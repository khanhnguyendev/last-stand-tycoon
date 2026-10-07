class_name MapLayout
extends RefCounted
## The single source of map coordinates (spec 6.1, D-054, D-055, D-062, D-091–D-093, D-112).
## Positions are Vector2(x, z). North = −z. Origin = diner center.

const DINER_HALF := 4.0
const DINER_HEIGHT := 3.0
const BOUNDS_MIN := Vector2(-24, -24)
const BOUNDS_MAX := Vector2(24, 14)
const HOME := Vector2(0, 9.5)  ## outside every zone (D-122); the sign is SIGN
## New game and night-1 restart spawn: north of the diner, off the lane, outside every zone (D-126).
const NIGHT1_START := Vector2(-2.5, -7)
const HERO_RADIUS := 0.4
const TOWER_VISUAL_RADIUS := 0.5  ## mesh only: towers never collide with the hero (D-125)

const LANE_PATHS := {
	"north": [Vector2(0, -24), Vector2(0, -5.2)],
	"west": [Vector2(-16, -24), Vector2(-11, -11), Vector2(-5.2, 0)],
	"east": [Vector2(16, -24), Vector2(11, -11), Vector2(5.2, 0)],
}
## Width axis of each lane's attack zone (D-111).
## Oriented so dot(axis, end-of-path perpendicular) > 0, keeping the blend on one side of the centerline.
const ZONE_AXIS := {"north": Vector2(-1, 0), "west": Vector2(0, 1), "east": Vector2(0, -1)}
## Band between each wall and the reach line (D-101). Rect2(x, z, w, h).
const ZONE_RECTS := {
	"west": Rect2(-5.2, -1.5, 1.2, 3.0),
	"north": Rect2(-1.5, -5.2, 3.0, 1.2),
	"east": Rect2(4.0, -1.5, 1.2, 3.0),
}

const SPOT_IDS: Array[String] = ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e"]
const TOWER_SPOTS := {"tower_nw": Vector2(-5, -5), "tower_ne": Vector2(5, -5), "tower_w": Vector2(-10.6, 0.6), "tower_e": Vector2(8.8, 1.1)}
const TOWER_LANES := {"tower_nw": ["west", "north"], "tower_ne": ["north", "east"], "tower_w": ["west"], "tower_e": ["east"]}
const FENCE_LANE := {"fence_w": "west", "fence_n": "north", "fence_e": "east"}
const LANE_FENCE := {"west": "fence_w", "north": "fence_n", "east": "fence_e"}
const FENCE_OFFSET_FROM_END := 4.0
const TELEGRAPH_OFFSET_FROM_END := 5.5

## E5 (spec 5.1, D-239, D-240): spots a tier unlocks (appended to spots_for_tier), the side yards (Rect2(x, z, w, h)) and
## the tier sign, which stands on the land it sells. SPOT_IDS stays the tier-1 list; nothing above moves.
const TIER_SPOTS := {2: ["tower_w", "tower_e"], 3: ["tower_sw", "fence_sw"]}
const YARDS := {"west": Rect2(-13.5, -2.5, 4.5, 10.5), "east": Rect2(8.0, -0.5, 5.0, 3.5)}
const YARD_TIER := {"west": 2, "east": 2}
const TIER_SIGN := Vector2(-10.0, 7.5)
const ALL_SPOT_IDS: Array[String] = ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e", "tower_w", "tower_e", "tower_sw", "fence_sw"]

## E5 tier 3 (spec 4.1, D-271). The tier-3 entries live in their own dictionaries, NOT in LANE_PATHS, ZONE_RECTS, ZONE_AXIS, FENCE_LANE,
## LANE_FENCE, TOWER_SPOTS, TOWER_LANES or YARDS: art/env/ground.gd and art/env/lane_strip.gd iterate LANE_PATHS by key and would draw the
## south-west strip at tiers 1 and 2. Read every lane, zone, fence and tower through the accessors below (lane_path, zone_rect, ...) and
## iterate lanes_for_tier(tier) / spots_for_tier(tier); the shared dictionaries are the tier 1 and 2 data and never change.
const LANE_PATHS_T3 := {"sw": [Vector2(-24, 11), Vector2(-3.5, 11.0), Vector2(-2.75, 5.2)]}
const ZONE_AXIS_T3 := {"sw": Vector2(1, 0)}
const ZONE_RECTS_T3 := {"sw": Rect2(-4.0, 4.0, 2.5, 1.2)}
const TOWER_SPOTS_T3 := {"tower_sw": Vector2(-6.6, 5.6)}
const TOWER_LANES_T3 := {"tower_sw": ["sw", "west"]}
const FENCE_LANE_T3 := {"fence_sw": "sw"}
const LANE_FENCE_T3 := {"sw": "fence_sw"}
const YARDS_T3 := {"front": Rect2(-7.6, 5.6, 6.1, 4.3)}
const YARD_TIER_T3 := {"front": 3}
## The sign of tier N sells tier N and is shown at tier N - 1 (TIER_SIGN is the tier-2 value, kept).
const TIER_SIGNS := {2: Vector2(-10.0, 7.5), 3: Vector2(-5.6, 9.0)}
## From tier 3 (spec 4.2): today's slots 2 to 4 would sit on the south-west lane or in its fence, and today's west exit would pass the tower.
const QUEUE_SLOTS_T3 := [Vector2(0, 6.0), Vector2(1.1, 6.9), Vector2(1.3, 8.0), Vector2(1.4, 9.1),
	Vector2(1.8, 10.3), Vector2(3.0, 10.3), Vector2(4.2, 10.3), Vector2(5.4, 10.3), Vector2(6.6, 10.3)]
const TRAVELER_EXIT_T3 := Vector2(24, 11)
## Branch pads (spec 4.3): radius, and two pad centres per spot, chosen with tools/probe_t3_layout.gd and pinned by test_branch_pad_layout.
const BRANCH_PAD_RADIUS := 0.9
const BRANCH_PADS := {
	"tower_sw": [Vector2(-8.2, 6.8), Vector2(-6.5, 3.6)],
	"fence_sw": [Vector2(-5.6, 7.8), Vector2(-1.0, 10.7)],
	"fence_w": [Vector2(-9.8, -3.4), Vector2(-8.8, -1.4)],
	"fence_n": [Vector2(-2.5, -10.4), Vector2(2.5, -10.4)],
	"fence_e": [Vector2(8.8, -1.4), Vector2(9.8, -3.4)],
	"tower_nw": [Vector2(-5.9, -6.8), Vector2(-3.4, -6.2)],
	"tower_ne": [Vector2(3.4, -6.2), Vector2(5.9, -6.8)],
	"tower_w": [Vector2(-12.6, 0.6), Vector2(-9.0, 1.8)],
	"tower_e": [Vector2(7.6, 2.7), Vector2(10.8, 1.1)],
}

static func spots_for_tier(tier: int) -> Array[String]:
	var out: Array[String] = []
	out.assign(SPOT_IDS)
	for t in range(2, tier + 1):
		if TIER_SPOTS.has(t):
			out.append_array(TIER_SPOTS[t])
	return out

static func yards_for_tier(tier: int) -> Array[String]:
	var out: Array[String] = []
	for id in YARDS:
		if int(YARD_TIER[id]) <= tier:
			out.append(id)
	for id in YARDS_T3:
		if int(YARD_TIER_T3[id]) <= tier:
			out.append(id)
	return out

static func yard_rect(id: String) -> Rect2:
	return YARDS_T3[id] if YARDS_T3.has(id) else YARDS[id]

static func yard_tier(id: String) -> int:
	return int(YARD_TIER_T3[id]) if YARD_TIER_T3.has(id) else int(YARD_TIER[id])

## The lanes monsters use at `tier`: the three of tiers 1 and 2, plus the south-west lane from tier 3 (spec 3.1).
static func lanes_for_tier(tier: int) -> Array[String]:
	var out: Array[String] = ["west", "north", "east"]
	if tier >= 3:
		out.append("sw")
	return out

static func lane_path(lane: String) -> Array:
	return LANE_PATHS_T3[lane] if LANE_PATHS_T3.has(lane) else LANE_PATHS[lane]

static func zone_rect(lane: String) -> Rect2:
	return ZONE_RECTS_T3[lane] if ZONE_RECTS_T3.has(lane) else ZONE_RECTS[lane]

static func zone_axis(lane: String) -> Vector2:
	return ZONE_AXIS_T3[lane] if ZONE_AXIS_T3.has(lane) else ZONE_AXIS[lane]

static func fence_lane(spot_id: String) -> String:
	return FENCE_LANE_T3[spot_id] if FENCE_LANE_T3.has(spot_id) else FENCE_LANE[spot_id]

static func lane_fence(lane: String) -> String:
	return LANE_FENCE_T3[lane] if LANE_FENCE_T3.has(lane) else LANE_FENCE[lane]

static func tower_spot(spot_id: String) -> Vector2:
	return TOWER_SPOTS_T3[spot_id] if TOWER_SPOTS_T3.has(spot_id) else TOWER_SPOTS[spot_id]

static func tower_lanes(spot_id: String) -> Array:
	return TOWER_LANES_T3[spot_id] if TOWER_LANES_T3.has(spot_id) else TOWER_LANES[spot_id]

## Position of the sign that sells `tier`.
static func tier_sign(tier: int) -> Vector2:
	return TIER_SIGNS[tier]

static func queue_slots(tier: int) -> Array:
	return QUEUE_SLOTS_T3 if tier >= 3 else QUEUE_SLOTS

static func traveler_exit(tier: int) -> Vector2:
	return TRAVELER_EXIT_T3 if tier >= 3 else TRAVELER_EXIT

static func spot_tier(spot_id: String) -> int:
	for t in TIER_SPOTS:
		if spot_id in TIER_SPOTS[t]:
			return t
	return 1

const COUNTER := Vector2(0, 4.8)
const COUNTER_SIZE := Vector2(3, 1)
const COUNTER_DROP := Vector2(2.2, 4.8)
const SERVICE_POINT := Vector2(0, 6.0)
## Slots 0-3: the S1 diagonal. Slots 4-8 (E1, D-230): a second row on the road's north edge (the strip spans ROAD_Z ± 1.0), filling eastward, so an
## arriving traveler never walks through the queue and the whole line is on screen from the counter.
const QUEUE_SLOTS := [Vector2(0, 6.0), Vector2(-1.2, 7.0), Vector2(-2.4, 8.0), Vector2(-3.6, 9.0),
	Vector2(-3.0, 10.3), Vector2(-1.8, 10.3), Vector2(-0.6, 10.3), Vector2(0.6, 10.3), Vector2(1.8, 10.3)]
const GOLD_PILE := Vector2(-2.5, 5.5)
const FREEZER := Vector2(5.5, 5.0)
const FREEZER_SIZE := Vector2(1.5, 1.5)
const FREEZER_ZONE := Vector2(5.5, 6.3)
const SIGN := Vector2(0, 8)
const ROAD_Z := 11.0
const TRAVELER_ENTER := Vector2(24, 11)
const TRAVELER_EXIT := Vector2(-24, 11)
const STATION_RADIUS := 1.0
const BUILD_RADIUS := 1.2
## E1 upgrade pads (radius BUILD_RADIUS) and where the hero stands to use each station (camera test).
const STATION_PADS := {&"counter": Vector2(2.6, 7.2), &"freezer": Vector2(7.9, 7.0)}
const STATION_STAND := {&"counter": COUNTER_DROP, &"freezer": FREEZER_ZONE}

## S2 guard posts (D-163): the Archer on the diner roof; the Tank on the west lane's center line,
## TANK_POST_BACK m before the lane end. A knocked-out guard respawns at DINER_DOOR (D-165).
const GUARD_POST_ARCHER := Vector2(2.5, -2.5)
const DINER_DOOR := Vector2(-3.0, 4.6)
const TANK_POST_BACK := 3.0

static func guard_post(id: StringName) -> Vector2:
	if id == &"archer":
		return GUARD_POST_ARCHER
	assert(id == &"tank", "no guard post for %s" % id)
	return Geometry.point_back_from_end(LANE_PATHS["west"], TANK_POST_BACK)

## Door -> south-west corner (outside the diner) -> Tank post; test_geometry proves it clears the diner and towers.
static func tank_return_path() -> Array:
	return [DINER_DOOR, Vector2(-5.0, 4.6), guard_post(&"tank")]

static func to3(v: Vector2, y := 0.0) -> Vector3:
	return Vector3(v.x, y, v.y)

static func path_length(lane: String) -> float:
	return Geometry.path_length(lane_path(lane))

static func lane_end(lane: String) -> Vector2:
	var path: Array = lane_path(lane)
	return path[path.size() - 1]

static func fence_spot(lane: String) -> Vector2:
	return Geometry.point_back_from_end(lane_path(lane), FENCE_OFFSET_FROM_END)

static func telegraph_spot(lane: String) -> Vector2:
	return Geometry.point_back_from_end(lane_path(lane), TELEGRAPH_OFFSET_FROM_END)

static func spot_kind(spot_id: String) -> String:
	return "tower" if spot_id.begins_with("tower") else "fence"

static func spot_position(spot_id: String) -> Vector2:
	if TOWER_SPOTS.has(spot_id) or TOWER_SPOTS_T3.has(spot_id):
		return tower_spot(spot_id)
	return fence_spot(fence_lane(spot_id))
