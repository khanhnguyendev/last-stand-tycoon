# S1 Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Routing (author's rule):**
> - Every task is executed by the `implementer` subagent, and every task result gets a `reviewer` pass.
> - Human checkpoints (**CP1, CP2, CP3**) stop all work until the author says continue.
> - Merges (D-137): the main session merges a phase PR itself when CI is green (before CI: the full local suite output is in the PR body), every task passed its reviewer pass, no escalation is open, and the phase doesn't end at a checkpoint. Phases 5 (CP1), 10 (CP2) and 14 (CP3) are merged by the author.
> - Parallel tasks follow D-136 (worktrees, hot files, at most 3 implementers).
> - Device testing (D-138): the iOS Simulator and, when installed, the Android Emulator are primary. The author's phone is used only at CP2 and CP3.
> - An implementer escalation (a failing threshold, a spec contradiction, a missing fact) goes back to
>   the main session. It is never decided inside the task.
> - **Time is not a constraint (D-131).** Scope follows quality and the v0.1 gate, never the calendar.
>   There are no time-based stop rules. If a task turns out bigger than this plan describes (new files, new
>   systems, or steps the plan didn't anticipate), stop and propose a split before continuing.

**Goal:** Build the S1 vertical slice of Last Stand Tycoon: an endless night → dawn → day → close-up loop in Godot 4.7, on the final architecture, with placeholder art. It is proven by headless sims, runs as a mobile web build, and is gated by the author's phone playtest.

**Architecture:**
- Gameplay lives in scene nodes built in code: `World`, `Hero`, `Boar`, stations and build spots.
- Every formula lives in pure static `core/` classes that are unit-tested without a scene.
- There are three autoloads:
  - `EventBus`: cross-system signals;
  - `GameState`: the only mutable game data, changed only through its methods, and serializable
    with `to_dict()`/`from_dict()`;
  - `Balance`: typed `.tres` data.
- `PhaseController` orchestrates NIGHT → DAWN → DAY and owns the in-memory snapshot.
- Randomness comes only from named seeded streams, so the bot-driven sims are deterministic.

**Tech stack:** Godot 4.7 (GDScript, Compatibility renderer, single-threaded Web export), GUT (headless tests), bash, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-30-s1-vertical-slice-design.md`. Rationale lives in `docs/DECISIONS.md` (the D-xxx ids). Executors read the spec section each task cites.

## Global Constraints

- Engine: Godot **4.7**, GDScript only, renderer `gl_compatibility`, and the base viewport is portrait **720×1280** with stretch `canvas_items` and aspect `expand` (D-072).
- Web export: **single-threaded** (`variant/thread_support=false`), custom shell `export/web_shell.html` (D-014, D-077).
- Hosting (D-135): every push deploys to GitHub Pages (`main` at the root, other branches at `preview/<slug>/` (slug = the branch name with every character outside `[A-Za-z0-9._-]` replaced by `-`)). Phone tests and the gate use those URLs. Plain-http LAN doesn't work (D-120).
- Layout (D-032, D-098):
  - game code only in `autoload/ core/ components/ actors/ world/ ui/ balance/`;
  - tests in `tests/unit/` and `tests/sim/`;
  - infra only in `addons/` (GUT), `export/`, `.github/` and `docs/`.
- Autoload file names: `autoload/EventBus.gd`, `autoload/GameState.gd`, `autoload/Balance.gd` (spec 3.1). Autoload scripts never declare `class_name`.
- Units are meters and seconds. North is −z, and the origin is the diner center. XZ positions are passed as `Vector2(x, z)`.
- Every gameplay update runs in `_physics_process` at 60 Hz. Visual-only code (tweens, camera, HUD) may use `_process`.
- Randomness (D-034):
  - It comes only from `Rng.stream(run_seed, day, name)`, with the streams `lane_plan`, `spawns`, `travelers` and `drops`.
  - No `randi(`/`randf(`/`randi_range(`/`randf_range(`/`randomize(`/`RandomNumberGenerator.new(` appears outside `core/rng.gd`. Method calls on a stream (`rng.randi_range`) are fine.
- Ties are broken by `spawn_index`, never by node or group order.
- GameState fields are written only inside `autoload/GameState.gd` (D-096). Tweens never change state.
- EventBus is for cross-system events only; component-to-owner communication uses local signals (D-037).
- Every tunable number lives in `balance/*.gd` defaults (`balance.tres`, `ui_tuning.tres`). No magic gameplay numbers in node scripts.
- Every user-facing string goes through `tr()`, with the English text as the key (D-074). The font is Nunito (OFL), logged in `docs/ASSET_LICENSES.md`.
- Balance literals in tests: only the pinned-reference tests (`test_balance`, `test_wave_math`, `test_economy`, the pool-size row) assert default numbers, and each says so in a comment. Every other test derives its numbers from `Balance.data` / `Balance.ui`, so tuning (Task 35) never breaks a mechanics test.
- Tests: GUT, headless, `--fixed-fps 60`. The sim suite runs in **< 60 s** (D-035). Pass/fail sims assert thresholds, never exact outcomes (D-105).
- The Godot binary is always `$GODOT` (set in Task 0), and every test run goes through `./run_tests.sh [unit|sim|all]`.
- Commits: conventional prefixes (`feat:`, `test:`, `chore:`, `docs:`), ending with the session's attribution lines.

## Review Focus

These are the input classes the spec implies but no feature test naturally covers. Each has a pinned test in its owning task.

1. **Snapshot through JSON** (S3 will serialize it): ints come back as floats. `from_dict(JSON.parse_string(JSON.stringify(to_dict())))` must restore an identical state, with ints still ints. Pinned in **Task 10**.
2. **A projectile in flight when its target dies and the pooled Boar is reused** for a new spawn: the projectile must despawn and never damage the new Boar. Pinned in **Task 16**.
3. **The diner falls on the same tick that wave 3 clears:** the fail flow wins, there is no dawn, and a late `wave_cleared(2)` is ignored. Pinned in **Task 17**.
4. **A second finger, or a touch that starts in a 16 px edge strip:** it is ignored. Lifting the second finger doesn't stop the joystick. Pinned in **Task 27**.
5. **Paying with less gold than the drain, or standing on a level-3 spot:** the spot takes only what's there (gold never goes negative), and a max-level spot takes nothing. Pinned in **Task 23**.

## Git Workflow (D-133)

- **One branch and one PR per phase**, branched from an up-to-date `main` after the previous phase's PR is merged. **One commit per task** inside it.

  | Phase | Branch |
  |---|---|
  | 0 | `s1/p0-spike` |
  | 1 | `s1/p1-bootstrap` |
  | 2 | `s1/p2-core` |
  | 3 | `s1/p3-state` |
  | 4 | `s1/p4-night-loop` |
  | 5 | `s1/p5-sims` |
  | 6 | `s1/p6-day` |
  | 7 | `s1/p7-planner` |
  | 8 | `s1/p8-restore` |
  | 9 | `s1/p9-input-hud` |
  | 10 | `s1/p10-web` |
  | 11 | `s1/p11-screenshots-ci` |
  | 12 | `s1/p12-tuning` |
  | 13 | `s1/p13-perf` |
  | 14 | `s1/p14-gate` |

- **Reviews:** the `reviewer` subagent reviews every task before its commit counts as done. The author reviews the checkpoint phases' PRs (5, 10, 14) and may review any other.
- **Before CI exists** (Phases 0–10), the PR body carries the local test output: `./run_tests.sh all`, or the spike results for Phase 0. **After CI lands** (Phase 11), `unit` and `sim` must be green before asking for review.
- **Merge policy (D-137).** The main session may merge a phase PR into `main` itself, with a merge commit (never squash), when ALL of these hold:
  - CI is green (before CI exists: the full local suite output is in the PR body);
  - every task in the phase passed its reviewer pass;
  - there are no open escalations;
  - the phase doesn't end at a checkpoint.

  Phases ending at CP1 (Phase 5, Task 20), CP2 (Phase 10, Task 32) and CP3 (Phase 14, Task 37) stay open for the author to review and merge. After each self-merge, post a PR comment of at most 5 lines: what shipped, tests, decisions. Agents never push to `main` directly and never change branch protection. After CI lands, Task 34 hands the author the exact `gh` command to protect `main`.
- **Parallel tasks (D-136).**
  - Tasks run in parallel only when their file sets are disjoint.
  - Hot files are always serialized: `project.godot`, `CLAUDE.md`, `autoload/EventBus.gd`, `autoload/GameState.gd`, `balance/*.gd` and `*.tres`, `world/main.gd`, `world/main.tscn`, `world/world.gd`, `run_tests.sh`, `.github/workflows/*`. A parallel task that needs a small hot-file edit leaves it out; the main session applies those edits afterwards, one at a time.
  - At most 3 `implementer` subagents at once, each in its own git worktree on a task branch `s1/p<N>-t<NN>-<slug>` cut from the phase branch. Each worktree runs its own Godot import (its own `.godot/`); shared gitignored inputs are symlinked, never copied.
  - Every task keeps the full flow: TDD, verification with pasted output, a reviewer pass (reviewers may run in parallel).
  - Integration: after a task passes review, merge its task branch into the phase branch with `--no-ff` (one task commit preserved), then run the FULL suite on the phase branch before merging the next task. If it fails, stop merging and debug on the phase branch first (systematic-debugging).
  - Merge conflicts are resolved by the main session, never by an implementer; a conflict in a hot file or in design intent is escalated to the author.
  - A task that runs alone commits directly on the phase branch (no worktree).
- **Device testing (D-138).** The iOS Simulator (Safari on a notch iPhone) and, when installed, the Android Emulator (Chrome) are the primary devices, on `http://localhost` (a secure context) or the Pages preview URL. They are scripted with `export/device_check.sh` (Task 32), and results are read from screenshots. Never install system components; when a runtime is missing, give the author the one-time install step. The author's phone is used only at CP2 and CP3.

## Checkpoints and Estimates

Stop at each checkpoint and wait for the author:

| # | Where | What the author reviews |
|---|---|---|
| CP1 | end of Task 20 | Quality review only: headless night loop and night sims green, the sim output plus the `docs/screenshots/s1/cp1_night1.png` render |
| CP2 | end of Task 32 | Input, camera, HUD and web shell on the author's phone (the branch's GitHub Pages preview URL, D-135) |
| CP3 | Task 37, Step 2 | Before the gate playtest from the Pages URL (D-135); the phone numbers for criteria 4 and 6 are taken in the same session (D-138) |

Estimates in working days, **for information only** (D-131: no deadline; nothing is stopped or cut because of them):

| Phase | Tasks | Days |
|---|---|---|
| 0 Spike | 0 | 0.5 |
| 1 Bootstrap | 1–2 | 1.0 |
| 2 Core modules | 3–9 | 1.5 |
| 3 State and skeleton | 10–12 | 1.0 |
| 4 Night loop | 13–18 | 2.5 |
| 5 Bots and night sims (→ CP1) | 19–20 | 1.5 |
| 6 Day systems | 21–24 | 2.0 |
| 7 PlannerBot, night-2 sims, sweep | 25 | 1.0 |
| 8 Restore contract | 26 | 0.5 |
| 9 Input, camera, HUD, feel, focus | 27–31 | 2.5 |
| 10 Web shell and presets (→ CP2) | 32 | 1.0 |
| 11 Screenshots and CI | 33–34 | 0.5 |
| 12 Tuning | 35 | 2.0 |
| 13 Perf and results | 36 | 0.5 |
| 14 Gate (→ CP3) | 37 | 0.5 |
| **Total** | 38 tasks | **18.5 days (about 3.7 weeks)** |

## File Map

| Path | Responsibility | Task |
|---|---|---|
| `.github/workflows/pages.yml`, `export/probe/build_probe.sh` | Pages deploy, safe-area probe (D-135) | 0 |
| `project.godot`, `.gitignore`, `run_tests.sh`, `CLAUDE.md`, `.gutconfig.json` | project config, test runner, agent guide | 1 |
| `addons/gut/` | GUT test framework (third-party) | 1 |
| `balance/*.gd`, `balance/balance.tres`, `balance/ui_tuning.tres` | typed tuning data | 2 |
| `autoload/Balance.gd` | loads and injects tuning data | 2 |
| `core/rng.gd` | FNV-1a seeded streams | 3 |
| `core/wave_math.gd`, `core/wave_schedule.gd` | wave counts, HP, splits, spawn times, clear rule | 4 |
| `core/lane_planner.gd` | seeded lane plan, lane threat | 5 |
| `core/map_layout.gd`, `core/geometry.gd`, `core/enemy_path.gd` | single source of map coordinates, geometry math, Boar path positions | 6 |
| `core/targeting.gd`, `core/economy.gd`, `core/pulse.gd` | target select, costs, sign pulse predicate | 7 |
| `core/waypoint_graph.gd` | bot navigation graph | 8 |
| `core/camera_math.gd` | camera transform and projection (shared by the rig and the tests) | 9 |
| `core/phase.gd`, `autoload/EventBus.gd`, `autoload/GameState.gd` | phase ids, signals, state | 10 |
| `world/visuals.gd`, `ui/world_label/world_label.gd`, `ui/fonts/`, `components/node_pool.gd`, `components/health.gd`, `components/targetable.gd` | placeholder meshes, 3D labels, pooling, HP | 11 |
| `world/main.tscn`, `world/main.gd`, `world/world.gd`, `world/lanes/lane.gd` | scene root (orchestrated nodes and typed @export wiring, D-128), map build | 12 (+13, 14, 16, 17, 22, 30) |
| `actors/enemy/boar.gd`, `actors/pickups/steak.gd`, `world/target_providers.gd` | enemy, steak, target kinds | 13 |
| `world/wave_director.gd` | night waves | 14 |
| `actors/hero/hero.gd`, `actors/hero/hero_input.gd`, `components/magnet.gd`, `components/carry_stack.gd` | hero body, input, pickup | 15 |
| `components/attacker.gd`, `actors/projectile/projectile.gd` | auto-attack, homing shots | 16 |
| `world/phase_controller.gd` | phase flow, snapshot, fail, dawn, close-up | 17 |
| `world/build_spots/build_spot.gd`, `tower_spot.gd`, `fence_spot.gd` | spot visuals, tower combat, fence rubble | 18 |
| `actors/bots/*.gd`, `tests/sim/sim_harness.gd` | bots and sim driver | 19 |
| `tests/sim/test_night_sims.gd` | night sims (CP1) | 20 |
| `components/station_zone.gd`, `ui/progress_ring/*`, `world/stations/freezer.gd`, `world/stations/counter.gd` | stand-still stations | 21 |
| `actors/traveler/traveler.gd`, `world/traveler_spawner.gd`, `world/stations/gold_pile.gd` | buyers and gold | 22 |
| `world/build_spots/build_spot.gd` (pay) | build and upgrade | 23 |
| `world/stations/closeup_sign.gd`, `world/lanes/telegraph_marker.gd` | close-up, pulse, telegraph | 24 |
| `actors/bots/planner_bot.gd`, `tests/sim/test_day_sims.gd`, `tests/sim/sweep.gd` | night-2 sims, sweep | 25 |
| `tests/unit/test_restore_world.gd` | full restore contract | 26 |
| `ui/joystick/joystick.gd` | floating joystick | 27 |
| `world/camera_rig.gd` | follow camera and shake | 28 |
| `ui/hud/hud.gd`, `ui/hud/safe_area.gd` | HUD | 29 |
| `world/fx/fly_fx.gd` | transfer arcs, pops, flashes | 30 |
| `world/focus_pause.gd` | pause on focus loss | 31 |
| `export/web_shell.html`, `export_presets.cfg`, `ui/debug/debug_overlay.gd`, `ui/perf_overlay.gd`, `export/README.md`, `ui/build_label.gd` | web build, presets, overlays (CP2) | 32 |
| `tests/sim/lane_screenshots.gd` | per-lane screenshots | 33 |
| `.github/workflows/ci.yml` | CI | 34 |
| `balance/*.gd` defaults, `docs/DECISIONS.md` | tuning | 35 |
| spec §16 | results | 36–37 |

---

## Phase 0: Spike

### Task 0: Spike on the Godot 4.7 toolchain (D-104, D-131, D-135)

**Goal:** answer spec Appendix B plus the tool facts this plan depends on. The probe project itself is throwaway. What remains: the installed toolchain, the DECISIONS entries, and (D-135) the Pages workflow plus the safe-area probe script.

**Branch (D-133):** `s1/p0-spike`, from `main` after PR #1 is merged. The PR body carries the spike results (D-116 to D-120).

**Stop rule (D-131, no timebox):** work through the checks in order. When a check fails, apply its pre-agreed fallback. Escalate only when the fallback also fails.

**Files:**
- Create (throwaway, outside the repo): `$SPIKE=/tmp/lst-spike/`
- Create (D-135): `.github/workflows/pages.yml`, `export/probe/build_probe.sh` (their own commit, before the results commit)
- Modify: `docs/DECISIONS.md` (append D-116 to D-120, and D-135)
- One-time repo setting (D-135): GitHub Pages source = "Deploy from a branch", `gh-pages`, `/ (root)`, enabled after the first `pages` run creates `gh-pages`. D-119 is read from the probe on the Pages URL in the iOS Simulator, and confirmed on the author's phone at CP2.

- [ ] **Step 1: Install Godot 4.7 and its export templates (outside the repo), checksum-verified (D-129)**

Official sources only: the `godotengine/godot-builds` GitHub releases, which godotengine.org links to. Every archive is checked against the release's published `SHA512-SUMS.txt`, and the script stops on any mismatch.

```bash
set -euo pipefail
# Find the newest 4.7.x stable tag
curl -fsS "https://api.github.com/repos/godotengine/godot-builds/releases?per_page=50" \
  | grep '"tag_name"' | grep -E '"4\.7(\.[0-9]+)?-stable"' | head -1
# Suppose it prints 4.7-stable. Use that EXACT tag below; it becomes the pinned GODOT_TAG (D-129).
TAG=4.7-stable
BASE="https://github.com/godotengine/godot-builds/releases/download/$TAG"
EDITOR_ZIP="Godot_v${TAG}_macos.universal.zip"
TEMPLATES="Godot_v${TAG}_export_templates.tpz"
DEST="$HOME/Applications/Godot-$TAG"
mkdir -p "$DEST" && cd "$DEST"
curl -fL -o SHA512-SUMS.txt "$BASE/SHA512-SUMS.txt"
curl -fL -o "$EDITOR_ZIP" "$BASE/$EDITOR_ZIP"
curl -fL -o "$TEMPLATES" "$BASE/$TEMPLATES"
grep -E "[[:space:]]\*?(${EDITOR_ZIP}|${TEMPLATES})\$" SHA512-SUMS.txt > wanted.sha512
[ "$(wc -l < wanted.sha512 | tr -d ' ')" = "2" ] || { echo "FAIL: checksum lines missing for $TAG"; exit 1; }
shasum -a 512 -c wanted.sha512 || { echo "FAIL: SHA-512 mismatch, do not use these files"; exit 1; }
unzip -q -o "$EDITOR_ZIP"
TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/${TAG/-/.}"
mkdir -p "$TPL_DIR"
rm -rf /tmp/lst-templates && unzip -q "$TEMPLATES" -d /tmp/lst-templates
cp -R /tmp/lst-templates/templates/* "$TPL_DIR/"
export GODOT="$DEST/Godot.app/Contents/MacOS/Godot"
"$GODOT" --version
```

Expected:
- `shasum` prints `…: OK` for both files;
- the version line starts `4.7.` and ends `.stable.official...`.

If there is no 4.7 stable, or a checksum fails, **stop and escalate**. Don't pick another version or source.

- [ ] **Step 2: Build a probe project with GUT**

```bash
mkdir -p /tmp/lst-spike/tests && cd /tmp/lst-spike
GUT_TAG=$(curl -s https://api.github.com/repos/bitwes/Gut/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
echo "GUT $GUT_TAG"
curl -fL -o gut.zip "https://github.com/bitwes/Gut/archive/refs/tags/$GUT_TAG.zip" && unzip -q gut.zip
mkdir -p addons && cp -R Gut-*/addons/gut addons/gut
cat > project.godot <<'CFG'
config_version=5
[application]
config/name="spike"
[autoload]
Probe="*res://probe.gd"
[physics]
common/physics_ticks_per_second=60
CFG
cat > probe.gd <<'GD'
extends Node
var ticks := 0
func _physics_process(_d: float) -> void:
	ticks += 1
GD
cat > tests/test_probe.gd <<'GD'
extends GutTest
func test_autoload_present() -> void:
	assert_not_null(get_node_or_null("/root/Probe"))
func test_fixed_fps_speed() -> void:
	var start_ms := Time.get_ticks_msec()
	var start_ticks: int = get_node("/root/Probe").ticks
	for i in 3600:
		await get_tree().physics_frame
	var ms := Time.get_ticks_msec() - start_ms
	gut.p("3600 physics ticks took %d ms" % ms)
	assert_eq(get_node("/root/Probe").ticks - start_ticks, 3600)
	assert_lt(ms, 20000)
func test_projection_math() -> void:
	var p := Projection.create_perspective(42.0, 720.0 / 1280.0, 0.1, 200.0, true)
	var c := p * Vector4(0, 0, -10, 1)
	assert_almost_eq(c.x / c.w, 0.0, 0.0001)
GD
"$GODOT" --headless --path . --import ; echo "import exit=$?"
"$GODOT" --headless --path . --fixed-fps 60 -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit ; echo "gut exit=$?"
```

Record:
- (a) whether `--import` exists (exit 0) or you needed `--editor --quit`;
- (b) the GUT tag;
- (c) the "3600 physics ticks took N ms" line;
- (d) that the autoload test passes;
- (e) that the projection test passes.

Apply the pre-agreed fallbacks:
- GUT fails to load on 4.7 → try the previous GUT tag, then gdUnit4. If both fail, write a minimal runner and escalate before doing so.
- 3600 ticks take ≥ 20 s (so `--fixed-fps` isn't unthrottled) → re-run with `Engine.time_scale = 8.0` and `Engine.max_physics_steps_per_frame = 16` set in the test, and record which one works.

- [ ] **Step 3: Web probe for the safe area and plain-http LAN**

```bash
cd /tmp/lst-spike
cat > web_probe.gd <<'GD'
extends Control
func _ready() -> void:
	var l := Label.new(); l.add_theme_font_size_override("font_size", 34); l.position = Vector2(24, 220); add_child(l)  # below any notch
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var css := ""
	if OS.has_feature("web"):
		css = str(JavaScriptBridge.eval("(function(){var d=document.createElement('div');d.style.cssText='position:fixed;padding-top:env(safe-area-inset-top);padding-bottom:env(safe-area-inset-bottom)';document.body.appendChild(d);var s=getComputedStyle(d);var r=s.paddingTop+','+s.paddingBottom+','+window.isSecureContext;d.remove();return r;})()", true))
	l.text = "safe=%s\nwin=%s\ncss(top,bottom,secure)=%s" % [safe, win, css]
GD
printf '[gd_scene format=3]\n[ext_resource type="Script" path="res://web_probe.gd" id="1"]\n[node name="P" type="Control"]\nscript = ExtResource("1")\n' > web_probe.tscn
printf '\n[application]\nrun/main_scene="res://web_probe.tscn"\n' >> project.godot
cat > export_presets.cfg <<'CFG'
[preset.0]
name="web"
platform="Web"
runnable=true
export_filter="all_resources"
exclude_filter="tests/*, addons/gut/*"
export_path="build/index.html"
[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
html/canvas_resize_policy=2
CFG
mkdir -p build && "$GODOT" --headless --path . --export-release "web" build/index.html ; echo "export exit=$?"
ls -la build
cd build && python3 -m http.server 8000 --bind 0.0.0.0
```

**HUMAN step (the author, about 2 minutes).** The implementer first runs `ipconfig getifaddr en0` (or `en1` on some Macs) and sends the author the exact URL, for example `http://192.168.1.23:8000/`. Then the author:

1. Puts the phone on the **same Wi-Fi** as the Mac.
2. Opens **Safari** (iPhone) or **Chrome** (Android) and types the URL exactly, starting with `http://`, not `https://`. Taps Go.
3. Waits up to 60 s for the loading bar to finish. Taps nothing else; there is no button in the probe.
4. Looks at the three white lines of text, about a third of the way down the screen:
   - `safe=[P: (x, y), S: (w, h)]`
   - `win=(w, h)`
   - `css(top,bottom,secure)=<top>px,<bottom>px,<true|false>`
5. If the screen stays black, shows a loading bar that never finishes, or shows an error: copy the error text, or write "black".
6. Replies with exactly one line:

```
SPIKE phone=<model> browser=<Safari|Chrome> <version> loaded=<yes|no> safe=<text after "safe="> win=<text after "win="> css=<text after "="> notes=<error text or none>
```

For example: `SPIKE phone=iPhone 13 browser=Safari 18 loaded=yes safe=[P: (0, 141), S: (1170, 2391)] win=(1170, 2532) css=47px,34px,false notes=none`

While the author does this, the implementer opens the same URL in desktop Chrome and notes the console errors.

Apply the fallbacks:
- The page fails over http on the phone → phone tests use the HTTPS GitHub Pages URL (D-135, amends D-083).
- `safe=` equals the full window while CSS `env()` shows a nonzero top on a notched phone → the web safe area uses the CSS path (D-077).

- [ ] **Step 4: Log the results and clean up**

Append to `docs/DECISIONS.md` under a new heading `## <date>: S1 Task 0 spike results`:

| Id | Records |
|---|---|
| **D-116** | The exact Godot tag (for example `4.7-stable`), now the pinned `GODOT_TAG`; the `$GODOT` path; SHA-512 verified; export templates installed. |
| **D-117** | The GUT tag, or the fallback used. The import command that works. |
| **D-118** | The sim stepping method (`--fixed-fps` or the `time_scale` fallback) and the measured ms per 3600 ticks. |
| **D-119** | The web safe-area source (DisplayServer or CSS env). |
| **D-120** | Whether LAN over http works (yes, or Pages-only per D-135). |

Then (the D-135 hosting commit, `ci: deploy web builds to GitHub Pages ...`, already holds `pages.yml`, `export/probe/build_probe.sh` and D-135):

```bash
rm -rf /tmp/lst-spike /tmp/lst-templates
cd /Users/ryan/ws/1.GAME/last-stand-tycoon
git add docs/DECISIONS.md
git commit -m "docs: log S1 toolchain spike results"
```

**If Task 1 onward needs a different command than written here** (for example the import flag), use the one D-117 or D-118 records. Every later "Run:" line assumes the defaults: `--import` and `--fixed-fps 60`.

---

## Phase 1: Project bootstrap

### Task 1: Godot project, GUT, test runner, CLAUDE.md

**Files:**
- Create: `project.godot`, `.gutconfig.json`, `run_tests.sh`, `CLAUDE.md`, `addons/gut/` (copied), `tests/unit/test_smoke.gd`, `world/main.tscn`, `world/main.gd` (stub)

**Interfaces:**
- Produces:
  - `./run_tests.sh unit|sim|all`, which exits non-zero on any failure;
  - the autoload names `EventBus`, `Balance`, `GameState`. Their files are created in Tasks 2 and 10; this task registers them with stub files.

- [ ] **Step 1: Copy GUT at the tag from D-117**

```bash
cd /Users/ryan/ws/1.GAME/last-stand-tycoon
GUT_TAG=<tag from D-117>
curl -fL -o /tmp/gut.zip "https://github.com/bitwes/Gut/archive/refs/tags/$GUT_TAG.zip"
unzip -q /tmp/gut.zip -d /tmp/gut && mkdir -p addons && cp -R /tmp/gut/Gut-*/addons/gut addons/gut && rm -rf /tmp/gut /tmp/gut.zip
```

- [ ] **Step 2: Write `project.godot`**

```ini
; Engine configuration file.
config_version=5

[application]
config/name="Last Stand Tycoon"
run/main_scene="res://world/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[autoload]
EventBus="*res://autoload/EventBus.gd"
Balance="*res://autoload/Balance.gd"
GameState="*res://autoload/GameState.gd"

[display]
window/size/viewport_width=720
window/size/viewport_height=1280
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1

[input_devices]
pointing/emulate_mouse_from_touch=false

[physics]
common/physics_ticks_per_second=60
common/max_physics_steps_per_frame=8

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

The autoload order matters: `EventBus`, then `Balance`, then `GameState`, because GameState reads Balance and emits on EventBus.

- [ ] **Step 3: Stub the autoloads so the project boots (Tasks 2 and 10 replace them)**

```bash
mkdir -p autoload
printf 'extends Node\n' > autoload/EventBus.gd
printf 'extends Node\n' > autoload/Balance.gd
printf 'extends Node\n' > autoload/GameState.gd
```

- [ ] **Step 4: Write the main scene stub**

`world/main.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://world/main.gd" id="1_main"]

[node name="Main" type="Node3D"]
script = ExtResource("1_main")
```

`world/main.gd`:
```gdscript
class_name Main
extends Node3D
## Scene root. Builds the game in code (see spec 3.3). Extended in Tasks 12, 15, 17, 27–32.

@export var auto_start := true
```

- [ ] **Step 5: Write `.gutconfig.json` and `run_tests.sh`**

`.gitignore` already exists (committed with the plan). Don't overwrite it; check that it ignores `.godot/`, `build/` and `tests/sim/out/`:

```bash
for p in .godot/ build/ tests/sim/out/; do grep -qx "$p" .gitignore && echo "ok $p" || echo "MISSING $p"; done
```

`.gutconfig.json`:
```json
{ "dirs": ["res://tests/unit", "res://tests/sim"], "include_subdirs": true, "prefix": "test_", "suffix": ".gd", "should_exit": true, "log_level": 1 }
```

`run_tests.sh`:
```bash
#!/usr/bin/env bash
# Usage: ./run_tests.sh [unit|sim|all|--quick]. Requires $GODOT (Godot 4.7 binary, see docs/DECISIONS.md D-116).
# --quick = unit + night-1 sims, for local loops (D-132). CI always runs the full unit and sim suites.
# Fails on test failures AND on GUT errors (missing scripts, parse errors, nothing run).
# .gutconfig.json is ignored by this runner (-gconfig=); dirs come from the flags below.
set -euo pipefail
cd "$(dirname "$0")"
SELF="$PWD/$(basename "$0")"
: "${GODOT:?Set GODOT to the Godot 4.7 binary path}"
SUITE="${1:-all}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
run_gut() {
  local log rc; log="$(mktemp)"
  trap 'rm -f "$log"' RETURN INT TERM
  set +e
  "$GODOT" --headless --path . --fixed-fps 60 -s res://addons/gut/gut_cmdln.gd \
    -gconfig= -ginclude_subdirs -gprefix=test_ "$@" -gexit 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -eq 0 ] && sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E '^Errors[[:space:]]+[1-9]|Could not find script|could not be loaded|\[GUT ERROR\]:.*does not exist\.|Nothing was run|SCRIPT ERROR' >/dev/null; then
    echo "GUT reported errors (see above); failing"; rc=1
  fi
  trap - RETURN INT TERM
  rm -f "$log"; return "$rc"
}
case "$SUITE" in
  unit) run_gut -gdir=res://tests/unit ;;
  sim)
    if [ -z "$(find tests/sim -name 'test_*.gd' -print -quit 2>/dev/null)" ]; then echo "SIM SUITE: no sim tests yet"; exit 0; fi
    start=$SECONDS
    rc=0; run_gut -gdir=res://tests/sim || rc=$?
    elapsed=$((SECONDS - start))
    echo "SIM SUITE: ${elapsed}s (budget 60s)"
    [ "$rc" -eq 0 ] || exit "$rc"
    if [ "$elapsed" -gt 60 ]; then echo "SIM SUITE OVER BUDGET"; exit 1; fi ;;
  all) "$SELF" unit && "$SELF" sim ;;
  --quick)
    run_gut -gdir=res://tests/unit && run_gut -gtest=res://tests/sim/test_night_sims.gd ;;
  *) echo "usage: $0 [unit|sim|all|--quick]"; exit 2 ;;
esac
```

```bash
chmod +x run_tests.sh
mkdir -p tests/unit tests/sim
```

`run_tests.sh` fails on any GUT error (a script that doesn't parse, a missing file or directory, "Nothing was run"), not only on failed asserts, because GUT itself exits 0 for those. It passes `-gconfig=` so `.gutconfig.json` (editor panel only) never adds directories. `tests/sim/.gitkeep` keeps the sim dir in fresh clones. (Task 1 review amendment.)

- [ ] **Step 6: Write a failing smoke test**

`tests/unit/test_smoke.gd`:
```gdscript
extends GutTest

func test_autoloads_registered() -> void:
	assert_not_null(get_node_or_null("/root/EventBus"))
	assert_not_null(get_node_or_null("/root/Balance"))
	assert_not_null(get_node_or_null("/root/GameState"))

func test_physics_rate_is_60() -> void:
	assert_eq(Engine.physics_ticks_per_second, 60)

func test_main_scene_loads() -> void:
	var scene: PackedScene = load("res://world/main.tscn")
	assert_not_null(scene)
```

Temporarily rename `autoload/GameState.gd` to `autoload/GameState.gd.off` and run:

`./run_tests.sh unit`

Expected: FAIL on `test_autoloads_registered` (GameState missing). Rename it back.

- [ ] **Step 7: Run and see it pass**

Run: `./run_tests.sh unit`

Expected: exit 0, with 3 passing tests and 0 failing.

- [ ] **Step 8: Write `CLAUDE.md`**

```markdown
# Last Stand Tycoon — agent guide

Godot 4.7 · GDScript · Compatibility renderer · portrait 720×1280 · single-threaded Web export.
Spec: `docs/superpowers/specs/2026-09-30-s1-vertical-slice-design.md`. Decisions: `docs/DECISIONS.md`.

## Layout (canonical, D-032 + D-098)
- `autoload/` EventBus.gd, GameState.gd, Balance.gd (no class_name in autoloads)
- `core/` pure static helpers, no scene access (unit-tested)
- `components/` reusable child nodes
- `actors/` hero, enemy, traveler, projectile, pickups, bots
- `world/` main scene, map, stations, build spots, directors, PhaseController
- `ui/` HUD, joystick, world labels, overlays; `ui/debug/` is debug-only and excluded from release/profile exports
- `balance/` typed Resource scripts + `balance.tres`, `ui_tuning.tres`
- `tests/unit/`, `tests/sim/` (GUT); `tests/sim/out/` is gitignored
- Infra only (never game code): `addons/` (GUT), `export/` (web shell), `.github/` (CI), `docs/`

## Toolchain (pinned, D-129)
- Godot: **GODOT_TAG=<exact tag from D-116>**. The same string is in `.github/workflows/ci.yml` and `.github/workflows/pages.yml`, and CI fails if they differ.
- Official binaries only (`godotengine/godot-builds` releases), verified against the release's `SHA512-SUMS.txt`.
- GUT: the tag from D-117.

## Commands
- `export GODOT=<path from D-116>`
- `./run_tests.sh unit` · `./run_tests.sh sim` · `./run_tests.sh all` · `./run_tests.sh --quick` (unit + night-1 sims; after Task 20)
- Sweep: `"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd`
- Web export: see `export/README.md`

## Architecture
- Autoloads: EventBus (cross-system signals), GameState (the only mutable game data), Balance (typed tuning).
- No system reaches into another system's nodes. **Single exception (D-110, D-128):** `PhaseController`
  calls other systems only through this narrow interface, via typed `@export` references assigned in
  `world/main.tscn` (never `get_node` paths, never groups):
  - `WaveDirector.start_night(plan)`, `WaveDirector.stop()`
  - `NodePool.recall_all() -> int`
  - `TravelerSpawner.start()`, `stop()`, `clear_queue()`
  - hero placement is the bus event `EventBus.hero_place_requested(position)`.
- Tests and tools create the game with `Main.create()` (instantiates `main.tscn`), never `Main.new()`.

## Git workflow (D-133)
- One branch and one PR per plan phase: `s1/p<N>-<slug>` (the table is in the plan), from an up-to-date `main`. One commit per task inside it.
- The `reviewer` subagent reviews every task; the author reviews the checkpoint phases' PRs.
- Before CI exists, the PR body carries the local test output. After CI exists, `unit` and `sim` must be green.
- Every push deploys a web build to GitHub Pages: `main` at https://khanhnguyendev.github.io/last-stand-tycoon/, other branches at `preview/<slug>/` (slug = the branch name with every character outside `[A-Za-z0-9._-]` replaced by `-`) (D-135). Phone tests use those URLs; plain-http LAN doesn't work (D-120).
- **Merges (D-137).** Merge a phase PR yourself (merge commit, never squash) only when CI is green (before CI: the full local suite output is in the PR body), every task passed its reviewer pass, no escalation is open, and the phase doesn't end at a checkpoint. Phases 5 (CP1), 10 (CP2) and 14 (CP3) are merged by the author. After a self-merge, post a PR comment of at most 5 lines (what shipped, tests, decisions).
- Never push to `main` directly, never change branch protection. After CI lands, give the author the exact `gh api ... /branches/main/protection` command (plan Task 34, Step 6) instead of running it.
- **Parallel tasks (D-136):** only with disjoint file sets; hot files (`project.godot`, `CLAUDE.md`, `autoload/EventBus.gd`, `autoload/GameState.gd`, `balance/*`, `world/main.gd`, `world/main.tscn`, `world/world.gd`, `run_tests.sh`, `.github/workflows/*`) are serialized and edited by the main session; at most 3 implementers, each in its own worktree on `s1/p<N>-t<NN>-<slug>`; merge `--no-ff` into the phase branch and run the full suite before the next merge; conflicts are resolved by the main session.

## Device testing (D-138)
- Primary: the iOS Simulator (Safari, a notch iPhone) and, when installed, the Android Emulator (Chrome), on `http://localhost` or the Pages preview URL. Run `export/device_check.sh <url> <out_dir>` and read the screenshots.
- Never install system components. If a runtime is missing, give the author the one-time install step the script prints.
- The author's phone is used only at CP2 and CP3.
- Desktop Chrome: headless with software WebGL (flags in D-138).

## Scope and time (D-131)
- v0.1 has no deadline. Scope is decided by quality and the v0.1 gate, never by the calendar. Plan estimates are information only.
- No time-based stop rules. If a task turns out bigger than its plan describes (new files, new systems, or steps the plan didn't anticipate), stop and propose a split before continuing.
- Escalate on facts, not time: a failed check whose pre-agreed fallback also fails (spike); must-hold balance targets that conflict, or 3 tuning rounds without progress (D-103).

## Sim budget (D-132)
- The sim suite must stay under 60 s headless (`run_tests.sh sim` fails above it).
- If it goes over: **never drop, skip or weaken a test.** CI already runs `unit` and `sim` as parallel jobs, and `./run_tests.sh --quick` (unit + night-1 sims) is for local loops. Report per-test timings and escalate.

## Rules
- Gameplay in `_physics_process` only; never depend on frame delta.
- Randomness only via `Rng.stream(run_seed, day, name)`; a unit test bans global rand calls.
- Only `GameState` methods mutate game data; they emit the EventBus signals. Tweens are visual only.
- EventBus = cross-system events only; local signals inside a system.
- Every number in `balance/`; every user string through `tr()`.
- Ties broken by `spawn_index`, never node order.
- `./run_tests.sh` fails on GUT errors as well as failed asserts, including any `SCRIPT ERROR`. Don't write tests that expect engine errors.
- Sims and tests read state at matching points after `await get_tree().physics_frame`; `physics_frame` fires before the nodes' `_physics_process` (D-118).
```

- [ ] **Step 9: Commit**

```bash
git add project.godot .gutconfig.json run_tests.sh CLAUDE.md addons/gut autoload world tests
git commit -m "chore: bootstrap Godot 4.7 project with GUT test runner"
```

### Task 2: Balance resources and the `Balance` autoload

**Files:**
- Create:
  - `balance/hero_balance.gd`, `balance/enemy_balance.gd`, `balance/wave_balance.gd`, `balance/target_priority.gd`
  - `balance/economy_balance.gd`, `balance/build_balance.gd`, `balance/sim_thresholds.gd`
  - `balance/balance_data.gd`, `balance/ui_tuning.gd`
  - `balance/balance.tres`, `balance/ui_tuning.tres`
- Replace: `autoload/Balance.gd`
- Test: `tests/unit/test_balance.gd`

**Interfaces:**
- Produces:
  - `Balance.data: BalanceData`, with `.hero .enemy .wave .economy .build .sim` (typed sub-resources);
  - `Balance.ui: UiTuning`;
  - `Balance.reset() -> void`, which reloads fresh copies from disk;
  - `Balance.inject(data: BalanceData, ui: UiTuning = null) -> void`.
- The field names are exactly those in the code below; spec §12 lists the values.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_balance.gd`:
```gdscript
extends GutTest
## PINNED REFERENCE: asserts the spec 12 defaults on purpose. Task 35 updates these rows (and spec 12)
## in the same commit as any tuned value. Every other test derives its numbers from Balance.

func before_each() -> void:
	Balance.reset()

func test_spec_values_loaded() -> void:
	var d: BalanceData = Balance.data
	assert_eq(d.hero.attack_range, 4.0)
	assert_eq(d.hero.carry_capacity, 6)
	assert_eq(d.enemy.hp, 30.0)
	assert_eq(Array(d.wave.base_counts), [4, 6, 8])
	assert_eq(Array(d.wave.target_priority.kinds), [&"fence_on_lane", &"diner"])
	assert_eq(d.economy.steaks_per_kill, 2)
	assert_eq(d.economy.gold_per_steak, 3)
	assert_eq(Array(d.build.tower_damage), [8.0, 12.0, 18.0])
	assert_eq(d.build.diner_max_hp, 300.0)
	assert_eq(d.sim.night2_comfort_min, 0.60)
	assert_eq(Balance.ui.camera_fov_h, 42.0)
	assert_eq(Balance.ui.edge_ignore_px, 16.0)

func test_reset_discards_mutation() -> void:
	Balance.data.hero.attack_range = 99.0
	Balance.reset()
	assert_eq(Balance.data.hero.attack_range, 4.0)

func test_inject_replaces_data() -> void:
	var d := BalanceData.new()
	d.hero.move_speed = 1.0
	Balance.inject(d)
	assert_eq(Balance.data.hero.move_speed, 1.0)
	Balance.reset()

func test_inject_ui_semantics() -> void:
	var d := BalanceData.new()
	var u := UiTuning.new()
	u.camera_fov_h = 1.0
	Balance.inject(d, u)
	assert_eq(Balance.ui.camera_fov_h, 1.0)
	var before := Balance.ui
	Balance.inject(BalanceData.new())
	assert_same(Balance.ui, before)
	Balance.reset()
```

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`BalanceData` not declared / `reset` not found).

- [ ] **Step 3: Write the resource scripts**

`balance/hero_balance.gd`:
```gdscript
class_name HeroBalance
extends Resource

@export var move_speed := 5.0
@export var attack_damage := 10.0
@export var attack_interval := 0.5
@export var attack_range := 4.0
@export var retarget_interval := 0.2
## Multiplies attack rate while moving; < 1.0 gives the hybrid (D-019).
@export var moving_attack_speed_mult := 1.0
@export var projectile_speed := 14.0
@export var magnet_radius := 1.5
@export var carry_capacity := 6
```

`balance/enemy_balance.gd`:
```gdscript
class_name EnemyBalance
extends Resource

@export var hp := 30.0
@export var speed := 2.0
@export var damage := 5.0
@export var attack_interval := 1.0
@export var reach := 1.2
@export var lateral_spread := 1.0
@export var drop_scatter := 0.6
## Over the last N meters the lateral offset blends onto the zone's width axis (spec 6.3 test D).
@export var offset_fade_distance := 3.0
```

`balance/target_priority.gd`:
```gdscript
class_name TargetPriority
extends Resource

## Ordered target kinds an enemy checks each tick (D-004, D-049). S2 inserts &"guard".
@export var kinds: Array[StringName] = [&"fence_on_lane", &"diner"]
```

`balance/wave_balance.gd`:
```gdscript
class_name WaveBalance
extends Resource

@export var base_counts: Array[int] = [4, 6, 8]
@export var count_growth := 0.35
@export var hp_growth := 0.15
@export var max_wave_size := 30
@export var spawn_interval := 0.8
@export var first_wave_delay := 5.0
@export var breather := 10.0
@export var side_share_base := 0.20
@export var side_share_step := 0.05
@export var side_share_cap := 0.45
@export var side_group_delay := 4.0
@export var target_priority: TargetPriority = TargetPriority.new()
```

`balance/economy_balance.gd`:
```gdscript
class_name EconomyBalance
extends Resource

@export var steaks_per_kill := 2
@export var gold_per_steak := 3
@export var counter_capacity := 12
@export var transfer_tick := 0.08
@export var stand_still_speed := 0.1
@export var stand_still_time := 0.25
@export var closeup_hold := 1.0
@export var traveler_interval := 2.5
@export var traveler_jitter := 0.5
@export var queue_max := 4
@export var traveler_want_min := 1
@export var traveler_want_max := 2
@export var service_time := 1.0
@export var traveler_speed := 2.5
@export var economy_margin := 1.3
```

`balance/build_balance.gd`:
```gdscript
class_name BuildBalance
extends Resource

@export var tower_cost := 40
@export var fence_cost := 20
@export var level_cost_mult := 2.0
@export var max_level := 3
@export var drain_divisor := 20
@export var tower_damage: Array[float] = [8.0, 12.0, 18.0]
@export var tower_range: Array[float] = [7.0, 7.5, 8.0]
@export var tower_interval := 0.5
@export var tower_projectile_speed := 16.0
@export var fence_hp: Array[float] = [120.0, 200.0, 320.0]
@export var diner_max_hp := 300.0
```

`balance/sim_thresholds.gd`:
```gdscript
class_name SimThresholds
extends Resource

@export var night1_win_min := 0.50
@export var night2_unaided_max := 0.30
@export var night2_comfort_min := 0.60
@export var first_combat_max_s := 30.0
@export var sim_suite_budget_s := 60.0
```

`balance/balance_data.gd`:
```gdscript
class_name BalanceData
extends Resource
## All gameplay tuning (spec 12, D-033). Changing a value must never need a code change.

@export var hero: HeroBalance = HeroBalance.new()
@export var enemy: EnemyBalance = EnemyBalance.new()
@export var wave: WaveBalance = WaveBalance.new()
@export var economy: EconomyBalance = EconomyBalance.new()
@export var build: BuildBalance = BuildBalance.new()
@export var sim: SimThresholds = SimThresholds.new()
```

`balance/ui_tuning.gd`:
```gdscript
class_name UiTuning
extends Resource
## Presentation tuning (D-078, D-090). Separate from gameplay BalanceData.

@export var joystick_radius_px := 64.0
@export var joystick_deadzone := 0.15
@export var edge_ignore_px := 16.0
@export var camera_fov_h := 42.0
@export var camera_pitch := -55.0
@export var camera_distance := 18.0
@export var camera_follow_rate := 8.0
@export var transfer_arc_time := 0.15
@export var transfer_arc_apex := 0.6
@export var gold_punch_scale := 1.25
@export var gold_punch_time := 0.12
@export var shake_amp := 0.12
@export var shake_time := 0.15
@export var shake_cooldown := 0.5
@export var build_pop_scale := 1.2
@export var build_pop_time := 0.2
@export var hit_flash_time := 0.08
@export var banner_time := 2.0
@export var telegraph_scale_min := 0.5
@export var telegraph_scale_max := 2.0
@export var pulse_scale := 1.15
@export var pulse_hz := 1.0
```

`balance/balance.tres`:
```
[gd_resource type="Resource" script_class="BalanceData" load_steps=2 format=3]

[ext_resource type="Script" path="res://balance/balance_data.gd" id="1_bd"]

[resource]
script = ExtResource("1_bd")
```

`balance/ui_tuning.tres`:
```
[gd_resource type="Resource" script_class="UiTuning" load_steps=2 format=3]

[ext_resource type="Script" path="res://balance/ui_tuning.gd" id="1_ui"]

[resource]
script = ExtResource("1_ui")
```

The defaults live in the scripts. Tuning (Task 35) changes the script defaults, so git diffs stay readable.

- [ ] **Step 4: Write the autoload**

`autoload/Balance.gd`:
```gdscript
extends Node
## Loads tuning data (spec 3.2). Tests call reset() in before_each and may inject().

const DATA_PATH := "res://balance/balance.tres"
const UI_PATH := "res://balance/ui_tuning.tres"

var data: BalanceData
var ui: UiTuning

func _init() -> void:
	reset()

func reset() -> void:
	data = (load(DATA_PATH) as BalanceData).duplicate(true)
	ui = (load(UI_PATH) as UiTuning).duplicate(true)

func inject(new_data: BalanceData, new_ui: UiTuning = null) -> void:
	data = new_data
	if new_ui != null:
		ui = new_ui
```

- [ ] **Step 5: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add balance autoload/Balance.gd tests/unit/test_balance.gd
git commit -m "feat: add typed balance resources and Balance autoload"
```

---
## Phase 2: Pure core modules (TDD, no scenes)

### Task 3: `Rng` streams and the global-rand ban

**Files:**
- Create: `core/rng.gd`
- Test: `tests/unit/test_rng.gd`, `tests/unit/test_no_global_rand.gd`

**Interfaces:**
- Produces:
  - Golden values for run seed 20260930 in `test_rng.gd` (D-130, D-134).
    - `seeds` is the true oracle (an independent FNV-1a reference). If any seed mismatches, **escalate**; it is a derivation bug.
    - `first` starts from an unverified Python replica of Godot's RNG. On the **first** Task 3 run only: if every seed passes but `first` fails, capture the engine's values (Step 4b), replace `first`, log a decision that the replica differed and the engine values from the pinned `GODOT_TAG` are now the golden baseline, and freeze them. After that, any mismatch is escalated and never regenerated.
  - `Rng.fnv1a32(s: String) -> int`
  - `Rng.derive_seed(run_seed: int, day: int, stream_name: StringName) -> int`
  - `Rng.stream(run_seed: int, day: int, stream_name: StringName) -> RandomNumberGenerator`
  - `Rng.new_run_seed() -> int`: the only clock-derived seed (D-041). It never returns 0, because 0 means "pick one" in `GameState.new_game`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_rng.gd`:
```gdscript
extends GutTest

## Golden values (D-130, D-134).
## "seeds": FNV-1a 32 of "20260930:<day>:<stream>", days 1–30, from an independent reference. It is the
##   true oracle: a seed mismatch is a derivation bug. Escalate; never edit this list.
## "first": the first randi() of each stream. It starts from an UNVERIFIED Python replica of Godot's
##   RandomPCG. If, on the FIRST Task 3 run, every seed passes but "first" fails, replace "first" with
##   values captured from the pinned GODOT_TAG engine, log that decision, and freeze the list. From then
##   on any mismatch is escalated and never silently regenerated.
const GOLDEN_RUN_SEED := 20260930
const GOLDEN := {
	&"lane_plan": {
		"seeds": [
			1134225596, 2612275673, 2197898854, 294757867, 77956904, 4026147925, 2561854546, 392618375, 2382490068, 2284203448,
			1806702523, 4167824802, 2799489509, 2311279820, 807322655, 3889261174, 2518233961, 89412688, 4234412627, 3666120943,
			155795804, 39263737, 368497798, 3268737035, 2475869000, 206479861, 1619169138, 2300074535, 2168788340, 3851402902,
		],
		"first": [
			982263674, 2176323166, 3238188479, 3368145719, 1234230965, 3109628391, 2159941969, 3375391918, 2255527354, 263167400,
			2060852024, 2106045376, 3529827490, 3840523951, 2746769375, 588929936, 3728030851, 3081809858, 901593407, 1092658841,
			4211841515, 3591191369, 165663572, 348143332, 3925096213, 2777594316, 3384715265, 2039596329, 1528698510, 656414399,
		],
	},
	&"spawns": {
		"seeds": [
			3552542920, 3082638567, 2235635290, 3873018793, 3447222812, 1872249579, 3161085038, 3186541453, 98592880, 2757118156,
			1413269657, 2173656414, 159813019, 3249958648, 2039657749, 829452170, 4175368791, 4029844244, 3522715393, 51971333,
			2233232424, 1471707079, 3130926906, 3662825097, 3570123644, 1279175115, 2568010574, 2593466989, 221596880, 3514938474,
		],
		"first": [
			650738716, 1703870746, 2893652679, 750204739, 2692720213, 2621354981, 622020695, 292235156, 2992577952, 3570663851,
			2182738079, 1162675790, 3034859318, 220721513, 4239364696, 3161825226, 264160985, 2350020726, 3609720301, 3003290713,
			1777538403, 4111975843, 3252279489, 1471586341, 3628916440, 665381522, 1165781075, 3821350835, 1260613377, 2332073099,
		],
	},
	&"travelers": {
		"seeds": [
			1037452772, 3764324805, 540417362, 2352332251, 3327093240, 3881382265, 4113671414, 3298653007, 2415790556, 1238013544,
			4222653707, 894706278, 2266828137, 3820948948, 2251913959, 3083357378, 2531954293, 1147363744, 3644043139, 1082525719,
			2036120260, 3567974437, 3992866994, 4212734267, 3675015384, 2348268249, 2378986838, 3986181295, 4154292924, 2755827234,
		],
		"first": [
			2326239200, 1095793081, 1403444951, 133880543, 2962542670, 3509341101, 1359385378, 3431938266, 1091111726, 2506745929,
			4100069274, 1019532442, 212007670, 2972616008, 1704051235, 262048066, 2923729206, 1885323088, 4167720434, 3728583517,
			197587392, 3682149064, 3261978064, 1389963297, 3079065814, 1797102475, 3185963683, 4222814056, 2631372803, 1168296846,
		],
	},
	&"drops": {
		"seeds": [
			221602518, 3728831699, 2212039968, 3271538453, 1428158962, 2471274223, 4210337772, 3807603825, 439648654, 1986480738,
			1524644037, 3410230876, 3658510367, 2151169286, 2438740457, 1836390544, 4149987075, 679600634, 2290389949, 1060493977,
			2261392054, 328039219, 1299769216, 2677244021, 1555021778, 1517529935, 3574363468, 2470875601, 524831598, 1186286576,
		],
		"first": [
			1157851790, 3552634191, 2671218064, 3522585653, 2540771891, 663546705, 2005689044, 1588691184, 2381121139, 64950392,
			2915435827, 3785732610, 812727903, 853077187, 2631317515, 304738107, 1989086258, 1771721265, 1664518914, 907789140,
			881532959, 207269281, 3804631421, 757119745, 2277132098, 1494116371, 2144379826, 3669206535, 2405477159, 1061516348,
		],
	},
}

func test_golden_seeds_distinct_and_stable() -> void:
	# D-130: all 4 stream names x days 1–30 give distinct seeds, equal to the committed golden list.
	var seen := {}
	for stream_name in GOLDEN:
		var seeds: Array = GOLDEN[stream_name].seeds
		for d in range(1, 31):
			var got := Rng.derive_seed(GOLDEN_RUN_SEED, d, stream_name)
			assert_eq(got, int(seeds[d - 1]), "%s day %d" % [stream_name, d])
			seen[got] = true
	assert_eq(seen.size(), 4 * 30, "all 120 seeds distinct")

func test_golden_first_values() -> void:
	for stream_name in GOLDEN:
		var first: Array = GOLDEN[stream_name].first
		for d in range(1, 31):
			var rng := Rng.stream(GOLDEN_RUN_SEED, d, stream_name)
			assert_eq(int(rng.randi()), int(first[d - 1]), "%s day %d first randi" % [stream_name, d])

func test_fnv1a32_known_vectors() -> void:
	assert_eq(Rng.fnv1a32(""), 2166136261)
	assert_eq(Rng.fnv1a32("a"), 3826002220)
	assert_eq(Rng.fnv1a32("foobar"), 3214735720)

func test_same_inputs_same_sequence() -> void:
	var a := Rng.stream(42, 3, &"spawns")
	var b := Rng.stream(42, 3, &"spawns")
	for i in 20:
		assert_eq(a.randi(), b.randi())

func test_streams_differ_by_name_day_and_seed() -> void:
	var base := Rng.derive_seed(42, 3, &"spawns")
	assert_ne(base, Rng.derive_seed(42, 3, &"drops"))
	assert_ne(base, Rng.derive_seed(42, 4, &"spawns"))
	assert_ne(base, Rng.derive_seed(43, 3, &"spawns"))

func test_new_run_seed_is_nonzero() -> void:
	assert_ne(Rng.new_run_seed(), 0)
```

`tests/unit/test_no_global_rand.gd`:
```gdscript
extends GutTest
## D-034: randomness only through Rng streams. Global calls are banned outside core/rng.gd.

const SCAN_DIRS := ["res://autoload", "res://core", "res://components", "res://actors",
	"res://world", "res://ui", "res://balance"]
const ALLOWED := ["res://core/rng.gd"]

func _collect(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		_collect(dir_path.path_join(d), out)

func test_no_global_randomness() -> void:
	var files: Array = []
	for d in SCAN_DIRS:
		_collect(d, files)
	var re := RegEx.new()
	re.compile("(?<![\\.\\w])(randi|randf|randi_range|randf_range|randomize)\\s*\\(|RandomNumberGenerator\\s*\\.\\s*new\\s*\\(")
	var offenders: Array = []
	for path in files:
		if path in ALLOWED:
			continue
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			offenders.append("%s: %s" % [path, m.get_string()])
	assert_eq(offenders, [], "global randomness found")

func test_ban_regex_catches_and_allows() -> void:
	var re := RegEx.new()
	re.compile("(?<![\\.\\w])(randi|randf|randi_range|randf_range|randomize)\\s*\\(")
	assert_not_null(re.search("var x = randi()"))
	assert_not_null(re.search("randf_range(0, 1)"))
	assert_null(re.search("rng.randi_range(0, 2)"))
	assert_null(re.search("my_randi(3)"))
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`Rng` not declared).

- [ ] **Step 3: Implement**

`core/rng.gd`:
```gdscript
class_name Rng
extends RefCounted
## Named, seeded random streams (D-034, D-097, D-108). The only file allowed to create RNGs.

const FNV_OFFSET := 2166136261
const FNV_PRIME := 16777619
const MASK32 := 0xFFFFFFFF

static func fnv1a32(s: String) -> int:
	var h := FNV_OFFSET
	for b in s.to_utf8_buffer():
		h = ((h ^ b) * FNV_PRIME) & MASK32
	return h

static func derive_seed(run_seed: int, day: int, stream_name: StringName) -> int:
	return fnv1a32("%d:%d:%s" % [run_seed, day, stream_name])

static func stream(run_seed: int, day: int, stream_name: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = derive_seed(run_seed, day, stream_name)
	return rng

static func new_run_seed() -> int:
	var s := fnv1a32("%d:%d" % [int(Time.get_unix_time_from_system() * 1000.0), Time.get_ticks_usec()])
	return s if s != 0 else 1
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 4b (first run only, D-134): capture the engine's first values if the replica differs.** Do this only when `test_golden_seeds_distinct_and_stable` passes and `test_golden_first_values` fails on this first run. If a seed fails, stop and escalate instead.

```bash
cat > /tmp/lst_first.gd <<'GD'
extends SceneTree
func _initialize() -> void:
	for stream_name in [&"lane_plan", &"spawns", &"travelers", &"drops"]:
		var vals: Array = []
		for d in range(1, 31):
			vals.append(Rng.stream(20260930, d, stream_name).randi())
		print(stream_name, " ", vals)
	quit(0)
GD
cp /tmp/lst_first.gd ./lst_first_tmp.gd && "$GODOT" --headless --path . -s res://lst_first_tmp.gd; rm -f ./lst_first_tmp.gd
```

Paste the printed lists into each stream's `"first"` array in `test_rng.gd`, re-run `./run_tests.sh unit` (expect exit 0), and append a decision to `docs/DECISIONS.md`: "D-1xx RNG golden first values: the Python PCG32 replica differed from Godot `<GODOT_TAG>`; the engine-captured values are now the frozen golden baseline (supersedes the replica values in D-130)." Commit it with this task.

- [ ] **Step 5: Commit**

```bash
git add core/rng.gd tests/unit/test_rng.gd tests/unit/test_no_global_rand.gd
git commit -m "feat: add seeded Rng streams and global-rand ban test"
```

### Task 4: `WaveMath` and `WaveSchedule`

**Files:**
- Create: `core/wave_math.gd`, `core/wave_schedule.gd`
- Test: `tests/unit/test_wave_math.gd`, `tests/unit/test_wave_schedule.gd`

**Interfaces:**
- Consumes: `WaveBalance` (Task 2).
- Produces:
  - `WaveMath.raw_total(day: int, w: int, wb: WaveBalance) -> int`
  - `WaveMath.total_count(day, w, wb) -> int`
  - `WaveMath.hp_mult(day, w, wb) -> float`
  - `WaveMath.side_share(day, wb) -> float`
  - `WaveMath.split(day, w, wb) -> Dictionary {"main": int, "side": int}`
  - `WaveSchedule.build(wave: Dictionary, wb: WaveBalance) -> Array`, returning Dictionaries `{"t": float, "lane": String, "side": bool}` sorted by `t` (main first on ties)
  - `WaveSchedule.is_cleared(planned: int, spawned: int, alive: int) -> bool`
- Wave dictionaries (as produced by Task 5): `{"main": String, "side": String, "main_count": int, "side_count": int, "hp_mult": float}`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_wave_math.gd`:
```gdscript
extends GutTest
## PINNED REFERENCE: spec 6.2 reference values at the default WaveBalance. Update with Task 35 if tuned.

var wb: WaveBalance

func before_each() -> void:
	Balance.reset()
	wb = Balance.data.wave

func test_day1_totals() -> void:
	assert_eq([WaveMath.total_count(1, 0, wb), WaveMath.total_count(1, 1, wb), WaveMath.total_count(1, 2, wb)], [4, 6, 8])

func test_day2_reference_values() -> void:
	assert_eq([WaveMath.total_count(2, 0, wb), WaveMath.total_count(2, 1, wb), WaveMath.total_count(2, 2, wb)], [5, 8, 11])
	assert_almost_eq(WaveMath.hp_mult(2, 0, wb), 1.15, 0.0001)
	assert_eq(WaveMath.split(2, 0, wb), {"main": 4, "side": 1})
	assert_eq(WaveMath.split(2, 1, wb), {"main": 6, "side": 2})
	assert_eq(WaveMath.split(2, 2, wb), {"main": 9, "side": 2})

func test_day1_has_no_side_group() -> void:
	for w in 3:
		assert_eq(WaveMath.split(1, w, wb).side, 0)

func test_side_share_curve_and_cap() -> void:
	assert_eq(WaveMath.side_share(1, wb), 0.0)
	assert_almost_eq(WaveMath.side_share(2, wb), 0.20, 0.0001)
	assert_almost_eq(WaveMath.side_share(4, wb), 0.30, 0.0001)
	assert_almost_eq(WaveMath.side_share(7, wb), 0.45, 0.0001)
	assert_almost_eq(WaveMath.side_share(20, wb), 0.45, 0.0001)

func test_cap_overflows_into_hp() -> void:
	# day 10, wave 2: raw = round(8 * 4.15) = 33 -> capped to 30, hp x 33/30
	assert_eq(WaveMath.raw_total(10, 2, wb), 33)
	assert_eq(WaveMath.total_count(10, 2, wb), 30)
	assert_almost_eq(WaveMath.hp_mult(10, 2, wb), (1.0 + 0.15 * 9) * 33.0 / 30.0, 0.0001)

func test_side_at_least_one_from_day2() -> void:
	wb.side_share_base = 0.01
	assert_eq(WaveMath.split(2, 0, wb).side, 1)
```

`tests/unit/test_wave_schedule.gd`:
```gdscript
extends GutTest

var wb: WaveBalance

func before_each() -> void:
	Balance.reset()
	wb = Balance.data.wave

func test_main_only_schedule() -> void:
	var s := WaveSchedule.build({"main": "north", "side": "", "main_count": 3, "side_count": 0, "hp_mult": 1.0}, wb)
	assert_eq(s.size(), 3)
	assert_almost_eq(float(s[0].t), 0.0, 0.0001)
	assert_almost_eq(float(s[1].t), 0.8, 0.0001)
	assert_almost_eq(float(s[2].t), 1.6, 0.0001)
	for e in s:
		assert_eq(e.lane, "north")
		assert_false(e.side)

func test_side_group_starts_after_delay() -> void:
	var s := WaveSchedule.build({"main": "west", "side": "east", "main_count": 2, "side_count": 2, "hp_mult": 1.0}, wb)
	var side_times: Array = s.filter(func(e): return e.side).map(func(e): return e.t)
	assert_almost_eq(float(side_times[0]), 4.0, 0.0001)
	assert_almost_eq(float(side_times[1]), 4.8, 0.0001)
	for i in range(1, s.size()):
		assert_true(s[i - 1].t <= s[i].t, "sorted by time")

func test_clear_rule_requires_all_spawned() -> void:
	# D-044: main group dead before the side group spawns is NOT a clear.
	assert_false(WaveSchedule.is_cleared(6, 4, 0))
	assert_false(WaveSchedule.is_cleared(6, 6, 1))
	assert_true(WaveSchedule.is_cleared(6, 6, 0))
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`WaveMath` not declared).

- [ ] **Step 3: Implement**

`core/wave_math.gd`:
```gdscript
class_name WaveMath
extends RefCounted
## Wave sizes and HP (spec 6.2, D-027, D-053, D-100).

static func raw_total(day: int, w: int, wb: WaveBalance) -> int:
	return int(round(wb.base_counts[w] * (1.0 + wb.count_growth * (day - 1))))

static func total_count(day: int, w: int, wb: WaveBalance) -> int:
	return mini(raw_total(day, w, wb), wb.max_wave_size)

static func hp_mult(day: int, w: int, wb: WaveBalance) -> float:
	var m := 1.0 + wb.hp_growth * (day - 1)
	var raw := raw_total(day, w, wb)
	if raw > wb.max_wave_size:
		m *= float(raw) / float(wb.max_wave_size)
	return m

static func side_share(day: int, wb: WaveBalance) -> float:
	if day < 2:
		return 0.0
	return minf(wb.side_share_base + wb.side_share_step * (day - 2), wb.side_share_cap)

static func split(day: int, w: int, wb: WaveBalance) -> Dictionary:
	var total := total_count(day, w, wb)
	var side := 0
	if day >= 2:
		side = maxi(1, int(round(total * side_share(day, wb))))
	return {"main": total - side, "side": side}
```

`core/wave_schedule.gd`:
```gdscript
class_name WaveSchedule
extends RefCounted
## Spawn times for one wave and the clear rule (spec 7.1, D-044).

static func build(wave: Dictionary, wb: WaveBalance) -> Array:
	var out: Array = []
	for i in int(wave.main_count):
		out.append({"t": i * wb.spawn_interval, "lane": String(wave.main), "side": false})
	for i in int(wave.side_count):
		out.append({"t": wb.side_group_delay + i * wb.spawn_interval, "lane": String(wave.side), "side": true})
	out.sort_custom(func(a, b): return a.t < b.t or (is_equal_approx(a.t, b.t) and not a.side and b.side))
	return out

static func is_cleared(planned: int, spawned: int, alive: int) -> bool:
	return spawned >= planned and alive == 0
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add core/wave_math.gd core/wave_schedule.gd tests/unit/test_wave_math.gd tests/unit/test_wave_schedule.gd
git commit -m "feat: add wave math, spawn schedule and clear rule"
```

### Task 5: `LanePlanner` and lane threat

**Files:**
- Create: `core/lane_planner.gd`
- Test: `tests/unit/test_lane_planner.gd`

**Interfaces:**
- Consumes: `Rng.stream`, `WaveMath.split`, `WaveMath.hp_mult`, `WaveBalance`.
- Produces:
  - `LanePlanner.LANES: Array[String] = ["west", "north", "east"]`
  - `LanePlanner.plan(run_seed: int, day: int, wb: WaveBalance) -> Array` (3 wave dictionaries, as in Task 4)
  - `LanePlanner.threat_by_lane(plan: Array, base_hp: float) -> Dictionary` (lane → float)
  - `LanePlanner.marker_scale(threat: float, max_threat: float, min_s: float, max_s: float) -> float`, which is 0 when the threat is ≤ 0

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_lane_planner.gd`:
```gdscript
extends GutTest

var wb: WaveBalance

func before_each() -> void:
	Balance.reset()
	wb = Balance.data.wave

func test_day1_single_lane_and_wave0_north() -> void:
	for seed in [1, 2, 3, 99, 12345]:
		var p := LanePlanner.plan(seed, 1, wb)
		assert_eq(p.size(), 3)
		assert_eq(p[0].main, "north", "D-095")
		for w in p:
			assert_eq(w.side, "")
			assert_eq(w.side_count, 0)

func test_day2_plus_main_differs_from_side() -> void:
	for seed in range(1, 40):
		for day in [2, 3, 6]:
			for w in LanePlanner.plan(seed, day, wb):
				assert_ne(w.side, "")
				assert_ne(w.main, w.side)
				assert_true(w.main in LanePlanner.LANES)
				assert_true(w.side in LanePlanner.LANES)

func test_counts_match_wave_math() -> void:
	var p := LanePlanner.plan(7, 2, wb)
	assert_eq([p[0].main_count, p[0].side_count], [4, 1])
	assert_eq([p[2].main_count, p[2].side_count], [9, 2])
	assert_almost_eq(float(p[1].hp_mult), 1.15, 0.0001)

func test_same_seed_same_plan() -> void:
	assert_eq(LanePlanner.plan(555, 4, wb), LanePlanner.plan(555, 4, wb))

func test_plan_varies_across_seeds() -> void:
	var seen := {}
	for seed in range(1, 30):
		seen[str(LanePlanner.plan(seed, 3, wb))] = true
	assert_gt(seen.size(), 5)

func test_threat_and_marker_scale() -> void:
	var plan := [
		{"main": "north", "side": "west", "main_count": 4, "side_count": 1, "hp_mult": 1.0},
		{"main": "north", "side": "", "main_count": 2, "side_count": 0, "hp_mult": 2.0},
		{"main": "east", "side": "west", "main_count": 1, "side_count": 1, "hp_mult": 1.0},
	]
	var t := LanePlanner.threat_by_lane(plan, 30.0)
	assert_almost_eq(float(t.north), 4 * 30.0 + 2 * 60.0, 0.001)
	assert_almost_eq(float(t.west), 60.0, 0.001)
	assert_almost_eq(float(t.east), 30.0, 0.001)
	assert_eq(LanePlanner.marker_scale(0.0, 240.0, 0.5, 2.0), 0.0)
	assert_almost_eq(LanePlanner.marker_scale(240.0, 240.0, 0.5, 2.0), 2.0, 0.0001)
	assert_almost_eq(LanePlanner.marker_scale(120.0, 240.0, 0.5, 2.0), 1.25, 0.0001)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`LanePlanner` not declared).

- [ ] **Step 3: Implement**

`core/lane_planner.gd`:
```gdscript
class_name LanePlanner
extends RefCounted
## Seeded per-night lane plan (spec 6.2, D-026, D-028, D-095) and telegraph threat (D-029).

const LANES: Array[String] = ["west", "north", "east"]

static func plan(run_seed: int, day: int, wb: WaveBalance) -> Array:
	var rng := Rng.stream(run_seed, day, &"lane_plan")
	var waves: Array = []
	for w in wb.base_counts.size():
		var main := ""
		if day == 1 and w == 0:
			main = "north"
		else:
			main = LANES[rng.randi_range(0, LANES.size() - 1)]
		var counts := WaveMath.split(day, w, wb)
		var side := ""
		if int(counts.side) > 0:
			var others: Array = LANES.filter(func(l): return l != main)
			side = others[rng.randi_range(0, others.size() - 1)]
		waves.append({
			"main": main, "side": side,
			"main_count": int(counts.main), "side_count": int(counts.side),
			"hp_mult": WaveMath.hp_mult(day, w, wb),
		})
	return waves

static func threat_by_lane(plan_waves: Array, base_hp: float) -> Dictionary:
	var t := {"west": 0.0, "north": 0.0, "east": 0.0}
	for wave in plan_waves:
		var hp := base_hp * float(wave.hp_mult)
		t[wave.main] += int(wave.main_count) * hp
		if String(wave.side) != "":
			t[wave.side] += int(wave.side_count) * hp
	return t

static func marker_scale(threat: float, max_threat: float, min_s: float, max_s: float) -> float:
	if threat <= 0.0 or max_threat <= 0.0:
		return 0.0
	return lerpf(min_s, max_s, threat / max_threat)
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0. The grep ban still passes, because `rng.randi_range` has a `.` prefix.

- [ ] **Step 5: Commit**

```bash
git add core/lane_planner.gd tests/unit/test_lane_planner.gd
git commit -m "feat: add seeded lane planner and lane threat"
```

### Task 6: `MapLayout`, `Geometry`, `EnemyPath` and geometry tests A′–E

**Files:**
- Create: `core/map_layout.gd`, `core/geometry.gd`, `core/enemy_path.gd`
- Test: `tests/unit/test_geometry.gd`

**Interfaces:**
- Produces, all XZ as `Vector2(x, z)`:
  - **`MapLayout` constants:**
    - `DINER_HALF=4.0`, `DINER_HEIGHT=3.0`, `BOUNDS_MIN`, `BOUNDS_MAX`, `HOME=(0, 9.5)` (outside every zone, D-122), `NIGHT1_START=(-2.5, -7)` (D-126)
    - `LANE_PATHS: Dictionary[String → Array[Vector2]]`, `ZONE_AXIS`, `ZONE_RECTS: Dictionary[String → Rect2]`
    - `SPOT_IDS`, `TOWER_SPOTS`, `TOWER_LANES`, `FENCE_LANE`, `LANE_FENCE`, `FENCE_OFFSET_FROM_END=4.0`, `TELEGRAPH_OFFSET_FROM_END=5.5`
    - `COUNTER`, `COUNTER_SIZE`, `COUNTER_DROP`, `SERVICE_POINT`, `QUEUE_SLOTS`, `GOLD_PILE`
    - `FREEZER`, `FREEZER_SIZE`, `FREEZER_ZONE`, `SIGN`, `TRAVELER_ENTER`, `TRAVELER_EXIT`
    - `STATION_RADIUS=1.0`, `BUILD_RADIUS=1.2`, `TOWER_VISUAL_RADIUS=0.5` (mesh only; towers don't collide, D-125), `HERO_RADIUS=0.4`
  - **`MapLayout` functions:**
    - `to3(v: Vector2, y := 0.0) -> Vector3`
    - `fence_spot(lane: String) -> Vector2`, `telegraph_spot(lane: String) -> Vector2`
    - `spot_position(spot_id: String) -> Vector2`, `spot_kind(spot_id: String) -> String` (`"tower"` or `"fence"`)
    - `lane_end(lane) -> Vector2`, `path_length(lane) -> float`
  - **`Geometry`:**
    - `path_length(path: Array) -> float`
    - `point_at(path, dist) -> Vector2`, `tangent_at(path, dist) -> Vector2`
    - `point_back_from_end(path, back) -> Vector2`
    - `dist_point_segment(p, a, b) -> float`
    - `dist_point_rect(p: Vector2, r: Rect2) -> float`
    - `rect_contains(r: Rect2, p: Vector2, eps := 1e-4) -> bool`
    - `rect_corners(r: Rect2) -> Array`
    - `enclosing_radius(points: Array) -> float`
  - **`EnemyPath.position_at(lane: String, dist: float, offset: float, fade: float) -> Vector2`**

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_geometry.gd`:
```gdscript
extends GutTest
## Spec 6.3 tests A′ and B–E, plus the Geometry helpers. Re-run after any path change (D-076).

func before_each() -> void:
	Balance.reset()

func test_helpers() -> void:
	var path := [Vector2(0, 0), Vector2(0, 10), Vector2(10, 10)]
	assert_almost_eq(Geometry.path_length(path), 20.0, 0.0001)
	assert_eq(Geometry.point_at(path, 15.0), Vector2(5, 10))
	assert_eq(Geometry.point_back_from_end(path, 4.0), Vector2(6, 10))
	assert_almost_eq(Geometry.dist_point_segment(Vector2(5, 3), Vector2(0, 0), Vector2(10, 0)), 3.0, 0.0001)
	assert_almost_eq(Geometry.dist_point_rect(Vector2(6, 0), Rect2(-4, -4, 8, 8)), 2.0, 0.0001)
	assert_true(Geometry.rect_contains(Rect2(4, -1.5, 1.2, 3), Vector2(5.2, 0)))
	var r := Geometry.enclosing_radius([Vector2(-1, 0), Vector2(1, 0), Vector2(0, 0.5)])
	assert_almost_eq(r, 1.0, 0.0001)

func _zone_points() -> Array:
	var pts: Array = []
	for lane in LanePlanner.LANES:
		pts.append_array(Geometry.rect_corners(MapLayout.ZONE_RECTS[lane]))
	return pts

## Colliders the hero cannot enter (D-094, D-125): diner, counter, freezer. Towers and fences are walk-through.
func _hero_colliders() -> Array:
	return [
		Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2),
		Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE),
	]

func _reachable(p: Vector2, colliders: Array) -> bool:
	for r in colliders:
		if Geometry.dist_point_rect(p, r) < MapLayout.HERO_RADIUS:
			return false
	return true

func test_A_prime_no_reachable_position_hits_all_three_lanes() -> void:
	# D-123 (supersedes the D-054 enclosing-circle assertion): sample every hero-reachable point on a
	# 0.25 m grid; count lanes with at least one possible enemy stop point (D-111 model, full lateral
	# spread) within hero range. No point may reach all 3 lanes.
	var eb := Balance.data.enemy
	var hero_range := Balance.data.hero.attack_range
	var stops := {}
	for lane in LanePlanner.LANES:
		var pts: Array = []
		var length := MapLayout.path_length(lane)
		for i in 41:
			var offset := lerpf(-1.0, 1.0, i / 40.0) * eb.lateral_spread
			pts.append(EnemyPath.position_at(lane, length, offset, eb.offset_fade_distance))
		stops[lane] = pts
	var colliders := _hero_colliders()
	var pairs := {}
	var max_lanes := 0
	var positions := 0
	var x := MapLayout.BOUNDS_MIN.x
	while x <= MapLayout.BOUNDS_MAX.x + 1e-6:
		var z := MapLayout.BOUNDS_MIN.y
		while z <= MapLayout.BOUNDS_MAX.y + 1e-6:
			var p := Vector2(x, z)
			if _reachable(p, colliders):
				positions += 1
				var reached: Array = []
				for lane in LanePlanner.LANES:
					if p.distance_to(MapLayout.lane_end(lane)) > hero_range + eb.lateral_spread + 0.01:
						continue
					for q in stops[lane]:
						if p.distance_to(q) <= hero_range:
							reached.append(lane)
							break
				max_lanes = maxi(max_lanes, reached.size())
				if reached.size() == 2:
					var key := "+".join(reached)
					pairs[key] = int(pairs.get(key, 0)) + 1
			z += 0.25
		x += 0.25
	gut.p("A': %d reachable positions, max lanes reached = %d" % [positions, max_lanes])
	gut.p("A' info: 2-lane positions per pair = %s" % [pairs])
	gut.p("info only: enclosing radius of zone corners = %.3f" % Geometry.enclosing_radius(_zone_points()))
	assert_lt(max_lanes, 3, "a reachable position covers all three lanes")

func test_B_towers_reach_adjacent_zones() -> void:
	var tower_range: float = Balance.data.build.tower_range[0]
	for spot_id in MapLayout.TOWER_SPOTS:
		var t: Vector2 = MapLayout.TOWER_SPOTS[spot_id]
		for lane in MapLayout.TOWER_LANES[spot_id]:
			for c in Geometry.rect_corners(MapLayout.ZONE_RECTS[lane]):
				assert_true(t.distance_to(c) <= tower_range, "%s -> %s corner %s" % [spot_id, lane, c])

func test_C_towers_reach_adjacent_fences() -> void:
	var tower_range: float = Balance.data.build.tower_range[0]
	for spot_id in MapLayout.TOWER_SPOTS:
		var t: Vector2 = MapLayout.TOWER_SPOTS[spot_id]
		for lane in MapLayout.TOWER_LANES[spot_id]:
			assert_true(t.distance_to(MapLayout.fence_spot(lane)) <= tower_range, "%s -> fence %s" % [spot_id, lane])

func test_D_stop_points_inside_zone() -> void:
	var eb := Balance.data.enemy
	for lane in LanePlanner.LANES:
		var length := MapLayout.path_length(lane)
		for i in 1001:
			var offset := lerpf(-1.0, 1.0, i / 1000.0) * eb.lateral_spread
			var p := EnemyPath.position_at(lane, length, offset, eb.offset_fade_distance)
			assert_true(Geometry.rect_contains(MapLayout.ZONE_RECTS[lane], p), "%s offset %.3f -> %s" % [lane, offset, p])

func test_E_paths_clear_towers_and_diner() -> void:
	var eb := Balance.data.enemy
	var diner := Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2)
	for lane in LanePlanner.LANES:
		var length := MapLayout.path_length(lane)
		var d := 0.0
		while d <= length + 0.0001:
			for offset in [-eb.lateral_spread, 0.0, eb.lateral_spread]:
				var p := EnemyPath.position_at(lane, d, offset, eb.offset_fade_distance)
				for spot_id in MapLayout.TOWER_SPOTS:
					assert_true(p.distance_to(MapLayout.TOWER_SPOTS[spot_id]) >= 1.5 - 0.02, "%s near %s at %.1f" % [lane, spot_id, d])
				assert_true(Geometry.dist_point_rect(p, diner) >= eb.reach - 0.001, "%s inside diner reach at %.1f" % [lane, d])
			d += 0.1

func test_home_and_night1_start_are_clear() -> void:
	# D-122, D-126: both spawn points are outside every station/build zone, off every lane, reachable.
	var zones := [[MapLayout.SIGN, MapLayout.STATION_RADIUS], [MapLayout.FREEZER_ZONE, MapLayout.STATION_RADIUS],
		[MapLayout.COUNTER_DROP, MapLayout.STATION_RADIUS], [MapLayout.GOLD_PILE, Balance.data.hero.magnet_radius]]
	for id in MapLayout.SPOT_IDS:
		zones.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS])
	for p in [MapLayout.HOME, MapLayout.NIGHT1_START]:
		for z in zones:
			assert_gt(p.distance_to(z[0]), float(z[1]), "%s inside zone at %s" % [p, z[0]])
		for lane in LanePlanner.LANES:
			var path: Array = MapLayout.LANE_PATHS[lane]
			for i in range(1, path.size()):
				assert_gt(Geometry.dist_point_segment(p, path[i - 1], path[i]),
					Balance.data.enemy.lateral_spread + MapLayout.HERO_RADIUS, "%s on lane %s" % [p, lane])
	# night 1, wave 0 comes up the north lane: it passes within hero range of the start
	var north: Array = MapLayout.LANE_PATHS["north"]
	assert_lt(Geometry.dist_point_segment(MapLayout.NIGHT1_START, north[0], north[1]), Balance.data.hero.attack_range)

func test_fence_spots_match_spec() -> void:
	assert_true(MapLayout.fence_spot("north").is_equal_approx(Vector2(0, -9.2)))
	assert_almost_eq(MapLayout.fence_spot("west").x, -7.07, 0.02)
	assert_almost_eq(MapLayout.fence_spot("west").y, -3.54, 0.02)
	assert_almost_eq(MapLayout.fence_spot("east").x, 7.07, 0.02)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`MapLayout` not declared).

- [ ] **Step 3: Implement `Geometry`**

`core/geometry.gd`:
```gdscript
class_name Geometry
extends RefCounted
## 2D (XZ) geometry helpers. Paths are Arrays of Vector2.

static func path_length(path: Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += (path[i] as Vector2).distance_to(path[i - 1])
	return total

static func _segment_at(path: Array, dist: float) -> Array:
	# returns [segment_index, distance_into_segment]
	var d := clampf(dist, 0.0, path_length(path))
	for i in range(1, path.size()):
		var seg := (path[i] as Vector2).distance_to(path[i - 1])
		if d <= seg or i == path.size() - 1:
			return [i, minf(d, seg)]
		d -= seg
	return [path.size() - 1, 0.0]

static func point_at(path: Array, dist: float) -> Vector2:
	var s := _segment_at(path, dist)
	var a: Vector2 = path[s[0] - 1]
	var b: Vector2 = path[s[0]]
	return a + (b - a).normalized() * float(s[1])

static func tangent_at(path: Array, dist: float) -> Vector2:
	var s := _segment_at(path, dist)
	return ((path[s[0]] as Vector2) - (path[s[0] - 1] as Vector2)).normalized()

static func point_back_from_end(path: Array, back: float) -> Vector2:
	return point_at(path, path_length(path) - back)

static func dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 0.0:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func dist_point_rect(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()

static func rect_contains(r: Rect2, p: Vector2, eps := 1e-4) -> bool:
	return p.x >= r.position.x - eps and p.x <= r.end.x + eps and p.y >= r.position.y - eps and p.y <= r.end.y + eps

static func rect_corners(r: Rect2) -> Array:
	return [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]

static func _contains_all(c: Vector2, radius: float, points: Array) -> bool:
	for p in points:
		if (p as Vector2).distance_to(c) > radius + 1e-6:
			return false
	return true

static func enclosing_radius(points: Array) -> float:
	# Brute-force minimal enclosing circle: fine for a few dozen points.
	var best := INF
	var n := points.size()
	for i in n:
		for j in range(i + 1, n):
			var c: Vector2 = ((points[i] as Vector2) + (points[j] as Vector2)) * 0.5
			var r := (points[i] as Vector2).distance_to(c)
			if r < best and _contains_all(c, r, points):
				best = r
			for k in range(j + 1, n):
				var cc := _circumcenter(points[i], points[j], points[k])
				if cc.x == INF:
					continue
				var rr := (points[i] as Vector2).distance_to(cc)
				if rr < best and _contains_all(cc, rr, points):
					best = rr
	return best

static func _circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 1e-9:
		return Vector2(INF, INF)
	var a2 := a.length_squared()
	var b2 := b.length_squared()
	var c2 := c.length_squared()
	return Vector2(
		(a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d,
		(a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d)
```

- [ ] **Step 4: Implement `MapLayout` and `EnemyPath`**

`core/map_layout.gd`:
```gdscript
class_name MapLayout
extends RefCounted
## The single source of map coordinates (spec 6.1, D-054, D-055, D-062, D-091–D-093, D-112).
## Positions are Vector2(x, z). North = −z. Origin = diner center.

const DINER_HALF := 4.0
const DINER_HEIGHT := 3.0
const BOUNDS_MIN := Vector2(-24, -24)
const BOUNDS_MAX := Vector2(24, 14)
const HOME := Vector2(0, 9.5)  ## outside every zone (D-122); the sign is SIGN
## New game and night-1 restart spawn: north of the diner, off the lane, outside every zone (D-126).
const NIGHT1_START := Vector2(-2.5, -7)
const HERO_RADIUS := 0.4
const TOWER_VISUAL_RADIUS := 0.5  ## mesh only: towers never collide with the hero (D-125)

const LANE_PATHS := {
	"north": [Vector2(0, -24), Vector2(0, -5.2)],
	"west": [Vector2(-16, -24), Vector2(-11, -11), Vector2(-5.2, 0)],
	"east": [Vector2(16, -24), Vector2(11, -11), Vector2(5.2, 0)],
}
## Width axis of each lane's attack zone (D-111).
const ZONE_AXIS := {"north": Vector2(1, 0), "west": Vector2(0, 1), "east": Vector2(0, 1)}
## Band between each wall and the reach line (D-101). Rect2(x, z, w, h).
const ZONE_RECTS := {
	"west": Rect2(-5.2, -1.5, 1.2, 3.0),
	"north": Rect2(-1.5, -5.2, 3.0, 1.2),
	"east": Rect2(4.0, -1.5, 1.2, 3.0),
}

const SPOT_IDS: Array[String] = ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e"]
const TOWER_SPOTS := {"tower_nw": Vector2(-5, -5), "tower_ne": Vector2(5, -5)}
const TOWER_LANES := {"tower_nw": ["west", "north"], "tower_ne": ["north", "east"]}
const FENCE_LANE := {"fence_w": "west", "fence_n": "north", "fence_e": "east"}
const LANE_FENCE := {"west": "fence_w", "north": "fence_n", "east": "fence_e"}
const FENCE_OFFSET_FROM_END := 4.0
const TELEGRAPH_OFFSET_FROM_END := 5.5

const COUNTER := Vector2(0, 4.8)
const COUNTER_SIZE := Vector2(3, 1)
const COUNTER_DROP := Vector2(2.2, 4.8)
const SERVICE_POINT := Vector2(0, 6.0)
const QUEUE_SLOTS := [Vector2(0, 6.0), Vector2(-1.2, 7.0), Vector2(-2.4, 8.0), Vector2(-3.6, 9.0)]
const GOLD_PILE := Vector2(-2.5, 5.5)
const FREEZER := Vector2(5.5, 5.0)
const FREEZER_SIZE := Vector2(1.5, 1.5)
const FREEZER_ZONE := Vector2(5.5, 6.3)
const SIGN := Vector2(0, 8)
const ROAD_Z := 11.0
const TRAVELER_ENTER := Vector2(24, 11)
const TRAVELER_EXIT := Vector2(-24, 11)
const STATION_RADIUS := 1.0
const BUILD_RADIUS := 1.2

static func to3(v: Vector2, y := 0.0) -> Vector3:
	return Vector3(v.x, y, v.y)

static func path_length(lane: String) -> float:
	return Geometry.path_length(LANE_PATHS[lane])

static func lane_end(lane: String) -> Vector2:
	var path: Array = LANE_PATHS[lane]
	return path[path.size() - 1]

static func fence_spot(lane: String) -> Vector2:
	return Geometry.point_back_from_end(LANE_PATHS[lane], FENCE_OFFSET_FROM_END)

static func telegraph_spot(lane: String) -> Vector2:
	return Geometry.point_back_from_end(LANE_PATHS[lane], TELEGRAPH_OFFSET_FROM_END)

static func spot_kind(spot_id: String) -> String:
	return "tower" if spot_id.begins_with("tower") else "fence"

static func spot_position(spot_id: String) -> Vector2:
	if TOWER_SPOTS.has(spot_id):
		return TOWER_SPOTS[spot_id]
	return fence_spot(FENCE_LANE[spot_id])
```

`core/enemy_path.gd`:
```gdscript
class_name EnemyPath
extends RefCounted
## Boar position along its lane with a lateral offset that blends onto the zone axis near the end (D-111).

static func position_at(lane: String, dist: float, offset: float, fade: float) -> Vector2:
	var path: Array = MapLayout.LANE_PATHS[lane]
	var length := Geometry.path_length(path)
	var d := clampf(dist, 0.0, length)
	var base := Geometry.point_at(path, d)
	var tan := Geometry.tangent_at(path, d)
	var perp := Vector2(-tan.y, tan.x)
	var k := clampf((length - d) / fade, 0.0, 1.0) if fade > 0.0 else 0.0
	var axis: Vector2 = MapLayout.ZONE_AXIS[lane]
	return base + perp * offset * k + axis * offset * (1.0 - k)
```

- [ ] **Step 5: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0. The log shows `A': 28148 reachable positions, max lanes reached = 2`, the 2-lane info `{"west+north": 16, "north+east": 16}` (computed on paper, D-123) and the info-only enclosing radius 5.412. If test E fails by a few centimeters at the NW tower, **do not move the tower**. Escalate with the printed failing point, because geometry changes are design changes.

- [ ] **Step 6: Commit**

```bash
git add core/map_layout.gd core/geometry.gd core/enemy_path.gd tests/unit/test_geometry.gd
git commit -m "feat: add map layout, geometry helpers, enemy path and geometry tests A'-E"
```

### Task 7: `Targeting`, `Economy` and `Pulse`

**Files:**
- Create: `core/targeting.gd`, `core/economy.gd`, `core/pulse.gd`
- Test: `tests/unit/test_targeting.gd`, `tests/unit/test_economy.gd`, `tests/unit/test_pulse.gd`

**Interfaces:**
- Produces:
  - **Candidate dictionary:** `{"position": Vector3, "spawn_index": int, "ref": Object}`.
  - `Targeting.select(origin: Vector3, attack_range: float, candidates: Array) -> Dictionary`: the chosen candidate, or `{}`. It measures XZ distance and breaks ties by the lower `spawn_index`.
  - `Economy.level_cost(spot_id: String, level: int, bb: BuildBalance) -> int`: the cost to go from `level` to `level + 1`, or `-1` at max level.
  - `Economy.drain_per_tick(cost: int, bb: BuildBalance) -> int`
  - `Economy.night_kills(day: int, wb: WaveBalance) -> int`
  - `Economy.night_gold(day: int, bd: BalanceData) -> int`
  - `Pulse.should_pulse(state: Dictionary, bd: BalanceData) -> bool`, where `state` is a `GameState.to_dict()` dictionary.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_targeting.gd`:
```gdscript
extends GutTest

func _c(x: float, z: float, idx: int) -> Dictionary:
	return {"position": Vector3(x, 0, z), "spawn_index": idx, "ref": null}

func test_nearest_in_range_wins() -> void:
	var got := Targeting.select(Vector3.ZERO, 4.0, [_c(3, 0, 5), _c(1, 1, 9), _c(0, 5, 1)])
	assert_eq(got.spawn_index, 9)

func test_out_of_range_ignored() -> void:
	assert_eq(Targeting.select(Vector3.ZERO, 4.0, [_c(0, 4.5, 1)]), {})

func test_tie_breaks_by_lower_spawn_index_regardless_of_order() -> void:
	assert_eq(Targeting.select(Vector3.ZERO, 4.0, [_c(2, 0, 8), _c(-2, 0, 3)]).spawn_index, 3)
	assert_eq(Targeting.select(Vector3.ZERO, 4.0, [_c(-2, 0, 3), _c(2, 0, 8)]).spawn_index, 3)

func test_height_is_ignored() -> void:
	var c := {"position": Vector3(0, 10, 3), "spawn_index": 1, "ref": null}
	assert_eq(Targeting.select(Vector3.ZERO, 4.0, [c]).spawn_index, 1)
```

`tests/unit/test_economy.gd`:
```gdscript
extends GutTest
## PINNED REFERENCE: spec 8.6 / 8.9 values at the default Balance (the margin check is computed).
## Update the pinned rows with Task 35 if tuned.

var bd: BalanceData

func before_each() -> void:
	Balance.reset()
	bd = Balance.data

func test_level_costs() -> void:
	var costs_t: Array = []
	var costs_f: Array = []
	for lvl in 4:
		costs_t.append(Economy.level_cost("tower_nw", lvl, bd.build))
		costs_f.append(Economy.level_cost("fence_n", lvl, bd.build))
	assert_eq(costs_t, [40, 80, 160, -1])
	assert_eq(costs_f, [20, 40, 80, -1])

func test_drain_per_tick() -> void:
	assert_eq(Economy.drain_per_tick(40, bd.build), 2)
	assert_eq(Economy.drain_per_tick(20, bd.build), 1)
	assert_eq(Economy.drain_per_tick(160, bd.build), 8)
	assert_eq(Economy.drain_per_tick(21, bd.build), 2)

func test_night_yield() -> void:
	assert_eq(Economy.night_kills(1, bd.wave), 18)
	assert_eq(Economy.night_kills(2, bd.wave), 24)
	assert_eq(Economy.night_gold(1, bd), 108)
	assert_eq(Economy.night_gold(2, bd), 144)

func test_economy_check_night1_covers_tower_plus_fence_with_margin() -> void:
	# Spec 8.9 / D-063
	var need := bd.economy.economy_margin * (bd.build.tower_cost + bd.build.fence_cost)
	assert_true(Economy.night_gold(1, bd) >= need, "%d < %.1f" % [Economy.night_gold(1, bd), need])
```

`tests/unit/test_pulse.gd`:
```gdscript
extends GutTest

func before_each() -> void:
	Balance.reset()

func _state() -> Dictionary:
	var b := {}
	for id in MapLayout.SPOT_IDS:
		b[id] = {"level": 0, "paid": 0, "hp": 0.0}
	return {"gold": 0, "gold_pile": 0, "freezer_steaks": 0, "carried_steaks": 0, "counter_steaks": 0, "buildings": b}

func test_pulses_when_nothing_to_do() -> void:
	assert_true(Pulse.should_pulse(_state(), Balance.data))

func test_each_stock_blocks_pulse() -> void:
	for key in ["freezer_steaks", "carried_steaks", "counter_steaks", "gold_pile"]:
		var s := _state()
		s[key] = 1
		assert_false(Pulse.should_pulse(s, Balance.data), key)

func test_affordable_build_blocks_pulse() -> void:
	var s := _state()
	s.gold = 20  # fence costs 20
	assert_false(Pulse.should_pulse(s, Balance.data))
	s.gold = 19
	assert_true(Pulse.should_pulse(s, Balance.data))

func test_partial_paid_counts() -> void:
	var s := _state()
	s.gold = 5
	s.buildings.fence_w.paid = 15  # 20 - 15 = 5 remaining
	assert_false(Pulse.should_pulse(s, Balance.data))

func test_max_level_spots_ignored() -> void:
	var s := _state()
	s.gold = 10000
	for id in MapLayout.SPOT_IDS:
		s.buildings[id].level = 3
	assert_true(Pulse.should_pulse(s, Balance.data))
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`Targeting` not declared).

- [ ] **Step 3: Implement**

`core/targeting.gd`:
```gdscript
class_name Targeting
extends RefCounted
## Nearest-in-range selection; ties by lower spawn_index (D-034).

const EPS := 1e-6

static func select(origin: Vector3, attack_range: float, candidates: Array) -> Dictionary:
	var best := {}
	var best_d := INF
	for c in candidates:
		var pos: Vector3 = c.position
		var d := Vector2(pos.x - origin.x, pos.z - origin.z).length()
		if d > attack_range:
			continue
		if d < best_d - EPS or (absf(d - best_d) <= EPS and int(c.spawn_index) < int(best.spawn_index)):
			best = c
			best_d = d
	return best
```

`core/economy.gd`:
```gdscript
class_name Economy
extends RefCounted
## Costs and yields (spec 8.6, 8.9, D-063, D-065, D-067).

static func base_cost(spot_id: String, bb: BuildBalance) -> int:
	return bb.tower_cost if MapLayout.spot_kind(spot_id) == "tower" else bb.fence_cost

static func level_cost(spot_id: String, level: int, bb: BuildBalance) -> int:
	if level >= bb.max_level:
		return -1
	return int(round(base_cost(spot_id, bb) * pow(bb.level_cost_mult, level)))

static func drain_per_tick(cost: int, bb: BuildBalance) -> int:
	return maxi(1, int(ceil(float(cost) / float(bb.drain_divisor))))

static func night_kills(day: int, wb: WaveBalance) -> int:
	var total := 0
	for w in wb.base_counts.size():
		total += WaveMath.total_count(day, w, wb)
	return total

static func night_gold(day: int, bd: BalanceData) -> int:
	return night_kills(day, bd.wave) * bd.economy.steaks_per_kill * bd.economy.gold_per_steak
```

`core/pulse.gd`:
```gdscript
class_name Pulse
extends RefCounted
## Close-up sign pulse predicate (spec 8.8, D-068). `state` is a GameState.to_dict() dictionary.

static func should_pulse(state: Dictionary, bd: BalanceData) -> bool:
	for key in ["freezer_steaks", "carried_steaks", "counter_steaks", "gold_pile"]:
		if int(state[key]) != 0:
			return false
	var gold := int(state.gold)
	for spot_id in state.buildings:
		var b: Dictionary = state.buildings[spot_id]
		var cost := Economy.level_cost(spot_id, int(b.level), bd.build)
		if cost < 0:
			continue
		if gold >= cost - int(b.paid):
			return false
	return true
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add core/targeting.gd core/economy.gd core/pulse.gd tests/unit/test_targeting.gd tests/unit/test_economy.gd tests/unit/test_pulse.gd
git commit -m "feat: add targeting, economy costs and close-up pulse predicate"
```

### Task 8: `WaypointGraph` for bots

**Files:**
- Create: `core/waypoint_graph.gd`
- Test: `tests/unit/test_waypoint_graph.gd`

**Interfaces:**
- Produces:
  - `WaypointGraph.create_default() -> WaypointGraph`
  - `add_node(name: String, pos: Vector2)`, `add_edge(a: String, b: String)`
  - `nodes: Dictionary`, `edges: Dictionary`
  - `nearest(p: Vector2) -> String`
  - `shortest(from: String, to: String) -> Array` (node names, inclusive)
  - `route_from(p: Vector2, goal: String) -> Array` (Vector2 points to walk)
  - `position_of(name: String) -> Vector2`
- **Node names:** `home`, `sign`, `gold_pile`, `front_e`, `counter_drop`, `freezer`, `sw`, `se`, `nw`, `ne`, `zone_west`, `zone_north`, `zone_east`, `fence_w`, `fence_n`, `fence_e`, `tower_nw`, `tower_ne`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_waypoint_graph.gd`:
```gdscript
extends GutTest

var g: WaypointGraph

func before_each() -> void:
	g = WaypointGraph.create_default()

func test_all_nodes_connected() -> void:
	for n in g.nodes:
		assert_gt(g.shortest("home", n).size(), 0, "unreachable: " + n)

## D-125: every edge is traversable with hero-radius clearance against the hero's only colliders.
func test_edges_traversable_against_colliders() -> void:
	var diner := Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2)
	var freezer := Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)
	var counter := Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE)
	for a in g.edges:
		for b in g.edges[a]:
			var pa := g.position_of(a)
			var pb := g.position_of(b)
			for i in 51:
				var p := pa.lerp(pb, i / 50.0)
				for r in [diner, freezer, counter]:
					assert_true(Geometry.dist_point_rect(p, r) >= MapLayout.HERO_RADIUS - 0.01, "%s-%s hits box at %s" % [a, b, p])

func test_route_home_to_zone_north_goes_around() -> void:
	var names := g.shortest("home", "zone_north")
	assert_eq(names[0], "home")
	assert_eq(names[names.size() - 1], "zone_north")
	assert_true("nw" in names or "ne" in names)

func test_route_from_position_ends_at_goal() -> void:
	var pts := g.route_from(MapLayout.HOME, "freezer")
	assert_eq(pts[pts.size() - 1], g.position_of("freezer"))

func test_tower_stand_points_inside_build_radius() -> void:
	for id in ["tower_nw", "tower_ne"]:
		var d := g.position_of(id).distance_to(MapLayout.TOWER_SPOTS[id])
		assert_true(d <= MapLayout.BUILD_RADIUS)
		assert_true(d >= MapLayout.TOWER_VISUAL_RADIUS, "stand beside the mesh, not inside it")
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`WaypointGraph` not declared).

- [ ] **Step 3: Implement**

`core/waypoint_graph.gd`:
```gdscript
class_name WaypointGraph
extends RefCounted
## Fixed bot navigation graph (D-057, D-112). Dijkstra with deterministic ties by name.

var nodes := {}   # name -> Vector2
var edges := {}   # name -> Array[String]

func add_node(node_name: String, pos: Vector2) -> void:
	nodes[node_name] = pos
	if not edges.has(node_name):
		edges[node_name] = []

func add_edge(a: String, b: String) -> void:
	if not b in edges[a]:
		edges[a].append(b)
	if not a in edges[b]:
		edges[b].append(a)

func position_of(node_name: String) -> Vector2:
	return nodes[node_name]

func nearest(p: Vector2) -> String:
	var names := nodes.keys()
	names.sort()
	var best := ""
	var best_d := INF
	for n in names:
		var d := p.distance_to(nodes[n])
		if d < best_d - 1e-6:
			best = n
			best_d = d
	return best

func shortest(from: String, to: String) -> Array:
	var dist := {}
	var prev := {}
	var open: Array = nodes.keys()
	for n in open:
		dist[n] = INF
	dist[from] = 0.0
	while not open.is_empty():
		open.sort_custom(func(a, b): return dist[a] < dist[b] or (dist[a] == dist[b] and a < b))
		var u: String = open.pop_front()
		if u == to or dist[u] == INF:
			break
		for v in edges[u]:
			var alt: float = dist[u] + (nodes[u] as Vector2).distance_to(nodes[v])
			if alt < dist[v] - 1e-9:
				dist[v] = alt
				prev[v] = u
	if dist[to] == INF:
		return []
	var path: Array = [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return path

func route_from(p: Vector2, goal: String) -> Array:
	var start := nearest(p)
	var pts: Array = []
	for n in shortest(start, goal):
		pts.append(nodes[n])
	if not pts.is_empty() and p.distance_to(pts[0]) < 0.05:
		pts.pop_front()
	return pts

static func create_default() -> WaypointGraph:
	var g := WaypointGraph.new()
	g.add_node("home", MapLayout.HOME)
	g.add_node("sign", MapLayout.SIGN)
	g.add_node("gold_pile", MapLayout.GOLD_PILE)
	g.add_node("front_e", Vector2(3.0, 6.5))
	g.add_node("counter_drop", MapLayout.COUNTER_DROP)
	g.add_node("freezer", MapLayout.FREEZER_ZONE)
	g.add_node("sw", Vector2(-6.8, 6.8))
	g.add_node("se", Vector2(6.8, 6.8))
	g.add_node("nw", Vector2(-7, -7))
	g.add_node("ne", Vector2(7, -7))
	for lane in ["west", "north", "east"]:
		g.add_node("zone_" + lane, MapLayout.lane_end(lane))
	g.add_node("fence_w", MapLayout.fence_spot("west"))
	g.add_node("fence_n", MapLayout.fence_spot("north"))
	g.add_node("fence_e", MapLayout.fence_spot("east"))
	g.add_node("tower_nw", MapLayout.TOWER_SPOTS.tower_nw + Vector2(-0.75, -0.75))
	g.add_node("tower_ne", MapLayout.TOWER_SPOTS.tower_ne + Vector2(0.75, -0.75))
	for e in [
		["home", "sign"], ["home", "sw"], ["home", "se"], ["home", "front_e"], ["home", "gold_pile"], ["sw", "gold_pile"],
		["front_e", "freezer"], ["front_e", "counter_drop"], ["se", "freezer"],
		["sw", "nw"], ["se", "ne"], ["sw", "zone_west"], ["se", "zone_east"],
		["nw", "zone_west"], ["nw", "zone_north"], ["nw", "fence_w"], ["nw", "fence_n"], ["nw", "tower_nw"],
		["ne", "zone_east"], ["ne", "zone_north"], ["ne", "fence_e"], ["ne", "fence_n"], ["ne", "tower_ne"],
		["zone_west", "fence_w"], ["zone_north", "fence_n"], ["zone_east", "fence_e"],
	]:
		g.add_edge(e[0], e[1])
	return g
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0. If an edge-clearance assertion fails, escalate with the reported segment. Do not move stations.

- [ ] **Step 5: Commit**

```bash
git add core/waypoint_graph.gd tests/unit/test_waypoint_graph.gd
git commit -m "feat: add bot waypoint graph"
```

### Task 9: `CameraMath` and the lane-visibility test

**Files:**
- Create: `core/camera_math.gd`
- Test: `tests/unit/test_lane_visibility.gd`

**Interfaces:**
- Consumes: `UiTuning` (camera fields), `MapLayout`, `EnemyPath`, `Balance.data.hero.attack_range`, `Balance.data.enemy.speed`.
- Produces:
  - `CameraMath.ASPECT := 720.0 / 1280.0`
  - `CameraMath.FOCUS_MIN := Vector2(-17, -20)`, `CameraMath.FOCUS_MAX := Vector2(17, 8)`
  - `CameraMath.focus_for(hero_xz: Vector2) -> Vector2`
  - `CameraMath.camera_transform(focus: Vector2, ui: UiTuning) -> Transform3D`
  - `CameraMath.projection(ui: UiTuning, aspect: float) -> Projection`
  - `CameraMath.to_ndc(world: Vector3, xform: Transform3D, proj: Projection) -> Vector3`
  - `CameraMath.on_screen(world: Vector3, xform: Transform3D, proj: Projection) -> bool`
- `CameraRig` (Task 28) must use exactly these functions, so the test and the game agree.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_lane_visibility.gd`:
```gdscript
extends GutTest
## Spec 6.4 / D-076: a Boar is on screen ≥ 2.0 s before it enters hero range, hero standing at the zone.

func before_each() -> void:
	Balance.reset()

func test_camera_centers_focus() -> void:
	var ui := Balance.ui
	var xf := CameraMath.camera_transform(Vector2(3, -2), ui)
	var proj := CameraMath.projection(ui, CameraMath.ASPECT)
	var ndc := CameraMath.to_ndc(Vector3(3, 0, -2), xf, proj)
	assert_almost_eq(ndc.x, 0.0, 0.001)
	assert_almost_eq(ndc.y, 0.0, 0.001)

func test_visible_width_about_14m() -> void:
	var ui := Balance.ui
	var xf := CameraMath.camera_transform(Vector2.ZERO, ui)
	var proj := CameraMath.projection(ui, CameraMath.ASPECT)
	var edge := 0.0
	while CameraMath.on_screen(Vector3(edge, 0, 0), xf, proj):
		edge += 0.05
	gut.p("half width at focus = %.2f m" % edge)
	assert_between(edge * 2.0, 12.5, 15.5)

func test_boar_visible_two_seconds_before_range() -> void:
	var ui := Balance.ui
	var proj := CameraMath.projection(ui, CameraMath.ASPECT)
	var eb := Balance.data.enemy
	var hero_range := Balance.data.hero.attack_range
	var dt := 1.0 / 60.0
	for lane in LanePlanner.LANES:
		var hero := MapLayout.lane_end(lane)
		var xf := CameraMath.camera_transform(CameraMath.focus_for(hero), ui)
		var length := MapLayout.path_length(lane)
		var samples: Array = []
		var d := 0.0
		while d <= length:
			samples.append(EnemyPath.position_at(lane, d, 0.0, eb.offset_fade_distance))
			d += eb.speed * dt
		var range_idx := -1
		for i in samples.size():
			if (samples[i] as Vector2).distance_to(hero) <= hero_range:
				range_idx = i
				break
		assert_gt(range_idx, 0, lane)
		var first_visible := range_idx
		while first_visible > 0 and CameraMath.on_screen(MapLayout.to3(samples[first_visible - 1], 0.5), xf, proj):
			first_visible -= 1
		var seconds := (range_idx - first_visible) * dt
		gut.p("%s: on screen %.2f s before range" % [lane, seconds])
		assert_true(seconds >= 2.0, "%s only %.2f s" % [lane, seconds])
```

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`CameraMath` not declared).

- [ ] **Step 3: Implement**

`core/camera_math.gd`:
```gdscript
class_name CameraMath
extends RefCounted
## Camera placement and projection shared by CameraRig and tests (D-071, D-090, D-112).

const ASPECT := 720.0 / 1280.0
const FOCUS_MIN := Vector2(-17, -20)
const FOCUS_MAX := Vector2(17, 8)
const Z_NEAR := 0.1
const Z_FAR := 200.0

static func focus_for(hero_xz: Vector2) -> Vector2:
	return hero_xz.clamp(FOCUS_MIN, FOCUS_MAX)

static func camera_transform(focus: Vector2, ui: UiTuning) -> Transform3D:
	var pitch := deg_to_rad(-ui.camera_pitch)  # 55° down
	var target := Vector3(focus.x, 0.0, focus.y)
	var pos := target + Vector3(0.0, sin(pitch), cos(pitch)) * ui.camera_distance
	return Transform3D(Basis(), pos).looking_at(target, Vector3.UP)

static func projection(ui: UiTuning, aspect: float) -> Projection:
	# flip_fov = true: camera_fov_h is horizontal, matching Camera3D.KEEP_WIDTH.
	return Projection.create_perspective(ui.camera_fov_h, aspect, Z_NEAR, Z_FAR, true)

static func to_ndc(world: Vector3, xform: Transform3D, proj: Projection) -> Vector3:
	var v := xform.affine_inverse() * world
	var c := proj * Vector4(v.x, v.y, v.z, 1.0)
	if c.w <= 0.0:
		return Vector3(INF, INF, INF)
	return Vector3(c.x / c.w, c.y / c.w, c.z / c.w)

static func on_screen(world: Vector3, xform: Transform3D, proj: Projection) -> bool:
	var n := to_ndc(world, xform, proj)
	return absf(n.x) <= 1.0 and absf(n.y) <= 1.0
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0. The log shows the half width (about 7 m) and the seconds per lane (all ≥ 2.0). If a lane fails, **stop and escalate** with the numbers (D-076 fallback: camera distance or FOV, keeping the Boar at least 40 px tall). Do not edit the paths.

- [ ] **Step 5: Commit**

```bash
git add core/camera_math.gd tests/unit/test_lane_visibility.gd
git commit -m "feat: add camera math and lane visibility test"
```

---
## Phase 3: State, bus, scene skeleton

### Task 10: `Phase`, `EventBus` and `GameState`

**Files:**
- Create: `core/phase.gd`
- Replace: `autoload/EventBus.gd`, `autoload/GameState.gd`
- Test: `tests/unit/test_game_state.gd`

**Interfaces:**
- Consumes: `Balance`, `LanePlanner.plan`, `Economy.level_cost`, `MapLayout.SPOT_IDS`, `Rng.new_run_seed`.
- Produces:
  - `Phase.NIGHT = 0`, `Phase.DAWN = 1`, `Phase.DAY = 2`, and `Phase.name_of(p: int) -> String`.
  - Every `EventBus` signal in the code below: spec 3.2 plus D-109.
  - **GameState fields:** `resume_phase: String`, `run_seed: int`, `day: int`, `gold: int`, `gold_pile: int`, `freezer_steaks: int`, `counter_steaks: int`, `carried_steaks: int`, `diner_hp: float`, `buildings: Dictionary` (String → `{level:int, paid:int, hp:float}`), `lane_plan: Array`.
  - **GameState methods:**

    | Method | Returns |
    |---|---|
    | `new_game(seed: int = 0)` | void |
    | `to_dict()` | Dictionary |
    | `from_dict(d: Dictionary)` | void |
    | `add_gold(n: int)` | void |
    | `collect_pile()` | int |
    | `add_freezer(n: int)` | void |
    | `pick_steak()` | bool |
    | `move_freezer_to_carry(n: int = 1)` | int |
    | `move_carry_to_counter(n: int = 1)` | int |
    | `sell_from_counter(want: int)` | int |
    | `next_level_cost(spot_id: String)` | int |
    | `remaining_cost(spot_id: String)` | int |
    | `pay_into_spot(spot_id: String, amount: int)` | int |
    | `fence_max_hp(level: int)` | float |
    | `damage_fence(spot_id: String, amount: float)` | void |
    | `damage_diner(amount: float)` | void |
    | `heal_for_dawn()` | void |
    | `reset_destroyed_fences()` | void |
    | `advance_day()` | void |
    | `diner_fraction()` | float |

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_game_state.gd`:
```gdscript
extends GutTest

func before_each() -> void:
	Balance.reset()
	GameState.new_game(1234)

func _max_hp() -> float:
	return Balance.data.build.diner_max_hp

func _cap() -> int:
	return Balance.data.hero.carry_capacity

func test_new_game_defaults() -> void:
	assert_eq(GameState.day, 1)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.diner_hp, _max_hp())
	assert_eq(GameState.lane_plan.size(), 3)
	assert_eq(GameState.lane_plan[0].main, "north")
	for id in MapLayout.SPOT_IDS:
		assert_eq(GameState.buildings[id], {"level": 0, "paid": 0, "hp": 0.0})

func test_round_trip_identity() -> void:
	GameState.add_gold(55)
	GameState.add_freezer(7)
	var d := GameState.to_dict()
	GameState.new_game(999)
	GameState.from_dict(d)
	assert_eq(GameState.to_dict(), d)

func test_round_trip_through_json_keeps_ints() -> void:
	# Review Focus 1: S3 will serialize; JSON turns ints into floats.
	GameState.add_gold(1000)
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	GameState.advance_day()
	var d := GameState.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	GameState.new_game(1)
	GameState.from_dict(parsed)
	assert_eq(GameState.to_dict(), d)
	assert_eq(typeof(GameState.gold), TYPE_INT)
	assert_eq(typeof(GameState.buildings.fence_w.level), TYPE_INT)
	assert_eq(typeof(GameState.lane_plan[0].main_count), TYPE_INT)

func test_from_dict_emits_state_restored() -> void:
	watch_signals(EventBus)
	GameState.from_dict(GameState.to_dict())
	assert_signal_emitted(EventBus, "state_restored")

func test_carry_capacity_and_transfers() -> void:
	GameState.add_freezer(_cap() + 4)
	assert_eq(GameState.move_freezer_to_carry(_cap() + 4), _cap())
	assert_eq(GameState.carried_steaks, _cap())
	assert_false(GameState.pick_steak())
	assert_eq(GameState.move_carry_to_counter(_cap()), _cap())
	assert_eq(GameState.counter_steaks, _cap())
	assert_eq(GameState.freezer_steaks, 4)

func test_counter_capacity() -> void:
	var cap := Balance.data.economy.counter_capacity
	GameState.counter_steaks = cap - 1  # test-only setup write
	GameState.carried_steaks = 3
	assert_eq(GameState.move_carry_to_counter(3), 1)
	assert_eq(GameState.counter_steaks, cap)

func test_sell_is_atomic_and_partial() -> void:
	var price := Balance.data.economy.gold_per_steak
	GameState.counter_steaks = 1
	watch_signals(EventBus)
	assert_eq(GameState.sell_from_counter(2), 1)
	assert_eq(GameState.counter_steaks, 0)
	assert_eq(GameState.gold_pile, price)
	assert_signal_emitted_with_parameters(EventBus, "steak_sold", [1, price])
	assert_eq(GameState.sell_from_counter(2), 0)

func test_collect_pile() -> void:
	GameState.gold_pile = 9
	assert_eq(GameState.collect_pile(), 9)
	assert_eq(GameState.gold, 9)
	assert_eq(GameState.gold_pile, 0)

func test_pay_builds_and_levels() -> void:
	var cost := GameState.next_level_cost("fence_n")
	GameState.add_gold(cost * 5)
	watch_signals(EventBus)
	assert_eq(GameState.pay_into_spot("fence_n", cost - 1), cost - 1)
	assert_eq(GameState.buildings.fence_n.paid, cost - 1)
	assert_eq(GameState.pay_into_spot("fence_n", cost), 1, "pays only what is left")
	assert_eq(GameState.buildings.fence_n, {"level": 1, "paid": 0, "hp": GameState.fence_max_hp(1)})
	assert_signal_emitted_with_parameters(EventBus, "build_completed", [&"fence_n", 1])
	assert_eq(GameState.gold, cost * 4)
	assert_eq(GameState.next_level_cost("fence_n"), Economy.level_cost("fence_n", 1, Balance.data.build))

func test_diner_fell_once() -> void:
	watch_signals(EventBus)
	GameState.damage_diner(_max_hp() - 1.0)
	GameState.damage_diner(5.0)
	GameState.damage_diner(5.0)
	assert_eq(GameState.diner_hp, 0.0)
	assert_signal_emit_count(EventBus, "diner_fell", 1)

func test_fence_damage_rubble_and_dawn() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_w") * 2)
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_e", GameState.next_level_cost("fence_e"))
	GameState.damage_fence("fence_w", 1e6)
	GameState.damage_fence("fence_e", 1.0)
	assert_eq(GameState.buildings.fence_w.hp, 0.0)
	GameState.damage_diner(_max_hp() / 3.0)
	GameState.heal_for_dawn()
	GameState.reset_destroyed_fences()
	assert_eq(GameState.buildings.fence_w, {"level": 0, "paid": 0, "hp": 0.0})
	assert_eq(GameState.buildings.fence_e.hp, GameState.fence_max_hp(1))
	assert_eq(GameState.diner_hp, _max_hp())

func test_advance_day_makes_new_plan() -> void:
	GameState.advance_day()
	assert_eq(GameState.day, 2)
	assert_ne(GameState.lane_plan[0].side, "")
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`new_game` not found).

- [ ] **Step 3: Implement `Phase` and `EventBus`**

`core/phase.gd`:
```gdscript
class_name Phase
extends RefCounted
## Phase ids (spec 2). Stored as int in signals.

const NIGHT := 0
const DAWN := 1
const DAY := 2

static func name_of(p: int) -> String:
	return ["NIGHT", "DAWN", "DAY"][p]
```

`autoload/EventBus.gd`:
```gdscript
extends Node
## Cross-system signals only (D-037, D-109). Components talk to owners with local signals.

## PhaseController -> all. phase: Phase.NIGHT/DAWN/DAY, day: GameState.day.
signal phase_changed(phase: int, day: int)
## WaveDirector -> HUD. Emitted when the pre-wave delay (first delay or breather) starts.
signal wave_incoming(wave_index: int, main_lane: StringName, side_lane: StringName)
## WaveDirector -> all. side_lane is &"" when there is no side group.
signal wave_started(wave_index: int, main_lane: StringName, side_lane: StringName)
## WaveDirector -> HUD. The wave's last planned enemy has spawned.
signal wave_spawned_out(wave_index: int)
## WaveDirector -> PhaseController, HUD. All planned spawns spawned and none alive (D-044).
signal wave_cleared(wave_index: int)
## WaveDirector -> sims, HUD.
signal enemy_killed(spawn_index: int, lane: StringName, position: Vector3)
## GameState -> HUD, camera. hp_left after the hit.
signal diner_damaged(amount: float, hp_left: float)
## GameState -> PhaseController. Once per fall.
signal diner_fell()
## PhaseController -> HUD, sims.
signal night_failed(day: int)
## GameState -> every stateful node. GameState was replaced wholesale (new_game or from_dict).
signal state_restored()
## GameState -> HUD. delta may be negative.
signal gold_changed(gold: int, delta: int)
## GameState -> build spots, sign. Any level/paid/hp change.
signal building_changed(spot_id: StringName, level: int, paid: int)
## GameState -> fx. A level was completed.
signal build_completed(spot_id: StringName, level: int)
## GameState -> fx.
signal steak_picked(carried: int)
## GameState -> fx, sims.
signal steak_sold(count: int, gold: int)
## GameState -> stations, sign, carry stack. freezer/carried/counter/gold_pile changed; re-read GameState.
signal stocks_changed()
## CloseUpSign -> PhaseController.
signal closeup_requested()
## PhaseController -> HUD. Already translated text.
signal banner_requested(text: String)
## PhaseController -> Hero, CameraRig. Place the hero (new game, restore). Replaces a node call (D-128).
signal hero_place_requested(position: Vector2)
```

- [ ] **Step 4: Implement `GameState`**

`autoload/GameState.gd`:
```gdscript
extends Node
## The only mutable game data (spec 4, D-096). Only these methods change it; they emit EventBus signals.

const SCHEMA_VERSION := 1

var resume_phase := "NIGHT"
var run_seed := 0
var day := 1
var gold := 0
var gold_pile := 0
var freezer_steaks := 0
var counter_steaks := 0
var carried_steaks := 0
var diner_hp := 0.0
var buildings := {}
var lane_plan: Array = []

func new_game(seed: int = 0) -> void:
	run_seed = seed if seed != 0 else Rng.new_run_seed()
	resume_phase = "NIGHT"
	day = 1
	gold = 0
	gold_pile = 0
	freezer_steaks = 0
	counter_steaks = 0
	carried_steaks = 0
	diner_hp = Balance.data.build.diner_max_hp
	buildings = {}
	for id in MapLayout.SPOT_IDS:
		buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
	lane_plan = LanePlanner.plan(run_seed, day, Balance.data.wave)
	EventBus.state_restored.emit()

# --- snapshot -------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"v": SCHEMA_VERSION, "resume_phase": resume_phase, "run_seed": run_seed, "day": day,
		"gold": gold, "gold_pile": gold_pile, "freezer_steaks": freezer_steaks,
		"counter_steaks": counter_steaks, "carried_steaks": carried_steaks, "diner_hp": diner_hp,
		"buildings": buildings.duplicate(true), "lane_plan": lane_plan.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	assert(int(d.v) == SCHEMA_VERSION, "unknown snapshot schema")
	resume_phase = String(d.resume_phase)
	run_seed = int(d.run_seed)
	day = int(d.day)
	gold = int(d.gold)
	gold_pile = int(d.gold_pile)
	freezer_steaks = int(d.freezer_steaks)
	counter_steaks = int(d.counter_steaks)
	carried_steaks = int(d.carried_steaks)
	diner_hp = float(d.diner_hp)
	buildings = {}
	for id in d.buildings:
		var b: Dictionary = d.buildings[id]
		buildings[String(id)] = {"level": int(b.level), "paid": int(b.paid), "hp": float(b.hp)}
	lane_plan = []
	for w in d.lane_plan:
		lane_plan.append({
			"main": String(w.main), "side": String(w.side),
			"main_count": int(w.main_count), "side_count": int(w.side_count), "hp_mult": float(w.hp_mult),
		})
	EventBus.state_restored.emit()

# --- gold and stocks ------------------------------------------------------

func add_gold(n: int) -> void:
	if n == 0:
		return
	gold += n
	EventBus.gold_changed.emit(gold, n)

func collect_pile() -> int:
	var n := gold_pile
	if n <= 0:
		return 0
	gold_pile = 0
	gold += n
	EventBus.stocks_changed.emit()
	EventBus.gold_changed.emit(gold, n)
	return n

func add_freezer(n: int) -> void:
	if n <= 0:
		return
	freezer_steaks += n
	EventBus.stocks_changed.emit()

func pick_steak() -> bool:
	if carried_steaks >= Balance.data.hero.carry_capacity:
		return false
	carried_steaks += 1
	EventBus.steak_picked.emit(carried_steaks)
	EventBus.stocks_changed.emit()
	return true

func move_freezer_to_carry(n: int = 1) -> int:
	var m := mini(n, mini(freezer_steaks, Balance.data.hero.carry_capacity - carried_steaks))
	if m <= 0:
		return 0
	freezer_steaks -= m
	carried_steaks += m
	EventBus.stocks_changed.emit()
	return m

func move_carry_to_counter(n: int = 1) -> int:
	var m := mini(n, mini(carried_steaks, Balance.data.economy.counter_capacity - counter_steaks))
	if m <= 0:
		return 0
	carried_steaks -= m
	counter_steaks += m
	EventBus.stocks_changed.emit()
	return m

func sell_from_counter(want: int) -> int:
	var m := mini(want, counter_steaks)
	if m <= 0:
		return 0
	counter_steaks -= m
	var g := m * Balance.data.economy.gold_per_steak
	gold_pile += g
	EventBus.steak_sold.emit(m, g)
	EventBus.stocks_changed.emit()
	return m

# --- buildings ------------------------------------------------------------

func next_level_cost(spot_id: String) -> int:
	return Economy.level_cost(spot_id, int(buildings[spot_id].level), Balance.data.build)

func remaining_cost(spot_id: String) -> int:
	var cost := next_level_cost(spot_id)
	return -1 if cost < 0 else cost - int(buildings[spot_id].paid)

func fence_max_hp(level: int) -> float:
	return Balance.data.build.fence_hp[level - 1]

func pay_into_spot(spot_id: String, amount: int) -> int:
	var cost := next_level_cost(spot_id)
	if cost < 0:
		return 0
	var b: Dictionary = buildings[spot_id]
	var pay := mini(amount, mini(gold, cost - int(b.paid)))
	if pay <= 0:
		return 0
	gold -= pay
	b.paid = int(b.paid) + pay
	EventBus.gold_changed.emit(gold, -pay)
	if int(b.paid) >= cost:
		b.level = int(b.level) + 1
		b.paid = 0
		if MapLayout.spot_kind(spot_id) == "fence":
			b.hp = fence_max_hp(b.level)
		EventBus.building_changed.emit(StringName(spot_id), b.level, b.paid)
		EventBus.build_completed.emit(StringName(spot_id), b.level)
	else:
		EventBus.building_changed.emit(StringName(spot_id), b.level, b.paid)
	return pay

func damage_fence(spot_id: String, amount: float) -> void:
	var b: Dictionary = buildings[spot_id]
	if int(b.level) < 1 or float(b.hp) <= 0.0:
		return
	b.hp = maxf(float(b.hp) - amount, 0.0)
	EventBus.building_changed.emit(StringName(spot_id), b.level, b.paid)

func damage_diner(amount: float) -> void:
	if diner_hp <= 0.0:
		return
	diner_hp = maxf(diner_hp - amount, 0.0)
	EventBus.diner_damaged.emit(amount, diner_hp)
	if diner_hp <= 0.0:
		EventBus.diner_fell.emit()

func diner_fraction() -> float:
	return diner_hp / Balance.data.build.diner_max_hp

# --- dawn -----------------------------------------------------------------

func heal_for_dawn() -> void:
	diner_hp = Balance.data.build.diner_max_hp
	for id in buildings:
		var b: Dictionary = buildings[id]
		if MapLayout.spot_kind(id) == "fence" and int(b.level) >= 1 and float(b.hp) > 0.0:
			b.hp = fence_max_hp(b.level)
			EventBus.building_changed.emit(StringName(id), b.level, b.paid)

func reset_destroyed_fences() -> void:
	for id in buildings:
		var b: Dictionary = buildings[id]
		if MapLayout.spot_kind(id) == "fence" and int(b.level) >= 1 and float(b.hp) <= 0.0:
			buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
			EventBus.building_changed.emit(StringName(id), 0, 0)

func advance_day() -> void:
	day += 1
	lane_plan = LanePlanner.plan(run_seed, day, Balance.data.wave)
```

Test code may write fields directly for setup (as `test_counter_capacity` does). Game code never does. The reviewer checks this with `grep -rnE "GameState\.[a-z_.]+ *[-+*/]?=[^=]" core components actors world ui`, which must return nothing.

- [ ] **Step 5: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add core/phase.gd autoload/EventBus.gd autoload/GameState.gd tests/unit/test_game_state.gd
git commit -m "feat: add EventBus signals and GameState with snapshot round trip"
```

### Task 11: Visuals, `WorldLabel` with the Nunito font, `NodePool`, `Health`, `Targetable`

**Files:**
- Create:
  - `world/visuals.gd`, `ui/world_label/world_label.gd`, `ui/fonts/Nunito.ttf`
  - `components/node_pool.gd`, `components/health.gd`, `components/targetable.gd`
  - `docs/ASSET_LICENSES.md`
- Modify: `project.godot` (`[gui]` theme font)
- Test: `tests/unit/test_components.gd`, `tests/unit/test_glyphs.gd`

**Interfaces:**
- Produces:
  - **`Visuals`:**
    - `Visuals.COLORS: Dictionary`
    - `Visuals.material(color: Color) -> StandardMaterial3D` (cached)
    - `Visuals.box(size: Vector3, color: Color) -> MeshInstance3D`
    - `Visuals.capsule(radius: float, height: float, color: Color) -> MeshInstance3D`
    - `Visuals.cylinder(radius: float, height: float, color: Color) -> MeshInstance3D`
    - `Visuals.cone(radius: float, height: float, color: Color) -> MeshInstance3D`
    - `Visuals.plane(size: Vector2, color: Color) -> MeshInstance3D`
    - `Visuals.visual_root() -> Node3D`: a node named `"Visual"`, the S4 swap point.
  - **`WorldLabel`** (extends `Label3D`): `WorldLabel.FONT_PATH`, `WorldLabel.make(text: String, size: int = 48) -> WorldLabel`.
  - **`NodePool`:**
    - `setup(factory: Callable, prewarm: int) -> void`
    - `acquire() -> Node3D`, `release(n: Node3D) -> void`, `recall_all() -> int` (the number recalled; part of the D-128 interface)
    - `active() -> Array` (in acquire order), `size: int`
    - `signal grew(new_size: int)`
    - Items may implement `on_acquire()` and `on_release()`. Pools are never found by group (D-128).
  - **`Health`:** `max_hp`, `hp`, `reset(max_value: float)`, `damage(amount: float)`, `is_alive() -> bool`, `signal died`, `signal damaged(amount: float)`.
  - **`Targetable`:** `kind: StringName`, `spawn_index: int`.

- [ ] **Step 1: Add the font and license log**

```bash
mkdir -p ui/fonts
curl -fL -o "ui/fonts/Nunito.ttf" "https://github.com/google/fonts/raw/main/ofl/nunito/Nunito%5Bwght%5D.ttf"
file ui/fonts/Nunito.ttf   # expect: TrueType Font data
```

If that URL 404s, download the Nunito family from `https://fonts.google.com/specimen/Nunito`, take the variable `Nunito[wght].ttf` (or `static/Nunito-Regular.ttf`) and save it as `ui/fonts/Nunito.ttf`.

`docs/ASSET_LICENSES.md`:
```markdown
# Asset licenses

One line per asset, added when the asset is first used (IDEA.md, D-079). S4 appends here.

| Asset | Path | Source | License | Added |
|---|---|---|---|---|
| Nunito (variable font) | ui/fonts/Nunito.ttf | https://github.com/google/fonts/tree/main/ofl/nunito | SIL OFL 1.1 | 2026-09-30 (S1) |
```

Append to `project.godot`:
```ini
[gui]
theme/custom_font="res://ui/fonts/Nunito.ttf"
```

- [ ] **Step 2: Write the failing tests**

`tests/unit/test_glyphs.gd`:
```gdscript
extends GutTest
## D-079: the font must cover Vietnamese diacritics.

const SAMPLE := "Quán ăn mở cửa — Đêm thứ 3"

func test_nunito_has_all_glyphs() -> void:
	var font: FontFile = load(WorldLabel.FONT_PATH)
	assert_not_null(font)
	var missing := ""
	for i in SAMPLE.length():
		var cp := SAMPLE.unicode_at(i)
		if cp != 32 and not font.has_char(cp):
			missing += SAMPLE[i]
	assert_eq(missing, "", "missing glyphs")

func test_world_label_uses_nunito() -> void:
	var l := WorldLabel.make("x")
	assert_eq(l.font.resource_path, WorldLabel.FONT_PATH)
	l.free()
```

`tests/unit/test_components.gd`:
```gdscript
extends GutTest

func test_health_dies_once() -> void:
	var h := Health.new()
	add_child_autofree(h)
	h.reset(10.0)
	watch_signals(h)
	h.damage(4.0)
	h.damage(8.0)
	h.damage(8.0)
	assert_eq(h.hp, 0.0)
	assert_false(h.is_alive())
	assert_signal_emit_count(h, "died", 1)

func test_pool_prewarm_acquire_release() -> void:
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Node3D.new(), 2)
	assert_eq(pool.size, 2)
	var a := pool.acquire()
	var b := pool.acquire()
	assert_eq(pool.active(), [a, b])
	assert_true(a.visible)
	pool.release(a)
	assert_false(a.visible)
	assert_eq(pool.active(), [b])
	pool.recall_all()
	assert_eq(pool.active(), [])

func test_pool_grows_and_warns() -> void:
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Node3D.new(), 1)
	watch_signals(pool)
	pool.acquire()
	pool.acquire()
	assert_eq(pool.size, 2)
	assert_signal_emitted_with_parameters(pool, "grew", [2])

func test_pool_release_is_idempotent() -> void:
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Node3D.new(), 1)
	var a := pool.acquire()
	pool.release(a)
	pool.release(a)
	assert_eq(pool.active(), [])
	assert_eq(pool.acquire(), a)
```

- [ ] **Step 3: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`WorldLabel`, `Health`, `NodePool` not declared).

- [ ] **Step 4: Implement**

`world/visuals.gd`:
```gdscript
class_name Visuals
extends RefCounted
## Placeholder primitive meshes (D-016, D-075). Every actor keeps a child named "Visual" for S4.

const COLORS := {
	"hero": Color("3a7bd5"), "hat": Color("ffffff"), "boar": Color("d64545"), "traveler": Color("9a9a9a"),
	"diner": Color("e8d8b0"), "counter": Color("8b5a2b"), "freezer": Color("5fd3e0"), "steak": Color("7a3b1e"),
	"coin": Color("f2c230"), "tower": Color("8c8c8c"), "fence": Color("9b6b3a"), "telegraph": Color("e03030"),
	"ground": Color("6fa35a"), "lane": Color("b59a6a"), "road": Color("7d7d7d"), "sign": Color("ffffff"),
	"pip": Color("ffd24a"), "flash": Color("ffffff"),
}

static var _materials := {}

static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		_materials[key] = m
	return _materials[key]

static func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func box(size: Vector3, color: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(m, color)

static func capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return _mesh(m, color)

static func cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	return _mesh(m, color)

static func cone(radius: float, height: float, color: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	return _mesh(m, color)

static func plane(size: Vector2, color: Color) -> MeshInstance3D:
	var m := PlaneMesh.new()
	m.size = size
	return _mesh(m, color)

static func visual_root() -> Node3D:
	var n := Node3D.new()
	n.name = "Visual"
	return n
```

`ui/world_label/world_label.gd`:
```gdscript
class_name WorldLabel
extends Label3D
## Billboard 3D label using Nunito (D-073, D-079). Label3D does not read the Theme.

const FONT_PATH := "res://ui/fonts/Nunito.ttf"

static func make(text_value: String, size: int = 48) -> WorldLabel:
	var l := WorldLabel.new()
	l.text = text_value
	l.font_size = size
	return l

func _init() -> void:
	font = load(FONT_PATH)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size = 0.01
	outline_size = 12
	no_depth_test = true
	modulate = Color.WHITE
```

`components/node_pool.gd`:
```gdscript
class_name NodePool
extends Node
## Prewarmed pool (D-017, D-061). Items are hidden and disabled while free. Grows with a warning.

signal grew(new_size: int)

var size := 0
var _factory: Callable
var _free: Array = []
var _active: Array = []

func setup(factory: Callable, prewarm: int) -> void:
	_factory = factory
	for i in prewarm:
		_make()

func acquire() -> Node3D:
	if _free.is_empty():
		_make()
		push_warning("NodePool %s grew to %d" % [name, size])
		grew.emit(size)
	var n: Node3D = _free.pop_back()
	_active.append(n)
	n.visible = true
	n.process_mode = Node.PROCESS_MODE_INHERIT
	if n.has_method("on_acquire"):
		n.on_acquire()
	return n

func release(n: Node3D) -> void:
	var i := _active.find(n)
	if i < 0:
		return
	_active.remove_at(i)
	if n.has_method("on_release"):
		n.on_release()
	n.visible = false
	n.process_mode = Node.PROCESS_MODE_DISABLED
	_free.append(n)

## D-128 interface: return every active item to the pool; returns how many were recalled.
func recall_all() -> int:
	var count := _active.size()
	for n in _active.duplicate():
		release(n)
	return count

func active() -> Array:
	return _active

func _make() -> void:
	var n: Node3D = _factory.call()
	size += 1
	n.visible = false
	n.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(n)
	_free.append(n)
```

`components/health.gd`:
```gdscript
class_name Health
extends Node
## Hit points for enemies. Diner and fence HP live in GameState.

signal died
signal damaged(amount: float)

var max_hp := 1.0
var hp := 1.0

func reset(max_value: float) -> void:
	max_hp = max_value
	hp = max_value

func is_alive() -> bool:
	return hp > 0.0

func damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount)
	if hp <= 0.0:
		died.emit()
```

`components/targetable.gd`:
```gdscript
class_name Targetable
extends Node
## Marks a node as a target of a kind (&"enemy", &"fence", &"diner"); spawn_index breaks ties.

@export var kind: StringName = &"enemy"
var spawn_index := -1
```

- [ ] **Step 5: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0. If the glyph test reports missing characters, the downloaded file isn't the full Nunito. Re-download the variable font. Don't substitute another font without escalating (D-079).

- [ ] **Step 6: Commit**

```bash
git add world/visuals.gd ui components docs/ASSET_LICENSES.md project.godot tests/unit/test_glyphs.gd tests/unit/test_components.gd
git commit -m "feat: add placeholder visuals, Nunito world labels, pool and health components"
```

### Task 12: `Main` and the `World` map skeleton

**Files:**
- Modify: `world/main.gd`, `world/main.tscn`
- Create: `world/world.gd`, `world/lanes/lane.gd`
- Test: `tests/unit/test_world_build.gd`

**Interfaces:**
- Produces:
  - **`Main`:** `auto_start: bool`, `@export world: World`, and `static create(p_auto_start := false) -> Main`, which instantiates `world/main.tscn`. Tests and tools always use `Main.create()`, never `Main.new()`. Later tasks add `hero`, `phase_controller` (an export), `camera_rig`, `hud` and `focus_pause`.
  - **`world/main.tscn`** holds the nodes that PhaseController orchestrates, wired with typed `@export` references (D-128). Everything else is built in code.
  - **`World`:** `lanes: Dictionary` (String → `Lane`), `diner_body: StaticBody3D`. Later tasks add the pools, `wave_director`, `build_spots`, the stations, `traveler_spawner`, `telegraph_markers` and `fly_fx`.
  - **`Lane`:** `lane_id: String`, `path3d: Path3D`, `entrance_position() -> Vector3`.
  - **Collision layers:** layer 1 = static world (diner, counter, freezer only; towers and fences never collide, D-094, D-125); layer 2 = hero.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_world_build.gd`:
```gdscript
extends GutTest

func before_each() -> void:
	Balance.reset()

func test_main_builds_world_without_starting() -> void:
	var main := Main.create()
	add_child_autofree(main)
	assert_not_null(main.world)
	assert_eq(main.world.lanes.size(), 3)
	assert_not_null(main.world.diner_body)
	var shape: BoxShape3D = main.world.diner_body.get_child(0).shape
	assert_eq(shape.size, Vector3(8, 3, 8))

func test_lane_curve_matches_layout() -> void:
	var main := Main.create()
	add_child_autofree(main)
	var lane: Lane = main.world.lanes["west"]
	assert_eq(lane.path3d.curve.point_count, 3)
	assert_eq(lane.entrance_position(), Vector3(-16, 0, -24))
```

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`World` / `Lane` not declared, `main.world` is null).

- [ ] **Step 3: Implement**

`world/lanes/lane.gd`:
```gdscript
class_name Lane
extends Node3D
## One lane: Path3D (editor/debug view of MapLayout.LANE_PATHS), ground strip, entrance post.

var lane_id := ""
var path3d: Path3D

func setup(id: String) -> void:
	lane_id = id
	name = "Lane_" + id
	path3d = Path3D.new()
	path3d.curve = Curve3D.new()
	for p in MapLayout.LANE_PATHS[id]:
		path3d.curve.add_point(MapLayout.to3(p))
	add_child(path3d)
	var pts: Array = MapLayout.LANE_PATHS[id]
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var strip := Visuals.box(Vector3(3.0, 0.02, a.distance_to(b)), Visuals.COLORS.lane)
		strip.position = MapLayout.to3((a + b) * 0.5, 0.01)
		strip.rotation.y = atan2(b.x - a.x, b.y - a.y)
		add_child(strip)
	var post := Visuals.cylinder(0.25, 1.5, Visuals.COLORS.telegraph)
	post.position = entrance_position() + Vector3(0, 0.75, 0)
	add_child(post)

func entrance_position() -> Vector3:
	return MapLayout.to3(MapLayout.LANE_PATHS[lane_id][0])
```

`world/world.gd`:
```gdscript
class_name World
extends Node3D
## Builds the map in code from MapLayout (spec 3.3, 6.1). Extended by later tasks.

var lanes := {}
var diner_body: StaticBody3D

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_diner()
	_build_lanes()

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = false
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9fd3e8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)

func _build_ground() -> void:
	var size := MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN
	var ground := Visuals.plane(size, Visuals.COLORS.ground)
	ground.position = MapLayout.to3((MapLayout.BOUNDS_MIN + MapLayout.BOUNDS_MAX) * 0.5)
	add_child(ground)
	var road := Visuals.box(Vector3(size.x, 0.02, 2.0), Visuals.COLORS.road)
	road.position = Vector3(0, 0.01, MapLayout.ROAD_Z)
	add_child(road)

func _build_diner() -> void:
	diner_body = add_static_box("Diner", Vector3(8, MapLayout.DINER_HEIGHT, 8), Vector2.ZERO, Visuals.COLORS.diner)

func _build_lanes() -> void:
	for id in LanePlanner.LANES:
		var lane := Lane.new()
		lane.setup(id)
		add_child(lane)
		lanes[id] = lane

## Static collider + visual box on layer 1, standing on the ground at xz.
func add_static_box(node_name: String, size: Vector3, xz: Vector2, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	body.add_child(shape)
	var vis := Visuals.visual_root()
	var mesh := Visuals.box(size, color)
	mesh.position.y = size.y * 0.5
	vis.add_child(mesh)
	body.add_child(vis)
	body.position = MapLayout.to3(xz)
	add_child(body)
	return body
```

`world/main.gd` (replace):
```gdscript
class_name Main
extends Node3D
## Scene root (world/main.tscn, spec 3.3). Orchestrated nodes live in the scene and are wired with
## typed @export references (D-128); everything else is built in code. Extended in Tasks 13–32.

const SCENE_PATH := "res://world/main.tscn"

@export var auto_start := true
@export var world: World

static func create(p_auto_start := false) -> Main:
	var m: Main = (load(SCENE_PATH) as PackedScene).instantiate()
	m.auto_start = p_auto_start
	return m
```

Replace the Task 1 stub

`world/main.tscn` (full content at this stage):
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://world/main.gd" id="1_main"]
[ext_resource type="Script" path="res://world/world.gd" id="2_world"]

[node name="Main" type="Node3D" node_paths=PackedStringArray("world")]
script = ExtResource("1_main")
world = NodePath("World")

[node name="World" type="Node3D" parent="."]
script = ExtResource("2_world")
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add world tests/unit/test_world_build.gd
git commit -m "feat: add Main and World map skeleton built from MapLayout"
```

---
## Phase 4: Headless night loop

### Task 13: `Boar`, `Steak`, `TargetProviders` and the enemy/steak pools

**Files:**
- Create: `actors/enemy/boar.gd`, `actors/pickups/steak.gd`, `world/target_providers.gd`
- Modify: `world/world.gd` (pools), `world/main.tscn`
- Test: `tests/unit/test_boar.gd`

**Interfaces:**
- Consumes: `EnemyPath`, `MapLayout`, `GameState.damage_fence/damage_diner`, `Health`, `Targetable`, `NodePool`, `Visuals`.
- Produces:
  - **`Boar`:**
    - fields: `lane: String`, `spawn_index: int`, `dist: float`, `offset: float`, `alive: bool`, `health: Health`, `visual: Node3D`, `current_target: Dictionary`
    - `spawn(p_lane: String, p_index: int, p_offset: float, hp_mult: float, director: Object) -> void`
    - `path_length() -> float`, `at_path_end() -> bool`
    - `take_hit(amount: float) -> void`
    - `candidate() -> Dictionary` (the Task 7 candidate format)
    - `play_death(pool: NodePool) -> void`
    - `on_release() -> void`
    - The director object must provide `providers: TargetProviders` and `on_enemy_died(boar: Boar)`.
  - **`Steak`:** `place(pos: Vector3) -> void`.
  - **`TargetProviders`:** `register(kind: StringName, fn: Callable)`, `find_target(enemy: Boar) -> Dictionary`, static `fence_on_lane(enemy) -> Dictionary`, static `diner(enemy) -> Dictionary`. A target is `{"kind": StringName, "spot_id": String}` for a fence, or `{"kind": &"diner"}`.
  - **`World`:** `enemy_pool: NodePool`, `steak_pool: NodePool`, and static `World.pool_sizes(bd: BalanceData) -> Dictionary` (`{enemy, steak, projectile, fx}`; steaks from the capped day-10 counts, D-124).

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_boar.gd`:
```gdscript
extends GutTest

class FakeDirector:
	extends RefCounted
	var providers := TargetProviders.new()
	var died: Array = []
	func _init() -> void:
		providers.register(&"fence_on_lane", func(e): return TargetProviders.fence_on_lane(e))
		providers.register(&"diner", func(e): return TargetProviders.diner(e))
	func on_enemy_died(b) -> void:
		died.append(b.spawn_index)

const DT := 1.0 / 60.0
var dir: FakeDirector

func before_each() -> void:
	Balance.reset()
	GameState.new_game(7)
	dir = FakeDirector.new()

func _boar(lane: String, offset := 0.0) -> Boar:
	var b := Boar.new()
	b.process_mode = Node.PROCESS_MODE_DISABLED  # tests step it by hand
	add_child_autofree(b)
	b.spawn(lane, 0, offset, 1.0, dir)
	return b

func _step(b: Boar, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		b._physics_process(DT)

func _walk_time(lane: String) -> float:
	return MapLayout.path_length(lane) / Balance.data.enemy.speed

func test_walks_to_zone_and_hits_diner() -> void:
	var eb := Balance.data.enemy
	var max_hp := Balance.data.build.diner_max_hp
	var b := _boar("north", 0.7)
	_step(b, _walk_time("north") + 0.1)
	assert_true(b.at_path_end())
	assert_true(Geometry.rect_contains(MapLayout.ZONE_RECTS.north, Vector2(b.position.x, b.position.z)))
	assert_eq(GameState.diner_hp, max_hp)
	_step(b, eb.attack_interval - 0.05)
	assert_eq(GameState.diner_hp, max_hp - eb.damage)

func test_standing_fence_blocks_and_takes_damage() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	var b := _boar("north")
	_step(b, _walk_time("north") + 3.0 * Balance.data.enemy.attack_interval)
	var fence_dist := b.path_length() - MapLayout.FENCE_OFFSET_FROM_END
	assert_almost_eq(b.dist, fence_dist - Balance.data.enemy.reach, 0.05)
	assert_lt(GameState.buildings.fence_n.hp, GameState.fence_max_hp(1))
	assert_eq(GameState.diner_hp, Balance.data.build.diner_max_hp)

func test_rubble_does_not_block() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	GameState.damage_fence("fence_n", 1000.0)
	var b := _boar("north")
	_step(b, _walk_time("north") + 0.1)
	assert_true(b.at_path_end())

func test_priority_is_data_driven() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	Balance.data.wave.target_priority.kinds.assign([&"diner"])
	var b := _boar("north")
	_step(b, _walk_time("north") + 0.1)
	assert_true(b.at_path_end(), "fence ignored when not in priority list")

func test_death_reports_once() -> void:
	var b := _boar("west")
	b.take_hit(10.0)
	b.take_hit(25.0)
	b.take_hit(25.0)
	assert_false(b.alive)
	assert_eq(dir.died, [0])

func test_hp_mult_applies() -> void:
	var b := Boar.new()
	add_child_autofree(b)
	b.spawn("east", 3, 0.0, 1.15, dir)
	assert_almost_eq(b.health.max_hp, Balance.data.enemy.hp * 1.15, 0.0001)
	assert_eq(b.candidate().spawn_index, 3)

func test_pool_sizes_from_balance() -> void:
	# PINNED REFERENCE: spec 11 at the default Balance (D-124: steaks from the CAPPED day-10 counts
	# 17 + 25 + 30). If Task 35 changes a wave or economy value, update this row and spec 11 together.
	assert_eq(World.pool_sizes(Balance.data), {"enemy": 40, "steak": 173, "projectile": 24, "fx": 32})
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`TargetProviders` not declared).

- [ ] **Step 3: Implement**

`world/target_providers.gd`:
```gdscript
class_name TargetProviders
extends RefCounted
## Target kinds by name (D-004, D-049). Enemies ask kinds in Balance.wave.target_priority order.
## S2 registers &"guard" here without touching Boar.

var _providers := {}

func register(kind: StringName, fn: Callable) -> void:
	_providers[kind] = fn

func find_target(enemy) -> Dictionary:
	for kind in Balance.data.wave.target_priority.kinds:
		if _providers.has(kind):
			var t: Dictionary = _providers[kind].call(enemy)
			if not t.is_empty():
				return t
	return {}

static func fence_on_lane(enemy) -> Dictionary:
	var spot_id: String = MapLayout.LANE_FENCE[enemy.lane]
	var b: Dictionary = GameState.buildings[spot_id]
	if int(b.level) < 1 or float(b.hp) <= 0.0:
		return {}
	var fence_dist: float = enemy.path_length() - MapLayout.FENCE_OFFSET_FROM_END
	if enemy.dist >= fence_dist - Balance.data.enemy.reach - 1e-4:
		return {"kind": &"fence_on_lane", "spot_id": spot_id}
	return {}

static func diner(enemy) -> Dictionary:
	return {"kind": &"diner"} if enemy.at_path_end() else {}
```

`actors/enemy/boar.gd`:
```gdscript
class_name Boar
extends Node3D
## The one S1 monster (spec 7.2). Moved in code along its lane; never uses physics.

var lane := ""
var spawn_index := -1
var dist := 0.0
var offset := 0.0
var alive := false
var health: Health
var targetable: Targetable
var visual: Node3D
var current_target: Dictionary = {}
var _mesh: MeshInstance3D
var _length := 0.0
var _stop_dist := INF
var _attack_timer := 0.0
var _director: Object
var _death_tween: Tween

func _init() -> void:
	name = "Boar"
	health = Health.new()
	add_child(health)
	health.died.connect(_on_died)
	targetable = Targetable.new()
	targetable.kind = &"enemy"
	add_child(targetable)
	visual = Visuals.visual_root()
	_mesh = Visuals.capsule(0.35, 1.0, Visuals.COLORS.boar)
	_mesh.position.y = 0.5
	visual.add_child(_mesh)
	add_child(visual)

func spawn(p_lane: String, p_index: int, p_offset: float, hp_mult: float, director: Object) -> void:
	lane = p_lane
	spawn_index = p_index
	targetable.spawn_index = p_index
	offset = p_offset
	_director = director
	dist = 0.0
	_attack_timer = 0.0
	current_target = {}
	_length = MapLayout.path_length(lane)
	health.reset(Balance.data.enemy.hp * hp_mult)
	visual.scale = Vector3.ONE
	alive = true
	_update_position()

func path_length() -> float:
	return _length

func at_path_end() -> bool:
	return dist >= _length - 1e-4

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var eb := Balance.data.enemy
	current_target = _director.providers.find_target(self)
	if current_target.is_empty():
		_attack_timer = 0.0
		var step := eb.speed * delta
		var next := minf(dist + step, _length)
		# do not walk past a standing fence's stop point in one tick
		var spot_id: String = MapLayout.LANE_FENCE[lane]
		var b: Dictionary = GameState.buildings[spot_id]
		if int(b.level) >= 1 and float(b.hp) > 0.0:
			var stop := _length - MapLayout.FENCE_OFFSET_FROM_END - eb.reach
			if dist <= stop:
				next = minf(next, stop)
		dist = next
		_update_position()
		return
	_attack_timer += delta
	if _attack_timer >= eb.attack_interval - 1e-6:
		_attack_timer -= eb.attack_interval
		match current_target.kind:
			&"fence_on_lane":
				GameState.damage_fence(current_target.spot_id, eb.damage)
			&"diner":
				GameState.damage_diner(eb.damage)

func take_hit(amount: float) -> void:
	if alive:
		health.damage(amount)

func candidate() -> Dictionary:
	return {"position": global_position, "spawn_index": spawn_index, "ref": self}

func play_death(pool: NodePool) -> void:
	_death_tween = create_tween()
	_death_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_death_tween.tween_property(visual, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	_death_tween.tween_callback(pool.release.bind(self))

func on_release() -> void:
	alive = false
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null

func _on_died() -> void:
	alive = false
	_director.on_enemy_died(self)

func _update_position() -> void:
	var p := EnemyPath.position_at(lane, dist, offset, Balance.data.enemy.offset_fade_distance)
	position = MapLayout.to3(p)
```

`actors/pickups/steak.gd`:
```gdscript
class_name Steak
extends Node3D
## A cartoon steak on the ground (spec 7.8). Picked up by the hero's Magnet.

func _init() -> void:
	name = "Steak"
	var v := Visuals.visual_root()
	var m := Visuals.box(Vector3(0.35, 0.18, 0.25), Visuals.COLORS.steak)
	m.position.y = 0.12
	v.add_child(m)
	add_child(v)

func place(pos: Vector3) -> void:
	position = Vector3(pos.x, 0.0, pos.z)
```

Modify `world/world.gd`: add the exports, a call at the end of `_ready()`, and the functions. The pool nodes are declared in `main.tscn` (below), so PhaseController can reference them with typed exports (D-128).

```gdscript
@export var enemy_pool: NodePool
@export var steak_pool: NodePool

# in _ready(), after _build_lanes():
	_setup_pools()

static func pool_sizes(bd: BalanceData) -> Dictionary:
	var steaks := 0
	for w in bd.wave.base_counts.size():
		steaks += WaveMath.total_count(10, w, bd.wave)  # capped counts (D-124)
	return {
		"enemy": bd.wave.max_wave_size + 10,
		"steak": int(ceil(steaks * bd.economy.steaks_per_kill * 1.2)),
		"projectile": 24,
		"fx": 32,
	}

func _setup_pools() -> void:
	var sizes := World.pool_sizes(Balance.data)
	enemy_pool.setup(func(): return Boar.new(), sizes.enemy)
	steak_pool.setup(func(): return Steak.new(), sizes.steak)
```

Add the pool nodes

`world/main.tscn` (full content at this stage):
```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://world/main.gd" id="1_main"]
[ext_resource type="Script" path="res://world/world.gd" id="2_world"]
[ext_resource type="Script" path="res://components/node_pool.gd" id="3_pool"]

[node name="Main" type="Node3D" node_paths=PackedStringArray("world")]
script = ExtResource("1_main")
world = NodePath("World")

[node name="World" type="Node3D" parent="." node_paths=PackedStringArray("enemy_pool", "steak_pool")]
script = ExtResource("2_world")
enemy_pool = NodePath("EnemyPool")
steak_pool = NodePath("SteakPool")

[node name="EnemyPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="SteakPool" type="Node" parent="World"]
script = ExtResource("3_pool")
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add actors world tests/unit/test_boar.gd
git commit -m "feat: add Boar enemy, steaks, data-driven target providers and pools"
```

### Task 14: `WaveDirector`

**Files:**
- Create: `world/wave_director.gd`
- Modify: `world/world.gd`, `world/main.tscn`
- Test: `tests/unit/test_wave_director.gd`

**Interfaces:**
- Consumes: `WaveSchedule`, `Rng.stream`, `GameState.lane_plan`, `Boar.spawn/play_death`, `Steak.place`, `TargetProviders`.
- Produces:
  - **`WaveDirector`:**
    - `enemy_pool`, `steak_pool`, `providers: TargetProviders`, `wave_index: int`, `state: int` (`State.IDLE/WAITING/ACTIVE`)
    - `setup(p_enemy_pool: NodePool, p_steak_pool: NodePool)`
    - **D-128 interface:** `start_night(plan: Array)`, `stop()`
    - the `plan` passed in is used for the whole night (`GameState.lane_plan` from PhaseController)
    - `on_enemy_died(boar: Boar)`
    - `alive_enemies() -> Array`, `alive_count() -> int`, `enemy_candidates() -> Array`
    - `upcoming_main_lane() -> String`
    - `debug_spawn(lane: String, offset: float = 0.0, hp_mult: float = 1.0) -> Boar`
    - `debug_kill_all()`
  - It emits `wave_incoming`, `wave_started`, `wave_spawned_out`, `wave_cleared` and `enemy_killed`.
  - **`World`:** `wave_director: WaveDirector`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_wave_director.gd`:
```gdscript
extends GutTest

var main: Main
var wd: WaveDirector

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(4242)
	wd = main.world.wave_director

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_first_wave_starts_after_delay() -> void:
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	assert_signal_emitted_with_parameters(EventBus, "wave_incoming", [0, &"north", &""])
	await _ticks(299)
	assert_signal_not_emitted(EventBus, "wave_started")
	await _ticks(2)
	assert_signal_emitted_with_parameters(EventBus, "wave_started", [0, &"north", &""])
	assert_eq(wd.alive_count(), 1)

func test_spawns_follow_schedule_and_spawn_out() -> void:
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	await _ticks(301 + 48 * 3)  # 3 more spawns at 0.8 s
	assert_eq(wd.alive_count(), 4)
	assert_signal_emitted_with_parameters(EventBus, "wave_spawned_out", [0])

func test_clear_breather_next_wave() -> void:
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	await _ticks(301 + 48 * 3 + 2)
	wd.debug_kill_all()
	await _ticks(2)
	assert_signal_emitted_with_parameters(EventBus, "wave_cleared", [0])
	assert_eq(get_signal_parameters(EventBus, "wave_incoming"), [1, StringName(GameState.lane_plan[1].main), &""])
	await _ticks(595)
	assert_signal_emit_count(EventBus, "wave_started", 1)
	await _ticks(10)
	assert_signal_emit_count(EventBus, "wave_started", 2)

func test_main_group_dead_before_side_spawns_is_not_clear() -> void:
	GameState.advance_day()  # day 2: side groups
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	await _ticks(301 + 60)  # 1 s into wave 0: side group starts at 4 s
	wd.debug_kill_all()
	await _ticks(30)
	assert_signal_not_emitted(EventBus, "wave_cleared")
	await _ticks(60 * 5)
	wd.debug_kill_all()
	await _ticks(2)
	assert_signal_emitted_with_parameters(EventBus, "wave_cleared", [0])

func test_kill_drops_two_steaks() -> void:
	wd.start_night(GameState.lane_plan)
	await _ticks(302)
	wd.debug_kill_all()
	await _ticks(1)
	assert_eq(main.world.steak_pool.active().size(), 2)

func test_same_seed_same_offsets() -> void:
	wd.start_night(GameState.lane_plan)
	await _ticks(301 + 48 * 3 + 1)
	var a: Array = wd.alive_enemies().map(func(b): return b.offset)
	wd.stop()
	main.world.enemy_pool.recall_all()
	wd.start_night(GameState.lane_plan)
	await _ticks(301 + 48 * 3 + 1)
	var b: Array = wd.alive_enemies().map(func(x): return x.offset)
	assert_eq(a, b)

func test_stop_halts_everything() -> void:
	watch_signals(EventBus)
	wd.start_night(GameState.lane_plan)
	wd.stop()
	await _ticks(400)
	assert_signal_not_emitted(EventBus, "wave_started")
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`main.world.wave_director` is null / not declared).

- [ ] **Step 3: Implement**

`world/wave_director.gd`:
```gdscript
class_name WaveDirector
extends Node
## Runs the 3 waves of a night from _plan (spec 7.1). Never changes the phase.

enum State { IDLE, WAITING, ACTIVE }

var enemy_pool: NodePool
var steak_pool: NodePool
var providers := TargetProviders.new()
var wave_index := -1
var state := State.IDLE
var _pending_wave := 0
var _timer := 0.0
var _t := 0.0
var _schedule: Array = []
var _next := 0
var _alive: Array = []
var _spawn_counter := 0
var _spawned_out_sent := false
var _spawn_rng: RandomNumberGenerator
var _drop_rng: RandomNumberGenerator
var _plan: Array = []

func setup(p_enemy_pool: NodePool, p_steak_pool: NodePool) -> void:
	enemy_pool = p_enemy_pool
	steak_pool = p_steak_pool
	providers.register(&"fence_on_lane", func(e): return TargetProviders.fence_on_lane(e))
	providers.register(&"diner", func(e): return TargetProviders.diner(e))

## D-128 interface.
func start_night(plan: Array) -> void:
	stop()
	_plan = plan
	_spawn_counter = 0
	_spawn_rng = Rng.stream(GameState.run_seed, GameState.day, &"spawns")
	_drop_rng = Rng.stream(GameState.run_seed, GameState.day, &"drops")
	wave_index = -1
	_begin_wait(Balance.data.wave.first_wave_delay, 0)

## D-128 interface.
func stop() -> void:
	state = State.IDLE
	_alive.clear()
	_schedule = []
	_next = 0

func _begin_wait(seconds: float, w: int) -> void:
	state = State.WAITING
	_timer = seconds
	_pending_wave = w
	var plan: Dictionary = _plan[w]
	EventBus.wave_incoming.emit(w, StringName(plan.main), StringName(plan.side))

func _physics_process(delta: float) -> void:
	match state:
		State.WAITING:
			_timer -= delta
			if _timer <= 1e-6:
				_start_wave(_pending_wave)
		State.ACTIVE:
			_t += delta
			_spawn_due()
			if WaveSchedule.is_cleared(_schedule.size(), _next, _alive.size()):
				var cleared := wave_index
				state = State.IDLE
				EventBus.wave_cleared.emit(cleared)
				if state == State.IDLE and cleared < _plan.size() - 1:
					_begin_wait(Balance.data.wave.breather, cleared + 1)

func _start_wave(w: int) -> void:
	wave_index = w
	var plan: Dictionary = _plan[w]
	_schedule = WaveSchedule.build(plan, Balance.data.wave)
	_next = 0
	_t = 0.0
	_spawned_out_sent = false
	state = State.ACTIVE
	EventBus.wave_started.emit(w, StringName(plan.main), StringName(plan.side))
	_spawn_due()

func _spawn_due() -> void:
	while _next < _schedule.size() and float(_schedule[_next].t) <= _t + 1e-6:
		_spawn(String(_schedule[_next].lane), _spawn_rng.randf_range(-1.0, 1.0))
		_next += 1
	if _next >= _schedule.size() and not _spawned_out_sent:
		_spawned_out_sent = true
		EventBus.wave_spawned_out.emit(wave_index)

func _spawn(lane: String, unit_offset: float, hp_mult: float = -1.0) -> Boar:
	var boar: Boar = enemy_pool.acquire()
	var mult := hp_mult if hp_mult > 0.0 else float(_plan[maxi(wave_index, 0)].hp_mult)
	boar.spawn(lane, _spawn_counter, unit_offset * Balance.data.enemy.lateral_spread, mult, self)
	_spawn_counter += 1
	_alive.append(boar)
	return boar

func on_enemy_died(boar: Boar) -> void:
	_alive.erase(boar)
	EventBus.enemy_killed.emit(boar.spawn_index, StringName(boar.lane), boar.global_position)
	for i in Balance.data.economy.steaks_per_kill:
		var s: Steak = steak_pool.acquire()
		var a := _drop_rng.randf() * TAU
		var r := _drop_rng.randf() * Balance.data.enemy.drop_scatter
		s.place(boar.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r))
	boar.play_death(enemy_pool)

func alive_enemies() -> Array:
	return _alive.duplicate()

func alive_count() -> int:
	return _alive.size()

func enemy_candidates() -> Array:
	var out: Array = []
	for b in _alive:
		out.append(b.candidate())
	return out

func upcoming_main_lane() -> String:
	var w := _pending_wave if state == State.WAITING else wave_index
	if w < 0 or w >= _plan.size():
		return "north"
	return String(_plan[w].main)

## Test/debug helpers (used by tests and ui/debug only).
func debug_spawn(lane: String, unit_offset: float = 0.0, hp_mult: float = 1.0) -> Boar:
	if _drop_rng == null:
		_drop_rng = Rng.stream(GameState.run_seed, GameState.day, &"drops")
	return _spawn(lane, unit_offset, hp_mult)

func debug_kill_all() -> void:
	for b in _alive.duplicate():
		b.take_hit(1e9)
```

Modify `world/world.gd`:
```gdscript
@export var wave_director: WaveDirector

# in _ready(), after _setup_pools():
	wave_director.setup(enemy_pool, steak_pool)
```

Add the WaveDirector node after the pools, so pooled Boars process before the director in each tick

`world/main.tscn` (full content at this stage):
```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://world/main.gd" id="1_main"]
[ext_resource type="Script" path="res://world/world.gd" id="2_world"]
[ext_resource type="Script" path="res://components/node_pool.gd" id="3_pool"]
[ext_resource type="Script" path="res://world/wave_director.gd" id="4_wave"]

[node name="Main" type="Node3D" node_paths=PackedStringArray("world")]
script = ExtResource("1_main")
world = NodePath("World")

[node name="World" type="Node3D" parent="." node_paths=PackedStringArray("enemy_pool", "steak_pool", "wave_director")]
script = ExtResource("2_world")
enemy_pool = NodePath("EnemyPool")
steak_pool = NodePath("SteakPool")
wave_director = NodePath("WaveDirector")

[node name="EnemyPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="SteakPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="WaveDirector" type="Node" parent="World"]
script = ExtResource("4_wave")
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add world/wave_director.gd world/world.gd tests/unit/test_wave_director.gd
git commit -m "feat: add WaveDirector with schedule, clear rule, breather and drops"
```

### Task 15: `Hero`, `HeroInput`, `Magnet`, `CarryStack`

**Files:**
- Create: `actors/hero/hero.gd`, `actors/hero/hero_input.gd`, `components/magnet.gd`, `components/carry_stack.gd`
- Modify: `world/main.gd`
- Test: `tests/unit/test_hero.gd`

**Interfaces:**
- Produces:
  - **`Hero`** (CharacterBody3D, group `&"hero"`):
    - `input: HeroInput`, `magnet: Magnet`, `carry_stack: CarryStack`, `still_time: float`, `teleport_serial: int`
    - `setup(world: World)`
    - `is_moving() -> bool`, `xz() -> Vector2`, `teleport(p: Vector2)`
  - **`HeroInput`:**
    - `player_control: bool` (bots set false)
    - `set_move(v: Vector2)`, where x = east and y = south, length ≤ 1
    - `get_move() -> Vector2`
    - static `ensure_actions()`, which registers `move_left/right/up/down` on WASD and the arrow keys
  - **`Magnet`:** `setup(steak_pool: NodePool)`.
  - **`CarryStack`:** `refresh()`.
  - **`Main`:** `hero: Hero`, placed at `MapLayout.HOME`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_hero.gd`:
```gdscript
extends GutTest

var main: Main
var hero: Hero

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(1)
	hero = main.hero
	hero.input.player_control = false

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_moves_at_speed() -> void:
	hero.teleport(Vector2(10, 8))
	hero.input.set_move(Vector2(1, 0))
	await _ticks(60)
	assert_almost_eq(hero.xz().x, 10.0 + Balance.data.hero.move_speed, 0.2)

func test_blocked_by_diner() -> void:
	hero.teleport(Vector2(-3, 7))
	hero.input.set_move(Vector2(0, -1))
	await _ticks(90)
	assert_true(hero.xz().y >= MapLayout.DINER_HALF + MapLayout.HERO_RADIUS - 0.05, "z=%f" % hero.xz().y)

func test_still_time_counts() -> void:
	hero.teleport(Vector2(10, 8))
	hero.input.set_move(Vector2.ZERO)
	await _ticks(30)
	assert_almost_eq(hero.still_time, 0.5, 0.05)
	hero.input.set_move(Vector2(1, 0))
	await _ticks(2)
	assert_eq(hero.still_time, 0.0)
	assert_true(hero.is_moving())

func test_magnet_picks_steaks_up_to_capacity() -> void:
	hero.teleport(Vector2(10, 8))
	for i in 7:
		var s: Steak = main.world.steak_pool.acquire()
		s.place(Vector3(10.5, 0, 8))
	await _ticks(2)
	assert_eq(GameState.carried_steaks, 6)
	assert_eq(main.world.steak_pool.active().size(), 1)
	assert_eq(hero.carry_stack.visible_count(), 6)

func test_magnet_collects_gold_pile() -> void:
	GameState.gold_pile = 9  # test-only setup write
	hero.teleport(MapLayout.GOLD_PILE + Vector2(-1.0, 0))
	await _ticks(2)
	assert_eq(GameState.gold, 9)
	assert_eq(GameState.gold_pile, 0)

func test_starts_at_home() -> void:
	var m := Main.create()
	add_child_autofree(m)
	assert_eq(m.hero.xz(), MapLayout.HOME)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`main.hero` is null).

- [ ] **Step 3: Implement**

`actors/hero/hero_input.gd`:
```gdscript
class_name HeroInput
extends Node
## The hero's only movement API (D-034). Joystick, WASD and bots all go through it.

var player_control := true
var _move := Vector2.ZERO

static func ensure_actions() -> void:
	var map := {
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

func _ready() -> void:
	HeroInput.ensure_actions()

func set_move(v: Vector2) -> void:
	_move = v.limit_length(1.0)

func get_move() -> Vector2:
	if player_control:
		var k := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if k != Vector2.ZERO:
			return k
	return _move
```

`components/magnet.gd`:
```gdscript
class_name Magnet
extends Node
## Walk-over pickup by distance check each tick (D-008, D-034). Parent must be the Hero.

var _steaks: NodePool

func setup(steak_pool: NodePool) -> void:
	_steaks = steak_pool

func _physics_process(_delta: float) -> void:
	var owner3d := get_parent() as Node3D
	var p := Vector2(owner3d.global_position.x, owner3d.global_position.z)
	var r := Balance.data.hero.magnet_radius
	if _steaks != null:
		for s in _steaks.active().duplicate():
			if p.distance_to(Vector2(s.position.x, s.position.z)) <= r:
				if not GameState.pick_steak():
					break
				_steaks.release(s)
	if GameState.gold_pile > 0 and p.distance_to(MapLayout.GOLD_PILE) <= r:
		GameState.collect_pile()
```

`components/carry_stack.gd`:
```gdscript
class_name CarryStack
extends Node3D
## Visual steak stack on the hero's back, driven by GameState.carried_steaks (D-009).

var _boxes: Array = []

func _ready() -> void:
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func refresh() -> void:
	var n := GameState.carried_steaks
	while _boxes.size() < n:
		var m := Visuals.box(Vector3(0.35, 0.16, 0.25), Visuals.COLORS.steak)
		m.position = Vector3(0, 1.0 + _boxes.size() * 0.2, 0.5)
		add_child(m)
		_boxes.append(m)
	for i in _boxes.size():
		_boxes[i].visible = i < n

func visible_count() -> int:
	return _boxes.filter(func(b): return b.visible).size()
```

`actors/hero/hero.gd`:
```gdscript
class_name Hero
extends CharacterBody3D
## The player's cook (spec 7.3). Moves only through HeroInput.

var input: HeroInput
var magnet: Magnet
var carry_stack: CarryStack
var still_time := 0.0
## Incremented by teleport(); StationZone disarms when it changes (D-121).
var teleport_serial := 0

func _init() -> void:
	name = "Hero"
	add_to_group(&"hero")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = MapLayout.HERO_RADIUS
	cap.height = 1.6
	shape.shape = cap
	shape.position.y = 0.8
	add_child(shape)
	var v := Visuals.visual_root()
	var body := Visuals.capsule(MapLayout.HERO_RADIUS, 1.6, Visuals.COLORS.hero)
	body.position.y = 0.8
	v.add_child(body)
	var hat := Visuals.box(Vector3(0.5, 0.3, 0.5), Visuals.COLORS.hat)
	hat.position.y = 1.75
	v.add_child(hat)
	add_child(v)
	input = HeroInput.new()
	add_child(input)
	magnet = Magnet.new()
	add_child(magnet)
	carry_stack = CarryStack.new()
	add_child(carry_stack)

func setup(world: World) -> void:
	magnet.setup(world.steak_pool)

func _physics_process(delta: float) -> void:
	var mv := input.get_move()
	velocity = Vector3(mv.x, 0.0, mv.y) * Balance.data.hero.move_speed
	move_and_slide()
	position.y = 0.0
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < Balance.data.economy.stand_still_speed:
		still_time += delta
	else:
		still_time = 0.0

func is_moving() -> bool:
	return still_time <= 0.0

func xz() -> Vector2:
	return Vector2(global_position.x, global_position.z)

func teleport(p: Vector2) -> void:
	global_position = MapLayout.to3(p)
	velocity = Vector3.ZERO
	still_time = 0.0
	teleport_serial += 1
	input.set_move(Vector2.ZERO)
```

Modify `world/main.gd` (its first `_ready`):
```gdscript
var hero: Hero

func _ready() -> void:
	hero = Hero.new()
	add_child(hero)
	hero.setup(world)
	hero.teleport(MapLayout.HOME)
```

Add to `actors/hero/hero.gd`, so PhaseController places the hero through the bus instead of a node reference (D-128):
```gdscript
func _ready() -> void:
	EventBus.hero_place_requested.connect(teleport)
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add actors/hero components/magnet.gd components/carry_stack.gd world/main.gd tests/unit/test_hero.gd
git commit -m "feat: add hero body, input API, magnet pickup and carry stack"
```

### Task 16: `Attacker` and `Projectile` (hero combat)

**Files:**
- Create: `components/attacker.gd`, `actors/projectile/projectile.gd`
- Modify: `actors/hero/hero.gd`, `world/world.gd`, `world/main.tscn`
- Test: `tests/unit/test_attacker.gd`, `tests/unit/test_hero_combat.gd`

**Interfaces:**
- Produces:
  - **`Attacker`** (Node3D):
    - `configure(damage: float, attack_range: float, interval: float, retarget_interval: float, moving_mult: float, projectile_speed: float)`
    - `candidates: Callable` (returns an Array of candidate dictionaries)
    - `projectile_pool: NodePool`
    - `is_moving: Callable` (returns bool)
    - `enabled: bool`
    - `signal fired(target: Object)`
  - **`Projectile`:** `launch(from: Vector3, target: Object, target_index: int, damage: float, speed: float, pool: NodePool)`. The target object must have `alive: bool`, `spawn_index: int`, `global_position: Vector3` and `take_hit(amount: float)`.
  - **`World`:** `projectile_pool: NodePool`.
  - **`Hero`:** `attacker: Attacker`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_attacker.gd`:
```gdscript
extends GutTest

class FakeTarget:
	extends Node3D
	var alive := true
	var spawn_index := 1
	var hits := 0.0
	func take_hit(a: float) -> void:
		hits += a

var pool: NodePool
var target: FakeTarget

func before_each() -> void:
	Balance.reset()
	pool = NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Projectile.new(), 8)
	target = FakeTarget.new()
	add_child_autofree(target)
	target.position = Vector3(2, 0, 0)

func _attacker(moving: bool) -> Attacker:
	var a := Attacker.new()
	a.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(a)
	a.configure(10.0, 4.0, 0.5, 0.2, 0.5, 14.0)
	a.candidates = func(): return [{"position": target.global_position, "spawn_index": 1, "ref": target}]
	a.projectile_pool = pool
	a.is_moving = func(): return moving
	return a

func _count_shots(a: Attacker, ticks: int) -> int:
	var shots := [0]
	a.fired.connect(func(_t): shots[0] += 1)
	for i in ticks:
		a._physics_process(1.0 / 60.0)
	return shots[0]

func test_fires_immediately_then_on_interval() -> void:
	assert_eq(_count_shots(_attacker(false), 120), 4)  # t=0, .5, 1.0, 1.5

func test_moving_mult_slows_rate() -> void:
	assert_eq(_count_shots(_attacker(true), 120), 2)  # interval effectively 1.0 s

func test_no_target_out_of_range() -> void:
	target.position = Vector3(9, 0, 0)
	assert_eq(_count_shots(_attacker(false), 60), 0)

func test_dead_target_not_shot() -> void:
	target.alive = false
	assert_eq(_count_shots(_attacker(false), 60), 0)
```

`tests/unit/test_hero_combat.gd`:
```gdscript
extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(3)
	main.hero.input.player_control = false

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_hero_kills_boar_in_range() -> void:
	var wd := main.world.wave_director
	var b := wd.debug_spawn("north")
	main.hero.teleport(Vector2(0, -21))
	watch_signals(EventBus)
	await _ticks(120)
	assert_false(b.alive)
	assert_signal_emitted(EventBus, "enemy_killed")
	# the hero's magnet may already hold some of the 2 drops
	assert_eq(GameState.carried_steaks + main.world.steak_pool.active().size(), 2)

func test_projectile_never_hits_recycled_boar() -> void:
	# Review Focus 2
	var wd := main.world.wave_director
	var b1 := wd.debug_spawn("north", 0.0, 100.0)
	b1.dist = 0.0
	var proj: Projectile = main.world.projectile_pool.acquire()
	proj.launch(Vector3(0, 1, 30), b1, b1.spawn_index, 10.0, 1.0, main.world.projectile_pool)  # slow and far
	b1.take_hit(1e9)
	await _ticks(20)  # death tween (0.15 s) releases b1
	var b2 := wd.debug_spawn("north", 0.0, 1.0)
	assert_same(b2, b1, "pool reused the same node")
	var hp_before := b2.health.hp
	await _ticks(5)
	assert_eq(b2.health.hp, hp_before)
	assert_false(main.world.projectile_pool.active().has(proj))
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`Attacker` not declared).

- [ ] **Step 3: Implement**

`actors/projectile/projectile.gd`:
```gdscript
class_name Projectile
extends Node3D
## Homing cleaver/bolt (D-050, D-060). Damage on hit only; despawns if its target died or was recycled.

var _target: Object
var _target_index := -1
var _damage := 0.0
var _speed := 0.0
var _pool: NodePool

func _init() -> void:
	name = "Projectile"
	var v := Visuals.visual_root()
	v.add_child(Visuals.box(Vector3(0.25, 0.08, 0.35), Visuals.COLORS.hat))
	add_child(v)

func launch(from: Vector3, target: Object, target_index: int, damage: float, speed: float, pool: NodePool) -> void:
	position = from
	_target = target
	_target_index = target_index
	_damage = damage
	_speed = speed
	_pool = pool

func _physics_process(delta: float) -> void:
	if _pool == null:
		return
	if not is_instance_valid(_target) or not _target.alive or _target.spawn_index != _target_index:
		_finish()
		return
	var aim: Vector3 = _target.global_position + Vector3(0, 0.5, 0)
	var to := aim - position
	var step := _speed * delta
	if to.length() <= step:
		_target.take_hit(_damage)
		_finish()
	else:
		position += to.normalized() * step

func on_release() -> void:
	_pool = null
	_target = null

func _finish() -> void:
	var p := _pool
	if p != null:
		p.release(self)
```

`components/attacker.gd`:
```gdscript
class_name Attacker
extends Node3D
## Auto-attack: retargets on an interval, fires homing projectiles (D-019, D-020, D-060).

signal fired(target: Object)

var damage := 0.0
var attack_range := 0.0
var interval := 1.0
var retarget_interval := 0.2
var moving_mult := 1.0
var projectile_speed := 14.0
var enabled := true
var candidates: Callable
var projectile_pool: NodePool
var is_moving: Callable = func(): return false
var _cooldown := 0.0
var _retarget := 0.0
var _target: Dictionary = {}

func configure(p_damage: float, p_range: float, p_interval: float, p_retarget: float, p_moving_mult: float, p_speed: float) -> void:
	damage = p_damage
	attack_range = p_range
	interval = p_interval
	retarget_interval = p_retarget
	moving_mult = p_moving_mult
	projectile_speed = p_speed

func _physics_process(delta: float) -> void:
	if not enabled or not candidates.is_valid() or projectile_pool == null:
		return
	var origin := global_position
	_retarget -= delta
	if _retarget <= 0.0 or not _target_valid(origin):
		_retarget = retarget_interval
		_target = Targeting.select(origin, attack_range, candidates.call())
	var rate := moving_mult if is_moving.call() else 1.0
	_cooldown = maxf(_cooldown - delta * rate, 0.0)
	if _cooldown <= 1e-6 and _target_valid(origin):
		_cooldown = interval
		var ref: Object = _target.ref
		var p: Projectile = projectile_pool.acquire()
		p.launch(origin + Vector3(0, 1.0, 0), ref, int(_target.spawn_index), damage, projectile_speed, projectile_pool)
		fired.emit(ref)

func _target_valid(origin: Vector3) -> bool:
	if _target.is_empty():
		return false
	var r: Object = _target.ref
	if not is_instance_valid(r) or not r.alive or r.spawn_index != int(_target.spawn_index):
		return false
	var pos: Vector3 = r.global_position
	return Vector2(pos.x - origin.x, pos.z - origin.z).length() <= attack_range
```

Modify `world/world.gd`:
```gdscript
@export var projectile_pool: NodePool

# in _setup_pools(), after steak_pool:
	projectile_pool.setup(func(): return Projectile.new(), sizes.projectile)
```

Add the ProjectilePool node

`world/main.tscn` (full content at this stage):
```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://world/main.gd" id="1_main"]
[ext_resource type="Script" path="res://world/world.gd" id="2_world"]
[ext_resource type="Script" path="res://components/node_pool.gd" id="3_pool"]
[ext_resource type="Script" path="res://world/wave_director.gd" id="4_wave"]

[node name="Main" type="Node3D" node_paths=PackedStringArray("world")]
script = ExtResource("1_main")
world = NodePath("World")

[node name="World" type="Node3D" parent="." node_paths=PackedStringArray("enemy_pool", "steak_pool", "projectile_pool", "wave_director")]
script = ExtResource("2_world")
enemy_pool = NodePath("EnemyPool")
steak_pool = NodePath("SteakPool")
projectile_pool = NodePath("ProjectilePool")
wave_director = NodePath("WaveDirector")

[node name="EnemyPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="SteakPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="ProjectilePool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="WaveDirector" type="Node" parent="World"]
script = ExtResource("4_wave")
```

Modify `actors/hero/hero.gd`:
```gdscript
var attacker: Attacker

# in _init(), after carry_stack:
	attacker = Attacker.new()
	add_child(attacker)

# replace setup():
func setup(world: World) -> void:
	magnet.setup(world.steak_pool)
	var hb := Balance.data.hero
	attacker.configure(hb.attack_damage, hb.attack_range, hb.attack_interval, hb.retarget_interval,
		hb.moving_attack_speed_mult, hb.projectile_speed)
	attacker.candidates = world.wave_director.enemy_candidates
	attacker.projectile_pool = world.projectile_pool
	attacker.is_moving = is_moving
```

The tests call `a._physics_process` directly with the node disabled, so the engine doesn't step it too.

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add components/attacker.gd actors/projectile actors/hero/hero.gd world/world.gd tests/unit/test_attacker.gd tests/unit/test_hero_combat.gd
git commit -m "feat: add auto-attacker and homing projectiles for hero combat"
```

### Task 17: `PhaseController` (new game, night, fail, dawn, close-up)

**Files:**
- Create: `world/phase_controller.gd`
- Modify: `world/main.gd`, `world/main.tscn`
- Test: `tests/unit/test_phase_controller.gd`

**Interfaces:**
- Consumes, ONLY through the D-128 narrow interface and typed `@export` references assigned in `main.tscn` (no `get_node` paths, no groups): `WaveDirector.start_night(plan)` and `stop()`, `NodePool.recall_all()`. Task 22 adds `TravelerSpawner.start()`, `stop()` and `clear_queue()`. It places the hero with `EventBus.hero_place_requested`. It also uses `GameState.*`.
- Produces:
  - **`PhaseController`:**
    - `phase: int`, `dawn_substate: String`, `snapshot: Dictionary`, `failing: bool`
    - exports: `wave_director`, `enemy_pool`, `steak_pool`, `projectile_pool` (Task 22 adds `traveler_spawner`, Task 30 adds `fx_pool`)
    - `start_new_game(seed: int = 0)`, `close_up()`
    - `debug_skip_to_day()`, `debug_skip_to_night()`
  - It listens to `wave_cleared`, `diner_fell` and `closeup_requested`.
  - **`Main`:** `@export phase_controller: PhaseController` (assigned in `main.tscn`). With `auto_start`, it calls `start_new_game()` deferred.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_phase_controller.gd`:
```gdscript
extends GutTest

var main: Main
var pc: PhaseController

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	pc = main.phase_controller
	main.hero.input.player_control = false
	pc.start_new_game(99)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_phase_controller_uses_only_the_narrow_interface() -> void:
	# D-128: typed @export references only; no node paths, groups or tree searches.
	var src := FileAccess.get_file_as_string("res://world/phase_controller.gd")
	for banned in ["get_node", "$", "get_nodes_in_group", "find_children", "find_child", "get_parent", "owner."]:
		assert_false(src.contains(banned), "phase_controller.gd uses %s" % banned)
	for prop in ["wave_director", "enemy_pool", "steak_pool", "projectile_pool"]:
		assert_not_null(pc.get(prop), "%s not wired in main.tscn" % prop)

func test_new_game_starts_night_with_night_snapshot() -> void:
	assert_eq(pc.phase, Phase.NIGHT)
	assert_eq(pc.snapshot.resume_phase, "NIGHT")
	assert_eq(main.hero.xz(), MapLayout.NIGHT1_START)
	assert_eq(main.world.wave_director.state, WaveDirector.State.WAITING)

func test_dawn_steps_in_order() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	GameState.damage_fence("fence_w", 1e6)
	GameState.damage_diner(50.0)
	GameState.carried_steaks = 2  # test-only setup write
	for i in 3:
		main.world.steak_pool.acquire().place(Vector3(20, 0, 0))
	watch_signals(EventBus)
	EventBus.wave_cleared.emit(2)
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.freezer_steaks, 3)
	assert_eq(GameState.carried_steaks, 2)
	assert_eq(GameState.diner_hp, Balance.data.build.diner_max_hp)
	assert_eq(GameState.buildings.fence_w, {"level": 0, "paid": 0, "hp": 0.0})
	assert_eq(GameState.day, 2)
	assert_ne(GameState.lane_plan[0].side, "")
	assert_eq(main.world.steak_pool.active().size(), 0)
	assert_eq(get_signal_parameters(EventBus, "phase_changed", 0), [Phase.DAWN, 1])
	assert_eq(get_signal_parameters(EventBus, "phase_changed", 1), [Phase.DAY, 2])
	assert_eq(pc.dawn_substate, "")

func test_early_wave_clear_is_not_dawn() -> void:
	EventBus.wave_cleared.emit(0)
	assert_eq(pc.phase, Phase.NIGHT)

func test_close_up_collects_and_snapshots_day() -> void:
	EventBus.wave_cleared.emit(2)
	GameState.gold_pile = 12  # test-only setup write
	main.world.steak_pool.acquire().place(Vector3(20, 0, 0))
	pc.close_up()
	assert_eq(GameState.gold, 12)
	assert_eq(GameState.freezer_steaks, 1)
	assert_eq(pc.snapshot.resume_phase, "DAY")
	assert_eq(pc.snapshot.gold, 12)
	assert_eq(pc.phase, Phase.NIGHT)

func test_close_up_ignored_at_night() -> void:
	pc.close_up()
	assert_eq(pc.snapshot.resume_phase, "NIGHT")

func test_fail_night1_restarts_night() -> void:
	var snap := pc.snapshot.duplicate(true)
	GameState.add_gold(5)
	watch_signals(EventBus)
	GameState.damage_diner(1000.0)
	assert_signal_emitted_with_parameters(EventBus, "night_failed", [1])
	assert_true(pc.failing)
	await _ticks(125)
	assert_false(pc.failing)
	assert_eq(pc.phase, Phase.NIGHT)
	var now := GameState.to_dict()
	now.resume_phase = snap.resume_phase
	assert_eq(now, snap)
	assert_eq(main.hero.xz(), MapLayout.NIGHT1_START)

func test_fail_after_close_up_returns_to_day() -> void:
	EventBus.wave_cleared.emit(2)
	GameState.add_gold(30)
	pc.close_up()
	GameState.damage_diner(1000.0)
	await _ticks(125)
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.gold, 30)
	assert_eq(GameState.day, 2)
	assert_eq(main.hero.xz(), MapLayout.HOME)

func test_fall_and_clear_same_tick_fail_wins() -> void:
	# Review Focus 3
	GameState.damage_diner(1000.0)
	EventBus.wave_cleared.emit(2)
	assert_ne(pc.phase, Phase.DAWN)
	await _ticks(125)
	assert_eq(pc.phase, Phase.NIGHT)
	assert_eq(GameState.day, 1)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`main.phase_controller` is null).

- [ ] **Step 3: Implement**

`world/phase_controller.gd`:
```gdscript
class_name PhaseController
extends Node
## Owns the phase, the snapshot and the dawn / close-up / fail steps (spec 5, D-043).
## The single architecture exception (D-110, D-128): it calls other systems directly, but ONLY through
## this narrow interface, via typed @export references assigned in world/main.tscn (never node-path
## lookups, never groups; test_phase_controller greps this file for them):
##   WaveDirector.start_night(plan), WaveDirector.stop()
##   NodePool.recall_all() -> int
##   TravelerSpawner.start(), stop(), clear_queue()      (added in Task 22)
## The hero is placed with the bus event EventBus.hero_place_requested(position).

@export var wave_director: WaveDirector
@export var enemy_pool: NodePool
@export var steak_pool: NodePool
@export var projectile_pool: NodePool

var phase := Phase.NIGHT
var dawn_substate := ""
var snapshot: Dictionary = {}
var failing := false

func _ready() -> void:
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.diner_fell.connect(_on_diner_fell)
	EventBus.closeup_requested.connect(close_up)

func start_new_game(seed: int = 0) -> void:
	failing = false
	_recall_all()
	GameState.new_game(seed)
	snapshot = GameState.to_dict()
	snapshot.resume_phase = "NIGHT"
	EventBus.hero_place_requested.emit(MapLayout.NIGHT1_START)  # D-126: combat comes to a new player
	EventBus.banner_requested.emit(tr("The monsters return"))
	_enter_night()

func close_up() -> void:
	if phase != Phase.DAY or failing:
		return
	GameState.collect_pile()
	_steaks_to_freezer()
	snapshot = GameState.to_dict()
	snapshot.resume_phase = "DAY"
	_enter_night()

func _enter_night() -> void:
	phase = Phase.NIGHT
	EventBus.phase_changed.emit(phase, GameState.day)
	wave_director.start_night(GameState.lane_plan)

func _enter_day() -> void:
	phase = Phase.DAY
	EventBus.phase_changed.emit(phase, GameState.day)

func _on_wave_cleared(w: int) -> void:
	if phase != Phase.NIGHT or failing:
		return
	if w < GameState.lane_plan.size() - 1:
		return
	_run_dawn()

func _run_dawn() -> void:
	wave_director.stop()
	phase = Phase.DAWN
	EventBus.phase_changed.emit(phase, GameState.day)
	EventBus.banner_requested.emit(tr("Dawn"))
	_steaks_to_freezer()                 # 1
	_recall_all()                        # projectiles (and later fx) in flight
	GameState.heal_for_dawn()            # 2
	GameState.reset_destroyed_fences()   # 3
	GameState.advance_day()              # 4
	dawn_substate = "CARD_PICK"          # 5
	_card_pick()

func _card_pick() -> void:
	# S1 stub (spec 5.4 step 5). S2 presents the 3 hero cards here and continues on pick.
	dawn_substate = ""
	_enter_day()

func _on_diner_fell() -> void:
	if phase != Phase.NIGHT or failing:
		return
	failing = true
	wave_director.stop()
	EventBus.night_failed.emit(GameState.day)
	EventBus.banner_requested.emit(tr("The diner fell"))
	await get_tree().create_timer(Balance.ui.banner_time, false, true).timeout
	_restore_snapshot()

func _restore_snapshot() -> void:
	_recall_all()
	GameState.from_dict(snapshot)
	var night_restart := String(snapshot.resume_phase) == "NIGHT"
	EventBus.hero_place_requested.emit(MapLayout.NIGHT1_START if night_restart else MapLayout.HOME)  # D-122, D-126
	failing = false
	if night_restart:
		EventBus.banner_requested.emit(tr("The monsters return"))  # spec 5.2: each night-1 restart
		_enter_night()
	else:
		_enter_day()

func _steaks_to_freezer() -> void:
	GameState.add_freezer(steak_pool.recall_all())

func _recall_all() -> void:
	enemy_pool.recall_all()
	steak_pool.recall_all()
	projectile_pool.recall_all()

## Debug helpers (ui/debug hotkeys, tests). Same narrow interface.
func debug_skip_to_day() -> void:
	if phase == Phase.NIGHT and not failing:
		wave_director.stop()
		enemy_pool.recall_all()
		_run_dawn()

func debug_skip_to_night() -> void:
	if phase == Phase.DAY:
		close_up()
```

Modify `world/main.gd`:
```gdscript
@export var phase_controller: PhaseController

# at the end of _ready():
	if auto_start:
		phase_controller.start_new_game.call_deferred()
```

Add the PhaseController node with its typed references

`world/main.tscn` (full content at this stage):
```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://world/main.gd" id="1_main"]
[ext_resource type="Script" path="res://world/world.gd" id="2_world"]
[ext_resource type="Script" path="res://components/node_pool.gd" id="3_pool"]
[ext_resource type="Script" path="res://world/wave_director.gd" id="4_wave"]
[ext_resource type="Script" path="res://world/phase_controller.gd" id="5_phase"]

[node name="Main" type="Node3D" node_paths=PackedStringArray("world", "phase_controller")]
script = ExtResource("1_main")
world = NodePath("World")
phase_controller = NodePath("PhaseController")

[node name="World" type="Node3D" parent="." node_paths=PackedStringArray("enemy_pool", "steak_pool", "projectile_pool", "wave_director")]
script = ExtResource("2_world")
enemy_pool = NodePath("EnemyPool")
steak_pool = NodePath("SteakPool")
projectile_pool = NodePath("ProjectilePool")
wave_director = NodePath("WaveDirector")

[node name="EnemyPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="SteakPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="ProjectilePool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="WaveDirector" type="Node" parent="World"]
script = ExtResource("4_wave")

[node name="PhaseController" type="Node" parent="." node_paths=PackedStringArray("wave_director", "enemy_pool", "steak_pool", "projectile_pool")]
script = ExtResource("5_phase")
wave_director = NodePath("../World/WaveDirector")
enemy_pool = NodePath("../World/EnemyPool")
steak_pool = NodePath("../World/SteakPool")
projectile_pool = NodePath("../World/ProjectilePool")
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add world/phase_controller.gd world/main.gd tests/unit/test_phase_controller.gd
git commit -m "feat: add PhaseController with snapshot, fail restore, dawn and close-up"
```

### Task 18: Build spots (tower combat, fence rubble, visuals)

**Files:**
- Create: `world/build_spots/build_spot.gd`, `world/build_spots/tower_spot.gd`, `world/build_spots/fence_spot.gd`
- Modify: `world/world.gd`
- Test: `tests/unit/test_build_spots.gd`

**Interfaces:**
- Consumes: `GameState.buildings`, `building_changed`, `state_restored`, `Attacker`, `WaveDirector.enemy_candidates`, `World.projectile_pool`, `WorldLabel`.
- Produces:
  - **`BuildSpot`** (Node3D base):
    - `spot_id: String`, `level: int`, `label: WorldLabel`, `visual: Node3D`
    - `setup(id: String, world: World)`
    - `refresh()`, which rebuilds entirely from GameState
    - virtual `_apply_level(level: int, b: Dictionary)`
  - **`TowerSpot`:** `attacker: Attacker`. There is no physics body: the hero walks through towers (D-125).
  - **`FenceSpot`:** `is_rubble() -> bool`.
  - **`World`:** `build_spots: Dictionary` (spot_id → BuildSpot).
  - The Task 23 paying is added onto `BuildSpot` later.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_build_spots.gd`:
```gdscript
extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(5)
	main.hero.input.player_control = false
	main.hero.teleport(Vector2(20, 10))  # out of the way

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_five_spots_at_layout_positions() -> void:
	assert_eq(main.world.build_spots.size(), 5)
	for id in MapLayout.SPOT_IDS:
		var s: BuildSpot = main.world.build_spots[id]
		assert_eq(Vector2(s.position.x, s.position.z), MapLayout.spot_position(id))

func test_tower_inactive_until_built() -> void:
	var t: TowerSpot = main.world.build_spots.tower_nw
	assert_false(t.attacker.enabled)
	assert_eq(t.find_children("*", "CollisionObject3D", true, false).size(), 0, "towers never collide (D-125)")
	GameState.add_gold(GameState.next_level_cost("tower_nw"))
	GameState.pay_into_spot("tower_nw", GameState.next_level_cost("tower_nw"))
	assert_true(t.attacker.enabled)
	assert_eq(t.attacker.attack_range, Balance.data.build.tower_range[0])

func test_built_tower_kills_boar() -> void:
	GameState.add_gold(GameState.next_level_cost("tower_nw"))
	GameState.pay_into_spot("tower_nw", GameState.next_level_cost("tower_nw"))
	var b := main.world.wave_director.debug_spawn("north")
	b.dist = 12.0  # (0,-12): 8.6 m from the tower, walks into its level-1 range
	await _ticks(60 * 5)
	assert_false(b.alive)

func test_upgrade_changes_tower_stats() -> void:
	GameState.add_gold(10000)
	GameState.pay_into_spot("tower_ne", GameState.next_level_cost("tower_ne"))
	GameState.pay_into_spot("tower_ne", GameState.next_level_cost("tower_ne"))
	var t: TowerSpot = main.world.build_spots.tower_ne
	assert_eq(t.attacker.damage, Balance.data.build.tower_damage[1])
	assert_eq(t.attacker.attack_range, Balance.data.build.tower_range[1])

func test_fence_rubble_and_restore() -> void:
	var f: FenceSpot = main.world.build_spots.fence_n
	assert_false(f.visual.visible)
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	assert_true(f.visual.visible)
	assert_false(f.is_rubble())
	GameState.damage_fence("fence_n", 999.0)
	assert_true(f.is_rubble())
	GameState.new_game(5)  # emits state_restored
	assert_false(f.visual.visible)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`build_spots` not found).

- [ ] **Step 3: Implement**

`world/build_spots/build_spot.gd`:
```gdscript
class_name BuildSpot
extends Node3D
## Base for tower and fence spots. All state comes from GameState.buildings[spot_id] (D-036).

var spot_id := ""
var level := 0
var label: WorldLabel
var visual: Node3D
var _world: World
var _pips: Array = []

func setup(id: String, world: World) -> void:
	spot_id = id
	_world = world
	name = "Spot_" + id
	position = MapLayout.to3(MapLayout.spot_position(id))
	visual = Visuals.visual_root()
	add_child(visual)
	_build_visual()
	label = WorldLabel.make("", 40)
	label.position = Vector3(0, 2.6, 0)
	add_child(label)
	for i in Balance.data.build.max_level:
		var pip := Visuals.box(Vector3(0.18, 0.18, 0.18), Visuals.COLORS.pip)
		pip.position = Vector3(-0.3 + i * 0.3, 2.1, 0)
		add_child(pip)
		_pips.append(pip)
	EventBus.building_changed.connect(_on_building_changed)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_building_changed(id: StringName, _level: int, _paid: int) -> void:
	if String(id) == spot_id:
		refresh()

func refresh() -> void:
	var b: Dictionary = GameState.buildings.get(spot_id, {"level": 0, "paid": 0, "hp": 0.0})
	level = int(b.level)
	visual.scale = Vector3.ONE * pow(1.1, maxi(level - 1, 0))
	for i in _pips.size():
		_pips[i].visible = i < level
	var remaining := GameState.remaining_cost(spot_id) if not GameState.buildings.is_empty() else -1
	label.text = tr("MAX") if remaining < 0 else str(remaining)
	_apply_level(level, b)

## Subclasses build their meshes under `visual`.
func _build_visual() -> void:
	pass

## Subclasses react to level/hp.
func _apply_level(_level: int, _b: Dictionary) -> void:
	pass
```

`world/build_spots/tower_spot.gd`:
```gdscript
class_name TowerSpot
extends BuildSpot
## Tower: never targeted, auto-attacks when level >= 1 (spec 7.5).

var attacker: Attacker

func _build_visual() -> void:
	# No physics body: the hero walks through towers (D-125).
	var m := Visuals.cylinder(MapLayout.TOWER_VISUAL_RADIUS, 2.0, Visuals.COLORS.tower)
	m.position.y = 1.0
	visual.add_child(m)
	attacker = Attacker.new()
	attacker.position.y = 1.5
	attacker.candidates = _world.wave_director.enemy_candidates
	attacker.projectile_pool = _world.projectile_pool
	add_child(attacker)

func _apply_level(p_level: int, _b: Dictionary) -> void:
	var built := p_level >= 1
	visual.visible = built
	attacker.enabled = built
	if built:
		var bb := Balance.data.build
		attacker.configure(bb.tower_damage[p_level - 1], bb.tower_range[p_level - 1], bb.tower_interval,
			Balance.data.hero.retarget_interval, 1.0, bb.tower_projectile_speed)
```

`world/build_spots/fence_spot.gd`:
```gdscript
class_name FenceSpot
extends BuildSpot
## Fence bar across its lane (spec 7.6). Rubble at hp <= 0 until dawn resets it.

var _bar: MeshInstance3D
var _rubble := false

func _build_visual() -> void:
	var lane: String = MapLayout.FENCE_LANE[spot_id]
	var path: Array = MapLayout.LANE_PATHS[lane]
	var tan := Geometry.tangent_at(path, MapLayout.path_length(lane) - MapLayout.FENCE_OFFSET_FROM_END)
	_bar = Visuals.box(Vector3(3.0, 0.8, 0.3), Visuals.COLORS.fence)
	_bar.position.y = 0.4
	visual.rotation.y = atan2(tan.x, tan.y)
	visual.add_child(_bar)

func _apply_level(p_level: int, b: Dictionary) -> void:
	visual.visible = p_level >= 1
	_rubble = p_level >= 1 and float(b.hp) <= 0.0
	_bar.scale = Vector3(1.0, 0.15 if _rubble else 1.0, 1.0)
	_bar.position.y = 0.06 if _rubble else 0.4

func is_rubble() -> bool:
	return _rubble
```

Modify `world/world.gd`:
```gdscript
var build_spots := {}

# in _ready(), after wave_director.setup(...):
	_build_spots()

func _build_spots() -> void:
	for id in MapLayout.SPOT_IDS:
		var s: BuildSpot = TowerSpot.new() if MapLayout.spot_kind(id) == "tower" else FenceSpot.new()
		add_child(s)
		s.setup(id, self)
		build_spots[id] = s
```

`BuildSpot.refresh()` calls `GameState.remaining_cost`, which needs `buildings` filled. Before any `new_game`, `buildings` is empty. The `is_empty()` guard handles that, because `World` can be built before the first `new_game`.

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add world/build_spots world/world.gd tests/unit/test_build_spots.gd
git commit -m "feat: add tower and fence build spots with level-driven stats and rubble"
```

---
## Phase 5: Sim bots and night sims

### Task 19: `BotBase`, `ParkedBot`, `NaiveBot`, `SimHarness`

**Files:**
- Create: `actors/bots/bot_base.gd`, `actors/bots/parked_bot.gd`, `actors/bots/naive_bot.gd`, `tests/sim/sim_harness.gd`
- Test: `tests/unit/test_bots.gd`

**Interfaces:**
- Consumes: `WaypointGraph.create_default/route_from/position_of`, `HeroInput.set_move`, `WaveDirector.alive_enemies/enemy_candidates/upcoming_main_lane`, `PhaseController.phase/failing`.
- Produces:
  - **`BotBase`** (Node):
    - `main: Main`, `hero: Hero`, `graph: WaypointGraph`, `goal: String`
    - `setup(m: Main)`, `go_to(node_name: String)`, `arrived() -> bool`, `reset_route()`
    - virtual `think(delta: float)`, virtual `day_think(delta: float)`
  - **`ParkedBot`** always stays at `home`.
  - **`NaiveBot`** follows the spec 13.3 rules. Its day behavior is walking to the `sign` node, where standing closes up once Task 24 exists.
  - **`SimHarness`** (RefCounted):
    - `SimHarness.new(parent: Node)`
    - `start(seed: int, bot_script: GDScript)`, `finish()`
    - `tick()`, `run_until(cond: Callable, max_seconds: float) -> bool`
    - `run_night(max_seconds := 300.0) -> Dictionary` returns `{day, failed, cleared, diner_frac, kills}`
    - `run_day(max_seconds := 400.0) -> Dictionary` returns `{seconds, closed}`
    - fields: `elapsed: float`, `first_combat_s: float`, `main`, `bot`

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_bots.gd`:
```gdscript
extends GutTest

var h: SimHarness

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)

func after_each() -> void:
	h.finish()

func test_bot_walks_route_and_stops_at_goal() -> void:
	h.start(11, BotBase)  # base bot: no think(), only steering
	h.bot.go_to("zone_north")
	var ok := await h.run_until(func(): return h.bot.arrived(), 15.0)
	assert_true(ok)
	assert_lt(h.main.hero.xz().distance_to(MapLayout.lane_end("north")), 0.15)
	await h.run_until(func(): return false, 0.5)
	assert_gt(h.main.hero.still_time, 0.3)

func test_parked_bot_stays_home() -> void:
	h.start(11, ParkedBot)  # spawns at NIGHT1_START (D-126), walks home in about 6 s
	await h.run_until(func(): return false, 10.0)
	assert_lt(h.main.hero.xz().distance_to(MapLayout.HOME), 0.1)

func test_naive_bot_heads_for_main_lane_at_night_start() -> void:
	h.start(11, NaiveBot)
	await h.run_until(func(): return false, 1.2)
	assert_eq(h.bot.goal, "zone_north")  # night 1 wave 0 is always north

func test_route_reset_on_restore() -> void:
	h.start(11, NaiveBot)
	await h.run_until(func(): return false, 1.2)
	GameState.from_dict(GameState.to_dict())
	assert_eq(h.bot.goal, "")
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`SimHarness` not declared).

- [ ] **Step 3: Implement the bots**

`actors/bots/bot_base.gd`:
```gdscript
class_name BotBase
extends Node
## Scripted player for sims (spec 13.3). Drives the hero only through HeroInput on a fixed graph.

var main: Main
var hero: Hero
var graph := WaypointGraph.create_default()
var goal := ""
var _route: Array = []

func setup(m: Main) -> void:
	main = m
	hero = m.hero
	hero.input.player_control = false
	EventBus.state_restored.connect(reset_route)

func reset_route() -> void:
	goal = ""
	_route = []

func go_to(node_name: String) -> void:
	if goal == node_name:
		return
	goal = node_name
	_route = graph.route_from(hero.xz(), node_name)

func arrived() -> bool:
	return goal != "" and _route.is_empty() and hero.xz().distance_to(graph.position_of(goal)) < 0.15

func _physics_process(delta: float) -> void:
	if main == null:
		return
	think(delta)
	_steer()

func think(_delta: float) -> void:
	pass

func day_think(_delta: float) -> void:
	go_to("sign")  # walking in arms the sign (D-121); standing there closes up

func _steer() -> void:
	var step := Balance.data.hero.move_speed / float(Engine.physics_ticks_per_second)
	while not _route.is_empty():
		var tol := step if _route.size() > 1 else 0.02
		if hero.xz().distance_to(_route[0]) <= tol:
			_route.pop_front()
		else:
			break
	if _route.is_empty():
		hero.input.set_move(Vector2.ZERO)
		return
	var d: Vector2 = _route[0] - hero.xz()
	if _route.size() > 1 or d.length() > step:
		hero.input.set_move(d.normalized())
	else:
		hero.input.set_move(d / step)
```

`actors/bots/parked_bot.gd`:
```gdscript
class_name ParkedBot
extends BotBase
## Negative control (D-056, D-122): walks from the night-1 start to home (0, 9.5) and stays there.

func think(_delta: float) -> void:
	go_to("home")
```

`actors/bots/naive_bot.gd`:
```gdscript
class_name NaiveBot
extends BotBase
## Night: defend the main lane, then the lane with most live enemies; re-decide every 1 s; never builds.

var _decide_timer := 0.0

func think(delta: float) -> void:
	var pc := main.phase_controller
	if pc.failing:
		return
	if pc.phase == Phase.NIGHT:
		_night(delta)
	elif pc.phase == Phase.DAY:
		_decide_timer = 0.0
		day_think(delta)

func _night(delta: float) -> void:
	_decide_timer -= delta
	if _decide_timer > 0.0:
		return
	_decide_timer = 1.0
	var wd := main.world.wave_director
	var r := Balance.data.hero.attack_range
	for c in wd.enemy_candidates():
		var p: Vector3 = c.position
		if Vector2(p.x, p.z).distance_to(hero.xz()) <= r:
			return  # enemies in range: stay
	var counts := {"west": 0, "north": 0, "east": 0}
	for b in wd.alive_enemies():
		counts[b.lane] += 1
	var best := ""
	var best_n := 0
	for lane in LanePlanner.LANES:
		if counts[lane] > best_n:
			best = lane
			best_n = counts[lane]
	if best == "":
		best = wd.upcoming_main_lane()
	go_to("zone_" + best)
```

- [ ] **Step 4: Implement the harness**

`tests/sim/sim_harness.gd`:
```gdscript
class_name SimHarness
extends RefCounted
## Runs a real Main headless with a bot (spec 13.4). Reads results only from signals and GameState (D-113).

var parent: Node
var main: Main
var bot: BotBase
var elapsed := 0.0
var first_combat_s := -1.0
var diner_min := INF
var kills := 0
var failed := false

func _init(p_parent: Node) -> void:
	parent = p_parent

func start(seed: int, bot_script: GDScript) -> void:
	main = Main.create()
	parent.add_child(main)
	bot = bot_script.new()
	bot.name = "Bot"
	main.add_child(bot)
	bot.setup(main)
	EventBus.diner_damaged.connect(_on_diner_damaged)
	EventBus.enemy_killed.connect(_on_killed)
	EventBus.night_failed.connect(_on_failed)
	main.phase_controller.start_new_game(seed)

func finish() -> void:
	for pair in [[EventBus.diner_damaged, _on_diner_damaged], [EventBus.enemy_killed, _on_killed], [EventBus.night_failed, _on_failed]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	if is_instance_valid(main):
		main.queue_free()

func tick() -> void:
	await parent.get_tree().physics_frame
	elapsed += 1.0 / Engine.physics_ticks_per_second
	if first_combat_s < 0.0 and main.phase_controller.phase == Phase.NIGHT:
		var r := Balance.data.hero.attack_range
		for c in main.world.wave_director.enemy_candidates():
			var p: Vector3 = c.position
			if Vector2(p.x, p.z).distance_to(main.hero.xz()) <= r:
				first_combat_s = elapsed
				break

func run_until(cond: Callable, max_seconds: float) -> bool:
	var n := int(max_seconds * Engine.physics_ticks_per_second)
	for i in n:
		if cond.call():
			return true
		await tick()
	return cond.call()

func run_night(max_seconds := 300.0) -> Dictionary:
	diner_min = GameState.diner_hp
	failed = false
	kills = 0
	var day := GameState.day
	await run_until(func(): return failed or main.phase_controller.phase == Phase.DAY, max_seconds)
	return {
		"day": day, "failed": failed, "cleared": not failed and main.phase_controller.phase == Phase.DAY,
		"diner_frac": diner_min / Balance.data.build.diner_max_hp, "kills": kills,
	}

func run_day(max_seconds := 400.0) -> Dictionary:
	var t0 := elapsed
	await run_until(func(): return main.phase_controller.phase == Phase.NIGHT, max_seconds)
	return {"seconds": elapsed - t0, "closed": main.phase_controller.phase == Phase.NIGHT}

func _on_diner_damaged(_amount: float, hp_left: float) -> void:
	diner_min = minf(diner_min, hp_left)

func _on_killed(_i: int, _lane: StringName, _p: Vector3) -> void:
	kills += 1

func _on_failed(_day: int) -> void:
	failed = true
```

`tests/sim/sim_harness.gd` has no `test_` prefix, so GUT doesn't run it as a test. It lives under `tests/` because it is test tooling; `class_name` makes it global after the `--import` scan.

- [ ] **Step 5: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add actors/bots tests/sim/sim_harness.gd tests/unit/test_bots.gd
git commit -m "feat: add sim bots on the waypoint graph and a headless sim harness"
```

### Task 20: Night sims and the capture tool → **CHECKPOINT 1**

**Files:**
- Create: `tests/sim/test_night_sims.gd`, `tests/sim/capture.gd`
- Output (committed): `docs/screenshots/s1/cp1_night1.png`

**Interfaces:**
- Consumes: `SimHarness`, `NaiveBot`, `ParkedBot`, `Balance.data.sim`, `CameraMath`.
- Produces: `tests/sim/capture.gd`, a SceneTree script run *with* rendering. Usage:
  `"$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --out=<png> --seconds=<t> [--seed=<n>] [--lane=<id>]`

- [ ] **Step 1: Write the night sims**

`tests/sim/test_night_sims.gd`:
```gdscript
extends GutTest
## Spec 13.4 night-1 rows (D-056, D-058, D-085, D-043). Thresholds only (D-105).

const SEED := 20260930
var h: SimHarness

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)

func after_each() -> void:
	h.finish()

func test_first_combat_within_30s() -> void:
	h.start(SEED, NaiveBot)
	await h.run_until(func(): return h.first_combat_s >= 0.0, 40.0)
	gut.p("first combat at %.2f s (on paper ~12 s from NIGHT1_START, D-126)" % h.first_combat_s)
	assert_between(h.first_combat_s, 0.0, Balance.data.sim.first_combat_max_s)

func test_night1_naive_bot_holds() -> void:
	h.start(SEED, NaiveBot)
	var r := await h.run_night()
	gut.p("night1 naive: %s" % r)
	assert_true(r.cleared, "night 1 must be cleared")
	assert_true(r.diner_frac >= Balance.data.sim.night1_win_min, "diner %.2f" % r.diner_frac)

func test_night1_parked_bot_falls() -> void:
	h.start(SEED, ParkedBot)
	var r := await h.run_night()
	gut.p("night1 parked: %s" % r)
	assert_true(r.failed, "parking must not be a strategy (D-056)")

func test_first_combat_idle_player_within_30s() -> void:
	# D-126: a new player who never touches the joystick still meets wave 0 at the start point.
	h.start(SEED, BotBase)  # base bot: no think(), the hero stays at NIGHT1_START
	await h.run_until(func(): return h.first_combat_s >= 0.0, 40.0)
	gut.p("idle first combat at %.2f s" % h.first_combat_s)
	assert_between(h.first_combat_s, 0.0, Balance.data.sim.first_combat_max_s)

func test_night1_fail_restarts_night() -> void:
	h.start(SEED, ParkedBot)
	var snap: Dictionary = h.main.phase_controller.snapshot.duplicate(true)
	await h.run_night()
	await h.run_until(func(): return not h.main.phase_controller.failing, 5.0)
	assert_eq(h.main.phase_controller.phase, Phase.NIGHT)
	var now := GameState.to_dict()
	now.resume_phase = snap.resume_phase
	assert_eq(now, snap)
	var t0 := h.elapsed
	await h.run_until(func(): return h.main.world.wave_director.state == WaveDirector.State.ACTIVE, 10.0)
	assert_almost_eq(h.elapsed - t0, Balance.data.wave.first_wave_delay, 3.0 / 60.0)

func test_night1_deterministic() -> void:
	var results: Array = []
	for run in 2:
		Balance.reset()
		var hh := SimHarness.new(self)
		hh.start(SEED, NaiveBot)
		var plan := GameState.lane_plan.duplicate(true)
		var r := await hh.run_night()
		r["plan"] = plan
		r["steaks"] = GameState.freezer_steaks + GameState.carried_steaks
		results.append(r)
		hh.finish()
		await get_tree().process_frame
	gut.p("determinism: %s" % [results])
	assert_eq(results[0], results[1])
```

- [ ] **Step 2: Run the sims**

Run: `./run_tests.sh sim`

Expected: exit 0 and `SIM SUITE: <n>s (budget 60s)`. The log prints the first-combat time, the night-1 diner fraction and the determinism tuples.

If a threshold test fails, **do not tune yet**. Tuning is Task 35. Record the numbers and escalate to the main session, which decides whether to take the Balance fix early.

- [ ] **Step 3: Write the capture tool**

`tests/sim/capture.gd`:
```gdscript
extends SceneTree
## Renders the real game and saves a 720x1280 PNG. Run WITH rendering (no --headless):
## "$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --out=docs/screenshots/s1/x.png --seconds=12
## --lane=<west|north|east>: hero parked at that lane's zone, one Boar 2 s before it reaches hero range.

var _args := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_run.call_deferred()

func _run() -> void:
	Balance.reset()
	var main := Main.create()
	root.add_child(main)
	var bot: BotBase = (ParkedBot if _args.has("lane") else NaiveBot).new()
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.start_new_game(int(_args.get("seed", "20260930")))
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = Balance.ui.camera_fov_h
	cam.current = true
	root.add_child(cam)
	if _args.has("lane"):
		var lane: String = _args.lane
		main.phase_controller.phase = Phase.DAY  # freeze waves for a staged shot
		main.world.wave_director.stop()
		main.hero.teleport(MapLayout.lane_end(lane))
		bot.queue_free()
		var eb := Balance.data.enemy
		var b := main.world.wave_director.debug_spawn(lane)
		var length := MapLayout.path_length(lane)
		var d := length
		while d > 0.0 and EnemyPath.position_at(lane, d, 0.0, eb.offset_fade_distance).distance_to(MapLayout.lane_end(lane)) <= Balance.data.hero.attack_range:
			d -= 0.05
		b.dist = maxf(d - eb.speed * 2.0, 0.0)
		b.set_physics_process(false)
		b._update_position()
	else:
		for i in int(float(_args.get("seconds", "12")) * 60.0):
			await physics_frame
	cam.global_transform = CameraMath.camera_transform(CameraMath.focus_for(main.hero.xz()), Balance.ui)
	for i in 3:
		await process_frame
	var img := root.get_texture().get_image()
	var out: String = _args.get("out", "docs/screenshots/s1/capture.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(out.get_base_dir()))
	img.save_png(ProjectSettings.globalize_path("res://").path_join(out))
	print("saved ", out, " ", img.get_size())
	quit(0)
```

- [ ] **Step 4: Capture a night-1 frame**

```bash
"$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --out=docs/screenshots/s1/cp1_night1.png --seconds=14
```

Expected: `saved docs/screenshots/s1/cp1_night1.png (720, 1280)`. Open the PNG. It should show the diner, the north lane with red capsules, and the blue hero.

- [ ] **Step 5: Commit**

```bash
git add tests/sim/test_night_sims.gd tests/sim/capture.gd docs/screenshots/s1/cp1_night1.png
git commit -m "test: add night-1 sims and a render capture tool"
```

- [ ] **Step 6: CHECKPOINT 1. Stop and wait for the author.**

CP1 is a quality review only (D-131). Report to the author:
- the full `./run_tests.sh sim` output (first combat, the night-1 NaiveBot diner fraction, the ParkedBot fall, restart timing, determinism);
- the path `docs/screenshots/s1/cp1_night1.png`;
- anything escalated.

Do not start Task 21 until the author says continue.

---
## Phase 6: Day stations and travelers

### Task 21: `StationZone`, `ProgressRing`, `Freezer`, `Counter`

**Files:**
- Create:
  - `components/station_zone.gd`
  - `ui/progress_ring/progress_ring.gd`, `ui/progress_ring/progress_ring.gdshader`
  - `world/stations/freezer.gd`, `world/stations/counter.gd`
- Modify: `world/world.gd`, `actors/hero/hero.gd` (`teleport_serial`)
- Test: `tests/unit/test_stations.gd`, helper `tests/unit/helpers.gd`

**Interfaces:**
- Consumes: the `Hero` in group `&"hero"` (`still_time`, `global_position`, `teleport_serial`), `phase_changed`, `GameState.move_freezer_to_carry/move_carry_to_counter`.
- Produces:
  - **`StationZone`** (Node3D):
    - `radius: float`, `active_phases: Array[int]` (default `[Phase.DAY]`), `standing: bool`, `armed: bool`, `ring: ProgressRing`
    - `disarm()`, called on `phase_changed`, `state_restored` and hero teleport (D-121)
    - signals `stand_started`, `ticked`, `stand_ended`
    - `is_active() -> bool`
  - **`ProgressRing`** (MeshInstance3D): `set_progress(p: float)`.
  - **`TestHelpers.walk_in(hero: Hero, target: Vector2, from_offset := Vector2(0, 2)) -> void`** (async): teleports just outside, then walks in the way a player does. Every test that uses a station walks in with it; a teleport into a zone never arms it.
  - **`Freezer`** and **`Counter`** (Node3D): `setup(world: World)`, `zone: StationZone`, `label: WorldLabel`, `stack_count() -> int`.
  - **`World`:** `freezer: Freezer`, `counter: Counter`, `add_static_box(...)` (public, from Task 12).

- [ ] **Step 1: Write the failing tests**

`tests/unit/helpers.gd` (no `test_` prefix, so GUT doesn't collect it):
```gdscript
class_name TestHelpers
extends RefCounted
## Walks the hero into a point from just outside, the way a player enters a station (D-121).

static func walk_in(hero: Hero, target: Vector2, from_offset := Vector2(0, 2.0)) -> void:
	hero.teleport(target + from_offset)
	var tree := hero.get_tree()
	await tree.physics_frame
	var step := Balance.data.hero.move_speed / float(Engine.physics_ticks_per_second)
	for i in 600:
		var d := target - hero.xz()
		if d.length() < 0.02:
			break
		hero.input.set_move((d / step).limit_length(1.0))
		await tree.physics_frame
	hero.input.set_move(Vector2.ZERO)
```

`tests/unit/test_stations.gd`:
```gdscript
extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(8)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _day() -> void:
	main.phase_controller.debug_skip_to_day()

func test_freezer_fills_carry_to_capacity() -> void:
	_day()
	GameState.add_freezer(10)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	await _ticks(30)
	assert_between(GameState.carried_steaks, 2, 4)  # PINNED to the default 0.25 s still + 0.08 s tick
	await _ticks(30)
	assert_eq(GameState.carried_steaks, Balance.data.hero.carry_capacity)
	assert_eq(GameState.freezer_steaks, 10 - Balance.data.hero.carry_capacity)

func test_freezer_inactive_at_night() -> void:
	GameState.add_freezer(10)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	await _ticks(60)
	assert_eq(GameState.carried_steaks, 0)

func test_teleport_into_zone_does_not_arm() -> void:
	# D-121
	_day()
	GameState.add_freezer(10)
	main.hero.teleport(MapLayout.FREEZER_ZONE)
	await _ticks(60)
	assert_false(main.world.freezer.zone.armed)
	assert_eq(GameState.carried_steaks, 0)

func test_inside_when_zone_activates_needs_reentry() -> void:
	# D-121: hero inside at NIGHT, zone activates at dawn -> nothing until it leaves and re-enters.
	GameState.add_freezer(10)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	_day()
	await _ticks(60)
	assert_eq(GameState.carried_steaks, 0)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	await _ticks(60)
	assert_gt(GameState.carried_steaks, 0)

func test_moving_hero_does_not_transfer() -> void:
	_day()
	GameState.add_freezer(10)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE + Vector2(-0.8, 0))
	main.hero.input.set_move(Vector2(1, 0) * 0.1)  # 0.5 m/s drift inside the zone
	await _ticks(20)
	assert_eq(GameState.carried_steaks, 0)

func test_counter_fills_up_to_capacity() -> void:
	_day()
	var cap := Balance.data.economy.counter_capacity
	GameState.carried_steaks = 3  # test-only setup
	GameState.counter_steaks = cap - 1
	await TestHelpers.walk_in(main.hero, MapLayout.COUNTER_DROP)
	await _ticks(60)
	assert_eq(GameState.counter_steaks, cap)
	assert_eq(GameState.carried_steaks, 2)

func test_leaving_ends_stand() -> void:
	_day()
	var z: StationZone = main.world.freezer.zone
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	await _ticks(20)
	assert_true(z.standing)
	main.hero.teleport(Vector2(15, 8))
	await _ticks(2)
	assert_false(z.standing)

func test_labels_follow_state() -> void:
	_day()
	GameState.add_freezer(15)
	assert_eq(main.world.freezer.label.text, "15")
	assert_eq(main.world.freezer.stack_count(), 10)
	GameState.from_dict(main.phase_controller.snapshot)
	assert_eq(main.world.freezer.label.text, "0")
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`main.world.freezer` is null).

- [ ] **Step 3: Implement the zone and ring**

`ui/progress_ring/progress_ring.gdshader`:
```glsl
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.2, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = fract(atan(p.x, -p.y) / 6.28318530718 + 1.0);
	float ring = step(0.72, r) * step(r, 1.0);
	float fill = step(ang, progress);
	ALBEDO = color.rgb;
	ALPHA = ring * mix(0.25, 1.0, fill) * color.a;
}
```

`ui/progress_ring/progress_ring.gd`:
```gdscript
class_name ProgressRing
extends MeshInstance3D
## Shared stand-still progress ring (D-073). Flat on the ground; visual only.

const SHADER := preload("res://ui/progress_ring/progress_ring.gdshader")

func _init() -> void:
	var m := PlaneMesh.new()
	m.size = Vector2(2.4, 2.4)
	mesh = m
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material_override = mat
	position.y = 0.03
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_progress(p: float) -> void:
	(material_override as ShaderMaterial).set_shader_parameter("progress", clampf(p, 0.0, 1.0))
```

`components/station_zone.gd`:
```gdscript
class_name StationZone
extends Node3D
## Stand-still interaction (D-006, spec 8.1): hero inside radius, still for stand_still_time, phase active.
## Emits `ticked` every transfer_tick while standing. State changes happen in the owner's tick handler.

signal stand_started
signal ticked
signal stand_ended

var radius := 1.0
var active_phases: Array[int] = [Phase.DAY]
var standing := false
## Armed only when the hero walks INTO the radius while the zone is active (D-121).
var armed := false
var ring: ProgressRing
var _phase := Phase.NIGHT
var _tick_timer := 0.0
var _seen_outside := false
var _seen_teleport := -1

func _ready() -> void:
	ring = ProgressRing.new()
	ring.scale = Vector3.ONE * (radius / 1.2)
	ring.visible = false
	add_child(ring)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.state_restored.connect(disarm)

func is_active() -> bool:
	return _phase in active_phases

## A hero already inside must leave and re-enter before the zone works again.
func disarm() -> void:
	armed = false
	_seen_outside = false
	if standing:
		_end()

func _on_phase_changed(p: int, _day: int) -> void:
	_phase = p
	disarm()

func _physics_process(delta: float) -> void:
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	if hero == null:
		return
	if hero.teleport_serial != _seen_teleport:
		_seen_teleport = hero.teleport_serial
		disarm()
	var d := Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length()
	var inside := d <= radius
	if is_active():
		if not inside:
			_seen_outside = true
			armed = false
		elif _seen_outside:
			armed = true
	var ok := is_active() and inside and armed and hero.still_time >= Balance.data.economy.stand_still_time - 1e-6
	if ok:
		if not standing:
			standing = true
			_tick_timer = 0.0
			ring.visible = true
			stand_started.emit()
		_tick_timer += delta
		var tick := Balance.data.economy.transfer_tick
		while _tick_timer >= tick - 1e-9:
			_tick_timer -= tick
			ticked.emit()
	elif standing:
		_end()

func _end() -> void:
	standing = false
	ring.visible = false
	stand_ended.emit()
```

Because `ring.scale` uses `radius` in `_ready`, owners set `radius` **before** `add_child(zone)`.

- [ ] **Step 4: Implement the freezer and counter**

`world/stations/freezer.gd`:
```gdscript
class_name Freezer
extends Node3D
## Freezer → carry, 1 steak per tick (spec 8.2). Visual stack up to 10 plus a count label.

var zone: StationZone
var label: WorldLabel
var _stack: Array = []

func setup(world: World) -> void:
	name = "Freezer"
	world.add_static_box("FreezerBody", Vector3(MapLayout.FREEZER_SIZE.x, 1.4, MapLayout.FREEZER_SIZE.y), MapLayout.FREEZER, Visuals.COLORS.freezer)
	position = MapLayout.to3(MapLayout.FREEZER_ZONE)
	zone = StationZone.new()
	zone.radius = MapLayout.STATION_RADIUS
	add_child(zone)
	zone.ticked.connect(_on_tick)
	label = WorldLabel.make("0")
	label.position = MapLayout.to3(MapLayout.FREEZER - MapLayout.FREEZER_ZONE, 2.6)
	add_child(label)
	for i in 10:
		var m := Visuals.box(Vector3(0.35, 0.16, 0.25), Visuals.COLORS.steak)
		m.position = MapLayout.to3(MapLayout.FREEZER - MapLayout.FREEZER_ZONE, 1.5 + i * 0.18)
		add_child(m)
		_stack.append(m)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_tick() -> void:
	GameState.move_freezer_to_carry(1)

func refresh() -> void:
	label.text = str(GameState.freezer_steaks)
	for i in _stack.size():
		_stack[i].visible = i < GameState.freezer_steaks

func stack_count() -> int:
	return _stack.filter(func(m): return m.visible).size()
```

`world/stations/counter.gd`:
```gdscript
class_name Counter
extends Node3D
## Carry → counter, 1 steak per tick up to counter_capacity (spec 8.3). Travelers buy from it.

var zone: StationZone
var label: WorldLabel
var _stack: Array = []

func setup(world: World) -> void:
	name = "Counter"
	world.add_static_box("CounterBody", Vector3(MapLayout.COUNTER_SIZE.x, 1.0, MapLayout.COUNTER_SIZE.y), MapLayout.COUNTER, Visuals.COLORS.counter)
	position = MapLayout.to3(MapLayout.COUNTER_DROP)
	zone = StationZone.new()
	zone.radius = MapLayout.STATION_RADIUS
	add_child(zone)
	zone.ticked.connect(_on_tick)
	label = WorldLabel.make("0")
	label.position = MapLayout.to3(MapLayout.COUNTER - MapLayout.COUNTER_DROP, 2.2)
	add_child(label)
	for i in Balance.data.economy.counter_capacity:
		var m := Visuals.box(Vector3(0.35, 0.16, 0.25), Visuals.COLORS.steak)
		var col := i % 6
		var row := i / 6
		m.position = MapLayout.to3(MapLayout.COUNTER - MapLayout.COUNTER_DROP + Vector2(-1.1 + col * 0.44, -0.2 + row * 0.4), 1.1)
		add_child(m)
		_stack.append(m)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_tick() -> void:
	GameState.move_carry_to_counter(1)

func refresh() -> void:
	label.text = str(GameState.counter_steaks)
	for i in _stack.size():
		_stack[i].visible = i < GameState.counter_steaks

func stack_count() -> int:
	return _stack.filter(func(m): return m.visible).size()
```

Modify `world/world.gd`:
```gdscript
var freezer: Freezer
var counter: Counter

# in _ready(), after _build_spots():
	_build_stations()

func _build_stations() -> void:
	freezer = Freezer.new()
	add_child(freezer)
	freezer.setup(self)
	counter = Counter.new()
	add_child(counter)
	counter.setup(self)
```

- [ ] **Step 5: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add components/station_zone.gd ui/progress_ring world/stations world/world.gd actors/hero/hero.gd tests/unit/helpers.gd tests/unit/test_stations.gd
git commit -m "feat: add stand-still station zones that arm on entry, freezer and counter"
```

### Task 22: `Traveler`, `TravelerSpawner`, `GoldPile`, and the phase hooks

**Files:**
- Create: `actors/traveler/traveler.gd`, `world/traveler_spawner.gd`, `world/stations/gold_pile.gd`
- Modify: `world/world.gd`, `world/phase_controller.gd`, `world/main.tscn`
- Test: `tests/unit/test_travelers.gd`

**Interfaces:**
- Consumes: `GameState.sell_from_counter`, `Rng.stream(.., &"travelers")`, `NodePool`.
- Produces:
  - **`Traveler`:**
    - `want: int`, `service_timer: float`, `leaving: bool`
    - `begin(p_want: int)`, `set_target(p: Vector2)`, `leave()`
    - `at_target() -> bool`, `gone() -> bool`, `xz() -> Vector2`
  - **`TravelerSpawner`:** the D-128 interface is `start()`, `stop()` (queued travelers leave) and `clear_queue()` (drops every traveler and recalls its pool). Also `setup(pool)`, `queue: Array`, `leaving: Array`, `active: bool`.
  - **`GoldPile`:** `setup(world)`, `coin_count() -> int`.
  - **`World`:** `traveler_spawner`, `gold_pile`.
  - **PhaseController hooks:**
    - `_enter_day()` calls `traveler_spawner.start()`.
    - `_enter_night()` calls `traveler_spawner.stop()`.
    - `close_up()` calls `traveler_spawner.stop()` before taking the snapshot.
    - `_recall_all()` calls `traveler_spawner.clear_queue()`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_travelers.gd`:
```gdscript
extends GutTest

var main: Main
var sp: TravelerSpawner

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(21)
	main.hero.teleport(Vector2(15, 8))  # well away from every station zone
	sp = main.world.traveler_spawner

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_no_travelers_at_night() -> void:
	await _ticks(300)
	assert_eq(sp.queue.size(), 0)

func test_spawn_and_queue_cap_in_day() -> void:
	main.phase_controller.debug_skip_to_day()
	await _ticks(60 * 3)
	assert_gt(sp.queue.size(), 0)
	await _ticks(60 * 20)
	assert_eq(sp.queue.size(), Balance.data.economy.queue_max)

func test_purchase_is_atomic_after_service_time() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.counter_steaks = 5  # test-only setup
	var ok := await _wait_front_at_counter()
	assert_true(ok)
	var front: Traveler = sp.queue[0]
	var want := front.want
	await _ticks(30)  # half the service time: nothing sold yet
	assert_eq(GameState.counter_steaks, 5)
	assert_eq(GameState.gold_pile, 0)
	await _ticks(35)
	assert_eq(GameState.counter_steaks, 5 - want)
	assert_eq(GameState.gold_pile, want * Balance.data.economy.gold_per_steak)
	assert_true(front.leaving)

func test_empty_counter_front_waits() -> void:
	main.phase_controller.debug_skip_to_day()
	assert_true(await _wait_front_at_counter())
	await _ticks(120)
	assert_false((sp.queue[0] as Traveler).leaving)
	assert_eq(GameState.gold_pile, 0)

func test_close_up_sends_everyone_away_and_stops() -> void:
	main.phase_controller.debug_skip_to_day()
	await _ticks(60 * 6)
	main.phase_controller.close_up()
	assert_eq(sp.queue.size(), 0)
	for t in sp.leaving:
		assert_true(t.leaving)
	await _ticks(60 * 5)
	assert_eq(sp.queue.size(), 0)

func test_gold_pile_visual() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.counter_steaks = 1
	GameState.sell_from_counter(1)
	assert_eq(main.world.gold_pile.coin_count(), Balance.data.economy.gold_per_steak)

func _wait_front_at_counter() -> bool:
	for i in 60 * 20:
		if not sp.queue.is_empty() and (sp.queue[0] as Traveler).at_target():
			return true
		await get_tree().physics_frame
	return false
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`traveler_spawner` is null).

- [ ] **Step 3: Implement**

`actors/traveler/traveler.gd`:
```gdscript
class_name Traveler
extends Node3D
## A buyer (spec 8.4). Moved in code; holds no game state (D-045).

var want := 1
var service_timer := 0.0
var leaving := false
var _target := Vector2.ZERO

func _init() -> void:
	name = "Traveler"
	var v := Visuals.visual_root()
	var m := Visuals.capsule(0.35, 1.4, Visuals.COLORS.traveler)
	m.position.y = 0.7
	v.add_child(m)
	add_child(v)

func begin(p_want: int) -> void:
	want = p_want
	service_timer = 0.0
	leaving = false
	position = MapLayout.to3(MapLayout.TRAVELER_ENTER)
	_target = MapLayout.TRAVELER_ENTER

func set_target(p: Vector2) -> void:
	_target = p

func leave() -> void:
	leaving = true
	_target = MapLayout.TRAVELER_EXIT

func xz() -> Vector2:
	return Vector2(position.x, position.z)

func at_target() -> bool:
	return xz().distance_to(_target) < 0.05

func gone() -> bool:
	return leaving and at_target()

func _physics_process(delta: float) -> void:
	position = MapLayout.to3(xz().move_toward(_target, Balance.data.economy.traveler_speed * delta))
```

`world/traveler_spawner.gd`:
```gdscript
class_name TravelerSpawner
extends Node
## Day-only traveler queue (spec 8.4, D-064). Purchases are atomic at the service point (D-045).

var pool: NodePool
var queue: Array = []
var leaving: Array = []
var active := false
var _timer := 0.0
var _rng: RandomNumberGenerator

func setup(p_pool: NodePool) -> void:
	pool = p_pool

## D-128 interface: start spawning for today's day number.
func start() -> void:
	active = true
	_rng = Rng.stream(GameState.run_seed, GameState.day, &"travelers")
	_timer = _next_interval()

## D-128 interface: stop spawning; queued travelers walk away holding nothing (D-045).
func stop() -> void:
	active = false
	for t in queue:
		t.leave()
	leaving.append_array(queue)
	queue.clear()

## D-128 interface: drop every traveler immediately (restore / new game).
func clear_queue() -> void:
	queue.clear()
	leaving.clear()
	pool.recall_all()

func _next_interval() -> float:
	var e := Balance.data.economy
	return e.traveler_interval + _rng.randf_range(-e.traveler_jitter, e.traveler_jitter)

func _physics_process(delta: float) -> void:
	var e := Balance.data.economy
	if active:
		_timer -= delta
		if _timer <= 0.0:
			_timer = _next_interval()
			if queue.size() < e.queue_max:
				var t: Traveler = pool.acquire()
				t.begin(_rng.randi_range(e.traveler_want_min, e.traveler_want_max))
				queue.append(t)
	for i in queue.size():
		(queue[i] as Traveler).set_target(MapLayout.QUEUE_SLOTS[i])
	if active and not queue.is_empty():
		var front: Traveler = queue[0]
		if front.at_target() and GameState.counter_steaks > 0:
			front.service_timer += delta
			if front.service_timer >= e.service_time - 1e-6:
				GameState.sell_from_counter(front.want)
				queue.pop_front()
				front.leave()
				leaving.append(front)
	for t in leaving.duplicate():
		if t.gone():
			leaving.erase(t)
			pool.release(t)
```

`world/stations/gold_pile.gd`:
```gdscript
class_name GoldPile
extends Node3D
## Coins waiting to be collected by walking over (spec 8.5). Drawn from GameState.gold_pile.

const MAX_COINS := 30
var label: WorldLabel
var _coins: Array = []

func setup(_world: World) -> void:
	name = "GoldPile"
	position = MapLayout.to3(MapLayout.GOLD_PILE)
	for i in MAX_COINS:
		var c := Visuals.cylinder(0.18, 0.06, Visuals.COLORS.coin)
		c.position = Vector3((i % 3) * 0.38 - 0.38, 0.04 + (i / 3) * 0.07, 0)
		add_child(c)
		_coins.append(c)
	label = WorldLabel.make("")
	label.position.y = 1.6
	add_child(label)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func refresh() -> void:
	var n := GameState.gold_pile
	for i in _coins.size():
		_coins[i].visible = i < n
	label.text = str(n) if n > 0 else ""

func coin_count() -> int:
	return _coins.filter(func(c): return c.visible).size()
```

Modify `world/world.gd`:
```gdscript
@export var traveler_pool: NodePool
@export var traveler_spawner: TravelerSpawner
var gold_pile: GoldPile

# append to _build_stations():
	gold_pile = GoldPile.new()
	add_child(gold_pile)
	gold_pile.setup(self)
	traveler_pool.setup(func(): return Traveler.new(), Balance.data.economy.queue_max * 2)
	traveler_spawner.setup(traveler_pool)
```

Modify `world/phase_controller.gd`:
```gdscript
@export var traveler_spawner: TravelerSpawner

# _enter_night(): add as the first line
	traveler_spawner.stop()

# _enter_day(): add after phase_changed.emit(...)
	traveler_spawner.start()

# close_up(): after _steaks_to_freezer() and before the snapshot
	traveler_spawner.stop()

# _recall_all(): add as the last line
	traveler_spawner.clear_queue()
```

Add the TravelerPool and TravelerSpawner nodes, and wire `traveler_spawner` into PhaseController

`world/main.tscn` (full content at this stage):
```
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://world/main.gd" id="1_main"]
[ext_resource type="Script" path="res://world/world.gd" id="2_world"]
[ext_resource type="Script" path="res://components/node_pool.gd" id="3_pool"]
[ext_resource type="Script" path="res://world/wave_director.gd" id="4_wave"]
[ext_resource type="Script" path="res://world/phase_controller.gd" id="5_phase"]
[ext_resource type="Script" path="res://world/traveler_spawner.gd" id="6_spawner"]

[node name="Main" type="Node3D" node_paths=PackedStringArray("world", "phase_controller")]
script = ExtResource("1_main")
world = NodePath("World")
phase_controller = NodePath("PhaseController")

[node name="World" type="Node3D" parent="." node_paths=PackedStringArray("enemy_pool", "steak_pool", "projectile_pool", "wave_director", "traveler_pool", "traveler_spawner")]
script = ExtResource("2_world")
enemy_pool = NodePath("EnemyPool")
steak_pool = NodePath("SteakPool")
projectile_pool = NodePath("ProjectilePool")
wave_director = NodePath("WaveDirector")
traveler_pool = NodePath("TravelerPool")
traveler_spawner = NodePath("TravelerSpawner")

[node name="EnemyPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="SteakPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="ProjectilePool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="WaveDirector" type="Node" parent="World"]
script = ExtResource("4_wave")

[node name="TravelerPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="TravelerSpawner" type="Node" parent="World"]
script = ExtResource("6_spawner")

[node name="PhaseController" type="Node" parent="." node_paths=PackedStringArray("wave_director", "enemy_pool", "steak_pool", "projectile_pool", "traveler_spawner")]
script = ExtResource("5_phase")
wave_director = NodePath("../World/WaveDirector")
enemy_pool = NodePath("../World/EnemyPool")
steak_pool = NodePath("../World/SteakPool")
projectile_pool = NodePath("../World/ProjectilePool")
traveler_spawner = NodePath("../World/TravelerSpawner")
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0. Re-run the Task 17 tests too; they are in the same suite.

- [ ] **Step 5: Commit**

```bash
git add actors/traveler world tests/unit/test_travelers.gd   # world/ includes main.tscn
git commit -m "feat: add travelers, atomic counter purchases and the gold pile"
```

### Task 23: Build and upgrade payment on build spots

**Files:**
- Modify: `world/build_spots/build_spot.gd`
- Test: `tests/unit/test_build_pay.gd`

**Interfaces:**
- Consumes: `StationZone` (Task 21), `GameState.pay_into_spot/remaining_cost/next_level_cost`, `Economy.drain_per_tick`.
- Produces: `BuildSpot.zone: StationZone` (radius `MapLayout.BUILD_RADIUS`, active in DAY). The ring shows `paid / cost`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_build_pay.gd`:
```gdscript
extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(31)
	main.phase_controller.debug_skip_to_day()

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _stand(spot_id: String) -> void:
	await TestHelpers.walk_in(main.hero, WaypointGraph.create_default().position_of(spot_id))

## Frames to finish `cost` by standing: still time + ticks at the drain rate, +10 % margin.
func _frames_to_pay(cost: int) -> int:
	var e := Balance.data.economy
	var ticks := ceili(float(cost) / Economy.drain_per_tick(cost, Balance.data.build))
	return int(ceil((e.stand_still_time + ticks * e.transfer_tick) * 60.0 * 1.1))

func test_fence_builds_and_keeps_paying() -> void:
	var cost := GameState.next_level_cost("fence_n")
	GameState.add_gold(cost + 5)
	await _stand("fence_n")
	await _ticks(_frames_to_pay(cost))
	assert_eq(GameState.buildings.fence_n.level, 1)
	await _ticks(30)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.buildings.fence_n.paid, 5, "keeps paying toward the next level")

func test_partial_payment_persists_after_leaving() -> void:
	GameState.add_gold(10)
	await _stand("tower_nw")
	await _ticks(60)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.buildings.tower_nw.paid, 10)
	main.hero.teleport(MapLayout.HOME)
	await _ticks(10)
	assert_eq(GameState.buildings.tower_nw.paid, 10)
	assert_eq(main.world.build_spots.tower_nw.label.text, str(GameState.next_level_cost("tower_nw") - 10))

func test_pays_only_what_gold_allows() -> void:
	# Review Focus 5: gold below the drain never goes negative.
	assert_gt(Economy.drain_per_tick(GameState.next_level_cost("tower_ne"), Balance.data.build), 1, "precondition: drain >= 2")
	GameState.add_gold(1)
	await _stand("tower_ne")
	await _ticks(40)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.buildings.tower_ne.paid, 1)

func test_max_level_spot_takes_nothing() -> void:
	# Review Focus 5
	GameState.add_gold(10000)
	for i in Balance.data.build.max_level:
		GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	var left := GameState.gold
	assert_eq(main.world.build_spots.fence_w.label.text, "MAX")
	await _stand("fence_w")
	await _ticks(60)
	assert_eq(GameState.gold, left)

func test_dawn_inside_zone_needs_reentry() -> void:
	# D-121: hero inside a build-spot zone when dawn activates it -> no payment until exit and re-entry.
	main.phase_controller.close_up()  # back to NIGHT
	GameState.add_gold(40)
	await _stand("fence_e")
	main.phase_controller.debug_skip_to_day()
	await _ticks(60)
	assert_eq(GameState.gold, 40)
	await _stand("fence_e")
	await _ticks(60)
	assert_lt(GameState.gold, 40)

func test_no_payment_at_night() -> void:
	main.phase_controller.close_up()
	GameState.add_gold(40)
	await _stand("fence_e")
	await _ticks(60)
	assert_eq(GameState.gold, 40)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (no payment happens; `gold` stays).

- [ ] **Step 3: Implement.** Add to `world/build_spots/build_spot.gd`:

```gdscript
var zone: StationZone

# in setup(), before refresh():
	zone = StationZone.new()
	zone.radius = MapLayout.BUILD_RADIUS
	add_child(zone)
	zone.ticked.connect(_on_tick)

func _on_tick() -> void:
	var cost := GameState.next_level_cost(spot_id)
	if cost < 0:
		return
	GameState.pay_into_spot(spot_id, Economy.drain_per_tick(cost, Balance.data.build))
```

and at the end of `refresh()`:
```gdscript
	if zone != null:
		var cost := GameState.next_level_cost(spot_id) if not GameState.buildings.is_empty() else -1
		zone.ring.set_progress(0.0 if cost <= 0 else float(b.paid) / float(cost))
```

`zone.ring` is created in `StationZone._ready()`. `setup()` runs after `add_child(spot)`, and `add_child(zone)` inside `setup()` triggers `_ready` immediately, so `ring` exists before `refresh()`.

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add world/build_spots/build_spot.gd tests/unit/test_build_pay.gd
git commit -m "feat: pay into build spots by standing, with upgrades to level 3"
```

### Task 24: `CloseUpSign` with the pulse, and `TelegraphMarker`

**Files:**
- Create: `world/stations/closeup_sign.gd`, `world/lanes/telegraph_marker.gd`
- Modify: `world/world.gd`
- Test: `tests/unit/test_sign_and_telegraph.gd`

**Interfaces:**
- Consumes: `StationZone`, `Pulse.should_pulse`, `LanePlanner.threat_by_lane/marker_scale`, `EventBus.closeup_requested`.
- Produces:
  - **`CloseUpSign`:** `zone`, `hold: float`, `pulsing: bool`, `refresh_pulse()`. It emits `EventBus.closeup_requested` after `closeup_hold`.
  - **`TelegraphMarker`:** `lane_id`, `target_scale: float`, `refresh()`.
  - **`World`:** `closeup_sign`, `telegraph_markers: Dictionary`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_sign_and_telegraph.gd`:
```gdscript
extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(41)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_standing_on_sign_starts_night_after_hold() -> void:
	main.phase_controller.debug_skip_to_day()
	await TestHelpers.walk_in(main.hero, MapLayout.SIGN)
	var e := Balance.data.economy
	var still := int(ceil(e.stand_still_time * 60.0))
	var hold := int(ceil(ceil(e.closeup_hold / e.transfer_tick) * e.transfer_tick * 60.0))
	await _ticks(still + int(hold * 0.85))
	assert_eq(main.phase_controller.phase, Phase.DAY)
	await _ticks(int(hold * 0.3) + 2)
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_eq(main.phase_controller.snapshot.resume_phase, "DAY")

func test_hold_resets_when_leaving() -> void:
	main.phase_controller.debug_skip_to_day()
	await TestHelpers.walk_in(main.hero, MapLayout.SIGN)
	await _ticks(50)
	main.hero.teleport(Vector2(10, 8))
	await _ticks(5)
	await TestHelpers.walk_in(main.hero, MapLayout.SIGN)
	await _ticks(50)
	assert_eq(main.phase_controller.phase, Phase.DAY)

func test_restore_to_day_does_not_close_up() -> void:
	# D-121, D-122: the hero lands at HOME after a fail; with no input the day must not end.
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(7)
	main.phase_controller.close_up()
	GameState.damage_diner(1e9)
	await _ticks(int(Balance.ui.banner_time * 60) + 5)
	assert_eq(main.phase_controller.phase, Phase.DAY)
	assert_eq(main.hero.xz(), MapLayout.HOME)
	await _ticks(60 * 5)
	assert_eq(main.phase_controller.phase, Phase.DAY)
	assert_eq(GameState.gold, 7)

func test_pulse_follows_predicate() -> void:
	main.phase_controller.debug_skip_to_day()
	var s: CloseUpSign = main.world.closeup_sign
	assert_true(s.pulsing)
	GameState.add_freezer(1)
	assert_false(s.pulsing)

func test_telegraph_scales_and_visibility() -> void:
	var m: Dictionary = main.world.telegraph_markers
	for lane in m:
		assert_false(m[lane].visible, "hidden at night")
	main.phase_controller.debug_skip_to_day()
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp)
	var mx: float = threat.values().max()
	for lane in m:
		var expect := LanePlanner.marker_scale(threat[lane], mx, Balance.ui.telegraph_scale_min, Balance.ui.telegraph_scale_max)
		assert_almost_eq(m[lane].target_scale, expect, 0.0001)
		assert_eq(m[lane].visible, expect > 0.0)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`closeup_sign` is null).

- [ ] **Step 3: Implement**

`world/stations/closeup_sign.gd`:
```gdscript
class_name CloseUpSign
extends Node3D
## "Close up" sign (spec 5.6, 8.8, D-039, D-068). Hold 1 s standing still → closeup_requested.

var zone: StationZone
var hold := 0.0
var pulsing := false
var _visual: Node3D
var _phase := Phase.NIGHT
var _t := 0.0

func setup(_world: World) -> void:
	name = "CloseUpSign"
	position = MapLayout.to3(MapLayout.SIGN)
	_visual = Visuals.visual_root()
	var post := Visuals.cylinder(0.08, 1.6, Visuals.COLORS.counter)
	post.position.y = 0.8
	_visual.add_child(post)
	var board := Visuals.box(Vector3(1.4, 0.6, 0.1), Visuals.COLORS.sign)
	board.position.y = 1.7
	_visual.add_child(board)
	add_child(_visual)
	var l := WorldLabel.make(tr("Close up"), 36)
	l.position.y = 2.4
	add_child(l)
	zone = StationZone.new()
	zone.radius = MapLayout.STATION_RADIUS
	add_child(zone)
	zone.ticked.connect(_on_tick)
	zone.stand_ended.connect(_on_stand_ended)
	EventBus.stocks_changed.connect(refresh_pulse)
	EventBus.state_restored.connect(refresh_pulse)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.building_changed.connect(_on_building_changed)
	EventBus.phase_changed.connect(_on_phase_changed)

func _on_stand_ended() -> void:
	hold = 0.0
	zone.ring.set_progress(0.0)

func _on_gold_changed(_gold: int, _delta: int) -> void:
	refresh_pulse()

func _on_building_changed(_id: StringName, _level: int, _paid: int) -> void:
	refresh_pulse()

func _on_phase_changed(p: int, _day: int) -> void:
	_phase = p
	refresh_pulse()

func _on_tick() -> void:
	hold += Balance.data.economy.transfer_tick
	zone.ring.set_progress(hold / Balance.data.economy.closeup_hold)
	if hold >= Balance.data.economy.closeup_hold - 1e-6:
		hold = 0.0
		zone.ring.set_progress(0.0)
		EventBus.closeup_requested.emit()

func refresh_pulse() -> void:
	pulsing = _phase == Phase.DAY and not GameState.buildings.is_empty() and Pulse.should_pulse(GameState.to_dict(), Balance.data)
	if not pulsing:
		_visual.scale = Vector3.ONE

func _process(delta: float) -> void:
	if pulsing:
		_t += delta
		var k := 0.5 + 0.5 * sin(_t * TAU * Balance.ui.pulse_hz)
		_visual.scale = Vector3.ONE * lerpf(1.0, Balance.ui.pulse_scale, k)
```

`world/lanes/telegraph_marker.gd`:
```gdscript
class_name TelegraphMarker
extends Node3D
## Day-only threat marker near each lane's fence spot (D-029, D-093). Hidden when threat is 0.

var lane_id := ""
var target_scale := 0.0
var _phase := Phase.NIGHT

func setup(id: String) -> void:
	lane_id = id
	name = "Telegraph_" + id
	position = MapLayout.to3(MapLayout.telegraph_spot(id))
	var v := Visuals.visual_root()
	var cone := Visuals.cone(0.5, 1.2, Visuals.COLORS.telegraph)
	cone.position.y = 0.6
	v.add_child(cone)
	add_child(v)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_phase_changed(p: int, _day: int) -> void:
	_phase = p
	refresh()

func refresh() -> void:
	if GameState.lane_plan.is_empty():
		visible = false
		return
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp)
	var mx: float = threat.values().max()
	target_scale = LanePlanner.marker_scale(threat[lane_id], mx, Balance.ui.telegraph_scale_min, Balance.ui.telegraph_scale_max)
	visible = _phase == Phase.DAY and target_scale > 0.0
	if target_scale > 0.0:
		scale = Vector3.ONE * target_scale
```

Modify `world/world.gd`:
```gdscript
var closeup_sign: CloseUpSign
var telegraph_markers := {}

# append to _build_stations():
	closeup_sign = CloseUpSign.new()
	add_child(closeup_sign)
	closeup_sign.setup(self)
	for id in LanePlanner.LANES:
		var m := TelegraphMarker.new()
		add_child(m)
		m.setup(id)
		telegraph_markers[id] = m
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add world/stations/closeup_sign.gd world/lanes/telegraph_marker.gd world/world.gd tests/unit/test_sign_and_telegraph.gd
git commit -m "feat: add close-up sign with pulse and day lane telegraph"
```

---

## Phase 7: Economy, upgrades, PlannerBot, night-2 sims

### Task 25: `PlannerBot`, day and night-2 sims, and the sweep

**Files:**
- Create: `actors/bots/planner_bot.gd`, `tests/sim/test_day_sims.gd`, `tests/sim/sweep.gd`
- Test: `tests/unit/test_planner_choice.gd`

**Interfaces:**
- Consumes: everything from Tasks 19–24.
- Produces:
  - **`PlannerBot`** (extends `NaiveBot`): overrides `day_think`, and exposes `next_purchase() -> String` (a spot id, or `""`).
  - **`tests/sim/sweep.gd`** (SceneTree script) writes `tests/sim/out/sweep.csv` with the header `day,diner_frac,failed_retries,kills,steaks,gold_earned,builds,enemy_count,night_seconds,day_seconds,unspent_gold_at_closeup`.

- [ ] **Step 1: Write the failing unit test for the purchase order**

`tests/unit/test_planner_choice.gd`:
```gdscript
extends GutTest

var main: Main
var bot: PlannerBot

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	bot = PlannerBot.new()
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.start_new_game(51)
	GameState.advance_day()  # day-2 plan has side groups

func _side_lane() -> String:
	var side := {"west": 0.0, "north": 0.0, "east": 0.0}
	for w in GameState.lane_plan:
		side[w.side] += int(w.side_count) * float(w.hp_mult)
	var best := ""
	for l in LanePlanner.LANES:
		if best == "" or side[l] > side[best]:
			best = l
	return best

func test_first_buy_is_fence_on_top_side_lane() -> void:
	GameState.add_gold(100)
	assert_eq(bot.next_purchase(), MapLayout.LANE_FENCE[_side_lane()])

func test_then_adjacent_tower() -> void:
	GameState.add_gold(100)
	var fence: String = MapLayout.LANE_FENCE[_side_lane()]
	GameState.pay_into_spot(fence, 20)
	var t := bot.next_purchase()
	assert_true(t.begins_with("tower"))
	assert_true(_side_lane() in MapLayout.TOWER_LANES[t])

func test_nothing_if_unaffordable() -> void:
	GameState.add_gold(5)
	assert_eq(bot.next_purchase(), "")
```

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`PlannerBot` not declared).

- [ ] **Step 3: Implement `PlannerBot`**

`actors/bots/planner_bot.gd`:
```gdscript
class_name PlannerBot
extends NaiveBot
## NaiveBot at night; by day: haul and sell everything, collect gold, then build/upgrade by tonight's
## telegraph (spec 13.3, D-067), then close up.

func day_think(_delta: float) -> void:
	var cap := Balance.data.hero.carry_capacity
	var counter_cap := Balance.data.economy.counter_capacity
	# keep loading / unloading until the stack or the station is done
	if goal == "freezer" and GameState.freezer_steaks > 0 and GameState.carried_steaks < cap:
		return
	if goal == "counter_drop" and GameState.carried_steaks > 0 and GameState.counter_steaks < counter_cap:
		return
	if GameState.carried_steaks > 0 and GameState.counter_steaks < counter_cap:
		go_to("counter_drop")
	elif GameState.freezer_steaks > 0 and GameState.carried_steaks < cap:
		go_to("freezer")
	elif GameState.gold_pile > 0:
		go_to("gold_pile")
	elif GameState.counter_steaks > 0 or GameState.carried_steaks > 0:
		go_to("counter_drop")  # wait for travelers
	else:
		var spot := next_purchase()
		go_to(spot if spot != "" else "sign")

func next_purchase() -> String:
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp)
	var side := {"west": 0.0, "north": 0.0, "east": 0.0}
	for w in GameState.lane_plan:
		if String(w.side) != "":
			side[w.side] += int(w.side_count) * float(w.hp_mult)
	var lanes := LanePlanner.LANES.duplicate()
	lanes.sort_custom(func(a, b): return threat[a] > threat[b] or (threat[a] == threat[b] and LanePlanner.LANES.find(a) < LanePlanner.LANES.find(b)))
	var builds: Array = []
	var side_lane := ""
	for l in LanePlanner.LANES:
		if side[l] > 0.0 and (side_lane == "" or side[l] > side[side_lane]):
			side_lane = l
	if side_lane != "":
		builds.append(MapLayout.LANE_FENCE[side_lane])
		for t in ["tower_nw", "tower_ne"]:
			if side_lane in MapLayout.TOWER_LANES[t]:
				builds.append(t)
				break
	for l in lanes:
		if threat[l] > 0.0:
			builds.append(MapLayout.LANE_FENCE[l])
	for id in builds:
		if int(GameState.buildings[id].level) == 0 and GameState.remaining_cost(id) <= GameState.gold:
			return id
	var spot_threat := func(id: String) -> float:
		if MapLayout.spot_kind(id) == "fence":
			return threat[MapLayout.FENCE_LANE[id]]
		var s := 0.0
		for l in MapLayout.TOWER_LANES[id]:
			s += threat[l]
		return s
	var ups := MapLayout.SPOT_IDS.duplicate()
	ups.sort_custom(func(a, b): return spot_threat.call(a) > spot_threat.call(b) or (spot_threat.call(a) == spot_threat.call(b) and a < b))
	for id in ups:
		var lvl := int(GameState.buildings[id].level)
		if lvl >= 1 and spot_threat.call(id) > 0.0:
			var rem := GameState.remaining_cost(id)
			if rem >= 0 and rem <= GameState.gold:
				return id
	return ""
```

- [ ] **Step 4: Run the unit tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Write the day and night-2 sims**

`tests/sim/test_day_sims.gd`:
```gdscript
extends GutTest
## Spec 13.4 night-2 rows + day loop (D-058, D-103, D-105).

const SEED := 20260930
var h: SimHarness

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)

func after_each() -> void:
	h.finish()

func _night2(bot: GDScript, harness: SimHarness) -> Dictionary:
	harness.start(SEED, bot)
	var n1 := await harness.run_night()
	assert_true(n1.cleared, "night 1 must clear: %s" % n1)
	var d1 := await harness.run_day()
	assert_true(d1.closed, "day 1 must close up")
	var n2 := await harness.run_night()
	n2["day1_seconds"] = d1.seconds
	n2["builds"] = GameState.buildings.duplicate(true)
	return n2

func test_night2_naive_unaided_is_hard_and_deterministic() -> void:
	var r1 := await _night2(NaiveBot, h)
	gut.p("night2 naive: %s" % r1)
	assert_true(r1.failed or r1.diner_frac <= Balance.data.sim.night2_unaided_max, "diner %.2f" % r1.diner_frac)
	h.finish()
	await get_tree().process_frame
	Balance.reset()
	var h2 := SimHarness.new(self)
	var r2 := await _night2(NaiveBot, h2)
	h2.finish()
	assert_eq([r1.failed, r1.diner_frac, r1.kills], [r2.failed, r2.diner_frac, r2.kills], "same seed, same outcome")

func test_night2_planner_is_comfortable() -> void:
	var r := await _night2(PlannerBot, h)
	gut.p("night2 planner: %s" % r)
	var built := 0
	for id in r.builds:
		built += int(r.builds[id].level)
	assert_gt(built, 1, "day 1 yield bought at least a fence and a tower")
	assert_true(r.cleared, "night 2 must clear")
	assert_true(r.diner_frac >= Balance.data.sim.night2_comfort_min, "diner %.2f" % r.diner_frac)
```

- [ ] **Step 6: Write the sweep script**

`tests/sim/sweep.gd`:
```gdscript
extends SceneTree
## Manual difficulty sweep (D-059, D-066, D-067): PlannerBot days 1–10 → tests/sim/out/sweep.csv.
## "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd [-- --seed=N --days=10]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := {"seed": "20260930", "days": "10"}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	Balance.reset()
	var holder := Node.new()
	root.add_child(holder)
	var h := SimHarness.new(holder)
	h.start(int(args.seed), PlannerBot)
	var rows := ["day,diner_frac,failed_retries,kills,steaks,gold_earned,builds,enemy_count,night_seconds,day_seconds,unspent_gold_at_closeup"]
	var broke_at := -1
	for day in range(1, int(args.days) + 1):
		var retries := 0
		var enemy_count := Economy.night_kills(GameState.day, Balance.data.wave)
		var t0 := h.elapsed
		var n := await h.run_night()
		while n.failed and retries < 3:
			retries += 1
			await h.run_until(func(): return not h.main.phase_controller.failing, 5.0)
			if h.main.phase_controller.phase == Phase.DAY:
				await h.run_day()
			t0 = h.elapsed
			n = await h.run_night()
		var night_s := h.elapsed - t0
		if n.failed:
			broke_at = day
			rows.append("%d,%.3f,%d,%d,%d,%d,%s,%d,%.1f,,," % [day, n.diner_frac, retries, n.kills, n.kills * 2, 0, _builds(), enemy_count, night_s])
			break
		var d := await h.run_day()
		var steaks: int = n.kills * Balance.data.economy.steaks_per_kill
		rows.append("%d,%.3f,%d,%d,%d,%d,%s,%d,%.1f,%.1f,%d" % [day, n.diner_frac, retries, n.kills, steaks,
			steaks * Balance.data.economy.gold_per_steak, _builds(), enemy_count, night_s, d.seconds,
			int(h.main.phase_controller.snapshot.gold)])
	var out_dir := ProjectSettings.globalize_path("res://tests/sim/out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join("sweep.csv"), FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()
	print("\n".join(rows))
	print("SWEEP broke_at_day=%d" % broke_at)
	h.finish()
	quit(0)

func _builds() -> String:
	var parts: Array = []
	for id in MapLayout.SPOT_IDS:
		parts.append("%s:%d" % [id, int(GameState.buildings[id].level)])
	return "|".join(parts)
```

- [ ] **Step 7: Run the sims and the sweep**

Run: `./run_tests.sh sim`

Expected: exit 0, and `SIM SUITE` under 60 s.
- If the budget is exceeded, **stop and escalate** with the per-test timings (`gut` prints them). Don't drop tests.
- If a threshold fails, record the printed dictionaries and escalate. Tuning is Task 35 (D-103 priority order).

Run: `"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd`

Expected: the CSV rows print, then `SWEEP broke_at_day=<n>`, and `tests/sim/out/sweep.csv` exists. It is gitignored and not committed.

- [ ] **Step 8: Commit**

```bash
git add actors/bots/planner_bot.gd tests/sim/test_day_sims.gd tests/sim/sweep.gd tests/unit/test_planner_choice.gd
git commit -m "feat: add PlannerBot, night-2 sims and the difficulty sweep"
```

---

## Phase 8: Snapshot and restore

### Task 26: Full restore-contract test (D-036, D-045)

**Files:**
- Test: `tests/unit/test_restore_world.gd`
- Modify: whichever node fails the test, and only to make it rebuild from GameState on `state_restored`.

**Interfaces:**
- Consumes: `PhaseController.snapshot/_restore_snapshot()` and every stateful node's public fields from Tasks 18–24.

- [ ] **Step 1: Write the test**

`tests/unit/test_restore_world.gd`:
```gdscript
extends GutTest
## Snapshot → mutate everything → restore → world matches snapshot, no pending transactions (spec 13.2).

var main: Main
var pc: PhaseController

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	pc = main.phase_controller
	pc.start_new_game(61)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_restore_rebuilds_world_from_snapshot() -> void:
	pc.debug_skip_to_day()
	GameState.add_gold(1000)
	GameState.pay_into_spot("tower_nw", GameState.next_level_cost("tower_nw"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n") - 5)  # leaves 5 to pay
	GameState.add_freezer(4)
	pc.close_up()  # snapshot (resume DAY), now NIGHT
	var snap: Dictionary = pc.snapshot.duplicate(true)
	# mutate everything
	pc.debug_skip_to_day()
	GameState.add_gold(500)
	GameState.pay_into_spot("tower_ne", GameState.next_level_cost("tower_ne"))
	GameState.pay_into_spot("fence_n", 5)
	GameState.damage_diner(40.0)
	GameState.add_freezer(9)
	GameState.move_freezer_to_carry(3)
	GameState.counter_steaks = 7
	GameState.gold_pile = 12
	GameState.advance_day()
	for i in 5:
		main.world.steak_pool.acquire().place(Vector3(15, 0, 0))
	main.world.wave_director.debug_spawn("west")
	main.world.projectile_pool.acquire()
	main.hero.teleport(Vector2(15, 8))  # away from every station zone while we wait
	await _ticks(60 * 12)  # travelers arrive; one is mid-service
	# restore
	pc.snapshot = snap
	pc._restore_snapshot()
	# state
	var now := GameState.to_dict()
	assert_eq(now, snap)
	# world items and in-flight state
	for pool in main.find_children("*", "NodePool", true, false):
		assert_eq(pool.active().size(), 0, "pool %s not empty" % pool.name)
	assert_eq(main.world.traveler_spawner.queue.size(), 0)
	assert_eq(main.world.traveler_spawner.leaving.size(), 0)
	assert_eq(main.world.wave_director.alive_count(), 0)
	# nodes rebuilt from GameState
	var spots: Dictionary = main.world.build_spots
	assert_eq(spots.tower_nw.level, 1)
	assert_true(spots.tower_nw.attacker.enabled)
	assert_eq(spots.tower_ne.level, 0)
	assert_false(spots.tower_ne.attacker.enabled)
	assert_eq(spots.fence_n.label.text, "5")
	assert_eq(main.world.freezer.label.text, str(snap.freezer_steaks))
	assert_eq(main.world.counter.label.text, str(snap.counter_steaks))
	assert_eq(main.world.gold_pile.coin_count(), int(snap.gold_pile))
	assert_eq(main.hero.carry_stack.visible_count(), int(snap.carried_steaks))
	assert_eq(main.hero.xz(), MapLayout.HOME)
	assert_eq(pc.phase, Phase.DAY)
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp)
	var mx: float = threat.values().max()
	for lane in main.world.telegraph_markers:
		var expect := LanePlanner.marker_scale(threat[lane], mx, Balance.ui.telegraph_scale_min, Balance.ui.telegraph_scale_max)
		assert_almost_eq(main.world.telegraph_markers[lane].target_scale, expect, 0.0001)
```

- [ ] **Step 2: Run it**

Run: `./run_tests.sh unit`

Expected: PASS if Tasks 18–24 honored D-036. If it fails, the failing assertion names the node holding hidden state. Fix **only** that node so it rebuilds from GameState in its `state_restored` handler, then re-run until it passes.

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_restore_world.gd   # plus every node file you fixed in Step 2
git commit -m "test: pin the full snapshot restore contract"
```

---
## Phase 9: Input, camera, HUD, feel

### Task 27: Floating `Joystick`

**Files:**
- Create: `ui/joystick/joystick.gd`
- Modify: `world/main.gd`
- Test: `tests/unit/test_joystick.gd`

**Interfaces:**
- Consumes: `HeroInput.set_move`, and `Balance.ui` (`joystick_radius_px`, `joystick_deadzone`, `edge_ignore_px`).
- Produces:
  - **`Joystick`** (Control):
    - `setup(input: HeroInput)`
    - `handle(event: InputEvent)`, which is called from `_input` and public so tests can drive it
    - `is_active() -> bool`, `active_index: int` (−2 none, −1 mouse, ≥ 0 touch)
  - **`Main`:** `joystick: Joystick`, inside a `CanvasLayer` named `InputLayer`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_joystick.gd`:
```gdscript
extends GutTest

var input: HeroInput
var js: Joystick

func before_each() -> void:
	Balance.reset()
	input = HeroInput.new()
	input.player_control = false
	add_child_autofree(input)
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	js = Joystick.new()
	layer.add_child(js)
	js.setup(input)

func _touch(i: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = pressed
	js.handle(e)

func _drag(i: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	js.handle(e)

func test_drag_moves_full_right() -> void:
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(360 + 64, 900))
	assert_almost_eq(input.get_move().x, 1.0, 0.001)
	_drag(0, Vector2(360 + 200, 900))
	assert_almost_eq(input.get_move().length(), 1.0, 0.001, "clamped to radius")

func test_up_is_north() -> void:
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(360, 900 - 64))
	assert_almost_eq(input.get_move().y, -1.0, 0.001)

func test_deadzone() -> void:
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(365, 900))
	assert_eq(input.get_move(), Vector2.ZERO)

func test_release_stops() -> void:
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(424, 900))
	_touch(0, Vector2(424, 900), false)
	assert_eq(input.get_move(), Vector2.ZERO)
	assert_false(js.is_active())

func test_second_finger_ignored() -> void:
	# Review Focus 4
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(424, 900))
	_touch(1, Vector2(200, 400), true)
	_drag(1, Vector2(100, 400))
	_touch(1, Vector2(100, 400), false)
	assert_true(js.is_active())
	assert_almost_eq(input.get_move().x, 1.0, 0.001)

func test_edge_strip_touch_ignored() -> void:
	# Review Focus 4
	_touch(0, Vector2(8, 900), true)
	assert_false(js.is_active())
	var w := js.get_viewport_rect().size.x
	_touch(1, Vector2(w - 8, 900), true)
	assert_false(js.is_active())

func test_mouse_drag_works() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(360, 900)
	js.handle(down)
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(360, 964)
	js.handle(mv)
	assert_almost_eq(input.get_move().y, 1.0, 0.001)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`Joystick` not declared).

- [ ] **Step 3: Implement**

`ui/joystick/joystick.gd`:
```gdscript
class_name Joystick
extends Control
## Floating one-thumb joystick (D-015, D-070, D-077). Screen up = north. Ignores edge strips and extra fingers.

var active_index := -2
var _input_api: HeroInput
var _base := Vector2.ZERO
var _knob := Vector2.ZERO

func setup(input: HeroInput) -> void:
	_input_api = input

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	handle(event)

func is_active() -> bool:
	return active_index != -2

func handle(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not is_active() and _allowed(event.position):
				_begin(event.index, event.position)
		elif event.index == active_index:
			_end()
	elif event is InputEventScreenDrag:
		if event.index == active_index:
			_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not is_active() and _allowed(event.position):
				_begin(-1, event.position)
		elif active_index == -1:
			_end()
	elif event is InputEventMouseMotion and active_index == -1:
		_drag(event.position)

func _allowed(p: Vector2) -> bool:
	var w := get_viewport_rect().size.x
	var e := Balance.ui.edge_ignore_px
	return p.x >= e and p.x <= w - e

func _begin(i: int, p: Vector2) -> void:
	active_index = i
	_base = p
	_knob = Vector2.ZERO
	_input_api.set_move(Vector2.ZERO)
	queue_redraw()

func _drag(p: Vector2) -> void:
	var r := Balance.ui.joystick_radius_px
	_knob = (p - _base).limit_length(r)
	var v := _knob / r
	_input_api.set_move(Vector2.ZERO if v.length() < Balance.ui.joystick_deadzone else v)
	queue_redraw()

func _end() -> void:
	active_index = -2
	_knob = Vector2.ZERO
	_input_api.set_move(Vector2.ZERO)
	queue_redraw()

func _draw() -> void:
	if not is_active():
		return
	var r := Balance.ui.joystick_radius_px
	draw_circle(_base, r, Color(1, 1, 1, 0.18))
	draw_circle(_base + _knob, r * 0.45, Color(1, 1, 1, 0.55))
```

Modify `world/main.gd`:
```gdscript
var joystick: Joystick

# in _ready(), after hero setup:
	var input_layer := CanvasLayer.new()
	input_layer.name = "InputLayer"
	input_layer.layer = 5
	add_child(input_layer)
	joystick = Joystick.new()
	input_layer.add_child(joystick)
	joystick.setup(hero.input)
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add ui/joystick world/main.gd tests/unit/test_joystick.gd
git commit -m "feat: add floating joystick with edge strips and single-finger control"
```

### Task 28: `CameraRig` (follow and shake)

**Files:**
- Create: `world/camera_rig.gd`
- Modify: `world/main.gd`
- Test: `tests/unit/test_camera_rig.gd`

**Interfaces:**
- Consumes: `CameraMath.focus_for/camera_transform`, `Balance.ui` camera and shake fields, `EventBus.diner_damaged`.
- Produces:
  - **`CameraRig`** (Node3D): `camera: Camera3D`, `setup(hero: Hero)`, `shake_count: int` (test hook), `snap()`.
  - **`Main`:** `camera_rig: CameraRig`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_camera_rig.gd`:
```gdscript
extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(71)

func test_camera_uses_keep_width_and_fov() -> void:
	var cam := main.camera_rig.camera
	assert_eq(cam.keep_aspect, Camera3D.KEEP_WIDTH)
	assert_eq(cam.fov, Balance.ui.camera_fov_h)
	assert_true(cam.current)

func test_snap_matches_camera_math() -> void:
	main.hero.teleport(Vector2(3, -2))
	main.camera_rig.snap()
	var expect := CameraMath.camera_transform(CameraMath.focus_for(Vector2(3, -2)), Balance.ui)
	assert_true(main.camera_rig.camera.global_transform.is_equal_approx(expect))

func test_shake_has_cooldown() -> void:
	GameState.damage_diner(5.0)
	GameState.damage_diner(5.0)
	assert_eq(main.camera_rig.shake_count, 1)
	for i in 40:
		await get_tree().process_frame
	GameState.damage_diner(5.0)
	assert_eq(main.camera_rig.shake_count, 2)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`camera_rig` is null).

- [ ] **Step 3: Implement**

`world/camera_rig.gd`:
```gdscript
class_name CameraRig
extends Node3D
## Follow camera (D-071, D-090, D-112). Uses CameraMath so tests and game agree. Visual only (_process).

var camera: Camera3D
var shake_count := 0
var _hero: Hero
var _focus := Vector2.ZERO
var _shake_left := 0.0
var _cooldown := 0.0
var _t := 0.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = Balance.ui.camera_fov_h
	camera.near = CameraMath.Z_NEAR
	camera.far = CameraMath.Z_FAR
	add_child(camera)
	camera.current = true
	EventBus.diner_damaged.connect(_on_diner_damaged)

func setup(hero: Hero) -> void:
	_hero = hero
	snap()

func snap() -> void:
	_focus = CameraMath.focus_for(_hero.xz())
	camera.global_transform = CameraMath.camera_transform(_focus, Balance.ui)

func _process(delta: float) -> void:
	if _hero == null:
		return
	_t += delta
	_cooldown -= delta
	var goal := CameraMath.focus_for(_hero.xz())
	_focus = _focus.lerp(goal, 1.0 - exp(-Balance.ui.camera_follow_rate * delta))
	var xf := CameraMath.camera_transform(_focus, Balance.ui)
	if _shake_left > 0.0:
		_shake_left -= delta
		var k := maxf(_shake_left, 0.0) / Balance.ui.shake_time
		xf.origin += Vector3(sin(_t * 97.0), cos(_t * 89.0), 0.0) * Balance.ui.shake_amp * k
	camera.global_transform = xf

func _on_diner_damaged(_amount: float, _hp_left: float) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = Balance.ui.shake_cooldown
	_shake_left = Balance.ui.shake_time
	shake_count += 1
```

Modify `world/main.gd`:
```gdscript
var camera_rig: CameraRig

# in _ready(), after hero setup:
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup(hero)
```

The camera follows placements through the bus, so PhaseController needs no camera reference (D-128). Add to `world/camera_rig.gd`:
```gdscript
# in _ready():
	EventBus.hero_place_requested.connect(snap_to)

func snap_to(p: Vector2) -> void:
	_focus = CameraMath.focus_for(p)
	camera.global_transform = CameraMath.camera_transform(_focus, Balance.ui)
```

Modify `tests/sim/capture.gd`: delete the manual `Camera3D` block and use `main.camera_rig.snap()` before capturing.

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh all`

Expected: exit 0. Run `all` because `capture.gd` changed.

- [ ] **Step 5: Commit**

```bash
git add world/camera_rig.gd world/main.gd tests/sim/capture.gd tests/unit/test_camera_rig.gd
git commit -m "feat: add follow camera rig with capped diner-hit shake"
```

### Task 29: `Hud` and `SafeArea`

**Files:**
- Create: `ui/hud/hud.gd`, `ui/hud/safe_area.gd`
- Modify: `world/main.gd`
- Test: `tests/unit/test_hud.gd`

**Interfaces:**
- Consumes: `EventBus` (`gold_changed`, `phase_changed`, `wave_incoming`, `wave_spawned_out`, `wave_cleared`, `diner_damaged`, `state_restored`, `banner_requested`), `CameraRig.camera`, `World.lanes`, and `Balance.ui` (`gold_punch_*`, `banner_time`).
- Produces:
  - **`Hud`** (CanvasLayer): `setup(main: Main)`, `root: Control`, `gold_label: Label`, `day_label: Label`, `moons: Array` (ColorRect), `diner_bar: ProgressBar`, `banner: Label`, `arrows: Dictionary` (`"main"`/`"side"` → Polygon2D), `filled_moons() -> int`.
  - **`SafeArea.insets(viewport_size: Vector2) -> Dictionary`** returns `{top, bottom, left, right}` in viewport px, all ≥ 0.
  - **`Main`:** `hud: Hud`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_hud.gd`:
```gdscript
extends GutTest

var main: Main
var hud: Hud

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(81)
	hud = main.hud

func test_gold_label_follows_gold() -> void:
	GameState.add_gold(42)
	assert_eq(hud.gold_label.text, "42")

func test_moons_fill_and_reset() -> void:
	EventBus.wave_cleared.emit(0)
	EventBus.wave_cleared.emit(1)
	assert_eq(hud.filled_moons(), 2)
	EventBus.phase_changed.emit(Phase.NIGHT, 2)
	assert_eq(hud.filled_moons(), 0)

func test_day_label_and_moons_visibility() -> void:
	main.phase_controller.debug_skip_to_day()
	assert_true(hud.day_label.visible)
	assert_eq(hud.day_label.text, "Day 2")
	assert_false(hud.moons[0].visible)

func test_diner_bar() -> void:
	var max_hp := Balance.data.build.diner_max_hp
	GameState.damage_diner(30.0)
	assert_almost_eq(hud.diner_bar.value, max_hp - 30.0, 0.001)
	GameState.from_dict(main.phase_controller.snapshot)
	assert_almost_eq(hud.diner_bar.value, max_hp, 0.001)

func test_banner_shows_then_hides() -> void:
	EventBus.banner_requested.emit("Dawn")
	assert_true(hud.banner.visible)
	assert_eq(hud.banner.text, "Dawn")
	for i in int(Balance.ui.banner_time * 60) + 30:
		await get_tree().process_frame
	assert_false(hud.banner.visible)

func test_arrows_follow_wave_events_and_stay_on_screen() -> void:
	EventBus.wave_incoming.emit(1, &"west", &"east")
	await get_tree().process_frame
	assert_true(hud.arrows.main.visible)
	assert_true(hud.arrows.side.visible)
	var rect := hud.root.get_viewport_rect()
	assert_true(rect.has_point(hud.arrows.main.position))
	assert_lt(hud.arrows.side.scale.x, hud.arrows.main.scale.x)
	EventBus.wave_spawned_out.emit(1)
	assert_false(hud.arrows.main.visible)

func test_safe_area_insets_non_negative_and_applied() -> void:
	var ins := SafeArea.insets(Vector2(720, 1280))
	for k in ["top", "bottom", "left", "right"]:
		assert_true(float(ins[k]) >= 0.0, k)
	assert_eq(hud.root.offset_top, float(ins.top))
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`hud` is null).

- [ ] **Step 3: Implement**

`ui/hud/safe_area.gd`:
```gdscript
class_name SafeArea
extends RefCounted
## Safe-area insets in viewport pixels (D-077). Source per spike D-119: DisplayServer, CSS env() on web.

const CSS_JS := "(function(){var d=document.createElement('div');d.style.cssText='position:fixed;top:0;left:0;visibility:hidden;padding-top:env(safe-area-inset-top);padding-right:env(safe-area-inset-right);padding-bottom:env(safe-area-inset-bottom);padding-left:env(safe-area-inset-left)';document.body.appendChild(d);var s=getComputedStyle(d);var r=[s.paddingTop,s.paddingRight,s.paddingBottom,s.paddingLeft].map(parseFloat).concat([window.innerWidth,window.innerHeight]).join(',');d.remove();return r;})()"

static func insets(viewport_size: Vector2) -> Dictionary:
	var out := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if OS.has_feature("web"):
		var raw := str(JavaScriptBridge.eval(CSS_JS, true)).split(",")
		if raw.size() == 6 and float(raw[5]) > 0.0:
			var sx := viewport_size.x / float(raw[4])
			var sy := viewport_size.y / float(raw[5])
			out = {"top": float(raw[0]) * sy, "right": float(raw[1]) * sx, "bottom": float(raw[2]) * sy, "left": float(raw[3]) * sx}
		return _clamped(out)
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0:
		return out
	var sx2 := viewport_size.x / win.x
	var sy2 := viewport_size.y / win.y
	var wpos := Vector2(DisplayServer.window_get_position())
	out.top = (safe.position.y - wpos.y) * sy2
	out.left = (safe.position.x - wpos.x) * sx2
	out.bottom = (wpos.y + win.y - safe.end.y) * sy2
	out.right = (wpos.x + win.x - safe.end.x) * sx2
	return _clamped(out)

static func _clamped(d: Dictionary) -> Dictionary:
	for k in d:
		d[k] = maxf(float(d[k]), 0.0)
	return d
```

If D-119 recorded that DisplayServer works on web, delete the `if OS.has_feature("web")` branch and note it in the commit message.

`ui/hud/hud.gd`:
```gdscript
class_name Hud
extends CanvasLayer
## Listener-only HUD (spec 9.4). Gold, moons/day, diner bar, banners, edge arrows, safe-area inset.

var root: Control
var gold_label: Label
var day_label: Label
var moons: Array = []
var diner_bar: ProgressBar
var banner: Label
var arrows := {}
var _camera: Camera3D
var _lanes := {}
var _arrow_lane := {"main": "", "side": ""}
var _filled := 0
var _banner_tween: Tween
var _gold_tween: Tween

func setup(main: Main) -> void:
	_camera = main.camera_rig.camera
	_lanes = main.world.lanes

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var ins := SafeArea.insets(root.get_viewport_rect().size)
	root.offset_top = ins.top
	root.offset_bottom = -ins.bottom
	root.offset_left = ins.left
	root.offset_right = -ins.right
	gold_label = _label(48, Vector2(24, 16))
	gold_label.pivot_offset = Vector2(0, 30)
	day_label = _label(40, Vector2(300, 16))
	for i in 3:
		var m := ColorRect.new()
		m.size = Vector2(28, 28)
		m.position = Vector2(300 + i * 40, 24)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(m)
		moons.append(m)
	diner_bar = ProgressBar.new()
	diner_bar.show_percentage = false
	diner_bar.position = Vector2(220, 70)
	diner_bar.size = Vector2(280, 14)
	diner_bar.max_value = Balance.data.build.diner_max_hp
	diner_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(diner_bar)
	banner = _label(64, Vector2(0, 520))
	banner.size = Vector2(720, 90)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.visible = false
	for key in ["main", "side"]:
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([Vector2(-20, -16), Vector2(20, -16), Vector2(0, 20)])
		p.color = Color("e03030")
		p.scale = Vector2.ONE if key == "main" else Vector2.ONE * 0.6
		p.visible = false
		root.add_child(p)
		arrows[key] = p
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.wave_incoming.connect(_on_wave_incoming)
	EventBus.wave_spawned_out.connect(_on_wave_spawned_out)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.diner_damaged.connect(_on_diner_damaged)
	EventBus.state_restored.connect(_refresh_all)
	EventBus.banner_requested.connect(_on_banner)
	_refresh_all()

func _label(size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l

func filled_moons() -> int:
	return _filled

func _refresh_all() -> void:
	gold_label.text = str(GameState.gold)
	diner_bar.value = GameState.diner_hp
	day_label.text = tr("Day %d") % GameState.day

func _on_gold_changed(gold: int, _delta: int) -> void:
	gold_label.text = str(gold)
	if _gold_tween != null and _gold_tween.is_valid():
		_gold_tween.kill()
	gold_label.scale = Vector2.ONE * Balance.ui.gold_punch_scale
	_gold_tween = create_tween()
	_gold_tween.tween_property(gold_label, "scale", Vector2.ONE, Balance.ui.gold_punch_time)

func _on_phase_changed(phase: int, day: int) -> void:
	var night := phase == Phase.NIGHT
	for m in moons:
		m.visible = night
	day_label.visible = not night
	day_label.text = tr("Day %d") % day
	diner_bar.value = GameState.diner_hp
	if night:
		_filled = 0
		_paint_moons()

func _on_wave_cleared(w: int) -> void:
	_filled = clampi(w + 1, 0, 3)
	_paint_moons()

func _paint_moons() -> void:
	for i in moons.size():
		moons[i].color = Color("ffe066") if i < _filled else Color(0.25, 0.25, 0.35)

func _on_wave_incoming(_w: int, main_lane: StringName, side_lane: StringName) -> void:
	_arrow_lane.main = String(main_lane)
	_arrow_lane.side = String(side_lane)
	arrows.main.visible = _arrow_lane.main != ""
	arrows.side.visible = _arrow_lane.side != ""
	_place_arrows()

func _on_wave_spawned_out(_w: int) -> void:
	arrows.main.visible = false
	arrows.side.visible = false

func _on_diner_damaged(_amount: float, hp_left: float) -> void:
	diner_bar.value = hp_left
	var t := create_tween()
	var base := Vector2(220, 70)
	t.tween_property(diner_bar, "position", base + Vector2(6, 0), 0.04)
	t.tween_property(diner_bar, "position", base, 0.04)

func _on_banner(text: String) -> void:
	banner.text = text
	banner.visible = true
	banner.modulate.a = 1.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(Balance.ui.banner_time * 0.75)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, Balance.ui.banner_time * 0.25)
	_banner_tween.tween_callback(func(): banner.visible = false)

func _process(_delta: float) -> void:
	_place_arrows()

func _place_arrows() -> void:
	if _camera == null:
		return
	var rect := root.get_viewport_rect().grow(-48.0)
	for key in ["main", "side"]:
		var arrow: Polygon2D = arrows[key]
		var lane: String = _arrow_lane[key]
		if not arrow.visible or lane == "" or not _lanes.has(lane):
			continue
		var world_pos: Vector3 = _lanes[lane].entrance_position()
		var p := _camera.unproject_position(world_pos)
		if _camera.is_position_behind(world_pos):
			p = rect.get_center() - (p - rect.get_center())
		if rect.has_point(p):
			arrow.position = p + Vector2(0, -40)
			arrow.rotation = 0.0
		else:
			var c := rect.get_center()
			var dir := (p - c).normalized()
			var tx := INF if is_zero_approx(dir.x) else ((rect.end.x if dir.x > 0 else rect.position.x) - c.x) / dir.x
			var ty := INF if is_zero_approx(dir.y) else ((rect.end.y if dir.y > 0 else rect.position.y) - c.y) / dir.y
			arrow.position = c + dir * minf(tx, ty)
			arrow.rotation = dir.angle() - PI / 2.0
```

`tween_callback(func(): banner.visible = false)` is a single-expression lambda (an assignment on a single line), which GDScript allows.

Modify `world/main.gd`:
```gdscript
var hud: Hud

# in _ready(), after camera_rig:
	hud = Hud.new()
	hud.name = "Hud"
	hud.setup(self)
	add_child(hud)
```

`setup` runs before `add_child`, so `_camera` and `_lanes` are set when `_ready` places the arrows.

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add ui/hud world/main.gd tests/unit/test_hud.gd
git commit -m "feat: add HUD with gold punch, moons, diner bar, banners, edge arrows and safe area"
```

### Task 30: Feel budget (`FlyFx` arcs, build pop, hit flash)

**Files:**
- Create: `world/fx/fly_fx.gd`
- Modify:
  - `world/world.gd`
  - `world/stations/freezer.gd`, `world/stations/counter.gd`
  - `world/build_spots/build_spot.gd`
  - `components/magnet.gd`
  - `world/traveler_spawner.gd`
  - `actors/enemy/boar.gd`
- Test: `tests/unit/test_fx.gd`

**Interfaces:**
- Consumes: `World.fx_pool` (32 prewarmed), `Balance.ui.transfer_arc_*`, `build_pop_*`, `hit_flash_time`.
- Produces:
  - **`FlyFx`** (Node): `setup(pool: NodePool)`, `fly(kind: String, from: Vector3, to: Vector3)`, where kind is `"steak"` or `"coin"`, and `in_flight() -> int`. It never touches GameState.
  - **`World`:** `fx_pool`, `fly_fx`.
  - **`Magnet`:** `setup(steak_pool: NodePool, fly_fx: FlyFx = null)`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_fx.gd`:
```gdscript
extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(91)

func test_fly_is_visual_only_and_releases() -> void:
	var before := GameState.to_dict()
	main.world.fly_fx.fly("coin", Vector3(0, 1, 0), Vector3(3, 1, 0))
	assert_eq(main.world.fly_fx.in_flight(), 1)
	for i in 30:
		await get_tree().process_frame
	assert_eq(main.world.fly_fx.in_flight(), 0)
	assert_eq(GameState.to_dict(), before)

func test_freezer_transfer_spawns_fly() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.add_freezer(3)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	for i in 25:
		await get_tree().physics_frame
	assert_gt(GameState.carried_steaks, 0, "FX hooks never break the transfer")

func test_build_pop_overshoots() -> void:
	var s: BuildSpot = main.world.build_spots.fence_w
	GameState.add_gold(GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	await get_tree().process_frame
	assert_gt(s.visual.scale.x, 1.0)
	for i in 30:
		await get_tree().process_frame
	assert_almost_eq(s.visual.scale.x, 1.0, 0.01)

func test_hit_flash() -> void:
	var b := main.world.wave_director.debug_spawn("north", 0.0, 10.0)
	b.take_hit(1.0)
	assert_eq(b.flash_active(), true)
	for i in 12:
		await get_tree().physics_frame
	assert_eq(b.flash_active(), false)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`fly_fx` is null).

- [ ] **Step 3: Implement**

`world/fx/fly_fx.gd`:
```gdscript
class_name FlyFx
extends Node
## Visual-only transfer arcs (D-078). Never reads or writes GameState.

class FxItem:
	extends Node3D
	func on_release() -> void:
		if has_meta(&"tween"):
			var tw: Tween = get_meta(&"tween")
			if tw != null and tw.is_valid():
				tw.kill()
			remove_meta(&"tween")

var _pool: NodePool

static func make_item() -> Node3D:
	var n := FxItem.new()
	n.name = "Fx"
	n.add_child(Visuals.box(Vector3(0.25, 0.12, 0.2), Visuals.COLORS.coin))
	return n

func setup(pool: NodePool) -> void:
	_pool = pool

func in_flight() -> int:
	return _pool.active().size()

func fly(kind: String, from: Vector3, to: Vector3) -> void:
	var n: Node3D = _pool.acquire()
	var mesh: MeshInstance3D = n.get_child(0)
	mesh.material_override = Visuals.material(Visuals.COLORS.coin if kind == "coin" else Visuals.COLORS.steak)
	n.position = from
	var apex := Balance.ui.transfer_arc_apex
	var tw := n.create_tween()
	n.set_meta(&"tween", tw)
	tw.tween_method(func(t: float): n.position = from.lerp(to, t) + Vector3.UP * apex * 4.0 * t * (1.0 - t), 0.0, 1.0, Balance.ui.transfer_arc_time)
	tw.tween_callback(_pool.release.bind(n))
```

The item's `on_release()` kills a running tween, so a restore mid-flight never releases a reused item. `n.position = ...` inside the `tween_method` lambda is a single assignment expression, which is valid.

Modify `world/world.gd`:
```gdscript
@export var fx_pool: NodePool
var fly_fx: FlyFx

# in _setup_pools(), after projectile_pool:
	fx_pool.setup(func(): return FlyFx.make_item(), sizes.fx)
	fly_fx = FlyFx.new()
	fly_fx.name = "FlyFx"
	add_child(fly_fx)
	fly_fx.setup(fx_pool)
```

Modify `world/phase_controller.gd`:
```gdscript
@export var fx_pool: NodePool

# _recall_all(): add
	fx_pool.recall_all()
```

Add the FxPool node and wire it into World and PhaseController

`world/main.tscn` (full content at this stage):
```
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://world/main.gd" id="1_main"]
[ext_resource type="Script" path="res://world/world.gd" id="2_world"]
[ext_resource type="Script" path="res://components/node_pool.gd" id="3_pool"]
[ext_resource type="Script" path="res://world/wave_director.gd" id="4_wave"]
[ext_resource type="Script" path="res://world/phase_controller.gd" id="5_phase"]
[ext_resource type="Script" path="res://world/traveler_spawner.gd" id="6_spawner"]

[node name="Main" type="Node3D" node_paths=PackedStringArray("world", "phase_controller")]
script = ExtResource("1_main")
world = NodePath("World")
phase_controller = NodePath("PhaseController")

[node name="World" type="Node3D" parent="." node_paths=PackedStringArray("enemy_pool", "steak_pool", "projectile_pool", "fx_pool", "wave_director", "traveler_pool", "traveler_spawner")]
script = ExtResource("2_world")
enemy_pool = NodePath("EnemyPool")
steak_pool = NodePath("SteakPool")
projectile_pool = NodePath("ProjectilePool")
fx_pool = NodePath("FxPool")
wave_director = NodePath("WaveDirector")
traveler_pool = NodePath("TravelerPool")
traveler_spawner = NodePath("TravelerSpawner")

[node name="EnemyPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="SteakPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="ProjectilePool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="FxPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="WaveDirector" type="Node" parent="World"]
script = ExtResource("4_wave")

[node name="TravelerPool" type="Node" parent="World"]
script = ExtResource("3_pool")

[node name="TravelerSpawner" type="Node" parent="World"]
script = ExtResource("6_spawner")

[node name="PhaseController" type="Node" parent="." node_paths=PackedStringArray("wave_director", "enemy_pool", "steak_pool", "projectile_pool", "fx_pool", "traveler_spawner")]
script = ExtResource("5_phase")
wave_director = NodePath("../World/WaveDirector")
enemy_pool = NodePath("../World/EnemyPool")
steak_pool = NodePath("../World/SteakPool")
projectile_pool = NodePath("../World/ProjectilePool")
fx_pool = NodePath("../World/FxPool")
traveler_spawner = NodePath("../World/TravelerSpawner")
```

The hooks are visual only, and each is added right after the state call it decorates:

- `Freezer._on_tick()`:
  ```gdscript
  if GameState.move_freezer_to_carry(1) > 0:
  	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
  	(get_parent() as World).fly_fx.fly("steak", MapLayout.to3(MapLayout.FREEZER, 1.6), hero.global_position + Vector3(0, 1.2, 0.5))
  ```
- `Counter._on_tick()`:
  ```gdscript
  if GameState.move_carry_to_counter(1) > 0:
  	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
  	(get_parent() as World).fly_fx.fly("steak", hero.global_position + Vector3(0, 1.2, 0.5), MapLayout.to3(MapLayout.COUNTER, 1.2))
  ```
- `TravelerSpawner`, after `GameState.sell_from_counter(front.want)` succeeds (it returns the sold count):
  ```gdscript
  var sold := GameState.sell_from_counter(front.want)
  if sold > 0:
  	(get_parent() as World).fly_fx.fly("coin", MapLayout.to3(MapLayout.SERVICE_POINT, 1.2), MapLayout.to3(MapLayout.GOLD_PILE, 0.3))
  ```
- `Magnet`: store `_fx: FlyFx` from `setup(steak_pool, fly_fx)`. After a successful `pick_steak()`, call `_fx.fly("steak", s.position, owner3d.global_position + Vector3(0, 1.2, 0.5))`. After a nonzero `collect_pile()`, call `_fx.fly("coin", MapLayout.to3(MapLayout.GOLD_PILE, 0.3), owner3d.global_position + Vector3(0, 1.2, 0))`. Each is guarded by `if _fx != null`. Update `Hero.setup()` to pass `world.fly_fx`.
- `BuildSpot`:
  - After `_on_tick()` paid > 0: `_world.fly_fx.fly("coin", hero.global_position + Vector3(0, 1.2, 0), global_position + Vector3(0, 1.0, 0))`.
  - Connect `EventBus.build_completed` to `_on_build_completed(id, _level)`. When `String(id) == spot_id`:
    ```gdscript
    var base := visual.scale
    visual.scale = base * Balance.ui.build_pop_scale
    create_tween().tween_property(visual, "scale", base, Balance.ui.build_pop_time)
    ```
    Because `refresh()` sets `visual.scale` from the level first, connect `build_completed` **after** `building_changed`, so the pop starts from the new level's scale.
- `Boar`: add `var _flash_left := 0.0`.
  - In `take_hit`, when alive: `_mesh.material_override = Visuals.material(Visuals.COLORS.flash)` and `_flash_left = Balance.ui.hit_flash_time`.
  - At the top of `_physics_process`, before the `alive` check:
    ```gdscript
    if _flash_left > 0.0:
    	_flash_left -= delta
    	if _flash_left <= 0.0:
    		_mesh.material_override = Visuals.material(Visuals.COLORS.boar)
    ```
  - Add `func flash_active() -> bool: return _flash_left > 0.0`.
  - In `on_release()` and `spawn()`, reset `_flash_left = 0.0` and the boar material.

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh all`

Expected: exit 0, and the sims still pass (the FX never change state).

- [ ] **Step 5: Commit**

```bash
git add world actors components tests/unit/test_fx.gd
git commit -m "feat: add visual-only transfer arcs, build pop and hit flash"
```

### Task 31: `FocusPause`

**Files:**
- Create: `world/focus_pause.gd`
- Modify: `world/main.gd`
- Test: `tests/unit/test_focus_pause.gd`

**Interfaces:**
- Produces:
  - **`FocusPause`** (Node, `PROCESS_MODE_ALWAYS`): `set_paused(p: bool)`.
  - It reacts to `NOTIFICATION_APPLICATION_FOCUS_OUT` and `_IN`, and on web to `visibilitychange`.
  - **`Main`:** `focus_pause`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_focus_pause.gd`:
```gdscript
extends GutTest

class TickCounter:
	extends Node
	var ticks := 0
	func _physics_process(_d: float) -> void:
		ticks += 1

var fp: FocusPause
var counter: TickCounter

func before_each() -> void:
	fp = FocusPause.new()
	add_child_autofree(fp)
	counter = TickCounter.new()
	add_child_autofree(counter)

func after_each() -> void:
	get_tree().paused = false

func test_focus_out_pauses_and_in_resumes() -> void:
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused)
	var t0 := counter.ticks
	for i in 10:
		await get_tree().process_frame
	assert_eq(counter.ticks, t0)
	fp.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(get_tree().paused)
	for i in 5:
		await get_tree().physics_frame
	assert_gt(counter.ticks, t0)
```

GUT's own runner must keep processing while paused. If `await get_tree().process_frame` hangs, set GUT's node to `PROCESS_MODE_ALWAYS` in this test's `before_each` with `gut.process_mode = Node.PROCESS_MODE_ALWAYS`.

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`FocusPause` not declared).

- [ ] **Step 3: Implement**

`world/focus_pause.gd`:
```gdscript
class_name FocusPause
extends Node
## Pause on focus loss / hidden tab so switching away never costs the diner (D-046).

var _js_cb: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_js_cb = JavaScriptBridge.create_callback(_on_visibility)
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _js_cb)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_paused(false)

func set_paused(p: bool) -> void:
	get_tree().paused = p

func _on_visibility(_args: Array) -> void:
	set_paused(bool(JavaScriptBridge.eval("document.hidden", true)))
```

Modify `world/main.gd`:
```gdscript
var focus_pause: FocusPause

# in _ready(), after hud:
	focus_pause = FocusPause.new()
	focus_pause.name = "FocusPause"
	add_child(focus_pause)
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add world/focus_pause.gd world/main.gd tests/unit/test_focus_pause.gd
git commit -m "feat: pause the game on focus loss and hidden tab"
```

---

## Phase 10: Web shell, export presets, overlays

### Task 32: Web shell, three presets, debug and perf overlays → **CHECKPOINT 2**

**Files:**
- Create:
  - `export/web_shell.html`, `export/README.md`, `export_presets.cfg`, `export/device_check.sh`
  - `ui/debug/debug_overlay.gd`, `ui/perf_overlay.gd`, `ui/build_label.gd`
- Modify: `world/main.gd`
- Test: `tests/unit/test_overlays.gd`

**Interfaces:**
- Produces:
  - **Export presets:** `web_debug`, `web_profile` and `web_release`. The profile preset has the custom feature `profile_overlay`. Release and profile exclude `ui/debug/*`.
  - **`PerfOverlay`** (CanvasLayer): `record(frame_seconds: float)`, `avg_fps() -> float`, `worst_ms() -> float`, `WINDOW_S := 60.0`.
  - **The debug overlay** (no `class_name`): `setup(main: Main)`, `handle_key(keycode: Key)`.
  - **`BuildLabel`** (CanvasLayer, layer 100): a Label in the bottom-left corner inside the safe area, font 14, 50% alpha, text `build_id()`. `static func build_id() -> String` returns `window.LST_BUILD` through `JavaScriptBridge` on web (`"dev"` when empty) and `"dev"` elsewhere. `main.gd` adds it in every preset, release included (D-135).

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_overlays.gd`:
```gdscript
extends GutTest

func before_each() -> void:
	Balance.reset()

func test_perf_overlay_stats() -> void:
	var p := PerfOverlay.new()
	add_child_autofree(p)
	for i in 59:
		p.record(1.0 / 60.0)
	p.record(0.120)
	assert_almost_eq(p.worst_ms(), 120.0, 0.01)
	assert_lt(p.avg_fps(), 60.0)

func test_debug_overlay_present_in_debug_build_and_hotkey_gold() -> void:
	if not OS.is_debug_build():
		pass_test("release runner: overlay intentionally absent")
		return
	var main := Main.create()
	add_child_autofree(main)
	main.phase_controller.start_new_game(101)
	var o := main.get_node_or_null("DebugOverlay")
	assert_not_null(o)
	o.handle_key(KEY_G)
	assert_eq(GameState.gold, 100)

func test_main_does_not_preload_debug() -> void:
	var src := FileAccess.get_file_as_string("res://world/main.gd")
	assert_false(src.contains("preload(\"res://ui/debug"), "debug overlay must be load()ed, never preloaded (D-099)")

func test_build_label_off_web_is_dev_and_added_by_main() -> void:
	assert_eq(BuildLabel.build_id(), "dev")
	var main := Main.create()
	add_child_autofree(main)
	assert_eq(main.get_children().filter(func(c): return c is BuildLabel).size(), 1)
```

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit`

Expected: FAIL (`PerfOverlay` not declared).

- [ ] **Step 3: Implement the overlays**

`ui/perf_overlay.gd`:
```gdscript
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
```

`ui/debug/debug_overlay.gd`:
```gdscript
extends CanvasLayer
## Debug builds only (D-047, D-099, D-115). Loaded with load() from Main; excluded from release/profile.

var _main: Main
var _label: Label
var _warnings: Array = []

func setup(main: Main) -> void:
	_main = main
	name = "DebugOverlay"
	layer = 30
	_label = Label.new()
	_label.position = Vector2(420, 110)
	_label.add_theme_font_size_override("font_size", 20)
	add_child(_label)
	for pool in main.find_children("*", "NodePool", true, false):
		pool.grew.connect(func(n: int): _warnings.append("%s grew to %d" % [pool.name, n]))

func _process(_delta: float) -> void:
	if _main == null:
		return
	var wd := _main.world.wave_director
	_label.text = "seed %d\nday %d  %s\nwave %d  alive %d\nfps %d\n%s" % [GameState.run_seed, GameState.day,
		Phase.name_of(_main.phase_controller.phase), wd.wave_index, wd.alive_count(),
		Engine.get_frames_per_second(), "\n".join(_warnings)]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		handle_key(event.physical_keycode)

func handle_key(keycode: Key) -> void:
	match keycode:
		KEY_G: GameState.add_gold(100)
		KEY_J: _main.phase_controller.debug_skip_to_day()
		KEY_N: _main.phase_controller.debug_skip_to_night()
		KEY_K: _main.world.wave_director.debug_kill_all()
		KEY_F:
			if _main.phase_controller.phase == Phase.NIGHT:
				GameState.damage_diner(1e9)
```

Modify `world/main.gd`, at the end of `_ready()` before the `auto_start` block:
```gdscript
	if OS.is_debug_build() and ResourceLoader.exists("res://ui/debug/debug_overlay.gd"):
		var overlay: CanvasLayer = load("res://ui/debug/debug_overlay.gd").new()
		add_child(overlay)
		overlay.setup(self)
	if OS.has_feature("profile_overlay"):
		add_child(PerfOverlay.new())
	add_child(BuildLabel.new())
```

`ui/build_label.gd` (D-135: every Pages build shows its git hash):
```gdscript
class_name BuildLabel
extends CanvasLayer
## Bottom-left build id. The pages workflow sets window.LST_BUILD = "<short hash> <branch>".

var _label: Label

func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.text = build_id()
	_label.add_theme_font_size_override("font_size", 14)
	_label.modulate.a = 0.5
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	get_viewport().size_changed.connect(_place)
	_place()

func _place() -> void:
	var ins := SafeArea.insets(get_viewport().get_visible_rect().size)
	_label.offset_left = 8.0 + ins.left
	_label.offset_bottom = -(8.0 + ins.bottom)

static func build_id() -> String:
	if OS.has_feature("web"):
		var v := str(JavaScriptBridge.eval("window.LST_BUILD||''", true))
		return v if v != "" else "dev"
	return "dev"
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `./run_tests.sh unit`

Expected: exit 0.

- [ ] **Step 5: Write the web shell**

Start from the engine's own shell for this exact version, so the loader placeholders stay correct:

```bash
TPL="$HOME/Library/Application Support/Godot/export_templates/<version dir from D-116>"
unzip -p "$TPL/web_nothreads_release.zip" godot.html > export/web_shell.html
grep -n '\$GODOT_' export/web_shell.html   # keep every placeholder line intact
```

Then make exactly these edits in `export/web_shell.html`:

1. Replace the `<meta name="viewport" ...>` line with:
   ```html
   <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
   ```
2. Append inside the existing `<style>` block:
   ```css
   html, body, #canvas { touch-action: none; overscroll-behavior: none; -webkit-user-select: none; user-select: none; -webkit-touch-callout: none; -webkit-tap-highlight-color: transparent; }
   html, body { position: fixed; inset: 0; overflow: hidden; }
   ```
3. Add before `</body>`:
   ```html
   <script>
   document.addEventListener('contextmenu', function (e) { e.preventDefault(); });
   document.addEventListener('gesturestart', function (e) { e.preventDefault(); });
   document.addEventListener('dblclick', function (e) { e.preventDefault(); }, { passive: false });
   </script>
   ```

If the template zip name differs, list it with `unzip -l "$TPL"/web*.zip | grep html` and use the no-threads release zip.

- [ ] **Step 6: Write `export_presets.cfg`**

```ini
[preset.0]

name="web_debug"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, addons/gut/*, docs/*"
export_path="build/web_debug/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=true
html/custom_html_shell="res://export/web_shell.html"
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false

[preset.1]

name="web_profile"
platform="Web"
runnable=false
advanced_options=false
dedicated_server=false
custom_features="profile_overlay"
export_filter="all_resources"
include_filter=""
exclude_filter="ui/debug/*, tests/*, addons/gut/*, docs/*"
export_path="build/web_profile/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.1.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=true
html/custom_html_shell="res://export/web_shell.html"
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false

[preset.2]

name="web_release"
platform="Web"
runnable=false
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="ui/debug/*, tests/*, addons/gut/*, docs/*"
export_path="build/web_release/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.2.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=true
html/custom_html_shell="res://export/web_shell.html"
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
```

`tests/sim/sim_harness.gd` and the bots stay out of release, because `tests/*` is excluded and the bots are only referenced from tests. The `actors/bots/*.gd` scripts are still exported. That is harmless and keeps the class cache consistent.

- [ ] **Step 7: Export all three and verify the exclusions**

```bash
mkdir -p build/web_debug build/web_profile build/web_release
"$GODOT" --headless --path . --export-debug "web_debug" build/web_debug/index.html
"$GODOT" --headless --path . --export-release "web_profile" build/web_profile/index.html
"$GODOT" --headless --path . --export-release "web_release" build/web_release/index.html
for d in web_debug web_profile web_release; do printf "%s ui/debug hits: " $d; grep -a -c "ui/debug" build/$d/index.pck || true; done
grep -c "viewport-fit=cover" build/web_release/index.html
```

Expected:
- three exports with exit 0;
- `web_debug` ui/debug hits ≥ 1, while `web_profile` and `web_release` show 0;
- the viewport-fit count is 1.

- [ ] **Step 8: Write `export/README.md`**

````markdown
# Web export

Presets (export_presets.cfg): `web_debug` (debug template, debug overlay + hotkeys G/J/N/K/F),
`web_profile` (release template, fps/frame-time overlay only), `web_release` (GitHub Pages builds, D-135).
All single-threaded (no COOP/COEP headers needed) with the custom shell `export/web_shell.html`.

```bash
"$GODOT" --headless --path . --export-release "web_release" build/web_release/index.html
cd build/web_release && python3 -m http.server 8000 --bind 127.0.0.1   # desktop check only: http://localhost:8000/ (localhost is a secure context)
```

Release check: `grep -a -c "ui/debug" build/web_release/index.pck` must print 0. The `pages` workflow runs the same check on the release and profile packs and fails the deploy on a hit; if `main.gd`'s `load("res://ui/debug/...")` string alone makes it non-zero, narrow the check to the overlay's script entry and log the change (D-135).

Phones: push the branch; the `pages` workflow deploys it to https://khanhnguyendev.github.io/last-stand-tycoon/preview/<slug>/ (slug: branch name, every character outside [A-Za-z0-9._-] → "-")
(main: the site root). The bottom-left label shows the build's git hash. Plain-http LAN does not work
(secure context, D-120). The itch.io draft is S6.
````

- [ ] **Step 9: Commit**

```bash
git add export export_presets.cfg ui/perf_overlay.gd ui/build_label.gd ui/debug world/main.gd tests/unit/test_overlays.gd
git commit -m "feat: add mobile web shell, three export presets and debug/perf overlays"
```

- [ ] **Step 9b: Device pass before CP2 (D-138).** Write `export/device_check.sh`, `chmod +x` it, and fold it into this task's commit (`git add export/device_check.sh && git commit --amend --no-edit`):

```bash
#!/usr/bin/env bash
# Usage: export/device_check.sh <url> <out_dir>   (D-138)
# Opens <url> in the iOS Simulator (Safari, a notch iPhone) and, when installed, the Android Emulator
# (Chrome), waits WAIT_S seconds (default 45) and saves screenshots. It never installs anything: when a
# runtime or device is missing it prints the one-time step for the author. The emulator is shut down
# at the end; the iOS Simulator is left booted.
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: $0 <url> <out_dir>"; exit 2; }
URL="$1"; OUT="$2"; WAIT="${WAIT_S:-45}"
mkdir -p "$OUT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

RUNTIMES=$(xcrun simctl list runtimes 2>/dev/null || true)
if printf '%s\n' "$RUNTIMES" | grep -E '^iOS .*SimRuntime' | grep -v unavailable >/dev/null; then
  UDID=$(xcrun simctl list devices available | grep -E 'iPhone [0-9]+ Pro \(' | head -1 | grep -oE '[0-9A-F-]{36}' || true)
  if [ -z "$UDID" ]; then
    echo "MISSING iPhone Pro simulator. One-time step (author): Xcode > Window > Devices and Simulators > + > iPhone 17 Pro"
  else
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b >/dev/null
    xcrun simctl openurl "$UDID" "$URL"
    sleep "$WAIT"
    xcrun simctl io "$UDID" screenshot "$OUT/ios.png" >/dev/null 2>&1
    echo "ios: $OUT/ios.png"
  fi
else
  echo "MISSING iOS Simulator runtime. One-time step (author): xcodebuild -downloadPlatform iOS"
fi

SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
AVD=""
if [ -x "$SDK/emulator/emulator" ]; then
  AVD=$("$SDK/emulator/emulator" -list-avds 2>/dev/null | awk '!/^INFO/ && NF {print; exit}' || true)
fi
if [ -z "$AVD" ]; then
  echo "MISSING Android Emulator. One-time step (author): install Android Studio, then Device Manager > add a Pixel with a Google Play system image (it ships Chrome)."
  exit 0
fi
ADB="$SDK/platform-tools/adb"
SERIAL=emulator-5554
"$SDK/emulator/emulator" -avd "$AVD" -port 5554 -no-window -no-snapshot-save -no-audio >/dev/null 2>&1 &
booted=""
for _ in $(seq 1 150); do
  if [ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then booted=1; break; fi
  sleep 2
done
[ -n "$booted" ] || { echo "ERROR: Android emulator $AVD did not boot within 300 s"; "$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || true; exit 1; }
case "$URL" in
  http://localhost:*|http://127.0.0.1:*)
    PORT=${URL#*//*:}; PORT=${PORT%%/*}
    "$ADB" -s "$SERIAL" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null ;;  # localhost stays a secure context
esac
# Skip Chrome's first-run screens.
"$ADB" -s "$SERIAL" shell 'echo "_ --disable-fre --no-default-browser-check --no-first-run" > /data/local/tmp/chrome-command-line'
"$ADB" -s "$SERIAL" shell am set-debug-app --persistent com.android.chrome >/dev/null
"$ADB" -s "$SERIAL" shell am start -a android.intent.action.VIEW -d "$URL" com.android.chrome >/dev/null
sleep "$WAIT"
"$ADB" -s "$SERIAL" exec-out screencap -p > "$OUT/android.png"
echo "android: $OUT/android.png"
"$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || true
```

Push the branch, wait for the `pages` run, then run `export/device_check.sh https://khanhnguyendev.github.io/last-stand-tycoon/preview/s1-p10-web/ /tmp/lst-cp2` and the desktop Chrome check with the Playwright method and flags logged in D-138 (screenshot plus console and page errors). The Chrome check must pass by CP2. Read the screenshots: the game renders, the bottom-left label shows the head's short hash, and the HUD is clear of the Dynamic Island and the home indicator. Fix anything that fails before CP2, and attach the screenshots' findings to the CP2 message. If the script prints a MISSING line, pass that one-time install step to the author.

- [ ] **Step 10: CHECKPOINT 2. Stop and wait for the author.**

Push the branch and wait for the `pages` workflow run to go green. Give the author https://khanhnguyendev.github.io/last-stand-tycoon/preview/s1-p10-web/ and this checklist to try on the phone:

- [ ] The bottom-left label shows the branch head's short hash (`git rev-parse --short=7 HEAD`).
- [ ] The joystick appears under the thumb; up = north. A touch starting at the very left or right edge does nothing.
- [ ] Nothing zooms, scrolls, selects or opens a context menu (long press, double tap, pinch, pull-down).
- [ ] The HUD (gold, moons, bar, banners) sits clear of the notch and home indicator.
- [ ] The edge arrow points at the incoming lane. The camera follows smoothly and shakes a little on diner hits.
- [ ] Switching tabs or apps mid-night and returning costs no diner HP.
- [ ] The day loop works: haul, sell, build, upgrade, close up.
- [ ] Perf early warning (optional, same session): open https://khanhnguyendev.github.io/last-stand-tycoon/preview/s1-p10-web/profile/, play into a night and read the overlay's `avg` and `worst`.
- [ ] D-119 phone confirmation: open https://khanhnguyendev.github.io/last-stand-tycoon/probe/ (the probe is built on `main` only) and reply with one line: `SPIKE phone=<model> browser=<name version> loaded=<yes|no> build=… safe=… win=… screen=… scale=… css=… inner=… dpr=… secure=… iframe=… notes=<none or error>` (each value copied from the probe's lines).

Do not start Task 33 until the author says continue.

---

## Phase 11: Screenshots and CI

### Task 33: Per-lane screenshots (D-076)

**Files:**
- Output (committed): `docs/screenshots/s1/lane_west.png`, `lane_north.png`, `lane_east.png`

- [ ] **Step 1: Capture**

```bash
for lane in west north east; do
  "$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --lane=$lane --out=docs/screenshots/s1/lane_$lane.png
done
```

Expected: three `saved ... (720, 1280)` lines.

- [ ] **Step 2: Check each image**

The hero stands at the lane's wall zone, and the Boar is visible on screen 2 s before it reaches range. Measure the Boar's height in pixels with any image viewer: it must be **≥ 40 px** (D-076). If it is smaller, escalate; don't change the camera silently.

- [ ] **Step 3: Commit**

```bash
git add docs/screenshots/s1/lane_*.png
git commit -m "docs: add per-lane S1 visibility screenshots"
```

### Task 34: GitHub Actions CI (D-087)

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `CLAUDE.md` (a CI section)

- [ ] **Step 1: Write the workflow** (use the exact tag from D-116)

`.github/workflows/ci.yml`:
```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
env:
  GODOT_TAG: "4.7-stable"   # EXACT tag from D-116; must equal CLAUDE.md "GODOT_TAG=" (D-129)
jobs:
  # Two parallel jobs (D-132). Their names are the required checks for branch protection (D-133).
  unit:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - name: Check the pinned Godot tag matches CLAUDE.md
        run: |
          grep -q "GODOT_TAG=${GODOT_TAG}\*\*" CLAUDE.md || { echo "CLAUDE.md pins a different GODOT_TAG"; exit 1; }
          grep -qF "GODOT_TAG: \"${GODOT_TAG}\"" .github/workflows/pages.yml || { echo "pages.yml pins a different GODOT_TAG"; exit 1; }
      - name: Download Godot headless (official, SHA-512 verified)
        run: |
          set -euo pipefail
          BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_TAG}"
          ZIP="Godot_v${GODOT_TAG}_linux.x86_64.zip"
          curl -fsSL -o SHA512-SUMS.txt "$BASE/SHA512-SUMS.txt"
          curl -fsSL -o "$ZIP" "$BASE/$ZIP"
          grep -E "[[:space:]]\*?${ZIP}\$" SHA512-SUMS.txt > wanted.sha512
          sha512sum -c wanted.sha512
          unzip -q "$ZIP"
          mv "Godot_v${GODOT_TAG}_linux.x86_64" godot-bin && chmod +x godot-bin
          echo "GODOT=$PWD/godot-bin" >> "$GITHUB_ENV"
      - name: Unit tests + grep ban
        run: ./run_tests.sh unit
  sim:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - name: Check the pinned Godot tag matches CLAUDE.md
        run: |
          grep -q "GODOT_TAG=${GODOT_TAG}\*\*" CLAUDE.md || { echo "CLAUDE.md pins a different GODOT_TAG"; exit 1; }
          grep -qF "GODOT_TAG: \"${GODOT_TAG}\"" .github/workflows/pages.yml || { echo "pages.yml pins a different GODOT_TAG"; exit 1; }
      - name: Download Godot headless (official, SHA-512 verified)
        run: |
          set -euo pipefail
          BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_TAG}"
          ZIP="Godot_v${GODOT_TAG}_linux.x86_64.zip"
          curl -fsSL -o SHA512-SUMS.txt "$BASE/SHA512-SUMS.txt"
          curl -fsSL -o "$ZIP" "$BASE/$ZIP"
          grep -E "[[:space:]]\*?${ZIP}\$" SHA512-SUMS.txt > wanted.sha512
          sha512sum -c wanted.sha512
          unzip -q "$ZIP"
          mv "Godot_v${GODOT_TAG}_linux.x86_64" godot-bin && chmod +x godot-bin
          echo "GODOT=$PWD/godot-bin" >> "$GITHUB_ENV"
      - name: Sim tests (thresholds, < 60 s; never drop tests, D-132)
        run: ./run_tests.sh sim
```

- [ ] **Step 2: Validate the YAML locally**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('yaml ok')"`

Expected: `yaml ok`. If PyYAML is missing, run `pip3 install --user pyyaml` first.

- [ ] **Step 3: Document it in `CLAUDE.md`** (append)

```markdown
## CI
`.github/workflows/ci.yml` runs two parallel jobs, `unit` (`./run_tests.sh unit`) and `sim` (`./run_tests.sh sim`),
on Linux with the pinned, SHA-512-verified Godot (D-116, D-129), for every PR and push to main. CI is canonical
for sim thresholds (D-105). If the sim suite goes over 60 s: never drop tests; report timings and escalate
(D-132). The sweep is manual.
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml CLAUDE.md
git commit -m "ci: run unit and sim suites as parallel jobs on every PR"
```

- [ ] **Step 5: Push the phase branch and open its PR.** The remote is `origin` (`khanhnguyendev/last-stand-tycoon`). Push `s1/p11-screenshots-ci` and open the Phase 11 PR (D-133). Then:

Run: `gh pr checks --watch`

Expected: both `unit` and `sim` pass. If the run is red only on thresholds, CI wins (D-105). Compare with the local numbers and escalate if they differ by more than 5 percentage points of diner HP.

- [ ] **Step 6: Hand the author the branch-protection command. Don't run it (D-133).** In the Phase 11 PR, and in the report, give the author exactly this. It requires a PR and green `unit` and `sim` checks for `main`, admins included:

```bash
gh api -X PUT repos/khanhnguyendev/last-stand-tycoon/branches/main/protection \
  -H "Accept: application/vnd.github+json" --input - <<'JSON'
{
  "required_status_checks": { "strict": true, "contexts": ["unit", "sim"] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null
}
JSON
```

Note: the repo is public, so branch protection works on the free plan (D-134). From Phase 12 on, every phase PR must be green before review.

---

## Phase 12: Balance tuning (D-103, D-131)

### Task 35: Sim-driven tuning pass

**Files:**
- Modify: `balance/*.gd` defaults only
- Modify: `docs/DECISIONS.md` (append)

**Rules:**
- Change only Balance defaults. No code or geometry changes.
- Update the pinned-reference rows (`test_balance`, `test_wave_math`, `test_economy`, `test_pool_sizes_from_balance`) and the matching spec sections (6.2, 8.9, 11, 12) in the same commit.
- The priority order is D-103:
  1. night 1 NaiveBot ≥ 50% must hold;
  2. night 2 PlannerBot ≥ 60% must hold;
  3. night 2 NaiveBot ≤ 30% may relax to ≤ 45%, which must be logged.
- There is no timebox (D-131). **Stop and escalate** with the sweep CSV when either:
  - 1 and 2 can't both be met; or
  - 3 consecutive tuning rounds (one knob change plus a sims-and-sweep run each) make no progress on any target.
- Never change the design yourself.

- [ ] **Step 1: Baseline.** Run `./run_tests.sh sim` and the sweep. Save both outputs to the task report.

- [ ] **Step 2: Iterate.** Change one knob at a time, re-run `./run_tests.sh sim` and the sweep, and note the effect. The knobs to try, in order:
  1. `side_share_base` / `side_share_step`
  2. `EnemyBalance.hp`
  3. `BuildBalance.tower_damage[0]`
  4. `EnemyBalance.speed`
  5. `WaveBalance.count_growth`
  6. `EconomyBalance.traveler_interval` (day length)

  Stop when all of these hold:
  - the three thresholds pass;
  - in the sweep, `unspent_gold_at_closeup` stays low through day 5 (under about one tower's cost per day);
  - night + day seconds from day 2 on is at least 4 min.

- [ ] **Step 3: Log the tuning.** Append a `Tuning pass` entry under the next free D-id to `docs/DECISIONS.md` with:
  - every changed value (old → new);
  - the final sim numbers;
  - the sweep break day ("S1 breaks at day N; target for S2 card power");
  - any threshold relaxation.

  Also update the spec §12 values if any changed.

- [ ] **Step 4: Commit**

```bash
git add balance docs/DECISIONS.md docs/superpowers/specs/2026-09-30-s1-vertical-slice-design.md
git commit -m "chore: tune S1 balance from sims and log the sweep break day"
```

---

## Phase 13: Perf check and results

### Task 36: Profile build, the web baseline, and the results

**Files:**
- Modify: `docs/superpowers/specs/2026-09-30-s1-vertical-slice-design.md` §16 (Results)

- [ ] **Step 1: Build profile and release, and measure their sizes**

```bash
"$GODOT" --headless --path . --export-release "web_profile" build/web_profile/index.html
"$GODOT" --headless --path . --export-release "web_release" build/web_release/index.html
for f in index.wasm index.pck index.js; do printf "%s gz bytes: " $f; gzip -9 -c build/web_release/$f | wc -c; done
```

Record the gzip sum (wasm + pck) as "release build size, compressed" (D-086).

- [ ] **Step 2: Device numbers without the phone (D-138).** Push the branch; run `export/device_check.sh https://khanhnguyendev.github.io/last-stand-tycoon/preview/s1-p13-perf/profile/ /tmp/lst-perf` and the desktop Chrome check on the same URL. Record, for information only, the overlay's `avg`/`worst` visible in each screenshot after `WAIT_S` seconds, labelled "idle, no combat". Load time is not measured off-phone. Simulator and desktop fps are not criterion 4; the phone reading happens at CP3 (Task 37, Step 3).

- [ ] **Step 3: Fill in the results table.** Complete spec §16's build-size row, and note the device numbers from Step 2 next to it. The phone rows (load time, first combat, criterion 4) are filled in at Task 37, Step 4.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-09-30-s1-vertical-slice-design.md
git commit -m "docs: record S1 web baseline and perf results"
```

---

## Phase 14: Gate

### Task 37: **CHECKPOINT 3**, then the gate playtest from the Pages URL

- [ ] **Step 1: The pre-upload check.**
  - `./run_tests.sh all` is green.
  - `grep -a -c "ui/debug" build/web_release/index.pck` prints 0.
  - The `pages` workflow run for the branch head is green, and https://khanhnguyendev.github.io/last-stand-tycoon/preview/s1-p14-gate/ shows the head's short hash, and so does https://khanhnguyendev.github.io/last-stand-tycoon/preview/s1-p14-gate/profile/.

- [ ] **Step 2: CHECKPOINT 3. Stop and wait for the author.** Hand over the preview URL above. Do nothing further until the author has played.

- [ ] **Step 3: HUMAN.**
  - The author opens the preview URL on their phone and confirms it loads and plays (DoD 6).
  - They play the 3 gate cycles on the **profile** build (https://khanhnguyendev.github.io/last-stand-tycoon/preview/s1-p14-gate/profile/: the release template plus the small fps overlay), so the one phone session also gives the phone numbers (D-138). They note the time from page open until playable and until first combat (D-085), and during 60 s of night-3 combat they read the overlay's `avg` and `worst`. They report the phone model.
  - They answer the 6 playtest questions (spec §15). Each answer is tagged **loop** or **presentation** (D-107).
  - They give the gate verdict: "want a 4th?"

- [ ] **Step 4: Record the gate.** Fill in spec §16's phone rows (load time, first combat, criterion 4 with the phone model; if the phone is clearly high-end, write "not validated on mid-range; carried to S6", D-084), "Playtest answers 1–6" and "Gate verdict". If criterion 4 fails on a phone that is not clearly high-end, list it as unmet and escalate to the author before reporting done. Tick off every definition-of-done item in spec §14.2, and list any that are unmet.

```bash
git add docs/superpowers/specs/2026-09-30-s1-vertical-slice-design.md
git commit -m "docs: record S1 gate playtest results"
```

- [ ] **Step 5: Final review.** Dispatch the `reviewer` for a whole-branch review against the spec and this plan, then report done or not done to the author.
