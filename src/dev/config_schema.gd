class_name ConfigSchema
## Every setting a master configuration may hold (docs/DEV.md), with its default.
## A configuration file only lists what it changes; everything it does not name
## is the default here, so a default changed in code reaches every configuration.
##
## This file names nothing heavy on purpose: main.gd reads the active
## configuration before the first frame is drawn, and a table that pulled in the
## landscapes, the weather or the items would compile half the game to do it.
## Choices that come from the game's content (where a game starts, the weather,
## what can be carried) are marked `from` and filled by ConfigChoices.
##
## A row:
##   id        "group.name", the key in a configuration file
##   label     what the slate calls it
##   kind      bool | choice | text | int | kit | fit | targets
##   default   the value when no configuration says otherwise
##   options   for a choice: the values, in the order left and right step through
##   from      for a choice filled from content: &"places" | &"weather"
##   min, max  for an int
##   applies   &"boot" (read as the game starts up) | &"new" (a new game) |
##             &"live" (the running game, at once) | &"build" (what a build makes)
##   note      one plain line for the slate's panel
##
## Adding a setting: a row here, the one line that reads it (GameConfig.value),
## and tests/dev/test_configs.gd holds every configuration file to the table.

const ROWS: Array[Dictionary] = [
	{"id": "build.label", "group": "build", "label": "name", "kind": "text", "default": "", "applies": "build",
		"note": "What a build of this is called on the title and the shelf."},
	{"id": "build.channel", "group": "build", "label": "channel", "kind": "choice", "default": "dev",
		"options": ["dev", "playtest", "release"], "applies": "build",
		"note": "Dev and playtest builds say what they are on the title; a release says nothing."},
	{"id": "build.version", "group": "build", "label": "version", "kind": "text", "default": "0.0.0", "applies": "build",
		"note": "Stamped into every build made from this."},
	{"id": "build.quality", "group": "build", "label": "quality", "kind": "choice", "default": "auto",
		"from": "quality", "applies": "boot",
		"note": "The graphics tier a build of this boots at. auto: what the machine can do."},

	{"id": "dev.access", "group": "dev", "label": "dev mode", "kind": "choice", "default": "off",
		"options": ["off", "chord", "open"], "applies": "boot",
		"note": "open: a row on home and the title. chord: struck three times to arm. off: never."},

	{"id": "world.seed", "group": "world", "label": "first island", "kind": "int", "default": 1, "min": 1, "max": 99999, "applies": "boot",
		"note": "The island the title shows first, and a new game's unless another is chosen."},
	{"id": "world.seed_locked", "group": "world", "label": "island fixed", "kind": "bool", "default": false, "applies": "boot",
		"note": "Yes: the title shows only the first island, offers no other, and every new game is played on it."},
	# THE DEFAULT IS `Tuning.WORLD_SIZE` AND IS NOT WRITTEN OUT AGAIN HERE. It was
	# 512 spelled a second time, so the day the world became five continents this
	# page still offered a one-island world as "the game as it is" and
	# `tests/dev/test_configs.gd` was the only thing that noticed. The options are
	# the sizes worth choosing between: one island, and the squares that hold three,
	# five, six and seven continents at full size (`GenBodies._square_for`).
	{"id": "world.size", "group": "world", "label": "size", "kind": "choice", "default": Tuning.WORLD_SIZE,
		"options": [256, 512, 996, 1138, Tuning.WORLD_SIZE, 1477, 1666], "applies": "boot",
		"note": "Tiles along a side of the world. 512 is one island; 1300 is five continents."},
	{"id": "world.hour", "group": "world", "label": "starts at", "kind": "choice", "default": 8.0,
		"options": [5.0, 6.5, 8.0, 10.0, 12.0, 15.0, 17.5, 19.5, 21.0, 23.0, 1.0], "applies": "new",
		"note": "The hour a new game wakes at."},
	{"id": "world.start", "group": "world", "label": "starts in", "kind": "choice", "default": "spawn", "from": "places", "applies": "new",
		"note": "Where a new game wakes: the strand, or deep in a landscape."},
	{"id": "world.weather", "group": "world", "label": "weather", "kind": "choice", "default": "rules", "from": "weather", "applies": "new",
		"note": "Rules: each landscape's own. Anything else holds that sky for the whole game."},
	{"id": "world.weather_strength", "group": "world", "label": "how hard", "kind": "choice", "default": 1.0,
		"options": [0.25, 0.5, 0.75, 1.0], "applies": "new", "note": "How hard held weather comes down."},

	{"id": "start.kit", "group": "start", "label": "carrying", "kind": "kit", "default": {}, "applies": "new",
		"note": "What a new game starts with in the creel, beside the knife."},
	{"id": "start.fit", "group": "start", "label": "wearing", "kind": "fit", "default": [], "applies": "new",
		"note": "Gear a new game starts with on."},
	{"id": "start.lamp", "group": "start", "label": "lamp lit", "kind": "bool", "default": false, "applies": "new",
		"note": "A new game starts with the lamp burning."},

	# The default is the shipped rate itself rather than a second copy of it, and
	# the steps near it are fine because that is where the choice actually is:
	# 1 to 2 is a day going from 24 minutes to 12, which is not a nudge.
	{"id": "rules.clock", "group": "rules", "label": "clock", "kind": "choice", "default": Tuning.MINUTES_PER_SECOND,
		"options": [0.0, 0.5, 0.75, 1.0, 1.2, 1.4, 1.7, 2.0, 3.0, 5.0, 10.0, 30.0, 60.0], "applies": "live",
		"note": "World minutes to a real second. At 1 a day takes 24 minutes; at 1.4, about 17."},
	{"id": "rules.harm", "group": "rules", "label": "harm taken", "kind": "choice", "default": 1.0,
		"options": [0.0, 0.25, 0.5, 1.0, 1.5, 2.0], "applies": "live",
		"note": "What a blow takes off the player. None: nothing can down them."},
	{"id": "rules.hunger", "group": "rules", "label": "hunger pace", "kind": "choice", "default": 1.0,
		"options": [0.0, 0.5, 1.0, 1.5, 2.0], "applies": "live",
		"note": "How fast the body grows hungry against the clock. None: it never does."},
	{"id": "rules.bodies", "group": "rules", "label": "how many come", "kind": "choice", "default": 1.0,
		"options": [0.25, 0.5, 1.0, 2.0, 3.0], "applies": "live",
		"note": "How often the land puts a body round the player, against the game as tuned."},
	{"id": "rules.hazards", "group": "rules", "label": "the land presses", "kind": "choice", "default": 1.0,
		"options": [0.0, 0.5, 1.0, 1.5, 2.0], "applies": "live",
		"note": "How hard a landscape's cold, heat, fumes and the rest press on the body. None: nothing presses."},
	{"id": "rules.autosave", "group": "rules", "label": "autosave", "kind": "choice", "default": "normal",
		"options": ["off", "rare", "normal", "often"], "applies": "live",
		"note": "How often the game saves itself: off keeps a playtest to the slots a tester writes by hand."},
	{"id": "rules.machines", "group": "rules", "label": "machines come", "kind": "bool", "default": true, "applies": "live",
		"note": "No: nothing new is put on the land round the player."},
	{"id": "rules.guide", "group": "rules", "label": "first-hour guide", "kind": "bool", "default": true, "applies": "live",
		"note": "The goal line and the key hints of a first hour."},
	{"id": "rules.works", "group": "rules", "label": "the works work", "kind": "choice", "default": 1.0,
		"options": [0.0, 0.5, 1.0, 2.0, 4.0], "applies": "live",
		"note": "How busy a region's depot is: how often it puts one of its own out and sends a round along the survey. None: it stands lit and sends nothing."},
	{"id": "rules.lock_lens", "group": "rules", "label": "held Z lens", "kind": "bool", "default": true, "applies": "live",
		"note": "Yes: holding Z puts the camera behind the player in perspective, and letting go puts it back. On by default (owner, 2026-09-22: the held-Z lens stays and becomes the default, once its cost clears the slums and the depot on a quiet box)."},
	{"id": "rules.raids", "group": "rules", "label": "machines raid", "kind": "bool", "default": true, "applies": "live",
		"note": "No: a holding is still read and still files, and nothing is ever sent for it."},
	{"id": "rules.raid_pace", "group": "rules", "label": "raids come", "kind": "choice", "default": 1.0,
		"options": [0.25, 0.5, 1.0, 2.0, 4.0], "applies": "live",
		"note": "How fast a holding earns the plan's attention, against the game as tuned."},

	{"id": "builds.targets", "group": "builds", "label": "makes", "kind": "targets", "default": ["web"],
		"options": ["web", "web-nothreads", "mac"], "applies": "build",
		"note": "What making a build of this exports."},
	{"id": "builds.template", "group": "builds", "label": "template", "kind": "choice", "default": "release",
		"options": ["release", "debug"], "applies": "build", "note": "Debug keeps the engine's checks and is slower."},
]

const GROUPS: Array[String] = ["build", "dev", "world", "start", "rules", "builds"]
const TARGETS: Array[String] = ["web", "web-nothreads", "mac"]


static var _by_id: Dictionary = {}


static func row(id: String) -> Dictionary:
	if _by_id.is_empty():
		for r: Dictionary in ROWS:
			_by_id[r.id] = r
	return _by_id.get(id, {})


static func has(id: String) -> bool:
	return not row(id).is_empty()


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r: Dictionary in ROWS:
		out.append(r.id)
	return out


static func default_of(id: String) -> Variant:
	var d: Variant = row(id).get("default")
	return d.duplicate(true) if d is Dictionary or d is Array else d


## A value read from JSON (every number a float, every key a String), as the
## setting holds it: ints back to ints, a kit's counts to ints, lists of ids.
static func coerce(id: String, v: Variant) -> Variant:
	var r := row(id)
	match String(r.get("kind", "")):
		"bool":
			return bool(v) if v is bool or v is float or v is int else v
		"int":
			return int(v) if v is float or v is int else v
		"choice":
			var d: Variant = r.get("default")
			if (v is float or v is int) and d is int:
				return int(v)
			if (v is float or v is int) and d is float:
				return float(v)
			return v
		"kit":
			if not (v is Dictionary):
				return v
			var kit := {}
			for k: Variant in v:
				var n: Variant = v[k]
				kit[String(k)] = int(n) if n is float or n is int else n
			return kit
		"fit", "targets":
			if not (v is Array):
				return v
			var list: Array = []
			for x: Variant in v:
				list.append(String(x) if x is String or x is StringName else x)
			return list
	return v


## "" when `v` may be the value of setting `id`, otherwise one plain line why
## not. Choices filled from content are checked for shape here and for
## membership by ConfigChoices (which knows the content).
static func check(id: String, v: Variant) -> String:
	var r := row(id)
	if r.is_empty():
		return "no setting is called %s" % id
	match String(r.kind):
		"bool":
			if not (v is bool):
				return "%s is yes or no" % id
		"text":
			if not (v is String):
				return "%s is words" % id
			if (v as String).length() > 40:
				return "%s is longer than 40 letters" % id
		"int":
			if not (v is int):
				return "%s is a whole number" % id
			if int(v) < int(r.min) or int(v) > int(r.max):
				return "%s is %d..%d" % [id, int(r.min), int(r.max)]
		"choice":
			if r.has("options") and not _in(v, r.options):
				return "%s is one of %s" % [id, ", ".join(PackedStringArray(r.options.map(func(o: Variant) -> String: return str(o))))]
			if r.has("from") and not (v is String):
				return "%s is a name" % id
		"kit":
			if not (v is Dictionary):
				return "%s is things and how many" % id
			for k: Variant in v:
				if not (v[k] is int) or int(v[k]) < 1 or int(v[k]) > 99:
					return "%s: %s is 1..99" % [id, str(k)]
		"fit":
			if not (v is Array):
				return "%s is a list of gear" % id
			for x: Variant in v:
				if not (x is String):
					return "%s is a list of gear" % id
		"targets":
			if not (v is Array) or (v as Array).is_empty():
				return "%s names at least one of %s" % [id, ", ".join(TARGETS)]
			for x: Variant in v:
				if not TARGETS.has(str(x)):
					return "%s: %s is not a build target" % [id, str(x)]
	return ""


## Values compare as the game reads them: 8 and 8.0 are the same hour.
static func same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		var sa: Array = (a as Array).duplicate()
		var sb: Array = (b as Array).duplicate()
		sa.sort()
		sb.sort()
		return sa == sb
	return typeof(a) == typeof(b) and a == b


static func _in(v: Variant, options: Array) -> bool:
	for o: Variant in options:
		if same(o, v) and (v is String) == (o is String):
			return true
	return false
