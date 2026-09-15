class_name WorldView
extends Node3D
## Streams the world into the scene as chunks around a focus point. Each chunk
## is at most four draws: terrain, water, props and decor. Props and decor are
## baked into one mesh each per chunk (native array transforms, no per-vertex
## script work), so draw calls do not grow with the number of trees.
## Chunks are built a few per frame while playing, or all at once with
## ensure_near() (startup, screenshots, tests).
##
## The view radius follows the camera: chunks are wanted while they touch the
## square that holds the camera's ground footprint plus a margin for tall things.

signal chunk_built(cx: int, cy: int)

const CHUNK := TerrainMesher.CHUNK

## Extra tiles around the camera footprint that are built before they are seen.
@export var margin := 7.0
## Chunks are dropped once they are this many tiles outside the wanted square.
@export var keep := 16.0
@export var builds_per_frame := 1

var world: WorldData
var focus := Vector2.ZERO
var mesher: TerrainMesher
var _chunks: Dictionary = {} # Vector2i -> Node3D
var _data: Dictionary = {} # Vector2i -> TerrainMesher.Chunk
var _props_by_chunk: Dictionary = {} # Vector2i -> Array[WorldProp]
var _world_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _tile_tex: ImageTexture
var _field_tex: ImageTexture
var _decor: Decor

## Build timing, for --stats.
var build_count := 0
var build_ms := 0.0
var build_ms_max := 0.0


func setup(w: WorldData) -> void:
	world = w
	mesher = TerrainMesher.new(w)
	_decor = Decor.new(w, mesher)
	_tile_tex = ImageTexture.create_from_image(mesher.tile_image)
	_field_tex = ImageTexture.create_from_image(mesher.field_image)
	var pal := ImageTexture.create_from_image(TerrainMesher.palette_image())
	_world_mat = ShaderMaterial.new()
	_world_mat.shader = preload("res://src/render/world.gdshader")
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = preload("res://src/render/water.gdshader")
	for m: ShaderMaterial in [_world_mat, _water_mat]:
		m.set_shader_parameter("has_terrain", true)
		m.set_shader_parameter("tile_tex", _tile_tex)
		m.set_shader_parameter("field_tex", _field_tex)
		m.set_shader_parameter("field_lin", _field_tex)
		m.set_shader_parameter("palette_tex", pal)
		m.set_shader_parameter("world_size", Vector2(w.size, w.size))
	for p in w.props:
		var key := Vector2i(floori(p.pos.x) / CHUNK, floori(p.pos.y) / CHUNK)
		if not _props_by_chunk.has(key):
			_props_by_chunk[key] = []
		_props_by_chunk[key].append(p)
	_add_open_sea()


func world_material() -> ShaderMaterial:
	return _world_mat


func water_material() -> ShaderMaterial:
	return _water_mat


## Build every chunk near the focus synchronously.
func ensure_near(p: Vector2) -> void:
	focus = p
	for key in _wanted(0.0):
		if not _chunks.has(key):
			_build(key)
	_upload()


func pending() -> int:
	var n := 0
	for key in _wanted(0.0):
		if not _chunks.has(key):
			n += 1
	return n


func chunk_count() -> int:
	return _chunks.size()


func _process(_delta: float) -> void:
	if world == null:
		return
	var built := 0
	for key in _wanted(0.0):
		if built >= builds_per_frame:
			break
		if not _chunks.has(key):
			_build(key)
			built += 1
	var keep_set := {}
	for key in _wanted(keep):
		keep_set[key] = true
	for key: Vector2i in _chunks.keys():
		if not keep_set.has(key):
			_chunks[key].queue_free()
			_chunks.erase(key)
			_data.erase(key)
	_upload()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_world_mat.set_shader_parameter("texel", cam.size / maxf(1.0, get_viewport().get_visible_rect().size.y))
	_world_mat.set_shader_parameter("tile_origin", Vector2(global_position.x, global_position.z))


func _upload() -> void:
	if mesher.dirty:
		_tile_tex.update(mesher.tile_image)
		_field_tex.update(mesher.field_image)
		mesher.dirty = false


## Half the side, in tiles, of the square around the focus that the camera can see.
func view_half_extent() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var vh := 15.0
	var aspect := 16.0 / 9.0
	var pitch := deg_to_rad(57.0)
	if cam != null and cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		vh = cam.size
		var r := get_viewport().get_visible_rect().size
		aspect = r.x / maxf(1.0, r.y)
		pitch = absf(cam.global_rotation.x)
	return half_extent_for(vh, aspect, pitch)


## The ground footprint of an orthographic view (height vh, yaw 45) as a square
## half-side in tile axes, plus room for land up to 6 units high to show from behind.
static func half_extent_for(vh: float, aspect: float, pitch: float) -> float:
	var hw := vh * aspect * 0.5
	var hh := vh * 0.5 / maxf(0.2, sin(pitch))
	var rise := 6.0 / maxf(0.2, tan(pitch))
	return (hw + hh) / sqrt(2.0) + rise


func _wanted(extra: float) -> Array[Vector2i]:
	var r := view_half_extent() + margin + extra
	var n := ceili(float(world.size) / CHUNK)
	var x0 := clampi(floori((focus.x - r) / CHUNK), 0, n - 1)
	var x1 := clampi(floori((focus.x + r) / CHUNK), 0, n - 1)
	var y0 := clampi(floori((focus.y - r) / CHUNK), 0, n - 1)
	var y1 := clampi(floori((focus.y + r) / CHUNK), 0, n - 1)
	var out: Array[Vector2i] = []
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			out.append(Vector2i(cx, cy))
	var fc := Vector2(focus.x / CHUNK - 0.5, focus.y / CHUNK - 0.5)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) - fc).length_squared() < (Vector2(b) - fc).length_squared())
	return out


func _build(key: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var node := Node3D.new()
	node.name = "chunk_%d_%d" % [key.x, key.y]
	var ch := mesher.build(key.x, key.y)
	_data[key] = ch
	var terrain := MeshInstance3D.new()
	terrain.name = "terrain"
	terrain.mesh = ch.terrain
	terrain.material_override = _world_mat
	node.add_child(terrain)
	if ch.water != null:
		var sea := MeshInstance3D.new()
		sea.name = "water"
		sea.mesh = ch.water
		sea.material_override = _water_mat
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(sea)
	var decor := _decor.build(ch)
	if decor != null:
		var mi := MeshInstance3D.new()
		mi.name = "decor"
		mi.mesh = decor
		mi.material_override = _world_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	_build_props(node, key)
	add_child(node)
	_chunks[key] = node
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	build_count += 1
	build_ms += ms
	build_ms_max = maxf(build_ms_max, ms)
	chunk_built.emit(key.x, key.y)


## Rebuild the props of the chunk holding `prop` (after it was taken or grew back).
func refresh_props(prop: WorldProp) -> void:
	var key := Vector2i(floori(prop.pos.x) / CHUNK, floori(prop.pos.y) / CHUNK)
	if not _chunks.has(key):
		return
	var node: Node3D = _chunks[key]
	var old := node.get_node_or_null("props")
	if old != null:
		node.remove_child(old)
		old.queue_free()
	_build_props(node, key)


func _build_props(node: Node3D, key: Vector2i) -> void:
	if not _props_by_chunk.has(key):
		return
	var ch: TerrainMesher.Chunk = _data.get(key)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	for p: WorldProp in _props_by_chunk[key]:
		if world.depleted.has(p.id):
			continue
		var tx := floori(p.pos.x)
		var ty := floori(p.pos.y)
		var country := world.country_at(tx, ty)
		if ch != null:
			var ti := (ty - ch.y0) * ch.w + (tx - ch.x0)
			if ti >= 0 and ti < ch.country.size():
				country = ch.country[ti]
				if mesher.h01(p.id, 3, 97) < ch.blend[ti]:
					country = ch.country2[ti]
		var variant := PropModels.pick_variant(p.kind, Rng.hash_ints(world.seed_value, p.id, 90))
		var tpl := PropModels.template(p.kind, variant, country)
		var tone := int(mesher.h01(p.id, 1, 91) * 3.0)
		var h := _ground_under(ch, p.pos)
		var basis := Basis(Vector3.UP, p.rot)
		var xf := Transform3D(basis.scaled(Vector3.ONE * p.scale), Vector3(p.pos.x, h, p.pos.y))
		v.append_array(xf * tpl.v)
		n.append_array(Transform3D(basis, Vector3.ZERO) * tpl.n)
		c.append_array(tpl.tones[tone])
		uv.append_array(tpl.uv)
	if v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "props"
	mi.mesh = mesh
	mi.material_override = _world_mat
	node.add_child(mi)


## Height of the drawn ground under a point: the tile's corners, bilinear, sunk
## a hair so nothing floats on an undulating top.
func _ground_under(ch: TerrainMesher.Chunk, p: Vector2) -> float:
	var tx := floori(p.x)
	var ty := floori(p.y)
	if ch == null:
		return world.height_at(p)
	var ti := (ty - ch.y0) * ch.w + (tx - ch.x0)
	if tx < ch.x0 or ty < ch.y0 or tx >= ch.x0 + ch.w or ty >= ch.y0 + ch.h:
		return world.height_at(p)
	var fx := p.x - tx
	var fy := p.y - ty
	var a := lerpf(ch.corners[ti * 4], ch.corners[ti * 4 + 1], fx)
	var b := lerpf(ch.corners[ti * 4 + 3], ch.corners[ti * 4 + 2], fx)
	return minf(lerpf(a, b, fy), maxf(a, b)) - 0.02


## A flat deep-sea sheet under and around the whole map, so the edge of the
## world is the sea and not the void.
func _add_open_sea() -> void:
	var s := float(world.size)
	var m := 200.0
	var k := TerrainMesher.Buf.new()
	var y := TerrainMesher.WATER_Y - 0.02
	var uv := Vector2(TerrainMesher.WATER_OPEN, 0)
	var col := Color(0.5, 0.5, 0.0, 1.0)
	# Four strips around the map, so the sheet never lies under the map's own water.
	k.quad(Vector3(-m, y, -m), Vector3(-m, y, 0), Vector3(s + m, y, 0), Vector3(s + m, y, -m), col, uv)
	k.quad(Vector3(-m, y, s), Vector3(-m, y, s + m), Vector3(s + m, y, s + m), Vector3(s + m, y, s), col, uv)
	k.quad(Vector3(-m, y, 0), Vector3(-m, y, s), Vector3(0, y, s), Vector3(0, y, 0), col, uv)
	k.quad(Vector3(s, y, 0), Vector3(s, y, s), Vector3(s + m, y, s), Vector3(s + m, y, 0), col, uv)
	var sea := MeshInstance3D.new()
	sea.name = "open_sea"
	sea.mesh = k.build()
	sea.material_override = _water_mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
