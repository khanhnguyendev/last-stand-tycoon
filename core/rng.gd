class_name Rng
extends RefCounted
## Named, seeded random streams (D-034, D-097, D-108). The only file allowed to create RNGs.

const FNV_OFFSET := 2166136261
const FNV_PRIME := 16777619
const MASK32 := 0xFFFFFFFF

static func fnv1a32(s: String) -> int:
	var h := FNV_OFFSET
	for b in s.to_utf8_buffer():
		h = ((h ^ b) * FNV_PRIME) & MASK32
	return h

static func derive_seed(run_seed: int, day: int, stream_name: StringName) -> int:
	return fnv1a32("%d:%d:%s" % [run_seed, day, stream_name])

static func stream(run_seed: int, day: int, stream_name: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = derive_seed(run_seed, day, stream_name)
	return rng

static func new_run_seed() -> int:
	var s := fnv1a32("%d:%d" % [int(Time.get_unix_time_from_system() * 1000.0), Time.get_ticks_usec()])
	return s if s != 0 else 1
