class_name GameConfig
## The master configuration this run of the game is made from (docs/DEV.md).
##
##   GameConfig.value("rules.clock")        what a reader asks; the default when nothing says otherwise
##   GameConfig.use("playtest")             make a configuration file the active one ("" or why not)
##   GameConfig.use_stamp(stamp)            an exported build's own, from its stamp
##   GameConfig.set_value(id, v)            an edit on the slate, live for this session ("" or why not)
##   GameConfig.keep() / keep_as(name)      write the edits into a configuration file
##   GameConfig.fill_boot(o) / fill_new_game(o)   what a configuration puts into a start
##
## A file is `configs/<name>.json`: {"base": "<name>", "settings": {id: value}}.
## It holds only what it changes over its base (and the base over ConfigSchema's
## defaults). Files written on the machine the game is built on go into the
## repository's configs/; anywhere else (a web build, an app) into
## user://dev/configs/, where a copy of a packed configuration shadows it (the
## test runner writes neither: its own user://test-dev/configs/).
##
## Light on purpose, like ConfigSchema: main.gd calls it before the first frame.
## Membership of choices filled from content is ConfigChoices'.

const DIR := "res://configs"
const NAME_RULE := "^[a-z0-9][a-z0-9-]{0,23}$"
## How deep `base` may chain before it is called a loop.
const MAX_CHAIN := 8

## The configuration in use; "" for none (every setting at its default).
static var active := ""
## Where it came from: &"none", &"file" (configs/), &"user", &"stamp" (this build's own).
static var source: StringName = &"none"
## The active configuration's settings with its bases merged under them.
static var _settings: Dictionary = {}
## Its chain, itself first.
static var chain: PackedStringArray = []
## Changed on the slate this session and not yet kept: id -> value.
static var edits: Dictionary = {}
## Bumped on every change a reader might act on (the dev system applies live rules on it).
static var revision := 0


## Configurations kept on this device (the test runner's own under test).
static func user_dir() -> String:
	return DevMode.user_root().path_join("configs")


static func valid_name(name: String) -> bool:
	return RegEx.create_from_string(NAME_RULE).search(name) != null


## Every configuration this build can see, packed and the user's, by name.
static func names() -> PackedStringArray:
	var seen := {}
	for dir: String in [DIR, user_dir()]:
		for f in _files(dir):
			if f.ends_with(".json") and valid_name(f.get_basename()):
				seen[f.get_basename()] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


static func exists(name: String) -> bool:
	return valid_name(name) and (FileAccess.file_exists(user_dir().path_join(name + ".json")) or FileAccess.file_exists(DIR.path_join(name + ".json")))


## Where a configuration named `name` is read from: the user's copy first.
static func path_of(name: String) -> String:
	var user := user_dir().path_join(name + ".json")
	return user if FileAccess.file_exists(user) else DIR.path_join(name + ".json")


## The file as written: {ok, why, base, settings}. Settings are coerced to the
## types the game reads, and each is checked against the schema.
static func read_file(name: String) -> Dictionary:
	if not valid_name(name):
		return {"ok": false, "why": "%s is not a configuration's name" % name}
	var path := path_of(name)
	if not FileAccess.file_exists(path):
		return {"ok": false, "why": "there is no configuration called %s" % name}
	return parse(FileAccess.get_file_as_string(path), name)


## A configuration from its JSON text (a file, or pasted): {ok, why, base, settings}.
static func parse(text: String, name: String = "") -> Dictionary:
	# JSON.parse_string writes an error to the log for text that is not JSON, and
	# pasted text can be anything.
	var json := JSON.new()
	var data: Variant = json.data if json.parse(text) == OK else null
	if not (data is Dictionary):
		return {"ok": false, "why": "%s is not a configuration" % (name if name != "" else "that")}
	var base := str(data.get("base", ""))
	if base != "" and not valid_name(base):
		return {"ok": false, "why": "%s: base %s is not a configuration's name" % [name, base]}
	var raw: Variant = data.get("settings", {})
	if not (raw is Dictionary):
		return {"ok": false, "why": "%s: settings are not a table" % name}
	var settings := {}
	for k: Variant in raw:
		var id := str(k)
		var v: Variant = ConfigSchema.coerce(id, raw[k])
		var why := ConfigSchema.check(id, v)
		if why != "":
			return {"ok": false, "why": "%s: %s" % [name, why]}
		settings[id] = v
	return {"ok": true, "why": "", "base": base, "settings": settings, "name": str(data.get("name", name))}


## A configuration with its bases merged under it: {ok, why, chain, settings}.
static func resolve(name: String) -> Dictionary:
	var names_seen := PackedStringArray()
	var layers: Array[Dictionary] = []
	var at := name
	while at != "":
		if names_seen.has(at):
			return {"ok": false, "why": "%s: its bases go round in a loop" % name, "chain": names_seen, "settings": {}}
		if names_seen.size() >= MAX_CHAIN:
			return {"ok": false, "why": "%s: more than %d bases deep" % [name, MAX_CHAIN], "chain": names_seen, "settings": {}}
		var f := read_file(at)
		if not f.ok:
			return {"ok": false, "why": f.why, "chain": names_seen, "settings": {}}
		names_seen.append(at)
		layers.append(f.settings)
		at = f.base
	var merged := {}
	for i in range(layers.size() - 1, -1, -1):
		for id: String in layers[i]:
			merged[id] = layers[i][id]
	return {"ok": true, "why": "", "chain": names_seen, "settings": merged}


## Make `name` the active configuration. Edits not kept are dropped. Returns
## "" or why not (and then nothing changes).
static func use(name: String) -> String:
	if name == "":
		clear()
		return ""
	var r := resolve(name)
	if not r.ok:
		return r.why
	active = name
	source = &"user" if path_of(name).begins_with("user://") else &"file"
	chain = r.chain
	_settings = r.settings
	edits.clear()
	revision += 1
	return ""


## An exported build's own configuration, as its stamp carries it (resolved when
## the build was made, so the build never depends on the files it was made from).
static func use_stamp(stamp: Dictionary) -> void:
	active = str(stamp.get("config", ""))
	source = &"stamp"
	chain = PackedStringArray(stamp.get("chain", []))
	_settings = {}
	var raw: Variant = stamp.get("settings", {})
	if raw is Dictionary:
		for k: Variant in raw:
			var id := str(k)
			var v: Variant = ConfigSchema.coerce(id, raw[k])
			if ConfigSchema.check(id, v) == "":
				_settings[id] = v
			else:
				push_warning("stamp: %s" % ConfigSchema.check(id, v))
	edits.clear()
	revision += 1


static func clear() -> void:
	active = ""
	source = &"none"
	chain = PackedStringArray()
	_settings = {}
	edits.clear()
	revision += 1


static func value(id: String) -> Variant:
	if edits.has(id):
		return edits[id]
	if _settings.has(id):
		return _settings[id]
	return ConfigSchema.default_of(id)


## What the active configuration says before this session's edits.
static func kept_value(id: String) -> Variant:
	return _settings[id] if _settings.has(id) else ConfigSchema.default_of(id)


## An edit for this session. It is live at once for readers that read live, and
## kept only by keep(). Setting a value back to what is kept drops the edit.
static func set_value(id: String, v: Variant) -> String:
	v = ConfigSchema.coerce(id, v)
	var why := ConfigSchema.check(id, v)
	if why != "":
		return why
	if ConfigSchema.same(v, kept_value(id)):
		edits.erase(id)
	else:
		edits[id] = v
	revision += 1
	return ""


static func forget_edits() -> void:
	edits.clear()
	revision += 1


## Every setting as this session has it, where it differs from the default.
static func current() -> Dictionary:
	var out := {}
	for id in ConfigSchema.ids():
		var v: Variant = value(id)
		if not ConfigSchema.same(v, ConfigSchema.default_of(id)):
			out[id] = v
	return out


## Where configurations are written here: the repository on the machine the game
## is built on, user:// anywhere else.
static func write_dir() -> String:
	if DevMode.local() and not OS.get_cmdline_args().has("-s"):
		return ProjectSettings.globalize_path(DIR)
	return user_dir()


## Write the active configuration with this session's edits into its file,
## keeping its base. Returns "" or why not.
static func keep() -> String:
	if active == "" or source == &"stamp":
		return "Keep it under a name first."
	var f := read_file(active)
	if not f.ok:
		return f.why
	return _write(active, f.base)


## Write this session's settings as a new configuration `name`, on the same base
## as the active one, and make it the active one.
static func keep_as(name: String) -> String:
	if not valid_name(name):
		return "A name is small letters, digits and dashes."
	var base := ""
	if active != "" and source != &"stamp":
		var f := read_file(active)
		base = f.base if f.ok else ""
	var why := _write(name, base)
	if why != "":
		return why
	return use(name)


static func _write(name: String, base: String) -> String:
	var under := {}
	if base != "":
		var r := resolve(base)
		if not r.ok:
			return r.why
		under = r.settings
	var settings := {}
	for id in ConfigSchema.ids():
		var v: Variant = value(id)
		var beneath: Variant = under[id] if under.has(id) else ConfigSchema.default_of(id)
		if not ConfigSchema.same(v, beneath):
			settings[id] = v
	var dir := write_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join(name + ".json"), FileAccess.WRITE)
	if f == null:
		return "It would not write %s." % name
	f.store_string(to_text(base, settings))
	f.close()
	if active == name:
		_settings = resolve(name).get("settings", _settings)
		edits.clear()
	revision += 1
	return ""


## A configuration as the file holds it, with a stable order so a diff of a
## kept configuration shows only what changed.
static func to_text(base: String, settings: Dictionary) -> String:
	var data := {}
	if base != "":
		data["base"] = base
	data["settings"] = settings
	return JSON.stringify(data, "\t", true) + "\n"


## The session's configuration as text to copy out of a build: its name, base and
## every setting that differs from a default (so it pastes anywhere whole).
static func export_text() -> String:
	var data := {"name": active if active != "" else "copied", "settings": current()}
	return JSON.stringify(data, "\t", true) + "\n"


## Settings a configuration puts into a start before anything else reads it: the
## island and its size, unless the command line named them.
static func fill_boot(o: BootOptions, explicit: Dictionary = {}) -> void:
	if not explicit.has("seed"):
		o.seed_value = int(value("world.seed"))
	if not explicit.has("size"):
		o.size = int(value("world.size"))


## What a NEW game takes from the configuration (never a loaded one): the hour,
## where it wakes, held weather, the kit, the gear and the lamp. Anything the
## command line named stays as named. With nothing set, `o` is left as it was.
static func fill_new_game(o: BootOptions, explicit: Dictionary = {}) -> void:
	if o.load_slot >= 0:
		return
	if not explicit.has("hour"):
		o.hour = float(value("world.hour"))
	var start := str(value("world.start"))
	if start != "spawn" and not (explicit.has("at") or explicit.has("village") or explicit.has("place")):
		o.place = start
	var weather := str(value("world.weather"))
	if weather != "rules" and not explicit.has("weather"):
		o.weather = "%s:%s" % [weather, str(value("world.weather_strength"))]
	if not explicit.has("give"):
		var kit: Dictionary = value("start.kit")
		for id: String in kit:
			o.give[StringName(id)] = int(o.give.get(StringName(id), 0)) + int(kit[id])
	if not explicit.has("fit"):
		for id: Variant in value("start.fit"):
			if not o.fit.has(str(id)):
				o.fit.append(str(id))
	if bool(value("start.lamp")) and not explicit.has("lamp"):
		o.lamp = true


static func _files(dir: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(dir):
		return PackedStringArray()
	var out := DirAccess.get_files_at(dir)
	return out
