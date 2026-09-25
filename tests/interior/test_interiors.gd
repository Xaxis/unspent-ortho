extends TestCase
## Enterable structures, the pure half (docs/interiors): which things have
## doors, and what a pocket behind one is.

var _w: WorldData


func _world() -> WorldData:
	if _w == null:
		_w = BootWorld.world(4, 256)
	return _w


func _sig(p: InteriorGen.Pocket) -> String:
	var s := "%d|" % p.layout.size
	for r: Rect2i in p.layout.rooms:
		s += str(r)
	return s + "|%s|%s|%s" % [str(p.layout.door), str(p.layout.hearth), str(p.layout.table)]


func test_the_table_is_sound() -> void:
	for line in Interiors.problems():
		fail(line)
	check(Interiors.problems().is_empty(), "the interiors table is sound")


func test_the_same_house_grows_the_same_rooms_and_its_neighbour_its_own() -> void:
	var doors := Interiors.thresholds(_world())
	gt(float(doors.size()), 1.0, "the coast's houses have doors (%d)" % doors.size())
	if doors.size() < 2:
		return
	var a := InteriorGen.grow(4, doors[0])
	var again := InteriorGen.grow(4, doors[0])
	eq(_sig(again), _sig(a), "the same house, the same rooms")
	var differ := 0
	for t: Threshold in doors.slice(1, 9):
		if _sig(InteriorGen.grow(4, t)) != _sig(a):
			differ += 1
	gt(float(differ), 0.0, "and the houses round it are not all the same house")


func test_a_pocket_keeps_its_own_word() -> void:
	for t: Threshold in Interiors.thresholds(_world()).slice(0, 12):
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		eq(p.world.realm, Realm.INTERIOR, "%s is under a roof" % t.key)
		eq(Realm.at(p.world, l.inside()), Realm.INTERIOR, "and the ground inside it says so")
		check(Realm.roofed(t.realm_key()), "its realm key reads as roofed")
		check(l.door_out.is_equal_approx(InteriorGen._quantize(t.out)), "%s: the way out faces the way the house's door does" % t.key)
		var inside := l.inside()
		check(l.is_floor(floori(inside.x), floori(inside.y)), "%s: a body comes in onto floor" % t.key)
		check(l.is_floor(floori(l.hearth.x), floori(l.hearth.y)), "%s: the hearth is on the floor" % t.key)
		check(l.is_floor(floori(l.table.x), floori(l.table.y)), "%s: and the table" % t.key)
		var just_out := l.door + l.door_out * 0.4
		check(not l.is_floor(floori(just_out.x), floori(just_out.y)), "%s: the door is in an outside wall" % t.key)
		var fires := 0
		for pr: WorldProp in p.world.props:
			if pr.kind == PropKind.FIRE:
				fires += 1
		eq(fires, 1, "%s: one hearth" % t.key)
		eq(p.world.country_at(floori(inside.x), floori(inside.y)), t.land, "%s: made of the land it stands on" % t.key)


## A landscape that declares nothing to walk into has no doors, whatever stands in
## it: every door found on the island belongs to a landscape that declared its host.
func test_a_landscape_that_declares_nothing_has_no_doors() -> void:
	for t: Threshold in Interiors.thresholds(_world()):
		var d := BiomeRegistry.by_index(t.land)
		check(d.interiors.has(&"house"), "%s: a door in %s, which declares no interiors" % [t.key, d.id])
	var houses := {}
	for p: WorldProp in _world().props:
		if p.kind == PropKind.HOUSE:
			var d := BiomeRegistry.by_index(_world().country_at(floori(p.pos.x), floori(p.pos.y)))
			houses[d.id] = d.interiors.has(&"house")
	var closed := 0
	for id: Variant in houses:
		if not houses[id]:
			closed += 1
	gt(float(closed), 0.0, "and the island has houses in landscapes with no doors, which this asked of (%s)" % str(houses))


## Every plan and every household is dealt somewhere on one coast, so walking
## into the next house is walking into somebody else's.
func test_a_coast_deals_every_plan_and_every_household() -> void:
	var w := _world()
	var plans := {}
	var homes := {}
	var pairs := {}
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"cottage":
			continue
		var l := InteriorGen.grow(4, t).layout
		plans[l.plan] = true
		homes[l.dressing] = true
		pairs["%s/%s" % [l.plan, l.dressing]] = true
	eq(plans.size(), 3, "three plans dealt (%s)" % [plans.keys()])
	eq(homes.size(), 3, "three households dealt (%s)" % [homes.keys()])
	gt(float(pairs.size()), 6.0, "and most of the nine rooms they make (%s)" % [pairs.keys()])


## NOTHING A HOUSEHOLD KEEPS WALLS ANYBODY IN. Walked with the real query and the
## room's real blocks (21_doors._walls: the walls, the breast and every solid
## thing), a body the player's size gets from the doorway to the hearth, the
## table and the side of the bed, in every room on the coast.
func test_every_room_can_be_walked_to_its_hearth_table_and_bed() -> void:
	var doors_script := load("res://src/systems/21_doors.gd") as GDScript
	var w := _world()
	var ts := Interiors.thresholds(w)
	gt(float(ts.size()), 10.0, "the coast has doors to walk")
	for t: Threshold in ts:
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", doors_script.call(&"_walls", l))
		var reach := _reach(q, l.inside())
		var goals := {"hearth": l.hearth - l.hearth_wall * 1.2, "table": l.table + Vector2(0.0, 0.9)}
		for th: Dictionary in l.things:
			if th.kind == &"bed":
				goals["bed"] = (th.at as Vector2) + (th.face as Vector2) * 0.85
		for g: String in goals:
			check(_reached(reach, goals[g]), "%s (%s/%s): the %s at %s cannot be walked to from the door" % [
				t.key, l.plan, l.dressing, g, goals[g]])


const STEP := 0.2


## Every lattice point a body can walk to from `from`, stepping only where
## `move_body` really arrives.
func _reach(q: WorldQuery, from: Vector2) -> Dictionary:
	var seen := {Vector2i(roundi(from.x / STEP), roundi(from.y / STEP)): true}
	var todo: Array[Vector2i] = [seen.keys()[0]]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if seen.has(n):
				continue
			var a := Vector2(c) * STEP
			var b := Vector2(n) * STEP
			if q.move_body(a, b - a, Tuning.PLAYER_RADIUS).distance_to(b) < 0.02:
				seen[n] = true
				todo.append(n)
	return seen


## Whether a body gets within a stride of `at`.
func _reached(reach: Dictionary, at: Vector2) -> bool:
	var c := Vector2i(roundi(at.x / STEP), roundi(at.y / STEP))
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			if reach.has(c + Vector2i(dx, dy)):
				return true
	return false


## EVERY DEPOT OF THE PLAN ON THE COAST KEEPS A HALL, and its hatch stands clear
## of the deck: off the yard's back end, with a body's room between the hatch's
## door and the deck's own mass (WorksDepot.yard_blocks reaches 3.8 back).
func test_every_coast_depot_has_a_hall_behind_a_clear_hatch() -> void:
	var w := _world()
	var coast_sites := 0
	for site: WorksSite in Works.sites(w):
		var d := BiomeRegistry.by_index(w.country_at(floori(site.pos.x), floori(site.pos.y)))
		if d != null and d.interiors.has(&"works:depot"):
			coast_sites += 1
	var halls: Array[Threshold] = []
	for t: Threshold in Interiors.thresholds(w):
		if t.kind == &"weapons_hall":
			halls.append(t)
	gt(float(coast_sites), 0.0, "seed 4 has depots where a hall is declared")
	eq(halls.size(), coast_sites, "one hall door per such depot")
	for t: Threshold in halls:
		var site_pos := t.host - t.out * Threshold.HATCH
		check(t.door.distance_to(site_pos) > 3.8 + Tuning.PLAYER_RADIUS + 0.5, "%s: the hatch door clears the deck" % t.key)
		var p := InteriorGen.grow(4, t)
		eq(p.kind.id, &"weapons_hall", "%s grows a weapons hall" % t.key)
		check(not p.layout.has_hearth, "%s: a hall has no hearth for the walls to stand round" % t.key)
