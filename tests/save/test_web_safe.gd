extends TestCase
## Saving must work in a browser: user:// there is IndexedDB behind an in-memory
## filesystem, synced when a written file is closed. That rules out threads (a
## no-threads web build has none), OS processes and shells, blocking sleeps,
## absolute paths and writing into res://. The save code is read as text and
## held to that, and every place a slot can live is under user://.

const FILES: Array[String] = [
	"res://src/core/save/save_game.gd",
	"res://src/core/save/save_codec.gd",
	"res://src/core/save/save_file.gd",
	"res://src/core/save/save_slots.gd",
	"res://src/core/save/save_core.gd",
	# On the save path since the stamp: SaveFile.write and every read spell it out.
	"res://src/core/save/world_stamp.gd",
	"res://src/core/save/save_staging.gd",
	"res://src/core/save/autosave_rules.gd",
	"res://src/systems/05_save.gd",
	"res://src/ui/ui_saves_screen.gd",
]
const FORBIDDEN: Array[String] = ["Thread", "WorkerThreadPool", "Mutex", "Semaphore", "OS.delay", "OS.execute",
	"OS.create_process", "OS.shell_open", "globalize_path", "\"res://", "OS.get_user_data_dir", "await get_tree().create_timer"]


func test_the_save_code_uses_nothing_a_browser_cannot_do() -> void:
	for path in FILES:
		var f := FileAccess.open(path, FileAccess.READ)
		check(f != null, "%s is there" % path)
		if f == null:
			continue
		var n := 0
		while not f.eof_reached():
			var line := f.get_line()
			n += 1
			var code := line.split("#")[0]
			for word in FORBIDDEN:
				check(not code.contains(word), "%s:%d uses %s" % [path.get_file(), n, word])
	# Every file a save writes closes before it is renamed: the close is what syncs it on the web.
	var src := FileAccess.get_file_as_string("res://src/core/save/save_file.gd")
	check(src.find("f.close()") < src.find("DirAccess.rename_absolute"), "closed before the rename")


func test_every_slot_lives_under_user() -> void:
	for root: String in [SaveSlots.PLAYER_ROOT, SaveSlots.TOOL_ROOT, SaveSlots.TEST_ROOT]:
		check(root.begins_with("user://"), "%s is under user://" % root)
	var o := BootOptions.parse(PackedStringArray(["--saves=elsewhere", "--shot=x.png"]))
	var was := SaveSlots.root
	SaveSlots.use_options(o)
	eq(SaveSlots.root, "user://elsewhere", "--saves picks a folder under user://")
	SaveSlots.use_options(BootOptions.parse(PackedStringArray(["--shot=x.png"])))
	eq(SaveSlots.root, SaveSlots.TOOL_ROOT, "a shot keeps clear of the player's saves")
	SaveSlots.use_options(BootOptions.parse(PackedStringArray(["--tour=tours/saves.tour"])))
	eq(SaveSlots.root, SaveSlots.TOOL_ROOT.path_join("saves"), "a tour keeps its own, clear of other tours run beside it")
	SaveSlots.root = was
	check(SaveSlots.root.begins_with(SaveSlots.TEST_ROOT), "tests run clear of the player's saves too: %s" % SaveSlots.root)
