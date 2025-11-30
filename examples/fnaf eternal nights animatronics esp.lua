local animatronics = workspace.Game.Animatronics.Animatronics

-- // esp-lib.lua
local esplib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ryosus/Esp-Lib/refs/heads/main/esp_lib.lua"))()

-- // Find existing animatronics in workspace
for i, v in pairs(animatronics:GetChildren()) do
    esplib.add_box(v)
    esplib.add_name(v)
    esplib.add_distance(v)
end

