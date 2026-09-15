class_name UiTitleMenu
extends UiScreen
## The title's page: the name lettered on a pasted label, and a small slip
## with new game, the coast's seed (left/right draws another), controls, quit.

const LABEL := Rect2i(170, 42, 300, 86)
const SLIP := Rect2i(254, 236, 132, 84)
const LETTER_H := 34

var title: UiTitle
## 0 shows the world, 1 is ink over everything.
var fade := 1.0:
	set(v):
		if not is_equal_approx(v, fade):
			fade = v
			queue_redraw()
var page := "list"


func _init() -> void:
	super()
	screen_name = &"title"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	var rows: Array[Dictionary] = [
		{"id": &"new", "text": "new game"},
		{"id": &"seed", "text": "coast"},
		{"id": &"controls", "text": "controls"},
		{"id": &"quit", "text": "quit"},
	]
	menu.set_rows(rows)
	queue_redraw()


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
	var r := SLIP
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
		if row.id == &"seed" and title != null:
			text = "coast %d" % title.seed_value
			if i == menu.index:
				UiDraw.text(self, Vector2i(r.end.x - 26, top), "<", UiTheme.FADED)
				UiDraw.text(self, Vector2i(r.end.x - 16, top), ">", UiTheme.FADED)
		UiDraw.text(self, Vector2i(x0, top), text, UiTheme.INK)
	UiNotebook.tape(self, Vector2i(r.position.x + r.size.x / 2 - 14, r.position.y - 3), 28)
	UiDraw.hand_hline(self, r.position.x + 6, r.end.x - 7, r.position.y + 10 + 1 * 16 - 4, UiTheme.RULE, 3)
	UiDraw.hand_hline(self, r.position.x + 6, r.end.x - 7, r.position.y + 10 + 2 * 16 - 4, UiTheme.RULE, 4)
	UiDraw.hand_hline(self, r.position.x + 6, r.end.x - 7, r.position.y + 10 + 3 * 16 - 4, UiTheme.RULE, 5)


func _draw_keys() -> void:
	var r := Rect2i(216, 146, 208, 176)
	UiDraw.rect(self, Rect2i(r.position.x + 2, r.position.y + 2, r.size.x, r.size.y), Color(UiTheme.INK_DEEP, 0.5))
	UiNotebook.page(self, r, 31, false, false)
	UiDraw.frame(self, r.grow(1), UiTheme.INK_DEEP)
	UiPauseScreen.draw_keys(self, Vector2i(r.position.x + 14, r.position.y + 10))
	UiDraw.text(self, Vector2i(r.position.x + 14, r.end.y - 14), "esc back", UiTheme.FADED)
