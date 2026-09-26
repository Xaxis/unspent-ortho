extends TestCase
## EVERY VILLAGE DOOR OPENS (src/content/interiors/home.gd): a house in any
## landscape opens on a room, and a home is kept by one of its landscape's own
## households, furnished from pieces the one catalogue draws. Asked of seed 4 at
## full size, with the real query and the room's real blocks.

const STEP := 0.2
const Home := preload("res://src/content/interiors/home.gd")
const Cottage := preload("res://src/content/interiors/cottage.gd")
const Furnish := preload("res://src/models/interior/furnish.gd")
const Kit := preload("res://src/models/props/kit.gd")

var _doors := load("res://src/systems/21_doors.gd") as GDScript


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


func _reached(reach: Dictionary, at: Vector2) -> bool:
	var c := Vector2i(roundi(at.x / STEP), roundi(at.y / STEP))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if reach.has(c + Vector2i(dx, dy)):
				return true
	return false


## EVERY HOUSE HAS A DOOR in a landscape that keeps a room behind its houses
## (`&"house"`): no house there is left shut. A landscape that declares only its
## own forms' rooms (`form:ID`) opens those forms and no others, and one that
## opens only some of its houses (`home.open`, the machine city) is asked of in
## test_squat.
func test_every_house_opens_where_its_landscape_keeps_homes() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var hosts := {}
	for t: Threshold in Interiors.thresholds(w):
		hosts[Vector2i(roundi(t.host.x * 4.0), roundi(t.host.y * 4.0))] = t.kind
	var shut := {}
	var houses := 0
	var homes := {}
	for p: WorldProp in w.each_prop():
		if p.kind != PropKind.HOUSE:
			continue
		houses += 1
		var d := BiomeRegistry.by_index(w.country_at(floori(p.pos.x), floori(p.pos.y)))
		var k: StringName = hosts.get(Vector2i(roundi(p.pos.x * 4.0), roundi(p.pos.y * 4.0)), &"")
		if k == &"" and d.interiors.has(&"house") and not d.home.has("open"):
			shut[d.id] = int(shut.get(d.id, 0)) + 1
		elif k == &"home":
			homes[d.id] = true
	gt(float(houses), 100.0, "seed 4 stands houses")
	eq(shut.size(), 0, "houses with no door, by landscape: %s" % str(shut))
	gt(float(homes.size()), 5.0, "and homes stand in many landscapes (%s)" % str(homes.keys()))


## A HOME IS KEPT BY ITS LANDSCAPE'S PEOPLE: a landscape that declares its
## households deals only those; one that declares none is furnished as the coast.
func test_a_home_is_kept_by_its_landscapes_households() -> void:
	var d := BiomeRegistry.get_def(&"snowfield")
	var kept := d.home
	d.home = {"households": {&"trapper": {"wants": [&"creel", &"basket"], "by_hearth": []}}}
	for i in 12:
		var l := Home.lay(Rng.make(4, i), d.index)
		eq(l.dressing, &"trapper", "a snowfield home is a trapper's")
	d.home = {}
	var seen := {}
	for i in 40:
		seen[Home.lay(Rng.make(4, i), d.index).dressing] = true
	eq(seen.size(), Cottage.COAST.size(), "declaring none, it deals the coast's households (%s)" % str(seen.keys()))
	d.home = kept


## EVERY PIECE A HOUSEHOLD WANTS IS ONE THE CATALOGUE DRAWS: a name Furnish does
## not know draws nothing, and the wall stands bare where it was meant to be.
func test_every_piece_a_household_wants_is_drawn() -> void:
	var tables: Array[Dictionary] = [Cottage.COAST]
	for d: BiomeDef in BiomeRegistry.all():
		var hh: Dictionary = d.home.get("households", {})
		if not hh.is_empty():
			tables.append(hh)
	for hh: Dictionary in tables:
		for id: Variant in hh:
			var pieces: Array = (hh[id].get("wants", []) as Array).duplicate()
			for h: Dictionary in hh[id].get("by_hearth", []):
				pieces.append(h.kind)
			for piece: Variant in pieces:
				var kit := Kit.new()
				var f := Furnish.new(kit, 0.0, 2.4, BiomeDressing.new(), StringName(id))
				f.thing({"kind": StringName(piece), "at": Vector2(2, 2), "face": Vector2(0, 1), "solid": 0.3})
				gt(float(kit.made.vertex_count() + kit.found.vertex_count()), 0.0, "%s's %s is drawn" % [id, piece])


## THE HOMES CAN BE LIVED IN: from the door a body gets to the hearth, a side of
## the table and the side of the bed, in the first homes of every landscape.
func test_every_home_can_be_walked_to_its_hearth_table_and_bed() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var per := {}
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"home" or int(per.get(t.land, 0)) >= 4:
			continue
		per[t.land] = int(per.get(t.land, 0)) + 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", _doors.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside())
		check(_reached(reach, l.hearth - l.hearth_wall * 1.2), "%s: the hearth" % t.key)
		for th: Dictionary in l.things:
			if th.kind == &"bed":
				check(_reached(reach, (th.at as Vector2) + (th.face as Vector2) * 0.85), "%s (%s/%s in %s): the bed at %s facing %s; rooms %s, door %s" % [
					t.key, l.plan, l.dressing, BiomeRegistry.by_index(t.land).id, th.at, th.face, l.rooms, l.door])
		var sat := false
		for dd: Vector2 in [Vector2(0, 0.9), Vector2(0, -0.9), Vector2(0.9, 0), Vector2(-0.9, 0)]:
			sat = sat or _reached(reach, l.table + dd)
		check(sat, "%s: a side of the table" % t.key)
	gt(float(per.size()), 5.0, "homes walked in %d landscapes" % per.size())


## THE HEARTH A LANDSCAPE KEEPS: a slum flat round the plan's issued stove, not
## an open hearth and its chimney breast. The stove holds the room's fire (the
## world's FIRE, drawn as embers only), so it still warms and still lets a body
## sleep; a hearth of none lays no fire at all; and every hearth is drawn.
func test_a_home_keeps_its_landscapes_hearth() -> void:
	var d := BiomeRegistry.get_def(&"slums")
	var l := Home.lay(Rng.make(4, 3), d.index)
	check(not l.has_hearth, "no open hearth, no chimney breast")
	var stoves := 0
	for th: Dictionary in l.things:
		if th.kind == &"issued_stove":
			stoves += 1
			check((th.at as Vector2).is_equal_approx(l.hearth), "the stove stands at the hearth")
	eq(stoves, 1, "the plan's issued stove")
	var fires := 0
	for pr: Dictionary in l.props:
		if int(pr.kind) == PropKind.FIRE:
			fires += 1
			eq(int(pr.get("variant", -1)), PropModels.HELD_FIRE, "its fire held in the stove")
	eq(fires, 1, "one fire, so it warms and a body can sleep by it")
	var coast := Home.lay(Rng.make(4, 3), BiomeRegistry.get_def(&"moss").index)
	check(coast.has_hearth, "a landscape that declares no hearth keeps the open one")
	var kept := d.home
	d.home = {"hearth": &"none", "households": kept.households}
	var cold := Home.lay(Rng.make(4, 3), d.index)
	d.home = kept
	for pr: Dictionary in cold.props:
		check(int(pr.kind) != PropKind.FIRE, "a hearth of none lays no fire")
	for piece: StringName in [&"issued_stove", &"raised_stove", &"brazier"]:
		var kit := Kit.new()
		var f := Furnish.new(kit, 0.0, 2.4, BiomeDressing.new(), &"clerk")
		f.thing({"kind": piece, "at": Vector2(2, 2), "face": Vector2(0, 1), "solid": 0.42})
		gt(float(kit.made.vertex_count()), 0.0, "the %s is drawn" % piece)
