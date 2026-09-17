extends TestCase
## The marks drawn over the WORLD have to hold against what `lit` put behind them.
##
## Everything else the slate says is read off its own opaque glass, so the only
## question there is the phosphor against the glass (tests/ui/test_slate.gd). The
## three things drawn over the world have no such guarantee: a body's tag, the
## location ping and the pickup feed all sit on a translucent or a small scrap of
## glass with a landscape behind them — and since LANTERN lit the world, that
## landscape runs from a genuinely dark bog to a hearth, a machine's lens or snow
## at noon, and it can change under a mark while the player is reading it.
##
## So the worst case is stated here as a number rather than judged in a screenshot:
## the ground behind a mark is taken as WHITE, which is the brightest anything can
## be, and the mark must still read. The other end is checked too, because the
## first fix for this was an opaque black lozenge that cut a hole in every frame.


## WCAG contrast on linear light, as tests/ui/test_slate.gd measures it.
static func _wcag(a: Color, b: Color) -> float:
	var la := _lum(a) + 0.05
	var lb := _lum(b) + 0.05
	return maxf(la, lb) / minf(la, lb)


static func _lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## `col` at alpha `a` laid over `ground`, the way the canvas composites it.
static func _over(col: Color, a: float, ground: Color) -> Color:
	return Color(ground.r, ground.g, ground.b).lerp(Color(col.r, col.g, col.b), a)


## A tag carries no word — pips and one glyph — so it is held to the bar a
## non-text indicator is held to, not the bar a sentence is.
const INDICATOR := 3.0


func test_a_bodys_tag_reads_over_the_brightest_ground_there_is() -> void:
	var backing := _over(UiTheme.GLASS, UiTargetView.TAG_GLASS, Color.WHITE)
	# Every ink a tag is ever drawn in. MACHINE[2] is the binding one and the easy
	# one to forget: MACHINE[3] is only used while that body is the one being READ,
	# so what stands over every machine the player has not locked is the darker
	# step. Getting this wrong is what made the tag disappear over snow.
	for ink: Color in [UiTheme.TEXT, UiTheme.TEXT_DIM, UiTheme.MACHINE[2], UiTheme.MACHINE[3]]:
		var c := _wcag(ink, backing)
		check(c >= INDICATOR, "a tag's %s reads at only %.2f:1 over a white ground" % [ink.to_html(false), c])
	# ...and the rim under the pips, which is what gives the tag an edge.
	gt(_wcag(UiTheme.FAINT, backing), 1.4, "the tag's rail is still seen over white")


func test_a_bodys_tag_cuts_no_hole_in_a_dark_frame() -> void:
	# The charge the first version was convicted on: an opaque lozenge whose
	# darkest pixels sat under anything else in the frame. A lit night frame has
	# real black in it now, so the tag only has to stay inside that range.
	var dark := _over(UiTheme.GLASS, UiTargetView.TAG_GLASS, Color.BLACK)
	var most := maxf(dark.r, maxf(dark.g, dark.b)) * 255.0
	check(most > 12.0, "the tag over black is a hole at %d of 255" % roundi(most))
	check(dark != Color.BLACK, "the tag is never pure black")
	check(UiTargetView.TAG_GLASS < 1.0, "the tag's glass is never opaque")


func test_the_words_over_the_world_are_read_off_opaque_glass() -> void:
	# A conversation and a machine's read are the two places the slate writes
	# SENTENCES over the world. Neither may take its legibility from what is
	# behind it: both are drawn on `Hud.clip`, whose glass is opaque.
	eq(UiTheme.GLASS.a, 1.0, "the clip's glass is opaque")
	eq(UiTheme.RIM.a, 1.0, "and so is the dead glass it is held by")
	gt(_wcag(UiTheme.TEXT, UiTheme.GLASS), 6.5, "words on that glass")
	gt(_wcag(UiTheme.BRIGHT, UiTheme.GLASS), 6.5, "and what is being said now")
	var src := (load("res://src/ui/ui_talk_view.gd") as GDScript).source_code
	check(src.contains("Hud.clip("), "a conversation is read off the slate's own glass")


func test_a_fading_line_over_the_world_keeps_its_rim() -> void:
	# The message line and the pickup feed fade, and a fading rim is what holds
	# them over a landscape. It is drawn as ONE picture at a stepped alpha, never
	# as nine translucent passes, or the rim piles up where the passes overlap.
	var tex := UiDraw.text_picture("the tide", UiTheme.TEXT, UiTheme.RIM)
	var img := tex.get_image()
	eq(img.get_width(), UiFont.width("the tide") + UiFont.PITCH * 2, "a rim of one module pixel each side")
	var rim := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.a < 1.0:
				fail("a half-strength pixel at %d,%d would smear as it fades" % [x, y])
			if c.a > 0.0 and Color(c, 1.0) == UiTheme.RIM:
				rim += 1
	gt(rim, 0, "there is a rim to hold it")
