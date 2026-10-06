class_name BalanceData
extends Resource
## All gameplay tuning (spec 12, D-033). Changing a value must never need a code change.

@export var hero: HeroBalance = HeroBalance.new()
@export var enemy: EnemyBalance = EnemyBalance.new()
@export var wave: WaveBalance = WaveBalance.new()
@export var economy: EconomyBalance = EconomyBalance.new()
@export var build: BuildBalance = BuildBalance.new()
@export var sim: SimThresholds = SimThresholds.new()
@export var cards: CardBalance = CardBalance.new()
@export var guards: GuardBalance = GuardBalance.new()
@export var stations: StationBalance = StationBalance.new()
@export var tiers: TierBalance = TierBalance.new()
@export var monsters: MonsterBalance = MonsterBalance.new()
