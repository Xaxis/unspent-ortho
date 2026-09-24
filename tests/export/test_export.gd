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
	# LANTERN took the whole-number nearest upscale out: it was the pixel-art
	# contract and the image is fractional now (docs/LOOK.md). What is still worth
	# pinning is the pair that keeps the tool loop alive and the web build honest —
	# the frame is rendered into its own texture whatever size the window is
	# ("viewport"), at the 1920x1080 base, and the browser gets Compatibility while
	# the desktop gets Forward+.
	eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "fractional", "the image is no longer a whole-number upscale")
	eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport", "and it renders into its own texture, so an off-screen 1x1 window still shoots a full frame")
	eq(Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))), UiBase.SIZE, "the base is UiBase.SIZE")
	eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "forward_plus", "the desktop target is Forward+")
	eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.web"), "gl_compatibility", "and the web degrades to Compatibility")
	eq(ProjectSettings.get_setting("audio/general/default_playback_type.web"), 0, "the web mixes sound like everywhere else")


func test_the_shell_passes_the_query_as_boot_arguments() -> void:
	var html := FileAccess.get_file_as_string("res://src/boot/shell.html")
	for token: String in ["$GODOT_URL", "$GODOT_CONFIG", "$GODOT_THREADS_ENABLED", "URLSearchParams", "GODOT_CONFIG.args"]:
		check(html.contains(token), "the shell has %s" % token)


func test_the_shell_forwards_only_what_a_player_may_set() -> void:
	var html := FileAccess.get_file_as_string("res://src/boot/shell.html")
	var m := RegEx.create_from_string("const ALLOWED = \\{(.*)\\};").search(html)
	check(m != null, "the shell lists what the address may set")
	if m == null:
		return
	var keys := PackedStringArray()
	for k in RegEx.create_from_string("'(--[a-z-]+)'").search_all(m.get_string(1)):
		keys.append(k.get_string(1))
	keys.sort()
	eq(keys, PackedStringArray(["--probe", "--scene", "--seed"]), "only a seed, a scene and the probe")
	check(m.get_string(1).contains("(title|game)"), "and the scene only a title or a game")


## The shell draws the engine's loading page itself while the engine downloads, so
## both must use the same numbers, colours and glyphs.
func test_the_shell_draws_the_page_the_engine_draws() -> void:
	var html := FileAccess.get_file_as_string("res://src/boot/shell.html")
	check(html.contains("const SHELL_SHARE = %s;" % str(BootPage.SHELL_SHARE)), "the shell fills the line to BootPage.SHELL_SHARE")
	check(html.contains("LINE_Y = %d, LINE_X0 = %d, LINE_X1 = %d" % [BootPage.LINE_Y, BootPage.LINE_X0, BootPage.LINE_X1]), "the line sits where the page draws it")
	for pair: Array in [["glass", BootPage.GLASS], ["rail", BootPage.RAIL], ["tick", BootPage.TICK], ["lit", BootPage.LIT], ["litSoft", BootPage.LIT_SOFT], ["head", BootPage.HEAD], ["words", BootPage.WORDS]]:
		check(html.contains("%s: '#%s'" % [pair[0], (pair[1] as Color).to_html(false)]), "the shell's %s ink is the page's" % pair[0])
	var m := RegEx.create_from_string("const GLYPHS = (\\{.*?\\});").search(html)
	check(m != null, "the shell carries the pixel font's glyphs")
	if m == null:
		return
	var glyphs: Dictionary = JSON.parse_string(m.get_string(1))
	for word: String in ["fetching", "waking", "stopped", "slate", "opening"]:
		for ch in word:
			check(glyphs.has(ch), "the shell can write '%s'" % ch)
	for ch: String in glyphs:
		eq(glyphs[ch], UiFont.GLYPHS[ch], "glyph '%s' is the game's" % ch)
	check(html.contains("background: #000"), "outside the game's rectangle the page is black, like the engine's bars")
	# On the web the shell is the first screen of the game for as long as the wasm
	# takes, so it draws the whole device and not only the line on it.
	check(html.contains("const DEV = { x: %d, y: %d, w: %d, h: %d };" % [BootPage.DEVICE.position.x, BootPage.DEVICE.position.y, BootPage.DEVICE.size.x, BootPage.DEVICE.size.y]), "the shell's device is the page's")
	check(html.contains("const SCR = { x: %d, y: %d, w: %d, h: %d };" % [BootPage.SCREEN.position.x, BootPage.SCREEN.position.y, BootPage.SCREEN.size.x, BootPage.SCREEN.size.y]), "and so is its glass")
	check(html.contains("const STATUS_H = %d, KEYS_H = %d;" % [BootPage.STATUS_H, BootPage.KEYS_H]), "and the bar and strip are the same height")
	for ramp: Array in [["CHROME", BootPage.CHROME], ["CASING", BootPage.CASING], ["SENSOR", BootPage.SENSOR], ["PLATE", Palette.PLATE]]:
		var want := PackedStringArray()
		for c: Color in (ramp[1] as Array):
			want.append("'#%s'" % c.to_html(false))
		check(html.contains("const %s = [%s];" % [ramp[0], ", ".join(want)]), "the shell's %s ramp is the palette's" % ramp[0])
	check(html.contains("SCREEN_GLASS = '#%s', SCREEN_ROW = '#%s'" % [BootPage.SCREEN_GLASS.to_html(false), BootPage.SCREEN_ROW.to_html(false)]), "and its lit glass is the page's")


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
	# A cap on the GAME's size, not a check on what ships: dev files are refused one
	# by one above. 4 MB was crossed by real code (far models, the shoulder view,
	# the stutter fixes: 4,097 KB on 2026-09-24), so the cap has headroom again.
	lt(float(size), 5.0 * 1024 * 1024, "the pack stays small (%d KB)" % (size / 1024))
	lt(float(ms), 60000.0, "and exports in well under a minute (%d ms)" % ms)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
