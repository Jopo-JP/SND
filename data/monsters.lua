-- ======================================================================
-- SND Monster-Datenbank
-- Reine Datendatei - hier Monster und ihre Drops eintragen
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
            { name = "Ätzendes Sekret", id = 5496 },
        },
    },
    {
        name = "Glotzauge",
        waypoints = {
            { x = 414.3, y = 174.6, z = 454.5 },
            { x = 449.5, y = 170.6, z = 431.7 },
            { x = 451.4, y = 168.9, z = 419.2 },
            { x = 434.9, y = 174.8, z = 385.7 },
            { x = 475.2, y = 164.2, z = 356.0 },
            { x = 449.7, y = 164.7, z = 307.8 },
            { x = 414.4, y = 168.5, z = 269.0 },
            { x = 367.6, y = 166.0, z = 241.8 },
            { x = 337.0, y = 171.1, z = 226.0 },
        },
        drops = {
            { name = "Glotzaugen-Tränen", id = 12628 },
        },
    },
    -- ===== WEITERE MONSTER HIER EINFÜGEN =====
}

return monsters
