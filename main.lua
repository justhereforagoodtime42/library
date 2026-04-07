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
--[[ Obsidian-style: PlayerMouse matches GuiObject.AbsolutePosition better than GetMouseLocation on some clients. ]]
local PlayerMouse = LocalPlayer:GetMouse()

-- ----------------------------------------------------------------------------- theme (mutable; ThemeManager / RefreshTheme)
local Library = {}

Library.Theme = {
	Background = Color3.new(0, 0, 0),
	Panel = Color3.new(0, 0, 0),
	--[[ Main panel + scroll columns; 0 = fully opaque (Obsidian-style solid UI) ]]
	PanelTrans = 0,
	--[[ Groupbox shell fill — panel washed with accent (recomputed after AccentBlue is set below) ]]
	Groupbox = Color3.new(0, 0, 0),
	--[[ Section wrap transparency; lower = more solid accent tint on the box ]]
	GroupboxTrans = 0.68,
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
Theme.Groupbox = Theme.Panel:Lerp(Theme.AccentBlue, 0.16)

----------------------------------------------------------------------------- helpers (must be above Library:Notify — it uses corner/stroke)
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

--[[ Section / groupbox widget density (Obsidian-style: ~14px text, ~18–21px controls) ]]
local UID = {
	SectionHeaderH = 26,
	SectionOuterPad = 6,
	SectionHeaderInnerPad = 6,
	SectionIcon = 16,
	SectionTitle = 12,
	BodyListPad = 8,
	Chevron = 14,
	--
	ToggleRowH = 20,
	ToggleTrackW = 32,
	ToggleTrackH = 16,
	ToggleKnob = 12,
	ToggleLabelReserve = 38,
	--[[ Inline keybind cap (Obsidian-style), sits between label and toggle track ]]
	ToggleInlineKeyW = 52,
	ToggleInlineKeyH = 18,
	ToggleInlineKeyGap = 6,
	--[[ Inline color swatch on toggle row (same band as key cap) ]]
	ToggleInlineColorW = 18,
	ToggleInlineColorH = 18,
	FontWidget = 14,
	--
	SliderRowH = 34,
	SliderTopH = 14,
	SliderValW = 44,
	SliderValH = 18,
	SliderTrackY = 22,
	SliderTrackH = 8,
	SliderLblText = 13,
	SliderValText = 12,
	--
	DropLblH = 14,
	DropBtnH = 21,
	DropBtnY = 15,
	DropListY = 37,
	DropBtnPad = 7,
	DropBtnText = 13,
	DropOptRow = 21,
	DropSearchH = 24,
	DropChev = 14,
	--
	InputRowH = 40,
	InputLblH = 14,
	InputBoxH = 21,
	InputBoxY = 15,
	InputBoxPad = 7,
	InputLblText = 12,
	InputBoxText = 13,
	--
	ButtonH = 21,
	KeyRowH = 30,
	KeyCapW = 100,
	KeyCapH = 22,
	AddLabelH = 16,
	AddLabelText = 13,
	--
	ColorRowH = 38,
	ColorLblH = 14,
	ColorBarH = 21,
	ColorBarY = 15,
	ColorSwatch = 34,
	--
	TabboxStripH = 28,
	TabboxBtnH = 20,
	TabboxBtnText = 12,
}

Library.Toggles = {} :: { [string]: any }
Library.Options = {} :: { [string]: any }
--[[ When true, AddDropdown uses Multi = true unless the option explicitly sets Multi = false ]]
Library.MultiDropdownByDefault = false
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
--[[ Per-toast refresh callbacks so notifications follow Library.Theme after ThemeManager:ApplyTheme ]]
Library._notifyThemeRefreshes = {} :: { () -> () }
Library._libFocusConn = nil :: RBXScriptConnection?
Library._libFocusReleasedConn = nil :: RBXScriptConnection?

--[[ Theme paint cache: instances tagged with Ui* attrs; rebuilt on descendant changes (no full GetDescendants each RefreshTheme). ]]
Library._themePaintHost = nil :: Instance?
Library._themePaintValid = false
Library._themePaintTagged = {} :: { { any } }
Library._themePaintGroupbox = {} :: { Frame }
Library._themePaintDropdownScroll = {} :: { ScrollingFrame }
Library._themePaintSubConns = {} :: { RBXScriptConnection }

--[[ Mobile / focus (Obsidian-style): touch clients, floating controls, drag lock ]]
Library.IsMobile = false
Library.DevicePlatform = nil :: Enum.Platform?
Library.IsRobloxFocused = true
Library.CantDragForced = false

do
	if RunService:IsStudio() then
		Library.IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	else
		pcall(function()
			Library.DevicePlatform = UserInputService:GetPlatform()
		end)
		Library.IsMobile = (Library.DevicePlatform == Enum.Platform.Android or Library.DevicePlatform == Enum.Platform.IOS)
	end
end

if Library._libFocusConn == nil then
	Library._libFocusConn = UserInputService.WindowFocused:Connect(function()
		Library.IsRobloxFocused = true
	end)
	Library._libFocusReleasedConn = UserInputService.WindowFocusReleased:Connect(function()
		Library.IsRobloxFocused = false
	end)
end

function Library:OnUnload(fn: () -> ())
	if typeof(fn) == "function" then
		table.insert(self._unloadCallbacks, fn)
	end
end

function Library:RefreshTheme()
	for _, fn in self._windowRefreshes do
		pcall(fn)
	end
	for _, fn in self._notifyThemeRefreshes do
		pcall(fn)
	end
end

function Library:InvalidateThemePaintCache()
	self._themePaintValid = false
end

function Library:_disconnectThemePaintSubscribers()
	for _, c in self._themePaintSubConns do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(self._themePaintSubConns)
end

function Library:_subscribeThemePaintHost(host: Instance)
	if self._themePaintHost == host and #self._themePaintSubConns > 0 then
		return
	end
	self:_disconnectThemePaintSubscribers()
	self._themePaintHost = host
	local function bump()
		self:InvalidateThemePaintCache()
	end
	table.insert(self._themePaintSubConns, host.DescendantAdded:Connect(bump))
	table.insert(self._themePaintSubConns, host.DescendantRemoving:Connect(bump))
end

function Library:_rebuildThemePaintList(host: Instance)
	local T = self.Theme
	table.clear(self._themePaintTagged)
	table.clear(self._themePaintGroupbox)
	table.clear(self._themePaintDropdownScroll)
	for _, d in host:GetDescendants() do
		if d:IsA("UIStroke") then
			local sk = d:GetAttribute("UiStroke")
			if typeof(sk) == "string" and typeof(T[sk]) == "Color3" then
				table.insert(self._themePaintTagged, { "stroke", d, sk })
			end
		end
		if d:IsA("GuiObject") then
			local bgk = d:GetAttribute("UiBg")
			if typeof(bgk) == "string" and typeof(T[bgk]) == "Color3" then
				table.insert(self._themePaintTagged, { "bg", d, bgk })
			end
			local tx = d:GetAttribute("UiText")
			if typeof(tx) == "string" and typeof(T[tx]) == "Color3" then
				if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
					table.insert(self._themePaintTagged, { "text", d, tx })
				end
			end
			local ph = d:GetAttribute("UiPlaceholder")
			if typeof(ph) == "string" and typeof(T[ph]) == "Color3" and d:IsA("TextBox") then
				table.insert(self._themePaintTagged, { "ph", d, ph })
			end
			local ik = d:GetAttribute("UiImg")
			if typeof(ik) == "string" and typeof(T[ik]) == "Color3" then
				if d:IsA("ImageLabel") or d:IsA("ImageButton") then
					table.insert(self._themePaintTagged, { "img", d, ik })
				end
			end
		end
		if d:IsA("Frame") and d:GetAttribute("UiBg") == "Groupbox" then
			table.insert(self._themePaintGroupbox, d)
		end
		if d.Name == "DropdownScroll" and d:IsA("ScrollingFrame") then
			table.insert(self._themePaintDropdownScroll, d :: ScrollingFrame)
		end
	end
	self._themePaintValid = true
end

function Library:_paintThemeContentHost(host: Instance)
	local T = self.Theme
	if not self._themePaintValid or self._themePaintHost ~= host then
		self:_subscribeThemePaintHost(host)
		self:_rebuildThemePaintList(host)
	end
	for _, e in self._themePaintTagged do
		local kind, d, k = e[1], e[2], e[3]
		pcall(function()
			if kind == "stroke" and d:IsA("UIStroke") then
				d.Color = T[k]
			elseif kind == "bg" and d:IsA("GuiObject") then
				d.BackgroundColor3 = T[k]
			elseif kind == "text" and (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) then
				d.TextColor3 = T[k]
			elseif kind == "ph" and d:IsA("TextBox") then
				d.PlaceholderColor3 = T[k]
			elseif kind == "img" and (d:IsA("ImageLabel") or d:IsA("ImageButton")) then
				d.ImageColor3 = T[k]
			end
		end)
	end
	local gbt = T.GroupboxTrans
	local acc = T.AccentBlue
	for _, f in self._themePaintGroupbox do
		pcall(function()
			f.BackgroundTransparency = gbt
		end)
	end
	for _, sf in self._themePaintDropdownScroll do
		pcall(function()
			sf.ScrollBarImageColor3 = acc
		end)
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
	-- Reserved: fixed scale for now; hook here if you add DPI scaling later.
end

function Library:Notify(payload: any, duration: number?)
	local title = "Notice"
	local desc = ""
	local dur = 5
	local persist = false
	local stepsTotal: number? = nil
	local timeInstance: Instance? = nil
	local soundId: any = nil

	if typeof(payload) == "table" then
		title = tostring(payload.Title or title)
		desc = tostring(payload.Description or payload.Text or "")
		persist = payload.Persist == true
		stepsTotal = if typeof(payload.Steps) == "number" then payload.Steps else nil
		soundId = payload.SoundId
		if typeof(payload.Time) == "Instance" then
			timeInstance = payload.Time :: Instance
			dur = 0
		elseif typeof(payload.Time) == "number" then
			dur = payload.Time
		end
	elseif typeof(payload) == "string" then
		desc = payload
		dur = duration or dur
	else
		desc = tostring(payload)
		dur = duration or dur
	end

	local list = self._notifyList
	if not list or not list.Parent then
		return
	end

	if soundId ~= nil and soundId ~= "" then
		local sid = soundId
		if typeof(sid) == "number" then
			sid = string.format("rbxassetid://%d", sid)
		end
		if typeof(sid) == "string" then
			pcall(function()
				local SoundService = game:GetService("SoundService")
				local s = Instance.new("Sound")
				s.SoundId = sid
				s.Volume = 0.35
				s.PlayOnRemove = true
				s.Parent = SoundService
				s:Destroy()
			end)
		end
	end

	self._notifyOrder += 1
	local order = self._notifyOrder
	local card = Instance.new("Frame")
	card.Name = "Notify_" .. order
	card.Size = UDim2.new(0, 280, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Theme.Groupbox
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.LayoutOrder = -order
	card.Parent = list
	corner(Theme.Corner).Parent = card
	local cardStroke = stroke(Theme.Stroke, 1, math.clamp(Theme.StrokeTrans, 0.25, 0.62))
	cardStroke.Parent = card
	local padN = Instance.new("UIPadding")
	padN.PaddingLeft = UDim.new(0, 10)
	padN.PaddingRight = UDim.new(0, 10)
	padN.PaddingTop = UDim.new(0, 8)
	padN.PaddingBottom = UDim.new(0, 8)
	padN.Parent = card
	local vl = Instance.new("UIListLayout")
	vl.SortOrder = Enum.SortOrder.LayoutOrder
	vl.Padding = UDim.new(0, 6)
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

	local dl: TextLabel? = nil
	if desc ~= "" then
		local d = Instance.new("TextLabel")
		d.BackgroundTransparency = 1
		d.Font = Enum.Font.GothamMedium
		d.TextSize = 12
		d.TextColor3 = Theme.TextDim
		d.TextXAlignment = Enum.TextXAlignment.Left
		d.TextWrapped = true
		d.AutomaticSize = Enum.AutomaticSize.Y
		d.Size = UDim2.new(1, 0, 0, 0)
		d.Text = desc
		d.LayoutOrder = 2
		d.Parent = card
		dl = d
	end

	local hasInstanceTime = typeof(timeInstance) == "Instance"
	local useStepBar = typeof(stepsTotal) == "number" and stepsTotal > 0
	local showTimerBar = not persist and (useStepBar or (not hasInstanceTime and dur > 0))

	local timerBar: Frame? = nil
	local timerBarStroke: UIStroke? = nil
	local timerFill: Frame? = nil
	local fillGradient: UIGradient? = nil
	local timeLeftLabel: TextLabel? = nil

	local timerHolder = Instance.new("Frame")
	timerHolder.Name = "TimerHolder"
	timerHolder.BackgroundTransparency = 1
	timerHolder.Size = UDim2.new(1, 0, 0, 0)
	timerHolder.AutomaticSize = Enum.AutomaticSize.Y
	timerHolder.LayoutOrder = 3
	timerHolder.Visible = showTimerBar
	timerHolder.Parent = card

	if showTimerBar then
		local stack = Instance.new("UIListLayout")
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Padding = UDim.new(0, 5)
		stack.Parent = timerHolder

		local tlbl = Instance.new("TextLabel")
		tlbl.Name = "TimeLeft"
		tlbl.BackgroundTransparency = 1
		tlbl.Font = Enum.Font.GothamMedium
		tlbl.TextSize = 12
		tlbl.TextColor3 = Theme.TextDim
		tlbl.TextXAlignment = Enum.TextXAlignment.Right
		tlbl.TextYAlignment = Enum.TextYAlignment.Center
		tlbl.TextTransparency = 0.25
		tlbl.Size = UDim2.new(1, 0, 0, 15)
		tlbl.Text = useStepBar and string.format("Step 0 / %d", stepsTotal :: number) or string.format("%.1fs left", dur)
		tlbl.LayoutOrder = 1
		tlbl.Parent = timerHolder
		timeLeftLabel = tlbl

		local bar = Instance.new("Frame")
		bar.Name = "TimerBar"
		bar.BackgroundColor3 = Theme.SliderTrack
		bar.BorderSizePixel = 0
		bar.Size = UDim2.new(1, 0, 0, 5)
		bar.ClipsDescendants = true
		bar.LayoutOrder = 2
		bar.Parent = timerHolder
		corner(UDim.new(1, 0)).Parent = bar
		local bs = stroke(Theme.Stroke, 1, math.clamp(Theme.StrokeTrans + 0.12, 0.35, 0.78))
		bs.Parent = bar
		timerBar = bar
		timerBarStroke = bs

		local fill = Instance.new("Frame")
		fill.Name = "TimerFill"
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = bar
		corner(UDim.new(1, 0)).Parent = fill
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.AccentPurple),
			ColorSequenceKeypoint.new(1, Theme.AccentBlue),
		})
		grad.Parent = fill
		timerFill = fill
		fillGradient = grad

		if hasInstanceTime and not useStepBar then
			fill.Size = UDim2.fromScale(0, 1)
			tlbl.Text = "…"
		end
	end

	local cancelled = false
	local activeTween: Tween? = nil
	local instConn: RBXScriptConnection? = nil
	local hbConn: RBXScriptConnection? = nil

	local handle: any

	local function refreshNotifyCard()
		local T = Library.Theme
		card.BackgroundColor3 = T.Groupbox
		card.BackgroundTransparency = 0
		local cc = card:FindFirstChildWhichIsA("UICorner")
		if cc then
			cc.CornerRadius = T.Corner
		end
		cardStroke.Color = T.Stroke
		cardStroke.Transparency = math.clamp(T.StrokeTrans, 0.25, 0.62)
		tl.TextColor3 = T.Text
		if dl then
			dl.TextColor3 = T.TextDim
		end
		if timeLeftLabel then
			timeLeftLabel.TextColor3 = T.TextDim
		end
		if timerBar then
			timerBar.BackgroundColor3 = T.SliderTrack
		end
		if timerBarStroke then
			timerBarStroke.Color = T.Stroke
			timerBarStroke.Transparency = math.clamp(T.StrokeTrans + 0.12, 0.35, 0.78)
		end
		if fillGradient then
			fillGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, T.AccentPurple),
				ColorSequenceKeypoint.new(1, T.AccentBlue),
			})
		end
	end

	table.insert(self._notifyThemeRefreshes, refreshNotifyCard)

	local function unregisterNotifyTheme()
		for i = #self._notifyThemeRefreshes, 1, -1 do
			if self._notifyThemeRefreshes[i] == refreshNotifyCard then
				table.remove(self._notifyThemeRefreshes, i)
				break
			end
		end
	end

	local function doDestroy()
		if cancelled then
			return
		end
		cancelled = true
		if handle then
			handle.Destroyed = true
		end
		unregisterNotifyTheme()
		if hbConn then
			hbConn:Disconnect()
			hbConn = nil
		end
		if activeTween then
			pcall(function()
				activeTween:Cancel()
			end)
			activeTween = nil
		end
		if instConn then
			instConn:Disconnect()
			instConn = nil
		end
		if card.Parent then
			card:Destroy()
		end
	end

	handle = {
		Destroyed = false,
		Destroy = function()
			if handle.Destroyed then
				return
			end
			doDestroy()
		end,
		ChangeTitle = function(_self, text: string)
			if tl.Parent then
				tl.Text = tostring(text)
			end
		end,
		ChangeDescription = function(_self, text: string)
			local s = tostring(text)
			if not dl or not dl.Parent then
				if s == "" then
					return
				end
				local d = Instance.new("TextLabel")
				d.BackgroundTransparency = 1
				d.Font = Enum.Font.GothamMedium
				d.TextSize = 12
				d.TextColor3 = Library.Theme.TextDim
				d.TextXAlignment = Enum.TextXAlignment.Left
				d.TextWrapped = true
				d.AutomaticSize = Enum.AutomaticSize.Y
				d.Size = UDim2.new(1, 0, 0, 0)
				d.LayoutOrder = 2
				d.Parent = card
				dl = d
			end
			if dl then
				dl.Text = s
				dl.TextColor3 = Library.Theme.TextDim
				dl.Visible = s ~= ""
			end
		end,
		ChangeStep = function(_self, newStep: number?)
			if typeof(stepsTotal) ~= "number" or stepsTotal <= 0 or not timerFill then
				return
			end
			local n = math.clamp(newStep or 0, 0, stepsTotal)
			timerFill.Size = UDim2.fromScale(n / stepsTotal, 1)
			if timeLeftLabel then
				timeLeftLabel.Text = string.format("Step %d / %d", n, stepsTotal)
			end
		end,
	}

	if useStepBar then
		handle:ChangeStep(0)
	end

	if showTimerBar and dur > 0 and not useStepBar and not hasInstanceTime then
		local t0 = tick()
		hbConn = RunService.Heartbeat:Connect(function()
			if cancelled or not timeLeftLabel or not timeLeftLabel.Parent then
				if hbConn then
					hbConn:Disconnect()
					hbConn = nil
				end
				return
			end
			timeLeftLabel.Text = string.format("%.1fs left", math.max(0, dur - (tick() - t0)))
		end)
	end

	if persist then
		return handle
	end

	if hasInstanceTime then
		if not timeInstance.Parent then
			task.defer(doDestroy)
			return handle
		end
		instConn = timeInstance.Destroying:Connect(function()
			task.defer(doDestroy)
		end)
		return handle
	end

	if dur > 0 then
		if useStepBar then
			task.delay(dur, function()
				if not cancelled then
					doDestroy()
				end
			end)
		elseif showTimerBar and timerFill then
			timerFill.Size = UDim2.fromScale(1, 1)
			activeTween = TweenService:Create(
				timerFill,
				TweenInfo.new(dur, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
				{ Size = UDim2.fromScale(0, 1) }
			)
			activeTween.Completed:Connect(function(state)
				if state ~= Enum.PlaybackState.Cancelled and not cancelled then
					doDestroy()
				end
			end)
			activeTween:Play()
		else
			task.delay(dur, function()
				if not cancelled then
					doDestroy()
				end
			end)
		end
	else
		task.defer(function()
			if not cancelled then
				doDestroy()
			end
		end)
	end

	return handle
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
	self:_disconnectThemePaintSubscribers()
	self._themePaintHost = nil
	self:InvalidateThemePaintCache()
	table.clear(self._themePaintTagged)
	table.clear(self._themePaintGroupbox)
	table.clear(self._themePaintDropdownScroll)
	self._notifyList = nil
	self._updateNotifyLayout = nil
	table.clear(self._windowRefreshes)
	table.clear(self._notifyThemeRefreshes)
	table.clear(self.Toggles)
	table.clear(self.Options)
	self.ToggleKeybind = nil
	self.CantDragForced = false
end

--[[ Works when Color3.fromHex is missing or picky; accepts #RGB, #RRGGBB ]]
local function parseHexColor(raw: string): Color3?
	local s = string.lower((raw:gsub("#", ""):gsub("%s", "")))
	if #s == 6 then
		local r = tonumber(s:sub(1, 2), 16)
		local g = tonumber(s:sub(3, 4), 16)
		local b = tonumber(s:sub(5, 6), 16)
		if r and g and b then
			return Color3.fromRGB(r, g, b)
		end
	elseif #s == 3 then
		local r = tonumber(s:sub(1, 1), 16)
		local g = tonumber(s:sub(2, 2), 16)
		local b = tonumber(s:sub(3, 3), 16)
		if r and g and b then
			return Color3.fromRGB(r * 17, g * 17, b * 17)
		end
	end
	local ok, c = pcall(function()
		return Color3.fromHex(s)
	end)
	if ok and typeof(c) == "Color3" then
		return c
	end
	return nil
end

--[[ Hue strip: same pattern as Obsidian (`HueSequenceTable` + `for Hue = 0, 1, step`).
	Obsidian uses step 0.1 (11 keypoints). Many executors cap ColorSequence tables much lower
	and still *print* "table is too long" even when the call is inside pcall — so we must not
	try 11 first. We use step 0.25 (5 stops: 0, 0.25, …, 1); if that fails, two-keypoint API (no table). ]]
local ColorPickerHueSequence: ColorSequence
do
	local HueSequenceTable: { ColorSequenceKeypoint } = {}
	for Hue = 0, 1, 0.25 do
		table.insert(HueSequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)))
	end
	local ok, res = pcall(function()
		return ColorSequence.new(HueSequenceTable)
	end)
	if ok and res ~= nil then
		ColorPickerHueSequence = res
	else
		ColorPickerHueSequence = ColorSequence.new(
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1))
		)
	end
end

type GlowLayerSpec = { size: number, transparency: number }

--[[ Outer glow corners track panel radius: each layer is larger by `size` px, so corner radius scales with base. ]]
local function mainGlowCornerPx(baseCornerPx: number, layerSizePx: number): number
	return math.max(0, math.floor(baseCornerPx + (layerSizePx + 1) / 4))
end

local function tabGlowCornerPx(baseSmPx: number, layerSizePx: number): number
	return math.max(0, math.floor(baseSmPx + (layerSizePx + 2) / 5))
end

--[[ Panel / pill: inner = accent (purple→blue), outer eases toward Stroke — tracks ThemeManager accent ]]
local function themeGlowLayerColor(t: number): Color3
	local core = Theme.AccentPurple:Lerp(Theme.AccentBlue, math.clamp(t * 1.1, 0, 1))
	return core:Lerp(Theme.Stroke, t * t * 0.52)
end

--[[ Idle tab halo: faint accent on dark backgrounds (lerp into Background) ]]
local function themeTabIdleGlowColor(t: number): Color3
	local c = Theme.AccentPurple:Lerp(Theme.AccentBlue, t * 0.75)
	return c:Lerp(Theme.Background, 0.58 + t * 0.22)
end

--[[ Centered stacked frames behind a host; spills past edges when host clips are off ]]
local function addStackedGlow(host: Frame, specs: { GlowLayerSpec }, baseCornerPx: number)
	local steps = #specs - 1
	for i, g in specs do
		local t = if steps > 0 then (i - 1) / steps else 0
		local layerColor = themeGlowLayerColor(t)
		local layer = Instance.new("Frame")
		layer.Name = "GlowLayer"
		layer:SetAttribute("GlowStep", i)
		layer:SetAttribute("GlowSize", g.size)
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.Position = UDim2.fromScale(0.5, 0.5)
		layer.Size = UDim2.new(1, g.size, 1, g.size)
		layer.BackgroundColor3 = layerColor
		layer.BackgroundTransparency = g.transparency
		layer.BorderSizePixel = 0
		layer.ZIndex = 0
		layer.Parent = host
		local gc = Instance.new("UICorner")
		gc.CornerRadius = UDim.new(0, mainGlowCornerPx(baseCornerPx, g.size))
		gc.Parent = layer
	end
end

--[[ Sidebar tabs: accent-tinted halo; paintTabGlowHost updates for selected vs idle ]]
local function addTabStackedGlow(host: Frame, specs: { GlowLayerSpec }, baseSmPx: number)
	local n = #specs
	for i, g in specs do
		local t = if n > 1 then (i - 1) / (n - 1) else 0
		local layer = Instance.new("Frame")
		layer.Name = "GlowLayer"
		layer:SetAttribute("GlowStep", i)
		layer:SetAttribute("GlowSize", g.size)
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.Position = UDim2.fromScale(0.5, 0.5)
		layer.Size = UDim2.new(1, g.size, 1, g.size)
		layer.BackgroundColor3 = themeTabIdleGlowColor(t)
		layer.BackgroundTransparency = g.transparency
		layer.BorderSizePixel = 0
		layer.ZIndex = 0
		layer.Parent = host
		local gc = Instance.new("UICorner")
		gc.CornerRadius = UDim.new(0, tabGlowCornerPx(baseSmPx, g.size))
		gc.Parent = layer
	end
end

--[[ Top title pill: full rounded rect glow (accent → outline), sits behind solid TopPill ]]
local function addPillStackedGlow(host: Frame, specs: { GlowLayerSpec })
	local n = #specs
	for i, g in specs do
		local t = if n > 1 then (i - 1) / (n - 1) else 0
		local layer = Instance.new("Frame")
		layer.Name = "PillGlowLayer"
		layer:SetAttribute("GlowStep", i)
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.Position = UDim2.fromScale(0.5, 0.5)
		layer.Size = UDim2.new(1, g.size, 1, g.size)
		layer.BackgroundColor3 = themeGlowLayerColor(t)
		layer.BackgroundTransparency = g.transparency
		layer.BorderSizePixel = 0
		layer.ZIndex = 0
		layer.Parent = host
		local gc = Instance.new("UICorner")
		gc.CornerRadius = UDim.new(1, 0)
		gc.Parent = layer
	end
end

local function paintPillGlowHost(pillGlowHost: Frame?)
	if not pillGlowHost then
		return
	end
	local layers: { Frame } = {}
	for _, c in pillGlowHost:GetChildren() do
		if c:IsA("Frame") and c.Name == "PillGlowLayer" then
			table.insert(layers, c)
		end
	end
	table.sort(layers, function(a, b)
		return (tonumber(a:GetAttribute("GlowStep")) or 0) < (tonumber(b:GetAttribute("GlowStep")) or 0)
	end)
	local steps = #layers - 1
	for i, layer in layers do
		local t = if steps > 0 then (i - 1) / steps else 0
		layer.BackgroundColor3 = themeGlowLayerColor(t)
	end
end

local function paintMainGlowHost(mainGlowHost: Frame?)
	if not mainGlowHost then
		return
	end
	local layers: { Frame } = {}
	for _, c in mainGlowHost:GetChildren() do
		if c:IsA("Frame") and c.Name == "GlowLayer" then
			table.insert(layers, c)
		end
	end
	table.sort(layers, function(a, b)
		local sa = tonumber(a:GetAttribute("GlowStep"))
		local sb = tonumber(b:GetAttribute("GlowStep"))
		if typeof(sa) == "number" and typeof(sb) == "number" then
			return sa < sb
		end
		return a.Size.X.Offset < b.Size.X.Offset
	end)
	local basePx = Theme.Corner.Offset
	local steps = #layers - 1
	for i, layer in layers do
		local t = if steps > 0 then (i - 1) / steps else 0
		layer.BackgroundColor3 = themeGlowLayerColor(t)
		local sz = tonumber(layer:GetAttribute("GlowSize")) or 0
		local gc = layer:FindFirstChildWhichIsA("UICorner")
		if gc then
			gc.CornerRadius = UDim.new(0, mainGlowCornerPx(basePx, sz))
		end
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
	local baseSm = Theme.CornerSm.Offset
	local steps = #layers - 1
	for i, layer in layers do
		local t = if steps > 0 then (i - 1) / steps else 0
		if isSelected then
			local hot = Theme.AccentPurple:Lerp(Theme.AccentBlue, t)
			layer.BackgroundColor3 = hot:Lerp(Theme.Stroke, t * t * 0.38)
		else
			layer.BackgroundColor3 = themeTabIdleGlowColor(t)
		end
		local sz = tonumber(layer:GetAttribute("GlowSize")) or 0
		local gc = layer:FindFirstChildWhichIsA("UICorner")
		if gc then
			gc.CornerRadius = UDim.new(0, tabGlowCornerPx(baseSm, sz))
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
	if typeof(IconName) == "number" then
		return {
			Url = string.format("rbxassetid://%d", IconName),
			ImageRectOffset = Vector2.zero,
			ImageRectSize = Vector2.zero,
			Custom = true,
			Untinted = true,
		}
	end
	if typeof(IconName) ~= "string" then
		return nil
	end
	if IconName:match("^%s*%d+%s*$") then
		local id = tonumber((IconName :: string):gsub("%s", ""))
		if id then
			return {
				Url = string.format("rbxassetid://%d", id),
				ImageRectOffset = Vector2.zero,
				ImageRectSize = Vector2.zero,
				Custom = true,
				Untinted = true,
			}
		end
	end
	if Library.IsValidCustomIcon(IconName) then
		return {
			Url = IconName,
			ImageRectOffset = Vector2.zero,
			ImageRectSize = Vector2.zero,
			Custom = true,
			Untinted = true,
		}
	end
	local lucide = Library:GetIcon(IconName)
	if lucide then
		return lucide
	end
	return nil
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
	--[[ optional: replaces purple header dot — rbxassetid number, digit string, or rbxasset:// URL (same as tab icons) ]]
	TitleIcon: string | number?,
	--[[ optional rbxasset:// or http url for left mascot ]]
	MascotImage: string?,
	Size: Vector2?,
	--[[ minimum body content size (width × height below title bar); root adds mascot + 48px header ]]
	MinSize: Vector2?,
	Resizable: boolean?,
	GlowEnabled: boolean?,
	--[[ stacked halo behind each sidebar tab; on by default (set false to disable) ]]
	TabGlowEnabled: boolean?,
	--[[ Dropdowns default to Multi when Multi is omitted (Obsidian-style) ]]
	MultiDropdownByDefault: boolean?,
	--[[ Mobile: "Left" | "Right" — floating Menu / Lock chips ]]
	MobileButtonsSide: string?,
	--[[ Like Obsidian UnlockMouseWhileOpen: tiny Modal sink when hub is open on touch devices ]]
	UnlockMouseWhileOpen: boolean?,
	--[[ mspaint-style Info tab: full-width CHANGELOG (centered). Set false to disable. ]]
	InfoTab: boolean?,
	InfoChangelog: string?,
	InfoTabIcon: (string | number)?,
}

function Library.new(config: WindowConfig)
	config = config or {}
	local titleText = config.Title or "UI"
	local subtitleText = config.Subtitle or "https://example.com | discord.gg/example"
	local titleIcon = config.TitleIcon
	local mobileSide = string.lower(tostring(config.MobileButtonsSide or "Left"))
	if mobileSide ~= "right" then
		mobileSide = "left"
	end
	local unlockMouseWhileOpen = config.UnlockMouseWhileOpen ~= false
	local defaultMin = if Library.IsMobile then Vector2.new(300, 200) else Vector2.new(380, 300)
	local minContent = config.MinSize or defaultMin
	local size = config.Size or (if Library.IsMobile then Vector2.new(480, 360) else Vector2.new(520, 440))
	size = Vector2.new(math.max(size.X, minContent.X), math.max(size.Y, minContent.Y))
	local cam0 = workspace.CurrentCamera
	if cam0 then
		local vs = cam0.ViewportSize
		local margin = 28
		local maxW = math.max(minContent.X, vs.X - margin)
		local maxH = math.max(minContent.Y, vs.Y - margin)
		size = Vector2.new(math.clamp(size.X, minContent.X, maxW), math.clamp(size.Y, minContent.Y, maxH))
	end
	local mascotId = config.MascotImage
	local mascotOffset = if mascotId then 72 else 0
	local minRootW = minContent.X + mascotOffset
	local minRootH = minContent.Y + 48
	local tabGlowEnabled = config.TabGlowEnabled ~= false
	local dropdownMultiDefault = config.MultiDropdownByDefault == true
	Library.MultiDropdownByDefault = dropdownMultiDefault

	local defaultInfoChangelog = [[
UI Changes:
[+] Made It so keybinds can be either toggleable or holdable.

Supported Games:
[+] Prospecting
[+] BloxStrike

Project Delta:
[-] Removed Mouse Aim Method
[+] Fixed fov circle being broken

Dungeon Heroes:
[/] Added support for the new dungeon
]]

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HubUI"
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

	--[[ Obsidian-style 0×0 modal sink: improves camera / world input while GUI is open on mobile ]]
	local modalSink = Instance.new("TextButton")
	modalSink.Name = "ModalSink"
	modalSink.BackgroundTransparency = 1
	modalSink.Text = ""
	modalSink.Size = UDim2.fromOffset(0, 0)
	modalSink.AnchorPoint = Vector2.zero
	modalSink.Position = UDim2.fromScale(0, 0)
	modalSink.Modal = false
	modalSink.ZIndex = -500
	modalSink.Active = false
	modalSink.AutoButtonColor = false
	modalSink.Parent = screenGui

	Library.Unloaded = false
	table.clear(Library.Toggles)
	table.clear(Library.Options)

	local toggleThemeRows: { { track: Frame, getOn: () -> boolean } } = {}
	local sliderGradients: { UIGradient } = {}
	--[[ After theme paint, restore section chevrons (ImageRect can get cleared on some clients). ]]
	local sectionChevronRefreshes: { () -> () } = {}

	-- Notify UI is parented after root (see below) so it stacks above the window with Global ZIndex

	-- Tooltips (hover label / tab — same idea as Obsidian AddTooltip)
	local tooltipLabel = Instance.new("TextLabel")
	tooltipLabel.Name = "LibTooltip"
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
	tooltipLabel.ZIndex = 950
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
					local px: number
					local py: number
					if Library.IsMobile then
						local ml = UserInputService:GetMouseLocation()
						px = ml.X
						py = ml.Y
					else
						px = PlayerMouse.X
						py = PlayerMouse.Y
					end
					local cam = workspace.CurrentCamera
					local vw = if cam then cam.ViewportSize.X else 1920
					local vh = if cam then cam.ViewportSize.Y else 1080
					local ax = tooltipLabel.AbsoluteSize.X
					local ay = tooltipLabel.AbsoluteSize.Y
					local x = math.clamp(px + 14, 6, math.max(6, vw - ax - 6))
					local y = math.clamp(py + 14, 6, math.max(6, vh - ay - 6))
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

	--[[ Right-click key cap → Toggle / Hold (Obsidian-style). One menu per window. ]]
	local keybindModeMenu: Frame? = nil
	local keybindModeMenuConn: RBXScriptConnection? = nil

	local function destroyKeybindModeMenu()
		if keybindModeMenuConn then
			keybindModeMenuConn:Disconnect()
			keybindModeMenuConn = nil
		end
		if keybindModeMenu then
			keybindModeMenu:Destroy()
			keybindModeMenu = nil
		end
	end

	local function showKeybindModeMenu(anchor: GuiObject, currentMode: string, onPick: (string) -> ())
		destroyKeybindModeMenu()
		local menu = Instance.new("Frame")
		menu.Name = "KeybindModeMenu"
		menu.BackgroundColor3 = Theme.Elevated
		menu.BackgroundTransparency = 0.05
		menu.BorderSizePixel = 0
		menu.ZIndex = 2000
		menu.AutomaticSize = Enum.AutomaticSize.Y
		menu.Size = UDim2.fromOffset(92, 0)
		local ap = anchor.AbsolutePosition
		local asz = anchor.AbsoluteSize
		menu.Position = UDim2.fromOffset(ap.X + asz.X + 3, ap.Y)
		menu.Parent = screenGui
		corner(Theme.CornerSm).Parent = menu
		stroke(Theme.Stroke, 1, 0.45).Parent = menu
		local mpad = Instance.new("UIPadding")
		mpad.PaddingTop = UDim.new(0, 4)
		mpad.PaddingBottom = UDim.new(0, 4)
		mpad.PaddingLeft = UDim.new(0, 4)
		mpad.PaddingRight = UDim.new(0, 4)
		mpad.Parent = menu
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 2)
		list.Parent = menu

		local modes = { "Toggle", "Hold" }
		for _, mName in modes do
			local sel = mName == currentMode
			local btn = Instance.new("TextButton")
			btn.AutoButtonColor = false
			btn.Size = UDim2.new(1, 0, 0, 22)
			btn.Text = mName
			btn.Font = Enum.Font.GothamMedium
			btn.TextSize = 13
			btn.TextColor3 = Theme.Text
			btn.BackgroundColor3 = if sel then Theme.AccentBlue else Theme.Background
			btn.BackgroundTransparency = if sel then 0.2 else 0.35
			btn:SetAttribute("UiBg", if sel then "AccentBlue" else "Background")
			btn:SetAttribute("UiText", "Text")
			btn.Parent = menu
			corner(Theme.CornerSm).Parent = btn
			btn.MouseButton1Click:Connect(function()
				onPick(mName)
				destroyKeybindModeMenu()
			end)
		end

		keybindModeMenu = menu
		task.defer(function()
			if keybindModeMenu ~= menu then
				return
			end
			keybindModeMenuConn = UserInputService.InputBegan:Connect(function(input: InputObject)
				if
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end
				local loc = Vector2.new(input.Position.X, input.Position.Y)
				local mp = menu.AbsolutePosition
				local ms = menu.AbsoluteSize
				if loc.X >= mp.X and loc.X <= mp.X + ms.X and loc.Y >= mp.Y and loc.Y <= mp.Y + ms.Y then
					return
				end
				if
					loc.X >= ap.X
					and loc.X <= ap.X + asz.X
					and loc.Y >= ap.Y
					and loc.Y <= ap.Y + asz.Y
				then
					return
				end
				destroyKeybindModeMenu()
			end)
		end)
	end

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.new(0.5, 0, 0.5, 0)
	root.Size = UDim2.fromOffset(size.X + mascotOffset, size.Y + 48)
	root.BackgroundTransparency = 1
	root.Parent = screenGui

	local function setRootVisible(v: boolean)
		root.Visible = v
		if unlockMouseWhileOpen and Library.IsMobile then
			modalSink.Modal = v
		end
	end

	-- Toasts: created after root so with Sibling ZIndex they stack above the window; high ZIndex vs root (0)
	local notifyHost = Instance.new("Frame")
	notifyHost.Name = "NotifyHost"
	notifyHost.Size = UDim2.fromScale(1, 1)
	notifyHost.BackgroundTransparency = 1
	notifyHost.ZIndex = 800
	notifyHost.Active = false
	notifyHost.Parent = screenGui
	local notifyList = Instance.new("Frame")
	notifyList.Name = "NotifyList"
	notifyList.Size = UDim2.new(0, 300, 1, -24)
	notifyList.BackgroundTransparency = 1
	notifyList.ZIndex = 801
	notifyList.Parent = notifyHost
	local nlayout = Instance.new("UIListLayout")
	nlayout.SortOrder = Enum.SortOrder.LayoutOrder
	nlayout.VerticalAlignment = Enum.VerticalAlignment.Top
	nlayout.Padding = UDim.new(0, 8)
	nlayout.Parent = notifyList

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
	Library._notifyList = notifyList
	Library._updateNotifyLayout = updateNotifyLayout

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

	local pillOuter = Instance.new("Frame")
	pillOuter.Name = "TopPillOuter"
	pillOuter.Size = UDim2.new(1, mascot and -74 or 0, 0, 36)
	pillOuter.BackgroundTransparency = 1
	pillOuter.BorderSizePixel = 0
	pillOuter.LayoutOrder = 1
	pillOuter.ClipsDescendants = false
	pillOuter.Parent = topRow

	local pillGlowHost: Frame? = nil
	if config.GlowEnabled ~= false then
		local gh = Instance.new("Frame")
		gh.Name = "PillGlowHost"
		gh.Size = UDim2.fromScale(1, 1)
		gh.BackgroundTransparency = 1
		gh.BorderSizePixel = 0
		gh.ZIndex = 0
		gh.Parent = pillOuter
		pillGlowHost = gh
		addPillStackedGlow(gh, {
			{ size = 4, transparency = 0.84 },
			{ size = 10, transparency = 0.91 },
			{ size = 16, transparency = 0.95 },
		})
	end

	local pill = Instance.new("Frame")
	pill.Name = "TopPill"
	pill.Size = UDim2.fromScale(1, 1)
	pill.Position = UDim2.fromScale(0, 0)
	pill.ZIndex = 1
	pill.BackgroundColor3 = Theme.Background
	pill.BackgroundTransparency = 0
	pill.BorderSizePixel = 0
	pill.Parent = pillOuter
	corner(UDim.new(1, 0)).Parent = pill
	stroke(Theme.Stroke, 1, 0.65).Parent = pill
	pad(12).Parent = pill

	local pillLayout = Instance.new("UIListLayout")
	pillLayout.FillDirection = Enum.FillDirection.Horizontal
	pillLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pillLayout.Padding = UDim.new(0, 10)
	pillLayout.Parent = pill

	local logo: GuiObject
	if titleIcon ~= nil then
		local img = Instance.new("ImageLabel")
		img.Name = "TitleIcon"
		img.Size = UDim2.fromOffset(18, 18)
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.LayoutOrder = 0
		local parsed = Library:GetCustomIcon(titleIcon)
		if parsed then
			img.Image = parsed.Url
			img.ImageRectOffset = parsed.ImageRectOffset
			img.ImageRectSize = parsed.ImageRectSize
			if parsed.Untinted then
				img.ImageColor3 = Color3.new(1, 1, 1)
			else
				img.ImageColor3 = Theme.AccentPurple
				img:SetAttribute("UiImg", "AccentPurple")
			end
		end
		img.Parent = pill
		corner(UDim.new(1, 0)).Parent = img
		logo = img
	else
		local fr = Instance.new("Frame")
		fr.Name = "LogoDot"
		fr.Size = UDim2.fromOffset(18, 18)
		fr.BackgroundColor3 = Theme.AccentPurple
		fr.LayoutOrder = 0
		fr.Parent = pill
		corner(UDim.new(1, 0)).Parent = fr
		logo = fr
	end

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
	sideList.Padding = UDim.new(0, 6)
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

	local panelGlowHost: Frame? = nil
	if config.GlowEnabled ~= false then
		local gh = Instance.new("Frame")
		gh.Name = "MainGlowHost"
		gh.Size = UDim2.fromScale(1, 1)
		gh.Position = UDim2.fromScale(0, 0)
		gh.BackgroundTransparency = 1
		gh.BorderSizePixel = 0
		gh.ZIndex = 0
		gh.Parent = mainPanel
		panelGlowHost = gh
		addStackedGlow(gh, {
			{ size = 5, transparency = 0.82 },
			{ size = 11, transparency = 0.9 },
			{ size = 17, transparency = 0.95 },
			{ size = 22, transparency = 0.98 },
		}, Library.CornerRadius)
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
	pcall(function()
		panelOutline.LineJoinMode = Enum.LineJoinMode.Round
	end)

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
			btn.BackgroundTransparency = if isSel then 0.08 else 0.45
			local icon = btn:FindFirstChild("LucideIcon")
			if icon and icon:IsA("ImageLabel") then
				if icon:GetAttribute("UiTabIconUntinted") == true then
					icon.ImageColor3 = Color3.new(1, 1, 1)
				else
					icon.ImageColor3 = if isSel then Color3.new(1, 1, 1) else Theme.Text
				end
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

	--[[ Floating Menu / Lock (Obsidian-style) — keyboard toggle is unreliable on pure touch clients ]]
	if Library.IsMobile then
		local chipOuter = Instance.new("Frame")
		chipOuter.Name = "MobileTools"
		chipOuter.BackgroundTransparency = 1
		chipOuter.Size = UDim2.fromOffset(92, 78)
		chipOuter.ZIndex = 950
		chipOuter.Parent = screenGui
		if mobileSide == "right" then
			chipOuter.AnchorPoint = Vector2.new(1, 0)
			chipOuter.Position = UDim2.new(1, -10, 0, 10)
		else
			chipOuter.Position = UDim2.fromOffset(10, 10)
		end
		local _chipList = Instance.new("UIListLayout")
		_chipList.Padding = UDim.new(0, 6)
		_chipList.Parent = chipOuter

		local function makeMobileChip(label: string): TextButton
			local b = Instance.new("TextButton")
			b.Size = UDim2.fromOffset(86, 34)
			b.BackgroundColor3 = Theme.Elevated
			b.BackgroundTransparency = 0.08
			b.Text = label
			b.TextColor3 = Theme.Text
			b.TextSize = 13
			b.Font = Enum.Font.GothamMedium
			b.AutoButtonColor = false
			b.BorderSizePixel = 0
			b.Parent = chipOuter
			corner(Theme.CornerSm).Parent = b
			stroke(Theme.Stroke, 1, 0.5).Parent = b
			return b
		end

		makeMobileChip("Menu").MouseButton1Click:Connect(function()
			setRootVisible(not root.Visible)
		end)

		local lockChip = makeMobileChip("Lock")
		lockChip.MouseButton1Click:Connect(function()
			Library.CantDragForced = not Library.CantDragForced
			lockChip.Text = if Library.CantDragForced then "Unlock" else "Lock"
		end)
	end

	setRootVisible(true)

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
				if Library.CantDragForced then
					return
				end
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
			if Library.CantDragForced then
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
			local p = Vector2.new(input.Position.X, input.Position.Y)
			local function inDragRegion(): boolean
				local ap = mainPanel.AbsolutePosition
				local as = mainPanel.AbsoluteSize
				if
					p.X >= ap.X
					and p.X <= ap.X + as.X
					and p.Y >= ap.Y
					and p.Y <= ap.Y + 44
				then
					return true
				end
				local pap = pill.AbsolutePosition
				local pas = pill.AbsoluteSize
				if
					pap.X <= p.X
					and p.X <= pap.X + pas.X
					and pap.Y <= p.Y
					and p.Y <= pap.Y + pas.Y
				then
					return true
				end
				return false
			end
			if gp and not inDragRegion() then
				return
			end
			if not inDragRegion() then
				return
			end
			dragging = true
			dragStart = p
			startPos = root.Position
		end
		local function inputMoved(input: InputObject, gp: boolean)
			if Library.CantDragForced then
				dragging = false
				resizing = false
				return
			end
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
		paintPillGlowHost(pillGlowHost)
		do
			local mg = mainPanel:FindFirstChild("MainGlowHost")
			if mg and mg:IsA("Frame") then
				paintMainGlowHost(mg)
			else
				paintMainGlowHost(panelGlowHost)
			end
		end
		if logo:IsA("Frame") then
			logo.BackgroundColor3 = Theme.AccentPurple
		elseif logo:IsA("ImageLabel") then
			local ak = logo:GetAttribute("UiImg")
			if typeof(ak) == "string" and typeof(Theme[ak]) == "Color3" then
				logo.ImageColor3 = Theme[ak]
			end
		end
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
			local function styleScroll(sf: ScrollingFrame)
				--[[ Transparent: PanelFace already draws the rounded shell; an opaque rect here covers the bottom corners. ]]
				sf.BackgroundTransparency = 1
				sf.ScrollBarImageColor3 = Theme.AccentBlue
			end
			if sc:IsA("ScrollingFrame") then
				styleScroll(sc)
			else
				for _, ch in sc:GetChildren() do
					if ch:IsA("ScrollingFrame") then
						styleScroll(ch)
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
		Library:_paintThemeContentHost(contentHost)
		for _, chevRefresh in sectionChevronRefreshes do
			pcall(chevRefresh)
		end
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
		if not Library.IsRobloxFocused then
			return
		end
		local tb = Library.ToggleKeybind
		if not tb or typeof(tb.Value) ~= "EnumItem" then
			return
		end
		if tb.Value == Enum.KeyCode.Unknown then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode ~= tb.Value then
			return
		end
		setRootVisible(not root.Visible)
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
		destroyKeybindModeMenu()
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
		local mg = mainPanel:FindFirstChild("MainGlowHost")
		if mg and mg:IsA("Frame") then
			paintMainGlowHost(mg :: Frame)
		else
			paintMainGlowHost(panelGlowHost)
		end
		selectTab(activeTab)
	end

	-- Tab API
	local Tab = {}
	Tab.__index = Tab

	--[[ Horizontal sub-tabs inside a column; each :AddTab returns a proxy Tab (use AddLeftGroupbox / AddSection on it). ]]
	local function makeTabbox(parentScroll: Instance, layoutOrder: number, boxTitle: string?): any
		local root = Instance.new("Frame")
		root.Name = "TabboxRoot"
		root.BackgroundTransparency = 1
		root.BorderSizePixel = 0
		root.Size = UDim2.new(1, 0, 0, 0)
		root.AutomaticSize = Enum.AutomaticSize.Y
		root.LayoutOrder = layoutOrder
		root.Parent = parentScroll

		local vList = Instance.new("UIListLayout")
		vList.FillDirection = Enum.FillDirection.Vertical
		vList.SortOrder = Enum.SortOrder.LayoutOrder
		vList.Padding = UDim.new(0, 6)
		vList.Parent = root

		local nextLo = 1
		if typeof(boxTitle) == "string" and boxTitle ~= "" then
			local title = Instance.new("TextLabel")
			title.BackgroundTransparency = 1
			title.Size = UDim2.new(1, 0, 0, 14)
			title.Font = Enum.Font.GothamBold
			title.TextSize = 11
			title.TextColor3 = Theme.TextDim
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Text = string.upper(boxTitle)
			title.LayoutOrder = nextLo
			title:SetAttribute("UiText", "TextDim")
			nextLo += 1
			title.Parent = root
		end

		local strip = Instance.new("Frame")
		strip.Name = "TabboxStrip"
		strip.BackgroundColor3 = Theme.Background
		strip.BackgroundTransparency = 0.35
		strip.BorderSizePixel = 0
		strip.Size = UDim2.new(1, 0, 0, UID.TabboxStripH)
		strip.LayoutOrder = nextLo
		nextLo += 1
		strip:SetAttribute("UiBg", "Background")
		strip.Parent = root
		corner(Theme.CornerSm).Parent = strip
		local stripPad = Instance.new("UIPadding")
		stripPad.PaddingLeft = UDim.new(0, 4)
		stripPad.PaddingRight = UDim.new(0, 4)
		stripPad.PaddingTop = UDim.new(0, 4)
		stripPad.PaddingBottom = UDim.new(0, 4)
		stripPad.Parent = strip

		local hList = Instance.new("UIListLayout")
		hList.FillDirection = Enum.FillDirection.Horizontal
		hList.SortOrder = Enum.SortOrder.LayoutOrder
		hList.Padding = UDim.new(0, 4)
		hList.VerticalAlignment = Enum.VerticalAlignment.Center
		hList.Parent = strip

		local contentHost = Instance.new("Frame")
		contentHost.Name = "TabboxContent"
		contentHost.BackgroundTransparency = 1
		contentHost.BorderSizePixel = 0
		contentHost.Size = UDim2.new(1, 0, 0, 0)
		contentHost.AutomaticSize = Enum.AutomaticSize.Y
		contentHost.LayoutOrder = nextLo
		contentHost.Parent = root

		local chList = Instance.new("UIListLayout")
		chList.SortOrder = Enum.SortOrder.LayoutOrder
		chList.Padding = UDim.new(0, 0)
		chList.Parent = contentHost

		local entries: { { btn: TextButton, inner: Frame, proxy: any } } = {}
		local activeSub = 1

		local function paintStrip(sel: number)
			for i, e in entries do
				local on = i == sel
				e.btn.BackgroundTransparency = if on then 0.08 else 0.55
				e.btn.BackgroundColor3 = if on then Theme.Elevated else Theme.Background
				e.btn.TextColor3 = if on then Theme.Text else Theme.TextDim
				e.btn:SetAttribute("UiBg", if on then "Elevated" else "Background")
				e.btn:SetAttribute("UiText", if on then "Text" else "TextDim")
			end
		end

		local function selectSub(i: number)
			if i < 1 or i > #entries then
				return
			end
			activeSub = i
			for j, e in entries do
				e.inner.Visible = j == i
			end
			paintStrip(i)
		end

		local box = {}
		function box:AddTab(name: string)
			local idx = #entries + 1
			local btn = Instance.new("TextButton")
			btn.Name = "SubTab_" .. name
			btn.AutoButtonColor = false
			btn.Size = UDim2.new(0, 0, 0, UID.TabboxBtnH)
			btn.AutomaticSize = Enum.AutomaticSize.X
			btn.Font = Enum.Font.GothamMedium
			btn.TextSize = UID.TabboxBtnText
			btn.Text = name
			btn.BackgroundColor3 = Theme.Background
			btn.BackgroundTransparency = 0.55
			btn.TextColor3 = Theme.TextDim
			btn.LayoutOrder = idx
			btn:SetAttribute("UiBg", "Background")
			btn:SetAttribute("UiText", "TextDim")
			btn.Parent = strip
			corner(Theme.CornerSm).Parent = btn
			pad(8).Parent = btn

			local inner = Instance.new("Frame")
			inner.Name = "TabboxPage_" .. name
			inner.BackgroundTransparency = 1
			inner.BorderSizePixel = 0
			inner.Size = UDim2.new(1, 0, 0, 0)
			inner.AutomaticSize = Enum.AutomaticSize.Y
			inner.Visible = idx == 1
			inner.LayoutOrder = 1
			inner.Parent = contentHost

			local innerList = Instance.new("UIListLayout")
			innerList.SortOrder = Enum.SortOrder.LayoutOrder
			innerList.Padding = UDim.new(0, 12)
			innerList.Parent = inner

			local proxy = setmetatable({
				_scroll = inner,
				_list = innerList,
				_split = false,
				_scrollLeft = nil,
				_scrollRight = nil,
				_listLeft = nil,
				_listRight = nil,
				_name = name,
				_sectionOrder = 0,
				_sectionOrderLeft = 0,
				_sectionOrderRight = 0,
			}, Tab)

			table.insert(entries, { btn = btn, inner = inner, proxy = proxy })
			btn.MouseButton1Click:Connect(function()
				selectSub(idx)
			end)
			selectSub(activeSub)
			return proxy
		end

		return box
	end

	--[[ Tab icons: Lucide name (e.g. "layout-grid", "eye") or rbxassetid://… — same as Obsidian GetCustomIcon
	    SplitColumns: two-column layout (left/right ScrollingFrames); use AddLeftGroupbox / AddRightGroupbox / AddLeftTabbox / AddRightTabbox ]]
	function window:AddTab(opts: { Name: string?, Icon: (string | number)?, Tooltip: string?, SplitColumns: boolean? })
		opts = opts or {}
		local idx = #tabScrolls + 1
		local splitColumns = opts.SplitColumns == true
		local rawIcon = opts.Icon
		local parsed: any = nil
		if rawIcon ~= nil and not (typeof(rawIcon) == "string" and rawIcon == "") then
			parsed = Library:GetCustomIcon(rawIcon)
		end

		local tabSlot = Instance.new("Frame")
		tabSlot.Name = "TabSlot_" .. idx
		tabSlot.Size = UDim2.fromOffset(44, 44)
		tabSlot.BackgroundTransparency = 1
		tabSlot.BorderSizePixel = 0
		tabSlot.ClipsDescendants = false
		tabSlot.LayoutOrder = idx
		tabSlot.Parent = sidebar

		if tabGlowEnabled then
			local tabGlowHost = Instance.new("Frame")
			tabGlowHost.Name = "TabGlowHost"
			tabGlowHost.Size = UDim2.fromScale(1, 1)
			tabGlowHost.BackgroundTransparency = 1
			tabGlowHost.BorderSizePixel = 0
			tabGlowHost.ZIndex = 0
			tabGlowHost.Parent = tabSlot
			addTabStackedGlow(tabGlowHost, {
				{ size = 2, transparency = 0.88 },
				{ size = 6, transparency = 0.93 },
				{ size = 11, transparency = 0.97 },
			}, math.max(0, math.floor(Library.CornerRadius * 0.75)))
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
			if parsed.Untinted == true then
				img.ImageColor3 = Color3.new(1, 1, 1)
				img:SetAttribute("UiTabIconUntinted", true)
			else
				img.ImageColor3 = Theme.Text
			end
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

	function window:SelectTab(index: number)
		local n = math.floor(index + 0.5)
		if n < 1 or n > #tabButtons then
			return
		end
		selectTab(n)
	end

	--[[ Section: optional Collapsible, DefaultExpanded, Tooltip; Column "Left"|"Right" when tab uses SplitColumns ]]
	function Tab:AddSection(
		header: string,
		sectionOpts: {
			Collapsible: boolean?,
			DefaultExpanded: boolean?,
			Tooltip: string?,
			Column: string?,
			--[[ Roblox asset id (number or numeric string), rbxasset URL, or Lucide icon name ]]
			Icon: (number | string)?,
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
		wrap.BackgroundColor3 = Theme.Groupbox
		wrap.BackgroundTransparency = Theme.GroupboxTrans
		wrap.BorderSizePixel = 0
		wrap.LayoutOrder = layoutOrder
		wrap:SetAttribute("UiBg", "Groupbox")
		wrap.Parent = parentScroll
		corner(Theme.Corner).Parent = wrap
		local gbStroke = stroke(Theme.AccentBlue, 1, math.clamp(Theme.StrokeTrans, 0.22, 0.58))
		gbStroke:SetAttribute("UiStroke", "AccentBlue")
		gbStroke.Parent = wrap
		local wrapOuterPad = Instance.new("UIPadding")
		wrapOuterPad.PaddingLeft = UDim.new(0, UID.SectionOuterPad)
		wrapOuterPad.PaddingRight = UDim.new(0, UID.SectionOuterPad)
		wrapOuterPad.PaddingTop = UDim.new(0, UID.SectionOuterPad)
		wrapOuterPad.PaddingBottom = UDim.new(0, UID.SectionOuterPad)
		wrapOuterPad.Parent = wrap

		local wrapList = Instance.new("UIListLayout")
		wrapList.FillDirection = Enum.FillDirection.Vertical
		wrapList.SortOrder = Enum.SortOrder.LayoutOrder
		wrapList.Padding = UDim.new(0, 0)
		wrapList.Parent = wrap

		local headerRow: GuiObject
		if collapsible then
			local hb = Instance.new("TextButton")
			hb.Name = "Header"
			hb.Size = UDim2.new(1, 0, 0, UID.SectionHeaderH)
			hb.BackgroundTransparency = 1
			hb.Text = ""
			hb.AutoButtonColor = false
			hb.LayoutOrder = 1
			hb.Parent = wrap
			headerRow = hb
		else
			local hf = Instance.new("Frame")
			hf.Name = "Header"
			hf.Size = UDim2.new(1, 0, 0, UID.SectionHeaderH)
			hf.BackgroundTransparency = 1
			hf.LayoutOrder = 1
			hf.Parent = wrap
			headerRow = hf
		end
		pad(UID.SectionHeaderInnerPad).Parent = headerRow

		local hLayout = Instance.new("UIListLayout")
		hLayout.FillDirection = Enum.FillDirection.Horizontal
		pcall(function()
			hLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
		end)
		hLayout.SortOrder = Enum.SortOrder.LayoutOrder
		hLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		hLayout.Padding = UDim.new(0, 6)
		hLayout.Parent = headerRow

		local headerLayoutNext = 0
		if sectionOpts.Icon ~= nil then
			local spec: { Url: string, ImageRectOffset: Vector2, ImageRectSize: Vector2, Untinted: boolean }? = nil
			local ri = sectionOpts.Icon
			if typeof(ri) == "number" then
				spec = {
					Url = string.format("rbxassetid://%d", ri),
					ImageRectOffset = Vector2.zero,
					ImageRectSize = Vector2.zero,
					Untinted = true,
				}
			elseif typeof(ri) == "string" then
				if Library.IsValidCustomIcon(ri) then
					spec = {
						Url = ri,
						ImageRectOffset = Vector2.zero,
						ImageRectSize = Vector2.zero,
						Untinted = true,
					}
				elseif ri:match("^%s*%d+%s*$") then
					local id = tonumber((ri :: string):gsub("%s", ""))
					if id then
						spec = {
							Url = string.format("rbxassetid://%d", id),
							ImageRectOffset = Vector2.zero,
							ImageRectSize = Vector2.zero,
							Untinted = true,
						}
					end
				else
					local ci = Library:GetCustomIcon(ri :: string)
					if ci and typeof(ci.Url) == "string" and ci.Url ~= "" then
						spec = {
							Url = ci.Url,
							ImageRectOffset = ci.ImageRectOffset or Vector2.zero,
							ImageRectSize = ci.ImageRectSize or Vector2.zero,
							Untinted = false,
						}
					end
				end
			end
			if spec then
				local img = Instance.new("ImageLabel")
				img.Name = "SectionIcon"
				img.BackgroundTransparency = 1
				img.Size = UDim2.fromOffset(UID.SectionIcon, UID.SectionIcon)
				img.Image = spec.Url
				img.ImageRectOffset = spec.ImageRectOffset
				img.ImageRectSize = spec.ImageRectSize
				img.ScaleType = Enum.ScaleType.Fit
				img.LayoutOrder = headerLayoutNext
				img.Parent = headerRow
				if spec.Untinted then
					img.ImageColor3 = Color3.new(1, 1, 1)
				else
					img.ImageColor3 = Theme.AccentBlue
					img:SetAttribute("UiImg", "AccentBlue")
				end
				headerLayoutNext += 1
			end
		end

		local hText = Instance.new("TextLabel")
		hText.Size = UDim2.new(0, 100, 1, 0)
		hText.AutomaticSize = Enum.AutomaticSize.X
		hText.BackgroundTransparency = 1
		hText.Font = Enum.Font.GothamBold
		hText.TextSize = UID.SectionTitle
		hText.TextColor3 = Theme.Text
		hText.TextXAlignment = Enum.TextXAlignment.Left
		hText.Text = string.upper(header)
		hText.LayoutOrder = headerLayoutNext
		hText.Parent = headerRow
		headerLayoutNext += 1
		local flexGrow = Instance.new("UIFlexItem")
		flexGrow.FlexMode = Enum.UIFlexMode.Grow
		flexGrow.Parent = hText

		--[[ Collapsible: swap Lucide chevron-down (expanded) / chevron-up (collapsed). ImageButton so the glyph receives clicks (ImageLabel often lets hits fall through oddly). ]]
		local chevBtn: ImageButton? = nil
		local specChevExpanded: any = nil
		local specChevCollapsed: any = nil
		local function lucideSpriteUrl(spec: any): string?
			if typeof(spec) ~= "table" then
				return nil
			end
			local u = spec.Url or spec.url
			if typeof(u) == "string" and u ~= "" then
				return u
			end
			return nil
		end
		local function applyLucideSprite(btn: ImageButton, spec: any)
			local u = lucideSpriteUrl(spec)
			if not u then
				return
			end
			btn.Image = u
			local ro = spec.ImageRectOffset or spec.imageRectOffset
			local rs = spec.ImageRectSize or spec.imageRectSize
			btn.ImageRectOffset = if typeof(ro) == "Vector2" then ro else Vector2.zero
			btn.ImageRectSize = if typeof(rs) == "Vector2" then rs else Vector2.zero
		end
		if collapsible then
			specChevExpanded = Library:GetIcon("chevron-down")
			specChevCollapsed = Library:GetIcon("chevron-up")
			if not lucideSpriteUrl(specChevExpanded) or not lucideSpriteUrl(specChevCollapsed) then
				error("Library: Lucide chevron-down and chevron-up are required for collapsible sections.")
			end
			local btn = Instance.new("ImageButton")
			btn.Name = "Chevron"
			btn.AutoButtonColor = false
			btn.BackgroundTransparency = 1
			btn.Size = UDim2.fromOffset(UID.Chevron, UID.Chevron)
			btn.ImageColor3 = Theme.TextDim
			btn.LayoutOrder = headerLayoutNext
			btn.ScaleType = Enum.ScaleType.Fit
			btn.ZIndex = 2
			btn.Selectable = false
			btn.Parent = headerRow
			chevBtn = btn
		end

		hText:SetAttribute("UiText", "Text")
		if chevBtn then
			chevBtn:SetAttribute("UiImg", "TextDim")
		end

		if typeof(sectionOpts.Tooltip) == "string" and sectionOpts.Tooltip ~= "" then
			local ttParts: { GuiObject } = { headerRow, hText }
			if chevBtn then
				table.insert(ttParts, chevBtn)
			end
			bindTooltipToInstances(ttParts, sectionOpts.Tooltip)
		end

		local titleSep = Instance.new("Frame")
		titleSep.Name = "SectionTitleSep"
		titleSep.Size = UDim2.new(1, 0, 0, 1)
		titleSep.BorderSizePixel = 0
		titleSep.BackgroundColor3 = Theme.AccentBlue
		titleSep.BackgroundTransparency = math.clamp(Theme.StrokeTrans, 0.28, 0.65)
		titleSep.LayoutOrder = 2
		titleSep.Parent = wrap
		titleSep:SetAttribute("UiBg", "AccentBlue")

		local bodyF = Instance.new("Frame")
		bodyF.Name = "Body"
		bodyF.Size = UDim2.new(1, 0, 0, 0)
		bodyF.AutomaticSize = Enum.AutomaticSize.Y
		bodyF.BackgroundTransparency = 1
		bodyF.LayoutOrder = 3
		bodyF.Parent = wrap

		local bodyList = Instance.new("UIListLayout")
		bodyList.SortOrder = Enum.SortOrder.LayoutOrder
		bodyList.Padding = UDim.new(0, UID.BodyListPad)
		bodyList.Parent = bodyF

		local sectionExpanded = expanded
		local function applyChevronSprite(on: boolean)
			if not chevBtn or not specChevExpanded or not specChevCollapsed then
				return
			end
			local spec = if on then specChevExpanded else specChevCollapsed
			applyLucideSprite(chevBtn, spec)
		end
		local function applySectionExpanded(on: boolean)
			sectionExpanded = on
			if not collapsible then
				return
			end
			bodyF.Visible = on
			applyChevronSprite(on)
		end
		local lastSectionToggleClock = 0.0
		local function toggleSectionExpanded()
			local t = os.clock()
			if t - lastSectionToggleClock < 0.08 then
				return
			end
			lastSectionToggleClock = t
			applySectionExpanded(not sectionExpanded)
		end
		if collapsible and headerRow:IsA("TextButton") then
			(headerRow :: TextButton).MouseButton1Click:Connect(toggleSectionExpanded)
		end
		if chevBtn then
			chevBtn.MouseButton1Click:Connect(toggleSectionExpanded)
		end
		if collapsible then
			applySectionExpanded(expanded)
			table.insert(sectionChevronRefreshes, function()
				applyChevronSprite(sectionExpanded)
			end)
		else
			bodyF.Visible = true
		end

		local section = {
			_frame = bodyF,
		}

		--[[ Forward declare: toggle :AddColorPicker calls this before the assignment below. ]]
		local mountColorPicker: (any, any) -> any

		--[[ Save files / other UIs use "None" for unbound; Enum.KeyCode has no None (indexing errors). ]]
		local function enumKeyCodeFromString(raw: string): (Enum.KeyCode, string)
			local t = raw:gsub("^%s+", ""):gsub("%s+$", "")
			if t == "" or string.lower(t) == "none" then
				return Enum.KeyCode.Unknown, ""
			end
			local ok, k = pcall(function()
				return Enum.KeyCode[t]
			end)
			if ok and typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode then
				return k, k.Name
			end
			return Enum.KeyCode.Unknown, ""
		end

		--[[ nil / omitted Default -> RightShift; false, "", or whitespace-only -> unbound (Unknown). ]]
		local function resolveKeybindDefault(defaultField: any): (Enum.KeyCode, string)
			if defaultField == false then
				return Enum.KeyCode.Unknown, ""
			end
			if defaultField == nil then
				return Enum.KeyCode.RightShift, "RightShift"
			end
			if typeof(defaultField) == "string" then
				return enumKeyCodeFromString(defaultField :: string)
			end
			return Enum.KeyCode.RightShift, "RightShift"
		end

		local function keyCapLabel(kcode: Enum.KeyCode, name: string): string
			if kcode == Enum.KeyCode.Unknown or name == "" then
				return "-"
			end
			return name
		end

		--[[ Stack inline widgets right-to-left: [label …][color?][key?][track]. ]]
		local function layoutToggleInlineExtras(row: Frame, label: TextLabel, track: TextButton)
			local TW = UID.ToggleTrackW
			local keyW, keyH = UID.ToggleInlineKeyW, UID.ToggleInlineKeyH
			local colW, colH = UID.ToggleInlineColorW, UID.ToggleInlineColorH
			local g = UID.ToggleInlineKeyGap
			local cap = row:FindFirstChild("ToggleKeybind")
			local sw = row:FindFirstChild("ToggleColorSwatch")
			--[[ Outward from track: color swatch by the switch, then keybind (Obsidian-style). ]]
			local cursor = TW
			if sw and sw:IsA("GuiObject") then
				cursor += g + colW
				sw.Position = UDim2.new(1, -cursor, 0.5, -colH / 2)
			end
			if cap and cap:IsA("GuiObject") then
				cursor += g + keyW
				cap.Position = UDim2.new(1, -cursor, 0.5, -keyH / 2)
			end
			label.Size = UDim2.new(1, -(UID.ToggleLabelReserve + (cursor - TW)), 1, 0)
		end

		local function refreshToggleTooltip(reg: any)
			local tt = reg._toggleTooltip
			if typeof(tt) ~= "string" or tt == "" then
				return
			end
			local trow = reg._toggleRow
			local tlabel = reg._toggleLabel
			local ttrack = reg._toggleTrack
			if not trow or not tlabel or not ttrack then
				return
			end
			local parts: { GuiObject } = { tlabel, ttrack }
			local cap = trow:FindFirstChild("ToggleKeybind")
			local sw = trow:FindFirstChild("ToggleColorSwatch")
			if cap and cap:IsA("GuiObject") then
				table.insert(parts, cap)
			end
			if sw and sw:IsA("GuiObject") then
				table.insert(parts, sw)
			end
			bindTooltipToInstances(parts, tt)
		end

		--[[ Obsidian-style: compact key cap on the toggle row; optional SyncToggleState (default true). ]]
		local function attachInlineKeybindToToggle(
			row: Frame,
			label: TextLabel,
			track: TextButton,
			apply: (boolean) -> (),
			toggleReg: any,
			ko: any
		): any
			if toggleReg._inlineKeyReg ~= nil then
				return toggleReg._inlineKeyReg
			end
			ko = ko or {}
			local kc, keyName = resolveKeybindDefault(ko.Default)
			local TW, TH = UID.ToggleTrackW, UID.ToggleTrackH
			local keyW, keyH = UID.ToggleInlineKeyW, UID.ToggleInlineKeyH
			local gapK = UID.ToggleInlineKeyGap
			local syncToggle = ko.SyncToggleState ~= false

			local capBtn = Instance.new("TextButton")
			capBtn.Name = "ToggleKeybind"
			capBtn.AutoButtonColor = false
			capBtn.Size = UDim2.fromOffset(keyW, keyH)
			capBtn.BackgroundColor3 = Theme.Background
			capBtn.BackgroundTransparency = 0.15
			capBtn.Text = keyCapLabel(kc, keyName)
			capBtn.Font = Enum.Font.GothamBold
			capBtn.TextSize = UID.SliderValText
			capBtn.TextColor3 = Theme.Text
			capBtn.TextTruncate = Enum.TextTruncate.AtEnd
			capBtn:SetAttribute("UiBg", "Background")
			capBtn:SetAttribute("UiText", "Text")
			capBtn.Parent = row
			corner(Theme.CornerSm).Parent = capBtn
			do
				local kp = Instance.new("UIPadding")
				kp.PaddingLeft = UDim.new(0, 4)
				kp.PaddingRight = UDim.new(0, 4)
				kp.Parent = capBtn
			end

			local listening = false
			local keyCbs: { () -> () } = {}
			local bindMode: string = ko.Mode == "Hold" and "Hold" or "Toggle"

			local keyReg: any = {
				Type = "KeyPicker",
				Value = kc,
				Mode = bindMode,
				Modifiers = {},
				Toggled = false,
			}

			local function applyKey(newK: Enum.KeyCode, name: string)
				kc = newK
				keyName = name
				keyReg.Value = kc
				capBtn.Text = keyCapLabel(kc, keyName)
				for _, cb in keyCbs do
					task.spawn(cb)
				end
			end

			local function setBindMode(m: string)
				if m ~= "Toggle" and m ~= "Hold" then
					return
				end
				bindMode = m
				keyReg.Mode = bindMode
				for _, cb in keyCbs do
					task.spawn(cb)
				end
			end

			keyReg.SetValue = function(_: any, v: any)
				if type(v) ~= "table" then
					return
				end
				if typeof(v[1]) == "string" then
					local kc2, nm2 = enumKeyCodeFromString(v[1])
					applyKey(kc2, nm2)
				end
				if typeof(v[2]) == "string" then
					setBindMode(v[2])
				end
			end
			keyReg.OnChanged = function(_: any, cb: () -> ())
				table.insert(keyCbs, cb)
			end

			local function keyMatches(input: InputObject): boolean
				if kc == Enum.KeyCode.Unknown then
					return false
				end
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					return false
				end
				return input.KeyCode == kc
			end

			keyReg.GetState = function(): boolean
				if Library.Unloaded then
					return false
				end
				if bindMode == "Hold" then
					if kc == Enum.KeyCode.Unknown then
						return false
					end
					if UserInputService:GetFocusedTextBox() then
						return false
					end
					return UserInputService:IsKeyDown(kc)
				end
				if syncToggle then
					return toggleReg.Value == true
				end
				return keyReg.Toggled == true
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
					if input.UserInputType == Enum.UserInputType.Keyboard then
						if input.KeyCode == Enum.KeyCode.Escape then
							if capConn then
								capConn:Disconnect()
								capConn = nil
							end
							listening = false
							capBtn.Text = keyCapLabel(kc, keyName)
							return
						end
						if input.KeyCode ~= Enum.KeyCode.Unknown then
							if capConn then
								capConn:Disconnect()
								capConn = nil
							end
							listening = false
							applyKey(input.KeyCode, input.KeyCode.Name)
							if ko.Idx == "MenuKeybind" or ko.NoUI then
								Library.ToggleKeybind = keyReg
							end
						end
					end
				end)
			end)

			capBtn.MouseButton2Click:Connect(function()
				showKeybindModeMenu(capBtn, bindMode, setBindMode)
			end)

			UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
				if Library.Unloaded or listening or gp then
					return
				end
				if not Library.IsRobloxFocused then
					return
				end
				if UserInputService:GetFocusedTextBox() then
					return
				end
				if not keyMatches(input) then
					return
				end
				if syncToggle then
					if bindMode == "Toggle" then
						apply(not toggleReg.Value)
					else
						apply(true)
					end
					return
				end
				if typeof(ko.Callback) == "function" then
					if bindMode == "Toggle" then
						keyReg.Toggled = not keyReg.Toggled
						ko.Callback(keyReg.Toggled)
					else
						ko.Callback(true)
					end
					return
				end
				if bindMode == "Toggle" then
					keyReg.Toggled = not keyReg.Toggled
				end
			end)

			UserInputService.InputEnded:Connect(function(input: InputObject, gp: boolean)
				if Library.Unloaded or listening then
					return
				end
				if bindMode ~= "Hold" then
					return
				end
				if not keyMatches(input) then
					return
				end
				if syncToggle then
					apply(false)
				elseif typeof(ko.Callback) == "function" then
					ko.Callback(false)
				end
			end)

			if ko.Idx == "MenuKeybind" or ko.NoUI then
				Library.ToggleKeybind = keyReg
			end
			if typeof(ko.Idx) == "string" and ko.Idx ~= "" then
				Library.Options[ko.Idx] = keyReg
			end

			if typeof(ko.Tooltip) == "string" and ko.Tooltip ~= "" then
				bindTooltipToInstances({ capBtn }, ko.Tooltip)
			end

			layoutToggleInlineExtras(row, label, track)

			toggleReg._inlineKeyReg = keyReg
			return keyReg
		end

		function section:AddToggle(o: {
			Text: string,
			Default: boolean?,
			Callback: ((boolean) -> ())?,
			Tooltip: string?,
			Idx: string?,
			Keybind: {
				Default: string?,
				Idx: string?,
				Mode: string?,
				SyncToggleState: boolean?,
				NoUI: boolean?,
				Tooltip: string?,
				Callback: ((boolean) -> ())?,
			}?,
		})
			local TW, TH = UID.ToggleTrackW, UID.ToggleTrackH
			local K = UID.ToggleKnob
			local knobHalf = K / 2
			local kOff = UDim2.new(0, 2, 0.5, -knobHalf)
			local kOn = UDim2.new(1, -(2 + K), 0.5, -knobHalf)

			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, UID.ToggleRowH)
			row.Parent = bodyF

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, -UID.ToggleLabelReserve, 1, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamMedium
			label.TextSize = UID.FontWidget
			label.TextColor3 = Theme.Text
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = o.Text
			label:SetAttribute("UiText", "Text")
			label.Parent = row

			local on = o.Default == true
			local track = Instance.new("TextButton")
			track.AutoButtonColor = false
			track.Size = UDim2.fromOffset(TW, TH)
			track.Position = UDim2.new(1, -TW, 0.5, -TH / 2)
			track.BackgroundColor3 = if on then Theme.ToggleOn else Theme.ToggleOff
			track.Text = ""
			track.Parent = row
			corner(UDim.new(1, 0)).Parent = track

			local knob = Instance.new("Frame")
			knob.Size = UDim2.fromOffset(K, K)
			knob.Position = if on then kOn else kOff
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
			reg._toggleRow = row
			reg._toggleLabel = label
			reg._toggleTrack = track
			reg._toggleTooltip = o.Tooltip

			local function apply(v: boolean)
				on = v
				reg.Value = v
				tween(track, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
					BackgroundColor3 = if on then Theme.ToggleOn else Theme.ToggleOff,
				}):Play()
				tween(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
					Position = if on then kOn else kOff,
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

			function reg:AddKeybind(ko: any): any
				local kr = attachInlineKeybindToToggle(row, label, track, apply, reg, ko)
				if typeof(o.Tooltip) == "string" and o.Tooltip ~= "" then
					refreshToggleTooltip(reg)
				elseif typeof(ko.Tooltip) == "string" and ko.Tooltip ~= "" then
					local cap = row:FindFirstChild("ToggleKeybind")
					if cap and cap:IsA("GuiObject") then
						bindTooltipToInstances({ cap }, ko.Tooltip)
					end
				end
				--[[ Return toggle for chaining (:AddKeybind():AddColorPicker()). KeyPicker stays in Library.Options[ko.Idx]. ]]
				return reg
			end

			function reg:AddColorPicker(co: any): any
				if reg._inlineColorReg ~= nil then
					return reg
				end
				co = co or {}
				local cr = mountColorPicker(co, {
					Mode = "toggle",
					row = row,
					label = label,
					track = track,
				})
				reg._inlineColorReg = cr
				if typeof(o.Tooltip) == "string" and o.Tooltip ~= "" then
					refreshToggleTooltip(reg)
				elseif typeof(co.Tooltip) == "string" and co.Tooltip ~= "" then
					local sw = row:FindFirstChild("ToggleColorSwatch")
					if sw and sw:IsA("GuiObject") then
						bindTooltipToInstances({ sw }, co.Tooltip)
					end
				end
				--[[ Return toggle for chaining (:AddColorPicker():AddKeybind()). ColorPicker stays in Library.Options[co.Idx]. ]]
				return reg
			end

			if o.Keybind then
				reg:AddKeybind(o.Keybind)
			elseif typeof(o.Tooltip) == "string" and o.Tooltip ~= "" then
				refreshToggleTooltip(reg)
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
			row.Size = UDim2.new(1, 0, 0, UID.SliderRowH)
			row.Parent = bodyF

			local top = Instance.new("Frame")
			top.Size = UDim2.new(1, 0, 0, UID.SliderTopH)
			top.BackgroundTransparency = 1
			top.Parent = row

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -(UID.SliderValW + 4), 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = UID.SliderLblText
			lbl.TextColor3 = Theme.Text
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = o.Text
			lbl:SetAttribute("UiText", "Text")
			lbl.Parent = top

			local valBox = Instance.new("TextBox")
			valBox.Size = UDim2.fromOffset(UID.SliderValW, UID.SliderValH)
			valBox.Position = UDim2.new(1, -UID.SliderValW, 0, -2)
			valBox.BackgroundColor3 = Theme.Background
			valBox.BackgroundTransparency = 0.15
			valBox.Font = Enum.Font.GothamBold
			valBox.TextSize = UID.SliderValText
			valBox.TextColor3 = Theme.Text
			valBox.Text = tostring(val)
			valBox.ClearTextOnFocus = false
			valBox.TextEditable = true
			valBox.TextXAlignment = Enum.TextXAlignment.Center
			valBox:SetAttribute("UiBg", "Background")
			valBox:SetAttribute("UiText", "Text")
			valBox:SetAttribute("UiPlaceholder", "TextDim")
			valBox.Parent = top
			corner(Theme.CornerSm).Parent = valBox
			pad(4).Parent = valBox
			local valStroke = stroke(Theme.Stroke, 1, 0.65)
			valStroke:SetAttribute("UiStroke", "Stroke")
			valStroke.Parent = valBox

			local track = Instance.new("Frame")
			track.Name = "Track"
			track.Size = UDim2.new(1, 0, 0, UID.SliderTrackH)
			track.Position = UDim2.new(0, 0, 0, UID.SliderTrackY)
			track.BackgroundColor3 = Theme.SliderTrack
			track:SetAttribute("UiBg", "SliderTrack")
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
			--[[ Filter option rows while the list is open (search box at top of dropdown). ]]
			Searchable: boolean?,
			--[[ Max option rows visible before scrolling (default 5; clamped 3–24). ]]
			MaxVisibleItems: number?,
		})
			local allowNull = o.AllowNull == true
			local searchable = o.Searchable == true
			local maxVisibleItems = math.clamp(
				if typeof(o.MaxVisibleItems) == "number" then math.floor(o.MaxVisibleItems :: number) else 5,
				3,
				24
			)
			local multi = if o.Multi ~= nil then (o.Multi == true) else dropdownMultiDefault
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
			lbl.Size = UDim2.new(1, 0, 0, UID.DropLblH)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = UID.InputLblText
			lbl.TextColor3 = Theme.TextDim
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = o.Text
			lbl:SetAttribute("UiText", "TextDim")
			lbl.Parent = row

			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, UID.DropBtnH)
			btn.Position = UDim2.new(0, 0, 0, UID.DropBtnY)
			btn.BackgroundColor3 = Theme.Elevated
			btn.BackgroundTransparency = 0.1
			btn.AutoButtonColor = false
			btn.Font = Enum.Font.GothamMedium
			btn.TextSize = UID.DropBtnText
			btn.TextColor3 = Theme.Text
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.Text = "  " .. summary()
			btn:SetAttribute("UiBg", "Elevated")
			btn:SetAttribute("UiText", "Text")
			btn.Parent = row
			corner(Theme.CornerSm).Parent = btn
			pad(UID.DropBtnPad).Parent = btn

			local chev = Instance.new("TextLabel")
			chev.Size = UDim2.fromOffset(UID.DropChev, UID.DropChev)
			chev.Position = UDim2.new(1, -(UID.DropChev + 4), 0.5, -UID.DropChev / 2)
			chev.BackgroundTransparency = 1
			chev.Text = "▼"
			chev.TextSize = 10
			chev.TextColor3 = Theme.TextDim
			chev:SetAttribute("UiText", "TextDim")
			chev.Parent = btn

			local listF = Instance.new("Frame")
			listF.Size = UDim2.new(1, 0, 0, 0)
			listF.AutomaticSize = Enum.AutomaticSize.Y
			listF.Position = UDim2.new(0, 0, 0, UID.DropListY)
			listF.BackgroundColor3 = Theme.Background
			listF.BackgroundTransparency = 0.05
			listF.Visible = false
			listF.ZIndex = 5
			listF:SetAttribute("UiBg", "Background")
			listF.Parent = row
			corner(Theme.CornerSm).Parent = listF
			local listStroke = stroke(Theme.Stroke, 1, 0.7)
			listStroke:SetAttribute("UiStroke", "Stroke")
			listStroke.Parent = listF

			pad(6).Parent = listF
			local stackLay = Instance.new("UIListLayout")
			stackLay.FillDirection = Enum.FillDirection.Vertical
			stackLay.SortOrder = Enum.SortOrder.LayoutOrder
			stackLay.Padding = UDim.new(0, 6)
			stackLay.Parent = listF

			local scrollList = Instance.new("ScrollingFrame")
			scrollList.Name = "DropdownScroll"
			scrollList.BackgroundTransparency = 1
			scrollList.BorderSizePixel = 0
			scrollList.Size = UDim2.new(1, -12, 0, 120)
			scrollList.ScrollBarThickness = 4
			scrollList.ScrollBarImageColor3 = Theme.AccentBlue
			scrollList.ScrollingDirection = Enum.ScrollingDirection.Y
			scrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y
			scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
			scrollList.ZIndex = 6
			scrollList.LayoutOrder = 2
			scrollList.ClipsDescendants = true
			scrollList.Parent = listF

			local innerList = Instance.new("UIListLayout")
			innerList.SortOrder = Enum.SortOrder.LayoutOrder
			innerList.Padding = UDim.new(0, 2)
			innerList.Parent = scrollList

			local OPT_ROW_H = UID.DropOptRow
			local LIST_GAP = 2
			local function optionsBlockHeight(n: number): number
				if n <= 0 then
					return OPT_ROW_H
				end
				return n * OPT_ROW_H + (n - 1) * LIST_GAP
			end
			local function syncScrollViewport()
				local n = 0
				for _, ch in scrollList:GetChildren() do
					if ch:IsA("TextButton") then
						n = n + 1
					end
				end
				local contentH = optionsBlockHeight(n)
				local capH = optionsBlockHeight(maxVisibleItems)
				local viewH = math.clamp(math.min(contentH, capH), OPT_ROW_H, capH)
				scrollList.Size = UDim2.new(1, -12, 0, viewH)
			end

			local searchBox: TextBox? = nil
			if searchable then
				local searchRow = Instance.new("Frame")
				searchRow.Name = "DropdownSearch"
				searchRow.BackgroundTransparency = 1
				searchRow.Size = UDim2.new(1, -12, 0, UID.DropSearchH)
				searchRow.LayoutOrder = 1
				searchRow.Parent = listF
				local sb = Instance.new("TextBox")
				sb.Name = "Search"
				sb.Size = UDim2.new(1, 0, 1, 0)
				sb.BackgroundColor3 = Theme.Elevated
				sb.BackgroundTransparency = 0.12
				sb.ClearTextOnFocus = false
				sb.Font = Enum.Font.GothamMedium
				sb.TextSize = 12
				sb.TextColor3 = Theme.Text
				sb.PlaceholderText = "Search…"
				sb.PlaceholderColor3 = Theme.TextDim
				sb.Text = ""
				sb:SetAttribute("UiBg", "Elevated")
				sb:SetAttribute("UiText", "Text")
				sb:SetAttribute("UiPlaceholder", "TextDim")
				sb.Parent = searchRow
				corner(Theme.CornerSm).Parent = sb
				pad(8).Parent = sb
				searchBox = sb
			end

			local open = false
			local optionButtonMap: { [string]: TextButton } = {}

			local function filteredOptions(): { string }
				if not searchable or not searchBox or searchBox.Text == "" then
					return options
				end
				local q = string.lower(searchBox.Text)
				local out: { string } = {}
				for _, opt in options do
					if string.find(string.lower(opt), q, 1, true) then
						table.insert(out, opt)
					end
				end
				return out
			end

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
				for _, ch in scrollList:GetChildren() do
					if ch:IsA("TextButton") then
						ch:Destroy()
					end
				end
			end

			local function buildOptionButtons()
				clearOptionButtons()
				for _, opt in filteredOptions() do
					local optBtn = Instance.new("TextButton")
					optBtn.Size = UDim2.new(1, -12, 0, OPT_ROW_H)
					optBtn.AutoButtonColor = false
					optBtn.Font = Enum.Font.GothamMedium
					optBtn.TextSize = UID.DropBtnText
					optBtn.TextXAlignment = Enum.TextXAlignment.Left
					optBtn.ZIndex = 7
					optBtn:SetAttribute("UiBg", "Elevated")
					optBtn:SetAttribute("UiText", "Text")
					optBtn.Parent = scrollList
					corner(UDim.new(0, 4)).Parent = optBtn
					pad(UID.DropBtnPad).Parent = optBtn
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
				syncScrollViewport()
				scrollList.CanvasPosition = Vector2.zero
			end

			buildOptionButtons()

			if searchBox then
				searchBox:GetPropertyChangedSignal("Text"):Connect(function()
					if open then
						buildOptionButtons()
						refreshOptionVisuals()
					end
				end)
			end

			btn.MouseButton1Click:Connect(function()
				open = not open
				if open and searchBox then
					searchBox.Text = ""
					buildOptionButtons()
					refreshOptionVisuals()
				end
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
			row.Size = UDim2.new(1, 0, 0, UID.InputRowH)
			row.Parent = bodyF

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 0, UID.InputLblH)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = UID.InputLblText
			lbl.TextColor3 = Theme.TextDim
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = o.Text
			lbl:SetAttribute("UiText", "TextDim")
			lbl.Parent = row

			local box = Instance.new("TextBox")
			box.Size = UDim2.new(1, 0, 0, UID.InputBoxH)
			box.Position = UDim2.new(0, 0, 0, UID.InputBoxY)
			box.BackgroundColor3 = Theme.Elevated
			box.BackgroundTransparency = 0.1
			box.ClearTextOnFocus = false
			box.Font = Enum.Font.GothamMedium
			box.TextSize = UID.InputBoxText
			box.TextColor3 = Theme.Text
			box.PlaceholderText = o.Placeholder or ""
			box.PlaceholderColor3 = Theme.TextDim
			box.Text = o.Default or ""
			box:SetAttribute("UiBg", "Elevated")
			box:SetAttribute("UiText", "Text")
			box:SetAttribute("UiPlaceholder", "TextDim")
			box.Parent = row
			corner(Theme.CornerSm).Parent = box
			pad(UID.InputBoxPad).Parent = box

			local inputCbs: { (string) -> () } = {}
			local reg: any = { Type = "Input", Value = box.Text }

			local function sync()
				reg.Value = box.Text
			end

			box:GetPropertyChangedSignal("Text"):Connect(function()
				sync()
			end)

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
			d:SetAttribute("UiBg", "Stroke")
			d.Parent = bodyF
		end

		function section:AddSpacer(height: number)
			local h = math.max(0, math.floor(height + 0.5))
			local s = Instance.new("Frame")
			s.Name = "Spacer"
			s.BackgroundTransparency = 1
			s.Size = UDim2.new(1, 0, 0, h)
			s.Parent = bodyF
		end

		function section:AddLabel(textOrOpts: any, wrap: boolean?, idx: string?)
			local text = ""
			local doesWrap = wrap == true
			local idxStr: string? = nil
			local centered = false
			local labelTextSize: number? = nil
			if type(textOrOpts) == "table" then
				text = tostring(textOrOpts.Text or "")
				doesWrap = textOrOpts.DoesWrap == true
				idxStr = textOrOpts.Idx
				centered = textOrOpts.Centered == true
				if typeof(textOrOpts.TextSize) == "number" then
					labelTextSize = textOrOpts.TextSize
				end
			else
				text = tostring(textOrOpts)
				idxStr = if typeof(idx) == "string" then idx else nil
			end
			local lab = Instance.new("TextLabel")
			lab.BackgroundTransparency = 1
			lab.Font = Enum.Font.GothamMedium
			lab.TextSize = labelTextSize or UID.AddLabelText
			lab.TextColor3 = Theme.TextDim
			lab.TextXAlignment = if centered then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
			lab.TextYAlignment = Enum.TextYAlignment.Top
			lab.TextWrapped = doesWrap
			lab.AutomaticSize = if doesWrap then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
			lab.Size = UDim2.new(1, 0, 0, if doesWrap then 0 else UID.AddLabelH)
			lab.Text = text
			lab:SetAttribute("UiText", "TextDim")
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
			b.Size = UDim2.new(1, 0, 0, UID.ButtonH)
			b.BackgroundColor3 = Theme.Elevated
			b.BackgroundTransparency = 0.1
			b.AutoButtonColor = not disabled
			b.Text = text
			b.Font = Enum.Font.GothamMedium
			b.TextSize = UID.DropBtnText
			b.TextColor3 = if disabled then Theme.TextDim else Theme.Text
			b:SetAttribute("UiBg", "Elevated")
			b:SetAttribute("UiText", if disabled then "TextDim" else "Text")
			b.Parent = bodyF
			corner(Theme.CornerSm).Parent = b
			do
				local bp = Instance.new("UIPadding")
				bp.PaddingLeft = UDim.new(0, UID.DropBtnPad)
				bp.PaddingRight = UDim.new(0, UID.DropBtnPad)
				bp.Parent = b
			end
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
			Mode: string?,
			Callback: ((boolean) -> ())?,
		})
			o = o or {}
			local kc, keyName = resolveKeybindDefault(o.Default)
			local bindMode: string = o.Mode == "Hold" and "Hold" or "Toggle"
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, UID.KeyRowH)
			row.Parent = bodyF
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -(UID.KeyCapW + 12), 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = UID.FontWidget
			lbl.TextColor3 = Theme.Text
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = o.Text or "Keybind"
			lbl:SetAttribute("UiText", "Text")
			lbl.Parent = row
			local capBtn = Instance.new("TextButton")
			capBtn.Size = UDim2.fromOffset(UID.KeyCapW, UID.KeyCapH)
			capBtn.Position = UDim2.new(1, -UID.KeyCapW, 0.5, -UID.KeyCapH / 2)
			capBtn.BackgroundColor3 = Theme.Background
			capBtn.BackgroundTransparency = 0.15
			capBtn.Text = keyCapLabel(kc, keyName)
			capBtn.Font = Enum.Font.GothamBold
			capBtn.TextSize = UID.SliderValText
			capBtn.TextColor3 = Theme.Text
			capBtn.AutoButtonColor = false
			capBtn:SetAttribute("UiBg", "Background")
			capBtn:SetAttribute("UiText", "Text")
			capBtn.Parent = row
			corner(Theme.CornerSm).Parent = capBtn

			local listening = false
			local keyCbs: { () -> () } = {}
			local reg: any = {
				Type = "KeyPicker",
				Value = kc,
				Mode = bindMode,
				Modifiers = {},
				Toggled = false,
			}

			local function applyKey(newK: Enum.KeyCode, name: string)
				kc = newK
				keyName = name
				reg.Value = kc
				capBtn.Text = keyCapLabel(kc, keyName)
				for _, cb in keyCbs do
					task.spawn(cb)
				end
			end

			local function setBindMode(m: string)
				if m ~= "Toggle" and m ~= "Hold" then
					return
				end
				bindMode = m
				reg.Mode = bindMode
				for _, cb in keyCbs do
					task.spawn(cb)
				end
			end

			reg.SetValue = function(_: any, v: any)
				if type(v) ~= "table" then
					return
				end
				if typeof(v[1]) == "string" then
					local kc2, nm2 = enumKeyCodeFromString(v[1])
					applyKey(kc2, nm2)
				end
				if typeof(v[2]) == "string" then
					setBindMode(v[2])
				end
			end
			reg.OnChanged = function(_: any, cb: () -> ())
				table.insert(keyCbs, cb)
			end

			local function keyMatches(input: InputObject): boolean
				if kc == Enum.KeyCode.Unknown then
					return false
				end
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					return false
				end
				return input.KeyCode == kc
			end

			reg.GetState = function(): boolean
				if Library.Unloaded then
					return false
				end
				if bindMode == "Hold" then
					if kc == Enum.KeyCode.Unknown then
						return false
					end
					if UserInputService:GetFocusedTextBox() then
						return false
					end
					return UserInputService:IsKeyDown(kc)
				end
				return reg.Toggled == true
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
					if input.UserInputType == Enum.UserInputType.Keyboard then
						if input.KeyCode == Enum.KeyCode.Escape then
							if capConn then
								capConn:Disconnect()
								capConn = nil
							end
							listening = false
							capBtn.Text = keyCapLabel(kc, keyName)
							return
						end
						if input.KeyCode ~= Enum.KeyCode.Unknown then
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
					end
				end)
			end)

			capBtn.MouseButton2Click:Connect(function()
				showKeybindModeMenu(capBtn, bindMode, setBindMode)
			end)

			UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
				if Library.Unloaded or listening or gp then
					return
				end
				if not Library.IsRobloxFocused then
					return
				end
				if UserInputService:GetFocusedTextBox() then
					return
				end
				if not keyMatches(input) then
					return
				end
				if typeof(o.Callback) == "function" then
					if bindMode == "Toggle" then
						reg.Toggled = not reg.Toggled
						o.Callback(reg.Toggled)
					else
						o.Callback(true)
					end
					return
				end
				if bindMode == "Toggle" then
					reg.Toggled = not reg.Toggled
				end
			end)

			UserInputService.InputEnded:Connect(function(input: InputObject, gp: boolean)
				if Library.Unloaded or listening then
					return
				end
				if bindMode ~= "Hold" then
					return
				end
				if not keyMatches(input) then
					return
				end
				if typeof(o.Callback) == "function" then
					o.Callback(false)
				end
			end)

			if o.Idx == "MenuKeybind" or o.NoUI then
				Library.ToggleKeybind = reg
			end
			if typeof(o.Idx) == "string" and o.Idx ~= "" then
				Library.Options[o.Idx] = reg
			end

			return reg
		end

		mountColorPicker = function(
			o: {
				Text: string?,
				Default: Color3?,
				Transparency: number?,
				Idx: string?,
				Callback: ((Color3) -> ())?,
				Tooltip: string?,
			},
			mount: { Mode: "section", bodyParent: Instance }
				| { Mode: "toggle", row: Frame, label: TextLabel, track: TextButton }
		)
			o = o or {}
			local col = o.Default or Color3.fromRGB(255, 255, 255)
			local alpha = 1 - (o.Transparency or 0)
			local sectionMode = mount.Mode == "section"

			local row: Frame
			local lbl: TextLabel?
			local bar: Frame?
			local hexBox: TextBox?
			local swBtn: TextButton

			if sectionMode then
				row = Instance.new("Frame")
				row.BackgroundTransparency = 1
				row.Size = UDim2.new(1, 0, 0, UID.ColorRowH)
				row.Parent = (mount :: any).bodyParent

				lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 0, UID.ColorLblH)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamMedium
				lbl.TextSize = UID.InputLblText
				lbl.TextColor3 = Theme.TextDim
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Text = o.Text or "Color"
				lbl:SetAttribute("UiText", "TextDim")
				lbl.Parent = row

				bar = Instance.new("Frame")
				bar.Name = "ColorBar"
				bar.BackgroundTransparency = 1
				bar.Size = UDim2.new(1, 0, 0, UID.ColorBarH)
				bar.Position = UDim2.new(0, 0, 0, UID.ColorBarY)
				bar.Parent = row

				hexBox = Instance.new("TextBox")
				hexBox.Size = UDim2.new(1, -(UID.ColorSwatch + 6), 1, 0)
				hexBox.Position = UDim2.fromScale(0, 0)
				hexBox.BackgroundColor3 = Theme.Elevated
				hexBox.BackgroundTransparency = 0.1
				hexBox.Text = string.upper(col:ToHex())
				hexBox.PlaceholderText = "RRGGBB"
				hexBox.PlaceholderColor3 = Theme.TextDim
				hexBox.Font = Enum.Font.GothamMedium
				hexBox.TextSize = 12
				hexBox.TextColor3 = Theme.Text
				hexBox.ClearTextOnFocus = false
				hexBox:SetAttribute("UiBg", "Elevated")
				hexBox:SetAttribute("UiText", "Text")
				hexBox:SetAttribute("UiPlaceholder", "TextDim")
				hexBox.Parent = bar
				corner(Theme.CornerSm).Parent = hexBox
				pad(6).Parent = hexBox

				swBtn = Instance.new("TextButton")
				swBtn.Name = "Swatch"
				swBtn.AnchorPoint = Vector2.new(1, 0)
				swBtn.Size = UDim2.fromOffset(UID.ColorSwatch, UID.ColorBarH)
				swBtn.Position = UDim2.new(1, 0, 0, 0)
				swBtn.BackgroundColor3 = col
				swBtn.BackgroundTransparency = 1 - alpha
				swBtn.Text = ""
				swBtn.AutoButtonColor = false
				swBtn.ZIndex = 2
				--[[ No UiBg on swatch: theme paint would force Elevated and hide the picked color ]]
				swBtn.Parent = bar
				corner(Theme.CornerSm).Parent = swBtn
				local swStroke = stroke(Theme.Stroke, 1, 0.5)
				swStroke:SetAttribute("UiStroke", "Stroke")
				swStroke.Parent = swBtn
			else
				local tm = mount :: any
				row = tm.row
				lbl = nil
				bar = nil
				hexBox = nil
				swBtn = Instance.new("TextButton")
				swBtn.Name = "ToggleColorSwatch"
				swBtn.AutoButtonColor = false
				local cw, ch = UID.ToggleInlineColorW, UID.ToggleInlineColorH
				swBtn.Size = UDim2.fromOffset(cw, ch)
				swBtn.BackgroundColor3 = col
				swBtn.BackgroundTransparency = 1 - alpha
				swBtn.Text = ""
				swBtn.ZIndex = 2
				swBtn.Parent = row
				corner(Theme.CornerSm).Parent = swBtn
				local swStrokeT = stroke(Theme.Stroke, 1, 0.5)
				swStrokeT:SetAttribute("UiStroke", "Stroke")
				swStrokeT.Parent = swBtn
				layoutToggleInlineExtras(row, tm.label, tm.track)
			end

			local colorCbs: { (Color3) -> () } = {}
			local reg: any = {
				Type = "ColorPicker",
				Value = col,
				Transparency = o.Transparency or 0,
			}

			local hueN, satN, valN = col:ToHSV()
			local fillRgbBoxesRef: (() -> ())? = nil
			local syncHsVisualRef: (() -> ())? = nil

			local function syncSwatch()
				swBtn.BackgroundColor3 = col
				swBtn.BackgroundTransparency = 1 - alpha
			end

			local popOpen = false

			local function applyColor(c: Color3)
				local newHex = string.upper(c:ToHex())
				local prevHex = string.upper(col:ToHex())
				if newHex == prevHex then
					return
				end
				col = c
				reg.Value = col
				syncSwatch()
				if hexBox then
					hexBox.Text = newHex
				end
				if popOpen then
					hueN, satN, valN = col:ToHSV()
					if syncHsVisualRef then
						syncHsVisualRef()
					end
					if fillRgbBoxesRef then
						fillRgbBoxesRef()
					end
				end
				--[[ Obsidian: synchronous Changed/Callback — avoids task backlog + matches ThemeManager:UpdateColorsUsingRegistry cadence. ]]
				for _, cb in colorCbs do
					pcall(cb, col)
				end
				if o.Callback then
					pcall(o.Callback, col)
				end
			end

			local function tryParseHexInput()
				if not hexBox then
					return
				end
				local parsed = parseHexColor(hexBox.Text)
				if parsed then
					applyColor(parsed)
				else
					hexBox.Text = string.upper(col:ToHex())
				end
			end

			if hexBox then
				hexBox.FocusLost:Connect(function()
					tryParseHexInput()
				end)
			end

			--[[ Obsidian-style HSV surface (rbxassetid://4155801252 saturation map) + RGB fields ]]
			local SATURATION_MAP_ASSET = "rbxassetid://4155801252"
			local popCloseConn: RBXScriptConnection? = nil

			local function isColorPickerDragInput(input: InputObject): boolean
				if not Library.IsRobloxFocused then
					return false
				end
				if
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return false
				end
				return input.UserInputState == Enum.UserInputState.Begin
					or input.UserInputState == Enum.UserInputState.Change
			end

			local pop = Instance.new("Frame")
			pop.Name = "ColorPickerPop"
			pop.AutomaticSize = Enum.AutomaticSize.Y
			pop.Size = UDim2.fromOffset(260, 0)
			pop.BackgroundColor3 = Theme.Elevated
			pop.BackgroundTransparency = 0.04
			pop.Visible = false
			pop.ZIndex = 2500
			pop.Parent = screenGui
			corner(Theme.CornerSm).Parent = pop
			stroke(Theme.Stroke, 1, 0.45).Parent = pop
			local popPad = Instance.new("UIPadding")
			popPad.PaddingLeft = UDim.new(0, 8)
			popPad.PaddingRight = UDim.new(0, 8)
			popPad.PaddingTop = UDim.new(0, 8)
			popPad.PaddingBottom = UDim.new(0, 8)
			popPad.Parent = pop
			local popList = Instance.new("UIListLayout")
			popList.SortOrder = Enum.SortOrder.LayoutOrder
			popList.Padding = UDim.new(0, 8)
			popList.Parent = pop

			local svRow = Instance.new("Frame")
			svRow.BackgroundTransparency = 1
			svRow.Size = UDim2.new(1, 0, 0, 168)
			svRow.LayoutOrder = 1
			svRow.ZIndex = 2501
			svRow.Parent = pop
			local svList = Instance.new("UIListLayout")
			svList.FillDirection = Enum.FillDirection.Horizontal
			svList.SortOrder = Enum.SortOrder.LayoutOrder
			svList.Padding = UDim.new(0, 8)
			svList.VerticalAlignment = Enum.VerticalAlignment.Center
			svList.Parent = svRow

			local satMap = Instance.new("ImageButton")
			satMap.Name = "SaturationValue"
			satMap.AutoButtonColor = false
			satMap.Size = UDim2.fromOffset(168, 168)
			satMap.BackgroundColor3 = Color3.fromHSV(hueN, 1, 1)
			satMap.Image = SATURATION_MAP_ASSET
			satMap.ScaleType = Enum.ScaleType.Stretch
			satMap.ZIndex = 2502
			satMap.LayoutOrder = 1
			satMap.Parent = svRow
			corner(Theme.CornerSm).Parent = satMap

			local satCursor = Instance.new("Frame")
			satCursor.AnchorPoint = Vector2.new(0.5, 0.5)
			satCursor.BackgroundColor3 = Color3.new(1, 1, 1)
			satCursor.BorderSizePixel = 0
			satCursor.Size = UDim2.fromOffset(6, 6)
			satCursor.ZIndex = 2503
			satCursor.Parent = satMap
			corner(UDim.new(1, 0)).Parent = satCursor
			stroke(Theme.Stroke, 1, 0.3).Parent = satCursor

			local hueSel = Instance.new("TextButton")
			hueSel.Name = "Hue"
			hueSel.AutoButtonColor = false
			hueSel.Size = UDim2.fromOffset(22, 168)
			hueSel.Text = ""
			hueSel.ZIndex = 2502
			hueSel.LayoutOrder = 2
			hueSel.Parent = svRow
			corner(Theme.CornerSm).Parent = hueSel
			local hueGrad = Instance.new("UIGradient")
			hueGrad.Color = ColorPickerHueSequence
			hueGrad.Rotation = 90
			hueGrad.Parent = hueSel

			local hueCursor = Instance.new("Frame")
			hueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
			hueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
			hueCursor.BorderSizePixel = 0
			hueCursor.Position = UDim2.new(0.5, 0, hueN, 0)
			hueCursor.Size = UDim2.new(1, 4, 0, 3)
			hueCursor.ZIndex = 2503
			hueCursor.Parent = hueSel
			corner(UDim.new(0, 2)).Parent = hueCursor
			stroke(Color3.new(0, 0, 0), 1, 0.2).Parent = hueCursor

			local function syncHsVisual()
				satMap.BackgroundColor3 = Color3.fromHSV(hueN, 1, 1)
				satCursor.Position = UDim2.fromScale(satN, 1 - valN)
				hueCursor.Position = UDim2.new(0.5, 0, hueN, 0)
			end
			syncHsVisualRef = syncHsVisual

			local function pointerXY(): (number, number)
				--[[ Match Obsidian / AbsolutePosition: PlayerMouse aligns with AbsolutePosition; GetMouseLocation can be offset (e.g. GuiInset). ]]
				if UserInputService.MouseEnabled then
					return PlayerMouse.X, PlayerMouse.Y
				end
				local v = UserInputService:GetMouseLocation()
				return v.X, v.Y
			end

			local function sampleSatVal()
				local ax, ay = satMap.AbsolutePosition.X, satMap.AbsolutePosition.Y
				local sx, sy = satMap.AbsoluteSize.X, satMap.AbsoluteSize.Y
				local px, py = pointerXY()
				local oldSat, oldVal = satN, valN
				satN = math.clamp((px - ax) / math.max(sx, 1e-4), 0, 1)
				valN = 1 - math.clamp((py - ay) / math.max(sy, 1e-4), 0, 1)
				if satN ~= oldSat or valN ~= oldVal then
					applyColor(Color3.fromHSV(hueN, satN, valN))
				end
				syncHsVisual()
			end

			local function sampleHue()
				local ay = hueSel.AbsolutePosition.Y
				local sy = hueSel.AbsoluteSize.Y
				local _, py = pointerXY()
				local oldHue = hueN
				hueN = math.clamp((py - ay) / math.max(sy, 1e-4), 0, 1)
				if hueN ~= oldHue then
					applyColor(Color3.fromHSV(hueN, satN, valN))
				end
				syncHsVisual()
			end

			satMap.InputBegan:Connect(function(input: InputObject)
				if
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end
				while isColorPickerDragInput(input) and popOpen do
					sampleSatVal()
					RunService.RenderStepped:Wait()
				end
			end)

			hueSel.InputBegan:Connect(function(input: InputObject)
				if
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end
				while isColorPickerDragInput(input) and popOpen do
					sampleHue()
					RunService.RenderStepped:Wait()
				end
			end)

			local function rgbRow(labelText: string, layoutOrder: number): TextBox
				local wrap = Instance.new("Frame")
				wrap.BackgroundTransparency = 1
				wrap.Size = UDim2.new(1, 0, 0, 26)
				wrap.LayoutOrder = layoutOrder
				wrap.ZIndex = 2501
				wrap.Parent = pop
				local lab = Instance.new("TextLabel")
				lab.Size = UDim2.fromOffset(22, 26)
				lab.BackgroundTransparency = 1
				lab.Font = Enum.Font.GothamBold
				lab.TextSize = 12
				lab.TextColor3 = Theme.TextDim
				lab.Text = labelText
				lab.TextXAlignment = Enum.TextXAlignment.Left
				lab.ZIndex = 2501
				lab.Parent = wrap
				local box = Instance.new("TextBox")
				box.Size = UDim2.new(1, -28, 1, 0)
				box.Position = UDim2.new(0, 28, 0, 0)
				box.BackgroundColor3 = Theme.Elevated
				box.BackgroundTransparency = 0.1
				box.Font = Enum.Font.GothamMedium
				box.TextSize = 12
				box.TextColor3 = Theme.Text
				box.ClearTextOnFocus = false
				box.ZIndex = 2501
				box.Parent = wrap
				corner(Theme.CornerSm).Parent = box
				pad(6).Parent = box
				return box
			end

			local rBox = rgbRow("R", 2)
			local gBox = rgbRow("G", 3)
			local bBox = rgbRow("B", 4)

			local function fillRgbBoxes()
				rBox.Text = tostring(math.floor(col.R * 255 + 0.5))
				gBox.Text = tostring(math.floor(col.G * 255 + 0.5))
				bBox.Text = tostring(math.floor(col.B * 255 + 0.5))
			end
			fillRgbBoxesRef = fillRgbBoxes

			local function tryApplyRgb()
				local r = tonumber(rBox.Text)
				local g = tonumber(gBox.Text)
				local b = tonumber(bBox.Text)
				if r and g and b then
					applyColor(
						Color3.fromRGB(math.clamp(math.floor(r), 0, 255), math.clamp(math.floor(g), 0, 255), math.clamp(math.floor(b), 0, 255))
					)
				else
					fillRgbBoxes()
				end
			end

			rBox.FocusLost:Connect(tryApplyRgb)
			gBox.FocusLost:Connect(tryApplyRgb)
			bBox.FocusLost:Connect(tryApplyRgb)

			local doneBtn = Instance.new("TextButton")
			doneBtn.Size = UDim2.new(1, 0, 0, 26)
			doneBtn.LayoutOrder = 5
			doneBtn.BackgroundColor3 = Theme.AccentBlue
			doneBtn.BackgroundTransparency = 0.15
			doneBtn.Text = "Done"
			doneBtn.TextColor3 = Theme.Text
			doneBtn.TextSize = 12
			doneBtn.Font = Enum.Font.GothamBold
			doneBtn.AutoButtonColor = false
			doneBtn.ZIndex = 2501
			doneBtn.Parent = pop
			corner(Theme.CornerSm).Parent = doneBtn

			local function closePop()
				popOpen = false
				pop.Visible = false
				if popCloseConn then
					popCloseConn:Disconnect()
					popCloseConn = nil
				end
			end

			local function openPop()
				hueN, satN, valN = col:ToHSV()
				syncHsVisual()
				fillRgbBoxes()
				local ap = swBtn.AbsolutePosition
				local sz = swBtn.AbsoluteSize
				pop.AnchorPoint = Vector2.new(0, 0)
				pop.Position = UDim2.fromOffset(math.floor(ap.X), math.floor(ap.Y + sz.Y + 4))
				pop.Visible = true
				popOpen = true
				if popCloseConn then
					popCloseConn:Disconnect()
				end
				popCloseConn = UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
					if gp or not popOpen or not pop.Visible then
						return
					end
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
						return
					end
					local p = Vector2.new(input.Position.X, input.Position.Y)
					local function inside(g: GuiObject): boolean
						local a, s = g.AbsolutePosition, g.AbsoluteSize
						return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
					end
					if inside(pop) or inside(swBtn) or (hexBox and inside(hexBox)) then
						return
					end
					closePop()
				end)
			end

			swBtn.MouseButton1Click:Connect(function()
				if popOpen then
					closePop()
				else
					openPop()
				end
			end)

			if hexBox then
				do
					local lastHexTap = 0.0
					hexBox.InputBegan:Connect(function(input: InputObject)
						if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
							return
						end
						if input.UserInputState ~= Enum.UserInputState.Begin then
							return
						end
						local t = os.clock()
						if t - lastHexTap < 0.35 then
							lastHexTap = 0
							if popOpen then
								closePop()
							else
								openPop()
							end
						else
							lastHexTap = t
						end
					end)
				end
			end

			doneBtn.MouseButton1Click:Connect(function()
				tryApplyRgb()
				closePop()
			end)

			reg.SetValueRGB = function(_: any, c: Color3, trans: number?)
				col = c
				reg.Value = col
				if typeof(trans) == "number" then
					reg.Transparency = trans
					alpha = 1 - trans
				end
				syncSwatch()
				if hexBox then
					hexBox.Text = string.upper(col:ToHex())
				end
				fillRgbBoxes()
				if popOpen then
					hueN, satN, valN = col:ToHSV()
					syncHsVisual()
				end
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

		function section:AddColorPicker(o: {
			Text: string,
			Default: Color3?,
			Transparency: number?,
			Idx: string?,
			Callback: ((Color3) -> ())?,
			Tooltip: string?,
		})
			return mountColorPicker(o, { Mode = "section", bodyParent = bodyF })
		end

		return section
	end

	function Tab:AddLeftTabbox(boxTitle: string?)
		local parentScroll: Instance
		local layoutOrder: number
		if self._split and self._scrollLeft then
			parentScroll = self._scrollLeft
			self._sectionOrderLeft += 1
			layoutOrder = self._sectionOrderLeft
		else
			parentScroll = self._scroll
			self._sectionOrder += 1
			layoutOrder = self._sectionOrder
		end
		return makeTabbox(parentScroll, layoutOrder, boxTitle)
	end

	function Tab:AddRightTabbox(boxTitle: string?)
		local parentScroll: Instance
		local layoutOrder: number
		if self._split and self._scrollRight then
			parentScroll = self._scrollRight
			self._sectionOrderRight += 1
			layoutOrder = self._sectionOrderRight
		else
			parentScroll = self._scroll
			self._sectionOrder += 1
			layoutOrder = self._sectionOrder
		end
		return makeTabbox(parentScroll, layoutOrder, boxTitle)
	end

	function Tab:AddLeftGroupbox(
		header: string,
		sectionOpts: { Collapsible: boolean?, DefaultExpanded: boolean?, Tooltip: string?, Icon: (number | string)? }?
	)
		local o: any = if sectionOpts then table.clone(sectionOpts) else {}
		if self._split then
			o.Column = "Left"
		end
		return Tab.AddSection(self, header, o)
	end

	function Tab:AddRightGroupbox(
		header: string,
		sectionOpts: { Collapsible: boolean?, DefaultExpanded: boolean?, Tooltip: string?, Icon: (number | string)? }?
	)
		local o: any = if sectionOpts then table.clone(sectionOpts) else {}
		if self._split then
			o.Column = "Right"
		end
		return Tab.AddSection(self, header, o)
	end

	--[[ Built-in Info tab (mspaint-style): one full-width CHANGELOG group, centered body text. Tab index 1. ]]
	if config.InfoTab ~= false then
		local infoIcon = config.InfoTabIcon
		if infoIcon == nil then
			infoIcon = "info"
		end
		local infoTab = window:AddTab({
			Name = "Info",
			Icon = infoIcon,
			Tooltip = "Info",
			SplitColumns = false,
		})
		local changelogSection = infoTab:AddSection("Change logs", {
			Collapsible = false,
			DefaultExpanded = true,
			Icon = "scroll-text",
		})
		changelogSection:AddLabel({
			Text = typeof(config.InfoChangelog) == "string" and config.InfoChangelog ~= "" and config.InfoChangelog
				or defaultInfoChangelog,
			DoesWrap = true,
			Centered = true,
			TextSize = 14,
		})
		--[[ Tall body so the group reads as a full “page” like mspaint’s info view ]]
		changelogSection:AddSpacer(160)
	end

	return window
end

return Library
