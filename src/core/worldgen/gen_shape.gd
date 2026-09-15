class_name GenShape
## Stage 1: the island. One landmass with a sea rim on every edge, a coastline
## of bays, headlands and the odd skerry, and no enclosed seas. Worked at half
## resolution (the coastline is smooth at that scale) and spread to tiles.

## Share of the whole square that is land.
const LAND_SHARE := 0.54
## Islets smaller than this many tiles survive as skerries; bigger detached
## land is sunk so every country is on the one walkable island.
const ISLET_TILES := 220


static func run(c: GenContext) -> void:
	var size := c.size
	var s := c.s
	var hs := 2
	var hw := GenFields.coarse_width(size, hs)
	var hn := hw * hw
	var continent := GenFields.noise(s, 101, 1.0 / (170.0 * c.k), 4)
	var bays := GenFields.noise(s, 105, 1.0 / (64.0 * maxf(c.k, 0.5)), 2)
	var coastline := GenFields.noise(s, 102, 1.0 / 22.0, 3)
	var warp := GenFields.noise(s, 103, 1.0 / (240.0 * c.k), 2)
	var lf := PackedFloat32Array()
	lf.resize(hn)
	var inner := PackedByteArray()
	inner.resize(hn)
	var inner_count := 0
	for gy in hw:
		var ty := GenFields.cell_centre(gy, hs)
		var v := ty / size
		for gx in hw:
			var tx := GenFields.cell_centre(gx, hs)
			var u := tx / size
			var i := gy * hw + gx
			var hard := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			if hard < 0.05:
				lf[i] = -1.0
				continue
			var wu := u + warp.get_noise_2d(tx, ty) * 0.08
			var wv := v + warp.get_noise_2d(tx + 731.0, ty - 419.0) * 0.08
			var e := minf(minf(wu, 1.0 - wu), minf(wv, 1.0 - wv))
			# Rounded: a corner is further from land than an edge midpoint.
			var cu := absf(wu - 0.5) * 2.0
			var cv := absf(wv - 0.5) * 2.0
			var corner := maxf(0.0, cu * cv - 0.35)
			var h := smoothstep(0.03, 0.26, e) - corner * 0.9 - 0.5
			# Bays and headlands bite hardest near the rim, where the coast is.
			var rimness := 1.0 - smoothstep(0.1, 0.3, e)
			h += continent.get_noise_2d(tx, ty) * 0.36 + bays.get_noise_2d(tx, ty) * (0.1 + 0.2 * rimness) + coastline.get_noise_2d(tx, ty) * 0.08
			lf[i] = h
			inner[i] = 1
			inner_count += 1
	c.mark(&"shape.noise")
	var want := clampf(1.0 - LAND_SHARE * hn / maxf(1.0, inner_count), 0.05, 0.95)
	var thr := GenFields.quantile(lf, inner, want, -1.5, 1.5)
	var land_h := PackedByteArray()
	land_h.resize(hn)
	for i in hn:
		lf[i] -= thr
		land_h[i] = 1 if lf[i] > 0.0 else 0
	c.mark(&"shape.quantile")
	_clean(lf, land_h, hw)
	c.mark(&"shape.clean")
	# Tiles: bilinear, then a whisper of fine noise right at the waterline so
	# rock shores crinkle and throw the odd skerry.
	var full := GenFields.upsample(lf, hw, hs, size)
	var fine := GenFields.noise(s, 104, 1.0 / 7.0, 2)
	var land := PackedByteArray()
	land.resize(c.n)
	var min_x := size
	var min_y := size
	var max_x := 0
	var max_y := 0
	for y in range(3, size - 3):
		var row := y * size
		for x in range(3, size - 3):
			var h := full[row + x]
			if h < -0.03:
				continue
			if h < 0.03:
				h += fine.get_noise_2d(x, y) * 0.022
				if h <= 0.0:
					continue
			land[row + x] = 1
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	c.land = land
	c.land_rect = Rect2(min_x, min_y, maxi(1, max_x - min_x), maxi(1, max_y - min_y))
	c.mark(&"shape.tiles")
	# Distances at half resolution are plenty for ramps and profiles.
	var sea_h := PackedByteArray()
	sea_h.resize(hn)
	for i in hn:
		sea_h[i] = 1 - land_h[i]
	var inland_h := GenFields.distance8(sea_h, hw, 999.0)
	var offshore_h := GenFields.distance8(land_h, hw, 999.0)
	for i in hn:
		inland_h[i] = inland_h[i] * hs - 1.0
		offshore_h[i] = offshore_h[i] * hs - 1.0
	c.inland = GenFields.upsample(inland_h, hw, hs, size)
	c.offshore = GenFields.upsample(offshore_h, hw, hs, size)
	c.mark(&"shape.distance")
	c.convex = GenFields.neighbourhood_share(land, size, 4)
	c.mark(&"shape.convex")


## Fill enclosed seas; sink detached land bigger than an islet.
static func _clean(lf: PackedFloat32Array, land_h: PackedByteArray, hw: int) -> void:
	var hn := hw * hw
	var sea := PackedByteArray()
	sea.resize(hn)
	for i in hn:
		sea[i] = 1 - land_h[i]
	var sizes := PackedInt32Array()
	var labels := GenFields.components(sea, hw, sizes)
	var ocean := labels[0]
	for i in hn:
		if labels[i] >= 0 and labels[i] != ocean:
			land_h[i] = 1
			lf[i] = 0.04
	var lsizes := PackedInt32Array()
	var llabels := GenFields.components(land_h, hw, lsizes)
	var main := 0
	for id in lsizes.size():
		if lsizes[id] > lsizes[main]:
			main = id
	var islet_cells := ISLET_TILES / 4
	for i in hn:
		var id := llabels[i]
		if id >= 0 and id != main and lsizes[id] > islet_cells:
			land_h[i] = 0
			lf[i] = -0.04
