class_name UiScreen
extends Control
## A full-screen page of the notebook. Screens take abstract actions, never
## devices, so tests drive them directly:
##   up down left right   choose / change a value
##   confirm              do the chosen row (E, Enter, Space)
##   back                 close, one level (Esc)
##   <own_action>         the key that opened the screen also closes it
## Opening and closing emit Events.screen_changed(screen_name, open), which is
## what pauses gameplay input, and the book sounds.

signal closed(screen: UiScreen)

## Set by subclasses in _init.
var screen_name: StringName = &"screen"
var own_action: StringName = &""
var menu := UiMenu.new()
## The running game, or null (title, tests without a world).
var game: Game
## A short line at the foot of the page: why a row was refused, what was made.
var note := ""
var note_age := 0.0
var is_open := false
## 0..1: the page is lifted into view over a moment when it opens, the way a
## notebook is brought up, at whole pixels so nothing blurs. Title pages stay put.
var reveal := 1.0
var lifts := true
const LIFT_PX := 8
const LIFT_SECONDS := 0.14
## First row drawn of a list longer than its page.
var scroll := 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.theme()
	visible = false


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	reveal = 0.0 if lifts else 1.0
	_place_reveal()
	note = ""
	_on_open()
	refresh()
	# The HUD steps aside while a page is open; its messages land on the page.
	if not Events.message.is_connected(say):
		Events.message.connect(say)
	Events.screen_changed.emit(screen_name, true)
	Events.sfx.emit(&"open_book", Vector3.ZERO)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if Events.message.is_connected(say):
		Events.message.disconnect(say)
	_on_close()
	Events.screen_changed.emit(screen_name, false)
	Events.sfx.emit(&"close_book", Vector3.ZERO)
	closed.emit(self)


## Rebuild rows from the game's data and redraw.
func refresh() -> void:
	queue_redraw()


## Returns true if the action was used.
func handle(action: StringName) -> bool:
	if not is_open:
		return false
	match action:
		&"up", &"down":
			if menu.move(-1 if action == &"up" else 1):
				Events.sfx.emit(&"menu_move", Vector3.ZERO)
				_on_choice_changed()
				queue_redraw()
			return true
		&"left", &"right":
			_on_side(-1 if action == &"left" else 1)
			return true
		&"confirm":
			var row := menu.selected()
			if row.is_empty():
				return true
			if not UiMenu.enabled(row):
				refuse(String(row.get("why", "Not now.")))
			else:
				_on_confirm(row)
			return true
		&"back":
			close()
			return true
	if own_action != &"" and action == own_action:
		close()
		return true
	return false


## Move the choice to the row whose id is `id`, if there is one (shots, links).
func select(id: StringName) -> void:
	for i in menu.rows.size():
		if UiMenu.selectable(menu.rows[i]) and menu.rows[i].get("id") == id:
			menu.index = i
			_on_choice_changed()
			queue_redraw()
			return


## Move `scroll` so the chosen row is among the `lines` drawn, keeping a
## group's heading in view with its first row.
func keep_in_view(lines: int) -> void:
	if menu.index < 0:
		scroll = 0
		return
	if menu.index < scroll:
		scroll = menu.index
	elif menu.index >= scroll + lines:
		scroll = menu.index - lines + 1
	if scroll > 0 and menu.index == scroll and menu.rows[scroll - 1].has("header"):
		scroll -= 1
	scroll = clampi(scroll, 0, maxi(0, menu.rows.size() - lines))


func refuse(why: String) -> void:
	Events.sfx.emit(&"refused", Vector3.ZERO)
	say(why)


func say(text: String) -> void:
	note = text
	note_age = 0.0
	queue_redraw()


func _exit_tree() -> void:
	# Sketches this page asked for may still be drawing on a worker.
	UiSketch.wait()


## Jump the opening lift to its end (screenshots).
func settle() -> void:
	reveal = 1.0
	_place_reveal()


func _place_reveal() -> void:
	var t := 1.0 - pow(1.0 - reveal, 3.0)
	position.y = roundi((1.0 - t) * LIFT_PX)
	modulate.a = clampf(reveal * 1.6, 0.0, 1.0)


func _process(delta: float) -> void:
	if is_open and reveal < 1.0:
		reveal = minf(1.0, reveal + delta / LIFT_SECONDS)
		_place_reveal()
	if is_open and note != "":
		note_age += delta


# --- for subclasses ---

func _on_open() -> void:
	pass


func _on_close() -> void:
	pass


func _on_confirm(_row: Dictionary) -> void:
	Events.sfx.emit(&"menu_select", Vector3.ZERO)


func _on_side(_dir: int) -> void:
	pass


func _on_choice_changed() -> void:
	pass
