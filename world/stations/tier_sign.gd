class_name TierSign
extends Node3D
## E5 spec 7.2: stand-still payment for the next diner tier. All state comes from GameState (tier_paid, boss_pending).
## Stands on the land it sells (MapLayout.TIER_SIGN). Hidden when this build has no next tier.

const SIGN_SCENE := preload("res://art/env/tier_sign.tscn")
const MARKER_SCENE := preload("res://art/env/spot_marker.tscn")
const LABEL_Y := 3.5  # clear of the gold star on the board top (E5 tier 3: a taller sign)

var label: WorldLabel
var zone: StationZone
var marker: Node3D
var _visual: Node3D
var _fx: FlyFx
var _paid_ticks := 0

func setup(world: World) -> void:
	name = "TierSign"
	_fx = world.fly_fx
	position = MapLayout.to3(MapLayout.TIER_SIGN)
	_visual = SIGN_SCENE.instantiate()
	add_child(_visual)
	label = WorldLabel.make("", Balance.ui.tier_sign_label_font)
	label.pixel_size = Balance.ui.tier_sign_label_pixel_size
	label.position = Vector3(0, LABEL_Y, 0)
	add_child(label)
	marker = MARKER_SCENE.instantiate()
	add_child(marker)
	zone = StationZone.new()
	zone.radius = MapLayout.STATION_RADIUS
	zone.drive_ring = false  # the ring shows paid / cost
	add_child(zone)
	zone.ticked.connect(_on_tick)
	# Named methods, not lambdas, and after the zone's own phase connection (it syncs its phase first).
	EventBus.tier_changed.connect(_on_tier_changed)
	EventBus.tier_reached.connect(_on_tier_reached)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.state_restored.connect(refresh)
	refresh()

func state() -> StringName:
	if GameState.tier_next_cost() < 0:
		return &"hidden"
	return &"boss" if GameState.boss_pending else &"selling"

func _on_tier_changed(_tier: int, _paid: int, _boss_pending: bool) -> void:
	refresh()

func _on_tier_reached(_tier: int) -> void:
	refresh()

func _on_phase_changed(_phase: int, _day: int) -> void:
	refresh()

## Runs on the zone's physics ticks (gameplay, D-118). The zone is active by day only.
func _on_tick() -> void:
	var cost := GameState.tier_next_cost()
	if cost < 0 or GameState.boss_pending:
		return
	var paid := GameState.pay_into_tier(Economy.drain_per_tick(cost, Balance.data.build))
	if paid > 0:
		_paid_ticks = PayFx.paid_tick(self, _fx, _paid_ticks, GameState.boss_pending, 1.0)

## Rebuilds everything from GameState. Safe before the first new_game (tier_next_cost is -1 then).
func refresh() -> void:
	var st := state()
	var day := zone != null and zone.is_active()
	visible = st != &"hidden"
	match st:
		&"hidden":
			label.text = ""
		&"boss":
			label.text = tr("Boss tonight")
		_:
			label.text = tr("Open the yards") + "\n" + str(GameState.tier_remaining_cost())
	label.visible = day and st != &"hidden"
	marker.visible = day and st == &"selling"
	if GameState.tier_paid == 0:
		_paid_ticks = 0
	if zone != null:
		var cost := GameState.tier_next_cost()
		var p := 0.0 if (cost <= 0 or st != &"selling") else float(GameState.tier_paid) / float(cost)
		zone.ring.visible = p > 0.0 and day
		zone.ring.set_progress(p)
