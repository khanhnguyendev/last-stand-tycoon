# E5 follow-ups

Open items from the E5 diner tier ladder build (slice 1, 2026-10-06, PRs #50 to #53). They come from the per-task
reviews and the final whole-branch review; none blocked the checkpoint. Decisions are in `docs/DECISIONS.md` D-236 to
D-259; feel questions are in `docs/REVIEW_QUEUE.md`, section "E5 diner tier ladder, slice 1". Delete a line here when
it is done.

## Owed measurements (one run, after all tasks, milestones and phases are done: D-260)

1. **Perf on the iOS Simulator** for `tier2_night` and `boss_night_tier1`, with the night-3 reference taken the same
   day (spec 8.4): not measured. Commands and gate: `docs/review/media/e5/perf/README.md`. Do not run it between
   phases.
2. **The tier-up dawn on a phone**: ground mesh swap, props re-merge, five pops and the camera move in one dawn. The
   warm-up pre-builds the terrain and props; whether it hitches is unmeasured.

## FINAL REVIEW phone checklist (E5 items; blocks no merge)

- The tier sign: readable, findable from the home spot, the pay ring and the "boss tonight" state.
- The boss bar during a boss night and the boss moon on the HUD (no screenshot of either exists from a device).
- The tier-2 diner and the two yards after the reveal; the reveal's camera move on a notch phone.
- An earlier Simulator attempt (2026-10-06) timed out on a loaded Mac; nothing was captured.

## Before tier 3

4. **Sim budget**: done (D-247). New tier sims go in `tests/sim_tier/` with an entry in `tests/sim_ticks.golden.json`.
5. `tests/sim/sweep_runner.gd` `at_cap` and `actors/bots/tier_bot.gd` `create_for_tier(2)` hard-code tier 2.
6. `world/tier_reveal.gd`: `yard_stones` is one MultiMesh for every open yard; a tier that opens more yards must split
   it per tier before reusing the stones step.
7. `World._ready` builds for whatever tier GameState holds (only reachable in tests); build tier 1 there and call
   `rebuild_for_tier()` once at the end.
8. `core/economy.gd` `night_kills(day)` / `night_gold(day)` now mean pressure and have no production caller.
9. Determinism pins that only hold for shipped balance: the boss-first order relies on `boss_lead > 0`; the lane RNG
   draw order relies on `tier_base[1] == 1` (both pinned by unit tests; make the code robust before tuning either).

## Tick budget (D-247, from its review)

- The start phase of a sim depends on GUT's wall-clock paint pause after a very short previous test (1-tick jitter on
  `test_night1_fail_restarts_night`). Hardening: `await get_tree().process_frame` first in each sim's `before_each`,
  or `-gpaint_after=0.001` for sim suites; confirm with repeat runs.
- `tests/sim/tick_budget_hook.gd`: a parameterized sim would record only its last parameter (GUT emits `start_test`
  per parameter, `end_test` once); keep the first start. No sim is parameterized today.
- `tests/unit/test_tick_budget.gd`: the coverage scan keys an inner-class test as `path::test_x`; the hook uses
  `path::Inner::test_x`. Align them before the first inner-class sim.
- A sim hollowed out to an early `return` still passes the tick budget (fewer ticks are allowed); the guard is the
  golden file's diff in review.

## From the task reviews (deferred minor findings, as logged)

Copied from the build ledger in the order they were logged. Some were fixed later in the build (the phase-2 follow-up
task and the final fix wave: warm-up coverage, the HUD boss moon on restore and its disc, the hare length pin, the
`test_save_tier.gd` isolation, the sim asserts, the boss-moon breath field, the Linux check of the hash pins). Check a
line against the code before working on it.

- **Task 1:** spec 4.4 "+2" sentence — FIXED by main session commit on e5/p1-core; stats(&"boar") reads the global Balance.data not the owning BalanceData (doc line wanted); test_boar_view_follows_a_mutation only mutates speed; fast_share_now has no tier bounds guard.
- **Task 2:** props inside/at the yards (props_layout.gd:67,69,70) → REVIEW_QUEUE + add yard-vs-props assert; east yard shrank to Rect2(8.0,-0.5,5.0,3.5) → REVIEW_QUEUE; test_waypoint_graph.gd:38 hard-codes nw/ne (add lower-bound assert in test_create_for_tier); spec 5.3 stop-point sampling not pinned; tower_w range slack 0.07 m.
- **Task 3:** sweep enemy_count + Economy.night_kills take a day → fix in Task 16 before the re-record (sum the lane_plan counts); pin tier_base[1] == 1 in test_tier_effects (RNG-order invariant now depends on balance); core/ now reads the Balance autoload (lane_planner.gd:11,51, wave_schedule.gd:18) → DECISIONS note or inject boss_hp; boss-first relies on boss_lead > 0 (unstable sort tie) → push_front the boss entry; test_threat_counts_hares_and_the_boss misnamed/weak; test_tier1_schedule_is_unchanged misnamed; baseline_rows.sh: `|| true` on the grep line and validate N; `pressure` parameter shadows the static function.
- **Task 3:** test name `..._with_day8_lanes` no longer checks lanes; defaults-vs-explicit comparison for days 3, 5-7 dropped; oracle day-1 branch not pinned by a literal; `for w in 3` hard-coded; a future tier with base 1 entered after day 1 would drop the side draw.
- **Task 4:** re-plan-after-tier-up assertion weak (compare lane_plan to LanePlanner.plan(..., 2, 9)); test_debug_set_tier pressure line circular (use literal 8); top-tier branch of complete_tier_up untested; debug_set_tier going DOWN a tier leaves tower_w/e in buildings; debug_set_tier accepts day_entered > day; gold_changed fires before tier_paid is written (comment); only tower_w asserted in building_changed test; "paying at night does nothing" lives in the sign (Task 9), not GameState.
- **Task 5:** literal 5 at test_save_tier.gd:27,124; test_save_codec.gd:38-40 passes SCHEMA_VERSION - 2 as current_v; fixture test name says schema_3 but day3_counter5 is v4 and nothing pins on-disk versions; literals 499 and [2]; 3d631d9 is a red bisect point (authorized follow-up commit).
- **Tasks 4+5:** test_save_tier.gd needs after_each Balance.reset() (leaves tier_costs = [0] behind); unused dict values at test_save_tier.gd:127; "other keys unchanged" loop should also compare key sets.
- **Task 6:** test_wave_director new tests create a second Main (shadow the fixture); test_steak_pool... re-derives the formula; AIM_HEIGHT 0.5 and SHADOW_RADIUS 0.7 are constants for the 2.2 m boss (shadow radius is in Task 7's rulings; AIM_HEIGHT for the occluder fade is not).
- **Task 6:** Boar.stats() doc comment exact only for the boar (hare/boss hold the shared resource); mercy test should also assert mercy_factor() < 1.0; monster_balance.gd:37 comment should point at Boar.stats(); test_mercy.gd::test_fail_banner_sequence_end_to_end fails when run alone (pre-existing, order-dependent) → own follow-up.
- **Task 8:** Pulse test lacks top-tier and partial-payment cases; telegraph test comment says "day-1 plan"; tier_paid_up sparkle and sound have no test; spec 7.6 says `build` sound but the manifest id is `build_done` (spec wording to fix in Task 17).
- **Task 7:** boar-mesh SHA-256 pin captured on macOS may differ on Linux CI (watch the `unit` job on the P2 PR; fallback = fixture + per-vertex 1e-5 compare); HUD _refresh_all does not clear icons.boss_alive on state_restored + no test for wave_started/enemy_killed handlers; boss-moon ink disc stays 32 px under a 34-36 px moon (grow the disc; take a boss-night HUD shot); hare belly sphere ignores body_scale; leg-swing pivot/rate fixed for all kinds; Warmup draws only the boar (hare/boss meshes + bar materials first drawn mid-night → hitch, D-215); ART_BIBLE "only non-swatch colour" text + section 6 rows; hare length not asserted; fill_color() reads the static material; comment "31 pooled Boars tick"; renames in boar_mesh; params(kind) dict per spawn; breath 0.06 literal; boar is 1.115 m vs table 1.0 m (pre-existing); spec 7.1 boss lerp 0.4 vs code 0.25 (DECISIONS line).
- **Task 8:** soft `if not offered[0].is_empty()` guard in the top-tier test (assert non-empty instead); a normal dawn with an empty offer leaves a stale GameState.card_offer; literal 500 remains in test_pulse.gd, test_guide.gd, test_game_state_tier.gd; fix-round-2 report lacks the raw GUT line.
- **Task 9:** swatch intent of the sign's UVs unpinned (atlas texel → Palette test); tools/shot_*.gd share copied scaffolding (extract shot_common.gd); spec says "kitbash" but the sign is procedural (REVIEW_QUEUE).
- **Task 8b:** peak-disc test should also assert moon_scale at the peak; report lacks two commands.
- **Task 10:** the first tier-2 open builds the tier-2 terrain (10.5k verts) and re-merges props in the tier-up frame → possible dawn hitch on web; pre-build both in Warmup if the perf reading (Task 17) shows it — candidate for Task 12's dispatch.
- **Task 10:** blank line detaches the items_for doc comment (props.gd:17); the tower_w assert_same cannot go RED with the guard removed (only yard_stones pins it).
- **Task 9:** make_tier_sign_src.gd asserts instead of exiting non-zero + header says deterministic though unique_ids change per run; new bake-material test lacks assert_not_null; nothing pins the generator to the committed scene; tier_sign unbudgeted (same as closeup_sign).
- **Task 13:** threat ordering / tie rule / upgrade pass untested (both tower tests accept either tower); `GameState.day = 2` dead write in the equality test + add assert_ne(planner.next_purchase(), ""); the sign test does not exercise the hold (rename or add pressure); boss_nights_won untested; header comment wording; spec 8.1 text stale vs rulings (Task 17).
- **Task 11:** art/env/src/* ships in the web export (about 11 KB more; add to exclude_filter in a later hot-file pass).
- **Task 11:** lane strips (y 0.02) and lane edge stones draw over the cream terrace where the west/east lanes meet the wall (dirt band across the cream); _forget_gone_nodes drops a detached-but-valid node without restoring its materials (only caller frees it); no test of refresh_bounds() while faded in test_occluder_fade.gd itself; original report sections above "Fix round 2" are stale.
- **Task 12:** no test moves the hero during a reveal; spec 7.5 / section 3 stale (zoom, signature, sound id, CameraMath helper) → Task 17.
- **Task 11:** shot_diner_t2.gd skips the kill silently when the monster is gone + header wording; terrace-top test message omits the lane strips.
- **Task 12:** "still running at 2.9 s" samples at 2.80 s; tier-3 test asserts neither the camera request nor stones visible, and its fx loop can be empty; dead `if st.has("at")`; hard-coded n := 5; stale class doc ("camera pulls back meanwhile"); no RED line quoted for the markers finding.
- **Task 14:** make_save `_write` does not check FileAccess.open (exit 0 on a failed write; comment overstates); smoke test still named "five seconds"; boss_only's boss spawn is exercised only by sim 2.
- **Task 15:** assert last_wave_start_s >= 0 before the print; sim 4 should also assert tier == 2; report's sim-4 line not verbatim; sim 1 "night seconds" includes the dawn/reveal; harness header overstates D-113 (reads wave_director.boss_alive/alive_count/enemy_candidates).
- **Task 16:** sweep_runner reads enemy_count/boss_night once before the first attempt (a non-boss night that fails and is followed by a tier payment in the replayed day would be mis-reported; did not occur); no CI pin of enemy_count(plan) == night_kills(min(day, 7)) for days 1-8.
- **Final fix wave:** test_sweep_math.gd lacks before_each Balance.reset(); redundant assertion wording at test_boss_night.gd:160-161.
