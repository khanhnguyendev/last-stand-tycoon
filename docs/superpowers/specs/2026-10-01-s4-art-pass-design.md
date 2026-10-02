# S4 Asset Pipeline + Full Art Pass: Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`). It builds on the S1–S3 specs, and their conventions,
  architecture and rules still apply.
- **Precondition:** S3 is merged (save, failure, mercy). The S4 style board is done and decided (D-183, D-186,
  `docs/review/media/s4_style_board/README.md`).
- **Status:** written autonomously under D-159 and D-182..D-186. The main session answered every brainstorming
  question from IDEA.md, the pillars, DECISIONS.md, the author's S4 direction and the style board. A reviewer pass
  replaces the author's approval. Revised after the spec review: the size gate, the perf method, ownership of
  `Visual` scale, the animation library, the determinism baseline and the shot lists.
- **Decision log:** `docs/DECISIONS.md` D-187 to D-197.

---

## 1. Goal and success criteria

S4 replaces every placeholder primitive with real, cohesive low-poly art, while gameplay stays byte-for-byte
identical.

1. **Coverage.** Every item on the author's list has final art:
   - hero, Boar, travelers, guards;
   - diner, counter, freezer, towers, fences, steak, coins, signs;
   - ground and lanes, props;
   - UI skin, card art.

   No shipped game script calls `Visuals.box/capsule/cylinder/cone/plane`. The validator enforces this from Task 12
   (§5.4).
2. **One world.** Everything follows `docs/ART_BIBLE.md`: one master palette, one shading model and the D-183
   readability rules. Every visual task's shot list (§9.4) passes the ART_BIBLE checklist at full size and at 40%.
3. **Gameplay identity.** The §6.3 baseline (sweep CSV plus SWEEP and RETRIES lines, seeds 20260930, 11 and 777)
   diffs empty after every phase. Unit and sim suites stay green, with their thresholds unchanged.
4. **Performance.** On the `web_profile` build in the iOS Simulator, a night-3 60 s window averages at least
   58 fps, reached through the §9.5 save-injection harness. It is measured at the end of P2, P4 and P6 (D-159,
   D-196).
5. **Size (D-196).**
   - The served payload, `gzip -9` of wasm + pck + js, is at most 16 MB. The S1 basis is 10.3 MB (D-086).
   - The raw release pck is at most 8 MB.
   - `pages.yml` gates both.
6. **Licenses.** Every shipped third-party file is CC0, except Nunito (OFL, D-079), and logged in
   `docs/ASSET_LICENSES.md`. The asset validator enforces this in CI.
7. **Media.** Before and after screenshots of each major screen and of each lane are in `docs/review/media/`
   (§9.6).

## 2. Scope

**In:**
- `docs/ART_BIBLE.md`.
- The master palette and the atlas remap tool.
- The asset validator (a unit test in CI).
- The import pipeline: a shared KayKit animation library and stripped character imports.
- VRAM texture compression for mobile (D-158).
- The `ActorVisual` contract.
- Character visuals: hero, guards, travelers.
- The production procedural Boar.
- Pickups and piles: steak, coin, carry stack, counter, freezer, gold pile, fly FX.
- Projectiles.
- The diner kitbash.
- Towers and fences at every level, plus rubble.
- Level pips, build-spot markers, the close-up sign, telegraph flags, lane entrances.
- Ground, lanes, road and props.
- Day and night lighting.
- Blob shadows and the hero ring.
- The UI theme (HUD, banners, card overlay, world labels), HUD icons, card art.
- The night-3 perf harness.
- Before/after media.

**Out** (S5 or later):
- Particles, screen shake, hit-stop, number pop-ups and other juice. S5 does VFX and juice; S4 only keeps the
  existing flash, pop and poof.
- The joystick skin and HUD layout changes (S5 UI polish).
- Onboarding hints.
- Audio.
- The settings or New game panel.

IDEA "Later" stays out: no Mage or Chef hero cards. The chef look is the hero's costume, not a card.

## 3. Brainstorm answers (autonomous, D-159)

| Question | Answer | Source | D-id |
|---|---|---|---|
| Where do assets live? | **`assets/<pack-id>/`** holds third-party files: only the files used, keeping the pack's relative paths, plus the pack's licence normalised to the file name `LICENSE.txt` (Kenney ships `License.txt`; CI's file system is case-sensitive). **`art/`** holds our art: palette, materials, shaders, wrapper scenes, procedural builders and rendered icons. **`tools/`** holds headless and editor-only scripts: palette remap, icon render, the KayKit post-import script, and the validator. An `EditorScenePostImport` script must not live in `art/`, because the release boot check (D-157) would fail on it. **Export:** `tools/*`, `export/*` (the perf fixtures and seed page) and `assets/_candidates/*` (gitignored board leftovers) are added to every web preset's exclude filter. **Licence log:** `docs/ASSET_LICENSES.md` moves from one row per asset to one row per pack: pack, folder, URL, licence, date, SHA-256 of `LICENSE.txt`, number of files. The validator checks each row against disk. **Superseded:** this, ART_BIBLE §9 and spec §5 replace the `ASSET_PIPELINE.md` promised in D-024. **CLAUDE.md:** the layout gets the three directories. | D-024, D-032, D-079, D-098 | D-187 |
| How do the packs share one palette? | **Master palette:** 32 colours in `art/palette/palette.gd` (named constants) and `art/palette/palette.png` (a 32×1 strip). **Atlas remap:** Kenney and KayKit models colour through small flat-swatch atlases (`colormap.png`, `*_texture.png`). `tools/palette_remap.gd` maps every atlas pixel to its nearest palette colour in Oklab and writes `art/palette/atlas/<pack>__<file>.png`, with per-swatch overrides (the hero's torso to apron white, travelers to muted variants). **Wiring:** imported materials point at shared `art/materials/<atlas>.tres` through the import's external-material setting, so the original embedded textures don't ship. **Procedural meshes** use palette constants. **Icons** are quantised through the same remap. **Validator:** every texture under `art/` contains only palette colours. | D-183 (one palette) | D-188 |
| How are KayKit's 3.6 MB glbs kept small? | **Size:** the five characters share one 41-joint rig (checked on the board), and their file size is mostly the 76 animations. **Primary method:** `tools/kaykit_import.gd`, an `EditorScenePostImport` script set on each character's import. It strips every clip from the imported scene, and on the first character (Knight) it also writes `art/characters/kaykit_anims.tres`, but only when the clip set or the clip data differ from the committed file, so CI's `--import` never rewrites it, an AnimationLibrary with only the needed clips: Idle, Running_A, Walking_A, Throw, 1H_Melee_Attack_Slice_Diagonal, 2H_Ranged_Shoot, Hit_A and Cheer. **Fallback:** the import's per-clip `_subresources` "save to file", assembled into the library by `tools/`, with that source import excluded from export. **Acceptance:** each imported character scene is under 500 KB. | D-182 (no Blender) | D-189 |
| How do actors talk to their art? | **The contract:** every actor's "Visual" child (the D-016 promise) is an `ActorVisual` (§6.1). Actors call it; it never feeds gameplay. **Ownership:** the Visual root's `scale` and `visible`, and their tweens, stay with today's gameplay code (`Boar.play_death`, `Guard.poof`, the build pop, the sign pulse) at today's durations and process modes. ActorVisual animates only an inner `Body` node. The Boar's hit-flash timer stays in `Boar._physics_process`, which pushes `visual.set_flash(on)`. **Proof:** the §6.3 baseline. | D-016, S1 rules | D-190 |
| Who is the hero and how does it fight? | **Body:** the Barbarian body as the diner cook. The hood, cape and props are hidden; a procedural chef hat sits on the head bone; the torso is remapped to apron white; a frying pan is in the right hand; a warm ring sits underfoot. **Combat:** its homing projectile becomes a spinning kitchen knife (KayKit Restaurant `knife`). The visual plays `Throw` on the upper body while the legs keep running; the fallback is a full-body Throw only when standing still. **Rest:** Cheer at dawn. **No hit or death:** the hero is never targeted (D-161). | D-183 (cook) | D-191 |
| What do guards and travelers look like? | **Archer:** Rogue_Hooded (green) with crossbow_2handed, `2H_Ranged_Shoot`, shooting bolts (KayKit `arrow`). It has no hit reaction: it is untargetable on the roof (D-164). **Tank:** Knight with sword_1handed and shield_badge, `1H_Melee_Attack_Slice_Diagonal`. `Hit_A` plays at most once per `hit_react_cooldown` (1.0 s), so constant damage doesn't freeze it. **Knockout:** the existing 0.15 s poof is the knockout's tween fake (D-183 allows fakes), so Death_A is not used. The revive walk uses Walking_A. **Travelers:** Rogue and Mage bodies with no props, in three muted palette variants each, so six looks. Walking_A to queue, Idle to wait; no attack, hit or death. **Variant choice:** a visual-only counter in the traveler factory: the n-th traveler created by the pool gets variant `n % 6`. No gameplay field and no Rng draw is added. **Distinction:** travelers are never brighter than any guard. | D-183 | D-191 |
| How is the procedural Boar made cheap? | **Mesh:** the production Boar is one merged `ArrayMesh` built once and cached: the board prototype's primitives are merged with `SurfaceTool`, using palette vertex colours, and the tusks are re-angled to about 55°. **Shader:** one shared `boar.gdshader` swings the leg vertices, which are marked in the vertex colour alpha. Its phase comes from `NODE_POSITION_WORLD`; the fallback is `MODEL_MATRIX[3].xyz`. **Materials:** three shared materials (idle, run, flash) are swapped with `material_override` on its one MeshInstance3D, so it is one draw call. **Tweens:** attack lunge, hit squash and death squash animate the inner `Body` and finish within 0.15 s. | D-186 open item | D-192 |
| How are piles and shadows kept cheap? | **Piles:** the counter grid, freezer stack, gold pile and carry stack become one `MultiMeshInstance3D` each, using `visible_instance_count`. The fallback is per-instance MeshInstance3D, as today. **Shadows:** no real-time shadows. Characters and Boars get a shared blob-shadow quad (unshaded, a radial alpha texture in palette ink). | S1 perf | D-193 |
| What is the diner and the world? | **Diner:** a roadside diner, `art/env/diner.tscn`, on the existing 8×8×3 m body. It has Fantasy Town wood walls with windows, a **flat roof** with a low parapet (the Archer's perch, D-164), a chimney, a rooftop "DINER" board (a WorldLabel, `tr`), and a city-kit striped awning on the counter side. Its kitchen props are only decor on the walls; the Counter and Freezer stations keep their own art. **Occluder fade:** OccluderFade's AABB comes from the wrapper's merged visual AABB, so it includes the parapet, chimney and board. It also fades Label3D `modulate.a`, and ignores aim points inside the footprint at or above the roof (the
Archer, D-164). There is no MultiMesh under the diner Visual. **Towers:** Tower Defense round pieces; L1 is bottom + top + ballista, L2 adds a middle section, L3 adds a roof and crystals. **Fences:** Castle wood fence at L1, double wood at L2, stone wall-narrow at L3; rubble is Fantasy Town `fence-broken`. **Growth:** the level now changes the model, so `build_level_scale` becomes 1.0 and the scale table's heights are final. **Ground and lanes:** grass ground, dirt lanes with stone edging, a road, and hand-placed trees, rocks and bushes outside the play area (MultiMesh). Visual variation uses a position hash, never Rng. **Lighting:** a warm day, and a blue night that stays readable (D-183 rules), driven by a small `world/lighting_director.gd` on `phase_changed`. | Pillar 1 (diner visibly grows) | D-194 |
| What is the UI skin and card art? | **Skin:** a Theme resource, `ui/theme/game_theme.tres`: StyleBoxFlat in palette colours, rounded, with a dark outline, and Nunito. It covers the HUD panels, banner, card overlay panels and world-label outline colour. **Icons:** HUD icons (coin, steak, diner heart, moon) and card art are rendered from the game's own 3D assets by `tools/render_icons.gd` at 256 px, then quantised through `PaletteMath.remap_image`, and committed as PNGs. **Cards:** each card shows its portrait. **Card strip:** icons + level instead of text glyphs. | Author S4 list | D-195 |
| What are the budgets? | **Perf:** the §1.4 target. Guide metrics from `capture.gd` (desktop, render): at most 120 draw calls at the night-3 peak and at most 150 at the day peak (full queue). **Size:** the §1.5 target. Both ETC2/ASTC and S3TC/BPTC texture sets count toward it. **Per-asset limits:** textures at most 512², icons 256². Triangle budgets come from `art/budgets.gd` (a path → category map, visible meshes only): hero/guard 3k, traveler 3k, Boar 1.5k, tower L3 4k, diner 12k, prop 1.5k. The KayKit counts are measured in Task 4 before the numbers freeze. | D-159 | D-196 |
| Which build-spot and growth details change? | **Level pips:** small palette-gold star meshes, still outside Visual. **Unbuilt marker:** Tower Defense `selection-a`, a sibling of Visual, visible when level == 0 in DAY. **`World.add_static_box`:** becomes collision-only, plus a passed-in visual scene; the collision sizes are unchanged. **`build_level_scale` 1.0:** logged in REVIEW_QUEUE. | Review findings | D-197 |

## 4. Art bible (`docs/ART_BIBLE.md`, Task 2)

ART_BIBLE is the reviewer's checklist for every visual task.

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
3. **Readability rules (D-183),** each answered pass or fail per image:
   - R1. Silhouettes are distinct for the hero, travelers, guards and the Boar.
   - R2. The hero pops: it is the only white/gold figure and has a ring.
   - R3. Travelers are muted: their saturation and value are at most the guards'.
   - R4. Only enemies, telegraphs and danger UI use the enemy reds.
   - R5. Steaks and coins read against the grass and the dirt.
   - R6. Night keeps R1–R5.
   - R7. Everything in the scale table matches within 10%.
   - R8. No placeholder primitive is visible.
4. **Shading.**
   - One DirectionalLight with shadows off, plus ambient.
   - StandardMaterial3D with roughness 1.0, or the shared Boar shader.
   - No PBR textures.
   - Blob shadows under characters and Boars.
5. **Scale table:**

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

6. **Animation table.** It lists the clip for each role and state (idle, move, attack, hit, death or knockout,
   cheer), and marks N/A where a state can't happen:
   - Hero: hit and death N/A (D-161).
   - Archer: hit N/A (D-164).
   - Tank: knockout is the poof fake.
   - Travelers: attack, hit and death N/A.
   - Boar: tweens (idle bob, run hop with shader legs, attack lunge, hit squash with flash, death squash).
7. **Phone check.** Every image is also judged at 40% (288×512) against R1–R8.
8. **Budgets** from D-196.
9. **Sources and process.**
   - CC0 only.
   - The order is: existing packs, then kitbash, then procedural, then generation (only with the author's OK,
     D-182).
   - Log every pack in ASSET_LICENSES.
   - The pipeline steps are §5 of this spec.

## 5. Asset pipeline (Tasks 2–4)

### 5.1 Intake

- **Copy rule:** only files actually used are copied from a pack into `assets/<pack-id>/`, keeping the pack's
  relative path. `.gltf` files keep their `.bin` and texture siblings.
- **Pack ids:**
  - `kenney-tower-defense`
  - `kenney-castle`
  - `kenney-fantasy-town`
  - `kenney-city-commercial`
  - `kenney-food`
  - `kenney-platformer`
  - `kaykit-adventurers`
  - `kaykit-restaurant`
- **Licence log:** ASSET_LICENSES rows follow D-187. Procedural and rendered assets get one row each, as "original,
  made in this repo, CC0".

### 5.2 Palette remap (`core/palette_math.gd` + `tools/palette_remap.gd`)

- **`core/palette_math.gd`** is pure static and unit-tested:
  - `to_oklab(c: Color) -> Vector3`
  - `nearest(c: Color, palette: PackedColorArray) -> int`
  - `remap_image(img: Image, palette: PackedColorArray, overrides: Dictionary) -> Image`. The overrides map a
    source hex to a palette name. Alpha is kept.
- **`tools/palette_remap.gd`** is a `-s` script:
  - It reads `art/palette/remap_manifest.gd`, which lists, for each atlas, its source path, output path and
    overrides, and writes the remapped PNGs.
  - Re-running it gives byte-identical PNGs.
  - The remapped atlases are committed.

### 5.3 Import

- **Props:** Kenney and KayKit prop scenes are wrapped in `art/**/*_visual.tscn` scenes. Their materials are the
  shared `art/materials/<atlas>.tres` (StandardMaterial3D on the remapped atlas, roughness 1). These are set through
  the import's external materials, and as a fallback by overriding each surface in the wrapper. With the fallback,
  the original embedded textures still ship, and the size gate is the backstop.
- **Characters (D-189):**
  - `tools/kaykit_import.gd` strips the clips and writes `art/characters/kaykit_anims.tres`.
  - `art/characters/kaykit_character.tscn` is the base wrapper: the glb's skeleton and meshes, an AnimationPlayer
    using the shared library, an AnimationTree, a `Body` node and a blob shadow. Role scenes inherit it.
- **VRAM compression (D-158):** `project.godot` sets `rendering/textures/vram_compression/import_etc2_astc=true`,
  and every web preset sets `vram_texture_compression/for_mobile=true`.

### 5.4 Asset validator (`tools/asset_validator.gd`, run by `tests/unit/test_assets.gd`)

The validator is static and returns an Array of problem strings; the test asserts it is empty. It skips
`assets/_candidates/`. It checks:

1. **Licences.**
   - Every file under `assets/` is inside a pack folder whose `LICENSE.txt` contains "CC0" or "Creative Commons
     Zero".
   - Every pack folder has an ASSET_LICENSES row whose file count and SHA-256 match disk.
   - No model or texture (`.glb`, `.gltf`, `.fbx`, `.obj`, `.png`, `.jpg`) exists outside `assets/`, `art/`,
     `ui/fonts/`, `export/`, `docs/`, `addons/` and `tests/`.
2. **Palette.** Every PNG under `art/palette/atlas/` and `art/icons/` uses only palette colours on its pixels with
   alpha == 255.
3. **Texture size.** Every texture referenced under `art/` is at most 512×512. Icons are at most 256.
4. **Triangles.** Each scene or mesh in `art/budgets.gd` is within its budget, counting visible meshes only. The
   Boar builder's mesh is included.
5. **Animations.** `kaykit_anims.tres` has every clip in the ART_BIBLE animation table.
6. **No physics in art.** No `PhysicsBody3D`, `CollisionShape3D` or `Area3D` exists under `art/` or in an imported
   `assets/` scene, because collision stays in gameplay code.
7. **No placeholders.** No game script outside `tests/`, `tools/` and `world/visuals.gd` calls `Visuals.box`,
   `capsule`, `cylinder`, `cone` or `plane`. This rule turns on in Task 12; before that it is a printed warning.

### 5.5 Export and size gate

- The exclude filters follow D-187.
- `pages.yml` (a hot file; the main session edits it, in Task 4) prints the raw release pck size and `gzip -9` of
  wasm + pck + js. It fails above 8 MB or 16 MB respectively (D-196).

## 6. Visual architecture

### 6.1 `ActorVisual` (`components/actor_visual.gd`, class_name ActorVisual, extends Node3D, name "Visual")

```
func set_motion(speed_frac: float) -> void   # 0 = idle, 1 = full run speed
func face(dir: Vector3) -> void              # world XZ direction; ignored when its length < 0.01
func attack() -> void                         # upper-body one-shot (characters) or lunge (Boar)
func hit() -> void                            # Hit_A one-shot (Tank, throttled) / squash (Boar)
func set_flash(on: bool) -> void              # Boar: idle/run material <-> flash material
func die() -> void                            # Boar squash; finishes within 0.15 s; never changes gameplay timing
func reset() -> void                          # back to idle, Body transform identity, flash off
var flash_active: bool                        # mirrors the last set_flash()
```

- **Ownership (D-190).** The Visual root's `scale` and `visible` belong to the existing gameplay tweens.
  ActorVisual only touches `Body` (the model's parent), the AnimationTree and the materials.
- **Facing.** `Body` turns toward `face()` at `Balance.ui.visual_turn_speed` (rad/s; default 14) in `_process`.
- **KayKitVisual** (`art/characters/kaykit_visual.gd`) drives an AnimationTree:
  - a `locomotion` BlendSpace1D (Idle at 0, Walking_A at 0.5, Running_A at 1);
  - an `action` OneShot filtered to the spine, arm and head bones (Throw and the attacks);
  - a full-body `react` OneShot (Hit_A);
  - a `cheer` OneShot.

  The crossfade is `Balance.ui.anim_blend_s` (0.12).
- **BoarVisual** (`art/boar/boar_visual.gd`) uses the shared mesh and materials (D-192). Run vs idle comes from
  `set_motion`.
- **Call sites:**
  - `reset()`: `Boar.spawn`, `Traveler.begin`, `Guard.place_at_post` and `Guard.arrive_from_door`.
  - `set_flash()`: the Boar's existing flash start and end points.
  - `attack()`: `Attacker.fired`.
  - `hit()`: `Boar.take_hit` and the Tank's `guard_damaged`.
  - `die()`: `Boar.play_death`, beside its existing scale tween, which keeps owning the root.
- **Motion.** Each actor derives `set_motion` and `face` from its own position delta per physics tick (the hero
  from `velocity`). The result is divided by that actor's move speed and clamped to 0..1.

### 6.2 Tests that peek at visuals

The tests listed in §9.2 move to the contract with the same semantics:
- A hit still flashes for 0.08 s, and `test_fx` still asserts that the Boar mesh's `material_override` is the
  non-flash material after the flash, after release and after spawn.
- Rubble still differs visibly.
- The sign still pulses.
- Pips, stacks and level visuals still match their counts.

No test is dropped or weakened (D-132 spirit).

### 6.3 Gameplay identity (the determinism baseline)

- **Recording:** before any visual change (Task 1), the main session records on its Mac (Godot 4.7.2):
  - for each seed, `"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --seed=N`;
  - then `cp tests/sim/out/sweep.csv tests/sim/baseline/s4_sweep_<seed>.csv`;
  - and `grep -E '^(SWEEP|RETRIES) '` of stdout into `tests/sim/baseline/s4_sweep_<seed>.txt`.

  It runs twice, and the two runs must be identical before they are committed.
- **Diff:** every phase PR re-runs the same commands on the Mac and diffs them, and the PR body says "baseline
  identical". **The baseline is never re-recorded in S4; a diff is a bug.**
- **What must not move:**
  - Attacker origins (hero 0, guard 1.0, tower 1.5; the launch +1.0 in `attacker.gd`);
  - the projectile aim +0.5;
  - collision shapes and sizes;
  - pool sizes and release timings;
  - the poof, death and pop durations;
  - anything in `_physics_process` of gameplay nodes except calls into Visual.
- **Visual scripts** never write gameplay nodes or GameState, never call `Rng`, never await in gameplay paths, and
  never add physics nodes (§5.4 rule 6).
- **Rand scan:** `tests/unit/test_no_global_rand.gd` adds `res://art` and `res://tools` to `SCAN_DIRS` (Task 2).

## 7. Per-item art (Tasks 5–14)

| Item | Art | Notes |
|---|---|---|
| Hero | KayKit Barbarian as the cook, chef hat, apron, pan, ring | D-191. Ring: flat torus r0.7 m, palette warm white, alpha `Balance.ui.hero_ring_alpha` 0.6, unshaded. |
| Hero projectile | kk-restaurant `knife`, spinning at `Balance.ui.knife_spin_deg_s` (720) about its local X | The art is chosen by the projectile's source kind. |
| Archer | Rogue_Hooded, crossbow_2handed, `2H_Ranged_Shoot` | On the flat roof. |
| Archer and tower projectile | kk-adventurers `arrow`, nose along velocity | |
| Tank | Knight, sword + shield badge, `1H_Melee_Attack_Slice_Diagonal` | HP bar restyled: palette ink back, green fill, rounded ends. |
| Travelers | Rogue / Mage, no props, three muted variants each | Variant from the factory counter (D-191). |
| Boar | Production procedural mesh (D-192) | Tusks at about 55°, ridge of 5. |
| Steak | kenney-food `meat-cooked` (fallback `meat-ribs`) | Same model on the ground, in stacks and in fly FX. |
| Coin | Procedural gold disc (`art/pickups/coin_mesh.gd`, D-208) | Pile, fly FX and icon source. |
| Carry stack | MultiMesh of steaks above the hero's hands | Up to the carry cap. |
| Counter | kk-restaurant `kitchencounter_straight_*` ×3 + a steak MultiMesh grid | On the existing 3×1 body. |
| Freezer | kk-restaurant `fridge_A` + a steak MultiMesh stack beside it | On the existing 1.5×1.5 body. |
| Gold pile | Coin MultiMesh in a heap pattern | |
| Diner | Fantasy Town walls/windows/door, flat roof + parapet, chimney, rooftop board (WorldLabel "DINER"), city-kit awning, kk-restaurant stove/menu decor | `art/env/diner.tscn`. Fallback if draw calls run high: merge into 2 ArrayMeshes (walls, roof). |
| Tower L1–L3 | kenney-tower-defense round pieces + `weapon-ballista` | The model changes per level (D-194). |
| Fence L1–L3, rubble | castle wood fence / double / stone wall-narrow; fantasy-town `fence-broken` | Rotated to the lane tangent as today. |
| Level pips | Palette-gold star meshes | Outside Visual, as today (D-197). |
| Unbuilt marker | kenney-tower-defense `selection-a` | A sibling of Visual, visible at level 0 in DAY (D-197). |
| Close-up sign | Wooden post + board (fantasy-town pieces) + a WorldLabel "Close up" (tr) | The pulse is kept. |
| Telegraph | Red pennant flag (castle `flag-pennant`) scaled by threat | Enemy reds only. |
| Lane | Dirt strip mesh with stone edge pieces; entrance: castle `gate` posts | |
| Ground and road | Grass plane (palette grass, position-hash vertex variation), road strip | |
| Props | castle trees and rocks, tower-defense detail rocks/trees, outside the play bounds | Hand-placed list `art/env/props_layout.gd`; one MultiMesh per model. |
| Lighting | Day: warm sun + sky ambient. Night: blue moon light + dim ambient. A tween of `Balance.ui.lighting_tween_s` (1.5 s) on `phase_changed`. | `world/lighting_director.gd`. Colours and energies in UiTuning. |
| UI | `game_theme.tres`; HUD icons; banner and card overlay panels; world labels in palette ink outline | |
| Card art | **hero_damage** "Sharp Cleaver": kk-restaurant `knife`, large. **attack_speed** "Quick Hands": three knives fanned. **move_speed** "Running Shoes": the cook mid-run (Running_A pose). **carry_capacity** "Big Backpack": a stack of 3 steaks. **gold_per_steak** "Fancy Menu": kk-restaurant `menu`. **archer** / **tank**: the guard models' portraits. | `tools/render_icons.gd` writes to `art/icons/`. |

Every number above that is a tuning value lives in `balance/ui_tuning.gd` (§8).

## 8. Hot files and wiring

These files take wiring from the main session (D-139, D-181):
- **`world/world.gd`:** the diner scene, `add_static_box` → collision + visual scene, ground and lanes, props,
  LightingDirector, the projectile art kind, and the traveler variant counter.
- **`balance/ui_tuning.gd` and `balance/ui_tuning.tres`:**
  - `visual_turn_speed`, `anim_blend_s`, `hit_react_cooldown`;
  - `hero_ring_alpha`, `knife_spin_deg_s`, `lighting_tween_s`;
  - the day/night light colours and energies;
  - the Boar tween values;
  - `build_level_scale` → 1.0.
- **`project.godot`:** the theme and `import_etc2_astc`.
- **`export_presets.cfg`:** the exclude filters and `for_mobile`.
- **`.github/workflows/pages.yml`:** the size gate.
- **`CLAUDE.md`:** the layout.

Implementers report the exact lines.

## 9. Testing and verification

### 9.1 Unit

- `palette_math`: Oklab nearest, overrides, alpha kept, determinism.
- The validator, against good and bad fixture folders under `tests/unit/fixtures/assets/`. There is one bad fixture
  per rule.
- The ActorVisual contract, per role visual:
  - it instantiates headless;
  - the `set_motion` / `attack` / `hit` / `set_flash` / `die` / `reset` cycle has no errors;
  - `flash_active` mirrors `set_flash`;
  - the facing converges;
  - the root's `scale` and `visible` are untouched by every contract call.
- The Boar mesh: one surface, triangles within budget, a leg-mask vertex count above 0.
- Tower and fence level models differ per level.
- The unbuilt marker's visibility.
- The lighting director's day and night targets.
- OccluderFade on the real `art/env/diner.tscn`: the AABB covers the parapet and board, and the board's Label3D
  fades. The existing fixture test stays.
- With only the Archer hired, standing at its roof post, the diner stays opaque. OccluderFade ignores aim points
  inside the diner footprint at or above `DINER_HEIGHT`; the Archer can't be hidden by its own roof (D-164).
- `test_no_global_rand` covers `art/` and `tools/`.

### 9.2 Updated tests (same semantics, §6.2)

- `test_fx`
- `test_guards`
- `test_build_spots`
- `test_restore_world`. With `build_level_scale` 1.0, a surviving pop tween no longer shows in the scale, so it
  also asserts `not (spot._pop != null and spot._pop.is_valid())` after a restore, as `test_fx` does.
- `test_occluder_fade`
- `test_hud` (fill colour from the palette)
- `test_stations`, `test_hero`, `test_travelers` (MultiMesh visible counts)
- `test_sign_and_telegraph`

### 9.3 Sims

Unchanged, and under 60 s (D-132). The headless cost of skinned characters is measured in Task 5. If the sim suite
grows by more than 10 s, escalate with timings.

### 9.4 Per-visual-task shot list and review

- **Shots:** `tests/sim/capture.gd` gets `--phase=night` (it starts night 1 and waits for the first Boars). Every
  visual task renders these to `docs/review/media/s4/<task>/`, each at 720×1280 plus a 40% copy:
  1. a day overview;
  2. a night overview;
  3. the west lane, the north lane and the east lane (`--lane=`);
  4. a close-up of the subject. For diner work this includes D-151's "hero at north zone centre" shot.
- **Device check:** `export/device_check.sh` runs on the iOS Simulator against the task's phase preview URL after
  the push.
- **Review:** the reviewer gets the shot paths and the ART_BIBLE checklist, must view every image, and answers
  R1–R8 pass or fail per image.

### 9.5 Perf harness (Task 4) and checkpoints

- **Fixtures:** `tests/sim/make_save.gd` runs a PlannerBot (seed 20260930) to the close-up that precedes night 3
  and writes two S3 save envelopes:
  - `export/fixtures/night3_start.save.json`: that snapshot with `resume_phase = "NIGHT"`. `resume_from` restores
    it and enters night 3 at once, with no input (`phase_controller.gd` night-restart path).
  - `export/fixtures/night3_closeup.save.json`: the same snapshot with `resume_phase = "DAY"`, for the day-peak
    reading. The hero waits at HOME while travelers queue.
- **Script:** `export/perf_night3.sh <profile_build_dir>`:
  - serves the build locally;
  - copies `export/seed_save.html` into the served root;
  - opens `seed_save.html?to=<game path>` in the iOS Simulator. The page writes the fixture into
    `localStorage["lst:<pathname>:save"]` and redirects to the game. `<pathname>` is the game's
    `location.pathname` with a trailing `index.html` trimmed (`SaveStore.normalize_path`).

  With `night3_start` the game resumes straight into night 3; with `night3_closeup` it resumes into the day.
- **Readings:** the perf overlay's 60 s average and worst frame, read at about 80 s into night 3, plus a day-peak
  window.
- **Android:** the same is done for emulated Pixel 7 (`pw_check.mjs` with injection, labelled emulated).
- **Checkpoints:** end of P2 (Task 7), end of P4 (Task 12), and P6 (Task 15). The numbers go in each PR body. Below
  58 fps, apply the §11 fallbacks in order before going on.

### 9.6 Media for the final review

Major screens:
1. day overview with travelers queued;
2. night combat;
3. the dawn card pick;
4. the fail banner and retry;
5. a build in progress (progress ring + label);
6. the HUD close-up.

Plus one shot per lane. The "before" set is captured in Task 1 to `docs/review/media/before/` (`capture.gd` +
iOS Simulator), and the "after" set in Task 16 to `docs/review/media/after/`, with the same framing.

## 10. Build order (a hint for writing-plans)

| Phase | Branch | Tasks |
|---|---|---|
| P1 Foundation | `s4/p1-foundation` | 1 before media + determinism baseline + capture `--phase=night`; 2 ART_BIBLE + palette + remap + rand scan; 3 intake + licences + validator; 4 import pipeline + VRAM compression + export filters + size gate + perf harness |
| P2 Characters | `s4/p2-characters` | 5 ActorVisual + KayKitVisual + blob shadow + test moves; 6 hero (cook, knife, ring); 7 guards + travelers + **perf checkpoint** |
| P3 Boar and pickups | `s4/p3-boar` | 8 production Boar; 9 steak/coin/stacks/piles/fly FX/projectiles |
| P4 World | `s4/p4-world` | 10 diner + counter + freezer + `add_static_box`; 11 towers/fences/pips/markers/sign/telegraph/lane ends; 12 ground/lanes/props/lighting + validator placeholder rule on + **perf checkpoint** |
| P5 UI | `s4/p5-ui` | 13 theme + HUD skin + labels; 14 icon renders + card art + card strip |
| P6 Results | `s4/p6-results` | 15 perf + size + load; 16 after media + results + review queue |

Tasks in one phase with disjoint files may run in parallel (D-136), at most 3 at once.

## 11. Risks

| Risk | Mitigation (in order) |
|---|---|
| Night-3 fps drops below 58 (S1 placeholder baseline: 58.4 at night 1, so there is no headroom) | Checkpoints at P2 and P4. 1. AnimationPlayer only (no AnimationTree) for travelers. 2. 15 Hz animation updates for travelers and guards. 3. Merge the diner into 2 ArrayMeshes. 4. Fewer props. 5. Drop blob shadows for travelers. |
| Draw calls: KayKit characters are several mesh nodes each | Count in Task 5. Hiding props removes their draws. |
| The post-import script fails headless | Fallback: `_subresources` per clip (D-189). |
| Imported materials break OccluderFade | Our own StandardMaterial3D (§5.3); a real-diner test (§9.1). |
| Palette remap muddies KayKit faces | Per-swatch overrides; skin tones are dedicated palette entries; reviewed in Task 2's closeup. |
| AnimationTree bone filters misbehave on web | A full-body Throw only when standing still. |
| MultiMesh `visible_instance_count` issues | Per-instance MeshInstance3D, as today. |
| Sim time grows from headless animation | Measure in Task 5; escalate per D-132. |
| The pck exceeds 8 MB | Trim unused files; shrink textures; drop the second traveler body. |

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

## 13. Results (S4)

**What shipped.** Every placeholder primitive is gone; the validator bans them. The game now has a cohesive CC0
look:
- **Cast:** KayKit Adventurers. The hero is a cook with a chef hat, apron and pan who throws knives. The Archer is
  hooded with a crossbow, the Tank has a helmet, sword and shield, and travelers come in six muted looks.
- **Boar:** a procedural tusked Boar.
- **World:** Kenney kits. A roadside diner with a flat gravel roof and a DINER board, towers and fences whose model
  changes per level, dirt lanes with stone edging, and trees and rocks.
- **Pickups:** Kenney steaks and a procedural gold coin.
- **UI:** a palette theme with bold Nunito, rendered icons and card portraits.
- **Lighting:** day and night.

All of it sits in one 32-colour palette (D-188). Gameplay is unchanged: the determinism baseline was identical
after every task in P1–P6.

**How it was kept fast (D-201).** Draw calls, not triangles or animation, set the frame rate on web. So:
- each character is baked offline into one skinned mesh with its props;
- every blob shadow is one MultiMesh;
- ground steaks are one MultiMesh;
- each pile is one MultiMesh;
- the diner, each tower and fence level, and the terrain are baked or merged per material;
- the card strip and HUD icons draw from one atlas.

| Result | Value |
|---|---|
| Unit / sim tests | 688 unit, 9 sim (sim suite 8–9 s of 60 s) |
| Determinism baseline | Identical after every task (seeds 20260930, 11, 777) |
| Asset validator | Green in CI: licences, palette, enemy colours, sizes, triangles, animations, no physics in art, no placeholders |
| Licences | 7 CC0 packs (Kenney ×5, KayKit ×2), one row each in ASSET_LICENSES; procedural Boar, coin, icons and palette made in the repo. The Platformer pack was removed. |
| Night-3 fps, iOS Simulator, profile build (gate ≥ 58, median of 3) | **59.0** (runs 59.3 / 55.8 / 59.0; the 55.8 run had the Mac drop to 39% idle mid-run). Earlier checkpoints: placeholder baseline 58.3; P2 after the character bake 58.2; P4 59.8. |
| Day-3 fps, same harness | 49.6 on a busy machine; 57.3 at the P4 checkpoint on an idle one. Not the gate; in known issues. |
| Draw calls at night 3 | Simulator: 36 (placeholder baseline 35). Desktop capture: 48 with 2 or with 7 cards owned (guide ≤ 120). |
| Worst frame at night 3 | About 115–140 ms once per night, at the first wave spawn (known issue, S5). |
| Emulated Pixel 7 (Playwright, software GL) | 6.1 fps, 0 page errors: a smoke check only, not a device figure (D-141). |
| Release size | pck 4,398,040 B raw (gate 8 MiB); `gzip -9` of wasm + pck + js 12,787,266 B (gate 16 MiB). Before S4 the payload was 10.3 MB. |
| Load time | Deferred to the final review on a real phone (D-159). Localhost Simulator load is not comparable. |

**Fallbacks from §11 that were used:** none of the animation fallbacks; turning animation off was worth only +2
fps. Instead, D-201 added three things the spec did not plan: the offline character bake, the shared shadow and
pickup fields, and the UI atlas.

**Deviations from the spec, all logged:**
- KayKit is a third CC0 source (D-186).
- Characters are baked, not wrapped (D-201).
- The hero wears a full white coat (D-201).
- Tower L3 has no roof or crystals (D-205).
- The coin is procedural and the Platformer pack is dropped (D-208).
- The character triangle budget is 5500 (D-198).
- The perf gate is the median of 3 runs on an idle machine (D-199, D-209).

**Skipped nits (D-185):** the coin back-face ridge normal sign (cosmetic).

**Open risks carried to S5 and the final review:**
1. The fps gate is measured in the iOS Simulator on the author's Mac, and it moves by several fps with whatever
   else the Mac is doing. A real mid-range phone has not been measured.
2. Day-phase fps is lower than night.
3. The first-wave stall.
4. The Boar's tusks are small at phone size.
5. Fence L1 and L2 differ mainly by posts.

