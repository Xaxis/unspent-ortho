class_name Takes
## What each prop in the world gives, and how (design-extract §9.5, mapped
## onto PropKind). Pure data plus the rule that picks an option for the tool in
## hand. No nodes, no game.
##
## An option:
##   verb      break dig fell cut need a held tool with that verb;
##             gather scrape tap turn are bare-handed
##   item, n   what one take adds
##   min       bare-hand world minutes (a matching tool's speed and edge shorten it)
##   regrow    hours until it can be taken again; NEVER = a permanent world edit
##   stuff     hardness the tool must reach (wood iron steel crucible)
##   uses      takes before the option is exhausted (a vein works out, a tip is picked over)
##   keep      true: the prop stays standing when exhausted (a rock after its mussels);
##             false: it is taken away (WorldData.depleted) until it regrows
##   tide      &"low": only when the water is off it (see TIDE_GATES)
##   bonus     [item, chance]: sometimes one more thing comes up with it
##   ground    only on these grounds (empty = any)
##
## Options are tried in order: a held tool whose verb matches wins; otherwise
## the first bare-handed option that is not exhausted.
##
## Departures from the source, for a game without trade:
## - A boulder gives a loose stone by hand (so a fire ring needs no pick);
##   breaking it with a pick gives more and takes it away.
## - Ore is broken with a pick OR dug with a mattock, and iron needs only iron,
##   so the first pick opens the iron rung. Copper (not in the source) needs steel.
## - Driftwood comes two at a time: the first fire should not be a chore.
## - Any tree gives dead wood by hand, and a ruin gives a little plate, so the
##   way in (a fire, a haft, a pick) opens inland as well as on the shore.

const NEVER := -1.0

const TOOL_VERBS: Array[StringName] = [&"break", &"dig", &"fell", &"cut"]

## The source gates shore food on the tide. The water does not yet visibly
## move, so an invisible gate would read as a bug; the data keeps the tide and
## this switch turns it on when the shore shows it.
const TIDE_GATES := false

static var _table: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		_table = _build()
	return _table


static func _o(verb: StringName, item: StringName, n: int, minutes: float, regrow: float, extra: Dictionary = {}) -> Dictionary:
	var o := {"verb": verb, "item": item, "n": n, "min": minutes, "regrow": regrow,
		"stuff": &"", "uses": 1, "keep": false, "tide": &"", "bonus": [], "ground": []}
	o.merge(extra, true)
	return o


static func _build() -> Dictionary:
	var t := {}
	var fell_tree := _o(&"fell", &"timber", 2, 18.0, NEVER, {"stuff": &"iron"})
	# Fallen wood under a crown, picked up by hand: a live tree drops a little, slowly.
	var deadfall := _o(&"gather", &"deadwood", 1, 5.0, 36.0, {"keep": true})
	var resin := _o(&"tap", &"resin", 1, 8.0, 96.0, {"keep": true})
	t[PropKind.PINE] = [fell_tree, deadfall, resin]
	t[PropKind.SNOW_PINE] = [fell_tree, deadfall, resin]
	t[PropKind.BROADLEAF] = [fell_tree, deadfall]
	# A dead tree sheds its own limbs: more of them, and they come back sooner.
	t[PropKind.DEAD_TREE] = [_o(&"fell", &"timber", 1, 11.0, NEVER, {"stuff": &"iron"}),
		_o(&"gather", &"deadwood", 2, 6.0, 24.0, {"keep": true, "uses": 2})]
	t[PropKind.BUSH] = [
		_o(&"gather", &"samphire", 1, 5.0, 18.0, {"keep": true, "ground": [Ground.SAND, Ground.SHINGLE, Ground.MUD]}),
		_o(&"gather", &"berries", 1, 5.0, 36.0, {"keep": true, "ground": [Ground.GRASS, Ground.HEATH, Ground.MOSS,
			Ground.NEEDLES, Ground.SNOW, Ground.BONE, Ground.ASH, Ground.ROCK, Ground.GRAVEL, Ground.SCREE,
			Ground.LIMESTONE, Ground.PEAT, Ground.FLOOR, Ground.ROAD, Ground.CLINKER]}),
	]
	t[PropKind.REEDS] = [_o(&"cut", &"reeds", 2, 7.0, 24.0, {"stuff": &"iron"})]
	t[PropKind.GORSE] = [_o(&"cut", &"gorse_cut", 1, 9.0, 72.0, {"stuff": &"iron"})]
	t[PropKind.PEAT_BANK] = [_o(&"cut", &"peat", 3, 10.0, NEVER, {"stuff": &"iron", "uses": 2}),
		_o(&"dig", &"peat", 3, 10.0, NEVER, {"stuff": &"iron", "uses": 2})]
	# Rock out in the snow grows crottle on its crust: scraped by hand once the loose stone is had.
	var crottle := _o(&"scrape", &"crottle", 1, 12.0, 240.0, {"keep": true, "ground": [Ground.SNOW, Ground.ICE]})
	t[PropKind.BOULDER] = [
		_o(&"break", &"stone", 2, 20.0, NEVER, {"stuff": &"iron", "uses": 2}),
		_o(&"gather", &"stone", 1, 10.0, 24.0, {"keep": true}),
		crottle,
	]
	t[PropKind.STONE_ORE] = [
		_o(&"break", &"stone", 2, 14.0, NEVER, {"stuff": &"iron", "uses": 3}),
		_o(&"gather", &"stone", 1, 10.0, 24.0, {"keep": true}),
		crottle,
	]
	# A fallen roof was patched in plate: turned over by hand, a piece or two comes out of the rubble.
	t[PropKind.RUIN] = [_o(&"break", &"stone", 2, 25.0, NEVER, {"stuff": &"iron", "uses": 2}),
		_o(&"turn", &"scrap", 1, 60.0, 96.0, {"keep": true})]
	t[PropKind.CLINTS] = [_o(&"break", &"limestone", 2, 13.0, NEVER, {"stuff": &"iron", "uses": 2})]
	for pair: Array in [[PropKind.COAL_ORE, &"coal", 22.0, &"iron"], [PropKind.TIN_ORE, &"tin_ore", 22.0, &"iron"],
			[PropKind.IRON_ORE, &"iron_ore", 30.0, &"iron"], [PropKind.COPPER_ORE, &"copper_ore", 34.0, &"steel"]]:
		t[pair[0]] = [
			_o(&"break", pair[1], 1, pair[2], NEVER, {"stuff": pair[3], "uses": 3}),
			_o(&"dig", pair[1], 1, pair[2], NEVER, {"stuff": pair[3], "uses": 3}),
		]
	t[PropKind.MUSSEL_ROCK] = [_o(&"gather", &"mussels", 1, 6.0, 12.0, {"keep": true, "uses": 2, "tide": &"low", "bonus": [&"whelks", 0.35]})]
	t[PropKind.DRIFTWOOD] = [_o(&"gather", &"driftwood", 2, 3.0, 12.0)]
	t[PropKind.WRACK] = [_o(&"gather", &"wrack", 2, 4.0, 6.0)]
	t[PropKind.TIP] = [
		_o(&"dig", &"scrap", 1, 45.0, 48.0, {"stuff": &"iron", "keep": true, "uses": 3}),
		_o(&"turn", &"scrap", 1, 90.0, 48.0, {"keep": true, "uses": 2}),
	]
	t[PropKind.WRECK] = [_o(&"break", &"scrap", 2, 120.0, NEVER, {"stuff": &"iron", "uses": 2})]
	t[PropKind.POLE] = [_o(&"break", &"scrap", 1, 90.0, NEVER, {"stuff": &"iron"})]
	t[PropKind.PYLON] = [_o(&"break", &"scrap", 2, 150.0, NEVER, {"stuff": &"steel", "uses": 3})]
	t[PropKind.VENT] = [_o(&"dig", &"brimstone", 1, 16.0, 72.0, {"stuff": &"iron", "keep": true, "uses": 2})]
	# What was lost (landscape: props/remains.gd) is salvage. Loose debris is
	# picked up for good; a car or a barricade is broken for its plate, or picked
	# over by hand; a beached hull gives planks and its fittings; a fence gives a
	# post to an axe and a rail to a hand; a stump is the last of a tree.
	t[PropKind.DEBRIS] = [_o(&"turn", &"scrap", 1, 30.0, NEVER)]
	t[PropKind.VEHICLE] = [_o(&"break", &"scrap", 2, 100.0, NEVER, {"stuff": &"iron", "uses": 2}),
		_o(&"turn", &"scrap", 1, 60.0, 96.0, {"keep": true})]
	t[PropKind.BARRICADE] = [_o(&"break", &"scrap", 2, 80.0, NEVER, {"stuff": &"iron"}),
		_o(&"turn", &"scrap", 1, 50.0, 120.0, {"keep": true})]
	t[PropKind.HULL] = [_o(&"break", &"scrap", 1, 120.0, NEVER, {"stuff": &"iron", "uses": 3}),
		_o(&"gather", &"driftwood", 1, 8.0, 48.0, {"keep": true})]
	t[PropKind.FENCE] = [_o(&"fell", &"timber", 1, 12.0, NEVER, {"stuff": &"iron"}),
		_o(&"gather", &"deadwood", 1, 5.0, 72.0, {"keep": true})]
	t[PropKind.STUMP] = [_o(&"fell", &"timber", 1, 14.0, NEVER, {"stuff": &"iron"}),
		_o(&"gather", &"deadwood", 1, 5.0, 48.0, {"keep": true})]
	return t


static func workable(kind: int) -> bool:
	return table().has(kind)


static func options(kind: int) -> Array:
	return table().get(kind, [])


## Tide height 0..1 at a world minute: two tides per 24 h 50 m, t=0 low. (source §5)
static func tide(minutes: float) -> float:
	return 0.5 - 0.5 * cos(TAU * fposmod(minutes, 1490.0) / 745.0)


static func tide_is_low(minutes: float) -> bool:
	return tide(minutes) < 0.34


## Choose how a prop would be worked with `held`. `exhausted` is a Callable
## (option index -> bool). Returns:
##   {ok: true, index, option}                 it can be worked now
##   {ok: false, index, option, why: reason}   it cannot; why is one of
##       &"hands" (needs a tool you do not hold), &"hard" (tool too soft),
##       &"spent" (picked over, comes back later), &"tide" (water over it), &"none"
static func choose(kind: int, ground: int, held: StringName, exhausted: Callable, minutes: float) -> Dictionary:
	var opts := options(kind)
	if opts.is_empty():
		return {"ok": false, "index": -1, "option": {}, "why": &"none"}
	var held_verb := Items.verb(held)
	var fallback := {}
	# 1. The held tool's verb.
	for i in opts.size():
		var o: Dictionary = opts[i]
		if held_verb == &"" or o.verb != held_verb or not _on_ground(o, ground):
			continue
		if not Items.hard_enough(held, o.stuff):
			fallback = {"ok": false, "index": i, "option": o, "why": &"hard"}
			continue
		if exhausted.call(i):
			fallback = {"ok": false, "index": i, "option": o, "why": &"spent"}
			continue
		return {"ok": true, "index": i, "option": o}
	# 2. Bare hands.
	for i in opts.size():
		var o: Dictionary = opts[i]
		if TOOL_VERBS.has(o.verb) or not _on_ground(o, ground):
			continue
		if exhausted.call(i):
			if fallback.is_empty():
				fallback = {"ok": false, "index": i, "option": o, "why": &"spent"}
			continue
		if TIDE_GATES and o.tide == &"low" and not tide_is_low(minutes):
			fallback = {"ok": false, "index": i, "option": o, "why": &"tide"}
			continue
		return {"ok": true, "index": i, "option": o}
	if not fallback.is_empty():
		return fallback
	for i in opts.size():
		if _on_ground(opts[i], ground):
			return {"ok": false, "index": i, "option": opts[i], "why": &"hands"}
	return {"ok": false, "index": -1, "option": {}, "why": &"none"}


static func _on_ground(o: Dictionary, ground: int) -> bool:
	var g: Array = o.ground
	return g.is_empty() or g.has(ground)


## The player-facing line for a refusal reason. The first two are the source's.
static func refusal(why: StringName, held: StringName) -> String:
	match why:
		&"hands":
			return "Not with your hands." if Items.verb(held) == &"" else "Not with that."
		&"hard":
			return "It rings, and nothing comes away."
		&"spent":
			return "There is nothing more on it yet."
		&"tide":
			return "The water is over it."
	return ""
