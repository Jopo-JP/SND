-- ======================================================================
-- SND Inventory Module
-- Item-Zaehlung (lokal) und ID-Aufloesung (Inventar -> XIVAPI Fallback)
-- ======================================================================
local log    = require("lib/logger")
local utils  = require("lib/utils")
local xivapi = require("lib/xivapi")

local M = {}

-- Alle durchsuchbaren Inventar-Container
local BAG_NAMES = {
    "Inventory1", "Inventory2", "Inventory3", "Inventory4",
    "EquippedItems", "Crystals", "Currency", "KeyItems",
}

--- Gibt die Anzahl eines Items per ID zurueck (schnell, lokal).
-- @param itemId number Item-ID
-- @return number Anzahl
function M.getCount(itemId)
    local ok, count = pcall(function()
        return Inventory.GetItemCount(itemId)
    end)
    return ok and tonumber(count) or 0
end

--- Liest einen Item-Namen per ID via XIVAPI (kein Lag).
-- @param itemId number Item-ID
-- @param language string|nil Sprache (default "de")
-- @return string|nil Item-Name oder nil
function M.getNameById(itemId, language)
    local item = xivapi.getItem(itemId, language or "de")
    if item then return item.name end
    return nil
end

--- Sucht eine Item-ID per Name im Inventar (lokal, schnell).
-- @param itemName string Name des Items
-- @return number|nil Item-ID oder nil
function M.findIdInInventory(itemName)
    log.info("Suche '%s' im Inventar...", itemName)

    for _, bagName in ipairs(BAG_NAMES) do
        local okBag, container = pcall(function() return Inventory[bagName] end)
        if okBag and container then
            local okCount, count = pcall(function() return container.Count end)
            if okCount and count and count > 0 then
                for i = 0, count - 1 do
                    local okItem, item = pcall(function() return container[i] end)
                    if okItem and item then
                        local isEmpty = false
                        pcall(function() isEmpty = item.IsEmpty end)
                        if not isEmpty then
                            local id = 0
                            pcall(function() id = item.ItemId end)
                            -- Nutze XIVAPI statt Excel.GetRow fuer den Namen
                            local name = M.getNameById(id)
                            if name and utils.matchName(name, itemName) then
                                log.info("Gefunden: '%s' ID=%d", name, id)
                                return id
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

--- Sucht eine Item-ID per Name via XIVAPI Search (schnell, kein Lag).
-- @param itemName string Name des Items
-- @param language string|nil Sprache (default "de")
-- @return number|nil Item-ID oder nil
function M.findIdBySearch(itemName, language)
    log.info("Suche '%s' via XIVAPI...", itemName)

    local order = language and { language } or { "en", "de", "fr", "ja" }
    for _, lang in ipairs(order) do
        local results = xivapi.searchItems(itemName, lang, 5)
        if results and #results > 0 then
            local best = results[1]
            log.info("XIVAPI Treffer ueber '%s': '%s' ID=%d (Score: %.2f)", lang, best.name, best.id, best.score)
            return best.id
        end
    end

    log.warn("Keine XIVAPI-Treffer fuer '%s'", itemName)
    return nil
end

--- Versucht eine Item-ID aufzuloesen: erst Inventar (lokal), dann XIVAPI.
-- @param itemName string Name des Items
-- @param language string|nil Sprache (default "de")
-- @return number|nil Item-ID oder nil
function M.resolveId(itemName, language)
    return M.findIdInInventory(itemName) or M.findIdBySearch(itemName, language)
end

return M
