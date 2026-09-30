class_name Phase
extends RefCounted
## Phase ids (spec 2). Stored as int in signals.

const NIGHT := 0
const DAWN := 1
const DAY := 2

static func name_of(p: int) -> String:
	return ["NIGHT", "DAWN", "DAY"][p]
