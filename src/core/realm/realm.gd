class_name Realm
## Which WORLD a place belongs to (docs/VISION.md, §7.1). A realm is a world
## of its own — its own WorldData, its own view, its own saved edits — grown from
## the same seed with the realm's own salt, and joined to the others by portals
## (§4). The game holds one active realm at a time (src/systems/20_realms.gd).
##
##   Realm.of(def)              the realm a landscape TYPE belongs to
##   Realm.at(world, pos)       the realm a TILE is in
##   Realm.beyond(kind)         what a portal out of `kind` opens onto
##   Realm.seed_for(seed, kind) the seed that grows this realm's world
##
## A realm is the authority over its own light, sky, weather and sound, and a
## landscape declares them THROUGH it, not around it: `limestone_caves.gd` takes
## `Realm.light`, `Realm.airs` and `Realm.bed` and colours inside them, exactly
## as a surface landscape takes the coast's baseline and argues with parts of it.
## That is why these are defaults a content file reads and not numbers a system
## writes over the top: the existing doors (BiomeDef.light_tint, .weather,
## .sound_bed, GroundColors) already reach every renderer, and a realm that
## needed its own door into each of them would be a second sky package.
## `tests/realm/test_realms.gd` holds every registered landscape to its realm.

const SURFACE := &"surface"
const UNDERGROUND := &"underground"
const ORBITAL := &"orbital"
const ERA := &"era"

## Every realm a landscape may declare (BiomeDef.realms).
const KINDS: Array[StringName] = [SURFACE, UNDERGROUND, ORBITAL, ERA]

## The notebook changes medium with the realm (docs/VISION.md). Only the first
## two are drawn: the others are named so a landscape written for them cannot be
## registered into a realm whose page nobody has drawn yet.
const PAGE_WASH := &"ink_and_wash"
const PAGE_SCRATCH := &"scratchboard"
const PAGE_GRAPHITE := &"graphite"
const PAGE_CYANOTYPE := &"cyanotype"
const PAGE_WATERCOLOUR := &"watercolour"
const PAGES_DRAWN: Array[StringName] = [PAGE_WASH, PAGE_SCRATCH]

## What a realm is, and what it lends every landscape in it.
##
##   page     the medium it is drawn in (VISION §8)
##   roofed   nothing is above it: no sky, no sun on the land, no weather from
##            the sky. What hangs in its air is its own, and always the same.
##   light    the multiply a landscape's own BiomeDef.light_tint starts from. On
##            a roofed page it is what makes the frame dark enough for a lamp to
##            be worth carrying: the shader's gloom is read off the light's own
##            luminance (sky.gdshaderinc sky_gloom), so a realm with no sky in it
##            darkens the light rather than asking for a term of its own.
##   lift     the dark term of a landscape's grade (BiomeDef.grade.x). Negative
##            lifts, which every surface landscape does; a roofed realm DIMS, and
##            under a roof it is a FLOOR (a landscape may be darker than its
##            realm, never brighter), while above one it is only a start.
##   night    how much of the NIGHT sky's light stands over a landscape in it
##            (BiomeDef.night_sky). A surface landscape argues with this freely —
##            a fen has more sky over it than a wood does — but a roofed realm has
##            no sky at all, and what makes it dark is SkyLight.closed reading it
##            as night at every hour, not a number here. So this stays 1.0 under a
##            roof and the door exists for the realms that are not drawn yet: the
##            orbital page has no air to soften a night, so its dark is harder.
##   airs     the weather table a landscape in it starts from (BiomeDef.weather).
##   bans     weather kinds that cannot fall in it: nothing out of the sky
##            reaches a roofed realm.
##   bed      the ambience floor under it (BiomeDef.sound_bed).
##   salt     the salt its world is grown with, so one seed makes every realm and
##            no two are the same island.
const DEFS := {
	SURFACE: {
		"page": PAGE_WASH, "roofed": false,
		"light": Color(1, 1, 1), "lift": -0.4, "night": 1.0,
		"airs": [], "bans": [], "bed": &"bed_wind", "salt": 0,
	},
	UNDERGROUND: {
		"page": PAGE_SCRATCH, "roofed": true,
		# Cold, and two thirds of the day's level. It is NOT what makes the frame
		# dark — SkyLight.closed does that, by reading a roofed realm as night at
		# any hour, which is what brings the blue floor, the hatch, the night ink
		# and the lamp's pool with it. This is only the colour of what light there
		# is: dimmed further here the page went flat and muddy instead of dark.
		"light": Color(0.62, 0.68, 0.84), "lift": 0.42, "night": 1.0,
		# The air of a cave is its own: it hangs saturated for days and then dries
		# and stands clear, and nothing ever falls through it. Weather is still an
		# event down here, which is the rule every landscape keeps (tests/sky);
		# what a roof takes away is the SUN, and that the realms system takes off
		# SkyLight directly, because no air can.
		"airs": [[Weather.FOG, 62, 0.0], [Weather.CLEAR, 38, 0.0]], "bans": [Weather.RAIN, Weather.DRIZZLE,
			Weather.STORM, Weather.HAIL, Weather.SNOW, Weather.BLIZZARD, Weather.WHITEOUT,
			Weather.GLARE, Weather.DUST, Weather.DRY_STORM, Weather.ASH, Weather.HAZE,
			Weather.GREY, Weather.HEAT],
		"bed": &"bed_river", "salt": 0x5CA1EF,
		# The caves run UNDER the surface, so they are cut in the same footprints
		# (see `same_land_as` on the era for the other half of this pair: that one
		# shares the landscapes too, this one only the map).
		"footprints_of": SURFACE,
	},
	ORBITAL: {
		"page": PAGE_GRAPHITE, "roofed": false,
		"light": Color(0.86, 0.88, 1.0), "lift": -0.2, "night": 1.25,
		"airs": [[Weather.CLEAR, 100, 0.0]], "bans": [Weather.RAIN, Weather.DRIZZLE,
			Weather.STORM, Weather.HAIL, Weather.SNOW, Weather.BLIZZARD, Weather.FOG,
			Weather.WHITEOUT, Weather.DUST, Weather.DRY_STORM, Weather.ASH, Weather.HAZE,
			Weather.GREY, Weather.HEAT],
		"bed": &"bed_far_drone", "salt": 0x0B117A,
	},
	# THE SAME LAND, EARLIER. An era is not another place: it is this coast in
	# 2029, at the same coordinates, which is what makes the ruin he wakes in his
	# own town (docs/STORY.md) and what VISION §4 meant by "realm pairs sharing
	# coordinates". So its salt is 0 — the same seed grows the same island — and
	# it lays the SURFACE's landscapes, because the coast was the coast then too.
	# What differs is what stands on it, which is dressing and not terrain.
	ERA: {
		"page": PAGE_WATERCOLOUR, "roofed": false,
		"light": Color(1, 1, 1), "lift": -0.5, "night": 1.0,
		"airs": [], "bans": [], "bed": &"bed_wind", "salt": 0,
		"same_land_as": SURFACE,
		"footprints_of": SURFACE,
		# THE PLAN HAD NOT STARTED. 2029 is before the machines ruled this coast
		# on a bearing, so none of their works stand in it: no relays, no survey
		# posts, no drill rigs, no depot. The land is the same land and what is
		# ON it is sixty-nine years of difference, which is the whole of why a
		# player is walked back here (docs/STORY.md).
		"before_the_plan": true,
	},
}


## Whose landscapes this realm lays. Its own, unless it IS another realm at a
## different time (`same_land_as`): the Before is this coast in 2029, so it grows
## the same coast. Every reader of `BiomeDef.realms` goes through here, or one of
## them lays a world nobody declared a landscape for.
## Whether this realm is from before the machines began (`GenWorks`). The land is
## laid the same; their works are simply not there yet.
static func before_the_plan(kind: StringName) -> bool:
	return bool(def(kind).get("before_the_plan", false))


static func land_realm(kind: StringName) -> StringName:
	return def(kind).get("same_land_as", kind)


static func def(kind: StringName) -> Dictionary:
	return DEFS.get(kind, DEFS[SURFACE])


## The realm a landscape TYPE belongs to: the first it declares. A type may be
## registered in several (a landscape that lies both on the surface and under a
## roof), and the first is where it is at home.
static func of(d: BiomeDef) -> StringName:
	if d == null or d.realms.is_empty():
		return SURFACE
	return d.realms[0]


## The realm a TILE is in: its landscape's, and for water the world's, because
## the sea is one type shared by every realm and belongs to none of them — the
## flooded bottom of a cave system is under the world, not on the coast.
static func at(w: WorldData, p: Vector2) -> StringName:
	if w == null:
		return SURFACE
	var d := BiomeRegistry.at(w, p)
	return w.realm if d.sea else of(d)


## The realm on the far side of a portal out of `kind`. One pair is joined so
## far: the surface and what the machines sank under it.
static func beyond(kind: StringName) -> StringName:
	return SURFACE if kind == UNDERGROUND else UNDERGROUND


## Nothing above it: no sky, no sun on the ground, no weather off the sky.
static func roofed(kind: StringName) -> bool:
	return bool(def(kind).get("roofed", false))


static func page(kind: StringName) -> StringName:
	return def(kind).get("page", PAGE_WASH)


## The light a landscape in this realm starts from (BiomeDef.light_tint).
static func light(kind: StringName) -> Color:
	return def(kind).get("light", Color(1, 1, 1))


## The dark term a landscape in this realm grades with (BiomeDef.grade.x).
static func lift(kind: StringName) -> float:
	return float(def(kind).get("lift", -0.4))


## How much of the night sky a landscape in this realm starts with
## (BiomeDef.night_sky).
static func night_sky(kind: StringName) -> float:
	return float(def(kind).get("night", 1.0))


## The weather table a landscape in this realm starts from (BiomeDef.weather).
## Empty means the realm lets a landscape write its own, as the surface does.
static func airs(kind: StringName) -> Array:
	return (def(kind).get("airs", []) as Array).duplicate(true)


## The ambience floor under this realm (BiomeDef.sound_bed).
static func bed(kind: StringName) -> StringName:
	return def(kind).get("bed", &"bed_wind")


## Weather kinds that cannot happen in this realm.
static func bans(kind: StringName) -> Array:
	return def(kind).get("bans", [])


## The seed that grows this realm's world from a game's seed. Each realm is its
## own island from the same number, so one save's seed is the whole set of them.
static func seed_for(seed_value: int, kind: StringName) -> int:
	var salt := int(def(kind).get("salt", 0))
	if salt == 0:
		return seed_value
	# Mixed, not added: two realms' salts must not be able to land one realm's
	# world on another realm's seed for any game.
	return (seed_value * 0x9E3779B1 + salt) & 0x7FFFFFFF


## Every realm's problems, as lines. Empty means the table is sound; the realm
## test fails on anything here.
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for kind: StringName in KINDS:
		if not DEFS.has(kind):
			out.append("realm %s has no row" % kind)
			continue
		var row: Dictionary = DEFS[kind]
		for field: String in ["page", "roofed", "light", "lift", "night", "airs", "bans", "bed", "salt"]:
			if not row.has(field):
				out.append("realm %s says nothing about %s" % [kind, field])
		for k: StringName in bans(kind):
			if not Weather.KINDS.has(k):
				out.append("realm %s bans %s, which is no weather" % [kind, k])
		var table: Array = airs(kind)
		if not table.is_empty():
			var total := 0.0
			for r: Array in table:
				total += float(r[1])
				if bans(kind).has(r[0]):
					out.append("realm %s hangs %s in its air and bans it" % [kind, r[0]])
			if absf(total - 100.0) > 0.01:
				out.append("realm %s airs sum to %.1f, not 100" % [kind, total])
	for kind: StringName in DEFS:
		if not KINDS.has(kind):
			out.append("realm %s is a row with no kind" % kind)
	return out
