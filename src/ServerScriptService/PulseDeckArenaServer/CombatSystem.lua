--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local Util = require(sharedRoot:WaitForChild("Util"))
local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))

local CombatSystem = {}

CombatSystem.Objectives = {}
CombatSystem.ActivePickups = {}

-- Pickup types: Health, Ammo, Energy
local PICKUP_TYPES = {
	Health = {respawnTime = 15, amount = 50},
	Ammo = {respawnTime = 12, amount = 100},
	Energy = {respawnTime = 18, amount = 30},
	Armor = {respawnTime = 20, amount = 50},
}

local BURN_TICK_INTERVAL = 0.5
local FREEZE_TICK_INTERVAL = 0.5

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

local function fireDamageNumber(player, payload)
	if not player then return end
	local remotes = getRemotes()
	local event = remotes and remotes:FindFirstChild("DamageNumberEvent")
	if event and event:IsA("RemoteEvent") then
		event:FireClient(player, payload)
	end
end

local function fireAnnouncement(text, duration)
	local remotes = getRemotes()
	local event = remotes and remotes:FindFirstChild("AnnouncementEvent")
	if event and event:IsA("RemoteEvent") then
		event:FireAllClients({text = text, duration = duration or 4})
	end
end

local function buildRayParams(hero)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignore = {hero.Model}
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	if world then
		local effects = world:FindFirstChild("Effects")
		local projectiles = world:FindFirstChild("Projectiles")
		if effects then table.insert(ignore, effects) end
		if projectiles then table.insert(ignore, projectiles) end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function getWeaponDamage(weapon, isHeadshot)
	local baseDamage = weapon.damage or 0
	if isHeadshot and weapon.headMultiplier then
		baseDamage = baseDamage * weapon.headMultiplier
	end
	return baseDamage
end

local function getDistanceFalloff(weapon, distance)
	if not weapon.falloffStart then return 1.0 end
	if distance <= weapon.falloffStart then return 1.0 end
	if distance >= weapon.falloffEnd then return weapon.falloffMultiplierAtEnd or 1.0 end
	local t = (distance - weapon.falloffStart) / (weapon.falloffEnd - weapon.falloffStart)
	return 1.0 - (1.0 - (weapon.falloffMultiplierAtEnd or 1.0)) * t
end

function CombatSystem.Init()
	CombatSystem.Objectives = {}
	CombatSystem.ActivePickups = {}
	CombatSystem.BurningEffects = {}
	CombatSystem.FrozenEffects = {}
end

function CombatSystem.CreateObjective(name, teamId, health, position)
	local model = Instance.new("Model")
	model.Name = name

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(8, 8, 8)
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	core.Color = (teamId == Config.TEAM_RED) and Config.RED_COLOR or Config.BLUE_COLOR
	core.Anchored = true
	core.Position = position
	core.Parent = model

	-- Add a glow ring around the core
	local ring = Instance.new("Part")
	ring.Name = "GlowRing"
	ring.Size = Vector3.new(14, 0.3, 14)
	ring.Color = core.Color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.Position = position + Vector3.new(0, 4, 0)
	ring.Parent = model

	-- Shield mesh effect
	local shield = Instance.new("Part")
	shield.Name = "ShieldMesh"
	shield.Size = Vector3.new(12, 12, 12)
	shield.Shape = Enum.PartType.Ball
	shield.Transparency = 0.7
	shield.Color = Color3.fromRGB(255, 255, 255)
	shield.Anchored = true
	shield.CanCollide = false
	shield.Position = position
	shield.Parent = model

	model.PrimaryPart = core
	model.Parent = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Objectives")
	model:SetAttribute("ObjectiveTeam", teamId)
	model:SetAttribute("ObjectiveType", name)

	CombatSystem.Objectives[model] = {
		TeamId = teamId,
		Name = name,
		Health = health,
		MaxHealth = health,
		Model = model,
	}

	return model
end

function CombatSystem.RegisterObjective(model, teamId, health, objectiveType)
	CombatSystem.Objectives[model] = {
		TeamId = teamId,
		Name = objectiveType,
		Health = health,
		MaxHealth = health,
		Model = model,
	}
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", health)
	model:SetAttribute("ObjectiveTeam", teamId)
	model:SetAttribute("ObjectiveType", objectiveType)
end

function CombatSystem.DamageObjective(model, amount, teamId)
	local obj = CombatSystem.Objectives[model]
	if not obj then return end
	if teamId == obj.TeamId then return end

	local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))

	local adjusted = amount
	if obj.Name == "Core" then
		local gens = 0
		for _, data in pairs(CombatSystem.Objectives) do
			if data.TeamId == obj.TeamId and data.Name == "Generator" and data.Health > 0 then
				gens += 1
			end
		end
		if gens == 2 then adjusted = adjusted * 0.4
		elseif gens == 1 then adjusted = adjusted * 0.6
		elseif gens == 0 then adjusted = adjusted * 1.5
		end

		MatchSystem.RecordCoreDamage(teamId, adjusted)
	end

	obj.Health = math.max(0, obj.Health - adjusted)
	model:SetAttribute("Health", obj.Health)

	-- Visual damage feedback
	if obj.Model and obj.Model.PrimaryPart then
		local percentage = obj.Health / obj.MaxHealth
		obj.Model.PrimaryPart.Color = Util.ColorLerp(
			obj.TeamId == Config.TEAM_RED and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(60, 200, 255),
			Color3.fromRGB(80, 10, 10),
			1 - percentage
		)
	end

	MatchSystem.AddScore(teamId, adjusted)

	fireEffect({
		effectType = "ObjectiveHit",
		position = model.PrimaryPart and model.PrimaryPart.Position or Vector3.zero,
		damageAmount = math.floor(adjusted),
	})

	if obj.Health == 0 then
		model:SetAttribute("Destroyed", true)
		fireEffect({
			effectType = "ObjectiveDestroyed",
			position = model.PrimaryPart and model.PrimaryPart.Position or Vector3.zero,
			teamId = teamId,
		})
		fireAnnouncement("💥 " .. tostring(teamId) .. " " .. obj.Name .. " DESTROYED!", 5)

		if obj.Name == "Generator" then
			MatchSystem.AddScore(teamId, Config.SCORE_GENERATOR_DESTROY)
		elseif obj.Name == "Core" then
			MatchSystem.OnCoreDestroyed(teamId)
		end
	end
end

function CombatSystem.GetObjectiveSnapshot()
	local snapshot = {}
	for model, obj in pairs(CombatSystem.Objectives) do
		snapshot[model.Name] = {
			objectiveType = obj.Name,
			teamId = obj.TeamId,
			health = obj.Health,
			maxHealth = obj.MaxHealth,
			alive = obj.Health > 0,
			position = model.PrimaryPart and model.PrimaryPart.Position or Vector3.zero,
		}
	end
	return snapshot
end

function CombatSystem.GetObjectiveFromPart(part)
	if not part then return nil end
	local current = part
	while current and current ~= workspace do
		if CombatSystem.Objectives[current] then
			return current, CombatSystem.Objectives[current]
		end
		current = current.Parent
	end
	return nil
end

local function getFireOrigin(hero)
	local origin = hero.Root.Position + Vector3.new(0, 1.5, 0)
	-- Adjust for weapon type
	local weaponCfg = WeaponConfig[hero.WeaponId]
	if weaponCfg and (weaponCfg.weaponModel == "Sniper" or weaponCfg.weaponModel == "Launcher") then
		origin = hero.Root.Position + Vector3.new(0, 1.8, 0)
	end
	return origin
end

local function canFire(hero, weapon)
	if not hero.Alive then return false end
	if hero.IsReloading then return false end
	if hero.Ammo <= 0 then return false end
	if os.clock() < hero.NextFireAt then return false end
	if hero.Stunned then return false end
	if hero.Model and hero.Model:GetAttribute("IsControlled") == false then return false end
	return true
end

function CombatSystem.RequestReload(hero)
	if not hero or hero.IsReloading then return end
	local weapon = WeaponConfig[hero.WeaponId]
	if not weapon then return end
	if hero.Ammo >= weapon.magazineSize then return end
	if hero.ReserveAmmo <= 0 then return end

	hero.IsReloading = true
	hero.ReloadEndAt = os.clock() + weapon.reloadTime

	fireEffect({
		effectType = "Reload",
		heroGuid = hero.Guid,
		position = hero.Root.Position,
		duration = weapon.reloadTime,
	})

	task.delay(weapon.reloadTime, function()
		if not hero.Alive then
			hero.IsReloading = false
			return
		end
		local need = weapon.magazineSize - hero.Ammo
		local take = math.min(need, hero.ReserveAmmo)
		hero.Ammo = hero.Ammo + take
		hero.ReserveAmmo = hero.ReserveAmmo - take
		hero.IsReloading = false

		fireEffect({
			effectType = "ReloadComplete",
			heroGuid = hero.Guid,
			position = hero.Root.Position,
		})
	end)
end

function CombatSystem.ApplyDamage(attacker, target, amount, damageType, isHeadshot)
	if not attacker or not target then return end
	if not target.Alive then return end
	if attacker.TeamId == target.TeamId then return end
	if target.InvulnerableUntil and os.clock() < target.InvulnerableUntil then return end
	if target.IsStealthed and (not isHeadshot) then return end -- Can't hit stealthed enemies except headshots

	local finalAmount = amount

	-- Shield absorption
	local shieldAbsorbed = 0
	if target.ShieldHealth and target.ShieldHealth > 0 then
		shieldAbsorbed = math.min(target.ShieldHealth, finalAmount * 0.5)
		target.ShieldHealth = math.max(0, target.ShieldHealth - shieldAbsorbed)
		finalAmount = finalAmount - shieldAbsorbed
	end

	-- Damage reduction from abilities
	local ok, AbilitySystem = pcall(function()
		return require(script.Parent:WaitForChild("AbilitySystem"))
	end)
	if ok and AbilitySystem then
		finalAmount = finalAmount * (1 - AbilitySystem.GetDamageReduction(target))
		if AbilitySystem.IsMarked(target, attacker) then
			finalAmount = finalAmount * 1.2
		end
		-- Slow field damage
		if target.ActiveEffects and target.ActiveEffects.slowField then
			finalAmount = finalAmount * 1.15 -- Bonus damage to slowed enemies
		end
	end

	-- Damage resistance from power
	if target.ActiveEffects and target.ActiveEffects.power_damageresistance then
		finalAmount = finalAmount * (1 - (target.ActiveEffects.power_damageresistance.reduction or 0))
	end

	-- Critical hit (10% chance)
	local isCritical = math.random() < 0.1
	if isCritical then
		finalAmount = finalAmount * 1.5
	end

	-- Headshot bonus
	if isHeadshot then
		local weapon = WeaponConfig[attacker.WeaponId]
		if weapon and weapon.headMultiplier then
			finalAmount = finalAmount * (weapon.headMultiplier / (weapon.headMultiplier - 1) * 0.5 + 0.5)
		end
	end

	-- Distance falloff
	local distance = (attacker.Root.Position - target.Root.Position).Magnitude
	local weapon = WeaponConfig[attacker.WeaponId]
	if weapon then
		finalAmount = finalAmount * getDistanceFalloff(weapon, distance)
	end

	finalAmount = math.max(0, math.floor(finalAmount))

	target.Health = math.max(0, target.Health - finalAmount)
	target.Humanoid.Health = target.Health
	target.DamageTaken = (target.DamageTaken or 0) + finalAmount
	attacker.DamageDealt = (attacker.DamageDealt or 0) + finalAmount

	local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))
	MatchSystem.AddScore(attacker.TeamId, finalAmount)

	-- Determine damage number color
	local numberColor = Config.DAMAGE_NUMBER_COLORS.normal
	if isHeadshot then
		numberColor = Config.DAMAGE_NUMBER_COLORS.headshot
	elseif isCritical then
		numberColor = Config.DAMAGE_NUMBER_COLORS.critical
	elseif damageType == "heal" then
		numberColor = Config.DAMAGE_NUMBER_COLORS.healing
	elseif damageType == "ability" then
		numberColor = Config.DAMAGE_NUMBER_COLORS.ability
	end

	-- Show damage number to attacker
	fireDamageNumber(attacker.OwnerPlayer, {
		amount = finalAmount,
		position = target.Root.Position,
		isHealing = damageType == "heal",
		isCritical = isCritical,
		isHeadshot = isHeadshot,
		color = numberColor,
		shieldAbsorbed = shieldAbsorbed,
	})

	-- Award killstreak tracking
	if target.Health <= 0 then
		attacker.KillCount = (attacker.KillCount or 0) + 1

		if attacker.OwnerPlayer and not (MatchSystem.GameMode == "FFA") then
			MatchSystem.AddKillstreak(attacker.OwnerPlayer.UserId)
		end

		local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
		HeroSystem.KillHero(target, attacker.OwnerId)

		-- Kill XP bonus to attacker
		local ProgressionSystem = require(script.Parent:WaitForChild("ProgressionSystem"))
		local attackerProfile = ProgressionSystem.Profiles[attacker.OwnerId]
		if attackerProfile then
			attackerProfile.XP = (attackerProfile.XP or 0) + 30
		end

		-- Economy money for bomb mode
		if MatchSystem.GameMode == "Bomb" then
			local reward = attacker.TeamId == Config.TEAM_RED and Config.BOMB_KILL_REWARD_CT or Config.BOMB_KILL_REWARD_T
			attacker.Money = (attacker.Money or 0) + reward
		end

		local remotes = getRemotes()
		local killfeed = remotes and remotes:FindFirstChild("KillfeedEvent")
		if killfeed and killfeed:IsA("RemoteEvent") then
			local attackerName = "???"
			if attacker.OwnerPlayer then
				attackerName = attacker.OwnerPlayer.Name
			elseif attacker.OwnerId == "__BOT_BLUE__" then
				attackerName = attacker.Model.Name
			end

			killfeed:FireAllClients({
				killerName = attackerName,
				victimName = target.Model.Name,
				teamId = attacker.TeamId,
				victimTeamId = target.TeamId,
				weaponId = attacker.WeaponId,
				isHeadshot = isHeadshot or false,
				killCount = attacker.KillCount,
			})
		end

		-- Update killstreaks after death
		if MatchSystem.GameMode ~= "FFA" then
			MatchSystem.ResetKillstreak(target.OwnerId, attacker.OwnerId)
		end

		-- FFA kill tracking
		if MatchSystem.GameMode == "FFA" then
			MatchSystem.AddFFAKill(attacker.OwnerId)
		end

		-- Dispatch kill effect for the attacker's hero
		local heroDef = HeroConfig[attacker.HeroId]
		if heroDef and heroDef.killEffect then
			fireEffect({
				effectType = heroDef.killEffect,
				position = target.Root.Position,
				heroGuid = attacker.Guid,
			})
		end
	end

	return finalAmount
end

function CombatSystem.FireWeapon(hero, direction)
	local weapon = WeaponConfig[hero.WeaponId]
	if not canFire(hero, weapon) then
		if hero.Ammo <= 0 then
			CombatSystem.RequestReload(hero)
		end
		return
	end

	local ammoCost = 1
	local weaponBehavior = weapon.behavior

	if weaponBehavior == "Beam" then
		ammoCost = weapon.ammoDrainPerSecond * (weapon.tickInterval or 0.1)
	elseif weaponBehavior == "ChargingProjectile" then
		ammoCost = weapon.ammoPerShot or 5
	elseif weaponBehavior == "Melee" or weaponBehavior == "MeleeSweep" then
		ammoCost = 0 -- Melee weapons don't use ammo
	elseif weaponBehavior == "MeleeExplosive" then
		ammoCost = 0
	elseif weaponBehavior == "FlameThrower" then
		ammoCost = weapon.ammoDrainPerSecond * (weapon.tickInterval or 0.15)
	end

	hero.Ammo = math.max(0, hero.Ammo - ammoCost)
	hero.NextFireAt = os.clock() + (weapon.fireInterval or weapon.tickInterval or 0.1)

	-- Weapon sway while moving for hip fire spread
	local moveSway = 0
	if hero.Humanoid and hero.Humanoid.MoveDirection.Magnitude > 0.1 then
		moveSway = 0.5
	end

	local origin = getFireOrigin(hero)
	local spreadAngle = (weapon.spreadDegrees or 0) + moveSway
	local spreadDir = Util.RandomVectorInCone(direction.Unit, spreadAngle)
	local params = buildRayParams(hero)

	-- Muzzle flash effect
	fireEffect({
		effectType = "MuzzleFlash",
		position = origin,
		direction = direction.Unit,
		heroGuid = hero.Guid,
		color = weapon.muzzleFlashColor or Color3.fromRGB(255, 200, 100),
	})

	-- === HANDLER PER WEAPON BEHAVIOR ===

	if weaponBehavior == "ProjectileExplosive" then
		local range = weapon.range or ((weapon.projectileSpeed or 175) * (weapon.rangeLifetime or 3))
		local ray = workspace:Raycast(origin, spreadDir * range, params)

		local hitPos = ray and ray.Position or (origin + spreadDir * range)

		if ray then
			local objModel, objData = CombatSystem.GetObjectiveFromPart(ray.Instance)
			if objModel and objData then
				CombatSystem.DamageObjective(objModel, weapon.directDamage, hero.TeamId)
			else
				local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
				local hitHero = HeroSystem.GetHeroFromPart(ray.Instance)
				if hitHero then
					CombatSystem.ApplyDamage(hero, hitHero, weapon.directDamage)
				end
			end
		end

		-- Visual projectile trail
		fireEffect({
			effectType = "ProjectileTrail",
			startPos = origin,
			endPos = hitPos,
			speed = weapon.projectileSpeed,
			color = weapon.tracerColor,
		})

		fireEffect({
			effectType = "Explosion",
			position = hitPos,
			radius = weapon.splashRadius or 12,
			duration = 0.5,
			innerRadius = (weapon.splashRadius or 12) * 0.5,
		})

		-- Splash damage in radius
		local splashRadius = weapon.splashRadius or 8
		local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local dist = (h.Root.Position - hitPos).Magnitude
				if dist <= splashRadius then
					local splashDmg = weapon.splashDamage * (1 - (dist / splashRadius) * 0.5)
					CombatSystem.ApplyDamage(hero, h, math.floor(splashDmg))
				end
			end
		end

		-- Self damage
		local selfDmg = (weapon.selfDamageMultiplier or 0) * weapon.directDamage
		if selfDmg > 0 then
			CombatSystem.ApplyDamage(hero, hero, selfDmg)
		end
		return
	end

	if weaponBehavior == "Shotgun" then
		for i = 1, weapon.pellets do
			local pelletDir = Util.RandomVectorInCone(direction.Unit, weapon.spreadDegrees)
			local ray = workspace:Raycast(origin, pelletDir * weapon.range, params)

			if ray then
				local objModel, objData = CombatSystem.GetObjectiveFromPart(ray.Instance)
				if objModel and objData then
					CombatSystem.DamageObjective(objModel, weapon.damagePerPellet, hero.TeamId)
				else
					local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
					local hitHero = HeroSystem.GetHeroFromPart(ray.Instance)
					if hitHero then
						CombatSystem.ApplyDamage(hero, hitHero, weapon.damagePerPellet)
					end
				end
			end

			fireEffect({
				effectType = "Tracer",
				startPosition = origin,
				endPosition = ray and ray.Position or (origin + pelletDir * weapon.range),
				color = weapon.tracerColor,
				duration = 0.06,
			})
		end
		return
	end

	if weaponBehavior == "BurstHitscan" then
		task.spawn(function()
			for i = 1, weapon.burstCount do
				if not hero.Alive then break end
				local burstDir = Util.RandomVectorInCone(direction.Unit, weapon.spreadDegrees or 0)
				local ray = workspace:Raycast(origin, burstDir * weapon.range, params)

				if ray then
					local objModel, objData = CombatSystem.GetObjectiveFromPart(ray.Instance)
					if objModel and objData then
						CombatSystem.DamageObjective(objModel, weapon.damage, hero.TeamId)
					else
						local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
						local hitHero = HeroSystem.GetHeroFromPart(ray.Instance)
						if hitHero then
							CombatSystem.ApplyDamage(hero, hitHero, weapon.damage)
						end
					end
				end

				fireEffect({
					effectType = "Tracer",
					startPosition = origin,
					endPosition = ray and ray.Position or (origin + burstDir * weapon.range),
					color = weapon.tracerColor,
					duration = 0.06,
				})

				task.wait(weapon.burstInterval)
			end
		end)
		return
	end

	if weaponBehavior == "HitscanSniper" then
		local range = weapon.range or 500
		local ray = workspace:Raycast(origin, spreadDir * range, params)
		local isHeadshot = false

		if ray then
			if ray.Instance and ray.Instance.Name == "Head" then
				isHeadshot = true
			end

			local objModel, objData = CombatSystem.GetObjectiveFromPart(ray.Instance)
			if objModel and objData then
				CombatSystem.DamageObjective(objModel, getWeaponDamage(weapon, isHeadshot), hero.TeamId)
			else
				local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
				local hitHero = HeroSystem.GetHeroFromPart(ray.Instance)
				if hitHero then
					CombatSystem.ApplyDamage(hero, hitHero, getWeaponDamage(weapon, isHeadshot), nil, isHeadshot)
					isHeadshot = true -- Mark as headshot for feedback
				end
			end
		end

		-- Piercing - check for second target
		if weapon.pierceCount and weapon.pierceCount > 0 and ray then
			local pierceOrigin = ray.Position + spreadDir * 2
			local pierceParams = buildRayParams(hero)
			local pierceRay = workspace:Raycast(pierceOrigin, spreadDir * (range - (pierceOrigin - origin).Magnitude), pierceParams)
			if pierceRay then
				local objModel, objData = CombatSystem.GetObjectiveFromPart(pierceRay.Instance)
				if objModel and objData then
					CombatSystem.DamageObjective(objModel, weapon.damage * 0.5, hero.TeamId)
				else
					local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
					local hitHero = HeroSystem.GetHeroFromPart(pierceRay.Instance)
					if hitHero then
						CombatSystem.ApplyDamage(hero, hitHero, weapon.damage * 0.5)
					end
				end
			end
		end

		fireEffect({
			effectType = "Tracer",
			startPosition = origin,
			endPosition = ray and ray.Position or (origin + spreadDir * range),
			color = weapon.tracerColor,
			duration = 0.1,
			thickness = 2,
			isHeadshot = isHeadshot,
		})
		return
	end

	if weaponBehavior == "ChargedSniper" then
		local range = weapon.range or 500
		local ray = workspace:Raycast(origin, spreadDir * range, params)

		-- Charging damage: lerp between base and max damage
		-- (Charge is handled client-side, server just uses max for now)
		local damage = weapon.maxDamage

		if ray then
			local objModel, objData = CombatSystem.GetObjectiveFromPart(ray.Instance)
			if objModel and objData then
				CombatSystem.DamageObjective(objModel, damage, hero.TeamId)
			else
				local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
				local hitHero = HeroSystem.GetHeroFromPart(ray.Instance)
				if hitHero then
					CombatSystem.ApplyDamage(hero, hitHero, damage)
				end
			end
		end

		fireEffect({
			effectType = "Tracer",
			startPosition = origin,
			endPosition = ray and ray.Position or (origin + spreadDir * range),
			color = weapon.tracerColor,
			duration = 0.15,
			thickness = 3,
		})
		return
	end

	if weaponBehavior == "Beam" then
		local range = weapon.range or 200
		local ray = workspace:Raycast(origin, spreadDir * range, params)
		local hitEnemy = false

		if ray then
			local objModel, objData = CombatSystem.GetObjectiveFromPart(ray.Instance)
			if objModel and objData then
				CombatSystem.DamageObjective(objModel, weapon.damagePerSecond * weapon.tickInterval, hero.TeamId)
				hitEnemy = true
			else
				local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
				local hitHero = HeroSystem.GetHeroFromPart(ray.Instance)
				if hitHero then
					CombatSystem.ApplyDamage(hero, hitHero, weapon.damagePerSecond * weapon.tickInterval)
					hitEnemy = true
				end
			end
		end

		local endPos = ray and ray.Position or (origin + spreadDir * range)
		fireEffect({
			effectType = "Beam",
			startPosition = origin,
			endPosition = endPos,
			color = weapon.tracerColor,
			duration = 0.08,
			hitEnemy = hitEnemy,
		})
		return
	end

	if weaponBehavior == "Melee" then
		-- Melee lunge
		hero.Root.CFrame = CFrame.new(hero.Root.Position, hero.Root.Position + direction * 5)
		local meleeRange = weapon.attackRange or 4

		fireEffect({
			effectType = "Swing",
			position = origin,
			direction = direction.Unit,
			color = weapon.tracerColor,
		})

		-- Damage check in cone
		local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local toTarget = h.Root.Position - hero.Root.Position
				local dist = toTarget.Magnitude
				if dist <= meleeRange then
					local dot = direction.Unit:Dot(toTarget.Unit)
					if dot > 0.6 then -- Within cone
						CombatSystem.ApplyDamage(hero, h, weapon.damage)
					end
				end
			end
		end
		return
	end

	if weaponBehavior == "MeleeSweep" then
		local sweepAngle = weapon.sweepAngle or 120

		fireEffect({
			effectType = "Swing",
			position = origin,
			direction = direction.Unit,
			color = weapon.tracerColor,
			sweepAngle = sweepAngle,
		})

		local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local toTarget = h.Root.Position - hero.Root.Position
				local dist = toTarget.Magnitude
				if dist <= weapon.attackRange then
					local dot = direction.Unit:Dot(toTarget.Unit)
					local angle = math.acos(Util.Clamp(dot, -1, 1))
					if math.deg(angle) <= sweepAngle / 2 then
						CombatSystem.ApplyDamage(hero, h, weapon.damage)
						-- Knockback
						if h.Humanoid and h.Root then
							h.Root.Velocity = h.Root.CFrame.LookVector * 0 + Vector3.new(0, 20, 0) + toTarget.Unit * (weapon.knockbackForce or 30)
						end
					end
				end
			end
		end
		return
	end

	if weaponBehavior == "MeleeExplosive" then
		fireEffect({
			effectType = "Swing",
			position = origin,
			direction = direction.Unit,
			color = weapon.tracerColor,
		})

		-- Melee damage
		local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local toTarget = h.Root.Position - hero.Root.Position
				local dist = toTarget.Magnitude
				if dist <= weapon.attackRange then
					local dot = direction.Unit:Dot(toTarget.Unit)
					if dot > 0.5 then
						CombatSystem.ApplyDamage(hero, h, weapon.damage)
					end
				end
			end
		end

		-- AOE explosion
		local aoePos = origin + direction * 3
		fireEffect({
			effectType = "Explosion",
			position = aoePos,
			radius = weapon.splashRadius or 10,
			duration = 0.4,
		})

		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local dist = (h.Root.Position - aoePos).Magnitude
				if dist <= (weapon.splashRadius or 10) then
					CombatSystem.ApplyDamage(hero, h, weapon.splashDamage or 20)
					-- Knockback
					if h.Root then
						h.Root.Velocity = Vector3.new(0, 30, 0) + (h.Root.Position - aoePos).Unit * (weapon.knockbackForce or 40)
					end
				end
			end
		end

		-- Self knockback
		if hero.Root then
			hero.Root.Velocity = direction * (weapon.knockbackForce or 30) + Vector3.new(0, 15, 0)
		end

		return
	end

	if weaponBehavior == "FlameThrower" then
		local coneAngle = weapon.coneAngle or 45

		fireEffect({
			effectType = "FlameSpray",
			position = origin,
			direction = direction.Unit,
			color = weapon.tracerColor,
			coneAngle = coneAngle,
			range = weapon.range,
		})

		-- Damage in cone over time
		local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local toTarget = h.Root.Position - hero.Root.Position
				local dist = toTarget.Magnitude
				if dist <= weapon.range then
					local dot = direction.Unit:Dot(toTarget.Unit)
					local angle = math.acos(Util.Clamp(dot, -1, 1))
					if math.deg(angle) <= coneAngle / 2 then
						CombatSystem.ApplyDamage(hero, h, weapon.damagePerSecond * weapon.tickInterval, "burn")
					end
				end
			end
		end
		return
	end

	if weaponBehavior == "ChainLightning" then
		local range = weapon.range or 300
		local maxChains = weapon.maxChains or 4
		local chainRange = weapon.chainRange or 25

		local targets = {}
		local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))

		-- Find targets
		for _, h in pairs(HeroSystem.HeroesByGuid) do
			if h.Alive and h.TeamId ~= hero.TeamId then
				local dist = (h.Root.Position - origin).Magnitude
				if dist <= range then
					table.insert(targets, {hero = h, dist = dist})
				end
			end
		end

		if #targets == 0 then
			fireEffect({
				effectType = "Lightning",
				startPosition = origin,
				endPosition = origin + spreadDir * range,
				color = weapon.tracerColor,
			})
			return
		end

		-- Sort by distance
		table.sort(targets, function(a, b) return a.dist < b.dist end)

		-- Chain
		local currentPos = origin
		local chains = 0
		local processedTargets = {}

		for _, target in ipairs(targets) do
			if chains >= maxChains then break end
			if processedTargets[target.hero.Guid] then continue end

			local dist = (target.hero.Root.Position - currentPos).Magnitude
			if dist <= chainRange or currentPos == origin then
				CombatSystem.ApplyDamage(hero, target.hero, weapon.damage)
				processedTargets[target.hero.Guid] = true
				chains += 1

				fireEffect({
					effectType = "Lightning",
					startPosition = currentPos,
					endPosition = target.hero.Root.Position,
					color = weapon.tracerColor,
				})

				currentPos = target.hero.Root.Position
			end
		end
		return
	end

	-- === CHARGING PROJECTILE (e.g., Nova Launcher, Plasma Orb) ===
	if weaponBehavior == "ChargingProjectile" then
		local chargeTime = weapon.chargeTime or 1
		local range = weapon.range or 500

		-- Spawn projectile
		local projectile = Instance.new("Part")
		projectile.Name = "ChargingProjectile"
		projectile.Size = Vector3.new(1.5, 1.5, 1.5)
		projectile.Shape = Enum.PartType.Ball
		projectile.Color = weapon.tracerColor or Color3.fromRGB(255, 100, 200)
		projectile.Material = Enum.Material.Neon
		projectile.Anchored = false
		projectile.CanCollide = true
		projectile.Position = origin

		-- Glow
		local glow = Instance.new("PointLight")
		glow.Color = weapon.tracerColor
		glow.Brightness = 3
		glow.Range = 10
		glow.Parent = projectile

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = spreadDir * weapon.projectileSpeed
		bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		bodyVelocity.Parent = projectile

		projectile.Parent = getEffectsFolder()

		local startT = os.clock()

		-- Travel and explode
		local connection
		connection = game:GetService("RunService").Heartbeat:Connect(function()
			if not projectile or not projectile.Parent then
				connection:Disconnect()
				return
			end

			local elapsed = os.clock() - startT
			if elapsed > (weapon.rangeLifetime or 3) then
				connection:Disconnect()
				projectile:Destroy()
				return
			end

			-- Check for hits along the path
			local rayParams = buildRayParams(hero)
			local ray = workspace:Raycast(projectile.Position, projectile.Velocity * 0.05, rayParams)
			if ray then
				connection:Disconnect()

				local hitPos = ray.Position

				-- Check for objective hit
				local objModel, objData = CombatSystem.GetObjectiveFromPart(ray.Instance)
				if objModel and objData then
					CombatSystem.DamageObjective(objModel, weapon.directDamage, hero.TeamId)
				else
					local hitHero = HeroSystem.GetHeroFromPart(ray.Instance)
					if hitHero then
						CombatSystem.ApplyDamage(hero, hitHero, weapon.directDamage)
					end
				end

				-- Splash damage on impact
				if weapon.splashRadius and weapon.splashDamage then
					fireEffect({
						effectType = "Explosion",
						position = hitPos,
						radius = weapon.splashRadius,
						duration = 0.5,
					})
					for _, h in pairs(HeroSystem.HeroesByGuid) do
						if h.Alive and h.TeamId ~= hero.TeamId then
							local dist = (h.Root.Position - hitPos).Magnitude
							if dist <= weapon.splashRadius then
								local splashDmg = weapon.splashDamage * (1 - (dist / weapon.splashRadius) * 0.5)
								CombatSystem.ApplyDamage(hero, h, math.floor(splashDmg))
							end
						end
					end
				end

				projectile:Destroy()
			end
		end)

		fireEffect({
			effectType = "ChargingProjectile",
			position = origin,
			direction = spreadDir,
			speed = weapon.projectileSpeed,
			color = weapon.tracerColor,
		})
		return
	end

	-- Default hitscan
	local range = weapon.range or 200
	local ray = workspace:Raycast(origin, spreadDir * range, params)

	if ray then
		local objModel, objData = CombatSystem.GetObjectiveFromPart(ray.Instance)
		if objModel and objData then
			local objectiveDamage = weapon.damage or ((weapon.damagePerSecond or 0) * (weapon.tickInterval or 1))
			CombatSystem.DamageObjective(objModel, objectiveDamage, hero.TeamId)
		else
			local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
			local hitHero = HeroSystem.GetHeroFromPart(ray.Instance)
			if hitHero then
				local dmg = weapon.damage or (weapon.damagePerSecond * weapon.tickInterval)
				local isHeadshot = ray.Instance and ray.Instance.Name == "Head"
				CombatSystem.ApplyDamage(hero, hitHero, dmg, nil, isHeadshot)
			end
		end
	end

	fireEffect({
		effectType = "Tracer",
		startPosition = origin,
		endPosition = ray and ray.Position or (origin + spreadDir * range),
		color = weapon.tracerColor,
		duration = 0.08,
	})
end

function CombatSystem.DamageRadius(ownerHero, position, radius, damage, objectiveMultiplier)
	for _, hero in pairs(HeroSystem.HeroesByGuid) do
		if hero.Alive and hero.TeamId ~= ownerHero.TeamId and (hero.Root.Position - position).Magnitude <= radius then
			CombatSystem.ApplyDamage(ownerHero, hero, damage)
		end
	end

	local objectivesFolder = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Objectives")
	if objectivesFolder then
		for _, model in ipairs(objectivesFolder:GetChildren()) do
			if model:IsA("Model") and model.PrimaryPart and model:GetAttribute("ObjectiveTeam") ~= ownerHero.TeamId then
				if (model.PrimaryPart.Position - position).Magnitude <= radius then
					CombatSystem.DamageObjective(model, damage * (objectiveMultiplier or 1), ownerHero.TeamId)
				end
			end
		end
	end
end

function CombatSystem.CreatePickup(pickupType, position)
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	if not world then return end
	local pickupsFolder = world:FindFirstChild("Pickups")
	if not pickupsFolder then
		pickupsFolder = Instance.new("Folder")
		pickupsFolder.Name = "Pickups"
		pickupsFolder.Parent = world
	end

	local config = PICKUP_TYPES[pickupType]
	if not config then return end

	local pickupModel = Instance.new("Model")
	pickupModel.Name = pickupType .. "_Pickup"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(2, 1, 2)
	base.Color = pickupType == "Health" and Color3.fromRGB(40, 200, 80)
		or pickupType == "Ammo" and Color3.fromRGB(200, 160, 40)
		or Color3.fromRGB(80, 120, 255)
	base.Material = Enum.Material.Neon
	base.Anchored = true
	base.CanCollide = false
	base.Position = position
	base.Orientation = Vector3.new(0, 0, 90)
	base.Parent = pickupModel

	-- Glow effect
	local glow = Instance.new("PointLight")
	glow.Color = base.Color
	glow.Brightness = 2
	glow.Range = 12
	glow.Parent = base

	-- Sparkle
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = base.Color
	sparkle.Parent = base

	pickupModel.PrimaryPart = base
	pickupModel.Parent = pickupsFolder

	local guid = HttpService:GenerateGUID(false)
	CombatSystem.ActivePickups[guid] = {
		model = pickupModel,
		type = pickupType,
		position = position,
		respawnTime = config.respawnTime,
		active = true,
	}

	-- Handle collection
	base.Touched:Connect(function(hit)
		if not CombatSystem.ActivePickups[guid] then return end
		if not CombatSystem.ActivePickups[guid].active then return end

		local hero = HeroSystem.GetHeroFromPart(hit)
		if not hero or not hero.Alive then return end

		local collected = false
		if pickupType == "Health" then
			if hero.Health < hero.MaxHealth then
				hero.Health = math.min(hero.MaxHealth, hero.Health + config.amount)
				hero.Humanoid.Health = hero.Health
				collected = true
			end
		elseif pickupType == "Ammo" then
			local weapon = WeaponConfig[hero.WeaponId]
			if weapon and hero.ReserveAmmo < weapon.reserveAmmo then
				hero.ReserveAmmo = math.min(weapon.reserveAmmo, hero.ReserveAmmo + config.amount)
				collected = true
			end
		elseif pickupType == "Energy" then
			collected = true -- Energy is used for ultimates
			if hero.UltimateCharge < hero.UltimateChargeMax then
				hero.UltimateCharge = math.min(hero.UltimateChargeMax, hero.UltimateCharge + config.amount)
			end
		end

		if collected then
			-- Hide pickup
			CombatSystem.ActivePickups[guid].active = false
			base.Transparency = 1
			fireEffect({effectType = "PickupCollected", position = position, pickupType = pickupType})

			task.delay(config.respawnTime, function()
				if CombatSystem.ActivePickups[guid] then
					CombatSystem.ActivePickups[guid].active = true
					base.Transparency = 0
				end
			end)
		end
	end)

	return guid
end

return CombatSystem