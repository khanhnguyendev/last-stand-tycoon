class_name PhaseController
extends Node
## Owns the phase, the snapshot and the dawn / close-up / fail steps (spec 5, D-043).
## The single architecture exception (D-110, D-128): it calls other systems directly, but ONLY through
## this narrow interface, via typed @export references assigned in world/main.tscn (never node-path
## lookups, never groups; test_phase_controller greps this file for them):
##   WaveDirector.start_night(plan), WaveDirector.stop()
##   NodePool.recall_all() -> int
##   TravelerSpawner.start(), stop(), clear_queue()
## The hero is placed with the bus event EventBus.hero_place_requested(position).

@export var wave_director: WaveDirector
@export var enemy_pool: NodePool
@export var steak_pool: NodePool
@export var projectile_pool: NodePool
@export var fx_pool: NodePool
@export var traveler_spawner: TravelerSpawner

var phase := Phase.NIGHT
var dawn_substate := ""
var snapshot: Dictionary = {}
var failing := false
## Bumped whenever a fail flow starts or is cancelled, so a stale fail timer never restores a snapshot.
var _fail_id := 0

func _ready() -> void:
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.diner_fell.connect(_on_diner_fell)
	EventBus.closeup_requested.connect(close_up)
	EventBus.card_chosen.connect(_on_card_chosen)

func start_new_game(seed: int = 0) -> void:
	failing = false
	_fail_id += 1
	dawn_substate = ""
	_recall_all()
	GameState.new_game(seed)
	snapshot = GameState.to_dict()
	snapshot.resume_phase = "NIGHT"
	EventBus.snapshot_taken.emit(snapshot)
	EventBus.hero_place_requested.emit(MapLayout.NIGHT1_START)  # D-126: combat comes to a new player
	EventBus.banner_requested.emit(tr("The monsters return"))
	_enter_night()

func close_up() -> void:
	if phase != Phase.DAY or failing:
		return
	GameState.collect_pile()
	_steaks_to_freezer()
	traveler_spawner.stop()
	snapshot = GameState.to_dict()
	snapshot.resume_phase = "DAY"
	EventBus.snapshot_taken.emit(snapshot)
	_enter_night()

func _enter_night() -> void:
	traveler_spawner.stop()
	phase = Phase.NIGHT
	EventBus.phase_changed.emit(phase, GameState.day)
	wave_director.start_night(GameState.lane_plan)

func _enter_day() -> void:
	phase = Phase.DAY
	EventBus.phase_changed.emit(phase, GameState.day)
	traveler_spawner.start()

func _on_wave_cleared(w: int) -> void:
	if phase != Phase.NIGHT or failing:
		return
	if w < GameState.lane_plan.size() - 1:
		return
	_run_dawn()

func _run_dawn() -> void:
	wave_director.stop()
	phase = Phase.DAWN
	EventBus.phase_changed.emit(phase, GameState.day)
	_steaks_to_freezer()                 # 1
	_recall_all()                        # projectiles (and later fx) in flight
	GameState.heal_for_dawn()            # 2
	GameState.reset_destroyed_fences()   # 3
	GameState.clear_night_fails()        # a cleared night resets mercy (S3 spec 6)
	GameState.advance_day()              # 4
	_card_pick()

## Spec 5.4 step 5 (S2 spec 5.1): offer the dawn cards and wait for EventBus.card_chosen.
func _card_pick() -> void:
	var offer := CardOffer.make(GameState.run_seed, GameState.day, GameState.cards, Balance.data.cards)
	if offer.is_empty():
		dawn_substate = ""
		EventBus.banner_requested.emit(tr("Dawn"))  # the pick overlay would hide it otherwise
		_enter_day()
		return
	dawn_substate = "CARD_PICK"
	GameState.set_card_offer(offer)

func _on_card_chosen(id: StringName) -> void:
	if phase != Phase.DAWN or dawn_substate != "CARD_PICK" or not GameState.card_offer.has(id):
		return
	var level := GameState.pick_card(id)
	dawn_substate = ""
	EventBus.banner_requested.emit(CardCatalog.pick_banner(id, level))
	_enter_day()

func _on_diner_fell() -> void:
	if phase != Phase.NIGHT or failing:
		return
	failing = true
	_fail_id += 1
	var fail_id := _fail_id
	wave_director.stop()
	EventBus.night_failed.emit(GameState.day)
	EventBus.banner_requested.emit(tr("The diner fell"))
	# A connected callback (not await): a freed controller never resumes. Timer is physics-time (D-118).
	get_tree().create_timer(Balance.ui.banner_time, false, true).timeout.connect(_on_fail_timer.bind(fail_id))

func _on_fail_timer(fail_id: int) -> void:
	if fail_id != _fail_id:
		return  # start_new_game() ran meanwhile
	_fail_restore()

## The one failure path (S3 spec 6, D-175): the restore point carries the new mercy count, a night-1 retry
## re-emits it (the save gets it), then the S1 restore contract, then the flavor line.
func _fail_restore() -> void:
	var fails := int(snapshot.get("night_fails", 0)) + 1
	snapshot.night_fails = fails
	if String(snapshot.resume_phase) == "NIGHT":
		EventBus.snapshot_taken.emit(snapshot)
	_restore_snapshot()
	EventBus.banner_requested.emit(tr("The monsters look tired tonight."))

func _restore_snapshot() -> void:
	wave_director.stop()  # a DAY restore never calls start_night(), which would drop the live boar list
	_recall_all()
	dawn_substate = ""
	GameState.from_dict(snapshot)
	var night_restart := String(snapshot.resume_phase) == "NIGHT"
	EventBus.hero_place_requested.emit(MapLayout.NIGHT1_START if night_restart else MapLayout.HOME)  # D-122, D-126
	failing = false
	if night_restart:
		EventBus.banner_requested.emit(tr("The monsters return"))  # spec 5.2: each night-1 restart
		_enter_night()
	else:
		_enter_day()

func _steaks_to_freezer() -> void:
	GameState.add_freezer(steak_pool.recall_all())

func _recall_all() -> void:
	enemy_pool.recall_all()
	steak_pool.recall_all()
	projectile_pool.recall_all()
	fx_pool.recall_all()
	traveler_spawner.clear_queue()

## Debug helpers (ui/debug hotkeys, tests). Same narrow interface.
## Skips the card pick without granting a card (S2 spec 5.1), from NIGHT or during CARD_PICK.
func debug_skip_to_day() -> void:
	if phase == Phase.NIGHT and not failing:
		_run_dawn()
	if phase == Phase.DAWN and dawn_substate == "CARD_PICK":
		GameState.clear_card_offer()
		dawn_substate = ""
		_enter_day()

func debug_skip_to_night() -> void:
	if phase == Phase.DAY:
		close_up()
