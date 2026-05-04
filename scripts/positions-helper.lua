--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 2.0.0
description: >-
  Waypoint-Sammler: Liest bestehende Waypoints aus der Zwischenablage,
  haengt die aktuelle Position an und kopiert den gesamten Block zurueck.
  Mehrfach ausfuehren um eine Route aufzubauen. Ergebnis ist direkt
  copy-paste-fertig fuer die Monster-Datenbank.

[[End Metadata]]
--]=====]
-- ======================================================================
-- Position Helper v2 - Waypoint-Sammler via Zwischenablage
-- ======================================================================

local entity = require("lib/entity")

--- Parst bestehende Waypoints aus einem Clipboard-String.
-- Erkennt das Format: { x = 1.0, y = 2.0, z = 3.0 },
-- @param text string Clipboard-Inhalt
-- @return table Liste von {x, y, z} Tables
local function parseWaypoints(text)
    local waypoints = {}
    if not text or text == "" then return waypoints end

    -- Matcht: { x = -49.8, y = -47.2, z = 420.9 },
    -- Flexibel bei Leerzeichen und optionalem Komma am Ende
    for x, y, z in text:gmatch("{%s*x%s*=%s*([%-%d%.]+)%s*,%s*y%s*=%s*([%-%d%.]+)%s*,%s*z%s*=%s*([%-%d%.]+)%s*}") do
        table.insert(waypoints, {
            x = tonumber(x),
            y = tonumber(y),
            z = tonumber(z),
        })
    end

    return waypoints
end

--- Formatiert eine Waypoint-Liste als copy-paste-fertigen Lua-Block.
-- @param waypoints table Liste von {x, y, z}
-- @return string Formatierter Block
local function formatWaypoints(waypoints)
    local lines = {}
    for _, wp in ipairs(waypoints) do
        table.insert(lines, string.format("            { x = %.1f, y = %.1f, z = %.1f },", wp.x, wp.y, wp.z))
    end
    return table.concat(lines, "\n")
end

-- Aktuelle Position lesen
local pos = entity.getPlayerPos()
if not pos then
    yield("/echo [POS] FEHLER: Spieler-Position nicht lesbar!")
    return
end

-- Bestehende Waypoints aus Zwischenablage lesen
local clipboard = ""
pcall(function() clipboard = System.GetClipboardText() end)
local waypoints = parseWaypoints(clipboard)

-- Duplikat-Check: Nicht hinzufügen wenn letzte Position fast identisch ist
local isDuplicate = false
if #waypoints > 0 then
    local last = waypoints[#waypoints]
    local dx = math.abs(last.x - pos.x)
    local dy = math.abs(last.y - pos.y)
    local dz = math.abs(last.z - pos.z)
    if dx < 1.0 and dy < 1.0 and dz < 1.0 then
        isDuplicate = true
    end
end

if isDuplicate then
    yield("/echo [POS] Duplikat! Position zu nah am letzten Waypoint.")
else
    -- Neue Position anhängen
    table.insert(waypoints, { x = pos.x, y = pos.y, z = pos.z })

    -- Formatieren und in Zwischenablage kopieren
    local output = formatWaypoints(waypoints)
    System.SetClipboardText(output)

    yield("/echo [POS] Waypoint #" .. #waypoints .. " hinzugefuegt: "
        .. string.format("{x=%.1f, y=%.1f, z=%.1f}", pos.x, pos.y, pos.z))
    yield("/echo [POS] Gesamt: " .. #waypoints .. " Waypoints in Zwischenablage")
end
