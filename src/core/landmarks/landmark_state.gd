class_name LandmarkState
extends RefCounted
## What a player has done about the places worth the walk, and the only part of a
## landmark that is saved: which have been FOUND (so they stay on the map for
## good, whether or not the player ever goes back) and which have been OPENED
## (so a cache cannot be emptied twice, and cannot be rerolled by loading).

## Site id (&"lighthouse#1") -> true.
var found: Dictionary = {}
var opened: Dictionary = {}


func is_found(id: StringName) -> bool:
	return found.has(id)


func is_opened(id: StringName) -> bool:
	return opened.has(id)


func find(id: StringName) -> bool:
	if found.has(id):
		return false
	found[id] = true
	return true


func open(id: StringName) -> bool:
	if opened.has(id):
		return false
	opened[id] = true
	found[id] = true
	return true


func save() -> Dictionary:
	return {"found": found.keys(), "opened": opened.keys()}


func load_from(d: Dictionary) -> void:
	found.clear()
	opened.clear()
	for k: Variant in d.get("found", []):
		found[StringName(str(k))] = true
	for k: Variant in d.get("opened", []):
		var id := StringName(str(k))
		opened[id] = true
		found[id] = true
