class_name NodePool
extends Node
## Prewarmed pool (D-017, D-061). Items are hidden and disabled while free. Grows with a warning.

signal grew(new_size: int)

var size := 0
var _factory: Callable
var _free: Array = []
var _active: Array = []

func setup(factory: Callable, prewarm: int) -> void:
	_factory = factory
	for i in prewarm:
		_make()

func acquire() -> Node3D:
	if _free.is_empty():
		_make()
		push_warning("NodePool %s grew to %d" % [name, size])
		grew.emit(size)
	var n: Node3D = _free.pop_back()
	_active.append(n)
	n.visible = true
	n.process_mode = Node.PROCESS_MODE_INHERIT
	if n.has_method("on_acquire"):
		n.on_acquire()
	return n

func release(n: Node3D) -> void:
	var i := _active.find(n)
	if i < 0:
		return
	_active.remove_at(i)
	if n.has_method("on_release"):
		n.on_release()
	n.visible = false
	n.process_mode = Node.PROCESS_MODE_DISABLED
	_free.append(n)

## D-128 interface: return every active item to the pool; returns how many were recalled.
func recall_all() -> int:
	var count := _active.size()
	for n in _active.duplicate():
		release(n)
	return count

## Returns the live array; duplicate() it before releasing while iterating.
func active() -> Array:
	return _active

func _make() -> void:
	var n: Node3D = _factory.call()
	size += 1
	n.visible = false
	n.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(n)
	_free.append(n)
