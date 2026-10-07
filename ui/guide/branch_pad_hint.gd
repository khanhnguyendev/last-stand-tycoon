class_name BranchPadHint
extends Node
## The one-time onboarding pointer at a branch pad (E5 tier 3 Task 17, D-273.5): the first time a branch pad is visible in a game,
## ever (remembered in BranchHintStore), the Guide's world pointer bounces over ONE pad. It goes away when the hero steps on any
## pad (the preview takes over), when the pad is gone, or at night; it never returns. Visual only: it reads the world, writes
## nothing but its own flag. Main builds it with `setup(world, BranchHintStore.for_platform())`; tests give a temp-dir store.

const POINTER_SCENE := preload("res://art/fx/pointer.tscn")
## Above the tallest label of the pad's stack, so the arrow points down at the pad and covers nothing.
const POINTER_Y := 6.6

var world: World
var store: BranchHintStore
var pointer: Node3D
## The pad the pointer is over now (null when it is not showing).
var target: BranchPad
## How many times the pointer has been shown in this game (0 or 1: the flag stops a second time).
var shown_count := 0
var _t := 0.0

func setup(p_world: World, p_store: BranchHintStore) -> void:
	world = p_world
	store = p_store
	pointer = POINTER_SCENE.instantiate()
	pointer.visible = false
	add_child(pointer)

func _physics_process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	if target != null:
		if not target.is_shown() or _hero_on_a_pad():
			target = null
			pointer.visible = false
			return
		var bounce := sin(_t * TAU * Balance.ui.guide_bounce_hz) * Balance.ui.guide_bounce_m
		pointer.global_position = target.global_position + Vector3(0.0, POINTER_Y + bounce, 0.0)
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			pointer.global_basis = cam.global_basis
		return
	if store.done:
		return
	for id in MapLayout.spots_for_tier(GameState.tier):
		var pads: Array = world.branch_pads.get(id, [])
		if not pads.is_empty() and (pads[0] as BranchPad).is_shown():
			target = pads[0]
			store.done = true
			store.save_store()
			shown_count += 1
			pointer.visible = true
			return

func _hero_on_a_pad() -> bool:
	for id in world.branch_pads:
		for p in world.branch_pads[id]:
			if (p as BranchPad).hero_inside():
				return true
	return false
