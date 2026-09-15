extends Node
## Checks a running build can only make about itself, printed as lines tools/web.sh
## reads (`web ok ...`, `web FAIL ...`, `web skip ...`, then `web probe done`).
## Added by main.gd after the first frame when booted with --probe.
##
##   systems  the game loaded its systems (an export lists scripts differently)
##   focus    the canvas holds keyboard focus (web)
##   audio    after the first key (a browser starts audio only then): a test tone
##            reaches the master bus meter (the engine's path), then in a game the
##            game's own sound does. The tone plays once per page: a game started
##            from a title that proved the path plays none, so what tools/web.sh
##            hears at the speakers in the game is the game.
##   save     user:// survives a reload (IndexedDB on the web): the first boot writes
##            SaveGame.collect() of the running game, the next reports it kept
##   slot     a real save file (SaveFile: compressed, framed, md5-checked) of the
##            running game in the tools' own slot folder, read back whole on the
##            next boot: what Continue reads in a browser

const FILE := "user://web_probe.json"
## Under SaveSlots.TOOL_ROOT, never a player's slot.
const SLOT_DIR := "web-probe"
const AUDIO_WAIT := 30.0
## At most this many seconds of test tones after the first gesture.
const TONE_SECONDS := 8.0
const TONE_MIN_SECONDS := 2.5
const SILENT_DB := -70.0
## Engine meta set once a tone has reached the meter in this page.
const PATH_PROVEN := &"web_probe_audio_path"

## The scene checked (main.gd sets it): the game or the title.
var scene: Node
var _pressed_at := -1.0
var _t := 0.0
var _loudest := -200.0
var _audio_done := false
var _tone: AudioStreamPlayer
var _tone_at := 0.0
var _game_from := 0.0
var _tone_done := false
var _proven_before := false


func _ready() -> void:
	name = "web_probe"
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("web probe start (web %s, threads %s, scene %s, args %s)" % [OS.has_feature("web"), BootPage.has_threads(), scene.name if scene != null else "none", " ".join(OS.get_cmdline_user_args())])
	_check_systems()
	_check_focus()
	_check_save()
	_check_slot()
	if not OS.has_feature("web"):
		# Only a browser holds audio back until the first key.
		_pressed_at = 0.0
	_proven_before = Engine.has_meta(PATH_PROVEN)
	if _proven_before:
		print("web skip audio path (a tone reached the meter earlier in this page; no tone now)")


func _check_systems() -> void:
	if not (scene is Game):
		return
	var systems: Array = (scene as Game).systems
	var expected := BootPage.system_scripts().size()
	if systems.size() == expected and expected > 0:
		print("web ok systems %d loaded" % systems.size())
	else:
		print("web FAIL systems: %d loaded of %d scripts" % [systems.size(), expected])


func _check_focus() -> void:
	if not OS.has_feature("web"):
		print("web skip focus (not a web build)")
		return
	var id: Variant = JavaScriptBridge.eval("document.activeElement ? document.activeElement.id : ''", true)
	if str(id) == "canvas":
		print("web ok focus on the canvas")
	else:
		print("web FAIL focus is on '%s', not the canvas" % str(id))


func _check_save() -> void:
	var before: Variant = null
	if FileAccess.file_exists(FILE):
		before = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	var doc := {"written_unix": int(Time.get_unix_time_from_system()), "token": str(Time.get_ticks_usec()), "scene": str(scene.name) if scene != null else ""}
	var save_script := _global_script("SaveGame")
	if save_script != null and scene is Game:
		doc["state"] = save_script.call("collect")
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f == null:
		print("web FAIL save: cannot write %s (%s)" % [FILE, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(doc))
	f.close()
	var back: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not (back is Dictionary) or str((back as Dictionary).get("token")) != doc["token"]:
		print("web FAIL save: %s did not read back" % FILE)
		return
	var keys := (doc.get("state", {}) as Dictionary).keys()
	print("web ok save written to %s (%s, SaveGame %s, %d keys)" % [ProjectSettings.globalize_path(FILE), "IndexedDB" if OS.has_feature("web") else "disk", "found" if save_script != null else "absent", keys.size()])
	# Only a file written before this process started proves the reload kept it.
	var started := int(Time.get_unix_time_from_system() - Time.get_ticks_msec() / 1000.0)
	if before is Dictionary and float((before as Dictionary).get("written_unix", 0.0)) < started:
		print("web ok save kept from the boot before (%s)" % Time.get_datetime_string_from_unix_time(int((before as Dictionary).get("written_unix", 0))))


func _check_slot() -> void:
	var file := _global_script("SaveFile")
	var slots := _global_script("SaveSlots")
	var registry := _global_script("SaveGame")
	if file == null or slots == null or registry == null:
		print("web skip slot (no save system)")
		return
	var path := String((slots as GDScript).get_script_constant_map().get("TOOL_ROOT", "user://tool-saves")).path_join(SLOT_DIR).path_join("slot_1.save")
	var started := Time.get_unix_time_from_system() - Time.get_ticks_msec() / 1000.0
	if FileAccess.file_exists(path):
		var r: Dictionary = file.call("read", path)
		var at := float((r.get("header", {}) as Dictionary).get("saved_at", 0.0))
		if bool(r.get("ok", false)) and at < started:
			print("web ok slot kept from the boot before: %d keys read back whole (%s)" % [(r.get("data", {}) as Dictionary).size(), Time.get_datetime_string_from_unix_time(int(at))])
		elif not bool(r.get("ok", false)):
			print("web FAIL slot: the save file from before cannot be read (%s)" % str(r.get("why", "")))
	if not (scene is Game):
		print("web skip slot write (the title has no game to save)")
		return
	var header := {"saved_at": Time.get_unix_time_from_system(), "clock": "", "place": "web probe", "seed": (scene as Game).options.seed_value}
	var err: int = file.call("write", path, header, registry.call("collect"))
	if err != OK:
		print("web FAIL slot: %s not written (%s)" % [path, error_string(err)])
		return
	var back: Dictionary = file.call("read", path)
	if bool(back.get("ok", false)):
		print("web ok slot written to %s and read back" % ProjectSettings.globalize_path(path))
	else:
		print("web FAIL slot: %s did not read back (%s)" % [path, str(back.get("why", ""))])


func _global_script(cls: String) -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry.get("class") == cls:
			return load(str(entry.get("path"))) as Script
	return null


func _process(delta: float) -> void:
	_t += delta
	if _audio_done:
		return
	if _pressed_at < 0.0:
		# The browser's own record of a gesture: audio may start only after it.
		if bool(JavaScriptBridge.eval("navigator.userActivation ? navigator.userActivation.hasBeenActive : true", true)):
			_pressed_at = _t
		return
	var db := maxf(AudioServer.get_bus_peak_volume_left_db(0, 0), AudioServer.get_bus_peak_volume_right_db(0, 0))
	var since := _t - _pressed_at
	if not _tone_done:
		# Tones until the meter sees one, and for TONE_MIN_SECONDS at least, so the page's speakers can be heard too.
		var proven := Engine.has_meta(PATH_PROVEN)
		if not _proven_before and since < TONE_SECONDS and (not proven or since < TONE_MIN_SECONDS):
			# The engine's own path: a short tone each second on Master must reach the
			# meter (and, for tools/web.sh listening at the page, the speakers).
			if _tone == null or _t - _tone_at >= 1.0:
				_play_tone()
				_tone_at = _t
			if not proven and db > SILENT_DB:
				Engine.set_meta(PATH_PROVEN, true)
				print("web ok audio path: a test tone reached %.1f dB on the master bus %.1f s after the first gesture" % [db, since])
			return
		_tone_done = true
		# A second after the last tone, the bus holds only the scene's own sound.
		_game_from = _t + (1.0 if _tone != null else 0.0)
		if _tone != null:
			_tone.queue_free()
			_tone = null
		if not Engine.has_meta(PATH_PROVEN):
			print("web FAIL audio path: a test tone on the master bus never reached the meter (%s)" % _players())
			_audio_done = true
		elif not (scene is Game):
			print("web skip audio game (the title makes no sound)")
			_audio_done = true
		_finish_if_done()
		return
	if _t < _game_from:
		return
	# The game's own sound: beds, steps, the machines.
	_loudest = maxf(_loudest, db)
	var waited := _t - _game_from
	if _loudest > SILENT_DB:
		print("web ok audio game: the master bus reached %.1f dB %.1f s after the tone (%s)" % [_loudest, waited, _players()])
		_audio_done = true
		_finish_if_done()
	elif waited > AUDIO_WAIT:
		print("web FAIL audio game: the master bus stayed silent for %d s though the path works (%s)" % [int(AUDIO_WAIT), _players()])
		_audio_done = true
		_finish_if_done()


func _play_tone() -> void:
	var rate := 44100
	var n := int(rate * 0.3)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var env := minf(1.0, minf(i, n - i) / (rate * 0.01))
		data.encode_s16(i * 2, int(sin(TAU * 440.0 * i / rate) * 8000.0 * env))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	if _tone == null:
		_tone = AudioStreamPlayer.new()
		_tone.bus = &"Master"
		add_child(_tone)
	_tone.stream = wav
	_tone.play()


## "N of M players playing, mix R Hz" over the checked scene, to tell a silent
## mix from nothing asked to play.
func _players() -> String:
	var total := 0
	var playing := 0
	var stack: Array[Node] = []
	if scene != null:
		stack.append(scene)
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is AudioStreamPlayer or n is AudioStreamPlayer2D or n is AudioStreamPlayer3D:
			total += 1
			if n.get("playing") == true:
				playing += 1
	return "%d of %d players playing, mix %d Hz, %d buses" % [playing, total, int(AudioServer.get_mix_rate()), AudioServer.bus_count]


func _finish_if_done() -> void:
	if _audio_done:
		print("web probe done")
		queue_free()
