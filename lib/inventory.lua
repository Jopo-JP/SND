-- ======================================================================
-- SND Inventory Module
-- Item-Suche (Inventar, Excel-Sheet) und Zählung
-- ======================================================================
local log   = require("lib/logger")
local utils = require("lib/utils")

local M = {}

-- Alle durchsuchbaren Inventar-Container
local BAG_NAMES = {
    "Inventory1", "Inventory2", "Inventory3", "Inventory4",
    "EquippedItems", "Crystals", "Currency", "KeyItems",
}

--- Gibt die Anzahl eines Items per ID zurück (schnell).
-- @param itemId number Item-ID
-- @return number Anzahl
function M.getCount(itemId)
    local ok, count = pcall(function()
        return Inventory.GetItemCount(itemId)
    end)
    return ok and tonumber(count) or 0
end

--- Löst einen Item-Namen zu einer ID auf via Excel-Sheet.
-- @param itemId number Item-ID
-- @return string|nil Item-Name oder nil
function M.getNameById(itemId)
    local ok, row = pcall(function() return Excel.GetRow("Item", itemId) end)
    if ok and row then
        local okN, n = pcall(function() return row.Name end)
        if okN and n then return tostring(n) end
    end
    return nil
end

--- Sucht eine Item-ID per Name im Inventar.
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

--- Sucht eine Item-ID per Name im Excel Item-Sheet (langsam, ~15s).
-- @param itemName string Name des Items
-- @param maxId number|nil Höchste zu prüfende ID (default 40000)
-- @return number|nil Item-ID oder nil
function M.findIdInExcel(itemName, maxId)
    maxId = maxId or 40000
    log.info("Suche '%s' im Excel Item-Sheet (dauert ca. 15s)...", itemName)
    local batchSize = 2000

    for batchStart = 0, maxId, batchSize do
        local batchEnd = math.min(batchStart + batchSize - 1, maxId)
        for id = batchStart, batchEnd do
            local name = M.getNameById(id)
            if name and utils.matchName(name, itemName) then
                log.info("Gefunden: '%s' ID=%d", name, id)
                return id
            end
        end
        yield("/wait 0.05")
    end
    return nil
end

--- Versucht eine Item-ID aufzulösen: erst Inventar, dann Excel.
-- @param itemName string Name des Items
-- @return number|nil Item-ID oder nil
function M.resolveId(itemName)
    return M.findIdInInventory(itemName) or M.findIdInExcel(itemName)
end

return M
