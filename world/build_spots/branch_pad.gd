class_name BranchPad
extends Node3D
## One branch option of one level-3 building at tier 3 (E5 tier 3 Task 17, D-263, D-264, D-273): the player chooses by standing
## still on one of the spot's two pads, exactly as every other purchase. The world makes two per spot (index 0 = the first option
## of GameState.branch_options, index 1 the second) and each shows only while GameState.can_branch(spot_id) and it is DAY.
## All state comes from GameState (partial payments live in buildings[id].branch_paid); the pad only draws it and pays into IT
## (never into the other pad): GameState.pay_into_branch commits only on full payment and refunds the other pad's partial
## payment, which this node shows as coins flying back to the hero.
##
## PROGRESSIVE DISCLOSURE (fix round 1): one focus spot at a time, so many level-3 buildings never pile their labels up.
##   FAR   (not the focus spot): the ground ring and the branch glyph on the pad, depth-tested (buildings hide it); no text. The glyph
##         is hidden (FAR_QUIET) while the hero stands on any pad.
##   NEAR  (the focus spot, hero not on this pad): ring, glyph and the remaining cost under it, one block at most 1.25 m wide.
##   QUIET (the other pad of the spot the hero stands on): ring and payment ring only; its glyph and cost come back when he leaves.
##   ON    (the hero is inside this pad): glyph and cost row, name, preview line, the fence warning line, and the preview at the
##         building (range rings, "x3", shield, spikes). It shows before the stand-still threshold and before any gold moves.
## The stage is VISUAL ONLY: _on_tick (the payment) never reads it.
##
## E6 (spec 5.3, D-284.4, D-284.5, D-286, D-307): the name, the preview line and the fence warning live in
## the HUD's branch card (ui/hud/branch_card.gd), so the world keeps only the ring, the glyph, the NEAR cost and the preview at the building.
##   ON    (the hero stands on an ARMED pad: he walked in, the card shows): the ring, the glyph alone (no cost, no name, no preview line, no
##         warning) and the preview shape. The sibling stays quiet.
##   UNARMED (the hero stands on a pad that is not armed: he was placed there, or the pad appeared under him; the card stays hidden until he
##         leaves and re-enters): ring and glyph at the ON glyph's place, NO cost and NO preview (it cannot be paid yet: one step out shows the
##         near cost, stepping back in arms it and the card shows). The sibling stays quiet.
##   While a pad is ON or UNARMED its glyph follows the HERO (above his head, or below his feet for the pads in ON_ROW_NORTH_RETUNE), by the same
##         screen offset it has above the pad's centre; the preview shape stays at the building. One position write per physics frame, visual only.
##   NEAR  is per PAD: the focus spot's pad shows its cost only while the hero is within branch_pad_near_m of that pad (branch_pad_leave_m once
##         shown); the spot's other pad, if farther, stays FAR (ring and glyph).

## E6: emitted whenever the stage changes (or the pad goes away). The build spot of the pad listens: its level pips hide while one of its own pads
## shows a cost. A local signal between a spot and its own pads, not an EventBus event.
signal stage_changed

const FAR := 0
const FAR_QUIET := 1
const NEAR := 2
const ON := 3
## The sibling of the pad the hero stands on: its ground ring and payment ring only (on a pad only the stood option speaks).
const SIBLING_QUIET := 4
## E6: the hero stands on a pad that is not armed, so the card is hidden: the glyph and the cost stay in the world.
const UNARMED := 5
## The lone ON glyph starts this far below the pad's ground point on the screen (clears the marker ring, about 0.75 m deep on screen).
const SOUTH_BASE_M := 0.8
## The gap (m) between the preview glyph and its multiplier.
const WARN_GAP := 0.1
## E6: the lone glyph above the hero's head starts here (the test's hero box is taller on screen).
const RETUNE_NORTH_BASE_M := 1.25
## E6 (D-294.8): the hero is drawn IN FRONT of every pad label. The labels are Label3D with no depth test (drawn over buildings and ground), so
## they cannot be hidden by depth; the order is by render priority (a lower number draws earlier, all in the transparent pass): the pad's ring and disc
## RING_PRIORITY (-7), the label OUTLINES OUTLINE_PRIORITY (-6, with the tether's ink edge), the label fills, glyphs and the tether's light line LABEL_PRIORITY (-5),
## then the hero and his carried pile at Hero.DRAW_AFTER_LABELS_PRIORITY (-2; he writes depth, so everything drawn after him is hidden where he stands), then
## everything else (-1 and up) as today. The HERO owns his materials (HeroVisual.draw_after_labels): no pad touches them.
const RING_PRIORITY := -7
const OUTLINE_PRIORITY := -6
const LABEL_PRIORITY := -5
## The coins of a refund flight (the exact amount is on the "+N" label) and the pause between two of them (s).
const REFUND_COINS := 5
const REFUND_GAP := 0.07
const REFUND_LABEL_RISE := 1.2
const REFUND_LABEL_TIME := 1.4

## E6: where the lone ON glyph (and the UNARMED glyph-and-cost row) stands: "spot:index" -> true above the hero's head, false below
## the pad. Searched with the zero-overlap test (tests/unit/test_branch_pads.gd); a pad not listed stands above.
const ON_ROW_NORTH_RETUNE := {"tower_nw:0": false, "tower_ne:1": false}
## E6: where the glyph of a STOOD pad (ON or UNARMED) stands relative to its default place above the hero's head (or below the pad):
## "spot:index" -> Vector2(right, up) in metres ON THE SCREEN. Searched with the edge-point cases of the stood-pad zero test.
const ON_SHIFT_RETUNE := {"fence_w:1": Vector2(-0.1, 0.3), "fence_e:0": Vector2(0.2, 0.4), "tower_e:1": Vector2(-0.6, 0.0), "fence_sw:1": Vector2(0.0, -0.075), "tower_ne:0": Vector2(-0.1, 0.0), "tower_sw:0": Vector2(0.0, 0.1)}
## E6: where a pad's NEAR cost stands relative to its default place under the glyph: "spot:index" -> Vector2(right, up) in metres ON THE SCREEN.
## The GLYPH moves only inside its ring (GLYPH_SHIFT_RETUNE, tested). Only the COST moves far (D-294.8); searched with the per-pad near-stage scan of tests/unit/test_branch_pads.gd (every reachable
## view of the pad, zero overlaps, 8 px clearance). A pad not listed keeps the cost under its glyph.
const GLYPH_SHIFT_RETUNE := {"tower_e:0": Vector2(0.1, 0.0), "tower_ne:1": Vector2(-0.05, 0.0), "tower_sw:0": Vector2(0.0, -0.05), "tower_sw:1": Vector2(0.1, 0.0)}
const COST_SHIFT_RETUNE := {
	"tower_nw:0": Vector2(-1.1, 0.8), "tower_ne:0": Vector2(-1.1, 0.8), "tower_ne:1": Vector2(-1.1, 0.8),
	"tower_e:0": Vector2(1.9, 0.2),
	"fence_e:0": Vector2(-1.1, 0.7), "fence_e:1": Vector2(0.4, 0.0), "fence_sw:0": Vector2(-1.1, 0.8), "fence_sw:1": Vector2(-1.1, 0.9),
	"fence_w:0": Vector2(-1.1, 0.8), "fence_w:1": Vector2(-1.1, 0.8),
}

## The texts, through tr() when shown: [name, preview line]. The Volley's line is built from the balance count.
const TEXTS := {
	&"longbow": ["Longbow", "far, heavy, slow"],
	&"volley": ["Volley", "%d targets"],
	&"stone": ["Stone wall", "holds brutes"],
	&"spike": ["Spike fence", "hurts attackers"],
}
const WARN_TEXT := "lost if broken"

var spot_id := ""
var branch_id: StringName = &""
var index := 0
var zone: StationZone
## Hidden as a whole when the pad is not shown (the root stays: the refund effect outlives the pad).
var body: Node3D
var marker: MeshInstance3D
var icon: MeshInstance3D
var name_label: WorldLabel
var effect_label: WorldLabel
var cost_label: WorldLabel
var warn_icon: MeshInstance3D
var warn_label: WorldLabel
var refund_label: WorldLabel
## The preview (top level, at the building): range rings (Longbow) or a glyph with its multiplier (Volley, Stone wall, Spike fence).
var preview: Node3D
var preview_rings: Array[MeshInstance3D] = []
var hint_icons: Array[MeshInstance3D] = []
var hint_label: WorldLabel
## Where the preview glyph stands relative to its default (HINT_AT_RETUNE); call place_hint() after changing it.
var hint_at := Vector2.ZERO
## What the last refund showed: the exact gold (the "+N" label) and how many coins flew for it.
var last_refund := 0
var refund_coins := 0
## The stage shown now (FAR, FAR_QUIET, NEAR, ON, SIBLING_QUIET, UNARMED).
var stage := FAR
## Where the lone ON glyph stands (ON_ROW_NORTH_RETUNE): above the hero's head or below the pad; call _layout_items() and re-apply the stage after changing it.
var row_north := false
## E6: the NEAR cost's shift from its default place (COST_SHIFT_RETUNE), metres on the screen (right, up); call _layout_items() and re-apply the stage after changing it
## (the layout reads the glyph's size from Balance.ui.icon_m, not from its current scale, so a re-layout at any stage gives the same place).
var cost_shift := Vector2.ZERO
## E6: the NEAR glyph's shift inside its ring (GLYPH_SHIFT_RETUNE), metres on the screen (right, up).
var glyph_shift := Vector2.ZERO
## E6: the tether (D-294.8): a line from a cost's edge to the pad's RING edge, drawn when the cost's nearest edge stands farther than TETHER_FROM_M from the pad's centre; shown
## only with the cost. A light line (palette gold) with an ink edge, TETHER_WIDTH_M wide in all (the ink included; the gold line alone is TETHER_WIDTH_M - 2 x TETHER_INK_M = 0.17 m), drawn like a label (ink edge at OUTLINE_PRIORITY, light line at
## LABEL_PRIORITY). `tether_ends` = [ring end, cost end] of its centre line in the pad's local space ([] when there is none), `tether_len` its length in metres on the screen.
const TETHER_FROM_M := 0.5
## E6: the NEAR glyph's height above the pad's centre (metres on the screen: its box stays inside the ring), and the gap between it and the cost.
const NEAR_GLYPH_UP_M := 0.0
const STACK_GAP_NEAR_M := -0.02
const TETHER_WIDTH_M := 0.27
const TETHER_INK_M := 0.05
var tether: MeshInstance3D
var tether_ink: MeshInstance3D
var tether_ends: Array = []
var tether_len := 0.0
## E6: the stood glyph's shift (ON_SHIFT_RETUNE), metres on the screen (right, up).
var on_shift := Vector2.ZERO
var _fx: FlyFx
var _paid_ticks := 0
var _was_shown := false
## Gold of this pad in GameState at the last refresh while the building could branch (a completion or a destroyed fence clears
## the state before branch_refunded fires; this is what the refund takes from this pad).
var _paid_seen := 0
var _refund_tween: Tween
var _coin_tween: Tween
## Local positions of the items per stage (built once, in screen metres): {NEAR: {node: Vector3}, ON: {node: Vector3}}.
var _pos := {}

# --- the focus spot (one per physics frame, shared by every pad) -------------------------------------------

## The pads on the map now (shown ones only: a hidden pad is not in it and does not process).
static var _shown_pads: Array = []
static var _cache_frame := -1
static var _focus_spot := ""
static var _on_pad: BranchPad = null
## The hero's ground position as read by the last update_focus (E6: the glyph of a stood pad follows him).
static var _hero_at := Vector3.ZERO
## Reused every frame (no allocation in update_focus): spot -> smallest distance to one of its pads; the spots of the tier, refreshed
## when the tier changes.
static var _nearest := {}
static var _spots: Array[String] = []
static var _spots_tier := -1

## Computes the focus spot and the pad the hero stands on, once per physics frame: one hero lookup and one distance per shown pad.
## The pad the hero stands on gives its spot; else the spot kept from before while the hero is within `branch_pad_leave_m` of its
## nearest pad (hysteresis); else the spot whose nearest pad is closest within `branch_pad_near_m` (ties: spots_for_tier order).
## With no pad shown (night, a new game, a load) nothing is focused.
static func update_focus(tree: SceneTree) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _cache_frame:
		return
	_cache_frame = frame
	_on_pad = null
	_purge_freed()  # a pad freed since (a rebuild) leaves the registry
	var hero := tree.get_first_node_in_group(&"hero") as Node3D
	if hero == null or _shown_pads.is_empty():
		_focus_spot = ""
		return
	var hx := hero.global_position.x
	var hz := hero.global_position.z
	_hero_at = hero.global_position
	for k in _nearest:  # overwrite, never clear and re-insert: a spot with no shown pad now keeps INF
		_nearest[k] = INF
	var best_on := INF
	for p: BranchPad in _shown_pads:
		var d := Vector2(hx - p.global_position.x, hz - p.global_position.z).length()
		if d < float(_nearest.get(p.spot_id, INF)):
			_nearest[p.spot_id] = d
		if d <= MapLayout.BRANCH_PAD_RADIUS and d < best_on:
			best_on = d
			_on_pad = p
	if _on_pad != null:
		_focus_spot = _on_pad.spot_id
		return
	if _focus_spot != "" and _nearest.has(_focus_spot) and float(_nearest[_focus_spot]) <= Balance.ui.branch_pad_leave_m:
		return
	_focus_spot = ""
	if _spots_tier != GameState.tier:
		_spots_tier = GameState.tier
		_spots = MapLayout.spots_for_tier(GameState.tier)
	var best := INF
	for id in _spots:
		if _nearest.has(id) and float(_nearest[id]) <= Balance.ui.branch_pad_near_m and float(_nearest[id]) < best:
			best = float(_nearest[id])
			_focus_spot = id

## The material of a glyph that shows: one with LABEL_PRIORITY (drawn before the hero).
func _glyph_material() -> StandardMaterial3D:
	return BranchIcons.front_material(LABEL_PRIORITY)

## Drops the freed pads from the shown registry.
static func _purge_freed() -> void:
	for i in range(_shown_pads.size() - 1, -1, -1):
		if not is_instance_valid(_shown_pads[i]):
			_shown_pads.remove_at(i)

## Takes a pad out of the shown registry; the last one out clears the focus (night, a new game, a load: no stale focus survives).
static func _forget_shown(pad: BranchPad) -> void:
	_shown_pads.erase(pad)
	_purge_freed()
	if _shown_pads.is_empty():
		_focus_spot = ""
		_on_pad = null
	elif _on_pad == pad:
		_on_pad = null
	_cache_frame = -1

static func focus_spot() -> String:
	return _focus_spot

static func pad_hero_stands_on() -> BranchPad:
	return _on_pad

## Forgets the shared focus (a new world, tests).
static func reset_focus() -> void:
	_purge_freed()
	_cache_frame = -1
	_focus_spot = ""
	_on_pad = null

func setup(p_spot_id: String, p_index: int, world: World) -> void:
	spot_id = p_spot_id
	index = p_index
	branch_id = GameState.branch_options(spot_id)[index]
	_fx = world.fly_fx
	name = "BranchPad_%s_%s" % [spot_id, branch_id]
	position = MapLayout.to3(MapLayout.branch_pad(spot_id, index))
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	marker = MeshInstance3D.new()
	marker.name = "Marker"
	marker.mesh = BranchIcons.ring_mesh(&"ice_blue", 0.82, 0.22)
	marker.material_override = BranchIcons.ground_front_material(RING_PRIORITY)
	marker.scale = Vector3(MapLayout.BRANCH_PAD_RADIUS, 1.0, MapLayout.BRANCH_PAD_RADIUS)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(marker)
	_build_items()
	_build_preview()
	refund_label = WorldLabel.make("", Balance.ui.branch_pad_cost_font)
	refund_label.name = "Refund"
	refund_label.pixel_size = Balance.ui.branch_pad_cost_pixel_size
	refund_label.modulate = Palette.color(&"gold")
	_front(refund_label)
	refund_label.visible = false
	add_child(refund_label)
	zone = StationZone.new()
	zone.radius = MapLayout.BRANCH_PAD_RADIUS
	zone.drive_ring = false  # the ring shows paid / cost
	add_child(zone)
	# the payment ring is a ground ring too: under the labels (the zone makes it in its _ready)
	if zone.ring != null:
		_ring_under_labels()
	else:
		zone.ready.connect(_ring_under_labels, CONNECT_ONE_SHOT)
	zone.ticked.connect(_on_tick)
	EventBus.building_changed.connect(_on_building_changed)
	EventBus.branch_refunded.connect(_on_branch_refunded)
	EventBus.phase_changed.connect(_on_phase_changed)  # after the zone's own connection (it syncs its phase first)
	EventBus.state_restored.connect(refresh)
	EventBus.tier_changed.connect(_on_tier_changed)
	set_physics_process(false)
	refresh()

func _ring_under_labels() -> void:
	(zone.ring.material_override as ShaderMaterial).render_priority = RING_PRIORITY

func _exit_tree() -> void:
	_forget_shown(self)  # also clears _on_pad when it is this pad, and the frame cache
	stage = FAR  # a pad taken out of the tree shows no cost: its spot gets its pips back
	stage_changed.emit()

# --- items and their layout --------------------------------------------------------------------------

func _label(font_size: int, pixel: float, node_name: String, text := "") -> WorldLabel:
	var l := WorldLabel.make(text, font_size)
	l.name = node_name
	l.pixel_size = pixel
	l.visible = false
	_front(l)
	body.add_child(l)
	return l

## E6: a pad label draws below the hero: its outline at OUTLINE_PRIORITY, its fill at LABEL_PRIORITY.
func _front(l: Label3D) -> void:
	l.render_priority = LABEL_PRIORITY
	l.outline_render_priority = OUTLINE_PRIORITY

func _glyph(kind: StringName, size_m: float, node_name: String, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = BranchIcons.mesh(kind)
	m.material_override = _glyph_material()
	m.scale = Vector3.ONE * size_m
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else body).add_child(m)
	return m

static func _font() -> Font:
	return load(WorldLabel.BOLD_PATH)

## The box (m, camera-facing) a label draws, outline included, from its own font, size, text and wrap.
static func text_box(l: Label3D) -> Vector2:
	var wrap := float(l.width) if l.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	var sz := _font().get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, wrap, l.font_size)
	return (sz + Vector2.ONE * float(l.outline_size)) * l.pixel_size

## The box (m) a glyph node draws, its ink outline included.
static func glyph_box(g: MeshInstance3D) -> Vector2:
	var sz := g.mesh.get_aabb().size
	return Vector2(sz.x, sz.y) * g.scale.x

## World y (m) of a billboard that must stand `m` metres above (below, when negative) its anchor ON THE SCREEN: the camera looks
## down at 55 degrees, so a height h shows as h * cos(pitch).
static func screen_to_y(m: float) -> float:
	return m / cos(deg_to_rad(absf(Balance.ui.camera_pitch)))

## Creates the items and lays out the NEAR block and the ON stack once, in screen metres.
func _build_items() -> void:
	var ui := Balance.ui
	var pix: float = ui.branch_pad_label_pixel_size
	icon = _glyph(branch_id, ui.icon_m(), "Icon")
	cost_label = _label(ui.branch_pad_cost_font, ui.branch_pad_cost_pixel_size, "Cost", "000")  # "000": the widest cost fixes the block widths
	name_label = _label(ui.branch_pad_label_font, pix, "Name", tr(TEXTS[branch_id][0]))
	var effect := tr(TEXTS[branch_id][1])
	if branch_id == &"volley":
		effect = effect % int(Balance.data.branches.tower(&"volley").count)
	effect_label = _label(ui.branch_pad_label_font, pix, "Effect", effect)
	var fence := MapLayout.spot_kind(spot_id) == "fence"
	if fence:
		warn_label = _label(ui.branch_pad_warn_font, ui.branch_pad_warn_pixel_size, "Warn", tr(WARN_TEXT))
		warn_icon = _glyph(&"broken", float(ui.branch_pad_warn_font) * ui.branch_pad_warn_pixel_size * 1.3, "WarnIcon")
		warn_icon.visible = false
	row_north = bool(ON_ROW_NORTH_RETUNE.get("%s:%d" % [spot_id, index], true))
	glyph_shift = GLYPH_SHIFT_RETUNE.get("%s:%d" % [spot_id, index], Vector2.ZERO)
	cost_shift = COST_SHIFT_RETUNE.get("%s:%d" % [spot_id, index], Vector2.ZERO)
	on_shift = ON_SHIFT_RETUNE.get("%s:%d" % [spot_id, index], Vector2.ZERO)
	_layout_items()
	cost_label.text = ""

## Lays out the NEAR block and the ON stack (positions only), in screen metres.
func _layout_items() -> void:
	# the glyph's size at its NEAR/ON stage, not its current scale (the far stage is smaller): a re-layout at any stage gives the same place
	var ibox := Vector2(icon.mesh.get_aabb().size.x, icon.mesh.get_aabb().size.y) * Balance.ui.icon_m()
	var cbox := _cost_box()
	# NEAR: the glyph stays INSIDE its ring (NEAR_GLYPH_UP_M above the pad's centre); only the cost moves (COST_SHIFT_RETUNE), from its default place right under the glyph
	var cost_up := NEAR_GLYPH_UP_M + glyph_shift.y - ibox.y * 0.5 - STACK_GAP_NEAR_M - cbox.y * 0.5 + cost_shift.y
	_pos[NEAR] = {
		icon: _at(NEAR_GLYPH_UP_M + glyph_shift.y, true) + Vector3(glyph_shift.x, 0.0, 0.0),
		cost_label: _at(-cost_up, false) + Vector3(cost_shift.x, 0.0, 0.0),
	}
	_layout_tether(cbox, cost_up)
	_layout_stood(ibox, cbox)

## A point `p` metres ON THE SCREEN from the pad's ground point (right, up), in the plane facing the camera, as a local position.
static func _scr(p: Vector2) -> Vector3:
	var basis := CameraMath.camera_transform(Vector2.ZERO, Balance.ui).basis
	return basis.x * p.x + basis.y * p.y

## E6: the tether from the NEAR cost to its pad (screen metres from the pad): a line from the cost's edge facing the pad to the RING's edge, light (gold) with an ink edge
## all round (TETHER_WIDTH_M wide in all). None while the cost stands within TETHER_FROM_M of the pad's centre.
func _layout_tether(cbox: Vector2, cost_up: float) -> void:
	tether_ends = []
	tether_len = 0.0
	if tether == null:
		tether_ink = _tether_node("TetherInk", OUTLINE_PRIORITY)
		tether = _tether_node("Tether", LABEL_PRIORITY)
	var cpos := Vector2(cost_shift.x, cost_up)  # the cost's centre from the pad's, on the screen
	var edge := Vector2(maxf(absf(cpos.x) - cbox.x * 0.5, 0.0), maxf(absf(cpos.y) - cbox.y * 0.5, 0.0)).length()  # the cost's nearest edge from the pad's centre
	if edge <= TETHER_FROM_M + 0.001:
		tether.mesh = null
		tether_ink.mesh = null
		return
	var d := -cpos.normalized()
	var ry := MapLayout.BRANCH_PAD_RADIUS * sin(deg_to_rad(absf(Balance.ui.camera_pitch)))
	var t_ring := 1.0 / sqrt(pow(d.x / MapLayout.BRANCH_PAD_RADIUS, 2.0) + pow(d.y / ry, 2.0))  # the ring's edge from the pad's centre along the line
	var t_blk := minf(cbox.x * 0.5 / maxf(absf(d.x), 1e-6), cbox.y * 0.5 / maxf(absf(d.y), 1e-6))
	var tail := cpos + d * t_blk  # on the edge of the cost's box (the outline included)
	tether_len = maxf(tail.length() - t_ring, 0.0)
	var tip := tail + d * tether_len  # on the ring's edge
	tether_ends = [_scr(tip), _scr(tail)]
	var ink := TETHER_INK_M
	tether.mesh = _quad_mesh(tip, tail, d, TETHER_WIDTH_M * 0.5 - ink, Palette.color(&"gold"))
	tether_ink.mesh = _quad_mesh(tip, tail, d, TETHER_WIDTH_M * 0.5, Palette.color(&"ink"))

func _tether_node(node_name: String, priority: int) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = node_name
	n.visible = false
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := BranchIcons.ground_material().duplicate() as StandardMaterial3D
	mat.no_depth_test = true
	mat.render_priority = priority
	n.material_override = mat
	body.add_child(n)
	return n

## A flat strip from `tip` to `tail` (screen metres from the pad), `half` metres to each side of the line; the ink strip is longer than the light one by the same edge.
func _quad_mesh(tip: Vector2, tail: Vector2, d: Vector2, half: float, c: Color) -> ArrayMesh:
	var grow := half - (TETHER_WIDTH_M * 0.5 - TETHER_INK_M)  # 0 for the light strip, TETHER_INK_M for the ink strip
	var perp := Vector2(-d.y, d.x) * half
	var t0 := tip - d * grow
	var t1 := tail + d * grow
	var verts := PackedVector3Array([_scr(t1 - perp), _scr(t1 + perp), _scr(t0 + perp), _scr(t1 - perp), _scr(t0 + perp), _scr(t0 - perp)])
	var cols := PackedColorArray([c, c, c, c, c, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## E6: the ON glyph alone, centred, above the hero's head or below the pad (`row_north`); the UNARMED glyph stands at the same place (no cost).
## Above the head starts at RETUNE_NORTH_BASE_M: the test's hero box is taller on screen. The offset is from the
## pad's centre; while shown on a stood pad the glyph keeps it from the HERO (_follow_hero).
func _layout_stood(ibox: Vector2, _cbox: Vector2) -> void:
	var m := RETUNE_NORTH_BASE_M if row_north else SOUTH_BASE_M
	_pos[ON] = {icon: _at(m + ibox.y * 0.5 + (on_shift.y if row_north else -on_shift.y), row_north) + Vector3(on_shift.x, 0.0, 0.0)}
	_pos[UNARMED] = _pos[ON]

## The local position of an item whose centre stands `c` metres ON THE SCREEN above (north) or below (south) the pad: above it is a
## height (a billboard over the hero), below it is a point on the ground south of the pad (the camera looks down at 55 degrees).
static func _at(c: float, north: bool) -> Vector3:
	if north:
		return Vector3(0, screen_to_y(c), 0)
	return Vector3(0, 0, c / sin(deg_to_rad(absf(Balance.ui.camera_pitch))))

## The box of the widest cost ("000"): it fixes the width of the NEAR block, whatever the cost reads now.
func _cost_box() -> Vector2:
	var t := cost_label.text
	cost_label.text = "000"
	var b := text_box(cost_label)
	cost_label.text = t
	return b

# --- the preview (D-263.3) ---------------------------------------------------------------------------

func _build_preview() -> void:
	preview = Node3D.new()
	preview.name = "Preview"
	preview.top_level = true
	preview.visible = false
	add_child(preview)
	preview.global_position = MapLayout.to3(MapLayout.spot_position(spot_id))
	var bb: BranchBalance = Balance.data.branches
	match branch_id:
		&"longbow":
			# the ring at today's level-3 range, and the Longbow's: the gain is the gap between them
			_ring(bb.tower(&"").attack_range, &"steel", "RangeNow")
			_ring(bb.tower(&"longbow").attack_range, &"ice_blue", "RangeLongbow")
		&"volley":
			_hint(&"volley", _mult_text(float(bb.tower(&"volley").count)))
		&"stone":
			_hint(&"stone", _mult_text(bb.fence(&"stone").hp / bb.fence(&"").hp))
		_:
			_hint(&"spike", "")

func _ring(radius: float, colour: StringName, node_name: String) -> void:
	var r := MeshInstance3D.new()
	r.name = node_name
	r.mesh = BranchIcons.ring_mesh(colour, 0.985, 0.0)
	r.material_override = BranchIcons.ground_front_material(RING_PRIORITY)
	r.scale = Vector3(radius, 1.0, radius)
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.add_child(r)
	preview_rings.append(r)

## The preview glyph (and its multiplier) hangs HINT_Y above the ground and HINT_Z south of the building's centre (HINT_AT_RETUNE moves it per spot or pad).
const HINT_Z := 1.7
const HINT_Y := 0.35
## E6: a key is a spot ("tower_e") or one pad ("tower_e:1", which wins); the zero-overlap test (tests/unit/test_branch_pads.gd) is the oracle for any change.
const HINT_AT_RETUNE := {"tower_w": Vector2(0.0, -1.5), "tower_sw": Vector2(-1.0, 0.0), "tower_e": Vector2(0.0, 0.25), "fence_sw": Vector2(0.25, 0.0), "tower_nw:1": Vector2(-0.5, 0.0), "tower_w:1": Vector2(-0.5, -1.5)}

## A glyph and, if `mult` is not empty, its multiplier beside it, in front of the building.
func _hint(kind: StringName, mult: String) -> void:
	var g := _glyph(kind, Balance.ui.icon_m(), "HintIcon", preview)
	hint_icons.append(g)
	if mult != "":
		hint_label = WorldLabel.make(mult, Balance.ui.branch_pad_cost_font)
		hint_label.name = "HintMult"
		_front(hint_label)
		hint_label.pixel_size = Balance.ui.branch_pad_label_pixel_size
		preview.add_child(hint_label)
	hint_at = HINT_AT_RETUNE.get("%s:%d" % [spot_id, index], HINT_AT_RETUNE.get(spot_id, Vector2.ZERO))
	place_hint()

## Puts the preview glyph (and its multiplier) at (hint_at.x, HINT_Y, HINT_Z + hint_at.y) from the building.
func place_hint() -> void:
	if hint_icons.is_empty():  # the Longbow previews with rings only
		return
	var g := hint_icons[0]
	var z := HINT_Z + hint_at.y
	var gw := glyph_box(g).x
	if hint_label == null:
		g.position = Vector3(hint_at.x, HINT_Y, z)
		return
	var tw := text_box(hint_label).x
	var total := gw + WARN_GAP + tw
	g.position = Vector3(hint_at.x - total * 0.5 + gw * 0.5, HINT_Y, z)
	hint_label.position = Vector3(hint_at.x + total * 0.5 - tw * 0.5, HINT_Y, z)

## "x3", "x2", "x1.5": a whole number without a decimal.
static func _mult_text(m: float) -> String:
	return "x%d" % int(roundf(m)) if is_equal_approx(m, roundf(m)) else "x%s" % String.num(m, 1)

## The radius (m) a ring of the preview draws.
static func ring_radius(ring: MeshInstance3D) -> float:
	return ring.mesh.get_aabb().size.x * 0.5 * ring.scale.x

# --- state -------------------------------------------------------------------------------------------

## True while this pad is on the map: the building can branch (tier 3, level 3, no branch, a fence that stands) and it is DAY.
func is_shown() -> bool:
	return zone != null and zone.is_active() and GameState.can_branch(spot_id)

func hero_inside() -> bool:
	if not is_shown():
		return false
	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
	if hero == null:
		return false
	return Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length() <= MapLayout.BRANCH_PAD_RADIUS

## Gold paid into this pad (0 when the building cannot branch).
func paid() -> int:
	var rem := GameState.branch_remaining(spot_id, branch_id)
	return GameState.branch_cost(spot_id) - rem if rem >= 0 else 0

func preview_shown() -> bool:
	return preview.visible

func _physics_process(_delta: float) -> void:
	update_focus(get_tree())
	var want := _stage_now()
	if want != stage:
		_apply_stage(want)
	_follow_hero()

## E6: the hero is at or near this pad, or on its sibling: NEAR, UNARMED, ON or SIBLING_QUIET, i.e. anything but FAR / FAR_QUIET. The pips of its
## building are covered (BuildSpot) while any of its own pads is in use: a walk-in passes NEAR -> UNARMED -> ON, and a rule that skipped UNARMED flashed the stars for a tick.
func in_use() -> bool:
	return body != null and body.visible and (stage == NEAR or stage == ON or stage == UNARMED or stage == SIBLING_QUIET)

func _stage_now() -> int:
	if _on_pad == self:
		if not zone.armed:
			return UNARMED
		return ON
	if _on_pad != null and _on_pad.spot_id == spot_id:
		return SIBLING_QUIET
	if _focus_spot == spot_id:
		if not _in_reach():
			return FAR  # E6: a pad of the focus spot that is out of reach keeps its ring and glyph; the cost is for the pads the hero can walk to
		return NEAR
	return FAR if _on_pad == null else FAR_QUIET

## E6: the hero is within `branch_pad_near_m` of THIS pad, or, while it already shows its cost, within `branch_pad_leave_m` (the same
## hysteresis as the spot's focus, per pad).
func _in_reach() -> bool:
	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
	if hero == null:
		return false
	var d := Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length()
	return d <= (Balance.ui.branch_pad_leave_m if stage == NEAR else Balance.ui.branch_pad_near_m)

## Writes the items of `st`: only when the stage changes (visibility, positions, glyph size and material).
func _apply_stage(st: int) -> void:
	stage = st
	var ui := Balance.ui
	icon.visible = st != FAR_QUIET and st != SIBLING_QUIET
	if st <= FAR_QUIET or st == SIBLING_QUIET:
		icon.material_override = BranchIcons.far_front_material(LABEL_PRIORITY)
		icon.scale = Vector3.ONE * ui.branch_pad_far_icon_m
		icon.position = Vector3(0, 0.45, 0)
	else:
		icon.material_override = _glyph_material()
		icon.scale = Vector3.ONE * ui.icon_m()
	cost_label.visible = st == NEAR  # E6: an unarmed (or stood) pad shows no cost: the card speaks
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if st == NEAR else HORIZONTAL_ALIGNMENT_LEFT
	if tether != null:
		tether.visible = st == NEAR and not tether_ends.is_empty()
		tether_ink.visible = tether.visible
	var on := st == ON
	# E6: the name, the preview line and the warning are the card's, not the world's: those labels stay hidden
	preview.visible = on
	if _pos.has(st):
		for n in _pos[st]:
			(n as Node3D).position = _pos[st][n]
	_follow_hero()
	stage_changed.emit()

## E6: on a stood pad (ON or UNARMED) the glyph keeps its offset from the hero, not from the pad's centre: a hero standing at the pad's
## edge has the glyph above his head, not on it. Visual only.
func _follow_hero() -> void:
	if stage != ON and stage != UNARMED:
		return
	var off: Vector3 = _pos[ON][icon]
	icon.global_position = Vector3(_hero_at.x, global_position.y, _hero_at.z) + off

func _on_tick() -> void:
	if not is_shown():
		return  # DAY only, and only while the building can branch (a Stone wall is never a cheap mid-night repair)
	var cost := GameState.branch_cost(spot_id)
	var took := GameState.pay_into_branch(spot_id, branch_id, Economy.drain_per_tick(cost, Balance.data.build))
	if took > 0:
		# A completing tick leaves a branch chosen: the next purchase would start counting again.
		_paid_ticks = PayFx.paid_tick(self, _fx, _paid_ticks, GameState.branch_of(spot_id) != &"", 0.3)

func _on_building_changed(id: StringName, _level: int, _paid: int) -> void:
	if String(id) == spot_id:
		refresh()

func _on_phase_changed(_phase: int, _day: int) -> void:
	refresh()

func _on_tier_changed(_tier: int, _paid: int, _boss_pending: bool) -> void:
	refresh()

## Rebuilds everything from GameState. Safe before the first new_game (buildings is empty then). A hidden pad does not process.
func refresh() -> void:
	var shown := is_shown() and is_inside_tree()  # a pad a rebuild took out of the tree is never shown
	if shown and not _was_shown:
		zone.disarm()  # D-121: a hero already standing here when the pad appears must leave and come back
		_shown_pads.append(self)
	elif _was_shown and not shown:
		_forget_shown(self)
	if shown != _was_shown:
		_cache_frame = -1
	_was_shown = shown
	body.visible = shown
	set_physics_process(shown)
	if GameState.can_branch(spot_id):
		_paid_seen = paid()
	elif GameState.branch_of(spot_id) == branch_id:
		_paid_seen = 0  # the chosen pad: nothing to refund
	if _paid_seen == 0:
		_paid_ticks = 0
	var cost := GameState.branch_cost(spot_id)
	if shown:
		cost_label.text = str(GameState.branch_remaining(spot_id, branch_id))
		if is_inside_tree():
			update_focus(get_tree())
		_apply_stage(_stage_now())
	else:
		preview.visible = false
		stage = FAR
		stage_changed.emit()
	zone.ring.visible = shown and _paid_seen > 0
	zone.ring.set_progress(float(_paid_seen) / float(cost) if shown and cost > 0 else 0.0)

# --- the refund (D-263.1) ----------------------------------------------------------------------------

## The other pad's partial payment went back to gold: coins fly from THIS pad to the hero, the exact amount on a "+N" label.
## A destroyed fence's dawn refund is shared by both of its pads, each flying what it held.
func _on_branch_refunded(id: StringName, _amount: int) -> void:
	if String(id) != spot_id or GameState.branch_of(spot_id) == branch_id:
		return
	var held := _paid_seen
	_paid_seen = 0
	if held <= 0:
		return
	last_refund = held
	refund_coins = mini(REFUND_COINS, held)
	_show_refund_label(held)
	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
	if _fx == null or hero == null:
		return
	_launch_coin(hero)
	if refund_coins > 1:
		if _coin_tween != null and _coin_tween.is_valid():
			_coin_tween.kill()
		_coin_tween = create_tween()
		for i in range(1, refund_coins):
			_coin_tween.tween_interval(REFUND_GAP)
			_coin_tween.tween_callback(_launch_coin.bind(hero))

func _launch_coin(hero: Node3D) -> void:
	if is_instance_valid(hero) and _fx != null:
		_fx.fly("coin", global_position + Vector3(0, 0.4, 0), hero.global_position + Vector3(0, 1.2, 0))

func _show_refund_label(amount: int) -> void:
	if _refund_tween != null and _refund_tween.is_valid():
		_refund_tween.kill()
	refund_label.text = "+%d" % amount
	refund_label.visible = true
	refund_label.position = Vector3(0, 1.0, 0)
	refund_label.modulate.a = 1.0
	_refund_tween = create_tween()
	_refund_tween.set_parallel(true)
	_refund_tween.tween_property(refund_label, "position:y", 1.0 + REFUND_LABEL_RISE, REFUND_LABEL_TIME)
	_refund_tween.tween_property(refund_label, "modulate:a", 0.0, REFUND_LABEL_TIME)
	_refund_tween.chain().tween_callback(func(): refund_label.visible = false)
