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
		for pr: WorldProp in p.world.each_prop():
			if pr.kind == PropKind.FIRE:
				fires += 1
		eq(fires, 1, "%s: one hearth" % t.key)
		eq(p.world.country_at(floori(inside.x), floori(inside.y)), t.land, "%s: made of the land it stands on" % t.key)


## A landscape that declares nothing to walk into has no doors, whatever stands in
## it: every door found on the island belongs to a landscape that declared its host.
func test_a_landscape_that_declares_nothing_has_no_doors() -> void:
	for t: Threshold in Interiors.thresholds(_world()):
		var d := BiomeRegistry.by_index(t.land)
		check(not d.interiors.is_empty(), "%s: a door in %s, which declares no interiors" % [t.key, d.id])
	var houses := {}
	for p: WorldProp in _world().each_prop():
		if p.kind == PropKind.HOUSE:
			var d := BiomeRegistry.by_index(_world().country_at(floori(p.pos.x), floori(p.pos.y)))
			houses[d.id] = not d.interiors.is_empty()
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
##
## Found by what the island holds, never by its seed: which islands deal a
## depot to the coast is the world's deal to make (GEN 28 dealt seed 4's small
## island none), so every island of the first ten that has one is checked, and
## at least one must.
func test_every_coast_depot_has_a_hall_behind_a_clear_hatch() -> void:
	var islands := 0
	for seed_value in range(1, 11):
		var w := BootWorld.world(seed_value, 256)
		var coast_sites := 0
		for site: WorksSite in Works.sites(w):
			var d := BiomeRegistry.by_index(w.country_at(floori(site.pos.x), floori(site.pos.y)))
			if d != null and d.interiors.has(&"works:depot"):
				coast_sites += 1
		if coast_sites == 0:
			continue
		islands += 1
		var halls: Array[Threshold] = []
		for t: Threshold in Interiors.thresholds(w):
			if t.kind == &"weapons_hall":
				halls.append(t)
		eq(halls.size(), coast_sites, "seed %d: one hall door per depot where a hall is declared" % seed_value)
		for t: Threshold in halls:
			var site_pos := t.host - t.out * Threshold.HATCH
			check(t.door.distance_to(site_pos) > 3.8 + Tuning.PLAYER_RADIUS + 0.5, "seed %d %s: the hatch door clears the deck" % [seed_value, t.key])
			var p := InteriorGen.grow(seed_value, t)
			eq(p.kind.id, &"weapons_hall", "%s grows a weapons hall" % t.key)
			check(not p.layout.has_hearth, "%s: a hall has no hearth for the walls to stand round" % t.key)
	gt(float(islands), 0.0, "the first ten islands have a depot where a hall is declared")


## EVERY RING OF CAST STONES ON THE COAST KEEPS A BUNKER, its hatch in the ring
## beside the tall stone and opening toward a GAP: the doorstep, and where a
## player is put out, clear of every standing stone's mass (LandmarkModels.blocks
## for cast_stones, turned by the site the way 22_landmarks hands it over).
## And the bunker carries the story's slots -- a desk, a terminal, a wall -- for
## the words to be written into.
func test_every_ring_of_cast_stones_keeps_a_bunker() -> void:
	# The full-size island: at 256 seed 4 grows no ring of stones on its coast.
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var rings: Array[LandmarkSite] = []
	for site: LandmarkSite in Landmarks.sites(w):
		var d := BiomeRegistry.by_index(w.country_at(floori(site.pos.x), floori(site.pos.y)))
		if site.kind == &"cast_stones" and d != null and d.interiors.has(&"landmark:cast_stones"):
			rings.append(site)
	gt(float(rings.size()), 0.0, "seed 4 has a ring of cast stones where a bunker is declared")
	var bunkers: Array[Threshold] = []
	for t: Threshold in Interiors.thresholds(w):
		if t.kind == &"bunker":
			bunkers.append(t)
	eq(bunkers.size(), rings.size(), "one bunker door per ring")
	var exit_out := float((load("res://src/systems/21_doors.gd") as GDScript).get_script_constant_map()["EXIT_OUT"])
	for i in rings.size():
		var site := rings[i]
		var t: Threshold = null
		for b: Threshold in bunkers:
			if b.host.distance_to(site.pos) < 3.0:
				t = b
		check(t != null, "ring at %s has its bunker" % site.pos)
		if t == null:
			continue
		# The door opens toward a GAP: its bearing from the ring's heart stands well
		# off every ring stone's (the tall one in the middle has no bearing).
		for c: Vector3 in LandmarkModels.blocks(&"cast_stones"):
			var off := Vector2(c.x, c.y).rotated(site.facing)
			if off.length() < 1.0:
				continue
			gt(absf(angle_difference(off.angle(), t.out.angle())), deg_to_rad(12.0),
				"%s: the door opens between the stones, not at one" % t.key)
		for c: Vector3 in LandmarkModels.blocks(&"cast_stones"):
			var stone := site.pos + Vector2(c.x, c.y).rotated(site.facing)
			for p: Vector2 in [t.door, t.door + t.out * exit_out]:
				check(p.distance_to(stone) > c.z + Tuning.PLAYER_RADIUS, "%s: %s is clear of a stone at %s" % [t.key, p, stone])
		var l := InteriorGen.grow(4, t).layout
		var kinds := {}
		for sl: Dictionary in l.slots:
			kinds[sl.slot] = true
		for want: StringName in [&"desk", &"terminal", &"wall"]:
			check(kinds.has(want), "%s: the bunker has a %s slot for the story" % [t.key, want])


## A LANDSCAPE'S OWN FORM KEEPS ITS OWN ROOM (`form:ID` before `house`): in every
## landscape that declares one, every house of that form opens on that kind of
## room, and a house of any other form opens only on the landscape's own `house`
## kind, if it has one. The crags' roundhouse and the drowned city's stilt house
## both stand on seed 4.
func test_every_house_opens_on_its_own_forms_room() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var doors := {}
	for t: Threshold in Interiors.thresholds(w):
		if t.host_code == PropKind.HOUSE:
			doors[t.key] = t
	var seen := {}
	for p: WorldProp in w.each_prop():
		if p.kind != PropKind.HOUSE:
			continue
		var land := w.country_at(floori(p.pos.x), floori(p.pos.y))
		var d := BiomeRegistry.by_index(land)
		if d == null:
			continue
		var key := "house@%d,%d" % [floori(p.pos.x * 4.0), floori(p.pos.y * 4.0)]
		var form := Interiors.form_of(p, w.seed_value, land)
		var want: StringName = d.interiors.get(StringName("form:%s" % form), d.interiors.get(&"house", &""))
		if d.interiors.has(StringName("form:%s" % form)):
			seen[want] = true
		if want == &"":
			check(not doors.has(key), "the %s %s at %s has no door" % [d.id, form, p.pos])
		else:
			check(doors.has(key) and (doors[key] as Threshold).kind == want,
				"the %s %s at %s opens on a %s" % [d.id, form, p.pos, want])
	for k: StringName in [&"roundhouse", &"stilt_room", &"tower_lobby", &"cliff_room", &"hulk_hold", &"rooted_floor", &"tenement", &"maintenance_bay"]:
		check(seen.has(k), "seed 4 has a house that opens on a %s" % k)


## EVERY BAY OF A ROUNDHOUSE CAN BE WALKED INTO, between piers that stand as
## solid as they are drawn: from the doorway to the fire's side, the bed's side
## and the front of every other thing a bay keeps, with the real query and the
## room's real blocks (21_doors._walls).
func test_every_roundhouse_bay_can_be_walked_to() -> void:
	var doors_script := load("res://src/systems/21_doors.gd") as GDScript
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"roundhouse":
			continue
		n += 1
		var l := InteriorGen.grow(4, t).layout
		var q := WorldQuery.new(InteriorGen.grow(4, t).world)
		var blocks: Array[Vector3] = doors_script.call(&"_walls", l)
		q.set_blocks(&"rooms", blocks)
		var reach := _reach(q, l.inside())
		var goals := {"fire": l.hearth + (l.inside() - l.hearth).normalized() * 1.2}
		var piers := 0
		for th: Dictionary in l.things:
			if th.kind == &"pier":
				piers += 1
				# A pier stops a body along its whole depth, not only at its foot.
				var tip := (th.at as Vector2) + (th.face as Vector2) * float(th.deep) * 0.5
				var held := false
				for b: Vector3 in blocks:
					if Vector2(b.x, b.y).distance_to(tip) < b.z + 0.05:
						held = true
				check(held, "%s: the pier's inner end at %s stops a body" % [t.key, tip])
			elif th.kind in [&"bed", &"kist", &"quern", &"slates", &"loom", &"peat"]:
				var off := 0.85 if th.kind == &"bed" else 0.6
				goals["%s@%s" % [th.kind, th.at]] = (th.at as Vector2) + (th.face as Vector2) * off
		eq(piers, 8, "%s: eight piers" % t.key)
		for g: String in goals:
			check(_reached(reach, goals[g]), "%s: the %s at %s cannot be walked to from the door" % [t.key, g, goals[g]])
	gt(float(n), 0.0, "seed 4 has roundhouses to walk")


## A TENEMENT'S STAIR HALL LEADS TO THE ONE OPEN DOOR. From the street door of
## every tenement on seed 4, a body gets to the shift board, the turnstile at the
## stair's foot, down the corridor through the flat's open door, and to its
## table, its bed and its stove: the corridor's shut doors, the stair and the
## turnstile stand as solid as they are drawn and none of them walls the way.
func test_every_tenement_can_be_walked_through() -> void:
	var doors_script := load("res://src/systems/21_doors.gd") as GDScript
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"tenement":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", doors_script.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside())
		var goals := {"table": l.table}
		for th: Dictionary in l.things:
			var off := {&"shift_board": 0.5, &"turnstile": 0.6, &"bed": 0.85, &"stove": 0.9}
			if off.has(th.kind):
				goals["%s@%s" % [th.kind, th.at]] = (th.at as Vector2) + (th.face as Vector2) * float(off[th.kind])
		eq(goals.size(), 5, "%s: a board, a turnstile, a bed, a stove and the table" % t.key)
		for g: String in goals:
			check(_reached(reach, goals[g]), "%s: the %s at %s cannot be walked to from the door" % [t.key, g, goals[g]])
	gt(float(n), 0.0, "seed 4 has tenements to walk")


## A MAINTENANCE BAY IS WALKED THROUGH TO THE GAP. From the hatch of every bay on
## seed 4, a body gets to the diagnostic panel, the front of the cradle or the
## sorting bench, and through the missing panel into the niche to the count
## scratched in it: the racks, bins and cradle stand as solid as they are drawn
## the length of them, and none of them walls the way.
func test_every_maintenance_bay_can_be_walked_through() -> void:
	var doors_script := load("res://src/systems/21_doors.gd") as GDScript
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"maintenance_bay":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", doors_script.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside())
		var goals := {"niche": l.table}
		for th: Dictionary in l.things:
			var off := {&"diag_panel": 0.6, &"tally": 0.6, &"cradle": 1.3, &"sort_bench": 0.8}
			if off.has(th.kind):
				goals["%s@%s" % [th.kind, th.at]] = (th.at as Vector2) + (th.face as Vector2) * float(off[th.kind])
		# A rack or a row of bins runs along its wall (`long`): its ends stop a
		# body as its middle does.
		for th: Dictionary in l.things:
			if th.has("long"):
				var along := Vector2(-(th.face as Vector2).y, (th.face as Vector2).x)
				for e: float in [-1.0, 1.0]:
					var tip := (th.at as Vector2) + along * e * (float(th.long) * 0.5 - 0.15)
					check(not reach.has(Vector2i(roundi(tip.x / STEP), roundi(tip.y / STEP))),
						"%s: a body stands inside the %s's end at %s" % [t.key, th.kind, tip])
		eq(goals.size(), 4, "%s: a panel, a count, a cradle or a bench, and the niche" % t.key)
		for g: String in goals:
			check(_reached(reach, goals[g]), "%s: the %s at %s cannot be walked to from the hatch" % [t.key, g, goals[g]])
	gt(float(n), 0.0, "seed 4 has maintenance bays to walk")


## NOTHING OVER THE WATER WALLS ANYBODY IN: from the door of every stilt room on
## seed 4, a body gets to the sand hearth, the table, the hammock's side and the
## trapdoor's edge, with the real query and the room's real blocks -- the
## hammock stands its whole length, and the trapdoor is a hole nobody walks over.
func test_every_stilt_room_can_be_walked_to() -> void:
	var doors_script := load("res://src/systems/21_doors.gd") as GDScript
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"stilt_room":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		var blocks: Array[Vector3] = doors_script.call(&"_walls", l)
		q.set_blocks(&"rooms", blocks)
		var reach := _reach(q, l.inside())
		var middle := Vector2(l.rooms[0].position) + Vector2(l.rooms[0].size) * 0.5
		var goals := {"hearth": l.hearth - l.hearth_wall * 1.2, "table": l.table + (middle - l.table).normalized() * 0.2}
		for th: Dictionary in l.things:
			var at: Vector2 = th.at
			var inward := (middle - at).normalized()
			match th.kind:
				&"hammock", &"trapdoor":
					goals["%s" % th.kind] = at + inward * 1.0
					check(q.move_body(at + inward * 1.5, -inward * 1.5, Tuning.PLAYER_RADIUS).distance_to(at) > 0.45,
						"%s: nobody walks into the %s at %s" % [t.key, th.kind, at])
		for g: String in goals:
			check(_reached(reach, goals[g]), "%s (%s/%s): the %s at %s cannot be walked to from the door" % [t.key, l.plan, l.dressing, g, goals[g]])
	gt(float(n), 0.0, "seed 4 has stilt rooms to walk")


## THE LOBBY CAN BE LIVED IN: from the door of every tower lobby on seed 4 a
## body gets between the columns to the fire, the counter, the letterboxes, the
## lift and into the stall past its curtain to the mattress -- and not up the
## stair, which is choked to the slab.
func test_every_tower_lobby_can_be_walked_to() -> void:
	var doors_script := load("res://src/systems/21_doors.gd") as GDScript
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"tower_lobby":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		var blocks: Array[Vector3] = doors_script.call(&"_walls", l)
		q.set_blocks(&"rooms", blocks)
		var reach := _reach(q, l.inside())
		var middle := Vector2(l.rooms[0].position) + Vector2(l.rooms[0].size) * 0.5
		var goals := {"fire": l.hearth + (l.inside() - l.hearth).normalized() * 1.1}
		for th: Dictionary in l.things:
			var at: Vector2 = th.at
			var inward := (middle - at).normalized()
			match th.kind:
				&"counter", &"letterboxes", &"lift":
					goals["%s" % th.kind] = at + inward * 0.9
				&"mattress":
					goals["mattress"] = at + inward * 0.9
				&"stair":
					check(not _reached(reach, at), "%s: the choked stair at %s is not walked onto" % [t.key, at])
		for g: String in goals:
			check(_reached(reach, goals[g]), "%s (%s/%s): the %s at %s cannot be walked to from the door" % [t.key, l.plan, l.dressing, g, goals[g]])
	gt(float(n), 0.0, "seed 4 has tower lobbies to walk")


## A ROOM IN THE ROCK CAN BE LIVED IN: from the door of every cliff room on
## seed 4 a body gets round the slab stood against the draught to the fire, to
## the side of the ledge, and through the low doorway into the store when there
## is one -- and not through the ledge, which is rock.
func test_every_cliff_room_can_be_walked_to() -> void:
	var doors_script := load("res://src/systems/21_doors.gd") as GDScript
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"cliff_room":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		var blocks: Array[Vector3] = doors_script.call(&"_walls", l)
		q.set_blocks(&"rooms", blocks)
		var reach := _reach(q, l.inside())
		var middle := Vector2(l.rooms[0].position) + Vector2(l.rooms[0].size) * 0.5
		var goals := {"fire": l.hearth + (l.hearth - l.inside()).normalized() * 1.1}
		for th: Dictionary in l.things:
			var at: Vector2 = th.at
			if th.kind == &"ledge":
				goals["ledge"] = at + (middle - at).normalized() * 0.9
				check(not _reached(reach, at), "%s: the ledge at %s is rock, not walked onto" % [t.key, at])
		if l.rooms.size() > 1:
			goals["store"] = Vector2(l.rooms[1].position) + Vector2(l.rooms[1].size) * 0.5
		for g: String in goals:
			check(_reached(reach, goals[g]), "%s (%s/%s): the %s at %s cannot be walked to from the door" % [t.key, l.plan, l.dressing, g, goals[g]])
	gt(float(n), 0.0, "seed 4 has cliff rooms to walk")


## A HOLD CAN BE LIVED IN: from the companion of every hulk on seed 4 a body gets
## to the stove, the table under the hatch, the side of every hammock, and
## through the bulkhead's door into the fore cabin when there is one -- and the
## open bilge hatch refuses it.
func test_every_hulk_hold_can_be_walked_to() -> void:
	var doors_script := load("res://src/systems/21_doors.gd") as GDScript
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"hulk_hold":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		var blocks: Array[Vector3] = doors_script.call(&"_walls", l)
		q.set_blocks(&"rooms", blocks)
		var reach := _reach(q, l.inside())
		var goals := {}
		var k := 0
		for th: Dictionary in l.things:
			var at: Vector2 = th.at
			var r := l.rooms[0] if l.rooms[0].has_point(Vector2i(floori(at.x), floori(at.y))) or l.rooms.size() == 1 else l.rooms[1]
			var middle := Vector2(r.position) + Vector2(r.size) * 0.5
			match th.kind:
				&"stove", &"hammock":
					var side := (middle - at).normalized()
					if th.kind == &"hammock":
						var f: Vector2 = th.face
						side = Vector2(-f.y, f.x) * signf(Vector2(-f.y, f.x).dot(middle - at) + 0.001)
					goals["%s %d" % [th.kind, k]] = at + side * 0.85
					k += 1
				&"trapdoor":
					var inward := (middle - at).normalized()
					check(q.move_body(at + inward * 1.5, -inward * 1.5, Tuning.PLAYER_RADIUS).distance_to(at) > 0.45,
						"%s: the open bilge at %s refuses a body" % [t.key, at])
		goals["table"] = l.table + (l.inside() - l.table).normalized() * 0.9
		if l.rooms.size() > 1:
			goals["fore cabin"] = Vector2(l.rooms[1].position) + Vector2(l.rooms[1].size) * 0.5 + Vector2(0, 1.2)
		for g: String in goals:
			check(_reached(reach, goals[g]), "%s (%s/%s): the %s at %s cannot be walked to from the companion" % [t.key, l.plan, l.dressing, g, goals[g]])
	gt(float(n), 0.0, "seed 4 has hulks to walk")


## THE FOREST'S FLOOR CAN BE LIVED IN: from the door of every rooted floor on
## seed 4 a body gets to the fire, the table, the side of the sleeping platform
## and round to the far side of the trunk -- and not through the trunk.
func test_every_rooted_floor_can_be_walked_to() -> void:
	var doors_script := load("res://src/systems/21_doors.gd") as GDScript
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"rooted_floor":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		var blocks: Array[Vector3] = doors_script.call(&"_walls", l)
		q.set_blocks(&"rooms", blocks)
		var reach := _reach(q, l.inside())
		var middle := Vector2(l.rooms[0].position) + Vector2(l.rooms[0].size) * 0.5
		var goals := {"fire": l.hearth + (l.inside() - l.hearth).normalized() * 1.1, "table": l.table + (l.inside() - l.table).normalized() * 0.9}
		for th: Dictionary in l.things:
			var at: Vector2 = th.at
			match th.kind:
				&"trunk":
					var inward := (l.inside() - at).normalized()
					check(q.move_body(at + inward * 1.6, -inward * 1.6, Tuning.PLAYER_RADIUS).distance_to(at) > 0.6,
						"%s: the trunk at %s is not walked through" % [t.key, at])
					# Round the far side of it from the door.
					goals["behind the trunk"] = at + (at - l.door).normalized() * 1.0
				&"nest":
					var f: Vector2 = th.face
					var side := Vector2(-f.y, f.x) * signf(Vector2(-f.y, f.x).dot(middle - at) + 0.001)
					goals["platform"] = at + side * 0.9
		for g: String in goals:
			var at: Vector2 = goals[g]
			if not l.is_floor(floori(at.x), floori(at.y)):
				continue
			check(_reached(reach, at), "%s (%s/%s): the %s at %s cannot be walked to from the door" % [t.key, l.plan, l.dressing, g, at])
	gt(float(n), 0.0, "seed 4 has rooted floors to walk")


## THE DOOR YOU FACE IS THE DOOR YOU GO THROUGH. Stood half a tile out from any
## door on seed 4 and facing its house, the use key means that door -- even where
## two houses face each other across a channel with their doors half a tile
## apart (GEN 28 put a stilt house and a hulk so), where nearest-first opened
## the house behind the player.
func test_the_door_a_player_faces_is_the_one_they_open() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var doors := Interiors.thresholds(w)
	var reach := float((load("res://src/systems/21_doors.gd") as GDScript).get_script_constant_map()["REACH"])
	var close := 0
	for t: Threshold in doors:
		for o: Threshold in doors:
			if o != t and o.door.distance_to(t.door) < reach:
				close += 1
		var at := t.door + t.out * 0.5
		var got := Interiors.door_for(doors, at, (-t.out).angle(), reach)
		check(got == t, "%s: facing its house from its doorstep, the key opens %s" % [t.key, got.key if got != null else "nothing"])
	gt(float(close), 0.0, "seed 4 has doors near enough each other for this to be asked")


## A HALL'S GUARD IS A BODY THAT KEEPS A HALL: in every landscape that keeps a
## hall behind its depot, the guard it stands in there walks the floor, fits
## between the racks and the gantry's legs, and fights with a blow of its own --
## whatever the landscape's roster lists. The coast's lists a flock first among
## its hunters (it passed over and could not be fought) and a dredger after it,
## which stood wedged among the gantry's legs while its alarm brought the warden.
func test_a_halls_guard_walks_the_floor_and_fights() -> void:
	var doors_script := load("res://src/systems/21_doors.gd") as GDScript
	var halls := 0
	for d: BiomeDef in BiomeRegistry.all():
		if not d.interiors.has(&"works:depot"):
			continue
		halls += 1
		var k: StringName = doors_script.call(&"_body_for", &"guard", d.index)
		var row := Roster.row(k)
		check(not row.is_empty(), "%s: the guard %s has a row" % [d.id, k])
		check(row.get("crosses", &"") != &"fly", "%s: the guard %s walks the floor" % [d.id, k])
		check(row.has("bite"), "%s: the guard %s fights with a blow of its own" % [d.id, k])
		lt(float(row.get("radius", 1.0)), 0.51, "%s: the guard %s fits between the racks" % [d.id, k])
	gt(float(halls), 0.0, "some landscape keeps a hall")
