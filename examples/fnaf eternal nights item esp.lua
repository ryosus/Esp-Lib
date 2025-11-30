-- // esp-lib.lua
local esplib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ryosus/Esp-Lib/refs/heads/main/esp_lib.lua"))()

function check(v)
    if v:IsA("Tool") or v.Name == "OldFlashlight" then
        esplib.add_box(v.Handle)
        esplib.add_name(v.Handle, v.Name)
        esplib.add_distance(v.Handle)
    elseif v.Name == "Battery" then
        esplib.add_box(v)
        esplib.add_name(v)
        esplib.add_distance(v)
    end
end

-- // Find existing tools in workspace
for i, v in pairs(workspace:GetChildren()) do
    check(v)
end

-- // Monitor for new tools being added to workspace
workspace.ChildAdded:Connect(function(v)
    check(v)
end)

-- check if items are being picked up and remove esp
game:GetService("RunService").Stepped:Connect(function()
    for i, v in pairs(getgenv().espinstances) do
        pcall(function()
            if i.Parent.Parent ~= workspace and i.Name ~= "Battery" then
                esplib.remove_esp(i)
            end
        end)
    end
end)