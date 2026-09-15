extends TestCase
## The dystopian evidence of every landscape (GenWorks): each landscape holds
## its own works and remains on every seed, the machines' works lie ruled on
## the survey bearing, the hand's things keep off villages, roads and water,
## and the whole of it stays inside its budget. Uses the cached default worlds.

const Worlds := preload("res://tests/core/test_world_gen.gd")

## The evidence kinds, from FENCE to the end of PropKind.
const FIRST := PropKind.FENCE

## Works each landscape must hold on every seed: kind -> its country.
const HOME := {
	PropKind.HULL: Country.COAST, PropKind.INTAKE: Country.COAST, PropKind.SEA_WALL: Country.COAST, PropKind.TIDE_GAUGE: Country.COAST,
	PropKind.PUMP_HOUSE: Country.MOSS,
	PropKind.RELAY: Country.PINEWOOD, PropKind.FIRE_TOWER: Country.PINEWOOD,
	PropKind.CHECKPOINT: Country.SNOWFIELD, PropKind.STACK: Country.SNOWFIELD,
	PropKind.WATER_TANK: Country.BONELANDS, PropKind.CONVEYOR: Country.BONELANDS,
	PropKind.SLAG_HEAP: Country.BURNING, PropKind.ARCHIVE: Country.BURNING,
}


func test_every_landscape_holds_its_own_works_on_every_seed() -> void:
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
			check(at_home.has(kind), "seed %d: no %s in the %s" % [s, PropKind.NAMES[kind], Country.NAMES[HOME[kind]]])
		for kind in range(FIRST, PropKind.COUNT):
			gt(counts[kind], 0, "seed %d %s placed" % [s, PropKind.NAMES[kind]])
		# Evidence at walking scale in every landscape, not only at the works.
		var land := PackedFloat32Array()
		land.resize(Country.COUNT)
		for i in w.level.size():
			if w.level[i] > 0:
				land[w.country[i]] += 1.0
		var evidence := PackedFloat32Array()
		evidence.resize(Country.COUNT)
		for p in w.props:
			if p.kind >= FIRST:
				evidence[w.country_at(floori(p.pos.x), floori(p.pos.y))] += 1.0
		for cc: int in Country.LAND:
			gt(evidence[cc] * 1000.0 / maxf(land[cc], 1.0), 9.0,"seed %d evidence per 1000 tiles of %s" % [s, Country.NAMES[cc]])


func test_evidence_keeps_off_roads_water_and_village_squares() -> void:
	for s in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var bad := {}
		for p in w.props:
			if p.kind < FIRST:
				continue
			var g := w.ground_at(floori(p.pos.x), floori(p.pos.y))
			var why := ""
			if g == Ground.ROAD:
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
	for kind: int in [PropKind.VEHICLE, PropKind.HULL, PropKind.SEA_WALL, PropKind.FIRE_TOWER, PropKind.STUMP, PropKind.GRAVE, PropKind.DEBRIS]:
		for c: int in Country.LAND:
			var t := PropModels.template(kind, 0, c)
			gt(t.made_v.size(), t.found_v.size(), "%s in %s is mostly drawn by hand" % [PropKind.NAMES[kind], Country.NAMES[c]])
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
				check(kind in [PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.RELAY, PropKind.STACK, PropKind.CHECKPOINT, PropKind.DRILL_RIG, PropKind.TIDE_GAUGE, PropKind.SIGN, PropKind.SURVEY, PropKind.VENT_CAP, PropKind.SHACK],
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
	# Printed so a change that fattens the world shows in the log.
	var t := Time.get_ticks_msec()
	var w := WorldGen.generate(Worlds.WORLD_SEEDS[0], 256)
	var gen_ms := Time.get_ticks_msec() - t
	var works_ms := 0.0
	for key: StringName in WorldGen.last_detail:
		if String(key).begins_with("works."):
			works_ms += float(WorldGen.last_detail[key])
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
	lt(works_ms, 400.0, "works stage at 256")
	lt(float(verts) / maxf(n, 1), 1500.0, "vertices per piece of evidence")
