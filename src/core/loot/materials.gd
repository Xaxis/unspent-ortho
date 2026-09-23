class_name Materials
## Where an elite material can be got, and nowhere else (docs/VISION.md).
##
## This is the spine of the long game: the best of a kind is gated behind a
## LANDSCAPE or behind one enemy or sentinel, so a player who wants it has to
## travel, dive, climb or fight for it. A material declared here is a promise
## that it exists in those places and is absent everywhere else — the test suite
## holds both halves of that, because a material that quietly turns up anywhere
## costs a landscape its reason to be visited.
##
## Content declares; nothing here knows a landscape by name:
##   Materials.declare(&"tide_iron", {"lands": [&"coast"], "what": "rust-bled, pitted"})
##   Materials.declare(&"sentinel_core", {"sources": [&"sentinel_coast"]})
##
## A player can learn this in the world (a trader, a read, their own slate), so
## `where` is written to be shown, not just tested against.

static var _table: Dictionary = {}


## `where` takes: lands (landscape ids), sources (roster or sentinel ids), what
## (a line for the player), rarity (the grade it tends to make).
static func declare(id: StringName, where: Dictionary) -> void:
	var row := {"lands": [], "sources": [], "what": "", "rarity": Rarity.RARE}
	row.merge(where, true)
	_table[id] = row


static func known() -> Array:
	return _table.keys()


static func where(id: StringName) -> Dictionary:
	return _table.get(id, {})


static func lands(id: StringName) -> Array:
	return _table.get(id, {}).get("lands", [])


static func sources(id: StringName) -> Array:
	return _table.get(id, {}).get("sources", [])


## Every elite material a landscape holds, for a slate that answers "what is here".
static func in_land(land: StringName) -> Array:
	var out := []
	for id: StringName in _table:
		if lands(id).has(land):
			out.append(id)
	return out


## True only where this material is declared to be. A material with no land and
## no source is a mistake, not a material that is everywhere: it comes back false.
static func can_come_from(id: StringName, land: StringName = &"", source: StringName = &"") -> bool:
	var row: Dictionary = _table.get(id, {})
	if row.is_empty():
		return false
	if land != &"" and (row.get("lands", []) as Array).has(land):
		return true
	if source != &"" and (row.get("sources", []) as Array).has(source):
		return true
	return false


## Every declared material names somewhere it comes from, and the places it names
## exist. Returns what is wrong, so a test can fail with the list.
static func problems(land_ids: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for id: StringName in _table:
		var l: Array = lands(id)
		var s: Array = sources(id)
		if l.is_empty() and s.is_empty():
			out.append("%s comes from nowhere" % id)
		for one: StringName in l:
			if not land_ids.has(one):
				out.append("%s names a landscape that does not exist: %s" % [id, one])
	return out


## Tests and a loaded game start from a known table.
static func clear() -> void:
	_table.clear()
