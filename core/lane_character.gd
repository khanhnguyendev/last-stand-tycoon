class_name LaneCharacter
extends RefCounted
## E6 (spec 3.1, D-282): the run's persistent lane character at tier 3. One SIEGE lane (all siege brutes walk it)
## and one HARE lane (most hares do), drawn once per run, so a permanent building choice can be informed by
## something that does not change every night. Pure: no scene or autoload access.

const SIEGE := &"siege"
const HARE := &"hare"
const NEUTRAL := &"neutral"

## Returns {"siege": lane, "hare": lane}. The result is pinned forever by saves, so the draw is exactly:
##   var rng := Rng.stream(run_seed, 0, &"lane_character")
##   siege = lanes[rng.randi_range(0, 3)]            # lanes = LanePlanner.lanes_for_tier(3)
##   hare  = others[rng.randi_range(0, 2)]           # others = lanes without siege, in the list's order
## Two draws, in that order. Never reorder, add a draw before them, or change the stream name or day.
static func for_run(run_seed: int) -> Dictionary:
	var lanes := LanePlanner.lanes_for_tier(3)
	var rng := Rng.stream(run_seed, 0, &"lane_character")
	var siege: String = lanes[rng.randi_range(0, lanes.size() - 1)]
	var others: Array = lanes.filter(func(l): return l != siege)
	var hare: String = others[rng.randi_range(0, others.size() - 1)]
	return {"siege": siege, "hare": hare}

## &"siege", &"hare" or &"neutral". An empty character is neutral on every lane.
static func lane_type(character: Dictionary, lane: String) -> StringName:
	if character.is_empty():
		return NEUTRAL
	if String(character.get("siege", "")) == lane:
		return SIEGE
	if String(character.get("hare", "")) == lane:
		return HARE
	return NEUTRAL

## The types of the lanes a building covers, in order.
static func spot_types(character: Dictionary, lanes: Array) -> Array:
	var out: Array = []
	for lane in lanes:
		out.append(lane_type(character, String(lane)))
	return out
