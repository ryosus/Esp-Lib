-- Minimal Roblox API mock for executing esp_lib.lua / esp_gui.lua headlessly.
-- Strict on Drawing properties so typos and wrong value types surface as errors.

local MOCK = {
    drawings = {},
    render = nil,
    connections = {},
    raycast_hit = nil,
    time = 0,
}
MOCK = MOCK

-- math.clamp (Roblox-only in stock Luau)
if not math.clamp then
    function math.clamp(value, minimum, maximum)
        if value < minimum then
            return minimum
        elseif value > maximum then
            return maximum
        end
        return value
    end
end

if not table.find then
    function table.find(list, value)
        for index, entry in ipairs(list) do
            if entry == value then
                return index
            end
        end
    end
end

if not table.clear then
    function table.clear(target)
        for key in pairs(target) do
            target[key] = nil
        end
    end
end

if not table.clone then
    function table.clone(target)
        local copy = {}
        for key, value in pairs(target) do
            copy[key] = value
        end
        return copy
    end
end

-- // Color3
local Color3 = {}
local Color3MT = { __index = Color3, __tostring = function(self)
    return string.format("Color3(%f, %f, %f)", self.R, self.G, self.B)
end }

function Color3.new(r, g, b)
    return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3MT)
end

function Color3.fromRGB(r, g, b)
    return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end

function Color3.fromHSV(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local r, g, b
    local index = i % 6
    if index == 0 then
        r, g, b = v, t, p
    elseif index == 1 then
        r, g, b = q, v, p
    elseif index == 2 then
        r, g, b = p, v, t
    elseif index == 3 then
        r, g, b = p, q, v
    elseif index == 4 then
        r, g, b = t, p, v
    else
        r, g, b = v, p, q
    end
    return Color3.new(r, g, b)
end

function Color3.fromHex(hex)
    local r = tonumber(hex:sub(2, 3), 16) or 0
    local g = tonumber(hex:sub(4, 5), 16) or 0
    local b = tonumber(hex:sub(6, 7), 16) or 0
    return Color3.fromRGB(r, g, b)
end

-- // Vector2
local Vector2 = {}
local Vector2MT = {
    __index = Vector2,
    __add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end,
    __sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end,
    __mul = function(a, b)
        if type(a) == "number" then
            return Vector2.new(a * b.X, a * b.Y)
        end
        return Vector2.new(a.X * b, a.Y * b)
    end,
    __div = function(a, b)
        if type(a) == "number" then
            return Vector2.new(a / b.X, a / b.Y)
        end
        return Vector2.new(a.X / b, a.Y / b)
    end,
    __eq = function(a, b) return a.X == b.X and a.Y == b.Y end,
    __tostring = function(self) return string.format("Vector2(%f, %f)", self.X, self.Y) end,
}

function Vector2.new(x, y)
    return setmetatable({ X = x or 0, Y = y or 0 }, Vector2MT)
end

function Vector2:Min(other)
    return Vector2.new(math.min(self.X, other.X), math.min(self.Y, other.Y))
end

function Vector2:Max(other)
    return Vector2.new(math.max(self.X, other.X), math.max(self.Y, other.Y))
end

function Vector2:Dot(other)
    return self.X * other.X + self.Y * other.Y
end

function Vector2.zero()
    return Vector2.new(0, 0)
end

Vector2MT.__index = function(self, key)
    if key == "Magnitude" then
        return math.sqrt(self.X * self.X + self.Y * self.Y)
    elseif key == "Unit" then
        local magnitude = math.sqrt(self.X * self.X + self.Y * self.Y)
        if magnitude == 0 then
            return Vector2.new(0, 0)
        end
        return Vector2.new(self.X / magnitude, self.Y / magnitude)
    end
    return Vector2[key]
end

-- // Vector3
local Vector3 = {}
local Vector3MT = {
    __add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
    __sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
    __mul = function(a, b)
        if type(a) == "number" then
            return Vector3.new(a * b.X, a * b.Y, a * b.Z)
        end
        return Vector3.new(a.X * b, a.Y * b, a.Z * b)
    end,
    __div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end,
    __tostring = function(self) return string.format("Vector3(%f, %f, %f)", self.X, self.Y, self.Z) end,
}

function Vector3.new(x, y, z)
    return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3MT)
end

Vector3MT.__index = function(self, key)
    if key == "Magnitude" then
        return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
    elseif key == "Unit" then
        local magnitude = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
        if magnitude == 0 then
            return Vector3.new(0, 0, 0)
        end
        return Vector3.new(self.X / magnitude, self.Y / magnitude, self.Z / magnitude)
    end
    return Vector3[key]
end

-- // CFrame (identity rotation)
local CFrame = {}
local CFrameMT = { __index = CFrame }

function CFrame.new(x, y, z)
    if type(x) == "table" then
        return setmetatable({ Position = x }, CFrameMT)
    end
    return setmetatable({ Position = Vector3.new(x, y, z) }, CFrameMT)
end

function CFrame.Angles()
    return CFrame.new(0, 0, 0)
end

function CFrame:PointToWorldSpace(point)
    return self.Position + point
end

function CFrame:PointToObjectSpace(point)
    return point - self.Position
end

function CFrame:VectorToWorldSpace(vector)
    return vector
end

-- // Drawing
local DRAWING_PROPS = {
    Square = {
        Position = "Vector2",
        Size = "Vector2",
        Color = "Color3",
        Thickness = "number",
        Filled = "boolean",
        Transparency = "number",
        Visible = "boolean",
    },
    Line = {
        From = "Vector2",
        To = "Vector2",
        Color = "Color3",
        Thickness = "number",
        Transparency = "number",
        Visible = "boolean",
    },
    Text = {
        Text = "string",
        Position = "Vector2",
        Size = "number",
        Color = "Color3",
        Center = "boolean",
        Outline = "boolean",
        Transparency = "number",
        Visible = "boolean",
        Font = "number",
    },
    Circle = {
        Position = "Vector2",
        Radius = "number",
        Color = "Color3",
        Thickness = "number",
        Filled = "boolean",
        Transparency = "number",
        Visible = "boolean",
    },
}

local function type_matches(value, expected)
    if expected == "Vector2" then
        return type(value) == "table" and value.X ~= nil and value.Y ~= nil
    elseif expected == "Color3" then
        return type(value) == "table" and value.R ~= nil
    end
    return type(value) == expected
end

local Drawing = {}

function Drawing.new(kind)
    local props = DRAWING_PROPS[kind]
    assert(props, "unknown drawing type: " .. tostring(kind))

    local object = {
        Type = kind,
        Visible = false,
        Removed = false,
        __writes = 0,
    }

    local meta = {
        __index = function(self, key)
            if key == "Remove" then
                return function(self_inner)
                    rawset(self_inner, "Removed", true)
                    MOCK.removed = (MOCK.removed or 0) + 1
                end
            end
            return nil
        end,
        __newindex = function(self, key, value)
            local expected = props[key]
            if not expected then
                error(string.format("invalid property %q on Drawing.%s", tostring(key), kind), 2)
            end
            if not type_matches(value, expected) then
                error(string.format(
                    "bad value for Drawing.%s.%s: expected %s, got %s",
                    kind,
                    key,
                    expected,
                    type(value)
                ), 2)
            end
            rawset(self, key, value)
            rawset(self, "__writes", (rawget(self, "__writes") or 0) + 1)
        end,
    }

    setmetatable(object, meta)
    table.insert(MOCK.drawings, object)
    return object
end

-- // Instances
local CLASS_CHAINS = {
    Instance = {},
    Part = { Instance = true, PVInstance = true, BasePart = true },
    BasePart = { Instance = true, PVInstance = true, BasePart = true },
    Accessory = { Instance = true },
    Tool = { Instance = true, BackpackItem = true },
    Model = { Instance = true, PVInstance = true },
    Humanoid = { Instance = true },
    Player = { Instance = true },
    Folder = { Instance = true },
}

local Instance = {}
local InstanceMT = { __index = Instance }

local function new_instance(class, properties)
    local object = setmetatable({
        ClassName = class,
        Children = {},
        Parent = nil,
        __chain = CLASS_CHAINS[class] or { Instance = true },
    }, InstanceMT)

    if properties then
        for key, value in pairs(properties) do
            object[key] = value
        end
    end
    return object
end

function Instance:IsA(class)
    return self.ClassName == class or self.__chain[class] == true
end

function Instance:GetChildren()
    local children = {}
    for index, child in ipairs(self.Children) do
        children[index] = child
    end
    return children
end

function Instance:GetDescendants()
    local descendants = {}
    local function walk(node)
        for _, child in ipairs(node.Children) do
            table.insert(descendants, child)
            walk(child)
        end
    end
    walk(self)
    return descendants
end

function Instance:FindFirstChild(name)
    for _, child in ipairs(self.Children) do
        if child.Name == name then
            return child
        end
    end
    return nil
end

function Instance:FindFirstChildOfClass(class)
    for _, child in ipairs(self.Children) do
        if child.ClassName == class then
            return child
        end
    end
    return nil
end

function Instance:FindFirstChildWhichIsA(class)
    for _, child in ipairs(self.Children) do
        if child:IsA(class) then
            return child
        end
    end
    return nil
end

function Instance:AddChild(child)
    child.Parent = self
    table.insert(self.Children, child)
    local descendant_added = rawget(self, "DescendantAdded")
    if descendant_added then
        descendant_added:Fire(child)
    end
    return child
end

function Instance:IsDescendantOf(other)
    local current = self.Parent
    while current do
        if current == other then
            return true
        end
        current = current.Parent
    end
    return false
end

local function part(name, position, size)
    local object = new_instance("Part", {
        Name = name,
        CFrame = CFrame.new(position),
        Size = size or Vector3.new(1, 2, 1),
        Transparency = 0,
    })
    object.Position = object.CFrame.Position
    return object
end

local function humanoid()
    return new_instance("Humanoid", {
        Name = "Humanoid",
        Health = 100,
        MaxHealth = 100,
    })
end

local function character(name, position, rig)
    local model = new_instance("Model", { Name = name })
    model:AddChild(humanoid())
    model:AddChild(part("HumanoidRootPart", position, Vector3.new(2, 2, 1)))
    model:AddChild(part("Head", position + Vector3.new(0, 3, 0), Vector3.new(2, 1, 1)))
    model:AddChild(part("Torso", position + Vector3.new(0, 1, 0), Vector3.new(2, 2, 1)))
    model:AddChild(part("UpperTorso", position + Vector3.new(0, 1, 0), Vector3.new(2, 2, 1)))
    model:AddChild(part("LowerTorso", position, Vector3.new(2, 2, 1)))
    model:AddChild(part("Neck", position + Vector3.new(0, 2, 0), Vector3.new(1, 1, 1)))

    if rig ~= "r6" then
        model:AddChild(part("LeftUpperArm", position + Vector3.new(-1, 1, 0)))
        model:AddChild(part("LeftLowerArm", position + Vector3.new(-1, 0, 0)))
        model:AddChild(part("LeftHand", position + Vector3.new(-1, -1, 0)))
        model:AddChild(part("RightUpperArm", position + Vector3.new(1, 1, 0)))
        model:AddChild(part("RightLowerArm", position + Vector3.new(1, 0, 0)))
        model:AddChild(part("RightHand", position + Vector3.new(1, -1, 0)))
        model:AddChild(part("LeftUpperLeg", position + Vector3.new(-0.5, -1, 0)))
        model:AddChild(part("LeftLowerLeg", position + Vector3.new(-0.5, -2, 0)))
        model:AddChild(part("LeftFoot", position + Vector3.new(-0.5, -3, 0)))
        model:AddChild(part("RightUpperLeg", position + Vector3.new(0.5, -1, 0)))
        model:AddChild(part("RightLowerLeg", position + Vector3.new(0.5, -2, 0)))
        model:AddChild(part("RightFoot", position + Vector3.new(0.5, -3, 0)))
    else
        model:AddChild(part("Left Arm", position + Vector3.new(-1, 1, 0)))
        model:AddChild(part("Right Arm", position + Vector3.new(1, 1, 0)))
        model:AddChild(part("Left Leg", position + Vector3.new(-0.5, -1, 0)))
        model:AddChild(part("Right Leg", position + Vector3.new(0.5, -1, 0)))
    end

    return model
end

local BrickColorMT = {
    __eq = function(a, b)
        return a.Color.R == b.Color.R and a.Color.G == b.Color.G and a.Color.B == b.Color.B
    end,
}

local function brick_color(name, color)
    return setmetatable({ Name = name, Color = color }, BrickColorMT)
end

local function new_player(name, team_color, neutral)
    return new_instance("Player", {
        Name = name,
        TeamColor = brick_color("Team " .. name, team_color),
        Team = { Name = "Team " .. name, TeamColor = brick_color("Team " .. name, team_color) },
        Neutral = neutral ~= false,
    })
end

-- // services and workspace
local camera = new_instance("Camera", {
    Name = "Camera",
    CFrame = CFrame.new(0, 0, 0),
    ViewportSize = Vector2.new(1920, 1080),
})

function camera:WorldToViewportPoint(world)
    local relative = world - self.CFrame.Position
    local depth = -relative.Z -- camera looks toward -Z
    if depth <= 1 then
        return Vector3.new(960 + relative.X, 540 - relative.Y, depth), false
    end
    local scale = 1000 / depth
    return Vector3.new(960 + relative.X * scale, 540 - relative.Y * scale, depth), true
end

local workspace_object = new_instance("Workspace", {
    Name = "Workspace",
    CurrentCamera = camera,
})

function workspace_object:Raycast(origin, direction, params)
    MOCK.raycasts = (MOCK.raycasts or 0) + 1
    MOCK.last_ray = { origin = origin, direction = direction, params = params }
    if MOCK.raycast_hit then
        return { Instance = MOCK.raycast_hit, Position = origin, Normal = Vector3.new(0, 1, 0) }
    end
    return nil
end

local function signal()
    local handlers = {}
    return {
        handlers = handlers,
        Connect = function(self, handler)
            table.insert(handlers, handler)
            local connection = { Connected = true }
            connection.Disconnect = function()
                connection.Connected = false
            end
            return connection
        end,
        Fire = function(self, ...)
            for _, handler in ipairs(handlers) do
                handler(...)
            end
        end,
    }
end

local RunService = {
    RenderStepped = signal(),
    Heartbeat = signal(),
    Stepped = signal(),
}

function RunService.RenderStepped:Connect(handler)
    MOCK.render = handler
    local connection = { Connected = true }
    connection.Disconnect = function()
        connection.Connected = false
        if MOCK.render == handler then
            MOCK.render = nil
        end
    end
    table.insert(MOCK.connections, connection)
    return connection
end

workspace_object.DescendantAdded = signal()

local function make_player(name, team_color)
    local player = new_player(name, team_color, false)
    player.Character = nil
    player.CharacterAdded = signal()
    player.CharacterRemoving = signal()
    return player
end

local local_player = make_player("Me", Color3.fromRGB(0, 120, 255))
local ally = make_player("Ally", Color3.fromRGB(0, 120, 255))
local enemy = make_player("Enemy", Color3.fromRGB(255, 40, 40))

local player_characters = {}

local Players = {
    LocalPlayer = local_player,
    PlayerAdded = signal(),
    PlayerRemoving = signal(),
}

function Players:GetPlayers()
    return { local_player, ally, enemy }
end

function Players:GetPlayerFromCharacter(model)
    return player_characters[model]
end

function Players:GetPlayerByUserId()
    return nil
end

local UserInputService = {
    GetMouseLocation = function()
        return Vector2.new(640, 300)
    end,
    InputBegan = signal(),
}

local HttpService = {
    GenerateGUID = function()
        return "guid"
    end,
    JSONEncode = function(_, value)
        return "{}"
    end,
    JSONDecode = function(_, value)
        return {}
    end,
}

local SERVICES = {
    RunService = RunService,
    Players = Players,
    UserInputService = UserInputService,
    HttpService = HttpService,
}

local game_object = {
    PlaceId = 1,
    HttpGet = function(_, url)
        if MOCK.http_get then
            return MOCK.http_get(url)
        end
        return MOCK.http_responses and MOCK.http_responses[url] or ""
    end,
    GetService = function(_, name)
        local service = SERVICES[name]
        if not service then
            error("unmocked service: " .. tostring(name))
        end
        return service
    end,
    GetFullName = function()
        return "Game"
    end,
}

Enum = {
    RaycastFilterType = { Exclude = "Exclude", Include = "Include" },
    KeyCode = { F1 = "F1", F3 = "F3", F4 = "F4", LeftControl = "LeftControl" },
    UserInputType = { MouseButton1 = "MouseButton1" },
}

RaycastParams = {}

function RaycastParams.new()
    return { FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false, RespectCanCollide = true }
end

function getgenv()
    return getfenv()
end

-- Locals shadow globals for assignment in Luau, so export through the environment table.
local ENV = getfenv()

ENV.game = game_object
ENV.workspace = workspace_object
ENV.Enum = Enum
ENV.Drawing = Drawing
ENV.Color3 = Color3
ENV.Vector2 = Vector2
ENV.Vector3 = Vector3
ENV.CFrame = CFrame
ENV.RaycastParams = RaycastParams
ENV.Instance = Instance
ENV.UDim2 = {
    fromOffset = function(x, y)
        return { X = x, Y = y, Kind = "Offset" }
    end,
    new = function(x, y, xo, yo)
        return { X = x, Y = y, XOffset = xo, YOffset = yo }
    end,
}
ENV.UDim = { new = function(scale, offset) return { Scale = scale, Offset = offset } end }
ENV.TweenInfo = { new = function() return {} end }
ENV.warn = print
ENV.wait = function() end

MOCK.tasks = {}
ENV.task = {
    spawn = function(fn)
        table.insert(MOCK.tasks, fn)
        return { Status = "Spawned", Cancel = function() end }
    end,
    defer = function(fn)
        table.insert(MOCK.tasks, fn)
    end,
    wait = function() end,
    delay = function() end,
}

ENV.MOCK_ENTITIES = {
    local_player = local_player,
    ally = ally,
    enemy = enemy,
    player_characters = player_characters,
    camera = camera,
    workspace = workspace_object,
    character = character,
    part = part,
    new_player = new_player,
    new_instance = new_instance,
    signal = signal,
    brick_color = brick_color,
    Vector2 = Vector2,
    Vector3 = Vector3,
    Color3 = Color3,
    CFrame = CFrame,
}

return MOCK
