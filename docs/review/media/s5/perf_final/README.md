# S5 final perf, size and web checks (Task 12)

Branch = `s5/p5-results` at 6f9b826 (all of S5), profile build. Main = S4 `main` at c8cce18, profile build. iOS Simulator
"iPhone 17 Pro", `export/perf_night3.sh` (same script and fixtures for both), runs alternating branch, main, branch, ...
Crops of the PERF lines are in `runs/<name>/day_peak_crop.png` and `night3_80s_crop.png`; `run.log` holds cpu idle.
Day-3 = frozen `PERF phase=DAY` line (fixture `night3_closeup`), night-3 = frozen `PERF phase=NIGHT` line (`night3_start`).

## Readings
| run | idle before / after | night avg_fps | night worst_ms | day avg_fps | day worst_ms | night top3 / pre3 |
|---|---|---|---|---|---|---|
| branch 1 | 75% / 0% | 59.6 | 57.0 | 54.1 | 76.0 | 57@0.1s 54@0.1s 52@45.4s / 855@0.9s 61@1.6s 37@0.9s |
| branch 2 | 76% / 59% | 59.6 | 108.0 | 52.1 | 88.0 | 108@0.1s 39@0.2s 34@0.2s / 863@0.9s 25@1.0s 19@0.9s |
| branch 3 | 76% / 54% | 59.6 | 110.0 | 52.6 | 140.0 | 110@0.1s 34@19.6s 33@0.2s / 902@0.9s 33@1.6s 28@0.9s |
| **branch median** | | **59.6** | **108.0** | **52.6** | 88.0 | |
| main 1 | 79% / 59% | 59.7 | 119.0 | 53.3 | 76.0 | n/a (S4 has no top3/pre3) |
| main 2 | 82% / 39% | 59.6 | 122.0 | 54.0 | 107.0 | n/a |
| main 3 | 80% / 55% | 59.7 | 115.0 | 54.0 | 73.0 | n/a |
| **main median** | | **59.7** | **119.0** | **54.0** | 76.0 | |

(Day top3/pre3 for the branch: run 1 76@0.1s 43@16.1s 42@3.2s / 445@0.4s 56@2.0s 39@0.5s; run 2 88@0.1s 47@35.8s 37@0.2s / 486@0.5s 35@1.1s 30@0.6s;
run 3 140@0.2s 54@0.3s 48@0.4s / 496@0.5s 42@0.9s 41@1.8s.) pre3 = the three worst frames before the window starts (boot/warm-up), not counted in worst_ms.

## Gates (spec 1)
- night-3 median avg_fps >= 58: **pass** (59.6).
- night-3 median worst_ms < 60: **FAIL** (108.0; main 119.0). Only branch run 1 is under 60 (57.0), runs 2 and 3 are 108 and 110. The worst frame is at 0.1 s of the window in all three branch runs.
- day-3 median avg_fps >= main median - 1 (53.0): **FAIL by 0.4** (52.6 vs 54.0; range branch 52.1-54.1, main 53.3-54.0). Not tuned.

## Measurement validity
- Another process on this Mac (a different project's `node exp.mjs` batches, 6 workers at 60-70% CPU each) ran intermittently during this session,
  which the script's idle gate cannot see once a run has started. Its effect shows as the low "idle after" figures (0% for branch 1, 39% for main 2).
  Discarded and repeated: branch 1 first try (load started mid-run, day shot not frozen), main 1 first try (idle before 54%), branch 3 first try (idle before 65%);
  logs in `invalid/`. Branch 1 (idle before exactly 75%, 0% after, but both lines frozen and its night/day readings in line with the others) was kept.
  The old 17-hour-spread runs were deleted.
- All six kept runs have idle before >= 75%. "After" is taken while Safari still plays, so it is always lower.

## Desktop draw calls with FX active (real renderer, macOS, 720x1280)
`capture.gd` cannot combine `--drawcalls` and `--fx` as is: draw calls are only sampled inside `_wait`, which ends before the burst is emitted.
Not patched; measured with a temporary copy outside the repo that prints `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` on the same frame (3 frames after the burst) with and without `--fx`:

| scene | no FX | poof (8 quads) | hit (4 quads) |
|---|---|---|---|
| night (`--phase=night`) | 28 | 29 | 29 |
| day (`--phase=day`) | 50 | 51 | 51 |

Each FX kind costs one draw call.

## Size (release build, `web_release`)
- `index.pck` raw: 5,514,704 B (5.26 MiB), gate 8 MiB: **pass**. `grep -a -c ui/debug index.pck` = 0.
- `gzip -9`: wasm 10,054,769 B, pck 3,684,863 B, js 68,480 B; `cat wasm pck js | gzip -9` = 13,807,078 B (13.17 MiB), gate 16 MiB: **pass**.
- Audio: 22 files (20 ogg, 2 mp3), 1,021,516 B total (budget 2,621,440 B, `AudioManifest.BUDGET_BYTES`).

## Web checks
- `node export/pw_s5_check.mjs http://localhost:8767/` (debug build): `S5 CHECK: PASS`. Console 8 lines, 2 new distinct vs baseline (`WARMUP built=12 track=night`, `BOOTFADE done=4.05 frames=18`, both expected logs);
  audio contexts "suspended" before the tap, "running" after; `LST_STATE` {music_id night, muted false, unlocked true}; `?mute=1` gives muted true and survives a reload without flags.
- `export/device_check.sh` on the release build (served locally with `LST_BUILD=local`): `device_check/ios.png` (iOS Simulator Safari) and `device_check/android_emulated.png` (Playwright Pixel 7, emulated, D-141).
  Both show the night-1 start of a fresh run: coin counter 0, three moon discs, heart and diner bar, settings gear top right, hero with ring, boars on the left lane (iOS) / north lane (Android), diner roof, "Drag to move" prompt over a joystick ring, bottom-left "local" label.
  No debug overlay, no errors. The Android shot is cropped at the bottom by the viewport and shows the DINER sign. Console showed only WebGL "GPU stall due to ReadPixels" performance warnings.
- Audio CPU: see `docs/review/AUDIO.md`, "Audio CPU (Task 12)".
