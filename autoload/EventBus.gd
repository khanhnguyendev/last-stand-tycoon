extends Node
## Cross-system signals only (D-037, D-109). Components talk to owners with local signals.

## PhaseController -> all. phase: Phase.NIGHT/DAWN/DAY, day: GameState.day.
signal phase_changed(phase: int, day: int)
## WaveDirector -> HUD. Emitted when the pre-wave delay (first delay or breather) starts.
signal wave_incoming(wave_index: int, main_lane: StringName, side_lane: StringName)
## WaveDirector -> all. side_lane is &"" when there is no side group.
signal wave_started(wave_index: int, main_lane: StringName, side_lane: StringName)
## WaveDirector -> HUD. The wave's last planned enemy has spawned.
signal wave_spawned_out(wave_index: int)
## WaveDirector -> PhaseController, HUD. All planned spawns spawned and none alive (D-044).
signal wave_cleared(wave_index: int)
## WaveDirector -> sims, HUD.
signal enemy_killed(spawn_index: int, lane: StringName, position: Vector3)
## GameState -> HUD, camera. hp_left after the hit.
signal diner_damaged(amount: float, hp_left: float)
## GameState -> PhaseController. Once per fall.
signal diner_fell()
## PhaseController -> HUD, sims.
signal night_failed(day: int)
## GameState -> every stateful node. GameState was replaced wholesale (new_game or from_dict).
signal state_restored()
## GameState -> HUD. delta may be negative.
signal gold_changed(gold: int, delta: int)
## GameState -> build spots, sign. Any level/paid/hp change.
signal building_changed(spot_id: StringName, level: int, paid: int)
## GameState -> fx. A level was completed.
signal build_completed(spot_id: StringName, level: int)
## GameState -> fx.
signal steak_picked(carried: int)
## GameState -> fx, sims.
signal steak_sold(count: int, gold: int)
## GameState -> stations, sign, carry stack. freezer/carried/counter/gold_pile changed; re-read GameState.
signal stocks_changed()
## CloseUpSign -> PhaseController.
signal closeup_requested()
## PhaseController -> HUD. Already translated text.
signal banner_requested(text: String)
## PhaseController -> Hero, CameraRig. Place the hero (new game, restore). Replaces a node call (D-128).
signal hero_place_requested(position: Vector2)
