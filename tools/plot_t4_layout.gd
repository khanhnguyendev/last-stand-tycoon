extends SceneTree
## E8 phase 2 Task 6: a top-down plot of the tier-4 layout (spec 4.3), drawn into an Image from MapLayout alone (no rendering, runs headless).
##   "$GODOT" --headless --path . -s res://tools/plot_t4_layout.gd -- --out=docs/review/media/e8/backlot
## Writes layout_t4.png (the whole map, 24 px per metre, north up) and layout_t4_home.png (the HOME camera's 9:16 view region and the south-east
## quarter around the back lot). Colours: lanes brown with the monsters' spread, zones red, fence bars orange, diner/counter/freezer grey,
## tier-2 and tier-3 yards blue, tier-4 yards green, existing towers white, tier-4 towers yellow, existing pads cyan, tier-4 pads yellow rings,
## signs purple (tier 4 magenta), queue slots dots, the HOME camera's 9:16 ground view a white outline.

const PPM := 24.0
const MIN := Vector2(-24, -24)
const MAX := Vector2(24, 14)
var img: Image
var origin: Vector2

func _px(p: Vector2) -> Vector2i:
	return Vector2i(int(round((p.x - origin.x) * PPM)), int(round((p.y - origin.y) * PPM)))

func _dot(p: Vector2i, c: Color) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
		img.set_pixelv(p, c)

func _line(a: Vector2, b: Vector2, c: Color, w := 1) -> void:
	var n := int(a.distance_to(b) * PPM) + 1
	for i in n + 1:
		var q := _px(a.lerp(b, float(i) / n))
		for dx in range(-(w / 2), w / 2 + 1):
			for dy in range(-(w / 2), w / 2 + 1):
				_dot(q + Vector2i(dx, dy), c)

func _circle(p: Vector2, r: float, c: Color, fill := false) -> void:
	var n := int(TAU * r * PPM) + 8
	for i in n:
		var a := TAU * i / n
		_dot(_px(p + Vector2(cos(a), sin(a)) * r), c)
	if fill:
		for k in range(1, int(r * PPM)):
			for i in n:
				var a := TAU * i / n
				_dot(_px(p + Vector2(cos(a), sin(a)) * (r * k / (r * PPM))), c)

func _rect(r: Rect2, c: Color, fill := false) -> void:
	if fill:
		var x := r.position.x
		while x <= r.end.x:
			_line(Vector2(x, r.position.y), Vector2(x, r.end.y), c)
			x += 1.0 / PPM
	_line(r.position, Vector2(r.end.x, r.position.y), c, 2)
	_line(Vector2(r.end.x, r.position.y), r.end, c, 2)
	_line(r.end, Vector2(r.position.x, r.end.y), c, 2)
	_line(Vector2(r.position.x, r.end.y), r.position, c, 2)

func _draw_all(spread: float) -> void:
	img.fill(Color(0.16, 0.22, 0.16))
	_rect(Rect2(MIN, MAX - MIN), Color(0.5, 0.5, 0.5))
	for id in MapLayout.all_yards():
		var col := Color(0.2, 0.45, 0.2) if MapLayout.yard_tier(id) >= 4 else Color(0.2, 0.3, 0.5)
		_rect(MapLayout.yard_rect(id), col, true)
	for lane in MapLayout.lanes_for_tier(4):
		var pts: Array = MapLayout.lane_path(lane)
		for i in range(1, pts.size()):
			_line(pts[i - 1], pts[i], Color(0.45, 0.32, 0.18), int(spread * 2.0 * PPM))
		_rect(MapLayout.zone_rect(lane), Color(0.9, 0.2, 0.2))
		var f := MapLayout.fence_spot(lane)
		_circle(f, 0.5, Color(1, 0.6, 0.1), true)
	_rect(Rect2(-4, -4, 8, 8), Color(0.6, 0.6, 0.6), true)
	_rect(Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE), Color(0.7, 0.7, 0.7), true)
	_rect(Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE), Color(0.7, 0.7, 0.9), true)
	for id in MapLayout.ALL_SPOT_IDS:
		var t4 := MapLayout.spot_tier(id) >= 4
		var col := Color(1, 0.9, 0.1) if t4 else Color(1, 1, 1)
		if MapLayout.spot_kind(id) == "tower":
			_circle(MapLayout.spot_position(id), MapLayout.TOWER_VISUAL_RADIUS, col, true)
		_circle(MapLayout.spot_position(id), MapLayout.BUILD_RADIUS, col)
		for p in MapLayout.BRANCH_PADS[id]:
			_circle(p, MapLayout.BRANCH_PAD_RADIUS, Color(1, 0.9, 0.1) if t4 else Color(0.2, 0.9, 0.9))
	for t in MapLayout.TIER_SIGNS:
		_circle(MapLayout.tier_sign(t), MapLayout.STATION_RADIUS, Color(1, 0.2, 0.9) if t == 4 else Color(0.7, 0.4, 0.8), true)
	for q in MapLayout.queue_slots(3):
		_circle(q, 0.3, Color(0.9, 0.9, 0.5), true)
	_line(MapLayout.TRAVELER_ENTER, MapLayout.queue_slots(3)[8], Color(0.8, 0.8, 0.4))
	_line(MapLayout.SERVICE_POINT, MapLayout.traveler_exit(3), Color(0.8, 0.8, 0.4))
	_circle(MapLayout.HOME, 0.4, Color(1, 1, 1), true)
	# the HOME camera's 9:16 ground view
	var ui = root.get_node("Balance").ui
	var xf := CameraMath.camera_transform(CameraMath.focus_for(MapLayout.HOME), ui)
	var proj := CameraMath.projection(ui, 720.0 / 1280.0)
	var z := MIN.y
	while z <= MAX.y:
		var lo := INF
		var hi := -INF
		var x := MIN.x
		while x <= MAX.x:
			if CameraMath.on_screen(MapLayout.to3(Vector2(x, z), 0.0), xf, proj):
				lo = minf(lo, x)
				hi = maxf(hi, x)
			x += 0.1
		if lo < INF:
			_dot(_px(Vector2(lo, z)), Color.WHITE)
			_dot(_px(Vector2(hi, z)), Color.WHITE)
			_dot(_px(Vector2(lo, z)) + Vector2i(1, 0), Color.WHITE)
			_dot(_px(Vector2(hi, z)) + Vector2i(1, 0), Color.WHITE)
		z += 0.05

func _initialize() -> void:
	var out := "docs/review/media/e8/backlot"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var spread: float = root.get_node("Balance").data.enemy.lateral_spread
	var dir := ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(dir)
	origin = MIN
	img = Image.create(int((MAX.x - MIN.x) * PPM) + 1, int((MAX.y - MIN.y) * PPM) + 1, false, Image.FORMAT_RGB8)
	_draw_all(spread)
	img.save_png(dir.path_join("layout_t4.png"))
	# the south-east quarter, 2x: the back lot and HOME
	var crop := Rect2i(_px(Vector2(-12, -8)), Vector2i(int(26 * PPM), int(22 * PPM)))
	var part := img.get_region(crop)
	part.resize(part.get_width() * 2, part.get_height() * 2, Image.INTERPOLATE_NEAREST)
	part.save_png(dir.path_join("layout_t4_home.png"))
	print("wrote ", dir)
	quit(0)
