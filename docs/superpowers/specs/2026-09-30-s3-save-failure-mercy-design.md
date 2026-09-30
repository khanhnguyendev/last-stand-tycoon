# S3 Save/Load + Failure & Mercy: Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`). This builds on the S1 spec
  (`2026-09-30-s1-vertical-slice-design.md`) and the S2 spec (`2026-09-30-s2-hero-cards-guards-design.md`). Their
  conventions, architecture and rules still apply.
- **Status:** written autonomously under D-159. The main session answered every brainstorming question from IDEA.md,
  the pillars, DECISIONS.md and the S1/S2 work. A reviewer pass replaces the author's approval.
- **Decision log:** `docs/DECISIONS.md` (D-171 to D-178, logged with this spec).

---

## 1. Goal and success criteria

S3 makes a run survive closing the tab, and makes failure gentle, as IDEA.md says:
1. One local save in the browser, plus a backup. It is written automatically at night start, at dawn, after the card
   pick, after each build, and every few seconds during the day when something changed. At most the current night
   and a few seconds of the day can be lost.
2. Reopening the page resumes the run with no menu: at the day's sign, at the open card pick, or at night 1's start.
3. **Failure:** the diner falls, the night ends, and the game reloads the start of that night, back in the day
   (already true in S1/S2). Quitting mid-night costs exactly the same.
4. **Mercy:** each failed retry of the same night makes enemies weaker. HP and damage drop 15% per failure, with a
   floor of 40%. It shows only as a flavor line: "The monsters look tired tonight."
5. A corrupt or missing save never crashes the game. It falls back to the backup, then to a new game.
6. Unit, sim and CI stay green, every task passes a reviewer, and the sweep still reports the break day.

## 2. Scope

**In:**
- a `SaveStore` with two backends: web `localStorage`, and a `user://` file for desktop and tests;
- the save envelope (schema, checksum) and the primary/backup rotation;
- autosave triggers;
- resume on boot;
- the night-in-progress marker, so a quit counts as a failure;
- the mercy multiplier and its flavor line;
- sim and sweep updates.

**Out:**
- cloud save (IDEA "Later");
- a settings or "New game" UI (S5; debug builds get a key);
- offline earnings (IDEA "Later");
- save slots.

## 3. Brainstorm answers (autonomous, D-159)

| Question | Answer | Source | D-id |
|---|---|---|---|
| Where does the web save live? | `localStorage`, through `JavaScriptBridge`. It is synchronous, so it survives a tab closing right after a write, and a save is a few KB. Godot's `user://` on web is IndexedDB with an asynchronous sync, which can lose the last write on close. Desktop, the editor and tests use `user://save/`. | IDEA Save; D-014 | D-171 |
| What is saved? | `GameState.to_dict()` (schema v2, full float precision, D-146), inside an envelope: `{format, saved_at_unix, build, night_in_progress, state, check}`. `check` is FNV-1a 32 over the state JSON. | D-022, D-146 | D-172 |
| Backup rule? | Before each write, the current primary (if valid) is copied to the backup key. Load tries primary, then backup, then starts a new game. A corrupt primary is kept aside under `…_corrupt` for S6 debugging. | IDEA Save | D-172 |
| When is it written? | See §5.2: after new game, at close-up (the night-start save), after the dawn steps (resume in `CARD_PICK`), after the pick, after each completed build level, and every `autosave_interval_s` (3.0) during DAY when dirty. Also on `visibilitychange` → hidden and `pagehide` during DAY. There are no writes during NIGHT. | IDEA Save | D-173 |
| What does "quitting mid-night costs the same" mean for mercy? | The night-start save carries `night_in_progress = true`. Loading a save with it set counts as one failure of that night: mercy + 1, the flavor line, and a resume at the close-up state. Clearing the night (dawn save) clears the flag. The same "costs exactly the same" rule covers mercy too. | IDEA Failure; D-048 | D-174 |
| How is mercy applied? | `GameState.night_fails` is the count of consecutive failures of the current night. Factor = `max(1 − 0.15 × fails, 0.40)`. It multiplies Boar HP (at spawn) and Boar damage. It resets to 0 when a night is cleared. It is saved, and it survives the fail restore: PhaseController re-applies it after `from_dict`. | IDEA Failure | D-175 |
| Where does the flavor line appear? | As the banner after a restore when `night_fails ≥ 1`, instead of a numeric UI. The night-1 restart shows "The monsters return" first, then the flavor line. | IDEA Failure | D-175 |
| What happens on boot with a save? | Main auto-starts by loading instead of starting a new game:<br>• `resume_phase` DAY → the day at HOME;<br>• CARD_PICK → dawn with the saved offer (re-emitted);<br>• NIGHT (night 1 only) → night 1 start.<br>The travelers' queue, pools and pending timers are not saved. They restart empty (the S1 restore contract). | S1 §4.2 | D-176 |
| How does a tester restart? | Debug builds: key `R` (and `?reset=1` in the debug URL) wipes the save and starts a new game. Release: no UI in S3; the S5 settings panel adds "New game" with a confirmation. | Pillar 2 | D-177 |
| Does mercy change the sweep's break day? | The sweep now plays on with mercy. It reports both `first_fail_day`, which is the S2 target metric (D-170), and `hard_break_day` (the first night still lost after 3 retries with mercy). The break-day target stays on `first_fail_day`. | D-155, D-170 | D-178 |

## 4. Save format (`core/save_codec.gd`, pure)

```
envelope := {
  "format": 1,                       # envelope version; GameState has its own "v"
  "saved_at_unix": int,
  "build": String,                   # LST_BUILD or "dev"
  "night_in_progress": bool,
  "state": Dictionary,               # GameState.to_dict(), resume_phase set by the writer
  "check": int,                      # Rng.fnv1a32(JSON.stringify(state, "", true, true))
}
```

- `SaveCodec.encode(state: Dictionary, night_in_progress: bool, build: String, now_unix: int) -> String` returns the
  envelope as full-precision JSON (D-146).
- `SaveCodec.decode(text: String) -> Dictionary` returns `{ok: bool, reason: String, envelope}`. It is `ok` only
  when:
  - the JSON parses;
  - `format == 1`;
  - `check` matches;
  - `state.v` equals `GameState.SCHEMA_VERSION`.
- **Migration:** a `state.v` older than the current version goes through `SaveCodec.migrate(state) -> Dictionary`.
  The steps shipped now are:
  - `1 → 2`: adds empty `cards`, `card_offer` and `guards`;
  - `2 → 3`: adds `night_fails = 0`.
  An unknown or newer version fails with `reason = "version"`.
- **Content validation:** `decode` also rejects a state whose `cards`, `card_offer` or `guards` ids are not in
  `CardCatalog.IDS` / `ADVENTURERS`, and levels outside `0..max_level` (`reason = "content"`). This matters because
  release builds strip the asserts in `CardCatalog`/`pick_card` (S2 Task 2 review). `GameState.from_dict` itself still accepts only the
  current version; migration happens in `SaveCodec`, before `from_dict`.

## 5. Save store and triggers

### 5.1 `SaveStore` (`world/save/save_store.gd`)

- Keys: `lst_save_v1` (primary), `lst_save_v1_bak` (backup), `lst_save_v1_corrupt` (the last corrupt primary).
- Backends, chosen at `_ready` (`OS.has_feature("web")`):
  - `WebBackend`: `JavaScriptBridge.eval("localStorage.getItem(...)")` and `setItem`/`removeItem`. Values go through
    `JSON.stringify` for JS-string safety.
  - `FileBackend`: `user://save/<key>.json`, written through a temp file plus a rename. Tests inject a directory.
- API:
  - `write(text)`: copies a valid primary to the backup, then writes the primary.
  - `read() -> {ok, envelope, source}`: `source` is primary, backup or none.
  - `wipe()` clears all keys.
- A storage error (quota, private mode) is logged once with `push_warning`, and the game keeps running. Only a
  dev/debug label shows it (S5 may surface it).

### 5.2 `Autosave` (`world/save/autosave.gd`, a Node in Main)

It listens only to EventBus and asks GameState and PhaseController for nothing but read-only state. It writes
through `SaveStore`.

| Trigger | resume_phase written | night_in_progress |
|---|---|---|
| `start_new_game` (the NIGHT snapshot) | NIGHT | true |
| close-up (`PhaseController` snapshot, D-048) | DAY (the snapshot state) | true |
| dawn steps done, offer open (`card_offered`) | CARD_PICK | false |
| `card_picked` | DAY | false |
| `phase_changed(DAY)` straight after dawn with an empty offer (all cards maxed) | DAY | false |
| `build_completed` | DAY | false |
| DAY, dirty and `autosave_interval_s` elapsed | DAY | false |
| DAY and `visibilitychange` hidden / `pagehide` | DAY | false |

- "Dirty" means any `stocks_changed`, `gold_changed`, `building_changed` or `card_picked` since the last write.
- During NIGHT, and during a fail flow, nothing is written. The night-start save stands.
- At close-up and new game it writes `PhaseController.snapshot` (the exact restore point), not the live state.
- PhaseController exposes nothing new to Autosave except a new signal `EventBus.snapshot_taken(snapshot:
  Dictionary)`, emitted by PhaseController when it takes the close-up or new-game snapshot. That keeps the D-128
  whitelist unchanged.

### 5.3 Boot and resume (`PhaseController.resume_from(envelope)`)

`Main._ready` behaviour when `auto_start` is set:
- Call `SaveStore.read()`.
- If it is `ok`, call `phase_controller.resume_from(envelope)`. Otherwise call `start_new_game()`.

`resume_from`:
1. `_recall_all()`, then `GameState.from_dict(state)`, then `snapshot = state` (the restore point).
2. If `night_in_progress`: `GameState.add_night_fail()`, then take the fail-restore path of §6: DAY at HOME, or night
   1's start when `resume_phase == "NIGHT"`. Show the flavor banner.
3. Otherwise, by `resume_phase`:
   - `DAY`: hero at HOME, then `_enter_day()`.
   - `CARD_PICK`: set `phase = DAWN` and `dawn_substate = "CARD_PICK"`, emit `phase_changed(DAWN, day)`, then
     `GameState.set_card_offer(card_offer)`, which re-emits the saved offer (the overlay shows).
   - `NIGHT`: the night-1 start (only new-game saves carry NIGHT).

## 6. Failure and mercy

- New GameState field: `night_fails: int`, saved in the snapshot (schema v3).
- New methods:
  - `add_night_fail()`, `set_night_fails(n)` and `clear_night_fails()`, each emitting
    `EventBus.mercy_changed(fails: int)`;
  - `mercy_factor() -> float`, which returns `max(1 − mercy_step × night_fails, mercy_floor)`.
- **PhaseController fail flow** (`_on_fail_timer`): `var fails := GameState.night_fails + 1`, then
  `_restore_snapshot()`, then `GameState.set_night_fails(fails)`. The snapshot holds the pre-night count, so it has
  to be re-applied. Then, if `fails ≥ 1`, show the banner "The monsters look tired tonight." (tr).
- `_run_dawn()` calls `GameState.clear_night_fails()` before the dawn save.
- **WaveDirector:** a spawned Boar's HP multiplier is `plan hp_mult × GameState.mercy_factor()`.
- **Boar:** attack damage is `enemy.damage × GameState.mercy_factor()`, read at attack time.
- **Balance:** `WaveBalance.mercy_step = 0.15`, `WaveBalance.mercy_floor = 0.40`.
- **Sims:**
  - The existing fail tests keep passing, with mercy now applied on retries.
  - A new sim: ParkedBot fails night 1, and with mercy the enemies are weaker (HP at spawn is 0.85 × base).
  - The sweep gets `first_fail_day` and `hard_break_day` (D-178).

## 7. Testing

- **`test_save_codec`:**
  - a round trip that is equal including floats;
  - a bad checksum, bad JSON, the wrong format or a newer `v` rejected with a reason;
  - migrating v1 and v2 to the current version.
- **`test_save_store`** (FileBackend in a temp dir):
  - primary and backup rotation;
  - a corrupt primary falls back to the backup and is kept aside as `_corrupt`;
  - both corrupt gives none;
  - `wipe`.
- **`test_autosave`:**
  - each trigger in §5.2 writes the right `resume_phase` and `night_in_progress`;
  - no writes during NIGHT;
  - interval debouncing: several changes in 3 s give one write;
  - hidden or pagehide flushes.
- **`test_resume`:**
  - boot with each resume phase (DAY at HOME, CARD_PICK with the same offer and the overlay visible, NIGHT day 1);
  - `night_in_progress` gives a fail plus mercy plus the flavor banner;
  - a corrupt save gives a new game.
- **`test_mercy`:**
  - the factor curve and its floor;
  - fail increments and dawn clears;
  - the count survives the fail restore;
  - Boar HP at spawn and damage per hit are scaled.
- **`test_game_state`:** schema v3 round trip, and v2 → v3 migration through `SaveCodec`.
- **Sims:** the ParkedBot night-1 fail-then-retry replay shows mercy (fewer kills needed and less diner damage per
  hit). The sweep columns follow D-178.
- **Web smoke (device check):** on the Pages preview, play into the day, reload the page, and check the resume at
  HOME with the same gold. Use the debug URL `?scene=` hooks from S2 Task 9, plus a new `?reset=1`.

## 8. Build order (a hint for writing-plans)

Phase branches `s3/p<N>-<slug>`:
1. `SaveCodec` plus migration plus GameState v3 (`night_fails`).
2. `SaveStore` backends.
3. Mercy: GameState, PhaseController fail flow, WaveDirector, Boar, balance.
4. Autosave plus the `snapshot_taken` signal.
5. Boot resume (`resume_from`, Main wiring, the debug reset).
6. Sims, sweep columns, the web smoke check, and results.

## 9. Risks

- **`localStorage` throws in some private modes.** It is caught, the game keeps running, and a warning is logged.
  S6 checks it on devices.
- **A tab killed mid-write:** `localStorage.setItem` is atomic per key, and the backup covers a bad primary.
- **The quit-counts-as-fail rule could surprise a player** who closes the tab right after a night starts. It is
  reversible, so it is in REVIEW_QUEUE.

## 10. Playtest questions added for the final review

1. After closing and reopening the page, did the game continue where you expected?
2. After losing a night, did the retry feel fair? Did you notice the monsters were weaker?

## Appendix: Post-v0.1 ideas (not in v0.1)

- Cloud save and sync across devices.
- A visible save indicator.
- Multiple save slots.
