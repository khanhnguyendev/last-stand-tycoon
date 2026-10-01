# S4 style board (D-183, D-186)

Rendered by `tests/style_board/style_board.gd`, run with rendering:
`"$GODOT" --path . --resolution 720x1280 -s res://tests/style_board/style_board.gd -- --set=<a..e> --out=<png>`.
Candidates are copied into `assets/_candidates/`, which is gitignored. The game camera matches
`tests/sim/capture.gd`: `CameraMath` with the real lens.

Every board has the same environment: a diner kitbashed from Kenney Fantasy Town walls and roof, a Kenney Tower
Defense round tower, a Castle-kit wood fence, Food-kit steaks and Platformer-kit coins. Left to right, the lineup is
hero, traveler, traveler, Archer, Tank, Boar.

| Set | Cast | Boar | Verdict |
|---|---|---|---|
| a | Kenney Blocky Characters | Kenney Cube Pets hog | Rejected. Blocky characters on rounded kits; the hog reads as a toy pet. |
| b | Quaternius Ultimate Animated Characters | Quaternius farm Pig, tinted, with tusks | Rejected. Slim bodies are lost at distance; no archer mesh; no run animation; the faceted Pig doesn't match. |
| c | KayKit Adventurers | farm Pig | The cast is right; the Boar is not. |
| d | KayKit + chef treatment | Quaternius cute-monster Pig (head only) | The hero is solved; the Boar has no body and one animation. |
| **e** | **KayKit + chef hero, muted travelers, hero ring** | **procedural rounded Boar** | **Picked.** |

## Why set E

- **Cohesion:** KayKit bodies are chunky, rounded and big-headed with bright flat colours, which is the same
  language as the rounded Kenney kits.
- **Roles read at phone size** (`set_e_focus_phone40.png`, 288×512):
  - The hero is the brightest spot (white chef hat, white apron, warm ring).
  - The Archer reads as a green hood.
  - The Tank reads as a steel helmet with a shield.
  - The travelers are grey-beige and unarmed.
  - The Boar is a dark red body with a black ridge and white tusks.
- **Night:** `set_e_focus_night_phone40.png` keeps the same read.
- **Animation:** KayKit has idle, run, attacks, hit and death on one shared rig. The Boar's five animations are
  tweens (`tests/style_board/proto_boar.gd`).

## Files

- `set_a.png` … `set_e.png`: the real game camera at 720×1280.
- `*_closeup.png`: a low 3/4 view at 1280×720 for faces and detail.
- `set_d_phone40.png`, `set_e_phone40.png`, `set_e_focus_phone40.png`: 40% phone-size checks.
- `set_e_night.png`, `set_e_focus_night*.png`: approximate night lighting.
- `set_e_focus*.png`: the lineup moved out from under the diner roof (same lens).
- `boar_options_closeup.png`: farm Pig vs cute-monster Pig vs tinted cute-monster Pig.
- `boar_proto_turnaround.png`: the procedural Boar from the front, 3/4, side and top.
- `animations.md`: the animation names for every candidate.
