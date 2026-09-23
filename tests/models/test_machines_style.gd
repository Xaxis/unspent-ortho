extends TestCase
## The machines against docs/LOOK.md: FOUND geometry on found.gdshader and never
## hatched, natural matter they carry on the MADE material, amber only where the
## soft side is, a cold slit on the plate, mirror-exact silhouettes, and a light
## that knows the dark without reading a global shader parameter back.

const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk"]
const FOUND := "res://src/render/found.gdshader"
const MADE := "res://src/render/world.gdshader"
## Kinds whose rest silhouette is deliberately not mirrored: the hauler's hinge is
## open on one flank; the lineman's grips work hand over hand; the clerk reads
## with its head turned.
const ASYMMETRIC: Array[StringName] = [&"hauler", &"lineman", &"clerk", &"flock"]
## One FITTING carried over one flank on purpose, on a body that is otherwise
## mirrored: the harvester's unloading spout, which is the whole of what tells
## that machine from a box at play zoom. The fitting is taken off for the mirror
## rather than the kind being excused it, so the hull it is bolted to is still held.
const ONE_FLANK := {&"harvester": &"spout"}


static func geometry(n: Node, out: Array) -> void:
	if n is GeometryInstance3D and n.name != &"glow" and n.name != &"beam":
		out.append(n)
	for c in n.get_children():
		geometry(c, out)


static func shader_path(g: GeometryInstance3D) -> String:
	var m := g.material_override as ShaderMaterial
	return m.shader.resource_path if m != null and m.shader != null else ""


static func colours(g: GeometryInstance3D) -> PackedColorArray:
	var mesh: Mesh = null
	if g is MeshInstance3D:
		mesh = (g as MeshInstance3D).mesh
	elif g is MultiMeshInstance3D:
		mesh = (g as MultiMeshInstance3D).multimesh.mesh
	if mesh == null or mesh.get_surface_count() == 0:
		return PackedColorArray()
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray


## Mesh colours are stored in 8 bits a channel: compare within one step each.
static func same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.006 and absf(a.g - b.g) < 0.006 and absf(a.b - b.b) < 0.006


static func any_same(list: Array, c: Color) -> bool:
	for x: Color in list:
		if same(x, c):
			return true
	return false


func test_every_machine_surface_is_found_or_named_matter() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid, FigureModel._default_material())
		var geo: Array = []
		geometry(m, geo)
		for g: GeometryInstance3D in geo:
			var path := shader_path(g)
			if g.name == &"matter":
				eq(path, MADE, "%s carried matter is drawn by the hand" % kid)
			else:
				eq(path, FOUND, "%s %s under %s is FOUND" % [kid, g.name, g.get_parent().name])
		m.free()


func test_found_kits_carry_no_hatch_hand() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid)
		var geo: Array = []
		geometry(m, geo)
		for g: GeometryInstance3D in geo:
			if g.name == &"matter" or not g is MeshInstance3D:
				continue
			var uv := (g as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			var hatched := false
			for v in uv:
				if v.x != float(Ink.NONE):
					hatched = true
					break
			check(not hatched, "%s %s has a hatch style" % [kid, g.name])
		m.free()


func test_working_parts_glow_and_bodies_do_not() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		m.settle()
		eq(float(m.material.get_shader_parameter("emission_strength")), 0.0, "%s body emission" % kid)
		gt(m.part_emission(), 0.0, "%s part emission" % kid)
		m.free()


func test_amber_is_only_on_the_soft_side() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		var geo: Array = []
		geometry(m, geo)
		var part_amber := 0
		for g: GeometryInstance3D in geo:
			var on_part := g.material_override == m.part_material
			for c in colours(g):
				if same(c, Palette.LENS[2]) or same(c, Palette.LENS[3]):
					if on_part:
						part_amber += 1
					else:
						fail("%s: amber on %s, which is not the working part" % [kid, g.name])
						break
		if kid == &"clerk":
			# Never built to be near anything: nothing soft to show.
			eq(part_amber, 0, "clerk shows no amber")
		else:
			gt(float(part_amber), 0.0, "%s shows amber somewhere" % kid)
		m.free()


func test_plated_faces_carry_a_cold_slit() -> void:
	for kid in KINDS:
		if kid == &"flock":
			continue
		var m := FigureModel.create(kid)
		var geo: Array = []
		geometry(m, geo)
		var cold := false
		for g: GeometryInstance3D in geo:
			if any_same(Array(colours(g)), Palette.COLD[1]):
				cold = true
				break
		check(cold, "%s has no cold visor slit" % kid)
		m.free()


func test_body_colours_are_exact_ramp_values() -> void:
	# The machine as built: its own ramp and the shared lens, cold, ink, brine
	# and linen values, nothing else.
	var shared: Array = []
	for ramp: Array in [Palette.LENS, Palette.COLD, Palette.INK, Palette.BRINE, Palette.LINEN]:
		shared.append_array(ramp)
	# What the years did: patches are plate cut off other machines, so wear may
	# carry any machine's ramp, or salvage's.
	var worn: Array = Palette.FOUND.duplicate()
	for other: String in Palette.MACHINE:
		worn.append_array(Palette.MACHINE[other])
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		var mine: Array = Palette.MACHINE[String(kid)]
		var wear_bones := {}
		for bone in m._bone_chain.size():
			var c := m._bone_chain[bone]
			var n: Node = m._chain[c] if c >= 0 else null
			while n != null and n != m:
				if n.name == &"wear":
					wear_bones[bone] = true
					break
				n = n.get_parent()
		var own_ramp := 0
		for surface: StringName in m.surfaces:
			if surface == &"matter":
				continue
			var mi: MeshInstance3D = m.surfaces[surface]
			var arrays := mi.mesh.surface_get_arrays(0)
			var cols := arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
			var bpv := bones.size() / maxi(1, cols.size())
			for i in cols.size():
				var c := cols[i]
				if any_same(mine, c):
					own_ramp += 1
					continue
				if any_same(shared, c):
					continue
				if wear_bones.has(bones[i * bpv]) and any_same(worn, c):
					continue
				fail("%s %s: %s is not on the kind's ramp%s" % [kid, surface, c, " (and not on a wear holder)" if any_same(worn, c) else ""])
				break
		# Pieces drawn outside the merged rig (the flock's shards) are all as built.
		var geo: Array = []
		geometry(m, geo)
		for g: GeometryInstance3D in geo:
			if m.surfaces.values().has(g) or g.name == &"matter":
				continue
			for c in colours(g):
				if any_same(mine, c):
					own_ramp += 1
				elif not any_same(shared, c):
					fail("%s %s: %s is not on the kind's ramp" % [kid, g.name, c])
					break
		gt(float(own_ramp), 0.0, "%s is built in its own ramp" % kid)
		m.free()
	# The rule has teeth: another kind's plate off a wear holder is refused.
	var h := FigureModel.create(&"harvester") as MachineModel
	var foreign := 0
	var body: MeshInstance3D = h.surfaces[&"body"]
	for c in body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
		if any_same(Palette.MACHINE["cutter"], c) and not any_same(Palette.MACHINE["harvester"], c):
			foreign += 1
	gt(float(foreign), 0.0, "the harvester's cutter patch is there to be judged")
	h.free()


## Seen straight from the front, the rest silhouette is mirror-exact.
func test_rest_silhouettes_are_mirror_exact() -> void:
	for kid in KINDS:
		if ASYMMETRIC.has(kid):
			continue
		var m := FigureModel.create(kid) as MachineModel
		m.settle()
		var w := 96
		var h := 96
		var mask := PackedByteArray()
		mask.resize(w * h)
		var texel := 0.04
		# The machine as it was built: the years' wear is not mirrored.
		for wear: Node in m.find_children("wear", "Node3D", true, false):
			(wear as Node3D).visible = false
		if ONE_FLANK.has(kid):
			(m.joints[ONE_FLANK[kid]] as Node3D).visible = false
			m.settle()
		_front_mask(m, m, Transform3D.IDENTITY, mask, w, h, texel)
		var diff := 0
		var total := 0
		for y in h:
			for x in w:
				var a := mask[y * w + x]
				total += a
				if a != mask[y * w + (w - 1 - x)]:
					diff += 1
		gt(float(total), 20.0, "%s front silhouette" % kid)
		lt(float(diff), maxf(4.0, total * 0.04), "%s mirror difference %d of %d px" % [kid, diff, total])
		m.free()


static func _front_mask(root: Node3D, n: Node, xf: Transform3D, mask: PackedByteArray, w: int, h: int, texel: float) -> void:
	if n is Node3D and n != root:
		if not (n as Node3D).visible or n.name == &"glow" or n.name == &"beam" or n.name == &"lights":
			return
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var verts := (n as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if (n as MeshInstance3D).skin != null and root is MachineModel:
			verts = (root as MachineModel).posed_triangles(n as MeshInstance3D)
		for t in range(0, verts.size(), 3):
			var pts: Array[Vector2] = []
			for i in 3:
				var p := xf * verts[t + i]
				# Looking along -X from the front: z is screen x (mirror axis at the centre).
				pts.append(Vector2(p.z / texel + w * 0.5, h - 4.0 - p.y / texel))
			_fill(pts[0], pts[1], pts[2], mask, w, h)
	for c in n.get_children():
		_front_mask(root, c, xf, mask, w, h, texel)


static func _fill(a: Vector2, b: Vector2, c: Vector2, mask: PackedByteArray, w: int, h: int) -> void:
	var area := (b - a).cross(c - a)
	if absf(area) < 1e-6:
		return
	for y in range(maxi(0, floori(minf(a.y, minf(b.y, c.y)))), mini(h - 1, ceili(maxf(a.y, maxf(b.y, c.y)))) + 1):
		for x in range(maxi(0, floori(minf(a.x, minf(b.x, c.x)))), mini(w - 1, ceili(maxf(a.x, maxf(b.x, c.x)))) + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			var w0 := (b - a).cross(q - a) / area
			var w1 := (c - b).cross(q - b) / area
			var w2 := (a - c).cross(q - c) / area
			if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
				mask[y * w + x] = 1


func test_darkness_comes_from_the_scene_light() -> void:
	# No light: full day.
	MachineModel._sun = null
	MachineModel._dark_frame = -1
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.55
	tree.root.add_child(sun)
	MachineModel._sun = null
	MachineModel._dark_frame = -1
	near(MachineModel.darkness(), 0.45, 0.01, "a night sun")
	sun.light_energy = 1.0
	MachineModel._dark_frame = -1
	near(MachineModel.darkness(), 0.0, 0.01, "a noon sun")
	sun.free()
	MachineModel._sun = null
	MachineModel._dark_frame = -1
	near(MachineModel.darkness(), 0.0, 0.01, "no sun")


func test_the_part_burns_brighter_at_night() -> void:
	var sun := DirectionalLight3D.new()
	tree.root.add_child(sun)
	MachineModel._sun = null
	var m := FigureModel.create(&"warden") as MachineModel
	m.rotation.y = -PI * 0.25
	sun.light_energy = 1.0
	MachineModel._dark_frame = -1
	m.settle()
	var day := m.part_emission()
	sun.light_energy = 0.55
	MachineModel._dark_frame = -1
	m.settle()
	gt(m.part_emission(), day * 1.5, "night emission")
	m.free()
	sun.free()
	MachineModel._sun = null
	MachineModel._dark_frame = -1
