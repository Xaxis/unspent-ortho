class_name SkyGround
## What each part of the land can hold under the sky, as one small texture the
## sky shader include reads by world position (global `sky_ground`):
##   R  snow can lie here     G  ash can lie here     B  wet can show here
##   A  the ground's height, smoothed over about eight tiles (/ HEIGHT_RANGE)
## Snow lies only on the countries that snow, ash only where ash falls, so at a
## border the snowfield's drifts never spill onto burning clinker. Countries
## meet on their ecotone blend, so a drift thins out across the border instead
## of stopping on a line. Fog reads A against a fragment's own height: a hollow
## is ground lower than its neighbourhood, and fog lies in it.

## World units of height that A spans (0..1).
const HEIGHT_RANGE := 8.0
## Halvings before the height is spread back out: 3 is an 8-tile neighbourhood.
const SMOOTH_HALVINGS := 3


## Per settled thing, 1 if any weather in the country's table feeds it at half
## strength or more: Vector3(snow, ash, wet).
static func capable(country: int) -> Vector3:
	var table: Array = Weather.TABLES[clampi(country, 0, Weather.TABLES.size() - 1)]
	var out := Vector3.ZERO
	var keys := ["snow", "ash", "wet"]
	for row: Array in table:
		for i in 3:
			var feed: Dictionary = (Weather.SETTLE[keys[i]] as Dictionary).feed
			if float(feed.get(row[0], 0.0)) >= 0.5:
				out[i] = 1.0
	return out


static func image(w: WorldData) -> Image:
	var n := w.size
	var caps: Array[Vector3] = []
	for c in Weather.TABLES.size():
		caps.append(capable(c))
	var heights := PackedByteArray()
	heights.resize(n * n)
	var rgba := PackedByteArray()
	rgba.resize(n * n * 4)
	var has_blend := w.blend.size() == n * n and w.country2.size() == n * n
	for i in n * n:
		var cap := caps[mini(int(w.country[i]), caps.size() - 1)]
		if has_blend and w.blend[i] > 0.0:
			cap = cap.lerp(caps[mini(int(w.country2[i]), caps.size() - 1)], clampf(w.blend[i], 0.0, 1.0))
		var h := maxf(float(w.level[i]) * WorldData.STEP, TerrainMesher.WATER_Y)
		var o := i * 4
		rgba[o] = int(cap.x * 255.0)
		rgba[o + 1] = int(cap.y * 255.0)
		rgba[o + 2] = int(cap.z * 255.0)
		heights[i] = clampi(int(h / HEIGHT_RANGE * 255.0 + 0.5), 0, 255)
	# Box-average the heights by halving, then spread them back out smoothly:
	# all native, so a 256-tile world costs a few milliseconds.
	var hi := Image.create_from_data(n, n, false, Image.FORMAT_L8, heights)
	var s := n
	for k in SMOOTH_HALVINGS:
		s = maxi(1, s / 2)
		hi.resize(s, s, Image.INTERPOLATE_BILINEAR)
	hi.resize(n, n, Image.INTERPOLATE_CUBIC)
	var smooth := hi.get_data()
	for i in n * n:
		rgba[i * 4 + 3] = smooth[i]
	return Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, rgba)


static func texture(w: WorldData) -> ImageTexture:
	return ImageTexture.create_from_image(image(w))
