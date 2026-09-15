class_name UiTitleMenu
extends UiScreen
## The title's page: the name lettered on a pasted label, and a small slip
## with new game, the coast's seed (left/right draws another), controls, quit.
## With a game saved, continue heads the slip (the newest readable save) and its
## picture is pasted beside it; a save that cannot be read is said so plainly
## under the slip.

const LABEL := Rect2i(170, 42, 300, 86)
const SLIP := Rect2i(254, 236, 132, 84)
const LETTER_H := 34
const ROW_H := 16
## The continued save's picture, pasted to the right of the slip.
const PHOTO := Rect2i(420, 222, 160, 90)

var title: UiTitle
## 0 shows the world, 1 is ink over everything.
var fade := 1.0:
	set(v):
		if not is_equal_approx(v, fade):
			fade = v
			queue_redraw()
var page := "list"
## The newest readable save (SaveSlots.list entry), or {}.
var saved := {}
var _photo: ImageTexture
var _opening := false


func _init() -> void:
	super()
	screen_name = &"title"
	lifts = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	var rows: Array[Dictionary] = [
		{"id": &"new", "text": "new game"},
		{"id": &"seed", "text": "coast"},
		{"id": &"controls", "text": "controls"},
		{"id": &"quit", "text": "quit"},
	]
	var entries := SaveSlots.list()
	saved = SaveSlots.newest(entries)
	_photo = SaveSlots.thumbnail(saved.header) if not saved.is_empty() else null
	var problems := SaveSlots.problems(entries)
	if not saved.is_empty():
		rows.insert(0, {"id": &"continue", "text": "continue"})
	elif not problems.is_empty():
		rows.insert(1, {"id": &"continue", "text": "continue", "enabled": false, "why": problems[0]})
	menu.set_rows(rows)
	if _opening and not saved.is_empty():
		menu.index = 0
	_opening = false
	if not problems.is_empty():
		say(problems[0])
	queue_redraw()


func _on_open() -> void:
	_opening = true


## The slip, grown upward by a row for each row past four.
func slip() -> Rect2i:
	var extra := maxi(0, menu.rows.size() - 4) * ROW_H
	return Rect2i(SLIP.position.x, SLIP.position.y - extra, SLIP.size.x, SLIP.size.y + extra)


func handle(action: StringName) -> bool:
	if page == "keys":
		if action == &"back" or action == &"confirm":
			page = "list"
			queue_redraw()
		return true
	if action == &"back":
		return true
	return super(action)


func _on_side(dir: int) -> void:
	if menu.selected().get("id") == &"seed" and title != null:
		Events.sfx.emit(&"menu_move", Vector3.ZERO)
		title.change_seed(dir)


func _on_confirm(row: Dictionary) -> void:
	match row.id:
		&"continue":
			if title != null:
				title.continue_game(int(saved.get("slot", -1)))
		&"new":
			if title != null:
				title.new_game()
		&"seed":
			_on_side(1)
		&"controls":
			Events.sfx.emit(&"menu_select", Vector3.ZERO)
			page = "keys"
			queue_redraw()
		&"quit":
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	for pair: Array in [[&"move_up", &"up"], [&"move_down", &"down"], [&"move_left", &"left"], [&"move_right", &"right"], [&"use", &"confirm"], [&"swing", &"confirm"], [&"pause", &"back"]]:
		if event.is_action_pressed(pair[0]):
			handle(pair[1])
			get_viewport().set_input_as_handled()
			return


func _draw() -> void:
	# A soft ink band behind the label and the slip keeps them calm over bright ground.
	for i in 6:
		UiDraw.rect(self, Rect2i(0, 0 + i * 6, 640, 6), Color(UiTheme.INK_DEEP, 0.3 - i * 0.05))
		UiDraw.rect(self, Rect2i(0, 354 - i * 6, 640, 6), Color(UiTheme.INK_DEEP, 0.3 - i * 0.05))
	_draw_label()
	if page == "keys":
		_draw_keys()
	else:
		_draw_slip()
		_draw_saved()
	if fade > 0.0:
		UiDraw.rect(self, Rect2i(0, 0, 640, 360), Color(UiTheme.INK_DEEP, fade))


func _draw_label() -> void:
	var r := LABEL
	# Shadow of the label lifting off the cover.
	UiDraw.rect(self, Rect2i(r.position.x + 3, r.position.y + 3, r.size.x, r.size.y), Color(UiTheme.INK_DEEP, 0.55))
	UiNotebook.page(self, r, 17, false, false)
	UiDraw.frame(self, r.grow(1), UiTheme.INK_DEEP)
	# Two ruled lines framing the name, the way a label is printed.
	UiDraw.hline(self, r.position.x + 8, r.end.x - 9, r.position.y + 8, UiTheme.INK)
	UiDraw.hline(self, r.position.x + 8, r.end.x - 9, r.position.y + 10, UiTheme.INK)
	UiDraw.hline(self, r.position.x + 8, r.end.x - 9, r.end.y - 11, UiTheme.INK)
	UiDraw.hline(self, r.position.x + 8, r.end.x - 9, r.end.y - 9, UiTheme.INK)
	var word := "UNSPENT"
	var w := UiLettering.width(word, LETTER_H)
	var at := Vector2i(r.position.x + (r.size.x - w) / 2, r.position.y + (r.size.y - LETTER_H) / 2)
	# Printed a hair off register in the accent, with its shade hatched onto the label.
	draw_texture(UiLettering.shade_texture(word, LETTER_H, 7, 4), Vector2(at), UiTheme.INK_SOFT)
	UiLettering.draw(self, word, at + Vector2i(1, 1), LETTER_H, Color(UiTheme.ACCENT, 0.9), 7)
	UiLettering.draw(self, word, at, LETTER_H, UiTheme.INK, 7)
	UiNotebook.tape(self, Vector2i(r.position.x - 8, r.position.y - 2), 30)
	UiNotebook.tape(self, Vector2i(r.end.x - 22, r.end.y - 5), 30)


func _draw_slip() -> void:
	var r := slip()
	UiDraw.rect(self, Rect2i(r.position.x + 2, r.position.y + 2, r.size.x, r.size.y), Color(UiTheme.INK_DEEP, 0.5))
	UiNotebook.page(self, r, 29, false, false)
	UiDraw.frame(self, r.grow(1), UiTheme.INK_DEEP)
	var x0 := r.position.x + 20
	for i in menu.rows.size():
		var row := menu.rows[i]
		var top := r.position.y + 10 + i * 16
		if i == menu.index:
			UiNotebook.cursor(self, x0 - 10, top)
		var text: String = row.text
		var ink := UiTheme.INK if UiMenu.enabled(row) else UiTheme.FADED
		if row.id == &"seed" and title != null:
			text = "coast %d" % title.seed_value
			if i == menu.index:
				UiDraw.text(self, Vector2i(r.end.x - 26, top), "<", UiTheme.FADED)
				UiDraw.text(self, Vector2i(r.end.x - 16, top), ">", UiTheme.FADED)
		UiDraw.text(self, Vector2i(x0, top), text, ink)
	UiNotebook.tape(self, Vector2i(r.position.x + r.size.x / 2 - 14, r.position.y - 3), 28)
	for i in range(1, menu.rows.size()):
		UiDraw.hand_hline(self, r.position.x + 6, r.end.x - 7, r.position.y + 10 + i * ROW_H - 4, UiTheme.RULE, 2 + i)


## The save Continue would load, as a picture pasted beside the slip with where
## and when it stands written under it; and, under the slip, what cannot be read.
func _draw_saved() -> void:
	var s := slip()
	if note != "":
		var w := UiFont.width(note)
		UiDraw.text_rimmed(self, Vector2i(320 - w / 2, s.end.y + 8), note, UiTheme.HUD_TEXT, UiTheme.INK_DEEP)
	if saved.is_empty():
		return
	var p := PHOTO
	var mount := Rect2i(p.position.x - 4, p.position.y - 4, p.size.x + 8, p.size.y + 20)
	UiDraw.rect(self, Rect2i(mount.position.x + 2, mount.position.y + 2, mount.size.x, mount.size.y), Color(UiTheme.INK_DEEP, 0.5))
	UiDraw.rect(self, mount, UiTheme.SLIP)
	UiDraw.frame(self, mount.grow(1), UiTheme.INK_DEEP)
	if _photo != null:
		draw_texture_rect(_photo, Rect2(p), false)
	else:
		UiDraw.rect(self, p, Color(UiTheme.PAPER_SHADE, 0.6))
	UiDraw.frame(self, p.grow(1), Color(UiTheme.INK_SOFT, 0.6))
	UiDraw.text(self, Vector2i(p.position.x, p.end.y + 5), SaveSlots.describe(saved.header), UiTheme.INK_SOFT)
	UiNotebook.tape(self, Vector2i(mount.end.x - 26, mount.position.y - 3), 30)


func _draw_keys() -> void:
	var r := Rect2i(216, 146, 208, 176)
	UiDraw.rect(self, Rect2i(r.position.x + 2, r.position.y + 2, r.size.x, r.size.y), Color(UiTheme.INK_DEEP, 0.5))
	UiNotebook.page(self, r, 31, false, false)
	UiDraw.frame(self, r.grow(1), UiTheme.INK_DEEP)
	UiPauseScreen.draw_keys(self, Vector2i(r.position.x + 14, r.position.y + 10))
	UiDraw.text(self, Vector2i(r.position.x + 14, r.end.y - 14), "esc back", UiTheme.FADED)
