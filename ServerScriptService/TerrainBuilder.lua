-- TerrainBuilder.lua
-- ServerScriptService Script (NOT ModuleScript)
-- Runs once on server start to generate Starter Suburbs terrain

local terrain = workspace.Terrain
local Lighting = game:GetService("Lighting")

-- Step 1: Clear all existing terrain
local function clearTerrain()
	terrain:Clear()
end

-- Step 2: Fill the base ground layer with grass
local function buildGround()
	terrain:FillBlock(
		CFrame.new(0, -4, 0),
		Vector3.new(600, 8, 600),
		Enum.Material.Grass
	)
end

-- Step 3: Cut asphalt road channels into the grass layer
local function buildRoads()
	-- Main road running along Z axis through center
	terrain:FillBlock(CFrame.new(0, -1, 0),    Vector3.new(22, 4, 600),  Enum.Material.Asphalt)
	-- Cross street 1 (positive Z side)
	terrain:FillBlock(CFrame.new(0, -1, 80),   Vector3.new(400, 4, 22),  Enum.Material.Asphalt)
	-- Cross street 2 (negative Z side)
	terrain:FillBlock(CFrame.new(0, -1, -80),  Vector3.new(400, 4, 22),  Enum.Material.Asphalt)
	-- Side street 1 (positive X side)
	terrain:FillBlock(CFrame.new(120, -1, 0),  Vector3.new(22, 4, 200),  Enum.Material.Asphalt)
	-- Side street 2 (negative X side)
	terrain:FillBlock(CFrame.new(-120, -1, 0), Vector3.new(22, 4, 200),  Enum.Material.Asphalt)
end

-- Step 4: Lay concrete pavements flanking both sides of the main road
local function buildPavements()
	-- Right-side pavement
	terrain:FillBlock(CFrame.new(14, -1, 0),  Vector3.new(6, 3, 600), Enum.Material.Concrete)
	-- Left-side pavement
	terrain:FillBlock(CFrame.new(-14, -1, 0), Vector3.new(6, 3, 600), Enum.Material.Concrete)
end

-- Step 5: Dirt shortcut zones between road blocks (encourage off-road play)
local function buildYards()
	terrain:FillBlock(CFrame.new(60, -2, 40),   Vector3.new(90, 2, 60), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(-60, -2, -40), Vector3.new(90, 2, 60), Enum.Material.Ground)
end

-- Step 6: Raised grass hills along map boundaries to wall off the playable area
local function buildHills()
	-- North boundary
	terrain:FillBlock(CFrame.new(0, 8, 280),   Vector3.new(600, 24, 80), Enum.Material.Grass)
	-- South boundary
	terrain:FillBlock(CFrame.new(0, 8, -280),  Vector3.new(600, 24, 80), Enum.Material.Grass)
	-- East boundary
	terrain:FillBlock(CFrame.new(280, 8, 0),   Vector3.new(80, 24, 400), Enum.Material.Grass)
	-- West boundary
	terrain:FillBlock(CFrame.new(-280, 8, 0),  Vector3.new(80, 24, 400), Enum.Material.Grass)
end

-- Step 7: Small water feature for visual interest and hazard
local function buildWater()
	terrain:FillBlock(CFrame.new(60, -3, -40), Vector3.new(30, 2, 20), Enum.Material.Water)
end

-- Step 8: Narrow mud track as an off-road shortcut path
local function buildShortcuts()
	terrain:FillBlock(CFrame.new(60, -1, 0), Vector3.new(8, 3, 80), Enum.Material.Mud)
end

-- Step 9: Configure lighting for a sunny suburban afternoon
local function setupLighting()
	Lighting.Ambient        = Color3.fromRGB(120, 120, 120)
	Lighting.Brightness     = 2
	Lighting.ClockTime      = 14        -- 2 PM gives strong daylight
	Lighting.FogEnd         = 900       -- soft distant fog
	Lighting.FogColor       = Color3.fromRGB(180, 200, 220)
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 120, 100)

	-- Remove any existing Sky to avoid duplicates
	local existingSky = Lighting:FindFirstChildOfClass("Sky")
	if existingSky then
		existingSky:Destroy()
	end

	local sky = Instance.new("Sky")
	sky.SkyboxBk = "rbxassetid://159454299"
	sky.SkyboxDn = "rbxassetid://159454296"
	sky.SkyboxFt = "rbxassetid://159454293"
	sky.SkyboxLf = "rbxassetid://159454286"
	sky.SkyboxRt = "rbxassetid://159454290"
	sky.SkyboxUp = "rbxassetid://159454300"
	sky.Parent   = Lighting
end

-- Main orchestrator: calls each builder in order with error protection
local function buildTerrain()
	local steps = {
		{ fn = clearTerrain,    name = "clearTerrain"    },
		{ fn = buildGround,     name = "buildGround"     },
		{ fn = buildRoads,      name = "buildRoads"      },
		{ fn = buildPavements,  name = "buildPavements"  },
		{ fn = buildYards,      name = "buildYards"      },
		{ fn = buildHills,      name = "buildHills"      },
		{ fn = buildWater,      name = "buildWater"      },
		{ fn = buildShortcuts,  name = "buildShortcuts"  },
		{ fn = setupLighting,   name = "setupLighting"   },
	}

	for _, step in ipairs(steps) do
		local success, err = pcall(step.fn)
		if not success then
			-- Warn but continue so remaining steps still run
			warn(("[TerrainBuilder] Step '%s' failed: %s"):format(step.name, tostring(err)))
		end
	end

	-- Summary output confirming generation completed
	print("[TerrainBuilder] Starter Suburbs terrain generated")
	print("[TerrainBuilder] Roads: asphalt channels cut through grass")
	print("[TerrainBuilder] Yards: dirt shortcut zones")
	print("[TerrainBuilder] Hills: boundary walls")
	print("[TerrainBuilder] Lighting: sunny afternoon")
end

-- Entry point — runs once when server starts
buildTerrain()