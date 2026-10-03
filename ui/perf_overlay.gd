class_name PerfOverlay
extends CanvasLayer
## fps / frame-time overlay for the `profile` export only (D-084, D-099).
## S4 Task 5 protocol: the window resets on every EventBus.phase_changed and skips the first 2 s (loading and
## resume hitches), so the first wave spawn at `first_wave_delay` (5 s) is inside the reading, which is the honest
## case. The frame that straddles the 2 s edge is not counted. Every field (avg fps, worst frame, proc, phys, draw
## calls, slow %) is accumulated over the same frames; when those frames add up to 60 s the overlay prints and
## freezes one `PERF phase=... window=60s ...` line. The frozen line stays on screen until the next freeze, so a
## screenshot taken after the phase ended still carries it.
## Frame time is measured from Time.get_ticks_usec() deltas; the engine's `delta` is tracked beside it
## (delta_worst_ms) because it is clamped.

const WINDOW_S := 60.0
const WARMUP_S := 2.0
const SLOW_S := 0.020

var _label: Label
var _frozen_label: Label
var _since_reset := 0.0
var _last_usec := 0
var _phase := -1
var _day := 0
var _frozen := false
var _n := 0
var _raw_sum := 0.0
var _raw_worst := 0.0
var _proc_sum := 0.0
var _phys_sum := 0.0
var _dc_sum := 0.0
var _slow := 0
var _delta_worst := 0.0
## The 3 worst frames of the window: {"ms", "at" (s into the window), "wave" (last started wave index, -1 none), "since" (s since that wave_started, -1 none)}.
var _top: Array[Dictionary] = []
## The 3 worst frames before the window opens: {"ms", "at" (s since the phase change)}.
var _pre: Array[Dictionary] = []
var _warm := WARMUP_S
var _wave := -1
var _wave_at := -1.0

func _ready() -> void:
	layer = 20
	_label = Label.new()
	_label.theme_type_variation = &"HudLabel"
	_label.position = Vector2(12, 1130)
	_label.add_theme_font_size_override("font_size", 22)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_frozen_label = Label.new()
	_frozen_label.theme_type_variation = &"HudLabel"
	_frozen_label.position = Vector2(12, 1190)
	_frozen_label.add_theme_font_size_override("font_size", 13)
	_frozen_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frozen_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_frozen_label.custom_minimum_size = Vector2(696, 0)
	add_child(_frozen_label)
	var pw := UrlFlags.get_flag("perfwarm")
	if pw.is_valid_float() and float(pw) >= 0.0:
		_warm = float(pw)  # ?perfwarm=<s>: warm-up length (default WARMUP_S), to tell the overlay's own boundary from a game event
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.wave_started.connect(_on_wave_started)

func _on_wave_started(w: int, _main: StringName, _side: StringName) -> void:
	_wave = w
	_wave_at = _since_reset

func _on_phase_changed(p: int, d: int) -> void:
	_phase = p
	_day = d
	_reset_window()

func _reset_window() -> void:
	_since_reset = 0.0
	_last_usec = 0
	_frozen = false
	_n = 0
	_raw_sum = 0.0
	_raw_worst = 0.0
	_proc_sum = 0.0
	_phys_sum = 0.0
	_dc_sum = 0.0
	_slow = 0
	_delta_worst = 0.0
	_top.clear()
	_pre.clear()
	_wave = -1
	_wave_at = -1.0

## Counts one frame (seconds) into the window.
func record(frame_seconds: float) -> void:
	_n += 1
	_raw_sum += frame_seconds
	_raw_worst = maxf(_raw_worst, frame_seconds * 1000.0)

func avg_fps() -> float:
	return 0.0 if _raw_sum <= 0.0 else _n / _raw_sum

func worst_ms() -> float:
	return _raw_worst

func frozen_text() -> String:
	return _frozen_label.text

func _phase_name() -> String:
	return "NONE" if _phase < 0 else Phase.name_of(_phase)

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var raw := 0.0 if _last_usec == 0 else (now - _last_usec) / 1000000.0
	_last_usec = now
	_tick(raw, delta)

## One frame: raw = measured seconds, delta = the engine's (clamped) delta. Split out so tests can inject time.
func _tick(raw: float, delta: float) -> void:
	var state := "frozen" if _frozen else ("warm-up" if _since_reset < _warm else "")
	var n := maxi(_n, 1)
	_label.text = "fps %.0f  avg %.1f  worst %.0f ms  win %.0fs %s\nproc %.1f ms  phys %.1f ms  dc %.0f  slow %.1f%%" % [
		Engine.get_frames_per_second(), avg_fps(), worst_ms(), _raw_sum, state,
		_proc_sum / n, _phys_sum / n, _dc_sum / n, 100.0 * _slow / n]
	if raw <= 0.0 or _frozen:
		return
	var before := _since_reset
	_since_reset += raw
	if before < _warm:
		_track_pre(raw)
		_prime_reads()
		return
	record(raw)
	_proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_dc_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if raw > SLOW_S:
		_slow += 1
	_delta_worst = maxf(_delta_worst, delta * 1000.0)
	_track_top(raw)
	if _raw_sum >= WINDOW_S:
		_frozen = true
		var line := "PERF phase=%s day=%d window=60s avg_fps=%.1f worst_ms=%.1f proc_ms=%.2f phys_ms=%.2f dc=%.0f slow_pct=%.1f delta_worst_ms=%.1f" % [
			_phase_name(), _day, avg_fps(), worst_ms(), _proc_sum / _n, _phys_sum / _n, _dc_sum / _n,
			100.0 * _slow / _n, _delta_worst]
		line += " top3=" + top3_text() + " pre3=" + pre3_text()
		_frozen_label.text = line
		print(line)

func _track_top(raw: float) -> void:
	var ms := raw * 1000.0
	if _top.size() == 3 and ms <= float(_top[2].ms):
		return
	_top.append({"ms": ms, "at": _raw_sum, "wave": _wave, "since": -1.0 if _wave_at < 0.0 else _since_reset - _wave_at})
	_top.sort_custom(func(a, b): return a.ms > b.ms)
	if _top.size() > 3:
		_top.resize(3)

## `124@12.3s(w0,+0.4) ...`: ms, seconds into the window, last started wave, seconds since its wave_started (+-1 none).
func top3_text() -> String:
	var parts: PackedStringArray = []
	for t in _top:
		parts.append("%.0f@%.1fs(w%d,%s)" % [t.ms, t.at, t.wave, "-1" if float(t.since) < 0.0 else "+%.1f" % t.since])
	return " ".join(parts)

func _track_pre(raw: float) -> void:
	var ms := raw * 1000.0
	if _pre.size() == 3 and ms <= float(_pre[2].ms):
		return
	_pre.append({"ms": ms, "at": _since_reset})
	_pre.sort_custom(func(a, b): return a.ms > b.ms)
	if _pre.size() > 3:
		_pre.resize(3)

## `98@2.1s ...`: ms and seconds since the phase change of the 3 worst frames inside the warm-up.
func pre3_text() -> String:
	var parts: PackedStringArray = []
	for t in _pre:
		parts.append("%.0f@%.1fs" % [t.ms, t.at])
	return " ".join(parts)

## S5 Task 7: the warm-up does the same monitor reads as the window and throws the values away, so crossing the window's
## boundary changes only bookkeeping (the label formatting already runs every frame).
func _prime_reads() -> float:
	return Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) \
		+ Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
