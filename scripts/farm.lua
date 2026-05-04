--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 6.0.0
description: >-
  Modulares Farm Script - Farmt Items automatisch via Monster-Datenbank.
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
-- Farm Script v6.0 - Modular
-- ======================================================================

-- Module laden
local log       = require("lib/logger")
local utils     = require("lib/utils")
local entity    = require("lib/entity")
local nav       = require("lib/nav")
local combat    = require("lib/combat")
local inventory = require("lib/inventory")
local MONSTER_DB = require("data/monsters")

-- ======================================================================
-- Konfiguration aus SND Config-UI laden
-- ======================================================================
local FARM_ITEM       = Config.Get("farmItem")
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

--- Findet das Monster und Drop in der Datenbank.
-- Unterstuetzt Suche per Item-ID (Zahl) oder Item-Name (alle Sprachen).
-- @param farmItem string|number Item-Name oder Item-ID
-- @return table|nil monster, number itemId, string itemName
local function resolveFarmTarget(farmItem)
    local itemId = 0
    local itemName = ""

    if tonumber(farmItem) then
        -- Numerische ID
        itemId = tonumber(farmItem)
        for _, m in ipairs(MONSTER_DB) do
            for _, d in ipairs(m.drops) do
                if d.id == itemId then
                    itemName = utils.displayName(d.name)
                    return m, itemId, itemName
                end
            end
        end
        itemName = "Item#" .. itemId
    else
        -- String-Name: Suche in allen Sprachen
        itemName = farmItem
        for _, m in ipairs(MONSTER_DB) do
            for _, d in ipairs(m.drops) do
                local match, lang = utils.matchMultiName(d.name, farmItem)
                if match then
                    log.info("Item '%s' gefunden (Sprache: %s)", farmItem, lang or "?")
                    return m, d.id, utils.displayName(d.name)
                end
            end
        end
    end

    return nil, itemId, itemName
end

-- ======================================================================
-- Main
-- ======================================================================
local ok, err = xpcall(function()
    log.info("=== FARM v6.0 ===")

    -- 1. Farm-Target auflösen
    local monster, farmItemId, farmItemName = resolveFarmTarget(FARM_ITEM)
    if not monster then
        log.error("ABBRUCH: Kein Monster fuer '%s' in MONSTER_DB gefunden!", tostring(FARM_ITEM))
        log.error("Verfuegbare Items:")
        for _, m in ipairs(MONSTER_DB) do
            for _, d in ipairs(m.drops) do
                log.error("  %s -> %s (ID:%d)", m.name, utils.displayName(d.name), d.id)
            end
        end
        return
    end

    local mobName   = monster.name
    local mobLabel  = utils.displayName(monster.name)
    local waypoints = monster.waypoints

    log.info("Farm: %d x '%s' (ID:%d)", FARM_QTY, farmItemName, farmItemId)
    log.info("Monster: %s | Waypoints: %d", mobLabel, #waypoints)
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
