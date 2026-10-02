# S5 Polish, Onboarding, Audio, Juice: Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`). It builds on the S1–S4 specs, and their conventions,
  architecture and rules still apply.
- **Precondition:** S4 is merged (art pass, D-182..D-209). The night-3 perf harness, the determinism baseline and the
  shot tooling exist.
- **Status:** written autonomously under D-159. The main session answered every brainstorming question from IDEA.md,
  the pillars, DECISIONS.md, the author's S5 line and the S4 results. A reviewer pass replaces the author's approval.
- **Decision log:** `docs/DECISIONS.md` D-210 to D-218.
- **The author's S5 line:** "UI/HUD polish, onboarding (contextual, no text walls), audio (CC0 SFX + music, mute
  toggle, web audio unlock), VFX and juice."

---

## 1. Goal and success criteria

S5 makes the finished-looking game feel finished: it sounds, reacts, explains itself without text walls, and has
the small UI a released web game needs.

1. **Audio.** CC0 SFX for every core action, and looping CC0 music for day and night. One mute toggle, remembered
   across sessions. Audio starts on the first user gesture on web, with no console error before it.
2. **Onboarding.** A first-time player gets from "page open" to "second night started" guided only by one moving
   pointer with at most three words. No modal, no pause, no text wall. A returning player never sees it again.
3. **Juice.** Kills, pickups, sales, builds, damage and phase changes each have a visible and audible reaction.
4. **UI polish.**
   - a settings button and panel: mute, New game with a confirmation (D-177);
   - a skinned joystick;
   - a HUD layout that respects the safe area;
   - no world label drawn under the HUD.
5. **Gameplay identity.** `tools/baseline_diff.sh` prints `baseline identical` after every task. S5 changes no rule,
   number or timing of the game.
6. **Performance.** Night 3 on the `web_profile` build in the iOS Simulator stays at a median of at least 58 fps
   (D-196, D-209 protocol). The first-wave stall drops below 60 ms. Day 3 is measured and reported.
7. **Size.** The release stays inside the D-196 gates: pck at most 8 MiB, gzip payload at most 16 MiB. Audio gets a
   budget of 2.5 MB.
8. **Licences.** Every audio file is CC0 and logged. The validator covers audio.

## 2. Scope

**In:**
- an `AudioDirector` with an SFX map, music by phase, web unlock and a mute bus;
- a settings store (localStorage key, separate from the save);
- the settings panel and its button;
- New game;
- an `FxField` (one MultiMesh of animated quads) for poofs, sparks, sparkles and dust;
- screen shake;
- UI motion: banner slide, card entrance, button press, strip pop;
- the onboarding `Guide` pointer;
- the joystick skin;
- a HUD safe-area and overlap pass;
- shader and pool warm-up for the first-wave stall;
- perf and size results.

**Out:**
- anything that changes gameplay: hit-stop, knockback, new enemy behaviour, balance;
- damage numbers (Label3D cost; not needed to read the fight);
- voice;
- a volume slider (one mute toggle is the author's ask);
- localisation beyond `tr()`;
- a title screen (D-176: resume is instant);
- the final review package (its own short plan after S5).

IDEA "Later" stays out.

## 3. Brainstorm answers (autonomous, D-159)

| Question | Answer | Source | D-id |
|---|---|---|---|
| Where do settings live? | Not in GameState, because they are device preferences, not game data. A `SettingsStore` writes one JSON value `{v, muted, guide_done}` under `lst:<pathname>:settings`, with the same try/catch JS path as SaveStore, and a `user://settings.json` file elsewhere. A wiped or corrupt value means defaults. New game does not reset it. | D-171, D-177 | D-210 |
| Which sounds and music? | **SFX:** Kenney audio packs (CC0): Interface Sounds, Impact Sounds, RPG Audio, Casino Audio, Music Jingles. One file per event, picked in Task 1 by ear-free criteria (see §4.2). **Music:** day = "Happy Adventure Loop" (tinyworlds, CC0); night = "Chiptune Adventures: Stage 2" (Juhani Junkala, CC0). Both from OpenGameArt, with the licence page saved beside the file. **Honesty:** the agent cannot hear. The tracks are chosen by licence, length, loopability and measured tempo and loudness. Each track is one line in `art/audio/audio_manifest.gd`, so the author can swap it in a minute. | Author's S5 line | D-211 |
| How is audio kept small? | Music is re-encoded with the already-installed `ffmpeg` to Ogg Vorbis, mono, 22.05 kHz, about 64 kbps: roughly 0.4 MB per minute. SFX stay as shipped (10–40 KB each). **Budget:** all audio at most 2.5 MB in the pck; the validator enforces it. | D-196 | D-211 |
| How does audio start on web? | Browsers keep the AudioContext suspended until a user gesture. `AudioDirector` starts music only after the first `InputEventScreenTouch`, mouse button or key press, and retries once per second until `AudioServer` reports a running mix. Nothing plays before that, so there are no console errors. | Author's S5 line | D-212 |
| How does the mute toggle work? | One toggle. It mutes the Master bus (`AudioServer.set_bus_mute`). It is saved in SettingsStore at once and applied at boot before anything plays. | Author's S5 line | D-212 |
| How does onboarding teach without text? | One world pointer (a bouncing arrow) plus one label of at most three words, driven by a rule list that looks at the game state. It shows the next useful thing on night 1 and day 1, and each step ends when the player does it. **It never pauses, blocks input or opens a panel.** When the last step is done (night 2 starts), `guide_done` is saved, and the Guide never shows again on that device. | Author's S5 line; Pillar 2 | D-213 |
| What are the steps? | Night 1: *Drag to move* (a ghost joystick), *Stay close* (nearest Boar), *Grab steaks* (a ground steak). Day 1: *Take steaks* (freezer), *Stock counter* (counter), *Collect gold* (gold pile), *Build here* (the cheapest affordable spot), *Close up* (the sign). Each appears only while its condition holds; see §6. | IDEA core loop | D-213 |
| How is juice kept cheap? | One `FxField`: a MultiMesh of camera-facing quads with a small atlas, animated on the CPU in `_process`. It is one draw call for every particle in the game. No GPUParticles (one draw each), no Label3D pop-ups. Screen shake moves only the camera rig's offset. | D-201 | D-214 |
| Which reactions? | See §5.2. Every reaction is triggered from an existing EventBus signal or an existing visual call. None adds a physics tick, a timer the game waits on, or an Rng draw. | S1 rules | D-214 |
| What about the first-wave stall? | It is first-use cost: shaders compile and pooled nodes draw for the first time when the first Boar, steak, projectile and FX appear. A `Warmup` step during boot draws one of each off-screen for two frames behind the boot fade, and prewarms the FxField and audio players. | D-199 known issue | D-215 |
| What does the HUD pass change? | Positions only, and only to fix known problems: every HUD block sits inside the safe area; the card strip moves clear of the diner bar; world labels fade out when they would sit under a HUD block; a settings gear sits top-right inside the edge strip. The joystick gets palette colours. | REVIEW_QUEUE, S4 notes | D-216 |
| How does New game work? | Settings panel → "New game" → the button turns into "Really? Tap again" for 3 s → wipes the save and calls the existing `debug_fresh_start` path (renamed `fresh_start`). The panel pauses the tree like FocusPause does; closing it resumes. | D-177 | D-217 |
| What are the gates? | Baseline identical; unit and sim green; validator green including audio; night-3 median ≥ 58 fps on an idle Mac; first-wave worst frame < 60 ms; size gates; a shot review per visual task. Audio is checked by state, not by ear: buses, players, no console errors on web. | D-159, D-196, D-209 | D-218 |

## 4. Audio (P1)

### 4.1 Files and layout

- `assets/kenney-<pack>-audio/` holds only the files used, plus `LICENSE.txt`.
- `assets/oga-music/<slug>/` holds the re-encoded track, the saved `LICENSE.txt` (the page's CC0 statement, author
  and URL), and the original file name in the licence row.
- `art/audio/audio_manifest.gd` (class `AudioManifest`):

  ```
  const SFX := {&"hit": {"path": "...ogg", "volume_db": -6.0, "pitch_spread": 0.08, "min_gap_s": 0.05}, ...}
  const MUSIC := {&"day": {"path": "...ogg", "volume_db": -14.0}, &"night": {...}}
  ```

  It is the single place where a sound or a track is chosen.
- ASSET_LICENSES gets one row per audio pack and one per music track.
- **Validator additions:**
  - `.ogg`, `.mp3` and `.wav` are allowed only under `assets/`;
  - every manifest path exists;
  - the summed size of the files the manifest names is at most 2.5 MB;
  - music is Ogg Vorbis.

### 4.2 Choosing sounds without ears

Task 1 picks each SFX by pack, file name and measured properties (`ffprobe` duration, `ffmpeg volumedetect` peak
and mean), with these rules:
- under 0.6 s for repeated sounds (hit, pickup, coin);
- under 1.5 s for single events;
- no clipping;
- similar loudness after `volume_db`.

A table of event, file, duration, peak and reason goes in the PR body and in `docs/review/AUDIO.md`, so the author
can audit and swap. REVIEW_QUEUE gets one high entry: "all audio was chosen without listening".

### 4.3 `AudioDirector` (`world/audio/audio_director.gd`, a Node in Main)

- **Players:** a pool of 10 `AudioStreamPlayer`s on an `SFX` bus, and two on a `Music` bus for a 1.0 s crossfade.
- **`play(id: StringName)`:** drops the sound if the same id played less than `min_gap_s` ago. Pitch is
  `1.0 + pitch_spread * seq`, where `seq` cycles through a fixed table (-1, 0.5, -0.5, 1, 0). No randomness.
- **Event map** (EventBus signal → SFX id):

  | Signal or call | SFX id |
  |---|---|
  | `Attacker.fired` (hero) | `throw` |
  | Boar `take_hit` (through the visual `hit()`) | `hit` |
  | `enemy_killed` | `poof` |
  | `steak_picked` | `pickup` |
  | `stocks_changed` (counter gained) | `stock` |
  | `steak_sold` | `coin` |
  | `gold_changed` (delta > 0 from the pile) | `collect` |
  | `building_changed` (paid > 0) | `build_tick` |
  | `build_completed` | `build_done` |
  | `card_offered` | `card_open` |
  | `card_picked` | `card_pick` |
  | `wave_incoming` | `horn` |
  | `wave_cleared` | `wave_clear` |
  | `diner_damaged` | `diner_hit` |
  | `night_failed` | `fail` |
  | `phase_changed` → DAWN | `dawn` (jingle) |
  | `guard_knocked_out` / `guard_revived` | `guard_down` / `guard_up` |
  | UI button press | `click` |

- **Music:** `phase_changed` → NIGHT plays `night`; DAWN and DAY play `day`. It crossfades and loops.
- **Unlock and mute:** as D-212. Before unlock, `play()` and music requests are dropped; music starts with the
  current phase's track at unlock.
- **Headless and tests:** the director works with the dummy audio driver. It exposes `last_played: Array` (ring of
  the last 16 ids), `music_id`, `unlocked` and `muted` for tests.
- **Pause:** SFX and music players use `PROCESS_MODE_ALWAYS` for UI clicks; music keeps playing in the settings
  panel, and FocusPause (tab hidden) pauses the music bus.

## 5. Juice (P2)

### 5.1 `FxField` (`art/fx/fx_field.gd`, class `FxField`, one MultiMeshInstance3D owned by World)

- **Capacity:** 192 quads. A free-list.
- **One texture:** `art/fx/fx_atlas.png`, 4 cells (puff, spark, star, dust), generated by a tool script, in palette
  colours.
- **Per particle:** position, velocity, gravity, life, size curve (grow then shrink), colour, cell. `_process`
  integrates and writes the instance transform, colour and custom data. Dead quads get zero scale.
- **API:** `burst(kind: StringName, at: Vector3, count: int)`, with kinds defined in a table: `poof` (8 puffs,
  enemy snout pink to white), `hit` (3 sparks), `sparkle` (6 gold stars), `dust` (2 puffs), `coin` (4 gold stars).
  The motion table uses a fixed direction set per kind, rotated by a per-burst counter. No randomness.
- **Billboarding:** the quad faces the camera through the shader (`MODEL_MATRIX` billboard), unshaded, alpha
  blended, no depth write.

### 5.2 Reactions

| Event | Reaction |
|---|---|
| Boar hit | `hit` burst at the Boar; existing flash and squash. |
| Boar killed | `poof` burst; the existing death squash; the steak appears as today. |
| Steak picked | the existing fly arc; a 6% squash pulse on the carry stack. |
| Counter stocked / sold | `coin` burst at the counter on a sale; the traveler does a small hop (visual Body only). |
| Gold collected | `sparkle` burst at the pile; the HUD coin icon punches (the existing gold punch, also on the icon). |
| Build paid | `dust` at the spot every 4th tick. |
| Build completed | `sparkle` burst; the existing pop. |
| Diner damaged | screen shake 0.12 s, amplitude 0.12 m; the diner bar flashes `enemy_red` for 0.15 s. |
| Diner fell | screen shake 0.4 s, amplitude 0.3 m. |
| Wave incoming | the telegraph flag pulses twice; the lane arrow punches. |
| Dawn | every guard and the hero cheer (exists); a `sparkle` burst over the diner. |
| Card picked | the card strip cell pops 1.25× for 0.15 s. |
| Hero running | `dust` puff every 0.35 s of movement, at the feet. |

**Screen shake** lives in the camera rig as an additive offset with exponential decay. It is driven by a fixed
offset table, not randomness. `Balance.ui.shake_enabled` exists for tests and capture (`capture.gd` turns it off).

### 5.3 UI motion

- **Banner:** slides down 24 px and fades in over 0.15 s.
- **Card pick:** the three cards rise 40 px and fade in, staggered by 0.06 s. Input is accepted only after the last
  card lands; the existing input guard time already covers it, so it is not lengthened.
- **Buttons:** scale to 0.94 on press.
- **All durations** live in `ui_tuning`.

### 5.4 Warm-up (D-215)

`world/warmup.gd` runs once at boot, before the first phase starts:
- It instances one Boar visual, one steak in the PickupField, one knife and one arrow projectile, one of each FxField
  cell, a tower L1 and a fence L1, at a spot behind the camera.
- It waits two rendered frames, then frees or resets them.
- It plays a silent sample through each audio bus once unlock has happened.
- **Boot fade:** the game's first frame fades in from the theme's `night_sky` over 0.3 s, so the warm-up is never
  seen.
- **Gameplay identity:** the warm-up uses visuals only, outside pools, and never touches GameState, pools or Rng.

## 6. Onboarding `Guide` (P4)

- **Node:** `ui/guide/guide.gd`, a Node in Main. It owns one pointer (`art/fx/pointer.tscn`: a bouncing arrow mesh,
  unshaded gold, with a WorldLabel under it) and, for the first step, a ghost joystick drawn on a CanvasLayer.
- **Rules:** an ordered list. Each rule has `id`, `text` (through `tr`), `when(state) -> bool`,
  `target(world) -> Vector3` and `done(state) -> bool`. The Guide shows the first rule whose `when` is true and
  whose `done` is false. It evaluates four times a second, not every frame.

  | id | Text | Shown while | Target | Done when |
  |---|---|---|---|---|
  | `move` | Drag to move | night 1, hero has moved < 2 m | ghost joystick, lower third | hero moved 2 m |
  | `fight` | Stay close | night 1, a Boar is alive, 0 kills | nearest Boar | first kill |
  | `grab` | Grab steaks | night 1 or day 1, a ground steak exists, 0 picked | nearest ground steak | first steak picked |
  | `take` | Take steaks | day 1, carrying 0, freezer > 0, counter not full | freezer | carrying > 0 |
  | `stock` | Stock counter | day 1, carrying > 0 | counter | counter gained steaks |
  | `collect` | Collect gold | day 1, gold pile > 0 | gold pile | gold collected once |
  | `build` | Build here | day 1, gold ≥ the cheapest spot's cost, nothing built | that spot | first payment |
  | `close` | Close up | day 1, after the first build or 60 s of day | the sign | night 2 starts |

- **Completion:** when night 2 starts, `guide_done` is saved, and the Guide frees itself.
- **A returning player** (`guide_done` true) never gets a Guide node.
- **Never blocks:** the pointer has no collision, the label is a WorldLabel, and the ghost joystick ignores input.
- **Debug:** `?guide=1` on debug builds forces the Guide on; `?guide=0` turns it off.

## 7. UI polish (P3)

- **Settings button:** a 72 px gear, top-right, inside the safe area and inside the joystick's right edge strip
  (the strip already ignores touches for movement). It opens the settings panel.
- **Settings panel:** a centred cream panel with:
  - **Sound** (toggle);
  - **New game** (two-step confirm, D-217);
  - **Close**.

  It sits on a CanvasLayer above the card overlay, pauses the tree, and owns touches the way the card overlay does.
- **Joystick skin:** the base ring in `ink` at 25% alpha with a `warm_white` rim; the knob in `warm_white` at 80%.
- **HUD safe-area pass:**
  - every HUD block (coin and counter, day and moons and bar, card strip, gear) is positioned from
    `SafeArea.insets`;
  - the card strip sits 12 px below the lowest of the coin row and the diner bar.
- **World labels under the HUD:** a WorldLabel whose screen position falls inside a HUD block's rect (grown 8 px)
  fades to alpha 0.15. Checked four times a second.
- **Layout numbers** live in `ui_tuning`.

## 8. Hot files and wiring

These files take wiring from the main session (D-139, D-181):
- **`world/main.gd`:** AudioDirector, SettingsStore, Guide, the settings panel, Warmup, `fresh_start`.
- **`world/world.gd`:** FxField.
- **`world/camera_rig.gd`** is not hot, but it is shared: the shake.
- **`balance/ui_tuning.gd`:** every new number.
- **`project.godot`:** the audio bus layout (`default_bus_layout.tres`).
- **`export_presets.cfg`:** nothing expected.
- **`.github/workflows/pages.yml`:** nothing expected.
- **`CLAUDE.md`:** the layout line for `art/audio`, `art/fx`, `world/audio`, `ui/guide`, `ui/settings`.

## 9. Testing and verification

- **Unit:**
  - **SettingsStore:** defaults; round trip; a corrupt value gives defaults; it is separate from the save key; New
    game leaves it alone.
  - **AudioDirector:**
    - each mapped signal records its id in `last_played`;
    - `min_gap_s` drops repeats;
    - the pitch table cycles;
    - nothing plays before unlock;
    - music follows the phase and crossfades;
    - mute sets the Master bus and persists.
  - **The manifest:** every path exists; the audio budget; the validator rules.
  - **FxField:** `burst` fills quads; life ends them; capacity is never exceeded; one MultiMesh; no randomness
    (two identical burst sequences give identical transforms).
  - **Reactions:** each event in §5.2 calls its burst or shake (through recorded calls).
  - **Screen shake:** decays to zero; never moves the hero or gameplay nodes; off when `shake_enabled` is false.
  - **Warm-up:** leaves GameState, pools and Rng untouched; frees everything.
  - **Guide:**
    - each rule shows and completes under its conditions;
    - the order;
    - `guide_done` persists and suppresses the Guide;
    - it never consumes input.
  - **Settings panel:** pause and resume; the two-step confirm; New game calls `fresh_start` and keeps settings.
  - **HUD:** blocks inside the safe area for three inset sets; the strip gap; the label fade under the HUD.
- **Sims:** unchanged; under 60 s.
- **Determinism:** `tools/baseline_diff.sh` after every task. The baseline is the S4 one; it must still match.
- **Web checks** (`export/pw_check.mjs` extended):
  - no console error or warning from audio before the first gesture;
  - after a synthetic tap, `AudioDirector.unlocked` is true (read through a debug hook on the `/debug/` build);
  - the mute toggle survives a reload.
- **Shots:** the standard `tools/shots.sh` list per visual task, plus:
  - the settings panel;
  - each Guide step (a `--guide=<id>` capture option);
  - a burst frame per FxField kind.
- **Perf:** the D-209 protocol at the end of P2 and at the end of S5: night-3 median, the first-wave worst frame,
  day 3, and desktop draw calls with FX active.

## 10. Build order (a hint for writing-plans)

| Phase | Branch | Tasks |
|---|---|---|
| P1 Audio | `s5/p1-audio` | 1 audio intake, re-encode, manifest, validator, AUDIO.md; 2 SettingsStore; 3 AudioDirector (SFX, music, unlock, mute) |
| P2 Juice | `s5/p2-juice` | 4 FxField and atlas; 5 reactions and screen shake; 6 UI motion; 7 warm-up and boot fade + **perf checkpoint** |
| P3 UI | `s5/p3-ui` | 8 settings button and panel, New game; 9 joystick skin, HUD safe-area pass, label fade |
| P4 Onboarding | `s5/p4-guide` | 10 Guide rules and pointer; 11 ghost joystick, persistence, web checks |
| P5 Results | `s5/p5-results` | 12 perf, size, web audio checks, results, review queue |

## 11. Risks

| Risk | Mitigation |
|---|---|
| Audio chosen without listening sounds wrong | One manifest; `docs/review/AUDIO.md` lists every choice; top REVIEW_QUEUE entry; conservative volumes (music −14 dB). |
| Web audio crackles or fails in single-threaded builds | Default playback types; no bus effects; check for console errors in Playwright; the fallback is SFX only, with music off by default. |
| FX or audio cost drops night 3 below 58 | One MultiMesh for FX; 10 SFX players; the perf checkpoint at P2; cut `dust` first, then lower the FxField capacity. |
| The warm-up changes gameplay order | It uses no pools and no GameState; the baseline diff proves it. |
| The Guide annoys returning players | `guide_done` is per device; it ends at night 2; `?guide=0` for debug. |
| The settings pause interacts with FocusPause or the card overlay | The panel sits on its own layer, sets a flag FocusPause respects, and is tested with the card overlay open. |

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
