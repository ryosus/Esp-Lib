--[[

    esp_gui.lua
    Fluent user interface for esp_lib.lua.

    Exposes every option of the library plus the feature set of
    ic3w0lf22/Unnamed-ESP:
        - master switch + keybind
        - show players / show teammates / team + enemy colours / Roblox team colours
        - names, distance, health bar, health text, boxes (normal + corner)
        - tracers with mouse / head / top / bottom / center / custom origins
        - skeletons (R15 + R6) and head dots
        - visibility check, max distance, minimum health
        - rainbow accents, crosshair
        - custom object targets (Unnamed's per-game custom ESP, generalised)
        - config saving / loading through Fluent's SaveManager

    Usage (executor):
        loadstring(game:HttpGet("https://raw.githubusercontent.com/ryosus/Esp-Lib/main/esp_gui.lua"))()

]]

local ESP_LIB_URL = "https://raw.githubusercontent.com/ryosus/Esp-Lib/refs/heads/main/esp_lib.lua"
local FLUENT_URL = "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
local SAVE_MANAGER_URL = "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"
local INTERFACE_MANAGER_URL = "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"

local CONFIG_FOLDER = "esp-lib"
local MAX_CUSTOM_INSTANCES = 150

-- // dependencies
local function load_module(url)
    local source = game:HttpGet(url)
    local chunk, compile_error = loadstring(source)
    if not chunk then
        error(string.format("esp_gui: failed to compile %s (%s)", url, tostring(compile_error)), 0)
    end
    local ok, result = pcall(chunk)
    if not ok then
        error(string.format("esp_gui: failed to run %s (%s)", url, tostring(result)), 0)
    end
    return result
end

local Fluent = load_module(FLUENT_URL)
local SaveManager = load_module(SAVE_MANAGER_URL)
local InterfaceManager = load_module(INTERFACE_MANAGER_URL)
local esplib = load_module(ESP_LIB_URL)

if esplib.api ~= 2 then
    error(
        "esp_gui: esp_lib.lua is out of date (missing api 2 options such as team, filters, "
            .. "head_dot and crosshair). Update the library at "
            .. ESP_LIB_URL,
        0
    )
end

-- // services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- // window
local Window = Fluent:CreateWindow({
    Title = "esp-lib",
    SubTitle = "visuals + fluent",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 480),
    Acrylic = false, -- the blur can be detectable in some games
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
    General = Window:AddTab({ Title = "ESP", Icon = "eye" }),
    Box = Window:AddTab({ Title = "Box", Icon = "square" }),
    Health = Window:AddTab({ Title = "Health", Icon = "heart" }),
    Text = Window:AddTab({ Title = "Text", Icon = "type" }),
    Tracer = Window:AddTab({ Title = "Tracer", Icon = "move-up-right" }),
    Skeleton = Window:AddTab({ Title = "Skeleton", Icon = "accessibility" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "sparkles" }),
    Targets = Window:AddTab({ Title = "Targets", Icon = "crosshair" }),
    Settings = Window:AddTab({ Title = "Config", Icon = "save" }),
}

-- // control helpers
local controls = {}

local function add_control(container, spec)
    local current = spec.get()
    local element

    if spec.kind == "toggle" then
        element = container:AddToggle(spec.name, {
            Title = spec.title,
            Description = spec.description,
            Default = current,
            Callback = function(value)
                spec.set(value)
            end,
        })
    elseif spec.kind == "slider" then
        element = container:AddSlider(spec.name, {
            Title = spec.title,
            Description = spec.description,
            Default = current,
            Min = spec.min,
            Max = spec.max,
            Rounding = spec.rounding or 0,
            Callback = function(value)
                local numeric = tonumber(value)
                if numeric then
                    spec.set(numeric)
                end
            end,
        })
    elseif spec.kind == "dropdown" then
        element = container:AddDropdown(spec.name, {
            Title = spec.title,
            Description = spec.description,
            Values = spec.values,
            Default = spec.to_ui and spec.to_ui(current) or current,
            Callback = function(value)
                if value == nil then
                    return
                end
                spec.set(spec.to_lib and spec.to_lib(value) or value)
            end,
        })
    elseif spec.kind == "color" then
        element = container:AddColorpicker(spec.name, {
            Title = spec.title,
            Description = spec.description,
            Default = current,
            Callback = function(value)
                spec.set(value)
            end,
        })
    end

    controls[#controls + 1] = { element = element, spec = spec }
    return element
end

local function sync_controls()
    for _, control in ipairs(controls) do
        local spec = control.spec
        local element = control.element
        local value = spec.get()

        if spec.kind == "dropdown" then
            element:SetValue(spec.to_ui and spec.to_ui(value) or value)
        elseif spec.kind == "color" then
            element:SetValueRGB(value)
        else
            element:SetValue(value)
        end
    end
end

local function title_case(value)
    return value:sub(1, 1):upper() .. value:sub(2)
end

local function lower_case(value)
    return value:lower()
end

-- // targets
local esp_targets = {} -- instance -> { player = Player?, label = string }
local player_connections = {}
local custom_targets = {}
local show_players = true
local running = true
local scan_interval = 0.25

local function track(instance, player, full)
    if not instance then
        return
    end

    local info = esp_targets[instance]
    if info then
        if player then
            info.player = player
        end
        return
    end

    esplib.add_box(instance)
    esplib.add_dynamic_text(instance, "name", player and player.Name or instance.Name)
    esplib.add_distance(instance)

    if full then
        esplib.add_healthbar(instance)
        esplib.add_tracer(instance)
        esplib.add_skeleton(instance)
        esplib.add_head_dot(instance)
    end

    esp_targets[instance] = {
        player = player,
        label = player and player.Name or instance.Name,
        full = full and true or false,
    }
end

local function untrack(instance)
    if not instance then
        return
    end
    esp_targets[instance] = nil
    esplib.remove_esp(instance)
end

local function untrack_all(predicate)
    for instance, info in pairs(esp_targets) do
        if not predicate or predicate(instance, info) then
            untrack(instance)
        end
    end
end

local function track_player_character(player)
    if not show_players or player == LocalPlayer then
        return
    end

    local character = player.Character
    if not character then
        return
    end

    for instance, info in pairs(esp_targets) do
        if info.player == player and instance ~= character then
            untrack(instance)
        end
    end

    track(character, player, true)
end

local function watch_player(player)
    if player == LocalPlayer then
        return
    end

    track_player_character(player)

    if player_connections[player] then
        return
    end

    player_connections[player] = {
        added = player.CharacterAdded:Connect(function()
            track_player_character(player)
        end),
        removed = player.CharacterRemoving:Connect(function()
            for instance, info in pairs(esp_targets) do
                if info.player == player then
                    untrack(instance)
                end
            end
        end),
    }
end

local function unwatch_player(player)
    local connections = player_connections[player]
    if connections then
        if connections.added then
            connections.added:Disconnect()
        end
        if connections.removed then
            connections.removed:Disconnect()
        end
    end
    player_connections[player] = nil

    for instance, info in pairs(esp_targets) do
        if info.player == player then
            untrack(instance)
        end
    end
end

local function set_players_enabled(enabled)
    show_players = enabled
    if enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            watch_player(player)
        end
    else
        untrack_all(function(_, info)
            return info.player ~= nil
        end)
    end
end

local function is_player_character(instance)
    local current = instance
    while current and current ~= workspace do
        if Players:GetPlayerFromCharacter(current) then
            return true
        end
        current = current.Parent
    end
    return false
end

local function is_trackable(instance)
    return instance:IsA("BasePart")
        or instance:IsA("Model")
        or instance:IsA("Accessory")
        or instance:IsA("Tool")
end

local function track_matching(instance, name)
    if instance.Name ~= name or not is_trackable(instance) then
        return 0
    end
    if esp_targets[instance] or is_player_character(instance) then
        return 0
    end
    track(instance, nil, false)
    return 1
end

local function add_custom_target(name)
    if not name or name == "" then
        return false
    end
    if custom_targets[name] then
        return true
    end

    custom_targets[name] = true

    local budget = MAX_CUSTOM_INSTANCES
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if budget <= 0 then
            break
        end
        budget = budget - track_matching(descendant, name)
    end
    return true
end

local function remove_custom_target(name)
    if not custom_targets[name] then
        return
    end
    custom_targets[name] = nil

    for instance, info in pairs(esp_targets) do
        if not info.player and info.label == name then
            untrack(instance)
        end
    end
end

local function custom_target_list()
    local names = {}
    for name in pairs(custom_targets) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

for _, player in ipairs(Players:GetPlayers()) do
    watch_player(player)
end

Players.PlayerAdded:Connect(watch_player)
Players.PlayerRemoving:Connect(unwatch_player)

local function custom_instance_count()
    local count = 0
    for _, info in pairs(esp_targets) do
        if not info.player then
            count = count + 1
        end
    end
    return count
end

workspace.DescendantAdded:Connect(function(descendant)
    if next(custom_targets) == nil then
        return
    end
    if custom_targets[descendant.Name] and custom_instance_count() < MAX_CUSTOM_INSTANCES then
        track_matching(descendant, descendant.Name)
    end
end)

local function resync()
    if not running then
        return
    end

    for instance in pairs(esp_targets) do
        if instance.Parent == nil then
            esp_targets[instance] = nil
        end
    end

    if not show_players then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character and not esp_targets[character] then
                track_player_character(player)
            end
        end
    end
end

-- // main tab
local general = Tabs.General:AddSection("ESP")

local master_toggle = add_control(general, {
    kind = "toggle",
    name = "ESPEnabled",
    title = "ESP enabled",
    description = "Master switch for every esp drawing",
    get = function()
        return esplib.enabled
    end,
    set = function(value)
        esplib.enabled = value
    end,
})

general:AddKeybind("ESPToggleKey", {
    Title = "Toggle key",
    Description = "Toggles the master switch",
    Mode = "Toggle",
    Default = "F3",
    Callback = function(value)
        master_toggle:SetValue(value)
    end,
})

local player_group = Tabs.General:AddSection("Player targets")

add_control(player_group, {
    kind = "toggle",
    name = "ShowPlayers",
    title = "Players",
    description = "Track every player in the server",
    get = function()
        return show_players
    end,
    set = function(value)
        set_players_enabled(value)
    end,
})

add_control(player_group, {
    kind = "toggle",
    name = "ShowTeammates",
    title = "Show teammates",
    description = "Draw players on your own team",
    get = function()
        return not esplib.team.check
    end,
    set = function(value)
        esplib.team.check = not value
    end,
})

add_control(player_group, {
    kind = "toggle",
    name = "TeamColors",
    title = "Team colours",
    description = "Colour players by friendly / enemy",
    get = function()
        return esplib.team.colors
    end,
    set = function(value)
        esplib.team.colors = value
    end,
})

add_control(player_group, {
    kind = "toggle",
    name = "UseTeamColor",
    title = "Use Roblox team colour",
    description = "Use Player.TeamColor instead of the friendly / enemy colours",
    get = function()
        return esplib.team.use_team_color
    end,
    set = function(value)
        esplib.team.use_team_color = value
    end,
})

add_control(player_group, {
    kind = "color",
    name = "FriendlyColor",
    title = "Friendly colour",
    description = "Accent for teammates and non-player targets",
    get = function()
        return esplib.team.friendly
    end,
    set = function(value)
        esplib.team.friendly = value
    end,
})

add_control(player_group, {
    kind = "color",
    name = "EnemyColor",
    title = "Enemy colour",
    description = "Accent for enemies",
    get = function()
        return esplib.team.enemy
    end,
    set = function(value)
        esplib.team.enemy = value
    end,
})

local filter_group = Tabs.General:AddSection("Filters")

add_control(filter_group, {
    kind = "toggle",
    name = "VisibilityCheck",
    title = "Visibility check",
    description = "Raycast to the target and skip it when a wall is in the way",
    get = function()
        return esplib.filters.visibility_check
    end,
    set = function(value)
        esplib.filters.visibility_check = value
    end,
})

add_control(filter_group, {
    kind = "slider",
    name = "MaxDistance",
    title = "Max distance",
    description = "Studs, 0 = unlimited",
    min = 0,
    max = 25000,
    rounding = 0,
    get = function()
        return esplib.filters.max_distance
    end,
    set = function(value)
        esplib.filters.max_distance = value
    end,
})

add_control(filter_group, {
    kind = "toggle",
    name = "MinHealthEnabled",
    title = "Minimum health",
    description = "Hide targets whose health is at or below the value",
    get = function()
        return esplib.minimum_health.enabled
    end,
    set = function(value)
        esplib.minimum_health.enabled = value
    end,
})

add_control(filter_group, {
    kind = "slider",
    name = "MinHealthValue",
    title = "Minimum health value",
    min = 0,
    max = 1000,
    rounding = 0,
    get = function()
        return esplib.minimum_health.value
    end,
    set = function(value)
        esplib.minimum_health.value = value
    end,
})

add_control(filter_group, {
    kind = "slider",
    name = "RefreshRate",
    title = "Target refresh (ms)",
    description = "How often missed players / targets are picked up",
    min = 50,
    max = 2000,
    rounding = 0,
    get = function()
        return math.floor(scan_interval * 1000 + 0.5)
    end,
    set = function(value)
        scan_interval = math.max(value, 50) / 1000
    end,
})

Tabs.General:AddButton({
    Title = "Unload ESP",
    Description = "Removes every drawing and closes this interface",
    Callback = function()
        Window:Dialog({
            Title = "Unload",
            Content = "Remove every esp drawing and close the interface?",
            Buttons = {
                {
                    Title = "Unload",
                    Callback = function()
                        running = false
                        untrack_all()
                        esplib.unload()
                        Window:Destroy()
                    end,
                },
                {
                    Title = "Cancel",
                    Callback = function() end,
                },
            },
        })
    end,
})

-- // box tab
local box_group = Tabs.Box:AddSection("Box")

add_control(box_group, {
    kind = "toggle",
    name = "BoxEnabled",
    title = "Box",
    description = "Draw a box around the target",
    get = function()
        return esplib.box.enabled
    end,
    set = function(value)
        esplib.box.enabled = value
    end,
})

add_control(box_group, {
    kind = "dropdown",
    name = "BoxType",
    title = "Box type",
    values = { "Normal", "Corner" },
    get = function()
        return esplib.box.type
    end,
    set = function(value)
        esplib.box.type = value
    end,
    to_ui = title_case,
    to_lib = lower_case,
})

add_control(box_group, {
    kind = "slider",
    name = "BoxPadding",
    title = "Padding",
    description = "Multiplier applied to every bound corner",
    min = 1,
    max = 3,
    rounding = 2,
    get = function()
        return esplib.box.padding
    end,
    set = function(value)
        esplib.box.padding = value
    end,
})

add_control(box_group, {
    kind = "slider",
    name = "BoxThickness",
    title = "Outline thickness",
    min = 1,
    max = 6,
    rounding = 0,
    get = function()
        return esplib.box.thickness
    end,
    set = function(value)
        esplib.box.thickness = value
    end,
})

add_control(box_group, {
    kind = "slider",
    name = "BoxCornerLength",
    title = "Corner length",
    description = "Corner mode only, fraction of the shortest side",
    min = 0.05,
    max = 0.5,
    rounding = 2,
    get = function()
        return esplib.box.corner_length
    end,
    set = function(value)
        esplib.box.corner_length = value
    end,
})

add_control(box_group, {
    kind = "color",
    name = "BoxFill",
    title = "Box colour",
    get = function()
        return esplib.box.fill
    end,
    set = function(value)
        esplib.box.fill = value
    end,
})

add_control(box_group, {
    kind = "color",
    name = "BoxOutline",
    title = "Outline colour",
    get = function()
        return esplib.box.outline
    end,
    set = function(value)
        esplib.box.outline = value
    end,
})

-- // health tab
local health_group = Tabs.Health:AddSection("Health bar")

add_control(health_group, {
    kind = "toggle",
    name = "HealthbarEnabled",
    title = "Health bar",
    description = "Bar to the left of the target",
    get = function()
        return esplib.healthbar.enabled
    end,
    set = function(value)
        esplib.healthbar.enabled = value
    end,
})

add_control(health_group, {
    kind = "slider",
    name = "HealthbarWidth",
    title = "Bar width",
    min = 1,
    max = 8,
    rounding = 0,
    get = function()
        return esplib.healthbar.width
    end,
    set = function(value)
        esplib.healthbar.width = value
    end,
})

add_control(health_group, {
    kind = "color",
    name = "HealthbarFill",
    title = "Bar colour",
    get = function()
        return esplib.healthbar.fill
    end,
    set = function(value)
        esplib.healthbar.fill = value
    end,
})

add_control(health_group, {
    kind = "color",
    name = "HealthbarOutline",
    title = "Bar outline colour",
    get = function()
        return esplib.healthbar.outline
    end,
    set = function(value)
        esplib.healthbar.outline = value
    end,
})

local health_text_group = Tabs.Health:AddSection("Health text")

add_control(health_text_group, {
    kind = "toggle",
    name = "HealthTextEnabled",
    title = "Health text",
    description = "Shows health below the target",
    get = function()
        return esplib.healthbar.text.enabled
    end,
    set = function(value)
        esplib.healthbar.text.enabled = value
    end,
})

add_control(health_text_group, {
    kind = "dropdown",
    name = "HealthTextFormat",
    title = "Format",
    values = { "Both", "Numbers", "Percent" },
    get = function()
        return esplib.healthbar.text.format
    end,
    set = function(value)
        esplib.healthbar.text.format = value
    end,
    to_ui = title_case,
    to_lib = lower_case,
})

add_control(health_text_group, {
    kind = "slider",
    name = "HealthTextSize",
    title = "Size",
    min = 8,
    max = 24,
    rounding = 0,
    get = function()
        return esplib.healthbar.text.size
    end,
    set = function(value)
        esplib.healthbar.text.size = value
    end,
})

add_control(health_text_group, {
    kind = "color",
    name = "HealthTextColor",
    title = "Text colour",
    get = function()
        return esplib.healthbar.text.fill
    end,
    set = function(value)
        esplib.healthbar.text.fill = value
    end,
})

-- // text tab
local name_group = Tabs.Text:AddSection("Names")

add_control(name_group, {
    kind = "toggle",
    name = "NamesEnabled",
    title = "Names",
    description = "Draw the target name above the box",
    get = function()
        return esplib.dynamic_text.enabled
    end,
    set = function(value)
        esplib.dynamic_text.enabled = value
    end,
})

add_control(name_group, {
    kind = "slider",
    name = "TextSize",
    title = "Size",
    min = 8,
    max = 24,
    rounding = 0,
    get = function()
        return esplib.dynamic_text.size
    end,
    set = function(value)
        esplib.dynamic_text.size = value
    end,
})

add_control(name_group, {
    kind = "slider",
    name = "TextOffset",
    title = "Y offset",
    description = "Pixels above the box",
    min = -50,
    max = 100,
    rounding = 0,
    get = function()
        return esplib.dynamic_text.y_offset
    end,
    set = function(value)
        esplib.dynamic_text.y_offset = value
    end,
})

add_control(name_group, {
    kind = "slider",
    name = "TextSpacing",
    title = "Line spacing",
    description = "Gap between stacked texts",
    min = 0,
    max = 12,
    rounding = 0,
    get = function()
        return esplib.dynamic_text.line_spacing
    end,
    set = function(value)
        esplib.dynamic_text.line_spacing = value
    end,
})

add_control(name_group, {
    kind = "color",
    name = "TextColor",
    title = "Text colour",
    get = function()
        return esplib.dynamic_text.fill
    end,
    set = function(value)
        esplib.dynamic_text.fill = value
    end,
})

add_control(name_group, {
    kind = "toggle",
    name = "TextOutline",
    title = "Text outline",
    description = "Dark outline behind names and health text",
    get = function()
        return esplib.dynamic_text.outline
    end,
    set = function(value)
        esplib.dynamic_text.outline = value
    end,
})

local distance_group = Tabs.Text:AddSection("Distance")

add_control(distance_group, {
    kind = "toggle",
    name = "DistanceEnabled",
    title = "Distance",
    description = "Shows the distance below the target",
    get = function()
        return esplib.distance.enabled
    end,
    set = function(value)
        esplib.distance.enabled = value
    end,
})

add_control(distance_group, {
    kind = "slider",
    name = "DistanceSize",
    title = "Size",
    min = 8,
    max = 24,
    rounding = 0,
    get = function()
        return esplib.distance.size
    end,
    set = function(value)
        esplib.distance.size = value
    end,
})

add_control(distance_group, {
    kind = "color",
    name = "DistanceColor",
    title = "Text colour",
    get = function()
        return esplib.distance.fill
    end,
    set = function(value)
        esplib.distance.fill = value
    end,
})

add_control(distance_group, {
    kind = "toggle",
    name = "DistanceOutline",
    title = "Text outline",
    get = function()
        return esplib.distance.outline
    end,
    set = function(value)
        esplib.distance.outline = value
    end,
})

-- // tracer tab
local tracer_group = Tabs.Tracer:AddSection("Tracer")

add_control(tracer_group, {
    kind = "toggle",
    name = "TracerEnabled",
    title = "Tracer",
    description = "Line from an origin to the target",
    get = function()
        return esplib.tracer.enabled
    end,
    set = function(value)
        esplib.tracer.enabled = value
    end,
})

add_control(tracer_group, {
    kind = "dropdown",
    name = "TracerOrigin",
    title = "Origin",
    values = { "Mouse", "Head", "Top", "Bottom", "Center", "Custom" },
    get = function()
        return esplib.tracer.from
    end,
    set = function(value)
        esplib.tracer.from = value
    end,
    to_ui = title_case,
    to_lib = lower_case,
})

add_control(tracer_group, {
    kind = "slider",
    name = "TracerOriginX",
    title = "Custom origin X",
    min = 0,
    max = 4000,
    rounding = 0,
    get = function()
        return math.floor(esplib.tracer.origin.X)
    end,
    set = function(value)
        esplib.tracer.origin = Vector2.new(value, esplib.tracer.origin.Y)
    end,
})

add_control(tracer_group, {
    kind = "slider",
    name = "TracerOriginY",
    title = "Custom origin Y",
    min = 0,
    max = 2000,
    rounding = 0,
    get = function()
        return math.floor(esplib.tracer.origin.Y)
    end,
    set = function(value)
        esplib.tracer.origin = Vector2.new(esplib.tracer.origin.X, value)
    end,
})

add_control(tracer_group, {
    kind = "slider",
    name = "TracerFromOffset",
    title = "Default origin offset",
    description = "Used when the custom origin is 0, 0",
    min = 0,
    max = 2000,
    rounding = 0,
    get = function()
        return esplib.tracer.from_offset
    end,
    set = function(value)
        esplib.tracer.from_offset = value
    end,
})

local tracer_origin_x, tracer_origin_y

for _, control in ipairs(controls) do
    if control.spec.name == "TracerOriginX" then
        tracer_origin_x = control.element
    elseif control.spec.name == "TracerOriginY" then
        tracer_origin_y = control.element
    end
end

tracer_group:AddButton({
    Title = "Reset custom origin",
    Description = "Back to the default screen point",
    Callback = function()
        esplib.tracer.origin = Vector2.new(0, 0)
        tracer_origin_x:SetValue(0)
        tracer_origin_y:SetValue(0)
    end,
})

add_control(tracer_group, {
    kind = "color",
    name = "TracerFill",
    title = "Colour",
    get = function()
        return esplib.tracer.fill
    end,
    set = function(value)
        esplib.tracer.fill = value
    end,
})

add_control(tracer_group, {
    kind = "color",
    name = "TracerOutline",
    title = "Outline colour",
    get = function()
        return esplib.tracer.outline
    end,
    set = function(value)
        esplib.tracer.outline = value
    end,
})

add_control(tracer_group, {
    kind = "slider",
    name = "TracerThickness",
    title = "Thickness",
    min = 1,
    max = 6,
    rounding = 0,
    get = function()
        return esplib.tracer.thickness
    end,
    set = function(value)
        esplib.tracer.thickness = value
    end,
})

add_control(tracer_group, {
    kind = "slider",
    name = "TracerOutlineThickness",
    title = "Outline thickness",
    min = 1,
    max = 8,
    rounding = 0,
    get = function()
        return esplib.tracer.outline_thickness
    end,
    set = function(value)
        esplib.tracer.outline_thickness = value
    end,
})

-- // skeleton tab
local skeleton_group = Tabs.Skeleton:AddSection("Skeleton")

add_control(skeleton_group, {
    kind = "toggle",
    name = "SkeletonEnabled",
    title = "Skeleton",
    description = "Bone lines for R15 and R6 rigs",
    get = function()
        return esplib.skeleton.enabled
    end,
    set = function(value)
        esplib.skeleton.enabled = value
    end,
})

add_control(skeleton_group, {
    kind = "color",
    name = "SkeletonColor",
    title = "Bone colour",
    get = function()
        return esplib.skeleton.color
    end,
    set = function(value)
        esplib.skeleton.color = value
    end,
})

add_control(skeleton_group, {
    kind = "color",
    name = "SkeletonHeadColor",
    title = "Head circle colour",
    get = function()
        return esplib.skeleton.head
    end,
    set = function(value)
        esplib.skeleton.head = value
    end,
})

add_control(skeleton_group, {
    kind = "slider",
    name = "SkeletonThickness",
    title = "Thickness",
    min = 1,
    max = 6,
    rounding = 0,
    get = function()
        return esplib.skeleton.thickness
    end,
    set = function(value)
        esplib.skeleton.thickness = value
    end,
})

add_control(skeleton_group, {
    kind = "toggle",
    name = "SkeletonHeadCircle",
    title = "Head circle",
    description = "Circle around the head as part of the skeleton",
    get = function()
        return esplib.skeleton.head_circle
    end,
    set = function(value)
        esplib.skeleton.head_circle = value
    end,
})

local dot_group = Tabs.Skeleton:AddSection("Head dot")

add_control(dot_group, {
    kind = "toggle",
    name = "HeadDotEnabled",
    title = "Head dot",
    description = "Dot on the target head",
    get = function()
        return esplib.head_dot.enabled
    end,
    set = function(value)
        esplib.head_dot.enabled = value
    end,
})

add_control(dot_group, {
    kind = "toggle",
    name = "HeadDotFilled",
    title = "Filled",
    get = function()
        return esplib.head_dot.filled
    end,
    set = function(value)
        esplib.head_dot.filled = value
    end,
})

add_control(dot_group, {
    kind = "slider",
    name = "HeadDotSize",
    title = "Size",
    description = "Multiplier of the projected head radius",
    min = 0.1,
    max = 3,
    rounding = 2,
    get = function()
        return esplib.head_dot.size
    end,
    set = function(value)
        esplib.head_dot.size = value
    end,
})

add_control(dot_group, {
    kind = "slider",
    name = "HeadDotThickness",
    title = "Outline thickness",
    min = 1,
    max = 6,
    rounding = 0,
    get = function()
        return esplib.head_dot.thickness
    end,
    set = function(value)
        esplib.head_dot.thickness = value
    end,
})

add_control(dot_group, {
    kind = "color",
    name = "HeadDotColor",
    title = "Colour",
    get = function()
        return esplib.head_dot.fill
    end,
    set = function(value)
        esplib.head_dot.fill = value
    end,
})

-- // misc tab
local accent_group = Tabs.Misc:AddSection("Accents")

add_control(accent_group, {
    kind = "toggle",
    name = "Rainbow",
    title = "Rainbow",
    description = "Cycles the accent colour of every drawing",
    get = function()
        return esplib.rainbow
    end,
    set = function(value)
        esplib.rainbow = value
    end,
})

add_control(accent_group, {
    kind = "slider",
    name = "RainbowSpeed",
    title = "Rainbow speed",
    min = 0.1,
    max = 3,
    rounding = 2,
    get = function()
        return esplib.rainbow_speed
    end,
    set = function(value)
        esplib.rainbow_speed = value
    end,
})

local crosshair_group = Tabs.Misc:AddSection("Crosshair")

add_control(crosshair_group, {
    kind = "toggle",
    name = "CrosshairEnabled",
    title = "Crosshair",
    description = "Screen centre crosshair",
    get = function()
        return esplib.crosshair.enabled
    end,
    set = function(value)
        esplib.crosshair.enabled = value
    end,
})

add_control(crosshair_group, {
    kind = "slider",
    name = "CrosshairSize",
    title = "Size",
    min = 2,
    max = 100,
    rounding = 0,
    get = function()
        return esplib.crosshair.size
    end,
    set = function(value)
        esplib.crosshair.size = value
    end,
})

add_control(crosshair_group, {
    kind = "slider",
    name = "CrosshairGap",
    title = "Gap",
    min = 0,
    max = 50,
    rounding = 0,
    get = function()
        return esplib.crosshair.gap
    end,
    set = function(value)
        esplib.crosshair.gap = value
    end,
})

add_control(crosshair_group, {
    kind = "slider",
    name = "CrosshairThickness",
    title = "Thickness",
    min = 1,
    max = 6,
    rounding = 0,
    get = function()
        return esplib.crosshair.thickness
    end,
    set = function(value)
        esplib.crosshair.thickness = value
    end,
})

add_control(crosshair_group, {
    kind = "slider",
    name = "CrosshairOutlineThickness",
    title = "Outline thickness",
    min = 1,
    max = 8,
    rounding = 0,
    get = function()
        return esplib.crosshair.outline_thickness
    end,
    set = function(value)
        esplib.crosshair.outline_thickness = value
    end,
})

add_control(crosshair_group, {
    kind = "color",
    name = "CrosshairColor",
    title = "Colour",
    get = function()
        return esplib.crosshair.fill
    end,
    set = function(value)
        esplib.crosshair.fill = value
    end,
})

add_control(crosshair_group, {
    kind = "color",
    name = "CrosshairOutline",
    title = "Outline colour",
    get = function()
        return esplib.crosshair.outline
    end,
    set = function(value)
        esplib.crosshair.outline = value
    end,
})

-- // targets tab
Tabs.Targets:AddParagraph({
    Title = "Custom objects",
    Content = "Add any instance by name (e.g. Battery, MoneyPrinter). Every current and future\ninstance with that name in Workspace gets a box, a label and a distance.",
})

local target_input = Tabs.Targets:AddInput("CustomTargetName", {
    Title = "Instance name",
    Description = "Exact name, case sensitive",
    Placeholder = "Battery",
    Finished = false,
})

local target_dropdown
local refreshing_targets = false

local function refresh_target_dropdown()
    if refreshing_targets or not target_dropdown then
        return
    end

    refreshing_targets = true
    local names = custom_target_list()
    local selected = {}
    for _, name in ipairs(names) do
        selected[name] = true
    end
    target_dropdown:SetValues(names)
    target_dropdown:SetValue(selected)
    refreshing_targets = false
end

target_dropdown = Tabs.Targets:AddDropdown("CustomTargetList", {
    Title = "Active targets",
    Description = "Deselect a target to stop drawing it",
    Values = custom_target_list(),
    Multi = true,
    Default = {},
    Callback = function(values)
        if type(values) ~= "table" then
            return
        end

        local changed = false
        for name in pairs(custom_targets) do
            if not values[name] then
                remove_custom_target(name)
                changed = true
            end
        end
        if changed then
            refresh_target_dropdown()
        end
    end,
})

Tabs.Targets:AddButton({
    Title = "Add target",
    Callback = function()
        local name = target_input.Value
        if type(name) ~= "string" then
            return
        end
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then
            return
        end
        if add_custom_target(name) then
            target_input:SetValue("")
            refresh_target_dropdown()
            Fluent:Notify({
                Title = "Targets",
                Content = string.format("Tracking %q", name),
                Duration = 4,
            })
        end
    end,
})

Tabs.Targets:AddButton({
    Title = "Clear targets",
    Callback = function()
        for name in pairs(custom_targets) do
            remove_custom_target(name)
        end
        refresh_target_dropdown()
    end,
})

-- // settings tab
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder(CONFIG_FOLDER)
SaveManager:SetFolder(CONFIG_FOLDER)

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Tabs.Settings:AddButton({
    Title = "Reset settings",
    Description = "Restore every library option to its default",
    Callback = function()
        esplib.reset()
        sync_controls()
        Fluent:Notify({
            Title = "Settings",
            Content = "Library options restored",
            Duration = 4,
        })
    end,
})

Window:SelectTab(1)

task.spawn(function()
    while running and not Fluent.Unloaded do
        task.wait(scan_interval)
        resync()
    end
end)

SaveManager:LoadAutoloadConfig()

Fluent:Notify({
    Title = "esp-lib",
    Content = "Interface loaded",
    SubContent = "F3 toggles the ESP, LeftControl minimises the menu",
    Duration = 6,
})

return esplib
