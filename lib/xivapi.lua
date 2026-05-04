-- ======================================================================
-- SND XIVAPI Client Module
-- Non-blocking HTTP-Client fuer https://v2.xivapi.com/api
--
-- Startet PowerShell als Hintergrund-Prozess (Start-Process -NoNewWindow)
-- und pollt die Antwort-Datei, damit der Game Main Thread frei bleibt.
-- ======================================================================
local json = require("lib/json")
local log  = require("lib/logger")

local M = {}

M.BASE_URL = "https://v2.xivapi.com/api"
M.TIMEOUT  = 10  -- Sekunden max. Wartezeit auf API-Antwort

--- URL-Encoding fuer Query-Parameter (Sonderzeichen, Umlaute, Leerzeichen).
-- @param str string Zu kodierender String
-- @return string URL-kodierter String
local function urlEncode(str)
    return str:gsub("([^%w%-_.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

--- Generiert einen eindeutigen Temp-Dateinamen.
-- @return string Pfad zur Temp-Datei
local function tempFile()
    local tmp = os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
    return tmp .. "\\snd_xivapi_" .. tostring(os.clock()):gsub("%.", "") .. ".json"
end

--- Startet einen HTTP GET als Hintergrund-Prozess via PowerShell.
-- Nutzt yield() zwischen den Poll-Versuchen, damit das Spiel nicht laggt.
-- @param url string Vollstaendige URL
-- @return string|nil Response-Body oder nil bei Fehler
local function httpGetAsync(url)
    local outFile = tempFile()
    log.debug("HTTP GET (async): %s", url)

    -- PowerShell-Befehl: Invoke-RestMethod schreibt direkt in Datei
    -- Start-Process -WindowStyle Hidden startet non-blocking
    local psScript = string.format(
        "try { Invoke-RestMethod -Uri '%s' | ConvertTo-Json -Depth 10 | Set-Content -Path '%s' -Encoding UTF8 } catch { Set-Content -Path '%s' -Value ('ERROR: ' + $_.Exception.Message) -Encoding UTF8 }",
        url, outFile, outFile
    )

    -- Starte PowerShell non-blocking: os.execute kehrt sofort zurueck
    local cmd = string.format(
        'powershell.exe -NoProfile -WindowStyle Hidden -Command "Start-Process powershell -ArgumentList \'-NoProfile\',\'-Command\',\'%s\' -WindowStyle Hidden"',
        psScript:gsub("'", "''")  -- single quotes escapen fuer verschachtelte PS-Aufrufe
    )

    os.execute(cmd)

    -- Warte non-blocking bis Datei existiert und Inhalt hat
    for i = 1, M.TIMEOUT * 5 do  -- alle 0.2s pruefen
        yield("/wait 0.2")

        local f = io.open(outFile, "r")
        if f then
            local body = f:read("*a")
            f:close()

            if body and #body > 0 then
                -- Fehler-Check
                if body:match("^ERROR:") then
                    log.error("XIVAPI Fehler: %s", body)
                    os.remove(outFile)
                    return nil
                end

                -- Pruefen ob JSON komplett ist (endet mit } oder ])
                local trimmed = body:match("^%s*(.-)%s*$")
                if trimmed and (#trimmed > 0) and (trimmed:sub(-1) == "}" or trimmed:sub(-1) == "]") then
                    os.remove(outFile)
                    log.debug("API-Antwort erhalten (%d bytes)", #body)
                    return body
                end
            end
        end
    end

    -- Timeout - aufraeumen
    log.error("XIVAPI Timeout nach %ds!", M.TIMEOUT)
    pcall(os.remove, outFile)
    return nil
end

--- Sucht Items per Name ueber die XIVAPI Search API.
-- Nutzt partial string match (Name~"suchbegriff").
-- Non-blocking: gibt dem Spiel zwischen Polls Zeit zum Rendern.
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

    local body = httpGetAsync(url)
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
-- Non-blocking.
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

    local body = httpGetAsync(url)
    if not body then return nil end

    local ok, data = pcall(json.decode, body)
    if not ok or not data then return nil end

    return {
        id   = data.row_id,
        name = data.fields and data.fields.Name or ("Item#" .. itemId),
    }
end

return M
