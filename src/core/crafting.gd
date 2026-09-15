class_name Crafting
## Recipes and making. The data is src/content/recipes.gd; the UI package calls
## only these functions.
##
## A recipe: {id, at (hand fire bench kiln wheel loom), minutes, needs: {item: n},
##            makes: {item: n}, and optionally tool, keeps, builds, action}
## (full schema at the top of recipes.gd).
##
##   recipes_at(station) -> Array[Dictionary]   &"hand" = anywhere
##   recipe(id) -> Dictionary                   {} if unknown
##   can_make(inv, recipe) -> bool              carried inputs, tool, kept items, action target
##   missing(inv, recipe) -> {item: n short}
##   make(inv, recipe) -> bool                  moves the goods and mends; the CALLER charges
##                                              r.minutes. A build recipe puts its station in the
##                                              running game (see bind) and charges nothing either.
##   why_not(game, recipe) -> String            "" if make_in would succeed, else a line
##   make_in(game, recipe) -> bool              all of it in one call: station in reach, inputs,
##                                              builds, minutes charged, events
##   suggest(game) -> Dictionary                a sensible next thing to make here, or {}
##   bind(game)                                 the running game builds go into (50_survival calls it)

## Honing lifts the edge this much, up to HONE_CAP. (source)
const HONE_STEP := 2500
const HONE_CAP := 6000

static var _by_station: Dictionary = {}
static var _by_id: Dictionary = {}
static var _bound: WeakRef = null


## The running game whose inventory make() builds for: a crafting screen that
## only holds the inventory can still put a campfire in the world.
static func bind(game: Game) -> void:
	_bound = weakref(game) if game != null else null


static func _bound_game(inv: Inventory) -> Game:
	if _bound == null:
		return null
	var g := _bound.get_ref() as Game
	return g if g != null and g.inventory == inv else null


static func _index() -> void:
	if not _by_id.is_empty():
		return
	for r: Dictionary in Recipes.LIST:
		_by_id[r.id] = r
		var at: StringName = r.at
		if not _by_station.has(at):
			var list: Array[Dictionary] = []
			_by_station[at] = list
		(_by_station[at] as Array[Dictionary]).append(r)


static func recipes_at(station: StringName) -> Array[Dictionary]:
	_index()
	if station == &"":
		station = &"hand"
	var out: Array[Dictionary] = []
	if _by_station.has(station):
		out.assign(_by_station[station])
	return out


static func recipe(id: StringName) -> Dictionary:
	_index()
	return _by_id.get(id, {})


static func missing(inv: Inventory, r: Dictionary) -> Dictionary:
	var out := {}
	for group: String in ["needs", "keeps"]:
		var d: Dictionary = r.get(group, {})
		for id: StringName in d:
			var short: int = int(d[id]) - inv.count(id)
			if short > 0:
				out[id] = maxi(out.get(id, 0), short)
	return out


static func can_make(inv: Inventory, r: Dictionary) -> bool:
	if r.is_empty() or not missing(inv, r).is_empty():
		return false
	var tool: StringName = r.get("tool", &"")
	if tool != &"" and not _carries_verb(inv, tool):
		return false
	match r.get("action", &""):
		&"hone":
			return _mendable(inv) and inv.edge(inv.held) < HONE_CAP
		&"reedge":
			return _mendable(inv) and inv.edge(inv.held) < 10000
	return true


## Consumes, adds, mends. Time is the caller's to charge. A build needs the
## game bound to this inventory; without one it refuses.
static func make(inv: Inventory, r: Dictionary) -> bool:
	if not can_make(inv, r):
		return false
	var station: StringName = r.get("builds", &"")
	if station != &"":
		var g := _bound_game(inv)
		return g != null and Survival.build(g, station, false, false) != null
	for id: StringName in r.needs:
		inv.remove(id, r.needs[id])
	match r.get("action", &""):
		&"hone":
			inv.set_edge(inv.held, mini(inv.edge(inv.held) + HONE_STEP, HONE_CAP))
		&"reedge":
			inv.set_edge(inv.held, 10000)
	var makes: Dictionary = r.get("makes", {})
	for id: StringName in makes:
		inv.add(id, makes[id])
		Events.made.emit(id, makes[id])
		# You are holding what you just made, if your hands were empty or it does the same work better.
		if Items.has_edge(id) and _better_in_hand(inv, id):
			inv.set_held(id)
	return true


static func why_not(game: Game, r: Dictionary) -> String:
	if r.is_empty():
		return "There is no such thing."
	if r.at != &"hand" and not Survival.stations_near(game).has(r.at):
		return "Not without a %s." % r.at
	var tool: StringName = r.get("tool", &"")
	if tool != &"" and not _carries_verb(game.inventory, tool):
		return "Not without a blade."
	if not missing(game.inventory, r).is_empty():
		return "Not without what it needs."
	match r.get("action", &""):
		&"hone", &"reedge":
			if not _mendable(game.inventory):
				return "Nothing in hand to mend."
			if not can_make(game.inventory, r):
				return "It is as keen as that will make it."
	if Survival.busy(game):
		return "Not while your hands are full."
	return ""


static func make_in(game: Game, r: Dictionary) -> bool:
	var why := why_not(game, r)
	if why != "":
		Events.message.emit(why)
		return false
	var station: StringName = r.get("builds", &"")
	if station != &"":
		return Survival.build(game, station) != null
	var action: StringName = r.get("action", &"")
	if not make(game.inventory, r):
		return false
	if game.player != null and game.player.model != null:
		game.player.model.set_held(game.inventory.held)
		game.player.model.play_action(&"work", Survival.WORK_SECONDS)
	game.clock.skip(r.minutes)
	Events.time_skipped.emit(r.minutes, &"make")
	Events.sfx.emit(action if action != &"" else &"make", game.player.position)
	return true


## A sensible next thing to make with what is in reach: first a tool of a kind
## not yet carried, then a mend for a dull tool in hand, then smelting, then fuel,
## then food. {} if nothing can be made.
static func suggest(game: Game) -> Dictionary:
	var inv := game.inventory
	var best := {}
	var best_rank := -1
	for station in Survival.stations_near(game):
		for r in recipes_at(station):
			if r.get("builds", &"") != &"" or not can_make(inv, r):
				continue
			var rank := 1
			var makes: Dictionary = r.makes
			var action: StringName = r.get("action", &"")
			if action == &"reedge" and inv.edge(inv.held) <= Inventory.DULL_EDGE:
				rank = 8
			elif action != &"":
				rank = 0
			for id: StringName in makes:
				if Items.has_edge(id) and not _carries_verb(inv, Items.verb(id)):
					rank = 10
				elif Items.has_edge(id) and not inv.has(id):
					rank = maxi(rank, 6)
				elif id == &"iron" or id == &"tin" or id == &"copper":
					rank = maxi(rank, 5)
				elif id == &"haft":
					rank = maxi(rank, 4 if not inv.has(&"haft") else 1)
				elif id == &"charcoal":
					rank = maxi(rank, 3 if inv.count(&"charcoal") < 3 else 1)
				elif Items.feeds(id) > 0.0:
					rank = maxi(rank, 2)
			if rank > best_rank:
				best_rank = rank
				best = r
	return best


static func _carries_verb(inv: Inventory, verb: StringName) -> bool:
	if verb == &"":
		return false
	for id: StringName in inv.items:
		if Items.verb(id) == verb:
			return true
	return false


static func _mendable(inv: Inventory) -> bool:
	return inv.held != &"" and int(Items.def(inv.held).get("bite", 0)) > 0 and not Items.is_found(inv.held)


static func _better_in_hand(inv: Inventory, id: StringName) -> bool:
	if inv.held == &"" or inv.held == id:
		return true
	if Items.verb(inv.held) != Items.verb(id):
		return false
	return Items.STUFF_RANK.get(Items.stuff(id), 0) > Items.STUFF_RANK.get(Items.stuff(inv.held), 0)
