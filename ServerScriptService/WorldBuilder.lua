-- WorldBuilder.lua
-- Route Rage — Starter Suburbs District Builder
-- Place in: ServerScriptService
-- Runs once on server start; procedurally builds StarterSuburbs geometry.

local CollectionService = game:GetService("CollectionService")
local WorldConfig       = require(script.Parent:WaitForChild("WorldConfig"))

local AREA         = WorldConfig.Areas and WorldConfig.Areas[1] or {}
local SPAWN_POINTS = AREA.spawnPoints or {}

-- Counters for final summary print
local roadCount   = 0
local hazardCount = 0
local spawnCount  = 0

-- ── Root Model & Folders ─────────────────────────────────────────────────────

local suburbsModel = Instance.new("Model")
suburbsModel.Name  = "StarterSuburbs"
suburbsModel.Parent = workspace

local roadsFolder    = Instance.new("Folder")
roadsFolder.Name     = "Roads"
roadsFolder.Parent   = suburbsModel

local spawnPadsFolder = Instance.new("Folder")
spawnPadsFolder.Name  = "SpawnPads"
spawnPadsFolder.Parent = suburbsModel

local hazardsFolder  = Instance.new("Folder")
hazardsFolder.Name   = "Hazards"
hazardsFolder.Parent = suburbsModel

local shortcutsFolder = Instance.new("Folder")
shortcutsFolder.Name  = "Shortcuts"
shortcutsFolder.Parent = suburbsModel

-- ── Helpers ──────────────────────────────────────────────────────────────────

-- Creates and returns an Anchored Part with the given properties
local function makePart(name, size, cframe, color, material, canCollide, parent)
    local p          = Instance.new("Part")
    p.Name           = name
    p.Size           = size
    p.CFrame         = cframe
    p.Color          = color
    p.Material       = material
    p.Anchored       = true
    p.CanCollide     = canCollide ~= false  -- defaults to true
    p.CastShadow     = true
    p.Parent         = parent
    return p
end

-- Applies one or more CollectionService tags to a part
local function tag(part, ...)
    for _, t in ipairs({...}) do
        CollectionService:AddTag(part, t)
    end
end

-- ── Roads ────────────────────────────────────────────────────────────────────

local function buildRoads()
    local asphalt   = Enum.Material.Asphalt
    local darkGray  = Color3.fromRGB(40, 40, 40)

    local roadDefs = {
        { name = "MainRoad",      size = Vector3.new(200, 2, 20),  cf = CFrame.new(0,  0,   0), mat = asphalt,           color = darkGray                    },
        { name = "CrossStreet1",  size = Vector3.new(100, 2, 16),  cf = CFrame.new(0,  0,  60), mat = asphalt,           color = darkGray                    },
        { name = "CrossStreet2",  size = Vector3.new(100, 2, 16),  cf = CFrame.new(0,  0, -60), mat = asphalt,           color = darkGray                    },
        -- Slightly raised to prevent z-fighting with cross streets
        { name = "Intersection1", size = Vector3.new(20, 2, 20),   cf = CFrame.new(0,  0.05, 60), mat = asphalt,         color = darkGray                    },
        { name = "Intersection2", size = Vector3.new(20, 2, 20),   cf = CFrame.new(0,  0.05,-60), mat = asphalt,         color = darkGray                    },
        { name = "Ground",        size = Vector3.new(400, 2, 400), cf = CFrame.new(0, -2,   0), mat = Enum.Material.Grass, color = Color3.fromRGB(80, 140, 60) },
    }

    for _, def in ipairs(roadDefs) do
        makePart(def.name, def.size, def.cf, def.color, def.mat, true, roadsFolder)
        roadCount = roadCount + 1
    end
end

-- ── Spawn Pads ───────────────────────────────────────────────────────────────

local function buildSpawnPads()
    for i, spawnPos in ipairs(SPAWN_POINTS) do
        local pad = makePart(
            "SpawnPad_" .. i,
            Vector3.new(6, 0.5, 6),
            CFrame.new(spawnPos + Vector3.new(0, 1.25, 0)),  -- rest on road surface
            Color3.fromRGB(0, 162, 255),
            Enum.Material.Neon,
            true,
            spawnPadsFolder
        )

        tag(pad, "SpawnPoint", "SpawnPad")

        -- BillboardGui label so the spawn is identifiable in-world
        local billboard        = Instance.new("BillboardGui")
        billboard.Name         = "SpawnLabel"
        billboard.Size         = UDim2.new(0, 60, 0, 20)
        billboard.StudsOffset  = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop  = false
        billboard.Parent       = pad

        local label            = Instance.new("TextLabel")
        label.Text             = "SPAWN"
        label.TextColor3       = Color3.new(1, 1, 1)
        label.Font             = Enum.Font.GothamBold
        label.TextSize         = 14
        label.Size             = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Parent           = billboard

        spawnCount = spawnCount + 1
    end
end

-- ── Hazard Props ─────────────────────────────────────────────────────────────

local function buildHazardProps()
    -- HazardCar × 4 — parked cars blocking lanes
    local carPositions = {
        Vector3.new(-70, 2,  12),
        Vector3.new(-30, 2, -12),
        Vector3.new( 30, 2,  12),
        Vector3.new( 70, 2, -12),
    }
    for i, pos in ipairs(carPositions) do
        local car = makePart(
            "HazardCar_" .. i,
            Vector3.new(8, 3, 4),
            CFrame.new(pos),
            Color3.fromRGB(80, 80, 90),
            Enum.Material.SmoothPlastic,
            true,
            hazardsFolder
        )
        tag(car, "HazardCar", "HazardProp")
        hazardCount = hazardCount + 1
    end

    -- HazardCone × 6 — traffic cones at junctions and mid-road
    local conePositions = {
        Vector3.new(-10, 2,  9),
        Vector3.new(-10, 2, -9),
        Vector3.new(  0, 2, 69),
        Vector3.new(  0, 2,-69),
        Vector3.new( 10, 2,  9),
        Vector3.new( 10, 2, -9),
    }
    for i, pos in ipairs(conePositions) do
        local cone = makePart(
            "HazardCone_" .. i,
            Vector3.new(1, 1.5, 1),
            CFrame.new(pos),
            Color3.fromRGB(255, 100, 0),
            Enum.Material.SmoothPlastic,
            true,
            hazardsFolder
        )
        tag(cone, "HazardCone", "HazardProp")
        hazardCount = hazardCount + 1
    end

    -- HazardBarrier × 2 — concrete dividers mid-block
    local barrierPositions = {
        Vector3.new(-50, 2, 0),
        Vector3.new( 50, 2, 0),
    }
    for i, pos in ipairs(barrierPositions) do
        local barrier = makePart(
            "HazardBarrier_" .. i,
            Vector3.new(8, 1, 1),
            CFrame.new(pos),
            Color3.fromRGB(240, 200, 0),
            Enum.Material.SmoothPlastic,
            true,
            hazardsFolder
        )
        tag(barrier, "HazardBarrier", "HazardProp")
        hazardCount = hazardCount + 1
    end
end

-- ── Shortcuts ────────────────────────────────────────────────────────────────

local function buildShortcuts()
    local shortcutColor = Color3.fromRGB(100, 160, 70)

    -- ShortcutPath_1 — right-side cut-through
    makePart(
        "ShortcutPath_1",
        Vector3.new(6, 2, 40),
        CFrame.new(55, 0, 30),
        shortcutColor,
        Enum.Material.Grass,
        true,
        shortcutsFolder
    )

    -- ShortcutPath_2 — left-side cut-through
    makePart(
        "ShortcutPath_2",
        Vector3.new(6, 2, 40),
        CFrame.new(-55, 0, -30),
        shortcutColor,
        Enum.Material.Grass,
        true,
        shortcutsFolder
    )

    -- Sprinkler trigger zone (invisible sensor on right shortcut)
    local sprinkler              = makePart(
        "Hazard_Sprinkler",
        Vector3.new(6, 0.1, 6),
        CFrame.new(55, 0, 10),
        Color3.fromRGB(0, 150, 255),
        Enum.Material.SmoothPlastic,
        false,      -- no collision; acts as a touch sensor
        shortcutsFolder
    )
    sprinkler.Transparency = 0.8
    tag(sprinkler, "Hazard_Sprinkler")

    -- Dog trigger zone (invisible sensor on left shortcut)
    local dog                    = makePart(
        "Hazard_Dog",
        Vector3.new(4, 0.1, 4),
        CFrame.new(-55, 0, -10),
        Color3.fromRGB(180, 120, 60),
        Enum.Material.SmoothPlastic,
        false,
        shortcutsFolder
    )
    dog.Transparency = 0.8
    tag(dog, "Hazard_Dog")
end

-- ── Entry Point ───────────────────────────────────────────────────────────────

local function buildWorld()
    local ok, err

    ok, err = pcall(buildRoads)
    if not ok then warn("[WorldBuilder] buildRoads failed:", err) end

    ok, err = pcall(buildSpawnPads)
    if not ok then warn("[WorldBuilder] buildSpawnPads failed:", err) end

    ok, err = pcall(buildHazardProps)
    if not ok then warn("[WorldBuilder] buildHazardProps failed:", err) end

    ok, err = pcall(buildShortcuts)
    if not ok then warn("[WorldBuilder] buildShortcuts failed:", err) end

    print(
        "[WorldBuilder] Starter Suburbs built: " .. roadCount .. " roads, "
        .. hazardCount .. " hazards, "
        .. spawnCount  .. " spawn pads"
    )
end

buildWorld()