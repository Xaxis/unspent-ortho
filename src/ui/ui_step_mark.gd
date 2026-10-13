class_name UiStepMark
extends CanvasLayer
## WHERE THE STEP UNDER WAY IS (owner, 2026-10-13: "clear direction"). Over the
## thing the first steps' card asks for (FirstSteps.target_at), an arrow pointing
## down at it with its name; off the glass, the arrow stands at the glass's edge
## on the bearing to it, with its name and how far, so the way is never a guess.
## 90_ui feeds it on the guide's cadence. Close by it steps aside: the harvest
## mark's brackets have the thing then.

## Base pixels in from the glass's sides for a mark that is off it, and from its
## top and foot, clear of the readouts there (the place's name, the clock, the
## record's lines, the key row); tiles inside which the harvest mark has it; how
## far the arrow bobs.
const EDGE := 70
const EDGE_TOP := 150
const EDGE_FOOT := 160
const NEAR := 2.2
const BOB := 5.0
## How far over the ground the arrow hangs above a thing, in world units.
const OVER := 1.6
## Size of the arrow's head and of its dark rim (base pixels).
const HEAD := 14

var game: Game
## Where the thing is (world), or INF for nothing to point at.
var at := Vector3.INF
var word := ""
var _canvas: Control
var _t := 0.0


func _ready() -> void:
	# With the harvest mark: over the world, under the HUD's own glass (10).
	layer = 9
	_canvas = Control.new()
	_canvas.name = "step_mark"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_mark)
	add_child(_canvas)


func _process(delta: float) -> void:
	_t += delta
	_canvas.queue_redraw()


func _draw_mark() -> void:
	if not at.is_finite() or game == null or game.player == null or game.camera == null or not game.camera.is_inside_tree():
		return
	var cam := game.camera
	var me := game.player.position
	var tiles := Vector2(at.x - me.x, at.z - me.z).length()
	if tiles < NEAR:
		return
	var inner := Rect2(UiBase.screen()).grow_individual(-EDGE, -EDGE_TOP, -EDGE, -EDGE_FOOT)
	var head := at + Vector3(0.0, OVER, 0.0)
	var p := cam.unproject_position(head)
	var bob := sin(_t * TAU / 1.2) * BOB
	if not cam.is_position_behind(head) and inner.has_point(p):
		var tip := p + Vector2(0.0, bob)
		_arrow(tip, Vector2.DOWN)
		_label(tip + Vector2(0.0, -HEAD * 2 - UiTheme.LINE), word if tiles < 12.0 else "%s  %d" % [word, roundi(tiles)])
		return
	# Off the glass: at its edge, on the line from where he stands on it.
	var from := cam.unproject_position(me + Vector3(0.0, 0.8, 0.0))
	var dir := (p - from).normalized() if p.distance_to(from) > 1.0 else Vector2.UP
	var e := _edge(from, dir, inner) + dir * bob
	_arrow(e, dir)
	_label(e - dir * (HEAD * 2 + 10) - Vector2(0.0, UiTheme.LINE * 0.5), "%s  %d" % [word, roundi(tiles)])


## Where the ray from `from` along `dir` leaves `r`.
static func _edge(from: Vector2, dir: Vector2, r: Rect2) -> Vector2:
	var t := INF
	for axis in 2:
		if absf(dir[axis]) < 1e-5:
			continue
		var bound := r.end[axis] if dir[axis] > 0.0 else r.position[axis]
		t = minf(t, (bound - from[axis]) / dir[axis])
	if not is_finite(t):
		return from
	return from + dir * maxf(t, 0.0)


## An arrowhead with its point at `tip`, pointing along `dir`: a dark rim first,
## so it holds against pale ground as against dark.
func _arrow(tip: Vector2, dir: Vector2) -> void:
	var side := Vector2(-dir.y, dir.x)
	var back := tip - dir * HEAD
	for pass_i in 2:
		var col := UiTheme.RIM if pass_i == 0 else UiTheme.BRIGHT
		var w := UiBase.PITCH * (3 if pass_i == 0 else 1)
		for wing: Vector2 in [back + side * HEAD * 0.75, back - side * HEAD * 0.75]:
			_line(tip, wing, col, w)
		_line(tip - dir * HEAD * 0.4, tip - dir * HEAD * 1.8, col, w)


func _line(a: Vector2, b: Vector2, col: Color, w: int) -> void:
	var steps := maxi(1, ceili(a.distance_to(b) / float(UiBase.PITCH)))
	for i in steps + 1:
		var q := a.lerp(b, float(i) / float(steps)).round()
		UiDraw.rect(_canvas, Rect2i(int(q.x) - w / 2, int(q.y) - w / 2, w, w), col)


func _label(centre: Vector2, text: String) -> void:
	var w := UiFont.width(text)
	UiDraw.text_rimmed(_canvas, Vector2i(roundi(centre.x - w / 2.0), roundi(centre.y)), text, UiTheme.BRIGHT, UiTheme.RIM)
