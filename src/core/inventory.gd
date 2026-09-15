class_name Inventory
extends RefCounted
## What the player carries. Items are ids from Items.DEFS. Tools carry an edge
## (0..10000; 10000 is new). One hand, one thing: `held` is both the work verb
## and the weapon; &"" is bare hands.
##
## Edges are per item id, not per copy: the edge is the best copy's, a newly
## made or found copy comes out new (source: "a spare comes out new"), and wear
## goes on that copy. There is no slot cap; load (bulk against the creel) is
## what slows a body down.

signal changed

## Load carried before a body is laden. (source: creel 40)
const CREEL := 40.0
## The one-time notice when an edge wears down past this. (source)
const DULL_EDGE := 3500
const DULL_LINE := "It is not biting the way it did."

var items: Dictionary = {} # StringName -> int
var edges: Dictionary = {} # StringName -> int, only for tools
var held: StringName = &""
## The one salvage kit piece worn (&"" = none). Worn kit still counts toward load.
var worn: StringName = &""
var _dull_noticed: Dictionary = {} # StringName -> true once the notice was given


func count(id: StringName) -> int:
	return items.get(id, 0)


func has(id: StringName, n: int = 1) -> bool:
	return count(id) >= n


func add(id: StringName, n: int = 1) -> void:
	if n <= 0:
		return
	items[id] = count(id) + n
	if Items.has_edge(id):
		edges[id] = 10000
		_dull_noticed.erase(id)
	changed.emit()


func remove(id: StringName, n: int = 1) -> bool:
	if not has(id, n):
		return false
	items[id] = count(id) - n
	if items[id] == 0:
		items.erase(id)
		edges.erase(id)
		if held == id:
			held = &""
		if worn == id:
			worn = &""
	changed.emit()
	return true


func set_held(id: StringName) -> void:
	held = id if (id == &"" or has(id)) else &""
	changed.emit()


func edge(id: StringName) -> int:
	return edges.get(id, 10000)


func set_edge(id: StringName, value: int) -> void:
	if not Items.has_edge(id):
		return
	edges[id] = clampi(value, 0, 10000)
	if edges[id] > DULL_EDGE:
		_dull_noticed.erase(id)
	changed.emit()


## Wear a tool by `uses` (one work, one swing). Never breaks: edge stops at 0.
## Tools that never dull (bite 0) and found tools are untouched. Returns true
## the first time the edge falls to DULL_EDGE, so the caller can say so once.
func wear(id: StringName, uses: int = 1) -> bool:
	var bite: int = Items.def(id).get("bite", 0)
	if bite <= 0 or not has(id):
		return false
	var before := edge(id)
	edges[id] = maxi(0, before - roundi(uses * 10000.0 / bite))
	changed.emit()
	if edges[id] <= DULL_EDGE and not _dull_noticed.has(id):
		_dull_noticed[id] = true
		return true
	return false


## Wear one piece of salvage kit (one at a time); &"" takes it off.
func wear_kit(id: StringName) -> bool:
	if id != &"" and (not has(id) or Items.def(id).get("kit", &"") == &""):
		return false
	worn = id
	changed.emit()
	return true


func bulk() -> float:
	var total := 0.0
	for id: StringName in items:
		total += Items.bulk(id) * items[id]
	return total


## Load that can be carried without being laden: the creel, a worn rig, a carried basket.
func creel() -> float:
	var c := CREEL
	if worn != &"":
		c += Items.def(worn).get("creel", 0.0)
	if has(&"basket"):
		c += Items.def(&"basket").get("creel", 0.0)
	return c


## Ids carried in `group` (tool found material food good kit), sorted for a stable list.
func ids_in(group: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in items:
		if Items.group(id) == group:
			out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out
