-- ======================================================================
-- SND Logger Module
-- Zentrales Logging mit Level-Filterung
-- ======================================================================
local M = {}

local LEVELS = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

-- Standard: INFO (kann vom Hauptskript überschrieben werden)
M.level = "INFO"

--- Formatiert und gibt eine Log-Nachricht aus.
-- DEBUG-Nachrichten gehen nur an Dalamud.Log, alles andere auch in den Chat.
-- @param level string Log-Level (DEBUG, INFO, WARN, ERROR)
-- @param msg string Format-String (string.format-kompatibel)
-- @param ... any Format-Argumente
function M.log(level, msg, ...)
    if (LEVELS[level] or 0) < (LEVELS[M.level] or 1) then return end

    local formatted = msg
    local argCount = select('#', ...)
    if argCount > 0 then
        local args = {}
        for i = 1, argCount do
            args[i] = tostring(select(i, ...))
        end
        local ok, result = pcall(string.format, msg, table.unpack(args))
        formatted = ok and result or (msg .. " [ARGS: " .. table.concat(args, ", ") .. "]")
    end

    if level == "DEBUG" then
        -- Debug nur ins Dalamud-Log, nicht in den Chat
        pcall(function() Dalamud.Log("[SND] " .. formatted) end)
    else
        yield("/echo [" .. level .. "] " .. formatted)
    end
end

function M.debug(msg, ...) M.log("DEBUG", msg, ...) end
function M.info(msg, ...)  M.log("INFO",  msg, ...) end
function M.warn(msg, ...)  M.log("WARN",  msg, ...) end
function M.error(msg, ...) M.log("ERROR", msg, ...) end

return M
