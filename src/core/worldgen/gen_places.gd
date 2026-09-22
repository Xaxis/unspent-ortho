class_name GenPlaces
## Named places in a generated world, for shots, tools and tests:
##   "spawn"                   where the player wakes
##   "moss"                    a standing tile deep inside a country
##   "coast-pinewood"          a standing tile on that ecotone, where both mix
##   "tip", "wreck2", ...      the Nth landmark of a kind (1-based, default 1)
##   "works", "works_breaker"  the Nth depot of the plan, or one of its housings
##   "lighthouse", "firewatch" the Nth landmark worth the walk of that kind
##   "river"                   a bank beside the longest river's middle reach
##   "cliff"                   a tile at the foot of the tallest nearby face
##   "open", "open_moss"       open standable ground, clear of every village and
##                             every depot: room to fight in with nothing built
##                             in shot, in the landscape the player wakes in or
##                             in the one named
##   "lit_village"             the square of the village nearest where the player
##                             wakes that wired a machine's light into a house
##   "typical", "typical_moss" the most CHARACTERISTIC standing ground of a
##                             landscape, clear of everything built: what the
##                             place looks like, where `open` is where there is
##                             room to fight
## find() returns Vector2(-1, -1) when a world has no such place.


static func find(w: WorldData, name: String) -> Vector2:
	var key := name.to_lower().strip_edges()
	if key == "spawn":
		return w.spawn
	if key == "lit_village":
		var sq := lit_village_square(w)
		return _stand_near(w, sq) if sq.x >= 0.0 else Vector2(-1, -1)
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
	if key == "typical" or key.begins_with("typical_"):
		var tland := key.trim_prefix("typical").trim_prefix("_")
		var twant := BiomeRegistry.index_of(StringName(tland)) if tland != "" else w.country[int(w.spawn.y) * w.size + int(w.spawn.x)]
		return typical_sample(w, twant) if twant >= 0 else Vector2(-1, -1)
	if key == "open" or key.begins_with("open_"):
		var land := key.trim_prefix("open").trim_prefix("_")
		var want := BiomeRegistry.index_of(StringName(land)) if land != "" else w.country[int(w.spawn.y) * w.size + int(w.spawn.x)]
		return open_sample(w, want) if want >= 0 else Vector2(-1, -1)
	var digits := ""
	while key.length() > 0 and key.right(1).is_valid_int():
		digits = key.right(1) + digits
		key = key.left(key.length() - 1)
	var nth := maxi(1, digits.to_int()) if digits != "" else 1
	var here: Array[Vector2] = []
	for m in w.landmarks:
		if String(m.kind) == key:
			here.append(m.pos as Vector2)
	if not here.is_empty():
		return _stand_near(w, _out_of_the_yard(w, here, nth))
	return _placed_after(w, key, nth)


## The nth of `marks`, preferring one no depot has been built over.
##
## A depot goes up at the BUSIEST marked landmark of its region (`Works.sites`),
## so a works mark being under a yard is the world working, not a fault -- but it
## makes the mark's NAME a lie about the picture. Measured on seed 7, seven of
## them resolved inside a yard: turf_rows, drill_field, pans, drained, corridor,
## slag and breaking_yard. `place turf_rows` was a photograph of a depot and
## nothing about the name said so.
##
## So the name goes to an instance in the open where there is one, and `turf_rows2`
## still reaches the buried one for anybody who wants the yard built on the cut.
static func _out_of_the_yard(w: WorldData, marks: Array[Vector2], nth: int) -> Vector2:
	var yards: Array[Vector2] = []
	for s in Works.sites(w):
		yards.append(s.pos)
	var open_ones: Array[Vector2] = []
	for m in marks:
		var shut := false
		for y in yards:
			if y.distance_to(m) < Works.YARD:
				shut = true
				break
		if not shut:
			open_ones.append(m)
	var pick := open_ones if open_ones.size() >= nth else marks
	return pick[mini(nth, pick.size()) - 1]


## Places that are laid AFTER the world is generated — the plan's depots
## (`Works`) and the landmarks worth the walk (`Landmarks`) — are put in
## `w.landmarks` by their own systems, which have not run when a shot resolves
## `--place`. Both are pure functions of the island, so they are asked directly
## rather than made a worldgen stage: adding a stage would move every seed.
static func _placed_after(w: WorldData, key: String, nth: int) -> Vector2:
	if key.begins_with("works"):
		var works := Works.sites(w)
		if nth > works.size():
			return Vector2(-1, -1)
		# "works" is the yard; "works_feed", "works_breaker", "works_coolant" are
		# its three working parts, which is how a tour walks to the next one
		# without a coordinate (they lie along the survey bearing, so nothing
		# written in a tour file could name where they are).
		var part := Works.PART_NAMES.find(StringName(key.trim_prefix("works_")))
		return _stand_near(w, works[nth - 1].part(maxi(0, part)))
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


## How far open ground must be from anything built. The play camera shows about
## 26.7 x 17.9 tiles of ground, so half its width is 13.4: at twenty tiles no
## village and no depot is in the shot, and there is room left for a target lock
## to lean the frame off the player without walking one into it.
const CLEAR_OF_BUILT := 20.0
## How far round the tile itself has to be standable, so a body can be put down
## beside the player and fought without a boulder in the way.
const ROOM := 5


## Open standable ground in a landscape, well clear of every village and every
## depot of the plan.
##
## This is what twelve staged tour frames were reaching for with a coordinate and
## could not ask for by name (CLAUDE.md, "Stage by name, never by a coordinate"):
## room to fight in, with nothing built in shot. `country_sample` is NOT it --
## that one is a tile deep inside a country, and deep inside a country is exactly
## where a village sits. Measured: "coast" lands 21.5 tiles from the nearest
## built thing on seed 1, 35.0 on seed 4 and 25.5 on seed 42 -- over the line, but
## by luck rather than by rule, and the first of those by a tile and a half.
## "open" is 44.6, 56.6 and 45.4 on the same three.
##
## Pure and derived like every other name here, so a tour asking for it gets the
## same ground every run, and different but still-correct ground the day worldgen
## moves the island under it.
static func open_sample(w: WorldData, cc: int) -> Vector2:
	var solid := solid_mask(w)
	var built: Array[Vector2] = []
	for v: Dictionary in w.villages:
		built.append(v.pos as Vector2)
	for s in Works.sites(w):
		built.append(s.pos)
	# And the places worth the walk. A lighthouse is as much a building as a
	# village is, and a name promising nothing built in shot that lands at the
	# foot of one has swapped one photograph of a building for another.
	for s in Landmarks.sites(w):
		built.append(s.pos)
	var best := Vector2(-1, -1)
	var best_score := -1.0
	for y in range(6, w.size - 6, 3):
		for x in range(6, w.size - 6, 3):
			var i := y * w.size + x
			if w.country[i] != cc or w.blend[i] > 0.0 or not standable(w, solid, x, y):
				continue
			var here := Vector2(x + 0.5, y + 0.5)
			var shut := false
			for b in built:
				if b.distance_to(here) < CLEAR_OF_BUILT:
					shut = true
					break
			if shut:
				continue
			# Of the ground that qualifies, the most open: the tile with the fewest
			# things to stand behind is the one a fight reads in.
			var room := 0.0
			for dy in range(-ROOM, ROOM + 1):
				for dx in range(-ROOM, ROOM + 1):
					if standable(w, solid, x + dx, y + dy):
						room += 1.0
			var score := room + Rng.hash01(w.seed_value, x, y, 11) * 0.5
			if score > best_score:
				best_score = score
				best = here
	return best


## How far round a candidate its surroundings are read. The play camera holds
## about 26.7 x 17.9 tiles, so eleven each way is close to what a frame taken here
## will actually contain -- the score is about the PICTURE, not the map.
const TYPICAL_REACH := 11
## Props are binned into squares this wide once, so reading a neighbourhood is
## nine lookups instead of a walk over every prop in the world.
const TYPICAL_BUCKET := 8
## What a portrait must stand clear of, measured against what the camera can hold
## (`Landmarks.read_reach` is 11-13 tiles at the play camera, so 16 puts a
## landmark out of shot). Wider than `open`'s single rule because this frame is
## about the LAND, and one roof in it is the whole subject changed.
const TYPICAL_OF_YARD := 30.0
const TYPICAL_OF_VILLAGE := 22.0
const TYPICAL_OF_LANDMARK := 16.0


## The most CHARACTERISTIC standing ground of a landscape: the tile whose
## surroundings look most like that landscape's own average, clear of everything
## built.
##
## `open` is the other question and both are worth having. Measured on seed 1,
## `open` takes a REED MARSH -- 32 reeds within eleven tiles where the coast's own
## mean is driftwood, gorse and broadleaf. Nothing is wrong with that answer: it
## is "where is there room to fight", and a marsh has room. It is simply not
## "what does the coast look like", and a portrait staged there is a picture of
## the one place on the coast that is unlike the coast.
##
## So this scores a candidate by how far its neighbourhood is from the
## landscape's own make-up, over ground types AND prop kinds together, and takes
## the nearest. Nothing declares a signature list that could rot -- what counts
## as typical is measured off the world every time it is asked.
static func typical_sample(w: WorldData, cc: int) -> Vector2:
	var solid := solid_mask(w)
	var yards: Array[Vector2] = []
	for site in Works.sites(w):
		yards.append(site.pos)
	var villages: Array[Vector2] = []
	for v: Dictionary in w.villages:
		villages.append(v.pos as Vector2)
	# Both sets: the survey's marks and the places worth the walk are different
	# lists, and the lighthouse is only in the second.
	var marks: Array[Vector2] = []
	for m: Dictionary in w.landmarks:
		marks.append(m.pos as Vector2)
	for site in Landmarks.sites(w):
		marks.append(site.pos)

	var bw := w.size / TYPICAL_BUCKET + 1
	var bins := PackedFloat32Array()
	bins.resize(bw * bw * PropKind.COUNT)
	var land_props := PackedFloat32Array()
	land_props.resize(PropKind.COUNT)
	for pr in w.props:
		var px := int(pr.pos.x)
		var py := int(pr.pos.y)
		if not w.in_bounds(px, py):
			continue
		bins[((py / TYPICAL_BUCKET) * bw + px / TYPICAL_BUCKET) * PropKind.COUNT + pr.kind] += 1.0
		if w.country[py * w.size + px] == cc:
			land_props[pr.kind] += 1.0

	var land_ground := PackedFloat32Array()
	land_ground.resize(Ground.COUNT)
	for y in w.size:
		for x in w.size:
			var i := y * w.size + x
			if w.country[i] == cc:
				land_ground[w.ground[i]] += 1.0
	_share(land_ground)
	_share(land_props)

	var best := Vector2(-1, -1)
	var best_score := INF
	for y in range(6, w.size - 6, 2):
		for x in range(6, w.size - 6, 2):
			var i := y * w.size + x
			if w.country[i] != cc or w.blend[i] > 0.0 or not standable(w, solid, x, y):
				continue
			var here := Vector2(x + 0.5, y + 0.5)
			if _nearest_of(yards, here) < TYPICAL_OF_YARD:
				continue
			if _nearest_of(villages, here) < TYPICAL_OF_VILLAGE:
				continue
			if _nearest_of(marks, here) < TYPICAL_OF_LANDMARK:
				continue
			var near_ground := PackedFloat32Array()
			near_ground.resize(Ground.COUNT)
			for dy in range(-TYPICAL_REACH, TYPICAL_REACH + 1, 2):
				for dx in range(-TYPICAL_REACH, TYPICAL_REACH + 1, 2):
					if w.in_bounds(x + dx, y + dy):
						near_ground[w.ground[(y + dy) * w.size + x + dx]] += 1.0
			var near_props := PackedFloat32Array()
			near_props.resize(PropKind.COUNT)
			var bx := x / TYPICAL_BUCKET
			var by := y / TYPICAL_BUCKET
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if bx + ox < 0 or by + oy < 0 or bx + ox >= bw or by + oy >= bw:
						continue
					var base := ((by + oy) * bw + bx + ox) * PropKind.COUNT
					for k in PropKind.COUNT:
						near_props[k] += bins[base + k]
			_share(near_ground)
			_share(near_props)
			var score := _apart(near_ground, land_ground) + _apart(near_props, land_props)
			# A hair of noise so two identical neighbourhoods do not depend on scan order.
			score += Rng.hash01(w.seed_value, x, y, 13) * 0.002
			if score < best_score:
				best_score = score
				best = here
	return best


## In place, to shares summing to one (all zero stays all zero).
static func _share(h: PackedFloat32Array) -> void:
	var total := 0.0
	for v in h:
		total += v
	if total <= 0.0:
		return
	for i in h.size():
		h[i] = h[i] / total


## How far apart two share histograms are, 0 (the same) .. 2 (nothing in common).
static func _apart(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var d := 0.0
	for i in mini(a.size(), b.size()):
		d += absf(a[i] - b[i])
	return d


static func _nearest_of(of: Array[Vector2], p: Vector2) -> float:
	var d := INF
	for q in of:
		d = minf(d, q.distance_to(p))
	return d


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
			if not standable(w, solid, x, y):
				continue
			var i := y * w.size + x
			var l := w.level[i]
			var rise := maxi(maxi(w.level[i - 2] - l, w.level[i - 2 * w.size] - l), maxi(w.level[i + 2] - l, w.level[i + 2 * w.size] - l))
			# The rise is four lookups and `_mainland` is eighty-one, and both must
			# hold, so the cheap one goes first. Same answer, measured 869 ms -> 142 ms
			# on a 512-tile island: `best_rise` only ever climbs, so a cell that does
			# not beat it could not have won whatever `_mainland` said.
			if rise <= best_rise or not _mainland(w, x, y):
				continue
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
## The square of the village nearest the spawn that wired a machine's light into a
## house, or (-1, -1) when none did.
##
## ONLY A SHARE OF VILLAGES ARE LIT, and which share is a hash of each village's
## POSITION (GenScatter.LIT_SHARE). So moving the spawn re-rolls which village is
## nearest it and whether that one is lit: the canon stood at `spawn` and assumed
## it was, and a spawn moved home put its village frame somewhere with no tube in
## it at all. The ruling was to find a lit village, not to make the spawn's always
## lit -- neon is a situational accent, and the owner has corrected it being
## applied everywhere once already.
##
## Asked of the HOUSES THE WORLD LAID, never of the hash: in a lit village the lit
## house is the one nearest the square (GenScatter deals it that way), so that is
## the house checked, against the forms that landscape counts as lit. If the rule
## for which villages light ever changes, this goes on telling the truth.
static func lit_village_square(w: WorldData) -> Vector2:
	var order: Array[Dictionary] = w.villages.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.pos as Vector2).distance_to(w.spawn) < (b.pos as Vector2).distance_to(w.spawn))
	for v: Dictionary in order:
		var vp: Vector2 = v.pos
		var lit := BiomeForms.of(int(v.get("country", 0))).lit()
		if lit.is_empty():
			continue
		var nearest: WorldProp = null
		var near := INF
		for p: WorldProp in w.props:
			if p.kind != PropKind.HOUSE or p.variant < 0:
				continue
			var d := p.pos.distance_to(vp)
			if d <= 18.0 and d < near:
				near = d
				nearest = p
		if nearest != null and lit.has(nearest.variant):
			return vp
	return Vector2(-1, -1)


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
