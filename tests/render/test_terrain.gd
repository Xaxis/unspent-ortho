extends TestCase
## The land as drawn: contours, ecotones, water and chunk streaming. Worlds are
## built by hand here, so these rules hold whatever world generation does.


## A 64-tile world: sea on the west, a coast plateau at level 2 with a step to
## level 4, a river at level 2 running north-south, and pinewood to the east of
## x = 40 (no transitions written, so the fallback must supply them).
static func fixture() -> WorldData:
	var w := WorldData.new(5, 64)
	for y in 64:
		for x in 64:
			var i := y * 64 + x
			var l := -1 if x < 6 else (0 if x < 9 else (2 if x < 30 else 4))
			# A diagonal step, so a contour must not follow tile rows.
			if x >= 24 and x < 30 and x - 24 > (y % 12) / 2:
				l = 4
			w.level[i] = l
			w.country[i] = Country.SEA if l <= 0 else (Country.COAST if x < 40 else Country.PINEWOOD)
			var g := Ground.GRASS if x < 40 else Ground.NEEDLES
			if l < 0:
				g = Ground.DEEP_WATER
			elif l == 0:
				g = Ground.WATER
			elif x >= 14 and x < 17:
				g = Ground.RIVER
			w.ground[i] = g
	return w


func test_chunk_build_is_deterministic() -> void:
	var w := fixture()
	var a := TerrainMesher.new(w).build(0, 0)
	var b := TerrainMesher.new(w).build(0, 0)
	eq(a.key, b.key, "keys")
	eq(a.t, b.t, "terraces")
	eq(a.terrain.surface_get_array_len(0), b.terrain.surface_get_array_len(0), "vertex count")


func test_neighbouring_chunks_agree_on_their_border() -> void:
	var w := WorldData.new(9, 96)
	for y in 96:
		for x in 96:
			var i := y * 96 + x
			w.level[i] = 1 + int((x + y * 0.7) / 9.0) % 4
			w.country[i] = Country.COAST
			w.ground[i] = Ground.GRASS
	var m := TerrainMesher.new(w)
	var left := m.build(0, 0)
	var right := m.build(1, 0)
	var np := left.n + 1
	for j in left.h * TerrainMesher.RES + 1:
		var a := j * np + left.n
		var b := j * np
		near(left.f[a], right.f[b], 1e-4, "field at border row %d" % j)
		eq(left.key[a], right.key[b], "key at border row %d" % j)


## Rough terraced country the way generation leaves it: blocky steps along
## rows, with one-tile spurs, notches and pits sprinkled over them.
static func rough() -> WorldData:
	var w := WorldData.new(11, 96)
	for y in 96:
		for x in 96:
			var i := y * 96 + x
			var l := clampi(int(2.5 + sin(x * 0.13) * 1.4 + cos(y * 0.11 + x * 0.05) * 1.4), 1, 5)
			if x >= 60 and x < 72 and y >= 20 and y < 28:
				l = 5
			var h := Rng.hash01(11, x, y)
			if h < 0.025:
				l += 1
			elif h > 0.975:
				l = maxi(1, l - 1)
			w.level[i] = l
			w.country[i] = Country.COAST
			w.ground[i] = Ground.GRASS
	return w


func test_terrace_edges_do_not_follow_the_tile_grid() -> void:
	var w := fixture()
	var ch := TerrainMesher.new(w).build(0, 0)
	var arrays := ch.terrain.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var walls := 0
	var off_grid := 0
	for i in verts.size():
		if absf(normals[i].y) > 0.5:
			continue
		walls += 1
		var v := verts[i]
		if absf(v.x * 2.0 - roundf(v.x * 2.0)) > 0.02 or absf(v.z * 2.0 - roundf(v.z * 2.0)) > 0.02:
			off_grid += 1
	gt(walls, 50, "walls drawn")
	gt(float(off_grid) / maxf(1.0, walls), 0.4, "share of wall vertices off the half-tile lattice")
	# No right-angled turns: an edge bends like a drawn contour, it does not
	# step round single tiles.
	var m := TerrainMesher.new(rough())
	var length := 0.0
	var corners := 0.0
	for cy in 3:
		for cx in 3:
			var r := TerrainMesher.edge_corners(m.build(cx, cy).edges)
			length += r[0]
			corners += r[1]
	gt(length, 400.0, "rough country has edges")
	lt(corners * 10.0 / length, 0.25, "sharp corners per 10 tiles of edge (%d in %d tiles)" % [corners, length])


func test_one_tile_spurs_and_notches_are_drawn_at_their_neighbours_level() -> void:
	var w := WorldData.new(2, 32)
	for i in 32 * 32:
		w.level[i] = 2
		w.country[i] = Country.COAST
		w.ground[i] = Ground.GRASS
	for x in range(16, 32):
		for y in 32:
			w.level[y * 32 + x] = 3
	w.level[10 * 32 + 16] = 2 # a notch into the high side
	w.level[20 * 32 + 15] = 3 # a spur out of it
	w.level[5 * 32 + 5] = 3 # a lone pip
	w.level[25 * 32 + 5] = 1 # a lone pit
	for y in range(12, 16): # a two-tile-wide ridge is a shape, not noise
		w.level[y * 32 + 8] = 3
		w.level[y * 32 + 9] = 3
	var d := TerrainMesher.new(w).drawn_levels(0, 0, 32, 32)
	eq(d[10 * 32 + 16], 3, "notch filled")
	eq(d[20 * 32 + 15], 2, "spur cut")
	eq(d[5 * 32 + 5], 2, "pip levelled")
	eq(d[25 * 32 + 5], 2, "pit filled")
	eq(d[13 * 32 + 8], 3, "ridge kept")
	eq(d[13 * 32 + 9], 3, "ridge kept")
	eq(d[10 * 32 + 20], 3, "the plateau stays")


func test_a_tile_centre_stays_on_its_own_terrace() -> void:
	var w := fixture()
	var m := TerrainMesher.new(w)
	var d := m.drawn_levels(0, 0, 64, 64)
	for y in range(2, 62, 3):
		for x in range(10, 62, 3):
			eq(floori(m.smooth_level(x, y) + 0.5), d[y * 64 + x], "smoothed level at %d,%d" % [x, y])
			if w.level_at(x - 1, y) == w.level_at(x, y) and w.level_at(x + 1, y) == w.level_at(x, y):
				eq(d[y * 64 + x], w.level_at(x, y), "only lone tiles are redrawn, %d,%d" % [x, y])


func test_sea_sheet_sits_at_water_level_and_inland_water_hides_shins() -> void:
	var w := fixture()
	var ch := TerrainMesher.new(w).build(0, 0)
	check(ch.water != null, "water built")
	var arrays := ch.water.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var sea := 0
	var river := 0
	for v in verts:
		if v.x < 5.0:
			near(v.y, TerrainMesher.WATER_Y, 1e-4, "sea sheet")
			sea += 1
		elif v.x > 14.6 and v.x < 16.4 and v.z > 4.0 and v.z < 28.0:
			# A walker stands at level * STEP; the sheet must cover its shins.
			near(v.y, 2 * WorldData.STEP + TerrainMesher.WADE, 1e-4, "river sheet at %s" % v)
			river += 1
	gt(sea, 0, "sea vertices")
	gt(river, 0, "river vertices")
	# The river bed is below its sheet.
	lt(ch.surface(15.5, 16.0), 2 * WorldData.STEP + TerrainMesher.WADE - 0.1, "bed under the sheet")


func test_fallback_blend_only_when_generation_wrote_none() -> void:
	var w := fixture()
	check(BlendFallback.new(w).active, "a world without transitions uses the fallback")
	w.blend[w.size * 10 + 20] = 0.2
	check(not BlendFallback.new(w).active, "a world with transitions keeps its own")


func test_fallback_turns_toward_the_neighbour_near_a_border() -> void:
	var w := fixture()
	var f := BlendFallback.new(w)
	var c := PackedByteArray()
	var c2 := PackedByteArray()
	var b := PackedFloat32Array()
	f.fill(0, 0, 64, 64, c, c2, b)
	var at_border := b[32 * 64 + 40]
	var deep := b[32 * 64 + 12]
	gt(at_border, 0.2, "blend at the coast/pinewood border")
	lt(deep, at_border, "blend deep in the coast")
	for i in b.size():
		check(b[i] <= 0.5, "blend never passes the border")
	eq(int(c2[32 * 64 + 40]) if c[32 * 64 + 40] == Country.COAST else int(c[32 * 64 + 40]), Country.PINEWOOD, "the neighbour is pinewood")


func test_an_ecotone_interleaves_both_countries() -> void:
	var w := fixture()
	var m := TerrainMesher.new(w)
	var ch := m.build(1, 0)
	var seen := {}
	for k in ch.key:
		if (k & 0x10000) == 0:
			seen[(k >> 8) & 0xFF] = true
	check(seen.has(Country.COAST) and seen.has(Country.PINEWOOD), "both countries drawn in the ecotone chunk: %s" % str(seen.keys()))


## Two countries meeting on a straight north-south border at x = 64.
static func two_countries() -> WorldData:
	var w := WorldData.new(21, 128)
	for y in 128:
		for x in 128:
			var i := y * 128 + x
			w.level[i] = 2
			w.country[i] = Country.COAST if x < 64 else Country.SNOWFIELD
			w.ground[i] = Ground.GRASS if x < 64 else Ground.SNOW
	return w


func test_an_ecotone_turns_gradually_and_heartlands_stay_clean() -> void:
	var w := two_countries()
	var m := TerrainMesher.new(w)
	# Foreign share by distance band from the border (in tiles, own side).
	var bands := PackedFloat32Array([0, 0, 0, 0, 0])
	var counts := PackedFloat32Array([0, 0, 0, 0, 0])
	var edges: Array[float] = [0.0, 4.0, 9.0, 16.0, 28.0, 64.0]
	for cy in range(1, 3):
		for cx in 4:
			var ch := m.build(cx, cy)
			var np := ch.n + 1
			for j in ch.h * TerrainMesher.RES + 1:
				for i in np:
					var x := ch.x0 + i * 0.5
					var own := Country.COAST if x < 64.0 else Country.SNOWFIELD
					var d := absf(x - 64.0)
					var country := (ch.key[j * np + i] >> 8) & 0xFF
					for band in 5:
						if d >= edges[band] and d < edges[band + 1]:
							counts[band] += 1.0
							if country != own:
								bands[band] += 1.0
	for band in 5:
		bands[band] /= maxf(1.0, counts[band])
	gt(bands[0], 0.2, "the border is a mix")
	lt(bands[1], bands[0], "less mixed 4-9 tiles out")
	lt(bands[2], bands[1] + 0.02, "less again 9-16 tiles out")
	lt(bands[2], 0.12, "only tongues 9-16 tiles out")
	eq(bands[4], 0.0, "a heartland is its own country")


func test_decor_of_the_neighbour_arrives_before_its_wash() -> void:
	for b: float in [0.05, 0.15, 0.25, 0.35]:
		gt(Decor.lead_share(b), TerrainMesher.eco_cover(b), "decor leads the wash at blend %s" % b)
	eq(Decor.lead_share(0.0), 0.0, "no neighbour decor in a heartland")
	near(TerrainMesher.eco_share(0.5), 0.5, 1e-4, "an even mix on the border")
	near(TerrainMesher.eco_share(0.3) + TerrainMesher.eco_share(0.7), 1.0, 1e-4, "both sides read one field")


func test_marks_ride_in_alpha_and_plain_colours_carry_none() -> void:
	eq(roundi(Color(0.2, 0.3, 0.4, 1.0).a * 255.0), 255, "a palette colour is plain")
	var g := GroundColors.glow(Palette.EMBER[3], 1.0)
	var code := roundi(g.a * 255.0)
	check(code >= 1 and code <= 16, "glow code %d" % code)
	var l := GroundColors.lamp(Palette.COPPER[4], 1.6)
	code = roundi(l.a * 255.0)
	check(code >= 17 and code <= 32, "lamp code %d" % code)
	for gr: int in [Ground.GRASS, Ground.SNOW, Ground.LIMESTONE, Ground.ASH, Ground.NEEDLES, Ground.MOSS]:
		check(GroundColors.mark(gr, Country.COAST) >= 40, "%s carries a ground mark" % Ground.NAMES[gr])


func test_every_country_draws_its_turf_in_its_own_wash() -> void:
	var seen: Array[Color] = []
	for c: int in Country.LAND:
		var col := GroundColors.wash(GroundColors.home_turf(c), c)
		check(col != Palette.BLOOM[3], "%s has a wash" % Country.NAMES[c])
		for other in seen:
			var diff := absf(col.r - other.r) + absf(col.g - other.g) + absf(col.b - other.b)
			gt(diff, 0.08, "%s turf distinct" % Country.NAMES[c])
		seen.append(col)


func test_view_radius_follows_the_camera() -> void:
	var small := WorldView.half_extent_for(15.0, 16.0 / 9.0, deg_to_rad(57.0))
	var big := WorldView.half_extent_for(30.0, 16.0 / 9.0, deg_to_rad(57.0))
	gt(small, 12.0, "sees at least the screen")
	lt(small, 32.0, "no more than a chunk each way at play zoom")
	gt(big, small * 1.6, "a wider view wants more land")


func test_soft_ground_hummocks_only_inside_one_terrace() -> void:
	var w := WorldData.new(3, 64)
	for y in 64:
		for x in 64:
			var i := y * 64 + x
			w.level[i] = 2 if x < 40 else 3
			w.country[i] = Country.MOSS
			w.ground[i] = Ground.MOSS
	var ch := TerrainMesher.new(w).build(0, 0)
	var np := ch.n + 1
	var any := false
	for j in ch.h * TerrainMesher.RES + 1:
		for i in np:
			var b := ch.bump[j * np + i]
			if b != 0.0:
				any = true
				lt(absf(b), 0.12, "a hummock stays small")
				var x := ch.x0 + i * 0.5
				check(absf(x - 40.0) > 1.2, "no hummock at the step, x=%s" % x)
	check(any, "fen ground is hummocked")
	near(ch.surface(20.0, 20.0), 2 * WorldData.STEP, 0.12, "walkable height kept")


func test_masts_carry_cables_from_their_arms() -> void:
	eq(WorldView.cable_points(PropKind.PYLON).size(), 4, "pylon insulators")
	eq(WorldView.cable_points(PropKind.POLE).size(), 2, "pole insulators")
	eq(WorldView.cable_points(PropKind.PINE).size(), 0, "a tree carries none")
