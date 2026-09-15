class_name WorldView
extends Node3D
## Streams the world into the scene as chunks around a focus point. Each chunk
## is one terrain mesh, one sea mesh and one MultiMesh per prop kind. Chunks
## are built a few per frame while playing, or all at once with ensure_near()
## (startup, screenshots, tests).

signal chunk_built(cx: int, cy: int)

const CHUNK := TerrainMesher.CHUNK

## Chunks within this many chunks of the focus chunk are kept.
@export var radius := 2
@export var builds_per_frame := 2

var world: WorldData
var focus := Vector2.ZERO
var _mesher: TerrainMesher
var _chunks: Dictionary = {} # Vector2i -> Node3D
var _props_by_chunk: Dictionary = {} # Vector2i -> Array[WorldProp]
var _world_mat: ShaderMaterial
var _water_mat: ShaderMaterial


func setup(w: WorldData) -> void:
	world = w
	_mesher = TerrainMesher.new(w)
	_world_mat = ShaderMaterial.new()
	_world_mat.shader = preload("res://src/render/world.gdshader")
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = preload("res://src/render/water.gdshader")
	for p in w.props:
		var key := Vector2i(floori(p.pos.x) / CHUNK, floori(p.pos.y) / CHUNK)
		if not _props_by_chunk.has(key):
			_props_by_chunk[key] = []
		_props_by_chunk[key].append(p)
	_add_open_sea()


func world_material() -> ShaderMaterial:
	return _world_mat


## Build every chunk near the focus synchronously.
func ensure_near(p: Vector2) -> void:
	focus = p
	for key in _wanted():
		if not _chunks.has(key):
			_build(key)


func pending() -> int:
	var n := 0
	for key in _wanted():
		if not _chunks.has(key):
			n += 1
	return n


func _process(_delta: float) -> void:
	if world == null:
		return
	var wanted := _wanted()
	var built := 0
	for key in wanted:
		if built >= builds_per_frame:
			break
		if not _chunks.has(key):
			_build(key)
			built += 1
	# Free chunks well outside the radius.
	var fc := _focus_chunk()
	for key: Vector2i in _chunks.keys():
		if absi(key.x - fc.x) > radius + 1 or absi(key.y - fc.y) > radius + 1:
			_chunks[key].queue_free()
			_chunks.erase(key)


func _focus_chunk() -> Vector2i:
	return Vector2i(floori(focus.x) / CHUNK, floori(focus.y) / CHUNK)


func _wanted() -> Array[Vector2i]:
	var fc := _focus_chunk()
	var n := ceili(float(world.size) / CHUNK)
	var out: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var key := fc + Vector2i(dx, dy)
			if key.x >= 0 and key.y >= 0 and key.x < n and key.y < n:
				out.append(key)
	# Nearest first.
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - fc).length_squared() < (b - fc).length_squared())
	return out


func _build(key: Vector2i) -> void:
	var node := Node3D.new()
	node.name = "chunk_%d_%d" % [key.x, key.y]
	var meshes := _mesher.build_chunk(key.x, key.y)
	var terrain := MeshInstance3D.new()
	terrain.mesh = meshes[0]
	terrain.material_override = _world_mat
	node.add_child(terrain)
	if meshes[1] != null:
		var sea := MeshInstance3D.new()
		sea.mesh = meshes[1]
		sea.material_override = _water_mat
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(sea)
	_build_props(node, key)
	add_child(node)
	_chunks[key] = node
	chunk_built.emit(key.x, key.y)


func _build_props(node: Node3D, key: Vector2i) -> void:
	if not _props_by_chunk.has(key):
		return
	var by_kind: Dictionary = {}
	for p: WorldProp in _props_by_chunk[key]:
		if not by_kind.has(p.kind):
			by_kind[p.kind] = []
		by_kind[p.kind].append(p)
	for kind: int in by_kind:
		var list: Array = by_kind[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = PropModels.mesh(kind)
		mm.instance_count = list.size()
		for j in list.size():
			var p: WorldProp = list[j]
			var b := Basis(Vector3.UP, p.rot).scaled(Vector3.ONE * p.scale)
			mm.set_instance_transform(j, Transform3D(b, world.to_3d(p.pos)))
			var k := 0.92 + Rng.hash01(world.seed_value, p.id, 91) * 0.16
			mm.set_instance_color(j, Color(k, k, k))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _world_mat
		mmi.name = PropKind.NAMES[kind]
		node.add_child(mmi)


## A flat deep-sea sheet under and around the whole map, so the edge of the
## world is the sea and not the void.
func _add_open_sea() -> void:
	var s := float(world.size)
	var m := 200.0
	var k := MeshKit.new()
	var y := TerrainMesher.WATER_Y - 0.02
	var c := Palette.BRINE[1]
	k.quad(Vector3(-m, y, -m), Vector3(-m, y, s + m), Vector3(s + m, y, s + m), Vector3(s + m, y, -m), c)
	var sea := MeshInstance3D.new()
	sea.name = "open_sea"
	sea.mesh = k.build()
	sea.material_override = _water_mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
