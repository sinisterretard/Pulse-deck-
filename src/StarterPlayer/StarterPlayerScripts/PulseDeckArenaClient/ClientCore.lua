--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientCore = {}

ClientCore.Remotes = {}
ClientCore.State = {
    matchState = "Lobby",
    timerRemaining = 0,
    teamId = nil,
    heroes = {},
    objectives = {},
    score = { Red = 0, Blue = 0 },
    selectedDeck = {"bolt_runner","iron_bulwark","vesper_scope","patch_flux","fuse_jack"},
    progression = {Wins = 0, Coins = 0, XP = 0},
}
ClientCore.Events = {
    MatchStateChanged = Instance.new("BindableEvent"),
    HeroStateChanged = Instance.new("BindableEvent"),
    ObjectiveStateChanged = Instance.new("BindableEvent"),
    ScoreChanged = Instance.new("BindableEvent"),
    DamageNumber = Instance.new("BindableEvent"),
    Effects = Instance.new("BindableEvent"),
    Killfeed = Instance.new("BindableEvent"),
    Scoreboard = Instance.new("BindableEvent"),
}

function ClientCore.Init()
    local remotes = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Remotes")
    ClientCore.Remotes = {
        ClientReady = remotes:WaitForChild("ClientReady"),
        RequestJoinQueue = remotes:WaitForChild("RequestJoinQueue"),
        RequestDeckUpdate = remotes:WaitForChild("RequestDeckUpdate"),
        RequestSwitchHero = remotes:WaitForChild("RequestSwitchHero"),
        RequestStartMatch = remotes:WaitForChild("RequestStartMatch"),
        RequestFire = remotes:WaitForChild("RequestFire"),
        RequestReload = remotes:WaitForChild("RequestReload"),
        RequestAbility = remotes:WaitForChild("RequestAbility"),
        RequestCameraMode = remotes:WaitForChild("RequestCameraMode"),
        RequestScoreboard = remotes:WaitForChild("RequestScoreboard"),
        MatchStateChanged = remotes:WaitForChild("MatchStateChanged"),
        HeroStateSnapshot = remotes:WaitForChild("HeroStateSnapshot"),
        ObjectiveStateChanged = remotes:WaitForChild("ObjectiveStateChanged"),
        ScoreChanged = remotes:WaitForChild("ScoreChanged"),
        DamageNumberEvent = remotes:WaitForChild("DamageNumberEvent"),
        EffectsEvent = remotes:WaitForChild("EffectsEvent"),
        KillfeedEvent = remotes:WaitForChild("KillfeedEvent"),
        GetInitialState = remotes:WaitForChild("GetInitialState"),
    }

    local initial = ClientCore.Remotes.GetInitialState:InvokeServer()
    if type(initial) == "table" then
        ClientCore.State.matchState = initial.matchState or "Lobby"
        ClientCore.State.timerRemaining = initial.timerRemaining or 0
        ClientCore.State.teamId = initial.teamId
        ClientCore.State.selectedDeck = initial.selectedDeck or ClientCore.State.selectedDeck
        ClientCore.State.score = initial.score or ClientCore.State.score
        ClientCore.State.progression = initial.progression or ClientCore.State.progression
    end

    ClientCore.Remotes.MatchStateChanged.OnClientEvent:Connect(function(payload)
        ClientCore.State.matchState = payload.state or ClientCore.State.matchState
        ClientCore.State.timerRemaining = payload.timerRemaining or ClientCore.State.timerRemaining
        ClientCore.State.teamId = payload.teamId or ClientCore.State.teamId
        ClientCore.Events.MatchStateChanged:Fire(payload)
    end)
    ClientCore.Remotes.HeroStateSnapshot.OnClientEvent:Connect(function(payload)
        ClientCore.State.heroes = payload.heroes or {}
        ClientCore.Events.HeroStateChanged:Fire(payload)
    end)
    ClientCore.Remotes.ObjectiveStateChanged.OnClientEvent:Connect(function(payload)
        ClientCore.State.objectives = payload.objectives or {}
        ClientCore.Events.ObjectiveStateChanged:Fire(payload)
    end)
    ClientCore.Remotes.ScoreChanged.OnClientEvent:Connect(function(payload)
        ClientCore.State.score = payload
        ClientCore.Events.ScoreChanged:Fire(payload)
    end)
    ClientCore.Remotes.DamageNumberEvent.OnClientEvent:Connect(function(payload)
        ClientCore.Events.DamageNumber:Fire(payload)
    end)
    ClientCore.Remotes.EffectsEvent.OnClientEvent:Connect(function(payload)
        ClientCore.Events.Effects:Fire(payload)
    end)
    ClientCore.Remotes.KillfeedEvent.OnClientEvent:Connect(function(payload)
        ClientCore.Events.Killfeed:Fire(payload)
    end)
    ClientCore.Remotes.RequestScoreboard.OnClientEvent:Connect(function(payload)
        ClientCore.Events.Scoreboard:Fire(payload)
    end)

    ClientCore.Fire("ClientReady", {})
end

function ClientCore.Fire(remoteName: string, payload)
    local remote = ClientCore.Remotes[remoteName]
    if remote then
        remote:FireServer(payload)
    end
end

return ClientCore
