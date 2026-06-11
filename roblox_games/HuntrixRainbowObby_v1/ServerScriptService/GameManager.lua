-- GameManager.lua — Huntrix Rainbow Carpet Obby
-- ServerScriptService Script

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldConfig = require(script.Parent:WaitForChild("WorldConfig"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateStars = remotes:WaitForChild("UpdateStars")
local updateStage = remotes:WaitForChild("UpdateStage")
local showMessage = remotes:WaitForChild("ShowMessage")
local carpetBoost = remotes:WaitForChild("CarpetBoost")

local carpetCooldown: { [number]: number } = {}
local collectedStars: { [number]: { [string]: boolean } } = {}

local function starKey(pos: Vector3): string
	return string.format("%d_%d_%d", math.round(pos.X), math.round(pos.Y), math.round(pos.Z))
end

local function teleportToCheckpoint(player: Player, stageIndex: number)
	local stage = WorldConfig.Stages[stageIndex]
	if not stage then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = CFrame.new(stage.checkpoint + Vector3.new(0, 3, 0))
	end
end

local function syncHud(player: Player)
	local data = PlayerData.get(player)
	updateStars:FireClient(player, data.stars)
	local stage = WorldConfig.Stages[data.checkpoint] or WorldConfig.Stages[1]
	updateStage:FireClient(player, stage.name, data.checkpoint, #WorldConfig.Stages)
end

local function onStarTouched(hit: BasePart, starPart: BasePart, stageIndex: number)
	local char = hit:FindFirstAncestorOfClass("Model")
	if not char then
		return
	end
	local player = Players:GetPlayerFromCharacter(char)
	if not player then
		return
	end

	local uid = player.UserId
	collectedStars[uid] = collectedStars[uid] or {}
	local key = starKey(starPart.Position)
	if collectedStars[uid][key] then
		return
	end
	collectedStars[uid][key] = true

	local data = PlayerData.get(player)
	data.stars += 1
	showMessage:FireClient(player, "Star collected! ✨")
	syncHud(player)

	starPart.Transparency = 1
	starPart.CanCollide = false
	local sparkle = starPart:FindFirstChildOfClass("ParticleEmitter")
	if sparkle then
		sparkle.Enabled = false
	end
end

local function buildWorld()
	local folder = workspace:FindFirstChild("HuntrixObby")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "HuntrixObby"
	folder.Parent = workspace

	for stageIndex, stage in ipairs(WorldConfig.Stages) do
		local stageFolder = Instance.new("Folder")
		stageFolder.Name = stage.name
		stageFolder.Parent = folder

		local platform = Instance.new("Part")
		platform.Name = "CarpetPlatform"
		platform.Size = Vector3.new(24, 2, 24)
		platform.Anchored = true
		platform.CanCollide = true
		platform.Material = Enum.Material.Fabric
		platform.Color = WorldConfig.RainbowColors[((stageIndex - 1) % #WorldConfig.RainbowColors) + 1]
		platform.CFrame = CFrame.new(stage.spawn)
		platform.Parent = stageFolder

		local checkpoint = Instance.new("Part")
		checkpoint.Name = "Checkpoint"
		checkpoint.Size = Vector3.new(6, 8, 6)
		checkpoint.Anchored = true
		checkpoint.CanCollide = false
		checkpoint.Transparency = 0.5
		checkpoint.Color = Color3.fromRGB(255, 255, 255)
		checkpoint.CFrame = CFrame.new(stage.checkpoint + Vector3.new(0, 4, 0))
		checkpoint.Parent = stageFolder

		checkpoint.Touched:Connect(function(hit)
			local char = hit:FindFirstAncestorOfClass("Model")
			local player = char and Players:GetPlayerFromCharacter(char)
			if not player then
				return
			end
			local data = PlayerData.get(player)
			if stageIndex > data.checkpoint then
				data.checkpoint = stageIndex
				showMessage:FireClient(player, "Checkpoint saved! 🌈")
				syncHud(player)
			end
		end)

		for _, starPos in ipairs(stage.stars) do
			local star = Instance.new("Part")
			star.Name = "Star"
			star.Shape = Enum.PartType.Ball
			star.Size = Vector3.new(2.5, 2.5, 2.5)
			star.Anchored = true
			star.CanCollide = false
			star.Material = Enum.Material.Neon
			star.Color = Color3.fromRGB(255, 240, 120)
			star.CFrame = CFrame.new(starPos)
			star.Parent = stageFolder

			local emitter = Instance.new("ParticleEmitter")
			emitter.Rate = 12
			emitter.Lifetime = NumberRange.new(0.4, 0.8)
			emitter.Speed = NumberRange.new(1, 3)
			emitter.LightEmission = 1
			emitter.Parent = star

			star.Touched:Connect(function(hit)
				onStarTouched(hit, star, stageIndex)
			end)
		end
	end
end

local function applyCarpetBoost(player: Player)
	local now = os.clock()
	local uid = player.UserId
	if carpetCooldown[uid] and now < carpetCooldown[uid] then
		showMessage:FireClient(player, "Carpet recharging…")
		return
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return
	end

	carpetCooldown[uid] = now + WorldConfig.CarpetBoostCooldown
	local data = PlayerData.get(player)
	data.carpetUses += 1

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(0, math.huge, 0)
	bv.Velocity = Vector3.new(0, 28, 0)
	bv.Parent = hrp
	showMessage:FireClient(player, "Flying carpet! ☁️")

	task.delay(WorldConfig.CarpetBoostDuration, function()
		if bv and bv.Parent then
			bv:Destroy()
		end
	end)
end

carpetBoost.OnServerEvent:Connect(applyCarpetBoost)

Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
	collectedStars[player.UserId] = {}
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		local data = PlayerData.get(player)
		teleportToCheckpoint(player, data.checkpoint)
		syncHud(player)
		showMessage:FireClient(player, "Welcome to Huntrix Rainbow Adventure!")
	end)
end)

RunService.Heartbeat:Connect(function()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp.Position.Y < WorldConfig.FallKillY then
			local data = PlayerData.get(player)
			teleportToCheckpoint(player, data.checkpoint)
			showMessage:FireClient(player, "Oops! Back to your checkpoint 💫")
		end
	end
end)

buildWorld()
