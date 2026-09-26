extends TestCase
## The tours are the evidence every wave is read from, so the gate reads them as
## a language and not as text. Wave A2 found a frame named "a keeper at noon"
## with no keeper in it: the tour had said `spawn warden`, waited, and shot,
## and nothing anywhere asked whether a warden had been put out. These rules
## make that shape impossible to write again.

const TOUR_DIR := "res://tours"
const TOUR := preload("res://src/systems/98_tour.gd")

## Every word the runner's match statement answers to. A package that teaches the
## runner a new command adds it here in the same commit: `stale` reached main in
## the saves package while this list was being written in another worktree, and
## the first thing the merged gate said was that saves-elsewhere.tour was
## speaking a word no tour could use. That is the rule working, but it only
## works if the list is kept beside the runner.
const COMMANDS := ["at", "near", "ground", "place", "ledge", "leap", "village", "hour", "zoom", "weather",
	"walk", "press", "hold", "release", "tap", "wait", "shot", "await", "until", "spawn",
	"choose", "coast", "walkto", "perf", "echo", "key", "mouse", "same", "try", "end", "stale", "under", "over", "wound",
	"mark", "back"]
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
					for id: String in subject.substr(5).split("|", false):
						check(lands.has(StringName(id)),
							"%s line %d: no landscape type %s" % [f, n, id])
				if subject.begins_with("border:"):
					var pair := subject.substr(7).split("-", false)
					check(pair.size() == 2, "%s line %d: %s wants two ids joined by a dash" % [f, n, subject])
					for id: String in pair:
						check(lands.has(StringName(id)),
							"%s line %d: no landscape type %s" % [f, n, id])
				if subject.begins_with("prop:"):
					check(PropKind.NAMES.has(subject.substr(5).replace("_", " ")),
						"%s line %d: no prop kind %s" % [f, n, subject])
				if subject.begins_with("pixels:"):
					var bits := subject.split(":")
					check(bits.size() >= 2 and not bits[1].is_empty(), "%s line %d: %s needs a colour" % [f, n, subject])
					for hex: String in bits[1].split("+", false):
						check(hex.length() == 6 and hex.is_valid_hex_number(),
							"%s line %d: %s is not RRGGBB" % [f, n, hex])
					if bits.size() > 2:
						check(bits[2].is_valid_int() and bits[2].to_int() > 0,
							"%s line %d: %s wants a count above zero" % [f, n, subject])


## The other way a tour asks for something and silently does not get it: a name
## the runner looks up and does not find. `near boulder,stone ore` split on the
## space and asked for boulders and nothing else for a year; an action nobody
## bound is pressed into the void with an engine error the tour runner does not
## read as a failure.
func test_every_name_a_tour_asks_for_exists() -> void:
	# The control scheme is on the map before a tour's first line, as boot puts
	# it there (main.gd): its actions (the lock's cycle keys, the peek, the look)
	# are not in project.godot's list either.
	PlayerSettings.load_once()
	for f: String in tours():
		var n := 0
		for raw: String in lines_of(f):
			n += 1
			var parts := raw.strip_edges().split(" ", false)
			if parts.is_empty() or parts[0].begins_with("#"):
				continue
			match parts[0]:
				"near":
					check(parts.size() == 2, "%s line %d: `near` takes one comma-joined list; write a space as _" % [f, n])
					for k: String in parts[1].split(",", false):
						check(PropKind.NAMES.has(k.replace("_", " ")) or _system_places().has(k),
							"%s line %d: no prop kind %s, and no system stands you by one" % [f, n, k])
				"ground":
					check(parts.size() == 2, "%s line %d: `ground` takes one comma-joined list; write a space as _" % [f, n])
					for k: String in parts[1].split(",", false):
						check(Ground.NAMES.has(k.replace("_", " ")), "%s line %d: no ground %s" % [f, n, k])
				"back":
					for k: String in parts[1].split(",", false):
						check(PropKind.NAMES.has(k.replace("_", " ")), "%s line %d: no prop kind %s to stand back from" % [f, n, k])
				"at":
					if parts[1].begins_with("prop:"):
						var k := parts[1].substr(5).replace("_", " ")
						check(PropKind.NAMES.has(k), "%s line %d: no prop kind %s" % [f, n, k])
					# Stage by name, never by coordinate: a number off one world's
					# map lands somewhere else on the next (CLAUDE.md).
					var xy := parts[1].split(",")
					check(not (xy.size() == 2 and xy[0].is_valid_float() and xy[1].is_valid_float()),
						"%s line %d: `at %s` is a coordinate; stand by a name (prop:, mark:, a place)" % [f, n, parts[1]])
				"press", "tap", "hold", "release", "key":
					# Dev mode's own keys are added to the map while it can be
					# reached, so they are not in project.godot's list.
					check(InputMap.has_action(parts[1]) or DevMode.ACTIONS.has(StringName(parts[1])),
						"%s line %d: nothing is bound to '%s'" % [f, n, parts[1]])
				"walkto":
					if parts[1].begins_with("prop:"):
						for k: String in parts[1].substr(5).split(",", false):
							check(PropKind.NAMES.has(k.replace("_", " ")), "%s line %d: no prop kind %s to walk to" % [f, n, k])
						continue
					check(parts[1] in (load("res://src/systems/98_tour.gd") as GDScript).get("WALK_TARGETS"),
						"%s line %d: cannot walk to '%s'" % [f, n, parts[1]])


## The names a system answers `near NAME` with instead of a prop kind: every
## `TOUR_PLACES` a script under src/systems declares (19_colossi's feet).
static func _system_places() -> Array:
	var out: Array = []
	for f: String in DirAccess.get_files_at("res://src/systems"):
		if not f.ends_with(".gd"):
			continue
		var script := load("res://src/systems/" + f) as GDScript
		if script != null and script.get_script_constant_map().has("TOUR_PLACES"):
			out.append_array(script.get_script_constant_map()["TOUR_PLACES"])
	return out


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
			if parts[0] in ["spawn", "under", "over"] and parts.size() > 1:
				# Through the same door the tour and boot read it by, so a token
				# that carries a bearing (`runner@-112`) is still held to naming
				# a kind the roster has.
				var id: StringName = Spawner.staged(parts[1]).id
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


## Words in a frame's NAME that the tour vocabulary can be asked about, and the
## declaration each one owes. A `with` is otherwise voluntary, and a voluntary
## rule is kept by whoever last read the file: the sweep that found the keeper
## at noon found sixteen dozen more frames naming a landscape, a fire, a lamp or
## a crowd and saying nothing about it, which is one sweep away from the same
## lie again.
const PEOPLE := {"crowd": "crowd", "folk": "folk", "villager": "folk",
	"villagers": "folk", "gulls": "gulls", "dog": "dog"}
## A name that says something HAPPENED: a frame cannot hold an event, so what it
## owes is an `await` between it and the frame before it.
const EVENT_WORDS := ["taken", "took", "made", "built", "killed"]
## A machine is in the picture, said in the machines' own words. Which machine
## the name does not say, so what this owes is a declaration of any kind.
const MACHINE_WORDS := ["worker", "workers", "keeper", "keepers", "machine",
	"machines", "its-round", "its-rounds", "their-round", "their-rounds"]


## Compound adjectives that carry an EVENT_WORD without claiming an event.
## "hand-built" says how a house was made, not that anything happened while the
## tour was watching, and a frame cannot await a thing that was true before it
## arrived. This is the misfire this package's own brief warned about — a
## matcher over prose written for a human will sometimes fire on the prose —
## so it is answered by naming the exceptions rather than by making builders
## rename honest frames to please the checker.
const NOT_EVENTS := ["hand-built", "hand-made", "machine-made", "machine-built", "well-made"]


## Whether `name` (hyphen-separated) carries `word` as a whole word or phrase.
static func names_it(shot_name: String, word: String) -> bool:
	return ("-%s-" % shot_name).contains("-%s-" % word)


## The same, for a word that only counts when it is not half of a compound.
static func claims_event(shot_name: String, word: String) -> bool:
	if not names_it(shot_name, word):
		return false
	for phrase: String in NOT_EVENTS:
		if ("-%s-" % shot_name).contains("-%s-" % phrase):
			return false
	return true


func test_a_frame_named_after_something_says_what_it_holds() -> void:
	var lands: Array[String] = []
	for def: BiomeDef in BiomeRegistry.all():
		lands.append(String(def.id))
	var kinds: Array[String] = []
	for id: StringName in Roster.DEFS:
		var prefix := String(id).split(".")[0]
		if not kinds.has(prefix):
			kinds.append(prefix)
	for f: String in tours():
		var n := 0
		var awaited := 0
		for raw: String in lines_of(f):
			n += 1
			var parts := raw.strip_edges().split(" ", false)
			if parts.is_empty() or parts[0].begins_with("#"):
				continue
			if parts[0] == "await":
				awaited += 1
				continue
			if parts[0] != "shot":
				continue
			var label := parts[1]
			var subjects: Array[String] = []
			if parts.size() > 3 and parts[2] == "with":
				for w: String in " ".join(Array(parts).slice(3)).split(",", false):
					subjects.append(w.strip_edges())
			var bodies: Array[String] = []
			for s: String in subjects:
				for p: String in BODY_PREFIXES:
					if s.begins_with(p):
						bodies.append(String(Roster.resolve(s.substr(p.length()))).split(".")[0])
			for k: String in kinds:
				if names_it(label, k):
					check(bodies.has(k) or subjects.has(k),
						"%s line %d: %s names a %s and never says one is in it" % [f, n, label, k])
			# A frame named after a landscape says which ground it is of. A name
			# that carries two is of their border, and either answer is honest.
			var named: Array[String] = []
			for id: String in lands:
				if names_it(label, id.replace("_", "-")):
					named.append(id)
			if not named.is_empty() and not names_it(label, "title"):
				var said := false
				for s: String in subjects:
					if s.begins_with("land:"):
						for id: String in s.substr(5).split("|", false):
							said = said or named.has(id)
					if s.begins_with("border:"):
						# Every landscape the NAME carries has to be one of the two, but
						# the name need not carry both: "coast meets salt" is a frame of
						# the coast/salt_flats border and says so. Requiring both spelled
						# out made this a rule about how a frame is NAMED rather than about
						# what it DECLARES, which is the opposite of the point.
						var pair := s.substr(7).split("-", false)
						var within := pair.size() == 2
						for id: String in named:
							within = within and pair.has(id)
						said = said or within
				check(said, "%s line %d: %s names %s and never says which ground it is on"
					% [f, n, label, ", ".join(named)])
			if names_it(label, "lamp"):
				check(subjects.has("lamp") or subjects.has("unlit"),
					"%s line %d: %s names the lamp and never says whether it is lit" % [f, n, label])
			for word: String in PEOPLE:
				if names_it(label, word) and not subjects.has(String(PEOPLE[word])) and bodies.is_empty():
					fail("%s line %d: %s names %s and never says one is in it" % [f, n, label, word])
			# "fire tower" is a tower, not a fire.
			if names_it(label, "fire") and not names_it(label, "fire-tower"):
				check(subjects.has("station:fire"),
					"%s line %d: %s names a fire and never says one is in reach" % [f, n, label])
			if names_it(label, "pylon"):
				check(subjects.has("prop:pylon"),
					"%s line %d: %s names a pylon and never says one is in frame" % [f, n, label])
			if names_it(label, "neon"):
				var counted := false
				for s: String in subjects:
					counted = counted or s.begins_with("pixels:")
				check(counted, "%s line %d: %s names the neon and never counts a tube" % [f, n, label])
			for word: String in EVENT_WORDS:
				if claims_event(label, word):
					check(awaited > 0,
						"%s line %d: %s says something happened and nothing was awaited since the frame before it"
						% [f, n, label])
			for word: String in MACHINE_WORDS:
				if names_it(label, word):
					check(not subjects.is_empty(),
						"%s line %d: %s says a machine is in it and declares nothing" % [f, n, label])
			awaited = 0


func test_the_name_reader_reads_whole_words() -> void:
	check(names_it("07-salt-flats-noon", "salt-flats"), "a two-word landscape")
	check(names_it("14-crowd-of-24", "crowd"), "a word in the middle")
	check(names_it("06-lamp", "lamp"), "a word at the end")
	check(names_it("12-pinewood-fire-tower-day", "fire-tower"), "a phrase, so a tower is not a fire")
	check(not names_it("05-watching", "watcher"), "watching is not a watcher")
	check(not names_it("16-slid-round-the-tree", "its-round"), "slid round a tree is not a machine's round")


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


## A tube is emission, so what reaches the picture is its colour carried some way
## toward white — and the cap on how far is what stops every pale thing on the
## glass counting as every tube that was asked for.
func test_a_tube_counts_washed_toward_white_but_only_so_far() -> void:
	var img := Image.create_empty(10, 10, false, Image.FORMAT_RGB8)
	img.fill(Color8(20, 20, 30))
	# The magenta tube as it actually arrives: along the run, and at its core.
	img.set_pixel(0, 0, Color8(217, 136, 217))
	img.set_pixel(1, 0, Color8(255, 160, 255))
	eq(TOUR.pixels_like(img, "pixels:ff40cc:1"), 2, "the tube's own colour, washed by its own light")
	eq(TOUR.pixels_like(img, "pixels:8cff59:1"), 0, "a magenta tube is not a green one")
	eq(TOUR.pixels_like(img, "pixels:4df2ff:1"), 0, "nor a cyan one")
	# White is where every colour ends up, so it must belong to none of them:
	# uncapped, the slate's own phosphor and the sea's foam answer for any tube
	# that is asked for. The two greens here are the real thing, measured off the
	# message line and the location label of a frame carrying no tube at all.
	img.set_pixel(5, 5, Color8(255, 255, 255))
	img.set_pixel(6, 5, Color8(108, 174, 145))
	img.set_pixel(7, 5, Color8(63, 124, 103))
	eq(TOUR.pixels_like(img, "pixels:ff40cc:1"), 2, "white is not a magenta tube")
	eq(TOUR.pixels_like(img, "pixels:8cff59:1"), 0, "nor is the glass's own green text")


# --- an await means SINCE I LAST ASKED ----------------------------------------

const SYSTEM_DIR := "res://src/systems"


## Every `src/systems/NN_*.gd`, in name order.
func system_files() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(SYSTEM_DIR)
	if d == null:
		fail("no %s" % SYSTEM_DIR)
		return out
	for f in d.get_files():
		if f.ends_with(".gd") and f.length() > 2 and f[0].is_valid_int() and f[1].is_valid_int():
			out.append(f)
	out.sort()
	return out


func source_of(f: String) -> PackedStringArray:
	var file := FileAccess.open(SYSTEM_DIR.path_join(f), FileAccess.READ)
	if file == null:
		fail("cannot read %s" % f)
		return PackedStringArray()
	return file.get_as_text().split("\n")


## The literal words a file's `tour_seen` answers from the LIVE world: the arms
## of its own match statement. Multiple keys may share one arm.
func live_keys(lines: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	var inside := false
	var quoted := RegEx.create_from_string('&?"([^"]*)"')
	for raw: String in lines:
		if raw.begins_with("func tour_seen"):
			inside = true
			continue
		if inside and raw.begins_with("func "):
			break
		if not inside:
			continue
		var line := raw.split("#")[0].strip_edges()
		# A match arm and nothing else: quoted words, then a colon.
		if not line.ends_with(":") or not (line.begins_with('"') or line.begins_with('&"')):
			continue
		for m in quoted.search_all(line):
			out.append(m.get_string(1))
	return out


## Every word a file latches with a literal key. An interpolated one
## (`_seen["raid:%s" % stage]`) is deliberately not counted: it is not a word.
func latched_keys(lines: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	var write := RegEx.create_from_string('_seen\\[&?"([^"]*)"\\]\\s*=')
	for raw: String in lines:
		var m := write.search(raw.split("#")[0])
		if m != null:
			out.append(m.get_string(1))
	return out


## A LATCH IS THE DECLARATION THAT A KEY IS AN EVENT. So a latch standing in
## front of a live computation of the same word is not belt and braces: it is the
## only thing that can make the answer WRONG, because the live half is consulted
## second and never gets to say no.
##
## Three were found this way and all three were pure hazard: `works_broken` and
## `sentinel_fallen` each sat in front of a scan that answers the same question
## durably, and `_seen["party"]` in 48_raids could never be read at all, because
## that file's match runs first. A fourth of the same shape is one line away in
## any package, and nothing else in the gate would notice it.
func test_no_system_latches_a_word_it_already_answers_live() -> void:
	for f: String in system_files():
		var lines := source_of(f)
		var live := live_keys(lines)
		if live.is_empty():
			continue
		for key: String in latched_keys(lines):
			check(not live.has(key),
				"%s latches '%s' in front of its own match arm for it: delete the latch, or the world's answer can never say no" % [f, key])


## A latch that is never spent answers every await after the first for free —
## which is exactly the bug this rule exists for: machine-read.tour pressed `use`
## once where a survey post needs three, robbed nothing, and `await theft` passed
## anyway off a theft earlier in the run. Only the runner knows when a tour asked,
## so a system that latches must take `tour_forget` and erase there.
func test_every_latching_system_spends_its_latches() -> void:
	for f: String in system_files():
		if f.begins_with("98_"):
			continue  # the runner's own dictionary, erased in `_forget` itself
		var lines := source_of(f)
		if latched_keys(lines).is_empty():
			continue
		var has := false
		for raw: String in lines:
			if raw.begins_with("func tour_forget"):
				has = true
				break
		check(has, "%s latches a tour word but never spends it: add `func tour_forget(what: StringName) -> void: _seen.erase(what)`" % f)
