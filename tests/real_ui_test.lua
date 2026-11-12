-- End-to-end wiring test against the REAL Fluent 1.1.0 build (not a mock) plus
-- the real esp_lib.lua / esp_gui.lua sources, executed in tests/fluent_runtime.lua.

local RUNTIME = RUNTIME_MOCK
local E = RUNTIME.entities

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

-- name the library chunk so its render loop can be identified
local raw_loadstring = loadstring
loadstring = function(source, name)
    if source == LIB_SOURCE and name == nil then
        name = "esp_lib"
    end
    return raw_loadstring(source, name)
end

-- // scene -----------------------------------------------------------------
local function attach(player, name, position)
    local character = E.new_character(name, position)
    character.Parent = workspace
    player.Character = character
    E.player_characters[character] = player
    return character
end

local local_character = attach(E.local_player, "MeChar", E.Vector3.new(0, 5, -60))
local ally_character = attach(E.ally, "AllyChar", E.Vector3.new(-10, 10, -100))
local enemy_character = attach(E.enemy, "EnemyChar", E.Vector3.new(10, 10, -100))

local battery = E.new_part("Battery", E.Vector3.new(0, 2, -90), E.Vector3.new(1, 1, 1))
battery.Parent = workspace

RUNTIME.http_get = function(url)
    if url:find("Fluent", 1, true) and url:find("main.lua", 1, true) then
        -- hand the gui the already required 1.1.0 source tree
        return "return FLUENT_LIBRARY"
    elseif url:find("esp_lib", 1, true) then
        return LIB_SOURCE
    elseif url:find("SaveManager", 1, true) then
        return SAVE_SOURCE
    elseif url:find("InterfaceManager", 1, true) then
        return IFACE_SOURCE
    end
    error("unexpected url: " .. tostring(url))
end

-- // run the real gui -------------------------------------------------------
local loaded, load_error = xpcall(function()
    return assert(loadstring(GUI_SOURCE))()
end, function(err)
    return tostring(err) .. "\n" .. debug.traceback("", 2)
end)

check(loaded, "esp_gui builds against real Fluent: " .. tostring(load_error))
if not loaded then
    print("load error: " .. tostring(load_error))
    error("cannot continue", 0)
end

local esplib = getgenv().esplib
local Fluent = FLUENT_LIBRARY

check(Fluent ~= nil, "fluent module captured")
check(Fluent.Version == "1.1.0", "real Fluent 1.1.0 loaded, got " .. tostring(Fluent and Fluent.Version))
check(Fluent.Window ~= nil, "window created")
check(getgenv().esplib == esplib, "esplib shared through getgenv")
check(esplib.api == 2, "library api 2")
check(Fluent.UseAcrylic ~= nil, "acrylic flag present")
check(Fluent.Acrylic == false, "blur disabled through ToggleAcrylic")

-- // elements registered by the real library ------------------------------
local expected = {
    "ESPEnabled", "ESPToggleKey", "ShowPlayers", "ShowTeammates", "TeamColors",
    "UseTeamColor", "FriendlyColor", "EnemyColor", "VisibilityCheck", "MaxDistance",
    "MinHealthEnabled", "MinHealthValue", "RefreshRate", "BoxEnabled", "BoxType",
    "BoxPadding", "BoxThickness", "BoxCornerLength", "BoxFill", "BoxOutline",
    "HealthbarEnabled", "HealthbarWidth", "HealthbarFill", "HealthbarOutline",
    "HealthTextEnabled", "HealthTextFormat", "HealthTextSize", "HealthTextColor",
    "NamesEnabled", "TextSize", "TextOffset", "TextSpacing", "TextColor", "TextOutline",
    "DistanceEnabled", "DistanceSize", "DistanceColor", "DistanceOutline",
    "TracerEnabled", "TracerOrigin", "TracerOriginX", "TracerOriginY", "TracerFromOffset",
    "TracerFill", "TracerOutline", "TracerThickness", "TracerOutlineThickness",
    "SkeletonEnabled", "SkeletonColor", "SkeletonHeadColor", "SkeletonThickness",
    "SkeletonHeadCircle", "HeadDotEnabled", "HeadDotFilled", "HeadDotSize",
    "HeadDotThickness", "HeadDotColor", "Rainbow", "RainbowSpeed", "CrosshairEnabled",
    "CrosshairSize", "CrosshairGap", "CrosshairThickness", "CrosshairOutlineThickness",
    "CrosshairColor", "CrosshairOutline", "CustomTargetName", "CustomTargetList",
}

for _, name in ipairs(expected) do
    check(Fluent.Options[name] ~= nil, "registered control: " .. name)
end

local function set(name, value)
    local element = Fluent.Options[name]
    assert(element ~= nil, "missing element " .. name)
    element:SetValue(value)
end

-- // real toggle path ------------------------------------------------------
set("TeamColors", true)
check(esplib.team.colors == true, "TeamColors toggle reaches esplib")
set("TeamColors", false)
check(esplib.team.colors == false, "TeamColors toggle off reaches esplib")

set("UseTeamColor", true)
check(esplib.team.use_team_color == true, "UseTeamColor toggle reaches esplib")
set("UseTeamColor", false)

set("VisibilityCheck", true)
check(esplib.filters.visibility_check == true, "VisibilityCheck toggle reaches esplib")
set("VisibilityCheck", false)

set("ShowTeammates", false)
check(esplib.team.check == true, "ShowTeammates off enables team check")
set("ShowTeammates", true)
check(esplib.team.check == false, "ShowTeammates on disables team check")

set("ESPEnabled", false)
check(esplib.enabled == false, "master toggle reaches esplib")
set("ESPEnabled", true)

set("BoxEnabled", false)
check(esplib.box.enabled == false, "box toggle reaches esplib")
set("BoxEnabled", true)

set("NamesEnabled", false)
check(esplib.dynamic_text.enabled == false, "names toggle reaches esplib")
set("NamesEnabled", true)

set("Rainbow", true)
check(esplib.rainbow == true, "rainbow toggle reaches esplib")
set("Rainbow", false)

-- // sliders ---------------------------------------------------------------
set("BoxPadding", 1.5)
check(near(esplib.box.padding, 1.5), "padding slider reaches esplib, got " .. tostring(esplib.box.padding))
check(type(esplib.box.padding) == "number", "padding stays a number")

set("MaxDistance", 750)
check(esplib.filters.max_distance == 750, "max distance slider reaches esplib")

set("TracerOriginX", 320)
set("TracerOriginY", 240)
check(esplib.tracer.origin.X == 320 and esplib.tracer.origin.Y == 240, "custom tracer origin sliders")

set("TextSize", 18)
check(esplib.dynamic_text.size == 18, "text size slider")

-- // dropdowns -------------------------------------------------------------
set("BoxType", "Corner")
check(esplib.box.type == "corner", "box type dropdown, got " .. tostring(esplib.box.type))
set("BoxType", "Normal")
check(esplib.box.type == "normal", "box type dropdown back")

set("HealthTextFormat", "Percent")
check(esplib.healthbar.text.format == "percent", "health format dropdown, got " .. tostring(esplib.healthbar.text.format))
set("HealthTextFormat", "Both")

set("TracerOrigin", "Head")
check(esplib.tracer.from == "head", "tracer origin dropdown, got " .. tostring(esplib.tracer.from))
set("TracerOrigin", "Mouse")

-- // colour pickers ---------------------------------------------------------
local blue = E.Color3.fromRGB(0, 0, 255)
local function is_blue(color)
    return getmetatable(color) ~= nil and near(color.R, 0, 0.01) and near(color.G, 0, 0.01) and near(color.B, 1, 0.01)
end
Fluent.Options.BoxFill:SetValueRGB(blue)
check(is_blue(esplib.box.fill), "box fill colour picker reaches esplib")
Fluent.Options.FriendlyColor:SetValueRGB(blue)
check(is_blue(esplib.team.friendly), "friendly colour picker reaches esplib")
Fluent.Options.TracerFill:SetValueRGB(blue)
check(is_blue(esplib.tracer.fill), "tracer colour picker reaches esplib")
Fluent.Options.FriendlyColor:SetValueRGB(E.Color3.fromRGB(0, 255, 0))
Fluent.Options.BoxFill:SetValueRGB(E.Color3.fromRGB(255, 255, 255))

-- // keybind --------------------------------------------------------------
set("ESPEnabled", true)
Fluent.Options.ESPToggleKey:OnClick(function() end)
Fluent.Options.ESPToggleKey:SetValue("F4", "Toggle")
check(Fluent.Options.ESPToggleKey.Value == "F4", "keybind value stored")

-- // end to end render -----------------------------------------------------
local function step(count)
    local handlers = {}
    for _, handler in ipairs(RUNTIME.render_handlers) do
        if RUNTIME.is_esp_handler(handler) then
            handlers[#handlers + 1] = handler
        end
    end
    if #handlers == 0 then
        handlers[1] = assert(RUNTIME.render_handlers[1], "esp_lib did not connect a render step")
    end
    for _ = 1, count or 1 do
        for _, handler in ipairs(handlers) do
            handler()
        end
    end
end

check(getgenv().espinstances[enemy_character] ~= nil, "enemy character tracked by the gui")
check(getgenv().espinstances[local_character] == nil, "local player not tracked")

local enemy_data = getgenv().espinstances[enemy_character]
step(1)
check(enemy_data.box.outline.Visible == true, "box renders for a tracked player")
check(enemy_data.texts.name.Visible == true, "name renders")
check(enemy_data.healthbar.fill.Visible == true, "health bar renders")
check(enemy_data.distance.Visible == true, "distance renders")
check(enemy_data.tracer.fill.Visible == true, "tracer renders")

-- master switch through the real toggle
set("ESPEnabled", false)
step(1)
check(enemy_data.box.outline.Visible == false, "master toggle hides the box in the render loop")
set("ESPEnabled", true)
step(1)
check(enemy_data.box.outline.Visible == true, "master toggle restores the box")

-- team colours through the real colour pickers
Fluent.Options.TeamColors:SetValue(true)
step(1)
check(near(enemy_data.box.fill.Color.R, 1), "team colours colour enemies red")
local ally_data = getgenv().espinstances[ally_character]
check(near(ally_data.box.fill.Color.G, 1), "team colours colour teammates green")

-- team check hides teammates
set("ShowTeammates", false)
step(1)
check(ally_data.box.outline.Visible == false, "team check hides teammates in the render loop")
check(enemy_data.box.outline.Visible == true, "team check keeps enemies")
set("ShowTeammates", true)

-- visibility check
set("VisibilityCheck", true)
RUNTIME.raycast_hit = E.new_part("Wall", E.Vector3.new(0, 0, -50), E.Vector3.new(20, 20, 1))
step(1)
check(enemy_data.box.outline.Visible == false, "visibility check hides occluded targets")
RUNTIME.raycast_hit = nil
step(1)
check(enemy_data.box.outline.Visible == true, "visibility check shows clear targets")
set("VisibilityCheck", false)

-- box type through the real dropdown
set("BoxType", "Corner")
step(1)
check(enemy_data.box.outline.Visible == false, "corner box hides the square")
check(enemy_data.box.corner_fill[1].Visible == true, "corner box draws corner lines")

print(string.format("\n%d checks, %d failures", checks, failures))
if failures > 0 then
    error(string.format("%d assertion(s) failed", failures), 0)
end
print("real Fluent 1.1.0 + esp_gui: all wiring checks passed")
