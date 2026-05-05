--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local Config = require(sharedRoot:WaitForChild("Config"))
local Util = require(sharedRoot:WaitForChild("Util"))

local MapBuilder = {}

local function getWorldFolder(name: string): Folder
    local world = workspace:WaitForChild("PulseDeckArenaWorld")
    return world:WaitForChild(name) :: Folder
end

local function clearFolder(folder: Folder)
    for _, child in ipairs(folder:GetChildren()) do
        child:Destroy()
    end
end

local function makeWaypoint(folder: Folder, name: string, pos: Vector3, laneName: string, order: number)
    local wp = Instance.new("Part")
    wp.Name = name
    wp.Size = Vector3.new(2, 2, 2)
    wp.Transparency = 1
    wp.Anchored = true
    wp.CanCollide = false
    wp.Position = pos
    wp.Parent = folder
    wp:SetAttribute("LaneName", laneName)
    wp:SetAttribute("Order", order)
    CollectionService:AddTag(wp, "AIWaypoint")
end

function MapBuilder.BuildNeonFoundry()
    local mapFolder = getWorldFolder("Map")
    local waypointFolder = getWorldFolder("Waypoints")
    local effectsFolder = getWorldFolder("Effects")
    local projectilesFolder = getWorldFolder("Projectiles")

    clearFolder(mapFolder)
    clearFolder(waypointFolder)
    clearFolder(effectsFolder)
    clearFolder(projectilesFolder)

    local floor = Util.MakePart("ArenaFloor", Vector3.new(280, 2, 190), Vector3.new(0, -1, 0), Color3.fromRGB(24, 28, 36))
    floor.Parent = mapFolder

    Util.MakePart("Wall_North", Vector3.new(288, 36, 6), Vector3.new(0, 18, 96), Color3.fromRGB(18, 20, 28), Enum.Material.Concrete).Parent = mapFolder
    Util.MakePart("Wall_South", Vector3.new(288, 36, 6), Vector3.new(0, 18, -96), Color3.fromRGB(18, 20, 28), Enum.Material.Concrete).Parent = mapFolder
    Util.MakePart("Wall_West", Vector3.new(6, 36, 196), Vector3.new(-143, 18, 0), Color3.fromRGB(18, 20, 28), Enum.Material.Concrete).Parent = mapFolder
    Util.MakePart("Wall_East", Vector3.new(6, 36, 196), Vector3.new(143, 18, 0), Color3.fromRGB(18, 20, 28), Enum.Material.Concrete).Parent = mapFolder

    Util.MakePart("BasePlatform_Red", Vector3.new(42, 2, 78), Vector3.new(-124, 1, 0), Color3.fromRGB(80, 28, 34)).Parent = mapFolder
    Util.MakePart("BasePlatform_Blue", Vector3.new(42, 2, 78), Vector3.new(124, 1, 0), Color3.fromRGB(24, 56, 84)).Parent = mapFolder

    Util.MakePart("Cover_Main_Red_1", Vector3.new(14, 8, 8), Vector3.new(-62, 4, -12), Color3.fromRGB(35, 40, 55)).Parent = mapFolder
    Util.MakePart("Cover_Main_Red_2", Vector3.new(18, 8, 8), Vector3.new(-58, 4, 18), Color3.fromRGB(35, 40, 55)).Parent = mapFolder
    Util.MakePart("Cover_Main_Center_1", Vector3.new(20, 8, 8), Vector3.new(-12, 4, 20), Color3.fromRGB(35, 40, 55)).Parent = mapFolder
    Util.MakePart("Cover_Main_Center_2", Vector3.new(20, 8, 8), Vector3.new(12, 4, -20), Color3.fromRGB(35, 40, 55)).Parent = mapFolder
    Util.MakePart("Cover_Main_Blue_1", Vector3.new(14, 8, 8), Vector3.new(62, 4, 12), Color3.fromRGB(35, 40, 55)).Parent = mapFolder
    Util.MakePart("Cover_Main_Blue_2", Vector3.new(18, 8, 8), Vector3.new(58, 4, -18), Color3.fromRGB(35, 40, 55)).Parent = mapFolder

    Util.MakePart("Cover_Upper_Red_Entrance", Vector3.new(10, 12, 18), Vector3.new(-88, 6, 62), Color3.fromRGB(40, 45, 60)).Parent = mapFolder
    Util.MakePart("Cover_Upper_Mid_Left", Vector3.new(16, 10, 8), Vector3.new(-28, 5, 62), Color3.fromRGB(40, 45, 60)).Parent = mapFolder
    Util.MakePart("Cover_Upper_Mid_Right", Vector3.new(16, 10, 8), Vector3.new(28, 5, 62), Color3.fromRGB(40, 45, 60)).Parent = mapFolder
    Util.MakePart("Cover_Upper_Blue_Entrance", Vector3.new(10, 12, 18), Vector3.new(88, 6, 62), Color3.fromRGB(40, 45, 60)).Parent = mapFolder

    Util.MakePart("Cover_Lower_Red_Entrance", Vector3.new(10, 12, 18), Vector3.new(-88, 6, -62), Color3.fromRGB(40, 45, 60)).Parent = mapFolder
    Util.MakePart("Cover_Lower_Mid_Left", Vector3.new(16, 10, 8), Vector3.new(-28, 5, -62), Color3.fromRGB(40, 45, 60)).Parent = mapFolder
    Util.MakePart("Cover_Lower_Mid_Right", Vector3.new(16, 10, 8), Vector3.new(28, 5, -62), Color3.fromRGB(40, 45, 60)).Parent = mapFolder
    Util.MakePart("Cover_Lower_Blue_Entrance", Vector3.new(10, 12, 18), Vector3.new(88, 6, -62), Color3.fromRGB(40, 45, 60)).Parent = mapFolder

    local platforms = {
        Vector3.new(-38, 9, 48),
        Vector3.new(-38, 9, -48),
        Vector3.new(38, 9, 48),
        Vector3.new(38, 9, -48),
    }
    for i, pos in ipairs(platforms) do
        Util.MakePart("SniperPlatform_" .. i, Vector3.new(24, 2, 18), pos, Color3.fromRGB(30, 40, 55)).Parent = mapFolder
    end

    local jumpPads = {
        Vector3.new(-82, 2, 46),
        Vector3.new(-82, 2, -46),
        Vector3.new(82, 2, 46),
        Vector3.new(82, 2, -46),
    }
    for i, pos in ipairs(jumpPads) do
        Util.MakePart("JumpPad_" .. i, Vector3.new(10, 1, 10), pos, Color3.fromRGB(60, 120, 255), Enum.Material.Neon).Parent = mapFolder
    end

    local objectivesFolder = workspace:WaitForChild("PulseDeckArenaWorld"):WaitForChild("Objectives")
    for _, child in ipairs(objectivesFolder:GetChildren()) do
        child:Destroy()
    end

    local function createObjective(name: string, pos: Vector3, color: Color3)
        local model = Instance.new("Model")
        model.Name = name
        local core = Instance.new("Part")
        core.Name = "Core"
        core.Size = Vector3.new(8, 8, 8)
        core.Shape = Enum.PartType.Ball
        core.Material = Enum.Material.Neon
        core.Color = color
        core.Anchored = true
        core.Position = pos
        core.Parent = model
        model.PrimaryPart = core
        model.Parent = objectivesFolder
        return model
    end

    createObjective("RedCore", Config.MAP.RED_CORE, Config.RED_COLOR)
    createObjective("BlueCore", Config.MAP.BLUE_CORE, Config.BLUE_COLOR)

    for i, pos in ipairs(Config.MAP.RED_GENERATORS) do
        local gen = createObjective("RedGenerator" .. i, pos, Config.RED_COLOR)
        gen.PrimaryPart.Size = Vector3.new(6, 10, 6)
    end
    for i, pos in ipairs(Config.MAP.BLUE_GENERATORS) do
        local gen = createObjective("BlueGenerator" .. i, pos, Config.BLUE_COLOR)
        gen.PrimaryPart.Size = Vector3.new(6, 10, 6)
    end

    local laneMain = {
        Vector3.new(-125, 2, 0), Vector3.new(-82, 2, 0), Vector3.new(-38, 2, 0),
        Vector3.new(0, 2, 0), Vector3.new(38, 2, 0), Vector3.new(82, 2, 0), Vector3.new(125, 2, 0),
    }
    local laneUpper = {
        Vector3.new(-125, 2, 62), Vector3.new(-82, 2, 62), Vector3.new(-38, 2, 62),
        Vector3.new(0, 2, 62), Vector3.new(38, 2, 62), Vector3.new(82, 2, 62), Vector3.new(125, 2, 62),
    }
    local laneLower = {
        Vector3.new(-125, 2, -62), Vector3.new(-82, 2, -62), Vector3.new(-38, 2, -62),
        Vector3.new(0, 2, -62), Vector3.new(38, 2, -62), Vector3.new(82, 2, -62), Vector3.new(125, 2, -62),
    }

    local laneMainFolder = Instance.new("Folder")
    laneMainFolder.Name = "Lane_Main"
    laneMainFolder.Parent = waypointFolder
    for i, pos in ipairs(laneMain) do
        makeWaypoint(laneMainFolder, "Lane_Main_" .. i, pos, "Lane_Main", i)
    end

    local laneUpperFolder = Instance.new("Folder")
    laneUpperFolder.Name = "Lane_Upper"
    laneUpperFolder.Parent = waypointFolder
    for i, pos in ipairs(laneUpper) do
        makeWaypoint(laneUpperFolder, "Lane_Upper_" .. i, pos, "Lane_Upper", i)
    end

    local laneLowerFolder = Instance.new("Folder")
    laneLowerFolder.Name = "Lane_Lower"
    laneLowerFolder.Parent = waypointFolder
    for i, pos in ipairs(laneLower) do
        makeWaypoint(laneLowerFolder, "Lane_Lower_" .. i, pos, "Lane_Lower", i)
    end

    Lighting.ClockTime = 20
    Lighting.Brightness = 2
    Lighting.Ambient = Color3.fromRGB(55, 60, 80)
    Lighting.OutdoorAmbient = Color3.fromRGB(30, 35, 50)
    Lighting.EnvironmentDiffuseScale = 0.4
    Lighting.EnvironmentSpecularScale = 0.6
end

return MapBuilder
