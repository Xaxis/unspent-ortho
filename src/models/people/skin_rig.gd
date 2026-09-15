class_name SkinRig
extends RefCounted
## A figure as ONE skinned mesh on a Skeleton3D: every part is a MeshKit drawn in
## its bone's local space and rigidly bound to that bone. One mesh node per person
## or animal instead of one per limb, which is what lets a village of people fit
## the Compatibility renderer's draw budget.
##
##   var rig := SkinRig.new()
##   var hips := rig.bone(&"hips", -1, Vector3(0, 0.6, 0))
##   rig.kit(hips).prism(0, 0, 0, 0.1, 0.3, 0.08, 6, Palette.LINEN[2])
##   rig.attach(parent_node, material)      # Skeleton3D + MeshInstance3D
##   rig.pose(hips, Vector3(0, 0.3, 0))     # euler radians, every frame
##
## Rest transforms are translations only, so a bone's pose rotation is the whole
## joint angle and animation code never has to know about bind matrices.
##
## Parts go on one of three surfaces (docs/ART.md law 3):
##   MADE   the hand: the material given to attach() (world or person shader)
##   FOUND  the ruler: found.gdshader, clean, unhatched (plate salvage, glim bodies)
##   GLOW   a light built into the FOUND: a glim's light, a live aerial tip, a
##          slate's screen. Drawn in the FOUND mesh with vertex alpha LIT_ALPHA,
##          which found.gdshader lights as a steady strip: one draw call fewer
##          for every figure that carries a light.
## Every MeshKit ink channel (style, sway, wash2) is carried through.

enum { MADE, FOUND, GLOW }
## found.gdshader lights a vertex with alpha in 0.5..0.98 at (1 - alpha) * 5: 0.55.
const LIT_ALPHA := 0.89

var names: Array[StringName] = []
var parents: PackedInt32Array = []
var rest: Array[Vector3] = []
var skeleton: Skeleton3D
var body: MeshInstance3D
## One mesh node per surface kind, indexed by MADE / FOUND (null = never used).
## GLOW parts are inside the FOUND mesh, so meshes[GLOW] stays null.
var meshes: Array[MeshInstance3D] = [null, null, null]
## A shadows-only twin, for materials that draw in the transparent pass (people):
## those cast no shadow of their own.
var shadow: MeshInstance3D
## Triangle counts of the last build, for budgets: {layer: tris}.
var tris: Dictionary = {}

var _kits: Array = [] # per bone: Array of [MeshKit, surface: int, layer: StringName]
var _index: Dictionary = {} # StringName -> int


func bone(n: StringName, parent: int, local_pos: Vector3) -> int:
	var i := names.size()
	names.append(n)
	parents.append(parent)
	rest.append(local_pos)
	_kits.append([])
	_index[n] = i
	return i


func find(n: StringName) -> int:
	return _index.get(n, -1)


## A fresh kit in bone-local space. `layer` labels triangle counts.
func kit(b: int, layer: StringName = &"body", surface: int = MADE) -> MeshKit:
	var k := MeshKit.new()
	_kits[b].append([k, surface, layer])
	return k


## Forget all geometry but keep the bones (a new look or a new held item).
func clear_parts() -> void:
	for i in _kits.size():
		_kits[i] = []


func global_rest(b: int) -> Vector3:
	var p := Vector3.ZERO
	while b >= 0:
		p += rest[b]
		b = parents[b]
	return p


## Build (or rebuild) the skeleton and meshes under `parent`.
func attach(parent: Node3D, material: Material, shadow_twin: bool = false) -> void:
	if skeleton == null:
		skeleton = Skeleton3D.new()
		skeleton.name = "skeleton"
		for i in names.size():
			skeleton.add_bone(String(names[i]))
			if parents[i] >= 0:
				skeleton.set_bone_parent(i, parents[i])
			skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, rest[i]))
			skeleton.set_bone_pose_position(i, rest[i])
		parent.add_child(skeleton)
	rebuild(material, shadow_twin)


func rebuild(material: Material, shadow_twin: bool = false) -> void:
	tris = {}
	for s: int in [MADE, FOUND]:
		var mesh := ArrayMesh.new()
		var used := _merge(s, mesh)
		var mi: MeshInstance3D = meshes[s]
		if not used:
			if mi != null:
				mi.visible = false
			continue
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = ["body", "found"][s]
			skeleton.add_child(mi)
			mi.skeleton = NodePath("..")
			meshes[s] = mi
		mi.visible = true
		mi.mesh = mesh
		# material_override, not a surface material: the gallery fills in any
		# empty override with its own material.
		mi.material_override = material if s == MADE else found_material(false)
	body = meshes[MADE]
	var made: MeshInstance3D = meshes[MADE]
	if shadow_twin and made != null and made.visible:
		made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if shadow == null:
			shadow = MeshInstance3D.new()
			shadow.name = "shadow"
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			skeleton.add_child(shadow)
			shadow.skeleton = NodePath("..")
		shadow.mesh = made.mesh
		shadow.material_override = shadow_material()
	elif shadow != null:
		shadow.mesh = null


static var _found_cache: Array[ShaderMaterial] = []
static var _shadow_mat: ShaderMaterial


## The FOUND material, shared by every figure: clean, or lit from inside.
static func found_material(lit: bool) -> ShaderMaterial:
	if _found_cache.is_empty():
		for glow: bool in [false, true]:
			var m := ShaderMaterial.new()
			m.shader = preload("res://src/render/found.gdshader")
			m.set_shader_parameter("emission_strength", 0.55 if glow else 0.0)
			_found_cache.append(m)
	return _found_cache[1 if lit else 0]


## Opaque stand-in drawn only into the shadow map.
static func shadow_material() -> ShaderMaterial:
	if _shadow_mat == null:
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = preload("res://src/render/found.gdshader")
	return _shadow_mat


func triangle_count(layers: Array = []) -> int:
	var n := 0
	for l: StringName in tris:
		if layers.is_empty() or layers.has(l):
			n += tris[l]
	return n


func _merge(surface: int, mesh: ArrayMesh) -> bool:
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cu := PackedFloat32Array()
	var tan := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for b in _kits.size():
		var off := global_rest(b)
		for entry: Array in _kits[b]:
			var lit: bool = entry[1] == GLOW
			if entry[1] != surface and not (lit and surface == FOUND):
				continue
			var k: MeshKit = entry[0]
			var n := k.verts.size()
			if n == 0:
				continue
			var layer: StringName = entry[2]
			tris[layer] = int(tris.get(layer, 0)) + n / 3
			# Whole arrays at a time: a village builds a person on a frame, and a
			# per-vertex loop here was most of that frame.
			v.append_array(Transform3D(Basis.IDENTITY, off) * k.verts)
			bones.append_array(_repeat_ints(PackedInt32Array([b, 0, 0, 0]), n))
			weights.append_array(_repeat_floats(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]), n))
			nm.append_array(k.normals)
			if surface == MADE:
				# Only the hand's surface draws the rim that pushes along these.
				tan.append_array(_smooth_normals(k))
			if lit:
				for col in k.colors:
					c.append(Color(col.r, col.g, col.b, LIT_ALPHA))
			else:
				c.append_array(k.colors)
			uv.append_array(k.uvs)
			uv2.append_array(k.uv2s)
			cu.append_array(k.custom0)
	if v.is_empty():
		return false
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nm
	if surface == MADE:
		arrays[Mesh.ARRAY_TANGENT] = tan
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = cu
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return true


## Per vertex, the average normal of every face meeting at that corner within one
## part, as a tangent (x, y, z, w=1). A rim pass pushes along it: flat normals
## would split the rim open at every hard edge.
static func _smooth_normals(k: MeshKit) -> PackedFloat32Array:
	# One dictionary pass: each vertex takes a slot per distinct corner, normals
	# add up per slot, and the second pass reads slots with no lookups.
	var slot_of := {}
	var n := k.verts.size()
	var slots := PackedInt32Array()
	slots.resize(n)
	var acc := PackedVector3Array()
	for j in n:
		var key := Vector3i((k.verts[j] * 512.0).round())
		var i: int = slot_of.get(key, -1)
		if i < 0:
			i = acc.size()
			slot_of[key] = i
			acc.append(Vector3.ZERO)
		acc[i] += k.normals[j]
		slots[j] = i
	var out := PackedFloat32Array()
	out.resize(n * 4)
	for j in n:
		var v: Vector3 = acc[slots[j]]
		v = v.normalized() if v.length_squared() > 1e-10 else k.normals[j]
		out[j * 4] = v.x
		out[j * 4 + 1] = v.y
		out[j * 4 + 2] = v.z
		out[j * 4 + 3] = 1.0
	return out


## `pattern` repeated `n` times, by doubling.
static func _repeat_ints(pattern: PackedInt32Array, n: int) -> PackedInt32Array:
	var out := pattern.duplicate()
	var want := pattern.size() * n
	while out.size() < want:
		out.append_array(out)
	out.resize(want)
	return out


static func _repeat_floats(pattern: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var out := pattern.duplicate()
	var want := pattern.size() * n
	while out.size() < want:
		out.append_array(out)
	out.resize(want)
	return out


## Joint angle (euler radians, YXZ) and an offset from the rest position.
func pose(b: int, euler: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	skeleton.set_bone_pose_rotation(b, Quaternion.from_euler(euler))
	skeleton.set_bone_pose_position(b, rest[b] + offset)


## Model-space transform of a bone as currently posed (hand positions, effects).
func bone_global(b: int) -> Transform3D:
	return skeleton.get_bone_global_pose(b)
