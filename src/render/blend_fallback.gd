class_name BlendFallback
extends RefCounted
## Landscape transitions for renderers, whichever way they arrive.
##
## Contract: WorldData.country2 / WorldData.blend are written by world generation
## (0 = pure `country`, 0.5 = on the border). A world made before that exists has
## blend all zero; then, and only then, this computes an approximation so
## ecotones can be seen and tuned. It never writes into WorldData.
##
## The approximation measures, on a two-tile grid round the asked rectangle, how
## far each point is from the nearest border between two land countries and
## which country lies across it: blend = 0.5 on the border falling to 0 at
## REACH tiles. Sea tiles report the nearest land country as `country`, so
## water can take on its look.
##
## Either way the band is pulled in to REACH tiles each side of a border, so a
## heartland is its country alone: fill() reports the blend a renderer should
## draw, 0 at REACH tiles out and 0.5 on the border.
##
## `active` also marks a LEGACY world (one generated before the richer grounds):
## renderers may then interleave grounds across an ecotone and draw the
## sub-grounds (heath, shingle, peat, scree, clinker) the generator will place.

## Tiles between distance samples.
const SAMPLE := 2
## Tiles each side of a border that an ecotone reaches.
const REACH := 12.0
## A generated blend runs 0.5 on the border to 0 at 12 to 24 tiles; below this
## it is further out than REACH and drawn as heartland.
const GEN_FLOOR := 0.2

const _SCAN_DX: PackedInt32Array = [-1, -1, 0, 1]
const _SCAN_DY: PackedInt32Array = [0, -1, -1, -1]

var world: WorldData
## True when the world carries no transitions of its own.
var active := false
var _sub: FastNoiseLite


func _init(w: WorldData) -> void:
	world = w
	active = needs_fallback(w)
	_sub = FastNoiseLite.new()
	_sub.seed = Rng.hash_ints(w.seed_value, 0x5B6) & 0x7FFFFFFF
	_sub.frequency = 1.0 / 11.0
	_sub.fractal_octaves = 3


static func needs_fallback(w: WorldData) -> bool:
	return w.blend.size() == 0 or w.blend.count(0.0) == w.blend.size()


## Fill country / country2 / blend for the tile rectangle [x0, x1) x [y0, y1)
## (clipped to the world). Arrays are resized to the rectangle, row-major.
## `country` is the land country a renderer should draw the tile as.
func fill(x0: int, y0: int, x1: int, y1: int, out_country: PackedByteArray, out_country2: PackedByteArray, out_blend: PackedFloat32Array) -> void:
	var w := world
	var size := w.size
	var cw := x1 - x0
	var ch := y1 - y0
	out_country.resize(cw * ch)
	out_country2.resize(cw * ch)
	out_blend.resize(cw * ch)
	# The sample grid: far enough round the rectangle to see every border that
	# can reach into it.
	var pad := int(REACH) + SAMPLE * 2
	var gx0 := floori(float(x0 - pad) / SAMPLE)
	var gy0 := floori(float(y0 - pad) / SAMPLE)
	var gw := floori(float(x1 + pad) / SAMPLE) - gx0 + 1
	var gh := floori(float(y1 + pad) / SAMPLE) - gy0 + 1
	var n := gw * gh
	var own := PackedByteArray()
	own.resize(n)
	for gy in gh:
		var ty := (gy0 + gy) * SAMPLE + SAMPLE / 2
		for gx in gw:
			var tx := (gx0 + gx) * SAMPLE + SAMPLE / 2
			own[gy * gw + gx] = w.country[clampi(ty, 0, size - 1) * size + clampi(tx, 0, size - 1)] if tx >= 0 and ty >= 0 and tx < size and ty < size else Country.SEA
	# Distance (in samples) to a border between land countries and the country
	# across it; and for the sea, the nearest land country.
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(1e6)
	var other := PackedByteArray()
	other.resize(n)
	var land_d := PackedFloat32Array()
	land_d.resize(n)
	land_d.fill(1e6)
	var land := PackedByteArray()
	land.resize(n)
	var any_sea := false
	var any_border := false
	for gy in gh:
		for gx in gw:
			var i := gy * gw + gx
			var c := own[i]
			if c == Country.SEA:
				any_sea = true
				continue
			land_d[i] = 0.0
			land[i] = c
			if gx > 0 and own[i - 1] != Country.SEA and own[i - 1] != c:
				dist[i] = 0.5
				other[i] = own[i - 1]
			elif gx < gw - 1 and own[i + 1] != Country.SEA and own[i + 1] != c:
				dist[i] = 0.5
				other[i] = own[i + 1]
			elif gy > 0 and own[i - gw] != Country.SEA and own[i - gw] != c:
				dist[i] = 0.5
				other[i] = own[i - gw]
			elif gy < gh - 1 and own[i + gw] != Country.SEA and own[i + gw] != c:
				dist[i] = 0.5
				other[i] = own[i + gw]
			if dist[i] < 1.0:
				any_border = true
	# Borders matter only when this fallback draws them; the nearest land only
	# when there is sea.
	var do_border := active and any_border
	if do_border or any_sea:
		for pass_i in 2:
			var sgn := 1 if pass_i == 0 else -1
			for yy in gh:
				var gy := yy if pass_i == 0 else gh - 1 - yy
				for xx in gw:
					var gx := xx if pass_i == 0 else gw - 1 - xx
					var i := gy * gw + gx
					var c := own[i]
					for k in 4:
						# Behind this point in scan order: west, north-west, north, north-east.
						var dx: int = _SCAN_DX[k] * sgn
						var dy: int = _SCAN_DY[k] * sgn
						var nx := gx + dx
						var ny := gy + dy
						if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
							continue
						var q := ny * gw + nx
						var cost := 1.0 if k != 1 and k != 3 else 1.4142
						if land_d[q] + cost < land_d[i]:
							land_d[i] = land_d[q] + cost
							land[i] = land[q]
						if not do_border or c == Country.SEA or dist[q] + cost >= dist[i]:
							continue
						var across := other[q] if own[q] == c else own[q]
						if across == c or across == Country.SEA:
							continue
						dist[i] = dist[q] + cost
						other[i] = across
	for y in range(y0, y1):
		var v := clampf((y + 0.5) / SAMPLE - gy0 - 0.5, 0.0, gh - 1.001)
		var iv := floori(v)
		var fv := v - iv
		for x in range(x0, x1):
			var u := clampf((x + 0.5) / SAMPLE - gx0 - 0.5, 0.0, gw - 1.001)
			var iu := floori(u)
			var fu := u - iu
			var a := iv * gw + iu
			var near := a + (1 if fu > 0.5 else 0) + (gw if fv > 0.5 else 0)
			var o := (y - y0) * cw + (x - x0)
			var c := w.country[clampi(y, 0, size - 1) * size + clampi(x, 0, size - 1)] if w.in_bounds(x, y) else Country.SEA
			var i := clampi(y, 0, size - 1) * size + clampi(x, 0, size - 1)
			if c == Country.SEA:
				c = land[near] if land[near] != Country.SEA else Country.COAST
				if w.in_bounds(x, y) and not active and w.country2[i] != Country.SEA and w.blend[i] > 0.0:
					c = w.country2[i]
				out_country[o] = c
				out_country2[o] = c
				out_blend[o] = 0.0
				continue
			out_country[o] = c
			if not active:
				out_country2[o] = w.country2[i]
				out_blend[o] = reach(w.blend[i], GEN_FLOOR)
				continue
			var top := dist[a] + (dist[a + 1] - dist[a]) * fu
			var d := top + ((dist[a + gw] + (dist[a + gw + 1] - dist[a + gw]) * fu) - top) * fv
			var across := other[near]
			if across == Country.SEA or across == c:
				for qi in 4:
					var q := a + (qi & 1) + (gw if qi >= 2 else 0)
					if other[q] != Country.SEA and other[q] != c:
						across = other[q]
						break
			if across == Country.SEA or across == c:
				out_country2[o] = c
				out_blend[o] = 0.0
				continue
			var bl := 0.5 * clampf(1.0 - maxf(0.0, d * SAMPLE - 1.0) / REACH, 0.0, 1.0)
			out_country2[o] = across if bl > 0.0 else c
			out_blend[o] = bl


## A blend pulled in to the band: `floor` and below is heartland (0), the
## border stays 0.5.
static func reach(b: float, floor_value: float) -> float:
	return clampf((b - floor_value) / (0.5 - floor_value), 0.0, 1.0) * 0.5


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
