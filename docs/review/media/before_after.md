# S4 before / after

Same framing and args for both sets (`tools/shots.sh <dir>`, no `--cards`), 720x1280. Before: Task 1 (placeholder art).
After: the S4 art pass through P6 (KayKit cast, diner and tower models, pickups, UI theme, icons, draw-call diet).
Device shots are web builds in the iOS Simulator and in Playwright's Pixel 7 profile (before: the pre-art build
3aee9b2 on `main`; after: the P6 preview build 4999bf9, through the draw-call diet).

| Screen | Before | After | What changed |
|---|---|---|---|
| Day | [before](before/day.png) | [after](after/day.png) | Modelled diner, chef hero and travelers, palette ground, themed coin icon, heart and diner bar. |
| Night | [before](before/night.png) | [after](after/night.png) | Boars replace placeholder enemies, moons on ink discs, the diner with the occlusion fade. |
| Build | [before](before/build.png) | [after](after/build.png) | Gold counter with coin icon, tower and fence spots with the new models and palette. |
| Fail | [before](before/fail.png) | [after](after/fail.png) | Themed banner panel (night_sky) with the bold font, boars at the gate. |
| Retry | [before](before/retry.png) | [after](after/retry.png) | Same banner and HUD skin; the lane arrow is enemy_red. |
| Card pick | [before](before/cardpick.png) | [after](after/cardpick.png) | Cream cards with a gold or teal band and a rendered portrait per card. |
| Lane west | [before](before/lane_west.png) | [after](after/lane_west.png) | Lane close-up with Boar, rocks and trees from the new art set. |
| Lane north | [before](before/lane_north.png) | [after](after/lane_north.png) | Same, north lane, arrow above the gate. |
| Lane east | [before](before/lane_east.png) | [after](after/lane_east.png) | Same, east lane, with the Freezer and tree models. |
| HUD | [before](before/hud.png) | [after](after/hud.png) | Coin and heart icons, bold Nunito counters, themed bar. |
| iOS | [before](before/ios/ios.png) | [after](after/ios/ios.png) | Simulator framing: HUD icons, moons, models and the palette on the Simulator. |
| Android (emulated) | [before](before/ios/android_emulated.png) | [after](after/ios/android_emulated.png) | Same, Playwright Pixel 7 profile (emulated, D-141). |

The 40% copies (`*_40.png`) sit beside each full shot.
