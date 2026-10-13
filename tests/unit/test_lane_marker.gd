extends GutTest
## E6 Task 10 (spec 5.1, D-282.5, D-289): the lasting lane-character marker and its two icons. With the retune flag on, at tier 3
## each lane entrance shows a badge beside the count row: the siege icon on the siege lane, the hare icon on the hare lane,
## nothing on the two neutral lanes, by day and by night, never hidden under the HUD's top bar. Every test names the wrong
## implementation it catches. The build's top tier is 2, so each test appends the tier-3 cost entry (Balance.reset() drops it).

const ASPECTS := [9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0]
const ASPECT_NAMES := ["9:21", "9:16", "16:9"]
## Hand-written from LaneCharacter.for_run (the draw is pinned forever): seed -> [siege lane, hare lane].
const CHARACTERS := {1: ["east", "west"], 3: ["sw", "west"], 4: ["west", "north"], 7: ["north", "sw"], 14: ["north", "east"], 18: ["west", "east"],
	2: ["east", "north"], 9: ["north", "west"], 12: ["sw", "north"]}
## The seeds the placement tests cover: every lane as siege and as hare (14 and 18 put the hare on the east lane), and the north badge on both
## sides: 9 = north siege + west hare (mirrored to +4.0), 4 = north hare + west siege (+4.0), 2 and 12 = north hare + east / sw siege (-4.0).
const PLACEMENT_SEEDS := [1, 3, 4, 7, 14, 18, 2, 9, 12]
const LANES := ["west", "north", "east", "sw"]

var main: Main

func before_each() -> void:
	Balance.reset()
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)
	SafeArea.override_for_tests = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

func after_each() -> void:
	SafeArea.override_for_tests = {}
	Balance.reset()
	GameState.new_game(1)

## A running game on `seed`, day, the hero under test control, at `tier` with the flag as given.
func _start(seed: int, tier := 3, flag := true) -> void:
	Balance.data.tiers.retune_enabled = flag
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(seed)
	main.phase_controller.debug_skip_to_day()
	await get_tree().physics_frame
	if tier > 1:
		GameState.debug_set_tier(tier, 5)
	await get_tree().physics_frame

func _marker(lane: String) -> TelegraphMarker:
	return main.world.telegraph_markers[lane]

## {lane: icon kind} of every badge the run has (its lane is not neutral). The cover rule may hide one for a moment: tests read is_visible_in_tree().
func _badges() -> Dictionary:
	var out := {}
	for lane in main.world.telegraph_markers:
		var b: LaneCharacterMarker = _marker(lane).badge
		if b != null and b.shown_kind() != &"":
			out[lane] = b.shown_kind()
	return out

## True when the badge's OWN rule says something covers it from the viewport's camera and the hero node now.
func _covered_now(b: LaneCharacterMarker) -> bool:
	var cam := b.get_viewport().get_camera_3d()
	return b.covers(cam.global_transform, func(w: Vector3) -> Vector2:
		return Vector2(INF, INF) if cam.is_position_behind(w) else cam.unproject_position(w), main.hero.global_position, b.get_viewport().get_visible_rect())

## Puts the hero at `f`, snaps the camera and waits for the cover timer (period 15 frames at 4 Hz, lane phase up to 0.75 of it): 30 frames.
func _stand_at(f: Vector2) -> void:
	main.hero.teleport(f)
	main.camera_rig.snap()
	for i in 30:
		await get_tree().physics_frame

## Names of every LaneCharacterMarker in the world that is NOT the `badge` of the current marker of its lane (an orphan: its marker was
## freed or rebuilt and the badge stayed behind). Call after a process_frame so queued frees have happened.
func _orphans() -> Array:
	var out := []
	for c in main.world.get_children():
		if c is LaneCharacterMarker:
			var mk: TelegraphMarker = main.world.telegraph_markers.get(c.lane_id)
			if mk == null or mk.badge != c:
				out.append(String(c.name))
	return out

func _expect(seed: int) -> Dictionary:
	var c: Array = CHARACTERS[seed]
	return {c[0]: &"siege", c[1]: &"hare"}

# --- shown only at tier 3 with the flag on ------------------------------------------------------------------------------

func test_the_pinned_characters_are_the_seeds_we_name() -> void:
	for s in CHARACTERS:
		assert_eq(LaneCharacter.for_run(s), {"siege": CHARACTERS[s][0], "hare": CHARACTERS[s][1]}, "seed %d" % s)

func test_flag_off_at_tier_3_shows_no_badge_and_makes_no_node() -> void:
	await _start(1, 3, false)
	assert_eq(GameState.tier, 3)
	assert_eq(GameState.lane_character(), {})
	assert_eq(_badges(), {}, "a badge shown with the flag off")
	for lane in LANES:
		assert_null(_marker(lane).badge, "%s: no node is made with the flag off" % lane)

func test_flag_on_at_tiers_1_and_2_shows_no_badge() -> void:
	await _start(1, 1, true)
	assert_eq(_badges(), {}, "tier 1")
	GameState.debug_set_tier(2, 5)
	await get_tree().physics_frame
	assert_eq(_badges(), {}, "tier 2: a badge drawn before the lane character exists")

func test_flag_on_at_tier_3_shows_exactly_two_badges_on_the_right_lanes_for_seeds_covering_every_lane() -> void:
	for s in PLACEMENT_SEEDS:
		await _start(s)
		var badges := _badges()
		assert_eq(badges, _expect(s), "seed %d: siege %s hare %s" % [s, CHARACTERS[s][0], CHARACTERS[s][1]])
		assert_eq(badges.size(), 2, "seed %d: exactly two" % s)
		for lane in LANES:
			if not badges.has(lane):
				assert_true(_marker(lane).badge == null or not _marker(lane).badge.visible, "seed %d: the neutral lane %s shows nothing" % [s, lane])
		main.queue_free()
		await get_tree().process_frame

func test_the_badge_shows_by_day_and_by_night() -> void:
	await _start(3)
	assert_eq(_badges(), _expect(3), "day")
	for lane in _badges():
		await _stand_at(_zone_focus(lane))
		assert_true(_marker(lane).badge.is_visible_in_tree(), "day: the %s badge is drawn from its own zone" % lane)
	main.phase_controller.debug_skip_to_night()
	await get_tree().physics_frame
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_eq(_badges(), _expect(3), "night: the count row hides, the badge does not")
	for lane in LANES:
		assert_false(_marker(lane).visible, "the flag of %s hides by night (the badge is not its child)" % lane)
	for lane in _badges():
		await _stand_at(_zone_focus(lane))
		assert_true(_marker(lane).badge.is_visible_in_tree(), "night: the %s badge is drawn from its own zone" % lane)
	main.phase_controller.debug_skip_to_day()
	await get_tree().physics_frame
	assert_eq(_badges(), _expect(3), "day again")

func test_a_new_game_with_another_seed_moves_the_badges_to_that_runs_lanes() -> void:
	await _start(1)
	assert_eq(_badges(), _expect(1))
	GameState.new_game(7)  # tier 1 again: nothing shows
	await get_tree().physics_frame
	assert_eq(_badges(), {}, "a fresh run is at tier 1")
	GameState.debug_set_tier(3, 5)
	await get_tree().physics_frame
	assert_eq(_badges(), _expect(7), "seed 7: siege north, hare sw")
	GameState.new_game(4)
	GameState.debug_set_tier(3, 5)
	await get_tree().physics_frame
	assert_eq(_badges(), _expect(4), "seed 4: siege west, hare north")
	await get_tree().process_frame
	assert_eq(_orphans(), [], "no badge outlives its marker (the sw badge of the tier-3 run before is gone with its marker)")
	var n := 0
	for c in main.world.get_children():
		if c is LaneCharacterMarker and c.shown_kind() != &"":
			n += 1
	assert_eq(n, 2, "exactly the two badges of this run show (a lane that turned neutral keeps a hidden node)")

## Mutation: TelegraphMarker._exit_tree does not free the badge: the sw badge stays when the tier drops and its marker is removed.
func test_no_badge_is_orphaned_after_a_tier_change_that_rebuilds_markers_and_after_a_load() -> void:
	await _start(3)  # siege sw, hare west
	assert_eq(_badges(), _expect(3))
	assert_not_null(_marker("sw").badge)
	GameState.debug_set_tier(2, 5)  # the sw lane and its marker go
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(main.world.telegraph_markers.has("sw"), "the sw marker is gone at tier 2")
	assert_eq(_orphans(), [], "tier change: the sw badge went with its marker")
	GameState.debug_set_tier(3, 5)  # rebuilt
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_eq(_badges(), _expect(3))
	assert_eq(_orphans(), [], "tier change back up: one badge per marker")
	var snap := GameState.to_dict()
	GameState.new_game(1)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_eq(_orphans(), [], "a fresh tier-1 run")
	GameState.from_dict(snap)
	EventBus.state_restored.emit()
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_eq(_badges(), _expect(3))
	assert_eq(_orphans(), [], "after a load")

func test_after_a_save_and_load_at_tier_3_the_badges_are_right() -> void:
	await _start(3)
	var snap := GameState.to_dict()
	GameState.new_game(1)  # another run, tier 1
	await get_tree().physics_frame
	assert_eq(_badges(), {})
	GameState.from_dict(snap)
	EventBus.state_restored.emit()
	await get_tree().physics_frame
	assert_eq(GameState.run_seed, 3)
	assert_eq(_badges(), _expect(3), "the restored run's lanes")

func test_the_badge_is_visual_only_and_does_nothing_per_frame() -> void:
	await _start(3)
	var before := GameState.to_dict()
	_marker("sw").refresh()
	await get_tree().physics_frame
	assert_eq(GameState.to_dict(), before, "no state moved")
	var src := FileAccess.get_file_as_string("res://world/lanes/lane_character_marker.gd")
	assert_false("func _process" in src or "func _physics_process" in src, "no per-frame work")
	for dir in ["res://actors", "res://autoload", "res://core", "res://components", "res://balance"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				assert_false("LaneCharacterMarker" in FileAccess.get_file_as_string(dir + "/" + f), "%s does not read the badge" % f)

# --- visibility ---------------------------------------------------------------------------------------------------------

class View:
	var xf: Transform3D
	var proj: Projection
	var aspect: float
	func _init(focus: Vector2, p_aspect: float) -> void:
		xf = CameraMath.camera_transform(CameraMath.focus_for(focus), Balance.ui)
		proj = CameraMath.projection(Balance.ui, p_aspect)
		aspect = p_aspect
	func half_h() -> float:
		return 0.5 * maxf(1280.0, 720.0 / aspect)
	func half_w() -> float:
		return 0.5 * (720.0 if aspect < 720.0 / 1280.0 else 1280.0 * aspect)
	func pt(w: Vector3) -> Vector2:
		var n := CameraMath.to_ndc(w, xf, proj)
		return Vector2(n.x * half_w(), -n.y * half_h())
	func quad(c: Vector3, sz: Vector2) -> Rect2:
		return bounds([c + xf.basis.x * sz.x * 0.5 + xf.basis.y * sz.y * 0.5, c - xf.basis.x * sz.x * 0.5 + xf.basis.y * sz.y * 0.5,
			c + xf.basis.x * sz.x * 0.5 - xf.basis.y * sz.y * 0.5, c - xf.basis.x * sz.x * 0.5 - xf.basis.y * sz.y * 0.5])
	func box(b: AABB) -> Rect2:
		var pts: Array = []
		for k in 8:
			pts.append(b.position + Vector3(b.size.x * (k & 1), b.size.y * ((k >> 1) & 1), b.size.z * ((k >> 2) & 1)))
		return bounds(pts)
	func bounds(pts: Array) -> Rect2:
		var r := Rect2(pt(pts[0]), Vector2.ZERO)
		for q in pts:
			r = r.expand(pt(q))
		return r
	func screen() -> Rect2:
		return Rect2(-half_w(), -half_h(), half_w() * 2.0, half_h() * 2.0)
	## True when the whole of `r` lies on screen.
	func contains(r: Rect2) -> bool:
		return screen().encloses(r)

## The rect of the badge's drawn mesh (its own bounds times the node's scale), or null when the badge shows nothing.
func _badge_rect(lane: String, v: View) -> Variant:
	var b: LaneCharacterMarker = _marker(lane).badge
	if b == null or b.shown_kind() == &"":
		return null
	var bb := b.icon.mesh.get_aabb()
	var c := b.icon.global_position + v.xf.basis.x * (bb.get_center().x * b.icon.scale.x) + v.xf.basis.y * (bb.get_center().y * b.icon.scale.y)
	return v.quad(c, Vector2(bb.size.x, bb.size.y) * b.icon.scale.x)

func _zone_focus(lane: String) -> Vector2:
	return MapLayout.zone_rect(lane).get_center()

## The HUD's top bar the way the count row's rule reads it: the top edge (base px from the top) is under hud_top_bar_px.
func _under_bar(r: Rect2, v: View) -> bool:
	return r.position.y + v.half_h() < Balance.ui.hud_top_bar_px

func test_from_each_lanes_attack_zone_its_badge_is_fully_on_screen_and_clear_of_the_hud_bar() -> void:
	var worst_top := INF
	for s in PLACEMENT_SEEDS:
		await _start(s)
		for aspect_i in ASPECTS.size():
			for lane in _badges():
				var v := View.new(_zone_focus(lane), ASPECTS[aspect_i])
				var r: Rect2 = _badge_rect(lane, v)
				assert_true(v.contains(r), "seed %d %s at %s: badge %s is fully on screen (%s)" % [s, lane, ASPECT_NAMES[aspect_i], r, v.screen()])
				assert_false(_under_bar(r, v), "seed %d %s at %s: badge top %.0f px is under the HUD bar (%.0f)" % [s, lane, ASPECT_NAMES[aspect_i], r.position.y + v.half_h(), Balance.ui.hud_top_bar_px])
				worst_top = minf(worst_top, r.position.y + v.half_h())
		main.queue_free()
		await get_tree().process_frame
	gut.p("lowest badge top edge from a zone: %.1f px from the top (the bar is %.0f)" % [worst_top, Balance.ui.hud_top_bar_px])

func test_from_home_the_badge_visibility_per_lane_is_reported_honestly() -> void:
	var lines: Array = []
	for s in PLACEMENT_SEEDS:
		await _start(s)
		for lane in _badges():
			var cells: Array = []
			for aspect_i in ASPECTS.size():
				var v := View.new(MapLayout.HOME, ASPECTS[aspect_i])
				var r: Rect2 = _badge_rect(lane, v)
				var state := "on screen"
				if not v.screen().intersects(r):
					state = "off screen"
				elif not v.contains(r):
					state = "partly off"
				elif _under_bar(r, v):
					state = "under bar"
				cells.append("%s %s (top %.0f, x %.0f..%.0f)" % [ASPECT_NAMES[aspect_i], state, r.position.y + v.half_h(), r.position.x, r.end.x])
			lines.append("seed %d %-5s %-5s | %s" % [s, lane, _badges()[lane], " | ".join(cells)])
		main.queue_free()
		await get_tree().process_frame
	gut.p("HOME visibility of each lane's badge (computed from the real nodes):")
	for l in lines:
		gut.p("  " + l)
	assert_eq(lines.size(), 2 * PLACEMENT_SEEDS.size(), "two badges for each seed")

## Real viewport: from HOME at 9:16 the three northern count rows hide under the bar; the badge must stay (a badge that copies the
## row's HUD rule fails here on the north lane, seed 7).
func test_the_badge_does_not_hide_with_the_count_row_under_the_hud_bar() -> void:
	SafeArea.override_for_tests = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	Balance.data.tiers.retune_enabled = true
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	add_child_autofree(vp)
	main = Main.create()
	vp.add_child(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(7)  # siege north, hare sw
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_tier(3, 5)
	GameState.lane_plan = [{"main": "north", "side": "east", "main_count": 5, "side_count": 3, "hp_mult": 1.0, "fast_main": 1, "fast_side": 0,
		"boss": false, "brute_main": 1, "brute_side": 0}, {"main": "west", "side": "sw", "main_count": 4, "side_count": 2, "hp_mult": 1.0,
		"fast_main": 0, "fast_side": 0, "boss": false, "brute_main": 0, "brute_side": 0}]
	for m in main.world.telegraph_markers.values():
		m.refresh()
	main.hero.teleport(MapLayout.HOME)
	main.camera_rig.snap()
	for i in 30:
		await get_tree().physics_frame  # the last cover evaluation was before the teleport
	assert_false(_marker("north").row.visible, "the north count row is hidden under the bar from HOME at 9:16")
	assert_false(_marker("east").row.visible, "so is the east row")
	assert_eq(_badges(), {"north": &"siege", "sw": &"hare"}, "but both badges stay")
	var nb: LaneCharacterMarker = _marker("north").badge
	var covered := _covered_now(nb)
	assert_eq(nb.is_visible_in_tree(), not covered, "the badge is drawn exactly when its own rule says nothing covers it")
	assert_false(covered, "from HOME at 9:16 the hero stands at the screen centre and the badge is up under the bar: no hero, label or pip covers it")
	assert_true(nb.is_visible_in_tree(), "so it IS drawn while its count row is hidden under the bar")

# --- no overlap ---------------------------------------------------------------------------------------------------------

func _wave(m: String, mc: int, fm: int, s: String, sc: int, fs: int, bm := 0, bs := 0) -> Dictionary:
	return {"main": m, "side": s, "main_count": mc, "side_count": sc, "hp_mult": 1.0,
		"fast_main": fm, "fast_side": fs, "boss": false, "brute_main": bm, "brute_side": bs}

## Every lane carries Boar, hare and brute (three pairs) and the boss is on `boss_lane`: the widest row each lane can show.
func _plan_boss_on(boss_lane: String) -> Array:
	var w1 := _wave("west", 6, 2, "east", 5, 1, 1, 1)
	var w2 := _wave("north", 6, 2, "sw", 5, 1, 1, 1)
	var w3 := _wave(boss_lane, 6, 2, "north" if boss_lane != "north" else "west", 5, 1, 1, 1)
	w3.boss = true
	return [w1, w2, w3]

func _set_plan(plan: Array) -> void:
	GameState.lane_plan = plan
	for m in main.world.telegraph_markers.values():
		m.refresh()

## The rect of everything a marker's count row shows now (the geometry test_telegraph.gd measures).
func _row_rect(mk: TelegraphMarker, v: View) -> Variant:
	var rect := Rect2()
	var first := true
	for kind in mk.items:
		var it: Dictionary = mk.items[kind]
		if not (it.icon as Node3D).visible:
			continue
		var ic := it.icon as MeshInstance3D
		var bb := ic.mesh.get_aabb()
		var rs: Array = [v.quad(ic.global_position + v.xf.basis.x * (bb.get_center().x * ic.scale.x) + v.xf.basis.y * (bb.get_center().y * ic.scale.y), Vector2(bb.size.x, bb.size.y) * ic.scale.x)]
		if it.num != null:
			var l := it.num as Label3D
			var lb := l.get_aabb()
			rs.append(v.quad(l.global_position + v.xf.basis.x * lb.get_center().x, Vector2(lb.size.x, 0.75 * float(l.font_size) * l.pixel_size)))
		for r in rs:
			rect = r if first else rect.merge(r)
			first = false
	return null if first else rect

func _label_rect(l: Label3D, v: View) -> Rect2:
	var b := BranchPad.text_box(l)
	var c := l.global_position
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
		c += v.xf.basis.x * b.x * 0.5
	return v.quad(c, b)

## Cost-label and level-pip rects of every spot at every level (unbuilt and built heights).
func _spot_rects(v: View) -> Array:
	var out: Array = []
	for id in main.world.build_spots:
		var sp: BuildSpot = main.world.build_spots[id]
		for lvl in range(0, Balance.data.build.max_level + 1):
			out.append([id + " label L%d" % lvl, v.quad(sp.global_position + Vector3(0, sp._label_y(lvl), 0), Vector2(1.2, 0.6))])
			if lvl >= 1:
				out.append([id + " pips L%d" % lvl, v.quad(sp.global_position + Vector3(0, sp._pip_y(lvl), 0), Vector2(1.1, 0.4))])
	return out

func _foci() -> Array:
	var out: Array = [MapLayout.HOME, MapLayout.SIGN]
	for id in MapLayout.STATION_STAND:
		out.append(MapLayout.STATION_STAND[id])
	for lane in MapLayout.lanes_for_tier(3):
		out.append(MapLayout.zone_rect(lane).get_center())
	for id in MapLayout.spots_for_tier(3):
		out.append(MapLayout.spot_position(id))
	var pads := MapLayout.branch_pads(TierEffects.retune_on(Balance.data.tiers))
	for id in pads:
		for pad in pads[id]:
			out.append(pad)
	return out

## The count of rects (count rows of every lane, the tier sign, cost labels and pips, the hero) the badge of each lane overlaps while on
## screen, over `foci`. Returns {overlaps: [text], gap: smallest base-px gap to a count row, views: n}.
func _category(what: String) -> String:
	if what == "tier sign" or what == "hero":
		return what
	if what.begins_with("pad glyph"):
		return "pad"
	if what.contains("pips"):
		return "pips"
	if what.begins_with("fence"):
		return "fence label"
	return "tower label"

## "category: count" table text of an overlaps list, every category listed (0 included).
func _table(overlaps: Array) -> Dictionary:
	var by := {"count row": 0, "tier sign": 0, "tower label": 0, "fence label": 0, "pips": 0, "hero": 0, "pad": 0}
	for t in overlaps:
		by[t.cat] += 1
	return by

func _print_table(title: String, views: int, overlaps: Array) -> Dictionary:
	var by := _table(overlaps)
	gut.p("%s: %d badge views, %d overlaps" % [title, views, overlaps.size()])
	for k in by:
		gut.p("    %-12s %d" % [k, by[k]])
	return by

func _overlaps(foci: Array, own_zone_only := false) -> Dictionary:
	var out := []
	var gap := INF
	var views := 0
	for s in PLACEMENT_SEEDS:
		await _start(s)
		for boss in LANES:
			_set_plan(_plan_boss_on(boss))
			for aspect_i in ASPECTS.size():
				for f in foci:
					var v := View.new(f, ASPECTS[aspect_i])
					var others := _spot_rects(v)
					var ts: TierSign = main.world.tier_sign
					if ts != null and ts.label.visible:
						others.append(["tier sign", _label_rect(ts.label, v)])
					others.append(["hero", v.box(AABB(Vector3(f.x - 0.4, 0.0, f.y - 0.05), Vector3(0.8, 1.8, 0.1)))])
					for pid in main.world.branch_pads:
						for pad in main.world.branch_pads[pid]:
							if pad.icon != null:
								others.append(["pad glyph %s" % pad.name, v.quad(pad.icon.global_position, BranchPad.glyph_box(pad.icon))])
					for lane in _badges():
						if own_zone_only and f != _zone_focus(lane):
							continue
						var r: Rect2 = _badge_rect(lane, v)
						if not v.screen().intersects(r):
							continue  # off screen from this focus: nothing to clear
						views += 1
						for lane2 in LANES:
							var rr: Variant = _row_rect(_marker(lane2), v)
							if rr != null:
								var row: Rect2 = rr
								if r.intersects(row):
									out.append({"cat": "count row", "text": "seed %d boss %s %s focus %s: the %s badge %s overlaps the %s row %s" % [s, boss, ASPECT_NAMES[aspect_i], f, lane, r, lane2, row]})
								gap = minf(gap, maxf(maxf(row.position.x - r.end.x, r.position.x - row.end.x), maxf(row.position.y - r.end.y, r.position.y - row.end.y)))
						for e in others:
							if r.intersects(e[1]):
								out.append({"cat": _category(e[0]), "text": "seed %d boss %s %s focus %s: the %s badge %s overlaps %s %s" % [s, boss, ASPECT_NAMES[aspect_i], f, lane, r, e[0], e[1]]})
		main.queue_free()
		await get_tree().process_frame
	return {"overlaps": out, "gap": gap, "views": views}

## D-292.3: from ITS OWN lane's attack zone (where the player walks toward the lane and chooses) the badge meets no count row, tier sign, spot
## label, pip or hero body. Pads are excluded (a later task moves them and owns that test). The badge seen from the OTHER lanes' zones and every
## other focus is in the report-only table below.
func test_the_badge_clears_the_count_row_the_tier_sign_the_spot_labels_and_the_hero_from_each_lanes_zone() -> void:
	var foci: Array = []
	for lane in MapLayout.lanes_for_tier(3):
		foci.append(_zone_focus(lane))
	var res: Dictionary = await _overlaps(foci, true)
	for t in res.overlaps:
		if t.cat != "pad":  # the pads move in Task 14: their overlaps are in the table, not asserted
			fail_test(t.text)
	_print_table("zone views", res.views, res.overlaps)
	assert_gt(res.views, 0)
	gut.p("%d badge views from the four attack zones; smallest gap from a badge to a count row: %.1f base px" % [res.views, res.gap])

## From every camera focus the game reaches (HOME, the sign, the station stand points, the zones, the spots and the pads) the badge clears the
## count rows and the tier sign (the table of the other categories is printed; the cover rule's own assertion is below).
func test_from_every_focus_the_badge_clears_the_count_rows_and_the_tier_sign() -> void:
	var res: Dictionary = await _overlaps(_foci())
	var by := _print_table("all %d foci" % _foci().size(), res.views, res.overlaps)
	var shown := 0
	for t in res.overlaps:
		if (t.cat == "count row" or t.cat == "tier sign") and shown < 4:
			gut.p("  " + t.text)
			shown += 1
	assert_eq(by["count row"] + by["tier sign"], 0, "from every focus the badge clears the count rows and the tier sign")
	assert_gt(res.views, 0)

# --- an extra hare group still shows its count row ------------------------------------------------------------------------

## Scans real plans for a seed and a tier-3 day on which the hare lane is neither main nor side of any wave and an EXTRA group
## feeds it: returns {seed, day, plan, lane, hares}.
func _extra_hare_only_case() -> Dictionary:
	for s in range(1, 60):
		var ch := LaneCharacter.for_run(s)
		for day in range(5, 30):
			var raw := LanePlanner.plan(s, day, Balance.data.wave, 3, day - 4, Balance.data.tiers)
			var plan := LaneCharacter.apply(raw, ch, Balance.data.tiers)
			var hare := String(ch.hare)
			var extras := 0
			var direct := false
			for w in plan:
				if String(w.main) == hare or String(w.side) == hare:
					direct = true
				for e in w.get("extra", []):
					if String(e.lane) == hare:
						extras += int(e.fast)
			if not direct and extras > 0:
				return {"seed": s, "day": day, "plan": plan, "lane": hare, "hares": extras}
	return {}

func test_a_lane_fed_only_by_an_extra_hare_group_shows_its_count_row_by_day() -> void:
	var c := _extra_hare_only_case()
	assert_false(c.is_empty(), "a seed and day with an extra-only hare lane exists")
	if c.is_empty():
		return
	gut.p("extra-only hare lane: seed %d day %d lane %s hares %d" % [c.seed, c.day, c.lane, c.hares])
	await _start(c.seed)
	_set_plan(c.plan)
	var mk := _marker(c.lane)
	assert_eq(mk.shown(), {&"hare": c.hares}, "the row counts the extra group's hares (written out from the plan's extra entries)")
	assert_true(mk.visible, "the lane's flag shows by day")
	assert_true(mk.row.is_visible_in_tree())
	assert_eq(_badges()[c.lane], &"hare", "and its badge is the hare icon")

# --- shape ----------------------------------------------------------------------------------------------------------------

func _mask(img: Image) -> Array:
	var out: Array = []
	for y in img.get_height():
		for x in img.get_width():
			out.append(img.get_pixel(x, y).a > 0.5)
	return out

## Share of the opaque union that differs between two binary masks.
func _mask_diff(a: Image, b: Image) -> float:
	var ma := _mask(a)
	var mb := _mask(b)
	var union := 0
	var diff := 0
	for i in ma.size():
		if ma[i] or mb[i]:
			union += 1
			if ma[i] != mb[i]:
				diff += 1
	return float(diff) / float(maxi(union, 1))

## Grey level over a mid-grey ground: luminance by alpha, no hue.
func _grey(c: Color) -> float:
	return c.get_luminance() * c.a + 0.5 * (1.0 - c.a)

## Share of the opaque union whose GREY level differs by more than 0.12 between two images (a pixel with a hue-only difference
## has the same grey and does not count).
func _grey_diff(a: Image, b: Image) -> float:
	var union := 0
	var diff := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if ca.a > 0.5 or cb.a > 0.5:
				union += 1
				if absf(_grey(ca) - _grey(cb)) > 0.12:
					diff += 1
	return float(diff) / float(maxi(union, 1))

func test_the_two_icons_differ_by_silhouette_and_by_luminance_not_hue() -> void:
	var siege := LaneCharacterIcons.image(LaneCharacterIcons.SIEGE, 64)
	var hare := LaneCharacterIcons.image(LaneCharacterIcons.HARE, 64)
	var m := _mask_diff(siege, hare)
	var g := _grey_diff(siege, hare)
	gut.p("shape difference at 64 x 64: alpha masks %.1f%% of the opaque union, grey levels %.1f%%" % [m * 100.0, g * 100.0])
	assert_gte(m, 0.30, "silhouettes differ in at least 30% of the union (same silhouette, only recoloured, would be 0%)")
	assert_gte(g, 0.30, "and so do the grey levels")
	# the metrics can fail: an icon against itself, and against its own recolour, differ in 0 pixels of the mask
	assert_eq(_mask_diff(siege, siege), 0.0)
	var recoloured := siege.duplicate() as Image
	for y in 64:
		for x in 64:
			var c := recoloured.get_pixel(x, y)
			recoloured.set_pixel(x, y, Color(c.b, c.r, c.g, c.a))
	assert_eq(_mask_diff(siege, recoloured), 0.0, "a recolour keeps the silhouette: the mask metric ignores hue")

func test_the_icons_are_wide_and_tall_respectively_and_fit_their_unit_square() -> void:
	var sb := LaneCharacterIcons.mesh(LaneCharacterIcons.SIEGE).get_aabb().size
	var hb := LaneCharacterIcons.mesh(LaneCharacterIcons.HARE).get_aabb().size
	gut.p("siege %.2f x %.2f, hare %.2f x %.2f (w x h, glyph units)" % [sb.x, sb.y, hb.x, hb.y])
	assert_gt(sb.x / sb.y, 1.2, "the siege icon is wide and low")
	assert_lt(hb.x / hb.y, 0.9, "the hare icon is tall")
	for k in LaneCharacterIcons.KINDS:
		var bb := LaneCharacterIcons.mesh(k).get_aabb()
		assert_lte(bb.size.x, 1.0001, "%s fits 1 m wide" % k)
		assert_lte(bb.size.y, 1.0001, "%s fits 1 m high" % k)
		assert_eq(LaneCharacterIcons.mesh(k).surface_get_array_len(0), LaneCharacterIcons.expected_vertices(k), "%s: every layer triangulated" % k)
		for l in LaneCharacterIcons.layers(k):
			assert_false(String(l[1]).begins_with("gold") or String(l[1]).contains("white"), "%s: no gold and no white" % k)

func test_the_texture_form_is_the_same_picture_as_the_mesh_and_crisp_at_64() -> void:
	for k in LaneCharacterIcons.KINDS:
		var t := LaneCharacterIcons.texture(k)
		assert_eq(t.get_size(), Vector2(128, 128), "128 px stays crisp when shown at 64")
		var img := LaneCharacterIcons.image(k, 128)
		var opaque := 0
		for y in 128:
			for x in 128:
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		assert_gt(opaque, 128 * 128 / 8, "%s: the picture has body" % k)
		# a pixel and the glyph's own sample agree (centre of pixel (64, 64) is glyph point (0.0039, -0.0039))
		var p := Vector2((64.5) / 128.0 - 0.5, 0.5 - 64.5 / 128.0)
		assert_eq(img.get_pixel(64, 64), LaneCharacterIcons.sample(k, p), "%s: image and sample agree" % k)
		assert_same(LaneCharacterIcons.texture(k), t, "cached")

# --- warm-up ------------------------------------------------------------------------------------------------------------

func test_the_warmup_draws_both_icons_on_screen_at_three_aspects_within_the_grid() -> void:
	Balance.data.tiers.retune_enabled = true
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	var warmup := Warmup.new()
	main.add_child(warmup)
	warmup.run(main)  # no await: the temporary nodes are in the tree
	var found := {}
	var xf := main.camera_rig.camera.global_transform
	for c in warmup.get_children():
		if c is MeshInstance3D:
			for k in LaneCharacterIcons.KINDS:
				if c.mesh == LaneCharacterIcons.mesh(k) and c.material_override == LaneCharacterIcons.material():
					found[k] = c
	assert_eq(found.size(), 2, "both icon meshes with the billboard material are drawn")
	for k in found:
		var pos: Vector3 = (found[k] as Node3D).global_position
		for aspect in ASPECTS:
			assert_true(CameraMath.on_screen(pos, xf, CameraMath.projection(Balance.ui, aspect)), "%s is on screen at aspect %.2f" % [k, aspect])
	assert_true(warmup.built_count <= Warmup.CAPACITY, "%d nodes fit the %d-slot grid" % [warmup.built_count, Warmup.CAPACITY])
	assert_eq(warmup.placed.size(), warmup.built_count)
	await warmup.finished
	assert_eq(warmup.get_child_count(), 0)

func test_the_warmup_with_the_flag_off_draws_no_badge_icon() -> void:
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	assert_eq(Warmup.lane_character_visuals().size(), 0, "flag off: the warm-up is exactly today's")


# --- the safe-area inset (D: SafeArea may push the HUD bar down) ----------------------------------------------------------
## Real devices with a notch: a 9:19.5 phone (720 x 1560 base) with a top inset of 87 or 108 base px. No inset is asserted at 9:16: it is
## not a real notch device. The bar is the GAME's own TelegraphMarker.bar_px(viewport size) = inset + hud_top_bar_px.

func _inset_bar(inset: float, vp: Vector2) -> float:
	SafeArea.override_for_tests = {"top": inset, "bottom": 0.0, "left": 0.0, "right": 0.0}
	TelegraphMarker._bar_stamp = -1  # the cache would hold the last value for a second
	return TelegraphMarker.bar_px(vp)

func test_with_a_notch_inset_at_9_19_5_the_shown_badges_are_not_under_the_bar_from_each_zone() -> void:
	var vp := Vector2(720, 1560)
	var aspect := vp.x / vp.y
	var worst := {}
	for inset in [87.0, 108.0]:
		var bar := _inset_bar(inset, vp)
		assert_almost_eq(bar, inset + Balance.ui.hud_top_bar_px, 0.01, "the game's bar is inset + the HUD bar")
		for s in PLACEMENT_SEEDS:
			await _start(s)
			for lane in _badges():
				for focus_name in ["HOME", "zone"]:
					var f: Vector2 = MapLayout.HOME if focus_name == "HOME" else _zone_focus(lane)
					var v := View.new(f, aspect)
					var r: Rect2 = _badge_rect(lane, v)
					if not v.screen().intersects(r):
						continue  # off screen: not under the bar
					var top := r.position.y + v.half_h()
					worst[inset] = minf(worst.get(inset, INF), top) if focus_name == "zone" else worst.get(inset, INF)
					gut.p("inset %.0f bar %.0f seed %d %-5s %-4s top %.0f %s" % [inset, bar, s, lane, focus_name, top, "UNDER THE BAR" if top < bar else "clear"])
					if focus_name == "zone":  # HOME is informational (D-292.3: the badge need not be visible from HOME)
						assert_gte(top, bar, "inset %.0f seed %d %s zone: the badge's top %.0f is under the bar %.0f" % [inset, s, lane, top, bar])
			main.queue_free()
			await get_tree().process_frame

# --- the road: the drawn surface and the enemies' bodies --------------------------------------------------------------------

## The drawn road is LaneStrip.WIDTH wide (half 1.5 m); the kerb stones stand at 1.75 m from the centre line and are LaneStrip.STONE_RADIUS (0.4 m) big,
## so the drawn surface reaches 2.15 m (the test below measures the stones of every lane).
const SURFACE_HALF := LaneStrip.WIDTH * 0.5 + 0.25 + LaneStrip.STONE_RADIUS
## The enemies' volume: a body at the limit of the lateral spread. 0.975 m is the half-width of the broadest body, the brute (art/boar/boar_mesh.gd);
## 1.5 m high models the tall bodies the lane carries (the boss kinds are taller, but a boss walks the lane's centre line, spread 0).
const BODY_EXTRA := 0.975
const BODY_HEIGHT := 1.5
## The badge's rect, grown by this (base px), must still meet neither obstacle.
const CLEAR_PX := 4.0

## The projected rects of the lane's road: one oriented prism per 1 m path piece (a long diagonal's bounding box would cover the grass
## beside it), half-width `half` on the ground plane, up to `height` (0 = a flat quad on the ground).
func _road_rects(lane: String, v: View, half: float, height: float) -> Array:
	var path: Array = MapLayout.lane_path(lane)
	var out: Array = []
	for i in path.size() - 1:
		var a0: Vector2 = path[i]
		var b0: Vector2 = path[i + 1]
		var n := (b0 - a0).normalized().orthogonal() * half
		var pieces := maxi(1, ceili(a0.distance_to(b0) / 1.0))
		for k in pieces:
			var a := a0.lerp(b0, float(k) / float(pieces))
			var b := a0.lerp(b0, float(k + 1) / float(pieces))
			var pts: Array = []
			for p in [a + n, a - n, b + n, b - n]:
				pts.append(Vector3(p.x, 0.0, p.y))
				if height > 0.0:
					pts.append(Vector3(p.x, height, p.y))
			out.append(v.bounds(pts))
	return out

## Smallest separation (base px, negative = overlap) between `r` and any of `rects`.
func _gap(r: Rect2, rects: Array) -> float:
	var gap := INF
	for sr in rects:
		gap = minf(gap, maxf(maxf(sr.position.x - r.end.x, r.position.x - sr.end.x), maxf(sr.position.y - r.end.y, r.position.y - sr.end.y)))
	return gap

## Distance (m) from a ground point to the lane's centre line.
func _centre_distance(lane: String, p: Vector2) -> float:
	var path: Array = MapLayout.lane_path(lane)
	var best := INF
	for i in path.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1]).distance_to(p))
	return best

func test_the_kerb_stones_stay_inside_the_surface_quad() -> void:
	var worst := 0.0
	for lane in LANES:
		for xf in LaneStrip.edge_transforms(MapLayout.lane_path(lane)):
			worst = maxf(worst, _centre_distance(lane, Vector2(xf.origin.x, xf.origin.z)) + LaneStrip.STONE_RADIUS)
	gut.p("kerb stones: the outer reach (centre line to a stone's far edge, nearest lane path) is at most %.3f m; the surface quad's half-width is %.3f m" % [worst, SURFACE_HALF])
	assert_lte(worst, SURFACE_HALF + 0.001, "a stone sticks out of the surface quad")
	assert_gt(worst, 2.0, "stones were found")

## D-292.3: from its own lane's zone at 9:21, 9:16 and 16:9 every seed's badge, grown CLEAR_PX, meets neither the DRAWN road (surface + kerb, on the
## ground) nor the enemies' volume (spread + a brute's half-width, 1.5 m high) of ANY lane. Prints the smallest gaps.
func test_the_badge_clears_the_drawn_road_and_the_enemy_bodies_from_its_own_zone() -> void:
	var worst := {}  # "lane aspect" -> [surface gap, body gap]
	for s in PLACEMENT_SEEDS:
		await _start(s)
		for lane in _badges():
			var b: LaneCharacterMarker = _marker(lane).badge
			for aspect_i in ASPECTS.size():
				var v := View.new(_zone_focus(lane), ASPECTS[aspect_i])
				var r: Rect2 = _badge_rect(lane, v)
				var surf := INF
				var body := INF
				for other in LANES:
					surf = minf(surf, _gap(r, _road_rects(other, v, SURFACE_HALF, 0.0)))
					body = minf(body, _gap(r, _road_rects(other, v, Balance.data.enemy.lateral_spread + BODY_EXTRA, BODY_HEIGHT)))
				assert_gte(surf, CLEAR_PX, "seed %d %s %s (%.2f m from the centre line): the badge %s is %.1f px from the drawn road, needs %.0f" % [s, lane, ASPECT_NAMES[aspect_i], _centre_distance(lane, Vector2(b.global_position.x, b.global_position.z)), r, surf, CLEAR_PX])
				assert_gte(body, CLEAR_PX, "seed %d %s %s: the badge %s is %.1f px from the enemies' volume, needs %.0f" % [s, lane, ASPECT_NAMES[aspect_i], r, body, CLEAR_PX])
				var key := "%s %s" % [lane, ASPECT_NAMES[aspect_i]]
				var w: Array = worst.get(key, [INF, INF])
				worst[key] = [minf(w[0], surf), minf(w[1], body)]
		main.queue_free()
		await get_tree().process_frame
	gut.p("smallest gap (base px) from a badge, seen from its own zone, to the drawn road (surface + kerb) | to the enemies' volume:")
	for key in worst:
		gut.p("  %-9s %6.1f | %6.1f" % [key, worst[key][0], worst[key][1]])

## D-292.3: every badge, the south-west one too, stands BELOW its lane's count row (nearer the camera).
func test_every_badge_is_below_its_count_row() -> void:
	for s in PLACEMENT_SEEDS:
		await _start(s)
		for lane in _badges():
			var mk := _marker(lane)
			assert_gt(mk.badge.global_position.z, mk.row_anchor().z + 0.5, "seed %d %s: the badge (z %.2f) is toward the camera of its row (z %.2f)" % [s, lane, mk.badge.global_position.z, mk.row_anchor().z])
		main.queue_free()
		await get_tree().process_frame

func test_an_unknown_lane_is_not_placed_on_the_row_anchor() -> void:
	for lane in LANES:
		assert_ne(LaneCharacterMarker.place(lane, Vector3(1, 1, 1)), Vector3(1, 1, 1), "%s has an offset" % lane)
	var src := FileAccess.get_file_as_string("res://world/lanes/lane_character_marker.gd")
	assert_true("unknown lane" in src and "assert(offsets.has(lane)" in src, "an unknown lane asserts (a Dictionary.get default would put it on the anchor)")
	assert_false(", _align" in src or "_align := 0" in src, "the unused align parameter is gone")

# --- west + north ----------------------------------------------------------------------------------------------------------------

## Seed 4 is west + north (siege west, hare north), seed 14 is north + east, seed 7 north + sw: from the north zone at 9:16 the two badges are
## at least 300 base px apart, and the north badge goes to the side away from the other one.
func test_the_north_badge_keeps_away_from_the_other_badge_of_its_run() -> void:
	for case in [[4, "west", 1.0], [9, "west", 1.0], [14, "east", -1.0], [2, "east", -1.0], [7, "sw", -1.0], [12, "sw", -1.0]]:
		await _start(case[0])
		var v := View.new(_zone_focus("north"), ASPECTS[1])
		var rn: Rect2 = _badge_rect("north", v)
		var ro: Rect2 = _badge_rect(case[1], v)
		var apart := rn.get_center().distance_to(ro.get_center()) if v.screen().intersects(ro) else INF
		gut.p("seed %d north + %s: north badge x %.1f m, %.0f base px from the other badge (centres, from the north zone at 9:16)" % [case[0], case[1], _marker("north").badge.global_position.x, apart])
		assert_gte(apart, 300.0, "seed %d: the north badge is %.0f px from the %s badge" % [case[0], apart, case[1]])
		assert_gt(_marker("north").badge.global_position.x * case[2], 0.0, "seed %d: the north badge sits on the side away from the %s one" % [case[0], case[1]])
		main.queue_free()
		await get_tree().process_frame

# --- the cover rule (E6 fix round 3) -------------------------------------------------------------------------------------------

## Puts every standing spot and both stations at `level` (what the game would show on that day).
func _set_levels(level: int) -> void:
	for id in GameState.buildings:
		GameState.buildings[id].level = level
		GameState.buildings[id].paid = 0
		EventBus.building_changed.emit(StringName(id), level, 0)
	for sid in StationEffects.IDS:
		GameState.debug_set_station_level(sid, mini(level, Balance.data.stations.max_level))

## The things a badge must not cover, as the test models them from the game's own numbers (not from the badge's code): the hero's body at
## `f`, each visible spot's cost / MAX label at the spot's own label height, its pips as the LevelPips row lays them out (the ones that show), every visible
## station label.
func _cover_obstacles(v: View, f: Vector2) -> Array:
	var out: Array = [["hero", v.box(AABB(Vector3(f.x - 0.4, 0.0, f.y - 0.05), Vector3(0.8, 1.8, 0.1)))]]
	var max_level: int = Balance.data.build.max_level
	for id in main.world.build_spots:
		var sp: BuildSpot = main.world.build_spots[id]
		if sp.label.is_visible_in_tree() and sp.label.text != "":
			out.append([id + " label", v.quad(sp.global_position + Vector3(0, sp._label_y(sp.level), 0), BranchPad.text_box(sp.label))])
		for i in sp.level:
			if not (sp._pips[i] as Node3D).is_visible_in_tree():
				continue  # E6 round 7: a star hides while one of its spot's own branch pads shows a cost; a hidden star is no obstacle (read from the real node, like the label above)
			out.append([id + " pip %d" % i, v.quad(sp.global_position + Vector3((i - (max_level - 1) * 0.5) * LevelPips.SPACING, sp._pip_y(sp.level), 0), Vector2.ONE * LevelStar.SIZE)])
	for n in get_tree().get_nodes_in_group(&"world_labels"):
		var l := n as Label3D
		if l == null or not l.is_visible_in_tree() or l.text == "":
			continue
		var p := l.get_parent()
		if p is UpgradePad or p is Counter or p is Freezer or p is GoldPile or p is CloseUpSign:
			out.append([String(p.name) + " label", _label_rect(l, v)])
		if p is UpgradePad:
			var up := p as UpgradePad
			for i in GameState.station_level(up.station_id):
				out.append([String(p.name) + " pip %d" % i, v.quad(up.global_position + Vector3((i - (Balance.data.stations.max_level - 1) * 0.5) * LevelPips.SPACING, UpgradePad.PIP_Y, 0), Vector2.ONE * LevelStar.SIZE)])
	return out

func _focus_class(f: Vector2, own: String) -> String:
	if f == _zone_focus(own):
		return "own zone"
	for lane in MapLayout.lanes_for_tier(3):
		if f == _zone_focus(lane):
			return "other zone"
	if f == MapLayout.HOME:
		return "HOME"
	if f == MapLayout.SIGN:
		return "sign"
	for id in MapLayout.STATION_STAND:
		if f == MapLayout.STATION_STAND[id]:
			return "station stand"
	for id in MapLayout.spots_for_tier(3):
		if f == MapLayout.spot_position(id):
			return "tower spot" if id.begins_with("tower") else "fence spot"
	return "pad"

## ZERO overlap wherever the badge is shown. Over every focus the game reaches (the four zones, HOME, the sign, the station stand points,
## the nine spots, the pads), three aspects, every seed and every level the spots and stations can stand at: after the cover rule has run
## once for that view (the rule needs no frames: `evaluate` is what the timer calls), the badge is hidden or its rect meets no hero body,
## spot label, pip or station label; and from its OWN lane's zone it is drawn. Prints how often each class of focus hides it.
func test_the_badge_is_hidden_or_clear_of_the_hero_the_labels_and_the_pips_from_every_focus_and_drawn_from_its_own_zone() -> void:
	var table := {}  # focus class -> [views, hidden]
	var matrix := {}  # "badge lane from zone of lane" -> [views, hidden]
	var foci := _foci()
	for s in PLACEMENT_SEEDS:
		await _start(s)
		for level in range(0, int(Balance.data.build.max_level) + 1):
			_set_levels(level)
			await get_tree().physics_frame
			for aspect_i in ASPECTS.size():
				for f in foci:
					var v := View.new(f, ASPECTS[aspect_i])
					var obstacles := _cover_obstacles(v, f)
					for lane in _badges():
						var b: LaneCharacterMarker = _marker(lane).badge
						var r: Rect2 = _badge_rect(lane, v)
						b.evaluate(v.xf, Callable(v, "pt"), Vector3(f.x, 0.0, f.y))
						var cls := _focus_class(f, lane)
						var row: Array = table.get(cls, [0, 0])
						row[0] += 1
						row[1] += 0 if b.visible else 1
						table[cls] = row
						for z in MapLayout.lanes_for_tier(3):
							if f == _zone_focus(z):
								var m: Array = matrix.get("%s from %s" % [lane, z], [0, 0])
								m[0] += 1
								m[1] += 0 if b.visible else 1
								matrix["%s from %s" % [lane, z]] = m
						if cls == "own zone":
							assert_true(b.visible, "seed %d level %d %s: the %s badge is hidden from its own zone" % [s, level, ASPECT_NAMES[aspect_i], lane])
						if b.visible and v.screen().intersects(r):
							for e in obstacles:
								if r.intersects(e[1]):
									fail_test("seed %d level %d %s focus %s: the %s badge %s is drawn over %s %s" % [s, level, ASPECT_NAMES[aspect_i], f, lane, r, e[0], e[1]])
		main.queue_free()
		await get_tree().process_frame
	gut.p("how often the cover rule hides a badge, by class of camera focus (all seeds, levels 0..3, three aspects):")
	for cls in table:
		gut.p("  %-14s %5d views, %5d hidden (%.1f%%)" % [cls, table[cls][0], table[cls][1], 100.0 * table[cls][1] / maxf(table[cls][0], 1)])
	var other: Array = table.get("other zone", [1, 0])
	assert_lte(float(other[1]) / float(other[0]), 0.20, "a rule that hides a badge from more than a fifth of the other lanes' zone views over-hides")
	gut.p("a badge seen from the zone of each lane (hidden / views):")
	for k in matrix:
		gut.p("  %-22s %4d / %4d" % [k, matrix[k][1], matrix[k][0]])

## Real frames, a real viewport at 9:16: the hero stands on the badge's ground point (its body covers the icon): within 20 physics frames
## (the timer's period is 15) the badge is hidden; the hero walks to the lane's zone and it is drawn again. The rule runs at most
## label_dim_hz times a second, not every frame.
func test_the_cover_rule_runs_on_a_timer_hides_over_the_hero_and_shows_again_when_clear() -> void:
	SafeArea.override_for_tests = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	Balance.data.tiers.retune_enabled = true
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	add_child_autofree(vp)
	main = Main.create()
	vp.add_child(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(4)  # siege west, hare north
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_tier(3, 5)
	for i in 3:
		await get_tree().physics_frame
	var b: LaneCharacterMarker = _marker("west").badge
	assert_not_null(b)
	var ground := Vector2(b.global_position.x, b.global_position.z)
	main.hero.teleport(ground)
	main.camera_rig.snap()
	for i in 20:
		await get_tree().physics_frame
	assert_true(b.is_covered(), "the hero stands on the badge: it is hidden")
	assert_false(b.visible)
	var before := b.ticks
	for i in 60:
		await get_tree().physics_frame
	assert_lte(b.ticks - before, int(ceilf(Balance.ui.label_dim_hz)) + 1, "at most label_dim_hz evaluations a second, not one per frame (%d in 60 frames)" % (b.ticks - before))
	assert_gt(b.ticks - before, 0, "but it does run")
	main.hero.teleport(_zone_focus("west"))
	main.camera_rig.snap()
	for i in 20:
		await get_tree().physics_frame
	assert_false(b.is_covered(), "the hero left: the badge is drawn again")
	assert_true(b.visible)

# --- the hold for the dawn reveal, the timers, the share of hiding ------------------------------------------------------------------

## Mutation: tick() or evaluate() ignores `held` -> the badge re-shows from its own zone within 20 frames.
func test_a_held_badge_stays_hidden_and_shows_again_within_20_frames_of_the_release() -> void:
	await _start(4)  # siege west, hare north
	var b: LaneCharacterMarker = _marker("west").badge
	await _stand_at(_zone_focus("west"))
	assert_true(b.is_visible_in_tree(), "from its own zone nothing covers it")
	b.hold(true)
	assert_false(b.visible)
	assert_false(b.is_covered(), "a held badge is held, not covered")
	for i in 60:
		await get_tree().physics_frame
	assert_false(b.visible, "held for 60 frames from its own zone, where nothing covers it")
	_marker("west").refresh()
	assert_false(b.visible, "a refresh during the hold keeps it hidden")
	GameState.debug_set_tier(3, 6)
	await get_tree().physics_frame
	assert_false(b.visible, "so does a tier event")
	b.hold(false)
	for i in 20:
		await get_tree().physics_frame
	assert_true(b.visible, "released: it shows again within 20 frames")
	assert_false(b.held)

func test_badges_made_by_a_new_game_or_a_tier_rebuild_are_not_held() -> void:
	await _start(3)  # siege sw, hare west
	for lane in _badges():
		_marker(lane).badge.hold(true)
	GameState.debug_set_tier(2, 5)  # the sw marker and its badge go
	await get_tree().physics_frame
	await get_tree().process_frame
	GameState.debug_set_tier(3, 5)  # rebuilt
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_not_null(_marker("sw").badge)
	assert_false(_marker("sw").badge.held, "a rebuilt badge is not held")
	assert_true(_marker("sw").badge.visible)
	GameState.new_game(7)
	GameState.debug_set_tier(3, 5)
	await get_tree().physics_frame
	for lane in _badges():
		assert_false(_marker(lane).badge.held, "%s: a badge of a new run is not held" % lane)

func test_the_two_badges_of_a_run_do_not_evaluate_in_the_same_physics_frame() -> void:
	for s in PLACEMENT_SEEDS:
		await _start(s)
		await _stand_at(_zone_focus("north"))
		var frames := {}
		for lane in _badges():
			frames[lane] = _marker(lane).badge.last_tick_frame
		var seen := {}
		for lane in frames:
			assert_gt(int(frames[lane]), 0, "seed %d %s has evaluated" % [s, lane])
			assert_false(seen.has(frames[lane]), "seed %d: two badges evaluated in physics frame %d" % [s, frames[lane]])
			seen[frames[lane]] = true
		main.queue_free()
		await get_tree().process_frame
