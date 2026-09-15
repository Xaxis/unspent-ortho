extends TestCase
## The first ten minutes, played by a bot on a generated coast through the same
## calls the keys and the crafting screen make:
##   knife -> shore food and driftwood -> loose stone -> a campfire -> charcoal
##   -> a haft -> plate from a tip -> a pick -> iron ore -> iron -> an axe -> timber
## The bot teleports between props but is charged real walking time for the
## distance, so the test also proves the path fits in ten real minutes. Props the
## generator does not place yet are put near the spawn, on clear flat ground.

const Fx := preload("res://tests/survival/fixture.gd")
const REAL_BUDGET := 600.0
## Real seconds a person spends in a crafting screen per thing made.
const MENU_SECONDS := 4.0

var g: Game
var real := 0.0
var actions := 0
var log: PackedStringArray = []
var worst_hunger := 0


func test_the_first_ten_minutes_lead_from_a_knife_to_an_iron_axe() -> void:
	g = Fx.from_world(WorldGen.generate(1), Tuning.START_HOUR)
	var home := g.world.spawn

	# Food and fuel off the shore.
	for i in 2:
		_take(PropKind.MUSSEL_ROCK, &"mussels")
		_take(PropKind.MUSSEL_ROCK, &"mussels")
	_take(PropKind.WRACK, &"wrack")
	while g.inventory.count(&"driftwood") < 9:
		_take(PropKind.DRIFTWOOD, &"driftwood")
	# Two loose stones: a boulder gives one by hand, then it is picked over.
	while g.inventory.count(&"stone") < 2:
		_take(PropKind.BOULDER, &"stone")
	eq(g.inventory.held, &"knife", "still only the knife")

	# A fire of our own.
	_walk_to(home)
	var fire := Survival.build_fire(g)
	check(fire != null, "built a campfire")
	if fire == null:
		_fail_out()
		return
	_note("fire")
	check(Survival.stations_near(g).has(&"fire"), "standing at it")
	_make(&"charcoal")
	_make(&"haft")
	_eat_if_hungry()

	# Plate from a tip, turned over by hand.
	_take(PropKind.TIP, &"scrap")
	_take(PropKind.TIP, &"scrap")
	eq(g.inventory.count(&"scrap"), 2, "two plates off the tip")

	_walk_to(fire.pos + Vector2(1.2, 0))
	_make(&"pick_made")
	check(g.inventory.has(&"pick"), "a pick")
	_make(&"soup")
	_eat_if_hungry()
	_sleep_if_night(fire)

	# A new day on the shore: the mussels have come back.
	for i in 2:
		_take(PropKind.MUSSEL_ROCK, &"mussels")
		_take(PropKind.MUSSEL_ROCK, &"mussels")
	_eat_if_hungry()

	# Iron: the new pick breaks a vein and the coal to smelt it; driftwood for charcoal.
	for i in 3:
		_take(PropKind.IRON_ORE, &"iron_ore")
	eq(g.inventory.held, &"pick", "the pick went into the hand for the ore")
	while g.inventory.count(&"coal") < 2:
		_take(PropKind.COAL_ORE, &"coal")
	while g.inventory.count(&"driftwood") < 6:
		_take(PropKind.DRIFTWOOD, &"driftwood")
	_walk_to(fire.pos + Vector2(1.2, 0))
	_make(&"charcoal")
	_make(&"iron_coal")
	check(g.inventory.has(&"iron"), "iron")
	_eat_if_hungry()
	_make(&"haft")
	_make(&"axe_iron")
	check(g.inventory.has(&"axe_hand"), "an iron axe")
	_eat_if_hungry()
	_sleep_if_night(fire)

	# The better tool reaches further: a tree comes down.
	Survival.hold(g, &"axe_hand")
	_take(PropKind.PINE, &"timber")
	check(g.inventory.count(&"timber") >= 2, "timber")

	var hours := (g.clock.minutes - Tuning.START_HOUR * 60.0) / 60.0
	print("  info progression: %d actions, %.0f real s, %.1f world h, ends %s, hunger worst %d" % [
		actions, real, hours, g.clock.label(), worst_hunger])
	lt(real, REAL_BUDGET, "fits in ten real minutes")
	lt(worst_hunger, 3, "never starving on the way")
	lt(hours, 60.0, "an iron axe inside two and a half days")
	gt(hours, 16.0, "but it is not free: at least a night goes by")
	check(g.clock.day() >= 1, "a night went by")
	if not failures.is_empty() or OS.get_environment("PROGRESSION_LOG") != "":
		_fail_out()
	Fx.done(g)


func _note(s: String) -> void:
	log.append("%s  hunger %d load %2.0f  %s" % [g.clock.label(), g.body.hunger_level(g.clock.minutes), g.inventory.bulk(), s])
	worst_hunger = maxi(worst_hunger, g.body.hunger_level(g.clock.minutes))


func _fail_out() -> void:
	for l in log:
		print("       | ", l)


func _walk_to(p: Vector2) -> void:
	real += g.player.pos.distance_to(p) / Tuning.WALK_SPEED
	g.player.pos = p


## Find the nearest untaken prop of `kind` that gives `item` now, or put one
## near the spawn; stand in front of it; use.
func _take(kind: int, item: StringName) -> void:
	var prop := _find(kind)
	if prop == null:
		prop = _place(kind)
	if prop == null:
		fail("nowhere to put a %s" % PropKind.NAMES[kind])
		return
	_stand_at(prop)
	var before := g.inventory.count(item)
	var target := Survival.use_target(g)
	check(target != null and target.kind == kind, "%s in front (got %s)" % [PropKind.NAMES[kind], PropKind.NAMES[target.kind] if target else "nothing"])
	check(Survival.use(g), "use on %s: %s" % [PropKind.NAMES[kind], Survival.describe_target(g)])
	Survival.finish_work(g)
	real += Survival.WORK_SECONDS
	actions += 1
	check(g.inventory.count(item) > before, "%s gave %s" % [PropKind.NAMES[kind], item])
	_note("%s -> %s (%d)" % [PropKind.NAMES[kind], item, g.inventory.count(item)])
	Survival.update_body(g)


func _make(id: StringName) -> void:
	var r := Crafting.recipe(id)
	var why := Crafting.why_not(g, r)
	check(why == "", "make %s: %s (missing %s)" % [id, why, Crafting.missing(g.inventory, r)])
	if Crafting.make_in(g, r):
		real += MENU_SECONDS
		actions += 1
		_note("made %s" % id)


func _eat_if_hungry() -> void:
	while g.body.hunger_level(g.clock.minutes) >= 1 and Survival.best_food(g) != &"":
		var food := Survival.best_food(g)
		g.body.busy_until = 0.0
		check(Survival.eat(g, food), "eat %s" % food)
		g.body.busy_until = 0.0
		real += 1.0
		_note("ate %s" % food)


func _sleep_if_night(fire: WorldProp) -> void:
	_walk_to(fire.pos + Vector2(1.2, 0))
	if Survival.sleep_refusal(g) == "":
		check(Survival.sleep(g), "sleep")
		real += 2.0
		_note("slept")
		_eat_if_hungry()


func _find(kind: int) -> WorldProp:
	var best: WorldProp = null
	var best_d := 90.0
	var state := SurvivalState.of(g)
	for p in g.world.props:
		if p.kind != kind or g.world.depleted.has(p.id):
			continue
		var spent := false
		for i in Takes.options(kind).size():
			if state.spent.has(SurvivalState.key(p.id, i)):
				spent = true
		if spent or not _standing_spot(p).is_finite():
			continue
		var d := p.pos.distance_to(g.player.pos)
		if d < best_d:
			best_d = d
			best = p
	return best


func _place(kind: int) -> WorldProp:
	var home := g.world.spawn
	for r in range(5, 40):
		for a in 24:
			var s := (home + Vector2.from_angle(a / 24.0 * TAU + r) * r).floor() + Vector2(0.5, 0.5)
			var level := g.world.level_at(floori(s.x), floori(s.y))
			if level <= 0 or not Survival._clear(g, s, 1.2, level):
				continue
			return Survival.add_prop(g, kind, s)
	return null


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
