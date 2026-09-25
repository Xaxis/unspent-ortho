class_name Transitions
extends RefCounted
## Landscape transitions as renderers draw them.
##
## Contract: WorldData.country2 / WorldData.blend are written by world generation
## (0 = pure `country`, 0.5 = on the border, falling to 0 over 12-24 tiles). A
## renderer pulls the band in to REACH tiles each side of a border, so a
## heartland is its country alone, and sea tiles take the look of the nearest
## land country (so water near a border reads with its shore).

## Tiles between nearest-land samples.
const SAMPLE := 2
## Tiles each side of a border that a drawn ecotone reaches.
const REACH := 12.0
## Tiles past its rectangle that `fill` reads: its country samples, every
## SAMPLE tiles out to REACH and two samples more.
const WINDOW := int(REACH) + SAMPLE * 3
## A generated blend below this is further out than REACH and drawn as heartland.
const GEN_FLOOR := 0.2

const _SCAN_DX: PackedInt32Array = [-1, -1, 0, 1]
const _SCAN_DY: PackedInt32Array = [0, -1, -1, -1]

var world: WorldData


func _init(w: WorldData) -> void:
	world = w


## Fill country / country2 / blend for the tile rectangle [x0, x1) x [y0, y1)
## (clipped to the world). Arrays are resized to the rectangle, row-major.
## `country` is the land country a renderer should draw the tile as.
## Reads only `win`, which must hold the rectangle and WINDOW round it.
func fill(x0: int, y0: int, x1: int, y1: int, out_country: PackedByteArray, out_country2: PackedByteArray, out_blend: PackedFloat32Array, win: TileWindow) -> void:
	var w := world
	var size := w.size
	var cw := x1 - x0
	var ch := y1 - y0
	out_country.resize(cw * ch)
	out_country2.resize(cw * ch)
	out_blend.resize(cw * ch)
	var pad := int(REACH) + SAMPLE * 2
	var gx0 := floori(float(x0 - pad) / SAMPLE)
	var gy0 := floori(float(y0 - pad) / SAMPLE)
	var gw := floori(float(x1 + pad) / SAMPLE) - gx0 + 1
	var gh := floori(float(y1 + pad) / SAMPLE) - gy0 + 1
	var n := gw * gh
	var own := PackedByteArray()
	own.resize(n)
	var any_sea := false
	for gy in gh:
		var ty := (gy0 + gy) * SAMPLE + SAMPLE / 2
		for gx in gw:
			var tx := (gx0 + gx) * SAMPLE + SAMPLE / 2
			var c: int = win.country[win.at(tx, ty)] if tx >= 0 and ty >= 0 and tx < size and ty < size else Country.SEA
			own[gy * gw + gx] = c
			any_sea = any_sea or c == Country.SEA
	# For the sea, the nearest land country (a two-pass chamfer on the samples).
	var land_d := PackedFloat32Array()
	land_d.resize(n)
	land_d.fill(1e6)
	var land := PackedByteArray()
	land.resize(n)
	if any_sea:
		for i in n:
			if own[i] != Country.SEA:
				land_d[i] = 0.0
				land[i] = own[i]
		for pass_i in 2:
			var sgn := 1 if pass_i == 0 else -1
			for yy in gh:
				var gy := yy if pass_i == 0 else gh - 1 - yy
				for xx in gw:
					var gx := xx if pass_i == 0 else gw - 1 - xx
					var i := gy * gw + gx
					for k in 4:
						var nx := gx + _SCAN_DX[k] * sgn
						var ny := gy + _SCAN_DY[k] * sgn
						if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
							continue
						var q := ny * gw + nx
						var cost := 1.0 if k != 1 and k != 3 else 1.4142
						if land_d[q] + cost < land_d[i]:
							land_d[i] = land_d[q] + cost
							land[i] = land[q]
	for y in range(y0, y1):
		var v := clampf((y + 0.5) / SAMPLE - gy0 - 0.5, 0.0, gh - 1.001)
		var iv := floori(v)
		var fv := v - iv
		for x in range(x0, x1):
			var o := (y - y0) * cw + (x - x0)
			var inside := w.in_bounds(x, y)
			var i := win.at(clampi(x, 0, size - 1), clampi(y, 0, size - 1))
			var c := win.country[i] if inside else Country.SEA
			if c == Country.SEA:
				var u := clampf((x + 0.5) / SAMPLE - gx0 - 0.5, 0.0, gw - 1.001)
				var iu := floori(u)
				var near := iv * gw + iu + (1 if u - iu > 0.5 else 0) + (gw if fv > 0.5 else 0)
				c = land[near] if land[near] != Country.SEA else Country.COAST
				if inside and win.country2[i] != Country.SEA and win.blend[i] > 0.0:
					c = win.country2[i]
				out_country[o] = c
				out_country2[o] = c
				out_blend[o] = 0.0
				continue
			out_country[o] = c
			out_country2[o] = win.country2[i]
			out_blend[o] = reach(win.blend[i], GEN_FLOOR)


## A blend pulled in to the band: `floor` and below is heartland (0), the
## border stays 0.5.
static func reach(b: float, floor_value: float) -> float:
	return clampf((b - floor_value) / (0.5 - floor_value), 0.0, 1.0) * 0.5
