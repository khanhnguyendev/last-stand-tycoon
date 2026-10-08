extends GutTest

## Golden values (D-130, D-134).
## "seeds": FNV-1a 32 of "20260930:<day>:<stream>", days 1–30, from an independent reference. It is the
##   true oracle: a seed mismatch is a derivation bug. Escalate; never edit this list.
## "first": the first randi() of each stream. It starts from an UNVERIFIED Python replica of Godot's
##   RandomPCG. If, on the FIRST Task 3 run, every seed passes but "first" fails, replace "first" with
##   values captured from the pinned GODOT_TAG engine, log that decision, and freeze the list. From then
##   on any mismatch is escalated and never silently regenerated.
const GOLDEN_RUN_SEED := 20260930
const GOLDEN := {
	&"lane_plan": {
		"seeds": [
			1134225596, 2612275673, 2197898854, 294757867, 77956904, 4026147925, 2561854546, 392618375, 2382490068, 2284203448,
			1806702523, 4167824802, 2799489509, 2311279820, 807322655, 3889261174, 2518233961, 89412688, 4234412627, 3666120943,
			155795804, 39263737, 368497798, 3268737035, 2475869000, 206479861, 1619169138, 2300074535, 2168788340, 3851402902,
		],
		"first": [
			982263674, 2176323166, 3238188479, 3368145719, 1234230965, 3109628391, 2159941969, 3375391918, 2255527354, 263167400,
			2060852024, 2106045376, 3529827490, 3840523951, 2746769375, 588929936, 3728030851, 3081809858, 901593407, 1092658841,
			4211841515, 3591191369, 165663572, 348143332, 3925096213, 2777594316, 3384715265, 2039596329, 1528698510, 656414399,
		],
	},
	&"spawns": {
		"seeds": [
			3552542920, 3082638567, 2235635290, 3873018793, 3447222812, 1872249579, 3161085038, 3186541453, 98592880, 2757118156,
			1413269657, 2173656414, 159813019, 3249958648, 2039657749, 829452170, 4175368791, 4029844244, 3522715393, 51971333,
			2233232424, 1471707079, 3130926906, 3662825097, 3570123644, 1279175115, 2568010574, 2593466989, 221596880, 3514938474,
		],
		"first": [
			650738716, 1703870746, 2893652679, 750204739, 2692720213, 2621354981, 622020695, 292235156, 2992577952, 3570663851,
			2182738079, 1162675790, 3034859318, 220721513, 4239364696, 3161825226, 264160985, 2350020726, 3609720301, 3003290713,
			1777538403, 4111975843, 3252279489, 1471586341, 3628916440, 665381522, 1165781075, 3821350835, 1260613377, 2332073099,
		],
	},
	&"travelers": {
		"seeds": [
			1037452772, 3764324805, 540417362, 2352332251, 3327093240, 3881382265, 4113671414, 3298653007, 2415790556, 1238013544,
			4222653707, 894706278, 2266828137, 3820948948, 2251913959, 3083357378, 2531954293, 1147363744, 3644043139, 1082525719,
			2036120260, 3567974437, 3992866994, 4212734267, 3675015384, 2348268249, 2378986838, 3986181295, 4154292924, 2755827234,
		],
		"first": [
			2326239200, 1095793081, 1403444951, 133880543, 2962542670, 3509341101, 1359385378, 3431938266, 1091111726, 2506745929,
			4100069274, 1019532442, 212007670, 2972616008, 1704051235, 262048066, 2923729206, 1885323088, 4167720434, 3728583517,
			197587392, 3682149064, 3261978064, 1389963297, 3079065814, 1797102475, 3185963683, 4222814056, 2631372803, 1168296846,
		],
	},
	&"drops": {
		"seeds": [
			221602518, 3728831699, 2212039968, 3271538453, 1428158962, 2471274223, 4210337772, 3807603825, 439648654, 1986480738,
			1524644037, 3410230876, 3658510367, 2151169286, 2438740457, 1836390544, 4149987075, 679600634, 2290389949, 1060493977,
			2261392054, 328039219, 1299769216, 2677244021, 1555021778, 1517529935, 3574363468, 2470875601, 524831598, 1186286576,
		],
		"first": [
			1157851790, 3552634191, 2671218064, 3522585653, 2540771891, 663546705, 2005689044, 1588691184, 2381121139, 64950392,
			2915435827, 3785732610, 812727903, 853077187, 2631317515, 304738107, 1989086258, 1771721265, 1664518914, 907789140,
			881532959, 207269281, 3804631421, 757119745, 2277132098, 1494116371, 2144379826, 3669206535, 2405477159, 1061516348,
		],
	},
}

func test_golden_seeds_distinct_and_stable() -> void:
	# D-130: all 4 stream names x days 1–30 give distinct seeds, equal to the committed golden list.
	var seen := {}
	for stream_name in GOLDEN:
		var seeds: Array = GOLDEN[stream_name].seeds
		for d in range(1, 31):
			var got := Rng.derive_seed(GOLDEN_RUN_SEED, d, stream_name)
			assert_eq(got, int(seeds[d - 1]), "%s day %d" % [stream_name, d])
			seen[got] = true
	assert_eq(seen.size(), 4 * 30, "all 120 seeds distinct")

func test_golden_first_values() -> void:
	for stream_name in GOLDEN:
		var first: Array = GOLDEN[stream_name].first
		for d in range(1, 31):
			var rng := Rng.stream(GOLDEN_RUN_SEED, d, stream_name)
			assert_eq(int(rng.randi()), int(first[d - 1]), "%s day %d first randi" % [stream_name, d])

func test_fnv1a32_known_vectors() -> void:
	assert_eq(Rng.fnv1a32(""), 2166136261)
	assert_eq(Rng.fnv1a32("a"), 3826002220)
	assert_eq(Rng.fnv1a32("foobar"), 3214735720)

func test_same_inputs_same_sequence() -> void:
	var a := Rng.stream(42, 3, &"spawns")
	var b := Rng.stream(42, 3, &"spawns")
	for i in 20:
		assert_eq(a.randi(), b.randi())

func test_streams_differ_by_name_day_and_seed() -> void:
	var base := Rng.derive_seed(42, 3, &"spawns")
	assert_ne(base, Rng.derive_seed(42, 3, &"drops"))
	assert_ne(base, Rng.derive_seed(42, 4, &"spawns"))
	assert_ne(base, Rng.derive_seed(43, 3, &"spawns"))

func test_new_run_seed_is_nonzero() -> void:
	assert_ne(Rng.new_run_seed(), 0)

## E6 task 2: stream identity. The first three randi() of EVERY stream used by production code (grep Rng.stream:
## lane_plan, cards, spawns, drops, travelers), captured from the code BEFORE &"lane_character" was added.
## A later change that shifts a stream fails here. Never regenerate silently.
const PINNED_PROD_STREAMS := {
	&"lane_plan": {1: [982263674, 3566436726, 4133231561], 3: [3238188479, 2011179619, 3794814636]},
	&"cards": {1: [3017969449, 3113214463, 4065174797], 3: [2317415651, 3759696000, 1490404807]},
	&"spawns": {1: [650738716, 3217271523, 1430698105], 3: [2893652679, 2732774452, 1079296089]},
	&"drops": {1: [1157851790, 1041351977, 3806099412], 3: [2671218064, 1256413913, 2230018907]},
	&"travelers": {1: [2326239200, 1697935363, 1249486560], 3: [1403444951, 801686502, 2188915574]},
}

func test_production_stream_identity_pins() -> void:
	for n in PINNED_PROD_STREAMS:
		for d in PINNED_PROD_STREAMS[n]:
			var rng := Rng.stream(GOLDEN_RUN_SEED, d, n)
			var got := [int(rng.randi()), int(rng.randi()), int(rng.randi())]
			assert_eq(got, PINNED_PROD_STREAMS[n][d], "%s day %d first three" % [n, d])

## The new E6 stream, pinned by literals (seed from the FNV-1a of "20260930:0:lane_character", then its first three randi()).
## Saves depend on it forever. Mutation: the stream renamed, moved to another day, or derived differently.
func test_lane_character_stream_is_pinned() -> void:
	assert_false(PINNED_PROD_STREAMS.has(&"lane_character"), "new name, not one of the pre-existing streams")
	assert_eq(Rng.derive_seed(GOLDEN_RUN_SEED, 0, &"lane_character"), 2971160035)
	var rng := Rng.stream(GOLDEN_RUN_SEED, 0, &"lane_character")
	assert_eq([int(rng.randi()), int(rng.randi()), int(rng.randi())], [3561404524, 1919775873, 3074756434])
