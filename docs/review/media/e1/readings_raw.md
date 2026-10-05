# Task 10 readings (Steps 3 and 4), raw

Worktree /Users/ryan/ws/1.GAME/lst-wt/e1-p1-core, branch e1/p3-sims. No tracked files edited; git status shows only untracked docs/review/media/e1/.
Mac was NOT idle: vitest (node) ~97% CPU and BlueStacks ~57% were running at the start. The script waited its full 40 x 15 s cap
(40 "cpu idle N% < 75%, waiting" lines in every run.txt) and then measured anyway. Idle figures below are what the script printed.

## A. Perf (iOS Simulator, iPhone 17 Pro, profile build)

Commands:
- `mkdir -p build && touch build/.gdignore && "$GODOT" --headless --path . --export-release "web_profile" build/web_profile/index.html`
  First attempt failed: `Export: Target folder does not exist or is inaccessible: "build/web_profile"`. Repeated after `mkdir -p build/web_profile`: exported OK. git status clean (build/ ignored).
- `DAY_FIXTURE=day3_counter5 export/perf_night3.sh build/web_profile docs/review/media/e1/perf_counter5/run<N>` for N=1,2,3 (stdout in run<N>/run.txt)
- `export/perf_night3.sh build/web_profile docs/review/media/e1/perf_counter0/run1`

Idle (script output):
| run | before | mid day | mid night | after |
|---|---|---|---|---|
| counter5 run1 | 69% | 5% | 0% | 22% |
| counter5 run2 | 63% | 52% | 60% | 59% |
| counter5 run3 | 67% | 51% | 40% | 33% |
| counter0 run1 | 60% | 57% | 62% | 57% |

All overlays were frozen (win 60s frozen for day; night PERF line present with window=60s). No run discarded. counter5 run1 was taken
under heavy load (idle mid 5% / 0%), flagged but kept per the "frozen" rule; no repeat was done.

Frozen PERF lines (transcribed from the screenshots):

counter5 run1
- DAY: phase=DAY day=3 window=60s avg_fps=39.1 worst_ms=91.0 proc_ms=32.56 phys_ms=1.41 dc=81 slow_pct=94.8 delta_worst_ms=83.8 top3=91@11.0s(w-1,-1) 84@12.5s(w-1,-1) 78@0.2s(w-1,-1) pre3=742@0.7s 64@1.0s 60@2.0s
- NIGHT: phase=NIGHT day=3 window=60s avg_fps=58.3 worst_ms=109.0 proc_ms=15.48 phys_ms=1.12 dc=36 slow_pct=5.8 delta_worst_ms=95.7 top3=109@0.1s(w-1,-1) 50@46.1s(w1,+8.6) 47@28.9s(w0,+25.0) pre3=1028@1.0s 45@1.1s 40@1.4s
counter5 run2
- DAY: phase=DAY day=3 window=60s avg_fps=42.8 worst_ms=86.0 proc_ms=26.65 phys_ms=1.10 dc=81 slow_pct=92.8 delta_worst_ms=76.7 top3=86@0.1s(w-1,-1) 76@10.9s(w-1,-1) 66@12.3s(w-1,-1) pre3=632@0.6s 50@0.7s 40@1.6s
- NIGHT: phase=NIGHT day=3 window=60s avg_fps=59.6 worst_ms=117.0 proc_ms=14.79 phys_ms=1.10 dc=36 slow_pct=1.3 delta_worst_ms=108.7 top3=117@0.2s(w-1,-1) 35@0.4s(w-1,-1) 35@47.6s(w1,+10.1) pre3=1025@1.0s 48@1.1s 36@1.8s
counter5 run3
- DAY: phase=DAY day=3 window=60s avg_fps=42.5 worst_ms=98.0 proc_ms=27.69 phys_ms=1.23 dc=81 slow_pct=93.5 delta_worst_ms=96.7 top3=98@0.1s(w-1,-1) 71@10.9s(w-1,-1) 62@12.4s(w-1,-1) pre3=675@0.7s 67@0.9s 44@1.5s
- NIGHT: phase=NIGHT day=3 window=60s avg_fps=58.5 worst_ms=229.0 proc_ms=16.02 phys_ms=1.15 dc=36 slow_pct=3.5 delta_worst_ms=146.1 top3=229@40.7s(w1,+3.3) 169@40.9s(w1,+3.4) 109@0.1s(w-1,-1) pre3=976@1.0s 42@1.0s 35@1.8s
counter0 run1 (old method)
- DAY: phase=DAY day=3 window=60s avg_fps=48.0 worst_ms=100.0 proc_ms=21.50 phys_ms=1.00 dc=71 slow_pct=47.3 delta_worst_ms=93.2 top3=100@0.1s(w-1,-1) 61@32.2s(w-1,-1) 52@10.5s(w-1,-1) pre3=551@0.6s 69@1.8s 48@0.8s
- NIGHT: phase=NIGHT day=3 window=60s avg_fps=59.6 worst_ms=63.0 proc_ms=14.28 phys_ms=1.15 dc=36 slow_pct=1.7 delta_worst_ms=53.3 top3=63@0.1s(w-1,-1) 42@0.2s(w-1,-1) 41@42.8s(w1,+5.4) pre3=957@1.0s 64@1.9s 26@1.6s

Day screenshot description (day_peak.png):
- counter5 runs 1-3 look identical: Day 3, 32 coins, 9 travelers in view (a clump of 7 standing in front of the hero near the road, 2 more at the counter/Close-up sign), no one visibly moving through; a standing queue. Counter label reads "Counter MAX" with 5 stars (no steak count number; counter-level label, the counter appears not to show a stock number). A "0" label above the counter window and a 126 coin pile at left. Hero (chef) stands among the queue.
- counter0 run1: Day 3, 32 coins, 4 travelers visible (3 queued diagonally toward the counter, 1 at the counter), label "Counter 30" with a yellow build-spot bracket (counter level 0 pad costs 30), empty counter, standing short queue.
- Night shots (all runs) show the "Pick a card" overlay for Day 4 over the night map (the night3_start fixture resumes at a card pick); counter5 run1 and counter0 night shots caught the cards mid-fade.

## B. Load time (Playwright Chromium, emulated): SKIPPED
Preview deployed: `gh run list --branch e1/p3-sims` shows pages workflow "docs(e1): upgrader sweeps, build decisions (D-231), review queue" completed success; build stamp seen in the device shot: 120214b e1/p3-sims.
Both `node docs/review/media/final/load_time.mjs <url> 3` runs failed at launch (outputs saved in load_time_e1.txt, load_time_main.txt):
`browserType.launch: Executable doesn't exist at /Users/ryan/Library/Caches/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-mac-arm64/chrome-headless-shell ... Please run: npx playwright install`
~/Library/Caches/ms-playwright holds only chromium-1194 / chromium_headless_shell-1194 (installed Playwright wants 1243). Not installed (rule: no system components). One-time fix for the author: `npx playwright install chromium` (with PLAYWRIGHT dir ~/.cache/lst-playwright), or pin the older playwright version.
Pre-E1 reference: docs/review/media/final/load_time_chromium.txt (t_engine about 3.6 to 4.8 s, t_full about 7.9 to 9.1 s). Main currently holds E1 phases 1 and 2 (traveler pool already 31).

## C. Device check
`export/device_check.sh https://khanhnguyendev.github.io/last-stand-tycoon/preview/e1-p3-sims/ docs/review/media/e1/device`
- ios.png (iOS Simulator, iPhone 17 Pro Safari, real simulator): night 1 of the E1 preview (three moon icons, coins 0), hero and 4 boars on the right path, "Drag to move" joystick hint, build stamp "120214b e1/p3-sims" bottom left. Dynamic Island is hidden in this shot; nothing clipped by the status bar or the bottom Safari bar; HUD (coins, hearts, settings gear) is fully visible.
- Android/Playwright shot: not produced; pw_check.mjs failed with the same missing-Chromium-1243 error.
