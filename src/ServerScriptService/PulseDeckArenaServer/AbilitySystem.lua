--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local AbilityConfig = require(sharedRoot:WaitForChild("AbilityConfig"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local Config = require(sharedRoot:WaitForChild("Config"))

local AbilitySystem = {}

AbilitySystem.HeroSystem = nil
AbilitySystem.MatchSystem = nil
AbilitySystem.CombatSystem = nil
AbilitySystem.ActiveDomes = {}
AbilitySystem.SlowFields = {}
AbilitySystem.ActiveSlowFields = {}
AbilitySystem.Sentries = {}
AbilitySystem.GravityWells = {}
AbilitySystem.EnergyShields = {}
AbilitySystem.ActiveHealingFields = {}
AbilitySystem.ActiveMines = {}

local function makeSphere(name, position, radius, color, lifetime)
	local sphere = Instance.new("Part")
	sphere.Name = name
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	sphere.Position = position
	sphere.Color = color
	sphere.Material = Enum.Material.SmoothPlastic
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.Transparency = 0.7
	sphere.Parent = getEffectsFolder()
	if lifetime then
		task.delay(lifetime, function()
			if sphere and sphere.Parent then sphere:Destroy() end
		end)
	end
	return sphere
end

local function getEffectsFolder()
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	if not world then return nil end
	local effects = world:FindFirstChild("Effects")
	if not effects then
		effects = Instance.new("Folder")
		effects.Name = "Effects"
		effects.Parent = world
	end
	return effects :: Folder
end

local function getRemotes()
	local root = ReplicatedStorage:FindFirstChild("PulseDeckArena")
	return root and root:FindFirstChild("Remotes")
end

local function effectAll(payload)
	local remotes = getRemotes()
	local event = remotes and remotes:FindFirstChild("EffectsEvent")
	if event and event:IsA("RemoteEvent") then
		event:FireAllClients(payload)
	end
end

local function safeDirection(hero, payload)
	local dir = payload and payload.direction
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.1 then
		return hero.Root.CFrame.LookVector
	end
	return dir.Unit
end

function AbilitySystem.Init(heroSystem, matchSystem, combatSystem)
	AbilitySystem.HeroSystem = heroSystem
	AbilitySystem.MatchSystem = matchSystem
	AbilitySystem.CombatSystem = combatSystem

	task.spawn(function()
		while true do
			task.wait(0.2)
			AbilitySystem.UpdateTimedAbilities()
		end
	end)
end

function AbilitySystem.Clear()
	AbilitySystem.ActiveDomes = {}
	AbilitySystem.SlowFields = {}
	AbilitySystem.Sentries = {}
	AbilitySystem.GravityWells = {}
	AbilitySystem.EnergyShields = {}
	AbilitySystem.ActiveHealingFields = {}
	local effects = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Effects")
	if effects then
		effects:ClearAllChildren()
	end
end

function AbilitySystem.GetDamageReduction(targetHero)
	local now = os.clock()
	local best = 0
	for _, dome in ipairs(AbilitySystem.ActiveDomes) do
		if now <= dome.ExpireAt and dome.TeamId == targetHero.TeamId and dome.Health > 0 then
			if (targetHero.Root.Position - dome.Position).Magnitude <= dome.Radius then
				best = math.max(best, dome.Reduction)
			end
		end
	end
	-- Energy shield
	for _, shield in ipairs(AbilitySystem.EnergyShields) do
		if now <= shield.ExpireAt and shield.Health > 0 then
			if (targetHero.Root.Position - shield.Position).Magnitude <= shield.Width / 2 then
				best = math.max(best, shield.DamageAbsorption)
			end
		end
	end
	return best
end

function AbilitySystem.IsMarked(targetHero, attackerHero)
	return targetHero.MarkedUntil and os.clock() < targetHero.MarkedUntil
		and attackerHero.HeroId == "vesper_scope"
		and targetHero.MarkedByOwnerId == attackerHero.OwnerId
end

function AbilitySystem.Heal(hero, amount)
	hero.Health = math.min(hero.MaxHealth, hero.Health + amount)
	hero.Humanoid.Health = hero.Health
end

function AbilitySystem.DamageRadius(ownerHero, position, radius, damage, objectiveMultiplier)
	for _, hero in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
		if hero.Alive and hero.TeamId ~= ownerHero.TeamId and (hero.Root.Position - position).Magnitude <= radius then
			AbilitySystem.CombatSystem.ApplyDamage(ownerHero, hero, damage)
		end
	end

	local objectivesFolder = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Objectives")
	if objectivesFolder then
		for _, model in ipairs(objectivesFolder:GetChildren()) do
			if model:IsA("Model") and model.PrimaryPart and model:GetAttribute("ObjectiveTeam") ~= ownerHero.TeamId then
				if (model.PrimaryPart.Position - position).Magnitude <= radius then
					AbilitySystem.CombatSystem.DamageObjective(model, damage * (objectiveMultiplier or 1), ownerHero.TeamId)
				end
			end
		end
	end
end

function AbilitySystem.UseAbility(hero, payload)
	local cfg = AbilityConfig[hero.AbilityId]
	if not cfg or not hero.Alive then return end
	local now = os.clock()
	if now < hero.AbilityReadyAt then return end

	local dir = safeDirection(hero, payload)

	-- === MOBILITY ABILITIES ===
	if cfg.id == "phase_dash" then
		local start = hero.Root.Position
		local goal = start + dir * cfg.dashDistance
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {hero.Model}
		local hit = workspace:Raycast(start, goal - start, params)
		if hit then goal = hit.Position - dir * 2 end
		hero.InvulnerableUntil = now + cfg.invulnerabilitySeconds
		hero.Model:PivotTo(CFrame.new(goal, goal + dir))
		effectAll({effectType = "Blink", position = start, endPosition = goal, duration = 0.25, color = cfg.trailColor})
		if cfg.leaveTrail then
			effectAll({effectType = "Trail", position = start, endPosition = goal, color = cfg.trailColor, duration = cfg.trailDuration})
		end

	elseif cfg.id == "shadow_step" then
		local start = hero.Root.Position
		local goal = start + dir * cfg.dashDistance
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {hero.Model}
		local hit = workspace:Raycast(start, goal - start, params)
		if hit then goal = hit.Position - dir * 2 end
		hero.InvulnerableUntil = now + cfg.invulnerabilitySeconds
		hero.IsStealthed = true
		hero.Model:PivotTo(CFrame.new(goal, goal + dir))
		effectAll({effectType = "Blink", position = start, endPosition = goal, duration = 0.35, color = Color3.fromRGB(40, 40, 50)})
		task.delay(cfg.stealthDuration, function()
			hero.IsStealthed = false
		end)

	elseif cfg.id == "time_dilation" then
		hero.IsStealthed = false -- Remove stealth if any
		local zonePos = hero.Root.Position
		effectAll({
			effectType = "TimeDilation",
			position = zonePos,
			radius = cfg.radius,
			duration = cfg.duration,
			color = cfg.effectColor,
			selfSpeedMultiplier = cfg.selfSpeedMultiplier,
			enemySlowMultiplier = cfg.enemySlowMultiplier,
		})
		-- Apply slow field effect
		AbilitySystem.ActiveSlowFields = AbilitySystem.ActiveSlowFields or {}
		table.insert(AbilitySystem.ActiveSlowFields, {
			Position = zonePos,
			Radius = cfg.radius,
			ExpireAt = now + cfg.duration,
			EnemySlow = cfg.enemySlowMultiplier,
			SelfSpeed = cfg.selfSpeedMultiplier,
			OwnerHero = hero,
		})

	elseif cfg.id == "overcharge" then
		hero.IsStealthed = false
		hero.ActiveEffects.overcharge = {
			ExpireAt = now + cfg.duration,
			SpeedMultiplier = cfg.speedMultiplier,
			FireRateMultiplier = cfg.fireRateMultiplier,
		}
		 effectAll({
			effectType = "OverchargeAura",
			position = hero.Root.Position,
			color = cfg.energyColor,
			duration = cfg.duration,
			radius = 3,
		})

	-- === DEFENSIVE ABILITIES ===
	elseif cfg.id == "shield_dome" then
		local color = cfg.color or (hero.TeamId == Config.TEAM_RED and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(60, 200, 255))
		local dome = makeSphere("ShieldDome", hero.Root.Position, cfg.radius, color, cfg.duration * 3)
		dome.Transparency = 0.6
		dome.CanCollide = true
		table.insert(AbilitySystem.ActiveDomes, {
			Part = dome,
			Position = hero.Root.Position,
			Radius = cfg.radius,
			Reduction = cfg.damageReduction,
			Health = cfg.domeHealth,
			TeamId = hero.TeamId,
			ExpireAt = now + cfg.duration,
			HealRate = cfg.healInsideAlly or 0,
			HealTick = cfg.healTickInterval or 1,
			LastHeal = now,
		})
		effectAll({effectType = "ShieldDome", position = hero.Root.Position, radius = cfg.radius, duration = cfg.duration})

	elseif cfg.id == "fortify" then
		hero.ActiveEffects.fortify = {
			ExpireAt = now + cfg.duration,
			DamageReduction = cfg.damageReduction,
			CannotMove = cfg.cannotMove,
			CanFire = cfg.canFireWhileActive,
		}
		effectAll({
			effectType = "FortifyAura",
			position = hero.Root.Position,
			color = cfg.effectColor,
			duration = cfg.duration,
		})

	-- === OFFENSIVE ABILITIES ===
	elseif cfg.id == "tracker_mark" then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {hero.Model}
		local origin = hero.Root.Position + Vector3.new(0, 1.5, 0)
		local hit = workspace:Raycast(origin, dir * cfg.range, params)
		if hit then
			local target = AbilitySystem.HeroSystem.GetHeroFromPart(hit.Instance)
			if target and target.TeamId ~= hero.TeamId then
				target.MarkedUntil = now + cfg.duration
				target.MarkedByOwnerId = hero.OwnerId
				target.ActiveEffects.markedByVesper = true
				effectAll({effectType = "TrackerMark", position = target.Root.Position, duration = cfg.duration})
			end
		end

	elseif cfg.id == "cluster_charge" then
		local explodeAt = hero.Root.Position + dir * 28
		task.delay(cfg.fuseSeconds, function()
			if hero.Alive then
				AbilitySystem.DamageRadius(hero, explodeAt, cfg.mainRadius, cfg.mainDamage, cfg.objectiveMultiplier)
				effectAll({effectType = "Explosion", position = explodeAt, radius = cfg.mainRadius, duration = 0.5})
				for i = 1, cfg.miniCount do
					local angle = (i / cfg.miniCount) * math.pi * 2
					local dist = cfg.miniSpread or 8
					local miniPos = explodeAt + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
					AbilitySystem.DamageRadius(hero, miniPos, cfg.miniRadius, cfg.miniDamage, cfg.objectiveMultiplier)
					effectAll({effectType = "Explosion", position = miniPos, radius = cfg.miniRadius, duration = 0.3})
				end
			end
		end)

	elseif cfg.id == "blink_swap" then
		local start = hero.Root.Position
		local goal = start + dir * cfg.teleportDistance
		for _, target in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
			if target.TeamId ~= hero.TeamId and target.Alive and (target.Root.Position - start).Magnitude <= cfg.targetBlinkRange then
				goal = target.Root.Position - target.Root.CFrame.LookVector * cfg.behindTargetOffset
				break
			end
		end
		hero.Model:PivotTo(CFrame.new(goal, goal + dir))
		if cfg.decoyExplodes then
			local decoy = Instance.new("Part")
			decoy.Name = "BlinkDecoy"
			decoy.Size = Vector3.new(2, 4, 1)
			decoy.Position = start
			decoy.Color = Color3.fromRGB(255, 255, 255)
			decoy.Material = Enum.Material.Neon
			decoy.Transparency = 0.3
			decoy.Anchored = true
			decoy.CanCollide = false
			decoy.Parent = getEffectsFolder()
			task.delay(cfg.decoyDuration, function()
				if decoy and decoy.Parent then
					decoy:Destroy()
					AbilitySystem.DamageRadius(hero, start, cfg.decoyRadius or 8, cfg.decoyDamage or 30)
					effectAll({effectType = "Explosion", position = start, radius = cfg.decoyRadius or 8, duration = 0.3})
				end
			end)
		end
		effectAll({effectType = "Blink", position = start, endPosition = goal, duration = 0.25})

	-- === SUPPORT ABILITIES ===
	elseif cfg.id == "heal_pulse" then
		for _, target in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
			if target.Alive and (target.Root.Position - hero.Root.Position).Magnitude <= cfg.radius then
				if target.TeamId == hero.TeamId then
					AbilitySystem.Heal(target, cfg.allyHeal)
					if target.ActiveEffects then
						target.ActiveEffects.healOverTime = {
							ExpireAt = now + (cfg.healOverTimeDuration or 3),
							HealPerTick = (cfg.healOverTime or 0),
							LastTick = now,
						}
					end
				else
					AbilitySystem.CombatSystem.ApplyDamage(hero, target, cfg.enemyDamage, "ability")
				end
			end
		end
		effectAll({effectType = "HealRing", position = hero.Root.Position, radius = cfg.radius, duration = 0.7, color = Color3.fromRGB(92, 255, 180, 150)})

	elseif cfg.id == "rejuvenation_field" then
		local field = Instance.new("Part")
		field.Name = "HealingField"
		field.Shape = Enum.PartType.Cylinder
		field.Size = Vector3.new(cfg.radius * 2, 0.5, cfg.radius * 2)
		field.Position = hero.Root.Position + Vector3.new(0, -0.5, 0)
		field.Color = cfg.color
		field.Material = Enum.Material.Neon
		field.Transparency = 0.5
		field.Anchored = true
		field.CanCollide = false
		field.Parent = getEffectsFolder()
		task.delay(cfg.duration, function() field:Destroy() end)

		AbilitySystem.ActiveHealingFields = AbilitySystem.ActiveHealingFields or {}
		table.insert(AbilitySystem.ActiveHealingFields, {
			Part = field,
			Position = hero.Root.Position,
			Radius = cfg.radius,
			HealPerSecond = cfg.healPerSecond,
			MaxHeal = cfg.maxHealPerAlly,
			TeamId = hero.TeamId,
			ExpireAt = now + cfg.duration,
			Healed = {},
		})
		effectAll({effectType = "HealField", position = hero.Root.Position, radius = cfg.radius, duration = cfg.duration})

	-- === UTILITY ABILITIES ===
	elseif cfg.id == "mini_sentry" then
		if hero.Sentry and hero.Sentry.Part then
			hero.Sentry.Part:Destroy()
		end
		local sentry = Instance.new("Part")
		sentry.Name = "MiniSentry"
		sentry.Shape = Enum.PartType.Cylinder
		sentry.Size = Vector3.new(2, 3, 2)
		sentry.Position = hero.Root.Position + dir * 5
		sentry.Color = Color3.fromRGB(35, 180, 170)
		sentry.Material = Enum.Material.Metal
		sentry.Anchored = true
		sentry.Parent = getEffectsFolder()
		local data = {
			Part = sentry,
			OwnerHero = hero,
			TeamId = hero.TeamId,
			ExpireAt = now + cfg.duration,
			NextFireAt = 0,
			Range = cfg.range,
			Damage = cfg.damage,
			FireInterval = cfg.fireInterval,
			BulletSpeed = cfg.bulletSpeed or 500,
			MaxTargets = cfg.maxTargets or 1,
		}
		hero.Sentry = data
		table.insert(AbilitySystem.Sentries, data)

	elseif cfg.id == "smart_mine" then
		local mine = Instance.new("Part")
		mine.Name = "SmartMine"
		mine.Shape = Enum.PartType.Ball
		mine.Size = Vector3.new(2, 2, 2)
		mine.Position = hero.Root.Position + dir * 3
		mine.Color = Color3.fromRGB(255, 50, 50)
		mine.Material = Enum.Material.Neon
		mine.Anchored = true
		mine.CanCollide = false
		mine.Parent = getEffectsFolder()

		local data = {
			Part = mine,
			OwnerHero = hero,
			TeamId = hero.TeamId,
			ExpireAt = now + cfg.duration,
			ArmedAt = now + (cfg.armTime or 1),
			Range = cfg.range,
			Damage = cfg.damage,
			SplashRadius = cfg.splashRadius or 8,
		}

		mine.Touched:Connect(function(hit)
			if not mine or not mine.Parent then return end
			if hit and hit.Parent then
				local hitHero = AbilitySystem.HeroSystem.GetHeroFromPart(hit)
				if hitHero and hitHero.TeamId ~= data.TeamId then
					AbilitySystem.CombatSystem.ApplyDamage(data.OwnerHero, hitHero, data.Damage)
				end
			end
			if mine and mine.Parent then
				mine:Destroy()
				AbilitySystem.DamageRadius(data.OwnerHero, data.Part.Position, data.SplashRadius, data.Damage, 0.5)
				effectAll({effectType = "Explosion", position = data.Part.Position, radius = data.SplashRadius, duration = 0.4})
			end
		end)
		table.insert(hero.Mines, data)
		table.insert(AbilitySystem.ActiveMines, data)
		effectAll({effectType = "MineDeployed", position = mine.Position})

	elseif cfg.id == "slow_field" then
		local position = hero.Root.Position + dir * math.min(cfg.targetRange, 40)
		local field = Instance.new("Part")
		field.Name = "SlowField"
		field.Shape = Enum.PartType.Cylinder
		field.Size = Vector3.new(cfg.radius * 2, 1, cfg.radius * 2)
		field.Position = position
		field.Color = cfg.color or Color3.fromRGB(80, 220, 255)
		field.Material = Enum.Material.Neon
		field.Transparency = 0.4
		field.Anchored = true
		field.CanCollide = false
		field.Parent = getEffectsFolder()
		task.delay(cfg.duration, function() field:Destroy() end)
		table.insert(AbilitySystem.SlowFields, {
			Part = field,
			OwnerHero = hero,
			TeamId = hero.TeamId,
			Position = position,
			Radius = cfg.radius,
			ExpireAt = now + cfg.duration,
			Slow = cfg.enemySlowMultiplier,
			Dps = cfg.damagePerSecond,
		})
		effectAll({effectType = "SlowField", position = position, radius = cfg.radius, duration = cfg.duration})

	-- === AREA CONTROL ===
	elseif cfg.id == "gravity_well" then
		local wellPos = hero.Root.Position + dir * 8
		table.insert(AbilitySystem.GravityWells, {
			Position = wellPos,
			Radius = cfg.radius,
			PullStrength = cfg.pullStrength,
			DamagePerSecond = cfg.damagePerSecond,
			ExpireAt = now + cfg.duration,
			OwnerHero = hero,
			Color = cfg.color,
		})
		effectAll({
			effectType = "GravityWell",
			position = wellPos,
			radius = cfg.radius,
			duration = cfg.duration,
			color = cfg.color,
		})

	elseif cfg.id == "energy_shield" then
		local shield = {
			Position = hero.Root.Position + dir * 3,
			Width = cfg.width,
			Height = cfg.height,
			MaxHealth = cfg.maxHealth,
			Health = cfg.maxHealth,
			DamageAbsorption = cfg.damageAbsorption,
			ReflectChance = cfg.reflectChance or 0,
			ExpireAt = now + cfg.duration,
			OwnerHero = hero,
			TeamId = hero.TeamId,
			Color = cfg.color,
		}
		table.insert(AbilitySystem.EnergyShields, shield)
		effectAll({
			effectType = "EnergyShield",
			position = shield.Position,
			width = cfg.width,
			height = cfg.height,
			color = cfg.color,
			duration = cfg.duration,
		})

	-- === ULTIMATE ===
	elseif cfg.id == "ultimate_ability" then
		hero.UltimateCharge = 0
		hero.ActiveEffects.ultimate = {
			ExpireAt = now + cfg.duration,
			ShotsPerSecond = cfg.shotsPerSecond,
			DamagePerShot = cfg.damagePerShot,
			Range = cfg.range,
			SpreadDegrees = cfg.spreadDegrees,
			LastShotAt = now,
		}
		effectAll({
			effectType = "UltimateActivated",
			position = hero.Root.Position,
			color = cfg.color,
			duration = cfg.duration,
			heroGuid = hero.Guid,
		})

	-- === MOBILITY: ADRENALINE ===
	elseif cfg.id == "adrenaline" then
		hero.ActiveEffects.adrenaline = {
			ExpireAt = now + cfg.duration,
			SpeedMultiplier = cfg.speedMultiplier,
			FireRateMultiplier = cfg.fireRateMultiplier,
		}
		effectAll({
			effectType = "OverchargeAura",
			position = hero.Root.Position,
			color = Color3.fromRGB(255, 200, 50),
			duration = cfg.duration,
			radius = 3,
		})

	-- === MOBILITY: BERSERK ===
	elseif cfg.id == "berserk" then
		hero.ActiveEffects.berserk = {
			ExpireAt = now + cfg.duration,
			DamageMultiplier = cfg.damageMultiplier,
			DamageReduction = cfg.damageReduction,
			SpeedMultiplier = cfg.speedMultiplier or 1.0,
		}
		effectAll({
			effectType = "BerserkAura",
			position = hero.Root.Position,
			color = Color3.fromRGB(255, 0, 0),
			duration = cfg.duration,
			radius = 4,
		})

	-- === MOBILITY: VAULT ===
	elseif cfg.id == "vault" then
		local goal = hero.Root.Position + dir * cfg.dashDistance
		goal = Vector3.new(goal.X, goal.Y + cfg.jumpBoost, goal.Z)
		hero.InvulnerableUntil = now + cfg.invulnerabilitySeconds
		hero.Root.CFrame = CFrame.new(goal, goal + dir)
		hero.Humanoid.Velocity = Vector3.new(0, cfg.jumpBoost * 3, 0)
		effectAll({effectType = "Blink", position = hero.Root.Position, endPosition = goal, duration = 0.3, color = cfg.trailColor})

-- === MOBILITY: PHOENIX DIVE ===
	elseif cfg.id == "phoenix_dive" then
		local skyPos = hero.Root.Position + Vector3.new(0, 80, 0)
		hero.Root.CFrame = CFrame.new(skyPos)
		hero.Root.Velocity = Vector3.new(0, -100, 0)
		hero.ActiveEffects.phoenixDiving = true
		task.delay(2, function()
			if hero.ActiveEffects then hero.ActiveEffects.phoenixDiving = nil end
		end)
		effectAll({
			effectType = "PhoenixDive",
			position = hero.Root.Position,
			radius = cfg.blastRadius,
			duration = 1,
			color = Color3.fromRGB(255, 100, 0),
		})
		-- Impact handled in UpdateTimedAbilities when phoenixDiving flag is set

	-- === STEALTH: CLOAK AND DAGGER ===
end

end

function AbilitySystem.UseUltimate(hero)
	if not hero.UltimateId then return end
	local cfg = AbilityConfig[hero.UltimateId]
	if not cfg then return end
	if hero.UltimateCharge < hero.UltimateChargeMax then return end
	hero.UltimateCharge = 0

	AbilitySystem.UseAbility(hero, {direction = hero.Root.CFrame.LookVector})
end

function AbilitySystem.UpdateTimedAbilities()
	local now = os.clock()

	-- Domes
	for i = #AbilitySystem.ActiveDomes, 1, -1 do
		local dome = AbilitySystem.ActiveDomes[i]
		if now > dome.ExpireAt or dome.Health <= 0 then
			if dome.Part then dome.Part:Destroy() end
			table.remove(AbilitySystem.ActiveDomes, i)
		elseif dome.HealRate > 0 and now - dome.LastHeal >= dome.HealTick then
			dome.LastHeal = now
			local allHealed = true
			for _, hero in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
				if hero.Alive and hero.TeamId == dome.TeamId and (hero.Root.Position - dome.Position).Magnitude <= dome.Radius then
					AbilitySystem.Heal(hero, dome.HealRate * dome.HealTick)
					allHealed = false
				end
			end
		end
	end

	-- Slow Fields
	for i = #AbilitySystem.SlowFields, 1, -1 do
		local field = AbilitySystem.SlowFields[i]
		if now > field.ExpireAt then
			table.remove(AbilitySystem.SlowFields, i)
		else
			field.Part.CFrame = CFrame.new(field.Position - Vector3.new(0, 0.5, 0))
			for _, hero in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
				if hero.Alive and hero.TeamId ~= field.TeamId and (hero.Root.Position - field.Position).Magnitude <= field.Radius then
					local baseSpeed = HeroConfig[hero.HeroId].walkSpeed
					hero.Humanoid.WalkSpeed = baseSpeed * field.Slow
					AbilitySystem.CombatSystem.ApplyDamage(field.OwnerHero, hero, field.Dps * 0.25, "ability")
				elseif hero.Alive then
					local baseSpeed = HeroConfig[hero.HeroId].walkSpeed
					if not hero.ActiveEffects or not hero.ActiveEffects.overcharge then
						hero.Humanoid.WalkSpeed = baseSpeed
					end
				end
			end
		end
	end

	-- Sentries
	for i = #AbilitySystem.Sentries, 1, -1 do
		local sentry = AbilitySystem.Sentries[i]
		if now > sentry.ExpireAt or not sentry.Part or not sentry.Part.Parent then
			if sentry.Part then sentry.Part:Destroy() end
			table.remove(AbilitySystem.Sentries, i)
		elseif now >= sentry.NextFireAt then
			local nearest = nil
			local bestDist = math.huge
			for _, hero in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
				if hero.Alive and hero.TeamId ~= sentry.TeamId then
					local dist = (hero.Root.Position - sentry.Part.Position).Magnitude
					if dist < bestDist and dist <= sentry.Range then
						nearest = hero
						bestDist = dist
					end
				end
			end
			if nearest then
				sentry.NextFireAt = now + sentry.FireInterval
				AbilitySystem.CombatSystem.ApplyDamage(sentry.OwnerHero, nearest, sentry.Damage)
				effectAll({effectType = "Tracer", startPosition = sentry.Part.Position, endPosition = nearest.Root.Position, color = sentry.Part.Color, duration = 0.08})
			end
		end
	end

	-- Gravity Wells
	for i = #AbilitySystem.GravityWells, 1, -1 do
		local well = AbilitySystem.GravityWells[i]
		if now > well.ExpireAt then
			table.remove(AbilitySystem.GravityWells, i)
		else
			-- Pull and damage enemies
			for _, hero in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
				if hero.Alive and hero.TeamId ~= well.OwnerHero.TeamId then
					local dist = (hero.Root.Position - well.Position).Magnitude
					if dist <= well.Radius then
						local pullDir = (well.Position - hero.Root.Position).Unit
						local pullForce = well.PullStrength / math.max(1, dist)
						if hero.Root and hero.Humanoid then
							hero.Humanoid:Move(hero.Root.Position + pullDir * pullForce * 0.5)
							AbilitySystem.CombatSystem.ApplyDamage(well.OwnerHero, hero, well.DamagePerSecond * 0.25)
						end
					end
				end
			end
			-- Visual pulse
			if math.floor(now * 4) % 2 == 0 then
				effectAll({effectType = "GravityWellPulse", position = well.Position, radius = well.Radius, color = well.Color})
			end
		end
	end

	-- Energy Shields
	for i = #AbilitySystem.EnergyShields, 1, -1 do
		local shield = AbilitySystem.EnergyShields[i]
		if now > shield.ExpireAt or shield.Health <= 0 then
			table.remove(AbilitySystem.EnergyShields, i)
		end
	end

	-- Healing Fields
	if AbilitySystem.ActiveHealingFields then
		for i = #AbilitySystem.ActiveHealingFields, 1, -1 do
			local field = AbilitySystem.ActiveHealingFields[i]
			if now > field.ExpireAt then
				if field.Part then field.Part:Destroy() end
				table.remove(AbilitySystem.ActiveHealingFields, i)
			else
				for _, hero in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
					if hero.Alive and hero.TeamId == field.TeamId
						and (hero.Root.Position - field.Position).Magnitude <= field.Radius
						and not field.Healed[hero.Guid] then
						local healAmt = math.min(field.MaxHeal, field.HealPerSecond)
						AbilitySystem.Heal(hero, healAmt * 0.25)
						if hero.Health >= hero.MaxHealth then
							field.Healed[hero.Guid] = true
						end
					end
				end
			end
		end
	end
end

function AbilitySystem.Clear()
	AbilitySystem.ActiveDomes = {}
	AbilitySystem.SlowFields = {}
	AbilitySystem.ActiveSlowFields = {}
	AbilitySystem.Sentries = {}
	AbilitySystem.GravityWells = {}
	AbilitySystem.EnergyShields = {}
	AbilitySystem.ActiveHealingFields = {}
	AbilitySystem.ActiveMines = {}
	local effects = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Effects")
	if effects then
		effects:ClearAllChildren()
	end
end

return AbilitySystem