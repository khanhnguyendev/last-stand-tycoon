# Last Stand Tycoon: Art Bible (S4, D-183, D-186..D-197)

This is the reviewer's checklist for every visual task. Spec: `docs/superpowers/specs/2026-10-01-s4-art-pass-design.md`
§4. The palette lives in `art/palette/palette.gd` (and `palette.png`); this file is its contract.

## 1. Pillar

Bright, comedic, chunky low-poly. Rounded forms, flat swatch colour, big heads, no gore. Monsters poof into cartoon
steaks. One cohesive look: KayKit characters, Kenney rounded kits and a procedural Boar, all remapped to one palette.

## 2. Palette

32 named colours (D-188). Order and names are fixed; hex values may be tuned by the Task 3 remap review, but never the
count or the names. Every texture and every vertex colour uses only these.

| # | Name | Hex | Role |
|---|---|---|---|
| 0 | `ink` | `#2b2233` | Outlines, shadows, UI text |
| 1 | `ink_soft` | `#4a3f55` | Outlines, shadows, UI text (soft variant) |
| 2 | `apron_white` | `#fbf7ee` | Hero: chef hat, apron |
| 3 | `warm_white` | `#fff3c4` | Hero: highlight, ring glow |
| 4 | `gold` | `#f2c230` | Hero and reward: coin, level pips, hero ring; UI accent |
| 5 | `gold_dark` | `#c08a1e` | Hero and reward: coin edge, gold shade |
| 6 | `skin_light` | `#f4c9a0` | Skin tone 1 |
| 7 | `skin_mid` | `#d99a6c` | Skin tone 2 |
| 8 | `skin_dark` | `#8d5a3b` | Skin tone 3 |
| 9 | `guard_green` | `#3f9a4a` | Guards (Archer hood), hero sleeves |
| 10 | `guard_green_dark` | `#2a6b35` | Guards: shade, trim |
| 11 | `steel` | `#b8c2cc` | Guards (Tank helmet, shield), hero sleeves, towers' metal |
| 12 | `steel_dark` | `#6e7a86` | Guards: armour shade, weapon metal |
| 13 | `cloth_blue` | `#4a78b5` | Guard and hero cloth, sleeves |
| 14 | `traveler_grey` | `#9a9488` | Travelers only |
| 15 | `traveler_beige` | `#b8a98e` | Travelers only |
| 16 | `traveler_brown` | `#7d6e5c` | Travelers only |
| 17 | `enemy_red` | `#c8402f` | Boars, telegraphs and danger UI only |
| 18 | `enemy_maroon` | `#7a2e22` | Boars, telegraphs and danger UI only |
| 19 | `enemy_snout` | `#c97a6a` | Boars (snout, ears), danger UI only |
| 20 | `grass` | `#7fbf5a` | World: ground |
| 21 | `grass_dark` | `#5e9a45` | World: ground variation, bushes |
| 22 | `dirt` | `#c9a06a` | World: lanes, road |
| 23 | `dirt_dark` | `#a07a4a` | World: lane edges, ruts |
| 24 | `stone` | `#a3a3a8` | World: rocks, tower walls, rubble |
| 25 | `wood` | `#a8683c` | World: fences, crates, tower timber |
| 26 | `wood_dark` | `#6e4527` | World: timber shade |
| 27 | `diner_teal` | `#4fb3a9` | The diner: walls, awning |
| 28 | `diner_cream` | `#f3e3c3` | The diner: trim, roof, parapet; UI panels |
| 29 | `ice_blue` | `#7cc6e0` | Freezer |
| 30 | `steak_brown` | `#8a4a2b` | Steak |
| 31 | `night_sky` | `#1f2a4a` | Night background and UI dim |

Colour discipline:
- `apron_white`, `warm_white`, `gold`, `gold_dark` belong to the hero and to rewards. No other character wears them.
- UI may use the hero and reward golds only as accents.
- `traveler_*` is for travelers only.
- `enemy_*` is for Boars, telegraphs and danger UI only (R4).

## 3. Readability rules (D-183)

Each image is answered pass or fail on every rule. Any fail blocks the task.

- **R1.** Silhouettes are distinct for the hero, travelers, guards and the Boar.
- **R2.** The hero pops: it is the only white/gold figure and has a ring.
- **R3.** Travelers are muted, and guards read stronger. Fixed numeric limits (HSV):
  - every traveler colour (`traveler_grey`, `traveler_beige`, `traveler_brown`) has saturation at most 0.30 and
    value at most 0.75;
  - the guard accent `guard_green` has saturation at least 0.50.
  Enforced by `test_r3_traveler_colours_muted`.
- **R4.** Only enemies, telegraphs and danger UI use the enemy reds. Mechanical check: `tools/palette_remap.gd`
  never maps an atlas pixel to an `enemy_*` colour (the Boar is procedural; enemy reds come only from code), and the
  asset validator fails on any `enemy_*` pixel in `art/palette/atlas/`. Icons for danger UI (the heart) are the only
  exception.
- **Palette exception (D-192).** The Boar's upper body is `enemy_maroon` lerped 0.4 toward `enemy_red` (procedural
  vertex colour, D-192): the only non-swatch colour, for readability under lambert shading.
- **R5.** Steaks and coins read against the grass and the dirt.
- **R6.** Night keeps R1–R5.
- **R7.** Everything in the scale table matches within 10%.
- **R8.** No placeholder primitive is visible.

## 4. Shading

- One DirectionalLight with shadows off, plus ambient.
- StandardMaterial3D with roughness 1.0, or the shared Boar shader.
- No PBR textures (no normal, roughness or metallic maps).
- Blob shadows under characters and Boars. No real-time shadows (D-193).
- Vertex colours from `Palette` are sRGB; materials set `vertex_color_is_srgb = true`.

## 5. Scale table

Heights at `build_level_scale` 1.0. R7 allows 10% tolerance.

| Item | Height (final, `build_level_scale` 1.0) |
|---|---|
| Hero and guards | 1.6 m |
| Traveler | 1.5 m |
| Boar | 1.0 m tall, 1.45 m long |
| Steak | 0.4 m |
| Coin | 0.3 m |
| Tower L1 / L2 / L3 | 2.2 / 2.8 / 3.4 m |
| Fence | 0.9 m |
| Diner | 3 m + parapet |

## 6. Animation table

KayKit clips (D-189): `Idle`, `Running_A`, `Walking_A`, `Throw`, `1H_Melee_Attack_Slice_Diagonal`,
`2H_Ranged_Shoot`, `Hit_A`, `Cheer`. N/A marks a state that cannot happen. The Visual root's scale and visible stay
with the gameplay tweens; ActorVisual animates only its inner `Body` (D-190).

| Role | Idle | Move | Attack | Hit | Death / knockout | Cheer |
|---|---|---|---|---|---|---|
| Hero | `Idle` | `Running_A` | `Throw` (upper body) | N/A (D-161) | N/A (D-161) | `Cheer` |
| Archer | `Idle` | `Walking_A` | `2H_Ranged_Shoot` | N/A (D-164) | poof (0.15 s tween) | `Cheer` |
| Tank | `Idle` | `Running_A` | `1H_Melee_Attack_Slice_Diagonal` | `Hit_A` (throttled by `hit_react_cooldown`) | poof (tween fake) | `Cheer` |
| Traveler | `Idle` | `Walking_A` | N/A | N/A | N/A | N/A |

Boar (tweens, no clips; D-192):

| State | Tween |
|---|---|
| Idle | bob 3% at 0.8 s |
| Run | hop 0.08 m at 4 Hz, with shader legs |
| Attack | crouch 0.06 s, then lunge 0.3 m |
| Hit | squash 0.92 on y for 0.08 s, with flash |
| Death | squash to 0.6 on y within 0.15 s, then the steak pops |

Durations that never change: Boar death release 0.15 s, guard poof 0.15 s, build pop 0.2 s, hit flash
`Balance.ui.hit_flash_time` (0.08 s).

## 7. Phone check

Every image is also judged at 40% (288×512, the phone-size check from `tools/shots.sh`) against R1–R8. A rule that
passes only at full size fails.

## 8. Budgets (D-196)

- Perf: iOS Simulator, profile build, night 3: average at least 58 fps (checked at P2, P4, P6).
- Desktop guide: at most 120 draw calls at the night-3 peak, at most 150 at the day peak (full queue).
- Size: `gzip -9` of wasm + pck + js at most 16 MB; raw release pck at most 8 MB (gated in `pages.yml`).
- Textures: at most 512² (icons at most 256²).
- Triangles: per `art/budgets.gd`, with the KayKit counts measured before they freeze.
- Each imported character scene is under 500 KB (D-189).
- VRAM compression ETC2/ASTC is on (D-158) and counts toward the size.

## 9. Sources and process

- CC0 only (Nunito is OFL, D-079). Every pack folder has a `LICENSE.txt` and a row in `docs/ASSET_LICENSES.md`
  (D-187).
- Source order: existing packs first, then kitbash, then procedural, then generation (only with the author's OK,
  D-182).
- Pipeline (spec §5): copy only used files into `assets/<pack-id>/`; remap atlases to the palette offline
  (`tools/palette_remap.gd`, Oklab nearest with per-swatch overrides); share materials in `art/materials/`; wrap
  scenes under `art/` with the root node named `Visual`; validate with `tools/asset_validator.gd`
  (`tests/unit/test_assets.gd`).
- No physics nodes in `art/` or imported scenes; collision stays in gameplay code.
- Visual code never writes GameState, never calls Rng or global rand, never changes gameplay durations.

Review: for each image answer R1–R8 pass/fail; any fail blocks the task.
