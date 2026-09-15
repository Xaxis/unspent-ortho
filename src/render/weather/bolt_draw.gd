class_name BoltDraw
extends Node2D
## A lightning strike drawn with a pen on the 640x360 page (docs/ART.md section
## 6): a jagged pale core two pixels wide down the main stroke and one pixel
## down each fork, with one pixel of ink either side, every pixel snapped to the
## screen grid. It lives in a CanvasLayer under the HUD and is re-anchored to
## the strike's ground point every frame, so it stays on the land it hit while
## the camera follows the player.

const CORE := Color(0.953, 0.925, 0.851) # LINEN[5]-ish page white, a touch warm
const FORK_CORE := Color(0.827, 0.886, 0.914)
const INK := Color(0.106, 0.098, 0.157)

var camera: Camera3D
## World point the bolt lands on; the path is drawn relative to it.
var ground := Vector3.ZERO
## Pixel cells relative to the landing pixel: [core cells, ink cells].
var _core: Dictionary = {}
var _ink: Dictionary = {}


## Build a strike: the main stroke from `rise` pixels above the landing point
## down to it, and two forks. Pure in its seed.
func set_strike(at: Vector3, seed_value: int, rise: float) -> void:
	ground = at
	var cells := BoltDraw.cells(seed_value, rise)
	_core = cells[0]
	_ink = cells[1]
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if camera == null or _core.is_empty():
		return
	if camera.is_position_behind(ground):
		return
	var o := camera.unproject_position(ground).floor()
	for c: Vector2i in _ink:
		draw_rect(Rect2(o.x + c.x, o.y + c.y, 1, 1), INK)
	for c: Vector2i in _core:
		draw_rect(Rect2(o.x + c.x, o.y + c.y, 1, 1), CORE if int(_core[c]) == 2 else FORK_CORE)


## Pixel cells of a strike, relative to its landing pixel (y down): returns
## [core: Dictionary Vector2i -> 2 main / 1 fork, ink: Dictionary Vector2i -> true].
static func cells(seed_value: int, rise: float) -> Array:
	var r := Rng.make(seed_value, 0xB017)
	var main := _jag(Vector2(r.randf_range(-40.0, 40.0), -rise), Vector2.ZERO, r, 16.0, 9.0)
	var core := {}
	_stroke(core, main, 2)
	# Forks leave the lower part of the stroke, where they are on screen.
	for i in 2:
		var at := main[r.randi_range(main.size() * 5 / 10, maxi(main.size() * 5 / 10, main.size() * 8 / 10))]
		var side := -1.0 if (i == 0) == (r.randf() < 0.5) else 1.0
		var to := at + Vector2(side * r.randf_range(18.0, 44.0), r.randf_range(26.0, 60.0))
		_stroke(core, _jag(at, to, r, 9.0, 4.0), 1)
	var ink := {}
	for c: Vector2i in core:
		for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if not core.has(n):
				ink[n] = true
	return [core, ink]


## A jagged polyline from a to b in steps of about `step` pixels, each joint
## thrown up to `jitter` pixels sideways; the ends stay put.
static func _jag(a: Vector2, b: Vector2, r: RandomNumberGenerator, step: float, jitter: float) -> PackedVector2Array:
	var n := maxi(2, ceili(a.distance_to(b) / step))
	var across := (b - a).normalized().orthogonal()
	var out := PackedVector2Array()
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		if i > 0 and i < n:
			p += across * r.randf_range(-jitter, jitter)
		out.append(p.round())
	return out


## Rasterise a polyline into whole pixels (8-connected), `width` pixels wide
## (the second column to the right).
static func _stroke(into: Dictionary, pts: PackedVector2Array, width: int) -> void:
	for i in range(1, pts.size()):
		var a := Vector2i(pts[i - 1])
		var b := Vector2i(pts[i])
		var dx := absi(b.x - a.x)
		var dy := -absi(b.y - a.y)
		var sx := 1 if a.x < b.x else -1
		var sy := 1 if a.y < b.y else -1
		var err := dx + dy
		var p := a
		while true:
			for w in width:
				var c := p + Vector2i(w, 0)
				into[c] = maxi(int(into.get(c, 0)), width)
			if p == b:
				break
			var e2 := 2 * err
			if e2 >= dy:
				err += dy
				p.x += sx
			if e2 <= dx:
				err += dx
				p.y += sy
