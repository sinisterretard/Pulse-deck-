--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraClient = {}

CameraClient.Mode = "TPS"

function CameraClient.ToggleMode()
    CameraClient.Mode = (CameraClient.Mode == "TPS") and "FPS" or "TPS"
end

function CameraClient.Init()
    local camera = workspace.CurrentCamera
    if not camera then return end
    camera.CameraType = Enum.CameraType.Scriptable

    RunService.RenderStepped:Connect(function()
        local character = Players.LocalPlayer.Character
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root or not root:IsA("BasePart") then return end

        if CameraClient.Mode == "FPS" then
            local pos = root.Position + Vector3.new(0, 1.7, 0)
            camera.CFrame = CFrame.new(pos, pos + root.CFrame.LookVector)
        else
            local cameraPos = root.CFrame:PointToWorldSpace(Vector3.new(3, 3, 9))
            local lookAt = root.Position + Vector3.new(0, 2, 0) + root.CFrame.LookVector * 8
            camera.CFrame = CFrame.new(cameraPos, lookAt)
        end
    end)
end

return CameraClient
