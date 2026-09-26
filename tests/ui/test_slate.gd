extends TestCase
## The slate as a device (docs/LOOK.md): one phosphor and one warning on dark
## glass with the stolen module's violet, no paper left anywhere, a bezel that
## is pixel-exact and patched, and flaws that never sit under what it says.

## The notebook's linen paper and ink, which the slate replaced.
const PAPER_COLOURS := [Color("#e8dcc0"), Color("#c0b394"), Color("#968a76"), Color("#6f6559"), Color("#efe8d6"), Color("#b9b8a8"), Color("#33231f"), Color("#4f3627"), Color("#9a4f28"), Color("#c47438")]


func test_theme_has_no_paper_colours_left() -> void:
	var names: Array = (load("res://src/ui/ui_theme.gd") as GDScript).get_script_constant_map().keys()
	for n: String in names:
		for word: String in ["PAPER", "LINEN", "INK", "COVER", "SLIP", "RULE", "ACCENT", "FADED"]:
			check(not n.contains(word), "no notebook colour named %s" % n)
	for col: Color in UiTheme.all_colours():
		for paper: Color in PAPER_COLOURS:
			var d := Vector3(col.r - paper.r, col.g - paper.g, col.b - paper.b).length()
			check(d > 0.08, "%s is too near the old paper %s" % [col.to_html(false), paper.to_html(false)])
	check(not ResourceLoader.exists("res://src/ui/ui_notebook.gd"), "the notebook is gone")


func test_one_phosphor_one_warning_and_the_module_violet() -> void:
	# The phosphor is a cold green: green leads, and it is never warm.
	for c: Color in UiTheme.PHOSPHOR:
		check(c.g > c.r and c.g >= c.b, "phosphor is green: %s" % c.to_html(false))
	for i in range(1, 5):
		check(UiTheme.PHOSPHOR[i].get_luminance() > UiTheme.PHOSPHOR[i - 1].get_luminance(), "the phosphor ramps up")
		check(UiTheme.MACHINE[i].get_luminance() > UiTheme.MACHINE[i - 1].get_luminance(), "the violet ramps up")
	for c: Color in UiTheme.MACHINE:
		check(c.b > c.g and c.r > c.g, "the module's tone is violet: %s" % c.to_html(false))
	check(UiTheme.WARN.r > UiTheme.WARN.g + 0.3 and UiTheme.WARN.r > UiTheme.WARN.b + 0.3, "the warning is hot and not green or violet")
	# Glass is near black, never black, and text reads on it.
	for glass: Color in [UiTheme.GLASS, UiTheme.GLASS_SPARE, UiTheme.GLASS_OFF]:
		check(glass.get_luminance() < 0.09 and glass != Color.BLACK and glass.r + glass.g + glass.b > 0.0, "glass is dark, not black")
	gt(_contrast(UiTheme.TEXT, UiTheme.GLASS), 6.5, "text on glass")
	gt(_contrast(UiTheme.TEXT_DIM, UiTheme.GLASS_SPARE), 4.5, "dim text on the spare panel")
	gt(_contrast(UiTheme.WARN, UiTheme.GLASS), 4.5, "the warning on glass")
	gt(_contrast(UiTheme.MACHINE[3], UiTheme.GLASS), 4.5, "machine reads on glass")
	gt(_contrast(UiTheme.FAINT, UiTheme.GLASS), 1.8, "even a rule is seen")


func test_the_device_is_pixel_exact_and_patched() -> void:
	var size := UiSlate.DEVICE.size
	var img := UiSlate.device_image(size)
	eq(img.get_size(), size + Vector2i(UiSlate.PAD, UiSlate.PAD) * 2, "the texture is the device and its pad")
	var o := Vector2i(UiSlate.PAD, UiSlate.PAD)
	var g := Rect2i(o + Vector2i(UiSlate.BEZEL_L, UiSlate.BEZEL_T), UiSlate.GLASS_RECT.size)
	var bezel := 0
	var violet := 0
	var grey := 0
	var half := 0
	# The duct tape over the cracked corner laps onto the glass there.
	var taped := UiSlate.crack_zone(UiSlate.DEVICE)
	taped.position += o - UiSlate.DEVICE.position
	# Every pixel of the bezel, every third of the glass (it is one flat fill).
	for y in size.y:
		for x in size.x:
			var p := o + Vector2i(x, y)
			if g.grow(-2).has_point(p) and (x + y) % 3 != 0:
				continue
			var c := img.get_pixelv(p)
			if g.has_point(p):
				if taped.has_point(p):
					continue
				check(c.a == 1.0 and c.get_luminance() < 0.1, "glass is opaque and dark at %s" % p)
				continue
			if UiSlate._chamfered(x, y, size.x, size.y, 4 * UiSlate.UNIT):
				continue
			bezel += 1
			if c.a > 0.0 and c.a < 1.0:
				half += 1
			if c.b > c.g + 0.05 and c.r > c.g:
				violet += 1
			elif absf(c.r - c.g) < 0.04 and absf(c.g - c.b) < 0.06:
				grey += 1
	eq(half, 0, "no half-transparent pixel on the bezel")
	gt(violet, bezel * 0.45, "most of it is the stolen module's violet")
	gt(grey, bezel * 0.12, "a real share is the grey casing it was patched with")
	eq(UiSlate.glass_of(UiSlate.DEVICE).size, UiSlate.GLASS_RECT.size)


func test_the_flaws_never_sit_under_words() -> void:
	var size := UiSlate.DEVICE.size
	var img := UiSlate.marks_image(size)
	var o := UiSlate.DEVICE.position - Vector2i(UiSlate.PAD, UiSlate.PAD)
	var zone := UiSlate.crack_zone(UiSlate.DEVICE)
	var dead := UiSlate.dead_column_x(UiSlate.DEVICE)
	var marked := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a <= 0.0:
				continue
			marked += 1
			var s := o + Vector2i(x, y)
			check(zone.has_point(s) or s.x <= UiSlate.GLASS_RECT.position.x + UiSlate.MARGIN_L - 4, "a flaw at %s is outside the crack and the margin" % s)
	gt(marked, 100, "there are flaws to see")
	check(dead < UiSlate.GLASS_RECT.position.x + UiSlate.MARGIN_L - 4, "the dead column is in the margin")
	check(not UiSlate.LIST.grow_individual(-UiSlate.MARGIN_L, 0, 0, 0).intersects(zone), "the list is clear of the crack")
	check(UiSlate.SPARE.end.x - UiSlate.SPARE_INSET <= zone.position.x, "the spare panel's words are clear of the crack")


func test_power_dims_the_glass_not_the_bezel() -> void:
	var s := UiPauseScreen.new()
	tree.root.add_child(s)
	s.open()
	s.settle()
	await tree.process_frame
	check(_dim_washes(await _glass_drawn(s)).is_empty(), "full power: no wash")
	# Power runs low while the app stays open: only the brightness changes.
	UiDraw.tape.clear()
	UiDraw.taping = true
	s.brightness = UiRules.brightness(0.0)
	await tree.process_frame
	UiDraw.taping = false
	check(s.brightness >= UiSlate.DIM_FLOOR, "dim, never unreadable")
	var washes := _dim_washes(UiDraw.tape.filter(func(d: Dictionary) -> bool: return d.ci != s))
	eq(washes.size(), 1, "the glass redraws dimmed while the app is open")
	if washes.size() == 1:
		eq(Rect2i(washes[0].rect), UiSlate.glass_of(s.device_rect), "over the glass only, never the bezel")
		near((washes[0].col as Color).a, 1.0 - s.brightness, 0.01, "as dark as the power is low")
	UiDraw.tape.clear()
	s.free()


## What the glass layer over `s` draws on its next frame.
func _glass_drawn(s: UiScreen) -> Array:
	UiDraw.tape.clear()
	UiDraw.taping = true
	(s.get_node("glass") as CanvasItem).queue_redraw()
	await tree.process_frame
	UiDraw.taping = false
	var out := UiDraw.tape.filter(func(d: Dictionary) -> bool: return d.ci != s)
	UiDraw.tape.clear()
	return out


static func _dim_washes(drawn: Array) -> Array:
	return drawn.filter(func(d: Dictionary) -> bool:
		var c: Color = d.col
		return d.kind == &"rect" and c.a > 0.0 and c.a < 1.0 and Color(c, 1.0) == UiTheme.GLASS_OFF)


func test_the_slate_bakes_ahead_off_the_main_thread() -> void:
	UiSlate.warm()
	UiSlate.wait()
	var tex := UiSlate.device_texture(UiSlate.DEVICE.size)
	eq(Vector2i(tex.get_size()), UiSlate.DEVICE.size + Vector2i(UiSlate.PAD, UiSlate.PAD) * 2)
	check(UiSlate.device_texture(UiSlate.DEVICE.size) == tex, "baked once")
	# A size nobody warmed: asking for it never bakes on the main thread. It is
	# null at once, a plain frame is drawn, and the bake arrives from a worker.
	var odd := Vector2i(301, 187)
	check(UiSlate.device_texture(odd) == null, "not baked in the caller")
	# **A COST, SO THE CHEAPEST OF SEVERAL AND NOT ONE RUN TIMES `machine_slack`.**
	# Slack is for WAITING -- how long a thing may take to happen on a busy
	# machine -- and it clamps at 8, so as a cost bar it stood at 160 ms here and
	# could no longer fail for a real reason. Load only ever ADDS time, so the
	# minimum of several runs is the honest number and the value can stay where
	# it was. Each run asks for a size nobody has warmed, so every one of them
	# measures the same thing: the early-out. A bake is half a second, so 20 ms
	# is clear of any plausible noise and nowhere near a bake.
	var asking := INF
	for i in 5:
		var t0 := Time.get_ticks_usec()
		@warning_ignore("return_value_discarded")
		UiSlate.device_texture(Vector2i(303 + i * 2, 189 + i))
		asking = minf(asking, float(Time.get_ticks_usec() - t0) / 1000.0)
	lt(asking, 20.0, "and asking does not wait for it")
	var s := UiPauseScreen.new()
	s.device_rect = Rect2i(10, 10, odd.x, odd.y)
	tree.root.add_child(s)
	s.open()
	await tree.process_frame
	check(s.get("_plain"), "the app drew a plain frame meanwhile")
	UiSlate.wait()
	check(UiSlate.ready(odd), "the bake came in from the worker")
	s._process(0.0)
	await tree.process_frame
	check(not s.get("_plain"), "and the app redrew with it")
	s.free()


func test_the_title_and_the_game_start_their_bakes_in_setup() -> void:
	var src := (load("res://src/ui/ui_title.gd") as GDScript).source_code
	var setup := src.substr(src.find("func setup("), 900)
	check(setup.contains("UiSlate.warm(UiTitleMenu.DEVICE.size)"), "the title warms its slate as it sets up")
	var ui := (load("res://src/systems/90_ui.gd") as GDScript).source_code
	var ui_setup := ui.substr(ui.find("func setup("), 600)
	check(ui_setup.contains("UiSlate.warm()"), "the ui system warms the page slate as it sets up")


## Every word each app draws, in every state worth drawing, reads on the glass:
## 4.5:1 lit and 3:1 at the low-power floor. Rules, sockets and ghosts may be
## faint; words may not.
func test_every_word_on_the_glass_reads() -> void:
	SlateFeeds.clear()
	SlateFeeds.provide(&"loadout", func(_g: Game) -> Dictionary:
		return {"slots": [{"id": &"head", "label": "head", "item": &"kit_lens", "modules": [{"id": &"m", "name": "seal", "grants": "cold"}]}, {"id": &"body", "label": "body", "item": &"", "modules": []}],
			"resist": {&"cold": 0.5}, "abilities": [{"id": &"dash", "name": "dash", "ready": true, "note": "ready"}, {"id": &"veil", "name": "veil", "ready": false, "note": "charging"}]})
	SlateFeeds.provide(&"reads", func(g: Game) -> Dictionary:
		return {"interference": 0.4, "network": "coast grid", "scans": [{"id": &"a", "kind": &"runner", "name": "runner", "pos": g.player.pos + Vector2(4, 2), "disposition": &"hostile", "note": "it has your scent"}, {"id": &"b", "kind": &"watcher", "name": "watcher", "pos": g.player.pos + Vector2(-9, 5), "disposition": &"observant", "note": ""}]})
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(["--size=64", "--seed=4", "--give=knife:1,mussels:3,stone:2,wick:2,las_hand:1,kit_brace:1,scrap:1"]))
	var ui: Node = null
	for sys in g.systems:
		if sys.name == "90_ui":
			ui = sys
	g.world.add_prop(WorldProp.new(99996, PropKind.FIRE, g.player.pos + Vector2(1, 0), 0.0, 1.0))
	g.query.add_prop(g.world.prop_at(g.world.prop_count() - 1))
	var words := {}
	# [app, a row to choose or "", home's page]
	# The fed apps first, then the same apps with nothing wired in (what they say empty).
	for pick: Array in [[&"inventory", &"las_hand", ""], [&"inventory", &"mussels", ""], [&"crafting", &"", ""], [&"map", &"", ""], [&"pause", &"", ""], [&"pause", &"", "keys"], [&"loadout", &"body", ""], [&"reads", &"a", ""], [&"saves", &"slot_2", ""],
			[&"", &"", ""], [&"loadout", &"", ""], [&"reads", &"", ""], [&"saves", &"", ""]]:
		if pick[0] == &"":
			SlateFeeds.clear()
			continue
		if pick[0] in SlateFeeds.APPS:
			ui.call("open_screen", &"pause")
		check(ui.call("open_screen", pick[0]), "%s opens" % pick[0])
		var s: UiScreen = ui.call("top")
		s.settle()
		if pick[1] != &"":
			s.select(pick[1])
		if pick[2] != "":
			(s as UiPauseScreen).page = pick[2]
		s.power = 0.1
		for w: Dictionary in await _words_drawn(s):
			words["%s|%s" % [w.text, (w.col as Color).to_html()]] = [s.screen_name, w]
		if pick[0] == &"reads" and pick[1] == &"":
			check(words.has("NO NETWORK READ|%s" % UiTheme.MACHINE[2].to_html()), "the empty reads were drawn too")
		while ui.call("top") != null:
			(ui.call("top") as UiScreen).handle(&"back")
	g.free()
	SlateFeeds.clear()
	var title := UiTitleMenu.new()
	tree.root.add_child(title)
	title.open()
	title.settle()
	for page: String in ["list", "keys"]:
		title.page = page
		for w: Dictionary in await _words_drawn(title):
			words["%s|%s" % [w.text, (w.col as Color).to_html()]] = [&"title", w]
	title.free()
	gt(words.size(), 60, "the apps said enough to judge")
	var dim := 1.0 - UiSlate.DIM_FLOOR
	for key: String in words:
		var app: StringName = words[key][0]
		var col: Color = words[key][1].col
		var said: String = words[key][1].text
		# Dark words cut out of a lit tag are read against the tag, not the glass.
		if col.a < 1.0 or col.get_luminance() <= UiTheme.GLASS.get_luminance():
			continue
		for glass: Color in [UiTheme.GLASS, UiTheme.GLASS_SPARE]:
			var lit := _wcag(col, glass)
			var low := _wcag(col.lerp(UiTheme.GLASS_OFF, dim), glass.lerp(UiTheme.GLASS_OFF, dim))
			check(lit >= 4.5, "%s: '%s' in %s is %.2f:1 on the glass" % [app, said, col.to_html(false), lit])
			check(low >= 3.0, "%s: '%s' in %s is %.2f:1 at low power" % [app, said, col.to_html(false), low])
	for faint: Color in [UiTheme.FAINT, UiTheme.GHOST, UiTheme.MACHINE[0], UiTheme.MACHINE[1]]:
		check(_wcag(faint, UiTheme.GLASS) < 4.5, "%s is only for rules and glyphs" % faint.to_html(false))
	for word_tone: Color in [UiTheme.TEXT_DIM, UiTheme.MACHINE[2], UiTheme.WARN]:
		gt(_wcag(word_tone, UiTheme.GLASS), 4.5, "the dimmest word tone %s reads" % word_tone.to_html(false))


## The words `s` draws on its next frame.
func _words_drawn(s: UiScreen) -> Array[Dictionary]:
	s.queue_redraw()
	UiDraw.tape.clear()
	UiDraw.taping = true
	await tree.process_frame
	UiDraw.taping = false
	var out: Array[Dictionary] = []
	for w: Dictionary in UiDraw.tape:
		if w.kind == &"text" and w.ci == s and String(w.text).strip_edges() != "":
			out.append(w)
	UiDraw.tape.clear()
	return out


## Contrast as WCAG measures it, on linear light.
static func _wcag(a: Color, b: Color) -> float:
	var la := _lum(a) + 0.05
	var lb := _lum(b) + 0.05
	return maxf(la, lb) / minf(la, lb)


static func _lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


static func _contrast(a: Color, b: Color) -> float:
	var la := a.get_luminance() + 0.05
	var lb := b.get_luminance() + 0.05
	return maxf(la, lb) / minf(la, lb)
