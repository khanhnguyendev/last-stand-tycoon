class_name AudioManifest
extends RefCounted
## The single place a sound or a track is chosen (S5 spec 4.1, D-211). Chosen without listening: see docs/review/AUDIO.md.
## mean_db/peak_db/duration_s are the measured source values (ffmpeg volumedetect, ffprobe); volume_db brings mean_db to
## the class target.

const CLASS_TARGET_DB := {&"repeated": -24.0, &"single": -18.0, &"music": -26.0}
const BUDGET_BYTES := 2_621_440
const MAX_MUSIC_S := 60.0
## Music playback mode (D-212): &"samples" (both tracks registered as samples at boot), &"lazy" (each track registered as a
## sample on first use and kept for the life of the director) or &"stream". &"swap" was dropped: Godot 4.7.2 cannot release a sample.
const MUSIC_MODE := &"lazy"

const SFX := {
	&"throw": {"path": "res://assets/kenney-rpg-audio/knifeSlice2.ogg", "class": &"repeated", "mean_db": -19.1, "peak_db": 0.0, "duration_s": 0.57, "volume_db": -5.0, "pitch_spread": 0.08, "min_gap_s": 0.05},
	&"hit": {"path": "res://assets/kenney-impact-sounds/impactPunch_medium_000.ogg", "class": &"repeated", "mean_db": -17.2, "peak_db": -1.1, "duration_s": 0.43, "volume_db": -7.0, "pitch_spread": 0.08, "min_gap_s": 0.05},
	&"poof": {"path": "res://assets/kenney-impact-sounds/impactSoft_heavy_000.ogg", "class": &"repeated", "mean_db": -17.4, "peak_db": -0.9, "duration_s": 0.51, "volume_db": -6.5, "pitch_spread": 0.08, "min_gap_s": 0.05},
	&"pickup": {"path": "res://assets/kenney-interface-sounds/pluck_001.ogg", "class": &"repeated", "mean_db": -20.4, "peak_db": 0.0, "duration_s": 0.1, "volume_db": -3.5, "pitch_spread": 0.08, "min_gap_s": 0.05},
	&"take": {"path": "res://assets/kenney-interface-sounds/drop_003.ogg", "class": &"repeated", "mean_db": -19.6, "peak_db": -1.1, "duration_s": 0.19, "volume_db": -4.5, "pitch_spread": 0.08, "min_gap_s": 0.05},
	&"stock": {"path": "res://assets/kenney-impact-sounds/impactPlate_heavy_001.ogg", "class": &"repeated", "mean_db": -17.4, "peak_db": -0.9, "duration_s": 0.35, "volume_db": -6.5, "pitch_spread": 0.08, "min_gap_s": 0.05},
	&"coin": {"path": "res://assets/kenney-casino-audio/chips-stack-4.ogg", "class": &"repeated", "mean_db": -26.8, "peak_db": -1.2, "duration_s": 0.23, "volume_db": 0.0, "pitch_spread": 0.08, "min_gap_s": 0.05},
	&"collect": {"path": "res://assets/kenney-rpg-audio/dropLeather.ogg", "class": &"single", "mean_db": -18.7, "peak_db": -0.1, "duration_s": 0.42, "volume_db": -1.0, "pitch_spread": 0.0, "min_gap_s": 0.3},
	&"build_tick": {"path": "res://assets/kenney-impact-sounds/impactWood_light_000.ogg", "class": &"repeated", "mean_db": -22.3, "peak_db": -1.1, "duration_s": 0.27, "volume_db": -1.5, "pitch_spread": 0.08, "min_gap_s": 0.05},
	&"build_done": {"path": "res://assets/kenney-music-jingles/jingles_PIZZI04.ogg", "class": &"single", "mean_db": -16.3, "peak_db": -2.9, "duration_s": 0.56, "volume_db": -1.5, "pitch_spread": 0.0, "min_gap_s": 0.3},
	&"card_open": {"path": "res://assets/kenney-rpg-audio/bookClose.ogg", "class": &"single", "mean_db": -18.8, "peak_db": 0.0, "duration_s": 0.23, "volume_db": -1.0, "pitch_spread": 0.0, "min_gap_s": 0.3},
	&"card_pick": {"path": "res://assets/kenney-casino-audio/cards-pack-take-out-1.ogg", "class": &"single", "mean_db": -18.9, "peak_db": -0.1, "duration_s": 0.5, "volume_db": -1.0, "pitch_spread": 0.0, "min_gap_s": 0.3},
	&"horn": {"path": "res://assets/kenney-music-jingles/jingles_SAX03.ogg", "class": &"single", "mean_db": -20.0, "peak_db": -10.6, "duration_s": 1.12, "volume_db": 2.0, "pitch_spread": 0.0, "min_gap_s": 0.3},
	&"wave_clear": {"path": "res://assets/kenney-music-jingles/jingles_PIZZI16.ogg", "class": &"single", "mean_db": -17.3, "peak_db": -5.4, "duration_s": 0.46, "volume_db": -0.5, "pitch_spread": 0.0, "min_gap_s": 0.3},
	&"diner_hit": {"path": "res://assets/kenney-impact-sounds/impactWood_heavy_000.ogg", "class": &"repeated", "mean_db": -19.6, "peak_db": -0.9, "duration_s": 0.31, "volume_db": -4.5, "pitch_spread": 0.08, "min_gap_s": 0.05},
	# E5 tier 3 (Task 10): the siege brute's fence thump reuses the diner-hit file (impactWood_heavy_000, Kenney Impact Sounds, already in the repo).
	&"thump": {"path": "res://assets/kenney-impact-sounds/impactWood_heavy_000.ogg", "class": &"repeated", "mean_db": -19.6, "peak_db": -0.9, "duration_s": 0.31, "volume_db": -4.5, "pitch_spread": 0.08, "min_gap_s": 0.05},
	&"fail": {"path": "res://assets/kenney-music-jingles/jingles_PIZZI14.ogg", "class": &"single", "mean_db": -15.0, "peak_db": -4.9, "duration_s": 0.92, "volume_db": -3.0, "pitch_spread": 0.0, "min_gap_s": 0.3},
	&"dawn": {"path": "res://assets/kenney-music-jingles/jingles_PIZZI10.ogg", "class": &"single", "mean_db": -15.4, "peak_db": -4.6, "duration_s": 0.8, "volume_db": -2.5, "pitch_spread": 0.0, "min_gap_s": 0.3},
	&"guard_down": {"path": "res://assets/kenney-music-jingles/jingles_PIZZI09.ogg", "class": &"single", "mean_db": -16.6, "peak_db": -5.1, "duration_s": 0.57, "volume_db": -1.5, "pitch_spread": 0.0, "min_gap_s": 0.3},
	&"guard_up": {"path": "res://assets/kenney-music-jingles/jingles_PIZZI08.ogg", "class": &"single", "mean_db": -16.6, "peak_db": -4.8, "duration_s": 0.57, "volume_db": -1.5, "pitch_spread": 0.0, "min_gap_s": 0.3},
	&"click": {"path": "res://assets/kenney-interface-sounds/click_001.ogg", "class": &"repeated", "mean_db": -26.4, "peak_db": -1.4, "duration_s": 0.1, "volume_db": 0.0, "pitch_spread": 0.08, "min_gap_s": 0.05},
}

const MUSIC := {
	&"day": {"path": "res://assets/oga-happy-adventure-loop/happy_adventure_loop.mp3", "mean_db": -13.5, "peak_db": 0.0, "duration_s": 46.81, "volume_db": -12.5},
	&"night": {"path": "res://assets/oga-chiptune-adventures/stage_2.mp3", "mean_db": -10.9, "peak_db": 0.0, "duration_s": 56.1, "volume_db": -15.0},
}

static func all_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for d in [SFX, MUSIC]:
		for id in d:
			out.append(String(d[id].path))
	return out
