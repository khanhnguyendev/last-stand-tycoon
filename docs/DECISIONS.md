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
