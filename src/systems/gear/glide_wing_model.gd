class_name GlideWingModel
extends Node3D
## The glide wing on the player's back, and the one place in the game where
## MENDED is drawn as a thing rather than an icon (docs/ART.md §10): the panels
## are FOUND plate on found.gdshader, exact and unhatched, and the frame and the
## cord that bind them to a person are MADE on world.gdshader, hatched and
## crooked. Both idioms are in one silhouette at once.
##
## It is folded against the back until a glide starts, then opens over two
## tenths of a second and holds until the body lands.

const SPAN := 0.92
const CHORD := 0.56
## Folded (up against the spine) and open (nearly level) angles of the two spars.
const FOLDED := 1.32
const OPEN := 0.18
const OPEN_SECONDS := 0.2

var open := 0.0
var _target := 0.0
var _plate: MeshInstance3D
var _frame: MeshInstance3D
var _left: Node3D
var _right: Node3D


func build(made: Material) -> void:
	for side: int in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "spar%d" % side
		add_child(pivot)
		if side < 0:
			_left = pivot
		else:
			_right = pivot
		var plate := MeshInstance3D.new()
		plate.name = "plate"
		plate.mesh = _plate_mesh(side)
		plate.material_override = PropModels.found_material()
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(plate)
		var frame := MeshInstance3D.new()
		frame.name = "frame"
		frame.mesh = _frame_mesh(side)
		if made != null:
			frame.material_override = made
		frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(frame)
	visible = false
	_set_angle(0.0)


## Three plate panels per side, each narrower than the last, cut off other
## machines: straight leading edge, chamfered tip, one rubbed corner.
static func _plate_mesh(side: int) -> ArrayMesh:
	var k := MeshKit.new()
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	var P := Palette.PLATE
	for i in 3:
		var t0 := float(i) / 3.0
		var t1 := float(i + 1) / 3.0
		var x0 := side * SPAN * t0
		var x1 := side * SPAN * t1
		var c0 := CHORD * (1.0 - 0.55 * t0)
		var c1 := CHORD * (1.0 - 0.55 * t1)
		var lift0 := 0.06 * t0
		var lift1 := 0.06 * t1
		var col: Color = P[2 + (i % 2)]
		# Authored counter-clockwise seen from above, so the panel faces the
		# camera; the far side mirrors, which flips the winding back.
		var inner_back := Vector3(x0, lift0, -c0 * 0.35)
		var inner_front := Vector3(x0, lift0, c0 * 0.65)
		var outer_back := Vector3(x1, lift1, -c1 * 0.35)
		var outer_front := Vector3(x1, lift1, c1 * 0.65)
		if side > 0:
			k.quad(inner_back, inner_front, outer_front, outer_back, col)
		else:
			k.quad(inner_back, outer_back, outer_front, inner_front, col)
	return k.build()


## The made half: a whittled spar down the leading edge and three cords lashing
## the plate to it, crooked where the plate is exact.
static func _frame_mesh(side: int) -> ArrayMesh:
	var k := MeshKit.new()
	k.style = Ink.HAND
	k.style2 = Ink.HAND
	var wood := Palette.EARTH[2]
	var cord := Palette.SAND[3]
	k.strut(Vector3(0, 0, -CHORD * 0.3), Vector3(side * SPAN, 0.06, -CHORD * 0.28 * 0.45), 0.05, 5, wood)
	for i in 3:
		var t := 0.22 + 0.3 * i
		var x := side * SPAN * t
		var c := CHORD * (1.0 - 0.55 * t)
		k.strut(Vector3(x, 0.03 + 0.06 * t, -c * 0.33), Vector3(x + side * 0.06, 0.01 + 0.06 * t, c * 0.6), 0.03, 4, cord)
	return k.build()


func set_open(on: bool) -> void:
	_target = 1.0 if on else 0.0


## One place decides how open the wing is and whether it is on screen, every
## frame: a wing left hanging over a body that has stopped flying is worse than
## no wing at all.
func step(delta: float) -> void:
	open = move_toward(open, _target, delta / OPEN_SECONDS)
	_set_angle(open)
	visible = open > 0.0


func _set_angle(t: float) -> void:
	var a := lerpf(FOLDED, OPEN, t)
	if _left != null:
		_left.rotation = Vector3(0.0, 0.0, -a)
	if _right != null:
		_right.rotation = Vector3(0.0, 0.0, a)
