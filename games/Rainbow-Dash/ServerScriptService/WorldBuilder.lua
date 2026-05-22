local CollectionService = game:GetService("CollectionService")
local WorldConfig = require(script.Parent:WaitForChild("WorldConfig"))

-- Root model and folders
local suburbsModel = Instance.new("Model")
suburbsModel.Name = "StarterSuburbs"
suburbsModel.Parent = workspace

local roadsFolder = Instance.new("Folder")
roadsFolder.Name = "Roads"
roadsFolder.Parent = suburbsModel

local spawnPadsFolder = Instance.new("Folder")
spawnPadsFolder.Name = "SpawnPads"
spawnPadsFolder.Parent = suburbsModel

local hazardsFolder = Instance.new("Folder")
hazardsFolder.Name = "Hazards"
hazardsFolder.Parent = suburbsModel

local shortcutsFolder = Instance.new("Folder")
shortcutsFolder.Name = "Shortcuts"
shortcutsFolder.Parent = suburbsModel

-- Counters for final print
local roadCount = 0
local hazardCount = 0
local spawnCount = 0

-- Helper: create a basic anchored part with common properties
local function makePart(name, size, cframe, color3, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color3
	part.Material = material
	part.Anchored = true
	part.CanCollide = canCollide
	return part
end

-- ============================================================
-- BUILD ROADS
-- ============================================================
local function buildRoads()
	local asphalt = Enum.Material.SmoothPlastic -- Roblox uses SmoothPlastic for Asphalt appearance
	-- Use Enum.Material.SmoothPlastic for roads; Asphalt enum exists in newer Roblox
	local asphaltMaterial = Enum.Material.SmoothPlastic
	-- Attempt actual Asphalt material (exists in Studio)
	pcall(function()
		asphaltMaterial = Enum.Material.Asphalt
	end)

	local darkGray = Color3.fromRGB(40, 40, 40)
	local grassGreen = Color3.fromRGB(80, 140, 60)
	local grassMaterial = Enum.Material.Grass

	local roadDefs = {
		{ name = "MainRoad",     size = Vector3.new(200, 2, 20),  cf = CFrame.new(0, 0, 0),    mat = asphaltMaterial, color = darkGray,   cc = true },
		{ name = "CrossStreet1", size = Vector3.new(100, 2, 16),  cf = CFrame.new(0, 0, 60),   mat = asphaltMaterial, color = darkGray,   cc = true },
		{ name = "CrossStreet2", size = Vector3.new(100, 2, 16),  cf = CFrame.new(0, 0, -60),  mat = asphaltMaterial, color = darkGray,   cc = true },
		{ name = "Intersection1",size = Vector3.new(20, 2, 20),   cf = CFrame.new(0, 0, 60),   mat = asphaltMaterial, color = darkGray,   cc = true },
		{ name = "Intersection2",size = Vector3.new(20, 2, 20),   cf = CFrame.new(0, 0, -60),  mat = asphaltMaterial, color = darkGray,   cc = true },
		{ name = "Ground",       size = Vector3.new(400, 2, 400), cf = CFrame.new(0, -2, 0),   mat = grassMaterial,   color = grassGreen, cc = true },
	}

	for _, def in ipairs(roadDefs) do
		local part = makePart(def.name, def.size, def.cf, def.color, def.mat, def.cc)
		part.Parent = roadsFolder
		roadCount = roadCount + 1
	end
end

-- ============================================================
-- BUILD SPAWN PADS
-- ============================================================
local function buildSpawnPads()
	-- Safely read WorldConfig spawn points
	local spawnPoints = nil
	local ok, err = pcall(function()
		spawnPoints = WorldConfig.Areas[1].spawnPoints
	end)

	if not ok or not spawnPoints then
		warn("[WorldBuilder] Could not read WorldConfig.Areas[1].spawnPoints: " .. tostring(err))
		-- Fallback spawn points so the district still has pads
		spawnPoints = {
			Vector3.new(0, 1, 0),
			Vector3.new(10, 1, 0),
			Vector3.new(-10, 1, 0),
		}
	end

	local padColor = Color3.fromRGB(0, 162, 255)
	local neonMat  = Enum.Material.Neon

	for i, spawnPos in ipairs(spawnPoints) do
		local padCF = CFrame.new(spawnPos + Vector3.new(0, 1.25, 0))
		local pad = makePart(
			"SpawnPad_" .. i,
			Vector3.new(6, 0.5, 6),
			padCF,
			padColor,
			neonMat,
			true
		)

		-- CollectionService tags
		CollectionService:AddTag(pad, "SpawnPoint")
		CollectionService:AddTag(pad, "SpawnPad")

		-- BillboardGui label
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "SpawnLabel"
		billboard.Size = UDim2.new(0, 60, 0, 20)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = pad

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "SPAWN"
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.Parent = billboard

		pad.Parent = spawnPadsFolder
		spawnCount = spawnCount + 1
	end
end

-- ============================================================
-- BUILD HAZARD PROPS
-- ============================================================
local function buildHazardProps()
	local smoothPlastic = Enum.Material.SmoothPlastic

	-- HazardCar × 4
	local carPositions = {
		Vector3.new(-70, 2, 12),
		Vector3.new(-30, 2, -12),
		Vector3.new(30,  2, 12),
		Vector3.new(70,  2, -12),
	}
	local carColor = Color3.fromRGB(80, 80, 90)

	for i, pos in ipairs(carPositions) do
		local car = makePart(
			"HazardCar_" .. i,
			Vector3.new(8, 3, 4),
			CFrame.new(pos),
			carColor,
			smoothPlastic,
			true
		)
		CollectionService:AddTag(car, "HazardCar")
		CollectionService:AddTag(car, "HazardProp")
		car.Parent = hazardsFolder
		hazardCount = hazardCount + 1
	end

	-- HazardCone × 6
	local conePositions = {
		Vector3.new(-10, 2,  9),
		Vector3.new(-10, 2, -9),
		Vector3.new(  0, 2, 69),
		Vector3.new(  0, 2,-69),
		Vector3.new( 10, 2,  9),
		Vector3.new( 10, 2, -9),
	}
	local coneColor = Color3.fromRGB(255, 100, 0)

	for i, pos in ipairs(conePositions) do
		local cone = makePart(
			"HazardCone_" .. i,
			Vector3.new(1, 1.5, 1),
			CFrame.new(pos),
			coneColor,
			smoothPlastic,
			true
		)
		CollectionService:AddTag(cone, "HazardCone")
		CollectionService:AddTag(cone, "HazardProp")
		cone.Parent = hazardsFolder
		hazardCount = hazardCount + 1
	end

	-- HazardBarrier × 2
	local barrierPositions = {
		Vector3.new(-50, 2, 0),
		Vector3.new( 50, 2, 0),
	}
	local barrierColor = Color3.fromRGB(240, 200, 0)

	for i, pos in ipairs(barrierPositions) do
		local barrier = makePart(
			"HazardBarrier_" .. i,
			Vector3.new(8, 1, 1),
			CFrame.new(pos),
			barrierColor,
			smoothPlastic,
			true
		)
		CollectionService:AddTag(barrier, "HazardBarrier")
		CollectionService:AddTag(barrier, "HazardProp")
		barrier.Parent = hazardsFolder
		hazardCount = hazardCount + 1
	end
end

-- ============================================================
-- BUILD SHORTCUTS
-- ============================================================
local function buildShortcuts()
	local grassMat  = Enum.Material.Grass
	local grassColor = Color3.fromRGB(100, 160, 70)

	-- ShortcutPath_1
	local path1 = makePart(
		"ShortcutPath_1",
		Vector3.new(6, 2, 40),
		CFrame.new(55, 0, 30),
		grassColor,
		grassMat,
		true
	)
	path1.Parent = shortcutsFolder

	-- ShortcutPath_2
	local path2 = makePart(
		"ShortcutPath_2",
		Vector3.new(6, 2, 40),
		CFrame.new(-55, 0, -30),
		grassColor,
		grassMat,
		true
	)
	path2.Parent = shortcutsFolder

	-- Sprinkler trigger zone (invisible, non-collidable sensor)
	local sprinkler = Instance.new("Part")
	sprinkler.Name = "Hazard_Sprinkler"
	sprinkler.Size = Vector3.new(6, 0.1, 6)
	sprinkler.CFrame = CFrame.new(55, 0, 10)
	sprinkler.Transparency = 0.8
	sprinkler.CanCollide = false
	sprinkler.Anchored = true
	sprinkler.Color = Color3.fromRGB(0, 180, 255)  -- subtle blue tint for editors
	CollectionService:AddTag(sprinkler, "Hazard_Sprinkler")
	sprinkler.Parent = shortcutsFolder

	-- Dog trigger zone (invisible, non-collidable sensor)
	local dogZone = Instance.new("Part")
	dogZone.Name = "Hazard_Dog"
	dogZone.Size = Vector3.new(4, 0.1, 4)
	dogZone.CFrame = CFrame.new(-55, 0, -10)
	dogZone.Transparency = 0.8
	dogZone.CanCollide = false
	dogZone.Anchored = true
	dogZone.Color = Color3.fromRGB(200, 120, 40)  -- subtle brown tint for editors
	CollectionService:AddTag(dogZone, "Hazard_Dog")
	dogZone.Parent = shortcutsFolder
end

-- ============================================================
-- MAIN BUILD SEQUENCE — each phase wrapped in pcall
-- ============================================================
local buildOk, buildErr

buildOk, buildErr = pcall(buildRoads)
if not buildOk then
	warn("[WorldBuilder] buildRoads() failed: " .. tostring(buildErr))
end

buildOk, buildErr = pcall(buildSpawnPads)
if not buildOk then
	warn("[WorldBuilder] buildSpawnPads() failed: " .. tostring(buildErr))
end

buildOk, buildErr = pcall(buildHazardProps)
if not buildOk then
	warn("[WorldBuilder] buildHazardProps() failed: " .. tostring(buildErr))
end

buildOk, buildErr = pcall(buildShortcuts)
if not buildOk then
	warn("[WorldBuilder] buildShortcuts() failed: " .. tostring(buildErr))
end

-- Final summary
print("[WorldBuilder] Starter Suburbs built: " .. roadCount .. " roads, "
	.. hazardCount .. " hazards, " .. spawnCount .. " spawn pads")