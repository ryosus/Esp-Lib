-- Behavioral tests for esp_lib.lua. Runs after the library has been loaded
-- through the mock environment (see tests/build_and_run.py).

local ESP = ESP
local M = MOCK_ENTITIES
local players_service = game:GetService("Players")

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

local function step(count)
    assert(MOCK.render, "no render connection")
    for _ = 1, count or 1 do
        MOCK.render()
    end
end

local function first_part(model, name)
    return model:FindFirstChild(name)
end

-- fresh characters ---------------------------------------------------------
local enemy_character = M.character("EnemyChar", M.Vector3.new(10, 20, -100))
local ally_character = M.character("AllyChar", M.Vector3.new(-20, 20, -100))
local behind_character = M.character("BehindChar", M.Vector3.new(0, 20, 150))

M.player_characters[enemy_character] = M.enemy
M.player_characters[ally_character] = M.ally
M.player_characters[behind_character] = M.enemy

M.workspace:AddChild(enemy_character)
M.workspace:AddChild(ally_character)
M.workspace:AddChild(behind_character)

-- 1. shape of the loaded library -------------------------------------------
check(type(ESP) == "table", "esplib returns a table")
check(getgenv().esplib == ESP, "getgenv().esplib is the returned table")
check(type(ESP.add_box) == "function", "add_box exists")
check(type(ESP.add_healthbar) == "function", "add_healthbar exists")
check(type(ESP.add_dynamic_text) == "function", "add_dynamic_text exists")
check(type(ESP.add_name) == "function", "add_name exists")
check(type(ESP.add_distance) == "function", "add_distance exists")
check(type(ESP.add_tracer) == "function", "add_tracer exists")
check(type(ESP.add_skeleton) == "function", "add_skeleton exists")
check(type(ESP.add_head_dot) == "function", "add_head_dot exists")
check(type(ESP.remove_esp) == "function", "remove_esp exists")
check(type(ESP.unload) == "function", "unload exists")
check(type(ESP.set_color) == "function", "set_color exists")
check(type(ESP.set_text) == "function", "set_text exists")
check(type(ESP.reset) == "function", "reset exists")
check(ESP.box.type == "normal", "default box type")
check(ESP.tracer.from == "mouse", "default tracer origin")
check(ESP.enabled == true, "enabled by default")
check(ESP.api == 2, "api marker exposed for the interface")
check(getmetatable(ESP.box.fill) ~= nil, "config keeps a real Color3 after load")
check(getmetatable(ESP.team.friendly) ~= nil, "nested config keeps a real Color3 after load")
check(getmetatable(ESP.tracer.origin) ~= nil, "config keeps a real Vector2 after load")
check(getmetatable(ESP.defaults.box.fill) ~= nil, "defaults snapshot keeps a real Color3")

-- 2. every module renders ---------------------------------------------------
ESP.add_box(enemy_character)
ESP.add_healthbar(enemy_character)
ESP.add_name(enemy_character, "Enemy")
ESP.add_distance(enemy_character)
ESP.add_tracer(enemy_character)
ESP.add_skeleton(enemy_character)
ESP.add_head_dot(enemy_character)

local instances = getgenv().espinstances
local data = instances[enemy_character]
check(data ~= nil, "record created")
check(#data.skeleton.lines == 21, "skeleton covers R15 and R6 bones")
check(#data.drawings == 18 + 3 + 1 + 1 + 2 + 21 + 1, "drawing count matches modules")

step(1)

check(data.box.outline.Visible == true, "box visible")
check(data.box.outline.Size.X > 0 and data.box.outline.Size.Y > 0, "box has a size")
check(data.healthbar.outline.Visible == true, "healthbar outline visible")
check(data.healthbar.fill.Visible == true, "healthbar fill visible")
check(data.texts.name.Visible == true, "name text visible")
check(data.texts.name.Text == "Enemy", "name text content")
check(data.distance.Visible == true, "distance text visible")
check(type(data.distance.Text) == "string" and data.distance.Text:match("%d+m$") ~= nil, "distance text format")
check(data.tracer.fill.Visible == true, "tracer visible")
check(data.tracer.fill.From.X == 640 and data.tracer.fill.From.Y == 300, "tracer starts at the mouse by default")
check(data.head_dot.Visible == false, "head dot hidden by default")

ESP.head_dot.enabled = true
step(1)
check(data.head_dot.Visible == true, "head dot visible when enabled")
check(data.head_dot.Radius > 0, "head dot has a radius")
check(data.head_dot.Color ~= nil, "head dot has a colour")

ESP.head_dot.filled = false
ESP.head_dot.size = 2
step(1)
check(data.head_dot.Filled == false, "head dot honours the filled option")
ESP.head_dot.filled = true
ESP.head_dot.size = 1
ESP.head_dot.enabled = false
step(1)
check(data.head_dot.Visible == false, "head dot hides when disabled")

local visible_bones = 0
for _, line in ipairs(data.skeleton.lines) do
    if line.Visible then
        visible_bones = visible_bones + 1
    end
end
check(visible_bones > 0, "skeleton draws bones")
check(data.skeleton.head_circle == nil, "skeleton has no head circle")

check(data.healthbar.text.Visible == false, "health text hidden by default")

-- 3. master switch ----------------------------------------------------------
ESP.enabled = false
step(1)
check(data.box.outline.Visible == false, "master switch hides box")
check(data.distance.Visible == false, "master switch hides distance")
local hidden_bones = true
for _, line in ipairs(data.skeleton.lines) do
    if line.Visible then
        hidden_bones = false
    end
end
check(hidden_bones, "master switch hides skeleton bones")
ESP.enabled = true
step(1)
check(data.box.outline.Visible == true, "master switch restores box")

-- 4. corner box -------------------------------------------------------------
ESP.box.type = "corner"
step(1)
check(data.box.outline.Visible == false, "corner mode hides square")
local corner_visible = 0
for _, line in ipairs(data.box.corner_fill) do
    if line.Visible then
        corner_visible = corner_visible + 1
    end
end
check(corner_visible == 8, "corner mode shows all eight corners")
ESP.box.type = "normal"
step(1)
check(data.box.outline.Visible == true, "normal mode restores square")
check(data.box.corner_fill[1].Visible == false, "normal mode hides corner lines")

-- 5. minimum health ---------------------------------------------------------
local humanoid = enemy_character:FindFirstChildOfClass("Humanoid")
ESP.minimum_health.value = 50
humanoid.Health = 10
step(1)
check(data.box.outline.Visible == false, "low health hides esp")
check(instances[enemy_character] ~= nil, "low health keeps the record for revival")
humanoid.Health = 100
step(1)
check(data.box.outline.Visible == true, "healing restores esp")

-- 6. team check -------------------------------------------------------------
ESP.add_box(ally_character)
local ally_data = instances[ally_character]
step(1)
check(ally_data.box.outline.Visible == true, "ally visible with team check off")

ESP.team.check = true
step(1)
check(ally_data.box.outline.Visible == false, "team check hides allies")
check(data.box.outline.Visible == true, "team check keeps enemies")

-- neutral players count as teammates (roblox team semantics, same as Unnamed ESP)
M.enemy.Neutral = true
M.local_player.Neutral = true
step(1)
check(data.box.outline.Visible == false, "neutral players count as teammates")
M.enemy.Neutral = false
M.local_player.Neutral = false
step(1)
ESP.team.check = false

-- 7. team colors ------------------------------------------------------------
ESP.team.colors = true
ESP.team.use_team_color = false
step(1)
check(near(data.box.fill.Color.R, 1) and near(data.box.fill.Color.G, 0), "enemy accent is red")
check(near(ally_data.box.fill.Color.G, 1) and near(ally_data.box.fill.Color.R, 0), "friendly accent is green")

ESP.team.use_team_color = true
step(1)
check(near(ally_data.box.fill.Color.R, 0) and near(ally_data.box.fill.Color.B, 1), "ally uses its team colour")
ESP.team.use_team_color = false

-- 8. rainbow ---------------------------------------------------------------
ESP.rainbow_speed = 0
ESP.rainbow = true
step(1)
check(near(data.box.fill.Color.R, 1) and near(data.box.fill.Color.G, 0) and near(data.box.fill.Color.B, 0),
    "rainbow overrides team colours")
ESP.rainbow = false

-- per-instance colour wins over team colours
ESP.set_color(enemy_character, M.Color3.new(0, 0, 1))
step(1)
check(near(data.box.fill.Color.B, 1) and near(data.box.fill.Color.R, 0), "set_color overrides team colour")
ESP.set_color(enemy_character, nil)
step(1)
check(near(data.box.fill.Color.R, 1), "clearing set_color restores team colour")
ESP.team.colors = false
step(1)
check(near(data.box.fill.Color.R, 1) and near(data.box.fill.Color.G, 1), "default box colour restored")

-- 9. distance filter --------------------------------------------------------
ESP.filters.max_distance = 50
step(1)
check(data.box.outline.Visible == false, "max distance hides far targets")
ESP.filters.max_distance = 0
step(1)
check(data.box.outline.Visible == true, "unlimited distance shows far targets")

-- 10. visibility check ------------------------------------------------------
ESP.filters.visibility_check = true
local wall = M.part("Wall", M.Vector3.new(0, 0, -50), M.Vector3.new(20, 20, 1))
M.workspace:AddChild(wall)
MOCK.raycast_hit = wall
step(1)
check(data.box.outline.Visible == false, "visibility check hides occluded targets")
check(data.texts.name.Visible == false, "visibility check hides names of occluded targets")
check(data.distance.Visible == false, "visibility check hides distances of occluded targets")
check(data.healthbar.outline.Visible == false, "visibility check hides health bars of occluded targets")
check(data.tracer.fill.Visible == true, "visibility check keeps the tracer to an occluded target")

-- a tracer must also survive for occluded targets that are off screen
ESP.add_tracer(behind_character)
ESP.add_box(behind_character)
step(1)
check(instances[behind_character].tracer.fill.Visible == true, "off-screen occluded targets keep their tracer")
check(instances[behind_character].box.outline.Visible == false, "off-screen occluded targets have no box")

wall.Transparency = 0.9
step(1)
check(data.box.outline.Visible == true, "transparent obstructions do not block")

wall.Transparency = 0
wall.LocalTransparencyModifier = 1
step(1)
check(data.box.outline.Visible == true, "locally hidden parts do not block")

wall.LocalTransparencyModifier = 0
MOCK.raycast_hit = nil
step(1)
check(data.box.outline.Visible == true, "clear line of sight shows targets")
check(data.texts.name.Visible == true, "clear line of sight restores names")
ESP.filters.visibility_check = false

-- 11. tracer origins --------------------------------------------------------
local viewport = M.camera.ViewportSize
local head = first_part(enemy_character, "Head")
local head_screen = M.camera:WorldToViewportPoint(head.Position)

ESP.tracer.from = "mouse"
step(1)
check(data.tracer.fill.From.X == 640 and data.tracer.fill.From.Y == 300, "mouse tracer origin")

ESP.tracer.from = "head"
step(1)
check(near(data.tracer.fill.From.X, head_screen.X) and near(data.tracer.fill.From.Y, head_screen.Y), "head tracer origin")

ESP.tracer.from = "top"
step(1)
check(data.tracer.fill.From.X == viewport.X / 2 and data.tracer.fill.From.Y == 0, "top tracer origin")

ESP.tracer.from = "bottom"
step(1)
check(data.tracer.fill.From.X == viewport.X / 2 and data.tracer.fill.From.Y == viewport.Y, "bottom tracer origin")

ESP.tracer.from = "center"
step(1)
check(data.tracer.fill.From.X == viewport.X / 2 and data.tracer.fill.From.Y == viewport.Y / 2, "center tracer origin")

ESP.tracer.from = "custom"
ESP.tracer.origin = M.Vector2.new(100, 200)
step(1)
check(data.tracer.fill.From.X == 100 and data.tracer.fill.From.Y == 200, "custom tracer origin")

ESP.tracer.origin = M.Vector2.new(0, 0)
step(1)
check(data.tracer.fill.From.Y == viewport.Y - ESP.tracer.from_offset, "custom tracer falls back to a screen point")

-- off-screen target still gets a tracer to the viewport edge
ESP.add_tracer(behind_character)
ESP.add_box(behind_character)
ESP.tracer.from = "bottom"
step(1)
local behind_data = instances[behind_character]
local target_point = behind_data.tracer.fill.To
check(target_point.X >= 0 and target_point.X <= viewport.X, "clamped tracer x inside viewport")
check(target_point.Y >= 0 and target_point.Y <= viewport.Y, "clamped tracer y inside viewport")
check(behind_data.box.outline.Visible == false, "offscreen box hidden")
ESP.remove_esp(behind_character)
ESP.tracer.from = "mouse"

-- 12. health text -----------------------------------------------------------
ESP.healthbar.text.enabled = true
humanoid.Health = 55
humanoid.MaxHealth = 100

ESP.healthbar.text.format = "both"
step(1)
check(data.healthbar.text.Visible == true, "health text visible")
check(data.healthbar.text.Text == "55/100 [55%]", "health text both format")

ESP.healthbar.text.format = "numbers"
step(1)
check(data.healthbar.text.Text == "55/100", "health text numbers format")

ESP.healthbar.text.format = "percent"
step(1)
check(data.healthbar.text.Text == "55%", "health text percent format")

-- rounding of fractional health
humanoid.Health = 54.6
ESP.healthbar.text.format = "percent"
step(1)
check(data.healthbar.text.Text == "55%", "health percent rounds")

ESP.healthbar.text.enabled = false
step(1)
check(data.healthbar.text.Visible == false, "health text toggle off")

-- 13. text stacking ---------------------------------------------------------
ESP.add_dynamic_text(enemy_character, "tag", "tag")
step(1)
local name_y = data.texts.name.Position.Y
local tag_y = data.texts.tag.Position.Y
check(near(tag_y, name_y - (ESP.dynamic_text.size + ESP.dynamic_text.line_spacing)), "dynamic texts stack upward")

ESP.dynamic_text.y_offset = 20
step(1)
check(near(data.texts.name.Position.Y, data.box.outline.Position.Y - 20), "y offset moves text above box")
ESP.dynamic_text.y_offset = 0

-- 14. set_text / add_name ---------------------------------------------------
ESP.set_text(enemy_character, "name", "Renamed")
check(data.texts.name.Text == "Renamed", "set_text updates the text")
ESP.add_name(enemy_character, "Again")
check(data.texts.name.Text == "Again", "add_name falls back to the existing name drawing")

-- 15. live option application ----------------------------------------------
ESP.dynamic_text.size = 20
ESP.dynamic_text.fill = M.Color3.new(0, 1, 0)
ESP.dynamic_text.outline = false
ESP.distance.size = 9
ESP.distance.fill = M.Color3.new(1, 0, 1)
step(1)
check(data.texts.name.Size == 20, "text size is live")
check(near(data.texts.name.Color.G, 1), "text colour is live")
check(data.texts.name.Outline == false, "text outline is live")
check(data.distance.Size == 9, "distance size is live")
check(near(data.distance.Color.B, 1), "distance colour is live")

ESP.box.padding = 2
step(1)
check(data.box.outline.Size.X > 0, "padding change keeps a valid box")
ESP.box.padding = 1.15

-- 16. part / tool targets ---------------------------------------------------
local loose_part = M.part("Loot", M.Vector3.new(5, 5, -80), M.Vector3.new(2, 2, 2))
M.workspace:AddChild(loose_part)
ESP.add_box(loose_part)
ESP.add_name(loose_part, "Loot")
step(1)
local part_data = instances[loose_part]
check(part_data ~= nil and part_data.box.outline.Visible == true, "BasePart target renders")
check(part_data.texts.name.Visible == true, "BasePart target renders text")

local tool = M.new_instance("Tool", { Name = "Flashlight" })
tool:AddChild(M.part("Handle", M.Vector3.new(-5, 5, -80), M.Vector3.new(1, 1, 1)))
M.workspace:AddChild(tool)
ESP.add_box(tool)
step(1)
check(instances[tool] ~= nil and instances[tool].box.outline.Visible == true, "Tool target uses its Handle")

local accessory = M.new_instance("Accessory", { Name = "Hat" })
accessory:AddChild(M.part("Handle", M.Vector3.new(-5, 8, -80), M.Vector3.new(1, 1, 1)))
M.workspace:AddChild(accessory)
ESP.add_box(accessory)
step(1)
check(instances[accessory] ~= nil and instances[accessory].box.outline.Visible == true, "Accessory target uses its Handle")

local empty_tool = M.new_instance("Tool", { Name = "EmptyTool" })
M.workspace:AddChild(empty_tool)
ESP.add_box(empty_tool)
step(1)
check(instances[empty_tool].box.outline.Visible == false, "targets without parts stay hidden")

-- 17. prune destroyed instances --------------------------------------------
local doomed = M.character("Doomed", M.Vector3.new(0, 0, -60))
M.workspace:AddChild(doomed)
ESP.add_box(doomed)
step(1)
check(instances[doomed] ~= nil, "doomed instance registered")
doomed.Parent = nil
step(1)
check(instances[doomed] == nil, "destroyed instances are pruned")

-- 18. remove_esp -----------------------------------------------------------
local removed_before = MOCK.removed or 0
local drawing_count = #data.drawings
ESP.remove_esp(enemy_character)
check(instances[enemy_character] == nil, "remove_esp clears the record")
check((MOCK.removed or 0) - removed_before == drawing_count, "remove_esp removes every drawing")

-- 18b. master switch hides new records and still prunes -------------------
local hidden_target = M.character("Hidden", M.Vector3.new(0, 0, -70))
M.workspace:AddChild(hidden_target)
ESP.add_box(hidden_target)
ESP.enabled = false
step(1)
check(instances[hidden_target].box.outline.Visible == false, "box hidden while the master switch is off")
hidden_target.Parent = nil
step(1)
check(instances[hidden_target] == nil, "records pruned while the master switch is off")
ESP.enabled = true
step(1)

-- 19. crosshair ------------------------------------------------------------
ESP.crosshair.enabled = true
step(1)
local crosshair_drawings = 0
local limit = 20
for _, drawing in ipairs(MOCK.drawings) do
    if drawing.Type == "Line" and not drawing.Removed and drawing.Visible
        and drawing.From and drawing.To
        and math.abs(drawing.From.X - viewport.X / 2) <= limit
        and math.abs(drawing.From.Y - viewport.Y / 2) <= limit
        and math.abs(drawing.To.X - viewport.X / 2) <= limit
        and math.abs(drawing.To.Y - viewport.Y / 2) <= limit then
        crosshair_drawings = crosshair_drawings + 1
    end
end
check(crosshair_drawings == 8, "crosshair draws four filled and four outline segments")

ESP.crosshair.enabled = false
step(1)

-- 20. unload ---------------------------------------------------------------
ESP.add_box(loose_part)
ESP.add_tracer(loose_part)
local render = MOCK.render
ESP.unload()
check(next(getgenv().espinstances) == nil, "unload clears every record")
check(MOCK.render == nil, "unload disconnects the render step")
check(render ~= nil, "render step existed before unload")

-- 21. reloading the library reuses the config table ------------------------
local previous = getgenv().esplib
previous.box.type = "corner"
local source = assert(LIB_SOURCE)
local reloaded = assert(loadstring(source))()
check(reloaded == previous, "reload keeps the same config table")
check(reloaded.box.type == "corner", "reload preserves user options")
check(MOCK.render ~= nil, "reload reconnects the render step")

-- 22. legacy config (only the original keys) loads cleanly ----------------
if ESP and ESP.unload then
    ESP.unload()
end
getgenv().espinstances = {}
getgenv().esplib = {
    box = {
        enabled = false,
        type = "normal",
        padding = 1.15,
        fill = M.Color3.new(1, 1, 1),
        outline = M.Color3.new(0, 0, 0),
    },
    healthbar = {
        enabled = true,
        fill = M.Color3.new(0, 1, 0),
        outline = M.Color3.new(0, 0, 0),
    },
    dynamic_text = {
        enabled = true,
        fill = M.Color3.new(1, 1, 1),
        size = 13,
        y_offset = -15,
    },
    distance = {
        enabled = true,
        fill = M.Color3.new(1, 1, 1),
        size = 13,
    },
    tracer = {
        enabled = true,
        fill = M.Color3.new(1, 1, 1),
        outline = M.Color3.new(0, 0, 0),
        from = "bottom",
    },
    skeleton = {
        enabled = true,
        color = M.Color3.new(1, 0, 1),
        thickness = 2,
        head = M.Color3.new(1, 0, 0),
    },
    minimum_health = {
        enabled = true,
        value = 0,
    },
}

local legacy_ok, legacy_error = pcall(function()
    local legacy = assert(loadstring(source))()
    ESP = legacy
    local target = M.character("Legacy", M.Vector3.new(0, 10, -70))
    M.workspace:AddChild(target)
    legacy.add_healthbar(target)
    legacy.add_dynamic_text(target, "name", "Legacy")
    legacy.add_distance(target)
    legacy.add_tracer(target)
    legacy.add_skeleton(target)
    step(3)
    local legacy_data = getgenv().espinstances[target]
    assert(legacy_data.box == nil, "box was not added (disabled in config)")
    assert(legacy_data.healthbar.outline.Visible == true, "legacy healthbar renders")
    assert(legacy_data.tracer.fill.From.X == viewport.X / 2, "legacy 'bottom' tracer origin")
    assert(legacy.defaults.box.type == "normal", "defaults snapshot present")
end)

check(legacy_ok, "legacy configuration works: " .. tostring(legacy_error))

-- 23. reset restores defaults ---------------------------------------------
if legacy_ok then
    ESP = ESP
    ESP.box.type = "corner"
    ESP.dynamic_text.size = 22
    ESP.reset()
    check(ESP.box.type == "normal", "reset restores box type")
    check(ESP.dynamic_text.size == 13, "reset restores text size")
    check(getmetatable(ESP.box.fill) ~= nil, "reset keeps a real Color3")
    check(getmetatable(ESP.tracer.origin) ~= nil, "reset keeps a real Vector2")
end

-- 24. frame cost sanity ----------------------------------------------------
local performance_target = M.character("Perf", M.Vector3.new(3, 10, -90))
M.workspace:AddChild(performance_target)
ESP.add_box(performance_target)
ESP.add_healthbar(performance_target)
ESP.add_name(performance_target, "Perf")
ESP.add_distance(performance_target)
ESP.add_tracer(performance_target)
ESP.add_skeleton(performance_target)
ESP.add_head_dot(performance_target)

local started = os.clock()
local ok, err = pcall(function()
    step(120)
end)
local elapsed = os.clock() - started
check(ok, "120 frames render without errors: " .. tostring(err))
print(string.format("[perf] 120 frames in %.3fs", elapsed))

-- summary ------------------------------------------------------------------
print(string.format("\n%d checks, %d failures", checks, failures))
if failures > 0 then
    error(string.format("%d assertion(s) failed", failures))
end
print("esp_lib.lua: all behavioral checks passed")
