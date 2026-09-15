class_name GenScatter
## Stages 8 and 10: places worth walking to, then every prop.
##
## Sites (before grounds, since a tip lays its own gravel): tips of machine
## leavings in every country, stone circles, wrecks on bay beaches, ruins,
## cairns on summits, the caldera.
##
## Props (after grounds): villages first (square with lamp, fire and bench;
## houses facing in), then landmarks, then the machines' grid (pylon and pole
## lines striding dead straight across countries, spurs to villages), then the
## hashed per-tile scatter. Scatter density comes from the tile's country
## recipe; in an ecotone a tile rolls which country's recipe it follows
## against the blend, so woods thin into heath and reeds give out as the fen
## dries. Ore sits in rock by country, richest in the Bonelands, thickest at
## cliff feet where a face is exposed.


## Sites that shape grounds. Records landmarks.
static func sites(c: GenContext) -> void:
	var w := c.w
	var rng := Rng.make(c.s, 81)
	# Tips: scrap heaps in every country.
	var tips_per: PackedInt32Array = [0, 4, 2, 2, 2, 3, 2]
	for cc: int in Country.LAND:
		var want := maxi(1, roundi(tips_per[cc] * maxf(c.k, 0.4)))
		var placed := 0
		for attempt in 2500:
			if placed >= want:
				break
			var p := _random_tile(c, rng)
			var i := p.y * c.size + p.x
			if w.country[i] != cc or w.blend[i] > 0.42:
				continue
			if not _clear_site(c, p, 6, 2) or _near_landmark(w, Vector2(p), 36.0 * maxf(c.k, 0.5)) or _near_village(w, Vector2(p), 22.0):
				continue
			_lay_tip(c, p, rng.randf_range(4.0, 7.5))
			w.landmarks.append({"kind": &"tip", "pos": Vector2(p) + Vector2(0.5, 0.5), "country": cc})
			placed += 1
	# Stone circles on open flat ground, mostly in the Bonelands.
	var circles: PackedInt32Array = [0, 1, 0, 0, 0, 2, 0]
	for cc: int in Country.LAND:
		var placed := 0
		for attempt in 2500:
			if placed >= circles[cc]:
				break
			var p := _random_tile(c, rng)
			var i := p.y * c.size + p.x
			if w.country[i] != cc or w.blend[i] > 0.3:
				continue
			if not _clear_site(c, p, 5, 1) or _near_landmark(w, Vector2(p), 30.0) or _near_village(w, Vector2(p), 26.0):
				continue
			w.landmarks.append({"kind": &"stone_circle", "pos": Vector2(p) + Vector2(0.5, 0.5), "country": cc})
			placed += 1
	# Wrecks on beaches in bays.
	var wrecks := 0
	for attempt in 3000:
		if wrecks >= maxi(1, roundi(4 * maxf(c.k, 0.3))):
			break
		var p := _random_tile(c, rng)
		var i := p.y * c.size + p.x
		if c.land[i] == 0 or w.level[i] != 1 or c.convex[i] < 0.5 or c.inland[i] > 3.5 or c.water[i] != 0 or c.road[i] != 0:
			continue
		if w.country[i] == Country.BURNING or w.country[i] == Country.SNOWFIELD:
			continue
		if _near_landmark(w, Vector2(p), 50.0 * maxf(c.k, 0.4)) or _near_village(w, Vector2(p), 16.0):
			continue
		w.landmarks.append({"kind": &"wreck", "pos": Vector2(p) + Vector2(0.5, 0.5), "country": w.country[i]})
		wrecks += 1
	# Ruins in the green countries.
	var ruins := 0
	for attempt in 800:
		if ruins >= maxi(1, roundi(5 * maxf(c.k, 0.3))):
			break
		var p := _random_tile(c, rng)
		var i := p.y * c.size + p.x
		var cc := w.country[i]
		if cc != Country.COAST and cc != Country.PINEWOOD and cc != Country.MOSS:
			continue
		if not _clear_site(c, p, 3, 1) or _near_landmark(w, Vector2(p), 36.0) or _near_village(w, Vector2(p), 24.0):
			continue
		w.landmarks.append({"kind": &"ruin", "pos": Vector2(p) + Vector2(0.5, 0.5), "country": cc})
		ruins += 1
	# Summits: the highest walkable ground in each upland country gets a cairn.
	var best_at: Array[Vector2i] = []
	var best_l := PackedInt32Array()
	for cc in Country.COUNT:
		best_at.append(Vector2i(-1, -1))
		best_l.append(-1)
	var level := w.level
	for y in range(4, c.size - 4, 2):
		for x in range(4, c.size - 4, 2):
			var i := y * c.size + x
			var cc := w.country[i]
			var l := level[i]
			if l <= best_l[cc] or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0:
				continue
			if level[i + 1] == l and level[i - 1] == l and level[i + c.size] == l and level[i - c.size] == l:
				best_l[cc] = l
				best_at[cc] = Vector2i(x, y)
	for cc: int in [Country.SNOWFIELD, Country.BONELANDS, Country.PINEWOOD, Country.COAST]:
		if best_at[cc].x >= 0:
			w.landmarks.append({"kind": &"summit", "pos": Vector2(best_at[cc]) + Vector2(0.5, 0.5), "country": cc})
	# Falls: wherever a river's bed steps down a level.
	for r in c.rivers:
		for j in range(1, r.size()):
			var a := r[j - 1]
			var b := r[j]
			if w.level_at(floori(a.x), floori(a.y)) > w.level_at(floori(b.x), floori(b.y)):
				w.landmarks.append({"kind": &"falls", "pos": a, "country": w.country_at(floori(a.x), floori(a.y)), "dir": b - a})
	var heart := c.hearts[Country.BURNING]
	if heart.x >= 0.0:
		w.landmarks.append({"kind": &"caldera", "pos": heart, "country": w.country_at(int(heart.x), int(heart.y))})


static func _random_tile(c: GenContext, rng: RandomNumberGenerator) -> Vector2i:
	var r := c.land_rect
	return Vector2i(
		clampi(rng.randi_range(int(r.position.x), int(r.end.x)), 3, c.size - 4),
		clampi(rng.randi_range(int(r.position.y), int(r.end.y)), 3, c.size - 4))


## Dry, roadless, village-free, nearly flat ground within radius r.
static func _clear_site(c: GenContext, p: Vector2i, r: int, max_rise: int) -> bool:
	var w := c.w
	var i0 := p.y * c.size + p.x
	if c.land[i0] == 0:
		return false
	var l0 := w.level[i0]
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			var x := p.x + dx
			var y := p.y + dy
			if x < 2 or y < 2 or x >= c.size - 2 or y >= c.size - 2:
				return false
			var i := y * c.size + x
			if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or c.ramp[i] != 0:
				return false
			if absi(w.level[i] - l0) > max_rise:
				return false
	return true


static func _near_landmark(w: WorldData, p: Vector2, d: float) -> bool:
	for m in w.landmarks:
		if (m.pos as Vector2).distance_squared_to(p) < d * d:
			return true
	return false


static func _near_village(w: WorldData, p: Vector2, d: float) -> bool:
	for v in w.villages:
		if (v.pos as Vector2).distance_squared_to(p) < d * d:
			return true
	return false


static func _lay_tip(c: GenContext, p: Vector2i, r: float) -> void:
	var cc := c.w.country[p.y * c.size + p.x]
	var ground := Ground.CLINKER if cc == Country.BURNING else Ground.GRAVEL
	var ri := ceili(r) + 2
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := p.x + dx
			var y := p.y + dy
			if x < 1 or y < 1 or x >= c.size - 1 or y >= c.size - 1:
				continue
			var i := y * c.size + x
			if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0:
				continue
			var ang := atan2(dy, dx)
			var edge := r * (0.8 + 0.25 * sin(ang * 3.0 + p.x) + 0.12 * sin(ang * 5.0 + p.y))
			if dx * dx + dy * dy <= edge * edge:
				c.site_ground[i] = ground + 1


static func props(c: GenContext) -> void:
	var occ := PackedByteArray()
	occ.resize(c.n)
	_villages(c, occ)
	_landmarks(c, occ)
	c.mark(&"props.places")
	_lines(c, occ)
	c.mark(&"props.lines")
	_scatter(c, occ)
	c.mark(&"props.scatter")


static func _add(c: GenContext, kind: int, p: Vector2, rot: float = -1.0) -> WorldProp:
	var w := c.w
	var id := w.props.size()
	var r := rot if rot >= 0.0 else GenFields.h01(c.s, id, kind, 77) * TAU
	var prop := WorldProp.new(id, kind, p, r, 0.8 + GenFields.h01(c.s, id, kind, 78) * 0.4)
	w.props.append(prop)
	return prop


## Mark the tiles a big solid covers so nothing else grows through it.
static func _occupy(c: GenContext, occ: PackedByteArray, p: Vector2, r: float) -> void:
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if x >= 0 and y >= 0 and x < c.size and y < c.size:
				occ[y * c.size + x] = 1


static func _free(c: GenContext, occ: PackedByteArray, p: Vector2, r: float) -> bool:
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if x < 1 or y < 1 or x >= c.size - 1 or y >= c.size - 1:
				return false
			var i := y * c.size + x
			if occ[i] != 0 or c.road[i] != 0 or c.land[i] == 0 or c.water[i] != 0:
				return false
	return true


static func _villages(c: GenContext, occ: PackedByteArray) -> void:
	var w := c.w
	var rng := Rng.make(c.s, 29)
	for v in w.villages:
		var vp: Vector2 = v.pos
		# The square. (3, 3) from the centre stays clear: --village=N starts there.
		var fire := _add(c, PropKind.FIRE, vp + Vector2(-0.4, -1.6))
		var bench := _add(c, PropKind.BENCH, vp + Vector2(-2.3, -2.6))
		bench.rot = (fire.pos - bench.pos).angle()
		_add(c, PropKind.LAMP, vp + Vector2(1.9, -2.1))
		_occupy(c, occ, vp, 2.5)
		var count := rng.randi_range(5, 8)
		var placed := 0
		var start := rng.randf() * TAU
		for h in 120:
			if placed >= count:
				break
			var a := start + h * 2.39996
			if absf(wrapf(a - PI * 0.25, -PI, PI)) < 0.4:
				continue
			# Inner ring first, spreading out as the good spots are taken.
			var rad := 5.8 + fmod(h * 0.618, 1.0) * 2.8 + h * 0.035
			var hp := vp + Vector2.from_angle(a) * rad
			hp = hp.floor() + Vector2(0.5, 0.5)
			# The player wakes with room around them and the view ahead open.
			var to_spawn := hp - w.spawn
			if to_spawn.length() < 4.5 or (to_spawn.length() < 9.0 and to_spawn.normalized().dot(Vector2.from_angle(w.spawn_facing)) > 0.5):
				continue
			if not _free(c, occ, hp, 1.0):
				continue
			var l := w.level_at(floori(hp.x), floori(hp.y))
			var level_ok := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if w.level_at(floori(hp.x) + dx, floori(hp.y) + dy) != l:
						level_ok = false
			if not level_ok:
				continue
			var house := _add(c, PropKind.HOUSE, hp)
			# Facing the square, never quite square to it.
			house.rot = wrapf((vp - hp).angle() + rng.randf_range(-0.2, 0.2), 0.0, TAU)
			_occupy(c, occ, hp, 2.0)
			placed += 1


static func _landmarks(c: GenContext, occ: PackedByteArray) -> void:
	var w := c.w
	var rng := Rng.make(c.s, 83)
	for m in w.landmarks:
		var p: Vector2 = m.pos
		match m.kind:
			&"tip":
				var heaps := rng.randi_range(3, 6)
				for h in heaps:
					var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 4.0)
					q = q.floor() + Vector2(0.5, 0.5)
					if _free(c, occ, q, 1.0):
						_add(c, PropKind.TIP, q + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)))
						_occupy(c, occ, q, 1.0)
				if rng.randf() < 0.5 and _free(c, occ, p + Vector2(3, -2), 1.3):
					_add(c, PropKind.WRECK, p + Vector2(3, -2))
					_occupy(c, occ, p + Vector2(3, -2), 1.5)
			&"stone_circle":
				var stones := rng.randi_range(7, 9)
				var radius := rng.randf_range(3.2, 4.2)
				for k in stones:
					var q := p + Vector2.from_angle(float(k) / stones * TAU + rng.randf_range(-0.12, 0.12)) * radius
					if _free(c, occ, q, 0.0):
						var st := _add(c, PropKind.STANDING_STONE, q)
						st.rot = (p - q).angle()
						_occupy(c, occ, q, 0.6)
				if rng.randf() < 0.6:
					_add(c, PropKind.CAIRN, p)
				_occupy(c, occ, p, 1.0)
			&"wreck":
				if _free(c, occ, p, 1.0):
					var wr := _add(c, PropKind.WRECK, p)
					wr.rot = rng.randf() * TAU
					_occupy(c, occ, p, 1.6)
				for k in 4:
					var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 4.5)
					if _free(c, occ, q, 0.0):
						_add(c, PropKind.DRIFTWOOD, q)
			&"ruin":
				var walls := rng.randi_range(2, 4)
				for k in walls:
					var q := p + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
					if _free(c, occ, q, 0.6):
						_add(c, PropKind.RUIN, q.floor() + Vector2(0.5, 0.5), roundf(rng.randf() * 4.0) * PI * 0.5)
						_occupy(c, occ, q, 0.8)
			&"summit":
				if _free(c, occ, p, 0.0):
					_add(c, PropKind.CAIRN, p)
					_occupy(c, occ, p, 1.0)
	# Kilns: on dune sand near the coast villages, on pavement near the Bonelands'.
	for v in w.villages:
		var cc: int = v.country
		if cc != Country.COAST and cc != Country.BONELANDS:
			continue
		var want := Ground.SAND if cc == Country.COAST else Ground.LIMESTONE
		var vp: Vector2 = v.pos
		var done := false
		for rad in range(11, 26, 2):
			if done:
				break
			for a in 12:
				var q := (vp + Vector2.from_angle(a / 12.0 * TAU + rad) * rad).floor() + Vector2(0.5, 0.5)
				if w.ground_at(floori(q.x), floori(q.y)) == want and _free(c, occ, q, 1.0):
					_add(c, PropKind.KILN, q)
					_occupy(c, occ, q, 1.2)
					done = true
					break


static func _lines(c: GenContext, occ: PackedByteArray) -> void:
	var w := c.w
	var rng := Rng.make(c.s, 91)
	var size := float(c.size)
	var centre := c.land_rect.get_center()
	# Two pylon lines crossing the island, two pole lines, then spurs.
	# Offsets (fractions of the island's half-diagonal) sit in separate bands so
	# the lines stride across different country rather than meeting in a star.
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var specs: Array[Vector3] = [
		Vector3(PropKind.PYLON, PI * 0.5 + rng.randf_range(-0.35, 0.35), side * rng.randf_range(0.12, 0.3)),
		Vector3(PropKind.PYLON, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.28, -0.08)),
		Vector3(PropKind.POLE, PI * 0.5 + rng.randf_range(-0.3, 0.3), -side * rng.randf_range(0.2, 0.4)),
		Vector3(PropKind.POLE, rng.randf_range(-0.3, 0.3), rng.randf_range(0.15, 0.32)),
	]
	for spec in specs:
		var kind := int(spec.x)
		var dir := Vector2.from_angle(spec.y)
		var nrm := Vector2(-dir.y, dir.x)
		var through := centre + nrm * spec.z * c.land_rect.size.length() * 0.5
		var a := through - dir * size * 1.5
		var b := through + dir * size * 1.5
		_string_line(c, occ, kind, a, b, 13.0 if kind == PropKind.PYLON else 7.0)
	# Every village with a line within reach gets a pole spur to its square.
	for v in w.villages:
		var vp: Vector2 = v.pos + Vector2(-3.5, 3.5)
		var best := Vector2.ZERO
		var best_d := 90.0 * maxf(c.k, 0.4)
		for line in w.lines:
			for id: int in line.props:
				var d := w.props[id].pos.distance_to(vp)
				if d < best_d and d > 8.0:
					best_d = d
					best = w.props[id].pos
		if best != Vector2.ZERO:
			_string_line(c, occ, PropKind.POLE, vp, best, 6.0)


## Walk a straight line, standing a mast every `spacing` tiles on dry land.
## A gap over water or through a village starts a new line record.
static func _string_line(c: GenContext, occ: PackedByteArray, kind: int, a: Vector2, b: Vector2, spacing: float) -> void:
	var w := c.w
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var ids := PackedInt32Array()
	var missed := 0
	var t := 0.0
	while t <= length:
		var p := a + dir * t
		t += spacing
		var tx := floori(p.x)
		var ty := floori(p.y)
		if tx < 2 or ty < 2 or tx >= c.size - 2 or ty >= c.size - 2:
			continue
		var placed := false
		# Nudge along the line up to a couple of tiles to find footing.
		for nudge: float in [0.0, 1.5, -1.5, 3.0]:
			var q := (p + dir * nudge).floor() + Vector2(0.5, 0.5)
			if q.x < 2.0 or q.y < 2.0 or q.x >= c.size - 2 or q.y >= c.size - 2:
				continue
			var i := floori(q.y) * c.size + floori(q.x)
			if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or occ[i] != 0:
				continue
			var to_spawn := q - w.spawn
			if to_spawn.length_squared() < 16.0 or (to_spawn.length_squared() < 81.0 and to_spawn.normalized().dot(Vector2.from_angle(w.spawn_facing)) > 0.5):
				continue
			var prop := _add(c, kind, q)
			prop.rot = dir.angle()
			_occupy(c, occ, q, 0.0)
			ids.append(prop.id)
			placed = true
			break
		if placed:
			missed = 0
		else:
			missed += 1
			if missed >= 2 and ids.size() >= 2:
				w.lines.append({"kind": kind, "props": ids})
				ids = PackedInt32Array()
			elif missed >= 2:
				ids.clear()
	if ids.size() >= 2:
		w.lines.append({"kind": kind, "props": ids})


static func _scatter(c: GenContext, occ: PackedByteArray) -> void:
	var w := c.w
	var size := c.size
	var s := c.s & 0xFFFFFFFF
	var forest := c.forest
	var rise := c.rise
	var clump := GenFields.field(GenFields.noise(c.s, 611, 1.0 / 11.0, 2), size, 2)
	var fissure := GenFields.sample(GenFields.noise(c.s, 612, 1.0 / 26.0, 2), size, 1)
	var sp := w.spawn
	var face := Vector2.from_angle(w.spawn_facing)
	var land := c.land
	var water := c.water
	var road := c.road
	var village := c.village
	var ground := w.ground
	var level := w.level
	var country := w.country
	var country2 := w.country2
	var blend := w.blend
	var sea_steps := c.sea_steps
	# The highest roll any branch below can use on each ground: most rolls
	# are thrown away before any other work.
	var reach := PackedFloat32Array()
	reach.resize(Ground.COUNT)
	reach.fill(0.3)
	for g: int in [Ground.NEEDLES, Ground.LIMESTONE, Ground.MUD]:
		reach[g] = 0.5
	for g: int in [Ground.SNOW, Ground.GRASS, Ground.HEATH, Ground.CLINKER]:
		reach[g] = 0.4
	for g: int in [Ground.ASH, Ground.BONE, Ground.GRAVEL, Ground.SAND, Ground.SHINGLE]:
		reach[g] = 0.25
	var solid := PropKind.SOLID
	const COAST := Country.COAST
	const MOSS := Country.MOSS
	const PINEWOOD := Country.PINEWOOD
	const SNOWFIELD := Country.SNOWFIELD
	const BONELANDS := Country.BONELANDS
	const BURNING := Country.BURNING
	const G_SAND := Ground.SAND
	const G_GRASS := Ground.GRASS
	const G_MOSS := Ground.MOSS
	const G_MUD := Ground.MUD
	const G_NEEDLES := Ground.NEEDLES
	const G_SNOW := Ground.SNOW
	const G_BONE := Ground.BONE
	const G_ASH := Ground.ASH
	const G_ROCK := Ground.ROCK
	const G_HEATH := Ground.HEATH
	const G_SHINGLE := Ground.SHINGLE
	const G_GRAVEL := Ground.GRAVEL
	const G_SCREE := Ground.SCREE
	const G_LIMESTONE := Ground.LIMESTONE
	const G_CLINKER := Ground.CLINKER
	const G_PEAT := Ground.PEAT
	var band := 12
	var parts: Array[PackedFloat32Array] = []
	parts.resize(ceili(float(size) / band))
	# Candidates are found in parallel, one list per band, and added in row
	# order: prop ids come out the same however the bands were scheduled.
	GenFields.rows(size - 2, func(y0: int, y1: int) -> void:
		var found := PackedFloat32Array()
		for y in range(maxi(y0, 2), y1):
			var row := y * size
			for x in range(2, size - 2):
				var h := (x * 0x27d4eb2d + y * 0x165667b1 + s * 0x9e3779b1) & 0xFFFFFFFF
				h = ((h ^ (h >> 15)) * 0x2c1b3c6d) & 0xFFFFFFFF
				h = ((h ^ (h >> 12)) * 0x297a2d39) & 0xFFFFFFFF
				h ^= h >> 15
				var r := (h & 0xFFFF) / 65536.0
				var i := row + x
				var g := ground[i]
				if r > reach[g] or land[i] == 0 or water[i] != 0 or road[i] != 0 or village[i] != 0 or occ[i] != 0:
					continue
				var l := level[i]
				var cc := country[i]
				var bl := blend[i]
				if bl > 0.0 and ((h >> 16) & 0xFF) / 256.0 < bl:
					cc = country2[i]
				var up := maxi(maxi(level[i - 1], level[i + 1]), maxi(level[i - size], level[i + size])) - l
				var wa := water[i - 1]
				var wb := water[i + 1]
				var wc := water[i - size]
				var wd := water[i + size]
				var bank := wa == 1 or wb == 1 or wc == 1 or wd == 1
				var pool := wa == 2 or wb == 2 or wc == 2 or wd == 2
				var road_side := road[i - 1] != 0 or road[i + 1] != 0 or road[i - size] != 0 or road[i + size] != 0
				var ss := sea_steps[i]
				var kind := -1
				var k := 0.0
				if up >= 2 and (g == G_SCREE or g == G_ROCK or g == G_LIMESTONE or g == G_GRAVEL or g == G_SNOW or g == G_ASH):
					# An exposed face: ore shows at its foot.
					kind = _ore(cc, r * 2.2)
				elif bank or pool:
					if cc != BURNING and cc != SNOWFIELD and r < (0.3 if cc == MOSS else 0.14):
						kind = PropKind.REEDS
				elif g == G_SAND:
					if ss <= 2:
						# The strandline: wrack in drifts, driftwood along it.
						k = maxf(0.0, clump[i])
						kind = PropKind.WRACK if r < 0.02 + k * 0.08 else (PropKind.DRIFTWOOD if r < 0.035 + k * 0.08 else -1)
					elif r < 0.012:
						kind = PropKind.GORSE if cc == COAST else PropKind.BUSH
					elif r < 0.0135 and ss >= 3:
						kind = PropKind.KILN
				elif g == G_SHINGLE:
					if ss <= 1 and r < 0.07:
						kind = PropKind.MUSSEL_ROCK
					elif r < 0.1:
						kind = PropKind.WRACK
					elif r < 0.12:
						kind = PropKind.DRIFTWOOD
					elif r < 0.14:
						kind = PropKind.BOULDER
				elif g == G_GRASS:
					k = maxf(0.0, forest[i])
					if cc == COAST:
						# Copses in the sheltered folds, not on the tops.
						k *= clampf(1.0 - rise[i] * 0.6, 0.0, 1.3)
						if r < k * k * 1.1:
							kind = PropKind.BROADLEAF
						elif r < 0.02:
							kind = PropKind.BUSH
						elif r < 0.026:
							kind = PropKind.BOULDER
					elif cc == PINEWOOD:
						if r < 0.03 + k * 0.1:
							kind = PropKind.PINE
						elif r < 0.07:
							kind = PropKind.BUSH
					elif cc == BONELANDS:
						if r < 0.01:
							kind = PropKind.BONES
						elif r < 0.022:
							kind = PropKind.BOULDER
						elif r < 0.03:
							kind = PropKind.GORSE
					elif cc == SNOWFIELD:
						if r < 0.02:
							kind = PropKind.SNOW_PINE
					elif r < 0.02:
						kind = PropKind.BUSH
				elif g == G_HEATH:
					k = maxf(0.0, clump[i])
					if cc == COAST or cc == BONELANDS:
						if r < 0.02 + k * 0.26:
							kind = PropKind.GORSE
						elif r > 0.37 and r < 0.385:
							kind = PropKind.BOULDER
					elif cc == PINEWOOD:
						kind = PropKind.PINE if r < 0.03 else (PropKind.BUSH if r < 0.06 else -1)
					elif r < 0.04:
						kind = PropKind.BUSH
				elif g == G_NEEDLES:
					k = maxf(0.0, forest[i] + 0.12)
					if cc == SNOWFIELD:
						kind = PropKind.SNOW_PINE if r < 0.1 + k * 0.3 else -1
					elif r < 0.16 + k * 0.34:
						kind = PropKind.PINE
					elif r < 0.17 + k * 0.34:
						kind = PropKind.DEAD_TREE
					elif r < 0.2 + k * 0.34:
						kind = PropKind.BUSH
				elif g == G_MOSS:
					k = maxf(0.0, clump[i])
					if r < 0.03 + k * 0.08:
						kind = PropKind.REEDS
					elif r < 0.045 + k * 0.08:
						kind = PropKind.DEAD_TREE
					elif r < 0.055 + k * 0.08:
						kind = PropKind.BUSH
				elif g == G_MUD:
					if r < 0.1 + maxf(0.0, clump[i]) * 0.35:
						kind = PropKind.REEDS
					elif r > 0.49 and cc == MOSS:
						kind = PropKind.DEAD_TREE
				elif g == G_PEAT:
					# Banks are cut along the edge of a hag.
					var edge := ground[i - 1] != G_PEAT or ground[i + 1] != G_PEAT or ground[i - size] != G_PEAT or ground[i + size] != G_PEAT
					if edge and r < 0.16:
						kind = PropKind.PEAT_BANK
					elif r < 0.02:
						kind = PropKind.REEDS
				elif g == G_SNOW:
					k = maxf(0.0, forest[i] + 0.05)
					if l <= 9 and r < k * 0.5:
						kind = PropKind.SNOW_PINE
					elif r < 0.008 + k * 0.5:
						kind = PropKind.DEAD_TREE
					elif r < 0.016 + k * 0.5:
						kind = PropKind.BOULDER
				elif g == G_ROCK or g == G_SCREE:
					if r < 0.06:
						kind = PropKind.BOULDER
					else:
						kind = _ore(cc, r - 0.06)
				elif g == G_GRAVEL:
					if r < 0.018:
						kind = PropKind.BOULDER
					elif cc == BONELANDS:
						kind = _ore(cc, (r - 0.018) * 3.0)
				elif g == G_LIMESTONE:
					k = maxf(0.0, clump[i])
					if r < 0.04 + k * 0.22:
						kind = PropKind.CLINTS
					elif r > 0.3 and r < 0.302:
						kind = PropKind.STANDING_STONE
					elif r > 0.3985 and r < 0.4:
						kind = PropKind.KILN
					elif r > 0.44:
						# Seams show in the pavement's joints.
						kind = _ore(cc, (r - 0.44) * 1.6)
				elif g == G_BONE:
					if r < 0.02:
						kind = PropKind.BONES
					elif r < 0.03:
						kind = PropKind.BOULDER
				elif g == G_ASH:
					k = maxf(0.0, clump[i] - 0.15)
					if cc == BURNING:
						# Burnt groves stand together; between them, open ash.
						if r < 0.004 + k * 0.4:
							kind = PropKind.DEAD_TREE
						elif r < 0.012 + k * 0.4:
							kind = PropKind.BOULDER
						elif r < 0.016 + k * 0.4 and absf(fissure[i]) < 0.08:
							kind = PropKind.VENT
					elif r < 0.015:
						kind = PropKind.DEAD_TREE
				elif g == G_CLINKER:
					# Vents breathe in rows along the fissures.
					var f := absf(fissure[i])
					if f < 0.05 and r < 0.12:
						kind = PropKind.VENT
					elif r < 0.004:
						kind = PropKind.VENT
					elif r < 0.02:
						kind = PropKind.BOULDER
				if kind < 0:
					continue
				if road_side and solid[kind] > 0.0:
					continue
				var p := Vector2(x + 0.2 + ((h >> 24) & 0xFF) / 425.0, y + 0.2 + ((h >> 8) & 0xFF) / 425.0)
				if solid[kind] > 0.0:
					var to := p - sp
					if to.length_squared() < 9.0 or (to.length_squared() < 64.0 and to.normalized().dot(face) > 0.6):
						continue
				found.append(kind)
				found.append(p.x)
				found.append(p.y)
		parts[y0 / band] = found
	, band)
	for part in parts:
		for j in range(0, part.size(), 3):
			_add(c, int(part[j]), Vector2(part[j + 1], part[j + 2]))


## Ore by country, flattened: ORE_KIND[cc * 5 + j] shows when r < ORE_CUM[cc * 5 + j].
const ORE_KIND: PackedInt32Array = [
	-1, -1, -1, -1, -1,
	PropKind.STONE_ORE, PropKind.TIN_ORE, PropKind.IRON_ORE, -1, -1,
	PropKind.STONE_ORE, PropKind.COAL_ORE, -1, -1, -1,
	PropKind.STONE_ORE, PropKind.COAL_ORE, PropKind.IRON_ORE, -1, -1,
	PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.TIN_ORE, -1, -1,
	PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.TIN_ORE, PropKind.COAL_ORE,
	PropKind.STONE_ORE, PropKind.COAL_ORE, PropKind.COPPER_ORE, PropKind.IRON_ORE, -1,
]
const ORE_CUM: PackedFloat32Array = [
	0.0, 0.0, 0.0, 0.0, 0.0,
	0.035, 0.05, 0.055, 0.0, 0.0,
	0.02, 0.03, 0.0, 0.0, 0.0,
	0.035, 0.06, 0.07, 0.0, 0.0,
	0.014, 0.026, 0.034, 0.0, 0.0,
	0.05, 0.075, 0.1, 0.12, 0.135,
	0.02, 0.05, 0.068, 0.085, 0.0,
]


## Ore by country and rock, richest in the Bonelands. `r` in [0, 1): low
## values are the common kinds. -1 = bare rock.
static func _ore(cc: int, r: float) -> int:
	var base := cc * 5
	for j in 5:
		if r < ORE_CUM[base + j]:
			return ORE_KIND[base + j]
	return -1
