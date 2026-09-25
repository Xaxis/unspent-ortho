extends RefCounted
## Finds code that reads the WHOLE world: the readers a streamed world, where
## only some sections are resident (docs of record: the streaming design, S0),
## has to change before it can drop any. `test_whole_world_readers` holds the
## list this makes against `whole_world_readers.txt`.
##
## A hit is keyed `path::function::kind`, never by line, so moving code does not
## churn the list. The kinds:
##   list     a loop over a whole-world list (props, villages, landmarks,
##            regions, roads, rivers, lines, continents, depleted)
##   index    a dense `props[...]` lookup: an id read as a place in the list
##   tiles    a buffer or loop the size of the whole map (`size * size`, a
##            loop bounded by the world's `size`, the far view's every block)
##   raw      a per-tile array read by absolute index (`w.level[i]`), or
##            taken whole to be read so (`var level := w.level`): the design
##            moves every one of these to a TileWindow
##   whole    a whole-world list taken as a value: aliased, returned or passed
##            on, so whatever walks it next is out of this file's sight
##   builder  a call into something that itself reads the whole world
##   alloc    a new prop id taken from the list's length
## Text, not a parser: it sees the direct forms. A list walked through an alias
## is caught where the alias is taken (`whole`); a reader behind a helper in
## another file is caught at the call only if the helper is in BUILDERS.
##
## Generation is being redesigned on its own (sections and a plan), so
## src/core/worldgen/ and world_gen.gd are not scanned, except GenPlaces, which
## runs in the game.

const ROOT := "res://src"
const SKIP_DIRS := ["res://src/core/worldgen"]
const SKIP_FILES := ["res://src/core/world_gen.gd"]
const KEEP_FILES := ["res://src/core/worldgen/gen_places.gd"]

const WORLD := "(?:\\bworld|\\bw|\\b_world|\\bc\\.w|\\bgame\\.world|\\bwd)"
const LISTS := "(?:props|villages|landmarks|regions|roads|rivers|lines|continents|depleted)"
## Calls whose own bodies read the whole world, so a caller does too.
const BUILDERS := [
	"Landmarks.sites", "Works.sites", "StoryPlan.cast", "Portals.in_world",
	"Interiors.thresholds", "Sentinels.states", "WorldQuery.new", "WorldGen.generate",
	"GenPlaces.find", "GenPlaces.solid_mask", "GenPlaces.country_sample",
	"GenPlaces.open_sample", "GenPlaces.typical_sample", "SkyGround.texture",
	"SkyGround.image", "SkyWear.texture", "SkyWear.image", "UiMapData.new",
	"Chapter.read", "Chapters.of", "Chapters.for_regions",
	"RoadHold.sites", "Hold.sites", "StoryGates.all", "BlackSite.blocks",
	"RealmWorlds.keep", "SoundMix.remoteness", "Treads.hand_over", "StoryJourney.bodies",
	"Spawner.green_distance", "Haven.at",
]

var _list := RegEx.new()
var _index := RegEx.new()
var _tiles := RegEx.new()
var _alloc := RegEx.new()
var _whole := RegEx.new()
var _raw := RegEx.new()
var _walk := RegEx.new()
var _func := RegEx.new()
var _clamp := RegEx.new()
var _touches := RegEx.new()


func _init() -> void:
	# `for x in w.props`, `for i in w.props.size()`, `range(w.villages.size())`,
	# `w.landmarks.filter(`: every way this code base walks a list.
	_list.compile("(?:\\bfor\\b.*\\bin\\b.*" + WORLD + "\\." + LISTS + "\\b|" + WORLD + "\\." + LISTS + "\\.(?:filter|map|any|all|reduce)\\()")
	_index.compile(WORLD + "\\.props\\[")
	_tiles.compile("\\bsize\\s*\\*\\s*[\\w.]*\\bsize\\b")
	# Indexed, or the array itself taken as a value to be indexed later
	# (`var level := w.level`). Not `region` or `continent` as values: a site's
	# own `w.region` is an int, and `w` names sites too.
	_raw.compile(WORLD + "\\.(?:(?:region|continent)\\[|(?:level|ground|country|country2|blend|recipe|road|moisture|temperature)(?:\\[|\\s*(?:[,)]|$)))")
	_alloc.compile(WORLD + "\\.props\\.size\\(\\)")
	# The list itself as a value: `var props := w.props`, `f(w.props, ...)`.
	_whole.compile(WORLD + "\\." + LISTS + "\\s*(?:[,)]|$)")
	# A loop bounded by the map: `for y in size`, `range(0, size, 2)`,
	# `while x < w.size - 3`; and the far view's block count over the world.
	_walk.compile("\\b(?:for|while)\\b.*(?<![\\w.])(?:(?:w|world|c|c\\.w|game\\.world)\\.)?size\\b(?!\\s*\\(|\\.)|\\bacross\\((?:\\w+\\.)*size\\)")
	_func.compile("^\\s*(?:static\\s+)?func\\s+(\\w+)")
	# A window clamped to the map (`mini(w.size - 1, y + r)`) is local, not a
	# walk of the map: clamps are taken out before `tiles` looks.
	_clamp.compile("\\b(?:mini|maxi|clampi|min|max|clamp|clampf)\\((?:[^()]|\\([^()]*\\))*\\)")
	# Only a file that holds a world can walk one: a `size` in a slate or a tree
	# model is its own.
	_touches.compile("\\bWorldData\\b|" + WORLD + "\\.(?:size|level|ground|country|props)\\b")


## Every hit under ROOT as a sorted list of keys.
func scan() -> PackedStringArray:
	var keys := {}
	for path: String in _files(ROOT):
		_scan_file(path, keys)
	var out := PackedStringArray(keys.keys())
	out.sort()
	return out


func _files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if dir_path in SKIP_DIRS:
		for f: String in KEEP_FILES:
			if f.begins_with(dir_path + "/"):
				out.append(f)
		return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f: String in dir.get_files():
		var p := dir_path + "/" + f
		if f.ends_with(".gd") and not p in SKIP_FILES:
			out.append(p)
	for d: String in dir.get_directories():
		out.append_array(_files(dir_path + "/" + d))
	return out


func _scan_file(path: String, keys: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(path)
	_scan_file_text(path.trim_prefix("res://"), text, _touches.search(text) != null, keys)


## One file's text; `worldly` says whether it holds a world at all.
func _scan_file_text(rel: String, text: String, worldly: bool, keys: Dictionary) -> void:
	var fn := "(class)"
	for raw: String in text.split("\n"):
		var line := _code(raw)
		var m := _func.search(line)
		if m != null:
			fn = m.get_string(1)
		if line.strip_edges() == "":
			continue
		if _list.search(line) != null:
			keys["%s::%s::list" % [rel, fn]] = true
		if _index.search(line) != null:
			keys["%s::%s::index" % [rel, fn]] = true
		var bare := line
		for k in 3:
			bare = _clamp.sub(bare, "0", true)
		if worldly and (_tiles.search(bare) != null or _walk.search(bare) != null):
			keys["%s::%s::tiles" % [rel, fn]] = true
		if _raw.search(line.strip_edges(false, true)) != null:
			keys["%s::%s::raw" % [rel, fn]] = true
		if _whole.search(line.strip_edges(false, true)) != null:
			keys["%s::%s::whole" % [rel, fn]] = true
		if _alloc.search(line) != null:
			keys["%s::%s::alloc" % [rel, fn]] = true
		for b: String in BUILDERS:
			if line.contains(b + "("):
				keys["%s::%s::builder %s" % [rel, fn, b]] = true


## The line without its comment. A `#` inside a string does not start one.
static func _code(line: String) -> String:
	var quote := ""
	var i := 0
	while i < line.length():
		var ch := line[i]
		if quote != "":
			if ch == "\\":
				i += 1
			elif ch == quote:
				quote = ""
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == "#":
			return line.substr(0, i)
		i += 1
	return line
