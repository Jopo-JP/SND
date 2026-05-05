-- ======================================================================
-- SND Farm DB Module
-- Loest manuelle Farm-Quellen gegen generierte XIVAPI-Daten auf.
-- ======================================================================
local utils     = require("lib/utils")
local game_data = require("lib/game_data")

local M = {}

local rawSources = require("data/monsters")

local function makeNameFallback(label)
    return { en = label, de = label, fr = label, ja = label }
end

local function copyArray(source)
    local out = {}
    for i, value in ipairs(source or {}) do
        out[i] = value
    end
    return out
end

local function resolveLegacyItemIds(source)
    local itemIds = {}
    local seen = {}

    for _, id in ipairs(source.item_ids or {}) do
        id = tonumber(id)
        if id and not seen[id] then
            itemIds[#itemIds + 1] = id
            seen[id] = true
        end
    end

    for _, drop in ipairs(source.drops or {}) do
        local id = tonumber(drop.id)
        if id and not seen[id] then
            itemIds[#itemIds + 1] = id
            seen[id] = true
        end
    end

    return itemIds
end

local function fallbackName(source)
    if source.name then return source.name end
    if source.bnpc_name_id then return "BNpcName#" .. tostring(source.bnpc_name_id) end
    return "???"
end

local function resolveSource(source)
    local bnpcNameId = source.bnpc_name_id or source.name_id
    local mobName = source.name
    local missing = { items = {} }

    if bnpcNameId then
        local generatedName = game_data.getBnpcSingular(bnpcNameId)
        mobName = generatedName or mobName
        missing.bnpc_name = generatedName == nil and source.name == nil
    end

    local itemIds = resolveLegacyItemIds(source)
    local drops = {}

    for _, itemId in ipairs(itemIds) do
        local item = game_data.getItem(itemId)
        local legacyDrop

        if not item then
            missing.items[#missing.items + 1] = itemId
        end

        for _, drop in ipairs(source.drops or {}) do
            if tonumber(drop.id) == itemId then
                legacyDrop = drop
                break
            end
        end

        drops[#drops + 1] = {
            id = itemId,
            name = item and item.name or (legacyDrop and legacyDrop.name) or makeNameFallback("Item#" .. itemId),
        }
    end

    local territory = nil
    if source.territory_id then
        territory = game_data.getTerritory(source.territory_id)
        missing.territory = territory == nil
    end

    return {
        key = source.key or source.id or utils.displayName(mobName or fallbackName(source)),
        bnpc_name_id = bnpcNameId,
        territory_id = source.territory_id,
        map_id = source.map_id,
        name = mobName or fallbackName(source),
        territory = territory,
        item_ids = itemIds,
        drops = drops,
        waypoints = copyArray(source.waypoints),
        missing = missing,
        raw = source,
    }
end

local sourcesCache = nil

function M.sources()
    if sourcesCache then return sourcesCache end
    local out = {}
    for _, source in ipairs(rawSources) do
        out[#out + 1] = resolveSource(source)
    end
    sourcesCache = out
    return out
end

function M.findItemByName(search)
    for _, source in ipairs(M.sources()) do
        for _, drop in ipairs(source.drops) do
            local match, lang = utils.matchMultiName(drop.name, search)
            if match then return drop.id, utils.displayName(drop.name), lang end
        end
    end
    return nil, tostring(search), nil
end

function M.findCandidatesByItem(itemId)
    itemId = tonumber(itemId)
    local matches = {}
    if not itemId then return matches end

    for _, source in ipairs(M.sources()) do
        for _, id in ipairs(source.item_ids) do
            if id == itemId then
                matches[#matches + 1] = source
                break
            end
        end
    end

    return matches
end

function M.findSourceByKey(key, candidates)
    if not key or key == "" then return nil end
    local searchIn = candidates or M.sources()
    for _, source in ipairs(searchIn) do
        if source.key == key then return source end
    end
    return nil
end

function M.itemDisplayName(itemId, fallback)
    local item = game_data.getItem(itemId)
    if item and item.name then return utils.displayName(item.name) end
    return fallback or ("Item#" .. tostring(itemId))
end

function M.sourceLabel(source)
    local label = utils.displayName(source.name)
    if source.territory then
        label = label .. " @ " .. utils.displayName(source.territory.name)
    elseif source.territory_id then
        label = label .. " @ Territory#" .. tostring(source.territory_id)
    end
    return label
end

return M
