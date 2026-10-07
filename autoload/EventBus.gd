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
## WaveDirector -> sims, HUD (boss moon), audio, fx. kind: &"boar" | &"hare" | &"boss" | &"brute" | &"baron" (E5).
signal enemy_killed(spawn_index: int, lane: StringName, position: Vector3, kind: StringName)
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
## E5 tier 3: GameState -> Autosave (write). Listeners to come: world fx, HUD. A branch was paid in full and chosen at level 3.
signal branch_chosen(spot_id: StringName, branch_id: StringName)
## E5 tier 3: GameState -> none yet (the pad coin flight comes later). `amount` gold went back to the player: the other pad's
## partial payment when a branch was chosen, or the pads' payments of a fence destroyed at dawn.
signal branch_refunded(spot_id: StringName, amount: int)
## E1: a station's level or paid amount changed.
signal station_changed(id: StringName, level: int, paid: int)
## E1: a station finished a level (emitted after station_changed).
signal station_upgraded(id: StringName, level: int)
## E5: GameState -> World, TierSign, CloseUpSign (pulse), TelegraphMarker, Autosave (dirty). The sign's paid amount or the boss flag changed.
signal tier_changed(tier: int, paid: int, boss_pending: bool)
## E5: GameState -> Autosave (write), AudioDirector, Reactions, TierBot. The tier-up is paid in full; next_tier arrives after the boss.
signal tier_paid_up(next_tier: int)
## E5: GameState -> World (yards, spots, diner), TierReveal, TierSign, HUD (day label), Autosave, TierBot. Emitted after
## building_changed for each new spot, at the dawn after a won boss night.
signal tier_reached(tier: int)
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
## TierReveal -> CameraRig. A visual pull-back: ease to (focus, zoom) over in_s, hold, ease back to the hero over out_s (E5 spec 7.5). Never read by gameplay.
signal camera_reveal_requested(in_s: float, hold_s: float, out_s: float, zoom: float, focus: Vector2)

## PhaseController (via GameState) -> overlay, HUD, bots. The dawn offer, in display order.
signal card_offered(offer: Array)
## Overlay / bots -> PhaseController. A pick request; ignored unless it matches the open offer.
signal card_chosen(card_id: StringName)
## GameState -> Hero, guards, HUD. level is the card's new level.
signal card_picked(card_id: StringName, level: int)
## GameState -> guards. hp_left after the hit.
signal guard_damaged(guard_id: StringName, hp_left: float)
## GameState -> guards, sims. Once per knockout.
signal guard_knocked_out(guard_id: StringName)
## GameState -> guards. Back at full HP after the respawn timer.
signal guard_revived(guard_id: StringName)
## GameState -> guards. Dawn healed the guard to hp (spec 5.2: after phase_changed(DAWN)).
signal guard_healed(guard_id: StringName, hp: float)

## Any system -> AudioDirector. A local event wants a sound (S5 D-214). Never listened to by gameplay.
signal sfx_requested(id: StringName)
## Any system -> FxField. A local event wants a particle burst (S5 D-214). Never listened to by gameplay.
signal fx_requested(kind: StringName, position: Vector3)

## PhaseController -> Autosave. A new restore point was taken (new game, close-up, night-1 retry). Never mutate it.
signal snapshot_taken(snapshot: Dictionary)
