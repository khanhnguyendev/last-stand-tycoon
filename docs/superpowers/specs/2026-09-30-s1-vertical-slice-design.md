# S1 Vertical Slice: Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`)
- **Status:** approved in brainstorm on 2026-09-30, pending review of this written spec
- **Decision log:** `docs/DECISIONS.md`. This spec states final values and cites `D-xxx` ids.
  Rationale lives in the log.
- **Engine:** Godot 4.7, GDScript, Compatibility renderer, portrait 720×1280, web export
  (single-threaded, D-014).

This spec is written for an implementer who has not seen the brainstorm. Every system lists its
**owner**, **inputs**, **outputs** and **tests**.

---

## 1. Context

### 1.1 What S1 is

S1 is the smallest playable version of the core loop, built on the final architecture with
placeholder art. The loop runs endlessly:

night (3 waves) → dawn → day (haul, sell, build, upgrade) → close up → next night.

There is no throwaway code. S2 and later add to it; they do not rewrite it.

### 1.2 v0.1 decomposition (D-001)

| Id | Sub-project | Notes |
|---|---|---|
| **S1** | Vertical slice | This spec |
| S2 | Hero cards + adventurer guards | Fills the `CARD_PICK` stub. Adds `guard` to `TargetPriority`. Re-tunes wave scaling against a target break day *with* cards (D-156): in S1 the PlannerBot ends nights 2–4 at 100%, 83% and 75% diner HP. |
| S3 | Save/load + failure & mercy | The Close-up snapshot is the night-start save point, so quitting mid-night costs the same as failing (D-048). |
| S4 | Asset pipeline + art pass | S4 asset pipeline (TBD, D-024). Swaps each scene's `Visual` child. |
| S5 | UI/HUD polish, onboarding, audio | |
| S6 | Web hardening, QA, itch.io release + playtest gate | Owns the itch.io draft, the iframe-embed checks (safe area and fullscreen inside the embed) and butler uploads (D-135). |

Each sub-project gets its own spec → plan → build.

### 1.3 Scope

**In:**
- The game opens at dusk of night 1, with first combat within 30 s.
- Floating joystick; stand-still interaction.
- 3 waves with a 10 s breather, edge arrows and moon icons.
- Hero auto-attack while moving.
- One monster type (Boar).
- Steak drops and walk-over pickup.
- Enemy targeting: fence → diner, data-driven.
- Diner HP.
- Dawn: steaks to the freezer, heal, fence reset, a stub card pick.
- Day: freezer → carry → counter, traveler queue, gold pile.
- 2 tower spots and 3 fence spots, with build and upgrade to level 3.
- The "Close up" sign with its pulse.
- Per-day wave scaling, with main and side lane groups from night 2.
- Seeded lane plan and day telegraph.
- Diner falls → restore the night-start snapshot (in memory).
- Mobile web shell, focus pause, debug and profile tooling, CI.

**Out:** hero cards, guards, disk save, mercy, audio, onboarding, final art and settings.

---

## 2. Conventions

- **Units:** meters, seconds and degrees.
- **World axes:** the origin is the diner center. North is **−z**, east is **+x**, and **y** is
  up. The ground is y = 0.
- **Map bounds:** x ∈ [−24, 24], z ∈ [−24, 14].
- **Ticks:** physics runs at 60 Hz. All gameplay runs in `_physics_process`, and nothing gameplay
  uses frame delta (D-031).
- **Ids:**
  - lane ids: `&"west"`, `&"north"`, `&"east"`;
  - spot ids: `&"tower_nw"`, `&"tower_ne"`, `&"fence_w"`, `&"fence_n"`, `&"fence_e"`.
- **Phases:** `enum Phase { NIGHT, DAWN, DAY }`.
- **Strings:** every user-facing string goes through `tr()`, with the English text as the key
  (D-074).

---

## 3. Architecture

### 3.1 Project layout (canonical, D-032, D-098)

```
autoload/        EventBus.gd, GameState.gd, Balance.gd
core/            pure static helpers: rng.gd, lane_planner.gd, wave_math.gd, targeting.gd,
                 economy.gd, geometry.gd, pulse.gd
components/      health.gd, targetable.gd, attacker.gd, station_zone.gd, carry_stack.gd, magnet.gd,
                 node_pool.gd
actors/          hero/, enemy/, traveler/, projectile/, bots/ (sim bots)
world/           main.tscn, map.tscn, diner/, lanes/, stations/, build_spots/, wave_director.gd,
                 traveler_spawner.gd, phase_controller.gd, focus_pause.gd, camera_rig.gd
ui/              hud/, joystick/, world_label/, progress_ring/, perf_overlay.tscn, debug/ (debug only)
balance/         balance.tres (BalanceData), ui_tuning.tres (UiTuning), *.gd resource scripts
tests/unit/      pure core tests + single-scene integration tests (D-080)
tests/sim/       bot-driven sims + sweep.gd; out/ is gitignored
addons/          GUT only (third-party)
export/          web_shell.html, export notes
.github/         workflows/ci.yml
docs/            IDEA.md, DECISIONS.md, ASSET_LICENSES.md, specs, screenshots/s1/
```

`CLAUDE.md` is written in the first build step and must match this layout (D-032).

### 3.2 Autoloads

**`EventBus`**
- Holds signals only. It carries cross-system events; parent/child and component-to-owner
  communication uses local signals (D-037).
- Every signal is documented with typed arguments in `EventBus.gd`:

| Signal | Args | Emitted by |
|---|---|---|
| `phase_changed` | `phase: int, day: int` | PhaseController |
| `wave_started` | `wave_index: int, main_lane: StringName, side_lane: StringName` (`&""` if none) | WaveDirector |
| `wave_cleared` | `wave_index: int` | WaveDirector |
| `enemy_killed` | `spawn_index: int, lane: StringName, position: Vector3` | Enemy |
| `diner_damaged` | `amount: float, hp_left: float` | GameState |
| `diner_fell` | none | GameState |
| `night_failed` | `day: int` | PhaseController |
| `state_restored` | none (GameState was replaced wholesale: `new_game` or `from_dict`, D-109) | GameState |
| `gold_changed` | `gold: int, delta: int` | GameState |
| `building_changed` | `spot_id: StringName, level: int, paid: int` | GameState |
| `build_completed` | `spot_id: StringName, level: int` | GameState |
| `steak_picked` | `carried: int` | GameState |
| `steak_sold` | `count: int, gold: int` | GameState |
| `stocks_changed` (D-109) | none (freezer, carried, counter or gold_pile changed; listeners re-read GameState) | GameState |
| `closeup_requested` (D-109) | none | CloseUpSign |
| `banner_requested` (D-109) | `text: String` (already translated) | PhaseController |
| `wave_incoming` (D-109) | `wave_index: int, main_lane: StringName, side_lane: StringName` (the pre-wave delay started) | WaveDirector |
| `wave_spawned_out` (D-109) | `wave_index: int` (the wave's last planned enemy spawned) | WaveDirector |
| `hero_place_requested` (D-128) | `position: Vector2` (new game and restore placement; the Hero teleports and the CameraRig snaps) | PhaseController |

**`GameState`**
- Holds data only. **All mutation goes through its methods, which emit the matching bus signals**
  (D-096). The methods are:
  - `add_gold`, `collect_pile`
  - `add_freezer`, `pick_steak`
  - `move_freezer_to_carry`, `move_carry_to_counter`
  - `sell_from_counter`
  - `pay_into_spot`, `next_level_cost`, `remaining_cost`, `fence_max_hp`
  - `damage_diner`, `damage_fence`, `diner_fraction`
  - `heal_for_dawn`, `reset_destroyed_fences`, `advance_day`
- It also has `to_dict()`, `from_dict()` and `new_game(seed)`. Section 4 lists the fields.

**`Balance`**
- Loads `res://balance/balance.tres` (`BalanceData`) and `res://balance/ui_tuning.tres`
  (`UiTuning`).
- `Balance.reset()` reloads fresh copies and `Balance.inject(data, ui)` swaps them (tests).
- Section 12 lists every field.

### 3.3 Main scene tree

```
Main (Node3D)                      world/main.tscn: holds World, its pools, WaveDirector,
                                   TravelerSpawner and PhaseController, wired by typed @export (D-128)
├─ PhaseController                 owns phase, snapshot, dawn + close-up steps
├─ FocusPause                      pauses tree on focus loss / hidden tab (D-046)
├─ World (map.tscn)
│  ├─ Ground, Road
│  ├─ Diner, Counter, Freezer      StaticBody3D: the hero's only colliders (D-125); diner HP lives in GameState
│  ├─ Lanes: LaneWest, LaneNorth, LaneEast   (Path3D + entrance marker + TelegraphMarker)
│  ├─ BuildSpots: TowerNW, TowerNE, FenceW, FenceN, FenceE
│  ├─ Stations: Freezer, Counter, GoldPile, CloseUpSign
│  ├─ WaveDirector
│  ├─ TravelerSpawner
│  ├─ FlyFx                        visual-only transfer arcs (D-078)
│  └─ Pools: EnemyPool, SteakPool, ProjectilePool, FxPool, TravelerPool
├─ Hero                            CharacterBody3D + HeroInput + Attacker + CarryStack + Magnet
├─ CameraRig
├─ InputLayer (CanvasLayer)        Joystick
├─ HUD (CanvasLayer)               gold, moons/day label, diner bar, edge arrows, banners
└─ (DebugOverlay)                  added at runtime via load() only if OS.is_debug_build() (D-099)
```

### 3.4 Components

| Component | Purpose | Local signals |
|---|---|---|
| `Health` | `max_hp`, `hp`, `reset(max)`, `damage(amount)`, `is_alive()`. Used by enemies. The diner and fences keep their HP in GameState. | `died`, `damaged(amount)` |
| `Targetable` | `kind: StringName` (`&"enemy"`, `&"fence"`, `&"diner"`), `spawn_index: int` | none |
| `Attacker` | `configure(damage, attack_range, interval, retarget_interval, moving_mult, projectile_speed)`, `candidates: Callable`, `is_moving: Callable`; fires a projectile through the pool | `fired(target)` |
| `StationZone` | `radius`, `active_phases`, `armed`; arms on walk-in (D-121), detects the hero standing still (D-006), runs a tick timer | `stand_started`, `ticked`, `stand_ended` |
| `CarryStack` | Visual stack of N steaks on the hero's back, driven by `GameState.carried_steaks` | none |
| `Magnet` | Radius check against ground steaks and the gold pile each tick (a distance check, not Area3D, D-034) | none (it calls GameState) |
| `NodePool` | Prewarmed pool with `acquire()`/`release()`; warns if it grows (D-061) | `grew(new_size)` |

### 3.5 Pure `core/` modules (unit-tested, no scene)

| Module | API |
|---|---|
| `Rng` | `stream(run_seed, day, name) -> RandomNumberGenerator`, where seed = **FNV-1a 32** of `"%d:%d:%s"`, masked to 32 bits (D-097 amended by D-108: the 64-bit multiply overflows in GDScript). `new_run_seed()` is the only clock-derived seed (D-041). |
| `LanePlanner` | `plan(run_seed, day, wave_balance) -> Array[Dictionary]` (section 6.2), `threat_by_lane(plan, base_hp)`, `marker_scale(threat, max, min_s, max_s)` |
| `WaveMath` | `raw_total(day, w, wb)`, `total_count(day, w, wb)`, `hp_mult(day, w, wb)`, `side_share(day, wb)`, `split(day, w, wb) -> {main, side}` |
| `WaveSchedule` | `build(wave, wb) -> [{t, lane, side}]`, `is_cleared(planned, spawned, alive)` (D-044) |
| `Targeting` | `select(origin, range, candidates) -> candidate or {}`: nearest (XZ), ties broken by the lower `spawn_index` |
| `Economy` | `level_cost(spot_id, level, build_balance)`, `drain_per_tick(cost, build_balance)`, `night_kills(day, wb)`, `night_gold(day, balance)` |
| `Pulse` | `should_pulse(state_dict, balance) -> bool` (section 8.8) |
| `MapLayout` | every map coordinate (section 6.1): lane paths, zone rectangles, spots, stations, `HOME`, `NIGHT1_START` |
| `Geometry` | path length/point/tangent, point-to-segment and point-to-rect distance, rect containment, enclosing radius |
| `EnemyPath` | `position_at(lane, dist, offset, fade)`: the D-111 offset model (section 6.5) |
| `WaypointGraph` | the fixed bot navigation graph (section 13.3) |
| `CameraMath` | camera transform and projection shared by `CameraRig` and the lane-visibility test (D-090) |
| `Phase` | `NIGHT`, `DAWN`, `DAY`, `name_of(p)` |

### 3.6 Determinism rules (D-034)

1. All randomness comes from `Rng.stream(run_seed, day, name)`. The streams are `lane_plan`,
   `spawns`, `travelers` and `drops`.
2. A grep test fails on `randi(`, `randf(`, `randi_range(`, `randf_range(`, `randomize(` or
   `RandomNumberGenerator.new(` anywhere outside `core/rng.gd`.
3. Enemies and travelers are moved in code along paths on the physics tick. No gameplay decision
   uses physics queries or Area3D overlap order.
4. Ties are broken by `spawn_index`, never by node order.
5. The hero is a `CharacterBody3D`, driven only through `HeroInput.set_move(v: Vector2)`. The
   joystick, WASD and the bots all call it.

### 3.7 Data flow

- Nodes read `Balance`, change `GameState` through its methods, and listen on `EventBus`.
- The HUD and world visuals only listen.
- No system reaches into another system's nodes, **with one exception (D-110, D-128):** `PhaseController`
  is the orchestrator. It calls other systems only through this narrow interface, via **typed `@export`
  references assigned in `world/main.tscn`**. It never uses `get_node` paths, groups or tree searches, and
  a unit test greps its source to enforce that.
  - `WaveDirector.start_night(plan)`, `WaveDirector.stop()`
  - `NodePool.recall_all() -> int` (enemy, steak, projectile and fx pools; the steak count goes to the freezer)
  - `TravelerSpawner.start()`, `stop()`, `clear_queue()`
  - The hero is placed with the bus event `hero_place_requested(position)`, which the Hero and CameraRig handle.
- PhaseController is the only writer of the phase.

---

## 4. GameState and the snapshot

### 4.1 Fields and snapshot schema (`to_dict()`, schema `v: 1`)

```gdscript
{
  "v": 1,
  "resume_phase": "NIGHT" | "DAY",      # D-043
  "run_seed": int,
  "day": int,                           # D-038: night N is fought with day == N
  "gold": int,
  "gold_pile": int,
  "freezer_steaks": int,
  "counter_steaks": int,
  "carried_steaks": int,
  "diner_hp": float,
  "buildings": {                        # D-067
    "tower_nw": {"level": int, "paid": int, "hp": float},  # towers: hp unused (0)
    "tower_ne": {...}, "fence_w": {...}, "fence_n": {...}, "fence_e": {...}
  },
  "lane_plan": [                        # 3 entries, one per wave (6.2)
    {"main": "north", "side": "" | "west" | "east" | "north",
     "main_count": int, "side_count": int, "hp_mult": float}
  ]
}
```

- `level` 0 means unbuilt. `paid` is the gold already paid toward the next level.
- The snapshot never contains world items: no enemies, ground steaks, coins, travelers or
  projectiles (D-036, D-045).

### 4.2 Restore contract (D-036)

- `from_dict(d)` replaces every field and then emits `state_restored`.
- Each stateful node rebuilds its visuals and behavior **from GameState alone** when it gets that
  signal:
  - **BuildSpot:** level model, pips, cost label, fence HP and rubble state.
  - **Freezer, Counter, GoldPile:** their stacks and labels.
  - **Diner:** the HP bar.
  - **TelegraphMarkers:** scaled from `lane_plan`.
  - **CarryStack.**
- Nodes hold no hidden gameplay state.
- `PhaseController` owns the snapshot (`snapshot: Dictionary`) and performs the restore
  (section 5.3).

---

## 5. Phase flow (owner: PhaseController)

### 5.1 New game

1. `GameState.new_game(seed)`:
   - `run_seed = seed`, or `Rng.new_run_seed()` when no seed is passed
   - `day = 1`, `gold = 0`
   - every stock is 0
   - diner at full HP
   - every building `{0, 0, 0}`
   - `lane_plan = LanePlanner.plan(run_seed, 1, Balance.data.wave)`
2. `snapshot = GameState.to_dict()` with `resume_phase = "NIGHT"` (D-043).
3. The hero is placed at the **night-1 start (−2.5, −7)**: north of the diner, off the north lane and outside every zone, so wave 0 (always north) walks into range with no map knowledge (D-126). The phase becomes `NIGHT`.

### 5.2 NIGHT

- `WaveDirector` runs waves 0, 1 and 2 from `GameState.lane_plan` (section 6.3).
- Stations, build spots, the sign and the telegraph markers are inactive or hidden. Travelers are
  absent.
- When `wave_cleared(2)` arrives, PhaseController enters `DAWN`.
- When `diner_fell` arrives, the fail flow runs (5.3).
- The first night of a new game (and each night-1 restart) shows the banner "The monsters return".

### 5.3 Fail flow (D-043)

1. `night_failed(day)` is emitted, and the banner "The diner fell" shows for `banner_time` (2.0 s). WaveDirector
   stops spawning.
2. Every pool recalls its items (enemies, steaks, projectiles, coin FX).
3. `GameState.from_dict(snapshot)` runs, which emits `state_restored`.
4. The hero goes to the night-1 start (−2.5, −7) when `resume_phase == "NIGHT"` (D-126), otherwise to home (0, 9.5), which is outside every station zone (D-122).
5. If `resume_phase == "NIGHT"`: enter `NIGHT` again (night 1 restarts directly, first spawn at
   `first_wave_delay`, 5 s). If it is `"DAY"`: enter `DAY`.
6. The lane plan is part of the snapshot, so the same night replays.

### 5.4 DAWN (steps in order, with a "Dawn" banner)

1. Every ground steak is recalled, and the count is added to `freezer_steaks`. Carried steaks stay.
2. `diner_hp` is set to max, and standing fences heal to the max for their level.
3. Every destroyed fence (`hp <= 0` with `level >= 1`) is set to `{level: 0, paid: 0, hp: 0}`
   (D-067).
4. `day += 1`, and `lane_plan = LanePlanner.plan(run_seed, day, Balance.data.wave)` (D-038).
5. The `CARD_PICK` sub-state is a stub that completes immediately. It stays a real state for S2.
6. The phase becomes `DAY`.

### 5.5 DAY

- The stations, build spots, sign and telegraph markers activate, and TravelerSpawner starts.
- There is no timer. The night starts only through Close-up.

### 5.6 Close-up (D-039, D-036)

The hero walks into the sign zone (arming it, D-121) and stands still (`stand_still_time`, 0.25 s), then the ring fills over `closeup_hold` (1.0 s).
Then:
1. `GameState.collect_pile()` moves `gold_pile` into `gold`, and any ground steaks go to the
   freezer.
2. TravelerSpawner stops, and the travelers walk off and despawn. They hold nothing (D-045).
3. `snapshot = GameState.to_dict()` with `resume_phase = "DAY"`.
4. The phase becomes `NIGHT`.

### 5.7 Tests

| Tier | Test |
|---|---|
| Unit (integration) | The dawn step order, including a destroyed fence resetting to level 0 |
| Unit (integration) | The close-up order: the pile is collected before the snapshot, and the snapshot has no world items |
| Unit (integration) | The restore test (section 13.2) |
| Sim | Night-1 fail → restart (section 13.4) |

---

## 6. Map, lanes and geometry

### 6.1 Layout (D-054, D-055, D-062, D-091 to D-093)

| Thing | Position / shape |
|---|---|
| Diner | Solid box 8×8×3, centered at the origin (walls at x = ±4, z = ±4) |
| North lane path | (0, −24) → (0, −5.2) |
| West lane path | (−16, −24) → (−11, −11) → (−5.2, 0) |
| East lane path | (16, −24) → (11, −11) → (5.2, 0) |
| Attack zone, west | Rectangle x ∈ [−5.2, −4.0], z ∈ [−1.5, 1.5] (the band within 1.2 m reach of the west wall). The path ends at (−5.2, 0). |
| Attack zone, north | Rectangle z ∈ [−5.2, −4.0], x ∈ [−1.5, 1.5]. The path ends at (0, −5.2). |
| Attack zone, east | Rectangle x ∈ [4.0, 5.2], z ∈ [−1.5, 1.5]. The path ends at (5.2, 0). |
| Tower spots | `tower_nw` (−5, −5), `tower_ne` (+5, −5) |
| Fence spots (4 m before the zone along the path) | `fence_n` (0, −9.2), `fence_w` (−7.06, −3.54), `fence_e` (+7.06, −3.54); a 3 m bar perpendicular to the path |
| Telegraph markers | 1.5 m up-path from each fence spot |
| Counter | 3×1 m box at (0, 4.8). Hero drop zone at (2.2, 4.8). Traveler service point at (0, 6.0). |
| Queue slots | (0, 6.0), (−1.2, 7.0), (−2.4, 8.0), (−3.6, 9.0) |
| Gold pile | (−2.5, 5.5) |
| Freezer | 1.5×1.5 m box at (5.5, 5), zone at (5.5, 6.3) |
| Close-up sign | (0, 8) |
| Hero home | (0, 9.5): outside every zone; restores to DAY land here (D-122) |
| Night-1 start | (−2.5, −7): new game and night-1 restart spawn, outside every zone and 2.5 m off the north lane (D-126) |
| Road | East–west at z = 11. Travelers enter at (24, 11) and exit at (−24, 11). |

- Station zones have a radius of 1.0 m; build-spot zones 1.2 m.
- The hero collides with the diner, counter and freezer only. Towers, fences, enemies, travelers
  and pickups don't collide with it (D-094, D-125).

### 6.2 Lane plan (owner: `LanePlanner`, D-026 to D-028, D-095, D-100)

`plan(run_seed, day, wave_balance)` uses the `lane_plan` stream and returns 3 waves. Each wave is
`{main, side, main_count, side_count, hp_mult}`.

- **Day 1:** there is no side group (`side = ""`, `side_count = 0`). Wave 0's `main` is always
  `north`. Waves 1 and 2 pick `main` uniformly from the 3 lanes.
- **Day ≥ 2:** `main` is picked uniformly, and `side` is picked uniformly from the other 2 lanes.
  At most 2 lanes are active per wave.
- **Counts (`WaveMath`):**
  - `total = round(base_counts[w] × (1 + count_growth × (day − 1)))`, with `base_counts` [4, 6, 8] and
    `count_growth` 0.35.
  - `hp_mult = 1 + hp_growth × (day − 1)`, with `hp_growth` 0.15.
  - If `total > max_wave_size` (30): `hp_mult ×= total / max_wave_size`, then `total = max_wave_size` (D-053).
  - `side = day ≥ 2 ? max(1, round(total × share(day))) : 0`, and `main = total − side`.
  - `share(day) = min(side_share_base + side_share_step × (day − 2), side_share_cap)` for day ≥ 2, i.e. min(0.20 + 0.05 × (day − 2), 0.45) (D-027).

**Reference values** (at the default Balance; pinned by `test_wave_math`):

| Day | Totals | Side counts | HP per Boar |
|---|---|---|---|
| 1 | 4 / 6 / 8 | 0 | 30 |
| 2 | 5 / 8 / 11 | 1 / 2 / 2 | 34.5 |

### 6.3 Geometry tests (`tests/unit/test_geometry.gd`)

| Test | Assertion | Value on paper |
|---|---|---|
| A′ (D-123) | On a 0.25 m grid of hero-reachable positions (the map bounds minus the diner, counter and freezer, grown by the hero radius), no position has enemy stop points (the D-111 model, full lateral spread) from all 3 lanes within hero range. The positions reaching 2 lanes are printed as info. The zone-corner enclosing radius (5.41) is printed as info only. | max 2 lanes; west+north 16 points, north+east 16 points, west+east impossible |
| B (D-055) | Each tower reaches every point of the zones of its two adjacent lanes (NW: west + north, NE: north + east) | worst 6.58 ≤ 7 (corner (−4, 1.5) from (−5, −5), after D-101) |
| C (D-076) | Each tower reaches the fence spots of its two adjacent lanes | NW → west 2.5, north 6.53 |
| D (D-093) | For 1,000 sampled lateral offsets in [−1, 1], every enemy stop point lies inside its lane's zone rectangle | none |
| E | Every lane path keeps ≥ 1.5 m from every tower spot (including the ±1 m lateral offset) and ≥ reach (1.2 m) from the diner box | west path to NW tower 2.5 m |

All geometry tests re-run after any change to a path.

### 6.4 Lane visibility (D-076, D-090)

- **Camera projection test:** with the hero standing at each lane's zone center, the camera settled
  and the viewport at 720×1280, a Boar walking the path is on screen for **≥ 2.0 s** at Boar speed
  before it enters hero range. The test projects path samples through the real `Camera3D`.
- **Screenshots:** one 720×1280 screenshot per lane, saved to `docs/screenshots/s1/lane_<id>.png`.
- **Fallback, only if the test fails:** pull the camera back or widen the FOV, keeping the Boar at
  least 40 px tall at 720 width. Log the change.

### 6.5 Enemy lateral offset (D-111)

- Each Boar gets `offset = unit × lateral_spread` (1.0 m), with `unit` in [−1, 1] from the `spawns` stream.
- `EnemyPath.position_at(lane, dist, offset, fade)`: along the path, the offset is perpendicular to the
  path tangent. Over the last `offset_fade_distance` (`EnemyBalance`, 3.0 m) it blends linearly onto the
  zone's width axis (z for west and east, x for north).
- So the stop point is always `path end + axis × offset`, inside the zone rectangle (test D), and the
  path keeps ≥ 1.5 m from the towers and ≥ reach from the diner (test E).

---

## 7. Night systems

### 7.1 WaveDirector

- **Owner:** `world/wave_director.gd`.
- **Inputs:** `GameState.lane_plan`, `Balance.wave`, `EnemyPool`, the `spawns` stream.
- **Outputs:** the `wave_started` and `wave_cleared` signals.

**Timeline**
- On entering NIGHT, wave 0 starts after `first_wave_delay` = 5.0 s.
- Main-group Boars spawn at the main lane's entrance, one every `spawn_interval` = 0.8 s.
- The side group starts `side_group_delay` = 4.0 s after the main group's first spawn, at the same
  interval.
- Each enemy gets a unique, increasing `spawn_index` per night, and a lateral offset in [−1, 1] m
  from the `spawns` stream.

**Clear rule (D-044):** a wave is cleared only when **every planned spawn (main + side) has
spawned AND its alive count is 0**. Then it emits `wave_cleared(w)`. For w < 2, the next wave starts
after `breather` = 10.0 s.

**It never changes the phase.** PhaseController reacts to `wave_cleared(2)`.

**Tests**
- Unit: the wave-clear edge case, where the main group is killed before the side group spawns and
  no clear fires.
- Unit: the spawn schedule times.

### 7.2 Enemy: Boar

- **Owner:** `actors/enemy/boar.tscn`.
- **Components:** Health, Targetable (`enemy`), Visual.
- **Stats (`EnemyBalance`):** HP `hp × hp_mult` (30 × hp_mult), `speed` 2.0 m/s, `damage` 5 every `attack_interval` 1.0 s, `reach` 1.2 m.

**Movement:** walks its lane path in code on the physics tick, applying its lateral offset by the
D-111 model (section 6.5). It stops at its attack zone (a stop point inside the zone rectangle, per
geometry test D). It never paths to the door.

**Targeting (D-004, D-049):** each tick it walks `TargetPriority.kinds`, which is
`[&"fence_on_lane", &"diner"]` in S1. It asks a provider for each kind in order; the first
non-null target wins. With none, it walks.
- `fence_on_lane`: the fence spot on this lane is standing (`level ≥ 1` and `hp > 0`) and is within
  reach of the enemy.
- `diner`: the enemy has reached its stop point.

S2 inserts `guard` without editing the enemy code: providers are registered by kind in a
dictionary.

**Attacking**
- A fence: `GameState.damage_fence(spot_id, damage)`. At `hp ≤ 0` the fence becomes rubble (it blocks
  nothing, stays level ≥ 1 with hp 0, and is reset at dawn).
- The diner: `GameState.damage_diner(damage)`.

**Death**
- It emits `enemy_killed` and spawns `steaks_per_kill` (2) steaks, scattered up to `drop_scatter` (0.6 m) by the
  `drops` stream.
- Placeholder death: a scale-down tween (0.15 s), then it returns to the pool.
- Hit flash: white for `hit_flash_time` (0.08 s, `UiTuning`).

The hero is never a target in S1 (D-005).

**Tests**
- Unit: provider order (fence before diner, rubble ignored).
- Unit: `Targeting.select()` tie-break.

### 7.3 Hero combat (D-018 to D-020)

- **Owner:** `actors/hero/hero.tscn` plus its `Attacker`.
- **Stats (`HeroBalance`):** `move_speed` 5.0 m/s, `attack_damage` 10 every `attack_interval` 0.5 s,
  `attack_range` **4.0 m**, `retarget_interval` 0.2 s.
- `moving_attack_speed_mult` = 1.0 scales the rate while moving. Values below 1.0 give the hybrid.
- **Targeting:** every `retarget_interval`, it runs `Targeting.select()` over the live enemies, in
  spawn-index order.
- **Attacks while moving.** Night and day behave the same: there are simply no enemies by day.

### 7.4 Projectiles (D-050, D-060)

- Cleaver `projectile_speed` 14 m/s (`HeroBalance`); tower bolt `tower_projectile_speed` 16 m/s (`BuildBalance`). Both are homing.
- **Damage applies on hit only.** If the target dies mid-flight, the projectile despawns, with no
  retarget and no damage carry.
- They are pooled.

### 7.5 Towers (D-055, D-067)

- **Owner:** `world/build_spots/tower_spot.tscn`.
- **Inputs:** `GameState.buildings[id].level`, `Balance.build`.

**Stats by level** (`BuildBalance`: `tower_damage[]`, `tower_range[]`, `tower_interval`, cost = `tower_cost × level_cost_mult^(level−1)`)

| Level | Damage | Range | Interval | Cost to reach |
|---|---|---|---|---|
| 1 | 8 | 7.0 | 0.5 s | 40 |
| 2 | 12 | 7.5 | 0.5 s | 80 |
| 3 | 18 | 8.0 | 0.5 s | 160 |

- Towers use the same `Targeting.select()` and a homing bolt.
- They have no HP and are never targeted. They are inactive at level 0.

### 7.6 Fences (D-003, D-067)

**HP by level** (`BuildBalance`: `fence_hp[]`, cost = `fence_cost × level_cost_mult^(level−1)`)

| Level | HP | Cost to reach |
|---|---|---|
| 1 | 120 | 20 |
| 2 | 200 | 40 |
| 3 | 320 | 80 |

- **Rubble** (hp ≤ 0): blocks nothing. It keeps its level until dawn, when it resets to level 0.
- **Visual:** a brown bar. Rubble is the same bar flattened.

### 7.7 Diner

- `diner_max_hp` (`BuildBalance`, 300), stored in `GameState.diner_hp`.
- At 0, GameState emits `diner_fell` once per night.

### 7.8 Steaks and pickup (D-008, D-009, D-023)

- Ground steaks come from the pool. The hero's `Magnet` (`magnet_radius`, 1.5 m) picks one up while
  `carried_steaks < carry_capacity` (6), through `GameState.pick_steak()`.
- Steaks that don't fit stay on the ground until dawn or close-up, when they go to the freezer.
- Night pickup has no bonus. It is a playtest question (section 15).

### 7.9 Night HUD

- **Moons:** 3 icons. One fills on each `wave_cleared`.
- **Edge arrows:**
  - Big for the main lane, small for the side lane.
  - Shown from the start of the breather (or NIGHT start) until that wave's last spawn.
  - Pinned to the screen edge when the lane entrance is off-screen; otherwise hovering over the
    entrance.
- **Diner HP bar:** slim, at the top. It shakes when the diner is hit.

---

## 8. Day systems

### 8.1 Stand-still (D-006, D-070)

- Standing still means hero speed < `stand_still_speed` (0.1 m/s) for `stand_still_time` (0.25 s) inside a `StationZone`.
- **Arming (D-121):** a zone works only after the hero **walks into** its radius while the zone is active. A hero who is already inside when the zone activates (a phase change), or who is teleported in (a restore or new game), must leave and re-enter first. The zone disarms on `phase_changed`, on `state_restored` and on any hero teleport.
- While the hero stands, the zone fires `ticked` every `transfer_tick` (0.08 s).
- **State changes on the tick. Tweens are visual only** (D-096).
- A shared progress-ring shader quad shows the progress (D-073).

### 8.2 Freezer

- On each tick: if `freezer_steaks > 0` and `carried < carry_capacity`, `move_freezer_to_carry(1)`.
- Visual: up to 10 steaks stacked, plus a count label beyond that.

### 8.3 Counter

- The hero's drop zone is at (2.2, 4.8). On each tick: if `carried > 0` and `counter < counter_capacity` (12),
  `move_carry_to_counter(1)`.
- Visual: up to `counter_capacity` steaks on the counter.

### 8.4 Travelers (D-010, D-064, D-045)

- **Owner:** `world/traveler_spawner.gd` plus `actors/traveler/`.
- **Spawning:** while in DAY and the queue holds fewer than `queue_max` (4), one spawns every
  `traveler_interval` ± `traveler_jitter` (2.5 s ± 0.5 s, `travelers` stream).
- **Behavior:**
  - Each wants `traveler_want_min`–`traveler_want_max` (1–2) steaks (`travelers` stream) and walks at
    `traveler_speed` (2.5 m/s) to the last free queue slot.
  - The queue advances as slots free up.
  - At the service point, the front traveler waits `service_time` (1.0 s), then atomically calls
    `GameState.sell_from_counter(n)` with `n = min(want, counter)`. That removes `n` steaks, adds
    `n × gold_per_steak` (3) to `gold_pile`, and emits `steak_sold`.
  - If the counter is empty, it waits.
  - After buying, it walks off to (−24, 11) and despawns.
- Travelers never hold reserved steaks. They are not in GameState, so after a restore to DAY the
  queue starts empty.
- **Test:** unit (integration) test of the atomic purchase: no state changes between the service
  start and the transfer.

### 8.5 Gold pile

- Stored in `GameState.gold_pile`, with a visual coin stack of up to 30 plus a label.
- The hero's `Magnet` within `magnet_radius` of (−2.5, 5.5) calls `collect_pile()`, which adds everything to
  `gold` at once. Coin FX fly to the hero.

### 8.6 Build and upgrade (D-007, D-065, D-067)

- **Owner:** `world/build_spots/build_spot.gd`, the base of the tower and fence spots.
- **Inputs:** `GameState.buildings[id]`, `Balance.build`, `GameState.gold`.
- **Outputs:** `building_changed` and `build_completed`.
- **Paying:**
  - While the hero stands in the (armed) spot zone during DAY and `level < max_level` (3), each tick pays
    `min(drain, gold, remaining)` into `paid`.
  - `drain = ceil(cost / drain_divisor)` (20), where `cost = base_cost × level_cost_mult^level` (×2).
  - When `paid == cost`: `level += 1`, `paid = 0`. For a fence, `hp` is set to its new max.
  - `paid` persists across walking away, dawn and the snapshot, except on a destroyed fence, which
    resets to level 0 and `paid` 0 at dawn (7.6).
- **Labels:** a `Label3D` shows the remaining cost, "MAX" at level 3, and one pip per level.
- **Visuals:**
  - The model scales ×1.1 per level.
  - A completed build or upgrade pops (`build_pop_scale` ×1.2, `build_pop_time` 0.2 s).
- **Tests:**
  - Unit (pinned reference at the default Balance): the costs 40/80/160 and 20/40/80, and the drain.
  - Unit (integration): partial pay persists through a snapshot round trip.

### 8.7 Telegraph (D-029, D-093)

- **Owner:** `world/lanes/telegraph_marker.gd`.
- **Inputs:** `GameState.lane_plan`, `state_restored`, `phase_changed`.
- **Rule:**
  - `threat[lane] = Σ over waves (count on that lane × Balance.enemy.hp × hp_mult)`.
  - Marker scale = `lerp(telegraph_scale_min, telegraph_scale_max, threat / max_threat)` (0.5 → 2.0, `UiTuning`).
  - Hidden when the lane's threat is 0. Visible in DAY only.
- **Visual:** a red cone.

### 8.8 Close-up sign and pulse (D-068)

`Pulse.should_pulse(state)` is true when **all** of these hold:
- `freezer_steaks == 0`
- `carried_steaks == 0`
- `counter_steaks == 0`
- `gold_pile == 0`
- for every spot with `level < 3`: `gold < next_level_cost(spot) − spot.paid`

It is re-evaluated on each relevant bus signal. When it is true, the sign pulses (scale 1.0 ↔ `pulse_scale` 1.15,
at `pulse_hz` 1 Hz).

**Test:** a unit test of the predicate, including the cases where a single condition flips it.

### 8.9 Economy check (D-063)

| Night | Kills | Steaks (× `steaks_per_kill` 2) | Gold (× `gold_per_steak` 3) |
|---|---|---|---|
| 1 | 18 | 36 | 108 |
| 2 | 24 | 48 | 144 |

- Night-1 gold covers a tower plus a fence (60) with a margin of 1.8×.
- **Unit test:** `night_gold(1) ≥ economy_margin × (tower_cost + fence_cost)` (1.3), computed from the Balance
  formulas.
- **Sinks:** the one-time total is about 980 gold (2 towers × 280 + 3 fences × 140). Fence rebuilds
  recur. Kills on nights 1–5 yield about 912 gold.

---

## 9. Input, camera, HUD, world UI, feel

### 9.1 Input (D-015, D-070, D-077)

- **Joystick** (`ui/joystick/`):
  - A touch anywhere spawns the base under the thumb.
  - Knob radius `joystick_radius_px` (64 px at the 720-wide base), `joystick_deadzone` 0.15. Hidden on release.
  - Touches that start within `edge_ignore_px` (16 px) of the left or right screen edge are ignored.
- **Desktop:** mouse drag works the same way, and WASD overrides it when pressed.
- **Routing:** every source calls `HeroInput.set_move(Vector2)`.

### 9.2 Camera (D-071, D-090)

- Perspective, `keep_aspect = KEEP_WIDTH`, horizontal FOV `camera_fov_h` 42°, `camera_pitch` −55°, fixed yaw,
  `camera_distance` 18 m from the hero.
- Follow smoothing `camera_follow_rate` 8/s. The focus is clamped to x ∈ [−17, 17], z ∈ [−20, 8] (`CameraMath`, D-112).
- That gives about 14 m of ground width at the hero, and from about 10 m south to about 28 m north.
- **Shake** when the diner is hit: `shake_amp` 0.12 m for `shake_time` 0.15 s, at most once per `shake_cooldown` 0.5 s.

### 9.3 Viewport (D-072)

A 720×1280 base, stretch mode `canvas_items`, aspect `expand`, portrait orientation.

### 9.4 HUD (`ui/hud/`, a listener only)

- **Top left:** gold. It punch-scales `gold_punch_scale` ×1.25 over `gold_punch_time` 0.12 s when it changes.
- **Top center:** 3 moons at night, "Day N" by day.
- **Under that:** the diner HP bar.
- **Edge arrows:** as in 7.9.
- **Center banners** (`banner_time`, 2.0 s): "The monsters return", "Dawn", "The diner fell".
- **Safe area (D-077):** the HUD `CanvasLayer` is inset by the safe area, using
  `DisplayServer.get_display_safe_area()`. On web, the fallback reads CSS `env(safe-area-inset-*)`
  through `JavaScriptBridge`.

### 9.5 World UI (D-073, D-079)

- A shared `WorldLabel` scene: a billboard `Label3D` using Nunito.
- A shared progress-ring quad with an arc-fill shader (one `progress` uniform).

### 9.6 Feel budget (D-078)

All of it uses tweens, with no new assets and no audio.
- Every steak and coin transfer flies on an arc (`transfer_arc_time` 0.15 s, `transfer_arc_apex` 0.6 m).
- The gold number punches.
- The camera shakes.
- Builds pop.
- Enemies flash when hit and scale down when they die.

### 9.7 Text and font (D-074, D-079)

- Nunito (OFL) is the Theme font and the `WorldLabel` font. Its license line goes in
  `docs/ASSET_LICENSES.md`, the single license file for the project.
- **Glyph test:** `font.has_char()` holds for every character of "Quán ăn mở cửa — Đêm thứ 3".

### 9.8 Placeholder look (D-016, D-075)

- Every object is a primitive mesh with a flat material.
- One DirectionalLight, **no real-time shadows**.

| Object | Look |
|---|---|
| Hero | blue capsule with a white "hat" box |
| Boar | red capsule |
| Traveler | gray capsule |
| Diner | beige 8×8×3 box |
| Counter | brown box |
| Freezer | cyan box |
| Steak | small brown box |
| Coin | yellow cylinder |
| Tower | gray cylinder |
| Fence | brown bar |
| Rubble | flat bar |
| Telegraph | red cone |

- Each scene keeps a `Visual` child as the S4 swap point.
- **Stacks drawn:** hero up to `carry_capacity` (6), counter `counter_capacity` (12), freezer 10 (plus a label beyond that), coins 30.

---

## 10. Web shell, focus, export presets, tooling

### 10.1 Web shell (`export/web_shell.html`, D-077)

- `touch-action: none` and `overscroll-behavior: none` on `html`, `body` and the canvas.
- `user-select: none` and `-webkit-touch-callout: none`.
- `contextmenu` is prevented.
- The viewport meta is
  `width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover`.
- The result: no pull-to-refresh, pinch zoom, double-tap zoom, long-press selection or context menu.

### 10.2 Focus pause (D-046)

- `FocusPause` sets `get_tree().paused = true` on `NOTIFICATION_APPLICATION_FOCUS_OUT` and on a web
  `visibilitychange` to hidden (a `JavaScriptBridge` listener). It resumes on focus in or visible.
- **Test:** unit (integration), sending the notification and asserting that the tree pauses and
  the physics frame count stops advancing.

### 10.3 Export presets (D-047, D-084, D-099)

| Preset | Optimizations | `ui/debug/*` | Overlay | Use |
|---|---|---|---|---|
| `debug` | debug template | included | debug overlay (seed, day, phase, wave, alive enemies, fps, pool warnings) plus hotkeys | development |
| `profile` | release template | excluded | perf overlay only (fps, frame time); feature tag `profile_overlay` | criterion 4 |
| `release` | release template | excluded | none | GitHub Pages builds (D-135) |

- **Debug hotkeys:** +100 gold, skip to DAY, skip to NIGHT, kill all, force diner fall.
- The debug overlay is loaded with `load()` only when `OS.is_debug_build()`. It is never
  preloaded.

---

## 11. Pools (D-017, D-061)

| Pool | Prewarm |
|---|---|
| Enemy | `max_wave_size + 10` = 40 |
| Ground steak | 173, which is `ceil((17 + 25 + 30) × steaks_per_kill × 1.2)` from the **capped** day-10 counts (D-124) |
| Projectile | 24 |
| Fx (coins and steaks in flight) | 32 |
| Traveler | `queue_max × 2` = 8 |

A pool that grows at runtime logs a warning and shows it on the debug overlay.

---

## 12. Balance (starting values; the sims tune them)

`balance/balance.tres` is a `BalanceData` with typed sub-resources (D-033):

- **HeroBalance**

  | Field | Value |
  |---|---|
  | `move_speed` | 5.0 |
  | `attack_damage` | 10 |
  | `attack_interval` | 0.5 |
  | `attack_range` | 4.0 |
  | `retarget_interval` | 0.2 |
  | `moving_attack_speed_mult` | 1.0 |
  | `projectile_speed` | 14 |
  | `magnet_radius` | 1.5 |
  | `carry_capacity` | 6 |

- **EnemyBalance** (Boar)

  | Field | Value |
  |---|---|
  | `hp` | 30 |
  | `speed` | 2.0 |
  | `damage` | 5 |
  | `attack_interval` | 1.0 |
  | `reach` | 1.2 |
  | `lateral_spread` | 1.0 |
  | `drop_scatter` | 0.6 |
  | `offset_fade_distance` | 3.0 (D-111) |

- **WaveBalance**

  | Field | Value |
  |---|---|
  | `base_counts` | [4, 6, 8] |
  | `count_growth` | 0.35 |
  | `hp_growth` | 0.15 |
  | `max_wave_size` | 30 |
  | `spawn_interval` | 0.8 |
  | `first_wave_delay` | 5.0 |
  | `breather` | 10.0 |
  | `side_share_base` | 0.20 |
  | `side_share_step` | 0.05 |
  | `side_share_cap` | 0.45 |
  | `side_group_delay` | 4.0 |

  Also `target_priority`, a `TargetPriority` resource set to `[fence_on_lane, diner]`.

- **EconomyBalance**

  | Field | Value |
  |---|---|
  | `steaks_per_kill` | 2 |
  | `gold_per_steak` | 3 |
  | `counter_capacity` | 12 |
  | `transfer_tick` | 0.08 |
  | `stand_still_speed` | 0.1 |
  | `stand_still_time` | 0.25 |
  | `closeup_hold` | 1.0 |
  | `traveler_interval` | 2.5 |
  | `traveler_jitter` | 0.5 |
  | `queue_max` | 4 |
  | `traveler_want_min` | 1 |
  | `traveler_want_max` | 2 |
  | `service_time` | 1.0 |
  | `traveler_speed` | 2.5 |
  | `economy_margin` | 1.3 |

- **BuildBalance**

  | Field | Value |
  |---|---|
  | `tower_cost` | 40 |
  | `fence_cost` | 20 |
  | `level_cost_mult` | 2.0 |
  | `max_level` | 3 |
  | `drain_divisor` | 20 |
  | `tower_damage` | [8, 12, 18] |
  | `tower_range` | [7.0, 7.5, 8.0] |
  | `tower_interval` | 0.5 |
  | `tower_projectile_speed` | 16 |
  | `fence_hp` | [120, 200, 320] |
  | `diner_max_hp` | 300 |

- **SimThresholds**

  | Field | Value |
  |---|---|
  | `night1_win_min` | 0.50 |
  | `night2_unaided_max` | 0.30 |
  | `night2_comfort_min` | 0.60 |
  | `first_combat_max_s` | 30 |
  | `sim_suite_budget_s` | 60 |

`balance/ui_tuning.tres` is a `UiTuning` resource:

| Group | Fields |
|---|---|
| Joystick | `joystick_radius_px` 64, `joystick_deadzone` 0.15, `edge_ignore_px` 16 |
| Camera | `camera_fov_h` 42, `camera_pitch` −55, `camera_distance` 18, `camera_follow_rate` 8 |
| Transfer arc | `transfer_arc_time` 0.15, `transfer_arc_apex` 0.6 |
| Gold punch | `gold_punch_scale` 1.25, `gold_punch_time` 0.12 |
| Diner-hit shake | `shake_amp` 0.12, `shake_time` 0.15, `shake_cooldown` 0.5 |
| Build pop | `build_pop_scale` 1.2, `build_pop_time` 0.2 |
| Feedback and banners | `hit_flash_time` 0.08, `banner_time` 2.0 |
| Telegraph | `telegraph_scale_min` 0.5, `telegraph_scale_max` 2.0 |
| Sign pulse | `pulse_scale` 1.15, `pulse_hz` 1.0 |

Changing a value in Balance must never need a code change.

---

## 13. Testing

GUT runs headless with `--fixed-fps 60` (D-013, D-035, D-080).

### 13.1 `tests/unit/`: pure `core/`

- **`Rng`:** the same inputs give the same sequence; different streams differ.
- **Grep ban:** no global rand outside `core/rng.gd` (3.6).
- **`LanePlanner`:**
  - day 1 has no side group, and wave 0 is north;
  - from day 2, main ≠ side;
  - at most 2 lanes per wave;
  - the same seed gives the same plan.
- **`WaveMath`:** the reference values in 6.2, the cap-to-HP overflow, and the share curve and its
  cap.
- **`Targeting.select()`:** nearest wins; a tie goes to the lower `spawn_index`.
- **Provider order:** fence before diner; rubble is ignored.
- **Wave-clear edge case (D-044).**
- **`Pulse.should_pulse`** (D-068).
- **Economy check** (8.9); upgrade costs and drain.
- **Geometry tests A′ and B–E** (6.3).

### 13.2 `tests/unit/`: single-scene integration

- **GameState round trip:** `from_dict(to_dict())` is identity.
- **Restore test (D-036, D-045):**
  1. Take a snapshot.
  2. Mutate everything: gold, stocks, levels, paid, fence HP, diner HP, lane plan, and spawn world
     items.
  3. `from_dict(snapshot)`.
  4. Assert that every stateful node's visuals and labels match the snapshot, that no world items
     remain, and that there are **no pending transactions**: no traveler mid-purchase and no
     in-flight steak or coin affecting state.
- **Station transfer rates:** freezer → carry and carry → counter move 1 per 0.08 s, bounded by the
  capacities.
- **Atomic traveler purchase.**
- **Dawn order; close-up order.**
- **Focus pause.**
- **Glyph test.**
- **Camera projection lane-visibility test** (6.4), which also writes the screenshots when it runs
  with a rendering driver.

### 13.3 Sim bots (`actors/bots/`, D-057, D-091)

All bots drive the hero only through `HeroInput`, and move between points on a fixed waypoint graph:
- corners (±6, −6) and (±6.8, 6.8);
- home (0, 9.5) and the sign (0, 8);
- the freezer zone, the counter drop zone and the gold pile;
- the three zone centers;
- the five build spots.

Paths use shortest distance on this graph, with no navmesh.

- **ParkedBot:** walks to home (0, 9.5) and stays there.
- **NaiveBot (night):**
  - Goes to the current wave's main-lane zone center and stays while enemies are in range.
  - Then goes to the zone of the lane with the most live enemies (ties go to the lower lane index:
    west, north, east).
  - Re-decides every 1.0 s. It builds nothing, and by day it walks to the sign and closes up.
- **PlannerBot:** NaiveBot at night. By day:
  1. Haul and sell until freezer, carry and counter are all 0.
  2. Collect the pile.
  3. Spend gold in this order:
     1. A fence on the highest-threat side lane (tonight's plan).
     2. The tower adjacent to that lane.
     3. More fences and any unbuilt tower, by the threat on their lanes (a tower scores its
        higher-threat lane) (D-154).
     4. Upgrades: rank lanes by threat and take the spots next to the top lane, towers before
        fences; if none is affordable, the next lane (D-067, D-154).
  4. Close up.

### 13.4 `tests/sim/` (pass/fail; suite < `sim_suite_budget_s` 60 s headless; thresholds are `SimThresholds`)

| Test | Setup | Pass |
|---|---|---|
| First combat (D-085, D-126) | New game, fixed seed: NaiveBot, and an idle player (no input) at the night-1 start | The first Boar enters hero range at ≤ `first_combat_max_s` (30 s) of game time |
| Night 1, hero alone (D-058) | New game, NaiveBot | Diner HP at dawn ≥ `night1_win_min` (50%) |
| Night 1, negative control (D-056) | New game, ParkedBot | The diner falls |
| Night 2, unaided | Night-2 state after a real night 1 and day 1 with no builds, NaiveBot | ≤ `night2_unaided_max` (30%) or it falls |
| Night 2, planned | PlannerBot plays a real night 1, then a real day 1 (no dev gold), then night 2 | ≥ `night2_comfort_min` (60%) |
| Night-1 fail → restart (D-043) | New game, ParkedBot until the fall | The state equals the new-game snapshot, the phase is NIGHT, and the first spawn is at `first_wave_delay` (5 s) again |
| Determinism (D-028) | The same seed, run twice (NaiveBot, night 1 and night 2) | Identical lane plan, diner HP at dawn, kill count and steak count |

### 13.5 Sweep (manual report, D-059, D-066, D-067)

- `tests/sim/sweep.gd` runs PlannerBot through days 1–10 and writes `tests/sim/out/sweep.csv`
  (gitignored). It keeps going after a fall: it retries, capped at 3 retries per night.
- **Columns:** `day`, `diner_hp_left`, `steaks`, `gold_earned`, `builds` (levels per spot),
  `enemy_count`, `night_seconds`, `day_seconds`, `unspent_gold_at_closeup`, `retries`.
- **Expected:** it breaks around day 4–6. Log the break day in DECISIONS.md as the target for S2
  card power.
- **Target:** `unspent_gold_at_closeup` stays low through day 5.

### 13.6 CI (D-087)

- `.github/workflows/ci.yml` runs on every PR and on pushes to main.
- It downloads Godot 4.7 headless (Linux) and runs the GUT unit and sim suites plus the grep ban.
- Green checks are required before merge. The author sets up branch protection.
- The sweep is not in CI.

---

## 14. Success criteria and definition of done

### 14.1 Success criteria

| # | Criterion | How it's proven |
|---|---|---|
| 1 | Night 1 is winnable by the hero alone | Sim: NaiveBot ≥ 50% |
| 2 | Night 2 is noticeably harder, and 1 tower plus fences makes it comfortable | Sims: NaiveBot ≤ 30% or falls; PlannerBot ≥ 60% |
| 3 | A full cycle takes about 4–6 min for a player who builds | Sweep gives a lower bound; judged at the playtest (D-066) |
| 4 | 60 fps on web on a mid-range phone | `profile` build, night 3, 60 s of combat: average ≥ 58 fps, no frame over 100 ms. Record the phone model. If the phone is clearly high-end, mark it "not validated on mid-range" and carry it as an S6 risk; it does not block S1 (D-084). |
| 5 | Gate to S2 | The author plays 3 cycles on their phone from the GitHub Pages URL and wants a 4th (D-083, D-135) |
| 6 | First combat within 30 s | Sim: ≤ 30 s of game time. Also record the real time from page open to first combat on the phone (D-085). |

### 14.2 Definition of done

1. `CLAUDE.md` exists and matches the layout in 3.1.
2. The unit and sim suites are green headless, locally and in CI, and the grep ban passes. The sim
   suite runs in under 60 s.
3. CI runs on every PR.
4. The sweep has run, and the break day is logged in DECISIONS.md.
5. The `release` web export builds with `export/web_shell.html`, and `ui/debug/*` is absent from
   the `release` and `profile` packs.
6. The release build is deployed to **GitHub Pages** by the `pages` workflow (D-135). The page
   shows the build's git hash, and the game loads and plays on the author's phone from the Pages
   URL.
7. One screenshot per lane is committed under `docs/screenshots/s1/`.
8. Every asset and font has a line in `docs/ASSET_LICENSES.md`.
9. The results section (16) is filled in: the web baseline, criterion 4 with the phone model, the
   first-combat time, and the playtest answers.
10. Plain-http LAN does not work with the 4.7 web build (it needs a secure context, D-120), so
    phone testing uses the HTTPS GitHub Pages URL (D-135).

---

## 15. Playtest questions (answered after the author's 3-cycle session, D-088)

1. Is night pickup worth it? (D-023)
2. After a loss, did you feel you had agency? (D-069)
3. How long did each cycle take?
4. Did the side lanes feel readable?
5. Did you know what to do next without being told?
6. At which moment did you most want to keep playing, and where did it drag?

---

## 16. Results (filled in at the end of S1)

| Item | Value |
|---|---|
| Release build size, compressed as served (wasm + pck) (D-086) | gzip -9: 10,326,534 B (≈ 9.85 MiB: wasm 10,054,769 + pck 271,765; js 68,480 more). Brotli -q 11: 7,171,732 B (for reference; Pages serves gzip, level unknown). Raw: wasm 39,514,754, pck 295,840 (Task 36, commit 0cd6168). |
| Phone load time (page open → playable) | Deferred to the final review (D-159), so it will be measured on the post-S5 build and there is no pre-S4 phone baseline. For information only: the iOS Simulator (Safari, localhost, cache state unknown) showed the HUD about 5.2 s after `simctl openurl`. Localhost has no network transfer of the 10.3 MB payload, so this is not comparable to a phone load time. |
| Page open → first combat, on the phone (D-085) | Deferred to the final review (D-159). |
| Criterion 4: phone model, average fps, worst frame (profile build) | Deferred to the final review (D-159). For information only (`web_profile` from localhost, no input):
- iOS Simulator: avg 58.4 fps, worst 143 ms, the rolling 60 s window read at about 80 s (night 1 combat).
- Pixel 7 **emulated** (software WebGL): avg 7.8, worst 150 ms, over the first 60 s from engine start (startup, dusk and night 1).
- Desktop Chrome with software WebGL: avg 16.4, worst 147 ms, over the same window.

None of these is criterion 4: the Simulator renders on the host GPU. Against D-159's quality gate (Simulator ≥ 58 fps at night 3 with the final art), this night-1 reading with placeholder art leaves 0.4 fps of headroom.

A ~145 ms worst frame appears in all three runs, cause not identified. The iOS window excludes the first ~20 s, so it is not only startup. A first-combat shader compile is a candidate; S5 checks it. |
| Sweep break day | Day 8 (D-155, D-160). |
| Playtest answers 1–6 | |
| Gate verdict (criterion 5) | |

---

## 17. Suggested build order (a hint for writing-plans, not tasks)

1. Walking skeleton: autoloads, PhaseController, the empty map.
2. Pure core modules with their tests.
3. The headless night loop.
4. Sim bots and night sims.
5. Day stations and travelers.
6. Economy and upgrades.
7. Snapshot and restore.
8. Input, camera and HUD.
9. Web shell and export presets.
10. CI.
11. Sim-driven balance tuning.
12. The perf check.
13. The gate playtest from the GitHub Pages URL.

---

## 18. Risks

1. **The balance targets pull against each other.**
   - Night 1 needs NaiveBot ≥ 50%, night 2 needs NaiveBot ≤ 30%, and night 2 with PlannerBot needs
     ≥ 60%, all from one set of numbers.
   - The side group may need a larger night-2 share or faster side enemies.
   - Fixes go into the numbers, not the design. There is no timebox (D-131): escalate when the two
     must-hold targets conflict or 3 tuning rounds make no progress (D-103).
2. **Godot 4.7 unknowns:**
   - GUT compatibility (gdUnit4 is the fallback);
   - `--fixed-fps` behavior;
   - web safe-area reporting;
   - single-threaded web performance and plain-http LAN.

   All must be verified at the start of the plan.
3. **Hero physics and determinism:** the hero's `move_and_slide` may differ across platforms (CI
   Linux versus macOS). The determinism test compares runs on the same machine, and the threshold
   sims must pass on both.
4. **Mobile web performance and load time** under the Compatibility renderer, on a phone that may
   not be mid-range.
5. **The fun gate may fail for the wrong reasons:** placeholder art, no audio and no onboarding.
   The feel budget (9.6) mitigates it, and playtest question 5 sizes S5.

---

## Appendix A: Post-v0.1 ideas (not in v0.1)

- All 3 lanes active per wave (D-026).
- Refunds or respec of builds after a loss (D-069).
- Fence relocation (D-029).
- From IDEA "Later": mobile apps, ads, IAP, gacha; Mage, Chef and follower heroes; moving guards;
  extra waves; spoilage; offline earnings; a second resource; a second map; bosses; cloud save;
  localization.

## Appendix B: Verify at the start of the plan

| Item | Fallback |
|---|---|
| GUT supports Godot 4.7 | gdUnit4 |
| `--fixed-fps 60` headless runs unthrottled with a fixed delta | `Engine.time_scale` plus raised `max_physics_steps_per_frame` |
| `DisplayServer.get_display_safe_area()` on web | CSS `env()` through `JavaScriptBridge` |
| The single-threaded web export works over plain-http LAN | HTTPS GitHub Pages URL for phone tests (D-135) |
| Headless camera projection works without a rendering driver; screenshots need one | Screenshots are taken in a separate, non-headless run |
