-- Monetisation.lua
-- Route Rage Terrain — GamePass & DevProduct wiring
-- Place in: ServerScriptService

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Monetisation = {}

-- ── Product IDs ──────────────────────────────────────────────────────────────
local GAMEPASSES = {
	SpeedDemon   = GAMEPASS_ID_PLACEHOLDER,  -- 299 Robux — permanent top-speed boost for all vehicles
	VehiclePack  = GAMEPASS_ID_PLACEHOLDER,  -- 499 Robux — unlocks exclusive vehicle skin bundle
	DoubleCoins  = GAMEPASS_ID_PLACEHOLDER,  -- 199 Robux — 2× coin earnings from all race finishes
}

local DEVPRODUCTS = {
	CoinBoost_500  = DEVPRODUCT_ID_PLACEHOLDER,  -- 75 Robux  — instantly grants 500 coins
	CoinBoost_1500 = DEVPRODUCT_ID_PLACEHOLDER,  -- 175 Robux — instantly grants 1 500 coins
	Nitro_Refill   = DEVPRODUCT_ID_PLACEHOLDER,  -- 50 Robux  — fully refills nitro tank mid-race
}

-- ── Remotes (created if absent) ──────────────────────────────────────────────
local function getOrCreateRemote(name, class)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(class)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local grantCoinsEvent  = getOrCreateRemote("GrantCoins",        "RemoteEvent")
local refillNitroEvent = getOrCreateRemote("RefillNitro",       "RemoteEvent")
local applyVehiclePack = getOrCreateRemote("ApplyVehiclePack",  "RemoteEvent")
local applySpeedBoost  = getOrCreateRemote("ApplySpeedBoost",   "RemoteEvent")

-- ── Ownership cache ──────────────────────────────────────────────────────────
local ownershipCache = {}  -- [userId][passId] = bool

-- Checks (and caches) whether a player owns the named GamePass.
local function hasPremiumPass(player, passName)
	local passId = GAMEPASSES[passName]
	if not passId then
		warn("[Monetisation] Unknown GamePass name:", passName)
		return false
	end

	local uid = player.UserId
	ownershipCache[uid] = ownershipCache[uid] or {}

	if ownershipCache[uid][passId] ~= nil then
		return ownershipCache[uid][passId]  -- return cached result
	end

	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(uid, passId)
	end)

	local owns = ok and result or false
	ownershipCache[uid][passId] = owns
	return owns
end

Monetisation.hasPremiumPass = hasPremiumPass

-- ── Prompt helpers ───────────────────────────────────────────────────────────
function Monetisation.promptGamePass(player, passName)
	local id = GAMEPASSES[passName]
	if not id then warn("[Monetisation] Unknown GamePass:", passName) return end
	MarketplaceService:PromptGamePassPurchase(player, id)
end

function Monetisation.promptDevProduct(player, productName)
	local id = DEVPRODUCTS[productName]
	if not id then warn("[Monetisation] Unknown DevProduct:", productName) return end
	MarketplaceService:PromptProductPurchase(player, id)
end

-- ── ProcessReceipt ───────────────────────────────────────────────────────────
local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	-- If the player has left, retry later
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	if productId == DEVPRODUCTS.CoinBoost_500 then
		-- Tell the client (and any listening server scripts) to award 500 coins
		grantCoinsEvent:FireClient(player, 500)

	elseif productId == DEVPRODUCTS.CoinBoost_1500 then
		-- Award 1 500 coins
		grantCoinsEvent:FireClient(player, 1500)

	elseif productId == DEVPRODUCTS.Nitro_Refill then
		-- Signal client to instantly refill the player's nitro gauge
		refillNitroEvent:FireClient(player)

	else
		warn("[Monetisation] Unhandled DevProduct ID:", productId)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

-- ── Apply GamePass perks on spawn ────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	-- Invalidate cache on join so we always fetch fresh data
	ownershipCache[player.UserId] = nil

	player.CharacterAdded:Connect(function()
		-- Vehicle skin bundle
		if hasPremiumPass(player, "VehiclePack") then
			applyVehiclePack:FireClient(player)
		end

		-- Persistent top-speed boost
		if hasPremiumPass(player, "SpeedDemon") then
			applySpeedBoost:FireClient(player)
		end
		-- DoubleCoins is checked server-side at coin-award time via hasPremiumPass
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	-- Free memory when player leaves
	ownershipCache[player.UserId] = nil
end)

-- ── Exports ──────────────────────────────────────────────────────────────────
Monetisation.GAMEPASSES  = GAMEPASSES
Monetisation.DEVPRODUCTS = DEVPRODUCTS

return Monetisation