extends TestCase
## EVERY LANDSCAPE IS BUILT TO ONE RULE, ASKED OF A GROWN WORLD (docs/ROADMAP.md,
## "The rule every landscape is built to"). A landscape is four layers — the plan,
## the land, the people, the player — and each row below asks one thing a layer
## needs of the WORLD the seed grew, never of the file that declares it: a prop
## kind counts once one is placed, a depot once `Works.sites` finds it, a keeper
## once `Sentinels.states` puts one out. So a declaration that never reaches the
## world is a red here, not a quiet gap.
##
## **THE BASELINE ONLY SHRINKS.** Most landscapes fail most rows today, and that is
## the point of L2 and L3, not of this file. `depth_standing.txt` lists every
## `land row` that fails on the tree it was written against. This test fails on a
## failure that is NOT listed (something got worse, or a new landscape arrived
## thin) and on a listed one that now PASSES (take it out: the list is a record of
## debt, and debt paid and still listed hides the next regression behind it).
##
## **EVERY SEED WHERE THE LAND GROWS.** A row holds only if it holds on each of
## the cached worlds the landscape has a region on, because a guarantee that holds
## on one seed of three is not one; the verdict prints how many seeds it was asked
## on, so a pass on one seed reads as the thin evidence it is. A landscape grown
## on none of them fails `grown` and nothing else is asked of it.
##
## DENSITY IS REPORTED, NOT JUDGED, in L1 (cb, 2026-09-22): a floor stated
## against a neighbour moves every time the neighbour is built, so a baseline on it
## would churn with every L2 landscape. The medians print; the floor comes after
## the first L2 landscape shows what "rich" measures.

const Worlds := preload("res://tests/core/test_world_gen.gd")
const STANDING := "res://tests/biome/depth_standing.txt"

## One play frame, in tiles (docs/ROADMAP.md: 26.7 x 17.9, about 478).
const FRAME := Vector2(26.7, 17.9)
## The size rule: a landscape's main region holds at least this many frames.
const FRAMES_WANTED := 40
## "Of its own": a kind (prop or site) this landscape declares with at most one
## partner (cb: scrap trees shared by the scrapwood and the middens are one idea;
## three would let a family pass for everyone in it).
const OWN_AT_MOST := 2
## A landmark kind of its own stands in this land and at most two others.
const LANDMARK_AT_MOST := 3
## Frames sampled per landscape per seed for the density report.
const DENSITY_FRAMES := 20

const ROWS: Array[StringName] = [
	&"grown",
	&"plan.depot", &"plan.keeper", &"plan.machine", &"plan.work_props",
	&"land.own_props", &"land.site", &"land.landmark", &"land.frames",
	&"people.built", &"people.local", &"people.dressing",
	&"player.hazards", &"player.only_in", &"player.signature",
]


func test_every_landscape_is_as_deep_as_it_is_listed() -> void:
	GearEconomy.declare(true)
	var worlds: Array[WorldData] = []
	for s in Worlds.WORLD_SEEDS:
		worlds.append(Worlds.world(s))
	var failing: Dictionary = {}
	var lines: PackedStringArray = []
	for d: BiomeDef in BiomeRegistry.land_in(worlds[0].realm):
		var verdict := _judge(d, worlds)
		var shown: PackedStringArray = []
		for row: StringName in ROWS:
			if not verdict.has(row):
				continue
			var v: Dictionary = verdict[row]
			shown.append("%s %s%s" % [row, "ok" if v.ok else "NO", "" if v.seeds == 0 else " %d/%d" % [v.seeds, worlds.size()]])
			if not v.ok:
				failing["%s %s" % [d.id, row]] = true
		lines.append("  %-18s %s" % [d.id, ", ".join(shown)])
	for l in lines:
		print(l)
	_print_density(worlds)
	var standing := _standing()
	var worse: PackedStringArray = []
	var better: PackedStringArray = []
	for k: String in failing:
		if not standing.has(k):
			worse.append(k)
	for k: String in standing:
		if not failing.has(k):
			better.append(k)
	worse.sort()
	better.sort()
	eq(worse.size(), 0, "new depth failures, not in depth_standing.txt: %s" % ", ".join(worse))
	eq(better.size(), 0, "now passing, take them OUT of depth_standing.txt: %s" % ", ".join(better))


## The listed debt, as `land row` keys. A line naming a land or a row this test
## does not know is itself a failure: a stale entry reads as debt forever.
func _standing() -> Dictionary:
	var out := {}
	var f := FileAccess.open(STANDING, FileAccess.READ)
	check(f != null, "depth_standing.txt exists")
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		check(parts.size() == 2 and BiomeRegistry.get_def(StringName(parts[0])) != null and ROWS.has(StringName(parts[1])),
			"depth_standing.txt names a real land and row: '%s'" % line)
		out[line] = true
	return out


## Every row for one landscape: {row: {ok, seeds}}. `seeds` is how many worlds
## the row was asked on, 0 for a row that asks the registry rather than a world.
func _judge(d: BiomeDef, worlds: Array[WorldData]) -> Dictionary:
	var out := {}
	var grown: Array[WorldData] = []
	for w in worlds:
		if _main_region(w, d.id).size() > 0:
			grown.append(w)
	out[&"grown"] = {"ok": not grown.is_empty(), "seeds": grown.size()}
	if grown.is_empty():
		return out
	var own := _own_kinds(d)
	var ask := func(row: StringName, test: Callable) -> void:
		var ok := true
		for w in grown:
			if not bool(test.call(w)):
				ok = false
				break
		out[row] = {"ok": ok, "seeds": grown.size()}
	# --- THE PLAN ---
	ask.call(&"plan.depot", func(w: WorldData) -> bool:
		for site: WorksSite in Works.sites(w):
			if site.land == d.id:
				return true
		return false)
	ask.call(&"plan.keeper", func(w: WorldData) -> bool:
		for st: SentinelState in Sentinels.states(w):
			if st.land == d.id:
				return true
		return false)
	# A roster kind this land alone puts out. The spawner runs in a game, so this
	# asks the economy's walker, which reads the same rolls the spawner does.
	var only_here := false
	for k: StringName in Sources.kinds_in(d.id):
		var lands := Sources.lands_of_kind(k)
		if lands.size() == 1 and lands[0] == d.id:
			only_here = true
	out[&"plan.machine"] = {"ok": only_here, "seeds": 0}
	ask.call(&"plan.work_props", func(w: WorldData) -> bool:
		return _worked(w, d))
	# --- THE LAND ---
	ask.call(&"land.own_props", func(w: WorldData) -> bool:
		return _placed_own(w, d, own).size() >= 3)
	ask.call(&"land.site", func(w: WorldData) -> bool:
		return _own_site(w, d))
	ask.call(&"land.landmark", func(w: WorldData) -> bool:
		for ls: LandmarkSite in Landmarks.sites(w):
			if ls.land == d.id and Landmarks.lands_of(ls.kind).size() <= LANDMARK_AT_MOST:
				return true
		return false)
	ask.call(&"land.frames", func(w: WorldData) -> bool:
		return int(_main_region(w, d.id).get("tiles", 0)) >= roundi(FRAMES_WANTED * FRAME.x * FRAME.y))
	# --- THE PEOPLE ---
	# A land that declares nobody lives in it keeps its declaration for BUILDINGS
	# only (cb): it still has a face, a camp's ice-fisher or a glass-picker.
	if d.villages > 0:
		var stock := BiomeForms.of(d.index).stock
		out[&"people.built"] = {"ok": stock != BiomeForms.PLAIN and stock != BiomeForms.RAISED, "seeds": 0}
	ask.call(&"people.local", func(w: WorldData) -> bool:
		return not (StoryPlan.cast(w).get(StringName("local_%s" % d.id), {}) as Dictionary).is_empty())
	out[&"people.dressing"] = {"ok": d.dressing != null, "seeds": 0}
	# --- THE PLAYER ---
	out[&"player.hazards"] = {"ok": not d.hazards.is_empty(), "seeds": 0}
	out[&"player.only_in"] = {"ok": _only_here_reachable(d.id), "seeds": 0}
	ask.call(&"player.signature", func(w: WorldData) -> bool:
		var placed := _placed_own(w, d, own)
		if placed.is_empty():
			return false
		for k: int in placed:
			if not Takes.table().has(k) and PropKind.SOLID[k] <= 0.0:
				return false
		return true)
	return out


## The largest region of this landscape on this world, or {} when it has none.
## `WorldData.regions` is biggest first, so the first match is the main one.
static func _main_region(w: WorldData, land: StringName) -> Dictionary:
	for r: Dictionary in w.regions:
		if StringName(str(r.get("type", &""))) == land:
			return r
	return {}


## Kinds this land declares (props or ore) that at most one other land declares.
static func _own_kinds(d: BiomeDef) -> Dictionary:
	var count := {}
	for other: BiomeDef in BiomeRegistry.land():
		var seen := {}
		for k: int in other.props:
			seen[k] = true
		for row: Array in other.ore:
			seen[int(row[0])] = true
		for k: int in seen:
			count[k] = int(count.get(k, 0)) + 1
	var out := {}
	for k: int in d.props:
		if int(count.get(k, 0)) <= OWN_AT_MOST:
			out[k] = true
	for row: Array in d.ore:
		if int(count.get(int(row[0]), 0)) <= OWN_AT_MOST:
			out[int(row[0])] = true
	return out


## One pass over a world's props, kept per world object (never per seed: a key on
## the seed would hand a regrown world the first one's answer). `core` is
## country -> {kind: true} for props standing at blend 0; `evidence` buckets
## works-evidence props (kind >= FENCE) by EVIDENCE_CELL tiles.
const EVIDENCE_CELL := 16
static var _index_of: WorldData = null
static var _index: Dictionary = {}


static func _indexed(w: WorldData) -> Dictionary:
	if w == _index_of:
		return _index
	var core := {}
	var evidence := {}
	for p in w.each_prop():
		var i := floori(p.pos.y) * w.size + floori(p.pos.x)
		if w.blend[i] == 0.0:
			var c: int = w.country[i]
			if not core.has(c):
				core[c] = {}
			(core[c] as Dictionary)[p.kind] = true
		if p.kind >= PropKind.FENCE:
			var cell := Vector2i(floori(p.pos.x) / EVIDENCE_CELL, floori(p.pos.y) / EVIDENCE_CELL)
			if not evidence.has(cell):
				evidence[cell] = []
			(evidence[cell] as Array).append(p.pos)
	_index_of = w
	_index = {"core": core, "evidence": evidence}
	return _index


## Which of `own` stand in this land's CORE (blend 0) on this world.
static func _placed_own(w: WorldData, d: BiomeDef, own: Dictionary) -> Dictionary:
	var here: Dictionary = (_indexed(w).core as Dictionary).get(d.index, {})
	var out := {}
	for k: int in own:
		if here.has(k):
			out[k] = true
	return out


## A works record with a mark in this land, and evidence standing at it.
static func _worked(w: WorldData, d: BiomeDef) -> bool:
	var evidence: Dictionary = _indexed(w).evidence
	for m: Dictionary in w.landmarks:
		if not m.has("mark") or int(m.get("country", -1)) != d.index:
			continue
		var at: Vector2 = m.pos
		var reach := maxf((m.get("half", Vector2(4, 4)) as Vector2).length(), 4.0) + 2.0
		var lo := Vector2i(floori(at.x - reach) / EVIDENCE_CELL, floori(at.y - reach) / EVIDENCE_CELL)
		var hi := Vector2i(floori(at.x + reach) / EVIDENCE_CELL, floori(at.y + reach) / EVIDENCE_CELL)
		for cy in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				for q: Vector2 in evidence.get(Vector2i(cx, cy), []):
					if q.distance_squared_to(at) < reach * reach:
						return true
	return false


## A place of a kind from `SiteKinds` that this land claims in `BiomeDef.sites`
## (by its name, or the plural a count is written under) and at most one other
## land claims, standing in one of this land's regions.
static func _own_site(w: WorldData, d: BiomeDef) -> bool:
	for kind: StringName in SiteKinds.ROWS:
		if not _claims(d, kind):
			continue
		var claimed := 0
		for other: BiomeDef in BiomeRegistry.land():
			if _claims(other, kind):
				claimed += 1
		if claimed > OWN_AT_MOST:
			continue
		for m: Dictionary in w.landmarks:
			# `site`: a place laid for a claim, not a works record of the same name
			# (GenWorks marks the plan's quarry cut `&"quarry"` too).
			if bool(m.get("site", false)) and StringName(str(m.kind)) == kind and int(m.get("country", -1)) == d.index:
				return true
	return false


static func _claims(d: BiomeDef, kind: StringName) -> bool:
	var v: Variant = d.sites.get(String(kind), d.sites.get(String(kind) + "s", null))
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) > 0.0
	return v != null


## A drop only this land gives, that the economy can walk back to the world.
static func _only_here_reachable(land: StringName) -> bool:
	for source: Variant in Drops.sources():
		for row: Dictionary in Drops.table(StringName(source)):
			var only: Array = row.get("only_in", [])
			if only.size() == 1 and StringName(only[0]) == land and not Sources.path_to(StringName(row.item)).is_empty():
				return true
	return false


## Per landscape, over DENSITY_FRAMES frames of its core on each seed: the median
## distinct kinds, props and bare-plain share. Printed only (see the header).
## One pass buckets the props by tile, so each frame is a window read.
func _print_density(worlds: Array[WorldData]) -> void:
	var t := Time.get_ticks_msec()
	var per := {}
	for w in worlds:
		var at_tile := {}
		for p in w.each_prop():
			var i := floori(p.pos.y) * w.size + floori(p.pos.x)
			if at_tile.has(i):
				(at_tile[i] as Array).append(p.kind)
			else:
				at_tile[i] = [p.kind]
		var core := {}
		for i in w.country.size():
			if w.blend[i] == 0.0 and w.level[i] > 0:
				var c: int = w.country[i]
				if not core.has(c):
					core[c] = []
				(core[c] as Array).append(i)
		var rng := Rng.make(w.seed_value, 7331)
		for c: int in core:
			var tiles: Array = core[c]
			var d := BiomeRegistry.by_index(c)
			for n in DENSITY_FRAMES:
				var mid: int = tiles[rng.randi_range(0, tiles.size() - 1)]
				var cx := mid % w.size
				var cy := mid / w.size
				var kinds := {}
				var props := 0
				var bare := 0
				var area := 0
				for y in range(cy - int(FRAME.y / 2), cy + int(FRAME.y / 2)):
					for x in range(cx - int(FRAME.x / 2), cx + int(FRAME.x / 2)):
						if not w.in_bounds(x, y):
							continue
						var i := y * w.size + x
						area += 1
						var here: Array = at_tile.get(i, [])
						props += here.size()
						for k: int in here:
							kinds[k] = true
						if here.is_empty() and w.ground[i] == d.plain_ground:
							bare += 1
				if not per.has(d.id):
					per[d.id] = [[], [], []]
				(per[d.id][0] as Array).append(kinds.size())
				(per[d.id][1] as Array).append(props)
				(per[d.id][2] as Array).append(float(bare) / maxf(area, 1))
	var ids := per.keys()
	ids.sort()
	for id: StringName in ids:
		print("  density %-18s kinds %2d  props %4d  bare plain %.2f" % [id,
			_median(per[id][0]), _median(per[id][1]), _median(per[id][2])])
	print("  density sampled in %d ms" % (Time.get_ticks_msec() - t))


static func _median(a: Array) -> Variant:
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]
