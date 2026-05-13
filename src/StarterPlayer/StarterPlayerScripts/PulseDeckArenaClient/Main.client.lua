--!strict

print("PDA CLIENT: Main.client.lua is running!")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundManager = require(ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared"):WaitForChild("SoundManager"))

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))
local UIClient = require(script.Parent:WaitForChild("UIClient"))
local CameraClient = require(script.Parent:WaitForChild("CameraClient"))
local InputClient = require(script.Parent:WaitForChild("InputClient"))
local CombatClient = require(script.Parent:WaitForChild("CombatClient"))
local EffectsClient = require(script.Parent:WaitForChild("EffectsClient"))
local AnimationClient = require(script.Parent:WaitForChild("AnimationClient"))
local SettingsClient = require(script.Parent:WaitForChild("SettingsClient"))

-- Initialize in correct dependency order:
ClientCore.Init()
SettingsClient.Init()
UIClient.Init()
CameraClient.Init()
InputClient.Init()
CombatClient.Init()
EffectsClient.Init()

-- Animation client setup for local player rendering
-- (handled per-frame in InputClient or via RenderStepped)

-- SFX playback handler
local playSFX = ReplicatedStorage:FindFirstChild("PulseDeckArena")
	and ReplicatedStorage.PulseDeckArena:FindFirstChild("Remotes")
	and ReplicatedStorage.PulseDeckArena.Remotes:FindFirstChild("PlaySFX")

if playSFX and playSFX:IsA("RemoteEvent") then
	playSFX.OnClientEvent:Connect(function(payload)
		if payload.uiOnly then return end
		local soundName = payload.soundName
		local volume = payload.volume or 1
		local soundId = SoundManager.Sounds[soundName]
		if soundId and soundId ~= "rbxassetid://0" then
			local sound = Instance.new("Sound")
			sound.SoundId = soundId
			sound.Volume = volume
			sound.Parent = workspace
			if payload.position then
				sound.Position = payload.position
			end
			sound:Play()
			game:GetService("Debris"):AddItem(sound, 3)
		end
	end)
end

-- Animation update loop (client-side visual only)
game:GetService("RunService").RenderStepped:Connect(function(dt)
	-- Animation updates for local player's controlled hero
	-- would be handled here if needed
end)

print("PULSE DECK ARENA v2 client ready - All systems operational")