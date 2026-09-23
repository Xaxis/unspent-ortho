class_name Modifiers
## How the modules in a loadout talk to each other (docs/VISION.md). The
## table is `ModifierTable`; this is the rule that reads it.
##
## Two things happen when a kit is settled, and they are the only two:
##   settle(ids, resist)   the conflicts and combos change what the kit keeps off
##                         the body, and hand back the lines that say why
##   allow(ids, abilities) an ability a conflict has taken away is not fitted
##
## `Gear.resist_total` and `Gear.abilities_of` call these, so every reader — the
## body, the hazards system, the slate's gear page, a test — sees the same kit.
## Nothing here is random and nothing depends on the order the modules were
## socketed in: the same parts always settle to the same numbers.

## A conflict never takes a resistance below this share of what it was: a cost
## should be felt, not be a refusal to work at all.
const FLOOR := 0.5


## Every tag in the kit, and how many parts give it.
static func tags(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in ids:
		for t: Variant in ModifierTable.gives(StringName(id)):
			var k := StringName(t)
			out[k] = int(out.get(k, 0)) + 1
	return out


## Whether a pair's condition holds for this kit. `b` empty means "a is here and
## `unless` is not", which is how an unpaid cost is written.
static func _fires(pair: Dictionary, counted: Dictionary) -> bool:
	var a := StringName(pair.get("a", &""))
	var b := StringName(pair.get("b", &""))
	if not counted.has(a):
		return false
	if b == &"":
		var unless := StringName(pair.get("unless", &""))
		return unless == &"" or not counted.has(unless)
	if a == b:
		# One tag twice: two parts that do the same thing together.
		return int(counted[a]) >= 2
	return counted.has(b)


## Every pair that fires for this kit, in table order.
static func firing(ids: Array) -> Array[Dictionary]:
	var counted := tags(ids)
	var out: Array[Dictionary] = []
	for pair: Dictionary in ModifierTable.PAIRS:
		if _fires(pair, counted):
			out.append(pair)
	return out


static func conflicts(ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in firing(ids):
		if StringName(p.get("kind", &"")) == &"conflict":
			out.append(p)
	return out


static func combos(ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in firing(ids):
		if StringName(p.get("kind", &"")) == &"combo":
			out.append(p)
	return out


## What the kit really keeps off the body once the parts have argued. `resist` is
## changed in place (it is `Gear.resist_total`'s own dictionary); the lines come
## back for whoever wants to say why.
static func settle(ids: Array, resist: Dictionary) -> PackedStringArray:
	var said := PackedStringArray()
	for pair: Dictionary in firing(ids):
		var effect: Dictionary = pair.get("effect", {})
		for h: Variant in (effect.get("scale", {}) as Dictionary):
			var key := StringName(h)
			if not resist.has(key):
				continue
			var by := maxf(FLOOR, float((effect["scale"] as Dictionary)[h]))
			resist[key] = clampf(float(resist[key]) * by, 0.0, 1.0)
		for h: Variant in (effect.get("add", {}) as Dictionary):
			Gear.combine(resist, {StringName(h): float((effect["add"] as Dictionary)[h])})
		said.append(String(pair.get("line", "")))
	return said


## The abilities a kit really grants: one a conflict has smothered is not fitted.
static func allow(ids: Array, abilities: Array[StringName]) -> Array[StringName]:
	var lost: Array[StringName] = []
	for pair: Dictionary in conflicts(ids):
		var drop := StringName((pair.get("effect", {}) as Dictionary).get("drop", &""))
		if drop != &"" and not lost.has(drop):
			lost.append(drop)
	if lost.is_empty():
		return abilities
	var out: Array[StringName] = []
	for a in abilities:
		if not lost.has(a):
			out.append(a)
	return out


## What this module does, for the ONE line the gear page has beside a socket.
##
## It says one thing, never two. While nothing is wrong with the kit that is the
## decision the part changes; the moment a pair fires it is the price instead,
## because a price is the news. Both are short on purpose: the first version put
## the whole sentence here and it ran off the panel and printed itself across the
## resistances (frame 05 of tours/gear-economy.tour). `tests/gear_economy` measures
## every one of these against the real font and the real panel.
static func note(id: StringName, ids: Array) -> String:
	var mine: Array = ModifierTable.gives(id)
	for pair: Dictionary in firing(ids):
		var a: Variant = pair.get("a", &"")
		var b: Variant = pair.get("b", &"")
		if not (mine.has(a) or mine.has(b)):
			continue
		var conflict := StringName(pair.get("kind", &"")) == &"conflict"
		return "%s%s" % ["!" if conflict else "+", pair.get("mark", pair.get("line", ""))]
	return ModifierTable.short(id)


## What a part still wants paid that nothing in the kit is paying: the line a
## player needs before they walk into the burning wearing a shock lattice.
static func unpaid(ids: Array) -> PackedStringArray:
	var counted := tags(ids)
	var out := PackedStringArray()
	for id: Variant in ids:
		for t: Variant in ModifierTable.wants(StringName(id)):
			if not counted.has(StringName(t)):
				out.append("%s wants %s" % [Items.display_name(StringName(id)), t])
	return out
