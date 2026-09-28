class_name DevPageTab
extends DevPage
## One of the dev app's five tabs, the first page under its strip (UiDevScreen):
## WORLD, STORY, FIGHT, LOOK & SPEED, SAVES. A tab holds the pages it is about
## in one of two ways:
##
##   inline  a short page's rows stand on the tab itself, under the page's name,
##           and a row keeps its own id and does what its page does with it (the
##           page is kept here and every confirm, side, panel and key strip for
##           that row is its page's). Nothing is copied: the page is the page.
##   doors   a long page (every warp, every item, every build) is a row that
##           steps into it, as home's rows did.
##
## STORY's tab is the story page itself (DevPageStory), which was already a hub.
## Every page id a key, a tool or a tour ever opened (`--dev=PAGE[:ROW]`) still
## resolves through `tab_of`, to the tab that holds it now.

## In strip order. `inline` and `doors` are page ids of `page_for`; `game`: the
## tab reads a running game and says so on the title.
const TABS: Array[Dictionary] = [
	{"id": &"world", "name": "WORLD", "game": true, "doors": [&"go"], "inline": [&"time"]},
	{"id": &"story", "name": "STORY", "game": true},
	{"id": &"fight", "name": "FIGHT", "game": true, "doors": [&"give"], "inline": [&"body", &"spawn"]},
	{"id": &"look", "name": "LOOK & SPEED", "game": true, "inline": [&"view"]},
	{"id": &"saves", "name": "SAVES", "game": false, "doors": [&"config", &"notes", &"builds", &"proofs"], "inline": []},
]
## The tab a game opens on, and the one the title opens on (the rest need a game).
const FIRST := 0
const FIRST_ON_TITLE := 4

## A door's row: what it is called and what it stands at.
const DOOR_NAMES := {&"go": "go", &"give": "things", &"config": "configuration", &"notes": "notes",
	&"builds": "builds", &"proofs": "proofs"}

## Counts that read files (notes, the shelf) are read again at most this often (s).
const COUNT_EVERY := 2.0

var tab := 0
## Page id -> the page whose rows stand inline here.
var _inline := {}
var _notes := 0
var _shelf := 0
var _counted_at := -INF


static func make(i: int) -> DevPage:
	if TABS[i].id == &"story":
		return DevPageStory.new()
	var t := DevPageTab.new()
	t.tab = i
	return t


## A page by the id it has always had (--dev=PAGE, a key that goes straight to one).
static func page_for(id: StringName) -> DevPage:
	match id:
		&"go": return DevPageGo.new()
		&"time": return DevPageTime.new()
		&"body": return DevPageBody.new()
		&"give": return DevPageGive.new()
		&"spawn": return DevPageSpawn.new()
		&"view": return DevPageView.new()
		&"config": return DevPageConfig.new()
		&"story": return DevPageStory.new()
		&"notes": return DevPageNotes.new()
		&"builds": return DevPageBuilds.new()
		&"proofs": return DevPageProofs.new()
	# The story's own pages (people, path, ledger, words), so --dev can open one straight.
	return DevPageStory.page_for(id)


## Which tab holds a page id or a tab id, and how: {tab, how: &"tab" | &"inline" |
## &"door" | &"story"}, or {} for an id nothing holds.
static func tab_of(id: StringName) -> Dictionary:
	for i in TABS.size():
		var t: Dictionary = TABS[i]
		if t.id == id:
			return {"tab": i, "how": &"tab"}
		if (t.get("inline", []) as Array).has(id):
			return {"tab": i, "how": &"inline"}
		if (t.get("doors", []) as Array).has(id):
			return {"tab": i, "how": &"door"}
	if id == &"story":
		return {"tab": index_of(&"story"), "how": &"tab"}
	if DevPageStory.page_for(id) != null:
		return {"tab": index_of(&"story"), "how": &"story"}
	return {}


static func index_of(tab_id: StringName) -> int:
	for i in TABS.size():
		if TABS[i].id == tab_id:
			return i
	return -1


func heading() -> String:
	return str(TABS[tab].name)


## The page that owns a row on this tab, or null for the tab's own.
func owner_of(row: Dictionary) -> DevPage:
	return _inline.get(row.get("page", &""), null)


func _ensure() -> void:
	if game == null or not _inline.is_empty():
		return
	for id: StringName in TABS[tab].get("inline", []):
		var p := page_for(id)
		p.screen = screen
		p.game = game
		p.title = title
		_inline[id] = p


func rows() -> Array[Dictionary]:
	var t: Dictionary = TABS[tab]
	var out: Array[Dictionary] = []
	if bool(t.game) and game == null:
		out.append(item(&"no_game", "only in a game", "", {"enabled": false, "why": "This tab reads a running game. Play one, then `."}))
		return out
	_ensure()
	if not (t.get("doors", []) as Array).is_empty():
		out.append(header("pages"))
	for id: StringName in t.get("doors", []):
		var r := item(id, str(DOOR_NAMES.get(id, id)), _door_value(id))
		if id == &"builds" or id == &"proofs":
			r = local_only(r)
		if id == &"config":
			r["edited"] = not GameConfig.edits.is_empty()
		out.append(r)
	for id: StringName in t.get("inline", []):
		var p: DevPage = _inline[id]
		var own := p.rows()
		# The page's name heads its rows, joined to its own first group's where it
		# opens on one. A blank heading of its own only spaced its last rows off.
		var name := p.heading().to_lower()
		if own.is_empty() or not own[0].has("header"):
			out.append(header(name))
		for r: Dictionary in own:
			if r.has("header"):
				if str(r.header) != "":
					out.append(header("%s · %s" % [name, str(r.header)]))
				continue
			r["page"] = id
			out.append(r)
	if t.id == &"saves":
		out.append(header("this game"))
		out.append(item(&"saves", "the game's saves", _saves_value(), {"enabled": game != null, "why": "There is no game to save on the title."}))
		out.append(header("dev mode"))
		out.append(item(&"away", "put dev mode away", "", {"tone": "dev"}))
	return out


func confirm(row: Dictionary) -> void:
	var p := owner_of(row)
	if p != null:
		p.confirm(row)
		return
	match row.id:
		&"away":
			if DevMode.access() == &"open":
				refuse("This configuration keeps dev mode open.")
				return
			DevMode.disarm()
			Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
			screen.close()
			return
		&"saves":
			screen.open_app(&"saves")
			return
	var door := page_for(row.id)
	if door != null:
		screen.push_page(door)


## Left and right change a row that steps; on any other row they move along the
## strip, which is what a tab's arrows are for.
func side(row: Dictionary, dir: int) -> void:
	var p := owner_of(row)
	if p != null and bool(row.get("steps", false)):
		p.side(row, dir)
		return
	screen.step_tab(dir)


func step(delta: float) -> void:
	for id: StringName in _inline:
		(_inline[id] as DevPage).step(delta)


func keys(row: Dictionary) -> Array:
	var p := owner_of(row)
	if p != null:
		var out: Array = p.keys(row)
		if not bool(row.get("steps", false)):
			out.insert(out.size() - 1, ["a d", "tabs"])
		return out
	return [["e", "open"], ["a d  [ ]", "tabs"], ["`", "shut"]]


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var p := owner_of(screen.menu.selected())
	if p != null:
		p.detail(ci, r)
	else:
		_panel(ci, r)
	if TABS[tab].id == &"look" and game != null:
		_speed(ci, r)


## What a frame costs, held at the foot of LOOK & SPEED's panel whatever row is
## chosen, so a change of quality or zoom is read against its cost at once.
func _speed(ci: CanvasItem, r: Rect2i) -> void:
	var y := r.end.y - 16 - 6 * UiTheme.LINE - 8
	y = panel_heading(ci, r, y, "speed", true)
	y = panel_pair(ci, r, y, "frame", DevReadout.frame_line())
	y = panel_pair(ci, r, y, "draws", str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))))
	y = panel_pair(ci, r, y, "objects", str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))))
	y = panel_pair(ci, r, y, "memory", "%d MB" % roundi(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	panel_pair(ci, r, y, "chunks due", str(game.view.pending()))


## What the app is on, where the player stands, what the frame costs and the keys.
func _panel(ci: CanvasItem, r: Rect2i) -> void:
	var y := r.position.y + 16
	y = panel_heading(ci, r, y, "this build", true)
	y = panel_pair(ci, r, y, "build", DevReadout.build_line())
	y = panel_pair(ci, r, y, "runs as", DevMode.host())
	y = panel_pair(ci, r, y, "config", DevReadout.config_line())
	y = panel_pair(ci, r, y, "dev mode", "%s%s" % [String(DevMode.access()), ", armed" if DevMode.armed and DevMode.access() == &"chord" else ""])
	if game != null:
		y += 12
		y = panel_heading(ci, r, y, "here")
		for pair: Array in DevReadout.pairs(game):
			y = panel_pair(ci, r, y, pair[0], pair[1])
	y += 12
	y = panel_heading(ci, r, y, "keys")
	for pair: Array in [["`", "this app, from anywhere"], ["[ ]", "the tabs"], ["f2", "a note, now"], ["f3", "the readout on the edge"], ["f4", "a picture, nothing of the slate"]]:
		# The cap is a line of type plus its rim, so it centres on the words beside
		# it at any size: one pixel up, not half the line.
		UiSlate.key_cap(ci, Vector2i(panel_x(r) + 8, y - 1), pair[0])
		UiDraw.text(ci, Vector2i(panel_x(r) + 52, y), pair[1], UiTheme.TEXT_DIM)
		y += UiTheme.LINE + 4


func _count() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _counted_at < COUNT_EVERY:
		return
	_counted_at = now
	_notes = DevNotes.list().size()
	_shelf = DevBuilds.shelf().size()


func _door_value(id: StringName) -> String:
	match id:
		&"go":
			return BiomeRegistry.at(game.world, game.player.pos).display_name.to_lower()
		&"give":
			return "%d carried" % game.inventory.items.size()
		&"config":
			return (GameConfig.active if GameConfig.active != "" else "none") + ("*" if not GameConfig.edits.is_empty() else "")
		&"notes":
			_count()
			return "%d kept" % _notes
		&"builds":
			_count()
			return _builds_value()
		&"proofs":
			return _proofs_value()
	return ""


func _saves_value() -> String:
	return "kept apart" if DevPlay.dev_started() else ""


func _builds_value() -> String:
	if not DevMode.local():
		return ""
	DevJobs.poll()
	if DevJobs.running() and str(DevJobs.job.kind) in ["make", "keep", "deploy", "prove"]:
		return "%s %ds" % [str(DevJobs.job.label), roundi(DevJobs.seconds())]
	return "%d on the shelf" % _shelf


func _proofs_value() -> String:
	if not DevMode.local():
		return ""
	if DevJobs.running() and str(DevJobs.job.kind) in ["gate", "tour", "tests", "canon"]:
		return "%s %ds" % [str(DevJobs.job.label), roundi(DevJobs.seconds())]
	for i in range(DevJobs.history.size() - 1, -1, -1):
		var h: Dictionary = DevJobs.history[i]
		if str(h.kind) in ["gate", "tour", "tests", "canon"]:
			return "%s %s" % [str(h.label), "ok" if int(h.code) == 0 else "failed"]
	return ""
