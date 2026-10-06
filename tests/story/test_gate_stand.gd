extends TestCase
## WHERE A GATE STANDS (GateStand, StoryGates): on open ground beside its place,
## never inside it. The lab's gate stood in the middle of the yard's raised deck on
## every seed: a player warped to it stood inside the deck with his head through
## the plate, the gate drew under it, and nobody could walk into its reach at all.
##
## Measured against the running game's own query, which holds every wall any
## system hands it (a yard's deck, a landmark's tower, the platform in the sea, a
## ruin's walls, a hatch, a hold's barrier), not against the rule's own idea of
## them; in both years, on the gate seeds.
##
## Everywhere a body stands at a gate, clear of anything solid, and walks on from
## it. In 2098 the whole of its reach is open ground as the world was grown; what
## play sets down (the strand's mussel rock and driftwood, laid on the first
## morning: Strand) keeps off by its own placer's rule, or not. In 2029 the gate
## is on the same spot, worked out where its place stands, and the Before is
## dressed otherwise (no plan: the scatter and the landmarks fall differently
## round a yard; seed 1's at 256 has a landmark's foot 1.3 off its lab gate), so
## there it is held to what a body needs.

const Sx := preload("res://tests/save/save_fixture.gd")
const SEEDS: Array[int] = [1, 7, 42]
## Small enough to boot both years of three seeds in one test. Where a gate stands
## does not depend on the size: it is cast at its place's heart at every size.
const SIZE := 256
## How near a body must be to a gate to step through it (20_realms GATE_REACH):
## the ground it covers must be open, or part of the gate is out of reach.
const REACH := 1.5
## How far on from a gate a body must be able to walk.
const WALK_OUT := 12.0


func test_every_gate_stands_on_open_ground_a_body_walks_to_in_both_years() -> void:
	for s: int in SEEDS:
		var spots := {}
		for realm: StringName in [Realm.SURFACE, Realm.ERA]:
			Story.forget()
			var args := ["--seed=%d" % s, "--size=%d" % SIZE, "--hour=11", "--weather=clear:0"]
			if realm == Realm.ERA:
				args.append("--realm=era")
			var g := Sx.game(tree, args)
			await process_frames(2)
			eq(g.world.realm, realm, "seed %d boots in %s" % [s, realm])
			var gates := StoryGates.all(g.world)
			eq(gates.size(), StoryGates.GATES.size(), "seed %d %s holds every gate" % [s, realm])
			for gate: Dictionary in gates:
				var p: Vector2 = gate.pos
				var at := "seed %d %s %s at (%.1f, %.1f)" % [s, realm, gate.id, p.x, p.y]
				_stands_open(g, p, at, realm == Realm.SURFACE)
				if realm == Realm.SURFACE:
					spots[gate.id] = p
				else:
					eq(p, spots.get(gate.id, Vector2.INF) as Vector2, "%s: the same spot as in 2098" % at)
			Sx.end(g)
	Story.forget()


## A body stands at `p`, whole, on dry ground, inside nothing solid, and walks on
## from it; and where `open`, nothing the world stands, nor any wall, comes within
## the gate's reach.
func _stands_open(g: Game, p: Vector2, at: String, open: bool) -> void:
	var t := Vector2i(p.floor())
	check(g.query.standable(t.x, t.y) and not Ground.is_water(g.world.ground_at(t.x, t.y)),
		"%s: on dry ground a body stands on" % at)
	check(g.query.body_fits(p, Tuning.PLAYER_RADIUS), "%s: a body fits there whole" % at)
	var hit := _nearest_solid(g, p, true)
	check(hit[0] >= Tuning.PLAYER_RADIUS, "%s: inside nothing solid (%s, %.2f off)" % [at, hit[1], hit[0]])
	if open:
		var grown := _nearest_solid(g, p, false)
		check(grown[0] >= REACH, "%s: nothing the world stands within its reach (%s, %.2f off)" % [at, grown[1], grown[0]])
	check(_walks_out(g, p), "%s: a body walks %.0f tiles on from it" % [at, WALK_OUT])


## What a gate keeps clear of is held to the things it keeps clear for: a door's
## reach and its own (21_doors), the key's reach as a person keeps a door
## (StoryProps.REACH, 49_cast DOOR_ROOM), and a hold's barrier across the road
## (24_holds). Read off the systems' scripts, which core may not name.
func test_what_a_gate_keeps_clear_of_matches_the_systems() -> void:
	eq(GateStand.REACH, REACH, "the gate's reach is the one this test holds open")
	eq((load("res://src/systems/20_realms.gd") as GDScript).get_script_constant_map()["GATE_REACH"], GateStand.REACH,
		"and the one 20_realms crosses at")
	var doors := (load("res://src/systems/21_doors.gd") as GDScript).get_script_constant_map()
	check(GateStand.DOOR_KEEP >= GateStand.REACH + float(doors["REACH"]), "a door's reach never reaches into a gate's")
	check(GateStand.DOOR_KEEP >= StoryProps.REACH, "a gate keeps a door off as far as a person does")
	var holds := (load("res://src/systems/24_holds.gd") as GDScript).get_script_constant_map()
	check(GateStand.ROAD_KEEP >= GateStand.REACH + float(holds["ACROSS"]) * 0.5 + float(holds["BLOCK"]),
		"a hold's barrier across the road never comes down inside a gate")


## [edge distance, what] of the nearest thing that stops a body: a solid prop
## (only those generation laid, unless `set_down`), a ghost, or any system's wall
## (WorldQuery.blocks_at, stamped into every tile it could stop a body in).
func _nearest_solid(g: Game, p: Vector2, set_down: bool) -> Array:
	var best := INF
	var what := "nothing"
	for q: WorldProp in g.query.solid_props_near(p, REACH + 1.0):
		if q.solid <= 0.0 or g.world.depleted.has(q.id):
			continue
		if not set_down and (q.id & WorldData.BUILT_BIT) != 0:
			continue
		var e := q.pos.distance_to(p) - q.solid
		if e < best:
			best = e
			what = PropKind.NAMES[q.kind] if q.kind < PropKind.NAMES.size() else str(q.kind)
	var r := ceili(REACH) + 1
	for y in range(floori(p.y) - r, floori(p.y) + r + 1):
		for x in range(floori(p.x) - r, floori(p.x) + r + 1):
			for c: Vector3 in g.query.blocks_at(Vector2(x + 0.5, y + 0.5)):
				var e := Vector2(c.x, c.y).distance_to(p) - c.z
				if e < best:
					best = e
					what = "a wall"
	return [best, what]


## Tile to tile on foot, as a body moves (WorldQuery.passable: never deep water,
## a step at most), never onto a tile whose middle something solid stands within
## a body's radius of: whether that reaches WALK_OUT tiles from `p`.
func _walks_out(g: Game, p: Vector2) -> bool:
	var start := Vector2i(p.floor())
	var seen := {start: true}
	var edge: Array[Vector2i] = [start]
	var head := 0
	while head < edge.size():
		var t: Vector2i = edge[head]
		head += 1
		if (Vector2(t) + Vector2(0.5, 0.5)).distance_to(p) >= WALK_OUT:
			return true
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + o
			if seen.has(n) or not g.query.passable(t.x, t.y, n.x, n.y):
				continue
			seen[n] = true
			if _nearest_solid_within(g, Vector2(n) + Vector2(0.5, 0.5), Tuning.PLAYER_RADIUS):
				continue
			edge.append(n)
	return false


func _nearest_solid_within(g: Game, c: Vector2, r: float) -> bool:
	for q: WorldProp in g.query.solid_props_near(c, r):
		if q.solid > 0.0 and not g.world.depleted.has(q.id) and q.pos.distance_to(c) - q.solid < r:
			return true
	for w: Vector3 in g.query.blocks_at(c):
		if Vector2(w.x, w.y).distance_to(c) - w.z < r:
			return true
	return false
