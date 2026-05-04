--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 2.0.0
description: >-
  Item-Suche via XIVAPI - Findet Item-IDs per Name ohne Lag.
  Nutzt https://v2.xivapi.com statt lokaler Excel-Sheets.
  Konfiguration ueber SND Config-UI.
configs:
  itemName:
    default: "Glotzaugen-Tränen"
    description: Name des Items das gesucht werden soll
    type: string
    required: true
  language:
    default: "de"
    description: Sprache (de, en, fr, ja)
    type: string
    required: false
  maxResults:
    default: 10
    description: Maximale Anzahl Ergebnisse
    type: int
    min: 1
    max: 50
    required: false

[[End Metadata]]
--]=====]
-- ======================================================================
-- Item Search Tool v2 - via XIVAPI (kein Lag!)
-- ======================================================================

local log    = require("lib/logger")
local xivapi = require("lib/xivapi")

log.level = "INFO"

local ITEM_NAME   = Config.Get("itemName")
local LANGUAGE    = Config.Get("language")
local MAX_RESULTS = Config.Get("maxResults")

log.info("Suche '%s' via XIVAPI (Sprache: %s)...", ITEM_NAME, LANGUAGE)

local results = xivapi.searchItems(ITEM_NAME, LANGUAGE, MAX_RESULTS)

if not results then
    log.error("XIVAPI-Anfrage fehlgeschlagen! Ist eine Internetverbindung vorhanden?")
    return
end

log.info("=== ERGEBNIS ===")
log.info("Suche nach '%s': %d Treffer", ITEM_NAME, #results)

for i, r in ipairs(results) do
    log.info("  #%d  ID %-6d  '%s'  (Score: %.2f)", i, r.id, r.name, r.score)
end

if #results == 0 then
    log.warn("Keine Treffer. Pruefen: Rechtschreibung, Sprache (%s), oder anderen Suchbegriff verwenden.", LANGUAGE)
end
