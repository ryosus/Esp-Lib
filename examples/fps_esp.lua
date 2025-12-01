-- // simple player esp
getgenv().esplib = {
    box = {
        enabled = false,
        type = "normal", -- normal, corner
        padding = 1.15,
        fill = Color3.new(1,1,1),
        outline = Color3.new(0,0,0),
    },
    healthbar = {
        enabled = true,
        fill = Color3.new(0,1,0),
        outline = Color3.new(0,0,0),
    },
    dynamic_text = {
        enabled = true,
        fill = Color3.new(1,1,1),
        size = 13,
        y_offset = -15,
    },
    name = {
        enabled = true,
        fill = Color3.new(1,1,1),
        size = 13,
    },
    distance = {
        enabled = true,
        fill = Color3.new(1,1,1),
        size = 13,
    },
    tracer = {
        enabled = true,
        fill = Color3.new(1,1,1),
        outline = Color3.new(0,0,0),
        from = "bottom", -- mouse, head, top, bottom, center
    },
    skeleton = {
        enabled = true,
        color = Color3.new(1, 0, 1),
        thickness = 2,
        head = Color3.new(1, 0, 0),
    },
    minimum_health = {
        enabled = true,
        value = 0
    }, -- if health is below this value, don't show anything
}

local esplib = loadstring(game:HttpGet('https://raw.githubusercontent.com/ryosus/Esp-Lib/refs/heads/main/esp_lib.lua'))()

local function apply_esp(character)
    esplib.add_healthbar(character)
    --esplib.add_name(character)
    esplib.add_dynamic_text(character, "test", "hahahaha")
    esplib.add_distance(character)
    esplib.add_tracer(character)
    esplib.add_skeleton(character)
end


for i,v in pairs(game.Players:GetPlayers()) do
    if v ~= game.Players.LocalPlayer then
        if v.Character then
            apply_esp(v.Character)
        end

        v.CharacterAdded:Connect(function(character)
            apply_esp(character)
        end)
    end
end

game.Players.PlayerAdded:Connect(function(v)
    if v ~= game.Players.LocalPlayer then
        v.CharacterAdded:Connect(function(character)
            apply_esp(character)
        end)
    end
end)