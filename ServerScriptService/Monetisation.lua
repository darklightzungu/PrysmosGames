local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- DataStore for tracking purchase receipts (prevent duplicate processing)
local purchaseStore = DataStoreService:GetDataStore("route_rage_purchases")

local Monetisation = {}

-- ============================================================
-- GAMEPASS DEFINITIONS
-- ============================================================
Monetisation.GAMEPASSES = {
	DoubleXP = {
		id = GAMEPASS_ID_PLACEHOLDER,
		name = "DoubleXP",
		description = "Earn 2x XP from every race and takedown",
	},
	NitroBoost = {
		id = GAMEPASS_ID_PLACEHOLDER,
		name = "NitroBoost",
		description = "Unlocks permanent nitro boost ability for all vehicles",
	},
	VIPGarage = {
		id = GAMEPASS_ID_PLACEHOLDER,
		name = "VIPGarage",
		description = "Access to exclusive VIP vehicles and cosmetics",
	},
}

-- ============================================================
-- DEVPRODUCT DEFINITIONS
-- ============================================================
Monetisation.DEVPRODUCTS = {
	CashBundle = {
		id = DEVPRODUCT_ID_PLACEHOLDER,
		name = "CashBundle",
		description = "Instantly receive 5,000 in-game cash",
		cashReward = 5000,
	},
	RepairKit = {
		id = DEVPRODUCT_ID_PLACEHOLDER,
		name = "RepairKit",
		description = "Fully repair your vehicle and restore all armour",
		cashReward = 0,
	},
	TurboFuel = {
		id = DEVPRODUCT_ID_PLACEHOLDER,
		name = "TurboFuel",
		description = "Grants 10 turbo charges to use across any session",
		turboCharges = 10,
	},
}

-- Build a quick lookup from product ID to product config
local productIdMap = {}
for _, product in pairs(Monetisation.DEVPRODUCTS) do
	productIdMap[product.id] = product
end

-- ============================================================
-- hasPremiumPass
-- Returns true if the player owns the named gamepass, false otherwise
-- ============================================================
function Monetisation.hasPremiumPass(player, passName)
	local passData = Monetisation.GAMEPASSES[passName]
	if not passData then
		warn("[Monetisation] Unknown pass name: " .. tostring(passName))
		return false
	end

	local success, owned = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passData.id)
	end)

	if not success then
		warn("[Monetisation] UserOwnsGamePassAsync failed for " .. player.Name .. ": " .. tostring(owned))
		return false
	end

	return owned
end

-- ============================================================
-- Helper: grant DevProduct rewards to a player
-- ============================================================
local function grantProductRewards(player, product)
	if product.name == "CashBundle" then
		-- Fire to a cash-update RemoteEvent or adjust leaderstats directly
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local cash = leaderstats:FindFirstChild("Cash")
			if cash then
				cash.Value = cash.Value + product.cashReward
			end
		end

	elseif product.name == "RepairKit" then
		-- Signal the vehicle system to fully repair this player
		local repairEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
			and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("RepairVehicle")
		if repairEvent then
			repairEvent:FireClient(player)
		end

	elseif product.name == "TurboFuel" then
		-- Signal the turbo system to grant charges
		local turboEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
			and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("GrantTurbo")
		if turboEvent then
			turboEvent:FireClient(player, product.turboCharges)
		end
	end
end

-- ============================================================
-- ProcessReceipt handler
-- Roblox calls this when a DevProduct purchase is completed
-- ============================================================
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId

	-- Prevent duplicate processing using a DataStore receipt key
	local receiptKey = "receipt_" .. tostring(purchaseId)
	local alreadyProcessed = false

	local checkSuccess, checkResult = pcall(function()
		return purchaseStore:GetAsync(receiptKey)
	end)

	if checkSuccess and checkResult == true then
		alreadyProcessed = true
	end

	if alreadyProcessed then
		-- Already granted; acknowledge without re-granting
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Find the product config
	local product = productIdMap[productId]
	if not product then
		warn("[Monetisation] Received unknown product ID: " .. tostring(productId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Find the player instance (they may have left)
	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		-- Player not in server; retry next time they join
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Grant the rewards
	local grantSuccess, grantErr = pcall(function()
		grantProductRewards(player, product)
	end)

	if not grantSuccess then
		warn("[Monetisation] Failed to grant rewards for " .. product.name .. ": " .. tostring(grantErr))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Mark receipt as processed in DataStore
	local saveSuccess, saveErr = pcall(function()
		purchaseStore:SetAsync(receiptKey, true)
	end)

	if not saveSuccess then
		warn("[Monetisation] Failed to save receipt " .. receiptKey .. ": " .. tostring(saveErr))
		-- Do not grant again but we already did; still acknowledge to avoid double charge
		-- In production consider a retry queue here
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return Monetisation