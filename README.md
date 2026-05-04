# SND Scripts

Modulare Lua-Skripte fuer das Dalamud-Plugin `SomethingNeedDoing`.

Dieses Repo enthaelt:

- ein modulares Farm-Skript
- Hilfsskripte zum Sammeln von Waypoints
- Tools zum Nachschlagen von Item-IDs und multilingualen Item-Namen
- einen Monster-Entry-Builder fuer `data/monsters.lua`

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
│   └── monsters.lua
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
- unterstuetzt mehrsprachige Drop-Namen (`en`, `de`, `fr`, `ja`)
- laeuft Waypoints ab
- targetet Mobs, bewegt sich via `vnavmesh`, pullt und wartet auf Kampfende

Wichtige Module:

- `lib/combat.lua`
- `lib/nav.lua`
- `lib/entity.lua`
- `lib/inventory.lua`
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

Baut einen fast fertigen Eintrag fuer `data/monsters.lua`.

Funktionen:

- `monsterName` konfigurierbar
- `itemName` oder `itemId` konfigurierbar
- sammelt Waypoints wie `positions-helper.lua`
- laedt Item-Namen in `en`, `de`, `fr`, `ja`
- kopiert den kompletten Monster-Block in die Zwischenablage

Beispiel Output:

```lua
    {
        name = "Glotzauge",
        waypoints = {
            { x = 48.4, y = -16.0, z = 152.8 },
            { x = 46.7, y = -16.0, z = 154.1 },
        },
        drops = {
            {
                id = 12628,
                name = {
                    en = "Deepeye Tears",
                    de = "Glotzaugen-Tränen",
                    fr = "Larme d'oculus",
                    ja = "ディープアイの涙",
                },
            },
        },
    },
```

## Datenmodell

### `data/monsters.lua`

Monster koennen als einzelner String oder multilingualer Table vorliegen:

```lua
name = "Glotzauge"
```

oder:

```lua
name = {
    en = "deepeye",
    de = "Glotzauge",
    fr = "oculus",
    ja = "ディープアイ",
}
```

Grund:

- SND/Lua bekommt die Client-Sprache aktuell nicht direkt sauber geliefert
- deshalb probiert das Skript bei multilingualen Monster-Namen die verfuegbaren
  Namen nacheinander fuer `/target`
- ein einfacher String funktioniert weiterhin genauso wie bisher

Drops sind multilingual:

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

## Wie alles zusammenhaengt

### Farm-Pfad

`scripts/farm.lua`:

1. liest `farmItem` und `farmQty` aus SND Config
2. sucht passendes Monster in `data/monsters.lua`
3. nutzt `lib/inventory.lua` fuer Item-Count / Item-ID-Aufloesung
4. nutzt `lib/nav.lua` fuer Bewegung
5. nutzt `lib/combat.lua` fuer Pull/Kill-Loop

### Builder-Pfad

`scripts/monster-builder.lua`:

1. liest `monsterName` und `itemName`
2. sucht Item ueber `lib/xivapi.lua`
3. liest aktuelle Position ueber `lib/entity.lua`
4. sammelt Waypoints aus der Zwischenablage
5. kopiert fertigen Eintrag zurueck in die Zwischenablage

### API-Pfad

`lib/xivapi.lua`:

1. ruft XIVAPI ueber PowerShell `Invoke-RestMethod` auf
2. serialisiert JSON
3. encodiert stdout als Base64
4. dekodiert Base64 in Lua
5. parsed JSON ueber `lib/json.lua`

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

- `monster.name` kann jetzt multilingual sein
- fuer `/target` werden die verfuegbaren Sprachvarianten nacheinander probiert

Einschraenkung:

- es gibt noch keine direkte Client-Spracherkennung in diesem Repo
- dadurch entstehen pro Target-Versuch ggf. mehrere `/target`-Aufrufe

### 4. Item-Suche mit `language = all` sucht initial in `de`

Status: bekannt.

Aktuell wird fuer die initiale Suche standardmaessig `de` verwendet. Danach werden alle Sprachen ueber die gefundene ID geladen.

Verbesserungspaeter:

- zuerst `de`, danach Fallback `en`, `fr`, `ja`
- oder direkte ID-Eingabe priorisieren

## TODO

- Client-Sprache direkt aus SND/Dalamud lesen, falls spaeter verfuegbar
- Fallback-Suchstrategie fuer `item-search.lua` verbessern
- eventuell C#-seitiges HTTP-Modul fuer SND bauen, um PowerShell komplett zu vermeiden
- optional Caching fuer XIVAPI-Antworten einfuehren
- `monster-builder.lua` ggf. um mehrere Drops pro Monster erweitern
- `positions-helper.lua` und `monster-builder.lua` koennen noch gemeinsame Helper teilen

## Entwicklung

Codeaenderungen bitte klein halten und bevorzugt in `lib/` kapseln.

Wichtige Prinzipien in diesem Repo:

- minimale, pragmatische Loesungen
- keine unnötige Abstraktion
- Daten getrennt von Logik
- Zwischenablage als schneller Workflow fuer Copy/Paste nach `data/monsters.lua`
