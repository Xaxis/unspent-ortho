class_name UiPauseScreen
extends UiScreen
## Esc: the world stops (the ui system pauses the tree). Resume, the keys,
## back to the title, or quit. The keys page is one level down; Esc backs out.

const KEYS := [
	["wasd", "walk"],
	["shift", "run, or dodge"],
	["space", "swing"],
	["e", "use what is in reach"],
	["f", "lamp"],
	["tab  i", "carrying"],
	["c", "make, at a station"],
	["m", "map"],
	["esc", "pause"],
]

## "list" or "keys".
var page := "list"
## Called for "title"; the ui system or title scene sets it. Empty = no such row.
var to_title: Callable


func _init() -> void:
	super()
	screen_name = &"pause"
	own_action = &""


func _on_open() -> void:
	page = "list"


func refresh() -> void:
	var rows: Array[Dictionary] = [
		{"id": &"resume", "text": "resume"},
		{"id": &"controls", "text": "controls"},
		{"id": &"title", "text": "to the title", "enabled": true},
		{"id": &"quit", "text": "quit"},
	]
	menu.set_rows(rows)
	queue_redraw()


func handle(action: StringName) -> bool:
	if is_open and page == "keys":
		if action == &"back" or action == &"confirm":
			page = "list"
			Events.sfx.emit(&"close_book", Vector3.ZERO)
			queue_redraw()
		return true
	return super(action)


func _on_confirm(row: Dictionary) -> void:
	Events.sfx.emit(&"menu_select", Vector3.ZERO)
	match row.id:
		&"resume":
			close()
		&"controls":
			page = "keys"
			queue_redraw()
		&"title":
			close()
			if to_title.is_valid():
				to_title.call()
		&"quit":
			get_tree().quit()


## The keys, one to a ruled line, starting with the first line's top at `at`.
static func draw_keys(ci: CanvasItem, at: Vector2i) -> void:
	for i in KEYS.size():
		var top := at.y + i * UiTheme.LINE
		UiDraw.text(ci, Vector2i(at.x, top), KEYS[i][0], UiTheme.INK)
		UiDraw.text(ci, Vector2i(at.x + 50, top), KEYS[i][1], UiTheme.INK_SOFT)


func _draw() -> void:
	var P := UiNotebook.SINGLE
	UiNotebook.single(self, P, 41)
	var x0 := P.position.x + UiNotebook.MARGIN_X
	if page == "keys":
		UiNotebook.title(self, P, "controls", 12)
		draw_keys(self, Vector2i(x0 + 8, UiNotebook.line_top(P, 1)))
		UiNotebook.footer(self, P, "esc back")
		return
	UiNotebook.title(self, P, "paused", 4)
	for i in menu.rows.size():
		var row := menu.rows[i]
		var top := UiNotebook.line_top(P, i * 2 + 1)
		if i == menu.index:
			UiNotebook.cursor(self, x0 + 6, top)
		UiDraw.text(self, Vector2i(x0 + 16, top), row.text, UiTheme.INK)
	if game != null:
		var p := game.player.pos
		var place := Country.NAMES[game.world.country_at(floori(p.x), floori(p.y))]
		UiDraw.text_right(self, P.end.x - 12, UiNotebook.line_top(P, 9), game.clock.label(), UiTheme.FADED)
		UiDraw.text_right(self, P.end.x - 12, UiNotebook.line_top(P, 10), place, UiTheme.FADED)
	UiNotebook.footer(self, P, "e choose     esc resume")
