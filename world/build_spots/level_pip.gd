class_name LevelPip
extends Node3D
## One level star of a build spot or an upgrade pad (visual only). It draws nothing itself: it is the pip's HANDLE (E6 phase A, D-298.2). Its `visible`, its
## transform and the group `level_pips` are what the spot, the tests and the lane badge read; the PipBatch of the scene draws every handle as one instance of
## ONE MultiMesh. The handle tells the batch when it enters or leaves the tree, shows or hides, or moves.

## The batch that draws this pip (set by LevelPips.make before the pip enters the tree).
var _batch: PipBatch

func _init() -> void:
	set_notify_transform(true)
	visibility_changed.connect(_sync)

func _enter_tree() -> void:
	if _batch != null and is_instance_valid(_batch):
		_batch.attach(self)

func _exit_tree() -> void:
	if _batch != null and is_instance_valid(_batch):
		_batch.detach(self)

func use_batch(b: PipBatch) -> void:
	_batch = b

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_sync()

func _sync() -> void:
	if _batch != null and is_instance_valid(_batch):
		_batch.refresh_slot(self)
