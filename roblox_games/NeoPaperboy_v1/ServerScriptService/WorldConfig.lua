-- WorldConfig.lua — Daily Blox Delivery (Neo Paperboy v1)
-- Centralised world configuration; consumed by both Server and Client scripts.
-- Never mutate this table at runtime — treat it as read-only data.

local WorldConfig = {}

-- ─── Game Identity ────────────────────────────────────────────────────────────
WorldConfig.GameTitle      = "Daily Blox Delivery"

-- ─── Street / Scroll Parameters ───────────────────────────────────────────────
WorldConfig.ScrollSpeed    = 32   -- studs per second (world moves toward player)
WorldConfig.RoadHalfWidth  = 16   -- studs from street centre to kerb edge
WorldConfig.StreetLength   = 600  -- total playable street depth in studs
WorldConfig.FallKillY      = -20  -- Y threshold below which the bike is destroyed

-- ─── Player Starting State ────────────────────────────────────────────────────
WorldConfig.StartLives       = 3
WorldConfig.StartSubscribers = 8   -- houses that begin as active subscribers
WorldConfig.PaperCount       = 20  -- newspapers in the basket at round start

-- ─── Scoring Table ────────────────────────────────────────────────────────────
-- Keys match delivery-target types and gameplay events.
WorldConfig.Score = {
	Mailbox  = 700,  -- perfect delivery into the mailbox slot
	Porch    = 350,  -- lands on the porch (good, not perfect)
	Chaos    = 300,  -- hits a non-subscriber target (chaos bonus)
	Bundle   = 50,   -- picking up a paper bundle mid-street
}

-- ─── House Definitions ────────────────────────────────────────────────────────
-- Each entry describes one house on the street.
--   z          : depth position along the street (studs from start)
--   x          : lateral offset from street centre (negative = left side)
--   subscriber : true  → player should deliver here; false → non-subscriber (avoid)
WorldConfig.Houses = {
	{ z =  60,  x = -14, subscriber = true  },
	{ z =  60,  x =  14, subscriber = true  },
	{ z = 120,  x = -14, subscriber = true  },
	{ z = 120,  x =  14, subscriber = false },  -- non-subscriber: avoid delivery
	{ z = 200,  x = -14, subscriber = true  },
	{ z = 200,  x =  14, subscriber = true  },
	{ z = 280,  x = -14, subscriber = false },  -- non-subscriber: avoid delivery
	{ z = 280,  x =  14, subscriber = true  },
	{ z = 360,  x = -14, subscriber = true  },
	{ z = 360,  x =  14, subscriber = true  },
	{ z = 440,  x = -14, subscriber = true  },
	{ z = 520,  x =  14, subscriber = false },  -- non-subscriber: avoid delivery
}

-- ─── Obstacle Definitions ─────────────────────────────────────────────────────
-- Each entry describes one obstacle the bike must dodge.
--   kind : asset tag used by the obstacle spawner
--   z    : depth position along the street
--   lane : integer lane index (0 = centre) used for moving obstacles (e.g. cars)
--   x    : explicit lateral offset for static obstacles; overrides lane when present
--
-- NOTE: Moving obstacles (car, pothole) use `lane`; static props use `x`.
--       Spawner code should prefer `x` when present, otherwise derive x from `lane`.
WorldConfig.Obstacles = {
	{ kind = "car",     z = 180, lane =  0            },  -- oncoming vehicle, centre lane
	{ kind = "dog",     z = 260,             x = -10  },  -- chasing dog, left kerb
	{ kind = "trash",   z = 320,             x =  12  },  -- bin on right side
	{ kind = "hydrant", z = 400,             x = -12  },  -- fire hydrant, left side
	{ kind = "sign",    z = 480,             x =  10  },  -- road sign, right side
	{ kind = "pothole", z = 540, lane =  0            },  -- sunken road section
}

-- ─── Derived / Computed Constants ─────────────────────────────────────────────
-- Computed once here so consumers never recalculate inline.

-- Total subscriber count (used to initialise delivery-completion tracking)
local subscriberCount = 0
for _, house in ipairs(WorldConfig.Houses) do
	if house.subscriber then
		subscriberCount = subscriberCount + 1
	end
end
WorldConfig.SubscriberCount = subscriberCount  -- 9 for the default layout above

-- Sanity guard: warn if PaperCount is fewer than subscribers (round unwinnable)
if WorldConfig.PaperCount < WorldConfig.SubscriberCount then
	warn(string.format(
		"[WorldConfig] PaperCount (%d) is less than SubscriberCount (%d) — "
		.. "round cannot be completed perfectly.",
		WorldConfig.PaperCount,
		WorldConfig.SubscriberCount
	))
end

-- Freeze the table so accidental writes produce a clear error at the call site.
-- Deep-freeze helper (one level is sufficient for this flat config).
local function shallowFreeze(t)
	return setmetatable(t, {
		__newindex = function(_, key)
			error(string.format(
				"[WorldConfig] Attempt to write read-only field '%s'.", tostring(key)
			), 2)
		end,
		__metatable = "locked",
	})
end

shallowFreeze(WorldConfig.Score)
shallowFreeze(WorldConfig)

return WorldConfig