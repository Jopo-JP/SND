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

--- URL-Encoding fuer Query-Parameter (Sonderzeichen, Umlaute, Leerzeichen).
-- @param str string Zu kodierender String
-- @return string URL-kodierter String
local function urlEncode(str)
    return str:gsub("([^%w%-_.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

--- HTTP GET via PowerShell Invoke-RestMethod.
-- Liest die Ausgabe direkt ueber stdout (io.popen), kein Temp-File noetig.
-- @param url string Vollstaendige URL
-- @return string|nil JSON-Body oder nil bei Fehler
local function httpGet(url)
    log.debug("HTTP GET: %s", url)

    -- PowerShell-Befehl:
    -- -NoProfile: Schnellerer Start
    -- -Command:   Invoke-RestMethod gibt direkt JSON zurueck
    -- [Console]::OutputEncoding sicherstellen dass UTF-8 ohne BOM auf stdout kommt
    local cmd = string.format(
        'powershell.exe -NoProfile -Command "[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); Invoke-RestMethod -Uri \'%s\' | ConvertTo-Json -Depth 10 -Compress"',
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

    return body
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

return M
