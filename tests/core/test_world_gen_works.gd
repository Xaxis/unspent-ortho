extends TestCase
## The dystopian evidence of every landscape (GenWorks): each landscape holds
## its own works and remains on every seed, the machines' works lie ruled on
## the survey bearing, the hand's things keep off villages, roads and water,
## and the whole of it stays inside its budget. Uses the cached default worlds.

const Worlds := preload("res://tests/core/test_world_gen.gd")

## The evidence kinds, from FENCE to the end of PropKind, less the kinds that
## are a landscape's own nature (PropKind.WILD).
const FIRST := PropKind.FENCE


static func is_evidence(kind: int) -> bool:
	return kind >= FIRST and not PropKind.WILD.has(kind)

## Works each landscape must hold on every seed: kind -> its country.
const HOME := {
	PropKind.HULL: Country.COAST, PropKind.INTAKE: Country.COAST, PropKind.SEA_WALL: Country.COAST, PropKind.TIDE_GAUGE: Country.COAST,
	PropKind.PUMP_HOUSE: Country.MOSS,
	PropKind.RELAY: Country.PINEWOOD, PropKind.FIRE_TOWER: Country.PINEWOOD,
	PropKind.CHECKPOINT: Country.SNOWFIELD, PropKind.STACK: Country.SNOWFIELD,
	PropKind.WATER_TANK: Country.BONELANDS, PropKind.CONVEYOR: Country.BONELANDS,
	PropKind.SLAG_HEAP: Country.BURNING, PropKind.ARCHIVE: Country.BURNING,
}


## Walking-scale evidence every landscape holds, per 1000 dry tiles.
const EVIDENCE_PER_1000 := 25.0


func test_every_landscape_holds_its_own_works() -> void:
	# A LANDSCAPE'S OWN WORKS ARE ASSERTED ACROSS THE SAMPLE, NOT ON EVERY ISLAND
	# (owner, 2026-09-18). Some of these are rare — six water tanks in six worlds —
	# so demanding one on EVERY seed asks the rarest thing in the game to land in
	# one landscape on three named islands. Adding a landscape shrinks every
	# landscape's share, and the first thing to fall off is whatever was rarest:
	# "no water tank in the bonelands on seed 1" was that, and the bonelands had not
	# changed. Measured over six seeds, every kind here appears in its home on every
	# one of them before the eleventh landscape, and on at least two thirds after —
	# so a majority of the sample is the honest bar, and the seeds that missed are
	# named so a real regression (none of them) is still loud.
	var seen_home := {}
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var at_home := {}
		var counts := PackedInt32Array()
		counts.resize(PropKind.COUNT)
		for p in w.props:
			counts[p.kind] += 1
			if HOME.has(p.kind) and w.country_at(floori(p.pos.x), floori(p.pos.y)) == int(HOME[p.kind]):
				at_home[p.kind] = true
		for kind: int in HOME:
			if at_home.has(kind):
				var got: Array = seen_home.get(kind, [])
				got.append(s)
				seen_home[kind] = got
		for kind in range(FIRST, PropKind.COUNT):
			gt(counts[kind], 0, "seed %d %s placed" % [s, PropKind.NAMES[kind]])
		# Evidence at walking scale in every landscape, not only at the works.
		var land := PackedFloat32Array()
		land.resize(BiomeRegistry.count())
		for i in w.level.size():
			if w.level[i] > 0:
				land[w.country[i]] += 1.0
		var evidence := PackedFloat32Array()
		evidence.resize(BiomeRegistry.count())
		for p in w.props:
			if is_evidence(p.kind):
				evidence[w.country_at(floori(p.pos.x), floori(p.pos.y))] += 1.0
		for cc: int in BiomeRegistry.land_indices_in(w.realm):
			gt(evidence[cc] * 1000.0 / maxf(land[cc], 1.0), EVIDENCE_PER_1000, "seed %d evidence per 1000 tiles of %s" % [s, BiomeRegistry.name_of(cc)])
	var most := (Worlds.WORLD_SEEDS.size() + 1) / 2
	for kind: int in HOME:
		var on: Array = seen_home.get(kind, [])
		check(on.size() >= most, "%s is the %s's own and stands in it on %d of %d islands %s"
			% [PropKind.NAMES[kind], BiomeRegistry.name_of(int(HOME[kind])), on.size(), Worlds.WORLD_SEEDS.size(), on])


func test_the_snowfield_checkpoints_stand_at_a_road() -> void:
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var found := 0
		for p in w.props:
			if p.kind != PropKind.CHECKPOINT:
				continue
			found += 1
			# Distance from the booth to the nearest road tile's square.
			var best := 99.0
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var x := floori(p.pos.x) + dx
					var y := floori(p.pos.y) + dy
					if w.in_bounds(x, y) and w.ground[y * w.size + x] == Ground.ROAD:
						var q := Vector2(clampf(p.pos.x, x, x + 1.0), clampf(p.pos.y, y, y + 1.0))
						best = minf(best, q.distance_to(p.pos))
			if best > 90.0 and not _road_within(w, p.pos, 40):
				# A landscape no road reaches still gets its gate: it stands on
				# the open field, checking a way nobody drives any more.
				continue
			lt(best, 2.01, "seed %d: the checkpoint at %s stands within 2 tiles of a road" % [s, p.pos])
			# The gate's boom (+Z of the model) reaches over the road.
			var over := p.pos + Vector2.from_angle(p.rot + PI * 0.5) * 2.4
			var on_road := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if w.ground_at(floori(over.x) + dx, floori(over.y) + dy) == Ground.ROAD:
						on_road = true
			check(on_road, "seed %d: the checkpoint's boom lies across the road" % s)
		gt(found, 0, "seed %d has a checkpoint" % s)


## A road in the same landscape as p, within r tiles. A road through the next
## country over is not this landscape's road.
static func _road_within(w: WorldData, p: Vector2, r: int) -> bool:
	var mine := w.country_at(floori(p.x), floori(p.y))
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if not w.in_bounds(x, y):
				continue
			var i := y * w.size + x
			if w.ground[i] == Ground.ROAD and (w.country[i] == mine or w.country2[i] == mine):
				return true
	return false


func test_trawlers_lie_on_the_beach() -> void:
	var hulls := 0
	var beached := 0
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		for p in w.props:
			if p.kind != PropKind.HULL:
				continue
			hulls += 1
			var g := w.ground_at(floori(p.pos.x), floori(p.pos.y))
			if g == Ground.SAND or g == Ground.SHINGLE:
				beached += 1
	gt(hulls, 0, "hulls placed")
	gt(float(beached) / maxf(hulls, 1), 0.75, "hulls on sand or shingle (%d of %d)" % [beached, hulls])


func test_evidence_is_keyed_by_landscape_type() -> void:
	# Every landscape type the registry knows either has its own row or falls to
	# the generic set, and every row names works that exist.
	for def in BiomeRegistry.all():
		var row := GenWorks.evidence(def.id)
		check(row.has("works") and row.has("vignettes") and row.has("survey"), "%s has a whole row" % def.id)
		var fn: StringName = row.works
		if fn != &"":
			var host: Object = row.get("host", GenWorks)
			check(Callable(host, fn).is_valid(), "%s works %s exist on its host" % [def.id, fn])
	for id: StringName in GenWorks.EVIDENCE:
		check(BiomeRegistry.get_def(id) != null, "the row %s is a landscape type" % id)
	# A type nobody registered gets the generic set, and a registered row is used.
	eq(GenWorks.evidence(&"no_such_land").vignettes, GenWorks.GENERIC.vignettes, "an unknown type gets the generic remains")
	GenWorks.register(&"test_type", {"vignettes": [[1, &"grave_cluster"]]})
	eq(GenWorks.evidence(&"test_type").vignettes, [[1, &"grave_cluster"]], "a registered row is read")
	eq(GenWorks.evidence(&"test_type").works, &"", "and keeps the generic keys it left out")
	GenWorks._registered.erase(&"test_type")


func test_places_worth_walking_to_are_recorded() -> void:
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var lit := GenPlaces.find(w, "stolen_light")
		check(lit.x >= 0.0, "seed %d: a shack with stolen light is recorded" % s)
		for p in w.props:
			if p.kind == PropKind.SHACK and p.pos.distance_to(lit) < 3.0:
				eq(PropModels.variant_of(p, w.seed_value), 1, "seed %d: the recorded shack is the lit one" % s)
				break


func test_the_first_frame_shows_what_was_lost() -> void:
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var n := 0
		for p in w.props:
			if p.kind >= FIRST and absf(p.pos.x - w.spawn.x) < 16.0 and absf(p.pos.y - w.spawn.y) < 12.0:
				n += 1
		gt(n, 10, "seed %d: evidence round the spawn" % s)


## A road people LAID stays clear. Not every tile painted `Ground.ROAD`: a
## landscape may pave its own streets, and the Slums does — its lanes are ROAD
## so the map draws them, so nothing is sited in one, and so a foot on one
## sounds like a foot on tarmac. A barricade across a city lane, a burnt-out
## vehicle, a sign down in the gutter: that is the place, not a fault in it.
##
## `GenWorks` and `GenScatter` have always asked the right question —
## `c.road[i] != 0`, the mask the access stage laid — and this test asked a
## proxy for it that was exact until a landscape started paving. `WorldData.road`
## is now that same mask, so both ask one question again. Measured on seed 1
## with the Slums muted, ROAD ground is 2955 tiles and every one of them is a
## laid road; with the Slums in it is 5853, of which 2786 are the city's lanes.
func test_evidence_keeps_off_roads_water_and_village_squares() -> void:
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var bad := {}
		# THE ONE PLACE THAT STANDS IN THE SEA ON PURPOSE. This rule is about the
		# machines' SCATTERED works — a platform in the water is a placement bug —
		# and the threshold site is not scattered: it is one named place, laid last
		# and deliberately out in the water off the beach the player washes up on
		# (`GenScatter._black_site`, docs/STORY.md). Named here by WHERE IT STANDS
		# rather than by its kinds, because `ARCHIVE` and `CONSOLE` stand elsewhere
		# too and exempting the kinds would blind the rule to the bug it exists for.
		var threshold := BlackSite.site(w)
		for p in w.props:
			if not is_evidence(p.kind):
				continue
			if threshold != Vector2.INF and p.pos.distance_to(threshold) < 6.0:
				continue
			var px := floori(p.pos.x)
			var py := floori(p.pos.y)
			var g := w.ground_at(px, py)
			var why := ""
			if w.on_road(px, py):
				why = "on a road"
			elif Ground.is_water(g) or w.level_at(floori(p.pos.x), floori(p.pos.y)) <= 0:
				why = "in water"
			else:
				for v in w.villages:
					if (v.pos as Vector2).distance_to(p.pos) < float(v.get("radius", 4.0)):
						why = "in the square of %s" % v.name
						break
			if why != "":
				var key := "%s %s" % [PropKind.NAMES[p.kind], why]
				bad[key] = int(bad.get(key, 0)) + 1
		check(bad.is_empty(), "seed %d: %s" % [s, bad])


func test_the_machines_works_lie_ruled_on_the_survey_bearing() -> void:
	var w := Worlds.world(Worlds.WORLD_SEEDS[0])
	var d := Vector2.from_angle(GenWorks.bearing(w.seed_value))
	var bearing := fposmod(d.angle(), PI * 0.5)
	# The bearing never follows the tile axes.
	gt(bearing, 0.15, "bearing off the x axis")
	lt(bearing, PI * 0.5 - 0.15, "bearing off the y axis")
	var marked := 0
	for m in w.landmarks:
		if not m.has("mark"):
			continue
		marked += 1
		check(m.has("dir") and m.has("half"), "%s carries its extent" % m.kind)
		var md: Vector2 = m.dir
		if m.kind in [&"turf_rows", &"drained", &"clearcut", &"quarry", &"drill_field", &"slag", &"refinery", &"archive", &"corridor"]:
			near(absf(md.dot(d)) * absf(md.cross(d)), 0.0, 0.02, "%s lies along or across the bearing" % m.kind)
	gt(marked, 10, "works that mark the ground")
	# Runs stand exact: whole pieces at scale 1, turned along their run.
	for p in w.props:
		if p.kind == PropKind.PIPE or p.kind == PropKind.CONVEYOR or p.kind == PropKind.DRILL_RIG:
			near(p.scale, 1.0, 1e-6, "%s at scale 1" % PropKind.NAMES[p.kind])
			var pd := Vector2.from_angle(p.rot)
			near(absf(pd.dot(d)) * absf(pd.cross(d)), 0.0, 0.02, "%s ruled on the bearing" % PropKind.NAMES[p.kind])


func test_the_survey_is_pure_and_broken_into_stretches() -> void:
	var a := GenWorks.survey_sections(7, 512)
	var b := GenWorks.survey_sections(7, 512)
	eq(a.size(), b.size(), "same survey twice")
	gt(a.size(), 60, "stretches across the island")
	var d := Vector2.from_angle(GenWorks.bearing(7))
	var phase := GenWorks.survey_phase(7)
	for sec: Array in a:
		var from: Vector2 = sec[0]
		var to: Vector2 = sec[1]
		near(from.distance_to(to), GenWorks.SURVEY_SECTION, 1e-3, "a stretch is one section")
		# Each stretch sits on its family's line.
		var off := from.dot(Vector2(-d.y, d.x)) if int(sec[2]) == 0 else from.dot(d)
		var spacing := GenWorks.SURVEY_ALONG if int(sec[2]) == 0 else GenWorks.SURVEY_ACROSS
		near(absf(fposmod(off - phase[int(sec[2])] + spacing * 0.5, spacing) - spacing * 0.5), 0.0, 1e-3, "on its line")
	# Broken: about SURVEY_KEEP of the sections survive, never all.
	var c := GenWorks.survey_sections(8, 512)
	check(c.size() != a.size() or c[0][0] != a[0][0], "another seed, another survey")


func test_works_map_paints_each_work_into_its_channel() -> void:
	var w := WorldData.new(3, 64)
	w.ground.fill(Ground.GRASS)
	w.level.fill(1)
	w.landmarks.append({"kind": &"clearcut", "pos": Vector2(20, 20), "dir": Vector2.RIGHT, "half": Vector2(4, 4), "mark": &"cut"})
	w.landmarks.append({"kind": &"slag", "pos": Vector2(44, 44), "dir": Vector2.RIGHT, "half": Vector2(3, 2), "mark": &"scorch"})
	w.landmarks.append({"kind": &"tip", "pos": Vector2(40, 12)})
	var m := WorksMap.bake(w)
	near(m.at(20, 20, 0), 1.0, 1e-3, "inside the clearcut: cut")
	near(m.at(20, 20, 1), 0.0, 1e-3, "and not scorched")
	near(m.at(44, 44, 1), 1.0, 1e-3, "inside the slag: scorch")
	near(m.at(40, 12, 0) + m.at(40, 12, 1) + m.at(40, 12, 2) + m.at(40, 12, 3), 0.0, 1e-3, "a place with no mark paints nothing")
	lt(m.at(26, 20, 0), 0.9, "the edge fades")
	near(m.at(30, 20, 0), 0.0, 1e-3, "and is gone past the feather")


func test_works_map_keeps_off_roads_villages_and_houses() -> void:
	var w := WorldData.new(3, 64)
	w.ground.fill(Ground.GRASS)
	w.level.fill(1)
	for y in 64:
		w.ground[y * 64 + 30] = Ground.ROAD
	w.villages.append({"name": "test", "pos": Vector2(12, 50), "radius": 4.0})
	w.props.append(WorldProp.new(0, PropKind.HOUSE, Vector2(50.5, 12.5), 0.0, 1.0))
	w.landmarks.append({"kind": &"turf_rows", "pos": Vector2(32, 32), "dir": Vector2.RIGHT, "half": Vector2(30, 30), "mark": &"cut"})
	var m := WorksMap.bake(w)
	near(m.at(30, 20, 0), 0.0, 1e-3, "nothing on the road")
	near(m.at(12, 50, 0), 0.0, 1e-3, "nothing in the square")
	near(m.at(50, 12, 0), 0.0, 1e-3, "nothing under a house")
	near(m.at(20, 20, 0), 1.0, 1e-3, "full in open ground")
	check(m.at(32, 20, 0) > 0.0 and m.at(32, 20, 0) < 1.0, "fading back in beside the road")


func test_the_works_keep_off_roads_and_village_squares_on_every_seed() -> void:
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var m := WorksMap.bake(w)
		var road := 0
		var square := 0
		for y in w.size:
			for x in w.size:
				var i := (y * w.size + x) * 4
				if m.bytes[i] == 0 and m.bytes[i + 1] == 0 and m.bytes[i + 2] == 0 and m.bytes[i + 3] == 0:
					continue
				if w.ground[y * w.size + x] == Ground.ROAD:
					road += 1
				for v in w.villages:
					if (v.pos as Vector2).distance_to(Vector2(x + 0.5, y + 0.5)) < float(v.get("radius", 4.0)):
						square += 1
						break
		eq(road, 0, "seed %d: road tiles under the works" % s)
		eq(square, 0, "seed %d: village tiles under the works" % s)
		# The corridor a visitor is sent to carries masts.
		var corridor := GenPlaces.find(w, "corridor")
		if corridor.x >= 0.0:
			var masts := 0
			for p in w.props:
				if p.kind == PropKind.RELAY and p.pos.distance_to(corridor) < 12.0:
					masts += 1
			gt(masts, 0, "seed %d: masts in view of the corridor" % s)
			for v in w.villages:
				gt((v.pos as Vector2).distance_to(corridor), float(v.get("radius", 4.0)) + 4.0, "seed %d: the corridor stop is out of %s" % [s, v.name])


func test_evidence_models_are_drawn_in_the_right_pen() -> void:
	# The machines' works are ruled: FOUND carries most of them.
	for kind: int in [PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.RELAY, PropKind.STACK, PropKind.CHECKPOINT, PropKind.DRILL_RIG, PropKind.CONVEYOR, PropKind.ARCHIVE, PropKind.SURVEY, PropKind.TIDE_GAUGE]:
		var t := PropModels.template(kind, 0, Country.COAST)
		gt(t.found_v.size(), t.made_v.size(), "%s is mostly ruled" % PropKind.NAMES[kind])
	# What people built is drawn by hand, however much steel was in it.
	for kind: int in [PropKind.VEHICLE, PropKind.HULL, PropKind.SEA_WALL, PropKind.FIRE_TOWER, PropKind.STUMP, PropKind.GRAVE, PropKind.DEBRIS, PropKind.WRECKAGE, PropKind.MEMORIAL]:
		for c: int in BiomeRegistry.land_indices():
			var t := PropModels.template(kind, 0, c)
			gt(t.made_v.size(), t.found_v.size(), "%s in %s is mostly drawn by hand" % [PropKind.NAMES[kind], BiomeRegistry.name_of(c)])
	# Neon only where it means something: machine installations, the relay
	# line, and the stolen tech in a shack that wired it in.
	for kind in range(FIRST, PropKind.COUNT):
		for v in PropModels.variants(kind):
			var t := PropModels.template(kind, v, Country.COAST)
			var lit := false
			for col in t.found_c:
				if col.a < 0.98:
					lit = true
					break
			if lit:
				check(kind in [PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.RELAY, PropKind.STACK, PropKind.CHECKPOINT, PropKind.DRILL_RIG, PropKind.TIDE_GAUGE, PropKind.SIGN, PropKind.SURVEY, PropKind.VENT_CAP, PropKind.SHACK, PropKind.PAN_GATE,
					# A mural carries light only on the variants that had a
					# hoarding bolted over the painting, and that light is the
					# city's own: maintained, not stolen and not salvaged.
					PropKind.MURAL,
					# The THRESHOLD site still has power and nobody living: the
					# strip across the tank's head and the line still running on
					# a console are the point of the place, not decoration on it
					# (`src/models/props/black_site.gd`, docs/STORY.md).
					PropKind.GROWTH_TANK, PropKind.CONSOLE],
					"%s %d carries machine light it has no reason for" % [PropKind.NAMES[kind], v])
	var stolen := PropModels.template(PropKind.SHACK, 1, Country.COAST)
	var dark := PropModels.template(PropKind.SHACK, 0, Country.COAST)
	check(_lamp(stolen.made_c) and not _lamp(dark.made_c), "only the shack with stolen tech lights up at night")


static func _lamp(cols: PackedColorArray) -> bool:
	for col in cols:
		var code := roundi(col.a * 255.0)
		if code >= 17 and code <= 32:
			return true
	return false


func test_budgets() -> void:
	# THE LEAST CONTENDED OF THREE RUNS, because a SHARE does not cancel load and
	# I was wrong to think it did. Measured: the works stage is 0.109 of generation
	# run alone and 0.288 of it inside a full gate — nearly triple, from the same
	# code on the same machine. Two stages sharing a worker pool do not slow down
	# together; whichever is more threaded loses more to contention, so the ratio
	# moves. (The "a difference measured WITHIN one run is safe" rule this was
	# built on is docs/LOOK.md's, and it is true of PIXELS in one rendered frame,
	# where both values come from the same pass. Two timings are not that.)
	#
	# So the same answer as everywhere else: load only ever ADDS time, so the
	# cheapest run is the honest one (TestCase.best_of, CLAUDE.md's rule line).
	# Both numbers have to come from ONE run to be a share at all, so this keeps
	# the pair from the run whose generation was quickest rather than timing the
	# two separately.
	var works_ms := 0.0
	var gen_ms := 0
	var w: WorldData = null
	for attempt in 3:
		var t := Time.get_ticks_msec()
		var made := WorldGen.generate(Worlds.WORLD_SEEDS[0], 256)
		var ms := Time.get_ticks_msec() - t
		var stage := 0.0
		for key: StringName in WorldGen.last_detail:
			if String(key).begins_with("works."):
				stage += float(WorldGen.last_detail[key])
		if w == null or ms < gen_ms:
			gen_ms = ms
			works_ms = stage
			w = made
	var evidence := 0
	for p in w.props:
		if p.kind >= FIRST:
			evidence += 1
	print("       works at 256: %d evidence props of %d, works %.0f ms of gen %d ms" % [evidence, w.props.size(), works_ms, gen_ms])
	var big := Worlds.world(Worlds.WORLD_SEEDS[0])
	var verts := 0
	var n := 0
	for p in big.props:
		if p.kind >= FIRST:
			var tpl := PropModels.template(p.kind, 0, Country.COAST)
			verts += tpl.made_v.size() + tpl.found_v.size()
			n += 1
	print("       works at 512: %d evidence props, %d template vertices (%.0f each)" % [n, verts, float(verts) / maxf(n, 1)])
	# NO CLOCK IS ASSERTED HERE ANY MORE, and the two numbers above are printed as
	# diagnostics only. The history is worth keeping because I got it wrong twice:
	#
	#   400 * machine_slack()   56 ms of real work against a bar slack took to
	#                           3200. Blind: nothing could trip it.
	#   share < 0.22            0.141-0.162 measured on a quiet machine, so the bar
	#                           looked tight. In a full gate the same code gives
	#                           0.288. Two stages sharing a worker pool do NOT
	#                           slow down together — whichever is more threaded
	#                           loses more to contention — so a ratio does not
	#                           cancel load. (docs/LOOK.md's "measured WITHIN one
	#                           run" is about PIXELS in one rendered frame. Two
	#                           timings are not that.)
	#   best of three shares    still 0.224 in a gate against 0.109 alone: every
	#                           one of the three runs is contended, so the best of
	#                           them is too.
	#
	# Both, and they answer different questions. `cost_lt` keeps the share as a
	# bar that says "cannot measure" under load instead of guessing (cb's
	# 07b98fb, and the better answer — a door every cost test can use rather than
	# one test's workaround). And the evidence COUNT is asserted outright, because
	# it is the CAUSE: what would make this stage expensive is the world getting
	# fatter, and a count is the same number on any machine under any load, which
	# no timing here has ever been.
	cost_lt(works_ms / maxf(float(gen_ms), 1.0), 0.22,
		"the works stage as a share of generation (%.0f ms of %d)" % [works_ms, gen_ms])
	lt(float(evidence), 1400.0, "evidence the works stage lays at 256 (%d)" % evidence)
	# The vertex count is not a clock and is not scaled: it is the same number on
	# any machine, under any load.
	lt(float(verts) / maxf(n, 1), 1500.0, "vertices per piece of evidence")
