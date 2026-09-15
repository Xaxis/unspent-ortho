class_name TerrainMesher
extends RefCounted
## Builds one CHUNK x CHUNK tile area of the world into meshes, and writes the
## per-tile data the world shader draws the ground from. Pure function of
## WorldData + chunk coords: the same chunk always builds the same mesh.
##
## Geometry
##   tops   one quad per tile at its corner heights. A corner is shared (and may
##          wobble, or slope into water on soft shores) only when every land tile
##          around it stands at the same height, so there are never cracks.
##   faces  one quad per edge toward a lower neighbour, carrying the strata data
##          (country, country2, blend, lip height) the shader paints beds from.
##   lips   ragged overhangs of turf or snow along cliff tops; icicles in the cold.
##   water  sheets over wet tiles, falls between sheets at different heights.
##
## Vertex channels (all terrain and prop geometry, see world.gdshader)
##   UV.y   kind: KIND_* below.  UV.x  kind parameter (ground id, sway weight, glow).
##   UV2    tile-space xz, so data lookups survive the view being moved (gallery).
##
## Data textures (world-sized, RGBA8, nearest)
##   tile   rgb base colour across the ecotone, a ground id
##   field  r level+64, g country | country2 << 4, b blend * 510,
##          a 128 + signed distance to the waterline * 10 (water side positive)

const CHUNK := 32
const WATER_Y := 0.3
const SEA_FLOOR := -1.0
## How far an inland wet tile's bed sits below its level.
const WET_SINK := 0.4
## Inland water surface below the tile's level: never proud of a same-level bank.
const INLAND_SHEET := 0.12
## Soft shores slope to this far above the water they meet.
const SHORE_LIFT := 0.06
const SHORE_MARGIN := 9

const KIND_MODEL := 0
const KIND_TOP := 1
const KIND_FACE := 2
const KIND_GLOW := 3
const KIND_SWAY := 4
const KIND_GLINT := 5

const WATER_SEA := 0
const WATER_RIVER := 1
const WATER_BLACK := 2
const WATER_COLD := 3
const WATER_FALL := 4
const WATER_OPEN := 5

var world: WorldData
var transitions: BlendFallback
var tile_image: Image
var field_image: Image
## Set when a build wrote texture data that is not uploaded yet.
var dirty := false

static var _rand := PackedFloat32Array()
static var PROF := PackedInt64Array([0, 0, 0, 0])
static var _SOFT := PackedByteArray()
static var _WOBBLE := PackedFloat32Array()


## One built chunk: meshes plus what decor needs to sit on the ground.
class Chunk:
	var cx: int
	var cy: int
	var x0: int
	var y0: int
	var w: int
	var h: int
	var terrain: ArrayMesh
	var water: ArrayMesh
	## Per tile, row-major over the chunk: drawn country, country2, blend.
	var country := PackedByteArray()
	var country2 := PackedByteArray()
	var blend := PackedFloat32Array()
	## Per tile: 4 corner heights (NW, NE, SE, SW).
	var corners := PackedFloat32Array()
	## Per tile: signed distance to the waterline (water side positive).
	var shore := PackedFloat32Array()
	## Per tile: base colour across the ecotone.
	var colors := PackedColorArray()
	## Cliff feet: [Vector3 foot point, Vector3 outward normal, int country, float drop].
	var feet: Array = []


## Plain vertex buffers with the channels above.
class Buf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()

	## a, b, c counter-clockwise seen from the front; emitted reversed (Godot fronts are clockwise).
	func tri(a: Vector3, b: Vector3, cc: Vector3, col: Color, kind_uv: Vector2) -> void:
		var nn := (cc - b).cross(a - b).normalized()
		v.append(a)
		v.append(cc)
		v.append(b)
		n.append(nn)
		n.append(nn)
		n.append(nn)
		c.append(col)
		c.append(col)
		c.append(col)
		uv.append(kind_uv)
		uv.append(kind_uv)
		uv.append(kind_uv)
		uv2.append(Vector2(a.x, a.z))
		uv2.append(Vector2(cc.x, cc.z))
		uv2.append(Vector2(b.x, b.z))

	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color, kind_uv: Vector2) -> void:
		tri(a, b, cc, col, kind_uv)
		tri(a, cc, d, col, kind_uv)

	## A quad with a known normal; `pin` (if non-zero) fixes the data position.
	func quad_n(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color, kind_uv: Vector2, nn: Vector3, pin: Vector2) -> void:
		v.append(a)
		v.append(cc)
		v.append(b)
		v.append(a)
		v.append(d)
		v.append(cc)
		for i in 6:
			n.append(nn)
			c.append(col)
			uv.append(kind_uv)
		if pin != Vector2.ZERO:
			for i in 6:
				uv2.append(pin)
		else:
			uv2.append(Vector2(a.x, a.z))
			uv2.append(Vector2(cc.x, cc.z))
			uv2.append(Vector2(b.x, b.z))
			uv2.append(Vector2(a.x, a.z))
			uv2.append(Vector2(d.x, d.z))
			uv2.append(Vector2(cc.x, cc.z))

	func empty() -> bool:
		return v.is_empty()

	func build() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if v.is_empty():
			return mesh
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


static func _static_init() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 0x1A2B3C4D
	_rand.resize(65536)
	for i in 65536:
		_rand[i] = r.randf()
	_SOFT.resize(256)
	_WOBBLE.resize(256)
	for g in 256:
		_SOFT[g] = 1 if is_soft(g) else 0
		_WOBBLE[g] = wobble_amount(g)


func _init(w: WorldData) -> void:
	world = w
	transitions = BlendFallback.new(w)
	tile_image = Image.create(w.size, w.size, false, Image.FORMAT_RGBA8)
	field_image = Image.create(w.size, w.size, false, Image.FORMAT_RGBA8)
	field_image.fill(Color8(64, Country.COAST, 0, 128))


## Cheap deterministic hash of a tile and a salt, in [0, 1).
func h01(x: int, y: int, salt: int) -> float:
	var k := (x * 374761393 + y * 668265263 + salt * 1274126177 + world.seed_value * 2654435761) & 0xFFFFFFFF
	k = ((k ^ (k >> 13)) * 1103515245) & 0xFFFFFFFF
	return _rand[(k ^ (k >> 16)) & 0xFFFF]


static func is_wet(g: int) -> bool:
	return Ground.is_water(g)


## Grounds that slump into water and may slope instead of stepping.
static func is_soft(g: int) -> bool:
	match g:
		Ground.ROCK, Ground.LIMESTONE, Ground.CLINKER, Ground.ICE, Ground.FLOOR, Ground.SCREE:
			return false
	return not Ground.is_water(g)


## How much a ground's top may undulate, in world units.
static func wobble_amount(g: int) -> float:
	match g:
		Ground.MOSS: return 0.1
		Ground.PEAT, Ground.SNOW: return 0.06
		Ground.HEATH, Ground.SAND, Ground.ASH, Ground.MUD, Ground.SCREE: return 0.045
		Ground.GRASS, Ground.NEEDLES: return 0.035
		Ground.SHINGLE, Ground.GRAVEL, Ground.BONE: return 0.02
	return 0.0


## Rendered height of a tile's flat top (before corner shaping).
func top_height(x: int, y: int) -> float:
	var l := world.level_at(x, y)
	var g := world.ground_at(x, y)
	if is_wet(g) or not world.in_bounds(x, y):
		if l <= 0:
			return 0.0 if l == 0 else SEA_FLOOR
		return l * WorldData.STEP - WET_SINK
	if l <= 0:
		return WATER_Y + 0.02
	return l * WorldData.STEP


## Height of the water surface over a wet tile.
func sheet_height(x: int, y: int) -> float:
	var l := world.level_at(x, y)
	if l <= 0:
		return WATER_Y
	return l * WorldData.STEP - INLAND_SHEET


## The height a walker's shins are hidden below on a wet tile (world.gdshader
## cuts models there). Always above the walker's feet at WorldData.height_at.
func wade_line(x: int, y: int) -> float:
	var l := world.level_at(x, y)
	if l <= 0:
		return WATER_Y
	return l * WorldData.STEP + 0.22


## Height of tile (x, y)'s corner at integer corner point (px, py).
func corner_height(x: int, y: int, px: int, py: int) -> float:
	var w := world
	var own := top_height(x, y)
	if is_wet(w.ground_at(x, y)):
		return own
	var wet := false
	var sheet := INF
	var soft := true
	var amp := 1.0
	for oy in 2:
		for ox in 2:
			var tx := px - 1 + ox
			var ty := py - 1 + oy
			var g := w.ground_at(tx, ty)
			if is_wet(g) or not w.in_bounds(tx, ty):
				wet = true
				sheet = minf(sheet, sheet_height(tx, ty))
				continue
			if absf(top_height(tx, ty) - own) > 1e-4:
				return own
			soft = soft and is_soft(g)
			amp = minf(amp, wobble_amount(g))
	if wet:
		var lift := sheet + SHORE_LIFT
		if soft and own > lift and own - sheet <= 0.62:
			return lift
		return own
	if amp <= 0.0:
		return own
	return own + (_corner_noise(px, py) - 0.5) * 2.0 * amp


func _corner_noise(px: int, py: int) -> float:
	# Two octaves so hummocks come in groups rather than as salt and pepper.
	var s := world.seed_value * 31
	var a := _rand[(px * 7919 + py * 104729 + s) & 0xFFFF]
	var b := _rand[((px >> 1) * 2273 + (py >> 1) * 6007 + s + 17) & 0xFFFF]
	return a * 0.45 + b * 0.55


## Base colour of a tile as drawn (used by the map tool). No ecotone mixing.
func top_color(x: int, y: int) -> Color:
	var c := world.country_at(x, y)
	return GroundColors.base(world.ground_at(x, y), c if c != Country.SEA else Country.COAST)


## Build a chunk. Also writes its tiles (and a one-tile ring) into the data images.
func build(cx: int, cy: int) -> Chunk:
	var w := world
	var size := w.size
	var ch := Chunk.new()
	ch.cx = cx
	ch.cy = cy
	ch.x0 = cx * CHUNK
	ch.y0 = cy * CHUNK
	var x1 := mini(size, ch.x0 + CHUNK)
	var y1 := mini(size, ch.y0 + CHUNK)
	ch.w = x1 - ch.x0
	ch.h = y1 - ch.y0
	# Transitions and shore distances over the chunk plus a ring for the textures.
	var rx0 := maxi(0, ch.x0 - 1)
	var ry0 := maxi(0, ch.y0 - 1)
	var rx1 := mini(size, x1 + 1)
	var ry1 := mini(size, y1 + 1)
	var rw := rx1 - rx0
	var rc := PackedByteArray()
	var rc2 := PackedByteArray()
	var rb := PackedFloat32Array()
	transitions.fill(rx0, ry0, rx1, ry1, rc, rc2, rb)
	var shore := _shore_field(rx0, ry0, rx1, ry1)
	var ring_col := PackedColorArray()
	ring_col.resize(rw * (ry1 - ry0))
	var _p0 := Time.get_ticks_usec()
	for y in range(ry0, ry1):
		for x in range(rx0, rx1):
			var o := (y - ry0) * rw + (x - rx0)
			var i := y * size + x
			var g := w.ground[i]
			var col := GroundColors.tile(g, rc[o], rc2[o], rb[o])
			ring_col[o] = col
			col.a = g / 255.0
			tile_image.set_pixel(x, y, col)
			field_image.set_pixel(x, y, Color8(clampi(w.level[i] + 64, 0, 255), rc[o] | (rc2[o] << 4), clampi(roundi(rb[o] * 510.0), 0, 255), clampi(roundi(128.0 + shore[o] * 10.0), 0, 255)))
	dirty = true
	var n := ch.w * ch.h
	ch.country.resize(n)
	ch.country2.resize(n)
	ch.blend.resize(n)
	ch.shore.resize(n)
	ch.corners.resize(n * 4)
	ch.colors.resize(n)
	for y in range(ch.y0, y1):
		for x in range(ch.x0, x1):
			var o := (y - ry0) * rw + (x - rx0)
			var t := (y - ch.y0) * ch.w + (x - ch.x0)
			ch.country[t] = rc[o]
			ch.country2[t] = rc2[o]
			ch.blend[t] = rb[o]
			ch.shore[t] = shore[o]
			ch.colors[t] = ring_col[o]
	var _p1 := Time.get_ticks_usec()
	var win := _window(ch)
	var _p2 := Time.get_ticks_usec()
	var terrain := Buf.new()
	var water := Buf.new()
	for y in range(ch.y0, y1):
		for x in range(ch.x0, x1):
			_tile(ch, win, terrain, water, x, y)
	var _p3 := Time.get_ticks_usec()
	PROF[0] += _p1 - _p0
	PROF[1] += _p2 - _p1
	PROF[2] += _p3 - _p2
	PROF[3] += terrain.v.size()
	ch.terrain = terrain.build()
	ch.water = water.build() if not water.empty() else null
	return ch


## Per-chunk lookups over the chunk plus a one-tile ring, so building a tile
## never calls back into WorldData: levels, grounds, wet flags, top and sheet
## heights, and the shared height of every corner point (NO_SHARE if a tile
## there must use its own top).
class Patch:
	var x0: int
	var y0: int
	var ww: int
	var wet := PackedByteArray()
	var ground := PackedByteArray()
	var level := PackedInt32Array()
	var top := PackedFloat32Array()
	var sheet := PackedFloat32Array()
	var shared := PackedFloat32Array()
	var cw: int

	func at(x: int, y: int) -> int:
		return (y - y0) * ww + (x - x0)


const NO_SHARE := -1000.0


func _window(ch: Chunk) -> Patch:
	var w := world
	var win := Patch.new()
	win.x0 = ch.x0 - 1
	win.y0 = ch.y0 - 1
	win.ww = ch.w + 2
	var wh := ch.h + 2
	var n := win.ww * wh
	win.wet.resize(n)
	win.ground.resize(n)
	win.level.resize(n)
	win.top.resize(n)
	win.sheet.resize(n)
	for yy in wh:
		var y := win.y0 + yy
		for xx in win.ww:
			var x := win.x0 + xx
			var i := yy * win.ww + xx
			var inside := x >= 0 and y >= 0 and x < w.size and y < w.size
			var l := w.level[y * w.size + x] if inside else -3
			var g := w.ground[y * w.size + x] if inside else Ground.DEEP_WATER
			var is_w := not inside or Ground.is_water(g)
			win.level[i] = l
			win.ground[i] = g
			win.wet[i] = 1 if is_w else 0
			if is_w:
				win.top[i] = (0.0 if l == 0 else SEA_FLOOR) if l <= 0 else l * WorldData.STEP - WET_SINK
			else:
				win.top[i] = WATER_Y + 0.02 if l <= 0 else l * WorldData.STEP
			win.sheet[i] = WATER_Y if l <= 0 else l * WorldData.STEP - INLAND_SHEET
	win.cw = ch.w + 1
	win.shared.resize(win.cw * (ch.h + 1))
	for cy in ch.h + 1:
		for cx in win.cw:
			var px := ch.x0 + cx
			var py := ch.y0 + cy
			var h := NO_SHARE
			var same := true
			var wet := false
			var sheet := INF
			var soft := true
			var amp := 1.0
			for k in 4:
				var i := win.at(px - 1 + (k & 1), py - 1 + (k >> 1))
				if win.wet[i] == 1:
					wet = true
					sheet = minf(sheet, win.sheet[i])
					continue
				var th := win.top[i]
				if h == NO_SHARE:
					h = th
				elif absf(th - h) > 1e-4:
					same = false
					break
				var g := win.ground[i]
				soft = soft and _SOFT[g] == 1
				amp = minf(amp, _WOBBLE[g])
			var out := NO_SHARE
			if same and h != NO_SHARE:
				if wet:
					var lift := sheet + SHORE_LIFT
					if soft and h > lift and h - sheet <= 0.62:
						out = lift
				elif amp > 0.0:
					out = h + (_corner_noise(px, py) - 0.5) * 2.0 * amp
			win.shared[cy * win.cw + cx] = out
	return win


func _tile(ch: Chunk, win: Patch, t: Buf, water: Buf, x: int, y: int) -> void:
	var wi := win.at(x, y)
	var g := win.ground[wi]
	var ti := (y - ch.y0) * ch.w + (x - ch.x0)
	var wet := win.wet[wi] == 1
	var own := win.top[wi]
	var k00 := own
	var k10 := own
	var k11 := own
	var k01 := own
	if not wet:
		var c0 := (y - ch.y0) * win.cw + (x - ch.x0)
		var s := win.shared[c0]
		if s != NO_SHARE:
			k00 = s
		s = win.shared[c0 + 1]
		if s != NO_SHARE:
			k10 = s
		s = win.shared[c0 + win.cw + 1]
		if s != NO_SHARE:
			k11 = s
		s = win.shared[c0 + win.cw]
		if s != NO_SHARE:
			k01 = s
	ch.corners[ti * 4] = k00
	ch.corners[ti * 4 + 1] = k10
	ch.corners[ti * 4 + 2] = k11
	ch.corners[ti * 4 + 3] = k01
	var p00 := Vector3(x, k00, y)
	var p10 := Vector3(x + 1, k10, y)
	var p11 := Vector3(x + 1, k11, y + 1)
	var p01 := Vector3(x, k01, y + 1)
	var c := ch.country[ti]
	var c2 := ch.country2[ti]
	var bl := ch.blend[ti]
	var sheet := win.sheet[wi]
	# Beds under an opaque sheet are never seen.
	if not (wet and own < sheet - 0.05):
		var col := ch.colors[ti]
		var top_uv := Vector2(g, KIND_TOP)
		# Split along the diagonal that follows the ground: a ridge stays a ridge.
		if absf(k01 + k10 - k00 - k11) > 1e-4 and (k01 + k10 > k00 + k11) == (h01(x, y, 3) < 0.7):
			t.tri(p01, p11, p10, col, top_uv)
			t.tri(p01, p10, p00, col, top_uv)
		elif k00 == k10 and k10 == k11 and k11 == k01:
			t.quad_n(p00, p01, p11, p10, col, top_uv, Vector3.UP, Vector2.ZERO)
		else:
			t.quad(p00, p01, p11, p10, col, top_uv)
	# Faces toward every lower neighbour.
	var lo := minf(minf(k00, k10), minf(k11, k01))
	if win.top[wi + 1] < lo or win.top[wi - 1] < lo or win.top[wi + win.ww] < lo or win.top[wi - win.ww] < lo \
			or win.top[wi + 1] < own - 1e-4 or win.top[wi - 1] < own - 1e-4 or win.top[wi + win.ww] < own - 1e-4 or win.top[wi - win.ww] < own - 1e-4:
		_face(ch, win, t, x, y, g, wi + 1, p11, p10, Vector3.RIGHT, c, c2, bl)
		_face(ch, win, t, x, y, g, wi - 1, p00, p01, Vector3.LEFT, c, c2, bl)
		_face(ch, win, t, x, y, g, wi + win.ww, p01, p11, Vector3.BACK, c, c2, bl)
		_face(ch, win, t, x, y, g, wi - win.ww, p10, p00, Vector3.FORWARD, c, c2, bl)
	if wet:
		_water(ch, win, water, x, y, g, sheet, c)


func _face(ch: Chunk, win: Patch, t: Buf, x: int, y: int, g: int, ni: int, a: Vector3, b: Vector3, normal: Vector3, c: int, c2: int, bl: float) -> void:
	var bottom := win.top[ni]
	var hi := maxf(a.y, b.y)
	if bottom >= minf(a.y, b.y) - 1e-4:
		return
	if win.wet[ni] == 1 and win.level[ni] <= 0:
		# Under the sea sheet nothing shows.
		bottom = maxf(bottom, -0.05)
	var wet := win.wet[win.at(x, y)] == 1
	if wet and hi <= win.sheet[win.at(x, y)] + 0.01:
		return
	var data := Color(c / 8.0, c2 / 8.0, bl * 2.0, clampf(hi / 8.0, 0.0, 1.0))
	var ab := Vector3(a.x, bottom, a.z)
	var bb := Vector3(b.x, bottom, b.z)
	t.quad_n(ab, bb, b, a, data, Vector2(g, KIND_FACE), normal, Vector2.ZERO)
	var drop := hi - bottom
	if wet or drop < 0.3:
		return
	if drop >= 0.99:
		var mid := (a + b) * 0.5
		ch.feet.append([Vector3(mid.x, bottom, mid.z) + normal * 0.02, normal, c if h01(x, y, 41) >= bl else c2, drop])
	_lip(t, x, y, g, a, b, normal, c if h01(x + int(normal.x), y + int(normal.z), 43) >= bl else c2, drop)


## A ragged overhang along a cliff top: turf, snow with icicles, or nothing on bare rock and sand.
func _lip(t: Buf, x: int, y: int, g: int, a: Vector3, b: Vector3, normal: Vector3, country: int, drop: float) -> void:
	var style := 0 # 0 none, 1 turf, 2 snow
	match g:
		Ground.GRASS, Ground.HEATH, Ground.MOSS, Ground.PEAT, Ground.NEEDLES, Ground.MUD:
			style = 1
		Ground.SNOW:
			style = 2
	if country == Country.SNOWFIELD and g != Ground.ICE and g != Ground.SAND:
		style = 2
	if style == 0:
		return
	var top_col := GroundColors.base(g, country)
	var front := GroundColors.down(top_col, 0.9)
	var pin := Vector2(x + 0.5, y + 0.5)
	var salt := int(normal.x * 11.0 + normal.z * 17.0) + 60
	var up := Vector3(0, 0.004, 0)
	var mid := 0.35 + h01(x, y, 47) * 0.3
	var prev_q := Vector3.ZERO
	var prev_d := 0.0
	for s in 2:
		var t0 := 0.0 if s == 0 else mid
		var t1 := mid if s == 0 else 1.0
		var o := 0.04 + h01(x * 3 + s, y * 5 + salt, salt) * 0.07
		var th := 0.08 + h01(x + s * 7, y + salt, salt + 1) * 0.08
		if style == 2:
			o += 0.03
			th += 0.05
		o = minf(o, 0.12)
		var p0 := a.lerp(b, t0) + up
		var p1 := a.lerp(b, t1) + up
		var q0 := p0 + normal * o
		var q1 := p1 + normal * o
		var dh := minf(th, drop * 0.5)
		var d := Vector3(0, -dh, 0)
		# Top of the overhang continues the ground; front is the turf or snow edge.
		t.quad_n(p0, q0, q1, p1, top_col, Vector2(g, KIND_TOP), Vector3.UP, pin)
		t.quad_n(q0 + d, q1 + d, q1, q0, Palette.RIME[5] if style == 2 else front, Vector2.ZERO, normal, Vector2.ZERO)
		if s == 1:
			# One cap where the two segments meet, facing whichever way shows.
			var deep := prev_q if o < prev_d else q0
			var shallow := q0 if o < prev_d else prev_q
			var dd := Vector3(0, -maxf(dh, th), 0)
			t.quad(shallow + dd, deep + dd, deep, shallow, GroundColors.down(front, 0.5), Vector2.ZERO)
		prev_q = q1
		prev_d = o
		if style == 2:
			# Icicles hang from the snow edge, uneven.
			var teeth := 2 + int(h01(x + s, y * 3, salt + 2) * 3.0)
			for k in teeth:
				var u0 := (k + 0.15) / teeth
				var u1 := (k + 0.85) / teeth
				var e0 := q0.lerp(q1, u0) + d
				var e1 := q0.lerp(q1, u1) + d
				var tip := e0.lerp(e1, 0.5) + Vector3(0, -0.06 - h01(x * 7 + k, y + s * 13, salt + 3) * 0.16, 0)
				t.tri(e0, tip, e1, Palette.RIME[4] if k % 2 == 0 else Palette.RIME[5], Vector2.ZERO)


func _water(ch: Chunk, win: Patch, water: Buf, x: int, y: int, g: int, sheet: float, country: int) -> void:
	var w := world
	var kind := WATER_SEA
	if g == Ground.BLACKWATER:
		kind = WATER_BLACK
	elif g == Ground.RIVER or w.level_at(x, y) > 0:
		kind = WATER_RIVER
	elif country == Country.SNOWFIELD:
		kind = WATER_COLD
	var flow := _flow(x, y) if kind == WATER_RIVER else Vector2.ZERO
	var data := Color(flow.x * 0.5 + 0.5, flow.y * 0.5 + 0.5, 1.0 if kind == WATER_RIVER else 0.0, 1.0)
	var uv := Vector2(kind, 0)
	water.quad(Vector3(x, sheet, y), Vector3(x, sheet, y + 1), Vector3(x + 1, sheet, y + 1), Vector3(x + 1, sheet, y), data, uv)
	# Falls where this sheet stands above a neighbouring one.
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var ni := win.at(x + d.x, y + d.y)
		if win.wet[ni] == 0:
			continue
		var ns := win.sheet[ni]
		if ns >= sheet - 0.02:
			continue
		var a: Vector3
		var b: Vector3
		match d:
			Vector2i(1, 0):
				a = Vector3(x + 1, 0, y + 1)
				b = Vector3(x + 1, 0, y)
			Vector2i(-1, 0):
				a = Vector3(x, 0, y)
				b = Vector3(x, 0, y + 1)
			Vector2i(0, 1):
				a = Vector3(x, 0, y + 1)
				b = Vector3(x + 1, 0, y + 1)
			_:
				a = Vector3(x + 1, 0, y)
				b = Vector3(x, 0, y)
		water.quad(Vector3(a.x, ns, a.z), Vector3(b.x, ns, b.z), Vector3(b.x, sheet, b.z), Vector3(a.x, sheet, a.z), data, Vector2(WATER_FALL, 0))


## Downstream direction of a river tile: away from higher water, toward lower,
## otherwise along the channel toward the sea side.
func _flow(x: int, y: int) -> Vector2:
	var w := world
	var here := w.level_at(x, y)
	var acc := Vector2.ZERO
	var axis := Vector2.ZERO
	for oy in range(-2, 3):
		for ox in range(-2, 3):
			if ox == 0 and oy == 0:
				continue
			var g := w.ground_at(x + ox, y + oy)
			if not is_wet(g):
				continue
			var d := Vector2(ox, oy)
			var l := w.level_at(x + ox, y + oy)
			acc += d.normalized() * float(here - l)
			# Channel axis: accumulate doubled-angle vectors so opposite cells agree.
			var ang := d.angle() * 2.0
			axis += Vector2(cos(ang), sin(ang))
	if acc.length() > 0.5:
		return acc.normalized()
	if axis.length() > 0.1:
		var dir := Vector2.from_angle(axis.angle() * 0.5)
		# Point it toward the world edge it is nearer (the sea), deterministically.
		var centre := Vector2(w.size * 0.5, w.size * 0.5)
		if dir.dot(Vector2(x, y) - centre) < 0.0:
			dir = -dir
		return dir
	return Vector2(1, 0)


## Signed distance (tiles) from each tile centre in the rectangle to the
## waterline: wet tiles positive, dry tiles negative. Exact within SHORE_MARGIN.
func _shore_field(rx0: int, ry0: int, rx1: int, ry1: int) -> PackedFloat32Array:
	var w := world
	var m := SHORE_MARGIN
	var wx0 := maxi(0, rx0 - m)
	var wy0 := maxi(0, ry0 - m)
	var wx1 := mini(w.size, rx1 + m)
	var wy1 := mini(w.size, ry1 + m)
	var ww := wx1 - wx0
	var wh := wy1 - wy0
	var wet := PackedByteArray()
	wet.resize(ww * wh)
	for y in wh:
		var src := (y + wy0) * w.size + wx0
		for x in ww:
			wet[y * ww + x] = 1 if Ground.is_water(w.ground[src + x]) else 0
	# One unsigned field: distance from each centre to the nearest waterline,
	# seeded half a tile from every edge between wet and dry.
	var d := PackedFloat32Array()
	d.resize(ww * wh)
	d.fill(99.0)
	for y in wh:
		for x in ww:
			var i := y * ww + x
			var here := wet[i]
			if (x > 0 and wet[i - 1] != here) or (x < ww - 1 and wet[i + 1] != here) or (y > 0 and wet[i - ww] != here) or (y < wh - 1 and wet[i + ww] != here):
				d[i] = 0.5
			elif (x > 0 and y > 0 and wet[i - ww - 1] != here) or (x < ww - 1 and y > 0 and wet[i - ww + 1] != here) \
					or (x > 0 and y < wh - 1 and wet[i + ww - 1] != here) or (x < ww - 1 and y < wh - 1 and wet[i + ww + 1] != here):
				d[i] = 0.71
	var dg := 1.4142
	for y in wh:
		for x in ww:
			var i := y * ww + x
			var v := d[i]
			if x > 0:
				v = minf(v, d[i - 1] + 1.0)
			if y > 0:
				v = minf(v, d[i - ww] + 1.0)
				if x > 0:
					v = minf(v, d[i - ww - 1] + dg)
				if x < ww - 1:
					v = minf(v, d[i - ww + 1] + dg)
			d[i] = v
	for yy in wh:
		var y := wh - 1 - yy
		for xx in ww:
			var x := ww - 1 - xx
			var i := y * ww + x
			var v := d[i]
			if x < ww - 1:
				v = minf(v, d[i + 1] + 1.0)
			if y < wh - 1:
				v = minf(v, d[i + ww] + 1.0)
				if x < ww - 1:
					v = minf(v, d[i + ww + 1] + dg)
				if x > 0:
					v = minf(v, d[i + ww - 1] + dg)
			d[i] = v
	var out := PackedFloat32Array()
	var rw := rx1 - rx0
	out.resize(rw * (ry1 - ry0))
	for y in range(ry0, ry1):
		for x in range(rx0, rx1):
			var i := (y - wy0) * ww + (x - wx0)
			var v := minf(d[i], 12.5)
			out[(y - ry0) * rw + (x - rx0)] = v if wet[i] == 1 else -v
	return out


## Legacy entry point: [terrain: ArrayMesh, water: ArrayMesh or null].
func build_chunk(cx: int, cy: int) -> Array:
	var ch := build(cx, cy)
	return [ch.terrain, ch.water]


## Palette ramps as a texture: row = ramp (RAMPS order), column = step.
static func palette_image() -> Image:
	var ramps: Array = [Palette.INK, Palette.STONE, Palette.BRINE, Palette.SLATE, Palette.EARTH, Palette.RUST,
		Palette.MOSS, Palette.SPRUCE, Palette.SAND, Palette.LINEN, Palette.FLESH, Palette.COPPER, Palette.ASH,
		Palette.EMBER, Palette.RIME, Palette.BLOOM, Palette.FOUND, Palette.LENS, Palette.COLD, Palette.PLATE]
	var img := Image.create(6, ramps.size(), false, Image.FORMAT_RGBA8)
	for r in ramps.size():
		var ramp: Array = ramps[r]
		for s in 6:
			img.set_pixel(s, r, ramp[mini(s, ramp.size() - 1)])
	return img
