# E1 Station Upgrades: Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`). This builds on the S1 to S5 specs. Their conventions,
  architecture and rules still apply.
- **Precondition:** `main` at the final review package (D-221): GameState schema 3, the save envelope with its
  migration hook, the S4 determinism baseline, the S5 guide and audio.
- **Status:** brainstormed with the author on 2026-10-05. The author chose every option below and approved the design
  in chat.
- **Decision log:** `docs/DECISIONS.md` D-222 to D-229.

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

**The problem E1 solves:** gold has only 5 sinks (2 towers and 3 fences, 3 levels each). After a few days nothing is
left to buy, and the day stays the same length forever.

E1 is done when:
1. The counter and the freezer can each be upgraded from level 0 to level 5 with gold, by standing still on an upgrade
   pad beside the station. No menu and no button.
2. A counter upgrade makes the day busier and faster: more travelers, a longer queue, faster service, a bigger pile.
3. A freezer upgrade makes hauling faster: the hero carries more and loads faster.
4. At level 0 both stations behave exactly as they do today: `tools/baseline_diff.sh` prints `baseline identical`.
5. A schema 3 save loads, with both stations at level 0.
6. A planner bot that buys station upgrades still holds nights 1 to 3 on the sim seeds, and its day 3 is shorter than
   the same bot's day 3 without station upgrades.
7. Unit, sim and CI are green, the sim suite stays under 60 s, and every task passes a reviewer.

## 2. Scope

**In:**
- Station state in GameState, its payment method and two EventBus signals.
- `StationBalance` and the pure `StationEffects` helper.
- An `UpgradePad` beside the counter and beside the freezer.
- The counter, the freezer, the traveler spawner, the carry stack, the guide, the sign pulse and the planner bot read
  the upgraded values.
- Save schema 4 with a migration from 3.
- Sim and sweep updates.
- IDEA.md: stations become a gold sink.

**Out:**
- Staff, new equipment, map expansion (E2 to E4).
- A higher price per steak, a freezer capacity limit, spoilage.
- New station models per level. A level shows as the existing model scaled, plus star pips, the same as towers. This
  goes into `docs/REVIEW_QUEUE.md` as a reversible art decision.
- A guide pointer step that teaches the pads. The pads use the build-spot look the player already knows.

## 3. Player flow

- Each station has one upgrade pad on the ground: the build-spot ring marker, a cost label and up to 5 star pips.
- The pads are active in the DAY phase only, from day 1. At night the label and the ring are hidden.
- Standing still on a pad drains gold into it, at the build spots' rate (`Economy.drain_per_tick`). The ring shows
  paid / cost. When the level completes, the station pops, a dust puff plays and one more pip lights.
- A partial payment stays on the pad and is saved.
- At level 5 the label reads `MAX` and the pad takes no gold.
- An upgrade takes effect immediately: the next traveler interval, the next service, the next load tick.

## 4. Effects

Level 0 is today's value in every row. Every number lives in `balance/station_balance.gd` and `balance.tres`; the
values below are the starting point for tuning.

**Counter**

| Level | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Queue size | 4 | 5 | 6 | 7 | 8 | 8 |
| Traveler interval (s) | 2.5 | 2.1 | 1.8 | 1.5 | 1.25 | 1.0 |
| Service time (s) | 1.0 | 0.9 | 0.8 | 0.7 | 0.6 | 0.5 |
| Pile capacity | 12 | 18 | 24 | 30 | 36 | 42 |
| Cost to reach | n/a | 30 | 60 | 120 | 240 | 480 |

Service time is in the table because it is the real limit: today a traveler is served in 1.0 s and the next one needs
about 0.6 s to step up, so a shorter arrival interval alone would only fill the queue.

**Freezer**

| Level | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Extra carry | 0 | 2 | 4 | 6 | 8 | 10 |
| Steaks per load tick | 1 | 1 | 2 | 2 | 3 | 3 |
| Cost to reach | n/a | 25 | 50 | 100 | 200 | 400 |

- Extra carry applies everywhere, including picking up steaks at night. There is one carry number:
  `GameState.carry_capacity()` = the card value + the freezer bonus.
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
@export var queue_max: Array[int] = [4, 5, 6, 7, 8, 8]
@export var traveler_interval: Array[float] = [2.5, 2.1, 1.8, 1.5, 1.25, 1.0]
@export var service_time: Array[float] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
@export var counter_capacity: Array[int] = [12, 18, 24, 30, 36, 42]
@export var carry_bonus: Array[int] = [0, 2, 4, 6, 8, 10]
@export var load_per_tick: Array[int] = [1, 1, 2, 2, 3, 3]
```

Each array has `max_level + 1` entries; the validator and a unit test check it. `queue_max`, `traveler_interval`,
`service_time` and `counter_capacity` are removed from `EconomyBalance`: one source for each number.

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
```

`MapLayout` gains:
- `STATION_PADS := {"counter": Vector2(2.6, 7.2), "freezer": Vector2(7.8, 5.0)}`, pad radius `BUILD_RADIUS`.
- `QUEUE_SLOTS` grows to 8: the 4 existing slots, then 4 more running west at 1.2 m spacing from the last one.
- A unit test proves that each pad's circle overlaps no station zone, build spot, queue slot, lane zone, the sign or
  the diner, and that every queue slot is inside the bounds. The coordinates may move to satisfy the test.

### 5.3 GameState and EventBus

```gdscript
var stations := {}   # {"counter": {"level": 0, "paid": 0}, "freezer": {...}}
func station_level(id: StringName) -> int
func station_next_cost(id: StringName) -> int        # -1 at max level
func station_remaining_cost(id: StringName) -> int   # -1 at max level
func pay_into_station(id: StringName, amount: int) -> int
```

- `pay_into_station` mirrors `pay_into_spot`: it takes at most the gold held and the remaining cost, emits
  `gold_changed`, then `station_changed(id, level, paid)`, and `station_upgraded(id, level)` when a level completes.
- `new_game` sets both stations to level 0, paid 0.
- `carry_capacity()` adds `StationEffects.carry_bonus(station_level(&"freezer"))`.
- `move_carry_to_counter` uses `StationEffects.counter_capacity(station_level(&"counter"))`.
- EventBus gains `station_changed(id: StringName, level: int, paid: int)` and
  `station_upgraded(id: StringName, level: int)`.

### 5.4 World

- `world/stations/upgrade_pad.gd`, `class_name UpgradePad`: a `StationZone` with `drive_ring = false`, the ring marker,
  the cost label and the pips. It pays through `GameState.pay_into_station` and refreshes on `station_changed`,
  `phase_changed` and `state_restored`. Coins fly from the hero to the pad, and `fx_requested(&"dust")` fires on the
  same cadence as build spots.
- `BuildSpot` and `UpgradePad` share only what is identical: the pip row. It moves into a small helper
  (`LevelPips`), used by both. `BuildSpot` is not otherwise refactored.
- `Counter`: pile slots are generated for the level 5 capacity, 12 per layer (2 rows of 6), layers stacked upward. The
  visible count follows `counter_steaks`. On `station_upgraded(&"counter")` the counter body pops.
- `Freezer`: each tick moves `load_per_tick` steaks. On `station_upgraded(&"freezer")` the freezer body pops.
- `TravelerSpawner`: reads the queue size, the interval and the service time through `StationEffects` at the moment
  it uses them. The RNG stream and the order of its calls do not change.
- `World`: the traveler pool is sized for the level 5 queue. It creates the two pads.
- `CarryStack`: slots are generated for the largest possible carry (max card level + max freezer level, 26 today).
- `Pulse.should_pulse` and `GuideRules`: an affordable station upgrade counts as an affordable build spot, so the sign
  does not pulse while one can be bought. `Guide` passes the upgraded counter capacity.
- Wiring (D-139): `world/world.gd`, `autoload/*`, `balance/*` are hot files; implementers report wiring notes and the
  main session applies them.

### 5.5 Save

- `SCHEMA_VERSION` becomes 4. `to_dict` and `from_dict` carry `stations`.
- `SaveCodec` gets its first migration, 3 to 4: add `stations` with both ids at level 0, paid 0.
- Validation: both ids present, `0 <= level <= max_level`, `0 <= paid < cost of the next level`, and `paid == 0` at
  max level. A save that fails validation is handled as a corrupt save is today.
- `counter_steaks` above the current capacity is not an error (capacity only limits adding).

### 5.6 Bots and sims

- `PlannerBot.day_think` reads the counter capacity through `StationEffects`.
- `NaiveBot` and `PlannerBot` never buy station upgrades. Their runs are the determinism baseline: level 0 for the
  whole run, so the S4 baseline stays identical.
- A new `UpgraderBot` extends `PlannerBot`: after the planner's purchases for tonight's telegraph are bought, it spends
  the remaining gold on the cheapest station upgrade (ties: counter first), then closes up.
- New sims in `tests/sim/test_day_sims.gd`: the `UpgraderBot` holds nights 1 to 3 on the sim seeds; its day 3 takes
  fewer physics frames than the `PlannerBot`'s day 3 on the same seed.
- The sweep gains an `upgrader` column. It stays manual.

## 6. Error handling

- A pad never takes more gold than the hero holds or than the level still costs.
- Paying at max level, at night or with 0 gold does nothing.
- An unknown station id in a GameState call is an assert, as unknown spot ids are today.
- A queue longer than the current queue size cannot happen: the queue size never shrinks.

## 7. Testing

**Unit**
- `StationEffects`: every table at levels 0 and 5, the cost curve, -1 at max level, array lengths.
- Level 0 equals the S5 values (12, 4, 2.5, 1.0, carry bonus 0, load 1).
- `GameState`: `pay_into_station` (partial, completing, capped by gold, at max level), the signals and their order,
  `carry_capacity` with the bonus, `move_carry_to_counter` with the upgraded capacity, `move_freezer_to_carry` with
  the upgraded load.
- Save: the 3 to 4 migration, a round trip with upgraded stations, each validation rule.
- `MapLayout`: pad clearance, 8 queue slots inside the bounds.
- `Pulse` and `GuideRules`: an affordable station upgrade stops the pulse.

**Sim**
- The existing sims pass unchanged.
- `tools/baseline_diff.sh` prints `baseline identical`.
- The two new `UpgraderBot` sims (5.6).
- The sim suite stays under 60 s. If it does not: report per-test timings and escalate (D-132).

**Device**
- `export/device_check.sh` on the preview URL: the pads, the labels and the pips are readable at 720x1280 on the notch
  iPhone, and the 8-traveler queue stays on screen.

## 8. Risks

- **Night balance:** gold spent on stations is not spent on defense. The `UpgraderBot` sims guard nights 1 to 3; the
  sweep shows the break day against the planner's. Costs are tuned within D-103's rule (3 rounds, then escalate).
- **Day perf:** the day already runs at about 53 fps in the iOS Simulator (known issue 1). A level 5 counter doubles
  the travelers on screen. Day-3 perf is measured with a level 5 counter and recorded; a regression against the D-221
  reading is reported to the author, not hidden.
- **Carry stack height:** 26 steaks is a tall stack. If it leaves the screen or hides the hero, the visual stack is
  capped and the count label carries the rest; logged in `docs/REVIEW_QUEUE.md`.
