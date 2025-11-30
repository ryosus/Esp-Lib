-- // esp-lib.lua
local esplib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ryosus/Esp-Lib/refs/heads/main/esp_lib.lua"))()

-- // Find existing tools in workspace
for i, v in pairs(workspace:GetChildren()) do
    if v:IsA("Tool") then
    esplib.add_box(v.Handle)
    esplib.add_name(v.Handle, v.Name)
    esplib.add_distance(v.Handle)
    elseif v.Name == "Battery" or v.Name == "OldFlashlight" then
        esplib.add_box(v)
        esplib.add_name(v)
        esplib.add_distance(v)
    end
end

-- // Monitor for new tools being added to workspace
workspace.ChildAdded:Connect(function(child)
    if child:IsA("Tool") then
        esplib.add_box(child.Handle)
        esplib.add_name(child.Handle, child.Name)
        esplib.add_distance(child.Handle)
    elseif child.Name == "Battery" or child.Name == "OldFlashlight" then
        esplib.add_box(child)
        esplib.add_name(child)
        esplib.add_distance(child)
    end
end)