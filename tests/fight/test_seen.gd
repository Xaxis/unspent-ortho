extends TestCase
## THE READERS SEE WHAT A PERSON SEES (tests/fight/seen.gd). A reader that
## decides on the brain's own clocks and flags measures a fight nobody plays:
## twice it did (#6, #26), and both times every balance number built on it
## moved. The readers' sources may read a body's motion only through Seen; the
## brain's run state, its timers and its intentions never appear in them.

const READERS: Array[String] = [
	"res://tests/fight/reader.gd",
	"res://tests/fight/crowd_reader.gd",
	"res://tests/fight/shoulder_reader.gd",
	"res://tests/fight/plate_reader.gd",
]

## MobState fields a person cannot see: the brain's flags, clocks and aims.
const HIDDEN: Array[String] = [
	"charging", "pause_until", "run_until", "run_from", "bearing", "flank_since", "route_until",
	"commanded", "stood_for", "last_think_pos", "lost_beats", "mood", "want", "aim",
	"calm_until", "rest_until", "closing_since", "detour_until", "look_until", "hunt",
	"hunt_i", "slew_until", "slew_to", "seal_until",
]


func test_the_readers_read_no_brain_state() -> void:
	var found: Array[String] = []
	for path: String in READERS:
		var text := FileAccess.get_file_as_string(path)
		var lines := text.split("\n")
		for i in lines.size():
			var line := lines[i]
			if line.strip_edges().begins_with("#"):
				continue
			for f: String in HIDDEN:
				var re := RegEx.create_from_string("\\.%s\\b" % f)
				if re.search(line) != null:
					found.append("%s:%d .%s" % [path.get_file(), i + 1, f])
	check(found.is_empty(), "the readers read a body only through Seen (%s)" % ", ".join(found))
