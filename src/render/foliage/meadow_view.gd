class_name MeadowView
extends Node3D
## THE MEADOW RING: at eye level, the grass round the player stands as thick as
## grass stands, and the baked decor's sparser tufts take over at its edge.
##
## The ground is cut into CELL-tile cells, pinned to the world. Each cell within
## `reach` of the centre is grown once from its chunk by Decor.meadow (the decor's
## own rule for where anything small stands, `thick` times its plants and none
## of its stones), and dropped once it is out of reach. What a cell grows is
## decided by each tile's own place, so nothing swims as the ring follows.
## Cells grow one at a time, nearest first, STRIP rows a frame: grown whole, a
## cell of the coast was an 8-9 ms frame every sixteen tiles walked. (On a
## worker thread the engine intermittently hung at quit, idle, waiting on a
## thread: not worth a hang for a millisecond a frame.)
##
## ONE DRAW PER PLANT TEMPLATE FOR THE WHOLE RING. Every cell's plants of one
## template are one MultiMesh, drawn on grass.gdshader with `meadow` on: the same
## wind, trample and weather as every other blade. A MultiMesh per cell was a
## draw per template per cell, 312 of them for fourteen cells of the coast; the
## ring's plants are few enough that a behind-the-eye half costs less as vertex
## work than as draws. A template is written again only when a cell holding it
## comes or goes, into the MultiMesh it already has: a new one per write left
## the dropped ones' buffers behind and a desktop run hung at quit
## (tests/render/test_meadow_ring.gd).
##
## THE HAND-OVER. Global `foliage_meadow` (xz the centre, z the reach, w BAND)
## tells the grass shader where the ring is. Within BAND of the reach a plant's
## seed decides whether the meadow or the decor draws it, the two shares adding
## to one, so the edge is a thinning and never a line; inside, the decor's own
## grass is left out and its stones and litter stay. A reach of 0 is no ring.
##
## Only while the camera sees the horizon: from above the whole frame is near
## and the ring would be a disc of thicker grass round the player.

## Tiles on a cell's side. A chunk (TerrainMesher.CHUNK) holds a whole number of them.
const CELL := 16
## Tiles over which the meadow hands over to the decor at its edge.
const BAND := 6.0
## Rows of a cell grown in a frame.
const STRIP := 2
## Height over its lowest root a plant may reach, and the lean a gale or a
## trample may give it past its cell, in tiles: the ring's bounds.
const TALLEST := 1.2
const CULL_MARGIN := 1.0

var reach := 0.0
var density := 0.0
## Plants and draws standing now, for a tour to print.
var plants := 0
var draws := 0
var _mat: ShaderMaterial
var _view: WorldView
## Vector2i cell -> {template key: PackedFloat32Array} (Decor.meadow)
var _cells: Dictionary = {}
## Vector2i cell -> Vector2(lowest root, highest root)
var _heights: Dictionary = {}
## template key -> MultiMeshInstance3D
var _draws: Dictionary = {}
var _dirty: Dictionary = {}
var _live := true
## The cell growing, the next row of it to grow, and what it has grown so far.
var _growing := Vector2i.ZERO
var _row := -1
var _grown: Dictionary = {}
## One mesh per plant template, shared by every ring.
static var _meshes: Dictionary = {}


func setup(grass: Shader) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = grass
	_mat.set_shader_parameter(&"meadow", true)
	RenderingServer.global_shader_parameter_set(&"foliage_meadow", Vector4.ZERO)


## The tier's reach and density; changing either grows the ring again.
func configure(new_reach: float, new_density: float) -> void:
	if is_equal_approx(new_reach, reach) and is_equal_approx(new_density, density):
		return
	reach = new_reach
	density = new_density
	clear()


func clear() -> void:
	_row = -1
	_grown = {}
	for mmi: MultiMeshInstance3D in _draws.values():
		mmi.queue_free()
	_draws.clear()
	_cells.clear()
	_heights.clear()
	_dirty.clear()
	plants = 0
	draws = 0


## A chunk was built again (a prop felled, the ground changed): its cells grow again.
func chunk_changed(cx: int, cy: int) -> void:
	var per := TerrainMesher.CHUNK / CELL
	for y in per:
		for x in per:
			var cell := Vector2i(cx * per + x, cy * per + y)
			if _cells.has(cell):
				_drop(cell)
	_redraw()


## Once a frame: follow `centre` (tiles) over `view`'s ground, or stand down.
func follow(view: WorldView, centre: Vector2, on: bool) -> void:
	if view != _view:
		clear()
		_view = view
	var live := on and reach > 0.0 and density > 0.0 and view != null
	# Only when it changes: a tour's `perf meadow` hides the ring to measure it.
	if live != _live:
		_live = live
		visible = live
	RenderingServer.global_shader_parameter_set(&"foliage_meadow",
		Vector4(centre.x, centre.y, reach, BAND) if live else Vector4.ZERO)
	if not live:
		return
	var wanted := cells_near(centre, reach)
	var keep := {}
	for cell: Vector2i in wanted:
		keep[cell] = true
	for cell: Vector2i in _cells.keys():
		if not keep.has(cell):
			_drop(cell)
	if _row >= 0 and not keep.has(_growing):
		_row = -1
	if _row < 0:
		for cell: Vector2i in wanted:
			if not _cells.has(cell):
				_growing = cell
				_row = 0
				_grown = {}
				break
	if _row >= 0:
		_grow_strip()
	_redraw()


## Every cell with some part within `r` of `c`, nearest first.
static func cells_near(c: Vector2, r: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo := Vector2i(floori((c.x - r) / CELL), floori((c.y - r) / CELL))
	var hi := Vector2i(floori((c.x + r) / CELL), floori((c.y + r) / CELL))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if cell_distance(Vector2i(x, y), c) < r:
				out.append(Vector2i(x, y))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return cell_distance(a, c) < cell_distance(b, c))
	return out


## Tiles from `c` to the nearest point of `cell`.
static func cell_distance(cell: Vector2i, c: Vector2) -> float:
	var lo := Vector2(cell * CELL)
	return c.distance_to(c.clamp(lo, lo + Vector2(CELL, CELL)))


func _drop(cell: Vector2i) -> void:
	for key: int in _cells[cell]:
		_dirty[key] = true
	_cells.erase(cell)
	_heights.erase(cell)


## Grow the next STRIP rows of the cell growing; the whole cell joins the ring
## once its last row has grown. Waits while its chunk is not built.
func _grow_strip() -> void:
	var ch := _view.chunk_at(Vector2(_growing * CELL) + Vector2(0.5, 0.5))
	if ch == null:
		return
	var got := _view.decor.meadow(ch, _growing.x * CELL - ch.x0, _growing.y * CELL - ch.y0 + _row, CELL, STRIP,
		Decor.MEADOW_THICK * density)
	for key: int in got:
		var buf: PackedFloat32Array = _grown.get(key, PackedFloat32Array())
		buf.append_array(got[key])
		_grown[key] = buf
	_row += STRIP
	if _row >= CELL:
		_take(_growing, _grown)
		_row = -1
		_grown = {}


## A cell's plants in the ring.
func _take(cell: Vector2i, got: Dictionary) -> void:
	var lo := INF
	var hi := -INF
	for key: int in got:
		_dirty[key] = true
		var buf: PackedFloat32Array = got[key]
		for i in range(7, buf.size(), Decor.MEADOW_FLOATS):
			lo = minf(lo, buf[i])
			hi = maxf(hi, buf[i])
	_cells[cell] = got
	if lo <= hi:
		_heights[cell] = Vector2(lo, hi)


## Write again every template a cell holding it came or went for.
func _redraw() -> void:
	if _dirty.is_empty():
		return
	for key: int in _dirty:
		var buf := PackedFloat32Array()
		var box := AABB()
		var first := true
		for cell: Vector2i in _cells:
			var part: Variant = (_cells[cell] as Dictionary).get(key)
			if part == null:
				continue
			buf.append_array(part)
			var h: Vector2 = _heights[cell]
			var b := AABB(Vector3(cell.x * CELL - CULL_MARGIN, h.x - 0.1, cell.y * CELL - CULL_MARGIN),
				Vector3(CELL + 2.0 * CULL_MARGIN, h.y - h.x + TALLEST, CELL + 2.0 * CULL_MARGIN))
			box = b if first else box.merge(b)
			first = false
		var mmi: MultiMeshInstance3D = _draws.get(key)
		if buf.is_empty():
			if mmi != null:
				mmi.queue_free()
				_draws.erase(key)
			continue
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			mmi.material_override = _mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			_draws[key] = mmi
			var fresh := MultiMesh.new()
			fresh.transform_format = MultiMesh.TRANSFORM_3D
			fresh.use_custom_data = true
			fresh.mesh = _mesh(key)
			mmi.multimesh = fresh
		var mm := mmi.multimesh
		mm.instance_count = buf.size() / Decor.MEADOW_FLOATS
		mm.buffer = buf
		# A buffer written whole does not give the MultiMesh its bounds, and one
		# with none is culled from every frame.
		mm.custom_aabb = box
	_dirty.clear()
	plants = 0
	for mmi: MultiMeshInstance3D in _draws.values():
		plants += mmi.multimesh.instance_count
	draws = _draws.size()


## A template as a mesh the MultiMesh repeats: its UV2.y is the whole part only
## (weight and motion, Decor.template), the seed coming from each instance.
static func _mesh(key: int) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var tpl := Decor.template_of(key)
	var uv2 := PackedVector2Array()
	for wgt: Vector2 in tpl.uv2:
		uv2.append(Vector2(wgt.x, float(tpl.motion)))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = tpl.v
	a[Mesh.ARRAY_NORMAL] = tpl.n
	a[Mesh.ARRAY_COLOR] = tpl.c
	a[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	_meshes[key] = mesh
	return mesh
