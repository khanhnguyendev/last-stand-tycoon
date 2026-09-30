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
