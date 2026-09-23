class_name DevNotes
## Notes: feedback that can be acted on (docs/DESIGN.md). A note is a picture of the
## world as it was, a kind, a few words, what build and configuration it was, the
## state of the game, and the command that stages that moment again:
##
##   tools/shot.sh shots/notes/<id>.png --seed=1 --size=512 --at=212.4,301.9 --hour=19.25 ...
##
##   DevNotes.make(game, kind, words)     the note of this moment (no picture)
##   DevNotes.write(note, picture)        keep it: user://dev/notes, and shots/notes/ from source
##   DevNotes.list()                      every kept note, newest first
##   DevNotes.restage(note)               BootOptions that start a game at that moment
##   DevNotes.text(note)                  the note as JSON text, to copy out of a build
##
## Notes live on the device that wrote them; from source they are also written
## beside the shots, where a session working on the game can Read them.

const SHOTS := "shots/notes"
const KINDS: Array[String] = ["bug", "look", "feel", "idea", "slow"]
const VERSION := 1
## What a new game carries before anything is given (game.gd, 50_survival).
const STARTS_WITH := {&"knife": 1, &"lamp": 1}


## Where notes are kept on this device.
static func folder() -> String:
	return DevMode.user_root().path_join("notes")


## The note of this moment in `game`. `picture` is kept separately (write()).
static func make(game: Game, kind: String, words: String, at_unix: int = -1) -> Dictionary:
	if at_unix < 0:
		at_unix = int(Time.get_unix_time_from_system())
	var id := "note-%s" % Time.get_datetime_string_from_unix_time(at_unix + _utc_offset()).replace("-", "").replace("T", "-").replace(":", "")
	var state := state_of(game)
	var stamp := DevStamp.current()
	var note := {
		"note": VERSION,
		"id": id,
		"at": at_unix,
		"kind": kind if KINDS.has(kind) else "bug",
		"words": words,
		"build": DevStamp.label(stamp) if not stamp.is_empty() else "source %s" % DevStamp.source_commit(),
		"host": DevMode.host(),
		"config": GameConfig.active,
		"edits": GameConfig.edits.duplicate(true),
		"touched": DevMode.touched,
		"state": state,
	}
	note["repro"] = repro(note)
	return note


## What of the game a note keeps: enough to stage the moment and to read it.
static func state_of(game: Game) -> Dictionary:
	var p := game.player.pos
	var w := game.world
	var b := BiomeRegistry.at(w, p)
	var weather := DevCheats.weather_here(game)
	# What was carried beyond what every new game starts with, so staging it gives
	# the difference and not a second knife and lamp.
	var carried := {}
	for id: StringName in game.inventory.items:
		var n := game.inventory.count(id) - int(STARTS_WITH.get(id, 0))
		if n > 0:
			carried[String(id)] = n
	var worn: Array = []
	var gear := DevCheats.system(game, "54_gear")
	if gear != null:
		var loadout: Loadout = gear.get("loadout")
		for id in loadout.all_ids():
			# The thing in hand fills the tool slot; --held stages that, not --fit.
			if Gear.is_wearable(id) or Gear.is_module(id):
				worn.append(String(id))
	var fps := Engine.get_frames_per_second()
	return {
		"seed": w.seed_value,
		"size": w.size,
		"pos": [snappedf(p.x, 0.1), snappedf(p.y, 0.1)],
		"level": w.level_at(floori(p.x), floori(p.y)),
		"ground": Ground.NAMES[w.ground_at(floori(p.x), floori(p.y))] if w.ground_at(floori(p.x), floori(p.y)) < Ground.NAMES.size() else "",
		"land": String(b.id),
		"region": w.region_at(floori(p.x), floori(p.y)),
		"day": game.clock.day() + 1,
		"hour": snappedf(game.clock.hour(), 0.01),
		"clock": game.clock.label(),
		"weather": String(weather.kind),
		"strength": snappedf(float(weather.strength), 0.01),
		"weather_held": bool(weather.forced),
		"held": String(game.inventory.held),
		"carried": carried,
		"worn": worn,
		"lamp": game.body.lamp_lit,
		"health": game.body.health,
		"zoom": snappedf(game.camera.view_height, 0.1),
		"fps": fps,
	}


## The command that stages the note's moment again from source.
static func repro(note: Dictionary) -> String:
	var s: Dictionary = note.state
	var parts := PackedStringArray(["tools/shot.sh", "%s/%s.png" % [SHOTS, note.id]])
	parts.append("--seed=%d" % int(s.seed))
	parts.append("--size=%d" % int(s.size))
	parts.append("--at=%s,%s" % [str(s.pos[0]), str(s.pos[1])])
	parts.append("--hour=%s" % str(s.hour))
	if float(s.strength) > 0.0 or bool(s.weather_held):
		parts.append("--weather=%s:%s" % [s.weather, str(s.strength)])
	else:
		parts.append("--weather=clear:0")
	if bool(s.lamp):
		parts.append("--lamp")
	if str(s.held) != "" and str(s.held) != "knife":
		parts.append("--held=%s" % s.held)
	var give := PackedStringArray()
	for id: String in (s.carried as Dictionary):
		give.append("%s:%d" % [id, int(s.carried[id])])
	if not give.is_empty():
		parts.append("--give=%s" % ",".join(give))
	if not (s.worn as Array).is_empty():
		parts.append("--fit=%s" % ",".join(PackedStringArray(s.worn)))
	if not is_equal_approx(float(s.zoom), 15.0):
		parts.append("--zoom=%s" % str(s.zoom))
	if str(note.get("config", "")) != "":
		parts.append("--config=%s" % note.config)
	return " ".join(parts)


## Options that start a game at the note's moment.
static func restage(note: Dictionary) -> BootOptions:
	var s: Dictionary = note.state
	var o := BootOptions.new()
	o.seed_value = int(s.seed)
	o.size = int(s.size)
	o.at = Vector2(float(s.pos[0]), float(s.pos[1]))
	o.hour = float(s.hour)
	if bool(s.weather_held):
		o.weather = "%s:%s" % [s.weather, str(s.strength)]
	o.lamp = bool(s.lamp)
	if str(s.held) != "":
		o.held = str(s.held)
	for id: String in (s.carried as Dictionary):
		o.give[StringName(id)] = int(s.carried[id])
	for id: Variant in s.worn:
		o.fit.append(str(id))
	o.zoom = float(s.zoom)
	return o


## Keep a note and its picture. Returns "" or why not.
static func write(note: Dictionary, picture: Image) -> String:
	DirAccess.make_dir_recursive_absolute(folder())
	var err := _write_pair(folder(), note, picture)
	if err != "":
		return err
	if DevMode.local() and not DevMode.tool_run:
		var mirror := DevMode.project_path(SHOTS)
		DirAccess.make_dir_recursive_absolute(mirror)
		_write_pair(mirror, note, picture)
	return ""


static func _write_pair(dir: String, note: Dictionary, picture: Image) -> String:
	var f := FileAccess.open(dir.path_join(note.id + ".json"), FileAccess.WRITE)
	if f == null:
		return "It would not keep the note."
	f.store_string(text(note))
	f.close()
	if picture != null and not picture.is_empty():
		picture.save_png(dir.path_join(note.id + ".png"))
	return ""


static func text(note: Dictionary) -> String:
	return JSON.stringify(note, "\t", true) + "\n"


## Every kept note on this device, newest first.
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(folder()):
		return out
	for f in DirAccess.get_files_at(folder()):
		if not f.ends_with(".json"):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(folder().path_join(f))) != OK or not (json.data is Dictionary):
			continue
		var n: Dictionary = json.data
		if n.has("note") and n.has("state") and n.has("id"):
			out.append(n)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("at", 0)) > float(b.get("at", 0)))
	return out


static func picture(note: Dictionary) -> ImageTexture:
	var path := folder().path_join(str(note.get("id", "")) + ".png")
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null


static func remove(note: Dictionary) -> void:
	for ext: String in [".json", ".png"]:
		var path := folder().path_join(str(note.get("id", "")) + ext)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Hand a note to the person holding the build: the browser downloads its picture
## and its text; anywhere else, its folder opens.
static func hand_over(note: Dictionary) -> String:
	if DevMode.web():
		var png := folder().path_join(str(note.id) + ".png")
		if FileAccess.file_exists(png):
			JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(png), str(note.id) + ".png", "image/png")
		JavaScriptBridge.download_buffer(text(note).to_utf8_buffer(), str(note.id) + ".json", "application/json")
		return "Downloading %s." % note.id
	var dir := DevMode.project_path(SHOTS) if DevMode.local() else ProjectSettings.globalize_path(folder())
	OS.shell_open(dir)
	return "Opened %s." % dir.get_file()


static func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
