class_name TickBudget
extends RefCounted
## Deterministic sim budget (D-247): each sim test records the physics ticks it simulated, and a suite fails
## when a test exceeds its expected ticks (committed golden file) by more than TOLERANCE.
## Pure static; no scene access. Keys are "<script res path>::<test name>".

const TOLERANCE := 0.2
const GOLDEN_PATH := "res://tests/sim_ticks.golden.json"


## One line per problem; empty when the budget holds. Only keys under `suite_dir + "/"` are considered.
static func check(actual: Dictionary, golden: Dictionary, suite_dir: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var prefix := suite_dir + "/"
	var limit_pct := roundi((1.0 + TOLERANCE) * 100.0)
	var tol_pct := roundi(TOLERANCE * 100.0)
	var akeys: Array = actual.keys()
	akeys.sort()
	for k in akeys:
		var key := String(k)
		if not key.begins_with(prefix):
			continue
		if not golden.has(key):
			problems.append("%s: no expected tick count; add it to the golden file deliberately" % key)
			continue
		var a := int(actual[key])
		var e := int(golden[key])
		if a * 100 > e * limit_pct:
			var pct := (a - e) * 100.0 / maxf(float(e), 1.0)
			problems.append("%s: %d ticks, expected %d (+%.1f%%, limit +%d%%)" % [key, a, e, pct, tol_pct])
	var gkeys: Array = golden.keys()
	gkeys.sort()
	for k in gkeys:
		var key := String(k)
		if key.begins_with(prefix) and not actual.has(key):
			problems.append("%s: in the golden file but did not run (never drop a sim, D-132)" % key)
	return problems


static func load_golden() -> Dictionary:
	if not FileAccess.file_exists(GOLDEN_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	if parsed is Dictionary:
		var out := {}
		for k in parsed:
			out[String(k)] = int(parsed[k])
		return out
	return {}


static func save_golden(d: Dictionary) -> void:
	var keys: Array = d.keys()
	keys.sort()
	var lines := PackedStringArray()
	for k in keys:
		lines.append("  %s: %d" % [JSON.stringify(String(k)), int(d[k])])
	var text := "{\n" + ",\n".join(lines) + "\n}\n" if not lines.is_empty() else "{}\n"
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()
