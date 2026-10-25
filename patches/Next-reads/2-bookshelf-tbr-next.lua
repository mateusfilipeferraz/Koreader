-- 2-bookshelf-tbr-next.lua
-- User patch: Aba 'Next Reads' (TBR) e botão em 'Ações do Plugin'

local userpatch = require("userpatch")
local UIManager = require("ui/uimanager")
local DataStorage = require("datastorage")
local json = require("json")
local InfoMessage = require("ui/widget/infomessage")

-- NOME VISÍVEL DA ABA E BOTÕES (Altere à vontade esta variável)
local DISPLAY_NAME = "Next Reads"

local QUEUE_FILE = DataStorage:getSettingsDir() .. "/bookshelf_next_queue.json"

-- Gerenciamento de persistência da fila
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
            local q = loadQueue()
            local in_q = false
            for _, fp in ipairs(q) do
                if fp == file then in_q = true; break end
            end

            return {{
                text = in_q and ("Remover de " .. DISPLAY_NAME) or ("Adicionar a " .. DISPLAY_NAME),
                callback = function()
                    local added = toggleQueue(file)
                    UIManager:show(InfoMessage:new{
                        text = added and ("Livro adicionado a " .. DISPLAY_NAME .. "!") or ("Livro removido de " .. DISPLAY_NAME .. "."),
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
                table.insert(tabs, {
                    id = "next",             -- NÃO ALTERAR (ID interno)
                    label = DISPLAY_NAME,    -- Nome que aparece na tela
                    source = { kind = "next" }, -- NÃO ALTERAR (Tipo interno)
                })
            end
            return tabs
        end

        local orig_getById = TabModel.getById
        TabModel.getById = function(id, ...)
            if id == "next" then
                return { id = "next", label = DISPLAY_NAME, source = { kind = "next" } }
            end
            return orig_getById(id, ...)
        end
    end

    local ok_bw, BookshelfWidget = pcall(require, "lib/bookshelf_widget")
    if ok_bw and BookshelfWidget and not BookshelfWidget._tbr_patched then
        BookshelfWidget._tbr_patched = true

        local orig_fetch = BookshelfWidget._fetchChipItems
        BookshelfWidget._fetchChipItems = function(self_widget, n, want_all)
            -- Compara com o identificador interno "next"
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