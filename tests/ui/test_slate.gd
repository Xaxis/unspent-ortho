extends TestCase
## The slate as a device (docs/ART.md §9): one phosphor and one warning on dark
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
			if UiSlate._chamfered(x, y, size.x, size.y, 4):
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
	check(UiSlate.SPARE.end.x - 12 <= zone.position.x, "the spare panel's words are clear of the crack")


func test_power_dims_the_glass_not_the_bezel() -> void:
	var s := UiPauseScreen.new()
	tree.root.add_child(s)
	s.open()
	s.settle()
	s.brightness = UiRules.brightness(0.0)
	check(s.brightness >= UiSlate.DIM_FLOOR, "dim, never unreadable")
	s.free()


func test_the_slate_bakes_ahead_off_the_main_thread() -> void:
	UiSlate.warm()
	UiSlate.wait()
	var tex := UiSlate.device_texture(UiSlate.DEVICE.size)
	eq(Vector2i(tex.get_size()), UiSlate.DEVICE.size + Vector2i(UiSlate.PAD, UiSlate.PAD) * 2)
	check(UiSlate.device_texture(UiSlate.DEVICE.size) == tex, "baked once")


static func _contrast(a: Color, b: Color) -> float:
	var la := a.get_luminance() + 0.05
	var lb := b.get_luminance() + 0.05
	return maxf(la, lb) / minf(la, lb)
