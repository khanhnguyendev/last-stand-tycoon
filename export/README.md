# Web export

Presets (export_presets.cfg): `web_debug` (debug template, debug overlay + hotkeys G/J/N/K/F/O; the bottom-right "Fade alpha" button and O cycle the occluder alpha 0.30/0.45/0.60 live, D-151),
`web_profile` (release template, fps/frame-time overlay only), `web_release` (GitHub Pages builds, D-135).
All single-threaded (no COOP/COEP headers needed) with the custom shell `export/web_shell.html`.

```bash
"$GODOT" --headless --path . --export-release "web_release" build/web_release/index.html
cd build/web_release && python3 -m http.server 8000 --bind 127.0.0.1   # desktop check only: http://localhost:8000/ (localhost is a secure context)
```

Release check: `grep -a -c "ui/debug" build/web_release/index.pck` must print 0. The `pages` workflow runs the same check on the release and profile packs and fails the deploy on a hit; if `main.gd`'s `load("res://ui/debug/...")` string alone makes it non-zero, narrow the check to the overlay's script entry and log the change (D-135).

Phones: push the branch; the `pages` workflow deploys it to https://khanhnguyendev.github.io/last-stand-tycoon/preview/<slug>/ (slug: branch name, every character outside [A-Za-z0-9._-] → "-")
(main: the site root). The bottom-left label shows the build's git hash. Plain-http LAN does not work
(secure context, D-120). The itch.io draft is S6.

Checks without a phone (D-138, D-141): `export/device_check.sh <url> <out_dir>` (iOS Simulator, Android Emulator if installed, else
Playwright "Pixel 7", labelled emulated) and `node export/pw_check.mjs <url> <out.png> [android|desktop]` (Playwright from `$LST_PW_DIR`,
default `~/.cache/lst-playwright`). Both expect `window.LST_BUILD`, which the pages workflow injects; a local build needs
`<script>window.LST_BUILD="local";</script>` added before `</head>` of its `index.html`.
