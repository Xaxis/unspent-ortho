class_name WorldStamp
## Which island a seed makes, in eight hex digits.
##
## A save keeps only the seed and the size and generates the world again on
## load (SaveSlots.options_for). That is only safe while the same seed still
## makes the same island — and it does not: the world is composed from whatever
## landscape types the registry holds, so REGISTERING A LANDSCAPE MOVES EVERY
## SEED'S ISLAND. Adding salt_flats and scrapwood in M2 wave A moved 8-10% of
## every world's tiles into another landscape and 16-19% to another height,
## which a save's tile-keyed state (the player's tile, `depleted` prop ids, the
## explored map) would have been laid back onto in silence.
##
## So a save carries this stamp of everything outside the seed that decides the
## terrain, and a save whose stamp is not this build's is refused by name
## (SaveFile: code &"elsewhere"). M3 adds a dozen landscapes; each one moves
## every island again, and each time the player is told rather than misplaced.
##
##   WorldStamp.current() -> String          this build's registry
##   WorldStamp.of(defs)  -> String          any list of types (tests)
##   WorldStamp.UNKNOWN                      a save from before the stamp
##
## What it does NOT cover, and why: the bodies of a landscape's `surface` and
## `scatter` recipes (only their names are hashable — a script's source is not
## readable the same way in an exported build), and the worldgen stages
## themselves. `GEN` below is the hand lever for those, and SaveCore.disagrees
## is the cheap second line that catches them on the player's own tile.

## A save written before the stamp existed. Never equal to a real stamp.
const UNKNOWN := "unknown"

## Bump when a worldgen stage changes what a seed makes (a different island from
## the same inputs). Nothing here can see into GenShape or GenRelief; this is
## the hand that says they moved.
##
## 2: GenCountries marks a half-cell whose nearest border pair does not name its
##    own country as a SEAM, which it always was. `blend` changes by a fifth of a
##    percent over the three test seeds, and `GenScatter` chooses a tile's recipe
##    by blend, so a handful of props move. Small, but not nothing, and a save
##    grows its world again from the seed.
## 3. The slums declared what it is BUILT of (`BiomeForms.RAISED`, `plan = row`).
##    The stock's size is how many buildings a settlement raises and the plan is
##    where each one stands, so every prop placed after the first village in that
##    landscape has a new id. It is the largest deliberate move of this list and
##    it is the landscape finally being the thing it was written to be: without
##    it a megacity rendered as eight one-storey huts.
## 4. The Crags scatters what it DECLARES. It listed ten prop kinds — standing
##    stones, cairns, graves, ruins, clints, memorials — and its `_scatter`
##    placed one, a bush on moss, so nine tenths of its own declaration existed
##    in `props` and never in the ground between the landmarks. **The stamp
##    cannot see this and that is why the counter is turned by hand**: a scatter
##    recipe is hashed by its NAME and not by its source, so the digest was
##    identical before and after while every seed's Crags changed completely.
## 5. Eight more landscapes followed the Crags, and two of them are landscapes the
##    parity baseline holds: the moss and the snowfield. Each used to answer
##    `BiomeScatter.PASS` on every ground but one, which hands the tile to the
##    SHARED table -- and the shared table is the coast's, so a snowfield was
##    being filled with the coast's driftwood. Naming its own grounds costs it
##    that fallback, and the island places 107 to 181 FEWER props on the five
##    parity seeds (the snowfield alone 92 to 146). A count that falls is still a
##    count that moved: every prop id after the first changed tile shifts, so a
##    village is dealt different buildings. Same blindness as 4 -- the recipe is
##    hashed by name -- which is why this is the second hand turn in a row.
##  6. The region floor became a share of the BODY a run lies on and of how many
##     landscapes share that body, instead of a share of the whole square
##     (`GenCountries.BODY_SHARE`, owner 2026-09-19). The square grew five times
##     faster than any continent in it once the world became five bodies, so the
##     floor had outgrown them: at 1300 it asked 8,059 tiles of continents
##     holding about 6,600 each, leaving 26% of the land in no region and the
##     server fields and the glass desert with no chapter anywhere. `GenScatter`
##     iterates `w.regions` and filters props by `region_at`, so which runs
##     become places decides where props go -- this moves every seed.
##  7. Two worldgen faults found together. The per-region site loops (tips, stone
##     circles) threw their darts at `land_rect` -- the bounding box of ALL the
##     land -- while keeping only the ones that landed in the region they were
##     filling. On a 1300 world that is 1.6 million tiles against a region of a
##     few hundred, so a small region was hit about once in the 2,500 darts the
##     loop throws, and a landscape that declared tips in its own file had none
##     anywhere on the island. Aimed at the region's own bounds now. And the
##     way-in seam laid iron and stone ore wherever it sited, without asking
##     whether that landscape holds them: `BiomeDef.ore` decides now, with iron
##     forced where a landscape claims neither, because the first seam has to
##     exist on every seed.
##  8. A strait that two continents' shelves closed. Deep water is the only thing
##     that stops a body on foot and every coast carries twenty tiles of level-0
##     shelf; where two continents' shelves touched, that was a dry road between
##     them. `GenBodies.deepen_straits` cuts the watershed between two shelves.
##     It moves 125 tiles on seed 1 and NOTHING on seeds 42 and 90210, which have
##     no seam -- and nothing at all at 256, where a world holds one body of
##     continent size. Turned all the same: 125 tiles is a world that moved.
##  9. The deal holds LAND, not only sites, and home is the plan's home. Which
##     landscapes a continent was dealt was asked only where a site went, so a
##     territory grew across the strait onto a nearer body: up to 70.6% of a
##     continent (seed 42) was landscapes it was never dealt. `GenContext.may_stand`
##     is asked by the layout now, and `deal` finds home by the continent that
##     holds the plan's home centre instead of by list position. Every seed at the
##     shipped size moves; NOTHING moves at 256, where a world is one body and the
##     deal restricts nothing, so `test_parity` stays green over it and cannot be
##     the evidence. The counter is the only thing that knows.
## 10. A river is a simple path. The traced line folded back over tiles it had
##     already crossed and a tile keeps the lowest bed of its visits, so a fold
##     after a drop left water a level above the water beside it and a line that
##     climbed. `GenWater._cut_loops` takes the loops out; every river's mouth and
##     count are unchanged, and ground, level and props move on every seed.
## 11. A repeated building is checked for still water at the size it will be.
##     A city's repeats are dealt a size band AFTER they are placed, so a tower
##     checked at its form's reach grew past the ring and stood with a pool at its
##     door. The placer asks the largest band now; cities move at 1300.
## 12. One batch, landed together so the world moves once (owner's delegation,
##     `docs/ROADMAP.md` DECIDED 5 and 6): a region's floor share 0.35 -> 0.25;
##     a prop's model dealt by its kind and position, not its id; the spawn
##     village preferring a beach the black site can stand off; and a works site
##     thrown at its own landscape's regions instead of the whole land.
## 13. The spawn asks the south half of home before flat ground. Flat-before-rough
##     woke 6 of 150 worlds (seeds 1-50 at 1300, 1477, 1666) in home's far north;
##     those six move south, the other 144 are unchanged.
## 14. The scatter reaches what its recipes wrote. The shared roll cap threw away
##     every roll over it before a landscape's own recipe was asked, so about 33
##     signature bands in 16 landscapes (cairns, sea walls, stacks) could never be
##     laid; the prop mask was a 64-bit word that wrapped the kinds past 64 onto
##     pines and bushes; declared ore was refused wherever `props` did not repeat
##     it; only the first landscape declaring fumaroles got its fields. Props move
##     on every seed, and ground moves wherever the jungle's new fields lay salt.
## 15. A landscape is a PLACE (L1, docs/ROADMAP.md: 40 frames of main region on
##     every seed). The surface holds five continents at most (`GenBodies.COUNT`),
##     the square is 1840 (`Tuning.WORLD_SIZE`), a landscape lies on two of the
##     five (`MOST_BODIES` 0.4), and eight shares rose out of the coast's. Every
##     seed's world moves; 21 of 21 surface landscapes make 40 frames on seeds 1,
##     42 and 90210, and none has a smaller main region than it had at 1300.
const GEN := 24

## The BiomeDef fields worldgen reads, so the ones that decide which island a
## seed makes. Every one is read somewhere under src/core/worldgen or in the
## surface and scatter recipes.
const TERRAIN: Array[String] = [
	"id", "index", "order", "sea", "realms",
	"share", "spread", "anchors", "temp_range", "moist_range", "site_count", "adjacency", "coastal",
	"relief", "caldera", "dunes",
	"border_elevation", "tongues", "reach_out_thin", "reach_in_thin", "reach_out_high", "reach_in_low",
	"plain_ground", "pool_rim_ground", "rivers_freeze", "village_ground", "village_square_ground", "built",
	"props", "ore", "gravel_ore", "reed_chance", "scorched", "shore_bush", "surface", "scatter",
	"sites", "tip_ground", "beached_wrecks", "pools", "villages", "village_names", "village_order",
	"villages_each_region", "village_platform",
	"spawn_home",
]

## The BiomeDef fields that decide how a landscape LOOKS, SOUNDS or is LIVED in,
## which no worldgen stage reads. They are deliberately outside the stamp: a
## wash retuned or a hazard restrung must not throw away the player's game.
## Listed so tests/save/test_world_stamp.gd can fail on a field in neither list
## — a new field on BiomeDef is classified here or the stamp quietly stops
## covering it.
const LOOK: Array[String] = [
	"display_name", "style_note",
	"hatch", "grounds", "ground_marks", "cliff_wash", "water_wash", "strata", "bank_ground", "rock_ground",
	"decor", "grass_colors", "rock_color", "decor_tints", "tree_tints", "hard_rock", "dressing",
	"light_tint", "night_sky", "web_contrast", "sky_shut", "grade", "wet", "lip_snow", "street_folk",
	"weather", "mist", "hazards", "roster", "sentinel", "landmarks", "sound_bed", "music_motif",
	"fliers", "holograms",
]


## This build's registry, whatever it holds (a muted registry stamps as itself,
## which is the point: a test that mutes is on another island too).
##
## Nothing is held between calls. It was, keyed on the registry's ids, and that
## cache handed back the old stamp for a registry whose ids were unchanged but
## whose values had been retuned in place — measured stale, in the one function
## whose whole job is to notice change. Spelling every field of every landscape
## out costs 1.3 ms (nine types), so instead of caching the answer the callers
## ask once and pass it on: SaveSlots.list reads four slots against ONE stamp
## (SaveFile.read takes it), which is the only place it was ever read repeatedly.
static func current() -> String:
	return of(BiomeRegistry.all())


## The stamp of a list of types, in the order they are handed indices.
static func of(defs: Array[BiomeDef]) -> String:
	var parts := PackedStringArray()
	parts.append("gen%d" % GEN)
	for d in defs:
		if d == null:
			continue
		var row := PackedStringArray()
		for f in TERRAIN:
			row.append(f + "=" + _spell(d.get(f)))
		parts.append("|".join(row))
	return "\n".join(parts).md5_text().substr(0, 8)


## One value, spelled the same way every run: floats to a fixed number of
## places (so a recompile's last bit cannot move the stamp), dictionaries by
## sorted key, a recipe by the method and script it came from.
static func _spell(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "none"
		TYPE_OBJECT:
			# A declared object (`BiomeDef.built`, a BiomeForms). `str()` on one is
			# its INSTANCE ID, which changes every run, so the one field that is an
			# object would have moved the stamp on every launch and refused every save
			# on disk as &"elsewhere" — silently, and ONLY for the players who had a
			# landscape declaring one. Everybody else would be fine and nobody could
			# reproduce it. So it is spelled out: the script's bare file name (an
			# exported build serves the same script as .gdc or through a .remap, and a
			# save written by the mac build must still open in the web one), and the
			# fields the OBJECT ITSELF names, in the order it names them.
			#
			# It was `get_property_list()`. That order is the engine's to decide and
			# nothing promises it survives an export — and if it does not, the same
			# landscape stamps differently in the two builds and a save made in either
			# is refused in the other, with nothing in the editor able to show it. A
			# type that declares no `stamped()` is spelled as its class alone, loudly
			# enough for a test to catch, because guessing at a field list is the
			# thing this replaced.
			var o := v as Object
			if o == null:
				return "none"
			var sc := o.get_script() as Script
			var where: String = sc.resource_path.get_file().get_basename() if sc != null else o.get_class()
			if not o.has_method("stamped"):
				return "%s(?)" % where
			var fields := PackedStringArray()
			for name: String in (o.call("stamped") as PackedStringArray):
				fields.append("%s=%s" % [name, _spell(o.get(name))])
			return "%s(%s)" % [where, ";".join(fields)]
		TYPE_FLOAT:
			return "%.6f" % (v as float)
		TYPE_VECTOR2:
			return "%.6f,%.6f" % [(v as Vector2).x, (v as Vector2).y]
		TYPE_VECTOR2I:
			return "%d,%d" % [(v as Vector2i).x, (v as Vector2i).y]
		TYPE_VECTOR3:
			var v3 := v as Vector3
			return "%.6f,%.6f,%.6f" % [v3.x, v3.y, v3.z]
		TYPE_VECTOR4:
			var v4 := v as Vector4
			return "%.6f,%.6f,%.6f,%.6f" % [v4.x, v4.y, v4.z, v4.w]
		TYPE_COLOR:
			var c := v as Color
			return "%.4f,%.4f,%.4f,%.4f" % [c.r, c.g, c.b, c.a]
		TYPE_CALLABLE:
			var c := v as Callable
			if not c.is_valid():
				return "none"
			var owner: Object = c.get_object()
			var script := owner as Script
			var where := script.resource_path if script != null else ""
			# The file's bare name: an exported build may serve the same script
			# as .gdc or through a .remap, and a save written by the mac build
			# must still open in the web one.
			return "%s@%s" % [c.get_method(), where.get_file().get_basename()]
		TYPE_DICTIONARY:
			var d := v as Dictionary
			var keys: Array = d.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var out := PackedStringArray()
			for k: Variant in keys:
				out.append("%s:%s" % [str(k), _spell(d[k])])
			return "{" + ";".join(out) + "}"
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			var out := PackedStringArray()
			for e: Variant in v:
				out.append(_spell(e))
			return "[" + ";".join(out) + "]"
	return str(v)
