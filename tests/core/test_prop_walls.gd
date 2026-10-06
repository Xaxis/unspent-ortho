extends TestCase
## A walled prop's walls stop a body where it is drawn (PropWalls, #75): walking
## straight at a wall of every walled kind seed 7 lays ends short of it, and the
## prop's own `solid` no longer stands in the open (the solid rows leave it out).

const F := preload("res://tests/fight/fixture.gd")
const Lights := preload("res://src/systems/15_lights.gd")

static var _w: WorldData = null


static func _world() -> WorldData:
	if _w == null:
		_w = WorldGen.generate(7, 512)
	return _w


## Walk from `from` straight at `to` in small steps, as a body does.
static func _walk(q: WorldQuery, from: Vector2, to: Vector2) -> Vector2:
	var p := from
	for i in 160:
		var d := to - p
		if d.length() < 0.01:
			break
		p = q.move_body(p, d.limit_length(0.05), Tuning.PLAYER_RADIUS)
	return p


func test_a_body_stops_at_every_walled_kinds_wall() -> void:
	var w := _world()
	var q := WorldQuery.new(w)
	var t := w.table
	var done := {}
	for row in t.size():
		var kind := int(t.kind[row])
		if not PropWalls.walled(kind) or done.has(kind) or w.depleted.has(t.id[row]):
			continue
		var walls := PropWalls.of_row(w, row)
		if walls.is_empty():
			continue
		# The wall furthest out from the prop's middle, aimed at from past it.
		var pos: Vector2 = t.pos[row]
		var far: Vector3 = walls[0]
		for c in walls:
			if Vector2(c.x, c.y).distance_to(pos) > Vector2(far.x, far.y).distance_to(pos):
				far = c
		var target := Vector2(far.x, far.y)
		var out := (target - pos).normalized() if target.distance_to(pos) > 0.05 else Vector2.RIGHT
		var start := target + out * (far.z + 2.5)
		if not q.body_fits(start, Tuning.PLAYER_RADIUS):
			continue
		done[kind] = true
		var end := _walk(q, start, target)
		gt(end.distance_to(target), far.z + 0.15, "%s: a body walking at its wall stops short (%.2f from its middle, wall %.2f)" % [
			PropKind.NAMES[kind], end.distance_to(target), far.z])
	print("  info walled kinds walked at on seed 7: %s" % [done.keys().map(func(k: int) -> String: return PropKind.NAMES[k])])
	gt(float(done.size()), 3.0, "seed 7 lays walled kinds to walk at")


## A BODY STANDING IN A WALLED PROP WALKS OUT OF IT. A body put down inside a
## prop's walls (a keeper at a lair in a pump house, a save, a prop come back over
## it) must get out, as it always got out of one disc: seed 1's salt flats keeper
## dens on its station's pump house and stood there, every way out of one wall a
## way into the next. Stood at the middle of each of a prop's walls and walked
## straight away from the prop's middle, it ends clear of all of them.
func test_a_body_inside_a_walled_prop_walks_out_of_it() -> void:
	var w := F.flat_world(96)
	var kinds: Array[int] = [PropKind.PUMP_HOUSE, PropKind.HOUSE, PropKind.FALLEN_TOWER, PropKind.HULL]
	var props: Array[WorldProp] = []
	for i in kinds.size():
		var p := WorldProp.new(w.next_id(), kinds[i], Vector2(24.2 + 40.0 * (i % 2), 24.7 + 40.0 * (i / 2)), 0.6 * i, 1.0)
		w.add_prop(p)
		props.append(p)
	var q := WorldQuery.new(w)
	var r := Tuning.PLAYER_RADIUS
	for p in props:
		var walls := q.walls_of(w.row_of_id(p.id))
		check(not walls.is_empty(), "%s has walls" % PropKind.NAMES[p.kind])
		var stuck := 0
		for c: Vector3 in walls:
			var at := Vector2(c.x, c.y)
			var out := (at - p.pos).normalized() if at.distance_to(p.pos) > 0.05 else Vector2.RIGHT
			var end := at
			for i in 200:
				end = q.move_body(end, out * 0.05, r)
			for c2: Vector3 in walls:
				if Vector2(c2.x, c2.y).distance_to(end) < c2.z + r - 0.001:
					stuck += 1
					break
		eq(stuck, 0, "%s: a body stood in each of its %d walls walks out of them" % [PropKind.NAMES[p.kind], walls.size()])


## A LANTERN DIMS BY A ROOM'S WALLS AND NOT BY A HOUSE'S (PropWalls.ROOMS). The
## held lantern comes down beside walls handed to the query (15_lights), and a
## prop is not asked: a walled house's walls are a body's to meet, and dimmed
## beside every one at night the whole game's night would change. A ruin's are a
## room's, and dim it as they always did. Stood a hand off each one's walls.
func test_a_lantern_dims_by_a_rooms_walls_and_not_by_a_house() -> void:
	var w := F.flat_world(64)
	var house := WorldProp.new(w.next_id(), PropKind.HOUSE, Vector2(20.2, 32.5), 0.0, 1.0)
	w.add_prop(house)
	var ruin := WorldProp.new(w.next_id(), PropKind.RUIN, Vector2(44.2, 32.5), 0.0, 1.0)
	w.add_prop(ruin)
	var g := Game.new()
	g.world = w
	g.query = WorldQuery.new(w)
	var lights: Node = Lights.new()
	lights.set("game", g)
	for p: WorldProp in [house, ruin]:
		var at := p.pos + Vector2.RIGHT * g.query.stand_off(p, Vector2.RIGHT, 0.3)
		near(g.query.edge_to(p, at), 0.3, 0.05, "%s: stood a hand off its walls" % PropKind.NAMES[p.kind])
		var level := float(lights.call("_held_off", at))
		if p.kind == PropKind.HOUSE:
			near(level, 1.0, 1e-6, "beside a house the lantern is the lantern it always was")
		else:
			lt(level, 0.5, "beside a ruin's walls it comes down, as in a room")
	lights.free()
	g.free()


func test_a_walled_props_solid_stops_nothing() -> void:
	# Its `solid` is worldgen's placement footprint; what stops a body is its walls.
	var w := _world()
	var q := WorldQuery.new(w)
	var t := w.table
	for row in t.size():
		if PropWalls.walled(int(t.kind[row])) and t.solid[row] > 0.0:
			check(not q.ordinary_rows_near(t.pos[row], 0.5).has(row), "%s's solid is not a solid row" % PropKind.NAMES[int(t.kind[row])])
			check(not q.wide_rows_in(t.pos[row], t.pos[row], 0.5).has(row), "nor a wide one")
			return
	check(false, "seed 7 has a walled prop with a solid")
