--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 1.1.0
description: >-
  Item-Suche - Findet Item-IDs per Name im Excel Item-Sheet.
  Konfiguration über SND Config-UI.
configs:
  itemName:
    default: "Glotzaugen-Tränen"
    description: Name des Items das gesucht werden soll
    type: string
    required: true
  maxId:
    default: 40000
    description: Hoechste Item-ID die durchsucht wird
    type: int
    min: 1000
    max: 100000
    required: false

[[End Metadata]]
--]=====]
-- ======================================================================
-- Item Search Tool
-- ======================================================================

local log   = require("lib/logger")
local utils = require("lib/utils")

log.level = "INFO"

local ITEM_NAME = Config.Get("itemName")
local MAX_ID    = Config.Get("maxId")
local found     = {}
local batchSize = 200

log.info("Suche '%s' in Item-Sheet (0-%d)...", ITEM_NAME, MAX_ID)

for batchStart = 0, MAX_ID, batchSize do
    local batchEnd = math.min(batchStart + batchSize - 1, MAX_ID)
    for id = batchStart, batchEnd do
        local ok, row = pcall(function() return Excel.GetRow("Item", id) end)
        if ok and row then
            local okN, name = pcall(function() return row.Name end)
            if okN and name then
                local nStr = tostring(name)
                if utils.matchName(nStr, ITEM_NAME) then
                    table.insert(found, { id = id, name = nStr })
                    log.info(">>> GEFUNDEN: ID=%d Name='%s'", id, nStr)
                end
            end
        end
    end
    log.info("Batch %d-%d durchsucht. Treffer: %d", batchStart, batchEnd, #found)
    yield("/wait 0.1")
end

log.info("=== ERGEBNIS ===")
log.info("Suche nach '%s': %d Treffer", ITEM_NAME, #found)
for _, f in ipairs(found) do
    log.info("  ID %d = '%s'", f.id, f.name)
end
