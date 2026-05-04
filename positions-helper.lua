--[=====[
[[SND Metadata]]
author: Jopo-JP
version: 0.0.1
description: Copy player position to the clipboard.

[[End Metadata]]
--]=====]
local p = Entity.Player
if p then
    local pos = p.Position
    if pos then
        local line = "{x=" .. string.format("%.1f", pos.X)
                  .. ", y=" .. string.format("%.1f", pos.Y)
                  .. ", z=" .. string.format("%.1f", pos.Z) .. "},"
        
        -- In Zwischenablage kopieren
        System.SetClipboardText(line)
        
        -- Weiterhin im Chat anzeigen
        yield("/echo [POS] " .. line)
    end
end
