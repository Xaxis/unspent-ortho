extends MachineModel
## THE KITE: the Mesas' watcher (docs/LANDSCAPES.md §6). A wide slow frame of
## rods and taut plate flown on a line off a winch the plan bolts beside a span
## pylon, circling over the canyon and filing what it sees. It is the plan's eye
## on a ropeway that crosses country no road can: nothing walks those spans, so
## what watches them has to hang over them.
##
## THE BODY THE FIGHT KNOWS IS THE WINCH. What flies is drawn off it on its line,
## five units up and circling; the body a blow lands on, the part a player cuts,
## and the place it files from are the winch on the ground, which is exactly
## where the spec puts its weakness — cut the line at the pylon and it drops.
## That is why this model can be drawn honestly before anything in the game
## flies (docs/LANDSCAPES.md, shared system 6): it never has to be MOVED at
## altitude, only drawn there, and a real sun gives the frame a real shadow on
## the canyon floor without a system to fake one.
##
## Why a KITE. Every other watcher stands on the ground and turns; this is the
## one in the game whose read is ABOVE the player, a flat dark cross against a
## hard sky, and its line down to the rock is what tells you where to go to put
## it out. Watcher's ramp, cold indigo (Palette: a machine's colour is its role).
##
## Poses.
## stand  the frame circles on its line, banked into the turn
## walk   the same: the winch does not walk, the frame goes on circling
## alert  the frame stops circling and hangs over what it has seen, nose down
## windup the line winds in a turn and the frame stoops
## strike it holds, staring: a watcher files, it does not bite
## hurt   the line judders
## dead   the line is cut: the frame comes down on the rock beside the winch

const LINE_UP := 5.0
const LINE_OUT := 1.8
const SPAN := 3.2
const CHORD := 1.4

var _t := 0.0


func build() -> void:
	part_side = &"front"
	height = 5.6
	stride = 1.0
	gallery_turn = 30.0
	emission = 0.35
	begin_rig()
	ramp = Palette.MACHINE["watcher"]
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)
	var winch := joint(&"winch", self, Vector3.ZERO)
	_winch(winch, R, D, DD)
	var line := joint(&"line", winch, Vector3(0.0, 0.62, 0.0))
	var lk := FoundKit.kit()
	FoundKit.tbar(lk, Vector3.ZERO, Vector3(LINE_OUT, LINE_UP, 0.0), 0.016, 0.012, 4, FoundKit.flat(Palette.INK[2]))
	body_mesh(lk, line)
	var frame := joint(&"frame", line, Vector3(LINE_OUT, LINE_UP, 0.0))
	_frame(frame, R, D, DD)
	finish_rig()


## The winch: a squat drum on a bolted foot, the line paying off its top. Its
## front face carries the plan strip and the amber of the drum's brake, which is
## the working part: where a blade goes through the line.
func _winch(winch: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(0.7, 0.6, 0.12)
	FoundKit.loft(k, [FoundKit.ring(plan, 0.0, 0.04), FoundKit.ring(plan, 0.08), FoundKit.ring(plan, 0.22, 0.06)], DD, false, false)
	# Four bolts through the foot into the rock.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			FoundKit.disc(k, Vector3(sx * 0.26, 0.225, sz * 0.22), Vector3.UP, 0.035, 0.03, 6, 0.0, R)
	# Cheeks and the drum between them, the line wound on it.
	for sz: float in [-1.0, 1.0]:
		FoundKit.slab(k, Vector3(0.0, 0.22, sz * 0.2), Vector3.RIGHT, Vector3.UP,
			[Vector2(-0.2, 0.0), Vector2(0.2, 0.0), Vector2(0.14, 0.4), Vector2(-0.14, 0.4)], 0.04, D, 0.008)
	FoundKit.lathe(k, Vector3(0.0, 0.46, -0.18), Vector3.BACK, [Vector2(0.11, 0.0), Vector2(0.13, 0.02), Vector2(0.13, 0.34), Vector2(0.11, 0.36)], 10, D, PI / 10.0)
	FoundKit.lathe(k, Vector3(0.0, 0.46, -0.14), Vector3.BACK, [Vector2(0.135, 0.0), Vector2(0.15, 0.03), Vector2(0.15, 0.25), Vector2(0.135, 0.28)], 10, FoundKit.flat(Palette.INK[2]), 0.0)
	# The fairlead the line runs up through.
	FoundKit.tbar(k, Vector3(0.0, 0.46, 0.0), Vector3(0.0, 0.64, 0.0), 0.04, 0.03, 6, DD)
	body_mesh(k, winch)
	add_lamp(winch, Vector3(0.351, 0.14, 0.0), Vector3.RIGHT, Vector3.UP, 0.04, 0.04, &"status")
	# The brake: an amber band on the drum's front end, the part.
	var gk := FoundKit.kit()
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	FoundKit.lathe(gk, Vector3(0.2, 0.46, 0.0), Vector3.RIGHT, [Vector2(0.06, 0.0), Vector2(0.09, 0.02), Vector2(0.09, 0.08), Vector2(0.06, 0.1)], 10, amber, PI / 10.0)
	part_mesh(gk, winch)
	set_part_anchor(winch, Vector3(0.3, 0.46, 0.0), 0.5)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(0.0, 0.1, 0.301), Vector3.BACK, 0.6, 0.12, 4, 251,
		[Palette.RUST[1], Palette.RUST[2], Palette.EARTH[2], Palette.RUST[2], Palette.RUST[3], Palette.SAND[3]])
	wear_mesh(w, winch)


## The frame: a keel along the wind, a spar across it, a bow of rod round the
## leading edge and taut plate stretched between them, with one lens under the
## keel that looks down. It is wide and thin on purpose: flat dark cross against
## the sky, the one read the canyon has overhead.
func _frame(frame: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var nose := Vector3(CHORD * 0.6, 0.0, 0.0)
	var tail := Vector3(-CHORD * 0.4, 0.0, 0.0)
	var tip_r := Vector3(-0.1, 0.12, SPAN * 0.5)
	var tip_l := Vector3(-0.1, 0.12, -SPAN * 0.5)
	var s0 := k.vertex_count()
	FoundKit.tbar(k, tail, nose, 0.035, 0.03, 5, D)
	FoundKit.tbar(k, tip_l, tip_r, 0.03, 0.03, 5, D)
	FoundKit.tbar(k, nose, tip_r, 0.022, 0.02, 4, DD)
	FoundKit.tbar(k, nose, tip_l, 0.022, 0.02, 4, DD)
	FoundKit.tbar(k, tail, tip_r, 0.018, 0.018, 4, DD)
	FoundKit.tbar(k, tail, tip_l, 0.018, 0.018, 4, DD)
	k.smooth_range(s0, k.vertex_count(), 70.0)
	# The plate: four thin panels, each a slab so it reads from above and below.
	for side: float in [-1.0, 1.0]:
		var tip := tip_r if side > 0.0 else tip_l
		for pair: Array in [[nose, R], [tail, D]]:
			var a: Vector3 = pair[0]
			var col: Array = pair[1]
			var u := (a - Vector3.ZERO)
			var v := tip - Vector3.ZERO
			var n := u.cross(v).normalized()
			if n.y < 0.0:
				n = -n
			var uu := u.normalized()
			var vv := n.cross(uu).normalized()
			var poly: Array[Vector2] = [Vector2(0.04, 0.0), Vector2(u.length() - 0.06, 0.0), Vector2(v.dot(uu) * 0.94, v.dot(vv) * 0.94)]
			if poly[2].y < 0.0:
				poly = [poly[0], poly[2], poly[1]]
			FoundKit.slab(k, Vector3(0.0, -0.008, 0.0), uu, vv, poly, 0.016, col)
	FoundKit.rivets(k, Vector3(-0.3, 0.021, 0.0), Vector3(0.6, 0.021, 0.0), Vector3.UP, 5, R[5])
	# A short tail of plate streamers off the keel's end, which is what shows
	# which way the wind has it.
	FoundKit.tbar(k, tail, tail + Vector3(-0.5, -0.12, 0.0), 0.012, 0.008, 4, DD)
	body_mesh(k, frame)
	# The lens under the keel, looking down at the canyon.
	add_lamp(frame, Vector3(0.2, -0.045, 0.0), Vector3.DOWN, Vector3.RIGHT, 0.08, 0.08, &"optic")
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(0.3, 0.02, 0.6), Vector3.UP, Vector3.RIGHT, 0.3, 0.2, Palette.MACHINE["hauler"], 252)
	wear_mesh(w, frame)


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"frame"] = r(Vector3(0.0, 0.0, -0.35))
			d[&"line"] = r(Vector3(0.0, 0.0, 0.12))
		&"windup":
			d[&"line"] = r(Vector3(0.0, 0.0, 0.22))
			d[&"frame"] = r(Vector3(0.0, 0.0, -0.5))
		&"strike":
			d[&"frame"] = r(Vector3(0.0, 0.0, -0.3))
		&"hurt":
			d[&"line"] = r(Vector3(0.06, 0.0, -0.05))
		&"dead":
			# The line is cut and the frame comes down on the rock beside the
			# winch, a wing tip up where it broke on landing.
			d[&"line"] = r(Vector3(0.0, 0.0, -1.24))
			d[&"frame"] = r(Vector3(0.3, 0.0, 1.1))
	return d


func _gait_deltas(_phase: float) -> Dictionary:
	return {}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_t += delta
	# It circles on its line while it watches, and hangs still once it has
	# something: a watcher that has seen you stops looking round.
	var line := joints[&"line"] as Node3D
	if not locked():
		line.rotation.y = _t * 0.35
	var frame := joints[&"frame"] as Node3D
	frame.rotation.x = 0.0 if locked() else 0.28 + sin(_t * 0.9) * 0.05


## Its own review surface (the gallery finds any script under src/models with a
## `gallery()`). Not in `MachineGallery.KINDS`, for the skater's reason: that
## list is the lineup frame the wear and ramp tests measure.
##
##   tools/shot.sh shots/x.png --scene=gallery --filter=kite
static func gallery() -> Array:
	const MG := preload("res://src/models/machines/machine_gallery.gd")
	var out: Array = []
	for p: StringName in [&"stand", &"alert", &"windup", &"dead"]:
		var item: FigureModel = MG.make(&"kite", p, 0.3)
		var holder := Node3D.new()
		holder.add_child(item)
		out.append({"name": "kite %s" % p, "node": holder})
	return out
