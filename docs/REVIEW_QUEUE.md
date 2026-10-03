# Review queue

Decisions the author may want to reverse at the final review (D-159): player-facing feel, balance targets, art
direction, and anything that deviates from IDEA.md. Ranked by impact, highest first. One line each.

1. Art direction: KayKit Adventurers cast (chef-hatted Barbarian as the hero), Kenney rounded kits, and a procedural tusked Boar. Quaternius characters (named in IDEA.md) were rejected on the style board — [D-186](DECISIONS.md), [board](review/media/s4_style_board/README.md)
2. All audio (SFX and both music tracks) was chosen without listening; swap any line in `art/audio/audio_manifest.gd` (list: `docs/review/AUDIO.md`) — [D-211](DECISIONS.md)
3. The hero is a cook who throws spinning kitchen knives (IDEA doesn't say how the hero attacks; a pan is held for the look) — [D-191](DECISIONS.md)
4. Boar: red-brown procedural tusked boar; tusks only small white flares at phone size (bigger tusks cost readability of the face) — [D-202](DECISIONS.md)
5. Onboarding is one bouncing pointer with ≤ 3 words for night 1 and day 1, then never again on that device — [D-213](DECISIONS.md)
6. Night look: darker blue moonlight (about half the day's light); the grey diner roof reads slate-blue at night; the hero's white stays white — [D-194](DECISIONS.md), [D-206](DECISIONS.md)
7. The diner has a flat roof with a parapet so the Archer can stand on it (a gabled roof reads more 'diner', but hides the Archer) — [D-194](DECISIONS.md)
8. Diner look: grey gravel flat roof with teal trim, rooftop DINER board, cream awning band, ice-blue freezer — [D-204](DECISIONS.md)
9. Towers and fences grow by changing model per level; the old 10% size-up per level is off (`build_level_scale` 1.0) — [D-197](DECISIONS.md)
10. Occluder fade alpha default 0.45 (picker cycles 0.30/0.45/0.60 in /debug/) — [D-151](DECISIONS.md), [D-159](DECISIONS.md)
11. Fence L1 vs L2 differ only by thickness and posts (both wood); L3 is stone — [D-205](DECISIONS.md)
12. UI look: cream cards with rendered portraits, icon card strip, coin/heart/moon HUD icons, bold Nunito; gold counter shifted right for the coin — [D-207](DECISIONS.md), [D-208](DECISIONS.md)
13. Hero knife projectile is oversized (~0.7 m) so it reads in flight at phone size — [D-200](DECISIONS.md)
14. Hero wears a full white chef coat (white sleeves): baked onto one atlas for one draw call — [D-201](DECISIONS.md)
15. Travelers are single-toned (hair included) and the Rogue/Mage bodies read alike without props — [D-191](DECISIONS.md)
16. Telegraph flag reads as a thin red stick at phone size — [D-205](DECISIONS.md)
17. Coin is a procedural gold disc (stacks look slightly olive in shade) — [D-208](DECISIONS.md)
18. Ground steaks drawn 1.6x bigger than pile steaks so they read on the ground at phone size — [D-203](DECISIONS.md)
19. Carried steaks stack behind the hero's head (tighter, 0.09 m) instead of in front — [D-203](DECISIONS.md)
20. The player's hero is never targeted and has no HP; only guard heroes take damage (IDEA reading) — [D-161](DECISIONS.md)
21. Cards are picked by tapping panels (not by standing on pedestals) — [D-162](DECISIONS.md)
22. Day length left at the bot's lower bound (day-2 cycle 199 s for a perfect bot; 4–6 min judged by you). Longer days = `traveler_interval` 2.5 → 4.4, which only adds waiting — [D-160](DECISIONS.md), [D-066](DECISIONS.md)
23. Target difficulty with cards: a perfect bot first fails at day 10 ± 1 (with mercy it then keeps going) — [D-170](DECISIONS.md), [D-178](DECISIONS.md)
24. Late-game gold has no use: all builds max out around day 7 and gold piles up (IDEA: towers/fences are the only sink) — [D-180](DECISIONS.md)
25. With mercy no run ever ends (all seeds survive 14 days, every lost night clears within 3 retries); late-game has no end state or goal — [D-175](DECISIONS.md), [D-178](DECISIONS.md)
26. Night 2 difficulty varies by seed (a perfect bot ends it at 52–100% diner HP); thresholds are pinned on one seed — [D-180](DECISIONS.md)
27. Closing the tab mid-night loses that night (resume at its start), but only real failures add mercy; alternative: count quits too (farmable, and it greets night-1 bouncers with "monsters look tired") — [D-174](DECISIONS.md)
28. S1 difficulty: the PlannerBot sweep breaks at day 8; S2 re-tunes wave scaling for cards — [D-155](DECISIONS.md), [D-156](DECISIONS.md)
29. Guard posts: the Tank holds the west lane, the Archer sits on the roof and can never be hit — [D-163](DECISIONS.md), [D-164](DECISIONS.md)
30. Upgrade card sizes (+20% damage, +15% attack speed, +8% move, +2 carry, +1 gold per level) — [D-167](DECISIONS.md)
31. Mercy is invisible except a flavor line (15% weaker per failed retry, floor 40%) — [D-175](DECISIONS.md)
32. Reopening the page resumes instantly with no title/continue menu; release has no New game until S5 — [D-176](DECISIONS.md), [D-177](DECISIONS.md)
33. Fences only stop Boars (they are a target kind, not walls) — [D-148](DECISIONS.md)
34. Camera keeps the portrait vertical view on wide windows; aspects clamped to 9:21..21:9 — [D-145](DECISIONS.md), [D-153](DECISIONS.md)
35. A new game spawns the hero north of the diner; HOME at (0, 9.5) — [D-122](DECISIONS.md), [D-126](DECISIONS.md)
36. Towers don't collide with the hero — [D-125](DECISIONS.md)
37. Focus pause also triggers on window focus loss — [D-147](DECISIONS.md)

## Final review playtest questions (S2)

1. Did you understand what each card did before you picked it?
2. Did any pick feel wasted or useless?
3. Did the Archer and the Tank feel like part of your defense?
4. When the Tank went down and came back, did you notice, and did it make sense?

## Final review playtest questions (S3)

1. After closing and reopening the page, did the game continue where you expected?
2. After losing a night, did the retry feel fair? Did you notice the monsters were weaker?

## Final review playtest questions (S4)

1. At a glance, could you always tell which character was you?
2. Did the monsters look dangerous, and did the steaks look like food?
3. Did the diner and the defenses look like they grew as you upgraded them?
4. Was anything hard to see at night?

## Final review playtest questions (S5)

1. Did you know what to do in your first minute without reading anything?
2. Did the sound fit? Was anything too loud, too quiet or annoying?
3. Did kills, sales and builds feel satisfying?
4. Did you find the mute button when you wanted it?

## Known issues (collected for the final review)

1. Day phase runs at about 52 fps in the iOS Simulator (night about 58). Not the gate (night only); cause unresolved after three spikes (D-199); S5 perf work.
2. There is a stall of about 115–140 ms when the first wave of a night spawns (S4 final; 280–300 ms before the S4 bake). The cause is unproven (first-use shader or pool cost); S5 Task 7 attributes it, then warms up.
3. One-time WebGL warnings (`bindBuffer: element array buffers can not be bound to a different target`, `bufferSubData: no buffer`) appear about 15–45 s into night 1 on Chromium; pre-existing on S3 main, nothing visibly wrong. S5 check.
4. Music is kept as decoded samples, each registered on first use (`lazy`, D-212): about 36–39 MB of audio buffers plus a WASM high-water rise during registration, and a 60–70 ms registration at the first tap and the first dawn. Godot 4.7.2 cannot release a sample, so one-track-at-a-time leaked; stream playback would glitch on long frames. Watch memory on a low-end phone at the final review (`AudioManifest.MUSIC_MODE`).
5. The iOS silent switch may mute Web Audio (unverified); it affects playtest question 2 on iPhones.
