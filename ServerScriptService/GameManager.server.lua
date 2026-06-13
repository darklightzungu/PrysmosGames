-- GameManager.server.lua — Daily Blox Delivery (arcade rail + paper throw)
-- Runs server-side: manages run state, street geometry, obstacle/mailbox wiring,
-- paper projectile spawning, and currency rewards.

local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService    = game:GetService("RunService")
local Debris        = game:GetService("Debris")

-- ── Dependencies ─────────────────────────────────────────────────────────────
local WorldConfig   = require(script.Parent:WaitForChild("WorldConfig"))
local PlayerData    = require(script.Parent:WaitForChild("PlayerData"))

-- ── RemoteEvents (must exist in ReplicatedStorage.Remotes) ───────────────────
local remotes          = ReplicatedStorage:WaitForChild("Remotes")
local throwPaperRemote = remotes:WaitForChild("ThrowPaper")
local updateScoreRemote   = remotes:WaitForChild("UpdateScore")
local showMessageRemote   = remotes:WaitForChild("ShowMessage")
local subscriberUpdateRemote = remotes:WaitForChild("SubscriberUpdate")
local runCompleteRemote  = remotes:WaitForChild("RunComplete")

-- ── Run-state table keyed by UserId ──────────────────────────────────────────
-- Each entry: { score, subscribers, lives, papers, progressZ, ended, chaosPoints }
local runState: { [number]: any } = {}

-- ── Debounce table to prevent multi-fire on Touched ──────────────────────────
local touchDebounce: { [string]: boolean } = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- Sync the current run snapshot to the player's HUD
local function syncHud(player: Player)
	local state = runState[player.UserId]
	if not state then return end
	updateScoreRemote:FireClient(player, state.score, state.chaosPoints)
	subscriberUpdateRemote:FireClient(player, state.subscribers, state.lives, state.papers)
end

-- Safely show a transient message to the player
local function notify(player: Player, msg: string)
	showMessageRemote:FireClient(player, msg)
end

-- Award Delivery Bucks, fire run-complete event, and mark state ended
local function endRun(player: Player, reason: string)
	local state = runState[player.UserId]
	if not state or state.ended then return end
	state.ended = true

	-- Delivery Bucks = 1 per 100 score, bonus 1 per 5 chaos points
	local bucks = math.floor(state.score / 100) + math.floor(state.chaosPoints / 5)
	PlayerData.addBucks(player, bucks)

	runCompleteRemote:FireClient(player, state.score, bucks, state.chaosPoints, reason)
	notify(player, reason)
end

-- Remove one subscriber; end run if subscriber count hits zero
local function cancelSubscriber(player: Player)
	local state = runState[player.UserId]
	if not state or state.ended then return end

	state.subscribers = math.max(0, state.subscribers - 1)
	notify(player, "📰 Subscriber cancelled! (" .. state.subscribers .. " left)")
	syncHud(player)

	if state.subscribers <= 0 then
		endRun(player, "All subscribers cancelled!")
	end
end

-- Remove one life; end run when lives reach zero
local function loseLife(player: Player, reason: string)
	local state = runState[player.UserId]
	if not state or state.ended then return end

	state.lives = math.max(0, state.lives - 1)
	notify(player, "💥 " .. reason .. " (" .. state.lives .. " lives left)")
	syncHud(player)

	if state.lives <= 0 then
		endRun(player, "Out of lives!")
	end
end

-- Award chaos points when a paper hits non-subscriber props
local function awardChaos(player: Player, points: number, label: string)
	local state = runState[player.UserId]
	if not state or state.ended then return end

	state.chaosPoints += points
	notify(player, "🌀 Chaos! " .. label .. " +" .. points)
	syncHud(player)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Paper projectile (arc launch)
-- ─────────────────────────────────────────────────────────────────────────────

-- Spawns a paper part with an arc velocity; arc is achieved by adding upward
-- bias to the requested direction unit so it follows a parabolic path.
local function spawnPaper(player: Player, origin: Vector3, direction: Vector3)
	local state = runState[player.UserId]
	if not state or state.ended then return end
	if state.papers <= 0 then
		notify(player, "No papers left!")
		return
	end

	state.papers -= 1
	syncHud(player)

	local paper = Instance.new("Part")
	paper.Name         = "PaperProjectile"
	paper.Size         = Vector3.new(1.2, 0.2, 1.8)
	paper.Color        = Color3.fromRGB(245, 245, 245)
	paper.Material     = Enum.Material.SmoothPlastic
	paper.CastShadow   = false
	paper.CanCollide   = true
	paper.CFrame       = CFrame.new(origin, origin + direction)
	-- Tag so other Touched handlers can identify this as a delivery paper
	paper:SetAttribute("OwnerId", player.UserId)
	paper:SetAttribute("Delivered", false)
	paper.Parent       = workspace

	-- Arc velocity: flat speed forward + fixed upward kick; gravity handles descent
	local arcVelocity = direction.Unit * WorldConfig.PaperSpeed
		+ Vector3.new(0, WorldConfig.PaperArcUp or 22, 0)

	local bv = Instance.new("BodyVelocity")
	bv.Velocity  = arcVelocity
	bv.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
	bv.Parent    = paper

	-- Auto-destroy after a fixed flight time to prevent stale projectiles
	Debris:AddItem(paper, WorldConfig.PaperLifetime or 5)
end

-- Validate and relay client throw requests
throwPaperRemote.OnServerEvent:Connect(function(player: Player, origin, direction)
	-- Strict type checks to prevent exploited data from reaching game logic
	if typeof(origin)    ~= "Vector3" then return end
	if typeof(direction) ~= "Vector3" then return end
	-- Magnitude guard: direction must be non-zero and not absurdly large
	if direction.Magnitude < 0.01 or direction.Magnitude > 1e4 then return end

	spawnPaper(player, origin, direction.Unit)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Street / obstacle construction
-- ─────────────────────────────────────────────────────────────────────────────

-- Six obstacle kinds defined in WorldConfig.Obstacles, each with a .kind field:
--   "Pothole", "TrashCan", "Dog", "Puddle", "ConstructionBarrier", "Parked Car"
-- We colour-code them and attach appropriate consequences.
local OBSTACLE_COLORS: { [string]: Color3 } = {
	Pothole              = Color3.fromRGB(80,  40,  10),
	TrashCan             = Color3.fromRGB(90,  90,  90),
	Dog                  = Color3.fromRGB(200, 150, 80),
	Puddle               = Color3.fromRGB(50,  120, 200),
	ConstructionBarrier  = Color3.fromRGB(255, 140, 0),
	["Parked Car"]       = Color3.fromRGB(160, 30,  30),
}

local OBSTACLE_SIZES: { [string]: Vector3 } = {
	Pothole              = Vector3.new(4, 0.5, 4),
	TrashCan             = Vector3.new(2, 4,   2),
	Dog                  = Vector3.new(3, 2,   3),
	Puddle               = Vector3.new(5, 0.3, 5),
	ConstructionBarrier  = Vector3.new(3, 5,   1),
	["Parked Car"]       = Vector3.new(8, 4,   14),
}

local function buildStreet()
	-- Tear down any previous geometry so this is idempotent (server restart / reset)
	local existing = workspace:FindFirstChild("DeliveryRoute")
	if existing then existing:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name   = "DeliveryRoute"
	folder.Parent = workspace

	-- ── Road surface ──────────────────────────────────────────────────────────
	local road           = Instance.new("Part")
	road.Name            = "Road"
	road.Anchored        = true
	road.CanCollide      = true
	road.Size            = Vector3.new(WorldConfig.RoadHalfWidth * 2, 1, WorldConfig.StreetLength)
	road.Position        = Vector3.new(0, 0, WorldConfig.StreetLength / 2)
	road.Color           = Color3.fromRGB(60, 60, 60)
	road.Material        = Enum.Material.SmoothPlastic
	road.TopSurface      = Enum.SurfaceType.Smooth
	road.BottomSurface   = Enum.SurfaceType.Smooth
	road.Parent          = folder

	-- ── Houses and mailboxes ──────────────────────────────────────────────────
	for index, house in ipairs(WorldConfig.Houses) do
		if typeof(house.x) ~= "number" or typeof(house.z) ~= "number" then
			warn("[GameManager] Invalid house entry at index", index)
			continue
		end

		local lot    = Instance.new("Folder")
		lot.Name     = "House" .. index
		lot.Parent   = folder

		local isSubscriber: boolean = house.subscriber == true

		local base           = Instance.new("Part")
		base.Name            = "HouseBase"
		base.Anchored        = true
		base.CanCollide      = true
		base.Size            = Vector3.new(12, 10, 12)
		base.Position        = Vector3.new(house.x, 5, house.z)
		base.Color           = isSubscriber
			and Color3.fromRGB(135, 206, 250)
			or  Color3.fromRGB(140, 140, 140)
		base.Material        = Enum.Material.SmoothPlastic
		base.Parent          = lot

		-- Mailbox sits at the sidewalk edge, slightly in front of the house
		local sideOffset     = house.x > 0 and -5 or 5
		local mailbox        = Instance.new("Part")
		mailbox.Name         = "Mailbox"
		mailbox.Anchored     = true
		mailbox.CanCollide   = true
		mailbox.Size         = Vector3.new(2, 3, 1)
		mailbox.Position     = base.Position + Vector3.new(sideOffset, -3.5, 5)
		mailbox.Color        = isSubscriber
			and Color3.fromRGB(255, 220, 80)
			or  Color3.fromRGB(120, 120, 120)
		mailbox.Material     = Enum.Material.SmoothPlastic
		mailbox.Parent       = lot

		-- ── Subscriber mailbox: reward on hit ─────────────────────────────────
		if isSubscriber then
			mailbox.Touched:Connect(function(hit)
				-- Only react to paper projectiles
				if not hit.Name:find("Paper") then return end

				-- Debounce using part's unique id to prevent multi-fire
				local key = tostring(mailbox) .. tostring(hit)
				if touchDebounce[key] then return end
				touchDebounce[key] = true
				task.delay(0.5, function() touchDebounce[key] = nil end)

				-- Prevent already-delivered papers from re-scoring
				if hit:GetAttribute("Delivered") then return end

				local ownerId = hit:GetAttribute("OwnerId")
				if not ownerId then return end
				local owner = Players:GetPlayerByUserId(ownerId)
				if not owner then return end

				local state = runState[owner.UserId]
				if not state or state.ended then return end

				hit:SetAttribute("Delivered", true)
				state.score += WorldConfig.Score.Mailbox
				notify(owner, "📬 Perfect delivery! +" .. WorldConfig.Score.Mailbox)
				syncHud(owner)
				hit:Destroy()
			end)
		else
			-- ── Non-subscriber prop: cancel a subscriber if hit by paper ───────
			mailbox.Touched:Connect(function(hit)
				if not hit.Name:find("Paper") then return end
				if hit:GetAttribute("Delivered") then return end

				local key = tostring(mailbox) .. tostring(hit)
				if touchDebounce[key] then return end
				touchDebounce[key] = true
				task.delay(0.5, function() touchDebounce[key] = nil end)

				local ownerId = hit:GetAttribute("OwnerId")
				if not ownerId then return end
				local owner = Players:GetPlayerByUserId(ownerId)
				if not owner then return end

				hit:SetAttribute("Delivered", true) -- consume the paper
				cancelSubscriber(owner)
				hit:Destroy()
			end)
		end
	end

	-- ── Six obstacle types ────────────────────────────────────────────────────
	for _, obstacle in ipairs(WorldConfig.Obstacles) do
		local kind: string = obstacle.kind or "Unknown"
		local posX: number = tonumber(obstacle.x) or 0
		local posZ: number = tonumber(obstacle.z) or 0

		local part           = Instance.new("Part")
		part.Name            = kind
		part.Anchored        = true
		part.CanCollide      = true
		part.Size            = OBSTACLE_SIZES[kind] or Vector3.new(4, 4, 4)
		part.Position        = Vector3.new(posX, (OBSTACLE_SIZES[kind] and OBSTACLE_SIZES[kind].Y / 2) or 2, posZ)
		part.Color           = OBSTACLE_COLORS[kind] or Color3.fromRGB(255, 100, 100)
		part.Material        = Enum.Material.SmoothPlastic
		part.CastShadow      = false
		part.Parent          = folder

		part.Touched:Connect(function(hit)
			-- Only react to character body parts (not papers, not the road itself)
			if hit.Name:find("Paper") then return end

			local char   = hit:FindFirstAncestorOfClass("Model")
			local player = char and Players:GetPlayerFromCharacter(char)
			if not player then return end

			local key = tostring(part) .. tostring(player.UserId)
			if touchDebounce[key] then return end
			touchDebounce[key] = true
			-- Cooldown varies by obstacle severity
			task.delay(1.5, function() touchDebounce[key] = nil end)

			loseLife(player, "Hit a " .. kind .. "!")
		end)

		-- Papers hitting non-route obstacles award