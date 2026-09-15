extends MachineModel
## The flock: a scatter, never a formation. Thirty-six shards in a jittered
## cloud, each flying its own small orbit on exactly the same period, each with
## an amber point at its centre. Too small to plate: there is no weak side, and
## everything about it is soft. Wind grounds it.
##
## alert, hurt  closes up
## windup       draws back and thickens; strike stretches out at you
## dead         the lights go out and the shards fall where they are

const COUNT := 36
const STEP := 0.36
const ORBIT := 0.07
const OMEGA := 5.5

var _home: PackedVector3Array = PackedVector3Array()
var _axis: PackedVector3Array = PackedVector3Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _fallen: PackedVector3Array = PackedVector3Array()
var _shards: MultiMesh
var _dots: MultiMesh
var _spread := 1.0
var _stretch := 1.0
var _offset := Vector3.ZERO
var _orbit_t := 0.0
## Where every shard is, model space. Kept here as well as in the MultiMesh
## because a headless run cannot read MultiMesh transforms back.
var shard_xforms: Array[Transform3D] = []


func build() -> void:
	part_side = &"none"
	height = 1.7
	stride = 2.0
	emission = 0.7
	begin_rig()
	var R := ramp
	for i in COUNT:
		var cx := i % 4
		var cy := (i / 4) % 3
		var cz := i / 12
		var jitter := Vector3(Rng.hash01(141, i, 0) - 0.5, Rng.hash01(141, i, 1) - 0.5, Rng.hash01(141, i, 2) - 0.5) * STEP * 0.8
		_home.append(Vector3((cx - 1.5) * STEP, 0.95 + (cy - 1.0) * STEP, (cz - 1.0) * STEP) + jitter)
		_axis.append(Vector3(Rng.hash01(142, i, 0) - 0.5, 1.0, Rng.hash01(142, i, 1) - 0.5).normalized())
		_phase.append(Rng.hash01(143, i) * TAU)
		var a := Rng.hash01(144, i) * TAU
		var dist := 0.2 + Rng.hash01(145, i) * 0.75
		_fallen.append(Vector3(cos(a) * dist, 0.02, sin(a) * dist))

	# A shard: a flat lozenge with a ridge, sharp at both ends, like a cut vane.
	var sk := FoundKit.kit()
	var vane: Array[Vector2] = [Vector2(0.09, 0.0), Vector2(0.01, 0.05), Vector2(-0.07, 0.0), Vector2(0.01, -0.05)]
	FoundKit.slab(sk, Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD, vane, 0.03, R, 0.01)
	_shards = _multimesh(sk.build())
	var smi := MultiMeshInstance3D.new()
	smi.name = "shards"
	smi.multimesh = _shards
	smi.material_override = material
	add_child(smi)

	var dk := FoundKit.kit()
	FoundKit.spot(dk, Vector3(0.01, 0.016, 0), Vector3.UP, 0.022, 4, Palette.LENS[2], 0.002)
	_dots = _multimesh(dk.build())
	var dmi := MultiMeshInstance3D.new()
	dmi.name = "dots"
	dmi.multimesh = _dots
	dmi.material_override = part_material
	dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dmi)
	_part_swaps.append([_dots, &"mesh", _dots.mesh, FoundKit.darkened(dk).build()])
	finish_rig()
	_place(0.0)


func _multimesh(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = COUNT
	return mm


func _apply_pose() -> void:
	var spread := 1.0
	var stretch := 1.0
	var offset := Vector3.ZERO
	match pose:
		&"alert", &"hurt":
			spread = 0.55
			offset = Vector3(0, 0.12, 0)
		&"windup":
			spread = 0.5
			offset = Vector3(-0.3, 0.05, 0)
		&"strike":
			spread = 0.7
			stretch = 1.9
			offset = Vector3(0.55, -0.1, 0)
	var k := 1.0 if pose_time > 100.0 else 1.0 - exp(-8.0 * _dt)
	_spread = lerpf(_spread, spread, k)
	_stretch = lerpf(_stretch, stretch, k)
	_offset = _offset.lerp(offset, k)
	_place(_dt)


func _place(delta: float) -> void:
	if running():
		_orbit_t += delta
	for i in COUNT:
		var xf := Transform3D.IDENTITY
		var home := _home[i]
		var fly := Vector3(home.x * _spread * _stretch, 0.95 + (home.y - 0.95) * _spread, home.z * _spread) + _offset
		var a := _orbit_t * OMEGA + _phase[i]
		var ax := _axis[i]
		var u := ax.cross(Vector3.RIGHT).normalized()
		var v := ax.cross(u)
		fly += (u * cos(a) + v * sin(a)) * ORBIT
		var yaw := a + PI * 0.5
		var pos := fly
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.35 * sin(a))
		if pose == &"dead":
			var start := LIGHT_FIRST + Rng.hash01(146, i) * 0.5
			var f := clampf((pose_time - start) / 0.45, 0.0, 1.0)
			f *= f
			pos = fly.lerp(_fallen[i], f)
			basis = basis.slerp(Basis(Vector3.UP, _phase[i]), f)
		xf = Transform3D(basis, pos)
		if shard_xforms.size() < COUNT:
			shard_xforms.resize(COUNT)
		shard_xforms[i] = xf
		_shards.set_instance_transform(i, xf)
		# Dying, the points go out one at a time before anything falls.
		var dot := xf
		if pose == &"dead" and pose_time >= PART_OUT * Rng.hash01(147, i):
			dot = Transform3D(Basis().scaled(Vector3.ZERO), pos)
		_dots.set_instance_transform(i, dot)
