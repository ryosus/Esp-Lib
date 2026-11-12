-- Wires up the mock server, loads esp_gui.lua and asserts that every control
-- mutates esp_lib's live configuration.

local M = MOCK_ENTITIES
local Players = game:GetService("Players")

local checks = 0
local failures = 0

local function check(condition, message)
    checks = checks + 1
    if not condition then
        failures = failures + 1
        warn("[FAIL] " .. message)
    end
end

local function near(a, b, epsilon)
    return math.abs(a - b) <= (epsilon or 1e-6)
end

-- // server state before the gui loads ------------------------------------
local local_character = M.character("MeChar", M.Vector3.new(0, 5, -60))
M.workspace:AddChild(local_character)
M.local_player.Character = local_character

local ally_character = M.character("AllyChar", M.Vector3.new(-10, 10, -100))
M.workspace:AddChild(ally_character)
M.ally.Character = ally_character
M.player_characters[ally_character] = M.ally

local enemy_character = M.character("EnemyChar", M.Vector3.new(10, 10, -100))
M.workspace:AddChild(enemy_character)
M.enemy.Character = enemy_character
M.player_characters[enemy_character] = M.enemy

local battery = M.part("Battery", M.Vector3.new(0, 2, -90), M.Vector3.new(1, 1, 1))
M.workspace:AddChild(battery)

-- // load the interface ----------------------------------------------------
local loaded, gui = pcall(function()
    return assert(loadstring(GUI_SOURCE))()
end)

check(loaded, "gui loads: " .. tostring(gui))
if not loaded then
    error("gui failed to load: " .. tostring(gui))
end

local ESP = getgenv().esplib
local UI = MOCK_UI
local instances = getgenv().espinstances

check(gui == ESP, "gui returns the library table")
check(UI ~= nil, "fluent mock recorded elements")
check(UI.elements.ESPEnabled ~= nil, "master toggle created")
check(UI.destroyed ~= true, "window alive after load")
check(UI.autoload_called == true, "autoload config requested")
check(UI.save_folder == "esp-lib", "save folder configured")
check(UI.interface_folder == "esp-lib", "interface folder configured")
check(UI.save_section ~= nil, "config section built")
check(UI.interface_section ~= nil, "interface section built")
check(#UI.notifications > 0, "load notification shown")

-- // target wiring ---------------------------------------------------------
check(instances[enemy_character] ~= nil, "enemy character tracked")
check(instances[ally_character] ~= nil, "ally character tracked")
check(instances[local_character] == nil, "local player never tracked")
check(instances[enemy_character].box ~= nil, "character has a box")
check(instances[enemy_character].healthbar ~= nil, "character has a health bar")
check(instances[enemy_character].tracer ~= nil, "character has a tracer")
check(instances[enemy_character].skeleton ~= nil, "character has a skeleton")
check(instances[enemy_character].head_dot ~= nil, "character has a head dot")
check(instances[enemy_character].texts.name.Text == "Enemy", "character name drawn")

MOCK.render()
check(instances[enemy_character].box.outline.Visible == true, "tracked character renders")

-- new character for an existing player replaces the old tracking
local ally_respawn = M.character("AllyChar2", M.Vector3.new(-12, 10, -100))
M.workspace:AddChild(ally_respawn)
M.ally.Character = ally_respawn
M.player_characters[ally_respawn] = M.ally
M.ally.CharacterAdded:Fire(ally_respawn)
check(instances[ally_respawn] ~= nil, "CharacterAdded tracks the new character")
check(instances[ally_character] == nil, "old character is untracked")

-- players toggle
UI.elements.ShowPlayers:SetValue(false)
check(instances[enemy_character] == nil, "players toggle removes player targets")
check(instances[ally_respawn] == nil, "players toggle removes every player target")
UI.elements.ShowPlayers:SetValue(true)
check(instances[enemy_character] ~= nil, "players toggle restores player targets")
check(instances[ally_respawn] ~= nil, "players toggle restores respawned character")

-- // every control exists --------------------------------------------------
local expected = {
    "ESPEnabled", "ESPToggleKey",
    "ShowPlayers", "ShowTeammates", "ExcludedTeams", "TeamColors", "UseTeamColor",
    "FriendlyColor", "EnemyColor",
    "VisibilityCheck", "MaxDistance", "MinHealthEnabled", "MinHealthValue", "RefreshRate",
    "BoxEnabled", "BoxType", "BoxPadding", "BoxThickness", "BoxCornerLength", "BoxFill", "BoxOutline",
    "HealthbarEnabled", "HealthbarWidth", "HealthbarFill", "HealthbarOutline",
    "HealthTextEnabled", "HealthTextFormat", "HealthTextSize", "HealthTextColor",
    "NamesEnabled", "TextSize", "TextOffset", "TextSpacing", "TextColor", "TextOutline",
    "DistanceEnabled", "DistanceSize", "DistanceColor", "DistanceOutline",
    "TracerEnabled", "TracerOrigin", "TracerOriginX", "TracerOriginY", "TracerFromOffset",
    "TracerFill", "TracerOutline", "TracerThickness", "TracerOutlineThickness",
    "SkeletonEnabled", "SkeletonColor", "SkeletonThickness",
    "HeadDotEnabled", "HeadDotFilled", "HeadDotSize", "HeadDotThickness", "HeadDotColor",
    "OutlinesEnabled", "Rainbow", "RainbowSpeed",
    "CrosshairEnabled", "CrosshairSize", "CrosshairGap", "CrosshairThickness",
    "CrosshairOutlineThickness", "CrosshairColor", "CrosshairOutline",
    "CustomTargetName", "CustomTargetList",
}
for _, name in ipairs(expected) do
    check(UI.elements[name] ~= nil, "control exists: " .. name)
end

local function set_value(name, value)
    local element = UI.elements[name]
    assert(element ~= nil, "missing control " .. name)
    element:SetValue(value)
end

local function set_color(name, color)
    local element = UI.elements[name]
    assert(element ~= nil, "missing control " .. name)
    element:SetValueRGB(color)
end

-- // toggles ---------------------------------------------------------------
local toggle_cases = {
    { "TeamColors", true, function() return ESP.team.colors end },
    { "UseTeamColor", true, function() return ESP.team.use_team_color end },
    { "VisibilityCheck", true, function() return ESP.filters.visibility_check end },
    { "MinHealthEnabled", false, function() return ESP.minimum_health.enabled end },
    { "BoxEnabled", false, function() return ESP.box.enabled end },
    { "HealthbarEnabled", false, function() return ESP.healthbar.enabled end },
    { "HealthTextEnabled", true, function() return ESP.healthbar.text.enabled end },
    { "NamesEnabled", false, function() return ESP.dynamic_text.enabled end },
    { "TextOutline", false, function() return ESP.dynamic_text.outline end },
    { "DistanceEnabled", false, function() return ESP.distance.enabled end },
    { "DistanceOutline", false, function() return ESP.distance.outline end },
    { "TracerEnabled", false, function() return ESP.tracer.enabled end },
    { "SkeletonEnabled", false, function() return ESP.skeleton.enabled end },
    { "HeadDotEnabled", true, function() return ESP.head_dot.enabled end },
    { "HeadDotFilled", false, function() return ESP.head_dot.filled end },
    { "OutlinesEnabled", false, function() return ESP.outlines end },
    { "Rainbow", true, function() return ESP.rainbow end },
    { "CrosshairEnabled", true, function() return ESP.crosshair.enabled end },
}

for _, case in ipairs(toggle_cases) do
    local name, value, getter = case[1], case[2], case[3]
    set_value(name, value)
    check(getter() == value, string.format("%s -> %s", name, tostring(value)))
    set_value(name, value == false)
end

-- excluded teams
UI.elements.ExcludedTeams:SetValue({ ["Team Enemy"] = true })
check(ESP.team.excluded["Team Enemy"] == true, "excluded teams dropdown reaches esplib")
MOCK.render()
check(instances[enemy_character].box.outline.Visible == false, "excluded team is not drawn")
check(instances[ally_respawn].box.outline.Visible == true, "other teams are still drawn")
UI.elements.ExcludedTeams:SetValue({})
check(next(ESP.team.excluded) == nil, "clearing the excluded teams")
MOCK.render()
check(instances[enemy_character].box.outline.Visible == true, "excluded team restored")

-- inverted toggle
set_value("ShowTeammates", false)
check(ESP.team.check == true, "ShowTeammates off enables the team check")
set_value("ShowTeammates", true)
check(ESP.team.check == false, "ShowTeammates on disables the team check")

-- // sliders ---------------------------------------------------------------
local slider_cases = {
    { "BoxPadding", 1.5, function() return ESP.box.padding end },
    { "BoxThickness", 5, function() return ESP.box.thickness end },
    { "BoxCornerLength", 0.4, function() return ESP.box.corner_length end },
    { "HealthbarWidth", 4, function() return ESP.healthbar.width end },
    { "HealthTextSize", 18, function() return ESP.healthbar.text.size end },
    { "TextSize", 19, function() return ESP.dynamic_text.size end },
    { "TextOffset", 25, function() return ESP.dynamic_text.y_offset end },
    { "TextSpacing", 6, function() return ESP.dynamic_text.line_spacing end },
    { "DistanceSize", 21, function() return ESP.distance.size end },
    { "TracerOriginX", 300, function() return ESP.tracer.origin.X end },
    { "TracerOriginY", 200, function() return ESP.tracer.origin.Y end },
    { "TracerFromOffset", 240, function() return ESP.tracer.from_offset end },
    { "TracerThickness", 4, function() return ESP.tracer.thickness end },
    { "TracerOutlineThickness", 6, function() return ESP.tracer.outline_thickness end },
    { "SkeletonThickness", 4, function() return ESP.skeleton.thickness end },
    { "HeadDotSize", 2, function() return ESP.head_dot.size end },
    { "HeadDotThickness", 4, function() return ESP.head_dot.thickness end },
    { "RainbowSpeed", 2, function() return ESP.rainbow_speed end },
    { "CrosshairSize", 40, function() return ESP.crosshair.size end },
    { "CrosshairGap", 10, function() return ESP.crosshair.gap end },
    { "CrosshairThickness", 3, function() return ESP.crosshair.thickness end },
    { "CrosshairOutlineThickness", 5, function() return ESP.crosshair.outline_thickness end },
    { "MaxDistance", 1234, function() return ESP.filters.max_distance end },
    { "MinHealthValue", 42, function() return ESP.minimum_health.value end },
    { "RefreshRate", 500, function() return UI.elements.RefreshRate.Value end },
}

for _, case in ipairs(slider_cases) do
    local name, value, getter = case[1], case[2], case[3]
    set_value(name, value)
    check(near(getter(), value), string.format("%s -> %s", name, tostring(value)))
end

-- rounded slider still stores a number
set_value("BoxPadding", 2)
check(type(ESP.box.padding) == "number", "rounded slider stores a number")
set_value("BoxPadding", 1.15)

-- // dropdowns -------------------------------------------------------------
set_value("BoxType", "Corner")
check(ESP.box.type == "corner", "BoxType -> corner")
set_value("BoxType", "Normal")
check(ESP.box.type == "normal", "BoxType -> normal")

set_value("HealthTextFormat", "Percent")
check(ESP.healthbar.text.format == "percent", "HealthTextFormat -> percent")
set_value("HealthTextFormat", "Both")
check(ESP.healthbar.text.format == "both", "HealthTextFormat -> both")

set_value("TracerOrigin", "Head")
check(ESP.tracer.from == "head", "TracerOrigin -> head")
set_value("TracerOrigin", "Mouse")
check(ESP.tracer.from == "mouse", "TracerOrigin -> mouse")

-- // colours --------------------------------------------------------------
local colour_cases = {
    { "FriendlyColor", function() return ESP.team.friendly end, function(color) ESP.team.friendly = color end },
    { "EnemyColor", function() return ESP.team.enemy end, function(color) ESP.team.enemy = color end },
    { "BoxFill", function() return ESP.box.fill end, function(color) ESP.box.fill = color end },
    { "BoxOutline", function() return ESP.box.outline end, function(color) ESP.box.outline = color end },
    { "HealthbarFill", function() return ESP.healthbar.fill end, function(color) ESP.healthbar.fill = color end },
    { "HealthbarOutline", function() return ESP.healthbar.outline end, function(color) ESP.healthbar.outline = color end },
    { "HealthTextColor", function() return ESP.healthbar.text.fill end, function(color) ESP.healthbar.text.fill = color end },
    { "TextColor", function() return ESP.dynamic_text.fill end, function(color) ESP.dynamic_text.fill = color end },
    { "DistanceColor", function() return ESP.distance.fill end, function(color) ESP.distance.fill = color end },
    { "TracerFill", function() return ESP.tracer.fill end, function(color) ESP.tracer.fill = color end },
    { "TracerOutline", function() return ESP.tracer.outline end, function(color) ESP.tracer.outline = color end },
    { "SkeletonColor", function() return ESP.skeleton.color end, function(color) ESP.skeleton.color = color end },
    { "HeadDotColor", function() return ESP.head_dot.fill end, function(color) ESP.head_dot.fill = color end },
    { "CrosshairColor", function() return ESP.crosshair.fill end, function(color) ESP.crosshair.fill = color end },
    { "CrosshairOutline", function() return ESP.crosshair.outline end, function(color) ESP.crosshair.outline = color end },
}

for index, case in ipairs(colour_cases) do
    local name = case[1]
    local reference = case[2]()
    local color = M.Color3.fromRGB(index * 10, 255 - index * 5, index * 3)
    set_color(name, color)
    check(case[2]() == color, name .. " stores the picked colour")
    check(case[2]() ~= reference, name .. " replaced the previous colour")
    set_color(name, reference)
end

-- // custom origin button --------------------------------------------------
ESP.tracer.origin = M.Vector2.new(500, 600)
UI.elements.TracerOriginX:SetValue(500)
UI.elements.TracerOriginY:SetValue(600)
UI.buttons["Reset custom origin"]:Click()
check(ESP.tracer.origin.X == 0 and ESP.tracer.origin.Y == 0, "reset custom origin button")
check(UI.elements.TracerOriginX.Value == 0, "reset updates the x slider")
check(UI.elements.TracerOriginY.Value == 0, "reset updates the y slider")

-- // custom object targets -------------------------------------------------
UI.elements.CustomTargetName:SetValue("Battery")
UI.buttons["Add target"]:Click()
check(instances[battery] ~= nil, "custom target tracked by name")
check(instances[battery].box ~= nil, "custom target gets a box")
check(instances[battery].texts.name.Text == "Battery", "custom target gets a label")
check(instances[battery].healthbar == nil, "custom target has no health bar")
check(UI.elements.CustomTargetName.Value == "", "input cleared after adding")
check(UI.elements.CustomTargetList.Values ~= nil and #UI.elements.CustomTargetList.Values == 1, "target list refreshed")

-- deselecting through the dropdown stops tracking and prunes the list
UI.elements.CustomTargetList:SetValue({})
check(instances[battery] == nil, "dropdown deselection stops tracking")
check(#UI.elements.CustomTargetList.Values == 0, "dropdown list refreshed after removal")

UI.elements.CustomTargetName:SetValue("Battery")
UI.buttons["Add target"]:Click()
check(instances[battery] ~= nil, "target can be re-added after removal")

-- new instances with a tracked name are picked up automatically
local new_battery = M.part("Battery", M.Vector3.new(5, 2, -90), M.Vector3.new(1, 1, 1))
M.workspace:AddChild(new_battery)
check(instances[new_battery] ~= nil, "DescendantAdded tracks new custom objects")

-- player parts are never tracked as custom objects
local stray_head = M.part("Battery", M.Vector3.new(10, 10, -100), M.Vector3.new(1, 1, 1))
enemy_character:AddChild(stray_head)
check(instances[stray_head] == nil, "player parts are not tracked as custom objects")

UI.buttons["Clear targets"]:Click()
check(instances[battery] == nil, "clear targets removes custom objects")
check(instances[new_battery] == nil, "clear targets removes every custom object")
check(#UI.elements.CustomTargetList.Values == 0, "target list emptied")

-- // settings reset --------------------------------------------------------
set_value("BoxPadding", 2)
set_value("TextSize", 22)
UI.buttons["Reset settings"]:Click()
check(near(ESP.box.padding, 1.15), "reset restores library defaults")
check(UI.elements.BoxPadding.Value == 1.15, "reset syncs the padding slider")
check(UI.elements.TextSize.Value == 13, "reset syncs the text size slider")
check(next(ESP.team.excluded) == nil, "reset clears the excluded teams")

-- // keybind ---------------------------------------------------------------
check(ESP.enabled == true, "esp enabled before keybind test")
UI.elements.ESPToggleKey:Click()
check(ESP.enabled == true, "keybind on does not disable the esp")
UI.elements.ESPToggleKey:Click()
check(ESP.enabled == false, "keybind off disables the esp")
check(UI.elements.ESPEnabled.Value == false, "keybind updates the master toggle")
UI.elements.ESPToggleKey:Click()
check(ESP.enabled == true, "keybind re-enables the esp")

-- // live render integration ----------------------------------------------
UI.elements.BoxEnabled:SetValue(false)
MOCK.render()
check(instances[enemy_character].box.outline.Visible == false, "box toggle hides boxes in the render loop")
UI.elements.BoxEnabled:SetValue(true)
MOCK.render()
check(instances[enemy_character].box.outline.Visible == true, "box toggle restores boxes in the render loop")

UI.elements.ShowTeammates:SetValue(false)
MOCK.render()
check(instances[ally_respawn].box.outline.Visible == false, "show teammates off hides allies")
check(instances[enemy_character].box.outline.Visible == true, "show teammates off keeps enemies")
UI.elements.ShowTeammates:SetValue(true)

UI.elements.TeamColors:SetValue(true)
MOCK.render()
check(near(instances[enemy_character].box.fill.Color.R, 1), "team colours drive the accent")
UI.elements.TeamColors:SetValue(false)

UI.elements.NamesEnabled:SetValue(false)
MOCK.render()
check(instances[enemy_character].texts.name.Visible == false, "names toggle hides names")
UI.elements.NamesEnabled:SetValue(true)
MOCK.render()
check(instances[enemy_character].texts.name.Visible == true, "names toggle restores names")

-- // unload ----------------------------------------------------------------
UI.buttons["Unload ESP"]:Click()
check(UI.last_dialog ~= nil and #UI.last_dialog.Buttons == 2, "unload asks for confirmation")
UI.last_dialog.Buttons[1].Callback()
check(next(instances) == nil, "unload removes every drawing")
check(MOCK.render == nil, "unload disconnects the render loop")
check(UI.destroyed == true, "unload closes the interface")

print(string.format("\n%d checks, %d failures", checks, failures))
if failures > 0 then
    error(string.format("%d assertion(s) failed", failures))
end
print("esp_gui.lua: all wiring checks passed")
