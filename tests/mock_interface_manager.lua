-- Mock of Fluent's InterfaceManager addon.
local InterfaceManager = {
    Folder = "FluentSettings",
    Settings = { Theme = "Dark", Acrylic = false, Transparency = true, MenuKeybind = "LeftControl" },
}

function InterfaceManager:SetLibrary(library)
    self.Library = library
end

function InterfaceManager:SetFolder(folder)
    self.Folder = folder
    MOCK_UI.interface_folder = folder
end

function InterfaceManager:BuildInterfaceSection(tab)
    MOCK_UI.interface_section = tab:AddSection("Interface")
    return MOCK_UI.interface_section
end

function InterfaceManager:LoadSettings() end
function InterfaceManager:SaveSettings() end

return InterfaceManager
