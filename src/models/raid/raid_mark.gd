class_name RaidMark
extends Node3D
## The tag the plan hangs on a thing it has decided to take (docs/ART.md §10,
## docs/VISION.md §9.5).
##
## When a step is warned, every piece the party is coming for wears one of these
## — a machine's own plate, spiked into the player's timber, numbered in notches
## and carrying one small beacon on the machines' beat. It is the warning made
## SPECIFIC: not "something is coming" but "that mast, that cell, that wall", so
## a player can see their own signature pointing at the thing that is about to
## go, and take it down themselves before anything arrives.
##
## FOUND and nothing else: ruled, unhatched, chamfered, riveted, drawn in the
## machines' violet with one beacon. It is deliberately ugly on a holding —
## exact where everything round it leans — because that is what it means.
##
##   tools/shot.sh shots/raids/gallery.png --scene=gallery --filter=mark

const Parts := preload("res://src/models/settlement/settle_parts.gd")
const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")

## How many drawings there are: the plan stamps a different number on each thing
## it means to take, and nothing it makes is ever hand-drawn twice over.
const VARIANTS := 4
## How high the spike stands. Tall enough that the plate clears a plot and a
## palisade and reads at 640x360, short enough to be a tag on somebody's yard
## and not a mast of its own.
const HANG := 1.34
## The plate's own size.
const WIDE := 0.46
const TALL := 0.30

var variant := 0
var _mesh: MeshInstance3D
static var _cache: Dictionary = {}


static func create(v: int) -> RaidMark:
	var m := RaidMark.new()
	m.variant = posmod(v, VARIANTS)
	m.name = "raid_mark"
	return m


func build() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "found"
	_mesh.material_override = PropModels.found_material()
	_mesh.mesh = _meshes(variant)
	add_child(_mesh)


static func _meshes(v: int) -> ArrayMesh:
	var key := "mark|%d" % v
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new()
	Parts.ruled(k)
	# The spike: driven into whatever was to hand, never plumb, because a machine
	# that is not building does not care how it looks in somebody's yard.
	var lean := (float(v) - 1.5) * 0.055
	var foot := HANG - TALL - 0.06
	k.strut(Vector3(0.0, -0.06, 0.0), Vector3(lean, HANG - 0.04, 0.0), 0.028, 4, P.PLATE[3])
	# A collar where the spike meets the plate: a machine bolts, it does not lash.
	k.prism(lean * 0.7, foot - 0.05, 0.0, 0.05, foot + 0.03, 0.045, 6, P.PLATE[2], P.PLATE[3])
	# The plate: a bright face on a dark frame, so it reads as a sign at a
	# distance and as riveted plate up close.
	var cx := lean
	var y := foot + 0.02
	k.block(cx, y - 0.02, -0.004, WIDE + 0.05, TALL + 0.05, 0.024, P.PLATE[1], P.PLATE[2])
	k.block(cx, y, 0.014, WIDE, TALL, 0.014, P.PLATE[4], P.PLATE[5])
	for i in 4:
		var rx := cx + (-0.17 if i % 2 == 0 else 0.17)
		var ry := y + (0.035 if i < 2 else TALL - 0.055)
		k.prism(rx, ry, 0.026, 0.016, ry + 0.016, 0.013, 5, P.PLATE[2])
	# The plan's own numbering, cut across the plate: a run of notches, different
	# on every mark, so a yard with three marks in it is wearing three numbers.
	var notches := 3 + v
	for i in notches:
		var nx := cx - 0.145 + 0.072 * float(i)
		var deep := 0.09 + 0.05 * float((i + v) % 3)
		k.block(nx, y + 0.075, 0.028, 0.022, deep, 0.008, P.PLATE[0])
	# A cold strip along the head of the plate — the machines' steady light,
	# saying the place is live on their books — and one beacon at the corner,
	# blinking on the same beat as every other thing they left standing. Neither
	# is amber: the one warm read on a machine is its working part (docs/ART.md
	# §4), and a tag on somebody's yard is not a working part.
	Parts.strip(k, Vector3(cx - WIDE * 0.42, y + TALL + 0.012, 0.02),
		Vector3(cx + WIDE * 0.42, y + TALL + 0.012, 0.02), 0.018)
	k.prism(cx + WIDE * 0.34, y + 0.02, 0.034, 0.024, y + 0.072, 0.017, 6, Works.BEACON, Works.BEACON)
	var mesh := k.build()
	_cache[key] = mesh
	return mesh


## Every number the plan stamps, side by side: what a holding wears when it has
## been decided about (docs/ART.md §10).
static func gallery() -> Array:
	var out: Array = []
	for v in VARIANTS:
		var m := RaidMark.create(v)
		m.build()
		var holder := Node3D.new()
		holder.add_child(m)
		out.append({"name": "raid mark %d" % v, "node": holder})
	return out
