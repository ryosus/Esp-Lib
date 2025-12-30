
local esplib = loadstring(game:HttpGet('https://raw.githubusercontent.com/ryosus/Esp-Lib/refs/heads/main/esp_lib.lua'))()

computers = {}

for i,v in pairs(game.Workspace:GetDescendants()) do
    if v.Name == "ComputerTable" then
        computers[#computers+1] = v
    end
end

local function apply_computer_esp(computer)
    esplib.add_box(computer.Screen)
    esplib.add_dynamic_text(computer.Screen, "Computer", "Computer")
end

for i,computer in pairs(computers) do
    if computer and computer.Parent then
        apply_computer_esp(computer)
    end
end


game:GetService("RunService").RenderStepped:Connect(function()
    for i,computer in pairs(computers) do
        if computer and computer.Parent then
            if computer.Screen.BrickColor == BrickColor.new("Dark green") then
                esplib.remove_esp(computer.Screen)
            end
        end
    end
end)