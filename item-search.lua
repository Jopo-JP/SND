--[[
  Item-Suche - Sucht Item-ID per Name im Excel-Sheet
  Sucht in Batches von 2000 um SND nicht zu überlasten
  ITEM_NAME unten anpassen!
]]
local ITEM_NAME = "Glotzaugen-Tränen"
local searchLower = string.lower(ITEM_NAME)
local found = {}
local startId = 0
local endId = 40000
local batchSize = 200

local function L(msg) yield("/echo [ITEM] " .. tostring(msg)) end

L("Suche '" .. ITEM_NAME .. "' in Item-Sheet (0-40000)...")

for batchStart = startId, endId, batchSize do
    local batchEnd = math.min(batchStart + batchSize - 1, endId)
    for id = batchStart, batchEnd do
        local ok, row = pcall(function() return Excel.GetRow("Item", id) end)
        if ok and row then
            local okN, name = pcall(function() return row.Name end)
            if okN and name then
                local nStr = tostring(name)
                if string.find(string.lower(nStr), searchLower) then
                    table.insert(found, {id=id, name=nStr})
                    L(">>> GEFUNDEN: ID=" .. tostring(id) .. " Name='" .. nStr .. "'")
                end
            end
        end
    end
    L("Batch " .. tostring(batchStart) .. "-" .. tostring(batchEnd) .. " durchsucht. Treffer: " .. tostring(#found))
    yield("/wait 0.1")  -- Kurz pausieren damit SND nicht crasht
end

L("=== ERGEBNIS ===")
L("Suche nach '" .. ITEM_NAME .. "': " .. tostring(#found) .. " Treffer")
for _, f in ipairs(found) do
    L("  ID " .. tostring(f.id) .. " = '" .. f.name .. "'")
end
