
local cloneref = (cloneref or clonereference or function(instance: any)
	return instance
end)
local CoreGui = cloneref(game:GetService("CoreGui"))
local Players = cloneref(game:GetService("Players"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService = cloneref(game:GetService("TweenService"))

local protectgui = protectgui or (syn and syn.protect_gui) or function() end
local gethui = gethui or function()
	return CoreGui
end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- ----------------------------------------------------------------------------- theme
local Theme = {
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

-- ----------------------------------------------------------------------------- Lucide ([lucide.dev](https://lucide.dev) — executor loads sprite module like Obsidian)
local LUCIDE_ROBLOX_DIRECT =
	"https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua"

local loadchunk = loadstring or load

local Library = {}

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

	--[[ MainPanel: single rim via PanelOutline (UIStroke) on the face — no extra halo frames ]]
	local mainPanel = Instance.new("Frame")
	mainPanel.Name = "MainPanel"
	mainPanel.Size = UDim2.new(1, -62, 1, 0)
	mainPanel.LayoutOrder = 1
	mainPanel.BackgroundTransparency = 1
	mainPanel.BorderSizePixel = 0
	mainPanel.ClipsDescendants = false
	mainPanel.Parent = body

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
	local tabScrolls: { ScrollingFrame } = {}
	local activeTab = 0

	local function selectTab(index: number)
		activeTab = index
		for i, btn in tabButtons do
			local isSel = (i == index)
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
		rh.ZIndex = 50
		rh.Parent = root
		local resizeIcon = Library:GetIcon("move-diagonal-2")
		if resizeIcon then
			local ig = Instance.new("ImageLabel")
			ig.Name = "ResizeIcon"
			ig.BackgroundTransparency = 1
			ig.Size = UDim2.new(1, -6, 1, -6)
			ig.Position = UDim2.fromOffset(3, 3)
			ig.ScaleType = Enum.ScaleType.Fit
			ig.Image = resizeIcon.Url
			ig.ImageRectOffset = resizeIcon.ImageRectOffset or Vector2.zero
			ig.ImageRectSize = resizeIcon.ImageRectSize or Vector2.zero
			ig.ImageColor3 = Theme.TextDim
			ig.ImageTransparency = 0.42
			ig.ZIndex = 51
			ig.Parent = rh
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

	-- dragging + resize
	local dragConn: { RBXScriptConnection } = {}
	local function beginDrag()
		local dragging = false
		local resizing = false
		local dragStart: Vector2
		local startPos: UDim2
		local resizeStart: Vector2
		local resizeStartSize: Vector2

		local function overResize(p: Vector3): boolean
			if not resizeHandle or not resizeHandle.Visible then
				return false
			end
			local ap = resizeHandle.AbsolutePosition
			local as = resizeHandle.AbsoluteSize
			return p.X >= ap.X and p.X <= ap.X + as.X and p.Y >= ap.Y and p.Y <= ap.Y + as.Y
		end

		local function inputBegan(input: InputObject, gp: boolean)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local p = input.Position
			--[[ Resize before gameProcessed — otherwise movement is swallowed while dragging size ]]
			if overResize(p) then
				resizing = true
				resizeStart = Vector2.new(p.X, p.Y)
				resizeStartSize = Vector2.new(root.AbsoluteSize.X, root.AbsoluteSize.Y)
				return
			end
			if gp then
				return
			end
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
			--[[ After drag/resize start, ignore gameProcessed so movement isn't eaten by the game ]]
			if not dragging and gp then
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

	function window:Destroy()
		for _, c in dragConn do
			c:Disconnect()
		end
		screenGui:Destroy()
	end

	function window:SetTitle(t: string)
		panelTitle.Text = t
	end

	function window:SetSubtitle(t: string)
		subtitle.Text = t
	end

	-- Tab API
	local Tab = {}
	Tab.__index = Tab

	function window:AddTab(opts: { Name: string?, Icon: string? })
		opts = opts or {}
		local idx = #tabScrolls + 1
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

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "TabContent_" .. idx
		scroll.Size = UDim2.fromScale(1, 1)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 4
		scroll.ScrollBarImageColor3 = Theme.AccentBlue
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.Visible = (idx == 1)
		scroll.Parent = contentHost

		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 12)
		list.Parent = scroll

		local padScroll = Instance.new("UIPadding")
		padScroll.PaddingLeft = UDim.new(0, 14)
		padScroll.PaddingRight = UDim.new(0, 14)
		padScroll.PaddingTop = UDim.new(0, 8)
		padScroll.PaddingBottom = UDim.new(0, 20)
		padScroll.Parent = scroll

		table.insert(tabButtons, btn)
		table.insert(tabScrolls, scroll)

		local tab = setmetatable({
			_scroll = scroll,
			_list = list,
			_name = opts.Name or ("Tab " .. idx),
			_sectionOrder = 0,
		}, Tab)

		if idx == 1 then
			selectTab(1)
		end

		return tab
	end

	-- Section
	function Tab:AddSection(header: string)
		self._sectionOrder += 1
		local wrap = Instance.new("Frame")
		wrap.Name = "Section_" .. header
		wrap.Size = UDim2.new(1, 0, 0, 0)
		wrap.AutomaticSize = Enum.AutomaticSize.Y
		wrap.BackgroundTransparency = 1
		wrap.LayoutOrder = self._sectionOrder
		wrap.Parent = self._scroll

		local headerRow = Instance.new("Frame")
		headerRow.Name = "Header"
		headerRow.Size = UDim2.new(1, 0, 0, 28)
		headerRow.BackgroundColor3 = Theme.Background
		headerRow.BackgroundTransparency = 0.2
		headerRow.Parent = wrap
		corner(Theme.CornerSm).Parent = headerRow
		pad(8).Parent = headerRow

		local hLayout = Instance.new("UIListLayout")
		hLayout.FillDirection = Enum.FillDirection.Horizontal
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
		hText.Size = UDim2.new(1, -16, 1, 0)
		hText.BackgroundTransparency = 1
		hText.Font = Enum.Font.GothamBold
		hText.TextSize = 13
		hText.TextColor3 = Theme.Text
		hText.TextXAlignment = Enum.TextXAlignment.Left
		hText.Text = string.upper(header)
		hText.LayoutOrder = 1
		hText.Parent = headerRow

		local bodyF = Instance.new("Frame")
		bodyF.Name = "Body"
		bodyF.Position = UDim2.new(0, 0, 0, 34)
		bodyF.Size = UDim2.new(1, 0, 0, 0)
		bodyF.AutomaticSize = Enum.AutomaticSize.Y
		bodyF.BackgroundTransparency = 1
		bodyF.Parent = wrap

		local bodyList = Instance.new("UIListLayout")
		bodyList.SortOrder = Enum.SortOrder.LayoutOrder
		bodyList.Padding = UDim.new(0, 10)
		bodyList.Parent = bodyF

		local section = {
			_frame = bodyF,
		}

		function section:AddToggle(o: { Text: string, Default: boolean?, Callback: ((boolean) -> ())? })
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

			local function apply(v: boolean)
				on = v
				tween(track, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
					BackgroundColor3 = if on then Theme.ToggleOn else Theme.ToggleOff,
				}):Play()
				tween(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
					Position = if on then UDim2.new(1, -22, 0.5, -10) else UDim2.new(0, 2, 0.5, -10),
				}):Play()
				if o.Callback then
					o.Callback(on)
				end
			end

			track.MouseButton1Click:Connect(function()
				apply(not on)
			end)

			return { Set = function(_: any, v: boolean) apply(v) end, Get = function() return on end }
		end

		function section:AddSlider(o: {
			Text: string,
			Min: number,
			Max: number,
			Default: number?,
			Rounding: number?,
			Callback: ((number) -> ())?,
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
			lbl.Parent = top

			local valBox = Instance.new("TextLabel")
			valBox.Size = UDim2.fromOffset(44, 22)
			valBox.Position = UDim2.new(1, -44, 0, -2)
			valBox.BackgroundColor3 = Theme.Background
			valBox.BackgroundTransparency = 0.15
			valBox.Font = Enum.Font.GothamBold
			valBox.TextSize = 12
			valBox.TextColor3 = Theme.Text
			valBox.Text = tostring(val)
			valBox.Parent = top
			corner(Theme.CornerSm).Parent = valBox

			local track = Instance.new("Frame")
			track.Name = "Track"
			track.Size = UDim2.new(1, 0, 0, 10)
			track.Position = UDim2.new(0, 0, 0, 32)
			track.BackgroundColor3 = Theme.SliderTrack
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
				if o.Callback then
					o.Callback(val)
				end
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

			return {
				Set = function(_: any, n: number)
					n = math.clamp(n, minV, maxV)
					setFromAlpha((n - minV) / (maxV - minV))
				end,
				Get = function()
					return val
				end,
			}
		end

		function section:AddDropdown(o: {
			Text: string,
			Options: { string },
			Multi: boolean?,
			Default: any?,
			Callback: ((any) -> ())?,
		})
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
			elseif #options > 0 then
				selected[options[1]] = true
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
				return "Select…"
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
			chev.Parent = btn

			local listF = Instance.new("Frame")
			listF.Size = UDim2.new(1, 0, 0, 0)
			listF.AutomaticSize = Enum.AutomaticSize.Y
			listF.Position = UDim2.new(0, 0, 0, 56)
			listF.BackgroundColor3 = Theme.Background
			listF.BackgroundTransparency = 0.05
			listF.Visible = false
			listF.ZIndex = 5
			listF.Parent = row
			corner(Theme.CornerSm).Parent = listF

			local innerList = Instance.new("UIListLayout")
			innerList.SortOrder = Enum.SortOrder.LayoutOrder
			innerList.Padding = UDim.new(0, 2)
			innerList.Parent = listF
			pad(6).Parent = listF

			local open = false
			local function fire()
				if multi then
					local out = {}
					for _, opt in options do
						if selected[opt] then
							table.insert(out, opt)
						end
					end
					if o.Callback then
						o.Callback(out)
					end
				else
					for k in pairs(selected) do
						if o.Callback then
							o.Callback(k)
						end
						break
					end
				end
			end

			for _, opt in options do
				local optBtn = Instance.new("TextButton")
				optBtn.Size = UDim2.new(1, -12, 0, 28)
				optBtn.BackgroundColor3 = Theme.Elevated
				optBtn.BackgroundTransparency = 0.4
				optBtn.AutoButtonColor = false
				optBtn.Text = (if multi and selected[opt] then "☑ " else "☐ ") .. opt
				optBtn.Font = Enum.Font.GothamMedium
				optBtn.TextSize = 12
				optBtn.TextColor3 = Theme.Text
				optBtn.TextXAlignment = Enum.TextXAlignment.Left
				optBtn.ZIndex = 6
				optBtn.Parent = listF
				corner(UDim.new(0, 4)).Parent = optBtn
				optBtn.MouseButton1Click:Connect(function()
					if multi then
						selected[opt] = not selected[opt]
						optBtn.Text = (if selected[opt] then "☑ " else "☐ ") .. opt
					else
						for _, child in listF:GetChildren() do
							if child:IsA("TextButton") then
								local t = child.Text
								local name = t:gsub("^[☑☐] ", "")
								child.Text = "☐ " .. name
							end
						end
						for k in pairs(selected) do
							selected[k] = nil
						end
						selected[opt] = true
						optBtn.Text = "☑ " .. opt
						listF.Visible = false
						open = false
					end
					btn.Text = "  " .. summary()
					fire()
				end)
			end

			btn.MouseButton1Click:Connect(function()
				open = not open
				listF.Visible = open
			end)

			btn.Text = "  " .. summary()
			return {
				Set = function(_: any, v: any)
					for k in pairs(selected) do
						selected[k] = nil
					end
					if multi and type(v) == "table" then
						for _, s in v do
							selected[s] = true
						end
					elseif not multi and type(v) == "string" then
						selected[v] = true
					end
					btn.Text = "  " .. summary()
					for _, child in listF:GetChildren() do
						if child:IsA("TextButton") then
							local name = child.Text:gsub("^[☑☐] ", "")
							child.Text = (if selected[name] then "☑ " else "☐ ") .. name
						end
					end
				end,
			}
		end

		function section:AddInput(o: { Text: string, Placeholder: string?, Default: string?, Callback: ((string) -> ())? })
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
			box.Parent = row
			corner(Theme.CornerSm).Parent = box
			pad(10).Parent = box

			box.FocusLost:Connect(function()
				if o.Callback then
					o.Callback(box.Text)
				end
			end)

			return {
				Set = function(_: any, t: string)
					box.Text = t
				end,
				Get = function()
					return box.Text
				end,
			}
		end

		return section
	end

	return window
end

return Library
