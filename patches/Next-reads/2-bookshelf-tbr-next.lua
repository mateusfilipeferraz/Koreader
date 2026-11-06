-- 2-bookshelf-tbr-next.lua
-- User patch: 'Next Reads' (TBR) completo para KOReader Bookshelf
-- Funcionalidades: Aba personalizada (editável com toque longo), auto-remoção e integração com o menu de seleção em massa.
--
-- Next Reads creates a saved shelf through Bookshelf's shelf-source API (lib/bookshelf_sources.lua, Bookshelf 6.x).
-- This allows the Next Reads tab to be changed through the shelf editor (normally via a long press on the tab).
-- Formatting can be changed as with any other tab and changes persist across restarts.
--
-- The shelf is created once automatically as a list sorted by title.
-- It stays deleted if removed but can be added back with Add new shelf > Source > Next Reads.
-- Finished books leave the list automatically.
-- The list is stored in koreader/settings/bookshelf_next_queue.json.

local userpatch = require("userpatch")
local UIManager = require("ui/uimanager")
local DataStorage = require("datastorage")
local json = require("json")
local InfoMessage = require("ui/widget/infomessage")

-- The id Bookshelf stores as the shelf's source.kind. Must ID as "next" so existing setups keep working.
local SOURCE_ID = "next"
-- Remembers that the Next Reads shelf was created once, so deletions persist.
local SHELF_CREATED_FLAG = "bookshelf_tbr_shelf_created"

-- =========================================================================
-- Dynamic localization (detects KOReader user language)
-- =========================================================================
local function getLanguage()
    if G_reader_settings and G_reader_settings.readSetting then
        local lang = G_reader_settings:readSetting("language")
        if lang and lang ~= "" then
            return lang:lower()
        end
    end
    local env_lang = os.getenv("LANG") or "en"
    return env_lang:lower()
end

local function getLocaleStrings()
    local lang = getLanguage()
    if lang:find("^pt") then
        return {
            display_name = "Próximas Leituras",
            source_label = "Próximas Leituras",
            add_button   = "Adicionar a Próximas Leituras",
            rem_button   = "Remover de Próximas Leituras",
            added_msg    = "Livro adicionado a Próximas Leituras!",
            removed_msg  = "Livro removido de Próximas Leituras.",
        }
    end
    return {
        display_name = "Next Reads",
        source_label = "Next Reads",
        add_button   = "Add to Next Reads",
        rem_button   = "Remove from Next Reads",
        added_msg    = "Added to Next Reads!",
        removed_msg  = "Removed from Next Reads.",
    }
end

-- =========================================================================
-- Queue storage
-- =========================================================================
local QUEUE_FILE = DataStorage:getSettingsDir() .. "/bookshelf_next_queue.json"

-- Tell Bookshelf the list changed, so an open Next Reads shelf redraws.
local function notifyChanged()
    local ok, Sources = pcall(require, "lib/bookshelf_sources")
    if ok and Sources and Sources.changed then
        pcall(Sources.changed, SOURCE_ID)
    end
end

local function loadQueue()
    local f = io.open(QUEUE_FILE, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(json.decode, content)
    return (ok and type(data) == "table") and data or {}
end

local function saveQueue(list)
    local f = io.open(QUEUE_FILE, "w")
    if f then
        f:write(json.encode(list))
        f:close()
    end
end

local function addMultipleToQueue(paths)
    local q = loadQueue()
    local added_count = 0
    for _, fp in ipairs(paths) do
        local exists = false
        local path_to_add = type(fp) == "table" and (fp.filepath or fp.path) or fp
        if type(path_to_add) == "string" then
            for _, existing in ipairs(q) do
                if existing == path_to_add then exists = true; break end
            end
            if not exists then
                table.insert(q, path_to_add)
                added_count = added_count + 1
            end
        end
    end
    if added_count > 0 then
        saveQueue(q)
        notifyChanged()
    end
    return added_count
end

local function removeFromQueue(filepath)
    local q = loadQueue()
    local changed = false
    for i = #q, 1, -1 do
        if q[i] == filepath then
            table.remove(q, i)
            changed = true
        end
    end
    if changed then
        saveQueue(q)
        notifyChanged()
    end
    return changed
end

-- =========================================================================
-- Book Completion Status Check
-- =========================================================================
local function isBookFinished(filepath)
    if not filepath then return false end

    local ok_bim, BIM = pcall(require, "bookinfomanager")
    if ok_bim and BIM and BIM.getBookInfo then
        local ok, info = pcall(BIM.getBookInfo, BIM, filepath, false)
        if ok and info and (info.status == "complete" or info.status == "finished") then
            return true
        end
    end

    local ok_ds, DocSettings = pcall(require, "docsettings")
    if ok_ds and DocSettings and DocSettings.open then
        local ok, doc_settings = pcall(DocSettings.open, DocSettings, filepath)
        if ok and doc_settings then
            local status = doc_settings:readSetting("summary", {})
            if type(status) == "table" and (status.status == "complete" or status.status == "finished") then
                return true
            end
        end
    end

    return false
end

-- =========================================================================
-- 1. File Manager Action Button Injection
-- =========================================================================
local function registerNextButton(fm_instance)
    local FileManager = require("apps/filemanager/filemanager")
    local target = fm_instance or FileManager

    if target and target.addFileDialogButtons then
        target:addFileDialogButtons("tbr_next_toggle", function(file)
            local strings = getLocaleStrings()
            local q = loadQueue()
            local in_q = false
            for _, fp in ipairs(q) do
                if fp == file then in_q = true; break end
            end

            return {{
                text = in_q and strings.rem_button or strings.add_button,
                callback = function()
                    if in_q then
                        removeFromQueue(file)
                        UIManager:show(InfoMessage:new{ text = strings.removed_msg, timeout = 2 })
                    else
                        addMultipleToQueue({file})
                        UIManager:show(InfoMessage:new{ text = strings.added_msg, timeout = 2 })
                    end
                end,
            }}
        end)
    end
end

local FileManager = require("apps/filemanager/filemanager")
if FileManager and not FileManager._original_init_tbr_next then
    FileManager._original_init_tbr_next = FileManager.init
    FileManager.init = function(self, ...)
        local ret = FileManager._original_init_tbr_next(self, ...)
        registerNextButton(self)
        return ret
    end
    registerNextButton(FileManager)
end

-- =========================================================================
-- 2. Bookshelf Plugin Patch
-- =========================================================================

-- The books on the Next Reads shelf, as ordinary Bookshelf book records.
-- Bookshelf then filters, sorts, and pages them with the shelf-specific settings.
local function listTbrBooks()
    local queue = loadQueue()
    local active_queue = {}
    local queue_changed = false

    for _, fp in ipairs(queue) do
        if type(fp) == "string" and not isBookFinished(fp) then
            table.insert(active_queue, fp)
        else
            queue_changed = true
        end
    end

    if queue_changed then
        saveQueue(active_queue)
    end

    local ok_r, Repo = pcall(require, "lib/bookshelf_book_repository")
    if not ok_r then Repo = nil end

    local books = {}
    for _, fp in ipairs(active_queue) do
        -- Light metadata first (cached, no cover decoded), then a full build without the cover, then a bare stand-in from the file name.
        local src = nil
        if Repo and Repo.lightMetaFor then
            local ok_l, res = pcall(Repo.lightMetaFor, fp)
            if ok_l and type(res) == "table" then src = res end
        end
        if not src and Repo and Repo.buildBookMeta then
            local ok_m, res = pcall(Repo.buildBookMeta, fp, { want_cover = false })
            if ok_m and type(res) == "table" then src = res end
        end

        local rec = {}
        if src then
            -- A copy: Bookshelf's cached records are shared and must not be changed, and Bookshelf stamps listed records.
            for k, v in pairs(src) do rec[k] = v end
            rec.cover_bb = nil
        else
            local name = (fp:match("([^/]+)$") or fp):gsub("%.[^%.]+$", "")
            rec.title = name
            rec.filename = name
        end
        rec.filepath = fp
        rec.source_kind = nil
        books[#books + 1] = rec
    end
    return books
end

local function registerTbrSource()
    local ok_s, Sources = pcall(require, "lib/bookshelf_sources")
    if not (ok_s and Sources and Sources.register) then return false end
    if Sources.get and Sources.get(SOURCE_ID) then return true end

    local ok_reg, res, why = pcall(Sources.register, SOURCE_ID, {
        api          = 1,
        label        = function() return getLocaleStrings().source_label end,
        available    = function() return true end,
        list         = function() return listTbrBooks() end,
        sort_default = { { key = "title", reverse = false } },
        -- A shelf made from "Add new shelf" with this source starts as a list.
        new_shelf    = function(draft)
            if draft.view_mode == nil then draft.view_mode = "list" end
        end,
        -- Covers for the visible page only, from KOReader's cover cache.
        cover        = function(rec)
            local ok_r, Repo = pcall(require, "lib/bookshelf_book_repository")
            if not (ok_r and Repo and Repo.getCoverBB and rec and rec.filepath) then return nil end
            local ok_c, bb = pcall(Repo.getCoverBB, rec.filepath)
            if ok_c and bb then return bb, bb:getWidth(), bb:getHeight() end
            return nil
        end,
    })
    if not ok_reg or not res then
        local logger = require("logger")
        logger.warn("Next Reads patch: could not register shelf source:", tostring(why or res))
        return false
    end
    return true
end

-- Add the Next Reads shelf to Bookshelf's saved shelves, once.
local function ensureTbrShelf(TabModel)
    if G_reader_settings:isTrue(SHELF_CREATED_FLAG) then return end

    local tabs = TabModel.load()
    for _, t in ipairs(tabs) do
        if type(t.source) == "table" and t.source.kind == SOURCE_ID then
            G_reader_settings:makeTrue(SHELF_CREATED_FLAG)
            return
        end
    end

    -- Keep the old tab's id ("next") when it's free, so a shelf that was open when KOReader closed opens again on Next Reads.
    local id = SOURCE_ID
    for _, t in ipairs(tabs) do
        if t.id == id then id = TabModel.newId(tabs); break end
    end

    tabs[#tabs + 1] = {
        id            = id,
        label         = getLocaleStrings().display_name,
        source        = { kind = SOURCE_ID },
        filter        = {},
        sort_priority = { { key = "title", reverse = false } },
        view_mode     = "list",
        enabled       = true,
    }
    TabModel.save(tabs)
    G_reader_settings:makeTrue(SHELF_CREATED_FLAG)
end

local function patchBookshelfPlugin(plugin)
    -- Integrar TBR com o diálogo nativo de seleção em massa (BulkActions)
    local ok_bulk, BulkActions = pcall(require, "lib/bookshelf_bulk_actions")

    if ok_bulk and BulkActions and not BulkActions._tbr_bulk_patched then
        BulkActions._tbr_bulk_patched = true

        local original_show = BulkActions.show

        BulkActions.show = function(opts)
            local ButtonDialog = require("ui/widget/buttondialog")
            local original_new = ButtonDialog.new
            local bulk_dialog = nil
            local inserted = false

            ButtonDialog.new = function(self, args)
                if not inserted and args and args.buttons then
                    inserted = true

                    local label
                    if getLanguage():find("^pt") then
                        label = "Adicionar selecionados a Próximas Leituras"
                    else
                        label = "Add selected to Next Reads"
                    end

                    local tbr_button = {
                        text = label,
                        callback = function()
                            local paths = opts.selection:paths()
                            local queue = loadQueue()
                            local known = {}
                            local added = 0
                            local already = 0

                            for _, fp in ipairs(queue) do
                                known[fp] = true
                            end

                            for _, fp in ipairs(paths) do
                                if not known[fp] then
                                    queue[#queue + 1] = fp
                                    known[fp] = true
                                    added = added + 1
                                else
                                    already = already + 1
                                end
                            end

                            if added > 0 then
                                saveQueue(queue)
                                notifyChanged()
                            end

                            if bulk_dialog then
                                UIManager:close(bulk_dialog)
                            end

                            local message
                            if getLanguage():find("^pt") then
                                message = string.format(
                                    "%d livro(s) adicionado(s); %d já estavam na fila.",
                                    added, already
                                )
                            else
                                message = string.format(
                                    "%d book(s) added; %d already queued.",
                                    added, already
                                )
                            end

                            UIManager:show(InfoMessage:new{
                                text = message,
                                timeout = 3,
                            })
                        end,
                    }

                    args.buttons[#args.buttons + 1] = { tbr_button }
                end

                bulk_dialog = original_new(self, args)
                return bulk_dialog
            end

            local result = { pcall(original_show, opts) }
            ButtonDialog.new = original_new

            if not result[1] then
                error(result[2])
            end

            return unpack(result, 2)
        end
    end

    -- The Next Reads shelf source, and the saved shelf.
    local source_ok = registerTbrSource()

    local ok_tm, TabModel = pcall(require, "lib/bookshelf_tab_model")
    if source_ok and ok_tm and TabModel and not TabModel._tbr_patched then
        TabModel._tbr_patched = true

        -- Bookshelf's settings are only loaded after it calls for its shelves, so the one-time shelf creation waits for the first call.
        local ensured = false
        local orig_getActive = TabModel.getActive
        TabModel.getActive = function(...)
            if not ensured then
                ensured = true
                local ok_e, err = pcall(ensureTbrShelf, TabModel)
                if not ok_e then
                    require("logger").warn("Next Reads patch: could not add the shelf:", tostring(err))
                end
            end
            return orig_getActive(...)
        end
    end

    local ok_repo, Repo = pcall(require, "lib/bookshelf_book_repository")
    if ok_repo and Repo and not Repo._tbr_status_hooked then
        Repo._tbr_status_hooked = true

        if Repo.setBookStatus then
            local orig_setBookStatus = Repo.setBookStatus
            Repo.setBookStatus = function(filepath, status, ...)
                if status == "complete" or status == "finished" then
                    removeFromQueue(filepath)
                end
                return orig_setBookStatus(filepath, status, ...)
            end
        end

        local orig_invalidated = Repo.on_book_invalidated
        Repo.on_book_invalidated = function(fp, ...)
            if fp and isBookFinished(fp) then
                removeFromQueue(fp)
            end
            if orig_invalidated then
                return orig_invalidated(fp, ...)
            end
        end
    end
end

userpatch.registerPatchPluginFunc("bookshelf", patchBookshelfPlugin)
