-- ======================================================================
-- Minimaler JSON-Decoder fuer SND
-- Unterstuetzt: objects, arrays, strings, numbers, booleans, null
-- Kein Encoder noetig (wir lesen nur API-Antworten)
-- ======================================================================
local M = {}

local function skipWhitespace(str, pos)
    return str:match("^%s*()", pos)
end

local function decodeString(str, pos)
    -- pos steht auf dem oeffnenden "
    pos = pos + 1
    local parts = {}
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c == '"' then
            return table.concat(parts), pos + 1
        elseif c == '\\' then
            pos = pos + 1
            local esc = str:sub(pos, pos)
            if esc == '"' then parts[#parts + 1] = '"'
            elseif esc == '\\' then parts[#parts + 1] = '\\'
            elseif esc == '/' then parts[#parts + 1] = '/'
            elseif esc == 'n' then parts[#parts + 1] = '\n'
            elseif esc == 'r' then parts[#parts + 1] = '\r'
            elseif esc == 't' then parts[#parts + 1] = '\t'
            elseif esc == 'b' then parts[#parts + 1] = '\b'
            elseif esc == 'f' then parts[#parts + 1] = '\f'
            elseif esc == 'u' then
                -- Unicode escape: \uXXXX -> als raw bytes durchlassen
                local hex = str:sub(pos + 1, pos + 4)
                local code = tonumber(hex, 16)
                if code and code < 128 then
                    parts[#parts + 1] = string.char(code)
                else
                    -- UTF-8 encoding fuer BMP characters
                    if code and code < 0x800 then
                        parts[#parts + 1] = string.char(
                            0xC0 + math.floor(code / 64),
                            0x80 + (code % 64)
                        )
                    elseif code then
                        parts[#parts + 1] = string.char(
                            0xE0 + math.floor(code / 4096),
                            0x80 + math.floor((code % 4096) / 64),
                            0x80 + (code % 64)
                        )
                    else
                        parts[#parts + 1] = "\\u" .. hex
                    end
                end
                pos = pos + 4
            end
            pos = pos + 1
        else
            parts[#parts + 1] = c
            pos = pos + 1
        end
    end
    error("JSON: unterminated string")
end

local decodeValue -- forward declaration

local function decodeObject(str, pos)
    pos = pos + 1  -- skip {
    local obj = {}
    pos = skipWhitespace(str, pos)
    if str:sub(pos, pos) == '}' then return obj, pos + 1 end

    while true do
        pos = skipWhitespace(str, pos)
        if str:sub(pos, pos) ~= '"' then
            error("JSON: expected string key at pos " .. pos)
        end
        local key
        key, pos = decodeString(str, pos)
        pos = skipWhitespace(str, pos)
        if str:sub(pos, pos) ~= ':' then
            error("JSON: expected ':' at pos " .. pos)
        end
        pos = skipWhitespace(str, pos + 1)
        local val
        val, pos = decodeValue(str, pos)
        obj[key] = val
        pos = skipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == '}' then return obj, pos + 1 end
        if c ~= ',' then error("JSON: expected ',' or '}' at pos " .. pos) end
        pos = pos + 1
    end
end

local function decodeArray(str, pos)
    pos = pos + 1  -- skip [
    local arr = {}
    pos = skipWhitespace(str, pos)
    if str:sub(pos, pos) == ']' then return arr, pos + 1 end

    while true do
        pos = skipWhitespace(str, pos)
        local val
        val, pos = decodeValue(str, pos)
        arr[#arr + 1] = val
        pos = skipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == ']' then return arr, pos + 1 end
        if c ~= ',' then error("JSON: expected ',' or ']' at pos " .. pos) end
        pos = pos + 1
    end
end

decodeValue = function(str, pos)
    pos = skipWhitespace(str, pos)
    local c = str:sub(pos, pos)

    if c == '"' then return decodeString(str, pos)
    elseif c == '{' then return decodeObject(str, pos)
    elseif c == '[' then return decodeArray(str, pos)
    elseif c == 't' then
        if str:sub(pos, pos + 3) == "true" then return true, pos + 4 end
    elseif c == 'f' then
        if str:sub(pos, pos + 4) == "false" then return false, pos + 5 end
    elseif c == 'n' then
        if str:sub(pos, pos + 3) == "null" then return nil, pos + 4 end
    elseif c == '-' or (c >= '0' and c <= '9') then
        local numStr = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
        return tonumber(numStr), pos + #numStr
    end

    error("JSON: unexpected character '" .. c .. "' at pos " .. pos)
end

--- Entfernt UTF-8 BOM falls vorhanden.
-- PowerShell schreibt auf aelteren Windows-Versionen eine BOM (EF BB BF).
-- @param str string Input
-- @return string Ohne BOM
local function stripBOM(str)
    if str:byte(1) == 0xEF and str:byte(2) == 0xBB and str:byte(3) == 0xBF then
        return str:sub(4)
    end
    return str
end

--- Dekodiert einen JSON-String in eine Lua-Tabelle.
-- @param str string JSON-String
-- @return any Lua-Wert (table, string, number, boolean, nil)
function M.decode(str)
    if not str or str == "" then return nil end
    str = stripBOM(str)
    local val, _ = decodeValue(str, 1)
    return val
end

return M
