extends TestCase
## The tours are the evidence every wave is read from, so the gate reads them as
## a language and not as text. Wave A2 found a frame named "a keeper at noon"
## with no keeper in it: the tour had said `spawn warden`, waited, and shot,
## and nothing anywhere asked whether a warden had been put out. These rules
## make that shape impossible to write again.

const TOUR_DIR := "res://tours"
const TOUR := preload("res://src/systems/98_tour.gd")

## Every word the runner's match statement answers to.
const COMMANDS := ["at", "near", "ground", "place", "village", "hour", "zoom", "weather",
	"walk", "press", "hold", "release", "tap", "wait", "shot", "await", "spawn", "choose",
	"coast", "walkto", "perf", "echo", "key", "same", "try", "end"]
## Subject prefixes with something to check behind them.
const BODY_PREFIXES := ["mob:", "down:", "body:"]


func tours() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(TOUR_DIR)
	if d == null:
		fail("no %s" % TOUR_DIR)
		return out
	for f in d.get_files():
		if f.ends_with(".tour"):
			out.append(f)
	out.sort()
	return out


func lines_of(f: String) -> PackedStringArray:
	var file := FileAccess.open(TOUR_DIR.path_join(f), FileAccess.READ)
	if file == null:
		fail("cannot read %s" % f)
		return PackedStringArray()
	return file.get_as_text().split("\n")


## A typo is a command the runner does not know, and it already fails a tour at
## run time — a minute in. The gate says so in a second instead.
func test_every_command_is_one_the_runner_knows() -> void:
	for f: String in tours():
		var n := 0
		for raw: String in lines_of(f):
			n += 1
			var line := raw.strip_edges()
			if line == "" or line.begins_with("#"):
				continue
			var cmd := line.split(" ", false)[0]
			check(COMMANDS.has(cmd), "%s line %d: unknown command '%s'" % [f, n, cmd])


## A shot may only claim a subject in a shape the runner can answer: a roster
## kind that exists, a landscape the registry holds, a colour it can count.
func test_every_claimed_subject_is_one_the_runner_can_answer() -> void:
	var lands: Array[StringName] = []
	for def: BiomeDef in BiomeRegistry.all():
		lands.append(def.id)
	for f: String in tours():
		var n := 0
		for raw: String in lines_of(f):
			n += 1
			var parts := raw.strip_edges().split(" ", false)
			if parts.size() < 3 or parts[0] != "shot":
				continue
			check(parts[1] != "" and parts[2] == "with" and parts.size() > 3,
				"%s line %d: a shot takes a name and then `with SUBJECT[,SUBJECT]`" % [f, n])
			if parts.size() < 4:
				continue
			for w: String in " ".join(Array(parts).slice(3)).split(",", false):
				var subject := w.strip_edges()
				check(not TOUR.EVENTS.has(subject),
					"%s line %d: `%s` happens, a frame cannot hold it; await it" % [f, n, subject])
				for p: String in BODY_PREFIXES:
					if subject.begins_with(p):
						check(Roster.resolve(subject.substr(p.length())) != &"",
							"%s line %d: the roster has no %s" % [f, n, subject])
				if subject.begins_with("land:"):
					check(lands.has(StringName(subject.substr(5))),
						"%s line %d: no landscape type %s" % [f, n, subject])
				if subject.begins_with("pixels:"):
					var bits := subject.split(":")
					check(bits.size() >= 2 and not bits[1].is_empty(), "%s line %d: %s needs a colour" % [f, n, subject])
					for hex: String in bits[1].split("+", false):
						check(hex.length() == 6 and hex.is_valid_hex_number(),
							"%s line %d: %s is not RRGGBB" % [f, n, hex])
					if bits.size() > 2:
						check(bits[2].is_valid_int() and bits[2].to_int() > 0,
							"%s line %d: %s wants a count above zero" % [f, n, subject])


## The wave A hole itself: a body put out and then photographed, with nothing in
## between asking whether it was ever there. The first frame after a `spawn` has
## to be a frame that says it is of that body.
func test_a_spawn_is_always_followed_by_a_frame_that_claims_it() -> void:
	for f: String in tours():
		var n := 0
		var owed: Array[String] = []
		var owed_line := 0
		for raw: String in lines_of(f):
			n += 1
			var parts := raw.strip_edges().split(" ", false)
			if parts.is_empty() or parts[0].begins_with("#"):
				continue
			if parts[0] == "spawn" and parts.size() > 1:
				var id := Roster.resolve(parts[1])
				check(id != &"", "%s line %d: the roster has no %s" % [f, n, parts[1]])
				if not owed.has(String(id)):
					owed.append(String(id))
				owed_line = n
				continue
			if parts[0] != "shot":
				continue
			if owed.is_empty():
				continue
			var claimed: Array[String] = []
			if parts.size() > 3 and parts[2] == "with":
				for w: String in " ".join(Array(parts).slice(3)).split(",", false):
					var subject := w.strip_edges()
					for p: String in BODY_PREFIXES:
						if subject.begins_with(p):
							claimed.append(String(Roster.resolve(subject.substr(p.length()))))
			for want: String in owed:
				check(claimed.has(want),
					"%s: `spawn %s` on line %d, and the next frame (%s, line %d) never says it holds one" % [f, want, owed_line, parts[1], n])
			owed.clear()


## The counter behind `pixels:`: a picture whose answer is known by construction.
func test_the_pixel_subject_counts_what_is_there() -> void:
	var img := Image.create_empty(10, 10, false, Image.FORMAT_RGB8)
	img.fill(Color8(20, 20, 30))
	for x in 5:
		img.set_pixel(x, 0, Color8(140, 255, 89))
	eq(TOUR.pixels_like(img, "pixels:8cff59:1"), 5, "the five green pixels")
	eq(TOUR.pixels_like(img, "pixels:ff40cc:1"), 0, "no magenta anywhere in it")
	eq(TOUR.pixels_like(img, "pixels:4df2ff+8cff59:1"), 5, "either colour counts")
	# A near miss inside the tolerance still counts; a far one never does.
	var shifted := Color8(140 + TOUR.PIXEL_TOLERANCE - 1, 255, 89)
	img.set_pixel(9, 9, shifted)
	eq(TOUR.pixels_like(img, "pixels:8cff59:1"), 6, "a pixel a shade off is the same tube")
	# The tolerance is wide, so a `pixels:` subject only means anything for a
	# colour nothing else on screen wears: the near-black ground here is within
	# it of black, and would be of any other near-black asked for.
	eq(TOUR.pixels_like(img, "pixels:ff0000:1"), 0, "nothing in it is red")
	gt(TOUR.pixels_like(img, "pixels:000000:1"), 50.0, "a near-black wanted matches near-black ground")
