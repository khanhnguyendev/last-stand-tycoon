class_name AudioDirector
extends Node
## SFX map, music by phase, web unlock, mute bus, suspend (S5 spec 4.3, D-212, D-214, D-218). Listens to EventBus only;
## never writes game state. Before unlock it drops SFX and starts no music.

const VOICES := 10
const RING := 16
const PITCH_TABLE: Array[float] = [-1.0, 0.5, -0.5, 1.0, 0.0]
const CROSSFADE_S := 1.0
const SILENT_DB := -60.0
const PROBE_S := 1.0

var unlocked := false
var muted := false
var suspended := false
var disabled := false
var music_id: StringName = &""
var last_played: Array[StringName] = []
var last_pitch := 1.0
var _settings: SettingsStore
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: Array[AudioStreamPlayer] = []
var _music_cur := 0
var _music_tween: Tween
var _streams := {}
var _last_ms := {}
var _seq := 0
var _phase := -1
var _plan_size := 0
var _probe_left := PROBE_S
var _release_seen := false

func _ready() -> void:
	name = "AudioDirector"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Music"
		m.volume_db = SILENT_DB
		if AudioManifest.MUSIC_MODE == &"stream":
			m.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(m)
		_music.append(m)
	EventBus.sfx_requested.connect(play)
	EventBus.enemy_killed.connect(func(_i, _l, _p): play(&"poof"))
	EventBus.steak_picked.connect(func(_c): play(&"pickup"))
	EventBus.steak_sold.connect(func(_c, _g): play(&"coin"))
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.build_completed.connect(func(_id, _lv): play(&"build_done"))
	EventBus.card_offered.connect(func(_o): play(&"card_open"))
	EventBus.card_picked.connect(func(_id, _lv): play(&"card_pick"))
	EventBus.wave_incoming.connect(func(_w, _m, _s): play(&"horn"))
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.diner_damaged.connect(func(_a, _h): play(&"diner_hit"))
	EventBus.night_failed.connect(func(_d): play(&"fail"))
	EventBus.guard_knocked_out.connect(func(_id): play(&"guard_down"))
	EventBus.guard_revived.connect(func(_id): play(&"guard_up"))
	EventBus.phase_changed.connect(_on_phase_changed)

func setup(settings: SettingsStore, auto_unlock := true) -> void:
	_settings = settings
	disabled = UrlFlags.get_flag("audio") == "0"
	if settings != null:
		if UrlFlags.get_flag("mute") == "1" and OS.is_debug_build():
			settings.muted = true
			settings.save_settings()
		_apply_mute(settings.muted)
	if auto_unlock and not OS.has_feature("web"):
		set_unlocked()

## Registers every SFX stream as a sample (web only). Music is registered here only in samples mode; lazy mode registers
## each track on first use in _set_music (D-212).
## Main calls it behind the boot fade.
func register_streams() -> void:
	if disabled:
		return
	for id in AudioManifest.SFX:
		var s := _stream(AudioManifest.SFX[id].path)
		if OS.has_feature("web"):
			AudioServer.register_stream_as_sample(s)
	for id in AudioManifest.MUSIC:
		var s := _stream(AudioManifest.MUSIC[id].path)
		if OS.has_feature("web") and AudioManifest.MUSIC_MODE == &"samples":
			AudioServer.register_stream_as_sample(s)

## Loaded once and cached.
func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]

func play(id: StringName) -> void:
	if disabled or suspended or not unlocked or not AudioManifest.SFX.has(id):
		return
	var info: Dictionary = AudioManifest.SFX[id]
	var now := Time.get_ticks_msec()
	if _last_ms.has(id) and now - int(_last_ms[id]) < int(float(info.min_gap_s) * 1000.0):
		return
	_last_ms[id] = now
	var p := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	last_pitch = 1.0 + float(info.pitch_spread) * PITCH_TABLE[_seq % PITCH_TABLE.size()]
	_seq += 1
	p.stream = _stream(info.path)
	p.volume_db = float(info.volume_db)
	p.pitch_scale = last_pitch
	p.play()
	last_played.append(id)
	if last_played.size() > RING:
		last_played = last_played.slice(last_played.size() - RING)

func _on_gold_changed(_g: int, delta: int) -> void:
	if delta > 0:
		play(&"collect")
	elif delta < 0:
		play(&"build_tick")

func _on_phase_changed(p: int, _day: int) -> void:
	_phase = p
	if p == Phase.NIGHT:
		_plan_size = GameState.lane_plan.size()
	if p == Phase.DAWN:
		play(&"dawn")
	_set_music(&"night" if p == Phase.NIGHT else &"day")

func _on_wave_cleared(w: int) -> void:
	if _phase == Phase.NIGHT and w < _plan_size - 1:
		play(&"wave_clear")

func _set_music(id: StringName) -> void:
	if not unlocked or disabled:
		return
	music_id = id
	var info: Dictionary = AudioManifest.MUSIC[id]
	var stream := _stream(info.path)
	var target_db := float(info.volume_db)
	var old := _music[_music_cur]
	if old.stream == stream and (old.playing or suspended):
		return  # already on this track
	_music_cur = 1 - _music_cur
	var nxt := _music[_music_cur]
	if _music_tween != null:
		_music_tween.kill()
		_music_tween = null
	if OS.has_feature("web") and AudioManifest.MUSIC_MODE == &"lazy" and not AudioServer.is_stream_registered_as_sample(stream):
		# Godot 4.7.2 cannot release a sample, so a registered track stays referenced in _streams for good (D-212).
		AudioServer.register_stream_as_sample(stream)
	nxt.stop()
	nxt.stream = stream
	if suspended:
		nxt.volume_db = target_db
		old.stop()
		old.volume_db = SILENT_DB
		nxt.play()
		nxt.stream_paused = true  # after play(), which would clear it
		return
	nxt.volume_db = SILENT_DB
	nxt.play()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(nxt, "volume_db", target_db, CROSSFADE_S)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", SILENT_DB, CROSSFADE_S)
		_music_tween.chain().tween_callback(old.stop)

func set_unlocked() -> void:
	unlocked = true
	if _phase >= 0:
		_set_music(&"night" if _phase == Phase.NIGHT else &"day")

func _input(event: InputEvent) -> void:
	if unlocked:
		return
	if (event is InputEventScreenTouch and not event.pressed) \
			or (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and not event.pressed):
		_release_seen = true

func _process(delta: float) -> void:
	if unlocked or not OS.has_feature("web"):
		return
	_probe_left -= delta
	if _probe_left > 0.0:
		return
	_probe_left = PROBE_S
	var n := int(JavaScriptBridge.eval("(window.LST_AUDIO||[]).length", true))
	var ok: bool = _release_seen if n == 0 else bool(JavaScriptBridge.eval("(window.LST_AUDIO||[]).some(c=>c.state==='running')", true))
	if ok:
		set_unlocked()

func set_muted(m: bool) -> void:
	_apply_mute(m)
	if _settings != null:
		_settings.muted = m
		_settings.save_settings()

func _apply_mute(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)

func set_suspended(p: bool) -> void:
	suspended = p
	for pl in all_players():
		pl.stream_paused = p

func sfx_players() -> Array[AudioStreamPlayer]:
	return _sfx

func music_players() -> Array[AudioStreamPlayer]:
	return _music

func all_players() -> Array[AudioStreamPlayer]:
	return _sfx + _music

func debug_clear_gaps() -> void:
	_last_ms.clear()
