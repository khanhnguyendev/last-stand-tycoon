# S3 Save/Load + Failure & Mercy: Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`). This builds on the S1 spec
  (`2026-09-30-s1-vertical-slice-design.md`) and the S2 spec (`2026-09-30-s2-hero-cards-guards-design.md`). Their
  conventions, architecture and rules still apply.
- **Precondition:** S2 is merged: GameState v2, the `CARD_PICK` sub-state, card offers, the debug URL scenes and the
  guards.
- **Status:** written autonomously under D-159. The main session answered every brainstorming question from IDEA.md,
  the pillars, DECISIONS.md and the S1/S2 work. A reviewer pass replaces the author's approval.
- **Decision log:** `docs/DECISIONS.md` D-171 to D-178, amended after the spec review.

---

## 1. Goal and success criteria

S3 makes a run survive closing the tab, and makes failure gentle, as IDEA.md says:
1. One local save in the browser, plus a backup. It is written automatically at night start, at dawn, after the card
   pick, after each build, and every few seconds during the day when something changed. At most the current night and
   a few seconds of the day can be lost.
2. Reopening the page resumes the run with no menu: at the day's sign, at the open card pick, or at night 1's start.
3. **Failure:** the diner falls, the night ends, and the game reloads the start of that night, back in the day. This
   is already true in S1/S2. **Quitting mid-night costs exactly the same:** the night is lost and play resumes at the
   same restore point.
4. **Mercy:** each failed retry of the same night makes enemies weaker. HP and damage drop 15% per failure, with a
   floor of 40%. It shows only as a flavor line: "The monsters look tired tonight."
5. A corrupt, missing or newer-version save never crashes the game, and a newer-version save is never overwritten.
6. Unit, sim and CI stay green, every task passes a reviewer, and the sweep reports the break day.

## 2. Scope

**In:**
- A `SaveStore` with a web `localStorage` backend (per deployment path) and a `user://` file backend for desktop and
  tests.
- The save envelope (checksum over the state text) and primary/backup rotation.
- Autosave triggers.
- Resume on boot.
- Mercy and its flavor line.
- A HUD banner queue.
- Sim and sweep updates.

**Out:**
- Cloud save (IDEA "Later").
- A settings or "New game" UI (S5; debug builds get a key and a URL flag).
- Offline earnings (IDEA "Later").
- Save slots.

## 3. Brainstorm answers (autonomous, D-159)

| Question | Answer | Source | D-id |
|---|---|---|---|
| Where does the web save live? | In `localStorage` through `JavaScriptBridge`, under keys prefixed with the deployment path (`location.pathname`), so each GitHub Pages build (`/`, `preview/<slug>/`, `debug/`) keeps its own save. `localStorage` is synchronous, and a save is a few KB. Godot's `user://` on web is IndexedDB with an asynchronous sync, which can lose the last write on close. Desktop, the editor and tests use `user://save/` (temp file, then rename). | IDEA Save; D-135 | D-171 |
| What is saved? | An envelope `{format: 1, saved_at_unix, build, state_json, check}`. `state_json` is `JSON.stringify(GameState.to_dict(), "", true, true)` (D-146), with `resume_phase` set by the writer. `check` is FNV-1a 32 over `state_json`, so the check runs on the raw string before parsing (a JSON round trip changes number formatting). | D-022, D-146 | D-172 |
| Backup rule? | Each write copies the last successfully written text (kept in memory, or read and validated once at boot) to the backup key, then writes the primary. Load tries the primary, then the backup, then starts a new game. A corrupt primary is kept aside as `…:corrupt`. A **newer** `format` or schema is never overwritten: autosave stays off for that session and a warning is logged. | IDEA Save | D-172 |
| When is it written? | See §5.2. Every trigger falls into one of three groups: a restore point (new game, close-up, night-1 retry), a dawn or day moment (the offer opens, any entry into DAY, each completed build), or a throttled DAY write (at most once per `autosave_interval_s` = 3.0 s while dirty, plus a flush when the page is hidden). Nothing is written during NIGHT. | IDEA Save | D-173 |
| What does "quitting mid-night costs the same" mean? | The only save during a night is its restore point (the close-up snapshot, or the new-game snapshot for night 1). Reopening after a mid-night quit resumes exactly where a failure would: the day before that night, or night 1's start. **A quit adds no mercy.** IDEA gives mercy for "each failed *retry*". Counting quits would let a player farm mercy by reloading, would greet a new player who bounced in night 1 with "the monsters look tired", and would count an OS tab discard as a failure. | IDEA Failure; D-048 | D-174 |
| How is mercy applied? | `GameState.night_fails` counts consecutive failures of the current night. Factor = `max(1 − mercy_step × night_fails, mercy_floor)`. It multiplies Boar HP at spawn (on the plan path only; `debug_spawn` stays exact) and Boar damage on every attack arm: fence, guard and diner. The count resets when a night is cleared. It is part of the snapshot and the save. A fail writes `snapshot.night_fails + 1` into the restore point before restoring, so a quit during the retry reloads the same count. | IDEA Failure | D-175 |
| Where does the flavor line appear? | As a HUD banner after every fail restore: "The monsters look tired tonight." (tr). The HUD gets a FIFO banner queue, so a night-1 restart shows "The monsters return" and then the flavor line, each for `banner_time`. | IDEA Failure | D-175 |
| What happens on boot with a save? | Main's boot runs deferred, after every listener has connected. It reads the store; if the read is ok it calls `phase_controller.resume_from(state)`, otherwise `start_new_game()`. The travelers' queue, pools and pending timers are not saved; they restart empty (S1 restore contract). | S1 §4.2 | D-176 |
| How does a tester restart? | Debug builds: the `R` key wipes the save and starts a new game. Any `?scene=`, `?cards=` or `?reset=1` query also skips the read and starts a new game (parsed synchronously in the debug overlay's setup, before Main's deferred boot), so URL scenes never mix with a resumed run. Release has no restart UI in S3; the S5 settings panel adds "New game" with a confirmation. | Pillar 2 | D-177 |
| What does the sweep report? | Both `first_fail_day` (the S2 difficulty target, D-170) and `hard_break_day`: the first night still lost after 4 retries, when mercy has reached its 0.40 floor. | D-155, D-170 | D-178 |

## 4. Save format (`core/save_codec.gd`, pure)

```
envelope := {
  "format": 1,                 # envelope version
  "saved_at_unix": int,
  "build": String,             # LST_BUILD or "dev"
  "state_json": String,        # JSON.stringify(GameState.to_dict(), "", true, true), resume_phase set by the writer
  "check": int,                # Rng.fnv1a32(state_json)
}
```

- `SaveCodec.encode(state: Dictionary, build: String, now_unix: int) -> String` returns the envelope as JSON.
- `SaveCodec.decode(text: String, current_v: int) -> Dictionary` returns `{ok: bool, reason: String, state:
  Dictionary, newer: bool}`. The pipeline runs in this order:
  1. Parse the envelope; failure gives `reason = "json"`.
  2. Check `format == 1`; a larger value gives `reason = "format"` and `newer = true`.
  3. Check `fnv1a32(state_json) == check`; failure gives `reason = "check"`.
  4. Parse `state_json`.
  5. If `state.v < current_v`, run `SaveCodec.migrate(state, current_v)`, one registered step per version.
  6. If `state.v > current_v`, return `reason = "version"` with `newer = true`.
  7. Validate the content (§4.1).
- **Migration** is a hook. `MIGRATIONS: Dictionary` maps a from-version to a `Callable`, and it is empty at ship,
  because no disk save older than the S3 schema (v3) exists. It is tested with a synthetic step injected by the test.

### 4.1 Content validation

`decode` rejects a state with `reason = "content"` when:
- `cards`, `card_offer` or `guards` hold ids not in `CardCatalog.IDS` (guards: `ADVENTURERS`);
- a card level is outside `0..max_level`;
- `resume_phase` is not one of `NIGHT`, `DAY`, `CARD_PICK`.

It also rejects:
- a missing `to_dict` key;
- building ids that are not in `MapLayout.SPOT_IDS`;
- a `lane_plan` whose size is not the wave count;
- a `CARD_PICK` state whose `card_offer` is empty or contains a maxed card. Resuming that would sit in DAWN with input
  blocked and no overlay.

Release builds strip the asserts in `CardCatalog` and `pick_card`, so this check is the real guard (S2 Task 2 review).
It keeps §1 goal 5 true ("never crashes").

## 5. Save store and triggers

### 5.1 `SaveStore` (`world/save/save_store.gd`)

**Keys:** `lst:<path>:save` (primary), `lst:<path>:save_bak` (backup), `lst:<path>:save_corrupt`.
- `<path>` is `location.pathname` with a trailing `index.html` stripped, so `/…/debug/` and `/…/debug/index.html`
  share one save. It is read once at `_ready` on web.
- The file backend uses the file names `save.json`, `save_bak.json` and `save_corrupt.json` under `user://save/`
  (no `:` in file names).

**Backends,** chosen by `OS.has_feature("web")`:
- **`WebBackend`:**
  - Every call goes through a JS wrapper that catches exceptions, e.g.
    `(function(){try{localStorage.setItem(K,V);return 1}catch(e){return 0}})()` and a `{ok, value}` form for `getItem`.
    `JavaScriptBridge.eval` swallows JS exceptions, so this wrapper is the only way GDScript sees a quota or
    private-mode error.
  - The JS source is built by a pure function, `SaveStore.js_call(op, key, value) -> String`, with `K` and `V`
    inserted through `JSON.stringify`. It is unit-tested for quotes, backslashes, newlines and non-ASCII text.
- **`FileBackend`:** `user://save/<key>.json`, written through a temp file and a rename. Tests inject a directory.
  There is no flush on window close, which is fine because desktop is only used for tests.

**API:**
- `read() -> {ok, state, source, newer}`
- `write(text) -> bool`: copies `_last_good_text` to the backup key, then writes the primary.
- `wipe()` clears all three keys, clears `_last_good_text` and resets `writable = true`, so a wiped run is never
  copied into the backup.
- `writable: bool`, which is false after a newer save was found, so it is never overwritten.
- A storage error is logged once with `push_warning`. The game keeps running.

### 5.2 `Autosave` (`world/save/autosave.gd`, a Node in Main)

Autosave listens only to EventBus. It tracks the phase itself, from `phase_changed` and `night_failed`. It reads
`GameState` and writes through its `store`. With no store (`store == null`, the default from `Main.create()`) it does
nothing, so the unit and sim suites never write saves. The real boot (`auto_start`) and tests that inject a
temp-directory store enable it.

| Trigger | What is written (`resume_phase`) |
|---|---|
| `EventBus.snapshot_taken(snap)`: new game, close-up, and each night-1 retry (see §6) | `snap.duplicate(true)` (the exact restore point; never mutated). NIGHT for night 1, DAY after a close-up. |
| `card_offered` (the dawn steps are done and the offer is open) | the live state, CARD_PICK |
| `phase_changed(DAY)`: after the pick, an empty-offer dawn, a DAY fail restore, and resume | the live state, DAY |
| `build_completed` | the live state, DAY |
| DAY and dirty: at most one write per `autosave_interval_s` (3.0), counted from the first change | the live state, DAY |
| DAY and the page is hidden (`visibilitychange`) or `pagehide` | the live state, DAY (flush if dirty) |

- **Dirty** means any `stocks_changed`, `gold_changed` or `building_changed` since the last write.
- **Autosave's state machine** (it tracks only EventBus):
  - `phase_changed(p)`: set `phase = p` and clear `failing`, **then** evaluate the row above (so the DAY write after
    a fail restore happens).
  - `night_failed`: set `failing = true`.
  - `snapshot_taken` **always writes** (whatever the phase or the fail flag). That covers new game at boot, `R`
    during a fail banner, and night-1 retries inside the fail flow. Only `store.writable == false` stops it.
  - Every other row writes only when `phase == DAY` (CARD_PICK: `phase == DAWN`) and `not failing`.
  - `store.writable == false` stops every write.
- `autosave_interval_s` lives in `UiTuning` (non-gameplay tuning).

### 5.3 Boot and resume

`Main._ready`, when `auto_start` is set: create the `SaveStore`, give it to `autosave`, then call `_boot.call_deferred()`.

`_boot()`:
1. If `debug_scene_query_present` (debug builds, §3 D-177): `store.wipe()`, then `start_new_game()`.
2. Otherwise run `var r := store.read()`. If `r.ok`, call `phase_controller.resume_from(r.state)`; if not, call
   `start_new_game()`.

`PhaseController.resume_from(state: Dictionary)`:
- `snapshot = state` (the restore point).
- **`resume_phase` DAY or NIGHT:** `_restore_snapshot()`. The S1 restore contract already handles stop, recall,
  `from_dict`, hero placement, `failing = false`, `dawn_substate = ""` and the phase entry.
- **`resume_phase` CARD_PICK:**
  1. `wave_director.stop()`, `traveler_spawner.stop()` (both D-128), `failing = false`, `_recall_all()`, then
     `GameState.from_dict(state)`;
  2. set `phase = DAWN` and `dawn_substate = "CARD_PICK"`;
  3. emit `hero_place_requested(HOME)` and `phase_changed(DAWN, day)`;
  4. `GameState.set_card_offer(GameState.card_offer)`, which re-emits the saved offer so the overlay shows.

  `snapshot` is left as the loaded state. The next close-up replaces it before any night can fail.

A resume never shows the flavor line, even with `night_fails ≥ 1` (a quit during a retry). The enemies are weaker,
and the line only appears after an actual failure. Tests must not expect the banner on resume.

## 6. Failure and mercy

**GameState:**
- New field `night_fails: int` (schema **v3**). `new_game()` sets it to 0, and `to_dict`/`from_dict` carry it.
- `set_night_fails(n)` and `clear_night_fails()` are the only mutators.
- `mercy_factor() -> float` returns `max(1 − mercy_step × night_fails, mercy_floor)`.

**PhaseController** gets one function for every failure, `_fail_restore()`, called by the fail timer:
```
var fails := int(snapshot.get("night_fails", 0)) + 1
snapshot.night_fails = fails                 # the restore point carries the new count
if String(snapshot.resume_phase) == "NIGHT":
    EventBus.snapshot_taken.emit(snapshot)   # night-1 retry: the save gets the new count
_restore_snapshot()                          # from_dict sets night_fails = fails; DAY restores autosave via phase_changed(DAY)
EventBus.banner_requested.emit(tr("The monsters look tired tonight."))
```
- `_run_dawn()` calls `GameState.clear_night_fails()` before `advance_day()`.
- `start_new_game()` and `close_up()` emit `EventBus.snapshot_taken(snapshot)` right after they take the snapshot.

**Applying the factor:**
- **WaveDirector:** a Boar's HP multiplier on the plan path is `plan hp_mult × GameState.mercy_factor()`.
  `debug_spawn(..., hp_mult)` is unchanged.
- **Boar:** every attack arm (`fence_on_lane`, `guard`, `diner`) uses `enemy.damage × GameState.mercy_factor()`.
- **Balance:** `WaveBalance.mercy_step = 0.15` and `WaveBalance.mercy_floor = 0.40`.

**HUD banner queue:**
- `_on_banner` queues the new text.
- If a banner is showing, it is shortened to `min(remaining, banner_min_s)` (`UiTuning.banner_min_s` = 0.6); then the
  next one plays for the full `banner_time`.
- So "The monsters return" is still readable before the flavor line, and a quick card pick's banner doesn't wait
  behind "Dawn" for the full time.
- A `state_restored` does **not** clear the queue, so a fail's banners survive the restore.

**Tests that change** (an update, not a weakening: every other field must still match exactly):
- `tests/sim/test_night_sims.gd` `test_night1_fail_restarts_night` and `tests/unit/test_phase_controller.gd`
  `test_fail_night1_restarts_night`: compare against the snapshot with `night_fails = 1`.
- `tests/unit/test_restore_world.gd` `test_fail_flow_restore_rebuilds_world`: the same change.
- `tests/unit/test_hud.gd` `test_second_banner_resets_the_fade`:
  - The second banner now appears after the first has been shortened to `banner_min_s`.
  - Let `r = min(remaining, banner_min_s)`. At `r` plus one frame after the second emit, assert
    `banner.text == "Two"` at alpha 1.0.
  - At `r + 0.7 × banner_time`, it is still visible at alpha 1.0.
  - Worked example: `banner_time` is 2.0 and the test emits "Two" 1.8 s after "One", so `r` is 0.2.
- `tests/sim/sweep_runner.gd:28-29`: replace the stale "retries replay identically" comment (not true with mercy).

## 7. Testing

- **`test_save_codec`:**
  - a round trip, equal including floats;
  - a tampered `state_json` is rejected (`check`);
  - bad JSON, and `format` 2 (newer);
  - `v` greater than current (newer) and `v` lower than current with a synthetic migration step;
  - content: an unknown card id, a level of 6, a bad `resume_phase`, a missing key, a bad building id, a CARD_PICK
    state with an empty offer.
- **`test_save_store`** (FileBackend in a temp directory):
  - primary and backup rotation from `_last_good_text`;
  - a corrupt primary falls back to the backup and is kept as `corrupt`;
  - both corrupt returns none;
  - a newer save makes `writable` false, and the file is untouched after a `write` attempt;
  - `wipe` (clears `_last_good_text`, resets `writable`);
  - `js_call` escaping cases (pure, so no browser is needed).
- **`test_autosave`** (injected store):
  - each §5.2 trigger writes the right `resume_phase`;
  - the new-game save is written at boot;
  - a night-1 retry save is written during the fail flow;
  - the first DAY write after a DAY fail restore happens;
  - nothing is written at NIGHT or during a fail;
  - throttling: 10 changes within 3 s give 1 write;
  - the hidden flush;
  - `Main.create()` has a null store and writes nothing.
- **`test_resume`:**
  - DAY resumes at HOME with the same gold and builds;
  - CARD_PICK resumes with the same offer and the overlay visible;
  - NIGHT resumes day 1 at `NIGHT1_START`;
  - a corrupt primary uses the backup;
  - both corrupt starts a new game;
  - a newer save starts a new game and leaves the save untouched;
  - fail night 1, "quit" (read the store), resume: `night_fails == 1`, and a second fail makes it 2;
  - fail night N ≥ 2: the saved DAY state carries `night_fails` = 1.
- **`test_mercy`:**
  - the factor curve and its floor (`assert_almost_eq`);
  - dawn clears the count;
  - Boar HP at spawn and the damage per hit on all three arms are scaled;
  - `debug_spawn` stays exact.
- **`test_hud`:** banner queue order and timing, and the queue survives `state_restored`.
- **`test_game_state`:** v3 round trip.
- **Sims:**
  - the updated fail tests (§6);
  - a ParkedBot night-1 retry has spawn HP = 0.85 × base, and fewer hits per kill;
  - the sweep reports `first_fail_day` and `hard_break_day` (4 retries).
- **Web smoke** (simulator and Playwright, each in one browser context):
  1. Load `…/debug/?cards=tank:1&scene=cardpick`.
  2. Load `…/debug/` again with no query.
  3. Expect the pick overlay with the same offer and the strip reading "TK1".
  4. **Playwright only** (`xcrun simctl` can't tap): press `1`, wait 4 s, reload, and expect DAY at HOME with that
     card.

## 8. Build order (a hint for writing-plans)

Phase branches `s3/p<N>-<slug>`, starting after S2 is merged:
1. `SaveCodec` plus the migration hook, and GameState v3 (`night_fails`).
2. `SaveStore` with both backends, plus `js_call`.
3. Mercy: GameState, `_fail_restore`, WaveDirector, Boar arms, balance, the HUD banner queue, and the updated fail
   tests.
4. Autosave plus the `snapshot_taken` signal.
5. Boot resume: `resume_from`, the `Main._boot` wiring, the debug `R` key and URL skip.
6. Sims, sweep columns, the web smoke check, and results.

**D-139 wiring notes** (the main session applies them): `autoload/EventBus.gd` (`snapshot_taken`),
`autoload/GameState.gd`, `balance/wave_balance.gd`, `balance/ui_tuning.gd`, `world/main.gd` (Autosave node,
`_boot`), and `world/phase_controller.gd` only where the plan says.

## 9. Risks

- **`localStorage` unavailable** (private mode, disabled storage): caught by the JS wrapper. The game runs without
  saving and logs a warning. S6 checks it on devices.
- **Shared origins:** itch.io's HTML host is shared across games, and Pages previews share `github.io`. Path-prefixed
  keys isolate our builds. The itch.io origin is checked in S6.
- **Safari ITP** may clear script-written storage after 7 days without a visit. That is accepted for v0.1, and S6
  notes it for testers.
- **Two open tabs** overwrite each other's save; the last write wins. Accepted, and noted in S6.
- **A tab killed mid-write:** `setItem` is atomic per key, and the backup covers a bad primary.

## 10. Playtest questions added for the final review

1. After closing and reopening the page, did the game continue where you expected?
2. After losing a night, did the retry feel fair? Did you notice the monsters were weaker?

## Appendix: Post-v0.1 ideas (not in v0.1)

- Cloud save and sync across devices.
- A visible save indicator.
- Multiple save slots.
