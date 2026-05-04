--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 1.0.0
description: >-
  Monster-Entry-Builder: Baut einen fast fertigen Eintrag fuer
  data/monsters.lua zusammen. Kombiniert Waypoint-Sammlung mit
  XIVAPI Item-Suche.

  Workflow:
  1. Item-Name oder ID eingeben
  2. Zu Mob-Positionen laufen und Skript wiederholt ausfuehren
  3. Jedes Mal wird die aktuelle Position als Waypoint hinzugefuegt
  4. Das Ergebnis liegt immer aktuell in der Zwischenablage

configs:
  monsterName:
    default: "MONSTER_NAME_HIER"
    description: Monster-Name fuer /target (muss zur Client-Sprache passen)
    type: string
    required: true
  itemName:
    default: ""
    description: Item-Name oder Item-ID (leer = nur Waypoints sammeln)
    type: string
    required: false
  resetWaypoints:
    default: false
    description: Waypoints zuruecksetzen (neue Route starten)
    type: bool
    required: false

[[End Metadata]]
--]=====]
-- ======================================================================
-- Monster-Entry-Builder
-- ======================================================================

local log    = require("lib/logger")
local entity = require("lib/entity")
local xivapi = require("lib/xivapi")

log.level = "INFO"

local MONSTER_NAME   = Config.Get("monsterName")
local ITEM_NAME      = Config.Get("itemName")
local RESET          = Config.Get("resetWaypoints")

local function escapeLuaString(value)
    return tostring(value)
        :gsub("\\", "\\\\")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub('"', '\\"')
end

-- ======================================================================
-- Waypoint-Parsing (gleiche Logik wie positions-helper)
-- ======================================================================

local function parseWaypoints(text)
    local wps = {}
    if not text or text == "" then return wps end
    -- Suche den waypoints-Block
    for x, y, z in text:gmatch("{%s*x%s*=%s*([%-%d%.]+)%s*,%s*y%s*=%s*([%-%d%.]+)%s*,%s*z%s*=%s*([%-%d%.]+)%s*}") do
        wps[#wps + 1] = { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
    end
    return wps
end

-- ======================================================================
-- Monster-Entry formatieren
-- ======================================================================

local function formatEntry(monsterName, itemData, waypoints)
    local lines = {}
    lines[#lines + 1] = "    {"
    lines[#lines + 1] = string.format('        name = "%s",', escapeLuaString(monsterName))
    lines[#lines + 1] = "        waypoints = {"

    for _, wp in ipairs(waypoints) do
        lines[#lines + 1] = string.format("            { x = %.1f, y = %.1f, z = %.1f },", wp.x, wp.y, wp.z)
    end

    lines[#lines + 1] = "        },"
    lines[#lines + 1] = "        drops = {"

    if itemData then
        lines[#lines + 1] = "            {"
        lines[#lines + 1] = string.format("                id = %d,", itemData.id)
        lines[#lines + 1] = "                name = {"
        lines[#lines + 1] = string.format('                    en = "%s",', escapeLuaString(itemData.name.en))
        lines[#lines + 1] = string.format('                    de = "%s",', escapeLuaString(itemData.name.de))
        lines[#lines + 1] = string.format('                    fr = "%s",', escapeLuaString(itemData.name.fr))
        lines[#lines + 1] = string.format('                    ja = "%s",', escapeLuaString(itemData.name.ja))
        lines[#lines + 1] = "                },"
        lines[#lines + 1] = "            },"
    else
        lines[#lines + 1] = '            -- Item hier eintragen (item-search.lua nutzen)'
    end

    lines[#lines + 1] = "        },"
    lines[#lines + 1] = "    },"

    return table.concat(lines, "\n")
end

-- ======================================================================
-- Main
-- ======================================================================

-- 1. Item-Daten laden (falls angegeben)
local itemData = nil

if ITEM_NAME and ITEM_NAME ~= "" then
    local itemId = tonumber(ITEM_NAME)

    if itemId then
        -- Direkt per ID laden
        log.info("Lade Item ID %d in allen Sprachen...", itemId)
        itemData = xivapi.getItemAllLanguages(itemId)
    else
        -- Per Name suchen, dann ID laden
        log.info("Suche '%s' via XIVAPI...", ITEM_NAME)
        local results = xivapi.searchItems(ITEM_NAME, "de", 1)
        if results and #results > 0 then
            log.info("Gefunden: ID %d - Lade alle Sprachen...", results[1].id)
            itemData = xivapi.getItemAllLanguages(results[1].id)
        else
            log.warn("Item '%s' nicht gefunden - Entry wird ohne Item erstellt.", ITEM_NAME)
        end
    end

    if itemData then
        log.info("Item: %s (ID: %d)", itemData.name.de or itemData.name.en, itemData.id)
    end
end

-- 2. Position lesen
local pos = entity.getPlayerPos()
if not pos then
    log.error("Spieler-Position nicht lesbar!")
    return
end

-- 3. Bestehende Waypoints aus Zwischenablage lesen
local waypoints = {}
if not RESET then
    local clipboard = ""
    pcall(function() clipboard = System.GetClipboardText() end)
    waypoints = parseWaypoints(clipboard)
end

-- 4. Duplikat-Check
local isDuplicate = false
if #waypoints > 0 then
    local last = waypoints[#waypoints]
    if math.abs(last.x - pos.x) < 1.0
       and math.abs(last.y - pos.y) < 1.0
       and math.abs(last.z - pos.z) < 1.0 then
        isDuplicate = true
    end
end

if isDuplicate then
    log.info("Position unveraendert - Waypoint nicht hinzugefuegt.")
else
    waypoints[#waypoints + 1] = { x = pos.x, y = pos.y, z = pos.z }
    log.info("Waypoint #%d hinzugefuegt: {x=%.1f, y=%.1f, z=%.1f}", #waypoints, pos.x, pos.y, pos.z)
end

-- 5. Entry formatieren und in Zwischenablage
local entry = formatEntry(MONSTER_NAME, itemData, waypoints)
System.SetClipboardText(entry)

log.info("=== Monster-Entry in Zwischenablage (%d Waypoints) ===", #waypoints)
log.info("Einfach in data/monsters.lua einfuegen.")
