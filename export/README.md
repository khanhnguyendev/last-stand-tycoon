# Web export

Presets (export_presets.cfg): `web_debug` (debug template, debug overlay + hotkeys G/J/N/K/F/O; the bottom-right "Fade alpha" button and O cycle the occluder alpha 0.30/0.45/0.60 live, D-151),
`web_profile` (release template, fps/frame-time overlay only), `web_release` (GitHub Pages builds, D-135).
All single-threaded (no COOP/COEP headers needed) with the custom shell `export/web_shell.html`.

```bash
mkdir -p build && touch build/.gdignore   # keeps old exports out of the project scan and the pack
"$GODOT" --headless --path . --export-release "web_release" build/web_release/index.html
cd build/web_release && python3 -m http.server 8000 --bind 127.0.0.1   # desktop check only: http://localhost:8000/ (localhost is a secure context)
```

Release check: `grep -a -c "ui/debug" build/web_release/index.pck` must print 0. The `pages` workflow runs the same check on the release and profile packs and fails the deploy on a hit; if `main.gd`'s `load("res://ui/debug/...")` string alone makes it non-zero, narrow the check to the overlay's script entry and log the change (D-135).

Phones: push the branch; the `pages` workflow deploys it to https://khanhnguyendev.github.io/last-stand-tycoon/preview/<slug>/ (slug: branch name, every character outside [A-Za-z0-9._-] → "-")
(main: the site root). The bottom-left label shows the build's git hash. Plain-http LAN does not work
(secure context, D-120). The itch.io draft is S6.

Checks without a phone (D-138, D-141): `export/device_check.sh <url> <out_dir>` (iOS Simulator, Android Emulator if installed, else
Playwright "Pixel 7", labelled emulated) and `node export/pw_check.mjs <url> <out.png> [android|desktop]` (Playwright from `$LST_PW_DIR`,
default `~/.cache/lst-playwright`). Both expect `window.LST_BUILD`, which the pages workflow injects; a local build needs
`<script>window.LST_BUILD="local";</script>` added before `</head>` of its `index.html`.

Fresh starts (S3): a plain URL resumes a saved run from `localStorage`. Add `?reset=1` to debug URLs for a fresh start. Release URLs can't be reset; use a fresh browser profile. `node export/pw_resume.mjs <debug_url_base> <out_dir> [android|desktop]` is the resume smoke (one browser context: pick, plain-URL resume, reload).

Night-3 perf (S4 Task 5, D-196): `export/perf_night3.sh <web_profile_dir> <out_dir>` (macOS only; modifies <dir> in place) serves a profile build on localhost:8765, injects the `export/fixtures/night3_*.save.json` saves through `export/seed_save.html` and screenshots the perf overlay in the iOS Simulator (`day_peak.png`, `night3_80s.png`).
Perf query flags (profile and debug builds, `ui/perf_overlay.gd`; E6 A2): `?perfwarm=<s>` (the overlay's warm-up before its 60 s window, default 2), `?perflog=<s>` (logs every frame of the first <s> seconds after each phase change: one `PERFLOG ...` console line with every `t:ms`, and on screen the frames of 30 ms or more, the first use of each event (`wave0@`, `fx_poof@`, `guard_hit@`, `banner_off@` ...), `phase_msec` (engine ticks at the phase change) and `stable_at` (seconds after the phase change when 10 frames in a row were under 50 ms, i.e. when the boot fade lifts: first playable frame = `phase_msec` + 1000 * `stable_at`; the print itself costs about 0.5 s, so keep the log shorter than the window or read a run apart), `?perfglyph=0` (the overlay now draws its own glyphs once in its first frame by default, D-292; `perfglyph=0` restores the old behaviour. Readings taken BEFORE this change include a 95 to 133 ms overlay artifact at the window start, the first rasterisation of the overlay's own digits: 128 / 95 / 133 ms became 35 / 27 / 38 ms), `?perfnofade=1` (diagnosis: switches the diner's occluder fade off), `?perfclose=<s>` (s seconds into a DAY the overlay sends the close-up signal, so the night begins as after a real close-up). All inert without the flag.
Gate rule (E6 A2, D-292): every perf table carries two lines: the GATE reading, and the RESUME HITCH reading (the default script: a night resumed from a save). Their fps differ because the camera frames the diner from the close-up sign (about 50.8 against 58.8): they are not comparable, and the fps reference stays the resumed mode. The gate reading is taken on a night the game ENTERS BY PLAYING: `PLAY_ENTERED=1 NIGHT_FIXTURE=tier3_cap_threat export/perf_night3.sh <web_profile_dir> <out_dir>` loads `<NIGHT_FIXTURE>_day` (`tests/sim/make_save.gd -- --fixture=tier3_cap_day` writes `tier3_cap_threat_day`), adds `perfclose=${PERF_CLOSE:-8}` to `QUERY` and waits `SHOT_WAIT` (125 s) before the shot. `PERF_SETTLE=<s>` adds `perfwarm=<s>` (the window opens <s> seconds after the phase change; default off = 2 s). The default (no `PLAY_ENTERED`) stays a night RESUMED from a save: report it separately as the "resume hitch" (the 1.5 s load freeze and the seconds after it).
`node export/pw_perf.mjs <base_url> <out_dir>` does the same for emulated Pixel 7 (software GL on a desktop, so its fps is only a smoke value; start `python3 export/serve_nocache.py 8765 <build dir>` first (no-store, so no stale pack)) and prints the console `PERF` lines.
`export/seed_save.html?f=<fixture stem>&to=<game path>` writes a fixture into `localStorage["lst:<path>:save"]` and redirects to the game; regenerate fixtures with `tests/sim/make_save.gd -- --fixture=day3_counter5|night3` (`night3` rewrites the two schema-3 migration fixtures at the current schema; do not use it while they serve as migration tests).

`?autoplay=tier` (debug builds only): attaches `ui/debug/autoplay_tier.gd`, a self-playing bot that also buys the tier sign and branches (`?autoplay=1` is the plain bot).
`?policy=all_a|all_b|mixed|threat|volley_stone` picks the tier autoplay's branch policy (default `threat`; an unknown value falls back to `threat`). The video's branch-day fixture: `"$GODOT" --headless --path . -s res://tests/sim/make_save.gd -- --fixture=tier3_branch_day` writes `export/fixtures/tier3_branch_day.save.json`.
