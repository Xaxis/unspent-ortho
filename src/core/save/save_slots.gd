class_name SaveSlots
## The saves on this machine: user://saves/slot_N.save. Slot 0 is the autosave;
## slots 1-3 are the player's, written from the pause menu. Continue on the
## title loads the newest readable one of all four.
##
##   SaveSlots.path(n) -> String
##   SaveSlots.list() -> Array[Dictionary]  {slot, exists, ok, why, header} for 0..3
##   SaveSlots.newest() -> Dictionary       the newest readable entry of list(), or {}
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

## A process run as a script (the test runner) keeps its saves here.
const TEST_ROOT := "user://test-saves"

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


static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in COUNT:
		var r := SaveFile.read_header(path(slot))
		out.append({"slot": slot, "exists": exists(slot), "ok": r.ok, "code": r.code, "why": r.why, "header": r.header})
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


## Plain sentences for saves that exist but cannot be read, in slot order.
static func problems(entries: Array[Dictionary] = []) -> PackedStringArray:
	if entries.is_empty():
		entries = list()
	var out := PackedStringArray()
	for e in entries:
		if e.exists and not e.ok:
			out.append(problem(int(e.slot), e.code))
	return out


## "Slot 2 is damaged and cannot be read."
static func problem(slot: int, code: StringName) -> String:
	var who := "The autosave" if slot == AUTO else "Slot %d" % slot
	match code:
		&"missing":
			return "%s is empty." % who
		&"newer":
			return "%s was saved by a newer version of the game." % who
		&"older":
			return "%s is too old for this version of the game." % who
	return "%s is damaged and cannot be read." % who


static func slot_name(slot: int) -> String:
	return "autosave" if slot == AUTO else "slot %d" % slot


## Set `o` up to boot the save in `slot`: its seed and size, the clock where it
## stood and the player's place, so the world is generated and the first chunks
## are drawn where the save is, not at the spawn. The rest is applied by 05_save
## once every system is set up. Returns "" or why it cannot be loaded.
static func options_for(slot: int, o: BootOptions) -> String:
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


## The save's picture, or null. Bytes that are not a whole PNG are never handed
## to the decoder, which would fill the log with CRC errors.
static func thumbnail(header: Dictionary) -> ImageTexture:
	var b64 := str(header.get("thumb", ""))
	if b64 == "":
		return null
	var png := Marshalls.base64_to_raw(b64)
	if not is_png(png):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(png) != OK or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


const PNG_MAGIC: Array[int] = [137, 80, 78, 71, 13, 10, 26, 10]
## The IEND chunk every whole PNG ends on: length 0, "IEND", its CRC.
const PNG_END: Array[int] = [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]


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
