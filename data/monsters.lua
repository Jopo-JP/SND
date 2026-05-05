-- ======================================================================
-- SND Farm-Quellen
--
-- Manuell gepflegte Datei: IDs + Waypoints.
-- Namen und mehrsprachige Stammdaten kommen aus data/generated/*.lua.
--
-- Farm-Source-Format:
--   key          = eindeutige Auswahl fuer farmSource
--   bnpc_name_id = BNpcName row_id fuer /target-Namen
--   territory_id = TerritoryType row_id (optional, aber empfohlen)
--   map_id       = Map row_id (optional)
--   item_ids     = Drop-Item-IDs, mehrere Items moeglich
--   waypoints    = manuell getestete Farmroute
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
        territory_id = 397,
        map_id = 211,
        item_ids = { 12628 },
        waypoints = {
            { x = 414.5, y = 174.7, z = 455.4 },
            { x = 453.4, y = 169.4, z = 424.9 },
            { x = 439.7, y = 173.1, z = 390.8 },
            { x = 466.9, y = 166.4, z = 349.2 },
            { x = 467.2, y = 164.4, z = 301.3 },
            { x = 445.6, y = 176.2, z = 224.3 },
            { x = 386.3, y = 167.6, z = 188.6 },
            { x = 336.1, y = 171.1, z = 226.5 },
            { x = 392.2, y = 166.9, z = 314.0 },
        },
    },
    -- ===== WEITERE FARM-QUELLEN HIER EINFUEGEN =====
}

return sources
