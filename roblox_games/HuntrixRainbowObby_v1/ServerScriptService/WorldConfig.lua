-- WorldConfig.lua — Huntrix Rainbow Carpet Obby (kid-safe, ages 5+)
-- ServerScriptService ModuleScript

local WorldConfig = {}

WorldConfig.GameTitle = "Huntrix Rainbow Carpet Adventure"
WorldConfig.FallKillY = -50
WorldConfig.CarpetBoostDuration = 4
WorldConfig.CarpetBoostCooldown = 8

-- Rainbow palette for platforms (bright, friendly)
WorldConfig.RainbowColors = {
	Color3.fromRGB(255, 105, 180), -- pink
	Color3.fromRGB(255, 165, 0),   -- orange
	Color3.fromRGB(255, 255, 100), -- yellow
	Color3.fromRGB(144, 238, 144), -- green
	Color3.fromRGB(135, 206, 250), -- sky blue
	Color3.fromRGB(186, 85, 211),  -- purple
}

WorldConfig.Stages = {
	{
		name = "Sparkle Start",
		spawn = Vector3.new(0, 8, 0),
		checkpoint = Vector3.new(0, 8, 0),
		stars = {
			Vector3.new(6, 10, 0),
			Vector3.new(-6, 10, 0),
		},
	},
	{
		name = "Rainbow Bridge",
		spawn = Vector3.new(0, 12, 40),
		checkpoint = Vector3.new(0, 12, 40),
		stars = {
			Vector3.new(0, 14, 55),
			Vector3.new(8, 14, 70),
			Vector3.new(-8, 14, 85),
		},
	},
	{
		name = "Flying Carpet Clouds",
		spawn = Vector3.new(0, 20, 120),
		checkpoint = Vector3.new(0, 20, 120),
		stars = {
			Vector3.new(12, 22, 135),
			Vector3.new(-12, 24, 150),
			Vector3.new(0, 26, 165),
		},
	},
	{
		name = "Star Finish",
		spawn = Vector3.new(0, 28, 200),
		checkpoint = Vector3.new(0, 28, 200),
		stars = {
			Vector3.new(0, 30, 210),
			Vector3.new(6, 30, 215),
			Vector3.new(-6, 30, 215),
		},
	},
}

return WorldConfig
