# Load time and size (release web export, `web_release`, branch at 23b7d7b + this commit)

All load times are **localhost** (`export/serve_nocache.py`, no compression, no network): not comparable to a phone on a network. Chromium runs use software GL (SwiftShader), so they are slower than a real GPU.

## Size
| file | raw B | gzip -9 B |
|---|---|---|
| index.wasm | 39,514,754 | 10,054,769 |
| index.pck | 5,514,672 (5.26 MiB; gate 8 MiB) | 3,685,354 |
| index.js | 279,815 | 68,480 |
| wasm+pck+js together | | 13,807,478 (13.17 MiB; gate 16 MiB) |
`grep -a -c ui/debug index.pck` = 0 for release and profile (6 for the debug build, as expected).

## Chromium (Playwright Pixel 7 profile, headless, software GL), 3 fresh-context runs
Signal: the release build prints nothing to the console, so `load_time.mjs` forces `preserveDrawingBuffer` on the game canvas via an init script and reads a 9x9 pixel grid every animation frame. `t_load` = the `load` event; `t_engine` = Godot's `#status` splash overlay removed; `t_first_px` = first canvas frame with a mean brightness above 3/255 (the first game frame, under the boot fade); `t_full` = first frame at >= 90% of the final mean brightness (boot fade lifted).
| run | t_load | t_engine | t_first_px | t_full |
|---|---|---|---|---|
| 1 | 28 ms | 4796 ms | 4783 ms | 9148 ms |
| 2 | 77 ms | 3700 ms | 3689 ms | 7974 ms |
| 3 | 47 ms | 3582 ms | 3574 ms | 7941 ms |
Raw: `load_time_chromium.txt`. Frame rate under SwiftShader is about 6 fps, so values are good to roughly +/- 0.2 s. The ~4 s between first pixel and "full" is mostly the warm-up under the fade at 6 fps; the game itself is playable in the Simulator much sooner (below).

## iOS Simulator (iPhone 17 Pro, Safari, release build on localhost), 3 runs, `simctl io screenshot` every ~0.2 s
Classified by pixels of each screenshot (dark splash with the Godot logo, then a dark-blue canvas, then the green game view).
| run | engine started (splash gone, dark-blue canvas) | first game frame (HUD, "The monsters return" banner) |
|---|---|---|
| 1 | 4.67 s | 6.41 s |
| 2 | 4.58 s | 6.13 s |
| 3 | 4.44 s | 6.18 s |
Times are from the `simctl openurl` call (includes about 0.3 s of Safari launching); the screenshot cadence is ~0.2 s. The Godot logo splash shows for the whole download/compile part (about 2-4.5 s here).
