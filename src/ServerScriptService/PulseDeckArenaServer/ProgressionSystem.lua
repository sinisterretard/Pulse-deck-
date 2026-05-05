--!strict
local DataStoreService = game:GetService("DataStoreService")

local ProgressionSystem = {}

ProgressionSystem.Profiles = {}
ProgressionSystem.DataStoreAvailable = true
ProgressionSystem.WarnedFallback = false

local store = DataStoreService:GetDataStore("PulseDeckArenaProfiles_v1")

local function defaultProfile()
    return {
        Wins = 0,
        Coins = 0,
        XP = 0,
    }
end

local function warnFallbackOnce()
    if ProgressionSystem.WarnedFallback then
        return
    end
    ProgressionSystem.WarnedFallback = true
    warn("PulseDeckArena: DataStore unavailable, using in-memory progression fallback.")
end

function ProgressionSystem.Init()
    ProgressionSystem.Profiles = {}
end

function ProgressionSystem.Load(player: Player)
    if not ProgressionSystem.DataStoreAvailable then
        local profile = defaultProfile()
        ProgressionSystem.Profiles[player.UserId] = profile
        return profile
    end

    local ok, data = pcall(function()
        return store:GetAsync("user_" .. tostring(player.UserId))
    end)

    if not ok then
        ProgressionSystem.DataStoreAvailable = false
        warnFallbackOnce()
        local profile = defaultProfile()
        ProgressionSystem.Profiles[player.UserId] = profile
        return profile
    end

    if type(data) ~= "table" then
        data = defaultProfile()
    end

    ProgressionSystem.Profiles[player.UserId] = data
    return data
end

function ProgressionSystem.Save(player: Player)
    local profile = ProgressionSystem.Profiles[player.UserId]
    if not profile or not ProgressionSystem.DataStoreAvailable then
        return
    end

    local ok = pcall(function()
        store:SetAsync("user_" .. tostring(player.UserId), profile)
    end)

    if not ok then
        ProgressionSystem.DataStoreAvailable = false
        warnFallbackOnce()
    end
end

function ProgressionSystem.CreateLeaderstats(player: Player)
    local profile = ProgressionSystem.Load(player)

    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local wins = Instance.new("IntValue")
    wins.Name = "Wins"
    wins.Value = profile.Wins
    wins.Parent = leaderstats

    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = profile.Coins
    coins.Parent = leaderstats

    local xp = Instance.new("IntValue")
    xp.Name = "XP"
    xp.Value = profile.XP
    xp.Parent = leaderstats
end

function ProgressionSystem.SyncLeaderstats(player: Player)
    local profile = ProgressionSystem.Profiles[player.UserId]
    local leaderstats = player:FindFirstChild("leaderstats")
    if not profile or not leaderstats then
        return
    end

    local wins = leaderstats:FindFirstChild("Wins")
    local coins = leaderstats:FindFirstChild("Coins")
    local xp = leaderstats:FindFirstChild("XP")
    if wins and wins:IsA("IntValue") then wins.Value = profile.Wins end
    if coins and coins:IsA("IntValue") then coins.Value = profile.Coins end
    if xp and xp:IsA("IntValue") then xp.Value = profile.XP end
end

function ProgressionSystem.AwardMatch(player: Player, result: string, score: number)
    local profile = ProgressionSystem.Profiles[player.UserId]
    if not profile then
        profile = ProgressionSystem.Load(player)
    end

    local coins = 35
    local xp = 80
    if result == "Win" then
        coins = 60
        xp = 120
        profile.Wins += 1
    elseif result == "Loss" then
        coins = 25
        xp = 60
    end

    coins += math.floor(score / 150)
    profile.Coins += coins
    profile.XP += xp
    ProgressionSystem.SyncLeaderstats(player)
end

return ProgressionSystem
