# S2 Hero Cards + Adventurer Guards: Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`). This builds on the S1 spec
  (`2026-09-30-s1-vertical-slice-design.md`), whose conventions, architecture and rules all still apply.
- **Status:** written autonomously under D-159. The main session answered every brainstorming question from IDEA.md,
  the three pillars, DECISIONS.md and the S1 sweep data. A reviewer pass replaces the author's approval. Reversible
  player-facing calls are listed in `docs/REVIEW_QUEUE.md`.
- **Decision log:** `docs/DECISIONS.md` (D-161 to D-170, logged with this spec).

---

## 1. Goal and success criteria

S2 fills the dawn `CARD_PICK` stub with IDEA.md's hero cards and adds the two adventurer guards.

It is done when:
1. Every dawn offers up to 3 cards and the player picks one with a tap (or 1/2/3 on desktop). The pick is permanent
   and shapes the next night.
2. The 5 upgrade cards change the hero and the economy exactly as specified (§4.2), and stack up to level 5.
3. The Archer and the Tank join, stand at their fixed posts (§6.1), fight, level up on duplicates, and the Tank can be
   knocked out and respawn at the diner door after 3 s.
4. Enemy targeting is `fence_on_lane → guard → diner`, with no change to how enemies move (they stay on their lanes).
5. The sims hold every S1 threshold with cards in play (§10.3). The PlannerBot sweep, with its card policy, breaks
   at **day 10 ± 1** (D-170). The sweep re-runs after every balance change.
6. Unit, sim and CI are green, and every task passes a reviewer.

## 2. Scope

**In:** the card catalog (7 types), offers, the pick overlay, card effects, the card strip on the HUD, the Archer,
the Tank, guard targeting, knockout and respawn, dawn healing for guards, bot card policies, sweep columns, the wave
re-tune, snapshot schema v2.

**Out:**
- disk save, resume into `CARD_PICK`, and mercy (S3);
- card art, guard models and animations (S4; placeholder shapes and colors now);
- pick sounds and juice beyond a pop and a banner (S5).
- From IDEA "Later": Mage, Chef and follower heroes; moving guard heroes.

## 3. Brainstorm answers (autonomous, D-159)

| Question | Answer | Source | D-id |
|---|---|---|---|
| Is the player's hero targeted now that guards exist? | No. Only guards join the target list; the hero keeps no HP. IDEA's "a knocked-out hero respawns at the diner door" refers to guard heroes, since IDEA's targeting list names only "a guard hero in reach". | IDEA Night; D-005 | D-161 |
| How is a card picked? | A tap on one of 3 cards in a full-screen overlay (1/2/3 or a click on desktop). Pillar 2 bans buttons for *core actions*. The pick is a once-a-day decision moment, and the cards need readable text on a phone. | Pillar 2; IDEA Dawn | D-162 |
| Where do the 2 fixed posts go? | The Tank stands on the west lane's center line, 3.0 m before the lane end. The Archer stands on the diner roof, at the north-east. S1 towers already double-cover north (tower_nw: west + north; tower_ne: north + east), so the Tank takes a side lane, and the roof lets the Archer reach all three lane ends. | IDEA Hero cards; D-055 | D-163 |
| What does "guard hero in reach" mean for lane-bound enemies? | A guard is a target when it is within the enemy's reach from the enemy's lane position (reach 1.2 + guard radius). Enemies never leave their lanes (D-003 stands). The Tank on the lane therefore works as a living fence behind the fence. The roof Archer is never in reach. | IDEA Night; D-003 | D-164 |
| How do guards respawn? | A knocked-out guard disappears with a poof. After 3.0 s it appears at `DINER_DOOR` with full HP and walks a fixed path back to its post. At dawn every guard is healed and placed back on its post. | IDEA Night and Dawn | D-165 |
| Which cards are offered? | The first offer (dawn 1) is always Archer + Tank + one seeded upgrade. After that, 3 distinct types are drawn uniformly (seeded) from the types below level 5. Fewer eligible types means fewer cards; none means no pick. | IDEA Hero cards | D-166 |
| How big is each upgrade step? | Starting values are in §8. The sweep tunes them. | S1 sweep, D-156 | D-167 |
| Can a pick be undone or rerolled? | No. Picks are permanent, and there are no rerolls in v0.1. | IDEA Hero cards | D-166 |
| Does the game pause during the pick? | No tree pause (nothing is live at dawn). Hero input is blocked from DAWN until DAY. | S1 §5.4 | D-162 |
| What do the bots pick? | NaiveBot: the Archer on dawn 1 (the strongest unaided pick, which makes the night-2 check the worst case), then the leftmost card. PlannerBot: a fixed preference order (§10.1). | S1 §13.3 | D-168 |
| What is the target break day with cards? | PlannerBot sweep breaks at day 10 ± 1. The S1 break day without cards was 8 (D-160). Humans play worse than the bot and get S3 mercy. | D-155, D-156, D-160 | D-170 |

## 4. Cards

### 4.1 Catalog (`core/card_catalog.gd`, static, pure)

| id | kind | name (tr key) | effect per level L (1..5) |
|---|---|---|---|
| `hero_damage` | upgrade | "Sharp Cleaver" | hero damage × (1 + `damage_step` · L) |
| `attack_speed` | upgrade | "Quick Hands" | hero attack interval ÷ (1 + `attack_speed_step` · L) |
| `move_speed` | upgrade | "Running Shoes" | hero move speed × (1 + `move_step` · L) |
| `carry_capacity` | upgrade | "Big Backpack" | carry capacity + `carry_step` · L |
| `gold_per_steak` | upgrade | "Fancy Menu" | gold per steak + `gold_step` · L |
| `archer` | adventurer | "Archer" | guard at the roof post, stats at level L (§6.3) |
| `tank` | adventurer | "Tank" | guard at the west-lane post, stats at level L (§6.3) |

- `CardCatalog.IDS` fixes the order above. That order is also the tie-break order everywhere.
- `CardCatalog.kind(id)`, `CardCatalog.UPGRADES` (the 5 upgrade ids in `IDS` order), and `static func max_level()`,
  which returns `Balance.data.cards.max_level` (5).
- Each card shows: its name, a one-line effect ("+20% hero damage"), and "NEW" for level 0 or "Lv 2 » 3"
  otherwise (Nunito has no U+2192 arrow). All strings go through `tr()`. `test_glyphs` adds "»" to its sample, so Nunito's coverage is checked.

### 4.2 Effects (`core/card_effects.gd`, static, pure; D-167)

Stat functions take the base value, the card levels (`Dictionary[StringName, int]`) and the `CardBalance`, and
return the value in effect:
- `hero_damage(base, levels, cb)`, `hero_attack_interval(base, levels, cb)`, `hero_move_speed(base, levels, cb)`
- `carry_capacity(base, levels, cb) -> int`, `gold_per_steak(base, levels, cb) -> int`
- `guard_stats(id, level, gb) -> Dictionary` with `{max_hp, damage, interval, range}`

The consumers (every read of these base values goes through `CardEffects` with `GameState.cards`):
- **`Hero`** reads move speed every tick, and reconfigures its `Attacker` (damage and interval) on `card_picked` and
  `state_restored`. In S1 the attacker is configured once in `Hero.setup`.
- **`GameState.pick_steak` / `move_freezer_to_carry`** use `CardEffects.carry_capacity`.
- **`GameState.sell_from_counter`** uses `CardEffects.gold_per_steak`.
- **The bots:** `actors/bots/planner_bot.gd` reads the carry capacity to decide when to leave the freezer, and
  `actors/bots/bot_base.gd` (plus `tests/unit/helpers.gd`) derives the arrival step from the move speed. Both use the
  effective values. `test_bots` covers `move_speed` L5 and `carry_capacity` L5.

### 4.3 Offers (`core/card_offer.gd`, static, pure; D-166)

`CardOffer.make(run_seed, day, levels, cb) -> Array[StringName]`:
- It draws from `Rng.stream(run_seed, day, &"cards")` and never uses global rand.
- `day` is `GameState.day` after `advance_day`, so the dawn after night 1 uses day 2.
- **First offer** (no card picked yet: no id has level ≥ 1): `[archer, tank, UPGRADES[rng.randi_range(0, 4)]]`.
- **Otherwise** (this exact algorithm, so every implementation gives the same offers):
  ```
  pool = [id for id in CardCatalog.IDS if levels.get(id, 0) < max_level]
  out = []
  repeat min(offer_size, pool.size()) times:
      out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
  ```
  The display order is `out`.
- An empty result means no pick that dawn.
- `test_card_offer` pins the offers for explicit inputs with one seed: day 2 with `{}`, day 3 with `{tank: 1}`, and
  day 4 with `{tank: 1, <day 3's first id>: 1}`.

## 5. Card pick flow

### 5.1 PhaseController (still within the D-128 whitelist; everything else goes over EventBus)

`_card_pick()` replaces the stub:
1. `offer = CardOffer.make(GameState.run_seed, GameState.day, GameState.cards, Balance.data.cards)`.
2. If the offer is empty: show the "Dawn" banner, set `dawn_substate = ""`, then `_enter_day()`.
3. Otherwise: set `dawn_substate = "CARD_PICK"`, then `GameState.set_card_offer(offer)` (emits `card_offered(offer)`).
   The sub-state is set first, so a listener that picks synchronously is accepted. The controller then waits.
   There is no "Dawn" banner in this case: the pick overlay would cover it, and the pick banner replaces it. This
   overrides S1 §5.4's "Dawn" banner for dawns with an offer.

On `EventBus.card_chosen(id)`:
- It is ignored unless `phase == DAWN`, `dawn_substate == "CARD_PICK"` and `id in GameState.card_offer`.
- Otherwise it calls `GameState.pick_card(id)` (which emits `card_picked(id, new_level)` and clears the offer), sets
  `dawn_substate = ""`, shows the banner (§5.3) and calls `_enter_day()`.

There are no timeouts. DAWN now lasts until the pick.

Resets:
- `start_new_game()` and `_restore_snapshot()` set `dawn_substate = ""`, so a new game or restore during a pick
  never leaves a stale sub-state.
- `debug_skip_to_day()` (and the J key) skips the pick **without granting a card**. From NIGHT it runs dawn and then
  skips the pick; during `CARD_PICK` it skips the pick. Skipping calls `GameState.clear_card_offer()` (no signal), sets
  `dawn_substate = ""` and enters DAY. The 32 existing unit-test call sites keep their meaning.
- Tests that need a pick emit `EventBus.card_chosen(id)` during `CARD_PICK`.

Day label: `phase_changed(DAWN, day)` fires before `advance_day`, so the HUD refreshes its day label on
`card_offered` too, and the offer screen shows the new day.

### 5.2 GameState (schema `v: 2`)

New fields:
- `cards: Dictionary` (StringName → int level; absent means 0)
- `card_offer: Array[StringName]`
- `guards: Dictionary` (StringName → `{hp: float}`). Only **targetable** guards have an entry, which means only the
  Tank; the roof Archer has none and no HP.

`new_game()` clears all three.

New mutators:
- `set_card_offer(offer)` emits `card_offered`; `clear_card_offer()` emits nothing (debug skip only).
- `pick_card(id)`:
  - asserts `id` is in the offer;
  - does `level += 1` and clears the offer;
  - for the Tank: sets `guards[&"tank"].hp` to its max HP at the new level;
  - emits `card_picked(id, level)`.
- `damage_guard(id, amount)`: a no-op if `id` has no entry or its HP is already ≤ 0 (as `damage_fence`). Otherwise
  HP is floored at 0 and it emits `guard_damaged(id, hp_left)`, then `guard_knocked_out(id)` when it reaches 0.
- `revive_guard(id)`: HP goes to max and it emits `guard_revived(id)`.
- `heal_for_dawn()` also sets every guard to its max HP and emits `guard_healed(id, hp)` for each. It runs after
  `phase_changed(DAWN)`, so guards and HP bars refresh HP on `guard_healed`, not on `phase_changed`.

The snapshot:
- `to_dict`/`from_dict` include `cards`, `card_offer` and `guards`, with explicit casts for the JSON round trip.
- `SCHEMA_VERSION = 2`. `from_dict` accepts only 2; S3 owns migrations, and no disk saves exist yet.

### 5.3 EventBus (new signals)

- `card_offered(offer: Array)`
- `card_chosen(card_id: StringName)`: a request from the UI or a bot
- `card_picked(card_id: StringName, level: int)`
- `guard_damaged(guard_id: StringName, hp_left: float)`
- `guard_knocked_out(guard_id: StringName)`
- `guard_revived(guard_id: StringName)`
- `guard_healed(guard_id: StringName, hp: float)`

Pick banners (`tr()`):
- "The Archer joins!" / "The Tank joins!" at level 1;
- "Archer Lv N" / "Tank Lv N" after that;
- "<card name> Lv N" for upgrades.

### 5.4 Card pick overlay (`ui/card_pick/card_pick_overlay.gd`, a CanvasLayer on layer 15, D-162)

- It is shown on `card_offered` (non-empty) and hidden on `card_picked`, on `state_restored`, and on `phase_changed` to
  any phase but DAWN. It starts hidden.
- It has 1–3 card panels in a column, centered in the safe area, each at least 560×220 px at 720×1280. The panel
  shows the name, the effect line and the level line (§4.1), plus a color band by kind: adventurer gold, upgrade
  teal. The heading is "Pick a card" (tr).
- The panel Controls are `MOUSE_FILTER_IGNORE`; the overlay does its own hit-testing.
- **Input** follows the debug fade button's ownership pattern (D-157 review):
  - The overlay's `_input` hit-tests the cached panel rects.
  - It owns a finger that presses on a panel, and picks only when that same finger releases on the same panel. It
    then emits `EventBus.card_chosen(id)` and calls `set_input_as_handled()`.
  - It ignores `DEVICE_ID_EMULATION`.
  - For `input_guard_s` (0.5 s) after it appears, it ignores every press, so a thumb still on the joystick when the
    night ends cannot pick by accident.
  - It clears owned fingers on `NOTIFICATION_PAUSED` (D-147).
  - Desktop keys `1`/`2`/`3` pick the matching panel, after the same guard time.
- While it is visible, `HeroInput` is blocked:
  - `HeroInput.blocked` is set by the Hero on `phase_changed`: blocked in DAWN, unblocked otherwise. The restore
    contract sets it from the resumed phase.
  - `get_move()` checks `blocked` **before** both the keyboard (`Input.get_vector`) path and the joystick/bot
    `_move` path, and returns zero.
  - The joystick reads `blocked` from its input API each frame, ends any active drag and hides its knob while it is
    set.
  - The overlay test covers WASD as well as `set_move`.
- It is added in `Main._ready` after InputLayer, so its `_input` runs before the joystick's (D-139 wiring).

### 5.5 HUD card strip (`ui/hud/card_strip.gd`)

- A row of small chips under the gold label, one per owned card, in `CardCatalog.IDS` order. Each chip shows a
  2-letter glyph ("DM", "AS", "MV", "CA", "GO", "AR", "TK") and its level.
- It listens to `card_picked` and `state_restored`, and is `MOUSE_FILTER_IGNORE`.
- Guard HP bars are world-space: a small `Sprite3D`/`Label3D` bar above each guard, shown while HP is below max.

## 6. Guards

### 6.1 Posts (`MapLayout`, D-163)

- `MapLayout.guard_post(&"tank")`: the west lane's center-line point at `path_length − 3.0` (≈ (-6.60, -2.65)), computed from
  `LANE_PATHS` and pinned in a test.
- `GUARD_POST_ARCHER`: `(2.5, -2.5)`, on the roof at height `DINER_HEIGHT`.
- `DINER_DOOR`: `(-3.0, 4.6)`, on the south wall, west of the counter.
- `MapLayout.tank_return_path()`: `[DINER_DOOR, (-5.0, 4.6), MapLayout.guard_post(&"tank")]`. It must stay clear of the diner box and of the
  tower footprints; a test checks this.
- Geometry guarantees, in `tests/unit/test_geometry.gd`:
  - The Archer's range at level 1 covers all three lane ends, plus the north and east fence stop points.
  - Every west-lane Boar comes within reach of the Tank, at any lateral offset.
  - The Tank is behind the west fence stop point, so a standing fence stops Boars before the Tank does.
  - The Tank's range reaches every Boar held at the west fence stop point, at any lateral offset. That distance is at
    most 2.42 m, and the Tank's range is 2.5, so the Tank fights over its fence instead of idling behind it.
  - Tank range ≥ `Balance.data.enemy.reach` + Tank `body_radius`, so it can always hit a Boar that is hitting it.
- Accepted gap: the Archer (range 9) doesn't reach Boars held at the Tank (9.0–10.6 m). The west lane is the Tank's side,
  covered by the Tank, `tower_nw` and the hero.

### 6.2 Guard actor (`actors/guards/guard.gd`, plus data per id)

**Components:** `Attacker`. HP lives in `GameState.guards`. Targeting goes through `GuardRoster.guard_target`, so guards carry no `Targetable` component.
Guards have no collision with the hero (as towers, D-125). The Tank's post is 1.0 m from `fence_w`, inside its 1.2 m
build zone. The visual overlap is accepted, and building there still works because build zones track the hero only.

**States:**
- `POSTED`: at its post, attacking.
- `DOWN`: hidden, respawn timer running. It is a physics-process timer, so it pauses with the tree.
- `RETURNING`: walks `TANK_RETURN_PATH` from the door at `walk_speed` and attacks while walking. The roof Archer is
  never `DOWN`.

**Attacking:**
- `Attacker.candidates` are the WaveDirector's enemy candidates (as for towers).
- The Archer fires projectiles. The Tank's hits are melee: the same `Attacker` with a very fast projectile, so no
  new code path (§8).

**Lifecycle:**
- On `guard_knocked_out` it plays a poof and goes `DOWN` for `respawn_s` (3.0).
- When the timer ends: `GameState.revive_guard(id)`, teleport to `DINER_DOOR`, and go `RETURNING`.
- On `phase_changed(DAWN)` and `state_restored` it goes straight to `POSTED` at its post, clearing any timer. It
  takes its HP from `guard_healed` (at dawn) or from `GameState` (on restore).
- `card_picked` for its id reconfigures its stats from `CardEffects.guard_stats`, and re-reads HP and max HP (a Tank
  level-up sets HP to the new max). HP bars do the same.

### 6.3 Guard roster (`world/guard_roster.gd`, owned by World; a D-139 wiring note)

- It spawns a Guard when `GameState.cards[id]` first becomes ≥ 1, on `card_picked` or `state_restored`, and frees
  guards that are absent after a restore.
- **Pops in:** the Archer appears on the roof post with a poof. The Tank appears at `DINER_DOOR` and walks to its
  post.
- It registers the `guard` target provider with `WaveDirector.providers` in `setup()` (§7).
- **D-139 wiring notes** (the main session applies them):
  - `world/world.gd` creates the roster and adds the guards to `_occluder_targets`, so the diner fades when it
    hides the Tank;
  - `world/main.gd` adds the pick overlay after InputLayer;
  - `autoload/EventBus.gd` and `autoload/GameState.gd`;
  - `balance/balance_data.gd`, `balance/target_priority.gd` (default kinds), `balance/sim_thresholds.gd` and
    `balance/ui_tuning.gd`, plus the new `card_balance.gd` and `guard_balance.gd`.

## 7. Targeting (D-164)

- `TargetPriority.kinds` = `[&"fence_on_lane", &"guard", &"diner"]`.
- **The `guard` provider** (a roster function) receives the enemy and returns the first guard that is:
  - alive and not `DOWN`;
  - `targetable` (ground guards only);
  - within `enemy.reach + guard.body_radius`, measured in XZ from the enemy's current position.
  It returns `{kind: &"guard", guard_id}`, or `{}` if none. Ties go to the lowest `CardCatalog.IDS` index.
- The reach is `Balance.data.enemy.reach` (Boar has no member of its own).
- **Boar** gets one `match` arm: `&"guard"` → `GameState.damage_guard(guard_id, Balance.data.enemy.damage)`, on the
  same `attack_interval` as the fence and diner arms.
  - Movement doesn't change. A Boar with a target stops advancing; with `{}` it walks on. So the Tank stops west Boars
    the way a fence does, and when the Tank goes down they walk on toward the diner.
  - This is the one edit to enemy code. It replaces the S1 note that claimed Boar needed no change; the stale comment
    in `world/target_providers.gd:4` is updated too.
- When a guard goes `DOWN`, the provider stops returning it. The Boar re-queries every tick (S1 behaviour).

## 8. Balance (new resources; starting values that the sims tune)

`CardBalance` (`balance/card_balance.gd`, in `BalanceData.cards`):

| field | value |
|---|---|
| `max_level` | 5 |
| `offer_size` | 3 |
| `damage_step` | 0.20 |
| `attack_speed_step` | 0.15 |
| `move_step` | 0.08 |
| `carry_step` | 2 |
| `gold_step` | 1 |

`GuardBalance` (`balance/guard_balance.gd`, in `BalanceData.guards`) holds two `GuardStats` resources
(`balance/guard_stats.gd`): `@export var archer: GuardStats = _archer()` and `@export var tank: GuardStats =
_tank()`. Both are built by static initializer functions (D-157 applies: export keeps `.tres` as text).

| field | Archer | Tank |
|---|---|---|
| `max_hp` (L1) | — (never targeted) | 160 |
| `hp_growth` per level | — | 0.35 |
| `damage` (L1) | 6 | 5 |
| `damage_growth` per level | 0.30 | 0.25 |
| `interval` | 0.6 | 0.8 |
| `attack_range` | 9.0 | 2.5 |
| `projectile_speed` | 16 | 60 (melee) |
| `body_radius` | 0.4 | 0.45 |
| `walk_speed` | — | 3.0 |
| `respawn_s` | — | 3.0 |

- A stat at level L is `base × (1 + growth × (L − 1))`.
- `UiTuning` adds `card_input_guard_s` 0.5, `card_panel_size` (560, 220), `card_panel_gap` 24.0 and `card_panel_min_h` 120.0.
- `SimThresholds` adds `break_day_target` 10 and `break_day_tolerance` 1. These are reported by the sweep; the sweep
  stays a manual report, not an assertion.

## 9. Snapshot and restore

- Close-up snapshots include `cards`, `card_offer` (always empty at close-up) and `guards`.
- A failed night restores the cards picked earlier, including that dawn's pick, because it happened before the
  close-up.
- The restore contract (S1 §4.2) is extended:
  - guards rebuild from `GameState` on `state_restored`;
  - the overlay hides;
  - `HeroInput.blocked` follows the resumed phase;
  - the Hero's attacker is reconfigured.
- `tests/unit/test_restore_world.gd` gains a case with cards and a knocked-out Tank.

## 10. Sims, bots and tuning

### 10.1 Bot card policies (D-168)

- Bots pick through `EventBus.card_chosen`, on `card_offered`, one physics tick later (D-118).
- **NaiveBot:** `archer` if it is offered, otherwise the leftmost card.
- **PlannerBot:** the first card in its offer by this preference order: `tank`, `archer`, `hero_damage`,
  `attack_speed`, `gold_per_steak`, `carry_capacity`, `move_speed`.
  - The Tank comes first because its post lies on a lane that has only one tower.
  - The order is a bot constant, not a balance value.
- **ParkedBot:** leftmost.

### 10.2 Harness and sweep

- `SimHarness` tolerates a DAWN that lasts until the pick.
- The sweep runs days 1–14, with the same retry and stall rules. New columns:
  - `cards` (e.g. `archer:1|tank:2|hero_damage:1`)
  - `guard_knockouts`
  - `picked`

### 10.3 Thresholds and the tuning pass (D-169, D-170)

Targets, in precedence order (D-169):
1. **Must hold:** night 1 NaiveBot ≥ 0.50. There are no cards yet.
2. **Must hold:** night 2 PlannerBot, with its dawn-1 pick (the Tank), ≥ 0.60.
3. **Sweep target:** the PlannerBot breaks at day 10 ± 1, with unspent gold at close-up under one tower's cost per
   day through day 5 (as in S1).
4. **Night 2 NaiveBot, with the Archer, ≤ 0.30.** It may relax to ≤ 0.45, which must be logged.

Knobs:
- For target 4, first: Archer L1 `damage`, then `range`. The range floor is about 8.65, because the north fence stop
  is 8.64 m away (§6.1). The PlannerBot picks
  the Tank on dawn 1, so these don't move target 2.
- For target 3: `count_growth` and `hp_growth` (both also move targets 2 and 4), then Tank stats, then card steps,
  then `side_share_*`.

Every round is one knob change, then the sims and the sweep. Stop and escalate (D-103, D-159) after 3 rounds with no
progress, or when targets conflict: 1 vs 2; 3 vs 1 or 2; or 4, even at ≤ 0.45, vs 3.

## 11. Testing

`tests/unit/`:
- `test_card_catalog` (ids, kinds, max level)
- `test_card_effects` (every stat at L0..5, pinned)
- `test_card_offer`:
  - the first-offer rule;
  - distinct, eligible-only types;
  - fewer than 3 when few are eligible, empty when all are maxed;
  - determinism per seed and day;
  - no global rand
- `test_game_state` additions:
  - pick, level cap, Tank HP (no Archer entry), damage, knockout once, the no-op after knockout, revive;
  - dawn heal with `guard_healed`;
  - `new_game` clears cards, offer and guards;
  - JSON round trip v2
- `test_phase_controller` additions:
  - dawn waits in `CARD_PICK`;
  - invalid, stale and duplicate choices are ignored;
  - an empty offer skips;
  - `debug_skip_to_day` grants no card;
  - `dawn_substate` resets on new game and restore;
  - the D-128 whitelist still passes
- `test_card_pick_overlay`:
  - panels match the offer;
  - tap-release on the same panel picks;
  - press on one panel and release on another does nothing;
  - after `debug_skip_to_day` the overlay is hidden, and a press on a former panel rect reaches the joystick;
  - the input guard;
  - keys 1/2/3;
  - a joystick finger released over a panel is not swallowed;
  - the hero is blocked during the pick
- `test_card_strip`
- `test_guards`:
  - spawn on pick;
  - the Archer kills from the roof and is never targeted;
  - the Tank stops west Boars and takes damage;
  - knockout, then respawn after 3 s at the door, then return to post;
  - dawn heal and post;
  - level-up reconfigures;
  - restore rebuilds
- `test_boar`: the guard arm, and the priority order fence → guard → diner
- `test_geometry` additions (§6.1)
- `test_hero` additions: card stats applied, including after a restore
- `test_bots` additions: the PlannerBot's freezer run and the arrival step use the effective carry capacity and move
  speed (L5 cases)
- `test_hud`: the day label refreshes on `card_offered`

`tests/sim/`:
- Existing tests adapt to the pick: the bots pick.
- The existing night-2 tests are extended with the §10.3 checks (not duplicated), and `GameState.cards` is added to
  the determinism tuple, so the suite stays within budget.

The sim suite stays under 60 s (D-132).

## 12. Build order (a hint for writing-plans)

Phase branches are `s2/p<N>-<slug>`, one PR per phase, all self-merged under D-137/D-159.
1. Pure core: catalog, effects, offer, and their tests.
2. GameState v2 plus EventBus signals.
3. PhaseController pick flow plus bot policies plus harness.
4. Hero card effects.
5. Pick overlay plus card strip (with an iOS Simulator screenshot self-review).
6. Guards: actor, roster, posts, targeting, Boar arm, geometry tests.
7. Restore extensions.
8. Sweep columns and the tuning pass (sims plus sweep, D-170).
9. Results: sims, the sweep, a screenshot per lane with guards, and review-queue entries.

## 13. Risks

- **Tank-as-fence stacking.** Boars queue on one spot at the Tank, the same visual as fences. Accepted for v0.1; S5
  juice may spread them.
- **The gold card inflates the economy** past the build sinks (max level 3). The sweep watches unspent gold. If it
  piles up, lower `gold_step`, and log it.
- **Roof Archer plus the occluder fade:** the Archer is above the diner and never hidden, but a screenshot
  self-review checks this.
- **A pick UI tap vs the joystick:** covered by the ownership pattern and the input guard, and tested.

## 14. Playtest questions added for the final review

1. Did you understand what each card did before you picked it?
2. Did any pick feel wasted or useless?
3. Did the Archer and the Tank feel like part of your defense?
4. When the Tank went down and came back, did you notice, and did it make sense?

## Appendix: Post-v0.1 ideas (not in v0.1)

- Card rerolls; card rarity.
- Guard post choice (the player moves a guard between posts).
- A hero HP and knockout for the player's own hero.

## 15. Results (S2, filled in at the end of S2)

| Item | Value |
|---|---|
| Tests | unit 393, sim 8, sim suite about 6 s (budget 60 s) |
| Sim targets (seed 20260930) | night 1 NaiveBot 0.667 (≥ 0.50); night 2 PlannerBot with the Tank 1.000 (≥ 0.60); night 2 NaiveBot with the Archer 0.300 (≤ 0.30) |
| Sweep break day | 10 / 11 / 10 on seeds 20260930 / 11 / 777 (target 10 ± 1, D-170, D-180) |
| Unspent gold through day 5 | at most 38 on every seed (under one tower, 40) |
| Balance changes | Archer L1 damage 6.0 → 4.0 (D-179); none in the tuning pass (D-180) |
| Known spread | seed 777: night 2 PlannerBot ends at 0.517 (cleared); late-game gold has no sink from about day 7 (REVIEW_QUEUE) |
| Screenshots | `docs/screenshots/s2/lane_west.png`, `lane_north.png`, `lane_east.png`, `card_pick.png`, `guards_night1.png` |
| Simulator self-reviews | card pick (preview s2-p3-pick-ui), guards (preview s2-p4-guards): pass |

Capture commands (with rendering, 720×1280):
- lane shots: `-- --lane=<west|north|east> --cards=archer:1,tank:1 --seconds=4`
- `card_pick.png`: `-- --scene=cardpick --cards=archer:1,tank:1 --seconds=4`
- `guards_night1.png`: `-- --cards=archer:2,tank:2 --seconds=3`

Notes for later sub-projects:
- The HUD card strip sits close under the diner bar (S5 polish).
- The Archer's roof post is off-screen when the camera frames the west lane on a narrow phone (S4 art pass or a camera-focus tweak).
- Level text uses "»" because Nunito has no "→".
