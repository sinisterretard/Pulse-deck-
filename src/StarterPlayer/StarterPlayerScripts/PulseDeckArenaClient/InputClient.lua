--!strict

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))
local UIClient = require(script.Parent:WaitForChild("UIClient"))
local CameraClient = require(script.Parent:WaitForChild("CameraClient"))
local SettingsClient = require(script.Parent:WaitForChild("SettingsClient"))

local InputClient = {}

local firing = false
local lastFireSent = 0
local ultimateRequested = false
local lastSwitchTime = 0
local inputDebounce = 0.15

local function sendFire()
	local camera = workspace.CurrentCamera
	if not camera then return end
	ClientCore.Fire("RequestFire", {
		origin = camera.CFrame.Position,
		direction = camera.CFrame.LookVector,
		clientTime = os.clock(),
	})
end

local function isChatFocused()
	-- Check if any UI element has keyboard focus
	local guiService = game:GetService("GuiService")
	return guiService:IsFocused()
end

function InputClient.Init()
	-- Mobile touch controls
	if UserInputService.TouchEnabled then
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local gui = playerGui:WaitForChild("PulseDeckArenaGui")
		local hud = gui:WaitForChild("HUD")

		local function mobileButton(text, position, color, size)
			local button = Instance.new("TextButton")
			button.Text = text
			button.Size = size or UDim2.new(0, 92, 0, 92)
			button.Position = position
			button.BackgroundColor3 = color
			button.TextColor3 = Color3.fromRGB(255, 255, 255)
			button.Font = Enum.Font.GothamBlack
			button.TextSize = 18
			button.TextScaled = true
			button.Parent = hud

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = button

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(255, 255, 255, 80)
			stroke.Thickness = 1.5
			stroke.Parent = button

			return button
		end

		-- Fire button
		local fireButton = mobileButton("🔥 FIRE", UDim2.new(0, -110, 1, -164),
			Color3.fromRGB(210, 55, 55), UDim2.new(0, 92, 0, 72))
		fireButton.MouseButton1Down:Connect(function()
			firing = true
			sendFire()
		end)
		fireButton.MouseButton1Up:Connect(function()
			firing = false
		end)

		-- Ability button
		local abilityButton = mobileButton("⚡ [Q]", UDim2.new(0, -214, 1, -90),
			Color3.fromRGB(60, 120, 230), UDim2.new(0, 92, 0, 68))
		abilityButton.MouseButton1Click:Connect(function()
			local camera = workspace.CurrentCamera
			ClientCore.Fire("RequestAbility", {
				direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
			})
		end)

		-- Ultimate button
		local ultimateButton = mobileButton("💀 [E]", UDim2.new(0, -118, 1, -266),
			Color3.fromRGB(160, 40, 200), UDim2.new(0, 92, 0, 68))
		ultimateButton.MouseButton1Click:Connect(function()
			ClientCore.Fire("RequestUltimate", {})
		end)

		-- Reload button
		local reloadButton = mobileButton("🔄 [R]", UDim2.new(0, -112, 1, -360),
			Color3.fromRGB(90, 90, 130), UDim2.new(0, 92, 0, 68))
		reloadButton.MouseButton1Click:Connect(function()
			ClientCore.Fire("RequestReload", {})
		end)

		-- Camera mode toggle
		local camButton = mobileButton("📷", UDim2.new(0, -214, 1, -360),
			Color3.fromRGB(80, 170, 150), UDim2.new(0, 92, 0, 68))
		camButton.MouseButton1Click:Connect(function()
			CameraClient.ToggleMode()
		end)

		-- Hero switch buttons (1-5)
		for i = 1, 5 do
			local btn = mobileButton(tostring(i),
				UDim2.new(0, -370 + (i-1) * 60, 1, -164),
				Color3.fromRGB(40, 44, 60), UDim2.new(0, 52, 0, 52))
			btn.TextSize = 22
			btn.MouseButton1Click:Connect(function()
				ClientCore.Fire("RequestSwitchHero", { slot = i })
			end)
		end
	end

	-- Keyboard & mouse input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if isChatFocused() then return end

		local function isAction(name)
			return SettingsClient.Bindings[name] == input.KeyCode or SettingsClient.Bindings[name] == input.UserInputType
		end

		if isAction("Fire") then
			firing = true
			sendFire()
		elseif isAction("Reload") then
			ClientCore.Fire("RequestReload", {})
		elseif isAction("Ability") then
			local camera = workspace.CurrentCamera
			ClientCore.Fire("RequestAbility", {
				direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1),
			})
		elseif isAction("Ultimate") then
			local hero = ClientCore.State.heroes and ClientCore.State.heroes[1]
			if ClientCore.State.gameMode == "Bomb" then
				ClientCore.Fire("RequestPlant", {sitePosition = (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position) or Vector3.new(0, 0, 0)})
			else
				local currentTime = os.clock()
				if currentTime - ultimateRequested > 1.0 then
					ultimateRequested = currentTime
					ClientCore.Fire("RequestUltimate", {})
				end
			end
		elseif isAction("Power") then
			ClientCore.Fire("RequestPower", { powerId = "speedBoost" })
		elseif isAction("Switch1") then
			ClientCore.Fire("RequestSwitchHero", { slot = 1 })
		elseif isAction("Switch2") then
			ClientCore.Fire("RequestSwitchHero", { slot = 2 })
		elseif isAction("Switch3") then
			ClientCore.Fire("RequestSwitchHero", { slot = 3 })
		elseif isAction("Switch4") then
			ClientCore.Fire("RequestSwitchHero", { slot = 4 })
		elseif isAction("Switch5") then
			ClientCore.Fire("RequestSwitchHero", { slot = 5 })
		elseif isAction("Camera") then
			CameraClient.ToggleMode()
		elseif isAction("Scoreboard") then
			ClientCore.Fire("RequestScoreboard", {})
		elseif isAction("Pause") then
			if UIClient.ShowPauseMenu then
				UIClient:ShowPauseMenu()
			end
		elseif isAction("Ready") then
			ClientCore.Fire("RequestReady", {})
		elseif isAction("SpectateNext") then
			CameraClient.FindNextSpectateTarget()
		elseif isAction("SpectateMode") then
			CameraClient.ToggleSpectateMode()
		elseif isAction("SpectateToggle") then
			if CameraClient.Spectating then
				CameraClient.ExitSpectate()
			else
				CameraClient.EnterSpectate()
			end
		elseif isAction("Emote") then
			if UIClient.EmoteFrame then
				UIClient.EmoteFrame.Visible = not UIClient.EmoteFrame.Visible
			end
		elseif isAction("Practice") then
			if UIClient.PracticeFrame then
				UIClient.PracticeFrame.Visible = not UIClient.PracticeFrame.Visible
			end
		elseif isAction("Shop") then
			if UIClient.ShopFrame then
				UIClient.ShopFrame.Visible = not UIClient.ShopFrame.Visible
			end
			if ClientCore.State.gameMode == "Bomb" and not (UIClient.ShopFrame and UIClient.ShopFrame.Visible) then
				ClientCore.Fire("RequestBuyMenu", {})
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		end
	end)

	-- Auto-fire support
	local autoFireConnection
	RunService.RenderStepped:Connect(function()
		if firing and os.clock() - lastFireSent >= 0.05 then
			lastFireSent = os.clock()
			sendFire()
		end

		-- Auto-fire for automatic weapons when mouse held
		if autoFireConnection and firing then
			sendFire()
		end
	end)
end

return InputClient