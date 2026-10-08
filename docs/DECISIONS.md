# Decisions

Decisions made without asking, because they are not product calls, plus product calls the author
made. Newest last. Each entry: what, why, and when to revisit.

## 2026-09-29: S1 vertical slice brainstorm

**D-001 Split v0.1 into sub-projects (author).** S1 vertical slice, S2 hero cards + adventurer
guards, S3 save/load + failure & mercy, S4 asset pipeline + art pass, S5 UI/HUD polish, onboarding,
audio, S6 web hardening, QA, itch.io release + playtest gate. Each gets its own spec → plan → build.

**D-002 [AMENDED by D-026, D-054, D-076, D-093] One fixed map with three lanes.** The diner sits center-south, with the road for travelers
along the south edge and the wilds to the north. Three approach lanes (west, north, east) converge on
the diner. Each wave picks a lane, and the edge arrow points at it. There is one fence spot per lane
choke (3) and one tower spot between each pair of lanes (2). Why: the build spots matter every night,
and it needs no free-form placement.

**D-003 Enemies follow lane waypoints; no navmesh.** An enemy walks its lane toward the diner. If a
standing fence sits on its lane, it stops and attacks the fence first. Why: fixed lanes make a
navmesh unnecessary, and the headless sim stays deterministic. Revisit if S2 guards need to leave
posts.

**D-004 Targeting priority is data.** A `TargetPriority` resource lists the target kinds in order.
S1 uses `[fence_on_lane, diner]`, and S2 inserts `guard` between them. Towers are never targets.

**D-005 The hero is not targeted in S1.** This follows from the author's S1 targeting list. There is
no hero HP, knockout or respawn until S2 adds guards to the priority list.

**D-006 Stand-still means the hero's speed stays below a threshold for 0.25 s inside a station zone.**
While the hero stands still, a transfer moves one item per tick (0.08 s, set in Balance).

**D-007 Build by standing and draining gold.** Gold flows into the build spot while the hero stands
on it, and progress is kept if the hero walks away. The remaining cost is shown on the spot. Why:
this is the genre convention, and it fits "things pile up".

**D-008 Pickups are walk-over with a small magnet radius.** Night steaks and gold piles are picked
up by walking near them. Stand-still stays reserved for stations, so the hero can collect while
fighting.

**D-009 One carry stack.** Steaks stack on the hero's back, capacity 6 (Balance). Night pickups use
the same stack. Steaks that don't fit stay on the ground and go to the freezer at dawn. Carried steaks
stay carried through dawn.

**D-010 The counter sells without the hero.** The counter holds up to 12 steaks. Queued travelers
take from it on their own and drop gold on a pile beside it. The queue holds at most 4 travelers,
each buying 1–2 steaks. Travelers come only by day and leave when the night starts.

**D-011 [AMENDED by D-043] Losing restores an in-memory snapshot.** The GameState snapshot is taken on "Close up". When
the diner falls, the game restores that snapshot and returns the player to DAY at the sign, so they
can build before retrying. There is no disk save and no mercy scaling (those are S3).

**D-012 Waves scale with a linear per-day formula in `Balance.tres`.** The enemy count and HP
multipliers grow per day. Starting values are in the spec, and the headless sim tunes them.

**D-013 [AMENDED by D-035, D-057] Test framework: GUT, run headless.** Tests run with `godot --headless`. The night-1 sim
test uses a scripted hero that stands at the diner door and auto-attacks, at a raised
`Engine.time_scale`. Verify that GUT supports Godot 4.7 when writing the plan; fall back to gdUnit4
if it does not.

**D-014 Single-threaded web export.** Why: it runs on itch.io without COOP/COEP headers or
SharedArrayBuffer.

**D-015 Input.** On touch, a floating joystick is spawned where the thumb lands. On desktop, the
same joystick works by mouse drag, plus WASD.

**D-016 Placeholder art uses primitive meshes.** Capsules and boxes, one flat color per role, with
no imported assets in S1. The scenes keep a `Visual` child node, so S4 can swap the art without
touching the logic.

**D-017 Performance budget.** At most 40 live enemies. Enemies, steaks, projectiles and gold coins
are pooled.

**D-018 The hero throws cleavers.** The hero's attack is a short-range projectile. Why: it reads as
a diner cook, and a projectile is easy to see on placeholder art.

**D-019 The hero auto-attacks while moving (author).** Why: "stand still" in IDEA.md means station
interaction (freezer, counter, sign), not combat. With no hero HP in S1, a stand-still attack adds
friction without tension. The genre references auto-attack on the move. The hybrid stays testable
without code changes: `Balance.moving_attack_speed_mult` (float, default 1.0; set it below 1.0 for
the hybrid).

**D-020 Retargeting is on an interval.** The hero targets the nearest enemy in range and re-checks
it every `Balance.hero_retarget_interval` seconds, not every frame.

**D-021 [AMENDED by D-058] Night tension comes from lane choice (author).** The hero's attack range is short enough
that no single position covers all 3 lanes. The night decision is which lane to defend while towers
and fences hold the others. A headless sim proves it: a hero parked at the diner cannot clear night 2
unaided, while a hero that moves between lanes plus 1 tower can. The edge arrow shows the wave source
early, so repositioning is a readable choice.

**D-022 The snapshot is a plain serializable Dictionary (author).** It is built from GameState
through a single `to_dict()` / `from_dict()` pair. S3 save reuses it unchanged.

**D-023 Night steak pickup stays, with no bonus (author).** Steaks already on the hero's back skip
one freezer trip at dawn. "Is night pickup worth it?" is a playtest question in the spec, not a
feature.

**D-024 ASSET_PIPELINE does not exist yet (author).** It is created at the start of S4. The spec
refers to it as "S4 asset pipeline (TBD)".

**D-025 [SUPERSEDED by D-057] The sim test bots are simple scripts.** The "parked" bot stays at the diner door. The
"mover" bot walks to the lane waypoint nearest the most live enemies and re-decides every 1 s.

**D-026 Waves use a main group and a side group from night 2 (author).** Night 1 is one lane per
wave, as in IDEA.md, and stays a tutorial-level night the hero can win alone. From night 2, each wave
has a main group on one lane (big arrow) and a side group on a different lane (small arrow). The side
group spawns `Balance.side_group_delay` s after the main group, so the two arrows read in sequence.
At most 2 active lanes per wave in v0.1. "All 3 lanes" goes to Post-v0.1.

**D-027 Side-group share curve (tunable).** `share(day) = min(0.20 + 0.05 × (day − 2), 0.45)` for
day ≥ 2. `side_group_delay` = 4 s. Both are starting values that the sim tunes.

**D-028 Lane plan is seeded and part of the snapshot (author).** At dawn, the next night's plan (main
lane and side lane per wave) is generated from a seeded RNG, with `seed = hash(run_seed, day)`. The
night-1 plan is generated at new game. The plan is stored in GameState, so it is part of the
Close-up snapshot. A retry replays the same night, which keeps it fair and keeps the sim
deterministic.

**D-029 [AMENDED by D-062, D-093] Day telegraph uses world-space markers only (author).** Each lane entrance has a placeholder
marker, scaled by tonight's threat on that lane. Threat is the total enemy HP planned on the lane
tonight, and the marker scale is lerped from 0.5 to 2.0 against the busiest lane. There are no new
UI screens. Fences on lanes unused tonight are allowed; there is no fence relocation or refund in S1.

**D-030 Sim thresholds live in Balance (starting values).** They are fractions of diner HP left at
dawn:
- `sim_night1_win_min` = 0.50
- `sim_night2_unaided_max` = 0.30 (falling also counts)
- `sim_night2_comfort_min` = 0.60

**D-031 Gameplay lives in scene nodes, and the math lives in pure static helpers.** Nodes and
components hold the behavior. Wave scaling, the lane plan, target selection and balance formulas are
static functions in `core/`, unit-tested without a scene. The sim tests run the real Night scene
headless on fixed physics ticks. Everything runs in `_physics_process`; nothing depends on frame
delta or unseeded randomness. Rejected: a separate pure-logic sim core with nodes as views. It
doubles the structure, and the sims would test a model instead of the game.

**D-032 This folder layout is canonical (author).** `autoload/`, `core/`, `components/`, `actors/`,
`world/`, `ui/`, `balance/`, `tests/unit/`, `tests/sim/`. It replaces the layout in the author's
earlier foundation notes. When CLAUDE.md is written, it must match this layout.

**D-033 Balance is one BalanceData .tres with typed sub-resources (author).** The sub-resources are
`HeroBalance`, `EnemyBalance`, `WaveBalance`, `EconomyBalance`, `BuildBalance` and `SimThresholds`.
This keeps it readable as S2+ adds fields.

**D-034 Determinism rules (author).**
- All randomness comes from named RNG streams derived from `(run_seed, day, stream_name)`. The
  streams are `lane_plan`, `spawns`, `travelers` and `drops`.
- There are no global `randi()`/`randf()` calls anywhere. A grep check in the test suite enforces it.
- Enemies move along their `Path3D` in code on the fixed physics tick. No gameplay decision depends
  on physics queries or Area3D overlap order.
- `Targeting.select()` breaks ties by spawn index, never by node order.
- The hero is a CharacterBody3D, and the sim bot drives it through the same input API the joystick
  uses.

**D-035 Sim speed: `--fixed-fps 60` headless.** It turns off real-time sync, so frames run as fast
as the CPU allows while delta stays exactly 1/60. It is deterministic, faster than real time, and
leaves `Engine.time_scale` at 1. Budget: the whole sim suite runs in under 60 s. Verify the flag's
behavior under Godot 4.7 while writing the plan; the fallback is `Engine.time_scale` plus a raised
`max_physics_steps_per_frame`.

**D-036 State restore contract (author).**
- `GameState.from_dict()` emits `state_restored`. Every stateful node (BuildSpot, Freezer, Counter,
  GoldPile, the diner, lane markers) rebuilds its visuals and behavior from GameState alone when it
  gets that signal. No hidden state lives in nodes.
- On Close-up, coins are auto-collected into gold and ground steaks go to the freezer before the
  snapshot is taken, so the snapshot never contains world items.
- A test snapshots the state, mutates everything, restores, and asserts the world matches.

**D-037 EventBus discipline (author).**
- The bus carries cross-system events only. Parent/child and component-to-owner communication uses
  local signals.
- The bus adds `state_restored`, `night_failed`, `steak_picked`, `steak_sold` and
  `build_completed`.
- Every signal's arguments and types are documented in `EventBus.gd`.

**D-038 Day numbering.** The day phase before night N has `day == N`. The game starts with
`day = 1` at night 1. Dawn increments `day`, so night N is fought with `day == N`. Dawn generates
the lane plan for the new `day`.

**D-039 Close-up needs a 1 s hold.** After the stand-still threshold, a ring fills for 1 s before
the night starts, so a player walking past can't start it by accident.

**D-040 [SUPERSEDED by D-068] Close-up pulse rule.** The sign pulses when:
- freezer, carried and counter steaks are all 0;
- the gold pile is 0;
- gold is below the remaining cost of every unbuilt spot.

**D-041 New-game seed.** `run_seed` comes from a hash of the system clock at new game. This is the
only non-derived randomness, and it is allowed by the grep check. Tests pass an explicit seed. The
snapshot dict carries a schema version `v: 1`, for S3.

**D-042 [SUPERSEDED by D-043] A new game takes a snapshot immediately.** If night 1 fails, the game restores to DAY 1 at
the sign (0 gold, nothing to sell), and the sign pulses. There is no special case for night 1.

## 2026-09-30: S1 brainstorm, section 2 review

**D-043 The snapshot records `resume_phase` (author; reverses D-042).** The new-game snapshot has
`resume_phase = NIGHT`, so failing night 1 shows the banner and restarts night 1 directly, with the
~5 s first spawn. Every Close-up snapshot has `resume_phase = DAY`, with the hero at the sign.
Why: an empty DAY with 0 gold is a dead end for a first-time player, and the first session is what
the v0.1 gate measures. A sim test covers the night-1 fail → restart path.

**D-044 Wave-clear condition (author).** A wave is cleared only when all its planned spawns (main
and side group) have spawned and its alive count is 0. Killing the main group before the side group
spawns does not start the breather. A unit test covers it.

**D-045 No in-flight state at snapshot time (author).** A traveler purchase is atomic: the steak and
gold move in one step when the traveler reaches the counter, with no reserved steaks. Departing
travelers hold nothing. `paid` on build spots persists in GameState. The restore test asserts that
there are no pending transactions.

**D-046 Pause on focus loss (author).** The tree pauses on `NOTIFICATION_APPLICATION_FOCUS_OUT`
and on a web `visibilitychange` to hidden (through a `JavaScriptBridge` listener), and resumes on
focus in or visible. A `FocusPause` node in Main handles it. S6 only verifies it on devices.

**D-047 Debug aids, in debug builds only (author).**
- An overlay shows `run_seed`, day, phase, wave, alive enemies and fps.
- Hotkeys: +100 gold, skip to DAY, skip to NIGHT, kill all, force diner fall.
- They are gated by `OS.is_debug_build()` and live in `ui/debug/`. The release web export preset
  excludes `ui/debug/*`, and S6 verifies it.

**D-048 The S3 save point is the Close-up snapshot (author).** Quitting mid-night in S3 restores it,
which matches IDEA's "quitting mid-night costs exactly the same". This goes in the S3 line of the
decomposition.

## 2026-09-30: S1 brainstorm, section 3 choices

**D-049 Enemy targeting uses per-kind providers.** Each physics tick, an enemy walks
`TargetPriority` in order and asks the provider for each kind whether a target exists. The first hit
wins; with none, the enemy walks. S1 has two providers:
- `fence_on_lane`: the fence on this lane is standing, and the enemy is within attack range of it.
- `diner`: the enemy is at the end of its path.

S2 adds a `guard` provider and does not touch the enemy code.

**D-050 Projectiles home in.** Cleavers and tower bolts home on their target and deal damage on
arrival. If the target dies mid-flight, the projectile despawns. Why: no miss logic, and it stays
deterministic.

**D-051 Spawn lateral offset.** Each enemy gets a lateral offset of ±1 m from the path, drawn from
the `spawns` stream, so that a group doesn't render as a single capsule.

**D-052 [SUPERSEDED by D-054] Lane geometry test.** A unit test asserts that `hero.range` is smaller than the radius of
the smallest circle through the three lane midpoints. That is the geometric form of "no single
position covers all 3 lanes" (D-021).

**D-053 Wave size cap.** At most 30 enemies per wave (within the 40-live budget). Scaling beyond the
cap goes into HP. With no hero growth until S2, late days in S1 become unwinnable; the S1 loop only
needs to keep running, not to stay winnable.

## 2026-09-30: S1 brainstorm, section 3 review

**D-054 The diner has a footprint, with a per-lane attack zone on its wall (author; geometry chosen
here).**
- The diner is 8×8 m, centered at the origin, with north = −z.
- Each lane ends at an attack zone on its own wall. The zone is 1.2 m out (enemy reach), 3 m wide:
  - west: x = −5.2, z ∈ [−1.5, 1.5]
  - north: z = −5.2, x ∈ [−1.5, 1.5]
  - east: x = +5.2, z ∈ [−1.5, 1.5]
- Enemies stop in their lane's zone and never path around to the door.
- Hero range drops from 5 m to 4 m.
- [SUPERSEDED by D-123] Geometry test A: the smallest circle enclosing all three zones has a radius of about 5.41 m, which
  must be greater than hero range + 1 (5.0). No hero position covers all three walls.

**D-055 [AMENDED by D-076, D-093] Tower and fence spots are placed for coverage.**
- Tower spots are at (−5, −5) and (+5, −5), range 7.
- Geometry test B: each tower reaches every point of the attack zones of its two adjacent lanes. The
  worst case is 6.5 m, within 7.
- Fence spots are 4 m outside each attack zone: (−9.2, 0), (0, −9.2), (+9.2, 0). An adjacent tower
  also covers its fence (about 6.5 m), which makes "fence + tower" the natural combo.
- Lanes run about 16 m from entrance to attack zone.

**D-056 The night-1 test uses NaiveBot, not ParkedBot (confirmed by author).**
- Why: after D-054, a hero at the diner center is at least 5.2 m from every zone, with range 4. It
  kills nothing, so "night 1, ParkedBot ≥ 50%" cannot pass. The same holds for any parked spot, by
  design.
- The night-1 test is now: NaiveBot ≥ 50%.
- ParkedBot becomes a negative control: night 1, ParkedBot at the diner center → the diner falls.
  That proves parking is not a strategy.

**D-057 [AMENDED by D-091] Sim bots (author).** All bots use the `HeroInput` API.
- ParkedBot: stands at the diner center and never moves.
- NaiveBot: goes to the current wave's main-lane attack zone, kills everything in range, then goes to
  the nearest lane with alive enemies. It builds nothing.
- PlannerBot: NaiveBot at night. In the DAY it hauls and sells until every steak is sold, collects
  gold, then spends it following the telegraph: a fence on the highest-threat side lane first, then
  the tower adjacent to it, then more fences. Then it closes up.
- Bots move between points through a fixed waypoint graph (the 4 diner corners, the station fronts
  and the lane zones). No navmesh.

**D-058 Sim tests (author).**
- Night 1, NaiveBot: ≥ 50% (D-056).
- Night 1, ParkedBot: falls (D-056).
- Night 2, NaiveBot, no builds: ≤ 30% or falls.
- Night 2, PlannerBot after a real night 1 and a real day 1, with no dev gold: ≥ 60%.
- Night-1 fail → restart (D-043).
- Same seed → same lane plan and same outcome.

**D-059 Difficulty sweep report (author).** `tests/sim/sweep.gd` runs PlannerBot through days 1–10
and writes `tests/sim/out/sweep.csv`. Each row is one night: day, diner HP left, steaks, gold, builds
and enemy count. It is a report, not pass/fail. Failure is expected around day 4–6 and records a
target for S2 card power. `tests/sim/out/` is gitignored.

**D-060 Projectile rule, restated (author).** Damage applies on hit only. If the target dies
mid-flight, the projectile despawns, with no retarget and no damage carry.

**D-061 [AMENDED by D-124] Pools are sized from the Balance caps (author).**
- Enemies: max wave size (30) × 1 wave alive at a time, plus 10, which gives 40.
- Ground steaks: `ceil(sum of the day-10 counts × steaks_per_kill × 1.2)`.
- Projectiles: 24.
- Coin FX: 32.
- A pool that grows at runtime logs a warning and shows it on the debug overlay.

## 2026-09-30: S1 brainstorm, section 4 choices

**D-062 [AMENDED by D-092] Station layout (south side, the diner front).** Coordinates:
- Counter: along the south wall, at (0, 4.8).
- Gold pile: (−2.5, 5.5).
- Freezer: (5.5, 5).
- Close-up sign: (0, 8).
- Road: east–west at z ≈ 11. The traveler queue runs from the counter south toward the road.

The telegraph markers sit just outside each fence spot, not at the lane entrance, so they are on
screen while the player is choosing where to build.

**D-063 Two steaks per kill; 3 gold per steak (confirmed by author).**
- `steaks_per_kill` = 2 (changed from 1) and `gold_per_steak` = 3.
- Why: twice the stack, the more visible pile and more hauling make the day long enough for the 4–6
  min cycle; with 1 steak per kill the day ran about 1 min. Pillar 1: things pile up.
- Night-1 economy check: 18 kills × 2 × 3 = 108 gold, against 60 (tower + fence), a margin of 1.8×.

**D-064 Traveler flow.**
- A traveler spawns every 2.5 s (±0.5 s jitter from the `travelers` stream) while the queue is
  under 4.
- Each wants 1–2 steaks. Service takes 1.0 s, then an atomic transfer of `min(want, counter)` steaks
  and gold.
- If the counter is empty, the front traveler waits. Travelers are not in GameState.

**D-065 Build payment rate.** A build spot drains `ceil(cost / 20)` gold per 0.08 s tick, so any
build finishes in about 1.6 s of standing.

**D-066 Cycle time is measured, not asserted.** The sweep CSV adds `night_seconds` and
`day_seconds` (PlannerBot plays efficiently, so these are a lower bound). The estimates:
- The night-1 cycle is about 3 to 3.5 min.
- From night 2 on, a cycle is about 4 min or more.

The 4–6 min criterion is judged at the human playtest.

## 2026-09-30: S1 brainstorm, section 4 review

**D-067 Built spots become upgrade spots (author; values chosen here).**
- Stand still on a built tower or fence to pay for its next level, with the same drain as building.
- Max level 3. Each level's cost is the previous cost × `BuildBalance.level_cost_mult` (2.0).
  - Tower: 40 → 80 → 160.
  - Fence: 20 → 40 → 80.
- Tower levels: damage ×1.5 per level (8 → 12 → 18), range +0.5 m per level (7 → 7.5 → 8), rate
  unchanged.
- Fence levels: HP 120 → 200 → 320.
- Placeholder visual: the model scales ×1.1 per level and gets one pip per level.
- A building entry in GameState is `{level, paid, hp}`. Level 0 means unbuilt, and `paid` counts
  toward the next level.
- A destroyed fence resets at dawn to `{level: 0, paid: 0}`. Rubble loses its upgrades, so fences
  stay a recurring sink.
- The total one-time sink is about 980 gold. Kills on nights 1–5 yield about 912 gold. That fits the
  target of keeping `unspent_gold_at_closeup` low through day 5.
- PlannerBot spends leftover gold on upgrades, highest-threat lane first.
- The sweep CSV adds `unspent_gold_at_closeup`.
- No new spots and no new building types.

**D-068 Sign pulse predicate (author; replaces D-040).** `should_pulse` is true when all of these
hold:
- `freezer_steaks == 0`
- `carried_steaks == 0`
- `counter_steaks == 0`
- `gold_pile == 0`
- for every spot with `level < 3`: `gold < next_level_cost(spot) − spot.paid`

It is a pure function in `core/`, with a unit test.

**D-069 No re-planning after a loss (author).** Restoring the Close-up snapshot keeps the builds as
they were. This is accepted for S1 and consistent with IDEA. Playtest question: "After a loss, does
the player feel they had agency?" S3 mercy addresses it. There are no refunds or respec.

## 2026-09-30: S1 brainstorm, section 5 choices

**D-070 Joystick.**
- Touch anywhere spawns the base under the thumb. The knob's max radius is 64 px (720-wide base),
  with a 0.15 deadzone. It is hidden when nothing touches the screen.
- The mouse drag works the same way; WASD overrides it when pressed.
- Everything goes through `HeroInput.set_move(Vector2)`.
- "Standing still" means speed < 0.1 m/s.

**D-071 [AMENDED by D-090] Camera.**
- Perspective, FOV 50, pitch −55°, fixed yaw, about 18 m from the hero.
- It follows the hero with a smoothing rate of 8/s, clamped to the map bounds: x ∈ [−24, 24],
  z ∈ [−24, 14].
- The visible ground is about 14 m wide at the hero.

**D-072 Viewport.** The base is 720×1280, stretch mode `canvas_items`, aspect `expand`, and portrait
orientation.

**D-073 World-space UI for stations.**
- Costs and counts use a billboard `Label3D`.
- The stand-still progress ring is a flat quad with a tiny arc-fill shader (one `progress` uniform),
  shared by every station.

**D-074 Text and font.**
- Every user-facing string goes through `tr()`, with the English text as the key. There is no
  translation file yet.
- The theme font is Nunito (OFL), which covers Vietnamese diacritics. Its license is logged in
  `docs/ASSET_LICENSES.md` when it is added, per IDEA.

**D-075 Placeholder look.**
- Every object is a primitive mesh with a flat-colored material.
- One DirectionalLight, no real-time shadows in S1 (for mobile web performance).
- Hit feedback: a 0.08 s white flash on the hit enemy.
- Death: a scale-down tween, then the steaks pop out.
- The diner HP bar shakes when the diner is hit. Everything else waits for S5.

## 2026-09-30: S1 brainstorm, section 5 review

**D-076 Lane visibility check, and side lanes entering from the top (author's check; fix chosen
here).**
- Check (a test): with the hero standing at any lane's attack zone, an incoming Boar is on screen for
  ≥ 2.0 s before it enters hero range. It is verified by a camera projection test plus one 720×1280
  screenshot per lane.
- Worked out on paper with D-071, the old straight west lane fails it. The visible half-width is
  about 7 m, so a Boar is on screen only about 3 m (1.5 s) before it is in range.
- So the preferred fix is adopted now, not after the screenshots. Lane entrances move to the top of
  the map (NW, N, NE). The west and east lanes curve down to their existing wall zones, and their
  last 8 m approach from within 45° of north. On the same numbers, the 45° worst case gives about
  5.9 m (about 3.0 s) on screen.
- The D-054 zones and tests A and B are unchanged. The fence spot is defined as the point on the lane
  path 4 m before the zone. New test C: the adjacent tower reaches its fence spot.
- The screenshots confirm or refute this during implementation.
- Fallback (pull the camera back or widen the FOV) applies only if the check still fails, and only
  while the Boar stays at least 40 px tall at 720 width.
- All geometry tests re-run after any change to a path.

**D-077 Mobile browser shell (author).**
- The custom web export HTML sets `touch-action: none` and `overscroll-behavior: none` on `html`,
  `body` and the canvas, plus:
  - `user-select: none` and `-webkit-touch-callout: none`;
  - `contextmenu` prevented;
  - `<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1,
    user-scalable=no, viewport-fit=cover">`.
- The result: no pull-to-refresh, pinch zoom, double-tap zoom, long-press selection or context menu.
- The HUD `CanvasLayer` is inset by the safe area. It uses `DisplayServer.get_display_safe_area()`;
  on web, where that may return the full window, it reads CSS `env(safe-area-inset-*)` through
  `JavaScriptBridge`. Verify which path works in Godot 4.7 web while writing the plan.
- The joystick ignores touches that start within `UiTuning.edge_ignore_px` (16) of the left or right
  edge.

**D-078 Minimal juice budget (author).** All of it uses tweens, with no new assets and no audio.
- Every steak and coin transfer between stacks flies on an arc (0.15 s, apex 0.6 m).
- The gold HUD number punch-scales on change (×1.25, 0.12 s).
- The camera shakes when the diner is hit: amplitude 0.12 m, 0.15 s, at most once per 0.5 s.
- A build or upgrade completion pops (scale overshoot ×1.2, 0.2 s).
- The values live in a `UiTuning` resource at `balance/ui_tuning.tres`, separate from gameplay
  `BalanceData`.

**D-079 Fonts and glyphs (author).**
- Nunito applies to both the Theme (Control) and every `Label3D`, through a shared `WorldLabel`
  scene, since `Label3D` does not read the Theme.
- A unit test asserts `font.has_char()` for every character of "Quán ăn mở cửa — Đêm thứ 3".
- There is one license file for the whole project, `docs/ASSET_LICENSES.md`. S4 appends to it.

## 2026-09-30: S1 brainstorm, section 6 choices

**D-080 Test tiers inside the D-032 layout.**
- `tests/unit/` holds the pure `core/` tests and the single-scene integration tests (stations,
  restore, dawn, close-up, focus pause, glyphs, camera projection).
- `tests/sim/` holds the bot-driven night and day sims and the sweep.
- No new top-level folders.

**D-081 [AMENDED by D-084] The 60 fps check is manual in S1.**
- The device is the author's own phone, plus desktop Chrome.
- The run: a debug web build with the fps overlay, fighting night 3.
- Pass: average ≥ 58 fps and no frame over 100 ms over 60 s of combat.
- S6 re-checks it on more devices.

**D-082 [AMENDED by D-083] S1 phone playtest uses a LAN static server.** The release web export is served with a
static HTTP server on the LAN (single-threaded, so it needs no special headers), and the phone opens
it. An itch.io draft upload is optional and the author's call; S6 owns the real itch.io page.

## 2026-09-30: S1 brainstorm, section 6 review

**D-083 The gate is played from an itch.io draft (author; amends D-082).**
- [AMENDED by D-135: S1 phone testing and the gate use the GitHub Pages URL; the itch.io draft moves to S6.]
- LAN serving stays for quick iteration.
- The criterion-5 gate session is played from an itch.io draft or restricted page, because the real
  iframe embed changes touch handling, the safe area, sizing and fullscreen.
- DoD: the release build is uploaded as a draft, the embed is portrait 720×1280 with mobile-friendly
  and fullscreen on, and it loads and plays on the author's phone from that page. The author does the
  upload.
- If plain-http LAN breaks anything in the 4.7 web build (secure-context features), log it and use
  itch.io for phone testing.

**D-084 Performance is measured on a "profile" export preset (author; amends D-081).**
- There are three presets: `debug`, `profile` and `release`.
- `profile` has release optimizations and only an fps/frame-time overlay: no cheats and no
  `ui/debug/` hotkeys.
- Criterion 4 is measured on `profile`, and the phone model is recorded with the result.
- If the phone is clearly high-end, criterion 4 is marked "not validated on mid-range" and carried
  as a risk into S6. It does not block S1.
- The overlay is gated by the feature tag `profile_overlay`, and only the `profile` preset enables
  it.

**D-085 First combat within 30 s (author, from IDEA).**
- Sim test: from a new game, the first Boar enters hero range in ≤ 30 s of game time.
- Baseline, recorded but not a gate: the real-world time on the author's phone from page open to
  first combat, including load.

**D-086 Web baseline, recorded but not a gate (author).** The spec's results section records:
- the release build size (wasm + pck, compressed as served);
- the phone load time.

This is what S4 and S6 measure against.

**D-087 CI (author).**
- A GitHub Actions workflow downloads Godot 4.7 headless and runs the unit and sim suites plus the
  grep ban on every PR.
- Green checks are required before merge. Branch protection is the author's call; the plan only
  documents it.
- The sweep stays manual.

**D-088 Six playtest questions (author).** Two are added to the four from section 6:
- "Did you know what to do next without being told?"
- "At which moment did you most want to keep playing, and where did it drag?"

**D-089 Spec rules (author).**
- The spec states final values and cites D-ids; DECISIONS.md keeps the rationale.
- No superseded D-id is cited as active.
- It is written for an implementer who hasn't seen the brainstorm.
- It includes a Post-v0.1 appendix and a suggested build order (not tasks).

## 2026-09-30: spec write-up (details fixed while writing the spec)

**D-090 The camera keeps width (amends D-071).**
- `Camera3D.keep_aspect = KEEP_WIDTH` with a horizontal FOV of 42°, which gives about 14 m of ground
  width at the hero. The vertical FOV is about 69°, so the visible ground runs from about 10 m south
  to about 28 m north of the hero.
- Why: Godot's default `KEEP_HEIGHT` with FOV 50 in portrait shows only about 9.4 m of width, not the
  14 m that D-071 and D-076 assumed.

**D-091 [AMENDED by D-122, D-126] The hero's home is (0, 8), at the sign (amends D-057).**
- New game, every restore and ParkedBot all place the hero at home.
- The diner footprint is solid, so ParkedBot parks at home rather than at the diner center. That is
  8.3 m from the nearest zone point, more than the 4 m range, so the negative control still holds.

**D-092 Front-of-house detail (refines D-062).**
- The counter is a 3×1 m box at (0, 4.8).
- The hero's drop zone is at the counter's east end, (2.2, 4.8), 3.3 m from the freezer zone.
- The traveler service point is (0, 6.0), and the queue slots run south-west: (0, 6.0),
  (−1.2, 7.0), (−2.4, 8.0), (−3.6, 9.0), so they clear the sign.
- Travelers enter from the road's east end (24, 11) and leave to the west (−24, 11).
- The freezer is a 1.5×1.5 m box at (5.5, 5), with its zone at (5.5, 6.3).
- Station zone radius: 1.0 m; build-spot radius: 1.2 m.

**D-093 Lane paths (refines D-055 and D-076).**
- North: (0, −24) → (0, −5.2).
- West: (−16, −24) → (−11, −11) → (−5.2, 0). East mirrors it.
- The west and east final legs are 12.4 m at 27.8° off north.
- Fence spots sit 4 m before the zone along the path: north (0, −9.2), west (−7.06, −3.54), east
  (7.06, −3.54).
- The telegraph marker sits 1.5 m up-path from the fence spot and is hidden when the lane's threat is
  0.
- Enemy stop points must lie within the zone rectangle. Test D samples lateral offsets to check it.
- Checked on paper: A 5.41 > 5.0; B worst case 6.5 ≤ 7; C NW tower to the west fence 2.5, to the
  north fence 6.53 ≤ 7; the west path passes 2.5 m from the NW tower.

**D-094 [AMENDED by D-125] Collisions.**
- The hero (CharacterBody3D) collides with the diner, counter, freezer and towers. It does not
  collide with fences, enemies, travelers or pickups.
- Enemies and travelers are moved in code, with no physics bodies.
- Why: the bots need no navigation around fences, and a player can step over a fence.

**D-095 Night 1, wave 1 always comes from the north.** North is straight up the screen, which is the
most readable first threat. Every other wave's lanes come from the `lane_plan` stream.

**D-096 GameState owns all mutation.**
- State changes only through GameState methods, which emit the matching bus signals. No other code
  writes GameState fields directly.
- Station transfers change state on the tick. Tweens are visual only and never hold state.

**D-097 [AMENDED by D-108] RNG derivation.** The seed is FNV-1a 64 over the string `"<run_seed>:<day>:<stream>"`,
passed to `RandomNumberGenerator.seed`. Why: Godot's `hash()` isn't guaranteed stable across
versions.

**D-098 Infra folders outside the D-032 game layout (confirmed by author).**
- `addons/` (third-party, GUT only), `export/` (the web shell HTML), `.github/` (CI) and `docs/`.
- None of them contain game code. Confirmed by the author, and recorded in the CLAUDE.md layout section.

**D-099 How the overlays load.**
- The debug overlay is loaded with `load()` only when `OS.is_debug_build()`, never with `preload`, so
  `release` and `profile` can exclude `ui/debug/*`.
- The perf overlay is `ui/perf_overlay.tscn`. It shows only when `OS.has_feature("profile_overlay")`.

**D-100 Wave count arithmetic.**
- `total = round(base[w] × (1 + count_growth × (day − 1)))`.
- If `total > 30`: `hp_mult ×= total / 30`, then `total = 30`.
- `side = 0` on day 1. From day 2: `side = max(1, round(total × share(day)))`.
- `main = total − side`.

**D-101 An attack zone is a band, not a line (refines D-054).**
- Each zone is the rectangle between its wall and the reach line. West: x ∈ [−5.2, −4.0],
  z ∈ [−1.5, 1.5]; north and east follow the same pattern.
- The path ends on the reach line. Lateral offsets may put a stop point anywhere inside the band.
- Test A's radius (5.41) is unchanged, because the far corners set it.

## 2026-09-30: spec review

**D-102 Spec-time details confirmed (author).**
- D-090, D-091, D-092, D-094 and D-095 are confirmed.
- ParkedBot stays a negative control; test A remains the formal guarantee.
- The hero walks through fences, but enemies are still blocked until the fence is destroyed.

**D-103 [AMENDED by D-131: no timebox] Balance tuning timebox and priority (author).**
- 2 working days of sim-driven tuning. If the targets conflict, this is the priority:
  1. Night 1, NaiveBot ≥ 50%: must hold.
  2. Night 2, PlannerBot ≥ 60%: must hold.
  3. Night 2, NaiveBot ≤ 30%: may relax to ≤ 45%, with the relaxation logged.
- If 1 and 2 can't both hold, stop and escalate with the sweep data. No design changes by the
  implementer.

**D-104 [AMENDED by D-131: no timebox] Spike first (author).**
- The plan's Task 0 is a fail-fast spike over spec Appendix B, timeboxed to half a day. The
  pre-agreed fallbacks:

  | Finding | Fallback |
  |---|---|
  | GUT broken on 4.7 | gdUnit4, or a minimal custom headless runner |
  | `--fixed-fps` not stepping as expected | `Engine.time_scale` |
  | Safe area not reported on web | CSS `env()` through `JavaScriptBridge` |
  | Plain-http LAN breaks something | Phone tests only through the itch.io draft [AMENDED by D-135: through the HTTPS GitHub Pages URL] |

- Each result is logged as a decision before Task 1 starts.

**D-105 Cross-platform sim policy (author).**
- Determinism tests compare two runs on the same machine, in the same process.
- Pass/fail sims assert thresholds only, never exact outcomes.
- CI (Linux) is canonical for sim thresholds. If a local run disagrees with CI, CI wins; investigate
  only when the difference exceeds 5 percentage points of diner HP.

**D-106 Perf and load are recorded, not blocking (author).** They are carried as S6 risks.

**D-107 Gate answers are tagged (author).**
- Each playtest answer in the results section is tagged "loop" or "presentation
  (art/audio/onboarding)".
- A loop problem means revisiting the design before S2.
- A presentation-only problem does not block S2; it becomes input to S4 and S5.

## 2026-09-30: S1 plan write-up (details fixed while writing the plan)

**D-108 RNG hash is FNV-1a 32 (amends D-097).** GDScript ints are 64-bit, and the FNV-1a 64 multiply
overflows (undefined in the engine's C++). The 32-bit variant, masked with `& 0xFFFFFFFF`, never
overflows. A 32-bit seed is plenty for the streams.

**D-109 Extra EventBus signals.** The plan needs five signals the spec's list lacks:
- `stocks_changed()`: freezer, carried, counter or gold_pile changed. Listeners re-read GameState.
- `closeup_requested()`: the sign asks PhaseController to start the night.
- `banner_requested(text: String)`: PhaseController asks the HUD for a banner.
- `wave_incoming(wave_index: int, main_lane: StringName, side_lane: StringName)`: the edge arrows
  show from the breather start.
- `wave_spawned_out(wave_index: int)`: the arrows hide after the last spawn.

`state_restored` is also emitted by `GameState.new_game()`, meaning "GameState was replaced
wholesale".

**D-110 [AMENDED by D-128] PhaseController is the one orchestrator.** It holds injected references to WaveDirector,
TravelerSpawner, the pools and the hero, and calls them directly, so the ordering of the dawn and
close-up steps is explicit and testable. This is the only exception to spec 3.7's "no system
reaches into another's nodes".

**D-111 Enemy lateral offset blends into the zone (refines D-093).**
- Over the last `EnemyBalance.offset_fade_distance` (3.0 m) of the path, the perpendicular offset
  blends linearly onto the zone's width axis (z for west and east, x for north).
- The stop point is therefore always inside the zone rectangle (test D), and the path keeps
  ≥ 1.5 m from the towers and ≥ reach from the diner (test E).

**D-112 [AMENDED by D-125] Collider and bot geometry.**
- [AMENDED by D-125, D-144: edges must clear the hero colliders; `e_mid` (7.0, 3.0) added.]
- The tower collider radius is 0.5 m and the hero radius 0.4 m.
- The bots' stand points for the tower spots are 1.06 m out from the tower center, away from the
  diner.
- The bot waypoints are the diner corners at (±7, −7) and (±6.8, 6.8), plus `front_e` (3, 6.5).
- The camera focus is clamped to x ∈ [−17, 17], z ∈ [−20, 8].

**D-113 Sims read the diner result without new state.** The harness tracks the lowest `hp_left`
seen on `diner_damaged` during a night. That equals the HP at dawn, since HP only drops at night.

**D-114 Balance defaults live in the resource scripts.** The `.tres` files only reference the
scripts. Tuning edits the script defaults, which keeps the diffs readable.

**D-115 Debug hotkeys.** G: +100 gold. J: skip to DAY. N: skip to NIGHT. K: kill all. F: force the
diner to fall. Debug builds only.

## 2026-09-30: PR #1 review fixes

(D-116 to D-120 stay reserved for the Task 0 spike results; see the plan's Task 0.)

**D-121 Station zones arm on entry (author).**
- A `StationZone` works only after the hero walks into its radius while the zone is active.
- A hero who is already inside when the zone activates (a phase change), or who is teleported in
  (a restore or new game), must leave and re-enter first.
- The zone disarms on `phase_changed`, on `state_restored` and on any hero teleport
  (`Hero.teleport_serial`).
- Why: before this, a restore to DAY put the hero on the sign and started the night after about
  1.25 s with no intent, and a hero standing on a build spot at dawn drained gold without asking.
- Tests:
  - a restore to DAY followed by 5 s of no input stays in DAY with gold unchanged;
  - at dawn inside a build-spot zone, nothing is paid until the hero exits and re-enters;
  - a teleport into a zone does not arm it;
  - a normal walk-in works.

**D-122 HOME moves off the sign to (0, 9.5) (author; amends D-091).**
- (0, 9.5) is outside every zone: 1.5 m from the sign (radius 1.0) and 4.7 m from the gold pile
  (magnet radius 1.5).
- The sign stays at (0, 8). The waypoint graph gets a `sign` node (edge home–sign). Bots close up by
  walking to `sign`, and ParkedBot stays at `home`.

**D-123 Geometry test A′ replaces the enclosing-circle test (author; supersedes the D-054 test
wording).**
- The old assertion (the minimal enclosing circle of the zone corners > range + 1) only proved that
  no point reaches every corner. It did not prove that no reachable point reaches an enemy in all
  three lanes.
- Test A′:
  - Sample hero-reachable positions on a 0.25 m grid inside the map bounds, excluding the diner,
    counter and freezer grown by the hero radius (the hero's only colliders, D-125).
  - For each position, count the lanes that have a possible enemy stop point within hero range. The
    stop points come from the D-111 model, sampled over the full ±1 m lateral spread.
  - Assert that no position reaches all 3 lanes.
  - Print the 2-lane positions per lane pair as info, and print the old 5.41 radius as info only.
- On paper: 28,148 reachable positions and a maximum of 2 lanes. West+north is reachable from 16
  points and north+east from 16, all at the NW and NE diner corners. West+east is impossible,
  because the west and east stop lines are 10.4 m apart, more than 2 × range.

**D-124 The steak pool is sized from the CAPPED day-10 counts (author; amends D-061).**
- The prewarm is `ceil((17 + 25 + 30) × steaks_per_kill × 1.2)` = 173, not 180. A night never
  spawns more than `max_wave_size` Boars per wave.
- The same pass synced the spec with D-108 to D-115:
  - 3.5 says FNV-1a 32;
  - the 3.2 EventBus table has the five D-109 signals;
  - 3.7 documents the D-110 orchestrator exception;
  - 6.5 describes the D-111 offset model and `offset_fade_distance`;
  - the `LanePlanner.plan(run_seed, day, wave_balance)` signature is used throughout;
  - the telegraph threat uses `Balance.enemy.hp`.
- Every Balance literal in the spec is annotated with its field name. In the plan, only the
  pinned-reference tests assert default numbers; every other test derives its numbers from Balance.

**D-125 Towers don't collide with the hero (author; amends D-094 and D-112).**
- The hero collides only with the diner, counter and freezer.
- Why: between a tower at (±5, −5) and the diner corner at (±4, −4) there is only about 0.9 m
  before radii, so joystick players and bots would snag.
- `TOWER_BODY_RADIUS` becomes `TOWER_VISUAL_RADIUS` (mesh only). Towers keep the same rule as
  fences.
- The waypoint test checks that every edge is traversable with hero-radius clearance against the
  remaining colliders.

**D-126 A new game spawns the hero north of the diner (author; amends D-091).**
- A new game and every night-1 restart place the hero at `MapLayout.NIGHT1_START` = (−2.5, −7). That
  is north of the diner, 2.5 m off the north lane (beyond the ±1 m spread plus the hero radius) and
  outside every station and build zone.
- Night 1, wave 0 is always north, so combat comes to a new player with no map knowledge.
- HOME (0, 9.5) stays south for restores to DAY. ParkedBot stays at HOME, so it remains a valid
  negative control (it walks home before the first Boar arrives).
- First combat on paper:
  - an idle player at the start meets the first Boar at about 11.9 s (it spawns at 5 s and is in
    range at z ≈ −10.1);
  - NaiveBot meets it at about 12.4 s;
  - an idle player at the old home never met it at all.
- The plan adds an idle-player first-combat sim (≤ 30 s) next to the NaiveBot one.

## 2026-09-30: PR #1 review, part 2

**D-127 [SUPERSEDED by D-131] Velocity tracking and the budget rule (author).**
- Every plan task has an **Actual (h)** field that the implementer fills in when the task is done.
  6 h counts as 1 working day.
- At CP1: `r = actual days for Tasks 0–20 ÷ 8.0 planned`, and the S1 forecast is
  `actual + (18.5 − 8.0) × r`.
- Pre-agreed rule: if the S1 forecast at CP1 is over 3 weeks (15 working days), the v0.1 budget
  extends to 8 weeks. The core loop and the S2 cards are never cut. Further room comes from
  `docs/CUT_CANDIDATES.md` in rank order.
- Note: the 18.5-day baseline is itself over 3 weeks, so the rule applies unless Phases 0–5 run at
  least 19% faster than planned.

**D-129 Official, checksum-verified Godot, one pinned version (author).**
- The editor, the export templates and the CI binary come only from the official
  `godotengine/godot-builds` GitHub releases, which godotengine.org links to.
- Each archive is verified against that release's `SHA512-SUMS.txt`. The script stops on a missing
  line or a mismatch.
- The exact tag from D-116 is pinned as `GODOT_TAG` in CLAUDE.md and in `.github/workflows/ci.yml`.
  [AMENDED by D-135: also in `.github/workflows/pages.yml`, and CI checks all three.]
  A CI step fails when the two differ, so local and CI always match.

**D-128 PhaseController's narrow interface is explicit and wired in the scene (author; amends D-110).**
- PhaseController may call only these:
  - `WaveDirector.start_night(plan)` and `stop()`
  - `NodePool.recall_all() -> int`
  - `TravelerSpawner.start()`, `stop()` and `clear_queue()`
- It reaches them only through typed `@export` references assigned in `world/main.tscn`: never
  `get_node` paths, groups or tree searches. A unit test greps its source to enforce that.
- The hero and camera are no longer called directly. PhaseController emits the new bus signal
  `hero_place_requested(position)`; the Hero teleports and the CameraRig snaps.
- So `main.tscn` now holds World, the pools, WaveDirector, TravelerSpawner and PhaseController, and
  tests and tools create the game with `Main.create()`, which instantiates the scene.
- `NodePool.release_all` is renamed `recall_all` and returns the count, which the dawn and close-up
  steps use for the freezer. The pools no longer join a group.
- This is documented as the single exception under Architecture in CLAUDE.md (plan Task 1).

**D-130 [AMENDED by D-134] Golden RNG test (author).**
- `test_rng.gd` commits a golden list for run seed 20260930, the 4 stream names and days 1–30. It
  holds the 120 derived seeds (all distinct) and the first `randi()` of each stream.
- The seeds come from an independent Python FNV-1a 32 oracle. The first values come from a
  reference PCG32 replica of Godot's `RandomPCG` (`pcg32_srandom_r(seed, PCG_DEFAULT_INC_64)`).
- A mismatch means the derivation or the engine RNG changed. Escalate; never regenerate the list
  silently.

**D-131 Time is not a constraint (author; supersedes D-127, amends D-103 and D-104).**
- v0.1 has no deadline. Scope is decided by quality and the v0.1 gate, never by the calendar.
- IDEA.md's timeline line now reads: "no fixed deadline; scope is driven by quality and the v0.1 gate".
- Plan estimates stay as information only. There is no "Actual (h)" field, no CP1 re-forecast (CP1 is
  a quality review only), no budget-extension rule and no cut list (`docs/CUT_CANDIDATES.md` is not
  created).
- There are no time-based stop rules:
  - **Spike:** no half-day timebox. Escalate when a check fails and its pre-agreed fallback also
    fails.
  - **Balance tuning:** no 2-day timebox. The D-103 priority order stays:
    1. night 1 NaiveBot ≥ 50% must hold;
    2. night 2 PlannerBot ≥ 60% must hold;
    3. night 2 NaiveBot may relax to ≤ 45%.

    Escalate with the sweep data when the two must-hold targets can't both be met, or when 3
    consecutive tuning rounds make no progress on any target. Never change the design.
  - **Task size:** if a task turns out bigger than its plan describes (new files, new systems, or
    steps the plan didn't anticipate), stop and propose a split before continuing.

**D-132 Sim budget handling (author).**
- The sim suite stays under 60 s headless. When it goes over, tests are never dropped, skipped or
  weakened.
- `./run_tests.sh --quick` (unit plus the night-1 sims) is for local loops, from Task 20 on.
- CI runs `unit` and `sim` as parallel jobs from the start (Task 34), so the first mitigation is
  already in place.
- If the budget is still exceeded: report per-test timings and escalate.
- The rule is written in the plan (Tasks 1 and 34) and in CLAUDE.md.

**D-133 Git workflow (author).**
- One branch and one PR per plan phase (`s1/p<N>-<slug>`), and one commit per task inside it.
- The `reviewer` subagent still reviews every task; the author reviews each phase PR.
  [AMENDED by D-137: the author reviews the checkpoint phases' PRs (5, 10, 14) and may review any
  other.]
- Before CI exists, the PR body carries the local test output. After CI exists, the `unit` and `sim`
  checks must be green.
- Only the author merges. [AMENDED by D-137: the agent merges non-checkpoint phase PRs that meet
  D-137's conditions; checkpoint phases stay with the author.] After CI lands, the agent gives the author the exact `gh api` command that
  protects `main` (PR plus green `unit` and `sim` required, admins included). The agent never applies
  it.
- [AMENDED by D-134: the repo is public now] Branch protection on a private repo needs GitHub Pro.
- Written in CLAUDE.md (plan Task 1) and in the plan's Git Workflow section.

**D-134 How golden RNG mismatches are handled, and the repo is public (author).**
- **`seeds` is the true oracle** (an independent FNV-1a reference). A seed mismatch is a derivation
  bug and is escalated.
- **`first` was produced by an unverified Python replica of Godot's RNG.** If, on the first Task 3
  run, every seed passes but `first` fails:
  1. replace `first` with values captured from the pinned `GODOT_TAG` engine (plan Task 3,
     Step 4b);
  2. log a decision that the replica differed and that the engine values are now the golden
     baseline;
  3. freeze the list.

  After that, any mismatch is escalated and never silently regenerated.
- The repo `khanhnguyendev/last-stand-tycoon` is now public, so branch protection works without
  GitHub Pro. The Task 34 note is updated.

## 2026-09-30: Dev hosting moves to GitHub Pages

**D-135 Dev and phone testing are served from GitHub Pages (author; amends D-083, D-104 and D-129; pre-decides the D-120 fallback).**
- Why: Godot 4.7 web builds need a secure context, so plain-http LAN fails on the phone. The Task 0
  spike got "Secure Context - Check web server configuration (use HTTPS)" on iPhone Safari. The repo
  is public, so GitHub Pages serves HTTPS for free.
- `.github/workflows/pages.yml` exports the `web_release` build with the pinned `GODOT_TAG` and
  publishes it on every push: `main` at the site root, every other branch at `preview/<slug>/`
  (slug = the branch name with every character outside `[A-Za-z0-9._-]` replaced by `-`). When the
  `web_profile` preset exists, it also goes to `<path>/profile/`. A release pck containing
  `ui/debug` fails the deploy.
- Previews of deleted or merged branches are pruned, and a deploy over 900 MB fails (the Pages
  limit is 1 GB). Branch-built Pages has a soft limit of 10 builds per hour.
- Each branch has its own concurrency lock; the publish step retries with `--force-with-lease`, so
  parallel branch deploys never overwrite each other. Branch names that slugify alike (`a/b`,
  `a-b`) share one preview.
- The `gh-pages` branch is rewritten as one orphan commit per deploy, so the ~40 MB wasm never piles
  up in history.
- Before Task 32 there is no `web_release` preset, so the path holds a placeholder page.
- Every page carries the git hash (`window.LST_BUILD = "<short hash> <branch>"`). The game shows it
  in a small corner label (plan Task 32), so a phone tester always knows which build they are on.
- The safe-area probe (`export/probe/build_probe.sh`) is kept. It is published at `/probe/` from
  `main`, and at `<path>/probe/` when a branch changes `export/probe/` or the workflow is run by
  hand with `probe=true` (it adds ~40 MB). Its page sets `viewport-fit=cover`, as the game shell does, because iOS reports the CSS
  insets as 0 without it. It is reused for D-119 (the iOS Simulator now, the author's phone at CP2)
  and for the S6 iframe checks. This amends the Task 0 rule that nothing from the probe is kept.
- The single-threaded export (D-014) needs no COOP/COEP headers, which Pages can't set anyway.
- Phone tests at CP2, the criterion-4 profile run and the criterion-5 gate (CP3) all use the Pages
  URL.
- Moved to S6: the itch.io draft, the itch iframe checks (safe area and fullscreen inside the embed)
  and butler uploads.
- Localhost stays fine for desktop checks, because localhost is a secure context.

## 2026-09-30: S1 Task 0 spike results

**D-116 Pinned Godot: `4.7.2-stable` (spike).**
- `GODOT_TAG=4.7.2-stable`, the newest 4.7.x stable in `godotengine/godot-builds` (the others are
  `4.7.1-stable` and `4.7-stable`). `--version` prints `4.7.2.stable.official.ed1daf0bf`.
- `$GODOT=/Users/ryan/Applications/Godot-4.7.2-stable/Godot.app/Contents/MacOS/Godot`.
- SHA-512 `OK` against the release's `SHA512-SUMS.txt` for the macOS universal zip and the export
  templates `.tpz`. The first `pages` run also verified the Linux x86_64 zip and the `.tpz`.
- Export templates are installed in `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`.

**D-117 GUT `v9.7.1`; `--headless --import` works (spike).**
- The plan's `releases/latest` query returns `v9.6.1`, because GitHub marks the 9.6.x backport as
  "latest". GUT 9.7.x is the line with the Godot 4.7 fixes (9.7.0 adapts doubles to 4.7's stricter
  return types), so the pinned tag is **`v9.7.1`**. Task 1 uses it.
- `"$GODOT" --headless --path . --import` exits 0. With 9.7.1 a single import on a fresh project
  (no `.godot/`) is enough for GUT to load. With 9.6.1 the first GUT run reported missing GUT
  class_names until a second import ran.
- Probe results on 9.7.1: the autoload test and the projection test pass.

**D-118 `--fixed-fps 60` runs unthrottled; tick-sampling rule (spike).**
- 3600 physics ticks took 29–30 ms headless. No `time_scale` fallback.
- `SceneTree.physics_frame` is emitted **before** the nodes' `_physics_process` for that tick. Code
  resuming from `await get_tree().physics_frame` sees state from before this tick's node updates.
  The probe's first count was 3599 of 3600 for that reason, not because of the stepping.
- Rule for tests and sims: take every reading at the same kind of point (for example, always right
  after an `await physics_frame`). Counts between two such points are exact (3600 awaits = 3600 ticks).
  Where a test needs the tick's node updates applied, it awaits one more `physics_frame` (or a
  `process_frame`) before asserting.

**D-119 Web safe area comes from CSS `env()` (spike; confirmed on the author's phone at CP2).**
- The probe ran on the Pages URL (`preview/s1-p0-spike/probe/`, build `d0525ba`) in the iOS
  Simulator: iPhone 17 Pro, iOS 26.5, Safari, portrait, standalone page (not an iframe):
  `safe=[P: (0, 0), S: (1206, 2142)]`, `win=(1206, 2142)`, `screen=(1206, 2622) scale=3.0`,
  `css(top,bottom,left,right)=0,0,0,0`, `inner=402x714 dpr=3`, `secure=true iframe=false`.
- `DisplayServer.get_display_safe_area()` on web returns the window rect (it equals `win`, not the
  screen), so it carries no inset information. The web path uses CSS `env(safe-area-inset-*)`
  through `JavaScriptBridge`, which `ui/hud/safe_area.gd` (plan Task 29) already does. Keep its web
  branch. The page needs `viewport-fit=cover` (the Task 32 shell has it).
- In portrait Safari the browser bars keep the page clear of the Dynamic Island and the home
  indicator, so both sources read 0 there. Cases with nonzero insets (landscape, a home-screen web
  app) were not measured. The phone reading at CP2 (`/probe/` on the Pages site) confirms the
  decision.
- [Accepted by the author, 2026-09-30.] iPhone Safari has no element Fullscreen API, so portrait
  Safari with its bars (insets 0) is the normal iPhone case. Nonzero insets matter for Android Chrome
  fullscreen and home-screen web apps, so the CSS `env()` path stays. S1 has no PWA or home-screen
  mode; that is an S6 candidate. The game is portrait-only, so no landscape reading is needed.

**D-120 Plain-http LAN does not work; phones use GitHub Pages (spike, D-135).**
- iPhone Safari on `http://192.168.1.52:8000/` stopped with "Secure Context - Check web server
  configuration (use HTTPS)". Godot 4.7 web needs a secure context.
- The pre-agreed fallback applies, as amended by D-135: phone tests use the HTTPS GitHub Pages URL.
  `http://localhost` is still fine for desktop checks (localhost is a secure context).
- The single-threaded export loads on Pages with no COOP/COEP headers (`secure=true`, D-014).

## 2026-09-30: Phase 1 start: parallel work, merges, device testing

**D-136 Parallel task execution (author).**
- Tasks run in parallel only when their file sets are disjoint. Two tasks that touch the same file
  never run at the same time.
- Hot files are always serialized: `project.godot`, `CLAUDE.md`, `autoload/EventBus.gd`,
  `autoload/GameState.gd`, `balance/*.gd` and `*.tres`, `world/main.gd`, `world/main.tscn`,
  `world/world.gd`, `run_tests.sh` and `.github/workflows/*`. When parallel tasks each need a small
  hot-file edit, they run without it, and the main session applies those edits afterwards, one at a
  time.
- At most 3 `implementer` subagents at once, each in its own git worktree on a task branch
  `s1/p<N>-t<NN>-<slug>` cut from the current phase branch. Each worktree runs its own Godot import
  (its own `.godot/` cache). Shared gitignored inputs are symlinked, never copied.
- Every task keeps the full flow: TDD, verification with pasted output, and a reviewer pass.
  Reviewers may run in parallel.
- Integration: after a task passes review, its task branch is merged into the phase branch with
  `--no-ff` (the task's one commit is preserved), and the FULL suite runs on the phase branch before
  the next task is merged. If the integrated run fails, merging stops and the phase branch is
  debugged first (systematic-debugging).
- Merge conflicts are resolved by the main session, never by an implementer. A conflict in a hot
  file or in design intent is escalated to the author.
- A task that runs alone commits directly on the phase branch, with no worktree (main session's
  reading of the rule).

**D-137 Phase PR merge policy (author; amends D-133).**
- The main session may merge a phase PR into `main` itself, with a merge commit (never squash), when
  ALL of these hold:
  - CI is green (before CI exists: the full local suite output is in the PR body);
  - every task in the phase passed its reviewer pass;
  - there are no open escalations;
  - the phase doesn't end at a checkpoint.
- Phases ending at CP1 (Phase 5, Task 20), CP2 (Phase 10, Task 32) and CP3 (Phase 14, Task 37) stay
  open for the author to review and merge.
- After each self-merge, the main session posts a PR comment of at most 5 lines: what shipped,
  tests, decisions.
- Agents still never push to `main` directly and never change branch protection.
- PR #2 (Phase 0) was merged this way on 2026-09-30, after the author said "merged" while it was
  still open.

**D-138 Device testing without the author's phone (author).**
- [AMENDED by D-141: without an Android Emulator, Android checks are Playwright-emulated.]
- Primary devices: the iOS Simulator (Safari on a notch iPhone) and, when Android Studio is
  installed, the Android Emulator (Chrome). They load `http://localhost` (a secure context) or the
  Pages preview URL. `export/device_check.sh` (plan Task 32) scripts them, and results are read from
  screenshots.
- System components are never installed by the agent. When a runtime is missing, the author gets
  the one-time install step. As of 2026-09-30: the iOS 26.5 runtime is present (Xcode.app, used
  through `DEVELOPER_DIR`), and Android Studio is not installed.
- The author's phone is used only at CP2 and at the gate (CP3). The criterion-4 phone numbers and
  the phone load and first-combat times move into the CP3 session: the author plays the 3 gate
  cycles on the profile build (release template plus the small fps overlay). Task 36 records
  simulator and desktop numbers for information only.
- Desktop Chrome passes headless with software WebGL (checked 2026-09-30 on `/probe/`, build
  `30be3ed`). It uses Playwright 1.63.0 (its cached chromium-1243), installed in a scratch dir and
  never in the repo:
  - `chromium.launch({headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']})`;
  - a 720×1280 viewport, `goto(url, {waitUntil: 'load'})`, then polling for `window.LST_BUILD` and the
    canvas, plus a 15 s wait before the screenshot;
  - a hard timeout: `perl -e 'alarm shift; exec @ARGV' 90 node run.js <url>` (macOS has no `timeout`).
  Result: renderer `ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device ...), SwiftShader driver)`, no page
  errors, no failed requests. The console only had Godot's banner and "GPU stall due to ReadPixels"
  performance warnings. The probe read `safe=[P: (0, 0), S: (720, 1280)]` and `css=0,0,0,0`. Plain
  `chrome --headless=new --virtual-time-budget` hangs on Godot's main loop, so it isn't used.

## 2026-09-30: More parallelism, look-ahead, emulated Android

**D-139 Wiring notes: implementers don't edit the shared scene files (author; amends D-136).**
- Implementers never edit `world/main.gd`, `world/world.gd` or `world/main.tscn`. The same goes for
  `autoload/EventBus.gd`, `autoload/GameState.gd`, `balance/*.gd`/`*.tres` and `project.godot`,
  unless that file is the task's main purpose (T10 for EventBus/GameState, T12 for main/world, T2
  and T35 for balance).
- Each task delivers its system as its own script or scene, plus a **wiring note** in its report
  with the exact lines to add. The main session applies wiring notes, serialized, on the task branch
  right after the task's review, and folds them into the task commit.
- The main session then runs the task's tests that need the wiring (for example the `Main.create()`
  tests). If they fail, the task goes back to its implementer. (Main session's reading: this is how
  TDD stays intact when a test needs wiring the implementer may not write.)
- Waves are recomputed with this rule, limited by real dependencies (each task's Interfaces and the
  scenes its tests use) and at most 3 implementers at once. The wave table is in the plan's Git
  Workflow section. The dependency check found:
  - T13 ∥ T15 is not possible: the hero's tests use `Steak` and `world.steak_pool` from T13. T14 ∥ T15 is.
  - T11 has no dependencies, so it starts alongside Phase 2.
  - T16 and T21 both edit `actors/hero/hero.gd`, so they run in turn.

**D-140 Look-ahead across checkpoints (author; amends the "stop at each checkpoint" rule).**
- Tasks whose outputs don't depend on night-loop behavior or balance numbers may start before CP1
  is approved. Checked against the dependency graph, that means:
  - T21 (day stations);
  - T22 (travelers) and T23 (build pay); both are day systems on top of T17, T18 and T21;
  - T24 (close-up sign, telegraph), added to the author's list: it needs only T17, T21 and the lane
    plan data;
  - T27 (joystick), T28 (camera), T30 (FX) and T31 (focus pause).
- They live on stacked branches (`s1/p6-day`, `s1/p9-input-hud`) and are not merged into `main`
  before the author approves CP1. If CP1 changes the design, they are reworked.
- Everything that depends on the night loop, the sims or balance still waits for CP1: T25 (PlannerBot
  and night-2 sims), T26 (restore contract), and T29 (the HUD, which reacts to wave and diner
  events).
- Before CP2, T33 (lane screenshots: needs T13 and T20) and T34 (CI) run alongside T32.

**D-141 Android checks are emulated until an emulator exists (author; amends D-138).**
- Don't wait for Android Studio. Until the author installs it (maybe never in S1), Android checks use
  Playwright Chromium with the Pixel 7 device profile (touch on, mobile user agent, portrait
  viewport) and software WebGL. `export/pw_check.mjs` (plan Task 32) runs them, and
  `export/device_check.sh` falls back to it.
- Results are labelled **emulated**, never "device".
- Playwright lives in a user-level cache (`~/.cache/lst-playwright`, pinned 1.63.0), never in the
  repo. Checked 2026-09-30 on `/probe/` (build `b905977`): it loads with no page errors and renders.
- Real Android is covered by the S6 friend playtests.

**D-142 Acting on "merged" (author; amends D-137).**
- When the author says "merged", the main session first checks the PR state with `gh pr view`.
- If the PR is still open and the main session may self-merge it (D-137), it merges it and tells the
  author.
- If it is a checkpoint PR (Phases 5, 10, 14), it stops and asks. It never merges a checkpoint PR on
  the author's behalf.

## 2026-09-30: Phase 2 review fixes

**D-143 Zone axes point along each lane's end-of-path perpendicular (Task 6 review; refines D-111).**
- The D-111 blend moves the lateral offset from the path perpendicular onto the zone's width axis
  over the last `offset_fade_distance`. The plan's `ZONE_AXIS` signs were arbitrary. North's axis was
  anti-parallel to its end perpendicular, so every north boar passed through one point halfway
  through the blend and then swerved to the other side (east did the same, less sharply).
- Rule: `ZONE_AXIS[lane].dot(end_perp) > 0` for every lane, fixed in the map data (the sign of an
  axis carries no meaning for the zone rectangle). Tests guard it: the axis sign, and an offset never
  crossing the centerline during the blend. Geometry tests D and E are unaffected, because the stop
  points are symmetric in the offset.
- Also from the Phase 2 reviews: `WaveSchedule` breaks float time ties main-first with a consistent
  comparator, and the bot lane sort (plan Task 25) treats float threat ties with `is_equal_approx`.

**D-144 Waypoint `e_mid` routes the southeast corner to the east zone (Task 8 review; amends D-112).**
- The planned edge `se` (6.8, 6.8) → `zone_east` (5.2, 0) ran straight through the freezer box,
  and the D-125 clearance test caught it (minimum clearance 0.0, 0.39 needed).
- Fix: a new node `e_mid` at (7.0, 3.0); the edge becomes `se` → `e_mid` → `zone_east`, with
  minimum clearances of 0.60 m and 1.20 m. Moving `se` instead would have needed x ≥ 7.6, which
  changes other routes. Stations and map coordinates are unchanged.
- The Dijkstra priority stays the plan's exact comparison. It is a consistent strict order, and
  near-equal routes don't occur in this graph.
- Process note: parallel implementers must write logs to unique temp paths (a shared `/tmp/g.txt`
  mixed two tasks' output once).

**D-145 Wide windows keep the portrait vertical view (Task 9 review).**
- `CameraMath` used `KEEP_WIDTH` at a fixed 9:16 aspect. With stretch aspect `expand` (D-072), a
  landscape desktop window widens the viewport, which under `KEEP_WIDTH` shrinks the vertical FOV.
  The north lane's warning time would drop below 2.0 s once width/height exceeded about 1.25
  (about 0.55 s at 16:9).
- Rule: up to 9:16, `KEEP_WIDTH` with the horizontal FOV `camera_fov_h` (unchanged). On wider
  windows, `KEEP_HEIGHT` with the portrait vertical FOV, so the view only gains width.
  `CameraMath.keeps_width(aspect)` decides, and `CameraRig` (Task 28) uses it for
  `Camera3D.keep_aspect` and the matching FOV.
- The lane-visibility test now runs at 9:16 and 16:9, with the hero at the zone centre and at the
  lane end, and with lateral offsets of −1, 0 and +1. A test checks the projection against a real
  `Camera3D`.

**D-146 Snapshots are serialized with full float precision (Task 10 review).**
- The default `JSON.stringify` drops float digits: a diner at `300 - 1/3` HP came back different
  after a JSON round trip (and capped-wave `hp_mult` values would too).
- Any JSON serialization of `GameState.to_dict()`, including S3 saves, uses
  `JSON.stringify(d, "", true, true)` (full precision). The round-trip test pins it.
- Also from the review: `fence_max_hp` asserts its level range, `add_gold` ignores non-positive
  amounts, and `test_balance` pins that the per-level arrays have `max_level` entries.

**D-147 Focus pause also covers window focus loss (Task 31 review; refines D-046).**
- On web, Godot reports canvas focus and blur as `NOTIFICATION_WM_WINDOW_FOCUS_OUT/IN`, not as
  application focus. With only `visibilitychange`, desktop alt-tab (browser still visible) and iOS
  overlays would not pause, and would cost diner HP. `FocusPause` now pauses on window focus out and
  on a hidden tab. The latest focus-in or visible event resumes, because iOS may never send focus-in.
- `FocusPause` only undoes a pause it set itself. It removes its JS listener on exit.
- A paused tree drops the touch release, so the joystick (Task 27) ends its stick on
  `NOTIFICATION_PAUSED`. Otherwise the hero kept walking after resume.
- Its `main.gd` wiring goes first in `Main._ready()`, which Task 15 creates.

**D-148 Fences stop Boars only as a target kind (Task 13 review).**
- Spec 7.2 and D-049: "the first non-null target wins; with none, it walks". The plan's Boar stopped
  at a standing fence even when `fence_on_lane` was not a target kind, so it stood still forever.
- The stop distance lives in `TargetProviders` (a single source). The Boar stops only when a
  `fence_on_lane` provider is registered, so S2's `guard` kind stays enemy-code-free.
- Boars carry a `generation` counter, incremented on every spawn, so projectiles and attackers can
  detect pool reuse across nights (Review Focus 2). `spawn_index` restarts every night.

**D-149 Screenshots keep their own camera; the per-level scale lives in `UiTuning` (Task 18 and 28 reviews).**
- `tests/sim/capture.gd` (Task 20) keeps its standalone `Camera3D`, set up with
  `CameraMath.apply_lens`. The plan's Task 28 step that switched it to `main.camera_rig.snap()` is
  dropped, because the rig's `_process` shake could land in a screenshot.
- The ×1.1 visual scale per built level (spec 8.6) is `UiTuning.build_level_scale` ("every number in
  `balance/`"). Level pips are centred for any `max_level`.

**D-150 `-s` scripts don't name autoloads (Task 20 review).**
- A script run with `godot -s` compiles before the autoloads are registered. So `Balance`,
  `EventBus` and `GameState`, and any class that uses them, fail to parse there.
- Tools launched with `-s` (`tests/sim/capture.gd`, `tests/sim/sweep.gd`) only load their typed logic
  at run time: `capture.gd` loads the classes it needs with `load()`, and `sweep.gd` adds
  `sweep_runner.gd` (a typed `Node`) to the tree.
- `docs/.gdignore` keeps Godot from importing `docs/` (screenshots got `.import` files). No test reads
  `docs/` through `res://`.

## 2026-09-30: CP1 approved

**D-151 The diner fades when it hides an actor (author at CP1; implemented in Task 30).**
- [AMENDED at the CP1 review: 0.3 looked too faint on grass. The value stays in `UiTuning`; at CP2 a debug
  button cycles 0.30 / 0.45 / 0.60 on the phone, and the author picks one (plan Task 32).]
- The spec camera (pitch 55°, distance 18) looks over a 3 m diner, which hides the north zone. In
  the CP1 render only a sliver of the hero showed.
- Each frame, the camera→actor segment is tested against the diner's AABB (slightly grown), for the
  hero and every alive Boar. If any actor is occluded, the diner's Visual (walls and roof) fades to
  `UiTuning.occluder_alpha` (0.3) over `UiTuning.occluder_fade_s`. It fades back to fully opaque when
  nothing is occluded.
- A generic `OccluderFade` component under the occluder's Visual does this, so S4's real diner model
  reuses it. S4 note: the diner model keeps its roof and walls as separate meshes compatible with the
  fade.
- The Compatibility renderer's transparency sorting must not hide the actors behind the diner. The
  re-rendered screenshots are the check.
- Tests project through `CameraMath`: the hero at the north zone centre fades the diner; a Boar in the
  north zone with the hero at HOME fades it; with nothing occluded it stays fully opaque.
- After Task 30, the three per-lane screenshots (D-076) and a hero-at-north-zone-centre shot are
  re-rendered and committed.

**D-152 The ground extends past every camera view (author at CP1; Task 24b).**
- The sky-coloured band at the top of `cp1_night1.png` was the edge of the ground at z = −24, not
  the horizon.
- A far ground "skirt" under the map means no camera focus inside `FOCUS_MIN/FOCUS_MAX` (at 9:16
  and 16:9) ever shows past the ground. A projection test checks the four focus corners.

**CP1 outcome (author).** CP1 approved. Night-1 sims at the default balance: first combat at 12.45 s
(idle player 12.27 s; limit 30 s); NaiveBot keeps 67% of diner HP (target ≥ 50%); ParkedBot's diner
falls and the night restarts identically.

**D-153 The camera supports window aspects 9:21 to 21:9 (Task 24b review; extends D-145 and D-152).**
- With stretch aspect `expand` and no clamp, very tall windows (below about 9:22.5; the top rays
  point above the horizon below about 9:33) and very wide ones (above about 2.85:1) would show past
  the 60 m ground (D-152).
- `CameraMath` clamps the view to `[ASPECT_MIN, ASPECT_MAX]` = 9:21 .. 21:9:
  - narrower than 9:21: `KEEP_HEIGHT` with the vertical FOV 9:21 shows;
  - wider than 21:9: `KEEP_WIDTH` with the horizontal FOV 21:9 shows;
  - in between: the D-145 rule.
  `apply_lens` and `projection` both use `lens_fov`.
- One ground plane covers `World.ground_rect()` (bounds + `GROUND_MARGIN` 80 m; the worst view
  reaches 53.9 m past the bounds). No skirt, so no z-fighting or overdraw. The environment background
  is the ground colour as a fallback.
- The ≥ 2.0 s lane warning is tested at 0.30, 9:21, 9:16, 16:9, 21:9 and 32:9 (worst 3.10 s at 0.30).
  It is only guaranteed inside 9:21..21:9.
- Tests: ground coverage at 0.30, 9:21, 9:19.5, 9:16, 16:9, 21:9 and 32:9 (all rays point down, all
  hits land inside, with 5 m of headroom); lane visibility ≥ 2.0 s at 9:21, 9:16, 16:9 and 21:9; the
  projection matches a real `Camera3D` in the clamped branches.

**D-154 PlannerBot buys unbuilt towers by lane threat (Task 25 review; refines spec 13.3).**
- With the plan's order, a level-0 tower was only a candidate as "the tower next to the top side
  lane", and upgrades skipped level 0. `tower_ne` was never built (every sweep row showed
  `tower_ne:0`), and the east lane had no tower at all. The sweep broke at day 3, probably from the
  bot's weakness rather than the balance.
- New order:
  1. a fence on the highest-threat side lane;
  2. the tower next to it;
  3. more fences and any unbuilt tower, by the threat on their lanes (a tower scores its
     higher-threat lane);
  4. upgrades: rank lanes by threat and take the spots next to the top lane, towers before fences.
  Ties go by `SPOT_IDS` order.
- Details fixed during review:
  - step 1 ranks side lanes by their side-group threat (count × `hp_mult`);
  - step 2, when the side lane is north, takes the adjacent tower whose other lane has more threat;
  - step 3 skips spots whose lanes carry no threat tonight;
  - step 4 is towers first, then fences; within a kind it takes the cheapest affordable. If nothing
    next to the top lane is affordable, it moves to the next lane by threat rather than saving.
- The break day (DoD 4) is logged only after the sweep re-runs with this order.

**D-155 Sweep break day: 8 (Task 25; DoD 4).**
- PlannerBot, seed 20260930, default balance, D-154 purchase order (towers before fences on
  upgrades). The run breaks at day 8: the diner falls three times in a row, and the retries replay
  identically.
- Diner HP left at dawn, days 1–7: 0.667, 1.000, 0.833, 0.750, 0.483, 0.883, 0.467, then the
  break.
- Economy: gold earned 108 / 144 / 186 / 216 / 258 / 300 / 336. Unspent at close-up
  8 / 32 / 38 / 34 / 12 / 32 / 28. Steaks equal kills × `steaks_per_kill` every night (freezer plus
  carried), and every steak was sold.
- History: with the plan's original order (`tower_ne` never built) the run broke at day 3; with
  fence-first upgrades, at day 6.
- (Correction: an earlier draft of this entry said only about 83% of steaks were picked up. That
  was a measurement error: the 6 carried steaks weren't counted. Nothing is lost.)

**D-156 S2 input: re-tune wave scaling for cards (author, from the CP1 review).**
- With the S1 PlannerBot (D-154, D-155), nights 2–4 end at 100%, 83% and 75% diner HP, and the
  sweep breaks at day 8.
- Hero cards (S2) add power, so S2 re-tunes wave scaling against a target break day *with* cards.
  Recorded in the spec's S2 decomposition line. No S1 work.

**D-157 Export keeps text resources as text (Task 32).**
- `BalanceData` builds its sub-resources in script initializers (`@export var wave: WaveBalance = WaveBalance.new()`),
  and `balance.tres` stores none of them explicitly.
- By default the export converts `.tres` files to binary. The converter loads them with placeholder scripts, so it
  can't evaluate non-constant initializers. It then writes those properties as `null`, and at runtime `null`
  overrides the initializer. The result: every exported build (release included) had `Balance.data.wave`, `.build`
  and the rest null.
- The release template hides script errors, so this showed up only as a silently broken game (no tower spots, no
  waves). Running the exported pack with the debug binary shows `Invalid access ... 'base_counts' on Nil`.
- Fix: `project.godot` `[editor] export/convert_text_resources_to_binary=false`. The text `.tres` keeps storing only
  the non-default properties, so the initializers apply exactly as in the editor and in tests.
- Alternative, not taken: write every sub-resource into `balance.tres` explicitly. That is more file churn, and the
  same trap would remain for any future initializer-built resource.
- Guards:
  - A unit test asserts the setting stays `false`.
  - `pages.yml` boots every exported pack (release, profile, debug) with
    `--headless --fixed-fps 60 --main-pack <pck> --quit-after 120`, which is 2 s of game time on any runner.
  - It fails if the pack is missing, on a non-zero exit, or on `SCRIPT ERROR`, `Invalid access`, `Parse Error`,
    `Failed loading resource` or `Cannot open` in the log. A missing `--main-pack` exits 0 with only a `Cannot open` line.
  - Checked locally: a pack exported with the fix logs 0 errors, and a pre-fix binary-converted pack logs 374.

**D-158 Export presets drop VRAM texture compression for S1 (Task 32).**
- The plan's `vram_texture_compression/for_mobile` lines make Godot reject the preset unless
  `rendering/textures/vram_compression/import_etc2_astc=true` is set. S1 ships no textures outside `addons/gut`
  (only `Nunito.ttf`), so the lines had no effect.
- S4 (art) restores `for_mobile=true` together with `import_etc2_astc=true`. Without both, phones fall back to
  decompressing textures on the CPU.

**D-159 Build v0.1 autonomously; one final review at the end of S5 (author; amends D-137, D-138, D-140, D-142).**
- The author won't test placeholder builds. CP2 (phone check) and CP3 (S1 gate) are deferred, not approved, and merged
  into a single FINAL REVIEW after S5. S6 (itch.io friend playtests, release) starts only after the author approves it.
- PR #12 (Phase 10) was self-merged under D-137 with CP2 deferred. PR #13 (Task 34 CI) was retargeted to `main` and
  merged when green. There are no checkpoint PRs before the final review; every phase is self-merged under D-137.
- Branch protection on `main` was applied by the main session on the author's instruction: a PR plus the `unit`, `sim`
  and Pages `deploy` checks, strict, admins included. Self-merges must pass it. No other protection changes.
- Default `UiTuning.occluder_alpha` is 0.45; the author confirms it at the final review.
- Order: finish S1 (Task 35 tuning, Task 36 perf on the profile build: iOS Simulator plus emulated Pixel; Task 37
  moves to the final review), then S2 hero cards and adventurer guards, S3 save/load plus failure and mercy, S4 asset
  pipeline and full art pass (ART_BIBLE.md and the asset validator first; CC0 packs first; kitbash and restyle
  through Blender; procedural props; AI generation only for gaps and only after a commercial-license check;
  everything in ASSET_LICENSES.md), S5 UI/HUD polish, contextual onboarding, audio, VFX and juice.
- Autonomy for S2–S5:
  - the full Superpowers flow per sub-project, with the brainstorming questions answered by the main session from
    IDEA.md, the three pillars, DECISIONS.md and the S1 sweep data;
  - every decision logged, and every reversible player-facing, balance, art-direction or IDEA.md-deviating one also
    added to `docs/REVIEW_QUEUE.md`, ranked by impact;
  - the v0.1 scope stays as in IDEA.md, with nothing from its "Later" list; new ideas go to "Post v0.1" in the spec.
- Quality gates replace the author:
  - CI green and a reviewer pass for every task;
  - sims and the sweep re-run after every balance-affecting change;
  - an iOS Simulator screenshot self-review against ART_BIBLE for every visual task;
  - the profile build at ≥ 58 fps average on the simulator at night 3, with the final art.
- Stop and ask only for:
  - one-time setup the agents can't do;
  - anything that costs money;
  - asset license uncertainty;
  - irreversible or destructive actions outside the repo;
  - a design conflict that can't be resolved inside IDEA.md's pillars.
- The final review delivers:
  - the release and /debug/ Pages URLs;
  - `docs/review/FINAL_REVIEW.md` (contents as the author listed them);
  - media in `docs/review/media/`: a 60–90 s iOS Simulator video covering a full night, the dawn card pick and a
    day, before/after screenshots, and one screenshot per lane.

**D-160 S1 tuning pass: the baseline balance stands (Task 35; D-066, D-103).**
- Baseline, seed 20260930, with no balance change:
  - night 1 NaiveBot clears at 0.667 diner HP (target ≥ 0.50);
  - night 2 PlannerBot clears at 1.000 (target ≥ 0.60);
  - night 2 NaiveBot falls (target ≤ 0.30). There is no relaxation.
- Sweep (PlannerBot): breaks at day 8, as in D-155. Unspent gold at close-up, days 1–5: 8 / 32 / 38 / 34 / 12, all under
  one tower (40). **S1 breaks at day 8; this is the target for S2 card power** (D-156).
- PlannerBot cycle (night + day seconds), days 1–7: 189 / 199 / 262 / 269 / 298 / 336 / 391. Day 2 misses the plan's
  "≥ 4 min from day 2" stop condition by 41 s.
- Rounds tried, one knob each, all reverted:
  - `side_share_base` 0.20 → 0.25: no cycle change;
  - `EnemyBalance.hp` 30 → 40 and 30 → 33: night 1 NaiveBot falls, so night 1 sits on an HP cliff;
  - `EnemyBalance.speed` 2.0 → 1.8: +3 s;
  - `WaveBalance.count_growth` 0.35 → 0.5: the break moves to day 5, which is a design change;
  - `traveler_interval` 2.5 → 4.4: meets 4 min (day 2 = 243 s) with identical gold and diner HP;
  - `traveler_interval` 2.5 → 5.0: the sweep stalls at the harness cap.
- Decision: keep `traveler_interval` 2.5. The 4.4 value only adds time spent waiting at an empty counter, the opposite
  of a queue building up in an arcade-idle day.
  - D-066 already treats bot cycle times as a lower bound (the PlannerBot hauls and builds perfectly) and judges the
    4–6 min criterion in the human playtest.
  - S2 (cards, adventurer guards) and S5 (onboarding) change cycle length anyway, so the criterion is re-measured at
    the final review.
- `count_growth` was also considered, since it is the only knob that adds combat without touching night 1. It fails
  too: day 2 is already paced by traveler arrivals (about 2.6 s per steak against the 2.5 s interval), and closing the
  41 s needs g ≈ 0.8. That breaks the unspent-gold condition and pulls the break day earlier; D-156 hands wave scaling
  to S2 anyway.
- Reversible: in REVIEW_QUEUE. The knob is `traveler_interval`, and 4.4 to 4.6 is the usable band (5.0 stalls the sweep).
- The only S1 default change in Task 35 is `UiTuning.occluder_alpha` 0.3 → 0.45 (D-159).

## 2026-09-30: S2 hero cards + adventurer guards (autonomous brainstorm, D-159)

Spec: `docs/superpowers/specs/2026-09-30-s2-hero-cards-guards-design.md`. The main session answered every question from
IDEA.md, the pillars, DECISIONS.md and the S1 sweep; a reviewer pass replaced the author's approval.

**D-161 The player's hero stays untargetable in v0.1 (S2; refines D-005).**
- IDEA's night targeting list is exhaustive: "a fence in the way, then a guard hero in reach, then the diner". It names
  only guard heroes, so only guard heroes take damage, get knocked out and respawn ("a knocked-out hero respawns at
  the diner door" applies to them).
- D-005 read "no hero HP … until S2 adds guards", which could also mean the player's hero joins. This decision
  resolves it the other way. The one-thumb hero never dies, which keeps pillar 2's flow, and pressure stays on the
  diner (pillar 3).
- Hero HP moves to the spec's post-v0.1 list. Reversible, so it is in REVIEW_QUEUE.

**D-162 Cards are picked by tapping one of up to 3 panels (S2).**
- A full-screen overlay at dawn; 1/2/3 or a click on desktop.
- Pillar 2 bans buttons for *core actions*. The pick is a once-a-day decision, and phone-readable card text needs panels,
  not world props.
- It reuses the fade button's finger-ownership pattern, plus a 0.5 s input guard so a joystick thumb held as the night
  ends can't pick by accident.
- Hero input is blocked during DAWN.
- Reversible, so it is in REVIEW_QUEUE: the alternative is standing still on card pedestals.

**D-163 Guard posts: the Tank on the west lane, the Archer on the roof (S2).**
- The Tank stands on the west lane's center line, 3.0 m before the end. The Archer stands on the diner roof at
  (2.5, -2.5).
- The S1 towers double-cover north (tower_nw: west + north; tower_ne: north + east), so the Tank takes a side lane, and
  the roof lets the Archer reach all three lane ends plus the north and east fence stops.
- Tank range is 2.5, so it also hits Boars held at the west fence.
- Reversible, so it is in REVIEW_QUEUE.

**D-164 "In reach" means reachable from the enemy's lane position (S2; keeps D-003).**
- A guard is a target when it is within `enemy.reach` + the guard's body radius, measured in XZ, from where the Boar
  walks. Enemies never leave their lanes.
- So the Tank on the lane is a living fence behind the fence, and the roof Archer can never be targeted.
- Boar gains one `guard` match arm and nothing else.

**D-165 Guard knockout and respawn (S2).**
- A knocked-out guard poofs, respawns at `DINER_DOOR` (-3.0, 4.6) after 3.0 s with full HP, and walks a fixed path back
  to its post.
- Dawn heals every guard (with a `guard_healed` signal) and places it on its post.

**D-166 Card offers (S2).**
- The first offer is Archer + Tank + one seeded upgrade.
- After that, a pinned draw without replacement from the types below level 5, seeded by `Rng.stream(seed, day,
  &"cards")`. Fewer eligible types means fewer cards; none means no pick.
- Picks are permanent, with no rerolls.
- `debug_skip_to_day` skips the pick without granting a card.

**D-167 Upgrade steps per level (S2 starting values; the S2 tuning pass may change them).**
- hero damage +20%, attack speed +15% (interval ÷), move speed +8%, carry +2, gold per steak +1.
- Guard stat at level L = base × (1 + growth × (L − 1)).

**D-168 Bot card policies (S2).**
- NaiveBot: the Archer on dawn 1 (the strongest unaided pick, so the night-2 check is the worst case), otherwise the
  leftmost card.
- PlannerBot: tank > archer > hero_damage > attack_speed > gold_per_steak > carry_capacity > move_speed.
- ParkedBot: the leftmost card.
- Bots read the carry capacity and move speed with card effects applied.

**D-169 S2 tuning precedence (refines D-103).**
- The order: night 1 NaiveBot ≥ 0.50 > night 2 PlannerBot ≥ 0.60 > sweep break day 10 ± 1 > night 2 NaiveBot (with the
  Archer) ≤ 0.30, relaxable to ≤ 0.45.
- The Archer's L1 damage and range are the first knobs for the last target.
- Escalate on conflicts in that order, or after 3 rounds with no progress.

**D-170 Target break day with cards: 10 ± 1 (S2; D-156).**
- S1 without cards broke at day 8 (D-160). The PlannerBot plays near-perfectly; humans break earlier and get S3 mercy.
- Reversible, so it is in REVIEW_QUEUE.

## 2026-09-30: S3 save/load + failure & mercy (autonomous brainstorm, D-159)

Spec: `docs/superpowers/specs/2026-09-30-s3-save-failure-mercy-design.md`.

**D-171 The web save lives in `localStorage`, with keys per deployment path (S3).**
- `localStorage` is written through `JavaScriptBridge`. Every call is wrapped in a JS try/catch, because
  `JavaScriptBridge.eval` swallows JS exceptions.
- Keys are prefixed `lst:<location.pathname>:`, so `/`, each `preview/<slug>/` and `debug/` keep separate saves on the
  shared `github.io` origin.
- Godot's web `user://` is IndexedDB with an asynchronous sync, which can lose the last write. Desktop and tests use
  `user://save/`.

**D-172 Save envelope and backup (S3).**
- The envelope is `{format 1, saved_at_unix, build, state_json, check}`, with `check` = FNV-1a 32 over the raw
  `state_json` string. A JSON round trip reformats numbers, so the check runs before parsing.
- Each write first copies the last good text to the backup. Load order: primary, then backup, then a new game. A
  corrupt primary is kept as `:corrupt`.
- A newer `format` or schema is never overwritten: autosave stays off for that session.
- Migration is a hook, empty at ship (no disk save is older than v3). Content is validated: card ids, levels and
  `resume_phase`.

**D-173 Autosave triggers (S3; IDEA Save).**
- A save is written at:
  - the `snapshot_taken` restore points (new game, close-up, each night-1 retry);
  - `card_offered` (CARD_PICK);
  - every `phase_changed(DAY)`;
  - each `build_completed`;
  - at most once per 3 s during DAY while dirty;
  - a flush on hidden or `pagehide`.
- Nothing is written during NIGHT, and the unit and sim suites never write (Autosave has no store by default).

**D-174 A mid-night quit costs the night but adds no mercy (S3; IDEA Failure; amended at spec review).**
- The only save during a night is its restore point, so reopening resumes exactly where a failure would.
- IDEA gives mercy for failed retries only. Counting quits would allow mercy farming by reloading, would greet a player
  who bounced in night 1 with "the monsters look tired", and would count tab discards as failures.
- Reversible, so it is in REVIEW_QUEUE.

**D-175 Mercy (S3; IDEA Failure).**
- Factor = `max(1 − 0.15 × night_fails, 0.40)`. It applies to Boar HP at spawn on the plan path, and to Boar damage on
  the fence, guard and diner arms.
- `night_fails` is in the snapshot (schema v3). A fail writes `+1` into the restore point before restoring, and a
  night-1 retry re-emits `snapshot_taken`, so a quit during a retry keeps the count. Dawn clears it.
- It is shown only as the banner "The monsters look tired tonight.", after an actual failure and never on resume.
- HUD banner queue: a new banner shortens the current one to `banner_min_s` (0.6 s). A banner shown while others still
  wait also plays only `banner_min_s`; the last one in the queue plays the full `banner_time`. The real fail sequence
  (tested) is: "The diner fell" (cut short), "The monsters return" (0.6 s), then the flavor line (full). Pick banners don't
  wait behind "Dawn". Amended at the S3 Task 5 review.

**D-176 Boot resumes without a menu (S3; pillar 2, first combat within 30 s).**
- With a valid save, a deferred `_boot` calls `PhaseController.resume_from`. DAY and NIGHT reuse `_restore_snapshot`;
  CARD_PICK re-emits the saved offer.
- Without one, it starts a new game.

**D-177 Restart is debug-only in S3 (S3).**
- Debug builds: the `R` key wipes the save. Any `?scene=`, `?cards=` or `?reset=1` URL skips the read and starts a new
  game, so URL scenes never mix with a resumed run.
- Release gets "New game" (with a confirmation) in the S5 settings panel.

**D-178 The sweep reports `first_fail_day` and `hard_break_day` (S3; refines D-155, D-170).**
- The difficulty target stays on the first failure (day 10 ± 1 with cards).
- `hard_break_day` is the first night still lost after 4 retries, when mercy has reached its 0.40 floor.

**D-179 S2 Task 11 tuning round: Archer L1 damage 6.0 → 4.0 (D-169, target 4).**
- With working guards, night 2 NaiveBot with the Archer rose to 0.60 against the 0.30 limit. PlannerBot with the Tank
  held at 1.0 in every row.
- One knob, Archer L1 damage, on seed 20260930:

  | Archer damage | Archer range | NaiveBot night 2 |
  |---|---|---|
  | 6.0 | 9.0 | 0.60 |
  | 5.0 | 9.0 | 0.60 |
  | 4.0 | 9.0 | 0.30 |
  | 3.0 | 9.0 | 0.2167 |
  | 3.0 | 8.8 | 0.1667 |
  | 3.0 | 8.65 | 0.1667 |
- Chose 4.0, the smallest change that passes (D-169). It has zero margin: one diner hit is 0.0167. 3.0 would weaken
  the Archer by 25% at every level, which is a target-3 decision for the S2 tuning pass.
- Task S2-14 re-checks target 4 across several sweep seeds, not only the sim seed.

**D-180 S2 tuning pass: no balance change beyond D-179 (Task S2-14; D-169, D-170).**
- Sweep break day (PlannerBot with its card policy, 14 days): 10 (seed 20260930), 11 (seed 11), 10 (seed 777), all
  inside the 10 ± 1 target. Unspent gold at close-up is at most 38 through day 5 on every seed.
- Per-seed night targets:

  | Seed | Night 1 NaiveBot (≥ 0.50) | Night 2 PlannerBot (≥ 0.60) | Night 2 NaiveBot with the Archer (≤ 0.30) |
  |---|---|---|---|
  | 20260930 | 0.667 | 1.000 | 0.300 |
  | 11 | 0.683 | 1.000 | 0.050 |
  | 777 | 0.633 | 0.517 (cleared, no retry) | 0.000 (fails) |
- The must-hold thresholds stay defined on the canonical sim seed (D-103, D-105), where the tests pin them and all hold.
  Seed 777's night 2 is a known spread: it still clears, and S3 mercy softens a failed retry.
- No knob was moved: raising the Tank or lowering wave pressure for one seed would move the break day and the
  zero-margin Archer target.
- Also seen: from about day 7, every tower and fence is at max level, so unspent gold piles up (260 → 748 by day 9).
  There is no other gold sink in v0.1 (IDEA: towers and fences are the only sink). Logged in REVIEW_QUEUE.

**D-181 Wiring notes that keep a branch green are applied before the review (clarifies D-139).**
- When a task's committed code needs its wiring note to compile or pass (for example, a test that uses a `Main` field
  the note adds), the main session applies the patch and amends it into the task commit **before** the reviewer pass.
  Otherwise the reviewer sees a red suite.
- The reviewer then reviews the task and its wiring together. The main session still owns the hot-file edit.

## 2026-10-01: S4 direction (author)

**D-182 S4 uses free CC0 assets only, without Blender (author; answers the S2–S5 setup batch).**
- No Blender MCP install for now and no paid AI generation. Free CC0 assets plus Godot-side material and colour work.
- Ask again only if the style board shows a gap only Blender can close. If so, send the exact one-time install steps.

**D-183 Art cohesion comes before asset choice (author).**
- Blocky sets (Kenney Blocky Characters, Cube Pets) are not mixed with the rounded kits (Food, Castle, Tower Defense)
  unless a style board proves they read as one world.
- **Style board first:** 2–3 candidate character sets, rendered in the real game camera with the diner, a tower, a
  fence, steaks and coins. Commit to `docs/review/media/s4_style_board/`. The pick is logged with written reasons and
  added to REVIEW_QUEUE (high impact).
- **Characters need:** idle, run, attack and hit/death animations (or a clean tween fake).
  - The hero reads as the diner owner/cook.
  - Archer and Tank are recognizable at phone size.
  - The Boar reads as "monster that becomes steak": cute-dangerous, not a cuddly pet.
- **ART_BIBLE readability rules:**
  - distinct silhouettes for the hero, travelers, guards and the Boar;
  - the hero always pops (ring or brighter palette);
  - travelers are muted;
  - enemies carry the warm/red accent;
  - checked at phone size (720×1280 viewed at about 40%).
- **One palette:** materials are palette-remapped in Godot (a shared palette texture or material overrides), so all
  packs sit in one palette.

**D-184 Mercy accepted; retries-per-night metric (author; S3 Task 8).**
- Endless runs fit IDEA ("non-punishing, picks permanent, no roguelite runs"). The REVIEW_QUEUE entry stays.
- The sweep and the S3 results report retries per night for days 1–14. Target: median 0, and no night before day 8
  needing more than 2 retries.
- Measured (seeds 20260930 / 11 / 777): every night before day 8 needed 0 retries; the most on any night through day
  14 was 3 (day 13 or 14); the median is 0 on every seed. The target holds. If it ever misses, it is tuned as a
  balance task.

**D-185 Review nits on already-guarded paths may be skipped (author).**
- Nits that only add cases to already-guarded paths can be skipped. Every skipped nit is listed in the PR body.

## 2026-10-01: S4 style board

**D-186 Art set: KayKit Adventurers cast + Kenney rounded kits + a procedural Boar (style board set E, D-183).**
- **Board:** `docs/review/media/s4_style_board/`. Five sets were rendered in the real game camera with the diner, a
  tower, a fence, steaks and coins; closeups, 40% phone-size images and a night render for the winner. See its
  README.
- **Rejected:**
  - (a) Kenney Blocky Characters + Cube Pets hog. Blocky faces and limbs clash with the rounded kits, and the hog
    reads as a toy pet. Fails the D-183 cohesion rule.
  - (b) Quaternius Ultimate Animated Characters + tinted farm Pig. Slim, small-headed bodies get lost at game
    distance. There is no archer mesh, there is no run animation (Walk only), and the faceted Pig is a different
    style from the rounded kits.
  - (c) KayKit + farm Pig. The cast is right; the Boar is not.
  - (d) KayKit + Quaternius cute-monster Pig. That Pig is a head with no body and only one animation.
- **Picked (set E):**
  - **Cast: KayKit Character Pack Adventures 1.0 (CC0).**
    - **Hero:** Barbarian body as the diner cook. The hood, cape and props are hidden; a procedural chef hat sits on
      the head bone; a white apron overlay; a KayKit Restaurant Bits frying pan as the weapon.
    - **Archer:** Rogue_Hooded with a crossbow (green).
    - **Tank:** Knight with a shield (steel).
    - **Travelers:** Rogue and Mage without props, desaturated toward grey-beige.
    - **Animation:** all share one rig with 76 animations (idle, running, attacks, hit, death).
  - **Boar: procedural, built from rounded primitives in Godot.**
    - **Shape:** a dark red-brown barrel body, a big low head, a pink snout, angry brows, big white flared tusks, a
      black mohawk ridge, stubby legs.
    - **Animation:** tweens (idle, run, attack, hit, death).
    - **Why procedural:** no CC0 rounded, animated boar exists. The only boar models found are CC-BY (Poly by
      Google), which this project does not use.
  - **Environment:** Kenney Tower Defense, Castle, Fantasy Town, Food and Platformer (coin) kits, plus KayKit
    Restaurant Bits for diner props. All CC0.
- **Why:**
  - Chunky, big-headed, rounded KayKit bodies match the rounded Kenney kits and read best at game distance.
  - Each role has a distinct silhouette:
    - the white chef hat and hero ring;
    - the green hood and crossbow;
    - the steel helmet and shield;
    - muted unarmed travelers;
    - a red tusked quadruped.
  - It is the only set with idle, run, attack, hit and death for every humanoid.
  - At 40% size and at night, the hero is the brightest spot and the Boar still reads by its ridge and tusks.
- **Deviation:** IDEA.md names Kenney and Quaternius. KayKit is a third CC0 source, and the Boar is procedural (in
  REVIEW_QUEUE).
- **Open for the spec:**
  - The Boar's draw cost: 26 mesh instances per Boar in the prototype.
  - The KayKit file size: 3.6 MB per character glb, mostly animations.
  - The diner roof: an 8 m slab dominates the frame.
  - The tusks are too horizontal (about 70°). Production uses about 55°.

## 2026-10-01: S4 spec (autonomous, D-159; revised after the spec review)

Full text: `docs/superpowers/specs/2026-10-01-s4-art-pass-design.md` §3.

**D-187 Layout and licence log.**
- **Layout:**
  - `assets/<pack-id>/` holds third-party files: only the files used, plus the licence normalised to `LICENSE.txt`.
  - `art/` holds the palette, materials, wrappers, builders and icons.
  - `tools/` holds headless and editor-only scripts, including the post-import script and the validator.
- **Export:** `tools/*`, `export/*` and `assets/_candidates/*` are excluded.
- **Licence log:** ASSET_LICENSES moves to one row per pack (licence SHA-256, file count), checked by the validator.
- **Supersedes:** this replaces the `ASSET_PIPELINE.md` promised in D-024.

**D-188 One palette.**
- 32 named colours. Swatch atlases are remapped offline to the nearest colour in Oklab, with per-swatch overrides.
- Shared external materials.
- Icons are quantised the same way.
- The validator enforces palette-only textures.

**D-189 KayKit size.**
- A post-import script in `tools/` strips the clips and writes one shared AnimationLibrary with 8 clips: Idle,
  Running_A, Walking_A, Throw, 1H_Melee_Attack_Slice_Diagonal, 2H_Ranged_Shoot, Hit_A and Cheer.
- The library is written only when stale, so CI's `--import` never rewrites it.
- Fallback: `_subresources` per clip.
- Each imported character scene is under 500 KB.

**D-190 ActorVisual contract.**
- `set_motion`, `face`, `attack`, `hit`, `set_flash`, `die`, `reset`, `flash_active`.
- **Ownership:** the Visual root's scale and visible stay with today's gameplay tweens; ActorVisual animates only an
  inner `Body`. The Boar flash timer stays in its physics tick.
- **Proof:** a determinism baseline recorded on the Mac (3 seeds, run twice), never re-recorded in S4.

**D-191 Characters.**
- **Hero:** the Barbarian-bodied cook. It throws spinning knives (an upper-body Throw) and cheers at dawn. No
  hit or death (D-161).
- **Archer:** Rogue_Hooded with a crossbow (bolts). No hit (D-164).
- **Tank:** Knight. Hit_A is throttled by `hit_react_cooldown`. The knockout is the existing poof (a tween fake).
- **Travelers:** 6 muted variants from a visual-only factory counter; no gameplay field and no Rng.

**D-192 Boar.**
- One merged ArrayMesh, built once.
- Shader legs; the phase comes from `NODE_POSITION_WORLD` (fallback `MODEL_MATRIX[3]`).
- 3 shared materials, so one draw call.
- Tweens on the inner Body finish within 0.15 s.

**D-193 Draw calls.**
- MultiMesh piles (fallback: per-instance MeshInstance3D).
- No real-time shadows.
- Blob shadows under characters and Boars.

**D-194 World.**
- **Diner:** a flat roof and parapet (the Archer's perch), a chimney, a rooftop WorldLabel board and an awning.
  OccluderFade uses the wrapper's AABB, also fades Label3D, and ignores aim points on its own roof (the Archer).
- **Towers and fences:** the model changes per level.
- **Ground and props:** a position-hash variation and a hand-placed prop list.
- **Lighting:** a warm day and a readable blue night via `LightingDirector`.

**D-195 UI and cards.**
- Theme resource.
- HUD icons and card portraits are rendered from the game's own 3D assets, quantised to the palette.
- The card strip shows icons + level.
- The joystick skin is left to S5.

**D-196 Budgets.**
- **Perf:** iOS Simulator at night 3 on the profile build, at least 58 fps average, reached by save injection and
  checked at P2, P4 and P6. Desktop guide: at most 120 draw calls at the night-3 peak and at most 150 at the day
  peak (full queue). The perf fixtures are a night-3-start save (resume_phase NIGHT) and a day save.
- **Size:** `gzip -9` of wasm + pck + js at most 16 MB, and the raw pck at most 8 MB, gated in `pages.yml`.
- **Textures:** at most 512².
- **Triangle budgets:** per `art/budgets.gd`, with the KayKit counts measured before they freeze.
- **VRAM compression:** ETC2/ASTC is restored (D-158) and counts toward the size.

**D-197 Build spots.**
- **Level pips:** palette-gold stars, outside Visual.
- **Unbuilt marker:** a sibling of Visual, shown at level 0 in DAY.
- **`World.add_static_box`:** collision-only, plus a visual scene; the sizes are unchanged.
- **`build_level_scale`:** 1.1 → 1.0, because the model change shows the growth (in REVIEW_QUEUE).

## 2026-10-01: S4 P1 (autonomous)

**D-198 Character triangle budget 5500 (amends D-196).**
- **Measured:** KayKit bare bodies (head, torso, arms, legs; every prop hidden) are 3921–4263 triangles.
- **Role kits:** with their hat or hood, cape and weapon, the role kits come to about 4.8k–5.3k. The silhouettes
  need those props (D-183): the chef hat, the Archer's hood and crossbow, the Tank's helmet and shield.
- **Budget:** hero, Archer, Tank and traveler scenes get 5500. The other budgets are unchanged.
- **Perf:** draw calls, not triangles, are the main web perf cost here.

**D-199 S4 P1 findings: materials, size, perf protocol.**
- **Materials:** the shared palette materials keep back-face culling. Pixel diffs from behind on the capes, pennant,
  awning and selection marker showed no missing faces, while disabling culling adds cape-lining artefacts.
- **Texture filter:** nearest, with no mipmaps. Mipmaps would blend swatches into off-palette colours.
- **Atlases stay lossless** (`compress/mode=0`) on purpose. VRAM compression (D-158) is on for any future
  compressed texture.
- **Size:** export excludes `tools/`, `export/`, `assets/_candidates/` and the unused source textures. The release
  pck went from 12.3 MB to 2.16 MB. The `gzip -9` payload is 11.87 MB (wasm 10.05). The D-196 gates (8 MiB pck,
  16 MiB gzip) leave about 4 MB for art, and `pages.yml` enforces them.
- **Perf measurement protocol:** the profile overlay resets its window on every phase change. After a 2 s warm-up,
  which keeps the first-wave spawn inside the window, it freezes one 60 s `PERF phase=… day=…` line, with avg fps,
  worst, proc ms, physics ms, draw calls and slow %. `export/perf_night3.sh` reads it on the iOS Simulator from
  injected night-3 and day-3 saves.
  - Run-to-run spread is about ±1 fps (night 3 read 56.5–58.9 on the same build).
  - **So the D-159/D-196 gate is the median of 3 runs.**
- **Baseline (placeholder art, fixture seed 20260930):**
  - Night 3: about 58–59 fps, proc 16–18 ms, physics 1.1 ms, 35 draw calls.
  - Day 3: about 52 fps, proc 22 ms, 59 draw calls.
  - There is a 280–300 ms stall at the first-wave spawn.
  - Halving the 3D render scale did not move these numbers, so the cost is not 3D fill. The diagnosis continues
    (spike 2).
- **Harness fix:** the perf harness serves with `Cache-Control: no-store` (`export/serve_nocache.py`). A spike found
  Safari reusing an older build's pack between runs.
- **Day-phase cost (unresolved, S5):**
  - Day 3 reads about 52 fps (proc about 22 ms) against about 58 at night.
  - Spikes ruled out:
    - 3D render scale (0.5 made no difference);
    - full viewport stretch (+0.3 fps);
    - the HUD (+3 fps, noise level);
    - Label3D text re-layout (0 text sets by day);
    - MSDF fonts;
    - an opaque prepass.
  - The 9 labels cost about 2 draw calls each. Removing the outline saves 8 draw calls but hurts readability.
  - The gate is night only, so this goes to S5 perf work and to known issues.

**D-200 Hero art details (S4 Task 7).**
- **Barbarian atlas:** its two blue gradient columns (torso, sleeves) are pixel-identical, so a hex override can't
  split them.
  - The default atlas maps them to `cloth_blue`.
  - An apron atlas maps them to `apron_white`.
  - The apron material is only on `Barbarian_Body`, so the sleeves stay blue.
- **Knife:** the hero's knife projectile is about 0.7 m, not 0.5. At 0.5 m it was 2–4 px wide and invisible from
  behind (REVIEW_QUEUE).
- **Projectile art:** each projectile builds its knife and arrow art once and toggles visibility. The shared pool
  flips kinds constantly at night, so this avoids per-shot instancing.

**D-201 Draw-call discipline (S4 P2 perf checkpoint, amends D-193/D-196).**
- **What the checkpoint found:** with the KayKit cast in, night 3 dropped to 47.4 fps (57 draw calls) and day 3 to
  30.8 fps (101 draw calls) on the iOS Simulator profile build.
- **What the spike showed:**
  - Draw calls and skinned surfaces dominate. Each KayKit character is 6 skinned parts, 1–3 props and a shadow.
  - Animation CPU does not: animation off gave +2 fps, and 15 Hz updates gave +0.
  - Merging the skinned parts alone gave night 56.5 and day 43.9 fps.
- **Rule from now on:**
  1. **One draw per character.** `tools/bake_characters.gd` bakes each role offline into one skinned ArrayMesh
     (body plus rigid-bound props, prop UVs retargeted onto the character's palette atlas), committed under
     `art/characters/baked/`. Travelers have 2 baked bodies × 3 tone materials.
  2. **One draw for all blob shadows:** a shared `ShadowField` MultiMesh updated per frame from registered actors.
     The Boars use it too (Task 9).
  3. **Static environment merged:** the diner and each tower/fence level are merged into as few meshes as their
     materials allow (Tasks 11–13).
- **Hero:** the hero bakes entirely onto the apron atlas, so its sleeves turn white (a full chef coat;
  REVIEW_QUEUE).
- **P2 checkpoint after the bake** (iOS Simulator, profile build, 3 runs):
  - Night 3: 58.1 / 58.3 / 58.2, median 58.2 (gate ≥ 58 passes); 35 draw calls, the same as the placeholder
    baseline.
  - Day 3: 48.6 fps, 60 draw calls (pre-cast 52 / 59).
  - Headroom is thin, so P3–P4 must keep draw calls flat or lower.

**D-202 Boar production details (S4 Task 9).**
- **Mesh:** one merged mesh, 1456 triangles.
- **Shading:**
  - Rim 0.35 and roughness 0.6 in the shared shader.
  - The upper body is lerped 0.4 from `enemy_maroon` toward `enemy_red` (the only non-swatch colour; ART_BIBLE),
    because pure maroon read near-black under lambert in the game camera.
  - The flash colour is pale pink-white (`warm_white` → `enemy_snout`), never white (R2).
- **Animation and shadow:**
  - The leg phase uses world position × 0.6, so trot speed is the same on every lane.
  - There are 4 shared materials (idle, run, flash, run_flash).
  - The shadow goes through the ShadowField.
- **Tusks:** they read clearly at full size but only as small white flares at 40% (REVIEW_QUEUE).

**D-203 Pickup art (S4 Task 10/10b).**
- **Draw calls:** ground steaks draw through one shared `PickupField` MultiMesh, with one stable slot per pooled
  steak (one draw in total; D-201). The piles (counter, freezer, gold, carry) are one MultiMesh each.
- **Ground steaks** are drawn at `ground_steak_scale` 1.6 so they read as cartoon steaks at phone size. Pile steaks
  stay at 1.0.
- **Carry stack:** it sits behind the hero at 0.09 m spacing `(0, 1.3 + 0.09 i, -0.3)`, so it never covers the
  cook's face (R2). A max stack (16) is still a satisfying tower.
- **Coins:** coin rims map to `gold`, so stacks read gold, not bronze.

**D-204 Diner art details (S4 Task 11; amends D-194).**
- **Mesh:** the diner is one baked mesh with 2 surfaces (2976 triangles), plus the rooftop DINER board (a WorldLabel,
  about 2 draws). The counter and freezer are 1 baked mesh each.
- **Occluder fade:** it tests per-part boxes from `DinerArt.occluder_boxes` (walls plus parapet to 3.4 m, the
  chimney, the sign). A single merged box (up to 5.3 m because of the sign) faded the diner when nothing was hidden
  (the hero at the night-1 start, far north-lane Boars), against D-151. A test keeps every tall vertex inside a box.
- **Colours:**
  - The flat roof is grey gravel (`stone`), because a teal roof read as water. Teal stays as the trim.
  - The freezer is `ice_blue`, because the remapped fridge read green on grass.
  - The awning reads as a cream band.

**D-205 Build-spot art details (S4 Task 12; amends D-194/D-197).**
- **Baked pieces:** every level model, rubble, marker, sign, flag and gate is one baked draw.
- **Towers:**
  - L1: bottom, top, ballista.
  - L2: adds a middle section.
  - L3: two middle ledges, top, ballista (2.2 / 2.8 / 3.4 m).
  - The plan's L3 roof and crystals were dropped: the crystal platform clipped the roof, and a max tower must show
    its weapon.
- **Fences:** the material tells the level.
  - L1: a low wood fence.
  - L2: a heavier wood fence with raised posts.
  - L3: a grey stone wall.
  - Rubble: brown boards.
  - These use castle-atlas variants (wood, stone) and a fantasy-town rubble variant.
- **Pips:** gold stars, unshaded and tilted to face the camera (ART_BIBLE §4: indicators are unshaded).
- **Model swaps:** only on a level or rubble change (an int key).
- **Close-up sign:** built from wall panels, since there is no post piece in `assets/`.

**D-206 Ground, lanes, props, lighting (S4 Task 13; amends D-194); P4 perf checkpoint.**
- **Static world: 4 draws** (it was 7 placeholders):
  - one terrain mesh (ground, road, lane strips);
  - one edge-stone MultiMesh;
  - props baked at runtime into one mesh per atlas (2).
  - The placeholder primitives are banned (validator), and `world/visuals.gd` keeps only `visual_root()`.
- **Lighting:**
  - Day: warm sun `fff3c4` 0.85, ambient 0.55.
  - Night: sun `d8e2ff` 0.55, ambient (0.36, 0.40, 0.58), background dark grass.
  - Night lit luminance is about half the day's. White stays the hero's colour; a bluer night sun made the chef hat
    read like the Tank's steel.
  - The first phase after boot or resume snaps, with no 1.5 s fade from day.
- **P4 perf checkpoint** (iOS Simulator, profile build, idle machine, 3 runs):
  - Night 3: 59.8 / 59.8 / 59.6, median 59.8 (gate ≥ 58), 32 draw calls, proc 13 ms.
  - Day 3: 57.3 fps, 59 draw calls.
  - Both beat the placeholder baseline (58.3 / 52), because the baked art draws less than the primitives did.
  - One reading taken while other Godot jobs ran was invalid (proc 48 ms). **Perf is only measured on an idle
    machine.**

**D-207 UI theme details (S4 Task 14; amends D-195).**
- **Theme:** `ui/theme/game_theme.tres` is generated by `tools/build_theme.gd` from the palette. A test compares
  the committed file with the builder, so it can't go stale.
  - Panels are `diner_cream` with an `ink` border.
  - The banner is `night_sky` at alpha 0.85.
  - Card bands are `gold` (adventurer) and `diner_teal` (upgrade).
  - Gold is an accent only.
- **Font:** the variable Nunito defaulted to its thinnest weight (200). All UI and world labels now use a bold
  variation (`wght` 800, `ui/fonts/nunito_bold.tres`). The world-label outline is 8, down from 12, so digits read
  solid at phone size.
- **Lane arrows** use `enemy_red`.

**D-208 Icons, card art, coin (S4 Task 15; amends D-195, D-203).**
- **Icons:** `tools/render_icons.gd` renders 11 icons from the game's own 3D art at 256 px. Each is quantised to a
  per-subject palette:
  - no enemy reds, except the heart;
  - no traveler tones, so steel reads as steel;
  - no gold on food.
- **HUD:** a coin icon beside the gold counter (the label moved right to fit it), a heart beside the diner bar, and
  moons on ink discs (lit warm white, unlit dim).
- **Cards:** each card shows its portrait leading the text row; the card size is unchanged. The card strip shows
  backed icons with level badges.
- **Coin:** a procedural solid gold coin (`art/pickups/coin_mesh.gd`, 288 triangles) replaces the Kenney Platformer
  coin, which was a hollow octagon that read as a nut. The Platformer pack is removed.
- **Not in the HUD:** there is no steak counter; `steak.png` is rendered but unused until S5 decides.
- **Tooling:** `tests/sim/capture.gd` now fails if the camera is not in place at grab time. One glitched shot was
  found and retaken.

**D-209 S4 final perf, UI draw diet, measurement rules (Task 16/16b).**
- **UI draw diet:**
  - One icon atlas (`art/icons/atlas.png`): 11 icons plus a baked card backing and an ink disc.
  - The card strip and the HUD icons are single custom-drawn controls.
  - Polygons (`draw_style_box`, `draw_circle`) do not batch in the Compatibility renderer, so shapes are atlas
    cells.
  - Night-3 desktop draws: 67 → 48 with 2 cards, and 81 → 48 with 7.
  - The validator skips `atlas.png` for the enemy-colour and 256 px rules. The per-icon files are the checked
    source, and a test checks that only the heart cell is red.
- **Final perf** (iOS Simulator, profile build): night 3 reads 59.3 / 55.8 / 59.0, median **59.0** (gate ≥ 58),
  at 36 draw calls. Day 3 reads 49.6.
- **Final size:** pck 4,398,040 B; gzip payload 12,787,266 B.
- **Measurement rules:**
  - `export/perf_night3.sh` waits for the Mac to be at least 75% idle and prints the idle figure before and after.
    The same build read 59.5 idle and 51.9 with an editor at 53% CPU.
  - Stale agent processes are killed first.
  - Readings taken with other Godot jobs running are invalid.
- **Capture rule:** the bad shots came from `FocusPause` (D-147). It pauses the tree when the capture window loses
  focus, while rendering and `physics_frame` carry on, so a shot shows a frozen game: wrong banners, no Boars, or
  the camera before it moved. `tests/sim/capture.gd` now removes FocusPause and fails if the tree is paused, the
  camera is not in place, or fewer than 5 frames were drawn after the camera was set.

## 2026-10-02: S5 spec (autonomous, D-159)

Full text: `docs/superpowers/specs/2026-10-02-s5-polish-onboarding-audio-juice-design.md` §3.

**D-210 Settings live outside the save.**
- A `SettingsStore` keeps `{v, muted, guide_done}` under `lst:<pathname>:settings` (a `user://` file off web).
- A corrupt or missing value means defaults. `SaveStore.wipe()` and New game do not reset it.
- It is built only in the `auto_start` boot path; tests inject it.

**D-211 Audio sources and size.**
- **SFX:** Kenney CC0 audio packs, one file per event.
- **Music:** two OpenGameArt CC0 tracks: day "Happy Adventure Loop" (tinyworlds), night "Chiptune Adventures:
  Stage 2" (Juhani Junkala). Each lives in `assets/oga-<slug>/` with a `LICENSE.txt` that records the page URL,
  the retrieval date, the licence field verbatim, the uploader-is-author check, the source SHA-256 and the ffmpeg
  command.
- **Encoding:** MP3 (libmp3lame), mono, 32 kHz, 64 kbps, at most 60 s. The installed ffmpeg has no libvorbis. An
  MP3 loop may have a small gap at the loop point; `docs/review/AUDIO.md` says so.
- **Budget:** all audio at most 2.5 MB. The validator enforces it and fails on any audio file the manifest does
  not name.
- **Chosen without listening:** the agent cannot hear. Sounds are picked by measured length, peak and mean level
  (±3 dB of a class target). Every choice is one line in `art/audio/audio_manifest.gd`, listed in
  `docs/review/AUDIO.md` (REVIEW_QUEUE, high).

**D-212 Web unlock, playback type and mute.**
- Nothing plays before the audio context runs; music starts at unlock with the current phase's track.
- **Probe:** the web shell subclasses `AudioContext` and keeps each context in `window.LST_AUDIO`; `unlocked` is
  "some context is running". Only if the hook found no context is it "an input release was seen". Off web it is
  true at once.
- **Playback:** SFX are samples, registered at boot behind the boot fade. Music's mode is picked by the Task 3
  spike, first option that passes: (1) samples, both tracks at boot (registration under 0.5 s, decoded size at
  most 48 MB); (2) stream playback (no underrun, at most +1 ms mean `proc_ms`); (3) samples, one track at a time,
  swapped at `phase_changed`. The result is appended here by Task 3.
- The spike checks the probe on Chromium (before and after a tap) and the iOS Simulator (before a gesture only:
  the harness has no input). The after-gesture check on a real iPhone is a final-review item.
- **Spike result (Task 3a, 2026-10-03): music mode `swap`.** Registering both tracks took 115–138 ms (Chromium)
  and 121 ms (iOS Simulator); decoded size 34.6 MiB at 44.1 kHz, 37.7 MiB at 48 kHz, so rule (1) passed as written.
  But the added memory, which the 48 MB limit was meant to bound, is 72–78 MiB: the Web Audio buffers persist outside
  the WASM heap, and registration raised the WASM high-water mark by 37 MiB, which never shrinks. Stream playback
  showed no underrun, but its CPU cost could not be read on software WebGL, and a stream is mixed on the main thread
  in a single-threaded build, so long frames would glitch the music. `swap` keeps one track registered (about
  36–41 MiB) for a registration of about 60–70 ms at each music change, behind the phase banner; Task 7 measures it.
  The iOS Simulator's locked state reads `interrupted`, not `suspended`; the probe (`state == "running"`) is
  unchanged. Resuming from `interrupted` on a real iPhone is a final-review item.
- **Amended (Task 3b, 2026-10-03): music mode `lazy`, not `swap`.** Godot 4.7.2 has no call to unregister a sample
  (`AudioServer` binds only `register_stream_as_sample` and `is_stream_registered_as_sample`). A Chromium check that
  counts Web Audio buffers (`git show 583fbd2:export/pw_audio_swap_check.mjs`) showed that dropping every reference to the old track
  does not free its buffer, and switching back registers the track again: `swap` leaks one track per music change.
  So the only non-leaking sample modes keep both tracks. `lazy` registers each track the first time it plays (night
  at the first tap, day at the first dawn) and keeps it. Measured in Chromium
  (`export/pw_audio_music_check.mjs`): 36.3 MB of registered buffers plus one playback copy of the playing track,
  about 53–56 MB steady (44.1 kHz), with a peak of 72.6 MB of music buffers (76.2 MB of all buffers) right after each
  switch, before GC; switching back reuses the registered sample. The two 60–70 ms registrations fall at different
  moments: the warm-up registers the resume phase's track behind the boot fade (Task 7), and the other one registers at
  its first use. Stream playback stays rejected (main-thread mixing
  glitches on long frames). The 48 MB limit was this spec's own guess, not a platform limit; the measured cost goes to
  REVIEW_QUEUE for the phone check.
- One toggle mutes the Master bus and is saved at once.

**D-213 Onboarding is one pointer.**
- A `Guide` shows one pointer with at most three words, from an ordered list of pure state predicates.
- Night 1 (`day == 1`): move, fight, grab. First day (`day == 2`): build, collect, take, stock, close.
- `fight` is true whenever a Boar is alive and none is in the hero's range; `grab` whenever no Boar is alive and
  a ground steak can be carried. Neither turns off after the first kill or pickup: a one-shot rule left a
  pointer-following player standing still while later waves took another lane (second spec review).
- `build` shows while a spot is affordable (`0 < remaining_cost ≤ gold`; a maxed spot never is) and points at
  the affordable spot with the lowest `next_level_cost`. `close` shows only while `Pulse.should_pulse()` is true.
- `take` waits for counter room for a full load (`min(carry_capacity, freezer, counter_capacity)`), and holds
  while the hero fills up in the freezer zone. This stops one-steak trips after each sale.
- An off-screen target gets an arrow clamped to the HUD's arrow rect (inset 40 px more), using the lane-arrow
  maths, now in `core/edge_clamp.gd`.
- Its one counter (walked distance) resets on `state_restored`. It never pauses or blocks input.
- It ends on the first `phase_changed(NIGHT, day ≥ 2)`; `guide_done` is saved per device.
- A sim proves it on two seeds: a bot that only follows the pointer clears night 1 with 0 fails and reaches
  night 2 with at least one build.
- **Guide sim details (Task 11, 2026-10-03):** the sim bot re-routes a chase only when the target's nearest graph node
  changes (re-routing on every 1 m of target movement made it dither and lose night 1). The day-2 "no rule for more
  than 5 s" check is sampled at the Guide's evaluations, like the fight check: between a sale that empties the counter
  and the next 0.25 s evaluation, the Guide still shows the previous (empty) rule, which is the rule's defined rate,
  not a dead spot. Measured: longest legitimate wait for travelers 13–20 s with a stocked counter.

**D-214 Juice is one draw; two request signals.**
- An `FxField` MultiMesh of 192 CPU-animated quads draws every poof, spark, sparkle and dust. When full, the
  oldest quads are replaced.
- No GPUParticles and no Label3D pop-ups.
- `EventBus.sfx_requested(id)` and `EventBus.fx_requested(kind, position)` carry local events (a throw, a hit, a
  payment tick, a UI press) to `AudioDirector` and `FxField`. No gameplay code listens to them.
- Screen shake replaces the existing one in `camera_rig.gd`; it stays a camera offset from a fixed table and can
  be turned off with `Balance.ui.shake_enabled`. The cooldown gates `diner_damaged` only; `diner_fell` always
  shakes, because both are emitted in one `damage_diner` call.
- No randomness and no gameplay timing.
- **Retuned after the Task 4 shot review (2026-10-03):** the spec's kind table read too small at phone size. Now
  poof size 0.75; hit 4 sparks, size 0.8, life 0.25; dust 3 puffs in `stone`, size 0.7, life 0.45; coin 5 stars, size
  0.45, life 0.6; sparkle unchanged. The table is `FxField.KINDS` (REVIEW_QUEUE).

**D-215 Warm-up.**
- Task 7 first attributes the first-wave stall with an A/B on the profile build; the cause was never proven.
- `Main._boot` awaits a warm-up that draws one of each visual inside the camera frustum, under an opaque boot-fade
  layer, for three frames, then frees them. Off-screen drawing would be culled and compile nothing.
- `_boot()` awaits only when a Warmup node exists, so tests that call it stay synchronous.
- It uses temporary nodes only: no pools, no PickupField slot, no GameState, no Rng.
- If `worst_ms` stays at or above 60 with every first-use item warmed, the measured cause becomes a known issue
  for the final review.
- **Amended (Task 7, 2026-10-03), from measurement.** The perf overlay now records the 3 worst frames with their
  timing, and with `?perfwarm=4` also the worst frames before its window. Findings (iOS Simulator, profile build,
  `docs/review/media/s5/perf_p2/README.md`):
  - The "first-wave stall" was mislabelled. The night-3 worst frame landed 0.1–0.2 s after the overlay's own 2 s
    warm-up boundary, before any wave; part of it was the overlay's first-time work at that boundary.
  - The real cost is a load freeze after the phase starts: about 2.1 s without the warm-up and about 0.85 s with it,
    after the boot fade had already lifted. Without the warm-up there are also 95–129 ms first-use frames after wave
    0 starts; with it there are none above 43 ms.
  - So the warm-up stays, and the boot fade now stays opaque until it sees 10 consecutive frames under 50 ms (at most
    4 s), so the remaining load freeze happens under the fade. The overlay reads its monitors during its warm-up too,
    so its boundary costs nothing new.
  - **Result:** night-3 median `avg_fps` 59.8; median `worst_ms` 71 (from 108 with the warm-up alone; main 134), so
    the < 60 gate fails. Priming the overlay's reads did not remove the frame at its window boundary. Per §5.4 the
    remaining frame (about 2.1 s after the night starts, also when the first 2 s banner hides) goes to the known issues;
    S5 does no further perf work on it.

**D-216 HUD pass.**
- Positions only: safe-area placement, the card strip clear of the diner bar, world labels dimmed (snapped to
  alpha 0.15) under HUD blocks, a settings gear top-right.
- The gear, the joystick ring and the knob are icon-atlas cells.
- The unused `steak` icon is removed; v0.1 has no steak counter.
- **Done (S5 Tasks 8a, 8b, 9, 2026-10-03):** the lane arrows are drawn from the atlas `guide_arrow` cell tinted
  `enemy_red` (removes the WebGL warnings and an unbatched draw); `steak` icon removed; world labels under HUD blocks
  dim fill and outline to 0.15; the gear and the panel are atlas-drawn (the panel backing keeps the atlas's 0.95
  alpha, the same look as the card overlay; its dim uses `ink`, the card overlay's `night_sky`).

**D-217 New game.**
- Settings panel → "New game" → a second tap after `card_input_guard_s` and within 3 s.
- The panel emits `new_game_requested`; Main calls `fresh_start()`: wipe the save, `start_new_game()`, close the
  panel, remove the `settings` pause reason. The debug R key calls the same function.
- The panel hit-tests touches itself, because `emulate_mouse_from_touch` is off.

**D-218 One pause owner.**
- Main owns a set of pause reasons (`focus`, `settings`); the tree is paused while the set is not empty. Main
  writes `tree.paused` only when the set changes between empty and not empty.
- FocusPause only emits `changed(paused)` and no longer touches the tree. Main maps it to `focus` and clears the
  reason when FocusPause leaves the tree. The settings panel adds and removes `settings`.
- `AudioDirector.set_suspended()` pauses its players while the tab is hidden (wired in Task 3).

**D-219 S5 gates.**
- Baseline identical; validator green including audio.
- Perf, median of 3 on an idle Mac: night-3 `avg_fps` ≥ 58; night-3 `worst_ms` < 60; day-3 `avg_fps` no lower
  than the S4 `main` build read in the same session, minus 1.
- D-196 size gates.
- Web console: no new error or warning against a baseline recorded from `main`.
- Audio is verified by state on web (suspended before a gesture, running after, mute persists), not by ear. Its
  CPU cost is reported from a Chromium A/B and is not gated.

**D-220 S5 results and the end-of-S5 perf reading.**
- S5 is complete: results in the S5 spec §13 and `docs/review/media/s5/perf_final/README.md`.
- Gates met: night-3 fps (59.6), size, console, web audio state, baseline identical, onboarding sim.
- Gates not met: night-3 worst frame (108 ms; D-215) and, at the end of S5 only, day-3 no-regression by 0.4 fps.
- All six end-of-S5 runs met the D-209 idle-before rule (≥ 75%), so they stand as the end-of-S5 reading: night-3 fps
  passes, the worst frame and day-3 fail. Another project's jobs ran between and during the runs; that weakens all
  three readings equally. No tuning in S5. The final review package re-runs the six-run comparison on a quiet Mac, and
  the perf harness also samples idle mid-run (the "after" figure is always low while Safari still plays).
- The day-3 gate is judged against S4 main (c8cce18), as §1.6 says. The P2 checkpoint compared with main at P2
  (37d14b3, S5 P1 merged), so its "pass" was not that gate.

## 2026-10-05: final review package

**D-221 Final review package and final perf reading.**
- `docs/review/FINAL_REVIEW.md` is the hand-over page; data and media are in `docs/review/media/final/`.
- Final perf (3 runs each, ≥ 75% idle before every run, mid-run idle now logged): night-3 59.9 fps (pass); night-3 worst
  frame 106 ms (fail; S4 main 119); day-3 52.9 against 54.0 (fail by 0.1). The end-of-S5 reading and this one agree, so both
  misses are treated as real and go to the author as known issues; nothing was tuned.
- Debug builds gain `?autoplay=1` (bots play; used to record the gameplay video in the input-less Simulator) and
  `?nooverlay=1`. Both live under `ui/debug/` and are absent from release and profile packs.
- v0.1 stops here for the author's review (D-159). S6 starts only after approval.

## 2026-10-05: E1 station upgrades (brainstorm with the author)

**D-222 Expansion split (author).** The author's expansion ideas (upgrade the counter and the freezer, hire staff, more
equipment, a bigger map) are four expansions, each with its own spec, plan and build: E1 station upgrades, E2 staff,
E3 new equipment, E4 map expansion. Only E1 is built before the v0.1 friend playtest; the playtest decides the order
of the rest. IDEA.md is amended: stations are a gold sink next to towers and fences.

**D-223 Counter upgrade = more customers (author).** A longer queue, faster arrivals and a bigger pile. No higher
price: it overlaps the gold-per-steak card and inflates gold.

**D-224 Freezer upgrade = bigger hauls (author).** Extra carry and more steaks per load tick. The freezer keeps no
capacity limit; spoilage stays in "Later".

**D-225 Five levels, cost doubles per level (author).** Base 30 (counter) and 25 (freezer). Starting values; tuned by
the sims.

**D-226 Station state is separate from `GameState.buildings`.** `buildings` means tower or fence in the lane code, the
dawn heal, the save validation and `Economy.level_cost`. Stations get `GameState.stations`, `StationBalance` and
`StationEffects`. Save schema 4, with the first migration (3 to 4).

**D-227 The counter upgrade also shortens the service time.** [AMENDED by D-230: the limit is the queue size, which
counts travelers still walking in, together with the interval and the service time.]

**D-228 Level 0 is today's game.** Every level-0 value equals the S5 value, and `NaiveBot` and `PlannerBot` never buy
station upgrades, so the S4 determinism baseline stays identical. A new `UpgraderBot` covers the upgraded game.

**D-229 No per-level station art in E1.** A level shows as the existing model (not scaled), a pop and star pips, as towers do.
Reversible; goes to `docs/REVIEW_QUEUE.md` when it ships.

**D-230 E1 spec amended after the spec review.**
- Success criterion 6 is three sims on seed 20260930: served travelers strictly increase per counter level (by at least
  `min_level_gain`, 8%); a preset level-3 counter shortens DAY phase 1; `UpgraderBot` holds nights 1 to 3. The first
  draft compared the upgrader's day 3 with the planner's, which cannot pass: with defense first, 8 to 38 gold is left.
- Level 5's queue is 9. The first table's level 5 was about 2.5% better than level 4 (hand estimate).
- The freezer upgrade is comfort (fewer trips, more night pickup), not day speed: selling is about 2.3 s per steak,
  hauling about 0.5 s. Accepted; the author chose it (D-224).
- Pad and queue slot coordinates are fixed by unit tests (clearances, the prop rule, on screen at 9:16), not by the spec.
- The sweep gets `--bot=upgrader` and its own CSV, not a new column: a column would break `baseline_diff.sh`.
- `WaypointGraph.create_default()` is frozen; `UpgraderBot` extends its own copy.
- Built-in save migrations live in a constant table, so tests that clear `SaveCodec.MIGRATIONS` cannot remove them.
- The guide ignores stations; the sign pulse counts them.

## 2026-10-05: E1 build (subagent-driven; rulings by the main session)

**D-231 E1 build decisions.**
- **Tables unchanged.** Sim 6.1 on seed 20260930: travelers served in 60 s per counter level 0 to 5 = 16, 20, 24, 29, 33,
  38 (gains 25, 20, 21, 14, 15%; minimum 8%). No tuning round was needed.
- **Sim 6.2:** DAY phase 1 with the planner takes 108.4 s at counter level 0 and 77.3 s at level 3.
- **Upgrader sweep, 14 days, against the planner baseline** (`docs/review/media/e1/sweep_upgrader_<seed>.*`):

  | Seed | first_fail_day (upgrader / planner) | hard break | Day 8 to 14 day length (upgrader / planner) | Unspent gold at day 14 | Stations at day 14 |
  |---|---|---|---|---|---|
  | 20260930 | 10 / 10 | none / none | 173 to 206 s / 313 to 380 s | 627 / 2312 | counter 5, freezer 5 |
  | 11 | 11 / 11 | none / none | 186 to 211 s / 299 to 380 s | 157 / 1822 | counter 5, freezer 5 |
  | 777 | 10 / 10 | none / none | 217 to 274 s / 298 to 385 s | 177 / 1102 | counter 4, freezer 4 |

  `first_fail_day` does not move on any seed. Days 8 to 14 are 14 to 53% shorter than the planner's (seed 20260930: 34 to
  53%; seed 11: 38 to 49%; seed 777: 14 to 41%). The first station level lands on day 2 or 3 (freezer), the first
  counter level between day 3 and day 7.
  "Defense first" holds within a day only: station spending removes the gold the planner would carry over, so on some
  nights of days 4 to 8 the upgrader is one or two fence levels behind. Night 9 on seed 20260930 ends at diner 0.033
  against the planner's 0.083.
- **One payment rule** (`GameState._pay_towards`) and **one paid-tick feedback** (`PayFx`) are shared by build spots and
  stations; the plan's line-for-line copies were replaced after review. Behaviour of build spots is unchanged
  (`baseline identical`).
- **Pads show the station's name** above the cost. A number alone did not say which station a pad upgrades.
- **A saved `paid` at or above the next cost is clamped to `cost - 1` on load** (spec 5.5 amended): a later cost
  reduction never loses a save or bricks a pad.
- **Built-in migrations are a `match` in `SaveCodec._built_in`**, not a constant table (a constant cannot hold a
  Callable). A hook entry in `MIGRATIONS` still overrides it.
- **Phase 2 ran Tasks 5, 6, 7 in parallel** (D-136) at the author's request; Task 8b (tuning) was skipped as not needed.
- **Traveler pool: 31** (`StationEffects.traveler_pool_size`), up from 8. Visual order of traveler looks changes.
- **Queue slots 4 to 8 stand on the road's north edge** (z 10.3; the strip spans z 10 to 12).
- **CI on the phase 3 head:** `SIM SUITE: 35s (budget 60s)`; sim 6.1 prints the same counts as locally.
- **Day perf with a level 5 counter (iOS Simulator, profile build, `DAY_FIXTURE=day3_counter5`): NOT a valid gate
  reading.** The Mac never reached the 75% idle the method requires (other programs of the author's were at about 97%
  and 57% CPU; idle before each run 60 to 69%), so the absolute numbers cannot be compared with D-221's 52.9 fps.
  Taken on the same loaded machine, back to back:

  | Fixture | Day avg fps (worst ms) | Night avg fps (worst ms) |
  |---|---|---|
  | `day3_counter5`, 3 runs | 39.1 (91), 42.8 (86), 42.5 (98) | 58.3 (109), 59.6 (117), 58.5 (229) |
  | `night3_closeup` (counter level 0), 1 run | 48.0 (100) | 59.6 (63) |

  What the day shot shows at level 5: the 42 stocked steaks are sold within the window, then 9 travelers stand in the
  queue (level 0: 4 travelers). Draw calls 81. So a level 5 day costs about 5 to 9 fps against level 0 on this
  machine and load. It is reported to the author as a known issue, not tuned; an idle-machine re-run is still owed
  (`docs/review/media/e1/readings_raw.md`, `shots_head/`).
- **Load time: not measured.** `load_time.mjs` and the emulated Android check failed at launch: Playwright in
  `~/.cache/lst-playwright` wants Chromium build 1243 and only 1194 is installed. One-time step for the author:
  `cd ~/.cache/lst-playwright && npx playwright install chromium` (agents never install system components, D-138).
  The traveler pool went from 8 to 31 prewarmed travelers, so boot time and memory are unmeasured for E1.
- **Device check:** iOS Simulator (iPhone 17 Pro, Safari) on the preview build: night 1 loads, nothing clipped by the
  notch (`docs/review/media/e1/device/ios.png`). No Android reading (same Playwright problem).

## 2026-10-06: E2 staff (brainstorm with the author)

**D-232 E2 starts before the friend playtest (author).** D-222 left the order of E2 to E4 to the playtest. The playtest
is postponed, and the author chose to keep building meanwhile; E2 (staff) goes first because it builds most directly on
E1's day loop (freezer, counter, traveler flow). D-222's "the playtest decides the order of the rest" is amended to
"the playtest decides the order of E3 and E4".

**D-233 E2 staff: brainstorm paused; a diner tier ladder comes first (author).** The E2 brainstorm stopped after three
questions because staff hang from a progression layer that is not in the repo yet: one global diner tier (1 to 5),
bought by standing on a new sign and confirmed by a boss night; each tier grows the diner and unlocks land, build spots
and monster types, and difficulty follows the tier instead of the day number. That ladder is its own expansion, specced
and built before E2; E2, E3 and E4 become content unlocked by tier (seller at tier 4, hauler at tier 5). Its first
slice is the tier system plus tier 2 only. D-232's "E2 goes first" is amended: the tier ladder goes first.

Notes the later E2 spec starts from (author's choices, 2026-10-06):
- **Hauler = pure automation.** It walks freezer to counter and keeps the counter stocked. It reads the freezer's
  `carry_bonus` and `load_per_tick` (the hero keeps the bonus too), so the freezer upgrade becomes the hauler's
  capacity. The spec never claims the hauler shortens the day: hauling is about 0.5 s per steak, selling about 2.3 s,
  and the day is limited by traveler flow.
- **Seller = throughput.** It shortens service or adds a second service lane, so the day gets shorter while gold per
  day stays the same (steaks per night are fixed). This is what makes the hauler's speed, and so the freezer level,
  matter.
- **Order: seller one tier before the hauler** (tier 4, then tier 5). For one tier the hero hauls for a faster counter.
  The E2 plan adds a sim proving a hero without a hauler can keep the counter stocked at the seller's throughput; if
  it cannot, the author is told before the order changes.
- **"A day where you watch" is accepted:** staff arrive at tiers 4 and 5, when the hero has more build spots, station
  pads and the tier sign to use. Giving the hero a new day action instead is out of E2's scope.
- Open (not decided): how many staff, whether they level up, one-time price or wage, where they are hired, what they
  do at night, how they look, day perf with more animated characters (each KayKit character is about 5k triangles).

## 2026-10-06: E1 follow-ups (owed from the E1 final review)

**D-234 A station level above `max_level` is clamped on load, not rejected.** `SaveCodec.validate` accepted
`0 <= level <= max_level`, so lowering `stations.max_level` in a later build would have rejected every save that had
reached the old maximum. Validation now checks only `level >= 0`; `GameState.from_dict` already clamps the level to
`max_level` (and `paid` to `cost - 1`, D-231). Same rule as `paid`: a later balance change never loses a save.
Also in this follow-up set: the four E1 test files derive every cost from `StationEffects` instead of literals (so cost
tuning does not break tests); the counter, freezer and build-spot pop tween share one helper (`PopFx`) and every pop is
killed on `state_restored`; a unit test pins `World.add_static_box`'s child order (shape, then visual root), which the
station pop depends on.

**D-235 E1 owed measurements (2026-10-06, `main` at 63b2532).**
- **Load time** (release build on localhost, Playwright Chromium 1243, Pixel 7 profile, software GL, 3 fresh contexts;
  `docs/review/media/e1/load/load_time_chromium.txt`): `t_engine` 6720 / 4050 / 3662 ms, `t_first_px` 6618 / 3997 /
  3640 ms, `t_full` 10971 / 8593 / 7923 ms. D-221: engine 4796 / 3700 / 3582, full 9148 / 7974 / 7941. Medians: engine
  4.05 s against 3.70 s, full 8.6 s against 8.0 s. Runs 2 and 3 sit inside D-221's spread; run 1 is a cold-start
  outlier. The Mac was not idle (about 55 to 60%), so this is not a strict comparison; the 31-traveler pool shows no
  load-time cost larger than the noise. `index.pck` 5,529,580 B (D-221: 5,514,672; gate 8 MiB).
- **Emulated Android check** (`export/device_check.sh` on the Pages root, D-141): Playwright Pixel 7 renders night 1
  with the HUD, moons, guide arrow and joystick, build `63b2532 main`; the iOS Simulator (iPhone 17 Pro, Safari) shows
  the same frame with nothing under the notch (`docs/review/media/e1/device_main/`).
- **Memory with the 31-traveler pool: still unmeasured.** No script reads heap or GPU memory; left in `REVIEW_QUEUE.md`.
- **Level 5 day perf idle re-run: postponed by the author.** One attempt on 2026-10-06 never reached the 75% idle gate
  (vitest and BlueStacks were running) and was stopped before measuring; nothing recorded. `build/web_profile` is
  rebuilt from 63b2532 and the command is `DAY_FIXTURE=day3_counter5 export/perf_night3.sh build/web_profile <out>`.

## 2026-10-06: E5 diner tier ladder (brainstorm with the author)

Spec: `docs/superpowers/specs/2026-10-06-e5-tier-ladder-design.md`. Plan: `docs/superpowers/plans/2026-10-06-e5-tier-ladder.md`.

**D-236 The diner tier is the progression spine (author; amends D-222 and D-233).** Five tiers; tier 1 is today's game;
difficulty follows the tier (a small per-day ramp to a per-tier cap in `balance/`), not the day; income only from kills;
tier-up = pay on a sign, win the boss night, the diner grows next dawn; permanent, no reset; mercy unchanged and hidden;
one thumb. D-222's E2, E3 and E4 are no longer independent expansions ordered by the playtest: they are content
unlocked by tier (E4 land and spots from tier 2, E2 seller at tier 4 and hauler at tier 5, E3 equipment at tier 4).
D-232's "the playtest decides the order of E3 and E4" is void. Slice 1 = the tier system plus tier 2.

**D-237 Tier-1 cap at day 7 and a one-time baseline re-record (author).** Rows 1 to 7 of the planner sweep are the
tier-1 identity and stay byte-identical (`tools/baseline_rows.sh 7`); rows 8 to 14 change, and the S4 baseline was
re-recorded once (evidence: `docs/review/media/e5/baseline/`). The "sweep CSV identical to today's" rule and the "first
fail day 10 ± 1" target are retired; the new targets are spec 8.2. A tier-1 save past day 7 meets day-7 pressure after
the update (accepted).

**D-238 Boss rides wave 3 (author).** A boss night is the tier's capped night plus the boss first in wave 3's main
group; 3 moons, the third a boss moon; a world HP bar; nothing from the next tier appears before the win; a loss is
the existing retry with the payment kept; mercy applies; the boss drops a night's worth of steaks, swept to the freezer
at dawn like any others.

**D-239 Tier 2 unlocks two single-lane yard towers (author).** `tower_w` and `tower_e` on the side yards; towers answer
the hare, which fences cannot stop.

**D-240 Yards and the sign are pinned by tests, not by the spec (author).** Clearance from lanes by `lateral_spread`
+ 1 m, from every pad, zone, slot, post and path; on screen at 9:16; the yard ring is stones, not the wooden fence
model; the tier sign stands on the land it sells. Final coordinates: `tower_w` (-10.6, 0.6), `tower_e` (8.8, 1.1), west
yard `Rect2(-13.5, -2.5, 4.5, 10.5)`, east yard `Rect2(8.0, -0.5, 5.0, 3.5)` (shaped by the props and the 3 m rule),
sign (-10.0, 7.5).

**D-241 The hare's share ramps (author).** 0.15 on the first tier-2 night, 0.35 from the third day, so the first night
teaches the threat.

**D-242 Boss tuned for a long readable fight (author).** 800 HP (1,520 at the tier-1 cap), 15 damage a second. Sim:
the boss alone needs 19.0 s from its first hit to fell the diner (minimum 15).

**D-243 The tier-up dawn is the game's biggest moment (author).** Banner, a camera move, staged pops, then the card
pick; all visual on top of the saved state; no replay on resume (D-253).

**D-244 Sim criteria for tiers.** A full build for a tier always holds that tier's cap with 0 retries, on three
seeds; the planner never tiers up; the tier bot's unspent gold on day 14 is below the planner's.

**D-245 Known gap: tier 2 is the top of slice 1 (author).** The sign hides at tier 2 and gold piles up again. Measured
(seed 20260930): both yard towers are at level 3 on the first tier-2 day, both stations are maxed by day 14, and unspent
gold at close-up then grows 223 → 3,999 from day 14 to day 20. Accepted; tier 3 removes it.

**D-246 Procedural hare and Boar King.** No monster models exist in the CC0 packs in use; both come from the Boar's
mesh builder and shader (D-192), the boar mesh pinned byte-identical. Reversible; REVIEW_QUEUE.

**D-247 Sim suite split and budget enforcement (approved by the author 2026-10-07; amends D-132).** The first form of
this decision ("not needed for slice 1") was wrong within a day: after the E5 merge the `sim` job on `main` failed
three attempts on wall time alone (69, 71, 61 s; 18 of 18 sims passing) while the same tree ran in 27 to 52 s on the
PR runs. Every sim file was about 1.7 times slower on the slow runs: runner speed, not a test.
- **Split.** The four tier sims live in `tests/sim_tier/` and run in a third parallel CI job, `sim-tiers`
  (`./run_tests.sh sim-tiers`). `unit`, `sim`, `sim-tiers` and Pages `deploy` are the required checks. `--quick` is
  unchanged (unit + night-1 sims). Later tiers add their sims to `tests/sim_tier/`.
- **Wall time, per sim job.** Over 60 s is a warning annotation, not a failure. Over 150 s is a hard failure (a
  runaway sim). Reason (the author's): wall time on shared runners varies about 2x for the same tree, so a hard 60 s
  limit is flaky, and splitting again each time the suite grows does not scale.
- **Tick budget (deterministic).** A GUT pre-run hook (`tests/sim/tick_budget_hook.gd`) records the physics ticks each
  sim test simulates. The job fails if a test exceeds its expected count by more than 20%, if a sim has no expected
  count, or if a sim in the golden file did not run. Expected counts are committed in `tests/sim_ticks.golden.json`
  and updated deliberately with `TICK_BUDGET_UPDATE=1 ./run_tests.sh sim` (or `sim-tiers`); the diff of that file is
  the review surface for "this sim got longer".
- **Unchanged:** never drop, skip or weaken a test (D-132). CI stays canonical for sim thresholds (D-105).
- **Guards:** an empty suite directory fails; a golden key without a sim, or a sim without a golden key, fails in
  `unit` as well; `TICK_BUDGET_UPDATE` is refused in CI and never writes after a failing run; a watchdog kills a suite
  still running 30 s past the hard limit (GUT never exits when its pre-run hook does not compile).
- **Evidence:** Linux CI (PR #54) gives the same 18 tick counts as the macOS recording. One sim
  (`test_night1_fail_restarts_night`) reads 2280 or 2281 between local runs: GUT's paint pause between tests depends on
  wall time and shifts the phase the next test starts in by one frame. Counts are stable to within 1 tick, not
  byte-identical; a 1-tick golden diff is not a regression.
- Cost if wrong: a slow-but-not-runaway regression in engine or script cost per tick no longer fails CI; it shows as
  the warning annotation and in the perf readings. Reversible (one script, one workflow, one golden file).

## 2026-10-06: E5 build (subagent-driven; rulings by the main session)

**D-248 Pressure and balance shape.** `TierBalance` arrays have `tier_costs.size() + 1` entries (index 0 unused; the top
tier is `tier_costs.size()`). `EnemyBalance` and `WaveBalance.target_priority` stay as the Boar's numbers;
`MonsterBalance.stats(&"boar")` is a view of them; hare and boss are exported `MonsterStats`. A monster's stats are
cached on the `Boar` at spawn (the per-call view allocated 3 to 7 objects per boar per tick), so a live balance edit
applies to monsters spawned after it. `core/` now reads the `Balance` autoload in `LanePlanner` and `WaveSchedule`
(boss HP for the lane threat, `boss_lead`).

**D-249 The determinism gate from Task 3 on is `tools/baseline_rows.sh 7`.** The tier-1 cap arrives with
`WaveMath.pressure`, so `tools/baseline_diff.sh` differed in rows 8 to 14 until the re-record (D-237). The sweep's
`enemy_count` column now sums the night's own plan (it printed uncapped counts past day 7).

**D-250 Paying the tier in full marks tonight's wave plan with the boss.** The day's plan is made at dawn, before the
payment; the plan only marked the boss at the next dawn, so no boss night would ever have happened. On load a pending
boss always rides tonight's plan (a hand-edited save cannot skip it). Telegraph flags refresh when the tier is paid.

**D-251 Save schema 5.** Built-in step 4 → 5; validation of the tier fields and of the new wave keys (types before
use); a tier above what the build knows is clamped on load, but a spot above the build's top tier is still rejected
("building tier <id>"; an id the build does not know at all is "building <id>"): a tier-2 save on a tier-1-only build
does not load (pinned by a test).

**D-252 The hare was redesigned after its first shots failed the silhouette rule (R1).** Lighter `enemy_snout` body,
lean and long, two flat `enemy_red` ears laid back for the top-down camera; scale 0.6 (0.72 m tall). The Boar King
passed R1 to R8 first time. Leg swing rate and pivot are shared by all kinds (known limit).

**D-253 The tier-up dawn.** The card offer is drawn once and stashed without a signal before `complete_tier_up`, so
the dawn save written on `tier_reached` resumes at the card pick at tier 2 (a tab closed during the reveal loses
nothing and skips nothing). A top-tier no-op opens the pick at once. The offer is stashed unconditionally (a stale
offer from a loaded save cannot be shown).

**D-254 The tier-2 diner has no awnings.** The spec put an awning on each flank; under the 55° camera any awning at
y ≥ 2.2 near the walls hides monsters in the attack zones, the north tower bases or the hero, outside every occluder
box. Tier 2 = the tier-1 diner plus two thin `diner_cream` terraces (top at y 0.015, under lane strips, steaks and
blob shadows), one baked mesh swapped per tier, 0 extra draws. The occluder fade re-applies after a swap. Honest
limit: from the home spot the diner reads only slightly grown (REVIEW_QUEUE).

**D-255 Yards.** Dirt patches in the one merged ground mesh, a stone ring (one MultiMesh), no collision. Props within
1 m of an OPEN yard are hidden (five props at tier 2). The world follows the tier on `tier_changed`, `tier_reached`
and `state_restored`; tier-1 terrain and props are pinned byte-identical.

**D-256 The reveal.** The camera is asked through `EventBus.camera_reveal_requested` (no system reaches into another's
nodes): it moves to the centre of the diner and the newly opened yards and zooms to fit them at 9:16 (2.15 at tier 2;
cap `tier_reveal_zoom` 2.25), holds, and returns to the hero. Five steps (dust at the first yard, the stones appear,
the diner pops, dust at the next yard, the yard spot markers pop) land at 0.60 to 2.00 s, inside the hold; the reveal
ends with the card pick at 3.0 s. The ground mesh is never scaled. The warm-up pre-builds the tier-2 terrain and props
and warms the hare, the boss and the boss bar. Known limit: at 9:21 and 21:9 the pulled-back view shows up to 20 m
past the ground mesh edge (grass-coloured background) for those 3 seconds.

**D-257 Bots and sims.** `TierBot` buys defense exactly as the planner first, then the tier-up when the full cost is
in hand, then yard towers (also on a lane with no threat tonight), then stations. The boss-night sim resumes its
fixture as DAY and retries through the day, as real play does. Fixtures are deterministic (`make_save.gd
--fixture=tier`, two runs byte-identical).

**D-258 E5 results (seed 20260930 unless noted; starting values, no tuning round).**
- Sims: boss night won after 1 retry through the day (2 allowed), diner 0.193, mercy 0.85 on the winning attempt;
  boss alone: 19.0 s hold; first tier-2 night cleared with 0 retries, diner 0.397, 9 hares; full tier-2 build at the
  cap cleared on seeds 20260930 / 1 / 2 with diner 0.037 / 0.59 / 0.933.
- Sweep (`docs/review/media/e5/sweep/`): planner clears 14 days with 0 retries on seeds 20260930, 1, 2 (unspent day
  14: 2,276 / 1,620 / 2,736). Tier bot: boss night on day 12 / 13 / 12 with 1 / 1 / 0 retries; its first failed night
  is the boss night (none on seed 2); tier-2 nights 1 to 3 need 0 retries; unspent day 14: 223 / 77 / 563; 5 / 4 / 5
  cap nights with 0 retries, lowest diner 0.123 / 0.380 / 0.277. Every spec 8.2 target is met.
- Linux CI (PR #53) prints the same four sim lines digit for digit, so the thin cap margin on seed 20260930 (diner
  0.037) is a balance fact, not platform noise. Sim suite 47 s of 60 on CI, 42 s locally.

**D-259 Phases were stacked, not merged one by one (deviates from D-137 for E5).** From Task 3 the tier-1 game stops
growing at day 7, while the tier sign arrives in phase 3; every merge to `main` deploys to Pages. PRs #50, #51, #52
and the phase-4 PR are stacked and merge together after the author's checkpoint.

**D-260 Perf and device measurements wait for the end (the author, 2026-10-07).** No iOS Simulator perf runs between
phases: one measurement after every task, milestone and phase is done. A run started on 2026-10-07 was stopped by the
author before it completed; no number from it is recorded. The real-device check of the tier sign, the boss bar and
the boss moon is on the FINAL REVIEW phone checklist and blocks no merge. What is owed is listed in
`docs/E5_FOLLOWUPS.md`.

## 2026-10-07: E5 slice 2 (tier 3) brainstorm

**D-261 The fourth lane is a south-west lane to the front (south) wall (author).** Chosen over a second northern lane
sharing a wall and a straight south lane. Reasons (the author's): the diner is attacked from all four sides, the
clearest "bigger tier" beat; the south wall is the most readable one (the camera looks north from the south, so
south-wall fights are in front of the diner and need no fade); the service-side conflicts are night-only (travelers
are gone, the gold pile is emptied at close-up). Constraints, each pinned by a test like S1's:
1. **Visibility (D-076):** with the hero at the SW attack zone, an incoming monster is on screen for at least 2.0 s
   before it enters hero range. West-to-east travel along the road crosses the narrow portrait axis, so the last
   segment may curve to come up from the bottom-left of the screen if the test needs it. A per-lane screenshot.
2. **Coverage (test A' extended to 4 lanes):** no reachable position reaches 3 or more lanes; the 2-lane positions are
   reported as information. The SW corner covering west + SW is expected.
3. **Day traffic:** travelers never visibly walk through a fence. Either traveler exits are rerouted east, or the SW
   fence spot is placed off the traveler path; the simpler one is chosen and logged.
4. **Service layout:** whatever must move moves (the tier sign, HOME, queue slots) so that no station, sign or HOME
   lies inside the SW attack zone or on its fence spot. Station arming (D-121) still applies.
5. **Tower coverage:** the tier-3 tower spot(s) reach the SW attack zone and its fence (tests B/C).
6. **Tier-1 identity:** days 1 to 7 stay byte-identical; the SW lane exists only after the tier-3 unlock and
   `lane_plan` picks it only from then on.

**D-262 Tier 3 is one slice; its first phase is "growth readability" (author).** Tiers 4 and 5 stay roadmap. The
tier-2 visual complaints are fixed in this slice, first, because the SW lane touches the same ground (west yard edge,
sign). Targets: the diner visibly grows per tier; yards read as owned land, not lane stubs (ground tint, low border
or decor); the tier sign is readable at phone size (checked on a 40% screenshot). Before/after screenshots under
`docs/review/media/`, and REVIEW_QUEUE entries.

**D-263 Branching at level 3 is chosen on two branch pads beside the building; the choice lasts the building's
lifetime (author).** Chosen over a two-card pick at dawn and over fixed branches per spot. Rules:
1. **Commitment only on full payment.** A partial payment belongs to the pad it was paid on. When one branch
   completes, any partial payment on the other pad is refunded to gold, with the coins flying back to the hero.
   Arming (D-121) and the stand-still threshold apply. Test: a hero walking across both pads commits nothing.
2. **"Permanent" means the building's lifetime.** A fence destroyed at night resets to level 0 at dawn as today
   (`GameState.reset_destroyed_fences`), so its branch is lost and is chosen again when it is rebuilt to level 3. The
   spec and the pad's label say so.
3. **Informed choice (pillar 3).** While the hero stands on a branch pad, before the payment completes, a preview
   shows: a 2 to 3 word label plus the effect (e.g. the new range ring, a target-count hint). Icons are
   distinguishable at phone size (checked on a 40% screenshot).
4. **Geometry.** Both pads of every spot clear all lanes, attack zones, fence spots, other pads, stations, signs and
   HOME; they join the geometry and waypoint tests, the SW lane included.
5. **Sims.** PlannerBot gets a deterministic branch policy. `sim-tiers` runs three full tier-3 builds (all branch A,
   all branch B, mixed); each holds the tier-3 cap with no retries. If one policy beats another by more than 15 points
   of diner HP, a REVIEW_QUEUE entry ("possible dominant branch") is added instead of a blind retune.
6. **Out of scope:** respec or refunds after commitment. "Paid respec as a gold sink" goes to Post-tier-3 ideas.

**D-264 Branches are threat-answer pairs (author).** Slow/control branches go to Post-tier-3 ideas. Economy branches
(a weaker branch that pays gold) are rejected: income stays "kills only", and the gold pile-up is handled by tier-3
costs. Every number is in `balance/`; sims tune them.
- **Longbow (tower A):** longer range, heavier single shots, slower rate. Geometry rule: no tower spot with Longbow
  range reaches the attack zones of 3 or more lanes (tower coverage tests, SW lane included).
- **Volley (tower B):** each attack fires up to 3 projectiles at the first 3 targets in range, in the tower's existing
  target-selection order (stable spawn-index tie-break, deterministic). Per-projectile damage is reduced so
  single-target DPS is below Longbow's. No splash, no chaining.
- **Stone wall (fence A):** much more HP, plus reduced damage taken from the fence-breaker specifically (a damage
  multiplier by attacker kind).
- **Spike fence (fence B):** normal HP. Damages monsters attacking it, and deals a fixed amount once to each hare that
  passes its spot (a per-hare flag, deterministic, no repeat hits). Test: hares still walk past; only the pass damage
  is new.
- **Informed choice:** the day telegraph shows tonight's threat composition per lane (regular / hare / fence-breaker
  icons or counts), not only total HP. Branch pad previews: range ring, "x3", shield, spike, plus the 2 to 3 word label.
- **Visuals:** each branch is a distinct model variant readable at phone size (Longbow taller and slimmer, Volley
  multi-barreled; stone versus spiked fence), through the art pipeline and ART_BIBLE, checked at 40% scale.
- **Economy:** branch costs are set so tier 3 absorbs the tier-2 pile-up. Sweep target: `unspent_gold_at_closeup`
  stays under a threshold defined from the tier-2 data through the tier-3 cap. REVIEW_QUEUE entry with the costs.
- **Sims:** the three full-build policies of D-263 plus a threat-matched policy (the bot picks the branch matching
  its lane's dominant threat). Threat-matched should do best; if not, REVIEW_QUEUE gets "branches don't reward
  reading the telegraph".

**D-265 The tier-3 monster is a siege brute (author).** The roadmap's "reach beyond fences" wording is replaced by
"wrecks fences": the brute keeps the Boar's attack reach, so the attack-zone stop points and test A' stay valid. The
thrower (ranged, stops outside the fence) goes to Post-tier-3 ideas as a possible tier-4/5 enemy; it needs ranged
monster attacks and its own coverage rules. The charger is rejected: burst damage makes Stone wall the only answer.
1. **Behavior:** the Boar's target order (lane fence, guard in reach, diner). A fence damage multiplier in `balance/`
   (several times normal); normal damage against guards and the diner. Stone wall applies its brute-specific
   reduction (D-264).
2. **Numbers, all in `balance/`:** HP, speed (clearly slower than the Boar), count per wave as a curve over day and
   tier with a cap. Only from the tier-3 unlock. Never a swarm: a small cap per wave, and at most 1 per lane per wave
   unless the sims prove more is needed.
3. **Telegraph and readability:** shown per lane in the day telegraph (D-264); at night a distinct big silhouette, a
   heavy slow walk and a ground-thump hit on the fence; the edge arrow marks a brute lane distinctly; readable at
   phone size (40% screenshot).
4. **Reward:** more steaks than a Boar, in `balance/`; included in the economy math and the tier-3 sink sizing.
5. **Sims and tests:** targeting order and the fence multiplier; the Stone wall reduction applies only to brute hits;
   a brute lane with no fence behaves as a tanky Boar; determinism with brutes; `sim-tiers` branch policies face
   brute lanes and the threat-matched policy (Stone wall or Longbow on brute lanes) should do best; pools sized from
   the new caps.
6. **Art (amended by the author the same day):** the procedural builder in the Boar family is the preferred path, not
   a fallback: consistency with the Boar, the hare and the Boar King (D-192, D-246) beats CC0 sourcing. Big,
   cute-dangerous; walk, attack, hit and death (or tween fakes). A REVIEW_QUEUE entry only if the result does not read
   as "big, cute-dangerous" at phone size.

**D-266 Tier 3 adds a front lot with one tower and one fence (author).** A second tower on the south-east is rejected
(crowded; risks the 3-lane rule at Longbow range). A movable guard post is rejected: "moving guard heroes" is on
IDEA.md's Later list.
1. The SW plot holds the SW lane's fence spot and one tower spot. The tower reaches the SW attack zone and the SW
   fence at base range (D-261 constraint 5). With every branch, Longbow included, it reaches at most 2 lanes' attack
   zones (SW + west expected). Coverage tests.
2. Branch pads for both new spots follow D-263's geometry rules: clear of the SW lane, attack zones, fence spots,
   stations, signs, HOME, queue slots and traveler paths. A dedicated geometry test plus a 720x1280 screenshot of the
   SW corner with every pad visible.
3. Before purchase the tier-3 sign stands on the plot, outside the SW attack zone and its fence spot. After purchase
   the plot reads as owned land, by phase 1's growth-readability rules.
4. Economy: the plot price, the two new spots and all tier-3 branch purchases form the tier-3 sink, sized against the
   tier-2 pile-up data (D-264). The full tier-3 purchase ladder with costs is listed in the spec and in REVIEW_QUEUE.
5. Buying the plot IS the tier-3 tier-up: pay on the tier sign standing on the plot, that night is the boss night, and
   everything new arrives the next dawn. The plot price is the tier-3 cost. The tier bot pays it as it paid tier 2,
   then follows its branch policy; the sweep covers it. The branch policies belong to the tier bot: PlannerBot stays
   at tier 1 and byte-identical for days 1 to 7.

**D-267 The tier-3 boss is a giant hare; rule: each boss examines the tier you are finishing (author).** The Boar King
again is rejected as a repeat. Several bosses at once go to Post-tier-3 ideas (the bar, the moon and the hold check
assume one boss).
1. **Behavior:** the hare's rules at boss scale. It walks past fences (Spike fence pass damage applies once, D-264).
   HP, speed and diner damage in `balance/`. Fast for a boss, but catchable: a test proves a hero starting at that
   lane's attack zone reaches melee range of it before it reaches the zone.
2. **Fairness (pillar 3):** the boss lane is fixed by the seeded lane plan and shown in the day telegraph before
   close-up with a distinct boss icon. Mercy applies as for any night.
3. **A meaningful test of tier 2, as `sim-tiers` runs:** the tier bot with the full tier-2 build holds the boss night
   with no retries; the tier bot WITHOUT the yard towers fails it or needs mercy retries; determinism for the night.
4. **Readability:** built with the hare builder, clearly bigger, with a boss marker consistent with the Boar King's
   (crown or equivalent); its own bar name, light and comedic; readable at phone size (40% scale).
5. **Reward:** the boss steak drop in `balance/`, included in the tier-3 economy math.

**D-268 The diner grows upward inside its footprint, and the land grows on the ground (author).** Low annexes on the
walls are rejected: every wall is now a lane wall or the service side, the trap the awnings fell into (D-253).
1. **Silhouette per tier, nothing overhanging:** tier 2 = roof color, chimney, rooftop sign board; tier 3 = a set-back
   second storey with lanterns. Before/after screenshots at 40% phone scale in `docs/review/media/`.
2. **Land:** a paved tint plus a low border for the yards and the SW plot. Small props (crates, barrels, a bench) are
   allowed on owned land only, outside every lane, attack zone, fence spot, pad, station, sign, HOME, queue slot and
   traveler path; they join the geometry tests and never collide with the hero.
3. **Occlusion:** the occluder fade (D-151) covers the whole building at every tier (roof, chimney, sign board,
   second storey); its trigger includes guards as well as the hero and monsters. Camera tests at tier 3: the hero, a
   monster and a guard at the north zone are visible (the fade triggers and no opaque face covers them); the tower
   bases at the NW and NE spots are never covered by the taller diner at any focus inside the clamp.
4. **Perf:** the new meshes stay inside the perf budget, measured on the profile build at the end (D-260).

**D-269 The tier-2 cap margin is decided with data before the tier-3 boss is tuned (author).** Slice 1 measured the
diner at 4% on one seed at the tier-2 cap (D-258). Order: (1) run the tier-2 cap night with the full tier-2 build on
at least 10 seeds; (2) if the median diner margin is under 15%, the cap is too tight: lower `tier_cap[2]` from 11 to
10, which also gives the boss room; (3) otherwise keep 11 and lighten the boss. Either way the boss must still fail
the no-yard-towers run (D-267). Within the three-round tuning rule (D-103); the result goes to REVIEW_QUEUE.

**D-270 Tier-3 design section 1 approved with additions (author).** Phases merge one by one; the tier-3 cost entry is
the switch and arrives in the last task of phase 4.
1. **Switch test:** with the tier-3 cost absent, no sign offers tier 3 and a full sweep shows no tier-3 content (no
   brutes, no SW lane, no branch pads). Debug hotkeys may force tier 3 in the debug build only; a release-export
   check proves the forcing code is absent.
2. **Save schema 6:** a migration test from a real committed v5 fixture save (not a hand-built dictionary) that loads
   with no branches and identical gameplay state; a v6 round trip with branches and partial pad payments; the
   fail/quit snapshot (S3) includes branch state and pad payments.
3. **RNG identity:** tier-3 lane draws use the `lane_plan` stream only and shift no other stream (spawns, travelers,
   drops). The byte-identity test covers tier 1 and 2 plans, sweep rows 1 to 7, and a tier-2 fixture night that is
   identical before and after the slice.
4. **Margin study ordering (amends D-269):** the cap decision (steps 1 and 2) is in phase 2; "lighten the boss"
   (step 3) is in phase 3, once the boss exists; the no-yard-towers fail check (D-267) is in phase 5.
5. **Checkpoint pack** in `docs/review/E5_T3.md` plus media: a 60 to 90 s iOS Simulator video (tier-2 boss night,
   dawn reveal, a tier-3 night with a brute lane and a branch purchase); before/after growth screenshots; the SW
   corner shot with all pads; `sim-tiers` results with the policy comparison and the margin study; the profile-build
   perf reading at a tier-3 night; this slice's REVIEW_QUEUE entries, top first.
   Main-session reading against D-260: the perf reading is taken once, at the end of phase 5, when every task and
   phase of this slice is done; never between phases.
6. **Pools:** the brute and boss pools are sized from the new caps (the S1 rule); the runtime-growth warning applies.

**D-271 Tier-3 map approved from probe results (author).** A headless probe using the game's own camera, path and
geometry code produced the numbers; the plan pins them by tests.
- **Lane:** `[(-24, 11), (-3.5, 11.0), (-2.75, 5.2)]`, 26.35 m; zone `Rect2(-4.0, 4.0, 2.5, 1.2)`; fence spot
  (-3.26, 9.17). Visibility before hero range: 2.45 s at aspect 0.30, 3.25 s at 9:21 and 9:16, 8.9 s or more wider. A
  flat road approach gives 1.60 s on a phone and 0.55 s at 0.30; only bends at x = -4.5 or further east pass every
  aspect, so the last 6 m come up from the bottom of the screen. (The author's approval text says "x <= -4.5"; the
  measured rule and the chosen bend are x >= -4.5.)
- **Coverage:** no reachable position hits 3 lanes; 2-lane positions west+sw 142, west+north 16, north+east 16.
- **Tower `tower_sw` at (-6.6, 5.6):** SW zone farthest corner 5.35 m, SW fence 4.88 m, lane (with offsets) 2.77 m,
  guard return path 1.89 m.
- **Tier-dependent layout:** tiers 1 and 2 are unchanged (byte-identity). At tier 3 the queue mirrors to the east
  side and travelers exit east (the constraint-3 choice: today's west exit clears the fence by 1.94 m but passes 0.5 m
  from the new tower; east reuses the entry line and clears the fence by 3.80 m). HOME and the close-up sign stay.
  The tier-3 sign, shown at tier 2, stands at (-5.6, 9.0) on the plot. The switch happens only at the tier-3 dawn,
  when no travelers exist; a mid-day save/load test at tier 3 restores the tier-3 layout.
- **Branch pads:** radius 0.9 m; every one of the nine spots has valid pairs (fewest at the SW fence, 23 positions;
  worst chosen clearance 0.46 m). The SW corner screenshot must show the SW-fence pads as separate targets at phone
  size.
- **Longbow range (updates D-264):** at any range a tower may reach the monster stop points OR the fence spot of at
  most 2 lanes. The probe's maximum is 10.28 m (bound by `tower_nw` reaching a SW stop point), so Longbow starts at
  9.98 m (maximum minus 0.3 m, capped near 10). A test iterates all tower spots x all lanes. If a later layout change
  pushes the result well under 10 m it is reported; the rule does not change.
- **Gold pile:** stays (0.29 m from the lane line, empty at night). A test proves the pile is empty from close-up
  until dawn at every tier.
- **Diner door:** stays the guard respawn point although it is inside the SW zone. Respawn protection:
  `respawn_protect_s` (start 1.5 s) during which a respawned guard is untargetable and walks toward its post. Tests
  and sims: with monsters in the SW zone a respawning guard is not knocked out again within 5 s; across `sim-tiers`
  runs no actor is knocked out more than twice in any 15 s window. REVIEW_QUEUE: "Respawned guards pull SW-zone aggro
  off the diner: intended?" with the measured effect on diner HP. Main-session note: the hero has no HP and is never
  knocked out, so the protection applies to guards.

**D-272 Tier-3 night rules approved with notes (author).** Starting numbers, all in `balance/`, tuned by sims inside
D-103: pressure 12 to 15 at tier 3; a four-lane draw at tier 3 (tiers 1 and 2 unchanged); brute HP 240, speed 1.2,
damage 8, fence damage x4, 8 steaks, one on the first tier-3 night's last wave, ramping over three days to at most
1 main + 1 side per wave; giant hare boss HP 500, speed 2.4, damage 12, leading the last wave by 3 s; Longbow range
9.98, 45 per shot, 1.0 s; Volley range 8.0, 3 x 10, 0.5 s; Stone wall 640 HP and brute damage halved; Spike fence
320 HP, 6 back per hit taken and 10 once per passing hare; per-kind counts in the telegraph and a brute mark on the
edge arrow; 1.5 s respawn protection for guards on every lane; unbranched buildings stay valid; pads appear at every
level-3 building on the tier-3 dawn.
1. **Spike damage scales with the night's HP multiplier** (pass damage and thorns), so Spike does not fade at the
   cap. The start values are the ones at the tier-3 base: 10 and 6.
2. **Boss reward:** checked against the Boar King's reward with the same reward-to-HP logic and included in the
   tier-3 sink sizing. The steak pool is sized for the boss drop plus a full cap wave. If 100 steak objects popping at
   once cost frames on the profile build, the drop is bundled visually (fewer pieces, each worth k steaks); freezer
   and economy counts must not change; tested.
3. **Branch identity test on Balance** (so tuning cannot silently break it): Longbow has the highest single-target
   DPS and the longest range; Volley the highest DPS against 3 or more targets; against hares Volley kills the most
   per second and Longbow the fewest; Stone wall holds longest against a brute; Spike is the only fence that damages
   passing hares; unbranched level 3 stays between the branches.
   Main-session notes for the spec: (a) at tier 3 a hare has about 40 HP at the base and 46 at the cap (HP multiplier
   2.65 to 3.1), so "one shot overkills" does not hold for Volley's 10 or the level-3 tower's 18; the hare test is
   computed in whole shots against the real hare HP at the tier-3 base and cap, and the starting damages are adjusted
   until the ordering holds at both. (b) "Between the branches" is checked per measure: with the starting numbers the
   unbranched tower is between on single-target DPS (20 < 36 < 45) but lowest against three targets (36 < 45 < 60);
   the spec states which measures the rule covers.

**D-273 Tier-3 world and interface approved with changes (author).** As proposed: phase 1 growth readability (roof
color, chimney, sign board; paved yards with a low border; a larger tier sign); the tier-3 dawn reuses the reveal
system with a new step list and switches the queue and the traveler exit while no traveler exists; two branch pads
with icon, cost, label and a preview; four branch models; a fourth edge arrow; per-kind telegraph counts; the
cost-entry switch and the debug-only tier forcing.
0. **On D-272:** "unbranched is never the best at any named measure" is the rule (it need not sit in the middle); the
   spec names the measures. The hare test is computed in whole shots against real hare HP at pressure 12 and 15, and
   the starting damages are adjusted until the ordering holds at both ends.
1. **Boss name: "Baron von Hop".** "Big Thumper" is rejected: Thumper is a well-known studio rabbit character. Check
   (web search, 2026-10-07): no well-known game or film character and no trademark found under "Baron von Hop"; the
   only near match is "Baron Von Hops", a character on a hobby worldbuilding page (World Anvil). "Duke Longears" was
   dropped for its closeness to Uncle Wiggily Longears. The other new display names in this slice (Longbow, Volley,
   Stone wall, Spike fence, Siege brute) are generic terms. Any further display name gets the same check.
2. **Reveal:** a tap anywhere fast-forwards it; the joystick stays disabled until the reveal ends or is skipped.
   Tests: both paths, plus a resume mid-reveal.
3. **Pad payments persist** through close-up, night and save/load, like build-spot partial payments today. The
   D-263 refund applies only when the other pad completes. Covered by the schema-6 round-trip test.
4. **Label legibility:** the fence pads' second line is a small broken-fence icon plus "lost if broken" (3 words at
   most), verified at 40% screenshot scale together with the per-kind telegraph counts.
5. **Sounds and hint:** the brute and the boss reuse existing monster sounds plus one CC0 thump from a pack already
   in the repo (logged in `docs/ASSET_LICENSES.md`); a one-time onboarding pointer at one branch pad.

**D-274 Tier-3 economy, proof and CI time approved (author).**
1. **Boss name** "Baron von Hop" accepted (a hobby worldbuilding page is not a meaningful conflict).
2. **Boss reward rule, general for future tiers:** a boss drops one cap night of the tier being finished. The Baron
   drops 150 steaks (450 gold, the tier-2 cap night). The D-272 bundling rule applies if the profile build shows a
   frame cost; economy counts stay exact.
3. **Ladder costs (starting values):** the plot 1,500 (= the tier-3 cost); the new tower 280 and fence 140 to level
   3; a tower branch 500 (x5), a fence branch 300 (x4); 5,620 in all. Sweep target: from the tier-3 dawn until the
   ladder completes, unspent gold at close-up stays at or under one cap night (650). The sweep also reports
   `fence_rebuild_gold` per night (levels plus branch repurchases after destruction; REVIEW_QUEUE "brutes make fences
   a tax" if its median at the tier-3 cap exceeds 30% of nightly income), the plot purchase day and the day the
   ladder completes. It uses the same card policy as the previous tier sweeps so pacing is comparable. Post-ladder
   pile-up at tier 3 is the accepted known gap (REVIEW_QUEUE: "tier 3 has no sink after the ladder; tier 4 must
   provide one").
4. **CI time:** studies are not regression tests. The 10-seed margin study and the multi-seed policy ranking run as
   report scripts, like the sweep; their results go into the spec results and the checkpoint pack. CI keeps
   single-seed (or at most 3-seed) assertions: each policy holds the cap; threat-matched >= the others on the CI
   seed; plus the boss-night, no-yard-towers, Baron-catch, first-night, respawn and identity sims. If `sim-tiers`
   still nears 150 s it is split into parallel jobs (`sim-tiers-a` / `sim-tiers-b`) before any test is touched, and
   the main session updates the required checks (authorized). Timings go to the author only if splitting does not fit.
5. **Next steps without further approval:** write and self-review the spec, write the plan (task graph, waves, D-136
   parallel rules, hot files wired by the main session), execute phases 1 to 4 with self-merges, stop at the end of
   phase 5 with the checkpoint pack `docs/review/E5_T3.md`. Stop earlier only for the standing stop conditions.

**D-275 Rulings while writing the tier-3 spec (main session).**
- **Longbow starts at 80 per shot every 1.8 s, not 45 per 1.0 s (changes a D-272 starting number).** With real hare HP
  (about 40 at pressure 12, 46 at 15) the D-272.3 ordering "Longbow kills the fewest hares per second" fails at
  pressure 12 with 45 per 1.0 s (it one-shots a hare, 1.0 per second, above the unbranched tower's 0.67). 80 per 1.8 s
  gives 0.56 hares per second at both ends and single-target 44.4 per second (unbranched 36, Volley 20). Cost if
  wrong: one balance value; the identity test pins the ordering either way.
- **Brutes are added to a wave; they replace no Boar.** Their HP is in the lane threat and their steaks in the
  economy. Cost if wrong: tier-3 nights are harder than the pressure alone says; the sims measure it.
- **Debug forcing (reading of D-270.1).** `GameState.debug_set_tier` stays (tests, sims and tools use it) and clamps
  to the top tier, so it cannot pass the switch. Forcing tier 3 before the switch exists only in the debug overlay
  under `ui/debug/`, which the `deploy` job already proves absent from release and profile packs; a source-grep unit
  test proves no other caller. Cost if wrong: the author wanted the function itself gone from release; that would
  need the tier tests to stop using it.
- **Spec path:** `docs/superpowers/specs/2026-10-07-e5-tier3-design.md`. Phase branches `e5/p6-growth`,
  `e5/p7-t3-data`, `e5/p8-t3-night`, `e5/p9-t3-world`, `e5/p10-t3-proof`.

## 2026-10-07: E5 slice 2 (tier 3) build

**D-276 Author decisions and main-session rulings during phases 1 and 2.**
- **Lighter build process (author, "B"):** implementers run their touched tests plus the unit suite; the main session
  runs `sim`, `sim-tiers` and both baseline scripts once per wave on the merged phase branch; reviews block only on
  Critical and Important findings, minors are fixed in one cleanup per phase; at most one fix round per task unless an
  Important finding stays open. Phases still merge one by one; perf once at the end (D-260).
- **Tier-2 cap 11 -> 10 (author; supersedes the "keep 11" outcome of D-269).** Margin study, tier-2 cap night, full
  tier-2 build, ten seeds: at cap 11 the night is held on 8 of 10 seeds (seeds 4 and 9 are real falls), median diner
  HP left 0.393, lowest quarter 0.014; at cap 10 it is held on 10 of 10, median 0.688, minimum 0.177. D-269's median
  rule said "keep 11", but the carried rule "a full build always holds its tier's cap with no retry" failed on 2 of
  10 seeds; the author chose 10. Players at tier 2 meet a lighter cap night after the update (REVIEW_QUEUE).
  Report script: `tests/sim/report_margin.gd` (`--tier-cap=<n>` measures another cap in memory).
- **Longbow starts at 120 per shot every 3.0 s (replaces D-275's 80 per 1.8 s).** At pressure 15 the last waves' hares
  have 54.25 and 72.85 HP (the wave-size factor), so the unbranched tower drops to 0.5 and 0.4 hares per second;
  120 per 3.0 s gives 0.333 at every wave and 40 per second on one target (unbranched 36, Volley 20).
- **Branch identity measures:** measures 1 and 3 (single-target DPS, DPS against three targets) are raw damage over
  interval by definition; a whole-shot check against a lone brute is added (Longbow is never slower than the
  unbranched tower; 3 of 12 waves tie). Against Boars the Longbow's overkill makes it slower in whole shots: by
  design. "Unbranched is never the best" includes a shared top.
- **`boss_kind` has an entry per tier including the top, whose entry is empty:** `[&"", &"boss", &"baron", &""]`.
- **Tier-2 diner silhouette (changes the plan's Task 1 and spec section 5).** Anything tall on the roof hides the
  Archer on his perch or a tower pad from some camera positions with no fade. Rule for tier 2: added roof parts hide
  nothing outside the footprint that tier 1 does not already hide, and never the Archer; pinned by camera sweep tests.
  Result: the tier-2 diner is NOT taller than tier 1 (top 4.6 m against tier 1's 5.1 m sign plank); it reads through
  a wood roof, a second chimney and a cream board. The reviewer also found that tier 1 already hides the pad centres
  of `tower_nw` and `tower_ne` from some north-lane positions, so the spec's "tower bases are never covered by the
  taller diner" is restated: the taller diner adds no occlusion of static things (the Archer, tower pads, fence
  spots, world labels) compared with tier 1; ground it newly hides must lie inside a fade box so an actor there
  triggers the fade (the rule for the tier-3 second storey, Task 19).
- **Art roles:** no `gold` or `steak_brown` on the building; the chimney band is `wood_dark`.
- **A pre-existing fade defect fixed in Task 1:** a fade that ended a hair under full alpha left the diner on its
  transparent material duplicates (`components/occluder_fade.gd`); exact compare plus a regression test.
- **Yards:** the kerb is closed at the west yard's south-east corner (the tier sign and an open west yard never
  coexist); pad gaps stay. The kerb is pre-drawn in the boot warm-up.
- **Tier sign:** `tier_sign_min_px` is 36 base pixels (the plan's 28 was already met by the old label in portrait);
  label font 56, label height 4.27 m.
- **Traveler exit (corrects D-271's reason):** with `tower_sw` at (-6.6, 5.6) today's west exit passes 1.74 m from
  the tower, not 0.5 m. The east exit at tier 3 stays as approved (it reuses the entry line and clears the fence by
  3.80 m).
- **Implementers sign commits with their own model's trailer** (the model that wrote the commit).

**D-277 Rulings during phase 2 (data and rules) and the start of phase 3.**
- **Map storage (changes spec 3.1):** the tier-3 map entries are `*_T3` constants behind accessors in
  `core/map_layout.gd`; the shared dictionaries keep only tier-1/2 entries, because art code iterates them by key and
  would have drawn the south-west strip at tier 1. A source-scan test bans direct reads outside `core/map_layout.gd`.
- **`tower_sw` covers the south-west lane only** (`["sw"]`): the west fence (9.15 m) and the west zone's far corner
  (7.56 m) are beyond level-1 range, so listing west would mislead the bots.
- **Branch pads:** yard props and kerbs count as obstacles; 14 of 18 pads moved; the worst clearance is 0.15 m.
- **Plan shape:** waves carry `brute_main` / `brute_side` only from tier 3, so tier-1/2 plans and saves keep their
  exact shape. `GameState.from_dict` copies the keys only at tier 3 or above.
- **Brute ramp:** the last d + 1 waves carry a main-lane brute on day d of tier 3; all side brutes arrive on the
  `brute_ramp_days` night (the same night pressure reaches the cap at the starting values).
- **Save schema 6:** only the two building fields are added. A pad payment at or above cost clamps on load (D-234);
  `validate` requires the new fields. Partial pad payments on a fence destroyed at night are refunded to gold at dawn
  (D-263 only said the branch is lost; no gold may disappear).
- **Stone wall:** buying it fully repairs the fence (its HP becomes the new maximum).
- **Wave 3b split:** the Spike fence's monster side (thorns on the attacker, pass damage to hares) moves from Task 12
  to Task 11, which changes hare-kind behaviour anyway; Task 12 does the towers and two state queries.
- **Boot warm-up:** it now builds the two placeholder monster meshes and the yard kerb; from the switch on it
  pre-builds the ground of every tier from 2 to the top. Cost unmeasured until the final perf run.
- **Hare ramp at tier 2 after the cap change:** `fast_ramp_days[2]` stays 3 while pressure now reaches the cap after 2
  days, so the first cap night has a slightly lower hare share. Left as is (REVIEW_QUEUE).

**D-278 Rulings during phase 3 (the night).**
- **Brute look:** mesh scale 1.5 (1.63x the Boar's height, 1.73x its width, 0.81x the Boar King's height) with a
  redder back; the first version read as the Boar King at 90%. Its fence hit raises two dust bursts beside the body
  and a thump that reuses the diner-hit sound at pitch 0.7. Fence damage x4; every other kind is bit-identical.
- **Boss kind per tier** through one helper pair (`TierEffects.boss_kind_for`, `is_boss_kind`). Baron von Hop is the
  tier-2 boss: 500 HP, 24.0 s from its first hit to fell the diner alone (minimum 15), caught by the hero with at
  least 5.7 s to spare on every lane. The Boar King's bar now shows its name (a visible tier-1 change). The night
  banner says "Baron von Hop comes" at tier 2. A pending boss at the top tier means no boss.
- **Spike fence:** thorns after each hit a monster lands on it; pass damage once per hare-kind life at the fence
  line. Both scale with the night's FIRST-wave HP multiplier relative to the tier-3 base (D-272.1 said "the night's
  multiplier"): against the last wave Spike is at 77% (pressure 12) and 64% (pressure 15) of its wave-1 strength,
  and mercy is ignored.
- **Towers:** Volley fires at the first three targets of the existing selection order; the single-target path is
  textually unchanged. A Longbow shot whose target dies in flight is lost with its cooldown.
- **Pools from balance:** projectiles 24 -> 35 (42 with tier 3), steaks 293 (440 with tier 3: boss drop per tier and
  brute steaks), enemies 41. The baselines did not move.
- **Respawn protection (D-271):** on respawns only, not hires; a protected guard still attacks (at most 2 swings per
  respawn). Measured with three Boars in the SW zone, diner HP after 10 s: no guard 150, protected guard 150,
  unprotected guard 150 to 165 across timing offsets. An earlier reading of "no difference" was a timing artifact.
- **Telegraph rows:** the ruled "3 m up-path of the marker" was infeasible (it lands on tower and fence labels or
  off screen). Rows sit in the free band at z = -15 for west, north and east and south of the road for sw. From HOME
  the three northern rows are at the top of the screen under the HUD strip: accepted for now (REVIEW_QUEUE). No gold
  on enemy glyphs. The brute arrow mark is its own 64 px texture beside the arrow's tail and shows for this wave or
  a later one.
- **Task 15 (boss tuning step) dropped:** it existed only for a tier-2 cap of 11.
- **Process:** `git stash` is forbidden to implementers (it is shared by all worktrees and swapped two tasks' files
  once). A fix round left the Boar King's back colour at the brute's value; the merged unit run caught it and the
  hare, Boar King, brute and Baron meshes are now hash-pinned like the Boar's.

**D-279 Rulings during phase 4 (world and interface).**

- **Tier-3 map in the world:** the tier-3 sign stands at (-4.7, 8.5) (the spec's (-5.6, 9.0) collided once phase 1's
  larger board was merged). The front lot is paved. The traveler spawner owns the queue and exit switch at the tier
  change. At tier 3 the roof plank is removed and DINER is written on the storey wall.
- **Tier-3 camera rule:** portrait must satisfy the strict "hides nothing tier 1 does not hide" rule. Landscape is
  exempt beyond 10 m from the diner. The Archer may stand behind a roof part only if the diner fades there.
- **Branch pads show information in stages** (D-273 said icon, cost and label at all times; with nine level-3
  buildings that piled 18 labels on each other, the HUD and the hero). Far: ring and a depth-tested icon. Near, for
  ONE focus building within 3.5 m (kept until 4.5 m): also the cost. On the pad: name, effect line, warning and the
  preview, and the sibling pad shows only its ring and payment ring. Payment never reads the stage.
- **Known pad overlaps are pinned exactly** in a passing test (pad, label, obstacle, pixels per aspect), never behind
  a pending or skipped test. The hull margin for pads north of a tower is 6.5 px (8 asked, 6.8 reachable). The stood
  stack may reach 3.2 screen-metres from its pad. The near-stage size floors hold up to 3.5 m; the 3.5 to 4.5 m band
  is exempt. To meet the 28 px cost floor at 3.45 m the cost text size went from 0.0123 to 0.0132 (worst reachable view 28.46 px, at `fence_e`), and the near
  block's width cap from 1.2 to 1.25 m (the floor outranks the width heuristic). Pinned today: 12 on-pad findings
  (station labels count as obstacles) and the near-stage ones, measured only from ground the hero can reach, from
  HOME's side and from due south. The kerb hash in tests is taken on positions quantized to 0.1 mm: raw float
  bytes differ between macOS and the Linux runner. The near-stage test scans each spot's worst
  reachable point; after three rounds on that test the residual overlaps are pinned and parked (REVIEW_QUEUE 20).
- **Onboarding flag** for the pad pointer lives in `SettingsStore` (`branch_hint_done`), not in its own file.
- **Reveal:** five steps at tier 3 (0.60, 0.95, 1.30, 1.65, 2.00 s; ends at 3.0 s). Branch pads are day-only, so
  they are not a step. A tap skips ANY reveal (tier 2 too) after a 0.6 s guard, so the player re-gripping the stick
  at dawn cannot skip it before step 1. The settings gear stays tappable; the pause freezes the reveal. The skip's
  camera return reuses `camera_reveal_requested` with a documented sentinel.
- **Count rows hide under the HUD bar** (a visible tier-1 change): from HOME at 9:16 the three northern rows are
  hidden and appear as the hero walks toward a lane.
- **The switch (Task 21):** `tier_costs = [0, 500, 1500]`. The tier-2 sign reads "Buy the lot" ("Buy the front lot"
  was 292 px wide against 270 free). The tier bot's tier-2 behaviour is frozen until Task 22 teaches it tier 3; with
  that, every sim's tick count and both baselines are unchanged by the switch. The sweep assertion planned for Task
  21 moves to Task 22. Pools grow to the tier-3 worst case (steaks 440, projectiles 42). A build from before the
  switch that shares the origin zeroes a partial tier-3 payment and rejects a tier-3 save.
- **Warm-up grid:** 5 columns, centred rows, checked against the portrait projection (an 8-column grid passed the
  headless test but left the boar, knife, arrow and steak draws outside a phone's frustum).

**D-280 Tier-3 balance from real play (phase 5).**

- **Finding:** with the approved values (tier-3 pressure 12 to 15, brutes on both lanes) the tier bot, playing three
  real 32-day runs (seeds 20260930, 1, 2), needed one or two retries on 20 of 31 cap nights; held nights ended as
  low as 1% diner HP; a fence fell on every cap night. The Baron night held with 0 retries on all three seeds.
- **Tuning** (in-memory sweep overrides; raw output in `docs/review/media/e5t3/balance/`). Round 1: cap 14 / 13 /
  12, brutes on the main lane only, brute fence damage halved, combinations: pressure is the main lever, fewer
  brutes second, fence damage least; none reached 0 retries. Round 2 at cap 12: main-lane brutes 0 retry nights of
  40; fence damage 2.0 or brute HP 180: 1 of 40.
- **Ruling:** `tier_cap[3]` 15 -> 12 and `brute_cap_side[3]` 1 -> 0. Tier 3 no longer ramps in pressure (base 12 =
  cap 12); its escalation is the brute ramp (3 days) and the fourth lane. After the change: 0 retry nights of 40;
  median held diner 79% to 94% per seed; two early nights on seed 1 held at 4% and 1% while the build was being
  completed; from the 5th tier-3 night on the lowest is 42%. The steak pool is 396 (was 440).
- **Fixtures come from real play.** A fixture constructed from the tier-2 save's day-13 gear, stamped as a later
  day, made the Baron night look lost. Fixtures 1, 2 and 5 are captured from the tier bot's own run.
- **Sims:** sim 5 starts at the DAY before the first tier-3 night (the real flow has a day; started at NIGHT with
  the south-west spots empty the night is lost in 33 s). Sim 6 asserts in CI that each of the four policies holds
  the cap night; the "threat is at least as good as every other policy" ordering moves to the multi-seed policy
  report, because one night cannot rank policies (the same night held in a play-through and was lost from a
  fixture). Sim 8 proves identity at planner level; the full rows stay with `tools/baseline_rows.sh 7`.
- **Bot:** it buys tier 3 only after every other purchase (tier 2 on day 13 or 14, tier 3 on day 18 to 22). The
  policy "mixed" (undefined in the spec) is towers Longbow, fences Spike fence.
- **Reports (Task 24):** policy ranking and the ladder line are report scripts, not CI. A fifth, report-only policy
  `volley_stone` completes the tower x fence table. Results: Volley + Stone 87.2 points, Volley + Spike 76.7,
  threat-matched 75.4, Longbow + Stone 67.2, Longbow + Spike 55.8; `DOMINANT_BRANCH_2x2: yes` (gap 31.4, threshold
  15); `THREAT_BEST: tie`. Ladder: the front lot is paid in sweep row 16 to 20, everything is bought 5 to 8 tier-3
  days later, `UNSPENT_TARGET: PASS`, `FENCE_TAX: yes` (31% to 35% of income). Per spec 9.2 these go to the review
  queue; the branch values are NOT retuned in this slice (tier 3 holds with 0 retries; which branch should win is
  the author's design call).
- **Deviation from D-274.4 (recorded for the author):** the approved CI assertion "threat-matched diner HP is at
  least every other policy's on the CI seed" was NOT built. On the CI cap night threat is third (0.737 against
  Volley + Spike 0.770 and Longbow + Stone 0.763), although that fixture gives threat the ideal branches for that
  night's plan, which real play cannot have (branches are permanent). The ordering lives in the multi-seed report
  (`THREAT_BEST: tie`).
- **"Holds with 0 retries" depends on the policy:** 0 of 40 tier-3 nights for threat, Volley + Spike and Volley +
  Stone; 1 of 40 for Longbow + Stone; 6 of 40 for Longbow + Spike. The carried rule "each policy holds the cap with
  no retries" (D-263.5) therefore fails for the Longbow pairs in real play; sim 6 proves it on one night only.
- **Both weak branches were tuned for pressure 15:** Longbow's 120 per 3.0 s and Spike's growth with the night's HP
  multiplier. At pressure 12 neither reason applies. Retuning them is the follow-up the checkpoint pack recommends.
- **Evidence:** per-night raw data of the applied setting is in `docs/review/media/e5t3/balance/applied/`; the
  policy runs in `policies/`. `policies.txt` first cited an amended work-in-progress commit with identical code.

**D-281 Author's checkpoint answers for E5 tier 3 (2026-10-08). PR #60 merged.**

1. **Tier-3 difficulty** (cap 12, brutes on the main lane only, no ramp) stays as the INTERIM setting. Revisit after
   the branch retune: restore a modest ramp (12 to 13 or 14) if the retuned branches allow it with zero retry
   nights for the threat-matched policy.
2. **Branch retune** is a follow-up slice: retune Longbow and Spike fence for the pressures the game reaches.
   Targets on the multi-seed report: every policy holds the tier-3 cap with zero retry nights; the spread between
   the best and worst fixed policy is at most 15 points of diner HP; the branch identity test (D-272) still holds.
3. **Fence tax** must be at most 30% (median, at the cap) after the retune, through fence HP, Stone wall values or
   branch costs. Fences stay a recurring sink (it partly answers the gold pile-up after the ladder). Reported in
   the follow-up.
4. **Pad-label overlaps** are accepted for the merge; fixing all 12 is in the follow-up's scope (the art and
   readability bar). Each fix is verified at about 40% screenshot scale. The pinned test changes from "overlap
   pinned" to "no overlap".
5. **The telegraph does not pay off.** Root cause (author): branches are permanent but lane threats change every
   night, so one night's telegraph cannot inform a permanent choice. Design fix to brainstorm, tier 3 only (the
   tier-1/2 identity is kept): each lane gets a persistent threat bias per run, seeded from `run_seed` (for
   example the SW road lane favours brutes and one northern lane favours hares), applied through the lane-plan
   weights, and shown as a lasting lane-character marker beside tonight's counts. Target: threat-matched beats the
   best fixed policy by at least 5 points on the multi-seed report. A simpler fix may be proposed in the brainstorm.
6. **The dropped CI assertion** (D-274.4) is accepted: one night cannot rank policies. **New rule:** if an approved
   assertion turns out to be unbuildable or wrong during implementation, escalate at that moment with the
   evidence. Never record it only at the checkpoint.

Also in the follow-up:
- **Worst frame 110 ms:** it always lands 0.1 to 0.2 s into the measured window. First decide whether it is a
  measurement artifact (window start, warm-up) or real (for example first-use shader compiles on the Compatibility
  renderer). If real, fix it with warm-up. Measure the boot warm-up cost too.
- **Early tier-3 nights** (held at 1% and 4% on one seed): the retune checks include first tier-3 nights from real
  bot play, not fixtures. Target: no first tier-3 night below 25% diner HP across the report's seeds.
- **Fixtures:** replace the three constructed fixtures (sims 4, 5, 7) with fixtures recorded from real play where
  feasible.
- **Process:** the follow-up is its own slice with the full flow (brainstorm with the author, spec, plan, build,
  checkpoint).

**D-282 Lane character (follow-up slice, brainstorm question 1; author, 2026-10-08).** Brutes are pinned, hares lean.

1. **Siege lane:** exactly ONE at tier 3, drawn per run from all four lanes ("one or two" stays a lever for later
   tiers, not this slice). Brutes spawn ONLY on the siege lane, whichever lane is tonight's main or side. This
   replaces the interim "brutes on the main lane only" rule (D-281.1). Brute counts per wave stay as tuned; only
   their lane is fixed. When the brute curve gives a wave brutes and the siege lane is neither its main nor its
   side lane, the siege lane carries them as an extra group. Tested.
2. **Hare lane:** one OTHER lane takes about 70% of the hares (a Balance value); the rest spread by the existing
   draw.
3. **Randomness:** a new named stream `lane_character`, derived from `run_seed` only. No other stream shifts; the
   tier-1/2 identity and sweep rows 1 to 7 stay byte-identical.
4. **Existing saves:** a live tier-3 save without a lane character gets one derived from its `run_seed` on load
   (deterministic, the same on every load). Schema bump, with a migration test from a real v6 fixture.
5. **Readability:** a lasting lane-character marker (siege and hare icons) at each lane entrance from the tier-3
   dawn on, beside tonight's counts; revealed as one step of the tier-3 dawn reveal with a short flavour line (for
   example "Heavy tracks on the west road..."); checked at about 40% screenshot scale.
6. **Targets for the retune report** (they replace the "fixed policy" framing of D-281.2 where they differ):
   threat-matched beats the best fixed policy by at least 5 points of diner HP on the multi-seed report; every
   policy, fixed or matched, still holds the cap with zero retry nights, so a wrong choice costs margin, not the
   run (the non-punishing pillar). If both cannot hold, escalate with the data; neither is relaxed silently.

**D-283 Branch retune direction (follow-up slice, brainstorm question 2; author, 2026-10-08).** Sharpen the
specialists.

1. **Kind-specific strengths, all in Balance:** Longbow gets a bonus damage multiplier against brutes (and against
   the boss only if the tier-2 to tier-3 boss flow needs it: decided from data and logged). Stone wall keeps its
   brute damage reduction. Spike fence gets higher pass damage on hares, still scaled with the night's HP
   multiplier (D-272). Volley keeps its general multi-target role unless the data demands otherwise.
2. **"Paying never makes it worse" floor** (replaces the vaguer off-lane floor). For each lane type (siege lane,
   hare lane, neutral lane), measured by a fixed micro-sim of that lane's realistic wave mix: every branch is at
   least as good as the unbranched level 3 on every lane type; a specialist clearly beats the other branch on its
   own lane type. Built as a unit / micro-sim test so tuning cannot break it silently. The D-272 identity test moves
   to these lane-type measures and keeps "unbranched is never the best at any named measure".
3. **Readability:** pad previews and labels show the specialty in at most 3 words with the lane-character icon (for
   example a siege icon plus "bonus vs brutes"), so the marker-to-choice mapping is visible at the moment of
   purchase. Checked at about 40% scale.
4. **Side effect to verify:** a Longbow on the siege lane kills brutes sooner, so fewer fences fall. The fence tax
   (target at most 30%, D-281.3) is reported with and without that effect.
5. **Report targets** stay as D-281 / D-282: threat-matched at least best fixed + 5 points; every policy holds the
   cap with zero retry nights; no first tier-3 night below 25%. Then try restoring the pressure ramp (D-281.1) on
   the tuned values.

**D-284 Branch card in the HUD (follow-up slice, brainstorm question 3; author, 2026-10-08).**

1. **Content:** branch icon, name, the specialty line with its lane-character icon (D-283), cost and payment
   progress, and for fences the "lost if broken" icon line. Every string through `tr()`.
2. **Behaviour:** the card appears when the hero enters an armed branch pad and hides on exit or on completion. It
   never intercepts input (mouse filter ignore): a joystick touch may start anywhere, including over the card.
   Test: a drag that starts on the card moves the hero.
3. **Layout:** bottom of the screen, inside the safe area (home indicator), never covering the hero at any focus
   inside the camera clamp: a projection test with the hero on each of the 9 spots' pads. Readable at about 40%
   scale.
4. **World side:** only the pad ring, the icon, the near-stage cost and the preview shape (range ring, "x3" and so
   on) stay in the world.
5. **Overlaps:** the near-stage overlaps are fixed by moving pads. The overlap test asserts ZERO overlaps for both
   the near stage and the on-pad stage, replacing the pinned counts, and includes the "Close up" label, level pips,
   station labels and the count rows.
6. **Scope:** branch pads only in this slice. REVIEW_QUEUE idea: use the same card for all build and upgrade pads,
   with the overlap count it would remove.

**D-285 How the retune report judges its targets (follow-up slice, brainstorm question 4; author, 2026-10-08).**

- **Seeds:** eight final-report seeds, two per siege lane, plus four tuning seeds, one per siege lane. The two sets
  are DISJOINT (12 unique seeds). Tuning never looks at the final eight until the final report (hold-out against
  overfitting).
- **Selection (against cherry-picking):** deterministic. Scan upward from a fixed start value and take the first
  seeds whose lane character gives each siege lane, the tuning set first, then the final set. The report prints the
  rule and the seeds.
- **Pass rules of the final report:**
  - threat-matched: mean lead over the best fixed policy at least 5 points AND ahead on at least 6 of 8 seeds;
  - per siege lane: the mean lead is not negative on any lane; if it is, escalate with the data even if the overall
    target passes (reading must pay on every lane);
  - on the same 8 seeds: zero retry nights for every policy (unbranched included, as the floor); no first tier-3
    night below 25%; fence tax at most 30% median at the cap; fixed-policy spread at most 15 points.
- **Output:** each target per seed and per siege lane, plus the verdict.
- **Running:** policies in parallel where the machine allows (three at a time). Reports are scripts, not CI
  (D-274.4).

**D-286 How the follow-up slice reaches main (brainstorm question 5; author, 2026-10-08).** Phase by phase, behind
one Balance switch.

1. **One flag,** for example `Balance.tier3_retune_enabled`, false until the flip. Lane character, the specialist
   values, the HUD card, the new markers and labels and the reveal step all read it. No other flags.
2. **Off-state identity:** with the flag off, tier 3 behaves exactly as on today's main. A tier-3 fixture night is
   recorded from current main BEFORE the first phase merges, and asserted byte-identical with the flag off after
   every phase, alongside the tier-1/2 identity checks.
3. **Debug only:** the debug build can toggle the flag at runtime for simulator checks; the release-export check
   proves the toggle code is absent.
4. **Saves across the flip:** a save made with the flag off loads correctly with it on (lane character derived from
   `run_seed`, D-282); a night-start snapshot replays under the new rules, which is acceptable and documented (the
   replay may differ). Both tested.
5. **The flip is the checkpoint:** the final 8-seed report passes (D-285), the pack is ready, the author approves;
   then the flag is flipped in a small PR.
6. **Cleanup in the same slice,** right after the flip PR: a cleanup PR removes the flag, the off-state code paths
   and the superseded values, keeping the tier-1/2 identity checks. Not "later".

The independent parts (the worst-frame diagnosis with any warm-up fix; the real-play fixtures) merge on their own,
early, with the usual gates.

**D-287 Design section 1 approved: lane character and the night plan (author, 2026-10-08).**

Accepted as presented: `LaneCharacter.for_run` / `apply` as pure core helpers; the stream
`Rng.stream(run_seed, 0, "lane_character")` (siege lane from four, hare lane from the other three); the plan format
with `extra` groups; truthful composition, threat and telegraph; the pool sized for the worst case; schema 7 with the
v6 migration; the documented replay change; the character distribution test (200 seeds, each lane siege at least 30
times). Refinements:

1. **Extra hare group:** the moved hares are taken from the main and side hare counts PROPORTIONALLY (deterministic
   largest-remainder rounding, never negative), not from the main group only. Per-wave totals of enemies, hares and
   brutes stay exactly as today.
2. **At most three active lanes per wave** at tier 3, never four; deterministic post-processing, no new draws:
   a. if the wave has brutes and the siege lane is neither main nor side, the SIDE lane becomes the siege lane (the
      side group moves there);
   b. then, if the hare lane is neither main nor side, its share comes as an extra group;
   c. hard cap of 3 active lanes: if it would be exceeded, that wave's hare share stays split between main and side,
      and the report counts how often that happens;
   d. extra groups use the side-group delay.
   Tests: at most 3 active lanes on every wave over the 200-seed scan; every brute on the siege lane; wave totals
   unchanged; the night-level hare-lane share reported per seed (target about 0.7; flagged below 0.6).
3. **Arrows and telegraph:** a third active lane gets its own small arrow; the edge-arrow and HUD tests cover three
   simultaneous arrows without overlap at 720 x 1280 and at the narrowest supported aspect.
4. **Saves:** if the stored character differs from the one derived from `run_seed`, the derived one is used and a
   warning is logged (debug overlay). Tested.

**D-288 Design section 2 approved: the specialists (author, 2026-10-08).**

Accepted as presented: Longbow gains `kind_mult {brute: x}` (start 2.0, range 1.5 to 3.0; no Baron bonus unless data
demands it); Stone wall unchanged; Spike fence pass damage up (start 16, range 12 to 24), its HP-multiplier scaling
kept; Volley unchanged unless data demands; the threat-matched table (siege-lane fence Stone, other fences Spike;
towers covering the siege lane Longbow, also when they cover the hare lane too; other towers Volley; the bot reads
the lane character, not tonight's plan); the tuning procedure (bench, 4 tuning seeds, at most 3 rounds, fence-tax
levers in the order Longbow's saving / re-buy cost / fence HP, the ramp attempt at 13 then 14, the 8 hold-out seeds
once; escalate if the 15-point spread and the 5-point lead conflict). Refinements:

0. Rule 2c of D-287 is unreachable given 2a; it stays as an asserted guard with a reported count.
1. **Bench measures per lane type:** siege lane: diner HP lost, then fence HP left. Hare lane: diner HP lost, then
   hares reaching the diner's attack zone (fewer is better), then time to clear. Neutral lane: diner HP lost, then
   time to clear. The floor uses the same order: a branch is "no worse than unbranched" only if it is no worse on
   the primary measure AND, when tied there, no worse on that lane type's first tie-breaker.
2. **The 15% specialist margin** applies on the first measure that separates the two branches, in that order.
3. **The bench runs at pressure 12 AND at the final cap** (13 or 14 too if the ramp returns). With the flag off it
   pins today's values.

**D-289 Design section 3 approved: readability (author, 2026-10-08).**

Accepted as presented: the lasting lane-character marker at each entrance (siege icon, hare icon, nothing on neutral
lanes; day and night from the tier-3 dawn; not hidden by the HUD bar); the branch card's rows (icon and name;
specialty in at most 3 words with its character icon: Longbow "breaks brutes", Stone wall "holds brutes", Volley
"hits 3 targets", Spike fence "hurts hares"; the guarded lane(s) with their character icon; cost with the payment
bar; for fences "lost if broken"), 640 x 170 px, 24 px above the bottom safe inset, input ignored; the reveal step
(markers pop, a 2 s flavour banner, six steps ending at 2.35 s, tap-to-skip applies all); the one-time banner at the
first dawn for saves already at tier 3 when the flag flips; the third arrow and the brute mark only on the siege
lane's arrow; the near-stage pad moves; zero overlaps in both stages; the 40% checks; the REVIEW_QUEUE card idea.
Additions:

1. **Flag scope (D-286):** the pad moves for `tower_e`, `tower_ne`, `tower_nw` and `fence_sw` and the removal of the
   world-side labels also sit behind the flag. With the flag off, pad positions and world labels stay exactly as on
   today's main, so the tier-3 off-state identity (fixture night, tier-bot day walking) holds. The zero-overlap
   target applies with the flag on; with it off the test keeps today's pinned counts until the flip.
2. **Icons** differ by SHAPE, not only colour (colour-blind safety); checked in grayscale at 40% scale.
3. **Text length:** every card row and banner goes through `tr()` and must survive longer translations: a
   pseudo-locale test (strings about 40% longer, plus a Vietnamese sample with diacritics): rows shrink or wrap
   inside the 640 x 170 card without overflow or overlap; the font renders the Vietnamese sample (D-079).
4. **Flavour banners** are at most 6 words (readable in 2 s at phone size) and go to REVIEW_QUEUE for the author's
   tone check.

**D-290 Design section 4 approved: proof (author, 2026-10-08).**

Accepted as presented: the report `tests/sim/report_retune.gd` (seed scan upward from 1: the first seed per siege
lane is the tuning set of four, the next two per siege lane the final set of eight, all printed; six policies per
seed: the four fixed pairs, threat-matched, unbranched; verdict lines `THREAT_LEAD`, `THREAT_LEAD_BY_LANE`,
`RETRY_NIGHTS`, `FIRST_T3_NIGHT`, `FENCE_TAX` (with and without Longbow on the siege lane), `FIXED_SPREAD`,
`HARE_SHARE`, `LANE_CAP_GUARD`, each per seed and per siege lane; the final set only with `--final`, recording its
commit); the off-state baseline recorded from today's main and `tools/baseline_t3_off.sh`; the existing tier-3 sims
running flag-off in CI with their exact pins; three flag-on CI sims on fixtures recorded from real play (sim 4 keeps
a constructed night with real gear); the split into `sim-tiers-a` / `sim-tiers-b` with the required checks updated
(D-274.4); the unit additions with the bench at about 10 s at most; the worst-frame diagnosis (window shifted by 1 s
and 3 s; first-use draws into the warm-up if real; the boot warm-up's cost) as an early independent PR; the standing
escalation rule (D-281.6). Additions:

1. **Hold-out integrity:** if the `--final` run fails any target, escalate to the author with the data; no further
   tuning against those 8 seeds. If more tuning follows, the next final run uses a NEW hold-out set: the next 2
   seeds per siege lane from the same scan. The report prints which hold-out set it is (#1, #2, ...) and the
   commit; earlier sets' results stay in the report history.
2. **Off-state baseline visibility:** the output of `tools/baseline_t3_off.sh` ("tier-3 off identical", with the
   commit) is pasted into EVERY phase PR body of this slice beside the existing baseline outputs. A phase PR without
   it is not self-mergeable under D-137. The baseline is recorded from today's main before phase 1.

**D-291 Design section 5 approved: delivery (author, 2026-10-08).** The author does not read the spec before the plan
and the build; stop at the phase-4 checkpoint (`docs/review/E6_RETUNE.md`) or earlier only for an escalation or a
standing stop condition.

Accepted as presented: the single flag `Balance.data.tiers.retune_enabled` with new values beside the old ones and
one accessor; `?retune=1` in the debug overlay; a test that no production file can set the flag; the slice is E6 with
branches `e6/p<N>-<slug>`; phases 0 setup, A worst frame, 1 lane character, 2 specialists, 3 interface, 4 proof
(checkpoint), 5 flip, 6 cleanup; every phase PR body carries the three baseline outputs; tuning edits to `balance/`
by the main session, one commit per round with its report output; the checkpoint pack's contents; the lighter build
process of the last slice; the escalation rule. Additions:

1. **Cleanup (phase 6):** remove `tools/baseline_t3_off.sh` and its pinned off-state files together with the flag;
   re-record the tier-3 baseline as the new truth under a new tool name, with its output in the cleanup PR; keep
   every flag-on test (they become the normal tests); update REVIEW_QUEUE, DECISIONS (mark D-286's flag as retired)
   and the spec's results section.
2. **Flip PR (phase 5):** includes the Pages deploy check and one post-deploy smoke run on the live main build
   (simulator plus emulated Pixel), confirming that the tier-3 dawn shows the lane-character step on a migrated v6
   save.
3. **Phase A goes first** and merges on its own as soon as it is green; it does not wait for the other phases.

