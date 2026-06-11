-- Monetisation.lua — cosmetic rainbow trail (kid-safe, no pay-to-win)
-- ServerScriptService Script

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RAINBOW_TRAIL_PASS = "GAMEPASS_ID_PLACEHOLDER"

local function ownsRainbowTrail(player: Player): boolean
	if RAINBOW_TRAIL_PASS == "GAMEPASS_ID_PLACEHOLDER" then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, tonumber(RAINBOW_TRAIL_PASS))
	end)
	return ok and owns
end

local function attachTrail(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	if hrp:FindFirstChild("RainbowTrail") then
		return
	end
	local att0 = Instance.new("Attachment")
	att0.Name = "TrailA0"
	att0.Position = Vector3.new(0, -1, 0)
	att0.Parent = hrp
	local att1 = Instance.new("Attachment")
	att1.Name = "TrailA1"
	att1.Position = Vector3.new(0, 1, 0)
	att1.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Name = "RainbowTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = 0.6
	trail.LightEmission = 1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 105, 180)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(144, 238, 144)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(135, 206, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(186, 85, 211)),
	})
	trail.Parent = hrp
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		if ownsRainbowTrail(player) then
			attachTrail(char)
		end
	end)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and tostring(passId) == RAINBOW_TRAIL_PASS and player.Character then
		attachTrail(player.Character)
	end
end)
