class_name UiHarvestMark
extends CanvasLayer
## The thing the use key would take, marked where it stands (owner, 2026-09-17).
##
## INTERIM DRAWING, and only the drawing: 51_harvest hands this a target that is
## already decided (`Harvest.target`) and already placed (`51_harvest.place`), and
## all this does is put brackets round it and a ring under it in a colour for its
## state. Under the lit world the answer to "this can be taken" is meant to be
## light falling on the thing (docs/LOOK.md), so this file is the one to throw
## away; the rule and the placement stay.

## Corners of the brackets, and how far out from the thing they stand (pixels).
const CORNER := 4
const PAD := 3
## Points round the ground ring (two drawn in every three, each on a dark rim).
const RING_POINTS := 36
## Seconds for one slow breath of the brackets, so a mark at rest is still alive.
const BREATH := 1.6

var game: Game
## {state, base: Vector3, height, radius} or {} for nothing in reach.
var target: Dictionary = {}
var _canvas: Control
var _t := 0.0


func _ready() -> void:
	# Over the world and under the HUD's own glass (10).
	layer = 9
	UiBase.fit(self)
	_canvas = Control.new()
	_canvas.name = "harvest_mark"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_mark)
	add_child(_canvas)


func _process(delta: float) -> void:
	_t += delta
	_canvas.queue_redraw()


## The ink for a state: the phosphor for a thing the key works now, dimmer for one
## it would work with another tool, and the warning's own dull red for one it will
## not. Picked over is only a ring: nothing to take, but the eye should not be
## left wondering why the key did nothing.
static func ink_of(state: StringName) -> Color:
	match state:
		Harvest.WORKABLE, Harvest.YOURS:
			return UiTheme.BRIGHT
		Harvest.OTHER_TOOL:
			return UiTheme.TEXT
		Harvest.PICKED_OVER, Harvest.UNDER_WATER:
			return UiTheme.TEXT_DIM
	return UiTheme.WARN_DIM


func _draw_mark() -> void:
	if target.is_empty() or game == null or game.camera == null or not game.camera.is_inside_tree():
		return
	var cam := game.camera
	var base: Vector3 = target.base
	var height := float(target.height)
	var radius := float(target.radius)
	var state := StringName(str(target.get("state", &"")))
	var col := ink_of(state)
	if not Rect2(UiBase.screen()).grow(40.0).has_point(UiBase.to_design(cam.unproject_position(base))):
		return
	if state == Harvest.PICKED_OVER or state == Harvest.UNDER_WATER:
		# Nothing to take: no brackets, only the ground marked round it, so the eye
		# is not left wondering why the key did nothing.
		_ring(cam, base, radius, col)
		return
	var box := bounds(cam, base, height, radius).grow(PAD)
	var breath := 0.5 + 0.5 * sin(_t * TAU / BREATH)
	box = box.grow(roundi(breath))
	# A dark bracket under the bright one, so the corners hold against pale ground
	# as well as dark (the target read's own rule).
	UiSlate.brackets(_canvas, box.grow(1), UiTheme.RIM, CORNER + 1)
	UiSlate.brackets(_canvas, box, col, CORNER)


## The screen box round a thing standing `height` tall and `radius` wide at `base`,
## put through the camera (and brought into the slate's design units, which this
## layer is drawn in) so the brackets fit what is drawn at any zoom, lean or turn
## of the rig. A rock, a seam or a bush is round and comes to a crown, not a
## crate: its foot and its shoulder are circles and its top is a point, and the
## corners of an upright box stood a head above every cone.
static func bounds(cam: Camera3D, base: Vector3, height: float, radius: float) -> Rect2i:
	var lo := UiBase.to_design(cam.unproject_position(base + Vector3(0.0, height, 0.0)))
	var hi := lo
	for k in 8:
		var a := float(k) * TAU / 8.0
		var round := Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		# The foot at full width, and a shoulder high up at most of it: a seam's
		# broad top stays inside, and a cone's point is still the top.
		for p: Vector2 in [UiBase.to_design(cam.unproject_position(base + round)),
				UiBase.to_design(cam.unproject_position(base + round * 0.8 + Vector3(0.0, height * 0.75, 0.0)))]:
			lo = lo.min(p)
			hi = hi.max(p)
	return Rect2i(Vector2i(lo.round()), Vector2i((hi - lo).round()))


## A ring of points on the ground round it, drawn through the camera so it lies on
## the world and never covers the thing it is round.
func _ring(cam: Camera3D, base: Vector3, radius: float, col: Color) -> void:
	var r := radius + 0.15
	for i in RING_POINTS:
		if i % 3 == 2:
			continue
		var a := float(i) * TAU / float(RING_POINTS)
		var p := UiBase.to_design(cam.unproject_position(base + Vector3(cos(a) * r, 0.03, sin(a) * r))).round()
		UiDraw.rect(_canvas, Rect2i(int(p.x) - 1, int(p.y) - 1, 3, 3), UiTheme.RIM)
		UiDraw.px(_canvas, int(p.x), int(p.y), col)
