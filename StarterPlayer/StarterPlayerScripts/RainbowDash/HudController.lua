local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Wait for remotes folder
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Remote events
local updateHealthEvent = remotes:WaitForChild("UpdateHealth")
local updateStatsEvent  = remotes:WaitForChild("UpdateStats")
local updatePvpEvent    = remotes:WaitForChild("UpdatePvpStatus")
local combatActionEvent = remotes:WaitForChild("CombatAction")

-- ─────────────────────────────────────────────
-- HUD Construction
-- ─────────────────────────────────────────────
local function buildHud()
    -- Remove any existing HUD to allow clean reconnect
    local existing = playerGui:FindFirstChild("HUD")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- ── Health Bar Container ──────────────────
    local healthContainer = Instance.new("Frame")
    healthContainer.Name = "HealthContainer"
    healthContainer.Size = UDim2.new(0, 300, 0, 36)
    healthContainer.Position = UDim2.new(0, 16, 1, -60)
    healthContainer.AnchorPoint = Vector2.new(0, 1)
    healthContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    healthContainer.BorderSizePixel = 0
    healthContainer.Parent = screenGui

    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 8)
    containerCorner.Parent = healthContainer

    -- Background track
    local healthBg = Instance.new("Frame")
    healthBg.Name = "HealthBg"
    healthBg.Size = UDim2.new(1, -8, 1, -8)
    healthBg.Position = UDim2.new(0, 4, 0, 4)
    healthBg.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
    healthBg.BorderSizePixel = 0
    healthBg.Parent = healthContainer

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 5)
    bgCorner.Parent = healthBg

    -- Actual fill bar
    local healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 5)
    fillCorner.Parent = healthFill

    -- Health label overlay
    local healthLabel = Instance.new("TextLabel")
    healthLabel.Name = "HealthLabel"
    healthLabel.Size = UDim2.new(1, 0, 1, 0)
    healthLabel.BackgroundTransparency = 1
    healthLabel.Text = "100 / 100"
    healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthLabel.TextScaled = true
    healthLabel.Font = Enum.Font.GothamBold
    healthLabel.ZIndex = 3
    healthLabel.Parent = healthBg

    -- ── Stats Panel ───────────────────────────
    local statsFrame = Instance.new("Frame")
    statsFrame.Name = "StatsFrame"
    statsFrame.Size = UDim2.new(0, 200, 0, 120)
    statsFrame.Position = UDim2.new(1, -216, 0, 16)
    statsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    statsFrame.BackgroundTransparency = 0.3
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = screenGui

    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 10)
    statsCorner.Parent = statsFrame

    local statsLayout = Instance.new("UIListLayout")
    statsLayout.Padding = UDim.new(0, 4)
    statsLayout.FillDirection = Enum.FillDirection.Vertical
    statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    statsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    statsLayout.Parent = statsFrame

    local statsPadding = Instance.new("UIPadding")
    statsPadding.PaddingLeft = UDim.new(0, 8)
    statsPadding.PaddingTop = UDim.new(0, 8)
    statsPadding.Parent = statsFrame

    -- Helper to make a stat label
    local function makeStatLabel(name, defaultText)
        local lbl = Instance.new("TextLabel")
        lbl.Name = name
        lbl.Size = UDim2.new(1, -8, 0, 22)
        lbl.BackgroundTransparency = 1
        lbl.Text = defaultText
        lbl.TextColor3 = Color3.fromRGB(210, 210, 255)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = statsFrame
        return lbl
    end

    local killsLabel  = makeStatLabel("KillsLabel",  "⚔  Kills: 0")
    local deathsLabel = makeStatLabel("DeathsLabel", "💀 Deaths: 0")
    local scoreLabel  = makeStatLabel("ScoreLabel",  "★  Score: 0")
    local pvpLabel    = makeStatLabel("PvpLabel",    "🔴 PvP: Off")

    -- ── Action Buttons ────────────────────────
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "ButtonContainer"
    buttonContainer.Size = UDim2.new(0, 260, 0, 60)
    buttonContainer.Position = UDim2.new(0.5, 0, 1, -16)
    buttonContainer.AnchorPoint = Vector2.new(0.5, 1)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = screenGui

    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.FillDirection = Enum.FillDirection.Horizontal
    buttonLayout.Padding = UDim.new(0, 10)
    buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    buttonLayout.Parent = buttonContainer

    -- Generic button factory
    local function makeButton(name, labelText, color)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, 120, 0, 50)
        btn.BackgroundColor3 = color
        btn.Text = labelText
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = buttonContainer

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 10)
        btnCorner.Parent = btn

        -- Hover / press tweens
        local hoverInfo  = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
        local normalColor = color
        local hoverColor  = Color3.new(
            math.min(color.R + 0.12, 1),
            math.min(color.G + 0.12, 1),
            math.min(color.B + 0.12, 1)
        )

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, hoverInfo, {BackgroundColor3 = hoverColor}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, hoverInfo, {BackgroundColor3 = normalColor}):Play()
        end)
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.08), {Size = UDim2.new(0, 112, 0, 44)}):Play()
        end)
        btn.MouseButton1Up:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.08), {Size = UDim2.new(0, 120, 0, 50)}):Play()
        end)

        return btn
    end

    local attackBtn = makeButton("AttackButton", "⚔ Attack", Color3.fromRGB(200, 60, 60))
    local pvpTogBtn = makeButton("PvpToggle",    "🔁 PvP",   Color3.fromRGB(60, 100, 200))

    -- ── Button Callbacks ──────────────────────
    attackBtn.Activated:Connect(function()
        combatActionEvent:FireServer("attack")
    end)

    pvpTogBtn.Activated:Connect(function()
        combatActionEvent:FireServer("togglePvp")
    end)

    -- ─────────────────────────────────────────
    -- Remote Event Listeners
    -- ─────────────────────────────────────────

    -- Health update: expects (currentHp, maxHp)
    updateHealthEvent.OnClientEvent:Connect(function(current, max)
        current = math.clamp(current, 0, max)
        local ratio = (max > 0) and (current / max) or 0

        -- Tween bar width
        TweenService:Create(healthFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Size = UDim2.new(ratio, 0, 1, 0)
        }):Play()

        -- Color shift: green → yellow → red
        local barColor
        if ratio > 0.5 then
            barColor = Color3.fromRGB(80, 220, 80)
        elseif ratio > 0.25 then
            barColor = Color3.fromRGB(220, 180, 40)
        else
            barColor = Color3.fromRGB(220, 60, 60)
        end
        TweenService:Create(healthFill, TweenInfo.new(0.3), {BackgroundColor3 = barColor}):Play()

        healthLabel.Text = string.format("%d / %d", math.floor(current), math.floor(max))
    end)

    -- Stats update: expects table {kills, deaths, score}
    updateStatsEvent.OnClientEvent:Connect(function(stats)
        if stats.kills  ~= nil then killsLabel.Text  = "⚔  Kills: "  .. stats.kills  end
        if stats.deaths ~= nil then deathsLabel.Text = "💀 Deaths: " .. stats.deaths end
        if stats.score  ~= nil then scoreLabel.Text  = "★  Score: "  .. stats.score  end
    end)

    -- PvP status update: expects (bool)
    updatePvpEvent.OnClientEvent:Connect(function(isEnabled)
        if isEnabled then
            pvpLabel.Text = "🔴 PvP: On"
            pvpLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        else
            pvpLabel.Text = "🟢 PvP: Off"
            pvpLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        end
    end)

    -- Sync health from character humanoid directly as a fallback
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.HealthChanged:Connect(function(hp)
                local maxHp = humanoid.MaxHealth
                updateHealthEvent:FireServer() -- optional server sync trigger
                -- Update locally for immediate feedback
                local ratio = (maxHp > 0) and (hp / maxHp) or 0
                TweenService:Create(healthFill, TweenInfo.new(0.2), {
                    Size = UDim2.new(ratio, 0, 1, 0)
                }):Play()
                healthLabel.Text = string.format("%d / %d", math.floor(hp), math.floor(maxHp))
            end)
        end
    end

    return screenGui
end

-- ─────────────────────────────────────────────
-- Initial Build
-- ─────────────────────────────────────────────
buildHud()

-- Rebuild HUD on character respawn (handles reconnect)
player.CharacterAdded:Connect(function(character)
    -- Small delay to let character fully load
    task.wait(0.5)
    buildHud()
end)
