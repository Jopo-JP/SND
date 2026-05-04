-- ======================================================================
-- SND Navigation Module
-- Navmesh-Steuerung und Bewegung
-- ======================================================================
local log    = require("lib/logger")
local entity = require("lib/entity")
local utils  = require("lib/utils")

local M = {}

-- Konfigurierbare Werte (können vom Hauptskript überschrieben werden)
M.MOVE_TIMEOUT_SEC     = 30
M.MAX_RETRIES          = 3
M.MESH_REBUILD_TIMEOUT = 60   -- Sekunden
M.DETECTION_RANGE      = 25
M.ARRIVAL_THRESHOLD    = 3.0  -- yalms, ab wann "angekommen"

--- Prüft ob vnavmesh gerade eine Route läuft.
-- @return boolean
function M.isMoving()
    local ok, v = pcall(function() return IPC.vnavmesh.IsRunning() end)
    return ok and v == true
end

--- Stoppt die aktuelle Navmesh-Bewegung.
function M.stop()
    pcall(function() IPC.vnavmesh.Stop() end)
end

--- Prüft ob das Navmesh bereit ist, ggf. Rebuild.
-- @return boolean
function M.ensureMesh()
    local ok, ready = pcall(function() return IPC.vnavmesh.IsReady() end)
    if ok and ready then return true end

    log.warn("Navmesh nicht bereit - Rebuild...")
    yield("/vnav rebuild")

    for waited = 1, M.MESH_REBUILD_TIMEOUT do
        yield("/wait 1")
        local okR, r = pcall(function() return IPC.vnavmesh.IsReady() end)
        if okR and r then
            log.info("Navmesh fertig!")
            return true
        end
    end

    log.error("Navmesh Rebuild Timeout nach %ds!", M.MESH_REBUILD_TIMEOUT)
    return false
end

--- Bewegt den Spieler zu einer Position via Navmesh.
-- Bricht ab wenn ein Mob in DETECTION_RANGE erkannt wird oder Kampf startet.
-- @param x number Ziel X
-- @param y number Ziel Y
-- @param z number Ziel Z
-- @param mobName string|nil Mob-Name zum automatischen Targeting unterwegs
-- @param retries number|nil Interner Retry-Counter
-- @return string "arrived", "mob", "combat" oder "failed"
function M.moveTo(x, y, z, mobName, retries)
    retries = retries or 0
    log.debug("MoveTo %.1f/%.1f/%.1f (Versuch %d)", x, y, z, retries + 1)

    if not M.ensureMesh() then return "failed" end

    yield("/vnav moveto " .. tostring(x) .. " " .. tostring(y) .. " " .. tostring(z))
    yield("/wait 0.8")

    if not M.isMoving() then
        if retries < M.MAX_RETRIES then
            log.warn("IsRunning=false - Retry...")
            yield("/wait 1")
            return M.moveTo(x, y, z, mobName, retries + 1)
        else
            log.error("Max Retries erreicht - weitergehen.")
            return "failed"
        end
    end

    -- Warte bis Bewegung endet, prüfe unterwegs auf Mobs/Kampf
    local ticks = 0
    local maxTicks = M.MOVE_TIMEOUT_SEC * 5  -- bei 0.2s Intervall
    while M.isMoving() do
        if entity.isInCombat() then
            log.info("Kampf beim Laufen! Stoppe.")
            M.stop()
            return "combat"
        end

        if mobName then
            utils.tryTargetByName(mobName)
            if entity.hasTarget() then
                local tPos = entity.getTargetPos()
                local myPos = entity.getPlayerPos()
                if tPos and myPos then
                    local d = utils.distBetween(myPos, tPos)
                    if d <= M.DETECTION_RANGE then
                        log.info("Mob erkannt (%.0fy)! Stoppe.", d)
                        M.stop()
                        return "mob"
                    end
                end
            end
        end

        ticks = ticks + 1
        if ticks > maxTicks then
            log.error("MoveTo Timeout nach %ds!", M.MOVE_TIMEOUT_SEC)
            M.stop()
            return "failed"
        end
        yield("/wait 0.2")
    end

    -- Prüfe ob wir nah genug am Ziel sind
    local pos = entity.getPlayerPos()
    if pos then
        local d = utils.dist(pos, x, y, z)
        if d > M.ARRIVAL_THRESHOLD and retries < M.MAX_RETRIES then
            return M.moveTo(x, y, z, mobName, retries + 1)
        elseif d > M.ARRIVAL_THRESHOLD then
            return "failed"
        end
    end

    return "arrived"
end

--- Läuft zum aktuellen Target bis in Kill-Range.
-- @param mobName string Mob-Name für Re-Targeting
-- @param killRange number Distanz ab der gestoppt wird
-- @param maxSteps number|nil Max Iterationen (default 50)
-- @return boolean, string In Kill-Range/Kampf erreicht und Status
function M.walkToTarget(mobName, killRange, maxSteps)
    maxSteps = maxSteps or 50

    for step = 1, maxSteps do
        utils.tryTargetByName(mobName)
        if not entity.hasTarget() then
            M.stop()
            log.warn("Target verloren!")
            return false, "lost"
        end

        if entity.targetIsDead() then
            M.stop()
            log.debug("Target ist bereits tot.")
            return false, "dead"
        end

        local tPos = entity.getTargetPos()
        local myPos = entity.getPlayerPos()
        if not tPos or not myPos then
            M.stop()
            return false, "lost"
        end

        local d = utils.distBetween(myPos, tPos)
        if d <= killRange then
            log.debug("In Kill-Range (%.1fy)!", d)
            return true, "in_range"
        end

        log.debug("Laufe zum Target... %.1fy", d)
        yield("/vnav moveto " .. tostring(tPos.x) .. " " .. tostring(tPos.y) .. " " .. tostring(tPos.z))
        yield("/wait 0.5")

        if entity.isInCombat() then
            log.info("Kampf gestartet!")
            M.stop()
            return true, "combat"
        end

        if entity.targetIsDead() then
            M.stop()
            log.debug("Target starb waehrend des Anlaufs.")
            return false, "dead"
        end

        if not M.isMoving() then
            local newPos = entity.getPlayerPos()
            local newT = entity.getTargetPos()
            if newPos and newT and utils.distBetween(newPos, newT) <= killRange then
                return true, "in_range"
            end
        end

        yield("/wait 0.3")
    end

    log.warn("WalkToTarget: Max Steps erreicht!")
    M.stop()
    return false, "failed"
end

return M
