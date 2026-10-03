class_name BootFade
extends CanvasLayer
## S5 (D-215): a night-sky cover over the first frames (layer 90) while the warm-up draws every first-use visual.
## fade_out() is called once the saved run is resumed; the cover then stays opaque until `boot_fade_stable_frames`
## consecutive frames each took under `boot_fade_stable_ms` (the load freeze after the phase starts happens under it), or
## `boot_fade_max_s` seconds after fade_out(); then it dissolves over `boot_fade_out_s`. Frame times are wall-clock
## (Time.get_ticks_usec deltas): they measure the real cost of a frame. Safety: it lifts by itself `boot_fade_max_s * 3`
## seconds after it exists even if fade_out() never comes. Visual only.

var _rect: ColorRect
var _requested := false
var _lifting := false
var _stable := 0
var _frames := 0
var _elapsed := 0.0
var _since_ready := 0.0
var _last_usec := 0

func _init() -> void:
	name = "BootFade"
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS  # a paused tree (Main's pause reasons, D-218) must not hold the cover up

func _ready() -> void:
	_rect = ColorRect.new()
	_rect.color = Palette.color(&"night_sky")
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

## Starts waiting for stable frames (harmless before _ready: the wait is checked from _process).
func fade_out() -> void:
	_requested = true

func is_lifting() -> bool:
	return _lifting

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var raw := 0.0 if _last_usec == 0 else (now - _last_usec) / 1000000.0
	_last_usec = now
	_tick(raw)

## One frame of `raw` seconds. Split out so tests can inject frame times.
func _tick(raw: float) -> void:
	if _lifting or raw <= 0.0:
		return
	_since_ready += raw
	if _since_ready >= Balance.ui.boot_fade_max_s * 3.0:
		_lift()  # safety: fade_out() never came (a failed boot)
		return
	if not _requested:
		return
	_frames += 1
	_elapsed += raw
	if raw * 1000.0 < Balance.ui.boot_fade_stable_ms:
		_stable += 1
	else:
		_stable = 0
	if _stable >= Balance.ui.boot_fade_stable_frames or _elapsed >= Balance.ui.boot_fade_max_s:
		_lift()

func _lift() -> void:
	_lifting = true
	if OS.is_debug_build() or OS.has_feature("profile_overlay"):
		print("BOOTFADE done=%.2f frames=%d" % [_elapsed, _frames])
	if _rect == null:
		queue_free()
		return
	var t := create_tween()
	t.tween_property(_rect, "color:a", 0.0, Balance.ui.boot_fade_out_s)
	t.tween_callback(queue_free)
