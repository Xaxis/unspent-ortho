extends TestCase
## WORLDGEN NEVER READS THE STORY. The story is cast from the finished world
## (StoryCasting, StoryPlan), and the world is never grown from the story: a
## stage that cast it would make what a seed grows hang on casting rules, which
## change with no GEN bump (parity at 256 cannot see a tread), and would cast on
## a half-made world (unpacked props, no roads or recipe yet), where keeper
## ground and every other world fact read differently. GenTreads._bearing did
## (#72). No code line under the worldgen names a Story class.

const FILES := ["res://src/core/world_gen.gd"]
const DIRS := ["res://src/core/worldgen"]


## `file:line: code` for each code line under the worldgen naming a Story class.
static func story_lines() -> Array[String]:
	var out: Array[String] = []
	var paths: Array[String] = []
	paths.assign(FILES)
	for d: String in DIRS:
		for f: String in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				paths.append(d.path_join(f))
	for p: String in paths:
		var n := 0
		for line: String in FileAccess.get_file_as_string(p).split("\n"):
			n += 1
			if names_story(line):
				out.append("%s:%d: %s" % [p, n, line.strip_edges()])
	return out


## Whether a line's code (not its comment) names a Story class.
static func names_story(line: String) -> bool:
	var code := line.split("#", true, 1)[0]
	var re := RegEx.create_from_string("\\bStory[A-Z]\\w*")
	return re.search(code) != null


func test_worldgen_never_casts_the_story() -> void:
	gt(float(DirAccess.get_files_at(DIRS[0]).size()), 10.0, "the worldgen's files were read")
	for hit: String in story_lines():
		check(false, "%s: worldgen reads the story; cast it from the finished world instead" % hit)


## The scan itself, on lines it must and must not catch, so a green run above
## cannot come from a scan that finds nothing.
func test_the_scan_sees_a_story_call_and_not_a_comment() -> void:
	check(names_story("\tfor place: Dictionary in StoryCasting.cast(w, StoryPlan.slots()).values():"), "a cast is seen")
	check(names_story("\tvar spine := StoryPlan.SPINE"), "a plan constant is seen")
	check(not names_story("\t# is the structure `StoryPlan.SPINE` has assumed"), "a comment is not")
	check(not names_story("## StoryCasting reads this row"), "a doc comment is not")
	check(not names_story("\tvar history := 3"), "a word that only contains it is not")
