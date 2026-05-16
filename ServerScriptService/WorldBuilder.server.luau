-- WorldBuilder.lua
-- Route Rage World — Starter Suburbs District Builder
-- Place in: ServerScriptService
-- Runs once on server start, procedurally builds StarterSuburbs geometry.

local CollectionService = game:GetService("CollectionService")
local WorldConfig       = require(script.Parent:WaitForChild("WorldConfig"))

local AREA         = (WorldConfig.Areas and WorldConfig.Areas[1]) or {}
local SPAWN_POINTS = AREA.spawnPoints or {}

-- ── Counters (mutated by each build function, read at the end) ───────────────
local roadCount  = 0
local hazardCount = 0

-- ── Root model and sub-folders ───────────────────────────────────────────────
local suburbsModel = Instance.new("Model")
suburbsModel.Name  = "StarterSuburbs"
suburbsModel.Parent = workspace

local roadsFolder    = Instance.new("Folder")
roadsFolder.Name     = "Roads"
roadsFolder.Parent   = suburbsModel

local hazardsFolder  = Instance.new("Folder")
hazardsFolder.Name   = "Hazards"
hazardsFolder.Parent = suburbsModel

local shortcutsFolder = Instance.new("Folder")
shortcutsFolder.Name  = "Shortcuts"
shortcutsFolder.Parent = suburbsModel

-- ── Generic helpers ──────────────────────────────────────────────────────────

local function makePart(name, size, cf, color, material, parent)
    local p          = Instance.new("Part")
    p.Name           = name
    p.Size           = size
    p.CFrame         = cf
    p.Color          = color
    p.Material       = material
    p.Anchored       = true
    p.CanCollide     = true
    p.CastShadow     = true
    p.Parent         = parent
    return p
end

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
        { name = "MainRoad",      size = Vector3.new(200, 2, 20),  cf = CFrame.new(0,  0,   0) },
        { name = "CrossStreet1",  size = Vector3.new(100, 2, 16),  cf = CFrame.new(0,  0,  60) },
        { name = "CrossStreet2",  size = Vector3.new(100, 2, 16),  cf = CFrame.new(0,  0, -60) },
        -- Intersection pads sit slightly above (0.05) to avoid z-fighting
        { name = "Intersection1", size = Vector3.new(20, 2, 20),   cf = CFrame.new(0,  0.05,  60) },
        { name = "Intersection2", size = Vector3.new(20, 2, 20),   cf = CFrame.new(0,  0.05, -60) },
    }

    for _, def in ipairs(roadDefs) do
        makePart(def.name, def.size, def.cf, darkGray, asphalt, roadsFolder)
        roadCount = roadCount + 1
    end

    -- Ground plane beneath everything
    makePart(
        "Ground",
        Vector3.new(400, 2, 400),
        CFrame.new(0, -2, 0),
        Color3.fromRGB(80, 140, 60),
        Enum.Material.Grass,
        roadsFolder
    )
    roadCount = roadCount + 1
end

-- ── Hazard Props ─────────────────────────────────────────────────────────────

local function buildHazardProps()
    -- ── Cars × 4 ────────────────────────────────────────────────────────────
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
            hazardsFolder
        )
        tag(car, "HazardCar", "HazardProp")
        hazardCount = hazardCount + 1
    end

    -- ── Cones × 6 ───────────────────────────────────────────────────────────
    local conePositions = {
        Vector3.new(-10, 2,   9),
        Vector3.new(-10, 2,  -9),
        Vector3.new(  0, 2,  69),
        Vector3.new(  0, 2, -69),
        Vector3.new( 10, 2,   9),
        Vector3.new( 10, 2,  -9),
    }
    for i, pos in ipairs(conePositions) do
        local cone = makePart(
            "HazardCone_" .. i,
            Vector3.new(1, 1.5, 1),
            CFrame.new(pos),
            Color3.fromRGB(255, 100, 0),
            Enum.Material.SmoothPlastic,
            hazardsFolder
        )
        tag(cone, "HazardCone", "HazardProp")
        hazardCount = hazardCount + 1
    end

    -- ── Barriers × 2 ────────────────────────────────────────────────────────
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
            hazardsFolder
        )
        tag(barrier, "HazardBarrier", "HazardProp")
        hazardCount = hazardCount + 1
    end
end

-- ── Shortcuts ─────────────────────────────────────────────────────────────────

local function buildShortcuts()
    local shortcutColor    = Color3.fromRGB(100, 160, 70)
    local shortcutMaterial = Enum.Material.Grass

    -- Shortcut path 1 (right-side cut-through)
    makePart(
        "ShortcutPath_1",
        Vector3.new(6, 2, 40),
        CFrame.new(55, 0, 30),
        shortcutColor,
        shortcutMaterial,
        shortcutsFolder
    )

    -- Shortcut path 2 (left-side cut-through)
    makePart(
        "ShortcutPath_2",
        Vector3.new(6, 2, 40),
        CFrame.new(-55, 0, -30),
        shortcutColor,
        shortcutMaterial,
        shortcutsFolder
    )

    -- Sprinkler hazard trigger zone (invisible sensor strip)
    local sprinkler              = Instance.new("Part")
    sprinkler.Name               = "Hazard_Sprinkler"
    sprinkler.Size               = Vector3.new(6, 0.1, 6)
    sprinkler.CFrame             = CFrame.new(55, 0, 10)
    sprinkler.Transparency       = 0.8
    sprinkler.CanCollide         = false
    sprinkler.Anchored           = true
    sprinkler.CastShadow         = false
    sprinkler.Color              = Color3.fromRGB(0, 180, 255)  -- blue tint for editors
    sprinkler.Material           = Enum.Material.Neon
    sprinkler.Parent             = shortcutsFolder
    tag(sprinkler, "Hazard_Sprinkler")

    -- Dog hazard trigger zone (invisible sensor square)
    local dog                    = Instance.new("Part")
    dog.Name                     = "Hazard_Dog"
    dog.Size                     = Vector3.new(4, 0.1, 4)
    dog.CFrame                   = CFrame.new(-55, 0, -10)
    dog.Transparency             = 0.8
    dog.CanCollide               = false
    dog.Anchored                 = true
    dog.CastShadow               = false
    dog.Color                    = Color3.fromRGB(200, 120, 50)  -- orange tint for editors
    dog.Material                 = Enum.Material.Neon
    dog.Parent                   = shortcutsFolder
    tag(dog, "Hazard_Dog")
end

-- ── Entry Point ───────────────────────────────────────────────────────────────

local function buildWorld()
    local ok, err

    ok, err = pcall(buildRoads)
    if not ok then warn("[WorldBuilder] buildRoads failed:", err) end

    ok, err = pcall(buildHazardProps)
    if not ok then warn("[WorldBuilder] buildHazardProps failed:", err) end

    ok, err = pcall(buildShortcuts)
    if not ok then warn("[WorldBuilder] buildShortcuts failed:", err) end

    -- Summary print for server log confirmation
    print(
        "[WorldBuilder] Starter Suburbs built: " .. roadCount .. " roads, "
        .. hazardCount .. " hazards"
    )
end

buildWorld()