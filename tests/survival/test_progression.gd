extends TestCase
## The first ten minutes, played by a bot on generated worlds through the same
## calls the keys and the crafting screen make:
##   knife -> shore food and wood -> loose stone -> a campfire -> charcoal
##   -> a haft -> plate from a tip -> a pick -> iron ore -> iron -> an axe -> timber
##
## Honest: the bot may only use what is in the world after a game's setup (the
## generator, plus the strand survival lays near the spawn). It never places a
## thing; if what it needs is not within a walk, the test fails. It teleports
## between props but is charged real walking time for the distance, and the
## world clock runs through that walk the way it does in play, so the test also
## proves the path fits in ten real minutes and that the day is lived: work set
## going at the fire cooks while the bot walks, and the first pick comes out in
## the morning of the first day.

const Fx := preload("res://tests/survival/fixture.gd")
const REAL_BUDGET := 600.0
## Real seconds a person spends in a crafting screen per thing made.
const MENU_SECONDS := 4.0
## How far the bot will LOOK for anything. This is a search cap, not a budget:
## what says whether a start is playable is the ten real minutes below, and the
## clock already charges every step of the walk. A distance cap as well was a
## second and weaker assertion of the same thing, and it is the one that failed
## first -- when a landscape moved every seed's island, seed 2's nearest iron
## went to 162 tiles and this reported "nothing within 100 tiles gives iron_ore"
## about a start the bot had otherwise played straight through: wood, fire,
## charcoal, mussels, all of it.
##
## Measured then, spawn to the nearest prop that can give the item at all:
##     seed         1       2      3      4     42
##     iron_ore  44.5   162.4   29.8   30.1   32.9
##     timber     6.5     5.8    5.0    6.7   11.5
## Seed 2 is an outlier for ORE and perfectly ordinary for WOOD -- so its second
## failure, "nothing within 100 tiles gives timber", was a cascade and not a
## fact: no iron, so no iron axe, so the timber five tiles away is unworkable.
## A distance cap reports that as two faults in two materials. The clock reports
## it as one long walk, which is what it is. Let the clock judge.
const FAR := 220.0
const WOOD: Array[StringName] = [&"driftwood", &"deadwood"]
## The first pick is in hand by this hour of day 1 for a bot that gathers
## thoroughly and walks a far strand (seed 1 lands it before noon, seed 2 just
## after; the playtest's came at 20:48).
const FIRST_PICK_BY_HOUR := 13.0

var g: Game
var real := 0.0
var actions := 0
var log: PackedStringArray = []
var worst_hunger := 0
var seed_value := 0


func test_the_first_ten_minutes_on_seed_1() -> void:
	_play(1)


func test_the_first_ten_minutes_on_seed_2() -> void:
	_play(2)


func test_plate_alone_never_makes_more_than_the_way_in() -> void:
	for r: Dictionary in Recipes.LIST:
		var needs: Dictionary = r.needs
		for id: StringName in r.makes:
			if id in [&"axe_hand", &"mattock", &"billhook"]:
				check(needs.has(&"iron"), "%s makes %s without iron" % [r.id, id])
		if needs.has(&"scrap") and not needs.has(&"iron"):
			for id: StringName in r.makes:
				if Items.has_edge(id) and Items.verb(id) != &"":
					check(id in [&"knife", &"pick"], "plate alone makes only the way in, not %s (%s)" % [id, r.id])
		check(not ((r.makes as Dictionary).has(&"iron") and needs.has(&"scrap")), "iron comes from ore, not plate (%s)" % r.id)


func _play(s: int) -> void:
	seed_value = s
	g = Fx.from_world(WorldGen.generate(s), Tuning.START_HOUR)
	var laid := Strand.lay(g)
	var props_after_setup := g.world.props.size()
	var home := g.world.spawn

	# Food and fuel off the shore and from under the trees.
	_gather(&"mussels", 3)
	_gather_wood(11)
	_gather(&"stone", 2)
	eq(g.inventory.held, &"knife", "still only the knife")

	# A fire of our own, laid with two presses of `use` on open ground.
	var fire := _build_fire_near(home)
	check(fire != null, "built a campfire")
	if fire == null:
		_fail_out()
		return
	_note("fire")
	check(Survival.stations_near(g).has(&"fire"), "standing at it")
	_make_any([&"charcoal", &"charcoal_deadwood"])
	_make_any([&"haft", &"haft_deadwood"])
	_eat_if_hungry()

	# Plate turned over by hand on a tip.
	_gather(&"scrap", 2)
	_collect(fire)
	_make(&"pick_made")
	check(g.inventory.has(&"scrap"), "a spare plate left over")
	# The second haft may want another armful: how much the first run gave
	# depends on what lay nearest (two driftwood a take, one dead wood).
	if Crafting.why_not(g, Crafting.recipe(&"haft")) != "" and Crafting.why_not(g, Crafting.recipe(&"haft_deadwood")) != "":
		_gather_wood(2)
	_make_any([&"haft", &"haft_deadwood"])
	_collect(fire)
	check(g.inventory.has(&"pick"), "a pick")
	check(g.clock.day() == 0 and g.clock.hour() <= FIRST_PICK_BY_HOUR, "the first pick by early afternoon on day 1, not at night: %s" % g.clock.label())
	# Plate makes the way in and nothing more: the axe waits for iron.
	for r: Dictionary in Recipes.LIST:
		if (r.makes as Dictionary).has(&"axe_hand"):
			check(not Crafting.can_make(g.inventory, r), "no axe from plate: %s" % r.id)
	_eat_if_hungry()
	_sleep_if_night(fire)

	# Iron: the new pick breaks a vein; wood for the charcoal to smelt it.
	_gather(&"iron_ore", 3)
	eq(g.inventory.held, &"pick", "the pick went into the hand for the ore")
	_gather_wood(8)
	_gather(&"mussels", 2)
	_collect(fire)
	_make_any([&"charcoal", &"charcoal_deadwood"])
	_eat_if_hungry()
	_sleep_if_night(fire)
	_collect(fire)
	_make_any([&"charcoal", &"charcoal_deadwood"])
	_collect(fire)
	_make_any([&"iron", &"iron_coal"])
	_collect(fire)
	check(g.inventory.has(&"iron"), "iron")
	_eat_if_hungry()
	_make(&"axe_iron")
	_collect(fire)
	check(g.inventory.has(&"axe_hand"), "an iron axe")
	_eat_if_hungry()
	_sleep_if_night(fire)

	# The better tool reaches further: a tree comes down.
	Survival.hold(g, &"axe_hand")
	_gather(&"timber", 2)

	var hours := (g.clock.minutes - Tuning.START_HOUR * 60.0) / 60.0
	print("  info progression seed %d: %d laid, %d actions, %.0f real s, %.1f world h, ends %s, hunger worst %d" % [
		s, laid.size(), actions, real, hours, g.clock.label(), worst_hunger])
	eq(g.world.props.size(), props_after_setup + 1, "nothing was placed but the fire the bot built")
	lt(real, REAL_BUDGET, "fits in ten real minutes")
	lt(worst_hunger, 3, "never starving on the way")
	lt(hours, 48.0, "an iron axe inside two days")
	gt(hours, 4.0, "but it is not free: most of a day goes by")
	if not failures.is_empty() or OS.get_environment("PROGRESSION_LOG") != "":
		_fail_out()
	Fx.done(g)


func _note(s: String) -> void:
	log.append("%s  hunger %d load %2.0f  real %3.0f  %s" % [g.clock.label(), g.body.hunger_level(g.clock.minutes), g.inventory.bulk(), real, s])
	worst_hunger = maxi(worst_hunger, g.body.hunger_level(g.clock.minutes))


func _fail_out() -> void:
	print("       seed %d" % seed_value)
	for l in log:
		print("       | ", l)


func _walk_to(p: Vector2) -> void:
	_spend(g.player.pos.distance_to(p) / (Tuning.WALK_SPEED * g.body.move_factor))
	g.player.pos = p


## Real seconds of play: the world clock runs through them as it does in a game.
func _spend(seconds: float) -> void:
	real += seconds
	g.clock.advance(seconds)


## Back at the fire: wait out whatever is still on it (charged as real time
## spent there) and take what came off it.
func _collect(fire: WorldProp) -> void:
	_walk_to(_beside(fire))
	var job := Survival.job_at(g, fire)
	if not job.is_empty() and float(job.done) > g.clock.minutes:
		_spend((float(job.done) - g.clock.minutes) / Tuning.MINUTES_PER_SECOND)
	if Survival.collect(g) > 0:
		_note("took %s off the fire" % [job.get("recipe", &"")])


func _wood() -> int:
	var n := 0
	for id in WOOD:
		n += g.inventory.count(id)
	return n


func _gather_wood(n: int) -> void:
	var target := _wood() + n
	var tries := 0
	while _wood() < target and tries < 40:
		tries += 1
		if not _take_one(WOOD):
			return


func _gather(item: StringName, n: int) -> void:
	var target := g.inventory.count(item) + n
	var tries := 0
	while g.inventory.count(item) < target and tries < 40:
		tries += 1
		if not _take_one([item]):
			return


## Walk to the nearest prop that would give one of `items` now, stand in front of
## it, press `use` and finish the work. Fails the test if nothing within FAR gives it.
func _take_one(items: Array[StringName]) -> bool:
	var prop := _find(items)
	if prop == null and g.player.pos.distance_to(g.world.spawn) > 8.0:
		# Out in the hills: what is not here may be back down on the shore.
		_walk_to(g.world.spawn)
		prop = _find(items)
	if prop == null:
		fail("seed %d: nothing within %d tiles gives %s (the bot may not place anything)" % [seed_value, FAR, items])
		_fail_out()
		return false
	_stand_at(prop)
	var target := Survival.use_target(g)
	check(target == prop, "%s in front (got %s)" % [PropKind.NAMES[prop.kind], PropKind.NAMES[target.kind] if target else "nothing"])
	var before := g.inventory.items.duplicate()
	check(Survival.use(g), "use on %s: %s" % [PropKind.NAMES[prop.kind], Survival.describe_target(g)])
	Survival.finish_work(g)
	_spend(Survival.WORK_SECONDS)
	actions += 1
	var got := ""
	for id: StringName in g.inventory.items:
		if g.inventory.count(id) > int(before.get(id, 0)):
			got += "%s " % id
	check(got != "", "%s gave something" % PropKind.NAMES[prop.kind])
	_note("%s -> %s" % [PropKind.NAMES[prop.kind], got])
	Survival.update_body(g)
	_eat_if_hungry()
	return true


## What working `prop` would give now, with the held tool or one carried: the item id or &"".
func _gives(prop: WorldProp, state: SurvivalState) -> StringName:
	var c := Survival._choose(g, state, prop)
	if not c.ok:
		var alt := Survival._tool_for(g, state, prop)
		if alt == &"":
			return &""
		c = Survival._choose(g, state, prop, alt)
	return (c.option as Dictionary).item if c.ok else &""


func _find(items: Array[StringName]) -> WorldProp:
	var state := SurvivalState.of(g)
	var here := g.player.pos
	# Only kinds that can give one of `items` at all are worth a look.
	var kinds := {}
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			if items.has(o.item):
				kinds[kind] = true
	var near: Array = []
	var far2 := FAR * FAR
	for p in g.world.props:
		if not kinds.has(p.kind) or p.pos.distance_squared_to(here) > far2 or g.world.depleted.has(p.id):
			continue
		near.append([p.pos.distance_squared_to(here), p])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for pair: Array in near:
		var p: WorldProp = pair[1]
		if not items.has(_gives(p, state)):
			continue
		if _standing_spot(p).is_finite():
			return p
	return null


func _make(id: StringName) -> void:
	var r := Crafting.recipe(id)
	var why := Crafting.why_not(g, r)
	check(why == "", "seed %d make %s: %s (missing %s)" % [seed_value, id, why, Crafting.missing(g.inventory, r)])
	if Crafting.make_in(g, r):
		_spend(MENU_SECONDS)
		actions += 1
		_note("made %s" % id)


func _make_any(ids: Array[StringName]) -> void:
	for id in ids:
		if Crafting.why_not(g, Crafting.recipe(id)) == "":
			_make(id)
			return
	_make(ids[0])


func _build_fire_near(p: Vector2) -> WorldProp:
	for r in range(0, 12):
		for a in 8:
			_walk_to(p + Vector2.from_angle(a / 8.0 * TAU) * r)
			g.player.facing = a / 8.0 * TAU
			if not g.query.standable(floori(g.player.pos.x), floori(g.player.pos.y)):
				continue
			if Survival.describe_target(g) != "campfire - build?":
				continue
			var before := g.world.props.size()
			check(Survival.use(g), "the first press asks")
			eq(g.world.props.size(), before, "and builds nothing")
			check(Survival.use(g), "the second builds")
			_spend(1.0)
			actions += 2
			if g.world.props.size() > before:
				return g.world.props[-1]
	return null


func _beside(fire: WorldProp) -> Vector2:
	for a in 8:
		var s := fire.pos + Vector2.from_angle(a / 8.0 * TAU) * 1.2
		if g.query.standable(floori(s.x), floori(s.y)) and not Ground.is_water(g.world.ground_at(floori(s.x), floori(s.y))):
			return s
	return fire.pos + Vector2(1.2, 0)


func _eat_if_hungry() -> void:
	while g.body.hunger_level(g.clock.minutes) >= 1 and Survival.best_food(g) != &"":
		var food := Survival.best_food(g)
		g.body.busy_until = 0.0
		check(Survival.eat(g, food), "eat %s" % food)
		g.body.busy_until = 0.0
		_spend(1.0)
		_note("ate %s" % food)
	worst_hunger = maxi(worst_hunger, g.body.hunger_level(g.clock.minutes))


func _sleep_if_night(fire: WorldProp) -> void:
	_walk_to(_beside(fire))
	if Survival.sleep_refusal(g) == "":
		check(Survival.sleep(g), "sleep")
		_spend(2.0)
		_note("slept")
		_eat_if_hungry()


## A dry spot beside `p` from which `use` targets `p` itself.
func _standing_spot(p: WorldProp) -> Vector2:
	var keep_pos := g.player.pos
	var keep_facing := g.player.facing
	var out := Vector2(INF, INF)
	for a in 16:
		var dir := Vector2.from_angle(a / 16.0 * TAU + PI)
		var s := p.pos + dir * (p.solid + Tuning.PLAYER_RADIUS + 0.2)
		if not g.query.standable(floori(s.x), floori(s.y)) or Ground.is_water(g.world.ground_at(floori(s.x), floori(s.y))):
			continue
		g.player.pos = s
		g.player.facing = (p.pos - s).angle()
		if Survival.use_target(g) == p:
			out = s
			break
	g.player.pos = keep_pos
	g.player.facing = keep_facing
	return out


func _stand_at(p: WorldProp) -> void:
	var s := _standing_spot(p)
	_walk_to(s)
	g.player.facing = (p.pos - s).angle()
