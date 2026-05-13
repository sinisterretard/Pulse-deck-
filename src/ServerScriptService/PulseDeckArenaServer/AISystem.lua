local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))
local AbilityConfig = require(sharedRoot:WaitForChild("AbilityConfig"))
local Util = require(sharedRoot:WaitForChild("Util"))

local AISystem = {}

AISystem.Enabled = {}
AISystem.HeroSystem = nil
AISystem.MatchSystem = nil
AISystem.CombatSystem = nil
AISystem.AbilitySystem = nil
AISystem.WaypointCache = {}
AISystem.PathCache = {}
AISystem.Difficulty = "Normal"

local DIFFICULTY = {
	Easy = {accuracyBonus = 0.15, reactionBonus = 0.0, abilityChanceMult = 0.5, ultChanceMult = 0.3, pathfindRecompute = 2},
	Normal = {accuracyBonus = 0.0, reactionBonus = 0.0, abilityChanceMult = 1.0, ultChanceMult = 1.0, pathfindRecompute = 1.5},
	Hard = {accuracyBonus = -0.1, reactionBonus = -0.15, abilityChanceMult = 1.3, ultChanceMult = 1.5, pathfindRecompute = 1},
}

AISystem.AIProfiles = {
	Flanker = {
		aggressiveness = 0.8, preferCloseRange = true, strafeChance = 0.6,
		abilityUsageChance = 0.5, retreatHealthThreshold = 0.3, preferredLane = "flank",
		fireWhileMoving = true, accuracy = 0.7, reactionTime = 0.4,
	},
	Aggressive = {
		aggressiveness = 0.9, preferCloseRange = true, strafeChance = 0.4,
		abilityUsageChance = 0.5, retreatHealthThreshold = 0.2, preferredLane = "main",
		fireWhileMoving = true, accuracy = 0.6, reactionTime = 0.3,
	},
	Frontline = {
		aggressiveness = 0.6, preferCloseRange = false, strafeChance = 0.3,
		abilityUsageChance = 0.4, retreatHealthThreshold = 0.2, preferredLane = "main",
		fireWhileMoving = false, accuracy = 0.65, reactionTime = 0.5,
	},
	Backline = {
		aggressiveness = 0.4, preferCloseRange = false, strafeChance = 0.2,
		abilityUsageChance = 0.6, retreatHealthThreshold = 0.25, preferredLane = "main",
		fireWhileMoving = false, accuracy = 0.8, reactionTime = 0.6,
	},
	Support = {
		aggressiveness = 0.2, preferCloseRange = false, strafeChance = 0.3,
		abilityUsageChance = 0.8, retreatHealthThreshold = 0.4, preferredLane = "main",
		fireWhileMoving = false, accuracy = 0.6, reactionTime = 0.5,
	},
	Siege = {
		aggressiveness = 0.5, preferCloseRange = false, strafeChance = 0.2,
		abilityUsageChance = 0.7, retreatHealthThreshold = 0.25, preferredLane = "main",
		fireWhileMoving = false, accuracy = 0.75, reactionTime = 0.7,
	},
	Assassin = {
		aggressiveness = 0.9, preferCloseRange = true, strafeChance = 0.8,
		abilityUsageChance = 0.7, retreatHealthThreshold = 0.2, preferredLane = "flank",
		fireWhileMoving = true, accuracy = 0.5, reactionTime = 0.25,
	},
	Controller = {
		aggressiveness = 0.4, preferCloseRange = false, strafeChance = 0.3,
		abilityUsageChance = 0.6, retreatHealthThreshold = 0.3, preferredLane = "main",
		fireWhileMoving = false, accuracy = 0.7, reactionTime = 0.6,
	},
	Defender = {
		aggressiveness = 0.3, preferCloseRange = false, strafeChance = 0.15,
		abilityUsageChance = 0.5, retreatHealthThreshold = 0.15, preferredLane = "main",
		fireWhileMoving = false, accuracy = 0.65, reactionTime = 0.5,
	},
}

local function getLanePoints(laneName)
	if AISystem.WaypointCache[laneName] then
		return AISystem.WaypointCache[laneName]
	end
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	if not world then return {} end
	local waypointsFolder = world:FindFirstChild("Waypoints")
	if not waypointsFolder then return {} end
	local laneFolder = waypointsFolder:FindFirstChild(laneName)
	if not laneFolder then return {} end
	local points = {}
	for _, child in ipairs(laneFolder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(points, child.Position)
		end
	end
	table.sort(points, function(a, b) return a.X < b.X end)
	AISystem.WaypointCache[laneName] = points
	return points
end

local function reverseList(list)
	local out = {}
	for i = #list, 1, -1 do
		table.insert(out, list[i])
	end
	return out
end

local function getRandomPointInRadius(center, radius)
	local angle = math.random() * math.pi * 2
	local dist = math.random() * radius
	return center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
end

local function getEnemiesInRadius(hero, radius)
	local enemies = {}
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.Alive and h.TeamId ~= hero.TeamId then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d <= radius then
				table.insert(enemies, {hero = h, distance = d})
			end
		end
	end
	table.sort(enemies, function(a, b) return a.distance < b.distance end)
	return enemies
end

local function getNearbyAllies(hero, radius)
	local allies = {}
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.Alive and h.TeamId == hero.TeamId and h ~= hero then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d <= radius then
				table.insert(allies, h)
			end
		end
	end
	return allies
end

local function getNearestEnemyObjective(hero, range)
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	if not world then return nil end
	local objectivesFolder = world:FindFirstChild("Objectives")
	if not objectivesFolder then return nil end
	local best = nil
	local bestDist = math.huge
	for _, model in ipairs(objectivesFolder:GetChildren()) do
		if model:IsA("Model") and model.PrimaryPart then
			local teamId = model:GetAttribute("ObjectiveTeam")
			local destroyed = model:GetAttribute("Destroyed")
			if teamId ~= hero.TeamId and not destroyed then
				local d = (model.PrimaryPart.Position - hero.Root.Position).Magnitude
				if d < bestDist and d <= range then
					best = model
					bestDist = d
				end
			end
		end
	end
	return best
end

local function getLowestHealthEnemy(hero, range)
	local best = nil
	local bestHealth = math.huge
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.Alive and h.TeamId ~= hero.TeamId then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d <= range and h.Health < bestHealth then
				best = h
				bestHealth = h.Health
			end
		end
	end
	return best
end

local function findFleePosition(hero)
	local nearestEnemy = nil
	local nearestDist = math.huge
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.Alive and h.TeamId ~= hero.TeamId then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d < nearestDist then
				nearestDist = d
				nearestEnemy = h
			end
		end
	end
	if nearestEnemy then
		local fleeDir = (hero.Root.Position - nearestEnemy.Root.Position).Unit
		local targetPos = hero.Root.Position + fleeDir * 20
		targetPos = Vector3.new(
			math.clamp(targetPos.X, -140, 140),
			targetPos.Y,
			math.clamp(targetPos.Z, -95, 95)
		)
		return targetPos
	end
	local spawnPoints = (hero.TeamId == Config.TEAM_RED) and Config.MAP.RED_SPAWN_PADS or Config.MAP.BLUE_SPAWN_PADS
	return spawnPoints[1]
end

local function computePath(hero, targetPos)
	if not hero or not targetPos then return {} end
	local key = hero.Guid .. "_" .. math.floor(targetPos.X) .. "_" .. math.floor(targetPos.Z)
	if AISystem.PathCache[key] and os.clock() - AISystem.PathCache[key].time < (DIFFICULTY[AISystem.Difficulty].pathfindRecompute or 2) then
		return AISystem.PathCache[key].points
	end
	local pathParams = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentMaxSlope = 45,
		WaypointSpacing = 4,
		Costs = {Water = 10},
	}
	local path = PathfindingService:CreatePath(pathParams)
	local ok = pcall(function()
		path:ComputeAsync(hero.Root.Position, targetPos)
	end)
	if not ok then return {} end
	local points = path:GetWaypoints()
	AISystem.PathCache[key] = {points = points, time = os.clock()}
	if #AISystem.PathCache > 200 then AISystem.PathCache = {} end
	return points
end

local function moveToPosition(hero, targetPos, profile, allowPathfinding)
	if not hero or not hero.Humanoid then return end
	local dist = (hero.Root.Position - targetPos).Magnitude
	if dist > 10 and allowPathfinding then
		local path = computePath(hero, targetPos)
		if #path > 1 then
			hero.AIPath = path
			hero.AIPathIndex = 2
			hero.AIPathGoal = targetPos
			return
		end
	end
	hero.AIPath = nil
	hero.Humanoid:MoveTo(targetPos)
end

local function followPath(hero)
	if not hero.AIPath or #hero.AIPath == 0 then
		if hero.AIPathGoal then
			hero.Humanoid:MoveTo(hero.AIPathGoal)
		end
		return false
	end
	local idx = hero.AIPathIndex or 2
	if idx > #hero.AIPath then
		hero.AIPath = nil
		return false
	end
	local waypoint = hero.AIPath[idx]
	hero.Humanoid:MoveTo(waypoint.Position)
	if (hero.Root.Position - waypoint.Position).Magnitude < 4 then
		hero.AIPathIndex = idx + 1
	end
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		hero.Humanoid.Jump = true
	end
	return true
end

local function findCoverPosition(hero, enemy)
	local enemyPos = enemy.Root.Position
	local heroPos = hero.Root.Position
	local dirAway = (heroPos - enemyPos).Unit
	local world = workspace:FindFirstChild("PulseDeckArenaWorld")
	if not world then return nil end
	local mapFolder = world:FindFirstChild("Map")
	if not mapFolder then return nil end
	local bestCover = nil
	local bestCoverScore = -1
	for _, part in ipairs(mapFolder:GetDescendants()) do
		if part:IsA("BasePart") and part.Name:lower():find("cover") then
			local coverPos = part.Position
			local distToCover = (heroPos - coverPos).Magnitude
			local distFromEnemy = (enemyPos - coverPos).Magnitude
			if distToCover < 30 and distFromEnemy < 20 then
				local toCover = (coverPos - heroPos).Unit
				local dot = toCover:Dot(dirAway)
				if dot > 0.3 then
					local score = distFromEnemy - distToCover
					if score > bestCoverScore then
						bestCoverScore = score
						bestCover = coverPos + Vector3.new(0, 2, 0)
					end
				end
			end
		end
	end
	return bestCover
end

local function isBehindCover(hero, enemy)
	local direction = (enemy.Root.Position - hero.Root.Position).Unit
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {hero.Model, enemy.Model}
	local ray = workspace:Raycast(hero.Root.Position + Vector3.new(0, 1, 0), direction * 50, rayParams)
	if ray and ray.Instance and ray.Instance.Parent and ray.Instance.Parent.Name == "Map" then
		return true, ray.Position
	end
	return false, nil
end

local function shouldUseAbility(hero, profile)
	if not AISystem.AbilitySystem then return false end
	if os.clock() < hero.AbilityReadyAt then return false end
	local prof = AISystem.AIProfiles[profile]
	local chance = (prof and prof.abilityUsageChance or 0.4) * DIFFICULTY[AISystem.Difficulty].abilityChanceMult
	return math.random() < chance
end

local function shouldUseUltimate(hero)
	if hero.UltimateCharge < hero.UltimateChargeMax then return false end
	return math.random() < 0.3 * DIFFICULTY[AISystem.Difficulty].ultChanceMult
end

function AISystem.Init(heroSystem, matchSystem, combatSystem, abilitySystem)
	AISystem.HeroSystem = heroSystem
	AISystem.MatchSystem = matchSystem
	AISystem.CombatSystem = combatSystem
	AISystem.AbilitySystem = abilitySystem

	RunService.Heartbeat:Connect(function()
		if not AISystem.MatchSystem then return end
		local state = AISystem.MatchSystem.State
		if state ~= "ActiveMatch" and state ~= "SuddenDeath" then return end

		for hero, enabled in pairs(AISystem.Enabled) do
			if enabled and hero.Alive and not hero.IsControlled then
				if not hero.AIThinkNextTick or os.clock() >= hero.AIThinkNextTick then
					local profile = AISystem.AIProfiles[HeroConfig[hero.HeroId].aiProfile]
					local reaction = (profile and profile.reactionTime or 0.5) - DIFFICULTY[AISystem.Difficulty].reactionBonus
					hero.AIThinkNextTick = os.clock() + math.max(0.15, reaction)
					AISystem.Think(hero)
				end
			end
		end

		for _, hero in pairs(AISystem.HeroSystem.HeroesByGuid) do
			if not hero.IsControlled and hero.Alive then
				hero.LastKnownPosition = hero.Root.Position
				if hero.ActiveEffects and hero.ActiveEffects.overcharge then
					local hd = HeroConfig[hero.HeroId]
					hero.Humanoid.WalkSpeed = hd.walkSpeed * hero.ActiveEffects.overcharge.SpeedMultiplier
				end
				if hero.ActiveEffects and hero.ActiveEffects.fortify then
					hero.Humanoid.WalkSpeed = 0.01
				end
				if not followPath(hero) then
					if hero.AIPathGoal then
						local distToGoal = (hero.Root.Position - hero.AIPathGoal).Magnitude
						if distToGoal < 5 then
							hero.AIPathGoal = nil
						end
					end
				end
			end
		end
	end)

	AISystem.LastHitMemory = {}
	AISystem.Difficulty = "Normal"
end

function AISystem.EnableHeroAI(hero, enabled)
	AISystem.Enabled[hero] = enabled
	if enabled then
		hero.AILastThink = 0
		hero.AILane = nil
		hero.AIWaypointIndex = nil
		hero.AILastPos = nil
		hero.AIStuckCounter = 0
		hero.AIAttackTarget = nil
		hero.AILastSwitchCover = 0
		hero.AIStrafeDir = nil
		hero.AIPath = nil
		hero.AIPathGoal = nil
		hero.AIThinkNextTick = 0
	end
end

function AISystem.Clear()
	AISystem.Enabled = {}
	AISystem.WaypointCache = {}
	AISystem.PathCache = {}
end

function AISystem.SetDifficulty(diff)
	if DIFFICULTY[diff] then AISystem.Difficulty = diff end
end

function AISystem.FindNearestEnemy(hero, range)
	local best = nil
	local bestDist = math.huge
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.TeamId ~= hero.TeamId and h.Alive and not h.IsStealthed then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d < bestDist and d <= range then
				best = h
				bestDist = d
			end
		end
	end
	return best, bestDist
end

function AISystem.FindNearestAlly(hero)
	local best = nil
	local bestDist = math.huge
	for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
		if h.TeamId == hero.TeamId and h.Alive and h ~= hero then
			local d = (h.Root.Position - hero.Root.Position).Magnitude
			if d < bestDist then
				best = h
				bestDist = d
			end
		end
	end
	return best, bestDist
end

function AISystem.GetLaneForHero(hero)
	if hero.AILane then return hero.AILane end
	local profile = HeroConfig[hero.HeroId].aiProfile
	local prof = AISystem.AIProfiles[profile]
	if prof and prof.preferredLane == "flank" then
		hero.AILane = math.random() > 0.5 and "Lane_Upper" or "Lane_Lower"
	else
		hero.AILane = "Lane_Main"
	end
	return hero.AILane
end

function AISystem.AdvanceLane(hero)
	local laneName = AISystem.GetLaneForHero(hero)
	local points = getLanePoints(laneName)
	if #points == 0 then return end
	local ordered = points
	if hero.TeamId == Config.TEAM_BLUE then
		ordered = reverseList(points)
	end
	if not hero.AIWaypointIndex then
		hero.AIWaypointIndex = 1
	end
	local idx = hero.AIWaypointIndex
	local target = ordered[idx]
	moveToPosition(hero, target, nil, true)
	if (hero.Root.Position - target).Magnitude < 5 then
		hero.AIWaypointIndex = math.clamp(idx + 1, 1, #ordered)
	end
end

function AISystem.RetreatToBase(hero)
	local points = (hero.TeamId == Config.TEAM_RED) and Config.MAP.RED_SPAWN_PADS or Config.MAP.BLUE_SPAWN_PADS
	local nearest = points[1]
	local best = math.huge
	for _, pos in ipairs(points) do
		local d = (hero.Root.Position - pos).Magnitude
		if d < best then
			best = d
			nearest = pos
		end
	end
	local retreatPos = nearest + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
	moveToPosition(hero, retreatPos, nil, true)
end

function AISystem.SeekCover(hero, enemy)
	local coverPos = findCoverPosition(hero, enemy)
	if coverPos then
		moveToPosition(hero, coverPos, nil, true)
		return true
	end
	return false
end

function AISystem.StrafeCombat(hero, enemy)
	local dirToEnemy = (hero.Root.Position - enemy.Root.Position).Unit
	local perp = Vector3.new(-dirToEnemy.Z, 0, dirToEnemy.X)
	if not hero.AIStrafeDir or math.random() < 0.05 then
		hero.AIStrafeDir = math.random() > 0.5 and 1 or -1
	end
	local strafeTarget = hero.Root.Position + perp * hero.AIStrafeDir * 8 + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
	strafeTarget = Vector3.new(
		math.clamp(strafeTarget.X, -135, 135),
		strafeTarget.Y,
		math.clamp(strafeTarget.Z, -92, 92)
	)
	hero.Humanoid:MoveTo(strafeTarget)
end

function AISystem.Think(hero)
	if not hero.Alive then return end

	local heroDef = HeroConfig[hero.HeroId]
	local profile = heroDef.aiProfile
	local aiProfile = AISystem.AIProfiles[profile]
	local diff = DIFFICULTY[AISystem.Difficulty]
	local aggressiveness = aiProfile and aiProfile.aggressiveness or 0.5
	local accuracy = (aiProfile and aiProfile.accuracy or 0.5) + (diff.accuracyBonus or 0)

	local weapon = WeaponConfig[hero.WeaponId]
	local range = weapon and weapon.range or 100

	local healthPercent = hero.Health / hero.MaxHealth

	if healthPercent < (aiProfile and aiProfile.retreatHealthThreshold or 0.25) then
		if shouldUseAbility(hero, profile) and hero.AbilityId then
			local cfg = AbilityConfig[hero.AbilityId]
			if cfg and (cfg.kind == "DefensiveDeployable" or cfg.kind == "DefensiveSelf") then
				AISystem.AbilitySystem.UseAbility(hero, {direction = hero.Root.CFrame.LookVector})
			end
		end
		if math.random() < aggressiveness * 0.5 and aiProfile and aiProfile.strafeChance > 0.5 then
			local nearEnemy = AISystem.FindNearestEnemy(hero, 100)
			if nearEnemy then AISystem.StrafeCombat(hero, nearEnemy) end
		else
			AISystem.RetreatToBase(hero)
		end
		return
	end

	if profile == "Support" then
		local allies = getNearbyAllies(hero, 25)
		local needsHeal = false
		for _, ally in ipairs(allies) do
			if ally.Health / ally.MaxHealth < 0.6 then needsHeal = true; break end
		end
		if needsHeal and shouldUseAbility(hero, profile) then
			AISystem.AbilitySystem.UseAbility(hero, {direction = hero.Root.CFrame.LookVector})
			hero.Humanoid:MoveTo(hero.Root.Position)
			return
		end
		local nearestLowAlly = nil
		local bestDist = math.huge
		for _, ally in ipairs(allies) do
			if ally.Health / ally.MaxHealth < 0.75 then
				local d = (ally.Root.Position - hero.Root.Position).Magnitude
				if d < bestDist then bestDist = d; nearestLowAlly = ally end
			end
		end
		if nearestLowAlly and bestDist > 8 then
			moveToPosition(hero, nearestLowAlly.Root.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)), aiProfile, true)
			return
		end
	end

	if shouldUseUltimate(hero) then
		local nearestEnemy = AISystem.FindNearestEnemy(hero, range)
		if nearestEnemy then AISystem.AbilitySystem.UseUltimate(hero) end
	end

	if shouldUseAbility(hero, profile) then
		local nearestEnemy = AISystem.FindNearestEnemy(hero, range)
		if nearestEnemy and hero.AbilityId then
			local cfg = AbilityConfig[hero.AbilityId]
			if cfg then
				if cfg.kind == "Teleport" then
					local dir = (hero.Root.Position - nearestEnemy.Root.Position).Unit
					AISystem.AbilitySystem.UseAbility(hero, {direction = dir})
				elseif cfg.kind == "Mobility" and aiProfile and aiProfile.preferCloseRange then
					local dist = (hero.Root.Position - nearestEnemy.Root.Position).Magnitude
					if dist > 15 then
						AISystem.AbilitySystem.UseAbility(hero, {direction = (nearestEnemy.Root.Position - hero.Root.Position).Unit})
					end
				elseif cfg.kind == "AreaBurst" then
					local enemies = getEnemiesInRadius(hero, 15)
					if #enemies >= 2 then
						AISystem.AbilitySystem.UseAbility(hero, {direction = hero.Root.CFrame.LookVector})
					end
				elseif cfg.kind == "DefensiveDeployable" or cfg.kind == "DefensiveSelf" then
					if healthPercent < 0.5 then
						AISystem.AbilitySystem.UseAbility(hero, {direction = hero.Root.CFrame.LookVector})
					end
				else
					AISystem.AbilitySystem.UseAbility(hero, {direction = (nearestEnemy.Root.Position - hero.Root.Position).Unit})
				end
			end
		elseif hero.AbilityId and math.random() < 0.2 then
			local objective = getNearestEnemyObjective(hero, 50)
			if objective then
				AISystem.AbilitySystem.UseAbility(hero, {direction = hero.Root.CFrame.LookVector})
			end
		end
	end

	local target, targetDist = AISystem.FindNearestEnemy(hero, range * 1.2)

	if target then
		local hasCover = isBehindCover(hero, target)

		if targetDist > (range * 0.8) then
			local moveTarget = (aiProfile and aiProfile.preferCloseRange)
				and target.Root.Position + (hero.Root.Position - target.Root.Position).Unit * 5
				or hero.Root.Position + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
			hero.Humanoid:MoveTo(moveTarget)
		elseif targetDist < 8 and aiProfile and aiProfile.preferCloseRange then
			AISystem.StrafeCombat(hero, target)
		elseif hasCover and targetDist > 10 then
			local coverPos = findCoverPosition(hero, target)
			if coverPos then moveToPosition(hero, coverPos, aiProfile, true) end
		elseif math.random() < (aiProfile and aiProfile.strafeChance or 0.3) and targetDist < 30 then
			AISystem.StrafeCombat(hero, target)
		else
			hero.Humanoid:MoveTo(hero.Root.Position + Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)))
		end

		local aimDir = (target.Root.Position - hero.Root.Position).Unit
		local aimSpread = Vector3.new(
			(math.random() - 0.5) * (1 - accuracy) * 4,
			(math.random() - 0.5) * (1 - accuracy) * 4,
			(math.random() - 0.5) * (1 - accuracy) * 4
		)
		local fireDir = (aimDir + aimSpread).Unit
		AISystem.CombatSystem.FireWeapon(hero, fireDir)
		hero.AIAttackTarget = target.Guid
	else
		hero.AIAttackTarget = nil
		local objective = getNearestEnemyObjective(hero, 80)
		if objective and math.random() < aggressiveness then
			local objectivePos = objective.PrimaryPart.Position
			local targetPos = objectivePos + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
			moveToPosition(hero, targetPos, aiProfile, true)
			local dist = (hero.Root.Position - objectivePos).Magnitude
			if dist < range then
				local dir = (objectivePos - hero.Root.Position).Unit
				AISystem.CombatSystem.FireWeapon(hero, dir)
			end
		else
			AISystem.AdvanceLane(hero)
		end
	end

	if profile == "Defender" or (profile == "Frontline" and math.random() < 0.3) then
		local myGens = (hero.TeamId == Config.TEAM_RED) and Config.MAP.RED_GENERATORS or Config.MAP.BLUE_GENERATORS
		if myGens then
			for _, genPos in ipairs(myGens) do
				local dist = (hero.Root.Position - genPos).Magnitude
				if dist > 20 and dist < 40 and math.random() < 0.3 then
					moveToPosition(hero, genPos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)), aiProfile, true)
					break
				end
			end
		end
	end
end

return AISystem
