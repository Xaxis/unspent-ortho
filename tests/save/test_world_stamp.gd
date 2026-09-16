extends TestCase
## The test that would have caught M2 wave A.
##
## A save keeps only the seed and grows the world again on load, so a build
## whose landscape registry has moved opens a DIFFERENT ISLAND from the same
## seed. Wave A added salt_flats and scrapwood and moved 8-10% of every world's
## tiles into another landscape; nothing noticed. Here the registry is moved
## both ways — a type muted out, a type added — and each time the save written
## before the move must be refused by name, with the reason the player reads.

const Sx := preload("res://tests/save/save_fixture.gd")
const SIX: Array[StringName] = [&"coast", &"moss", &"pinewood", &"snowfield", &"bonelands", &"burning"]

const HEADER := {"clock": "day 2  14:30", "place": "moss", "landscape": "moss", "saved_at": 100.0,
	"seed": 3, "size": 64, "pos": [10.5, 20.25], "minutes": 2310.0, "play_seconds": 4000.0}


## Muting the registry is global state; the guard puts it back however the test
## leaves (tests/biome/test_parity.gd does the same, for the same reason).
class Muted extends RefCounted:
	func _init(ids: Array[StringName]) -> void:
		BiomeRegistry.mute_to(ids)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			BiomeRegistry.mute_to([])


# --- the stamp itself --------------------------------------------------------

func test_the_stamp_is_the_same_run_to_run_and_moves_when_the_registry_does() -> void:
	var whole := WorldStamp.current()
	eq(WorldStamp.current(), whole, "the same registry stamps the same twice")
	eq(whole.length(), 8, "eight hex digits: %s" % whole)
	check(whole != WorldStamp.UNKNOWN, "and never the unknown stamp")

	# A type taken out of the registry: another island, another stamp.
	var guard := Muted.new(SIX)
	var six := WorldStamp.current()
	check(six != whole, "the six alone stamp differently from the whole registry")
	guard = null
	eq(WorldStamp.current(), whole, "and the whole registry stamps as it did")


func test_the_stamp_is_worked_out_afresh_and_never_handed_back_stale() -> void:
	# It was held between calls, keyed on the registry's ids — so a landscape
	# retuned IN PLACE, ids unchanged, kept the old stamp: the one function whose
	# whole job is to notice change, not noticing it. Spelling it out costs 1.3 ms,
	# which is why SaveSlots.list asks once for all four slots instead.
	var was := WorldStamp.current()
	var d := BiomeRegistry.all()[0]
	var keep := d.share
	d.share = Vector2(0.123, 0.456)
	var moved := WorldStamp.current()
	d.share = keep
	check(moved != was, "a landscape retuned in place moves the stamp at once")
	eq(WorldStamp.current(), was, "and putting it back puts the stamp back")


func test_a_read_holds_a_save_to_the_stamp_it_is_handed() -> void:
	Sx.use_root("stamp-handed")
	var p := SaveSlots.path(1)
	eq(SaveFile.write(p, HEADER, _data(WorldStamp.current())), OK)
	check(SaveFile.read_header(p, WorldStamp.current()).ok, "this build's stamp opens it")
	var other := SaveFile.read_header(p, "deadbeef")
	check(not other.ok, "another build's does not")
	eq(other.code, &"elsewhere")
	Sx.finish()


func test_a_type_added_or_reordered_moves_the_stamp_and_a_repaint_does_not() -> void:
	var defs := BiomeRegistry.all()
	var base := WorldStamp.of(defs)
	eq(base, WorldStamp.current(), "the registry's own list stamps as current()")

	# A landscape added — what wave A did, and what M3 will do a dozen times.
	var added := defs.duplicate()
	added.append(_fake(&"undercroft", 12))
	check(WorldStamp.of(added) != base, "a landscape joining the registry moves the stamp")

	# The same types in another order get other indices, so other tiles.
	var swapped := defs.duplicate()
	var last := swapped.size() - 1
	var keep: BiomeDef = swapped[last]
	swapped[last] = swapped[last - 1]
	swapped[last - 1] = keep
	check(WorldStamp.of(swapped) != base, "the same types reordered move the stamp")

	# A landscape retuned where worldgen reads it: another island.
	var relieved := _copy(defs)
	relieved[relieved.size() - 1].relief[&"hills"] = 9.75
	check(WorldStamp.of(relieved) != base, "a relief number moves the stamp")
	var shared := _copy(defs)
	shared[shared.size() - 1].share = Vector2(0.4, 0.5)
	check(WorldStamp.of(shared) != base, "a share moves the stamp")
	var settled := _copy(defs)
	settled[settled.size() - 1].villages += 1
	check(WorldStamp.of(settled) != base, "a village moves the stamp")

	# But a landscape REPAINTED is the same island, and must not cost the player
	# their game: the look, the weather, the hazards and the roster are outside
	# the stamp on purpose.
	var painted := _copy(defs)
	var d := painted[painted.size() - 1]
	d.grounds[Ground.GRASS] = Color(0.9, 0.1, 0.2)
	d.light_tint = Color(0.3, 0.9, 0.4)
	d.hazards[&"cold"] = 0.77
	d.sound_bed = &"bed_nothing"
	d.display_name = "Somewhere Else"
	eq(WorldStamp.of(painted), base, "a repaint, a new hazard and a new sound do not move the stamp")


func test_every_field_on_a_landscape_is_classified_as_terrain_or_look() -> void:
	# The stamp can only cover what it knows about. A field added to BiomeDef and
	# left out of both lists is a hole the next wave falls through, so this fails
	# until whoever added it says which side it is on.
	var known := {}
	for f in WorldStamp.TERRAIN:
		known[f] = "terrain"
	for f in WorldStamp.LOOK:
		check(not known.has(f), "%s is in both lists" % f)
		known[f] = "look"
	var def := BiomeDef.new()
	var missing := PackedStringArray()
	for p: Dictionary in def.get_property_list():
		var n: String = p.name
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or n.begins_with("_"):
			continue
		if not known.has(n):
			missing.append(n)
	eq(", ".join(missing), "", "BiomeDef fields in neither WorldStamp.TERRAIN nor WorldStamp.LOOK")
	for f: String in known:
		check(f in def, "WorldStamp lists %s, which BiomeDef has not got" % f)


# --- a save written before the registry moved ---------------------------------

func test_a_save_from_a_registry_with_fewer_landscapes_is_refused_by_name() -> void:
	Sx.use_root("stamp-muted")
	# Write the save on the M1 six, exactly as a player before wave A did.
	var guard := Muted.new(SIX)
	var six := WorldStamp.current()
	var p := SaveSlots.path(1)
	eq(SaveFile.write(p, HEADER, _data(six)), OK, "written on the six-type world")
	check(SaveFile.read(p).ok, "and it opens on the build that wrote it")
	guard = null

	# Two landscapes join the registry. The file is whole; the island is not.
	check(WorldStamp.current() != six, "the registry has moved")
	var r := SaveFile.read(p)
	check(not r.ok, "the save is not opened on another island")
	eq(r.code, &"elsewhere")
	eq(r.why, SaveFile.WHY_ELSEWHERE)
	check(not (r.header as Dictionary).is_empty(), "its header still reads, so the slate can show the game")
	eq(str(r.header.get("place")), "moss", "with where it stood")
	check(SaveFile.read_header(p).code == &"elsewhere", "the slot list says so too")
	eq(SaveSlots.problem(1, r.code), "Slot 1 is from another island.")
	eq(SaveSlots.short_problem(r.code), "another island")

	var o := BootOptions.new()
	eq(SaveSlots.options_for(1, o), SaveFile.WHY_ELSEWHERE, "and it boots nothing")
	eq(o.load_slot, -1)
	eq(o.seed_value, BootOptions.new().seed_value, "the seed is never taken from it")

	# Continue does not offer it, and the title says why.
	var entries := SaveSlots.list()
	check(SaveSlots.newest(entries).is_empty(), "Continue has nothing to continue")
	check(SaveSlots.problems(entries).has("Slot 1 is from another island."), "the title says it plainly")
	Sx.finish()


func test_a_save_from_a_registry_with_an_extra_landscape_is_refused_too() -> void:
	Sx.use_root("stamp-added")
	# The other direction, and the one M3 will take a dozen times: the save was
	# written by a build that knew a landscape this one does not.
	var defs := BiomeRegistry.all()
	defs.append(_fake(&"undercroft", 12))
	var theirs := WorldStamp.of(defs)
	check(theirs != WorldStamp.current(), "a build with one more landscape stamps differently")

	var head := HEADER.duplicate()
	head["stamp"] = theirs
	var p := SaveSlots.path(2)
	eq(_store(p, head, _data(theirs)), OK)
	var r := SaveFile.read(p)
	check(not r.ok, "not opened")
	eq(r.code, &"elsewhere")
	eq(SaveSlots.options_for(2, BootOptions.new()), SaveFile.WHY_ELSEWHERE)
	Sx.finish()


func test_a_new_game_asks_before_it_writes_over_an_autosave_from_another_island() -> void:
	Sx.use_root("stamp-title")
	# The whole point of refusing rather than loading is that the game is still
	# there. A new game's first autosave would be the end of it, so the title
	# asks about it exactly as it asks about one it could open.
	var defs := BiomeRegistry.all()
	defs.append(_fake(&"undercroft", 12))
	var head := HEADER.duplicate()
	head["stamp"] = WorldStamp.of(defs)
	eq(_store(SaveSlots.path(SaveSlots.AUTO), head, _data(str(head.stamp))), OK)
	eq(SaveSlots.list()[SaveSlots.AUTO].code, &"elsewhere", "the autosave is from another island")

	var title := UiTitle.new()
	title.options = BootOptions.new()
	var menu := UiTitleMenu.new()
	menu.title = title
	tree.root.add_child(menu)
	menu.open()
	eq(menu.note, "The autosave is from another island.", "the title says so plainly")
	menu.select(&"new")
	menu.handle(&"confirm")
	eq(menu.note, UiTitleMenu.ASK_NEW, "and asks before writing over it")
	check(not bool(title.get("_starting")), "nothing starts on the first press")
	menu.handle(&"confirm")
	check(bool(title.get("_starting")), "the second press starts the new game")
	menu.close()
	menu.free()
	title.free()
	Sx.finish()


func test_a_version_1_save_is_recognised_instead_of_misread() -> void:
	Sx.use_root("stamp-v1")
	# What every save on disk before this change looks like: no stamp at all.
	var head := HEADER.duplicate()
	head["format"] = SaveFile.FORMAT
	head["version"] = 1
	var body := JSON.stringify(_data(""), "", false, true)
	head["data_md5"] = body.md5_text()
	head["thumb_md5"] = "".md5_text()
	head["head_md5"] = SaveFile.header_md5(head)
	var p := SaveSlots.path(1)
	eq(SaveFile.store(p, PackedStringArray([JSON.stringify(head, "", false, true), body])), OK)

	# The migration step is what recognises it: no stamp becomes an unknown
	# world, and an unknown world is never taken for this one.
	var brought := SaveFile.migrate_header(head.duplicate(), 1)
	eq(str(brought.get("stamp")), WorldStamp.UNKNOWN, "version 1 migrates to an unknown world")
	check(WorldStamp.UNKNOWN != WorldStamp.current(), "which no build ever stamps")

	var r := SaveFile.read(p)
	check(not r.ok, "a version 1 save is not opened blind")
	eq(r.code, &"elsewhere", "and is not called damaged: the file is whole")
	eq(r.version, 1, "its version is still reported")
	eq(str(r.header.get("place")), "moss", "and the game it holds still reads")
	eq(SaveSlots.options_for(1, BootOptions.new()), SaveFile.WHY_ELSEWHERE)
	Sx.finish()


func test_the_header_and_the_data_must_agree_on_which_island_it_is() -> void:
	Sx.use_root("stamp-disagree")
	# A header stamped this build's over data from another island: the second
	# line of the same check, where the seed and size are already held together.
	var p := SaveSlots.path(1)
	eq(SaveFile.write(p, HEADER, _data("deadbeef")), OK, "write() stamps the header itself")
	var r := SaveFile.read(p)
	check(r.ok, "the header passes: %s" % r.why)
	eq(SaveSlots.options_for(1, BootOptions.new()), SaveFile.WHY_DAMAGED, "but the data disagrees, so it does not boot")
	Sx.finish()


# --- the cheap second line: the landscape the save says it stood in -----------

func test_the_world_is_held_to_the_landscape_the_save_says_it_stood_in() -> void:
	Sx.use_root("stamp-landscape")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10"])
	var h := SaveCore.header(g, 0.0, PackedByteArray())
	eq(SaveCore.disagrees(g, h), "", "the world it was saved on agrees with itself")

	# What a worldgen change no stamp can see into would look like on load.
	var wrong := h.duplicate()
	wrong["landscape"] = SaveStaging.other_land(str(h.get("landscape")))
	var said := SaveCore.disagrees(g, wrong)
	check(said != "", "a landscape that moved under the player is caught")
	check(said.contains(SaveCore.spoken(StringName(str(wrong.landscape)))), "it names what was saved: %s" % said)
	check(said.contains(SaveCore.spoken(StringName(str(h.landscape)))), "and what is there now: %s" % said)

	# Nothing to hold it to, or a tile off the world: no complaint, no guess.
	var blank := h.duplicate()
	blank.erase("landscape")
	eq(SaveCore.disagrees(g, blank), "", "a save with no landscape is not held to one")
	var away := wrong.duplicate()
	away["pos"] = [9999.0, 9999.0]
	eq(SaveCore.disagrees(g, away), "", "nor a tile off the world")
	Sx.end(g)
	Sx.finish()


func test_a_save_whose_landscape_moved_is_refused_and_nothing_is_written_over_it() -> void:
	Sx.use_root("stamp-refuse")
	var a := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--give=driftwood:7"])
	var saver := Sx.system(a, "05_save")
	eq(str(saver.call("save_to", 1)), "", "saved")
	Sx.end(a)

	# The one thing a worldgen stage that moved would change and no stamp can see:
	# the ground under the tile the save was made on. Staged the way the tour
	# stages it, so both prove the same path.
	var p := SaveSlots.path(1)
	eq(SaveStaging.age(p, &"landscape"), "", "the save now says it stood somewhere else")
	var whole := FileAccess.get_md5(p)

	var said := PackedStringArray()
	var listen := func(text: String) -> void: said.append(text)
	Events.message.connect(listen)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(1, o), "", "the stamp is this build's, so it gets as far as booting")
	var b := Sx.game(tree, [], o)
	Events.message.disconnect(listen)
	var back := Sx.system(b, "05_save")
	eq(int(back.get("loaded_from")), -1, "nothing of the save was applied")
	eq(b.inventory.count(&"driftwood"), 0, "not the carrying either")
	check(not said.is_empty(), "and the player was told")
	check(str(said[0]).contains("not the same ground"), "in the game's own words: %s" % str(said))

	# And this game, which is nobody's game, writes nothing: the autosave that
	# would otherwise be due within minutes would write over the very slot just
	# refused (the door in is Continue on slot 0).
	check(str(back.get("refused")) != "", "the refusal is on the record")
	check(str(back.call("save_to", 1)) != "", "it will not save over the slot it refused")
	check(str(back.call("save_on_leaving")) != "", "nor take an autosave on the way out")
	eq(FileAccess.get_md5(p), whole, "the save is on disk exactly as it was")
	check(SaveSlots.turned_away.has(p), "the slot is remembered as turned away")
	eq(int(SaveSlots.handed_back), 1, "and the title is told which slot to account for")
	Sx.end(b)
	Sx.finish()


func test_a_save_this_build_turned_away_is_never_offered_again() -> void:
	Sx.use_root("stamp-again")
	var a := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10"])
	eq(str(Sx.system(a, "05_save").call("save_to", 1)), "", "saved")
	Sx.end(a)
	var p := SaveSlots.path(1)
	eq(SaveStaging.age(p, &"landscape"), "")
	check(SaveFile.read(p).ok, "the file itself still reads: only the ground moved")

	# Without this the title would offer it, boot it, refuse it and hand back here
	# again, for ever.
	SaveSlots.turn_away(1, &"elsewhere", "That game was saved somewhere else.")
	var entries := SaveSlots.list()
	check(not entries[1].ok, "the slot list has it as unreadable")
	eq(entries[1].code, &"elsewhere")
	check(SaveSlots.newest(entries).is_empty(), "Continue has nothing to continue")
	eq(SaveSlots.options_for(1, BootOptions.new()), "That game was saved somewhere else.", "and it boots nothing")
	eq(SaveSlots.first_problem(entries).slot, 1, "the title has something to say about it")

	# Saved over, it is this build's game again.
	var b := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10"])
	eq(str(Sx.system(b, "05_save").call("save_to", 1)), "", "saved again")
	check(not SaveSlots.turned_away.has(p), "and the slot is no longer turned away")
	check(SaveSlots.list()[1].ok, "it opens")
	Sx.end(b)
	Sx.finish()


func test_the_title_says_the_whole_reason_and_not_only_a_line_of_it() -> void:
	Sx.use_root("stamp-reason")
	# One save, from another island, and a game that has just been handed back
	# here because this build would not open it.
	var head := HEADER.duplicate()
	head["stamp"] = "deadbeef"
	eq(_store(SaveSlots.path(1), head, _data("deadbeef")), OK)
	SaveSlots.handed_back = 1

	var title := UiTitle.new()
	title.options = BootOptions.new()
	var menu := UiTitleMenu.new()
	menu.title = title
	tree.root.add_child(menu)
	menu.open()
	eq(menu.page, "why", "the reason is on the glass, not waiting to be asked for")
	eq(menu.why_text, SaveFile.WHY_ELSEWHERE, "and it is the whole of it")
	eq(menu.note, SaveSlots.problem(1, &"elsewhere"), "with the short line in the strip")
	check(menu.note_warn, "said in the same amber the saves app says it in")

	# Backing out and asking again: the faded continue row is how a player who
	# was not handed back still gets the reason.
	menu.handle(&"back")
	eq(menu.page, "list")
	menu.select(&"continue")
	check(not UiMenu.enabled(menu.menu.selected()), "continue is faded")
	menu.handle(&"confirm")
	eq(menu.page, "why", "confirming it says why, in full")
	eq(menu.why_text, SaveFile.WHY_ELSEWHERE)
	eq(menu.note, SaveSlots.problem(1, &"elsewhere"))
	check(menu.note_warn)
	menu.close()
	menu.free()
	title.free()
	Sx.finish()


func test_a_save_is_aged_into_one_from_another_build_without_damaging_it() -> void:
	Sx.use_root("stamp-aged")
	# What the tour's `stale` command does, and the only way a proof can have a
	# save an older build wrote.
	var a := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10"])
	var saver := Sx.system(a, "05_save")
	eq(str(saver.call("save_to", 1)), "", "saved")
	eq(str(saver.call("save_to", 2)), "", "saved")
	var stood := str(_head_of(SaveSlots.path(2)).get("landscape"))
	Sx.end(a)

	eq(SaveStaging.age(SaveSlots.path(1), &"version"), "")
	var r := SaveFile.read(SaveSlots.path(1))
	eq(r.version, 1, "back to a version-1 file")
	eq(r.code, &"elsewhere", "which is refused, not called damaged")
	check(not (r.header as Dictionary).is_empty(), "and still reads: the file is whole")

	eq(SaveStaging.age(SaveSlots.path(2), &"landscape"), "")
	var r2 := SaveFile.read(SaveSlots.path(2))
	check(r2.ok, "the ground moved, which the file cannot know: it still opens")
	check(str(r2.header.get("landscape")) != stood, "but it says it stood elsewhere")
	eq(SaveStaging.age(SaveSlots.path(3), &"version"), "no save at %s" % SaveSlots.path(3))
	check(SaveStaging.age(SaveSlots.path(1), &"sideways").begins_with("no way"), "and only the ways it has")
	Sx.finish()


static func _head_of(path: String) -> Dictionary:
	var f := FileAccess.open_compressed(path, FileAccess.READ, SaveFile.MODE)
	return JSON.parse_string(f.get_line())


# --- helpers -----------------------------------------------------------------

## The data a save of this world would carry, stamped as `stamp`.
static func _data(stamp: String) -> Dictionary:
	var world := {"seed": 3, "size": 64}
	if stamp != "":
		world["stamp"] = stamp
	return {"world": world, "clock": {"minutes": 2310.0}, "player": {"pos": [10.5, 20.25], "facing": 0.0}}


## Store a header verbatim (SaveFile.write would stamp it with this build's).
static func _store(path: String, header: Dictionary, data: Dictionary) -> Error:
	var body := JSON.stringify(data, "", false, true)
	var head := header.duplicate()
	head["format"] = SaveFile.FORMAT
	head["version"] = SaveFile.VERSION
	head["data_md5"] = body.md5_text()
	head["thumb_md5"] = "".md5_text()
	head["head_md5"] = SaveFile.header_md5(head)
	return SaveFile.store(path, PackedStringArray([JSON.stringify(head, "", false, true), body]))


## A landscape this build does not have, of the shape a content file makes.
static func _fake(id: StringName, order: int) -> BiomeDef:
	var d := BiomeDef.new()
	d.id = id
	d.display_name = "Undercroft"
	d.order = order
	d.index = BiomeRegistry.count()
	return d


## The registry's defs, each one its own copy, so a test may retune one without
## moving the registry every later test reads.
static func _copy(defs: Array[BiomeDef]) -> Array[BiomeDef]:
	var out: Array[BiomeDef] = []
	for d in defs:
		var c := BiomeDef.new()
		for p: Dictionary in d.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or String(p.name).begins_with("_"):
				continue
			var v: Variant = d.get(p.name)
			c.set(p.name, v.duplicate(true) if v is Dictionary or v is Array else v)
		out.append(c)
	return out
