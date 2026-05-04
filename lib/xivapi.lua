-- ======================================================================
-- SND XIVAPI Client Module
-- HTTP-Client fuer https://v2.xivapi.com/api
--
-- Nutzt PowerShell Invoke-RestMethod via io.popen.
-- Blockiert kurz (~200ms), aber zuverlaessig auf allen Windows-Versionen.
-- ======================================================================
local json = require("lib/json")
local log  = require("lib/logger")

local M = {}

M.BASE_URL = "https://v2.xivapi.com/api"

local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

--- URL-Encoding fuer Query-Parameter (Sonderzeichen, Umlaute, Leerzeichen).
-- @param str string Zu kodierender String
-- @return string URL-kodierter String
local function urlEncode(str)
    return str:gsub("([^%w%-_.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

--- HTTP GET via PowerShell Invoke-RestMethod.
-- Die HTTP-Antwort wird als rohe UTF-8-Bytes gelesen und dann in Base64 ueber
-- stdout ausgegeben. So umgehen wir sowohl Console-Codepages als auch das
-- Re-Encoding von ConvertTo-Json fuer Unicode-Zeichen.
-- @param url string Vollstaendige URL
-- @return string|nil JSON-Body oder nil bei Fehler
local function base64Decode(data)
    local cleaned = data:gsub("%s+", "")
    cleaned = cleaned:gsub("[^" .. BASE64_CHARS .. "=]", "")

    return (cleaned:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (BASE64_CHARS:find(x, 1, true) or 1) - 1
        for i = 6, 1, -1 do
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
        end
        return string.char(c)
    end))
end

local function httpGet(url)
    log.debug("HTTP GET: %s", url)

    -- Wichtig: Wir lesen die HTTP-Response als Byte-Array und encodieren diese
    -- Bytes direkt als Base64. Damit bleibt die originale UTF-8-Antwort exakt
    -- erhalten und Lua bekommt danach wieder das unveraenderte JSON.
    local cmd = string.format(
        'powershell.exe -NoProfile -Command "try { [Convert]::ToBase64String((New-Object System.Net.WebClient).DownloadData(\'%s\')) } catch { \"ERROR:\" + $_.Exception.Message }"',
        url
    )

    local handle = io.popen(cmd, "r")
    if not handle then
        log.error("PowerShell konnte nicht gestartet werden")
        return nil
    end

    local body = handle:read("*a")
    handle:close()

    if not body or body == "" then
        log.error("Leere Antwort von XIVAPI")
        return nil
    end

    if body:match("^ERROR:") then
        log.error("XIVAPI Request fehlgeschlagen: %s", body)
        return nil
    end

    local ok, decoded = pcall(base64Decode, body)
    if not ok or not decoded or decoded == "" then
        log.error("Base64-Decode der XIVAPI-Antwort fehlgeschlagen")
        return nil
    end

    return decoded
end

--- Sucht Items per Name ueber die XIVAPI Search API.
-- Nutzt partial string match (Name~"suchbegriff").
-- @param name string Suchbegriff (Item-Name oder Teil davon)
-- @param language string|nil Sprache (default "de")
-- @param limit number|nil Max Ergebnisse (default 10)
-- @return table|nil Array von {id, name, score} oder nil bei Fehler
function M.searchItems(name, language, limit)
    language = language or "de"
    limit = limit or 10

    local query = 'Name~"' .. name .. '"'
    local url = string.format(
        "%s/search?sheets=Item&query=%s&fields=Name&language=%s&limit=%d",
        M.BASE_URL,
        urlEncode(query),
        urlEncode(language),
        limit
    )

    local body = httpGet(url)
    if not body then return nil end

    local ok, data = pcall(json.decode, body)
    if not ok or not data then
        log.error("JSON-Parse fehlgeschlagen: %s", tostring(data))
        return nil
    end

    if not data.results then
        log.warn("Keine Ergebnisse in API-Antwort")
        return {}
    end

    local results = {}
    for _, r in ipairs(data.results) do
        results[#results + 1] = {
            id    = r.row_id,
            name  = r.fields and r.fields.Name or ("Item#" .. r.row_id),
            score = r.score,
            sheet = r.sheet,
        }
    end

    return results
end

--- Liest ein einzelnes Item per ID von der XIVAPI.
-- @param itemId number Item-ID
-- @param language string|nil Sprache (default "de")
-- @return table|nil {id, name} oder nil
function M.getItem(itemId, language)
    language = language or "de"

    local url = string.format(
        "%s/sheet/Item/%d?fields=Name&language=%s",
        M.BASE_URL,
        itemId,
        urlEncode(language)
    )

    local body = httpGet(url)
    if not body then return nil end

    local ok, data = pcall(json.decode, body)
    if not ok or not data then return nil end

    return {
        id   = data.row_id,
        name = data.fields and data.fields.Name or ("Item#" .. itemId),
    }
end

--- Liest ein Item in allen 4 Sprachen (en, de, fr, ja).
-- @param itemId number Item-ID
-- @return table|nil {id, name={en, de, fr, ja}} oder nil
function M.getItemAllLanguages(itemId)
    local LANGS = { "en", "de", "fr", "ja" }
    local names = {}

    for _, lang in ipairs(LANGS) do
        local item = M.getItem(itemId, lang)
        if not item then
            log.error("XIVAPI-Abfrage fehlgeschlagen fuer Sprache '%s'", lang)
            return nil
        end
        names[lang] = item.name
    end

    return {
        id   = itemId,
        name = names,
    }
end

return M
