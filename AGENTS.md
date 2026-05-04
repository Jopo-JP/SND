# AGENTS.md

Dieses Repo enthaelt modulare Lua-Skripte fuer das Dalamud-Plugin `SomethingNeedDoing`.

## Projektziel

Der Nutzer migriert persoenliche SND-Skripte in ein privates Git-Repo und will sie refactoren, modularisieren und dokumentieren.

Das Repo soll:

- fuer Menschen gut wartbar sein
- fuer SND direkt nutzbar sein
- fuer weitere Agenten/Assistenten leicht verstaendlich sein

## Repo-Struktur

```text
data/
  monsters.lua         Statische Monster-Datenbank

lib/
  combat.lua           Kampf-Loop, Pull, Kill, Scan
  entity.lua           Player/Target-Zugriff
  inventory.lua        Item Count, Item-ID-Aufloesung
  json.lua             Minimaler JSON-Decoder
  logger.lua           Logging mit Leveln
  nav.lua              Bewegung via vnavmesh
  utils.lua            String-Matching, Distanz, Helper
  xivapi.lua           XIVAPI-Zugriff via PowerShell + Base64

scripts/
  farm.lua             Hauptskript zum Farmen
  item-search.lua      Item-Suche + multilingualer Drop-Export
  monster-builder.lua  Monster-Eintrag mit Waypoints + BNpcName + Item erstellen
  positions-helper.lua Waypoints sammeln
```

## Wie SND hier genutzt wird

- Nur Skripte in `scripts/` werden direkt in SND importiert.
- `lib/` und `data/` werden mit Lua `require()` geladen.
- Voraussetzung: der Repo-Root ist in SND als `Lua Required Path` gesetzt.

## Wichtige Architekturentscheidungen

### 1. Daten und Logik sind getrennt

- `data/monsters.lua` enthaelt nur Daten.
- Logik lebt in `lib/` und `scripts/`.

### 2. Monster-Namen sind optional multilingual

Grund:

- `/target <name>` muss exakt zur Sprache des Clients passen.
- Optional kann `name_id` als `BNpcName` row_id gespeichert werden.
- Falls `monster.name` ein multilingualer Table ist, probiert das Skript die
  verfuegbaren Sprachen nacheinander.
- Falls `monster.name` ein einzelner String ist, bleibt das Verhalten wie bisher.

### 3. Drop-Namen sind multilingual

Drop-Eintraege enthalten:

```lua
{
  id = 12628,
  name = {
    en = "Deepeye Tears",
    de = "Glotzaugen-Tränen",
    fr = "Larme d'oculus",
    ja = "ディープアイの涙",
  },
}
```

### 4. XIVAPI statt lokaler Excel-Iteration

Lokale Iteration ueber tausende Rows hat starkes Lag verursacht.

Aktueller Workaround:

- `lib/xivapi.lua` ruft XIVAPI via PowerShell auf
- die Antwort wird als Base64 ueber stdout transportiert
- Lua dekodiert Base64 und parsed JSON lokal

### 5. Clipboard-first Workflow

Der Nutzer arbeitet stark mit Copy/Paste.

Deshalb:

- `positions-helper.lua` schreibt Waypoints in die Zwischenablage
- `item-search.lua` schreibt fertige Drop-Bloecke in die Zwischenablage
- `monster-builder.lua` schreibt fast fertige Monster-Bloecke in die Zwischenablage
- `monster-builder.lua` nutzt `BNpcName.Singular`, um Monster-Namen multilingual zu exportieren

## Bekannte Probleme

### Kurzer Lag bei HTTP-Requests

- SND fuehrt Lua auf dem Main/Game-Thread aus.
- `io.popen()` blockiert waehrend des HTTP-Requests.
- Deshalb gibt es weiterhin kurzen Lag bei XIVAPI-Nutzung.

### HTTP ist nur ein Workaround

- SND stellt aktuell kein natives HTTP-Modul fuer Lua bereit.
- PowerShell ist die derzeit pragmatischste Loesung.

### Client-Sprache wird nicht direkt erkannt

- Mehrsprachige Monster-Namen werden aktuell ueber `/target`-Fallbacks geloest.
- Das ist funktional, aber nicht so elegant wie echte Client-Spracherkennung.

## Erwartungen an weitere Aenderungen

- Kleine, gezielte Aenderungen bevorzugen.
- Bestehende Daten in `data/monsters.lua` nicht ohne Grund neu strukturieren.
- `apply_patch` fuer Codeedits verwenden.
- Keine bestehenden Benutzer-Aenderungen rueckgaengig machen.
- Nicht versuchen, HTTP komplett zu abstrahieren, solange SND kein natives HTTP hat.

## Offene TODOs

- Client-Sprache direkt aus SND/Dalamud lesen, falls spaeter verfuegbar
- Item-Suche `language = all` mit Fallback-Reihenfolge statt nur `de`
- Mehrere Drops pro Monster ueber Builder unterstuetzen
- XIVAPI optional cachen
- Wenn moeglich langfristig C#-seitiges HTTP-Modul in SND statt PowerShell

## Wichtige User-Praeferenzen aus dieser Session

- Deutsche Kommunikation ist ok.
- Der Nutzer moechte private SND-Skripte sauber modularisieren.
- Gute Dokumentation ist explizit gewuenscht.
- QOL fuer Datenerfassung ist wichtig.
- Lags sind bekannt, aber aktuell wird mit pragmatischen Workarounds gearbeitet.
