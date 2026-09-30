class_name PerfOverlay
extends CanvasLayer
## fps / frame-time overlay for the `profile` export only (D-084, D-099). Rolling 60 s window.

const WINDOW_S := 60.0
var _frames: Array = []
var _sum := 0.0
var _label: Label
var _print_t := 0.0

func _ready() -> void:
	layer = 20
	_label = Label.new()
	_label.position = Vector2(12, 1180)
	_label.add_theme_font_size_override("font_size", 26)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func record(frame_seconds: float) -> void:
	_frames.append(frame_seconds)
	_sum += frame_seconds
	while _sum > WINDOW_S and _frames.size() > 1:
		_sum -= _frames.pop_front()

func avg_fps() -> float:
	return 0.0 if _sum <= 0.0 else _frames.size() / _sum

func worst_ms() -> float:
	var w := 0.0
	for f in _frames:
		w = maxf(w, f)
	return w * 1000.0

func _process(delta: float) -> void:
	record(delta)
	_label.text = "fps %.0f  avg %.1f  worst %.0f ms" % [Engine.get_frames_per_second(), avg_fps(), worst_ms()]
	_print_t += delta
	if _print_t >= WINDOW_S:
		_print_t = 0.0
		print("PERF window=60s avg_fps=%.1f worst_ms=%.1f" % [avg_fps(), worst_ms()])
