--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local ProgressionUtils = require(sharedRoot:WaitForChild("ProgressionUtils"))
local Config = require(sharedRoot:WaitForChild("Config"))
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))

local ProgressionSystem = {}

ProgressionSystem.Profiles = {}
ProgressionSystem.DataStoreAvailable = true
ProgressionSystem.WarnedFallback = false

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("PulseDeckArenaProfiles_v2")
end)
if not storeOk then
	store = nil
	ProgressionSystem.DataStoreAvailable = false
end

local function defaultProfile()
	return {
		Wins = 0,
		Losses = 0,
		Coins = 0,
		XP = 0,
		Level = 1,
		TotalKills = 0,
		TotalDeaths = 0,
		TotalDamage = 0,
		FavoriteHero = nil,
		UnlockedHeroes = {"bolt_runner", "iron_bulwark", "vesper_scope", "patch_flux", "fuse_jack"},
		OwnedSkins = {},
		EquippedSkin = "default",
		LastPlayed = 0,
		Achievements = {},
		PrestigeLevel = 0,
		BattlePassTier = 0,
		BattlePassXP = 0,
		BattlePassPremium = false,
		PurchasedItems = {},
		TotalSpent = 0,
	}
end

local function warnFallbackOnce()
	if ProgressionSystem.WarnedFallback then return end
	ProgressionSystem.WarnedFallback = true
	warn("PulseDeckArena: DataStore unavailable, using in-memory progression fallback.")
end

function ProgressionSystem.Init()
	ProgressionSystem.Profiles = {}
end

function ProgressionSystem.Load(player)
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

	-- Migrate / validate
	if not data.UnlockedHeroes then
		data.UnlockedHeroes = {"bolt_runner", "iron_bulwark", "vesper_scope", "patch_flux", "fuse_jack"}
	end

	ProgressionSystem.Profiles[player.UserId] = data
	return data
end

function ProgressionSystem.Save(player)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile or not ProgressionSystem.DataStoreAvailable then return end

	profile.LastPlayed = os.time()

	local ok = pcall(function()
		store:SetAsync("user_" .. tostring(player.UserId), profile)
	end)

	if not ok then
		ProgressionSystem.DataStoreAvailable = false
		warnFallbackOnce()
	end
end

function ProgressionSystem.CreateLeaderstats(player)
	local profile = ProgressionSystem.Load(player)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = profile.Wins
	wins.Parent = leaderstats

	local losses = Instance.new("IntValue")
	losses.Name = "Losses"
	losses.Value = profile.Losses or 0
	losses.Parent = leaderstats

	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Value = profile.TotalKills or 0
	kills.Parent = leaderstats

	local kd = Instance.new("StringValue")
	kd.Name = "K/D"
	local deaths = profile.TotalDeaths or 0
	local kc = profile.TotalKills or 0
	kd.Value = string.format("%.2f", kc / math.max(1, deaths))
	kd.Parent = leaderstats

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.Coins
	coins.Parent = leaderstats

	local xp = Instance.new("IntValue")
	xp.Name = "XP"
	xp.Value = profile.XP
	xp.Parent = leaderstats

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = ProgressionUtils.GetLevel(profile.XP)
	level.Parent = leaderstats
end

function ProgressionSystem.SyncLeaderstats(player)
	local profile = ProgressionSystem.Profiles[player.UserId]
	local leaderstats = player:FindFirstChild("leaderstats")
	if not profile or not leaderstats then return end

	local wins = leaderstats:FindFirstChild("Wins")
	local losses = leaderstats:FindFirstChild("Losses")
	local kills = leaderstats:FindFirstChild("Kills")
	local kd = leaderstats:FindFirstChild("K/D")
	local coins = leaderstats:FindFirstChild("Coins")
	local xp = leaderstats:FindFirstChild("XP")
	local level = leaderstats:FindFirstChild("Level")

	if wins then wins.Value = profile.Wins end
	if losses then losses.Value = profile.Losses or 0 end
	if kills then kills.Value = profile.TotalKills or 0 end
	if kd then
		local d = profile.TotalDeaths or 0
		local k = profile.TotalKills or 0
		kd.Value = string.format("%.2f", k / math.max(1, d))
	end
	if coins then coins.Value = profile.Coins end
	if xp then xp.Value = profile.XP end
	if level then level.Value = ProgressionUtils.GetLevel(profile.XP) end
end

function ProgressionSystem.GetLevel(xp)
	return ProgressionUtils.GetLevel(xp)
end

function ProgressionSystem.GetXpNeededForLevel(level)
	return ProgressionUtils.GetXpNeededForLevel(level)
end

function ProgressionSystem.AwardMatch(player, result, teamScore)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile then
		profile = ProgressionSystem.Load(player)
	end

	local coins = 40
	local xp = 90

	if result == "Win" then
		coins = 75
		xp = 140
		profile.Wins = (profile.Wins or 0) + 1
	elseif result == "Loss" then
		coins = 25
		xp = 50
		profile.Losses = (profile.Losses or 0) + 1
	elseif result == "Draw" then
		coins = 20
		xp = 30
	end

	-- Bonus based on team contribution
	coins += math.floor((teamScore or 0) / 25)
	xp += math.floor((teamScore or 0) / 50)

	profile.Coins += coins
	profile.XP += xp

	-- Update stats
	local hero = HeroSystem.GetControlledHero(player)
	if hero then
		profile.TotalKills = (profile.TotalKills or 0) + (hero.KillCount or 0)
		profile.TotalDeaths = (profile.TotalDeaths or 0) + (hero.DeathCount or 0)
		profile.TotalDamage = (profile.TotalDamage or 0) + math.floor(hero.DamageDealt or 0)
	end

	ProgressionSystem.SyncLeaderstats(player)
end

function ProgressionSystem.GetProfile(player)
	return ProgressionSystem.Profiles[player.UserId]
end

function ProgressionSystem.UnlockHero(player, heroId)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile then return false end

	if table.find(profile.UnlockedHeroes, heroId) then return true end

	-- Cost to unlock varies by hero rarity
	local heroDef = HeroConfig[heroId]
	local cost = 500
	if heroDef then
		-- Based on role difficulty or rarity
		cost = 300 + (#HeroConfig[heroId] and 50 or 0)
	end

	if profile.Coins >= cost then
		profile.Coins -= cost
		table.insert(profile.UnlockedHeroes, heroId)
		ProgressionSystem.SyncLeaderstats(player)
		return true
	end
	return false
end

function ProgressionSystem.UnlockSkin(player, heroId, skinId)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile then return false end

	-- Check hero is unlocked
	if not table.find(profile.UnlockedHeroes, heroId) then return false end

	local heroDef = HeroConfig[heroId]
	if not heroDef or not heroDef.skins or not heroDef.skins[skinId] then return false end

	local skinKey = heroId .. "_" .. skinId
	if table.find(profile.OwnedSkins, skinKey) then
		-- Already owned, just equip
		profile.EquippedSkin = skinKey
		ProgressionSystem.SyncLeaderstats(player)
		return true
	end

	-- Check skin rarity and cost
	local skinDef = heroDef.skins[skinId]
	local cost = 100 -- default
	if skinDef.rarity == "Common" then
		cost = 50
	elseif skinDef.rarity == "Rare" then
		cost = 200
	elseif skinDef.rarity == "Epic" then
		cost = 500
	elseif skinDef.rarity == "Legendary" then
		cost = 1500
	end

	if profile.Coins >= cost then
		profile.Coins -= cost
		table.insert(profile.OwnedSkins, skinKey)
		profile.EquippedSkin = skinKey
		ProgressionSystem.SyncLeaderstats(player)
		return true
	end
	return false
end

function ProgressionSystem.EquipSkin(player, heroId, skinId)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile then
		profile = ProgressionSystem.Load(player)
	end

	local heroDef = HeroConfig[heroId]
	if heroDef and heroDef.skins and heroDef.skins[skinId] then
		-- Allow equipping default skin without owning it
		if skinId == "default" then
			profile.EquippedSkin = "default"
			ProgressionSystem.SyncLeaderstats(player)
			return true
		end

		-- Check if skin is owned
		local skinKey = heroId .. "_" .. skinId
		if table.find(profile.OwnedSkins, skinKey) then
			profile.EquippedSkin = skinId
			ProgressionSystem.SyncLeaderstats(player)
			return true
		end
	end
	return false
end

function ProgressionSystem.RecordKill(player, heroId, kills, deaths)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile then return end

	profile.TotalKills = (profile.TotalKills or 0) + kills
	profile.TotalDeaths = (profile.TotalDeaths or 0) + deaths

	-- Track favorite hero
	if not profile.HeroStats then profile.HeroStats = {} end
	if not profile.HeroStats[heroId] then
		profile.HeroStats[heroId] = {kills = 0, deaths = 0, damage = 0}
	end
	profile.HeroStats[heroId].kills = profile.HeroStats[heroId].kills + kills
	profile.HeroStats[heroId].deaths = profile.HeroStats[heroId].deaths + deaths

	local bestHero = nil
	local bestKills = 0
	for hero, stats in pairs(profile.HeroStats) do
		if stats.kills > bestKills then
			bestKills = stats.kills
			bestHero = hero
		end
	end
	profile.FavoriteHero = bestHero

	-- Check achievement unlocks
	local function checkAndAwardAchievement(name, condition, xpReward)
		if not profile.Achievements[name] and condition() then
			profile.Achievements[name] = true
			profile.XP = (profile.XP or 0) + xpReward
		end
	end

	checkAndAwardAchievement("first_blood", function() return kills >= 1 end, 50)
	checkAndAwardAchievement("five_kills", function() return kills >= 5 end, 100)
	checkAndAwardAchievement("ten_kills", function() return kills >= 10 end, 200)
	checkAndAwardAchievement("dominator", function() return kills >= 20 end, 500)
	checkAndAwardAchievement("perfection", function() return kills > 0 and deaths == 0 end, 150)

	ProgressionSystem.SyncLeaderstats(player)
end

function ProgressionSystem.GetSkinList(heroId)
	local heroDef = HeroConfig[heroId]
	if not heroDef or not heroDef.skins then return {"default"} end
	local skins = {"default"}
	for id, _ in pairs(heroDef.skins) do
		if id ~= "default" then
			table.insert(skins, id)
		end
	end
	return skins
end

function ProgressionSystem.GetSkinRarity(heroId, skinId)
	local heroDef = HeroConfig[heroId]
	if heroDef and heroDef.skins and heroDef.skins[skinId] then
		return heroDef.skins[skinId].rarity or "Default"
	end
	return "Default"
end

function ProgressionSystem.PurchaseShopItem(player, itemId)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile then return false, "No profile" end

	local item = nil
	for _, shopItem in ipairs(Config.SHOP_ITEMS) do
		if shopItem.id == itemId then
			item = shopItem
			break
		end
	end
	if not item then return false, "Item not found" end
	if profile.Coins < item.price then return false, "Not enough coins" end

	profile.Coins = profile.Coins - item.price
	profile.TotalSpent = (profile.TotalSpent or 0) + item.price
	if not profile.PurchasedItems then profile.PurchasedItems = {} end
	table.insert(profile.PurchasedItems, itemId)

	-- Handle rewards
	if itemId == "coins_500" then
		profile.Coins += 500
	elseif itemId == "coins_1500" then
		profile.Coins += 1500
	elseif itemId == "coins_4000" then
		profile.Coins += 4000
	elseif string.find(itemId, "skin_bundle") then
		for _, skinKey in ipairs(item.items or {}) do
			if not table.find(profile.OwnedSkins or {}, skinKey) then
				table.insert(profile.OwnedSkins, skinKey)
			end
		end
	end

	ProgressionSystem.SyncLeaderstats(player)
	return true, "Purchased"
end

function ProgressionSystem.GetBattlePassRewards(tier)
	local reward = ProgressionUtils.BATTLE_PASS_TIERS[tier]
	return reward or nil
end

function ProgressionSystem.ClaimBattlePassReward(player, tier)
	local profile = ProgressionSystem.Profiles[player.UserId]
	if not profile then return false end
	if not profile.BattlePassClaimed then profile.BattlePassClaimed = {} end
	if profile.BattlePassClaimed[tier] then return false, "Already claimed" end
	local reward = ProgressionSystem.GetBattlePassRewards(tier)
	if not reward then return false, "No reward" end
	profile.BattlePassClaimed[tier] = true
	if reward.type == "coins" then
		profile.Coins += reward.amount or 0
	end
	ProgressionSystem.SyncLeaderstats(player)
	return true
end

return ProgressionSystem