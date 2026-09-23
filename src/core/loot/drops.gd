class_name Drops
## What a thing yields when it is broken, beaten or opened (docs/VISION.md).
##
## One economy, not four. Sentinels, works, landmarks, machines and a settlement's
## spoils all declare here rather than each inventing a way to hand things over,
## so a player can learn one set of rules and the gear package can balance in one
## place.
##
##   Drops.declare(&"sentinel_coast", [
##       {"item": &"sentinel_core", "chance": 1.0, "rarity": Rarity.RELIC},
##       {"item": &"plate", "count": Vector2i(4, 9)},
##   ])
##
## A roll is DETERMINISTIC: the same seed and the same thing yield the same
## things, however many times the world is regenerated or the game reloaded, so a
## player cannot reroll a sentinel's core by loading, and a tour can prove what a
## kill gives.

static var _tables: Dictionary = {}
## Table id -> the roster kind it comes off, when that is not the id itself.
static var _bodies: Dictionary = {}
## Table id -> the landscapes the PLACE it is opened at stands in.
static var _places: Dictionary = {}


## `entries` take: item (id), chance (0..1, default 1), count (Vector2i min/max,
## default 1..1), rarity (the grade the piece comes out at), only_in (landscape
## ids this source yields it in, when the same source stands in several places).
##
## `of` names the roster kind the table comes off when the id is NOT that kind.
## A kill rolls the table named by the kind killed (56_economy), so anything that
## hands its own spoils over on its own terms — a keeper, whose table is rolled
## once for its region and never again — must keep an id of its own or be paid
## twice. Saying which body it is keeps it pointable at all the same.
##
## So: a table is rolled by WHOEVER OWNS THE THING, and `of` is only for the case
## where a body hands the spoils over. A landmark's cache, a works' salvage and a
## settlement's spoils each take an id of their own and leave `of` empty — they
## are opened, broken into and looted, not killed. Naming a body there would hand
## the same goods out again the next time something of that kind died.
static func declare(source: StringName, entries: Array, of: StringName = &"") -> void:
	var rows: Array = []
	for e: Variant in entries:
		var row := {"item": &"", "chance": 1.0, "count": Vector2i.ONE, "rarity": Rarity.COMMON, "only_in": []}
		row.merge(e as Dictionary, true)
		rows.append(row)
	_tables[source] = rows
	if of != &"":
		_bodies[source] = of


## A table that is opened at a PLACE rather than cut off a body: a landmark's
## cache, and whatever else is walked to rather than killed. `lands` is the
## landscapes that place stands in, which is the whole of what the economy needs
## to answer "is there a path a player can walk to this" — `Sources` walks a
## normal table back to the roster kind it comes off, and a place is not one, so
## without this a wick in a lighthouse is a test failure instead of a find.
##
## Declaring the landscapes here, rather than letting the economy import whoever
## owns the place, is what keeps that dependency from existing at all.
static func declare_place(source: StringName, entries: Array, lands: Array[StringName]) -> void:
	declare(source, entries)
	_places[source] = lands


static func table(source: StringName) -> Array:
	return _tables.get(source, [])


## The landscapes the place this table is opened at stands in; empty for a table
## that comes off a body, which is every table that never said otherwise.
static func place_lands(source: StringName) -> Array[StringName]:
	return _places.get(source, [] as Array[StringName])


## Every table that is opened at a place.
static func places() -> Array:
	return _places.keys()


static func sources() -> Array:
	return _tables.keys()


## The roster kind a table comes off: itself, unless it said otherwise.
static func body_of(source: StringName) -> StringName:
	return _bodies.get(source, source)


## What this one thing yields: [{item, count}]. `instance` separates one harvester
## from the next on the same seed; `land` drops entries that do not belong here.
static func roll(source: StringName, seed_value: int, instance: int, land: StringName = &"") -> Array:
	var out: Array = []
	var rows: Array = table(source)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var only: Array = row.get("only_in", [])
		if land != &"" and not only.is_empty() and not only.has(land):
			continue
		if Rng.hash01(seed_value, instance, 0x10070 + i) > float(row.get("chance", 1.0)):
			continue
		var span: Vector2i = row.get("count", Vector2i.ONE)
		var n := span.x
		if span.y > span.x:
			n = span.x + int(Rng.hash01(seed_value, instance, 0x10071 + i) * float(span.y - span.x + 1))
		if n > 0:
			out.append({"item": row.get("item", &""), "count": mini(n, span.y)})
	return out


## Everything this source can ever yield, for a slate that says what a thing is
## worth breaking and for a test that proves a material is reachable at all.
static func can_yield(source: StringName) -> Array:
	var out: Array = []
	for row: Dictionary in table(source):
		var id: StringName = row.get("item", &"")
		if id != &"" and not out.has(id):
			out.append(id)
	return out


## What this source can yield WHERE IT STANDS: the same wreck holds different
## things on the salt flats than on the coast, which is how a landscape keeps
## something of its own without needing a source of its own.
static func can_yield_here(source: StringName, land: StringName) -> Array:
	var out: Array = []
	for row: Dictionary in table(source):
		var only: Array = row.get("only_in", [])
		if not only.is_empty() and not only.has(land):
			continue
		var id: StringName = row.get("item", &"")
		if id != &"" and not out.has(id):
			out.append(id)
	return out


## Every source that can yield this item.
static func sources_of(item: StringName) -> Array:
	var out: Array = []
	for s: StringName in _tables:
		if can_yield(s).has(item):
			out.append(s)
	return out


static func clear() -> void:
	_tables.clear()
	_bodies.clear()
	_places.clear()
