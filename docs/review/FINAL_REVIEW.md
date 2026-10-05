# Last Stand Tycoon v0.1: final review

Built without the author from S1 to S5 (D-159). This page is what to check before S6 (friend playtests).

## Summary

- **Play it:** release https://khanhnguyendev.github.io/last-stand-tycoon/ · debug
  https://khanhnguyendev.github.io/last-stand-tycoon/debug/ · profile (perf overlay)
  https://khanhnguyendev.github.io/last-stand-tycoon/profile/. All three serve main `23b7d7b`. After this branch
  merges, the debug build also takes `?autoplay=1` (bots play) and `?nooverlay=1`.
- **Watch it:** [gameplay.mp4](media/final/gameplay.mp4) (83 s, iOS Simulator, bots playing a debug build): night-1
  combat, the dawn card pick, the day.
- **What it is:** the v0.1 scope of IDEA.md. Nights of Boars on three lanes, steaks to sell by day, towers and fences
  to build, dawn cards (upgrades, Archer, Tank), save and resume, mercy after a lost night, one cohesive CC0 look,
  sound, juice, a settings panel and a pointer that teaches the first night and day.
- **State of the code:** 865 unit tests and 11 sims pass (sim suite 14 s of 60 s); the determinism baseline is
  identical; CI (`unit`, `sim`, Pages `deploy`) is green on main.
- **What did not meet its gate:** two perf gates (below). **What nobody has checked:** how it feels on a real phone,
  and how it sounds; all audio was chosen without listening.

## What to decide first: REVIEW_QUEUE top 10

Full list: [REVIEW_QUEUE.md](../REVIEW_QUEUE.md) (37 items, ranked).

1. Art direction: KayKit cast with a chef-hat hero, Kenney rounded kits, a procedural tusked Boar (D-186).
2. All audio chosen without listening; every sound is one line in `art/audio/audio_manifest.gd` (D-211,
   [AUDIO.md](AUDIO.md)).
3. The hero is a cook who throws kitchen knives (D-191).
4. The Boar's look; tusks are small at phone size (D-202).
5. Onboarding is one pointer with at most three words for night 1 and the first day, then never again (D-213).
6. Night look: blue moonlight at about half the day's light (D-194, D-206).
7. The diner has a flat roof so the Archer can stand on it (D-194).
8. Diner colours and the rooftop DINER board (D-204).
9. Towers and fences change model per level instead of growing 10% (D-197).
10. Occluder fade alpha 0.45; the /debug/ build has a picker (D-151).

Also worth an early look: late-game gold has no use and no run ever ends (items 24, 25); day length (22).

## Known issues

1. **Night-3 worst frame: 106 ms** (gate < 60; S4 main 119). One frame, 0.1 s after the perf window opens, about
   2.1 s after the night starts, before any wave. Cause unproven (D-215).
2. **Day-3 fps: 52.9 against S4 main's 54.0** (gate: no more than 1 fps lower; missed by 0.1; it was 0.4 at the end of
   S5). The day phase has run near 53 fps since S4; cause unresolved (D-199).
3. A 0.86–0.92 s load freeze right after the phase starts. The boot fade now holds over it; confirm on a phone.
4. Music is kept as decoded samples: 53–56 MB steady in Chromium, 72.6 MB peak after a switch (D-212). Watch a
   low-end phone.
5. The iOS silent switch may mute Web Audio (unverified).
6. Perf is measured in the iOS Simulator on a Mac that other work shares. No real phone has been measured.

Fixed during S5: the WebGL warnings on Chromium (the HUD's `Polygon2D` arrows).

## Sim and sweep results

- Unit 865/865, sim 11/11 (14 s), baseline identical: [unit](media/final/unit.txt), [sim](media/final/sim.txt),
  [baseline](media/final/baseline_diff.txt).
- Sweep, PlannerBot, seeds 20260930, 1, 2 ([sweep.md](media/final/sweep.md)): every seed plays all 14 days. First
  failed night: day 10, 9, 9 (target 10 ± 1). Nights 1–8 clear without a retry on every seed; lowest diner margin
  before day 9 is 0.42.
- **Mercy target (author):** median retries per night 0, none needing more than 2 before day 8. Result: median 0,
  max before day 8 is 0, max overall 3. Met.
- Onboarding sim: a bot that only follows the Guide clears night 1 with 0 fails on two seeds and builds 3 spots by
  night 2.

## Perf, size, load

iOS Simulator (iPhone 17 Pro), profile build, median of 3, Mac ≥ 75% idle before each run
([perf.md](media/final/perf.md)):

| | v0.1 | S4 main | Gate | Verdict |
|---|---|---|---|---|
| Night-3 avg fps | 59.9 | 59.7 | ≥ 58 | Pass |
| Night-3 worst frame | 106 ms | 119 ms | < 60 ms | **Fail** |
| Day-3 avg fps | 52.9 | 54.0 | ≥ S4 − 1 | **Fail by 0.1** |

- Draw calls on desktop: night 28, day 50; +1 while particles are alive.
- Release size ([load_size.md](media/final/load_size.md)): pck 5.26 MiB (gate 8); wasm + pck + js gzipped 13.17 MiB
  (gate 16). Audio 1.02 MB of that.
- Load time on localhost, not comparable to a phone on a network: first game frame at 3.6–4.8 s in Chromium (software
  GL) and 6.1–6.4 s in the iOS Simulator; the boot fade lifts about 4 s later in Chromium.

## Phone checklist (yours; nothing here has been done on a real phone)

1. **Joystick:** appears where the thumb lands, follows it, stops on release; a tap on the gear does not start it.
2. **Camera:** follows the hero; nothing important hides behind the diner (it fades).
3. **Fade:** the diner fades when the hero walks behind it; the boot fade covers the first second with no visible
   freeze after it lifts.
4. **HUD and safe area:** coin, day, moons, diner bar and gear clear of the notch and the home bar, portrait and
   landscape; labels under the HUD dim.
5. **Focus pause:** switch apps mid-night and return; the night continues, the music stops and comes back.
6. **Save and resume:** close the tab mid-day and mid-night, reopen; settings (mute) survive New game.
7. **Audio unlock:** silent until the first touch, then music and sounds; mute in the settings panel; the silent
   switch.
8. **Onboarding:** from a fresh start, the pointer gets you through night 1 and the first day without reading more
   than three words.
9. **Feel:** kills, sales and builds react; the screen shake when the diner is hit is not too much.

## Gate questions

From the specs' playtest questions (ask yourself, then S6 friends):

- **S1 gate (spec 1):** see `docs/superpowers/specs/2026-09-30-s1-vertical-slice-design.md` for the slice's own
  questions; in short, is one night and one day fun enough to play again?
- **S2:** Did you understand each card before picking? Did any pick feel wasted? Did the Archer and Tank feel like
  part of the defense? When the Tank went down and came back, did it make sense?
- **S3:** After reopening the page, did the game continue where you expected? Did a retry after a lost night feel
  fair, and did you notice the weaker monsters?
- **S4:** Could you always tell which character was you? Did the monsters look dangerous and the steaks like food?
  Did the diner and defenses look like they grew? Was anything hard to see at night?
- **S5:** Did you know what to do in your first minute without reading? Did the sound fit? Did kills, sales and
  builds feel satisfying? Did you find the mute button?

## Media

- Video: [gameplay.mp4](media/final/gameplay.mp4); frames at
  [10 s](media/final/gameplay_frame_10s.jpg), [50 s](media/final/gameplay_frame_50s.jpg),
  [61 s](media/final/gameplay_frame_61s.jpg), [75 s](media/final/gameplay_frame_75s.jpg).
- Before/after of each major screen and one shot per lane: [before_after.md](media/before_after.md) (42 links, all
  resolve).
- Style board: [s4_style_board](media/s4_style_board/README.md). Audio list: [AUDIO.md](AUDIO.md).

## One line per sub-project

| | What shipped | Main decisions | Tests at the end |
|---|---|---|---|
| S1 Vertical slice | Three lanes, Boars, steaks, counter and travelers, towers and fences, phases, HUD, web export and CI | Layout and architecture rules, deterministic sims, D-133 workflow | See the S1 spec results |
| S2 Cards and guards | Dawn card pick, five upgrades, Archer and Tank | Cards by tapping panels (D-162); guard posts (D-163/164); difficulty retuned for cards (D-170) | 393 unit, 8 sim |
| S3 Save, resume, mercy | Autosave, instant resume, night retry with mercy | Resume without a menu (D-176); mercy 15% per fail, floor 40% (D-175) | 449 unit, 9 sim |
| S4 Art pass | Asset pipeline and validator, one palette, KayKit cast, procedural Boar, baked world, UI theme and icons | Style board (D-186); draw-call discipline (D-201) | 688 unit, 9 sim |
| S5 Polish | Audio, juice, boot warm-up and fade, settings and New game, safe-area HUD, onboarding Guide | Audio by measurement (D-211/212); one-draw FX (D-214); state-only Guide (D-213); perf findings (D-215, D-220) | 865 unit, 11 sim |

## What happens next

Nothing until you review. S6 (friend playtests) starts only after you approve; the things to change first are yours
to pick from the queue above.
