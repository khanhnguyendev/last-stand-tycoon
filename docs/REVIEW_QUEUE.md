# Review queue

Decisions the author may want to reverse at the final review (D-159): player-facing feel, balance targets, art
direction, and anything that deviates from IDEA.md. Ranked by impact, highest first. One line each.

1. Art direction: KayKit Adventurers cast (chef-hatted Barbarian as the hero), Kenney rounded kits, and a procedural tusked Boar. Quaternius characters (named in IDEA.md) were rejected on the style board — [D-186](DECISIONS.md), [board](review/media/s4_style_board/README.md)
2. All audio (SFX and both music tracks) was chosen without listening; swap any line in `art/audio/audio_manifest.gd` (list: `docs/review/AUDIO.md`) — [D-211](DECISIONS.md)
3. The hero is a cook who throws spinning kitchen knives (IDEA doesn't say how the hero attacks; a pan is held for the look) — [D-191](DECISIONS.md)
4. Boar: red-brown procedural tusked boar; tusks only small white flares at phone size (bigger tusks cost readability of the face) — [D-202](DECISIONS.md)
5. Onboarding is one bouncing pointer with ≤ 3 words for night 1 and day 1, then never again on that device — [D-213](DECISIONS.md)
5c. Guide details: a hero carrying steaks who walks through the freezer zone sees "Take steaks" briefly (the spec's hold rule); near the top of the screen the Guide shows its edge arrow on the target instead of the world pointer — [D-213](DECISIONS.md)
5b. Particle sizes, counts and colours (`FxField.KINDS`) were tuned from screenshots, not on a phone; running dust is subtle by design — [D-214](DECISIONS.md)
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

## E1 station upgrades (2026-10-05)

Reversible decisions from the E1 build, highest impact first. Media: `docs/review/media/e1/`.

1. Station upgrades are a mid-game gold sink: with defense bought first, a player has 8 to 38 gold left in days 1 to 3, so the first levels land around days 2 to 7 (upgrader sweep). Too late to feel? And station spending eats carry-over gold, so some mid-game nights run closer (night 9, seed 20260930: diner 3% against 8%) — [D-230](DECISIONS.md), [D-231](DECISIONS.md)
2. The freezer upgrade is comfort (fewer trips, more night pickup), not day speed — [D-224](DECISIONS.md), [D-230](DECISIONS.md)
3. No per-level station art: a level shows as a pop, a sparkle and star pips on the pad — [D-229](DECISIONS.md)
4. Each pad shows its station's name above the cost ("Counter", "Freezer"); the freezer pad is off screen when the hero stands at the sign — [D-231](DECISIONS.md), `e1/shots_head/day3_counter0.png`, `e1/shots_head/day3_counter5.png`
5. A long queue (5 to 9 travelers) forms a second row on the road's north edge, around the hero's home spot — [D-230](DECISIONS.md), `e1/task06/level5.png`
6. A full carry (26 steaks: all carry cards plus a max freezer) is a tall stack that covers the "Close up" label when the hero stands by the sign; not capped — `e1/task06/level5.png`
7. The traveler pool is 31 instead of 8, so travelers appear in a different look order than before E1 (visual only) — [D-231](DECISIONS.md)
8. Known issue: a level 5 counter day runs about 5 to 9 fps below a level 0 day in the iOS Simulator (39 to 43 against 48 on a loaded Mac; not a valid gate reading; the idle re-run is postponed by the author, D-235). Options if it holds: cap the queue at 6 or 7, or cheaper traveler visuals — [D-231](DECISIONS.md)
9. Load time with the 31-traveler pool measured (engine start median 4.05 s against D-221's 3.70 s on a non-idle Mac, within D-221's spread) and the emulated Android check done; memory with the pool is still unmeasured (no tooling) — [D-235](DECISIONS.md), `e1/load/`, `e1/device_main/`
10. Playtest question: "Did you notice you could upgrade the counter and the freezer? Did you want to?"
11. Follow-up: a saved station level above `max_level` is clamped on load (D-234), but a saved tower or fence level above `build.max_level` is still rejected (`SaveCodec.validate`). Lowering `build.max_level` later would lose saves; same fix as D-234 if it ever matters.

## E5 diner tier ladder, slice 1 (2026-10-06)

Reversible decisions from the E5 build, highest impact first. Media: `docs/review/media/e5/`. Decisions: D-236 to D-259.

1. **The tier-2 diner reads only slightly grown.** It is the tier-1 diner plus two thin cream terraces; awnings were removed because any awning near the walls hides monsters, tower bases or the hero under the top-down camera. Growth is carried by the yards, the two towers and the reveal. A stronger "the diner grows" needs real art (a second storey, a bigger sign, new kit pieces) — [D-254](DECISIONS.md), `e5/task11/diner_t2_home_day.png`
2. **Yards look like lane stubs.** They use the lanes' dirt and edge stones; a paved cream or stone patio would read as diner property — [D-255](DECISIONS.md), `e5/task10/yards_west.png`, `e5/task10/yards_east.png`
3. **The tier sign is small and off screen from the home spot** (it stands on the west yard's edge, x −10). Nothing points at it; the Close-up sign simply stops pulsing while the tier is affordable. Candidates: a taller sign, an edge arrow, a one-time Guide hint — [D-240](DECISIONS.md), `e5/task09/`
4. **Tier 2 is the top of this slice, and gold piles up again within about two days** (223 → 3,999 unspent from day 14 to day 20 on seed 20260930). Tier 3 removes it — [D-245](DECISIONS.md), `e5/sweep/README.md`
5. **Tier-2 cost 500.** The tier bot maxes its defense by day 8, buys station levels on days 9 to 11 and pays in the day phase before night 12 or 13, which is then the boss night. Lower the cost or let the bot (and the player) pay in parts if that is too late — [D-258](DECISIONS.md)
6. **The boss night is lost once and won on the retry on two of three seeds** (with one mercy step). Is one loss the right "test you can prepare for", or should a maxed tier-1 defense win first time? Boss: 800 HP × 1.9 at the cap, 15 damage a second, speed 1.2 — [D-242](DECISIONS.md), [D-258](DECISIONS.md)
6b. **The cap-hold margin is thin on one seed.** A full tier-2 build at the cap clears with the diner at 4% in the sim (seed 20260930) and 12% on its worst sweep night; the other seeds hold at 28% to 93%. If a full build should hold comfortably, lower `tier_cap[2]` from 11 to 10 (the fixtures, sims and sweep then need re-running) — [D-244](DECISIONS.md), [D-258](DECISIONS.md)
7. **The reveal:** the camera leaves the hero, frames the diner and both yards (zoom 2.15), five beats 0.35 s apart with the build sound and dust, back to the hero at 3.0 s when the card pick opens. On very tall or very wide windows the pulled-back view shows up to 20 m past the ground mesh edge for those 3 seconds — [D-256](DECISIONS.md)
8. **The hare** is a small, lean, light-red monster with two long laid-back ears; it is small on screen and reads muted red rather than pink. Its legs swing at the Boar's rate — [D-252](DECISIONS.md), `e5/task07/`
9. **The Boar King** is a 2.2 m dark boar with four stone tusks and a red HP bar; no sound of its own (it uses the Boar's) — [D-246](DECISIONS.md), `e5/task07/`
10. **The boss moon** is the third moon drawn 1.3× in red, breathing while the boss lives; no boss-night HUD shot was taken — [D-238](DECISIONS.md)
11. **Texts:** "Open the yards" + cost, "Boss tonight", "The Boar King comes", "The diner grows!" — [D-238](DECISIONS.md), [D-243](DECISIONS.md)
12. **Props standing in a yard are hidden** when the yard opens (five trees and rocks at tier 2) instead of being moved — [D-255](DECISIONS.md)
13. **The east yard is small** (5 × 3.5 m against the west yard's 4.5 × 10.5 m): the props and the 3 m rule shaped it — [D-240](DECISIONS.md)
14. **Existing saves past day 7 at tier 1 get easier nights after the update** (day-7 pressure) — [D-237](DECISIONS.md)
15. Lane strips and lane edge stones draw across the cream terraces where the west and east lanes meet the wall — `e5/task11/diner_t2_west_zone_night.png`
16. Playtest question: "Did you understand what the sign was selling, and did the boss night feel like a test you could prepare for?"

Not measured in this slice: perf on the iOS Simulator for the `tier2_night` and `boss_night_tier1` fixtures (spec 8.4), and the device check of the sign, the boss bar and the boss moon (one attempt timed out on a loaded Mac). Both wait for the end of the build (D-260); the phone checklist and the open items are in `docs/E5_FOLLOWUPS.md`.

## E5 slice 2: diner tier 3 (2026-10-07, in progress)

Reversible decisions from the tier-3 build, highest impact first. Media: `docs/review/media/e5t3/`. Decisions: D-261 to D-276. This list grows until the phase-5 checkpoint (`docs/review/E5_T3.md`).

1. **The tier-2 cap is 10, not 11.** A full tier-2 build lost the cap night on 2 of 10 seeds at 11; at 10 it holds on 10 of 10 (median diner HP left 69%, lowest 18%). Players already at tier 2 get a lighter cap night — [D-276](DECISIONS.md)
2. **The tier-2 diner is not taller than tier 1.** Anything tall on the roof hid the Archer or a tower pad from some camera positions, so tier 2 reads through a wood roof, a second chimney and a cream board; the height change comes with tier 3's second storey. Is the tier-2 change strong enough? — [D-276](DECISIONS.md), `e5t3/growth/diner_t1.png`, `diner_t2_before.png`, `diner_t2_after.png`
3. From the home view the tier-1 "DINER" plank hides most of the new sign board (about 0.3 m shows); it reads fully only from the north — `e5t3/growth/diner_t2_after_north.png`
4. **Yards** are paved cream with a low dark kerb and crates, barrels and a bench (procedural shapes, not pack models). The east yard keeps 8 of 12 kerb pieces (its west edge is open by the tower pad); the west yard has a 3.9 m kerb gap at its tower pad. The hero's white hat has less contrast on cream than on dirt — `e5t3/growth/yards_after_west.png`, `yards_after_east.png`
5. **The tier sign** has a larger board and a label about 49 px tall (was 30). The label sits 4.3 m up and is drawn over everything, so it covers the ground about 3 to 6 m north of the sign, and its first line sits over a grey rock — `e5t3/growth/sign_before.png`, `sign_after.png`, `sign_after_on.png`, `sign_after_north.png`
6. **Longbow fires 120 damage every 3.0 s** (first proposed 45 per 1.0 s). The slow, heavy shot is what keeps "Longbow kills the fewest hares" true at the cap, where hares reach 73 HP. Against a lone brute it ties the unbranched tower on 3 of 12 waves — [D-276](DECISIONS.md)

7. **Branch pads sit tight.** With yard props and kerbs counted, the worst pad clearance is 0.15 m, and four towers have both pads on one side. To be judged on the pad screenshots of the world phase — [D-277](DECISIONS.md)
8. **All side-lane brutes arrive in one night,** the same night pressure reaches the tier-3 cap (main-lane brutes ramp 1, 2, 3 before it) — [D-277](DECISIONS.md)
9. **Buying a Stone wall fully repairs the fence.** Cheap repair by design, or should it keep its damage? — [D-277](DECISIONS.md)
10. At tier 2 the hare share still ramps over 3 days while pressure now caps after 2, so the first cap night is slightly lighter on hares — [D-277](DECISIONS.md)
11. The boot warm-up now builds more (kerb, placeholder monster meshes, every tier's ground after the switch); its cost is unmeasured until the final perf run — [D-277](DECISIONS.md)

12. **Tonight's count rows hide under the HUD from the home spot.** They read well near a lane. Options: move the day HUD, lift the tower labels, or a HUD summary of tonight's lanes — [D-278](DECISIONS.md), `e5t3/telegraph/day_tier3_home.png`, `day_tier3.png`
13. **The siege brute** is a stocky, redder boar at 80% of the Boar King's size; its fence thump is the diner-hit sound pitched down and its dust is hard to see (grey on grey) — [D-278](DECISIONS.md), `e5t3/monsters/brute.png`, `brute_vs_king.png`, `brute_fence.png`
14. **Baron von Hop** is a saturated red giant hare; its crown reads as a grey comb and its ears as antennae from the front; it hops and lunges with the Boar's values — `e5t3/monsters/baron.png`
15. **The Boar King's bar now shows its name** (tier 1 too), and tier 2's boss banner says "Baron von Hop comes" — [D-278](DECISIONS.md)
16. **Spike fence scaling** follows the night's first wave, so it is weaker against the last wave (64% at the cap) and ignores mercy — [D-278](DECISIONS.md)
17. **Respawned guards:** protected for 1.5 s (respawns only), still attacking (at most 2 swings). Without protection a respawning guard absorbed up to 15 of the diner's 300 HP in the SW zone. Disable the attacker while protected? — [D-278](DECISIONS.md)
18. A Longbow shot whose target dies in flight is wasted with its 3 s cooldown; the brute mark on an edge arrow shows for the whole remaining night's brutes on that lane — [D-278](DECISIONS.md)
19. **Branch pads show information in stages** (far: ring and icon; within 3.5 m: cost; on the pad: name, effect, preview; the sibling pad goes quiet). Distances 3.5 / 4.5 m. Shots: `docs/review/media/e5t3/pads/` (`dawn_all_pads`, `near_stage`, `pad_<spot>_a|b`) — [D-279](DECISIONS.md)
20. **Small pad-label overlaps remain, each pinned exactly in a test.** On a pad (12): `fence_w` B and `fence_e` A (icon or cost on the level pips, about 37 x 23 px); `tower_e` A's effect line over the freezer pad's labels (up to 70 x 36 px); six at `fence_sw` B, the worst being "Spike fence" over the "Close up" label (90 x 27 px; `pad_fence_sw_b.png`) and "hurts attackers" over the counter's count. Near stage: the two cost blocks touch at `tower_e`, `tower_ne` and `tower_nw` (pads 2 m apart, up to 24 px), and at `fence_sw` in portrait a block clips the left screen edge (33 px from HOME's side; 147 px when the hero stands far west of the pads, the largest open finding). On `fence_n` A the warning line touches two lane count rows by 2 px. The cost text reads at least 28.46 px (floor 28). Clearing these needs pads moved or a different near layout — [D-279](DECISIONS.md)
21. **The tier-2 sign reads "Buy the lot"** ("Buy the front lot" did not fit), at (-4.7, 8.5) — [D-279](DECISIONS.md)
22. **Tap skips the reveal after 0.6 s**, on the tier-2 reveal too; the tier-3 reveal has five steps and a modest pull-back (zoom 1.30); pads appear with the first tier-3 day, not in the reveal — [D-279](DECISIONS.md)
23. **Lane count rows hide while under the HUD bar** (visible at tier 1: from the home spot the three northern rows are hidden) — [D-279](DECISIONS.md)
24. **Tier-3 look:** DINER on the storey wall (no roof plank), the Archer can be seen through the faded diner, landscape views are exempt from the occlusion rule beyond 10 m, the east queue is tight, Stone wall against a level-3 fence and the Volley's barrels are the least distinct models — [D-279](DECISIONS.md)
25. **Tier-3 difficulty was lowered:** pressure cap 15 -> 12 and brutes on the main lane only. Before: retries on 20 of 31 cap nights in real bot play. After: 0 of 40. Tier 3 now starts at its cap and no longer ramps in pressure. Two early nights on one seed are held at 1% and 4%. With the cap equal to the base, the rule that Spike fence damage grows with the night's HP multiplier (D-272.1) no longer does anything in live play — [D-280](DECISIONS.md)
26. **Branches don't reward reading the telegraph (so far):** on the cap-night fixture the diner ends at 77% with Volley + Spike everywhere, 76% with Longbow + Stone, 74% with the threat-matched policy and 52% with the mixed one. The 25-point gap suggests a weak combination (Longbow towers with Spike fences) — [D-280](DECISIONS.md)
27. **No gold sink at tier 3:** the bot holds 6,000 to 12,000 unspent gold by day 32. A fence fell on every cap night before the tuning, and each lost fence drops its branch, which the bot re-buys daily — [D-280](DECISIONS.md)
28. **The bot reaches tier 3 late** (day 18 to 22), because it buys every station level and defence first; the policy "mixed" was defined by me — [D-280](DECISIONS.md)

## Final review playtest questions (S5)

1. Did you know what to do in your first minute without reading anything?
2. Did the sound fit? Was anything too loud, too quiet or annoying?
3. Did kills, sales and builds feel satisfying?
4. Did you find the mute button when you wanted it?

## Known issues (collected for the final review)

1. Day phase runs at about 53 fps in the iOS Simulator (night about 59.9). Final reading: day-3 52.9 against S4 main's 54.0, 0.1 fps under the no-regression gate (0.4 under at the end of S5); `docs/review/media/final/perf.md`. Cause of the day cost unresolved (D-199).
2. Night-3 worst frame is 106 ms in the final reading (85 / 107 / 106; gate < 60; S4 main 119); 71 ms at the S5 P2 checkpoint and 108 ms at the end of S5. It lands about 2.1 s after the night starts, before any wave, at the same moment the first banner ("The monsters return", 2 s) hides and the perf overlay's window opens; the cause is unproven (S5 Task 7, `docs/review/media/s5/perf_p2/README.md`). A load freeze of 0.84–0.90 s right after the phase starts now happens under the boot fade, which holds until frames are stable (D-215 amendment); on a real phone check that the fade covers it. Taps pass through the fade while it holds (handlers hit-test themselves, and audio unlock needs the first release); the card guard outlasts a normal hold, but on a device that never reaches stable frames the 4 s cap could leave cards tappable while covered.
3. ~~WebGL warnings at every wave on Chromium~~ fixed in S5 Task 9: the HUD's two `Polygon2D` lane arrows caused them (`docs/review/WEBGL_WARNINGS.md`); the arrows are now drawn from the icon atlas, and a 100 s Chromium night-1 run shows neither warning.
4. Music is kept as decoded samples, each registered on first use (`lazy`, D-212): about 53–56 MB of audio buffers in Chromium steady, peaking at about 72.6 MB (76.2 MB of all buffers) right after each music switch before GC (both registered tracks plus a playback copy of the playing one; more at 48 kHz on iOS), plus a WASM high-water rise during registration, and a 60–70 ms registration at the first tap and the first dawn. Godot 4.7.2 cannot release a sample, so one-track-at-a-time leaked; stream playback would glitch on long frames. Watch memory on a low-end phone at the final review (`AudioManifest.MUSIC_MODE`).
5. The iOS silent switch may mute Web Audio (unverified); it affects playtest question 2 on iPhones.
