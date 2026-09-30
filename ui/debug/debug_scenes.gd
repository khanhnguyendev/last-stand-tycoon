extends RefCounted
## Debug-build URL scenes for simulator self-reviews (D-159). Loaded, never preloaded from release code.
## ?cards=archer:1,tank:2 grants cards; &scene=cardpick jumps to the dawn pick.
## ?cards= without scene=cardpick is lost on a night-1 fail restore.

static func parse(query: String) -> Dictionary:
	var out := {"cards": {}, "scene": ""}
	for pair in query.trim_prefix("?").split("&", false):
		var kv := pair.split("=", true, 1)
		if kv.size() != 2:
			continue
		if kv[0] == "scene":
			out.scene = kv[1]
		elif kv[0] == "cards":
			for item in kv[1].uri_decode().split(",", false):
				var il := item.split(":", true, 1)
				if il.size() == 2 and StringName(il[0]) in CardCatalog.IDS and il[1].is_valid_int():
					# clamp: release builds strip pick_card's max-level assert (S2 Task 4 review)
					out.cards[StringName(il[0])] = clampi(int(il[1]), 0, Balance.data.cards.max_level)
	return out

## True when the query carries a key that asks for a fresh start (whole keys, not substrings).
static func has_fresh_start_key(query: String) -> bool:
	for pair in query.trim_prefix("?").split("&", false):
		if pair.split("=", true, 1)[0] in ["scene", "cards", "reset"]:
			return true
	return false

static func apply(main, q: Dictionary) -> void:
	for id in CardCatalog.IDS:
		for i in int(q.cards.get(id, 0)):
			GameState.debug_grant_card(id)
	if q.scene == "cardpick" and main.phase_controller.phase == Phase.NIGHT:
		EventBus.wave_cleared.emit(GameState.lane_plan.size() - 1)
