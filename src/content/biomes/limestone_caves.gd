## Limestone Caves: the first landscape under the world (docs/VISION.md, #16).
## Karst halls, an underground river, flowstone, and black sumps at the bottom of
## everything.
##
## Drawn as SCRATCHBOARD (docs/VISION.md): the page is dark and the lines are
## scraped pale. Nothing in the renderer had to change for that, because a
## scratchboard IS the notebook with its values turned over, and the notebook
## already puts a landscape's darkness in three places — the light it stands in
## (`light_tint`), the grade its washes pass through (`grade.x`, which lifts on
## every surface landscape and DIMS here) and the washes themselves. What is left
## is the drawing, and that is composed rather than filtered:
##
##   the floor is dark      LIMESTONE, wet stone, near the bottom of the ramp
##   the forms are pale     BONE is flowstone: gours, curtains and stalagmite
##                          feet, massing on every rise and along the water
##   every lip is scraped   `terrace` is high and the wall wash is calcite, so a
##                          hall is a stack of pale contour lines on a dark floor
##   the walls are bedded   STRATA_BONE bands each face the way limestone lies
##   the water is a hole    but not a hole in the page (`water_wash`)
##
## What the machines did to it: they cut in from above and left. The shafts are
## Portals (src/core/realm/portals.gd); the pipes and the debris are theirs.
##
## No sentinel yet, and the machines down here are the bonelands' cutters and
## haulers working a face: VISION's blind crawlers want a body of their own, and
## that is M3's.

const P := preload("res://src/render/palette.gd")

## The dark the hall floor sits at. Every wash here is measured against it: the
## floor near the bottom of the value ramp, the flowstone near the top, and
## nothing in between that makes the frame grey.
const FLOOR := Color(0.1255, 0.1412, 0.1804)
## Calcite: the one pale thing down here, warmed a little off the page so it is
## never mistaken for snow or for the salt flat's crust.
const CALCITE := Color(0.8353, 0.7961, 0.6980)


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"limestone_caves"
	d.display_name = "limestone caves"
	d.spoken_in = "down in the limestone caves"
	# After every surface landscape: the M1 six keep 1..6 and wave A's two keep
	# 7..8 whatever is registered under the world.
	d.order = 200
	d.realms = [Realm.UNDERGROUND]
	d.style_note = "Scratchboard: a dark page, pale scraped contours, and colour only inside the lamp."
	# The whole of its own realm, for now: the only landscape registered under the
	# world. The share still has to be a real one, because the moment the Adits
	# and the Rootways arrive they share this land out against it.
	d.share = Vector2(0.55, 0.75)
	# It lies where it lies: there is no journey under the world yet, and one
	# anchor keeps it from being dropped on a small island (GenCountries.fit_types
	# throws out an anchorless type whose share is not a region's worth).
	d.anchors = [{"seq": 0, "u": 0.5, "v": 0.5}]
	d.coastal = 0.0
	# Halls and galleries: low relief overall, cut deep by the river, and
	# TERRACED hard, because a terrace step is the line this landscape is drawn
	# with. `cliff` raises the faces the galleries run under.
	d.relief = {
		&"base": 5.0, &"hills": 3.6, &"ridge": 2.6, &"near": 6.0, &"terrace": 1.0, &"valley": 1.15,
		&"rain": 1.3, &"temp": 0.34, &"moist": 0.9, &"cliff": 0.7,
	}
	d.hatch = Ink.CRACK
	d.grounds = {
		# The hall floor and what it breaks into. Wet stone, cold, dark.
		Ground.LIMESTONE: FLOOR,
		Ground.ROCK: FLOOR.lerp(P.SLATE[1], 0.45),
		Ground.SCREE: FLOOR.lerp(P.SLATE[2], 0.30),
		Ground.GRAVEL: FLOOR.lerp(P.STONE[2], 0.42),
		# Flowstone and gour rims: the pale scraped forms the eye reads first.
		# Flowstone underfoot: calcite, but damp and in the dark, never the page.
		# At CALCITE it came back as snow-white patches under any lamp.
		Ground.BONE: CALCITE.lerp(P.SLATE[1], 0.5),
		# Cave clay, and the silt bank the river lays on the inside of a bend.
		Ground.MUD: P.EARTH[1].lerp(P.SLATE[1], 0.35),
		Ground.SAND: P.EARTH[2].lerp(P.SLATE[1], 0.45),
		# Nothing under the world lays these, and no cave can border a snowfield
		# — but `GroundColors.wash` is a table with a row for every ground under
		# every landscape, and a row left at the shared value is page-white. One
		# stray tile of it in a dark hall is a hole in the page, so the dark realm
		# answers for every row of its own column (tests/render/test_ground_washes).
		Ground.SNOW: CALCITE.lerp(P.RIME[2], 0.30),
		Ground.ICE: P.RIME[2].lerp(P.SLATE[1], 0.25),
		Ground.SALT: CALCITE.lerp(P.LINEN[2], 0.25),
	}
	# The floor is drawn with the cracks of rock, not the joints of a pavement:
	# a grike drawn pale on this ground would read as the flowstone it is not.
	d.ground_marks = {Ground.LIMESTONE: GroundColors.ROCK}
	# Every terrace wall is calcite over bedded limestone: the pale line.
	d.cliff_wash = CALCITE.lerp(P.LINEN[2], 0.35)
	# The walls are the CAVE's own (GroundColors.STRATA_CAVE): wet rock hung with
	# flowstone curtains. They were the bonelands' limestone beds, laid in courses
	# with ruled joints, and underground that read as brick terraces.
	d.strata = GroundColors.STRATA_CAVE
	d.plain_ground = Ground.LIMESTONE
	d.bank_ground = Ground.GRAVEL
	d.pool_rim_ground = Ground.BONE
	d.rock_ground = Ground.ROCK
	# No village under the world yet (villages = 0), so these are only what the
	# fields fall back to if one is ever put down here.
	d.village_ground = Ground.GRAVEL
	d.village_square_ground = Ground.GRAVEL
	d.rock_color = P.SLATE[2]
	d.grass_colors = [P.SPRUCE[1], P.SPRUCE[2]]
	# A hall's floor is stone chips, fallen blocks, calcite crystal where water
	# stood, and the cores the machines pulled and left.
	d.decor = {
		Ground.LIMESTONE: [0.85, Decor.STONE, 26, Decor.PEBBLES, 22, Decor.RUBBLE, 14, Decor.ICE_SHARD, 8, Decor.BONE, 3],
		Ground.BONE: [0.7, Decor.ICE_SHARD, 30, Decor.PEBBLES, 18, Decor.STONE, 12],
		Ground.GRAVEL: [1.0, Decor.RUBBLE, 30, Decor.STONE, 22, Decor.DRILL_CORE, 6],
		Ground.SCREE: [1.1, Decor.RUBBLE, 34, Decor.STONE, 20],
		Ground.MUD: [0.6, Decor.PEBBLES, 20, Decor.BONE, 6, Decor.SPOIL, 8],
		# Nothing green grows down here, so both of these say so: the shared
		# tables put lichen and marram grass on bare rock and on sand, and a
		# green speck in a cave is the one thing that says "outside".
		Ground.ROCK: [0.45, Decor.STONE, 34, Decor.RUBBLE, 16, Decor.ICE_SHARD, 6],
		Ground.SAND: [0.5, Decor.PEBBLES, 26, Decor.STONE, 14, Decor.BONE, 5],
	}
	d.decor_tints = {
		# Calcite crystal, and the grit a drill left: both read off the pale, so
		# a speck on a dark floor is a scrape and not a hole.
		&"spoil": [P.LINEN[2], P.STONE[2], P.STONE[3]],
	}
	d.tree_tints = {}
	# Nothing weathers down here, so nothing is silvered or bleached: a post left
	# in a hall is the wet dark it was cut as. What banks against a thing is the
	# grit off the roof, and the shelter a sump crew put up stands on stilts out
	# of the standing water.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[2], P.SLATE[1], P.LINEN[2]]
	dress.pale = [P.LINEN[4], P.LINEN[3], P.STONE[3]]
	dress.timber = [P.EARTH[1], P.INK[3]]
	dress.drift = [P.STONE[2], P.STONE[1]]
	dress.walling = [P.LINEN[3], P.LINEN[2], P.STONE[3], P.SLATE[2]]
	dress.covers = &"drift"
	dress.growth = P.SPRUCE[1]
	dress.sink = 0.08
	d.dressing = dress
	# What a roofed realm is: no sky over it, so no sun on it and no weather off
	# it. Both come from the realm, not from this file (src/core/realm/realm.gd).
	d.light_tint = Realm.light(Realm.UNDERGROUND)
	d.grade = Vector4(Realm.lift(Realm.UNDERGROUND), 0.10, 0.24, 0.12)
	# Taken from the realm like the other three, and 1.0 there: what makes a cave
	# dark is the roof (SkyLight.closed), not a night level. A cave that asked for
	# a dark night as well would be dimmed twice for one reason.
	d.night_sky = Realm.night_sky(Realm.UNDERGROUND)
	# Its air, out of the realm's own table (no rain, no snow, nothing that falls
	# out of a sky): still and clear for days, then saturated and hanging.
	d.weather = Realm.airs(Realm.UNDERGROUND)
	# The places worth the walk it holds (docs/VISION.md, src/core/landmarks):
	# what a player crosses this landscape FOR. Its own file is the authority;
	# `Landmarks.problems` fails if a kind here does not name this landscape back.
	d.landmarks = [&"clerks_office", &"poured_pillar", &"sump_pump"]
	d.sound_bed = Realm.bed(Realm.UNDERGROUND)
	# Saturated air: it lies wet whether or not anything is falling.
	d.wet = 0.55
	# Sinkholes to the day above (11_dome): columns of cold daylight standing in
	# the dark and the damp, the one place in the caves the hour is seen.
	d.sky_holes = 0.8
	d.mist = 0.0
	# Black, and still a chart: the soundings and the swash survive the tint
	# (tests/render/test_water_wash.gd).
	# Lifted well off the chart's own darks, because everything down here is then
	# multiplied by a light a third of the day's: black water under a dark realm's
	# light is a hole in the page, which is the one thing water may never be.
	d.water_wash = Color(0.31, 0.47, 0.51, 0.70)
	d.hard_rock = true
	d.props = [PropKind.BOULDER, PropKind.CLINTS, PropKind.STANDING_STONE,
		PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE,
		PropKind.TIN_ORE, PropKind.BONES, PropKind.DEBRIS]
	# Deep seams: what the surface only shows at a broken face is everywhere here,
	# and that is the reason to come down (VISION §6.1, elite materials by place).
	d.ore = [[PropKind.STONE_ORE, 0.075], [PropKind.IRON_ORE, 0.115],
		[PropKind.COPPER_ORE, 0.140], [PropKind.COAL_ORE, 0.158], [PropKind.TIN_ORE, 0.170]]
	d.gravel_ore = true
	d.reed_chance = 0.0
	d.shore_bush = PropKind.BOULDER
	d.sites = {}
	d.tip_ground = Ground.GRAVEL
	d.beached_wrecks = false
	# Sumps and gour pools, laid first: everything else is drawn round them.
	d.pools = {"order": 1, "cell": 30, "chance": 0.42, "r_min": 1.8, "r_max": 3.4,
		"ground": Ground.BLACKWATER}
	d.villages = 0
	d.village_names = []
	d.village_order = 90
	d.spawn_home = false
	# Dark first, and the two the karst itself presses with: it lies wet, and the
	# roof over a gallery is not sound. Every one of them has gear that answers
	# (tests/gear), because they are all pressures the surface already declares.
	d.hazards = {&"dark": 0.9, &"wet": 0.4, &"collapse": 0.35}
	# The machines that cut stone and carry it, at the face the surface only shows
	# the top of. Each says what it walks on HERE, because a row written for the
	# bonelands pavement is not a row about a cave floor (tests/biome). VISION's
	# blind crawlers want a body of their own, and that is M3's.
	d.roster = {
		&"cutter": {"weight": 1.0, "grounds": ["limestone", "rock", "gravel", "scree", "bone"]},
		# The cave hauler works the dark by ear: it hardly sees and hears
		# everything, walks the face slower, and winds its bite up longer, which
		# is what makes it a cave's to fight and not the bonelands' (BiomeDef.roster).
		# And its knuckle drive is on its BACK, away from the wall it works: a
		# player who has learned the bonelands hauler's left side goes round to
		# the wrong one here.
		&"hauler": {"weight": 0.7, "grounds": ["limestone", "gravel", "bone", "mud"],
			"over": {"sees": 3, "hears": 13, "pace": 3.4, "part": &"back",
				"bite": {"swing": [780, 160, 600, 800], "reach": 1.5, "width": 2.0, "dmg": 4, "knock": 9.5, "knock_ms": 320}}},
	}
	d.surface = _surface
	d.scatter = _scatter
	# What the machines left down here, and what they left it for. No fences, no
	# cars, no nets and nothing anybody sheltered in: what reaches a cave is a
	# drill at a face, the pipe they ran to it, the survey they ran it along, and
	# the graves of whoever was carried down to work it.
	GenWorks.register(&"limestone_caves", {
		"works": &"",
		"vignettes": [[5, &"drill"], [4, &"pipe_run"], [4, &"debris_field"], [3, &"survey_posts"],
			[3, &"grave_cluster"], [3, &"wreck_parts"], [1, &"tipped_signs"]],
		"survey": [[0.4, &"pipe_line"]],
	})
	return d


## The floor of a hall, as a composition rather than a noise field: dark stone
## almost everywhere, pale flowstone massing on the rises and along the water,
## breakdown at the foot of every face, clay in the hollows.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		# The edge of the flooded bottom: silt where it is sheltered, washed
		# gravel where the water works at it.
		return Ground.SAND if gb > 0.25 else Ground.GRAVEL
	if f & BiomeSurface.APRON != 0:
		# Breakdown: what came off the roof, heaped at the wall.
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0:
		# Gour rims stand along every stream, where the lime came out of it.
		return Ground.BONE
	# Flowstone comes down the rises and lies in sheets across the high side of a
	# hall: the mass field decides where a curtain hangs, so it draws as long
	# shapes and never as specks (docs/LOOK.md: grounds are washes).
	if gb > 0.40 and rs > -0.25:
		return Ground.BONE
	if rs > 0.55:
		return Ground.BONE
	if rs > 2.1 or e > 10.5:
		# The bare roof-fall ridges between galleries.
		return Ground.ROCK
	if rs < -1.05 and gb < -0.1:
		return Ground.MUD
	if gb < -0.55:
		return Ground.GRAVEL
	return Ground.LIMESTONE


## Columns and fallen blocks. Everything else — the clints in the pavement, the
## ore in a broken face, the boulders in the breakdown — is what every landscape
## reads the same way (BiomeScatter.shared), and this landscape's own ore table
## is what makes it worth the walk down.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.BONE:
		# Flowstone standing up: a stalagmite where a drip has been landing for
		# ten thousand years, and a column where it met the roof.
		var k := maxf(0.0, t.clump[i])
		if r < 0.035 + k * 0.16:
			return PropKind.STANDING_STONE
		if r < 0.055 + k * 0.16:
			return PropKind.BOULDER
		return BiomeScatter.NONE
	if g == Ground.LIMESTONE:
		# The hall floor is a floor, not a boulder field: the shared pavement
		# reads a limestone tile as the bonelands' open grike country and puts
		# clints on a quarter of it, which at this zoom is rubble wall to wall.
		# Down here the blocks gather instead, and the floor between them is what
		# the eye reads the hall by.
		var k := maxf(0.0, t.clump[i])
		if r < 0.012 + k * 0.05:
			return PropKind.CLINTS
		if r < 0.020 + k * 0.05:
			return PropKind.BOULDER
		if r > 0.30 and r < 0.302:
			return PropKind.STANDING_STONE
		# Seams show where the floor is broken.
		return BiomeScatter.ore(t.own_def, (r - 0.5) * 1.5) if r > 0.5 else BiomeScatter.NONE
	if g == Ground.MUD:
		# The carried-off, and what the machines dropped getting them out.
		if r < 0.008:
			return PropKind.BONES
		if r < 0.013:
			return PropKind.DEBRIS
		# The pipe they ran down here is laid as RUNS by the works stage
		# (`pipe_run` and the `pipe_line` survey in this file's GenWorks row), not
		# dealt a piece at a time here: see `GenWorks.RUNS`.
		return BiomeScatter.NONE
	return BiomeScatter.PASS
