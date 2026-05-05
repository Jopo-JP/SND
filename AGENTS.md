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
  monsters.lua         Manuelle Farm-Quellen / Monster-Datenbank
  generated/           Vom externen Exporter erzeugte XIVAPI-Lua-Daten

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

tools/
  export_xivapi_data.py Externer XIVAPI-v2-Exporter fuer data/generated/*.lua
```

## Wie SND hier genutzt wird

- Nur Skripte in `scripts/` werden direkt in SND importiert.
- `lib/` und `data/` werden mit Lua `require()` geladen.
- Voraussetzung: der Repo-Root ist in SND als `Lua Required Path` gesetzt.

## Wichtige Architekturentscheidungen

### 1. Daten und Logik sind getrennt

- `data/monsters.lua` enthaelt nur Daten.
- Logik lebt in `lib/` und `scripts/`.

### 2. Farm-Quellen sind ID-basiert

`data/monsters.lua` enthaelt manuelle Farm-Quellen im Format:

```lua
{
  key = "deepeye-coerthas-western-highlands",
  bnpc_name_id = 3471,
  territory_id = 397,
  map_id = 211,
  item_ids = { 12628 },
  waypoints = { ... },
}
```

Namen werden ueber `data/generated/*.lua` aufgeloest. Dadurch kann ein Drop in
mehreren Farm-Quellen vorkommen. `scripts/farm.lua` nutzt dann bei Mehrdeutigkeit
die optionale Config `farmSource`.

### 3. Monster-Namen sind weiterhin multilingual zur Laufzeit

Grund:

- `/target <name>` muss exakt zur Sprache des Clients passen.
- `bnpc_name_id` verweist auf `data/generated/bnpc_names.lua`.
- Das Farm-Skript probiert die verfuegbaren Sprachen nacheinander.

### 4. Drop-Namen sind generiert multilingual

Drop-IDs stehen in `item_ids`; Namen kommen aus `data/generated/items.lua`:

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

### 5. XIVAPI statt lokaler Excel-Iteration

Lokale Iteration ueber tausende Rows hat starkes Lag verursacht.

Aktueller Workaround:

- `lib/xivapi.lua` ruft XIVAPI via PowerShell auf
- die Antwort wird als Base64 ueber stdout transportiert
- Lua dekodiert Base64 und parsed JSON lokal

Zusaetzlich gibt es `tools/export_xivapi_data.py` fuer externe Datenexports.
Dieser Weg ist langfristig bevorzugt fuer wiederverwendbare Stammdaten, weil er
HTTP aus dem SND/Game-Thread entfernt. `data/generated/*.lua` ist generiert und
soll nicht manuell editiert werden.

Der Exporter cached erfolgreiche Daten in `data/generated/_xivapi_export_cache.json`.
Sauber fehlende oder leere IDs werden unter `_missing` mit Status `not_found`
oder `empty` notiert. Echte Request-/Access-/Netzwerkfehler brechen ab und
werden nicht als fehlende IDs gespeichert. Bekannte fehlende IDs koennen mit
`python tools/export_xivapi_data.py retry-missing --type item` gezielt erneut
probiert werden.

### 6. Clipboard-first Workflow

Der Nutzer arbeitet stark mit Copy/Paste.

Deshalb:

- `positions-helper.lua` schreibt Waypoints in die Zwischenablage
- `item-search.lua` schreibt fertige Drop-Bloecke in die Zwischenablage
- `monster-builder.lua` schreibt fertige ID-basierte Farm-Source-Bloecke in die Zwischenablage
- `monster-builder.lua` kann mehrere `itemIds` comma-separiert verarbeiten

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

### Farm-Loop priorisiert Mobs noch nicht stabil genug

- Beobachtet wurde: Mobs werden erkannt, aber nicht immer stabil verfolgt und
  zuverlaessig getoetet.
- Das aktuelle Zusammenspiel aus `moveTo`, `scanAndKill`, `walkToTarget` und
  Retargeting ist noch fehleranfaellig.
- Wunschbild: immer zuerst Mob priorisieren, aktuellen Mob stabil verfolgen,
  alle Mobs im lokalen Bereich clearen und erst danach zum naechsten Waypoint.
- Vermutlich spaeter als expliziten Zustandsautomaten neu aufbauen.

## Erwartungen an weitere Aenderungen

- Kleine, gezielte Aenderungen bevorzugen.
- Bestehende Daten in `data/monsters.lua` nicht ohne Grund neu strukturieren.
- `apply_patch` fuer Codeedits verwenden.
- Keine bestehenden Benutzer-Aenderungen rueckgaengig machen.
- Nicht versuchen, HTTP komplett zu abstrahieren, solange SND kein natives HTTP hat.

## Offene TODOs

- Client-Sprache direkt aus SND/Dalamud lesen, falls spaeter verfuegbar
- Aktuelle Territory-ID im Spiel erkennen und gegen `territory_id` pruefen;
  bei falscher Zone soll das Skript mit klarer Meldung abbrechen
- Farm-Loop spaeter als expliziten Zustandsautomaten umbauen, damit Mobs immer
  vor Waypoints priorisiert werden und das aktuelle Ziel stabil verfolgt wird
- Alte HTTP-basierten SND-Tools langfristig durch externen Exporter ersetzen
- Drop-Zuweisung pro Farm-Quelle validieren, aber Waypoints bleiben manuell
- Exporter-Cache spaeter ggf. komprimieren oder selektiv bereinigen, falls
  `data/generated/_xivapi_export_cache.json` zu gross wird
- Wenn moeglich langfristig C#-seitiges HTTP-Modul in SND statt PowerShell

## Wichtige User-Praeferenzen aus dieser Session

- Deutsche Kommunikation ist ok.
- Der Nutzer moechte private SND-Skripte sauber modularisieren.
- Gute Dokumentation ist explizit gewuenscht.
- QOL fuer Datenerfassung ist wichtig.
- Lags sind bekannt, aber aktuell wird mit pragmatischen Workarounds gearbeitet.
