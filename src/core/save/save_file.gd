class_name SaveFile
## One save on disk. JSON inside FileAccess.open_compressed (zstd), two lines:
##   1. the header: {format, version, saved_at, day, hour, clock, minutes, landscape,
##      place, play_seconds, seed, size, pos, data_md5, thumb (base64 PNG)}
##   2. the data: SaveGame.collect(), keyed by registered key
## The header is read alone for slot lists and the title (only its blocks are
## decompressed). Every read checks the file's block table against its length,
## the data line against the header's md5, and both lines parse as JSON objects,
## because a truncated or damaged compressed file otherwise reads back silently
## as garbage. Nothing here throws or asserts: a read returns
##   {ok: bool, code: StringName (&"" missing damaged newer older), why: String (a plain
##    sentence for the player), header, data, version}
##
## Writes go to `<path>.tmp` and are renamed over the slot, so a save cut off
## halfway never replaces a good one. Only FileAccess and DirAccess on user://:
## on the web user:// is IndexedDB, synced when a written file closes; no
## threads, no OS calls, no blocking waits (tests/save/test_web_safe.gd).

const FORMAT := "unspent-save"
## Bump when the data's shape changes, and add a step to migrate().
const VERSION := 1
## The oldest version migrate() can still bring forward.
const OLDEST := 1
const MODE := FileAccess.COMPRESSION_ZSTD
## FileAccessCompressed's framing: "GCPF", mode, block size, total, a u32 per block, data, "GCPF".
const MAGIC := "GCPF"

const WHY_MISSING := "Nothing is saved there."
const WHY_DAMAGED := "That save is damaged and cannot be read."
const WHY_NEWER := "That save was made by a newer version of the game."
const WHY_OLDER := "That save is too old for this version of the game."


static func write(path: String, header: Dictionary, data: Dictionary) -> Error:
	var body := JSON.stringify(data, "", false, true)
	var head := header.duplicate()
	head["format"] = FORMAT
	head["version"] = VERSION
	head["data_md5"] = body.md5_text()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, MODE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_line(JSON.stringify(head, "", false, true))
	f.store_line(body)
	f.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
	return err


## The header alone (for lists). `data` is left empty.
static func read_header(path: String) -> Dictionary:
	return _read(path, false)


static func read(path: String) -> Dictionary:
	return _read(path, true)


static func _read(path: String, with_data: bool) -> Dictionary:
	var out := {"ok": false, "code": &"damaged", "why": WHY_DAMAGED, "header": {}, "data": {}, "version": 0}
	if not FileAccess.file_exists(path):
		out.code = &"missing"
		out.why = WHY_MISSING
		return out
	if not framed(path):
		return out
	var f := FileAccess.open_compressed(path, FileAccess.READ, MODE)
	if f == null:
		return out
	var head: Variant = _parse(f.get_line())
	if not (head is Dictionary) or (head as Dictionary).get("format", "") != FORMAT:
		return out
	var header: Dictionary = head
	var version := SaveCodec.to_int(header.get("version"), 0)
	out.header = header
	out.version = version
	if version > VERSION:
		out.code = &"newer"
		out.why = WHY_NEWER
		return out
	if version < OLDEST:
		out.code = &"older"
		out.why = WHY_OLDER
		return out
	if not with_data:
		out.ok = true
		out.code = &""
		out.why = ""
		return out
	var body := f.get_line()
	if body.md5_text() != str(header.get("data_md5", "")):
		return out
	var parsed: Variant = _parse(body)
	if not (parsed is Dictionary):
		return out
	out.data = migrate(parsed, version)
	out.ok = true
	out.code = &""
	out.why = ""
	return out


## JSON text to a value, or null; quietly (JSON.parse_string logs an engine error).
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## True when the file is whole: its magic at both ends and a block table whose
## sizes add up to its length.
static func framed(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var length := f.get_length()
	if length < 24 or f.get_buffer(4).get_string_from_ascii() != MAGIC:
		return false
	f.get_32() # mode
	var block := f.get_32()
	var total := f.get_32()
	if block == 0:
		return false
	var blocks := total / block + 1
	if 16 + blocks * 4 + 4 > length:
		return false
	var sum := 0
	for i in blocks:
		sum += f.get_32()
	if 16 + blocks * 4 + sum + 4 != length:
		return false
	f.seek(length - 4)
	return f.get_buffer(4).get_string_from_ascii() == MAGIC


## Bring data saved by an older version up to VERSION, one step at a time. Each
## step takes the data as that version wrote it and returns it as the next
## version reads it. (Version 1 is the first; there is nothing to step yet.)
static func migrate(data: Dictionary, from_version: int) -> Dictionary:
	var v := from_version
	while v < VERSION:
		match v:
			_:
				pass
		v += 1
	return data
