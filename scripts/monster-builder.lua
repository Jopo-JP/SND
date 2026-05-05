--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 2.0.0
description: >-
  Farm-Source-Builder: Baut einen ID-basierten Eintrag fuer
  data/monsters.lua zusammen. Mehrfach ausfuehren sammelt Waypoints ueber die
  Zwischenablage. XIVAPI wird nur genutzt, wenn IDs/Namen neu aufgeloest werden.

  Workflow:
  1. sourceKey, monsterName oder bnpcNameId und itemIds setzen
  2. Zu Mob-Positionen laufen und Skript wiederholt ausfuehren
  3. Jedes Mal wird die aktuelle Position als Waypoint hinzugefuegt
  4. Das Ergebnis liegt immer aktuell in der Zwischenablage

configs:
  sourceKey:
    default: ""
    description: Eindeutiger key fuer farmSource (leer = automatisch aus Monstername)
    type: string
    required: false
  monsterName:
    default: "MONSTER_NAME_HIER"
    description: Monster-Name fuer BNpcName-Suche, falls bnpcNameId leer ist
    type: string
    required: false
  bnpcNameId:
    default: 0
    description: BNpcName-ID direkt setzen (empfohlen, falls bekannt)
    type: int
    min: 0
    max: 999999
    required: false
  itemIds:
    default: ""
    description: Item-IDs oder Namen, comma-separiert (z.B. 12628, Ätzendes Sekret)
    type: string
    required: false
  territoryId:
    default: 0
    description: TerritoryType-ID der Zone (optional)
    type: int
    min: 0
    max: 999999
    required: false
  mapId:
    default: 0
    description: Map-ID (optional)
    type: int
    min: 0
    max: 999999
    required: false
  mode:
    default: "add"
    description: add, undo, preview oder reset
    type: string
    required: false

[[End Metadata]]
--]=====]
-- ======================================================================
-- Farm-Source-Builder v2
-- ======================================================================

local log    = require("lib/logger")
local entity = require("lib/entity")
local xivapi = require("lib/xivapi")

log.level = "INFO"

local SOURCE_KEY   = Config.Get("sourceKey") or ""
local MONSTER_NAME = Config.Get("monsterName") or ""
local BNPC_NAME_ID = tonumber(Config.Get("bnpcNameId") or 0) or 0
local ITEM_IDS     = Config.Get("itemIds") or ""
local TERRITORY_ID = tonumber(Config.Get("territoryId") or 0) or 0
local MAP_ID       = tonumber(Config.Get("mapId") or 0) or 0
local MODE         = string.lower(tostring(Config.Get("mode") or "add"))

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function slug(value)
    local text = string.lower(tostring(value or "farm-source"))
    text = text:gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
    if text == "" then return "farm-source" end
    return text
end

local function escapeLuaString(value)
    return tostring(value or "")
        :gsub("\\", "\\\\")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub('"', '\\"')
end

local function searchMobWithFallback(name)
    local order = { "en", "de", "fr", "ja" }
    for _, lang in ipairs(order) do
        local results = xivapi.searchMobNames(name, lang, 1)
        if results and #results > 0 then
            return results[1], lang
        end
    end
    return nil, nil
end

local function searchItemWithFallback(name)
    local order = { "en", "de", "fr", "ja" }
    for _, lang in ipairs(order) do
        local results = xivapi.searchItems(name, lang, 1)
        if results and #results > 0 then
            return results[1], lang
        end
    end
    return nil, nil
end

local function parseList(value)
    local out = {}
    for part in tostring(value or ""):gmatch("[^,]+") do
        local token = trim(part)
        if token ~= "" then out[#out + 1] = token end
    end
    return out
end

local function parseNumberList(text, fieldName)
    local out = {}
    for value in tostring(text or ""):gmatch(fieldName .. "%s*=%s*{(.-)}") do
        for id in value:gmatch("%d+") do
            out[#out + 1] = tonumber(id)
        end
        return out
    end
    return out
end

local function parseScalarNumber(text, fieldName)
    local value = tostring(text or ""):match(fieldName .. "%s*=%s*(%d+)")
    return value and tonumber(value) or nil
end

local function parseScalarString(text, fieldName)
    return tostring(text or ""):match(fieldName .. '%s*=%s*"([^"]+)"')
end

local function parseWaypoints(text)
    local waypoints = {}
    if not text or text == "" then return waypoints end

    for x, y, z in text:gmatch("{%s*x%s*=%s*([%-%d%.]+)%s*,%s*y%s*=%s*([%-%d%.]+)%s*,%s*z%s*=%s*([%-%d%.]+)%s*}") do
        waypoints[#waypoints + 1] = { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
    end

    return waypoints
end

local function addUnique(list, value)
    value = tonumber(value)
    if not value then return end
    for _, existing in ipairs(list) do
        if existing == value then return end
    end
    list[#list + 1] = value
end

local function resolveItemToken(token)
    local id = tonumber(token)
    if id then return id end

    local result, lang = searchItemWithFallback(token)
    if result then
        log.info("Item '%s' gefunden ueber %s: ID %d", token, lang or "?", result.id)
        return result.id
    end

    log.warn("Item '%s' nicht gefunden.", token)
    return nil
end

local function resolveBnpcNameId(existingId)
    if BNPC_NAME_ID > 0 then return BNPC_NAME_ID end
    if existingId and existingId > 0 and MODE ~= "reset" then return existingId end
    if not MONSTER_NAME or MONSTER_NAME == "" or MONSTER_NAME == "MONSTER_NAME_HIER" then return nil end

    local result, lang = searchMobWithFallback(MONSTER_NAME)
    if result then
        log.info("Monster '%s' gefunden ueber %s: BNpcName ID %d", MONSTER_NAME, lang or "?", result.id)
        return result.id
    end

    log.warn("Monster '%s' nicht ueber BNpcName gefunden.", MONSTER_NAME)
    return nil
end

local function formatEntry(source)
    local lines = {}
    lines[#lines + 1] = "    {"
    lines[#lines + 1] = string.format('        key = "%s",', escapeLuaString(source.key))
    if source.bnpc_name_id then lines[#lines + 1] = string.format("        bnpc_name_id = %d,", source.bnpc_name_id) end
    if source.territory_id then lines[#lines + 1] = string.format("        territory_id = %d,", source.territory_id) end
    if source.map_id then lines[#lines + 1] = string.format("        map_id = %d,", source.map_id) end
    lines[#lines + 1] = "        item_ids = {"
    for _, id in ipairs(source.item_ids) do
        lines[#lines + 1] = string.format("            %d,", id)
    end
    lines[#lines + 1] = "        },"
    lines[#lines + 1] = "        waypoints = {"
    for _, wp in ipairs(source.waypoints) do
        lines[#lines + 1] = string.format("            { x = %.1f, y = %.1f, z = %.1f },", wp.x, wp.y, wp.z)
    end
    lines[#lines + 1] = "        },"
    lines[#lines + 1] = "    },"
    return table.concat(lines, "\n")
end

local clipboard = ""
if MODE ~= "reset" then
    pcall(function() clipboard = System.GetClipboardText() end)
end

local source = {
    key = SOURCE_KEY ~= "" and SOURCE_KEY or parseScalarString(clipboard, "key"),
    bnpc_name_id = parseScalarNumber(clipboard, "bnpc_name_id"),
    territory_id = parseScalarNumber(clipboard, "territory_id"),
    map_id = parseScalarNumber(clipboard, "map_id"),
    item_ids = parseNumberList(clipboard, "item_ids"),
    waypoints = parseWaypoints(clipboard),
}

source.bnpc_name_id = resolveBnpcNameId(source.bnpc_name_id)
if TERRITORY_ID > 0 then source.territory_id = TERRITORY_ID end
if MAP_ID > 0 then source.map_id = MAP_ID end

for _, token in ipairs(parseList(ITEM_IDS)) do
    addUnique(source.item_ids, resolveItemToken(token))
end

if not source.key or source.key == "" then
    source.key = slug(MONSTER_NAME ~= "" and MONSTER_NAME or ("bnpc-" .. tostring(source.bnpc_name_id or "unknown")))
end

if MODE == "undo" then
    if #source.waypoints > 0 then
        local removed = source.waypoints[#source.waypoints]
        source.waypoints[#source.waypoints] = nil
        log.info("Waypoint entfernt: {x=%.1f, y=%.1f, z=%.1f}", removed.x, removed.y, removed.z)
    else
        log.warn("Keine Waypoints zum Entfernen vorhanden.")
    end
elseif MODE == "preview" then
    log.info("Preview: keine Positionsaenderung.")
else
    local pos = entity.getPlayerPos()
    if not pos then
        log.error("Spieler-Position nicht lesbar!")
        return
    end

    local duplicate = false
    if #source.waypoints > 0 then
        local last = source.waypoints[#source.waypoints]
        duplicate = math.abs(last.x - pos.x) < 1.0
            and math.abs(last.y - pos.y) < 1.0
            and math.abs(last.z - pos.z) < 1.0
    end

    if duplicate then
        log.info("Position unveraendert - Waypoint nicht hinzugefuegt.")
    else
        source.waypoints[#source.waypoints + 1] = { x = pos.x, y = pos.y, z = pos.z }
        log.info("Waypoint #%d hinzugefuegt: {x=%.1f, y=%.1f, z=%.1f}", #source.waypoints, pos.x, pos.y, pos.z)
    end
end

local entry = formatEntry(source)
System.SetClipboardText(entry)

log.info("=== Farm-Source in Zwischenablage ===")
log.info("key=%s | bnpc_name_id=%s | territory_id=%s | map_id=%s | items=%d | waypoints=%d",
    source.key,
    tostring(source.bnpc_name_id),
    tostring(source.territory_id),
    tostring(source.map_id),
    #source.item_ids,
    #source.waypoints)
log.info("IDs bei Bedarf extern exportieren: python tools/export_xivapi_data.py export --items ... --mobs ... --territories ...")
