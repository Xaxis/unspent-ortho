class_name WorldCache
## Generated worlds kept on disk, so a process asking for a world another one
## already grew loads it (0.4 s at 1840) instead of growing it (35-50 s on the
## shared box). Every tour boots seed 1 or 7, and a smoke sweep grew the same
## island twelve times.
##
##   WorldCache.world(seed, size, realm)   loaded if kept, else grown and kept
##   WorldCache.encode(w) / decode(bytes)  the world as bytes and back, exact
##   UNSPENT_WORLD_CACHE=off               never read or write (timing worldgen)
##   UNSPENT_WORLD_CACHE=/some/dir         keep them there instead
##   WorldCache.enabled = false            off for this process (a test about a raise in flight)
##
## THE KEY IS THE SOURCE, NOT `WorldStamp.GEN`. A branch changes what a seed makes
## long before its GEN is bumped at landing, so a GEN key would hand it worlds its
## own code no longer makes. The key is the md5 of every .gd under res://src (a
## superset of what generate() can reach: biomes are found by a directory scan,
## so no reference walk can bound it), this build's WorldStamp (a registry muted
## or retuned in place), the engine version, the seed, the size and the realm.
## When any script under res://src is newer than this process, what is on disk is
## not what was compiled, so the cache is not used at all in that process.
## Generation's test hooks (GenScatter.keeping, GenBodies.trade and the like) are
## not in the key: a test that sets one grows its world with WorldGen.generate.
##
## Off in exported builds: their scripts are not readable as source.
##
## Shared by every worktree and process on the machine: a world is written to a
## file of its own name and renamed into place, so a reader sees a whole file or
## none; two processes growing one world both write it, and the later rename wins
## with the same bytes. Past CAP_BYTES (about 140 worlds at 1840, 28 MB each) the
## least recently used go (a hit rewrites its first byte, the same byte, to move
## its mtime).
##
## EXACT: decode(encode(w)) holds every script variable of WorldData and every
## object in it (PropTable, Portal, LandmarkSite) field for field, typed arrays as
## their type, and the world's metadata (Landmarks keeps its sites there from the
## first ask during generation). Fields are read off the property list, so a new
## field is kept without a line here (tests/boot/test_world_cache.gd). A world is
## kept only once generation finished it (`packed`): a halted raise is never kept.
##
## What generation works out and holds PER WORLD OBJECT outside WorldData (the
## works, the keepers' lairs, the threshold site, the crushed ore) is not kept: a
## loaded world is a new object and works each out again on its first ask, to the
## same answer (the test holds that). RealmWarm asks the ones a crossing's press
## needs beside the raise, so a loaded world's press is no longer than a grown one's.

const FORMAT := "unspent-world-cache 1"
const MAGIC := "UWC1"
const EXT := ".world"
const CAP_BYTES := 4 * 1024 * 1024 * 1024
## A temp file older than this was left by a killed writer.
const STALE_TMP_SEC := 3600
const OBJ := &"@obj"
const OBJS := &"@objs"

## False turns the cache off for this process (tests whose subject is a raise in
## flight, which a load a second long would finish before they look).
static var enabled := true
## Where entries live; "" asks the environment (`dir()`). Tests point it at
## their own folder.
static var root := ""
## What the last `world` call did: &"loaded", &"grown" (and kept), &"off".
static var last := &""

static var _lock := Mutex.new()
static var _source := ""
static var _source_why := ""


## The world for (seed, size, realm): loaded when kept, else generated and kept.
static func world(seed_value: int, size: int, realm: StringName = &"surface") -> WorldData:
	var key := key_for(seed_value, size, realm)
	if key == "":
		last = &"off"
		return WorldGen.generate(seed_value, size, &"", realm)
	var path := dir().path_join(file_name(seed_value, size, realm, key))
	var t := Time.get_ticks_msec()
	var w := read(path, key)
	if w != null:
		last = &"loaded"
		print("world cache: seed %d at %d (%s) loaded in %d ms" % [seed_value, size, realm, Time.get_ticks_msec() - t])
		return w
	w = WorldGen.generate(seed_value, size, &"", realm)
	last = &"grown"
	if w.packed:
		t = Time.get_ticks_msec()
		if write(path, key, w) == OK:
			print("world cache: seed %d at %d (%s) kept in %d ms" % [seed_value, size, realm, Time.get_ticks_msec() - t])
		evict(dir())
	return w


## The cache folder, or "" when there is none (off, or nowhere to put it).
static func dir() -> String:
	if root != "":
		return root
	var env := OS.get_environment("UNSPENT_WORLD_CACHE")
	if env.is_absolute_path():
		return env
	var base := OS.get_environment("XDG_CACHE_HOME")
	if base == "":
		base = OS.get_environment("HOME")
		if base == "":
			return ""
		base = base.path_join(".cache")
	return base.path_join("unspent-worlds")


## The whole key for a world, or "" when the cache is off for it.
static func key_for(seed_value: int, size: int, realm: StringName) -> String:
	if not enabled or OS.has_feature("template") or dir() == "":
		return ""
	var env := OS.get_environment("UNSPENT_WORLD_CACHE").to_lower()
	if env in ["off", "0", "no", "false"]:
		return ""
	var src := source_hash()
	if src == "":
		return ""
	return "%s|engine %s|stamp %s|src %s|seed %d|size %d|realm %s" % [
		FORMAT, Engine.get_version_info().get("string", "?"), WorldStamp.current(), src, seed_value, size, realm]


static func file_name(seed_value: int, size: int, realm: StringName, key: String) -> String:
	return "s%d-%d-%s-%s%s" % [seed_value, size, realm, key.md5_text().substr(0, 16), EXT]


## The md5 of every script under res://src, read once a process; "" when one is
## newer than the process (it is not the code that is running), said once.
static func source_hash() -> String:
	_lock.lock()
	if _source == "" and _source_why == "":
		var files := PackedStringArray()
		_scripts("res://src", files)
		files.sort()
		var began := floori(Time.get_unix_time_from_system() - Time.get_ticks_msec() / 1000.0)
		var h := HashingContext.new()
		h.start(HashingContext.HASH_MD5)
		for f in files:
			if FileAccess.get_modified_time(f) >= began:
				_source_why = "%s changed since this process began" % f
				break
			h.update(f.to_utf8_buffer())
			h.update(FileAccess.get_file_as_bytes(f))
		if files.is_empty():
			_source_why = "no scripts under res://src"
		if _source_why == "":
			_source = h.finish().hex_encode()
		else:
			print("world cache: off for this process: %s" % _source_why)
	var out := _source
	_lock.unlock()
	return out


static func _scripts(at: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(at):
		if f.ends_with(".gd"):
			out.append(at.path_join(f))
	for d in DirAccess.get_directories_at(at):
		_scripts(at.path_join(d), out)


# --- the file -------------------------------------------------------------------
# MAGIC, the key (u32 length + utf-8), the payload's raw size (u64), its md5 (16
# bytes), the payload: var_to_bytes of encode()'s plain form, zstd.

## Write `w` under `key` at `path`, whole or not at all.
static func write(path: String, key: String, w: WorldData) -> Error:
	var raw := encode(w)
	if raw.is_empty():
		return ERR_INVALID_DATA
	var body := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK and err != ERR_ALREADY_EXISTS:
		return err
	var tmp := "%s.%d-%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var k := key.to_utf8_buffer()
	f.store_buffer(MAGIC.to_ascii_buffer())
	f.store_32(k.size())
	f.store_buffer(k)
	f.store_64(raw.size())
	f.store_buffer(_md5(body))
	f.store_buffer(body)
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CANT_WRITE
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
	return err


## The world kept at `path` under exactly `key`, or null (none, another key,
## damaged).
static func read(path: String, key: String) -> WorldData:
	if not FileAccess.file_exists(path):
		return null
	var b := FileAccess.get_file_as_bytes(path)
	var k := key.to_utf8_buffer()
	var at := MAGIC.length()
	if b.size() < at + 4 or b.slice(0, at).get_string_from_ascii() != MAGIC:
		return null
	var n := b.decode_u32(at)
	at += 4
	if b.size() < at + n + 24 or b.slice(at, at + n) != k:
		return null
	at += n
	var raw_size := b.decode_u64(at)
	at += 8
	var sum := b.slice(at, at + 16)
	at += 16
	var body := b.slice(at)
	if _md5(body) != sum:
		return null
	var w := decode(body.decompress(raw_size, FileAccess.COMPRESSION_ZSTD))
	if w != null:
		_touch(path)
	return w


static func _md5(b: PackedByteArray) -> PackedByteArray:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	if not b.is_empty():
		h.update(b)
	return h.finish()


## Move the entry's mtime to now: its own first byte written back over itself.
static func _touch(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return
	var first := f.get_8()
	f.seek(0)
	f.store_8(first)
	f.close()


## Drop the least recently used entries past CAP_BYTES, and temp files a killed
## writer left.
static func evict(at: String, cap: int = CAP_BYTES) -> void:
	if not DirAccess.dir_exists_absolute(at):
		return
	var now := int(Time.get_unix_time_from_system())
	var rows: Array = []
	var total := 0
	for f in DirAccess.get_files_at(at):
		var p := at.path_join(f)
		if f.ends_with(".tmp"):
			if now - FileAccess.get_modified_time(p) > STALE_TMP_SEC:
				DirAccess.remove_absolute(p)
		elif f.ends_with(EXT):
			var bytes := FileAccess.get_size(p)
			total += bytes
			rows.append([FileAccess.get_modified_time(p), bytes, p])
	if total <= cap:
		return
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for r: Array in rows:
		if total <= cap:
			break
		DirAccess.remove_absolute(String(r[2]))
		total -= int(r[1])


# --- the world as bytes ---------------------------------------------------------

## Every script variable of `w` and its metadata, as bytes; empty when the world
## holds something this cannot spell (an object with no script).
static func encode(w: WorldData) -> PackedByteArray:
	var bad: Array[String] = []
	var fields := {}
	for p: Dictionary in w.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields[p.name] = _plain(w.get(p.name), bad)
	var meta := {}
	for m: StringName in w.get_meta_list():
		meta[m] = _plain(w.get_meta(m), bad)
	if not bad.is_empty():
		push_error("world cache: cannot keep %s" % ", ".join(bad))
		return PackedByteArray()
	return var_to_bytes({&"seed": w.seed_value, &"size": w.size, &"fields": fields, &"meta": meta})


## The world encode() was given, or null for bytes that are not one.
static func decode(raw: PackedByteArray) -> WorldData:
	if raw.is_empty():
		return null
	var d: Variant = bytes_to_var(raw)
	if typeof(d) != TYPE_DICTIONARY or not (d as Dictionary).has(&"fields"):
		return null
	var w := WorldData.new(int(d[&"seed"]), int(d[&"size"]))
	var fields: Dictionary = d[&"fields"]
	for name: Variant in fields:
		w.set(StringName(name), _live(fields[name]))
	var meta: Dictionary = d[&"meta"]
	for name: Variant in meta:
		w.set_meta(StringName(name), _live(meta[name]))
	return w


## `v` with every object in it spelled as data ({OBJ: [script path, fields]}, a
## typed array of objects as {OBJS: [class, script path, items]}). Containers with
## no object in them come back as themselves, uncopied.
static func _plain(v: Variant, bad: Array[String]) -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			var o := v as Object
			if o == null:
				return null
			var s := o.get_script() as Script
			if s == null or s.resource_path == "":
				bad.append(o.get_class())
				return null
			var f := {}
			for p: Dictionary in o.get_property_list():
				if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
					f[p.name] = _plain(o.get(p.name), bad)
			return {OBJ: [s.resource_path, f]}
		TYPE_ARRAY:
			var a := v as Array
			if a.get_typed_builtin() == TYPE_OBJECT:
				var items := []
				for e: Variant in a:
					items.append(_plain(e, bad))
				var ts := a.get_typed_script() as Script
				return {OBJS: [a.get_typed_class_name(), ts.resource_path if ts != null else "", items]}
			var out := a
			for i in a.size():
				var e: Variant = a[i]
				var t := typeof(e)
				if t != TYPE_OBJECT and t != TYPE_ARRAY and t != TYPE_DICTIONARY:
					continue
				var q: Variant = _plain(e, bad)
				if not is_same(q, e):
					if is_same(out, a):
						out = a.duplicate()
					out[i] = q
			return out
		TYPE_DICTIONARY:
			var d := v as Dictionary
			var out := d
			for k: Variant in d:
				if typeof(k) == TYPE_OBJECT:
					bad.append("an object key")
					continue
				var e: Variant = d[k]
				var t := typeof(e)
				if t != TYPE_OBJECT and t != TYPE_ARRAY and t != TYPE_DICTIONARY:
					continue
				var q: Variant = _plain(e, bad)
				if not is_same(q, e):
					if is_same(out, d):
						out = d.duplicate()
					out[k] = q
			return out
	return v


## The inverse of `_plain`, in place: decoded containers are this call's own.
static func _live(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var a := v as Array
			for i in a.size():
				var t := typeof(a[i])
				if t == TYPE_ARRAY or t == TYPE_DICTIONARY:
					a[i] = _live(a[i])
			return a
		TYPE_DICTIONARY:
			var d := v as Dictionary
			if d.size() == 1 and d.has(OBJ):
				var spelled: Array = d[OBJ]
				var o := _make(load(String(spelled[0])) as Script)
				var f: Dictionary = spelled[1]
				for name: Variant in f:
					o.set(StringName(name), _live(f[name]))
				return o
			if d.size() == 1 and d.has(OBJS):
				var spelled: Array = d[OBJS]
				var path := String(spelled[1])
				var items: Array = _live(spelled[2])
				return Array(items, TYPE_OBJECT, StringName(spelled[0]), load(path) if path != "" else null)
			for k: Variant in d:
				var t := typeof(d[k])
				if t == TYPE_ARRAY or t == TYPE_DICTIONARY:
					d[k] = _live(d[k])
			return d
	return v


## A new object of script `s`, its constructor's required arguments given their
## types' zero values (WorldProp takes five); every field is set after.
static func _make(s: Script) -> Object:
	var args := []
	for m: Dictionary in s.get_script_method_list():
		if m.name == "_init":
			var given: Array = m.args
			for i in given.size() - (m.default_args as Array).size():
				args.append(type_convert(null, int((given[i] as Dictionary).type)))
			break
	return s.callv(&"new", args)
