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

## World units of height that A spans (0..1): the highest land, and a unit
## over. sky.gdshaderinc's SKY_GROUND_HEIGHT must equal it.
const HEIGHT_RANGE := 16.0
## Halvings before the height is spread back out: 3 is an 8-tile neighbourhood
## (the map's own resolution, TILE, is the first of them).
const SMOOTH_HALVINGS := 3
## Tiles per texel, each way, of this map and SkyWear's. What they hold changes
## over an ecotone's twelve to twenty-four tiles and the height is smoothed over
## eight, so a texel per four tiles draws the same, and the sweep that makes it,
## the cost a raise hides (RealmWarm), is a quarter. The shaders read by world
## position over the world's size (`sky_view.z`), not by texel; a reader on the
## CPU asks `texel_of`.
const TILE := 2


## The texel of a map of this world that holds tile (x, y).
static func texel_of(x: int, y: int) -> Vector2i:
	return Vector2i(x / TILE, y / TILE)


## A map's side for a world of side n.
static func side(n: int) -> int:
	return maxi(1, (n + TILE - 1) / TILE)


## Per settled thing, 1 if any weather in the landscape type's climate feeds it
## at half strength or more: Vector3(snow, ash, wet).
static func capable(type_id: StringName) -> Vector3:
	var table := Weather.climate(type_id)
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
	# What each land id on the map can hold, read through the landscape type
	# BiomeRegistry finds there. Land ids cover wide regions, so a coarse pass
	# finds every one (an ecotone's neighbour is land of its own somewhere).
	var caps: Array[Vector3] = []
	caps.resize(256)
	caps.fill(capable(&""))
	var seen := PackedByteArray()
	seen.resize(256)
	for y in range(0, n, 4):
		for x in range(0, n, 4):
			var c := int(w.country[y * n + x])
			if seen[c] == 0:
				seen[c] = 1
				# Nothing the sky lets fall reaches a floor under a roof.
				caps[c] = Vector3.ZERO if w.realm == Realm.INTERIOR else capable(BiomeRegistry.at(w, Vector2(x, y)).id)
	var m := side(n)
	var heights := PackedByteArray()
	heights.resize(m * m)
	var rgba := PackedByteArray()
	rgba.resize(m * m * 4)
	var has_blend := w.blend.size() == n * n and w.country2.size() == n * n
	for ty in m:
		var row := mini(ty * TILE, n - 1) * n
		for tx in m:
			var i := row + mini(tx * TILE, n - 1)
			var cap := caps[int(w.country[i])]
			if has_blend and w.blend[i] > 0.0:
				cap = cap.lerp(caps[int(w.country2[i])], clampf(w.blend[i], 0.0, 1.0))
			var h := maxf(float(w.level[i]) * WorldData.STEP, TerrainMesher.WATER_Y)
			var t := ty * m + tx
			var o := t * 4
			rgba[o] = int(cap.x * 255.0)
			rgba[o + 1] = int(cap.y * 255.0)
			rgba[o + 2] = int(cap.z * 255.0)
			heights[t] = clampi(int(h / HEIGHT_RANGE * 255.0 + 0.5), 0, 255)
	# Box-average the heights by halving, then spread them back out smoothly:
	# all native, so a 256-tile world costs a few milliseconds. The map's own
	# resolution counts among the halvings.
	var hi := Image.create_from_data(m, m, false, Image.FORMAT_L8, heights)
	var s := m
	var least := maxi(1, n >> SMOOTH_HALVINGS)
	while s > least:
		s = maxi(least, s / 2)
		hi.resize(s, s, Image.INTERPOLATE_BILINEAR)
	hi.resize(m, m, Image.INTERPOLATE_CUBIC)
	var smooth := hi.get_data()
	for t in m * m:
		rgba[t * 4 + 3] = smooth[t]
	return Image.create_from_data(m, m, false, Image.FORMAT_RGBA8, rgba)


## PURE AND DERIVED, SO KEPT: one texture per world OBJECT (never per seed: a
## test grows one seed twice), so walking back out of a house onto the coast
## hands the coast's own back instead of sweeping the island again (4.6 s for
## the ground measured on seed 4, docs/interiors). Held by a weak reference to
## the world, so a world nobody holds any more takes its texture with it.
static var _kept: Dictionary = {}


## THE IMAGE, MADE BESIDE THE WORLD (RealmWarm, on the raise's worker): the sweep
## is the cost (1.2 s at 1840 on the way down a shaft) and the texture made from
## it is nothing, so a world raised for a crossing has its image waiting and the
## press only wraps it. Guarded, because the worker writes and the main reads.
static var _images: Dictionary = {}
static var _images_lock := Mutex.new()


static func prepare(w: WorldData) -> void:
	var img := image(w)
	_images_lock.lock()
	_images[w.get_instance_id()] = [weakref(w), img]
	_images_lock.unlock()


## The image `prepare` made for this world, taken (it is wanted once), or null.
static func _prepared(w: WorldData) -> Image:
	_images_lock.lock()
	var got: Array = _images.get(w.get_instance_id(), [])
	_images.erase(w.get_instance_id())
	_images_lock.unlock()
	if not got.is_empty() and (got[0] as WeakRef).get_ref() == w:
		return got[1]
	return null


static func texture(w: WorldData) -> ImageTexture:
	var id := w.get_instance_id()
	var got: Array = _kept.get(id, [])
	if not got.is_empty() and (got[0] as WeakRef).get_ref() == w:
		return got[1]
	for k: int in _kept.keys():
		if (_kept[k][0] as WeakRef).get_ref() == null:
			_kept.erase(k)
	var made := _prepared(w)
	var t := ImageTexture.create_from_image(made if made != null else image(w))
	_kept[id] = [weakref(w), t]
	return t
