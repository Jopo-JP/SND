--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 3.0.0
description: >-
  Item-Suche via XIVAPI - Findet Item-IDs per Name.
  Bei Sprache "all" werden alle 4 Sprachen abgefragt und das Ergebnis
  als fertiger Lua-Block in die Zwischenablage kopiert.
configs:
  itemName:
    default: "Glotzaugen-Tränen"
    description: Name des Items das gesucht werden soll
    type: string
    required: true
  language:
    default: "all"
    description: Sprache (de, en, fr, ja, all)
    type: string
    required: false
  maxResults:
    default: 5
    description: Maximale Anzahl Ergebnisse
    type: int
    min: 1
    max: 50
    required: false

[[End Metadata]]
--]=====]
-- ======================================================================
-- Item Search Tool v3 - via XIVAPI, multilingual, Clipboard-Output
-- ======================================================================

local log    = require("lib/logger")
local xivapi = require("lib/xivapi")

log.level = "INFO"

local ITEM_NAME   = Config.Get("itemName")
local LANGUAGE    = Config.Get("language")
local MAX_RESULTS = Config.Get("maxResults")

-- 1. Suche nach Items (immer in "de" suchen, da der User wahrscheinlich DE-Namen eingibt)
local searchLang = (LANGUAGE == "all") and "de" or LANGUAGE
log.info("Suche '%s' via XIVAPI (Sprache: %s)...", ITEM_NAME, searchLang)

local results = xivapi.searchItems(ITEM_NAME, searchLang, MAX_RESULTS)

if not results then
    log.error("XIVAPI-Anfrage fehlgeschlagen! Ist eine Internetverbindung vorhanden?")
    return
end

if #results == 0 then
    log.warn("Keine Treffer fuer '%s'. Pruefe Rechtschreibung oder andere Sprache.", ITEM_NAME)
    return
end

-- 2. Ergebnisse anzeigen
log.info("=== ERGEBNIS: %d Treffer ===", #results)

if LANGUAGE == "all" then
    -- Alle Sprachen abfragen und als Lua-Block formatieren
    local clipLines = {}

    for i, r in ipairs(results) do
        log.info("#%d  ID %-6d  (Score: %.2f) - Lade alle Sprachen...", i, r.id, r.score)

        local item = xivapi.getItemAllLanguages(r.id)
        if item then
            log.info("  en = %s", item.name.en)
            log.info("  de = %s", item.name.de)
            log.info("  fr = %s", item.name.fr)
            log.info("  ja = %s", item.name.ja)

            -- Fertiger Lua-Block fuer monsters.lua
            local block = string.format(
                '            {\n'
             .. '                id = %d,\n'
             .. '                name = {\n'
             .. '                    en = "%s",\n'
             .. '                    de = "%s",\n'
             .. '                    fr = "%s",\n'
             .. '                    ja = "%s",\n'
             .. '                },\n'
             .. '            },',
                item.id,
                item.name.en,
                item.name.de,
                item.name.fr,
                item.name.ja
            )
            clipLines[#clipLines + 1] = block
        else
            log.error("Konnte Item ID %d nicht in allen Sprachen laden", r.id)
        end
    end

    if #clipLines > 0 then
        local clipboard = table.concat(clipLines, "\n")
        System.SetClipboardText(clipboard)
        log.info("=== %d Item(s) in Zwischenablage kopiert (Ctrl+V in monsters.lua) ===", #clipLines)
    end
else
    -- Einzelne Sprache: einfach auflisten
    for i, r in ipairs(results) do
        log.info("  #%d  ID %-6d  '%s'  (Score: %.2f)", i, r.id, r.name, r.score)
    end
end
