class_name WorldView
extends Node3D
## Streams the world into the scene as chunks around a focus point. A chunk is
## at most five draws, however much is in it: terrain, water, decor, MADE props
## and FOUND props. Props and decor are baked into one mesh each per chunk
## (native array transforms), so draw calls do not grow with the trees.
## Chunks are built a few per frame while playing, or all at once with
## ensure_near() (startup, screenshots, tests).
##
## The view radius follows the camera: a chunk is wanted while it touches the
## square that holds the camera's ground footprint plus a margin for tall things.

signal chunk_built(cx: int, cy: int)

const CHUNK := TerrainMesher.CHUNK
## Rotation that turns a model's +X downwind (east-north-east).
const WIND_BEARING := 0.42

## Extra tiles around the camera footprint built before they are seen.
@export var margin := 6.0
## Chunks are dropped once they are this many tiles outside the wanted square.
@export var keep := 20.0
@export var builds_per_frame := 1

var world: WorldData
var focus := Vector2.ZERO
var mesher: TerrainMesher
var decor: Decor
var _chunks: Dictionary = {} # Vector2i -> Node3D
var _data: Dictionary = {} # Vector2i -> TerrainMesher.Chunk
var _props_by_chunk: Dictionary = {} # Vector2i -> Array[WorldProp]
var _world_mat: ShaderMaterial
var _water_mat: ShaderMaterial

## Build timing, for --stats.
var build_count := 0
var build_ms := 0.0
var build_ms_max := 0.0


func setup(w: WorldData) -> void:
	world = w
	mesher = TerrainMesher.new(w)
	decor = Decor.new(w)
	_world_mat = ShaderMaterial.new()
	_world_mat.shader = preload("res://src/render/world.gdshader")
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = preload("res://src/render/water.gdshader")
	for p in w.props:
		var key := _key_of(p.pos)
		if not _props_by_chunk.has(key):
			_props_by_chunk[key] = []
		_props_by_chunk[key].append(p)
	_add_open_sea()


func world_material() -> ShaderMaterial:
	return _world_mat


func water_material() -> ShaderMaterial:
	return _water_mat


func chunk_count() -> int:
	return _chunks.size()


## The built chunk data under a tile-space point, or null.
func chunk_at(p: Vector2) -> TerrainMesher.Chunk:
	return _data.get(_key_of(p))


## Height of the drawn land at a tile-space point.
func surface_height(p: Vector2) -> float:
	var ch := chunk_at(p)
	if ch != null:
		return ch.surface(p.x, p.y)
	return mesher.surface_height(p.x, p.y)


static func _key_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x) / CHUNK, floori(p.y) / CHUNK)


## Build every chunk near the focus synchronously.
func ensure_near(p: Vector2) -> void:
	focus = p
	for key in _wanted(0.0):
		if not _chunks.has(key):
			_build(key)


func pending() -> int:
	var n := 0
	for key in _wanted(0.0):
		if not _chunks.has(key):
			n += 1
	return n


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


## Half the side, in tiles, of the square around the focus that the camera sees.
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
	var dm := decor.build(ch)
	if dm != null:
		var mi := MeshInstance3D.new()
		mi.name = "decor"
		mi.mesh = dm
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


## Rebuild the props of the chunk holding `prop` (after it was taken, grew back,
## or was put in the world at runtime).
func refresh_props(prop: WorldProp) -> void:
	var key := _key_of(prop.pos)
	if not _props_by_chunk.has(key):
		_props_by_chunk[key] = []
	if not _props_by_chunk[key].has(prop):
		_props_by_chunk[key].append(prop)
	if not _chunks.has(key):
		return
	var node: Node3D = _chunks[key]
	for part: String in ["props", "props_found"]:
		var old := node.get_node_or_null(part)
		if old != null:
			node.remove_child(old)
			old.queue_free()
	_build_props(node, key)


## The country a prop is dressed for: its tile's, or across an ecotone the one
## drawn at its foot.
func prop_country(p: WorldProp, ch: TerrainMesher.Chunk) -> int:
	if ch != null:
		var c := ch.country_at(p.pos.x, p.pos.y)
		if c != Country.SEA:
			return c
	return maxi(Country.COAST, world.country_at(floori(p.pos.x), floori(p.pos.y)))


func _build_props(node: Node3D, key: Vector2i) -> void:
	if not _props_by_chunk.has(key):
		return
	var ch: TerrainMesher.Chunk = _data.get(key)
	var mv := PackedVector3Array()
	var mn := PackedVector3Array()
	var mc := PackedColorArray()
	var muv := PackedVector2Array()
	var muv2 := PackedVector2Array()
	var fv := PackedVector3Array()
	var fn := PackedVector3Array()
	var fc := PackedColorArray()
	for p: WorldProp in _props_by_chunk[key]:
		if world.depleted.has(p.id):
			continue
		var variant := PropModels.pick_variant(p.kind, Rng.hash_ints(world.seed_value, p.id, 90))
		var country := prop_country(p, ch)
		var tpl := PropModels.template(p.kind, variant, country)
		var h := ch.surface(p.pos.x, p.pos.y) if ch != null else mesher.surface_height(p.pos.x, p.pos.y)
		var angle := p.rot
		if PropModels.Trees.wind_bent(p.kind, country):
			# Bent by the one wind off the sea, not each its own way.
			angle = WIND_BEARING + (Rng.hash01(world.seed_value, p.id, 92) - 0.5) * 0.5
		var rot := Basis(Vector3.UP, angle)
		var xf := Transform3D(rot.scaled(Vector3.ONE * p.scale), Vector3(p.pos.x, h, p.pos.y))
		var nx := Transform3D(rot, Vector3.ZERO)
		if not tpl.made_v.is_empty():
			mv.append_array(xf * tpl.made_v)
			mn.append_array(nx * tpl.made_n)
			mc.append_array(tpl.made_c)
			muv.append_array(tpl.made_uv)
			muv2.append_array(tpl.made_uv2)
		if not tpl.found_v.is_empty():
			fv.append_array(xf * tpl.found_v)
			fn.append_array(nx * tpl.found_n)
			fc.append_array(tpl.found_c)
	if not mv.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = mv
		arrays[Mesh.ARRAY_NORMAL] = mn
		arrays[Mesh.ARRAY_COLOR] = mc
		arrays[Mesh.ARRAY_TEX_UV] = muv
		arrays[Mesh.ARRAY_TEX_UV2] = muv2
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.name = "props"
		mi.mesh = mesh
		mi.material_override = _world_mat
		node.add_child(mi)
	if not fv.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = fv
		arrays[Mesh.ARRAY_NORMAL] = fn
		arrays[Mesh.ARRAY_COLOR] = fc
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.name = "props_found"
		mi.mesh = mesh
		mi.material_override = PropModels.found_material()
		node.add_child(mi)


## A flat deep-sea sheet around the whole map, so the edge of the world is the
## sea and not the void. Four strips, so it never lies under the map's own water.
func _add_open_sea() -> void:
	var s := float(world.size)
	var m := 200.0
	var y := TerrainMesher.WATER_Y - 0.02
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var col := Color(0.0, 0.5, 0.5, 1.0)
	for r: Rect2 in [Rect2(-m, -m, s + 2.0 * m, m), Rect2(-m, s, s + 2.0 * m, m), Rect2(-m, 0, m, s), Rect2(s, 0, m, s)]:
		var a := Vector3(r.position.x, y, r.position.y)
		var b := Vector3(r.end.x, y, r.position.y)
		var d := Vector3(r.end.x, y, r.end.y)
		var e := Vector3(r.position.x, y, r.end.y)
		v.append_array([a, b, d, a, d, e])
		for i in 6:
			c.append(col)
	var nrm := PackedVector3Array()
	nrm.resize(v.size())
	nrm.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sea := MeshInstance3D.new()
	sea.name = "open_sea"
	sea.mesh = mesh
	sea.material_override = _water_mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
