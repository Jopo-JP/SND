-- ======================================================================
-- SND Entity Module
-- Wrapper für Spieler/Target-Zugriff mit Fehlerbehandlung
-- ======================================================================
local log = require("lib/logger")

local M = {}

--- Liest die Position einer Entity (Player oder Target).
-- @param entity userdata Entity.Player oder Entity.Target
-- @return table|nil {x, y, z} oder nil bei Fehler
local function getEntityPos(entity)
    local ok, pos = pcall(function()
        local p = entity.Position
        return { x = p.X, y = p.Y, z = p.Z }
    end)
    return ok and pos or nil
end

--- Gibt die Spielerposition zurück.
-- @return table|nil {x, y, z}
function M.getPlayerPos()
    local ok, player = pcall(function() return Entity.Player end)
    if not ok or not player then return nil end
    return getEntityPos(player)
end

--- Gibt die Target-Position zurück.
-- @return table|nil {x, y, z}
function M.getTargetPos()
    local ok, target = pcall(function() return Entity.Target end)
    if not ok or not target then return nil end
    return getEntityPos(target)
end

--- Prüft ob der Spieler im Kampf ist.
-- @return boolean
function M.isInCombat()
    local ok, val = pcall(function() return Entity.Player.IsInCombat end)
    return ok and val == true
end

--- Prüft ob der Spieler tot ist (HP == 0).
-- @return boolean
function M.isDead()
    local ok, hp = pcall(function() return Entity.Player.CurrentHp end)
    return ok and hp ~= nil and tonumber(hp) == 0
end

--- Prüft ob ein Target selektiert ist.
-- @return boolean
function M.hasTarget()
    local ok, t = pcall(function() return Entity.Target end)
    return ok and t ~= nil
end

--- Prüft ob das aktuelle Target tot ist.
-- @return boolean
function M.targetIsDead()
    local ok, hp = pcall(function() return Entity.Target.CurrentHp end)
    if not ok then return true end  -- kein Target = "tot"
    return hp ~= nil and tonumber(hp) == 0
end

return M
