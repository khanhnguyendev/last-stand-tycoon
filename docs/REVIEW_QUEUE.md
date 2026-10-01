# Review queue

Decisions the author may want to reverse at the final review (D-159): player-facing feel, balance targets, art
direction, and anything that deviates from IDEA.md. Ranked by impact, highest first. One line each.

1. Art direction: KayKit Adventurers cast (chef-hatted Barbarian as the hero), Kenney rounded kits, and a procedural tusked Boar. Quaternius characters (named in IDEA.md) were rejected on the style board — [D-186](DECISIONS.md), [board](review/media/s4_style_board/README.md)
2. The hero is a cook who throws spinning kitchen knives (IDEA doesn't say how the hero attacks; a pan is held for the look) — [D-191](DECISIONS.md)
3. Night look: a blue moonlight tint at night (art choice, not in IDEA) — [D-194](DECISIONS.md)
4. The diner has a flat roof with a parapet so the Archer can stand on it (a gabled roof reads more 'diner', but hides the Archer) — [D-194](DECISIONS.md)
5. Towers and fences grow by changing model per level; the old 10% size-up per level is off (`build_level_scale` 1.0) — [D-197](DECISIONS.md)
6. Occluder fade alpha default 0.45 (picker cycles 0.30/0.45/0.60 in /debug/) — [D-151](DECISIONS.md), [D-159](DECISIONS.md)
7. The player's hero is never targeted and has no HP; only guard heroes take damage (IDEA reading) — [D-161](DECISIONS.md)
8. Cards are picked by tapping panels (not by standing on pedestals) — [D-162](DECISIONS.md)
9. Day length left at the bot's lower bound (day-2 cycle 199 s for a perfect bot; 4–6 min judged by you). Longer days = `traveler_interval` 2.5 → 4.4, which only adds waiting — [D-160](DECISIONS.md), [D-066](DECISIONS.md)
10. Target difficulty with cards: a perfect bot first fails at day 10 ± 1 (with mercy it then keeps going) — [D-170](DECISIONS.md), [D-178](DECISIONS.md)
11. Late-game gold has no use: all builds max out around day 7 and gold piles up (IDEA: towers/fences are the only sink) — [D-180](DECISIONS.md)
12. With mercy no run ever ends (all seeds survive 14 days, every lost night clears within 3 retries); late-game has no end state or goal — [D-175](DECISIONS.md), [D-178](DECISIONS.md)
13. Night 2 difficulty varies by seed (a perfect bot ends it at 52–100% diner HP); thresholds are pinned on one seed — [D-180](DECISIONS.md)
14. Closing the tab mid-night loses that night (resume at its start), but only real failures add mercy; alternative: count quits too (farmable, and it greets night-1 bouncers with "monsters look tired") — [D-174](DECISIONS.md)
15. S1 difficulty: the PlannerBot sweep breaks at day 8; S2 re-tunes wave scaling for cards — [D-155](DECISIONS.md), [D-156](DECISIONS.md)
16. Guard posts: the Tank holds the west lane, the Archer sits on the roof and can never be hit — [D-163](DECISIONS.md), [D-164](DECISIONS.md)
17. Upgrade card sizes (+20% damage, +15% attack speed, +8% move, +2 carry, +1 gold per level) — [D-167](DECISIONS.md)
18. Mercy is invisible except a flavor line (15% weaker per failed retry, floor 40%) — [D-175](DECISIONS.md)
19. Reopening the page resumes instantly with no title/continue menu; release has no New game until S5 — [D-176](DECISIONS.md), [D-177](DECISIONS.md)
20. Fences only stop Boars (they are a target kind, not walls) — [D-148](DECISIONS.md)
21. Camera keeps the portrait vertical view on wide windows; aspects clamped to 9:21..21:9 — [D-145](DECISIONS.md), [D-153](DECISIONS.md)
22. A new game spawns the hero north of the diner; HOME at (0, 9.5) — [D-122](DECISIONS.md), [D-126](DECISIONS.md)
23. Towers don't collide with the hero — [D-125](DECISIONS.md)
24. Focus pause also triggers on window focus loss — [D-147](DECISIONS.md)

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
