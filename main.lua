
local function tryLoadLocal(path: string): (() -> ())?
	local lf = (getfenv and getfenv(0) and getfenv(0).loadfile) or loadfile
	if lf then
		local ok, chunk = pcall(lf, path)
		if ok and typeof(chunk) == "function" then
			return chunk
		end
	end
	local rf = readfile
	if rf then
		local ok, src = pcall(rf, path)
		if ok and typeof(src) == "string" and src ~= "" then
			local compile = loadstring or load
			if compile then
				local compiled, cerr = compile(src, "@" .. path)
				if typeof(compiled) == "function" then
					return compiled
				end
				if cerr then
					warn("[AcidHub] compile " .. path .. ": " .. tostring(cerr))
				end
			end
		end
	end
	return nil
end

local LIBRARY_PATH = "ui/library.lua"
local SAVE_PATH = "ui/addons/SaveManager.lua"
local THEME_PATH = "ui/addons/ThemeManager.lua"
local LIBRARY_URL =
	"https://raw.githubusercontent.com/justhereforagoodtime42/library/refs/heads/main/main.lua"
local SAVE_MANAGER_URL =
	"https://raw.githubusercontent.com/justhereforagoodtime42/library/refs/heads/main/savemanager"
local THEME_MANAGER_URL =
	"https://raw.githubusercontent.com/justhereforagoodtime42/library/refs/heads/main/thememanager"

local loadfn = loadstring or load
if not loadfn then
	error("loadstring/load required (executor)")
end

local function loadMod(path: string, urlFallback: string?): any
	local chunk = tryLoadLocal(path)
	if chunk then
		local okRun, result = pcall(chunk)
		if not okRun then
			error(string.format("[AcidHub] running local %s failed: %s", path, tostring(result)))
		end
		return result
	end
	if typeof(urlFallback) == "string" and urlFallback ~= "" then
		local g: any = game
		local hgOk, body = pcall(function()
			return g:HttpGet(urlFallback)
		end)
		if not hgOk then
			error(string.format("[AcidHub] HttpGet %s failed: %s", urlFallback, tostring(body)))
		end
		if typeof(body) ~= "string" or body == "" then
			error(string.format("[AcidHub] HttpGet %s returned empty body (blocked or 404?)", urlFallback))
		end
		local compiled, cerr = loadfn(body, "@" .. urlFallback)
		if typeof(compiled) ~= "function" then
			error(
				string.format(
					"[AcidHub] compile %s failed: %s",
					urlFallback,
					tostring(cerr or "load returned non-function")
				)
			)
		end
		local okRun, result = pcall(compiled)
		if not okRun then
			error(string.format("[AcidHub] running remote %s failed: %s", urlFallback, tostring(result)))
		end
		return result
	end
	error("[AcidHub] Missing file (and no URL): " .. path)
end

local Library = loadMod(LIBRARY_PATH, LIBRARY_URL)
if typeof(Library) ~= "table" or typeof(Library.new) ~= "function" then
	error(
		"[AcidHub] Library module is invalid (no .new). "
			.. "Local path failed and the GitHub URL may be the wrong file, blocked HttpGet, or not raw Lua. "
			.. "Use local files or fix LIBRARY_URL to the raw library script."
	)
end

local SaveManager = loadMod(SAVE_PATH, SAVE_MANAGER_URL)
local ThemeManager = loadMod(THEME_PATH, THEME_MANAGER_URL)

local ge = getgenv or function()
	return shared
end
ge().AcidHubLibrary = Library

--[[
	Callbacks: use Callback on elements, or Idx + Library.Toggles / Library.Options with :OnChanged.
	Tab Icon: Lucide name, rbxassetid URL, or numeric Roblox asset id (number / digit string).
]]

local window = Library.new({
	Title = "AcidHub",
	Subtitle = "GAME NAME HERE | Version: 0.0 | Discord.gg/acidhub",
	TitleIcon = 114741603622587,
	Size = Vector2.new(600, 520),
	MultiDropdownByDefault = false,
})

--[[ Sidebar: Lucide icons; pass a number for rbxassetid://… like Obsidian window icons ]]
local tabMain = window:AddTab({
	Name = "Main",
	Icon = "layout-grid",
	Tooltip = "Main hub",
	SplitColumns = true,
})
local tabVisual = window:AddTab({
	Name = "Visuals",
	Icon = "eye",
	Tooltip = "ESP / visuals",
	SplitColumns = true,
})
local tabPlayer = window:AddTab({
	Name = "Player",
	Icon = "user",
	Tooltip = "Character",
	SplitColumns = true,
})
local tabUi = window:AddTab({
	Name = "UI Settings",
	Icon = "settings",
	Tooltip = "Menu, configs (left), themes (right)",
	SplitColumns = true,
})

local cfg = tabMain:AddLeftGroupbox("General", {
	Tooltip = "Click header to collapse",
	Icon = "zap",
})
local toggleEnable = cfg:AddToggle({
	Text = "Enable",
	Default = false,
	Idx = "Main_Enable",
	Callback = function(on: boolean)
		print("[cb] Enable:", on)
	end,
})

cfg:AddSlider({
	Text = "Speed",
	Min = 16,
	Max = 100,
	Default = 50,
	Idx = "Main_Speed",
	Tooltip = "Drag or type in the value box",
	Callback = function(v: number)
		print("[cb] Speed:", v)
	end,
})

cfg:AddDropdown({
	Text = "Method",
	Options = { "Teleport", "Walk", "Noclip" },
	Multi = false,
	Default = "Walk",
	Idx = "Main_Method",
	Callback = function(choice: string)
		print("[cb] Method:", choice)
	end,
})

cfg:AddDropdown({
	Text = "Searchable (open list, type to filter)",
	Searchable = true,
	Options = {
		"Apple",
		"Apricot",
		"Banana",
		"Blueberry",
		"Cherry",
		"Date",
		"Elderberry",
		"Fig",
		"Grape",
		"Honeydew",
	},
	Multi = false,
	Default = "Banana",
	Idx = "Main_SearchFruit",
	Callback = function(choice: string)
		print("[cb] Fruit:", choice)
	end,
})

cfg:AddDivider()
cfg:AddLabel({
	Text = "AddButton: string + callback, or { Text, Tooltip, Func }.",
	DoesWrap = true,
})
cfg:AddButton({ Text = "Table-style button", Tooltip = "Uses opts.Text + optional Tooltip" }, function()
	print("[cb] Table-style button")
end)
cfg:AddButton("Simple string button", function()
	print("[cb] Simple button")
end)

cfg:AddColorPicker({
	Text = "Accent preview",
	Default = Color3.fromRGB(120, 170, 255),
	Idx = "Main_AccentPreview",
	Callback = function() end,
})
cfg:AddDivider()
cfg:AddLabel({
	Text = "Notifications: Time (linear bar + “Xs left”), Steps + ChangeStep, Persist, optional SoundId / Time = Instance.",
	DoesWrap = true,
})

local demoPersistNotify: any = nil

cfg:AddButton("Notify: timed (6s) + bar", function()
	Library:Notify({
		Title = "Acid Hub",
		Description = "Matches theme (groupbox shell, slider track, accent gradient). Countdown updates live.",
		Time = 6,
	})
end)

cfg:AddButton("Notify: steps + ChangeStep", function()
	local h = Library:Notify({
		Title = "Step demo",
		Description = "Bar fills each second; closes after Time.",
		Time = 8,
		Steps = 5,
	})
	task.spawn(function()
		for i = 1, 5 do
			task.wait(1)
			if h.Destroyed then
				return
			end
			h:ChangeStep(i)
		end
	end)
end)

cfg:AddButton("Notify: persist (stacking ok)", function()
	if demoPersistNotify and not demoPersistNotify.Destroyed then
		demoPersistNotify:Destroy()
	end
	demoPersistNotify = Library:Notify({
		Title = "Persistent",
		Description = "No timer bar. Use “Dismiss persist” or this button again.",
		Persist = true,
	})
end)

cfg:AddButton("Dismiss persist toast", function()
	if demoPersistNotify and not demoPersistNotify.Destroyed then
		demoPersistNotify:Destroy()
	end
	demoPersistNotify = nil
end)

toggleEnable.Set(nil, false)

--[[ Main · right column: Settings first, then tabboxes (each :AddTab returns a proxy tab for AddLeftGroupbox / AddSection). ]]
local mainRightSettings = tabMain:AddRightGroupbox("Settings", {
	Tooltip = "Right column header",
	Icon = "settings",
})
mainRightSettings:AddLabel({
	Text = "Use this column for settings-style blocks. Tab strips below reflow: few tabs share the full width; many tabs wrap to extra rows.",
	DoesWrap = true,
})

local nested = tabMain:AddRightTabbox("Nested pages")
local pgActions = nested:AddTab("Actions")
local pgMore = nested:AddTab("More")
local nestAct = pgActions:AddLeftGroupbox("Tabbox · Actions", { Collapsible = false, Icon = "layers" })
nestAct:AddButton("From tabbox sub-tab", function()
	print("[cb] Tabbox → Actions tab")
end)
nestAct:AddToggle({
	Text = "Toggle on sub-tab",
	Default = false,
	Idx = "Tabbox_SubToggle",
	Callback = function(on: boolean)
		print("[cb] Tabbox toggle:", on)
	end,
})
local nestMore = pgMore:AddLeftGroupbox("Tabbox · More", { Collapsible = false, Icon = "ellipsis" })
nestMore:AddSlider({
	Text = "Nested slider",
	Min = 0,
	Max = 10,
	Default = 5,
	Rounding = 0,
	Idx = "Tabbox_SubSlider",
	Callback = function(v: number)
		print("[cb] Tabbox slider:", v)
	end,
})

local tabboxFive = tabMain:AddRightTabbox("Five-tab strip (fills / wraps)")
local fiveNames = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon" }
for _, nm in fiveNames do
	local pg = tabboxFive:AddTab(nm)
	pg:AddLeftGroupbox(nm, { Collapsible = false, Icon = "folder" }):AddLabel({
		Text = "Sub-page: " .. nm .. " — resize the window to see tabs share the bar or split across rows.",
		DoesWrap = true,
	})
end

local vis = tabVisual:AddLeftGroupbox("ESP", { Collapsible = false, Icon = "scan-eye" })
vis:AddToggle({ Text = "Boxes", Idx = "Esp_Boxes", Callback = function() end })
vis:AddToggle({ Text = "Players", Idx = "Esp_Players", Callback = function() end })

local plr = tabPlayer:AddRightGroupbox("Character", { Icon = "person-standing" })
plr:AddSlider({
	Text = "Jump",
	Min = 50,
	Max = 200,
	Default = 100,
	Rounding = 0,
	Idx = "Player_Jump",
	Callback = function() end,
})

-- UI Settings: left = menu + configuration; right = themes only
local menu = tabUi:AddLeftGroupbox("Menu & window")
menu:AddDropdown({
	Text = "Notification side",
	Options = { "Left", "Right" },
	Default = "Right",
	Idx = "Ui_NotifySide",
	Callback = function(Value: string)
		Library:SetNotifySide(Value)
	end,
})
menu:AddSlider({
	Text = "Corner radius",
	Min = 0,
	Max = 20,
	Rounding = 0,
	Default = Library.CornerRadius,
	Idx = "Ui_Corner",
	Callback = function(value: number)
		window:SetCornerRadius(value)
	end,
})
menu:AddKeybind({
	Text = "Menu toggle key",
	Default = "RightShift",
	Idx = "MenuKeybind",
	NoUI = true,
})
menu:AddDivider()
menu:AddButton("Unload", function()
	Library:Unload()
end)

Library:OnUnload(function()
	print("Acid Hub unloaded")
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind", "Ui_NotifySide", "Ui_Corner" })

ThemeManager:SetFolder("AcidHub")
SaveManager:SetFolder("AcidHub/example-game")

--[[ Config builds on the left column (with menu); themes on the right when SplitColumns is used ]]
SaveManager:BuildConfigSection(tabUi)
ThemeManager:ApplyToTab(tabUi)

SaveManager:LoadAutoloadConfig()
