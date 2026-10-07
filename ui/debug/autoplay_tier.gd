extends TierBot
## Debug-build self-play that also buys tiers and branches (E5 tier-3 checkpoint recordings): ?autoplay=tier attaches this bot to Main,
## ?policy=all_a|all_b|mixed|threat|volley_stone picks its branch policy (default threat). Same card-pick delay as autoplay.gd
## (the pick screen stays up long enough to film), first card offered. Drives the hero only through HeroInput. Never loaded by
## release code except through debug_overlay's load(); ui/debug/ is excluded from release/profile exports.

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
