extends RefCounted
## THE WAY DOWN UNDER THE CAST STONES (docs/interiors): a low concrete hood sunk
## to its shoulders in the turf inside the ring, poured before the machines and
## weathered since -- moss on its crown, rust run down from a steel door painted
## once and long since gone to the metal, a caged bulb over it that nobody has
## changed. It is somebody's, not the plan's: MADE, cast and painted by people.
## Built in its own frame: +X is the way out of the door, the ground at y 0;
## 21_doors stands it at the threshold's host, turned by `rot`.

const Kit := preload("res://src/models/props/kit.gd")
## What stops a body, and the box the shoulder camera's probe holds the eye out
## of (21_doors `sight_boxes`), in its own frame.
const REACH := 0.8
const LO := Vector2(-1.1, -0.8)
const HI := Vector2(0.75, 0.8)
const TOP := 1.1


static func node(mat: Material) -> Node3D:
	var k := Kit.new()
	var cast := GroundColors.made(Color(0.52, 0.51, 0.47), GroundColors.CONCRETE)
	var cast_dark := GroundColors.made(Color(0.38, 0.37, 0.35), GroundColors.CONCRETE)
	var moss := GroundColors.made(Color(0.28, 0.36, 0.2), GroundColors.CLOTH)
	var steel := GroundColors.made(Color(0.2, 0.22, 0.2), GroundColors.TAR)
	var rust := GroundColors.made(Color(0.42, 0.22, 0.12), GroundColors.TAR)
	# The hood: a slab sunk into the ground, its top falling to the back.
	k.slab(-0.2, -0.3, 0.0, 1.8, 1.25, 1.6, 31, cast, cast_dark, 0.03, 0.06)
	# Moss grown over its crown, in clumps.
	for i in 5:
		var h := Rng.hash_ints(i, 0xB0C)
		k.stone(-0.9 + 1.4 * float(h & 255) / 255.0, 0.92, -0.6 + 1.2 * float((h >> 8) & 255) / 255.0,
			0.18 + 0.12 * float((h >> 16) & 255) / 255.0, 0.07, h, moss, 6)
	# The doorway: a recess in the front face, the steel door in it, set back.
	# Wound from -z to +z: MeshKit emits a quad reversed, and this faces out (+X).
	k.face(Vector3(0.705, 0.0, -0.42), Vector3(0.705, 0.82, -0.42), Vector3(0.705, 0.82, 0.42), Vector3(0.705, 0.0, 0.42),
		GroundColors.made(Color(0.05, 0.05, 0.05), GroundColors.TAR))
	k.slab(0.725, 0.0, 0.0, 0.04, 0.78, 0.76, 7, steel, steel, 0.0)
	# Rust run down from its hinges and its wheel.
	for z: float in [-0.3, 0.26]:
		k.face(Vector3(0.748, 0.1, z - 0.04), Vector3(0.748, 0.72, z - 0.03), Vector3(0.748, 0.72, z + 0.03), Vector3(0.748, 0.1, z + 0.05), rust)
	k.made.strut(Vector3(0.77, 0.42, -0.12), Vector3(0.77, 0.42, 0.12), 0.02, 6, rust)
	k.made.strut(Vector3(0.77, 0.3, 0.0), Vector3(0.77, 0.54, 0.0), 0.02, 6, rust)
	# A step down in front of it, and two rebar stubs where a rail was.
	k.slab(0.95, -0.12, 0.0, 0.45, 0.14, 0.9, 9, cast_dark, cast_dark, 0.02)
	for z: float in [-0.62, 0.62]:
		k.made.strut(Vector3(0.78, 0.9, z), Vector3(0.8, 1.2, z), 0.02, 4, rust)
	# The caged bulb over the door, still burning low: a lamp the renderer lights
	# when it is dark.
	var bulb := GroundColors.marked(Color(0.96, 0.74, 0.42), GroundColors.LAMP + 4)
	k.slab(0.8, 0.86, 0.0, 0.08, 0.1, 0.08, 3, bulb, bulb, 0.0)
	k.made.strut(Vector3(0.72, 0.96, 0.0), Vector3(0.84, 0.96, 0.0), 0.012, 4, steel)
	var root := Node3D.new()
	root.name = "bunker_hatch"
	var mm := MeshInstance3D.new()
	mm.mesh = k.made.build()
	mm.material_override = mat
	root.add_child(mm)
	return root
