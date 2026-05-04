-- ======================================================================
-- SND Monster-Datenbank
-- Reine Datendatei - hier Monster und ihre Drops eintragen
--
-- Monster-Format:
--   name  = "..." oder { en = "...", de = "...", fr = "...", ja = "..." }
--   name_id = optionale BNpcName row_id aus XIVAPI
--           Fuer /target probiert das Skript die verfuegbaren Sprachen
--           nacheinander, falls die Client-Sprache nicht bekannt ist.
--
-- Drop-Format:
--   id    = Item-ID (fuer Inventory.GetItemCount)
--   name  = { en = "...", de = "...", fr = "...", ja = "..." }
-- ======================================================================
local monsters = {
    {
        name = "Glitscher",
        waypoints = {
            { x = -49.8, y = -47.2, z = 420.9 },
            { x = -42.1, y = -48.8, z = 417.5 },
            { x = -23.9, y = -45.9, z = 414.4 },
            { x = -16.9, y = -52.1, z = 438.3 },
            { x = -27.1, y = -55.1, z = 464.1 },
            { x = -31.4, y = -54.0, z = 493.9 },
        },
        drops = {
            {
                id = 5496,
                name = {
                    en = "Acidic Secretions",
                    de = "Ätzendes Sekret",
                    fr = "Mucus acide",
                    ja = "アリオンの酸液",
                },
            },
        },
    },
    {
        name_id = 3471,
        name = {
            en = "deepeye",
            de = "Glotzauge",
            fr = "oculus",
            ja = "ディープアイ",
        },
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
    -- ===== WEITERE MONSTER HIER EINFÜGEN =====
}

return monsters
