--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 0.0.1
description: >-
  Farm Script v5.1 - Modular Monster Database

  Fix: string.find plain-text mode für Umlaute/Sonderzeichen
plugin_dependencies:
- BossModReborn
- SomethingNeedDoing
- vnavmesh
- RotationSolver

[[End Metadata]]
--]=====]
-- ======================================================================
-- ===== MONSTER DATABASE - HIER MONSTER EINTRAGEN ======================
-- ======================================================================
local MONSTER_DB = {
    {
        name = "Glitscher",
        waypoints = {
            {x=-49.8, y=-47.2, z=420.9},
            {x=-42.1, y=-48.8, z=417.5},
            {x=-23.9, y=-45.9, z=414.4},
            {x=-16.9, y=-52.1, z=438.3},
            {x=-27.1, y=-55.1, z=464.1},
            {x=-31.4, y=-54.0, z=493.9},
        },
        drops = {
            {name = "Ätzendes Sekret", id = 5496},
        },
    },
    {
        name = "Glotzauge",
        waypoints = {
            {x=414.3, y=174.6, z=454.5},
            {x=449.5, y=170.6, z=431.7},
            {x=451.4, y=168.9, z=419.2},
            {x=434.9, y=174.8, z=385.7},
            {x=475.2, y=164.2, z=356.0},
            {x=449.7, y=164.7, z=307.8},
            {x=414.4, y=168.5, z=269.0},
            {x=367.6, y=166.0, z=241.8},
            {x=337.0, y=171.1, z=226.0},
        },
        drops = {
            {name = "Glotzaugen-Tränen", id = 12628},
        },
    },
    -- ===== WEITERE MONSTER HIER EINFÜGEN =====
}

-- ======================================================================
-- ===== FARM TARGET - WAS WILLST DU FARMEN? ============================
-- ======================================================================
local FARM_ITEM = "Glotzaugen-Tränen"   -- Item-Name (string) ODER Item-ID (number)
local FARM_QTY  = 100                    -- Wie viele Items TOTAL

-- ======================================================================
-- ===== GLOBALE EINSTELLUNGEN ==========================================
-- ======================================================================
local PULL_SKILL       = "Tomahawk"
local KILL_RANGE       = 15
local SCAN_RANGE       = 35
local DETECTION_RANGE  = 25
local MOVE_TIMEOUT     = 30
local MAX_RETRIES      = 3
local MAX_PULL_ATTEMPTS = 3
local LOG_LEVEL        = "DEBUG"

-- ======================================================================
-- ===== AB HIER NICHTS ÄNDERN ==========================================
-- ======================================================================

-- ===== PROFIL AUFLÖSUNG =====
local farmItemId = 0
local farmItemName = ""
local activeMonster = nil

local function ResolveFarmTarget()
    if type(FARM_ITEM) == "number" then
        farmItemId = FARM_ITEM
        local ok, row = pcall(function() return Excel.GetRow("Item", farmItemId) end)
        if ok and row then
            local okN, n = pcall(function() return row.Name end)
            if okN and n then farmItemName = tostring(n) end
        end
        farmItemName = farmItemName ~= "" and farmItemName or ("Item#" .. tostring(farmItemId))

        for _, m in ipairs(MONSTER_DB) do
            for _, d in ipairs(m.drops) do
                if d.id == farmItemId then
                    activeMonster = m
                    return true
                end
            end
        end
    else
        farmItemName = FARM_ITEM
        local searchLower = string.lower(FARM_ITEM)
        for _, m in ipairs(MONSTER_DB) do
            for _, d in ipairs(m.drops) do
                -- FIX: , 1, true = Plain-Text-Suche (kein Pattern-Matching!)
                if string.find(string.lower(d.name), searchLower, 1, true) then
                    activeMonster = m
                    farmItemId = d.id
                    return true
                end
            end
        end
    end
    return false
end

-- ===== GLOBALS =====
local kills = 0
local startItemCount = 0
local MOB_NAME = ""
local waypoints = {}

-- ===== LOGGER =====
local _lvl = {DEBUG=1, INFO=2, WARN=3, ERROR=4}

local function LOG(level, msg, ...)
    if (_lvl[level] or 0) < (_lvl[LOG_LEVEL] or 1) then return end
    local argCount = select('#', ...)
    local formatted = msg
    if argCount > 0 then
        local safeArgs = {}
        for i = 1, argCount do
            safeArgs[i] = tostring(select(i, ...))
        end
        local ok, result = pcall(string.format, msg, table.unpack(safeArgs))
        formatted = ok and result or (msg .. " [ARGS: " .. table.concat(safeArgs, ", ") .. "]")
    end
    yield("/echo [" .. level .. "] " .. formatted)
end

local function LOGI(m,...) LOG("INFO",  m,...) end
local function LOGD(m,...) LOG("DEBUG", m,...) end
local function LOGW(m,...) LOG("WARN",  m,...) end
local function LOGE(m,...) LOG("ERROR", m,...) end

-- ===== SAFE CALL =====
local function SC(label, fn, ...)
    local args = {...}
    local ok, result = xpcall(
        function() return fn(table.unpack(args)) end,
        function(err) return debug.traceback(tostring(err), 2) end
    )
    if not ok then
        LOGE("FEHLER in [%s]:", label)
        for line in tostring(result):gmatch("[^\n]+") do
            yield("/echo [TRACE] " .. line)
        end
        return false, nil
    end
    return true, result
end

-- ===== POSITION =====
local function GetPos()
    local ok, p = SC("Entity.Player", function() return Entity.Player end)
    if not ok or p == nil then return nil end
    local okPos, pos = SC("Player.Position", function() return p.Position end)
    if not okPos or pos == nil then return nil end
    local okX, x = SC("Position.X", function() return pos.X end)
    local okY, y = SC("Position.Y", function() return pos.Y end)
    local okZ, z = SC("Position.Z", function() return pos.Z end)
    if okX and okY and okZ and x and y and z then
        return {x=tonumber(x), y=tonumber(y), z=tonumber(z)}
    end
    return nil
end

local function GetTargetPos()
    local ok, t = SC("Entity.Target", function() return Entity.Target end)
    if not ok or t == nil then return nil end
    local okPos, pos = SC("Target.Position", function() return t.Position end)
    if not okPos or pos == nil then return nil end
    local okX, x = SC("TPosition.X", function() return pos.X end)
    local okY, y = SC("TPosition.Y", function() return pos.Y end)
    local okZ, z = SC("TPosition.Z", function() return pos.Z end)
    if okX and okY and okZ and x and y and z then
        return {x=tonumber(x), y=tonumber(y), z=tonumber(z)}
    end
    return nil
end

local function Dist(p, x2, y2, z2)
    local dx, dy, dz = (p.x-x2), (p.y-y2), (p.z-z2)
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- ===== STATUS =====
local function IsInCombat()
    local ok, p = SC("Entity.Player", function() return Entity.Player end)
    if not ok or p == nil then return false end
    local okC, val = SC("IsInCombat", function() return p.IsInCombat end)
    return okC and val == true
end

local function IsDead()
    local ok, p = SC("Entity.Player", function() return Entity.Player end)
    if not ok or p == nil then return false end
    local okH, hp = SC("CurrentHp", function() return p.CurrentHp end)
    return okH and hp ~= nil and tonumber(hp) == 0
end

local function IsMoving()
    local ok, v = SC("IPC.vnavmesh.IsRunning", function() return IPC.vnavmesh.IsRunning() end)
    return ok and v == true
end

local function HasTarget()
    local ok, t = SC("Entity.Target", function() return Entity.Target end)
    return ok and t ~= nil
end

local function TargetIsDead()
    local ok, t = SC("Entity.Target", function() return Entity.Target end)
    if not ok or t == nil then return true end
    local okH, hp = SC("Target.CurrentHp", function() return t.CurrentHp end)
    return okH and hp ~= nil and tonumber(hp) == 0
end

local function StopMove()
    SC("IPC.vnavmesh.Stop", function() IPC.vnavmesh.Stop() end)
end

-- ===== ITEM COUNTING =====
local function GetItemCountFast(itemId)
    local ok, count = SC("Inventory.GetItemCount", function()
        return Inventory.GetItemCount(itemId)
    end)
    return ok and tonumber(count) or 0
end

local function FindItemIdInInventory(itemName)
    LOGI("Suche '%s' im Inventar...", itemName)
    local bags = {"Inventory1", "Inventory2", "Inventory3", "Inventory4",
                  "EquippedItems", "Crystals", "Currency", "KeyItems"}
    local lower = string.lower(itemName)

    for _, bagName in ipairs(bags) do
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
                            local name = ""
                            local okName, nameRow = pcall(function() return Excel.GetRow("Item", id) end)
                            if okName and nameRow then
                                local okN, n = pcall(function() return nameRow.Name end)
                                if okN then name = tostring(n) end
                            end
                            -- FIX: , 1, true = Plain-Text!
                            if string.find(string.lower(name), lower, 1, true) then
                                LOGI("Gefunden: '%s' ID=%s", name, tostring(id))
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

local function FindItemIdInExcel(itemName)
    LOGI("Suche '%s' im Excel Item-Sheet (dauert ca. 15s)...", itemName)
    local searchLower = string.lower(itemName)
    local batchSize = 2000
    local endId = 40000

    for batchStart = 0, endId, batchSize do
        local batchEnd = math.min(batchStart + batchSize - 1, endId)
        for id = batchStart, batchEnd do
            local ok, row = pcall(function() return Excel.GetRow("Item", id) end)
            if ok and row then
                local okN, name = pcall(function() return row.Name end)
                if okN and name then
                    local nStr = tostring(name)
                    -- FIX: , 1, true = Plain-Text!
                    if string.find(string.lower(nStr), searchLower, 1, true) then
                        LOGI("Gefunden: '%s' ID=%s", nStr, tostring(id))
                        return id
                    end
                end
            end
        end
        yield("/wait 0.05")
    end
    return nil
end

local function ResolveItemId()
    if farmItemId > 0 then
        LOGI("Item-ID bekannt: %s = %s", farmItemName, tostring(farmItemId))
        return true
    end

    local invId = FindItemIdInInventory(farmItemName)
    if invId then
        farmItemId = invId
        return true
    end

    local excelId = FindItemIdInExcel(farmItemName)
    if excelId then
        farmItemId = excelId
        return true
    end

    LOGE("Item '%s' NICHT gefunden!", farmItemName)
    LOGE("Loesung: item_id in MONSTER_DB manuell setzen (z.B. von garlandtools.org)")
    return false
end

local function CurrentItemCount()
    if farmItemId == nil or farmItemId == 0 then return 0 end
    return GetItemCountFast(farmItemId)
end

local function IsDone()
    return CurrentItemCount() >= FARM_QTY
end

-- ===== NAVMESH =====
local function MeshCheck()
    local ok, ready = SC("IPC.vnavmesh.IsReady", function() return IPC.vnavmesh.IsReady() end)
    if ok and ready then return true end
    LOGW("Navmesh nicht bereit - Rebuild...")
    yield("/vnav rebuild")
    local waited = 0
    while true do
        yield("/wait 1")
        waited = waited + 1
        local okR, r = SC("IPC.vnavmesh.IsReady.wait", function() return IPC.vnavmesh.IsReady() end)
        if okR and r then break end
        if waited > 60 then
            LOGE("Navmesh Rebuild Timeout!")
            return false
        end
    end
    LOGI("Navmesh fertig!")
    return true
end

-- ===== BEWEGUNG =====
local function MoveTo(x, y, z, retries)
    retries = retries or 0
    LOGD("MoveTo %.1f/%.1f/%.1f (Versuch %s)", x, y, z, tostring(retries + 1))

    if not MeshCheck() then return false end

    yield("/vnav moveto " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z))
    yield("/wait 0.8")

    if not IsMoving() then
        if retries < MAX_RETRIES then
            LOGW("IsRunning=false - Retry...")
            yield("/wait 1")
            return MoveTo(x, y, z, retries + 1)
        else
            LOGE("Max Retries - weitergehen.")
            return false
        end
    end

    local timeout = 0
    while IsMoving() do
        if IsInCombat() then
            LOGI("Kampf beim Laufen! Stoppe.")
            StopMove()
            return true
        end

        yield("/target " .. MOB_NAME)
        if HasTarget() then
            local tPos = GetTargetPos()
            local myPos = GetPos()
            if tPos and myPos then
                local d = Dist(myPos, tPos.x, tPos.y, tPos.z)
                if d <= DETECTION_RANGE then
                    LOGI("Mob erkannt (%.0fy)! Stoppe.", d)
                    StopMove()
                    return true
                end
            end
        end

        timeout = timeout + 1
        if timeout > (MOVE_TIMEOUT * 5) then
            LOGE("MoveTo Timeout!")
            StopMove()
            return false
        end
        yield("/wait 0.2")
    end

    local pos = GetPos()
    if pos then
        local d = Dist(pos, x, y, z)
        if d > 3.0 and retries < MAX_RETRIES then
            return MoveTo(x, y, z, retries + 1)
        end
    end
    return false
end

-- ===== ZUM MOB LAUFEN =====
local function WalkToTarget()
    local maxSteps = 50
    local step = 0

    while step < maxSteps do
        step = step + 1
        local tPos = GetTargetPos()
        local myPos = GetPos()
        if not tPos or not myPos then return false end

        local d = Dist(myPos, tPos.x, tPos.y, tPos.z)
        if d <= KILL_RANGE then
            LOGD("In Kill-Range (%.1fy)!", d)
            return true
        end

        yield("/target " .. MOB_NAME)
        if not HasTarget() then
            LOGW("Target verloren!")
            return false
        end

        LOGD("Laufe zum Target... %.1fy", d)
        yield("/vnav moveto " .. tostring(tPos.x) .. " " .. tostring(tPos.y) .. " " .. tostring(tPos.z))
        yield("/wait 0.5")

        if IsInCombat() then
            LOGI("Kampf gestartet!")
            StopMove()
            return true
        end

        if not IsMoving() then
            local newPos = GetPos()
            local newT = GetTargetPos()
            if newPos and newT then
                if Dist(newPos, newT.x, newT.y, newT.z) <= KILL_RANGE then return true end
            end
        end

        yield("/wait 0.3")
    end

    LOGW("WalkToTarget: Max Steps!")
    return false
end

-- ===== KAMPF ABWARTEN =====
local function WaitCombatEnd()
    LOGI("Warte auf Kampfende...")
    local t = 0
    while IsInCombat() do
        yield("/wait 0.5")
        t = t + 1
        if t > 600 then
            LOGE("Kampf nach 5min nicht beendet!")
            break
        end
    end
    LOGI("Kampf beendet.")
    yield("/wait 0.8")
end

-- ===== MOB KILLEN =====
local function KillTarget()
    if not HasTarget() then return false end

    if not WalkToTarget() then
        LOGW("Konnte nicht zum Target laufen!")
    end

    local pullAttempt = 0
    while pullAttempt < MAX_PULL_ATTEMPTS do
        pullAttempt = pullAttempt + 1
        LOGI("Werfe %s! (Versuch %s)", PULL_SKILL, tostring(pullAttempt))
        yield("/ac \"" .. PULL_SKILL .. "\"")
        yield("/wait 1.0")

        if IsInCombat() then
            LOGI("Kampf gestartet! Warte auf Kill...")
            WaitCombatEnd()
            return true
        end

        LOGW("Kein Kampf nach Versuch %s", tostring(pullAttempt))

        yield("/target " .. MOB_NAME)
        if not HasTarget() then
            LOGW("Target weg - wahrscheinlich tot.")
            return false
        end

        if TargetIsDead() then
            LOGI("Target bereits tot!")
            return true
        end

        WalkToTarget()
    end

    LOGW("Konnte nicht killen nach %s Versuchen.", tostring(MAX_PULL_ATTEMPTS))
    return false
end

-- ===== AREA CLEAR =====
local function ScanAndKill()
    local areaKills = 0

    while not IsDone() do
        yield("/target " .. MOB_NAME)
        yield("/wait 0.3")

        if not HasTarget() then
            LOGD("Kein weiterer Mob im Umkreis.")
            break
        end

        local tPos = GetTargetPos()
        local myPos = GetPos()
        if tPos and myPos then
            local d = Dist(myPos, tPos.x, tPos.y, tPos.z)
            if d > SCAN_RANGE then
                LOGD("Mob zu weit (%.0fy) - weitergehen", d)
                break
            end
        end

        local killed = KillTarget()
        if killed then
            areaKills = areaKills + 1
            kills = kills + 1

            local curItems = CurrentItemCount()
            local collected = curItems - startItemCount
            local needed = FARM_QTY - startItemCount
            LOGI("Kill %s | %s: %s/%s (Total: %s)", tostring(kills), farmItemName, tostring(collected), tostring(needed), tostring(curItems))
        else
            LOGW("Kill fehlgeschlagen - weitergehen.")
            break
        end
    end

    return areaKills
end

-- ===== SHUTDOWN =====
local function Shutdown()
    LOGI("=== SHUTDOWN ===")
    StopMove()
    yield("/rsr off")
    yield("/wait 0.3")
    yield("/bmrai off")
    yield("/wait 0.3")
    local curItems = CurrentItemCount()
    local collected = curItems - startItemCount
    LOGI("FERTIG! %s x '%s' gesammelt (Total: %s)", tostring(collected), farmItemName, tostring(curItems))
    LOGI("Kills gesamt: %s | Monster: %s", tostring(kills), MOB_NAME)
end

-- ===== MAIN =====
local ok, err = xpcall(function()

    LOGI("=== FARM v5.1 ===")

    local found = ResolveFarmTarget()
    if not found or not activeMonster then
        LOGE("ABBRUCH: Kein Monster fuer '%s' in MONSTER_DB gefunden!", tostring(FARM_ITEM))
        LOGE("Verfuegbare Items:")
        for _, m in ipairs(MONSTER_DB) do
            for _, d in ipairs(m.drops) do
                LOGE("  %s -> %s (ID:%s)", m.name, d.name, tostring(d.id))
            end
        end
        return
    end

    MOB_NAME = activeMonster.name
    waypoints = activeMonster.waypoints

    LOGI("Farm: %s x '%s' (ID:%s)", tostring(FARM_QTY), farmItemName, tostring(farmItemId))
    LOGI("Monster: %s | Waypoints: %s", MOB_NAME, tostring(#waypoints))
    LOGI("Pull: %s | Kill-Range: %sy | Scan: %sy", PULL_SKILL, tostring(KILL_RANGE), tostring(SCAN_RANGE))

    local startPos = GetPos()
    if not startPos then
        LOGE("ABBRUCH: Spieler nicht lesbar!")
        return
    end
    LOGI("Position: X=%.1f Y=%.1f Z=%.1f", startPos.x, startPos.y, startPos.z)

    if not MeshCheck() then
        LOGE("ABBRUCH: Navmesh nicht verfuegbar!")
        return
    end

    local okVnav, vnavOk = SC("IPC.IsInstalled.vnavmesh", function()
        return IPC.IsInstalled("vnavmesh")
    end)
    if not vnavOk then
        LOGE("ABBRUCH: vnavmesh IPC nicht registriert!")
        return
    end
    LOGI("vnavmesh: OK")

    if not ResolveItemId() then
        LOGE("ABBRUCH: Item-ID nicht gefunden!")
        return
    end

    startItemCount = CurrentItemCount()
    local needed = FARM_QTY - startItemCount
    LOGI("Aktuell: %s x '%s'", tostring(startItemCount), farmItemName)
    if needed <= 0 then
        LOGI("Bereits genug! (%s >= %s)", tostring(startItemCount), tostring(FARM_QTY))
        return
    end
    LOGI("Brauche noch %s x '%s'", tostring(needed), farmItemName)

    LOGI("Aktiviere RSR + BossModAI...")
    yield("/rsr auto")
    yield("/wait 0.5")
    yield("/bmrai on")
    yield("/wait 0.5")

    LOGI("Startup OK! Starte Farm-Loop...")

    local wpIdx = 1

    while not IsDone() do
        local areaKills = ScanAndKill()

        if IsDone() then break end

        local wp = waypoints[wpIdx]
        LOGD("Laufe zu Waypoint %s: %.1f/%.1f/%.1f", tostring(wpIdx), wp.x, wp.y, wp.z)
        MoveTo(wp.x, wp.y, wp.z)
        wpIdx = (wpIdx % #waypoints) + 1
    end

    Shutdown()

end, function(e)
    return debug.traceback(tostring(e), 2)
end)

if not ok then
    yield("/echo [FATAL] === SCRIPT CRASH ===")
    for line in tostring(err):gmatch("[^\n]+") do
        yield("/echo [FATAL] " .. line)
    end
    pcall(StopMove)
    yield("/rsr off")
    yield("/bmrai off")
end
