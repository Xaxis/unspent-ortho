class_name EraGate
## The drawn gate into 2029 (docs/STORY.md §6, `StoryGates`): a way through TIME
## rather than through rock, standing in the open where the Seeker put it.
##
##   EraGate.node(open) -> Node3D
##
## **A SHAFT IS A HOLE AND THIS IS A DOOR, AND THE CAMERA MAKES THAT HARD.**
## `RealmGate`'s header says why it is drawn as a hole: at this pitch a frame
## standing on the ground with a rectangle in it reads as a door, and a door is
## not a way down. A time gate IS a door — but seen from above a standing pane is
## a line, and its whole meaning is what is on the other side of it. So the WAY
## THROUGH is drawn lying on the ground the way a shaft's mouth is, and the frame
## stands round it: from the play camera you see a patch of another day's light on
## the grass with a machine's arch over it, which is the one thing a time gate
## could be and a shaft could not.
##
## The light through it is DAYLIGHT — 2029, and the sun was still reaching the
## ground then. It is the one warm thing in a world the machines lit violet, and
## it is deliberately not on their beat: a gate does not blink with the plan's
## power because the Seeker did not build it out of their parts.
##
## It faces +X like every model and has no collision: a gate is walked up to and
## used, never bumped into.

const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")
const Kit := preload("res://src/models/props/kit.gd")

## The way through, in tiles: how far across the lit ground reaches, and how high
## the arch stands over it. Wider than a shaft's mouth because nothing is cut
## away — a player walks ONTO this, not down it.
const WIDE := 2.3
const TALL := 3.1
## A hair above the ground, so the light and the terrain never fight for a pixel.
const LIFT := 0.035
## The daylight of 2029, and what it is when the beat has not landed yet: the
## frame is there and the way through is not.
const THROUGH := Color(0.99, 0.88, 0.62, 0.92)
const SHUT := Color(0.24, 0.23, 0.30, 1.0)


static func node(is_open: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "era_gate"
	var k := MeshKit.new()
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	_ground(k, is_open)
	_arch(k, is_open)
	var mi := MeshInstance3D.new()
	mi.name = "found"
	mi.mesh = k.build()
	mi.material_override = PropModels.found_material()
	# Above the terrain and below a body, as the shaft's own mouth is: a player
	# standing in the gate must draw over it.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


## Where 15_lights hangs the gate's pool, in the model's own frame. Daylight
## standing on the ground at night is the thing that makes a gate findable.
static func glow_points() -> Array:
	return [{"at": Vector3(0.0, 0.25, 0.0), "colour": THROUGH, "blink": false}]


## The way through: an oval of another day's light lying on the ground, broken
## into a ring of facets so it is never a clean ellipse — a hole in time with a
## ruled edge would read as a machine's hatch.
static func _ground(k: MeshKit, is_open: bool) -> void:
	var col := THROUGH if is_open else SHUT
	var n := 13
	var mid := Vector3(0.0, LIFT, 0.0)
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		# The edge wanders, so the light reads as something spilling rather than
		# something cut.
		var r0 := WIDE * 0.5 * (0.86 + 0.14 * sin(a0 * 3.0 + 0.7))
		var r1 := WIDE * 0.5 * (0.86 + 0.14 * sin(a1 * 3.0 + 0.7))
		var p0 := Vector3(cos(a0) * r0 * 0.78, LIFT, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r1 * 0.78, LIFT, sin(a1) * r1)
		# WOUND TO FACE THE SKY: (mid, p0, p1) round a rising angle gives a -Y
		# normal and lays the way through face down in the dirt. The same slip as
		# the black site's deck, and it looks identical from outside -- a model
		# that builds, reports its vertices and draws nothing.
		k.tri(mid, p1, p0, col)
	if not is_open:
		return
	# A brighter core, so the middle of the way through is the brightest thing in
	# the frame and the eye goes to it rather than to the arch.
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var r := WIDE * 0.22
		k.tri(Vector3(0.0, LIFT + 0.004, 0.0),
			Vector3(cos(a1) * r * 0.78, LIFT + 0.004, sin(a1) * r),
			Vector3(cos(a0) * r * 0.78, LIFT + 0.004, sin(a0) * r),
			Color(1.0, 0.97, 0.88, 0.96))


## The arch the Seeker stood round it: two legs and a lintel of the machines'
## plate, leaning back off the vertical so the camera sees the INSIDE face of the
## lintel rather than its edge, and a cable run down one leg.
static func _arch(k: MeshKit, is_open: bool) -> void:
	var half := WIDE * 0.52
	var lean := 0.34
	var foot := P.PLATE[1]
	var face := P.PLATE[3] if is_open else P.PLATE[2]
	for sz: float in [-1.0, 1.0]:
		var a := Vector3(0.0, 0.0, sz * half)
		var b := Vector3(-lean, TALL, sz * half)
		_leg(k, a, b, 0.16, foot, face)
		# The pad it is bolted to.
		k.box(Vector3(-0.26, 0.0, sz * half - 0.26), Vector3(0.26, 0.09, sz * half + 0.26), foot)
	# The lintel, leaning with the legs.
	_leg(k, Vector3(-lean, TALL, -half), Vector3(-lean, TALL, half), 0.15, foot, face)
	# What burns on it when the way is open: a strip along the inside of the
	# lintel, pointing DOWN at the ground it lights.
	if is_open:
		k.quad(Vector3(-lean + 0.11, TALL - 0.13, -half + 0.2),
			Vector3(-lean + 0.11, TALL - 0.13, half - 0.2),
			Vector3(-lean - 0.06, TALL - 0.13, half - 0.2),
			Vector3(-lean - 0.06, TALL - 0.13, -half + 0.2), THROUGH)


static func _leg(k: MeshKit, a: Vector3, b: Vector3, r: float, col: Color, cap: Color) -> void:
	var up := (b - a).normalized()
	var side := up.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.BACK
	side = side.normalized() * r
	var out := side.cross(up).normalized() * r
	for i in 4:
		var a0 := TAU * float(i) / 4.0 + PI * 0.25
		var a1 := TAU * float(i + 1) / 4.0 + PI * 0.25
		var o0 := side * cos(a0) + out * sin(a0)
		var o1 := side * cos(a1) + out * sin(a1)
		k.quad(a + o1, a + o0, b + o0, b + o1, col if i % 2 == 0 else cap)
