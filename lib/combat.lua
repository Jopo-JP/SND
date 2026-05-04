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
-- @return boolean Kill erfolgreich
function M.killTarget(mobName)
    if not entity.hasTarget() then return false end

    if not nav.walkToTarget(mobName, M.KILL_RANGE) then
        log.warn("Konnte nicht zum Target laufen!")
    end

    for attempt = 1, M.MAX_PULL_ATTEMPTS do
        log.info("Werfe %s! (Versuch %d)", M.PULL_SKILL, attempt)
        yield("/ac \"" .. M.PULL_SKILL .. "\"")
        yield("/wait 1.0")

        if entity.isInCombat() then
            log.info("Kampf gestartet! Warte auf Kill...")
            M.waitCombatEnd()
            return true
        end

        log.warn("Kein Kampf nach Versuch %d", attempt)

        yield("/target " .. mobName)
        if not entity.hasTarget() then
            log.warn("Target weg - wahrscheinlich tot.")
            return false
        end

        if entity.targetIsDead() then
            log.info("Target bereits tot!")
            return true
        end

        nav.walkToTarget(mobName, M.KILL_RANGE)
    end

    log.warn("Konnte nicht killen nach %d Versuchen.", M.MAX_PULL_ATTEMPTS)
    return false
end

--- Scannt die Umgebung und tötet alle Mobs im Scan-Range.
-- @param mobName string Mob-Name zum Targeting
-- @param isDoneFn function Callback das prüft ob Farm-Ziel erreicht
-- @param onKillFn function|nil Callback nach jedem Kill (optional)
-- @return number Anzahl Kills in dieser Runde
function M.scanAndKill(mobName, isDoneFn, onKillFn)
    local areaKills = 0

    while not isDoneFn() do
        yield("/target " .. mobName)
        yield("/wait 0.3")

        if not entity.hasTarget() then
            log.debug("Kein weiterer Mob im Umkreis.")
            break
        end

        local tPos = entity.getTargetPos()
        local myPos = entity.getPlayerPos()
        if tPos and myPos then
            local d = utils.distBetween(myPos, tPos)
            if d > M.SCAN_RANGE then
                log.debug("Mob zu weit (%.0fy) - weitergehen", d)
                break
            end
        end

        if M.killTarget(mobName) then
            areaKills = areaKills + 1
            if onKillFn then onKillFn(areaKills) end
        else
            log.warn("Kill fehlgeschlagen - weitergehen.")
            break
        end
    end

    return areaKills
end

return M
