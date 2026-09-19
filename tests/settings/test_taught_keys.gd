extends TestCase
## Every key the glass names is ASKED OF THE LIVE INPUTMAP, never spelled.
##
## A key cap (`UiSlate.key_cap`) letters whatever string it is handed, so a
## literal is a promise about the keyboard made by a file that cannot see one.
## `PlayerSettings` reads the LIVE `InputMap` and was already the rule for the
## keys PAGE ("so a page can never drift from the keys again"); everything else
## spelled its own.
##
## **WHAT WAS ACTUALLY WRONG, after checking which strings reach the screen** --
## because the first reading of this was wrong and the wrong half is instructive:
##
##   THE TWO CAPS A PLAYER SEES MOST were typed in. `90_ui` passed "e" for the
##   use prompt and "c" for making. Rebind `use` and the glass goes on saying E
##   for the rest of the game.
##
##   THREE LESSONS LETTERED A KEY INTO THEIR WORDS: "hold E on each" (34_works),
##   "E to go down" (20_realms), "Step off again: b." (44_crafts). Those are
##   sentences, so no cap is involved and nothing could catch them.
##
##   AND THE `Events.hint` KEY ARGUMENT REACHES NOTHING. `Hud.teach(text, _key)`
##   discards it -- the guide's key gets to a cap by another road (`90_ui._teach`).
##   So the five systems passing one were passing it nowhere. They are corrected
##   rather than emptied, because a dead argument that is also wrong is the one
##   that bites whenever somebody wires it up.
##
## The first two halves are what a player would have seen. The third is why no
## test and no frame ever showed it.

const SRC := "res://src/"

## The calls that hand a string to a key cap. `set_hint` is the one that reaches
## the glass today and `Events.hint.emit` is the one that will when somebody
## wires it; both are held, because which of them was live is exactly the thing
## nobody checked.
const CAP_CALLS: PackedStringArray = ["Events.hint.emit(", "set_hint("]


## A key argument may be empty (a line that names no key) or a call. What it may
## never be is a spelled-out string.
func test_nothing_spells_a_key_cap() -> void:
	var bad: Array[String] = []
	for path: String in _scripts(SRC):
		if path.ends_with("/hud.gd"):
			continue  # its own default, for a caller that passes nothing.
		var text := FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			for call: String in CAP_CALLS:
				var at := line.find(call)
				if at < 0:
					continue
				var key := _key_argument(line.substr(at + call.length() - 1))
				if key == "" or key == "\"\"" or not key.begins_with("\""):
					continue
				bad.append("%s: cap %s is spelled, not asked" % [path.get_file(), key])
	check(bad.is_empty(), "\n".join(bad))


## The other half: a line that NAMES a key in its words has to interpolate it.
## "hold E on each" reads fine and is a lie the moment `use` moves.
func test_no_lesson_letters_a_key_into_its_words() -> void:
	# The words a key is named with, as a lesson would write them.
	var spelled := RegEx.create_from_string("(: [a-z]\\.|\\b(hold|press|tap) [A-Z]\\b|\\b[A-Z] to \\w)")
	var bad: Array[String] = []
	for path: String in _scripts(SRC):
		var text := FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			if not line.contains("Events.hint.emit(") and not line.contains("PlayerSettings.spell("):
				continue
			if line.contains("PlayerSettings."):
				continue
			var m := spelled.search(line)
			if m != null:
				bad.append("%s: %s" % [path.get_file(), m.get_string().strip_edges()])
	check(bad.is_empty(), "\n".join(bad))


## And the live half, which the source scan cannot answer: rebind a key and the
## words follow it. If they do not, the two tests above are checking a habit
## rather than a result.
func test_rebinding_a_key_moves_what_the_lesson_says() -> void:
	var was := PlayerSettings.key_of(&"use")
	check(was != KEY_NONE, "use is on a key to begin with")
	eq(PlayerSettings.label_of(&"use"), OS.get_keycode_string(was), "it is named as itself")
	var line := "A steel edge, and hold %s on each."
	check(PlayerSettings.spell(line, [&"use"]).contains(OS.get_keycode_string(was)), "the line names it")
	# Move it, and the same line says the new key.
	PlayerSettings.bind_key(&"use", KEY_P)
	eq(PlayerSettings.label_of(&"use"), "P", "rebound, it is named P")
	eq(PlayerSettings.cap_of(&"use"), "p", "and the cap wears it lowercase")
	check(PlayerSettings.spell(line, [&"use"]).contains("hold P on"), "and the words follow")
	PlayerSettings.reset_keys()
	eq(PlayerSettings.key_of(&"use"), was, "put back")


## A cluster is one word: WASD while those are its keys, and not after.
func test_a_cluster_of_keys_reads_as_one_word() -> void:
	eq(PlayerSettings.label_of([&"move_up", &"move_left", &"move_down", &"move_right"]), "WASD",
		"the walking keys as they ship")
	eq(PlayerSettings.label_of(&"nothing_is_bound_to_this"), "", "an action nobody declared names no key")


## The standing goal line is the third road to the glass, and it goes through
## CORE, which may not read a key at all -- `guide.gd` says so itself. So a goal
## may not name one, and the lesson beside it carries the key instead.
func test_no_goal_line_names_a_key() -> void:
	# Inside the QUOTED text only. `str(n)` is not a key cap, and a regex loose
	# enough to match it reports every single-letter argument in core.
	# The LEGEND form a key is written in -- " (f)." -- and nothing else. Matching
	# any parenthesised letter caught `str(n)`; matching inside a quote run
	# caught `height_at(q), ` across the gap between two literals.
	var spelled := RegEx.create_from_string("\\s\\([a-z]\\)\\.")
	var bad: Array[String] = []
	for path: String in _scripts("res://src/core/"):
		var text := FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			var m := spelled.search(line)
			if m != null:
				bad.append("%s: %s" % [path.get_file(), m.get_string()])
	check(bad.is_empty(), "\n".join(bad))


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for name: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(name)))
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	return out


## The second argument of an `Events.hint.emit(...)` call, as written.
func _key_argument(call: String) -> String:
	var depth := 0
	var quoted := false
	var start := -1
	for i in call.length():
		var c := call[i]
		if c == "\"":
			quoted = not quoted
		if quoted:
			continue
		if c == "(" or c == "[":
			depth += 1
			if depth == 1:
				start = i + 1
		elif c == ")" or c == "]":
			depth -= 1
			if depth == 0:
				return call.substr(start, i - start).split(",")[-1].strip_edges() if start >= 0 else ""
		elif c == "," and depth == 1:
			start = i + 1
	return ""
