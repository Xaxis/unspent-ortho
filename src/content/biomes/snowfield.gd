## Snowfield: the page itself. Drifts with a blue lee, pylons strung with wire,
## soot in the lee of everything the machines still run up here.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"snowfield"
	d.display_name = "snowfield"
	d.order = 3
	d.style_note = "Line-dominant, minimal fill; the white is paper, the shade is blue."
	d.share = Vector2(0.11, 0.15)
	d.anchors = [
		{"seq": 6, "u": 0.3, "v": 0.19},
		{"seq": 9, "u": 0.1, "v": 0.34, "chance": 0.5},
	]
	d.temp_range = Vector2(0.0, 0.25)
	d.moist_range = Vector2(0.3, 0.7)
	d.adjacency = {&"pinewood": 0.3, &"bonelands": 0.1}
	d.coastal = -0.5
	d.relief = {
		&"base": 7.8, &"hills": 3.0, &"ridge": 6.5, &"terrace": 0.2, &"valley": 0.85,
		&"rain": 1.1, &"temp": 0.08, &"moist": 0.5, &"cliff": 0.3,
	}
	# Snow takes the high ground: the lie of the land moves its border.
	d.border_elevation = 2.4
	# It creeps out only down the ridges, and its valleys let the neighbour in.
	d.reach_out_high = Vector4(6.5, 0.1, 0.12, 0.45)
	d.reach_in_low = Vector3(6.0, 0.08, 0.3)
	d.hatch = Ink.SPARSE
	d.grounds = {
		Ground.ROAD: P.ASH[3].lerp(P.EARTH[3], 0.35),
		Ground.SAND: P.SAND[4].lerp(P.RIME[4], 0.45),
		Ground.SHINGLE: P.STONE[3].lerp(P.RIME[3], 0.3),
		# Frost-bitten turf between drifts.
		Ground.GRASS: P.MOSS[3].lerp(P.ASH[3], 0.55),
		Ground.HEATH: P.EARTH[2].lerp(P.ASH[2], 0.5),
		Ground.MOSS: P.SPRUCE[2].lerp(P.ASH[3], 0.4),
		Ground.NEEDLES: P.EARTH[2].lerp(P.ASH[3], 0.35),
		Ground.SNOW: P.RIME[5],
		Ground.ROCK: P.SLATE[3].lerp(P.RIME[3], 0.4),
	}
	d.cliff_wash = P.SLATE[2].lerp(P.RIME[2], 0.5)
	d.strata = GroundColors.STRATA_SNOW
	d.plain_ground = Ground.SNOW
	d.bank_ground = Ground.SNOW
	d.pool_rim_ground = Ground.GRAVEL
	d.rivers_freeze = true
	d.village_ground = Ground.SNOW
	d.decor = {Ground.GRASS: [0.7, Decor.SNOW_TUFT, 30, Decor.TUFT, 20, Decor.CROTTLE, 6]}
	d.grass_colors = [P.ASH[3], P.LINEN[3]]
	d.rock_color = P.SLATE[3]
	d.decor_tints = {&"fronds": [P.EARTH[2], P.EARTH[1], P.ASH[2]]}
	d.grade = Vector4(-0.04, 0.08, 0.08, -0.03)
	d.lip_snow = true
	d.props = [PropKind.SNOW_PINE, PropKind.DEAD_TREE, PropKind.BOULDER, PropKind.STONE_ORE,
		PropKind.IRON_ORE, PropKind.TIN_ORE, PropKind.DRIFTWOOD, PropKind.WRACK, PropKind.MUSSEL_ROCK]
	d.ore = [[PropKind.STONE_ORE, 0.014], [PropKind.IRON_ORE, 0.026], [PropKind.TIN_ORE, 0.034]]
	d.sites = {"tips": 2, "summit": 1}
	d.beached_wrecks = false
	d.pools = {"order": 2, "cell": 30, "chance": 0.5, "r_min": 2.6, "r_max": 4.8, "ground": Ground.ICE}
	d.villages = 1
	d.village_order = 5
	d.village_names = ["Whitecrag", "Hush Fold"]
	# Bright flat days, snow in squalls, whiteouts that take the horizon.
	d.weather = [
		[Weather.CLEAR, 30, 0.0], [Weather.GREY, 18, 0.0], [Weather.SNOW, 28, 0.65],
		[Weather.HAIL, 6, 0.5], [Weather.BLIZZARD, 10, 0.3], [Weather.WHITEOUT, 8, 0.0],
	]
	d.mist = 0.12
	d.hazards = {&"cold": 0.7}
	d.roster = {
		&"lineman": {"weight": 1.0},
		&"dog.yard": {"weight": 1.0}, &"dog.feral": {"weight": 1.0},
		&"gulls": {"weight": 1.0, "hours": Vector2(6, 20)},
	}
	d.sound_bed = &"bed_snowfield"
	d.surface = _surface
	d.scatter = _scatter
	return d


static func _surface(t: BiomeSurface) -> int:
	var i := t.i
	var gb := t.big[i]
	if t.shore:
		return Ground.ICE if gb > 0.15 else Ground.SHINGLE
	if t.apron:
		return Ground.SCREE
	if t.bank:
		return Ground.GRAVEL
	var e := t.elev[i]
	var rs := t.rise[i]
	if (e >= 11.5 and gb > 0.35) or rs > 1.8 + gb * 0.8:
		# Wind strips the crests to rock.
		return Ground.ROCK
	if rs < -0.85 and e < 5.5 and gb < 0.1:
		return Ground.GRAVEL
	return Ground.SNOW


static func _scatter(t: BiomeScatter) -> int:
	if t.ground == Ground.GRASS:
		return PropKind.SNOW_PINE if t.roll < 0.02 else BiomeScatter.NONE
	return BiomeScatter.PASS
