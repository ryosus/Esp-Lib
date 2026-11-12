-- Permissive Roblox runtime used to execute the REAL Fluent build and the REAL
-- esp_gui.lua outside of Roblox. Deliberately lenient about Instance
-- properties (Fluent touches hundreds of GUI properties) but faithful about
-- everything the ESP library and the UI wiring depend on: signals, parenting,
-- services, camera projection, drawing objects and players.

local RUNTIME = {
    instances = {},
    connections = {},
    frame = nil,
    notifications = {},
    tasks = {},
}
RUNTIME_MOCK = RUNTIME

-- // primitive types -------------------------------------------------------
Vector2 = {}

local Vector2MT = {}
Vector2MT.__index = function(self, key)
    if key == "Magnitude" then
        return math.sqrt(self.X * self.X + self.Y * self.Y)
    elseif key == "Unit" then
        local magnitude = math.sqrt(self.X * self.X + self.Y * self.Y)
        return Vector2.new(self.X / magnitude, self.Y / magnitude)
    end
    return Vector2MT[key]
end

function Vector2.new(x, y)
    return setmetatable({ X = x or 0, Y = y or 0, __typename = "Vector2" }, Vector2MT)
end
Vector2MT.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
Vector2MT.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
Vector2MT.__mul = function(a, b)
    if type(a) == "number" then
        return Vector2.new(a * b.X, a * b.Y)
    end
    return Vector2.new(a.X * b, a.Y * b)
end
Vector2MT.__div = function(a, b) return Vector2.new(a.X / b, a.Y / b) end
Vector2MT.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
function Vector2MT:Min(other) return Vector2.new(math.min(self.X, other.X), math.min(self.Y, other.Y)) end
function Vector2MT:Max(other) return Vector2.new(math.max(self.X, other.X), math.max(self.Y, other.Y)) end
function Vector2MT:Dot(other) return self.X * other.X + self.Y * other.Y end

Vector3 = {}

local Vector3MT = {}
Vector3MT.__index = function(self, key)
    if key == "Magnitude" then
        return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
    elseif key == "Unit" then
        local magnitude = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
        return Vector3.new(self.X / magnitude, self.Y / magnitude, self.Z / magnitude)
    end
    return Vector3MT[key]
end

function Vector3.new(x, y, z)
    return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __typename = "Vector3" }, Vector3MT)
end
Vector3MT.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3MT.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3MT.__mul = function(a, b)
    if type(a) == "number" then
        return Vector3.new(a * b.X, a * b.Y, a * b.Z)
    end
    return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
Vector3MT.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end

Color3 = {}

local Color3MT = {}
Color3MT.__index = Color3MT
Color3MT.__eq = function(a, b)
    return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end
function Color3.new(r, g, b)
    return setmetatable({ R = r or 0, G = g or 0, B = b or 0, __typename = "Color3" }, Color3MT)
end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHSV(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local index = i % 6
    local r, g, b
    if index == 0 then r, g, b = v, t, p
    elseif index == 1 then r, g, b = q, v, p
    elseif index == 2 then r, g, b = p, v, t
    elseif index == 3 then r, g, b = p, q, v
    elseif index == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return Color3.new(r, g, b)
end
function Color3.fromHex(hex)
    return Color3.fromRGB(tonumber(hex:sub(2, 3), 16) or 0, tonumber(hex:sub(4, 5), 16) or 0, tonumber(hex:sub(6, 7), 16) or 0)
end
function Color3MT:ToHSV()
    local r, g, b = self.R, self.G, self.B
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min
    local hue = 0
    if delta > 0 then
        if max == r then hue = ((g - b) / delta) % 6
        elseif max == g then hue = (b - r) / delta + 2
        else hue = (r - g) / delta + 4 end
        hue = hue / 6
    end
    return hue, (max > 0 and delta / max or 0), max
end
function Color3MT:ToHex() return "#000000" end

function Color3.toHSV(color)
    if getmetatable(color) ~= Color3MT then
        local keys = {}
        for k, v in pairs(color) do
            keys[#keys + 1] = k .. "=" .. tostring(v)
        end
        print("[debug] Color3.toHSV arg:", table.concat(keys, ", "), "mt=", tostring(getmetatable(color)))
        print(debug.traceback())
    end
    return color:ToHSV()
end

UDim = {}

local UDimMT = { __index = {} }
function UDim.new(scale, offset)
    return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDimMT)
end

UDim2 = {}

local UDim2MT = { __index = {} }
function UDim2.new(x, xo, y, yo)
    return setmetatable({ X = { Scale = x or 0, Offset = xo or 0 }, Y = { Scale = y or 0, Offset = yo or 0 } }, UDim2MT)
end
function UDim2.fromOffset(x, y) return UDim2.new(0, x or 0, 0, y or 0) end
function UDim2.fromScale(x, y) return UDim2.new(x or 0, 0, y or 0, 0) end

UDim2MT.__add = function(a, b)
    return UDim2.new(
        a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset,
        a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset
    )
end
UDim2MT.__sub = function(a, b)
    return UDim2.new(
        a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset,
        a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset
    )
end
UDim2MT.__eq = function(a, b)
    return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset
        and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
end

UDimMT.__add = function(a, b) return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset) end
UDimMT.__sub = function(a, b) return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset) end

TweenInfo = {}

function TweenInfo.new(time, style, direction, repeat_count, reverses, delay)
    return { Time = time, Style = style, Direction = direction, RepeatCount = repeat_count, Reverses = reverses, DelayTime = delay }
end

Rect = {}

Rect = {}

function Rect.new(min, max) return { Min = min, Max = max, __typename = "Rect" } end

-- additional Roblox value constructors used by the interface library
CFrame = {}

local CFrameMT = {}
CFrameMT.__index = {
    PointToWorldSpace = function(self, point) return self.Position + point end,
    PointToObjectSpace = function(self, point) return point - self.Position end,
    VectorToWorldSpace = function(self, vector) return vector end,
    VectorToObjectSpace = function(self, vector) return vector end,
    Lerp = function(self) return self end,
}

function CFrame.new(x, y, z)
    local position
    if type(x) == "table" then
        position = x
    else
        position = Vector3.new(x, y, z)
    end
    return setmetatable({ Position = position, __typename = "CFrame" }, CFrameMT)
end
function CFrame.Angles() return CFrame.new(0, 0, 0) end
function CFrame.fromEulerAnglesXYZ() return CFrame.new(0, 0, 0) end
function CFrame.lookAt() return CFrame.new(0, 0, 0) end
CFrame.identity = setmetatable({ Position = Vector3.new(0, 0, 0), __typename = "CFrame" }, CFrameMT)

NumberSequence = {}
function NumberSequence.new(a, b)
    return { Keypoints = { a, b }, __typename = "NumberSequence" }
end

NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(time, value)
    return { Time = time, Value = value, __typename = "NumberSequenceKeypoint" }
end

ColorSequence = {}
function ColorSequence.new(a, b)
    return { Keypoints = { a, b }, __typename = "ColorSequence" }
end

ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(time, value)
    return { Time = time, Value = value, __typename = "ColorSequenceKeypoint" }
end

NumberRange = {}
function NumberRange.new(a, b)
    return { Min = a, Max = b or a, __typename = "NumberRange" }
end

Font = {
    new = function(family, weight, style)
        return { Family = family, Weight = weight, Style = style, __typename = "Font" }
    end,
    fromEnum = function(item) return { Enum = item } end,
    fromId = function(id) return { Family = id } end,
}

-- // enum proxy ------------------------------------------------------------
local EnumItemMT = {
    __tostring = function(self) return "Enum." .. self.EnumType .. "." .. self.Name end,
    __eq = function(a, b) return a.EnumType == b.EnumType and a.Name == b.Name end,
}

local EnumTypeMT = {
    __index = function(self, name)
        local item = setmetatable({ EnumType = rawget(self, "__enum"), Name = name, Value = 0 }, EnumItemMT)
        rawset(self, name, item)
        return item
    end,
    __call = function(self)
        return self
    end,
}

Enum = setmetatable({}, {
    __index = function(self, name)
        local enum = setmetatable({ __enum = name }, EnumTypeMT)
        rawset(self, name, enum)
        return enum
    end,
    __call = function(self, name) return self[name] end,
})

-- // signals ---------------------------------------------------------------
local function new_signal(name)
    local signal = { name = name, handlers = {} }
    function signal:Connect(handler)
        table.insert(self.handlers, handler)
        local connection = { Connected = true }
        connection.Disconnect = function()
            connection.Connected = false
        end
        connection.disconnect = connection.Disconnect
        return connection
    end
    function signal:Once(handler) return self:Connect(handler) end
    function signal:Fire(...)
        for _, handler in ipairs(self.handlers) do
            local ok, err = pcall(handler, ...)
            if not ok then
                RUNTIME.signal_error = err
                warn("[runtime] signal " .. tostring(self.name) .. " handler error: " .. tostring(err))
            end
        end
    end
    function signal:Wait() end
    return signal
end

-- // instances -------------------------------------------------------------
local EVENTS = {
    MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true,
    MouseButton2Click = true, MouseEnter = true, MouseLeave = true,
    InputBegan = true, InputEnded = true, InputChanged = true, FocusLost = true, FocusGained = true,
    Focused = true, FocusReleased = true, TextBoxFocused = true, TextBoxFocusReleased = true,
    MouseWheel = true, TouchTap = true, SelectionChanged = true, ItemFocused = true,
    DragBegin = true, DragStopped = true, StateChanged = true,
    Activated = true, Changed = true, ChildAdded = true, ChildRemoved = true,
    DescendantAdded = true, DescendantRemoving = true, Touched = true,
}

local GEOMETRY_PROPS = {
    AbsolutePosition = true, AbsoluteSize = true, Position = true, Size = true,
    CanvasPosition = true, AbsoluteContentSize = true, AbsoluteCanvasSize = true,
    TextBounds = true, ContentTextSize = true,
}

local SCALAR_DEFAULTS = {
    Text = "", TextSize = 14, TextTransparency = 0, BackgroundTransparency = 0,
    ImageTransparency = 0, Transparency = 0, LayoutOrder = 0, ZIndex = 1,
    Rotation = 0, Visible = true, RichText = false, TextWrapped = false,
    ClipsDescendants = false, Active = false, AutoButtonColor = false,
    CanvasSize = nil, ScrollBarThickness = 4, BorderSizePixel = 0,
}

local BASE_CHAINS = {
    BasePart = {
        Part = true, MeshPart = true, WedgePart = true, CornerWedgePart = true,
        TrussPart = true, Seat = true, VehicleSeat = true, SpawnLocation = true,
        UnionOperation = true, NegateOperation = true, MeshPart = true,
    },
    PVInstance = {
        Part = true, MeshPart = true, WedgePart = true, CornerWedgePart = true,
        TrussPart = true, Seat = true, VehicleSeat = true, SpawnLocation = true,
        Model = true,
    },
    Accoutrement = { Accessory = true, Hat = true },
    BackpackItem = { Tool = true },
    GuiObject = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true,
        ImageButton = true, ScrollingFrame = true, TextBox = true, ViewportFrame = true },
    GuiBase2d = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true,
        ImageButton = true, ScrollingFrame = true, TextBox = true, ViewportFrame = true,
        ScreenGui = true, SurfaceGui = true, BillboardGui = true },
    LayerCollector = { ScreenGui = true, SurfaceGui = true, BillboardGui = true },
}

local InstanceMT = {}

local METHODS = {}

function METHODS:FindFirstChild(name)
    for _, child in ipairs(rawget(self, "__kids")) do
        if rawget(child, "__name") == name then
            return child
        end
    end
    return nil
end

function METHODS:WaitForChild(name)
    return self:FindFirstChild(name)
end

function METHODS:FindFirstChildOfClass(className)
    for _, child in ipairs(rawget(self, "__kids")) do
        if rawget(child, "__class") == className then
            return child
        end
    end
    return nil
end

function METHODS:FindFirstChildWhichIsA(className)
    for _, child in ipairs(rawget(self, "__kids")) do
        if child:IsA(className) then
            return child
        end
    end
    return nil
end

function METHODS:FindFirstAncestorOfClass(className)
    local current = self.Parent
    while current do
        if current.ClassName == className then
            return current
        end
        current = current.Parent
    end
end

function METHODS:GetChildren()
    local children = {}
    for index, child in ipairs(rawget(self, "__kids")) do
        children[index] = child
    end
    return children
end

function METHODS:GetDescendants()
    local descendants = {}
    local function walk(node)
        for _, child in ipairs(rawget(node, "__kids")) do
            table.insert(descendants, child)
            walk(child)
        end
    end
    walk(self)
    return descendants
end

function METHODS:IsA(className)
    local own = rawget(self, "__class")
    if own == className or className == "Instance" then
        return true
    end
    local chain = BASE_CHAINS[className]
    return (chain and chain[own]) or false
end

function METHODS:GetPropertyChangedSignal(property)
    local events = rawget(self, "__events")
    local key = "Changed:" .. tostring(property)
    events[key] = events[key] or new_signal(key)
    return events[key]
end

local MICE = {}

function METHODS:GetMouse()
    local existing = MICE[self]
    if existing then
        return existing
    end
    local mouse = {
        X = 960, Y = 540,
        Target = nil, TargetFilter = nil, Icon = nil,
        Hit = { Position = Vector3.new(0, 0, 0) },
        UnitRay = { Origin = Vector3.new(0, 0, 0), Direction = Vector3.new(0, 0, -1) },
        ViewSizeX = 1920, ViewSizeY = 1080,
    }
    mouse.Move = new_signal("Move")
    mouse.Button1Down = new_signal("Button1Down")
    mouse.Button1Up = new_signal("Button1Up")
    mouse.Button2Down = new_signal("Button2Down")
    mouse.Button2Up = new_signal("Button2Up")
    mouse.KeyDown = new_signal("KeyDown")
    mouse.KeyUp = new_signal("KeyUp")
    MICE[self] = mouse
    return mouse
end

function METHODS:IsFocused() return false end
function METHODS:ReleaseFocus() end
function METHODS:CaptureFocus() end

function METHODS:GetAttribute() return nil end
function METHODS:SetAttribute() end
function METHODS:GetFullName() return rawget(self, "__name") end

function METHODS:Clone()
    local copy = Instance.new(rawget(self, "__class"))
    for key, value in pairs(rawget(self, "__props")) do
        copy[key] = value
    end
    return copy
end

function METHODS:Destroy()
    local parent = rawget(self, "__parent")
    if parent then
        self.Parent = nil
    end
    self.__destroyed = true
end

InstanceMT.__index = function(self, key)
    local props = rawget(self, "__props")
    if key == "Parent" then
        return rawget(self, "__parent")
    elseif key == "Name" then
        return rawget(self, "__name")
    elseif key == "ClassName" then
        return rawget(self, "__class")
    end

    local methods = METHODS[key]
    if methods then
        return methods
    end

    if props[key] ~= nil then
        return props[key]
    end

    -- roblox resolves children by name: script.Parent.Creator
    for _, child in ipairs(rawget(self, "__kids")) do
        if rawget(child, "__name") == key then
            return child
        end
    end

    if EVENTS[key] then
        local events = rawget(self, "__events")
        events[key] = events[key] or new_signal(key)
        return events[key]
    end

    if GEOMETRY_PROPS[key] then
        return Vector2.new(0, 0)
    end

    local default = SCALAR_DEFAULTS[key]
    if default ~= nil then
        return default
    end

    -- class-child sugar: ScrollingFrame.UIListLayout / Frame.UICorner ...
    for _, child in ipairs(rawget(self, "__kids")) do
        if rawget(child, "__class") == key then
            return child
        end
    end

    local reads = RUNTIME.nil_reads
    if reads then
        reads[#reads + 1] = rawget(self, "__class") .. "." .. tostring(key)
        if #reads > 40 then
            table.remove(reads, 1)
        end
    end

    return nil
end

InstanceMT.__newindex = function(self, key, value)
    if key == "Parent" then
        local old = rawget(self, "__parent")
        if old then
            local kids = rawget(old, "__kids")
            for index = #kids, 1, -1 do
                if kids[index] == self then
                    table.remove(kids, index)
                end
            end
        end
        rawset(self, "__parent", value)
        if value then
            table.insert(rawget(value, "__kids"), self)
            local events = rawget(value, "__events")
            if events.ChildAdded then
                events.ChildAdded:Fire(self)
            end
        end
        return
    end

    if key == "Name" then
        rawset(self, "__name", value)
        return
    end

    local props = rawget(self, "__props")
    props[key] = value

    local events = rawget(self, "__events")
    local signal = events["Changed:" .. tostring(key)]
    if signal then
        signal:Fire()
    end
end

Instance = {}

function Instance.new(className, parent)
    local instance = setmetatable({
        __class = className,
        __name = className,
        __kids = {},
        __props = {},
        __events = {},
        __parent = nil,
    }, InstanceMT)

    if parent then
        instance.Parent = parent
    end
    table.insert(RUNTIME.instances, instance)
    return instance
end

-- // services --------------------------------------------------------------
local RunService = {
    RenderStepped = new_signal("RenderStepped"),
    Heartbeat = new_signal("Heartbeat"),
    Stepped = new_signal("Stepped"),
    IsStudio = function() return false end,
    IsClient = function() return true end,
    IsServer = function() return false end,
}

RUNTIME.render_handlers = {}

local function handler_source(handler)
    local ok, source = pcall(debug.info, handler, "s")
    if ok then
        return source
    end
    return nil
end

RUNTIME.is_esp_handler = function(handler)
    local source = handler_source(handler)
    if type(source) ~= "string" then
        return false
    end
    return source == "esp_lib" or source:find("esp_lib.lua", 1, true) ~= nil or source:find("esp-lib.lua", 1, true) ~= nil
end

for _, signal_name in ipairs({ "RenderStepped", "Heartbeat", "Stepped" }) do
    local signal = RunService[signal_name]
    local connect = signal.Connect
    signal.Connect = function(self, handler)
        if signal_name == "RenderStepped" then
            table.insert(RUNTIME.render_handlers, handler)
            RUNTIME.render = handler
        end
        local connection = connect(self, handler)
        local disconnect = connection.Disconnect
        connection.Disconnect = function()
            if signal_name == "RenderStepped" then
                for index = #RUNTIME.render_handlers, 1, -1 do
                    if RUNTIME.render_handlers[index] == handler then
                        table.remove(RUNTIME.render_handlers, index)
                    end
                end
            end
            return disconnect()
        end
        return connection
    end
end

local UserInputService = {
    InputBegan = new_signal("InputBegan"),
    InputEnded = new_signal("InputEnded"),
    InputChanged = new_signal("InputChanged"),
    GetFocusedTextBox = function() return nil end,
    IsKeyDown = function() return false end,
    IsMouseButtonPressed = function() return false end,
    GetMouseLocation = function() return Vector2.new(0, 0) end,
    GetMouseDelta = function() return Vector2.new(0, 0) end,
    TouchEnabled = false,
    KeyboardEnabled = true,
    MouseEnabled = true,
    MouseIconEnabled = false,
    GamepadEnabled = false,
}

local TweenService = {}
function TweenService:Create(instance, info, properties)
    local tween = { Completed = new_signal("Completed") }
    function tween:Play()
        for key, value in pairs(properties) do
            instance[key] = value
        end
        tween.Completed:Fire()
    end
    function tween:Cancel() end
    function tween:Pause() end
    return tween
end

local HttpService = {
    GenerateGUID = function() return "guid" end,
    JSONEncode = function(_, value) return "{}" end,
    JSONDecode = function(_, value) return {} end,
    UrlEncode = function(_, value) return value end,
    HttpEnabled = false,
}

local TextService = {
    GetTextSize = function(_, text, size) return Vector2.new(#tostring(text) * (size or 14) * 0.5, size or 14) end,
}

local GuiService = {
    GetGuiInset = function() return Vector2.new(0, 0), Vector2.new(0, 0) end,
    TopbarInset = { Min = Vector2.new(0, 0), Max = Vector2.new(0, 0) },
}

-- // core instances --------------------------------------------------------
local screen_gui_parent = Instance.new("Folder")
screen_gui_parent.Name = "CoreGui"

local workspace_object = Instance.new("Workspace")
workspace_object.Name = "Workspace"
workspace_object.DescendantAdded = new_signal("DescendantAdded")

local camera = Instance.new("Camera")
camera.Name = "Camera"
camera.CFrame = { Position = Vector3.new(0, 0, 0) }
camera.ViewportSize = Vector2.new(1920, 1080)

function camera:WorldToViewportPoint(world)
    local relative = world - self.CFrame.Position
    local depth = -relative.Z
    if depth <= 1 then
        return Vector3.new(960 + relative.X, 540 - relative.Y, depth), false
    end
    local scale = 1000 / depth
    return Vector3.new(960 + relative.X * scale, 540 - relative.Y * scale, depth), true
end

function camera:WorldToScreenPoint(world)
    return self:WorldToViewportPoint(world)
end

workspace_object.CurrentCamera = camera

function workspace_object:Raycast(origin, direction, params)
    RUNTIME.raycasts = (RUNTIME.raycasts or 0) + 1
    if RUNTIME.raycast_hit then
        return { Instance = RUNTIME.raycast_hit, Position = origin, Normal = Vector3.new(0, 1, 0) }
    end
    return nil
end

-- // drawing ---------------------------------------------------------------
local DRAWING_PROPS = {
    Square = { Position = "Vector2", Size = "Vector2", Color = "Color3", Thickness = "number",
        Filled = "boolean", Transparency = "number", Visible = "boolean" },
    Line = { From = "Vector2", To = "Vector2", Color = "Color3", Thickness = "number",
        Transparency = "number", Visible = "boolean" },
    Text = { Text = "string", Position = "Vector2", Size = "number", Color = "Color3",
        Center = "boolean", Outline = "boolean", Transparency = "number", Visible = "boolean",
        Font = "number" },
    Circle = { Position = "Vector2", Radius = "number", Color = "Color3", Thickness = "number",
        Filled = "boolean", Transparency = "number", Visible = "boolean" },
}

local function value_matches(value, expected)
    if expected == "Vector2" then
        return type(value) == "table" and getmetatable(value) ~= nil and value.X ~= nil and value.Y ~= nil
    elseif expected == "Color3" then
        return type(value) == "table" and getmetatable(value) ~= nil and value.R ~= nil
    end
    return type(value) == expected
end

RaycastParams = {}

function RaycastParams.new()
    return { FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false, RespectCanCollide = true }
end

Drawing = {}
RUNTIME.drawings = {}

function Drawing.new(kind)
    local props = assert(DRAWING_PROPS[kind], "unknown drawing type: " .. tostring(kind))
    local object = { Type = kind, Visible = false, Removed = false }

    setmetatable(object, {
        __index = function(self, key)
            if key == "Remove" then
                return function(inner)
                    rawset(inner, "Removed", true)
                    RUNTIME.removed = (RUNTIME.removed or 0) + 1
                end
            end
            return nil
        end,
        __newindex = function(self, key, value)
            local expected = props[key]
            if not expected then
                error(string.format("invalid property %q on Drawing.%s", tostring(key), kind), 2)
            end
            if not value_matches(value, expected) then
                error(string.format("bad value for Drawing.%s.%s (%s)", kind, key, expected), 2)
            end
            rawset(self, key, value)
        end,
    })

    table.insert(RUNTIME.drawings, object)
    return object
end


-- // players ---------------------------------------------------------------
local BrickColorMT = {
    __eq = function(a, b)
        return a.Color.R == b.Color.R and a.Color.G == b.Color.G and a.Color.B == b.Color.B
    end,
}

local function brick_color(name, color)
    return setmetatable({ Name = name, Color = color }, BrickColorMT)
end

local function new_player(name, team_color)
    local player = Instance.new("Player")
    player.Name = name
    player.Neutral = false
    player.TeamColor = brick_color("Team " .. name, team_color)
    player.Team = { Name = "Team " .. name, TeamColor = player.TeamColor }
    player.Character = nil
    player.CharacterAdded = new_signal("CharacterAdded")
    player.CharacterRemoving = new_signal("CharacterRemoving")
    player.DisplayName = name
    player.UserId = 0
    return player
end

local local_player = new_player("Me", Color3.fromRGB(0, 120, 255))
local ally = new_player("Ally", Color3.fromRGB(0, 120, 255))
local enemy = new_player("Enemy", Color3.fromRGB(255, 40, 40))

local player_characters = {}

local Players = {
    LocalPlayer = local_player,
    PlayerAdded = new_signal("PlayerAdded"),
    PlayerRemoving = new_signal("PlayerRemoving"),
}
function Players:GetPlayers() return { local_player, ally, enemy } end
function Players:GetPlayerFromCharacter(model) return player_characters[model] end
function Players:GetPlayerByUserId() return nil end
function Players:GetPlayerFromUserId() return nil end

local Teams = {
    ChildAdded = new_signal("Teams.ChildAdded"),
    ChildRemoved = new_signal("Teams.ChildRemoved"),
}

function Teams:GetTeams()
    return {
        { Name = "Team Ally" },
        { Name = "Team Enemy" },
    }
end

local SERVICES = {
    Teams = Teams,
    RunService = RunService,
    UserInputService = UserInputService,
    TweenService = TweenService,
    HttpService = HttpService,
    TextService = TextService,
    GuiService = GuiService,
    Players = Players,
    CoreGui = screen_gui_parent,
    Workspace = workspace_object,
    Lighting = Instance.new("Lighting"),
    ReplicatedStorage = Instance.new("ReplicatedStorage"),
    SoundService = Instance.new("SoundService"),
    ContextActionService = { BindAction = function() end, UnbindAction = function() end },
    ContentProvider = { PreloadAsync = function() end },
    StarterGui = Instance.new("StarterGui"),
    VirtualUser = { ClickButton1 = function() end },
}

-- services answer unknown properties with signals, like a real service would
-- for events we did not explicitly model
local function tolerate(service, label)
    return setmetatable(service, {
        __index = function(self, key)
            local signal = new_signal(label .. "." .. tostring(key))
            rawset(self, key, signal)
            return signal
        end,
    })
end

for name, service in pairs(SERVICES) do
    if type(service) == "table" and getmetatable(service) == nil then
        SERVICES[name] = tolerate(service, name)
    end
end

local game_object = {}
function game_object:GetService(name)
    local service = SERVICES[name]
    if not service then
        service = Instance.new(name)
        SERVICES[name] = service
    end
    return service
end
game_object.PlaceId = 1
game_object.JobId = "test"
game_object.HttpGet = function(_, url)
    if RUNTIME.http_get then
        return RUNTIME.http_get(url)
    end
    error("no http_get handler for " .. tostring(url))
end

-- // task / timing ---------------------------------------------------------
RUNTIME.tasks = {}
task = {
    spawn = function(fn)
        table.insert(RUNTIME.tasks, fn)
        return { Status = "Spawned", Cancel = function() end }
    end,
    defer = function(fn)
        table.insert(RUNTIME.tasks, fn)
    end,
    delay = function(_, fn)
        table.insert(RUNTIME.tasks, fn)
    end,
    wait = function() end,
    cancel = function() end,
}
wait = function() end
spawn = task.spawn

-- // exploit surface -------------------------------------------------------
local FILES = {}
function isfile(path) return FILES[path] ~= nil end
function isfolder(path) return true end
function makefolder() end
function writefile(path, data) FILES[path] = data end
function readfile(path) return FILES[path] or "" end
function listfiles() return {} end
function delfile(path) FILES[path] = nil end
function gethui() return screen_gui_parent end
function getgenv() return getfenv() end
function newproxy(addMetatable)
    if addMetatable == true then
        return setmetatable({}, {})
    end
    return setmetatable({}, addMetatable or {})
end

local TYPEOF = {
    Vector2 = "Vector2", Vector3 = "Vector3", Color3 = "Color3",
    UDim = "UDim", UDim2 = "UDim2", Font = "Font",
}
function typeof(value)
    if type(value) == "table" then
        local name = rawget(value, "__typename")
        if name then
            return name
        end
        return "table"
    end
    return type(value)
end

local ENV = getfenv()
ENV.game = game_object
ENV.workspace = workspace_object
ENV.Enum = Enum
ENV.Instance = Instance
ENV.Vector2 = Vector2
ENV.Vector3 = Vector3
ENV.Color3 = Color3
ENV.UDim = UDim
ENV.UDim2 = UDim2
ENV.TweenInfo = TweenInfo
ENV.Rect = Rect
ENV.Drawing = Drawing
ENV.warn = print
ENV.CFrame = CFrame
ENV.NumberSequence = NumberSequence
ENV.NumberSequenceKeypoint = NumberSequenceKeypoint
ENV.ColorSequence = ColorSequence
ENV.ColorSequenceKeypoint = ColorSequenceKeypoint
ENV.NumberRange = NumberRange
ENV.Font = Font
ENV.task = task
ENV.wait = wait
ENV.spawn = spawn
ENV.typeof = typeof
ENV.isfile = isfile
ENV.isfolder = isfolder
ENV.makefolder = makefolder
ENV.writefile = writefile
ENV.readfile = readfile
ENV.listfiles = listfiles
ENV.delfile = delfile
ENV.gethui = gethui
ENV.getgenv = getgenv
ENV.newproxy = newproxy

-- // scene helpers ---------------------------------------------------------
local function new_part(name, position, size)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size or Vector3.new(1, 2, 1)
    part.CFrame = CFrame.new(position)
    part.Position = part.CFrame.Position
    part.Transparency = 0
    part.LocalTransparencyModifier = 0
    part.CanCollide = true
    return part
end

local function new_character(name, position)
    local model = Instance.new("Model")
    model.Name = name

    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "Humanoid"
    humanoid.Health = 100
    humanoid.MaxHealth = 100
    humanoid.Parent = model

    local function add(part)
        part.Parent = model
        return part
    end

    add(new_part("HumanoidRootPart", position, Vector3.new(2, 2, 1)))
    add(new_part("Head", position + Vector3.new(0, 3, 0), Vector3.new(2, 1, 1)))
    add(new_part("Torso", position + Vector3.new(0, 1, 0), Vector3.new(2, 2, 1)))
    add(new_part("UpperTorso", position + Vector3.new(0, 1, 0), Vector3.new(2, 2, 1)))
    add(new_part("LowerTorso", position, Vector3.new(2, 2, 1)))
    add(new_part("Neck", position + Vector3.new(0, 2, 0), Vector3.new(1, 1, 1)))
    add(new_part("LeftUpperArm", position + Vector3.new(-1, 1, 0)))
    add(new_part("LeftLowerArm", position + Vector3.new(-1, 0, 0)))
    add(new_part("LeftHand", position + Vector3.new(-1, -1, 0)))
    add(new_part("RightUpperArm", position + Vector3.new(1, 1, 0)))
    add(new_part("RightLowerArm", position + Vector3.new(1, 0, 0)))
    add(new_part("RightHand", position + Vector3.new(1, -1, 0)))
    add(new_part("LeftUpperLeg", position + Vector3.new(-0.5, -1, 0)))
    add(new_part("LeftLowerLeg", position + Vector3.new(-0.5, -2, 0)))
    add(new_part("LeftFoot", position + Vector3.new(-0.5, -3, 0)))
    add(new_part("RightUpperLeg", position + Vector3.new(0.5, -1, 0)))
    add(new_part("RightLowerLeg", position + Vector3.new(0.5, -2, 0)))
    add(new_part("RightFoot", position + Vector3.new(0.5, -3, 0)))

    return model
end

RUNTIME.entities = {
    new_part = new_part,
    new_character = new_character,
    local_player = local_player,
    ally = ally,
    enemy = enemy,
    player_characters = player_characters,
    camera = camera,
    workspace = workspace_object,
    core_gui = screen_gui_parent,
    new_player = new_player,
    new_signal = new_signal,
    Vector2 = Vector2,
    Vector3 = Vector3,
    Color3 = Color3,
    CFrame = CFrame,
}

return RUNTIME
