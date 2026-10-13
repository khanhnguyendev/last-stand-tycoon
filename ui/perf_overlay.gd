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
## Debug-only exception to "no system reaches into another system's nodes" (CLAUDE.md): this overlay exists in the `profile`
## export only and reads the HUD (`hud`, `boot_fade`) and `OccluderFade` nodes of its parent to mark frame-log events (and,
## with `perfnofade=1`, disables the fade for a measurement). It never writes game state and ships in no release build.

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
## E6 A2 (`?perflog=<s>`): every frame of the first <s> seconds after each phase change, printed once to the console as `PERFLOG ...`
## and summarised on screen (frames over LOG_SHOW_MS, the first use of each event). 0 = off: the code below stays inert.
## `?perfclose=<s>`: s seconds into a DAY the overlay emits `closeup_requested`, the signal the close-up sign sends, so a perf run can
## measure a night the game entered by playing (not one resumed from a save). 0 = off.
const LOG_SHOW_MS := 30.0
var _log_s := 0.0
var _close_s := 0.0
var _closed := false
## The night in the window began by the overlay's own close-up (`?perfclose=`): a night ENTERED BY PLAY (kept through the phase change; cleared when a day starts).
var _play_entered := false
var _log_t: Array[float] = []
var _log_ms: Array[float] = []
## For a frame of LOG_SHOW_MS or more: the previous frame's script time, physics time, draw calls, and the node count and video memory change.
var _log_extra: Dictionary = {}
var _prev_nodes := 0
var _prev_vmem := 0.0
var _log_done := false
var _stable_run := 0
var _stable_at := -1.0
var _phase_msec := 0
var _first: Array[String] = []
var _first_seen := {}
var _log_label: Label
## E6 A2 (D-292): the overlay draws every glyph its two labels will ever show once, in its first frame (under the boot fade). Without it the first
## numbers the label shows 0.1 s into the window cost 95 to 133 ms (the first rasterisation of the digits: a measurement artifact, not a game frame; every
## reading taken before this change carries it). `?perfglyph=0` restores the old behaviour to reproduce such a reading.
## `?perfnofade=1` (diagnosis only): switches the diner's occluder fade off, to test whether its first activation is a frame of the night.
var _glyph_prime := true
var _nofade := false
## E6 phase A (D-300, diagnosis only, a2.md 4g): `?perfcut=<what>` removes ONE thing from the picture for a reading, to see what the frame cost is made of. Every cut is visual
## (nodes hidden, the simulation runs on): diner (the whole diner art), labels (every Label3D), hud (the Hud layer; this overlay stays), ground (terrain, kerb and yard stones),
## enemies (the enemy pool), half (the window at half size: the canvas buffer has a quarter of the pixels). Applied twice a second (nodes come and go). It writes no game state.
const CUTS: Array[StringName] = [&"diner", &"labels", &"hud", &"ground", &"enemies", &"half"]
var _cut: StringName = &""
var _cut_wait := 0.0
var _half_done := false
const GLYPHS := "0123456789 .,:=@()+-%_/ abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ"
var _seen_fade := true
var _fades: Array[Node] = []
## Every fade START of the log's seconds ({"t", "dc": [draw calls of its first 3 frames]}), and the previous frame's state (E6 A2: does the frame recur?).
var _fade_starts: Array[Dictionary] = []
var _fade_was := false
var _seen_banner := false
var _seen_arrow := false

## A positive number of seconds from a query flag value, else 0 (flag absent, not a number, zero or negative).
static func positive_seconds(flag: String) -> float:
	return float(flag) if flag.is_valid_float() and float(flag) > 0.0 else 0.0

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
	_glyph_prime = UrlFlags.get_flag("perfglyph") != "0"
	_nofade = UrlFlags.get_flag("perfnofade") == "1"
	_cut = StringName(UrlFlags.get_flag("perfcut")) if StringName(UrlFlags.get_flag("perfcut")) in CUTS else &""
	_log_s = positive_seconds(UrlFlags.get_flag("perflog"))
	_close_s = positive_seconds(UrlFlags.get_flag("perfclose"))
	if _log_s > 0.0:
		_log_label = Label.new()
		_log_label.theme_type_variation = &"HudLabel"
		_log_label.position = Vector2(12, 930)
		_log_label.add_theme_font_size_override("font_size", 13)
		_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_log_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_log_label.custom_minimum_size = Vector2(696, 0)
		add_child(_log_label)
		EventBus.wave_started.connect(func(w: int, _m: StringName, _s: StringName) -> void: _mark("wave%d" % w))
		EventBus.enemy_killed.connect(func(_i: int, _l: StringName, _p: Vector3, k: StringName) -> void: _mark("kill_" + String(k)))
		EventBus.fx_requested.connect(func(k: StringName, _p: Vector3) -> void: _mark("fx_" + String(k)))
		EventBus.sfx_requested.connect(func(id: StringName) -> void: _mark("sfx_" + String(id)))
		EventBus.wave_spawned_out.connect(func(w: int) -> void: _mark("spawned_out%d" % w))
		EventBus.wave_cleared.connect(func(w: int) -> void: _mark("cleared%d" % w))
		EventBus.guard_knocked_out.connect(func(_g: StringName) -> void: _mark("guard_ko"))
		EventBus.banner_requested.connect(func(_t: String) -> void: _mark("banner"))
		EventBus.diner_damaged.connect(func(_a: float, _h: float) -> void: _mark("diner_hit"))
		EventBus.guard_damaged.connect(func(_g: StringName, _h: float) -> void: _mark("guard_hit"))

func _on_wave_started(w: int, _main: StringName, _side: StringName) -> void:
	_wave = w
	_wave_at = _since_reset

func _on_phase_changed(p: int, d: int) -> void:
	_phase = p
	_day = d
	if p == Phase.DAY:
		_play_entered = false
	_phase_msec = Time.get_ticks_msec()
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
	_closed = false
	_log_t.clear()
	_log_ms.clear()
	_log_extra.clear()
	_log_done = false
	_stable_run = 0
	_stable_at = -1.0
	_first.clear()
	_first_seen.clear()
	_seen_banner = false
	_seen_arrow = false
	_fade_starts.clear()
	_fade_was = false

## First use of each event name inside the log's seconds: `name@t`.
func _mark(name: String) -> void:
	if _log_done or _first_seen.has(name):
		return
	_first_seen[name] = true
	_first.append("%s@%.2f" % [name, _since_reset])

## Marks the first frame the HUD banner panel and the lane arrow change visibility (log mode only; nothing happens when the parent has no `hud`).
func _poll_visuals() -> void:
	var h = get_parent().get("hud") if get_parent() != null else null
	if h == null:
		return
	var banner_on: bool = h.banner_panel.visible
	if banner_on != _seen_banner:
		_seen_banner = banner_on
		_mark("banner_on" if banner_on else "banner_off")
	var fade = get_parent().get("boot_fade")
	var fade_here: bool = fade != null and is_instance_valid(fade)
	if _seen_fade and not fade_here:
		_seen_fade = false
		_mark("bootfade_gone")
	elif fade_here and fade.is_lifting():
		_mark("bootfade_lift")
	if _fades.is_empty():
		_fades = get_parent().find_children("*", "OccluderFade", true, false)
	for f in _fades:
		if is_instance_valid(f) and f.is_faded():
			_mark("fade_" + String(f.get_parent().get_parent().name))
	var any_faded := false
	for f in _fades:
		if is_instance_valid(f) and f.is_faded():
			any_faded = true
	if any_faded and not _fade_was:
		_fade_starts.append({"t": _since_reset, "dc": []})
	_fade_was = any_faded
	var arrow_on: bool = h.arrows.main.visible
	if arrow_on != _seen_arrow:
		_seen_arrow = arrow_on
		_mark("arrow_on" if arrow_on else "arrow_off")

func _log_frame(raw: float) -> void:
	var ms := raw * 1000.0
	_log_t.append(_since_reset)
	_log_ms.append(ms)
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var vmem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	if ms >= LOG_SHOW_MS:
		_log_extra[_log_t.size() - 1] = "[p%.0f s%.1f dc%.0f n%+d v%+.1f]" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), nodes - _prev_nodes, vmem - _prev_vmem]
	_prev_nodes = nodes
	_prev_vmem = vmem
	var dcn := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	for st in _fade_starts:
		if (st.dc as Array).size() < 3:
			(st.dc as Array).append(int(dcn))
	if ms < Balance.ui.boot_fade_stable_ms:
		_stable_run += 1
		if _stable_run >= Balance.ui.boot_fade_stable_frames and _stable_at < 0.0:
			_stable_at = _since_reset  # when the boot fade would lift, i.e. the first playable frame
	else:
		_stable_run = 0
	if _since_reset >= _log_s:
		_flush_log()

## Prints the whole log once and shows the slow frames and first events on screen.
func _flush_log() -> void:
	_log_done = true
	var all: PackedStringArray = []
	var slow: PackedStringArray = []
	for i in _log_t.size():
		all.append("%.2f:%.0f" % [_log_t[i], _log_ms[i]])
		if _log_ms[i] >= LOG_SHOW_MS:
			slow.append("%.1f:%.0f%s" % [_log_t[i], _log_ms[i], _log_extra.get(i, "")])
	var fades: PackedStringArray = []
	for st in _fade_starts:
		var worst := 0.0
		for i in _log_t.size():
			if _log_t[i] > float(st.t) and _log_t[i] <= float(st.t) + 0.3:
				worst = maxf(worst, _log_ms[i])
		fades.append("%.1f:%.0f%s" % [st.t, worst, str(st.dc).replace(" ", "")])
	var head := "PERFLOG phase=%s day=%d phase_msec=%d stable_at=%.2f n=%d" % [_phase_name(), _day, _phase_msec, _stable_at, _log_t.size()]
	print(head + " first=" + ",".join(_first) + " frames=" + ",".join(all))
	_log_label.text = "%s\n>=%.0fms (t:ms): %s\nfade starts (t:worst ms within 0.3 s, dc of 3 frames): %s\nfirst: %s" % [head, LOG_SHOW_MS, " ".join(slow), " ".join(fades), " ".join(_first)]

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

## Hides what `_cut` names (see CUTS). The overlay's parent is Main; anything missing is skipped.
func _apply_cut() -> void:
	var main := get_parent()
	var world: Node = main.get("world") if main != null else null
	match _cut:
		&"diner":
			if world != null and world.get("diner_body") != null:
				(world.diner_body as Node3D).get_node("Visual").visible = false
		&"labels":
			for l in main.find_children("*", "Label3D", true, false):
				(l as Label3D).visible = false
		&"hud":
			var hud := main.get_node_or_null("Hud")
			if hud != null:
				hud.visible = false
		&"ground":
			if world != null:
				for n in [world.get("ground"), world.get("edge_stones"), world.get("yard_stones")]:
					if n != null:
						(n as Node3D).visible = false
		&"enemies":
			var pool: Node = world.get("enemy_pool") if world != null else null
			if pool != null:
				for e in pool.get_children():  # the pool shows an enemy when it spawns: hidden again every frame (see _tick)
					(e as Node3D).visible = false
		&"half":
			if not _half_done:
				_half_done = true
				var w := get_window()
				w.size = w.size / 2

func _phase_name() -> String:
	return "NONE" if _phase < 0 else Phase.name_of(_phase)

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var raw := 0.0 if _last_usec == 0 else (now - _last_usec) / 1000000.0
	_last_usec = now
	_tick(raw, delta)

## One frame: raw = measured seconds, delta = the engine's (clamped) delta. Split out so tests can inject time.
func _tick(raw: float, delta: float) -> void:
	if _cut != &"":
		_cut_wait -= raw
		if _cut_wait <= 0.0 or _cut == &"enemies":
			_cut_wait = 0.5
			_apply_cut()
	if _nofade:
		var fades := get_parent().find_children("*", "OccluderFade", true, false)
		for f in fades:
			f.process_mode = Node.PROCESS_MODE_DISABLED
		_nofade = fades.is_empty()  # keep looking until the diner exists
	var state := "frozen" if _frozen else ("warm-up" if _since_reset < _warm else "")
	var n := maxi(_n, 1)
	if _glyph_prime:
		_glyph_prime = false
		_label.text = GLYPHS  # drawn once; the next tick writes the real text
		_frozen_label.text = GLYPHS
	else:
		if _frozen_label.text == GLYPHS:
			_frozen_label.text = ""  # the prime text must not stay on screen (a second font size) through the measured window
		_label.text = "fps %.0f  avg %.1f  worst %.0f ms  win %.0fs %s\nproc %.1f ms  phys %.1f ms  dc %.0f  slow %.1f%%" % [
			Engine.get_frames_per_second(), avg_fps(), worst_ms(), _raw_sum, state,
			_proc_sum / n, _phys_sum / n, _dc_sum / n, 100.0 * _slow / n]
	if raw <= 0.0 or _frozen:
		return
	var before := _since_reset
	_since_reset += raw
	if _close_s > 0.0 and not _closed and _phase == Phase.DAY and _since_reset >= _close_s:
		_closed = true
		_play_entered = true
		EventBus.closeup_requested.emit()  # the phase changes here and the window resets: this frame is the old phase's last
		return
	if _log_s > 0.0 and not _log_done:
		_poll_visuals()
		_log_frame(raw)
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
		line += " top3=" + top3_text() + " pre3=" + pre3_text() + " " + budget_text(_dc_sum / _n, budget_kind())
		_frozen_label.text = line
		print(line)

## Draw-call budgets by reading (E6 phase A, D-300): the measured Simulator count plus 10 for each framing (a2.md 4f). A warning only: WARN never fails a run.
## The three framings differ by what the camera sees, so they have their own budgets: a night entered by play frames the whole diner from HOME (54 + 10), a night
## resumed from a save frames the hero's saved place (40 + 10), the day at HOME shows the pads (107 + 10, `tier3_branch_day`).
const BUDGET_NIGHT_PLAY := 64
const BUDGET_NIGHT_RESUMED := 50
const BUDGET_DAY_HOME := 117
enum BudgetKind { NIGHT_RESUMED, NIGHT_PLAY, DAY_HOME }

static func budget_for(kind: int) -> int:
	match kind:
		BudgetKind.NIGHT_PLAY:
			return BUDGET_NIGHT_PLAY
		BudgetKind.DAY_HOME:
			return BUDGET_DAY_HOME
	return BUDGET_NIGHT_RESUMED

## The reading the window in progress is: a day, a night entered by play (the overlay sent the close-up), or a night resumed from a save.
func budget_kind() -> int:
	if _phase == Phase.DAY:
		return BudgetKind.DAY_HOME
	return BudgetKind.NIGHT_PLAY if _play_entered else BudgetKind.NIGHT_RESUMED

## `DRAW_CALL_BUDGET: OK 40 (budget 50)` or `WARN 107 (budget 50)`: the frozen line's last words, with the budget of the reading's own kind.
static func budget_text(dc: float, kind := BudgetKind.NIGHT_RESUMED) -> String:
	var n := int(round(dc))
	var b := budget_for(kind)
	return "DRAW_CALL_BUDGET: %s %d (budget %d)" % ["OK" if n <= b else "WARN", n, b]

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
