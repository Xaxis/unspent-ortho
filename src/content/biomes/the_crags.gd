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
	d.spoken_in = "up in the crags"
	d.order = 20
	d.style_note = "Wet grey rock in fog, stone that was cut by hand, and no machine light anywhere."
	d.share = Vector2(0.085, 0.14)
	d.anchors = [{"seq": 20, "u": 0.14, "v": 0.6}]
	d.temp_range = Vector2(0.15, 0.5)
	d.moist_range = Vector2(0.55, 1.0)
	d.adjacency = {&"moss": 0.3, &"pinewood": 0.25, &"bonelands": 0.25}
	d.coastal = 0.2
	# Broken, steep and high: crags rather than hills, with the valleys between
	# them deep enough to hold the fog all day. Tall land on a two-level terrace
	# climbs as a stair of equal treads, so the steps here are cliffs of three to
	# eight levels (`shelf`, `shelf_var`) between shelves flat enough to stand on.
	d.relief = {
		&"base": 11.0, &"hills": 8.0, &"ridge": 4.0, &"near": 8.5, &"terrace": 0.85, &"valley": 2.8,
		&"rain": 1.3, &"temp": 0.14, &"moist": 0.75, &"cliff": 0.85, &"shelf": 3.5, &"shelf_var": 0.7,
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
	# ITS OWN FACES (GroundColors.STRATA_CRAG): gritstone in joint-bounded blocks,
	# lichened and streaked with water. It was the moss's peat bank, and a crag is
	# the one thing a bog is not. A LOOK field: no seed moves.
	d.strata = GroundColors.STRATA_CRAG
	d.plain_ground = Ground.MOSS
	d.bank_ground = Ground.PEAT
	d.pool_rim_ground = Ground.PEAT
	d.village_ground = Ground.GRASS
	# On the lichened ground, stones: some of them carved, by hands older than any
	# the machines have a file on (Decor.CUP_RING), and the rest lichened.
	d.decor = {
		Ground.MOSS: [0.85, Decor.TUFT, 30, Decor.CROTTLE, 18, Decor.BOG_COTTON, 8, Decor.CUP_RING, 3, Decor.LICHEN, 8],
		Ground.ROCK: [0.5, Decor.LICHEN, 30, Decor.CUP_RING, 6, Decor.STONE, 20],
	}
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
	# The old stones' cut rings give off a pale cold light after dark, and nothing
	# the machines or anyone else runs reaches them.
	dress.old_light = Color(0.62, 0.84, 0.86, 1.0)
	d.dressing = dress
	# What its people BUILT (docs/LANDSCAPES.md PEOPLE): three forms, none of
	# them lit, so this is the one village with no stolen neon, and the stock's
	# own size is the village -- three buildings, few people and old ones,
	# living in what was already standing. Declaring `built` is TERRAIN
	# (WorldStamp): it moves this landscape's island, and that is intended.
	d.built = BiomeForms.new()
	d.built.stock = [&"roundhouse", &"lean_to_broch", &"byre"] as Array[StringName]
	d.built.plan = &"ring"
	# Only the roundhouse is anyone's home: the broch's lean-to and the byre are
	# for beasts and weather. Its room is its own (content/interiors/roundhouse.gd).
	d.interiors = {&"form:roundhouse": &"roundhouse", &"house": &"home"}
	# Behind the other forms, the byre keeper, whose beast sleeps under the same
	# roof, and the waller who keeps the drystone standing.
	d.home = {"households": {
		&"byrer": {"wants": [&"stall", &"hay_rack", &"buckets", &"creel"],
			"by_hearth": [{"kind": &"chair", "off": 1.25, "solid": 0.25, "side": 1.0}]},
		&"waller": {"wants": [&"mason_rack", &"creel", &"basket", &"shelf"], "by_hearth": []},
	}}
	d.grade = Vector4(-0.04, 0.02, 0.04, 0.0)
	# THE DARKEST NIGHT IN THE GAME, and nothing of the machines' lights it. This
	# is the one place where a lantern is the only light there is.
	# Lichen and a little moss on what was built of its stone; the wind keeps ivy off.
	# (BiomeDef.overgrowth: lighter than the green towers' whole dose.)
	d.overgrowth = 0.25
	d.night_sky = 0.55
	d.props = [PropKind.STANDING_STONE, PropKind.CAIRN, PropKind.RUIN, PropKind.BOULDER,
		PropKind.CLINTS, PropKind.GRAVE, PropKind.MEMORIAL, PropKind.BUSH,
		PropKind.DEAD_TREE, PropKind.STONE_ORE,
		# Its own (docs/LANDSCAPES.md §1): the trilithon, the face in the boulder
		# and the sunken lane are `_scatter`'s; the sighting mast and the core
		# rack are the survey bench's (`_works`).
		PropKind.LINTEL, PropKind.CARVED_FACE, PropKind.HOLLOW_WAY,
		PropKind.THEODOLITE_MAST, PropKind.CORE_RACK]
	d.ore = [[PropKind.STONE_ORE, 0.028], [PropKind.IRON_ORE, 0.012]]
	# The barrow (SiteKinds): a mound with a cairn, a trilithon at its mouth and
	# the dead round it, claimed as a rate per 1,000 tiles of each region.
	d.sites = {"stone_circles": 3, "ruins": true, "summit": 1, "barrow": 0.12}
	# The force nobody has a file on lives in these circles (docs/HUSH.md).
	d.hush = true
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
	# Its fog is its own wet pale grey, the colour the far land goes to (Air), and it
	# lies in the ruins' hollows and between the stones rather than over them.
	d.weather_style = {&"fog": {"air": Color(0.70, 0.74, 0.76), "low": 0.5}}
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
		&"watcher": {"hours": Vector2(8, 18)},
		&"dog.feral": {},
		# The survey's chainman, by day, on the survey's own grounds (Roster
		# `where`): the one machine here still working, and what it does is measure.
		&"chainman": {"hours": Vector2(8, 18)},
	}
	d.landmarks = [&"cast_stones", &"firewatch", &"leaning_mast", &"clerks_office"]
	# Its keeper: the plumb, a survey instrument that never finished surveying
	# (src/core/sentinel/designs/plumb.gd). The one machine that stays, because
	# it cannot file what it found and will not leave until it has.
	d.sentinel = &"plumb"
	d.sound_bed = &"bed_wind"
	d.surface = _surface
	d.scatter = _scatter
	# The survey that never closes (docs/LANDSCAPES.md §1 PLAN): a bench in every
	# region big enough to keep the plumb, laid by `_works` below.
	GenWorks.register(&"the_crags", {"host": load("res://src/content/biomes/the_crags.gd"), "works": &"_works"})
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
	# The pavement showing through on the shoulders below the bare faces: the
	# ground the clints are keyed to (`_scatter`), which nothing laid until now
	# (docs/LANDSCAPES.md §1, "Lay LIMESTONE where rs is between 0.9 and 1.4").
	if rs > 0.9:
		return Ground.LIMESTONE
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
		# A trilithon fallen in the lichen, and a lane sunk between two banks:
		# each about one in three frames, windowed so a monument stays rare.
		if r > 0.40 and r < 0.4036:
			return PropKind.LINTEL
		if r > 0.50 and r < 0.5055:
			return PropKind.STANDING_STONE
		if r > 0.60 and r < 0.6040:
			return PropKind.HOLLOW_WAY
		return PropKind.GRAVE if r > 0.70 and r < 0.7035 else BiomeScatter.NONE
	if g == Ground.LIMESTONE:
		if r < 0.085:
			return PropKind.CLINTS
		if r > 0.40 and r < 0.4060:
			return PropKind.LINTEL
		return PropKind.STANDING_STONE if r > 0.60 and r < 0.609 else BiomeScatter.NONE
	if g == Ground.ROCK:
		if r < 0.042:
			return PropKind.BOULDER
		if r < 0.056:
			return PropKind.CLINTS
		if r < 0.066:
			return PropKind.STONE_ORE
		# A face cut into a boulder before anybody here kept records, and the
		# hushstone it is cut from (Takes).
		if r > 0.30 and r < 0.307:
			return PropKind.CARVED_FACE
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


## THE SURVEY BENCH (docs/LANDSCAPES.md §1 PLAN): a ruled lattice of core holes
## cut into the lichen along the bearing, a sighting mast at each corner, the
## cores it pulled racked down the middle, posts at the ends and one sign. The
## only ruled thing in the landscape, and it reads from across a valley.
##
## THE PLUMB DENS AT ITS REGION'S BENCH and starves on what stands there
## (designs/plumb.gd feeds: masts and racks), so every region big enough to keep
## it gets one (`GenWorks._n_station`), on the flattest ground it holds where a
## den by it keeps the plumb's ways (`GenWorks.flattest`: darts never found flat
## ground here), and every bench holds FED of them or is taken back whole.
const FED := SentinelWay.FEEDS_LEAST + 1
## How many of a region's flattest squares a bench is tried on, and how many
## the station rule is asked of per bench tried.
const BENCH_TRIES := 6
const BENCH_ASKS := 4
## What a bench is ruled on: the lichen and the pavement, else the bare rock.
## Never the peat, where the plumb founders.
const BENCH_FLOORS: Array = [Ground.MOSS, Ground.LIMESTONE]
const BENCH_BARE: Array = [Ground.ROCK, Ground.SCREE]


static func _works(L: Object) -> void:
	var benches := 0
	for n in GenWorks._n_station(L, 1.0):
		# A bench whose larder, once laid, leaves the plumb no den that keeps its
		# ways is taken back, and the next flattest is tried: on the lichen and
		# the pavement first, then on the bare rock and scree. Seed 90210's second
		# crags held five flat squares of the first, all one shelf, and none kept
		# a den.
		for floors: Array in [BENCH_FLOORS, BENCH_BARE]:
			if _bench_on(L, floors, BENCH_APART, BENCH_VILLAGE):
				benches += 1
				break
	# A region that holds no bench yet tries again at half the spacing, then at
	# BENCH_APART_LAST, so no bench that stands moves.
	if benches == 0 and GenWorks._n_station(L, 1.0) > 0:
		for apart: float in [BENCH_APART * 0.5, BENCH_APART_LAST]:
			if _bench_on(L, BENCH_FLOORS + BENCH_BARE, apart, BENCH_VILLAGE * 0.5):
				break


## How far a bench keeps from the region's other places and from a village.
const BENCH_APART := 30.0
const BENCH_VILLAGE := 18.0
## How far the last bench a region tries keeps from its other places: a place
## laid before the works can crowd every flat square of a small region, and
## 90210's 464 tiles of crags had all 25 within 7.6-10.6 of one stone circle.
## A bench beside a stone circle is a fine sight on the crags.
const BENCH_APART_LAST := 7.5


## A bench on the flattest of `floors` that stands, `apart` from other places
## and `village` from a village (`GenWorks.flattest`); whether one did. The
## whole station rule is asked of the squares in order, BENCH_ASKS of them per
## bench tried, and the asking stops at the first bench that stands.
static func _bench_on(L: Object, floors: Array, apart: float, village: float) -> bool:
	var tried := 0
	for p: Vector2i in GenWorks.flattest(L, 5, floors, apart, true, BENCH_TRIES * BENCH_ASKS, 0.35, village):
		var at := Vector2(p) + Vector2(0.5, 0.5)
		if not GenWorks.station_holds(L, at):
			continue
		if GenWorks._work(L, &"_bench", at):
			return true
		tried += 1
		if tried >= BENCH_TRIES:
			break
	return false


## One bench at `at` (`GenWorks._work`). Each mast and rack takes the nearest
## foothold a step off level (`GenWorks.put_on_step`): there is no flat ground in
## the crags to rule one on, and the lattice is the ground's mark (the bores),
## drawn whatever the relief does.
static func _bench(L: Object, at: Vector2, _a: Array) -> bool:
	var rng: RandomNumberGenerator = L.rng
	var d: Vector2 = L.d
	var nrm: Vector2 = L.nrm
	var half := Vector2(rng.randf_range(4.5, 5.5), rng.randf_range(2.6, 3.2))
	var larder := PackedVector2Array()
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var mast := GenWorks.put_on_step(L, PropKind.THEODOLITE_MAST, at + d * half.x * sx + nrm * half.y * sy, d.angle())
			if mast != null:
				larder.append(mast.pos)
	# The racks down the long axis, two rows of cores, and more of them where a
	# corner mast could not stand, so the bench feeds its keeper.
	for j: float in [-2.2, 2.2, 0.0, -4.0, 4.0]:
		if larder.size() >= FED + 3 or (absf(j) != 2.2 and larder.size() >= FED):
			break
		for sy: float in [-1.1, 1.1]:
			var rack := GenWorks.put_on_step(L, PropKind.CORE_RACK, at + d * j + nrm * sy, d.angle())
			if rack != null:
				larder.append(rack.pos)
	# Too broken to hold a survey, or where the den its keeper will take, off
	# its larder (Sentinels.station_den), cannot keep the plumb's ways.
	if larder.size() < FED or not GenWorks.station_holds(L, at, larder, maxf(half.x, half.y)):
		return false
	GenWorks._record(L.c, &"bench", at, d, half, GenWorks.BORES)
	# No yard's heart (Works.sites): the plan's depots stand on ground a yard
	# fits, and the terraces round a bench hold none. Searched for, 512's seed 1
	# walked the ring twice for nothing, and at 256 a crags yard stood first.
	(L.w.landmarks.back() as Dictionary)["depot"] = false
	for sx: float in [-1.0, 1.0]:
		GenWorks._put(L, PropKind.SURVEY, at + d * (half.x + 1.6) * sx, d.angle(), -99, 0.0, true)
	GenWorks._put(L, PropKind.SIGN, at - nrm * (half.y + 1.4), (-nrm).angle(), -99, 0.2)
	# Nothing grows back on a bench the survey keeps returning to.
	GenWorks._clear_rect(L, at, d, half)
	return true
