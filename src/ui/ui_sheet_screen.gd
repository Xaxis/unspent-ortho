class_name UiSheetScreen
extends UiScreen
## A review sheet for the ui's drawn parts, like the gallery is for models:
## every glyph of the font, every item icon at 1x and 3x, the need glyphs.
##   tools/shot.sh shots/ui/sheet.png --screen=sheet


func _init() -> void:
	super()
	screen_name = &"sheet"


func _draw() -> void:
	UiDraw.rect(self, Rect2i(0, 0, 640, 360), UiTheme.PAPER)
	var y := 6
	var line := ""
	for code in range(32, 127):
		line += String.chr(code)
		if line.length() == 48:
			UiDraw.text(self, Vector2i(8, y), line, UiTheme.INK)
			y += 11
			line = ""
	UiDraw.text(self, Vector2i(8, y), line + " ·—…×←→↑↓", UiTheme.INK)
	y += 13
	UiDraw.text(self, Vector2i(8, y), "The quick brown fox jumps over the lazy dog. pine - fell  day 12  23:59", UiTheme.INK)
	y += 11
	UiDraw.text_rimmed(self, Vector2i(9, y + 1), "rimmed over the world: took 2 timber.", UiTheme.HUD_TEXT, UiTheme.INK_DEEP)
	UiLettering.draw(self, "UNSPENT", Vector2i(400, 30), 22, UiTheme.INK, 7)
	y += 16
	var x := 8
	var shapes: Array = UiIcons.SHAPES.keys()
	for id: StringName in UiIcons.ITEMS:
		if x > 610:
			x = 8
			y += 12
		UiIcons.draw_item(self, id, Vector2i(x, y))
		x += 12
	y += 16
	x = 8
	for id: StringName in UiIcons.ITEMS:
		var st: StringName = UiIcons.style_of(id)[0]
		if not shapes.has(st):
			continue
		shapes.erase(st)
		if x > 600:
			x = 8
			y += 34
		UiDraw.rect(self, Rect2i(x - 1, y - 1, 29, 29), Color(UiTheme.PAPER_SHADE, 0.4))
		UiIcons.draw_item(self, id, Vector2i(x, y), 3)
		x += 32
	y += 36
	x = 8
	UiDraw.rect(self, Rect2i(0, y - 4, 640, 30), Palette.SLATE[1])
	for k: StringName in UiIcons.NEEDS:
		UiIcons.draw_need(self, k, Vector2i(x, y + 4), UiTheme.HUD_TEXT)
		UiIcons.draw_need(self, k, Vector2i(x + 14, y + 4), UiTheme.ACCENT_BRIGHT)
		x += 34
	var hud_icons := [&"knife", &"axe_hand", &"pick", &"mattock", &"billhook", &"stave", &"las_hand"]
	for id: StringName in hud_icons:
		UiDraw.sprite_rimmed(self, UiIcons.shape_of(id), Vector2i(x, y + 4), UiIcons.colours_for(id), UiTheme.INK_DEEP)
		x += 16
