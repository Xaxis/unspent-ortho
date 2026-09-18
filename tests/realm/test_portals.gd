extends TestCase
## Where the ways between realms are: every world has one, they are the same
## places every time the world is grown, they stand on ground a body can walk to,
## and a shaft on one side is paired with the shaft of the same number on the
## other.

const SIZE := 192
const SEEDS: Array[int] = [1, 7, 42]


static func world_of(seed_value: int, realm: StringName) -> WorldData:
	return WorldGen.generate(Realm.seed_for(seed_value, realm), SIZE, &"", realm)


func test_a_world_of_each_realm_holds_a_shaft() -> void:
	# Every world has a way out of it, or a realm can be generated and never
	# reached: the rule loosens rather than gives up (Portals._lay).
	for s in SEEDS:
		for realm: StringName in [Realm.SURFACE, Realm.UNDERGROUND]:
			var w := world_of(s, realm)
			var all := Portals.in_world(w)
			gt(float(all.size()), 0.0, "seed %d %s has a shaft" % [s, realm])
			check(all.size() <= Portals.MOST, "seed %d %s keeps to a handful" % [s, realm])
			for i in all.size():
				var p := all[i]
				eq(p.id, i, "shafts are numbered in order")
				eq(p.realm, realm, "seed %d shaft %d knows its realm" % [s, p.id])
				eq(p.to_realm, Realm.beyond(realm), "and where it opens onto")
				check(w.level_at(floori(p.pos.x), floori(p.pos.y)) > 0,
					"seed %d %s shaft %d stands on land" % [s, realm, p.id])
				check(not Ground.is_water(w.ground_at(floori(p.pos.x), floori(p.pos.y))),
					"seed %d %s shaft %d is not in the water" % [s, realm, p.id])


func test_the_same_world_puts_its_shafts_in_the_same_places() -> void:
	# A save keeps a seed and grows the world again, so a shaft that moved
	# between two runs of the same seed would move under a player's feet.
	for s in SEEDS:
		Portals.forget()
		var a := Portals.in_world(world_of(s, Realm.UNDERGROUND)).duplicate()
		Portals.forget()
		var b := Portals.in_world(world_of(s, Realm.UNDERGROUND))
		eq(b.size(), a.size(), "seed %d lays the same number of shafts twice" % s)
		for i in mini(a.size(), b.size()):
			eq(b[i].pos, a[i].pos, "seed %d shaft %d is in the same place" % [s, i])
			near(b[i].facing, a[i].facing, 1e-5, "seed %d shaft %d faces the same way" % [s, i])


func test_a_shaft_is_paired_with_the_one_of_its_number_on_the_far_side() -> void:
	for s in SEEDS:
		var up := world_of(s, Realm.SURFACE)
		var down := world_of(s, Realm.UNDERGROUND)
		for p in Portals.in_world(up):
			var far := Portals.paired(down, p.id)
			check(far != null, "seed %d shaft %d has a shaft to come out of" % [s, p.id])
			if far == null:
				continue
			var land := Portals.landing(down, p.id)
			lt(land.distance_to(far.pos), 9.0, "and a body lands beside it, not across the hall")
			check(down.level_at(floori(land.x), floori(land.y)) > 0, "on land")
			check(not Ground.is_water(down.ground_at(floori(land.x), floori(land.y))), "and out of the water")
			gt(land.distance_to(far.pos), 0.4, "and not inside the mouth it just came out of")


func test_the_nearest_shaft_is_the_nearest_one() -> void:
	var w := world_of(1, Realm.SURFACE)
	var all := Portals.in_world(w)
	check(not all.is_empty(), "there is a shaft to find")
	if all.is_empty():
		return
	var at: Vector2 = all[all.size() - 1].pos + Vector2(3, 3)
	var near_one := Portals.nearest(w, at)
	check(near_one != null, "something is nearest")
	for p in all:
		check(near_one.pos.distance_to(at) <= p.pos.distance_to(at) + 1e-4,
			"shaft %d is no nearer than the nearest" % p.id)
	check(near_one.within(near_one.pos + Vector2(1.0, 0.0)), "a body a tile away is in reach")
	check(not near_one.within(near_one.pos + Vector2(20.0, 0.0)), "one across the hall is not")


func test_a_shaft_reads_back_the_same_off_a_save() -> void:
	var w := world_of(7, Realm.UNDERGROUND)
	for p in Portals.in_world(w):
		var back := Portal.from_dict(p.to_dict())
		eq(back.id, p.id)
		eq(back.pos, p.pos)
		eq(back.realm, p.realm)
		eq(back.to_realm, p.to_realm)
		eq(back.open, p.open)
		near(back.facing, p.facing, 1e-6)


## A WAY DOWN ON EVERY LANDMASS PEOPLE LIVE ON. `MOST` is a cap for one island and
## it was still being applied to a whole archipelago: measured on seed 1 at 1024,
## the first continent to yield a shaft took every slot and the world came out with
## ONE portal while people lived on four continents — three a player could sail to
## and never leave. Asked for by the story session, whose spine sends a player
## across the water and then below it.
func test_every_landmass_anyone_lives_on_has_a_way_out() -> void:
	for pair: Array in [[1, 512], [1, 1024], [7, 1024]]:
		var w := WorldGen.generate(int(pair[0]), int(pair[1]))
		var lived := {}
		for v: Dictionary in w.villages:
			var p: Vector2 = v.pos
			var b := w.continent_at(floori(p.x), floori(p.y))
			if b != 0:
				lived[b] = true
		var served := {}
		for pt: Portal in Portals.in_world(w):
			served[w.continent_at(floori(pt.pos.x), floori(pt.pos.y))] = true
		check(not lived.is_empty(), "seed %d at %d: somebody lives somewhere" % pair)
		for b: int in lived:
			check(served.has(b), "seed %d at %d: people live on body %d and it has no shaft" % [pair[0], pair[1], b])
