extends MachineModel
## A skater: the Glass Desert's hunter (docs/LANDSCAPES.md, src/content/
## roster.gd `skater`). A long low lozenge of plate on four blade-skates, a slit
## across its nose reading the glass ahead, a dorsal rib along its back and the
## drive that pushes it standing proud of its tail. Nothing about it is upright:
## on a landscape whose every line lies flat it reads as a bar sliding across
## the plates, and the one thing that stands up off it is the rib.
##
## Why the SMALLEST hunter's structure. It was written from the runner's, the
## machine every player meets first: one rooted hull, limbs hung off it, a
## working part at the back, two pin eyes and a beam. What changed is what a
## skate is — four blades instead of two feet — so the gait is a PUSH and not a
## stride: the back skates go out and in, the hull rolls, and the nose never
## bobs, because a thing on blades glides.
##
## stand  settled on its four blades, the drive ticking over
## walk   SKATING: the back blades push out and back in turn, the hull rolls
## alert  it has you: the hull rises, the nose comes down to the glass, the
##        front blades bite
## windup the hull rears back off its front blades and the back blades splay
## strike it lunges, nose down, through where you were
## hurt   the hull rolls off true
## dead   it goes over on its side, blades folded under it
##
## lights two pin eyes at the ends of the nose slit and a beam on the glass
##        ahead; a status lamp on the hull's back; the amber drive at the tail
## wear   sand caked up the blade struts, plate off another hunter patched over
##        the hull, a scorch on its back where a strike came down near it, grime

const HULL_Y := 0.42
## Where the four blades hang: the hull's corners, in its own frame.
const BLADE_X := 0.42
const BLADE_Z := 0.3
## An eight-sided drum's facets meet at 45 degrees: a weld at this angle rounds
## the hull and the drive and keeps the chamfers, the caps and the blades hard.
const ROUND := 50.0

var _t := 0.0


func build() -> void:
	part_side = &"back"
	height = 0.72
	stride = 1.6
	nominal_speed = 3.0
	gallery_turn = 40.0
	begin_rig()
	# A hunter's ramp: the palette runs the machine ramps by ROLE, and this is
	# the glass desert's hunter. `Palette.MACHINE` is a solved packing of twelve
	# and a thirteenth would move every pair, so it borrows the longlegs'.
	ramp = Palette.MACHINE["longlegs"]
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hull := joint(&"hull", self, Vector3(0, HULL_Y, 0))
	_hull(hull, R, D)
	_blades(hull, R, D, DD)
	_drive(hull)
	finish_rig()


## Weld the shape pushed since `from`: the same triangles, told where they curve.
static func _weld(k: MeshKit, from: int, crease: float = ROUND) -> void:
	k.smooth_range(from, k.vertex_count(), crease)


## One lofted lozenge, long and low, with the slit across its nose and the rib
## along its back.
func _hull(hull: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(1.3, 0.5, 0.12)
	var s := k.vertex_count()
	FoundKit.loft(k, [FoundKit.ring(plan, -0.14, 0.06), FoundKit.ring(plan, -0.06), FoundKit.ring(plan, 0.12), FoundKit.ring(plan, 0.18, 0.08)], R, true, true)
	_weld(k, s)
	FoundKit.visor(k, Vector3(0.651, 0.02, 0.0), Vector3.RIGHT, Vector3.UP, 0.26, 0.03)
	FoundKit.seam(k, Vector3(-0.5, 0.181, 0.0), Vector3(0.4, 0.181, 0.0), Vector3.UP, R, 5)
	for sz: float in [-1.0, 1.0]:
		FoundKit.panel(k, Vector3(-0.1, 0.03, sz * 0.251), Vector3.BACK * sz, Vector3.UP, 0.44, 0.14, R)
		FoundKit.rivets(k, Vector3(0.3, 0.1, sz * 0.251), Vector3(0.56, 0.1, sz * 0.251), Vector3.BACK * sz, 3, R[5])
	# The rib: the one thing that stands up off a body built to lie flat, and
	# what tells a skater from a slab of debris at a hundred tiles.
	var rib: Array[Vector2] = [Vector2(-0.5, 0.18), Vector2(0.3, 0.18), Vector2(0.1, 0.34), Vector2(-0.4, 0.3)]
	FoundKit.slab(k, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, rib, 0.04, R, 0.008)
	FoundKit.ticks(k, Vector3(-0.38, 0.3, 0.021), Vector3(0.06, 0.32, 0.021), Vector3.BACK, 6, R[5], 0.02)
	body_mesh(k, hull)
	add_scan(hull, Vector3(0.652, 0.02, 0.0), Vector3.RIGHT, Vector3.BACK, 0.2, 0.026, 1.2)
	for sz: float in [-1.0, 1.0]:
		add_lamp(hull, Vector3(0.655, 0.07, sz * 0.11), Vector3.RIGHT, Vector3.UP, 0.022, 0.026, &"optic")
	add_lamp(hull, Vector3(-0.2, 0.181, -0.12), Vector3.UP, Vector3.RIGHT, 0.034, 0.036, &"status")
	# The glass it is closing across, lit from the pair of eyes.
	add_beam(self, Vector3(0.62, HULL_Y + 0.06, 0), Vector3(2.0, -1.1, 0), 1.6, 0.9)
	day_marks(hull, Vector3(0.2, 0.03, 0.251), Vector3.BACK, Vector3.UP, 0.5, 0.16, 161, 2.0)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(-0.3, 0.06, -0.251), Vector3.FORWARD, Vector3.UP, 0.22, 0.14, Palette.MACHINE["runner"], 162)
	FoundKit.scorch(w, Vector3(0.24, 0.182, 0.1), Vector3.UP, 0.09, 163)
	FoundKit.grime(w, Vector3(0.4, -0.02, 0.251), Vector3.BACK, 0.3, 0.1, 4, 164, D)
	wear_mesh(w, hull)


## Four blades on short struts under the hull's corners, every one along the
## line of travel. Sand cakes the struts: it has been off the plates.
func _blades(hull: Node3D, R: Array, D: Array, DD: Array) -> void:
	var sand: Array = [Palette.SAND[2], Palette.SAND[3], Palette.SAND[4], Palette.SAND[3], Palette.SAND[4], Palette.SAND[5]]
	var blade: Array[Vector2] = [Vector2(-0.3, -0.28), Vector2(0.3, -0.28), Vector2(0.36, -0.2),
		Vector2(0.24, -0.1), Vector2(-0.22, -0.1), Vector2(-0.34, -0.2)]
	var i := 0
	for sx: float in [1.0, -1.0]:
		for sz: float in [-1.0, 1.0]:
			var jn := StringName("skate_%s%s" % ["f" if sx > 0 else "b", "l" if sz < 0 else "r"])
			var skate := joint(jn, hull, Vector3(sx * BLADE_X, -0.14, sz * BLADE_Z))
			var k := FoundKit.kit()
			FoundKit.tbar(k, Vector3.ZERO, Vector3(0, -0.12, 0), 0.045, 0.036, 6, D, 0.01)
			FoundKit.disc(k, Vector3(0, -0.11, 0), Vector3.UP, 0.06, 0.03, 6, 0.008, R)
			FoundKit.slab(k, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, blade, 0.05, DD, 0.01)
			body_mesh(k, skate)
			var w := FoundKit.kit()
			FoundKit.grime(w, Vector3(0.0, -0.02, sz * 0.03), Vector3.BACK * sz, 0.08, 0.1, 2, 171 + i, sand)
			wear_mesh(w, skate)
			i += 1


## The drive at the tail: a turned amber barrel with its vanes, standing proud
## of the hull — the working part, out where a player has to come round behind a
## body that is charging them.
func _drive(hull: Node3D) -> void:
	var drive := joint(&"drive", hull, Vector3(-0.6, 0.02, 0.0))
	var dk := FoundKit.kit()
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	var s := dk.vertex_count()
	FoundKit.lathe(dk, Vector3.ZERO, Vector3.LEFT, [Vector2(0.09, 0.0), Vector2(0.14, 0.04), Vector2(0.14, 0.16), Vector2(0.09, 0.2)], 8, barrel, PI / 8.0)
	_weld(dk, s)
	for j in 6:
		var a := j * TAU / 6.0
		var at := Vector3(-0.1, cos(a) * 0.14, sin(a) * 0.14)
		var out := Vector3(0.0, cos(a), sin(a))
		FoundKit.slab(dk, at + out * 0.03, out, Vector3.LEFT,
			[Vector2(-0.04, 0.03), Vector2(0.05, 0.015), Vector2(0.05, -0.015), Vector2(-0.04, -0.03)], 0.14, amber)
	part_mesh(dk, drive)
	set_part_anchor(hull, Vector3(-0.78, 0.02, 0.0), 0.6)


## A body on blades has no limbs to speak with: everything is the hull's tilt
## and where the blades are.
func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			d[&"hull"] = pr(Vector3(0, -0.02, 0))
			d[&"skate_fl"] = pr(Vector3(0, 0, -0.03))
			d[&"skate_fr"] = pr(Vector3(0, 0, 0.03))
		&"alert":
			# It has you: the hull rises, the nose comes down to the glass and
			# the front blades bite in.
			d[&"hull"] = pr(Vector3(0.02, 0.06, 0), Vector3(0, 0, -0.08))
			d[&"skate_fl"] = pr(Vector3(0.04, 0, -0.04), Vector3(0, 0, 0.1))
			d[&"skate_fr"] = pr(Vector3(0.04, 0, 0.04), Vector3(0, 0, 0.1))
		&"windup":
			# It rears back off its front blades and the back blades splay for
			# the push: the opposite shape to alert, so the two never read alike.
			d[&"hull"] = pr(Vector3(-0.12, 0.08, 0), Vector3(0, 0, 0.18))
			d[&"skate_bl"] = pr(Vector3(-0.04, 0, -0.08))
			d[&"skate_br"] = pr(Vector3(-0.04, 0, 0.08))
			d[&"skate_fl"] = r(Vector3(0, 0, -0.14))
			d[&"skate_fr"] = r(Vector3(0, 0, -0.14))
		&"strike":
			d[&"hull"] = pr(Vector3(0.24, -0.04, 0), Vector3(0, 0, -0.14))
			d[&"skate_bl"] = pr(Vector3(0.06, 0, -0.02))
			d[&"skate_br"] = pr(Vector3(0.06, 0, 0.02))
		&"hurt":
			d[&"hull"] = r(Vector3(0.16, 0, 0))
		&"dead":
			# Over on its side, the blades folded under it.
			d[&"hull"] = pr(Vector3(0.1, -0.2, 0.12), Vector3(1.3, 0.2, 0.1))
			d[&"skate_fl"] = r(Vector3(0, 0, 0.6))
			d[&"skate_bl"] = r(Vector3(0, 0, -0.5))
			d[&"skate_fr"] = r(Vector3(0.7, 0, 0))
			d[&"skate_br"] = r(Vector3(0.6, 0, 0))
			d[&"drive"] = r(Vector3(0.4, 0, 0))
	return d


## SKATING: the back blades push out and back in turn, the hull rolls with the
## push, and the nose holds its height — a thing on blades glides.
func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	var b := sin(phase * TAU + PI)
	return {
		&"hull": r(Vector3(a * 0.05, a * 0.02, 0)),
		&"skate_bl": pr(Vector3(a * 0.08, 0, -maxf(0.0, a) * 0.1)),
		&"skate_br": pr(Vector3(b * 0.08, 0, maxf(0.0, b) * 0.1)),
		&"skate_fl": pr(Vector3(0, 0, -absf(a) * 0.02)),
		&"skate_fr": pr(Vector3(0, 0, absf(a) * 0.02)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_t += delta
	(joints[&"drive"] as Node3D).rotation.x = _t * 4.5


## Its own review surface (src/gallery.gd finds any script under src/models with
## a `gallery()`): every pose that changes its shape. It is not in
## `MachineGallery.KINDS` because that list is the lineup frame the wear and
## ramp tests measure, and a thirteenth body would move every width in it.
##
##   tools/shot.sh shots/x.png --scene=gallery --filter=skater
static func gallery() -> Array:
	const MG := preload("res://src/models/machines/machine_gallery.gd")
	var out: Array = []
	for p: StringName in [&"stand", &"walk", &"alert", &"windup", &"strike", &"dead"]:
		var item: FigureModel = MG.make(&"skater", p, 0.3)
		var holder := Node3D.new()
		holder.add_child(item)
		out.append({"name": "skater %s" % p, "node": holder})
	return out
