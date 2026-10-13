extends SceneTree
## The branch card (E6 Task 13, spec 5.2). Run WITH rendering (not --headless):
##   "$GODOT" --path . --resolution 720x1280 -s res://tools/shot_branch_card.gd -- --out=docs/review/media/e6/interface
## Seed 1 (SIEGE east, HARE west, north and south-west neutral), the retune flag on, tier 3 forced, all nine buildings at level 3.
## The hero WALKS onto a pad (a teleport would leave the pad unarmed and the card hidden). Writes, each 720x1280 plus a _40 copy:
##   card_longbow (tower_nw: west road with the hare icon, north path with none: a two-lane tower), card_volley (tower_w: hare lane),
##   card_stone (fence_e: siege lane), card_spike (fence_n: neutral lane), card_partial (tower_ne Volley, 200 of 500 paid),
##   card_vietnamese (fence_w Stone wall with the Vietnamese sample).
## The world labels above the hero (name, effect, warning) are still there: a later task removes them behind the flag.

var _out := "docs/review/media/e6/interface"
var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	var bal = root.get_node("Balance")
	var gs = root.get_node("GameState")
	var camera_math = load("res://core/camera_math.gd")
	var layout = load("res://core/map_layout.gd")
	bal.reset()
	bal.ui.shake_enabled = false
	bal.data.tiers.retune_enabled = true
	if bal.data.tiers.tier_costs.size() < 3:
		bal.data.tiers.tier_costs.append(1500)  # the shot forces tier 3
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	main.focus_pause.free()
	paused = false
	main.phase_controller.start_new_game(1)
	main.hero.input.player_control = false
	for i in 90:
		await physics_frame
	var dbg = main.get_node_or_null("DebugOverlay")
	if dbg != null:
		dbg.visible = false
	main.phase_controller.debug_skip_to_day()
	for i in 60:
		await physics_frame
	main.world.wave_director.stop()
	gs.debug_set_tier(3, 6)
	for i in 30:
		await physics_frame
	gs.gold = 100000
	for id in layout.spots_for_tier(3):
		while gs.next_level_cost(id) >= 0:
			gs.pay_into_spot(id, 100000)
	gs.gold = 0
	for i in 30:
		await physics_frame
	print("lane character: ", gs.lane_character())
	await _card(main, camera_math, layout, "card_longbow", "tower_nw", 0, &"longbow")
	await _card(main, camera_math, layout, "card_volley", "tower_w", 1, &"volley")
	await _card(main, camera_math, layout, "card_stone", "fence_e", 0, &"stone")
	await _card(main, camera_math, layout, "card_spike", "fence_n", 1, &"spike")
	gs.gold = 200
	gs.pay_into_branch("tower_ne", &"volley", 200)
	gs.gold = 0
	await _card(main, camera_math, layout, "card_partial", "tower_ne", 1, &"volley")
	# the Vietnamese sample through a real Translation, the way a locale would arrive
	var vi := Translation.new()
	vi.locale = "vi"
	for k in {"Stone wall": "Tường đá", "holds brutes": "chặn quái nặng", "west road": "đường phía tây", "lost if broken": "mất nếu bị phá"}:
		vi.add_message(k, {"Stone wall": "Tường đá", "holds brutes": "chặn quái nặng", "west road": "đường phía tây", "lost if broken": "mất nếu bị phá"}[k])
	TranslationServer.add_translation(vi)
	TranslationServer.set_locale("vi")
	await _card(main, camera_math, layout, "card_vietnamese", "fence_w", 0, &"stone", "Tường đá")
	TranslationServer.set_locale("en")
	TranslationServer.remove_translation(vi)
	quit(1 if _failed else 0)

## Fails (exit 1) unless the card on screen is the one for `spot` and `branch` (and, if given, its name reads `name_text`).
func _card(main, camera_math, layout, name: String, spot: String, idx: int, branch: StringName, name_text := "") -> void:
	if _failed:
		return
	var p: Vector2 = layout.branch_pad(spot, idx, true)  # the flag is on here: a moved pad (E6 Task 14)
	main.hero.teleport(p + Vector2(0, 2.0))
	for i in 5:
		await physics_frame
	var step: float = main.hero.move_speed() / 60.0
	for i in 600:
		var d: Vector2 = p - main.hero.xz()
		if d.length() < 0.02:
			break
		main.hero.input.set_move((d / step).limit_length(1.0))
		await physics_frame
	main.hero.input.set_move(Vector2.ZERO)
	for i in 30:
		main.hero.input.set_move(Vector2(0.3, 0.0) if (i / 6) % 2 == 0 else Vector2(-0.3, 0.0))
		await physics_frame
	main.hero.input.set_move(Vector2.ZERO)
	var card = main.hud.branch_card
	var gs = root.get_node("GameState")
	gs.gold = 0
	gs.add_gold(340)  # (through the API so the HUD shows it) a purse that is plausible but never enough to move the bar: the hero shuffles so the pad takes nothing
	main.camera_rig.snap_to(camera_math.focus_for(p))
	for i in 90:
		main.hero.input.set_move(Vector2(0.3, 0.0) if (i / 6) % 2 == 0 else Vector2(-0.3, 0.0))
		await physics_frame
	main.hero.input.set_move(Vector2.ZERO)
	await process_frame
	print(name, ": card visible ", card.visible, " rect ", card.get_global_rect(), " armed ", main.hero.global_position)
	var bad := ""
	if not card.visible:
		bad = "the card is hidden"
	elif card.spot_id != spot or card.branch_id != branch:
		bad = "the card is for %s / %s" % [card.spot_id, card.branch_id]
	elif name_text != "" and card.name_label.text != name_text:
		bad = "the card's name reads '%s'" % card.name_label.text
	if bad != "":
		printerr("SHOT FAILED: %s must show the card of %s (%s), but %s (hero at %s)" % [name, spot, branch, bad, main.hero.xz()])
		_failed = true
		quit(1)
		return
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	var small := img.duplicate()
	small.resize(288, 512, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(name + "_40.png"))
