class_name Visuals
extends RefCounted
## What is left of the S1 placeholder helpers (D-016, D-075) after S4 Task 13: every actor keeps a child named "Visual"
## (D-190). The asset validator bans placeholder primitives in game code (PLACEHOLDERS_ARE_ERRORS).

static func visual_root() -> Node3D:
	var n := Node3D.new()
	n.name = "Visual"
	return n
