-- ======================================================================
-- SND Game Data Module
-- Zugriff auf extern generierte XIVAPI-Lua-Daten aus data/generated/.
-- ======================================================================
local M = {}

local function safeRequire(moduleName)
    local ok, data = pcall(require, moduleName)
    if ok and type(data) == "table" then return data end
    return {}
end

M.items       = safeRequire("data/generated/items")
M.bnpc_names  = safeRequire("data/generated/bnpc_names")
M.territories = safeRequire("data/generated/territories")
M.maps        = safeRequire("data/generated/maps")
M.place_names = safeRequire("data/generated/place_names")

local function getById(source, id)
    id = tonumber(id)
    if not id then return nil end
    return source[id]
end

function M.getItem(id)
    return getById(M.items, id)
end

function M.getBnpcName(id)
    return getById(M.bnpc_names, id)
end

function M.getTerritory(id)
    return getById(M.territories, id)
end

function M.getMap(id)
    return getById(M.maps, id)
end

function M.getPlaceName(id)
    return getById(M.place_names, id)
end

function M.getItemName(id)
    local item = M.getItem(id)
    return item and item.name or nil
end

function M.getBnpcSingular(id)
    local mob = M.getBnpcName(id)
    return mob and mob.singular or nil
end

return M
