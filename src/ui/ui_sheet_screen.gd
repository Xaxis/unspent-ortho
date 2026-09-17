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
	var y := g.position.y + UiSlate.STATUS_H + 12
	var line := ""
	for code in range(32, 127):
		line += String.chr(code)
		if line.length() == 48:
			UiDraw.text(self, Vector2i(x0, y), line, UiTheme.TEXT)
			y += UiTheme.LINE
			line = ""
	UiDraw.text(self, Vector2i(x0, y), line + " ·—…×←→↑↓", UiTheme.TEXT)
	y += 24
	UiDraw.text(self, Vector2i(x0, y), "The quick brown fox jumps over the lazy dog. pine - fell  day 12  23:59", UiTheme.BRIGHT)
	y += UiTheme.LINE
	UiDraw.text(self, Vector2i(x0, y), "dim: a faded row", UiTheme.TEXT_DIM)
	UiDraw.text(self, Vector2i(x0 + 220, y), "SHORT OF TWO CHARCOAL", UiTheme.WARN)
	UiDraw.text(self, Vector2i(x0 + 500, y), "runner  hostile  12 tiles", UiTheme.MACHINE[3])
	# The tones, and a specimen of the display lettering: a panel of the device's
	# own parts, so it came across whole rather than down with the type.
	var sx := g.end.x - 450
	for i in 5:
		UiDraw.rect(self, Rect2i(sx + i * 36, g.position.y + 54, 30, 30), UiTheme.PHOSPHOR[i])
		UiDraw.rect(self, Rect2i(sx + i * 36, g.position.y + 90, 30, 30), UiTheme.MACHINE[i])
	UiDraw.rect(self, Rect2i(sx + 192, g.position.y + 54, 30, 66), UiTheme.WARN)
	UiLettering.draw(self, "UNSPENT", Vector2i(sx - 30, g.position.y + 138), 66, UiTheme.TEXT, 7)
	y += 30
	var x := x0
	for id: StringName in UiIcons.ITEMS:
		if x > g.end.x - 48:
			x = x0
			y += 24
		UiIcons.draw_item(self, id, Vector2i(x, y))
		x += 24
	y += 28
	x = x0
	var shapes: Array = UiSketch.SHAPES.keys()
	for id: StringName in UiIcons.ITEMS:
		var st: StringName = UiIcons.style_of(id)[0]
		if not shapes.has(st):
			continue
		shapes.erase(st)
		if x > g.end.x - 180:
			x = x0
			y += 120
		UiSketch.draw_item(self, id, Vector2i(x, y), 114)
		x += 120
	y += 120
	x = x0
	for st: StringName in UiSketch.STATIONS:
		UiSketch.draw_station(self, st, Vector2i(x, y), 126)
		x += 138
	for k: StringName in UiIcons.NEEDS:
		UiDraw.sprite(self, UiIcons.pressure_rows(k), Vector2i(x, y + 8), {"#": UiTheme.TEXT})
		UiDraw.sprite(self, UiIcons.pressure_rows(k), Vector2i(x, y + 32), {"#": UiTheme.WARN})
		x += 24
	draw_keys([["esc", "back"]])
