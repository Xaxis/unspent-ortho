class_name SaveFile
## One save on disk. JSON inside FileAccess.open_compressed (zstd), two lines:
##   1. the header: {format, version, saved_at, day, hour, clock, minutes, landscape,
##      place, play_seconds, seed, size, pos, data_md5, thumb (base64 PNG), thumb_md5,
##      head_md5}
##   2. the data: SaveGame.collect(), keyed by registered key
## Behind the compressed frames sits a trailer: "USUM" and the md5 of every byte
## before it. Nothing is decompressed until that md5 holds, because a damaged zstd
## block is not caught by the engine: FileAccessCompressed hands back whatever its
## buffer last held (another save's header, once), and zstd frames here carry no
## checksum. Past it, the header is checked against its own md5 (every field but
## the picture), the data line against the header's, and both lines must parse as
## JSON objects. The header is read alone for slot lists and the title. A picture
## that fails its md5 is dropped and the save still reads. Nothing here throws or
## asserts: a read returns
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
## After it: "USUM" and the md5 of everything before.
const SUM_MAGIC := "USUM"
const TRAILER := 20

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
	head["thumb_md5"] = str(head.get("thumb", "")).md5_text()
	head["head_md5"] = header_md5(head)
	return store(path, PackedStringArray([JSON.stringify(head, "", false, true), body]))


## Lines, compressed, with the trailer, to `<path>.tmp` and renamed over `path`.
## (write builds the lines; tests store hand-made ones.)
static func store(path: String, lines: PackedStringArray) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, MODE)
	if f == null:
		return FileAccess.get_open_error()
	for line in lines:
		f.store_line(line)
	f.close()
	var sum := _md5(FileAccess.get_file_as_bytes(tmp))
	var t := FileAccess.open(tmp, FileAccess.READ_WRITE)
	if t == null:
		DirAccess.remove_absolute(tmp)
		return FileAccess.get_open_error()
	t.seek_end()
	t.store_buffer(SUM_MAGIC.to_ascii_buffer())
	t.store_buffer(sum)
	t.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
	return err


static func _md5(b: PackedByteArray) -> PackedByteArray:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	if not b.is_empty():
		h.update(b)
	return h.finish()


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
	# A version this build reads: its header is whole, or nothing of it is trusted.
	if str(header.get("head_md5", "")) != header_md5(header):
		out.header = {}
		return out
	if str(header.get("thumb", "")).md5_text() != str(header.get("thumb_md5", "")):
		header["thumb"] = ""
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


## The md5 of a header's fields but the picture and this md5 itself, spelled one
## way (SaveCodec.canonical) so the header read back gives the same.
static func header_md5(header: Dictionary) -> String:
	var h := header.duplicate()
	h.erase("thumb")
	h.erase("head_md5")
	return SaveCodec.canonical(h).md5_text()


## JSON text to a value, or null; quietly (JSON.parse_string logs an engine error).
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## True when the file is whole: its magic at both ends of the frames, a block
## table whose sizes add up to its length, and the trailer's md5 over it all.
static func framed(path: String) -> bool:
	var raw := FileAccess.get_file_as_bytes(path)
	var length := raw.size()
	if length < 24 + TRAILER or raw.slice(0, 4).get_string_from_ascii() != MAGIC:
		return false
	var block := raw.decode_u32(8)
	var total := raw.decode_u32(12)
	if block == 0:
		return false
	var blocks := total / block + 1
	var frames := length - TRAILER
	if 16 + blocks * 4 + 4 > frames:
		return false
	var sum := 0
	for i in blocks:
		sum += raw.decode_u32(16 + i * 4)
	if 16 + blocks * 4 + sum + 4 != frames:
		return false
	if raw.slice(frames - 4, frames).get_string_from_ascii() != MAGIC:
		return false
	if raw.slice(frames, frames + 4).get_string_from_ascii() != SUM_MAGIC:
		return false
	return raw.slice(frames + 4) == _md5(raw.slice(0, frames))


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
