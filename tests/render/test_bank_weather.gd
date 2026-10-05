extends TestCase
## A BANK IS ONE SURFACE TO THE WEATHER. The mesher lays an inland water's lip
## in triangles that tilt one by one (TerrainMesher's shore profile), and the
## weather in sky.gdshaderinc used to ask each fragment's own facet how level it
## was: the wet darkening took the level facets and left the tilted ones, a
## sawtooth of pale triangles down every shore (the drowned city at noon). So the
## land tells the weather it is level (world.gdshader `land_up`), and the sky
## include asks a face's derivatives in one place only, for surfaces that say
## nothing.

const SKY := "res://src/render/sky.gdshaderinc"
const WORLD := "res://src/render/world.gdshader"
## The pool: centre and radius in tiles, in the first chunk.
const POOL := Vector2(16.0, 16.0)
const POOL_R := 6.0
## How level a facet must be for the wet to take it (sky_apply_up's `step(0.9`).
const SOAK_LEVEL := 0.9


## Drowned-city floor at level 2 with a pool of its black water in it.
static func fixture() -> WorldData:
	var w := WorldData.new(5, 48)
	var city := BiomeRegistry.index_of(&"drowned_city")
	for y in 48:
		for x in 48:
			var i := y * 48 + x
			w.level[i] = 2
			w.country[i] = city
			var wet := Vector2(x + 0.5, y + 0.5).distance_to(POOL) < POOL_R
			w.ground[i] = Ground.BLACKWATER if wet else Ground.FLOOR
	return w


func test_a_banks_lip_is_laid_in_tilted_facets() -> void:
	# The premise: on the bank (the floor and its lip, not the bed sunk under the
	# sheet) facets tilt past the soak's level test, so a test made facet by
	# facet splits the bank into triangles.
	var ch := TerrainMesher.new(fixture()).build_arrays(0, 0)
	var v: PackedVector3Array = ch.terrain_arrays[Mesh.ARRAY_VERTEX]
	var floor_y := TerrainMesher.level_height(2)
	var bank := 0
	var tilted := 0
	for t in range(0, v.size(), 3):
		var mid := (v[t] + v[t + 1] + v[t + 2]) / 3.0
		var off := Vector2(mid.x, mid.z).distance_to(POOL) - POOL_R
		if absf(off) > 2.5 or mid.y < floor_y - 0.02:
			continue
		var up := absf((v[t + 1] - v[t]).cross(v[t + 2] - v[t]).normalized().y)
		if up < 0.45:
			continue
		bank += 1
		if up < SOAK_LEVEL:
			tilted += 1
	print("  info the pool's bank: %d top facets, %d tilted past %.2f" % [bank, tilted, SOAK_LEVEL])
	gt(float(bank), 100.0, "the bank is laid (%d facets)" % bank)
	gt(float(tilted), 10.0, "and its lip's facets tilt past the soak's level test (%d)" % tilted)


func test_the_land_tells_the_weather_it_is_level() -> void:
	var sky := FileAccess.get_file_as_string(SKY)
	var world := FileAccess.get_file_as_string(WORLD)
	eq(sky.count("cross(dFdx(world_pos), dFdy(world_pos))"), 1,
		"sky.gdshaderinc asks a facet's derivatives in one place (sky_face_up)")
	check(sky.contains("float wet = neon_wetness(world_pos) * step(%s, face_up);" % SOAK_LEVEL),
		"the wet darkening reads the level it is given")
	check(sky.contains("vec3 c = sky_settled(albedo, albedo, world_pos, px, face_up);"),
		"and so does what settles")
	check(world.contains("float land_up = mark_ground(m) ? 1.0 : face_up;"),
		"world.gdshader calls the land's top level")
	check(world.contains("c = sky_apply_up(c, world_pos, TIME, land_up);"),
		"and asks the weather with it")
	check(world.contains("neon_reflect_up(world_pos, px, land_up)"),
		"and the wet ground's reflections too")
