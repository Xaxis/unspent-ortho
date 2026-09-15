extends TestCase
## The pixel font: every printable ASCII character is drawn, fits the 5x7 cell
## (plus 2 descender rows), and the FontFile agrees with the glyph tables.


func test_every_printable_ascii_character_has_a_glyph() -> void:
	var f := UiFont.font()
	for code in range(32, 127):
		var ch := String.chr(code)
		check(UiFont.GLYPHS.has(ch), "no glyph for %s (%d)" % [ch, code])
		check(f.has_char(code), "FontFile lacks %s (%d)" % [ch, code])


func test_glyphs_fit_the_cell() -> void:
	for ch: String in UiFont.GLYPHS:
		var rows: Array = UiFont.GLYPHS[ch]
		check(rows.size() <= UiFont.ROWS, "%s has %d rows" % [ch, rows.size()])
		for r: String in rows:
			check(r.length() <= 5, "%s is %d wide" % [ch, r.length()])
			for i in r.length():
				check(r[i] == "#" or r[i] == ".", "%s has stray character %s" % [ch, r[i]])


func test_only_space_is_blank() -> void:
	for code in range(33, 127):
		var ch := String.chr(code)
		check("".join(UiFont.glyph(ch)).contains("#"), "%s draws nothing" % ch)
	check(not "".join(UiFont.glyph(" ")).contains("#"), "space draws ink")


func test_capitals_and_digits_stand_on_the_baseline() -> void:
	# Row 6 is the last row above the baseline: every capital and digit touches it.
	for code in range(65, 91):
		var ch := String.chr(code)
		check(UiFont.glyph(ch)[6].contains("#") or ch == "Q", "%s floats above the baseline" % ch)
	for code in range(48, 58):
		var ch := String.chr(code)
		check(UiFont.glyph(ch)[6].contains("#"), "%s floats above the baseline" % ch)
		eq(UiFont.glyph_width(ch), 5, "digit %s width" % ch)


func test_descenders_go_below_the_baseline() -> void:
	for ch: String in ["g", "j", "p", "q", "y"]:
		check(UiFont.glyph(ch)[7].contains("#"), "%s has no descender" % ch)


func test_width_matches_the_font_file() -> void:
	var f := UiFont.font()
	for s: String in ["day 1  08:00", "pine - fell", "a piece of plate", "UNSPENT", "!"]:
		var measured := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE)
		# Font advance includes the gap after the last glyph; UiFont.width does not.
		eq(int(measured.x), UiFont.width(s) + 1, "width of '%s'" % s)
	eq(int(f.get_height(UiFont.SIZE)), UiFont.ASCENT + UiFont.DESCENT, "line height")


func test_theme_uses_the_pixel_font() -> void:
	var t := UiTheme.theme()
	check(t.default_font == UiFont.font(), "theme default font")
	eq(t.default_font_size, UiFont.SIZE, "theme font size")
	eq(UiFont.font().antialiasing, TextServer.FONT_ANTIALIASING_NONE, "no antialiasing")
