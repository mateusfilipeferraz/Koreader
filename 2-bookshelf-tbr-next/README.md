-- 2-bookshelf-tbr-next.lua
local userpatch = require("userpatch")
local UIManager = require("ui/uimanager")
local DataStorage = require("datastorage")
local json = require("json")
local InfoMessage = require("ui/widget/infomessage")

-- =========================================================================
-- Sistema de Tradução Dinâmico (segue o idioma do Bookshelf / KOReader)
-- =========================================================================
local function getLanguage()
    -- Tenta pegar a linguagem configurada nas opções do KOReader
    if G_reader_settings and G_reader_settings.readSetting then
        local lang = G_reader_settings:readSetting("language")
        if lang and lang ~= "" then
            return lang:lower()
        end
    end
    -- Fallback via variável de ambiente ou padrão
    local env_lang = os.getenv("LANG") or "en"
    return env_lang:lower()
end

local function getLocaleStrings()
    local lang = getLanguage()
    
    -- Se for Português (Brasil ou Portugal)
    if lang:find("^pt") then
        return {
            display_name = "Próximas Leituras",
            add_button   = "Adicionar a Próximas Leituras",
            rem_button   = "Remover de Próximas Leituras",
            added_msg    = "Livro adicionado a Próximas Leituras!",
            removed_msg  = "Livro removido de Próximas Leituras.",
        }
    end

    -- Padrão (Inglês)
    return {
        display_name = "Next Reads",
        add_button   = "Add to Next Reads",
        rem_button   = "Remove from Next Reads",
        added_msg    = "Added to Next Reads!",
        removed_msg  = "Removed from Next Reads.",
    }
end

local QUEUE_FILE = DataStorage:getSettingsDir() .. "/bookshelf_next_queue.json"

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

local function toggleQueue(filepath)
    local q = loadQueue()
    local found = false
    for i, fp in ipairs(q) do
        if fp == filepath then
            table.remove(q, i)
            found = true
            break
        end
    end
    if not found then
        table.insert(q, filepath)
    end
    saveQueue(q)
    return not found
end

-- =========================================================================
-- 1. Injeção do Botão em "AÇÕES DO PLUGIN"
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
                    local added = toggleQueue(file)
                    local current_strings = getLocaleStrings()
                    UIManager:show(InfoMessage:new{
                        text = added and current_strings.added_msg or current_strings.removed_msg,
                        timeout = 2,
                    })
                end,
            }}
        end)
    end
end

-- Hook na classe FileManager
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
-- 2. Injeção da Aba no Bookshelf
-- =========================================================================
local function patchBookshelfPlugin(plugin)
    local ok_tm, TabModel = pcall(require, "lib/bookshelf_tab_model")
    if ok_tm and TabModel and not TabModel._tbr_patched then
        TabModel._tbr_patched = true

        local orig_getActive = TabModel.getActive
        TabModel.getActive = function(...)
            local tabs = orig_getActive(...)
            local has_next = false
            for _, t in ipairs(tabs) do
                if t.id == "next" then has_next = true; break end
            end
            if not has_next then
                local strings = getLocaleStrings()
                table.insert(tabs, {
                    id = "next",
                    label = strings.display_name,
                    source = { kind = "next" },
                })
            end
            return tabs
        end

        local orig_getById = TabModel.getById
        TabModel.getById = function(id, ...)
            if id == "next" then
                local strings = getLocaleStrings()
                return { id = "next", label = strings.display_name, source = { kind = "next" } }
            end
            return orig_getById(id, ...)
        end
    end

    local ok_bw, BookshelfWidget = pcall(require, "lib/bookshelf_widget")
    if ok_bw and BookshelfWidget and not BookshelfWidget._tbr_patched then
        BookshelfWidget._tbr_patched = true

        local orig_fetch = BookshelfWidget._fetchChipItems
        BookshelfWidget._fetchChipItems = function(self_widget, n, want_all)
            if self_widget.chip == "next" and not (self_widget._drilldown_path and #self_widget._drilldown_path > 0) then
                local queue = loadQueue()
                local ok_repo, Repo = pcall(require, "lib/bookshelf_book_repository")
                local books = {}
                for _, fp in ipairs(queue) do
                    local b = nil
                    if ok_repo and Repo then
                        if Repo.buildBookMeta then
                            b = Repo.buildBookMeta(fp, { lazy_cover = true })
                        elseif Repo.lightMetaFor then
                            b = Repo.lightMetaFor(fp)
                        end
                    end
                    if not b then
                        b = {
                            filepath = fp,
                            title = (fp:match("([^/]+)$") or fp):gsub("%.[^%.]+$", ""),
                        }
                    end
                    table.insert(books, b)
                end
                return books, #books
            end
            return orig_fetch(self_widget, n, want_all)
        end
    end
end

userpatch.registerPatchPluginFunc("bookshelf", patchBookshelfPlugin)