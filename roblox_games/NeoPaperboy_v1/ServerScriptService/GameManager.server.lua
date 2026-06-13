-- GameManager.server.lua — Daily Blox Delivery (arcade rail + paper throw)
-- Authoritative server script: manages run state, world building,
-- paper-throw physics, scoring, and currency rewards.

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local Debris         = game:GetService("Debris")

-- ── Dependencies ─────────────────────────────────────────────────────────────
local WorldConfig = require(script.Parent:WaitForChild("WorldConfig"))
local PlayerData  = require(script.Parent:WaitForChild("PlayerData"))

-- ── Remote Events ─────────────────────────────────────────────────────────────
-- All remotes are expected to already exist in ReplicatedStorage.Remotes
-- (created by an initialisation Script that runs before this one).
local remotes         = ReplicatedStorage:WaitForChild("Remotes")
local throwPaper      = remotes:WaitForChild("ThrowPaper")       -- client → server
local updateScore     = remotes:WaitForChild("UpdateScore")      -- server → client
local showMessage     = remotes:WaitForChild("ShowMessage")      -- server → client (toast)
local subscriberUpdate = remotes:WaitForChild("SubscriberUpdate") -- server → client
local runComplete     = remotes:WaitForChild("RunComplete")      -- server → client

-- ── Type alias ────────────────────────────────────────────────────────────────
type RunState = {
	score       : number,
	subscribers : number,
	lives       : number,
	papers      : number,
	progressZ   : number,
	ended       : boolean,
	-- Debounce tables to prevent repeated hit triggers on the same frame
	obstacleDebounce : { [string]: boolean },
}

-- Per-player run state keyed by UserId
local runState: { [number]: RunState } = {}

-- ── HUD sync ──────────────────────────────────────────────────────────────────
local function syncHud(player: Player)
	local state = runState[player.UserId]
	if not state then return end
	-- Fire two separate remotes so the client can route each to its own UI element
	updateScore:FireClient(player, state.score)
	subscriberUpdate:FireClient(player, state.subscribers, state.lives, state.papers)
end

-- ── Run lifecycle ─────────────────────────────────────────────────────────────
local function endRun(player: Player, reason: string)
	local state = runState[player.UserId]
	if not state or state.ended then return end
	state.ended = true

	-- Convert score to Delivery Bucks (100 score = 1 buck, minimum 0)
	local bucks = math.max(0, math.floor(state.score / 100))
	PlayerData.addBucks(player, bucks)

	runComplete:FireClient(player, state.score, bucks, reason)
	showMessage:FireClient(player, reason)
end

-- Called when a paper misses a subscriber mailbox or hits a non-subscriber prop
local function cancelSubscriber(player: Player)
	local state = runState[player.UserId]
	if not state or state.ended then return end

	state.subscribers = math.max(0, state.subscribers - 1)
	showMessage:FireClient(player, "Subscriber cancelled! (" .. state.subscribers .. " left)")
	syncHud(player)

	if state.subscribers <= 0 then
		endRun(player, "No subscribers left!")
	end
end

-- Called when the player's character collides with an obstacle
local function loseLife(player: Player, reason: string)
	local state = runState[player.UserId]
	if not state or state.ended then return end

	state.lives = math.max(0, state.lives - 1)
	showMessage:FireClient(player, reason .. "  (" .. state.lives .. " lives left)")
	syncHud(player)

	if state.lives <= 0 then
		endRun(player, "Out of lives!")
	end
end

-- ── World building ────────────────────────────────────────────────────────────
--[[
	Obstacle kind → colour map.
	Kinds defined in WorldConfig.Obstacles[i].kind must appear here.
	Six supported types: Pothole, TrashCan, Dog, Sprinkler, Car, ConeBarrel
]]
local OBSTACLE_COLOURS: { [string]: Color3 } = {
	Pothole    = Color3.fromRGB(80,  60,  40),
	TrashCan   = Color3.fromRGB(100, 180, 100),
	Dog        = Color3.fromRGB(200, 150, 80),
	Sprinkler  = Color3.fromRGB(80,  160, 220),
	Car        = Color3.fromRGB(220, 60,  60),
	ConeBarrel = Color3.fromRGB(240, 140, 20),
}

local function buildStreet()
	-- Tear down any previous route (e.g. server restart / test rebuild)
	local existing = workspace:FindFirstChild("DeliveryRoute")
	if existing then existing:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = "DeliveryRoute"
	folder.Parent = workspace

	-- ── Road surface ──────────────────────────────────────────────────────────
	local road      = Instance.new("Part")
	road.Name       = "Road"
	road.Anchored   = true
	road.Size       = Vector3.new(WorldConfig.RoadHalfWidth * 2, 1, WorldConfig.StreetLength)
	road.Position   = Vector3.new(0, 0, WorldConfig.StreetLength / 2)
	road.Color      = Color3.fromRGB(60, 60, 60)
	road.Material   = Enum.Material.SmoothPlastic
	road.Parent     = folder

	-- ── Houses & mailboxes ────────────────────────────────────────────────────
	for index, house in ipairs(WorldConfig.Houses) do
		-- Validate required fields to avoid silent nil-math errors
		assert(typeof(house.x) == "number",         "WorldConfig.Houses[" .. index .. "].x must be a number")
		assert(typeof(house.z) == "number",         "WorldConfig.Houses[" .. index .. "].z must be a number")
		assert(typeof(house.subscriber) == "boolean", "WorldConfig.Houses[" .. index .. "].subscriber must be a boolean")

		local lot      = Instance.new("Folder")
		lot.Name       = "House" .. index
		lot.Parent     = folder

		local base     = Instance.new("Part")
		base.Name      = "HouseBase"
		base.Anchored  = true
		base.Size      = Vector3.new(12, 10, 12)
		base.Position  = Vector3.new(house.x, 5, house.z)
		-- Blue tint = active subscriber, grey = non-subscriber
		base.Color     = house.subscriber
			and Color3.fromRGB(135, 206, 250)
			or  Color3.fromRGB(140, 140, 140)
		base.Parent    = lot

		-- Mailbox offset toward the road depending on which side of the road the house is on
		local sideOffset = house.x > 0 and -4 or 4
		local mailbox    = Instance.new("Part")
		mailbox.Name     = "Mailbox"
		mailbox.Anchored = true
		mailbox.Size     = Vector3.new(2, 3, 1)
		mailbox.Position = Vector3.new(house.x + sideOffset, base.Position.Y - 3, house.z + 4)
		mailbox.Color    = house.subscriber
			and Color3.fromRGB(255, 220, 80)   -- gold = valid target
			or  Color3.fromRGB(120, 120, 120)  -- grey = no-score prop
		mailbox.Parent   = lot

		-- Tag the mailbox so projectiles can look it up quickly
		mailbox:SetAttribute("IsSubscriber", house.subscriber)

		if house.subscriber then
			-- ── Subscriber mailbox: reward on paper hit ───────────────────────
			mailbox.Touched:Connect(function(hit)
				-- Only react to our own paper projectiles
				if not hit.Name:find("PaperProjectile") then return end

				local char   = hit:FindFirstAncestorOfClass("Model")
				local player = char and Players:GetPlayerFromCharacter(char)
				if not player then return end

				local state = runState[player.UserId]
				if not state or state.ended then return end

				-- Prevent the same paper triggering twice (e.g. it bounces)
				if hit:GetAttribute("Delivered") then return end
				hit:SetAttribute("Delivered", true)

				state.score  += WorldConfig.Score.Mailbox
				showMessage:FireClient(player, "Perfect delivery! +" .. WorldConfig.Score.Mailbox)
				syncHud(player)
				hit:Destroy()
			end)
		else
			-- ── Non-subscriber prop: paper hit cancels a subscriber ────────────
			mailbox.Touched:Connect(function(hit)
				if not hit.Name:find("PaperProjectile") then return end
				if hit:GetAttribute("Delivered") then return end  -- already processed
				hit:SetAttribute("Delivered", true)

				local char   = hit:FindFirstAncestorOfClass("Model")
				local player = char and Players:GetPlayerFromCharacter(char)
				if player then
					-- Chaos points: reward the "wrong" action for style, but cancel sub
					local state = runState[player.UserId]
					if state and not state.ended then
						state.score += WorldConfig.Score.ChaosHit or 50
					end
					cancelSubscriber(player)
				end
				hit:Destroy()
			end)
		end
	end

	-- ── Six obstacle types ─────────────────────────────────────────────────────
	for _, obstacle in ipairs(WorldConfig.Obstacles) do
		local kind   = obstacle.kind or "Unknown"
		local colour = OBSTACLE_COLOURS[kind] or Color3.fromRGB(255, 100, 100)

		-- Determine obstacle size by kind for better visual variety
		local sizeMap: { [string]: Vector3 } = {
			Pothole    = Vector3.new(5, 0.5, 5),
			TrashCan   = Vector3.new(2, 4,   2),
			Dog        = Vector3.new(3, 2,   3),
			Sprinkler  = Vector3.new(1, 1,   1),
			Car        = Vector3.new(6, 4,   10),
			ConeBarrel = Vector3.new(2, 3,   2),
		}
		local size = sizeMap[kind] or Vector3.new(4, 4, 4)

		local xPos   = typeof(obstacle.x) == "number" and obstacle.x
			or (typeof(obstacle.lane) == "number" and obstacle.lane)
			or 0

		local part        = Instance.new("Part")
		part.Name         = kind .. "Obstacle"
		part.Anchored     = true
		part.Size         = size
		part.Position     = Vector3.new(xPos, size.Y / 2, obstacle.z)
		part.Color        = colour
		part.Material     = Enum.Material.SmoothPlastic
		-- Tag for quick identity checks in Touched callbacks
		part:SetAttribute("ObstacleKind", kind)
		part.Parent       = folder

		-- Debounce key is unique per part using its full path; we use a simple
		-- per-player attribute on the part instead of a shared table to avoid
		-- cross-player interference.
		part.Touched:Connect(function(hit)
			local char   = hit:FindFirstAncestorOfClass("Model")
			local player = char and Players:GetPlayerFromCharacter(char)
			if not player then return end

			local state = runState[player.UserId]
			if not state or state.ended then return end

			-- Per-player debounce stored as a part attribute (avoids shared state bugs)
			local debounceKey = "Debounce_" .. player.UserId
			if part:GetAttribute(debounceKey) then return end
			part:SetAttribute(debounceKey, true)
			-- Reset debounce after a short window so repeated hits are still possible
			task.delay(1.5, function()
				if part and part.Parent then
					part:SetAttribute(debounceKey, nil)
				end
			end)

			loseLife(player, "Crash! Hit a " .. kind .. ".")
		end)
	end

	-- ── Bonus target course ───────────────────────────────────────────────────
	-- Bonus mailboxes placed mid-route; hitting them awards extra score without
	-- subscriber risk.
	if WorldConfig.BonusTargets then
		for bonusIdx, target in ipairs(WorldConfig.BonusTargets) do
			local bonus       = Instance.new("Part")
			bonus.Name        = "BonusTarget" .. bonusIdx
			bonus.Anchored    = true
			bonus.Size        = Vector3.new(2, 2, 2)
			bonus.Shape       = Enum.PartType.Ball
			bonus.Position    = Vector3.new(target.x, target.y or 4, target.z)
			bonus.Color       = Color3.fromRGB(255, 80, 200)  -- hot-pink = bonus
			bonus.Material    = Enum3.Material.Neon
			bonus:SetAttribute("IsBonusTarget", true)
			bonus.Parent      = folder

			bonus.Touched:Connect(function(hit)
				if not hit.Name:find("PaperProjectile") then return end
				if hit:GetAttribute("Delivered") then return end
				hit:SetAttribute("Delivered", true)

				local char   = hit:FindFirstAncestorOfClass("Model")
				local player = char and Players:GetPlayerFromCharacter(char)
				if not player then
					hit:Destroy()
					return
				end

				local state = runState[player.UserId]
				if not state or state.ended then
					hit:Destroy()
					return
				end

				local bonusPoints = WorldConfig.Score.BonusTarget or 1500
				state.score      += bonusPoints
				showMessage:FireClient(player, "BONUS TARGET! +" .. bonusPoints)
				syncHud(player)

				-- Remove the bonus target so it can only be claimed once
				bonus:Destroy()
				hit:Destroy()
			end)
		end
	end

	-- ── Finish arch ───────────────────────────────────────────────────────────
	local finish      = Instance.new("Part")
	finish.Name       = "FinishArch"
	finish.Anchored   = true
	finish.CanCollide = false   -- visual only; we detect by overlap, not physics block
	finish.Size       = Vector3.new(WorldConfig.RoadHalfWidth * 2 + 4, 12, 2)
	finish.Position   = Vector3.new(0, 6, WorldConfig.StreetLength - 10)
	finish.Color      = Color3.fromRGB(100, 255, 150)
	finish.Material   = Enum.Material.Neon
	finish.Transparency = 0.4
	finish.Parent     = folder

	-- Use a per-player debounce so multi-player games each trigger independently
	finish.Touched:Connect(function(hit)
		local char   = hit:FindFirstAncestorOfClass("Model")
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then return end
		endRun(player, "Route complete!")
	end)
end

-- ── Paper throw (server) ──────────────────────────────