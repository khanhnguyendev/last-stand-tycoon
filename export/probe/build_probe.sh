#!/usr/bin/env bash
# Builds the safe-area probe (D-135) as a Godot web export into <out_dir>.
# The probe project is generated in a temp dir from heredocs, so the main
# project never parses probe scripts.
# Usage: GODOT=/path/to/godot export/probe/build_probe.sh <out_dir>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <out_dir>" >&2
  exit 2
fi
if [ -z "${GODOT:-}" ]; then
  echo "GODOT is not set" >&2
  exit 2
fi

mkdir -p "$1"
OUT="$(cd "$1" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/project.godot" <<'EOF'
config_version=5

[application]
config/name="lst-safe-area-probe"
run/main_scene="res://probe.tscn"

[display]
window/size/viewport_width=720
window/size/viewport_height=1280
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

cat > "$TMP/export_presets.cfg" <<'EOF'
[preset.0]

name="web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/index.html"

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
html/canvas_resize_policy=2
EOF

cat > "$TMP/probe.tscn" <<'EOF'
[gd_scene format=3]

[ext_resource type="Script" path="res://probe.gd" id="1"]

[node name="Probe" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
EOF

cat > "$TMP/probe.gd" <<'EOF'
extends Control

const JS := "(function(){var d=document.createElement('div');d.style.cssText='position:fixed;visibility:hidden;padding-top:env(safe-area-inset-top);padding-bottom:env(safe-area-inset-bottom);padding-left:env(safe-area-inset-left);padding-right:env(safe-area-inset-right)';document.body.appendChild(d);var s=getComputedStyle(d);var r=[s.paddingTop,s.paddingBottom,s.paddingLeft,s.paddingRight,window.innerWidth,window.innerHeight,window.devicePixelRatio,window.isSecureContext,window.self!==window.top,window.LST_BUILD||'local'].join(',');d.remove();return r;})()"

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.position = Vector2(24, 220)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(_refresh)
	add_child(t)
	_refresh()


func _refresh() -> void:
	var build := "local"
	var css := "n/a"
	var inner := "n/a dpr=n/a"
	var secure := "n/a iframe=n/a"
	if OS.has_feature("web"):
		var p := str(JavaScriptBridge.eval(JS, true)).split(",", true, 9)
		if p.size() == 10:
			css = "%s,%s,%s,%s" % [p[0].trim_suffix("px"), p[1].trim_suffix("px"), p[2].trim_suffix("px"), p[3].trim_suffix("px")]
			inner = "%sx%s dpr=%s" % [p[4], p[5], p[6]]
			secure = "%s iframe=%s" % [p[7], p[8]]
			build = p[9]
	_label.text = "build=%s\nsafe=%s\nwin=%s\nscreen=%s scale=%s\ncss(top,bottom,left,right)=%s\ninner=%s\nsecure=%s" % [
		build,
		DisplayServer.get_display_safe_area(),
		DisplayServer.window_get_size(),
		DisplayServer.screen_get_size(),
		DisplayServer.screen_get_scale(),
		css,
		inner,
		secure,
	]
EOF

"$GODOT" --headless --path "$TMP" --import
"$GODOT" --headless --path "$TMP" --export-release "web" "$OUT/index.html"

# iOS reports env(safe-area-inset-*) as 0 unless the viewport meta has viewport-fit=cover
python3 - "$OUT/index.html" <<'PY'
import re, sys
f = sys.argv[1]
t = open(f, encoding="utf-8").read()
def fix(m):
    tag = m.group(0)
    if "viewport-fit=cover" in tag:
        return tag
    return re.sub(r'(content=")([^"]*)(")', lambda c: c.group(1) + c.group(2) + ", viewport-fit=cover" + c.group(3), tag, count=1)
t2, n = re.subn(r'<meta\s+name="viewport"[^>]*>', fix, t, count=1)
if n != 1:
    sys.exit("no viewport meta in " + f)
open(f, "w", encoding="utf-8").write(t2)
PY
[ "$(grep -c "viewport-fit=cover" "$OUT/index.html")" -ge 1 ] || { echo "viewport-fit=cover missing" >&2; exit 1; }
ls -l "$OUT"
