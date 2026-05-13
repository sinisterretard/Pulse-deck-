--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))
local Util = require(sharedRoot:WaitForChild("Util"))

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))
local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
local AISystem = require(script.Parent:WaitForChild("AISystem"))
local AbilitySystem = require(script.Parent:WaitForChild("AbilitySystem"))
local ProgressionSystem = require(script.Parent:WaitForChild("ProgressionSystem"))

local function ensureWorld()
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	if not world then
		world = Instance.new("Folder")
		world.Name = "PulseDeckArenaWorld"
		world.Parent = workspace
	end
	for _, name in ipairs({"Map", "Heroes", "Objectives", "Pickups", "Projectiles", "Effects", "Waypoints", "Debris"}) do
		if not world:FindFirstChild(name) then
			local f = Instance.new("Folder")
			f.Name = name
			f.Parent = world
		end
	end
end

ensureWorld()

-- Create remote folder
local remotesFolder = ReplicatedStorage:FindFirstChild("PulseDeckArena") and ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	local root = ReplicatedStorage:FindFirstChild("PulseDeckArena")
	if not root then
		root = Instance.new("Folder")
		root.Name = "PulseDeckArena"
		root.Parent = ReplicatedStorage
	end
	remotesFolder.Parent = root
end

local function ensureRemote(name, className)
	local r = remotesFolder:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = remotesFolder
	end
	return r
end

local requestJoin = ensureRemote("RequestJoinQueue", "RemoteEvent")
local requestDeck = ensureRemote("RequestDeckUpdate", "RemoteEvent")
local requestSwitch = ensureRemote("RequestSwitchHero", "RemoteEvent")
local requestStart = ensureRemote("RequestStartMatch", "RemoteEvent")
local requestFire = ensureRemote("RequestFire", "RemoteEvent")
local requestReload = ensureRemote("RequestReload", "RemoteEvent")
local requestAbility = ensureRemote("RequestAbility", "RemoteEvent")
local requestUltimate = ensureRemote("RequestUltimate", "RemoteEvent")
local requestCamera = ensureRemote("RequestCameraMode", "RemoteEvent")
local requestScoreboard = ensureRemote("RequestScoreboard", "RemoteEvent")
local clientReady = ensureRemote("ClientReady", "RemoteEvent")
local matchStateChanged = ensureRemote("MatchStateChanged", "RemoteEvent")
local heroControlChanged = ensureRemote("HeroControlChanged", "RemoteEvent")
local heroStateSnapshot = ensureRemote("HeroStateSnapshot", "RemoteEvent")
local objectiveStateChanged = ensureRemote("ObjectiveStateChanged", "RemoteEvent")
local scoreChanged = ensureRemote("ScoreChanged", "RemoteEvent")
local killfeedEvent = ensureRemote("KillfeedEvent", "RemoteEvent")
local damageNumberEvent = ensureRemote("DamageNumberEvent", "RemoteEvent")
local effectsEvent = ensureRemote("EffectsEvent", "RemoteEvent")
local announcementEvent = ensureRemote("AnnouncementEvent", "RemoteEvent")
local getInitialState = ensureRemote("GetInitialState", "RemoteFunction")
local armorPickupEvent = ensureRemote("ArmorPickup", "RemoteEvent")
local playSFX = ensureRemote("PlaySFX", "RemoteEvent")
local requestPower = ensureRemote("RequestPower", "RemoteEvent")
local requestBuy = ensureRemote("RequestBuy", "RemoteEvent")
local requestBuyMenu = ensureRemote("RequestBuyMenu", "RemoteEvent")
local requestReady = ensureRemote("RequestReady", "RemoteEvent")
local requestPurchase = ensureRemote("RequestPurchase", "RemoteEvent")
local requestPracticeDummy = ensureRemote("RequestPracticeDummy", "RemoteEvent")
local requestPlant = ensureRemote("RequestPlant", "RemoteEvent")
local requestDefuse = ensureRemote("RequestDefuse", "RemoteEvent")
local cancelDefuse = ensureRemote("CancelDefuse", "RemoteEvent")
local bombDefuseProgress = ensureRemote("BombDefuseProgress", "RemoteEvent")

-- Forward SFX to all clients
playSFX.OnServerEvent:Connect(function(player, payload)
	if payload and payload.soundName then
		playSFX:FireAllClients(payload)
	end
end)

MatchSystem.ReadyState = {}

-- Request handlers
requestJoin.OnServerEvent:Connect(function(player)
	MatchSystem.RequestJoin(player)
end)

requestDeck.OnServerEvent:Connect(function(player, payload)
	if MatchSystem.State ~= "DeckSelect" then return end
	if type(payload) ~= "table" or type(payload.heroIds) ~= "table" then return end
	-- Validate hero IDs
	local validIds = {}
	for _, id in ipairs(payload.heroIds) do
		if HeroConfig[id] then
			table.insert(validIds, id)
		end
	end
	if #validIds == 5 then
		MatchSystem.Decks[player.UserId] = validIds
	end
end)

requestSwitch.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" or type(payload.slot) ~= "number" then return end
	HeroSystem.SwitchHero(player, payload.slot)
end)

requestStart.OnServerEvent:Connect(function(_player)
	if MatchSystem.State == "DeckSelect" then
		MatchSystem.BeginMatch()
	end
end)

requestFire.OnServerEvent:Connect(function(player, payload)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	if type(payload) ~= "table" then return end
	if typeof(payload.direction) ~= "Vector3" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	if hero.Stunned then return end
	if typeof(payload.origin) == "Vector3" and (payload.origin - hero.Root.Position).Magnitude > 35 then return end

	-- Rapid fire check
	local weapon = WeaponConfig[hero.WeaponId]
	if weapon then
		local minInterval = weapon.fireInterval or 0.1
		if os.clock() - hero.LastFireAt < minInterval * 0.8 then return end
		hero.LastFireAt = os.clock()
	end

	CombatSystem.FireWeapon(hero, payload.direction)
end)

requestReload.OnServerEvent:Connect(function(player)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	CombatSystem.RequestReload(hero)
end)

requestAbility.OnServerEvent:Connect(function(player, payload)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	if MatchSystem.State == "SuddenDeath" then
		local hero = HeroSystem.GetControlledHero(player)
		if hero and hero.UltimateId then
			AbilitySystem.UseUltimate(hero)
			return
		end
	end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	AbilitySystem.UseAbility(hero, payload or {})
end)

requestUltimate.OnServerEvent:Connect(function(player)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	if not hero.UltimateId then return end
	AbilitySystem.UseUltimate(hero)
end)

-- Hero power activation
requestPower.OnServerEvent:Connect(function(player, payload)
	if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	local heroDef = HeroConfig[hero.HeroId]
	if not heroDef or not heroDef.powers then return end
	local powerId = payload and payload.powerId
	if not powerId or not heroDef.powers[powerId] then return end
	local powerDef = heroDef.powers[powerId]
	hero.ActiveEffects = hero.ActiveEffects or {}
	local powerKey = "power_" .. powerId

	if powerId == "teamHeal" then
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId == hero.TeamId and (h.Root.Position - hero.Root.Position).Magnitude <= (powerDef.radius or 20) then
				h.Health = math.min(h.MaxHealth, h.Health + (powerDef.amount or 30))
				h.Humanoid.Health = h.Health
			end
		end
		effectsEvent:FireAllClients({effectType = "HealRing", position = hero.Root.Position, radius = powerDef.radius or 20, duration = 0.7, color = Color3.fromRGB(92, 255, 180)})
		return
	end

	if powerId == "energyDrain" then
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local d = (h.Root.Position - hero.Root.Position).Magnitude
				if d <= (powerDef.radius or 12) then
					CombatSystem.ApplyDamage(hero, h, powerDef.dps or 10, "ability")
				end
			end
		end
		effectsEvent:FireAllClients({effectType = "EnergyDrain", position = hero.Root.Position, radius = powerDef.radius or 12, duration = powerDef.duration or 4, color = Color3.fromRGB(100, 200, 255)})
		return
	end

	if powerId == "groundSlam" then
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local d = (h.Root.Position - hero.Root.Position).Magnitude
				if d <= (powerDef.radius or 14) then
					CombatSystem.ApplyDamage(hero, h, 30, "ability")
					h.Stunned = true
					task.delay(powerDef.stunDuration or 2, function() if h then h.Stunned = false end end)
				end
			end
		end
		effectsEvent:FireAllClients({effectType = "GroundSlam", position = hero.Root.Position, radius = powerDef.radius or 14, duration = 1})
		return
	end

	if powerId == "blastWave" then
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local d = (h.Root.Position - hero.Root.Position).Magnitude
				if d <= (powerDef.radius or 15) and h.Root then
					local knockDir = (h.Root.Position - hero.Root.Position).Unit
					h.Root.Velocity = knockDir * (powerDef.force or 70) + Vector3.new(0, 20, 0)
				end
			end
		end
		effectsEvent:FireAllClients({effectType = "Explosion", position = hero.Root.Position, radius = powerDef.radius or 15, duration = 0.5})
		return
	end

	hero.ActiveEffects[powerKey] = {
		ExpireAt = os.clock() + (powerDef.duration or 5),
		LastTick = os.clock(),
		PowerDef = powerDef,
	}
	effectsEvent:FireAllClients({effectType = "PowerActivated", heroGuid = hero.Guid, powerId = powerId, duration = powerDef.duration or 5})
end)

-- Bomb plant remote
requestPlant.OnServerEvent:Connect(function(player, payload)
	if MatchSystem.GameMode ~= "Bomb" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	if not hero.HasBomb then return end
	local sitePos = payload and payload.sitePosition
	if not sitePos then return end
	MatchSystem.PlantBomb(hero, sitePos)
end)

-- Bomb defuse remote
requestDefuse.OnServerEvent:Connect(function(player)
	if MatchSystem.GameMode ~= "Bomb" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	MatchSystem.StartDefuse(hero)
end)

-- Cancel defuse remote
cancelDefuse.OnServerEvent:Connect(function(player)
	if MatchSystem.GameMode ~= "Bomb" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	MatchSystem.CancelDefuse(hero)
end)

-- Buy menu remote
requestBuyMenu.OnServerEvent:Connect(function(player)
	if MatchSystem.GameMode ~= "Bomb" then return end
	if MatchSystem.RoundPhase ~= "Buy" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	requestBuyMenu:FireClient(player, {
		money = hero.Money or 0,
		weaponId = hero.WeaponId,
	})
end)

-- Buy weapon remote
requestBuy.OnServerEvent:Connect(function(player, payload)
	if MatchSystem.GameMode ~= "Bomb" then return end
	if MatchSystem.RoundPhase ~= "Buy" then return end
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	local weaponId = payload and payload.weaponId
	if not weaponId then return end
	local price = Config.WEAPON_PRICES[weaponId]
	if not price then return end
	if (hero.Money or 0) < price then return end
	local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))
	if not WeaponConfig[weaponId] then return end
	hero.Money = hero.Money - price
	hero.WeaponId = weaponId
	hero.Ammo = (WeaponConfig[weaponId].magazineSize or 30)
	hero.ReserveAmmo = (WeaponConfig[weaponId].reserveAmmo or (WeaponConfig[weaponId].magazineSize or 30) * 3)
	hero.SpentThisRound = (hero.SpentThisRound or 0) + price
	requestBuyMenu:FireClient(player, {
		money = hero.Money,
		weaponId = hero.WeaponId,
		bought = weaponId,
	})
end)

-- Ready-up handler
requestReady.OnServerEvent:Connect(function(player)
	if MatchSystem.State ~= "DeckSelect" and MatchSystem.State ~= "Lobby" then return end
	MatchSystem.ReadyState[player.UserId] = not (MatchSystem.ReadyState[player.UserId] or false)
	local readyText = MatchSystem.ReadyState[player.UserId] and "ready" or "not ready"
	announcementEvent:FireAllClients({text = player.Name .. " is " .. readyText, duration = 3})

	-- Check if all human players are ready
	local allReady = true
	for _, plr in ipairs(Players:GetPlayers()) do
		if not MatchSystem.ReadyState[plr.UserId] then
			allReady = false
			break
		end
	end
	if allReady and #Players:GetPlayers() >= 1 then
		MatchSystem.Timer = math.min(MatchSystem.Timer or 15, 5)
		announcementEvent:FireAllClients({text = "All ready! Match starting soon...", duration = 3})
	end
end)

requestPurchase.OnServerEvent:Connect(function(player, payload)
	if not payload or not payload.itemId then return end
	local ok, msg = ProgressionSystem.PurchaseShopItem(player, payload.itemId)
	if ok then
		requestPurchase:FireClient(player, {success = true, itemId = payload.itemId})
	else
		requestPurchase:FireClient(player, {success = false, error = msg})
	end
end)

requestPracticeDummy.OnServerEvent:Connect(function(player)
	local hero = HeroSystem.GetControlledHero(player)
	if not hero then return end
	local dummy = Instance.new("Part")
	dummy.Name = "PracticeDummy"
	dummy.Size = Vector3.new(2, 4, 1)
	dummy.Position = hero.Root.Position + hero.Root.CFrame.LookVector * 10
	dummy.Color = Color3.fromRGB(255, 100, 100)
	dummy.Material = Enum.Material.SmoothPlastic
	dummy.Anchored = true
	dummy.CanCollide = true
	dummy.Parent = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Effects")
	task.delay(30, function() if dummy and dummy.Parent then dummy:Destroy() end end)
end)

requestCamera.OnServerEvent:Connect(function(_player, _payload)
	-- Camera is client-owned.
end)

local requestGameMode = ensureRemote("RequestGameMode", "RemoteEvent")
requestGameMode.OnServerEvent:Connect(function(player, payload)
	if MatchSystem.State == "Lobby" or MatchSystem.State == "DeckSelect" then
		if payload and payload.mode then
			MatchSystem.GameMode = payload.mode
			announcementEvent:FireAllClients({text = "Game mode: " .. payload.mode, duration = 3})
		end
	end
end)

requestScoreboard.OnServerEvent:Connect(function(player)
	local rows = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local teamId = MatchSystem.GetTeam(plr.UserId) or "None"
		local hero = HeroSystem.GetControlledHero(plr)
		local kills = 0
		local deaths = 0
		local damage = 0
		if hero then
			kills = hero.KillCount or 0
			deaths = hero.DeathCount or 0
			damage = hero.DamageDealt or 0
		end
		table.insert(rows, {
			name = plr.Name,
			teamId = teamId,
			score = MatchSystem.Score[teamId] or 0,
			kills = kills,
			deaths = deaths,
			damage = damage,
			kd = kills / math.max(1, deaths),
		})
	end
	requestScoreboard:FireClient(player, { players = rows })
end)

clientReady.OnServerEvent:Connect(function(player)
	local prof = ProgressionSystem.Profiles[player.UserId]
	local progression = prof or {Wins = 0, Coins = 0, XP = 0}

	matchStateChanged:FireClient(player, {
		state = MatchSystem.State,
		timerRemaining = MatchSystem.Timer,
		redScore = MatchSystem.Score.Red,
		blueScore = MatchSystem.Score.Blue,
		teamId = MatchSystem.GetTeam(player.UserId),
		gameMode = MatchSystem.GameMode,
		roundNumber = MatchSystem.RoundNumber,
		roundPhase = MatchSystem.RoundPhase,
		bombState = MatchSystem.BombState,
		bombTimer = MatchSystem.BombTimer,
		roundScore = MatchSystem.RoundScore,
		hasBomb = false,
	})

	requestScoreboard:FireClient(player, {
		players = {},
		matchMode = MatchSystem.GameMode,
	})
end)

getInitialState.OnServerInvoke = function(player)
	local profile = ProgressionSystem.Profiles[player.UserId]
	return {
		gameName = Config.GAME_NAME,
		matchState = MatchSystem.State,
		timerRemaining = MatchSystem.Timer,
		teamId = MatchSystem.GetTeam(player.UserId),
		selectedDeck = MatchSystem.Decks[player.UserId] or Config.DEFAULT_DECK,
		score = MatchSystem.Score,
		progression = profile or {Wins = 0, Coins = 0, XP = 0},
		gameMode = MatchSystem.GameMode,
		money = 800,
		roundNumber = MatchSystem.RoundNumber,
		roundScore = MatchSystem.RoundScore,
		roundPhase = MatchSystem.RoundPhase,
		bombState = MatchSystem.BombState,
		bombTimer = MatchSystem.BombTimer,
		hasBomb = false,
	}
end

Players.PlayerAdded:Connect(function(player)
	MatchSystem.AssignTeam(player)
	ProgressionSystem.CreateLeaderstats(player)
	ProgressionSystem.Load(player)

	MatchSystem.Killstreaks[player.UserId] = 0
	MatchSystem.FFAKills[player.UserId] = 0
	MatchSystem.ReadyState[player.UserId] = false

	player.Chatted:Connect(function(message)
		local isAdmin = RunService:IsStudio() or table.find(Config.ADMIN_USER_IDS, player.UserId) ~= nil
		if not isAdmin then return end

		local args = string.split(message:lower(), " ")
		if args[1] == "/pda_reset" then
			MatchSystem.Reset()
		elseif args[1] == "/pda_start" then
			if MatchSystem.State == "Lobby" then
				MatchSystem.RequestJoin(player)
			end
			if MatchSystem.State == "DeckSelect" then
				MatchSystem.BeginMatch()
			end
		elseif args[1] == "/pda_bots" then
			MatchSystem.EnsureBotOpponent()
		elseif args[1] == "/pda_winred" then
			MatchSystem.EndMatch(Config.TEAM_RED)
		elseif args[1] == "/pda_winblue" then
			MatchSystem.EndMatch(Config.TEAM_BLUE)
		elseif args[1] == "/pda_mode" then
			if args[2] == "ffa" then
				MatchSystem.GameMode = "FFA"
			elseif args[2] == "koth" then
				MatchSystem.GameMode = "KOTH"
			elseif args[2] == "ctf" then
				MatchSystem.GameMode = "CTF"
			elseif args[2] == "bomb" then
				MatchSystem.GameMode = "Bomb"
			elseif args[2] == "standard" then
				MatchSystem.GameMode = "Standard"
			end
			announcementEvent:FireAllClients({text = "Game mode changed to " .. tostring(MatchSystem.GameMode), duration = 5})
		elseif args[1] == "/pda_givexp" then
			local prof = ProgressionSystem.Profiles[player.UserId]
			if prof then
				prof.XP = (prof.XP or 0) + 1000
				ProgressionSystem.SyncLeaderstats(player)
			end
		elseif args[1] == "/pda_givecoins" then
			local prof = ProgressionSystem.Profiles[player.UserId]
			if prof then
				prof.Coins = (prof.Coins or 0) + 1000
				ProgressionSystem.SyncLeaderstats(player)
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	ProgressionSystem.Save(player)
	HeroSystem.RemoveOwner(player.UserId)
	MatchSystem.Killstreaks[player.UserId] = nil
	MatchSystem.FFAKills[player.UserId] = nil
end)

MatchSystem.OnEnded(function(winnerTeam)
	for _, player in ipairs(Players:GetPlayers()) do
		local teamId = MatchSystem.GetTeam(player.UserId)
		local result = "Draw"
		if teamId == winnerTeam then
			result = "Win"
		elseif teamId ~= nil and winnerTeam ~= Config.TEAM_NONE then
			result = "Loss"
		end

		local hero = HeroSystem.GetControlledHero(player)
		local extraXP = 0
		if hero then
			extraXP = (hero.KillCount or 0) * 15 + math.floor((hero.DamageDealt or 0) / 10)
		end

		local profile = ProgressionSystem.Profiles[player.UserId]
		if profile then
			profile.XP = (profile.XP or 0) + extraXP
			ProgressionSystem.SyncLeaderstats(player)
		end

		ProgressionSystem.AwardMatch(player, result, MatchSystem.Score or 0)
		ProgressionSystem.Save(player)
	end

	local winText = "DRAW"
	if winnerTeam == Config.TEAM_RED then
		winText = "RED TEAM WINS!"
	elseif winnerTeam == Config.TEAM_BLUE then
		winText = "BLUE TEAM WINS!"
	end
	announcementEvent:FireAllClients({text = winText, duration = 7})
end)

-- Helper: process burn effects on a hero
local function processBurn(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.burn then return end
	local newBurns = {}
	for _, burn in ipairs(hero.ActiveEffects.burn) do
		if now >= burn.ExpireAt then
			-- Burn expired
		else
			if now - burn.LastTick >= BURN_TICK_INTERVAL then
				burn.LastTick = now
				CombatSystem.ApplyDamage(hero, hero, burn.DamagePerTick, "burn")
			end
			table.insert(newBurns, burn)
		end
	end
	if #newBurns == 0 then
		hero.ActiveEffects.burn = nil
	else
		hero.ActiveEffects.burn = newBurns
	end
end

-- Helper: process freeze effects on a hero
local function processFreeze(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.frozen then return end
	local freeze = hero.ActiveEffects.frozen
	if now >= freeze.ExpireAt then
		hero.ActiveEffects.frozen = nil
		local heroDef = HeroConfig[hero.HeroId]
		if heroDef then hero.Humanoid.WalkSpeed = heroDef.walkSpeed end
	else
		local heroDef = HeroConfig[hero.HeroId]
		if heroDef then
			hero.Humanoid.WalkSpeed = heroDef.walkSpeed * freeze.SlowMultiplier
		end
	end
end

-- Helper: process supernova channel
local function processSupernova(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.supernovaChannel then return end
	local channel = hero.ActiveEffects.supernovaChannel
	if now >= channel.ExpireAt then
		-- Detonate
		hero.ActiveEffects.supernovaChannel = nil
		CombatSystem.DamageRadius(hero, hero.Root.Position, channel.Radius, channel.Damage, 1.5)
		effectsEvent:FireAllClients({
			effectType = "SupernovaExplosion",
			position = hero.Root.Position,
			radius = channel.Radius,
			duration = 1,
			color = Color3.fromRGB(255, 200, 50),
		})
		-- Knockback nearby enemies
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local dist = (h.Root.Position - hero.Root.Position).Magnitude
				if dist <= channel.Radius and h.Root then
					h.Root.Velocity = Vector3.new(0, 40, 0) + (h.Root.Position - hero.Root.Position).Unit * channel.KnockbackForce
				end
			end
		end
	elseif now % 0.5 < 0.05 then
		-- Pulse visual during channel
		effectsEvent:FireAllClients({
			effectType = "SupernovaPulse",
			position = hero.Root.Position,
			radius = channel.Radius * (1 + (now % 1)),
			color = Color3.fromRGB(255, 200, 50),
		})
	end
end

-- Helper: process tether effects
local function processTether(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.tether then return end
	local tether = hero.ActiveEffects.tether
	if now >= tether.ExpireAt then
		hero.ActiveEffects.tether = nil
		return
	end
	-- Find target
	local target = HeroSystem.HeroesByGuid[tether.TargetGuid]
	if not target or not target.Alive then
		hero.ActiveEffects.tether = nil
		return
	end
	-- Heal self and target
	AbilitySystem.Heal(hero, tether.HealthShareRate * 0.25)
	if target.Alive then
		AbilitySystem.Heal(target, tether.HealthShareRate * 0.25)
	end
end

-- Helper: process tethered-by effects
local function processTetheredBy(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.tetheredBy then return end
	local tetherOwner = HeroSystem.HeroesByGuid[hero.ActiveEffects.tetheredBy]
	if not tetherOwner or not tetherOwner.ActiveEffects or not tetherOwner.ActiveEffects.tether then
		hero.ActiveEffects.tetheredBy = nil
		return
	end
	-- Receive heal passively
	AbilitySystem.Heal(hero, 5 * 0.25)
end

-- Helper: process berserk effect
local function processBerserk(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.berserk then return end
	local berserk = hero.ActiveEffects.berserk
	if now >= berserk.ExpireAt then
		hero.ActiveEffects.berserk = nil
		-- Reset walk speed
		local heroDef = HeroConfig[hero.HeroId]
		if heroDef then
			hero.Humanoid.WalkSpeed = heroDef.walkSpeed
		end
	end
end

-- Helper: process phoenix dive impact
local function processPhoenixDive(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.phoenixDiving then return end
	-- Check if hero has landed (close to ground)
	if hero.Root.Position.Y < 5 then
		hero.ActiveEffects.phoenixDiving = nil
		-- Deal damage on impact
		CombatSystem.DamageRadius(hero, hero.Root.Position, 15, 120, 1.0)
		effectsEvent:FireAllClients({
			effectType = "PhoenixDiveImpact",
			position = hero.Root.Position,
			radius = 15,
			duration = 0.5,
			color = Color3.fromRGB(255, 100, 0),
		})
		-- Self-heal
		local healAmt = math.min(hero.MaxHealth - hero.Health, 100)
		if healAmt > 0 then
			AbilitySystem.Heal(hero, healAmt)
		end
	end
end

-- Helper: process smoke screen
local function processSmokeScreen(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.smokeScreen then return end
	local smoke = hero.ActiveEffects.smokeScreen
	if now >= smoke.ExpireAt then
		hero.ActiveEffects.smokeScreen = nil
		-- Reset walk speed
		local heroDef = HeroConfig[hero.HeroId]
		if heroDef then
			hero.Humanoid.WalkSpeed = heroDef.walkSpeed
		end
	end
end

-- Helper: process radar pulse
local function processRadarPulse(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.radarPulse then return end
	if now >= hero.ActiveEffects.radarPulse.ExpireAt then
		hero.ActiveEffects.radarPulse = nil
	end
end

-- Helper: process tactical overlay
local function processTacticalOverlay(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.tacticalOverlay then return end
	if now >= hero.ActiveEffects.tacticalOverlay.ExpireAt then
		hero.ActiveEffects.tacticalOverlay = nil
	end
end

-- Helper: process cloak and dagger
local function processCloakAndDagger(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.cloakAndDagger then return end
	local cd = hero.ActiveEffects.cloakAndDagger
	if now >= cd.ExpireAt then
		hero.ActiveEffects.cloakAndDagger = nil
		hero.IsStealthed = false
		-- Reset walk speed
		local heroDef = HeroConfig[hero.HeroId]
		if heroDef then
			hero.Humanoid.WalkSpeed = heroDef.walkSpeed
		end
	else
		-- Apply speed boost
		local heroDef = HeroConfig[hero.HeroId]
		if heroDef then
			hero.Humanoid.WalkSpeed = heroDef.walkSpeed * (cd.MoveSpeedMultiplier or 1.0)
		end
	end
end

-- Helper: process EMP disabled
local function processEMP(hero, now)
	if not hero.ActiveEffects or not hero.ActiveEffects.empDisabled then return end
	if now >= hero.ActiveEffects.empDisabled.ExpireAt then
		hero.ActiveEffects.empDisabled = nil
	end
end

-- Update XP and ultimate charge every frame
task.spawn(function()
	while true do
		task.wait(0.25)

		if MatchSystem.State == "ActiveMatch" or MatchSystem.State == "SuddenDeath" then
			for _, hero in pairs(HeroSystem.HeroesByGuid) do
				-- Overcharge effect
				if hero.ActiveEffects and hero.ActiveEffects.overcharge then
					local oc = hero.ActiveEffects.overcharge
					if os.clock() >= oc.ExpireAt then
						hero.ActiveEffects.overcharge = nil
						local heroDef = HeroConfig[hero.HeroId]
						if heroDef then
							hero.Humanoid.WalkSpeed = heroDef.walkSpeed
						end
					else
						-- Apply speed boost
						local heroDef = HeroConfig[hero.HeroId]
						if heroDef then
							hero.Humanoid.WalkSpeed = heroDef.walkSpeed * oc.SpeedMultiplier
						end
					end
				end

				-- Fortify effect
				if hero.ActiveEffects and hero.ActiveEffects.fortify then
					if os.clock() >= hero.ActiveEffects.fortify.ExpireAt then
						hero.ActiveEffects.fortify = nil
					end
				end

				-- Heal over time
				if hero.ActiveEffects and hero.ActiveEffects.healOverTime then
					local hot = hero.ActiveEffects.healOverTime
					if os.clock() >= hot.ExpireAt then
						hero.ActiveEffects.healOverTime = nil
					elseif os.clock() - hot.LastTick >= 1 then
						hot.LastTick = os.clock()
						AbilitySystem.Heal(hero, hot.HealPerTick)
					end
				end

				-- Marked by Vesper Scope
				if hero.ActiveEffects and hero.ActiveEffects.markedByVesper then
					if os.clock() >= hero.MarkedUntil then
						hero.ActiveEffects.markedByVesper = nil
					end
				end

				-- Ultimate channel (legacy)
				if hero.ActiveEffects and hero.ActiveEffects.ultimate then
					local ult = hero.ActiveEffects.ultimate
					if os.clock() >= ult.ExpireAt then
						hero.ActiveEffects.ultimate = nil
					elseif os.clock() - ult.LastShotAt >= (1 / ult.ShotsPerSecond) then
						ult.LastShotAt = os.clock()
						local dir = hero.Root.CFrame.LookVector
						local spreadDir = Util.RandomVectorInCone(dir, ult.SpreadDegrees or 5)
						local aimPoint = hero.Root.Position + spreadDir * (ult.Range or 500)
						CombatSystem.FireWeapon(hero, aimPoint - hero.Root.Position)
					end
				end

				-- Adrenaline effect (speed + fire rate)
				if hero.ActiveEffects and hero.ActiveEffects.adrenaline then
					local adr = hero.ActiveEffects.adrenaline
					if os.clock() >= adr.ExpireAt then
						hero.ActiveEffects.adrenaline = nil
						local heroDef = HeroConfig[hero.HeroId]
						if heroDef then hero.Humanoid.WalkSpeed = heroDef.walkSpeed end
					end
				end

				-- Berserk effect
				if hero.ActiveEffects and hero.ActiveEffects.berserk then
					local bs = hero.ActiveEffects.berserk
					if os.clock() >= bs.ExpireAt then
						hero.ActiveEffects.berserk = nil
					end
				end

				-- Burn damage over time
				processBurn(hero, os.clock())

				-- Freeze slow effect
				processFreeze(hero, os.clock())

				-- Supernova channel -> detonation
				processSupernova(hero, os.clock())

				-- Tether heal sharing
				processTether(hero, os.clock())
				processTetheredBy(hero, os.clock())

				-- Phoenix dive landing check
				processPhoenixDive(hero, os.clock())

				-- Cloak and dagger speed
				processCloakAndDagger(hero, os.clock())

				-- EMP disabled
				processEMP(hero, os.clock())

				-- Smoke screen
				processSmokeScreen(hero, os.clock())

				-- Radar pulse
				processRadarPulse(hero, os.clock())

				-- Tactical overlay
				processTacticalOverlay(hero, os.clock())

			-- Hero power effect processing
			local heroDef = HeroConfig[hero.HeroId]
			if heroDef and heroDef.powers then
				for powerId, powerDef in pairs(heroDef.powers) do
					local powerKey = "power_" .. powerId
					if hero.ActiveEffects and hero.ActiveEffects[powerKey] then
						local pe = hero.ActiveEffects[powerKey]
						if os.clock() >= pe.ExpireAt then
							hero.ActiveEffects[powerKey] = nil
						elseif os.clock() - pe.LastTick >= (powerDef.tickInterval or 1) then
							pe.LastTick = os.clock()
							-- Apply power effect
							if powerId == "speedBoost" then
								hero.Humanoid.WalkSpeed = heroDef.walkSpeed * (powerDef.multiplier or 1.3)
							elseif powerId == "damageResistance" then
								-- Handled in ApplyDamage via ActiveEffects
							elseif powerId == "wallHack" then
								-- Handled client-side via ESP
							elseif powerId == "teamHeal" then
								-- Triggered heal pulse already
							elseif powerId == "damageBoost" then
								-- Apply damage multiplier on next hit
							end
						end
					end
				end
			end

			-- Regenerate ultimate charge slowly over time
			if hero.UltimateCharge < hero.UltimateChargeMax then
				hero.UltimateCharge = math.min(hero.UltimateChargeMax, hero.UltimateCharge + 0.05)
			end
		end
	end
end
end)

-- Update match state broadcasting and spawning
task.spawn(function()
	while true do
		task.wait(0.2)
		matchStateChanged:FireAllClients({
			state = MatchSystem.State,
			timerRemaining = MatchSystem.Timer,
			redScore = MatchSystem.Score.Red,
			blueScore = MatchSystem.Score.Blue,
			winner = MatchSystem.Winner,
			gameMode = MatchSystem.GameMode,
			kothHolder = MatchSystem.KOTHHolder,
			roundNumber = MatchSystem.RoundNumber,
			roundPhase = MatchSystem.RoundPhase,
			bombState = MatchSystem.BombState,
			bombTimer = MatchSystem.BombTimer,
			roundScore = MatchSystem.RoundScore,
			hasBomb = false,
		})
		scoreChanged:FireAllClients({
			Red = MatchSystem.Score.Red,
			Blue = MatchSystem.Score.Blue,
			coreDamage = MatchSystem.CoreDamage,
		})
		heroStateSnapshot:FireAllClients({
			matchId = MatchSystem.MatchId,
			heroes = HeroSystem.GetSnapshot(),
		})
		objectiveStateChanged:FireAllClients({
			objectives = CombatSystem.GetObjectiveSnapshot(),
		})
	end
end)

-- Spawn heroes and start AI
task.spawn(function()
	while true do
		task.wait(1)
		if MatchSystem.State == "MatchCountdown" then
			-- do nothing during countdown
		elseif MatchSystem.State == "ActiveMatch" then
			if not MatchSystem.SpawnedThisMatch then
				MatchSystem.SpawnedThisMatch = true
				for _, plr in ipairs(Players:GetPlayers()) do
					local deck = MatchSystem.Decks[plr.UserId] or Config.DEFAULT_DECK
					local teamId = MatchSystem.GetTeam(plr.UserId) or Config.TEAM_RED
					HeroSystem.SpawnHeroesForOwner(plr.UserId, teamId, deck, plr)
				end
				if MatchSystem.BotActive then
					local botDeck = Config.BOT_DECK
					HeroSystem.SpawnHeroesForOwner(MatchSystem.BotOwnerId, Config.TEAM_BLUE, botDeck, nil)
				end

-- Initialize AI system (once)
			if not AISystem.Initialized then
				AISystem.Init(HeroSystem, MatchSystem, CombatSystem, AbilitySystem)
				AISystem.Initialized = true
			end

			-- Enable AI for non-controlled heroes
			for _, hero in pairs(HeroSystem.HeroesByGuid) do
				if not hero.IsControlled then
					AISystem.EnableHeroAI(hero, true)
				end
			end

				-- Spawn pickups
				for _, pos in ipairs(Config.MAP.POWERUP_SPAWNS) do
					local types = {"Health", "Ammo", "Energy"}
					local ptype = types[math.random(1, #types)]
					CombatSystem.CreatePickup(ptype, pos)
				end

				-- Spawn armor stations
				MapBuilder.AddArmorStations()

				announcementEvent:FireAllClients({text = "⚔️ FIGHT! ⚔️", duration = 3})
			end
		elseif MatchSystem.State == "PostMatch" then
			-- waiting for reset
		elseif MatchSystem.State == "Resetting" then
			HeroSystem.ClearAll()
			MatchSystem.SpawnedThisMatch = false
			AISystem.Clear()
			AbilitySystem.Clear()
			MapBuilder.BuildNeonFoundry()
			CombatSystem.Init()
			local objectivesFolder = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Objectives")
			for _, child in ipairs(objectivesFolder:GetChildren()) do
				if child.Name == "RedCore" then
					CombatSystem.RegisterObjective(child, Config.TEAM_RED, Config.CORE_MAX_HEALTH, "Core")
				elseif child.Name == "BlueCore" then
					CombatSystem.RegisterObjective(child, Config.TEAM_BLUE, Config.CORE_MAX_HEALTH, "Core")
				elseif string.find(child.Name, "RedGenerator") then
					CombatSystem.RegisterObjective(child, Config.TEAM_RED, Config.GENERATOR_MAX_HEALTH, "Generator")
				elseif string.find(child.Name, "BlueGenerator") then
					CombatSystem.RegisterObjective(child, Config.TEAM_BLUE, Config.GENERATOR_MAX_HEALTH, "Generator")
				end
			end
			MatchSystem.NeedsWorldReset = false
		elseif MatchSystem.State == "Lobby" and MatchSystem.NeedsWorldReset then
			HeroSystem.ClearAll()
			AISystem.Clear()
			AbilitySystem.Clear()
			CombatSystem.Init()
			MapBuilder.BuildNeonFoundry()
			local objectivesFolder = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Objectives")
			for _, child in ipairs(objectivesFolder:GetChildren()) do
				if child.Name == "RedCore" then
					CombatSystem.RegisterObjective(child, Config.TEAM_RED, Config.CORE_MAX_HEALTH, "Core")
				elseif child.Name == "BlueCore" then
					CombatSystem.RegisterObjective(child, Config.TEAM_BLUE, Config.CORE_MAX_HEALTH, "Core")
				elseif string.find(child.Name, "RedGenerator") then
					CombatSystem.RegisterObjective(child, Config.TEAM_RED, Config.GENERATOR_MAX_HEALTH, "Generator")
				elseif string.find(child.Name, "BlueGenerator") then
					CombatSystem.RegisterObjective(child, Config.TEAM_BLUE, Config.GENERATOR_MAX_HEALTH, "Generator")
				end
			end
			MatchSystem.NeedsWorldReset = false
		end
	end
end)

print(Config.GAME_NAME .. " Stage 8 boot complete - All systems online")