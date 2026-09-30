extends Node
## Loads tuning data (spec 3.2). Tests call reset() in before_each and may inject().

const DATA_PATH := "res://balance/balance.tres"
const UI_PATH := "res://balance/ui_tuning.tres"

var data: BalanceData
var ui: UiTuning

func _init() -> void:
	reset()

func reset() -> void:
	data = (load(DATA_PATH) as BalanceData).duplicate(true)
	ui = (load(UI_PATH) as UiTuning).duplicate(true)

func inject(new_data: BalanceData, new_ui: UiTuning = null) -> void:
	data = new_data
	if new_ui != null:
		ui = new_ui
