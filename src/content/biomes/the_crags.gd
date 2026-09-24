## The Crags: fog on old stone, and ruins older than anything the machines built.
## Something is here that neither they nor the aliens have a file on. Owner's own,
## 2026-09-18: "a foggy crag land of ancient human ruins where myth and wonder
## still remain haunted by an unknown force even to the aliens and the machines".
##
## WHAT IT ARGUES WITH, and it is the only landscape that argues with the STORY
## rather than with the terrain. Everything else in this world is explained: the
## machines did it, the plan wants it, a person built it and left. This place is
## the one the explanation does not reach — and the two powers that between them
## can kill stars (docs/STORY.md) do not know what is in it either. That is
## worth more than another palette, because it is the only ground where a player
## can be told nothing and be right to be afraid.
##
## SO THE MACHINES ARE THIN HERE ON PURPOSE. The lightest roster of any surface
## landscape, no depot worth the name, and what is standing is old: the plan
## surveyed it, found nothing it wanted, and the survey posts are still up.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"the_crags"
	d.display_name = "the crags"
	d.order = 20
	d.style_note = "Wet grey rock in fog, stone that was cut by hand, and no machine light anywhere."
	d.share = Vector2(0.085, 0.14)
	d.anchors = [{"seq": 20, "u": 0.14, "v": 0.6}]
	d.temp_range = Vector2(0.15, 0.5)
	d.moist_range = Vector2(0.55, 1.0)
	d.adjacency = {&"moss": 0.3, &"pinewood": 0.25, &"bonelands": 0.25}
	d.coastal = 0.2
	# Broken, steep and high: crags rather than hills, with the valleys between
	# them deep enough to hold the fog all day.
	d.relief = {
		&"base": 11.0, &"hills": 8.0, &"ridge": 4.0, &"near": 8.5, &"terrace": 0.55, &"valley": 2.8,
		&"rain": 1.3, &"temp": 0.14, &"moist": 0.75, &"cliff": 0.85,
	}
	d.border_elevation = 2.0
	d.reach_out_high = Vector4(6.0, 0.11, 0.13, 0.4)
	d.reach_in_low = Vector3(5.5, 0.09, 0.32)
	d.hatch = Ink.SPARSE
	d.grounds = {
		Ground.ROCK: P.SLATE[3].lerp(P.MOSS[2], 0.2),
		# LICHEN ON OLD STONE, not fen. This was `P.MOSS[2].lerp(P.SPRUCE[2], 0.45)`,
		# which sat 0.0078 from the Moss's own moss -- near enough that the two
		# landscapes drew the same turf, and the fen is what moss SHOULD look like.
		# The crags are fog on old stone, so its moss is what grows ON that stone:
		# paler, greyer, drier.
		Ground.MOSS: P.MOSS[2].lerp(P.STONE[3], 0.55),
		Ground.HEATH: P.MOSS[2].lerp(P.EARTH[2], 0.4),
		Ground.GRASS: P.MOSS[3].lerp(P.SPRUCE[2], 0.3),
		Ground.SCREE: P.SLATE[2].lerp(P.STONE[2], 0.4),
		Ground.PEAT: P.EARTH[2].lerp(P.SPRUCE[1], 0.4),
		Ground.LIMESTONE: P.STONE[3].lerp(P.MOSS[2], 0.25),
	}
	# Grounds this place never lays, named anyway: anything left unnamed falls
	# through to the shared table, which is the COAST's and is far brighter than
	# here, so it would arrive as the loudest object in the frame. Each takes this
	# landscape's own limestone, because they only have to be in key.
	for g: int in [Ground.BONE, Ground.GRAVEL, Ground.ICE, Ground.PAN, Ground.SALT, Ground.SAND, Ground.SHINGLE, Ground.SNOW]:
		d.grounds[g] = d.grounds[Ground.LIMESTONE]
	d.cliff_wash = P.SLATE[2].lerp(P.MOSS[2], 0.3)
	d.strata = GroundColors.STRATA_MOSS
	d.plain_ground = Ground.MOSS
	d.bank_ground = Ground.PEAT
	d.pool_rim_ground = Ground.PEAT
	d.village_ground = Ground.GRASS
	d.decor = {Ground.MOSS: [0.85, Decor.TUFT, 30, Decor.CROTTLE, 18, Decor.BOG_COTTON, 8]}
	d.grass_colors = [P.MOSS[2], P.SPRUCE[2]]
	d.rock_color = P.SLATE[3]
	d.decor_tints = {&"fronds": [P.MOSS[2], P.SPRUCE[2], P.EARTH[2]]}
	# Stone cut by hand, lichen over everything, and timber that went black rather
	# than grey because it has never once been dry.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[3], P.STONE[3], P.MOSS[2]]
	dress.walling = [P.SLATE[2], P.STONE[3], P.MOSS[2], P.SPRUCE[2]]
	dress.timber = [P.SPRUCE[1], P.SLATE[2]]
	dress.sink = 0.18
	dress.lie = Vector2(-0.08, 0.12)
	# The patched shelter here is turf over stone: a small dry-stone round with
	# a plate sheet weighted onto its roof (props/crags.gd), never a shack of
	# boards, because there is no timber that was ever dry.
	dress.shelter = &"roundhouse"
	d.dressing = dress
	# What its people BUILT (docs/LANDSCAPES.md PEOPLE): three forms, none of
	# them lit, so this is the one village with no stolen neon, and the stock's
	# own size is the village -- three buildings, few people and old ones,
	# living in what was already standing. Declaring `built` is TERRAIN
	# (WorldStamp): it moves this landscape's island, and that is intended.
	d.built = BiomeForms.new()
	d.built.stock = [&"roundhouse", &"lean_to_broch", &"byre"] as Array[StringName]
	d.built.plan = &"ring"
	d.grade = Vector4(-0.04, 0.02, 0.04, 0.0)
	# THE DARKEST NIGHT IN THE GAME, and nothing of the machines' lights it. This
	# is the one place where a lantern is the only light there is.
	d.night_sky = 0.55
	d.props = [PropKind.STANDING_STONE, PropKind.CAIRN, PropKind.RUIN, PropKind.BOULDER,
		PropKind.CLINTS, PropKind.GRAVE, PropKind.MEMORIAL, PropKind.BUSH,
		PropKind.DEAD_TREE, PropKind.STONE_ORE]
	d.ore = [[PropKind.STONE_ORE, 0.028], [PropKind.IRON_ORE, 0.012]]
	d.sites = {"stone_circles": 3, "ruins": true, "summit": 1}
	d.beached_wrecks = false
	d.pools = {"order": 2, "cell": 28, "chance": 0.5, "r_min": 2.0, "r_max": 4.4, "ground": Ground.BLACKWATER}
	d.villages = 1
	d.village_order = 20
	d.village_names = ["Cairnwell", "Thin Ford"]
	# Still the foggiest place there is, and clear is still its rarest weather --
	# but 6 of 100 meant a player could cross it and never once see it. A day the
	# fog lifts is what makes the fog mean something.
	d.weather = [
		[Weather.FOG, 30, 0.0], [Weather.GREY, 24, 0.0], [Weather.RAIN, 20, 0.55],
		[Weather.CLEAR, 16, 0.0], [Weather.DRIZZLE, 10, 0.0],
	]
	# The foggiest place there is: it is what the landscape is FOR.
	d.mist = 0.55
	# Wet and dark and nothing else — no machine exhaust, no spores, no glare.
	# What is dangerous here is not a pressure, which is exactly the point.
	#
	# NOT `resonance`, though it is in `Hazards.IDS` and the spec asks for it
	# (docs/LANDSCAPES.md: "resonance 0.3 near stones only"). Declared here it
	# would press the whole landscape, every tile of moss and every bottom of
	# peat, and the stones' hum is the one mechanical trace of the unknown force:
	# it belongs to the standing stones and the carved faces and to nothing
	# else. That wants a per-prop hazard source ("within R adds H", the shared
	# systems list in docs/LANDSCAPES.md), which another builder is making, and
	# the fork that answers it (`mod_fork`) does not exist yet either. When both
	# land, the stones declare it and this line stays as it is.
	d.hazards = {&"wet": 0.5, &"dark": 0.45}
	# THE THINNEST ROSTER OF ANY SURFACE LANDSCAPE. The plan surveyed this place,
	# found nothing it wanted, and left. What a player meets here is the land.
	d.roster = {
		&"watcher": {"weight": 0.5, "hours": Vector2(8, 18)},
		&"dog.feral": {"weight": 0.8},
		# The survey's chainman, by day, on the survey's own grounds (Roster
		# `where`): the one machine here still working, and what it does is measure.
		&"chainman": {"weight": 1.2, "hours": Vector2(8, 18)},
	}
	d.landmarks = [&"cast_stones", &"firewatch", &"leaning_mast", &"clerks_office"]
	# Its keeper: the plumb, a survey instrument that never finished surveying
	# (src/core/sentinel/designs/plumb.gd). The one machine that stays, because
	# it cannot file what it found and will not leave until it has.
	d.sentinel = &"plumb"
	d.sound_bed = &"bed_wind"
	d.surface = _surface
	d.scatter = _scatter
	# The web's day contrast here (BiomeDef.web_contrast): inferred from the bonelands: bright rock.
	d.web_contrast = 1.1
	return d


## Bare rock on everything steep, moss over everything that holds water, and peat
## in the bottoms where it never drains. One field and one steep test.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SHINGLE
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0:
		return Ground.PEAT
	if rs > 1.4:
		return Ground.ROCK
	if e <= 6.0:
		return Ground.PEAT
	return Ground.MOSS


## Thorn in the sheltered pockets and nothing on the tops, which is what wind and
## seventy years of nobody cutting it leaves.
## WHAT IS STANDING HERE IS OLDER THAN THE MACHINES, and that is the whole of
## this landscape. It declared ten kinds and placed ONE — a bush, on moss, at
## three per cent — so the standing stones, the cairns and the graves that are
## the entire idea of the Crags existed in `props` and never in the ground
## between the landmarks. A declaration is not the act.
##
## Keyed to the grounds this file actually lays, because that is what makes a
## place read as itself rather than as a spread of its own prop list: the
## LIMESTONE is the pavement showing through and carries clints, the ROCK is
## what broke off it, the MOSS and HEATH are the thin soil people buried into,
## and the SCREE carries only what rolled down.
##
## The rare things are windowed rather than thresholded (`r > a and r < b`), so
## a standing stone is one in a few hundred tiles instead of a third of a
## hillside — a monument that is common is scenery.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.MOSS:
		if r < 0.030:
			return PropKind.BUSH
		if r > 0.30 and r < 0.3075:
			return PropKind.CAIRN
		if r > 0.50 and r < 0.5055:
			return PropKind.STANDING_STONE
		return PropKind.GRAVE if r > 0.70 and r < 0.7035 else BiomeScatter.NONE
	if g == Ground.LIMESTONE:
		if r < 0.085:
			return PropKind.CLINTS
		return PropKind.STANDING_STONE if r > 0.60 and r < 0.609 else BiomeScatter.NONE
	if g == Ground.ROCK:
		if r < 0.042:
			return PropKind.BOULDER
		if r < 0.056:
			return PropKind.CLINTS
		if r < 0.066:
			return PropKind.STONE_ORE
		return PropKind.RUIN if r > 0.80 and r < 0.8055 else BiomeScatter.NONE
	if g == Ground.HEATH or g == Ground.GRASS:
		if r < 0.028:
			return PropKind.BUSH
		if r < 0.038:
			return PropKind.DEAD_TREE
		return PropKind.MEMORIAL if r > 0.55 and r < 0.5535 else BiomeScatter.NONE
	if g == Ground.PEAT:
		return PropKind.BUSH if r < 0.020 else BiomeScatter.NONE
	if g == Ground.SCREE:
		return PropKind.BOULDER if r < 0.030 else BiomeScatter.NONE
	return BiomeScatter.NONE
