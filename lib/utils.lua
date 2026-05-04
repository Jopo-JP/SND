-- ======================================================================
-- SND Utility Module
-- Allgemeine Hilfsfunktionen: Safe-Call, Distanz, String-Matching
-- ======================================================================
local log = require("lib/logger")

local M = {}

--- Sicherer Funktionsaufruf mit Fehlerprotokollierung.
-- Fängt Fehler ab und gibt Stacktrace ins Log aus.
-- @param label string Beschreibung für Fehlermeldungen
-- @param fn function Auszuführende Funktion
-- @return boolean ok, any result
function M.safeCall(label, fn, ...)
    local args = {...}
    local ok, result = xpcall(
        function() return fn(table.unpack(args)) end,
        function(err) return debug.traceback(tostring(err), 2) end
    )
    if not ok then
        log.error("FEHLER in [%s]:", label)
        for line in tostring(result):gmatch("[^\n]+") do
            yield("/echo [TRACE] " .. line)
        end
        return false, nil
    end
    return true, result
end

--- 3D-Distanz zwischen Position-Table und Koordinaten.
-- @param pos table {x, y, z}
-- @param x2 number
-- @param y2 number
-- @param z2 number
-- @return number Distanz
function M.dist(pos, x2, y2, z2)
    local dx = pos.x - x2
    local dy = pos.y - y2
    local dz = pos.z - z2
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- 3D-Distanz zwischen zwei Position-Tables.
-- @param a table {x, y, z}
-- @param b table {x, y, z}
-- @return number Distanz
function M.distBetween(a, b)
    return M.dist(a, b.x, b.y, b.z)
end

--- Case-insensitive Plain-Text-Suche (sicher für Umlaute/Sonderzeichen).
-- @param haystack string Text in dem gesucht wird
-- @param needle string Suchbegriff
-- @return boolean
function M.matchName(haystack, needle)
    return string.find(
        string.lower(tostring(haystack)),
        string.lower(tostring(needle)),
        1, true  -- plain-text mode, kein Pattern-Matching
    ) ~= nil
end

return M
