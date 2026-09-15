class_name SoundBank
extends RefCounted
## Every sound the game can play, by key, generated on demand and cached.
##
## A key is "name" or "name:variant" (step_sand:2). SHEET is the mix sheet: for
## each sound its category (which fixes rate, looping, bus, high-pass and the
## window tests hold it to), the level it is HEARD at in dB relative to the
## weather bed at full strength (SoundMix.REF_DBFS), and how many variants
## exist. render() measures what the recipe made and sets the call gain that
## puts it at that level, so a recipe edit never silently re-balances the mix,
## and a recipe that needs an absurd gain fails its test instead.
##
## Recipes live in SoundMachines, SoundBeds, SoundEffects, SoundSignals,
## SoundCreatures, SoundWork and SoundMusic; emitted names reach the sheet
## through SoundNames. render() is pure and thread-safe. At run time one
## shared bank bakes on WorkerThreadPool (at most MAX_TASKS at once, so a frame
## never waits) or, without threads, one sound per frame.

const PEAK := 0.89
const MAX_TASKS := 2
## Where one sound alone may peak after its call gain and bus (dBFS): under the
## Master limiter's -0.5, so the limiter only ever meets sums. A recipe whose
## crest would carry it over has its transients limited at bake time.
const CEILING_DBFS := -1.5
## Bake-time limiter release per category (s): short for transients, long for
## thunder's roll.
const RELEASE := {&"event": 0.008, &"step": 0.006, &"ui": 0.006, &"scatter": 0.02, &"thunder": 0.25}
## Without worker threads these bake on the main thread (short one-shots, one a
## frame); beds, machines, weather and music would freeze a frame for seconds,
## so they are only played when the disk cache already holds them.
const MAIN_THREAD_CATEGORIES: Array[StringName] = [&"event", &"step", &"ui", &"scatter"]

## rate, loop, bus, hp (4th-order high-pass corner, Hz), window (heard dB).
const CATEGORIES := {
	&"machine": {"rate": 44100, "loop": true, "bus": &"Machines", "hp": 110.0, "window": [-7.0, 1.0]},
	&"bed": {"rate": 22050, "loop": true, "bus": &"Ambience", "hp": 100.0, "window": [-10.0, -2.0]},
	&"weather": {"rate": 22050, "loop": true, "bus": &"Ambience", "hp": 100.0, "window": [-3.0, 2.0]},
	&"scatter": {"rate": 22050, "loop": false, "bus": &"Ambience", "hp": 110.0, "window": [-15.0, -3.0]},
	&"event": {"rate": 44100, "loop": false, "bus": &"SFX", "hp": 90.0, "window": [-4.0, 5.0]},
	&"step": {"rate": 44100, "loop": false, "bus": &"SFX", "hp": 90.0, "window": [-4.0, 5.0]},
	&"thunder": {"rate": 22050, "loop": false, "bus": &"SFX", "hp": 55.0, "window": [6.0, 10.0]},
	&"ui": {"rate": 44100, "loop": false, "bus": &"UI", "hp": 150.0, "window": [-18.0, -6.0]},
	&"music": {"rate": 22050, "loop": false, "bus": &"Music", "hp": 80.0, "window": [-12.0, -3.0]},
}

## name: [category, heard dB, variants]
const SHEET := {
	# Machines at level 1.0 (standing on it). The warden is the quietest.
	&"machine_watcher": [&"machine", -3.5, 1],
	&"machine_longlegs": [&"machine", -3.0, 1],
	&"machine_harvester": [&"machine", -1.0, 1],
	&"machine_cutter": [&"machine", -2.0, 1],
	&"machine_hauler": [&"machine", -2.0, 1],
	&"machine_warden": [&"machine", -6.5, 1],
	&"machine_sweeper": [&"machine", -3.0, 1],
	&"machine_dredger": [&"machine", -2.5, 1],
	&"machine_lineman": [&"machine", -4.0, 1],
	&"machine_flock": [&"machine", -3.5, 1],
	&"machine_runner": [&"machine", -4.0, 1],
	&"machine_clerk": [&"machine", -6.0, 1],
	# Country beds at weight 1 (deep inside the country). The snowfield is the quietest.
	&"bed_shore": [&"bed", -3.0, 1],
	&"bed_wind": [&"bed", -4.0, 1],
	&"bed_pines": [&"bed", -4.0, 1],
	&"bed_moss": [&"bed", -5.0, 1],
	&"bed_snowfield": [&"bed", -7.5, 1],
	&"bed_bones": [&"bed", -4.5, 1],
	&"bed_burning": [&"bed", -3.5, 1],
	&"bed_river": [&"bed", -5.0, 1],
	# Machinery nobody switched off, carried on still night air from far away.
	&"bed_far_works": [&"bed", -9.0, 1],
	# Weather beds at full strength. Rain is the reference.
	&"weather_rain": [&"weather", 0.0, 1],
	&"weather_storm": [&"weather", 1.5, 1],
	&"weather_gust": [&"weather", -1.5, 1],
	&"weather_hail": [&"weather", -0.5, 1],
	&"weather_snow": [&"weather", -2.5, 1],
	&"weather_sand": [&"weather", 0.5, 1],
	&"weather_blizzard": [&"weather", 1.5, 1],
	&"weather_ash": [&"weather", -2.5, 1],
	# Scattered over the beds.
	&"pines_snap": [&"scatter", -8.0, 4],
	&"pines_creak": [&"scatter", -9.0, 3],
	&"moss_drip": [&"scatter", -9.5, 4],
	&"moss_bloop": [&"scatter", -10.0, 2],
	&"snow_creak": [&"scatter", -10.0, 3],
	&"bones_tick": [&"scatter", -9.0, 3],
	&"burning_crackle": [&"scatter", -10.0, 4],
	&"burning_thud": [&"scatter", -6.0, 2],
	&"shore_gull": [&"scatter", -7.0, 3],
	&"fog_horn": [&"scatter", -5.0, 1],
	&"heat_tick": [&"scatter", -11.0, 3],
	&"bird_song": [&"scatter", -11.0, 6],
	&"pines_drip": [&"scatter", -10.0, 4],
	&"moss_wisp": [&"scatter", -12.5, 3],
	&"wire_sing": [&"scatter", -11.0, 3],
	# Footfalls, one family per ground.
	&"step_sand": [&"step", -3.0, 4],
	&"step_grass": [&"step", -3.0, 4],
	&"step_heath": [&"step", -3.0, 4],
	&"step_mud": [&"step", -3.0, 4],
	&"step_needles": [&"step", -3.5, 4],
	&"step_snow": [&"step", -3.0, 4],
	&"step_ice": [&"step", -3.0, 4],
	&"step_stone": [&"step", -3.0, 4],
	&"step_gravel": [&"step", -2.5, 4],
	&"step_shingle": [&"step", -2.5, 4],
	&"step_ash": [&"step", -3.5, 4],
	&"step_clinker": [&"step", -3.0, 4],
	&"step_dirt": [&"step", -3.5, 4],
	&"step_wood": [&"step", -3.0, 4],
	&"step_water": [&"step", -2.0, 4],
	# The fight.
	&"swing": [&"event", -1.0, 3],
	&"whiff": [&"event", -2.0, 2],
	&"hit_flesh": [&"event", 3.0, 3],
	&"hit_plate": [&"event", 2.0, 3],
	&"dodge": [&"event", -2.0, 2],
	&"grip": [&"event", 2.0, 1],
	&"pull": [&"event", 0.0, 2],
	&"machine_down": [&"event", 2.0, 1],
	&"alert": [&"event", 0.0, 1],
	&"downed": [&"event", 2.0, 1],
	# What a machine does to you (SoundSignals): each alert is its own bed made urgent.
	&"alert_watcher": [&"event", 0.0, 1],
	&"alert_longlegs": [&"event", 0.5, 1],
	&"alert_harvester": [&"event", 1.0, 1],
	&"alert_cutter": [&"event", 1.0, 1],
	&"alert_hauler": [&"event", 0.5, 1],
	&"alert_warden": [&"event", -2.5, 1],
	&"alert_sweeper": [&"event", -1.0, 1],
	&"alert_dredger": [&"event", 0.5, 1],
	&"alert_lineman": [&"event", 0.0, 1],
	&"alert_flock": [&"event", -0.5, 1],
	&"alert_runner": [&"event", -1.0, 1],
	&"alert_clerk": [&"event", -1.5, 1],
	&"watcher_call": [&"event", 1.0, 1],
	&"second_act": [&"event", 3.0, 1],
	&"loose": [&"event", 0.0, 1],
	&"snatch_flock": [&"event", 1.0, 1],
	&"snatch_warden": [&"event", 2.0, 1],
	&"snatch_clerk": [&"event", 0.0, 1],
	# The tell before a strike: the fight is read by ear (SoundSignals).
	&"windup": [&"event", 0.0, 1],
	&"windup_watcher": [&"event", 0.0, 1],
	&"windup_longlegs": [&"event", 0.5, 1],
	&"windup_harvester": [&"event", 1.0, 1],
	&"windup_cutter": [&"event", 1.0, 1],
	&"windup_hauler": [&"event", 0.5, 1],
	&"windup_warden": [&"event", -2.0, 1],
	&"windup_sweeper": [&"event", -1.0, 1],
	&"windup_dredger": [&"event", 0.5, 1],
	&"windup_lineman": [&"event", 0.0, 1],
	&"windup_flock": [&"event", -0.5, 1],
	&"windup_runner": [&"event", -0.5, 1],
	&"windup_clerk": [&"event", -1.5, 1],
	# The living (SoundCreatures).
	&"dog_bark": [&"event", 1.0, 3],
	&"dog_growl": [&"event", 0.5, 2],
	&"bull_snort": [&"event", 2.0, 2],
	&"bull_paw": [&"event", 1.0, 2],
	&"gull_cry": [&"event", -1.0, 3],
	&"snatch_gull": [&"event", 0.0, 2],
	&"beast_down": [&"event", 1.0, 1],
	# Taking and making.
	&"break": [&"event", 1.0, 3],
	&"dig": [&"event", -1.0, 3],
	&"fell": [&"event", 1.0, 3],
	&"cut": [&"event", -2.0, 3],
	&"gather": [&"event", -3.0, 3],
	&"craft": [&"event", -1.0, 1],
	&"eat": [&"event", -3.0, 1],
	&"fire": [&"event", -1.0, 1],
	&"splash": [&"event", 1.0, 1],
	&"tree_fall": [&"event", 3.0, 1],
	&"pickup": [&"event", -3.0, 1],
	&"lamp_on": [&"event", -3.0, 1],
	&"lamp_off": [&"event", -3.5, 1],
	&"door": [&"event", -1.0, 1],
	# Hands at work (SoundWork).
	&"refuse": [&"event", -2.5, 1],
	&"scrape": [&"event", -2.0, 2],
	&"tap": [&"event", -2.0, 2],
	&"turn": [&"event", -1.0, 2],
	&"hone": [&"event", -2.0, 1],
	&"reedge": [&"event", 0.0, 1],
	&"build_fire": [&"event", -1.0, 1],
	&"build_bench": [&"event", 0.0, 1],
	&"build_kiln": [&"event", 0.0, 1],
	&"sleep": [&"event", -4.0, 1],
	&"tool_snap": [&"event", 1.5, 2],
	# Thunder only sits above everything.
	&"thunder": [&"thunder", 8.0, 2],
	&"thunder_far": [&"thunder", 6.5, 2],
	# The interface is the quietest thing in the mix.
	&"ui_move": [&"ui", -12.0, 1],
	&"ui_accept": [&"ui", -9.0, 1],
	&"ui_back": [&"ui", -9.0, 1],
	&"ui_refuse": [&"ui", -9.0, 1],
	&"book_open": [&"ui", -10.0, 1],
	&"book_close": [&"ui", -10.0, 1],
	# The slate (SoundSlate): synthetic, a little broken.
	&"ui_slate_click": [&"ui", -13.0, 1],
	&"ui_slate_confirm": [&"ui", -10.0, 1],
	&"ui_slate_back": [&"ui", -10.5, 1],
	&"ui_slate_deny": [&"ui", -10.0, 1],
	&"ui_slate_wake": [&"ui", -8.0, 1],
	&"ui_slate_sleep": [&"ui", -11.0, 1],
	&"ui_slate_switch": [&"ui", -12.0, 1],
	&"ui_slate_whine": [&"ui", -9.0, 1],
	&"ui_slate_ping": [&"ui", -8.0, 1],
	# The figure, per country. Variants: 0 arriving, 1 dawn, 2 dusk.
	&"music_coast": [&"music", -7.0, 3],
	&"music_pinewood": [&"music", -7.0, 3],
	&"music_moss": [&"music", -7.0, 3],
	&"music_snowfield": [&"music", -7.0, 3],
	&"music_bonelands": [&"music", -7.0, 3],
	&"music_burning": [&"music", -7.0, 3],
}


class Baked:
	extends RefCounted
	var key: StringName
	var name: StringName
	var variant := 0
	var category: StringName
	var rate := 44100
	var loop := false
	var bus: StringName
	## Level it is heard at (sheet), and the call gain that achieves it.
	var heard := 0.0
	var gain_db := 0.0
	var samples: PackedFloat32Array
	var pcm: PackedByteArray
	var stream: AudioStreamWAV
	var ms := 0
	## How far its transients were limited at bake to fit under CEILING_DBFS.
	var limited_db := 0.0
	## Loaded from the disk cache rather than generated this run.
	var from_disk := false


class Job:
	extends RefCounted
	var key: StringName
	var result: Baked
	var task := -1
	## A cache file to read instead of rendering, and to write after (or "").
	var cache_path := ""

	func run() -> void:
		if cache_path != "":
			result = SoundBank.load_cached(key, cache_path)
			if result != null:
				return
		result = SoundBank.render(key)
		result.pcm = Synth.to_pcm16(result.samples)
		if cache_path != "":
			SoundBank.save_cached(result, cache_path)


static var _shared: SoundBank

var threaded := true
## Keep float samples after baking (tools and tests); the game drops them.
var keep_samples := false
## False in screenshot runs: nothing bakes, so nothing plays.
var enabled := true
## Baked PCM kept between runs, under a folder per recipe version, so a second
## start plays at once. Empty = no disk (tests and tools never touch it).
var cache_dir := ""
var _cache_version_dir := ""
var _done: Dictionary = {}
var _jobs: Dictionary = {}
var _queue: Array[StringName] = []
var _pumped_frame := -1
var _on_disk: Dictionary = {}


static func shared() -> SoundBank:
	if _shared == null:
		_shared = SoundBank.new()
	return _shared


func _init() -> void:
	threaded = not OS.has_feature("web") or OS.has_feature("threads")


# ------------------------------------------------------------------ catalog

static func base_name(key: StringName) -> StringName:
	var s := String(key)
	var c := s.find(":")
	return StringName(s.substr(0, c)) if c >= 0 else key


static func variant_of(key: StringName) -> int:
	var s := String(key)
	var c := s.find(":")
	return s.substr(c + 1).to_int() if c >= 0 else 0


static func has_sound(key: StringName) -> bool:
	return SHEET.has(base_name(key))


static func variants(name: StringName) -> int:
	return int(SHEET[name][2]) if SHEET.has(name) else 0


static func category_of(name: StringName) -> StringName:
	return SHEET[name][0] if SHEET.has(name) else &""


## The key for a name and a variant number (wrapped into range).
static func key_for(name: StringName, variant: int) -> StringName:
	var v := variants(name)
	if v <= 1:
		return name
	return StringName("%s:%d" % [name, posmod(variant, v)])


static func names_in(category: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in SHEET:
		if SHEET[k][0] == category:
			out.append(k)
	return out


## Every key, variants expanded.
static func all_keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in SHEET:
		for i in maxi(1, int(SHEET[k][2])):
			out.append(key_for(k, i))
	return out


## Generates one sound: recipe, the category's high-pass (periodic for loops),
## peak normalisation, then the call gain for its sheet level. Pure: the same
## key gives the same samples on any thread.
static func render(key: StringName) -> Baked:
	var t0 := Time.get_ticks_msec()
	var b := Baked.new()
	b.key = key
	b.name = base_name(key)
	b.variant = variant_of(key)
	var row: Array = SHEET.get(b.name, [&"event", 0.0, 1])
	b.category = row[0]
	b.heard = row[1]
	var cat: Dictionary = CATEGORIES[b.category]
	b.rate = cat["rate"]
	b.loop = cat["loop"]
	b.bus = cat["bus"]
	var raw: PackedFloat32Array
	match b.category:
		&"machine":
			raw = SoundMachines.make(StringName(String(b.name).trim_prefix("machine_")))
		&"bed", &"weather", &"scatter":
			raw = SoundBeds.make(b.name, b.variant, b.rate)
		&"music":
			raw = SoundMusic.make(b.name, b.variant, b.rate)
		_:
			if SoundSignals.handles(b.name):
				raw = SoundSignals.make(b.name, b.variant, b.rate)
			elif SoundCreatures.handles(b.name):
				raw = SoundCreatures.make(b.name, b.variant, b.rate)
			elif SoundWork.handles(b.name):
				raw = SoundWork.make(b.name, b.variant, b.rate)
			elif SoundSlate.handles(b.name):
				raw = SoundSlate.make(b.name, b.variant, b.rate)
			else:
				raw = SoundEffects.make(b.name, b.variant, b.rate)
	Synth.highpass4(raw, b.rate, cat["hp"], b.loop)
	if not b.loop:
		raw = Synth.trim_tail(raw, b.rate)
		Synth.fade(raw, b.rate, 0.0008, 0.006)
	Synth.normalize(raw, PEAK)
	b.gain_db = _gain_for(raw, b)
	# Keep one sound under the Master limiter by its own crest: limit the
	# transients to the ceiling its gain allows, then take the gain again (the
	# loudest half-second hardly moves, so two or three rounds settle it).
	# A footfall's click is shaved and let go at once, so its body is untouched;
	# held sounds let go slower so the limiting never pumps.
	var release: float = RELEASE.get(b.category, 0.06)
	for _pass in 8:
		var allowed := db_to_linear(CEILING_DBFS - b.gain_db - SoundMix.bus_db(b.bus))
		if Synth.peak(raw) <= allowed:
			break
		Synth.limit(raw, b.rate, allowed * 0.97, minf(0.0015, release * 0.25), release, b.loop)
		b.gain_db = _gain_for(raw, b)
		b.limited_db = 20.0 * log(PEAK / maxf(1e-9, Synth.peak(raw))) / log(10.0)
	b.samples = raw
	b.ms = Time.get_ticks_msec() - t0
	return b


## The call gain (dB) that puts these samples at the sheet level after the bus.
static func _gain_for(raw: PackedFloat32Array, b: Baked) -> float:
	var rms_db := 20.0 * log(maxf(1e-9, Synth.loudest_rms(raw, b.rate, 0.5))) / log(10.0)
	return b.heard + SoundMix.REF_DBFS - rms_db - SoundMix.bus_db(b.bus)


# ------------------------------------------------------------------ disk

const CACHE_MAGIC := "USND"
const CACHE_FORMAT := 1
## Version folders kept; older ones (other branches, older recipes) are removed.
const CACHE_KEEP := 3


## A fingerprint of every recipe, the sheet, the game's version and the
## engine's: any edit to src/audio or the mix numbers gives a new cache folder,
## so a stale sound is never played. "" when the recipes cannot be read (then
## there is no disk cache at all, rather than one that could be stale).
static func recipe_version() -> String:
	return version_from(recipe_digests())


static func version_from(digests: PackedStringArray) -> String:
	if digests.is_empty():
		return ""
	var parts: PackedStringArray = [str(CACHE_FORMAT), str(SHEET), str(CATEGORIES), str(SoundMix.REF_DBFS), str(SoundMix.BUSES), str(CEILING_DBFS),
		str(ProjectSettings.get_setting("application/config/version", "")), str(Engine.get_version_info().get("hash", "")), str(Engine.get_version_info().get("string", ""))]
	parts.append_array(digests)
	return "\n".join(parts).md5_text().substr(0, 16)


## One md5 per recipe script, whatever form the build keeps it in: the .gd
## source in the editor and in text exports; in a tokenised export the
## .gd.remap names the compiled file, and that file is hashed instead.
static func recipe_digests(folder: String = "res://src/audio") -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		var path := folder.path_join(f)
		if f.ends_with(".gd") or f.ends_with(".gdc"):
			out.append(FileAccess.get_md5(path))
		elif f.ends_with(".gd.remap"):
			var target := remap_target(FileAccess.get_file_as_string(path))
			if target != "" and FileAccess.file_exists(target):
				out.append(FileAccess.get_md5(target))
	return out


## The path a Godot .remap file points at, or "".
static func remap_target(text: String) -> String:
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("path") and l.contains("="):
			return l.substr(l.find("=") + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""


## Turn the disk cache on under `root` (the running game does, once).
func use_disk_cache(root: String) -> void:
	var version := recipe_version()
	if version == "":
		cache_dir = ""
		_cache_version_dir = ""
		return
	cache_dir = root
	_on_disk.clear()
	_cache_version_dir = root.path_join(version)
	DirAccess.make_dir_recursive_absolute(_cache_version_dir)
	_prune_cache(root)


func _cache_path(key: StringName) -> String:
	if _cache_version_dir == "":
		return ""
	return _cache_version_dir.path_join(String(key).replace(":", "_") + ".usnd")


func _prune_cache(root: String) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	var folders: Array = []
	for d in dir.get_directories():
		var marker := root.path_join(d)
		folders.append([FileAccess.get_modified_time(marker) if FileAccess.file_exists(marker) else _folder_time(marker), d])
	folders.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	for i in range(CACHE_KEEP, folders.size()):
		var gone := root.path_join(String(folders[i][1]))
		if gone == _cache_version_dir:
			continue
		var sub := DirAccess.open(gone)
		if sub != null:
			for f in sub.get_files():
				sub.remove(f)
		DirAccess.remove_absolute(gone)


static func _folder_time(path: String) -> int:
	var newest := 0
	var dir := DirAccess.open(path)
	if dir != null:
		for f in dir.get_files():
			newest = maxi(newest, FileAccess.get_modified_time(path.path_join(f)))
	return newest


## Writes a baked sound (its PCM, rate, loop and gain) atomically: to a
## temporary name, then renamed, so two games starting at once never read half
## a file.
static func save_cached(b: Baked, path: String) -> void:
	var tmp := "%s.%d.tmp" % [path, OS.get_thread_caller_id()]
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(CACHE_MAGIC.to_ascii_buffer())
	f.store_32(CACHE_FORMAT)
	f.store_32(b.rate)
	f.store_8(1 if b.loop else 0)
	f.store_float(b.gain_db)
	f.store_32(b.pcm.size())
	f.store_buffer(b.pcm)
	f.close()
	DirAccess.rename_absolute(tmp, path)


## The baked sound for `key` from its cache file, or null when missing or not
## what this build would make.
static func load_cached(key: StringName, path: String) -> Baked:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 17:
		return null
	if f.get_buffer(4).get_string_from_ascii() != CACHE_MAGIC or f.get_32() != CACHE_FORMAT:
		return null
	var b := Baked.new()
	b.key = key
	b.name = base_name(key)
	b.variant = variant_of(key)
	var row: Array = SHEET.get(b.name, [&"event", 0.0, 1])
	b.category = row[0]
	b.heard = row[1]
	var cat: Dictionary = CATEGORIES[b.category]
	b.bus = cat["bus"]
	b.rate = f.get_32()
	b.loop = f.get_8() == 1
	b.gain_db = f.get_float()
	var size := f.get_32()
	b.pcm = f.get_buffer(size)
	if b.pcm.size() != size or b.rate != int(cat["rate"]) or b.loop != bool(cat["loop"]):
		return null
	b.from_disk = true
	return b


# ----------------------------------------------------------------- baking

## Queue a key for baking (no-op if baked or queued). urgent jumps the queue.
func request(key: StringName, urgent: bool = false) -> void:
	if not enabled or _done.has(key) or _jobs.has(key) or not has_sound(key):
		return
	if not threaded and not bakes_here(key):
		return
	var at := _queue.find(key)
	if at >= 0:
		if urgent and at > 0:
			_queue.remove_at(at)
			_queue.push_front(key)
		return
	if urgent:
		_queue.push_front(key)
	else:
		_queue.append(key)


## The baked sound if ready, else null (and it is requested).
func get_baked(key: StringName, urgent: bool = false) -> Baked:
	var b: Baked = _done.get(key)
	if b == null:
		request(key, urgent)
	return b


## Whether this bank may bake `key` at all: with threads, anything; without,
## a short one-shot, or anything its disk cache already holds (a file read).
func bakes_here(key: StringName) -> bool:
	if threaded or category_of(base_name(key)) in MAIN_THREAD_CATEGORIES:
		return true
	if not _on_disk.has(key):
		var path := _cache_path(key)
		_on_disk[key] = path != "" and FileAccess.file_exists(path)
	return _on_disk[key]


func is_ready(key: StringName) -> bool:
	return _done.has(key)


func pending() -> int:
	return _jobs.size() + _queue.size()


## Bake synchronously (tests, tools, and the no-thread fallback).
func bake_now(key: StringName) -> Baked:
	if _done.has(key):
		return _done[key]
	var job := Job.new()
	job.key = key
	job.cache_path = _cache_path(key)
	job.run()
	_queue.erase(key)
	_finish(job)
	return _done[key]


## Reap finished jobs and start new ones. Call once per frame; extra calls in
## the same frame do nothing.
func pump() -> void:
	var f := Engine.get_process_frames()
	if f == _pumped_frame:
		return
	_pumped_frame = f
	if not enabled:
		return
	for key: StringName in _jobs.keys():
		var job: Job = _jobs[key]
		if WorkerThreadPool.is_task_completed(job.task):
			WorkerThreadPool.wait_for_task_completion(job.task)
			_jobs.erase(key)
			_finish(job)
	if not threaded:
		# One thing a frame, and only what request() let in: a short one-shot or
		# a cache file.
		if not _queue.is_empty():
			bake_now(_queue[0])
		return
	while _jobs.size() < MAX_TASKS and not _queue.is_empty():
		var job := Job.new()
		job.key = _queue.pop_front()
		job.cache_path = _cache_path(job.key)
		job.task = WorkerThreadPool.add_task(job.run, false, "bake %s" % job.key)
		_jobs[job.key] = job


## Block until everything queued is baked (tools and tests).
func flush() -> void:
	while pending() > 0:
		for key: StringName in _jobs.keys():
			var job: Job = _jobs[key]
			WorkerThreadPool.wait_for_task_completion(job.task)
			_jobs.erase(key)
			_finish(job)
		_pumped_frame = -1
		pump()


## Take a sound rendered elsewhere (tests hand over what they already made).
func adopt(b: Baked) -> void:
	var job := Job.new()
	job.key = b.key
	job.result = b
	b.pcm = Synth.to_pcm16(b.samples)
	_queue.erase(b.key)
	_finish(job)


## Forget what is queued; what is already baking finishes and is kept.
func drop_queue() -> void:
	_queue.clear()


## Drop everything queued and wait out what is already running (quitting).
func cancel() -> void:
	_queue.clear()
	for key: StringName in _jobs.keys():
		var job: Job = _jobs[key]
		WorkerThreadPool.wait_for_task_completion(job.task)
		_finish(job)
	_jobs.clear()


func _finish(job: Job) -> void:
	var b := job.result
	b.stream = Synth.wav_from_pcm(b.pcm, b.rate, b.loop)
	if not keep_samples:
		b.samples = PackedFloat32Array()
	b.pcm = PackedByteArray()
	_done[job.key] = b
