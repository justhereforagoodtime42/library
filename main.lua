

local LIBRARY_URL =
	"https://raw.githubusercontent.com/justhereforagoodtime42/library/refs/heads/main/main.lua"

-- Optional: full raw URL to a bootstrap script
local RUN_LOADER = false
local LOADER_URL: string? = nil

local function httpGet(url: string): string
	local g: any = game
	if g.HttpGet then
		return g:HttpGet(url)
	end
	local req = (syn and syn.request)
		or (http and http.request)
		or (http_request)
		or (request)
	if not req then
		error("No HttpGet / request")
	end
	local res = req({ Url = url, Method = "GET" })
	local body = res.Body or res.body
	if res.Success == false or (res.StatusCode and res.StatusCode >= 400) then
		error("HTTP " .. tostring(res.StatusCode) .. " for " .. url)
	end
	if typeof(body) ~= "string" or body == "" then
		error("empty response: " .. url)
	end
	return body
end

local loadfn = loadstring or load
if not loadfn then
	error("loadstring/load required (executor)")
end

if RUN_LOADER and typeof(LOADER_URL) == "string" and LOADER_URL ~= "" then
	pcall(function()
		loadfn(httpGet(LOADER_URL), "@" .. LOADER_URL)()
	end)
end

local Library = loadfn(httpGet(LIBRARY_URL), "@" .. LIBRARY_URL)()

local ge = getgenv or function()
	return shared
end
ge().AcidHubLibrary = Library

--[[
	CALLBACK NOTE (same idea as Obsidian):
	You can pass Callback = function(...) end on each element, or keep references to returned tables
	(e.g. toggle:Get()) and wire logic elsewhere — whatever keeps UI and game logic separated.
]]

local window = Library.new({
	Title = "Acid Hub",
	Subtitle = "version: example | discord.gg/yourinvite",
	Size = Vector2.new(520, 440),
})

local tabMain = window:AddTab({ Name = "Main", Icon = "layout-grid" })
local tabVisual = window:AddTab({ Name = "Visuals", Icon = "eye" })
local tabPlayer = window:AddTab({ Name = "Player", Icon = "user" })

local cfg = tabMain:AddSection("Config")
local toggleEnable = cfg:AddToggle({
	Text = "Enable",
	Default = false,
	Callback = function(on: boolean)
		print("[cb] Enable:", on)
	end,
})

cfg:AddSlider({
	Text = "Speed",
	Min = 16,
	Max = 100,
	Default = 50,
	Callback = function(v: number)
		print("[cb] Speed:", v)
	end,
})

cfg:AddDropdown({
	Text = "Method",
	Options = { "Teleport", "Walk", "Noclip" },
	Multi = false,
	Default = "Walk",
	Callback = function(choice: string)
		print("[cb] Method:", choice)
	end,
})

-- Example: flip toggle from code (Obsidian-style Toggles.X:SetValue)
toggleEnable.Set(nil, false)

local farm = tabMain:AddSection("Santa-Farm")
farm:AddDropdown({
	Text = "Fish Sell Rarity",
	Options = { "Common Fish", "Rare Fish", "Epic Fish", "Legendary Fish" },
	Multi = true,
	Default = { "Common Fish", "Rare Fish" },
	Callback = function(list: { string })
		print("[cb] Sell:", table.concat(list, ", "))
	end,
})
farm:AddInput({
	Text = "Pause & collect every (boxes)",
	Placeholder = "0",
	Default = "0",
	Callback = function(text: string)
		print("[cb] Boxes:", text)
	end,
})

local vis = tabVisual:AddSection("ESP")
vis:AddToggle({ Text = "Boxes", Callback = function() end })
vis:AddToggle({ Text = "Players", Callback = function() end })

local plr = tabPlayer:AddSection("Character")
plr:AddSlider({
	Text = "Jump",
	Min = 50,
	Max = 200,
	Default = 100,
	Rounding = 0,
	Callback = function() end,
})

--[[
	AcidHub does not ship ThemeManager / SaveManager addons like Obsidian.
	Use your own config (JSON + writefile) or extend the library if you need that.

	Unload when done:
	  window:Destroy()
]]
