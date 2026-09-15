extends TestCase
## The file on disk: its two lines come back as written; a version from the
## future or from before the oldest step is refused with a plain reason; a
## missing, truncated, flipped, foreign or empty file never throws, reads as
## damaged, and the slots and the title say so without falling over.

const Sx := preload("res://tests/save/save_fixture.gd")

const HEADER := {"clock": "day 2  14:30", "place": "moss", "saved_at": 100.0, "seed": 3, "size": 64,
	"pos": [10.5, 20.25], "minutes": 2310.0, "play_seconds": 4000.0}
const DATA := {"clock": {"minutes": 2310.0}, "inventory": {"items": {"knife": 1}}, "world": {"depleted": {"12": "inf"}}}


func test_a_save_reads_back_as_written() -> void:
	Sx.use_root("file")
	var p := SaveSlots.path(1)
	eq(SaveFile.write(p, HEADER, DATA), OK, "written")
	check(not FileAccess.file_exists(p + ".tmp"), "the temporary file is renamed away")
	check(SaveFile.framed(p), "whole")
	var r := SaveFile.read(p)
	check(r.ok, "read: %s" % r.why)
	eq(r.code, &"")
	eq(r.version, SaveFile.VERSION)
	eq(SaveCodec.canonical(r.data), SaveCodec.canonical(DATA), "data")
	eq(str(r.header.place), "moss")
	eq(str(r.header.format), SaveFile.FORMAT)
	var h := SaveFile.read_header(p)
	check(h.ok and (h.data as Dictionary).is_empty(), "the header reads alone")
	eq(SaveSlots.describe(h.header), "day 2  14:30  moss")
	eq(SaveSlots.play_time(h.header), "1 h 06 m")
	# Written again over itself: the new one is what reads back.
	var data2 := DATA.duplicate(true)
	data2["clock"] = {"minutes": 9.0}
	eq(SaveFile.write(p, HEADER, data2), OK)
	eq(SaveCodec.to_num(SaveFile.read(p).data.clock.minutes), 9.0, "overwritten")
	Sx.finish()


func test_versions_from_the_future_and_the_distant_past_are_refused_plainly() -> void:
	Sx.use_root("versions")
	var newer := SaveSlots.path(1)
	_write_raw_save(newer, SaveFile.VERSION + 1)
	var r := SaveFile.read(newer)
	check(not r.ok, "a newer save is not loaded")
	eq(r.code, &"newer")
	eq(r.why, SaveFile.WHY_NEWER)
	eq(SaveSlots.problem(1, r.code), "Slot 1 was saved by a newer version of the game.")
	var older := SaveSlots.path(2)
	_write_raw_save(older, SaveFile.OLDEST - 1)
	r = SaveFile.read(older)
	check(not r.ok, "a save older than the oldest step is not loaded")
	eq(r.code, &"older")
	eq(SaveSlots.problem(2, r.code), "Slot 2 is too old for this version of the game.")
	# The migration ladder: data already at this version passes through untouched.
	eq(SaveCodec.canonical(SaveFile.migrate(DATA.duplicate(true), SaveFile.VERSION)), SaveCodec.canonical(DATA))
	eq(SaveCodec.canonical(SaveFile.migrate(DATA.duplicate(true), SaveFile.OLDEST)), SaveCodec.canonical(DATA), "each step returns data")
	var o := BootOptions.new()
	eq(SaveSlots.options_for(1, o), SaveFile.WHY_NEWER, "Continue says why")
	eq(o.load_slot, -1, "and boots nothing")
	Sx.finish()


func test_damaged_and_missing_files_never_throw_and_say_so() -> void:
	Sx.use_root("damaged")
	var good := SaveSlots.path(3)
	eq(SaveFile.write(good, HEADER, DATA), OK)
	var raw := FileAccess.get_file_as_bytes(good)
	eq(SaveFile.read(SaveSlots.path(1)).code, &"missing", "missing")
	eq(SaveFile.read(SaveSlots.path(1)).why, SaveFile.WHY_MISSING)
	var cases := {
		"empty": PackedByteArray(),
		"foreign text": "not a save at all, just words".to_utf8_buffer(),
		"truncated": raw.slice(0, raw.size() / 2),
		"one byte short": raw.slice(0, raw.size() - 1),
		"block table flipped": _flip(raw, 20, 4),
		"tail magic gone": _flip(raw, raw.size() - 2, 1),
	}
	# A payload flipped inside the compressed data: the framing holds, the data's md5 does not.
	var payload := _flip(raw, raw.size() - 40, 6)
	cases["payload flipped"] = payload
	for name: String in cases:
		var p := SaveSlots.path(1)
		_put(p, cases[name])
		var r := SaveFile.read(p)
		check(not r.ok, "%s is not read as a save" % name)
		eq(r.code, &"damaged", "%s:" % name)
		eq(r.why, SaveFile.WHY_DAMAGED, "%s:" % name)
	# Compressed, whole, but not a save inside.
	var f := FileAccess.open_compressed(SaveSlots.path(1), FileAccess.WRITE, SaveFile.MODE)
	f.store_line("{\"format\": \"something else\"}")
	f.close()
	eq(SaveFile.read(SaveSlots.path(1)).code, &"damaged", "a compressed file of something else")
	# A good header over a data line that is not what the header promised.
	f = FileAccess.open_compressed(SaveSlots.path(2), FileAccess.WRITE, SaveFile.MODE)
	f.store_line(JSON.stringify({"format": SaveFile.FORMAT, "version": SaveFile.VERSION, "data_md5": "0"}))
	f.store_line("{\"clock\": ")
	f.close()
	var half := SaveFile.read(SaveSlots.path(2))
	eq(half.code, &"damaged", "a data line cut short")
	check(SaveFile.read_header(SaveSlots.path(2)).ok, "its header alone still lists")

	# The slots: the good one is the newest readable; the damaged ones are named plainly.
	_put(SaveSlots.path(0), raw.slice(0, 10))
	var entries := SaveSlots.list()
	eq(entries.size(), SaveSlots.COUNT)
	var newest := SaveSlots.newest(entries)
	eq(int(newest.get("slot", -1)), 3, "the good save is the one Continue loads")
	var problems := SaveSlots.problems(entries)
	check(problems.has("The autosave is damaged and cannot be read."), "said plainly: %s" % str(problems))
	check(problems.has("Slot 1 is damaged and cannot be read."), "said plainly: %s" % str(problems))
	var o := BootOptions.new()
	eq(SaveSlots.options_for(0, o), SaveFile.WHY_DAMAGED, "a damaged slot does not boot")
	Sx.finish()


func test_the_title_offers_continue_for_the_newest_and_names_what_cannot_be_read() -> void:
	Sx.use_root("title")
	var menu := UiTitleMenu.new()
	tree.root.add_child(menu)
	menu.open()
	eq(_ids(menu), [&"new", &"seed", &"controls", &"quit"], "nothing saved: no continue")
	eq(menu.note, "", "and nothing to say")
	menu.close()

	var older := HEADER.duplicate()
	older["saved_at"] = 50.0
	eq(SaveFile.write(SaveSlots.path(1), older, DATA), OK)
	eq(SaveFile.write(SaveSlots.path(2), HEADER, DATA), OK)
	menu.open()
	eq(_ids(menu), [&"continue", &"new", &"seed", &"controls", &"quit"], "continue heads the slip")
	eq(menu.menu.selected().get("id"), &"continue", "and is chosen")
	eq(int(menu.saved.get("slot", -1)), 2, "the newest save")
	eq(menu.slip().size.y, UiTitleMenu.SLIP.size.y + UiTitleMenu.ROW_H, "the slip grows a row")
	menu.close()

	for slot: int in [1, 2]:
		_put(SaveSlots.path(slot), "garbage".to_utf8_buffer())
	menu.open()
	eq(_ids(menu), [&"new", &"continue", &"seed", &"controls", &"quit"], "unreadable saves: continue is faded, not first")
	eq(menu.note, "Slot 1 is damaged and cannot be read.", "the title says so plainly")
	menu.select(&"continue")
	menu.handle(&"confirm")
	eq(menu.note, "Slot 1 is damaged and cannot be read.", "and says it again when asked")
	menu.close()
	menu.free()
	Sx.finish()


func test_new_game_over_a_readable_autosave_asks_once_more() -> void:
	Sx.use_root("title-new")
	var menu := UiTitleMenu.new()
	menu.title = null
	tree.root.add_child(menu)
	menu.open()
	menu.select(&"new")
	menu.handle(&"confirm")
	eq(menu.note, "", "nothing saved: new game starts at once, no question")
	menu.close()

	eq(SaveFile.write(SaveSlots.path(1), HEADER, DATA), OK)
	menu.open()
	menu.select(&"new")
	menu.handle(&"confirm")
	eq(menu.note, "", "a manual slot is never written over by a new game: no question")
	menu.close()

	eq(SaveFile.write(SaveSlots.path(SaveSlots.AUTO), HEADER, DATA), OK)
	var title := UiTitle.new()
	title.options = BootOptions.new()
	menu.title = title
	menu.open()
	menu.select(&"new")
	menu.handle(&"confirm")
	eq(menu.note, UiTitleMenu.ASK_NEW, "an autosave that reads: asked once more")
	check(not bool(title.get("_starting")), "and nothing starts yet")
	menu.handle(&"up")
	menu.handle(&"down")
	menu.handle(&"confirm")
	check(not bool(title.get("_starting")), "moving away forgets the ask: asked again")
	menu.handle(&"confirm")
	check(bool(title.get("_starting")), "the second press starts the new game")
	menu.close()

	# A damaged autosave is nothing to lose.
	title.set("_starting", false)
	_put(SaveSlots.path(SaveSlots.AUTO), "garbage".to_utf8_buffer())
	menu.open()
	menu.select(&"new")
	menu.handle(&"confirm")
	check(bool(title.get("_starting")), "a damaged autosave: new game at once")
	menu.close()
	menu.free()
	title.free()
	Sx.finish()


func _ids(menu: UiTitleMenu) -> Array:
	var out: Array = []
	for r in menu.menu.rows:
		out.append(r.id)
	return out


func _write_raw_save(path: String, version: int) -> void:
	var body := JSON.stringify(DATA)
	var head := HEADER.duplicate()
	head["format"] = SaveFile.FORMAT
	head["version"] = version
	head["data_md5"] = body.md5_text()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, SaveFile.MODE)
	f.store_line(JSON.stringify(head))
	f.store_line(body)
	f.close()


func _flip(raw: PackedByteArray, at: int, n: int) -> PackedByteArray:
	var out := raw.duplicate()
	for i in n:
		out[at + i] = out[at + i] ^ 0x5a
	return out


func _put(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
