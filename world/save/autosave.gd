class_name Autosave
extends Node
## Writes the save at the S3 spec 5.2 triggers. Listens to EventBus only; tracks the phase itself. No store = no-op
## (Main.create() in tests), so suites never write a real save.

var store: SaveStore = null
var writes := 0
var phase := Phase.NIGHT
var failing := false
var _dirty := false
var _since_dirty := 0.0
var _js_hide: JavaScriptObject
var _js_vis: JavaScriptObject

func _ready() -> void:
	EventBus.snapshot_taken.connect(_on_snapshot)
	EventBus.card_offered.connect(_on_offer)
	EventBus.phase_changed.connect(_on_phase)
	EventBus.night_failed.connect(_on_night_failed)
	EventBus.build_completed.connect(_on_build_completed)
	EventBus.branch_chosen.connect(_on_branch_chosen)  # a chosen branch is a build too (E5 tier 3)
	EventBus.station_upgraded.connect(_on_build_completed)  # "after each build" covers station levels (E1)
	EventBus.station_changed.connect(_mark_dirty.unbind(3))
	EventBus.stocks_changed.connect(_mark_dirty)
	EventBus.gold_changed.connect(_mark_dirty.unbind(2))
	EventBus.building_changed.connect(_mark_dirty.unbind(3))
	EventBus.tier_changed.connect(_mark_dirty.unbind(3))
	EventBus.tier_paid_up.connect(_on_tier_paid_up)
	EventBus.tier_reached.connect(_on_tier_reached)
	if OS.has_feature("web"):
		var doc := JavaScriptBridge.get_interface("document")
		var win := JavaScriptBridge.get_interface("window")
		_js_hide = JavaScriptBridge.create_callback(_on_page_hidden)
		_js_vis = JavaScriptBridge.create_callback(_on_visibility)
		doc.addEventListener("visibilitychange", _js_vis)
		win.addEventListener("pagehide", _js_hide)

func _exit_tree() -> void:
	if OS.has_feature("web") and _js_hide != null:
		JavaScriptBridge.get_interface("document").removeEventListener("visibilitychange", _js_vis)
		JavaScriptBridge.get_interface("window").removeEventListener("pagehide", _js_hide)
		_js_hide = null
		_js_vis = null

func flush() -> void:
	if _dirty and phase == Phase.DAY and not failing:
		_write_live("DAY")

func _on_page_hidden(_args: Array) -> void:
	flush()

## visibilitychange also fires when the page becomes visible again; only a hide flushes.
func _on_visibility(_args: Array) -> void:
	if bool(JavaScriptBridge.eval("document.hidden", true)):
		flush()

## snapshot_taken always writes: new game, close-up, night-1 retry (spec 5.2 state machine).
func _on_snapshot(snap: Dictionary) -> void:
	_write_state(snap.duplicate(true))

func _on_offer(_offer: Array) -> void:
	if phase == Phase.DAWN and not failing:
		_write_live("CARD_PICK")

func _on_phase(p: int, _day: int) -> void:
	phase = p
	failing = false
	if p == Phase.DAY:
		_write_live("DAY")

func _on_night_failed(_day: int) -> void:
	failing = true

func _on_build_completed(_spot: StringName, _level: int) -> void:
	if phase == Phase.DAY and not failing:
		_write_live("DAY")

func _on_branch_chosen(_spot: StringName, _branch: StringName) -> void:
	if phase == Phase.DAY and not failing:
		_write_live("DAY")

func _on_tier_paid_up(_next_tier: int) -> void:
	if phase == Phase.DAY and not failing:
		_write_live("DAY")

## The tier-up dawn: the offer was stashed before complete_tier_up, so a tab closed during the reveal resumes at the card pick.
func _on_tier_reached(_tier: int) -> void:
	if phase == Phase.DAWN and not failing:
		_write_live("CARD_PICK" if not GameState.card_offer.is_empty() else "DAY")

func _mark_dirty() -> void:
	if store == null:
		return
	if phase == Phase.DAY and not failing and not _dirty:
		_dirty = true
		_since_dirty = 0.0

func _physics_process(delta: float) -> void:
	if not _dirty:
		return
	_since_dirty += delta
	if _since_dirty >= Balance.ui.autosave_interval_s - 1e-6:
		flush()

func _write_live(resume_phase: String) -> void:
	if store == null:
		return
	var d := GameState.to_dict()
	d.resume_phase = resume_phase
	_write_state(d)

func _write_state(d: Dictionary) -> void:
	_dirty = false
	if store == null:
		return
	if store.write(SaveCodec.encode(d, _build_id(), int(Time.get_unix_time_from_system()))):
		writes += 1

static func _build_id() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.LST_BUILD || ''", true))
	return "dev"
