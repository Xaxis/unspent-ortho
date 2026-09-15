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


func test_fading_text_is_one_picture_with_a_clean_rim() -> void:
	eq(UiDraw.stepped(1.0), 1.0)
	eq(UiDraw.stepped(0.0), 0.0)
	eq(UiDraw.stepped(0.6), 0.75, "a fade holds in steps")
	eq(UiDraw.stepped(0.01), 0.25, "and is gone only at nothing")
	var tex := UiDraw.text_picture("pine - fell", Color.WHITE, Color.BLACK)
	var img := tex.get_image()
	eq(img.get_width(), UiFont.width("pine - fell") + 2, "one rim column each side")
	var ink := 0
	for ch in "pine - fell":
		for row in UiFont.glyph(ch):
			ink += row.count("#")
	var fill := 0
	var rim := 0
	var other := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			if c == Color.WHITE:
				fill += 1
			elif c == Color.BLACK:
				rim += 1
			else:
				other += 1
	eq(fill, ink, "every glyph pixel once, at full strength")
	gt(rim, fill, "a rim all round")
	eq(other, 0, "no in-between pixels to smear when it fades")
	# The glyphs sit where text() puts them: row 1 of the text box is the glyph's top.
	var p := UiDraw.text_picture("I", Color.WHITE, Color.BLACK).get_image()
	var first := -1
	for y in p.get_height():
		for x in p.get_width():
			if first < 0 and p.get_pixel(x, y) == Color.WHITE:
				first = y
	var glyph_top := 0
	while not UiFont.glyph("I")[glyph_top].contains("#"):
		glyph_top += 1
	# text() puts a glyph's top row at at.y + ASCENT - (ROWS - 2); the picture is drawn at at.y.
	eq(first, glyph_top + UiFont.ASCENT - (UiFont.ROWS - 2), "the picture's glyphs sit where text() draws them")


## Every character the slate can be asked to letter has a glyph: every string
## written in the slate's own source, every thing's name, every place's name.
func test_every_word_the_slate_writes_has_its_glyphs() -> void:
	var missing := {}
	var re := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for path: String in _sources():
		var text := FileAccess.get_file_as_string(path)
		for line in text.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#") or code.contains("res://") or code.contains("RegEx"):
				continue
			for m in re.search_all(line):
				_check_chars(m.get_string(1).replace("\\\"", "\"").replace("\\\\", "\\"), path.get_file(), missing)
	for id: StringName in Items.DEFS:
		_check_chars(UiRules.item_name(id), "item %s" % id, missing)
	for n in PropKind.NAMES:
		_check_chars(n, "prop", missing)
	for d in BiomeRegistry.all():
		_check_chars(d.display_name.to_upper(), "landscape %s" % d.id, missing)
	for ch: String in missing:
		fail("no glyph for '%s' (U+%04X), wanted by %s" % [ch, ch.unicode_at(0), missing[ch]])


func _check_chars(s: String, where: String, missing: Dictionary) -> void:
	for i in s.length():
		var ch := s[i]
		if ch == "\t" or ch == "\n":
			continue
		if not UiFont.GLYPHS.has(ch) and not missing.has(ch):
			missing[ch] = where


func _sources() -> Array[String]:
	var out: Array[String] = ["res://src/systems/90_ui.gd"]
	var dir := DirAccess.open("res://src/ui")
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append("res://src/ui/" + f)
	return out
