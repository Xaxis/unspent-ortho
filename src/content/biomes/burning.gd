## Burning: ash, clinker, vents and basalt round a caldera, with the refineries
## and slag runs the machines put in it still working. Warm low light even at
## noon, and a glow from below at night.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"burning"
	d.display_name = "burning"
	d.order = 5
	d.style_note = "Jagged burnt edges, restless broken strokes, ember glints unhatched."
	d.share = Vector2(0.11, 0.15)
	d.anchors = [
		{"seq": 7, "u": 0.73, "v": 0.2},
		{"seq": 10, "u": 0.9, "v": 0.36, "chance": 0.5},
	]
	d.temp_range = Vector2(0.8, 1.0)
	d.moist_range = Vector2(0.0, 0.25)
	d.adjacency = {&"bonelands": 0.2}
	d.coastal = -0.4
	d.relief = {
		&"base": 4.6, &"hills": 2.0, &"ridge": 1.8, &"near": 3.5, &"terrace": 0.25, &"valley": 0.7,
		&"rain": 0.12, &"temp": 0.95, &"moist": 0.08, &"cliff": 0.2,
	}
	d.caldera = 30.0
	d.scorched = true
	# Ash drifts out thin, and thinner with every tile from the rim; little that
	# is not burnt survives inside it.
	d.reach_out_thin = 0.28
	d.reach_in_thin = 0.7
	d.hatch = Ink.SCRIBBLE
	d.grounds = {
		# A track trodden through the ash, darker and browner than the drifts.
		Ground.ROAD: P.ASH[2].lerp(P.EARTH[2], 0.45),
		Ground.SAND: P.SAND[3].lerp(P.ASH[2], 0.5),
		Ground.SHINGLE: P.STONE[1],
		Ground.GRAVEL: P.STONE[1],
		# Scorched: what grass is left near the burning.
		Ground.GRASS: P.EARTH[3].lerp(P.ASH[2], 0.5),
		Ground.HEATH: P.EARTH[1],
		Ground.MOSS: P.MOSS[1].lerp(P.ASH[1], 0.4),
		Ground.NEEDLES: P.EARTH[1],
		Ground.SNOW: P.RIME[4].lerp(P.ASH[3], 0.55),
		Ground.BONE: P.LINEN[3].lerp(P.ASH[3], 0.5),
		Ground.LIMESTONE: P.LINEN[3].lerp(P.ASH[3], 0.5),
		Ground.SCREE: P.STONE[1],
		Ground.ROCK: P.STONE[1].lerp(P.ASH[1], 0.5),
	}
	d.cliff_wash = P.STONE[0]
	d.strata = GroundColors.STRATA_BASALT
	d.plain_ground = Ground.ASH
	d.bank_ground = Ground.ASH
	d.rock_ground = Ground.CLINKER
	d.village_ground = Ground.ASH
	d.decor = {Ground.GRASS: [0.6, Decor.TWIG, 20, Decor.ASH_FLAKE, 30, Decor.TUFT, 12, Decor.CINDER, 10]}
	d.grass_colors = [P.EARTH[3], P.ASH[2]]
	d.rock_color = P.STONE[1]
	d.hard_rock = true
	d.decor_tints = {&"bloom": [P.BLOOM[1], P.BLOOM[2], P.ASH[3]], &"fronds": [P.EARTH[2], P.EARTH[1], P.ASH[2]], &"twig": [P.INK[2]]}
	# Basalt, ash banked against everything, and the rest taken from `scorched`:
	# charred timber, ash-bleached bone, blackened plate, a dugout for a shelter
	# and nothing that keeps a leaf.
	var dress := BiomeDressing.new()
	dress.stone = [P.STONE[1], P.STONE[0], P.RUST[2]]
	dress.drift = [P.ASH[2], P.ASH[1]]
	dress.walling = [P.STONE[1], P.ASH[1], P.STONE[2], P.STONE[0]]
	dress.sink = 0.14
	dress.lie = Vector2(-0.09, 0.17)
	d.dressing = dress
	d.grade = Vector4(-0.42, -0.04, -0.15, 0.1)
	# The Burning is lit from BELOW at night — vents, clinker, what is still
	# alight — and its sky is thick with ash. A bright night sky on top of that
	# would take the fires' own light off it, which is the whole picture here.
	d.night_sky = 0.90
	d.props = [PropKind.DEAD_TREE, PropKind.BOULDER, PropKind.STONE_ORE, PropKind.COAL_ORE,
		PropKind.COPPER_ORE, PropKind.IRON_ORE, PropKind.BONES, PropKind.VENT,
		PropKind.DRIFTWOOD, PropKind.MUSSEL_ROCK]
	d.ore = [[PropKind.STONE_ORE, 0.02], [PropKind.COAL_ORE, 0.05], [PropKind.COPPER_ORE, 0.068],
		[PropKind.IRON_ORE, 0.085]]
	d.sites = {"tips": 2, "ruins": true, "fumaroles": 4, "summit": 5}
	d.tip_ground = Ground.CLINKER
	d.beached_wrecks = false
	d.villages = 1
	d.village_order = 7
	d.village_names = ["Cinderstead", "Emberlow"]
	# Heat, ash fall and a furnace haze that lies in the low ground.
	d.weather = [
		[Weather.CLEAR, 22, 0.0], [Weather.HEAT, 16, 0.0], [Weather.GREY, 10, 0.0],
		[Weather.ASH, 30, 0.35], [Weather.HAZE, 22, 0.0],
	]
	# Fumes sit just under BITE (0.55) on purpose: the air is always noticed and
	# only unbreathable when the ash falls, which adds 0.35 x its strength and so
	# bites from ash 0.14 up — the commonest weather above. That is the day a
	# respirator earns its slot. Heat is the sun's, and falls under BITE after dark.
	d.hazards = {&"heat": 0.7, &"fumes": 0.5}
	d.roster = {&"clerk": {"weight": 1.0}}
	# The places worth the walk it holds (docs/VISION.md §3, src/core/landmarks):
	# what a player crosses this landscape FOR. Its own file is the authority;
	# `Landmarks.problems` fails if a kind here does not name this landscape back.
	d.landmarks = [&"blinking_stack", &"evaporator", &"clerks_office"]
	d.sound_bed = &"bed_burning"
	d.surface = _surface
	d.scatter = _scatter
	return d


static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	var g := Ground.ASH
	if f & BiomeSurface.SHORE != 0:
		g = Ground.CLINKER if gb > 0.0 else Ground.SHINGLE
	elif f & BiomeSurface.APRON != 0:
		g = Ground.SCREE
	elif t.flow > 0.65 - (0.1 if t.rim_dist < t.crater * 0.8 else 0.0) + maxf(0.0, t.heart_dist - t.crater * 3.0) * 0.004:
		g = Ground.CLINKER
	elif absf(t.rim_dist - t.crater) < 2.5 + gb * 3.0:
		g = Ground.ROCK
	elif e >= 9.0 and gb > 0.3:
		g = Ground.ROCK
	if t.own_def.id != &"burning" and g != Ground.SCREE:
		# Only the ash travels.
		return Ground.ASH
	return g


static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.ASH:
		var k := maxf(0.0, t.clump[i] - 0.1)
		if absf(t.fissure[i]) < 0.035 and r < 0.2:
			# Vents breathe in rows along the fissures.
			return PropKind.VENT
		if r < 0.01 + k * 0.9:
			# Burnt groves stand together; between them, open ash.
			return PropKind.DEAD_TREE
		if r < 0.024 + k * 0.9:
			return PropKind.BOULDER
		return PropKind.BONES if r > 0.49 and r < 0.492 else BiomeScatter.NONE
	return BiomeScatter.PASS
