-- Mock of Fluent's SaveManager addon.
local SaveManager = {
    Folder = "FluentSettings",
    Ignore = {},
    Options = {},
}

function SaveManager:SetLibrary(library)
    self.Library = library
    self.Options = library.Options
end

function SaveManager:IgnoreThemeSettings() end

function SaveManager:SetIgnoreIndexes(indexes)
    self.IgnoredIndexes = indexes
end

function SaveManager:SetFolder(folder)
    self.Folder = folder
    MOCK_UI.save_folder = folder
end

function SaveManager:RefreshConfigList()
    return {}
end

function SaveManager:BuildConfigSection(tab)
    MOCK_UI.save_section = tab:AddSection("Configuration")
    return MOCK_UI.save_section
end

function SaveManager:LoadAutoloadConfig()
    MOCK_UI.autoload_called = true
end

function SaveManager:Load(name)
    self.loaded = name
    MOCK_UI.loaded_config = name
    return true
end

function SaveManager:Save(name)
    self.saved = name
    MOCK_UI.saved_config = name
    return true
end

return SaveManager
