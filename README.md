# SND Scripts

Modulare Lua-Skripte fuer das Dalamud-Plugin `SomethingNeedDoing`.

Dieses Repo enthaelt:

- ein modulares Farm-Skript
- Hilfsskripte zum Sammeln von Waypoints
- Tools zum Nachschlagen von Item-IDs und multilingualen Item-Namen
- einen Monster-Entry-Builder fuer `data/monsters.lua`
- einen externen XIVAPI-Exporter fuer lokale Lua-Daten

## Ziel

Das Ziel dieses Repos ist, SND-Skripte wartbarer und wiederverwendbarer zu machen.
Statt einer grossen Datei wird die Logik in Module aufgeteilt:

- `lib/` fuer gemeinsam genutzte Funktionen
- `data/` fuer statische Daten
- `scripts/` fuer direkt in SND ausfuehrbare Skripte

## Struktur

```text
snd/
├── data/
│   ├── monsters.lua
│   └── generated/
│       ├── items.lua
│       ├── bnpc_names.lua
│       ├── territories.lua
│       ├── maps.lua
│       └── place_names.lua
├── lib/
│   ├── combat.lua
│   ├── entity.lua
│   ├── inventory.lua
│   ├── json.lua
│   ├── logger.lua
│   ├── nav.lua
│   ├── utils.lua
│   └── xivapi.lua
├── scripts/
│   ├── farm.lua
│   ├── item-search.lua
│   ├── monster-builder.lua
│   └── positions-helper.lua
├── tools/
│   └── export_xivapi_data.py
├── AGENTS.md
├── CLAUDE.md
└── README.md
```

## In SND hinzufuegen

Nur diese Skripte muessen in SND importiert oder verlinkt werden:

- `scripts/farm.lua`
- `scripts/item-search.lua`
- `scripts/monster-builder.lua`
- `scripts/positions-helper.lua`

`lib/` und `data/` werden ueber `require()` geladen.

## Voraussetzung

In SND muss der Repo-Root als `Lua Required Path` gesetzt sein.

Beispiel:

```text
G:/Downloads/SND
```

Danach funktionieren Aufrufe wie:

```lua
local xivapi = require("lib/xivapi")
local monsters = require("data/monsters")
```

## Implementierte Skripte

### `scripts/farm.lua`

Hauptskript fuer automatisches Farmen.

Funktionen:

- sucht das Farm-Ziel in `data/monsters.lua`
- unterstuetzt Suche nach Item-ID oder Item-Name
- loest Item-/Monster-Namen aus `data/generated/*.lua`
- unterstuetzt `farmSource`, wenn mehrere Quellen dasselbe Item droppen
- laeuft Waypoints ab
- targetet Mobs, bewegt sich via `vnavmesh`, pullt und wartet auf Kampfende

Wichtige Module:

- `lib/combat.lua`
- `lib/nav.lua`
- `lib/entity.lua`
- `lib/inventory.lua`
- `lib/farm_db.lua`
- `lib/game_data.lua`
- `lib/utils.lua`

### `scripts/item-search.lua`

Sucht Items ueber XIVAPI statt ueber lokale Excel-Iteration.

Funktionen:

- Suche per Name ueber XIVAPI `/search`
- Option `language = all`
- laedt dann `en`, `de`, `fr`, `ja`
- kopiert einen fertigen `drops`-Eintrag in die Zwischenablage

Beispiel Clipboard-Output:

```lua
            {
                id = 12628,
                name = {
                    en = "Deepeye Tears",
                    de = "Glotzaugen-Tränen",
                    fr = "Larme d'oculus",
                    ja = "ディープアイの涙",
                },
            },
```

### `scripts/positions-helper.lua`

Sammelt Waypoints ueber die Zwischenablage.

Funktionen:

- liest vorhandene Waypoints aus der Zwischenablage
- fuegt die aktuelle Position an
- erkennt Duplikate
- kopiert den kompletten Waypoint-Block zurueck in die Zwischenablage

### `scripts/monster-builder.lua`

Baut einen ID-basierten Farm-Source-Eintrag fuer `data/monsters.lua`.

Funktionen:

- `sourceKey`, `monsterName` oder `bnpcNameId` konfigurierbar
- `itemIds` akzeptiert IDs und Namen comma-separiert
- `territoryId` und `mapId` optional
- `mode = add|undo|preview|reset`
- sammelt Waypoints wie `positions-helper.lua`
- sucht IDs nur wenn noetig ueber `lib/xivapi.lua`
- kopiert den kompletten Farm-Source-Block in die Zwischenablage

Beispiel Output:

```lua
    {
        key = "deepeye-coerthas-western-highlands",
        bnpc_name_id = 3471,
        territory_id = 397,
        map_id = 211,
        item_ids = {
            12628,
        },
        waypoints = {
            { x = 48.4, y = -16.0, z = 152.8 },
            { x = 46.7, y = -16.0, z = 154.1 },
        },
    },
```

## Externer XIVAPI-Exporter

`tools/export_xivapi_data.py` laeuft ausserhalb von SND und erzeugt lokale Lua-Dateien in `data/generated/`.

Ziel:

- IDs extern validieren
- Namen in `en`, `de`, `fr`, `ja` exportieren
- SND-Lag durch HTTP-Requests im Spiel reduzieren
- `data/monsters.lua` mit lokalen Stammdaten aus `data/generated/*.lua` verbinden

Der Exporter nutzt nur die Python-Standardbibliothek.

### Suche nach IDs

Wenn eine ID nicht bekannt ist, kann zuerst gesucht werden:

```bash
python tools/export_xivapi_data.py search item "Glotzaugen-Tränen" --language de
python tools/export_xivapi_data.py search mob "deepeye" --language all
python tools/export_xivapi_data.py search territory "Coerthas" --language en
python tools/export_xivapi_data.py search map "Coerthas" --language en
python tools/export_xivapi_data.py search place_name "Coerthas" --language all
```

Wichtig:

- `mob` sucht in `BNpcName.Singular`, also dem Namen, der fuer `/target` relevant ist.
- `territory` sucht in `TerritoryType.PlaceName.Name`.
- `--language all` sucht nacheinander in `en`, `de`, `fr`, `ja` und dedupliziert IDs.

### Export nach Lua

Einzelne IDs und Bereiche koennen kombiniert werden:

```bash
python tools/export_xivapi_data.py export \
  --items 12628,5496,500-510 \
  --mobs 3471,7422 \
  --territories 397 \
  --maps 211 \
  --place-names 25,508,2200
```

Unterstuetzte ID-Syntax:

```text
1
1,5,50
50-80
1,5,50-80,120
```

Normale Exports fuegen neue IDs zum JSON-Cache unter `data/generated/_xivapi_export_cache.json` hinzu und schreiben daraus die Lua-Dateien neu.
Bereits vorhandene IDs werden dabei standardmaessig uebersprungen und nicht erneut von XIVAPI geladen.

IDs, die bei einem sauberen XIVAPI-Result nicht existieren oder leere Felder liefern, werden im Cache unter `_missing` notiert. Echte Request-Fehler wie Access-Denied, kaputte Antwort oder Netzwerkfehler brechen den Export ab und werden nicht als fehlende ID gespeichert.

Mit `--refresh` werden angefragte IDs trotz Cache neu geladen:

```bash
python tools/export_xivapi_data.py export --items 12628 --refresh
```

Bekannte fehlende/leere IDs anzeigen:

```bash
python tools/export_xivapi_data.py missing
python tools/export_xivapi_data.py missing --type item
```

Nur bekannte fehlende/leere IDs erneut probieren:

```bash
python tools/export_xivapi_data.py retry-missing
python tools/export_xivapi_data.py retry-missing --type item
```

Alternativ koennen bekannte fehlende IDs in einem normalen Export gezielt erneut probiert werden:

```bash
python tools/export_xivapi_data.py export --items 999999 --retry-missing
```

Mit `--replace` werden die betroffenen Datentypen neu aufgebaut:

```bash
python tools/export_xivapi_data.py export --items 12628 --replace
```

Generierte Dateien:

- `data/generated/items.lua`
- `data/generated/bnpc_names.lua`
- `data/generated/territories.lua`
- `data/generated/maps.lua`
- `data/generated/place_names.lua`

Optional technisch:

- `data/generated/bnpc_bases.lua`

`BNpcBase` ist nicht der lokalisierte Monstername. Fuer Farming und `/target` ist normalerweise `BNpcName` wichtiger.

### Drops zuweisen

Der Exporter prueft und exportiert Item-/Monster-/Territory-Daten, weist Drops aber noch nicht automatisch Monstern zu.

`data/monsters.lua` nutzt Farm-Source-Eintraege mit IDs:

```lua
{
    key = "deepeye-coerthas-western-highlands",
    bnpc_name_id = 3471,
    territory_id = 397,
    map_id = 211,
    item_ids = { 12628, 5496 },
    waypoints = {
        { x = 414.5, y = 174.7, z = 455.4 },
    },
}
```

Damit kann ein Drop mehreren Farm-Quellen zugewiesen werden, ohne Item-Namen mehrfach zu duplizieren. Waypoints bleiben manuell, weil sie die praktisch getestete Route beschreiben.

## Datenmodell

### `data/monsters.lua`

Die Datei enthaelt manuelle Farm-Quellen. Ein Eintrag beschreibt eine konkrete Route fuer ein Monster in einer Zone.

```lua
{
    key = "deepeye-coerthas-western-highlands",
    bnpc_name_id = 3471,
    territory_id = 397,
    map_id = 211,
    item_ids = { 12628, 5496 },
    waypoints = {
        { x = 414.5, y = 174.7, z = 455.4 },
    },
}
```

Namen und mehrsprachige Daten werden nicht mehr manuell dupliziert. Sie kommen aus:

- `data/generated/items.lua`
- `data/generated/bnpc_names.lua`
- `data/generated/territories.lua`
- `data/generated/maps.lua`

Mehrere Farm-Quellen duerfen dieselbe `item_id` enthalten. Wenn `farmItem` dadurch mehrdeutig wird, muss `farmSource` auf den `key` gesetzt werden.

## Wie alles zusammenhaengt

### Farm-Pfad

`scripts/farm.lua`:

1. liest `farmItem`, `farmSource` und `farmQty` aus SND Config
2. loest Farm-Quellen ueber `lib/farm_db.lua`
3. liest Stammdaten aus `data/generated/*.lua` ueber `lib/game_data.lua`
4. nutzt `lib/inventory.lua` fuer Item-Count
5. nutzt `lib/nav.lua` fuer Bewegung
6. nutzt `lib/combat.lua` fuer Pull/Kill-Loop

### Builder-Pfad

`scripts/monster-builder.lua`:

1. liest `sourceKey`, `monsterName`/`bnpcNameId`, `itemIds`, `territoryId`, `mapId`
2. sucht fehlende IDs bei Bedarf ueber `lib/xivapi.lua`
3. liest aktuelle Position ueber `lib/entity.lua`
4. sammelt Waypoints aus der Zwischenablage
5. kopiert fertigen Farm-Source-Eintrag zurueck in die Zwischenablage

### API-Pfad

`lib/xivapi.lua`:

1. ruft XIVAPI ueber PowerShell `Invoke-RestMethod` auf
2. serialisiert JSON
3. encodiert stdout als Base64
4. dekodiert Base64 in Lua
5. parsed JSON ueber `lib/json.lua`

Zusaetzlich verwendet das Repo:

- `Item.Name` fuer Item-Suchen
- `BNpcName.Singular` fuer Mob-/Monster-Suchen

Der Base64-Schritt ist noetig, weil Windows Console-Codepages UTF-8/Umlaute/Japanisch sonst zerstoeren.

## Offene Probleme / Bugs

### 1. Kurzer Lag bei XIVAPI Requests

Status: bekannt, nicht geloest.

Ursache:

- SND fuehrt Lua auf dem Game/Main-Thread aus
- `io.popen()` blockiert diesen Thread waehrend des HTTP-Requests

Aktueller Stand:

- deutlich besser als lokale Excel-Iteration ueber viele Tausend Rows
- aber weiterhin kurzer Freeze/Lag beim HTTP-Request

### 2. HTTP ist ein Workaround

Status: bekannt.

Es gibt in SND aktuell kein natives HTTP-Modul fuer Lua. Deshalb wird PowerShell verwendet.

### 3. Mehrsprachige Monster-Namen nutzen Fallback statt echter Client-Spracherkennung

Status: teilweise umgesetzt.

Aktueller Stand:

- `bnpc_name_id` wird ueber `data/generated/bnpc_names.lua` zu multilingualen Namen aufgeloest
- fuer `/target` werden die verfuegbaren Sprachvarianten nacheinander probiert

Einschraenkung:

- es gibt noch keine direkte Client-Spracherkennung in diesem Repo
- dadurch entstehen pro Target-Versuch ggf. mehrere `/target`-Aufrufe

### 4. Item-Suche im alten SND-Tool nutzt weiterhin HTTP

Status: bekannt.

`scripts/item-search.lua` nutzt weiterhin `lib/xivapi.lua`. Der bevorzugte neue Weg fuer Stammdaten ist `tools/export_xivapi_data.py` ausserhalb von SND.

Verbesserungspaeter:

- zuerst `de`, danach Fallback `en`, `fr`, `ja`
- oder direkte ID-Eingabe priorisieren

### 5. Farm-Loop priorisiert Mobs noch nicht stabil genug

Status: offen.

Beobachtetes Verhalten:

- beim Laufen zu Waypoints werden Mobs zwar erkannt (`Mob erkannt ... Stoppe.`)
- danach wird aber nicht zuverlaessig in einen stabilen Kill-Flow gewechselt
- teils laeuft das Skript kurz weiter, stoppt erneut und wiederholt das
- Angriffe werden zu selten oder unzuverlaessig ausgeloest
- dadurch werden einzelne Mobs uebersprungen oder nicht sauber verfolgt

Gewuenschtes Verhalten:

1. Mob in Reichweite erkennen
2. diesen konkreten Mob priorisieren
3. zu ihm hinlaufen, falls ausserhalb der Pull-/Kill-Range
4. wenn er vor Ankunft stirbt: Lauf abbrechen und naechsten Mob suchen
5. wenn Kampf startet: im Kampf-/Clear-Modus bleiben
6. alle passenden Mobs in der Naehe toeten
7. erst wenn kein passender Mob mehr in der Naehe ist, zum naechsten Waypoint

Vermutung:

- der aktuelle Mix aus Scan-, Move-, Retarget- und Kill-Logik ist noch zu implizit
- wahrscheinlich ist ein klarer Zustandsautomat sinnvoller:
  `scan -> chase current target -> kill -> repeat scan -> advance waypoint`

## TODO

- Client-Sprache direkt aus SND/Dalamud lesen, falls spaeter verfuegbar
- Zone/Territory pro Monster erfassen (ID + Name) und vor dem Farmen pruefen;
  wenn der Spieler in der falschen Zone ist, soll das Skript mit klarer Meldung
  abbrechen statt still weiterzulaufen
- Farm-Loop spaeter als expliziten Zustandsautomaten umbauen, damit Mobs immer
  vor Waypoints priorisiert werden und das aktuelle Ziel stabil verfolgt wird
- Farm-Skript spaeter um echte aktuelle Territory-Pruefung erweitern
- eventuell C#-seitiges HTTP-Modul fuer SND bauen, um PowerShell komplett zu vermeiden
- optional SND-HTTP weiter reduzieren und alte XIVAPI-Tools abloesen
- `positions-helper.lua` und `monster-builder.lua` koennen noch gemeinsame Helper teilen

## Entwicklung

Codeaenderungen bitte klein halten und bevorzugt in `lib/` kapseln.

Wichtige Prinzipien in diesem Repo:

- minimale, pragmatische Loesungen
- keine unnötige Abstraktion
- Daten getrennt von Logik
- Zwischenablage als schneller Workflow fuer Copy/Paste nach `data/monsters.lua`
