# Raw evidence for the tier-3 balance (E5)

One line per file or folder: what it is and which balance it was run on. "Current" = the applied balance (tier-3 cap 12, D-280, no override).

- `t3_balance_study.txt`: study 1, raw output of `report_t3_balance.gd` (since deleted) on CONSTRUCTED fixtures (hp500 and other configurations). Superseded; not the applied balance.
- `study2/`: round 1 of study 2, per-seed sweep CSVs (`sw_C<n>_<seed>.csv`) at tier cap 15 with the in-memory overrides of each configuration C0 to C7. Superseded.
- `study2_matrix_summary.txt`: the TIER3 lines of that round (cap 15, overrides). Superseded.
- `study2_cause_c0.txt`: the retry-night cause analysis of configuration C0 (cap 15, no brute override). Superseded.
- `study2_make_save_tier3_realplay.txt`: output of `make_save.gd -- --fixture=tier3` when the fixtures were made at pressure 15 (real play). Superseded (the fixtures were remade at cap 12).
- `study2_sims_2_3_6_on_realplay_fixtures.txt`: sims 2, 3 and 6 on those pressure-15 fixtures. Superseded.
- `applied/`: current. Three 32-day tier sweeps (`--bot=tier --days=32 --policy=threat --cols=extra`, seeds 20260930, 1, 2, no override): `seed_<n>.csv` the sweep CSV, `seed_<n>.stdout.txt` its stdout (TIER, TIER3, LADDER, UNSPENT_TARGET, FENCE_TAX lines; the last line is the exit code).
- `policies/`: current. The 15 runs of `report_policies.gd` (3 seeds x 5 policies, 32 days, cap 12): `policy_<seed>_<policy>.log` (stdout, first line records the commit) and `.csv` (the sweep CSV), 
- `policies.txt`: current. The report's own output of the re-run (COMMIT 38b7257); it replaced the earlier output of commit c0ce5e5, whose numbers it reproduces.
- `ladder_<seed>.txt`: current. The ladder summary of a 32-day tier sweep per seed (20260930, 1, 2).
- `tier3_off.txt`: current. `--bot=tier --days=20 --tier3=off` on the CI seed: the `TIER3_GATE tier3=off ... events=0` line and exit code.
- `sim_tiers_final.txt`: current. Full output of the final `./run_tests.sh sim-tiers`, with the margins of sims 2, 3, 4, 5 and 7.
