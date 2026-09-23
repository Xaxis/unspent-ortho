class_name WorldView
extends Node3D
## Streams the world into the scene as chunks around a focus point. A chunk is
## at most six draws, however much is in it: terrain, water, decor, MADE props,
## FOUND props and the leaf cards of every plant in it (props/kit.gd `canopy`). Props and decor are baked into one mesh each per chunk
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
## The coarse world, by PATH not by global class name: see its header for what a
## `class_name` here cost the owner.
const Far := preload("res://src/render/world_far.gd")
## Rotation that turns a model's +X downwind (east-north-east).
const WIND_BEARING := 0.42

## Extra tiles around the camera footprint built before they are seen.
@export var margin := 6.0
## Chunks are PARKED once they are this many tiles outside the wanted square.
@export var keep := 20.0
## How far the chunks ever reach, whatever the camera asks for. Past this the
## coarse `world_far.gd` carries the world, because a chunk is the wrong unit for
## looking at an island: see that file's header for the measurement.
@export var near_limit := 110.0
## How many chunks are kept built after they leave the view. **This is what
## stops a zoom out, in and out again rebuilding the world** -- a chunk that
## leaves the square is taken out of the scene, not thrown away, and coming back
## costs nothing. 192 covers the whole near square at `near_limit` three times
## over, so ordinary play never evicts anything.
@export var park_most := 192
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
## Chunks built, then taken out of the scene when the view left them. They cost
## no draw and no cull here, and putting one back is free.
var _parked: Dictionary = {} # Vector2i -> Node3D
var _park_seen: Dictionary = {} # Vector2i -> int, for evicting the least recently wanted
var _park_clock := 0
## The whole world, coarse, built once and never dropped.
var far: Far
var _far_tables: Array = []
## Far blocks are built on SEVERAL workers at once, unlike chunks. A chunk is
## built because the player is about to walk into it, so one at a time is right:
## it keeps the machine free. The coarse world is a hundred-odd blocks wanted all
## at once the first time the camera pulls back, and each is small, so what
## matters there is finishing.
const FAR_WORKERS := 4
var _far_tasks: Array[int] = []
var _far_keys: Array[Vector2i] = []
var _far_out: Array = []
var _far_at: Array[int] = []
## What each far slot is building: a block's LAND, or its STANDS (world_far's
## silhouettes), which are only built once the horizon has been seen.
const LAND := 0
const STANDS := 1
var _far_kind: Array[int] = []
var _stands_wanted := false
## Build the silhouettes as soon as the far land is in, without waiting for a
## camera to see the horizon: set by whoever knows the player CAN look out (the
## view over the shoulder, 41_shoulder), so the first look up is complete rather
## than bare far land filling in for seconds. Kept across a rebind, because a
## realm crossing does not take the key away.
var stands_early := false
## The far world's own copies of the two materials: the same shaders, told to
## stand down wherever a near chunk is in the scene (`near_mask`, one texel per
## chunk). Only these read the mask, so the near land draws exactly as it did.
var _far_land_mat: ShaderMaterial
var _far_water_mat: ShaderMaterial
var _near_mask: Image
var _near_tex: ImageTexture
var _mask_dirty := true
## What stands in each far block, snapshotted on the main thread at bind so a far
## worker never reads the live prop list (`world_far._stand_props`).
var _far_props: Dictionary = {} # Vector2i -> Array[WorldProp]
var _data: Dictionary = {} # Vector2i -> TerrainMesher.Chunk
var _props_by_chunk: Dictionary = {} # Vector2i -> Array[WorldProp]
var _cables_by_chunk: Dictionary = {} # Vector2i -> Array[Vector2i] of prop id pairs
var _world_mat: ShaderMaterial
var _water_mat: ShaderMaterial
## The leaves' own material (src/render/foliage/leaf.gdshader). One per view, not
## PropModels' shared one, for the reason the world material is one per view:
## 18_crowns writes the clearings into it every frame.
var _leaf_mat: ShaderMaterial
## Where the machines cut the ground (read-only once baked; both threads read it).
var works: WorksMap

## Build timing, for --stats: whole builds (arrays, meshes, props) and the
## part of each that ran on the main thread.
var build_count := 0
var build_ms := 0.0
var build_ms_max := 0.0
var main_ms := 0.0
var main_ms_max := 0.0
## What the coarse world cost, all in: a block's worker plus putting it in.
var far_ms := 0.0
var far_count := 0
## What COLLECTING a far block costs on the main thread, which nothing measured.
## The near path has had `main_ms` beside its `build_ms` all along; the far path
## timed only its worker, so the one half of it that can stall a frame was the one
## half nobody could see. `_far_step`'s own comment says collecting "is free and
## always worth doing" -- an assertion, never a measurement, sitting exactly where
## a spike would hide. And the loop collects EVERY ready slot in one frame, so four
## finishing together are four uploads in one frame.
var far_main_ms := 0.0
var far_main_ms_max := 0.0
## The two halves of a chunk's build that the MESHER's own profile cannot see,
## because they are this file's work and not its. Without them the stats line
## named 36 ms of a 46 ms build and looked perfectly healthy doing it — which is
## how six of seven stages got quoted as the whole cost. See `stats_line`.
var decor_ms := 0.0
var props_ms := 0.0
var _last_decor_usec := 0
var _last_props_usec := 0


func setup(w: WorldData) -> void:
	_world_mat = ShaderMaterial.new()
	_world_mat.shader = preload("res://src/render/world.gdshader")
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = preload("res://src/render/water.gdshader")
	_leaf_mat = ShaderMaterial.new()
	_leaf_mat.shader = preload("res://src/render/foliage/leaf.gdshader")
	_bind(w)


## Point this view at ANOTHER world: a realm crossing (docs/VISION.md,
## src/systems/20_realms.gd). Every chunk, every prop index and the works are
## dropped and grown again from `w`; the two MATERIALS are kept, because the
## player's figure, the crowns and the swing arc were handed them when the game
## started and they outlive the world they first drew.
func rebind(w: WorldData) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_task_chunk = null
		_task_decor = []
		_task_props = []
	for i in _far_tasks.size():
		if _far_tasks[i] >= 0:
			WorkerThreadPool.wait_for_task_completion(_far_tasks[i])
			_far_tasks[i] = -1
			_far_out[i] = []
	for key: Vector2i in _chunks.keys():
		(_chunks[key] as Node3D).queue_free()
	_chunks.clear()
	for key: Vector2i in _parked.keys():
		(_parked[key] as Node3D).queue_free()
	_parked.clear()
	_park_seen.clear()
	_data.clear()
	if far != null:
		remove_child(far)
		far.queue_free()
		far = null
	var sea := get_node_or_null("open_sea")
	if sea != null:
		remove_child(sea)
		sea.queue_free()
	build_count = 0
	build_ms = 0.0
	build_ms_max = 0.0
	main_ms = 0.0
	main_ms_max = 0.0
	_bind(w)


## Everything about this view that belongs to one world.
func _bind(w: WorldData) -> void:
	world = w
	# The landscape types are read from chunk workers (ice on the lines): build
	# the registry here first.
	BiomeRegistry.all()
	mesher = TerrainMesher.new(w)
	decor = Decor.new(w)
	_bg_mesher = TerrainMesher.new(w)
	_bg_decor = Decor.new(w)
	_props_by_chunk.clear()
	_cables_by_chunk.clear()
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
	# Read off the registry HERE, on the main thread, so a far block's worker
	# never touches it (the chunk workers learnt the same lesson above).
	_far_tables = Far.tables()
	_far_props.clear()
	for p in w.props:
		if w.depleted.has(p.id):
			continue
		var bk := Vector2i(floori(p.pos.x) / Far.BLOCK, floori(p.pos.y) / Far.BLOCK)
		if not _far_props.has(bk):
			_far_props[bk] = []
		_far_props[bk].append(p)
	_far_tasks.clear()
	_far_keys.clear()
	_far_out.clear()
	_far_at.clear()
	_far_kind.clear()
	_stands_wanted = false
	for i in FAR_WORKERS:
		_far_tasks.append(-1)
		_far_keys.append(Vector2i.ZERO)
		_far_out.append([])
		_far_at.append(0)
		_far_kind.append(LAND)
	far = Far.new()
	far.name = "far"
	add_child(far)
	var n := ceili(float(w.size) / CHUNK)
	# THE IMAGE HERE; THE TEXTURE AND THE FAR MATERIALS ON THE MAIN THREAD.
	# `setup` runs on a worker for the title (UiTitle._begin), and both creating a
	# texture and duplicating a material from a worker wait on the main thread --
	# which was waiting on that worker, so every test that built a title hung for
	# ever and the CI gate ran out its clock. `_far_mats` makes them the first time
	# the main thread needs them.
	_near_mask = Image.create(n, n, false, Image.FORMAT_R8)
	_near_tex = null
	_far_land_mat = null
	_far_water_mat = null
	_mask_dirty = true


## The far world's two materials and its mask texture, made on first use from the
## main thread (see `_bind`). Taken after the works are bound, so they carry them.
func _far_mats() -> void:
	if _near_mask == null:
		return
	if _near_tex == null:
		_near_tex = ImageTexture.create_from_image(_near_mask)
	if _far_land_mat == null:
		_far_land_mat = _far_copy(_world_mat)
		_far_water_mat = _far_copy(_water_mat)


## A far copy of one of the view's materials, told to stand down under the near
## chunks. Taken after the works are bound, so it carries them.
func _far_copy(m: ShaderMaterial) -> ShaderMaterial:
	var c := m.duplicate() as ShaderMaterial
	c.set_shader_parameter("near_mask", _near_tex)
	c.set_shader_parameter("near_cut", 1.0)
	c.set_shader_parameter("near_cell", float(CHUNK))
	return c


## Write which chunks are in the scene into the far world's mask. Once a frame at
## most, and only when a chunk came or went.
func _write_mask() -> void:
	if not _mask_dirty or _near_mask == null:
		return
	_mask_dirty = false
	_near_mask.fill(Color(0, 0, 0))
	var n := _near_mask.get_width()
	for key: Vector2i in _chunks.keys():
		if key.x >= 0 and key.y >= 0 and key.x < n and key.y < n:
			_near_mask.set_pixel(key.x, key.y, Color(1, 0, 0))
	_far_mats()
	_near_tex.update(_near_mask)


func world_material() -> ShaderMaterial:
	return _world_mat


func water_material() -> ShaderMaterial:
	return _water_mat


func leaf_material() -> ShaderMaterial:
	return _leaf_mat


func chunk_count() -> int:
	return _chunks.size()


func parked_count() -> int:
	return _parked.size()


## How many far blocks this world has in all.
func far_wanted() -> int:
	if world == null:
		return 0
	var n := Far.across(world.size)
	return n * n


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


## Whether this chunk is built, in the scene or parked out of it.
func _have(key: Vector2i) -> bool:
	return _chunks.has(key) or _parked.has(key)


## Put a parked chunk back in the scene. Free: it was never unbuilt.
func _revive(key: Vector2i) -> void:
	var node: Node3D = _parked[key]
	_parked.erase(key)
	_park_seen.erase(key)
	add_child(node)
	_chunks[key] = node
	_mask_dirty = true


## Take a chunk out of the scene but keep it built. The least recently wanted
## are let go once the park is full, and only THEY lose their height data.
func _park(key: Vector2i) -> void:
	var node: Node3D = _chunks[key]
	remove_child(node)
	_chunks.erase(key)
	_mask_dirty = true
	_parked[key] = node
	_park_clock += 1
	_park_seen[key] = _park_clock
	while _parked.size() > park_most:
		var oldest := Vector2i.ZERO
		var oldest_at := 0x7FFFFFFF
		for k: Vector2i in _parked.keys():
			var at: int = _park_seen.get(k, 0)
			if at < oldest_at:
				oldest_at = at
				oldest = k
		(_parked[oldest] as Node3D).queue_free()
		_parked.erase(oldest)
		_park_seen.erase(oldest)
		_data.erase(oldest)


## Build every chunk near the focus synchronously.
func ensure_near(p: Vector2) -> void:
	focus = p
	for key in _wanted(0.0):
		if _parked.has(key):
			_revive(key)
		elif not _chunks.has(key):
			_build(key)
	_write_mask()


## Build the nearest missing chunk round `p` on this thread (the view need not be
## in the tree yet) and return how many near `p` are still missing, 0 when all are
## built. The loading page draws the first view this way, one chunk a frame.
func build_one_near(p: Vector2) -> int:
	focus = p
	var missing := 0
	for key in _wanted(0.0):
		if _parked.has(key):
			_revive(key)
		elif not _chunks.has(key):
			if missing == 0:
				_build(key)
			missing += 1
	return maxi(0, missing - 1)


func pending() -> int:
	var n := 0
	for key in _wanted(0.0):
		if not _have(key):
			n += 1
	return n


func _process(_delta: float) -> void:
	if world == null:
		return
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if not _have(_task_key):
			_add_chunk(_task_key, _task_chunk, _task_decor, _task_usec, [] if _task_dirty else _task_props)
		_task_chunk = null
		_task_decor = []
		_task_props = []
	var wanted := _wanted(0.0)
	# Reviving is free, so every parked chunk the view has come back to goes in
	# at once; only building is one at a time.
	for key in wanted:
		if _parked.has(key):
			_revive(key)
	# Whether the near square still owes the player ground. `_far_step` reads it
	# and stands down: see the note there for what it cost not to.
	var near_busy := _task >= 0
	for key in wanted:
		if _chunks.has(key) or (_task >= 0 and key == _task_key):
			continue
		near_busy = true
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
			_park(key)
	_far_step(near_busy)
	_write_mask()


## Fill the coarse world in, a block at a time, on its own workers. It is built
## ONCE and kept: that is what makes zooming out, in and out again cost nothing
## at all.
##
## **IT STANDS DOWN WHILE THE NEAR SQUARE OWES THE PLAYER GROUND.** The header of
## this function used to say the opposite -- "on its own worker so it never
## queues behind a chunk" -- which is the same sentence read from the machine's
## side instead of the player's. A near chunk is what they are standing on; a far
## block is what they might look at later, it is built once and kept, and so it
## loses nothing at all by waiting. Without this it took FOUR workers from the
## first frame while the near square, which builds ONE chunk at a time, was still
## empty: measured at 1 fps with 4 chunks up and 4 of 121 far blocks done, and the
## opening of every game stuttered while the land popped in around the player.
## **A background job that outranks the foreground is not a background job.**
func _far_step(near_busy: bool) -> void:
	if far == null:
		return
	_far_mats()
	for i in _far_tasks.size():
		if _far_tasks[i] >= 0 and WorkerThreadPool.is_task_completed(_far_tasks[i]):
			WorkerThreadPool.wait_for_task_completion(_far_tasks[i])
			_far_tasks[i] = -1
			var t_main := Time.get_ticks_usec()
			if _far_kind[i] == STANDS:
				far.add_stands(_far_keys[i], _far_out[i], _far_land_mat)
			else:
				far.add_block(_far_keys[i], _far_out[i], _far_land_mat, _far_water_mat)
			var main_cost := (Time.get_ticks_usec() - t_main) / 1000.0
			far_main_ms += main_cost
			far_main_ms_max = maxf(far_main_ms_max, main_cost)
			_far_out[i] = []
			# The WORKER's own microseconds, which `_far_worker` writes back. It
			# was dispatch-to-collection: queue wait, plus however long until a
			# frame came round to collect it. So it reported 661 ms for a block
			# and got WORSE the busier the machine was -- which is backwards for
			# a cost, and is the same mistake as timing a chunk by when its
			# picture appeared. It sent me looking for a twelvefold regression
			# in the builder that was never there.
			far_ms += _far_at[i] / 1000.0
			far_count += 1
	if not _stands_wanted and (stands_early or is_inside_tree() and SkyLight.sees_horizon(get_viewport().get_camera_3d())):
		_stands_wanted = true
	var land_left := not far.done(world.size)
	if not land_left and (not _stands_wanted or far.stands_done(world.size)):
		return
	# Collecting a finished block above is CHEAP ON AVERAGE and always worth doing;
	# STARTING one is what yields. So this sits here rather than at the top, or a
	# block already paid for would hang in the pool unclaimed while the player walks.
	#
	# It said "free", and that was an assertion nobody had measured -- the near path
	# has carried `main_ms` beside its `build_ms` all along while the far path timed
	# only its worker, so the half of it that can stall a frame was the half nobody
	# could see. Measured over 597 frames: 0.5 ms average and **9.1 ms worst**, which
	# is most of a 120 Hz frame on its own. The loop above also takes EVERY ready
	# slot in one frame, so several finishing together are several uploads together.
	# Cheap on average is not free, and an average is the wrong statistic for a
	# stutter (docs/DESIGN.md).
	if near_busy:
		return
	# What is already in flight is not free to ask for again.
	var busy := {}
	for i in _far_tasks.size():
		if _far_tasks[i] >= 0:
			busy[_far_keys[i]] = true
	for i in _far_tasks.size():
		if _far_tasks[i] >= 0:
			continue
		var kind := LAND
		var key := far.next_block(world.size, focus, busy)
		if key.x < 0 and _stands_wanted:
			kind = STANDS
			key = far.next_stand(world.size, focus, busy)
		if key.x < 0:
			return
		busy[key] = true
		_far_keys[i] = key
		_far_kind[i] = kind
		_far_at[i] = 0
		_far_tasks[i] = WorkerThreadPool.add_task(_far_worker.bind(i, key), false, "far")


## Build every far block that is not built yet, on this thread: a still picture
## that looks out to the horizon (96_eye under a shot) has to hold the whole view
## on its first frame, and the workers take a few seconds to get there.
func ensure_far() -> void:
	if far == null:
		return
	_far_mats()
	for i in _far_tasks.size():
		if _far_tasks[i] >= 0:
			WorkerThreadPool.wait_for_task_completion(_far_tasks[i])
			if _far_kind[i] == STANDS:
				far.add_stands(_far_keys[i], _far_out[i], _far_land_mat)
			else:
				far.add_block(_far_keys[i], _far_out[i], _far_land_mat, _far_water_mat)
			_far_tasks[i] = -1
			_far_out[i] = []
	while not far.done(world.size):
		var key := far.next_block(world.size, focus, {})
		if key.x < 0:
			return
		var t0 := Time.get_ticks_usec()
		far.add_block(key, Far.build_arrays(world, key.x, key.y, _far_tables), _far_land_mat, _far_water_mat)
		far_ms += (Time.get_ticks_usec() - t0) / 1000.0
		far_count += 1
	_stands_wanted = true
	while not far.stands_done(world.size):
		var key := far.next_stand(world.size, focus, {})
		if key.x < 0:
			return
		far.add_stands(key, Far.stand_arrays(world, _far_props.get(key, [])), _far_land_mat)


func _far_worker(slot: int, key: Vector2i) -> void:
	var began := Time.get_ticks_usec()
	if _far_kind[slot] == STANDS:
		_far_out[slot] = Far.stand_arrays(world, _far_props.get(key, []))
	else:
		_far_out[slot] = Far.build_arrays(world, key.x, key.y, _far_tables)
	_far_at[slot] = Time.get_ticks_usec() - began


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for i in _far_tasks.size():
		if _far_tasks[i] >= 0:
			WorkerThreadPool.wait_for_task_completion(_far_tasks[i])
			_far_tasks[i] = -1


func _build_worker(key: Vector2i, props: Array, spans: Array) -> void:
	var t0 := Time.get_ticks_usec()
	_task_chunk = _bg_mesher.build_arrays(key.x, key.y)
	var t1 := Time.get_ticks_usec()
	_task_decor = _bg_decor.build_arrays(_task_chunk)
	var t2 := Time.get_ticks_usec()
	_task_props = bake_props(_task_chunk, _bg_mesher, props, spans)
	var t3 := Time.get_ticks_usec()
	_task_usec = t3 - t0
	_last_decor_usec = t2 - t1
	_last_props_usec = t3 - t2


## Half the side, in tiles, of the square around the focus that the camera sees.
##
## **A PROJECTION IT DOES NOT KNOW IS NOT A REASON TO ANSWER FOR THE OTHER ONE.**
## This used to fall through to a 15-unit view pitched 57 whenever the camera was
## not orthographic, which is a confident wrong answer rather than no answer: the
## lens (`CameraRig` persp) reaches 95.2 tiles ahead and 4.9 behind, measured in
## `tests/render/test_read_reach.gd`, so the square it was given was a sixth of
## the ground in the picture. `_wanted` caps whatever comes back at `near_limit`
## (110) and the coarse `world_far` stands past that, so telling the truth here
## costs nothing and lying costs the near half of the frame.
func view_half_extent() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		return _lens_half_extent(cam)
	var vh := 15.0
	var aspect := 16.0 / 9.0
	var pitch := deg_to_rad(57.0)
	if cam != null and cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		vh = cam.size
		var r := get_viewport().get_visible_rect().size
		aspect = r.x / maxf(1.0, r.y)
		pitch = absf(cam.global_rotation.x)
	return half_extent_for(vh, aspect, pitch)


## The same square for a LENS, asked of the camera instead of derived: its own
## four corner rays, dropped onto the ground the focus stands on.
##
## A frustum has no `size` to divide, and no single half-extent describes its
## shape -- the top edge runs a couple of degrees under the horizon while the
## bottom is a few tiles behind the player. So this asks for the four corners and
## takes the furthest, which is the only figure a SQUARE streamer can use.
##
## A corner that never meets the ground (level with the horizon or above it)
## answers `near_limit`, because that is where `_wanted` would clamp it anyway
## and a ray running to infinity must not become an infinite square.
func _lens_half_extent(cam: Camera3D) -> float:
	var rect := get_viewport().get_visible_rect().size
	var plane_y := world.height_at(focus) if world != null else 0.0
	var far_seen := 0.0
	for c: Vector2 in [Vector2.ZERO, Vector2(rect.x, 0.0), Vector2(0.0, rect.y), rect]:
		var from := cam.project_ray_origin(c)
		var dir := cam.project_ray_normal(c)
		var d := near_limit
		if dir.y < -0.0001:
			d = minf((from.y - plane_y) / -dir.y, near_limit)
		var hit := from + dir * d
		far_seen = maxf(far_seen, maxf(absf(hit.x - focus.x), absf(hit.z - focus.y)))
	return far_seen


## The ground footprint of an orthographic view (height vh, yaw 45) as a square
## half-side in tile axes, plus room for land up to 6 units high to show from behind.
static func half_extent_for(vh: float, aspect: float, pitch: float) -> float:
	var hw := vh * aspect * 0.5
	var hh := vh * 0.5 / maxf(0.2, sin(pitch))
	var rise := 6.0 / maxf(0.2, tan(pitch))
	return (hw + hh) / sqrt(2.0) + rise


## The chunks the camera wants. **The reach is CAPPED at `near_limit`**, because
## the wanted square grows with the square of the view height and a pulled-back
## camera asks for the whole world: 1,681 chunks on this island, 77 seconds of
## building, for a frame in which a tile is a pixel and a half. Past the cap the
## coarse `world_far.gd` is already standing there.
func _wanted(extra: float) -> Array[Vector2i]:
	var cap := near_limit
	if is_inside_tree() and SkyLight.sees_horizon(get_viewport().get_camera_3d()):
		cap = minf(cap, float(Quality.current().get("horizon_near", near_limit)))
	var r := minf(view_half_extent(), cap) + margin + extra
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
	var t1 := Time.get_ticks_usec()
	var dec := decor.build_arrays(ch)
	var t2 := Time.get_ticks_usec()
	var snap := _snapshot(key)
	var baked := bake_props(ch, mesher, snap[0], snap[1])
	var t3 := Time.get_ticks_usec()
	_last_decor_usec = t2 - t1
	_last_props_usec = t3 - t2
	_add_chunk(key, ch, dec, t3 - t0, baked)


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
	_mask_dirty = true
	var main := (Time.get_ticks_usec() - t0) / 1000.0
	var ms := worker_usec / 1000.0 + main
	decor_ms += _last_decor_usec / 1000.0
	props_ms += _last_props_usec / 1000.0
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
	# A parked chunk cannot be patched where it stands, and a stale one is worse
	# than a missing one: let it go, and it is built again as it is now.
	if _parked.has(key):
		(_parked[key] as Node3D).queue_free()
		_parked.erase(key)
		_park_seen.erase(key)
		_data.erase(key)
		return
	if not _chunks.has(key):
		return
	var node: Node3D = _chunks[key]
	for part: String in ["props", "props_found", "props_leaf"]:
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


## A chunk's props baked into three surfaces' arrays: [MADE arrays or [], FOUND
## arrays or [], LEAF arrays or []]. Pure given its inputs, so safe on a worker thread with that
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
	var lv := PackedVector3Array()
	var ln := PackedVector3Array()
	var lc := PackedColorArray()
	var luv := PackedVector2Array()
	var luv2 := PackedVector2Array()
	for p: WorldProp in props:
		var country := prop_country(p, ch)
		var variant := PropModels.variant_of(p, world.seed_value, country)
		# What a thing the taking has worked on is DRAWN as: the same thing with a
		# piece off it and a fresh face where the tool went (`Broken`), quantised
		# to the five steps a template is cached in. `shown` is 1.0 on anything
		# nobody has touched, so an untouched world bakes exactly as it always did.
		var tpl := PropModels.template(p.kind, variant, country, Broken.bucket(p.shown))
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
		if not tpl.leaf_v.is_empty():
			lv.append_array(xf * tpl.leaf_v)
			ln.append_array(nx * tpl.leaf_n)
			lc.append_array(tpl.leaf_c)
			luv.append_array(tpl.leaf_uv)
			luv2.append_array(tpl.leaf_uv2)
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
	var leaves := []
	if not lv.is_empty():
		leaves.resize(Mesh.ARRAY_MAX)
		leaves[Mesh.ARRAY_VERTEX] = lv
		leaves[Mesh.ARRAY_NORMAL] = ln
		leaves[Mesh.ARRAY_COLOR] = lc
		leaves[Mesh.ARRAY_TEX_UV] = luv
		leaves[Mesh.ARRAY_TEX_UV2] = luv2
	return [made, found, leaves]


## Height of the drawn land under p: the chunk's own surface inside it, the
## mesher's field outside.
static func _height(ch: TerrainMesher.Chunk, m: TerrainMesher, p: Vector2) -> float:
	if ch != null and p.x >= ch.x0 and p.y >= ch.y0 and p.x < ch.x0 + ch.w and p.y < ch.y0 + ch.h:
		return ch.surface(p.x, p.y)
	return m.surface_height(p.x, p.y)


## Turn baked prop arrays into the chunk's prop meshes (main thread).
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
	var leaves: Array = baked[2] if baked.size() > 2 else []
	if not leaves.is_empty():
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, leaves)
		var mi := MeshInstance3D.new()
		mi.name = "props_leaf"
		mi.mesh = mesh
		mi.material_override = _leaf_mat
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
			# in the page (docs/LOOK.md section 6).
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
	# Past everything the eye can see from anywhere on the island (SkyLight.SEE):
	# at eye level the sea runs to the horizon, and where it stopped the sky's
	# ground half showed through as a band of nothing under the air.
	var m := SkyLight.SEE + 200.0
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
