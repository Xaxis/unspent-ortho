class_name UiPauseScreen
extends UiScreen
## Esc: the slate's home. The world stops (the ui system pauses the tree).
## Resume, the apps that have no key of their own (gear, machine reads, saves),
## the keys, back to the title, or quit. The keys are one level down; Esc backs
## out. The replacement sub-panel says where and when the player is, and when
## the game was last saved. Leaving (to the title, or quit) takes the autosave
## first when it is calm (05_save).

const KEYS := [
	["wasd", "walk"],
	["shift", "run, tap to dodge"],
	["k", "dodge"],
	["ctrl  q", "crouch"],
	["space  j", "swing, or pull free"],
	["e", "use what is in reach"],
	["x", "hold: put down what is in hand"],
	["f", "lamp"],
	["tab  i", "carrying"],
	["c", "making"],
	["m", "map"],
	["esc", "pause, or back"],
]
const LIST_TOP := 52
const ROW_PITCH := 16

## "list" or "keys".
var page := "list"
## Called for "title"; the ui system or title scene sets it. Empty = no such row.
var to_title: Callable
## Called with a screen name to open an app over home (the ui system sets it).
var open_app: Callable
## Share of the land seen, for the panel (the ui system sets it on open).
var seen_share := 0.0


func _init() -> void:
	super()
	screen_name = &"pause"
	own_action = &""


func _on_open() -> void:
	page = "list"


func refresh() -> void:
	var rows: Array[Dictionary] = [
		{"id": &"resume", "text": "resume"},
		{"id": &"loadout", "text": "gear", "app": true},
		{"id": &"reads", "text": "machine reads", "app": true},
		{"id": &"saves", "text": "saves", "app": true},
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
			Events.sfx.emit(&"ui_slate_back", Vector3.ZERO)
			queue_redraw()
		return true
	return super(action)


func _on_confirm(row: Dictionary) -> void:
	Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
	match row.id:
		&"resume":
			close()
		&"controls":
			page = "keys"
			queue_redraw()
		&"title":
			_save_on_leaving()
			close()
			if to_title.is_valid():
				to_title.call()
		&"quit":
			_save_on_leaving()
			get_tree().quit()
		_:
			if row.get("app", false) and open_app.is_valid():
				open_app.call(row.id)


## The save system's (05_save), when the game has one.
func _saver() -> Node:
	if game == null:
		return null
	for sys in game.systems:
		if sys.name == "05_save":
			return sys
	return null


## Leaving the game: the autosave takes it first, when calm.
func _save_on_leaving() -> void:
	var s := _saver()
	if s != null:
		s.call("save_on_leaving")


## "saved 4 minutes ago", "not saved yet"; "" without a save system.
func saved_line() -> String:
	var s := _saver()
	if s == null:
		return ""
	var at := float(s.get("last_saved_at"))
	return "not saved yet" if at < 0.0 else UiSavesScreen.ago(at, Time.get_unix_time_from_system())


## The keys, one to a line, from `at`, in two columns: the key lit, what it does dim.
static func draw_keys_list(ci: CanvasItem, at: Vector2i, key_w: int = 56) -> void:
	for i in KEYS.size():
		var top := at.y + i * UiTheme.LINE
		UiDraw.text(ci, Vector2i(at.x, top), KEYS[i][0], UiTheme.BRIGHT)
		UiDraw.text(ci, Vector2i(at.x + key_w, top), KEYS[i][1], UiTheme.TEXT_DIM)


func _draw() -> void:
	# Home is a tab of its own on the strip: it lights while it is on the glass.
	draw_frame()
	var L := UiSlate.LIST
	var R := UiSlate.SPARE
	UiSlate.title(self, L, "PAUSED" if page == "list" else "CONTROLS")
	UiSlate.spare(self)
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 8
	for i in menu.rows.size():
		var row := menu.rows[i]
		var top := LIST_TOP + i * ROW_PITCH
		var chosen := i == menu.index
		if chosen:
			UiSlate.row_bar(self, x0 - 4, right + 3, top)
		UiDraw.text(self, Vector2i(x0 + 8, top), row.text, UiTheme.BRIGHT if chosen else UiTheme.TEXT)
		if row.get("app", false):
			UiDraw.text_right(self, right, top, "→", UiTheme.TEXT_DIM if not chosen else UiTheme.TEXT)
	var px := R.position.x + UiSlate.MARGIN_L
	if page == "keys":
		UiSlate.heading(self, Vector2i(px, R.position.y + 8), "keys", R.end.x - 12)
		draw_keys_list(self, Vector2i(px + 4, R.position.y + 24))
		draw_keys([["esc", "back"]])
		return
	UiSlate.heading(self, Vector2i(px, R.position.y + 8), "here", R.end.x - 12)
	if game != null:
		var p := game.player.pos
		var biome := BiomeRegistry.at(game.world, p)
		UiDraw.text(self, Vector2i(px + 4, R.position.y + 24), biome.display_name, UiTheme.BRIGHT)
		UiDraw.text(self, Vector2i(px + 4, R.position.y + 35), game.clock.label(), UiTheme.TEXT)
		UiDraw.text(self, Vector2i(px + 4, R.position.y + 46), "%s of the land seen" % UiRules.share(seen_share), UiTheme.TEXT_DIM)
		_draw_body(Vector2i(px, R.position.y + 68), R.end.x - 12)
	var sy := R.position.y + 172
	UiSlate.heading(self, Vector2i(px, sy), "slate", R.end.x - 12)
	UiDraw.text(self, Vector2i(px + 4, sy + 16), "power", UiTheme.TEXT_DIM)
	UiSlate.meter(self, Rect2i(px + 60, sy + 16, 120, 8), power, 2.0, UiTheme.WARN if power < UiSlate.LOW_POWER else UiTheme.TEXT)
	UiDraw.text(self, Vector2i(px + 4, sy + 28), "runs off the lamp's oil, or a found charge", UiTheme.TEXT_DIM)
	var line := saved_line()
	if line != "":
		UiDraw.text(self, Vector2i(px + 4, sy + 44), line, UiTheme.TEXT)
	draw_keys([["e", "choose"], ["esc", "resume"]])


## The body as the slate last read it: health, wind, hunger, wet and load.
func _draw_body(at: Vector2i, right: int) -> void:
	const HUNGER := ["fed", "peckish", "hungry", "starving"]
	var b := game.body
	UiSlate.heading(self, at, "body", right)
	var x := at.x + 4
	var y := at.y + 16
	UiDraw.text(self, Vector2i(x, y), "health", UiTheme.TEXT_DIM)
	var cells := UiRules.health_cells(b.health, b.max_health)
	for i in cells.size():
		for t in UiRules.PER_CELL:
			var lit := t < cells[i]
			var col := (UiTheme.WARN if b.health <= UiRules.PER_CELL else UiTheme.TEXT) if lit else UiTheme.GHOST
			UiDraw.rect(self, Rect2i(x + 56 + i * 12 + t * 3, y + 1, 2, 7), col)
	y += 12
	UiDraw.text(self, Vector2i(x, y), "wind", UiTheme.TEXT_DIM)
	UiSlate.meter(self, Rect2i(x + 56, y + 1, 120, 7), b.wind / maxf(1.0, b.max_wind))
	y += 12
	var h := clampi(b.hunger_level(game.clock.minutes), 0, 3)
	UiDraw.text(self, Vector2i(x, y), "hunger", UiTheme.TEXT_DIM)
	UiDraw.text(self, Vector2i(x + 56, y), HUNGER[h], UiTheme.WARN if h >= 2 else UiTheme.TEXT)
	y += 12
	UiDraw.text(self, Vector2i(x, y), "wet", UiTheme.TEXT_DIM)
	UiSlate.meter(self, Rect2i(x + 56, y + 1, 120, 7), b.wet, 0.75)
	y += 12
	var load := game.inventory.bulk()
	var cap := UiLink.creel(game.inventory, b)
	UiDraw.text(self, Vector2i(x, y), "load", UiTheme.TEXT_DIM)
	UiDraw.text(self, Vector2i(x + 56, y), "%s of %s" % [UiRules.num(load), UiRules.num(cap)], UiTheme.WARN if load > cap else UiTheme.TEXT)
