class_name WorldGen
## seed -> WorldData. Deterministic, no side effects, no nodes.
##
## Stages (each reads only what earlier stages wrote):
##   1. elevation  continent mask + fbm + ridges, sea on every edge, terraced to levels
##   2. climate    temperature (north cold, south hot, height cools) and moisture
##   3. countries  jittered regions typed by the climate at their heart; every
##                 land country is guaranteed at least one region
##   4. ground     from country + level + detail noise; sand where land meets sea
##   5. villages   flat, dry, near the sea; the first Coast village is the spawn
##   6. props      hashed per-tile scatter, density by country and ground

const DEFAULT_SIZE := 256
const MAX_LEVEL := 12

const VILLAGE_NAMES: PackedStringArray = [
	"Saltings", "Hythe", "Cold Harbour", "Wick", "Stair", "Fleet", "Gunhill",
	"Shingle Row", "Marram", "Brack", "Holloway", "Sluice End",
]


static func generate(seed_value: int, size: int = DEFAULT_SIZE) -> WorldData:
	var w := WorldData.new(seed_value, size)
	var height := _elevation(w)
	_climate(w, height)
	_countries(w)
	_grounds(w)
	_villages(w)
	_props(w)
	return w


static func _noise(seed_value: int, salt: int, freq: float, octaves: int, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = Rng.hash_ints(seed_value, salt) & 0x7FFFFFFF
	n.noise_type = kind
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n


static func _elevation(w: WorldData) -> PackedFloat32Array:
	var size := w.size
	var base := _noise(w.seed_value, 1, 1.0 / 60.0, 5)
	var warp := _noise(w.seed_value, 2, 1.0 / 96.0, 3)
	var ridge := _noise(w.seed_value, 3, 1.0 / 87.0, 1)
	var height := PackedFloat32Array()
	height.resize(size * size)
	var half := size * 0.5
	for y in size:
		for x in size:
			var wx := x + warp.get_noise_2d(x, y) * 22.0
			var wy := y + warp.get_noise_2d(x + 400.0, y + 400.0) * 22.0
			var ex := minf(wx, size - 1 - wx) / half
			var ey := minf(wy, size - 1 - wy) / half
			var edge := clampf(minf(ex, ey), 0.0, 1.0)
			var continent := smoothstep(0.08, 0.55, edge)
			var h := 0.5 * continent + 0.42 * base.get_noise_2d(wx, wy)
			var r := 1.0 - absf(ridge.get_noise_2d(wx, wy))
			h += 0.35 * pow(r, 4.0) * smoothstep(0.35, 0.7, h)
			h -= 0.55 * (1.0 - continent)
			height[y * size + x] = h
	for i in height.size():
		var h := height[i]
		var l: int
		if h < 0.08:
			l = -1
		elif h < 0.18:
			l = 0
		else:
			var t := clampf((h - 0.18) / 0.72, 0.0, 1.0)
			l = mini(1 + floori(pow(t, 1.35) * MAX_LEVEL), MAX_LEVEL)
		w.level[i] = l
	_smooth_lonely_steps(w)
	return height


## Single-tile spikes and pits read as noise, not land.
static func _smooth_lonely_steps(w: WorldData) -> void:
	var size := w.size
	for _pass in 2:
		for y in range(1, size - 1):
			for x in range(1, size - 1):
				var i := y * size + x
				var l := w.level[i]
				var a := w.level[i - 1]
				var b := w.level[i + 1]
				var c := w.level[i - size]
				var d := w.level[i + size]
				if (a > l and b > l and c > l and d > l) or (a < l and b < l and c < l and d < l):
					w.level[i] = roundi((a + b + c + d) / 4.0)


static func _climate(w: WorldData, height: PackedFloat32Array) -> void:
	var size := w.size
	var tn := _noise(w.seed_value, 5, 1.0 / 80.0, 4)
	var mn := _noise(w.seed_value, 6, 1.0 / 80.0, 4)
	var sea := distance_to_sea(w)
	for y in size:
		var lat := float(y) / (size - 1)
		for x in size:
			var i := y * size + x
			var t := lat * 0.9 + 0.05 + tn.get_noise_2d(x, y) * 0.3 - maxf(0.0, height[i] - 0.45) * 0.6
			var coastal := 1.0 - smoothstep(0.0, 28.0, sea[i])
			var m := 0.45 + mn.get_noise_2d(x, y) * 0.55 + coastal * 0.2
			w.temperature[i] = clampf(t, 0.0, 1.0)
			w.moisture[i] = clampf(m, 0.0, 1.0)


## Chamfer distance in tiles from each tile to the nearest tile at level <= 0.
static func distance_to_sea(w: WorldData) -> PackedFloat32Array:
	var solid := PackedByteArray()
	solid.resize(w.size * w.size)
	for i in solid.size():
		solid[i] = 1 if w.level[i] <= 0 else 0
	return distance_field(solid, w.size)


## Chamfer distance to the nearest cell where mask == 1.
static func distance_field(mask: PackedByteArray, size: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(size * size)
	for i in d.size():
		d[i] = 0.0 if mask[i] == 1 else 1e9
	for y in size:
		for x in size:
			var i := y * size + x
			var v := d[i]
			if x > 0:
				v = minf(v, d[i - 1] + 1.0)
			if y > 0:
				v = minf(v, d[i - size] + 1.0)
			d[i] = v
	for y in range(size - 1, -1, -1):
		for x in range(size - 1, -1, -1):
			var i := y * size + x
			var v := d[i]
			if x < size - 1:
				v = minf(v, d[i + 1] + 1.0)
			if y < size - 1:
				v = minf(v, d[i + size] + 1.0)
			d[i] = v
	return d


## How well a climate suits a country. Higher is better.
static func suit(c: int, t: float, m: float, l: int) -> float:
	match c:
		Country.SNOWFIELD:
			return (1.0 - t) * 2.0 - 0.5 + l * 0.03
		Country.BURNING:
			return t * 1.6 + (1.0 - m) * 0.8 - 1.0
		Country.BONELANDS:
			return (1.0 - m) * 1.8 - 0.7 + l * 0.02
		Country.MOSS:
			return m * 1.8 - 0.6 - l * 0.08
		Country.PINEWOOD:
			return (1.0 - absf(t - 0.35) * 2.5) * 0.8 + m * 0.6 - 0.2
		Country.COAST:
			return 0.55 - absf(t - 0.55) - absf(m - 0.5) * 0.5 - l * 0.04
	return -99.0


static func _countries(w: WorldData) -> void:
	var size := w.size
	var rng := Rng.make(w.seed_value, 13)
	var cell := maxi(24, size / 6)
	var rx: Array[int] = []
	var ry: Array[int] = []
	var rc: Array[int] = []
	for gy in range(0, size, cell):
		for gx in range(0, size, cell):
			var x := clampi(gx + floori(rng.randf_range(0.15, 0.85) * cell), 0, size - 1)
			var y := clampi(gy + floori(rng.randf_range(0.15, 0.85) * cell), 0, size - 1)
			if w.level[y * size + x] <= 0:
				continue
			rx.append(x)
			ry.append(y)
			rc.append(_best_country(w, y * size + x))
	# Guarantee every land country: take the best-suited region from a country
	# that holds more than one.
	for c: int in Country.LAND:
		if rc.has(c):
			continue
		var pick := -1
		var pick_score := -INF
		for r in rc.size():
			if rc.count(rc[r]) < 2:
				continue
			var i := ry[r] * size + rx[r]
			var sc := suit(c, w.temperature[i], w.moisture[i], w.level[i])
			if sc > pick_score:
				pick_score = sc
				pick = r
		if pick >= 0:
			rc[pick] = c
	# Tiles take the nearest region, with warped borders. Computed on a 2-tile
	# lattice and filled: borders are warped anyway, and it halves the cost.
	var warp := _noise(w.seed_value, 14, 1.0 / 40.0, 3)
	var n := rc.size()
	for y in range(0, size, 2):
		for x in range(0, size, 2):
			var wx := x + warp.get_noise_2d(x, y) * 14.0
			var wy := y + warp.get_noise_2d(x + 910.0, y + 910.0) * 14.0
			var best := Country.COAST
			var best_d := INF
			for r in n:
				var dx := rx[r] - wx
				var dy := ry[r] - wy
				var dd := dx * dx + dy * dy
				if dd < best_d:
					best_d = dd
					best = rc[r]
			for oy in 2:
				for ox in 2:
					var tx := x + ox
					var ty := y + oy
					if tx < size and ty < size:
						var i := ty * size + tx
						w.country[i] = Country.SEA if w.level[i] <= 0 else best


static func _best_country(w: WorldData, i: int) -> int:
	var best := Country.COAST
	var best_score := -INF
	for c: int in Country.LAND:
		var sc := suit(c, w.temperature[i], w.moisture[i], w.level[i])
		if sc > best_score:
			best_score = sc
			best = c
	return best


static func _grounds(w: WorldData) -> void:
	var size := w.size
	var detail := _noise(w.seed_value, 17, 1.0 / 12.0, 3)
	var sea := distance_to_sea(w)
	for y in size:
		for x in size:
			var i := y * size + x
			var l := w.level[i]
			if l < 0:
				w.ground[i] = Ground.DEEP_WATER
				continue
			if l == 0:
				w.ground[i] = Ground.WATER
				continue
			var d := detail.get_noise_2d(x, y)
			var c := w.country[i]
			var g := Ground.GRASS
			if l >= 9 and c != Country.SNOWFIELD:
				g = Ground.ROCK
			elif sea[i] <= 2.0 and l <= 2 and c != Country.SNOWFIELD:
				g = Ground.SAND
			else:
				match c:
					Country.COAST:
						g = Ground.SAND if d > 0.45 else Ground.GRASS
					Country.MOSS:
						g = Ground.MUD if d > 0.2 else Ground.MOSS
					Country.PINEWOOD:
						g = Ground.GRASS if d > 0.35 else Ground.NEEDLES
					Country.SNOWFIELD:
						g = Ground.ROCK if d > 0.5 else Ground.SNOW
					Country.BONELANDS:
						g = Ground.ROCK if d > 0.3 else Ground.BONE
					Country.BURNING:
						g = Ground.ROCK if d > 0.4 else Ground.ASH
			w.ground[i] = g


static func _villages(w: WorldData) -> void:
	var size := w.size
	var rng := Rng.make(w.seed_value, 19)
	var sea := distance_to_sea(w)
	var candidates: Array[Vector3] = [] # x, y, score
	for y in range(8, size - 8, 3):
		for x in range(8, size - 8, 3):
			var i := y * size + x
			var l := w.level[i]
			if l < 1 or l > 4 or sea[i] < 4.0 or sea[i] > 30.0:
				continue
			var flat := 0
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					if w.level[(y + dy) * size + x + dx] == l:
						flat += 1
			if flat < 70:
				continue
			candidates.append(Vector3(x, y, flat - sea[i] * 0.5 + rng.randf() * 4.0))
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z)
	var names := Rng.shuffle(rng, Array(VILLAGE_NAMES))
	for c in candidates:
		if w.villages.size() >= 6:
			break
		var p := Vector2(c.x + 0.5, c.y + 0.5)
		var too_close := false
		for v in w.villages:
			if (v.pos as Vector2).distance_squared_to(p) < 40.0 * 40.0:
				too_close = true
				break
		if too_close:
			continue
		w.villages.append({
			"pos": p,
			"country": w.country_at(int(c.x), int(c.y)),
			"name": names[w.villages.size() % names.size()],
		})
	var start: Dictionary = {}
	for v in w.villages:
		if v.country == Country.COAST:
			start = v
			break
	if start.is_empty() and not w.villages.is_empty():
		start = w.villages[0]
	if start.is_empty():
		w.spawn = _find_land(w, Vector2(size * 0.5, size * 0.5))
	else:
		w.spawn = (start.pos as Vector2) + Vector2(3, 3)
	for v in w.villages:
		var vx := floori(v.pos.x)
		var vy := floori(v.pos.y)
		for d in range(-7, 8):
			_set_if_land(w, vx + d, vy, Ground.ROAD)
			_set_if_land(w, vx, vy + d, Ground.ROAD)


static func _set_if_land(w: WorldData, x: int, y: int, g: int) -> void:
	if w.in_bounds(x, y) and w.level[y * w.size + x] > 0:
		w.ground[y * w.size + x] = g


static func _find_land(w: WorldData, c: Vector2) -> Vector2:
	for r in w.size:
		for a in 16:
			var p := c + Vector2.from_angle(a / 16.0 * TAU) * r
			var l := w.level_at(floori(p.x), floori(p.y))
			if l > 0 and l < 6:
				return p.floor() + Vector2(0.5, 0.5)
	return c


static func _props(w: WorldData) -> void:
	var size := w.size
	var s := w.seed_value
	var clump := _noise(s, 23, 1.0 / 18.0, 3)
	var village_points: Array[Vector2] = []
	for v in w.villages:
		village_points.append(v.pos)
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var i := y * size + x
			if w.level[i] <= 0:
				continue
			var g := w.ground[i]
			if g == Ground.ROAD:
				continue
			var tile := Vector2(x, y)
			var near_village := false
			for vp in village_points:
				if vp.distance_squared_to(tile) < 121.0:
					near_village = true
					break
			if near_village:
				continue
			var c := w.country[i]
			var r := Rng.hash01(s, x, y, 1)
			var p := Vector2(x + 0.2 + Rng.hash01(s, x, y, 2) * 0.6, y + 0.2 + Rng.hash01(s, x, y, 3) * 0.6)
			var k := maxf(0.0, clump.get_noise_2d(x, y))
			if g == Ground.ROCK:
				if r < 0.02:
					_add_prop(w, PropKind.STONE_ORE, p)
				elif r < 0.028:
					_add_prop(w, PropKind.COPPER_ORE if c == Country.BONELANDS else PropKind.IRON_ORE, p)
				elif r < 0.06:
					_add_prop(w, PropKind.BOULDER, p)
				continue
			match c:
				Country.PINEWOOD:
					if r < 0.1 + k * 0.35:
						_add_prop(w, PropKind.PINE, p)
					elif r < 0.14:
						_add_prop(w, PropKind.BUSH, p)
				Country.COAST:
					if g == Ground.SAND:
						if r < 0.006:
							_add_prop(w, PropKind.BOULDER, p)
					elif r < 0.015 + k * 0.12:
						_add_prop(w, PropKind.BROADLEAF, p)
					elif r < 0.05:
						_add_prop(w, PropKind.BUSH, p)
				Country.MOSS:
					if r < 0.08 + k * 0.1:
						_add_prop(w, PropKind.REEDS, p)
					elif r < 0.1:
						_add_prop(w, PropKind.DEAD_TREE, p)
				Country.SNOWFIELD:
					if r < 0.03 + k * 0.1:
						_add_prop(w, PropKind.PINE, p)
					elif r < 0.045:
						_add_prop(w, PropKind.BOULDER, p)
				Country.BONELANDS:
					if r < 0.012:
						_add_prop(w, PropKind.BONES, p)
					elif r < 0.03:
						_add_prop(w, PropKind.BOULDER, p)
					elif r < 0.034:
						_add_prop(w, PropKind.STONE_ORE, p)
				Country.BURNING:
					if r < 0.03:
						_add_prop(w, PropKind.DEAD_TREE, p)
					elif r < 0.04:
						_add_prop(w, PropKind.BOULDER, p)
	var rng := Rng.make(s, 29)
	for v in w.villages:
		var vp: Vector2 = v.pos
		_add_prop(w, PropKind.LAMP, vp + Vector2(1.2, 1.2))
		var count := rng.randi_range(4, 7)
		for h in count:
			var a := float(h) / count * TAU + rng.randf_range(-0.2, 0.2)
			var hp := vp + Vector2.from_angle(a) * rng.randf_range(5.0, 8.0)
			if w.level_at(floori(hp.x), floori(hp.y)) <= 0:
				continue
			var prop := _add_prop(w, PropKind.HOUSE, hp)
			# Houses face the square, snapped to a quarter turn.
			prop.rot = roundf((vp - hp).angle() / (PI / 2.0)) * (PI / 2.0)


static func _add_prop(w: WorldData, kind: int, p: Vector2) -> WorldProp:
	var id := w.props.size()
	var s := w.seed_value
	var prop := WorldProp.new(id, kind, p, Rng.hash01(s, id, 77) * TAU, 0.75 + Rng.hash01(s, id, 78) * 0.5)
	w.props.append(prop)
	return prop
