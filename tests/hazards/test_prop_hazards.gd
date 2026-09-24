extends TestCase
## A THING presses a body on top of the land it stands on (docs/LANDSCAPES.md,
## shared system 3): a vent's breath, a fire's warmth, a heap's pull, the hum
## under a pylon. The rows are `PropHazards.TABLE`; `Hazards.felt` reads them
## through `Place.near_props`, and 52_hazards fills that off the tile index once
## a sweep. The land's declaration stays the base: a prop is a step on it.

var game: Game


static func place(hazards: Dictionary, hour: float = 12.0) -> Hazards.Place:
	var p := Hazards.Place.new()
	p.hazards = hazards
	p.hour = hour
	return p


static func thing(kind: int, at: Vector2, id: int = 1) -> WorldProp:
	return WorldProp.new(id, kind, at, 0.0, 1.0)


static func felt_of(p: Hazards.Place, id: StringName) -> float:
	return float(Hazards.felt(p).get(id, 0.0))


## (a) Same landscape, same hour, same sky: only the vent differs.
func test_a_body_beside_a_vent_breathes_worse_air_than_one_ten_tiles_off() -> void:
	var row: Dictionary = PropHazards.near(PropKind.VENT)[0]
	eq(row.id, &"fumes", "a vent's row is its breath")
	var beside := place({&"fumes": 0.5})
	beside.near_props = [thing(PropKind.VENT, Vector2.ZERO)]
	var off := place({&"fumes": 0.5})
	off.near_props = [thing(PropKind.VENT, Vector2(10.0, 0.0))]
	var at_mouth := felt_of(beside, &"fumes")
	var away := felt_of(off, &"fumes")
	gt(at_mouth, away, "the air at the mouth of a vent is worse than the land's")
	near(away, 0.5, 1e-5, "and ten tiles off it is the land's own, to the digit")
	near(at_mouth, 0.5 + float(row.add), 1e-5, "declared plus what a vent adds, at the vent")
	# The Burning declares fumes just under BITE on purpose (CLAUDE.md, Pressures):
	# the vent is the thing that takes them over it, and that is the gauge a
	# player reads to learn that a vent is a thing to walk round.
	lt(away, Hazards.BITE, "the land's own air is noticed")
	gt(at_mouth, Hazards.BITE, "the vent's is not for breathing")
	# ...and a vent presses nothing the land did not know about: a kind with no
	# row is not a source, however close it stands.
	var stone := place({&"fumes": 0.5})
	stone.near_props = [thing(PropKind.BOULDER, Vector2.ZERO)]
	near(felt_of(stone, &"fumes"), 0.5, 1e-5, "a boulder adds nothing")


## (c) `add` at the prop, falling STRAIGHT to nothing at `reach`, and nothing
## past it.
func test_the_add_falls_off_in_a_straight_line_to_nothing_at_reach() -> void:
	var row: Dictionary = PropHazards.near(PropKind.VENT)[0]
	var reach := float(row.reach)
	var add := float(row.add)
	for k in 7:
		var share := float(k) / 6.0
		var p := place({})
		p.near_props = [thing(PropKind.VENT, Vector2(reach * share, 0.0))]
		near(felt_of(p, &"fumes"), add * (1.0 - share), 1e-5, "at %.2f of the reach" % share)
	var past := place({})
	past.near_props = [thing(PropKind.VENT, Vector2(reach + 0.5, 0.0))]
	near(felt_of(past, &"fumes"), 0.0, 1e-9, "and nothing past it")
	# Distance is the body's, not the origin's: the same vent read from a body
	# standing on it.
	var on_it := place({})
	on_it.pos = Vector2(40.0, 40.0)
	on_it.near_props = [thing(PropKind.VENT, Vector2(40.0, 40.0))]
	near(felt_of(on_it, &"fumes"), add, 1e-5, "measured from where the body stands")


## A cluster is one source, and the whole never goes past one.
func test_a_yard_of_vents_presses_like_a_vent_and_never_past_one() -> void:
	var row: Dictionary = PropHazards.near(PropKind.VENT)[0]
	var one := place({&"fumes": 0.5})
	one.near_props = [thing(PropKind.VENT, Vector2.ZERO)]
	var three := place({&"fumes": 0.5})
	three.near_props = [thing(PropKind.VENT, Vector2.ZERO, 1), thing(PropKind.VENT, Vector2(0.4, 0.0), 2),
		thing(PropKind.VENT, Vector2(0.0, 0.6), 3)]
	near(felt_of(three, &"fumes"), felt_of(one, &"fumes"), 1e-5, "three vents in a yard are one vent's air")
	# Nothing a thing adds carries a pressure past declared + add on a still
	# clear noon, and nothing carries it past 1.0 at all.
	var most := place({&"fumes": 0.9})
	most.near_props = [thing(PropKind.VENT, Vector2.ZERO, 1), thing(PropKind.VENT, Vector2(0.5, 0.0), 2)]
	near(felt_of(most, &"fumes"), 1.0, 1e-5, "the scale stops at one")
	lt(felt_of(one, &"fumes"), 0.5 + float(row.add) + 1e-6, "and never past declared plus the add")


## (e) A row gated on a weather family adds nothing under a clear sky — and
## nothing under some OTHER weather either: the gate is the family, not "any
## weather".
func test_a_weather_gated_row_adds_nothing_under_a_clear_sky() -> void:
	var rows := PropHazards.near(PropKind.PYLON)
	var plain := 0.0
	var gated: Array = []
	for row: Dictionary in rows:
		if row.weather == &"":
			plain += float(row.add)
		else:
			gated.append(row)
	check(not gated.is_empty(), "the pylon has a gated row, or this test proves nothing")
	var pylon := thing(PropKind.PYLON, Vector2.ZERO)
	var clear := place({})
	clear.near_props = [pylon]
	near(felt_of(clear, &"em"), plain, 1e-5, "under a clear sky only the everyday hum")
	# Drizzle is the rain family, which puts no em on anything: the pylon's
	# storm row stays shut.
	var wrong_weather := place({})
	wrong_weather.weather = &"drizzle"
	wrong_weather.weather_strength = 1.0
	wrong_weather.near_props = [pylon]
	near(felt_of(wrong_weather, &"em"), plain, 1e-5, "and under the wrong weather too")
	# In a storm the pylon is where the lightning goes. Its share is read against
	# the same storm in the open, so the sky's own em term is not counted to it,
	# and it is the storm row's add and not the two rows stacked (a cluster is
	# one source, and a prop's own rows are a cluster of one).
	var open := place({})
	open.weather = &"storm"
	open.weather_strength = 1.0
	var under := place({})
	under.weather = &"storm"
	under.weather_strength = 1.0
	under.near_props = [pylon]
	var share := felt_of(under, &"em") - felt_of(open, &"em")
	var largest := 0.0
	for row: Dictionary in rows:
		largest = maxf(largest, float(row.add))
	near(share, largest, 1e-5, "in a storm the pylon's share is its storm row")
	gt(share, plain, "which is more than its everyday hum")


## (d) The rot guard: every row names a hazard the model knows, a kind the
## world has, a gate spelled as a family, and an add that lights no gauge on
## its own. And every id a thing adds is one some landscape declares, because
## that is what `tests/gear` holds a wearable answer to — a row adding a
## pressure no land declares would be a pressure nothing can be worn against.
func test_every_row_names_a_real_hazard_a_real_kind_and_a_real_family() -> void:
	var families: Dictionary = {}
	for k: StringName in Weather.KINDS:
		families[Weather.family(k)] = true
	var declared: Dictionary = {}
	for d in BiomeRegistry.all():
		for id: Variant in d.hazards:
			declared[StringName(id)] = true
	check(not PropHazards.TABLE.is_empty(), "the table has rows")
	var furthest := 0.0
	for kind: Variant in PropHazards.TABLE:
		check(kind is int and int(kind) >= 0 and int(kind) < PropKind.COUNT, "%s is not a PropKind" % [kind])
		var rows: Array = PropHazards.TABLE[kind]
		check(not rows.is_empty(), "%s declares an empty table" % PropKind.NAMES[int(kind)])
		eq(rows, PropHazards.near(int(kind)), "near() is the table's own rows")
		for row: Dictionary in rows:
			var who := "%s's %s" % [PropKind.NAMES[int(kind)], row.get("id", "?")]
			for key: String in ["id", "reach", "add", "weather"]:
				check(row.has(key), "%s has no %s" % [who, key])
			check(Hazards.IDS.has(row.id), "%s is not a hazard" % who)
			check(declared.has(row.id), "%s: no landscape declares it, so nothing wearable answers it" % who)
			gt(float(row.reach), 0.0, "%s reaches nowhere" % who)
			gt(float(row.add), 0.0, "%s adds nothing" % who)
			lt(float(row.add), Hazards.FELT + 1e-6, "%s lights a gauge on its own" % who)
			var gate: StringName = row.weather
			check(gate == &"" or families.has(gate), "%s is gated on %s, which is not a weather family" % [who, gate])
			eq(Weather.family(gate), gate, "%s: a gate is spelled as the family, never as a kind" % who)
			furthest = maxf(furthest, float(row.reach))
	near(PropHazards.reach_most(), furthest, 1e-6, "the sweep looks as far as the furthest row")
	check(PropHazards.near(PropKind.BOULDER).is_empty(), "a kind with no row is not a source")


func _boot(extra: PackedStringArray = PackedStringArray()) -> Node:
	var args := PackedStringArray(["--seed=1", "--size=48", "--hour=12", "--weather=clear:0"])
	args.append_array(extra)
	game = Game.new()
	tree.root.add_child(game)
	game.setup(BootOptions.parse(args))
	return _system("52_hazards")


func _system(part: String) -> Node:
	for s in game.systems:
		if String(s.name).contains(part):
			return s
	return null


## Stand the body somewhere with nothing over it and nothing round it, so what
## the sweep reads is the vent and not the roof it happens to have spawned
## under: a tour's `at` moves the fight body too, and so does this.
func _stand_clear(sys: Node, also: Callable = Callable()) -> Vector2:
	var start := game.player.pos
	for ring in 24:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var p := start + Vector2(dx, dy)
				var tx := floori(p.x)
				var ty := floori(p.y)
				if not game.query.standable(tx, ty):
					continue
				if also.is_valid() and not also.call(p):
					continue
				_put_player(p)
				var here: Hazards.Place = sys.call("place")
				if here.shelter == 0.0 and not here.in_water and here.near_props.is_empty():
					return p
	fail("no clear ground within 24 tiles of the spawn")
	return start


func _put_player(p: Vector2) -> void:
	if game.player.hero != null:
		game.player.hero.pos = p
		game.player.hero.move = Vector2.ZERO
	game.player.pos = p
	game.player.position = game.world.to_3d(p)


## The system's half: the place carries what stands near the body, off the
## tile index, and (b) a thing already taken presses nothing.
func test_the_system_hands_felt_the_things_near_the_body_and_a_taken_one_presses_nothing() -> void:
	var sys := _boot()
	game.body.resist = {}
	var pos := _stand_clear(sys)
	sys.call("_sweep", 1.0)
	var before := float(game.body.pressure.get(&"fumes", 0.0))
	# At the body's own tile: a vent's add is FELT exactly at its mouth and under
	# it a step off, and the coast declares no fumes for it to sit on.
	var vent := Survival.add_prop(game, PropKind.VENT, pos)
	var p: Hazards.Place = sys.call("place")
	eq(p.pos, game.player.pos, "the place knows where the body stands")
	check(p.near_props.has(vent), "the vent beside the body is on the place")
	sys.call("_sweep", 1.0)
	gt(float(game.body.pressure.get(&"fumes", 0.0)), before, "and the body breathes it")
	check(sys.call("tour_seen", &"fumes"), "a tour asking `fumes` is answered beside it")
	var far := Survival.add_prop(game, PropKind.VENT, pos + Vector2(10.0, 0.0))
	p = sys.call("place")
	check(not p.near_props.has(far), "a vent ten tiles off is not even looked at")
	# (b) Taken, it presses nothing: the filter is the system's, at the index.
	game.world.depleted[vent.id] = INF
	p = sys.call("place")
	check(not p.near_props.has(vent), "a depleted vent is not on the place")
	sys.call("_sweep", 1.0)
	near(float(game.body.pressure.get(&"fumes", 0.0)), before, 1e-5, "and adds nothing")
	# The cost, stated in 52_hazards' own comment: a 9x9 block of cell lookups
	# once a sweep, never a walk of world.props.
	var us := TestCase.best_of(20, func() -> void: sys.call("_near_props", pos))
	print("  near props within %.1f tiles: %.1f us" % [PropHazards.reach_most(), us])
	cost_lt(us, 300.0, "finding the things that press the body, once a sweep")
	game.free()


## `bites:fumes` beside a vent, through the path a tour takes and nothing else.
## Staged with the weather the claim is about (CLAUDE.md, Pressures): ash on
## the coast is fumes felt in the open, and the vent is what takes them past
## BITE at its mouth. Nothing here reads the table's numbers back — the tour
## word is asked of `Body.pressure` exactly as 98_tour asks it.
func test_bites_fumes_is_answered_at_a_vent_through_the_tour_path() -> void:
	var sys := _boot(["--weather=ash:1"])
	game.body.resist = {}
	# Open ground in a land that does not breathe fumes itself: the Burning
	# declares them at 0.5 so ash makes them bite there on purpose (its own
	# file), and whichever landscape lies nearest the spawn is the world's
	# business -- once landscapes were resized it was the Burning.
	var pos := _stand_clear(sys, func(at: Vector2) -> bool:
		return not BiomeRegistry.at(game.world, at).hazards.has(&"fumes"))
	sys.call("_sweep", 1.0)
	check(sys.call("tour_seen", &"fumes"), "ash is felt in the open")
	check(not sys.call("tour_seen", &"bites:fumes"), "and does not bite there")
	Survival.add_prop(game, PropKind.VENT, pos)
	sys.call("_sweep", 1.0)
	check(sys.call("tour_seen", &"bites:fumes"), "at the vent's mouth it bites, and the tour word says so")
	game.free()
