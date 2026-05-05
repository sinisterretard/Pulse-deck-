--!strict
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))
local CameraClient = require(script.Parent:WaitForChild("CameraClient"))

local InputClient = {}

local firing = false
local lastFireSent = 0

local function sendFire()
    local camera = workspace.CurrentCamera
    if not camera then return end
    ClientCore.Fire("RequestFire", {
        origin = camera.CFrame.Position,
        direction = camera.CFrame.LookVector,
        clientTime = os.clock(),
    })
end

function InputClient.Init()
    if UserInputService.TouchEnabled then
        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        local gui = playerGui:WaitForChild("PulseDeckArenaGui")
        local hud = gui:WaitForChild("HUD")

        local function mobileButton(text: string, position: UDim2, color: Color3)
            local button = Instance.new("TextButton")
            button.Text = text
            button.Size = UDim2.new(0, 92, 0, 92)
            button.Position = position
            button.BackgroundColor3 = color
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.Font = Enum.Font.GothamBlack
            button.TextScaled = true
            button.Parent = hud
            return button
        end

        local fireButton = mobileButton("FIRE", UDim2.new(1, -112, 1, -164), Color3.fromRGB(210, 55, 55))
        fireButton.MouseButton1Down:Connect(function()
            firing = true
            sendFire()
        end)
        fireButton.MouseButton1Up:Connect(function()
            firing = false
        end)

        local abilityButton = mobileButton("ABILITY", UDim2.new(1, -214, 1, -164), Color3.fromRGB(60, 120, 230))
        abilityButton.MouseButton1Click:Connect(function()
            local camera = workspace.CurrentCamera
            ClientCore.Fire("RequestAbility", { direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1) })
        end)

        local reloadButton = mobileButton("RELOAD", UDim2.new(1, -112, 1, -266), Color3.fromRGB(90, 90, 130))
        reloadButton.MouseButton1Click:Connect(function()
            ClientCore.Fire("RequestReload", {})
        end)

        local cameraButton = mobileButton("CAM", UDim2.new(1, -214, 1, -266), Color3.fromRGB(80, 170, 150))
        cameraButton.MouseButton1Click:Connect(function()
            CameraClient.ToggleMode()
        end)
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            firing = true
            sendFire()
        elseif input.KeyCode == Enum.KeyCode.R then
            ClientCore.Fire("RequestReload", {})
        elseif input.KeyCode == Enum.KeyCode.Q then
            local camera = workspace.CurrentCamera
            ClientCore.Fire("RequestAbility", {
                direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1),
            })
        elseif input.KeyCode == Enum.KeyCode.One then
            ClientCore.Fire("RequestSwitchHero", { slot = 1 })
        elseif input.KeyCode == Enum.KeyCode.Two then
            ClientCore.Fire("RequestSwitchHero", { slot = 2 })
        elseif input.KeyCode == Enum.KeyCode.Three then
            ClientCore.Fire("RequestSwitchHero", { slot = 3 })
        elseif input.KeyCode == Enum.KeyCode.Four then
            ClientCore.Fire("RequestSwitchHero", { slot = 4 })
        elseif input.KeyCode == Enum.KeyCode.Five then
            ClientCore.Fire("RequestSwitchHero", { slot = 5 })
        elseif input.KeyCode == Enum.KeyCode.V then
            CameraClient.ToggleMode()
        elseif input.KeyCode == Enum.KeyCode.Tab then
            ClientCore.Fire("RequestScoreboard", {})
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            firing = false
        end
    end)

    RunService.RenderStepped:Connect(function()
        if firing and os.clock() - lastFireSent >= 0.06 then
            lastFireSent = os.clock()
            sendFire()
        end
    end)
end

return InputClient
