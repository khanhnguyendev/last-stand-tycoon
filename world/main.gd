class_name Main
extends Node3D
## Scene root (world/main.tscn, spec 3.3). Orchestrated nodes live in the scene and are wired with
## typed @export references (D-128); everything else is built in code. Extended in Tasks 13–32.

const SCENE_PATH := "res://world/main.tscn"

@export var auto_start := true
@export var world: World
@export var phase_controller: PhaseController

static func create(p_auto_start := false) -> Main:
	var m: Main = (load(SCENE_PATH) as PackedScene).instantiate()
	m.auto_start = p_auto_start
	return m

var hero: Hero
var camera_rig: CameraRig
var joystick: Joystick
var focus_pause: FocusPause
var hud: Hud
var autosave: Autosave
var card_overlay: CardPickOverlay
var save_store: SaveStore
var audio_director: AudioDirector
var settings_store: SettingsStore
var debug_fresh_start := false
var warmup: Warmup
var boot_fade: BootFade
var pause_reasons := {}
var settings_layer: SettingsLayer
var guide: Guide

## S5 D-218: the tree is paused while any reason is held. paused is written only when the set changes between empty
## and not empty, so a test that sets get_tree().paused directly is never overwritten.
func add_pause_reason(r: StringName) -> void:
	var was_empty := pause_reasons.is_empty()
	pause_reasons[r] = true
	if was_empty:
		get_tree().paused = true

func remove_pause_reason(r: StringName) -> void:
	if not pause_reasons.erase(r):
		return
	if pause_reasons.is_empty():
		get_tree().paused = false

func _exit_tree() -> void:
	if not pause_reasons.is_empty():
		pause_reasons.clear()
		get_tree().paused = false

## S5 D-217: wipe the save, start a new game, close the settings panel. Settings (mute, guide) are kept.
func fresh_start() -> void:
	if save_store != null:
		save_store.wipe()
	if settings_layer != null and settings_layer.panel_open():
		settings_layer.close()
	remove_pause_reason(&"settings")
	phase_controller.start_new_game()

func _on_settings_opened() -> void:
	settings_layer.set_muted_display(audio_director.muted)  # the stored mute is applied after _ready (setup)
	add_pause_reason(&"settings")

func _on_focus_changed(p: bool) -> void:
	if p:
		add_pause_reason(&"focus")
	else:
		remove_pause_reason(&"focus")

func _ready() -> void:
	focus_pause = FocusPause.new()
	focus_pause.name = "FocusPause"
	add_child(focus_pause)
	audio_director = AudioDirector.new()
	add_child(audio_director)
	focus_pause.changed.connect(audio_director.set_suspended)
	focus_pause.changed.connect(_on_focus_changed)
	focus_pause.tree_exiting.connect(remove_pause_reason.bind(&"focus"))
	autosave = Autosave.new()
	autosave.name = "Autosave"
	add_child(autosave)
	hero = Hero.new()
	add_child(hero)
	hero.setup(world)
	hero.teleport(MapLayout.HOME)
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup(hero)
	hud = Hud.new()
	hud.name = "Hud"
	hud.setup(self)
	add_child(hud)
	var input_layer := CanvasLayer.new()
	input_layer.name = "InputLayer"
	input_layer.layer = 5
	add_child(input_layer)
	joystick = Joystick.new()
	input_layer.add_child(joystick)
	joystick.setup(hero.input)
	# S2 (D-162): after InputLayer so its _input runs before the joystick's.
	card_overlay = CardPickOverlay.new()
	add_child(card_overlay)
	# S5 (D-216, D-217): after the card overlay, so its _input runs first.
	settings_layer = SettingsLayer.new()
	add_child(settings_layer)
	settings_layer.opened.connect(_on_settings_opened)
	settings_layer.closed.connect(remove_pause_reason.bind(&"settings"))
	settings_layer.mute_toggled.connect(audio_director.set_muted)
	settings_layer.new_game_requested.connect(fresh_start)
	settings_layer.set_muted_display(audio_director.muted)
	hud.reserved_rect = settings_layer.gear_rect
	if OS.is_debug_build() and ResourceLoader.exists("res://ui/debug/debug_overlay.gd"):
		# D-099: load(), never preload, so release/profile can exclude ui/debug/*. Added after InputLayer
		# so its _input (the fade button) runs before the joystick's.
		var overlay: CanvasLayer = load("res://ui/debug/debug_overlay.gd").new()
		add_child(overlay)
		overlay.setup(self)
	if OS.has_feature("profile_overlay"):
		add_child(PerfOverlay.new())
	add_child(BuildLabel.new())
	if auto_start:
		save_store = SaveStore.for_platform()
		autosave.store = save_store
		settings_store = SettingsStore.for_platform()
		settings_store.load_settings()
		_maybe_build_guide()
		if TierEffects.top_tier(Balance.data.tiers) >= 3 and not settings_store.branch_hint_done:
			var pad_hint := BranchPadHint.new()
			pad_hint.name = "BranchPadHint"
			add_child(pad_hint)
			pad_hint.setup(world, settings_store)
		audio_director.setup(settings_store)
		# S5 (D-215): the boot fade always; the warm-up unless ?warmup=0 (so A and B differ only in the warm-up).
		boot_fade = BootFade.new()
		add_child(boot_fade)
		if UrlFlags.get_flag("warmup") != "0":
			warmup = Warmup.new()
			warmup.name = "Warmup"
			add_child(warmup)
		_boot.call_deferred()
	else:
		audio_director.setup(null)

## S5 D-213: the onboarding pointer, only for a device that has not finished it (or forced by ?guide=1 on debug).
func _maybe_build_guide() -> void:
	if guide != null or settings_store == null:
		return
	var flag := UrlFlags.get_flag("guide")
	if flag == "1" or (flag != "0" and not settings_store.guide_done):
		guide = Guide.new()
		add_child(guide)
		guide.setup(self)
		guide.completed.connect(func(): guide = null)

## S3 (D-176, D-177): resume the saved run, or start fresh. S5 (D-215): when a Warmup exists, draw every first-use
## visual under the boot fade first; without one (tests) this stays synchronous.
func _boot() -> void:
	var r := {"ok": false, "state": {}}
	if not debug_fresh_start:
		r = save_store.read()  # read once, before the warm-up, which needs the resume phase for its music track
	if warmup != null:
		await warmup.run(self, String(r.state.resume_phase) if r.ok else "")
		warmup.queue_free()
		warmup = null
	else:
		audio_director.register_streams()
	if debug_fresh_start:
		save_store.wipe()
		phase_controller.start_new_game()
	elif r.ok:
		phase_controller.resume_from(r.state)
	else:
		phase_controller.start_new_game()
	if boot_fade != null:
		boot_fade.fade_out()
