if not game:IsLoaded() then
	game.Loaded:Wait()
end

local repo = "https://raw.githubusercontent.com/justhereforagoodtime42/library/refs/heads/main/"
local Library = loadstring(game:HttpGet(repo .. "main.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "thememanager"))()
local SaveManager = loadstring(game:HttpGet(repo .. "savemanager"))()

local Options = Library.Options
local Toggles = Library.Toggles

;(getgenv or function()
	return shared
end)().AcidHubLibrary = Library

if getgenv().AcidHub then
	Library:Notify("Script is already loaded")
	return
end
getgenv().AcidHub = true

local Window = Library.new({
	Title = "AcidHub",
	Subtitle = "Game | Version: 1.0 | discord.gg/acidhub",
	TitleIcon = 114741603622587,
	Size = Vector2.new(760, 620),
	NotifySide = "Right",
	MultiDropdownByDefault = false,
})


local Tabs = {
	Main = Window:AddTab({ Name = "Main", Icon = "user", SplitColumns = true }),
	["UI Settings"] = Window:AddTab({ Name = "UI Settings", Icon = "settings", SplitColumns = true }),
}

-- [[ Variables ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local RunService = game:GetService("RunService")
local Root = Character:WaitForChild("HumanoidRootPart")
local humanoid = Character.Humanoid
local UIS = game:GetService("UserInputService")

-- [[ Anti Afk ]] --
for _, v in ipairs(getconnections(Players.LocalPlayer.Idled)) do
	v:Disable()
end
Library:Notify("Anti-Afk is enabled", 3)

-- [[ Groupboxes ]]
local MovementGroupBox = Tabs.Main:AddRightGroupbox("Movement", { Icon = "person-standing" })

-- [[ Movement Logic ]]
local cameraFlightCF = CFrame.new()
local MovementSettings = {
	flightConnection = nil,
	speedConnection = nil,
	infJumpConnection = nil,
	noclipConnection = nil,
	noclipOriginalCollisions = {},
	FlightSpeed = 50,
	WalkSpeed = 16,
}

local function Flight()
	if Character and Root and humanoid then
		if not cameraFlightCF then
			cameraFlightCF = CFrame.new(Root.CFrame.Position)
		end

		local camCF = workspace.CurrentCamera.CFrame
		local speed = MovementSettings.FlightSpeed
		local force = Vector3.new(0, 0, 0)

		if UIS:IsKeyDown(Enum.KeyCode.W) then
			force = force + (camCF.LookVector * speed)
		end
		if UIS:IsKeyDown(Enum.KeyCode.S) then
			force = force - (camCF.LookVector * speed)
		end
		if UIS:IsKeyDown(Enum.KeyCode.A) then
			force = force - (camCF.RightVector * speed)
		end
		if UIS:IsKeyDown(Enum.KeyCode.D) then
			force = force + (camCF.RightVector * speed)
		end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then
			force = force + (camCF.UpVector * speed)
		end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
			force = force - (camCF.UpVector * speed)
		end

		force = force * RunService.Heartbeat:Wait()
		cameraFlightCF = cameraFlightCF * CFrame.new(force)
		Root.CFrame = CFrame.lookAt(cameraFlightCF.Position, camCF.Position + (camCF.LookVector * 10000))
		Root.Velocity = Vector3.new(0, 0, 0)
	end
end

local function TpWalk()
	if Character and Root and humanoid then
		if humanoid.MoveDirection.Magnitude > 0 then
			local delta = RunService.Heartbeat:Wait()
			local speedMultiplier = MovementSettings.WalkSpeed / 16
			Character:TranslateBy(humanoid.MoveDirection * speedMultiplier * delta * 10)
		end
	end
end

local function setCollisions(enabled)
	if not Character then
		return
	end

	for _, part in ipairs(Character:GetDescendants()) do
		if part:IsA("BasePart") then
			if not enabled then
				if MovementSettings.noclipOriginalCollisions[part] == nil then
					MovementSettings.noclipOriginalCollisions[part] = part.CanCollide
				end
				part.CanCollide = false
			else
				local originalState = MovementSettings.noclipOriginalCollisions[part]
				if originalState ~= nil then
					part.CanCollide = originalState
					MovementSettings.noclipOriginalCollisions[part] = nil
				else
					part.CanCollide = true
				end
			end
		end
	end
end

local function ToggleNoclip(enabled)
	if MovementSettings.noclipConnection then
		MovementSettings.noclipConnection:Disconnect()
		MovementSettings.noclipConnection = nil
	end

	if enabled then
		setCollisions(false)
		MovementSettings.noclipConnection = RunService.Heartbeat:Connect(function()
			if MovementSettings.noclipConnection then
				if Character then
					for _, part in ipairs(Character:GetDescendants()) do
						if part:IsA("BasePart") and part.CanCollide then
							if MovementSettings.noclipOriginalCollisions[part] == nil then
								MovementSettings.noclipOriginalCollisions[part] = true
							end
							part.CanCollide = false
						end
					end
				end
			end
		end)
	else
		setCollisions(true)
	end
end

MovementGroupBox:AddToggle({ Idx = "Flight", Text = "Flight", Default = false })
Toggles.Flight:OnChanged(function(Value)
	if MovementSettings.flightConnection then
		MovementSettings.flightConnection:Disconnect()
		MovementSettings.flightConnection = nil
	end
	cameraFlightCF = nil

	if Value then
		MovementSettings.flightConnection = RunService.Heartbeat:Connect(Flight)
	end
end)

MovementGroupBox:AddToggle({ Idx = "WalkSpeed", Text = "Walk Speed", Default = false })
Toggles.WalkSpeed:OnChanged(function(Value)
	if MovementSettings.speedConnection then
		MovementSettings.speedConnection:Disconnect()
		MovementSettings.speedConnection = nil
	end

	if Value then
		MovementSettings.speedConnection = RunService.Heartbeat:Connect(TpWalk)
	end
end)

MovementGroupBox:AddToggle({ Idx = "InfJump", Text = "Inf Jump", Default = false })
Toggles.InfJump:OnChanged(function(Value)
	if MovementSettings.infJumpConnection then
		MovementSettings.infJumpConnection:Disconnect()
		MovementSettings.infJumpConnection = nil
	end

	if Value then
		MovementSettings.infJumpConnection = UIS.JumpRequest:Connect(function()
			if Character and humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end
end)

MovementGroupBox:AddToggle({ Idx = "Noclip", Text = "Noclip", Default = false })
Toggles.Noclip:OnChanged(function(Value)
	ToggleNoclip(Value)
end)

MovementGroupBox:AddSlider({
	Idx = "FlightSpeed",
	Text = "Flight Value",
	Default = 16,
	Min = 0,
	Max = 500,
	Rounding = 0,
	Callback = function(value)
		MovementSettings.FlightSpeed = value
	end,
})

MovementGroupBox:AddSlider({
	Idx = "WalkSpeed",
	Text = "Speed Value",
	Default = 16,
	Min = 0,
	Max = 500,
	Rounding = 0,
	Callback = function(value)
		MovementSettings.WalkSpeed = value
	end,
})

-- UI Settings
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", { Icon = "wrench" })

MenuGroup:AddDropdown({
	Text = "Notification Side",
	Options = { "Left", "Right" },
	Default = "Right",
	Idx = "NotificationSide",
	Callback = function(Value: string)
		Library:SetNotifySide(Value)
	end,
})

MenuGroup:AddToggle({
	Idx = "HideUIOnLoad",
	Text = "Hide UI on load",
	Default = false,
})

MenuGroup:AddToggle({
	Text = "Custom Cursor",
	Default = Library.ShowCustomCursor == true,
	Idx = "CustomCursorToggle",
	Callback = function(value: boolean)
		Library:SetCursorEnabled(value)
	end,
}):AddColorPicker({
	Default = Library.CursorColor or Color3.new(1, 1, 1),
	Idx = "CustomCursorColor",
	Tooltip = "Color of the custom cursor.",
	Callback = function(color: Color3)
		Library:SetCursorColor(color)
	end,
})

MenuGroup:AddToggle({
	Text = "Show watermark",
	Default = true,
	Idx = "Watermark",
	Callback = function(value: boolean)
		Library:SetWatermarkEnabled(value)
	end,
})

MenuGroup:AddDivider()
MenuGroup:AddKeybind({
	Text = "Menu keybind",
	Default = "RightShift",
	Idx = "MenuKeybind",
	NoUI = true,
})

MenuGroup:AddButton({
	Text = "Unload",
	Func = function()
		getgenv().AcidHub = false
		Library:Unload()
	end,
})

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:SetFolder("AcidHub")
SaveManager:SetFolder("AcidHub/Game")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()
