class_name WorldProp
extends RefCounted
## One placed static thing: a tree, a rock, an ore node, a house.

var id: int
var kind: int
## Centre in tiles.
var pos: Vector2
## Radians about the vertical axis.
var rot: float
var scale: float
## Collision radius in tiles (already scaled). 0 = passable.
var solid: float
## Which model of this kind, or -1 to take the one `deal_hash` gives it. World gen
## sets it where the ARRANGEMENT matters and chance is not good enough: a village
## deals its houses one variant each so no two silhouettes in it repeat.
var variant := -1
## How much of it is still there, 1 whole down to 0 (Harvest.shown). Taking from a
## thing that the taking CONSUMES works it down: the drawing reads this, and so
## does what stops a body. Not saved — `SaveCore` puts the takes back and the rule
## works it out again.
var shown := 1.0

## How many WorldProps are alive: the number the streaming design drives toward
## the working set near the camera (tests/stream/test_prop_table.gd). Counted, not
## exact across threads, which is all a trend needs.
static var live := 0


## WHICH MODEL A PROP IS DRAWN AS COMES FROM WHAT IT IS AND WHERE IT STANDS, NOT
## FROM ITS ID. An id is its place in the order world gen laid things, so any
## change upstream -- one prop more in one landscape -- renumbered everything after
## it and re-dealt most of the island's models: the canon's neon frame moved to
## another shack every time the world did (owner, 2026-09-22: a prop's model is
## dealt by its position; `docs/ROADMAP.md`). A prop never moves, so this is as
## fixed as the id was and survives every change that does not touch the prop.
## Quarter-tile resolution: props are jittered off tile centres, and two can
## share a tile. `PropModels.variant_of` and `GenWorks._note_lit_shack` both ask
## this and nothing else, so what is drawn and what is lit cannot disagree.
## Whether `a` and `b` are the same prop: both none, or the same id. Never `==`
## on two props: a prop is a view made from its row (PropTable), so two asks for
## one prop are two objects (tests/stream/test_prop_identity.gd).
static func same(a: WorldProp, b: WorldProp) -> bool:
	if a == null or b == null:
		return a == null and b == null
	return a.id == b.id


static func deal_hash(seed_value: int, kind: int, pos: Vector2) -> int:
	return Rng.hash_ints(seed_value, kind, floori(pos.x * 4.0), floori(pos.y * 4.0), 90)


func _init(p_id: int, p_kind: int, p_pos: Vector2, p_rot: float, p_scale: float) -> void:
	id = p_id
	kind = p_kind
	pos = p_pos
	rot = p_rot
	scale = p_scale
	solid = PropKind.SOLID[kind] * scale
	live += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		live -= 1
