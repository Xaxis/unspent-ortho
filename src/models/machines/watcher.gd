extends MachineModel
## A watcher: a cross on a tripod, the only cross-shaped thing in the world. A
## surveyor's instrument that nobody is standing behind. It stands on rises and
## looks, indexing its head through the same bearings forever. The optic at the
## front of the head is its working part. The head bar is a long spindle across
## the line of sight, so end-on it is as thin as the mast: its width shows which
## way it looks.
##
## alert  the inner mast runs up out of its sleeve, showing its graduations, and
##        fins stand out above and below the bar ends
## dead   the light dies, the legs fold shut up the mast and the post is left
##        standing on its plumb point

const HUB_Y := 0.62
const FOOT := Vector3(0.5, -0.6, 0.0)
const BEARINGS := [PI, PI / 3.0, -PI / 3.0]
const FIN_Z := 0.31


func build() -> void:
	part_side = &"front"
	height = 1.78
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)

	var hub := joint(&"hub", self, Vector3(0, HUB_Y, 0))
	var hk := FoundKit.kit()
	# A six-sided drum, a plumb point under it, and the sleeve of the mast.
	FoundKit.disc(hk, Vector3.ZERO, Vector3.UP, 0.15, 0.1, 6, 0.025, R, Color(0, 0, 0, 0), PI / 6.0)
	FoundKit.lathe(hk, Vector3(0, -0.05, 0), Vector3.UP, [Vector2(0.07, 0.0), Vector2(0.0, -0.17)], 6, D, PI / 6.0)
	FoundKit.tbar(hk, Vector3(0, 0.05, 0), Vector3(0, 0.6, 0), 0.052, 0.044, 8, R)
	FoundKit.disc(hk, Vector3(0, 0.6, 0), Vector3.UP, 0.066, 0.04, 8, 0.012, R, Color(0, 0, 0, 0), PI / 8.0)
	FoundKit.disc(hk, Vector3(0, 0.08, 0), Vector3.UP, 0.062, 0.03, 8, 0.01, R, Color(0, 0, 0, 0), PI / 8.0)
	for j in 6:
		var a := float(j) / 6.0 * TAU
		var n := Vector3(cos(a), 0, sin(a))
		FoundKit.mark(hk, n * 0.131, n, Vector3.UP, 0.03, 0.03, R[5], 0.004)
	FoundKit.streaks(hk, Vector3(0.047, 0.56, 0.0), Vector3.RIGHT, 0.05, 0.3, 2, 11, R[2])
	body_mesh(hk, hub)

	for i in 3:
		var leg := joint(StringName("leg%d" % i), hub, Vector3(0.1, -0.02, 0), Vector3(0, BEARINGS[i], 0))
		# The joint sits at the knuckle; bearings rotate the knuckle round the hub.
		leg.position = Basis(Vector3.UP, BEARINGS[i]) * Vector3(0.1, -0.02, 0)
		var lk := FoundKit.kit()
		FoundKit.disc(lk, Vector3.ZERO, Vector3.BACK, 0.036, 0.07, 6, 0.01, R)
		FoundKit.tbar(lk, Vector3.ZERO, FOOT, 0.028, 0.019, 6, R)
		# A shoe with a peg and a point, as on a surveyor's legs.
		FoundKit.tbar(lk, FOOT * 0.86, FOOT * 0.86 + Vector3(0.05, 0.0, 0), 0.012, 0.012, 4, D)
		FoundKit.lathe(lk, FOOT, Vector3.DOWN, [Vector2(0.024, 0.0), Vector2(0.0, 0.06)], 6, D)
		body_mesh(lk, leg)

	var mast := joint(&"mast", hub, Vector3(0, 0.6, 0))
	var mk := FoundKit.kit()
	FoundKit.tbar(mk, Vector3(0, -0.36, 0), Vector3(0, 0.5, 0), 0.03, 0.03, 8, R)
	# Graduations: hidden in the sleeve until the mast runs up.
	FoundKit.ticks(mk, Vector3(0.03, -0.3, 0), Vector3(0.03, 0.42, 0), Vector3.RIGHT, 16, R[5], 0.022)
	FoundKit.ticks(mk, Vector3(0, -0.3, 0.03), Vector3(0, 0.42, 0.03), Vector3.BACK, 16, R[5], 0.022)
	body_mesh(mk, mast)

	# The scan yaw sits between mast and head and is driven by the routine, not the pose.
	var yaw := Node3D.new()
	yaw.name = "yaw"
	yaw.position = Vector3(0, 0.52, 0)
	mast.add_child(yaw)
	var head := joint(&"head", yaw, Vector3.ZERO)
	var bk := FoundKit.kit()
	# The cross bar: a straight eight-sided bar with a terminal at each end.
	FoundKit.tbar(bk, Vector3(0, 0, -0.42), Vector3(0, 0, 0.42), 0.046, 0.046, 8, R, 0.02)
	for sz: float in [-1.0, 1.0]:
		FoundKit.disc(bk, Vector3(0, 0, sz * 0.43), Vector3.BACK, 0.064, 0.05, 8, 0.014, R, Color(0, 0, 0, 0), PI / 8.0)
		FoundKit.mark(bk, Vector3(0.0, 0.047, sz * 0.2), Vector3.UP, Vector3.BACK, 0.016, 0.26, R[2], 0.002)
	# The instrument: an eight-sided barrel on the line of sight.
	FoundKit.lathe(bk, Vector3.ZERO, Vector3.RIGHT, [Vector2(0.07, -0.19), Vector2(0.1, -0.15), Vector2(0.105, 0.08), Vector2(0.085, 0.15), Vector2(0.085, 0.17)], 8, R, PI / 8.0)
	# Upper arm of the cross and its cap; a collar under the barrel.
	FoundKit.tbar(bk, Vector3(0, 0.09, 0), Vector3(0, 0.42, 0), 0.028, 0.022, 8, R)
	FoundKit.disc(bk, Vector3(0, 0.43, 0), Vector3.UP, 0.045, 0.03, 8, 0.01, R, Color(0, 0, 0, 0), PI / 8.0)
	FoundKit.disc(bk, Vector3(0, -0.1, 0), Vector3.UP, 0.05, 0.04, 8, 0.01, D, Color(0, 0, 0, 0), PI / 8.0)
	# Plate at the back of the barrel with its cold slit; rivets round the bezel.
	FoundKit.visor(bk, Vector3(-0.19, 0.0, 0), Vector3.LEFT, Vector3.UP, 0.1, 0.022)
	for j in 8:
		var a := float(j) / 8.0 * TAU + PI / 8.0
		FoundKit.mark(bk, Vector3(0.151, sin(a) * 0.072, cos(a) * 0.072), Vector3.RIGHT, Vector3.UP, 0.02, 0.02, R[5], 0.004)
	FoundKit.streaks(bk, Vector3(0.14, -0.06, 0.0), Vector3.RIGHT, 0.08, 0.05, 3, 12, R[2])
	body_mesh(bk, head)
	add_scan(head, Vector3(-0.19, 0.0, 0), Vector3.LEFT, Vector3.BACK, 0.07, 0.02, 2.4)

	var iris := joint(&"iris", head, Vector3(0.172, 0, 0))
	var ik := FoundKit.kit()
	FoundKit.optic(ik, Vector3.ZERO, Vector3.RIGHT, 0.058)
	part_mesh(ik, iris)
	set_part_anchor(head, Vector3(0.18, 0, 0), 0.5)

	# Fins: blades folded flat along the bar at rest, stood out on alert.
	for i in 4:
		var up := i < 2
		var sz := 1.0 if i % 2 == 0 else -1.0
		var dir := 1.0 if up else -1.0
		var fin := joint(StringName("fin%d" % i), head, Vector3(0, dir * 0.05, sz * FIN_Z))
		var fk := FoundKit.kit()
		var blade: Array[Vector2] = [Vector2(-0.045, 0.0), Vector2(0.045, 0.0), Vector2(0.018, 0.25), Vector2(-0.018, 0.25)]
		if not up:
			blade = [Vector2(-0.045, 0.0), Vector2(-0.018, -0.2), Vector2(0.018, -0.2), Vector2(0.045, 0.0)]
		FoundKit.slab(fk, Vector3.ZERO, Vector3.BACK, Vector3.UP, blade, 0.018, R)
		FoundKit.mark(fk, Vector3(0.01, dir * 0.12, 0), Vector3.RIGHT, Vector3.UP, 0.012, 0.14, R[5], 0.002)
		body_mesh(fk, fin)
	_fold_fins()
	finish_rig()


## Fin rest: lying along the bar toward its middle.
func _fold_fins() -> void:
	for i in 4:
		var up := i < 2
		var sz := 1.0 if i % 2 == 0 else -1.0
		# Rotating about X carries +Y toward +Z; fold each fin toward the centre.
		(joints[StringName("fin%d" % i)] as Node3D).rotation.x = sz * PI * 0.5 * (1.0 if up else -1.0)


func _fins_out(amount: float) -> Dictionary:
	var d := {}
	for i in 4:
		var up := i < 2
		var sz := 1.0 if i % 2 == 0 else -1.0
		var s := 1.0 if up else -1.0
		# From folded (sz*s*90deg) to standing a little outward (-sz*s*16deg).
		d[StringName("fin%d" % i)] = r(Vector3(-sz * s * (PI * 0.5 + 0.28) * amount, 0, 0))
	return d


func _pose_deltas(p: StringName) -> Dictionary:
	match p:
		&"alert":
			var d := _fins_out(1.0)
			d[&"mast"] = pr(Vector3(0, 0.3, 0))
			for i in 3:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.1))
			d[&"hub"] = pr(Vector3(0, 0.05, 0))
			return d
		&"windup":
			var d := _fins_out(0.6)
			d[&"mast"] = pr(Vector3(0, 0.2, 0))
			d[&"head"] = r(Vector3(0, 0, -0.36))
			d[&"hub"] = r(Vector3(0, 0, 0.12))
			return d
		&"strike":
			var d := _fins_out(1.0)
			d[&"mast"] = pr(Vector3(0, 0.08, 0))
			d[&"head"] = r(Vector3(0, 0, -0.55))
			d[&"hub"] = pr(Vector3(0.1, -0.04, 0), Vector3(0, 0, -0.26))
			return d
		&"dead":
			# Folded shut like a put-away tripod, the plumb point in the ground:
			# the post stays standing.
			var d := {}
			d[&"hub"] = pr(Vector3(0, -HUB_Y + 0.17, 0))
			for i in 3:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 2.18))
			d[&"mast"] = pr(Vector3(0, -0.3, 0))
			d[&"head"] = r(Vector3(0.0, 0, -0.42))
			return d
	return {}


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		match j:
			&"mast": return Vector2(LIGHT_FIRST + 0.5, 0.5)
			&"head": return Vector2(LIGHT_FIRST + 1.1, 0.35)
	return super(p, j)


## The three legs lift in turn, one at a time: a slow exact tripod walk.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	for i in 3:
		var t := fposmod(phase * 3.0 - i, 3.0)
		var lift := sin(t * PI) if t < 1.0 else 0.0
		d[StringName("leg%d" % i)] = r(Vector3(0, 0, lift * 0.24))
	d[&"hub"] = pr(Vector3(0, absf(sin(phase * TAU * 1.5)) * 0.02, 0))
	return d


func _routine(_delta: float, on: bool) -> void:
	var yaw := (joints[&"head"] as Node3D).get_parent() as Node3D
	if not on:
		return
	if pose == &"stand" or pose == &"walk":
		# Centre, left, centre, right: a servo move then an exact hold.
		var t := fposmod(clock, 6.0) / 6.0
		var slot := int(t * 4.0)
		var within := t * 4.0 - slot
		var bearings := [0.0, 0.55, 0.0, -0.55]
		var from: float = bearings[(slot + 3) % 4]
		var to: float = bearings[slot]
		yaw.rotation.y = lerpf(from, to, smoothstep(0.0, 1.0, clampf(within / 0.25, 0.0, 1.0)))
	else:
		yaw.rotation.y = move_toward(yaw.rotation.y, 0.0, 0.15)
