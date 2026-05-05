--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local AbilityConfig = require(sharedRoot:WaitForChild("AbilityConfig"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))

local AbilitySystem = {}

AbilitySystem.HeroSystem = nil
AbilitySystem.MatchSystem = nil
AbilitySystem.CombatSystem = nil
AbilitySystem.ActiveDomes = {}
AbilitySystem.SlowFields = {}
AbilitySystem.Sentries = {}

local function getEffectsFolder(): Folder
    return workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Effects") :: Folder
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

local function makeSphere(name: string, position: Vector3, radius: number, color: Color3, duration: number)
    local part = Instance.new("Part")
    part.Name = name
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
    part.Position = position
    part.Color = color
    part.Material = Enum.Material.ForceField
    part.Transparency = 0.45
    part.Anchored = true
    part.CanCollide = false
    part.Parent = getEffectsFolder()
    task.delay(duration, function()
        if part then
            part:Destroy()
        end
    end)
    return part
end

function AbilitySystem.Init(heroSystem, matchSystem, combatSystem)
    AbilitySystem.HeroSystem = heroSystem
    AbilitySystem.MatchSystem = matchSystem
    AbilitySystem.CombatSystem = combatSystem

    task.spawn(function()
        while true do
            task.wait(0.25)
            AbilitySystem.UpdateTimedAbilities()
        end
    end)
end

function AbilitySystem.Clear()
    AbilitySystem.ActiveDomes = {}
    AbilitySystem.SlowFields = {}
    AbilitySystem.Sentries = {}
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
    return best
end

function AbilitySystem.IsMarked(targetHero, attackerHero)
    return targetHero.MarkedUntil and os.clock() < targetHero.MarkedUntil and attackerHero.HeroId == "vesper_scope" and targetHero.MarkedByOwnerId == attackerHero.OwnerId
end

function AbilitySystem.Heal(hero, amount: number)
    hero.Health = math.min(hero.MaxHealth, hero.Health + amount)
    hero.Humanoid.Health = hero.Health
end

function AbilitySystem.DamageRadius(ownerHero, position: Vector3, radius: number, damage: number, objectiveMultiplier: number?)
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
    if not cfg or not hero.Alive then
        return
    end
    local now = os.clock()
    if now < hero.AbilityReadyAt then
        return
    end

    local dir = safeDirection(hero, payload)

    if cfg.id == "phase_dash" then
        local start = hero.Root.Position
        local goal = start + dir * cfg.dashDistance
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {hero.Model}
        local hit = workspace:Raycast(start, goal - start, params)
        if hit then
            goal = hit.Position - dir * 2
        end
        hero.InvulnerableUntil = now + cfg.invulnerabilitySeconds
        hero.Model:PivotTo(CFrame.new(goal, goal + dir))
        effectAll({effectType = "Blink", position = start, endPosition = goal, duration = 0.25})
    elseif cfg.id == "shield_dome" then
        local color = hero.TeamId == "Red" and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(60, 200, 255)
        local part = makeSphere("ShieldDome", hero.Root.Position, cfg.radius, color, cfg.duration)
        table.insert(AbilitySystem.ActiveDomes, {
            Part = part,
            Position = hero.Root.Position,
            Radius = cfg.radius,
            Reduction = cfg.damageReduction,
            Health = cfg.domeHealth,
            TeamId = hero.TeamId,
            ExpireAt = now + cfg.duration,
        })
        effectAll({effectType = "ShieldDome", position = hero.Root.Position, radius = cfg.radius, duration = cfg.duration})
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
                effectAll({effectType = "TrackerMark", position = target.Root.Position, duration = cfg.duration})
            end
        end
    elseif cfg.id == "heal_pulse" then
        for _, target in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
            if target.Alive and (target.Root.Position - hero.Root.Position).Magnitude <= cfg.radius then
                if target.TeamId == hero.TeamId then
                    AbilitySystem.Heal(target, cfg.allyHeal)
                else
                    AbilitySystem.CombatSystem.ApplyDamage(hero, target, cfg.enemyDamage)
                end
            end
        end
        effectAll({effectType = "HealRing", position = hero.Root.Position, radius = cfg.radius, duration = 0.7})
    elseif cfg.id == "cluster_charge" then
        local explodeAt = hero.Root.Position + dir * 28
        task.delay(cfg.fuseSeconds, function()
            if hero.Alive then
                AbilitySystem.DamageRadius(hero, explodeAt, cfg.mainRadius, cfg.mainDamage, cfg.objectiveMultiplier)
                effectAll({effectType = "Explosion", position = explodeAt, radius = cfg.mainRadius, duration = 0.4})
                for i = 1, cfg.miniCount do
                    local miniPos = explodeAt + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
                    AbilitySystem.DamageRadius(hero, miniPos, cfg.miniRadius, cfg.miniDamage, cfg.objectiveMultiplier)
                    effectAll({effectType = "Explosion", position = miniPos, radius = cfg.miniRadius, duration = 0.25})
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
        local decoy = Instance.new("Part")
        decoy.Name = "BlinkDecoy"
        decoy.Size = Vector3.new(2, 4, 1)
        decoy.Position = start
        decoy.Color = Color3.fromRGB(255, 45, 210)
        decoy.Material = Enum.Material.Neon
        decoy.Transparency = 0.5
        decoy.Anchored = true
        decoy.CanCollide = false
        decoy.Parent = getEffectsFolder()
        task.delay(cfg.decoyDuration, function() decoy:Destroy() end)
        effectAll({effectType = "Blink", position = start, endPosition = goal, duration = 0.25})
    elseif cfg.id == "mini_sentry" then
        if hero.Sentry and hero.Sentry.Part then
            hero.Sentry.Part:Destroy()
        end
        local sentry = Instance.new("Part")
        sentry.Name = "MiniSentry"
        sentry.Size = Vector3.new(2, 2, 2)
        sentry.Position = hero.Root.Position + dir * 4
        sentry.Color = Color3.fromRGB(35, 180, 170)
        sentry.Material = Enum.Material.Metal
        sentry.Anchored = true
        sentry.Parent = getEffectsFolder()
        local data = {Part = sentry, OwnerHero = hero, TeamId = hero.TeamId, ExpireAt = now + cfg.duration, NextFireAt = 0, Range = cfg.range, Damage = cfg.damage, FireInterval = cfg.fireInterval}
        hero.Sentry = data
        table.insert(AbilitySystem.Sentries, data)
    elseif cfg.id == "slow_field" then
        local position = hero.Root.Position + dir * math.min(cfg.targetRange, 40)
        local field = Instance.new("Part")
        field.Name = "SlowField"
        field.Shape = Enum.PartType.Cylinder
        field.Size = Vector3.new(cfg.radius * 2, 1, cfg.radius * 2)
        field.Position = position
        field.Color = Color3.fromRGB(80, 220, 255)
        field.Material = Enum.Material.Neon
        field.Transparency = 0.45
        field.Anchored = true
        field.CanCollide = false
        field.Parent = getEffectsFolder()
        task.delay(cfg.duration, function() field:Destroy() end)
        table.insert(AbilitySystem.SlowFields, {Part = field, OwnerHero = hero, TeamId = hero.TeamId, Position = position, Radius = cfg.radius, ExpireAt = now + cfg.duration, Slow = cfg.enemySlowMultiplier, Dps = cfg.damagePerSecond})
        effectAll({effectType = "SlowField", position = position, radius = cfg.radius, duration = cfg.duration})
    end

    hero.AbilityReadyAt = now + cfg.cooldown
end

function AbilitySystem.UpdateTimedAbilities()
    local now = os.clock()

    for i = #AbilitySystem.ActiveDomes, 1, -1 do
        local dome = AbilitySystem.ActiveDomes[i]
        if now > dome.ExpireAt or dome.Health <= 0 then
            if dome.Part then dome.Part:Destroy() end
            table.remove(AbilitySystem.ActiveDomes, i)
        end
    end

    for i = #AbilitySystem.SlowFields, 1, -1 do
        local field = AbilitySystem.SlowFields[i]
        if now > field.ExpireAt then
            table.remove(AbilitySystem.SlowFields, i)
        else
            for _, hero in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
                if hero.Alive and hero.TeamId ~= field.TeamId and (hero.Root.Position - field.Position).Magnitude <= field.Radius then
                    hero.Humanoid.WalkSpeed = HeroConfig[hero.HeroId].walkSpeed * field.Slow
                    AbilitySystem.CombatSystem.ApplyDamage(field.OwnerHero, hero, field.Dps * 0.25)
                elseif hero.Alive then
                    hero.Humanoid.WalkSpeed = HeroConfig[hero.HeroId].walkSpeed
                end
            end
        end
    end

    for i = #AbilitySystem.Sentries, 1, -1 do
        local sentry = AbilitySystem.Sentries[i]
        if now > sentry.ExpireAt or not sentry.Part or not sentry.Part.Parent then
            if sentry.Part then sentry.Part:Destroy() end
            table.remove(AbilitySystem.Sentries, i)
        elseif now >= sentry.NextFireAt then
            local nearest = nil
            local best = math.huge
            for _, hero in pairs(AbilitySystem.HeroSystem.HeroesByGuid) do
                if hero.Alive and hero.TeamId ~= sentry.TeamId then
                    local dist = (hero.Root.Position - sentry.Part.Position).Magnitude
                    if dist < best and dist <= sentry.Range then
                        nearest = hero
                        best = dist
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
end

return AbilitySystem
