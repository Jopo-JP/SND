-- ======================================================================
-- SND Combat Module
-- Kampflogik: Pull, Kill, Area-Clear
-- ======================================================================
local log    = require("lib/logger")
local entity = require("lib/entity")
local nav    = require("lib/nav")
local utils  = require("lib/utils")

local M = {}

-- Konfigurierbare Werte
M.PULL_SKILL       = "Tomahawk"
M.KILL_RANGE       = 15
M.SCAN_RANGE       = 35
M.MAX_PULL_ATTEMPTS = 3
M.COMBAT_TIMEOUT   = 300  -- Sekunden (5 Minuten)

--- Wartet bis der Kampf beendet ist.
-- @return nil
function M.waitCombatEnd()
    log.info("Warte auf Kampfende...")
    local ticks = 0
    local maxTicks = M.COMBAT_TIMEOUT * 2  -- bei 0.5s Intervall

    while entity.isInCombat() do
        yield("/wait 0.5")
        ticks = ticks + 1
        if ticks > maxTicks then
            log.error("Kampf nach %ds nicht beendet!", M.COMBAT_TIMEOUT)
            break
        end
    end

    log.info("Kampf beendet.")
    yield("/wait 0.8")
end

--- Versucht das aktuelle Target zu töten.
-- Läuft zum Mob, benutzt Pull-Skill, wartet auf Kampfende.
-- @param mobName string Mob-Name für Re-Targeting
-- @return boolean, string Kill erfolgreich und Status
function M.killTarget(mobName)
    if not entity.hasTarget() then return false, "no_target" end

    local reached, walkStatus = nav.walkToTarget(mobName, M.KILL_RANGE)
    if not reached then
        if walkStatus == "dead" then
            log.info("Target starb vor Kampfbeginn.")
            return false, "dead"
        end
        if walkStatus == "lost" then
            log.warn("Target verloren.")
            return false, "lost"
        end
        log.warn("Konnte nicht zum Target laufen!")
        return false, walkStatus or "failed"
    end

    for attempt = 1, M.MAX_PULL_ATTEMPTS do
        log.info("Werfe %s! (Versuch %d)", M.PULL_SKILL, attempt)
        yield("/ac \"" .. M.PULL_SKILL .. "\"")
        yield("/wait 1.0")

        if entity.isInCombat() then
            log.info("Kampf gestartet! Warte auf Kill...")
            M.waitCombatEnd()
            return true, "killed"
        end

        log.warn("Kein Kampf nach Versuch %d", attempt)

        utils.tryTargetByName(mobName)
        if not entity.hasTarget() then
            log.warn("Target weg - wahrscheinlich tot.")
            return false, "lost"
        end

        if entity.targetIsDead() then
            log.info("Target bereits tot!")
            return false, "dead"
        end

        local moved, status = nav.walkToTarget(mobName, M.KILL_RANGE)
        if not moved and status == "dead" then
            return false, "dead"
        end
    end

    log.warn("Konnte nicht killen nach %d Versuchen.", M.MAX_PULL_ATTEMPTS)
    return false, "failed"
end

--- Scannt die Umgebung und tötet alle Mobs im Scan-Range.
-- @param mobName string Mob-Name zum Targeting
-- @param isDoneFn function Callback das prüft ob Farm-Ziel erreicht
-- @param onKillFn function|nil Callback nach jedem Kill (optional)
-- @param scanCenter table|nil Optionaler Ankerpunkt {x, y, z} fuer den Clear-Bereich
-- @return number Anzahl Kills in dieser Runde
function M.scanAndKill(mobName, isDoneFn, onKillFn, scanCenter)
    local areaKills = 0

    while not isDoneFn() do
        utils.tryTargetByName(mobName)
        yield("/wait 0.3")

        if not entity.hasTarget() then
            log.debug("Kein weiterer Mob im Umkreis.")
            break
        end

        local tPos = entity.getTargetPos()
        local origin = scanCenter or entity.getPlayerPos()
        if tPos and origin then
            local d = utils.distBetween(origin, tPos)
            if d > M.SCAN_RANGE then
                log.debug("Mob zu weit (%.0fy) - weitergehen", d)
                break
            end
        end

        local killed, status = M.killTarget(mobName)
        if killed then
            areaKills = areaKills + 1
            if onKillFn then onKillFn(areaKills) end
        elseif status == "dead" or status == "lost" or status == "no_target" then
            log.debug("Target nicht mehr gueltig (%s) - suche naechsten Mob.", status)
            yield("/wait 0.2")
        else
            log.warn("Kill fehlgeschlagen - weitergehen.")
            break
        end
    end

    return areaKills
end

return M
