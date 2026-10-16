extends Node
## E6 phase 4 study runner (see study_first_t3.gd). One REAL tier-bot run on the shipped game, replayed with extra READ-ONLY logging; it changes no balance
## value and no production file. Arguments (after `--`): --seed=N --policy=<tier bot policy> --days=N --force=none|first|all --out=<file under tests/sim/out/study/>.
## --force (Q6, in memory only): `first` = the FIRST branch bought is a Longbow on the first tower (spots order) that covers the run's siege lane; `all` = Longbow on EVERY
## tower covering the siege lane before any other branch. Everything after that is the threat rule unchanged. The bot waits (buys no other branch) until it can pay.
## Output lines (stdout, one fact per line, parsed by hand into docs/review/media/e6/study_first_t3.md):
##   RUN, ROW, GOAL, BUY, STATE, PLAN, NIGHT_BEGIN, NIGHT_END, SPAWN, DMG, FENCE_FALL, FENCE_HP, SHOTS, SRC, BOT.
## Phase-4 round-2 additions (all in memory, study runner only): --interval=<s> sets the Longbow interval; --variant=<letters> changes the threat bot's branch choice
## (b: a tower that covers the hare lane takes Volley even if it also covers the siege lane; c: purchase order first ONE siege-lane tower, then the hare-lane towers, then the
## other siege-lane towers); --pin=<lane>:<from_s>:<row> pins the hero's night lane choice to <lane> from <from_s> seconds after the night of row <row> starts to the end of that night (attempt 1 and retries).
## --far=1 (D-304 what-if 3) is SHIPPED since D-310 (TierBot._pick_lane, keep_own_lane); the branch below is kept only to reproduce the D-305 rows, which ran on the old bot:
## add --oldbot=1 (sets TierBot.rule = "old", the bot without any D-310 / escalation-16 rule) to every such run. Without --oldbot=1 every run here plays the shipped (walk-time) rule. (The RUN line does not print oldbot, so the old rows stay byte-comparable.)
## No global rand call is made here (the unit suite bans them).

const DELTA := 1.0 / 60.0

## Q6: the threat policy with a forced start. Overrides ONE method of the shipped bot; nothing else.
class ForcedBot extends TierBot:
	var force := "none"
	var variant := ""
	var pin_lane := ""
	var pin_active := Callable()  # () -> bool, set by the runner (the night clock lives there)
	## Round 2 (b, c): the shipped _next_branch_pad with the choice (b) and/or the order (c) changed. Same affordability rule, same blocked-pad handling.
	func _variant_pad() -> String:
		if GameState.tier < 3:
			return ""
		var spots := MapLayout.spots_for_tier(GameState.tier)
		if _blocked_day != GameState.day:
			_blocked_day = GameState.day
			_blocked_pads.clear()
		if policy == "unbranched":
			return ""
		var character := GameState.lane_character()
		var choices := TierBot.branch_choices(policy, spots, GameState.lane_plan, GameState.tier, character)
		var siege := String(character.get("siege", ""))
		var hare := String(character.get("hare", ""))
		if "b" in variant:
			for id in spots:
				if MapLayout.spot_kind(id) == "tower" and hare in MapLayout.tower_lanes(id):
					choices[id] = BranchBalance.TOWER_BRANCHES[1]
		if policy == "threat" and not character.is_empty():
			var order: Array = TierBot.marked_lane_order(spots, character)
			if "c" in variant:
				var g0: Array = order.filter(func(i): return MapLayout.spot_kind(i) == "tower" and siege in MapLayout.tower_lanes(i))
				var g1: Array = order.filter(func(i): return MapLayout.spot_kind(i) == "tower" and not (siege in MapLayout.tower_lanes(i)) and hare in MapLayout.tower_lanes(i))
				var head: Array = []
				if not g0.is_empty():
					head.append(g0[0])
				head.append_array(g1)
				head.append_array(g0.slice(1))
				var rest: Array = order.filter(func(i): return not i in head)
				order = head + rest
			spots.assign(order)
		for id in spots:
			if not GameState.can_branch(id):
				continue
			var pad := TierBot.pad_goal(id, choices[id])
			if not graph.nodes.has(pad):
				skipped_goals += 1
				continue
			if _blocked_pads.has(pad):
				continue
			if GameState.branch_remaining(id, choices[id]) <= GameState.gold:
				return pad
		return ""
	## Q4 (the hero pin): NaiveBot._night with the lane choice replaced by pin_lane while pin_active returns true. The 1 s decision timer, the stay-if-in-range rule and
	## the go_to are the shipped ones; only `best` differs.
	func _night(delta: float) -> void:
		if pin_lane == "" or not pin_active.is_valid() or not pin_active.call():
			super(delta)
			return
		_decide_timer -= delta
		if _decide_timer > 0.0:
			return
		_decide_timer = 1.0
		var r := Balance.data.hero.attack_range
		for c in main.world.wave_director.enemy_candidates():
			var p: Vector3 = c.position
			if Vector2(p.x, p.z).distance_to(hero.xz()) <= r:
				return
		if graph.nodes.has("zone_" + pin_lane):
			go_to("zone_" + pin_lane)
	## What-if (D-304, the seed-14 diagnosis): the hero keeps the lane of its current zone goal while that lane has live enemies, unless another lane has MORE
	## breaching enemies than its own lane has live ones. Otherwise the shipped rule.
	var hold := false
	var commit := false
	var far := false
	func _pick_lane(lanes: Array, counts: Dictionary, wd: WaveDirector) -> String:
		if commit and not GameState.lane_character().is_empty() and goal.begins_with("zone_") and not arrived():
			return goal.trim_prefix("zone_")  # what-if 2: finish the walk before choosing again
		var picked := super(lanes, counts, wd)
		if far and not GameState.lane_character().is_empty() and goal.begins_with("zone_") and picked != "":
			var mine := goal.trim_prefix("zone_")  # what-if 3: no walk to the other side of the diner while the own lane has monsters
			if counts.has(mine) and int(counts[mine]) > 0 and graph.position_of(goal).distance_to(graph.position_of("zone_" + picked)) > 9.0:
				return mine
		if not hold or GameState.lane_character().is_empty() or not goal.begins_with("zone_"):
			return picked
		var own := goal.trim_prefix("zone_")
		if not counts.has(own) or int(counts[own]) == 0 or picked == own:
			return picked
		var breached := 0
		for b in wd.alive_enemies():
			if String(b.lane) != picked:
				continue
			var walks_past: bool = not (b.stats().priority as Array).has(&"fence_on_lane")
			if TierBot.enemy_breached(picked, float(b.dist), float(b.stats().reach), TargetProviders.fence_stop_dist(b) < INF, walks_past):
				breached += 1
		return picked if breached > int(counts[own]) else own
	func _siege_towers() -> Array:
		var siege := String(GameState.lane_character().get("siege", ""))
		var out: Array = []
		for id in MapLayout.spots_for_tier(GameState.tier):
			if MapLayout.spot_kind(id) == "tower" and siege in MapLayout.tower_lanes(id):
				out.append(id)
		return out
	func _any_branch() -> bool:
		for id in GameState.buildings:
			if String(GameState.buildings[id].branch) != "":
				return true
		return false
	func _next_branch_pad() -> String:
		if variant != "" and force == "none":
			return _variant_pad()
		if force == "none" or GameState.tier < 3:
			return super()
		var towers := _siege_towers()
		var pending: Array = towers.filter(func(id): return GameState.can_branch(id))
		var stage: bool = (force == "first" and not _any_branch() and not pending.is_empty()) or (force == "all" and not pending.is_empty())
		if not stage:
			return super()
		for id in pending:
			var pad := TierBot.pad_goal(id, &"longbow")
			if not graph.nodes.has(pad):
				continue
			if GameState.branch_remaining(id, &"longbow") <= GameState.gold:
				return pad
		return ""  # wait until a siege tower's Longbow can be paid in full

var _h: SimHarness
var _args := {}
var _lines: Array = []
var _row := 0
var _in_night := false
var _attempt := 0
var _nt0 := 0.0
var _last_neg := [0, 0]
var _pay_start := {}     # spot id -> the purse before the first instalment of the branch payment under way (a branch is paid in instalments)
var _last_goal := ""
var _towers := {}        # spot id -> TowerSpot
var _launch := {}        # projectile instance id -> tower label
var _seen := {}          # spawn_index -> true (this attempt)
var _wave_of := {}       # spawn_index -> wave index
var _reached := {}
var _spawn := {}         # "w|lane|kind" -> [spawned, reached, killed]
var _dmg := {}           # "w|lane|kind" -> [amount, hits]
var _src := {}           # source label -> {"shots": {}, "launched": {}, "hits": {}, "dealt": {}, "kills": {}}
var _connected := {}
var _fired_connected := {}
var _fence_prev := {}
var _attributed := {}    # enemy instance id -> physics frame of its last attributed diner hit
var _unknown_dmg := 0.0
var _sample := 0
var _wave_seen := -1

func _ready() -> void:
	_run.call_deferred()

func _out(s: String) -> void:
	print(s)

func _run() -> void:
	_args = {"seed": "1", "policy": "threat", "days": "24", "force": "none", "out": "", "bench": "", "variant": "", "pin": "", "interval": "", "hold": "", "commit": "", "base": "", "far": "", "oldbot": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	if not String(_args.force) in ["none", "first", "all"] or not (String(_args.policy) in TierBot.POLICIES or String(_args.policy) in TierBot.REPORT_POLICIES):
		push_error("bad --force or --policy")
		get_tree().quit(2)
		return
	Balance.reset()
	if String(_args.base) != "":
		Balance.data.tiers.tier_base[3] = int(_args.base)  # in memory only (D-304 what-if: a softer first tier-3 night)
	if String(_args.interval) != "":
		Balance.data.branches.longbow.interval = float(_args.interval)  # in memory only (round-2 what-if a)
	if String(_args.get("bench", "")) == "1":
		await _bench()
		get_tree().quit(0)
		return
	var holder := Node.new()
	get_tree().root.add_child(holder)
	_h = SimHarness.new(holder)
	var forced := String(_args.force) != "none" or String(_args.variant) != "" or String(_args.pin) != "" or String(_args.hold) == "1" or String(_args.commit) == "1" or String(_args.far) == "1"
	_h.start(int(_args.seed), ForcedBot if forced else TierBot)
	_h.bot.max_tier = 3  # a tier-3 study (E8): the bot never pays for tier 4, so its readings are the tier-3 ones
	_h.bot.policy = String(_args.policy)
	_h.bot.rule = "old" if String(_args.oldbot) == "1" else "walk"
	if forced:
		_h.bot.force = String(_args.force)
		_h.bot.hold = String(_args.hold) == "1"
		_h.bot.commit = String(_args.commit) == "1"
		_h.bot.far = String(_args.far) == "1"
		_h.bot.variant = String(_args.variant)
		if String(_args.pin) != "":
			var pv := String(_args.pin).split(":")
			_h.bot.pin_lane = pv[0]
			var from_s := float(pv[1])
			var pin_row := int(pv[2])  # the pin holds in the night of this row only
			_h.bot.pin_active = func() -> bool:
				return _in_night and _row == pin_row and _h.elapsed - _nt0 >= from_s and _h.main.world.wave_director.wave_index <= 2
	var ch := LaneCharacter.for_run(int(_args.seed))
	_out("RUN seed=%s policy=%s force=%s variant=%s pin=%s interval=%s siege=%s hare=%s days=%s hold=%s commit=%s far=%s base=%s" % [_args.seed, _args.policy, _args.force, _args.variant, _args.pin, _args.interval, ch.siege, ch.hare, _args.days, _args.hold, _args.commit, _args.far, _args.base])
	EventBus.gold_changed.connect(_on_gold)
	EventBus.branch_chosen.connect(_on_branch)
	EventBus.building_changed.connect(_on_building)
	EventBus.diner_damaged.connect(_on_diner_damaged)
	EventBus.enemy_killed.connect(_on_killed)
	for day in range(1, int(_args.days) + 1):
		_row = day
		_attempt = 0
		var tier0 := GameState.tier
		_begin_night()
		var n := await _h.run_night()
		var retries := 0
		_end_night(n)
		while n.failed and retries < 4:
			retries += 1
			var restored := await _h.run_until(func(): return not _h.main.phase_controller.failing, Balance.ui.banner_time + 1.0)
			if not restored:
				break
			if _h.main.phase_controller.phase == Phase.DAY:
				await _h.run_day()
			_begin_night()
			n = await _h.run_night()
			_end_night(n)
		_out("ROW %d night_start_tier=%d final_frac=%.3f retries=%d failed=%s" % [day, tier0, n.diner_frac, retries, str(n.failed)])
		if n.failed:
			break
		_state("day_phase_start")
		var d := await _h.run_day()
		_state("day_phase_end")
		if not d.closed:
			_out("STALL %d" % day)
			break
	_h.finish()
	var f := FileAccess.open(ProjectSettings.globalize_path("res://tests/sim/out/study/").path_join(String(_args.out)), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	get_tree().quit(0)

## Q5: the lane-type bench (tests/support/branch_bench.gd) at pressure 12, the full three waves, for the three single-tower configurations. Read only.
func _bench() -> void:
	for lane in BranchBench.LANES:
		for cfg in [[&"", &""], [&"longbow", &""], [&"volley", &""]]:
			var r: Dictionary = await BranchBench.run(lane, cfg[0], cfg[1], BranchBench.PRESSURE)
			_out("BENCH lane=%s cfg=%s diner_lost=%.0f fence_hp_left=%.0f hares_in_zone=%d clear_s=%.1f fence_stands_s=%s kills=%d" % [lane, BranchBench.cfg_name(cfg), r.diner_lost, r.fence_hp_left, r.hares_in_zone, r.clear_s, str(r.fence_stands_s), r.kills])

func _find_towers(n: Node) -> void:
	if n is TowerSpot:
		_towers[String((n as TowerSpot).spot_id)] = n
	for c in n.get_children():
		_find_towers(c)

func _state(tag: String) -> void:
	var parts: Array = []
	for id in MapLayout.ALL_SPOT_IDS:
		if GameState.buildings.has(id):
			var b: Dictionary = GameState.buildings[id]
			parts.append("%s:%d%s" % [id, int(b.level), ("/" + String(b.branch)) if String(b.branch) != "" else ""])
	_out("STATE row=%d day=%d %s tier=%d gold=%d %s" % [_row, GameState.day, tag, GameState.tier, GameState.gold, " ".join(parts)])

func _on_gold(gold: int, delta: int) -> void:
	if delta < 0:
		_last_neg = [gold - delta, gold]

func _on_building(spot: StringName, _level: int, _paid: int) -> void:
	var s := String(spot)
	if not GameState.buildings.has(s) or _pay_start.has(s):
		return
	var bp: Dictionary = GameState.buildings[s].branch_paid
	for k in bp:
		if int(bp[k]) > 0:
			_pay_start[s] = int(_last_neg[0])  # gold_changed fires just before building_changed: the purse before this first instalment
			return

func _on_branch(spot: StringName, branch: StringName) -> void:
	var s := String(spot)
	var lanes: Array = MapLayout.tower_lanes(s) if MapLayout.spot_kind(s) == "tower" else [MapLayout.fence_lane(s)]
	var opts: Array = BranchBalance.TOWER_BRANCHES if MapLayout.spot_kind(s) == "tower" else BranchBalance.FENCE_BRANCHES
	var ph := "NIGHT" if _h.main.phase_controller.phase == Phase.NIGHT else "DAY"
	_out("BUY row=%d day=%d phase=%s spot=%s pad=%s branch=%s lanes=%s gold_before=%d gold_after_last_instalment=%d gold_now=%d cost=%d" % [_row, GameState.day, ph, s, "ab"[opts.find(branch)], branch, "+".join(PackedStringArray(lanes)), int(_pay_start.get(s, _last_neg[0])), int(_last_neg[1]), GameState.gold, GameState.branch_cost(s)])
	_pay_start.erase(s)

## The tier-2 and tier-3 tower nodes are built when the tier is reached: look again at every night start and connect the new ones.
func _connect_towers() -> void:
	_find_towers(_h.main)
	for id in _towers:
		if not _fired_connected.has(id):
			_fired_connected[id] = true
			(_towers[id] as TowerSpot).attacker.fired.connect(_on_fired.bind(id))

func _begin_night() -> void:
	_connect_towers()
	_in_night = true
	_attempt += 1
	_nt0 = _h.elapsed
	_seen = {}
	_wave_of = {}
	_reached = {}
	_spawn = {}
	_dmg = {}
	_src = {}
	_unknown_dmg = 0.0
	_launch = {}
	_wave_seen = -1
	_sample = 0
	_fence_prev = {}
	for id in GameState.buildings:
		if MapLayout.spot_kind(id) == "fence":
			_fence_prev[id] = float(GameState.buildings[id].hp)
	if GameState.tier >= 3 or _row >= 20:
		_state("night_begin")
		var plan_parts: Array = []
		for w in GameState.lane_plan.size():
			var wv: Dictionary = GameState.lane_plan[w]
			plan_parts.append("w%d{main=%s:%d(h%d,b%d) side=%s:%d(h%d,b%d) extra=%s hp_mult=%.2f boss=%s}" % [w, wv.main, int(wv.main_count), int(wv.get("fast_main", 0)), int(wv.get("brute_main", 0)),
				wv.side, int(wv.side_count), int(wv.get("fast_side", 0)), int(wv.get("brute_side", 0)), str(wv.get("extra", [])), float(wv.hp_mult), str(wv.get("boss", false))])
		_out("PLAN row=%d attempt=%d pressure=%d %s" % [_row, _attempt, GameState.pressure(), " ".join(plan_parts)])
		_out("NIGHT_BEGIN row=%d attempt=%d tier=%d diner_hp=%.0f mercy=%.2f" % [_row, _attempt, GameState.tier, GameState.diner_hp, GameState.mercy_factor()])

func _end_night(n: Dictionary) -> void:
	_in_night = false
	if not (GameState.tier >= 3 or _row >= 20):
		return
	_out("NIGHT_END row=%d attempt=%d frac=%.3f failed=%s kills=%d" % [_row, _attempt, n.diner_frac, str(n.failed), n.kills])
	for k in _spawn.keys():
		var v: Array = _spawn[k]
		_out("SPAWN row=%d attempt=%d key=%s spawned=%d reached_diner=%d killed=%d" % [_row, _attempt, k, v[0], v[1], v[2]])
	for k in _dmg.keys():
		var v: Array = _dmg[k]
		_out("DMG row=%d attempt=%d key=%s diner_damage=%.0f hits=%d" % [_row, _attempt, k, v[0], v[1]])
	if _unknown_dmg > 0.0:
		_out("DMG row=%d attempt=%d key=unattributed diner_damage=%.0f hits=0" % [_row, _attempt, _unknown_dmg])
	for s in _src.keys():
		var v: Dictionary = _src[s]
		_out("SRC row=%d attempt=%d src=%s shots=%s launched_dmg=%s hits=%s dealt_dmg=%s kills=%s" % [_row, _attempt, s, str(v.shots), _round_d(v.launched), str(v.hits), _round_d(v.dealt), str(v.kills)])

func _round_d(d: Dictionary) -> String:
	var o := {}
	for k in d:
		o[k] = snappedf(float(d[k]), 0.1)
	return str(o)

func _phys_frame() -> int:
	return Engine.get_physics_frames()

func _physics_process(_delta: float) -> void:
	if _h == null or _h.main == null or GameState.buildings.is_empty():
		return
	var g := _h.bot.goal
	if GameState.tier >= 3 and g != _last_goal and (g.begins_with("pad_") or _last_goal.begins_with("pad_") or g.begins_with("tier")):
		_out("GOAL row=%d phase=%s %s -> %s gold=%d" % [_row, "NIGHT" if _in_night else "DAY", _last_goal, g, GameState.gold])
	var moved := g != _last_goal
	_last_goal = g
	if not _in_night or _h.main.phase_controller.phase != Phase.NIGHT:
		return
	if moved and _row >= 20:
		var per_lane := {}
		var in_range := 0
		var hp0 := _h.main.hero.xz()
		for e in _h.main.world.wave_director.alive_enemies():
			per_lane[e.lane] = int(per_lane.get(e.lane, 0)) + 1
			if Vector2(e.position.x, e.position.z).distance_to(hp0) <= Balance.data.hero.attack_range:
				in_range += 1
		_out("HEROMOVE row=%d attempt=%d t=%.1f goal=%s hero=%.1f,%.1f in_hero_range=%d alive_by_lane=%s diner=%.0f" % [_row, _attempt, _h.elapsed - _nt0, g, hp0.x, hp0.y, in_range, str(per_lane), GameState.diner_hp])
	var t := _h.elapsed - _nt0
	var wd: WaveDirector = _h.main.world.wave_director
	var live := {}
	for p in _h.main.world.projectile_pool.active():
		live[p.get_instance_id()] = true
	for k in _launch.keys():
		if not live.has(k):
			_launch.erase(k)  # a released projectile's label must not follow it into its next use
	var logging := _row >= 20
	if wd.wave_index != _wave_seen:
		_wave_seen = wd.wave_index
		var fh: Array = []
		for id in _fence_prev:
			if int(GameState.buildings[id].level) > 0:
				fh.append("%s=%.0f/%s" % [id, float(GameState.buildings[id].hp), String(GameState.buildings[id].branch)])
		if logging:
			_out("FENCE_HP row=%d attempt=%d t=%.1f wave_start=%d %s diner=%.0f" % [_row, _attempt, t, _wave_seen, " ".join(fh), GameState.diner_hp])
	for e in wd.alive_enemies():
		var b: Boar = e
		var si := b.spawn_index
		if not _seen.has(si):
			_seen[si] = true
			_wave_of[si] = wd.wave_index
			var key := "w%d|%s|%s" % [wd.wave_index, b.lane, b.kind]
			if not _spawn.has(key):
				_spawn[key] = [0, 0, 0]
			_spawn[key][0] += 1
			var cid := b.get_instance_id()
			if not _connected.has(cid):
				_connected[cid] = true
				b.health.damaged.connect(_on_enemy_damaged.bind(b))
		if not _reached.has(si) and not b.current_target.is_empty() and b.current_target.kind == &"diner":
			_reached[si] = true
			_spawn["w%d|%s|%s" % [_wave_of[si], b.lane, b.kind]][1] += 1
	for id in _fence_prev:
		var hp := float(GameState.buildings[id].hp)
		if float(_fence_prev[id]) > 0.0 and hp <= 0.0 and int(GameState.buildings[id].level) > 0:
			_out("FENCE_FALL row=%d attempt=%d t=%.1f wave=%d fence=%s branch=%s" % [_row, _attempt, t, wd.wave_index, id, String(GameState.buildings[id].branch)])
		_fence_prev[id] = hp
	_sample += 1
	if logging and _sample % 180 == 1:
		var hp2 := _h.main.hero.xz()
		_out("BOT row=%d attempt=%d t=%.1f goal=%s pos=%.1f,%.1f alive=%d diner=%.0f" % [_row, _attempt, t, _h.bot.goal, hp2.x, hp2.y, wd.alive_count(), GameState.diner_hp])

func _label(id: String) -> String:
	var br := String(GameState.buildings[id].branch)
	return "%s(%s)" % [id, br if br != "" else "plain"] if id != "" else "other"

func _src_entry(s: String) -> Dictionary:
	if not _src.has(s):
		_src[s] = {"shots": {}, "launched": {}, "hits": {}, "dealt": {}, "kills": {}}
	return _src[s]

func _on_fired(target: Object, id: String) -> void:
	if not _in_night:
		return
	var lab := _label(id)
	var pool: NodePool = _h.main.world.projectile_pool
	var best: Projectile = null
	var bd := 1e9
	var org := (_towers[id] as TowerSpot).attacker.global_position + Vector3(0, 1.0, 0)
	for p in pool.active():
		if p._target == target and not _launch.has(p.get_instance_id()):
			var d: float = (p as Node3D).global_position.distance_to(org)
			if d < bd:
				bd = d
				best = p
	var kind := String(target.get(&"kind"))
	var e := _src_entry(lab)
	e.shots[kind] = int(e.shots.get(kind, 0)) + 1
	var dmg: float = (_towers[id] as TowerSpot).attacker._damage_against(target)
	e.launched[kind] = float(e.launched.get(kind, 0.0)) + dmg
	if best != null:
		_launch[best.get_instance_id()] = [lab, best._target_index]

func _on_enemy_damaged(amount: float, b: Boar) -> void:
	if not _in_night:
		return
	var lab := "env(thorns/pass)"
	var pool: NodePool = _h.main.world.projectile_pool
	var best: Projectile = null
	var bd := 1e9
	for p in pool.active():
		if p._pool != null and p._target == b and p._target_index == b.spawn_index:
			var d: float = (p as Node3D).global_position.distance_to(b.global_position + Vector3(0, 0.5, 0))
			if d < bd:
				bd = d
				best = p
	if best != null and bd <= best._speed * DELTA + 0.05:
		lab = _launch[best.get_instance_id()][0] if _launch.has(best.get_instance_id()) else "other(hero/guard)"
	var kind := String(b.kind)
	var e := _src_entry(lab)
	e.hits[kind] = int(e.hits.get(kind, 0)) + 1
	e.dealt[kind] = float(e.dealt.get(kind, 0.0)) + amount
	if b.health.hp <= 0.0:
		var kk := "%s|%s" % [b.lane, kind]
		e.kills[kk] = int(e.kills.get(kk, 0)) + 1

func _on_killed(si: int, _lane: StringName, _p: Vector3, kind: StringName) -> void:
	if not _in_night or not _wave_of.has(si):
		return
	var key := "w%d|%s|%s" % [_wave_of[si], _lane, kind]
	if _spawn.has(key):
		_spawn[key][2] += 1

func _on_diner_damaged(amount: float, _hp_left: float) -> void:
	if not _in_night:
		return
	var wd: WaveDirector = _h.main.world.wave_director
	var frame := _phys_frame()
	var hit: Boar = null
	for e in wd.alive_enemies():
		var b: Boar = e
		if b.current_target.is_empty() or b.current_target.kind != &"diner":
			continue
		if absf(b.stats().damage * GameState.mercy_factor() - amount) > 1e-3 or b._attack_timer > DELTA + 1e-4:
			continue
		if _attributed.get(b.get_instance_id(), -1) == frame:
			continue
		hit = b
		break
	if hit == null:
		_unknown_dmg += amount
		return
	_attributed[hit.get_instance_id()] = frame
	var key := "w%d|%s|%s" % [_wave_of.get(hit.spawn_index, -1), hit.lane, hit.kind]
	if not _dmg.has(key):
		_dmg[key] = [0.0, 0]
	_dmg[key][0] += amount
	_dmg[key][1] += 1
