# E1 follow-ups

Open items from the E1 station upgrades build (merged 2026-10-06, PRs #43 to #45). They come from the per-task reviews
and the final whole-branch review; none blocked the merge. Decisions and measurements are in `docs/DECISIONS.md`
D-231; feel questions are in `docs/REVIEW_QUEUE.md`, section "E1 station upgrades". Delete a line here when it is done.
Done on 2026-10-06 and removed from the list: items 1 (postponed by the author, D-235), 2 and 3 (D-235), 4, 5, 7 and 8
(PR #48, D-234). The numbering of the remaining items is kept.

## Before tuning station balance

6. **The 60 s window of sim 6.1** (`tests/sim/test_station_sims.gd`, `WINDOW_S`) belongs in `SimThresholds`:
   `min_level_gain` is only meaningful over that window.

## Code

9. **`StationEffects.level_cost`**: any id that is not `&"counter"` is priced as the freezer, and a negative level is
   not guarded. Use a `match` with a failing default before E3 adds a third station. Same for `UpgradePad.setup`'s
   name label (anything that is not the counter reads "Freezer").
10. **EventBus comments** for `station_changed` and `station_upgraded` do not name the emitter and the listeners, as
    every other signal in the file does. Hot file: main session.

## Tests

11. Restore test: pin `GameState.counter_steaks` to the fixture's value and assert the pad label is visible in DAY
    (`test_perf_fixture.gd`, the `day3_counter5` resume test).
12. Station pop: assert the `CollisionShape3D` stays unscaled; add the freezer case (`test_station_world.gd`).
13. Review Focus 5: assert that the traveler in service at the moment of an upgrade leaves within the new service
    time (`test_station_world.gd`, `test_upgrading_while_a_traveler_is_served`).
14. Pad tests: the ring's progress value (10 of 30, not only "visible"); a hero walking through a pad without
    stopping pays nothing; payment on the freezer pad; the pad's own dust and coin feedback; the night precondition
    and the name label in the day-to-night test (`test_upgrade_pad.gd`).
15. Save validation: a non-dictionary station entry, a non-numeric `paid`, and `paid == cost` on load
    (`test_save_stations.gd`).
16. GameState: the boot-window pay test should hold gold so it can fail; `new_game` should be shown to reset `paid`
    and the freezer; the lower clamp of `debug_set_station_level` (`test_game_state_stations.gd`).
17. Waypoint pin: also assert the positions of `front_e` and `se` and the edge list (`test_station_layout.gd`).
18. Listeners: the build sound on `station_upgraded` (`test_audio_director.gd`); the dirty mark on `station_changed`
    (`test_autosave.gd`). `test_guide.gd:83` and `test_pulse.gd`'s "state without stations" test cannot fail on their
    own; give them a state where stations would decide.
19. Sim 6.3's message says the freezer pad was reached; it only checks that some station level was bought.

## Tools and docs

20. Upgrader sweep: a STALL row puts the stations value in the `failed_retries` column.
21. `export/perf_night3.sh` prints `day_fixture=` also under `NIGHT_ONLY=1`.
22. `tests/sim/make_save.gd`: the first header sentence still reads as if the night3 fixtures are always written.
23. The E1 spec names `test_geometry.gd` and `test_day_sims.gd` where the tests live in `test_station_layout.gd` and
    `test_station_sims.gd`.
24. ~~Stale wording after the schema bump~~: the schema literals in `test_save_codec.gd` and `test_save_stations.gd`
    now read `GameState.SCHEMA_VERSION` (E5 Task 5). Still open: the test name
    `test_round_trip_v3_carries_night_fails` in `test_game_state.gd` and the comment at `test_perf_fixture.gd:2`.
25. Exit-time leak warnings grew with the station sims (about 48 ObjectDB instances and 16 resources at exit of the
    sim suite, against 16 and 7 before). Not a failure condition of `run_tests.sh`; cause not investigated.
