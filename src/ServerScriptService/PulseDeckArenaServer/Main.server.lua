--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))

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
    for _, name in ipairs({"Map", "Heroes", "Objectives", "Pickups", "Projectiles", "Effects", "Waypoints"}) do
        if not world:FindFirstChild(name) then
            local f = Instance.new("Folder")
            f.Name = name
            f.Parent = world
        end
    end
end

ensureWorld()
MapBuilder.BuildNeonFoundry()
MatchSystem.Init()
CombatSystem.Init()
AbilitySystem.Init(HeroSystem, MatchSystem, CombatSystem)
AISystem.Init(HeroSystem, MatchSystem, CombatSystem, AbilitySystem)
ProgressionSystem.Init()

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

local function ensureRemote(name: string, className: string)
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

requestJoin.OnServerEvent:Connect(function(player)
    MatchSystem.RequestJoin(player)
end)

requestDeck.OnServerEvent:Connect(function(player, payload)
    if MatchSystem.State ~= "DeckSelect" then return end
    if type(payload) ~= "table" or type(payload.heroIds) ~= "table" then return end
    MatchSystem.Decks[player.UserId] = payload.heroIds
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
    if typeof(payload.origin) == "Vector3" and (payload.origin - hero.Root.Position).Magnitude > 35 then return end
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
    local hero = HeroSystem.GetControlledHero(player)
    if not hero then return end
    AbilitySystem.UseAbility(hero, payload or {})
end)

requestCamera.OnServerEvent:Connect(function(_player, _payload)
    -- Camera is client-owned.
end)

requestScoreboard.OnServerEvent:Connect(function(player)
    local rows = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        table.insert(rows, {
            name = plr.Name,
            teamId = MatchSystem.GetTeam(plr.UserId) or "None",
            score = MatchSystem.Score[MatchSystem.GetTeam(plr.UserId) or Config.TEAM_RED] or 0,
        })
    end
    requestScoreboard:FireClient(player, { players = rows })
end)

clientReady.OnServerEvent:Connect(function(player)
    matchStateChanged:FireClient(player, {
        state = MatchSystem.State,
        timerRemaining = MatchSystem.Timer,
        redScore = MatchSystem.Score.Red,
        blueScore = MatchSystem.Score.Blue,
        teamId = MatchSystem.GetTeam(player.UserId),
    })
end)

getInitialState.OnServerInvoke = function(player)
    local profile = ProgressionSystem.Profiles[player.UserId]
    return {
        gameName = Config.GAME_NAME,
        matchState = MatchSystem.State,
        timerRemaining = MatchSystem.Timer,
        teamId = MatchSystem.GetTeam(player.UserId),
        selectedDeck = MatchSystem.Decks[player.UserId] or {"bolt_runner","iron_bulwark","vesper_scope","patch_flux","fuse_jack"},
        score = MatchSystem.Score,
        progression = profile or {Wins = 0, Coins = 0, XP = 0},
    }
end

Players.PlayerAdded:Connect(function(player)
    MatchSystem.AssignTeam(player)
    ProgressionSystem.CreateLeaderstats(player)
    player.Chatted:Connect(function(message)
        local isAdmin = RunService:IsStudio() or table.find(Config.ADMIN_USER_IDS, player.UserId) ~= nil
        if not isAdmin then
            return
        end

        if message == "/pda_reset" then
            MatchSystem.Reset()
        elseif message == "/pda_start" then
            if MatchSystem.State == "Lobby" then
                MatchSystem.RequestJoin(player)
            end
            if MatchSystem.State == "DeckSelect" then
                MatchSystem.BeginMatch()
            end
        elseif message == "/pda_bots" then
            MatchSystem.EnsureBotOpponent()
        elseif message == "/pda_winred" then
            MatchSystem.EndMatch(Config.TEAM_RED)
        elseif message == "/pda_winblue" then
            MatchSystem.EndMatch(Config.TEAM_BLUE)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    ProgressionSystem.Save(player)
    HeroSystem.RemoveOwner(player.UserId)
end)

MatchSystem.OnEnded(function(winnerTeam)
    for _, player in ipairs(Players:GetPlayers()) do
        local teamId = MatchSystem.GetTeam(player.UserId)
        local result = "Draw"
        if teamId == winnerTeam then
            result = "Win"
        elseif teamId ~= nil then
            result = "Loss"
        end
        local teamScore = teamId and MatchSystem.Score[teamId] or 0
        ProgressionSystem.AwardMatch(player, result, teamScore)
        ProgressionSystem.Save(player)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        matchStateChanged:FireAllClients({
            state = MatchSystem.State,
            timerRemaining = MatchSystem.Timer,
            redScore = MatchSystem.Score.Red,
            blueScore = MatchSystem.Score.Blue,
            winner = MatchSystem.Winner,
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

task.spawn(function()
    while true do
        task.wait(1)
        if MatchSystem.State == "MatchCountdown" then
            -- do nothing during countdown
        elseif MatchSystem.State == "ActiveMatch" then
            if not MatchSystem.SpawnedThisMatch then
                MatchSystem.SpawnedThisMatch = true
                for _, plr in ipairs(Players:GetPlayers()) do
                    local deck = MatchSystem.Decks[plr.UserId] or {"bolt_runner","iron_bulwark","vesper_scope","patch_flux","fuse_jack"}
                    local teamId = MatchSystem.GetTeam(plr.UserId) or Config.TEAM_RED
                    HeroSystem.SpawnHeroesForOwner(plr.UserId, teamId, deck, plr)
                end
                if MatchSystem.BotActive then
                    local botDeck = {"glitch_byte","terra_pin","wisp_ion","iron_bulwark","fuse_jack"}
                    HeroSystem.SpawnHeroesForOwner(MatchSystem.BotOwnerId, Config.TEAM_BLUE, botDeck, nil)
                end
                for _, hero in pairs(HeroSystem.HeroesByGuid) do
                    if not hero.IsControlled then
                        AISystem.EnableHeroAI(hero, true)
                    end
                end
            end
        elseif MatchSystem.State == "PostMatch" then
            -- waiting for reset
        elseif MatchSystem.State == "Resetting" then
            HeroSystem.ClearAll()
            MatchSystem.SpawnedThisMatch = false
            AISystem.Clear()
            AbilitySystem.Clear()
        elseif MatchSystem.State == "Lobby" and MatchSystem.NeedsWorldReset then
            HeroSystem.ClearAll()
            AISystem.Clear()
            AbilitySystem.Clear()
            MapBuilder.BuildNeonFoundry()
            local objectivesFolder = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Objectives")
            CombatSystem.Init()
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

print(Config.GAME_NAME .. " Stage 6 boot complete")
