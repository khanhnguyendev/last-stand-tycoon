# Review queue

Decisions the author may want to reverse at the final review (D-159): player-facing feel, balance targets, art
direction, and anything that deviates from IDEA.md. Ranked by impact, highest first. One line each.

1. Occluder fade alpha default 0.45 (picker cycles 0.30/0.45/0.60 in /debug/) — [D-151](DECISIONS.md), [D-159](DECISIONS.md)
2. The player's hero is never targeted and has no HP; only guard heroes take damage (IDEA reading) — [D-161](DECISIONS.md)
3. Cards are picked by tapping panels (not by standing on pedestals) — [D-162](DECISIONS.md)
4. Day length left at the bot's lower bound (day-2 cycle 199 s for a perfect bot; 4–6 min judged by you). Longer days = `traveler_interval` 2.5 → 4.4, which only adds waiting — [D-160](DECISIONS.md), [D-066](DECISIONS.md)
5. Target difficulty with cards: a perfect bot breaks at day 10 ± 1 — [D-170](DECISIONS.md)
6. Closing the tab mid-night loses that night (resume at its start), but only real failures add mercy; alternative: count quits too (farmable, and it greets night-1 bouncers with "monsters look tired") — [D-174](DECISIONS.md)
7. S1 difficulty: the PlannerBot sweep breaks at day 8; S2 re-tunes wave scaling for cards — [D-155](DECISIONS.md), [D-156](DECISIONS.md)
8. Guard posts: the Tank holds the west lane, the Archer sits on the roof and can never be hit — [D-163](DECISIONS.md), [D-164](DECISIONS.md)
9. Upgrade card sizes (+20% damage, +15% attack speed, +8% move, +2 carry, +1 gold per level) — [D-167](DECISIONS.md)
10. Mercy is invisible except a flavor line (15% weaker per failed retry, floor 40%) — [D-175](DECISIONS.md)
11. Reopening the page resumes instantly with no title/continue menu; release has no New game until S5 — [D-176](DECISIONS.md), [D-177](DECISIONS.md)
12. Fences only stop Boars (they are a target kind, not walls) — [D-148](DECISIONS.md)
13. Camera keeps the portrait vertical view on wide windows; aspects clamped to 9:21..21:9 — [D-145](DECISIONS.md), [D-153](DECISIONS.md)
14. A new game spawns the hero north of the diner; HOME at (0, 9.5) — [D-122](DECISIONS.md), [D-126](DECISIONS.md)
15. Towers don't collide with the hero — [D-125](DECISIONS.md)
16. Focus pause also triggers on window focus loss — [D-147](DECISIONS.md)
