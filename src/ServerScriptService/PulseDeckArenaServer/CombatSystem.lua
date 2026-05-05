--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))

local CombatSystem = {}

local WeaponConfig = require(sharedRoot:WaitForChild("WeaponConfig"))
local Util = require(sharedRoot:WaitForChild("Util"))

CombatSystem.Objectives = {}

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

local function fireDamageNumber(player: Player?, payload)
    if not player then return end
    local remotes = getRemotes()
    local event = remotes and remotes:FindFirstChild("DamageNumberEvent")
    if event and event:IsA("RemoteEvent") then
        event:FireClient(player, payload)
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

function CombatSystem.Init()
    CombatSystem.Objectives = {}
end

function CombatSystem.CreateObjective(name: string, teamId: string, health: number, position: Vector3)
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

    model.PrimaryPart = core
    model.Parent = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Objectives")
    model:SetAttribute("ObjectiveTeam", teamId)
    model:SetAttribute("ObjectiveType", name)

    CombatSystem.Objectives[model] = {
        TeamId = teamId,
        Name = name,
        Health = health,
        MaxHealth = health,
    }

    return model
end

function CombatSystem.RegisterObjective(model: Model, teamId: string, health: number, objectiveType: string)
    CombatSystem.Objectives[model] = {
        TeamId = teamId,
        Name = objectiveType,
        Health = health,
        MaxHealth = health,
    }
    model:SetAttribute("Health", health)
    model:SetAttribute("MaxHealth", health)
    model:SetAttribute("ObjectiveTeam", teamId)
    model:SetAttribute("ObjectiveType", objectiveType)
end

function CombatSystem.DamageObjective(model: Model, amount: number, teamId: string)
    local obj = CombatSystem.Objectives[model]
    if not obj then return end
    if teamId == obj.TeamId then
        return
    end

    local adjusted = amount
    if obj.Name == "Core" then
        local gens = 0
        for _, data in pairs(CombatSystem.Objectives) do
            if data.TeamId == obj.TeamId and data.Name == "Generator" and data.Health > 0 then
                gens += 1
            end
        end
        if gens == 2 then
            adjusted = adjusted * 0.5
        elseif gens == 1 then
            adjusted = adjusted * 0.75
        end
        local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))
        MatchSystem.RecordCoreDamage(teamId, adjusted)
    end

    obj.Health = math.max(0, obj.Health - adjusted)
    model:SetAttribute("Health", obj.Health)
    local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))
    MatchSystem.AddScore(teamId, adjusted)
    if obj.Health == 0 then
        model:SetAttribute("Destroyed", true)
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

function CombatSystem.GetObjectiveFromPart(part: Instance?)
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
    return hero.Root.Position + Vector3.new(0, 1.5, 0)
end

local function canFire(hero, weapon)
    if not hero.Alive then return false end
    if hero.IsReloading then return false end
    if hero.Ammo <= 0 then return false end
    if os.clock() < hero.NextFireAt then return false end
    return true
end

function CombatSystem.RequestReload(hero)
    if not hero or hero.IsReloading then return end
    local weapon = WeaponConfig[hero.WeaponId]
    if hero.Ammo >= weapon.magazineSize then return end
    if hero.ReserveAmmo <= 0 then return end
    hero.IsReloading = true
    hero.ReloadEndAt = os.clock() + weapon.reloadTime
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
    end)
end

function CombatSystem.ApplyDamage(attacker, target, amount: number)
    if not attacker or not target then return end
    if not target.Alive then return end
    if attacker.TeamId == target.TeamId then return end
    if target.InvulnerableUntil and os.clock() < target.InvulnerableUntil then return end

    local ok, AbilitySystem = pcall(function()
        return require(script.Parent:WaitForChild("AbilitySystem"))
    end)
    if ok and AbilitySystem then
        amount *= (1 - AbilitySystem.GetDamageReduction(target))
        if AbilitySystem.IsMarked(target, attacker) then
            amount *= 1.15
        end
    end

    target.Health = math.max(0, target.Health - amount)
    target.Humanoid.Health = target.Health
    local MatchSystem = require(script.Parent:WaitForChild("MatchSystem"))
    MatchSystem.AddScore(attacker.TeamId, amount)
    fireDamageNumber(attacker.OwnerPlayer, {
        amount = math.floor(amount),
        position = target.Root.Position,
        isHealing = false,
        isCritical = false,
    })
    if target.Health <= 0 then
        local HeroSystem = require(script.Parent:WaitForChild("HeroSystem"))
        HeroSystem.KillHero(target)
        local remotes = getRemotes()
        local killfeed = remotes and remotes:FindFirstChild("KillfeedEvent")
        if killfeed and killfeed:IsA("RemoteEvent") then
            killfeed:FireAllClients({
                killerName = tostring(attacker.OwnerId),
                victimName = target.Model.Name,
                teamId = attacker.TeamId,
            })
        end
    end
end

function CombatSystem.FireWeapon(hero, direction: Vector3)
    local weapon = WeaponConfig[hero.WeaponId]
    if not canFire(hero, weapon) then
        if hero.Ammo <= 0 then
            CombatSystem.RequestReload(hero)
        end
        return
    end

    local ammoCost = 1
    if weapon.behavior == "Beam" then
        ammoCost = weapon.ammoDrainPerSecond * weapon.tickInterval
    end
    hero.Ammo = math.max(0, hero.Ammo - ammoCost)
    hero.NextFireAt = os.clock() + (weapon.fireInterval or weapon.tickInterval or 0.1)

    local origin = getFireOrigin(hero)
    local spreadDir = Util.RandomVectorInCone(direction.Unit, weapon.spreadDegrees or 0)
    local params = buildRayParams(hero)

    if weapon.behavior == "ProjectileExplosive" then
        local range = weapon.range or ((weapon.projectileSpeed or 175) * (weapon.rangeLifetime or 3))
        local ray = workspace:Raycast(origin, spreadDir * range, params)
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
        fireEffect({
            effectType = "Explosion",
            position = ray and ray.Position or (origin + spreadDir * range),
            radius = weapon.splashRadius or 12,
            duration = 0.4,
        })
        return
    end

    if weapon.behavior == "Shotgun" then
        for _ = 1, weapon.pellets do
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
                duration = 0.08,
            })
        end
        return
    end

    if weapon.behavior == "BurstHitscan" then
        task.spawn(function()
            for _ = 1, weapon.burstCount do
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
                    duration = 0.08,
                })
                task.wait(weapon.burstInterval)
            end
        end)
        return
    end

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
                CombatSystem.ApplyDamage(hero, hitHero, dmg)
            end
        end
    end
    fireEffect({
        effectType = weapon.behavior == "Beam" and "Beam" or "Tracer",
        startPosition = origin,
        endPosition = ray and ray.Position or (origin + spreadDir * range),
        color = weapon.tracerColor,
        duration = 0.08,
    })
end

return CombatSystem
