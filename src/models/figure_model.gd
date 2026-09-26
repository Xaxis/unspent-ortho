class_name FigureModel
extends Node3D
## Base for every animated non-human figure: machines and animals. Faces +X at
## rotation.y = 0 (set rotation.y = -facing).
##
## Contract used by fight/mobs (do not change signatures without updating both):
##   FigureModel.create(kind)   kind is a roster id tail, e.g. &"watcher", &"dog".
##                              Loads res://src/models/machines/<kind>.gd or
##                              res://src/models/animals/<kind>.gd (a script that
##                              extends FigureModel and overrides build()); falls
##                              back to a placeholder block so nothing crashes,
##                              also for helper scripts sharing those directories.
##   set_pose(pose)             &"stand" &"walk" &"alert" &"windup" &"strike"
##                              &"hurt" &"dead" (unknown poses are ignored)
##   animate(delta, speed)      speed in tiles/s actually moved
##   set_part_lit(lit)          the working part's light (off = hurt or dead)
##   flare_part()               brief flare when a blow reaches the working part
##   top_toward(up)             world point of the drawn body highest along `up`
##                              as posed now (a mark over the silhouette stands
##                              clear of it); machines read their bones
##   set_hunting(on)            the mob is running something down (roused): a
##                              machine holds its lights locked while it walks;
##                              figures that do not care ignore it
##   part_side                  &"front" &"back" &"left" &"right" &"none"
##   height                     world units, for hit effects and labels

var kind: StringName = &""
var pose: StringName = &"stand"
var part_side: StringName = &"front"
var height := 1.2
var material: Material


static func create(kind_id: StringName, mat: Material = null) -> FigureModel:
	var m: FigureModel = null
	# Sentinels are machines drawn the same way in their own directory, so a
	# landscape's keeper is found by `model` like any other kind (VISION §3).
	for dir: String in ["res://src/models/machines/", "res://src/models/machines/sentinels/", "res://src/models/animals/"]:
		var path := dir + String(kind_id) + ".gd"
		if ResourceLoader.exists(path):
			m = _instance_of(load(path) as GDScript)
			break
	if m == null:
		m = FigureModel.new()
	m.kind = kind_id
	m.material = mat if mat != null else _default_material()
	m.build()
	return m


## A figure from a kind script, or null when the file is not one: helper scripts
## that share the directory (a mesh kit, a gallery) are never kinds.
static func _instance_of(script: GDScript) -> FigureModel:
	if script == null or not script.can_instantiate():
		return null
	var obj: Object = script.new()
	if obj is FigureModel:
		return obj as FigureModel
	if obj is Node:
		(obj as Node).free()
	return null


static func _default_material() -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/render/world.gdshader")
	# A body moves: nothing grows on it (matter_grown).
	mat.set_shader_parameter(&"grows", 0.0)
	return mat


## Override. Default: a violet block with an amber part on the front (+X).
func build() -> void:
	var k := MeshKit.new()
	k.block(0, 0, 0, 0.8, 1.0, 0.8, Palette.FOUND[2], Palette.FOUND[3])
	k.block(0.41, 0.5, 0, 0.04, 0.25, 0.3, Palette.LENS[2])
	add_mesh(k)


func set_pose(p: StringName) -> void:
	pose = p


func animate(_delta: float, _speed: float) -> void:
	pass


func set_part_lit(_lit: bool) -> void:
	pass


func flare_part() -> void:
	pass


func set_hunting(_on: bool) -> void:
	pass


func top_toward(up: Vector3) -> Vector3:
	var to_world := global_transform if is_inside_tree() else transform
	var best := to_world.origin + Vector3(0, height, 0)
	var best_d := best.dot(up)
	for n in find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.visible or (gi is MeshInstance3D and not ((gi as MeshInstance3D).mesh is ArrayMesh)):
			continue
		var box := gi.get_aabb()
		var xf := to_world * _relative(gi)
		for i in 8:
			var c := xf * box.get_endpoint(i)
			if c.dot(up) > best_d:
				best_d = c.dot(up)
				best = c
	return best


func _relative(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != self:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Where a hit effect on the working part should appear, in world space (the
## figure's middle when it has no part). Machines override with the part itself.
func part_position() -> Vector3:
	var base := global_position if is_inside_tree() else position
	return base + Vector3(0, height * 0.5, 0)


## Triangles this figure draws, MultiMesh instances included. Budget: a machine
## 2000, an animal 800 (art-audio-extract §8).
func triangle_count() -> int:
	return _tris_under(self)


## Draw calls this figure can cost in the colour pass at worst (every light on):
## one per surface of every mesh, one per MultiMesh. Budget: a machine 6.
func draw_calls() -> int:
	return _draws_under(self)


static func _draws_under(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		total += (n as MeshInstance3D).mesh.get_surface_count()
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		total += 1
	for c in n.get_children():
		total += _draws_under(c)
	return total


static func _tris_under(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		total += _mesh_tris((n as MeshInstance3D).mesh)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm.mesh != null:
			total += _mesh_tris(mm.mesh) * mm.instance_count
	for c in n.get_children():
		total += _tris_under(c)
	return total


static func _mesh_tris(m: Mesh) -> int:
	var total := 0
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
			total += (idx as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## Helper for subclasses: add a MeshKit as a child mesh on `parent` (default self).
func add_mesh(k: MeshKit, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	mi.material_override = material
	(parent if parent != null else self).add_child(mi)
	return mi
