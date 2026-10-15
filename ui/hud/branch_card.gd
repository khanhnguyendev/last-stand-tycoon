class_name BranchCard
extends Control
## E6 Task 13 (spec 5.2, D-284, D-289): the branch card. While the hero stands on an ARMED branch pad (the pad is shown, the
## zone is armed: he walked in) and the run has a lane character (tier 3), a 640 x 222 card sits at the
## bottom of the HUD, 24 px above the safe inset, and tells the player what the pad sells:
##   row 1  branch icon and name                      (left, top line)
##   row 4  payment bar (paid / cost) and the REMAINING cost as the number   (right, top line)
##   row 2  the specialty (at most 3 words) with its lane-character icon     (left, middle line)
##   row 5  fences only: broken-fence icon and "lost if broken"              (right, middle line)
##   row 6  E8 (spec 3.4): the weakness (at most 3 words) with the icon of the kind it is weak to  (left, third line)
##   row 3  the guarded lane(s), each with its lane-character icon (none if neutral)  (full width, bottom line)
## The rows are numbered as in the spec; they are laid out in four lines (222 px) because six stacked 40 px icons do not fit.
## It is a listener: it reads BranchPad's static focus helpers and GameState, writes nothing, and every Control in it ignores the
## mouse, so a joystick touch may start on it. With no lane character (below tier 3) it stays hidden: while no
## armed pad is under the hero _process does one lookup and returns, and on a pad it asks GameState for the (empty) character
## and hides. It never writes game state, so it cannot change behaviour. The character is read once per shown pad (and again
## after a tier change or a load), not every frame.
## Every string goes through tr(); the card re-reads them on NOTIFICATION_TRANSLATION_CHANGED.
##
## TEXT FIT RULE: every label has one line and a fixed width. Its font starts at the row's maximum and shrinks one pixel at a
## time to the row's floor (name 32 -> 30, other text 24 .. 28, never below 24 on the 720 base) until the text fits. If it does
## not fit even at the floor the label trims with an ellipsis (`overflowing()` reports it; the tests assert it never happens
## for the pseudo-locale and the Vietnamese sample). Row 3 shrinks its entries together so both lanes use one size.

const CARD_SIZE := Vector2(640, 222)
const BOTTOM_GAP := 24.0
const MARGIN_X := 8.0
const MARGIN_Y := 11.0
const ROW_H := 44.0
const ROW_GAP := 8.0
const ICON_PX := 44.0
const ICON_GAP := 6.0
const LEFT_W := 318.0
const COL_GAP := 8.0
const NAME_MAX := 32
const NAME_MIN := 30
const TEXT_MAX := 28
const TEXT_MIN := 24
const BAR_W := 150.0
const BAR_H := 22.0
const LANE_GAP := 36.0
const OUTLINE_PX := 4
const TEX_PX := 96

static var _tex := {}
## Icons rasterized so far (a first show after the warm-up must not add to it).
static var rasterized := 0

## What the card shows now: "" when hidden.
var spot_id := ""
var branch_id: StringName = &""
var name_label: Label
var name_icon: TextureRect
var spec_label: Label
var spec_icon: TextureRect
var lane_icons: Array[TextureRect] = []
var lane_labels: Array[Label] = []
var bar_back: ColorRect
var bar_fill: ColorRect
var cost_label: Label
var warn_icon: TextureRect
var warn_label: Label
var weak_icon: TextureRect
var weak_label: Label

var _key := ""
var _shown_remaining := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -CARD_SIZE.x * 0.5
	offset_right = CARD_SIZE.x * 0.5
	offset_top = -(CARD_SIZE.y + BOTTOM_GAP)
	offset_bottom = -BOTTOM_GAP
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	visible = false
	EventBus.tier_changed.connect(func(_t: int, _p: int, _b: bool): _key = "")
	EventBus.state_restored.connect(func(): _key = "")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_key = ""  # the next refresh rebuilds every string from tr()

func _process(_delta: float) -> void:
	refresh()

## The pad the hero stands on when it is shown and armed (he walked in); else null.
func _armed_pad() -> BranchPad:
	var pad := BranchPad.pad_hero_stands_on()
	if pad == null or not is_instance_valid(pad) or not pad.is_inside_tree() or pad.zone == null:
		return null
	if not pad.is_shown() or not pad.zone.armed:
		return null
	return pad

## Syncs the card with the game (called every frame; tests call it too). Visual only.
func refresh() -> void:
	var pad := _armed_pad()
	if pad == null:
		_hide()
		return
	var key := "%s:%s" % [pad.spot_id, pad.branch_id]
	if key != _key:  # the character is read once per shown pad, not every frame
		var character := GameState.lane_character()
		if character.is_empty():
			_hide()
			return
		_key = key
		_build(pad.spot_id, pad.branch_id, character)
	visible = true
	var remaining := GameState.branch_remaining(spot_id, branch_id)
	if remaining >= 0:
		_set_payment(GameState.branch_cost(spot_id), remaining)

func _hide() -> void:
	visible = false
	spot_id = ""
	branch_id = &""
	_key = ""

# --- content -----------------------------------------------------------------------------------------

func branch_name(id: StringName) -> String:
	match id:
		&"longbow": return tr("Longbow")
		&"volley": return tr("Volley")
		&"stone": return tr("Stone wall")
		&"spike": return tr("Spike fence")
		_: return ""

## The specialty line, at most three words.
func specialty(id: StringName) -> String:
	match id:
		&"longbow": return tr("breaks brutes")
		&"volley": return tr("hits %d targets") % int(Balance.data.branches.tower(&"volley").count)
		&"stone": return tr("holds brutes")
		&"spike": return tr("hurts hares")
		_: return ""

## The character the specialty answers: siege for Longbow and Stone wall, hare for Volley and Spike fence.
static func specialty_kind(id: StringName) -> StringName:
	match id:
		&"longbow", &"stone": return LaneCharacterIcons.SIEGE
		&"volley", &"spike": return LaneCharacterIcons.HARE
		_: return &""

## E8 (spec 3.4): what the branch is weak to, at most three words.
func weakness(id: StringName) -> String:
	match id:
		&"longbow": return tr("weak to hares")
		&"volley": return tr("weak to brutes")
		&"spike": return tr("brutes smash it")
		&"stone": return tr("useless on hares")
		_: return ""

## The kind the weakness names, as the card draws kinds everywhere (a brute is the siege ram, a hare the hare head).
static func weakness_kind(id: StringName) -> StringName:
	match id:
		&"longbow", &"stone": return LaneCharacterIcons.HARE
		&"volley", &"spike": return LaneCharacterIcons.SIEGE
		_: return &""

func lane_name(lane: String) -> String:
	match lane:
		"west": return tr("west road")
		"north": return tr("north path")
		"east": return tr("east road")
		"sw": return tr("south road")
		_: return ""

## The lanes the building guards: a tower's own, a fence's single lane.
static func guarded_lanes(spot: String) -> Array:
	return MapLayout.tower_lanes(spot) if MapLayout.spot_kind(spot) == "tower" else [MapLayout.fence_lane(spot)]

## &"siege", &"hare" or &"" (neutral) for a lane.
static func lane_icon_kind(character: Dictionary, lane: String) -> StringName:
	var t := LaneCharacter.lane_type(character, lane)
	return t if t == LaneCharacter.SIEGE or t == LaneCharacter.HARE else &""

# --- build -------------------------------------------------------------------------------------------

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	lane_icons.clear()
	lane_labels.clear()
	name_label = null
	name_icon = null
	spec_label = null
	spec_icon = null
	bar_back = null
	bar_fill = null
	cost_label = null
	warn_icon = null
	warn_label = null
	weak_icon = null
	weak_label = null

func _build(p_spot: String, p_branch: StringName, character: Dictionary) -> void:
	_clear()
	spot_id = p_spot
	branch_id = p_branch
	_shown_remaining = -1
	var backing := Panel.new()
	backing.name = "Backing"
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.color(&"night_sky")
	sb.bg_color.a = 0.9
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(3)
	sb.border_color = Palette.color(&"ink")
	backing.add_theme_stylebox_override("panel", sb)
	backing.size = CARD_SIZE
	add_child(backing)
	size = CARD_SIZE
	var y1 := MARGIN_Y
	var y2 := MARGIN_Y + ROW_H + ROW_GAP
	var y3 := MARGIN_Y + 2.0 * (ROW_H + ROW_GAP)  # row 6, the weakness
	var y4 := MARGIN_Y + 3.0 * (ROW_H + ROW_GAP)  # row 3, the guarded lanes
	var xr := MARGIN_X + LEFT_W + COL_GAP
	var right_w := CARD_SIZE.x - MARGIN_X - xr
	# row 1: branch icon and name
	name_icon = _icon("NameIcon", branch_texture(p_branch), Vector2(MARGIN_X, y1))
	name_label = _fit_label("Name", branch_name(p_branch), Vector2(MARGIN_X + ICON_PX + ICON_GAP, y1),
		LEFT_W - ICON_PX - ICON_GAP, NAME_MAX, NAME_MIN)
	# row 2: the specialty with its character icon
	spec_icon = _icon("SpecIcon", LaneCharacterIcons.texture(specialty_kind(p_branch)), Vector2(MARGIN_X, y2))
	spec_label = _fit_label("Spec", specialty(p_branch), Vector2(MARGIN_X + ICON_PX + ICON_GAP, y2),
		LEFT_W - ICON_PX - ICON_GAP, TEXT_MAX, TEXT_MIN)
	# row 4: the payment bar and the remaining number
	var bar_y := y1 + (ROW_H - BAR_H) * 0.5
	bar_back = ColorRect.new()
	bar_back.name = "BarBack"
	bar_back.color = Palette.color(&"ink")
	bar_back.position = Vector2(xr, bar_y)
	bar_back.size = Vector2(BAR_W, BAR_H)
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_back)
	var track := ColorRect.new()  # the empty part, light enough to read on the dark card
	track.name = "BarTrack"
	track.color = Palette.color(&"traveler_grey")
	track.position = bar_back.position + Vector2(3, 3)
	track.size = Vector2(BAR_W - 6.0, BAR_H - 6.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	bar_fill = ColorRect.new()
	bar_fill.name = "BarFill"
	bar_fill.color = Palette.color(&"gold")
	bar_fill.position = bar_back.position + Vector2(3, 3)
	bar_fill.size = Vector2(0, BAR_H - 6.0)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_fill)
	cost_label = _fit_label("Cost", "0", Vector2(xr + BAR_W + ICON_GAP, y1), right_w - BAR_W - ICON_GAP, NAME_MAX, TEXT_MIN)
	# row 5: fences only
	if Balance.data.branches.is_fence_branch(p_branch):
		warn_icon = _icon("WarnIcon", branch_texture(&"broken"), Vector2(xr, y2))
		warn_label = _fit_label("Warn", tr("lost if broken"), Vector2(xr + ICON_PX + ICON_GAP, y2),
			right_w - ICON_PX - ICON_GAP, TEXT_MAX, TEXT_MIN)
	# row 6: the weakness, with the icon of the kind it is weak to
	weak_icon = _icon("WeakIcon", LaneCharacterIcons.texture(weakness_kind(p_branch)), Vector2(MARGIN_X, y3))
	# (it starts in the left column; the right column of this line is empty, so a longer translation may run on into it)
	weak_label = _fit_label("Weak", weakness(p_branch), Vector2(MARGIN_X + ICON_PX + ICON_GAP, y3),
		CARD_SIZE.x - 2.0 * MARGIN_X - ICON_PX - ICON_GAP, TEXT_MAX, TEXT_MIN)
	# row 3: the guarded lanes
	_build_lanes(guarded_lanes(p_spot), character, y4)

func _build_lanes(lanes: Array, character: Dictionary, y: float) -> void:
	var avail := CARD_SIZE.x - 2.0 * MARGIN_X
	var texts: Array[String] = []
	var kinds: Array[StringName] = []
	for lane in lanes:
		texts.append(lane_name(String(lane)))
		kinds.append(lane_icon_kind(character, String(lane)))
	# Every entry is [icon slot][text]: a neutral lane leaves its slot blank, so the text always starts in the text column and an
	# icon always sits left of the name it belongs to. One size for all entries: the largest that fits the whole row, else the floor.
	var probe := _probe_label()
	var font := probe.get_theme_font(&"font")
	var fixed := LANE_GAP * float(lanes.size() - 1) + (ICON_PX + ICON_GAP) * float(lanes.size())
	var fs := TEXT_MIN
	for s in range(TEXT_MAX, TEXT_MIN - 1, -1):
		var w := fixed
		for t in texts:
			w += _text_w(font, t, s)
		if w <= avail:
			fs = s
			break
	remove_child(probe)
	probe.queue_free()
	var x := MARGIN_X
	var share := (avail - fixed) / float(maxi(lanes.size(), 1))
	for i in lanes.size():
		if kinds[i] != &"":
			lane_icons.append(_icon("LaneIcon%d" % i, LaneCharacterIcons.texture(kinds[i]), Vector2(x, y)))
		else:
			lane_icons.append(null)
		x += ICON_PX + ICON_GAP
		var tw := _text_w(font, texts[i], fs)
		var lw := tw if tw <= share else share
		lane_labels.append(_label("Lane%d" % i, texts[i], fs, Vector2(x, y), lw))
		x += lw + LANE_GAP

func _probe_label() -> Label:
	var l := Label.new()
	l.theme_type_variation = &"BannerLabel"
	add_child(l)
	return l

## Text width in px at `size`, plus the outline on both sides, rounded up.
static func _text_w(font: Font, text: String, size: int) -> float:
	return ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) + float(OUTLINE_PX)

func _icon(node_name: String, tex: Texture2D, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.name = node_name
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.position = pos
	r.size = Vector2(ICON_PX, ICON_PX)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _label(node_name: String, text: String, font_size: int, pos: Vector2, width: float) -> Label:
	var l := Label.new()
	l.name = node_name
	l.theme_type_variation = &"BannerLabel"
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", OUTLINE_PX)
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	l.size = Vector2(width, ROW_H)
	add_child(l)
	return l

## A one-line label whose font is the largest in [min_size, max_size] that fits `width`.
func _fit_label(node_name: String, text: String, pos: Vector2, width: float, max_size: int, min_size: int) -> Label:
	var l := _label(node_name, text, max_size, pos, width)
	var font := l.get_theme_font(&"font")
	var fs := min_size
	for s in range(max_size, min_size - 1, -1):
		if _text_w(font, text, s) <= width:
			fs = s
			break
	l.add_theme_font_size_override("font_size", fs)
	return l

func _set_payment(cost: int, remaining: int) -> void:
	if remaining == _shown_remaining:
		return
	_shown_remaining = remaining
	var ratio := clampf(float(cost - remaining) / float(maxi(cost, 1)), 0.0, 1.0)
	bar_fill.size.x = (BAR_W - 6.0) * ratio
	cost_label.text = str(remaining)

# --- for tests ---------------------------------------------------------------------------------------

func all_labels() -> Array[Label]:
	var out: Array[Label] = []
	for c in get_children():
		if c is Label:
			out.append(c)
	return out

## Every Control the card owns, itself included.
func all_controls() -> Array[Control]:
	var out: Array[Control] = [self]
	for c in find_children("*", "Control", true, false):
		out.append(c as Control)
	return out

# --- icons -------------------------------------------------------------------------------------------

## A branch glyph (BranchIcons.layers) rasterized for the HUD: ink outline under every fill, like the world mesh.
static func branch_texture(kind: StringName) -> ImageTexture:
	if _tex.has(kind):
		return _tex[kind]
	rasterized += 1
	var ls := BranchIcons.layers(kind)
	var outs: Array = []
	for l in ls:
		var best := PackedVector2Array()
		for q in Geometry2D.offset_polygon(l[0], BranchIcons.OUTLINE, Geometry2D.JOIN_ROUND):
			if q.size() > best.size():
				best = q
		outs.append(best)
	var img := Image.create(TEX_PX, TEX_PX, false, Image.FORMAT_RGBA8)
	var ink := Palette.color(&"ink")
	for y in TEX_PX:
		for x in TEX_PX:
			var p := Vector2((float(x) + 0.5) / float(TEX_PX) - 0.5, 0.5 - (float(y) + 0.5) / float(TEX_PX))
			var c := Color(0, 0, 0, 0)
			var hit := false
			for i in range(ls.size() - 1, -1, -1):
				if Geometry2D.is_point_in_polygon(p, ls[i][0]):
					c = Palette.color(ls[i][1])
					hit = true
					break
			if not hit:
				for g in outs:
					if Geometry2D.is_point_in_polygon(p, g):
						c = ink
						break
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex[kind] = tex
	return tex

## Rasterizes every icon the card draws (the warm-up calls this behind the retune accessor, so the first show costs nothing).
static func prebuild_textures() -> void:
	for kind in BranchIcons.KINDS:
		branch_texture(kind)
	for kind in LaneCharacterIcons.KINDS:
		LaneCharacterIcons.texture(kind)
