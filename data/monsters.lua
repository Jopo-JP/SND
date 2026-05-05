-- ======================================================================
-- SND Farm-Quellen
--
-- Manuell gepflegte Datei: IDs + Waypoints.
-- Namen und mehrsprachige Stammdaten kommen aus data/generated/*.lua.
--
-- Farm-Source-Format:
--   key          = eindeutige Auswahl fuer farmSource
--   bnpc_name_id = BNpcName row_id fuer /target-Namen
--   bnpc_base_ids = BNpcBase row_ids fuer automatisch generierte Spawn-Waypoints
--   territory_id = TerritoryType row_id (optional, aber empfohlen)
--   map_id       = Map row_id (optional)
--   item_ids     = Drop-Item-IDs, mehrere Items moeglich
--   waypoints    = manuell getestete Farmroute (optional; sonst Spawnpunkte)
-- ======================================================================
local sources = {
    {
        key = "shroud-hare",
        bnpc_name_id = 40,
        item_ids = { 5496 },
        waypoints = {
            { x = -49.8, y = -47.2, z = 420.9 },
            { x = -42.1, y = -48.8, z = 417.5 },
            { x = -23.9, y = -45.9, z = 414.4 },
            { x = -16.9, y = -52.1, z = 438.3 },
            { x = -27.1, y = -55.1, z = 464.1 },
            { x = -31.4, y = -54.0, z = 493.9 },
        },
    },
    {
        key = "deepeye-coerthas-western-highlands",
        bnpc_name_id = 3471,
        bnpc_base_ids = { 5537, 5538, 5539 },
        territory_id = 397,
        map_id = 211,
        item_ids = { 12628 },
    },
    -- ===== WEITERE FARM-QUELLEN HIER EINFUEGEN =====
}

return sources
