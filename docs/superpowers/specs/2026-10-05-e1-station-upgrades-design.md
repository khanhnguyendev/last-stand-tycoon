# E1 Station Upgrades: Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`). This builds on the S1 to S5 specs. Their conventions,
  architecture and rules still apply.
- **Precondition:** `main` at the final review package (D-221): GameState schema 3, the save envelope with its
  migration hook, the S4 determinism baseline, the S5 guide and audio.
- **Status:** brainstormed with the author on 2026-10-05. The author chose every option below and approved the design
  and this spec. Amended after the spec review (D-230); the amendments are marked in section 9.
- **Decision log:** `docs/DECISIONS.md` D-222 to D-230.

---

## 1. Goal and success criteria

The author wants to expand the game: upgrade the counter and the freezer, hire sales staff, build more equipment and
expand the map. These are four subsystems, so they are four expansions, each with its own spec, plan and build:

| | Expansion | Depends on |
|---|---|---|
| **E1** | Station upgrades (this spec) | nothing |
| E2 | Staff: a seller at the counter, a hauler from the freezer | E1 |
| E3 | New equipment: new buildable stations | E1 |
| E4 | Map expansion: buy land, new lanes and spots | E1 |

Only E1 is built before the v0.1 friend playtest. The playtest then decides the order of E2 to E4.

**The problem E1 solves:** gold has only 5 sinks (2 towers and 3 fences, 3 levels each). The planner bot ends sweep
rows 1 to 3 with 8 to 38 gold left, and rows 8 onward with 186 to 484: later on nothing is left to buy, and the day
stays the same length forever.

**Words used below.** "DAY phase N" is the N-th DAY phase of a run; it follows night N and is sweep row N. The first
DAY phase runs with `GameState.day == 2`.

E1 is done when:
1. The counter and the freezer can each be upgraded from level 0 to level 5 with gold, by standing still on an upgrade
   pad near the station. No menu and no button.
2. A counter upgrade makes the day busier and faster: more travelers, a longer queue, faster service, a bigger pile.
3. A freezer upgrade makes hauling lighter: the hero carries more and loads faster, so fewer trips.
4. At level 0 both stations behave exactly as they do today: `tools/baseline_diff.sh` prints `baseline identical`,
   and the default sweep's CSV and stdout are byte-identical to today's.
5. A schema 3 save loads, with both stations at level 0.
6. Sims on seed `20260930`:
   1. With a stocked counter, the travelers served in a fixed window strictly increase with every counter level, by at
      least `min_level_gain` (section 4).
   2. DAY phase 1 played by `PlannerBot` with the counter preset to level 3 takes fewer physics frames than the same
      day at level 0.
   3. `UpgraderBot` (section 5.6) holds nights 1 to 3.
7. Unit, sim and CI are green, the sim suite stays under 60 s, and every task passes a reviewer.

## 2. Scope

**In:**
- Station state in GameState, its payment method and two EventBus signals.
- `StationBalance` and the pure `StationEffects` helper.
- An `UpgradePad` near the counter and near the freezer.
- The counter, the freezer, the traveler spawner, the carry stack, the sign pulse, the autosave, the build sound and
  sparkle, and the planner bot read or react to the upgraded values.
- Save schema 4 with a built-in migration from 3.
- Sims, a second sweep mode, and a level 5 perf fixture.
- IDEA.md: stations become a gold sink.

**Out:**
- Staff, new equipment, map expansion (E2 to E4).
- A higher price per steak, a freezer capacity limit, spoilage.
- New station models per level. A level shows as the existing model, a pop and star pips; the model is not scaled
  (`build_level_scale` is 1.0 for towers too). This goes into `docs/REVIEW_QUEUE.md` as a reversible art decision.
- Any change to the tutorial. The guide never points at a pad, and its rules ignore stations (section 5.4).

## 3. Player flow

- Each station has one upgrade pad on the ground: the build-spot ring marker, a cost label and up to 5 star pips.
- The pads are active in every DAY phase, from the first one. At night the label and the ring are hidden.
- Standing still on a pad drains gold into it, at the build spots' rate (`Economy.drain_per_tick`). The ring shows
  paid / cost. When the level completes, the station's visual pops, the build sound and sparkle play, a dust puff
  plays and one more pip lights.
- A partial payment stays on the pad and is saved.
- At level 5 the label reads `tr("MAX")` and the pad takes no gold.
- An upgrade takes effect immediately: the next traveler interval, the next service, the next load tick.

## 4. Effects

Level 0 is today's value in every row. Every number is a default in `balance/station_balance.gd`
(`balance/balance.tres` holds no values). The values below are the starting point for tuning.

**Counter**

| Level | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Queue size | 4 | 5 | 6 | 7 | 8 | 9 |
| Traveler interval (s) | 2.5 | 2.1 | 1.8 | 1.5 | 1.25 | 1.0 |
| Service time (s) | 1.0 | 0.9 | 0.8 | 0.7 | 0.6 | 0.5 |
| Pile capacity | 12 | 18 | 24 | 30 | 36 | 42 |
| Cost to reach | n/a | 30 | 60 | 120 | 240 | 480 |

How the flow is limited: the queue size counts travelers that are still walking in (about 9.8 s from the map edge),
and a full queue skips a whole arrival interval. So the queue size, the interval and the service time all matter, and
a level that raises only one of them can be nearly dead. Hand estimates for the first draft gave about
3.1 / 2.5 / 1.8 / 1.6 / 1.41 / 1.375 seconds per traveler, with level 5 only 2.5% better than level 4. Therefore:
- `min_level_gain` (default 0.08) is in `StationBalance`. Criterion 6.1 fails if any level serves less than
  `1 + min_level_gain` times the travelers of the level below. Tuning cannot ship a dead level.
- Level 5's queue is 9 in this draft for that reason. The tables are tuned in the plan's tuning task until 6.1
  passes, under D-103 (3 rounds, then escalate).

**Freezer**

| Level | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Extra carry | 0 | 2 | 4 | 6 | 8 | 10 |
| Steaks per load tick | 1 | 1 | 2 | 2 | 3 | 3 |
| Cost to reach | n/a | 25 | 50 | 100 | 200 | 400 |

- Extra carry applies everywhere, including picking up steaks at night. There is one carry number:
  `GameState.carry_capacity()` = the card value + the freezer bonus.
- The freezer upgrade does not shorten the day by much: selling takes about 2.3 s per steak and hauling about 0.5 s.
  It removes trips (comfort) and lets the hero pick up more at night. This is known and accepted (D-224, D-230).
- Cost of level `n + 1` = `round(base_cost * cost_mult ^ n)`, with `cost_mult` 2.0, base 30 (counter) and 25 (freezer).
- Steaks per night do not change, so gold per day does not change. The upgrades shorten the day. Night balance moves
  only because gold is now split between defense and stations, which is the intended choice.
- Traveler jitter (0.5 s) and traveler want (1 to 2) are unchanged.

## 5. Architecture

Station state is separate from `GameState.buildings`. `buildings` means "tower or fence" in the lane code, the dawn
heal, the save validation and `Economy.level_cost`; stations have no HP and a different max level.

### 5.1 Balance

`balance/station_balance.gd`, `class_name StationBalance`, exported on `BalanceData` as `stations`:

```gdscript
@export var max_level := 5
@export var cost_mult := 2.0
@export var counter_cost := 30
@export var freezer_cost := 25
@export var min_level_gain := 0.08
@export var queue_max: Array[int] = [4, 5, 6, 7, 8, 9]
@export var traveler_interval: Array[float] = [2.5, 2.1, 1.8, 1.5, 1.25, 1.0]
@export var service_time: Array[float] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
@export var counter_capacity: Array[int] = [12, 18, 24, 30, 36, 42]
@export var carry_bonus: Array[int] = [0, 2, 4, 6, 8, 10]
@export var load_per_tick: Array[int] = [1, 1, 2, 2, 3, 3]
```

- A unit test checks that each array has `max_level + 1` entries and that
  `queue_max.max() <= MapLayout.QUEUE_SLOTS.size()` (the spawner indexes the slots).
- `queue_max`, `traveler_interval`, `service_time` and `counter_capacity` are removed from `EconomyBalance`: one source
  for each number. The unit tests that read them keep the same assertions and read the level-0 value through
  `StationEffects`: `test_travelers.gd`, `test_reactions.gd`, `test_piles.gd`, `test_stations.gd`,
  `test_game_state.gd`, `test_guide.gd`, `test_restore_world.gd`.

### 5.2 Core

`core/station_effects.gd`, `class_name StationEffects`, static and pure, no scene access:

```gdscript
const IDS: Array[StringName] = [&"counter", &"freezer"]
static func level_cost(id: StringName, level: int, sb: StationBalance) -> int   # -1 at max level
static func queue_max(level: int, sb: StationBalance) -> int
static func traveler_interval(level: int, sb: StationBalance) -> float
static func service_time(level: int, sb: StationBalance) -> float
static func counter_capacity(level: int, sb: StationBalance) -> int
static func carry_bonus(level: int, sb: StationBalance) -> int
static func load_per_tick(level: int, sb: StationBalance) -> int
static func max_carry(hb: HeroBalance, cb: CardBalance, sb: StationBalance) -> int   # largest possible carry
static func traveler_pool_size(sb: StationBalance) -> int
```

`MapLayout` gains `STATION_PADS` (keys `&"counter"`, `&"freezer"`, pad radius `BUILD_RADIUS`) and a longer
`QUEUE_SLOTS`. The coordinates are fixed by tests, not by this spec; the first 4 queue slots do not change.

Pad tests (`tests/unit/test_geometry.gd`, `test_props_layout.gd`):
- Each pad's circle overlaps none of: the station zones, the build spots, the queue slots, the lane zones, the sign,
  the diner, the gold pile's magnet radius, `HOME`, `NIGHT1_START`, and the counter and freezer bodies grown by
  `HERO_RADIUS`.
- Each pad is more than 3.0 m from every prop, the same rule as the other points in `test_props_layout.gd`. Pads move;
  props do not.
- Each pad passes `CameraMath.on_screen` at 9:16 with the hero standing at its own station's zone.
- Draft positions that pass the zone checks by hand: counter pad (2.6, 7.2), freezer pad (7.8, 5.0). The freezer pad
  fails the prop rule (2.42 m from a tree) and must move.

Queue slot tests:
- `QUEUE_SLOTS.size() >= queue_max.max()`, and every slot is inside the bounds and north of `ROAD_Z`.
- For every slot k, the segment from `TRAVELER_ENTER` to slot k stays at least 1.0 m from every slot below k (today's
  diagonal gives 1.08 m). A straight line west does not pass this; the line must fold or step.
- All slots pass `CameraMath.on_screen` at 9:16 with the hero at `COUNTER_DROP`.

`WaypointGraph.create_default()` does not change; a unit test pins its nodes and edges to today's.

### 5.3 GameState and EventBus

```gdscript
var stations := {}   # {&"counter": {"level": 0, "paid": 0}, &"freezer": {...}}; StringName keys in memory
func station_level(id: StringName) -> int
func station_next_cost(id: StringName) -> int        # -1 at max level
func station_remaining_cost(id: StringName) -> int   # -1 at max level
func pay_into_station(id: StringName, amount: int) -> int
func debug_set_station_level(id: StringName, level: int) -> void   # tests, sims and fixtures only
```

- Keys are `StringName` in memory and `String` in snapshots, converted the way `cards` is (`_string_keys`).
- **Before the first `new_game`** (`stations` is empty while the world warms up): `station_level` returns 0 and the
  cost helpers return -1. An id outside `StationEffects.IDS` is an assert at any time.
- `pay_into_station` mirrors `pay_into_spot`: it takes at most the gold held and the remaining cost, emits
  `gold_changed`, then `station_changed(id, level, paid)`, and `station_upgraded(id, level)` when a level completes.
- `new_game` sets both stations to level 0, paid 0.
- `carry_capacity()` adds `StationEffects.carry_bonus(station_level(&"freezer"), Balance.data.stations)`.
- `move_carry_to_counter` uses the upgraded capacity. `Freezer` passes the upgraded load to `move_freezer_to_carry`.
- EventBus gains `station_changed(id: StringName, level: int, paid: int)` and
  `station_upgraded(id: StringName, level: int)`.

### 5.4 World and UI

- `world/stations/upgrade_pad.gd`, `class_name UpgradePad`: a `StationZone` with `drive_ring = false`, the ring marker,
  the cost label and the pips. It pays through `GameState.pay_into_station` and refreshes on `station_changed`,
  `phase_changed` and `state_restored`. `refresh` is safe before the first `new_game`. Coins fly from the hero to the
  pad, and `fx_requested(&"dust")` fires on the same cadence as build spots.
- `BuildSpot` and `UpgradePad` share only the pip row, through a small `LevelPips` helper. `BuildSpot._pips` stays
  (tests read it), and `BuildSpot` is not otherwise refactored.
- `Counter`: pile slots are generated for the level 5 capacity, 12 per layer (2 rows of 6), layers stacked upward. The
  visible count follows `counter_steaks`. On `station_upgraded(&"counter")` the body's visual child pops; the
  `StaticBody3D` and its shape are never scaled. `Freezer`: each tick moves `load_per_tick` steaks; its visual pops
  the same way.
- `TravelerSpawner`: reads the queue size, the interval and the service time through `StationEffects` at the moment
  it uses them, inside the existing `if active` paths. The RNG stream and the order of its calls do not change.
- `World`: creates the two pads. The traveler pool holds `StationEffects.traveler_pool_size(sb)` =
  `queue_max[max] + ceil(exit_walk_seconds / fastest_service_cycle) + 2`; a unit test runs a level 5 day and asserts
  the pool never emits `grew`.
- `CarryStack`: slots are generated for `StationEffects.max_carry` (26 today: 6 + 2×5 + 10). `test_piles.gd` pins the
  new formula.
- `Pulse.should_pulse`: an affordable station upgrade counts as an affordable purchase, so the sign does not pulse
  while one can be bought. A state without a `stations` key means no station is affordable (the existing Pulse
  fixtures keep their meaning).
- `CloseUpSign` also refreshes its pulse on `station_changed`. Without it the sign stays un-pulsed when the day's last
  purchase completes a station level (`gold_changed` fires before the level increments).
- `Autosave` writes on `station_upgraded`, as it does on `build_completed` ("after each build").
- `AudioDirector` and `Reactions` play the build sound and sparkle on `station_upgraded`.
- `Guide`: passes the upgraded counter capacity, and passes a spots-only pulse value to `GuideRules`, so the
  tutorial's `close` rule and its "Build here" pointer ignore stations. `GuideRules` is unchanged; a unit test covers
  "gold covers a pad but no spot: the guide still says close up".

### 5.5 Save

- `SCHEMA_VERSION` becomes 4. `to_dict` and `from_dict` carry `stations`; `"stations"` joins `SaveCodec.STATE_KEYS`.
- Built-in migrations live in `SaveCodec._built_in(from_v, state)` (a `match`; a constant cannot hold a Callable). `decode` uses `MIGRATIONS[from]` when a test registered
  one and the built-in step otherwise, so tests that clear `MIGRATIONS` cannot remove a real step.
- The 3 to 4 step adds `stations` with both ids at level 0, paid 0, and sets `v` to 4.
- `test_save_codec.gd`'s "no step registered for `SCHEMA_VERSION - 1`" assertion changes to cover the built-in step.
- `export/fixtures/night3_*.save.json` stay at schema 3: `test_perf_fixture.gd` and `test_lighting_director.gd` now
  also prove the migration on real files.
- Validation: both ids present and no unknown id, `0 <= level <= max_level`, `paid >= 0`. On load, `paid` is clamped
  to `cost - 1` (0 at max level): a save written before a cost was lowered still loads and its pad still completes.
- `counter_steaks` above the current capacity is not an error (capacity only limits adding).

### 5.6 Bots, sims, sweep, perf

- `PlannerBot.day_think` reads the counter capacity through `StationEffects`.
- `NaiveBot`, `PlannerBot` and `GuideBot` never buy station upgrades. Their runs are the determinism baseline.
- `UpgraderBot` extends `PlannerBot`: when the planner has no purchase left for tonight, it spends the remaining gold
  on the cheapest station upgrade it can finish (ties: counter first), then closes up. It builds its own graph: the
  default graph plus `pad_counter` and `pad_freezer` nodes.
- Sims (`tests/sim/test_day_sims.gd`, seed `20260930`):
  - 6.1: for each counter level 0 to 5, preset by `debug_set_station_level`, a counter kept stocked, a fixed window
    of physics frames; the served counts strictly increase by at least `min_level_gain`.
  - 6.2: DAY phase 1 with `PlannerBot`, counter at level 3 against level 0; fewer frames at level 3.
  - 6.3: one `UpgraderBot` run through night 3.
- Sweep: `sweep.gd` takes `--bot=upgrader` (default `planner`) and then writes `tests/sim/out/sweep_upgrader.csv`. The
  default invocation's CSV and stdout do not change. The sweep stays manual.
- Perf: `tests/sim/make_save.gd` can also write `export/fixtures/day3_counter5.save.json` (the close-up state before
  night 3, as the existing day fixture; counter at level 5 and stocked), and `export/perf_night3.sh` accepts the fixture name. Day perf with a level 5 counter is measured once
  and recorded next to the D-221 reading.

### 5.7 Hot files and wiring (D-136, D-139)

- `autoload/GameState.gd`, `autoload/EventBus.gd` and `balance/*` are edited by implementers only in tasks where that
  file is the task's main purpose; those tasks are serialized. In the plan: Task 1 owns `station_balance.gd` and the
  `stations` export in `balance_data.gd`; Tasks 3 and 4 own the autoloads; Task 6 owns the removal of the four fields
  from `economy_balance.gd`.
- Every other touch of a hot file (`world/world.gd`: pad creation and pool size) is reported as a wiring note and
  applied by the main session.

## 6. Error handling

- A pad never takes more gold than the hero holds or than the level still costs.
- Paying at max level, at night or with 0 gold does nothing.
- An unknown station id in a GameState call is an assert, as unknown spot ids are today.
- A queue longer than the current queue size cannot happen: the queue size never shrinks.

## 7. Testing

**Unit**
- `StationEffects`: every table at levels 0 and 5, the cost curve, -1 at max level, array lengths, `max_carry`,
  `traveler_pool_size`.
- Level 0 equals the S5 values (12, 4, 2.5, 1.0, carry bonus 0, load 1).
- `GameState`: `pay_into_station` (partial, completing, capped by gold, at max level), the signals and their order,
  the empty-`stations` window, `carry_capacity` with the bonus, the upgraded counter capacity and load.
- Save: the 3 to 4 migration (including after `MIGRATIONS.clear()`), a round trip with upgraded stations, each
  validation rule, the schema 3 fixtures.
- `MapLayout`: the pad and queue slot tests of 5.2; the default waypoint graph is unchanged.
- `Pulse`, `CloseUpSign`, `Guide`: an affordable station upgrade stops the pulse; completing the last affordable
  station level starts it; the guide ignores stations.
- `Autosave` writes on `station_upgraded`. The pool does not grow on a level 5 day.

**Sim**
- The existing sims pass unchanged. `tools/baseline_diff.sh` prints `baseline identical`.
- The three sims of 5.6. Estimated cost: about 15 s on top of today's 14 s.
- The sim suite stays under 60 s. If it does not: report per-test timings and escalate (D-132).

**Device**
- `export/device_check.sh` on the preview URL: the pads, the labels and the pips are readable at 720x1280 on the notch
  iPhone, and a level 5 queue is on screen from the counter.

## 8. Risks

- **Night balance:** gold spent on stations is not spent on defense. Sim 6.3 guards nights 1 to 3; the upgrader sweep
  shows the break day against the planner's. Costs are tuned within D-103's rule (3 rounds, then escalate).
- **Early gold:** in DAY phases 1 to 3 a player who builds defense first has 8 to 38 gold left, enough for one or two
  level-1 upgrades. Station upgrades are mostly a mid-game sink. Whether that is too late is a playtest question; it
  goes into `docs/REVIEW_QUEUE.md`.
- **Day perf:** the day already runs at about 53 fps in the iOS Simulator (known issue 1). A level 5 counter doubles
  the travelers on screen. The reading from 5.6 is recorded; a regression against the D-221 reading is reported to
  the author, not hidden.
- **Carry stack height:** 26 steaks is a tall stack. If it leaves the screen or hides the hero, the visual stack is
  capped and the count label carries the rest; logged in `docs/REVIEW_QUEUE.md`.

## 9. Changes after the spec review (D-230)

Changes to what the author approved:
- Criterion 6 was "the upgrader's day 3 is shorter than the planner's". With defense bought first, the bot has almost
  no gold for stations by day 3, so the comparison could not pass. It is now three sims (6.1 to 6.3).
- Level 5's queue is 9 (was 8), and `min_level_gain` forbids a dead level.
- The freezer upgrade is stated as comfort, not day speed.
- Pad and queue slot coordinates are fixed by tests; the "4 more slots running west" line is gone (arriving travelers
  would walk through the queue, and the slots would be off screen).
- The sweep gains a `--bot=upgrader` mode instead of a column (a column would break the determinism baseline).

Additions that do not change the design: the built-in migration table, the empty-`stations` window, the sign, autosave,
sound and sparkle listeners, the guide rule, the pool formula, the perf fixture, the list of unit tests that follow
the removed `EconomyBalance` fields, the hot-file rule.
