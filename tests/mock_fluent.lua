-- Mock of dawid-scripts/Fluent's public API. Records every element so the GUI
-- wiring can be asserted headlessly.

local Library = {
    Options = {},
    Themes = { "Dark", "Darker", "Light", "Rose", "Aqua", "Amethyst" },
    Unloaded = false,
    Version = "mock",
}

local UI = {
    elements = {},
    buttons = {},
    sections = {},
    tabs = {},
    notifications = {},
    dialogs = {},
}
MOCK_UI = UI

local function register(element)
    assert(UI.elements[element.Name] == nil, "duplicate element name: " .. tostring(element.Name))
    UI.elements[element.Name] = element
    Library.Options[element.Name] = element
end

local function round_value(value, factor)
    if factor == 0 then
        return math.floor(value)
    end
    local text = tostring(value)
    local point = text:find("%.")
    if point then
        return tonumber(text:sub(1, point + factor))
    end
    return text -- Fluent returns the string here for whole numbers
end

local function new_container(label)
    local container = { label = label }

    local function adder(kind)
        return function(_, name, config)
            config = config or {}
            local element = {
                Name = name,
                Kind = kind,
                Config = config,
                Multi = config.Multi == true,
                Mode = config.Mode,
                Values = config.Values,
                Toggled = false,
                Value = config.Default,
            }

            if kind == "toggle" then
                element.Value = config.Default == true
            elseif kind == "dropdown" then
                element.Value = config.Multi and {} or config.Default
            elseif kind == "input" then
                element.Value = config.Default or ""
            end

            function element:SetValue(value, mode)
                if mode ~= nil then
                    self.Mode = mode
                end

                if self.Kind == "slider" then
                    value = round_value(math.clamp(tonumber(value) or self.Value, config.Min, config.Max), config.Rounding)
                elseif self.Kind == "dropdown" then
                    local values = self.Values or {}
                    if self.Multi then
                        local filtered = {}
                        if type(value) == "table" then
                            for name, selected in pairs(value) do
                                if selected and table.find(values, name) then
                                    filtered[name] = true
                                end
                            end
                        end
                        value = filtered
                    else
                        if value == nil or not table.find(values, value) then
                            return
                        end
                    end
                end

                self.Value = value
                if config.Callback then
                    config.Callback(value)
                end
                if self.Changed then
                    self.Changed(value)
                end
            end

            function element:SetValueRGB(color)
                self.Value = color
                if config.Callback then
                    config.Callback(color)
                end
                if self.Changed then
                    self.Changed(color)
                end
            end

            function element:OnChanged(fn)
                self.Changed = fn
                fn(self.Value)
            end

            function element:GetValue()
                return self.Value
            end

            function element:GetState()
                return self.Value
            end

            function element:OnClick(fn)
                self.Clicked = fn
            end

            function element:SetTitle() end
            function element:SetDesc() end
            function element:Destroy() end

            function element:SetValues(values)
                self.Values = values
                config.Values = values
            end

            function element:Click()
                self.Toggled = not self.Toggled
                if config.Callback then
                    config.Callback(self.Toggled)
                end
            end

            register(element)

            if kind == "toggle" or kind == "slider" or kind == "dropdown" then
                element:SetValue(element.Value)
            elseif kind == "color" then
                element:SetValueRGB(element.Value)
            end

            return element
        end
    end

    container.AddToggle = adder("toggle")
    container.AddSlider = adder("slider")
    container.AddDropdown = adder("dropdown")
    container.AddColorpicker = adder("color")
    container.AddKeybind = adder("keybind")
    container.AddInput = adder("input")

    function container:AddButton(config)
        config = config or {}
        local button = { Name = config.Title, Kind = "button", Config = config }
        function button:Click()
            if config.Callback then
                config.Callback()
            end
        end
        UI.buttons[config.Title] = button
        return button
    end

    function container:AddParagraph(config)
        return { Kind = "paragraph", Config = config }
    end

    function container:AddSpace()
        return {}
    end

    function container:AddSection(title)
        table.insert(UI.sections, title)
        return new_container(title)
    end

    return container
end

function Library:CreateWindow(config)
    local window = { Config = config }

    function window:AddTab(tab_config)
        local tab = new_container(tab_config.Title)
        UI.tabs[tab_config.Title] = tab
        return tab
    end

    function window:SelectTab() end
    function window:Minimize() end

    function window:Dialog(dialog_config)
        table.insert(UI.dialogs, dialog_config)
        UI.last_dialog = dialog_config
        return dialog_config
    end

    function window:Destroy()
        UI.destroyed = true
    end

    Library.Window = window
    return window
end

function Library:Notify(config)
    table.insert(UI.notifications, config)
    return true
end

function Library:SetTheme(theme)
    Library.Theme = theme
end

function Library:GetIcon()
    return nil
end

return Library
