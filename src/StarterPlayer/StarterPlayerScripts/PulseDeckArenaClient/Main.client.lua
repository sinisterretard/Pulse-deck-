--!strict
local ClientCore = require(script.Parent:WaitForChild("ClientCore"))
local UIClient = require(script.Parent:WaitForChild("UIClient"))
local CameraClient = require(script.Parent:WaitForChild("CameraClient"))
local InputClient = require(script.Parent:WaitForChild("InputClient"))
local EffectsClient = require(script.Parent:WaitForChild("EffectsClient"))

ClientCore.Init()
UIClient.Init()
CameraClient.Init()
InputClient.Init()
EffectsClient.Init()

print("PULSE DECK ARENA client ready")
