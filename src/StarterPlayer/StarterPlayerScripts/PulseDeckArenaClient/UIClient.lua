--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))
local Config = require(sharedRoot:WaitForChild("Config"))
local AbilityConfig = require(sharedRoot:WaitForChild("AbilityConfig"))
local ProgressionUtils = require(sharedRoot:WaitForChild("ProgressionUtils"))

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))

local UIClient = {}

UIClient.Gui = nil
UIClient.MainMenu = nil
UIClient.DeckSelect = nil
UIClient.HUD = nil
UIClient.Scoreboard = nil
UIClient.PostMatch = nil
UIClient.PauseMenu = nil
UIClient.SelectedDeck = {}
UIClient.HeroButtons = {}
UIClient.AbilityButtons = {}
UIClient.HealthBarFill = nil
UIClient.ShieldBarFill = nil
UIClient.AmmoLabel = nil
UIClient.TimerLabel = nil
UIClient.KillfeedContainer = nil
UIClient.Notifications = nil
UIClient.HUDTargets = {}
UIClient.HUDSmoothing = {}

-----------------------------------------------------
-- HELPER FUNCTIONS
-----------------------------------------------------

local function createRoundedFrame(parent, name, size, pos, color, transparency, cornerRadius)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = pos
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cornerRadius or 8)
	corner.Parent = frame

	return frame
end

local function createTextLabel(parent, text, size, pos, fontSize, color, font)
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.fromRGB(245, 245, 255)
	label.Font = font or Enum.Font.GothamBold
	label.TextSize = fontSize or 14
	label.TextScaled = false
	label.Parent = parent
	return label
end

local function createTextButton(parent, text, size, pos, color, hoverColor)
	local button = Instance.new("TextButton")
	button.Text = text
	button.Size = size
	button.Position = pos
	button.BackgroundColor3 = color or Color3.fromRGB(35, 180, 140)
	button.TextColor3 = Color3.fromRGB(10, 10, 12)
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 16
	button.TextScaled = false
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 80)
	stroke.Thickness = 1
	stroke.Parent = button

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = hoverColor or Color3.fromRGB(45, 200, 160)
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = color or Color3.fromRGB(35, 180, 140)
	end)

	return button
end

local function createProgressBar(parent, size, pos, color, bgColor)
	local bg = Instance.new("Frame")
	bg.Size = size
	bg.Position = pos
	bg.BackgroundColor3 = bgColor or Color3.fromRGB(20, 20, 30, 180)
	bg.BorderSizePixel = 0
	bg.Parent = parent
	local corner1 = Instance.new("UICorner")
	corner1.CornerRadius = UDim.new(0, 4)
	corner1.Parent = bg

	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = true
	container.Parent = bg

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color or Color3.fromRGB(80, 200, 120)
	fill.BorderSizePixel = 0
	fill.Parent = container

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(color, Color3.new(color.R * 0.7, color.G * 0.7, color.B * 0.7))
	grad.Rotation = 90
	grad.Parent = fill

	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0, 4)
	corner2.Parent = fill

	return bg, fill
end

-----------------------------------------------------
-- MAIN MENU
-----------------------------------------------------

function UIClient.BuildMainMenu()
	local screen = UIClient.MainMenu

	-- Background
	createRoundedFrame(screen, "BG", UDim2.fromScale(1, 1), UDim2.new(0, 0, 0, 0),
		Color3.fromRGB(10, 12, 18), 0, 0)

	local title = createTextLabel(screen, "⚡ PULSE DECK ARENA ⚡",
		UDim2.new(1, 0, 0, 100), UDim2.new(0, 0, 0, 30), 48, Color3.fromRGB(255, 222, 35))
	title.Font = Enum.Font.GothamBlack

	local subtitle = createTextLabel(screen, "v2.0 • Advanced Arena Shooter",
		UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 135), 18, Color3.fromRGB(150, 160, 180))

	-- Stats display
	local progression = ClientCore.State.progression
	local level = ProgressionUtils.GetLevel(progression.XP or 0)
	local statsText = string.format(
		"Wins: %d | Coins: %d | XP: %d | Level: %d",
		progression.Wins or 0,
		progression.Coins or 0,
		progression.XP or 0,
		level
	)
	createTextLabel(screen, statsText,
		UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 170), 16, Color3.fromRGB(180, 190, 200), Enum.Font.GothamSemibold)

	-- PLAY button
	local playBtn = createTextButton(screen, "⚔ PLAY MATCH ⚔",
		UDim2.new(0, 280, 0, 64), UDim2.new(0.5, -140, 0.42, 0),
		Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 120, 100))
	playBtn.Font = Enum.Font.GothamBlack
	playBtn.TextSize = 22
	playBtn.MouseButton1Click:Connect(function()
		UIClient.Show("DeckSelect")
	end)

	-- Quick play button
	local quickBtn = createTextButton(screen, "⚡ QUICK PLAY (Solo + Bots)",
		UDim2.new(0, 280, 0, 50), UDim2.new(0.5, -140, 0.53, 0),
		Color3.fromRGB(60, 140, 100), Color3.fromRGB(80, 170, 130))
	quickBtn.MouseButton1Click:Connect(function()
		ClientCore.Fire("RequestJoinQueue", {})
	end)

	-- Settings button
	local settingsBtn = createTextButton(screen, "⚙ SETTINGS",
		UDim2.new(0, 160, 0, 44), UDim2.new(0.5, -80, 0.75, 0),
		Color3.fromRGB(60, 60, 80), Color3.fromRGB(80, 80, 110))
	settingsBtn.TextSize = 14
	settingsBtn.MouseButton1Click:Connect(function()
		UIClient.ShowSettings()
	end)

	-- Ready button
	local readyBtn = createTextButton(screen, "✅ READY UP",
		UDim2.new(0, 200, 0, 50), UDim2.new(0.5, -100, 0.65, 0),
		Color3.fromRGB(60, 160, 80), Color3.fromRGB(80, 200, 100))
	readyBtn.Font = Enum.Font.GothamBlack
	readyBtn.TextSize = 16
	readyBtn.MouseButton1Click:Connect(function()
		ClientCore.Fire("RequestReady", {})
	end)

	-- Game mode buttons
	local modesFrame = createRoundedFrame(screen, "ModesFrame",
		UDim2.new(0.8, 0, 0, 60), UDim2.new(0.1, 0, 0.67, -30),
		Color3.fromRGB(15, 17, 25), 0.5, 10)

	createTextLabel(modesFrame, "GAME MODES",
		UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 2), 14,
		Color3.fromRGB(160, 170, 190), Enum.Font.GothamSemibold)

	local modes = {"Standard", "FFA", "KOTH"}
	for i, mode in ipairs(modes) do
		local btn = createTextButton(modesFrame, mode,
			UDim2.new(0.3, -8, 0, 30), UDim2.new((i-1)/3 + 0.04, 0, 0.45, 0),
			Color3.fromRGB(40, 45, 60), Color3.fromRGB(60, 70, 90))
		btn.TextSize = 14
		btn.Font = Enum.Font.GothamSemibold
		btn.MouseButton1Click:Connect(function()
			ClientCore.Fire("RequestGameMode", {mode = mode})
		end)
	end

	-- Footer
	createTextLabel(screen, "Controls: WASD Move | Mouse Aim | LMB Fire | R Reload | Q Ability | E Ultimate | 1-5 Switch | V Camera",
		UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 1, -34), 12, Color3.fromRGB(80, 80, 100), Enum.Font.Gotham)
end

-----------------------------------------------------
-- DECK SELECT
-----------------------------------------------------

function UIClient.BuildDeckSelect()
	local screen = UIClient.DeckSelect

	createRoundedFrame(screen, "BG", UDim2.fromScale(1, 1), UDim2.new(0, 0, 0, 0),
		Color3.fromRGB(10, 12, 18), 0, 0)

	local title = createTextLabel(screen, "SELECT YOUR 5-HERO DECK",
		UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 0, 20), 40, Color3.fromRGB(255, 222, 35))
	title.Font = Enum.Font.GothamBlack

	-- Preset buttons
	local presetFrame = createRoundedFrame(screen, "Presets",
		UDim2.new(0.8, 0, 0, 50), UDim2.new(0.1, 0, 0, 80),
		Color3.fromRGB(20, 22, 32), 0, 8)

	local presets = {
		{name = "⚔ Assault", desc = "DPS focused", ids = {"bolt_runner", "nova", "glitch_byte", "fuse_jack", "reaper"}, color = Color3.fromRGB(200, 60, 60)},
		{name = "🛡 Defense", desc = "Tank & support", ids = {"iron_bulwark", "terra_pin", "wisp_ion", "vesper_scope", "bastion"}, color = Color3.fromRGB(60, 120, 200)},
		{name = "⚖ Balanced", desc = "Well rounded", ids = {"bolt_runner", "iron_bulwark", "vesper_scope", "patch_flux", "fuse_jack"}, color = Color3.fromRGB(60, 180, 100)},
	}

	for i, preset in ipairs(presets) do
		local btn = createTextButton(presetFrame, preset.name .. "  (" .. preset.desc .. ")",
			UDim2.new(0.3, -8, 0, 36), UDim2.new((i-1) * 0.34 + 0.01, 0, 0.25, 0),
			preset.color, Color3.new(preset.color.R * 1.2, preset.color.G * 1.2, preset.color.B * 1.2))
		btn.TextSize = 13
		btn.MouseButton1Click:Connect(function()
			UIClient.SelectedDeck = {}
			for _, hid in ipairs(preset.ids) do
				table.insert(UIClient.SelectedDeck, hid)
			end
			UIClient.UpdateDeckGrid()
		end)
	end

	-- Hero grid
	local gridFrame = createRoundedFrame(screen, "GridHolder",
		UDim2.new(0.9, 0, 0.45, 0), UDim2.new(0.05, 0, 0.2, 0),
		Color3.fromRGB(15, 17, 25), 0.3, 10)

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "HeroGrid"
	grid.Size = UDim2.fromScale(1, 1)
	grid.Position = UDim2.new(0, 8, 0, 8)
	grid.BackgroundTransparency = 1
	grid.ScrollBarThickness = 4
	grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	grid.Parent = gridFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 180, 0, 130)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local heroCards = {}

	local function buildGrid()
		local heroes = {}
		for id, _ in pairs(HeroConfig) do
			table.insert(heroes, id)
		end
		table.sort(heroes)

		for i, heroId in ipairs(heroes) do
			local heroDef = HeroConfig[heroId]
			local order = i

			local card = Instance.new("Frame")
			card.Name = heroId
			card.Size = UDim2.fromScale(1, 1)
			card.BackgroundColor3 = heroDef.primaryColor
			card.BorderSizePixel = 0
			card.LayoutOrder = order
			card.Parent = grid

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = card

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(60, 60, 80)
			stroke.Thickness = 1.5
			stroke.Parent = card

			-- Hero name
			createTextLabel(card, heroDef.displayName,
				UDim2.new(1, -8, 0, 22), UDim2.new(0, 4, 0, 4), 13, Color3.fromRGB(250, 250, 255), Enum.Font.GothamBold)

			-- Role badge
			local roleColors = {
				Assault = Color3.fromRGB(200, 60, 60),
				Tank = Color3.fromRGB(60, 120, 200),
				Sniper = Color3.fromRGB(150, 60, 220),
				Support = Color3.fromRGB(60, 200, 120),
				Demolition = Color3.fromRGB(220, 120, 40),
				Skirmisher = Color3.fromRGB(220, 50, 200),
				Engineer = Color3.fromRGB(200, 160, 60),
				Controller = Color3.fromRGB(40, 160, 200),
				Flanker = Color3.fromRGB(180, 100, 60),
				Mage = Color3.fromRGB(200, 60, 150),
				Defender = Color3.fromRGB(100, 100, 120),
			}
			local roleColor = roleColors[heroDef.role] or Color3.fromRGB(100, 100, 100)
			local roleBadge = createRoundedFrame(card, "Role",
				UDim2.new(0, 60, 0, 18), UDim2.new(1, -68, 0, 4),
				roleColor, 0.8, 4)
			createTextLabel(roleBadge, heroDef.role,
				UDim2.fromScale(1, 1), UDim2.new(0, 0, 0, 0), 9, Color3.fromRGB(240, 240, 255), Enum.Font.GothamSemibold)

			-- Stats
			createTextLabel(card,
				string.format("HP %d | SPD %d | DIFF %d", heroDef.maxHealth, heroDef.walkSpeed, heroDef.difficulty),
				UDim2.new(1, -8, 0, 16), UDim2.new(0, 4, 0, 28), 10, Color3.fromRGB(180, 190, 200), Enum.Font.Gotham)

			-- Description
			createTextLabel(card, heroDef.shortDescription,
				UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 46), 10, Color3.fromRGB(150, 160, 170), Enum.Font.Gotham)

			-- Weapon name
			local weaponName = WeaponConfig[heroDef.weaponId] and WeaponConfig[heroDef.weaponId].displayName or "Unknown"
			createTextLabel(card, "🔫 " .. weaponName,
				UDim2.new(1, -8, 0, 14), UDim2.new(0, 4, 1, -40), 10, Color3.fromRGB(120, 180, 255), Enum.Font.GothamSemibold)

			-- Selection overlay
			local selectOverlay = createRoundedFrame(card, "SelectOverlay",
				UDim2.fromScale(1, 1), UDim2.new(0, 0, 0, 0),
				Color3.fromRGB(0, 0, 0), 0.7, 8)

			createTextLabel(selectOverlay, "✓ SELECTED",
				UDim2.fromScale(1, 1), UDim2.new(0, 0, 0, 0), 16, Color3.fromRGB(100, 255, 150), Enum.Font.GothamBold)

			local isSelected = table.find(UIClient.SelectedDeck, heroId) ~= nil
			selectOverlay.Visible = isSelected

			local button = Instance.new("TextButton")
			button.Size = UDim2.fromScale(1, 1)
			button.BackgroundTransparency = 1
			button.Text = ""
			button.Parent = card

			button.MouseButton1Click:Connect(function()
				local selected = table.find(UIClient.SelectedDeck, heroId)
				if selected then
					table.remove(UIClient.SelectedDeck, selected)
					selectOverlay.Visible = false
				elseif #UIClient.SelectedDeck < Config.DECK_SIZE then
					table.insert(UIClient.SelectedDeck, heroId)
					selectOverlay.Visible = true
				end
				if UIClient.DeckCountLabel then
					UIClient.DeckCountLabel.Text = #UIClient.SelectedDeck .. " / " .. Config.DECK_SIZE .. " selected"
				end
			end)

			button.MouseEnter:Connect(function()
				card.BackgroundColor3 = Color3.new(
					math.min(card.BackgroundColor3.R * 1.15, 1),
					math.min(card.BackgroundColor3.G * 1.15, 1),
					math.min(card.BackgroundColor3.B * 1.15, 1)
				)
			end)
			button.MouseLeave:Connect(function()
				card.BackgroundColor3 = heroDef.primaryColor
			end)
		end

		grid.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#heroes / 4) * 140 + 20)
	end

	buildGrid()

	-- Deck count display
	local countFrame = createRoundedFrame(screen, "CountFrame",
		UDim2.new(0, 250, 0, 40), UDim2.new(0.5, -125, 0, 620),
		Color3.fromRGB(25, 28, 42), 0.4, 10)

	UIClient.DeckCountLabel = createTextLabel(countFrame,
		"0 / " .. Config.DECK_SIZE .. " selected",
		UDim2.fromScale(1, 1), UDim2.new(0, 0, 0, 0), 18,
		Color3.fromRGB(200, 200, 220), Enum.Font.GothamBold)

	-- Confirm button
	local confirmBtn = createTextButton(screen, "CONFIRM DECK & START MATCH",
		UDim2.new(0.3, 0, 0, 56), UDim2.new(0.35, 0, 0.92, 0),
		Color3.fromRGB(60, 180, 100), Color3.fromRGB(80, 210, 130))
	confirmBtn.Font = Enum.Font.GothamBlack
	confirmBtn.TextSize = 18
	confirmBtn.MouseButton1Click:Connect(function()
		if #UIClient.SelectedDeck == Config.DECK_SIZE then
			ClientCore.Fire("RequestDeckUpdate", { heroIds = UIClient.SelectedDeck })
			ClientCore.Fire("RequestStartMatch", {})
		end
	end)

	-- Back button
	local backBtn = createTextButton(screen, "← BACK",
		UDim2.new(0.15, 0, 0, 44), UDim2.new(0.05, 0, 0.925, 0),
		Color3.fromRGB(60, 60, 80), Color3.fromRGB(80, 80, 110))
	backBtn.MouseButton1Click:Connect(function()
		UIClient.Show("MainMenu")
	end)

	-- Skin selector
	local skinBtn = createTextButton(screen, "🎨 SKINS",
		UDim2.new(0.15, 0, 0, 44), UDim2.new(0.85, 0, 0.925, 0),
		Color3.fromRGB(120, 60, 180), Color3.fromRGB(160, 90, 220))
	skinBtn.TextSize = 14
	skinBtn.Font = Enum.Font.GothamSemibold
	skinBtn.MouseButton1Click:Connect(function()
		UIClient.ShowSkinPanel()
	end)
end

function UIClient.UpdateDeckGrid()
	if not UIClient.DeckSelect then return end
	local gridHolder = UIClient.DeckSelect:FindFirstChild("GridHolder")
	if not gridHolder then return end
	local grid = gridHolder:FindFirstChild("HeroGrid")
	if not grid then return end

	for _, card in ipairs(grid:GetChildren()) do
		if card:IsA("Frame") and card:FindFirstChild("SelectOverlay") then
			local heroId = card.Name
			local isSelected = table.find(UIClient.SelectedDeck, heroId) ~= nil
			card.SelectOverlay.Visible = isSelected
		end
	end

	if UIClient.DeckCountLabel then
		UIClient.DeckCountLabel.Text = #UIClient.SelectedDeck .. " / " .. Config.DECK_SIZE .. " selected"
	end
end

-----------------------------------------------------
-- SKIN PANEL
-----------------------------------------------------

function UIClient.ShowSkinPanel()
	-- Remove existing skin panel
	if UIClient.SkinPanel then
		UIClient.SkinPanel:Destroy()
	end

	local screen = UIClient.SkinPanel

	local bg = createRoundedFrame(nil, "SkinPanel",
		UDim2.new(0.7, 0, 0.8, 0),
		UDim2.new(0.15, 0, 0.1, 0),
		Color3.fromRGB(8, 10, 18, 240), 0.3, 12)
	bg.Parent = UIClient.Gui
	Instance.new("UICorner", bg)

	-- Title
	createTextLabel(bg, "SKIN SELECTION",
		UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 5),
		22, Color3.fromRGB(255, 222, 35), Enum.Font.GothamBlack)

	-- Close button
	local closeBtn = createTextButton(bg, "✕",
		UDim2.new(0, 40, 0, 36), UDim2.new(1, -50, 0, 8),
		Color3.fromRGB(180, 50, 50), Color3.fromRGB(220, 70, 70))
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.MouseButton1Click:Connect(function()
		bg:Destroy()
		UIClient.SkinPanel = nil
	end)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0.9, 0, 0.55, -40)
	frame.Position = UDim2.new(0.05, 0, 0.15, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = bg

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame

	local heroId = (UIClient.SelectedDeck and #UIClient.SelectedDeck > 0)
		and UIClient.SelectedDeck[1] or "bolt_runner"
	local heroDef = HeroConfig[heroId]
	local skins = heroDef and heroDef.skins or {}
	local progression = ClientCore.State and ClientCore.State.progression

	for skinId, skinDef in pairs(skins) do
		local entry = Instance.new("Frame")
		entry.Size = UDim2.new(1, 0, 0, 60)
		entry.BackgroundColor3 = Color3.fromRGB(20, 22, 35)
		entry.BorderSizePixel = 0
		entry.LayoutOrder = (skinId == "default") and 0 or 1
		Instance.new("UICorner", entry).CornerRadius = UDim.new(0, 6)
		entry.Parent = frame

		local outline = Instance.new("UIStroke")
		outline.Color = Color3.fromRGB(60, 60, 80)
		outline.Thickness = 1
		outline.Parent = entry

		-- Rarity badge
		local rarity = skinDef.rarity or "Default"
		local rarityColors = {
			Default = Color3.fromRGB(160, 160, 170),
			Common = Color3.fromRGB(180, 180, 180),
			Rare = Color3.fromRGB(70, 130, 255),
			Epic = Color3.fromRGB(180, 80, 220),
			Legendary = Color3.fromRGB(255, 200, 50),
		}
		local rColor = rarityColors[rarity] or rarityColors.Default

		local badge = createRoundedFrame(entry, "RarityBadge",
			UDim2.new(0, 80, 0, 24), UDim2.new(0, 8, 0.5, -12),
			rColor, 0.8, 4)
		createTextLabel(badge, rarity,
			UDim2.fromScale(1, 1), UDim2.new(0, 0, 0, 0), 11,
			Color3.fromRGB(10, 10, 15), Enum.Font.GothamBold)

		-- Skin name
		createTextLabel(entry, skinId:gsub("^%l", string.upper),
			UDim2.new(0.35, -8, 1, 0), UDim2.new(0, 96, 0, 0), 15,
			Color3.fromRGB(240, 240, 250), Enum.Font.GothamSemibold)

		-- Cost
		local cost = 0
		if rarity == "Common" then cost = 50
		elseif rarity == "Rare" then cost = 200
		elseif rarity == "Epic" then cost = 500
		elseif rarity == "Legendary" then cost = 1500 end

		createTextLabel(entry, "💎 " .. tostring(cost),
			UDim2.new(0.15, 0, 1, 0), UDim2.new(0.5, 0, 0, 0), 14,
			Color3.fromRGB(255, 222, 50), Enum.Font.GothamBold)

		-- Equip button
		local equipText = skinId == "default" and "EQUIPPED" or
			(progression and table.find(progression.OwnedSkins or {}, heroId .. "_" .. skinId) and "OWNED" or "EQUIP")
		local equipColor = skinId == "default" and Color3.fromRGB(80, 80, 100) or
			Color3.fromRGB(60, 180, 100)
		if equipText == "EQUIP" then
			equipColor = Color3.fromRGB(255, 160, 40)
		end

		local equipBtn = createTextButton(entry, equipText,
			UDim2.new(0, 100, 0, 36), UDim2.new(1, -116, 0.5, -18),
			equipColor)
		equipBtn.TextSize = 13
		equipBtn.Font = Enum.Font.GothamBold
		equipBtn.MouseButton1Click:Connect(function()
			if skinId == "default" then return end
			if equipText == "EQUIP" then
				if progression and progression.Coins and progression.Coins >= cost then
					ProgressionSystem.EquipSkin(nil, heroId, skinId)
				elseif progression and table.find(progression.OwnedSkins or {}, heroId .. "_" .. skinId) then
					ProgressionSystem.EquipSkin(nil, heroId, skinId)
				end
				bg:Destroy()
				UIClient.SkinPanel = nil
			end
		end)
	end
end

-----------------------------------------------------
-- HUD
-----------------------------------------------------

function UIClient.BuildHUD()
	local screen = UIClient.HUD
	screen.BackgroundTransparency = 1

	-- Top bar
	local topBar = createRoundedFrame(screen, "TopBar",
		UDim2.new(0, 420, 0, 50), UDim2.new(0.5, -210, 0, 0),
		Color3.fromRGB(10, 12, 20, 200), 0.4, 10)
	topBar.ZIndex = 10

	createTextLabel(topBar, "MODE",
		UDim2.new(0, 80, 0, 20), UDim2.new(0, 8, 0, 4), 12,
		Color3.fromRGB(150, 150, 170), Enum.Font.GothamSemibold)
	UIClient.ModeLabel = createTextLabel(topBar, "Standard",
		UDim2.new(0, 120, 0, 22), UDim2.new(0, 8, 0, 24), 16,
		Color3.fromRGB(255, 220, 80), Enum.Font.GothamBold)

	UIClient.ScoreLabel = createTextLabel(topBar, "RED 0 : 0 BLUE",
		UDim2.new(0, 280, 0, 28), UDim2.new(0.5, -140, 0, 24), 20,
		Color3.fromRGB(255, 245, 230), Enum.Font.GothamBlack)

	UIClient.TimerLabel = createTextLabel(topBar, "5:00",
		UDim2.new(0, 80, 0, 28), UDim2.new(1, -90, 0, 2), 22,
		Color3.fromRGB(255, 240, 220), Enum.Font.GothamBlack)

	-- Health & Shield bars
	local bottomBar = createRoundedFrame(screen, "BottomBar",
		UDim2.new(0, 500, 0, 130), UDim2.new(0.5, -250, 1, -140),
		Color3.fromRGB(10, 12, 20, 200), 0.4, 10)
	bottomBar.ZIndex = 10

	createTextLabel(bottomBar, "HEALTH", UDim2.new(0, 80, 0, 18), UDim2.new(0, 12, 0, 8), 11,
		Color3.fromRGB(180, 60, 60), Enum.Font.GothamBold)

	UIClient.HealthBarBG, UIClient.HealthBarFill = createProgressBar(bottomBar,
		UDim2.new(0, 280, 0, 20), UDim2.new(0, 12, 0, 28),
		Color3.fromRGB(200, 50, 50), Color3.fromRGB(30, 15, 15))

	createTextLabel(bottomBar, "SHIELD", UDim2.new(0, 80, 0, 18), UDim2.new(0, 12, 0, 52), 11,
		Color3.fromRGB(80, 120, 200), Enum.Font.GothamBold)

	UIClient.ShieldBarBG, UIClient.ShieldBarFill = createProgressBar(bottomBar,
		UDim2.new(0, 280, 0, 20), UDim2.new(0, 12, 0, 62),
		Color3.fromRGB(80, 140, 255), Color3.fromRGB(15, 25, 45))

	createTextLabel(bottomBar, "ABILITY [Q]", UDim2.new(0, 80, 0, 18), UDim2.new(0, 12, 0, 86), 11,
		Color3.fromRGB(200, 150, 50), Enum.Font.GothamBold)

	UIClient.AbilityBarBG, UIClient.AbilityBarFill = createProgressBar(bottomBar,
		UDim2.new(0, 280, 0, 18), UDim2.new(0, 12, 0, 104),
		Color3.fromRGB(200, 160, 40), Color3.fromRGB(30, 25, 10))

	createTextLabel(bottomBar, "ULTIMATE [E]", UDim2.new(0, 80, 0, 16), UDim2.new(0, 12, 0, 126), 11,
		Color3.fromRGB(180, 60, 200), Enum.Font.GothamBold)

	UIClient.UltimateBarBG, UIClient.UltimateBarFill = createProgressBar(bottomBar,
		UDim2.new(0, 280, 0, 16), UDim2.new(0, 12, 0, 142),
		Color3.fromRGB(160, 40, 200), Color3.fromRGB(30, 10, 45))

	-- Ammo display
	local ammoFrame = createRoundedFrame(screen, "AmmoFrame",
		UDim2.new(0, 200, 0, 60), UDim2.new(1, -220, 0.5, -30),
		Color3.fromRGB(10, 12, 20, 200), 0.4, 8)
	ammoFrame.ZIndex = 10

	UIClient.AmmoLabel = createTextLabel(ammoFrame, "42 / 126",
		UDim2.fromScale(1, 0.55), UDim2.new(0, 0, 0.1, 0), 24,
		Color3.fromRGB(240, 240, 255), Enum.Font.GothamBlack)

	UIClient.WeaponNameLabel = createTextLabel(ammoFrame, "PULSE RIFLE",
		UDim2.fromScale(1, 0.4), UDim2.new(0, 0, 0.55, 0), 14,
		Color3.fromRGB(150, 160, 170), Enum.Font.GothamSemibold)

	-- Hero switcher buttons
	local heroBar = createRoundedFrame(screen, "HeroBar",
		UDim2.new(0, 500, 0, 52), UDim2.new(0.5, -250, 1, -62),
		Color3.fromRGB(10, 12, 20, 180), 0.3, 10)

	for i = 1, 5 do
		local btn = createTextButton(heroBar, tostring(i),
			UDim2.new(0, 92, 0, 44), UDim2.new(0, (i - 1) * 100, 0, 0),
			Color3.fromRGB(40, 44, 60), Color3.fromRGB(60, 64, 80))
		btn.TextSize = 16
		btn.Font = Enum.Font.GothamSemibold
		btn.MouseButton1Click:Connect(function()
			ClientCore.Fire("RequestSwitchHero", { slot = i })
		end)
		UIClient.HeroButtons[i] = btn
	end

	-- Ability button (overlay)
	UIClient.AbilityButton = createTextButton(screen, "Q",
		UDim2.new(0, 56, 0, 56), UDim2.new(0, 20, 1, -76),
		Color3.fromRGB(30, 30, 45), Color3.fromRGB(70, 200, 150))
	UIClient.AbilityButton.TextSize = 20
	UIClient.AbilityButton.Font = Enum.Font.GothamBold
	UIClient.AbilityButton.ZIndex = 20
	UIClient.AbilityButton.TextColor3 = Color3.fromRGB(255, 240, 200)

	-- Ultimate button
	UIClient.UltimateButton = createTextButton(screen, "E",
		UDim2.new(0, 64, 0, 64), UDim2.new(1, -84, 1, -84),
		Color3.fromRGB(120, 40, 180), Color3.fromRGB(160, 60, 220))
	UIClient.UltimateButton.TextSize = 22
	UIClient.UltimateButton.Font = Enum.Font.GothamBlack
	UIClient.UltimateButton.ZIndex = 20
	UIClient.UltimateButton.TextColor3 = Color3.fromRGB(255, 240, 255)

	-- Killfeed
	UIClient.KillfeedContainer = createRoundedFrame(screen, "Killfeed",
		UDim2.new(0, 300, 0, 210), UDim2.new(1, -320, 0, 100),
		Color3.fromRGB(5, 5, 12, 180), 0.2, 6)
	UIClient.KillfeedContainer.ZIndex = 20

	createTextLabel(UIClient.KillfeedContainer, "KILLFEED",
		UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 2), 13,
		Color3.fromRGB(180, 180, 200), Enum.Font.GothamSemibold)

	-- Bomb mode HUD elements
	UIClient.BombTimerLabel = createTextLabel(screen, "",
		UDim2.new(0, 200, 0, 40), UDim2.new(0.5, -100, 0, 60), 28,
		Color3.fromRGB(255, 220, 80), Enum.Font.GothamBlack)
	UIClient.BombTimerLabel.Visible = false
	UIClient.BombTimerLabel.ZIndex = 20

	UIClient.RoundInfoLabel = createTextLabel(screen, "",
		UDim2.new(0, 200, 0, 24), UDim2.new(0.5, -100, 0, 95), 16,
		Color3.fromRGB(180, 190, 200), Enum.Font.GothamSemibold)
	UIClient.RoundInfoLabel.Visible = false
	UIClient.RoundInfoLabel.ZIndex = 20

	UIClient.DefuseBar = createProgressBar(screen,
		UDim2.new(0, 200, 0, 16), UDim2.new(0.5, -100, 0, 5),
		Color3.fromRGB(50, 150, 255), Color3.fromRGB(15, 25, 45))
	UIClient.DefuseBar.Visible = false
	UIClient.DefuseBar.ZIndex = 20

	UIClient.BombCarriedLabel = createTextLabel(screen, "BOMB CARRIER",
		UDim2.new(0, 180, 0, 28), UDim2.new(0.5, -90, 0, 105), 14,
		Color3.fromRGB(255, 200, 50), Enum.Font.GothamBold)
	UIClient.BombCarriedLabel.Visible = false
	UIClient.BombCarriedLabel.ZIndex = 20

	-- Notification area
	UIClient.NotificationArea = createRoundedFrame(screen, "Notifications",
		UDim2.new(0, 350, 0, 100), UDim2.new(0, 10, 1, -110),
		Color3.fromRGB(5, 5, 12, 180), 0.3, 8)
	UIClient.NotificationArea.ZIndex = 15
end

-----------------------------------------------------
-- BUY MENU (Bomb Mode)
-----------------------------------------------------

function UIClient.BuildBuyMenu()
	local screen = UIClient.HUD

	UIClient.BuyMenuFrame = createRoundedFrame(screen, "BuyMenu",
		UDim2.new(0, 400, 0, 500), UDim2.new(0.5, -200, 0.5, -250),
		Color3.fromRGB(10, 12, 20, 240), 0.3, 12)
	UIClient.BuyMenuFrame.Visible = false
	UIClient.BuyMenuFrame.ZIndex = 30

	createTextLabel(UIClient.BuyMenuFrame, "BUY MENU",
		UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 5), 22,
		Color3.fromRGB(255, 222, 35), Enum.Font.GothamBlack)

	UIClient.BuyMoneyLabel = createTextLabel(UIClient.BuyMenuFrame, "$800",
		UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 40), 18,
		Color3.fromRGB(100, 255, 150), Enum.Font.GothamBold)

	local categories = {
		{Pistols = {"twin_pistols", "shadow_pistols"}},
		{SMGs = {"nano_smg", "phase_smg", "vortex_smg", "shadow_smg"}},
		{Rifles = {"pulse_rifle", "storm_rifle", "plasma_rifle", "titan_rifle"}},
		{Snipers = {"hunter_rifle", "rail_lance", "longbow"}},
		{Shotguns = {"shotgun", "scatter_cannon", "pump_action"}},
		{Special = {"arc_launcher", "flamethrower", "ion_beam"}},
	}

	local y = 75
	local function getPrice(weaponId)
		local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("PulseDeckArena"):WaitForChild("Shared"):WaitForChild("Config"))
		return Config.WEAPON_PRICES[weaponId] or 0
	end

	for _, catTable in ipairs(categories) do
		for catName, weaponIds in pairs(catTable) do
			local catLabel = createTextLabel(UIClient.BuyMenuFrame, catName,
				UDim2.new(0.9, 0, 0, 20), UDim2.new(0.05, 0, 0, y), 13,
				Color3.fromRGB(150, 160, 180), Enum.Font.GothamBold)
			y += 22
			for _, wid in ipairs(weaponIds) do
				local price = getPrice(wid)
				local btn = createTextButton(UIClient.BuyMenuFrame, wid .. " ($" .. tostring(price) .. ")",
					UDim2.new(0.85, 0, 0, 28), UDim2.new(0.1, 0, 0, y),
					Color3.fromRGB(35, 45, 65), Color3.fromRGB(55, 65, 85))
				btn.TextSize = 12
				btn.Font = Enum.Font.GothamSemibold
				btn.ZIndex = 31
				btn.MouseButton1Click:Connect(function()
					ClientCore.Fire("RequestBuy", { weaponId = wid })
				end)
				y += 30
			end
		end
	end

	-- Close button
	local closeBtn = createTextButton(UIClient.BuyMenuFrame, "CLOSE (B)",
		UDim2.new(0.4, 0, 0, 34), UDim2.new(0.3, 0, 0.9, 0),
		Color3.fromRGB(180, 50, 50), Color3.fromRGB(220, 70, 70))
	closeBtn.TextSize = 14
	closeBtn.ZIndex = 31
	closeBtn.MouseButton1Click:Connect(function()
		UIClient.BuyMenuFrame.Visible = false
	end)
end

function UIClient.BuildShopUI()
	local screen = UIClient.HUD
	UIClient.ShopFrame = createRoundedFrame(screen, "ShopFrame",
		UDim2.new(0, 500, 0, 500), UDim2.new(0.5, -250, 0.5, -250),
		Color3.fromRGB(10, 12, 20, 240), 0.3, 12)
	UIClient.ShopFrame.Visible = false
	UIClient.ShopFrame.ZIndex = 40

	createTextLabel(UIClient.ShopFrame, "SHOP",
		UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 5), 24,
		Color3.fromRGB(255, 222, 35), Enum.Font.GothamBlack)

	local coins = ProgressionUtils and 0 or 0
	if ClientCore.State and ClientCore.State.progression then
		coins = ClientCore.State.progression.Coins or 0
	end
	createTextLabel(UIClient.ShopFrame, "💎 " .. tostring(coins) .. " coins",
		UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 42), 16,
		Color3.fromRGB(255, 222, 50), Enum.Font.GothamBold)

	local shopItems = {
		{name = "Assault Skin Bundle", price = 500, id = "skin_bundle_assault", cat = "Skins"},
		{name = "Tank Skin Bundle", price = 500, id = "skin_bundle_tank", cat = "Skins"},
		{name = "Mage Skin Bundle", price = 500, id = "skin_bundle_mage", cat = "Skins"},
		{name = "500 Coins", price = 99, id = "coins_500", cat = "Currency"},
		{name = "1500 Coins", price = 249, id = "coins_1500", cat = "Currency"},
		{name = "4000 Coins", price = 599, id = "coins_4000", cat = "Currency"},
	}

	local y = 75
	for _, item in ipairs(shopItems) do
		local frame = createRoundedFrame(UIClient.ShopFrame, "ShopItem_" .. item.id,
			UDim2.new(0.9, 0, 0, 36), UDim2.new(0.05, 0, 0, y),
			Color3.fromRGB(20, 22, 35), 0.5, 6)
		createTextLabel(frame, item.name .. " [" .. item.cat .. "]",
			UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 8, 0, 0), 14,
			Color3.fromRGB(220, 220, 240))
		createTextLabel(frame, "$" .. tostring(item.price),
			UDim2.new(0.15, 0, 1, 0), UDim2.new(0.6, 0, 0, 0), 14,
			Color3.fromRGB(255, 222, 50), Enum.Font.GothamBold)
		local buyBtn = createTextButton(frame, "BUY",
			UDim2.new(0.15, 0, 0, 28), UDim2.new(0.8, 0, 0.5, -14),
			Color3.fromRGB(60, 180, 100))
		buyBtn.TextSize = 12
		buyBtn.MouseButton1Click:Connect(function()
			ClientCore.Fire("RequestPurchase", { itemId = item.id })
		end)
		y += 40
	end

	local closeBtn = createTextButton(UIClient.ShopFrame, "CLOSE",
		UDim2.new(0.3, 0, 0, 34), UDim2.new(0.35, 0, 0.9, 0),
		Color3.fromRGB(180, 50, 50))
	closeBtn.MouseButton1Click:Connect(function()
		UIClient.ShopFrame.Visible = false
	end)
end

function UIClient.BuildEmoteUI()
	local screen = UIClient.HUD
	UIClient.EmoteFrame = createRoundedFrame(screen, "EmoteFrame",
		UDim2.new(0, 300, 0, 200), UDim2.new(0.5, -150, 0.5, -100),
		Color3.fromRGB(10, 12, 20, 230), 0.3, 12)
	UIClient.EmoteFrame.Visible = false
	UIClient.EmoteFrame.ZIndex = 50

	createTextLabel(UIClient.EmoteFrame, "EMOTES",
		UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 5), 18,
		Color3.fromRGB(255, 222, 35), Enum.Font.GothamBlack)

	local emotes = {"👍", "👋", "💪", "🔥", "😱", "🎉", "😎", "🧊"}
	for i, emoji in ipairs(emotes) do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local btn = createTextButton(UIClient.EmoteFrame, emoji,
			UDim2.new(0, 60, 0, 60), UDim2.new(0, 10 + col * 70, 0, 40 + row * 70),
			Color3.fromRGB(40, 44, 60))
		btn.TextSize = 24
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	local closeBtn = createTextButton(UIClient.EmoteFrame, "X",
		UDim2.new(0, 30, 0, 30), UDim2.new(1, -40, 0, 5),
		Color3.fromRGB(180, 50, 50))
	closeBtn.MouseButton1Click:Connect(function()
		UIClient.EmoteFrame.Visible = false
	end)
end

function UIClient.BuildPracticeRangeUI()
	local screen = UIClient.HUD
	UIClient.PracticeFrame = createRoundedFrame(screen, "PracticeFrame",
		UDim2.new(0, 200, 0, 100), UDim2.new(0.5, -100, 0.2, 0),
		Color3.fromRGB(10, 12, 20, 200), 0.4, 10)
	UIClient.PracticeFrame.Visible = false
	UIClient.PracticeFrame.ZIndex = 30

	createTextLabel(UIClient.PracticeFrame, "PRACTICE RANGE",
		UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 4), 16,
		Color3.fromRGB(255, 200, 50), Enum.Font.GothamBlack)
	createTextLabel(UIClient.PracticeFrame, "Dummy targets — test weapons",
		UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 28), 12,
		Color3.fromRGB(150, 160, 180))

	local spawnBtn = createTextButton(UIClient.PracticeFrame, "Spawn Dummy",
		UDim2.new(0.8, 0, 0, 28), UDim2.new(0.1, 0, 0.6, 0),
		Color3.fromRGB(60, 140, 100))
	spawnBtn.TextSize = 12
	spawnBtn.MouseButton1Click:Connect(function()
		ClientCore.Fire("RequestPracticeDummy", {})
	end)
end

-----------------------------------------------------
-- SCOREBOARD
-----------------------------------------------------

function UIClient.BuildScoreboard()
	local screen = UIClient.Scoreboard

	local bg = createRoundedFrame(screen, "BG",
		UDim2.new(0.5, 0, 0.7, 0), UDim2.new(0.25, 0, 0.15, 0),
		Color3.fromRGB(10, 12, 20, 240), 0.2, 12)

	createTextLabel(bg, "SCOREBOARD", UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 5),
		28, Color3.fromRGB(255, 222, 35), Enum.Font.GothamBlack)

	createTextLabel(bg, "PLAYER", UDim2.new(0.3, 0, 0, 30), UDim2.new(0.05, 0, 0, 55),
		13, Color3.fromRGB(150, 160, 180), Enum.Font.GothamBold)
	createTextLabel(bg, "TEAM", UDim2.new(0.1, 0, 0, 30), UDim2.new(0.35, 0, 0, 55),
		13, Color3.fromRGB(150, 160, 180), Enum.Font.GothamBold)
	createTextLabel(bg, "KILLS", UDim2.new(0.1, 0, 0, 30), UDim2.new(0.48, 0, 0, 55),
		13, Color3.fromRGB(150, 160, 180), Enum.Font.GothamBold)
	createTextLabel(bg, "DEATHS", UDim2.new(0.1, 0, 0, 30), UDim2.new(0.58, 0, 0, 55),
		13, Color3.fromRGB(150, 160, 180), Enum.Font.GothamBold)
	createTextLabel(bg, "K/D", UDim2.new(0.1, 0, 0, 30), UDim2.new(0.68, 0, 0, 55),
		13, Color3.fromRGB(150, 160, 180), Enum.Font.GothamBold)
	createTextLabel(bg, "SCORE", UDim2.new(0.1, 0, 0, 30), UDim2.new(0.78, 0, 0, 55),
		13, Color3.fromRGB(150, 160, 180), Enum.Font.GothamBold)

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0.95, 0, 0, 1)
	divider.Position = UDim2.new(0.025, 0, 0, 80)
	divider.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
	divider.BorderSizePixel = 0
	divider.Parent = bg
end

function UIClient.UpdateScoreboard(players)
	if not UIClient.Scoreboard then return end
	local bg = UIClient.Scoreboard:FindFirstChild("BG")
	if not bg then return end

	for _, child in ipairs(bg:GetChildren()) do
		if child:GetAttribute("ScoreEntry") then
			child:Destroy()
		end
	end

	local y = 90
	table.sort(players, function(a, b) return (a.score or 0) > (b.score or 0) end)

	for _, row in ipairs(players) do
		local entry = Instance.new("Frame")
		entry.Name = "Entry_" .. row.name
		entry.Size = UDim2.new(0.95, 0, 0, 28)
		entry.Position = UDim2.new(0.025, 0, 0, y)
		entry.BackgroundColor3 = Color3.fromRGB(20, 22, 32, 200)
		entry.BorderSizePixel = 0
		entry:SetAttribute("ScoreEntry", true)
		entry.Parent = bg
		Instance.new("UICorner", entry)

		local teamColor = row.teamId == "Red" and Config.RED_COLOR or (row.teamId == "Blue" and Config.BLUE_COLOR or Color3.fromRGB(150, 150, 150))

		local indicator = Instance.new("Frame")
		indicator.Size = UDim2.new(0, 4, 1, 0)
		indicator.BackgroundColor3 = teamColor
		indicator.BorderSizePixel = 0
		indicator.Parent = entry

		createTextLabel(entry, row.name,
			UDim2.new(0.3, -8, 1, 0), UDim2.new(0, 12, 0, 0), 13,
			Color3.fromRGB(240, 240, 255), Enum.Font.GothamSemibold)
		createTextLabel(entry, row.teamId,
			UDim2.new(0.1, 0, 1, 0), UDim2.new(0.36, 0, 0, 0), 13, teamColor, Enum.Font.GothamSemibold)
		createTextLabel(entry, tostring(row.kills or 0),
			UDim2.new(0.1, 0, 1, 0), UDim2.new(0.48, 0, 0, 0), 13,
			Color3.fromRGB(200, 200, 200), Enum.Font.GothamSemibold)
		createTextLabel(entry, tostring(row.deaths or 0),
			UDim2.new(0.1, 0, 1, 0), UDim2.new(0.58, 0, 0, 0), 13,
			Color3.fromRGB(200, 200, 200), Enum.Font.GothamSemibold)
		createTextLabel(entry, string.format("%.2f", row.kd or 0),
			UDim2.new(0.1, 0, 1, 0), UDim2.new(0.68, 0, 0, 0), 13,
			Color3.fromRGB(200, 200, 200), Enum.Font.GothamSemibold)
		createTextLabel(entry, tostring(math.floor(row.score or 0)),
			UDim2.new(0.1, 0, 1, 0), UDim2.new(0.78, 0, 0, 0), 13,
			Color3.fromRGB(255, 220, 80), Enum.Font.GothamBold)

		y += 30
	end

	bg.CanvasSize = UDim2.new(0, 0, 0, y + 20)
end

-----------------------------------------------------
-- POST-MATCH
-----------------------------------------------------

function UIClient.BuildPostMatch()
	local screen = UIClient.PostMatch
	createRoundedFrame(screen, "BG", UDim2.fromScale(1, 1), UDim2.new(0, 0, 0, 0),
		Color3.fromRGB(5, 5, 15, 180), 0.3, 0)
end

function UIClient.ShowMatchResult(winnerText, duration)
	local screen = UIClient.PostMatch
	screen:ClearAllChildren()
	screen.Visible = true

	local bg = createRoundedFrame(screen, "ResultBG",
		UDim2.new(0.6, 0, 0.7, 0), UDim2.new(0.2, 0, 0.15, 0),
		Color3.fromRGB(10, 12, 20, 220), 0.2, 14)

	createTextLabel(bg, "MATCH OVER",
		UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 10), 22,
		Color3.fromRGB(150, 160, 180), Enum.Font.GothamSemibold)

	createTextLabel(bg, winnerText,
		UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 45), 42,
		Color3.fromRGB(255, 222, 35), Enum.Font.GothamBlack)

	local localUserId = Players.LocalPlayer.UserId
	local stats = {kills = 0, deaths = 0, damage = 0, score = 0, hero = "Unknown"}
	for _, hero in pairs(ClientCore.State.heroes or {}) do
		if hero.ownerUserId == localUserId then
			stats.kills = hero.killCount or 0
			stats.deaths = hero.deathCount or 0
			stats.damage = hero.damageDealt or 0
			stats.hero = (hero.heroId or ""):gsub("_", " "):gsub("(%l)(%w+)", function(a,b) return a:upper()..b end)
			break
		end
	end

	local scoreText = string.format("Kills: %d  |  Deaths: %d  |  Damage: %d  |  K/D: %.2f",
		stats.kills, stats.deaths, stats.damage, stats.kills / math.max(1, stats.deaths))
	createTextLabel(bg, scoreText,
		UDim2.new(0.9, 0, 0, 28), UDim2.new(0.05, 0, 0.45, 0), 18,
		Color3.fromRGB(200, 210, 230), Enum.Font.GothamSemibold)

	createTextLabel(bg, "Hero: " .. stats.hero,
		UDim2.new(0.9, 0, 0, 24), UDim2.new(0.05, 0, 0.52, 0), 16,
		Color3.fromRGB(180, 190, 210), Enum.Font.Gotham)

	createTextLabel(bg, "Returning to menu in " .. tostring(math.floor(duration)) .. "s...",
		UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.75, 0), 16,
		Color3.fromRGB(120, 130, 150), Enum.Font.Gotham)

	task.spawn(animateScreenIn, screen, 0.3)
end

-----------------------------------------------------
-- SETTINGS
-----------------------------------------------------

function UIClient.ShowSettings()
	if UIClient.SettingsFrame then
		UIClient.SettingsFrame.Visible = not UIClient.SettingsFrame.Visible
		return
	end

	local screen = UIClient.Gui
	local bg = createRoundedFrame(screen, "SettingsFrame",
		UDim2.new(0, 500, 0, 550), UDim2.new(0.5, -250, 0.5, -275),
		Color3.fromRGB(10, 12, 20, 240), 0.3, 12)
	bg.ZIndex = 60

	createTextLabel(bg, "SETTINGS",
		UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 5), 24,
		Color3.fromRGB(255, 222, 35), Enum.Font.GothamBlack)

	-- Tabs
	local activeTab = "Graphics"
	local tabY = 50
	local tabsFrame = createRoundedFrame(bg, "Tabs",
		UDim2.new(0.9, 0, 0, 36), UDim2.new(0.05, 0, 0, 50),
		Color3.fromRGB(20, 22, 35), 0.5, 8)

	local tabs = {"Graphics", "Controls", "Audio"}
	local tabButtons = {}
	for i, tabName in ipairs(tabs) do
		local btn = createTextButton(tabsFrame, tabName,
			UDim2.new(0.3, -4, 0, 28), UDim2.new((i-1)/3 + 0.02, 0, 0.5, -14),
			Color3.fromRGB(40, 44, 60))
		btn.TextSize = 13
		btn.ZIndex = 61
		btn.MouseButton1Click:Connect(function()
			activeTab = tabName
			for _, b in ipairs(tabButtons) do
				b.BackgroundColor3 = Color3.fromRGB(40, 44, 60)
			end
			btn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
			UIClient.UpdateSettingsTab(bg, tabName)
		end)
		table.insert(tabButtons, btn)
	end
	tabButtons[1].BackgroundColor3 = Color3.fromRGB(60, 120, 200)

	-- Content area
	local contentFrame = createRoundedFrame(bg, "Content",
		UDim2.new(0.9, 0, 0.65, 0), UDim2.new(0.05, 0, 0.22, 0),
		Color3.fromRGB(15, 17, 28), 0.5, 8)
	contentFrame.ZIndex = 60

	bg:SetAttribute("ContentFrame", contentFrame)

	-- Close button
	local closeBtn = createTextButton(bg, "✕",
		UDim2.new(0, 36, 0, 36), UDim2.new(1, -46, 0, 5),
		Color3.fromRGB(180, 50, 50))
	closeBtn.TextSize = 18
	closeBtn.ZIndex = 61
	closeBtn.MouseButton1Click:Connect(function()
		bg.Visible = false
	end)

	UIClient.SettingsFrame = bg
	UIClient.UpdateSettingsTab(bg, "Graphics")
end

function UIClient.UpdateSettingsTab(bg, tab)
	local content = bg and bg:FindFirstChild("Content")
	if not content then return end
	content:ClearAllChildren()

	local SettingsClient = require(script.Parent:WaitForChild("SettingsClient"))
	local y = 8

	if tab == "Graphics" then
		createTextLabel(content, "Graphics Quality",
			UDim2.new(0.9, 0, 0, 22), UDim2.new(0.05, 0, 0, y), 14,
			Color3.fromRGB(180, 190, 210))
		y += 26

		local presets = {"Low", "Medium", "High", "Ultra"}
		for i, preset in ipairs(presets) do
			local isActive = SettingsClient.GetCurrentPreset() == preset
			local btn = createTextButton(content, preset,
				UDim2.new(0.2, -4, 0, 28), UDim2.new(0.05 + (i-1) * 0.22, 0, 0, y),
				isActive and Color3.fromRGB(60, 120, 200) or Color3.fromRGB(40, 44, 60))
			btn.TextSize = 12
			btn.ZIndex = 61
			btn.MouseButton1Click:Connect(function()
				SettingsClient.ApplyGraphicsPreset(preset)
				UIClient.UpdateSettingsTab(bg, "Graphics")
			end)
		end
		y += 36

		createTextLabel(content, "FPS Cap: " .. tostring(SettingsClient.GetFPSCap()),
			UDim2.new(0.9, 0, 0, 22), UDim2.new(0.05, 0, 0, y), 14,
			Color3.fromRGB(180, 190, 210))
		y += 22

		local fpsOptions = {30, 60, 120, 144, 240}
		for i, fps in ipairs(fpsOptions) do
			local isActive = SettingsClient.GetFPSCap() == fps
			local btn = createTextButton(content, tostring(fps),
				UDim2.new(0.15, -4, 0, 28), UDim2.new(0.05 + (i-1) * 0.17, 0, 0, y),
				isActive and Color3.fromRGB(60, 120, 200) or Color3.fromRGB(40, 44, 60))
			btn.TextSize = 12
			btn.ZIndex = 61
			btn.MouseButton1Click:Connect(function()
				SettingsClient.SetFPSCap(fps)
				UIClient.UpdateSettingsTab(bg, "Graphics")
			end)
		end
		y += 36

		-- Camera shake toggle
		local shakeBtn = createTextButton(content, "Camera Shake: " .. (SettingsClient.CameraShake and "ON" or "OFF"),
			UDim2.new(0.4, 0, 0, 28), UDim2.new(0.05, 0, 0, y),
			SettingsClient.CameraShake and Color3.fromRGB(60, 160, 80) or Color3.fromRGB(120, 60, 60))
		shakeBtn.TextSize = 12
		shakeBtn.ZIndex = 61
		shakeBtn.MouseButton1Click:Connect(function()
			SettingsClient.CameraShake = not SettingsClient.CameraShake
			UIClient.UpdateSettingsTab(bg, "Graphics")
		end)
		y += 36

		-- Show damage numbers toggle
		local dmgBtn = createTextButton(content, "Damage Numbers: " .. (SettingsClient.ShowDamageNumbers and "ON" or "OFF"),
			UDim2.new(0.4, 0, 0, 28), UDim2.new(0.05, 0, 0, y),
			SettingsClient.ShowDamageNumbers and Color3.fromRGB(60, 160, 80) or Color3.fromRGB(120, 60, 60))
		dmgBtn.TextSize = 12
		dmgBtn.ZIndex = 61
		dmgBtn.MouseButton1Click:Connect(function()
			SettingsClient.ShowDamageNumbers = not SettingsClient.ShowDamageNumbers
			SettingsClient.Save()
			UIClient.UpdateSettingsTab(bg, "Graphics")
		end)
		y += 36

		-- Show killfeed toggle
		local kfBtn = createTextButton(content, "Killfeed: " .. (SettingsClient.ShowKillfeed and "ON" or "OFF"),
			UDim2.new(0.4, 0, 0, 28), UDim2.new(0.05, 0, 0, y),
			SettingsClient.ShowKillfeed and Color3.fromRGB(60, 160, 80) or Color3.fromRGB(120, 60, 60))
		kfBtn.TextSize = 12
		kfBtn.ZIndex = 61
		kfBtn.MouseButton1Click:Connect(function()
			SettingsClient.ShowKillfeed = not SettingsClient.ShowKillfeed
			SettingsClient.Save()
			UIClient.UpdateSettingsTab(bg, "Graphics")
		end)

	elseif tab == "Controls" then
		createTextLabel(content, "Click a binding to change it",
			UDim2.new(0.9, 0, 0, 20), UDim2.new(0.05, 0, 0, y), 12,
			Color3.fromRGB(150, 160, 180))
		y += 22

		local actionNames = SettingsClient.GetControlNames()
		local listeningFor = nil
		local listeningLabel = nil

		for action, displayName in pairs(actionNames) do
			local keyStr = SettingsClient.GetBindingDisplay(action)
			local row = createRoundedFrame(content, "BindingRow",
				UDim2.new(0.9, 0, 0, 28), UDim2.new(0.05, 0, 0, y),
				Color3.fromRGB(20, 22, 35), 0.5, 6)
			row.ZIndex = 61
			createTextLabel(row, displayName,
				UDim2.new(0.5, 0, 1, 0), UDim2.new(0, 8, 0, 0), 12,
				Color3.fromRGB(200, 210, 230))
			local keyLabel = createTextLabel(row, "[" .. keyStr .. "]",
				UDim2.new(0.3, 0, 1, 0), UDim2.new(0.6, 0, 0, 0), 12,
				Color3.fromRGB(255, 200, 50), Enum.Font.GothamBold)
			keyLabel.ZIndex = 62

			local btn = Instance.new("TextButton")
			btn.Size = UDim2.fromScale(1, 1)
			btn.BackgroundTransparency = 1
			btn.Text = ""
			btn.ZIndex = 62
			btn.Parent = row
			btn.MouseButton1Click:Connect(function()
				listeningFor = action
				keyLabel.Text = "[...]"
				local conn
				conn = game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
					if gpe then return end
					if input.KeyCode == Enum.KeyCode.Escape then
						keyLabel.Text = "[" .. SettingsClient.GetBindingDisplay(action) .. "]"
						listeningFor = nil
						conn:Disconnect()
						return
					end
					SettingsClient.SetBinding(action, input)
					keyLabel.Text = "[" .. SettingsClient.GetBindingDisplay(action) .. "]"
					listeningFor = nil
					conn:Disconnect()
				end)
			end)
			y += 32
		end

		-- Reset bindings button
		local resetBtn = createTextButton(content, "Reset to Defaults",
			UDim2.new(0.4, 0, 0, 32), UDim2.new(0.3, 0, 0, y + 4),
			Color3.fromRGB(180, 80, 60))
		resetBtn.TextSize = 13
		resetBtn.ZIndex = 61
		resetBtn.MouseButton1Click:Connect(function()
			SettingsClient.ResetBindings()
			UIClient.UpdateSettingsTab(bg, "Controls")
		end)

	elseif tab == "Audio" then
		createTextLabel(content, "Master Volume",
			UDim2.new(0.9, 0, 0, 20), UDim2.new(0.05, 0, 0, y), 14,
			Color3.fromRGB(180, 190, 210))
		y += 22
		local mvLabel = createTextLabel(content, math.floor(SettingsClient.MasterVolume * 100) .. "%",
			UDim2.new(0.9, 0, 0, 20), UDim2.new(0.05, 0, 0, y), 14,
			Color3.fromRGB(255, 200, 50))
		y += 22
		local mvSlider = Instance.new("Frame")
		mvSlider.Size = UDim2.new(0.8, 0, 0, 6)
		mvSlider.Position = UDim2.new(0.1, 0, 0, y)
		mvSlider.BackgroundColor3 = Color3.fromRGB(40, 44, 60)
		mvSlider.BorderSizePixel = 0
		mvSlider.Parent = content
		local mvFill = Instance.new("Frame")
		mvFill.Size = UDim2.new(SettingsClient.MasterVolume, 0, 1, 0)
		mvFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
		mvFill.BorderSizePixel = 0
		mvFill.Parent = mvSlider
		y += 20

		createTextLabel(content, "SFX Volume",
			UDim2.new(0.9, 0, 0, 20), UDim2.new(0.05, 0, 0, y), 14,
			Color3.fromRGB(180, 190, 210))
		y += 22
		createTextLabel(content, math.floor(SettingsClient.SFXVolume * 100) .. "%",
			UDim2.new(0.9, 0, 0, 20), UDim2.new(0.05, 0, 0, y), 14,
			Color3.fromRGB(255, 200, 50))
		y += 22

		createTextLabel(content, "Music Volume",
			UDim2.new(0.9, 0, 0, 20), UDim2.new(0.05, 0, 0, y), 14,
			Color3.fromRGB(180, 190, 210))
		y += 22
		createTextLabel(content, math.floor(SettingsClient.MusicVolume * 100) .. "%",
			UDim2.new(0.9, 0, 0, 20), UDim2.new(0.05, 0, 0, y), 14,
			Color3.fromRGB(255, 200, 50))
	end
end

-----------------------------------------------------
-- PAUSE MENU
-----------------------------------------------------

function UIClient:ShowPauseMenu()
	if self.PauseMenu and self.PauseMenu.Visible then
		self.PauseMenu.Visible = false
		return
	end

	if not self.PauseMenu then
		self.PauseMenu = createRoundedFrame(nil, "PauseMenu",
			UDim2.new(0, 300, 0, 250), UDim2.new(0.5, -150, 0.5, -125),
			Color3.fromRGB(15, 17, 28, 230), 0.2, 12)

		createTextLabel(self.PauseMenu, "PAUSED",
			UDim2.fromScale(1, 0), UDim2.new(0, 0, 0, 10), 32,
			Color3.fromRGB(255, 222, 35), Enum.Font.GothamBlack)

		local resume = createTextButton(self.PauseMenu, "Resume",
			UDim2.new(0, 260, 0, 44), UDim2.new(0.5, -130, 0.35, 0),
			Color3.fromRGB(60, 180, 100))
		resume.MouseButton1Click:Connect(function()
			self.PauseMenu.Visible = false
		end)

		local quit = createTextButton(self.PauseMenu, "Leave Match",
			UDim2.new(0, 260, 0, 44), UDim2.new(0.5, -130, 0.55, 0),
			Color3.fromRGB(200, 60, 60))
		quit.MouseButton1Click:Connect(function()
			local player = Players.LocalPlayer
			player.Character = nil
			player:LoadCharacter()
		end)

		self.PauseMenu.Parent = self.Gui
	else
		self.PauseMenu.Visible = true
	end
end

-----------------------------------------------------
-- SHOW/HIDE
-----------------------------------------------------

local RunService = game:GetService("RunService")

local function animateScreenIn(screen, duration)
	local bg = screen:FindFirstChildOfClass("Frame")
	if not bg then return end
	local ogSize = bg.Size
	local ogTrans = bg.BackgroundTransparency
	bg.Size = UDim2.new(ogSize.X.Scale * 0.5, ogSize.X.Offset, ogSize.Y.Scale, ogSize.Y.Offset)
	bg.BackgroundTransparency = 1
	local t1 = TweenService:Create(bg, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = ogSize, BackgroundTransparency = ogTrans,
	})
	t1:Play()
end

local function animateScreenOut(screen, duration)
	local bg = screen:FindFirstChildOfClass("Frame")
	if not bg then return end
	local ogSize = bg.Size
	local t1 = TweenService:Create(bg, TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(ogSize.X.Scale * 0.5, ogSize.X.Offset, ogSize.Y.Scale, ogSize.Y.Offset),
		BackgroundTransparency = 1,
	})
	t1:Play()
	t1.Completed:Wait()
end

function UIClient.Show(screenName)
	for _, screen in ipairs({
		UIClient.MainMenu, UIClient.DeckSelect, UIClient.HUD,
		UIClient.Scoreboard, UIClient.PostMatch
	}) do
		if screen then
			local wasVisible = screen.Visible
			screen.Visible = screen.Name == screenName
			if screen.Visible and not wasVisible then
				task.spawn(animateScreenIn, screen, 0.25)
			end
		end
	end
end

-----------------------------------------------------
-- STATE BINDING
-----------------------------------------------------

function UIClient.BindState()
	ClientCore.Events.MatchStateChanged.Event:Connect(function(payload)
		if payload.state == "Lobby" then
			UIClient.Show("MainMenu")
		elseif payload.state == "DeckSelect" then
			UIClient.Show("DeckSelect")
		elseif payload.state == "ActiveMatch" or payload.state == "SuddenDeath" or payload.state == "MatchCountdown" then
			UIClient.Show("HUD")
		elseif payload.state == "PostMatch" then
			local winner = "DRAW"
			if payload.winner == Config.TEAM_RED then
				winner = "🔴 RED TEAM WINS!"
			elseif payload.winner == Config.TEAM_BLUE then
				winner = "🔵 BLUE TEAM WINS!"
			end
			UIClient.ShowMatchResult(winner, 12)
		end

		if UIClient.TimerLabel then
			local timer = payload.timerRemaining or 0
			local minutes = math.floor(timer / 60)
			local seconds = timer % 60
			UIClient.TimerLabel.Text = string.format("%d:%02d", minutes, seconds)
		end

		if payload.gameMode == "Bomb" then
			if UIClient.RoundInfoLabel then
				UIClient.RoundInfoLabel.Visible = true
				local ctScore = payload.roundScore and payload.roundScore.Red or 0
				local tScore = payload.roundScore and payload.roundScore.Blue or 0
				UIClient.RoundInfoLabel.Text = string.format("CT %d - %d T | Round %d/%d", ctScore, tScore, payload.roundNumber or 1, 15)
			end
			if UIClient.BombTimerLabel then
				UIClient.BombTimerLabel.Visible = payload.bombState == "Planted"
				if payload.bombState == "Planted" and payload.bombTimer then
					UIClient.BombTimerLabel.Text = string.format(" %d:%02d", math.floor(payload.bombTimer / 60), payload.bombTimer % 60)
				end
			end
			if UIClient.BombCarriedLabel then
				UIClient.BombCarriedLabel.Visible = payload.hasBomb == true
			end
		else
			if UIClient.RoundInfoLabel then UIClient.RoundInfoLabel.Visible = false end
			if UIClient.BombTimerLabel then UIClient.BombTimerLabel.Visible = false end
			if UIClient.DefuseBar then UIClient.DefuseBar.Visible = false end
			if UIClient.BombCarriedLabel then UIClient.BombCarriedLabel.Visible = false end
		end

		if UIClient.ModeLabel then
			UIClient.ModeLabel.Text = payload.gameMode or "Standard"
		end
	end)

	ClientCore.Events.ScoreChanged.Event:Connect(function(payload)
		if UIClient.ScoreLabel then
			UIClient.ScoreLabel.Text = string.format(
				"<font color='#FF4646'>RED %d</font> : <font color='#3CC0FF'>%d BLUE</font>",
				math.floor(payload.Red or 0), math.floor(payload.Blue or 0)
			)
		end
	end)

	ClientCore.Events.HeroStateChanged.Event:Connect(function(payload)
		local localUserId = Players.LocalPlayer.UserId
		for _, hero in pairs(payload.heroes or {}) do
			if hero.ownerUserId == localUserId then
				-- Update hero buttons
				local button = UIClient.HeroButtons[hero.slot]
				if button then
					local heroName = hero.heroId:gsub("_", " "):gsub("(%l)(%w)", function(a,b) return a:upper()..b end)
					button.Text = tostring(hero.slot) .. ". " .. heroName

					if hero.isControlled then
						button.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
						button.TextColor3 = Color3.fromRGB(10, 10, 12)
					elseif hero.alive then
						button.BackgroundColor3 = Color3.fromRGB(35, 180, 140)
						button.TextColor3 = Color3.fromRGB(10, 10, 12)
					else
						button.BackgroundColor3 = Color3.fromRGB(130, 35, 45)
						button.TextColor3 = Color3.fromRGB(255, 230, 230)
					end
				end

				-- Update HUD stats for controlled hero
				if hero.isControlled then
					if UIClient.HealthBarFill then
						local hp = (hero.health or 0) / math.max(1, hero.maxHealth or 1)
						UIClient.HUDTargets.health = hp
					end

					if UIClient.ShieldBarFill and (hero.shieldHealth or 0) > 0 then
						local sp = (hero.shieldHealth or 0) / math.max(1, hero.maxShield or 1)
						UIClient.HUDTargets.shield = sp
					elseif UIClient.ShieldBarFill then
						UIClient.HUDTargets.shield = 0
					end

					if UIClient.AbilityBarFill then
						local cd = hero.abilityCooldownRemaining or 0
						local fullCd = 10
						local heroAbCfg = AbilityConfig[hero.heroId]
						if heroAbCfg then fullCd = heroAbCfg.cooldown end
						local pct = 1 - (cd / math.max(1, fullCd))
						UIClient.HUDTargets.ability = math.clamp(pct, 0, 1)
					end

					if UIClient.UltimateBarFill then
						local pct = (hero.ultimateCharge or 0) / 100
						UIClient.HUDTargets.ultimate = pct
					end

					if UIClient.AmmoLabel then
						UIClient.AmmoLabel.Text = hero.ammo .. " / " .. tostring(hero.reserveAmmo or 0)
					end

					if UIClient.WeaponNameLabel then
						local wcEntry = WeaponConfig[hero.weaponId]
						if wcEntry then
							UIClient.WeaponNameLabel.Text = wcEntry.displayName
						end
					end
				end
			end
		end
	end)

	ClientCore.Events.ObjectiveStateChanged.Event:Connect(function(payload)
		if UIClient.ObjectiveLabel then
			local redCore, blueCore = "?", "?"
			for _, obj in pairs(payload.objectives or {}) do
				if obj.objectiveType == "Core" and obj.teamId == "Red" then
					redCore = tostring(math.floor(obj.health))
				elseif obj.objectiveType == "Core" and obj.teamId == "Blue" then
					blueCore = tostring(math.floor(obj.health))
				end
			end
			UIClient.ObjectiveLabel.Text = "Red Core " .. redCore .. " | Blue Core " .. blueCore
		end
	end)

	ClientCore.Events.Killfeed.Event:Connect(function(payload)
		if not UIClient.KillfeedContainer then return end

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -8, 0, 32)
		frame.Position = UDim2.new(0, 4, 0, 0)
		frame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
		frame.BorderSizePixel = 0
		frame.BackgroundTransparency = 0.1
		frame.Parent = UIClient.KillfeedContainer

		Instance.new("UICorner", frame)
		frame.CornerRadius = UDim.new(0, 4)

		local wColors = {
			pulse_rifle = Color3.fromRGB(255, 230, 45), rail_lance = Color3.fromRGB(170, 85, 255),
			scatter_cannon = Color3.fromRGB(255, 145, 40), nano_smg = Color3.fromRGB(95, 255, 180),
			arc_launcher = Color3.fromRGB(255, 90, 38), phase_smg = Color3.fromRGB(255, 50, 220),
			rivet_carbine = Color3.fromRGB(40, 210, 200), ion_beam = Color3.fromRGB(60, 235, 255),
			energy_sword = Color3.fromRGB(255, 50, 50), flamethrower = Color3.fromRGB(255, 120, 20),
			gravity_hammer = Color3.fromRGB(200, 50, 255), vortex_rifle = Color3.fromRGB(100, 200, 255),
			shotgun = Color3.fromRGB(200, 120, 60), plasma_caster = Color3.fromRGB(255, 180, 50),
			cryo_rifle = Color3.fromRGB(150, 220, 255), lightning_gun = Color3.fromRGB(255, 255, 100),
			cluster_mortar = Color3.fromRGB(200, 100, 40), thermal_grenade = Color3.fromRGB(255, 160, 40),
		}

		local wColor = wColors[payload.weaponId] or Color3.fromRGB(200, 200, 200)

		-- Kill dot
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 8, 0, 8)
		dot.Position = UDim2.new(0, 118, 0.5, -4)
		dot.BackgroundColor3 = wColor
		dot.BorderSizePixel = 0
		dot.Parent = frame

		-- Killer
		createTextLabel(frame, tostring(payload.killerName),
			UDim2.new(0, 110, 1, 0), UDim2.new(0, 4, 0, 0), 13,
			Color3.fromRGB(255, 200, 200), Enum.Font.GothamBold)

		-- Victim
		createTextLabel(frame, tostring(payload.victimName),
			UDim2.new(0.5, -140, 1, 0), UDim2.new(0, 200, 0, 0), 13,
			Color3.fromRGB(255, 235, 210), Enum.Font.GothamSemibold)

		-- Killstreak
		if payload.killCount and payload.killCount >= 5 then
			createTextLabel(frame, payload.killCount .. "x",
				UDim2.new(0, 50, 1, 0), UDim2.new(1, -120, 0, 0), 14,
				Color3.fromRGB(255, 200, 50), Enum.Font.GothamBold)
		end

		-- Headshot icon
		if payload.isHeadshot then
			createTextLabel(frame, "💀",
				UDim2.new(0, 30, 1, 0), UDim2.new(1, -160, 0, 0), 14,
				Color3.fromRGB(255, 50, 50), Enum.Font.GothamBold)
		end

		-- Animate
		frame.Size = UDim2.new(1, -8, 0, 0)
		task.spawn(function()
			local tween = TweenService:Create(frame, TweenInfo.new(0.3), {Size = UDim2.new(1, -8, 0, 32)})
			tween:Play()
		end)

		task.delay(5, function()
			if frame and frame.Parent then
				local fade = TweenService:Create(frame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
				fade:Play()
				fade.Completed:Wait()
				frame:Destroy()
			end
		end)
	end)

	ClientCore.Events.BuyMenuResponse = ClientCore.Events.BuyMenuResponse or Instance.new("BindableEvent")
	ClientCore.Events.BuyMenuResponse.Event:Connect(function(payload)
		if not UIClient.BuyMenuFrame then return end
		if payload.money then
			UIClient.BuyMenuFrame.Visible = not UIClient.BuyMenuFrame.Visible
			if UIClient.BuyMoneyLabel then
				UIClient.BuyMoneyLabel.Text = "$" .. tostring(payload.money)
			end
		end
	end)

	ClientCore.Events.BombDefuseProgress = ClientCore.Events.BombDefuseProgress or Instance.new("BindableEvent")
	ClientCore.Events.BombDefuseProgress.Event:Connect(function(payload)
		if not UIClient.DefuseBar then return end
		local pct = math.max(0, payload.progress or 0)
		if pct <= 0 then
			UIClient.DefuseBar.Visible = false
		else
			UIClient.DefuseBar.Visible = true
			UIClient.DefuseBarFill.Size = UDim2.new(pct, 0, 1, 0)
		end
	end)

	ClientCore.Events.Scoreboard.Event:Connect(function(payload)
		if UIClient.Scoreboard then
			UIClient.UpdateScoreboard(payload.players or {})
			UIClient.Show("Scoreboard")
			task.delay(5, function()
				if UIClient.Scoreboard then
					UIClient.Show("HUD")
				end
			end)
		end
	end)

	ClientCore.Events.Effects.Event:Connect(function(payload)
		if payload.effectType == "PickupCollected" then
			pcall(function()
				UIClient:ShowNotification(("🎁 +%s"):format(payload.pickupType or "Pickup"))
			end)
		end
	end)
end

-----------------------------------------------------
-- NOTIFICATIONS
-----------------------------------------------------

function UIClient:ShowNotification(text, duration)
	if not self.NotificationArea then return end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 0, 28)
	label.Position = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(100, 255, 200)
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 14
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = self.NotificationArea

	-- Push existing notifications up
	for _, child in ipairs(self.NotificationArea:GetChildren()) do
		if child:IsA("TextLabel") and child ~= label then
			child.Position = UDim2.new(child.Position.X.Scale, child.Position.X.Offset,
				0, child.Position.Y.Offset - 32)
		end
	end

	task.delay(duration or 2, function()
		if label and label.Parent then
			label:Destroy()
		end
	end)
end

function UIClient.ShowAnnouncement(payload)
	local gui = UIClient.Gui
	if not gui then return end

	-- Remove old announcement
	local old = gui:FindFirstChild("Announcement")
	if old then old:Destroy() end

	local announceFrame = Instance.new("Frame")
	announceFrame.Name = "Announcement"
	announceFrame.Size = UDim2.new(0, 0, 0, 0)
	announceFrame.Position = UDim2.new(0.5, 0, 0.1, -30)
	announceFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
	announceFrame.BorderSizePixel = 0
	announceFrame.BackgroundTransparency = 0
	announceFrame.Parent = gui

	Instance.new("UICorner", announceFrame).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 50)
	stroke.Thickness = 2
	stroke.Parent = announceFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = payload.text or ""
	label.TextColor3 = Color3.fromRGB(255, 230, 150)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 28
	label.TextScaled = true
	label.Parent = announceFrame

	announceFrame.Size = UDim2.new(0.6, 0, 0, 0)
	announceFrame.Position = UDim2.new(0.2, 0, 0.1, -30)

	task.spawn(function()
		local tweenService = game:GetService("TweenService")
		local showTween = tweenService:Create(announceFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
			Size = UDim2.new(0.6, 0, 0, 60),
			Position = UDim2.new(0.2, 0, 0.1, -30),
			BackgroundTransparency = 0.1,
		})
		showTween:Play()
		showTween.Completed:Wait()

		task.wait(payload.duration or 4)

		local hideTween = tweenService:Create(announceFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.7, 0, 0, 0),
		})
		hideTween:Play()
		hideTween.Completed:Wait()
		announceFrame:Destroy()
	end)
end

-----------------------------------------------------
-- INIT
-----------------------------------------------------

function UIClient.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("PulseDeckArenaGui")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "PulseDeckArenaGui"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = playerGui
	end

	UIClient.Gui = gui

	-- Create screen layers
	UIClient.MainMenu = Instance.new("Frame")
	UIClient.MainMenu.Name = "MainMenu"
	UIClient.MainMenu.Size = UDim2.fromScale(1, 1)
	UIClient.MainMenu.BackgroundTransparency = 1
	UIClient.MainMenu.Visible = false
	UIClient.MainMenu.Parent = gui

	UIClient.DeckSelect = Instance.new("Frame")
	UIClient.DeckSelect.Name = "DeckSelect"
	UIClient.DeckSelect.Size = UDim2.fromScale(1, 1)
	UIClient.DeckSelect.BackgroundTransparency = 1
	UIClient.DeckSelect.Visible = false
	UIClient.DeckSelect.Parent = gui

	UIClient.HUD = Instance.new("Frame")
	UIClient.HUD.Name = "HUD"
	UIClient.HUD.Size = UDim2.fromScale(1, 1)
	UIClient.HUD.BackgroundTransparency = 1
	UIClient.HUD.Visible = false
	UIClient.HUD.Parent = gui

	UIClient.Scoreboard = Instance.new("Frame")
	UIClient.Scoreboard.Name = "Scoreboard"
	UIClient.Scoreboard.Size = UDim2.fromScale(1, 1)
	UIClient.Scoreboard.BackgroundTransparency = 1
	UIClient.Scoreboard.Visible = false
	UIClient.Scoreboard.Parent = gui

	UIClient.PostMatch = Instance.new("Frame")
	UIClient.PostMatch.Name = "PostMatch"
	UIClient.PostMatch.Size = UDim2.fromScale(1, 1)
	UIClient.PostMatch.BackgroundTransparency = 1
	UIClient.PostMatch.Visible = false
	UIClient.PostMatch.Parent = gui

	-- Build all screens
	UIClient.BuildMainMenu()
	UIClient.BuildDeckSelect()
	UIClient.BuildHUD()
	UIClient.BuildBuyMenu()
	UIClient.BuildShopUI()
	UIClient.BuildEmoteUI()
	UIClient.BuildPracticeRangeUI()
	UIClient.BuildScoreboard()
	UIClient.BuildPostMatch()
	UIClient.BindState()

	UIClient.Show("MainMenu")

	-- HUD bar smooth lerping on RenderStepped
	UIClient.HUDTargets = {
		health = 1, shield = 0, ability = 0, ultimate = 0,
	}
	UIClient.HUDSmoothing = {health = 1, shield = 0, ability = 0, ultimate = 0}

	RunService.RenderStepped:Connect(function()
		local t = UIClient.HUDTargets
		local s = UIClient.HUDSmoothing
		local rate = 0.12

		s.health = s.health + (t.health - s.health) * rate
		s.shield = s.shield + (t.shield - s.shield) * rate
		s.ability = s.ability + (t.ability - s.ability) * rate
		s.ultimate = s.ultimate + (t.ultimate - s.ultimate) * rate

		if UIClient.HealthBarFill then
			UIClient.HealthBarFill.Size = UDim2.new(s.health, 0, 1, 0)
			UIClient.HealthBarFill.BackgroundColor3 = Color3.fromRGB(
				255 - s.health * 155, 20 + s.health * 180, 20 + s.health * 30)
		end
		if UIClient.ShieldBarFill then
			UIClient.ShieldBarFill.Size = UDim2.new(s.shield, 0, 1, 0)
		end
		if UIClient.AbilityBarFill then
			UIClient.AbilityBarFill.Size = UDim2.new(s.ability, 0, 1, 0)
		end
		if UIClient.UltimateBarFill then
			UIClient.UltimateBarFill.Size = UDim2.new(s.ultimate, 0, 1, 0)
		end
	end)
end

return UIClient