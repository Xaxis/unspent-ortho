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
const GEN := 1

## The BiomeDef fields worldgen reads, so the ones that decide which island a
## seed makes. Every one is read somewhere under src/core/worldgen or in the
## surface and scatter recipes.
const TERRAIN: Array[String] = [
	"id", "index", "order", "sea", "realms",
	"share", "anchors", "temp_range", "moist_range", "site_count", "adjacency", "coastal",
	"relief", "caldera", "dunes",
	"border_elevation", "tongues", "reach_out_thin", "reach_in_thin", "reach_out_high", "reach_in_low",
	"plain_ground", "pool_rim_ground", "rivers_freeze", "village_ground", "village_square_ground",
	"props", "ore", "gravel_ore", "reed_chance", "scorched", "shore_bush", "surface", "scatter",
	"sites", "tip_ground", "beached_wrecks", "pools", "villages", "village_names", "village_order",
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
	"hatch", "grounds", "ground_marks", "cliff_wash", "strata", "bank_ground", "rock_ground",
	"decor", "grass_colors", "rock_color", "decor_tints", "tree_tints", "hard_rock",
	"light_tint", "grade", "wet", "lip_snow",
	"weather", "mist", "hazards", "roster", "sentinel", "sound_bed", "music_motif",
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
