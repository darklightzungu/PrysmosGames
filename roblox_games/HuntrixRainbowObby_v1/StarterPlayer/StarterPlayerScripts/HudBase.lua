-- HudBase.lua — friendly star + stage HUD for young players
-- StarterPlayerScripts LocalScript

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateStars = remotes:WaitForChild("UpdateStars")
local updateStage = remotes:WaitForChild("UpdateStage")
local showMessage = remotes:WaitForChild("ShowMessage")
local carpetBoost = remotes:WaitForChild("CarpetBoost")

local hud = Instance.new("ScreenGui")
hud.Name = "HuntrixHUD"
hud.ResetOnSpawn = false
hud.Parent = playerGui

local starsLabel = Instance.new("TextLabel")
starsLabel.Name = "Stars"
starsLabel.Size = UDim2.new(0, 220, 0, 48)
starsLabel.Position = UDim2.new(0, 16, 0, 16)
starsLabel.BackgroundTransparency = 0.3
starsLabel.BackgroundColor3 = Color3.fromRGB(255, 182, 193)
starsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
starsLabel.Font = Enum.Font.GothamBold
starsLabel.TextSize = 22
starsLabel.Text = "Stars: 0 ✨"
starsLabel.Parent = hud

local stageLabel = Instance.new("TextLabel")
stageLabel.Name = "Stage"
stageLabel.Size = UDim2.new(0, 320, 0, 40)
stageLabel.Position = UDim2.new(0, 16, 0, 70)
stageLabel.BackgroundTransparency = 0.4
stageLabel.BackgroundColor3 = Color3.fromRGB(186, 85, 211)
stageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
stageLabel.Font = Enum.Font.Gotham
stageLabel.TextSize = 18
stageLabel.Text = "Stage: Sparkle Start"
stageLabel.Parent = hud

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.Size = UDim2.new(0, 400, 0, 44)
toast.Position = UDim2.new(0.5, -200, 1, -80)
toast.BackgroundTransparency = 0.2
toast.BackgroundColor3 = Color3.fromRGB(135, 206, 250)
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.Font = Enum.Font.GothamBold
toast.TextSize = 20
toast.Text = ""
toast.Visible = false
toast.Parent = hud

local function flashToast(msg: string)
	toast.Text = msg
	toast.Visible = true
	task.delay(2.5, function()
		toast.Visible = false
	end)
end

updateStars.OnClientEvent:Connect(function(count)
	starsLabel.Text = "Stars: " .. tostring(count) .. " ✨"
end)

updateStage.OnClientEvent:Connect(function(name, index, total)
	stageLabel.Text = string.format("Stage %d/%d: %s", index, total, name)
end)

showMessage.OnClientEvent:Connect(flashToast)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		carpetBoost:FireServer()
	end
end)
