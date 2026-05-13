local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local SettingsClient = {}

-- === KEY BINDINGS ===
SettingsClient.DefaultBindings = {
	Fire = Enum.UserInputType.MouseButton1,
	Reload = Enum.KeyCode.R,
	Ability = Enum.KeyCode.Q,
	Ultimate = Enum.KeyCode.E,
	Power = Enum.KeyCode.F,
	Switch1 = Enum.KeyCode.One,
	Switch2 = Enum.KeyCode.Two,
	Switch3 = Enum.KeyCode.Three,
	Switch4 = Enum.KeyCode.Four,
	Switch5 = Enum.KeyCode.Five,
	Camera = Enum.KeyCode.V,
	Scoreboard = Enum.KeyCode.Tab,
	Pause = Enum.KeyCode.P,
	Ready = Enum.KeyCode.U,
	SpectateNext = Enum.KeyCode.G,
	SpectateMode = Enum.KeyCode.H,
	SpectateToggle = Enum.KeyCode.Y,
	Emote = Enum.KeyCode.T,
	Practice = Enum.KeyCode.M,
	Shop = Enum.KeyCode.B,
	Jump = Enum.KeyCode.Space,
	Sprint = Enum.KeyCode.LeftShift,
	Crouch = Enum.KeyCode.LeftControl,
	Walk = Enum.KeyCode.LeftAlt,
}

SettingsClient.Bindings = {}
SettingsClient.GraphicsPreset = "High"
SettingsClient.FPSCap = 60
SettingsClient.MasterVolume = 1
SettingsClient.SFXVolume = 1
SettingsClient.MusicVolume = 0.5
SettingsClient.Sensitivity = 1
SettingsClient.InvertY = false
SettingsClient.CameraShake = true
SettingsClient.ShowDamageNumbers = true
SettingsClient.ShowKillfeed = true

-- Post-processing instances
SettingsClient.PostFX = {}

local PRESETS = {
	Low = {
		bloom = false, dof = false, atmosphere = false, colorCorrection = false, sunRays = false,
		fogEnd = 200, ambient = Color3.fromRGB(30, 35, 50), brightness = 1.5, fps = 60,
		envDiffuse = 0.5, envSpecular = 0.3, fogColor = Color3.fromRGB(15, 18, 25),
	},
	Medium = {
		bloom = true, dof = false, atmosphere = true, colorCorrection = false, sunRays = false,
		bloomIntensity = 0.2, bloomSize = 16, bloomThreshold = 1.5,
		fogEnd = 300, ambient = Color3.fromRGB(40, 50, 70), brightness = 1.8, fps = 60,
		envDiffuse = 0.4, envSpecular = 0.5, fogColor = Color3.fromRGB(15, 18, 25),
	},
	High = {
		bloom = true, dof = true, atmosphere = true, colorCorrection = true, sunRays = false,
		bloomIntensity = 0.3, bloomSize = 24, bloomThreshold = 1.2,
		dofFarIntensity = 0.3, dofFocusDistance = 20, dofInFocusRadius = 16,
		fogEnd = 400, ambient = Color3.fromRGB(55, 60, 80), brightness = 2,
		envDiffuse = 0.4, envSpecular = 0.6, fps = 120,
		fogColor = Color3.fromRGB(15, 18, 25),
	},
	Ultra = {
		bloom = true, dof = true, atmosphere = true, colorCorrection = true, sunRays = true,
		bloomIntensity = 0.4, bloomSize = 32, bloomThreshold = 1.0,
		dofFarIntensity = 0.4, dofFocusDistance = 25, dofInFocusRadius = 12,
		fogEnd = 600, ambient = Color3.fromRGB(65, 75, 95), brightness = 2.2,
		envDiffuse = 0.5, envSpecular = 0.7, fps = 144,
		fogColor = Color3.fromRGB(20, 25, 35),
		sunRaysIntensity = 0.05, sunRaysSpread = 0.3,
	},
}

function SettingsClient.GetControlNames()
	return {
		Fire = "Fire / Shoot", Reload = "Reload", Ability = "Ability", Ultimate = "Ultimate",
		Power = "Hero Power", Switch1 = "Switch Hero 1", Switch2 = "Switch Hero 2",
		Switch3 = "Switch Hero 3", Switch4 = "Switch Hero 4", Switch5 = "Switch Hero 5",
		Camera = "Toggle Camera", Scoreboard = "Scoreboard", Pause = "Pause Menu",
		Ready = "Ready Up", Jump = "Jump", Sprint = "Sprint", Crouch = "Crouch",
		Emote = "Emote Wheel", Practice = "Practice Range", Shop = "Shop",
		SpectateNext = "Spectate Next", SpectateMode = "Spectate Mode", SpectateToggle = "Spectate Toggle",
	}
end

function SettingsClient.GetBindingDisplay(actionName)
	local key = SettingsClient.Bindings[actionName]
	if not key then return "?" end
	local keyName = tostring(key)
	if keyName:find("Enum.KeyCode.") then
		return keyName:gsub("Enum.KeyCode.", "")
	elseif keyName:find("Enum.UserInputType.") then
		return keyName:gsub("Enum.UserInputType.", "")
	end
	return keyName
end

function SettingsClient.SetBinding(actionName, inputObject)
	SettingsClient.Bindings[actionName] = inputObject.KeyCode or inputObject.UserInputType
	SettingsClient.Save()
end

function SettingsClient.ResetBindings()
	for k, v in pairs(SettingsClient.DefaultBindings) do
		SettingsClient.Bindings[k] = v
	end
	SettingsClient.Save()
end

function SettingsClient.ApplyGraphicsPreset(preset)
	SettingsClient.GraphicsPreset = preset
	local p = PRESETS[preset] or PRESETS.High

	-- FPS cap
	RunService:SetFPSLimit(p.fps or 60)
	SettingsClient.FPSCap = p.fps

	-- UserGameSettings quality
	local ugs = UserInputService.UserGameSettings
	ugs.SavedQualityLevel = (preset == "Low") and Enum.SavedQualitySetting.QualityLevel1
		or (preset == "Medium") and Enum.SavedQualitySetting.QualityLevel3
		or (preset == "High") and Enum.SavedQualitySetting.QualityLevel7
		or (preset == "Ultra") and Enum.SavedQualitySetting.QualityLevel10
		or Enum.SavedQualitySetting.Automatic

	-- Lighting
	Lighting.Ambient = p.ambient or Color3.fromRGB(55, 60, 80)
	Lighting.Brightness = p.brightness or 2
	Lighting.EnvironmentDiffuseScale = p.envDiffuse or 0.4
	Lighting.EnvironmentSpecularScale = p.envSpecular or 0.6
	Lighting.FogColor = p.fogColor or Color3.fromRGB(15, 18, 25)
	Lighting.FogEnd = p.fogEnd or 400

	-- Bloom
	if SettingsClient.PostFX.Bloom then
		SettingsClient.PostFX.Bloom.Enabled = p.bloom
		if p.bloom then
			SettingsClient.PostFX.Bloom.Intensity = p.bloomIntensity or 0.3
			SettingsClient.PostFX.Bloom.Size = p.bloomSize or 24
			SettingsClient.PostFX.Bloom.Threshold = p.bloomThreshold or 1.2
		end
	end

	-- Depth of Field
	if SettingsClient.PostFX.DepthOfField then
		SettingsClient.PostFX.DepthOfField.Enabled = p.dof
		if p.dof then
			SettingsClient.PostFX.DepthOfField.FarIntensity = p.dofFarIntensity or 0.3
			SettingsClient.PostFX.DepthOfField.FocusDistance = p.dofFocusDistance or 20
			SettingsClient.PostFX.DepthOfField.InFocusRadius = p.dofInFocusRadius or 16
			SettingsClient.PostFX.DepthOfField.NearIntensity = 0
		end
	end

	-- Color Correction
	if SettingsClient.PostFX.ColorCorrection then
		SettingsClient.PostFX.ColorCorrection.Enabled = p.colorCorrection
	end

	-- Sun Rays
	if SettingsClient.PostFX.SunRays then
		SettingsClient.PostFX.SunRays.Enabled = p.sunRays
		if p.sunRays then
			SettingsClient.PostFX.SunRays.Intensity = p.sunRaysIntensity or 0
			SettingsClient.PostFX.SunRays.Spread = p.sunRaysSpread or 0.5
		end
	end

	-- Atmosphere
	if SettingsClient.PostFX.Atmosphere then
		SettingsClient.PostFX.Atmosphere.Enabled = p.atmosphere
		if p.atmosphere then
			SettingsClient.PostFX.Atmosphere.Density = p.density or 0.15
			SettingsClient.PostFX.Atmosphere.Offset = p.offset or 0.5
			SettingsClient.PostFX.Atmosphere.Color = Color3.fromRGB(40, 45, 60)
			SettingsClient.PostFX.Atmosphere.Decay = Color3.fromRGB(20, 22, 30)
			SettingsClient.PostFX.Atmosphere.Glare = p.glare or 0.1
			SettingsClient.PostFX.Atmosphere.Haze = p.haze or 0.5
		end
	end

	SettingsClient.Save()
end

function SettingsClient.SetFPSCap(fps)
	SettingsClient.FPSCap = fps
	RunService:SetFPSLimit(fps)
	SettingsClient.Save()
end

function SettingsClient.Init()
	for k, v in pairs(SettingsClient.DefaultBindings) do
		SettingsClient.Bindings[k] = v
	end

	-- Create and store post-processing instances
	local function attach(instance, name)
		instance.Parent = Lighting
		SettingsClient.PostFX[name] = instance
		return instance
	end

	attach(Instance.new("BloomEffect"), "Bloom")
	attach(Instance.new("DepthOfFieldEffect"), "DepthOfField")
	attach(Instance.new("ColorCorrectionEffect"), "ColorCorrection")
	attach(Instance.new("SunRaysEffect"), "SunRays")
	attach(Instance.new("Atmosphere"), "Atmosphere")

	SettingsClient.ApplyGraphicsPreset("High")
	SettingsClient.Load()
end

function SettingsClient.Save()
	local ok, err = pcall(function()
		local dss = game:GetService("DataStoreService")
		local store = dss:GetDataStore("PulseDeckArenaSettings")
		store:SetAsync("settings_" .. tostring(game.Players.LocalPlayer.UserId), {
			bindings = SettingsClient.Bindings,
			graphicsPreset = SettingsClient.GraphicsPreset,
			fpsCap = SettingsClient.FPSCap,
			masterVolume = SettingsClient.MasterVolume,
			sfxVolume = SettingsClient.SFXVolume,
			musicVolume = SettingsClient.MusicVolume,
			sensitivity = SettingsClient.Sensitivity,
			invertY = SettingsClient.InvertY,
			cameraShake = SettingsClient.CameraShake,
			showDamageNumbers = SettingsClient.ShowDamageNumbers,
			showKillfeed = SettingsClient.ShowKillfeed,
		})
	end)
	if not ok then
		-- Fallback: save to HttpService
		local ok2, err2 = pcall(function()
			local http = game:GetService("HttpService")
			local path = "PDA_Settings_" .. tostring(game.Players.LocalPlayer.UserId)
			local f = Instance.new("StringValue")
			f.Name = path
			f.Value = http:JSONEncode({
				bindings = SettingsClient.Bindings,
				graphicsPreset = SettingsClient.GraphicsPreset,
				fpsCap = SettingsClient.FPSCap,
				masterVolume = SettingsClient.MasterVolume,
				sfxVolume = SettingsClient.SFXVolume,
				musicVolume = SettingsClient.MusicVolume,
				sensitivity = SettingsClient.Sensitivity,
				invertY = SettingsClient.InvertY,
				cameraShake = SettingsClient.CameraShake,
			})
			f.Parent = game.Players.LocalPlayer
		end)
	end
end

function SettingsClient.Load()
	local ok, data = pcall(function()
		local dss = game:GetService("DataStoreService")
		local store = dss:GetDataStore("PulseDeckArenaSettings")
		return store:GetAsync("settings_" .. tostring(game.Players.LocalPlayer.UserId))
	end)
	if ok and type(data) == "table" then
		if data.bindings then
			for k, v in pairs(data.bindings) do
				SettingsClient.Bindings[k] = v
			end
		end
		if data.graphicsPreset then
			SettingsClient.ApplyGraphicsPreset(data.graphicsPreset)
		end
		if data.fpsCap then
			SettingsClient.SetFPSCap(data.fpsCap)
		end
		SettingsClient.MasterVolume = data.masterVolume or 1
		SettingsClient.SFXVolume = data.sfxVolume or 1
		SettingsClient.MusicVolume = data.musicVolume or 0.5
		SettingsClient.Sensitivity = data.sensitivity or 1
		SettingsClient.InvertY = data.invertY or false
		SettingsClient.CameraShake = data.cameraShake or true
		SettingsClient.ShowDamageNumbers = data.showDamageNumbers or true
		SettingsClient.ShowKillfeed = data.showKillfeed or true
	end
end

function SettingsClient.GetCurrentPreset()
	return SettingsClient.GraphicsPreset
end

function SettingsClient.GetFPSCap()
	return SettingsClient.FPSCap
end

return SettingsClient
