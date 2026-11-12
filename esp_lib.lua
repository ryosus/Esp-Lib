--[[

    esp-lib.lua
    A library for creating esp visuals in roblox using drawing.
    Provides functions to add boxes, health bars, names, distances, tracers,
    skeletons and head dots to instances.

    Written by tul (@.lutyeh).
    Edited by ryo (@.ryosus).

    Every option lives in `getgenv().esplib` and is read live every frame, so a
    user interface (see esp_gui.lua) can mutate it without reloading the library.

]]

-- // services
local run_service = game:GetService("RunService")
local players = game:GetService("Players")
local user_input_service = game:GetService("UserInputService")
local local_player = players.LocalPlayer

-- // defaults
local defaults = {
    enabled = true, -- master switch

    box = {
        enabled = true,
        type = "normal", -- normal, corner
        padding = 1.15,
        corner_length = 0.25, -- corner mode: fraction of the shortest side
        thickness = 3, -- outline thickness
        fill = Color3.new(1, 1, 1),
        outline = Color3.new(0, 0, 0),
    },
    healthbar = {
        enabled = true,
        width = 1,
        fill = Color3.new(0, 1, 0),
        outline = Color3.new(0, 0, 0),
        text = {
            enabled = false,
            format = "both", -- both, numbers, percent
            size = 13,
            fill = Color3.new(1, 1, 1),
        },
    },
    dynamic_text = {
        enabled = true,
        fill = Color3.new(1, 1, 1),
        size = 13,
        y_offset = 0, -- pixels above the box
        line_spacing = 2,
        outline = true,
    },
    distance = {
        enabled = true,
        fill = Color3.new(1, 1, 1),
        size = 13,
        outline = true,
    },
    tracer = {
        enabled = true,
        fill = Color3.new(1, 1, 1),
        outline = Color3.new(0, 0, 0),
        from = "mouse", -- mouse, head, top, bottom, center, custom
        origin = Vector2.new(0, 0), -- used by `custom`, (0, 0) = default screen point
        from_offset = 135, -- default custom origin: (width / 2, height - from_offset)
        thickness = 1,
        outline_thickness = 3,
    },
    skeleton = {
        enabled = true,
        color = Color3.new(1, 1, 1),
        thickness = 2,
    },
    head_dot = {
        enabled = false,
        filled = true,
        size = 1, -- multiplier of the projected head radius
        thickness = 1,
        fill = Color3.new(1, 1, 1),
    },
    minimum_health = {
        enabled = true,
        value = 0,
    }, -- if health is at or below this value, hide everything for that instance
    team = {
        check = false, -- skip teammates entirely
        colors = false, -- color players by friendly / enemy / team color
        use_team_color = false,
        friendly = Color3.new(0, 1, 0),
        enemy = Color3.new(1, 0, 0),
    },
    filters = {
        max_distance = 0, -- studs, 0 = unlimited
        visibility_check = false,
    },
    rainbow = false,
    rainbow_speed = 0.35,
    crosshair = {
        enabled = false,
        size = 10,
        gap = 4,
        thickness = 1,
        outline_thickness = 3,
        fill = Color3.new(1, 1, 1),
        outline = Color3.new(0, 0, 0),
    },
}

-- // table
local esplib = getgenv().esplib
if type(esplib) ~= "table" then
    esplib = {}
    getgenv().esplib = esplib
end

-- Config values such as Color3 and Vector2 are tables with a metatable; only
-- metatable-less tables are nested option groups. Cloning a Color3 into a plain
-- table breaks every Drawing call, so value types are always assigned by
-- reference.
local function is_config_table(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function value_type(value)
    if typeof then
        return typeof(value)
    end
    return type(value)
end

local function copy_config(source, target)
    for key, value in pairs(source) do
        if is_config_table(value) then
            if not is_config_table(target[key]) then
                target[key] = {}
            end
            copy_config(value, target[key])
        else
            target[key] = value
        end
    end
end

local function merge_config(target, source)
    for key, value in pairs(source) do
        if is_config_table(value) then
            if not is_config_table(target[key]) then
                target[key] = {}
            end
            merge_config(target[key], value)
        elseif value_type(target[key]) ~= value_type(value) then
            -- missing or corrupted option (a stale table where a Color3 belongs)
            target[key] = value
        end
    end
end

merge_config(esplib, defaults)
if type(esplib.defaults) ~= "table" then
    esplib.defaults = {}
end
copy_config(defaults, esplib.defaults)

getgenv().espinstances = getgenv().espinstances or {}
local espinstances = getgenv().espinstances
local espfunctions = {}

-- // constants
local CORNER_SIGNS = {
    { 1, 1, 1 }, { 1, 1, -1 }, { 1, -1, 1 }, { 1, -1, -1 },
    { -1, 1, 1 }, { -1, 1, -1 }, { -1, -1, 1 }, { -1, -1, -1 },
}

local SKELETON_BONES = {
    { "Head", "Neck" },
    { "Neck", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "LowerTorso", "HumanoidRootPart" },

    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },

    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },

    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },

    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },

    -- R6
    { "Torso", "Head" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}

-- // helpers
local function hide_drawings(data)
    local drawings = data.drawings
    for i = 1, #drawings do
        local drawing = drawings[i]
        if drawing.Visible then
            drawing.Visible = false
        end
    end
end

local function record(instance)
    local data = espinstances[instance]
    if not data then
        data = {
            drawings = {},
            texts = {},
            text_order = {},
        }
        espinstances[instance] = data
    end
    return data
end

local function add_drawing(data, drawing)
    table.insert(data.drawings, drawing)
    return drawing
end

local function get_parts(instance)
    local data = espinstances[instance]
    local now = os.clock()
    if data and data.parts and now - (data.parts_at or 0) < 0.5 then
        return data.parts
    end

    local parts = {}
    if instance:IsA("BasePart") then
        parts[1] = instance
    elseif instance:IsA("Accessory") or instance:IsA("Tool") then
        local handle = instance:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            parts[1] = handle
        end
    else
        for _, descendant in ipairs(instance:GetDescendants()) do
            if descendant:IsA("BasePart") then
                table.insert(parts, descendant)
            end
        end
    end

    if data then
        data.parts = parts
        data.parts_at = now
    end
    return parts
end

local function get_reference_position(instance, parts)
    if instance:IsA("BasePart") then
        return instance.Position
    end

    if instance:IsA("Model") then
        local part = instance.PrimaryPart
        if not part then
            part = instance:FindFirstChild("HumanoidRootPart")
                or instance:FindFirstChild("Head")
                or instance:FindFirstChild("Torso")
                or instance:FindFirstChildWhichIsA("BasePart")
        end
        if part then
            return part.Position
        end
    end

    for _, part in ipairs(parts) do
        if part.Parent then
            return part.Position
        end
    end
end

local function get_bounding_box(camera, parts, padding)
    local min = Vector2.new(math.huge, math.huge)
    local max = Vector2.new(-math.huge, -math.huge)
    local onscreen = false

    for _, part in ipairs(parts) do
        if part.Parent then
            local half = (part.Size * 0.5) * padding
            local cf = part.CFrame
            for i = 1, 8 do
                local sign = CORNER_SIGNS[i]
                local world = cf:PointToWorldSpace(
                    Vector3.new(half.X * sign[1], half.Y * sign[2], half.Z * sign[3])
                )
                local position, visible = camera:WorldToViewportPoint(world)
                if visible then
                    local point = Vector2.new(position.X, position.Y)
                    min = min:Min(point)
                    max = max:Max(point)
                    onscreen = true
                end
            end
        end
    end

    return min, max, onscreen
end

local function is_teammate(player)
    if not player or player == local_player then
        return false
    end
    if player.Neutral and local_player and local_player.Neutral then
        return true
    end
    if not local_player then
        return false
    end
    return player.TeamColor == local_player.TeamColor
end

local function rainbow_color()
    return Color3.fromHSV((os.clock() * (esplib.rainbow_speed or 0.35)) % 1, 1, 1)
end

local function clamp_to_viewport(point, viewport)
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local delta = point - center
    local half_x = math.max(viewport.X * 0.5, 1)
    local half_y = math.max(viewport.Y * 0.5, 1)
    local scale = math.min(
        half_x / math.max(math.abs(delta.X), 1e-4),
        half_y / math.max(math.abs(delta.Y), 1e-4)
    )
    if scale > 1 then
        scale = 1
    end
    return center + delta * scale
end

local function format_health(health, max_health, format)
    health = math.floor(health + 0.5)
    max_health = math.max(1, math.floor(max_health + 0.5))
    local percent = math.floor(health / max_health * 100 + 0.5)
    if format == "percent" then
        return percent .. "%"
    elseif format == "numbers" then
        return health .. "/" .. max_health
    end
    return health .. "/" .. max_health .. " [" .. percent .. "%]"
end

-- // instance functions
function espfunctions.add_box(instance)
    if not instance then
        return
    end
    local data = record(instance)
    if data.box then
        return data.box
    end

    local outline = Drawing.new("Square")
    outline.Thickness = esplib.box.thickness
    outline.Filled = false
    outline.Transparency = 1
    outline.Visible = false

    local fill = Drawing.new("Square")
    fill.Thickness = 1
    fill.Filled = false
    fill.Transparency = 1
    fill.Visible = false

    local box = {
        outline = outline,
        fill = fill,
        corner_fill = {},
        corner_outline = {},
    }

    add_drawing(data, outline)
    add_drawing(data, fill)

    for _ = 1, 8 do
        local corner_outline = add_drawing(data, Drawing.new("Line"))
        corner_outline.Thickness = esplib.box.thickness
        corner_outline.Transparency = 1
        corner_outline.Visible = false

        local corner_fill = add_drawing(data, Drawing.new("Line"))
        corner_fill.Thickness = 1
        corner_fill.Transparency = 1
        corner_fill.Visible = false

        table.insert(box.corner_outline, corner_outline)
        table.insert(box.corner_fill, corner_fill)
    end

    data.box = box
    return box
end

function espfunctions.add_healthbar(instance)
    if not instance then
        return
    end
    local data = record(instance)
    if data.healthbar then
        return data.healthbar
    end

    local outline = Drawing.new("Square")
    outline.Thickness = 1
    outline.Filled = true
    outline.Transparency = 1
    outline.Visible = false

    local fill = Drawing.new("Square")
    fill.Filled = true
    fill.Transparency = 1
    fill.Visible = false

    local text = Drawing.new("Text")
    text.Center = true
    text.Outline = true
    text.Font = 1
    text.Transparency = 1
    text.Visible = false

    add_drawing(data, outline)
    add_drawing(data, fill)
    add_drawing(data, text)

    data.healthbar = {
        outline = outline,
        fill = fill,
        text = text,
    }
    return data.healthbar
end

function espfunctions.add_dynamic_text(instance, value_name, text)
    if not instance or not value_name then
        return
    end
    local data = record(instance)

    local existing = data.texts[value_name]
    if existing then
        existing.Text = tostring(text or existing.Text)
        return existing
    end

    local drawing = Drawing.new("Text")
    drawing.Center = true
    drawing.Outline = esplib.dynamic_text.outline
    drawing.Font = 1
    drawing.Transparency = 1
    drawing.Text = tostring(text or instance.Name)
    drawing.Visible = false

    add_drawing(data, drawing)
    data.texts[value_name] = drawing
    table.insert(data.text_order, value_name)
    return drawing
end

function espfunctions.add_name(instance, name)
    return espfunctions.add_dynamic_text(instance, "name", name or (instance and instance.Name) or "?")
end

function espfunctions.set_text(instance, value_name, text)
    local data = instance and espinstances[instance]
    local drawing = data and data.texts[value_name]
    if drawing then
        drawing.Text = tostring(text)
    end
end

function espfunctions.add_distance(instance)
    if not instance then
        return
    end
    local data = record(instance)
    if data.distance then
        return data.distance
    end

    local drawing = Drawing.new("Text")
    drawing.Center = true
    drawing.Outline = esplib.distance.outline
    drawing.Font = 1
    drawing.Transparency = 1
    drawing.Visible = false

    add_drawing(data, drawing)
    data.distance = drawing
    return drawing
end

function espfunctions.add_tracer(instance)
    if not instance then
        return
    end
    local data = record(instance)
    if data.tracer then
        return data.tracer
    end

    local outline = Drawing.new("Line")
    outline.Thickness = esplib.tracer.outline_thickness
    outline.Transparency = 1
    outline.Visible = false

    local fill = Drawing.new("Line")
    fill.Thickness = esplib.tracer.thickness
    fill.Transparency = 1
    fill.Visible = false

    add_drawing(data, outline)
    add_drawing(data, fill)

    data.tracer = {
        outline = outline,
        fill = fill,
    }
    return data.tracer
end

function espfunctions.add_skeleton(instance)
    if not instance then
        return
    end
    local data = record(instance)
    if data.skeleton then
        return data.skeleton
    end

    local lines = {}
    for _ = 1, #SKELETON_BONES do
        local line = Drawing.new("Line")
        line.Thickness = esplib.skeleton.thickness
        line.Transparency = 1
        line.Visible = false
        add_drawing(data, line)
        table.insert(lines, line)
    end

    data.skeleton = {
        bones = SKELETON_BONES,
        lines = lines,
        parts = nil,
        parts_at = 0,
    }
    return data.skeleton
end

function espfunctions.add_head_dot(instance)
    if not instance then
        return
    end
    local data = record(instance)
    if data.head_dot then
        return data.head_dot
    end

    local dot = Drawing.new("Circle")
    dot.Filled = esplib.head_dot.filled
    dot.Thickness = esplib.head_dot.thickness
    dot.Transparency = 1
    dot.Visible = false

    add_drawing(data, dot)
    data.head_dot = dot
    return dot
end

function espfunctions.set_color(instance, color)
    local data = instance and espinstances[instance]
    if data then
        data.color = color
    end
end

function espfunctions.remove_esp(instance)
    local data = instance and espinstances[instance]
    if not data then
        return
    end

    local drawings = data.drawings
    for i = 1, #drawings do
        pcall(function()
            drawings[i]:Remove()
        end)
    end

    espinstances[instance] = nil
end

-- // crosshair
local crosshair = {}

local CROSSHAIR_DIRECTIONS = {
    Vector2.new(1, 0),
    Vector2.new(-1, 0),
    Vector2.new(0, 1),
    Vector2.new(0, -1),
}

local function get_crosshair()
    for i = 1, 4 do
        local entry = crosshair[i]
        if not entry then
            local fill = Drawing.new("Line")
            fill.Visible = false
            local outline = Drawing.new("Line")
            outline.Visible = false
            entry = { fill = fill, outline = outline }
            crosshair[i] = entry
        end
    end
    return crosshair
end

local function update_crosshair(config, viewport)
    local enabled = config.enabled
    if not enabled and #crosshair == 0 then
        return
    end

    local entries = get_crosshair()
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local gap = config.gap
    local size = config.size

    for i = 1, 4 do
        local entry = entries[i]
        if enabled then
            local direction = CROSSHAIR_DIRECTIONS[i]
            local from = center + direction * gap
            local to = center + direction * (gap + size)

            entry.fill.From = from
            entry.fill.To = to
            entry.fill.Thickness = config.thickness
            entry.fill.Color = config.fill
            entry.fill.Visible = true

            entry.outline.From = center + direction * math.max(gap - 1, 0)
            entry.outline.To = center + direction * (gap + size + 1)
            entry.outline.Thickness = config.outline_thickness
            entry.outline.Color = config.outline
            entry.outline.Visible = true
        else
            entry.fill.Visible = false
            entry.outline.Visible = false
        end
    end
end

-- // main thread
local render_connection
local render_hidden = false
local ray_params

local function render()
    local config = esplib
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    local viewport = camera.ViewportSize
    local local_character = local_player and local_player.Character

    if config.crosshair.enabled or #crosshair > 0 then
        update_crosshair(config.crosshair, viewport)
    end

    if not config.enabled then
        for instance, data in pairs(espinstances) do
            if not instance.Parent then
                espfunctions.remove_esp(instance)
            elseif not render_hidden then
                hide_drawings(data)
            end
        end
        render_hidden = true
        return
    end
    render_hidden = false

    local box_config = config.box
    local healthbar_config = config.healthbar
    local health_text_config = healthbar_config.text
    local text_config = config.dynamic_text
    local distance_config = config.distance
    local tracer_config = config.tracer
    local skeleton_config = config.skeleton
    local head_dot_config = config.head_dot
    local team_config = config.team
    local filters = config.filters
    local minimum_health = config.minimum_health
    local check_teams = team_config.check or team_config.colors
    local rainbow = config.rainbow

    local ray_filter = { camera }
    if local_character then
        table.insert(ray_filter, local_character)
    end

    if filters.visibility_check and not ray_params then
        ray_params = RaycastParams.new()
        ray_params.FilterType = Enum.RaycastFilterType.Exclude
        ray_params.IgnoreWater = true
        ray_params.RespectCanCollide = false
    end

    for instance, data in pairs(espinstances) do
        if not instance.Parent then
            espfunctions.remove_esp(instance)
            continue
        end

        local player
        if check_teams then
            player = instance:IsA("Model") and players:GetPlayerFromCharacter(instance) or nil
            if player and team_config.check and is_teammate(player) then
                hide_drawings(data)
                continue
            end
        end

        local humanoid = instance:FindFirstChildOfClass("Humanoid")
        if minimum_health.enabled and humanoid and humanoid.Health <= minimum_health.value then
            hide_drawings(data)
            continue
        end

        local parts = get_parts(instance)
        local position = get_reference_position(instance, parts)
        if not position then
            hide_drawings(data)
            continue
        end

        local distance = (camera.CFrame.Position - position).Magnitude
        if filters.max_distance > 0 and distance > filters.max_distance then
            hide_drawings(data)
            continue
        end

        if ray_params then
            local origin = camera.CFrame.Position
            local delta = position - origin
            local length = delta.Magnitude
            if length > 0.01 then
                table.insert(ray_filter, instance)
                ray_params.FilterDescendantsInstances = ray_filter
                local result = workspace:Raycast(origin, delta.Unit * length, ray_params)
                table.remove(ray_filter)
                if result and result.Instance and result.Instance.Transparency < 0.3 then
                    hide_drawings(data)
                    continue
                end
            end
        end

        local accent
        if rainbow then
            accent = rainbow_color()
        elseif data.color then
            accent = data.color
        end

        if not accent and team_config.colors and player then
            if team_config.use_team_color then
                accent = player.Team and player.Team.TeamColor.Color or player.TeamColor.Color
            else
                accent = is_teammate(player) and team_config.friendly or team_config.enemy
            end
        end

        local min, max, onscreen = get_bounding_box(camera, parts, box_config.padding)

        local center_x = (min.X + max.X) * 0.5
        local center_y = (min.Y + max.Y) * 0.5

        if data.box then
            local box = data.box
            if box_config.enabled and onscreen then
                local width = max.X - min.X
                local height = max.Y - min.Y

                box.outline.Thickness = box_config.thickness
                box.outline.Color = box_config.outline
                box.fill.Color = accent or box_config.fill

                if box_config.type == "corner" then
                    local length = math.min(width, height) * box_config.corner_length
                    local left = min.X
                    local top = min.Y
                    local right = max.X
                    local bottom = max.Y

                    local fill_lines = box.corner_fill
                    local outline_lines = box.corner_outline
                    local outline_color = box_config.outline
                    local fill_color = accent or box_config.fill

                    local corners = {
                        { Vector2.new(left, top), Vector2.new(left + length, top) },
                        { Vector2.new(left, top), Vector2.new(left, top + length) },

                        { Vector2.new(right - length, top), Vector2.new(right, top) },
                        { Vector2.new(right, top), Vector2.new(right, top + length) },

                        { Vector2.new(left, bottom), Vector2.new(left + length, bottom) },
                        { Vector2.new(left, bottom - length), Vector2.new(left, bottom) },

                        { Vector2.new(right - length, bottom), Vector2.new(right, bottom) },
                        { Vector2.new(right, bottom - length), Vector2.new(right, bottom) },
                    }

                    for i = 1, 8 do
                        local from = corners[i][1]
                        local to = corners[i][2]
                        local direction = (to - from).Unit
                        local oFrom = from - direction
                        local oTo = to + direction

                        local outline_line = outline_lines[i]
                        outline_line.From = oFrom
                        outline_line.To = oTo
                        outline_line.Thickness = box_config.thickness
                        outline_line.Color = outline_color
                        outline_line.Visible = true

                        local fill_line = fill_lines[i]
                        fill_line.From = from
                        fill_line.To = to
                        fill_line.Color = fill_color
                        fill_line.Visible = true
                    end

                    box.outline.Visible = false
                    box.fill.Visible = false
                else
                    box.outline.Position = min
                    box.outline.Size = max - min
                    box.outline.Visible = true

                    box.fill.Position = min
                    box.fill.Size = max - min
                    box.fill.Visible = true

                    for _, line in ipairs(box.corner_fill) do
                        line.Visible = false
                    end
                    for _, line in ipairs(box.corner_outline) do
                        line.Visible = false
                    end
                end
            else
                box.outline.Visible = false
                box.fill.Visible = false
                for _, line in ipairs(box.corner_fill) do
                    line.Visible = false
                end
                for _, line in ipairs(box.corner_outline) do
                    line.Visible = false
                end
            end
        end

        if data.healthbar then
            local outline = data.healthbar.outline
            local fill = data.healthbar.fill
            local height = max.Y - min.Y
            local bar_width = math.max(1, healthbar_config.width)
            local padding = 1

            if healthbar_config.enabled and onscreen and humanoid then
                local x = min.X - 4 - bar_width
                local y = min.Y - padding
                local health = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                local fill_height = height * health

                outline.Color = healthbar_config.outline
                outline.Position = Vector2.new(x, y)
                outline.Size = Vector2.new(bar_width + 2 * padding, height + 2 * padding)
                outline.Visible = true

                fill.Color = healthbar_config.fill
                fill.Position = Vector2.new(x + padding, y + padding + height - fill_height)
                fill.Size = Vector2.new(bar_width, fill_height)
                fill.Visible = true
            else
                outline.Visible = false
                fill.Visible = false
            end

            local health_text = data.healthbar.text
            if health_text_config.enabled and onscreen and humanoid then
                local health = humanoid.Health
                local max_health = humanoid.MaxHealth
                if data.health_value ~= health or data.health_max ~= max_health or data.health_format ~= health_text_config.format then
                    data.health_value = health
                    data.health_max = max_health
                    data.health_format = health_text_config.format
                    data.health_string = format_health(health, max_health, health_text_config.format)
                end

                health_text.Text = data.health_string
                health_text.Size = health_text_config.size
                health_text.Color = health_text_config.fill
                health_text.Outline = text_config.outline
                health_text.Position = Vector2.new(
                    center_x,
                    max.Y + 3 + (distance_config.enabled and (distance_config.size + 1) or 0)
                )
                health_text.Visible = true
            else
                health_text.Visible = false
            end
        end

        if #data.text_order > 0 then
            local y = min.Y - text_config.y_offset
            local index = 0
            for i = 1, #data.text_order do
                local drawing = data.texts[data.text_order[i]]
                if text_config.enabled and onscreen then
                    drawing.Size = text_config.size
                    drawing.Color = accent or text_config.fill
                    drawing.Outline = text_config.outline
                    drawing.Position = Vector2.new(center_x, y - index * (text_config.size + text_config.line_spacing))
                    drawing.Visible = true
                    index = index + 1
                else
                    drawing.Visible = false
                end
            end
        end

        if data.distance then
            local drawing = data.distance
            if distance_config.enabled and onscreen then
                local rounded = math.floor(distance)
                if data.distance_value ~= rounded then
                    data.distance_value = rounded
                    drawing.Text = rounded .. "m"
                end
                drawing.Size = distance_config.size
                drawing.Color = accent or distance_config.fill
                drawing.Outline = distance_config.outline
                drawing.Position = Vector2.new(center_x, max.Y + 3)
                drawing.Visible = true
            else
                drawing.Visible = false
            end
        end

        if data.tracer then
            local tracer = data.tracer
            local from

            if tracer_config.enabled then
                local mode = tracer_config.from
                if mode == "mouse" then
                    from = user_input_service:GetMouseLocation()
                elseif mode == "head" then
                    local head = instance:FindFirstChild("Head")
                    if head and head:IsA("BasePart") then
                        local head_position, head_visible = camera:WorldToViewportPoint(head.Position)
                        if head_visible then
                            from = Vector2.new(head_position.X, head_position.Y)
                        end
                    end
                elseif mode == "top" then
                    from = Vector2.new(viewport.X * 0.5, 0)
                elseif mode == "center" then
                    from = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
                elseif mode == "custom" then
                    local origin = tracer_config.origin
                    if origin and (origin.X ~= 0 or origin.Y ~= 0) then
                        from = origin
                    else
                        from = Vector2.new(viewport.X * 0.5, viewport.Y - tracer_config.from_offset)
                    end
                end

                if not from then
                    from = Vector2.new(viewport.X * 0.5, viewport.Y)
                end

                local to
                if onscreen then
                    to = Vector2.new(center_x, center_y)
                else
                    local screen_position = camera:WorldToViewportPoint(position)
                    local point = Vector2.new(screen_position.X, screen_position.Y)
                    if screen_position.Z <= 0 then
                        local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
                        point = center - (point - center)
                    end
                    to = clamp_to_viewport(point, viewport)
                end

                tracer.outline.From = from
                tracer.outline.To = to
                tracer.outline.Thickness = tracer_config.outline_thickness
                tracer.outline.Color = tracer_config.outline
                tracer.outline.Visible = true

                tracer.fill.From = from
                tracer.fill.To = to
                tracer.fill.Thickness = tracer_config.thickness
                tracer.fill.Color = accent or tracer_config.fill
                tracer.fill.Visible = true
            else
                tracer.outline.Visible = false
                tracer.fill.Visible = false
            end
        end

        if data.skeleton then
            local skeleton = data.skeleton
            local visible = skeleton_config.enabled and onscreen

            if visible then
                local now = os.clock()
                if not skeleton.parts or now - skeleton.parts_at > 0.25 then
                    skeleton.parts_at = now
                    local parts_cache = skeleton.parts or {}
                    for i = 1, #skeleton.bones do
                        local bone = skeleton.bones[i]
                        parts_cache[bone[1]] = instance:FindFirstChild(bone[1]) or false
                        parts_cache[bone[2]] = instance:FindFirstChild(bone[2]) or false
                    end
                    skeleton.parts = parts_cache
                end

                local parts_cache = skeleton.parts
                for i = 1, #skeleton.bones do
                    local bone = skeleton.bones[i]
                    local line = skeleton.lines[i]
                    local a = parts_cache[bone[1]]
                    local b = parts_cache[bone[2]]

                    if a and a.Parent and a:IsA("BasePart") and b and b.Parent and b:IsA("BasePart") then
                        local a_position, a_visible = camera:WorldToViewportPoint(a.Position)
                        local b_position, b_visible = camera:WorldToViewportPoint(b.Position)
                        if a_visible and b_visible then
                            line.From = Vector2.new(a_position.X, a_position.Y)
                            line.To = Vector2.new(b_position.X, b_position.Y)
                            line.Color = accent or skeleton_config.color
                            line.Thickness = skeleton_config.thickness
                            line.Visible = true
                        else
                            line.Visible = false
                        end
                    else
                        line.Visible = false
                    end
                end
            else
                for i = 1, #skeleton.lines do
                    skeleton.lines[i].Visible = false
                end
            end
        end

        if data.head_dot then
            local dot = data.head_dot
            local head = instance:FindFirstChild("Head")
            if head_dot_config.enabled and onscreen and head and head:IsA("BasePart") then
                local center, center_visible = camera:WorldToViewportPoint(head.Position)
                local top, top_visible = camera:WorldToViewportPoint(
                    head.CFrame:PointToWorldSpace(Vector3.new(0, head.Size.Y * 0.5, 0))
                )
                local bottom, bottom_visible = camera:WorldToViewportPoint(
                    head.CFrame:PointToWorldSpace(Vector3.new(0, head.Size.Y * -0.5, 0))
                )
                if center_visible and top_visible and bottom_visible then
                    local radius = math.abs(top.Y - bottom.Y) * 0.5 * head_dot_config.size
                    dot.Position = Vector2.new(center.X, center.Y)
                    dot.Radius = math.max(1, radius)
                    dot.Thickness = head_dot_config.thickness
                    dot.Filled = head_dot_config.filled
                    dot.Color = accent or head_dot_config.fill
                    dot.Visible = true
                else
                    dot.Visible = false
                end
            else
                dot.Visible = false
            end
        end
    end
end

-- // lifecycle
function espfunctions.unload()
    for instance in pairs(espinstances) do
        espfunctions.remove_esp(instance)
    end

    for i = 1, #crosshair do
        pcall(function()
            crosshair[i].fill:Remove()
            crosshair[i].outline:Remove()
        end)
        crosshair[i] = nil
    end

    if render_connection then
        render_connection:Disconnect()
        render_connection = nil
    end
    getgenv().esplib_connection = nil
end

function espfunctions.reset()
    copy_config(esplib.defaults, esplib)
end

-- // attach functions
for name, fn in pairs(espfunctions) do
    esplib[name] = fn
end

esplib.api = 2

if getgenv().esplib_connection then
    getgenv().esplib_connection:Disconnect()
end

render_connection = run_service.RenderStepped:Connect(render)
getgenv().esplib_connection = render_connection

return esplib
