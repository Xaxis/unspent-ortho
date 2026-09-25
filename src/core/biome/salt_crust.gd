class_name SaltCrust
extends RefCounted
## The salt crust's plates in GDScript: the mirror of src/render/salt_crust.gdshaderinc,
## so what grows along the cracks (Decor, a GrassSpecies that `rims`) roots on
## the rims the ground draws. The shader wanders its joins by a small `rag`
## (under 0.03 of a plate); a tuft a fifth of a tile across covers it.

const FREQ := 2.1
const LIFT := 0.62
const RIM_MIN := 0.03
const RIM_SPAN := 0.075


## ink.gdshaderinc's ink_hash.
static func ink_hash(p: Vector2) -> float:
	p = Vector2(p.x * 0.1031, p.y * 0.1030)
	p = p - p.floor()
	var d := p.dot(Vector2(p.y, p.x) + Vector2(33.33, 33.33))
	p += Vector2(d, d)
	var v := (p.x + p.y) * p.x
	return v - floorf(v)


static func _centre(g: Vector2) -> Vector2:
	return g + Vector2(ink_hash(g + Vector2(1.7, 1.7)), ink_hash(g + Vector2(5.3, 5.3))) * 0.8 + Vector2(0.1, 0.1)


## [own plate, next plate, join distance] at world xz, as salt_cells with no jitter.
static func cells(wp: Vector2) -> Array:
	var q := wp * FREQ
	var gi := q.floor()
	var d1 := 9.0
	var d2 := 9.0
	var own := Vector2.ZERO
	var next := Vector2.ZERO
	for yy in range(-1, 2):
		for xx in range(-1, 2):
			var g := gi + Vector2(xx, yy)
			var d := q.distance_to(_centre(g))
			if d < d1:
				d2 = d1
				d1 = d
				next = own
				own = g
			elif d < d2:
				d2 = d
				next = g
	return [own, next, d2 - d1]


static func lifted(own: Vector2, next: Vector2) -> float:
	return ink_hash(own.min(next) * 3.1 + own.max(next) * 7.3)


## True when world xz lies on a lifted rim, as the ground draws it.
static func on_rim(wp: Vector2) -> bool:
	var c := cells(wp)
	var l := lifted(c[0], c[1])
	return l < LIFT and float(c[2]) < RIM_MIN + l * RIM_SPAN


## The point on the join nearest `wp` between its plate and the next, when that
## join has lifted; Vector2.INF when it has not. What grows along the cracks
## roots here.
static func snap(wp: Vector2) -> Vector2:
	var c := cells(wp)
	if lifted(c[0], c[1]) >= LIFT:
		return Vector2.INF
	var a := _centre(c[0])
	var b := _centre(c[1])
	var n := (b - a).normalized()
	var q := wp * FREQ
	q -= n * (q - (a + b) * 0.5).dot(n)
	return q / FREQ
