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

--- Prüft ob ein multilang Name-Table einen Suchbegriff enthält.
-- Durchsucht alle Sprachen (en, de, fr, ja).
-- Funktioniert auch wenn name ein einfacher String ist (Rückwärtskompatibel).
-- @param name string|table Name-String oder {en="...", de="...", ...}
-- @param search string Suchbegriff
-- @return boolean match, string|nil matchedLang
function M.matchMultiName(name, search)
    if type(name) == "string" then
        return M.matchName(name, search), nil
    end
    if type(name) == "table" then
        for lang, langName in pairs(name) do
            if M.matchName(langName, search) then
                return true, lang
            end
        end
    end
    return false, nil
end

--- Gibt einen Display-Namen aus einem multilang Name-Table zurück.
-- Bevorzugt: übergebene Sprache -> en -> erster verfügbarer Name.
-- Funktioniert auch mit einfachem String (Rückwärtskompatibel).
-- @param name string|table Name-String oder {en="...", de="...", ...}
-- @param lang string|nil Bevorzugte Sprache (default "de")
-- @return string
function M.displayName(name, lang)
    if type(name) == "string" then return name end
    if type(name) ~= "table" then return tostring(name) end
    lang = lang or "de"
    if name[lang] then return name[lang] end
    if name.en then return name.en end
    -- Fallback: erster verfügbarer Name
    for _, v in pairs(name) do return v end
    return "???"
end

--- Gibt eine geordnete Liste von Moeglichen Namen fuer /target zurueck.
-- Unterstuetzt String oder multilingualen Table.
-- Reihenfolge ist auf praktikable Target-Fallbacks optimiert.
-- @param name string|table Name-String oder {en="...", de="...", ...}
-- @return table Liste von Namen ohne Duplikate
function M.targetNameCandidates(name)
    if type(name) == "string" then return { name } end
    if type(name) ~= "table" then return { tostring(name) } end

    local order = { "en", "de", "fr", "ja" }
    local out = {}
    local seen = {}

    for _, lang in ipairs(order) do
        local value = name[lang]
        if value and value ~= "" and not seen[value] then
            out[#out + 1] = value
            seen[value] = true
        end
    end

    for _, value in pairs(name) do
        if value and value ~= "" and not seen[value] then
            out[#out + 1] = value
            seen[value] = true
        end
    end

    if #out == 0 then
        out[1] = ""
    end

    return out
end

--- Versucht nacheinander mehrere Moegliche /target Namen.
-- Bricht sofort ab, sobald ein Target gefunden wurde.
-- @param name string|table Name-String oder {en="...", de="...", ...}
-- @return boolean true wenn ein Target gefunden wurde
function M.tryTargetByName(name)
    for _, candidate in ipairs(M.targetNameCandidates(name)) do
        if candidate ~= "" then
            yield("/target " .. candidate)
            local ok, hasTarget = pcall(function() return Entity.Target ~= nil end)
            if ok and hasTarget then
                return true
            end
        end
    end
    return false
end

return M
