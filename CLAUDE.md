# Last Stand Tycoon — agent guide

Godot 4.7 · GDScript · Compatibility renderer · portrait 720×1280 · single-threaded Web export.
Spec: `docs/superpowers/specs/2026-09-30-s1-vertical-slice-design.md`. Decisions: `docs/DECISIONS.md`.

## Layout (canonical, D-032 + D-098)
- `autoload/` EventBus.gd, GameState.gd, Balance.gd (no class_name in autoloads)
- `core/` pure static helpers, no scene access (unit-tested)
- `components/` reusable child nodes
- `actors/` hero, enemy, traveler, projectile, pickups, bots
- `world/` main scene, map, stations, build spots, directors, PhaseController; `world/audio/` AudioDirector (S5); `world/warmup.gd` boot warm-up
- `ui/` HUD, joystick, world labels, overlays; `ui/guide/` onboarding pointer, `ui/settings/` settings panel (S5); `ui/debug/` is debug-only and excluded from release/profile exports
- `balance/` typed Resource scripts + `balance.tres`, `ui_tuning.tres`
- `tests/unit/`, `tests/sim/`, `tests/sim_tier/` (GUT; tier sims, D-247); `tests/sim_ticks.golden.json` is the per-sim tick budget; `tests/sim/out/` is gitignored; `tests/sim/baseline/` is the determinism baseline (S4; re-recorded once for E5, D-237: rows 1 to 7 are the tier-1 identity)
- `assets/<pack-id>/` third-party CC0 packs (only used files + `LICENSE.txt`, one row per pack in `docs/ASSET_LICENSES.md`); `assets/_candidates/` is gitignored (D-187)
- `art/` our art: palette, remapped atlases, shared materials, wrappers, procedural builders, icons (D-187, D-188); `art/audio/` audio manifest, `art/fx/` FX atlas, shader, field, pointer (S5); rules in `docs/ART_BIBLE.md`
- `tools/` headless and editor-only scripts (validator, palette remap, KayKit post-import, shots); excluded from every web export
- Infra only (never game code): `addons/` (GUT), `export/` (web shell), `.github/` (CI), `docs/`

## Toolchain (pinned, D-129)
- Godot: **GODOT_TAG=4.7.2-stable**. The same string is in `.github/workflows/ci.yml` and `.github/workflows/pages.yml`, and CI fails if they differ.
- Official binaries only (`godotengine/godot-builds` releases), verified against the release's `SHA512-SUMS.txt`.
- GUT: `v9.7.1` (D-117).

## Commands
- `export GODOT=/Users/ryan/Applications/Godot-4.7.2-stable/Godot.app/Contents/MacOS/Godot` (D-116)
- `./run_tests.sh unit` · `./run_tests.sh sim` · `./run_tests.sh sim-tiers` · `./run_tests.sh all` · `./run_tests.sh --quick` (unit + night-1 sims)
- Tick budget update (deliberate, D-247): `TICK_BUDGET_UPDATE=1 ./run_tests.sh sim` or `sim-tiers`; commit the diff of `tests/sim_ticks.golden.json`
- Sweep: `"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd`
- Upgrader sweep (E1): the same command with `-- --bot=upgrader`; writes `tests/sim/out/sweep_upgrader.csv`
- Tier sweep (E5): the same command with `-- --bot=tier --days=20`; writes `tests/sim/out/sweep_tier.csv`; prints a `TIER` line
- Tier fixtures (E5): `"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/make_save.gd -- --fixture=tier` (deterministic; writes five files under `export/fixtures/`)
- Web export: see `export/README.md`
- S4 shots: `tools/shots.sh <out_dir>` (rendered 720x1280 + 40% copies); determinism: `tools/baseline_diff.sh` (must print `baseline identical`) and `tools/baseline_rows.sh 7` (must print `rows 1-7 identical`: the tier-1 identity, D-237)
- Night-3 perf (iOS Simulator, profile build): `export/perf_night3.sh <web_profile_dir> <out_dir>`; read the frozen `PERF phase=NIGHT` line; the gate is the median of 3 runs (D-199)

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
- One branch and one PR per plan phase: `s<N>/p<N>-<slug>` or `e<N>/p<N>-<slug>` (the table is in the plan), from an up-to-date `main`. One commit per task inside it.
- The `reviewer` subagent reviews every task; the author reviews the checkpoint phases' PRs.
- Before CI exists, the PR body carries the local test output. After CI exists, `unit` and `sim` must be green.
- Every push deploys a web build to GitHub Pages: `main` at https://khanhnguyendev.github.io/last-stand-tycoon/, other branches at `preview/<slug>/` (slug = the branch name with every character outside `[A-Za-z0-9._-]` replaced by `-`) (D-135). Phone tests use those URLs; plain-http LAN doesn't work (D-120).
- **Merges (D-137).** Merge a phase PR yourself (merge commit, never squash) only when CI is green (before CI: the full local suite output is in the PR body), every task passed its reviewer pass, no escalation is open, and the phase doesn't end at a checkpoint. D-159: CP2 and CP3 are deferred into one FINAL REVIEW after S5, so every phase until then is self-merged; `main` is protected (PR plus `unit`, `sim`, `sim-tiers` and Pages `deploy`, strict). After a self-merge, post a PR comment of at most 5 lines (what shipped, tests, decisions).
- Never push to `main` directly, never change branch protection. (The two authorized changes, D-159 and D-247, are applied.)
- **Wiring notes (D-139):** implementers never edit `world/main.gd`, `world/world.gd`, `world/main.tscn`, `autoload/EventBus.gd`, `autoload/GameState.gd`, `balance/*` or `project.godot` unless that file is the task's main purpose; they report the exact lines as a wiring note, and the main session applies it after review.
- **Look-ahead (D-140):** T21–T24, T27, T28, T30, T31 may run before CP1 is approved, on stacked branches that are not merged into `main` until the author approves CP1; T33, T34 may run alongside T32 before CP2.
- **Autonomy (D-159):** build v0.1 through S5 without the author. Log every decision; add reversible feel, balance, art and IDEA.md-deviating ones to `docs/REVIEW_QUEUE.md`. Stop and ask only for setup agents can't do, money, license doubt, irreversible actions outside the repo, or a design conflict inside IDEA.md's pillars.
- **"merged" (D-142):** check the PR with `gh pr view` first. Open and self-mergeable (D-137): merge it and say so. Checkpoint PR: stop and ask.
- **Parallel tasks (D-136):** only with disjoint file sets; hot files (`project.godot`, `CLAUDE.md`, `autoload/EventBus.gd`, `autoload/GameState.gd`, `balance/*`, `world/main.gd`, `world/main.tscn`, `world/world.gd`, `run_tests.sh`, `tests/sim_ticks.golden.json`, `.github/workflows/*`) are serialized and edited by the main session; at most 3 implementers, each in its own worktree on `s1/p<N>-t<NN>-<slug>`; merge `--no-ff` into the phase branch and run the full suite before the next merge; conflicts are resolved by the main session.

## Device testing (D-138)
- Primary: the iOS Simulator (Safari, a notch iPhone) and, when installed, the Android Emulator (Chrome), on `http://localhost` or the Pages preview URL. Run `export/device_check.sh <url> <out_dir>` and read the screenshots.
- Never install system components. If a runtime is missing, give the author the one-time install step the script prints.
- The author's phone is used only at the final review (D-159).
- Without an Android Emulator, Android checks use Playwright Chromium with the Pixel 7 profile (`export/pw_check.mjs`, from Task 32); label them **emulated**, not device (D-141). Real Android is covered by the S6 friend playtests.
- Desktop Chrome: headless with software WebGL (flags in D-138).

## Scope and time (D-131)
- v0.1 has no deadline. Scope is decided by quality and the v0.1 gate, never by the calendar. Plan estimates are information only.
- No time-based stop rules. If a task turns out bigger than its plan describes (new files, new systems, or steps the plan didn't anticipate), stop and propose a split before continuing.
- Escalate on facts, not time: a failed check whose pre-agreed fallback also fails (spike); must-hold balance targets that conflict, or 3 tuning rounds without progress (D-103).

## Sim budget (D-132, D-247)
- Two sim suites, each its own CI job: `sim` (`tests/sim/`) and `sim-tiers` (`tests/sim_tier/`).
- **Tick budget (the gate):** every sim records the physics ticks it simulated; a job fails if a sim exceeds its
  expected count in `tests/sim_ticks.golden.json` by more than 20%, has no expected count, or is in the golden file
  but did not run. Update the golden file deliberately (see Commands) and say why in the commit.
- **Wall time:** over 60 s per job is a warning, over 150 s a failure. Runner speed varies about 2x; do not chase
  the warning by re-running jobs.
- **Never drop, skip or weaken a test.** If a job nears the hard limit, report per-test ticks and timings and escalate.
- Perf and device measurements are taken once, after all tasks, milestones and phases are done (D-260).

## Rules
- Gameplay in `_physics_process` only; never depend on frame delta.
- Randomness only via `Rng.stream(run_seed, day, name)`; a unit test bans global rand calls.
- Only `GameState` methods mutate game data; they emit the EventBus signals. Tweens are visual only.
- EventBus = cross-system events only; local signals inside a system.
- Every number in `balance/`; every user string through `tr()`.
- Ties broken by `spawn_index`, never node order.
- Edit `world/main.tscn` by hand only; never save it from the Godot editor (the editor rewrites the header and uids, and later plan tasks give its full text).
- `./run_tests.sh` fails on GUT errors as well as failed asserts, including any `SCRIPT ERROR`. Don't write tests that expect engine errors.
- Sims and tests read state at matching points after `await get_tree().physics_frame`; `physics_frame` fires before the nodes' `_physics_process` (D-118).

## CI
`.github/workflows/ci.yml` runs three parallel jobs, `unit` (`./run_tests.sh unit`), `sim` (`./run_tests.sh sim`) and
`sim-tiers` (`./run_tests.sh sim-tiers`), on Linux with the pinned, SHA-512-verified Godot (D-116, D-129), for every PR
and push to main. Each job also checks that `GODOT_TAG` matches CLAUDE.md and pages.yml. The job names `unit`, `sim`
and `sim-tiers` are required checks for branch protection (D-133, D-247); don't rename them. CI is canonical for sim
thresholds (D-105). Sim jobs fail on the tick budget or above 150 s, and warn above 60 s (D-247); never drop tests
(D-132). The sweep is manual. The `pages` workflow's `deploy` job (release/profile packs free of `ui/debug`, DoD 5)
is a required check too.
