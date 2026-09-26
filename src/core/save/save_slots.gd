class_name SaveSlots
## The saves on this machine: user://saves/slot_N.save. Slot 0 is the autosave;
## slots 1-3 are the player's, written from the pause menu. Continue on the
## title loads the newest readable one of all four.
##
##   SaveSlots.path(n) -> String
##   SaveSlots.list() -> Array[Dictionary]  {slot, exists, ok, code, why, header} for 0..3
##   SaveSlots.newest() -> Dictionary       the newest readable entry of list(), or {}
##   SaveSlots.first_problem(...) -> Dictionary  the first save that will not open,
##                                          said both short (`line`) and whole (`why`)
##   SaveSlots.turn_away(slot, code, why)   a save this build grew the world for and
##                                          would not open: never offered again
##   SaveSlots.options_for(slot, into) -> String   fill BootOptions to boot that save
##                                                 ("" = done, else why it cannot)
##   SaveSlots.describe(header) -> String   "day 3  14:20  moss"
##   SaveSlots.thumbnail(header) -> ImageTexture or null

const AUTO := 0
const MANUAL: Array[int] = [1, 2, 3]
const COUNT := 4

const PLAYER_ROOT := "user://saves"
## Shots save here unless told otherwise, and each tour in a folder of its own
## under it (TOOL_ROOT/<tour name>), so running the tools never overwrites a
## player's autosave, and a tour run beside another never continues its save.
const TOOL_ROOT := "user://tool-saves"

## A process run as a script (the test runner) keeps its saves here, in a
## folder of its own process (RunnerHome): runners on one machine share user://.
static var TEST_ROOT := RunnerHome.path().path_join("saves")

## Where slots live. Tests point it somewhere of their own.
static var root := TEST_ROOT if OS.get_cmdline_args().has("-s") else PLAYER_ROOT


## At boot: where saves live (--saves, or the tools' own place), and for --load=N
## the save's seed, size, clock and place. A save that cannot be read boots a
## new game and says why in the log.
static func use_options(o: BootOptions) -> void:
	if o.saves != "":
		root = "user://".path_join(o.saves)
	elif o.tour != "":
		root = TOOL_ROOT.path_join(o.tour.get_file().get_basename())
	elif o.shot != "":
		root = TOOL_ROOT
	if o.load_slot >= 0:
		var why := options_for(o.load_slot, o)
		if why != "":
			push_warning("--load=%d: %s" % [o.load_slot, why])
			o.load_slot = -1


static func path(slot: int) -> String:
	return root.path_join("slot_%d.save" % slot)


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


## Saves this build has grown the world for and then turned away, by their path:
## path -> {code, why}. The stamp cannot see into the worldgen stages, so a save
## whose ground has moved under it is only caught once the world is made and the
## game is already booting (SaveCore.disagrees, 05_save). Remembering it for as
## long as the process runs is what stops the title offering the same save over
## and over, each time to be refused and handed straight back.
static var turned_away := {}


static func turn_away(slot: int, code: StringName, why: String) -> void:
	turned_away[path(slot)] = {"code": code, "why": why}


## That slot holds a game this build wrote: whatever it was turned away for is
## no longer true of it.
static func forget_turned_away(slot: int) -> void:
	turned_away.erase(path(slot))


## The slot a running game has just handed back over because this build would not
## open it, for the title to say in full the moment it comes up. Taken once.
static var handed_back := -1


static func take_handed_back() -> int:
	var slot := handed_back
	handed_back = -1
	return slot


static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Spelled out once for all four slots: it is the same build for each of them,
	# and working it out is the dear part of reading a header (1.3 ms a time).
	var mine := WorldStamp.current()
	for slot in COUNT:
		var r := SaveFile.read_header(path(slot), mine)
		var e := {"slot": slot, "exists": exists(slot), "ok": r.ok, "code": r.code, "why": r.why, "header": r.header}
		var turned: Dictionary = turned_away.get(path(slot), {})
		if e.ok and not turned.is_empty():
			e.ok = false
			e.code = turned.code
			e.why = turned.why
		out.append(e)
	return out


static func newest(entries: Array[Dictionary] = []) -> Dictionary:
	if entries.is_empty():
		entries = list()
	var best := {}
	for e in entries:
		if not e.ok:
			continue
		if best.is_empty() or SaveCodec.to_num((e.header as Dictionary).get("saved_at")) > SaveCodec.to_num((best.header as Dictionary).get("saved_at")):
			best = e
	return best


## The first save that exists and will not open, said both ways: `line` for the
## key strip, `why` in full for a page with room. `prefer` puts a slot first
## (the one a game has just been handed back over). {} when all is well.
static func first_problem(entries: Array[Dictionary] = [], prefer: int = -1) -> Dictionary:
	if entries.is_empty():
		entries = list()
	var best := {}
	for e in entries:
		if not (e.exists and not e.ok):
			continue
		var row := {"slot": int(e.slot), "code": e.code, "line": problem(int(e.slot), e.code), "why": str(e.why)}
		if int(e.slot) == prefer:
			return row
		if best.is_empty():
			best = row
	return best


## Plain sentences for saves that exist but cannot be read, in slot order.
static func problems(entries: Array[Dictionary] = []) -> PackedStringArray:
	if entries.is_empty():
		entries = list()
	var out := PackedStringArray()
	for e in entries:
		if e.exists and not e.ok:
			out.append(problem(int(e.slot), e.code))
	return out


## "Slot 2 cannot be read." — one short line for the KEY STRIP, which on the
## title's small slate has about 200 px for it (tests/save/test_problem_fits.gd
## holds every sentence here to that). The whole reason is SaveFile.WHY_*, read
## on the saves app's own page, where there is room to say it properly.
static func problem(slot: int, code: StringName) -> String:
	var who := "The autosave" if slot == AUTO else "Slot %d" % slot
	match code:
		&"missing":
			return "%s is empty." % who
		&"newer":
			return "%s is from a newer game." % who
		&"older":
			return "%s is too old for this game." % who
		&"elsewhere":
			# Not "damaged": the file is whole and the game in it is readable.
			# What moved is the island the seed grows into (WorldStamp).
			return "%s is from another island." % who
	return "%s cannot be read." % who


## Two or three words for a slot's row, where the whole sentence does not fit.
static func short_problem(code: StringName) -> String:
	match code:
		&"missing":
			return "empty"
		&"newer":
			return "newer game"
		&"older":
			return "too old"
		&"elsewhere":
			return "another island"
	return "cannot be read"


static func slot_name(slot: int) -> String:
	return "autosave" if slot == AUTO else "slot %d" % slot


## Set `o` up to boot the save in `slot`: its seed and size, the clock where it
## stood and the player's place, so the world is generated and the first chunks
## are drawn where the save is, not at the spawn. The rest is applied by 05_save
## once every system is set up. Returns "" or why it cannot be loaded.
static func options_for(slot: int, o: BootOptions) -> String:
	# One this build has already grown the world for and turned away never boots
	# again: it would be refused a second time, once the world was made.
	var turned: Dictionary = turned_away.get(path(slot), {})
	if not turned.is_empty():
		return str(turned.why)
	var r := SaveFile.read(path(slot))
	if not r.ok:
		return r.why
	var h: Dictionary = r.header
	# The world it boots is the data's; the header, which lists the slot, must agree.
	var world: Dictionary = r.data.get("world") if r.data.get("world") is Dictionary else {}
	var world_seed := SaveCodec.to_int(world.get("seed"), -1)
	var size := SaveCodec.to_int(world.get("size"), 0)
	if size <= 0 or world_seed != SaveCodec.to_int(h.get("seed"), -2) or size != SaveCodec.to_int(h.get("size"), -2):
		return SaveFile.WHY_DAMAGED
	# The seed is only half of which island this is; the data carries the stamp
	# too, and the header, which the slot list reads, must agree with it.
	if str(world.get("stamp", WorldStamp.UNKNOWN)) != str(h.get("stamp", WorldStamp.UNKNOWN)):
		return SaveFile.WHY_DAMAGED
	var player: Dictionary = r.data.get("player") if r.data.get("player") is Dictionary else {}
	var clock: Dictionary = r.data.get("clock") if r.data.get("clock") is Dictionary else {}
	o.seed_value = world_seed
	o.size = size
	o.at = SaveCodec.to_vec2(player.get("pos"), SaveCodec.to_vec2(h.get("pos"), Vector2(-1, -1)))
	o.hour = SaveCodec.to_num(clock.get("minutes"), SaveCodec.to_num(h.get("minutes"), Tuning.START_HOUR * 60.0)) / 60.0
	o.load_slot = slot
	return ""


static func describe(header: Dictionary) -> String:
	if header.is_empty():
		return ""
	return "%s  %s" % [str(header.get("clock", "")), str(header.get("place", ""))]


## "1 h 20 m" of play ("a moment" under a minute).
static func play_time(header: Dictionary) -> String:
	var s := SaveCodec.to_num(header.get("play_seconds"), 0.0)
	var m := floori(s / 60.0)
	if m < 1:
		return "a moment"
	if m < 60:
		return "%d m" % m
	return "%d h %02d m" % [m / 60, m % 60]


## The save's picture, or null. Bytes that are not a whole picture are never
## handed to a decoder, which would fill the log with CRC errors.
##
## IT READS BOTH FORMATS ON PURPOSE, and that is what let the picture get better
## without a migration. Saves written before 2026-09-18 carry a PNG; ones
## written since carry a JPEG (05_save.THUMB, and the note there for the
## measurements). Nothing else in the file cares: `SaveFile` only md5s the
## base64 string, so the format was never a contract anywhere but here, and
## teaching the READER a second format leaves every save on disk readable.
static func thumbnail(header: Dictionary) -> ImageTexture:
	var b64 := str(header.get("thumb", ""))
	if b64 == "":
		return null
	var raw := Marshalls.base64_to_raw(b64)
	var img := Image.new()
	if is_png(raw):
		if img.load_png_from_buffer(raw) != OK or img.is_empty():
			return null
	elif is_jpg(raw):
		if img.load_jpg_from_buffer(raw) != OK or img.is_empty():
			return null
	else:
		return null
	return ImageTexture.create_from_image(img)


const PNG_MAGIC: Array[int] = [137, 80, 78, 71, 13, 10, 26, 10]
## The IEND chunk every whole PNG ends on: length 0, "IEND", its CRC.
const PNG_END: Array[int] = [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]
## A JPEG opens on SOI + the first marker and closes on EOI. Same shape of test
## as the PNG one and for the same reason: a truncated picture must be refused
## here rather than in the decoder's log.
const JPG_MAGIC: Array[int] = [255, 216, 255]
const JPG_END: Array[int] = [255, 217]


## Starts as a PNG and ends as one.
static func is_png(b: PackedByteArray) -> bool:
	if b.size() < PNG_MAGIC.size() + PNG_END.size() + 25:
		return false
	for i in PNG_MAGIC.size():
		if b[i] != PNG_MAGIC[i]:
			return false
	var tail := b.size() - PNG_END.size()
	for i in PNG_END.size():
		if b[tail + i] != PNG_END[i]:
			return false
	return true


## Whole-JPEG test, the twin of `is_png`.
static func is_jpg(b: PackedByteArray) -> bool:
	if b.size() < JPG_MAGIC.size() + JPG_END.size() + 25:
		return false
	for i in JPG_MAGIC.size():
		if b[i] != JPG_MAGIC[i]:
			return false
	var tail := b.size() - JPG_END.size()
	for i in JPG_END.size():
		if b[tail + i] != JPG_END[i]:
			return false
	return true
