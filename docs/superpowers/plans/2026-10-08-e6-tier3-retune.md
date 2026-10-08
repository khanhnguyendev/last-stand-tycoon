# E6: tier-3 retune and lane character — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. One implementer per task, a
> reviewer pass per task, a whole-branch review at the end of phase 4.

**Goal:** make reading the lanes pay at tier 3 (a persistent lane character per run, specialist branches, a branch
card), meet the author's targets of D-281 to D-291 on a held-out report, and deliver it behind one flag.

**Architecture:** a pure `LaneCharacter` helper draws one siege lane and one hare lane per run from a new stream and
post-processes each night's plan. New balance values sit beside the old ones behind
`Balance.data.tiers.retune_enabled`; one accessor picks the set. The interface (markers, card, reveal step) reads the
same flag. Proof is a real-play report on disjoint tuning and hold-out seeds.

**Tech stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-08-e6-tier3-retune-design.md`.

## Global constraints

- Tier-1 and tier-2 play are byte-identical: `tools/baseline_rows.sh 7` prints `rows 1-7 identical`,
  `tools/baseline_diff.sh` prints `baseline identical`, the pinned plans hold.
- With the flag off, tier 3 is byte-identical to main at the start of the slice: `tools/baseline_t3_off.sh` prints
  `tier-3 off identical`. All three outputs, with the commit, go into EVERY phase PR body.
- One flag only. Production code reads it through the accessor; nothing in production sets it.
- Gameplay in `_physics_process`; randomness only through `Rng.stream`; only `GameState` mutates game data; every
  number in `balance/`; every user string through `tr()`; `ui/debug/` and `tools/` never reach release exports.
- Never drop, skip or weaken a test. Sim wall time warns at 60 s and fails at 150 s; the tick budget is the gate.
- Hot files (`project.godot`, `CLAUDE.md`, `autoload/*`, `balance/*`, `world/main.gd`, `world/main.tscn`,
  `world/world.gd`, `run_tests.sh`, `tests/sim_ticks.golden.json`, `.github/workflows/*`) are edited by the task
  that names them or by the main session. At most three implementers at once, each in its own worktree.
- Anything approved in D-281 to D-291 that proves unbuildable or wrong is escalated to the author at that moment.
- Tests that need tier 3 use `GameState.debug_set_tier(3, day)`; tests that need the flag set
  `Balance.data.tiers.retune_enabled = true` and restore with `Balance.reset()` in `after_each`.

## Review focus

1. A wave whose drawn main and side lanes are both neither siege nor hare: the side group moves, the hare share comes
   as an extra group, totals unchanged (Task 3).
2. A wave with very few hares (1 or 2): the largest-remainder split never goes negative or exceeds a group (Task 3).
3. A v6 tier-3 save loaded with the flag on, mid-night snapshot included (Task 5).
4. A tower covering both the siege lane and the hare lane (Tasks 6, 8, 13).
5. The card with a long translation and on the narrowest aspect (Task 13).

## Phases and branches

| Phase | Branch | Tasks |
|---|---|---|
| 0 Setup | `e6/retune-spec` | 0 |
| A Worst frame | `e6/pA-worst-frame` | A1, A2 |
| 1 Lane character | `e6/p1-lane-character` | 1 to 6 |
| 2 Specialists | `e6/p2-specialists` | 7 to 9 |
| 3 Interface | `e6/p3-interface` | 10 to 15 |
| 4 Proof (checkpoint) | `e6/p4-proof` | 16 to 21 |
| 5 Flip | `e6/p5-flip` | 22 |
| 6 Cleanup | `e6/p6-cleanup` | 23 |

## Waves

| Wave | Tasks (parallel inside a wave) |
|---|---|
| 0 | 0 |
| 1 | A1, 1, 2 |
| 2 | A2, 3, 7 |
| 3 | 4, 5, 8 |
| 4 | 6, 9, 10 |
| 5 | 11, 12, 13 |
| 6 | 14 |
| 7 | 15 |
| 8 | 16, 19 |
| 9 | 17 |
| 10 | 18 |
| 11 | 20 |
| 12 | 21, then STOP for the author |
| 13 | 22 (after approval) |
| 14 | 23 |

Phase A merges on its own as soon as A2 is green. Phases 1 to 3 are separate PRs; a task of a later phase that
starts before the earlier phase merges branches from that phase's branch and is merged after it.

---

### Task 0: setup (main session)

- **Files:** this plan, the spec, `docs/DECISIONS.md` (D-281 to D-291), `tools/baseline_t3_off.sh`,
  `tests/sim/baseline/tier3_off.csv`, `CLAUDE.md` (the command).
- **Do:** record the tier-3 sweep from main (`-- --bot=tier --days=32 --seed=20260930 --policy=threat
  --cols=extra`) as the baseline file; the tool re-runs it and diffs, printing `tier-3 off identical` or the first
  differing row. Run it twice to prove it is stable.

### Task A1: worst-frame diagnosis

- **Files:** `export/perf_night3.sh` (a window-offset parameter if missing), `docs/review/media/e6/perf/diagnosis.md`.
- **Do:** spec section 7 step 1: the same tier-3 night with the measured window starting 0 s, 1 s and 3 s later,
  three runs each, profile build, iOS Simulator. Report where the worst frame lands in each. Verdict: artifact or
  real. No fix in this task.

### Task A2: warm-up fix and boot cost

- **Files:** `world/warmup.gd`, `tests/unit/test_warmup.gd`, `ui/debug/` (a first-use draw log, debug only),
  `docs/review/media/e6/perf/`.
- **Do:** if A1 says real: log first-use draws around the spike in a debug build, add them to the warm-up, re-measure
  (median of 3). If A1 says artifact: correct the measurement window and document it. In both cases measure load to
  first playable frame with and without the warm-up (`?warmup=0`).
- **Tests:** every new warm-up node is on screen at 9:16, 9:21 and 16:9 and the grid capacity holds.

### Task 1: the flag and its accessor

- **Files:** `balance/tier_balance.gd` (`retune_enabled := false`), `core/tier_effects.gd` (`retune_on(tb)`),
  `ui/debug/debug_overlay.gd` (`?retune=1`), `tests/unit/test_retune_flag.gd`.
- **Tests:** default false; the debug flag turns it on; a source scan: no file outside `ui/debug/`, `tests/` and
  `tools/` assigns `retune_enabled`; every production read goes through `TierEffects.retune_on`.

### Task 2: `LaneCharacter.for_run`

- **Files:** `core/lane_character.gd`, `tests/unit/test_lane_character.gd`, `tests/unit/test_rng.gd`.
- **Interfaces:** produces `LaneCharacter.for_run(run_seed: int) -> Dictionary` (`{"siege": String, "hare":
  String}`), `LaneCharacter.lane_type(character, lane) -> StringName` (`&"siege"`, `&"hare"`, `&"neutral"`).
- **Tests:** deterministic per seed with literal pins for seeds 1 to 8; siege != hare; over seeds 1 to 200 each lane
  is siege at least 30 times and hare at least 30 times; the first three values of every existing named stream are
  unchanged (literal pins captured before the change).

### Task 3: the plan step

- **Files:** `core/lane_character.gd` (`apply`), `tests/unit/test_lane_character.gd`.
- **Interfaces:** consumes Task 2. Produces `LaneCharacter.apply(plan: Array, character: Dictionary, tb: TierBalance)
  -> Array`; a wave may carry `extra: [{lane, count, fast}]`; `LaneCharacter.active_lanes(wave) -> Array`;
  `LaneCharacter.brute_lane(wave, character) -> String`.
- **Tests:** spec 3.2 rules a to d on literal waves (each rule has a wave that fails for the named wrong
  implementation: hares taken from main only; side not moved; guard missing); over the 200-seed scan at brute-ramp
  days 1, 2, 3 and later: every brute on the siege lane, at most 3 active lanes, per-wave totals of enemies, hares
  and brutes equal the input plan, no negative count, a group's hares never above its count; the night-level hare
  share printed per seed; the input plan is not mutated.

### Task 4: consumers of the plan

- **Files:** `core/lane_planner.gd` (`composition_by_lane`, `threat_by_lane` read `extra`), `core/wave_schedule.gd`,
  `world/wave_director.gd`, `world/world.gd` (`pool_sizes`; hot file, this task), `autoload/GameState.gd` (the plan
  is passed through `apply` at tier 3 with the flag on; `lane_character()`; hot file, this task), tests in
  `test_lane_planner.gd`, `test_wave_schedule.gd`, `test_wave_director.gd`, `test_telegraph.gd`.
- **Tests:** an extra group spawns on its lane with the side-group delay; brutes spawn on the siege lane when it was
  not drawn; composition and threat count the extra group; pools cover the worst case and never grow in a full night;
  with the flag off the plan and the spawn schedule of a tier-3 night are identical to before (literal hash).

### Task 5: schema 7

- **Files:** `core/save_codec.gd`, `autoload/GameState.gd` (hot file, this task; serialize after Task 4),
  `tests/unit/test_save_v7.gd`, `tests/fixtures/` (a real v6 tier-3 save copied from `export/fixtures/`).
- **Tests:** v7 round trip; the real v6 fixture loads at v7 with the character derived from its `run_seed`, twice the
  same; a stored character that differs is replaced and a warning is recorded (assert the warning hook, not an
  engine error); a flag-off save loads with the flag on; a night-start snapshot made flag-off replays flag-on with
  the new plan (the documented difference is asserted, not hidden).

### Task 6: the bot's threat-matched rule

- **Files:** `actors/bots/tier_bot.gd`, `tests/unit/test_tier_bot.gd`.
- **Tests:** with the flag on, `threat` follows spec 4.4 for literal characters: the siege-lane fence takes Stone,
  other fences Spike; a tower covering the siege lane takes Longbow, also when it covers the hare lane; other towers
  Volley; the choice does not change from day to day. With the flag off the old rule is unchanged (existing tests
  untouched). A new report policy `unbranched` buys no branch.

### Task 7: the specialist values

- **Files:** `balance/branch_balance.gd` (new values beside the old: `longbow_kind_mult_retune`,
  `spike_pass_damage_retune`, `hare_lane_share`), `core/branch_math.gd` (the accessor and the kind multiplier),
  `components/` attackers and fences where damage is applied, `tests/unit/test_branch_effects.gd`.
- **Tests:** with the flag on a Longbow shot does 120 x 2.0 to a brute and 120 to a boar or hare; Spike's pass
  damage is 16 scaled by the night's HP multiplier; with the flag off every existing literal is unchanged.

### Task 8: the lane-type bench

- **Files:** `tests/support/branch_bench.gd`, `tests/unit/test_branch_bench.gd`.
- **Interfaces:** `BranchBench.run(lane_type, tower_branch, fence_branch, pressure) -> Dictionary` (`diner_lost`,
  `fence_hp_left`, `hares_in_zone`, `clear_s`).
- **Tests:** spec 4.2: the floor and the 15% specialist margin per lane type at pressure 12 and at the cap, with the
  flag on; with the flag off today's values are pinned as literals; each assertion names the mutation that fails it
  (kind multiplier 1.0; pass damage 10). Wall time of the file printed; about 10 s at most.

### Task 9: identity restated

- **Files:** `tests/unit/test_branch_identity.gd`.
- **Tests:** spec 4.3 on the bench measures with the flag on; the existing flag-off assertions stay; "unbranched is
  never the best at any named measure" for every lane type.

### Task 10: icons and the lane-character marker

- **Files:** `art/icons/` (siege and hare character icons, built procedurally like the branch icons),
  `world/lanes/lane_character_marker.gd`, `world/lanes/telegraph_marker.gd` (placement beside the row),
  `tests/unit/test_lane_marker.gd`, `tools/shot_lane_character.gd`.
- **Tests:** shown only at tier 3 with the flag on, by day and night; siege icon on the siege lane, hare icon on the
  hare lane, none on neutral; not hidden by the HUD-bar rule; on screen from each lane's zone at three aspects; the
  two icons' alpha silhouettes differ (shape, not colour: compare binarized masks); grayscale 40% shots.

### Task 11: the reveal step and banners

- **Files:** `world/tier_reveal.gd`, `world/phase_controller.gd` (the one-time banner), `ui/hud/` banner use,
  `tests/unit/test_tier_reveal.gd`.
- **Tests:** with the flag on the tier-3 reveal has six steps (0.60 to 2.35 s, ends at 3.0 s), the markers are
  hidden before their step and shown after, tap-to-skip applies all; the flavour line matches lane and character;
  all eight lines are at most 6 words and go through `tr()`; a tier-3 save loaded flag-on shows the banner once at
  its first dawn and never again after a reload; with the flag off the reveal has five steps as today.

### Task 12: the third arrow

- **Files:** `ui/hud/hud.gd`, `ui/hud/hud_icons.gd`, `tests/unit/test_hud.gd`.
- **Tests:** three active lanes give three arrows; no two arrow rects intersect at 720 x 1280 and at 9:21; the brute
  mark is on the siege lane's arrow only; two-lane waves are unchanged (existing tests).

### Task 13: the branch card

- **Files:** `ui/hud/branch_card.gd`, `ui/hud/hud.gd` (mount), `tests/unit/test_branch_card.gd`,
  `tools/shot_branch_card.gd`.
- **Tests:** rows per spec 5.2 for each of the four branches; row 3 lists both lanes for a two-lane tower with the
  right icons; appears on entering an armed pad, hides on exit and on completion; payment bar follows
  `GameState.branch_remaining`; mouse filter ignore and a drag starting on the card moves the hero; the card rect
  never intersects the hero's body rect with the hero on each of the 18 pads at 9:21, 9:16, 16:9; inside the safe
  area; pseudo-locale (every string 40% longer) and a Vietnamese sample: no row overflows the card or intersects
  another; the font has glyphs for the sample; with the flag off the card never shows.

### Task 14: the world side of the pads

- **Files:** `core/map_layout.gd` (`BRANCH_PADS_RETUNE` behind the accessor), `world/build_spots/branch_pad.gd`,
  `tests/unit/test_branch_pads.gd`, `tests/unit/test_branch_pad_layout.gd`, `tools/probe_t3_layout.gd`.
- **Tests:** with the flag on: no name, effect or warning label in the world; zero overlaps in the near stage and on
  the pad against hero, pips, "Close up", station labels, count rows, tier sign, HUD bar and the lane markers, at
  the worst reachable points and three aspects; pad clearance rules hold for the moved pads. With the flag off:
  positions, labels and the pinned overlap lists are exactly today's.

### Task 15: interface shots

- **Files:** `tools/`, `docs/review/media/e6/interface/`.
- **Do:** 720 x 1280 and 40% copies: the marker at each entrance for both characters (and grayscale), the card for
  four branches, the reveal step, three arrows, the 18 pad views. Look at every image and say what it shows.

### Task 16: the retune report

- **Files:** `tests/sim/report_retune.gd`, `tests/sim/sweep_math.gd`, `tests/sim/sweep_runner.gd`
  (`--retune=on`, per-run lines the report needs), `tests/unit/test_sweep_math.gd`.
- **Tests (pure maths on literal rows):** the seed scan (tuning set, hold-out sets #1 and #2 disjoint, in scan
  order); each verdict line's pass and fail boundary; per-lane lead; the `--final` gate (refuses without it; records
  commit and set number); a missing run means no verdicts and exit 1.

### Task 17: tuning rounds (main session rules; implementer runs)

- **Do:** spec 8.2 steps 1 to 3 on the tuning set. Each round: the main session edits `balance/`, the implementer
  runs the bench and the report and returns raw output, one commit per round with the output under
  `docs/review/media/e6/balance/round<N>/`. At most three rounds; then escalate.

### Task 18: fence tax and the ramp

- **Do:** spec 8.2 steps 4 and 5 on the tuning set, same commit discipline. The bench runs at the new cap.

### Task 19: flag-on fixtures, sims and the CI split

- **Files:** `tests/sim/make_save.gd` (`--fixture=retune`), `export/fixtures/`, `tests/sim_tier/test_retune_sims.gd`,
  `tests/sim_tier/test_tier3_sims.gd` (fixtures of sims 5 and 7; sim 4's gear), `tests/sim_ticks.golden.json`,
  `run_tests.sh` and `.github/workflows/ci.yml` (`sim-tiers-a`, `sim-tiers-b`; main session), branch protection
  (main session).
- **Tests:** spec 8.3. Each fixture-based sim asserts its saved plan equals the planner's; the existing tier-3 sims
  keep their flag-off pins.

### Task 20: the final report

- **Do:** `report_retune.gd --final` once on hold-out set #1; output under `docs/review/media/e6/balance/final/`.
  Any failed target: stop and escalate (D-290.1).

### Task 21: the checkpoint pack

- **Do:** the simulator video (tier-3 dawn with the lane-character step, one purchase through the card), the final
  perf reading (once), `docs/review/E6_RETUNE.md`, spec section 11, REVIEW_QUEUE (banners for the tone check, the
  card idea with its overlap count), `docs/E5_FOLLOWUPS.md`, CLAUDE.md commands. Whole-branch review, one fix wave,
  then STOP for the author.

### Task 22: the flip (after approval)

- **Files:** `balance/tier_balance.gd`.
- **Do:** set the flag to true in a small PR; the Pages deploy check; a post-deploy smoke run on the live main build
  (simulator and emulated Pixel) with a migrated v6 tier-3 save: the dawn shows the lane-character banner.

### Task 23: cleanup

- **Do:** remove the flag, the accessor's off branch, the superseded values, `tools/baseline_t3_off.sh` and its
  file; re-record the tier-3 baseline under `tools/baseline_t3.sh` with its output in the PR; keep every flag-on
  test as the normal test; update REVIEW_QUEUE, DECISIONS (D-286's flag retired) and spec section 11.
