extends TestCase
## A recipe asked over a WINDOW answers each tile as it would over the whole
## world (streamed worldgen S4a): a section lays its own window, and a pattern a
## landscape rules on the land must not start again at each window's corner.


const DrownedCity := preload("res://src/content/biomes/drowned_city.gd")


static func _surface(size: int, x0: int, y0: int) -> BiomeSurface:
	var t := BiomeSurface.new()
	t.size = size
	t.x0 = x0
	t.y0 = y0
	t.seed_value = 7
	return t


## The drowned city's streets: the one recipe that reads where a tile stands.
## A 40-tile window set at (123, 57) inside a 512 world must put its streets
## on the tiles the whole world puts them on.
func test_the_drowned_city_rules_its_streets_on_the_world_not_the_window() -> void:
	var whole := _surface(512, 0, 0)
	var win := _surface(40, 123, 57)
	var streets := 0
	var differ := 0
	for y in 40:
		for x in 40:
			var a: bool = DrownedCity._street(whole, (57 + y) * 512 + 123 + x)
			var b: bool = DrownedCity._street(win, y * 40 + x)
			streets += 1 if a else 0
			differ += 1 if a != b else 0
	gt(float(streets), 100.0, "the window holds streets to compare")
	eq(differ, 0, "and every tile of the window is a street exactly where the world's is")


## No recipe takes a tile's place from `i` without the window's origin: that is
## the whole world's corner, not the window's, and a section would lay its
## pattern from its own corner (the drowned city's streets did, until S4a).
func test_no_recipe_places_a_tile_without_its_window() -> void:
	var bare := RegEx.create_from_string("\\bi\\s*[%/]\\s*t\\.size")
	var bad: PackedStringArray = []
	var dir := DirAccess.open("res://src/content/biomes")
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string("res://src/content/biomes/" + f).split("\n")
		for n in lines.size():
			var line := lines[n]
			if bare.search(line) != null and not (line.contains("t.x0") or line.contains("t.y0")):
				bad.append("%s:%d" % [f, n + 1])
	eq(bad.size(), 0, "recipes place tiles through the window's origin: %s" % ", ".join(bad))
