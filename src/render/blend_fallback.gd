class_name BlendFallback
extends RefCounted
## Landscape transitions for renderers, whichever way they arrive.
##
## Contract: WorldData.country2 / WorldData.blend are written by world generation
## (0 = pure `country`, 0.5 = on the border). A world made before that exists has
## blend all zero; then, and only then, this computes an approximation so
## ecotones can be seen and tuned. It never writes into WorldData.
##
## The approximation: each land country's presence is sampled on a coarse grid,
## box-blurred natively (image mipmaps), and read back bilinearly with a noise
## warp. A tile's `country2` is the strongest other country near it, and
## blend = share of that country, capped at 0.5 on the border. Sea tiles report
## the strongest land country as `country` so water can take on its look.
##
## `active` also marks a LEGACY world (one generated before the richer grounds):
## renderers may then interleave grounds across an ecotone and draw the
## sub-grounds (heath, shingle, peat, scree, clinker) the generator will place.

const CELL := 4
## Mip level read back: CELL * 2^LEVEL tiles per texel, which sets the ecotone
## half-width (~16 tiles each side of a border).
const LEVEL := 2
const WARP := 7.0
## Tiles between weight samples when filling.
const SAMPLE := 2

var world: WorldData
## True when the world carries no transitions of its own.
var active := false
var _masks: Array[PackedFloat32Array] = []
var _mw := 0
var _mh := 0
var _span := 1.0
var _warp: FastNoiseLite
var _sub: FastNoiseLite


func _init(w: WorldData) -> void:
	world = w
	active = needs_fallback(w)
	_warp = FastNoiseLite.new()
	_warp.seed = Rng.hash_ints(w.seed_value, 0xB1E4D) & 0x7FFFFFFF
	_warp.frequency = 1.0 / 23.0
	_warp.fractal_octaves = 2
	_sub = FastNoiseLite.new()
	_sub.seed = Rng.hash_ints(w.seed_value, 0x5B6) & 0x7FFFFFFF
	_sub.frequency = 1.0 / 11.0
	_sub.fractal_octaves = 3
	# Sea tiles need a land country even when real transitions exist.
	_build_masks()


static func needs_fallback(w: WorldData) -> bool:
	return w.blend.size() == 0 or w.blend.count(0.0) == w.blend.size()


func _build_masks() -> void:
	var n := ceili(float(world.size) / CELL)
	var per: Array[PackedFloat32Array] = []
	for c in Country.COUNT:
		var a := PackedFloat32Array()
		a.resize(n * n)
		per.append(a)
	var size := world.size
	for gy in n:
		var ty := mini(size - 1, gy * CELL + CELL / 2)
		for gx in n:
			var tx := mini(size - 1, gx * CELL + CELL / 2)
			var c := world.country[ty * size + tx]
			per[c][gy * n + gx] = 1.0
	_masks.resize(Country.COUNT)
	for c in Country.COUNT:
		if c == Country.SEA:
			_masks[c] = PackedFloat32Array()
			continue
		var img := Image.create_from_data(n, n, false, Image.FORMAT_RF, per[c].to_byte_array())
		img.generate_mipmaps()
		var lw := maxi(1, n >> LEVEL)
		var lh := maxi(1, n >> LEVEL)
		var ofs := img.get_mipmap_offset(LEVEL)
		var data := img.get_data().slice(ofs, ofs + lw * lh * 4)
		_masks[c] = data.to_float32_array()
		_mw = lw
		_mh = lh
	_span = float(size) / _mw


## Weights of every country at a tile (index = Country id), bilinear, warped.
func _weights(x: float, y: float, out: PackedFloat32Array) -> void:
	var wx := x + _warp.get_noise_2d(x, y) * WARP
	var wy := y + _warp.get_noise_2d(x + 517.0, y - 211.0) * WARP
	var u := clampf(wx / _span - 0.5, 0.0, _mw - 1.0)
	var v := clampf(wy / _span - 0.5, 0.0, _mh - 1.0)
	var x0 := mini(floori(u), _mw - 1)
	var y0 := mini(floori(v), _mh - 1)
	var x1 := mini(x0 + 1, _mw - 1)
	var y1 := mini(y0 + 1, _mh - 1)
	var fx := u - x0
	var fy := v - y0
	var i00 := y0 * _mw + x0
	var i10 := y0 * _mw + x1
	var i01 := y1 * _mw + x0
	var i11 := y1 * _mw + x1
	for c in Country.COUNT:
		if c == Country.SEA:
			out[c] = 0.0
			continue
		var m := _masks[c]
		var top := lerpf(m[i00], m[i10], fx)
		var bot := lerpf(m[i01], m[i11], fx)
		out[c] = lerpf(top, bot, fy)


## Fill country / country2 / blend for the tile rectangle [x0, x1) x [y0, y1)
## (clipped to the world). Arrays are resized to the rectangle, row-major.
## `country` is the land country a renderer should draw the tile as.
## The weights are smooth, so they are sampled every SAMPLE tiles.
func fill(x0: int, y0: int, x1: int, y1: int, out_country: PackedByteArray, out_country2: PackedByteArray, out_blend: PackedFloat32Array) -> void:
	var w := world
	var cw := x1 - x0
	var ch := y1 - y0
	out_country.resize(cw * ch)
	out_country2.resize(cw * ch)
	out_blend.resize(cw * ch)
	var weights := PackedFloat32Array()
	weights.resize(Country.COUNT)
	var gx0 := floori(float(x0) / SAMPLE)
	var gy0 := floori(float(y0) / SAMPLE)
	var gw := floori(float(x1 - 1) / SAMPLE) - gx0 + 1
	var gh := floori(float(y1 - 1) / SAMPLE) - gy0 + 1
	# Per sample: the two strongest land countries and their weights.
	var first := PackedByteArray()
	var second := PackedByteArray()
	var wf := PackedFloat32Array()
	var ws := PackedFloat32Array()
	first.resize(gw * gh)
	second.resize(gw * gh)
	wf.resize(gw * gh)
	ws.resize(gw * gh)
	for gy in gh:
		for gx in gw:
			_weights((gx0 + gx) * SAMPLE + 1.0, (gy0 + gy) * SAMPLE + 1.0, weights)
			var a := _strongest(weights, -1)
			var b := _strongest(weights, a)
			var j := gy * gw + gx
			first[j] = a
			second[j] = b
			wf[j] = weights[a]
			ws[j] = weights[b]
	for y in range(y0, y1):
		for x in range(x0, x1):
			var o := (y - y0) * cw + (x - x0)
			if not w.in_bounds(x, y):
				var jj := (clampi(floori(float(y) / SAMPLE) - gy0, 0, gh - 1)) * gw + clampi(floori(float(x) / SAMPLE) - gx0, 0, gw - 1)
				out_country[o] = first[jj]
				out_country2[o] = first[jj]
				out_blend[o] = 0.0
				continue
			var i := y * w.size + x
			var c := w.country[i]
			var j := (floori(float(y) / SAMPLE) - gy0) * gw + (floori(float(x) / SAMPLE) - gx0)
			if c == Country.SEA:
				c = first[j]
				if not active and w.country2[i] != Country.SEA and w.blend[i] > 0.0:
					c = w.country2[i]
			if not active and w.country[i] != Country.SEA:
				out_country[o] = c
				out_country2[o] = w.country2[i]
				out_blend[o] = clampf(w.blend[i], 0.0, 0.5)
				continue
			out_country[o] = c
			if not active:
				out_country2[o] = second[j] if c == first[j] else first[j]
				out_blend[o] = 0.0
			elif c == first[j]:
				out_country2[o] = second[j]
				out_blend[o] = clampf(ws[j] / maxf(1e-3, wf[j] + ws[j]), 0.0, 0.5)
			elif c == second[j]:
				out_country2[o] = first[j]
				out_blend[o] = clampf(wf[j] / maxf(1e-3, wf[j] + ws[j]), 0.0, 0.5)
			else:
				# A sliver of a third country: it is all border.
				out_country2[o] = first[j]
				out_blend[o] = 0.5


func _strongest(weights: PackedFloat32Array, not_c: int) -> int:
	var best := Country.COAST if not_c != Country.COAST else Country.MOSS
	var best_w := -1.0
	for c: int in Country.LAND:
		if c == not_c:
			continue
		if weights[c] > best_w:
			best_w = weights[c]
			best = c
	return best


## The ground a legacy world's tile is drawn as: what the richer generator will
## place there (heath in coast turf, shingle on stretches of shore, peat in the
## fen, scree and clinker among rock). Identity for a world that has them.
func legacy_ground(g: int, c: int, x: float, y: float, shore: float) -> int:
	if not active:
		return g
	var n := _sub.get_noise_2d(x, y)
	match c:
		Country.COAST:
			if g == Ground.GRASS and n > 0.3:
				return Ground.HEATH
			if g == Ground.SAND and shore > -1.6 and n < -0.05:
				return Ground.SHINGLE
		Country.MOSS:
			if g == Ground.MUD:
				return Ground.PEAT
			if g == Ground.MOSS and n > 0.35:
				return Ground.HEATH
		Country.PINEWOOD:
			if g == Ground.GRASS and n > 0.3:
				return Ground.HEATH
		Country.BONELANDS:
			if g == Ground.BONE:
				return Ground.LIMESTONE
			if g == Ground.ROCK:
				return Ground.SCREE
		Country.BURNING:
			if g == Ground.ROCK and n > -0.1:
				return Ground.CLINKER
		Country.SNOWFIELD:
			if g == Ground.ROCK and n > 0.25:
				return Ground.SCREE
	return g
