class_name UiPauseScreen
extends UiScreen
## Esc: the slate's home. The world stops (the ui system pauses the tree).
## Resume, the apps that have no key of their own (gear, machine reads, saves),
## the journal for a player who has forgotten its key, the keys, back to the
## title, or quit. The keys are one level down; Esc backs
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
	["z", "hold: read a machine; a d another, r the field"],
	["esc", "pause, or back"],
]
## The home list starts a clear line under the pane's title, and its rows sit a
## little further apart than a list's: they are choices, not entries.
const LIST_TOP := UiSlate.LIST.position.y + 40
const ROW_PITCH := UiTheme.LINE + 10

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
		{"id": &"journal", "text": "journal", "app": true},
		{"id": &"saves", "text": "saves", "app": true},
		{"id": &"settings", "text": "settings", "app": true},
		{"id": &"title", "text": "to the title", "enabled": true},
		{"id": &"quit", "text": "quit"},
	]
	if DevMode.reachable() and game != null:
		# Dev mode's app (docs/DEV.md), marked as not the player's: the module's violet.
		rows.insert(rows.size() - 2, {"id": &"dev", "text": "dev", "app": true, "dev": true})
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
		&"settings":
			if open_app.is_valid():
				open_app.call(&"settings")
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
static func draw_keys_list(ci: CanvasItem, at: Vector2i, key_w: int = 112) -> void:
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
	var right := L.end.x - 16
	for i in menu.rows.size():
		var row := menu.rows[i]
		var top := LIST_TOP + i * ROW_PITCH
		var chosen := i == menu.index
		if chosen:
			UiSlate.row_bar(self, x0 - 8, right + 6, top)
		var ink := UiTheme.BRIGHT if chosen else UiTheme.TEXT
		if row.get("dev", false):
			ink = UiTheme.MACHINE[4] if chosen else UiTheme.MACHINE[3]
			var badge := UiFont.width("DEV") + 8
			UiDraw.frame(self, Rect2i(right - badge - 30, top - 2, badge, UiTheme.LINE), UiTheme.MACHINE[1])
			UiDraw.text(self, Vector2i(right - badge - 26, top - 2), "DEV", UiTheme.MACHINE[3])
		UiDraw.text(self, Vector2i(x0 + 16, top), row.text, ink)
		if row.get("app", false):
			UiDraw.text_right(self, right, top, "→", UiTheme.TEXT_DIM if not chosen else UiTheme.TEXT)
	var px := R.position.x + UiSlate.MARGIN_L
	if page == "keys":
		UiSlate.heading(self, Vector2i(px, R.position.y + 16), "keys", R.end.x - 24)
		draw_keys_list(self, Vector2i(px + 8, R.position.y + 48))
		draw_keys([["esc", "back"]])
		return
	UiSlate.heading(self, Vector2i(px, R.position.y + 16), "here", R.end.x - 24)
	if game != null:
		var p := game.player.pos
		var biome := BiomeRegistry.at(game.world, p)
		UiDraw.text(self, Vector2i(px + 8, R.position.y + 48), biome.display_name, UiTheme.BRIGHT)
		UiDraw.text(self, Vector2i(px + 8, R.position.y + 48 + UiTheme.LINE), game.clock.label(), UiTheme.TEXT)
		UiDraw.text(self, Vector2i(px + 8, R.position.y + 48 + UiTheme.LINE * 2), "%s of the land seen" % UiRules.share(seen_share), UiTheme.TEXT_DIM)
		_draw_body(Vector2i(px, R.position.y + 136), R.end.x - 24)
	var sy := R.position.y + 344
	UiSlate.heading(self, Vector2i(px, sy), "slate", R.end.x - 24)
	UiDraw.text(self, Vector2i(px + 8, sy + 32), "power", UiTheme.TEXT_DIM)
	UiSlate.meter(self, Rect2i(px + 120, sy + 32, 240, 16), power, 2.0, UiTheme.WARN if power < UiSlate.LOW_POWER else UiTheme.TEXT)
	UiDraw.text(self, Vector2i(px + 8, sy + 56), "runs off the lamp's oil, or a found charge", UiTheme.TEXT_DIM)
	var line := saved_line()
	if line != "":
		UiDraw.text(self, Vector2i(px + 8, sy + 88), line, UiTheme.TEXT)
	draw_keys([["e", "choose"], ["esc", "resume"]])


## The body as the slate last read it: health, wind, hunger, wet and load.
func _draw_body(at: Vector2i, right: int) -> void:
	const HUNGER := ["fed", "peckish", "hungry", "starving"]
	var b := game.body
	UiSlate.heading(self, at, "body", right)
	var x := at.x + 8
	var y := at.y + 32
	UiDraw.text(self, Vector2i(x, y), "health", UiTheme.TEXT_DIM)
	var cells := UiRules.health_cells(b.health, b.max_health)
	for i in cells.size():
		for t in UiRules.PER_CELL:
			var lit := t < cells[i]
			var col := (UiTheme.WARN if b.health <= UiRules.PER_CELL else UiTheme.TEXT) if lit else UiTheme.GHOST
			UiDraw.rect(self, Rect2i(x + 112 + i * 24 + t * 6, y + 2, 4, 14), col)
	y += 24
	UiDraw.text(self, Vector2i(x, y), "wind", UiTheme.TEXT_DIM)
	UiSlate.meter(self, Rect2i(x + 112, y + 2, 240, 14), b.wind / maxf(1.0, b.max_wind))
	y += 24
	var h := clampi(b.hunger_level(game.clock.minutes), 0, 3)
	UiDraw.text(self, Vector2i(x, y), "hunger", UiTheme.TEXT_DIM)
	UiDraw.text(self, Vector2i(x + 112, y), HUNGER[h], UiTheme.WARN if h >= 2 else UiTheme.TEXT)
	y += 24
	UiDraw.text(self, Vector2i(x, y), "wet", UiTheme.TEXT_DIM)
	UiSlate.meter(self, Rect2i(x + 112, y + 2, 240, 14), b.wet, 0.75)
	y += 24
	var load := game.inventory.bulk()
	var cap := UiLink.creel(game.inventory, b)
	UiDraw.text(self, Vector2i(x, y), "load", UiTheme.TEXT_DIM)
	UiDraw.text(self, Vector2i(x + 112, y), "%s of %s" % [UiRules.num(load), UiRules.num(cap)], UiTheme.WARN if load > cap else UiTheme.TEXT)
