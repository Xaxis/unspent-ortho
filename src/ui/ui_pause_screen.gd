class_name UiPauseScreen
extends UiScreen
## Esc: the world stops (the ui system pauses the tree). Resume, the keys,
## back to the title, or quit. The keys page is one level down; Esc backs out.

const KEYS := [
	["wasd", "walk"],
	["shift", "run, tap to dodge"],
	["k", "dodge"],
	["space  j", "swing, or pull free"],
	["e", "use what is in reach"],
	["f", "lamp"],
	["tab  i", "carrying"],
	["c", "making"],
	["m", "map"],
	["esc", "pause, or back"],
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
		{"id": &"save", "text": "save"},
		{"id": &"load", "text": "load"},
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
		&"save", &"load":
			open_saves(row.id)
		&"title":
			close()
			if to_title.is_valid():
				to_title.call()
		&"quit":
			get_tree().quit()


## Save or load: the saves page opens over this one (UiSavesScreen), through the
## ui system so it takes the keys and Esc comes back here.
func open_saves(mode: StringName) -> void:
	if game == null:
		return
	for sys in game.systems:
		if sys.name == "90_ui":
			var s: UiSavesScreen = (sys.get("screens") as Dictionary).get(&"saves")
			if s == null:
				return
			s.mode = mode
			if not bool(sys.call("open_screen", &"saves")):
				say("Not with that so close.")


## The keys, one to a ruled line, starting with the first line's top at `at`.
static func draw_keys(ci: CanvasItem, at: Vector2i) -> void:
	for i in KEYS.size():
		var top := at.y + i * UiTheme.LINE
		UiDraw.text(ci, Vector2i(at.x, top), KEYS[i][0], UiTheme.INK)
		UiDraw.text(ci, Vector2i(at.x + 56, top), KEYS[i][1], UiTheme.INK_SOFT)


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
		var below := menu.rows.size() * 2
		UiDraw.text_right(self, P.end.x - 12, UiNotebook.line_top(P, below), game.clock.label(), UiTheme.FADED)
		UiDraw.text_right(self, P.end.x - 12, UiNotebook.line_top(P, below + 1), place, UiTheme.FADED)
	UiNotebook.footer(self, P, "e choose     esc resume")
	UiNotebook.note(self, P, note, note_age)
