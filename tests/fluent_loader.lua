-- Loads the real Fluent 1.1.0 source tree (src/*.lua at tag 1.1.0) with
-- Rojo-like module semantics, so the interface library can be executed and
-- debugged with real line numbers outside of Roblox.

local FILES = FLUENT_FILES
local FOLDER_HINT = FLUENT_FOLDERS

local root = Instance.new("ModuleScript")
root.Name = "MainModule"

-- map every module path to its source; `*/init` modules own the folder node
local sources = { init = assert(FILES["init"], "missing Fluent root module") }
rawget(root, "__props").Source = sources.init
local prefixes = {}
local seen = {}

for key, source in pairs(FILES) do
    local prefix = key
    if key ~= "init" then
        if key:sub(-5) == "/init" then
            prefix = key:sub(1, -6)
        end
        sources[prefix] = source
        -- register the module and every ancestor folder
        local current = prefix
        while current do
            if not seen[current] then
                seen[current] = true
                prefixes[#prefixes + 1] = current
            end
            current = current:match("^(.*)/[^/]+$")
        end
    end
end
for hint in pairs(FOLDER_HINT) do
    if not seen[hint] then
        seen[hint] = true
        prefixes[#prefixes + 1] = hint
    end
end

local function depth_of(path)
    local _, count = path:gsub("/", "")
    return count
end

table.sort(prefixes, function(a, b)
    return depth_of(a) < depth_of(b)
end)

local nodes = { init = root }

local function parent_prefix_of(prefix)
    return prefix:match("^(.*)/[^/]+$")
end

-- create nodes shallowest first so parents always exist
for _, prefix in ipairs(prefixes) do
    local is_module = sources[prefix] ~= nil
    local node = Instance.new(is_module and "ModuleScript" or "Folder")
    node.Name = prefix:match("([^/]+)$")
    if is_module then
        rawget(node, "__props").Source = sources[prefix]
    end
    nodes[prefix] = node
end

-- wire the hierarchy
for _, prefix in ipairs(prefixes) do
    local parent_prefix = parent_prefix_of(prefix)
    nodes[prefix].Parent = parent_prefix and nodes[parent_prefix] or root
end

local cache = {}

function require(module)
    local cached = cache[module]
    if cached ~= nil then
        return cached
    end

    local source = module.Source
    assert(source, "not a module: " .. tostring(module and module.Name))

    local chunk = assert(loadstring(source))
    local env = setmetatable({ script = module }, { __index = getfenv() })
    setfenv(chunk, env)

    local result = chunk()
    cache[module] = result
    return result
end

FLUENT_LIBRARY = require(root)

return FLUENT_LIBRARY
