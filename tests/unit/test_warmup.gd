extends GutTest

var main: Main
var dir := ""

func before_each() -> void:
	Balance.reset()
	dir = "user://test_saves/wu_%d" % Time.get_ticks_usec()

func after_each() -> void:
	SaveStore.with_dir(dir).wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_saves"))

func _main() -> void:
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false

func _pool_sizes() -> Array:
	var w := main.world
	return [w.enemy_pool.size, w.steak_pool.size, w.projectile_pool.size, w.fx_pool.size, w.traveler_pool.size]

func test_run_builds_and_frees_without_touching_state() -> void:
	_main()
	var before := GameState.to_dict()
	var sizes := _pool_sizes()
	var warmup := Warmup.new()
	main.add_child(warmup)
	var fired := [false]
	warmup.finished.connect(func(): fired[0] = true)
	await warmup.run(main)
	assert_true(fired[0])
	assert_eq(GameState.to_dict(), before)
	assert_eq(_pool_sizes(), sizes)
	assert_eq(warmup.get_child_count(), 0)
	assert_gte(warmup.built_count, 9)

func test_boot_without_warmup_is_synchronous() -> void:
	_main()
	main.save_store = SaveStore.with_dir(dir)
	main.autosave.store = main.save_store
	assert_null(main.warmup)
	main._boot()
	assert_false(main.phase_controller.snapshot.is_empty())
	assert_ne(main.world.wave_director.state, WaveDirector.State.IDLE)

func test_music_track_follows_the_resume_phase() -> void:
	assert_eq(Warmup.music_for("NIGHT"), &"night")
	assert_eq(Warmup.music_for("DAY"), &"day")
	assert_eq(Warmup.music_for("CARD_PICK"), &"day")

func test_fade_material_is_a_transparent_copy() -> void:
	_main()
	var m := main.world.occluder_fade.fade_material_for_warmup()
	assert_not_null(m)
	assert_eq((m as BaseMaterial3D).transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
