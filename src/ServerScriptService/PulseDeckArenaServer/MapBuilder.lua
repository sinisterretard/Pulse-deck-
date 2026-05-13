--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local Util = require(sharedRoot:WaitForChild("Util"))

local MapBuilder = {}

local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))

local function getRemotes()
	local root = ReplicatedStorage:FindFirstChild("PulseDeckArena")
	return root and root:FindFirstChild("Remotes")
end

local function fireEffect(payload)
	local remotes = getRemotes()
	local event = remotes and remotes:FindFirstChild("EffectsEvent")
	if event and event:IsA("RemoteEvent") then
		event:FireAllClients(payload)
	end
end

local function getWorldFolder(name)
	local world = workspace:WaitForChild("PulseDeckArenaWorld")
	return world:WaitForChild(name) :: Folder
end

local function clearFolder(folder)
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

local function makeWaypoint(folder, name, pos, laneName, order)
	local wp = Instance.new("Part")
	wp.Name = name
	wp.Size = Vector3.new(2, 0.5, 2)
	wp.Transparency = 1
	wp.Anchored = true
	wp.CanCollide = false
	wp.Position = pos
	wp.Parent = folder
	wp:SetAttribute("LaneName", laneName)
	wp:SetAttribute("Order", order)
	CollectionService:AddTag(wp, "AIWaypoint")
end

local function addNeonStrip(name, size, position, color, rotation, parent)
	local strip = Util.MakePart(name, size, position, color, Enum.Material.Neon, true)
	strip.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0)
	strip.Parent = parent
	return strip
end

local function addGlowPart(name, size, position, color, parent, transparency)
	local part = Util.MakePart(name, size, position, color, Enum.Material.Neon, true)
	part.Transparency = transparency or 0.4
	part.CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.5
	light.Range = 12
	light.Parent = part

	part.Parent = parent
	return part
end

function MapBuilder.BuildNeonFoundry()
	local mapFolder = getWorldFolder("Map")
	local waypointFolder = getWorldFolder("Waypoints")
	local effectsFolder = getWorldFolder("Effects")
	local projectilesFolder = getWorldFolder("Projectiles")
	local pickupsFolder = getWorldFolder("Pickups")

	clearFolder(mapFolder)
	clearFolder(waypointFolder)
	clearFolder(effectsFolder)
	clearFolder(projectilesFolder)
	clearFolder(pickupsFolder)

	-- Arena floor with neon grid pattern
	local floor = Util.MakePart("ArenaFloor", Vector3.new(300, 1, 210), Vector3.new(0, -0.5, 0), Color3.fromRGB(20, 22, 30), Enum.Material.SmoothPlastic, true)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.Parent = mapFolder

	-- Floor grid lines
	for x = -140, 140, 20 do
		addNeonStrip("GridLine_X_" .. x, Vector3.new(0.2, 0.01, 210), Vector3.new(x, 0, 0), Color3.fromRGB(40, 44, 56), 0, mapFolder)
	end
	for z = -100, 100, 20 do
		addNeonStrip("GridLine_Z_" .. z, Vector3.new(300, 0.01, 0.2), Vector3.new(0, 0, z), Color3.fromRGB(40, 44, 56), 0, mapFolder)
	end

	-- Walls
	local function createWall(name, size, position, color)
		local wall = Util.MakePart(name, size, position, color, Enum.Material.Concrete, true)
		wall.Parent = mapFolder
		return wall
	end

	createWall("Wall_North", Vector3.new(308, 40, 6), Vector3.new(0, 20, 103), Color3.fromRGB(18, 20, 28))
	createWall("Wall_South", Vector3.new(308, 40, 6), Vector3.new(0, 20, -103), Color3.fromRGB(18, 20, 28))
	createWall("Wall_West", Vector3.new(6, 40, 212), Vector3.new(-153, 20, 0), Color3.fromRGB(18, 20, 28))
	createWall("East_Wall", Vector3.new(6, 40, 212), Vector3.new(153, 20, 0), Color3.fromRGB(18, 20, 28))

	-- Add wall trim (neon accents on walls)
	for _, wallData in ipairs({
		{name = "NorthTrim", pos = Vector3.new(0, 20, 100), size = Vector3.new(300, 0.3, 0.3), color = Config.RED_COLOR},
		{name = "SouthTrim", pos = Vector3.new(0, 20, -100), size = Vector3.new(300, 0.3, 0.3), color = Config.BLUE_COLOR},
		{name = "WestTrim", pos = Vector3.new(-150, 20, 0), size = Vector3.new(0.3, 40, 200), color = Config.RED_COLOR},
		{name = "EastTrim", pos = Vector3.new(150, 20, 0), size = Vector3.new(0.3, 40, 200), color = Config.BLUE_COLOR},
	}) do
		local trim = Util.MakePart(wallData.name, wallData.size, wallData.pos, wallData.color, Enum.Material.Neon, true)
		trim.Parent = mapFolder
	end

	-- Team platforms
	local redPlatform = Util.MakePart("RedPlatform", Vector3.new(48, 1.5, 84), Vector3.new(-130, 0.75, 0), Color3.fromRGB(80, 28, 34), Enum.Material.SmoothPlastic, true)
	redPlatform.Parent = mapFolder
	local bluePlatform = Util.MakePart("BluePlatform", Vector3.new(48, 1.5, 84), Vector3.new(130, 0.75, 0), Color3.fromRGB(24, 56, 84), Enum.Material.SmoothPlastic, true)
	bluePlatform.Parent = mapFolder

	-- Platform edges (neon)
	local function addPlatformEdge(name, size, pos, color, parent)
		local edge = Util.MakePart(name, size, pos, color, Enum.Material.Neon, true)
		edge.Parent = parent
	end

	addPlatformEdge("RedEdge_Front", Vector3.new(48, 0.3, 0.3), Vector3.new(-130, 1.6, 42), Config.RED_COLOR, mapFolder)
	addPlatformEdge("RedEdge_Back", Vector3.new(48, 0.3, 0.3), Vector3.new(-130, 1.6, -42), Config.RED_COLOR, mapFolder)
	addPlatformEdge("BlueEdge_Front", Vector3.new(48, 0.3, 0.3), Vector3.new(130, 1.6, 42), Config.BLUE_COLOR, mapFolder)
	addPlatformEdge("BlueEdge_Back", Vector3.new(48, 0.3, 0.3), Vector3.new(130, 1.6, -42), Config.BLUE_COLOR, mapFolder)

	-- Covers and obstacles
	local covers = {
		-- Main lane covers
		{name = "Cover_Main_1", size = Vector3.new(14, 8, 8), pos = Vector3.new(-50, 4, -18), color = Color3.fromRGB(35, 40, 55)},
		{name = "Cover_Main_2", size = Vector3.new(14, 8, 8), pos = Vector3.new(50, 4, 18), color = Color3.fromRGB(35, 40, 55)},
		{name = "Cover_Main_3", size = Vector3.new(12, 6, 8), pos = Vector3.new(-20, 3, 25), color = Color3.fromRGB(30, 35, 45)},
		{name = "Cover_Main_4", size = Vector3.new(12, 6, 8), pos = Vector3.new(20, 3, -25), color = Color3.fromRGB(30, 35, 45)},

		-- Side covers
		{name = "Cover_Side_L1", size = Vector3.new(10, 7, 8), pos = Vector3.new(-75, 3.5, 45), color = Color3.fromRGB(32, 36, 48)},
		{name = "Cover_Side_L2", size = Vector3.new(10, 7, 8), pos = Vector3.new(-75, 3.5, -45), color = Color3.fromRGB(32, 36, 48)},
		{name = "Cover_Side_R1", size = Vector3.new(10, 7, 8), pos = Vector3.new(75, 3.5, 45), color = Color3.fromRGB(32, 36, 48)},
		{name = "Cover_Side_R2", size = Vector3.new(10, 7, 8), pos = Vector3.new(75, 3.5, -45), color = Color3.fromRGB(32, 36, 48)},

		-- Center barriers
		{name = "Center_Barrier_L", size = Vector3.new(8, 5, 6), pos = Vector3.new(-6, 2.5, 8), color = Color3.fromRGB(45, 45, 55)},
		{name = "Center_Barrier_R", size = Vector3.new(8, 5, 6), pos = Vector3.new(6, 2.5, -8), color = Color3.fromRGB(45, 45, 55)},

		-- Flanking routes
		{name = "Flank_Block_1", size = Vector3.new(6, 4, 12), pos = Vector3.new(-40, 2, 50), color = Color3.fromRGB(30, 34, 42)},
		{name = "Flank_Block_2", size = Vector3.new(6, 4, 12), pos = Vector3.new(40, 2, -50), color = Color3.fromRGB(30, 34, 42)},
	}

	for _, c in ipairs(covers) do
		local part = Util.MakePart(c.name, c.size, c.pos, c.color, Enum.Material.SmoothPlastic, true)
		part.Parent = mapFolder
	end

	-- Sniper platforms (elevated)
	local sniperPlatforms = {
		{name = "Sniper_Plat_L", pos = Vector3.new(-55, 9, 55), color = Color3.fromRGB(35, 42, 55)},
		{name = "Sniper_Plat_R", pos = Vector3.new(55, 9, -55), color = Color3.fromRGB(35, 42, 55)},
		{name = "Sniper_Plat_MidL", pos = Vector3.new(-30, 7, 70), color = Color3.fromRGB(32, 38, 50)},
		{name = "Sniper_Plat_MidR", pos = Vector3.new(30, 7, -70), color = Color3.fromRGB(32, 38, 50)},
	}

	for i, sp in ipairs(sniperPlatforms) do
		local plat = Util.MakePart(sp.name, Vector3.new(18, 1.5, 18), sp.pos, sp.color, Enum.Material.SmoothPlastic, true)
		plat.Parent = mapFolder

		-- Railings
		for _, offset in ipairs({{8, 0, 0}, {-8, 0, 0}, {0, 0, 8}, {0, 0, -8}}) do
			local rail = Util.MakePart(sp.name .. "_Rail", Vector3.new(0.3, 3, 0.3), sp.pos + offset, Color3.fromRGB(100, 120, 140), Enum.Material.Metal, true)
			rail.Parent = mapFolder
		end
	end

	-- Jump pads
	local jumpPads = {
		Vector3.new(-90, 1.5, 50),
		Vector3.new(90, 1.5, -50),
		Vector3.new(-55, 1.5, -60),
		Vector3.new(55, 1.5, 60),
	}
	for i, pos in ipairs(jumpPads) do
		local jp = Util.MakePart("JumpPad_" .. i, Vector3.new(8, 0.7, 8), pos, Color3.fromRGB(60, 140, 255), Enum.Material.Neon, true)
		jp.Parent = mapFolder

		-- Glow under pad
		local glow = Util.MakePart("JumpPadGlow_" .. i, Vector3.new(10, 0.01, 10), pos - Vector3.new(0, 0.4, 0), Color3.fromRGB(60, 140, 255), Enum.Material.Neon, true)
		glow.Transparency = 0.6
		glow.Parent = mapFolder
	end

	-- Elevated walkways
	local walkways = {
		{name = "Walkway_1", size = Vector3.new(50, 1.5, 6), pos = Vector3.new(0, 6, 35), color = Color3.fromRGB(38, 42, 52)},
		{name = "Walkway_2", size = Vector3.new(50, 1.5, 6), pos = Vector3.new(0, 6, -35), color = Color3.fromRGB(38, 42, 52)},
		{name = "Walkway_3", size = Vector3.new(6, 1.5, 40), pos = Vector3.new(-45, 5, 0), color = Color3.fromRGB(36, 40, 50)},
		{name = "Walkway_4", size = Vector3.new(6, 1.5, 40), pos = Vector3.new(45, 5, 0), color = Color3.fromRGB(36, 40, 50)},
	}

	for _, w in ipairs(walkways) do
		local walk = Util.MakePart(w.name, w.size, w.pos, w.color, Enum.Material.SmoothPlastic, true)
		walk.Parent = mapFolder

		-- Underglow
		local underGlow = Util.MakePart(w.name .. "_Glow", Vector3.new(w.size.X + 0.5, 0.01, w.size.Z + 0.5), w.pos - Vector3.new(0, 0.8, 0), Color3.fromRGB(50, 80, 120), Enum.Material.Neon, true)
		underGlow.Transparency = 0.5
		underGlow.Parent = mapFolder
	end

	-- Walls for sub-lanes
	local subWalls = {
		{name = "Wall_Mid_Upper", size = Vector3.new(40, 15, 4), pos = Vector3.new(0, 7.5, 65), color = Color3.fromRGB(25, 28, 38)},
		{name = "Wall_Mid_Lower", size = Vector3.new(40, 15, 4), pos = Vector3.new(0, 7.5, -65), color = Color3.fromRGB(25, 28, 38)},
	}
	for _, w in ipairs(subWalls) do
		local wall = Util.MakePart(w.name, w.size, w.pos, w.color, Enum.Material.Concrete, true)
		wall.Parent = mapFolder
	end

	-- Decorative pillars
	local pillarPositions = {
		Vector3.new(-95, 6, 25), Vector3.new(-95, 6, -25),
		Vector3.new(95, 6, 25), Vector3.new(95, 6, -25),
		Vector3.new(-60, 6, 70), Vector3.new(60, 6, -70),
	}
	for i, p in ipairs(pillarPositions) do
		local pillar = Util.MakePart("Pillar_" .. i, Vector3.new(3, 10, 3), p, Color3.fromRGB(30, 33, 42), Enum.Material.Concrete, true)
		pillar.Parent = mapFolder
	end

	-- Objectives
	local objectivesFolder = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Objectives")
	for _, child in ipairs(objectivesFolder:GetChildren()) do
		child:Destroy()
	end

	local function createObjective(name, pos, color)
		local model = Instance.new("Model")
		model.Name = name

		local core = Instance.new("Part")
		core.Name = "Core"
		core.Size = Vector3.new(8, 8, 8)
		core.Shape = Enum.PartType.Ball
		core.Material = Enum.Material.Neon
		core.Color = color
		core.Anchored = true
		core.Position = pos
		core.Parent = model

		-- Protective shield ring
		local shield = Instance.new("Part")
		shield.Name = "ObjectiveShield"
		shield.Size = Vector3.new(14, 0.3, 14)
		shield.Color = color
		shield.Material = Enum.Material.Neon
		shield.Transparency = 0.6
		shield.Anchored = true
		shield.CanCollide = false
		shield.Position = pos + Vector3.new(0, 4.5, 0)
		shield.Parent = model

		-- Beacon light
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 3
		light.Range = 30
		light.Parent = core

		model.PrimaryPart = core
		model.Parent = objectivesFolder
		return model
	end

	createObjective("RedCore", Config.MAP.RED_CORE, Config.RED_COLOR)
	createObjective("BlueCore", Config.MAP.BLUE_CORE, Config.BLUE_COLOR)

	for i, pos in ipairs(Config.MAP.RED_GENERATORS) do
		local gen = createObjective("RedGenerator" .. i, pos, Config.RED_COLOR)
		gen.PrimaryPart.Size = Vector3.new(6, 12, 6)
	end
	for i, pos in ipairs(Config.MAP.BLUE_GENERATORS) do
		local gen = createObjective("BlueGenerator" .. i, pos, Config.BLUE_COLOR)
		gen.PrimaryPart.Size = Vector3.new(6, 12, 6)
	end

	-- Waypoints
	local laneMain = {
		Vector3.new(-145, 2, 0), Vector3.new(-100, 2, 0), Vector3.new(-55, 2, 0),
		Vector3.new(0, 2, 0), Vector3.new(55, 2, 0), Vector3.new(100, 2, 0), Vector3.new(145, 2, 0),
	}
	local laneUpper = {
		Vector3.new(-145, 2, 65), Vector3.new(-95, 2, 65), Vector3.new(-45, 2, 65),
		Vector3.new(0, 2, 65), Vector3.new(45, 2, 65), Vector3.new(95, 2, 65), Vector3.new(145, 2, 65),
	}
	local laneLower = {
		Vector3.new(-145, 2, -65), Vector3.new(-95, 2, -65), Vector3.new(-45, 2, -65),
		Vector3.new(0, 2, -65), Vector3.new(45, 2, -65), Vector3.new(95, 2, -65), Vector3.new(145, 2, -65),
	}

	local laneMainFolder = Instance.new("Folder")
	laneMainFolder.Name = "Lane_Main"
	laneMainFolder.Parent = waypointFolder
	for i, pos in ipairs(laneMain) do
		makeWaypoint(laneMainFolder, "Lane_Main_" .. i, pos, "Lane_Main", i)
	end

	local laneUpperFolder = Instance.new("Folder")
	laneUpperFolder.Name = "Lane_Upper"
	laneUpperFolder.Parent = waypointFolder
	for i, pos in ipairs(laneUpper) do
		makeWaypoint(laneUpperFolder, "Lane_Upper_" .. i, pos, "Lane_Upper", i)
	end

	local laneLowerFolder = Instance.new("Folder")
	laneLowerFolder.Name = "Lane_Lower"
	laneLowerFolder.Parent = waypointFolder
	for i, pos in ipairs(laneLower) do
		makeWaypoint(laneLowerFolder, "Lane_Lower_" .. i, pos, "Lane_Lower", i)
	end

	-- KOTH zone marker (center)
	local kothBase = Util.MakePart("KOTH_Base", Vector3.new(24, 0.2, 24), Vector3.new(0, 0.1, 0), Color3.fromRGB(255, 215, 0), Enum.Material.Neon, true)
	kothBase.Transparency = 0.5
	kothBase.CanCollide = false
	kothBase.Parent = mapFolder

	local kothBeam = Util.MakePart("KOTH_Beam", Vector3.new(0.3, 80, 0.3), Vector3.new(0, 40, 0), Color3.fromRGB(255, 215, 0), Enum.Material.Neon, true)
	kothBeam.Transparency = 0.6
	kothBeam.CanCollide = false
	kothBeam.Parent = mapFolder

	-- Lighting
	Lighting.ClockTime = 20
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(55, 60, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(30, 35, 50)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.FogColor = Color3.fromRGB(15, 18, 25)
	Lighting.FogEnd = 400

	-- Post-processing atmosphere
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.15
	atmosphere.Offset = 0.5
	atmosphere.Color = Color3.fromRGB(40, 45, 60)
	atmosphere.Decay = Color3.fromRGB(20, 22, 30)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 0.5
	atmosphere.Parent = Lighting
end

local function createFlag(name, position, color)
	local flag = Instance.new("Model")
	flag.Name = name

	local pole = Instance.new("Part")
	pole.Name = "Pole"
	pole.Size = Vector3.new(0.4, 10, 0.4)
	pole.Color = Color3.fromRGB(200, 200, 200)
	pole.Material = Enum.Material.Metal
	pole.Anchored = true
	pole.CanCollide = false
	pole.Position = position
	pole.Parent = flag

	local flagPart = Instance.new("Part")
	flagPart.Name = "Flag"
	flagPart.Size = Vector3.new(0.1, 5, 3)
	flagPart.Color = color
	flagPart.Material = Enum.Material.Neon
	flagPart.Anchored = true
	flagPart.CanCollide = false
	flagPart.Position = position + Vector3.new(0, 7, 0)
	flagPart.Parent = flag

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2
	light.Range = 20
	light.Parent = flagPart

	flag.PrimaryPart = pole
	flag:SetAttribute("FlagTeam", (color == Config.RED_COLOR and Config.TEAM_RED) or Config.TEAM_BLUE)
	return flag
end

function MapBuilder.SetupGameMode(mode)
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	if not world then return end
	local effectsFolder = world:FindFirstChild("Effects")

	if mode == "KOTH" then
		-- KOTH: enable beacon zone visuals
		local beacon = getWorldFolder("Map"):FindFirstChild("KOTH_Beacon")
		if beacon then beacon.Transparency = 0.4 end
	elseif mode == "Bomb" then
		MapBuilder.SetupBombSites()
	elseif mode == "CTF" then
		-- Create CTF flags
		local flagRed = createFlag("RedFlag", Config.MAP.CtfFlagRed, Config.RED_COLOR)
		local flagBlue = createFlag("BlueFlag", Config.MAP.CtfFlagBlue, Config.BLUE_COLOR)
		if effectsFolder then
			flagRed.Parent = effectsFolder
			flagBlue.Parent = effectsFolder
		end
		-- Register as objectives
		if not CombatSystem.Objectives["RedFlag"] then
			CombatSystem.Objectives["RedFlag"] = {
				TeamId = Config.TEAM_RED, Name = "RedFlag", Health = 1,
				Model = flagRed, MaxHealth = 1,
			}
		end
		if not CombatSystem.Objectives["BlueFlag"] then
			CombatSystem.Objectives["BlueFlag"] = {
				TeamId = Config.TEAM_BLUE, Name = "BlueFlag", Health = 1,
				Model = flagBlue, MaxHealth = 1,
			}
		end
	elseif mode == "FFA" then
		-- FFA: remove team-specific objectives from tracking
		-- (cores remain but no team scoring)
	end

	-- Spawn power pickups in all modes
	MapBuilder.AddPowerPickups()
end

function MapBuilder.SetupBombSites()
	local mapFolder = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Map")
	if not mapFolder then return end

	for siteName, sitePos in pairs(Config.BOMB_SITES) do
		-- Glowing site zone
		local zone = Instance.new("Part")
		zone.Name = "BombSite_" .. siteName
		zone.Size = Vector3.new(12, 0.2, 12)
		zone.Position = sitePos
		zone.Color = Color3.fromRGB(255, 100, 50)
		zone.Material = Enum.Material.Neon
		zone.Transparency = 0.6
		zone.Anchored = true
		zone.CanCollide = false
		zone.Parent = mapFolder

		-- Corner markers
		for _, offset in ipairs({{-5, 0, -5}, {-5, 0, 5}, {5, 0, -5}, {5, 0, 5}}) do
			local marker = Instance.new("Part")
			marker.Name = "BombSiteMarker_" .. siteName
			marker.Size = Vector3.new(0.5, 0.5, 0.5)
			marker.Position = sitePos + offset
			marker.Color = Color3.fromRGB(255, 200, 50)
			marker.Material = Enum.Material.Neon
			marker.Transparency = 0.3
			marker.Anchored = true
			marker.CanCollide = false
			marker.Parent = mapFolder
		end

		-- Site label
		local label = Instance.new("BillboardGui")
		label.Name = "SiteLabel_" .. siteName
		label.Size = UDim2.new(0, 40, 0, 24)
		label.StudsOffset = Vector3.new(0, 8, 0)
		label.AlwaysOnTop = true
		label.Adornee = zone
		label.Parent = zone

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = siteName
		text.TextColor3 = Color3.fromRGB(255, 200, 50)
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.Parent = label
	end

	-- CT spawn
	local ctPos = Config.BOMB_SPAWN_CT[1]
	if ctPos then
		local ctZone = Instance.new("Part")
		ctZone.Name = "CTSpawn"
		ctZone.Size = Vector3.new(20, 0.2, 10)
		ctZone.Position = ctPos
		ctZone.Color = Color3.fromRGB(50, 150, 255)
		ctZone.Material = Enum.Material.Neon
		ctZone.Transparency = 0.7
		ctZone.Anchored = true
		ctZone.CanCollide = false
		ctZone.Parent = mapFolder
	end

	-- T spawn
	local tPos = Config.BOMB_SPAWN_T[1]
	if tPos then
		local tZone = Instance.new("Part")
		tZone.Name = "TSpawn"
		tZone.Size = Vector3.new(20, 0.2, 10)
		tZone.Position = tPos
		tZone.Color = Color3.fromRGB(255, 100, 50)
		tZone.Material = Enum.Material.Neon
		tZone.Transparency = 0.7
		tZone.Anchored = true
		tZone.CanCollide = false
		tZone.Parent = mapFolder
	end
end

-- Add armor stations to the map
function MapBuilder.AddArmorStations()
	local mapFolder = getWorldFolder("Map")
	local stationPositions = Config.MAP.ARMOR_STATIONS or {}
	for i, pos in ipairs(stationPositions) do
		local station = Util.MakePart("ArmorStation_" .. i, Vector3.new(6, 1, 6), pos, Color3.fromRGB(200, 200, 100), Enum.Material.SmoothPlastic, true)
		station.Parent = mapFolder
		-- Glow
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(200, 200, 100)
		glow.Brightness = 2
		glow.Range = 15
		glow.Parent = station
		-- Collect handler
		station.Touched:Connect(function(hit)
			local hero = HeroSystem and HeroSystem.GetHeroFromPart(hit)
			if hero and hero.Alive and hero.Armor ~= nil and hero.Armor < hero.MaxArmor then
				hero.Armor = math.min(hero.MaxArmor, hero.Armor + Config.ARMOR_PICKUP_AMOUNT)
				station.Transparency = 0.5
				fireEffect({effectType = "ArmorPickup", position = pos, heroGuid = hero.Guid})
				task.delay(10, function()
					if station and station.Parent then
						station.Transparency = 0
					end
				end)
			end
		end)
	end
end

-- Spawn power pickups around the map
function MapBuilder.AddPowerPickups()
	local mapFolder = getWorldFolder("Map")
	local pickupsFolder = getWorldFolder("Pickups")
	local powerPositions = Config.MAP.POWERUP_SPAWNS or {}

	-- Power types: SpeedBoost, DamageBoost, Shield, Health
	local powerTypes = {"SpeedBoost", "DamageBoost", "Shield", "Health"}

	for i, pos in ipairs(powerPositions) do
		local powerType = powerTypes[(i - 1) % #powerTypes + 1]
		local colorMap = {
			SpeedBoost = Color3.fromRGB(255, 200, 50),
			DamageBoost = Color3.fromRGB(255, 50, 50),
			Shield = Color3.fromRGB(50, 150, 255),
			Health = Color3.fromRGB(50, 255, 100),
		}

		local pickup = Instance.new("Part")
		pickup.Name = "PowerPickup_" .. powerType .. "_" .. i
		pickup.Shape = Enum.PartType.Ball
		pickup.Size = Vector3.new(2, 2, 2)
		pickup.Color = colorMap[powerType] or Color3.fromRGB(200, 200, 200)
		pickup.Material = Enum.Material.Neon
		pickup.Transparency = 0.3
		pickup.Anchored = true
		pickup.CanCollide = false
		pickup.Position = pos + Vector3.new(0, 1.5, 0)
		pickup.Parent = pickupsFolder

		-- Glow
		local glow = Instance.new("PointLight")
		glow.Color = pickup.Color
		glow.Brightness = 2
		glow.Range = 12
		glow.Parent = pickup

		-- Collect on touch
		local debounce = false
		pickup.Touched:Connect(function(hit)
			if debounce then return end
			if not pickup or not pickup.Parent then return end

			local hero = HeroSystem and HeroSystem.GetHeroFromPart(hit)
			if not hero or not hero.Alive then return end

			debounce = true
			pickup:Destroy()

			-- Apply power effect
			local powerKey = "power_" .. powerType:lower()
			hero.ActiveEffects = hero.ActiveEffects or {}
			hero.ActiveEffects[powerKey] = {
				ExpireAt = os.clock() + 10,
				LastTick = os.clock(),
				PowerType = powerType,
			}

			if powerType == "SpeedBoost" then
				local heroDef = HeroConfig[hero.HeroId]
				if heroDef then
					hero.Humanoid.WalkSpeed = heroDef.walkSpeed * 1.5
				end
			elseif powerType == "Shield" then
				hero.MaxShield = (hero.MaxShield or 0) + 75
				hero.ShieldHealth = (hero.ShieldHealth or 0) + 75
			elseif powerType == "Health" then
				hero.Health = math.min(hero.MaxHealth, hero.Health + 50)
				hero.Humanoid.Health = hero.Health
			end

			fireEffect({
				effectType = "PowerPickup",
				position = pos,
				powerType = powerType,
				heroGuid = hero.Guid,
			})

			task.delay(1, function() debounce = false end)
		end)
	end
end

return MapBuilder