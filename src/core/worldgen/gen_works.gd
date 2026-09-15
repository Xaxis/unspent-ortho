class_name GenWorks
## Stage 12b (inside GenScatter.props: after the grid, before the scatter): what
## every landscape holds of what happened to it (docs/VISION.md section 8).
##
## Two hands lay it. The machines lay their works on one survey bearing across
## the whole island (bearing()): turf cut in rows on the coast, drainage cuts and
## pipelines through the moss, clearcuts in exact squares and a relay corridor
## through the pines, drill grids and conveyors on the bonelands, slag and
## refinery runs in the burning, a checkpoint and a stack on the snowfield.
## People leave the rest where they can: graves and shacks and fences by every
## village, barricades on the ways in, signs along the roads, wrecks and debris
## where things ended. Ruled works run straight through chaotic ground; the
## hand's things lean and gap.
##
## Every work is recorded as a landmark {kind, pos, country, dir, half, mark}:
## `dir` its bearing, `half` its half extents along and across it, `mark` the
## ground mark renderers lay under it (&"cut", &"scorch", &"quarry", &"bores";
## WorksMap). Sites keep off villages, roads, water and each other; their props
## keep the spawn's first steps clear. Runs and grids stand at scale 1 so their
## order is exact.

const CUT := &"cut"
const SCORCH := &"scorch"
const QUARRY := &"quarry"
const BORES := &"bores"


## The machines' survey bearing for a world (radians): every ruled work lies
## along it or across it, 11 to 31 degrees off the tile axes so no row ever
## follows the tile grid.
static func bearing(seed_value: int) -> float:
	return 0.2 + Rng.hash01(seed_value, 0xBEA, 7) * 0.35


static func place(c: GenContext, occ: PackedByteArray) -> void:
	var rng := Rng.make(c.s, 0x3057)
	var d := Vector2.from_angle(bearing(c.s))
	_coast(c, occ, rng, d)
	c.mark(&"works.coast")
	_moss(c, occ, rng, d)
	_pinewood(c, occ, rng, d)
	c.mark(&"works.moss_pine")
	_snowfield(c, occ, rng, d)
	_bonelands(c, occ, rng, d)
	_burning(c, occ, rng, d)
	c.mark(&"works.far")
	_villages(c, occ, rng)
	_roads(c, occ, rng)
	_remains(c, occ, rng)
	c.mark(&"works.people")
	_survey(c, occ)
	_vignettes(c, occ, d)
	c.mark(&"works.vignettes")


# --- helpers ---------------------------------------------------------------------

## How many of a thing a world of this size gets.
static func _n(c: GenContext, base: float) -> int:
	return maxi(1, roundi(base * maxf(c.k, 0.3)))


## A site in country cc: flat within r (levels differ by at most `rise`), dry,
## roadless, clear of villages and other places by `apart`, its middle tile on
## one of `grounds` (any, if empty) and heart-side of any ecotone. The last
## part of the search settles for less room, rougher ground and any ground, so
## every landscape gets its works on every seed.
static func _site(c: GenContext, rng: RandomNumberGenerator, cc: int, r: int, rise: int, grounds: Array, apart: float, attempts: int = 500, blend_max: float = 0.35) -> Vector2i:
	var w := c.w
	var strict := int(attempts * 0.55)
	for attempt in attempts * 2:
		var p := GenScatter._random_tile(c, rng)
		var i := p.y * c.size + p.x
		var loose := attempt >= strict
		if w.country[i] != cc or w.blend[i] > (blend_max if not loose else blend_max + 0.1):
			continue
		if attempt < attempts and not grounds.is_empty() and not grounds.has(int(w.ground[i])):
			continue
		var room := apart if not loose else apart * 0.45
		if _crowded(w, Vector2(p), room) or GenScatter._near_village(w, Vector2(p), maxf(room, 14.0)):
			continue
		if not GenScatter._clear_site(c, p, r if not loose else maxi(2, r - 3), rise if not loose else rise + 1):
			continue
		return p
	return Vector2i(-1, -1)


## Another place worth walking to within d of p. Small marks (falls, bridges,
## summits, graves) are passed over: a work may stand near them.
static func _crowded(w: WorldData, p: Vector2, d: float) -> bool:
	var d2 := d * d
	for m in w.landmarks:
		var k: StringName = m.kind
		if k == &"falls" or k == &"bridge" or k == &"summit" or k == &"graves":
			continue
		if (m.pos as Vector2).distance_squared_to(p) < d2:
			return true
	return false


static func _record(c: GenContext, kind: StringName, p: Vector2, dir: Vector2, half: Vector2, mark: StringName = &"") -> void:
	var at := Vector2i(clampi(floori(p.x), 0, c.size - 1), clampi(floori(p.y), 0, c.size - 1))
	var m := {"kind": kind, "pos": p, "country": int(c.w.country[at.y * c.size + at.x]), "dir": dir, "half": half}
	if mark != &"":
		m["mark"] = mark
	c.w.landmarks.append(m)


## Put one prop at p if the ground there takes it: dry land off roads and
## villages, free of other things within `clear`, on terrace `level` (any when
## -99), and never in the spawn's first steps. `exact` stands it at scale 1.
static func _put(c: GenContext, occ: PackedByteArray, kind: int, p: Vector2, rot: float, level: int = -99, clear: float = 0.5, exact: bool = false) -> WorldProp:
	var w := c.w
	var tx := floori(p.x)
	var ty := floori(p.y)
	if tx < 3 or ty < 3 or tx >= c.size - 3 or ty >= c.size - 3:
		return null
	var i := ty * c.size + tx
	if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or c.ramp[i] != 0:
		return null
	if Ground.is_water(w.ground[i]):
		return null
	if not GenScatter._free(c, occ, p, clear):
		return null
	var l := w.level[i]
	if level != -99 and l != level:
		return null
	for v in w.villages:
		if (v.pos as Vector2).distance_squared_to(p) < pow(float(v.get("radius", 4.0)) + 0.8, 2.0):
			return null
	if PropKind.SOLID[kind] > 0.0:
		# Not on a terrace lip: a solid stands on one level.
		for k: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if w.level[i + k.y * c.size + k.x] != l:
				return null
	var to := p - w.spawn
	var face := Vector2.from_angle(w.spawn_facing)
	if to.length_squared() < 16.0 or (PropKind.SOLID[kind] > 0.0 and to.length_squared() < 100.0 and to.normalized().dot(face) > 0.4):
		return null
	var prop := GenScatter._add(c, kind, p, fposmod(rot, TAU))
	if exact:
		prop.scale = 1.0
		prop.solid = PropKind.SOLID[kind]
	GenScatter._occupy(c, occ, p, maxf(PropKind.SOLID[prop.kind] * prop.scale, 0.0))
	return prop


## A straight run of pieces from `a` along `dir`, `step` apart, each turned
## along the run; a piece that cannot stand leaves a gap, and `gaps` of them
## are left out anyway. Returns the ids placed.
static func _run(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator, kind: int, a: Vector2, dir: Vector2, pieces: int, step: float, level: int, gaps: float = 0.0) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for i in pieces:
		if gaps > 0.0 and rng.randf() < gaps:
			continue
		var p := a + dir * (i + 0.5) * step
		var prop := _put(c, occ, kind, p, dir.angle(), level, 0.0, true)
		if prop != null:
			ids.append(prop.id)
			# A run owns the tiles along its length.
			GenScatter._occupy(c, occ, p + dir * step * 0.3, 0.0)
			GenScatter._occupy(c, occ, p - dir * step * 0.3, 0.0)
	return ids


## Mark every tile of a rotated rectangle occupied, so the scatter grows
## nothing there (a clearcut, a corridor, a drill field).
static func _clear_rect(c: GenContext, occ: PackedByteArray, centre: Vector2, dir: Vector2, half: Vector2) -> void:
	var nrm := Vector2(-dir.y, dir.x)
	# Walked in the rectangle's own axes at under half a tile, so no tile is missed.
	var nu := ceili(half.x * 2.5)
	var nv := ceili(half.y * 2.5)
	for iu in range(-nu, nu + 1):
		var along := centre + dir * (half.x * iu / nu)
		for iv in range(-nv, nv + 1):
			var q := along + nrm * (half.y * iv / nv)
			var x := floori(q.x)
			var y := floori(q.y)
			if x >= 0 and y >= 0 and x < c.size and y < c.size:
				occ[y * c.size + x] = 1


## Unit direction from p toward the nearest open sea within `reach`, or zero.
static func _sea_dir(c: GenContext, p: Vector2i, reach: int = 7) -> Vector2:
	var w := c.w
	for r in range(2, reach + 1):
		var best := Vector2.ZERO
		var n := 0
		for k in 16:
			var a := float(k) / 16.0 * TAU
			var q := Vector2(p) + Vector2.from_angle(a) * r
			if w.level_at(floori(q.x), floori(q.y)) <= 0:
				best += Vector2.from_angle(a)
				n += 1
		if n > 0 and best.length() > 0.1:
			return best.normalized()
	return Vector2.ZERO


## A tile on the coast's shore: level 1, within `reach` of the sea, on one of
## `grounds`, heart-side of any ecotone, away from other places.
static func _shore(c: GenContext, rng: RandomNumberGenerator, cc: int, grounds: Array, apart: float, attempts: int = 900) -> Vector2i:
	var w := c.w
	for attempt in attempts:
		var p := GenScatter._random_tile(c, rng)
		var i := p.y * c.size + p.x
		if w.country[i] != cc or w.level[i] < 1 or w.level[i] > (1 if attempt < attempts * 0.6 else 2) or c.sea_steps[i] > 4 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0:
			continue
		if not grounds.is_empty() and not grounds.has(int(w.ground[i])):
			continue
		if c.islet[i] != 0:
			continue
		var room := apart if attempt < attempts * 0.6 else apart * 0.4
		if _crowded(w, Vector2(p), room) or GenScatter._near_village(w, Vector2(p), maxf(room * 0.7, 14.0)):
			continue
		if _sea_dir(c, p).length() < 0.5:
			continue
		return p
	return Vector2i(-1, -1)


## A few things scattered round a point, each where it can stand.
static func _about(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator, kind: int, centre: Vector2, count: int, r0: float, r1: float, level: int = -99) -> int:
	var placed := 0
	for t in count * 4:
		if placed >= count:
			break
		var q := centre + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(r0, r1)
		if _put(c, occ, kind, q, rng.randf() * TAU, level, 0.3) != null:
			placed += 1
	return placed


## Every tile within r of p on p's level and dry.
static func _flat(c: GenContext, p: Vector2, r: int) -> bool:
	var x0 := floori(p.x)
	var y0 := floori(p.y)
	if x0 < r + 1 or y0 < r + 1 or x0 >= c.size - r - 1 or y0 >= c.size - r - 1:
		return false
	var l := c.w.level[y0 * c.size + x0]
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var i := (y0 + dy) * c.size + x0 + dx
			if c.w.level[i] != l or c.water[i] != 0 or Ground.is_water(c.w.ground[i]):
				return false
	return true


static func _level(c: GenContext, p: Vector2i) -> int:
	return c.w.level[p.y * c.size + p.x]


# --- the coast -------------------------------------------------------------------

static func _coast(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator, d: Vector2) -> void:
	var cc := Country.COAST
	var nrm := Vector2(-d.y, d.x)
	# Turf cut in the machines' rows: a ruled field of strips on the open turf,
	# survey posts at its corners, a fence along its end, a warning at its side.
	for n in _n(c, 2.0):
		var p := _site(c, rng, cc, 8, 1, [Ground.GRASS, Ground.HEATH], 26.0)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var half := Vector2(rng.randf_range(8.0, 11.0), rng.randf_range(5.0, 7.0))
		_record(c, &"turf_rows", at, d, half, CUT)
		var l := _level(c, p)
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				_put(c, occ, PropKind.SURVEY, at + d * half.x * sx + nrm * half.y * sy, d.angle(), -99, 0.0, true)
		_run(c, occ, rng, PropKind.FENCE, at - d * (half.x + 0.6) - nrm * half.y, nrm, ceili(half.y), 2.0, l, 0.15)
		_put(c, occ, PropKind.SIGN, at + nrm * (half.y + 1.2), nrm.angle(), -99, 0.3)
	# The intake: a machine housing at the shore, its pipes out to the water,
	# fenced square, a tide gauge standing in the wash.
	var intakes := 0
	for attempt in 10:
		if intakes >= _n(c, 1.0):
			break
		var p := _shore(c, rng, cc, [Ground.SAND, Ground.SHINGLE, Ground.GRASS, Ground.GRAVEL] if attempt < 5 else [], 40.0)
		if p.x < 0:
			continue
		var sea := _sea_dir(c, p)
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var l := _level(c, p)
		var intake: WorldProp = null
		for back in 4:
			intake = _put(c, occ, PropKind.INTAKE, at - sea * back, sea.angle(), l if back == 0 else -99, 1.0, true)
			if intake != null:
				at = intake.pos
				break
		if intake == null:
			continue
		intakes += 1
		_record(c, &"intake", at, sea, Vector2(4.0, 4.0))
		var side := Vector2(-sea.y, sea.x)
		# The fence square, open to the sea; the gate on the land side.
		_run(c, occ, rng, PropKind.FENCE, at - sea * 4.0 - side * 4.0, side, 4, 2.0, -99, 0.0)
		_run(c, occ, rng, PropKind.FENCE, at - sea * 4.0 - side * 4.0, sea, 4, 2.0, -99, 0.1)
		_run(c, occ, rng, PropKind.FENCE, at - sea * 4.0 + side * 4.0, sea, 4, 2.0, -99, 0.1)
		_put(c, occ, PropKind.SIGN, at - sea * 5.2 + side * 1.0, (-sea).angle(), -99, 0.2)
		_gauge(c, occ, at + side * 2.5, sea)
	# Trawlers beached where the sea put them, a field of debris round each.
	var hulls := 0
	for attempt in 10:
		if hulls >= _n(c, 2.0):
			break
		var p := _shore(c, rng, cc, [Ground.SAND, Ground.SHINGLE] if attempt < 4 else [], 30.0 if attempt < 4 else 16.0)
		if p.x < 0:
			continue
		var sea := _sea_dir(c, p)
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var hull: WorldProp = null
		for back in 4:
			# A hull lies whole on one terrace, never hung over a bank.
			if not _flat(c, (at - sea * back).floor(), 1):
				continue
			hull = _put(c, occ, PropKind.HULL, at - sea * back, (Vector2(-sea.y, sea.x)).angle() + rng.randf_range(-0.4, 0.4), -99, 0.8)
			if hull != null:
				at = hull.pos
				break
		if hull == null:
			continue
		hulls += 1
		_record(c, &"hulk", at, sea, Vector2(3.0, 2.0))
		_about(c, occ, rng, PropKind.DEBRIS, at, 3, 2.5, 5.0)
		_about(c, occ, rng, PropKind.DRIFTWOOD, at, 2, 2.0, 5.0)
		_gauge(c, occ, at + Vector2(-sea.y, sea.x) * 3.0, sea)
	# The sea wall, broken along the shore, a drowned car at its foot.
	var walls := 0
	for attempt in 12:
		if walls >= _n(c, 2.0):
			break
		var p := _shore(c, rng, cc, [], 30.0)
		if p.x < 0:
			continue
		var sea := _sea_dir(c, p)
		var along := Vector2(-sea.y, sea.x)
		var at := Vector2(p) + Vector2(0.5, 0.5) - sea
		var ids := _run(c, occ, rng, PropKind.SEA_WALL, at - along * 7.0, along, 5, 2.8, -99, 0.15)
		if ids.is_empty():
			continue
		walls += 1
		for id in ids:
			# The wall's sea face (+Z) looks at the sea.
			c.w.props[id].rot = fposmod(along.angle() + (PI if along.rotated(PI * 0.5).dot(sea) < 0.0 else 0.0), TAU)
		_record(c, &"sea_wall", at, along, Vector2(7.0, 1.0))
		_about(c, occ, rng, PropKind.VEHICLE, at + sea * 2.0, 1, 0.0, 3.0)
		_put(c, occ, PropKind.SIGN, at - sea * 2.2, (-sea).angle(), -99, 0.2)
	# Tide gauges along the shingle, where the machines read the sea.
	var gauges := 0
	for attempt in 12:
		if gauges >= _n(c, 2.0):
			break
		var p := _shore(c, rng, cc, [Ground.SHINGLE, Ground.SAND] if attempt < 6 else [], 24.0, 300)
		if p.x >= 0 and _gauge(c, occ, Vector2(p) + Vector2(0.5, 0.5), _sea_dir(c, p)) != null:
			gauges += 1
	# Cars drowned at the tide line.
	var cars := 0
	for attempt in 600:
		if cars >= _n(c, 3.0):
			break
		var p := _shore(c, rng, cc, [Ground.SAND, Ground.SHINGLE], 12.0, 60)
		if p.x < 0:
			continue
		if _put(c, occ, PropKind.VEHICLE, Vector2(p) + Vector2(0.5, 0.5), rng.randf() * TAU, -99, 0.8) != null:
			cars += 1


## A tide gauge on the last dry ground from `from` toward the sea.
static func _gauge(c: GenContext, occ: PackedByteArray, from: Vector2, sea: Vector2) -> WorldProp:
	var best := Vector2(-1, -1)
	for t in 16:
		var q := from + sea * (1.0 + t * 0.5)
		var tx := floori(q.x)
		var ty := floori(q.y)
		if not c.w.in_bounds(tx, ty) or c.land[ty * c.size + tx] == 0:
			break
		best = q
	if best.x < 0.0:
		return null
	for back in 5:
		var g := _put(c, occ, PropKind.TIDE_GAUGE, best - sea * back * 0.5, sea.angle(), -99, 0.0, true)
		if g != null:
			return g
	return null


# --- the moss ----------------------------------------------------------------------

static func _moss(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator, d: Vector2) -> void:
	var cc := Country.MOSS
	var nrm := Vector2(-d.y, d.x)
	# The drained fen: straight cuts, a pump house on them, its pipeline
	# striding off on stilts, a car sunk in the black water, reeds in the wire.
	for n in _n(c, 3.0):
		var p := _site(c, rng, cc, 7, 1, [Ground.MOSS, Ground.PEAT, Ground.MUD, Ground.GRASS, Ground.HEATH], 30.0, 700, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var l := _level(c, p)
		var half := Vector2(rng.randf_range(11.0, 15.0), rng.randf_range(7.0, 9.0))
		_record(c, &"drained", at, d, half, CUT)
		var pump := _put(c, occ, PropKind.PUMP_HOUSE, at, d.angle(), l, 1.0, true)
		if pump == null:
			pump = _put(c, occ, PropKind.PUMP_HOUSE, at + nrm * 2.0, d.angle(), -99, 0.8, true)
		var start := (pump.pos if pump != null else at) + d * 2.8
		_run(c, occ, rng, PropKind.PIPE, start, d, rng.randi_range(9, 14), 2.0, -99, 0.08)
		_run(c, occ, rng, PropKind.FENCE, at - d * half.x * 0.8 + nrm * (half.y + 0.5), d, 6, 2.0, -99, 0.25)
		_about(c, occ, rng, PropKind.VEHICLE, at, 1, 4.0, half.y)
		_put(c, occ, PropKind.SIGN, at - d * 2.5 + nrm * 1.6, d.angle(), -99, 0.2)
	# Bog graves: stakes in a row by a stilt hut.
	for n in _n(c, 2.0):
		var p := _site(c, rng, cc, 4, 1, [Ground.MOSS, Ground.PEAT, Ground.HEATH, Ground.GRASS], 24.0, 500, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var row := Vector2.from_angle(rng.randf() * TAU)
		var graves := 0
		for i in rng.randi_range(4, 6):
			if _put(c, occ, PropKind.GRAVE, at + row * (i * 1.3 - 3.0) + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)), row.angle() + PI * 0.5, -99, 0.2) != null:
				graves += 1
		if graves > 0:
			_record(c, &"bog_graves", at, row, Vector2(4.0, 1.0))
			_about(c, occ, rng, PropKind.SHACK, at + row.orthogonal() * 4.0, 1, 0.0, 2.5)


# --- the pinewood ------------------------------------------------------------------

static func _pinewood(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator, d: Vector2) -> void:
	var cc := Country.PINEWOOD
	var w := c.w
	var nrm := Vector2(-d.y, d.x)
	# The relay corridor: one straight cut through the heart of the pines, masts
	# strung along it with the machines' light on them, stumps at its edges.
	var heart := c.hearts[cc]
	var through := Vector2i(-1, -1)
	if heart.x >= 0.0 and w.country_at(int(heart.x), int(heart.y)) == cc:
		through = Vector2i(heart)
	else:
		through = _site(c, rng, cc, 2, 3, [], 0.0, 400, 0.5)
	if through.x >= 0:
		var mid := Vector2(through) + Vector2(0.5, 0.5)
		var along := nrm if rng.randf() < 0.5 else d
		var ends: Array[float] = [0.0, 0.0]
		for side in 2:
			var sgn := -1.0 if side == 0 else 1.0
			var t := 0.0
			while t < 90.0 * maxf(c.k, 0.4):
				var q := mid + along * sgn * (t + 1.0)
				if w.country_at(floori(q.x), floori(q.y)) != cc or w.level_at(floori(q.x), floori(q.y)) <= 0:
					break
				t += 1.0
			ends[side] = t
		var from := mid - along * ends[0]
		var length := ends[0] + ends[1]
		if length > 20.0:
			var centre := from + along * length * 0.5
			_clear_rect(c, occ, centre, along, Vector2(length * 0.5, 2.6))
			_record(c, &"corridor", centre, along, Vector2(length * 0.5, 2.8), CUT)
			var masts := PackedInt32Array()
			var tt := 4.0
			while tt < length - 2.0:
				var q := from + along * tt
				var mast: WorldProp = null
				for nudge: float in [0.0, 1.0, -1.0, 2.0]:
					# Masts stand in the cut: its tiles are taken, so they are put by hand.
					var qq := q + along * nudge
					var tx := floori(qq.x)
					var ty := floori(qq.y)
					var i := ty * c.size + tx
					if tx < 3 or ty < 3 or tx >= c.size - 3 or ty >= c.size - 3:
						continue
					if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or Ground.is_water(w.ground[i]):
						continue
					if (qq - w.spawn).length_squared() < 100.0:
						continue
					mast = GenScatter._add(c, PropKind.RELAY, qq.floor() + Vector2(0.5, 0.5), fposmod(along.angle(), TAU))
					mast.scale = 1.0
					mast.solid = PropKind.SOLID[PropKind.RELAY]
					break
				if mast != null:
					masts.append(mast.id)
				elif masts.size() >= 2:
					w.lines.append({"kind": PropKind.RELAY, "props": masts})
					masts = PackedInt32Array()
				else:
					masts.clear()
				tt += 11.0
			if masts.size() >= 2:
				w.lines.append({"kind": PropKind.RELAY, "props": masts})
			# Stumps along both edges of the cut, where the trees were felled for it.
			var sn := Vector2(-along.y, along.x)
			var st := 2.0
			while st < length - 1.0:
				for sgn: float in [-1.0, 1.0]:
					if rng.randf() < 0.55:
						_put(c, occ, PropKind.STUMP, from + along * (st + rng.randf_range(-0.4, 0.4)) + sn * sgn * rng.randf_range(3.1, 3.8), rng.randf() * TAU, -99, 0.0)
				st += 2.6
	# Clearcuts in exact squares: stumps in the harvester's rows, the wood
	# standing thick round the edge, a warning at the corner.
	for n in _n(c, 3.0):
		var p := _site(c, rng, cc, 7, 1, [Ground.NEEDLES, Ground.GRASS, Ground.HEATH], 28.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var half := rng.randf_range(6.0, 8.5)
		var dd := d if n % 2 == 0 else nrm
		var dn := Vector2(-dd.y, dd.x)
		var steps := floori(half)
		for gy in range(-steps, steps + 1, 2):
			for gx in range(-steps, steps + 1, 2):
				var q := at + dd * float(gx) + dn * float(gy)
				var st := _put(c, occ, PropKind.STUMP, q, rng.randf() * TAU, -99, 0.0)
				if st != null:
					st.scale = 0.9 + rng.randf() * 0.25
		_clear_rect(c, occ, at, dd, Vector2(half + 0.5, half + 0.5))
		_record(c, &"clearcut", at, dd, Vector2(half + 0.5, half + 0.5), CUT)
		# The sign is put by hand: its corner tile is in the cleared square.
		var corner := at + (dd + dn) * (half + 1.6)
		_put(c, occ, PropKind.SIGN, corner, (dd + dn).angle(), -99, 0.0)
	# Fire towers on the rises, a hunting blind below, a grave for whoever kept it.
	for n in _n(c, 2.0):
		var found: Array = []
		for attempt in 40:
			var p := _site(c, rng, cc, 3, 1, [], 30.0, 20, 0.4)
			if p.x >= 0:
				found.append([c.rise[p.y * c.size + p.x], p])
		found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		var tower: WorldProp = null
		for f: Array in found:
			tower = _put(c, occ, PropKind.FIRE_TOWER, Vector2(f[1] as Vector2i) + Vector2(0.5, 0.5), d.angle(), -99, 0.8, true)
			if tower != null:
				break
		if tower == null:
			continue
		var at := tower.pos
		_record(c, &"fire_tower", at, d, Vector2(2.0, 2.0))
		_about(c, occ, rng, PropKind.SHACK, at, 1, 3.0, 6.0)
		_about(c, occ, rng, PropKind.GRAVE, at, 1, 2.5, 5.0)
	# A burned grove: dead trees standing close in scorched ground.
	for n in _n(c, 1.5):
		var p := _site(c, rng, cc, 6, 1, [Ground.NEEDLES, Ground.GRASS], 28.0, 600, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var r := rng.randf_range(5.0, 7.0)
		_about(c, occ, rng, PropKind.DEAD_TREE, at, 10, 0.5, r)
		_about(c, occ, rng, PropKind.STUMP, at, 4, 0.5, r)
		_clear_rect(c, occ, at, d, Vector2(r, r * 0.8))
		_record(c, &"burned_grove", at, d, Vector2(r, r * 0.8), SCORCH)


# --- the snowfield -----------------------------------------------------------------

static func _snowfield(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator, d: Vector2) -> void:
	var cc := Country.SNOWFIELD
	var w := c.w
	var nrm := Vector2(-d.y, d.x)
	# A checkpoint on a road through the snow: its boom across the way, snow
	# fence running off either side, a barricade, a sign before it.
	var done := 0
	for road in w.roads:
		if done >= _n(c, 2.0):
			break
		for j in range(4, road.size() - 4, 6):
			var q := road[j]
			var i := floori(q.y) * c.size + floori(q.x)
			if w.country[i] != cc or w.blend[i] > 0.4 or GenScatter._near_landmark(w, q, 30.0) or GenScatter._near_village(w, q, 20.0):
				continue
			var along := (road[j + 2] - road[j - 2]).normalized()
			var across := Vector2(-along.y, along.x)
			var booth := _put(c, occ, PropKind.CHECKPOINT, q - across * 2.0, along.angle(), -99, 0.6, true)
			if booth == null:
				booth = _put(c, occ, PropKind.CHECKPOINT, q + across * 2.0, (-along).angle(), -99, 0.6, true)
				across = -across
			if booth == null:
				continue
			_record(c, &"checkpoint", q, along, Vector2(3.0, 3.0))
			_run(c, occ, rng, PropKind.FENCE, q - across * 3.4, -across, 3, 2.0, -99, 0.1)
			_run(c, occ, rng, PropKind.FENCE, q + across * 2.2, across, 3, 2.0, -99, 0.1)
			_put(c, occ, PropKind.BARRICADE, q + across * 2.0 + along * 1.5, along.angle(), -99, 0.4)
			_put(c, occ, PropKind.SIGN, q - across * 1.8 - along * 4.0, (-along).angle(), -99, 0.2)
			done += 1
			break
	for attempt in 10:
		if done > 0:
			break
		# No road through the snow took one: it stands on the open field anyway.
		var p := _site(c, rng, cc, 4 if attempt < 5 else 2, 1, [], 30.0 if attempt < 5 else 10.0, 500, 0.5)
		if p.x >= 0:
			var at := Vector2(p) + Vector2(0.5, 0.5)
			if _put(c, occ, PropKind.CHECKPOINT, at, d.angle(), -99, 0.6, true) != null:
				_record(c, &"checkpoint", at, d, Vector2(3.0, 3.0))
				_run(c, occ, rng, PropKind.FENCE, at - nrm * 1.5, -nrm, 4, 2.0, -99, 0.1)
				done += 1
	# The tall stack, fenced, seen from everywhere.
	var stacks := 0
	for attempt in 8:
		if stacks >= _n(c, 1.0):
			break
		var p := _site(c, rng, cc, 6 if attempt < 4 else 3, 1, [], 44.0 if attempt < 4 else 16.0, 500, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		if _put(c, occ, PropKind.STACK, at, d.angle(), -99, 1.2 if attempt < 4 else 0.8, true) == null:
			continue
		stacks += 1
		_record(c, &"stack", at, d, Vector2(4.5, 4.5))
		for side in 4:
			var e := d.rotated(side * PI * 0.5)
			var en := Vector2(-e.y, e.x)
			_run(c, occ, rng, PropKind.FENCE, at + e * 4.5 - en * 4.5, en, 4 if side != 2 else 2, 2.25, -99, 0.1)
		_about(c, occ, rng, PropKind.DEBRIS, at, 2, 5.5, 8.0)
		_put(c, occ, PropKind.SIGN, at - d * 6.0, (-d).angle(), -99, 0.2)
	# A convoy that never got through: vehicles buried in a line, a snow fence.
	for n in _n(c, 1.0):
		var p := _site(c, rng, cc, 5, 1, [Ground.SNOW], 30.0, 600, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var placed := 0
		for i in 4:
			if _put(c, occ, PropKind.VEHICLE, at + d * (i * 3.4 - 5.0) + nrm * rng.randf_range(-0.3, 0.3), d.angle() + rng.randf_range(-0.15, 0.15), -99, 0.8) != null:
				placed += 1
		if placed > 0:
			_record(c, &"convoy", at, d, Vector2(7.0, 2.0))
			_run(c, occ, rng, PropKind.FENCE, at - d * 6.0 + nrm * 2.5, d, 6, 2.0, -99, 0.2)
	# Emergency shelters, a grave by each.
	for n in _n(c, 2.0):
		var p := _site(c, rng, cc, 3, 1, [], 26.0, 500, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		if _put(c, occ, PropKind.SHACK, at, rng.randf() * TAU, -99, 1.0) == null:
			continue
		_record(c, &"shelter", at, d, Vector2(2.0, 2.0))
		_about(c, occ, rng, PropKind.GRAVE, at, 1, 2.5, 4.0)


# --- the bonelands -----------------------------------------------------------------

static func _bonelands(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator, d: Vector2) -> void:
	var cc := Country.BONELANDS
	var nrm := Vector2(-d.y, d.x)
	var pale: Array = [Ground.LIMESTONE, Ground.BONE, Ground.GRAVEL, Ground.GRASS, Ground.SCREE, Ground.HEATH]
	# Quarries cut in the grid: benches in exact squares, drills standing in
	# them, a conveyor carrying the stone off along the bearing.
	for n in _n(c, 2.0):
		var p := _site(c, rng, cc, 7, 1, pale, 30.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var half := Vector2(rng.randf_range(7.0, 9.0), rng.randf_range(5.0, 6.5))
		_record(c, &"quarry", at, d, half, QUARRY)
		for gy in range(-1, 2):
			for gx in range(-2, 3):
				if rng.randf() < 0.35:
					continue
				_put(c, occ, PropKind.DRILL_RIG, at + d * gx * 3.0 + nrm * gy * 3.0, d.angle(), -99, 0.3, true)
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				_put(c, occ, PropKind.SURVEY, at + d * half.x * sx + nrm * half.y * sy, d.angle(), -99, 0.0, true)
		_run(c, occ, rng, PropKind.CONVEYOR, at + d * (half.x + 0.5), d, rng.randi_range(5, 8), 2.5, -99, 0.1)
		_put(c, occ, PropKind.SIGN, at - d * (half.x + 1.5), (-d).angle(), -99, 0.2)
		_about(c, occ, rng, PropKind.DEBRIS, at, 2, half.y, half.x)
	# Drill fields: bores in an exact grid, capped or still drilling, the
	# survey posts that laid them out.
	for n in _n(c, 2.0):
		var p := _site(c, rng, cc, 7, 1, pale, 30.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var half := Vector2(8.0, 6.0)
		_record(c, &"drill_field", at, nrm, half, BORES)
		for gy in range(-2, 3):
			for gx in range(-3, 4):
				var q := at + nrm * gx * 2.6 + d * gy * 2.6
				if (gx + gy) % 3 == 0:
					_put(c, occ, PropKind.SURVEY, q, nrm.angle(), -99, 0.0, true)
				else:
					_put(c, occ, PropKind.DRILL_RIG, q, nrm.angle(), -99, 0.2, true)
	# Cisterns where people keep water, a lean-to by each, a fence, a grave.
	for n in _n(c, 2.0):
		var p := _site(c, rng, cc, 4, 1, [], 26.0, 500, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		if _put(c, occ, PropKind.WATER_TANK, at, rng.randf() * TAU, -99, 0.8) == null:
			continue
		_record(c, &"cistern", at, d, Vector2(3.0, 3.0))
		_about(c, occ, rng, PropKind.SHACK, at, 1, 2.8, 4.5)
		_run(c, occ, rng, PropKind.FENCE, at + Vector2(-3.0, 3.0), Vector2.from_angle(rng.randf() * TAU), 3, 2.0, -99, 0.3)
		_about(c, occ, rng, PropKind.GRAVE, at, 1, 4.0, 6.0)


# --- the burning -------------------------------------------------------------------

static func _burning(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator, d: Vector2) -> void:
	var cc := Country.BURNING
	var w := c.w
	var nrm := Vector2(-d.y, d.x)
	var dry: Array = [Ground.ASH, Ground.CLINKER, Ground.GRAVEL, Ground.ROCK, Ground.SCREE, Ground.GRASS, Ground.HEATH]
	# Slag heaps tipped in a line along the bearing, a scorched car by them.
	for n in _n(c, 2.0):
		var p := _site(c, rng, cc, 6, 1, dry, 30.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var heaps := 0
		for i in rng.randi_range(3, 4):
			if _put(c, occ, PropKind.SLAG_HEAP, at + d * (i * 3.6 - 5.0), d.angle(), -99, 1.0, true) != null:
				heaps += 1
		if heaps == 0:
			continue
		_record(c, &"slag", at, d, Vector2(7.5, 3.0), SCORCH)
		_about(c, occ, rng, PropKind.VEHICLE, at + nrm * 4.0, 1, 0.0, 2.5)
		_about(c, occ, rng, PropKind.DEBRIS, at, 2, 3.0, 6.0)
	# Refinery runs: parallel pipelines, collapsed in stretches, vents capped.
	for n in _n(c, 1.5):
		var p := _site(c, rng, cc, 6, 1, dry, 30.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var runs := rng.randi_range(2, 3)
		var length := rng.randi_range(7, 10)
		for r in runs:
			_run(c, occ, rng, PropKind.PIPE, at - d * length + nrm * (r - (runs - 1) * 0.5) * 1.7, d, length, 2.0, -99, 0.12)
		_record(c, &"refinery", at, d, Vector2(length + 1.0, runs * 1.2), SCORCH)
		_about(c, occ, rng, PropKind.VENT_CAP, at + nrm * (runs * 1.2 + 2.0), 2, 0.0, 3.5)
	# The clerks' archive: cabinets in exact rows standing in the ash.
	var archives := 0
	for attempt in 8:
		if archives >= _n(c, 1.0):
			break
		var p := _site(c, rng, cc, 5 if attempt < 4 else 3, 1, dry if attempt < 4 else [], 34.0 if attempt < 4 else 14.0, 600, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var placed := 0
		for gy in range(-1, 2):
			for gx in range(-1, 2):
				if rng.randf() < 0.25:
					continue
				if _put(c, occ, PropKind.ARCHIVE, at + d * gx * 2.4 + nrm * gy * 2.4, d.angle(), -99, 0.4, true) != null:
					placed += 1
		if placed == 0:
			continue
		archives += 1
		_record(c, &"archive", at, d, Vector2(4.0, 4.0), SCORCH)
		_put(c, occ, PropKind.SIGN, at - d * 4.5, (-d).angle(), -99, 0.2)
	# The machines bolted caps on the vents of the fumaroles.
	for m in w.landmarks:
		if m.kind != &"fumarole":
			continue
		var at: Vector2 = m.pos
		for sgn: float in [-1.0, 1.0]:
			_put(c, occ, PropKind.VENT_CAP, at + d * sgn * 2.2, d.angle(), -99, 0.4, true)
	# A dugout by the heat.
	for n in _n(c, 1.0):
		var p := _site(c, rng, cc, 3, 1, dry, 24.0, 500, 0.45)
		if p.x >= 0 and _put(c, occ, PropKind.SHACK, Vector2(p) + Vector2(0.5, 0.5), rng.randf() * TAU, -99, 1.0) != null:
			_record(c, &"dugout", Vector2(p) + Vector2(0.5, 0.5), d, Vector2(2.0, 2.0))


# --- people ------------------------------------------------------------------------

## Round every village: its graves in a row, a shack or two at the edge with
## stolen light in some, fences, a barricade on the way in, debris.
static func _villages(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var w := c.w
	for v in w.villages:
		var vp: Vector2 = v.pos
		# The graveyard: a row of graves a little way out, off the roads.
		for attempt in 16:
			var a := rng.randf() * TAU
			var at := vp + Vector2.from_angle(a) * rng.randf_range(11.0, 15.0)
			if _near_road(c, at, 3):
				continue
			var row := Vector2.from_angle(a + PI * 0.5)
			var graves := 0
			for i in rng.randi_range(3, 6):
				var q := at + row * (i * 1.25 - 3.0) + Vector2.from_angle(a) * rng.randf_range(-0.15, 0.15)
				if _put(c, occ, PropKind.GRAVE, q, a + rng.randf_range(-0.12, 0.12), -99, 0.3) != null:
					graves += 1
			if graves >= 2:
				_record(c, &"graves", at, row, Vector2(4.0, 1.0))
				break
		# Shacks at the edge.
		var shacks := 0
		for attempt in 40:
			if shacks >= rng.randi_range(1, 2):
				break
			var q := vp + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(12.0, 19.0)
			if _near_road(c, q, 2):
				continue
			if _put(c, occ, PropKind.SHACK, q.floor() + Vector2(0.5, 0.5), (vp - q).angle(), -99, 1.2) != null:
				shacks += 1
		# Garden fences, crooked, gapped.
		for f in 2:
			var q := vp + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, 13.0)
			_run(c, occ, rng, PropKind.FENCE, q, (q - vp).normalized().orthogonal(), rng.randi_range(2, 3), 2.0, -99, 0.2)
		_about(c, occ, rng, PropKind.DEBRIS, vp, 2, 11.0, 18.0)
	# Barricades on the ways in: beside each road where it nears a village.
	for road in w.roads:
		for end in 2:
			for k: int in [12, 15, 18, 22]:
				var j := k if end == 0 else road.size() - 1 - k
				if j < 2 or j >= road.size() - 2:
					continue
				var q := road[j]
				var along := (road[j + 1] - road[j - 1]).normalized()
				var across := Vector2(-along.y, along.x) * (1.0 if rng.randf() < 0.5 else -1.0)
				if _put(c, occ, PropKind.BARRICADE, q + across * 1.8, along.angle(), -99, 0.4) != null or _put(c, occ, PropKind.BARRICADE, q - across * 1.8, along.angle(), -99, 0.4) != null:
					break


static func _near_road(c: GenContext, p: Vector2, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if x >= 0 and y >= 0 and x < c.size and y < c.size and c.road[y * c.size + x] != 0:
				return true
	return false


## Warnings nobody reads, beside the roads, one every so often away from the
## villages; curfew boards in the pines.
static func _roads(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var w := c.w
	for road in w.roads:
		var j := 20
		while j < road.size() - 20:
			var q := road[j]
			if not GenScatter._near_village(w, q, 16.0):
				var along := (road[mini(j + 2, road.size() - 1)] - road[j - 2]).normalized()
				var across := Vector2(-along.y, along.x)
				for sgn: float in [1.0, -1.0]:
					if _put(c, occ, PropKind.SIGN, q + across * sgn * 1.7, (across * sgn).angle(), -99, 0.2) != null:
						break
			j += rng.randi_range(34, 52)


## What is left where things ended: debris round the tips, ruins and wrecks,
## a grave or a sign at some.
static func _remains(c: GenContext, occ: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var w := c.w
	var count := w.landmarks.size()
	for li in count:
		var m: Dictionary = w.landmarks[li]
		var at: Vector2 = m.pos
		match m.kind:
			&"tip", &"wreck":
				_about(c, occ, rng, PropKind.DEBRIS, at, 2, 3.0, 6.5)
				if rng.randf() < 0.5:
					_run(c, occ, rng, PropKind.FENCE, at + Vector2(-5.0, 4.0), Vector2.from_angle(rng.randf() * TAU), 3, 2.0, -99, 0.35)
			&"ruin":
				_about(c, occ, rng, PropKind.DEBRIS, at, 2, 2.0, 5.0)
				if rng.randf() < 0.6:
					_about(c, occ, rng, PropKind.GRAVE, at, 1, 3.5, 6.0)
				if rng.randf() < 0.4:
					_about(c, occ, rng, PropKind.VEHICLE, at, 1, 4.0, 7.0)


# --- the walk between places --------------------------------------------------------

## Tiles between vignette cells, and the share of cells in each country that
## hold one (sea, coast, moss, pinewood, snowfield, bonelands, burning).
const VIGNETTE_CELL := 9
const VIGNETTE_SHARE: PackedFloat32Array = [0.0, 0.75, 0.72, 0.75, 0.7, 0.75, 0.75]


## Small evidence at walking scale between the places, so any stretch of any
## landscape holds something of what happened: a fence run, a grave, a warning,
## a car left where it stopped, a few exact stumps, survey posts in a line.
## One cell in two holds a vignette; they keep off the works and the villages.
static func _vignettes(c: GenContext, occ: PackedByteArray, d: Vector2) -> void:
	var w := c.w
	var rng := Rng.make(c.s, 0x716)
	var busy := PackedByteArray()
	busy.resize(c.n)
	for m in w.landmarks:
		var k: StringName = m.kind
		if k == &"falls" or k == &"bridge" or k == &"summit":
			continue
		var half: Vector2 = m.get("half", Vector2(3.0, 3.0))
		_stamp(c, busy, m.pos, minf(maxf(half.x, half.y) + 3.0, 16.0))
	for v in w.villages:
		_stamp(c, busy, v.pos, 13.0)
	var nrm := Vector2(-d.y, d.x)
	var cell := VIGNETTE_CELL
	for cy in range(cell, c.size - cell, cell):
		for cx in range(cell, c.size - cell, cell):
			# Every roll is drawn whether it is used or not: a world comes out the same.
			var p := Vector2i(cx + rng.randi_range(0, cell - 1), cy + rng.randi_range(0, cell - 1))
			var roll := rng.randf()
			var pick := rng.randf()
			var turn := rng.randf()
			var i := p.y * c.size + p.x
			if c.land[i] == 0 or busy[i] != 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0:
				continue
			var cc := int(w.country[i])
			if roll > VIGNETTE_SHARE[cc]:
				continue
			var at := Vector2(p) + Vector2(0.5, 0.5)
			var along := d if turn < 0.5 else nrm
			var loose := Vector2.from_angle(turn * TAU)
			match cc:
				Country.COAST:
					if pick < 0.26:
						_run(c, occ, rng, PropKind.FENCE, at, loose, 2 + int(turn * 3.0), 2.0, -99, 0.25)
					elif pick < 0.42:
						_put(c, occ, PropKind.GRAVE, at, turn * TAU, -99, 0.3)
					elif pick < 0.58:
						_put(c, occ, PropKind.SIGN, at, turn * TAU, -99, 0.2)
					elif pick < 0.72:
						if _put(c, occ, PropKind.VEHICLE, at, turn * TAU, -99, 0.8) != null:
							_about(c, occ, rng, PropKind.DEBRIS, at, 1, 2.0, 3.5)
					elif pick < 0.88:
						_put(c, occ, PropKind.DEBRIS, at, turn * TAU, -99, 0.5)
					else:
						_put(c, occ, PropKind.BARRICADE, at, turn * TAU, -99, 0.5)
				Country.MOSS:
					if pick < 0.3:
						_run(c, occ, rng, PropKind.FENCE, at, loose, 2 + int(turn * 2.0), 2.0, -99, 0.3)
					elif pick < 0.48:
						_put(c, occ, PropKind.GRAVE, at, turn * TAU, -99, 0.3)
					elif pick < 0.62:
						_put(c, occ, PropKind.VEHICLE, at, turn * TAU, -99, 0.8)
					elif pick < 0.8:
						_run(c, occ, rng, PropKind.PIPE, at, d, 2 + int(turn * 2.0), 2.0, -99, 0.2)
					else:
						_put(c, occ, PropKind.SIGN, at, turn * TAU, -99, 0.2)
				Country.PINEWOOD:
					if pick < 0.36:
						# A small cut in the wood: stumps in the harvester's rows.
						var n := 2 + int(turn * 2.0)
						for gy in 2:
							for gx in n:
								_put(c, occ, PropKind.STUMP, at + d * (gx * 2.0) + nrm * (gy * 2.0), rng.randf() * TAU, -99, 0.0)
						_clear_rect(c, occ, at + d * (n - 1) + nrm, d, Vector2(n + 0.4, 1.9))
					elif pick < 0.52:
						_put(c, occ, PropKind.SIGN, at, turn * TAU, -99, 0.2)
					elif pick < 0.64:
						_put(c, occ, PropKind.VEHICLE, at, turn * TAU, -99, 0.8)
					elif pick < 0.78:
						_run(c, occ, rng, PropKind.FENCE, at, loose, 2 + int(turn * 2.0), 2.0, -99, 0.3)
					elif pick < 0.9:
						_put(c, occ, PropKind.GRAVE, at, turn * TAU, -99, 0.3)
					else:
						_put(c, occ, PropKind.DEBRIS, at, turn * TAU, -99, 0.4)
				Country.SNOWFIELD:
					if pick < 0.36:
						_run(c, occ, rng, PropKind.FENCE, at, along, 3 + int(turn * 3.0), 2.0, -99, 0.12)
					elif pick < 0.52:
						_put(c, occ, PropKind.VEHICLE, at, turn * TAU, -99, 0.8)
					elif pick < 0.66:
						_put(c, occ, PropKind.SIGN, at, turn * TAU, -99, 0.2)
					elif pick < 0.8:
						for k in 2:
							_put(c, occ, PropKind.SURVEY, at + along * (k * 3.0), along.angle(), -99, 0.0, true)
					elif pick < 0.92:
						_put(c, occ, PropKind.GRAVE, at, turn * TAU, -99, 0.3)
					else:
						_put(c, occ, PropKind.DEBRIS, at, turn * TAU, -99, 0.4)
				Country.BONELANDS:
					if pick < 0.3:
						for k in 3:
							_put(c, occ, PropKind.SURVEY, at + along * (k * 3.0), along.angle(), -99, 0.0, true)
					elif pick < 0.44:
						_put(c, occ, PropKind.DRILL_RIG, at, d.angle(), -99, 0.3, true)
					elif pick < 0.6:
						_put(c, occ, PropKind.DEBRIS, at, turn * TAU, -99, 0.4)
					elif pick < 0.72:
						_put(c, occ, PropKind.SIGN, at, turn * TAU, -99, 0.2)
					elif pick < 0.84:
						_put(c, occ, PropKind.VEHICLE, at, turn * TAU, -99, 0.8)
					else:
						_run(c, occ, rng, PropKind.FENCE, at, loose, 2 + int(turn * 2.0), 2.0, -99, 0.3)
				Country.BURNING:
					if pick < 0.26:
						if _put(c, occ, PropKind.VEHICLE, at, turn * TAU, -99, 0.8) != null:
							_about(c, occ, rng, PropKind.DEBRIS, at, 1, 2.0, 3.5)
					elif pick < 0.44:
						_put(c, occ, PropKind.VENT_CAP, at, d.angle(), -99, 0.4, true)
					elif pick < 0.6:
						_put(c, occ, PropKind.DEBRIS, at, turn * TAU, -99, 0.4)
					elif pick < 0.7:
						_put(c, occ, PropKind.ARCHIVE, at, d.angle(), -99, 0.5, true)
					elif pick < 0.84:
						_run(c, occ, rng, PropKind.PIPE, at, d, 2, 2.0, -99, 0.2)
					else:
						_put(c, occ, PropKind.SIGN, at, turn * TAU, -99, 0.2)


## The survey: the machines' lines laid across the whole island on the bearing
## and across it, SURVEY_ALONG and SURVEY_ACROSS tiles apart, surviving in
## broken stretches of SURVEY_SECTION tiles. Pure in (seed, size), so the
## renderer (WorksMap) finds the same lines the generator dressed.
const SURVEY_ALONG := 41.0
const SURVEY_ACROSS := 59.0
const SURVEY_SECTION := 24.0
const SURVEY_KEEP := 0.5


## Where the survey's line families sit: x the offset of the lines along the
## bearing (across it), y of the lines across it (along it).
static func survey_phase(seed_value: int) -> Vector2:
	return Vector2(Rng.hash01(seed_value, 0x5A1, 1) * SURVEY_ALONG, Rng.hash01(seed_value, 0x5A1, 2) * SURVEY_ACROSS)


## Every surviving stretch of the survey as [from: Vector2, to: Vector2, family: int].
static func survey_sections(seed_value: int, size: int) -> Array:
	var out: Array = []
	var d := Vector2.from_angle(bearing(seed_value))
	var nrm := Vector2(-d.y, d.x)
	var phase := survey_phase(seed_value)
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(size, 0), Vector2(0, size), Vector2(size, size)]
	for family in 2:
		var run_dir := d if family == 0 else nrm
		var off_dir := nrm if family == 0 else d
		var spacing := SURVEY_ALONG if family == 0 else SURVEY_ACROSS
		var lo := 1e9
		var hi := -1e9
		var ulo := 1e9
		var uhi := -1e9
		for q in corners:
			lo = minf(lo, q.dot(off_dir))
			hi = maxf(hi, q.dot(off_dir))
			ulo = minf(ulo, q.dot(run_dir))
			uhi = maxf(uhi, q.dot(run_dir))
		var k0 := floori((lo - phase[family]) / spacing)
		var k1 := ceili((hi - phase[family]) / spacing)
		for k in range(k0, k1 + 1):
			var v := phase[family] + k * spacing
			var s0 := floori(ulo / SURVEY_SECTION)
			var s1 := ceili(uhi / SURVEY_SECTION)
			for sec in range(s0, s1):
				if Rng.hash01(seed_value, family, k + 5000, sec + 5000) >= SURVEY_KEEP:
					continue
				var a := run_dir * (sec * SURVEY_SECTION) + off_dir * v
				var b := a + run_dir * SURVEY_SECTION
				out.append([a, b, family])
	return out


## The survey dressed by each landscape: a lane cut through the pines, snow
## fence along it on the snowfield, posts at its stations, pipe on it in the
## burning. The ground's own marks for it are drawn by world.gdshader.
static func _survey(c: GenContext, occ: PackedByteArray) -> void:
	var w := c.w
	var rng := Rng.make(c.s, 0x5A2)
	for sec: Array in survey_sections(c.s, c.size):
		var a: Vector2 = sec[0]
		var b: Vector2 = sec[1]
		var dir := (b - a).normalized()
		var mid := (a + b) * 0.5
		if mid.x < 0.0 or mid.y < 0.0 or mid.x >= c.size or mid.y >= c.size:
			continue
		var roll := rng.randf()
		var cc := int(w.country_at(floori(mid.x), floori(mid.y)))
		if cc == Country.PINEWOOD:
			# The lane stays open where it runs through the wood.
			var t := 0.0
			while t <= SURVEY_SECTION:
				var q := a + dir * t
				if q.x >= 1.0 and q.y >= 1.0 and q.x < c.size - 1 and q.y < c.size - 1 and w.country_at(floori(q.x), floori(q.y)) == Country.PINEWOOD:
					_clear_rect(c, occ, q, dir, Vector2(0.5, 1.3))
				t += 1.0
		# Stations: a post where the survey was read, now and then.
		var st := 4.0 + rng.randf() * 6.0
		while st < SURVEY_SECTION:
			if rng.randf() < 0.45:
				_put(c, occ, PropKind.SURVEY, a + dir * st, dir.angle(), -99, 0.0, true)
			st += 8.0 + rng.randf() * 4.0
		match cc:
			Country.SNOWFIELD:
				if roll < 0.5:
					_run(c, occ, rng, PropKind.FENCE, a + dir * (4.0 + roll * 8.0) + Vector2(-dir.y, dir.x) * 1.2, dir, 4, 2.0, -99, 0.15)
			Country.BURNING:
				if roll < 0.35:
					_run(c, occ, rng, PropKind.PIPE, a + dir * (4.0 + roll * 10.0) + Vector2(-dir.y, dir.x) * 1.0, dir, 3, 2.0, -99, 0.25)
			Country.BONELANDS:
				if roll < 0.3:
					_put(c, occ, PropKind.DRILL_RIG, mid + Vector2(-dir.y, dir.x) * 1.4, dir.angle(), -99, 0.3, true)
			Country.COAST, Country.MOSS:
				if roll < 0.25:
					_put(c, occ, PropKind.SIGN, mid + Vector2(-dir.y, dir.x) * 1.5, dir.angle() + PI * 0.5, -99, 0.2)


## Mark the tiles within a square of half side r round p.
static func _stamp(c: GenContext, mask: PackedByteArray, p: Vector2, r: float) -> void:
	var ri := ceili(r)
	var x0 := maxi(0, floori(p.x) - ri)
	var x1 := mini(c.size - 1, floori(p.x) + ri)
	var y0 := maxi(0, floori(p.y) - ri)
	var y1 := mini(c.size - 1, floori(p.y) + ri)
	for y in range(y0, y1 + 1):
		var row := y * c.size
		for x in range(x0, x1 + 1):
			mask[row + x] = 1
