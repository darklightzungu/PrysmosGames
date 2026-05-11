-- WorldBuilder.lua
-- Procedurally builds the Starter Suburbs district for Route Rage Terrain
-- Place in: ServerScriptService
-- Runs once on server start

local CollectionService = game:GetService("CollectionService")
local WorldConfig       = require(script.Parent:WaitForChild("WorldConfig"))

-- Counters for final summary print
local roadCount  = 0
local hazardCount = 0
local spawnCount = 0

-- ── Root Model & Folders ─────────────────────────────────────────────────────

local suburbsModel = Instance.new("Model")
suburbsModel.Name   = "StarterSuburbs"
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

-- Creates an anchored Part with common properties and parents it to the given folder
local function makePart(name, size, cframe, color, material, parent)
    local p          = Instance.new("Part")
    p.Name           = name
    p.Size           = size
    p.CFrame         = cframe
    p.Color          = color
    p.Material       = material
    p.Anchored       = true
    p.CanCollide     = true
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
    local asphaltColor = Color3.fromRGB(40, 40, 40)
    local asphalt      = Enum.Material.Asphalt

    -- Main road running along X axis
    makePart("MainRoad",
        Vector3.new(200, 2, 20),
        CFrame.new(0, 0, 0),
        asphaltColor, asphalt, roadsFolder)
    roadCount += 1

    -- Cross street north (+Z)
    makePart("CrossStreet1",
        Vector3.new(100, 2, 16),
        CFrame.new(0, 0, 60),
        asphaltColor, asphalt, roadsFolder)
    roadCount += 1

    -- Cross street south (-Z)
    makePart("CrossStreet2",
        Vector3.new(100, 2, 16),
        CFrame.new(0, 0, -60),
        asphaltColor, asphalt, roadsFolder)
    roadCount += 1

    -- Intersection pad north — slightly raised to prevent Z-fighting with MainRoad
    makePart("Intersection1",
        Vector3.new(20, 2, 20),
        CFrame.new(0, 0.05, 60),
        Color3.fromRGB(35, 35, 35), asphalt, roadsFolder)
    roadCount += 1

    -- Intersection pad south
    makePart("Intersection2",
        Vector3.new(20, 2, 20),
        CFrame.new(0, 0.05, -60),
        Color3.fromRGB(35, 35, 35), asphalt, roadsFolder)
    roadCount += 1

    -- Large grass ground plane beneath everything
    makePart("Ground",
        Vector3.new(400, 2, 400),
        CFrame.new(0, -2, 0),
        Color3.fromRGB(80, 140, 60),
        Enum.Material.Grass, roadsFolder)
    roadCount += 1
end

-- ── Spawn Pads ───────────────────────────────────────────────────────────────

local function buildSpawnPads()
    -- Pull spawn positions from WorldConfig; fall back to empty table if absent
    local area        = (WorldConfig.Areas and WorldConfig.Areas[1]) or {}
    local spawnPoints = area.spawnPoints or {}

    for i, spawnPos in ipairs(spawnPoints) do
        -- Pad sits 1.25 studs above the road surface
        local pad = makePart(
            "SpawnPad_" .. i,
            Vector3.new(6, 0.5, 6),
            CFrame.new(spawnPos + Vector3.new(0, 1.25, 0)),
            Color3.fromRGB(0, 162, 255),
            Enum.Material.Neon,
            spawnPadsFolder
        )
        tag(pad, "SpawnPoint", "SpawnPad")

        -- Billboard label floating above the pad
        local billboard            = Instance.new("BillboardGui")
        billboard.Name             = "SpawnLabel"
        billboard.Size             = UDim2.new(0, 60, 0, 20)
        billboard.StudsOffset      = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop      = false
        billboard.Parent           = pad

        local label                = Instance.new("TextLabel")
        label.Text                 = "SPAWN"
        label.TextColor3           = Color3.new(1, 1, 1)
        label.Font                 = Enum.Font.GothamBold
        label.TextSize             = 14
        label.BackgroundTransparency = 1
        label.Size                 = UDim2.new(1, 0, 1, 0)
        label.Parent               = billboard

        spawnCount += 1
    end
end

-- ── Hazard Props ─────────────────────────────────────────────────────────────

local function buildHazardProps()
    -- ── Hazard Cars ──────────────────────────────────────────────────────────
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
        hazardCount += 1
    end

    -- ── Traffic Cones ────────────────────────────────────────────────────────
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
        hazardCount += 1
    end

    -- ── Concrete Barriers ────────────────────────────────────────────────────
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
        hazardCount += 1
    end
end

-- ── Shortcuts ─────────────────────────────────────────────────────────────────

local function buildShortcuts()
    local shortcutColor    = Color3.fromRGB(100, 160, 70)
    local shortcutMaterial = Enum.Material.Grass

    -- Risky cut-through path 1 (north-east side)
    makePart(
        "ShortcutPath_1",
        Vector3.new(6, 2, 40),
        CFrame.new(55, 0, 30),
        shortcutColor, shortcutMaterial, shortcutsFolder
    )

    -- Risky cut-through path 2 (south-west side)
    makePart(
        "ShortcutPath_2",
        Vector3.new(6, 2, 40),
        CFrame.new(-55, 0, -30),
        shortcutColor, shortcutMaterial, shortcutsFolder
    )

    -- ── Trigger Zones (invisible, non-collidable) ─────────────────────────────

    -- Sprinkler hazard trigger on path 1
    local sprinkler           = Instance.new("Part")
    sprinkler.Name            = "Hazard_Sprinkler"
    sprinkler.Size            = Vector3.new(6, 0.1, 6)
    sprinkler.CFrame          = CFrame.new(55, 0, 10)
    sprinkler.Transparency    = 0.8
    sprinkler.CanCollide      = false
    sprinkler.Anchored        = true
    sprinkler.CastShadow      = false
    sprinkler.Color           = Color3.fromRGB(0, 180, 255)  -- visual hint in Studio
    sprinkler.Material        = Enum.Material.Neon
    sprinkler.Parent          = shortcutsFolder
    tag(sprinkler, "Hazard_Sprinkler")

    -- Dog hazard trigger on path 2
    local dog              = Instance.new("Part")
    dog.Name               = "Hazard_Dog"
    dog.Size               = Vector3.new(4, 0.1, 4)
    dog.CFrame             = CFrame.new(-55, 0, -10)
    dog.Transparency       = 0.8
    dog.CanCollide         = false
    dog.Anchored           = true
    dog.CastShadow         = false
    dog.Color              = Color3.fromRGB(255, 180, 0)     -- visual hint in Studio
    dog.Material           = Enum.Material.Neon
    dog.Parent             = shortcutsFolder
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

    print("[WorldBuilder] Starter Suburbs built: " .. roadCount .. " roads, "
          .. hazardCount .. " hazards, " .. spawnCount .. " spawn pads")
end

buildWorld()