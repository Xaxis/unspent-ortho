extends RefCounted
## A COTTAGE: one room with its hearth against the back wall and a table in the
## middle, and more often than not a small room off one side through a doorway.
## Windows in the side walls let the day in (the hour moves across the floor).
## Laid in the canonical frame: the way in is in the south wall (+y).


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"cottage"
	k.closed = 0.4
	k.zoom = 9.0
	k.wall_h = 2.4
	k.cut = 0.8
	k.door_width = 0.9
	k.rev = 1
	k.recipe = load("res://src/content/interiors/cottage.gd")
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	var w := rng.randi_range(6, 8)
	var d := rng.randi_range(5, 6)
	var main := Rect2i(0, 0, w, d)
	l.rooms.append(main)
	var side := Rect2i()
	var has_side := rng.randf() < 0.65
	if has_side:
		var sw := rng.randi_range(3, 4)
		var sd := rng.randi_range(3, d)
		side = Rect2i(w, 0, sw, sd) if rng.randf() < 0.5 else Rect2i(-sw, 0, sw, sd)
		l.rooms.append(side)
	# The way in: in the south wall, never in a corner.
	var dx := rng.randi_range(1, w - 2)
	l.door = Vector2(dx + 0.5, d)
	l.door_out = Vector2(0, 1)
	# The hearth: against the back wall, off the door's line so the table is not
	# in the way of it.
	var hx := clampi(w - 1 - dx + rng.randi_range(-1, 1), 1, w - 2)
	l.hearth = Vector2(hx + 0.5, 0.75)
	l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(w * 0.5 + rng.randf_range(-0.6, 0.6), d * 0.5 + 0.2)
	# Every unit edge of every room; one shared by two rooms is an inner wall.
	var seen := {}
	for r: Rect2i in l.rooms:
		for x in range(r.position.x, r.end.x):
			_edge(l, seen, Vector2(x, r.position.y), Vector2(x + 1, r.position.y), Vector2(0, -1))
			_edge(l, seen, Vector2(x, r.end.y), Vector2(x + 1, r.end.y), Vector2(0, 1))
		for y in range(r.position.y, r.end.y):
			_edge(l, seen, Vector2(r.position.x, y), Vector2(r.position.x, y + 1), Vector2(-1, 0))
			_edge(l, seen, Vector2(r.end.x, y), Vector2(r.end.x, y + 1), Vector2(1, 0))
	for e: Dictionary in l.edges:
		var mid: Vector2 = (e.a + e.b) * 0.5
		if mid.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner and absf(mid.y - 1.5) < 0.1:
			e.kind = &"inner"
		elif not e.inner and (e.out as Vector2).y == 0.0 and absf(mid.y - (floorf(d * 0.5) + 0.5)) < 0.1:
			e.kind = &"window"
	return l


static func _edge(l: InteriorLayout, seen: Dictionary, a: Vector2, b: Vector2, out: Vector2) -> void:
	var k := "%d,%d,%d,%d" % [int(a.x * 2), int(a.y * 2), int(b.x * 2), int(b.y * 2)]
	if seen.has(k):
		(seen[k] as Dictionary).inner = true
		return
	var e := {"a": a, "b": b, "out": out, "kind": &"wall", "inner": false}
	seen[k] = e
	l.edges.append(e)
