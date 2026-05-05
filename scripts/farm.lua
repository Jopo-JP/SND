--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 7.0.0
description: >-
  Modulares Farm Script - Farmt Items automatisch via Farm-Quellen-Datenbank.
  Konfiguration über SND Config-UI.
plugin_dependencies:
- BossModReborn
- SomethingNeedDoing
- vnavmesh
- RotationSolver
configs:
  farmItem:
    default: "Glotzaugen-Tränen"
    description: Item-Name ODER Item-ID (Zahl)
    type: string
    required: true
  farmSource:
    default: ""
    description: Optionale Farm-Source key, falls mehrere Quellen dasselbe Item droppen
    type: string
    required: false
  farmQty:
    default: 100
    description: Wie viele Items TOTAL gesammelt werden sollen
    type: int
    min: 1
    max: 9999
    required: true
  pullSkill:
    default: "Tomahawk"
    description: Skill zum Pullen der Mobs
    type: string
    required: true
  killRange:
    default: 15
    description: Distanz ab der angegriffen wird (yalms)
    type: int
    min: 1
    max: 50
    required: false
  scanRange:
    default: 35
    description: Scan-Radius fuer Mob-Erkennung (yalms)
    type: int
    min: 10
    max: 100
    required: false
  detectionRange:
    default: 25
    description: Distanz ab der beim Laufen gestoppt wird (yalms)
    type: int
    min: 5
    max: 50
    required: false
  logLevel:
    default: "INFO"
    description: Log-Level (DEBUG, INFO, WARN, ERROR)
    type: string
    required: false

[[End Metadata]]
--]=====]
-- ======================================================================
-- Farm Script v7.0 - Modular, ID-basierte Farm-Quellen
-- ======================================================================

-- Module laden
local log       = require("lib/logger")
local utils     = require("lib/utils")
local entity    = require("lib/entity")
local nav       = require("lib/nav")
local combat    = require("lib/combat")
local inventory = require("lib/inventory")
local farmDb    = require("lib/farm_db")

-- ======================================================================
-- Konfiguration aus SND Config-UI laden
-- ======================================================================
local FARM_ITEM       = Config.Get("farmItem")
local FARM_SOURCE     = Config.Get("farmSource") or ""
local FARM_QTY        = Config.Get("farmQty")

-- Module mit Konfiguration initialisieren
log.level              = Config.Get("logLevel")
combat.PULL_SKILL      = Config.Get("pullSkill")
combat.KILL_RANGE      = Config.Get("killRange")
combat.SCAN_RANGE      = Config.Get("scanRange")
nav.DETECTION_RANGE    = Config.Get("detectionRange")

-- ======================================================================
-- Farm-Target Auflösung
-- ======================================================================

--- Gibt alle verfuegbaren Farm-Quellen aus.
local function logAvailableSources(itemId)
    local sources = itemId and farmDb.findCandidatesByItem(itemId) or farmDb.sources()
    for _, source in ipairs(sources) do
        local itemLabels = {}
        for _, id in ipairs(source.item_ids) do
            itemLabels[#itemLabels + 1] = string.format("%s (ID:%d)", farmDb.itemDisplayName(id), id)
        end
        log.error("  %s | %s | Drops: %s", source.key, farmDb.sourceLabel(source), table.concat(itemLabels, ", "))
    end
end

--- Findet Farm-Quelle und Drop in der Datenbank.
-- Unterstuetzt Suche per Item-ID (Zahl) oder Item-Name (alle Sprachen).
-- @param farmItem string|number Item-Name oder Item-ID
-- @param farmSource string|nil Optionale Source-Auswahl per key
-- @return table|nil source, number itemId, string itemName
local function resolveFarmTarget(farmItem, farmSource)
    local itemId = 0
    local itemName = ""

    if tonumber(farmItem) then
        itemId = tonumber(farmItem)
        itemName = farmDb.itemDisplayName(itemId)
    else
        local lang
        itemId, itemName, lang = farmDb.findItemByName(farmItem)
        if itemId then
            log.info("Item '%s' gefunden (Sprache: %s, ID:%d)", farmItem, lang or "?", itemId)
        end
    end

    if itemId == 0 or not itemId then
        return nil, 0, tostring(farmItem)
    end

    local candidates = farmDb.findCandidatesByItem(itemId)
    if #candidates == 0 then
        return nil, itemId, itemName
    end

    if farmSource and farmSource ~= "" then
        local selected = farmDb.findSourceByKey(farmSource, candidates)
        if selected then return selected, itemId, itemName end
        log.error("farmSource '%s' passt nicht zu Item '%s' (ID:%d).", farmSource, itemName, itemId)
        return nil, itemId, itemName
    end

    if #candidates == 1 then
        return candidates[1], itemId, itemName
    end

    log.error("Mehrere Farm-Quellen fuer '%s' (ID:%d) gefunden.", itemName, itemId)
    log.error("Bitte farmSource setzen:")
    for _, source in ipairs(candidates) do
        log.error("  farmSource = \"%s\"  -- %s", source.key, farmDb.sourceLabel(source))
    end
    return nil, itemId, itemName
end

-- ======================================================================
-- Main
-- ======================================================================
local ok, err = xpcall(function()
    log.info("=== FARM v7.0 ===")

    -- 1. Farm-Target auflösen
    local source, farmItemId, farmItemName = resolveFarmTarget(FARM_ITEM, FARM_SOURCE)
    if not source then
        log.error("ABBRUCH: Keine eindeutige Farm-Quelle fuer '%s' gefunden!", tostring(FARM_ITEM))
        log.error("Verfuegbare Farm-Quellen:")
        logAvailableSources(farmItemId ~= 0 and farmItemId or nil)
        return
    end

    local mobName   = source.name
    local mobLabel  = utils.displayName(source.name)
    local waypoints = source.waypoints

    if source.missing and source.missing.bnpc_name then
        log.error("ABBRUCH: BNpcName ID %s fehlt in data/generated/bnpc_names.lua.", tostring(source.bnpc_name_id))
        log.error("Exporter ausfuehren: python tools/export_xivapi_data.py export --mobs %s", tostring(source.bnpc_name_id))
        return
    end

    if source.missing and #source.missing.items > 0 then
        log.warn("Einige item_ids fehlen in data/generated/items.lua: %s", table.concat(source.missing.items, ","))
        log.warn("Exporter ausfuehren: python tools/export_xivapi_data.py export --items %s", table.concat(source.missing.items, ","))
    end

    if not waypoints or #waypoints == 0 then
        log.error("ABBRUCH: Farm-Quelle '%s' hat keine Waypoints.", source.key)
        return
    end

    log.info("Farm: %d x '%s' (ID:%d)", FARM_QTY, farmItemName, farmItemId)
    log.info("Quelle: %s", source.key)
    log.info("Monster: %s | Waypoints: %d", mobLabel, #waypoints)
    if source.territory then
        log.info("Zone: %s (Territory:%d)", utils.displayName(source.territory.name), source.territory_id)
    elseif source.territory_id then
        log.info("Territory: %d", source.territory_id)
    end
    log.info("Pull: %s | Kill-Range: %dy | Scan: %dy",
        combat.PULL_SKILL, combat.KILL_RANGE, combat.SCAN_RANGE)

    -- 2. Spieler-Position prüfen
    local startPos = entity.getPlayerPos()
    if not startPos then
        log.error("ABBRUCH: Spieler nicht lesbar!")
        return
    end
    log.info("Position: X=%.1f Y=%.1f Z=%.1f", startPos.x, startPos.y, startPos.z)

    -- 3. Navmesh prüfen
    if not nav.ensureMesh() then
        log.error("ABBRUCH: Navmesh nicht verfuegbar!")
        return
    end

    local okVnav, vnavOk = pcall(function() return IPC.IsInstalled("vnavmesh") end)
    if not (okVnav and vnavOk) then
        log.error("ABBRUCH: vnavmesh IPC nicht registriert!")
        return
    end
    log.info("vnavmesh: OK")

    -- 4. Item-ID auflösen (falls noch nicht aus Monster-DB bekannt)
    if farmItemId == 0 then
        farmItemId = inventory.resolveId(farmItemName)
        if not farmItemId then
            log.error("ABBRUCH: Item-ID fuer '%s' nicht gefunden!", farmItemName)
            return
        end
    end

    -- 5. Aktuellen Bestand prüfen
    local startItemCount = inventory.getCount(farmItemId)
    local needed = FARM_QTY - startItemCount
    log.info("Aktuell: %d x '%s'", startItemCount, farmItemName)

    if needed <= 0 then
        log.info("Bereits genug! (%d >= %d)", startItemCount, FARM_QTY)
        return
    end
    log.info("Brauche noch %d x '%s'", needed, farmItemName)

    -- 6. Plugins aktivieren
    log.info("Aktiviere RSR + BossModAI...")
    yield("/rsr auto")
    yield("/wait 0.5")
    yield("/bmrai on")
    yield("/wait 0.5")

    -- 7. Farm-Loop
    log.info("Startup OK! Starte Farm-Loop...")
    local kills = 0
    local wpIdx = 1

    --- Prüft ob das Farm-Ziel erreicht ist
    local function isDone()
        return inventory.getCount(farmItemId) >= FARM_QTY
    end

    --- Wird nach jedem Kill aufgerufen
    local function onKill(areaKills)
        kills = kills + 1
        local curItems = inventory.getCount(farmItemId)
        local collected = curItems - startItemCount
        log.info("Kill %d | %s: %d/%d (Total: %d)",
            kills, farmItemName, collected, needed, curItems)
    end

    while not isDone() do
        local wp = waypoints[wpIdx]
        local waypointDone = false
        local wpCenter = { x = wp.x, y = wp.y, z = wp.z }

        while not isDone() and not waypointDone do
            log.debug("Laufe zu Waypoint %d: %.1f/%.1f/%.1f", wpIdx, wp.x, wp.y, wp.z)
            local moveStatus = nav.moveTo(wp.x, wp.y, wp.z, mobName)

            if moveStatus == "arrived" then
                -- Waypoint erreicht. Nur wenn im Bereich kein weiterer Mob steht,
                -- wechseln wir weiter. Sonst bleiben wir im Clear-Mode.
                local areaKills = combat.scanAndKill(mobName, isDone, onKill, wpCenter)
                if isDone() then break end
                if areaKills == 0 then
                    log.debug("Waypoint %d komplett gecleart.", wpIdx)
                    waypointDone = true
                else
                    log.debug("Waypoint %d: weitere Mobs im Bereich erledigt, pruefe erneut.", wpIdx)
                end
            elseif moveStatus == "mob" or moveStatus == "combat" then
                log.debug("Waypoint %d unterbrochen - area clear ab aktueller Position.", wpIdx)
                local currentPos = entity.getPlayerPos() or wpCenter
                combat.scanAndKill(mobName, isDone, onKill, currentPos)
            else
                log.warn("Waypoint %d nicht sauber erreicht (%s) - gehe weiter.", wpIdx, tostring(moveStatus))
                waypointDone = true
            end
        end

        wpIdx = (wpIdx % #waypoints) + 1
    end

    -- 8. Shutdown
    log.info("=== SHUTDOWN ===")
    nav.stop()
    yield("/rsr off")
    yield("/wait 0.3")
    yield("/bmrai off")
    yield("/wait 0.3")
    local curItems = inventory.getCount(farmItemId)
    local collected = curItems - startItemCount
    log.info("FERTIG! %d x '%s' gesammelt (Total: %d)", collected, farmItemName, curItems)
    log.info("Kills gesamt: %d | Monster: %s", kills, mobLabel)

end, function(e)
    return debug.traceback(tostring(e), 2)
end)

if not ok then
    yield("/echo [FATAL] === SCRIPT CRASH ===")
    for line in tostring(err):gmatch("[^\n]+") do
        yield("/echo [FATAL] " .. line)
    end
    pcall(function() nav.stop() end)
    yield("/rsr off")
    yield("/bmrai off")
end
