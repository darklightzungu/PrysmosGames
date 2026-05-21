local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local module = {}

-- Gamepass definitions relevant to a Rainbow Dash puzzle game
local GAMEPASSES = {
	HintBoost = {
		id = GAMEPASS_ID_PLACEHOLDER,
		name = "Hint Boost",
		description = "Receive double hints on every puzzle level.",
	},
	SkipPuzzle = {
		id = GAMEPASS_ID_PLACEHOLDER,
		name = "Puzzle Skip",
		description = "Unlocks the ability to skip one puzzle per session.",
	},
	ColorblindMode = {
		id = GAMEPASS_ID_PLACEHOLDER,
		name = "Colorblind Mode",
		description = "Activates high-contrast color schemes for all puzzles.",
	},
}

-- DevProduct definitions for one-time consumable purchases
local DEVPRODUCTS = {
	ExtraHints = {
		id = DEVPRODUCT_ID_PLACEHOLDER,
		name = "Extra Hints Pack",
		description = "Grants 5 additional hints immediately.",
		reward = 5, -- number of hints awarded
	},
	RainbowBoost = {
		id = DEVPRODUCT_ID_PLACEHOLDER,
		name = "Rainbow Boost",
		description = "Temporarily doubles your score multiplier for 10 minutes.",
		duration = 600, -- seconds
	},
	PuzzleSolveToken = {
		id = DEVPRODUCT_ID_PLACEHOLDER,
		name = "Solve Token",
		description = "Instantly solves the current puzzle without penalty.",
		reward = 1,
	},
}

module.GAMEPASSES = GAMEPASSES
module.DEVPRODUCTS = DEVPRODUCTS

-- Check if a player owns a named gamepass; returns bool and logs errors
function module.hasPremiumPass(player, passName)
	local passData = GAMEPASSES[passName]
	if not passData then
		warn("[Monetisation] Unknown pass name: " .. tostring(passName))
		return false
	end

	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passData.id)
	end)

	if not success then
		warn("[Monetisation] UserOwnsGamePassAsync failed for " .. player.Name .. ": " .. tostring(result))
		return false
	end

	return result
end

-- Build a reverse lookup: productId -> key, for use in ProcessReceipt
local productIdToKey = {}
for key, data in pairs(DEVPRODUCTS) do
	productIdToKey[data.id] = key
end

-- Handler functions per DevProduct; return true to confirm purchase
local receiptHandlers = {

	ExtraHints = function(player)
		-- Award hints via a leaderstats or data module; placeholder logic here
		local hints = player:FindFirstChild("Hints") -- example stat
		if hints then
			hints.Value = hints.Value + DEVPRODUCTS.ExtraHints.reward
		end
		print("[Monetisation] Awarded " .. DEVPRODUCTS.ExtraHints.reward .. " hints to " .. player.Name)
		return true
	end,

	RainbowBoost = function(player)
		-- Signal a boost to gameplay systems; placeholder logic here
		print("[Monetisation] Activated Rainbow Boost for " .. player.Name
			.. " (" .. DEVPRODUCTS.RainbowBoost.duration .. "s)")
		-- Fire a RemoteEvent or set an attribute to notify client/server systems
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		if remotes then
			local boostEvent = remotes:FindFirstChild("ActivateRainbowBoost")
			if boostEvent then
				boostEvent:FireClient(player, DEVPRODUCTS.RainbowBoost.duration)
			end
		end
		return true
	end,

	PuzzleSolveToken = function(player)
		-- Grant a solve token; placeholder logic here
		print("[Monetisation] Granted Solve Token to " .. player.Name)
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		if remotes then
			local tokenEvent = remotes:FindFirstChild("GrantSolveToken")
			if tokenEvent then
				tokenEvent:FireClient(player, DEVPRODUCTS.PuzzleSolveToken.reward)
			end
		end
		return true
	end,
}

-- ProcessReceipt is called by Roblox when a DevProduct purchase is completed
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local productKey = productIdToKey[receiptInfo.ProductId]

	if not productKey then
		-- Unknown product; do not grant and do not confirm (investigate manually)
		warn("[Monetisation] Unknown ProductId: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Wait briefly for the player to be fully loaded in the game
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player left mid-purchase; defer so Roblox retries on rejoin
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local handler = receiptHandlers[productKey]
	if not handler then
		warn("[Monetisation] No handler for product: " .. productKey)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success, result = pcall(handler, player)

	if success and result then
		-- Confirm purchase; Roblox will not re-fire this receipt
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		-- Something went wrong; allow Roblox to retry later
		warn("[Monetisation] Handler error for " .. productKey .. ": " .. tostring(result))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return module