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
	# A save read just before a damaged one: the damaged one never reads back as it.
	# (A broken zstd block leaves the engine's buffer holding what it last held.)
	_write_raw_save(SaveSlots.path(2), SaveFile.VERSION + 1)
	eq(SaveFile.read(SaveSlots.path(2)).code, &"newer")
	cases["read after another save"] = _flip(raw, 20, 4)
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
	eq(SaveFile.store(SaveSlots.path(1), PackedStringArray(["{\"format\": \"something else\"}"])), OK)
	eq(SaveFile.read(SaveSlots.path(1)).code, &"damaged", "a compressed file of something else")
	# A compressed save with no trailer (the engine's own file, not ours).
	var bare := FileAccess.open_compressed(SaveSlots.path(1), FileAccess.WRITE, SaveFile.MODE)
	bare.store_line(JSON.stringify(HEADER))
	bare.close()
	eq(SaveFile.read(SaveSlots.path(1)).code, &"damaged", "frames with no trailer")
	# A good header over a data line that is not what the header promised.
	var whole := {"format": SaveFile.FORMAT, "version": SaveFile.VERSION, "data_md5": "0", "thumb_md5": "".md5_text()}
	whole["head_md5"] = SaveFile.header_md5(whole)
	eq(SaveFile.store(SaveSlots.path(2), PackedStringArray([JSON.stringify(whole), "{\"clock\": "])), OK)
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


func test_a_header_is_checked_whole_and_a_damaged_picture_is_only_dropped() -> void:
	Sx.use_root("header")
	var picture := Image.create(160, 90, false, Image.FORMAT_RGB8)
	for y in 90:
		for x in 160:
			picture.set_pixel(x, y, Color(Rng.hash01(1, x, y, 1), Rng.hash01(1, x, y, 2), Rng.hash01(1, x, y, 3)))
	var png := picture.save_png_to_buffer()
	check(SaveSlots.is_png(png), "a PNG is a PNG")
	var header := HEADER.duplicate()
	header["thumb"] = Marshalls.raw_to_base64(png)
	var data := DATA.duplicate(true)
	data["world"] = {"seed": 3, "size": 64}
	data["player"] = {"pos": [10.5, 20.25], "facing": 0.0}
	var p := SaveSlots.path(1)
	eq(SaveFile.write(p, header, data), OK)
	var good := SaveFile.read_header(p)
	check(good.ok, "whole: %s" % good.why)
	check(SaveSlots.thumbnail(good.header) != null, "with its picture")
	var o := BootOptions.new()
	eq(SaveSlots.options_for(1, o), "", "it boots")
	eq(o.seed_value, 3)
	eq(o.at, Vector2(10.5, 20.25))

	# The header's seed changed after it was written: the digits a flipped byte could hit.
	for field: String in ["seed", "size", "pos", "minutes", "data_md5"]:
		var head := _head_of(p)
		match field:
			"pos": head[field] = [11.5, 20.25]
			"data_md5": head[field] = "0" + str(head[field]).substr(1)
			_: head[field] = SaveCodec.to_num(head[field]) + 1.0
		_rewrite(SaveSlots.path(2), head, _data_line_of(p))
		var r := SaveFile.read_header(SaveSlots.path(2))
		check(not r.ok, "a header whose %s changed is not trusted" % field)
		eq(r.code, &"damaged", "%s:" % field)
		eq(SaveSlots.options_for(2, BootOptions.new()), SaveFile.WHY_DAMAGED, "%s: and does not boot" % field)

	# The picture's bytes changed: the save reads, without a picture, and the decoder never sees them.
	var head := _head_of(p)
	var bad := Marshalls.base64_to_raw(str(head.thumb))
	for i in 40:
		bad[200 + i] = bad[200 + i] ^ 0x5a
	head["thumb"] = Marshalls.raw_to_base64(bad)
	_rewrite(SaveSlots.path(3), head, _data_line_of(p))
	var r3 := SaveFile.read_header(SaveSlots.path(3))
	check(r3.ok, "a damaged picture does not lose the save")
	eq(str(r3.header.get("thumb")), "", "the picture is dropped")
	eq(SaveSlots.thumbnail(r3.header), null, "and none is shown")
	# Bytes that are not a whole PNG are refused before decoding.
	check(not SaveSlots.is_png(bad.slice(0, bad.size() - 1)), "a PNG cut short")
	check(not SaveSlots.is_png("not a png at all, but long enough to be one maybe".to_utf8_buffer()), "text")
	eq(SaveSlots.thumbnail({"thumb": Marshalls.raw_to_base64(png.slice(0, 100))}), null)

	# The data's world must be the header's.
	var liar := DATA.duplicate(true)
	liar["world"] = {"seed": 4, "size": 64}
	eq(SaveFile.write(SaveSlots.path(2), header, liar), OK)
	eq(SaveSlots.options_for(2, BootOptions.new()), SaveFile.WHY_DAMAGED, "a header and data that disagree on the world do not boot")

	# Bytes flipped anywhere in a whole file: it reads as damaged, or it reads with
	# the header exactly as written (at most without its picture).
	var raw := FileAccess.get_file_as_bytes(p)
	var want := SaveFile.header_md5(good.header)
	for at in range(20, raw.size() - 8, maxi(1, raw.size() / 60)):
		_put(SaveSlots.path(2), _flip(raw, at, mini(40, raw.size() - 4 - at)))
		var r := SaveFile.read_header(SaveSlots.path(2))
		if r.ok:
			eq(SaveFile.header_md5(r.header), want, "flipped at %d: read, and the header as written" % at)
	Sx.finish()


func _head_of(path: String) -> Dictionary:
	var f := FileAccess.open_compressed(path, FileAccess.READ, SaveFile.MODE)
	return JSON.parse_string(f.get_line())


func _data_line_of(path: String) -> String:
	var f := FileAccess.open_compressed(path, FileAccess.READ, SaveFile.MODE)
	f.get_line()
	return f.get_line()


func _rewrite(path: String, head: Dictionary, body: String) -> void:
	SaveFile.store(path, PackedStringArray([JSON.stringify(head, "", false, true), body]))


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
	SaveFile.store(path, PackedStringArray([JSON.stringify(head), body]))


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
