extends PlannerBot
## Debug-build self-play for unattended recordings (final review, gameplay video): ?autoplay=1 attaches this bot to Main.
## PlannerBot's night/day behaviour; the dawn card is picked the PICK_DELAY_S after the offer (so the pick screen is on
## screen long enough to film), taking the first card offered. Drives the hero only through HeroInput. Never loaded
## by release code except through debug_overlay's load(); ui/debug/ is excluded from release/profile exports.

const PICK_DELAY_S := 3.0

var _pick_wait := 0.0

func choose_card(offer: Array) -> StringName:
	return offer[0]

func _physics_process(delta: float) -> void:
	if main == null:
		return
	if not _pending_offer.is_empty():
		_pick_wait += delta
		if _pick_wait >= PICK_DELAY_S:
			var pick := choose_card(_pending_offer)
			_pending_offer = []
			_pick_wait = 0.0
			EventBus.card_chosen.emit(pick)
	else:
		_pick_wait = 0.0
	think(delta)
	_steer()
