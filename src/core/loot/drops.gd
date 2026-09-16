class_name Drops
## What a thing yields when it is broken, beaten or opened (docs/VISION.md §6.1).
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


## `entries` take: item (id), chance (0..1, default 1), count (Vector2i min/max,
## default 1..1), rarity (the grade the piece comes out at), only_in (landscape
## ids this source yields it in, when the same source stands in several places).
static func declare(source: StringName, entries: Array) -> void:
	var rows: Array = []
	for e: Variant in entries:
		var row := {"item": &"", "chance": 1.0, "count": Vector2i.ONE, "rarity": Rarity.COMMON, "only_in": []}
		row.merge(e as Dictionary, true)
		rows.append(row)
	_tables[source] = rows


static func table(source: StringName) -> Array:
	return _tables.get(source, [])


static func sources() -> Array:
	return _tables.keys()


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
