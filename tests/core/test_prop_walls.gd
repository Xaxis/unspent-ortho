extends TestCase
## A walled prop's walls stop a body where it is drawn (PropWalls, #75): walking
## straight at a wall of every walled kind seed 7 lays ends short of it, and the
## prop's own `solid` no longer stands in the open (the solid rows leave it out).

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
