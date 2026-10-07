class_name BranchMath
extends RefCounted
## E5 tier-3 spec 6.4: the arithmetic behind the branch identity test. Pure: stats and numbers in, numbers out.
##
## Convention (every tower alike): a monster of HP h dies after ceil(h / d) hits of damage d. A tower that fires
## `count` projectiles per attack, one per target, lands count hits per `interval` seconds on a steady stream.
## DPS is raw damage over time; kill rates use whole hits (overkill is wasted).

static func hits_to_kill(hp: float, damage: float) -> int:
	assert(damage > 0.0, "hits_to_kill needs positive damage")
	# The 1e-9 keeps an exact fit (36 hp, 18 damage) at 2 hits against float noise; Health kills at hp <= 0, the same rule.
	return maxi(ceili(hp / damage - 1e-9), 1)

## Raw damage per second against ONE target (a multi-projectile tower hits it once per attack).
static func single_dps(t: TowerBranchStats) -> float:
	assert(t.interval > 0.0, "interval must be positive")
	return t.damage / t.interval

## Raw damage per second with `n` targets in range: min(n, count) projectiles per attack.
static func multi_dps(t: TowerBranchStats, n: int) -> float:
	assert(t.interval > 0.0, "interval must be positive")
	return t.damage * float(mini(maxi(n, 0), t.count)) / t.interval

## Kills per second of monsters of HP `hp`, a steady stream with `n_in_range` targets always available.
static func kills_per_second(hp: float, t: TowerBranchStats, n_in_range: int) -> float:
	assert(t.interval > 0.0, "interval must be positive")
	var hits_per_s := float(mini(maxi(n_in_range, 0), t.count)) / t.interval
	return hits_per_s / float(hits_to_kill(hp, t.damage))

## Seconds a fence of `fence_hp` holds against one attacker of `attacker_kind`: whole hits of
## damage x fence_damage_mult x the fence's damage_taken_mult_by_kind[kind], one per attack interval.
## Spike's thorns do not shorten it: a thorn hurts the attacker, it never stops the attack.
static func fence_hold_seconds(fence_hp: float, attacker: MonsterStats, fence: FenceBranchStats, attacker_kind: StringName) -> float:
	var taken: float = float(fence.damage_taken_mult_by_kind.get(attacker_kind, 1.0))
	var per_hit := attacker.damage * attacker.fence_damage_mult * taken
	if per_hit <= 0.0:
		return INF  # immune: the fence never falls
	return float(hits_to_kill(fence_hp, per_hit)) * attacker.attack_interval

## Damage a hare-kind monster takes crossing the fence's line (once). `scale` = spike_scale(...).
static func pass_damage(fence: FenceBranchStats, kind: StringName, scale: float) -> float:
	return fence.pass_damage * scale if kind in fence.pass_kinds else 0.0

## Spike's numbers grow with the night's HP multiplier relative to the multiplier at the tier-3 base (D-272.1).
static func spike_scale(hp_mult_now: float, hp_mult_base: float) -> float:
	assert(hp_mult_base > 0.0, "the base multiplier must be positive")
	return hp_mult_now / hp_mult_base

## The base multiplier Spike's numbers are quoted at: the HP multiplier of the FIRST wave at the tier's base pressure.
## One place for this choice; gameplay passes WaveMath.hp_mult(now) as the first argument of spike_scale.
static func spike_base_mult(wb: WaveBalance, tb: TierBalance, tier := 3) -> float:
	return WaveMath.hp_mult(tb.tier_base[tier], 0, wb)
