extends TestCase
## Prop models and decor: every kind drawn, MADE and FOUND in their own pens,
## nothing that sways at its root, decor only where the land lies flat.


func test_every_kind_has_a_model_in_every_variant_and_country() -> void:
	for kind in PropKind.COUNT:
		for v in PropModels.variants(kind):
			for c: int in Country.LAND:
				var t := PropModels.template(kind, v, c)
				gt(t.made_v.size() + t.found_v.size(), 11, "%s %d in %s" % [PropKind.NAMES[kind], v, Country.NAMES[c]])
				for col in t.made_c:
					if col == Palette.BLOOM[3]:
						fail("%s %d draws the unmodelled placeholder" % [PropKind.NAMES[kind], v])
						break


func test_the_machines_grid_is_found_and_the_stations_are_made() -> void:
	for kind: int in [PropKind.PYLON, PropKind.POLE]:
		var t := PropModels.template(kind, 0, Country.COAST)
		gt(t.found_v.size(), 100, "%s is ruled" % PropKind.NAMES[kind])
		eq(t.made_v.size(), 0, "%s has nothing drawn by hand" % PropKind.NAMES[kind])
	for kind: int in [PropKind.FIRE, PropKind.BENCH, PropKind.KILN, PropKind.LAMP]:
		var t := PropModels.template(kind, 0, Country.COAST)
		gt(t.made_v.size(), 100, "%s is drawn by hand" % PropKind.NAMES[kind])
	# Every house carries FOUND plate somewhere (patch, courses, housing or plate).
	for v in PropModels.variants(PropKind.HOUSE):
		gt(PropModels.template(PropKind.HOUSE, v, Country.COAST).found_v.size(), 0, "house %d has plate on it" % v)


func test_stations_glow_and_windows_light_at_night() -> void:
	var fire := PropModels.template(PropKind.FIRE, 0, Country.COAST)
	check(_has_code(fire.made_c, 1, 16), "the fire has embers that glow")
	var house := PropModels.template(PropKind.HOUSE, 0, Country.COAST)
	check(_has_code(house.made_c, 17, 32), "a house has a window that lights")


func test_trees_sway_at_the_crown_not_the_root() -> void:
	var t := PropModels.template(PropKind.PINE, 0, Country.PINEWOOD)
	var low := 0.0
	var high := 0.0
	for i in t.made_v.size():
		if t.made_v[i].y < 0.2:
			low = maxf(low, t.made_uv2[i].x)
		elif t.made_v[i].y > 1.8:
			high = maxf(high, t.made_uv2[i].x)
	lt(low, 0.01, "roots are still")
	gt(high, 0.3, "the crown moves")


func test_pines_are_jagged_tiers_not_cones() -> void:
	# A cone's rim is one radius; a drawn pine's tiers alternate tips and notches.
	var k := PropModels.Kit.new()
	k.tier(0.0, 1.0, 0.0, 0.8, 0.5, 8, 0.15, 77, Palette.SPRUCE[3], Palette.SPRUCE[1])
	var lo := 99.0
	var hi := 0.0
	for v in k.made.verts:
		var r := Vector2(v.x, v.z).length()
		if v.y < 1.2 and r > 0.1:
			lo = minf(lo, r)
			hi = maxf(hi, r)
	gt(hi / maxf(lo, 1e-3), 1.8, "tip to notch ratio")
	var t := PropModels.template(PropKind.PINE, 0, Country.PINEWOOD)
	gt(t.made_v.size(), 200, "a pine is several tiers")


func test_decor_is_deterministic_and_keeps_off_water_and_edges() -> void:
	var w := load("res://tests/render/test_terrain.gd").fixture() as WorldData
	var m := TerrainMesher.new(w)
	var ch := m.build(0, 0)
	var d := Decor.new(w)
	var a := d.build(ch)
	var b := Decor.new(w).build(ch)
	check(a != null, "decor built")
	eq(a.surface_get_array_len(0), b.surface_get_array_len(0), "same decor twice")
	var verts: PackedVector3Array = a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0, verts.size(), 7):
		var v := verts[i]
		check(not (v.x > 14.2 and v.x < 16.8 and v.z > 2.0 and v.z < 30.0), "decor in the river at %s" % v)
		check(v.x > 8.5, "decor in the sea at %s" % v)


func test_decor_grass_leans_and_moves_by_height() -> void:
	var t := Decor.template(Decor.TUFT, Country.COAST, 0)
	var base := 0.0
	var tip := 0.0
	for i in t.v.size():
		if t.v[i].y < 0.01:
			base = maxf(base, t.uv2[i].x)
		elif t.v[i].y > 0.1:
			tip = maxf(tip, t.uv2[i].x)
	lt(base, 0.01, "blade roots stay put")
	gt(tip, 0.4, "blade tips move")


static func _has_code(cols: PackedColorArray, lo: int, hi: int) -> bool:
	for c in cols:
		var code := roundi(c.a * 255.0)
		if code >= lo and code <= hi:
			return true
	return false
