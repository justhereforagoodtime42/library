--[[
	Example script — structure & comments modeled on Obsidian/Linoria Example.lua
	(https://github.com/mstudio45/LinoriaLib, modified Obsidian fork).
	API here is AcidHub: Library.new, Idx + Options/Toggles, AddLeftGroupbox({...}), etc.
	Suggest changes via PR.
]]

-- Remote load (same idea as Obsidian `repo .. "Library.lua"`).
local repo = "https://raw.githubusercontent.com/justhereforagoodtime42/library/refs/heads/main/"
local Library = loadstring(game:HttpGet(repo .. "main.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "thememanager"))()
local SaveManager = loadstring(game:HttpGet(repo .. "savemanager"))()

--[[
	Local dev (uncomment if your executor supports loadfile + workspace paths):

local Library = loadfile("ui/library.lua")()
local ThemeManager = loadfile("ui/addons/ThemeManager.lua")()
local SaveManager = loadfile("ui/addons/SaveManager.lua")()
]]

local Options = Library.Options
local Toggles = Library.Toggles

;(getgenv or function()
	return shared
end)().AcidHubLibrary = Library

--[[
	Window: AcidHub uses Library.new({ ... }) instead of :CreateWindow.
	- Subtitle ≈ Obsidian Footer
	- TitleIcon ≈ Obsidian Icon (number rbxasset id or Lucide name string)
	- NotifySide: "Left" | "Right"
	- SplitColumns: true → AddLeftGroupbox / AddRightGroupbox per tab
	- Mobile: Library.IsMobile + floating Menu/Lock; optional MobileButtonsSide = "Left"|"Right", UnlockMouseWhileOpen
]]
local Window = Library.new({
	Title = "AcidHub",
	Subtitle = "Game Name | Version: 1.0 | discord.gg/acidhub",
	TitleIcon = 114741603622587,
	Size = Vector2.new(720, 600),
	NotifySide = "Right",
	MultiDropdownByDefault = false,
	-- MobileButtonsSide = "Right",
	-- UnlockMouseWhileOpen = true,
})

--[[
	CALLBACK NOTE:
	You can pass Callback = function(...) end on each element.
	Recommended: give widgets Idx = "MyId", then Options.MyId / Toggles.MyId :OnChanged(...)
	after you build the UI, so logic stays separate from layout.
]]

-- Icons: Lucide names — https://lucide.dev/ — or rbxassetid number like TitleIcon.
local Tabs = {
	Main = Window:AddTab({ Name = "Main", Icon = "layout-grid", SplitColumns = true }),
	["UI Settings"] = Window:AddTab({ Name = "UI Settings", Icon = "settings", SplitColumns = true }),
}

-- Groupbox / Tabbox: same widget methods; tabbox uses AddTab then AddLeftGroupbox on the proxy tab.
local LeftGroupBox = Tabs.Main:AddLeftGroupbox("Groupbox", { Icon = "boxes", Tooltip = "Collapsible section" })

-- Groupbox:AddToggle — use Idx to register Toggles[Idx] and Library.Options[Idx] for toggles? Actually toggles go to Library.Toggles[Idx]
LeftGroupBox:AddToggle({
	Text = "This is a toggle",
	Tooltip = "Hover text",
	Default = true,
	Idx = "MyToggle",
	Callback = function(Value: boolean)
		print("[cb] MyToggle:", Value)
	end,
})

Toggles.MyToggle:OnChanged(function()
	print("MyToggle →", Toggles.MyToggle.Value)
end)
Toggles.MyToggle:SetValue(false)

LeftGroupBox:AddColorPicker({
	Text = "Pick accent",
	Default = Color3.fromRGB(255, 80, 80),
	Idx = "ColorPicker1",
	Callback = function(Value: Color3)
		print("[cb] ColorPicker1:", Value)
	end,
})

LeftGroupBox:AddColorPicker({
	Text = "Second picker",
	Default = Color3.fromRGB(80, 255, 80),
	Idx = "ColorPicker2",
	Callback = function(Value: Color3)
		print("[cb] ColorPicker2:", Value)
	end,
})

LeftGroupBox:AddDivider()

--[[
	Groupbox:AddButton — table form must use Func = function() ... end
	(string + callback) overload: AddButton("Text", function() end)
]]
LeftGroupBox:AddButton({
	Text = "Table button",
	Tooltip = "Primary action",
	Func = function()
		print("Table button clicked")
	end,
})
LeftGroupBox:AddButton("String button", function()
	print("String button clicked")
end)

LeftGroupBox:AddLabel("Plain label")
LeftGroupBox:AddLabel("Wrapped label with more text so it wraps in the column.", true)

LeftGroupBox:AddSlider({
	Text = "Slider",
	Min = 0,
	Max = 10,
	Default = 3,
	Rounding = 1,
	Idx = "MySlider",
	Tooltip = "Drag or type the value box",
	Callback = function(Value: number)
		print("[cb] Slider:", Value)
	end,
})

Options.MySlider:OnChanged(function()
	print("Slider →", Options.MySlider.Value)
end)
Options.MySlider.Set(nil, 5)

LeftGroupBox:AddInput({
	Text = "Text input",
	Default = "hello",
	Placeholder = "Placeholder",
	Idx = "MyInput",
	Callback = function(Value: string)
		print("[cb] Input:", Value)
	end,
})

-- Notifications (AcidHub): Time, Steps + ChangeStep, Persist, optional SoundId
local persistToast: any = nil
LeftGroupBox:AddButton({
	Text = "Notify (timed)",
	Func = function()
		Library:Notify({ Title = "Timed", Description = "Progress + countdown.", Time = 5 })
	end,
})
LeftGroupBox:AddButton({
	Text = "Notify (persist)",
	Func = function()
		if persistToast and not persistToast.Destroyed then
			persistToast:Destroy()
		end
		persistToast = Library:Notify({
			Title = "Persist",
			Description = "No timer; click again to replace.",
			Persist = true,
		})
	end,
})

-- Right column: dropdowns (Options = values; Searchable; MaxVisibleItems caps open list height)
local DropdownGroupBox = Tabs.Main:AddRightGroupbox("Dropdowns", { Icon = "list" })

DropdownGroupBox:AddDropdown({
	Text = "Basic dropdown",
	Options = { "This", "is", "a", "dropdown" },
	Multi = false,
	Default = "This",
	Idx = "MyDropdown",
	Callback = function(Value: string)
		print("[cb] Dropdown:", Value)
	end,
})

DropdownGroupBox:AddDropdown({
	Text = "Searchable",
	Searchable = true,
	Options = { "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot" },
	Default = "Alpha",
	Idx = "MySearchDropdown",
	Callback = function(Value: string)
		print("[cb] Search dropdown:", Value)
	end,
})

DropdownGroupBox:AddDropdown({
	Text = "Multi",
	Options = { "One", "Two", "Three" },
	Multi = true,
	Default = { "One" },
	Idx = "MyMultiDropdown",
	Callback = function(Value: any)
		print("[cb] Multi:", Value)
	end,
})

DropdownGroupBox:AddDropdown({
	Text = "Long list (scrolls)",
	Options = {
		"Row 1",
		"Row 2",
		"Row 3",
		"Row 4",
		"Row 5",
		"Row 6",
		"Row 7",
		"Row 8",
		"Row 9",
		"Row 10",
		"Row 11",
		"Row 12",
	},
	Multi = false,
	Default = "Row 1",
	Idx = "MyLongDropdown",
	MaxVisibleItems = 5,
	Callback = function(Value: string)
		print("[cb] Long:", Value)
	end,
})

--[[
	Tabbox: AddRightTabbox (or AddLeftTabbox) → AddTab("Name") returns a proxy tab;
	call AddLeftGroupbox / AddSection on it like a normal tab.
]]
local TabBox = Tabs.Main:AddRightTabbox("Tabbox")
local Tab1 = TabBox:AddTab("Tab 1")
Tab1:AddLeftGroupbox("Inside Tab 1", { Collapsible = false }):AddToggle({
	Text = "Tab1 toggle",
	Default = false,
	Idx = "Tab1Toggle",
	Callback = function() end,
})
local Tab2 = TabBox:AddTab("Tab 2")
Tab2:AddLeftGroupbox("Inside Tab 2", { Collapsible = false }):AddButton({
	Text = "Tab 2 button",
	Func = function()
		print("From tab 2")
	end,
})

-- ——— UI Settings ———
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", { Icon = "wrench" })
MenuGroup:AddDropdown({
	Text = "Notification side",
	Options = { "Left", "Right" },
	Default = "Right",
	Idx = "NotificationSide",
	Callback = function(Value: string)
		Library:SetNotifySide(Value)
	end,
})
MenuGroup:AddSlider({
	Text = "Corner radius",
	Min = 0,
	Max = 20,
	Rounding = 0,
	Default = Library.CornerRadius,
	Idx = "UICornerSlider",
	Callback = function(value: number)
		Window:SetCornerRadius(value)
	end,
})
MenuGroup:AddDivider()
MenuGroup:AddKeybind({
	Text = "Menu keybind",
	Default = "RightShift",
	Idx = "MenuKeybind",
	NoUI = true,
})
MenuGroup:AddButton("Unload", function()
	Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

Library:OnUnload(function()
	print("AcidHub unloaded")
end)

--[[
	Addons (same role as Obsidian):
	- SaveManager: configs (BuildConfigSection)
	- ThemeManager: themes (ApplyToTab)
]]
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({
	"MenuKeybind",
	"NotificationSide",
	"UICornerSlider",
})
ThemeManager:SetFolder("AcidHub")
SaveManager:SetFolder("AcidHub/example-game")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()
