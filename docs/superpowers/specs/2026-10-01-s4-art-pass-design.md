# S4 Asset Pipeline + Full Art Pass: Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`). It builds on the S1–S3 specs, and their conventions,
  architecture and rules still apply.
- **Precondition:** S3 is merged (save, failure, mercy). The S4 style board is done and decided (D-183, D-186,
  `docs/review/media/s4_style_board/README.md`).
- **Status:** written autonomously under D-159 and D-182..D-186. The main session answered every brainstorming
  question from IDEA.md, the pillars, DECISIONS.md, the author's S4 direction and the style board. A reviewer pass
  replaces the author's approval.
- **Decision log:** `docs/DECISIONS.md` D-187 to D-196.

---

## 1. Goal and success criteria

S4 replaces every placeholder primitive with real, cohesive low-poly art, while gameplay stays byte-for-byte
identical.

1. **Coverage.** Every item on the author's list has final art:
   - hero, Boar, travelers, guards;
   - diner, counter, freezer, towers, fences, steak, coins, signs;
   - ground and lanes, props;
   - UI skin, card art.

   Nothing built with `Visuals.box/capsule/cylinder/cone/plane` is left in shipped game code.
2. **One world.** Everything follows `docs/ART_BIBLE.md`: one master palette, one shading model and the D-183
   readability rules. Each visual task's screenshots pass its ART_BIBLE checklist at full size and at 40%.
3. **Gameplay identity.** For seeds 20260930, 11 and 777, the sweep's CSV and its SWEEP and RETRIES lines are
   byte-identical before and after S4. Unit and sim suites stay green, and their thresholds do not change.
4. **Performance.** On the `web_profile` build in the iOS Simulator, a night-3 60 s window averages at least
   58 fps (D-159).
5. **Size.** The release download stays at most 16 MB uncompressed (wasm + pck + js), and the pck at most 8 MB
   (D-195).
6. **Licenses.** Every shipped third-party file is CC0 and logged in `docs/ASSET_LICENSES.md`. The asset validator
   enforces this in CI.
7. **Media.** Before and after screenshots of each major screen and of each lane are in `docs/review/media/`.

## 2. Scope

**In:**
- `docs/ART_BIBLE.md`.
- The master palette and the atlas remap tool.
- The asset validator (a unit test in CI).
- The import pipeline: trimmed KayKit animations and a shared animation library.
- The `ActorVisual` contract.
- Character visuals (hero, guards, travelers).
- The production procedural Boar.
- Pickups and piles: steak, coin, carry stack, counter, freezer, gold pile, fly FX.
- Projectiles.
- The diner kitbash.
- Towers and fences at every level, plus rubble.
- Build-spot markers, the close-up sign, telegraph flags, lane entrances.
- Ground, lanes, road and props.
- Day and night lighting.
- Blob shadows and the hero ring.
- The UI theme, HUD icons and card art.
- Before/after media.

**Out** (S5 or later):
- Particles, screen shake, hit-stop, number pop-ups and other juice. S5 does VFX and juice; S4 only keeps the
  existing flash, pop and poof timings.
- Onboarding hints.
- Audio.
- HUD layout changes beyond the skin.
- The settings or New game panel.

IDEA "Later" stays out: no Mage or Chef hero cards. The chef look is the hero's costume, not a card.

## 3. Brainstorm answers (autonomous, D-159)

| Question | Answer | Source | D-id |
|---|---|---|---|
| Where do assets live? | **`assets/<pack-id>/`** holds third-party files: only the files used, plus each pack's `LICENSE.txt`, mirroring the pack's own folders. **`art/`** holds our art: palette, materials, shaders, wrapper scenes, procedural builders and rendered icons. **`tools/`** holds headless tools (palette remap, icon render) and the validator. **Export:** `tools/*` is excluded from every web preset, like `ui/debug/*`, and so are source-only files (`*.blend`, `*.fbx`, `LICENSE.txt` copies are kept). CLAUDE.md's layout gets the three directories. | D-032, D-098 | D-187 |
| How do the packs share one palette? | **Master palette:** 32 colours in `art/palette/palette.gd` (named constants) and `art/palette/palette.png` (a 32×1 strip). **Atlas remap:** Kenney and KayKit models colour through small flat-swatch atlases (`colormap.png`, `*_texture.png`). `tools/palette_remap.gd` maps every atlas pixel to its nearest palette colour in Oklab and writes `art/palette/atlas/<pack>__<file>.png`, with per-asset swatch overrides (e.g. the hero's torso to apron white, travelers to muted variants). Imported materials are pointed at the remapped atlas, so there is no runtime cost. **Procedural meshes** use palette constants. **Validator:** every texture under `art/` contains only palette colours. | D-183 (one palette) | D-188 |
| How are KayKit's 3.6 MB glbs kept small? | **Size:** the five characters share one 41-joint rig (checked on the board), and their file size is mostly the 76 animations. **Library:** the needed clips are saved once into `art/characters/kaykit_anims.tres` (an AnimationLibrary): Idle, Running_A, Walking_A, Throw, 1H_Melee_Attack_Slice_Diagonal, 2H_Ranged_Shoot, Hit_A, Death_A, Cheer. **Per-character imports** turn animation import off. The method is the glb's import `_subresources` "save to file" per clip. Fallback: an `EditorScenePostImport` script that drops the unlisted clips. **Validator:** checks the library has every clip the role table needs. | D-182 (no Blender) | D-189 |
| How do actors talk to their art? | **The contract:** every actor's "Visual" child (the D-016 promise) is an `ActorVisual` (`components/actor_visual.gd`) with `set_motion(speed_frac)`, `face(dir)`, `attack()`, `hit()`, `die()` and `reset()`. Actors call it; it never feeds gameplay. **Timing:** visual timing runs in `_process`. Any duration that gates gameplay today (Boar death release 0.15 s, guard poof 0.15 s, build pop 0.2 s, hit flash 0.08 s) keeps its current value and owner. **Proof:** the sweep must be byte-identical (§1.3). | D-016, S1 rules | D-190 |
| Who is the hero and how does it fight? | **Body:** the Barbarian body as the diner cook. The hood, cape and props are hidden; a procedural chef hat sits on the head bone; the torso is remapped to apron white; a frying pan is in the right hand; a warm ring sits underfoot. **Combat:** the hero's homing projectile becomes a spinning kitchen knife (KayKit Restaurant `knife`), and the visual plays `Throw` on the upper body while the legs keep running. **Rest:** Cheer on dawn. | D-183 (cook) | D-191 |
| What do guards and travelers look like? | **Archer:** Rogue_Hooded (green) with crossbow_2handed, shooting crossbow bolts (KayKit `arrow`). **Tank:** Knight with sword_1handed and shield_badge. **Knockout:** Death_A plays inside the existing 0.15 s poof window, and the revive walk uses Walking_A. **Travelers:** Rogue and Mage bodies with no props, in three muted palette variants each, so six looks; Walking_A to queue, Idle to wait. **Distinction:** the travelers are never brighter than any guard. | D-183 | D-191 |
| How is the procedural Boar made cheap? | **Mesh:** the production Boar is one merged `ArrayMesh` built once and cached: the board prototype's 26 primitives are merged with `SurfaceTool`, using palette vertex colours, and the tusks are re-angled to about 55°. **Shader:** one shared `boar.gdshader` swings the leg vertices, which are marked in the vertex colour alpha, with the phase taken from `NODE_POSITION_WORLD`. **Materials:** three shared materials (idle, run, flash) are swapped with `material_override`, so it is one draw call per Boar. **Tweens:** attack, hit squash and death are tweens on the Visual's transform. | D-186 open item | D-192 |
| How are piles and shadows kept cheap? | **Piles:** the counter grid, freezer stack, gold pile and carry stack become `MultiMeshInstance3D` with `visible_instance_count`, one draw call each. **Shadows:** no real-time shadows. Characters and Boars get a shared blob-shadow quad (unshaded, a radial alpha texture in palette ink). | S1 §perf | D-193 |
| What is the diner and the world? | **Diner:** a roadside diner on the existing 8×8×3 m body. It has Fantasy Town wood walls with windows, a **flat roof** with a low parapet (the Archer's perch, D-164), a chimney, a rooftop "DINER" board (Label3D, `tr`), a striped awning over the counter side, and KayKit Restaurant counters, fridge and stove. **Occluder fade:** OccluderFade keeps working on the imported materials. **Towers:** Tower Defense round pieces; L1 is bottom + top + ballista, L2 adds a middle section, L3 adds a roof and crystals. **Fences:** Castle wood fence at L1, double wood at L2, stone wall-narrow at L3; rubble is Fantasy Town `fence-broken`. **Ground and lanes:** grass ground, dirt lanes with stone edging, a road, and hand-placed trees, rocks and bushes outside the play area (MultiMesh). **Lighting:** a warm day, and a blue night that stays readable (D-183 rules), driven by a small `LightingDirector` on `phase_changed`. | Pillar 1 (diner visibly grows) | D-194 |
| What is the UI skin and card art? | **Skin:** a Theme resource, `ui/theme/game_theme.tres`: StyleBoxFlat in palette colours, rounded, with a dark outline, and Nunito. **Icons:** HUD icons (coin, steak, diner heart, moon) and card art are **rendered from the game's own 3D assets** by `tools/render_icons.gd` at 256 px, on palette backgrounds, and committed as PNGs. **Cards:** each card shows its portrait. Archer and Tank are their models; upgrades are an object (knife = damage, boot = speed, steak stack = carry, coin = gold, stopwatch-like crystal = attack speed). **Card strip:** icons + level instead of text glyphs. | Author S4 list | D-195 |
| What are the budgets? | **Perf:** the §1.4 target. A guide metric is recorded by `capture.gd`: at most 120 draw calls at the night-3 peak, desktop. **Size:** the §1.5 target. **Per-asset limits:** textures at most 512², with no hand-painted textures beyond swatch atlases; triangle budgets are hero/guard 3k, traveler 3k, Boar 1.5k, tower L3 4k, diner 12k, prop 1.5k. The validator checks these. | D-159 | D-196 |

## 4. Art bible (`docs/ART_BIBLE.md`, Task 2)

ART_BIBLE is the reviewer's checklist for every visual task. It holds:

1. **Pillar.** Bright, comedic, chunky low-poly; rounded forms; flat swatch colour; no gore. Monsters poof into
   cartoon steaks.
2. **Palette.** The 32 named colours, with hex values and their role:
   - ink (outline and shadow);
   - three skin tones;
   - hero whites and gold;
   - guard green and steel;
   - traveler muted greys and beiges;
   - enemy reds;
   - grass, dirt, stone and wood;
   - diner teal, red and cream;
   - UI cream, UI ink and UI accent;
   - coin gold, steak brown.
3. **Readability rules (D-183):**
   - **Silhouettes:** distinct for the hero, travelers, guards and the Boar.
   - **The hero pops:** the only white/gold figure, with a ring.
   - **Travelers** are muted: their saturation and value are at most the guards'.
   - **Enemies** carry the red accent, and only enemies, telegraphs and danger UI use the enemy reds.
   - **Steaks and coins** read against the grass and the dirt.
   - **Night** keeps these contrasts.
4. **Shading.**
   - One DirectionalLight with shadows off, plus ambient.
   - StandardMaterial3D with roughness 1.0, or the shared Boar shader.
   - No PBR textures.
   - Blob shadows under characters.
5. **Scale table:**

   | Item | Height |
   |---|---|
   | Hero and guards | 1.6 m |
   | Traveler | 1.5 m |
   | Boar | 1.0 m tall, 1.45 m long |
   | Steak | 0.4 m |
   | Coin | 0.3 m |
   | Tower L1 / L2 / L3 | 2.2 / 2.8 / 3.4 m |
   | Fence | 0.9 m |
   | Diner | 3 m + parapet |

6. **Animation table.** Role, then the clip for each state (idle, move, attack, hit, death or knockout, cheer), plus
   the tween specs for the Boar.
7. **Phone check.** Every screenshot is also judged at 40% (288×512). The reviewer's checklist is the readability
   rules, read against the 40% image.
8. **Budgets** from D-196.
9. **Sources and process.**
   - CC0 only.
   - The order is: existing packs, then kitbash, then procedural, then (only with the author) generation.
   - Log every file in ASSET_LICENSES.

## 5. Asset pipeline (Tasks 2–4)

### 5.1 Intake

- Only files actually used are copied from a pack into `assets/<pack-id>/`, keeping the pack's relative path. Each
  pack folder also gets the pack's `LICENSE.txt`.
- **Pack ids:**
  - `kenney-tower-defense`
  - `kenney-castle`
  - `kenney-fantasy-town`
  - `kenney-food`
  - `kenney-platformer`
  - `kenney-nature` (if used)
  - `kaykit-adventurers`
  - `kaykit-restaurant`
- `.gltf` files keep their `.bin` and texture siblings.
- `docs/ASSET_LICENSES.md` gets one row per pack. Each row has the pack name, folder, source URL, licence, the date
  added, the SHA-256 of the pack's `LICENSE.txt`, and the number of files used. Procedural and rendered assets get a
  row each, as "original, made in this repo".

### 5.2 Palette remap (`core/palette_math.gd` + `tools/palette_remap.gd`)

- **`core/palette_math.gd`** is pure static and unit-tested:
  - `to_oklab(c: Color) -> Vector3`
  - `nearest(c: Color, palette: PackedColorArray) -> int`
  - `remap_image(img: Image, palette, overrides: Dictionary) -> Image`. The overrides map a source hex to a
    palette name, so a whole swatch can be re-targeted (apron, muted travelers).
- **`tools/palette_remap.gd`** is a `-s` script:
  - It reads `art/palette/remap_manifest.gd`, which lists, for each atlas, its source path, output path and
    overrides, and writes the remapped PNGs.
  - Re-running it with the same inputs gives byte-identical PNGs.
  - The remapped atlases are committed. The manifest is the single source of truth for which atlas feeds which
    asset.

### 5.3 Import

- Kenney and KayKit prop scenes are wrapped in `art/**.tscn` scenes. The wrappers override each surface's material
  with a shared palette material (`art/materials/<atlas>.tres`, a StandardMaterial3D on the remapped atlas, roughness
  1). So a wrapper never relies on the imported material.
- **Characters (D-189):**
  - `art/characters/kaykit_anims.tres` holds the clips listed in D-189.
  - Each character glb imports with animation import off.
  - `art/characters/kaykit_character.tscn` is the base wrapper: the glb's skeleton and meshes, an AnimationPlayer
    using the shared library, an AnimationTree, and a blob shadow. Role scenes inherit it.

### 5.4 Asset validator (`tools/asset_validator.gd`, run by `tests/unit/test_assets.gd`)

The validator is static and returns an Array of problem strings; the test asserts it is empty. It checks:

1. **Licences.**
   - Every file under `assets/` is inside a pack folder that has a `LICENSE.txt` containing "CC0" or "Creative
     Commons Zero".
   - Every pack folder has a row in `docs/ASSET_LICENSES.md`.
   - No file outside `assets/` and `art/` is a model or texture (`.glb`, `.gltf`, `.fbx`, `.obj`, `.png` or `.jpg`),
     except `ui/fonts`, `export/`, `docs/`, `addons/` and `tests/` outputs.
2. **Palette.** Every PNG under `art/palette/atlas/` and `art/icons/` contains only palette colours. Icons are
   checked on their opaque pixels, with alpha edges excluded.
3. **Texture size.** Every texture used by `art/` is at most 512×512. Icons are at most 256.
4. **Triangles.** Each `art/**/*_visual.tscn` (and the Boar builder's mesh) is within its D-196 budget, counted from
   the mesh arrays.
5. **Animations.** `kaykit_anims.tres` has every clip in the ART_BIBLE animation table.
6. **No placeholders.** No game script outside `tests/` and `tools/` calls `Visuals.box`, `capsule`, `cylinder`,
   `cone` or `plane`. This rule turns on in Task 12, after the last placeholder goes; until then it is a reported
   warning.

### 5.5 Export

- `tools/*` and `assets/**/*.fbx` are added to every web preset's `exclude_filter`.
- `pages.yml` prints the release pck and total payload sizes, and fails if they exceed D-196 (Task 4). `pages.yml`
  is a hot file; the main session edits it.

## 6. Visual architecture

### 6.1 `ActorVisual` (`components/actor_visual.gd`, class_name ActorVisual, extends Node3D, name "Visual")

```
func set_motion(speed_frac: float) -> void   # 0 = idle, 1 = full run speed
func face(dir: Vector3) -> void              # world XZ direction; ignored when near zero
func attack() -> void                         # upper-body one-shot (characters) or lunge (Boar)
func hit() -> void                            # flash (Boar keeps its 0.08 s material swap) / Hit_A one-shot
func die() -> void                            # Death_A / Boar squash-pop; never changes gameplay timing
func reset() -> void                          # pooled actors: back to idle, scale 1, no flash
var flash_active: bool                        # read by tests (replaces peeking at material_override)
```

- **Facing.** It turns toward `face()` at `Balance.ui.visual_turn_speed` (rad/s) in `_process`. The default is 14.
  Only visual nodes rotate.
- **KayKitVisual** (`art/characters/kaykit_visual.gd`) drives an AnimationTree:
  - a `locomotion` BlendSpace1D (Idle at 0, Walking_A at 0.5, Running_A at 1);
  - an `action` OneShot filtered to the spine, arm and head bones (Throw, the attacks);
  - a full-body `react` OneShot (Hit_A);
  - a `dead` transition (Death_A).

  The crossfade is `Balance.ui.anim_blend_s` (0.12).
- **BoarVisual** (`art/boar/boar_visual.gd`) uses the shared mesh and materials (D-192). Run vs idle comes from
  `set_motion`.
- Actors feed `set_motion` from their own velocity each physics tick: hero, Boar, guards and travelers. `attack()`
  is fed from `Attacker.fired`, and `hit()` from `take_hit` or `guard_damaged`.

### 6.2 Tests that peek at visuals

The tests listed in §9 move to the contract (`visual.flash_active`, `visual.scale`, `visible`). Each keeps its
semantics: a hit still flashes for 0.08 s, rubble is still visibly different, and a sign still pulses. No test is
dropped or weakened (D-132 spirit).

### 6.3 Gameplay identity

- Visual scripts never write to gameplay nodes or GameState, never call `Rng`, and never await in gameplay paths.
- Pools keep their sizes and release timing.
- **The determinism proof** is a recorded baseline: before Task 5, the sweep for the three seeds is saved to
  `tests/sim/baseline/s4_sweep_<seed>.txt` (the CSV plus the SWEEP and RETRIES lines). Every phase PR re-runs it
  and diffs, and the PR body records "identical".

## 7. Per-item art (Tasks 5–14)

| Item | Art | Notes |
|---|---|---|
| Hero | KayKit Barbarian as the cook, chef hat, apron, pan, ring | D-191. Ring: flat torus r0.7 m, palette warm white, alpha 0.6, unshaded. |
| Hero projectile | kk-restaurant `knife`, spinning 720°/s around its local X | Pooled projectile; the art is chosen by the source kind. |
| Archer | Rogue_Hooded, crossbow_2handed, `2H_Ranged_Shoot` | Stands on the flat roof. |
| Archer and tower projectile | kk-adventurers `arrow`, nose along velocity | |
| Tank | Knight, sword + shield badge, `1H_Melee_Attack_Slice_Diagonal` | HP bar restyled: palette ink back, green fill, rounded ends. |
| Travelers | Rogue / Mage, no props, three muted variants each | Variant = `spawn_index % 6` (deterministic). |
| Boar | Production procedural mesh (D-192) | Tusks at about 55°, ridge of 5. |
| Steak | kenney-food `meat-cooked` (fallback: `meat-ribs`) | Same model for the ground, stacks and fly FX. |
| Coin | kenney-platformer `coin-gold` | Pile, fly FX and HUD icon source. |
| Carry stack | MultiMesh of steaks above the hero's hands | Up to the carry cap. |
| Counter | kk-restaurant `kitchencounter_straight_*` ×3 + a steak MultiMesh grid | On the existing 3×1 body. |
| Freezer | kk-restaurant `fridge_A` + a steak MultiMesh stack beside it | On the existing 1.5×1.5 body. |
| Gold pile | Coin MultiMesh in a heap pattern | |
| Diner | Fantasy Town walls/windows/door, flat roof + parapet, chimney, rooftop board, city-kit awning, kk-restaurant stove/menu | `art/env/diner.tscn`; OccluderFade under its Visual. |
| Tower L1–L3 | kenney-tower-defense round pieces + `weapon-ballista` | The level changes the model, not just the scale. |
| Fence L1–L3, rubble | castle wood fence / double / stone wall-narrow; fantasy-town `fence-broken` | Rotated to the lane tangent as today. |
| Build spot (unbuilt) | kenney-tower-defense `selection-a` marker | The progress ring is unchanged. |
| Close-up sign | Wooden post + board (fantasy-town pieces) + Label3D "Close up" (tr) | The pulse is kept. |
| Telegraph | Red pennant flag (castle `flag-pennant`) scaled by threat | Only enemy reds. |
| Lane | Dirt strip mesh with stone edge pieces; entrance: castle `gate` posts | |
| Ground and road | Grass plane (palette grass, subtle vertex-colour variation), road strip | |
| Props | castle trees and rocks, tower-defense detail rocks/trees, outside the play bounds | Hand-placed list `art/env/props_layout.gd`; MultiMesh per model. |
| Lighting | Day: warm sun + sky ambient. Night: blue moon light + dim ambient. A 1.5 s tween on `phase_changed`. | `world/lighting_director.gd`. |
| UI | `game_theme.tres`; HUD icons; banners; world labels in palette ink outline | |
| Cards | Rendered portraits; card strip icons | `tools/render_icons.gd` → `art/icons/`. |

## 8. Hot files and wiring

These files take wiring from the main session (D-139, D-181):
- **`world/world.gd`:** the diner scene, ground and lanes, props, the LightingDirector node, and the projectile art
  kind.
- **`balance/ui_tuning.gd`:** `visual_turn_speed`, `anim_blend_s`, and the lighting colours and energies.
- **`project.godot`:** the theme.
- **`export_presets.cfg`:** the exclude filters.
- **`.github/workflows/pages.yml`:** the size gate.
- **`CLAUDE.md`:** the layout.

Implementers report the exact lines.

## 9. Testing

- **Unit:**
  - `palette_math`: Oklab nearest, overrides, determinism.
  - The validator, against good and bad fixture folders under `tests/unit/fixtures/assets/`.
  - The ActorVisual contract, for each role visual:
    - it instantiates headless;
    - its `set_motion` / `attack` / `hit` / `die` / `reset` cycle has no errors;
    - `flash_active` timing;
    - facing converges.
  - The Boar mesh: one surface, tris within budget, a leg-mask vertex count above 0.
  - Tower and fence level models differ per level.
  - The lighting director's day and night target values.
- **Updated tests** (move to the contract with the same semantics):
  - `test_fx` (Boar flash, pop)
  - `test_guards` (visual visible/scale, the HP bar)
  - `test_build_spots` (rubble)
  - `test_restore_world` (sign pulse, spot visuals, pips, stacks)
  - `test_occluder_fade` (it builds a real diner wrapper or a local fixture; parent rule kept)
  - `test_hud` (fill colour from the palette)
  - the count helpers `test_stations`, `test_hero` and `test_travelers` (MultiMesh visible counts)
- **Sims:** unchanged; must stay under 60 s (D-132). Headless instantiation of skinned characters is measured in
  Task 5; if the sim suite grows by more than 10 s, escalate with timings.
- **Determinism:** the §6.3 baseline diff for every phase.
- **Visual review**, every visual task:
  - `tests/sim/capture.gd` renders at 720×1280, plus a 40% copy, into `docs/review/media/s4/<task>/`.
  - `export/device_check.sh` on the iOS Simulator for the phase's preview URL.
  - The reviewer gets the ART_BIBLE checklist and the PNG paths and must look at them.
- **Perf** (Task 15): `web_profile` on the iOS Simulator at night 3 (`?scene=night3`, a debug scene added in Task 15
  if it is missing, or the sweep-like debug skip), with the 60 s average and worst frame from the perf overlay.
  Plus emulated Pixel 7 (labelled).

## 10. Build order (a hint for writing-plans)

| Phase | Branch | Tasks |
|---|---|---|
| P1 Foundation | `s4/p1-foundation` | 1 before media + determinism baseline; 2 ART_BIBLE + palette + remap; 3 intake + licences + validator; 4 import pipeline + export filters + size gate |
| P2 Characters | `s4/p2-characters` | 5 ActorVisual + KayKitVisual + blob shadow + test moves; 6 hero (cook, knife, ring); 7 guards + travelers |
| P3 Boar and pickups | `s4/p3-boar` | 8 production Boar; 9 steak/coin/stacks/piles/fly FX/projectiles |
| P4 World | `s4/p4-world` | 10 diner + counter + freezer; 11 towers/fences/spots/sign/telegraph/lane ends; 12 ground/lanes/props/lighting (+ validator placeholder rule on) |
| P5 UI | `s4/p5-ui` | 13 theme + HUD skin + labels; 14 icon renders + card art + card strip |
| P6 Results | `s4/p6-results` | 15 perf + size + load; 16 after media + lane shots + results + review queue |

Tasks in one phase with disjoint files may run in parallel (D-136), at most 3 at once.

## 11. Risks

| Risk | Mitigation |
|---|---|
| Night-3 fps drops below 58 with skinned characters | Count: about 3–9 skinned characters (hero, 2 guards, up to 4–8 travelers by day; travelers leave at night). The Boar is one draw call. Piles are MultiMesh. No shadows. Fallbacks in order: drop AnimationTree for travelers (AnimationPlayer only); 15 fps animation update for travelers; LOD-free simpler props. |
| `_subresources` save-to-file is awkward headless | Fallback: an `EditorScenePostImport` script (D-189). |
| Imported materials break OccluderFade | The wrappers use our own StandardMaterial3D (§5.3), which OccluderFade already handles. A test covers the diner wrapper. |
| Palette remap muddies KayKit faces | Overrides per swatch; skin tones are dedicated palette entries; the closeup is reviewed in Task 2. |
| Sim time grows from headless animation | Measure in Task 5; escalate per D-132. Never weaken tests. |
| The pck exceeds 8 MB | Trim unused files; lower texture size; drop the extra traveler body. |

## 12. Playtest questions added for the final review

1. At a glance, could you always tell which character was you?
2. Did the monsters look dangerous, and did the steaks look like food?
3. Did the diner and the defenses look like they grew as you upgraded them?
4. Was anything hard to see at night?

## Appendix: Post-v0.1 ideas (not in v0.1)

- Per-lane biomes.
- Boar variants (armoured, piglets) with their own silhouettes.
- Seasonal diner skins.
- Animated travelers eating at tables.
- A Blender kitbash pass on the Boar for a skinned rig.

## 13. Results (S4, filled in at the end of S4)
