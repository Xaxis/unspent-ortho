extends TestCase
## The export presets: a threaded web build, a no-threads fallback and a macOS
## app, all through the loading page's shell, none carrying the tools; and an
## export that runs headless and packs only the game.

const PRESETS := "res://export_presets.cfg"
## What never ships: the loop's own files.
const DEV_DIRS: Array[String] = ["shots/", "tours/", "tools/", "tests/", "docs/", "build/"]


func _presets() -> Dictionary:
	var cfg := ConfigFile.new()
	var err := cfg.load(PRESETS)
	eq(err, OK, "export_presets.cfg loads")
	var out := {}
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			out[str(cfg.get_value(section, "name"))] = section
	out["cfg"] = cfg
	return out


func test_three_presets_with_their_variants() -> void:
	var p := _presets()
	var cfg: ConfigFile = p.cfg
	for name: String in ["Web", "Web (no threads)", "macOS"]:
		check(p.has(name), "a preset named %s" % name)
	if not (p.has("Web") and p.has("Web (no threads)") and p.has("macOS")):
		return
	eq(cfg.get_value(p["Web"] + ".options", "variant/thread_support"), true, "Web is threaded")
	eq(cfg.get_value(p["Web (no threads)"] + ".options", "variant/thread_support"), false, "the fallback is not")
	for name: String in ["Web", "Web (no threads)"]:
		var opts: String = p[name] + ".options"
		eq(cfg.get_value(opts, "html/custom_html_shell"), "res://src/boot/shell.html", "%s boots through the loading page's shell" % name)
		eq(cfg.get_value(opts, "html/canvas_resize_policy"), 2, "%s: the canvas follows the window (the game scales by whole numbers inside it)" % name)
		eq(cfg.get_value(opts, "html/focus_canvas_on_start"), true, "%s: keys work without a click" % name)
	eq(cfg.get_value(p["macOS"] + ".options", "binary_format/architecture"), "universal")
	eq(cfg.get_value(p["macOS"] + ".options", "codesign/codesign"), 1, "ad-hoc signed, so it runs on this machine")
	for name: String in ["Web", "Web (no threads)", "macOS"]:
		var filters := str(cfg.get_value(p[name], "exclude_filter"))
		for d in DEV_DIRS:
			check(filters.contains(d + "*"), "%s excludes %s" % [name, d])
	eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer", "whole-number scaling, in the browser too")
	eq(ProjectSettings.get_setting("audio/general/default_playback_type.web"), 0, "the web mixes sound like everywhere else")


func test_the_shell_passes_the_query_as_boot_arguments() -> void:
	var html := FileAccess.get_file_as_string("res://src/boot/shell.html")
	for token: String in ["$GODOT_URL", "$GODOT_CONFIG", "$GODOT_THREADS_ENABLED", "URLSearchParams", "GODOT_CONFIG.args", "#08070f"]:
		check(html.contains(token), "the shell has %s" % token)


func test_a_headless_export_packs_the_game_and_nothing_else() -> void:
	var dir := OS.get_cache_dir().path_join("unspent-export-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	var pck := dir.path_join("index.pck")
	var output := []
	var t0 := Time.get_ticks_msec()
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--export-pack", "Web", pck], output, true)
	var ms := Time.get_ticks_msec() - t0
	eq(code, 0, "the export exits cleanly (%s)" % "\n".join(PackedStringArray(output)).right(400))
	check(FileAccess.file_exists(pck), "a pack was written")
	var files := PckList.paths(pck)
	gt(files.size(), 100.0, "the pack lists the game's files")
	check(files.has("src/main.gdc") or files.has("src/main.gd"), "the entry script is in the pack")
	check(Array(files).any(func(f: String) -> bool: return f.begins_with("src/boot/")), "the loading page is in the pack")
	for f: String in files:
		for d in DEV_DIRS:
			check(not f.begins_with(d), "%s does not ship" % f)
	var size := FileAccess.open(pck, FileAccess.READ).get_length() if FileAccess.file_exists(pck) else 0
	lt(float(size), 4.0 * 1024 * 1024, "the pack stays small (%d KB)" % (size / 1024))
	lt(float(ms), 60000.0, "and exports in well under a minute (%d ms)" % ms)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
