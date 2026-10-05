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

## S5 additions (Task 12)
After shots for S5 (`after/` = `tools/shots.sh`, re-rendered on the S5 build 6f9b826). No S5 "before" exists for the new
screens; the S4 shots above are the before for the shared ones. Web checks of the release build: `../review/media/s5/device_check/`.

| Screen | After | What it shows |
|---|---|---|
| Settings, portrait | [after](s5/after/settings_portrait.png) | Cream panel over the dimmed day: Sound: On, New game, Close. |
| Settings, 1280x720 | [after](s5/after/settings_landscape.png) | Same panel centred in landscape; coin counter and gear stay in the corners. |
| Guide move | [after](s5/after/guide_move.png) | Night-1 start, "Drag to move" prompt above a joystick ring. |
| Guide fight | [after](s5/after/guide_fight.png) | "Stay close" with a yellow arrow over the lane. |
| Guide take | [after](s5/after/guide_take.png) | "Take steaks" with a yellow arrow pointing into the diner floor. |
| FX poof | [after](s5/after/fx_poof.png) | 8-quad poof 0.1 s old, offset 2 m from the hero. |
| FX coin | [after](s5/after/fx_coin.png) | Small orange coin burst at the counter offset. |
| FX hit | [after](s5/after/fx_hit.png) | 4-quad hit spark (shot taken, not individually inspected). |
| FX sparkle | [after](s5/after/fx_sparkle.png) | Sparkle burst (shot taken, not individually inspected). |
| FX dust | [after](s5/after/fx_dust.png) | Dust puff (shot taken, not individually inspected). |
| iOS (release) | [after](s5/device_check/ios.png) | Release build in the Simulator: HUD, settings gear, guide prompt, joystick. |
| Android (emulated) | [after](s5/device_check/android_emulated.png) | Same on the Pixel 7 profile. |

`--fx=click|stock|take|throw` emit no particles (they are audio-only kinds), so capture.gd exits with an error for them; no shots.
