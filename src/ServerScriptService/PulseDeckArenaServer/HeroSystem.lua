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

local function createRig(heroId: string, teamId: string, ownerId: any, guid: string): Model
    local heroDef = HeroConfig[heroId]
    local model = Instance.new("Model")
    model.Name = heroDef.displayName .. "_" .. guid

    local humanoid = Instance.new("Humanoid")
    humanoid.WalkSpeed = heroDef.walkSpeed
    humanoid.JumpPower = heroDef.jumpPower
    humanoid.Parent = model

    local function part(name, size, color)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.Color = color
        p.Material = Enum.Material.SmoothPlastic
        p.Anchored = false
        p.CanCollide = true
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = model
        return p
    end

    local teamColor = (teamId == Config.TEAM_RED) and Config.RED_COLOR or Config.BLUE_COLOR

    local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), teamColor)
    root.Transparency = 1
    root.CanCollide = false
    local torso = part("Torso", Vector3.new(2, 2, 1), teamColor)
    local head = part("Head", Vector3.new(2, 1, 1), teamColor)
    local ra = part("Right Arm", Vector3.new(1, 2, 1), teamColor)
    local la = part("Left Arm", Vector3.new(1, 2, 1), teamColor)
    local rl = part("Right Leg", Vector3.new(1, 2, 1), teamColor)
    local ll = part("Left Leg", Vector3.new(1, 2, 1), teamColor)

    root.CFrame = CFrame.new(0, 3, 0)
    torso.CFrame = root.CFrame
    head.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
    ra.CFrame = root.CFrame * CFrame.new(1.5, 0.5, 0)
    la.CFrame = root.CFrame * CFrame.new(-1.5, 0.5, 0)
    rl.CFrame = root.CFrame * CFrame.new(0.5, -1.5, 0)
    ll.CFrame = root.CFrame * CFrame.new(-0.5, -1.5, 0)

    local function weld(part0, part1, c0, name)
        local m6d = Instance.new("Motor6D")
        m6d.Part0 = part0
        m6d.Part1 = part1
        m6d.C0 = c0
        m6d.Name = name
        m6d.Parent = part0
    end

    weld(root, torso, CFrame.new(), "RootJoint")
    weld(torso, head, CFrame.new(0, 1.5, 0), "Neck")
    weld(torso, ra, CFrame.new(1.5, 0.5, 0), "RightShoulder")
    weld(torso, la, CFrame.new(-1.5, 0.5, 0), "LeftShoulder")
    weld(torso, rl, CFrame.new(0.5, -1.5, 0), "RightHip")
    weld(torso, ll, CFrame.new(-0.5, -1.5, 0), "LeftHip")

    local accent = Instance.new("Part")
    accent.Name = "Accent"
    accent.Size = Vector3.new(2.2, 1.2, 1.2)
    accent.Color = heroDef.primaryColor
    accent.Material = Enum.Material.Neon
    accent.Anchored = false
    accent.CanCollide = false
    accent.Parent = model
    weld(torso, accent, CFrame.new(0, 0.2, -0.1), "AccentWeld")

    local weapon = Instance.new("Part")
    weapon.Name = "Weapon"
    weapon.Size = Vector3.new(1.2, 0.3, 2.2)
    weapon.Color = heroDef.secondaryColor
    weapon.Material = Enum.Material.Metal
    weapon.Anchored = false
    weapon.CanCollide = false
    weapon.Parent = model
    weld(ra, weapon, CFrame.new(0, -0.6, -0.6) * CFrame.Angles(0, math.rad(90), 0), "WeaponWeld")

    local healthGui = Instance.new("BillboardGui")
    healthGui.Name = "HealthBar"
    healthGui.Size = UDim2.new(0, 90, 0, 10)
    healthGui.StudsOffset = Vector3.new(0, 2.5, 0)
    healthGui.AlwaysOnTop = true
    healthGui.Parent = head

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bg.BorderSizePixel = 0
    bg.Parent = healthGui

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = teamColor
    fill.BorderSizePixel = 0
    fill.Parent = bg

    model.PrimaryPart = root
    model:SetAttribute("HeroGuid", guid)
    model:SetAttribute("HeroId", heroId)
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

function HeroSystem.GetHeroFromPart(part: Instance?)
    if not part then return nil end
    local guid = HeroSystem.PartToHero[part]
    if guid then
        return HeroSystem.HeroesByGuid[guid]
    end
    return nil
end

function HeroSystem.GetControlledHero(player: Player)
    local guid = HeroSystem.ControlledHero[player.UserId]
    if not guid then
        return nil
    end
    return HeroSystem.HeroesByGuid[guid]
end

function HeroSystem.SpawnHeroesForOwner(ownerId: any, teamId: string, deck: {string}, ownerPlayer: Player?)
    local list = {}
    HeroSystem.HeroesByOwner[ownerId] = list
    for slot, heroId in ipairs(deck) do
        local guid = HttpService:GenerateGUID(false)
        local model = createRig(heroId, teamId, ownerId, guid)
        model.Parent = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Heroes")

        local spawnList = (teamId == Config.TEAM_RED) and Config.MAP.RED_SPAWN_PADS or Config.MAP.BLUE_SPAWN_PADS
        local spawnPos = spawnList[slot % #spawnList + 1]
        model:PivotTo(CFrame.new(spawnPos + Vector3.new(math.random(-3,3), 0, math.random(-3,3))))

        local weaponId = HeroConfig[heroId].weaponId
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
            Health = HeroConfig[heroId].maxHealth,
            MaxHealth = HeroConfig[heroId].maxHealth,
            WeaponId = weaponId,
            AbilityId = HeroConfig[heroId].abilityId,
            Ammo = weapon.magazineSize,
            ReserveAmmo = weapon.magazineSize * 3,
            IsReloading = false,
            ReloadEndAt = 0,
            AbilityReadyAt = 0,
            NextFireAt = 0,
            LastSwitchAt = 0,
            InvulnerableUntil = 0,
            MarkedUntil = 0,
            MarkedByOwnerId = nil,
            Sentry = nil,
        }

        HeroSystem.HeroesByGuid[guid] = hero
        table.insert(list, hero)

        if ownerPlayer and slot == 1 then
            HeroSystem.AssignControl(ownerPlayer, hero)
        end
    end
end

function HeroSystem.AssignControl(player: Player, hero)
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

function HeroSystem.SwitchHero(player: Player, slot: number)
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

function HeroSystem.KillHero(hero)
    if not hero.Alive then return end
    hero.Alive = false
    hero.IsControlled = false
    hero.Model:SetAttribute("Alive", false)
    hero.Humanoid.Health = 0
    if hero.Sentry and hero.Sentry.Part then
        hero.Sentry.Part:Destroy()
        hero.Sentry = nil
    end
    hero.Model:PivotTo(CFrame.new(0, -500, 0))
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
    hero.Model:SetAttribute("Alive", true)
    hero.Humanoid.MaxHealth = hero.MaxHealth
    hero.Humanoid.Health = hero.MaxHealth
    local weapon = WeaponConfig[hero.WeaponId]
    hero.Ammo = weapon.magazineSize
    hero.ReserveAmmo = weapon.magazineSize * 3
    hero.IsReloading = false
    hero.ReloadEndAt = 0
    hero.AbilityReadyAt = os.clock()
    hero.InvulnerableUntil = os.clock() + 1.25
    local spawnList = (hero.TeamId == Config.TEAM_RED) and Config.MAP.RED_SPAWN_PADS or Config.MAP.BLUE_SPAWN_PADS
    hero.Model:PivotTo(CFrame.new(spawnList[1]))
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
            alive = hero.Alive,
            ammo = hero.Ammo,
            reserveAmmo = hero.ReserveAmmo,
            isReloading = hero.IsReloading,
            abilityCooldownRemaining = math.max(0, hero.AbilityReadyAt - os.clock()),
            isControlled = hero.IsControlled,
            position = hero.Root.Position,
        }
    end
    return snapshot
end

function HeroSystem.RemoveOwner(ownerId: any)
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
