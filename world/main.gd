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

func _ready() -> void:
	focus_pause = FocusPause.new()
	focus_pause.name = "FocusPause"
	add_child(focus_pause)
	audio_director = AudioDirector.new()
	add_child(audio_director)
	focus_pause.changed.connect(audio_director.set_suspended)
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
