--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))
local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))

local AISystem = {}

AISystem.Enabled = {}
AISystem.HeroSystem = nil
AISystem.MatchSystem = nil
AISystem.CombatSystem = nil
AISystem.AbilitySystem = nil
AISystem.WaypointCache = {}

local function getLanePoints(laneName: string)
    if AISystem.WaypointCache[laneName] then
        return AISystem.WaypointCache[laneName]
    end
    local waypointsFolder = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Waypoints")
    local laneFolder = waypointsFolder:FindFirstChild(laneName)
    local points = {}
    if laneFolder then
        for _, child in ipairs(laneFolder:GetChildren()) do
            if child:IsA("BasePart") then
                table.insert(points, child.Position)
            end
        end
        table.sort(points, function(a, b)
            return a.X < b.X
        end)
    end
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

function AISystem.Init(heroSystem, matchSystem, combatSystem, abilitySystem)
    AISystem.HeroSystem = heroSystem
    AISystem.MatchSystem = matchSystem
    AISystem.CombatSystem = combatSystem
    AISystem.AbilitySystem = abilitySystem
    RunService.Heartbeat:Connect(function()
        if not AISystem.MatchSystem then return end
        local state = AISystem.MatchSystem.State
        if state ~= "ActiveMatch" and state ~= "SuddenDeath" then
            return
        end
        for hero, enabled in pairs(AISystem.Enabled) do
            if enabled and hero.Alive and not hero.IsControlled then
                AISystem.Think(hero)
            end
        end
    end)
end

function AISystem.EnableHeroAI(hero, enabled: boolean)
    AISystem.Enabled[hero] = enabled
end

function AISystem.Clear()
    AISystem.Enabled = {}
    AISystem.WaypointCache = {}
end

function AISystem.FindNearestEnemy(hero, range: number)
    local best = nil
    local bestDist = math.huge
    for _, h in pairs(AISystem.HeroSystem.HeroesByGuid) do
        if h.TeamId ~= hero.TeamId and h.Alive then
            local d = (h.Root.Position - hero.Root.Position).Magnitude
            if d < bestDist and d <= range then
                best = h
                bestDist = d
            end
        end
    end
    return best
end

function AISystem.FindNearestEnemyObjective(hero, range: number)
    local objectivesFolder = workspace:FindFirstChild("PulseDeckArenaWorld") and workspace.PulseDeckArenaWorld:FindFirstChild("Objectives")
    if not objectivesFolder then return nil end
    local best = nil
    local bestDist = math.huge
    for _, objective in ipairs(objectivesFolder:GetChildren()) do
        if objective:IsA("Model") and objective.PrimaryPart then
            local teamId = objective:GetAttribute("ObjectiveTeam")
            local destroyed = objective:GetAttribute("Destroyed")
            if teamId ~= hero.TeamId and not destroyed then
                local d = (objective.PrimaryPart.Position - hero.Root.Position).Magnitude
                if d < bestDist and d <= range then
                    best = objective
                    bestDist = d
                end
            end
        end
    end
    return best
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
    return best
end

function AISystem.GetLaneForHero(hero)
    if hero.AILane then
        return hero.AILane
    end
    local profile = HeroConfig[hero.HeroId].aiProfile
    if profile == "Flanker" or profile == "Assassin" then
        hero.AILane = (math.random() > 0.5) and "Lane_Upper" or "Lane_Lower"
    elseif profile == "Backline" then
        hero.AILane = "Lane_Main"
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
    hero.Humanoid:MoveTo(target)

    if (hero.Root.Position - target).Magnitude < 6 then
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
    hero.Humanoid:MoveTo(nearest)
end

function AISystem.Think(hero)
    if hero.AILastThink and (os.clock() - hero.AILastThink) < 0.25 then
        return
    end
    hero.AILastThink = os.clock()

    if hero.Health / hero.MaxHealth < 0.3 then
        AISystem.RetreatToBase(hero)
        return
    end

    local weapon = WeaponConfig[hero.WeaponId]
    local range = weapon.range or 150

    local profile = HeroConfig[hero.HeroId].aiProfile
    if profile == "Support" then
        local ally = AISystem.FindNearestAlly(hero)
        if ally then
            hero.Humanoid:MoveTo(ally.Root.Position)
        end
    end

    local target = AISystem.FindNearestEnemy(hero, range)
    if target then
        local dir = (target.Root.Position - hero.Root.Position)
        AISystem.CombatSystem.FireWeapon(hero, dir)
        if AISystem.AbilitySystem and os.clock() >= hero.AbilityReadyAt then
            AISystem.AbilitySystem.UseAbility(hero, {direction = dir.Unit})
        end
        hero.Humanoid:MoveTo(target.Root.Position)
        return
    end

    local objective = AISystem.FindNearestEnemyObjective(hero, range)
    if objective and objective.PrimaryPart then
        local dir = objective.PrimaryPart.Position - hero.Root.Position
        AISystem.CombatSystem.FireWeapon(hero, dir)
        if AISystem.AbilitySystem and os.clock() >= hero.AbilityReadyAt then
            AISystem.AbilitySystem.UseAbility(hero, {direction = dir.Unit})
        end
        hero.Humanoid:MoveTo(objective.PrimaryPart.Position)
        return
    end

    AISystem.AdvanceLane(hero)
end

return AISystem
