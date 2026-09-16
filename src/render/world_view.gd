class_name WorldView
extends Node3D
## Streams the world into the scene as chunks around a focus point. A chunk is
## at most five draws, however much is in it: terrain, water, decor, MADE props
## and FOUND props. Props and decor are baked into one mesh each per chunk
## (native array transforms), so draw calls do not grow with the trees.
## While playing, chunks are built one at a time on a worker thread (land,
## water, decor and baked prop arrays) and only turned into meshes on the main
## thread, so streaming never stalls a frame; ensure_near() builds synchronously
## (startup, screenshots, tests). What a worker bakes is snapshotted on the main
## thread first (the chunk's standing props and cable spans), so survival's
## edits to the world never race it; a chunk edited while in flight is baked
## again when it lands.
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
## Build streamed chunks on a worker thread (off: build in _process).
@export var threaded := true

var world: WorldData
var focus := Vector2.ZERO
var mesher: TerrainMesher
var decor: Decor
# The worker's own mesher and decor: neither is safe to share between threads.
var _bg_mesher: TerrainMesher
var _bg_decor: Decor
var _task := -1
var _task_key := Vector2i.ZERO
var _task_chunk: TerrainMesher.Chunk
var _task_decor: Array = []
var _task_props: Array = []
var _task_usec := 0
## The in-flight chunk's props changed while its worker was baking them.
var _task_dirty := false
var _chunks: Dictionary = {} # Vector2i -> Node3D
var _data: Dictionary = {} # Vector2i -> TerrainMesher.Chunk
var _props_by_chunk: Dictionary = {} # Vector2i -> Array[WorldProp]
var _cables_by_chunk: Dictionary = {} # Vector2i -> Array[Vector2i] of prop id pairs
var _world_mat: ShaderMaterial
var _water_mat: ShaderMaterial
## Where the machines cut the ground (read-only once baked; both threads read it).
var works: WorksMap

## Build timing, for --stats: whole builds (arrays, meshes, props) and the
## part of each that ran on the main thread.
var build_count := 0
var build_ms := 0.0
var build_ms_max := 0.0
var main_ms := 0.0
var main_ms_max := 0.0


func setup(w: WorldData) -> void:
	world = w
	# The landscape types are read from chunk workers (ice on the lines): build
	# the registry here first.
	BiomeRegistry.all()
	mesher = TerrainMesher.new(w)
	decor = Decor.new(w)
	_bg_mesher = TerrainMesher.new(w)
	_bg_decor = Decor.new(w)
	_world_mat = ShaderMaterial.new()
	_world_mat.shader = preload("res://src/render/world.gdshader")
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = preload("res://src/render/water.gdshader")
	# The machines' works cut into the ground, for the shader and the decor.
	works = WorksMap.bake(w)
	works.bind(_world_mat)
	decor.works = works
	_bg_decor.works = works
	for p in w.props:
		var key := _key_of(p.pos)
		if not _props_by_chunk.has(key):
			_props_by_chunk[key] = []
		_props_by_chunk[key].append(p)
	# The machines' grid (WorldData.lines, when world generation strings one):
	# each span is drawn with the chunk of the mast it leaves from.
	var lines: Variant = w.get("lines")
	if lines is Array:
		for line: Variant in lines:
			if not (line is Dictionary and (line as Dictionary).has("props")):
				continue
			var ids: PackedInt32Array = PackedInt32Array((line as Dictionary)["props"])
			for j in ids.size() - 1:
				if ids[j] < 0 or ids[j + 1] < 0 or ids[j] >= w.props.size() or ids[j + 1] >= w.props.size():
					continue
				var key := _key_of(w.props[ids[j]].pos)
				if not _cables_by_chunk.has(key):
					_cables_by_chunk[key] = []
				_cables_by_chunk[key].append(Vector2i(ids[j], ids[j + 1]))
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


## Build the nearest missing chunk round `p` on this thread (the view need not be
## in the tree yet) and return how many near `p` are still missing, 0 when all are
## built. The loading page draws the first view this way, one chunk a frame.
func build_one_near(p: Vector2) -> int:
	focus = p
	var missing := 0
	for key in _wanted(0.0):
		if not _chunks.has(key):
			if missing == 0:
				_build(key)
			missing += 1
	return maxi(0, missing - 1)


func pending() -> int:
	var n := 0
	for key in _wanted(0.0):
		if not _chunks.has(key):
			n += 1
	return n


func _process(_delta: float) -> void:
	if world == null:
		return
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if not _chunks.has(_task_key):
			_add_chunk(_task_key, _task_chunk, _task_decor, _task_usec, [] if _task_dirty else _task_props)
		_task_chunk = null
		_task_decor = []
		_task_props = []
	var wanted := _wanted(0.0)
	for key in wanted:
		if _chunks.has(key) or (_task >= 0 and key == _task_key):
			continue
		if threaded:
			if _task < 0:
				_task_key = key
				_task_dirty = false
				var snap := _snapshot(key)
				_task = WorkerThreadPool.add_task(_build_worker.bind(key, snap[0], snap[1]), false, "chunk")
		else:
			_build(key)
		break
	var keep_set := {}
	for key in _wanted(keep):
		keep_set[key] = true
	for key: Vector2i in _chunks.keys():
		if not keep_set.has(key):
			_chunks[key].queue_free()
			_chunks.erase(key)
			_data.erase(key)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _build_worker(key: Vector2i, props: Array, spans: Array) -> void:
	var t0 := Time.get_ticks_usec()
	_task_chunk = _bg_mesher.build_arrays(key.x, key.y)
	_task_decor = _bg_decor.build_arrays(_task_chunk)
	_task_props = bake_props(_task_chunk, _bg_mesher, props, spans)
	_task_usec = Time.get_ticks_usec() - t0


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
	var ch := mesher.build_arrays(key.x, key.y)
	var dec := decor.build_arrays(ch)
	var snap := _snapshot(key)
	var baked := bake_props(ch, mesher, snap[0], snap[1])
	_add_chunk(key, ch, dec, Time.get_ticks_usec() - t0, baked)


## Put a chunk built as arrays into the scene: meshes, decor, props.
## `worker_usec`: what building its arrays cost. `baked`: bake_props() output,
## or [] to bake them here (a chunk edited while its worker ran).
func _add_chunk(key: Vector2i, ch: TerrainMesher.Chunk, decor_arrays: Array, worker_usec: int, baked: Array) -> void:
	var t0 := Time.get_ticks_usec()
	var node := Node3D.new()
	node.name = "chunk_%d_%d" % [key.x, key.y]
	ch.commit()
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
	var dm := Decor.make_mesh(decor_arrays)
	if dm != null:
		var mi := MeshInstance3D.new()
		mi.name = "decor"
		mi.mesh = dm
		mi.material_override = _world_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	if baked.is_empty():
		var snap := _snapshot(key)
		baked = bake_props(ch, mesher, snap[0], snap[1])
	_attach_props(node, baked)
	add_child(node)
	_chunks[key] = node
	var main := (Time.get_ticks_usec() - t0) / 1000.0
	var ms := worker_usec / 1000.0 + main
	build_count += 1
	build_ms += ms
	build_ms_max = maxf(build_ms_max, ms)
	main_ms += main
	main_ms_max = maxf(main_ms_max, main)
	chunk_built.emit(key.x, key.y)


## Cumulative mesher stage times (usec) of both meshers, for --stats.
func stage_usec() -> PackedInt64Array:
	var out := mesher.prof.duplicate()
	for i in out.size():
		out[i] += _bg_mesher.prof[i]
	return out


## Rebuild the props of the chunk holding `prop` (after it was taken, grew back,
## or was put in the world at runtime, like a built fire).
func refresh_props(prop: WorldProp) -> void:
	var key := _key_of(prop.pos)
	if not _props_by_chunk.has(key):
		_props_by_chunk[key] = []
	if not _props_by_chunk[key].has(prop):
		_props_by_chunk[key].append(prop)
	if _task >= 0 and key == _task_key:
		_task_dirty = true
	if not _chunks.has(key):
		return
	var node: Node3D = _chunks[key]
	for part: String in ["props", "props_found"]:
		var old := node.get_node_or_null(part)
		if old != null:
			node.remove_child(old)
			old.queue_free()
	var snap := _snapshot(key)
	_attach_props(node, bake_props(_data.get(key), mesher, snap[0], snap[1]))


## The country a prop is dressed for: its tile's, or across an ecotone the one
## drawn at its foot.
func prop_country(p: WorldProp, ch: TerrainMesher.Chunk) -> int:
	if ch != null:
		var c := ch.country_at(p.pos.x, p.pos.y)
		if c != Country.SEA:
			return c
	return maxi(Country.COAST, world.country_at(floori(p.pos.x), floori(p.pos.y)))


## What a chunk's props bake from, taken on the main thread: [standing props,
## cable spans as [from prop, to prop]] (taken props left out).
func _snapshot(key: Vector2i) -> Array:
	var props: Array = []
	for p: WorldProp in _props_by_chunk.get(key, []):
		if not world.depleted.has(p.id):
			props.append(p)
	var spans: Array = []
	for pair: Vector2i in _cables_by_chunk.get(key, []):
		var a := world.props[pair.x]
		var b := world.props[pair.y]
		if not world.depleted.has(a.id) and not world.depleted.has(b.id):
			spans.append([a, b])
	return [props, spans]


## A chunk's props baked into two surfaces' arrays: [MADE arrays or [], FOUND
## arrays or []]. Pure given its inputs, so safe on a worker thread with that
## worker's own mesher (`m` answers heights outside the chunk).
func bake_props(ch: TerrainMesher.Chunk, m: TerrainMesher, props: Array, spans: Array) -> Array:
	var mv := PackedVector3Array()
	var mn := PackedVector3Array()
	var mc := PackedColorArray()
	var muv := PackedVector2Array()
	var muv2 := PackedVector2Array()
	var fv := PackedVector3Array()
	var fn := PackedVector3Array()
	var fc := PackedColorArray()
	for p: WorldProp in props:
		var variant := PropModels.variant_of(p, world.seed_value)
		var country := prop_country(p, ch)
		var tpl := PropModels.template(p.kind, variant, country)
		var h := _height(ch, m, p.pos)
		var facing := p.rot
		if PropModels.Trees.wind_bent(p.kind, country):
			# Bent by the one wind off the sea, not each its own way.
			facing = WIND_BEARING + (Rng.hash01(world.seed_value, p.id, 92) - 0.5) * 0.5
		# A model faces +X at rotation 0; turning to `facing` is rotation -facing.
		var rot := Basis(Vector3.UP, -facing)
		# A field of one model read as a tiled asset field: a dozen identical
		# drill tripods, thirty identical stumps, an arc of identical debris
		# (playtest, wave N). So every instance is cast a little differently as
		# well as turned, in the MODEL's own frame, so a fence still runs along
		# its line and a sign still faces its way. Masts keep the uniform scale:
		# their cables hang from points computed at it.
		var grow := Vector3.ONE
		if cable_points(p.kind).is_empty():
			grow = Vector3(1.0 + (Rng.hash01(world.seed_value, p.id, 93) - 0.5) * 0.22,
				1.0 + (Rng.hash01(world.seed_value, p.id, 94) - 0.5) * 0.30,
				1.0 + (Rng.hash01(world.seed_value, p.id, 95) - 0.5) * 0.22)
		# Scale first, then turn, so the cast is in the model's own frame.
		var xf := Transform3D(rot * Basis.from_scale(grow * p.scale), Vector3(p.pos.x, h, p.pos.y))
		# Normals take the turn only: a face keeps the light band the model was
		# drawn with, however the instance was cast.
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
	if not spans.is_empty():
		var ck := MeshKit.new()
		var ice := MeshKit.new()
		for span: Array in spans:
			_string_cables(ck, span[0], span[1], ch, m, ice)
		fv.append_array(ck.verts)
		fn.append_array(ck.normals)
		fc.append_array(ck.colors)
		# Ice hung on the lines is the weather's, drawn by hand (MADE).
		mv.append_array(ice.verts)
		mn.append_array(ice.normals)
		mc.append_array(ice.colors)
		muv.append_array(ice.uvs)
		muv2.append_array(ice.uv2s)
	var made := []
	if not mv.is_empty():
		made.resize(Mesh.ARRAY_MAX)
		made[Mesh.ARRAY_VERTEX] = mv
		made[Mesh.ARRAY_NORMAL] = mn
		made[Mesh.ARRAY_COLOR] = mc
		made[Mesh.ARRAY_TEX_UV] = muv
		made[Mesh.ARRAY_TEX_UV2] = muv2
	var found := []
	if not fv.is_empty():
		found.resize(Mesh.ARRAY_MAX)
		found[Mesh.ARRAY_VERTEX] = fv
		found[Mesh.ARRAY_NORMAL] = fn
		found[Mesh.ARRAY_COLOR] = fc
	return [made, found]


## Height of the drawn land under p: the chunk's own surface inside it, the
## mesher's field outside.
static func _height(ch: TerrainMesher.Chunk, m: TerrainMesher, p: Vector2) -> float:
	if ch != null and p.x >= ch.x0 and p.y >= ch.y0 and p.x < ch.x0 + ch.w and p.y < ch.y0 + ch.h:
		return ch.surface(p.x, p.y)
	return m.surface_height(p.x, p.y)


## Turn baked prop arrays into the chunk's two prop meshes (main thread).
func _attach_props(node: Node3D, baked: Array) -> void:
	if baked.size() < 2:
		return
	var made: Array = baked[0]
	if not made.is_empty():
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, made)
		var mi := MeshInstance3D.new()
		mi.name = "props"
		mi.mesh = mesh
		mi.material_override = _world_mat
		node.add_child(mi)
	var found: Array = baked[1]
	if not found.is_empty():
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, found)
		var mi := MeshInstance3D.new()
		mi.name = "props_found"
		mi.mesh = mesh
		mi.material_override = PropModels.found_material()
		node.add_child(mi)


## Insulator points a mast carries cables from, in model space.
static func cable_points(kind: int) -> PackedVector3Array:
	match kind:
		PropKind.PYLON:
			return PackedVector3Array([Vector3(0, 3.1, 1.1), Vector3(0, 3.1, -1.1), Vector3(0, 2.4, 0.8), Vector3(0, 2.4, -0.8)])
		PropKind.POLE:
			return PackedVector3Array([Vector3(0, 2.7, 0.42), Vector3(0, 2.7, -0.42)])
		PropKind.RELAY:
			# Under the insulators on the crossarm (props/works.gd relay).
			return PackedVector3Array([Vector3(0, 3.12, 0.55), Vector3(0, 3.12, -0.55)])
	return PackedVector3Array()


## Sagging cables from mast a to mast b, each insulator to its nearer partner,
## so a span never crosses itself however the masts are turned. Where the
## landscape under the span's middle is cold (BiomeRegistry hazards), ice hangs
## from the cables into `ice` (MADE): beads along the sag and icicles under it.
func _string_cables(k: MeshKit, a: WorldProp, b: WorldProp, ch: TerrainMesher.Chunk, m: TerrainMesher, ice: MeshKit = null) -> void:
	var pa := cable_points(a.kind)
	var pb := cable_points(b.kind)
	if pa.is_empty() or pb.is_empty():
		return
	var wa := _mast_points(a, pa, ch, m)
	var wb := _mast_points(b, pb, ch, m)
	var span := Vector2(b.pos - a.pos).length()
	for i in mini(wa.size(), wb.size()):
		# Pair by rank across the span's own sideways axis.
		var side := Vector3(-(b.pos.y - a.pos.y), 0.0, b.pos.x - a.pos.x).normalized()
		var from := _ranked(wa, side, i)
		var to := _ranked(wb, side, i)
		var prev := from
		var n := 10
		var icy := ice != null and float(BiomeRegistry.at(world, (a.pos + b.pos) * 0.5).hazards.get(&"cold", 0.0)) >= ICE_COLD
		var h0 := Rng.hash_ints(world.seed_value, a.id, b.id, i)
		for s in range(1, n + 1):
			var t := float(s) / n
			var p := from.lerp(to, t) + Vector3.DOWN * span * 0.035 * 4.0 * t * (1.0 - t)
			# A cable is dark, not black: it sits on the ink floor, so a span over a
			# pale pavement or a bright sky reads as a drawn line and never as a hole
			# in the page (docs/ART.md section 6).
			k.strut(prev, p, 0.014, 3, Palette.INK[2])
			if icy:
				_ice_on(ice, prev, p, h0 + s)
			prev = p


## Cold at or above which lines carry ice.
const ICE_COLD := 0.5


## Ice along one piece of cable: a sleeve of rime on it and icicles of uneven
## length hanging under it, never in a row; blue-grey, so they read against snow.
static func _ice_on(ice: MeshKit, a: Vector3, b: Vector3, h: int) -> void:
	ice.strut(a + Vector3(0, -0.015, 0), b + Vector3(0, -0.015, 0), 0.04, 3, Palette.RIME[3])
	var count := 2 + absi(h) % 3
	for j in count:
		var t := (float(j) + 0.2 + Rng.hash01(h, j, 3) * 0.6) / count
		var top := a.lerp(b, t) + Vector3(0, -0.03, 0)
		var length := 0.14 + Rng.hash01(h, j, 5) * 0.34
		ice.prism(top.x, top.y - length, top.z, 0.0, top.y, 0.045, 4, Palette.RIME[3] if j % 2 == 0 else Palette.RIME[2])


## Where a mast's cables hang from, in the world. No per-instance cast here on
## purpose: a mast is the one kind `_chunk_props` leaves at uniform scale,
## precisely so these points land on the metal that was baked, and a uniform
## scale commutes with the turn, so this transform is that one exactly.
func _mast_points(p: WorldProp, local: PackedVector3Array, ch: TerrainMesher.Chunk, m: TerrainMesher) -> PackedVector3Array:
	var h := _height(ch, m, p.pos)
	var xf := Transform3D(Basis(Vector3.UP, -p.rot).scaled(Vector3.ONE * p.scale), Vector3(p.pos.x, h, p.pos.y))
	return xf * local


static func _ranked(points: PackedVector3Array, axis: Vector3, rank: int) -> Vector3:
	var order := Array(points)
	order.sort_custom(func(u: Vector3, v: Vector3) -> bool: return u.y > v.y + 0.1 or (absf(u.y - v.y) <= 0.1 and u.dot(axis) < v.dot(axis)))
	return order[rank]


## A flat deep-sea sheet around the whole map, so the edge of the world is the
## sea and not the void. Four strips, so it never lies under the map's own water.
func _add_open_sea() -> void:
	var s := float(world.size)
	var m := 200.0
	var y := TerrainMesher.WATER_Y - 0.02
	var v := PackedVector3Array()
	var c := PackedColorArray()
	# Deep, open, and far from any bank: full surf weight (water.gdshader reads
	# COLOR.g on the sea), though at this depth nothing breaks anyway.
	var col := Color(0.0, 1.0, 0.5, 1.0)
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
