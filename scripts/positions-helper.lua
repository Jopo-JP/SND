--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 1.1.0
description: Kopiert die aktuelle Spielerposition in die Zwischenablage.

[[End Metadata]]
--]=====]
-- ======================================================================
-- Position Helper - Kopiert {x=..., y=..., z=...} in die Zwischenablage
-- ======================================================================

local entity = require("lib/entity")

local pos = entity.getPlayerPos()
if pos then
    local line = string.format("{x=%.1f, y=%.1f, z=%.1f},", pos.x, pos.y, pos.z)
    System.SetClipboardText(line)
    yield("/echo [POS] " .. line)
else
    yield("/echo [POS] FEHLER: Spieler-Position nicht lesbar!")
end
