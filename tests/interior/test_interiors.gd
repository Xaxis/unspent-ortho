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
