# E6: tier-3 retune and lane character — checkpoint pack (DRAFT)

Status: DRAFT of 2026-10-14. Sections 1 and 6 change with the author's answers to escalations 11 and 12 and with the
final hold-out run, which has NOT been run. Nothing here is a hold-out result.

Branch `e6/p4-proof` (phase 4). On `main`: phases 0 to 3 (PRs #61 to #63, #65). Open: phase A (PR #64).
Spec: `docs/superpowers/specs/2026-10-08-e6-tier3-retune-design.md`. Plan: `docs/superpowers/plans/2026-10-08-e6-tier3-retune.md`.
Decisions: D-281 to D-301. Media: `docs/review/media/e6/`. Everything ships behind `retune_enabled` (off).

## 1. What to decide

| # | Question | Evidence | My recommendation |
|---|---|---|---|
| 1 | Flip the flag? | Sections 4 to 7 | After items 2 to 4 are answered and the hold-out run is in |
| 2 | Threat-matched leads the best fixed pair by 1.7 points, not 5 | Section 6 | Change the target to "ahead on 6 of 8 seeds, mean above 0, no lane below -1" (escalation 11) |
| 3 | The unbranched reference has a first tier-3 night at 13% on the north seed | Section 6 | Exclude the reference from that target too (escalation 11) |
| 4 | Simulator fps: night gate 54.9 (58 wanted), day at HOME 43.2 (55 wanted) | Section 8 | Merge phase A; carry both to the phone review (escalation 12) |
| 5 | The measuring bot was changed twice | Section 5 | Accept; both changes are shown before and after |

## 2. What was built (flag on)

- **Lane character.** Each run draws a siege lane and a hare lane (`LaneCharacter.for_run(run_seed)`). Brutes go to
  the siege lane; the hare lane gets about 70% of the night's hares (measured 72.4%); an extra group can appear on a
  third lane, never more than three active lanes. Save schema 7.
- **Specialists.** Longbow fires every 2.0 s with the flag on (3.0 s off) and hits brutes for double; Spike fence pass
  damage 24. Volley and Stone wall are unchanged.
- **Interface.** Lane badges at the entrances, a third lane arrow, a branch card, the reveal step and three banners
  after the pick, pads with the hero drawn in front and a building's stars covered while its pad is in use.
- **Proof tools.** The lane-type bench (its own CI job), the retune report, flag-on fixtures and sims from real play.

## 3. The bench: "paying never makes it worse"

One lane, an invulnerable diner, diner HP lost at pressure 12 (lower is better):

| Lane type | Unbranched | Longbow | Volley | Stone wall | Spike fence |
|---|---|---|---|---|---|
| Siege | 1780 | 114 | 706 | 1478 | 1673 |
| Hare | 1693 | 828 | 395 | 1355 | 855 |
| Neutral | 560 | 0 | 100 | 315 | 335 |

Every floor, specialist (15%) and identity rule passes. The fence rows are the values of tuning round 1; the tower
rows are at the committed 2.0 s. Notes for you:
- On the siege lane a fence specialist is judged by how long the fence stands (Stone 68 s, Spike 30 s), D-294.6.
- The Spike floor row is a one-sided guard: Spike keeps the level-3 fence HP, so no Spike number can make it worse.
- The Longbow's brute multiplier no longer decides any bench rule at 2.0 s: its siege edge is its rate of fire.
- The Stone wall's bench edge is its HP alone.
- The bench ranks branches; it does not predict nights. Real play has two towers per lane, the hero and a 300 HP diner.

## 4. Tuning history (tuning set: seeds 1 east, 3 south-west, 4 west, 7 north; 24 real 32-day runs each)

| Step | What changed | Lead over best fixed | Retry nights (branch policies) | Lowest first tier-3 night | Fence tax | Spread |
|---|---|---|---|---|---|---|
| Round 0 | as built (Longbow 2.4 s) | +2.2 (west -4.3) | 4 | 19.7% | 19.4% | 10.4 |
| Round 1 | Longbow 2.2 s; threat buys for marked lanes first | +5.6 (west -1.6) | 0 | 12.7% | 9.7% | 4.9 |
| Trial | Longbow 2.0 s | +5.0 | 0 | 19.7% | 4.9% | 5.3 |
| Round 2 | 2.0 s; ONE purchase order for every policy; the hero holds a breached lane | +1.6 | 0 | 58.3% (4.0% unbranched) | 4.9% | 5.0 |
| Trial | round 2 with the pressure cap at 13 | +2.4 (east -0.8) | 0 | 58.3% (4.0% unbranched) | 0.0% | 9.3 |
| Round 2 on the merged branch | phase 3's pad moves included | +1.7 | 0 | 57.0% (13.0% unbranched) | 4.9% | 5.2 |

Outputs: `docs/review/media/e6/tuning/`. Two of three tuning rounds are used.

## 5. The measuring bot was changed (D-297)

The bots judge the targets, so both changes are shown plainly.
1. **Purchase order.** The bot bought branches in list order. Now, with a lane character, every branch policy buys
   siege-lane towers, hare-lane towers, the siege fence, the hare fence, then the rest. Giving this order to the
   threat policy alone produced the +5.0 and +5.6 leads above; sharing it gives +1.6. The earlier leads were mostly
   buying order, not branch choice.
2. **The hero at night.** Once a second the hero went to the lane with the most enemies and left a lane whose fence
   had just fallen. East seed, day 22, Volley + Spike: 19.7% before, 88.3% after. North seed, day 23, threat: 80.7%
   before, 58.3% after (worse on that night).
Both rules read only what a player could know (no plan, no future waves, no HP), apply only at tier 3 with a lane
character, and leave the tier-1 and flag-off baselines identical. The hero rule reads fence state on lanes outside
the player's view (review queue).

## 6. Where the targets stand (tuning set, round 2 on the merged branch; NOT the hold-out)

| Target (D-281, D-285, D-298) | Result | Verdict |
|---|---|---|
| Threat-matched lead >= 5 points | +1.7; ahead on 4 of 4 seeds; lanes +0.5 / +0.2 / +1.9 / +4.1 | fails |
| No lane with a negative lead | none | passes |
| Zero retry nights (unbranched excluded) | 0 for every policy, unbranched too | passes |
| First tier-3 night >= 25%, every policy | 13.0% unbranched (north); branch policies >= 57% | fails on the reference only |
| Fence tax <= 30% median | 4.9% | passes |
| Fixed pairs within 15 points | 5.2 (95.9 / 90.8 / 94.2 / 92.5) | passes |
| Lane-cap guard | 0 hits | passes |

Mean diner HP at dawn: threat 97.6, Longbow + Stone 95.9, Longbow + Spike 94.2, Volley + Stone 92.5, Volley + Spike
90.8, unbranched about 70.

Why the lead is small: Longbow everywhere is the wrong tool on the hare lane only, and being wrong there costs about
2 points. A hare has 15 HP against 120 Longbow damage, so no Longbow number changes that. With every branch policy
above 90%, the best fixed pair leaves at most 4 points of headroom.

**Watch item (D-298.4): unspent gold at close-up.** Before the ladder completes: median 142 to 193 a day. After it:
median 3,784 to 6,183, last day 6,784 to 11,120 (unbranched 12,598). The comparison with E5 T3 is still to be added.

## 7. Interface

Shot pack: `docs/review/media/e6/interface/final/INDEX.md` (57 images, each with a 40% copy and a blunt "reads at 40%"
column). Review queue 30 to 36. Known and left by design: a badge can be cut by the screen edge or pass under the
HUD's gold number (hiding clipped badges hid them in 48.6% of other-zone views); the reveal's badges, the third arrow,
the stars and the one tether are small at 40%; one pad shows its cost while the hero stands at HOME.

## 8. Performance (phase A, PR #64; iOS Simulator: a proxy, the phone check stays on the final review)

| Reading | fps | Wanted | Worst frame | Draw calls |
|---|---|---|---|---|
| Night entered by play, hero at HOME | 54.9 | 58 | 26 ms | 54 |
| Resumed night | 59.9 | reference | 25 ms | 40 |
| Day at HOME, tier 3, pads shown | 43.2 | 55 | 28 ms | 107 |

- The 117 ms first-fade frame is gone (dithered fade): 21 to 22 ms.
- The earlier "regression" was camera framing: the E5 T3 build also draws 78 calls at HOME.
- Every level pip is one draw (78 to 56 calls at HOME by night); that bought about 1 fps.
- By day the 29 world labels are the one large item (+6.1 fps without them, still 48.6). The night is not
  attributed to one part.
- Boot warm-up costs 0.76 s to first playable.

## 9. Tests and identity

- CI jobs: `unit`, `sim`, `sim-tiers-a`, `sim-tiers-b`, `bench`, Pages `deploy`.
- With the flag off tier 3 is identical to E5: `tier-3 off identical` at every phase head; tier 1: `rows 1-7
  identical`, `baseline identical`.
- Flag-on sims run on fixtures recorded from real play (seed 3). The flag-on respawn sim is an instrumented scene
  (3000 HP diner): it proves protection against an immediate second knock-out, not the full window at real HP.

## 10. Still to do before this pack is final

- Answers to escalations 11 and 12.
- The third tuning round or the ramp, if the answers call for one (Task 18).
- The hold-out run, once (`--set=1 --final`), and its numbers in section 6.
- The E5 T3 comparison for unspent gold.
- The whole-branch review and one fix wave.
