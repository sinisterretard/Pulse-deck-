--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("PulseDeckArena"):WaitForChild("Shared")
local HeroConfig = require(sharedRoot:WaitForChild("HeroConfig"))

local ClientCore = require(script.Parent:WaitForChild("ClientCore"))

local UIClient = {}

UIClient.Gui = nil
UIClient.MainMenu = nil
UIClient.DeckSelect = nil
UIClient.HUD = nil
UIClient.Scoreboard = nil
UIClient.PostMatch = nil
UIClient.SelectedDeck = {}
UIClient.HeroButtons = {}

local function makeScreen(gui: ScreenGui, name: string, color: Color3): Frame
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = color
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = gui
    return frame
end

local function makeLabel(parent: Instance, text: string, size: UDim2, pos: UDim2): TextLabel
    local label = Instance.new("TextLabel")
    label.Text = text
    label.Size = size
    label.Position = pos
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(235, 240, 255)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = parent
    return label
end

local function makeButton(parent: Instance, text: string, size: UDim2, pos: UDim2): TextButton
    local button = Instance.new("TextButton")
    button.Text = text
    button.Size = size
    button.Position = pos
    button.BackgroundColor3 = Color3.fromRGB(35, 180, 140)
    button.TextColor3 = Color3.fromRGB(10, 10, 12)
    button.Font = Enum.Font.GothamBlack
    button.TextScaled = true
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button
    return button
end

function UIClient.Show(screenName: string)
    for _, screen in ipairs({UIClient.MainMenu, UIClient.DeckSelect, UIClient.HUD, UIClient.Scoreboard, UIClient.PostMatch}) do
        if screen then
            screen.Visible = screen.Name == screenName
        end
    end
end

function UIClient.BuildMainMenu()
    local screen = UIClient.MainMenu
    makeLabel(screen, "PULSE DECK ARENA", UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0, 40))
    makeLabel(screen, "Core Duel MVP", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 122))
    local progression = ClientCore.State.progression
    makeLabel(screen, "Wins " .. tostring(progression.Wins or 0) .. " | Coins " .. tostring(progression.Coins or 0) .. " | XP " .. tostring(progression.XP or 0), UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 160))

    local play = makeButton(screen, "PLAY", UDim2.new(0, 220, 0, 60), UDim2.new(0.5, -110, 0.5, -40))
    play.MouseButton1Click:Connect(function()
        ClientCore.Fire("RequestJoinQueue", {})
        UIClient.Show("DeckSelect")
    end)

    local deck = makeButton(screen, "DECK", UDim2.new(0, 160, 0, 44), UDim2.new(0.5, -80, 0.5, 36))
    deck.MouseButton1Click:Connect(function()
        UIClient.Show("DeckSelect")
    end)

    makeLabel(screen, "Original Roblox arena shooter prototype. No external assets.", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 1, -42))
end

function UIClient.BuildDeckSelect()
    local screen = UIClient.DeckSelect
    makeLabel(screen, "SELECT 5 HEROES", UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 20))

    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, -40, 1, -150)
    grid.Position = UDim2.new(0, 20, 0, 90)
    grid.BackgroundTransparency = 1
    grid.Parent = screen

    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.new(0, 220, 0, 115)
    layout.CellPadding = UDim2.new(0, 12, 0, 12)
    layout.Parent = grid

    for heroId, hero in pairs(HeroConfig) do
        local card = Instance.new("TextButton")
        card.Name = heroId
        card.Text = hero.displayName .. "\n" .. hero.role .. " | HP " .. tostring(hero.maxHealth)
        card.TextColor3 = Color3.fromRGB(245, 245, 245)
        card.Font = Enum.Font.GothamBold
        card.TextScaled = true
        card.BackgroundColor3 = hero.primaryColor
        card.Parent = grid

        card.MouseButton1Click:Connect(function()
            local selected = table.find(UIClient.SelectedDeck, heroId)
            if selected then
                table.remove(UIClient.SelectedDeck, selected)
                card.BackgroundTransparency = 0
            elseif #UIClient.SelectedDeck < 5 then
                table.insert(UIClient.SelectedDeck, heroId)
                card.BackgroundTransparency = 0.35
            end
        end)
    end

    for _, heroId in ipairs(ClientCore.State.selectedDeck) do
        table.insert(UIClient.SelectedDeck, heroId)
    end

    local confirm = makeButton(screen, "CONFIRM", UDim2.new(0, 220, 0, 52), UDim2.new(0.5, -110, 1, -64))
    confirm.MouseButton1Click:Connect(function()
        if #UIClient.SelectedDeck == 5 then
            ClientCore.Fire("RequestDeckUpdate", { heroIds = UIClient.SelectedDeck })
            ClientCore.Fire("RequestStartMatch", {})
            UIClient.Show("HUD")
        end
    end)
end

function UIClient.BuildHUD()
    local screen = UIClient.HUD
    screen.BackgroundTransparency = 1

    UIClient.ScoreLabel = makeLabel(screen, "RED 0 : 0 BLUE", UDim2.new(0, 320, 0, 38), UDim2.new(0.5, -160, 0, 10))
    UIClient.TimerLabel = makeLabel(screen, "240", UDim2.new(0, 120, 0, 30), UDim2.new(0.5, -60, 0, 52))
    UIClient.HealthLabel = makeLabel(screen, "HP", UDim2.new(0, 180, 0, 34), UDim2.new(0, 20, 1, -70))
    UIClient.AmmoLabel = makeLabel(screen, "Ammo", UDim2.new(0, 160, 0, 34), UDim2.new(1, -180, 1, -70))
    UIClient.ObjectiveLabel = makeLabel(screen, "Objectives", UDim2.new(0, 360, 0, 28), UDim2.new(0.5, -180, 0, 86))

    UIClient.Killfeed = Instance.new("Frame")
    UIClient.Killfeed.Size = UDim2.new(0, 280, 0, 130)
    UIClient.Killfeed.Position = UDim2.new(1, -300, 0, 84)
    UIClient.Killfeed.BackgroundTransparency = 1
    UIClient.Killfeed.Parent = screen

    local heroBar = Instance.new("Frame")
    heroBar.Size = UDim2.new(0, 500, 0, 52)
    heroBar.Position = UDim2.new(0.5, -250, 1, -62)
    heroBar.BackgroundTransparency = 1
    heroBar.Parent = screen

    for i = 1, 5 do
        local button = makeButton(heroBar, tostring(i), UDim2.new(0, 92, 0, 44), UDim2.new(0, (i - 1) * 100, 0, 0))
        button.MouseButton1Click:Connect(function()
            ClientCore.Fire("RequestSwitchHero", { slot = i })
        end)
        UIClient.HeroButtons[i] = button
    end
end

function UIClient.BindState()
    ClientCore.Events.MatchStateChanged.Event:Connect(function(payload)
        if payload.state == "Lobby" then
            UIClient.Show("MainMenu")
        elseif payload.state == "DeckSelect" then
            UIClient.Show("DeckSelect")
        elseif payload.state == "ActiveMatch" or payload.state == "SuddenDeath" or payload.state == "MatchCountdown" then
            UIClient.Show("HUD")
        elseif payload.state == "PostMatch" then
            UIClient.PostMatch:ClearAllChildren()
            local winner = payload.winner and (tostring(payload.winner) .. " WINS") or "MATCH COMPLETE"
            makeLabel(UIClient.PostMatch, winner, UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.35, 0))
            makeLabel(UIClient.PostMatch, "Returning to menu soon", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0.48, 0))
            UIClient.Show("PostMatch")
        end
        if UIClient.TimerLabel then
            UIClient.TimerLabel.Text = tostring(math.floor(payload.timerRemaining or 0))
        end
    end)

    ClientCore.Events.ScoreChanged.Event:Connect(function(payload)
        if UIClient.ScoreLabel then
            UIClient.ScoreLabel.Text = "RED " .. tostring(math.floor(payload.Red or 0)) .. " : " .. tostring(math.floor(payload.Blue or 0)) .. " BLUE"
        end
    end)

    ClientCore.Events.HeroStateChanged.Event:Connect(function(payload)
        local localUserId = Players.LocalPlayer.UserId
        for _, hero in pairs(payload.heroes or {}) do
            if hero.ownerUserId == localUserId then
                local button = UIClient.HeroButtons[hero.slot]
                if button then
                    button.Text = tostring(hero.slot) .. " " .. hero.heroId
                    button.BackgroundColor3 = hero.isControlled and Color3.fromRGB(80, 220, 120) or (hero.alive and Color3.fromRGB(35, 180, 140) or Color3.fromRGB(130, 35, 45))
                end
                if hero.isControlled then
                    UIClient.HealthLabel.Text = "HP " .. tostring(math.floor(hero.health)) .. " / " .. tostring(math.floor(hero.maxHealth))
                    UIClient.AmmoLabel.Text = "Ammo " .. tostring(math.floor(hero.ammo))
                end
            end
        end
    end)

    ClientCore.Events.ObjectiveStateChanged.Event:Connect(function(payload)
        local redCore = "?"
        local blueCore = "?"
        for _, objective in pairs(payload.objectives or {}) do
            if objective.objectiveType == "Core" and objective.teamId == "Red" then
                redCore = tostring(math.floor(objective.health))
            elseif objective.objectiveType == "Core" and objective.teamId == "Blue" then
                blueCore = tostring(math.floor(objective.health))
            end
        end
        if UIClient.ObjectiveLabel then
            UIClient.ObjectiveLabel.Text = "Red Core " .. redCore .. " | Blue Core " .. blueCore
        end
    end)

    ClientCore.Events.Killfeed.Event:Connect(function(payload)
        if not UIClient.Killfeed then return end
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 22)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 235, 210)
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        label.Text = tostring(payload.killerName) .. " eliminated " .. tostring(payload.victimName)
        label.Parent = UIClient.Killfeed
        task.delay(4, function()
            if label then
                label:Destroy()
            end
        end)
    end)

    ClientCore.Events.Scoreboard.Event:Connect(function(payload)
        if not UIClient.Scoreboard then return end
        UIClient.Scoreboard:ClearAllChildren()
        makeLabel(UIClient.Scoreboard, "SCOREBOARD", UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 20))
        local y = 90
        for _, row in ipairs(payload.players or {}) do
            makeLabel(UIClient.Scoreboard, tostring(row.name) .. " | " .. tostring(row.teamId) .. " | Score " .. tostring(math.floor(row.score or 0)), UDim2.new(1, -80, 0, 28), UDim2.new(0, 40, 0, y))
            y += 32
        end
        UIClient.Scoreboard.Visible = true
        task.delay(3, function()
            if UIClient.Scoreboard then
                UIClient.Scoreboard.Visible = false
            end
        end)
    end)
end

function UIClient.Init()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = playerGui:FindFirstChild("PulseDeckArenaGui")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "PulseDeckArenaGui"
        gui.ResetOnSpawn = false
        gui.Parent = playerGui
    end

    UIClient.Gui = gui
    UIClient.MainMenu = makeScreen(gui, "MainMenu", Color3.fromRGB(10, 12, 18))
    UIClient.DeckSelect = makeScreen(gui, "DeckSelect", Color3.fromRGB(10, 12, 18))
    UIClient.HUD = makeScreen(gui, "HUD", Color3.fromRGB(0, 0, 0))
    UIClient.Scoreboard = makeScreen(gui, "Scoreboard", Color3.fromRGB(5, 7, 12))
    UIClient.PostMatch = makeScreen(gui, "PostMatch", Color3.fromRGB(10, 12, 18))

    UIClient.BuildMainMenu()
    UIClient.BuildDeckSelect()
    UIClient.BuildHUD()
    makeLabel(UIClient.Scoreboard, "SCOREBOARD", UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 20))
    makeLabel(UIClient.PostMatch, "MATCH COMPLETE", UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.35, 0))
    UIClient.BindState()
    UIClient.Show("MainMenu")
end

return UIClient
