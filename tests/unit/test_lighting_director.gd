extends GutTest
## S4 Task 13 (D-194): the warm day and the readable blue night. DAWN equals DAY (the card pick is a DAWN sub-state).

var _light: DirectionalLight3D
var _env: Environment
var _dir: LightingDirector

func before_each() -> void:
	Balance.reset()
	Balance.ui.lighting_tween_s = 0.1
	_light = DirectionalLight3D.new()
	add_child_autofree(_light)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_dir = LightingDirector.new()
	add_child_autofree(_dir)
	_dir.setup(_light, _env)

func after_each() -> void:
	Balance.reset()  # restores lighting_tween_s

## ambient + sun * energy * sin(55 deg): the light a flat ground receives, per channel (linear).
func _lit(t: Dictionary) -> Color:
	var amb: Color = (t.ambient as Color).srgb_to_linear()
	var sun: Color = (t.sun_color as Color).srgb_to_linear() * float(t.sun_energy) * sin(deg_to_rad(55.0))
	return Color(amb.r + sun.r, amb.g + sun.g, amb.b + sun.b)

func test_night_is_dimmer_than_day() -> void:
	var day := _lit(_dir.target_for(Phase.DAY))
	var night := _lit(_dir.target_for(Phase.NIGHT))
	assert_lte(night.get_luminance(), 0.7 * day.get_luminance(), "night reads as night")
	assert_lt(night.r, day.r)
	assert_lt(night.g, day.g)
	assert_gt(night.b, night.r, "a blue cast")

func test_night_sun_energy_is_lower() -> void:
	var day := _dir.target_for(Phase.DAY)
	var night := _dir.target_for(Phase.NIGHT)
	assert_lt(float(night.sun_energy), float(day.sun_energy))

func test_night_stays_readable() -> void:
	var night := _dir.target_for(Phase.NIGHT)
	var amb: Color = night.ambient
	assert_gt(amb.get_luminance(), 0.3, "a blue moonlight, not dark (R6)")
	assert_gt(amb.b, amb.r, "blue tint")
	assert_gt(float(night.sun_energy), 0.3)

func test_dawn_equals_day() -> void:
	assert_eq(_dir.target_for(Phase.DAWN), _dir.target_for(Phase.DAY))

func test_setup_applies_the_day_target() -> void:
	var day := _dir.target_for(Phase.DAY)
	assert_almost_eq(_light.light_energy, float(day.sun_energy), 0.001)
	assert_eq(_env.ambient_light_color, day.ambient)
	assert_eq(_env.background_color, day.bg)

func test_tween_reaches_the_night_target() -> void:
	EventBus.phase_changed.emit(Phase.DAY, 1)  # the first event snaps
	EventBus.phase_changed.emit(Phase.NIGHT, 1)
	assert_gt(_light.light_energy, float(_dir.target_for(Phase.NIGHT).sun_energy) + 0.05, "tweening, not snapped")
	await get_tree().create_timer(Balance.ui.lighting_tween_s + 0.1).timeout
	var night := _dir.target_for(Phase.NIGHT)
	assert_almost_eq(_light.light_energy, float(night.sun_energy), 0.01)
	assert_almost_eq(_light.light_color.b, (night.sun_color as Color).b, 0.01)
	assert_almost_eq(_env.ambient_light_color.b, (night.ambient as Color).b, 0.01)
	assert_almost_eq(_env.background_color.b, (night.bg as Color).b, 0.01)

func test_back_to_day_after_dawn() -> void:
	EventBus.phase_changed.emit(Phase.DAY, 1)
	EventBus.phase_changed.emit(Phase.NIGHT, 1)
	await get_tree().create_timer(Balance.ui.lighting_tween_s + 0.1).timeout
	EventBus.phase_changed.emit(Phase.DAWN, 1)
	await get_tree().create_timer(Balance.ui.lighting_tween_s + 0.1).timeout
	assert_almost_eq(_light.light_energy, float(_dir.target_for(Phase.DAY).sun_energy), 0.01)

func test_first_phase_snaps_when_resuming_into_night() -> void:
	Balance.ui.lighting_tween_s = 5.0
	var main: Main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(1)
	var text := FileAccess.get_file_as_string("res://export/fixtures/night3_start.save.json")
	var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)
	main.phase_controller.resume_from(r.state)
	await get_tree().process_frame
	var lighting := main.world.lighting
	assert_almost_eq(lighting._light.light_energy, float(lighting.target_for(Phase.NIGHT).sun_energy), 0.01)
