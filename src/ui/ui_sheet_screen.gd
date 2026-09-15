class_name UiSheetScreen
extends UiScreen
## A review sheet for the slate's drawn parts, like the gallery is for models:
## every glyph of the font, the tones, every item icon, the scans, the pressure
## glyphs and the HUD's clips over a strip of ground.
##   tools/shot.sh shots/slate/sheet.png --screen=sheet


func _init() -> void:
	super()
	screen_name = &"sheet"


func _draw() -> void:
	draw_frame(&"")
	var g := UiSlate.GLASS_RECT
	var x0 := g.position.x + UiSlate.MARGIN_L
	var y := g.position.y + UiSlate.STATUS_H + 6
	var line := ""
	for code in range(32, 127):
		line += String.chr(code)
		if line.length() == 48:
			UiDraw.text(self, Vector2i(x0, y), line, UiTheme.TEXT)
			y += 11
			line = ""
	UiDraw.text(self, Vector2i(x0, y), line + " ·—…×←→↑↓", UiTheme.TEXT)
	y += 12
	UiDraw.text(self, Vector2i(x0, y), "The quick brown fox jumps over the lazy dog. pine - fell  day 12  23:59", UiTheme.BRIGHT)
	y += 11
	UiDraw.text(self, Vector2i(x0, y), "dim: a faded row", UiTheme.TEXT_DIM)
	UiDraw.text(self, Vector2i(x0 + 110, y), "SHORT OF TWO CHARCOAL", UiTheme.WARN)
	UiDraw.text(self, Vector2i(x0 + 250, y), "runner  hostile  12 tiles", UiTheme.MACHINE[3])
	# The tones.
	var sx := g.end.x - 150
	for i in 5:
		UiDraw.rect(self, Rect2i(sx + i * 12, g.position.y + 18, 10, 10), UiTheme.PHOSPHOR[i])
		UiDraw.rect(self, Rect2i(sx + i * 12, g.position.y + 30, 10, 10), UiTheme.MACHINE[i])
	UiDraw.rect(self, Rect2i(sx + 64, g.position.y + 18, 10, 22), UiTheme.WARN)
	UiLettering.draw(self, "UNSPENT", Vector2i(sx - 10, g.position.y + 46), 22, UiTheme.TEXT, 7)
	y += 15
	var x := x0
	for id: StringName in UiIcons.ITEMS:
		if x > g.end.x - 24:
			x = x0
			y += 12
		UiIcons.draw_item(self, id, Vector2i(x, y))
		x += 12
	y += 14
	x = x0
	var shapes: Array = UiSketch.SHAPES.keys()
	for id: StringName in UiIcons.ITEMS:
		var st: StringName = UiIcons.style_of(id)[0]
		if not shapes.has(st):
			continue
		shapes.erase(st)
		if x > g.end.x - 60:
			x = x0
			y += 40
		UiSketch.draw_item(self, id, Vector2i(x, y), 38)
		x += 40
	y += 40
	x = x0
	for st: StringName in UiSketch.STATIONS:
		UiSketch.draw_station(self, st, Vector2i(x, y), 42)
		x += 46
	for k: StringName in UiIcons.NEEDS:
		UiDraw.sprite(self, UiIcons.pressure_rows(k), Vector2i(x, y + 4), {"#": UiTheme.TEXT})
		UiDraw.sprite(self, UiIcons.pressure_rows(k), Vector2i(x, y + 16), {"#": UiTheme.WARN})
		x += 12
	draw_keys([["esc", "back"]])
