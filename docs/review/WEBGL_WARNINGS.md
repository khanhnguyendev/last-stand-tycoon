# Carried WebGL warnings: attribution (S5 Task 4, spec §9)

The two warnings, as the Task 1 baseline on `main` records them (`docs/review/media/s5/console_baseline_main.txt`):

```
WebGL: INVALID_OPERATION: bindBuffer: element array buffers can not be bound to a different target
WebGL: INVALID_OPERATION: bufferSubData: no buffer
```

They always come as a pair, and they are not one-time: they repeat.

## Finding

**The trigger is the HUD edge arrows: two `Polygon2D` nodes made in `ui/hud/hud.gd` (`_ready`, `for key in ["main", "side"]`).**
They are the only `Polygon2D` (or `draw_colored_polygon` / `draw_polygon`) in the game. The warnings fire when an arrow
becomes visible (`_on_wave_incoming`: `arrows.main.visible = ...`), and not otherwise.

## Method

Debug web export (`web_debug`) of the Task 4 branch (equal to `main` for this purpose: the FxField draws nothing until a
burst is requested, and no gameplay code emits `fx_requested` yet), served from `export/serve_nocache.py`, Playwright
Chromium (Pixel 7 profile, SwiftShader, `~/.cache/lst-playwright`), 100 s of a fresh start (`?reset=1`) with every console
line timestamped from `goto`. The game runs at 5-7 fps on software GL, so the timings are slow-motion game time; the same
events land at 26-34 s, 59-79 s and 88-93 s in different runs.

Reproduction on the unmodified build (3 runs): a pair at about 26-34 s, a pair at about 59-79 s, in the longer runs a
third pair at about 88-93 s.

Screenshots every 3 s next to the console timestamps tie each pair to an arrow showing: the first pair lands as wave 0 is
cleared and the arrow for wave 1 appears; the second as the diner falls ("The diner fell") and the night restarts with
the arrow for wave 0; the third as the "monsters look tired" retry night starts.

Bisect (scratch edits, reverted; one debug export + 100 s run each):

| Run | Scratch change | Pairs seen |
|---|---|---|
| baseline | none | 2 in 90 s (3 in 100 s) |
| C | `WaveDirector.start_night` returns at once (no enemies, no waves) | **0** |
| D | no steak drops on kill | 2-3 |
| E | Boar visual hidden at spawn | 2 |
| F | projectile hidden after launch | 3 |
| GH | HUD moon repaint and `_place_arrows` skipped | 2 |
| I | **the arrows never set visible** | **0** |
| J | arrows made `ColorRect` instead of `Polygon2D` | **0** |

(An earlier "A+B" run, PickupField and ShadowField `MultiMesh` capacity pre-sized so they never resize, also showed the
warnings, but that run may have been served by a stale build, so it is not counted. D, E, F, GH, I and J were each served by
the freshly exported build.) C removes every wave and so every arrow, I removes only the arrows, and J swaps only the node
type, so the arrow `Polygon2D` is the draw that triggers them. No MultiMesh, pooled mesh, shader, steak, projectile, boar
or HUD moon is involved.

## Ours or the engine

Probably the engine's canvas polygon path in the Compatibility (GLES3) renderer under WebGL 2: a `Polygon2D` is drawn
through a dedicated polygon vertex/index buffer pair, and WebGL forbids binding a buffer that was first bound as
`ELEMENT_ARRAY_BUFFER` to another target, which is what the first message says; the `bufferSubData` that follows has
no buffer bound, which is the second. Our code only creates a three-point `Polygon2D` and toggles its visibility. This
is inferred from the behaviour (the warning goes away exactly when the node type changes) and not read from the engine
source (Godot 4.7.2); confirming it would need `drivers/gles3/rasterizer_canvas_gles3.cpp` (polygon buffer allocation). Nothing is visibly wrong:
the arrows draw correctly.

## Is there a one-file fix?

Yes, in `ui/hud/hud.gd` only: draw the arrow without `Polygon2D`. Options, in order of fit with the project rules:

1. Use an `IconAtlas` cell for the arrow (D-201: UI icons come from `IconAtlas`; no `Polygon2D` for new UI). Needs a
   downward-triangle cell in the icon atlas, which is `art/icons`, so it is not one file.
2. A `TextureRect`/`Sprite2D` with a small procedural triangle `ImageTexture` built once in the HUD (one file). The
   colour is `enemy_red`, as now. `_place_arrows` types the nodes as `Polygon2D` (`var arrow: Polygon2D`) and sets
   `position` and `rotation`; a `Sprite2D` keeps both.

J shows that a non-polygon node removes the warnings. J was an unfinished test only (a `ColorRect` has no pivot and `_place_arrows`
raised a type error after the arrow was shown); option 2 with a centred `Sprite2D` is the proper version. It has not been written
or run, since this task is investigation only.

## Open question

Whether the Compatibility renderer under real iOS Safari prints the same warnings. This was seen only on desktop Chromium
(SwiftShader). The Task 1 baseline records the same pair on Chromium; the iOS Simulator console was not read.
