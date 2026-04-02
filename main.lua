-- made with ai
local cloneref = (cloneref or clonereference or function(instance: any)
	return instance
end)
local CoreGui = cloneref(game:GetService("CoreGui"))
local Players = cloneref(game:GetService("Players"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService = cloneref(game:GetService("TweenService"))
local RunService = cloneref(game:GetService("RunService"))

local protectgui = protectgui or (syn and syn.protect_gui) or function() end
local gethui = gethui or function()
	return CoreGui
end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- ----------------------------------------------------------------------------- theme (mutable; ThemeManager / RefreshTheme)
local Library = {}

Library.Theme = {
	Background = Color3.fromRGB(10, 10, 12),
	Panel = Color3.fromRGB(14, 14, 18),
	PanelTrans = 0.12,
	Elevated = Color3.fromRGB(20, 20, 26),
	Stroke = Color3.fromRGB(70, 130, 255),
	StrokeTrans = 0.55,
	Text = Color3.fromRGB(245, 245, 250),
	TextDim = Color3.fromRGB(160, 165, 180),
	AccentBlue = Color3.fromRGB(88, 160, 255),
	AccentPurple = Color3.fromRGB(150, 100, 255),
	SectionDot = Color3.fromRGB(72, 220, 130),
	SliderTrack = Color3.fromRGB(28, 28, 36),
	ToggleOff = Color3.fromRGB(45, 45, 55),
	ToggleOn = Color3.fromRGB(88, 160, 255),
	Corner = UDim.new(0, 8),
	CornerSm = UDim.new(0, 6),
}
local Theme = Library.Theme

Library.Toggles = {} :: { [string]: any }
Library.Options = {} :: { [string]: any }
Library.Unloaded = false
Library._unloadCallbacks = {} :: { () -> () }
Library._windowRefreshes = {} :: { () -> () }
Library.NotifySide = "Right"
Library.CornerRadius = 8
Library.ToggleKeybind = nil
Library._menuInputConn = nil :: RBXScriptConnection?
Library._notifyList = nil :: Frame?
Library._notifyOrder = 0
Library._updateNotifyLayout = nil :: (() -> ())?
Library._windowDestroy = nil :: (() -> ())?

function Library:OnUnload(fn: () -> ())
	if typeof(fn) == "function" then
		table.insert(self._unloadCallbacks, fn)
	end
end

function Library:RefreshTheme()
	for _, fn in self._windowRefreshes do
		pcall(fn)
	end
end

function Library:SetNotifySide(side: string)
	if typeof(side) == "string" then
		self.NotifySide = side
	end
	if self._updateNotifyLayout then
		self._updateNotifyLayout()
	end
end

function Library:SetDPIScale(_scale: number)
	-- Reserved: AcidHub uses fixed scale; hook here if you add DPI scaling later.
end

function Library:Notify(payload: any, duration: number?)
	local title = "Notice"
	local desc = ""
	local t = 3
	if typeof(payload) == "table" then
		title = tostring(payload.Title or title)
		desc = tostring(payload.Description or payload.Text or "")
		t = tonumber(payload.Time) or t
	elseif typeof(payload) == "string" then
		desc = payload
		t = duration or t
	else
		desc = tostring(payload)
	end
	local list = self._notifyList
	if not list or not list.Parent then
		return
	end
	self._notifyOrder += 1
	local order = self._notifyOrder
	local card = Instance.new("Frame")
	card.Name = "Notify_" .. order
	card.Size = UDim2.new(0, 280, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Theme.Elevated
	card.BackgroundTransparency = 0.06
	card.BorderSizePixel = 0
	card.LayoutOrder = -order
	card.Parent = list
	corner(Theme.CornerSm).Parent = card
	stroke(Theme.Stroke, 1, 0.5).Parent = card
	local padN = Instance.new("UIPadding")
	padN.PaddingLeft = UDim.new(0, 10)
	padN.PaddingRight = UDim.new(0, 10)
	padN.PaddingTop = UDim.new(0, 8)
	padN.PaddingBottom = UDim.new(0, 8)
	padN.Parent = card
	local vl = Instance.new("UIListLayout")
	vl.SortOrder = Enum.SortOrder.LayoutOrder
	vl.Padding = UDim.new(0, 4)
	vl.Parent = card
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBold
	tl.TextSize = 14
	tl.TextColor3 = Theme.Text
	tl.TextXAlignment = Enum.TextXAlignment.Left
	tl.TextWrapped = true
	tl.AutomaticSize = Enum.AutomaticSize.Y
	tl.Size = UDim2.new(1, 0, 0, 0)
	tl.Text = title
	tl.LayoutOrder = 1
	tl.Parent = card
	if desc ~= "" then
		local dl = Instance.new("TextLabel")
		dl.BackgroundTransparency = 1
		dl.Font = Enum.Font.GothamMedium
		dl.TextSize = 12
		dl.TextColor3 = Theme.TextDim
		dl.TextXAlignment = Enum.TextXAlignment.Left
		dl.TextWrapped = true
		dl.AutomaticSize = Enum.AutomaticSize.Y
		dl.Size = UDim2.new(1, 0, 0, 0)
		dl.Text = desc
		dl.LayoutOrder = 2
		dl.Parent = card
	end
	task.delay(t, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

function Library:Unload()
	if self.Unloaded then
		return
	end
	self.Unloaded = true
	for _, fn in self._unloadCallbacks do
		pcall(fn)
	end
	table.clear(self._unloadCallbacks)
	if self._menuInputConn then
		self._menuInputConn:Disconnect()
		self._menuInputConn = nil
	end
	if self._windowDestroy then
		self._windowDestroy()
		self._windowDestroy = nil
	end
	self._notifyList = nil
	self._updateNotifyLayout = nil
	table.clear(self._windowRefreshes)
	table.clear(self.Toggles)
	table.clear(self.Options)
	self.ToggleKeybind = nil
end

-- ----------------------------------------------------------------------------- helpers
local function tween(inst: Instance, ti: TweenInfo, props: { [string]: any })
	return TweenService:Create(inst, ti, props)
end

local function corner(radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	return c
end

local function stroke(color: Color3, thickness: number, transparency: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

local function pad(p: number)
	local x = Instance.new("UIPadding")
	x.PaddingLeft = UDim.new(0, p)
	x.PaddingRight = UDim.new(0, p)
	x.PaddingTop = UDim.new(0, p)
	x.PaddingBottom = UDim.new(0, p)
	return x
end

type GlowLayerSpec = { size: number, transparency: number, radius: number }

--[[ Centered stacked frames behind a host; spills past edges when host clips are off ]]
local function addStackedGlow(host: Frame, specs: { GlowLayerSpec })
	local steps = #specs - 1
	for i, g in specs do
		local t = if steps > 0 then (i - 1) / steps else 0
		local layerColor = Theme.AccentBlue:Lerp(Theme.Stroke, t)
		local layer = Instance.new("Frame")
		layer.Name = "GlowLayer"
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.Position = UDim2.fromScale(0.5, 0.5)
		layer.Size = UDim2.new(1, g.size, 1, g.size)
		layer.BackgroundColor3 = layerColor
		layer.BackgroundTransparency = g.transparency
		layer.BorderSizePixel = 0
		layer.ZIndex = 0
		layer.Parent = host
		local gc = Instance.new("UICorner")
		gc.CornerRadius = UDim.new(0, g.radius)
		gc.Parent = layer
	end
end

--[[ Sidebar tabs: soft white halo; tint updated in selectTab ]]
local function addTabStackedGlow(host: Frame, specs: { GlowLayerSpec })
	local n = #specs
	for i, g in specs do
		local t = if n > 1 then (i - 1) / (n - 1) else 0
		local layer = Instance.new("Frame")
		layer.Name = "GlowLayer"
		layer:SetAttribute("GlowStep", i)
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.Position = UDim2.fromScale(0.5, 0.5)
		layer.Size = UDim2.new(1, g.size, 1, g.size)
		layer.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(232, 238, 255), t * 0.4)
		layer.BackgroundTransparency = g.transparency
		layer.BorderSizePixel = 0
		layer.ZIndex = 0
		layer.Parent = host
		local gc = Instance.new("UICorner")
		gc.CornerRadius = UDim.new(0, g.radius)
		gc.Parent = layer
	end
end

local function paintTabGlowHost(tabGlowHost: Frame?, isSelected: boolean)
	if not tabGlowHost then
		return
	end
	local layers: { Frame } = {}
	for _, c in tabGlowHost:GetChildren() do
		if c:IsA("Frame") and c.Name == "GlowLayer" then
			table.insert(layers, c)
		end
	end
	table.sort(layers, function(a, b)
		return (tonumber(a:GetAttribute("GlowStep")) or 0) < (tonumber(b:GetAttribute("GlowStep")) or 0)
	end)
	local steps = #layers - 1
	for i, layer in layers do
		local t = if steps > 0 then (i - 1) / steps else 0
		if isSelected then
			layer.BackgroundColor3 = Theme.AccentPurple:Lerp(Theme.AccentBlue, t)
		else
			layer.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(232, 238, 255), t * 0.4)
		end
	end
end

-- ----------------------------------------------------------------------------- Lucide ([lucide.dev](https://lucide.dev) — executor loads sprite module like Obsidian)
local LUCIDE_ROBLOX_DIRECT =
	"https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua"

local loadchunk = loadstring or load

function Library.IsValidCustomIcon(Icon: any): boolean
	return typeof(Icon) == "string"
		and (
			Icon:match("rbxasset") ~= nil
			or Icon:match("roblox%.com/asset/%?id=") ~= nil
			or Icon:match("rbxthumb://type=") ~= nil
		)
end

local LucideFetchOk = false
local LucideModule: any = nil

local function tryInitLucideModule()
	local ok, mod = pcall(function()
		local g: any = game
		local src = g:HttpGet(LUCIDE_ROBLOX_DIRECT)
		if not loadchunk then
			error("loadstring/load not available")
		end
		local chunk = loadchunk(src)
		if not chunk then
			error("invalid lucide module source")
		end
		return chunk()
	end)
	if ok and mod ~= nil and typeof(mod.GetAsset) == "function" then
		LucideFetchOk = true
		LucideModule = mod
	else
		LucideFetchOk = false
		LucideModule = nil
	end
end

tryInitLucideModule()

function Library:GetIcon(IconName: string): any
	if not LucideFetchOk or LucideModule == nil then
		return nil
	end
	local success, icon = pcall(function()
		return LucideModule.GetAsset(IconName)
	end)
	if not success then
		return nil
	end
	return icon
end

function Library:GetCustomIcon(IconName: any): any
	if typeof(IconName) ~= "string" then
		return nil
	end
	if Library.IsValidCustomIcon(IconName) then
		return {
			Url = IconName,
			ImageRectOffset = Vector2.zero,
			ImageRectSize = Vector2.zero,
			Custom = true,
		}
	end
	return Library:GetIcon(IconName)
end

--[[ Replace remote module (e.g. offline require) — same idea as Obsidian SetIconModule ]]
function Library:SetIconModule(module: any)
	if module ~= nil and typeof(module.GetAsset) == "function" then
		LucideFetchOk = true
		LucideModule = module
	end
end

export type WindowConfig = {
	Title: string?,
	Subtitle: string?,
	--[[ optional rbxasset:// or http url for left mascot ]]
	MascotImage: string?,
	Size: Vector2?,
	--[[ minimum body content size (width × height below title bar); root adds mascot + 48px header ]]
	MinSize: Vector2?,
	Resizable: boolean?,
	GlowEnabled: boolean?,
}

function Library.new(config: WindowConfig)
	config = config or {}
	local titleText = config.Title or "Acid Hub"
	local subtitleText = config.Subtitle or "https://example.com | discord.gg/example"
	local minContent = config.MinSize or Vector2.new(380, 300)
	local size = config.Size or Vector2.new(520, 440)
	size = Vector2.new(math.max(size.X, minContent.X), math.max(size.Y, minContent.Y))
	local mascotId = config.MascotImage
	local mascotOffset = if mascotId then 72 else 0
	local minRootW = minContent.X + mascotOffset
	local minRootH = minContent.Y + 48

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AcidHubUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	--[[ Obsidian-style: protect before parenting, then gethui with PlayerGui fallback ]]
	pcall(protectgui, screenGui)
	local parentOk = pcall(function()
		screenGui.Parent = gethui()
	end)
	if not parentOk or not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", math.huge)
	end

	Library.Unloaded = false
	table.clear(Library.Toggles)
	table.clear(Library.Options)

	local toggleThemeRows: { { track: Frame, getOn: () -> boolean } } = {}
	local sliderGradients: { UIGradient } = {}

	-- Notifications (Obsidian-style toasts)
	local notifyHost = Instance.new("Frame")
	notifyHost.Name = "NotifyHost"
	notifyHost.Size = UDim2.fromScale(1, 1)
	notifyHost.BackgroundTransparency = 1
	notifyHost.ZIndex = 750
	notifyHost.Parent = screenGui
	local notifyList = Instance.new("Frame")
	notifyList.Name = "NotifyList"
	notifyList.Size = UDim2.new(0, 300, 1, -24)
	notifyList.BackgroundTransparency = 1
	notifyList.Parent = notifyHost
	local nlayout = Instance.new("UIListLayout")
	nlayout.SortOrder = Enum.SortOrder.LayoutOrder
	nlayout.VerticalAlignment = Enum.VerticalAlignment.Top
	nlayout.Padding = UDim.new(0, 8)
	nlayout.Parent = notifyList
	Library._notifyList = notifyList

	local function updateNotifyLayout()
		local side = string.lower(Library.NotifySide or "right")
		if side == "left" then
			notifyList.AnchorPoint = Vector2.new(0, 0)
			notifyList.Position = UDim2.new(0, 12, 0, 12)
			nlayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		else
			notifyList.AnchorPoint = Vector2.new(1, 0)
			notifyList.Position = UDim2.new(1, -12, 0, 12)
			nlayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		end
	end
	updateNotifyLayout()
	Library._updateNotifyLayout = updateNotifyLayout

	local function paintThemedDescendants(host: Instance)
		for _, d in host:GetDescendants() do
			if not d:IsA("GuiObject") then
				continue
			end
			local bgk = d:GetAttribute("AcidBg")
			if typeof(bgk) == "string" and typeof(Theme[bgk]) == "Color3" then
				d.BackgroundColor3 = Theme[bgk]
			end
			local tx = d:GetAttribute("AcidText")
			if typeof(tx) == "string" and typeof(Theme[tx]) == "Color3" then
				if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
					d.TextColor3 = Theme[tx]
				end
			end
			local ph = d:GetAttribute("AcidPlaceholder")
			if typeof(ph) == "string" and typeof(Theme[ph]) == "Color3" and d:IsA("TextBox") then
				d.PlaceholderColor3 = Theme[ph]
			end
			local sk = d:GetAttribute("AcidStroke")
			if typeof(sk) == "string" and typeof(Theme[sk]) == "Color3" and d:IsA("UIStroke") then
				d.Color = Theme[sk]
			end
			local ik = d:GetAttribute("AcidImg")
			if typeof(ik) == "string" and typeof(Theme[ik]) == "Color3" and d:IsA("ImageLabel") then
				d.ImageColor3 = Theme[ik]
			end
		end
	end

	-- Tooltips (hover label / tab — same idea as Obsidian AddTooltip)
	local tooltipLabel = Instance.new("TextLabel")
	tooltipLabel.Name = "AcidTooltip"
	tooltipLabel.BackgroundColor3 = Theme.Elevated
	tooltipLabel.BackgroundTransparency = 0.08
	tooltipLabel.TextColor3 = Theme.Text
	tooltipLabel.TextSize = 13
	tooltipLabel.Font = Enum.Font.GothamMedium
	tooltipLabel.TextXAlignment = Enum.TextXAlignment.Left
	tooltipLabel.TextYAlignment = Enum.TextYAlignment.Top
	tooltipLabel.TextWrapped = true
	tooltipLabel.Visible = false
	tooltipLabel.AutomaticSize = Enum.AutomaticSize.XY
	tooltipLabel.ZIndex = 500
	tooltipLabel.Parent = screenGui
	corner(Theme.CornerSm).Parent = tooltipLabel
	local ttPad = Instance.new("UIPadding")
	ttPad.PaddingLeft = UDim.new(0, 8)
	ttPad.PaddingRight = UDim.new(0, 8)
	ttPad.PaddingTop = UDim.new(0, 6)
	ttPad.PaddingBottom = UDim.new(0, 6)
	ttPad.Parent = tooltipLabel
	stroke(Theme.Stroke, 1, 0.45).Parent = tooltipLabel

	local tooltipToken = 0
	local tooltipLoopToken = 0
	local function hideTooltip()
		tooltipLoopToken += 1
		tooltipLabel.Visible = false
	end
	local function bindTooltipToInstances(instances: { GuiObject }, tip: string?)
		if typeof(tip) ~= "string" or tip == "" then
			return
		end
		local hoverDepth = 0
		local hideScheduled = false
		local function scheduleHide()
			if hideScheduled then
				return
			end
			hideScheduled = true
			task.defer(function()
				hideScheduled = false
				if hoverDepth <= 0 then
					hideTooltip()
				end
			end)
		end
		local function onEnter()
			hoverDepth += 1
			if hoverDepth > 1 then
				return
			end
			tooltipToken += 1
			local showTok = tooltipToken
			tooltipLoopToken += 1
			local loopTok = tooltipLoopToken
			tooltipLabel.Text = tip
			tooltipLabel.Visible = true
			task.spawn(function()
				while
					tooltipLabel.Visible
					and loopTok == tooltipLoopToken
					and showTok == tooltipToken
				do
					local p = UserInputService:GetMouseLocation()
					local cam = workspace.CurrentCamera
					local vw = if cam then cam.ViewportSize.X else 1920
					local vh = if cam then cam.ViewportSize.Y else 1080
					local ax = tooltipLabel.AbsoluteSize.X
					local ay = tooltipLabel.AbsoluteSize.Y
					local x = math.clamp(p.X + 14, 6, math.max(6, vw - ax - 6))
					local y = math.clamp(p.Y + 14, 6, math.max(6, vh - ay - 6))
					tooltipLabel.Position = UDim2.fromOffset(x, y)
					RunService.RenderStepped:Wait()
				end
			end)
		end
		local function onLeave()
			hoverDepth = math.max(0, hoverDepth - 1)
			if hoverDepth == 0 then
				scheduleHide()
			end
		end
		for _, inst in instances do
			inst.MouseEnter:Connect(onEnter)
			inst.MouseLeave:Connect(onLeave)
		end
	end

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.new(0.5, 0, 0.5, 0)
	root.Size = UDim2.fromOffset(size.X + mascotOffset, size.Y + 48)
	root.BackgroundTransparency = 1
	root.Parent = screenGui

	-- top row: mascot + pill
	local topRow = Instance.new("Frame")
	topRow.Name = "TopRow"
	topRow.Size = UDim2.new(1, 0, 0, 40)
	topRow.BackgroundTransparency = 1
	topRow.ZIndex = 3
	topRow.Parent = root

	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.Padding = UDim.new(0, 10)
	topLayout.Parent = topRow

	local mascot: ImageLabel? = nil
	if mascotId then
		local m = Instance.new("ImageLabel")
		m.Name = "Mascot"
		m.Size = UDim2.fromOffset(64, 64)
		m.BackgroundTransparency = 1
		m.Image = mascotId
		m.ScaleType = Enum.ScaleType.Fit
		m.LayoutOrder = 0
		m.Parent = topRow
		mascot = m
	end

	local pill = Instance.new("Frame")
	pill.Name = "TopPill"
	pill.Size = UDim2.new(1, mascot and -74 or 0, 0, 36)
	pill.BackgroundColor3 = Theme.Background
	pill.BackgroundTransparency = 0.08
	pill.LayoutOrder = 1
	pill.Parent = topRow
	corner(UDim.new(1, 0)).Parent = pill
	stroke(Theme.Stroke, 1, 0.65).Parent = pill
	pad(12).Parent = pill

	local pillLayout = Instance.new("UIListLayout")
	pillLayout.FillDirection = Enum.FillDirection.Horizontal
	pillLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pillLayout.Padding = UDim.new(0, 10)
	pillLayout.Parent = pill

	local logo = Instance.new("Frame")
	logo.Name = "LogoDot"
	logo.Size = UDim2.fromOffset(18, 18)
	logo.BackgroundColor3 = Theme.AccentPurple
	logo.LayoutOrder = 0
	logo.Parent = pill
	corner(UDim.new(1, 0)).Parent = logo

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, -28, 1, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextSize = 13
	subtitle.TextColor3 = Theme.TextDim
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Text = subtitleText
	subtitle.LayoutOrder = 1
	subtitle.Parent = pill

	-- body: sidebar + panel
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0, 48)
	body.Size = UDim2.new(1, 0, 1, -48)
	body.BackgroundTransparency = 1
	body.ZIndex = 1
	body.Parent = root

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.FillDirection = Enum.FillDirection.Horizontal
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0, 10)
	bodyLayout.Parent = body

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.fromOffset(52, 0)
	sidebar.AutomaticSize = Enum.AutomaticSize.Y
	sidebar.BackgroundTransparency = 1
	sidebar.LayoutOrder = 0
	sidebar.Parent = body

	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, 8)
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sideList.Parent = sidebar

	--[[ One shell: transparent MainPanel holds glow + inner face (no extra MainPanelWrap in the tree) ]]
	local mainPanel = Instance.new("Frame")
	mainPanel.Name = "MainPanel"
	mainPanel.Size = UDim2.new(1, -62, 1, 0)
	mainPanel.LayoutOrder = 1
	mainPanel.BackgroundTransparency = 1
	mainPanel.BorderSizePixel = 0
	mainPanel.ClipsDescendants = false
	mainPanel.Parent = body

	if config.GlowEnabled ~= false then
		local panelGlowHost = Instance.new("Frame")
		panelGlowHost.Name = "MainGlowHost"
		panelGlowHost.Size = UDim2.fromScale(1, 1)
		panelGlowHost.Position = UDim2.fromScale(0, 0)
		panelGlowHost.BackgroundTransparency = 1
		panelGlowHost.BorderSizePixel = 0
		panelGlowHost.ZIndex = 0
		panelGlowHost.Parent = mainPanel
		addStackedGlow(panelGlowHost, {
			{ size = 5, transparency = 0.82, radius = 9 },
			{ size = 11, transparency = 0.9, radius = 11 },
			{ size = 17, transparency = 0.95, radius = 12 },
			{ size = 22, transparency = 0.98, radius = 13 },
		})
	end

	local panelFace = Instance.new("Frame")
	panelFace.Name = "PanelFace"
	panelFace.Size = UDim2.fromScale(1, 1)
	panelFace.Position = UDim2.fromScale(0, 0)
	panelFace.ZIndex = 1
	panelFace.BackgroundColor3 = Theme.Panel
	panelFace.BackgroundTransparency = Theme.PanelTrans
	panelFace.ClipsDescendants = true
	panelFace.Parent = mainPanel
	corner(Theme.Corner).Parent = panelFace
	local panelOutline = stroke(Theme.Stroke, 2, math.clamp(Theme.StrokeTrans - 0.15, 0.2, 0.55))
	panelOutline.Name = "PanelOutline"
	panelOutline.Parent = panelFace

	local panelTitle = Instance.new("TextLabel")
	panelTitle.Name = "WindowTitle"
	panelTitle.Size = UDim2.new(1, -24, 0, 28)
	panelTitle.Position = UDim2.new(0, 12, 0, 10)
	panelTitle.BackgroundTransparency = 1
	panelTitle.Font = Enum.Font.GothamBold
	panelTitle.TextSize = 18
	panelTitle.TextColor3 = Theme.Text
	panelTitle.TextXAlignment = Enum.TextXAlignment.Left
	panelTitle.Text = titleText
	panelTitle.Parent = panelFace

	local contentHost = Instance.new("Frame")
	contentHost.Name = "ContentHost"
	contentHost.Position = UDim2.new(0, 0, 0, 44)
	contentHost.Size = UDim2.new(1, 0, 1, -44)
	contentHost.BackgroundTransparency = 1
	contentHost.Parent = panelFace

	local tabButtons: { TextButton } = {}
	local tabScrolls: { GuiObject } = {}
	local activeTab = 0

	local function selectTab(index: number)
		activeTab = index
		for i, btn in tabButtons do
			local isSel = (i == index)
			local tabSlot = btn.Parent
			if tabSlot and tabSlot:IsA("Frame") then
				paintTabGlowHost(tabSlot:FindFirstChild("TabGlowHost") :: Frame?, isSel)
			end
			local glow = btn:FindFirstChild("Glow") :: UIStroke?
			if glow then
				glow.Color = if isSel then Theme.AccentPurple else Color3.new(1, 1, 1)
				glow.Thickness = if isSel then 2.5 else 1.2
				glow.Transparency = if isSel then 0.18 else 0.72
			end
			btn.BackgroundTransparency = if isSel then 0.08 else 0.45
			local icon = btn:FindFirstChild("LucideIcon")
			if icon and icon:IsA("ImageLabel") then
				icon.ImageColor3 = if isSel then Color3.new(1, 1, 1) else Theme.Text
			else
				btn.TextColor3 = if isSel then Color3.new(1, 1, 1) else Theme.Text
			end
		end
		for i, sc in tabScrolls do
			sc.Visible = (i == index)
		end
	end

	local resizeHandle: TextButton? = nil
	if config.Resizable ~= false then
		local rh = Instance.new("TextButton")
		rh.Name = "ResizeGrip"
		rh.AnchorPoint = Vector2.new(1, 1)
		rh.Position = UDim2.new(1, -4, 1, -4)
		rh.Size = UDim2.fromOffset(28, 28)
		rh.BackgroundTransparency = 1
		rh.Text = ""
		rh.AutoButtonColor = false
		rh.Active = true
		rh.Selectable = false
		rh.ZIndex = 50
		rh.Parent = root
		local resizeIcon = Library:GetIcon("move-diagonal-2")
		if resizeIcon and typeof(resizeIcon.Url) == "string" and resizeIcon.Url ~= "" then
			local gripImg = Instance.new("ImageLabel")
			gripImg.Name = "ResizeIcon"
			gripImg.BackgroundTransparency = 1
			gripImg.AnchorPoint = Vector2.new(1, 1)
			gripImg.Position = UDim2.new(1, -2, 1, -2)
			gripImg.Size = UDim2.fromOffset(18, 18)
			gripImg.Image = resizeIcon.Url
			gripImg.ImageRectOffset = resizeIcon.ImageRectOffset or Vector2.zero
			gripImg.ImageRectSize = resizeIcon.ImageRectSize or Vector2.zero
			gripImg.ImageColor3 = Theme.TextDim
			gripImg.ImageTransparency = 0.35
			gripImg.ScaleType = Enum.ScaleType.Fit
			gripImg.ZIndex = 51
			gripImg.Parent = rh
		else
			local grip = Instance.new("TextLabel")
			grip.BackgroundTransparency = 1
			grip.Size = UDim2.fromScale(1, 1)
			grip.Text = "⋰"
			grip.TextColor3 = Theme.TextDim
			grip.TextTransparency = 0.45
			grip.TextSize = 16
			grip.Font = Enum.Font.GothamBold
			grip.ZIndex = 51
			grip.Parent = rh
		end
		resizeHandle = rh
	end

	-- dragging + resize (grip uses local InputBegan — global InputBegan often has gameProcessed=true on Gui clicks)
	local dragConn: { RBXScriptConnection } = {}
	local function beginDrag()
		local dragging = false
		local resizing = false
		local dragStart: Vector2
		local startPos: UDim2
		local resizeStart: Vector2
		local resizeStartSize: Vector2
		local resizeEndConn: RBXScriptConnection? = nil

		if resizeHandle then
			resizeHandle.InputBegan:Connect(function(input: InputObject)
				if
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end
				resizing = true
				resizeStart = Vector2.new(input.Position.X, input.Position.Y)
				resizeStartSize = Vector2.new(root.AbsoluteSize.X, root.AbsoluteSize.Y)
				if resizeEndConn then
					resizeEndConn:Disconnect()
					resizeEndConn = nil
				end
				resizeEndConn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						resizing = false
						if resizeEndConn then
							resizeEndConn:Disconnect()
							resizeEndConn = nil
						end
					end
				end)
			end)
		end

		local function inputBegan(input: InputObject, gp: boolean)
			if gp then
				return
			end
			if resizing then
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local p = input.Position
			local ap = mainPanel.AbsolutePosition
			local as = mainPanel.AbsoluteSize
			if
				p.X >= ap.X
				and p.X <= ap.X + as.X
				and p.Y >= ap.Y
				and p.Y <= ap.Y + 44
			then
				dragging = true
				dragStart = Vector2.new(p.X, p.Y)
				startPos = root.Position
			end
			if
				pill.AbsolutePosition.X <= p.X
				and p.X <= pill.AbsolutePosition.X + pill.AbsoluteSize.X
				and pill.AbsolutePosition.Y <= p.Y
				and p.Y <= pill.AbsolutePosition.Y + pill.AbsoluteSize.Y
			then
				dragging = true
				dragStart = Vector2.new(p.X, p.Y)
				startPos = root.Position
			end
		end
		local function inputMoved(input: InputObject, gp: boolean)
			-- Clicks on our GUI set gameProcessed; still need move events while dragging/resizing.
			if gp and not dragging and not resizing then
				return
			end
			if resizing then
				if
					input.UserInputType ~= Enum.UserInputType.MouseMovement
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end
				local delta = Vector2.new(input.Position.X, input.Position.Y) - resizeStart
				local newW = math.max(minRootW, resizeStartSize.X + delta.X)
				local newH = math.max(minRootH, resizeStartSize.Y + delta.Y)
				root.Size = UDim2.fromOffset(newW, newH)
				return
			end
			if not dragging then
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			root.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
		local function inputEnded(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
				resizing = false
			end
		end
		table.insert(dragConn, UserInputService.InputBegan:Connect(inputBegan))
		table.insert(dragConn, UserInputService.InputChanged:Connect(inputMoved))
		table.insert(dragConn, UserInputService.InputEnded:Connect(inputEnded))
	end
	beginDrag()

	local refreshThemeFn: () -> ()
	refreshThemeFn = function()
		tooltipLabel.BackgroundColor3 = Theme.Elevated
		tooltipLabel.TextColor3 = Theme.Text
		for _, ch in tooltipLabel:GetChildren() do
			if ch:IsA("UIStroke") then
				ch.Color = Theme.Stroke
			end
		end
		pill.BackgroundColor3 = Theme.Background
		for _, ch in pill:GetChildren() do
			if ch:IsA("UIStroke") then
				ch.Color = Theme.Stroke
			end
		end
		logo.BackgroundColor3 = Theme.AccentPurple
		subtitle.TextColor3 = Theme.TextDim
		panelFace.BackgroundColor3 = Theme.Panel
		panelFace.BackgroundTransparency = Theme.PanelTrans
		for _, ch in panelFace:GetChildren() do
			if ch.Name == "PanelOutline" and ch:IsA("UIStroke") then
				ch.Color = Theme.Stroke
				ch.Transparency = math.clamp(Theme.StrokeTrans - 0.15, 0.2, 0.55)
			end
		end
		panelTitle.TextColor3 = Theme.Text
		for _, sc in tabScrolls do
			if sc:IsA("ScrollingFrame") then
				sc.ScrollBarImageColor3 = Theme.AccentBlue
			else
				for _, ch in sc:GetChildren() do
					if ch:IsA("ScrollingFrame") then
						ch.ScrollBarImageColor3 = Theme.AccentBlue
					end
				end
			end
		end
		for _, row in toggleThemeRows do
			row.track.BackgroundColor3 = if row.getOn() then Theme.ToggleOn else Theme.ToggleOff
		end
		for _, grad in sliderGradients do
			grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.AccentPurple),
				ColorSequenceKeypoint.new(1, Theme.AccentBlue),
			})
		end
		paintThemedDescendants(contentHost)
		selectTab(activeTab)
		if resizeHandle then
			local grip = resizeHandle:FindFirstChild("ResizeIcon")
			if grip and grip:IsA("ImageLabel") then
				grip.ImageColor3 = Theme.TextDim
			end
			local g2 = resizeHandle:FindFirstChildOfClass("TextLabel")
			if g2 then
				g2.TextColor3 = Theme.TextDim
			end
		end
	end

	if Library._menuInputConn then
		Library._menuInputConn:Disconnect()
		Library._menuInputConn = nil
	end
	Library._menuInputConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or Library.Unloaded then
			return
		end
		local tb = Library.ToggleKeybind
		if not tb or typeof(tb.Value) ~= "EnumItem" then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode ~= tb.Value then
			return
		end
		root.Visible = not root.Visible
	end)

	local window = {
		_gui = screenGui,
		_root = root,
		_main = mainPanel,
		_contentHost = contentHost,
		_tabButtons = tabButtons,
		_tabScrolls = tabScrolls,
		_selectTab = selectTab,
		_dragConn = dragConn,
	}

	local function destroyWindowGui()
		for _, c in dragConn do
			c:Disconnect()
		end
		table.clear(dragConn)
		for i, fn in Library._windowRefreshes do
			if fn == refreshThemeFn then
				table.remove(Library._windowRefreshes, i)
				break
			end
		end
		if screenGui.Parent then
			screenGui:Destroy()
		end
	end

	Library._windowDestroy = destroyWindowGui
	table.insert(Library._windowRefreshes, refreshThemeFn)

	function window:Destroy()
		Library:Unload()
	end

	function window:SetTitle(t: string)
		panelTitle.Text = t
	end

	function window:SetSubtitle(t: string)
		subtitle.Text = t
	end

	function window:SetCornerRadius(n: number)
		n = math.clamp(math.floor(n + 0.5), 0, 32)
		Library.CornerRadius = n
		Theme.Corner = UDim.new(0, n)
		Theme.CornerSm = UDim.new(0, math.max(0, math.floor(n * 0.75)))
		local pf = panelFace:FindFirstChildWhichIsA("UICorner")
		if pf then
			pf.CornerRadius = Theme.Corner
		end
	end

	-- Tab API
	local Tab = {}
	Tab.__index = Tab

	--[[ Tab icons: Lucide name (e.g. "layout-grid", "eye") or rbxassetid://… — same as Obsidian GetCustomIcon
	    SplitColumns: two-column layout (left/right ScrollingFrames); use AddLeftGroupbox / AddRightGroupbox ]]
	function window:AddTab(opts: { Name: string?, Icon: string?, Tooltip: string?, SplitColumns: boolean? })
		opts = opts or {}
		local idx = #tabScrolls + 1
		local splitColumns = opts.SplitColumns == true
		local rawIcon = opts.Icon
		local parsed = (rawIcon ~= nil and rawIcon ~= "") and Library:GetCustomIcon(rawIcon) or nil

		local tabSlot = Instance.new("Frame")
		tabSlot.Name = "TabSlot_" .. idx
		tabSlot.Size = UDim2.fromOffset(44, 44)
		tabSlot.BackgroundTransparency = 1
		tabSlot.BorderSizePixel = 0
		tabSlot.ClipsDescendants = false
		tabSlot.LayoutOrder = idx
		tabSlot.Parent = sidebar

		if config.GlowEnabled ~= false then
			local tabGlowHost = Instance.new("Frame")
			tabGlowHost.Name = "TabGlowHost"
			tabGlowHost.Size = UDim2.fromScale(1, 1)
			tabGlowHost.BackgroundTransparency = 1
			tabGlowHost.BorderSizePixel = 0
			tabGlowHost.ZIndex = 0
			tabGlowHost.Parent = tabSlot
			addTabStackedGlow(tabGlowHost, {
				{ size = 2, transparency = 0.88, radius = 6 },
				{ size = 6, transparency = 0.93, radius = 7 },
				{ size = 11, transparency = 0.97, radius = 8 },
			})
		end

		local btn = Instance.new("TextButton")
		btn.Name = "Tab_" .. idx
		btn.Size = UDim2.fromScale(1, 1)
		btn.ZIndex = 2
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Theme.Elevated
		btn.BackgroundTransparency = 0.45
		btn.Text = ""
		btn.Parent = tabSlot

		if parsed then
			local img = Instance.new("ImageLabel")
			img.Name = "LucideIcon"
			img.BackgroundTransparency = 1
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Size = UDim2.fromOffset(22, 22)
			img.ScaleType = Enum.ScaleType.Fit
			img.Image = parsed.Url
			img.ImageRectOffset = parsed.ImageRectOffset or Vector2.zero
			img.ImageRectSize = parsed.ImageRectSize or Vector2.zero
			img.ImageColor3 = Theme.Text
			img.Parent = btn
		else
			local fallback = "◫"
			if rawIcon and rawIcon ~= "" then
				-- kebab-case / lucide-like token → keep placeholder; otherwise treat as literal glyph (emoji, etc.)
				if not string.match(rawIcon, "^[%w%-]+$") then
					fallback = rawIcon
				end
			end
			btn.Text = fallback
			btn.TextColor3 = Theme.Text
			btn.TextSize = 18
			btn.Font = Enum.Font.GothamBold
		end
		corner(Theme.CornerSm).Parent = btn
		local g = stroke(Color3.new(1, 1, 1), 1.2, 0.72)
		g.Name = "Glow"
		g.Parent = btn

		btn.MouseEnter:Connect(function()
			if idx ~= activeTab then
				tween(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.25 }):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			if idx ~= activeTab then
				tween(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.45 }):Play()
			end
		end)
		btn.MouseButton1Click:Connect(function()
			selectTab(idx)
		end)

		local tipStr = opts.Tooltip
		if typeof(tipStr) ~= "string" or tipStr == "" then
			tipStr = opts.Name
		end
		if typeof(tipStr) == "string" and tipStr ~= "" then
			bindTooltipToInstances({ btn }, tipStr)
		end

		local scroll: ScrollingFrame
		local list: UIListLayout
		local scrollLeft: ScrollingFrame? = nil
		local scrollRight: ScrollingFrame? = nil
		local listLeft: UIListLayout? = nil
		local listRight: UIListLayout? = nil

		if splitColumns then
			local host = Instance.new("Frame")
			host.Name = "TabSplitHost_" .. idx
			host.Size = UDim2.fromScale(1, 1)
			host.BackgroundTransparency = 1
			host.BorderSizePixel = 0
			host.Visible = (idx == 1)
			host.Parent = contentHost

			local function makeColumn(name: string, xScale: number, xOffset: number): (ScrollingFrame, UIListLayout)
				local sc = Instance.new("ScrollingFrame")
				sc.Name = name
				sc.Size = UDim2.new(0.5, -7, 1, 0)
				sc.Position = UDim2.new(xScale, xOffset, 0, 0)
				sc.BackgroundTransparency = 1
				sc.BorderSizePixel = 0
				sc.ScrollBarThickness = 4
				sc.ScrollBarImageColor3 = Theme.AccentBlue
				sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
				sc.CanvasSize = UDim2.new(0, 0, 0, 0)
				sc.Parent = host

				local lst = Instance.new("UIListLayout")
				lst.SortOrder = Enum.SortOrder.LayoutOrder
				lst.Padding = UDim.new(0, 12)
				lst.Parent = sc

				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 14)
				pad.PaddingRight = UDim.new(0, 14)
				pad.PaddingTop = UDim.new(0, 8)
				pad.PaddingBottom = UDim.new(0, 20)
				pad.Parent = sc

				return sc, lst
			end

			local sl, ll = makeColumn("TabColumn_Left_" .. idx, 0, 0)
			local sr, lr = makeColumn("TabColumn_Right_" .. idx, 0.5, 7)
			scrollLeft, listLeft = sl, ll
			scrollRight, listRight = sr, lr
			scroll = sl
			list = ll
			table.insert(tabScrolls, host)
		else
			local sc = Instance.new("ScrollingFrame")
			sc.Name = "TabContent_" .. idx
			sc.Size = UDim2.fromScale(1, 1)
			sc.BackgroundTransparency = 1
			sc.BorderSizePixel = 0
			sc.ScrollBarThickness = 4
			sc.ScrollBarImageColor3 = Theme.AccentBlue
			sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
			sc.CanvasSize = UDim2.new(0, 0, 0, 0)
			sc.Visible = (idx == 1)
			sc.Parent = contentHost
			scroll = sc

			local lst = Instance.new("UIListLayout")
			lst.SortOrder = Enum.SortOrder.LayoutOrder
			lst.Padding = UDim.new(0, 12)
			lst.Parent = scroll
			list = lst

			local padScroll = Instance.new("UIPadding")
			padScroll.PaddingLeft = UDim.new(0, 14)
			padScroll.PaddingRight = UDim.new(0, 14)
			padScroll.PaddingTop = UDim.new(0, 8)
			padScroll.PaddingBottom = UDim.new(0, 20)
			padScroll.Parent = scroll

			table.insert(tabScrolls, scroll)
		end

		table.insert(tabButtons, btn)

		local tab = setmetatable({
			_scroll = scroll,
			_list = list,
			_split = splitColumns,
			_scrollLeft = scrollLeft,
			_scrollRight = scrollRight,
			_listLeft = listLeft,
			_listRight = listRight,
			_name = opts.Name or ("Tab " .. idx),
			_sectionOrder = 0,
			_sectionOrderLeft = 0,
			_sectionOrderRight = 0,
		}, Tab)

		if idx == 1 then
			selectTab(1)
		end

		return tab
	end

	--[[ Section: optional Collapsible, DefaultExpanded, Tooltip; Column "Left"|"Right" when tab uses SplitColumns ]]
	function Tab:AddSection(
		header: string,
		sectionOpts: {
			Collapsible: boolean?,
			DefaultExpanded: boolean?,
			Tooltip: string?,
			Column: string?,
		}?
	)
		sectionOpts = sectionOpts or {}
		local collapsible = sectionOpts.Collapsible ~= false
		local expanded = sectionOpts.DefaultExpanded ~= false

		local parentScroll: ScrollingFrame
		local layoutOrder: number
		if self._split and self._scrollLeft and self._scrollRight then
			local col = sectionOpts.Column
			if col == "Right" then
				parentScroll = self._scrollRight
				self._sectionOrderRight += 1
				layoutOrder = self._sectionOrderRight
			else
				parentScroll = self._scrollLeft
				self._sectionOrderLeft += 1
				layoutOrder = self._sectionOrderLeft
			end
		else
			parentScroll = self._scroll
			self._sectionOrder += 1
			layoutOrder = self._sectionOrder
		end

		local wrap = Instance.new("Frame")
		wrap.Name = "Section_" .. header
		wrap.Size = UDim2.new(1, 0, 0, 0)
		wrap.AutomaticSize = Enum.AutomaticSize.Y
		wrap.BackgroundTransparency = 1
		wrap.LayoutOrder = layoutOrder
		wrap.Parent = parentScroll

		local wrapList = Instance.new("UIListLayout")
		wrapList.FillDirection = Enum.FillDirection.Vertical
		wrapList.SortOrder = Enum.SortOrder.LayoutOrder
		wrapList.Padding = UDim.new(0, 6)
		wrapList.Parent = wrap

		local headerRow: GuiObject
		if collapsible then
			local hb = Instance.new("TextButton")
			hb.Name = "Header"
			hb.Size = UDim2.new(1, 0, 0, 28)
			hb.BackgroundColor3 = Theme.Background
			hb.BackgroundTransparency = 0.2
			hb.Text = ""
			hb.AutoButtonColor = false
			hb.LayoutOrder = 1
			hb.Parent = wrap
			headerRow = hb
		else
			local hf = Instance.new("Frame")
			hf.Name = "Header"
			hf.Size = UDim2.new(1, 0, 0, 28)
			hf.BackgroundColor3 = Theme.Background
			hf.BackgroundTransparency = 0.2
			hf.LayoutOrder = 1
			hf.Parent = wrap
			headerRow = hf
		end
		corner(Theme.CornerSm).Parent = headerRow
		pad(8).Parent = headerRow

		local hLayout = Instance.new("UIListLayout")
		hLayout.FillDirection = Enum.FillDirection.Horizontal
		pcall(function()
			hLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
		end)
		hLayout.SortOrder = Enum.SortOrder.LayoutOrder
		hLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		hLayout.Padding = UDim.new(0, 8)
		hLayout.Parent = headerRow

		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(8, 8)
		dot.BackgroundColor3 = Theme.SectionDot
		dot.LayoutOrder = 0
		dot.Parent = headerRow
		corner(UDim.new(1, 0)).Parent = dot

		local hText = Instance.new("TextLabel")
		hText.Size = UDim2.new(0, 100, 1, 0)
		hText.AutomaticSize = Enum.AutomaticSize.X
		hText.BackgroundTransparency = 1
		hText.Font = Enum.Font.GothamBold
		hText.TextSize = 13
		hText.TextColor3 = Theme.Text
		hText.TextXAlignment = Enum.TextXAlignment.Left
		hText.Text = string.upper(header)
		hText.LayoutOrder = 1
		hText.Parent = headerRow
		local flexGrow = Instance.new("UIFlexItem")
		flexGrow.FlexMode = Enum.UIFlexMode.Grow
		flexGrow.Parent = hText

		local chevImg: ImageLabel? = nil
		local chevGlyph: TextLabel? = nil
		if collapsible then
			local ci = Library:GetIcon("chevron-down")
			if ci and typeof(ci.Url) == "string" and ci.Url ~= "" then
				local img = Instance.new("ImageLabel")
				img.Name = "Chevron"
				img.BackgroundTransparency = 1
				img.Size = UDim2.fromOffset(16, 16)
				img.Image = ci.Url
				img.ImageRectOffset = ci.ImageRectOffset or Vector2.zero
				img.ImageRectSize = ci.ImageRectSize or Vector2.zero
				img.ImageColor3 = Theme.TextDim
				img.LayoutOrder = 2
				img.ScaleType = Enum.ScaleType.Fit
				img.Parent = headerRow
				chevImg = img
			else
				local cg = Instance.new("TextLabel")
				cg.Name = "ChevronGlyph"
				cg.BackgroundTransparency = 1
				cg.Size = UDim2.fromOffset(18, 18)
				cg.Text = "▼"
				cg.TextSize = 12
				cg.Font = Enum.Font.GothamBold
				cg.TextColor3 = Theme.TextDim
				cg.LayoutOrder = 2
				cg.Parent = headerRow
				chevGlyph = cg
			end
		end

		headerRow:SetAttribute("AcidBg", "Background")
		dot:SetAttribute("AcidBg", "SectionDot")
		hText:SetAttribute("AcidText", "Text")
		if chevImg then
			chevImg:SetAttribute("AcidImg", "TextDim")
		end
		if chevGlyph then
			chevGlyph:SetAttribute("AcidText", "TextDim")
		end

		if typeof(sectionOpts.Tooltip) == "string" and sectionOpts.Tooltip ~= "" then
			bindTooltipToInstances({ headerRow, hText }, sectionOpts.Tooltip)
		end

		local bodyF = Instance.new("Frame")
		bodyF.Name = "Body"
		bodyF.Size = UDim2.new(1, 0, 0, 0)
		bodyF.AutomaticSize = Enum.AutomaticSize.Y
		bodyF.BackgroundTransparency = 1
		bodyF.LayoutOrder = 2
		bodyF.Parent = wrap

		local bodyList = Instance.new("UIListLayout")
		bodyList.SortOrder = Enum.SortOrder.LayoutOrder
		bodyList.Padding = UDim.new(0, 10)
		bodyList.Parent = bodyF

		local sectionExpanded = expanded
		local function applySectionExpanded(on: boolean)
			sectionExpanded = on
			if not collapsible then
				return
			end
			bodyF.Visible = on
			if chevImg then
				tween(chevImg, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Rotation = if on then 0 else -90,
				}):Play()
			end
			if chevGlyph then
				chevGlyph.Text = if on then "▼" else "▶"
			end
		end
		if collapsible and headerRow:IsA("TextButton") then
			(headerRow :: TextButton).MouseButton1Click:Connect(function()
				applySectionExpanded(not sectionExpanded)
			end)
		end
		if collapsible then
			if chevImg and not expanded then
				chevImg.Rotation = -90
			end
			if chevGlyph and not expanded then
				chevGlyph.Text = "▶"
			end
			applySectionExpanded(expanded)
		else
			bodyF.Visible = true
		end

		local section = {
			_frame = bodyF,
		}

		function section:AddToggle(o: { Text: string, Default: boolean?, Callback: ((boolean) -> ())?, Tooltip: string?, Idx: string? })
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 32)
			row.Parent = bodyF

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, -54, 1, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamMedium
			label.TextSize = 14
			label.TextColor3 = Theme.Text
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = o.Text
			label:SetAttribute("AcidText", "Text")
			label.Parent = row

			local on = o.Default == true
			local track = Instance.new("TextButton")
			track.AutoButtonColor = false
			track.Size = UDim2.fromOffset(46, 24)
			track.Position = UDim2.new(1, -46, 0.5, -12)
			track.BackgroundColor3 = if on then Theme.ToggleOn else Theme.ToggleOff
			track.Text = ""
			track.Parent = row
			corner(UDim.new(1, 0)).Parent = track

			local knob = Instance.new("Frame")
			knob.Size = UDim2.fromOffset(20, 20)
			knob.Position = if on then UDim2.new(1, -22, 0.5, -10) else UDim2.new(0, 2, 0.5, -10)
			knob.BackgroundColor3 = Color3.new(1, 1, 1)
			knob.Parent = track
			corner(UDim.new(1, 0)).Parent = knob

			table.insert(toggleThemeRows, {
				track = track,
				getOn = function()
					return on
				end,
			})

			local changeCbs: { (boolean) -> () } = {}
			local reg: any = {
				Type = "Toggle",
				Value = on,
			}

			local function apply(v: boolean)
				on = v
				reg.Value = v
				tween(track, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
					BackgroundColor3 = if on then Theme.ToggleOn else Theme.ToggleOff,
				}):Play()
				tween(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
					Position = if on then UDim2.new(1, -22, 0.5, -10) else UDim2.new(0, 2, 0.5, -10),
				}):Play()
				for _, cb in changeCbs do
					task.spawn(cb, on)
				end
				if o.Callback then
					o.Callback(on)
				end
			end

			reg.Set = function(_: any, v: boolean)
				apply(v)
			end
			reg.Get = function()
				return on
			end
			reg.SetValue = reg.Set
			reg.OnChanged = function(_: any, cb: (boolean) -> ())
				table.insert(changeCbs, cb)
			end

			track.MouseButton1Click:Connect(function()
				apply(not on)
			end)

			if typeof(o.Tooltip) == "string" and o.Tooltip ~= "" then
				bindTooltipToInstances({ label, track }, o.Tooltip)
			end

			if typeof(o.Idx) == "string" and o.Idx ~= "" then
				Library.Toggles[o.Idx] = reg
			end

			return reg
		end

		function section:AddSlider(o: {
			Text: string,
			Min: number,
			Max: number,
			Default: number?,
			Rounding: number?,
			Callback: ((number) -> ())?,
			Tooltip: string?,
			Idx: string?,
		})
			local minV, maxV = o.Min, o.Max
			local round = o.Rounding or 0
			local val = math.clamp(o.Default or minV, minV, maxV)

			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 52)
			row.Parent = bodyF

			local top = Instance.new("Frame")
			top.Size = UDim2.new(1, 0, 0, 18)
			top.BackgroundTransparency = 1
			top.Parent = row

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -48, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 13
			lbl.TextColor3 = Theme.Text
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = o.Text
			lbl:SetAttribute("AcidText", "Text")
			lbl.Parent = top

			local valBox = Instance.new("TextBox")
			valBox.Size = UDim2.fromOffset(52, 22)
			valBox.Position = UDim2.new(1, -52, 0, -2)
			valBox.BackgroundColor3 = Theme.Background
			valBox.BackgroundTransparency = 0.15
			valBox.Font = Enum.Font.GothamBold
			valBox.TextSize = 12
			valBox.TextColor3 = Theme.Text
			valBox.Text = tostring(val)
			valBox.ClearTextOnFocus = false
			valBox.TextEditable = true
			valBox.TextXAlignment = Enum.TextXAlignment.Center
			valBox:SetAttribute("AcidBg", "Background")
			valBox:SetAttribute("AcidText", "Text")
			valBox:SetAttribute("AcidPlaceholder", "TextDim")
			valBox.Parent = top
			corner(Theme.CornerSm).Parent = valBox
			pad(4).Parent = valBox
			local valStroke = stroke(Theme.Stroke, 1, 0.65)
			valStroke:SetAttribute("AcidStroke", "Stroke")
			valStroke.Parent = valBox

			local track = Instance.new("Frame")
			track.Name = "Track"
			track.Size = UDim2.new(1, 0, 0, 10)
			track.Position = UDim2.new(0, 0, 0, 32)
			track.BackgroundColor3 = Theme.SliderTrack
			track:SetAttribute("AcidBg", "SliderTrack")
			track.Parent = row
			corner(UDim.new(1, 0)).Parent = track

			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.new((val - minV) / (maxV - minV), 0, 1, 0)
			fill.BackgroundColor3 = Color3.new(1, 1, 1)
			fill.BorderSizePixel = 0
			fill.Parent = track
			corner(UDim.new(1, 0)).Parent = fill
			local grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.AccentPurple),
				ColorSequenceKeypoint.new(1, Theme.AccentBlue),
			})
			grad.Parent = fill
			table.insert(sliderGradients, grad)

			local sliderCbs: { (number) -> () } = {}
			local reg: any = { Type = "Slider", Value = val }

			local function format(n: number): string
				if round <= 0 then
					return tostring(math.floor(n + 0.5))
				end
				local m = 10 ^ round
				return tostring(math.floor(n * m + 0.5) / m)
			end

			local function setFromAlpha(a: number)
				a = math.clamp(a, 0, 1)
				val = minV + (maxV - minV) * a
				if round <= 0 then
					val = math.floor(val + 0.5)
				else
					local m = 10 ^ round
					val = math.floor(val * m + 0.5) / m
				end
				val = math.clamp(val, minV, maxV)
				fill.Size = UDim2.new((val - minV) / (maxV - minV), 0, 1, 0)
				valBox.Text = format(val)
				reg.Value = val
				for _, cb in sliderCbs do
					task.spawn(cb, val)
				end
				if o.Callback then
					o.Callback(val)
				end
			end

			valBox.FocusLost:Connect(function()
				local n = tonumber(valBox.Text)
				if n == nil then
					valBox.Text = format(val)
					return
				end
				n = math.clamp(n, minV, maxV)
				setFromAlpha((n - minV) / math.max(maxV - minV, 1e-9))
			end)

			if typeof(o.Tooltip) == "string" and o.Tooltip ~= "" then
				bindTooltipToInstances({ lbl, valBox, track }, o.Tooltip)
			end

			local dragging = false
			local function posToAlpha(x: number): number
				local ap = track.AbsolutePosition.X
				local aw = track.AbsoluteSize.X
				return (x - ap) / math.max(aw, 1)
			end

			track.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					dragging = true
					setFromAlpha(posToAlpha(input.Position.X))
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					dragging = false
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if not dragging then
					return
				end
				if
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				then
					setFromAlpha(posToAlpha(input.Position.X))
				end
			end)

			reg.Set = function(_: any, n: number)
				n = math.clamp(n, minV, maxV)
				setFromAlpha((n - minV) / math.max(maxV - minV, 1e-9))
			end
			reg.Get = function()
				return val
			end
			reg.SetValue = function(_: any, v: any)
				local n = tonumber(v)
				if n == nil then
					return
				end
				reg.Set(nil, n)
			end
			reg.OnChanged = function(_: any, cb: (number) -> ())
				table.insert(sliderCbs, cb)
			end

			if typeof(o.Idx) == "string" and o.Idx ~= "" then
				Library.Options[o.Idx] = reg
			end

			return reg
		end

		function section:AddDropdown(o: {
			Text: string,
			Options: { string },
			Multi: boolean?,
			Default: any?,
			Callback: ((any) -> ())?,
			Tooltip: string?,
			AllowNull: boolean?,
			Idx: string?,
		})
			local allowNull = o.AllowNull == true
			local multi = o.Multi == true
			local options = o.Options or {}
			local selected: { [string]: boolean } = {}
			if multi then
				if type(o.Default) == "table" then
					for _, s in o.Default :: { string } do
						selected[s] = true
					end
				end
			elseif type(o.Default) == "string" then
				selected[o.Default :: string] = true
			elseif typeof(o.Default) == "number" and not multi and #options > 0 then
				local i = math.clamp(math.floor(o.Default :: number), 1, #options)
				selected[options[i]] = true
			elseif not allowNull and #options > 0 then
				selected[options[1]] = true
			end

			local function computeValue(): any
				if multi then
					local out = {}
					for _, opt in options do
						if selected[opt] then
							table.insert(out, opt)
						end
					end
					return out
				end
				for k in pairs(selected) do
					return k
				end
				return nil
			end

			local function summary(): string
				if multi then
					local parts = {}
					for _, opt in options do
						if selected[opt] then
							table.insert(parts, opt)
						end
					end
					if #parts == 0 then
						return "Select…"
					end
					return table.concat(parts, ", ")
				end
				for k in pairs(selected) do
					return k
				end
				return if allowNull then "None" else "Select…"
			end

			local dropdownCbs: { (any) -> () } = {}
			local reg: any = {
				Type = "Dropdown",
				Multi = multi,
				Value = computeValue(),
			}

			local function syncReg()
				reg.Value = computeValue()
			end

			local function fire()
				syncReg()
				local v = reg.Value
				for _, cb in dropdownCbs do
					task.spawn(cb, v)
				end
				if o.Callback then
					o.Callback(v)
				end
			end

			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 0)
			row.AutomaticSize = Enum.AutomaticSize.Y
			row.ZIndex = 2
			row.Parent = bodyF

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 0, 16)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 12
			lbl.TextColor3 = Theme.TextDim
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = o.Text
			lbl:SetAttribute("AcidText", "TextDim")
			lbl.Parent = row

			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, 34)
			btn.Position = UDim2.new(0, 0, 0, 20)
			btn.BackgroundColor3 = Theme.Elevated
			btn.BackgroundTransparency = 0.1
			btn.AutoButtonColor = false
			btn.Font = Enum.Font.GothamMedium
			btn.TextSize = 13
			btn.TextColor3 = Theme.Text
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.Text = "  " .. summary()
			btn:SetAttribute("AcidBg", "Elevated")
			btn:SetAttribute("AcidText", "Text")
			btn.Parent = row
			corner(Theme.CornerSm).Parent = btn
			pad(10).Parent = btn

			local chev = Instance.new("TextLabel")
			chev.Size = UDim2.fromOffset(24, 24)
			chev.Position = UDim2.new(1, -28, 0.5, -12)
			chev.BackgroundTransparency = 1
			chev.Text = "▼"
			chev.TextSize = 10
			chev.TextColor3 = Theme.TextDim
			chev:SetAttribute("AcidText", "TextDim")
			chev.Parent = btn

			local listF = Instance.new("Frame")
			listF.Size = UDim2.new(1, 0, 0, 0)
			listF.AutomaticSize = Enum.AutomaticSize.Y
			listF.Position = UDim2.new(0, 0, 0, 56)
			listF.BackgroundColor3 = Theme.Background
			listF.BackgroundTransparency = 0.05
			listF.Visible = false
			listF.ZIndex = 5
			listF:SetAttribute("AcidBg", "Background")
			listF.Parent = row
			corner(Theme.CornerSm).Parent = listF
			local listStroke = stroke(Theme.Stroke, 1, 0.7)
			listStroke:SetAttribute("AcidStroke", "Stroke")
			listStroke.Parent = listF

			local innerList = Instance.new("UIListLayout")
			innerList.SortOrder = Enum.SortOrder.LayoutOrder
			innerList.Padding = UDim.new(0, 2)
			innerList.Parent = listF
			pad(6).Parent = listF

			local open = false
			local optionButtonMap: { [string]: TextButton } = {}

			local function styleOptionRow(optBtn: TextButton, optName: string)
				local sel = selected[optName] == true
				optBtn.Text = optName
				optBtn.BackgroundColor3 = Theme.Elevated
				optBtn.TextColor3 = Theme.Text
				if sel then
					optBtn.BackgroundTransparency = 0.08
					optBtn.TextTransparency = 0
				else
					optBtn.BackgroundTransparency = 1
					optBtn.TextTransparency = 0.45
				end
			end

			local function refreshOptionVisuals()
				for optName, ob in optionButtonMap do
					if ob.Parent then
						styleOptionRow(ob, optName)
					end
				end
				btn.Text = "  " .. summary()
			end

			local function clearOptionButtons()
				table.clear(optionButtonMap)
				for _, ch in listF:GetChildren() do
					if ch:IsA("TextButton") then
						ch:Destroy()
					end
				end
			end

			local function buildOptionButtons()
				clearOptionButtons()
				for _, opt in options do
					local optBtn = Instance.new("TextButton")
					optBtn.Size = UDim2.new(1, -12, 0, 28)
					optBtn.AutoButtonColor = false
					optBtn.Font = Enum.Font.GothamMedium
					optBtn.TextSize = 12
					optBtn.TextXAlignment = Enum.TextXAlignment.Left
					optBtn.ZIndex = 6
					optBtn:SetAttribute("AcidBg", "Elevated")
					optBtn:SetAttribute("AcidText", "Text")
					optBtn.Parent = listF
					corner(UDim.new(0, 4)).Parent = optBtn
					pad(8).Parent = optBtn
					optionButtonMap[opt] = optBtn
					styleOptionRow(optBtn, opt)
					optBtn.MouseButton1Click:Connect(function()
						if multi then
							selected[opt] = not selected[opt]
							for optName, ob in optionButtonMap do
								styleOptionRow(ob, optName)
							end
						else
							for k in pairs(selected) do
								selected[k] = nil
							end
							selected[opt] = true
							for optName, ob in optionButtonMap do
								styleOptionRow(ob, optName)
							end
							listF.Visible = false
							open = false
						end
						btn.Text = "  " .. summary()
						fire()
					end)
				end
			end

			buildOptionButtons()

			btn.MouseButton1Click:Connect(function()
				open = not open
				listF.Visible = open
			end)

			if typeof(o.Tooltip) == "string" and o.Tooltip ~= "" then
				bindTooltipToInstances({ lbl, btn }, o.Tooltip)
			end

			btn.Text = "  " .. summary()
			syncReg()

			reg.Set = function(_: any, v: any)
				for k in pairs(selected) do
					selected[k] = nil
				end
				if multi and type(v) == "table" then
					for _, s in v do
						if typeof(s) == "string" then
							selected[s] = true
						end
					end
				elseif not multi and v == nil and allowNull then
					-- cleared
				elseif not multi and type(v) == "string" then
					selected[v] = true
				end
				refreshOptionVisuals()
				syncReg()
			end
			reg.SetValue = reg.Set
			reg.Get = function()
				return computeValue()
			end
			reg.OnChanged = function(_: any, cb: (any) -> ())
				table.insert(dropdownCbs, cb)
			end
			reg.SetValues = function(_: any, newOpts: { string })
				options = newOpts or {}
				for k in pairs(selected) do
					selected[k] = nil
				end
				if not multi then
					if allowNull then
						-- none
					elseif #options > 0 then
						selected[options[1]] = true
					end
				else
					-- keep empty until user picks
				end
				buildOptionButtons()
				refreshOptionVisuals()
				syncReg()
			end

			if typeof(o.Idx) == "string" and o.Idx ~= "" then
				Library.Options[o.Idx] = reg
			end

			return reg
		end

		function section:AddInput(o: {
			Text: string,
			Placeholder: string?,
			Default: string?,
			Callback: ((string) -> ())?,
			Tooltip: string?,
			Idx: string?,
		})
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 52)
			row.Parent = bodyF

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 0, 16)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 12
			lbl.TextColor3 = Theme.TextDim
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = o.Text
			lbl:SetAttribute("AcidText", "TextDim")
			lbl.Parent = row

			local box = Instance.new("TextBox")
			box.Size = UDim2.new(1, 0, 0, 32)
			box.Position = UDim2.new(0, 0, 0, 22)
			box.BackgroundColor3 = Theme.Elevated
			box.BackgroundTransparency = 0.1
			box.ClearTextOnFocus = false
			box.Font = Enum.Font.GothamMedium
			box.TextSize = 13
			box.TextColor3 = Theme.Text
			box.PlaceholderText = o.Placeholder or ""
			box.PlaceholderColor3 = Theme.TextDim
			box.Text = o.Default or ""
			box:SetAttribute("AcidBg", "Elevated")
			box:SetAttribute("AcidText", "Text")
			box:SetAttribute("AcidPlaceholder", "TextDim")
			box.Parent = row
			corner(Theme.CornerSm).Parent = box
			pad(10).Parent = box

			local inputCbs: { (string) -> () } = {}
			local reg: any = { Type = "Input", Value = box.Text }

			local function sync()
				reg.Value = box.Text
			end

			box.FocusLost:Connect(function()
				sync()
				for _, cb in inputCbs do
					task.spawn(cb, box.Text)
				end
				if o.Callback then
					o.Callback(box.Text)
				end
			end)

			if typeof(o.Tooltip) == "string" and o.Tooltip ~= "" then
				bindTooltipToInstances({ lbl, box }, o.Tooltip)
			end

			reg.Set = function(_: any, t: string)
				box.Text = t
				sync()
			end
			reg.SetValue = reg.Set
			reg.Get = function()
				return box.Text
			end
			reg.OnChanged = function(_: any, cb: (string) -> ())
				table.insert(inputCbs, cb)
			end

			if typeof(o.Idx) == "string" and o.Idx ~= "" then
				Library.Options[o.Idx] = reg
			end

			return reg
		end

		function section:AddDivider()
			local d = Instance.new("Frame")
			d.BackgroundColor3 = Theme.Stroke
			d.BackgroundTransparency = 0.5
			d.BorderSizePixel = 0
			d.Size = UDim2.new(1, 0, 0, 1)
			d:SetAttribute("AcidBg", "Stroke")
			d.Parent = bodyF
		end

		function section:AddLabel(textOrOpts: any, wrap: boolean?, idx: string?)
			local text = ""
			local doesWrap = wrap == true
			local idxStr: string? = nil
			if type(textOrOpts) == "table" then
				text = tostring(textOrOpts.Text or "")
				doesWrap = textOrOpts.DoesWrap == true
				idxStr = textOrOpts.Idx
			else
				text = tostring(textOrOpts)
				idxStr = if typeof(idx) == "string" then idx else nil
			end
			local lab = Instance.new("TextLabel")
			lab.BackgroundTransparency = 1
			lab.Font = Enum.Font.GothamMedium
			lab.TextSize = 13
			lab.TextColor3 = Theme.TextDim
			lab.TextXAlignment = Enum.TextXAlignment.Left
			lab.TextWrapped = doesWrap
			lab.AutomaticSize = if doesWrap then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
			lab.Size = UDim2.new(1, 0, 0, if doesWrap then 0 else 18)
			lab.Text = text
			lab:SetAttribute("AcidText", "TextDim")
			lab.Parent = bodyF
			local reg = {
				SetText = function(_: any, t: string)
					lab.Text = t
				end,
			}
			reg.Set = reg.SetText
			if typeof(idxStr) == "string" and idxStr ~= "" then
				Library.Options[idxStr] = reg
			end
			return reg
		end

		function section:AddButton(opts: any, func: (() -> ())?)
			local text: string
			local fn: (() -> ())?
			local disabled = false
			local tip: string? = nil
			if type(opts) == "table" then
				text = tostring(opts.Text or "Button")
				fn = opts.Func
				disabled = opts.Disabled == true
				tip = opts.Tooltip
			else
				text = tostring(opts)
				fn = func
			end
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, 34)
			b.BackgroundColor3 = Theme.Elevated
			b.BackgroundTransparency = 0.1
			b.AutoButtonColor = not disabled
			b.Text = text
			b.Font = Enum.Font.GothamMedium
			b.TextSize = 13
			b.TextColor3 = if disabled then Theme.TextDim else Theme.Text
			b:SetAttribute("AcidBg", "Elevated")
			b:SetAttribute("AcidText", if disabled then "TextDim" else "Text")
			b.Parent = bodyF
			corner(Theme.CornerSm).Parent = b
			if typeof(tip) == "string" and tip ~= "" then
				bindTooltipToInstances({ b }, tip)
			end
			b.MouseButton1Click:Connect(function()
				if disabled then
					return
				end
				if fn then
					fn()
				end
			end)
			return b
		end

		function section:AddKeybind(o: {
			Text: string,
			Default: string?,
			Idx: string?,
			NoUI: boolean?,
		})
			o = o or {}
			local keyName = o.Default or "RightShift"
			local kc = Enum.KeyCode[keyName] or Enum.KeyCode.RightShift
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 34)
			row.Parent = bodyF
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -120, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 13
			lbl.TextColor3 = Theme.Text
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = o.Text or "Keybind"
			lbl:SetAttribute("AcidText", "Text")
			lbl.Parent = row
			local capBtn = Instance.new("TextButton")
			capBtn.Size = UDim2.fromOffset(112, 28)
			capBtn.Position = UDim2.new(1, -112, 0.5, -14)
			capBtn.BackgroundColor3 = Theme.Background
			capBtn.BackgroundTransparency = 0.15
			capBtn.Text = keyName
			capBtn.Font = Enum.Font.GothamBold
			capBtn.TextSize = 12
			capBtn.TextColor3 = Theme.Text
			capBtn.AutoButtonColor = false
			capBtn:SetAttribute("AcidBg", "Background")
			capBtn:SetAttribute("AcidText", "Text")
			capBtn.Parent = row
			corner(Theme.CornerSm).Parent = capBtn

			local listening = false
			local keyCbs: { () -> () } = {}
			local reg: any = {
				Type = "KeyPicker",
				Value = kc,
				Mode = "Toggle",
				Modifiers = {},
			}

			local function applyKey(newK: Enum.KeyCode, name: string)
				kc = newK
				keyName = name
				reg.Value = kc
				capBtn.Text = name
				for _, cb in keyCbs do
					task.spawn(cb)
				end
			end

			reg.SetValue = function(_: any, v: any)
				if type(v) == "table" and typeof(v[1]) == "string" then
					local nm = v[1]
					local nk = Enum.KeyCode[nm]
					if nk then
						applyKey(nk, nm)
					end
				end
			end
			reg.OnChanged = function(_: any, cb: () -> ())
				table.insert(keyCbs, cb)
			end

			local capConn: RBXScriptConnection? = nil
			capBtn.MouseButton1Click:Connect(function()
				if listening then
					return
				end
				listening = true
				capBtn.Text = "…"
				if capConn then
					capConn:Disconnect()
				end
				capConn = UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
					if gp then
						return
					end
					if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
						if capConn then
							capConn:Disconnect()
							capConn = nil
						end
						listening = false
						applyKey(input.KeyCode, input.KeyCode.Name)
						if o.Idx == "MenuKeybind" or o.NoUI then
							Library.ToggleKeybind = reg
						end
					end
				end)
			end)

			if o.Idx == "MenuKeybind" or o.NoUI then
				Library.ToggleKeybind = reg
			end
			if typeof(o.Idx) == "string" and o.Idx ~= "" then
				Library.Options[o.Idx] = reg
			end

			return reg
		end

		function section:AddColorPicker(o: {
			Text: string,
			Default: Color3?,
			Transparency: number?,
			Idx: string?,
			Callback: ((Color3) -> ())?,
		})
			o = o or {}
			local col = o.Default or Color3.fromRGB(255, 255, 255)
			local alpha = 1 - (o.Transparency or 0)

			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 52)
			row.Parent = bodyF

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -120, 0, 16)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 12
			lbl.TextColor3 = Theme.TextDim
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = o.Text or "Color"
			lbl:SetAttribute("AcidText", "TextDim")
			lbl.Parent = row

			local swatch = Instance.new("Frame")
			swatch.Size = UDim2.fromOffset(36, 28)
			swatch.Position = UDim2.new(1, -120, 0, 22)
			swatch.BackgroundColor3 = col
			swatch.BackgroundTransparency = 1 - alpha
			swatch.BorderSizePixel = 0
			swatch.Parent = row
			corner(Theme.CornerSm).Parent = swatch
			stroke(Theme.Stroke, 1, 0.5).Parent = swatch

			local hexBox = Instance.new("TextBox")
			hexBox.Size = UDim2.new(1, -130, 0, 28)
			hexBox.Position = UDim2.new(0, 0, 0, 22)
			hexBox.BackgroundColor3 = Theme.Elevated
			hexBox.BackgroundTransparency = 0.1
			hexBox.Text = string.upper(col:ToHex())
			hexBox.Font = Enum.Font.GothamMedium
			hexBox.TextSize = 12
			hexBox.TextColor3 = Theme.Text
			hexBox.ClearTextOnFocus = false
			hexBox:SetAttribute("AcidBg", "Elevated")
			hexBox:SetAttribute("AcidText", "Text")
			hexBox.Parent = row
			corner(Theme.CornerSm).Parent = hexBox
			pad(6).Parent = hexBox

			local colorCbs: { (Color3) -> () } = {}
			local reg: any = {
				Type = "ColorPicker",
				Value = col,
				Transparency = o.Transparency or 0,
			}

			local function applyColor(c: Color3)
				col = c
				reg.Value = col
				swatch.BackgroundColor3 = col
				hexBox.Text = string.upper(c:ToHex())
				for _, cb in colorCbs do
					task.spawn(cb, col)
				end
				if o.Callback then
					o.Callback(col)
				end
			end

			hexBox.FocusLost:Connect(function()
				local h = hexBox.Text:gsub("#", ""):gsub("%s", "")
				local ok, parsed = pcall(Color3.fromHex, h)
				if ok and typeof(parsed) == "Color3" then
					applyColor(parsed)
				else
					hexBox.Text = string.upper(col:ToHex())
				end
			end)

			reg.SetValueRGB = function(_: any, c: Color3, trans: number?)
				col = c
				reg.Value = col
				if typeof(trans) == "number" then
					reg.Transparency = trans
					swatch.BackgroundTransparency = trans
					alpha = 1 - trans
				else
					swatch.BackgroundTransparency = 1 - alpha
				end
				swatch.BackgroundColor3 = col
				hexBox.Text = string.upper(col:ToHex())
			end
			reg.SetValue = reg.SetValueRGB
			reg.OnChanged = function(_: any, cb: (Color3) -> ())
				table.insert(colorCbs, cb)
			end

			if typeof(o.Idx) == "string" and o.Idx ~= "" then
				Library.Options[o.Idx] = reg
			end

			return reg
		end

		return section
	end

	function Tab:AddLeftGroupbox(
		header: string,
		sectionOpts: { Collapsible: boolean?, DefaultExpanded: boolean?, Tooltip: string? }?
	)
		local o: any = if sectionOpts then table.clone(sectionOpts) else {}
		if self._split then
			o.Column = "Left"
		end
		return Tab.AddSection(self, header, o)
	end

	function Tab:AddRightGroupbox(
		header: string,
		sectionOpts: { Collapsible: boolean?, DefaultExpanded: boolean?, Tooltip: string? }?
	)
		local o: any = if sectionOpts then table.clone(sectionOpts) else {}
		if self._split then
			o.Column = "Right"
		end
		return Tab.AddSection(self, header, o)
	end

	return window
end

return Library
