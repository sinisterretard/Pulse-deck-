--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))

local HeroSystem = {}

HeroSystem.HeroesByGuid = {}
HeroSystem.HeroesByOwner = {}
HeroSystem.PartToHero = {}
HeroSystem.ControlledHero = {}

-- Enhanced ragdoll / visual states
local DEBRIEF_DURATION = 10

local function createRig(heroId, teamId, ownerId, guid, skinId)
	local heroDef = HeroConfig[heroId]
	local skinId = skinId or "default"
	local skinDef = heroDef.skins and heroDef.skins[skinId] or heroDef.skins.default
	local model = Instance.new("Model")
	model.Name = heroDef.displayName .. "_" .. guid

	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = heroDef.walkSpeed
	humanoid.JumpPower = heroDef.jumpPower
	humanoid.MaxHealth = heroDef.maxHealth
	humanoid.Health = heroDef.maxHealth
	humanoid.AutoRotate = true
	humanoid.Parent = model

	local function part(name, size, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local teamColor = (teamId == Config.TEAM_RED) and Config.RED_COLOR or Config.BLUE_COLOR

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.fromRGB(0, 0, 0))
	root.Transparency = 1
	root.CanCollide = false

	local torso = part("Torso", Vector3.new(2, 2.2, 1.2), heroDef.secondaryColor)
	local head = part("Head", Vector3.new(1.8, 1.8, 1.8), heroDef.primaryColor)
	local ra = part("Right Arm", Vector3.new(1, 2, 1.1), heroDef.secondaryColor)
	local la = part("Left Arm", Vector3.new(1, 2, 1.1), heroDef.secondaryColor)
	local rl = part("Right Leg", Vector3.new(1, 2, 1.1), heroDef.primaryColor)
	local ll = part("Left Leg", Vector3.new(1, 2, 1.1), heroDef.primaryColor)

	root.CFrame = CFrame.new(0, 5, 0)
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.6, 0)
	ra.CFrame = root.CFrame * CFrame.new(1.4, 0.5, 0)
	la.CFrame = root.CFrame * CFrame.new(-1.4, 0.5, 0)
	rl.CFrame = root.CFrame * CFrame.new(0.5, -1.6, 0)
	ll.CFrame = root.CFrame * CFrame.new(-0.5, -1.6, 0)

	local function weld(part0, part1, c0, name)
		local m6d = Instance.new("Motor6D")
		m6d.Part0 = part0
		m6d.Part1 = part1
		m6d.C0 = c0
		m6d.Name = name
		m6d.Parent = part0
	end

	weld(root, torso, CFrame.new(), "RootJoint")
	weld(torso, head, CFrame.new(0, 1.6, 0), "Neck")
	weld(torso, ra, CFrame.new(1.4, 0.5, 0), "RightShoulder")
	weld(torso, la, CFrame.new(-1.4, 0.5, 0), "LeftShoulder")
	weld(torso, rl, CFrame.new(0.5, -1.6, 0), "RightHip")
	weld(torso, ll, CFrame.new(-0.5, -1.6, 0), "LeftHip")

	-- Accent piece (team-colored stripe/highlight)
	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Size = Vector3.new(2.4, 1.4, 1.4)
	accent.Color = heroDef.accentColor or heroDef.primaryColor
	accent.Material = Enum.Material.Neon
	accent.Anchored = false
	accent.CanCollide = false
	accent.Parent = model
	weld(torso, accent, CFrame.new(0, 0.2, -0.1), "AccentWeld")

	-- Helmet / head accessory (skin-aware)
	if skinDef and skinDef.helmet then
		local helmet = Instance.new("Part")
		helmet.Name = "Helmet"
		helmet.Size = Vector3.new(2.1, 1.5, 2.1)
		helmet.Color = skinDef.helmetColor or heroDef.primaryColor
		helmet.Material = Enum.Material.SmoothPlastic
		helmet.Anchored = false
		helmet.CanCollide = false
		helmet.Parent = model
		weld(head, helmet, CFrame.new(0, 0.05, 0), "HelmetWeld")

		-- Visor
		local visor = Instance.new("Part")
		visor.Name = "Visor"
		visor.Size = Vector3.new(1.6, 0.6, 2.15)
		visor.Color = skinDef.visorColor or Color3.fromRGB(200, 255, 255)
		visor.Material = Enum.Material.Neon
		visor.Transparency = 0.2
		visor.Anchored = false
		visor.CanCollide = false
		visor.Parent = model
		weld(helmet, visor, CFrame.new(0, 0.15, 0), "VisorWeld")
	end

	-- Clothing overlays from skin
	if skinDef then
		-- Shirt / chest plate overlay
		if skinDef.shirtColor then
			local shirtOverlay = Instance.new("Part")
			shirtOverlay.Name = "ClothingShirt"
			shirtOverlay.Size = Vector3.new(2.2, 2.4, 1.3)
			shirtOverlay.Color = skinDef.shirtColor
			shirtOverlay.Material = skinDef.shirtMaterial or Enum.Material.SmoothPlastic
			shirtOverlay.Transparency = skinDef.shirtTransparency or 0
			shirtOverlay.Anchored = false
			shirtOverlay.CanCollide = false
			shirtOverlay.Parent = model
			weld(torso, shirtOverlay, CFrame.new(0, 0.1, 0), "ShirtWeld")
		end

		-- Pants overlay
		if skinDef.pantsColor then
			local pantsOverlay = Instance.new("Part")
			pantsOverlay.Name = "ClothingPants"
			pantsOverlay.Size = Vector3.new(2.1, 2.2, 1.2)
			pantsOverlay.Color = skinDef.pantsColor
			pantsOverlay.Material = skinDef.pantsMaterial or Enum.Material.SmoothPlastic
			pantsOverlay.Transparency = skinDef.pantsTransparency or 0
			pantsOverlay.Anchored = false
			pantsOverlay.CanCollide = false
			pantsOverlay.Parent = model
			local pWeld = Instance.new("Motor6D")
			pWeld.Part0 = torso
			pWeld.Part1 = pantsOverlay
			pWeld.C0 = CFrame.new(0, -1.2, 0)
			pWeld.Name = "PantsWeld"
			pWeld.Parent = torso
		end

		-- Cape
		if skinDef.cape then
			local cape = Instance.new("Part")
			cape.Name = "Cape"
			cape.Size = Vector3.new(0.1, 4, 4)
			cape.Color = skinDef.capeColor or heroDef.accentColor or Color3.fromRGB(200, 50, 50)
			cape.Material = Enum.Material.Fabric
			cape.Transparency = 0.2
			cape.Anchored = false
			cape.CanCollide = false
			cape.Parent = model
			local capeWeld = Instance.new("Motor6D")
			capeWeld.Part0 = torso
			capeWeld.Part1 = cape
			capeWeld.C0 = CFrame.new(0, 1, 0.6)
			capeWeld.Name = "CapeWeld"
			capeWeld.Parent = torso
		end

		-- Shoulder armor (skin-specific overrides generic)
		if skinDef.shoulderArmor then
			local rShoulder = Instance.new("Part")
			rShoulder.Name = "RightShoulderPad"
			rShoulder.Size = Vector3.new(1.2, 1.4, 1.4)
			rShoulder.Color = skinDef.accentColor or heroDef.accentColor or Color3.fromRGB(80, 80, 80)
			rShoulder.Material = Enum.Material.Metal
			rShoulder.Anchored = false
			rShoulder.CanCollide = false
			rShoulder.Parent = model
			weld(ra, rShoulder, CFrame.new(0, 0.5, 0), "RShoulderPadWeld")

			local lShoulder = Instance.new("Part")
			lShoulder.Name = "LeftShoulderPad"
			lShoulder.Size = Vector3.new(1.2, 1.4, 1.4)
			lShoulder.Color = skinDef.accentColor or heroDef.accentColor or Color3.fromRGB(80, 80, 80)
			lShoulder.Material = Enum.Material.Metal
			lShoulder.Anchored = false
			lShoulder.CanCollide = false
			lShoulder.Parent = model
			weld(la, lShoulder, CFrame.new(0, 0.5, 0), "LShoulderPadWeld")
		end

		-- Emissive glow for rare/legendary skins
		if skinDef.emissive then
			local glowColor = skinDef.glowColor or heroDef.accentColor or Color3.fromRGB(255, 200, 50)
			local glowPart = Instance.new("Part")
			glowPart.Name = "SkinGlow"
			glowPart.Size = Vector3.new(3, 5, 3)
			glowPart.Color = glowColor
			glowPart.Material = Enum.Material.Neon
			glowPart.Transparency = 0.7
			glowPart.Anchored = false
			glowPart.CanCollide = false
			glowPart.Parent = model
			local gWeld = Instance.new("Motor6D")
			gWeld.Part0 = torso
			gWeld.Part1 = glowPart
			gWeld.C0 = CFrame.new(0, 0, 0)
			gWeld.Name = "GlowWeld"
			gWeld.Parent = torso

			local glowLight = Instance.new("PointLight")
			glowLight.Color = glowColor
			glowLight.Brightness = 1
			glowLight.Range = 12
			glowLight.Parent = glowPart
		end
	end

	-- Weapon model
	local weaponCfg = WeaponConfig[heroDef.weaponId]
	local weaponColor = heroDef.secondaryColor
	local weaponPart
	if weaponCfg and weaponCfg.weaponModel == "Rifle" then
		weaponPart = part("Weapon", Vector3.new(0.6, 0.6, 3), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.5, -0.8) * CFrame.Angles(0, math.rad(90), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Shotgun" then
		weaponPart = part("Weapon", Vector3.new(0.8, 0.8, 2.5), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.6, -0.8) * CFrame.Angles(0, math.rad(100), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "SMG" then
		weaponPart = part("Weapon", Vector3.new(0.5, 0.5, 2.2), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.4, -0.7) * CFrame.Angles(0, math.rad(90), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Carbine" then
		weaponPart = part("Weapon", Vector3.new(0.55, 0.55, 2.8), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.5, -0.9) * CFrame.Angles(0, math.rad(95), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Sniper" then
		weaponPart = part("Weapon", Vector3.new(0.7, 0.7, 4), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.3, -1.2) * CFrame.Angles(0, math.rad(90), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Launcher" then
		weaponPart = part("Weapon", Vector3.new(0.9, 0.9, 2.8), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.8, -0.6) * CFrame.Angles(0, math.rad(80), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Beam" then
		weaponPart = part("Weapon", Vector3.new(0.4, 0.4, 2.5), weaponColor, Enum.Material.Neon)
		weld(ra, weaponPart, CFrame.new(0, -0.5, -0.7) * CFrame.Angles(0, math.rad(90), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Sword" then
		weaponPart = part("Weapon", Vector3.new(0.15, 0.15, 3.5), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.3, -1.5) * CFrame.Angles(0, math.rad(90), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Hammer" then
		weaponPart = part("Weapon", Vector3.new(1.2, 1.5, 2), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.5, -1) * CFrame.Angles(0, math.rad(85), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Flamethrower" then
		weaponPart = part("Weapon", Vector3.new(1, 0.8, 3), weaponColor, Enum.Material.Neon)
		weld(ra, weaponPart, CFrame.new(0, -0.5, -0.5) * CFrame.Angles(0, math.rad(90), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Plasma" then
		weaponPart = part("Weapon", Vector3.new(0.7, 0.7, 2.5), weaponColor, Enum.Material.Neon)
		weld(ra, weaponPart, CFrame.new(0, -0.5, -0.7) * CFrame.Angles(0, math.rad(90), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "GrenadeLauncher" then
		weaponPart = part("Weapon", Vector3.new(1, 1, 2.2), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.7, -0.5) * CFrame.Angles(0, math.rad(80), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Energy" then
		weaponPart = part("Weapon", Vector3.new(0.5, 1.5, 2), weaponColor, Enum.Material.Neon)
		weld(ra, weaponPart, CFrame.new(0, -0.5, -0.8) * CFrame.Angles(0, math.rad(90), 0), "WeaponWeld")
	elseif weaponCfg and weaponCfg.weaponModel == "Mortar" then
		weaponPart = part("Weapon", Vector3.new(1, 1, 2.5), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.8, -0.4) * CFrame.Angles(0, math.rad(75), 0), "WeaponWeld")
	else
		weaponPart = part("Weapon", Vector3.new(0.6, 0.6, 2.5), weaponColor, Enum.Material.Metal)
		weld(ra, weaponPart, CFrame.new(0, -0.5, -0.8) * CFrame.Angles(0, math.rad(90), 0), "WeaponWeld")
	end

	-- Helmet / head accessory
	if heroDef.skins and heroDef.skins.default and heroDef.skins.default.helmet then
		local helmet = Instance.new("Part")
		helmet.Name = "Helmet"
		helmet.Size = Vector3.new(2.1, 1.5, 2.1)
		helmet.Color = heroDef.primaryColor
		helmet.Material = Enum.Material.SmoothPlastic
		helmet.Anchored = false
		helmet.CanCollide = false
		helmet.Parent = model
		weld(head, helmet, CFrame.new(0, 0.05, 0), "HelmetWeld")

		-- Visor
		local visor = Instance.new("Part")
		visor.Name = "Visor"
		visor.Size = Vector3.new(1.6, 0.6, 2.15)
		visor.Color = heroDef.skins.default.visorColor or Color3.fromRGB(200, 255, 255)
		visor.Material = Enum.Material.Neon
		visor.Transparency = 0.2
		visor.Anchored = false
		visor.CanCollide = false
		visor.Parent = model
		weld(helmet, visor, CFrame.new(0, 0.15, 0), "VisorWeld")
	end

	-- Health bar above head
	local healthGui = Instance.new("BillboardGui")
	healthGui.Name = "HealthBar"
	healthGui.Size = UDim2.new(0, 100, 0, 14)
	healthGui.StudsOffset = Vector3.new(0, 3, 0)
	healthGui.AlwaysOnTop = true
	healthGui.MaxDistance = 80
	healthGui.Parent = head

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bg.BorderSizePixel = 0
	bg.Parent = healthGui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = teamColor
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = fill

	-- Hero name plate
	local namePlate = Instance.new("BillboardGui")
	namePlate.Name = "NamePlate"
	namePlate.Size = UDim2.new(0, 150, 0, 22)
	namePlate.StudsOffset = Vector3.new(0, 4, 0)
	namePlate.AlwaysOnTop = true
	namePlate.MaxDistance = 100
	namePlate.Parent = head

	local nameBg = Instance.new("Frame")
	nameBg.Size = UDim2.new(1, 8, 1, 4)
	nameBg.Position = UDim2.new(0, -4, 0, -2)
	nameBg.BackgroundColor3 = Color3.fromRGB(10, 10, 20, 200)
	nameBg.BorderSizePixel = 0
	nameBg.Parent = namePlate

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = heroDef.displayName
	nameLabel.TextColor3 = Color3.fromRGB(245, 245, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.Parent = namePlate

	-- Ability icon indicator
	local abilityIcon = Instance.new("BillboardGui")
	abilityIcon.Name = "AbilityIcon"
	abilityIcon.Size = UDim2.new(0, 24, 0, 24)
	abilityIcon.StudsOffset = Vector3.new(-2, 4.5, 0)
	abilityIcon.AlwaysOnTop = true
	abilityIcon.MaxDistance = 60
	abilityIcon.Parent = head

	local iconBg = Instance.new("Frame")
	iconBg.Size = UDim2.new(1, 0, 1, 0)
	iconBg.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	iconBg.BorderSizePixel = 0
	iconBg.Parent = abilityIcon

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "Q"
	iconLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
	iconLabel.Font = Enum.Font.GothamSemibold
	iconLabel.TextScaled = true
	iconLabel.Parent = iconBg

	model.PrimaryPart = root
	model:SetAttribute("HeroId", heroId)
	model:SetAttribute("HeroGuid", guid)
	model:SetAttribute("OwnerId", ownerId)
	model:SetAttribute("TeamId", teamId)
	model:SetAttribute("IsHero", true)
	model:SetAttribute("IsControlled", false)
	model:SetAttribute("Alive", true)

	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			HeroSystem.PartToHero[inst] = guid
		end
	end

	return model
end

function HeroSystem.GetHeroFromPart(part)
	if not part then return nil end
	local guid = HeroSystem.PartToHero[part]
	if guid then
		return HeroSystem.HeroesByGuid[guid]
	end
	return nil
end

function HeroSystem.GetControlledHero(player)
	local guid = HeroSystem.ControlledHero[player.UserId]
	if not guid then return nil end
	return HeroSystem.HeroesByGuid[guid]
end

function HeroSystem.GetControlledHeroByUserId(userId)
	local guid = HeroSystem.ControlledHero[userId]
	if not guid then return nil end
	return HeroSystem.HeroesByGuid[guid]
end

function HeroSystem.SpawnHeroesForOwner(ownerId, teamId, deck, ownerPlayer)
	local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))
	local list = {}
	HeroSystem.HeroesByOwner[ownerId] = list

	for slot, heroId in ipairs(deck) do
		local guid = HttpService:GenerateGUID(false)
		-- Determine skin: use equipped skin from progression if available
		local skinId = "default"
		if ownerPlayer and ProgressionSystem and ProgressionSystem.Profiles then
			local profile = ProgressionSystem.Profiles[ownerPlayer.UserId]
			if profile and profile.EquippedSkin then
				-- Verify the skin is unlocked
				local heroDef = HeroConfig[heroId]
				if heroDef.skins and heroDef.skins[profile.EquippedSkin] then
					skinId = profile.EquippedSkin
				end
			end
		end
		local model = createRig(heroId, teamId, ownerId, guid, skinId)
		model.Parent = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Heroes")

		local spawnList = (teamId == Config.TEAM_RED) and Config.MAP.RED_SPAWN_PADS or Config.MAP.BLUE_SPAWN_PADS
		local ffaList = Config.MAP.FFA_SPAWNS

		local spawnPos
		if MatchSystem.GameMode == "FFA" then
			spawnPos = ffaList[(slot - 1) % #ffaList + 1]
		else
			spawnPos = spawnList[slot % #spawnList + 1]
		end

		model:PivotTo(CFrame.new(spawnPos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))))

		local heroDef = HeroConfig[heroId]
		local weaponId = heroDef.weaponId
		local weapon = WeaponConfig[weaponId]

		local hero = {
			Guid = guid,
			HeroId = heroId,
			OwnerId = ownerId,
			OwnerPlayer = ownerPlayer,
			TeamId = teamId,
			Slot = slot,
			Model = model,
			Humanoid = model:FindFirstChildOfClass("Humanoid"),
			Root = model.PrimaryPart,
			IsControlled = false,
			Alive = true,
			Health = heroDef.maxHealth,
			MaxHealth = heroDef.maxHealth,
			WeaponId = weaponId,
			AbilityId = heroDef.abilityId,
			UltimateId = heroDef.ultimateId,
			Ammo = weapon.magazineSize,
			ReserveAmmo = weapon.reserveAmmo or (weapon.magazineSize * 3),
			IsReloading = false,
			ReloadEndAt = 0,
			AbilityReadyAt = 0,
			UltimateReadyAt = 0,
			UltimateCharge = 0,
			UltimateChargeMax = 100,
			NextFireAt = 0,
			LastSwitchAt = 0,
			InvulnerableUntil = 0,
			MarkedUntil = 0,
			MarkedByOwnerId = nil,
			Sentry = nil,
			Mines = {},
			Stunned = false,
			IsStealthed = false,
			KillCount = 0,
			DeathCount = 0,
			AssistCount = 0,
			DamageDealt = 0,
			DamageTaken = 0,
		-- Weapon skin tracking
		WeaponSkin = heroDef.weaponSkin or "Default",
		-- Selected skin
		SkinEquipped = "default",
		-- Status effects
		ActiveEffects = {},
		-- Armor & Shield
		Armor = 0,
		MaxArmor = 100,
		-- Power effect multipliers
		DamageMultiplier = 1,
		-- Last known position for AI tracking
		LastKnownPosition = model.PrimaryPart.Position,
		-- Shield value
		ShieldHealth = 0,
		MaxShield = 0,
		-- Bomb defuse
		HasBomb = false,
		-- Economy (Bomb mode)
		Money = 0,
		SpentThisRound = 0,
		}

		HeroSystem.HeroesByGuid[guid] = hero
		table.insert(list, hero)

		if ownerPlayer and slot == 1 then
			HeroSystem.AssignControl(ownerPlayer, hero)
		end
	end
end

function HeroSystem.AssignControl(player, hero)
	local oldGuid = HeroSystem.ControlledHero[player.UserId]
	local old = oldGuid and HeroSystem.HeroesByGuid[oldGuid] or nil
	if old then
		old.IsControlled = false
		old.Model:SetAttribute("IsControlled", false)
	end

	hero.IsControlled = true
	hero.Model:SetAttribute("IsControlled", true)
	HeroSystem.ControlledHero[player.UserId] = hero.Guid
	player.Character = hero.Model

	local AISystem = require(script.Parent:WaitForChild("AISystem"))
	AISystem.EnableHeroAI(hero, false)
	if old then
		AISystem.EnableHeroAI(old, true)
	end

	local remotes = ReplicatedStorage:FindFirstChild("PulseDeckArena") and ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes")
	local event = remotes and remotes:FindFirstChild("HeroControlChanged")
	if event and event:IsA("RemoteEvent") then
		event:FireClient(player, {
			heroGuid = hero.Guid,
			slot = hero.Slot,
			heroId = hero.HeroId,
			position = hero.Root.Position,
		})
	end
end

function HeroSystem.SwitchHero(player, slot)
	local list = HeroSystem.HeroesByOwner[player.UserId]
	if not list then return end
	local hero = list[slot]
	if not hero or not hero.Alive then return end
	local current = HeroSystem.GetControlledHero(player)
	if current and os.clock() - current.LastSwitchAt < Config.SWITCH_COOLDOWN then
		return
	end
	if current then
		current.LastSwitchAt = os.clock()
	end
	HeroSystem.AssignControl(player, hero)
end

function HeroSystem.KillHero(hero, attackerId)
	if not hero.Alive then return end
	hero.Alive = false
	hero.IsControlled = false
	hero.DeathCount += 1
	hero.Model:SetAttribute("Alive", false)
	hero.Humanoid.Health = 0

	-- Reset effects on death
	hero.Stunned = false
	hero.IsStealthed = false

	if hero.Sentry and hero.Sentry.Part then
		hero.Sentry.Part:Destroy()
		hero.Sentry = nil
	end

	-- Destroy mines on death
	for _, mine in ipairs(hero.Mines) do
		if mine.Part then mine.Part:Destroy() end
	end
	hero.Mines = {}

	-- Destroy shields on death
	hero.ShieldHealth = 0

	-- Hide model (ragdoll / death)
	hero.Model:PivotTo(CFrame.new(0, -100, 0))

	task.delay(Config.HERO_RESPAWN_TIME, function()
		HeroSystem.RespawnHero(hero)
	end)

	local ownerPlayer = hero.OwnerPlayer
	if ownerPlayer then
		if HeroSystem.ControlledHero[ownerPlayer.UserId] == hero.Guid then
			HeroSystem.ControlledHero[ownerPlayer.UserId] = nil
		end
		local list = HeroSystem.HeroesByOwner[ownerPlayer.UserId]
		for _, h in ipairs(list) do
			if h.Alive then
				HeroSystem.AssignControl(ownerPlayer, h)
				return
			end
		end
		ownerPlayer.Character = nil
	end
end

function HeroSystem.RespawnHero(hero)
	hero.Alive = true
	hero.Health = hero.MaxHealth
	hero.ShieldHealth = hero.MaxShield
	hero.Humanoid.MaxHealth = hero.MaxHealth
	hero.Humanoid.Health = hero.MaxHealth
	local weapon = WeaponConfig[hero.WeaponId]
	hero.Ammo = weapon.magazineSize
	hero.ReserveAmmo = weapon.reserveAmmo or (weapon.magazineSize * 3)
	hero.IsReloading = false
	hero.ReloadEndAt = 0
	hero.AbilityReadyAt = os.clock()
	hero.UltimateReadyAt = os.clock() + 60
	hero.UltimateCharge = 50
	hero.InvulnerableUntil = os.clock() + 2
	hero.ActiveEffects = {}
	hero.Stunned = false
	hero.IsStealthed = false

	-- Remove old model
	if hero.Model then
		for _, inst in ipairs(hero.Model:GetDescendants()) do
			if inst:IsA("BasePart") then
				HeroSystem.PartToHero[inst] = nil
			end
		end
		hero.Model:Destroy()
	end

	local skinId = hero.SkinEquipped or "default"
	local model = createRig(hero.HeroId, hero.TeamId, hero.OwnerId, hero.Guid, skinId)
	model.Parent = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Heroes")
	hero.Model = model
	hero.Root = model.PrimaryPart
	hero.Humanoid = model:FindFirstChildOfClass("Humanoid")
	hero.Humanoid.MaxHealth = hero.MaxHealth
	hero.Humanoid.Health = hero.MaxHealth

	local spawnList = (hero.TeamId == Config.TEAM_RED) and Config.MAP.RED_SPAWN_PADS or Config.MAP.BLUE_SPAWN_PADS
	local ffaList = Config.MAP.FFA_SPAWNS
	local spawnPos
	if MatchSystem.GameMode == "FFA" then
		spawnPos = ffaList[math.random(1, #ffaList)]
	else
		spawnPos = spawnList[math.random(1, #spawnList)]
	end
	hero.Model:PivotTo(CFrame.new(spawnPos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))))

	if hero.OwnerPlayer and not HeroSystem.GetControlledHero(hero.OwnerPlayer) then
		HeroSystem.AssignControl(hero.OwnerPlayer, hero)
	end
end

function HeroSystem.GetSnapshot()
	local snapshot = {}
	for guid, hero in pairs(HeroSystem.HeroesByGuid) do
		snapshot[guid] = {
			heroId = hero.HeroId,
			ownerUserId = hero.OwnerId,
			teamId = hero.TeamId,
			slot = hero.Slot,
			health = hero.Health,
			maxHealth = hero.MaxHealth,
			shieldHealth = hero.ShieldHealth,
			maxShield = hero.MaxShield,
			alive = hero.Alive,
			ammo = hero.Ammo,
			reserveAmmo = hero.ReserveAmmo,
			isReloading = hero.IsReloading,
			abilityCooldownRemaining = math.max(0, hero.AbilityReadyAt - os.clock()),
			ultimateCharge = hero.UltimateCharge,
			isControlled = hero.IsControlled,
			position = hero.Root.Position,
			killCount = hero.KillCount,
			deathCount = hero.DeathCount,
			damageDealt = hero.DamageDealt,
			weaponId = hero.WeaponId,
			weaponSkin = hero.WeaponSkin,
			skinEquipped = hero.SkinEquipped,
			stealthed = hero.IsStealthed,
			stunned = hero.Stunned,
		}
	end
	return snapshot
end

function HeroSystem.RemoveOwner(ownerId)
	local list = HeroSystem.HeroesByOwner[ownerId]
	if not list then return end
	for _, hero in ipairs(list) do
		if hero.Model then
			for _, inst in ipairs(hero.Model:GetDescendants()) do
				if inst:IsA("BasePart") then
					HeroSystem.PartToHero[inst] = nil
				end
			end
			hero.Model:Destroy()
		end
		HeroSystem.HeroesByGuid[hero.Guid] = nil
	end
	HeroSystem.HeroesByOwner[ownerId] = nil
	HeroSystem.ControlledHero[ownerId] = nil
end

function HeroSystem.ClearAll()
	for _, hero in pairs(HeroSystem.HeroesByGuid) do
		if hero.Model then
			for _, inst in ipairs(hero.Model:GetDescendants()) do
				if inst:IsA("BasePart") then
					HeroSystem.PartToHero[inst] = nil
				end
			end
			hero.Model:Destroy()
		end
	end
	HeroSystem.HeroesByGuid = {}
	HeroSystem.HeroesByOwner = {}
	HeroSystem.ControlledHero = {}
	HeroSystem.PartToHero = {}
end

return HeroSystem