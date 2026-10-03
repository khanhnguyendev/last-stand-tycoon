# S5 Polish, Onboarding, Audio, Juice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the finished-looking game feel finished: CC0 sound and music with a mute toggle and web unlock, one-draw
juice, a settings panel with New game, a safe-area HUD pass, and a contextual pointer that teaches night 1 and the first
day without text walls. Gameplay stays byte-identical.

**Architecture:** Two new EventBus request signals (`sfx_requested`, `fx_requested`) carry local events to an
`AudioDirector` (Node in Main) and an `FxField` (one MultiMesh in World); neither is ever listened to by gameplay. A
`SettingsStore` keeps device preferences outside the save. Main owns one set of pause reasons. The `Guide` evaluates
pure state predicates (`core/guide_rules.gd`) four times a second and draws one pointer, with an edge arrow for
off-screen targets (`core/edge_clamp.gd`, shared with the HUD). A boot warm-up under an opaque fade pre-draws every
first-use visual.

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer, single-threaded web), GUT 9.7.1, Kenney CC0 audio packs,
two OpenGameArt CC0 tracks, `ffmpeg`/`ffprobe` (`/opt/homebrew/bin`), Playwright Chromium from `~/.cache/lst-playwright`,
the iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-10-02-s5-polish-onboarding-audio-juice-design.md` (D-210..D-219). Read the spec
section named in each task before starting it.

## Global Constraints

- `export GODOT=/Users/ryan/Applications/Godot-4.7.2-stable/Godot.app/Contents/MacOS/Godot` in the same Bash call as
  any Godot or `./run_tests.sh` command. After creating a worktree, run `"$GODOT" --headless --path . --import` once.
- `./run_tests.sh unit` and `./run_tests.sh sim` pass; they fail on any `SCRIPT ERROR` or GUT error. The sim suite stays
  under 60 s (D-132); never drop, skip or weaken a test.
- **Gameplay identity:** `tools/baseline_diff.sh` prints `baseline identical` after every task. The baseline in
  `tests/sim/baseline/` is never re-recorded. S5 changes no gameplay rule, number, timing, pool size or Rng call.
- **Request signals are one-way:** `EventBus.sfx_requested` and `EventBus.fx_requested` are emitted by gameplay or UI
  code and listened to only by `AudioDirector` and `FxField`. No gameplay code listens to them.
- Visual and audio code may use `_process` and tweens; it never writes GameState, never calls `Rng` or global rand, and
  never adds physics nodes.
- Every number in `balance/ui_tuning.gd`; every user string through `tr()`.
- **Hot files** (D-139, D-181): `project.godot`, `CLAUDE.md`, `run_tests.sh`, `.github/workflows/*`, `autoload/*`,
  `balance/*`, `world/main.gd`, `world/main.tscn`, `world/world.gd`. The implementer writes the change, saves it with
  `git diff -- <hot files> > /tmp/wiring_t<NN>.patch`, keeps it applied locally for its test runs, never commits it,
  and pastes the patch text in its report. The main session applies and commits it after review.
- **Input:** `emulate_mouse_from_touch` is off. Any new tappable thing hit-tests in its own `_input` for both
  `InputEventScreenTouch` and left `InputEventMouseButton`, owns the finger with the `_owned` pattern of
  `ui/debug/debug_overlay.gd:111-136`, and clears `_owned` on `NOTIFICATION_PAUSED`. Every Control ignores the mouse.
- **Draw calls (D-201):** UI icons come from `IconAtlas` cells (no `draw_circle`, `draw_style_box`, Polygon2D for new
  UI). All particles are one `FxField`.
- **Loading PNGs by path:** always `Image.load_from_file(ProjectSettings.globalize_path(path))`.
- **CanvasLayer numbers:** HUD 10, Guide 12, card overlay 15, perf 20, settings 25, debug 30, boot fade 90, build label
  100.
- **Safe-area tests:** `SafeArea.override_for_tests` (Task 9 adds it; until then insets are zero off web) is the only
  way tests and captures set insets; reset it to `{}` in `after_each`.
- **Time in tests:** `run_tests.sh` runs with `--fixed-fps 60`, so wall-clock time (`Time.get_ticks_msec()`) does not
  match game time in tests. Timers that tests wait on accumulate `delta`.
- **URL flags** (`world/url_flags.gd`, Task 3a) are read only on web and only in debug or profile builds; release ignores
  them.
- **Visual tasks** (4, 5, 6, 8a, 8b, 9, 10, 11) end with `tools/shots.sh docs/review/media/s5/task<NN>` plus the task's extra
  shots, and the main session reviews them at 100% and at 40% against `docs/ART_BIBLE.md`.
- **Commits:** one per task on the phase branch; message `feat(s5): …` or `docs(s5): …`; trailer = the
  `Co-Authored-By` line from your own session's attribution, then
  `Claude-Session: https://claude.ai/code/session_019nNyHrXgHzKVKBtdqy9Hez`.
- **Branches (D-133):** `s5/p1-audio`, `s5/p2-juice`, `s5/p3-ui`, `s5/p4-guide`, `s5/p5-results`, each from an
  up-to-date `main`. Each phase is self-merged by the main session (D-137, D-159).

## Review Focus

Task numbering: Tasks 3 and 8 are split into 3a/3b and 8a/8b (plan review); spec §10's numbers map to these.

1. **A pre-S5 player with a save but no settings key** resumes into DAY of day 5: the Guide must show nothing, and must
   complete (save `guide_done`) at the next `phase_changed(NIGHT, day ≥ 2)`. Test in Task 11.
2. **Mute set before unlock:** with `muted == true` loaded from settings, unlock starts the phase's music with the Master
   bus already muted, and toggling sound on later makes it audible without a restart. Test in Task 3b.
3. **Tab hidden across a phase change:** suspended, then `phase_changed(NIGHT)`; on resume exactly one music player
   plays, it holds the night stream at its manifest volume, and no player stays `stream_paused`. Test in Task 3b.
4. **Gear tapped while the card overlay is open and inside its input guard:** the panel opens, no card is chosen, the
   joystick does not start; closing the panel leaves the overlay accepting. Test in Task 8b.
5. **Window resized to landscape** (1280×720) with the settings panel open and with the Guide's edge arrow showing: both
   relayout on `size_changed` and stay inside the safe rect, with notch insets set through
   `SafeArea.override_for_tests`. Tests in Tasks 9 (gear) and 10 (Guide).

---

## Phase P1: Audio (`s5/p1-audio`)

### Task 1: Web console baseline, audio intake, manifest, validator, AUDIO.md

**Spec:** §4.1, §4.2, §9 (web checks), D-211, D-219.

**Files:**
- Create: `assets/kenney-interface-sounds/`, `assets/kenney-impact-sounds/`, `assets/kenney-rpg-audio/`,
  `assets/kenney-casino-audio/`, `assets/kenney-music-jingles/` (only the used `.ogg` files + `LICENSE.txt` copied from
  the pack's `License.txt`)
- Create: `assets/oga-happy-adventure-loop/happy_adventure_loop.mp3`, `assets/oga-chiptune-adventures/stage_2.mp3`, each
  with `LICENSE.txt`
- Create: `art/audio/audio_manifest.gd`, `docs/review/AUDIO.md`, `docs/review/media/s5/console_baseline_main.txt`
- Modify: `tools/asset_validator.gd` (new checks + `validate_project`), `docs/ASSET_LICENSES.md` (7 rows),
  `export/pw_check.mjs` (`CONSOLE_OUT` env var)
- Test: `tests/unit/test_asset_validator.gd`, `tests/unit/test_audio_manifest.gd`

**Interfaces:**
- Produces: `AudioManifest.SFX: Dictionary` (`StringName -> {path, volume_db, mean_db, peak_db, duration_s, class,
  pitch_spread, min_gap_s}`), `AudioManifest.MUSIC: Dictionary` (`&"day"`, `&"night"` -> `{path, volume_db, mean_db,
  peak_db, duration_s}`), `AudioManifest.CLASS_TARGET_DB := {&"repeated": -24.0, &"single": -18.0, &"music": -26.0}`,
  `AudioManifest.BUDGET_BYTES := 2_621_440`, `AudioManifest.MAX_MUSIC_S := 60.0`, `AudioManifest.all_paths() ->
  PackedStringArray`.
- Produces: `AssetValidator.check_audio(sfx: Dictionary, music: Dictionary, assets_dir: String, budget: int,
  max_music_s: float) -> Array[String]`, `AssetValidator.check_audio_location(root: String) -> Array[String]`.

- [ ] **Step 1: Record the console baseline from `main`.** In a scratch worktree of `main` (or the phase branch before
  any change), export the debug web build per `export/README.md`, serve it, and run
  `CONSOLE_OUT=docs/review/media/s5/console_baseline_main.txt WAIT_S=60 node export/pw_check.mjs <url>?reset=1 /tmp/b.png desktop`.
  First add to `export/pw_check.mjs`: when `process.env.CONSOLE_OUT` is set, also append every `[console.*]` and
  `[pageerror]` line to that file. Commit the file; it is what Task 11 and Task 12 diff against.

- [ ] **Step 2: Copy the SFX.** From `/Users/ryan/ws/1.GAME/lst-assets-src/audio/<pack>/` copy exactly these files
  (flat, keep the file name) into `assets/kenney-<pack>/`:

  | id | source (pack/file) | class |
  |---|---|---|
  | throw | rpg-audio/knifeSlice2.ogg | repeated |
  | hit | impact-sounds/impactPunch_medium_000.ogg | repeated |
  | poof | impact-sounds/impactSoft_heavy_000.ogg | repeated |
  | pickup | interface-sounds/pluck_001.ogg | repeated |
  | take | interface-sounds/drop_003.ogg | repeated |
  | stock | impact-sounds/impactPlate_heavy_001.ogg | repeated |
  | coin | casino-audio/chips-stack-1.ogg | repeated |
  | collect | rpg-audio/handleCoins.ogg | single |
  | build_tick | impact-sounds/impactWood_light_000.ogg | repeated |
  | build_done | music-jingles/jingles_PIZZI04.ogg | single |
  | card_open | casino-audio/card-fan-1.ogg | single |
  | card_pick | casino-audio/cards-pack-take-out-1.ogg | single |
  | horn | music-jingles/jingles_SAX03.ogg | single |
  | wave_clear | music-jingles/jingles_PIZZI16.ogg | single |
  | diner_hit | impact-sounds/impactWood_heavy_000.ogg | repeated |
  | fail | music-jingles/jingles_PIZZI14.ogg | single |
  | dawn | music-jingles/jingles_PIZZI10.ogg | single |
  | guard_down | music-jingles/jingles_PIZZI09.ogg | single |
  | guard_up | music-jingles/jingles_PIZZI08.ogg | single |
  | click | interface-sounds/click_001.ogg | repeated |

  Find each file with `find <pack> -name <file>`; the packs nest them in subfolders. Copy each pack's `License.txt` to
  `assets/kenney-<pack>/LICENSE.txt`.

- [ ] **Step 3: Encode the music.**

  ```bash
  SRC=/Users/ryan/ws/1.GAME/lst-assets-src/audio/music
  /opt/homebrew/bin/ffmpeg -y -i "$SRC/happy-adventure-loop/happy_adveture.mp3" -t 60 -ac 1 -ar 32000 -c:a libmp3lame -b:a 64k assets/oga-happy-adventure-loop/happy_adventure_loop.mp3
  /opt/homebrew/bin/ffmpeg -y -i "$SRC/4-chiptunes-adventure/Juhani Junkala [Chiptune Adventures] 2. Stage 2.ogg" -t 60 -ac 1 -ar 32000 -c:a libmp3lame -b:a 64k assets/oga-chiptune-adventures/stage_2.mp3
  ```

  Each `LICENSE.txt` holds, one per line: page URL, retrieval date `2026-10-02`, the licence field verbatim
  (`License(s): CC0`), the author field verbatim, the uploader-is-author note, the original file name, its SHA-256, and
  the ffmpeg command. Values:
  - day: `https://opengameart.org/content/happy-adventure-loop`; `Author: TinyWorlds` (submitter account
    `/users/tinyworlds`); `happy_adveture.mp3`; SHA-256
    `50aa6a32625fe8565403a0c8ceb772d7fb500b9267d0019eacfe0fc742b6c73d`.
  - night: `https://opengameart.org/content/4-chiptunes-adventure`; `Author: SubspaceAudio` (Juhani Junkala's account;
    the pack's INFO.txt: "I'm Juhani Junkala, the author of this music collection … released under CC0");
    `Juhani Junkala [Chiptune Adventures] 2. Stage 2.ogg`; SHA-256
    `68ec252839e1f227275fe46fca5e38ffab5086b39a6ab2650a752e4f2ef2a5a7`.

  Run `--import`, then set `loop=true` in both `.mp3.import` files' `[params]` and run `--import` again.

- [ ] **Step 4: Measure.** For every copied file run
  `ffprobe -v error -show_entries format=duration -of csv=p=0 <f>` and
  `ffmpeg -hide_banner -nostats -i <f> -af volumedetect -f null - 2>&1 | grep -E 'mean_volume|max_volume'`. Set
  `volume_db = round_to_0.5(CLASS_TARGET_DB[class] - mean_db)`, clamped so `peak_db + volume_db ≤ -1.0`. Music class is
  `music`. If the clamp leaves `mean_db + volume_db` more than 3 dB from the target, pick another file from the same
  pack with the same kind of name, and log the swap in AUDIO.md.

- [ ] **Step 5: Write `art/audio/audio_manifest.gd`.**

  ```gdscript
  class_name AudioManifest
  extends RefCounted
  ## The single place a sound or a track is chosen (S5 spec 4.1, D-211). Chosen without listening: see docs/review/AUDIO.md.
  ## mean_db/peak_db/duration_s are the measured source values (ffmpeg volumedetect, ffprobe); volume_db brings mean_db to
  ## the class target.

  const CLASS_TARGET_DB := {&"repeated": -24.0, &"single": -18.0, &"music": -26.0}
  const BUDGET_BYTES := 2_621_440
  const MAX_MUSIC_S := 60.0
  ## Music playback mode, set by the Task 3 spike (D-212): &"samples", &"stream" or &"swap".
  const MUSIC_MODE := &"samples"

  const SFX := {
  	&"throw": {"path": "res://assets/kenney-rpg-audio/knifeSlice2.ogg", "class": &"repeated", "mean_db": -19.1, "peak_db": 0.0, "duration_s": 0.57, "volume_db": -5.0, "pitch_spread": 0.08, "min_gap_s": 0.05},
  	# … one entry per row of the Step 2 table, measured values from Step 4 …
  }

  const MUSIC := {
  	&"day": {"path": "res://assets/oga-happy-adventure-loop/happy_adventure_loop.mp3", "mean_db": 0.0, "peak_db": 0.0, "duration_s": 0.0, "volume_db": 0.0},
  	&"night": {"path": "res://assets/oga-chiptune-adventures/stage_2.mp3", "mean_db": 0.0, "peak_db": 0.0, "duration_s": 0.0, "volume_db": 0.0},
  }

  static func all_paths() -> PackedStringArray:
  	var out := PackedStringArray()
  	for d in [SFX, MUSIC]:
  		for id in d:
  			out.append(String(d[id].path))
  	return out
  ```

  Every `SFX` entry has all eight keys; `pitch_spread` is 0.08 for `repeated` and 0.0 for `single`; `min_gap_s` is 0.05
  for `repeated` and 0.3 for `single`. Fill the music values from Step 4 (the zeros above are replaced).

- [ ] **Step 6: Write the failing tests.** `tests/unit/test_audio_manifest.gd`:

  ```gdscript
  extends GutTest

  func test_every_entry_meets_its_class_target() -> void:
  	for id in AudioManifest.SFX:
  		var e: Dictionary = AudioManifest.SFX[id]
  		var target: float = AudioManifest.CLASS_TARGET_DB[e["class"]]
  		assert_almost_eq(e.mean_db + e.volume_db, target, 3.0, "%s loudness" % id)
  		assert_true(e.peak_db + e.volume_db <= 0.0, "%s clips" % id)
  		var cap := 0.6 if e["class"] == &"repeated" else 1.5
  		assert_true(e.duration_s < cap, "%s too long" % id)
  	for id in AudioManifest.MUSIC:
  		var m: Dictionary = AudioManifest.MUSIC[id]
  		assert_almost_eq(m.mean_db + m.volume_db, AudioManifest.CLASS_TARGET_DB[&"music"], 3.0, "%s loudness" % id)

  func test_every_id_the_spec_names_exists() -> void:
  	for id in [&"throw", &"hit", &"poof", &"pickup", &"take", &"stock", &"coin", &"collect", &"build_tick", &"build_done",
  			&"card_open", &"card_pick", &"horn", &"wave_clear", &"diner_hit", &"fail", &"dawn", &"guard_down", &"guard_up", &"click"]:
  		assert_true(AudioManifest.SFX.has(id), String(id))
  	assert_true(AudioManifest.MUSIC.has(&"day") and AudioManifest.MUSIC.has(&"night"))

  func test_music_loops() -> void:
  	for id in AudioManifest.MUSIC:
  		var s: AudioStreamMP3 = load(AudioManifest.MUSIC[id].path)
  		assert_true(s.loop, "%s loops" % id)
  ```

  In `tests/unit/test_asset_validator.gd` add, using a temp dir under `user://validator_audio/` built in the test:
  - `check_audio` reports a manifest path that does not exist;
  - it reports an `.ogg` under the temp assets dir that the manifest does not name;
  - it reports a total over the budget (pass `budget = 10`);
  - it reports a music stream longer than `max_music_s` (pass `max_music_s = 0.1` with a real manifest track);
  - `check_audio_location` reports an `.ogg` outside `assets/` (temp root with `ui/x.ogg`) and accepts one under
    `assets/`.

  Run: `./run_tests.sh unit` — expect the new tests to FAIL (functions missing).

- [ ] **Step 7: Implement the checks** in `tools/asset_validator.gd`:

  ```gdscript
  const AUDIO_EXT := ["ogg", "mp3", "wav"]

  ## S5 (D-211): every manifest path exists; every audio file under assets_dir is named by the manifest; the total
  ## size fits the budget; music is at most max_music_s long.
  static func check_audio(sfx: Dictionary, music: Dictionary, assets_dir: String, budget: int, max_music_s: float) -> Array[String]:
  	var out: Array[String] = []
  	var named := {}
  	for d in [sfx, music]:
  		for id in d:
  			var p := String(d[id].path)
  			named[p] = true
  			if not FileAccess.file_exists(p):
  				out.append("audio %s: missing %s" % [id, p])
  	var files: Array = []
  	_files(assets_dir, files)
  	var total := 0
  	for f in files:
  		if String(f).get_extension().to_lower() in AUDIO_EXT:
  			total += FileAccess.get_file_as_bytes(f).size()
  			if not named.has(f):
  				out.append("audio file not in the manifest: %s" % f)
  	if total > budget:
  		out.append("audio total %d B > budget %d B" % [total, budget])
  	for id in music:
  		var p := String(music[id].path)
  		if FileAccess.file_exists(p):
  			var s := load(p) as AudioStream
  			if s != null and s.get_length() > max_music_s:
  				out.append("music %s is %.1f s > %.1f s" % [id, s.get_length(), max_music_s])
  	return out

  static func check_audio_location(root: String) -> Array[String]:
  	var out: Array[String] = []
  	var files: Array = []
  	_files(root, files)
  	for f in files:
  		var rel := String(f).trim_prefix(root.trim_suffix("/") + "/")
  		if rel.get_extension().to_lower() in AUDIO_EXT and not rel.begins_with("assets/") and not rel.begins_with(".godot/") and not rel.begins_with("build/"):
  			out.append("audio outside assets/: %s" % f)
  	return out
  ```

  Check `_files` (line 14) for how it walks and whether it returns `res://` paths; match its output format. In
  `validate_project` append:

  ```gdscript
  	errors.append_array(check_audio(AudioManifest.SFX, AudioManifest.MUSIC, "res://assets", AudioManifest.BUDGET_BYTES, AudioManifest.MAX_MUSIC_S))
  	errors.append_array(check_audio_location("res://"))
  ```

- [ ] **Step 8: ASSET_LICENSES rows.** One row per new `assets/` folder in the existing columns: Pack, Folder, Source,
  License (`CC0 1.0`), Added (`2026-10-03`), LICENSE.txt SHA-256 (`shasum -a 256`), Files (non-hidden, non-`.import`
  files in the folder, including `LICENSE.txt`). `check_licenses` must pass.

- [ ] **Step 9: Write `docs/review/AUDIO.md`.** Sections: "Chosen without listening" (one paragraph: picks are by
  pack and file name, measured length and loudness, and for jingles a pitch contour from an STFT peak tracker; swap any
  line in `art/audio/audio_manifest.gd`); a table `id | file | duration | peak | mean | volume_db | reason`; "Music" (both tracks, licence evidence, encode command,
  "an MP3 loop may have a small gap at the loop point"); "Spike results" (empty heading, Task 3 fills it). Reasons:
  throw "name fits a thrown knife"; hit "punch on a Boar"; poof "soft thud for the kill poof"; pickup "short pluck";
  take "freezer take"; stock "plate on the counter"; coin "chip clink per sale"; collect "coins in hand"; build_tick
  "wood tap"; build_done "rising major sixth A3→F#4"; card_open "card fan"; card_pick "take a card"; horn "sax
  semitone trill C#5/C5, an alarm"; wave_clear "rising fifth D#4 A4 A#4"; diner_hit "heavy wood knock"; fail
  "descending G#4 F#4 E4 D4 C4"; dawn "rising D4 E4 F#4 G4"; guard_down "falling E4→D4"; guard_up "rising D4→E4";
  click "UI click".

- [ ] **Step 10: Run** `./run_tests.sh unit` (PASS, including `test_assets.gd`), `./run_tests.sh sim`,
  `tools/baseline_diff.sh` (`baseline identical`). Report the audio total in bytes.

- [ ] **Step 11: Commit** everything above (`feat(s5): audio intake, manifest, validator audio rules, AUDIO.md (Task 1)`).

### Task 2: SettingsStore

**Spec:** §3 row "Where do settings live?", D-210.

**Files:**
- Create: `world/save/settings_store.gd`
- Test: `tests/unit/test_settings_store.gd`

**Interfaces:**
- Consumes: `SaveStore.js_call(op, key, value)`, `SaveStore.key_prefix_for(path)`, `SaveStore.normalize_path(p)`.
- Produces: `class_name SettingsStore extends RefCounted`; `static func for_platform() -> SettingsStore`;
  `static func with_dir(dir: String) -> SettingsStore`; `var muted := false`; `var guide_done := false`;
  `func load_settings() -> void`; `func save_settings() -> bool`; `const KEY := "settings"`; `const VERSION := 1`.

- [ ] **Step 1: Write the failing tests.**

  ```gdscript
  extends GutTest

  const DIR := "user://test_settings"

  func before_each() -> void:
  	var s := SettingsStore.with_dir(DIR)
  	s.wipe_for_tests()

  func test_defaults_when_missing() -> void:
  	var s := SettingsStore.with_dir(DIR)
  	s.load_settings()
  	assert_false(s.muted)
  	assert_false(s.guide_done)

  func test_round_trip() -> void:
  	var s := SettingsStore.with_dir(DIR)
  	s.muted = true
  	s.guide_done = true
  	assert_true(s.save_settings())
  	var t := SettingsStore.with_dir(DIR)
  	t.load_settings()
  	assert_true(t.muted)
  	assert_true(t.guide_done)

  func test_corrupt_value_gives_defaults() -> void:
  	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
  	var f := FileAccess.open(DIR.path_join("settings.json"), FileAccess.WRITE)
  	f.store_string("{not json")
  	f.close()
  	var s := SettingsStore.with_dir(DIR)
  	s.load_settings()
  	assert_false(s.muted)
  	assert_false(s.guide_done)

  func test_wrong_types_give_defaults_per_field() -> void:
  	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
  	var f := FileAccess.open(DIR.path_join("settings.json"), FileAccess.WRITE)
  	f.store_string(JSON.stringify({"v": 1, "muted": "yes", "guide_done": true}))
  	f.close()
  	var s := SettingsStore.with_dir(DIR)
  	s.load_settings()
  	assert_false(s.muted)
  	assert_true(s.guide_done)

  func test_save_wipe_leaves_settings() -> void:
  	var s := SettingsStore.with_dir(DIR)
  	s.muted = true
  	s.save_settings()
  	SaveStore.with_dir(DIR).wipe()
  	var t := SettingsStore.with_dir(DIR)
  	t.load_settings()
  	assert_true(t.muted)

  func test_web_key_is_separate_from_save_keys() -> void:
  	assert_false(SettingsStore.KEY in SaveStore.NAMES)
  ```

  Run `./run_tests.sh unit` — FAIL (class missing).

- [ ] **Step 2: Implement.**

  ```gdscript
  class_name SettingsStore
  extends RefCounted
  ## Device preferences, separate from the save (S5 D-210): {v, muted, guide_done}. Web: localStorage key
  ## lst:<pathname>:settings, through SaveStore's try/catch JS. Elsewhere: <dir>/settings.json. Missing or corrupt
  ## means defaults; SaveStore.wipe() and New game never touch it.

  const KEY := "settings"
  const VERSION := 1

  var muted := false
  var guide_done := false
  var _web := false
  var _key := ""
  var _dir := ""

  static func for_platform() -> SettingsStore:
  	var s := SettingsStore.new()
  	if OS.has_feature("web"):
  		s._web = true
  		s._key = SaveStore.key_prefix_for(SaveStore.normalize_path(str(JavaScriptBridge.eval("window.location.pathname", true)))) + KEY
  	else:
  		s._dir = "user://save"
  	return s

  static func with_dir(dir: String) -> SettingsStore:
  	var s := SettingsStore.new()
  	s._dir = dir
  	return s

  func load_settings() -> void:
  	muted = false
  	guide_done = false
  	var j := JSON.new()
  	if j.parse(_read()) != OK or typeof(j.data) != TYPE_DICTIONARY:
  		return
  	var d: Dictionary = j.data
  	if typeof(d.get("muted")) == TYPE_BOOL:
  		muted = d.muted
  	if typeof(d.get("guide_done")) == TYPE_BOOL:
  		guide_done = d.guide_done

  func save_settings() -> bool:
  	return _write(JSON.stringify({"v": VERSION, "muted": muted, "guide_done": guide_done}))

  ## Tests only: remove the stored value.
  func wipe_for_tests() -> void:
  	if _web:
  		JavaScriptBridge.eval(SaveStore.js_call("remove", _key), true)
  	elif FileAccess.file_exists(_dir.path_join(KEY + ".json")):
  		DirAccess.remove_absolute(ProjectSettings.globalize_path(_dir.path_join(KEY + ".json")))

  func _read() -> String:
  	if _web:
  		var j := JSON.new()
  		if j.parse(str(JavaScriptBridge.eval(SaveStore.js_call("get", _key), true))) != OK or typeof(j.data) != TYPE_DICTIONARY:
  			return ""
  		return String(j.data.value) if int(j.data.ok) == 1 else ""
  	var p := _dir.path_join(KEY + ".json")
  	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""

  func _write(text: String) -> bool:
  	if _web:
  		var raw = JavaScriptBridge.eval(SaveStore.js_call("set", _key, text), true)
  		return typeof(raw) in [TYPE_INT, TYPE_FLOAT] and int(raw) == 1
  	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
  	var f := FileAccess.open(_dir.path_join(KEY + ".json"), FileAccess.WRITE)
  	if f == null:
  		return false
  	f.store_string(text)
  	f.close()
  	return true
  ```

- [ ] **Step 3: Run** `./run_tests.sh unit` (PASS), `tools/baseline_diff.sh`.
- [ ] **Step 4: Commit** (`feat(s5): SettingsStore outside the save (Task 2)`).

### Task 3a: Bus layout, UrlFlags, web shell hook, unlock and playback spike

**Spec:** §3 rows on unlock and playback; §4.4; D-212.

**Files:**
- Create: `world/url_flags.gd`, `default_bus_layout.tres`, `export/pw_audio_spike.mjs`
- Modify: `export/web_shell.html` (AudioContext subclass), `docs/review/AUDIO.md` (spike results),
  `art/audio/audio_manifest.gd` (`MUSIC_MODE`)
- Test: `tests/unit/test_url_flags.gd`, `tests/unit/test_audio_buses.gd`

**Interfaces:**
- Produces: `UrlFlags.get_flag(name: String) -> String` ("" when absent, off web, or in release);
  `UrlFlags.parse(query: String) -> Dictionary`; `UrlFlags.set_for_tests(query: String)`.
- Produces: `AudioManifest.MUSIC_MODE` set to the spike's choice.
- Produces: `export/pw_audio_spike.mjs <url>` (prints the AudioContext states before and after a tap).

- [ ] **Step 1: Bus layout.** Create `default_bus_layout.tres` with buses `Master`, `SFX` (send Master), `Music` (send
  Master). Godot loads `res://default_bus_layout.tres` by default; no `project.godot` change. Add `tests/unit/test_audio_buses.gd`:
  `AudioServer.get_bus_index("SFX") >= 0` and `"Music"`.

- [ ] **Step 2: UrlFlags.**

  ```gdscript
  class_name UrlFlags
  extends RefCounted
  ## Query-string flags for debug and profile web builds (S5): audio=0, warmup=0, mute=1, guide=0|1. Release ignores them.

  static var _cache: Dictionary = {}
  static var _loaded := false

  static func get_flag(name: String) -> String:
  	if not _loaded:
  		_loaded = true
  		if OS.has_feature("web") and (OS.is_debug_build() or OS.has_feature("profile_overlay")):
  			_cache = parse(str(JavaScriptBridge.eval("window.location.search", true)))
  	return String(_cache.get(name, ""))

  static func parse(query: String) -> Dictionary:
  	var out := {}
  	for part in query.trim_prefix("?").split("&", false):
  		var kv := part.split("=", true, 1)
  		out[kv[0].uri_decode()] = kv[1].uri_decode() if kv.size() > 1 else "1"
  	return out

  static func set_for_tests(query: String) -> void:
  	_cache = parse(query)
  	_loaded = true
  ```

  Test `parse("?audio=0&guide")` gives `{"audio": "0", "guide": "1"}`; `set_for_tests("")` resets (call it in
  `after_each` of every test that sets flags).

- [ ] **Step 3: Web shell hook.** In `export/web_shell.html`, add before `<script src="$GODOT_URL"></script>`:

  ```html
  		<script>
  // S5 D-212: remember every AudioContext so the game can read its state. A subclass, not a Proxy (AudioWorklet brand checks).
  (function () {
  	window.LST_AUDIO = [];
  	for (const name of ['AudioContext', 'webkitAudioContext']) {
  		const Base = window[name];
  		if (typeof Base !== 'function') continue;
  		window[name] = class extends Base {
  			constructor(...args) { super(...args); window.LST_AUDIO.push(this); }
  		};
  	}
  }());
  		</script>
  ```

- [ ] **Step 4: Spike (record, then decide).** Build a debug web export of the branch with a temporary spike scene
  hook: on boot, register both music streams as samples (`AudioServer.register_stream_as_sample`), time it with
  `Time.get_ticks_usec()`, compute decoded bytes `AudioServer.get_mix_rate() * 2 * 4 * stream.get_length()` per track,
  try `JavaScriptBridge.eval("(typeof HEAP8!=='undefined')?HEAP8.length:-1", true)` before and after, and draw one status
  `Label` (layer 99) with: probe value, registration ms, decoded MB, heap before/after, `AudioServer.get_mix_rate()`.
  Then:
  - **Chromium:** a Playwright script (`export/pw_audio_spike.mjs`, kept in the repo for Task 11) loads the page, reads
    `window.LST_AUDIO.map(c => c.state)` (expect `suspended`), taps the canvas centre (`page.mouse.click`), waits 1 s,
    reads it again (expect `running`), and screenshots the label. Then repeat with the music player set to
    `PLAYBACK_TYPE_STREAM` and a 60 s run; record mean `proc_ms` from the perf overlay of a profile build and every
    console line containing `underrun` or `Audio`.
  - **iOS Simulator:** open the page with `xcrun simctl openurl`, wait 20 s, screenshot; read the label (no input:
    before-gesture half only).
  Pick the music mode: (1) `samples` if registration < 500 ms and decoded total ≤ 48 MB; else (2) `stream` if no
  underrun and mean `proc_ms` +≤ 1.0; else (3) `swap`. Write the numbers and the choice under "Spike results" in
  `docs/review/AUDIO.md`, set `AudioManifest.MUSIC_MODE`, and put the result in the report (the main session appends
  it to D-212). Remove the spike hook before committing. **If the probe never reads `running` after a tap on Chromium,
  stop and report** (escalation: the pre-agreed fallback is the input-release test, which the director then uses on
  web).

- [ ] **Step 5: Run** unit, sim, `tools/baseline_diff.sh`. **Commit** (`feat(s5): bus layout, UrlFlags, AudioContext hook,
  playback spike (Task 3a)`) and report the spike numbers and the chosen music mode.


### Task 3b: AudioDirector, request hooks, suspend

**Spec:** §3 rows on mute and request signals; §4.3; D-212, D-214, D-218. Review Focus 2 and 3.

**Files:**
- Create: `world/audio/audio_director.gd`
- Modify: `world/focus_pause.gd` (add `signal changed(paused: bool)`; emit it in `set_paused` whenever FocusPause's own
  focus state changes; tree behaviour unchanged until Task 8a), `actors/hero/hero.gd` (throw), `actors/enemy/boar.gd`
  (hit), `world/stations/freezer.gd` (take), `world/stations/counter.gd` (stock)
- Wiring (hot): `autoload/EventBus.gd` (two signals), `world/main.gd` (director, settings store)
- Test: `tests/unit/test_audio_director.gd`, `tests/unit/test_focus_pause.gd` (add signal tests)

**Interfaces:**
- Consumes: `UrlFlags.get_flag`, `UrlFlags.set_for_tests` (Task 3a), `AudioManifest` (Task 1, `MUSIC_MODE` from 3a),
  `SettingsStore` (Task 2), the `SFX` and `Music` buses (Task 3a).
- Produces (EventBus, wiring):

  ```gdscript
  ## Any system -> AudioDirector. A local event wants a sound (S5 D-214). Never listened to by gameplay.
  signal sfx_requested(id: StringName)
  ## Any system -> FxField. A local event wants a particle burst (S5 D-214). Never listened to by gameplay.
  signal fx_requested(kind: StringName, position: Vector3)
  ```

- Produces: `UrlFlags.get_flag(name: String) -> String` ("" when absent, off web, or in release);
  `UrlFlags.set_for_tests(query: String)`.
- Produces: `class_name AudioDirector extends Node` with `var unlocked := false`, `var muted := false`,
  `var suspended := false`, `var music_id: StringName = &""`, `var last_played: Array[StringName]` (ring of 16),
  `var disabled := false` (`?audio=0`), `func setup(settings: SettingsStore, auto_unlock := true) -> void` (off web,
  `auto_unlock` unlocks at once; tests pass `false` to exercise the locked state), `func play(id: StringName) -> void`,
  `func set_muted(m: bool) -> void`, `func set_suspended(p: bool) -> void`, `func set_unlocked() -> void`,
  `func register_streams() -> void`, `const VOICES := 10`, `const RING := 16`.
- Produces: `FocusPause.changed(paused: bool)`.

- [ ] **Step 1: Write the failing tests** (`tests/unit/test_audio_director.gd`). Use a bare director (no Main) for
  the logic tests and `Main.create()` for the wiring tests:

  ```gdscript
  extends GutTest

  var d: AudioDirector

  func before_each() -> void:
  	Balance.reset()
  	UrlFlags.set_for_tests("")
  	d = AudioDirector.new()
  	add_child_autofree(d)
  	d.setup(null)
  	d.set_unlocked()

  func after_each() -> void:
  	AudioServer.set_bus_mute(0, false)
  	GameState.new_game(0)
  	UrlFlags.set_for_tests("")

  func test_bus_signals_map_to_ids() -> void:
  	EventBus.steak_sold.emit(1, 3)
  	EventBus.steak_picked.emit(1)
  	EventBus.build_completed.emit(&"fence_n", 1)
  	EventBus.card_offered.emit([&"archer"])
  	EventBus.card_picked.emit(&"archer", 1)
  	EventBus.wave_incoming.emit(0, &"north", &"")
  	EventBus.diner_damaged.emit(5.0, 100.0)
  	EventBus.night_failed.emit(1)
  	EventBus.guard_knocked_out.emit(&"archer")
  	EventBus.guard_revived.emit(&"archer")
  	EventBus.sfx_requested.emit(&"throw")
  	EventBus.enemy_killed.emit(0, &"north", Vector3.ZERO)
  	EventBus.phase_changed.emit(Phase.DAWN, 1)
  	assert_eq(d.last_played, [&"coin", &"pickup", &"build_done", &"card_open", &"card_pick", &"horn", &"diner_hit", &"fail", &"guard_down", &"guard_up", &"throw", &"poof", &"dawn"])

  func test_gold_delta_sign() -> void:
  	EventBus.gold_changed.emit(10, 10)
  	EventBus.gold_changed.emit(8, -2)
  	assert_eq(d.last_played, [&"collect", &"build_tick"])

  func test_building_changed_plays_nothing() -> void:
  	EventBus.building_changed.emit(&"fence_n", 1, 0)
  	assert_eq(d.last_played, [])

  func test_last_wave_clear_is_silent() -> void:
  	GameState.lane_plan = [{}, {}, {}]
  	EventBus.phase_changed.emit(Phase.NIGHT, 1)
  	EventBus.wave_cleared.emit(0)
  	EventBus.wave_cleared.emit(2)
  	assert_eq(d.last_played.count(&"wave_clear"), 1)

  func test_min_gap_drops_repeats() -> void:
  	d.play(&"hit")
  	d.play(&"hit")
  	assert_eq(d.last_played.count(&"hit"), 1)

  func test_pitch_cycles_the_table() -> void:
  	var pitches := []
  	for i in 5:
  		d.play(&"pickup")
  		pitches.append(d.last_pitch)
  		d.debug_clear_gaps()
  	var spread: float = AudioManifest.SFX[&"pickup"].pitch_spread
  	assert_eq(pitches, [1.0 - spread, 1.0 + 0.5 * spread, 1.0 - 0.5 * spread, 1.0 + spread, 1.0])

  func test_oldest_voice_reused() -> void:
  	for i in AudioDirector.VOICES + 1:
  		d.play(&"click")
  		d.debug_clear_gaps()
  	assert_eq(d.sfx_players().size(), AudioDirector.VOICES)
  	assert_almost_eq(d.sfx_players()[0].pitch_scale, d.last_pitch, 0.0001, "the 11th play reused voice 0")

  func test_nothing_before_unlock_then_music() -> void:
  	var e := AudioDirector.new()
  	add_child_autofree(e)
  	e.setup(null, false)
  	EventBus.phase_changed.emit(Phase.NIGHT, 1)
  	EventBus.sfx_requested.emit(&"throw")
  	assert_eq(e.last_played, [])
  	assert_eq(e.music_id, &"")
  	e.set_unlocked()
  	assert_eq(e.music_id, &"night")

  func test_music_follows_phase() -> void:
  	EventBus.phase_changed.emit(Phase.NIGHT, 1)
  	assert_eq(d.music_id, &"night")
  	EventBus.phase_changed.emit(Phase.DAWN, 1)
  	assert_eq(d.music_id, &"day")
  	EventBus.phase_changed.emit(Phase.DAY, 2)
  	assert_eq(d.music_id, &"day")

  func test_mute_persists_and_sets_master() -> void:
  	var s := SettingsStore.with_dir("user://test_dir_audio")
  	s.wipe_for_tests()
  	var e := AudioDirector.new()
  	add_child_autofree(e)
  	e.setup(s)
  	e.set_muted(true)
  	assert_true(AudioServer.is_bus_mute(0))
  	var t := SettingsStore.with_dir("user://test_dir_audio")
  	t.load_settings()
  	assert_true(t.muted)

  func test_mute_before_unlock_review_focus_2() -> void:
  	var s := SettingsStore.with_dir("user://test_dir_audio")
  	s.muted = true
  	s.save_settings()
  	var e := AudioDirector.new()
  	add_child_autofree(e)
  	s.load_settings()
  	e.setup(s, false)
  	assert_true(AudioServer.is_bus_mute(0))
  	EventBus.phase_changed.emit(Phase.NIGHT, 1)
  	e.set_unlocked()
  	assert_eq(e.music_id, &"night")
  	assert_true(AudioServer.is_bus_mute(0))
  	e.set_muted(false)
  	assert_false(AudioServer.is_bus_mute(0))

  func test_suspend_across_phase_change_review_focus_3() -> void:
  	EventBus.phase_changed.emit(Phase.DAY, 2)
  	d.set_suspended(true)
  	EventBus.phase_changed.emit(Phase.NIGHT, 2)
  	assert_eq(d.music_id, &"night")
  	d.set_suspended(false)
  	for p in d.all_players():
  		assert_false(p.stream_paused)
  	var playing := d.music_players().filter(func(m): return m.playing)
  	assert_eq(playing.size(), 1)
  	assert_eq(playing[0].stream, load(AudioManifest.MUSIC[&"night"].path))
  	assert_almost_eq(playing[0].volume_db, float(AudioManifest.MUSIC[&"night"].volume_db), 0.01)

  func test_audio_flag_disables() -> void:
  	UrlFlags.set_for_tests("?audio=0")
  	var e := AudioDirector.new()
  	add_child_autofree(e)
  	e.setup(null)
  	e.set_unlocked()
  	EventBus.sfx_requested.emit(&"throw")
  	assert_eq(e.last_played, [])
  	UrlFlags.set_for_tests("")

  func test_focus_pause_changed_suspends() -> void:
  	var m := Main.create()
  	add_child_autofree(m)
  	m.focus_pause.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  	assert_true(m.audio_director.suspended)
  	m.focus_pause.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
  	assert_false(m.audio_director.suspended)
  	get_tree().paused = false
  ```

  Also add to `tests/unit/test_focus_pause.gd`: `changed` is emitted with `true` on focus-out and `false` on focus-in
  (`watch_signals(fp)` + `assert_signal_emitted_with_parameters`). And a test per local hook: `hero.attacker.fired`
  emits `sfx_requested(&"throw")`; `Boar.take_hit` emits `sfx_requested(&"hit")`; a freezer tick that moved a steak emits
  `&"take"`; a counter tick that moved one emits `&"stock"` (use `watch_signals(EventBus)`). Run — FAIL.

- [ ] **Step 2: Implement the director.**

  ```gdscript
  class_name AudioDirector
  extends Node
  ## SFX map, music by phase, web unlock, mute bus, suspend (S5 spec 4.3, D-212, D-214, D-218). Listens to EventBus only;
  ## never writes game state. Before unlock it drops SFX and starts no music.

  const VOICES := 10
  const RING := 16
  const PITCH_TABLE: Array[float] = [-1.0, 0.5, -0.5, 1.0, 0.0]
  const CROSSFADE_S := 1.0
  const SILENT_DB := -60.0

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
  var _streams := {}
  var _last_ms := {}
  var _seq := 0
  var _phase := -1
  var _plan_size := 0
  var _probe_left := 0.0
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

  ## Registers every manifest stream as a sample (web only). Main calls it behind the boot fade.
  func register_streams() -> void:
  	for id in AudioManifest.SFX:
  		_stream(AudioManifest.SFX[id].path)
  	for id in AudioManifest.MUSIC:
  		var s := _stream(AudioManifest.MUSIC[id].path)
  		if OS.has_feature("web") and AudioManifest.MUSIC_MODE == &"samples":
  			AudioServer.register_stream_as_sample(s)
  	if OS.has_feature("web"):
  		for id in AudioManifest.SFX:
  			AudioServer.register_stream_as_sample(_stream(AudioManifest.SFX[id].path))

  ## Loaded once and cached.
  func _stream(path: String) -> AudioStream:
  	if not _streams.has(path):
  		_streams[path] = load(path)
  	return _streams[path]
  ```

  Complete the class:
  - `play(id)`: return if `disabled`, not `unlocked`, or id not in `AudioManifest.SFX`. Gap: `Time.get_ticks_msec()`
    against `_last_ms[id]` and `min_gap_s`. Voice `_sfx[_next_voice]`, `_next_voice = (_next_voice + 1) % VOICES`
    (the oldest is reused). `last_pitch = 1.0 + spread * PITCH_TABLE[_seq % 5]`, `_seq += 1`. Set `stream`,
    `volume_db`, `pitch_scale`, `play()`. Push `id` to `last_played`, trimming to `RING`.
  - `_on_gold_changed(_g, delta)`: `delta > 0` plays `collect`, `delta < 0` plays `build_tick`.
  - `_on_phase_changed(p, _day)`: store `_phase`; when `p == Phase.NIGHT`, `_plan_size = GameState.lane_plan.size()`;
    play `dawn` when `p == Phase.DAWN`; `_set_music(&"night" if p == Phase.NIGHT else &"day")`.
  - `_on_wave_cleared(w)`: play `wave_clear` only if `_phase == Phase.NIGHT and w < _plan_size - 1`.
  - `_set_music(id)`: always record `music_id = id` when unlocked and not disabled; if suspended, set the new stream on
    the next player at its manifest `volume_db`, `stop()` the old player, then call `play()` and only after it set
    `stream_paused = true` (so `play()` cannot clear it); otherwise crossfade over `CROSSFADE_S` with a Tween on `volume_db`
    (old to `SILENT_DB` then `stop()`, new from `SILENT_DB` to the manifest `volume_db`). Swap mode
    (`MUSIC_MODE == &"swap"`): unregister the old stream (`AudioServer.unregister_stream_as_sample`) and register the
    new one before playing. Stream mode: set `playback_type = AudioServer.PLAYBACK_TYPE_STREAM` on the music players.
  - `set_unlocked()`: `unlocked = true`; if `_phase >= 0` start `_set_music` for the phase (`&"night"` for NIGHT, else
    `&"day"`); if `_phase < 0`, music starts on the first `phase_changed`.
  - `_process(delta)` (web only, until unlocked): every 1.0 s evaluate the probe
    `JavaScriptBridge.eval("(window.LST_AUDIO||[]).some(c=>c.state==='running')", true)`; if
    `JavaScriptBridge.eval("(window.LST_AUDIO||[]).length", true) == 0`, use `_release_seen` instead.
    `_input(event)` sets `_release_seen` on a touch release, a left mouse button release or a key release (never
    consumes the event).
  - `set_muted(m)`: `_apply_mute(m)`; save to settings when not null. `_apply_mute(m)`: `muted = m`;
    `AudioServer.set_bus_mute(0, m)`.
  - `set_suspended(p)`: `suspended = p`; `stream_paused = p` on every player in `_sfx` and `_music`.
  - Test helpers: `sfx_players()`, `music_players()`, `all_players()`, `debug_clear_gaps()` (clears `_last_ms`).

- [ ] **Step 3: Hooks.**
  - `actors/hero/hero.gd` (where `attacker` is created): `attacker.fired.connect(func(_t): EventBus.sfx_requested.emit(&"throw"))`.
  - `actors/enemy/boar.gd` `take_hit`: inside its existing `if alive:` branch (line 102), after the existing logic,
    `EventBus.sfx_requested.emit(&"hit")`.
  - `world/stations/freezer.gd` `_on_tick`: inside `if GameState.move_freezer_to_carry(1) > 0:` emit `&"take"`.
  - `world/stations/counter.gd` `_on_tick`: inside the success branch emit `&"stock"`.
  - `world/focus_pause.gd`: add `signal changed(paused: bool)` and `var focus_paused := false`; in `set_paused(p)`, at the
    top: `if p != focus_paused: focus_paused = p; changed.emit(p)`; keep the existing tree logic below it unchanged.

- [ ] **Step 4: Main wiring (patch).** In `world/main.gd`:

  ```gdscript
  var audio_director: AudioDirector
  var settings_store: SettingsStore
  ```

  In `_ready()`, right after the FocusPause block:

  ```gdscript
  	audio_director = AudioDirector.new()
  	add_child(audio_director)
  	focus_pause.changed.connect(audio_director.set_suspended)
  ```

  In the `if auto_start:` block, before `_boot.call_deferred()`:

  ```gdscript
  		settings_store = SettingsStore.for_platform()
  		settings_store.load_settings()
  		audio_director.setup(settings_store)
  ```

  and in the `else` case (add one) `audio_director.setup(null)` so tests and sims get a working director with no store.
  In `_boot()`, first line: `audio_director.register_streams()` (Task 7 moves it into the warm-up).

- [ ] **Step 5: Run** `./run_tests.sh unit`, `./run_tests.sh sim`, `tools/baseline_diff.sh`. Export the debug web build
  and run `node export/pw_audio_spike.mjs <url>` once more: `suspended` before the tap, `running` after.
- [ ] **Step 6: Commit** (non-hot files) and report the wiring patch.

---

## Phase P2: Juice (`s5/p2-juice`)

### Task 4: FxField, FX atlas, `fx_requested`, WebGL-warning attribution

**Spec:** §5.1, §9 (carried WebGL warnings), D-214.

**Files:**
- Create: `tools/make_fx_atlas.gd`, `art/fx/fx_atlas.png`, `art/fx/fx.gdshader`, `art/fx/fx_field.gd`
- Modify: `tools/asset_validator.gd` (`check_palette` dirs add `res://art/fx`), `tests/sim/capture.gd` (`--fx=<kind>`)
- Wiring (hot): `world/world.gd` (create FxField in `_ready`, `var fx_field: FxField`)
- Test: `tests/unit/test_fx_field.gd`
- Doc: `docs/review/WEBGL_WARNINGS.md`

**Interfaces:**
- Produces: `class_name FxField extends MultiMeshInstance3D`; `const CAPACITY := 192`;
  `const KINDS := {&"poof": {...}, &"hit": {...}, &"sparkle": {...}, &"dust": {...}, &"coin": {...}}`;
  `func burst(kind: StringName, pos: Vector3) -> void`; `func active_count() -> int`;
  `func instance_snapshot() -> PackedFloat32Array` (tests); `const CELLS := [&"puff", &"spark", &"star", &"dust"]`.

- [ ] **Step 1: Atlas tool.** `tools/make_fx_atlas.gd` (SceneTree script, run with
  `"$GODOT" --headless --path . -s res://tools/make_fx_atlas.gd`) writes `art/fx/fx_atlas.png`, 256×64, four 64 px
  cells drawn into an `Image.create_empty(256, 64, false, Image.FORMAT_RGBA8)` in `Palette.color(&"apron_white")` with
  alpha falloff: puff = soft disc (alpha `1 - r²`), spark = 4-point diamond, star = 5-point star (filled polygon by
  point-in-polygon test per pixel), dust = small soft disc at 60% radius. Colour comes per instance; the texture is
  white so `check_palette` only sees `apron_white` (alpha ignored per the existing rule; confirm in
  `check_palette`).

- [ ] **Step 2: Shader** `art/fx/fx.gdshader`:

  ```glsl
  shader_type spatial;
  render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
  uniform sampler2D atlas : source_color, filter_linear_mipmap;
  varying float v_cell;
  void vertex() {
  	float s = length(MODEL_MATRIX[0].xyz);
  	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
  	v_cell = INSTANCE_CUSTOM.x;
  }
  void fragment() {
  	vec2 uv = vec2((UV.x + v_cell) * 0.25, UV.y);
  	vec4 t = texture(atlas, uv);
  	ALBEDO = COLOR.rgb * t.rgb;
  	ALPHA = COLOR.a * t.a;
  }
  ```

- [ ] **Step 3: Write the failing tests.**

  ```gdscript
  extends GutTest

  var f: FxField

  func before_each() -> void:
  	f = FxField.new()
  	add_child_autofree(f)

  func test_burst_fills_quads() -> void:
  	f.burst(&"poof", Vector3.ZERO)
  	assert_eq(f.active_count(), FxField.KINDS[&"poof"].count)

  func test_life_ends_quads() -> void:
  	f.burst(&"hit", Vector3.ZERO)
  	for i in 120:
  		f.step(1.0 / 60.0)
  	assert_eq(f.active_count(), 0)

  func test_capacity_never_exceeded_oldest_replaced() -> void:
  	for i in 100:
  		f.burst(&"poof", Vector3(i, 0, 0))
  	assert_eq(f.active_count(), FxField.CAPACITY)
  	assert_eq(f.multimesh.instance_count, FxField.CAPACITY)

  func test_one_multimesh_with_custom_aabb() -> void:
  	assert_eq(f.find_children("*", "GeometryInstance3D", true, false).size(), 0)
  	assert_true(f.custom_aabb.has_volume())

  func test_deterministic() -> void:
  	var g := FxField.new()
  	add_child_autofree(g)
  	for x in [f, g]:
  		x.burst(&"sparkle", Vector3(1, 0, 2))
  		x.burst(&"dust", Vector3(0, 0, 0))
  		for i in 10:
  			x.step(1.0 / 60.0)
  	assert_eq(f.instance_snapshot(), g.instance_snapshot())

  func test_listens_to_fx_requested() -> void:
  	EventBus.fx_requested.emit(&"coin", Vector3.ZERO)
  	assert_eq(f.active_count(), FxField.KINDS[&"coin"].count)

  func test_unknown_kind_is_ignored() -> void:
  	f.burst(&"nope", Vector3.ZERO)
  	assert_eq(f.active_count(), 0)
  ```

- [ ] **Step 4: Implement `art/fx/fx_field.gd`.** Key parts:

  ```gdscript
  class_name FxField
  extends MultiMeshInstance3D
  ## Every particle in the game in one draw (S5 spec 5.1, D-214): camera-facing quads, CPU-animated in _process. No
  ## randomness: each kind has a fixed direction set, rotated by a per-burst counter. Visual only.

  const CAPACITY := 192
  const CELLS: Array[StringName] = [&"puff", &"spark", &"star", &"dust"]
  ## count, cell, colour (Palette name), speed (m/s), up (m/s), gravity (m/s²), life (s), size (m).
  const KINDS := {
  	&"poof": {"count": 8, "cell": 0, "color": &"enemy_snout", "speed": 2.2, "up": 1.5, "gravity": 2.0, "life": 0.45, "size": 0.55},
  	&"hit": {"count": 3, "cell": 1, "color": &"warm_white", "speed": 3.0, "up": 1.0, "gravity": 0.0, "life": 0.18, "size": 0.35},
  	&"sparkle": {"count": 6, "cell": 2, "color": &"gold", "speed": 1.6, "up": 2.4, "gravity": 3.0, "life": 0.6, "size": 0.4},
  	&"dust": {"count": 2, "cell": 3, "color": &"dirt", "speed": 0.6, "up": 0.4, "gravity": 0.0, "life": 0.35, "size": 0.35},
  	&"coin": {"count": 4, "cell": 2, "color": &"gold", "speed": 1.2, "up": 2.0, "gravity": 3.0, "life": 0.5, "size": 0.32},
  }
  ```

  All colour names exist in `art/palette/palette.gd`. The poof keeps the spec's "snout pink to white" by lerping its
  colour to `apron_white` over life. Arrays sized `CAPACITY`: `_pos`,
  `_vel`, `_life`, `_age`, `_kind_idx`, `_alive`, plus `_order` (a ring index for replacement) and `_burst_n`. A burst
  of n takes n free slots; if fewer are free it takes the oldest live slots (`_age` largest; ties by slot index).
  Direction for particle i of burst b: angle `TAU * (i + 0.5) / n + 0.618 * b`, horizontal `speed`, vertical `up`.
  `step(dt)` integrates, kills at `life`, and writes `multimesh.set_instance_transform` (basis scaled by
  `size * (sin(PI * t) * 0.6 + 0.4)` with `t = age / life`; zero scale when dead), `set_instance_color` (alpha
  `1 - t*t`) and `set_instance_custom_data(i, Color(cell, 0, 0, 0))`. `_process(delta)` calls `step(delta)` and skips
  all work when `active_count() == 0`. In `_init`: MultiMesh `TRANSFORM_3D`, `use_colors = true`,
  `use_custom_data = true`, `instance_count = CAPACITY`, mesh a 1×1 `QuadMesh`, `material_override` a
  `ShaderMaterial` with the shader and atlas, `custom_aabb = AABB(Vector3(-30, -1, -30), Vector3(60, 12, 60))`,
  `cast_shadow = SHADOW_CASTING_SETTING_OFF`. `_ready` connects `EventBus.fx_requested` to `burst`.

- [ ] **Step 5: World wiring (patch).** In `world/world.gd` add `var fx_field: FxField` and, at the end of `_ready()`:

  ```gdscript
  	fx_field = FxField.new()
  	fx_field.name = "FxField"
  	add_child(fx_field)
  ```

- [ ] **Step 6: Capture option.** In `tests/sim/capture.gd`, `--fx=<kind>`: after the scene is ready, emit
  `EventBus.fx_requested(kind, <hero position>)` and take the shot 0.1 s later. Shots:
  `tools/shots.sh docs/review/media/s5/task04` plus one `--fx=` shot per kind into the same folder.

- [ ] **Step 7: WebGL warnings.** On a debug web export of `main` (not this branch), run Playwright Chromium for 60 s of
  night 1 with `CONSOLE_OUT`, and capture the two warnings (`bindBuffer: element array buffers can not be bound to a
  different target`, `bufferSubData: no buffer`) with their timestamps. Bisect by URL scene (`ui/debug/debug_scenes.gd`
  scenes) or by temporarily hiding node groups in a scratch build to find the first draw that triggers them. Write
  `docs/review/WEBGL_WARNINGS.md`: what triggers them, whether it is our code or the engine, and whether a one-file fix
  exists. Do not change game code in this step; report the finding (the main session decides the fix).

- [ ] **Step 8: Run** unit, sim, `tools/baseline_diff.sh`, `"$GODOT" --headless --path . -s res://tools/make_fx_atlas.gd`
  twice and `git diff --exit-code art/fx/fx_atlas.png` (deterministic).
- [ ] **Step 9: Commit** and report the wiring patch.

### Task 5: Reactions and screen shake

**Spec:** §5.2, D-214.

**Files:**
- Create: `world/fx/reactions.gd`
- Modify: `world/camera_rig.gd`, `actors/enemy/boar.gd` (hit burst), `world/build_spots/build_spot.gd` (dust every 4th
  paid tick), `actors/hero/hero.gd` (running dust in `_process`), `components/carry_stack.gd` (squash on
  `steak_picked`), `world/traveler_spawner.gd` + `actors/traveler/traveler.gd` (`hop()` on a sale), `ui/hud/hud.gd`
  (diner bar flash, lane-arrow punch), `ui/hud/card_strip.gd` (cell pop on `card_picked`), `tests/sim/capture.gd`
  (sets `Balance.ui.shake_enabled = false`)
- Wiring (hot): `balance/ui_tuning.gd`, `world/world.gd` (create Reactions)
- Test: `tests/unit/test_reactions.gd`, `tests/unit/test_camera_rig.gd`

**Interfaces:**
- Consumes: `EventBus.fx_requested`, `FxField`.
- Produces (ui_tuning, wiring):

  ```gdscript
  ## S5 Task 5 (spec 5.2): reactions. Screen shake per kind; carry squash; traveler hop; bar flash; arrow punch; strip pop;
  ## hero dust interval; build dust every Nth paid tick.
  @export var shake_enabled := true
  @export var shake_fell_amp := 0.3
  @export var shake_fell_time := 0.4
  @export var carry_squash := 1.06
  @export var carry_squash_time := 0.12
  @export var traveler_hop_m := 0.25
  @export var traveler_hop_time := 0.2
  @export var bar_flash_time := 0.15
  @export var arrow_punch_scale := 1.3
  @export var arrow_punch_time := 0.2
  @export var strip_pop_scale := 1.25
  @export var strip_pop_time := 0.15
  @export var hero_dust_interval_s := 0.35
  @export var build_dust_every := 4
  ```

  and change `shake_time` from 0.15 to 0.12 (spec: diner damaged 0.12 s, 0.12 m).
- Produces: `class_name Reactions extends Node` (listens: `enemy_killed` → `poof` at position; `steak_sold` → `coin` at
  `MapLayout.to3(MapLayout.COUNTER, 1.2)`; `gold_changed` with `delta > 0` → `sparkle` at
  `MapLayout.to3(MapLayout.GOLD_PILE, 0.6)`; `build_completed` → `sparkle` at the spot
  (`MapLayout.to3(MapLayout.spot_position(id), 1.0)`); `phase_changed(DAWN)` → `sparkle` at `Vector3(0, 3.5, 0)`).
  `Traveler.hop()`. `CameraRig.shake(amp: float, time: float, respect_cooldown: bool)`.

- [ ] **Step 1: Write the failing tests.** `tests/unit/test_reactions.gd` builds `Main.create()` (auto_start false),
  `start_new_game(71)`, `watch_signals(EventBus)`, and for each row asserts the observable result:
  - `EventBus.enemy_killed.emit(0, &"north", Vector3(1,0,1))` → `fx_requested(&"poof", Vector3(1,0,1))`;
  - `boar.take_hit(1.0)` on a `debug_spawn("north")` Boar → `fx_requested(&"hit", …)`;
  - `steak_sold` → `&"coin"`; `gold_changed(+)` → `&"sparkle"`; `build_completed` → `&"sparkle"`; `phase_changed(DAWN)`
    → `&"sparkle"`;
  - four paid ticks on a spot (`TestHelpers.walk_in` + enough gold, or call `spot._on_tick()` four times with gold) →
    exactly one `&"dust"`;
  - the hero moving for 0.8 s (`hero.input.set_move(Vector2.RIGHT)`) → at least 2 `&"dust"`;
  - `steak_picked` → `hero.carry_stack.scale.y` above 1.0 within 0.05 s;
  - a sale → the buying traveler's `visual.position.y` above its rest within 0.1 s (drive one traveler to the service
    point as `tests/unit/test_traveler*.gd` does);
  - `diner_damaged` → `hud.diner_bar.modulate` is `Palette.color(&"enemy_red")`, back to white after 0.2 s;
  - `wave_incoming` → `hud.arrows.main.scale` above 1.0 within 0.05 s;
  - `card_picked` → `hud.card_strip.pop_scale(id)` above 1.0.
  In `test_camera_rig.gd`: update `test_shake_has_cooldown` to the new duration (`Balance.ui.shake_time` still names it);
  add `test_fell_shake_ignores_cooldown` (`damage_diner(1e9)` emits damaged then fell → `shake_count == 2`,
  `camera_rig.shake_amp_now() >= Balance.ui.shake_fell_amp * 0.9`); add `test_shake_disabled`
  (`shake_enabled = false` → `shake_count` unchanged and camera at rest); add `test_damaged_after_fell_is_full_strength`
  (fell shake, wait `shake_fell_time + 0.1`, wait out the cooldown, `damage_diner(5.0)`, then right away
  `shake_amp_now()` ≈ `Balance.ui.shake_amp`); keep `test_shake_decays_to_rest` with `shake_fell_time`. Run — FAIL.

- [ ] **Step 2: Camera rig.** Replace the shake with:

  ```gdscript
  var _shake_time := 0.0
  var _shake_amp := 0.0

  func _ready() -> void:
  	# … existing …
  	EventBus.diner_fell.connect(func(): shake(Balance.ui.shake_fell_amp, Balance.ui.shake_fell_time, false))

  ## Overlapping shakes merge: the larger amplitude and the longer remaining time (S5 spec 5.2).
  func shake(amp: float, time: float, respect_cooldown: bool) -> void:
  	if not Balance.ui.shake_enabled:
  		return
  	if respect_cooldown:
  		if _cooldown > 0.0:
  			return
  		_cooldown = Balance.ui.shake_cooldown
  	var idle := _shake_left <= 0.0
  	if idle:
  		_shake_amp = 0.0
  		_shake_time = 0.0
  	_shake_amp = maxf(_shake_amp, amp)
  	_shake_left = maxf(_shake_left, time)
  	_shake_time = maxf(_shake_time, time)
  	shake_count += 1

  func shake_amp_now() -> float:
  	return _shake_amp * maxf(_shake_left, 0.0) / _shake_time if _shake_time > 0.0 else 0.0
  ```

  `_on_diner_damaged` calls `shake(Balance.ui.shake_amp, Balance.ui.shake_time, true)`. `_process` uses
  `shake_amp_now()` in place of `Balance.ui.shake_amp * k`. `_on_state_restored` also zeroes `_shake_amp` and `_shake_time`.

- [ ] **Step 3: Local emitters.**
  - Boar `take_hit`, inside `if alive:`: `EventBus.fx_requested.emit(&"hit", global_position + Vector3(0, AIM_HEIGHT, 0))`.
  - BuildSpot `_on_tick`: count successful paid ticks in `var _paid_ticks := 0` (reset in `refresh()` when
    `paid == 0`); emit `&"dust"` at `global_position` when `_paid_ticks % Balance.ui.build_dust_every == 0`.
  - Hero: `_process(delta)`: while `is_moving()`, accumulate; every `hero_dust_interval_s` emit `&"dust"` at
    `global_position`. Visual only; no gameplay state.
- [ ] **Step 4: Reactions node and UI reactions** per the Interfaces list; tweens only on Visual or Control nodes,
  durations from `ui_tuning`. Traveler `hop()`: tween `visual.position.y` up `traveler_hop_m` and back over
  `traveler_hop_time`; TravelerSpawner calls `hop()` on the traveler it sold to, right after the sale. `hop()` keeps its tween in a var,
  kills it before starting a new one, and `on_release()` and `begin()` kill it and reset `visual.position.y` to rest (a
  pooled traveler must never keep the offset).
- [ ] **Step 5: Wiring (patch):** `world/world.gd` `_ready()` after the FxField: `var reactions := Reactions.new();
  reactions.name = "Reactions"; add_child(reactions)`. `ui_tuning.gd` per Interfaces.
- [ ] **Step 6: Run** unit, sim, `tools/baseline_diff.sh`; shots `tools/shots.sh docs/review/media/s5/task05`.
- [ ] **Step 7: Commit**, report the patch.

### Task 6: UI motion (banner, card entrance)

**Spec:** §5.3.

**Files:**
- Modify: `ui/hud/hud.gd` (banner slide), `ui/card_pick/card_pick_overlay.gd` (card rise + stagger)
- Wiring (hot): `balance/ui_tuning.gd`
- Test: `tests/unit/test_hud.gd` (or the existing banner test file), `tests/unit/test_card_pick_overlay.gd`

**Interfaces:**
- Produces (ui_tuning): `banner_slide_px := 24.0`, `banner_in_s := 0.15`, `card_rise_px := 40.0`, `card_rise_s := 0.18`,
  `card_stagger_s := 0.06`, `button_press_scale := 0.94` (used in Task 8).

- [ ] **Step 1: Failing tests.**
  - `test_card_entrance_fits_input_guard`: `Balance.ui.card_stagger_s * 2 + Balance.ui.card_rise_s <= Balance.ui.card_input_guard_s`.
  - Overlay: after `show_offer([a, b, c])`, panel 2's `modulate.a` is 0 at t = 0 and 1 at t = 0.35 s; its final
    position equals `layout(...)[2].position`; a tap at t = 0.6 s on a panel's final rect chooses it (the hit-test uses
    the final rects, not the animated positions).
  - HUD: a banner's panel starts `banner_slide_px` above its rest (`offset_top`/`offset_bottom`) and reaches rest within
    `banner_in_s + 0.05`; the label (`hud.banner.modulate.a`) fades from 0 to 1 over `banner_in_s`. The existing
    `tests/unit/test_hud.gd:183-184` assertion on `banner_panel.modulate.a` stays unchanged and must still pass.
- [ ] **Step 2: Implement.** Cards: tweens on each panel Control's `position` and `modulate`; `_rects` stay the final
  layout. Banner: tween the panel's `offset_top`/`offset_bottom` for the slide and `banner.modulate.a` (the label, not
  the panel) for the fade, because `_tick_banner` writes `banner_panel.modulate.a` every frame (`ui/hud/hud.gd:261,269`).
- [ ] **Step 3: Run** unit, sim, baseline; shots `docs/review/media/s5/task06` (`cardpick` at 0.1 s and 0.4 s: add
  `--wait=<s>` to capture if missing).
- [ ] **Step 4: Commit**, report the patch.

### Task 7: Stall attribution, warm-up, boot fade, perf checkpoint

**Spec:** §5.4, §1.6, D-215, D-219.

**Files:**
- Create: `world/warmup.gd`, `ui/boot_fade.gd`
- Modify: `components/occluder_fade.gd` (expose `fade_material_for_warmup() -> Material` returning one faded copy)
- Wiring (hot): `world/main.gd` (`_boot`), `balance/ui_tuning.gd` (`boot_fade_out_s := 0.3`)
- Test: `tests/unit/test_warmup.gd`, `tests/unit/test_resume.gd` (unchanged; must still pass)
- Media: `docs/review/media/s5/perf_p2/`

**Interfaces:**
- Produces: `class_name Warmup extends Node3D`; `signal finished`; `func run(main: Main) -> void` (a coroutine: builds the
  temporary nodes in front of `main.camera_rig.camera`, awaits `get_tree().process_frame` three times, frees them,
  calls `main.audio_director.register_streams()`, emits `finished`); `var built_count := 0` (tests).
- Produces: `class_name BootFade extends CanvasLayer` (layer 90): `func fade_out() -> void`.

Steps 1–4 implement the warm-up; Step 5 attributes the stall before anything is committed.

- [ ] **Step 1: Failing tests** (`tests/unit/test_warmup.gd`):
  - with a `Main.create()` and a hand-made Warmup: `GameState.to_dict()` is equal before and after
    `await warmup.run(main)`; every pool's
    `size` is unchanged; `warmup.get_child_count() == 0` after `finished`; `built_count` ≥ 9 (Boar, steak MultiMesh,
    knife, arrow, FX MultiMesh, tower L1, fence L1, the character roles, the diner fade material). (Rng needs no check:
    `Rng.stream` is pure, and the existing global-rand ban test covers the rest.)
  - it finishes under `--headless` (the test itself is the proof);
  - `_boot()` without a Warmup completes synchronously: with `main.save_store` a temp `SaveStore.with_dir` and no
    warmup, `main._boot()` then on the next line `not main.phase_controller.snapshot.is_empty()` and
    `main.world.wave_director.state != WaveDirector.State.IDLE`.
- [ ] **Step 2: Implement Warmup.** Place nodes at `camera.global_transform.origin - camera.global_transform.basis.z *
  6.0` spread 1 m apart, inside the frustum. Use the real scenes: `Boar.VISUAL_SCENE`, the knife and arrow projectile
  scenes from `art/pickups/`, `art/env/tower_l1.tscn`, `art/env/fence_l1.tscn`, the role visuals under
  `art/characters/` (hero, archer, tank, traveler), a MultiMeshInstance3D with `PileMesh.steak_mesh()` and the same
  instance format as `PickupField` (read `art/pickups/pickup_field.gd`), a MultiMeshInstance3D with the FxField quad,
  shader material and format (one instance per cell), and a cube MeshInstance3D with
  `world.occluder_fade.fade_material_for_warmup()`. Read each source file to match the material and format exactly; do
  not touch `PickupField` or any pool.
- [ ] **Step 3: Boot fade + `_boot` (patch).** `BootFade`: a full-rect `ColorRect` in `Palette.color(&"night_sky")`
  (a palette name), alpha 1; `fade_out()`
  tweens alpha to 0 over `boot_fade_out_s` and frees itself. In `world/main.gd`:

  ```gdscript
  var warmup: Warmup
  var boot_fade: BootFade

  ## S3 (D-176, D-177): resume the saved run, or start fresh. S5 (D-215): when a Warmup exists, draw every first-use
  ## visual under the boot fade first; without one (tests) this stays synchronous.
  func _boot() -> void:
  	if warmup != null:
  		await warmup.run(self)
  	else:
  		audio_director.register_streams()
  	if debug_fresh_start:
  		save_store.wipe()
  		phase_controller.start_new_game()
  	else:
  		var r := save_store.read()
  		if r.ok:
  			phase_controller.resume_from(r.state)
  		else:
  			phase_controller.start_new_game()
  	if boot_fade != null:
  		boot_fade.fade_out()
  ```

  In `_ready()`'s `auto_start` block, before `_boot.call_deferred()`, unless `UrlFlags.get_flag("warmup") == "0"`:
  create `boot_fade` (add_child) and `warmup` (add_child). With `?warmup=0`, still create the boot fade (so A and B
  differ only in the warm-up).
- [ ] **Step 4: Run** unit (including `test_resume.gd` untouched), sim, baseline.
- [ ] **Step 5 (run before committing anything): Attribution A/B.** Build one profile web export of Steps 1–4 and run
  `export/perf_night3.sh` three times with `?warmup=0` and three times without (add a `QUERY` env var to
  `perf_night3.sh` that is appended to both `to=/` targets as `to=/%3F<query>`; check `seed_save.html` passes it
  through). Record night-3 `avg_fps` and `worst_ms` for all six runs in `docs/review/media/s5/perf_p2/attribution.md`.
  If the warmed median `worst_ms` is not lower than the unwarmed one, stop and report with the numbers, without
  committing: the main session decides the bisect (spec §5.4).

- [ ] **Step 6: Perf checkpoint** (idle Mac, D-209): profile build of this branch vs a profile build of `main`, 3 runs
  each with `export/perf_night3.sh`: night-3 `avg_fps`, night-3 `worst_ms`, day-3 `avg_fps` (from `day_peak.png`),
  plus `cpu_idle_before/after`. Also read desktop draw calls with FX active (a headless-off desktop capture with
  `--fx=poof` repeated: `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`;
  expect S4's 48 + 1). Write `docs/review/media/s5/perf_p2/README.md` with the readings and medians.
  Gates: night-3 median `avg_fps` ≥ 58; night-3 median `worst_ms` < 60; day-3 median ≥ main's median − 1. If a gate
  fails: report the numbers; do not tune (the main session applies spec §5.4's fallback or the §11 FX cuts).
- [ ] **Step 7: Commit**, report the patch and the perf table.

---

## Phase P3: UI (`s5/p3-ui`)

### Task 8a: Icon cells, FocusPause signal-only, pause reasons

**Spec:** §7 (icon atlas), §3 row "Who owns pausing?", D-216, D-218.

**Files:**
- Modify: `tools/render_icons.gd`, `art/icons/atlas.gd`, `art/icons/atlas.png` (+ remove `art/icons/steak.png*`),
  `tests/unit/test_icons.gd`, `world/focus_pause.gd` (signal-only), `tests/unit/test_focus_pause.gd` (rewritten)
- Wiring (hot): `world/main.gd` (pause reasons)
- Test: `tests/unit/test_pause_reasons.gd`, `tests/unit/test_icons.gd`

**Interfaces:**
- Produces: `IconAtlas.NAMES` = the current 11 minus `&"steak"` (10 names, unchanged order otherwise);
  `IconAtlas.SHAPES` = `[&"backing", &"disc", &"gear", &"stick_ring", &"stick_knob", &"guide_arrow"]` (16 cells: the
  atlas stays 4×4 at 512×512). The ghost joystick is drawn later from `stick_ring` + `stick_knob` + `disc`; there is
  no `ghost_stick` cell.
- Produces (Main): `func add_pause_reason(r: StringName) -> void`, `func remove_pause_reason(r: StringName) -> void`,
  `var pause_reasons := {}`.

- [ ] **Step 1: Icon cells.** In `tools/render_icons.gd`, remove the steak icon (its PNG render and its NAMES entry) and
  add four shapes to `_shape()` (`tools/render_icons.gd:107`), analytic with the same 4×4 supersampling, each inset
  `IconAtlas.PAD`, each remapped with its own palette list at line 98 (replace the inline ternary with a
  `const SHAPE_PALETTES := {&"backing": [&"diner_cream", &"ink"], &"disc": [&"ink"], &"gear": [&"ink", &"warm_white"],
  &"stick_ring": [&"ink", &"warm_white"], &"stick_knob": [&"warm_white"], &"guide_arrow": [&"gold", &"ink"]}`):
  - gear: an `ink` cog, 8 teeth, with a `warm_white` hub hole;
  - stick_ring: an `ink` disc at 25% alpha with a 6 px `warm_white` rim;
  - stick_knob: a `warm_white` disc at 80% alpha;
  - guide_arrow: a `gold` down-pointing arrow with a 4 px `ink` outline.
  Regenerate the atlas (`--atlas-only` per the file header), delete `art/icons/steak.png` and its `.import`. Update
  `tests/unit/test_icons.gd`: `NAMES.size() == 10`, the extra list without `steak`, and a check that each new shape
  cell is not blank. `check_palette` and `check_texture_sizes` must pass (the atlas stays 512×512).

- [ ] **Step 2: Failing tests** (`tests/unit/test_pause_reasons.gd`, `Main.create()` each; a settings panel does not
  exist yet, so tests use `main.add_pause_reason(&"settings")` / `remove_pause_reason(&"settings")` directly):
  - focus out → paused; add `settings` → still paused; focus in → still paused; remove `settings` → unpaused;
  - add `settings`, focus out, remove `settings` → still paused; focus in → unpaused;
  - focus out, then `main.focus_pause.free()` → unpaused (`focus` cleared on `tree_exiting`);
  - a test sets `get_tree().paused = true` directly with an empty reason set: Main does not overwrite it (no
    reason change happened);
  - focus out while `settings` is held still suspends audio (`audio_director.suspended`).
  Rewrite `tests/unit/test_focus_pause.gd`: standalone FocusPause emits `changed(true)` on focus-out / hidden and
  `changed(false)` on focus-in / visible, never touches `get_tree().paused`, keeps `PROCESS_MODE_ALWAYS`; the pause
  behaviour tests move to `test_pause_reasons.gd`; keep `test_main_wires_focus_pause_first`.
  Run — FAIL.

- [ ] **Step 3: FocusPause signal-only.** Remove every `get_tree().paused` write and `_paused_by_focus`; keep
  `focus_paused` and `changed` from Task 3.

- [ ] **Step 4: Main (patch).**

  ```gdscript
  var pause_reasons := {}

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

  func _on_focus_changed(p: bool) -> void:
  	if p:
  		add_pause_reason(&"focus")
  	else:
  		remove_pause_reason(&"focus")
  ```

  In `_ready()` after the FocusPause block: `focus_pause.changed.connect(_on_focus_changed)` and
  `focus_pause.tree_exiting.connect(remove_pause_reason.bind(&"focus"))`.

- [ ] **Step 5: Run** unit, sim, baseline; shots `docs/review/media/s5/task08a` (the `hud` shot only; nothing else
  changes visibly).
- [ ] **Step 6: Commit**, report the patch.

### Task 8b: Settings layer, gear, panel, New game

**Spec:** §7, D-216, D-217. Review Focus 4.

**Files:**
- Create: `ui/settings/settings_layer.gd`
- Modify: `ui/hud/hud.gd` (`arrow_rect()` public, `reserved_rect: Callable`), `ui/debug/debug_overlay.gd` (R →
  `fresh_start`), `tests/sim/capture.gd` (`--settings=1`)
- Wiring (hot): `world/main.gd` (settings layer, `fresh_start`), `balance/ui_tuning.gd`
- Test: `tests/unit/test_settings_layer.gd`

**Interfaces:**
- Consumes: `Main.add_pause_reason` / `remove_pause_reason` (8a), `IconAtlas` `gear` and `backing` (8a),
  `AudioDirector.set_muted` / `muted` (3b), `SettingsStore` (2), `UiTuning.button_press_scale` (6).
- Produces (Main): `func fresh_start() -> void`, `var settings_layer: SettingsLayer`.
- Produces: `class_name SettingsLayer extends CanvasLayer` (layer 25): signals `opened`, `closed`,
  `mute_toggled(muted: bool)`, `new_game_requested`; `func gear_rect() -> Rect2`; `func panel_open() -> bool`;
  `func open() -> void`; `func close() -> void`; `func set_muted_display(m: bool) -> void`; `var confirm_armed := false`;
  `func button_rects() -> Dictionary` (`&"sound"`, `&"new_game"`, `&"close"`).
- Produces (Hud): `func arrow_rect() -> Rect2` (was `_arrow_rect`), `var reserved_rect: Callable`.
- Produces (ui_tuning): `gear_px := 72.0`, `gear_margin := 16.0`, `settings_panel_size := Vector2(520, 420)`,
  `settings_button_h := 96.0`, `new_game_confirm_s := 3.0`.

- [ ] **Step 1: Failing tests.** In each test, inject a store so `fresh_start` and mute have one:
  `main.settings_store = SettingsStore.with_dir("user://test_settings_layer")` (wiped first),
  `main.save_store = SaveStore.with_dir("user://test_settings_layer_save")`, then
  `main.audio_director.setup(main.settings_store)`.
  - a `InputEventScreenTouch` press + release at `gear_rect().get_center()` opens the panel and the joystick stays
    inactive (`main.joystick.is_active() == false`);
  - Sound toggles `audio_director.muted` and the displayed state;
  - New game: first tap arms (`confirm_armed`); a second tap before `card_input_guard_s` does nothing; a second tap
    between `card_input_guard_s` and `new_game_confirm_s` emits `new_game_requested`; after `new_game_confirm_s` the arm
    expires;
  - `fresh_start()` wipes the save store (temp `SaveStore.with_dir`), starts a new game (`GameState.day == 1`, phase
    NIGHT), closes the panel, removes `settings`, and leaves `settings_store.muted` unchanged;
  - Close closes and unpauses; Close while unfocused (`focus` held) leaves the tree paused;
  - Review Focus 4: card overlay open via `EventBus.card_offered.emit([...])` inside its guard; gear tap opens the panel,
    no `card_chosen` emitted (`watch_signals(EventBus)`); close; overlay `accepting()` after its guard;
  - in a `SubViewport` resized from 720×1280 to 1280×720 with the panel open, every `button_rects()` rect and
    `gear_rect()` lie inside the viewport (the notch-inset version of this check is in Task 9);
  - the HUD's `arrow_rect()` top is below `gear_rect().end.y`.
  Run — FAIL.

- [ ] **Step 2: Main (patch).**

  ```gdscript
  var settings_layer: SettingsLayer

  ## S5 D-217: wipe the save, start a new game, close the settings panel. Settings (mute, guide) are kept.
  func fresh_start() -> void:
  	if save_store != null:
  		save_store.wipe()
  	if settings_layer != null and settings_layer.panel_open():
  		settings_layer.close()
  	remove_pause_reason(&"settings")
  	phase_controller.start_new_game()
  ```

  In `_ready()`, after the card overlay is added (so its `_input` runs before the overlay's and the joystick's):
  create `settings_layer`, `add_child`, connect `opened → add_pause_reason.bind(&"settings")`,
  `closed → remove_pause_reason.bind(&"settings")`, `mute_toggled → audio_director.set_muted`,
  `new_game_requested → fresh_start`; call `settings_layer.set_muted_display(audio_director.muted)`; set
  `hud.reserved_rect = settings_layer.gear_rect`.

- [ ] **Step 3: SettingsLayer.** Built in code, `process_mode = PROCESS_MODE_ALWAYS`. The gear is one Control drawing
  `IconAtlas` `gear` at `gear_rect()` (top-right: `vp.x - insets.right - gear_margin - gear_px`,
  `insets.top + gear_margin`). The panel is one custom-draw Control that draws the panel and the three button
  backings from `IconAtlas` `backing` cells (no `draw_style_box`, no PanelContainer), with plain Labels (no stylebox)
  on top for the texts; texts through
  `tr()`: "Sound: On" / "Sound: Off", "New game", "Tap again to erase", "Close". `_input` hit-tests `gear_rect()` and,
  when open, `button_rects()`, with the `_owned` finger pattern; a press anywhere while open is consumed (so the game
  behind never gets it). On each press: `EventBus.sfx_requested.emit(&"click")` and a press scale tween to
  `button_press_scale` and back. Relayout on `get_viewport().size_changed`. The New game arm accumulates `delta` in `_process` (the layer is
  `PROCESS_MODE_ALWAYS`, so it counts while paused); never wall-clock time (tests run with `--fixed-fps`).

- [ ] **Step 4: HUD + debug.** `Hud._arrow_rect` → public `arrow_rect()` (update every caller); include
  `reserved_rect.call().end.y` (when set) in the `hud_bottom` max. Debug overlay R: `_main.fresh_start()`.

- [ ] **Step 5: Run** unit, sim, baseline; shots `docs/review/media/s5/task08b` plus `--settings=1` (panel open) at
  720×1280 and 1280×720.
- [ ] **Step 6: Commit**, report the patch.

### Task 9: Joystick skin, HUD safe-area pass, label dimming

**Spec:** §7 (joystick, HUD, labels), D-216.

**Files:**
- Modify: `ui/joystick/joystick.gd` (`_draw` from atlas cells), `ui/hud/safe_area.gd`
  (`static var override_for_tests: Dictionary = {}`; `insets()` returns a copy of it when it is not empty),
  `ui/hud/hud.gd` (safe-area layout, card-strip gap, label dimming), `ui/world_label/world_label.gd`
  (`add_to_group(&"world_labels")` in `_ready`), `components/occluder_fade.gd`
  (`func owns_label(l: Node) -> bool: return get_parent().is_ancestor_of(l)`: `_labels` is filled only while faded,
  so it cannot answer this), `tests/sim/capture.gd` (`--insets=t,r,b,l` sets `SafeArea.override_for_tests`)
- Wiring (hot): `balance/ui_tuning.gd` (`strip_gap_px := 12.0`, `label_dim_alpha := 0.15`, `label_dim_grow_px := 8.0`,
  `label_dim_hz := 4.0`)
- Test: `tests/unit/test_hud_layout.gd`, `tests/unit/test_joystick.gd`

- [ ] **Step 1: Failing tests.**
  - For insets set through `SafeArea.override_for_tests`: `{top: 0, …}`, `{top: 88, bottom: 68, left: 0, right: 0}`
    (notch portrait) and `{top: 0, bottom: 42, left: 88, right: 88}` (notch landscape, SubViewport 1280×720): every HUD
    block's global rect (coin and gold label, the top column, the card strip, the gear from the settings layer) lies
    inside the safe rect, after a `size_changed` relayout. With the settings panel open in the landscape case, every
    `button_rects()` rect lies inside the safe rect (Review Focus 5).
  - The card strip's top is `strip_gap_px` below `max(coin row bottom, diner bar bottom)` when the strip has cards.
  - A WorldLabel placed so its screen point falls inside the top column's rect gets `modulate.a == label_dim_alpha`
    within 0.3 s; moved away, 1.0; the diner board label (owned by OccluderFade) is never changed by the dimmer.
  - Joystick `_draw` issues texture draws only (assert by checking the joystick script source has no `draw_circle`,
    and that an active stick draws: a smoke test that `queue_redraw` + one frame produces no error).
- [ ] **Step 2: Implement.** The dimmer runs in `Hud._process` at `label_dim_hz`, walks
  `get_tree().get_nodes_in_group(&"world_labels")`, skips labels OccluderFade owns, unprojects with `_camera`, and
  snaps `modulate.a` (keep rgb). Joystick: ring = `stick_ring` cell at radius `joystick_radius_px`, knob =
  `stick_knob` at 0.45 r.
- [ ] **Step 3: Run** unit, sim, baseline; shots `docs/review/media/s5/task09` incl. `hud` at the three inset sets
  (capture option `--insets=t,r,b,l` if missing).
- [ ] **Step 4: Commit**, report the patch.

---

## Phase P4: Onboarding (`s5/p4-guide`)

### Task 10: Edge clamp, Guide rules, Guide node, pointer

**Spec:** §6, D-213. Review Focus 5.

**Files:**
- Create: `core/edge_clamp.gd`, `core/guide_rules.gd`, `ui/guide/guide.gd`, `art/fx/pointer.tscn` (+ a small
  `art/fx/pointer_mesh.gd` builder if no suitable mesh exists)
- Modify: `ui/hud/hud.gd` (`_place_arrows` uses `EdgeClamp`)
- Wiring (hot): `balance/ui_tuning.gd`:

  ```gdscript
  ## S5 Task 10 (spec 6): the Guide. Evaluation period, extra inset of its edge rect, world pointer height and bounce,
  ## the walk that clears `move`, the ghost stick's swipe loop.
  @export var guide_eval_s := 0.25
  @export var guide_rect_inset_px := 40.0
  @export var guide_pointer_h := 2.2
  @export var guide_bounce_m := 0.25
  @export var guide_bounce_hz := 1.5
  @export var guide_move_m := 2.0
  @export var guide_swipe_s := 1.0
  ```
- Test: `tests/unit/test_edge_clamp.gd`, `tests/unit/test_guide_rules.gd`, `tests/unit/test_guide.gd`

**Interfaces:**
- Produces: `EdgeClamp.clamp_to_rect(p: Vector2, rect: Rect2) -> Dictionary` → `{inside: bool, position: Vector2,
  rotation: float}` (rotation 0 when inside; else `dir.angle() - PI / 2`, matching the HUD arrow).
- Produces: `GuideRules.evaluate(s: Dictionary) -> Dictionary` → `{rule_id: StringName, target_id: StringName,
  target_position: Vector3}`; `GuideRules.TEXT := {&"move": "Drag to move", …}` (keys only; the Guide wraps with
  `tr()`).
- Consumes: `NodePool.active()` (exists, `components/node_pool.gd:49`), `IconAtlas` `guide_arrow`, `stick_ring`,
  `stick_knob`, `disc` (8a), `Hud.arrow_rect()` (8b), `SafeArea.override_for_tests` (9).
- Produces: `class_name Guide extends Node`; `signal evaluated`; `func debug_force(rule_id: StringName) -> void` (debug
  capture only: shows that rule's text and pointer at a fixed target); `var rule_id: StringName`, `var target_id: StringName`,
  `var target_position: Vector3`; `func setup(main: Main) -> void`; `func snapshot() -> Dictionary`;
  `func evaluate_now() -> void`; `var walked := 0.0`; `signal completed`.

  Snapshot keys (all plain values): `phase: int`, `day: int`, `hero_xz: Vector2`, `walked: float`,
  `attack_range: float`, `boars: Array` of `{xz: Vector2, remaining: float, spawn_index: int, pos: Vector3}`,
  `steaks: Array` of `Vector3`, `carried: int`, `carry_capacity: int`, `freezer: int`, `counter: int`,
  `counter_capacity: int`, `gold: int`, `gold_pile: int`, `move_m: float` (from `Balance.ui.guide_move_m`), `spots: Array` of `{id: String, remaining: int,
  next_cost: int, pos: Vector3}` in `MapLayout.SPOT_IDS` order, `should_pulse: bool`.

- [ ] **Step 1: Edge clamp, test first.** Move the maths from `ui/hud/hud.gd:301-313`:

  ```gdscript
  class_name EdgeClamp
  extends RefCounted
  ## Where an edge arrow sits for a screen point (S5 D-213; was Hud._place_arrows). Pure.

  static func clamp_to_rect(p: Vector2, rect: Rect2) -> Dictionary:
  	if rect.has_point(p):
  		return {"inside": true, "position": p, "rotation": 0.0}
  	var c := rect.get_center()
  	var dir := (p - c).normalized()
  	var tx := INF if is_zero_approx(dir.x) else ((rect.end.x if dir.x > 0 else rect.position.x) - c.x) / dir.x
  	var ty := INF if is_zero_approx(dir.y) else ((rect.end.y if dir.y > 0 else rect.position.y) - c.y) / dir.y
  	return {"inside": false, "position": c + dir * minf(tx, ty), "rotation": dir.angle() - PI / 2.0}
  ```

  Tests: inside point unchanged; a point far right lands on `rect.end.x` with rotation `-PI/2`; far below lands on
  `rect.end.y` with rotation 0; a corner direction lands on the rect boundary. The HUD's existing arrow tests must still
  pass after `_place_arrows` calls it.

- [ ] **Step 2: Guide rules, test first.** `tests/unit/test_guide_rules.gd` builds snapshots with a helper
  `_s(over: Dictionary) -> Dictionary` (defaults: phase DAY, day 2, everything 0, hero at HOME, attack_range 4,
  carry 6, counter_capacity 12, no boars, no steaks, spots with `remaining` 20/20/20/40/40 and `next_cost` equal,
  `should_pulse` false) and asserts:
  - every `GuideRules.TEXT` value has at most 3 words (spec §1.2);
  - NIGHT day 1, walked 0 (move_m 2) → `move`, target_id `&""`;
  - walked 3, a boar at 10 m → `fight` targeting the boar with the smallest `remaining`; two equal `remaining` → lower
    `spawn_index`;
  - a boar within 4 m → not `fight` (and not `grab`, since a boar is alive) → empty rule;
  - after a kill (boars empty), steaks present, carried < capacity → `grab` at the nearest steak; carried == capacity →
    empty;
  - NIGHT day 2 → empty (no rule);
  - DAY day 2, gold 25, a spot with remaining 20 → `build` at the lowest `next_cost` affordable spot; a maxed spot
    (`remaining -1`) with gold 999 and nothing else affordable → not `build`;
  - build target stays the same spot while its remaining drops with gold (payment in progress);
  - `collect`: pile 30, gold 0 (gold + pile reaches 20) → `collect`; same but hero inside the freezer zone and `take`
    true → `take`, not `collect`;
  - `take`: freezer 36, counter 0, carried 0 → `take`; hero inside the freezer zone with carried 3 → still `take`;
    carried 6 → `stock`; counter 11 (room 1 < load 6), carried 0, pile 0 → empty (wait);
  - `take` reachable when carry_capacity 14 > counter_capacity 12: freezer 20, counter 0 → `take`;
  - `close` only when `should_pulse` is true; everything else 0 and should_pulse true → `close`;
  - day 5 DAY with work available → empty (Review Focus 1).

  Implementation (`core/guide_rules.gd`), in rule order; `_affordable(s)` returns spots with
  `0 < remaining <= gold`; `_load(s) = mini(carry_capacity, mini(freezer, counter_capacity))`;
  `_room(s) = counter_capacity - counter`; `_in_freezer(s) = hero_xz.distance_to(MapLayout.FREEZER_ZONE) <= MapLayout.STATION_RADIUS`;
  `_take(s) = freezer > 0 and _room(s) >= _load(s) and (carried == 0 or (_in_freezer(s) and carried < mini(carry_capacity, _room(s))))`;
  `collect` = `gold_pile > 0 and ((_affordable_with(s, gold + gold_pile) and not (_in_freezer(s) and _take(s))) or (carried == 0 and not _take(s)))`.
  Targets: `move` none; `fight` the boar; `grab` the nearest steak (distance to `hero_xz`, ties by array order);
  `build` the spot; `collect` `&"gold_pile"` at `MapLayout.to3(MapLayout.GOLD_PILE)`; `take` `&"freezer"` at
  `MapLayout.to3(MapLayout.FREEZER_ZONE)`; `stock` `&"counter"` at `MapLayout.to3(MapLayout.COUNTER_DROP)`; `close`
  `&"sign"` at `MapLayout.to3(MapLayout.SIGN)`. Boar target_id is `&"boar"`, steak `&"steak"`, spot its id.

- [ ] **Step 3: Guide node, test first** (`tests/unit/test_guide.gd`, `Main.create()` + `start_new_game(20260930)` +
  a Guide built by the test with `setup(main)`):
  - `snapshot()` matches GameState and positions (`steaks` from `main.world.steak_pool.active()` global
    positions; `boars` from `wave_director.alive_enemies()` with `remaining = b.path_length() - b.dist`;
    `should_pulse` from `Pulse.should_pulse(GameState.to_dict(), Balance.data)`);
  - `walked` sums `hero.velocity` length × physics delta in `_physics_process`, so `hero.teleport` adds nothing; it
    resets on `state_restored`;
  - the Guide evaluates every `guide_eval_s` (`evaluated` emitted ~4 times in 1 s, counted in game time);
  - off-screen: hero at `NIGHT1_START`, force a DAY day-2 snapshot with the freezer as target (set GameState: phase via
    `debug_skip_to_day`, `freezer_steaks = 10`): the edge arrow is visible, inside `hud.arrow_rect().grow(-40)`, its
    rotation points toward the freezer's screen point (dot product of the arrow's down vector and the direction > 0.9);
    the label rect lies inside that rect;
  - Review Focus 5: with `SafeArea.override_for_tests` notch insets and the SubViewport at 1280×720, the edge arrow and
    the label stay inside `hud.arrow_rect().grow(-guide_rect_inset_px)`;
  - on screen: the world pointer is visible above the target and the edge arrow hidden;
  - every Control under the Guide has `mouse_filter == MOUSE_FILTER_IGNORE`;
  The Guide draws: CanvasLayer 12; label (theme `HudCounter`, text `tr(GuideRules.TEXT[rule_id])`); edge arrow and
  ghost joystick as one custom-draw Control using `IconAtlas` cells (the ghost stick = `stick_ring` + `stick_knob` + a
  small `disc` fingertip on the knob); the world pointer (`art/fx/pointer.tscn`, an unshaded `gold` arrow mesh, bouncing
  `guide_bounce_m` at `guide_bounce_hz` in `_process`) placed `guide_pointer_h` above `target_position`. `move` shows
  the ghost stick at the lower third centre with a `guide_swipe_s` horizontal swipe loop and no world pointer. Every
  number comes from `Balance.ui`.
- [ ] **Step 4: Run** unit, sim, baseline; shots `docs/review/media/s5/task10` with a capture option `--guide=<id>`
  that calls `guide.debug_force(id)` (debug only) for each of the 8 rules, including `take` from `NIGHT1_START` (off-screen).
- [ ] **Step 5: Commit**, report the patch.

### Task 11: Ghost joystick, persistence, Main wiring, guide sim, web checks

**Spec:** §6 (completion, debug flags), §9 (sim, web checks), D-210, D-213. Review Focus 1.

**Files:**
- Create: `actors/bots/guide_bot.gd`, `tests/sim/test_guide_sim.gd`, `export/pw_s5_check.mjs`
- Modify: `ui/guide/guide.gd` (completion, persistence), `tests/sim/sim_harness.gd` (optional guide injection)
- Wiring (hot): `world/main.gd` (build the Guide in the boot path), `CLAUDE.md` (layout line)
- Test: `tests/unit/test_guide.gd` (persistence), `tests/sim/test_guide_sim.gd`

**Interfaces:**
- Consumes: `Guide` (Task 10), `SettingsStore` (Task 2), `BotBase.go_to`, `graph.nearest`, `choose_card`.
- Produces: `class_name GuideBot extends BotBase`; `SimHarness.start(p_seed, bot_script, with_guide := false)` and
  `var guide: Guide`.

- [ ] **Step 1: Failing unit tests (persistence).**
  - On `phase_changed(NIGHT, 2)`, the Guide sets `settings.guide_done = true`, saves, emits `completed` and frees
    itself; `phase_changed(NIGHT, 1)` does not.
  - Review Focus 1: resume (from a fixture dict) into DAY day 5 with `guide_done == false`: `rule_id` stays empty for
    2 s; the next `phase_changed(NIGHT, 5)` completes it.
  - `Main._maybe_build_guide()`: with an injected `main.settings_store` (`SettingsStore.with_dir`), it builds a Guide
    only when `guide_done` is false and `UrlFlags.get_flag("guide") != "0"`, and always when the flag is `"1"`
    (set with `UrlFlags.set_for_tests`); it never builds a second one.
- [ ] **Step 2: Main (patch).**

  ```gdscript
  var guide: Guide

  ## S5 D-213: the onboarding pointer, only for a device that has not finished it (or forced by ?guide=1 on debug).
  func _maybe_build_guide() -> void:
  	if guide != null or settings_store == null:
  		return
  	var flag := UrlFlags.get_flag("guide")
  	if flag == "1" or (flag != "0" and not settings_store.guide_done):
  		guide = Guide.new()
  		add_child(guide)
  		guide.setup(self)
  ```

  Called from the `auto_start` block after `settings_store.load_settings()`. The Guide reads `main.settings_store` for completion (null-safe: tests without a
  store skip saving).
- [ ] **Step 3: GuideBot.**

  ```gdscript
  class_name GuideBot
  extends BotBase
  ## Follows only the Guide (S5 spec 9 sim): walks north while `move` shows, else to the target; stands still when no
  ## rule shows; takes the first offered card.

  var guide: Guide
  const STATION_NODES := {&"freezer": "freezer", &"counter": "counter_drop", &"gold_pile": "gold_pile", &"sign": "sign"}

  func think(_delta: float) -> void:
  	if guide == null or not is_instance_valid(guide) or main.phase_controller.failing:
  		return
  	var r := guide.rule_id
  	if r == &"move":
  		go_to("zone_north")
  	elif r == &"":
  		_stand()
  	elif STATION_NODES.has(guide.target_id):
  		go_to(STATION_NODES[guide.target_id])
  	elif String(guide.target_id) in MapLayout.SPOT_IDS:
  		go_to(String(guide.target_id))
  	else:
  		_chase(Vector2(guide.target_position.x, guide.target_position.z))
  ```

  `_stand()`: `goal = ""; _route = []` (not `reset_route()`, which would drop a pending card offer at dawn).
  `_chase(p)`: route to `graph.nearest(p)` with `go_to`; once `arrived()` (or within 1 m of that node), replace the route
  with `[p]` (walk the last leg straight). Re-evaluate the chase target when `guide.target_position` moves more than
  1 m. After the Guide completes (night 2 starts), the bot stands still; the sim ends there.
- [ ] **Step 4: Sim** (`tests/sim/test_guide_sim.gd`). `SimHarness.start(seed, GuideBot, true)` builds a Guide with
  `setup(main)` and a temp `SettingsStore.with_dir("user://sim_guide")` (wiped first), sets `bot.guide`. Seeds:
  `20260930` and the first seed ≥ 1 whose plan `pl := LanePlanner.plan(seed, 1, Balance.data.wave)` has
  `pl[1].main != "north" and pl[2].main != "north"` (wave 0 is always north on day 1; find the seed in the test with a
  loop up to 1000 and print it). For each seed:
  - `run_night()` → `cleared` true, `failed` false; print `diner_frac`;
  - during night 1, connect to `guide.evaluated`; after `move` has first cleared, at every evaluation where some Boar is
    alive and none within `attack_range` of the hero, assert `guide.rule_id == &"fight"`;
  - after the card pick, run the day with a 5 s no-rule gap check: track seconds with `rule_id == &""` while phase is
    DAY; whenever the gap exceeds 5 s assert `GameState.counter_steaks > 0` (an empty rule already means none of
    build, collect, take, stock, close is true, since `GuideRules.evaluate` returned empty);
  - `run_day(600)` → `closed`; at night 2 start at least one spot has `level >= 1`;
  - print the sim's seconds. The whole sim file must keep the sim suite under 60 s; print per-test timing.
  If the 0-fail assertion fails on a seed: stop and report the night log (do not weaken the test; the main session
  revises the `fight` target rule).
- [ ] **Step 5: Web checks** (`export/pw_s5_check.mjs`, Playwright, debug build, desktop profile):
  1. load `?reset=1`, wait 30 s, collect console lines; diff against `docs/review/media/s5/console_baseline_main.txt`
     ignoring timestamps and numbers (first normalise per-run pointers: `s/0x[0-9a-f]+/0x?/g`, since the baseline holds
     `[.WebGL-0x…]` prefixes); print new lines; exit 1 on any new `error` or `warning`;
  2. read `window.LST_AUDIO.map(c=>c.state)` (all `suspended`), click the canvas centre, wait 1.5 s, read again (some
     `running`) and read `window.LST_STATE` (`unlocked` true, `music_id` `night`);
  3. load `?mute=1`, wait 5 s; reload without flags; wait 5 s; `window.LST_STATE.muted` is true.
  `LST_STATE` is written once a second by the debug overlay (`ui/debug/debug_overlay.gd`, debug builds only):
  `JavaScriptBridge.eval("window.LST_STATE=" + JSON.stringify({unlocked, muted, music_id}))`.
- [ ] **Step 6: CLAUDE.md layout line (patch):** add `art/audio` (audio manifest), `art/fx` (FX atlas, shader, field,
  pointer), `world/audio` (AudioDirector), `ui/guide` (onboarding pointer), `ui/settings` (settings panel).
- [ ] **Step 7: Run** unit, sim (report total time), baseline, `node export/pw_s5_check.mjs <url>`; shots
  `docs/review/media/s5/task11` (Guide `move` with the ghost stick).
- [ ] **Step 8: Commit**, report the patch.

---

## Phase P5: Results (`s5/p5-results`)

### Task 12: Final perf, size, web audio checks, results, review queue

**Spec:** §1, §9, §13, D-219.

**Files:**
- Modify: `docs/superpowers/specs/2026-10-02-s5-polish-onboarding-audio-juice-design.md` (§13 Results),
  `docs/REVIEW_QUEUE.md`, `docs/DECISIONS.md` (results decision), `docs/review/AUDIO.md` (Chromium A/B)
- Create: `docs/review/media/s5/perf_final/README.md`, `docs/review/media/s5/after/` shots

- [ ] **Step 1: Perf** (idle Mac, D-209): profile build of this branch and of the S4 tag/commit `c8cce18`, 3 runs each:
  night-3 `avg_fps`, night-3 `worst_ms`, day-3 `avg_fps`; desktop draw calls with FX active (capture in a `--fx=poof`
  repeat scene: read `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`). Gates per spec
  §1.6. Report every reading and the medians.
- [ ] **Step 2: Audio CPU (not gated):** Chromium profile build, autoplay allowed
  (`--autoplay-policy=no-user-gesture-required`), 60 s with and without `?audio=0`: mean `proc_ms`. Into AUDIO.md.
- [ ] **Step 3: Size:** release export; pck raw ≤ 8 MiB and `gzip -9` of wasm + pck + js ≤ 16 MiB (D-196); audio total
  from the validator.
- [ ] **Step 4: Web checks:** `node export/pw_s5_check.mjs` on the debug build; `export/device_check.sh` on the iOS
  Simulator with the release build; read every screenshot.
- [ ] **Step 5: After media:** `tools/shots.sh docs/review/media/s5/after` plus settings panel, Guide steps, one FX
  burst per kind; add rows to `docs/review/media/before_after.md`.
- [ ] **Step 6: Docs.** §13 Results (what shipped, test counts, perf table, size, deviations, skipped nits, open risks);
  REVIEW_QUEUE: keep the audio entry first-tier, add "iOS silent switch may mute Web Audio" to known issues, update
  known issues 1–3 with the S5 numbers and the WebGL attribution; the S5 playtest questions stay.
- [ ] **Step 7: Run** unit, sim, baseline. **Commit.**

---

## Phase P0 (main session, before P1)

- [ ] Commit this plan on `s5/p0-spec`, open the PR (spec + decisions + plan), wait for CI, self-merge (D-137), post the
  ≤ 5-line comment.
