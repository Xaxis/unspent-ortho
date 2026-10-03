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
	## The registry index of `id`, or -1 while laying what every type shares.
	var own := -1
	## The bounds of each REGION of the type being laid, and its size in tiles:
	## where `_site` throws, so a dart lands in this landscape and not in the
	## square round every landscape at once. Empty while laying the shared things.
	var rects: Array[Rect2] = []
	var sizes: PackedFloat32Array = PackedFloat32Array()
	## THE REGION BEING LAID, and every region of its landscape by size. A
	## landscape's works are sited one region at a time (`place`), each from its
	## own darts and its own share of the landscape's count (`_n`), so a region's
	## works hang on its own ground and never on another region's.
	var region := -1
	var at := 0
	var all_sizes: PackedFloat32Array = PackedFloat32Array()
	var shares: Dictionary = {}
	## `w.landmarks` when the works stage began, and when this region's run did:
	## the rows between are other regions' works, which siting does not see.
	var m_start := 0
	var m_region := 0
	## Where a landscape's works are SITED from: its darts, thrown in order
	## (`_dart`). Composing a work draws from `rng`, keyed on the work (`_work`).
	var site_rng: RandomNumberGenerator
	## The occupancy the works stage began from. A work composes against this
	## and its own pieces only, never against another work's, so what it lays is
	## a function of its row and not of how many works came before it.
	var base: PackedByteArray
	## The work being composed: its key (0 outside one), and each tile it took
	## with what `occ` held there before, so a work that gives up is taken back.
	var key := 0
	var in_work := false
	## The world's prop count when the work being composed began (`_work`): its
	## own props are the ones from here, which is how a station hands over its
	## larder (`station_last`) without asking the world's size itself.
	var work_from := 0
	## What `_site` learned of this landscape, per question asked of it: 1 when
	## its strict search came up empty, 2 when the loose one did too.
	var site_memo: Dictionary = {}
	## The region being laid's cells of its keeper's founder ground
	## (`_founder_near`), gathered on the first ask; null until then.
	var founder_cells: Variant = null
	## False while a work is composed a second time for `witness`: it reads the
	## snapshot and keeps what it takes in `mine`, and writes no grid.
	var writes := true
	## Whose works functions compose the works: GenWorks, or the landscape
	## file that registered its own ("host" in its row).
	var host: Object = null
	var mine: Dictionary = {}
	## Every lit shack standing (`_note_lit_shack`).
	var lit: Array[Vector2] = []

	func _init(ctx: GenContext, o: PackedByteArray, bearing_dir: Vector2) -> void:
		c = ctx
		w = ctx.w
		occ = o
		base = o
		d = bearing_dir
		nrm = Vector2(-d.y, d.x)

	## Nothing stands within r of p, as `GenScatter._free` asks it: inside a
	## work, of the stage's first occupancy and the work's own pieces.
	func open(p: Vector2, r: float) -> bool:
		if not in_work:
			return GenScatter._free(c, occ, p, r)
		if not GenScatter._free(c, base, p, r):
			return false
		if mine.is_empty():
			return true
		var ri := ceili(r)
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				if mine.has((floori(p.y) + dy) * c.size + floori(p.x) + dx):
					return false
		return true

	## Take every tile within r of p, as `GenScatter._occupy` does.
	func take(p: Vector2, r: float) -> void:
		var ri := ceili(r)
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var x := floori(p.x) + dx
				var y := floori(p.y) + dy
				if x >= 0 and y >= 0 and x < c.size and y < c.size:
					take_tile(y * c.size + x)

	func take_tile(i: int) -> void:
		if in_work and not mine.has(i):
			mine[i] = occ[i]
		if writes:
			occ[i] = 1

	func type_at(x: int, y: int) -> StringName:
		return BiomeRegistry.by_index(_index_at(x, y)).id

	func _index_at(x: int, y: int) -> int:
		# What `BiomeRegistry.at` does, without the Vector2: it floors a tile
		# centre straight back to (x, y) and reads `country`.
		return clampi(w.country[y * c.size + x], 0, BiomeRegistry.count() - 1)

	## Tile (x, y) is of the type being laid.
	##
	## **THIS WAS THE MOST EXPENSIVE QUESTION IN THE FILE AND IT IS AN INTEGER
	## COMPARE.** It used to ask `type_at`, which allocated a `Vector2` per tile,
	## called `BiomeRegistry.at` (which calls `_ensure()` every time), and then ran
	## a LINEAR `find()` over the id array to turn the answer back into a small
	## int -- all to compare two StringNames. A per-tile byte cache was carried to
	## soften it, `n` bytes wide, which is 1.7 MB of the full world spent hiding
	## the cost of a lookup that was already a single array read.
	##
	## A landscape's index is on its own def (`BiomeDef.index`) and every tile
	## already carries it in `w.country`, so this is `country[i] == own`. Same
	## answer, tile for tile: `_index_at` is `BiomeRegistry.at` with the float
	## round trip taken out, and `own` is -1 while the shared things are being
	## laid, which no country index can equal -- exactly as the empty `id` it
	## replaced could never match a real one.
	func home(x: int, y: int) -> bool:
		return w.country[y * c.size + x] == own

	## Tile (x, y) is in the region being laid: where a work may be SITED.
	## Composing asks `home`, as a work may reach over into its next region.
	func here(x: int, y: int) -> bool:
		return home(x, y) and (region < 0 or w.region_at(x, y) == region)


## **THE PLAN'S OWN PROP KINDS, WHOEVER PUTS THEM DOWN.** `place` below refuses to
## run in a year before the machines began, and that was taken as the whole of it
## for as long as the Before has existed — but a LANDSCAPE may scatter one of
## these from its own recipe, and the Server Fields does: three relays stood in
## 2029 on seed 4 because `d.scatter` returns `PropKind.RELAY` on its floor and
## nothing between that recipe and the world asked what year it was. So the fact
## is about the KINDS and not about who places them, and it is written down once,
## here, where the plan is. `GenScatter.allow` clears these from every landscape's
## mask before the plan, and `tests/core/test_era.gd` reads this list rather than
## keeping a second copy that can drift out of agreement with it.
const THEIRS: Array[int] = [PropKind.RELAY, PropKind.SURVEY, PropKind.DRILL_RIG,
	PropKind.CONVEYOR, PropKind.CHECKPOINT, PropKind.PIPE, PropKind.INTAKE]


static func place(c: GenContext, occ: PackedByteArray) -> void:
	# NOT IN A YEAR BEFORE THEY BEGAN. Everything this file lays is the machines'
	# — ruled on their survey bearing, keeping their hours — and in 2029 there is
	# no plan to have laid it. The land underneath is identical either way, which
	# is what `Realm.same_land_as` is for; this is the sixty-nine years.
	if Realm.before_the_plan(c.w.realm):
		return
	var lay := Lay.new(c, occ, Vector2.from_angle(bearing(c.s)))
	lay.base = GenFields.snapshot(occ)
	lay.m_start = c.w.landmarks.size()
	lay.m_region = lay.m_start
	var laid: Array = []
	for def in BiomeRegistry.all():
		var fn: StringName = evidence(def.id).works
		if fn == &"":
			continue
		for k in _regions(lay, def).size():
			_enter(lay, def, k)
			var m0 := c.w.landmarks.size()
			Callable(lay.host, fn).call(lay)
			if checking:
				laid.append([def, k, _marks(c.w, m0, c.w.landmarks.size())])
		c.mark(StringName("works." + String(def.id)))
	# Each region again, alone, after every other region is laid: what it sites
	# and composes must not have moved (`checked`).
	for row: Array in laid:
		var def: BiomeDef = row[0]
		_enter(lay, def, int(row[1]))
		lay.writes = false
		var n0 := c.w.props.size()
		var m0 := c.w.landmarks.size()
		var l0 := c.w.lines.size()
		Callable(lay.host, evidence(def.id).works as StringName).call(lay)
		checked.append({"land": def.id, "region": lay.region, "world": row[2], "alone": _marks(c.w, m0, c.w.landmarks.size())})
		c.w.props.resize(n0)
		c.w.landmarks.resize(m0)
		c.w.lines.resize(l0)
		lay.writes = true
	lay.id = &""
	lay.own = -1
	lay.region = -1
	lay.at = 0
	lay.all_sizes = PackedFloat32Array()
	lay.shares.clear()
	lay.m_region = lay.m_start
	lay.rects.clear()
	lay.sizes = PackedFloat32Array()
	lay.rng = Rng.make(c.s, 0x3058)
	lay.site_rng = lay.rng
	lay.site_memo.clear()
	lay.founder_cells = null
	lay.host = GenWorks
	# The people's things are rows too, composed against the land as the works
	# left it: they keep off the works' pieces, and off nothing else of their own.
	lay.base = GenFields.snapshot(occ)
	_villages(lay)
	_roads(lay)
	_remains(lay)
	c.mark(&"works.people")
	_spawn_view(lay)
	_survey(lay)
	_vignettes(lay)
	_stolen_light(lay)
	c.mark(&"works.vignettes")


# --- helpers ---------------------------------------------------------------------

## A test's hook: set, every region's works are laid a second time alone,
## after all the others, writing no grid, and `checked` holds what each laid
## both times (`_marks`).
static var checking := false
static var checked: Array = []


## The regions of `def`'s landscape, the region -1 standing for them all when it
## is too small to hold one; sets the Lay's view of them.
static func _regions(L: Lay, def: BiomeDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	L.all_sizes = PackedFloat32Array()
	for r: Dictionary in L.w.regions:
		if int(r.get("index", -1)) == def.index:
			out.append(r)
			L.all_sizes.append(float(r.tiles))
	# A landscape too small to hold a region still lays its works, from darts
	# at the whole land (`_dart`), as region -1.
	if out.is_empty():
		out.append({"id": -1})
	return out


## Make the Lay lay region `k` of `def`'s landscape: its darts keyed on the
## landscape and region, its share of every count, and the works it can see.
static func _enter(L: Lay, def: BiomeDef, k: int) -> void:
	var regions := _regions(L, def)
	var r := regions[k]
	L.id = def.id
	L.own = def.index
	L.host = evidence(def.id).get("host", GenWorks)
	L.shares.clear()
	L.region = int(r.id)
	L.at = k
	L.rects.clear()
	L.sizes = PackedFloat32Array()
	if L.region >= 0:
		L.rects.append(r.bounds as Rect2)
		L.sizes.append(float(r.tiles))
	# Thrown from the region's own key, never its id (GenCountries.region_key).
	L.site_rng = Rng.make(L.c.s, Rng.hash_ints(0x3057, String(def.id).hash(), GenCountries.region_key(L.w, L.region)))
	L.site_memo.clear()
	L.founder_cells = null
	L.rng = L.site_rng
	L.m_region = L.w.landmarks.size()


## The works marks from `from` to `to`, as (kind, position) pairs.
static func _marks(w: WorldData, from: int, to: int) -> Array:
	var out: Array = []
	for j in range(from, to):
		out.append([w.landmarks[j].kind, w.landmarks[j].pos])
	return out


## A test's hook: set, the people's things are laid last to first, which must
## lay the same world (`_order`).
static var reversing := false


## 0..n-1, or n-1..0 while `reversing`.
static func _order(n: int) -> Array:
	return range(n - 1, -1, -1) if reversing else range(n)


## How many of a thing a world of this size gets: the landscape's count, and of
## that the region being laid gets its share (`_share`).
static func _n(L: Lay, base: float) -> int:
	return _share(L, maxi(1, roundi(base * maxf(L.c.body_k, 0.3))))


## How many of a work its keeper dens at (`BiomeDef.sentinel`'s `stations`) the
## region being laid gets: its share, and one at least where the region is big
## enough to keep a keeper (Sentinels.MIN_TILES). A share alone gave a
## landscape's one intake or lock to its biggest region, and every other keeper
## of the type stood at its heart with nothing of the plan to eat, its STARVE
## way closed (Sentinels.ways_closed).
static func _n_station(L: Lay, base: float) -> int:
	var keeps := L.region >= 0 and not L.sizes.is_empty() and L.sizes[0] >= float(Sentinels.MIN_TILES) \
		and Sentinels.for_land(L.id) != null
	return maxi(_n(L, base), 1 if keeps else 0)


## THE STATION RULE from the plan's side: a work its keeper dens at stands only
## where a den by it keeps every way its design declares that the ground can
## answer (Sentinels.ways_closed: mud or wash to founder in, water to come to it
## by raft). Its feeds are not laid yet, so STARVE is asked when the keeper is
## placed (Sentinels.lair). True where the landscape keeps no keeper.
##
## A work that has laid its larder by now hands it over as `laid` (with its
## footprint's `extent`), and is asked of the den the keeper will take
## (Sentinels.station_den): its rods under the nearest room's feet send the
## keeper off them, and that den's ground is what has to keep its ways. Without
## `laid` the nearest room is asked, as before: an intake's pipe is laid after
## it, so its larder is not known here.
static func station_holds(L: Lay, p: Vector2, laid := PackedVector2Array(), extent := 0.0) -> bool:
	var def := Sentinels.for_land(L.id)
	if def == null:
		return true
	var landings := _landings(L)
	if not laid.is_empty():
		return Sentinels.station_den(L.w, p, def, landings, L.w.region_at(floori(p.x), floori(p.y)), laid, true, extent).is_finite()
	var den := Sentinels.den_at(L.w, p, def, landings)
	return den.is_finite() and Sentinels.ways_closed(L.w, den, def, true).is_empty()


## THE CHEAP HALF OF THE STATION RULE, asked of many candidates so that
## `station_holds` floods few: the room nearest `p` off its keeper's founder
## ground is clear of home and of every landing, with a way out of it
## (Sentinels.den_clear), and that ground lies somewhere in its reach. What it
## refuses at `p`, `station_holds` without `laid` refuses too; what it passes
## may still be refused. True where the landscape keeps no keeper.
static func station_may_hold(L: Lay, p: Vector2) -> bool:
	var def := Sentinels.for_land(L.id)
	if def == null:
		return true
	if not _founder_near(L, def, p):
		return false
	var sink := Sentinels.founders(def)
	var at := Sentinels.stand_near(L.w, p, 1.4, sink)
	if not Sentinels.den_clear(L.w, at, def, _landings(L)):
		return false
	return sink.is_empty() or Sentinels.founder_tiles(L.w, at, def, 1, def.reach) > 0


## Whether any of `def`'s founder ground may lie within its reach of `p`, read
## off the region's cells of that ground (Sentinels._ground_cells, gathered once
## per region): the cheapest refusal a station has, a few lookups, and on the
## crags and the flats it refuses most candidates. A cell counts out to the
## reach and one cell more, so it refuses only where the founder flood finds
## none of that ground on the tiles the cells read (every other one).
static func _founder_near(L: Lay, def: SentinelDef, p: Vector2) -> bool:
	if Sentinels.founders(def).is_empty() or L.rects.is_empty():
		return true
	var cell := Sentinels.GROUND_CELL
	var cells := _founder_cells(L, def)
	var k := ceili(def.reach / float(cell)) + 1
	var at := Vector2i(floori(p.x) / cell, floori(p.y) / cell)
	for dy in range(-k, k + 1):
		for dx in range(-k, k + 1):
			if cells.has(at + Vector2i(dx, dy)):
				return true
	return false


static func _founder_cells(L: Lay, def: SentinelDef) -> Dictionary:
	if L.founder_cells == null:
		L.founder_cells = Sentinels._ground_cells(L.w, (L.rects[0] as Rect2).grow(def.reach + Sentinels.GROUND_CELL), Sentinels.founders(def))
	return L.founder_cells


## Whether a station of the region's keeper can hold anywhere in the region
## being laid: not when its founder ground lies nowhere within its reach of the
## region (`_founder_cells` empty), where every station would be refused. Asked
## before a station's search and its retries, so a region that cannot keep its
## keeper pays nothing for them: seed 7's salt-flat slivers have no pan in reach.
static func station_ground(L: Lay) -> bool:
	var def := Sentinels.for_land(L.id)
	if def == null or Sentinels.founders(def).is_empty() or L.rects.is_empty():
		return true
	return not _founder_cells(L, def).is_empty()


## Whether a station's den hangs on its larder: its keeper starves, and
## Sentinels.station_den sends the den off the larder. Then the rule is asked
## once the work has laid it (`station_holds` with `laid`); else before the work
## lays anything (`station_first`), so a refused site costs no laying.
static func larder_decides(L: Lay) -> bool:
	var def := Sentinels.for_land(L.id)
	return def != null and def.way_of(SentinelWay.STARVE) != null


## The rule asked before a station is laid at `p`, where its den does not hang
## on its larder (`larder_decides`); true where it does, for `station_holds` to
## answer once the larder is down.
static func station_first(L: Lay, p: Vector2) -> bool:
	return larder_decides(L) or station_holds(L, p)


## The rule asked once a station's larder, every feed the work has laid
## (`Lay.work_from`), is down, where its den hangs on it (`larder_decides`); true
## where it does not, `station_first` having answered.
static func station_last(L: Lay, p: Vector2, extent: float) -> bool:
	return not larder_decides(L) or station_holds(L, p, larder_since(L, L.work_from), extent)


## Where rafts come ashore, which no keeper's den covers: the landing is safe
## ground (Sentinels._lair_worked).
static func _landings(L: Lay) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for row: Dictionary in L.w.continents:
		if bool(row.get("landfall", false)) and row.has("from"):
			out.append(row["from"] as Vector2)
	return out


## A station's site by `_site`'s darts (its arguments), the cheap half of the
## station rule asked of the darts that pass the rest (`station_may_hold`, at
## most STATION_LOOKS of them); (-1, -1) when none passes, or the region can
## hold none of its keeper's stations (`station_ground`). One search, never one
## per refusal.
static func station_site(L: Lay, r: int, rise: int, grounds: Array, apart: float, attempts: int, blend_max: float) -> Vector2i:
	if not station_ground(L):
		return Vector2i(-1, -1)
	return _site(L, r, rise, grounds, apart, attempts, blend_max, true)




## The region being laid's share of `total` over its landscape's regions by
## size, by largest remainder (ties to the earlier region): the shares sum to
## `total` exactly, and each is known from the regions' sizes alone.
static func _share(L: Lay, total: int) -> int:
	if L.all_sizes.size() <= 1:
		return total
	if L.shares.has(total):
		return (L.shares[total] as PackedInt32Array)[L.at]
	var sum := 0.0
	for t in L.all_sizes:
		sum += t
	var out := PackedInt32Array()
	out.resize(L.all_sizes.size())
	var rest: Array = []
	var left := total
	for k in L.all_sizes.size():
		var exact := float(total) * L.all_sizes[k] / sum
		out[k] = floori(exact)
		left -= out[k]
		rest.append([exact - float(out[k]), k])
	rest.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	for j in left:
		out[int(rest[j][1])] += 1
	L.shares[total] = out
	return out[L.at]


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
static func _site(L: Lay, r: int, rise: int, grounds: Array, apart: float, attempts: int = 500, blend_max: float = 0.35,
		station := false) -> Vector2i:
	var c := L.c
	var w := L.w
	attempts = roundi(attempts * effort(c))
	var strict := int(attempts * 0.55)
	var looked := 0
	# WHAT A SEARCH LEARNED IS KEPT for the next one that asks the same thing.
	# The land does not change while the works are laid and places only ever
	# add, so a strict search that found nothing here will find nothing again
	# (the archive asks four times running on a burning with no room for it),
	# and a whole search that found nothing will too: each was 1-5 ms of darts
	# at 256, most of the works stage on a seed whose landscapes are cramped.
	var key := hash([r, rise, grounds, apart, attempts, blend_max, station])
	var known: int = L.site_memo.get(key, 0)
	if known == 2:
		return Vector2i(-1, -1)
	for attempt in range(strict if known == 1 else 0, attempts * 2):
		if attempt == strict and known == 0:
			L.site_memo[key] = 1
			known = 1
		var p := _dart(L)
		var i := p.y * c.size + p.x
		var loose := attempt >= strict
		if c.land[i] == 0 or w.blend[i] > (blend_max if not loose else blend_max + 0.1) or not L.here(p.x, p.y):
			continue
		if attempt < attempts and not grounds.is_empty() and not grounds.has(int(w.ground[i])):
			continue
		# CHEAPEST REFUSAL FIRST. Each check is pure and only `_dart` draws from
		# the rng, so their order decides nothing about WHICH tile is returned --
		# only what a refused dart costs. Once the darts landed inside the type's
		# own regions (8c3f2e2) nearly every one reached `_crowded`, which walks
		# every landmark, and the snowfield's stack search spent 80-150 ms of a
		# 230 ms works stage there. The flatness test reads at most 49 tiles and
		# stops at the first one that fails, and on terraced ground most do.
		if not GenScatter._clear_site(c, p, r if not loose else maxi(2, r - 3), rise if not loose else rise + 1):
			continue
		var room := apart if not loose else apart * 0.45
		if GenScatter._near_village(w, Vector2(p), maxf(room, 14.0)) or _crowded(L, Vector2(p), room):
			continue
		if station:
			if looked >= STATION_LOOKS:
				return Vector2i(-1, -1)
			looked += 1
			if not station_may_hold(L, Vector2(p) + Vector2(0.5, 0.5)):
				continue
		return p
	L.site_memo[key] = 2
	return Vector2i(-1, -1)


## THE FLATTEST ROOMS IN THE REGION BEING LAID, found by walking its own tiles
## rather than throwing darts: none when nothing in it qualifies.
##
## **DARTS DO NOT FIND FLAT GROUND WHERE THERE IS ALMOST NONE.** `_site` asks for
## a whole square within a level, and on the crags' terraces it ran through its
## strict half without a hit and settled in the loose half for a square that
## fell six levels corner to corner. Scoring every FLAT_STEP-th tile by how much
## of the square of radius `r` round it shares its level takes the best there IS,
## for a fixed walk instead of a search that runs longest exactly where it fails.
## A candidate is of the region (`here`), off the stage's first occupancy
## (`base`), water, roads and villages, on `grounds` (any when empty), within
## `blend_max`, clear of where the player wakes by Sentinels.CLEAR_OF_HOME (no
## keeper dens there), `apart` from this region's other works (`_crowded`) and
## `village` from any village.
## For a `station`, only rooms the cheap half of the station rule passes
## (`station_may_hold`): the flattest squares of seed 7's biggest crags region
## are pockets in the terraces, and the first 24 asked had no way out. The
## caller asks the whole of the rule (`station_holds`) of them in order, and
## stops at the first work that stands, so its floods are run only until then.
## Up to `count` of them, flattest first.
const FLAT_STEP := 3
## How many rooms `flattest` asks the cheap half of the station rule of per one
## it returns.
const STATION_LOOKS := 10


static func flattest(L: Lay, r: int, grounds: Array, apart: float, station := false, count := 1, blend_max: float = 0.35,
		village := 18.0) -> Array[Vector2i]:
	var c := L.c
	var w := L.w
	var out: Array[Vector2i] = []
	if L.rects.is_empty() or (station and not station_ground(L)):
		return out
	var rect: Rect2 = L.rects[0]
	var home_clear := Sentinels.CLEAR_OF_HOME + 2.0
	var scored: Array = []
	var y := maxi(int(rect.position.y), r + 1)
	while y < mini(int(rect.end.y), c.size - r - 1):
		var x := maxi(int(rect.position.x), r + 1)
		while x < mini(int(rect.end.x), c.size - r - 1):
			var i := y * c.size + x
			if L.here(x, y) and L.base[i] == 0 and w.blend[i] <= blend_max and c.land[i] != 0 and c.water[i] == 0 \
					and c.road[i] == 0 and (grounds.is_empty() or grounds.has(int(w.ground[i]))) \
					and Vector2(x, y).distance_to(w.spawn) >= home_clear:
				# Every other tile of the square: flatness ranks, it is not a count.
				var l0 := w.level[i]
				var score := 0
				for dy in range(-r, r + 1, 2):
					var row := i + dy * c.size
					for dx in range(-r, r + 1, 2):
						var j := row + dx
						if w.level[j] == l0 and L.base[j] == 0 and c.water[j] == 0 and c.road[j] == 0 and c.village[j] == 0 and c.ramp[j] == 0:
							score += 1
				scored.append(Vector3i(x, y, score))
			x += FLAT_STEP
		y += FLAT_STEP
	# Flattest first, ties in scan order; the dearer refusals only for those
	# taken, the founder cells before any, and the cheap half of the station
	# rule for at most STATION_LOOKS per room returned.
	scored.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.z > b.z or (a.z == b.z and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var def := Sentinels.for_land(L.id) if station else null
	var looked := 0
	for v: Vector3i in scored:
		var at := Vector2(v.x, v.y)
		if def != null and not _founder_near(L, def, at):
			continue
		if GenScatter._near_village(w, at, village) or _crowded(L, at, apart):
			continue
		if station:
			if looked >= count * STATION_LOOKS:
				break
			looked += 1
			if not station_may_hold(L, at + Vector2(0.5, 0.5)):
				continue
		out.append(Vector2i(v.x, v.y))
		if out.size() >= count:
			break
	return out


## A tile to try: inside one of the laid type's own regions, chosen by size, or
## anywhere on the land while laying what every type shares.
##
## **THE DARTS WERE THROWN AT THE WHOLE LAND AND KEPT WHERE THEY LANDED HOME.**
## `GenScatter._random_tile_in`'s header found this for tips and circles: at 1300
## a landscape is a few per cent of `land_rect`, so most of `_site`'s attempts
## never reached it. The bonelands cistern, which asks for flat ground a pale
## landscape rarely has, drew 1, 0 and 0 across seeds 1, 42 and 90210, and its
## own comment below already called it "nought to two" per landscape.
static func _dart(L: Lay) -> Vector2i:
	if L.rects.is_empty():
		return GenScatter._random_tile(L.c, L.site_rng)
	var total := 0.0
	for t in L.sizes:
		total += t
	var pick := L.site_rng.randf() * total
	var k := 0
	while k < L.sizes.size() - 1 and pick > L.sizes[k]:
		pick -= L.sizes[k]
		k += 1
	return GenScatter._random_tile_in(L.c, L.site_rng, L.rects[k])


## THE WORKS ARE ROWS: SITED IN ORDER, COMPOSED EACH ON ITS OWN. A landscape's
## works function sites (its darts are `site_rng`'s, thrown in order) and hands
## each site here; `fn` on the landscape's host composes the work at `at` with `args` and
## says whether it stands. It composes from a stream keyed on the landscape,
## the work and its tile, against the stage's first occupancy and its own
## pieces (`Lay.open`), so the same row lays the same work wherever and
## whenever it is composed -- which is what lets a section of a streamed world
## lay a work from the plan's row alone. A work that gives up is taken back
## whole: its props, its landmarks, its lines and the tiles it took.
##
## `witness`, when a test sets `witnessing`, holds each standing row composed
## twice: in the world, and again alone on a fresh Lay.
static var witnessing := false
static var witness: Array = []

static func _work(L: Lay, fn: StringName, at: Vector2, args: Array = []) -> bool:
	var w := L.w
	var n0 := w.props.size()
	var m0 := w.landmarks.size()
	var l0 := w.lines.size()
	var lit0 := L.lit.size()
	L.work_from = n0
	L.in_work = true
	L.mine.clear()
	L.key = Rng.hash_ints(0x3057, String(L.id).hash(), String(fn).hash(), floori(at.x), floori(at.y), args.hash())
	L.rng = Rng.make(L.c.s, L.key)
	var call := Callable(L.host, fn)
	var stands: bool = call.call(L, at, args)
	if not stands:
		w.props.resize(n0)
		w.landmarks.resize(m0)
		w.lines.resize(l0)
		L.lit.resize(lit0)
		for i: int in L.mine:
			L.occ[i] = L.mine[i]
	var key := L.key
	L.in_work = false
	L.key = 0
	L.rng = L.site_rng
	if stands and witnessing:
		var alone := Lay.new(L.c, L.base, L.d)
		alone.writes = false
		alone.id = L.id
		alone.own = L.own
		alone.site_rng = L.site_rng
		alone.host = L.host
		var n1 := w.props.size()
		var m1 := w.landmarks.size()
		var l1 := w.lines.size()
		alone.in_work = true
		alone.key = key
		alone.rng = Rng.make(L.c.s, key)
		call.call(alone, at, args)
		witness.append({"work": fn, "at": at, "land": L.id,
			"world": _pieces(w, n0, n1), "alone": _pieces(w, n1, w.props.size())})
		w.props.resize(n1)
		w.landmarks.resize(m1)
		w.lines.resize(l1)
	return stands


static func _pieces(w: WorldData, from: int, to: int) -> Array:
	var out: Array = []
	for i in range(from, to):
		var p := w.props[i]
		out.append([p.kind, p.pos, p.rot, p.scale])
	return out


## Another place worth walking to within d of p. Small marks (falls, bridges,
## summits, graves) are passed over: a work may stand near them.
static func _crowded(L: Lay, p: Vector2, d: float) -> bool:
	var marks := L.w.landmarks
	var d2 := d * d
	# Distance before kind: most landmarks are far, and the far test is one
	# subtraction where the kind test is six StringName compares. Other regions'
	# works are not looked at (`Lay.m_region`): the ecotone keeps them apart,
	# as sites refuse blended ground and two regions of one landscape never touch.
	for j in marks.size():
		if j >= L.m_start and j < L.m_region:
			continue
		var m: Dictionary = marks[j]
		if (m.pos as Vector2).distance_squared_to(p) >= d2:
			continue
		var k: StringName = m.kind
		if k == &"falls" or k == &"bridge" or k == &"summit" or k == &"graves" or k == &"stolen_light" or k == &"iced_line":
			continue
		return true
	return false


## Where every feed of the landscape's keeper laid since prop `from` stands: a
## work's own larder, handed to `station_holds` once the work has laid it.
static func larder_since(L: Lay, from: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var def := Sentinels.for_land(L.id)
	if def == null:
		return out
	for i in range(from, L.w.props.size()):
		var p: WorldProp = L.w.props[i]
		if def.feeds.has(p.kind):
			out.append(p.pos)
	return out


## This region's works rows of `kind` within d of p. Other regions' works are
## never seen (`Lay.m_region`), as `_crowded` keeps them: a work hangs on its
## own region's ground and works.
static func _rows_near(L: Lay, kind: StringName, p: Vector2, d: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var marks := L.w.landmarks
	for j in range(L.m_region, marks.size()):
		var m: Dictionary = marks[j]
		if m.kind == kind and (m.pos as Vector2).distance_to(p) <= d:
			out.append(m)
	return out


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
	if not L.open(p, clear):
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
	var prop := GenScatter._add(c, kind, p, fposmod(rot, TAU), L.key)
	if exact:
		prop.scale = 1.0
		prop.solid = PropKind.SOLID[kind]
	L.take(p, maxf(PropKind.SOLID[prop.kind] * prop.scale, 0.0))
	return prop


## Put one prop standing IN WATER at p, on a tile of `ground`: what the sea took
## and left standing (a drowned city's roofs, on the shallow sea's WATER), or the
## plan's own furniture in a canal (a lock's gates, on a street's BLACKWATER).
## Never the deep a raft is the only way across; nothing else within `clear`, at
## scale 1, and never in the spawn's first steps. It stands on its tile's level,
## under the sheet. Inside a work it reads the stage's first occupancy and the
## work's own pieces, as `Lay.open` does.
static func _put_awash(L: Lay, kind: int, p: Vector2, rot: float, clear: float, ground: int = Ground.WATER) -> WorldProp:
	var c := L.c
	var tx := floori(p.x)
	var ty := floori(p.y)
	if tx < 3 or ty < 3 or tx >= c.size - 3 or ty >= c.size - 3:
		return null
	var i := ty * c.size + tx
	if L.w.ground[i] != ground or (ground == Ground.WATER and c.land[i] != 0):
		return null
	var ri := ceili(clear)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var j := (ty + dy) * c.size + tx + dx
			if (L.base[j] if L.in_work else L.occ[j]) != 0 or (L.in_work and L.mine.has(j)):
				return null
	if (p - L.w.spawn).length_squared() < 100.0:
		return null
	var prop := GenScatter._add(c, kind, p, fposmod(rot, TAU), L.key)
	prop.scale = 1.0
	prop.solid = PropKind.SOLID[kind]
	L.take(p, PropKind.SOLID[kind])
	return prop


## A solid a work stands on: at `p` or, where `p` is on a terrace lip, the
## nearest tile round it that takes one. `_site` allows its site a rise of a
## level, so the site's own middle can be the lip, and a work that asked only
## there gave up on ground a step away from where it could stand. The step
## keeps to the landscape's own ground: a snowfield stack stepped two tiles
## over a border stood as the slums' work, and the snowfield lost its depot.
const FOOTING: Array[Vector2] = [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]

static func _put_footed(L: Lay, kind: int, p: Vector2, rot: float, clear: float, exact: bool = false) -> WorldProp:
	for k in FOOTING:
		var q := p + k
		if k != Vector2.ZERO and L.own >= 0 and not (L.w.in_bounds(floori(q.x), floori(q.y)) and L.home(floori(q.x), floori(q.y))):
			continue
		var prop := _put(L, kind, q, rot, -99, clear, exact)
		if prop != null:
			return prop
	return null


## A SOLID ON A STEP: at `q` or the nearest of a cross of tiles round it, out to
## `reach` along the survey bearing and across it, on a tile no more than ONE
## level off any of its four neighbours, standing across that step (`_put`'s
## `berthed`). Null when none of them will take it.
##
## Where nearly every tile is on a one-level step (the crags' terraces, the
## frost sea's ice), `_put`'s rule that a solid stands on ONE level refused every
## mast of every bench, and `_put_footed`'s ring keeps to it. A tripod's legs
## take a level's half unit; a cliff's two levels they do not.
static func put_on_step(L: Lay, kind: int, q: Vector2, rot: float, clear: float = 0.0, reach: float = 1.6) -> WorldProp:
	var c := L.c
	var w := L.w
	var offs: Array[Vector2] = [Vector2.ZERO]
	var r := reach * 0.5
	while r <= reach + 0.01:
		offs.append_array([L.nrm * r, -L.nrm * r, L.d * r, -L.d * r])
		r += reach * 0.5
	for off: Vector2 in offs:
		var at := q + off
		var x := floori(at.x)
		var y := floori(at.y)
		if x < 3 or y < 3 or x >= c.size - 3 or y >= c.size - 3:
			continue
		var i := y * c.size + x
		var steep := false
		for k: int in [1, -1, c.size, -c.size]:
			if absi(w.level[i + k] - w.level[i]) > 1:
				steep = true
		if steep:
			continue
		var prop := _put(L, kind, at, rot, -99, clear, true, true)
		if prop != null:
			return prop
	return null


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
			L.take(p + dir * step * 0.3, 0.0)
			L.take(p - dir * step * 0.3, 0.0)
	return ids


## Mark every tile of a rotated rectangle occupied, so the scatter grows
## nothing there (a clearcut, a corridor, a drill field).
static func _clear_rect(L: Lay, centre: Vector2, dir: Vector2, half: Vector2) -> void:
	var c := L.c
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
				L.take_tile(y * c.size + x)


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
## search), within SHORE_STEPS of the sea, on one of `grounds`, heart-side of
## any ecotone, away from other places.
const SHORE_STEPS := 4


static func _shore(L: Lay, grounds: Array, apart: float, attempts: int = 900) -> Vector2i:
	for attempt in attempts:
		var p := _dart(L)
		var room := apart if attempt < attempts * 0.6 else apart * 0.4
		if _shore_at(L, p, grounds, 1 if attempt < attempts * 0.6 else 2, room):
			return p
	return Vector2i(-1, -1)


## The shore tiles within `reach` of `at` that `_shore` would take (their ground,
## their level up to the second, `apart` off the marks), nearest first: where a
## work has to stand at one place on the coast, not anywhere along it.
static func _shores_near(L: Lay, grounds: Array, at: Vector2, reach: int, apart: float) -> Array[Vector2i]:
	var o := Vector2i(at.floor())
	var tiles: Array[Vector2i] = []
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx * dx + dy * dy <= reach * reach and L.w.in_bounds(o.x + dx, o.y + dy):
				tiles.append(o + Vector2i(dx, dy))
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a - o).length_squared()
		var db := (b - o).length_squared()
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	var out: Array[Vector2i] = []
	for p: Vector2i in tiles:
		if _shore_at(L, p, grounds, 2, apart):
			out.append(p)
	return out


## `p` is a shore tile a work may stand on: dry ground of `grounds` a level or two
## up (to `top`), within SHORE_STEPS of the sea, off water, roads and villages and
## islets, in the region being laid, `room` off the marks, and facing the sea.
static func _shore_at(L: Lay, p: Vector2i, grounds: Array, top: int, room: float) -> bool:
	var c := L.c
	var w := L.w
	var i := p.y * c.size + p.x
	if w.level[i] < 1 or w.level[i] > top or c.sea_steps[i] > SHORE_STEPS or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0:
		return false
	if not grounds.is_empty() and not grounds.has(int(w.ground[i])):
		return false
	if w.islet_at(p.x, p.y) or not L.here(p.x, p.y):
		return false
	if _crowded(L, Vector2(p), room) or GenScatter._near_village(w, Vector2(p), maxf(room * 0.7, 14.0)):
		return false
	return _sea_dir(c, p).length() >= 0.5


## Whether `region` of a finished world holds a tile `_shore` could give: land
## at level 1 or 2 within SHORE_STEPS steps of the sea (level 0 and below, and
## off the map), read off the levels, since the stage's own steps
## (GenContext.sea_steps) are gone by then, and off the skerries, by the one
## mask `_shore_at` reads (WorldData.islet_at). Seed 42's 400-tile coast
## region 39 has shore only on a skerry.
static func has_shore(world: WorldData, region: Dictionary) -> bool:
	var id := int(region.get("id", -1))
	var b: Rect2 = region.get("bounds", Rect2())
	for y in range(floori(b.position.y), ceili(b.end.y)):
		for x in range(floori(b.position.x), ceili(b.end.x)):
			var l := world.level_at(x, y)
			if l < 1 or l > 2 or world.region_at(x, y) != id or world.islet_at(x, y):
				continue
			for dy in range(-SHORE_STEPS, SHORE_STEPS + 1):
				var k := SHORE_STEPS - absi(dy)
				for dx in range(-k, k + 1):
					if not world.in_bounds(x + dx, y + dy) or world.level_at(x + dx, y + dy) <= 0:
						return true
	return false


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


## The heart of the type being laid: the first country heart that lies in the
## region being laid.
static func _heart(L: Lay) -> Vector2i:
	for h in L.c.hearts:
		if h.x >= 0.0 and L.w.in_bounds(int(h.x), int(h.y)) and L.here(int(h.x), int(h.y)):
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
	# Turf cut in the machines' rows: a ruled field of strips on the open turf,
	# survey posts at its corners, a fence along its end, a warning at its side.
	for n in _n(L, 2.0):
		var p := _site(L, 8, 1, [Ground.GRASS, Ground.HEATH], 26.0)
		if p.x >= 0:
			_work(L, &"_turf_rows", Vector2(p) + Vector2(0.5, 0.5))
	# The intake: a machine housing at the shore, its pipes out to the water,
	# fenced square, a tide gauge standing in the wash.
	var intakes := 0
	for attempt in 24:
		if intakes >= _n_station(L, 1.0):
			break
		var p := _shore(L, [Ground.SAND, Ground.SHINGLE, Ground.GRASS, Ground.GRAVEL] if attempt < 5 else [], 40.0)
		if p.x >= 0 and _work(L, &"_intake", Vector2(p) + Vector2(0.5, 0.5)):
			intakes += 1
	# Trawlers beached where the sea put them: on the sand or the shingle, lying
	# along the shore, a field of debris and wreckage round each.
	var hulls := 0
	for attempt in 16:
		if hulls >= _n(L, 2.0):
			break
		var beach := attempt < 12
		var p := _shore(L, [Ground.SAND, Ground.SHINGLE] if beach else [], 30.0 if attempt < 6 else 14.0, 1500)
		if p.x >= 0 and _work(L, &"_hulk", Vector2(p) + Vector2(0.5, 0.5), [beach]):
			hulls += 1
	# The sea wall, broken along the shore, a drowned car at its foot.
	var walls := 0
	for attempt in 12:
		if walls >= _n(L, 2.0):
			break
		var p := _shore(L, [], 30.0)
		if p.x >= 0 and _work(L, &"_sea_wall", Vector2(p) + Vector2(0.5, 0.5)):
			walls += 1
	# Tide gauges along the shingle, where the machines read the sea.
	var gauges := 0
	for attempt in 12:
		if gauges >= _n(L, 2.0):
			break
		var p := _shore(L, [Ground.SHINGLE, Ground.SAND] if attempt < 6 else [], 24.0, 300)
		if p.x >= 0 and _work(L, &"_tide_gauge", Vector2(p) + Vector2(0.5, 0.5)):
			gauges += 1
	# Cars drowned at the tide line.
	var cars := 0
	for attempt in 600:
		if cars >= _n(L, 3.0):
			break
		var p := _shore(L, [Ground.SAND, Ground.SHINGLE], 12.0, 60)
		if p.x >= 0 and _work(L, &"_drowned_car", Vector2(p) + Vector2(0.5, 0.5)):
			cars += 1


static func _turf_rows(L: Lay, at: Vector2, _a: Array) -> bool:
	var d := L.d
	var nrm := L.nrm
	var half := Vector2(L.rng.randf_range(8.0, 11.0), L.rng.randf_range(5.0, 7.0))
	_record(L.c, &"turf_rows", at, d, half, CUT)
	var l := _level(L.c, Vector2i(at.floor()))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_put(L, PropKind.SURVEY, at + d * half.x * sx + nrm * half.y * sy, d.angle(), -99, 0.0, true)
	_run(L, PropKind.FENCE, at - d * (half.x + 0.6) - nrm * half.y, nrm, ceili(half.y), 2.0, l, 0.15)
	_put(L, PropKind.SIGN, at + nrm * (half.y + 1.2), nrm.angle(), -99, 0.3)
	_about(L, PropKind.WRECKAGE, at + d * (half.x + 2.0), 1, 0.0, 2.0)
	return true


static func _intake(L: Lay, at: Vector2, _a: Array) -> bool:
	var p := Vector2i(at.floor())
	var sea := _sea_dir(L.c, p)
	var l := _level(L.c, p)
	var intake: WorldProp = null
	for back in 4:
		intake = _put(L, PropKind.INTAKE, at - sea * back, sea.angle(), l if back == 0 else -99, 1.0, true)
		if intake != null:
			at = intake.pos
			break
	if intake == null or not station_holds(L, at):
		return false
	_record(L.c, &"intake", at, sea, Vector2(4.0, 4.0))
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
	_run(L, PropKind.PIPE, at - sea * 6.0, inland, L.rng.randi_range(9, 14), 2.0, -99, 0.1)
	return true


## A trawler on the shore at `at`, `a[0]` whether it must lie on the beach.
static func _hulk(L: Lay, at: Vector2, a: Array) -> bool:
	var beach: bool = a[0]
	var sea := _sea_dir(L.c, Vector2i(at.floor()))
	var along := Vector2(-sea.y, sea.x)
	var hull: WorldProp = null
	for back: float in [0.0, 1.0, -1.0, 2.0, 3.0]:
		var q := at - sea * back
		var turn := along.angle() + L.rng.randf_range(-0.3, 0.3)
		if not _berth(L, q, Vector2.from_angle(turn), beach):
			continue
		hull = _put(L, PropKind.HULL, q, turn, -99, 0.8, false, true)
		if hull != null:
			break
	if hull == null:
		return false
	_record(L.c, &"hulk", hull.pos, sea, Vector2(3.0, 2.0))
	_about(L, PropKind.DEBRIS, hull.pos, 3, 2.5, 5.0)
	_about(L, PropKind.WRECKAGE, hull.pos, 1, 2.5, 4.5)
	_about(L, PropKind.DRIFTWOOD, hull.pos, 2, 2.0, 5.0)
	_gauge(L, hull.pos + along * 3.5, sea)
	return true


static func _sea_wall(L: Lay, p: Vector2, _a: Array) -> bool:
	var sea := _sea_dir(L.c, Vector2i(p.floor()))
	var along := Vector2(-sea.y, sea.x)
	var at := p - sea
	var ids := _run(L, PropKind.SEA_WALL, at - along * 7.0, along, 5, 2.8, -99, 0.15)
	if ids.is_empty():
		return false
	for id in ids:
		# The wall's sea face (+Z) looks at the sea.
		L.w.props[id].rot = fposmod(along.angle() + (PI if along.rotated(PI * 0.5).dot(sea) < 0.0 else 0.0), TAU)
	_record(L.c, &"sea_wall", at, along, Vector2(7.0, 1.0))
	_about(L, PropKind.VEHICLE, at + sea * 2.0, 1, 0.0, 3.0)
	_about(L, PropKind.DEBRIS, at, 2, 1.5, 5.0)
	_put(L, PropKind.SIGN, at - sea * 2.2, (-sea).angle(), -99, 0.2)
	return true


static func _tide_gauge(L: Lay, at: Vector2, _a: Array) -> bool:
	return _gauge(L, at, _sea_dir(L.c, Vector2i(at.floor()))) != null


static func _drowned_car(L: Lay, at: Vector2, _a: Array) -> bool:
	return _put(L, PropKind.VEHICLE, at, L.rng.randf() * TAU, -99, 0.8) != null


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
	# The drained fen: straight cuts, a pump house on them, its pipeline
	# striding off on stilts, a car sunk in the black water, reeds in the wire.
	for n in _n(L, 3.0):
		var p := _site(L, 7, 1, [Ground.MOSS, Ground.PEAT, Ground.MUD, Ground.GRASS, Ground.HEATH], 30.0, 700, 0.45)
		if p.x >= 0:
			_work(L, &"_drained", Vector2(p) + Vector2(0.5, 0.5))
	# Bog graves: stakes in a row by a stilt hut, a memorial for the drowned.
	for n in _n(L, 2.0):
		var p := _site(L, 4, 1, [Ground.MOSS, Ground.PEAT, Ground.HEATH, Ground.GRASS], 24.0, 500, 0.45)
		if p.x >= 0:
			_work(L, &"_bog_graves", Vector2(p) + Vector2(0.5, 0.5))


static func _drained(L: Lay, at: Vector2, _a: Array) -> bool:
	var d := L.d
	var nrm := L.nrm
	var l := _level(L.c, Vector2i(at.floor()))
	var half := Vector2(L.rng.randf_range(11.0, 15.0), L.rng.randf_range(7.0, 9.0))
	_record(L.c, &"drained", at, d, half, CUT)
	var pump := _put(L, PropKind.PUMP_HOUSE, at, d.angle(), l, 1.0, true)
	if pump == null:
		pump = _put(L, PropKind.PUMP_HOUSE, at + nrm * 2.0, d.angle(), -99, 0.8, true)
	var start := (pump.pos if pump != null else at) + d * 2.8
	_run(L, PropKind.PIPE, start, d, L.rng.randi_range(9, 14), 2.0, -99, 0.08)
	_run(L, PropKind.FENCE, at - d * half.x * 0.8 + nrm * (half.y + 0.5), d, 6, 2.0, -99, 0.25)
	_about(L, PropKind.VEHICLE, at, 1, 4.0, half.y)
	_about(L, PropKind.WRECKAGE, at, 1, 3.0, half.y)
	_put(L, PropKind.SIGN, at - d * 2.5 + nrm * 1.6, d.angle(), -99, 0.2)
	return true


static func _bog_graves(L: Lay, at: Vector2, _a: Array) -> bool:
	var rng := L.rng
	var row := Vector2.from_angle(rng.randf() * TAU)
	var graves := 0
	for i in rng.randi_range(4, 6):
		if _put(L, PropKind.GRAVE, at + row * (i * 1.3 - 3.0) + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)), row.angle() + PI * 0.5, -99, 0.2) != null:
			graves += 1
	if graves == 0:
		return false
	_record(L.c, &"bog_graves", at, row, Vector2(4.0, 1.0))
	_about(L, PropKind.MEMORIAL, at - row.orthogonal() * 2.0, 1, 0.0, 1.5)
	var shack := _put(L, PropKind.SHACK, at + row.orthogonal() * 4.0, rng.randf() * TAU, -99, 1.0)
	if shack != null:
		_note_lit_shack(L, shack)
	return true


# --- the pinewood ------------------------------------------------------------------

static func _pinewood(L: Lay) -> void:
	var c := L.c
	# The relay corridor: one straight cut through the heart of the pines, masts
	# strung along it with the machines' light on them, stumps at its edges.
	# One to a landscape: its largest region's share.
	if _share(L, 1) > 0:
		var through := _heart(L)
		if through.x < 0:
			through = _site(L, 2, 3, [], 0.0, 400, 0.5)
		if through.x >= 0:
			_work(L, &"_relay_corridor", Vector2(through) + Vector2(0.5, 0.5))
	# Clearcuts in exact squares: stumps in the harvester's rows, the wood
	# standing thick round the edge, a warning at the corner.
	for n in _n(L, 3.0):
		var p := _site(L, 7, 1, [Ground.NEEDLES, Ground.GRASS, Ground.HEATH], 28.0, 700, 0.4)
		if p.x >= 0:
			_work(L, &"_clearcut", Vector2(p) + Vector2(0.5, 0.5), [n % 2 == 0])
	# Fire towers on the rises, a hunting blind below, a grave for whoever kept it.
	for n in _n(L, 2.0):
		var found: Array = []
		for attempt in 40:
			var p := _site(L, 3, 1, [], 30.0, 20, 0.4)
			if p.x >= 0:
				found.append([c.rise[p.y * c.size + p.x], p])
		if found.is_empty():
			continue
		found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		var rises: Array[Vector2] = []
		for f: Array in found:
			rises.append(Vector2(f[1] as Vector2i) + Vector2(0.5, 0.5))
		_work(L, &"_fire_tower", rises[0], [rises])
	# A burned grove: dead trees standing close in scorched ground.
	for n in _n(L, 1.5):
		var p := _site(L, 6, 1, [Ground.NEEDLES, Ground.GRASS], 28.0, 600, 0.4)
		if p.x >= 0:
			_work(L, &"_burned_grove", Vector2(p) + Vector2(0.5, 0.5))


static func _relay_corridor(L: Lay, mid: Vector2, _a: Array) -> bool:
	var c := L.c
	var w := L.w
	var along := L.nrm if L.rng.randf() < 0.5 else L.d
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
	return true


## A clearcut at `at`, ruled on the bearing when `a[0]`, across it otherwise.
static func _clearcut(L: Lay, at: Vector2, a: Array) -> bool:
	var half := L.rng.randf_range(6.0, 8.5)
	var dd := L.d if a[0] else L.nrm
	var dn := Vector2(-dd.y, dd.x)
	var steps := floori(half)
	for gy in range(-steps, steps + 1, 2):
		for gx in range(-steps, steps + 1, 2):
			var q := at + dd * float(gx) + dn * float(gy)
			var st := _put(L, PropKind.STUMP, q, L.rng.randf() * TAU, -99, 0.0)
			if st != null:
				st.scale = 0.9 + L.rng.randf() * 0.25
	_clear_rect(L, at, dd, Vector2(half + 0.5, half + 0.5))
	_record(L.c, &"clearcut", at, dd, Vector2(half + 0.5, half + 0.5), CUT)
	# The sign is put by hand: its corner tile is in the cleared square.
	var corner := at + (dd + dn) * (half + 1.6)
	_put(L, PropKind.SIGN, corner, (dd + dn).angle(), -99, 0.0)
	return true


## A fire tower on the highest of `a[0]`'s rises it can stand on.
static func _fire_tower(L: Lay, _at: Vector2, a: Array) -> bool:
	var tower: WorldProp = null
	for q: Vector2 in a[0]:
		tower = _put(L, PropKind.FIRE_TOWER, q, L.d.angle(), -99, 0.8, true)
		if tower != null:
			break
	if tower == null:
		return false
	_record(L.c, &"fire_tower", tower.pos, L.d, Vector2(2.0, 2.0))
	_about(L, PropKind.SHACK, tower.pos, 1, 3.0, 6.0)
	_about(L, PropKind.GRAVE, tower.pos, 1, 2.5, 5.0)
	return true


static func _burned_grove(L: Lay, at: Vector2, _a: Array) -> bool:
	var r := L.rng.randf_range(5.0, 7.0)
	_about(L, PropKind.DEAD_TREE, at, 10, 0.5, r)
	_about(L, PropKind.STUMP, at, 4, 0.5, r)
	_about(L, PropKind.WRECKAGE, at, 1, 1.0, r)
	_clear_rect(L, at, L.d, Vector2(r, r * 0.8))
	_record(L.c, &"burned_grove", at, L.d, Vector2(r, r * 0.8), SCORCH)
	return true


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
	_clear_rect(L, from + along * (t0 + length * 0.5), along, Vector2(length * 0.5, 2.6))
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
			mast = GenScatter._add(c, PropKind.RELAY, qq.floor() + Vector2(0.5, 0.5), fposmod(along.angle(), TAU), L.key)
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
	var d := L.d
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
			if w.blend[i] > 0.5 or not L.here(floori(q.x), floori(q.y)) or _in_village(w, q, 5.0):
				continue
			var along := (road[j + 3] - road[j - 3]).normalized()
			# A straight stretch: the road holds its line for three tiles either way.
			if (road[j + 3] - road[j]).normalized().dot(along) < 0.9 or (road[j] - road[j - 3]).normalized().dot(along) < 0.9:
				continue
			spots.append([w.blend[i], q, along])
	spots.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var done := 0
	for spot: Array in spots:
		if done >= _n(L, 2.0):
			break
		var q: Vector2 = spot[1]
		if not _crowded(L, q, 12.0) and _work(L, &"_checkpoint", q, [spot[2]]):
			done += 1
	for attempt in 10:
		if done > 0 or _n(L, 2.0) == 0:
			break
		# No road through the snow took one: it stands on the open field anyway.
		var p := _site(L, 4 if attempt < 5 else 2, 1, [], 30.0 if attempt < 5 else 10.0, 500, 0.5)
		if p.x >= 0 and _work(L, &"_field_checkpoint", Vector2(p) + Vector2(0.5, 0.5)):
			done += 1
	# The tall stack, fenced, seen from everywhere.
	#
	# ONE STRICT SEARCH, THEN THE LOOSE ONES. The first four attempts asked the
	# same question -- six tiles of flat ground, 44 clear of every place -- of the
	# same regions, each a full `_site` of about 3,500 darts at 21 landscapes,
	# and on a world that has no such spot the three repeats could only fail the
	# same way: 49-74 ms of a ~150 ms works stage at 256 (task #32). A strict
	# search that found nothing sends the rest straight to the looser ground.
	var stacks := 0
	var strict_failed := false
	for attempt in 8:
		if stacks >= _n(L, 1.0):
			break
		var strict := attempt < 4 and not strict_failed
		if attempt < 4 and strict_failed:
			continue
		var p := _site(L, 6 if strict else 3, 1, [], 44.0 if strict else 16.0, 500, 0.45)
		if p.x < 0:
			if strict:
				strict_failed = true
			continue
		if _work(L, &"_stack", Vector2(p) + Vector2(0.5, 0.5), [strict]):
			stacks += 1
	# A convoy that never got through: vehicles buried in a line, a snow fence.
	for n in _n(L, 1.0):
		var p := _site(L, 5, 1, [Ground.SNOW], 30.0, 600, 0.4)
		if p.x >= 0:
			_work(L, &"_convoy", Vector2(p) + Vector2(0.5, 0.5))
	# Where the grid crosses the snow its lines hang with ice (WorldView strings
	# it): the span nearest the snow's heart is recorded so it can be walked to.
	var best := 1e9
	var iced := Vector2(-1, -1)
	var heart := _heart(L)
	for line in w.lines if _share(L, 1) > 0 else []:
		if line.kind != PropKind.PYLON and line.kind != PropKind.POLE:
			continue
		var ids: PackedInt32Array = line.props
		for k in ids.size() - 1:
			var mid := (w.props[ids[k]].pos + w.props[ids[k + 1]].pos) * 0.5
			if not L.here(floori(mid.x), floori(mid.y)) or w.blend[floori(mid.y) * c.size + floori(mid.x)] > 0.4:
				continue
			var score := mid.distance_squared_to(Vector2(heart)) if heart.x >= 0 else 0.0
			if score < best:
				best = score
				iced = mid
	if iced.x >= 0.0:
		_record(c, &"iced_line", iced, d, Vector2(1.0, 1.0))
	# Emergency shelters, a grave by each.
	for n in _n(L, 2.0):
		var p := _site(L, 3, 1, [], 26.0, 500, 0.45)
		if p.x >= 0:
			_work(L, &"_shelter", Vector2(p) + Vector2(0.5, 0.5))


## A gate on the road at `q`, the road running `a[0]`.
static func _checkpoint(L: Lay, q: Vector2, a: Array) -> bool:
	var w := L.w
	var along: Vector2 = a[0]
	var i := floori(q.y) * L.c.size + floori(q.x)
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
		return false
	# `across` now points from the booth over the road.
	_record(L.c, &"checkpoint", q, along, Vector2(3.0, 3.0))
	_run(L, PropKind.FENCE, booth.pos - across * 1.2 - along * 0.5, -across, 3, 2.0, -99, 0.1)
	_run(L, PropKind.FENCE, booth.pos + across * 5.6 + along * 0.5, across, 3, 2.0, -99, 0.1)
	_put(L, PropKind.BARRICADE, booth.pos + along * 3.4 - across * 0.4, along.angle(), -99, 0.4)
	_put(L, PropKind.SIGN, booth.pos - along * 4.5, (-along).angle(), -99, 0.2)
	_about(L, PropKind.DEBRIS, q, 1, 4.0, 6.0)
	return true


static func _field_checkpoint(L: Lay, at: Vector2, _a: Array) -> bool:
	var booth := _put_footed(L, PropKind.CHECKPOINT, at, L.d.angle(), 0.6, true)
	if booth == null:
		return false
	at = booth.pos
	_record(L.c, &"checkpoint", at, L.d, Vector2(3.0, 3.0))
	_run(L, PropKind.FENCE, at - L.nrm * 1.5, -L.nrm, 4, 2.0, -99, 0.1)
	return true


## The stack at `at`, with the room a strict site gave it when `a[0]`.
static func _stack(L: Lay, at: Vector2, a: Array) -> bool:
	var d := L.d
	var stack := _put_footed(L, PropKind.STACK, at, d.angle(), 1.2 if a[0] else 0.8, true)
	if stack == null:
		return false
	at = stack.pos
	# THE DEPOT STANDS AT IT. The stack is the snowfield's one marked work, so a
	# stack with no yard's room round it (`Works.sites` looks there) leaves the
	# snowfield without a depot or a keeper's larder. Asked of the ground alone,
	# so it is the row's own answer. Asked once, without the yard's facing: a
	# yard that stands facing the bearing stands at all, so the looser question
	# answers the same, and a stack with no room was paying for the scan twice.
	var region := L.w.region_at(floori(at.x), floori(at.y))
	if not Works.stand_near(L.w, at, true, region).is_finite():
		return false
	# SCORCH: the soot a stack throws on the snow round it. Unmarked, the
	# snowfield's works were never a place `Works.sites` counts, so it never
	# had a depot at all.
	_record(L.c, &"stack", at, d, Vector2(4.5, 4.5), SCORCH)
	for side in 4:
		var e := d.rotated(side * PI * 0.5)
		var en := Vector2(-e.y, e.x)
		_run(L, PropKind.FENCE, at + e * 4.5 - en * 4.5, en, 4 if side != 2 else 2, 2.25, -99, 0.1)
	_about(L, PropKind.DEBRIS, at, 2, 5.5, 8.0)
	_put(L, PropKind.SIGN, at - d * 6.0, (-d).angle(), -99, 0.2)
	return true


static func _convoy(L: Lay, at: Vector2, _a: Array) -> bool:
	var d := L.d
	var nrm := L.nrm
	var placed := 0
	for i in 4:
		if _put(L, PropKind.VEHICLE, at + d * (i * 3.4 - 5.0) + nrm * L.rng.randf_range(-0.3, 0.3), d.angle() + L.rng.randf_range(-0.15, 0.15), -99, 0.8) != null:
			placed += 1
	if placed == 0:
		return false
	_record(L.c, &"convoy", at, d, Vector2(7.0, 2.0))
	_run(L, PropKind.FENCE, at - d * 6.0 + nrm * 2.5, d, 6, 2.0, -99, 0.2)
	_about(L, PropKind.WRECKAGE, at, 2, 2.0, 5.0)
	return true


static func _shelter(L: Lay, at: Vector2, _a: Array) -> bool:
	var shack := _put_footed(L, PropKind.SHACK, at, L.rng.randf() * TAU, 1.0)
	if shack == null:
		return false
	at = shack.pos
	_note_lit_shack(L, shack)
	_record(L.c, &"shelter", at, L.d, Vector2(2.0, 2.0))
	_about(L, PropKind.GRAVE, at, 1, 2.5, 4.0)
	return true


# --- the bonelands -----------------------------------------------------------------

static func _bonelands(L: Lay) -> void:
	var c := L.c
	var pale: Array = [Ground.LIMESTONE, Ground.BONE, Ground.GRAVEL, Ground.GRASS, Ground.SCREE, Ground.HEATH]
	# Quarries cut in the grid: benches in exact squares, drills standing in
	# them, a conveyor carrying the stone off along the bearing.
	for n in _n(L, 2.0):
		var p := _site(L, 7, 1, pale, 30.0, 700, 0.4)
		if p.x >= 0:
			_work(L, &"_quarry", Vector2(p) + Vector2(0.5, 0.5))
	# Drill fields: bores in an exact grid, capped or still drilling, the
	# survey posts that laid them out.
	for n in _n(L, 2.0):
		var p := _site(L, 7, 1, pale, 30.0, 700, 0.4)
		if p.x >= 0:
			_work(L, &"_drill_field", Vector2(p) + Vector2(0.5, 0.5))
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
	for n in _n(L, 2.0):
		var p := _site(L, 4, 1, [], 14.0, 500, 0.45)
		if p.x >= 0:
			_work(L, &"_cistern", Vector2(p) + Vector2(0.5, 0.5))


static func _quarry(L: Lay, at: Vector2, _a: Array) -> bool:
	var rng := L.rng
	var d := L.d
	var nrm := L.nrm
	var half := Vector2(rng.randf_range(7.0, 9.0), rng.randf_range(5.0, 6.5))
	_record(L.c, &"quarry", at, d, half, QUARRY)
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
	return true


static func _drill_field(L: Lay, at: Vector2, _a: Array) -> bool:
	var d := L.d
	var nrm := L.nrm
	_record(L.c, &"drill_field", at, nrm, Vector2(8.0, 6.0), BORES)
	for gy in range(-2, 3):
		for gx in range(-3, 4):
			var q := at + nrm * gx * 2.6 + d * gy * 2.6
			if (gx + gy) % 3 == 0:
				_put(L, PropKind.SURVEY, q, nrm.angle(), -99, 0.0, true)
			else:
				_put(L, PropKind.DRILL_RIG, q, nrm.angle(), -99, 0.2, true)
	return true


static func _cistern(L: Lay, at: Vector2, _a: Array) -> bool:
	var tank := _put_footed(L, PropKind.WATER_TANK, at, L.rng.randf() * TAU, 0.8)
	if tank == null:
		return false
	at = tank.pos
	_record(L.c, &"cistern", at, L.d, Vector2(3.0, 3.0))
	_about(L, PropKind.SHACK, at, 1, 2.8, 4.5)
	_run(L, PropKind.FENCE, at + Vector2(-3.0, 3.0), Vector2.from_angle(L.rng.randf() * TAU), 3, 2.0, -99, 0.3)
	_about(L, PropKind.GRAVE, at, 1, 4.0, 6.0)
	return true


# --- the burning -------------------------------------------------------------------

static func _burning(L: Lay) -> void:
	var c := L.c
	var w := L.w
	var dry: Array = [Ground.ASH, Ground.CLINKER, Ground.GRAVEL, Ground.ROCK, Ground.SCREE, Ground.GRASS, Ground.HEATH]
	# Slag heaps tipped in a line along the bearing, a scorched car by them.
	for n in _n(L, 2.0):
		var p := _site(L, 6, 1, dry, 30.0, 700, 0.4)
		if p.x >= 0:
			_work(L, &"_slag", Vector2(p) + Vector2(0.5, 0.5))
	# Refinery runs: parallel pipelines, collapsed in stretches, vents capped.
	for n in _n(L, 1.5):
		var p := _site(L, 6, 1, dry, 30.0, 700, 0.4)
		if p.x >= 0:
			_work(L, &"_refinery", Vector2(p) + Vector2(0.5, 0.5))
	# The clerks' archive: cabinets in exact rows standing in the ash.
	var archives := 0
	for attempt in 8:
		if archives >= _n(L, 1.0):
			break
		var p := _site(L, 5 if attempt < 4 else 3, 1, dry if attempt < 4 else [], 34.0 if attempt < 4 else 14.0, 600, 0.45)
		if p.x >= 0 and _work(L, &"_archive", Vector2(p) + Vector2(0.5, 0.5)):
			archives += 1
	# The machines bolted caps on the vents of the fumaroles.
	for m: Dictionary in w.landmarks.duplicate():
		if m.kind != &"fumarole":
			continue
		var at: Vector2 = m.pos
		if L.here(floori(at.x), floori(at.y)):
			_work(L, &"_vent_caps", at)
	# A dugout by the heat.
	for n in _n(L, 1.0):
		var p := _site(L, 3, 1, dry, 24.0, 500, 0.45)
		if p.x >= 0:
			_work(L, &"_dugout", Vector2(p) + Vector2(0.5, 0.5))


static func _slag(L: Lay, at: Vector2, _a: Array) -> bool:
	var d := L.d
	var heaps := 0
	# Footed: the burning is terraced, and a heap tipped on a lip stood nowhere,
	# which gave up the whole line on half the sites a region drew.
	for i in L.rng.randi_range(3, 4):
		if _put_footed(L, PropKind.SLAG_HEAP, at + d * (i * 3.6 - 5.0), d.angle(), 1.0, true) != null:
			heaps += 1
	if heaps == 0:
		return false
	_record(L.c, &"slag", at, d, Vector2(7.5, 3.0), SCORCH)
	_about(L, PropKind.VEHICLE, at + L.nrm * 4.0, 1, 0.0, 2.5)
	_about(L, PropKind.DEBRIS, at, 3, 3.0, 6.0)
	_about(L, PropKind.WRECKAGE, at, 1, 3.0, 6.0)
	return true


static func _refinery(L: Lay, at: Vector2, _a: Array) -> bool:
	var d := L.d
	var nrm := L.nrm
	var runs := L.rng.randi_range(2, 3)
	var length := L.rng.randi_range(7, 10)
	for r in runs:
		_run(L, PropKind.PIPE, at - d * length + nrm * (r - (runs - 1) * 0.5) * 1.7, d, length, 2.0, -99, 0.12)
	_record(L.c, &"refinery", at, d, Vector2(length + 1.0, runs * 1.2), SCORCH)
	_about(L, PropKind.VENT_CAP, at + nrm * (runs * 1.2 + 2.0), 2, 0.0, 3.5)
	_about(L, PropKind.DEBRIS, at, 2, 3.0, 7.0)
	return true


static func _archive(L: Lay, at: Vector2, _a: Array) -> bool:
	var d := L.d
	var nrm := L.nrm
	var placed := 0
	for gy in range(-1, 2):
		for gx in range(-1, 2):
			if L.rng.randf() < 0.25:
				continue
			if _put(L, PropKind.ARCHIVE, at + d * gx * 2.4 + nrm * gy * 2.4, d.angle(), -99, 0.4, true) != null:
				placed += 1
	if placed == 0:
		return false
	_record(L.c, &"archive", at, d, Vector2(4.0, 4.0), SCORCH)
	_put(L, PropKind.SIGN, at - d * 4.5, (-d).angle(), -99, 0.2)
	return true


static func _vent_caps(L: Lay, at: Vector2, _a: Array) -> bool:
	var placed := false
	for sgn: float in [-1.0, 1.0]:
		if _put(L, PropKind.VENT_CAP, at + L.d * sgn * 2.2, L.d.angle(), -99, 0.4, true) != null:
			placed = true
	return placed


static func _dugout(L: Lay, at: Vector2, _a: Array) -> bool:
	var shack := _put_footed(L, PropKind.SHACK, at, L.rng.randf() * TAU, 1.0)
	if shack == null:
		return false
	_note_lit_shack(L, shack)
	_record(L.c, &"dugout", shack.pos, L.d, Vector2(2.0, 2.0))
	return true


# --- people ------------------------------------------------------------------------

## Round every village: its graves in a row by a memorial, a shack or two at
## the edge with stolen light in some, fences, a barricade on the way in, debris.
static func _villages(L: Lay) -> void:
	var w := L.w
	for vi: int in _order(w.villages.size()):
		_work(L, &"_village_edge", w.villages[vi].pos as Vector2, [vi])
	# Barricades on the ways in: beside each road where it nears a village.
	# Roads into one village share their last stretch, so each way in keeps off
	# the stations of every way in that OUTRANKS it (by its own hash): the plan's
	# roads decide who yields, not which way in happened to be laid first.
	var ends: Array = []
	for ri in w.roads.size():
		for end in 2:
			var road := w.roads[ri]
			if road.size() > 0:
				ends.append([ri, end, _way_in_stations(road, end), Rng.hash01(L.c.s, ri, end, 0x3059)])
	for ends_i: int in _order(ends.size()):
		var e: Array = ends[ends_i]
		var road := w.roads[int(e[0])]
		var held: Array[Vector2] = []
		for o: Array in ends:
			if float(o[3]) < float(e[3]):
				for q: Vector2 in o[2]:
					for mine: Vector2 in e[2]:
						if q.distance_squared_to(mine) < 16.0:
							held.append(q)
		_work(L, &"_way_in", road[0] if int(e[1]) == 0 else road[road.size() - 1], [e[0], e[1], held])


## Where a way in may put its barricade: road `road`'s stations a way in from
## end `end` (0 its first point, 1 its last).
static func _way_in_stations(road: PackedVector2Array, end: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k: int in [12, 15, 18, 22]:
		var j := k if end == 0 else road.size() - 1 - k
		if j >= 2 and j < road.size() - 2:
			out.append(road[j])
	return out


## Village `a[0]`'s edge: its graves, its shacks, its garden fences, its debris.
static func _village_edge(L: Lay, vp: Vector2, _a: Array) -> bool:
	var c := L.c
	var rng := L.rng
	var n0 := L.w.props.size()
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
	var want := rng.randi_range(1, 2)
	for attempt in 40:
		if shacks >= want:
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
	return L.w.props.size() > n0


## A barricade beside road `a[0]` where its end `a[1]` nears a village, off
## the stations of the ways in that outrank it (`a[2]`).
static func _way_in(L: Lay, _at: Vector2, a: Array) -> bool:
	var road := L.w.roads[int(a[0])]
	var end: int = a[1]
	var held: Array = a[2]
	for k: int in [12, 15, 18, 22]:
		var j := k if end == 0 else road.size() - 1 - k
		if j < 2 or j >= road.size() - 2:
			continue
		var q := road[j]
		var near := false
		for h: Vector2 in held:
			near = near or h.distance_squared_to(q) < 16.0
		if near:
			continue
		var along := (road[j + 1] - road[j - 1]).normalized()
		var across := Vector2(-along.y, along.x) * (1.0 if L.rng.randf() < 0.5 else -1.0)
		if _put(L, PropKind.BARRICADE, q + across * 1.8, along.angle(), -99, 0.4) != null or _put(L, PropKind.BARRICADE, q - across * 1.8, along.angle(), -99, 0.4) != null:
			return true
	return false


## Note a shack with stolen machine light wired in (the lit model: PropModels'
## variant 1 of 2, by the hash the view bakes with). One of them is recorded as
## the landmark "stolen_light" once every work is laid (`_stolen_light`), so it
## can be walked to and seen after dusk.
static func _note_lit_shack(L: Lay, shack: WorldProp) -> void:
	# The shack is lit when the model it is DEALT is its lit one: two models, the
	# second wired (`tests/core/test_world_gen_works.gd` holds the recorded shack to
	# variant 1). Asked of the same position hash `PropModels.variant_of` deals
	# from, so renumbering ids no longer moves the stolen light.
	if absi(WorldProp.deal_hash(L.c.s, shack.kind, shack.pos)) % 2 != 1:
		return
	if L.writes:
		L.lit.append(shack.pos)


## THE STOLEN LIGHT IS THE WORLD'S ONE, AND IT IS NOT A RACE. It went to the
## first lit shack laid, so where it stood hung on every region laid before.
## The regions are ranked by a hash of each one's own key; the light is the lowest-hashed
## lit shack of the first region in that rank that lit one. So it hangs on the
## first region or two of the rank and on nothing laid anywhere else.
static func _stolen_light(L: Lay) -> void:
	var best := {}
	for p: Vector2 in L.lit:
		var r := L.w.region_at(floori(p.x), floori(p.y))
		var h := Rng.hash01(L.c.s, roundi(p.x * 256.0), roundi(p.y * 256.0), 0x5701)
		if not best.has(r) or h < float((best[r] as Array)[0]):
			best[r] = [h, p]
	var first := -2
	var rank := 2.0
	for r: int in best:
		var k := Rng.hash01(L.c.s, GenCountries.region_key(L.w, r), 0, 0x5702)
		if k < rank:
			rank = k
			first = r
	if first != -2:
		_record(L.c, &"stolen_light", (best[first] as Array)[1] as Vector2, Vector2.RIGHT, Vector2(1.5, 1.5))


## Warnings nobody reads, beside the roads, one every so often away from the
## villages.
static func _roads(L: Lay) -> void:
	var w := L.w
	for ri: int in _order(w.roads.size()):
		var road := w.roads[ri]
		if road.size() < 41:
			continue
		# Where along it the signs stand is the road's own: a stream keyed on
		# its first point, so a road's signs do not hang on the roads before it.
		var steps := Rng.make(L.c.s, Rng.hash_ints(0x3058, floori(road[0].x), floori(road[0].y), road.size()))
		var j := 20
		while j < road.size() - 20:
			if not GenScatter._near_village(w, road[j], 16.0):
				_work(L, &"_road_sign", road[j], [ri, j])
			j += steps.randi_range(34, 52)


## A warning beside road `a[0]` at its point `a[1]`, on whichever side takes it.
static func _road_sign(L: Lay, q: Vector2, a: Array) -> bool:
	var road := L.w.roads[int(a[0])]
	var j: int = a[1]
	var along := (road[mini(j + 2, road.size() - 1)] - road[j - 2]).normalized()
	var across := Vector2(-along.y, along.x)
	for sgn: float in [1.0, -1.0]:
		if _put(L, PropKind.SIGN, q + across * sgn * 1.7, (across * sgn).angle(), -99, 0.2) != null:
			return true
	return false


## What is left where things ended: debris round the tips, ruins and wrecks,
## a grave or a sign at some.
static func _remains(L: Lay) -> void:
	var w := L.w
	var count := w.landmarks.size()
	for li: int in _order(count):
		var m: Dictionary = w.landmarks[li]
		var k: StringName = m.kind
		if k == &"tip" or k == &"wreck" or k == &"ruin":
			_work(L, &"_remains_at", m.pos as Vector2, [k])


static func _remains_at(L: Lay, at: Vector2, a: Array) -> bool:
	var rng := L.rng
	var n0 := L.w.props.size()
	if a[0] == &"ruin":
		_about(L, PropKind.DEBRIS, at, 2, 2.0, 5.0)
		if rng.randf() < 0.6:
			_about(L, PropKind.GRAVE, at, 2, 3.5, 6.0)
		if rng.randf() < 0.4:
			_about(L, PropKind.VEHICLE, at, 1, 4.0, 7.0)
	else:
		_about(L, PropKind.DEBRIS, at, 3, 3.0, 6.5)
		_about(L, PropKind.WRECKAGE, at, 1, 3.0, 6.5)
		if rng.randf() < 0.5:
			_run(L, PropKind.FENCE, at + Vector2(-5.0, 4.0), Vector2.from_angle(rng.randf() * TAU), 3, 2.0, -99, 0.35)
	return L.w.props.size() > n0


## The first frame of a game shows what was lost: in view of the spawn, past
## its first steps and the village square it wakes by, a few of its own
## landscape's compositions (graves round a memorial first).
static func _spawn_view(L: Lay) -> void:
	_work(L, &"_spawn_compositions", L.w.spawn)


static func _spawn_compositions(L: Lay, sp: Vector2, _a: Array) -> bool:
	var w := L.w
	var face := Vector2.from_angle(w.spawn_facing)
	var table: Array = evidence(L.type_at(floori(sp.x), floori(sp.y))).vignettes
	var rng := L.rng
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
	return placed > 0


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
	# SPLIT: `works.vignettes` is ~1.1 s and is the dearest thing left in props.
	# Marking what is already known to be two different jobs -- stamping every
	# landmark and village into a busy grid, then walking the world's cells --
	# because a single number names no culprit, and `evidence()` was already
	# tried and was not it (memoised, 1155 vs 1098 ms, reverted).
	c.mark(&"vig.busy")
	var cell := VIGNETTE_CELL
	var cells := range(cell, c.size - cell, cell)
	for cy: int in _order(cells.size()).map(func(k: int) -> int: return cells[k]):
		for cx: int in _order(cells.size()).map(func(k: int) -> int: return cells[k]):
			# The cell's rolls are its own (hashed from where it is), so a cell
			# decides the same whichever cells were decided before it.
			if Rng.hash01(c.s, cx, cy, 0x716, 3) > VIGNETTE_SHARE:
				continue
			var pick := Rng.hash01(c.s, cx, cy, 0x716, 4)
			var turn := Rng.hash01(c.s, cx, cy, 0x716, 5)
			# A cell whose first spot is wet or taken tries a second.
			for k in 2:
				var p := Vector2i(cx + floori(Rng.hash01(c.s, cx, cy, 0x716, 10 + k * 2) * cell), cy + floori(Rng.hash01(c.s, cx, cy, 0x716, 11 + k * 2) * cell))
				var i := p.y * c.size + p.x
				if c.land[i] == 0 or busy[i] != 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or Ground.is_water(w.ground[i]):
					continue
				var table: Array = evidence(L.type_at(p.x, p.y)).vignettes
				if _work(L, &"_vignette", Vector2(p) + Vector2(0.5, 0.5), [_pick(table, pick), turn]):
					break


## One cell's composition `a[0]`, varied by `a[1]`.
static func _vignette(L: Lay, at: Vector2, a: Array) -> bool:
	var turn: float = a[1]
	return _compose(L, a[0], at, turn, turn * TAU) > 0


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
			_clear_rect(L, at + d * (k - 1) + L.nrm, d, Vector2(k + 0.4, 1.9))
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
	var secs := survey_sections(c.s, c.size)
	for si: int in _order(secs.size()):
		var sec: Array = secs[si]
		var a: Vector2 = sec[0]
		var b: Vector2 = sec[1]
		var mid := (a + b) * 0.5
		if mid.x < 0.0 or mid.y < 0.0 or mid.x >= c.size or mid.y >= c.size:
			continue
		_work(L, &"_survey_section", a, [b])


## One surviving stretch of the survey from `at` to `a[0]`, dressed by the
## landscape at its middle.
static func _survey_section(L: Lay, a: Vector2, args: Array) -> bool:
	var c := L.c
	var rng := L.rng
	var n0 := L.w.props.size()
	var b: Vector2 = args[0]
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var mid := (a + b) * 0.5
	var roll := rng.randf()
	var dressing: Array = evidence(L.type_at(floori(mid.x), floori(mid.y))).survey
	# The lane stays open wherever it runs through a landscape that cuts one.
	var cut := false
	var t := 0.0
	while t <= SURVEY_SECTION:
		var q := a + dir * t
		if q.x >= 1.0 and q.y >= 1.0 and q.x < c.size - 1 and q.y < c.size - 1 and _survey_has(L, floori(q.x), floori(q.y), &"lane"):
			_clear_rect(L, q, dir, Vector2(0.5, 1.3))
			cut = true
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
		match StringName(e[1]):
			&"snow_fence_line":
				_run(L, PropKind.FENCE, a + dir * (4.0 + roll * 8.0) + side * 1.2, dir, 4, 2.0, -99, 0.15)
			&"pipe_line":
				_run(L, PropKind.PIPE, a + dir * (4.0 + roll * 10.0) + side * 1.0, dir, 3, 2.0, -99, 0.25)
			&"drill_beside":
				_put(L, PropKind.DRILL_RIG, mid + side * 1.4, dir.angle(), -99, 0.3, true)
			&"sign_beside":
				_put(L, PropKind.SIGN, mid + side * 1.5, dir.angle() + PI * 0.5, -99, 0.2)
	return cut or L.w.props.size() > n0


## The landscape at (x, y) dresses the survey with `dressing`.
static func _survey_has(L: Lay, x: int, y: int, dressing: StringName) -> bool:
	for e: Array in evidence(L.type_at(x, y)).survey:
		if StringName(e[1]) == dressing:
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
