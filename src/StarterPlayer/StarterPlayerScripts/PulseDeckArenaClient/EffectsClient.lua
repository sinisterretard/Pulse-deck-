--!strict
local Debris = game:GetService("Debris")

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))

local EffectsClient = {}

local function tracer(startPosition: Vector3, endPosition: Vector3, color: Color3?)
    local delta = endPosition - startPosition
    local distance = delta.Magnitude
    if distance <= 0 then return end

    local part = Instance.new("Part")
    part.Name = "PDA_Tracer"
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = color or Color3.fromRGB(255, 255, 255)
    part.Size = Vector3.new(0.08, 0.08, distance)
    part.CFrame = CFrame.new(startPosition, endPosition) * CFrame.new(0, 0, -distance / 2)
    part.Parent = workspace
    Debris:AddItem(part, 0.08)
end

local function sphere(position: Vector3, radius: number, color: Color3, duration: number)
    local part = Instance.new("Part")
    part.Name = "PDA_EffectSphere"
    part.Shape = Enum.PartType.Ball
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = 0.35
    part.Size = Vector3.new(radius, radius, radius)
    part.Position = position
    part.Parent = workspace
    Debris:AddItem(part, duration)
end

local function damageNumber(position: Vector3, amount: number)
    local anchor = Instance.new("Part")
    anchor.Name = "PDA_DamageNumberAnchor"
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Position = position
    anchor.Parent = workspace

    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.new(0, 90, 0, 28)
    gui.StudsOffset = Vector3.new(0, 2, 0)
    gui.AlwaysOnTop = true
    gui.Parent = anchor

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = tostring(amount)
    label.TextColor3 = Color3.fromRGB(255, 230, 120)
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    label.Parent = gui

    Debris:AddItem(anchor, 0.75)
end

function EffectsClient.Init()
    ClientCore.Events.Effects.Event:Connect(function(payload)
        if payload.effectType == "Tracer" or payload.effectType == "Beam" then
            tracer(payload.startPosition, payload.endPosition, payload.color)
        elseif payload.effectType == "Explosion" then
            sphere(payload.position, payload.radius or 12, Color3.fromRGB(255, 120, 60), payload.duration or 0.4)
        end
    end)

    ClientCore.Events.DamageNumber.Event:Connect(function(payload)
        damageNumber(payload.position, payload.amount)
    end)
end

return EffectsClient
