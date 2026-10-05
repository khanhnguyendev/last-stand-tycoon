# Last Stand Tycoon v0.1: final review

Built without the author from S1 to S5 (D-159). This page is what to check before S6 (friend playtests).

## Summary

- **Play it:** release https://khanhnguyendev.github.io/last-stand-tycoon/ · debug
  https://khanhnguyendev.github.io/last-stand-tycoon/debug/ · profile (perf overlay)
  https://khanhnguyendev.github.io/last-stand-tycoon/profile/. All three serve main `23b7d7b`. After this branch
  merges, the debug build also takes `?autoplay=1` (a bot plays; it takes the hero from you and autosaves over the
  /debug/ save) and `?nooverlay=1`. The build label in the corner says which commit a page serves.
- **Watch it:** [gameplay.mp4](media/final/gameplay.mp4) (84 s, a x2.2 time-lapse, silent, iOS Simulator, a bot
  playing a debug build): the whole first cycle, from the night-1 banner through three waves, the dawn card pick, the
  day (hauling, sales, a build) to the start of night 2. The same span in real time (185 s):
  [gameplay_full.mp4](media/final/gameplay_full.mp4). The capture has no audio track, and the speed is not labelled
  on screen (this ffmpeg has no text filter).
- **What it is:** the v0.1 scope of IDEA.md. Nights of Boars on three lanes, steaks to sell by day, towers and fences
  to build, dawn cards (upgrades, Archer, Tank), save and resume, mercy after a lost night, one cohesive CC0 look,
  sound, juice, a settings panel and a pointer that teaches the first night and day.
- **State of the code:** 867 unit tests and 11 sims pass (sim suite 14 s of 60 s); the determinism baseline is
  identical; CI (`unit`, `sim`, Pages `deploy`) is green on main.
- **What did not meet its gate:** two perf gates (below). **What nobody has checked:** how it feels on a real phone,
  and how it sounds; all audio was chosen without listening.

## What to decide first: REVIEW_QUEUE top 10

Full list: [REVIEW_QUEUE.md](../REVIEW_QUEUE.md) (39 entries: 1–37 plus 5b and 5c, ranked).

1. Art direction: KayKit cast with a chef-hat hero, Kenney rounded kits, a procedural tusked Boar (D-186).
2. All audio chosen without listening; every sound is one line in `art/audio/audio_manifest.gd` (D-211,
   [AUDIO.md](AUDIO.md)).
3. The hero is a cook who throws kitchen knives (D-191).
4. The Boar's look; tusks are small at phone size (D-202).
5. Onboarding is one pointer with at most three words for night 1 and the first day, then never again (D-213).
   Ranked right after it: 5c (Guide details: the brief "Take steaks", the edge arrow) and 5b (particles tuned from
   screenshots, not on a phone; D-214).
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
3. A load freeze of 0.84–0.88 s (final night runs) right after the phase starts. The boot fade now holds over it;
   confirm on a phone. Taps pass through the fade; on a device that never reaches stable frames the 4 s cap could
   leave cards tappable while covered.
4. Music is kept as decoded samples: 53–56 MB steady in Chromium, 72.6 MB peak after a switch (D-212). Watch a
   low-end phone.
5. The iOS silent switch may mute Web Audio (unverified).
6. Perf is measured in the iOS Simulator on a Mac that other work shares. No real phone has been measured.

Fixed during S5: the WebGL warnings on Chromium (the HUD's `Polygon2D` arrows).

## Sim and sweep results

- Unit 867/867 (865 before the two debug tests added with this package), sim 11/11 (12–14 s), baseline identical: [unit](media/final/unit.txt), [sim](media/final/sim.txt),
  [baseline](media/final/baseline_diff.txt).
- Sweep, PlannerBot, seeds 20260930, 1, 2 (S2–S4 and the baseline used 20260930, 11, 777; the 20260930 output is
  byte-identical to the S4 baseline) ([sweep.md](media/final/sweep.md)): every seed plays all 14 days. First
  failed night: day 10, 9, 9 (target 10 ± 1). Nights 1–8 clear without a retry on every seed; lowest diner margin
  before day 9 is 0.42.
- **Mercy target (author):** median retries per night 0, none needing more than 2 before day 8. Result: median 0,
  max before day 8 is 0, max overall 3. Met.
- Onboarding sim: a bot that only follows the Guide clears night 1 with 0 fails on two seeds and builds 3 spots by
  night 2.

## Perf, size, load

iOS Simulator (iPhone 17 Pro), profile build, median of 3, Mac ≥ 75% idle before each run; mid-run idle 50–66%, and
two S4-main runs waited 12 and 25 cycles for idle, so the Mac was not quiet ([perf.md](media/final/perf.md)):

| | v0.1 | S4 main | Gate | Verdict |
|---|---|---|---|---|
| Night-3 avg fps | 59.9 | 59.7 | ≥ 58 | Pass |
| Night-3 worst frame | 106 ms | 119 ms | < 60 ms | **Fail** |
| Day-3 avg fps | 52.9 | 54.0 | ≥ S4 − 1 | **Fail by 0.1** |

- Draw calls on desktop: night 28, day 50; +1 while particles are alive (S5 reading, not re-measured). In the
  Simulator in the final runs: night 36, day 65 (S4 main 36 and 64).
- Release size ([load_size.md](media/final/load_size.md)): pck 5.26 MiB (gate 8); wasm + pck + js gzipped 13,808,603 B, 13.17 MiB
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
10. **Load:** time from page open to playable, and from page open to first combat (S1 spec §16).
11. **Fps:** on /profile/, read the frozen `PERF phase=NIGHT` line at night 3; note the phone model, average fps and
    worst frame (S1 criterion 4: ≥ 58, no frame over 100 ms).
12. **Cycle length:** time one night plus day while building (target 4–6 min; D-066, D-160).

## Gate questions

From the specs' playtest questions (ask yourself, then S6 friends):

- **S1 gate (spec §14.1, criterion 5):** The author plays 3 cycles on their phone from the GitHub Pages URL and wants
  a 4th (D-083, D-135).
- **S1 playtest questions (spec §15):** 1. Is night pickup worth it? 2. After a loss, did you feel you had agency?
  3. How long did each cycle take? 4. Did the side lanes feel readable? 5. Did you know what to do next without being
  told? 6. At which moment did you most want to keep playing, and where did it drag?
- **S1 phone criteria still open (spec §14.1, §16):** a full cycle takes about 4–6 min for a player who builds;
  profile build, night 3, 60 s of combat: average ≥ 58 fps, no frame over 100 ms, phone model recorded; real time
  from page open to first combat.
- **S2:** Did you understand each card before picking? Did any pick feel wasted? Did the Archer and Tank feel like
  part of the defense? When the Tank went down and came back, did you notice, and did it make sense?
- **S3:** After reopening the page, did the game continue where you expected? Did a retry after a lost night feel
  fair, and did you notice the weaker monsters?
- **S4:** Could you always tell which character was you? Did the monsters look dangerous and the steaks like food?
  Did the diner and defenses look like they grew? Was anything hard to see at night?
- **S5:** Did you know what to do in your first minute without reading? Did the sound fit? Was anything too loud, too quiet or annoying? Did kills, sales and
  builds feel satisfying? Did you find the mute button?

## Media

- Video: [gameplay.mp4](media/final/gameplay.mp4) (time-lapse) and [gameplay_full.mp4](media/final/gameplay_full.mp4)
  (real time). Frames: [night start](media/final/gameplay_frame_01s.jpg),
  [combat](media/final/gameplay_frame_16s.jpg), [card pick](media/final/gameplay_frame_37s.jpg),
  [day](media/final/gameplay_frame_64s.jpg), [build](media/final/gameplay_frame_76s.jpg),
  [night 2](media/final/gameplay_frame_83s.jpg).
- Before/after of each major screen: [before_after.md](media/before_after.md) (before = placeholder art, after = end
  of S4; 42 links, all resolve). The same shots on the S5 build: [media/s5/after/](media/s5/after/).
- One shot per lane (S5 build): [west](media/s5/after/lane_west.png), [north](media/s5/after/lane_north.png),
  [east](media/s5/after/lane_east.png).
- Style board: [s4_style_board](media/s4_style_board/README.md). Audio list: [AUDIO.md](AUDIO.md).

## One line per sub-project

| | What shipped | Main decisions | Tests at the end |
|---|---|---|---|
| S1 Vertical slice | Three lanes, Boars, steaks, counter and travelers, towers and fences, phases, HUD, web export and CI | Layout and architecture rules, deterministic sims, D-133 workflow | 307 unit, 8 sim (at 26a4eb9, the last S1 merge) |
| S2 Cards and guards | Dawn card pick, five upgrades, Archer and Tank | Cards by tapping panels (D-162); guard posts (D-163/164); difficulty retuned for cards (D-170) | 393 unit, 8 sim |
| S3 Save, resume, mercy | Autosave, instant resume, night retry with mercy | Resume without a menu (D-176); mercy 15% per fail, floor 40% (D-175) | 449 unit, 9 sim |
| S4 Art pass | Asset pipeline and validator, one palette, KayKit cast, procedural Boar, baked world, UI theme and icons | Style board (D-186); draw-call discipline (D-201) | 688 unit, 9 sim |
| S5 Polish | Audio, juice, boot warm-up and fade, settings and New game, safe-area HUD, onboarding Guide | Audio by measurement (D-211/212); one-draw FX (D-214); state-only Guide (D-213); perf findings (D-215, D-220) | 865 unit, 11 sim (867 with the review package) |

## What happens next

Nothing until you review. S6 (friend playtests) starts only after you approve; the things to change first are yours
to pick from the queue above.
