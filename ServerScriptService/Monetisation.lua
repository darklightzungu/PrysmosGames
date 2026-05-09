-- Monetisation.lua
-- Route Rage — GamePass & DevProduct wiring
-- Place in: ServerScriptService

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Monetisation = {}

-- ── Product IDs ──────────────────────────────────────────────────────────────

local GAMEPASSES = {
	SpeedDemon    = GAMEPASS_ID_PLACEHOLDER,  -- 299 Robux — permanent top-speed boost for all vehicles
	RoadRageVIP   = GAMEPASS_ID_PLACEHOLDER,  -- 499 Robux — exclusive VIP vehicle skins + bonus XP
	NitroInfinite = GAMEPASS_ID_PLACEHOLDER,  -- 199 Robux — unlimited nitro refill rate
}

local DEVPRODUCTS = {
	CashBundle_Small  = DEVPRODUCT_ID_PLACEHOLDER,  -- 99  Robux — 5 000 in-game cash
	CashBundle_Large  = DEVPRODUCT_ID_PLACEHOLDER,  -- 249 Robux — 15 000 in-game cash
	RespawnShield     = DEVPRODUCT_ID_PLACEHOLDER,  -- 49  Robux — one-time respawn shield for current session
}

-- Export tables so callers can reference IDs without hard-coding them
Monetisation.GAMEPASSES   = GAMEPASSES
Monetisation.DEVPRODUCTS  = DEVPRODUCTS

-- ── Ensure Remotes folder exists ─────────────────────────────────────────────
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

-- Helper: get or create a RemoteEvent inside Remotes
local function getRemote(name)
	local re = remotes:FindFirstChild(name)
	if not re then
		re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = remotes
	end
	return re
end

-- Pre-declare events used across handlers
local grantCashEvent      = getRemote("GrantCash")          -- server → client cash UI update
local applySpeedBoostEvent= getRemote("ApplySpeedBoost")    -- server → client speed perk
local applyVIPSkinEvent   = getRemote("ApplyVIPSkin")       -- server → client VIP skin
local applyNitroBoostEvent= getRemote("ApplyNitroBoost")    -- server → client nitro perk
local grantShieldEvent    = getRemote("GrantRespawnShield") -- server → client shield

-- ── Ownership cache ──────────────────────────────────────────────────────────
local ownershipCache = {}  -- [userId][passId] = true/false

-- Checks whether a player owns a named GamePass; caches the result.
local function hasPremiumPass(player, passName)
	local passId = GAMEPASSES[passName]
	if not passId then
		warn("[Monetisation] Unknown GamePass name:", passName)
		return false
	end

	local uid = player.UserId
	ownershipCache[uid] = ownershipCache[uid] or {}

	-- Return cached value if available
	if ownershipCache[uid][passId] ~= nil then
		return ownershipCache[uid][passId]
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(uid, passId)
	end)

	local result = ok and owns or false
	ownershipCache[uid][passId] = result
	return result
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
	-- If player left, defer — Roblox will retry on next join
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	if productId == DEVPRODUCTS.CashBundle_Small then
		-- Award 5 000 in-game cash; tell client to refresh cash display
		grantCashEvent:FireClient(player, 5000)

	elseif productId == DEVPRODUCTS.CashBundle_Large then
		-- Award 15 000 in-game cash
		grantCashEvent:FireClient(player, 15000)

	elseif productId == DEVPRODUCTS.RespawnShield then
		-- Grant a one-use respawn shield for this session
		grantShieldEvent:FireClient(player)

	else
		warn("[Monetisation] Unhandled ProductId:", productId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

-- ── Apply GamePass perks on spawn ────────────────────────────────────────────
local function applyPassPerks(player)
	-- SpeedDemon: permanent vehicle speed boost
	if hasPremiumPass(player, "SpeedDemon") then
		applySpeedBoostEvent:FireClient(player)
	end

	-- RoadRageVIP: exclusive skin set
	if hasPremiumPass(player, "RoadRageVIP") then
		applyVIPSkinEvent:FireClient(player)
	end

	-- NitroInfinite: enhanced nitro regeneration
	if hasPremiumPass(player, "NitroInfinite") then
		applyNitroBoostEvent:FireClient(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	-- Re-apply perks each time character spawns (e.g. after respawn)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)  -- brief wait for character to fully load
		applyPassPerks(player)
	end)
end)

-- Clean up ownership cache when player leaves to prevent memory leaks
Players.PlayerRemoving:Connect(function(player)
	ownershipCache[player.UserId] = nil
end)

return Monetisation