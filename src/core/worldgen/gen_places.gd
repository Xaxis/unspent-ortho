class_name GenPlaces
## Named places in a generated world, for shots, tools and tests:
##   "spawn"                   where the player wakes
##   "moss"                    a standing tile deep inside a country
##   "coast-pinewood"          a standing tile on that ecotone, where both mix
##   "tip", "wreck2", ...      the Nth landmark of a kind (1-based, default 1)
##   "river"                   a bank beside the longest river's middle reach
##   "cliff"                   a tile at the foot of the tallest nearby face
## find() returns Vector2(-1, -1) when a world has no such place.


static func find(w: WorldData, name: String) -> Vector2:
	var key := name.to_lower().strip_edges()
	if key == "spawn":
		return w.spawn
	var ci := BiomeRegistry.index_of(StringName(key))
	if ci > 0:
		return country_sample(w, ci)
	for sep: String in ["-", "/", ">"]:
		if key.contains(sep):
			var parts := key.split(sep)
			var a := BiomeRegistry.index_of(StringName(parts[0]))
			var b := BiomeRegistry.index_of(StringName(parts[1]))
			if a > 0 and b > 0:
				return ecotone_sample(w, a, b)
	if key == "river":
		return river_sample(w)
	if key == "cliff":
		return cliff_sample(w)
	var digits := ""
	while key.length() > 0 and key.right(1).is_valid_int():
		digits = key.right(1) + digits
		key = key.left(key.length() - 1)
	var nth := maxi(1, digits.to_int()) if digits != "" else 1
	var want := nth
	for m in w.landmarks:
		if String(m.kind) == key:
			want -= 1
			if want == 0:
				return _stand_near(w, m.pos)
	return _placed_after(w, key, nth)


## Places that are laid AFTER the world is generated — the plan's depots
## (`Works`) and the landmarks worth the walk (`Landmarks`) — are put in
## `w.landmarks` by their own systems, which have not run when a shot resolves
## `--place`. Both are pure functions of the island, so they are asked directly
## rather than made a worldgen stage: adding a stage would move every seed.
static func _placed_after(w: WorldData, key: String, nth: int) -> Vector2:
	if key == "works":
		var works := Works.sites(w)
		return _stand_near(w, works[nth - 1].part(0)) if nth <= works.size() else Vector2(-1, -1)
	if Landmarks.by_id(StringName(key)) == null:
		return Vector2(-1, -1)
	var want := nth
	for s in Landmarks.sites(w):
		if String(s.kind) == key:
			want -= 1
			if want == 0:
				return _stand_near(w, Landmarks.cache_of(s))
	return Vector2(-1, -1)


## Tiles covered by solid props, for "somewhere to stand".
static func solid_mask(w: WorldData) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(w.size * w.size)
	for p in w.props:
		if p.solid <= 0.0:
			continue
		var r := ceili(p.solid)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := floori(p.pos.x) + dx
				var y := floori(p.pos.y) + dy
				if w.in_bounds(x, y):
					m[y * w.size + x] = 1
	return m


static func standable(w: WorldData, solid: PackedByteArray, x: int, y: int) -> bool:
	if x < 2 or y < 2 or x >= w.size - 2 or y >= w.size - 2:
		return false
	var i := y * w.size + x
	var g := w.ground[i]
	if Ground.is_water(g) or g == Ground.ROAD or w.level[i] < 1 or solid[i] != 0:
		return false
	var l := w.level[i]
	return absi(w.level[i - 1] - l) <= 1 and absi(w.level[i + 1] - l) <= 1 and absi(w.level[i - w.size] - l) <= 1 and absi(w.level[i + w.size] - l) <= 1


static func country_sample(w: WorldData, cc: int) -> Vector2:
	var solid := solid_mask(w)
	var best := Vector2(-1, -1)
	var best_score := -1.0
	for y in range(6, w.size - 6, 4):
		for x in range(6, w.size - 6, 4):
			var i := y * w.size + x
			if w.country[i] != cc or w.blend[i] > 0.0 or not standable(w, solid, x, y):
				continue
			var score := 0.0
			for r: int in [6, 12, 20, 30]:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					if w.country_at(x + d.x * r, y + d.y * r) == cc:
						score += 1.0
			score += Rng.hash01(w.seed_value, x, y, 7) * 0.5
			if score > best_score:
				best_score = score
				best = Vector2(x + 0.5, y + 0.5)
	return best


static func ecotone_sample(w: WorldData, a: int, b: int) -> Vector2:
	var solid := solid_mask(w)
	var best := Vector2(-1, -1)
	var best_score := 0.0
	for y in range(10, w.size - 10, 3):
		for x in range(10, w.size - 10, 3):
			var i := y * w.size + x
			var cc := w.country[i]
			var c2 := w.country2[i]
			if w.blend[i] < 0.35 or not ((cc == a and c2 == b) or (cc == b and c2 == a)):
				continue
			if not standable(w, solid, x, y):
				continue
			var na := 0
			var nb := 0
			var wet := 0
			for dy in range(-10, 11, 4):
				for dx in range(-10, 11, 4):
					var j := (y + dy) * w.size + x + dx
					var k := w.country[j]
					if k == a:
						na += 1
					elif k == b:
						nb += 1
					if Ground.is_water(w.ground[j]):
						wet += 1
			var score := minf(na, nb) + (na + nb) * 0.1 - wet * 0.5 + Rng.hash01(w.seed_value, x, y, 8) * 0.3
			if score > best_score:
				best_score = score
				best = Vector2(x + 0.5, y + 0.5)
	return best


static func river_sample(w: WorldData) -> Vector2:
	var longest := PackedVector2Array()
	for r in w.rivers:
		if r.size() > longest.size():
			longest = r
	if longest.is_empty():
		return Vector2(-1, -1)
	return _stand_near(w, longest[longest.size() / 2])


static func cliff_sample(w: WorldData) -> Vector2:
	var solid := solid_mask(w)
	var best := Vector2(-1, -1)
	var best_rise := 2
	for y in range(20, w.size - 20, 2):
		for x in range(20, w.size - 20, 2):
			if not standable(w, solid, x, y) or not _mainland(w, x, y):
				continue
			var i := y * w.size + x
			var l := w.level[i]
			var rise := maxi(maxi(w.level[i - 2] - l, w.level[i - 2 * w.size] - l), maxi(w.level[i + 2] - l, w.level[i + 2 * w.size] - l))
			if rise > best_rise:
				best_rise = rise
				best = Vector2(x + 0.5, y + 0.5)
	return best


## Mostly land for 20 tiles around: the island, not a stack or a skerry.
static func _mainland(w: WorldData, x: int, y: int) -> bool:
	var land := 0
	for dy in range(-20, 21, 5):
		for dx in range(-20, 21, 5):
			if w.level_at(x + dx, y + dy) > 0:
				land += 1
	return land >= 45


## The nearest standable tile to p (searching outward), or p itself.
static func _stand_near(w: WorldData, p: Vector2) -> Vector2:
	var solid := solid_mask(w)
	var px := floori(p.x)
	var py := floori(p.y)
	for r in 12:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				if standable(w, solid, px + dx, py + dy):
					return Vector2(px + dx + 0.5, py + dy + 0.5)
	return p
