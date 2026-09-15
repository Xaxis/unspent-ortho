class_name SkinRig
extends RefCounted
## A figure as ONE skinned mesh on a Skeleton3D: every part is a MeshKit drawn in
## its bone's local space and rigidly bound to that bone. One draw call (plus its
## shadow) per person or animal instead of one per limb, which is what lets a
## village of people fit the Compatibility renderer's draw budget.
##
##   var rig := SkinRig.new()
##   var hips := rig.bone(&"hips", -1, Vector3(0, 0.6, 0))
##   rig.kit(hips).block(0, 0, 0, 0.2, 0.3, 0.3, Palette.LINEN[2])
##   rig.attach(parent_node, material)      # Skeleton3D + MeshInstance3D(s)
##   rig.pose(hips, Vector3(0, 0.3, 0))     # euler radians, every frame
##
## Rest transforms are translations only, so a bone's pose rotation is the whole
## joint angle and animation code never has to know about bind matrices.
## Parts added with glow = true go on a second mesh with an emissive copy of the
## material (found weapons, live salvage tips).

var names: Array[StringName] = []
var parents: PackedInt32Array = []
var rest: Array[Vector3] = []
var skeleton: Skeleton3D
var body: MeshInstance3D
var glow: MeshInstance3D
## Triangle counts of the last build, for budgets: {layer: tris}.
var tris: Dictionary = {}

var _kits: Array = [] # per bone: Array of [MeshKit, glow: bool, layer: StringName]
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


## A fresh kit in bone-local space. `layer` only labels triangle counts.
func kit(b: int, layer: StringName = &"body", is_glow: bool = false) -> MeshKit:
	var k := MeshKit.new()
	_kits[b].append([k, is_glow, layer])
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
func attach(parent: Node3D, material: Material) -> void:
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
	rebuild(material)


func rebuild(material: Material) -> void:
	tris = {}
	var lit := _merge(false)
	var shine := _merge(true)
	if body == null:
		body = MeshInstance3D.new()
		body.name = "body"
		skeleton.add_child(body)
		body.skeleton = NodePath("..")
	body.mesh = lit
	body.material_override = material
	if shine.get_surface_count() > 0:
		if glow == null:
			glow = MeshInstance3D.new()
			glow.name = "glow"
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			skeleton.add_child(glow)
			glow.skeleton = NodePath("..")
		glow.mesh = shine
		glow.material_override = glow_material(material)
		glow.visible = true
	elif glow != null:
		glow.visible = false


## An emissive twin of the lit material, cached per source material.
static var _glow_cache: Dictionary = {}


static func glow_material(material: Material) -> Material:
	if not material is ShaderMaterial:
		return material
	var id := material.get_instance_id()
	if not _glow_cache.has(id) or not is_instance_valid(_glow_cache[id]):
		var m := (material as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter("emission_strength", 0.85)
		_glow_cache[id] = m
	return _glow_cache[id]


func triangle_count(layers: Array = []) -> int:
	var n := 0
	for l: StringName in tris:
		if layers.is_empty() or layers.has(l):
			n += tris[l]
	return n


func _merge(want_glow: bool) -> ArrayMesh:
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var c := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for b in _kits.size():
		var off := global_rest(b)
		for entry: Array in _kits[b]:
			if entry[1] != want_glow:
				continue
			var k: MeshKit = entry[0]
			var n := k.verts.size()
			var layer: StringName = entry[2]
			tris[layer] = int(tris.get(layer, 0)) + n / 3
			for j in n:
				v.append(k.verts[j] + off)
				bones.append_array([b, 0, 0, 0])
				weights.append_array([1.0, 0.0, 0.0, 0.0])
			nm.append_array(k.normals)
			c.append_array(k.colors)
	var mesh := ArrayMesh.new()
	if v.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nm
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Joint angle (euler radians, YXZ) and an offset from the rest position.
func pose(b: int, euler: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	skeleton.set_bone_pose_rotation(b, Quaternion.from_euler(euler))
	skeleton.set_bone_pose_position(b, rest[b] + offset)


## Model-space transform of a bone as currently posed (hand positions, effects).
func bone_global(b: int) -> Transform3D:
	return skeleton.get_bone_global_pose(b)
