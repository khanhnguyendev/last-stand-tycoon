class_name BranchPadHint
extends Node
## The one-time onboarding pointer at a branch pad (E5 tier 3 Task 17, D-273.5): the first time a branch pad is visible in a game,
## ever (remembered in the shared SettingsStore as `branch_hint_done`, like `guide_done`), the Guide's world pointer bounces over the
## SHOWN pad nearest the hero, at the Guide's pointer height, once it is on screen from where the hero stands. The flag is saved when
## the pointer has actually been shown. It goes away when the hero steps on any pad, when the pad is gone, or at night; it never
## returns and the node stops processing. Visual only: it reads the world, writes nothing but its own flag.
## Main builds it (only while the flag is false) with `setup(world, settings_store)`; tests give a temp-dir store.

const POINTER_SCENE := preload("res://art/fx/pointer.tscn")

var world: World
var store: SettingsStore
var pointer: Node3D
## The pad the pointer is over now (null when it is not showing).
var target: BranchPad
## How many times the pointer has been shown in this game (0 or 1: the flag stops a second time).
var shown_count := 0
var _t := 0.0

func setup(p_world: World, p_store: SettingsStore) -> void:
	world = p_world
	store = p_store
	pointer = POINTER_SCENE.instantiate()
	pointer.visible = false
	add_child(pointer)
	set_physics_process(not store.branch_hint_done)

func _physics_process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	if target != null:
		if not target.is_shown() or _hero_on_a_pad():
			target = null
			pointer.visible = false
			if store.branch_hint_done:
				set_physics_process(false)  # done: nothing left to watch
			return
		var bounce := sin(_t * TAU * Balance.ui.guide_bounce_hz) * Balance.ui.guide_bounce_m
		pointer.global_position = target.global_position + Vector3(0.0, Balance.ui.guide_pointer_h + bounce, 0.0)
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			pointer.global_basis = cam.global_basis
		return
	if store.branch_hint_done:
		set_physics_process(false)
		return
	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
	if hero == null:
		return
	var best: BranchPad = null
	var best_d := INF
	for id in world.branch_pads:
		for p in world.branch_pads[id]:
			var pad := p as BranchPad
			if not pad.is_shown():
				continue
			var d := Vector2(hero.global_position.x - pad.global_position.x, hero.global_position.z - pad.global_position.z).length()
			if d < best_d:
				best_d = d
				best = pad
	if best == null or not _on_screen(best, hero):
		return
	target = best
	store.branch_hint_done = true  # shown on screen: remembered now
	store.save_settings()
	shown_count += 1
	pointer.visible = true

## The pad and the pointer above it are on screen from where the hero stands (the camera follows the hero: CameraMath).
func _on_screen(pad: BranchPad, hero: Node3D) -> bool:
	var vp := get_viewport().get_visible_rect().size
	var xf := CameraMath.camera_transform(CameraMath.focus_for(Vector2(hero.global_position.x, hero.global_position.z)), Balance.ui)
	var proj := CameraMath.projection(Balance.ui, vp.x / maxf(vp.y, 1.0))
	var top := pad.global_position + Vector3(0.0, Balance.ui.guide_pointer_h + PointerMesh.HEIGHT, 0.0)
	return CameraMath.on_screen(pad.global_position, xf, proj) and CameraMath.on_screen(top, xf, proj)

func _hero_on_a_pad() -> bool:
	for id in world.branch_pads:
		for p in world.branch_pads[id]:
			if (p as BranchPad).hero_inside():
				return true
	return false
