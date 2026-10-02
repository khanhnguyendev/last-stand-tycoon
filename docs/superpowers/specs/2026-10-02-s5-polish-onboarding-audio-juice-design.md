# S5 Polish, Onboarding, Audio, Juice: Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`). It builds on the S1–S4 specs, and their conventions,
  architecture and rules still apply.
- **Precondition:** S4 is merged (art pass, D-182..D-209). The night-3 perf harness, the determinism baseline and the
  shot tooling exist.
- **Status:** written autonomously under D-159. The main session answered every brainstorming question from IDEA.md,
  the pillars, DECISIONS.md, the author's S5 line and the S4 results. A reviewer pass replaces the author's approval.
  Revised after the spec review: Guide off-screen targets and state-only rules, the warm-up, the audio hooks and
  unlock, pause ownership, the perf gates.
- **Decision log:** `docs/DECISIONS.md` D-210 to D-219.
- **The author's S5 line:** "UI/HUD polish, onboarding (contextual, no text walls), audio (CC0 SFX + music, mute
  toggle, web audio unlock), VFX and juice."

---

## 1. Goal and success criteria

S5 makes the finished-looking game feel finished: it sounds, reacts, explains itself without text walls, and has
the small UI a released web game needs.

1. **Audio.** CC0 SFX for every core action, and looping CC0 music for day and night. One mute toggle, remembered
   across sessions. Audio starts after the first user gesture on web, and adds no console error or warning beyond
   those the current `main` build already logs.
2. **Onboarding.** A bot that only walks to the Guide's pointer gets from a new game to night 2 with at least one
   build (§9 sim). The pointer shows at most three words, never pauses, never blocks input, and still points the
   way when its target is off screen. A returning player never sees it again.
3. **Juice.** Kills, pickups, sales, builds, damage and phase changes each have a visible and audible reaction.
4. **UI polish.**
   - a settings button and panel: mute, New game with a confirmation (D-177);
   - a skinned joystick;
   - a HUD layout that respects the safe area;
   - no world label drawn under the HUD.
5. **Gameplay identity.** `tools/baseline_diff.sh` prints `baseline identical` after every task. S5 changes no rule,
   number or timing of the game.
6. **Performance** (D-209 protocol, idle Mac, median of 3, iOS Simulator `web_profile`):
   - night-3 `avg_fps` at least 58;
   - night-3 `worst_ms` under 60 (S4 baseline: 113–139 ms, the first-wave stall);
   - day-3 `avg_fps` no lower than the S4 `main` build read in the same session, minus 1.
7. **Size.** The release stays inside the D-196 gates. Audio gets a budget of 2.5 MB.
8. **Licences.** Every audio file is CC0 and logged with evidence. The validator covers audio.

## 2. Scope

**In:**
- an `AudioDirector` with an SFX map, music by phase, web unlock and a mute bus;
- a settings store (a localStorage key, separate from the save);
- the settings panel and its button;
- New game;
- an `FxField` (one MultiMesh of animated quads) for poofs, sparks, sparkles and dust;
- screen shake, replacing the existing one;
- UI motion: banner slide, card entrance, button press, strip pop;
- the onboarding `Guide` pointer, with an edge arrow for off-screen targets;
- the joystick skin;
- a HUD safe-area and overlap pass;
- a shader warm-up for the first-wave stall;
- attribution of the carried WebGL warnings;
- perf and size results.

**Out:**
- anything that changes gameplay: hit-stop, knockback, new enemy behaviour, balance;
- damage numbers (Label3D cost; not needed to read the fight);
- voice;
- a volume slider (one mute toggle is the author's ask);
- localisation beyond `tr()`;
- a title screen (D-176: resume is instant);
- a HUD steak counter: `steak.png` is removed from the icons, because nothing shows it (closes the D-208 note);
- the final review package (its own short plan after S5).

IDEA "Later" stays out.

## 3. Brainstorm answers (autonomous, D-159)

| Question | Answer | Source | D-id |
|---|---|---|---|
| Where do settings live? | Not in GameState, because they are device preferences, not game data. A `SettingsStore` writes one JSON value `{v, muted, guide_done}` under `lst:<pathname>:settings`, with the same try/catch JS path as SaveStore, and a `user://settings.json` file elsewhere. A wiped or corrupt value means defaults. `SaveStore.wipe()` and New game leave it alone. | D-171, D-177 | D-210 |
| Which sounds and music? | **SFX:** Kenney audio packs (CC0): Interface Sounds, Impact Sounds, RPG Audio, Casino Audio, Music Jingles. One file per event, picked in Task 1 by the ear-free criteria in §4.2. **Music:** day = "Happy Adventure Loop" (tinyworlds, 47 s); night = "Chiptune Adventures: Stage 2" (Juhani Junkala, 56 s). Both are from OpenGameArt and marked CC0. **Honesty:** the agent cannot hear. The tracks are chosen by licence, length, loopability and measured loudness. Each is one line in `art/audio/audio_manifest.gd`, so the author can swap it in a minute. | Author's S5 line | D-211 |
| How is audio kept small? | Music is re-encoded with the already-installed `ffmpeg` to MP3 (libmp3lame), mono, 32 kHz, 64 kbps: 0.38 MB and 0.45 MB (measured). This ffmpeg has no libvorbis, and its native Vorbis encoder is experimental. Tracks are capped at 60 s. SFX stay as shipped (10–40 KB each). **Budget:** all audio at most 2.5 MB; the validator enforces it and fails on any audio file under `assets/` that the manifest does not name. | D-196 | D-211 |
| How does audio start on web? | Browsers keep the AudioContext suspended until a user activation, and the engine resumes it on input by itself. `AudioDirector` does not fight that: it polls one named probe, `unlocked`, once a second until true. Before that it drops SFX and queues no music; at unlock it starts the current phase's track. The probe on web is the AudioContext's `state == "running"`, read through a hook the web shell installs (§4.4). Off web it is true at once. A Task 3 spike proves the probe on iOS Safari and Chromium before the director relies on it. | Author's S5 line | D-212 |
| Which playback type? | Sample playback (the web default) for SFX and music, because it is the robust path in a single-threaded build. Its cost is a one-time decode per stream, so every manifest stream is registered at boot behind the boot fade (`AudioServer.register_stream_as_sample`). **Fallback** if the Task 3 spike shows a boot freeze over 0.5 s or an error: music uses `PLAYBACK_TYPE_STREAM`. | Reviewer finding | D-212 |
| How does the mute toggle work? | One toggle. It mutes the Master bus (`AudioServer.set_bus_mute`). It is saved in SettingsStore at once and applied at boot before anything plays. | Author's S5 line | D-212 |
| How does onboarding teach without text? | One pointer plus one label of at most three words, driven by an ordered rule list of **pure state predicates** (§6). When the target is on screen, the pointer is a bouncing world arrow over it. When it is off screen, the pointer is an arrow on the Guide's CanvasLayer, clamped to the safe rect's edge and pointing toward the target, using the HUD lane-arrow maths. **It never pauses, blocks input or opens a panel.** It completes on the first `phase_changed(NIGHT, day ≥ 2)`; `guide_done` is saved, and the Guide never shows again on that device. | Author's S5 line; Pillar 2 | D-213 |
| How is juice kept cheap? | One `FxField`: a MultiMesh of camera-facing quads with a small atlas, animated on the CPU in `_process`. It is one draw call for every particle in the game. No GPUParticles (one draw each), no Label3D pop-ups. Screen shake moves only the camera rig's offset. | D-201 | D-214 |
| How do systems ask for a sound or an effect? | Two new EventBus signals: `sfx_requested(id: StringName)` and `fx_requested(kind: StringName, position: Vector3)`. Local events with no bus signal (the hero's `Attacker.fired`, a Boar's hit, a build payment tick, a UI press) emit them. `AudioDirector` and `FxField` listen. Emitting is visual and audio only: no gameplay code listens to these two signals. | S1 architecture (EventBus = cross-system) | D-214 |
| What about the first-wave stall? | It is first-use cost: shaders compile when the first Boar, steak, projectile and FX are drawn. A `Warmup` step in `Main._boot` draws one of each **inside the camera frustum** under an opaque boot-fade layer for two rendered frames, then frees them. Off-screen placement would be frustum-culled and compile nothing. It uses temporary nodes only: no pool, no PickupField slot, no GameState, no Rng. | D-199 known issue | D-215 |
| What does the HUD pass change? | Positions only, and only to fix known problems: every HUD block sits inside the safe area; the card strip moves clear of the diner bar; world labels the HUD covers are dimmed; a settings gear sits top-right. The gear, the joystick ring and the knob are icon-atlas cells (D-209: polygons do not batch). | REVIEW_QUEUE, S4 notes | D-216 |
| How does New game work? | Settings panel → "New game" arms it and shows "Tap again to erase". The second tap counts only after `card_input_guard_s` (0.5 s) and within 3 s. It calls `Main.fresh_start()`: wipe the save, `start_new_game()`, close the panel, unpause. The debug R key calls the same function. | D-177 | D-217 |
| Who owns pausing? | Main owns a set of pause reasons (`focus`, `settings`); the tree is paused while the set is not empty. FocusPause and the settings panel add and remove their reason. This replaces FocusPause's private `_paused_by_focus` flag, which could unpause an open panel. FocusPause emits a local `changed(paused)` signal, and `AudioDirector.set_suspended(true)` sets `stream_paused` on its players while the tab is hidden. | D-147 | D-218 |
| What are the gates? | Baseline identical; unit and sim green; validator green including audio; the §1.6 perf gates; the size gates; a shot review per visual task. Audio is checked by state, not by ear. Console output on web must show no new error or warning against a baseline recorded from `main` in Task 1, and that includes the carried WebGL warnings. | D-159, D-196, D-209 | D-219 |

## 4. Audio (P1)

### 4.1 Files and layout

- `assets/kenney-<pack>-audio/` holds only the files used, plus `LICENSE.txt`.
- `assets/oga-<slug>/` holds one re-encoded track plus `LICENSE.txt`. The folder is a direct child of `assets/`, as
  the validator requires. Its `LICENSE.txt` records:
  - the page URL and the retrieval date;
  - the page's licence field, verbatim;
  - the uploader and the stated author, and that they are the same person;
  - the original file name and its SHA-256;
  - the exact ffmpeg command used.
- **Stop rule:** if a page shows any licence besides CC0, or the uploader is not the author, the track is swapped
  for another CC0 one. If no CC0 track fits, stop and ask the author (D-159).
- `art/audio/audio_manifest.gd` (class `AudioManifest`):

  ```
  const SFX := {&"hit": {"path": "...ogg", "volume_db": -6.0, "pitch_spread": 0.08, "min_gap_s": 0.05}, ...}
  const MUSIC := {&"day": {"path": "...mp3", "volume_db": -14.0}, &"night": {...}}
  ```

  It is the single place where a sound or a track is chosen.
- ASSET_LICENSES gets one row per audio pack and one per music track.
- **Validator additions:**
  - `.ogg`, `.mp3` and `.wav` are allowed only under `assets/`;
  - every manifest path exists, and every audio file under `assets/` is named by the manifest;
  - the summed size is at most 2.5 MB;
  - each music file is at most 60 s long (read from the imported stream's length).

### 4.2 Choosing sounds without ears

Task 1 picks each SFX by pack, file name and measured properties (`ffprobe` duration, `ffmpeg volumedetect` peak
and mean), with these rules:
- under 0.6 s for repeated sounds (hit, pickup, coin, tick);
- under 1.5 s for single events;
- peak below 0 dBFS (no clipping);
- after its `volume_db`, each sound's mean level is within ±3 dB of its class target: repeated −24 dB, single
  −18 dB, music −26 dB.

A table of event, file, duration, peak, mean and reason goes in `docs/review/AUDIO.md`, so the author can audit and
swap. REVIEW_QUEUE has one high entry: "all audio was chosen without listening". The MP3 loop may have a small gap
at the loop point; AUDIO.md says so.

### 4.3 `AudioDirector` (`world/audio/audio_director.gd`, a Node in Main, `PROCESS_MODE_ALWAYS`)

- **Players:** a pool of 10 `AudioStreamPlayer`s on an `SFX` bus, and two on a `Music` bus for a 1.0 s crossfade.
  When all 10 are busy, the oldest is reused.
- **`play(id: StringName)`:** drops the sound if the same id played less than `min_gap_s` ago. Pitch is
  `1.0 + pitch_spread * seq`, where `seq` cycles through a fixed table (-1, 0.5, -0.5, 1, 0). No randomness.
- **Event map:**

  | Source | SFX id |
  |---|---|
  | `sfx_requested(&"throw")`, from the hero on `Attacker.fired` | `throw` |
  | `sfx_requested(&"hit")`, from `Boar.take_hit` | `hit` |
  | `enemy_killed` | `poof` |
  | `steak_picked` | `pickup` |
  | `sfx_requested(&"take")`, from the freezer when the hero takes steaks | `take` |
  | `sfx_requested(&"stock")`, from the counter when it gains steaks | `stock` |
  | `steak_sold` | `coin` |
  | `gold_changed` with `delta > 0` (only `collect_pile` emits it) | `collect` |
  | `gold_changed` with `delta < 0` (only `pay_into_spot` emits it) | `build_tick` |
  | `build_completed` | `build_done` |
  | `card_offered` | `card_open` |
  | `card_picked` | `card_pick` |
  | `wave_incoming` | `horn` |
  | `wave_cleared`, except the night's last wave | `wave_clear` |
  | `diner_damaged` | `diner_hit` |
  | `night_failed` | `fail` |
  | `phase_changed` → DAWN | `dawn` (jingle) |
  | `guard_knocked_out` / `guard_revived` | `guard_down` / `guard_up` |
  | `sfx_requested(&"click")`, from UI buttons | `click` |

  `building_changed` is not used: it also fires on fence damage and dawn healing.
- **Music:** `phase_changed` → NIGHT plays `night`; DAWN and DAY play `day`. It crossfades and loops.
- **Unlock and mute:** as D-212.
- **Suspend:** `set_suspended(p)` sets `stream_paused` on every player (D-218).
- **Headless and tests:** the director works with the dummy audio driver. It exposes `last_played: Array` (a ring of
  the last 16 ids), `music_id`, `unlocked`, `muted` and `suspended` for tests.
- **Sims and unit tests:** `Main.create()` always builds the director (cheap, dummy driver). The SettingsStore,
  Guide, Warmup and boot fade are built only in the `auto_start` boot path, so sims and the baseline are untouched
  unless a test injects them.

### 4.4 The web unlock probe

- `export/web_shell.html` wraps `window.AudioContext` (and `webkitAudioContext`) before the engine loads, and keeps
  each created context in `window.LST_AUDIO`.
- The probe is `JavaScriptBridge.eval("(window.LST_AUDIO||[]).some(c=>c.state==='running')", true)`.
- **Task 3 spike first:** on the iOS Simulator and on Chromium, confirm that the context is suspended before a
  gesture and running after one, that the engine resumes it without help, and that registering streams at boot
  causes no freeze over 0.5 s. If the wrapper misbehaves, the fallback probe is "an input release event has been
  seen" (`InputEventScreenTouch` not pressed, mouse button up, or key up).

## 5. Juice (P2)

### 5.1 `FxField` (`art/fx/fx_field.gd`, class `FxField`, one MultiMeshInstance3D owned by World)

- **Capacity:** 192 quads and a free-list. When it is full, a new burst replaces the oldest quads.
- **One texture:** `art/fx/fx_atlas.png`, 4 cells (puff, spark, star, dust), generated by a tool script, in palette
  colours.
- **Per particle:** position, velocity, gravity, life, a size curve (grow then shrink), colour, cell. `_process`
  integrates and writes the instance transform, colour and custom data. Dead quads get zero scale.
- **Culling:** a fixed `custom_aabb` covering the ground rect, so the field is never culled as a whole.
- **API:** it listens to `fx_requested(kind, position)`. Kinds are a table: `poof` (8 puffs, snout pink to white),
  `hit` (3 sparks), `sparkle` (6 gold stars), `dust` (2 puffs), `coin` (4 gold stars). Each kind has a fixed
  direction set, rotated by a per-burst counter. No randomness.
- **Billboarding:** the quad faces the camera in the shader, unshaded, alpha blended, no depth write.

### 5.2 Reactions

| Event | Reaction |
|---|---|
| Boar hit | `fx_requested(&"hit")` at the Boar; the existing flash and squash. |
| Boar killed | `poof` burst; the existing death squash; the steak appears as today. |
| Steak picked | the existing fly arc; a 6% squash pulse on the carry stack. |
| Sale | `coin` burst at the counter; the buying traveler's Body hops once. |
| Gold collected | `sparkle` burst at the pile; the HUD coin icon punches with the existing gold punch. |
| Build paid | `dust` at the spot on every 4th payment tick, emitted from `BuildSpot._on_tick`. |
| Build completed | `sparkle` burst; the existing pop. |
| Diner damaged | screen shake; the diner bar flashes `enemy_red` for 0.15 s. |
| Diner fell | a longer, stronger shake. |
| Wave incoming | the HUD lane arrow punches. The telegraph flag is hidden at night, so it gets nothing. |
| Dawn | every guard and the hero cheer (exists); a `sparkle` burst over the diner. |
| Card picked | the card strip cell pops 1.25× for 0.15 s. |
| Hero running | a `dust` puff every 0.35 s of movement, at the feet. |

**Screen shake** replaces the existing one in `world/camera_rig.gd` (0.15 s, amplitude 0.12, cooldown 0.5 s).
- It stays an additive offset on the camera transform, from a fixed offset table.
- The cooldown is kept. Overlapping requests take the larger amplitude and the longer time.
- Diner damaged: 0.12 s, 0.12 m. Diner fell: 0.4 s, 0.3 m.
- A new `Balance.ui.shake_enabled` (default true) lets tests and `capture.gd` turn it off.
- A restore still ends any shake.

### 5.3 UI motion

- **Banner:** slides down 24 px and fades in over 0.15 s.
- **Card pick:** each card rises 40 px and fades in over 0.18 s, staggered by 0.06 s. The last card lands at
  0.30 s, inside the existing `card_input_guard_s` (0.5 s), so the guard is not lengthened. A test asserts
  stagger × 2 + duration ≤ `card_input_guard_s`.
- **Buttons:** scale to 0.94 on press.
- **All durations** live in `ui_tuning`.

### 5.4 Warm-up and boot fade (D-215)

- **Boot fade:** `Main._boot` shows a full-screen `night_sky` (Palette) ColorRect on its own CanvasLayer. It is
  opaque for the warm-up and then fades out over 0.3 s.
- **Warm-up** (`world/warmup.gd`), awaited inside `Main._boot` before the first phase starts:
  - It places temporary nodes in front of the camera, inside the frustum: one Boar visual with each of its four
    materials in turn, one steak in a temporary MultiMesh, one knife and one arrow projectile visual, one quad of
    each FxField cell in a temporary MultiMesh with the FxField material, a tower L1 and a fence L1, and one role
    visual of each character.
  - It waits two rendered frames, then frees everything.
  - It registers every manifest stream as a sample.
- **Gameplay identity:** no pool, no PickupField slot, no GameState, no Rng. The phase starts after the warm-up, so
  the baseline (which uses `Main.create()` without boot) cannot see it.

## 6. Onboarding `Guide` (P4)

- **Node:** `ui/guide/guide.gd`, a Node in Main, built only at boot when `guide_done` is false.
- **Parts:**
  - a world pointer (`art/fx/pointer.tscn`: a bouncing arrow mesh, unshaded gold);
  - a CanvasLayer with the label (theme `HudCounter`), the edge arrow and the ghost joystick, all drawn from the
    icon atlas.
- **Evaluation:** four times a second. The Guide shows the first rule, in the order below, whose predicate is true.
  If none is true it shows nothing.
- **Predicates are pure functions of the current state.** `phase` is `PhaseController.phase`; `day` is
  `GameState.day`. Night 1 is `NIGHT` with `day == 1`. The first day is `DAY` with `day == 2`, because
  `advance_day()` runs at dawn.

  | Order | id | Text | Predicate | Target |
  |---|---|---|---|---|
  | 1 | `move` | Drag to move | `NIGHT`, day 1, and the hero has walked < 2 m since the last start or restore | the ghost joystick, lower third |
  | 2 | `fight` | Stay close | `NIGHT`, day 1, a Boar is alive, and no Boar has died since the last start or restore | the nearest alive Boar |
  | 3 | `grab` | Grab steaks | `NIGHT`, day 1, a ground steak exists, and `carried_steaks == 0` | the nearest ground steak |
  | 4 | `build` | Build here | `DAY`, day 2, some spot has `gold ≥ remaining cost` | the spot with `paid > 0`, else the cheapest such spot |
  | 5 | `collect` | Collect gold | `DAY`, day 2, `gold_pile > 0`, and either `gold + gold_pile` reaches some spot's remaining cost, or `carried_steaks == 0` and (`freezer_steaks == 0` or the counter is full) | the gold pile |
  | 6 | `stock` | Stock counter | `DAY`, day 2, `carried_steaks > 0`, and the counter is not full | the counter |
  | 7 | `take` | Take steaks | `DAY`, day 2, `carried_steaks == 0`, `freezer_steaks > 0`, and the counter is not full | the freezer |
  | 8 | `close` | Close up | `DAY`, day 2, and `Pulse.should_pulse()` is true | the sign |

- **Two counters, both reset on `state_restored` and on a new game:** walked distance (summed from the hero's
  velocity, so a teleport does not count) and Boar deaths. A failed night 1 therefore replays `move`, `fight` and
  `grab` sensibly.
- **Dawn card pick:** no rule. The overlay has its own heading.
- **Completion:** on the first `phase_changed(NIGHT, day ≥ 2)`, `guide_done` is saved and the Guide frees itself.
- **Off-screen targets (D-213):** if the target's screen point is outside the safe rect inset by 48 px, the world
  pointer hides, and the edge arrow and the label sit on the rect's edge along the direction to the target.
- **Never blocks:** no collision; every Control ignores the mouse; the ghost joystick is a drawing.
- **Debug:** `?guide=1` on debug builds forces the Guide on; `?guide=0` turns it off.

## 7. UI polish (P3)

- **Settings button:** a 72 px gear (an atlas cell), top-right, inside the safe area.
  - It sits on the settings CanvasLayer, which is added after InputLayer and the card overlay.
  - It owns its presses with the debug overlay's `_owned` + `set_input_as_handled` pattern, so a press on it never
    starts the joystick.
  - The gear rect is excluded from `Hud._arrow_rect`.
- **Settings panel:** a centred cream panel, `PROCESS_MODE_ALWAYS`, with:
  - **Sound** (toggle);
  - **New game** (two-step, D-217);
  - **Close**.

  Opening it adds the `settings` pause reason (D-218); closing removes it. It is tested with the card overlay open
  and with a focus loss while open.
- **Joystick skin:** the base ring and the knob are atlas cells: `ink` at 25% alpha with a `warm_white` rim, and
  `warm_white` at 80%.
- **HUD safe-area pass:**
  - every HUD block (coin and counter, day and moons and bar, card strip, gear) is positioned from
    `SafeArea.insets`;
  - the card strip sits 12 px below the lowest of the coin row and the diner bar.
- **World labels under the HUD:** four times a second, a WorldLabel whose screen point falls inside a HUD block's
  rect (grown 8 px) is set to alpha 0.15; otherwise 1.0.
  - It snaps, because a modulate change rebuilds the label mesh.
  - It skips the labels OccluderFade owns (the diner board) and the Guide's label.
- **Layout numbers** live in `ui_tuning`.

## 8. Hot files and wiring

These files take wiring from the main session (D-139, D-181):
- **`autoload/EventBus.gd`:** `sfx_requested`, `fx_requested`.
- **`world/main.gd`:** AudioDirector, SettingsStore, Guide, the settings layer, Warmup and boot fade, the pause
  reasons, `fresh_start`.
- **`world/world.gd`:** FxField.
- **`balance/ui_tuning.gd`:** every new number, including `shake_enabled`.
- **`project.godot`:** the audio bus layout (`default_bus_layout.tres`).
- **`CLAUDE.md`:** the layout line for `art/audio`, `art/fx`, `world/audio`, `ui/guide`, `ui/settings`.

Not hot, but shared and named here: `world/camera_rig.gd` (shake), `world/focus_pause.gd` (pause reasons),
`export/web_shell.html` (the AudioContext hook), `ui/debug/debug_overlay.gd` (R key → `fresh_start`).

## 9. Testing and verification

- **Unit:**
  - **SettingsStore:** defaults; round trip; a corrupt value gives defaults; it is separate from the save key;
    `SaveStore.wipe()` and `fresh_start` leave it alone.
  - **AudioDirector:**
    - each mapped source records its id in `last_played`;
    - fence damage and dawn healing play nothing;
    - the last wave's clear plays no `wave_clear`;
    - `min_gap_s` drops repeats; the pitch table cycles; the oldest voice is reused;
    - nothing plays before unlock; music starts at unlock with the current phase's track;
    - music follows the phase and crossfades;
    - mute sets the Master bus and persists; `set_suspended` pauses every player.
  - **The manifest and the validator:** every path exists; no unnamed audio file; the budget; the 60 s cap.
  - **FxField:** a burst fills quads; life ends them; capacity is never exceeded and the oldest are replaced; one
    MultiMesh; two identical burst sequences give identical transforms.
  - **Reactions:** each row of §5.2 emits its `fx_requested` or shake.
  - **Screen shake:** decays to zero; overlapping requests take the maximum; the cooldown holds; off when
    `shake_enabled` is false; a restore ends it.
  - **Warm-up:** leaves GameState, the pools and Rng untouched; frees every temporary node.
  - **Pause reasons:** focus loss while the panel is open, then focus gain, leaves the tree paused; closing the
    panel while unfocused leaves it paused; both gone unpauses.
  - **Guide:**
    - each rule's predicate, in order, on hand-built states;
    - `day == 2` for the first day;
    - the counters reset on `state_restored`, and a teleport does not count as walking;
    - with the hero at `NIGHT1_START` and the freezer as target, the edge arrow shows inside the safe rect and
      points the right way;
    - `guide_done` persists and suppresses the Guide;
    - no Guide Control stops the mouse.
  - **Settings panel:** the gear press does not start the joystick; the two-step confirm with its guard time; New
    game calls `fresh_start` and keeps settings.
  - **HUD:** blocks inside the safe area for three inset sets; the strip gap; labels dim under the HUD and skip
    OccluderFade's and the Guide's.
- **Sim (new, P4):** `test_guide_sim`: a bot that walks only to the Guide's current target, and stands still on
  it, starts a new game with the Guide injected, and reaches night 2 with at least one built spot. At no time
  while work remains (`Pulse.should_pulse()` false, or a night-1 rule pending) does the Guide show nothing for more
  than 5 s. The sim suite stays under 60 s.
- **Determinism:** `tools/baseline_diff.sh` after every task. The baseline is the S4 one; it must still match.
- **Web checks** (`export/pw_check.mjs` extended, Task 1 records the baseline from `main`):
  - no new console error or warning against the baseline, WebGL warnings included;
  - before a gesture the AudioContext is suspended; after a synthetic tap it is running and the director's
    `unlocked` is true (read through a debug hook on the `/debug/` build);
  - the mute toggle survives a reload.
- **Carried WebGL warnings:** Task 4 reproduces the two one-time warnings on `main`, finds which draw triggers
  them, and records the finding. A fix is in scope only if it is a one-file change; otherwise it stays a known
  issue.
- **Shots:** the standard `tools/shots.sh` list per visual task, plus:
  - the settings panel;
  - each Guide step (a `--guide=<id>` capture option), including one off-screen target;
  - a burst frame per FxField kind.
- **Perf** (end of P2 and end of S5, D-209 protocol):
  - the three §1.6 gates, each as the median of 3 runs;
  - the same three numbers from the S4 `main` build in the same session, as the comparison;
  - desktop draw calls with FX active.
  - **Limit, stated honestly:** the Simulator harness has no gesture and no input, so audio and running dust are
    not in its reading. Audio's CPU cost is reported from a Chromium A/B run with autoplay allowed (proc time with
    audio on and off); it is not gated.

## 10. Build order (a hint for writing-plans)

| Phase | Branch | Tasks |
|---|---|---|
| P1 Audio | `s5/p1-audio` | 1 web console baseline, audio intake, re-encode, manifest, validator, AUDIO.md; 2 SettingsStore; 3 unlock spike, bus layout, AudioDirector, `sfx_requested` hooks |
| P2 Juice | `s5/p2-juice` | 4 FxField, atlas, `fx_requested`, WebGL-warning attribution; 5 reactions and screen shake; 6 UI motion; 7 warm-up and boot fade + **perf checkpoint** |
| P3 UI | `s5/p3-ui` | 8 pause reasons, settings layer, gear, panel, New game; 9 joystick skin, HUD safe-area pass, label dimming |
| P4 Onboarding | `s5/p4-guide` | 10 Guide rules, pointer, edge arrow; 11 ghost joystick, persistence, the guide sim, web checks |
| P5 Results | `s5/p5-results` | 12 perf, size, web audio checks, results, review queue |

## 11. Risks

| Risk | Mitigation |
|---|---|
| Audio chosen without listening sounds wrong | One manifest; `docs/review/AUDIO.md` lists every choice; top REVIEW_QUEUE entry; conservative volumes. |
| Sample registration freezes boot, or web audio errors | The Task 3 spike; tracks capped at 60 s mono; registration behind the boot fade; the stream-playback fallback for music. |
| The unlock probe is wrong on a phone | The spike runs on the iOS Simulator and Chromium; the input-release fallback; the real phone check is at the final review. |
| FX cost drops night 3 below 58 | One MultiMesh for FX; the perf checkpoint at P2; cut `dust` first, then lower the capacity. |
| The warm-up changes gameplay order | It runs only in `_boot`, with no pools and no GameState; the baseline diff proves it. |
| The Guide leaves a new player lost | State-only rules; the edge arrow; the guide sim with its 5 s no-gap check. |
| Pause conflicts | One owner (Main's reason set); tests for every pair. |

## 12. Playtest questions added for the final review

1. Did you know what to do in your first minute without reading anything?
2. Did the sound fit? Was anything too loud, too quiet or annoying?
3. Did kills, sales and builds feel satisfying?
4. Did you find the mute button when you wanted it?

## Appendix: Post-v0.1 ideas (not in v0.1)

- Separate music and SFX sliders.
- Adaptive music layers per wave.
- Haptics on mobile.
- Damage numbers.
- A photo mode.

## 13. Results (S5, filled in at the end of S5)
