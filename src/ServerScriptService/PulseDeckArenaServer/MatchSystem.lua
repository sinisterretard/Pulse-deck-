--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))

local MatchSystem = {}

MatchSystem.State = "Lobby"
MatchSystem.MatchId = "0"
MatchSystem.Timer = 0
MatchSystem.Score = { Red = 0, Blue = 0 }
MatchSystem.CoreDamage = { Red = 0, Blue = 0 }
MatchSystem.Players = {}
MatchSystem.BotOwnerId = "__BOT_BLUE__"
MatchSystem.BotActive = false
MatchSystem.TeamAssignments = {}
MatchSystem.Decks = {}
MatchSystem.ControlledHero = {}
MatchSystem.JoinRequestedAt = {}
MatchSystem.SoloStartTask = nil
MatchSystem.SpawnedThisMatch = false
MatchSystem.NeedsWorldReset = false
MatchSystem.EndedCallbacks = {}
MatchSystem.Winner = nil

function MatchSystem.Init()
    MatchSystem.State = "Lobby"
    MatchSystem.Score = { Red = 0, Blue = 0 }
    MatchSystem.CoreDamage = { Red = 0, Blue = 0 }
    MatchSystem.TeamAssignments = {}
    MatchSystem.Decks = {}
    MatchSystem.ControlledHero = {}
    MatchSystem.BotActive = false
    MatchSystem.Winner = nil
end

function MatchSystem.GetState()
    return MatchSystem.State
end

function MatchSystem.SetState(state: string)
    MatchSystem.State = state
end

function MatchSystem.AssignTeam(player: Player)
    if not MatchSystem.TeamAssignments[player.UserId] then
        local redTaken = false
        for _, teamId in pairs(MatchSystem.TeamAssignments) do
            if teamId == Config.TEAM_RED then
                redTaken = true
                break
            end
        end
        MatchSystem.TeamAssignments[player.UserId] = redTaken and Config.TEAM_BLUE or Config.TEAM_RED
    end
    return MatchSystem.TeamAssignments[player.UserId]
end

function MatchSystem.GetTeam(userId: number)
    return MatchSystem.TeamAssignments[userId]
end

function MatchSystem.EnsureBotOpponent()
    MatchSystem.BotActive = true
    MatchSystem.TeamAssignments[MatchSystem.BotOwnerId] = Config.TEAM_BLUE
end

function MatchSystem.RequestJoin(player: Player)
    MatchSystem.AssignTeam(player)
    MatchSystem.JoinRequestedAt[player.UserId] = os.clock()
    if MatchSystem.State == "Lobby" then
        MatchSystem.State = "DeckSelect"
        MatchSystem.Timer = 15
        MatchSystem.StartSoloCountdown()
        task.spawn(function()
            for i = 15, 1, -1 do
                task.wait(1)
                MatchSystem.Timer = i - 1
            end
            MatchSystem.BeginMatch()
        end)
    end
end

function MatchSystem.StartSoloCountdown()
    if MatchSystem.SoloStartTask then
        return
    end
    MatchSystem.SoloStartTask = task.delay(Config.SOLO_BOT_START_DELAY, function()
        if #Players:GetPlayers() == 1 then
            MatchSystem.EnsureBotOpponent()
        end
    end)
end

function MatchSystem.BeginMatch()
    if MatchSystem.State ~= "DeckSelect" then
        return
    end
    MatchSystem.State = "MatchCountdown"
    MatchSystem.MatchId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    MatchSystem.Score = { Red = 0, Blue = 0 }
    MatchSystem.CoreDamage = { Red = 0, Blue = 0 }
    MatchSystem.Timer = Config.MATCH_DURATION
    MatchSystem.SpawnedThisMatch = false
    task.spawn(function()
        task.wait(Config.COUNTDOWN_DURATION)
        MatchSystem.State = "ActiveMatch"
        if #Players:GetPlayers() < 2 then
            MatchSystem.EnsureBotOpponent()
        end
        task.spawn(function()
            while MatchSystem.State == "ActiveMatch" do
                task.wait(1)
                MatchSystem.Timer -= 1
                if MatchSystem.Timer <= 0 then
                    MatchSystem.EndByTime()
                    break
                end
            end
        end)
    end)
end

function MatchSystem.RecordCoreDamage(teamId: string, amount: number)
    MatchSystem.CoreDamage[teamId] = (MatchSystem.CoreDamage[teamId] or 0) + amount
end

function MatchSystem.AddScore(teamId: string, amount: number)
    MatchSystem.Score[teamId] = (MatchSystem.Score[teamId] or 0) + amount
end

function MatchSystem.EndByTime()
    if MatchSystem.Score.Red > MatchSystem.Score.Blue then
        MatchSystem.EndMatch(Config.TEAM_RED)
    elseif MatchSystem.Score.Blue > MatchSystem.Score.Red then
        MatchSystem.EndMatch(Config.TEAM_BLUE)
    else
        if MatchSystem.CoreDamage.Red > MatchSystem.CoreDamage.Blue then
            MatchSystem.EndMatch(Config.TEAM_RED)
        elseif MatchSystem.CoreDamage.Blue > MatchSystem.CoreDamage.Red then
            MatchSystem.EndMatch(Config.TEAM_BLUE)
        else
            MatchSystem.State = "SuddenDeath"
        end
    end
end

function MatchSystem.EndMatch(winnerTeam: string)
    if MatchSystem.State == "PostMatch" then
        return
    end
    MatchSystem.State = "PostMatch"
    MatchSystem.Winner = winnerTeam
    for _, callback in ipairs(MatchSystem.EndedCallbacks) do
        task.spawn(callback, winnerTeam, MatchSystem.Score)
    end
    task.delay(12, function()
        MatchSystem.Reset()
    end)
end

function MatchSystem.OnEnded(callback)
    table.insert(MatchSystem.EndedCallbacks, callback)
end

function MatchSystem.Reset()
    MatchSystem.State = "Resetting"
    MatchSystem.TeamAssignments = {}
    MatchSystem.Decks = {}
    MatchSystem.ControlledHero = {}
    MatchSystem.Score = { Red = 0, Blue = 0 }
    MatchSystem.CoreDamage = { Red = 0, Blue = 0 }
    MatchSystem.BotActive = false
    MatchSystem.SoloStartTask = nil
    MatchSystem.SpawnedThisMatch = false
    MatchSystem.NeedsWorldReset = true
    MatchSystem.Winner = nil
    MatchSystem.State = "Lobby"
end

function MatchSystem.OnCoreDestroyed(winnerTeam: string)
    if MatchSystem.State ~= "ActiveMatch" and MatchSystem.State ~= "SuddenDeath" then
        return
    end
    MatchSystem.EndMatch(winnerTeam)
end

return MatchSystem
