class_name GenWorks
## Stage 12b (inside GenScatter.props: after the grid, before the scatter): what
## every landscape holds of what happened to it (docs/VISION.md section 8).
##
## Two hands lay it. The machines lay their works on one survey bearing across
## the whole island (bearing()): turf cut in rows on the coast, drainage cuts and
## pipelines through the moss, clearcuts in exact squares and a relay corridor
## through the pines, drill grids and conveyors on the bonelands, slag and
## refinery runs in the burning, checkpoints and a stack on the snowfield.
## People leave the rest where they can: graves and shacks and fences by every
## village, barricades on the ways in, signs along the roads, wrecks and debris
## where things ended, and small compositions at walking scale between every
## place (a debris field, a fence corner gone over, graves round a memorial, a
## wreck in pieces). Ruled works run straight through chaotic ground; the hand's
## things lean and gap.
##
## What each landscape holds is data keyed by its type (BiomeDef id, asked of
## BiomeRegistry.at per tile): EVIDENCE names its works, its walking-scale
## compositions and how it dresses the survey. A type with no row gets GENERIC
## (the hand's remains, no works); a new type adds its own with register().
##
## Every work is recorded as a landmark {kind, pos, country, dir, half, mark}:
## `dir` its bearing, `half` its half extents along and across it, `mark` the
## ground mark renderers lay under it (&"cut", &"scorch", &"quarry", &"bores";
## WorksMap). Sites keep off villages, roads, water and each other; their props
## keep the spawn's first steps clear. Runs and grids stand at scale 1 so their
## order is exact.

## THE PLAN'S RUNS, WHICH NOBODY MAY SCATTER. A pipe, a conveyor and a drill rig
## are laid by this file in RUNS -- ruled on the survey bearing, at scale exactly
## 1, so a line of them reads as one thing the machines built rather than as
## litter. `tests/core/test_world_gen_works.gd` holds every one of them in the
## world to that, and a single loose one turned a random way fails it for the
## whole island.
##
## All three are already in `GenScatter.PLACED`, so a landscape never has to ask
## for them: the works stage may put them anywhere. That means naming one in
## `BiomeDef.props` buys exactly one thing -- permission for that landscape's own
## `_scatter` to DEAL one, at a random angle -- and there is no case where that is
## what anybody wanted. So the declaration is the bug, and `BiomeRegistry.problems`
## fails on it by name. A landscape that wants pipe on its ground asks for the
## `pipe_run` vignette in its `GenWorks.register` row, which lays a real run.
##
## Learned once in `slums.gd`, in a comment inside one landscape's scatter, where
## the next four authors never saw it -- and four of them did it again.
## How far a checkpoint's booth may stand from the ROAD'S EDGE and still be a gate
## ON that road. The booth sits off the carriageway with its boom swinging over
## it, so it is never ON the road; this is how far off is still "at" it.
##
## It was three bare numbers for one rule and they did not agree: the placer
## offered offsets of 2.2 and 2.7 tiles from the road's centre line, and the test
## demanded 2.01 from the road's nearest SQUARE. 2.2 clears it once the half tile
## from centre to edge is taken off; **2.7 cannot, ever** -- it was a fallback
## that could only ever place a booth the rule forbids, and it did, on seed 90210.
## So the placer proves this now instead of the test discovering the breach.
const CHECKPOINT_AT_ROAD := 2.0

const RUNS: Array[int] = [PropKind.PIPE, PropKind.CONVEYOR, PropKind.DRILL_RIG]

const CUT := &"cut"
const SCORCH := &"scorch"
const QUARRY := &"quarry"
const BORES := &"bores"

## Per landscape type (BiomeDef id):
##   "works"      the static func that lays its machine works (takes a Lay), on
##                GenWorks or on "host" when a row registered from elsewhere names one
##   "vignettes"  [weight, composition] drawn between places (_compose)
##   "survey"     [chance, dressing] where the survey crosses it (_survey)
const EVIDENCE := {
	&"coast": {
		"works": &"_coast",
		"vignettes": [[5, &"debris_field"], [4, &"wreck"], [4, &"fence_corner"], [3, &"grave_cluster"], [3, &"tipped_signs"], [2, &"barricade"], [2, &"wreck_parts"], [2, &"nets"], [1, &"shelter"]],
		"survey": [[0.25, &"sign_beside"]],
	},
	&"moss": {
		"works": &"_moss",
		"vignettes": [[4, &"sunk_wreck"], [4, &"fence_corner"], [3, &"grave_cluster"], [3, &"pipe_run"], [3, &"debris_field"], [2, &"tipped_signs"], [2, &"wreck_parts"], [1, &"shelter"]],
		"survey": [[0.25, &"sign_beside"]],
	},
	&"pinewood": {
		"works": &"_pinewood",
		"vignettes": [[5, &"stump_rows"], [3, &"wreck"], [3, &"fence_corner"], [3, &"grave_cluster"], [2, &"tipped_signs"], [2, &"debris_field"], [2, &"wreck_parts"], [1, &"shelter"]],
		"survey": [[1.0, &"lane"]],
	},
	&"snowfield": {
		"works": &"_snowfield",
		"vignettes": [[4, &"snow_fence"], [4, &"wreck"], [3, &"grave_cluster"], [3, &"debris_field"], [2, &"survey_posts"], [2, &"tipped_signs"], [2, &"wreck_parts"], [1, &"fence_corner"]],
		"survey": [[0.5, &"snow_fence_line"]],
	},
	&"bonelands": {
		"works": &"_bonelands",
		"vignettes": [[4, &"survey_posts"], [3, &"drill"], [4, &"debris_field"], [3, &"wreck"], [3, &"grave_cluster"], [2, &"tipped_signs"], [2, &"fence_corner"], [2, &"wreck_parts"]],
		"survey": [[0.3, &"drill_beside"]],
	},
	&"burning": {
		"works": &"_burning",
		"vignettes": [[5, &"wreck"], [4, &"debris_field"], [3, &"vent"], [3, &"burnt_archive"], [3, &"wreck_parts"], [2, &"pipe_run"], [2, &"tipped_signs"], [2, &"grave_cluster"], [1, &"barricade"]],
		"survey": [[0.35, &"pipe_line"]],
	},
}

## What a landscape type holds when it registers nothing of its own.
const GENERIC := {
	"works": &"",
	"vignettes": [[4, &"debris_field"], [3, &"wreck"], [3, &"fence_corner"], [3, &"grave_cluster"], [2, &"tipped_signs"], [2, &"wreck_parts"], [1, &"barricade"]],
	"survey": [[0.2, &"sign_beside"]],
}

## Rows added by other packages (register()), read before EVIDENCE.
static var _registered: Dictionary = {}


## Give a landscape type its own evidence, in EVIDENCE's shape (keys it leaves
## out come from GENERIC). Register before worlds are generated.
static func register(id: StringName, entry: Dictionary) -> void:
	_registered[id] = entry


## A landscape type's evidence row (EVIDENCE's shape, every key present).
static func evidence(id: StringName) -> Dictionary:
	var e: Dictionary = _registered.get(id, EVIDENCE.get(id, GENERIC))
	if not (e.has("works") and e.has("vignettes") and e.has("survey")):
		var full := GENERIC.duplicate()
		full.merge(e, true)
		return full
	return e


## The machines' survey bearing for a world (radians): every ruled work lies
## along it or across it, 11 to 31 degrees off the tile axes so no row ever
## follows the tile grid.
static func bearing(seed_value: int) -> float:
	return 0.2 + Rng.hash01(seed_value, 0xBEA, 7) * 0.35


## What laying one landscape's evidence needs: the generator's context, the
## occupancy grid, a sequence, the survey bearing, and which landscape type each
## tile is (BiomeRegistry.at, asked once per tile and only for tiles looked at).
class Lay:
	var c: GenContext
	var w: WorldData
	var occ: PackedByteArray
	var rng: RandomNumberGenerator
	## The survey bearing, and across it.
	var d: Vector2
	var nrm: Vector2
	## The type being laid (empty while laying what every type shares).
	var id: StringName = &""
	## Lay small things that can be walked through on any free tile, however
	## close to others (the crowded ground round the spawn).
	var tight := false
	var _ids: Array[StringName] = []
	var _type: PackedByteArray

	func _init(ctx: GenContext, o: PackedByteArray, bearing_dir: Vector2) -> void:
		c = ctx
		w = ctx.w
		occ = o
		d = bearing_dir
		nrm = Vector2(-d.y, d.x)
		_type.resize(ctx.n)

	func type_at(x: int, y: int) -> StringName:
		var i := y * c.size + x
		var t := _type[i]
		if t == 0:
			var def := BiomeRegistry.at(w, Vector2(x + 0.5, y + 0.5))
			var k := _ids.find(def.id)
			if k < 0:
				_ids.append(def.id)
				k = _ids.size() - 1
			t = k + 1
			_type[i] = t
		return _ids[t - 1]

	## Tile (x, y) is of the type being laid.
	func home(x: int, y: int) -> bool:
		return type_at(x, y) == id


static func place(c: GenContext, occ: PackedByteArray) -> void:
	# NOT IN A YEAR BEFORE THEY BEGAN. Everything this file lays is the machines'
	# — ruled on their survey bearing, keeping their hours — and in 2029 there is
	# no plan to have laid it. The land underneath is identical either way, which
	# is what `Realm.same_land_as` is for; this is the sixty-nine years.
	if Realm.before_the_plan(c.w.realm):
		return
	var lay := Lay.new(c, occ, Vector2.from_angle(bearing(c.s)))
	for def in BiomeRegistry.all():
		var row := evidence(def.id)
		var fn: StringName = row.works
		if fn == &"":
			continue
		lay.id = def.id
		lay.rng = Rng.make(c.s, 0x3057 + String(def.id).hash() % 65521)
		var host: Object = row.get("host", GenWorks)
		Callable(host, fn).call(lay)
		c.mark(StringName("works." + String(def.id)))
	lay.id = &""
	lay.rng = Rng.make(c.s, 0x3058)
	_villages(lay)
	_roads(lay)
	_remains(lay)
	c.mark(&"works.people")
	_spawn_view(lay)
	_survey(lay)
	_vignettes(lay)
	c.mark(&"works.vignettes")


# --- helpers ---------------------------------------------------------------------

## How many of a thing a world of this size gets.
static func _n(c: GenContext, base: float) -> int:
	return maxi(1, roundi(base * maxf(c.body_k, 0.3)))


## How hard a landscape's works have to look for room. 1 at the six landscapes
## the world was tuned for; every landscape the registry adds leaves each of
## them less ground, so each has to search further to find its own.
static func effort(c: GenContext) -> float:
	return maxf(1.0, float(c.land_types.size()) / 6.0)


## A site in the type being laid: flat within r (levels differ by at most
## `rise`), dry, roadless, clear of villages and other places by `apart`, its
## middle tile on one of `grounds` (any, if empty) and heart-side of any
## ecotone. The last part of the search settles for less room, rougher ground
## and any ground, so every landscape gets its works on every seed.
static func _site(L: Lay, r: int, rise: int, grounds: Array, apart: float, attempts: int = 500, blend_max: float = 0.35) -> Vector2i:
	var c := L.c
	var w := L.w
	attempts = roundi(attempts * effort(c))
	var strict := int(attempts * 0.55)
	for attempt in attempts * 2:
		var p := GenScatter._random_tile(c, L.rng)
		var i := p.y * c.size + p.x
		var loose := attempt >= strict
		if c.land[i] == 0 or w.blend[i] > (blend_max if not loose else blend_max + 0.1) or not L.home(p.x, p.y):
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
		if k == &"falls" or k == &"bridge" or k == &"summit" or k == &"graves" or k == &"stolen_light" or k == &"iced_line":
			continue
		if (m.pos as Vector2).distance_squared_to(p) < d2:
			return true
	return false


static func _record(c: GenContext, kind: StringName, p: Vector2, dir: Vector2, half: Vector2, mark: StringName = &"") -> void:
	var at := Vector2i(clampi(floori(p.x), 0, c.size - 1), clampi(floori(p.y), 0, c.size - 1))
	# `region` goes on the row here too (`WorldData.landmarks`): a works mark is
	# the busiest of these and is what a depot is sited at, so whoever asks which
	# place a yard belongs to must not have to work it out from a position.
	var m := {"kind": kind, "pos": p, "country": int(c.w.country[at.y * c.size + at.x]),
		"region": c.w.region_at(at.x, at.y), "dir": dir, "half": half}
	if mark != &"":
		m["mark"] = mark
	c.w.landmarks.append(m)


## Put one prop at p if the ground there takes it: dry land off roads and
## villages, free of other things within `clear`, on terrace `level` (any when
## -99), and never in the spawn's first steps. `exact` stands it at scale 1.
## A solid stands on one level unless `berthed` (its caller has checked the
## ground under its whole length).
static func _put(L: Lay, kind: int, p: Vector2, rot: float, level: int = -99, clear: float = 0.5, exact: bool = false, berthed: bool = false) -> WorldProp:
	var c := L.c
	var w := L.w
	var tx := floori(p.x)
	var ty := floori(p.y)
	if tx < 3 or ty < 3 or tx >= c.size - 3 or ty >= c.size - 3:
		return null
	var i := ty * c.size + tx
	if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or c.ramp[i] != 0:
		return null
	if Ground.is_water(w.ground[i]):
		return null
	if not GenScatter._free(c, L.occ, p, clear):
		return null
	var l := w.level[i]
	if level != -99 and l != level:
		return null
	for v in w.villages:
		# THE VILLAGE IS A LOBE (`GenSettle.village_core`). This kept a CIRCLE of
		# `radius` clear, and the village's own ground reaches 11.4 tiles where the
		# circle stops at 9.5, so a barricade, a fence or a survey post could be
		# stood on ground the village had already claimed -- outside the number
		# this asked, inside the place.
		var away: Vector2 = p - (v.pos as Vector2)
		if away.length() < GenSettle.village_core(c.s, v, away.angle()) + 0.8:
			return null
	if PropKind.SOLID[kind] > 0.0 and not berthed:
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
	GenScatter._occupy(c, L.occ, p, maxf(PropKind.SOLID[prop.kind] * prop.scale, 0.0))
	return prop


## A straight run of pieces from `a` along `dir`, `step` apart, each turned
## along the run; a piece that cannot stand leaves a gap, and `gaps` of them
## are left out anyway. Returns the ids placed.
## Distance from `p` to the nearest ROAD TILE'S SQUARE, or INF past `reach`. The
## square rather than its centre, because a road tile is a tile wide and a booth
## beside its edge is beside the road.
static func road_gap(w: WorldData, p: Vector2, reach: int = 4) -> float:
	var best := INF
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if not w.in_bounds(x, y) or w.ground[y * w.size + x] != Ground.ROAD:
				continue
			var q := Vector2(clampf(p.x, x, x + 1.0), clampf(p.y, y, y + 1.0))
			best = minf(best, q.distance_to(p))
	return best


static func _run(L: Lay, kind: int, a: Vector2, dir: Vector2, pieces: int, step: float, level: int, gaps: float = 0.0) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for i in pieces:
		if gaps > 0.0 and L.rng.randf() < gaps:
			continue
		var p := a + dir * (i + 0.5) * step
		var prop := _put(L, kind, p, dir.angle(), level, 0.0, true)
		if prop != null:
			ids.append(prop.id)
			# A run owns the tiles along its length.
			GenScatter._occupy(L.c, L.occ, p + dir * step * 0.3, 0.0)
			GenScatter._occupy(L.c, L.occ, p - dir * step * 0.3, 0.0)
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


## A tile on the shore of the type being laid: level 1 (or 2 late in the
## search), within 4 tiles of the sea, on one of `grounds`, heart-side of any
## ecotone, away from other places.
static func _shore(L: Lay, grounds: Array, apart: float, attempts: int = 900) -> Vector2i:
	var c := L.c
	var w := L.w
	for attempt in attempts:
		var p := GenScatter._random_tile(c, L.rng)
		var i := p.y * c.size + p.x
		if w.level[i] < 1 or w.level[i] > (1 if attempt < attempts * 0.6 else 2) or c.sea_steps[i] > 4 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0:
			continue
		if not grounds.is_empty() and not grounds.has(int(w.ground[i])):
			continue
		if c.islet[i] != 0 or not L.home(p.x, p.y):
			continue
		var room := apart if attempt < attempts * 0.6 else apart * 0.4
		if _crowded(w, Vector2(p), room) or GenScatter._near_village(w, Vector2(p), maxf(room * 0.7, 14.0)):
			continue
		if _sea_dir(c, p).length() < 0.5:
			continue
		return p
	return Vector2i(-1, -1)


## A few things scattered round a point, each where it can stand.
static func _about(L: Lay, kind: int, centre: Vector2, count: int, r0: float, r1: float, level: int = -99) -> int:
	var placed := 0
	for t in count * 4:
		if placed >= count:
			break
		var q := centre + Vector2.from_angle(L.rng.randf() * TAU) * L.rng.randf_range(r0, r1)
		var clear := 0.0 if L.tight and PropKind.SOLID[kind] <= 0.0 else 0.3
		if _put(L, kind, q, L.rng.randf() * TAU, level, clear) != null:
			placed += 1
	return placed


static func _level(c: GenContext, p: Vector2i) -> int:
	return c.w.level[p.y * c.size + p.x]


## The heart of the type being laid: the first country heart that lies in it.
static func _heart(L: Lay) -> Vector2i:
	for h in L.c.hearts:
		if h.x >= 0.0 and L.w.in_bounds(int(h.x), int(h.y)) and L.home(int(h.x), int(h.y)):
			return Vector2i(h)
	return Vector2i(-1, -1)


static func _near_road(c: GenContext, p: Vector2, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if x >= 0 and y >= 0 and x < c.size and y < c.size and c.road[y * c.size + x] != 0:
				return true
	return false


# --- the coast -------------------------------------------------------------------

static func _coast(L: Lay) -> void:
	var c := L.c
	var rng := L.rng
	var d := L.d
	var nrm := L.nrm
	# Turf cut in the machines' rows: a ruled field of strips on the open turf,
	# survey posts at its corners, a fence along its end, a warning at its side.
	for n in _n(c, 2.0):
		var p := _site(L, 8, 1, [Ground.GRASS, Ground.HEATH], 26.0)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var half := Vector2(rng.randf_range(8.0, 11.0), rng.randf_range(5.0, 7.0))
		_record(c, &"turf_rows", at, d, half, CUT)
		var l := _level(c, p)
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				_put(L, PropKind.SURVEY, at + d * half.x * sx + nrm * half.y * sy, d.angle(), -99, 0.0, true)
		_run(L, PropKind.FENCE, at - d * (half.x + 0.6) - nrm * half.y, nrm, ceili(half.y), 2.0, l, 0.15)
		_put(L, PropKind.SIGN, at + nrm * (half.y + 1.2), nrm.angle(), -99, 0.3)
		_about(L, PropKind.WRECKAGE, at + d * (half.x + 2.0), 1, 0.0, 2.0)
	# The intake: a machine housing at the shore, its pipes out to the water,
	# fenced square, a tide gauge standing in the wash.
	var intakes := 0
	for attempt in 10:
		if intakes >= _n(c, 1.0):
			break
		var p := _shore(L, [Ground.SAND, Ground.SHINGLE, Ground.GRASS, Ground.GRAVEL] if attempt < 5 else [], 40.0)
		if p.x < 0:
			continue
		var sea := _sea_dir(c, p)
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var l := _level(c, p)
		var intake: WorldProp = null
		for back in 4:
			intake = _put(L, PropKind.INTAKE, at - sea * back, sea.angle(), l if back == 0 else -99, 1.0, true)
			if intake != null:
				at = intake.pos
				break
		if intake == null:
			continue
		intakes += 1
		_record(c, &"intake", at, sea, Vector2(4.0, 4.0))
		var side := Vector2(-sea.y, sea.x)
		# The fence square, open to the sea; the gate on the land side.
		_run(L, PropKind.FENCE, at - sea * 4.0 - side * 4.0, side, 4, 2.0, -99, 0.0)
		_run(L, PropKind.FENCE, at - sea * 4.0 - side * 4.0, sea, 4, 2.0, -99, 0.1)
		_run(L, PropKind.FENCE, at - sea * 4.0 + side * 4.0, sea, 4, 2.0, -99, 0.1)
		_put(L, PropKind.SIGN, at - sea * 5.2 + side * 1.0, (-sea).angle(), -99, 0.2)
		_gauge(L, at + side * 2.5, sea)
		# AND THE PIPE IT TAKES THE WATER AWAY IN. An intake that stops at its own
		# fence is a machine doing half a job, and it left the coast's keeper with
		# nothing to eat: `tide_reaper` dens AT the intake (`stations`) and feeds on
		# INTAKE, PUMP_HOUSE, PIPE and RELAY, of which the coast held exactly one --
		# the intake itself. Pump houses are the moss's (`test_world_gen_works.HOME`)
		# and relays the pinewood's, so three quarters of its diet was somewhere it
		# could never reach, and starving it was a way of taking it that was already
		# taken. The run goes inland, which is where the water was going anyway.
		# ON THE SURVEY BEARING, like every other work the machines laid: `L.d` is
		# `GenWorks.bearing` and `test_the_machines_works_lie_ruled_on_the_survey_bearing`
		# holds the whole file to it. The first version ran the pipe straight inland
		# on `-sea`, which is what a water main would do and is not what THESE
		# builders do -- they ruled the coast on one line and the pipe is theirs.
		# Whichever way along that line leads away from the water.
		var inland := L.d if L.d.dot(-sea) >= 0.0 else -L.d
		_run(L, PropKind.PIPE, at - sea * 6.0, inland, rng.randi_range(9, 14), 2.0, -99, 0.1)
	# Trawlers beached where the sea put them: on the sand or the shingle, lying
	# along the shore, a field of debris and wreckage round each.
	var hulls := 0
	for attempt in 16:
		if hulls >= _n(c, 2.0):
			break
		var beach := attempt < 12
		var p := _shore(L, [Ground.SAND, Ground.SHINGLE] if beach else [], 30.0 if attempt < 6 else 14.0, 1500)
		if p.x < 0:
			continue
		var sea := _sea_dir(c, p)
		var along := Vector2(-sea.y, sea.x)
		var hull: WorldProp = null
		for back: float in [0.0, 1.0, -1.0, 2.0, 3.0]:
			var at := Vector2(p) + Vector2(0.5, 0.5) - sea * back
			var turn := along.angle() + rng.randf_range(-0.3, 0.3)
			if not _berth(L, at, Vector2.from_angle(turn), beach):
				continue
			hull = _put(L, PropKind.HULL, at, turn, -99, 0.8, false, true)
			if hull != null:
				break
		if hull == null:
			continue
		hulls += 1
		_record(c, &"hulk", hull.pos, sea, Vector2(3.0, 2.0))
		_about(L, PropKind.DEBRIS, hull.pos, 3, 2.5, 5.0)
		_about(L, PropKind.WRECKAGE, hull.pos, 1, 2.5, 4.5)
		_about(L, PropKind.DRIFTWOOD, hull.pos, 2, 2.0, 5.0)
		_gauge(L, hull.pos + along * 3.5, sea)
	# The sea wall, broken along the shore, a drowned car at its foot.
	var walls := 0
	for attempt in 12:
		if walls >= _n(c, 2.0):
			break
		var p := _shore(L, [], 30.0)
		if p.x < 0:
			continue
		var sea := _sea_dir(c, p)
		var along := Vector2(-sea.y, sea.x)
		var at := Vector2(p) + Vector2(0.5, 0.5) - sea
		var ids := _run(L, PropKind.SEA_WALL, at - along * 7.0, along, 5, 2.8, -99, 0.15)
		if ids.is_empty():
			continue
		walls += 1
		for id in ids:
			# The wall's sea face (+Z) looks at the sea.
			c.w.props[id].rot = fposmod(along.angle() + (PI if along.rotated(PI * 0.5).dot(sea) < 0.0 else 0.0), TAU)
		_record(c, &"sea_wall", at, along, Vector2(7.0, 1.0))
		_about(L, PropKind.VEHICLE, at + sea * 2.0, 1, 0.0, 3.0)
		_about(L, PropKind.DEBRIS, at, 2, 1.5, 5.0)
		_put(L, PropKind.SIGN, at - sea * 2.2, (-sea).angle(), -99, 0.2)
	# Tide gauges along the shingle, where the machines read the sea.
	var gauges := 0
	for attempt in 12:
		if gauges >= _n(c, 2.0):
			break
		var p := _shore(L, [Ground.SHINGLE, Ground.SAND] if attempt < 6 else [], 24.0, 300)
		if p.x >= 0 and _gauge(L, Vector2(p) + Vector2(0.5, 0.5), _sea_dir(c, p)) != null:
			gauges += 1
	# Cars drowned at the tide line.
	var cars := 0
	for attempt in 600:
		if cars >= _n(c, 3.0):
			break
		var p := _shore(L, [Ground.SAND, Ground.SHINGLE], 12.0, 60)
		if p.x < 0:
			continue
		if _put(L, PropKind.VEHICLE, Vector2(p) + Vector2(0.5, 0.5), rng.randf() * TAU, -99, 0.8) != null:
			cars += 1


## Ground a hull can lie on: the three tiles along its length (an oblong 1 by
## 3) dry and within a level of the middle one, which is highest, and nothing
## steeper across its beam; on the `beach`, the middle and one more on sand or
## shingle.
static func _berth(L: Lay, at: Vector2, along: Vector2, beach: bool) -> bool:
	var c := L.c
	var w := L.w
	if not w.in_bounds(floori(at.x), floori(at.y)):
		return false
	var l := w.level_at(floori(at.x), floori(at.y))
	if l < 1:
		return false
	var sandy := 0
	for t: float in [-1.7, 0.0, 1.7]:
		var q := at + along * t
		var x := floori(q.x)
		var y := floori(q.y)
		if not w.in_bounds(x, y):
			return false
		var i := y * c.size + x
		if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or Ground.is_water(w.ground[i]) or w.level[i] > l or w.level[i] < l - 1:
			return false
		if w.ground[i] == Ground.SAND or w.ground[i] == Ground.SHINGLE:
			sandy += 1
		elif t == 0.0 and beach:
			return false
	for s: float in [-0.9, 0.9]:
		var q := at + Vector2(-along.y, along.x) * s
		if w.level_at(floori(q.x), floori(q.y)) < l - 1:
			return false
	return sandy >= 2 or not beach


## A tide gauge on the last dry ground from `from` toward the sea.
static func _gauge(L: Lay, from: Vector2, sea: Vector2) -> WorldProp:
	var c := L.c
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
		var g := _put(L, PropKind.TIDE_GAUGE, best - sea * back * 0.5, sea.angle(), -99, 0.0, true)
		if g != null:
			return g
	return null


# --- the moss ----------------------------------------------------------------------

static func _moss(L: Lay) -> void:
	var c := L.c
	var rng := L.rng
	var d := L.d
	var nrm := L.nrm
	# The drained fen: straight cuts, a pump house on them, its pipeline
	# striding off on stilts, a car sunk in the black water, reeds in the wire.
	for n in _n(c, 3.0):
		var p := _site(L, 7, 1, [Ground.MOSS, Ground.PEAT, Ground.MUD, Ground.GRASS, Ground.HEATH], 30.0, 700, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var l := _level(c, p)
		var half := Vector2(rng.randf_range(11.0, 15.0), rng.randf_range(7.0, 9.0))
		_record(c, &"drained", at, d, half, CUT)
		var pump := _put(L, PropKind.PUMP_HOUSE, at, d.angle(), l, 1.0, true)
		if pump == null:
			pump = _put(L, PropKind.PUMP_HOUSE, at + nrm * 2.0, d.angle(), -99, 0.8, true)
		var start := (pump.pos if pump != null else at) + d * 2.8
		_run(L, PropKind.PIPE, start, d, rng.randi_range(9, 14), 2.0, -99, 0.08)
		_run(L, PropKind.FENCE, at - d * half.x * 0.8 + nrm * (half.y + 0.5), d, 6, 2.0, -99, 0.25)
		_about(L, PropKind.VEHICLE, at, 1, 4.0, half.y)
		_about(L, PropKind.WRECKAGE, at, 1, 3.0, half.y)
		_put(L, PropKind.SIGN, at - d * 2.5 + nrm * 1.6, d.angle(), -99, 0.2)
	# Bog graves: stakes in a row by a stilt hut, a memorial for the drowned.
	for n in _n(c, 2.0):
		var p := _site(L, 4, 1, [Ground.MOSS, Ground.PEAT, Ground.HEATH, Ground.GRASS], 24.0, 500, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var row := Vector2.from_angle(rng.randf() * TAU)
		var graves := 0
		for i in rng.randi_range(4, 6):
			if _put(L, PropKind.GRAVE, at + row * (i * 1.3 - 3.0) + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)), row.angle() + PI * 0.5, -99, 0.2) != null:
				graves += 1
		if graves > 0:
			_record(c, &"bog_graves", at, row, Vector2(4.0, 1.0))
			_about(L, PropKind.MEMORIAL, at - row.orthogonal() * 2.0, 1, 0.0, 1.5)
			var shack := _put(L, PropKind.SHACK, at + row.orthogonal() * 4.0, rng.randf() * TAU, -99, 1.0)
			if shack != null:
				_note_lit_shack(L, shack)


# --- the pinewood ------------------------------------------------------------------

static func _pinewood(L: Lay) -> void:
	var c := L.c
	var w := L.w
	var rng := L.rng
	var d := L.d
	var nrm := L.nrm
	# The relay corridor: one straight cut through the heart of the pines, masts
	# strung along it with the machines' light on them, stumps at its edges.
	var through := _heart(L)
	if through.x < 0:
		through = _site(L, 2, 3, [], 0.0, 400, 0.5)
	if through.x >= 0:
		var mid := Vector2(through) + Vector2(0.5, 0.5)
		var along := nrm if rng.randf() < 0.5 else d
		var ends: Array[float] = [0.0, 0.0]
		for side in 2:
			var sgn := -1.0 if side == 0 else 1.0
			var t := 0.0
			while t < 90.0 * maxf(c.body_k, 0.4):
				var q := mid + along * sgn * (t + 1.0)
				var qx := floori(q.x)
				var qy := floori(q.y)
				if not w.in_bounds(qx, qy) or not L.home(qx, qy) or w.level_at(qx, qy) <= 0:
					break
				t += 1.0
			ends[side] = t
		var from := mid - along * ends[0]
		var length := ends[0] + ends[1]
		# The cut stops short of a village and resumes past it: split the line
		# into the stretches that keep clear of every square.
		var stretches: Array[Vector2] = []
		var t0 := -1.0
		var tt := 0.0
		while tt <= length:
			var q := from + along * tt
			var open := not GenScatter._near_village(w, q, _village_clear(w, q))
			if open and t0 < 0.0:
				t0 = tt
			elif not open and t0 >= 0.0:
				stretches.append(Vector2(t0, tt - 1.0))
				t0 = -1.0
			tt += 1.0
		if t0 >= 0.0:
			stretches.append(Vector2(t0, length))
		var kept: Array = []
		for st: Vector2 in stretches:
			if st.y - st.x >= 14.0:
				kept.append([st, _corridor(L, from, along, st.x, st.y)])
		# The stretch with the most masts is recorded first: it is the one a
		# visitor is sent to (GenPlaces "corridor").
		kept.sort_custom(func(x: Array, y: Array) -> bool: return int(x[1]) > int(y[1]))
		for kv: Array in kept:
			var st: Vector2 = kv[0]
			_record(c, &"corridor", from + along * (st.x + st.y) * 0.5, along, Vector2((st.y - st.x) * 0.5, 2.8), CUT)
	# Clearcuts in exact squares: stumps in the harvester's rows, the wood
	# standing thick round the edge, a warning at the corner.
	for n in _n(c, 3.0):
		var p := _site(L, 7, 1, [Ground.NEEDLES, Ground.GRASS, Ground.HEATH], 28.0, 700, 0.4)
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
				var st := _put(L, PropKind.STUMP, q, rng.randf() * TAU, -99, 0.0)
				if st != null:
					st.scale = 0.9 + rng.randf() * 0.25
		_clear_rect(c, L.occ, at, dd, Vector2(half + 0.5, half + 0.5))
		_record(c, &"clearcut", at, dd, Vector2(half + 0.5, half + 0.5), CUT)
		# The sign is put by hand: its corner tile is in the cleared square.
		var corner := at + (dd + dn) * (half + 1.6)
		_put(L, PropKind.SIGN, corner, (dd + dn).angle(), -99, 0.0)
	# Fire towers on the rises, a hunting blind below, a grave for whoever kept it.
	for n in _n(c, 2.0):
		var found: Array = []
		for attempt in 40:
			var p := _site(L, 3, 1, [], 30.0, 20, 0.4)
			if p.x >= 0:
				found.append([c.rise[p.y * c.size + p.x], p])
		found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		var tower: WorldProp = null
		for f: Array in found:
			tower = _put(L, PropKind.FIRE_TOWER, Vector2(f[1] as Vector2i) + Vector2(0.5, 0.5), d.angle(), -99, 0.8, true)
			if tower != null:
				break
		if tower == null:
			continue
		var at := tower.pos
		_record(c, &"fire_tower", at, d, Vector2(2.0, 2.0))
		_about(L, PropKind.SHACK, at, 1, 3.0, 6.0)
		_about(L, PropKind.GRAVE, at, 1, 2.5, 5.0)
	# A burned grove: dead trees standing close in scorched ground.
	for n in _n(c, 1.5):
		var p := _site(L, 6, 1, [Ground.NEEDLES, Ground.GRASS], 28.0, 600, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var r := rng.randf_range(5.0, 7.0)
		_about(L, PropKind.DEAD_TREE, at, 10, 0.5, r)
		_about(L, PropKind.STUMP, at, 4, 0.5, r)
		_about(L, PropKind.WRECKAGE, at, 1, 1.0, r)
		_clear_rect(c, L.occ, at, d, Vector2(r, r * 0.8))
		_record(c, &"burned_grove", at, d, Vector2(r, r * 0.8), SCORCH)


## p lies within `margin` of a village's square.
static func _in_village(w: WorldData, p: Vector2, margin: float) -> bool:
	for v in w.villages:
		if (v.pos as Vector2).distance_to(p) < float(v.get("radius", 4.0)) + margin:
			return true
	return false


## How far a work keeps from the village nearest p: its square and a margin.
static func _village_clear(w: WorldData, p: Vector2) -> float:
	var r := 0.0
	for v in w.villages:
		if (v.pos as Vector2).distance_squared_to(p) < 900.0:
			r = maxf(r, float(v.get("radius", 4.0)))
	return r + 7.0


## One stretch [t0, t1] of the relay corridor along `along` from `from`: its
## cut cleared, masts strung every 11 tiles with the machines' light on them,
## stumps at its edges where the trees were felled for it. Returns the masts.
static func _corridor(L: Lay, from: Vector2, along: Vector2, t0: float, t1: float) -> int:
	var c := L.c
	var w := L.w
	var length := t1 - t0
	_clear_rect(c, L.occ, from + along * (t0 + length * 0.5), along, Vector2(length * 0.5, 2.6))
	var masts := PackedInt32Array()
	var placed := 0
	var tt := t0 + 4.0
	while tt < t1 - 2.0:
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
			placed += 1
		elif masts.size() >= 2:
			w.lines.append({"kind": PropKind.RELAY, "props": masts})
			masts = PackedInt32Array()
		else:
			masts.clear()
		tt += 11.0
	if masts.size() >= 2:
		w.lines.append({"kind": PropKind.RELAY, "props": masts})
	var sn := Vector2(-along.y, along.x)
	var st := t0 + 2.0
	while st < t1 - 1.0:
		for sgn: float in [-1.0, 1.0]:
			if L.rng.randf() < 0.55:
				_put(L, PropKind.STUMP, from + along * (st + L.rng.randf_range(-0.4, 0.4)) + sn * sgn * L.rng.randf_range(3.1, 3.8), L.rng.randf() * TAU, -99, 0.0)
		st += 2.6
	return placed


# --- the snowfield -----------------------------------------------------------------

static func _snowfield(L: Lay) -> void:
	var c := L.c
	var w := L.w
	var rng := L.rng
	var d := L.d
	var nrm := L.nrm
	# Checkpoints on the roads through the snow, at a straight stretch: the gate
	# (a booth beside the way, its boom across it to a far post), snow fence
	# running off either side, cast blocks, a sign before it.
	# Candidates on every road through the snow, deepest in the snow first (a
	# gate on the ecotone is dressed as whatever is drawn at its foot).
	var spots: Array = []
	for road in w.roads:
		for j in range(3, road.size() - 3):
			var q := road[j]
			var i := floori(q.y) * c.size + floori(q.x)
			# A checkpoint may hold a village's way in, but not its square.
			if w.blend[i] > 0.5 or not L.home(floori(q.x), floori(q.y)) or _in_village(w, q, 5.0):
				continue
			var along := (road[j + 3] - road[j - 3]).normalized()
			# A straight stretch: the road holds its line for three tiles either way.
			if (road[j + 3] - road[j]).normalized().dot(along) < 0.9 or (road[j] - road[j - 3]).normalized().dot(along) < 0.9:
				continue
			spots.append([w.blend[i], q, along])
	spots.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var done := 0
	for spot: Array in spots:
		if done >= _n(c, 2.0):
			break
		var q: Vector2 = spot[1]
		var along: Vector2 = spot[2]
		if _crowded(w, q, 12.0):
			continue
		var i := floori(q.y) * c.size + floori(q.x)
		var across := Vector2(-along.y, along.x)
		var booth: WorldProp = null
		for off: float in [2.2, 2.7]:
			for side: float in [-1.0, 1.0]:
				# The gate's boom (the model's +Z) swings from the booth over the road.
				var turn := along.angle() if side < 0.0 else (-along).angle()
				var stand := q + across * side * off
				# A booth further from the road than the rule allows is not a gate
				# on that road, whatever the offset that reached it.
				if road_gap(w, stand) >= CHECKPOINT_AT_ROAD:
					continue
				booth = _put(L, PropKind.CHECKPOINT, stand, turn, w.level[i], 0.6, true, true)
				if booth != null:
					across = across * -side
					break
			if booth != null:
				break
		if booth == null:
			continue
		# `across` now points from the booth over the road.
		_record(c, &"checkpoint", q, along, Vector2(3.0, 3.0))
		_run(L, PropKind.FENCE, booth.pos - across * 1.2 - along * 0.5, -across, 3, 2.0, -99, 0.1)
		_run(L, PropKind.FENCE, booth.pos + across * 5.6 + along * 0.5, across, 3, 2.0, -99, 0.1)
		_put(L, PropKind.BARRICADE, booth.pos + along * 3.4 - across * 0.4, along.angle(), -99, 0.4)
		_put(L, PropKind.SIGN, booth.pos - along * 4.5, (-along).angle(), -99, 0.2)
		_about(L, PropKind.DEBRIS, q, 1, 4.0, 6.0)
		done += 1
	for attempt in 10:
		if done > 0:
			break
		# No road through the snow took one: it stands on the open field anyway.
		var p := _site(L, 4 if attempt < 5 else 2, 1, [], 30.0 if attempt < 5 else 10.0, 500, 0.5)
		if p.x >= 0:
			var at := Vector2(p) + Vector2(0.5, 0.5)
			if _put(L, PropKind.CHECKPOINT, at, d.angle(), -99, 0.6, true) != null:
				_record(c, &"checkpoint", at, d, Vector2(3.0, 3.0))
				_run(L, PropKind.FENCE, at - nrm * 1.5, -nrm, 4, 2.0, -99, 0.1)
				done += 1
	# The tall stack, fenced, seen from everywhere.
	var stacks := 0
	for attempt in 8:
		if stacks >= _n(c, 1.0):
			break
		var p := _site(L, 6 if attempt < 4 else 3, 1, [], 44.0 if attempt < 4 else 16.0, 500, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		if _put(L, PropKind.STACK, at, d.angle(), -99, 1.2 if attempt < 4 else 0.8, true) == null:
			continue
		stacks += 1
		_record(c, &"stack", at, d, Vector2(4.5, 4.5))
		for side in 4:
			var e := d.rotated(side * PI * 0.5)
			var en := Vector2(-e.y, e.x)
			_run(L, PropKind.FENCE, at + e * 4.5 - en * 4.5, en, 4 if side != 2 else 2, 2.25, -99, 0.1)
		_about(L, PropKind.DEBRIS, at, 2, 5.5, 8.0)
		_put(L, PropKind.SIGN, at - d * 6.0, (-d).angle(), -99, 0.2)
	# A convoy that never got through: vehicles buried in a line, a snow fence.
	for n in _n(c, 1.0):
		var p := _site(L, 5, 1, [Ground.SNOW], 30.0, 600, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var placed := 0
		for i in 4:
			if _put(L, PropKind.VEHICLE, at + d * (i * 3.4 - 5.0) + nrm * rng.randf_range(-0.3, 0.3), d.angle() + rng.randf_range(-0.15, 0.15), -99, 0.8) != null:
				placed += 1
		if placed > 0:
			_record(c, &"convoy", at, d, Vector2(7.0, 2.0))
			_run(L, PropKind.FENCE, at - d * 6.0 + nrm * 2.5, d, 6, 2.0, -99, 0.2)
			_about(L, PropKind.WRECKAGE, at, 2, 2.0, 5.0)
	# Where the grid crosses the snow its lines hang with ice (WorldView strings
	# it): the span nearest the snow's heart is recorded so it can be walked to.
	var best := 1e9
	var iced := Vector2(-1, -1)
	var heart := _heart(L)
	for line in w.lines:
		if line.kind != PropKind.PYLON and line.kind != PropKind.POLE:
			continue
		var ids: PackedInt32Array = line.props
		for k in ids.size() - 1:
			var mid := (w.props[ids[k]].pos + w.props[ids[k + 1]].pos) * 0.5
			if not L.home(floori(mid.x), floori(mid.y)) or w.blend[floori(mid.y) * c.size + floori(mid.x)] > 0.4:
				continue
			var score := mid.distance_squared_to(Vector2(heart)) if heart.x >= 0 else 0.0
			if score < best:
				best = score
				iced = mid
	if iced.x >= 0.0:
		_record(c, &"iced_line", iced, d, Vector2(1.0, 1.0))
	# Emergency shelters, a grave by each.
	for n in _n(c, 2.0):
		var p := _site(L, 3, 1, [], 26.0, 500, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var shack := _put(L, PropKind.SHACK, at, rng.randf() * TAU, -99, 1.0)
		if shack == null:
			continue
		_note_lit_shack(L, shack)
		_record(c, &"shelter", at, d, Vector2(2.0, 2.0))
		_about(L, PropKind.GRAVE, at, 1, 2.5, 4.0)


# --- the bonelands -----------------------------------------------------------------

static func _bonelands(L: Lay) -> void:
	var c := L.c
	var rng := L.rng
	var d := L.d
	var nrm := L.nrm
	var pale: Array = [Ground.LIMESTONE, Ground.BONE, Ground.GRAVEL, Ground.GRASS, Ground.SCREE, Ground.HEATH]
	# Quarries cut in the grid: benches in exact squares, drills standing in
	# them, a conveyor carrying the stone off along the bearing.
	for n in _n(c, 2.0):
		var p := _site(L, 7, 1, pale, 30.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var half := Vector2(rng.randf_range(7.0, 9.0), rng.randf_range(5.0, 6.5))
		_record(c, &"quarry", at, d, half, QUARRY)
		for gy in range(-1, 2):
			for gx in range(-2, 3):
				if rng.randf() < 0.35:
					continue
				_put(L, PropKind.DRILL_RIG, at + d * gx * 3.0 + nrm * gy * 3.0, d.angle(), -99, 0.3, true)
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				_put(L, PropKind.SURVEY, at + d * half.x * sx + nrm * half.y * sy, d.angle(), -99, 0.0, true)
		# The conveyor leaves by whichever side of the quarry keeps it in the
		# bonelands' own ground, or failing that any side it can stand on.
		var pieces := rng.randi_range(5, 8)
		var laid := false
		for pass_home: bool in [true, false]:
			for way: Vector2 in [d, -d, nrm, -nrm]:
				if laid:
					break
				var reach := half.x if absf(way.dot(d)) > 0.5 else half.y
				var from := at + way * (reach + 0.5)
				var end := from + way * pieces * 2.5
				if pass_home and not (L.w.in_bounds(floori(end.x), floori(end.y)) and L.home(floori(end.x), floori(end.y))):
					continue
				laid = not _run(L, PropKind.CONVEYOR, from, way, pieces, 2.5, -99, 0.1).is_empty()
		_put(L, PropKind.SIGN, at - d * (half.x + 1.5), (-d).angle(), -99, 0.2)
		_about(L, PropKind.DEBRIS, at, 2, half.y, half.x)
	# Drill fields: bores in an exact grid, capped or still drilling, the
	# survey posts that laid them out.
	for n in _n(c, 2.0):
		var p := _site(L, 7, 1, pale, 30.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var half := Vector2(8.0, 6.0)
		_record(c, &"drill_field", at, nrm, half, BORES)
		for gy in range(-2, 3):
			for gx in range(-3, 4):
				var q := at + nrm * gx * 2.6 + d * gy * 2.6
				if (gx + gy) % 3 == 0:
					_put(L, PropKind.SURVEY, q, nrm.angle(), -99, 0.0, true)
				else:
					_put(L, PropKind.DRILL_RIG, q, nrm.angle(), -99, 0.2, true)
	# Cisterns where people keep water, a lean-to by each, a fence, a grave.
	#
	# A CISTERN IS A SMALL THING AND WAS ASKING FOR AN INSTALLATION'S ROOM. At 26
	# tiles clear of every other work it lost the draw against the drill rigs and
	# the conveyors that share the bonelands, and a whole 512 world came out with
	# nought to two of them across fourteen thousand tiles of its own landscape --
	# a kind with a model, a home and a place in a keeper's diet that a player
	# would never meet. `test_every_prop_kind_and_ground_is_placed` had been
	# failing on whichever seed happened to lose the last one, which reads as a
	# flaky test and was a content answer nobody had looked at.
	for n in _n(c, 2.0):
		var p := _site(L, 4, 1, [], 14.0, 500, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		if _put(L, PropKind.WATER_TANK, at, rng.randf() * TAU, -99, 0.8) == null:
			continue
		_record(c, &"cistern", at, d, Vector2(3.0, 3.0))
		_about(L, PropKind.SHACK, at, 1, 2.8, 4.5)
		_run(L, PropKind.FENCE, at + Vector2(-3.0, 3.0), Vector2.from_angle(rng.randf() * TAU), 3, 2.0, -99, 0.3)
		_about(L, PropKind.GRAVE, at, 1, 4.0, 6.0)


# --- the burning -------------------------------------------------------------------

static func _burning(L: Lay) -> void:
	var c := L.c
	var w := L.w
	var rng := L.rng
	var d := L.d
	var nrm := L.nrm
	var dry: Array = [Ground.ASH, Ground.CLINKER, Ground.GRAVEL, Ground.ROCK, Ground.SCREE, Ground.GRASS, Ground.HEATH]
	# Slag heaps tipped in a line along the bearing, a scorched car by them.
	for n in _n(c, 2.0):
		var p := _site(L, 6, 1, dry, 30.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var heaps := 0
		for i in rng.randi_range(3, 4):
			if _put(L, PropKind.SLAG_HEAP, at + d * (i * 3.6 - 5.0), d.angle(), -99, 1.0, true) != null:
				heaps += 1
		if heaps == 0:
			continue
		_record(c, &"slag", at, d, Vector2(7.5, 3.0), SCORCH)
		_about(L, PropKind.VEHICLE, at + nrm * 4.0, 1, 0.0, 2.5)
		_about(L, PropKind.DEBRIS, at, 3, 3.0, 6.0)
		_about(L, PropKind.WRECKAGE, at, 1, 3.0, 6.0)
	# Refinery runs: parallel pipelines, collapsed in stretches, vents capped.
	for n in _n(c, 1.5):
		var p := _site(L, 6, 1, dry, 30.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var runs := rng.randi_range(2, 3)
		var length := rng.randi_range(7, 10)
		for r in runs:
			_run(L, PropKind.PIPE, at - d * length + nrm * (r - (runs - 1) * 0.5) * 1.7, d, length, 2.0, -99, 0.12)
		_record(c, &"refinery", at, d, Vector2(length + 1.0, runs * 1.2), SCORCH)
		_about(L, PropKind.VENT_CAP, at + nrm * (runs * 1.2 + 2.0), 2, 0.0, 3.5)
		_about(L, PropKind.DEBRIS, at, 2, 3.0, 7.0)
	# The clerks' archive: cabinets in exact rows standing in the ash.
	var archives := 0
	for attempt in 8:
		if archives >= _n(c, 1.0):
			break
		var p := _site(L, 5 if attempt < 4 else 3, 1, dry if attempt < 4 else [], 34.0 if attempt < 4 else 14.0, 600, 0.45)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var placed := 0
		for gy in range(-1, 2):
			for gx in range(-1, 2):
				if rng.randf() < 0.25:
					continue
				if _put(L, PropKind.ARCHIVE, at + d * gx * 2.4 + nrm * gy * 2.4, d.angle(), -99, 0.4, true) != null:
					placed += 1
		if placed == 0:
			continue
		archives += 1
		_record(c, &"archive", at, d, Vector2(4.0, 4.0), SCORCH)
		_put(L, PropKind.SIGN, at - d * 4.5, (-d).angle(), -99, 0.2)
	# The machines bolted caps on the vents of the fumaroles.
	for m in w.landmarks:
		if m.kind != &"fumarole":
			continue
		var at: Vector2 = m.pos
		if not L.home(floori(at.x), floori(at.y)):
			continue
		for sgn: float in [-1.0, 1.0]:
			_put(L, PropKind.VENT_CAP, at + d * sgn * 2.2, d.angle(), -99, 0.4, true)
	# A dugout by the heat.
	for n in _n(c, 1.0):
		var p := _site(L, 3, 1, dry, 24.0, 500, 0.45)
		if p.x < 0:
			continue
		var shack := _put(L, PropKind.SHACK, Vector2(p) + Vector2(0.5, 0.5), rng.randf() * TAU, -99, 1.0)
		if shack != null:
			_note_lit_shack(L, shack)
			_record(c, &"dugout", shack.pos, d, Vector2(2.0, 2.0))


# --- people ------------------------------------------------------------------------

## Round every village: its graves in a row by a memorial, a shack or two at
## the edge with stolen light in some, fences, a barricade on the way in, debris.
static func _villages(L: Lay) -> void:
	var c := L.c
	var w := L.w
	var rng := L.rng
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
				if _put(L, PropKind.GRAVE, q, a + rng.randf_range(-0.12, 0.12), -99, 0.3) != null:
					graves += 1
			if graves >= 2:
				_record(c, &"graves", at, row, Vector2(4.0, 1.0))
				_put(L, PropKind.MEMORIAL, at + Vector2.from_angle(a) * 1.6, a + PI, -99, 0.3)
				break
		# Shacks at the edge, stolen light in some.
		var shacks := 0
		for attempt in 40:
			if shacks >= rng.randi_range(1, 2):
				break
			var q := vp + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(12.0, 19.0)
			if _near_road(c, q, 2):
				continue
			var shack := _put(L, PropKind.SHACK, q.floor() + Vector2(0.5, 0.5), (vp - q).angle(), -99, 1.2)
			if shack != null:
				shacks += 1
				_note_lit_shack(L, shack)
		# Garden fences, crooked, gapped.
		for f in 2:
			var q := vp + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, 13.0)
			_run(L, PropKind.FENCE, q, (q - vp).normalized().orthogonal(), rng.randi_range(2, 3), 2.0, -99, 0.2)
		_about(L, PropKind.DEBRIS, vp, 3, 11.0, 18.0)
		_about(L, PropKind.WRECKAGE, vp, 1, 12.0, 18.0)
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
				if _put(L, PropKind.BARRICADE, q + across * 1.8, along.angle(), -99, 0.4) != null or _put(L, PropKind.BARRICADE, q - across * 1.8, along.angle(), -99, 0.4) != null:
					break


## Record the first shack with stolen machine light wired in (the lit model:
## PropModels' variant 1 of 2, by the hash the view bakes with) as the landmark
## "stolen_light", so it can be walked to and seen after dusk.
static func _note_lit_shack(L: Lay, shack: WorldProp) -> void:
	if absi(Rng.hash_ints(L.c.s, shack.id, 90)) % 2 != 1:
		return
	for m in L.w.landmarks:
		if m.kind == &"stolen_light":
			return
	_record(L.c, &"stolen_light", shack.pos, Vector2.RIGHT, Vector2(1.5, 1.5))


## Warnings nobody reads, beside the roads, one every so often away from the
## villages.
static func _roads(L: Lay) -> void:
	var w := L.w
	for road in w.roads:
		var j := 20
		while j < road.size() - 20:
			var q := road[j]
			if not GenScatter._near_village(w, q, 16.0):
				var along := (road[mini(j + 2, road.size() - 1)] - road[j - 2]).normalized()
				var across := Vector2(-along.y, along.x)
				for sgn: float in [1.0, -1.0]:
					if _put(L, PropKind.SIGN, q + across * sgn * 1.7, (across * sgn).angle(), -99, 0.2) != null:
						break
			j += L.rng.randi_range(34, 52)


## What is left where things ended: debris round the tips, ruins and wrecks,
## a grave or a sign at some.
static func _remains(L: Lay) -> void:
	var w := L.w
	var rng := L.rng
	var count := w.landmarks.size()
	for li in count:
		var m: Dictionary = w.landmarks[li]
		var at: Vector2 = m.pos
		match m.kind:
			&"tip", &"wreck":
				_about(L, PropKind.DEBRIS, at, 3, 3.0, 6.5)
				_about(L, PropKind.WRECKAGE, at, 1, 3.0, 6.5)
				if rng.randf() < 0.5:
					_run(L, PropKind.FENCE, at + Vector2(-5.0, 4.0), Vector2.from_angle(rng.randf() * TAU), 3, 2.0, -99, 0.35)
			&"ruin":
				_about(L, PropKind.DEBRIS, at, 2, 2.0, 5.0)
				if rng.randf() < 0.6:
					_about(L, PropKind.GRAVE, at, 2, 3.5, 6.0)
				if rng.randf() < 0.4:
					_about(L, PropKind.VEHICLE, at, 1, 4.0, 7.0)


## The first frame of a game shows what was lost: in view of the spawn, past
## its first steps and the village square it wakes by, a few of its own
## landscape's compositions (graves round a memorial first).
static func _spawn_view(L: Lay) -> void:
	var w := L.w
	var sp := w.spawn
	var face := Vector2.from_angle(w.spawn_facing)
	var table: Array = evidence(L.type_at(floori(sp.x), floori(sp.y))).vignettes
	var rng := Rng.make(L.c.s, 0x5B4)
	var placed := 0
	L.tight = true
	for attempt in 200:
		if placed >= 5:
			break
		var a := rng.randf() * TAU
		var at := sp + Vector2.from_angle(a) * rng.randf_range(5.0, 13.0)
		var turn := rng.randf()
		var pick := _pick(table, rng.randf())
		if not w.in_bounds(floori(at.x), floori(at.y)) or _near_road(L.c, at, 1) or _in_village(w, at, 0.9):
			continue
		# Ahead, only what can be walked through (_put keeps solids off the first steps).
		if Vector2.from_angle(a).dot(face) > 0.7 and (pick == &"wreck" or pick == &"barricade" or pick == &"sunk_wreck"):
			pick = &"debris_field"
		if placed == 0 or pick == &"shelter" or pick == &"stump_rows" or pick == &"survey_posts" or pick == &"snow_fence":
			pick = [&"grave_cluster", &"debris_field", &"wreck_parts", &"fence_corner", &"debris_field"][placed]
		if _compose(L, pick, at, turn, a + PI) > 0:
			placed += 1
	L.tight = false


# --- the walk between places --------------------------------------------------------

## Tiles between vignette cells, and the share of cells that hold one.
const VIGNETTE_CELL := 8
const VIGNETTE_SHARE := 0.9


## Small compositions at walking scale between the places, so any stretch of
## any landscape holds something of what happened (EVIDENCE vignettes). Most
## cells hold one; they keep off the works, the villages and the first steps.
static func _vignettes(L: Lay) -> void:
	var c := L.c
	var w := L.w
	var busy := PackedByteArray()
	busy.resize(c.n)
	for m in w.landmarks:
		var k: StringName = m.kind
		if k == &"falls" or k == &"bridge" or k == &"summit" or k == &"stolen_light" or k == &"iced_line":
			continue
		var half: Vector2 = m.get("half", Vector2(3.0, 3.0))
		_stamp(c, busy, m.pos, minf(maxf(half.x, half.y) + 3.0, 16.0))
	for v in w.villages:
		_stamp(c, busy, v.pos, float(v.get("radius", 4.0)) + 6.0)
	_stamp(c, busy, w.spawn, 5.0)
	var rng := Rng.make(c.s, 0x716)
	L.rng = Rng.make(c.s, 0x717)
	var cell := VIGNETTE_CELL
	for cy in range(cell, c.size - cell, cell):
		for cx in range(cell, c.size - cell, cell):
			# Every roll is drawn whether it is used or not: a world comes out the same.
			var tries: Array[Vector2i] = [Vector2i(cx + rng.randi_range(0, cell - 1), cy + rng.randi_range(0, cell - 1)), Vector2i(cx + rng.randi_range(0, cell - 1), cy + rng.randi_range(0, cell - 1))]
			var roll := rng.randf()
			var pick := rng.randf()
			var turn := rng.randf()
			if roll > VIGNETTE_SHARE:
				continue
			# A cell whose first spot is wet or taken tries a second.
			for p in tries:
				var i := p.y * c.size + p.x
				if c.land[i] == 0 or busy[i] != 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or Ground.is_water(w.ground[i]):
					continue
				var table: Array = evidence(L.type_at(p.x, p.y)).vignettes
				if _compose(L, _pick(table, pick), Vector2(p) + Vector2(0.5, 0.5), turn, turn * TAU) > 0:
					break


## The composition a roll (0..1) picks from a [weight, name] table.
static func _pick(table: Array, roll: float) -> StringName:
	var total := 0.0
	for e: Array in table:
		total += float(e[0])
	var t := roll * total
	for e: Array in table:
		t -= float(e[0])
		if t < 0.0:
			return e[1]
	return (table[table.size() - 1] as Array)[1]


## One walking-scale composition of a few pieces round `at`: `turn` (0..1)
## varies it, `angle` is the way it faces. Returns the pieces placed.
static func _compose(L: Lay, name: StringName, at: Vector2, turn: float, angle: float) -> int:
	var rng := L.rng
	var d := L.d
	var along := d if turn < 0.5 else L.nrm
	var loose := Vector2.from_angle(angle)
	var n := 0
	match name:
		&"debris_field":
			# What a collapse threw across the ground, in a spray from where it
			# happened, the wreck of something larger at its heart.
			n += _about(L, PropKind.DEBRIS, at, 3 + int(turn * 3.0), 0.4, 3.2)
			if turn > 0.35:
				n += _about(L, PropKind.WRECKAGE, at, 1, 0.0, 1.5)
		&"wreck":
			if _put(L, PropKind.VEHICLE, at, angle, -99, 0.8) != null:
				n += 1
				n += _about(L, PropKind.WRECKAGE, at, 1 + int(turn * 2.0), 1.8, 3.6)
				n += _about(L, PropKind.DEBRIS, at, 1, 2.0, 3.5)
		&"sunk_wreck":
			if _put(L, PropKind.VEHICLE, at, angle, -99, 0.8) != null:
				n += 1
				n += _about(L, PropKind.WRECKAGE, at, 1, 2.0, 3.5)
				n += _about(L, PropKind.GRAVE, at, 1, 2.5, 4.0)
		&"wreck_parts":
			n += _about(L, PropKind.WRECKAGE, at, 2 + int(turn * 2.0), 0.5, 3.0)
			n += _about(L, PropKind.DEBRIS, at, 1, 1.0, 3.0)
		&"fence_corner":
			# Two runs meeting at a corner, one gone over, a warning down by it.
			n += _run(L, PropKind.FENCE, at, loose, 2 + int(turn * 2.0), 2.0, -99, 0.15).size()
			n += _run(L, PropKind.FENCE, at, loose.orthogonal(), 2, 2.0, -99, 0.3).size()
			n += _about(L, PropKind.DEBRIS, at + (loose + loose.orthogonal()) * 1.5, 1, 0.0, 1.5)
			if turn > 0.6 and _put(L, PropKind.SIGN, at - loose * 1.2, angle + 2.2, -99, 0.2) != null:
				n += 1
		&"grave_cluster":
			# The dead of one day together: a memorial, graves round it in an
			# uneven arc facing it.
			if _put(L, PropKind.MEMORIAL, at, angle, -99, 0.4) != null:
				n += 1
			var count := 3 + int(turn * 3.0)
			for g in count:
				var a := angle + PI + (g - (count - 1) * 0.5) * 0.55
				var q := at + Vector2.from_angle(a) * (1.7 + rng.randf() * 0.5)
				if _put(L, PropKind.GRAVE, q, a + PI + rng.randf_range(-0.2, 0.2), -99, 0.0 if L.tight else 0.25) != null:
					n += 1
		&"tipped_signs":
			if _put(L, PropKind.SIGN, at, angle, -99, 0.2) != null:
				n += 1
			if _put(L, PropKind.SIGN, at + loose * 2.2, angle + 1.1, -99, 0.2) != null:
				n += 1
			n += _about(L, PropKind.DEBRIS, at, 1, 1.2, 2.5)
		&"barricade":
			if _put(L, PropKind.BARRICADE, at, angle, -99, 0.5) != null:
				n += 1
			n += _run(L, PropKind.FENCE, at + loose * 1.8, loose, 2, 2.0, -99, 0.2).size()
			n += _about(L, PropKind.DEBRIS, at, 2, 1.5, 3.0)
		&"nets":
			# Where a boat was broken up for its timber and plate.
			n += _about(L, PropKind.DRIFTWOOD, at, 2, 0.5, 2.5)
			n += _about(L, PropKind.WRECKAGE, at, 1, 0.0, 2.0)
			n += _about(L, PropKind.DEBRIS, at, 2, 1.0, 3.0)
		&"shelter":
			var shack := _put(L, PropKind.SHACK, at, angle, -99, 1.0)
			if shack != null:
				n += 1
				_note_lit_shack(L, shack)
				n += _about(L, PropKind.GRAVE, at, 1, 2.5, 4.0)
				n += _run(L, PropKind.FENCE, at + loose * 2.4, loose.orthogonal(), 2, 2.0, -99, 0.2).size()
		&"pipe_run":
			n += _run(L, PropKind.PIPE, at, d, 2 + int(turn * 3.0), 2.0, -99, 0.2).size()
			n += _about(L, PropKind.DEBRIS, at + d * 2.0, 1, 1.0, 2.5)
		&"conveyor_run":
			# Longer than a pipe run and unbroken: a conveyor with pieces missing
			# has nothing to carry, and where these are laid the plant still runs.
			n += _run(L, PropKind.CONVEYOR, at, d, 3 + int(turn * 4.0), 2.5, -99, 0.0).size()
			n += _about(L, PropKind.DEBRIS, at + d * 2.5, 1, 1.0, 2.5)
		&"stump_rows":
			# A small cut in the wood: stumps in the harvester's rows.
			var k := 2 + int(turn * 2.0)
			for gy in 2:
				for gx in k:
					if _put(L, PropKind.STUMP, at + d * (gx * 2.0) + L.nrm * (gy * 2.0), rng.randf() * TAU, -99, 0.0) != null:
						n += 1
			_clear_rect(L.c, L.occ, at + d * (k - 1) + L.nrm, d, Vector2(k + 0.4, 1.9))
		&"snow_fence":
			n += _run(L, PropKind.FENCE, at, along, 3 + int(turn * 3.0), 2.0, -99, 0.12).size()
			n += _about(L, PropKind.DEBRIS, at, 1, 1.5, 3.0)
		&"survey_posts":
			for k in 3:
				if _put(L, PropKind.SURVEY, at + along * (k * 3.0), along.angle(), -99, 0.0, true) != null:
					n += 1
		&"drill":
			if _put(L, PropKind.DRILL_RIG, at, d.angle(), -99, 0.3, true) != null:
				n += 1
			if _put(L, PropKind.SURVEY, at + d * 2.6, d.angle(), -99, 0.0, true) != null:
				n += 1
			n += _about(L, PropKind.DEBRIS, at, 1, 1.5, 3.0)
		&"vent":
			if _put(L, PropKind.VENT_CAP, at, d.angle(), -99, 0.4, true) != null:
				n += 1
			n += _about(L, PropKind.DEBRIS, at, 2, 1.5, 3.0)
		&"burnt_archive":
			if _put(L, PropKind.ARCHIVE, at, d.angle(), -99, 0.5, true) != null:
				n += 1
			n += _about(L, PropKind.DEBRIS, at, 1, 1.5, 3.0)
			n += _about(L, PropKind.WRECKAGE, at, 1, 1.5, 3.0)
	return n


# --- the survey --------------------------------------------------------------------

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


## The survey dressed by each landscape (EVIDENCE survey): a lane cut through
## the pines, snow fence along it on the snowfield, pipe on it in the burning.
## Posts stand at its stations everywhere. The ground's own marks for it are
## drawn by world.gdshader.
static func _survey(L: Lay) -> void:
	var c := L.c
	var rng := Rng.make(c.s, 0x5A2)
	for sec: Array in survey_sections(c.s, c.size):
		var a: Vector2 = sec[0]
		var b: Vector2 = sec[1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var mid := (a + b) * 0.5
		if mid.x < 0.0 or mid.y < 0.0 or mid.x >= c.size or mid.y >= c.size:
			continue
		var roll := rng.randf()
		var dressing: Array = evidence(L.type_at(floori(mid.x), floori(mid.y))).survey
		# The lane stays open wherever it runs through a landscape that cuts one.
		var t := 0.0
		while t <= SURVEY_SECTION:
			var q := a + dir * t
			if q.x >= 1.0 and q.y >= 1.0 and q.x < c.size - 1 and q.y < c.size - 1 and _survey_has(L, floori(q.x), floori(q.y), &"lane"):
				_clear_rect(c, L.occ, q, dir, Vector2(0.5, 1.3))
			t += 1.0
		# Stations: a post where the survey was read, now and then.
		var st := 4.0 + rng.randf() * 6.0
		while st < SURVEY_SECTION:
			if rng.randf() < 0.45:
				_put(L, PropKind.SURVEY, a + dir * st, dir.angle(), -99, 0.0, true)
			st += 8.0 + rng.randf() * 4.0
		for e: Array in dressing:
			if roll >= float(e[0]):
				continue
			match e[1]:
				&"snow_fence_line":
					_run(L, PropKind.FENCE, a + dir * (4.0 + roll * 8.0) + side * 1.2, dir, 4, 2.0, -99, 0.15)
				&"pipe_line":
					_run(L, PropKind.PIPE, a + dir * (4.0 + roll * 10.0) + side * 1.0, dir, 3, 2.0, -99, 0.25)
				&"drill_beside":
					_put(L, PropKind.DRILL_RIG, mid + side * 1.4, dir.angle(), -99, 0.3, true)
				&"sign_beside":
					_put(L, PropKind.SIGN, mid + side * 1.5, dir.angle() + PI * 0.5, -99, 0.2)


## The landscape at (x, y) dresses the survey with `dressing`.
static func _survey_has(L: Lay, x: int, y: int, dressing: StringName) -> bool:
	for e: Array in evidence(L.type_at(x, y)).survey:
		if e[1] == dressing:
			return true
	return false


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
