class_name InteriorGen
## GROWS A POCKET (docs/interiors): the rooms behind a door, from the seed and the
## door's key alone, so the same house on the same seed always has the same rooms
## and its neighbour has its own. Pure: a WorldData and the layout it was grown
## from, nothing drawn and nothing pointed at.

const SALT := 0x1D0025
## The floor's level: a tile of nothing round the rooms stands two levels lower,
## a drop no body steps down, under the dark the view lays beneath a pocket.
const FLOOR_LEVEL := 2


class Pocket:
	var world: WorldData
	var layout: InteriorLayout
	var kind: InteriorKind
	var threshold: Threshold


static func grow(seed_value: int, t: Threshold) -> Pocket:
	var k := Interiors.kind(t.kind)
	if k == null:
		return null
	var rng := Rng.make(Rng.hash_ints(seed_value, t.host_code, floori(t.host.x * 4.0), floori(t.host.y * 4.0), SALT))
	var l: InteriorLayout = k.recipe.call(&"lay", rng)
	_turn(l, _quantize(t.out))
	var w := WorldData.new(seed_value, l.size)
	w.realm = Realm.INTERIOR
	for y in l.size:
		for x in l.size:
			var i := y * l.size + x
			var on_floor := l.is_floor(x, y)
			w.level[i] = FLOOR_LEVEL if on_floor else 0
			w.ground[i] = Ground.FLOOR
			w.country[i] = t.land
	w.spawn = l.inside()
	for pr: Dictionary in l.props:
		w.add_prop(WorldProp.new(w.props.size(), int(pr.kind), pr.at, (pr.face as Vector2).angle(), 1.0))
	var p := Pocket.new()
	p.world = w
	p.layout = l
	p.kind = k
	p.threshold = t
	return p


## The nearest of the four ways, so rooms stand on the tile grid.
static func _quantize(v: Vector2) -> Vector2:
	if absf(v.x) >= absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))


## Turns the canonical layout (way out +y) until its way out is `out`, and moves
## it to stand a tile in from the pocket's corner.
static func _turn(l: InteriorLayout, out: Vector2) -> void:
	var turns := 0
	var d := l.door_out
	while not d.is_equal_approx(out) and turns < 4:
		d = Vector2(-d.y, d.x)
		turns += 1
	var f := func(v: Vector2) -> Vector2:
		var r := v
		for i in turns:
			r = Vector2(-r.y, r.x)
		return r
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var rooms: Array[Rect2i] = []
	for r: Rect2i in l.rooms:
		var a: Vector2 = f.call(Vector2(r.position))
		var b: Vector2 = f.call(Vector2(r.end))
		var p := Vector2(minf(a.x, b.x), minf(a.y, b.y))
		var q := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		rooms.append(Rect2i(Vector2i(p), Vector2i(q - p)))
	var shift := Vector2.ONE - lo
	l.rooms.clear()
	for r: Rect2i in rooms:
		l.rooms.append(Rect2i(r.position + Vector2i(shift), r.size))
	for e: Dictionary in l.edges:
		e.a = (f.call(e.a) as Vector2) + shift
		e.b = (f.call(e.b) as Vector2) + shift
		e.out = f.call(e.out)
	l.door = (f.call(l.door) as Vector2) + shift
	l.door_out = f.call(l.door_out)
	l.hearth = (f.call(l.hearth) as Vector2) + shift
	l.hearth_wall = f.call(l.hearth_wall)
	l.table = (f.call(l.table) as Vector2) + shift
	for t: Dictionary in l.things:
		t.at = (f.call(t.at) as Vector2) + shift
		t.face = f.call(t.face)
	for pr: Dictionary in l.props:
		pr.at = (f.call(pr.at) as Vector2) + shift
		pr.face = f.call(pr.face)
	for r: Dictionary in l.residents:
		r.at = (f.call(r.at) as Vector2) + shift
		r.face = f.call(r.face)
	for sl: Dictionary in l.slots:
		sl.at = (f.call(sl.at) as Vector2) + shift
		sl.face = f.call(sl.face)
	for i in l.walks.size():
		var w2 := l.walks[i]
		for j in w2.size():
			w2[j] = (f.call(w2[j]) as Vector2) + shift
		l.walks[i] = w2
	var span := hi - lo
	l.size = int(maxf(span.x, span.y)) + 2
