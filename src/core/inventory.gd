class_name Inventory
extends RefCounted
## What the player carries. Items are ids from Items.DEFS. Tools carry an edge
## (0..10000; 10000 is new). One hand, one thing: `held` is both the work verb
## and the weapon; &"" is bare hands.

signal changed

var items: Dictionary = {} # StringName -> int
var edges: Dictionary = {} # StringName -> int, only for tools
var held: StringName = &""


func count(id: StringName) -> int:
	return items.get(id, 0)


func has(id: StringName, n: int = 1) -> bool:
	return count(id) >= n


func add(id: StringName, n: int = 1) -> void:
	items[id] = count(id) + n
	if Items.has_edge(id) and not edges.has(id):
		edges[id] = 10000
	changed.emit()


func remove(id: StringName, n: int = 1) -> bool:
	if not has(id, n):
		return false
	items[id] = count(id) - n
	if items[id] == 0:
		items.erase(id)
		if held == id:
			held = &""
	changed.emit()
	return true


func set_held(id: StringName) -> void:
	held = id if (id == &"" or has(id)) else &""
	changed.emit()


func edge(id: StringName) -> int:
	return edges.get(id, 10000)


func bulk() -> float:
	var total := 0.0
	for id: StringName in items:
		total += Items.bulk(id) * items[id]
	return total
