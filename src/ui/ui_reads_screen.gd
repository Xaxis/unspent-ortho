class_name UiReadsScreen
extends UiScreen
## The machine reads app (from home): what the stolen module picks up off the
## machines about, all of it in the module's violet. The list: every machine in
## reach, how far, which way, and how it is disposed to the player. The
## replacement sub-panel: the network's interference as a trace, a sweep of
## where they stand with the works the list names ticked on its rim, and the
## chosen read. The disposition package fills it through SlateFeeds (&"reads");
## until then it reads the mobs' own `hostile`.

const LIST_TOP := 50
const RADAR_R := 44
## What each ground mark the machines leave is, said plainly.
const MARK_WORDS := {&"cut": "cut in rows", &"scorch": "burnt over", &"quarry": "benches cut", &"bores": "drilled through"}
## Works listed when nothing living reads back.
const WORKS_ROWS := 4

var _feed: Dictionary = {}
var _time := 0.0
## The ground read, taken with the list (twice a second) and not per frame: it
## walks every landmark in the world and sorts them.
var _soil: Dictionary = {}


func _init() -> void:
	super()
	screen_name = &"reads"
	own_action = &""


func refresh() -> void:
	_feed = SlateFeeds.feed(&"reads", game)
	_soil = ground()
	var rows: Array[Dictionary] = []
	for s: Dictionary in _feed.get("scans", []):
		rows.append({"id": StringName(s.get("id", &"")), "scan": s})
	menu.set_rows(rows)
	queue_redraw()


func _on_confirm(row: Dictionary) -> void:
	var said := SlateFeeds.act(&"reads", game, row.id)
	if said.begins_with("!"):
		refuse(said.substr(1))
	elif said != "":
		Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
		say(said)


func _process(delta: float) -> void:
	super(delta)
	if is_open:
		_time += delta
		# The trace and the sweep move; the list is read again twice a second.
		if floori(_time * 2.0) != floori((_time - delta) * 2.0):
			refresh()
		queue_redraw()


func _player() -> Vector2:
	return game.player.pos if game != null else Vector2.ZERO


## The read that comes back everywhere, on the first day, with no machine in
## sight: the one bearing the machines surveyed this land along, the mark they
## left under the player's feet, and the works they left near. A slate that
## can only ever say "nothing reads back" is a dead screen; the ground is
## machine-written evidence, and the stolen module can read it.
##   {bearing: degrees or -1, under: mark or &"", level: 0..1,
##    works: [{mark, dist, dir}] nearest first}
func ground() -> Dictionary:
	var out := {"bearing": -1.0, "under": &"", "level": 0.0, "works": []}
	if game == null or game.world == null:
		return out
	out.bearing = rad_to_deg(GenWorks.bearing(game.world.seed_value))
	var p := _player()
	var works: WorksMap = game.view.works if game.view != null else null
	if works != null:
		for mark: StringName in WorksMap.CHANNEL:
			var v := works.at(floori(p.x), floori(p.y), int(WorksMap.CHANNEL[mark]))
			if v > float(out.level):
				out.level = v
				out.under = mark
	var found: Array[Dictionary] = []
	for lm in game.world.landmarks:
		if not lm.has("mark"):
			continue
		var at: Vector2 = lm.pos
		found.append({"mark": StringName(lm.mark), "dist": at.distance_to(p), "dir": at - p})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.dist) < float(b.dist))
	out.works = found.slice(0, WORKS_ROWS)
	return out


## The ground read as the page last took it (see `ground`), taken now if the
## page is drawn before it has ever been refreshed.
func soil() -> Dictionary:
	if _soil.is_empty():
		_soil = ground()
	return _soil


static func mark_words(mark: StringName) -> String:
	return String(MARK_WORDS.get(mark, String(mark)))


func _draw() -> void:
	draw_frame()
	var L := UiSlate.LIST
	var R := UiSlate.SPARE
	UiSlate.title(self, L, "MACHINE READS", UiTheme.MACHINE[3])
	UiSlate.spare(self)
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 8
	var read := soil()
	UiDraw.text_right(self, right, L.position.y + 4, "DIST  DISPOSED" if not menu.rows.is_empty() else "TILES OFF", UiTheme.MACHINE[2])
	if menu.rows.is_empty():
		UiDraw.text(self, Vector2i(x0 + 2, LIST_TOP), "nothing living reads back", UiTheme.MACHINE[2])
		UiDraw.text(self, Vector2i(x0 + 2, LIST_TOP + 11), "within %d tiles" % int(SlateFeeds.READ_RADIUS), UiTheme.MACHINE[2])
		_draw_works(read, x0, right, LIST_TOP + 30)
	var lines := UiSlate.line_count(LIST_TOP, L.end.y - 4)
	keep_in_view(lines)
	for n in mini(lines, menu.rows.size() - scroll):
		var i := scroll + n
		var s: Dictionary = menu.rows[i].scan
		var top := UiSlate.line_top(LIST_TOP, n)
		var chosen := i == menu.index
		if chosen:
			UiSlate.row_bar(self, x0 - 4, right + 3, top, UiTheme.MACHINE[3])
		var d: Vector2 = (s.get("pos", Vector2.ZERO) as Vector2) - _player()
		_arrow(Vector2i(x0 + 6, top + 4), d)
		UiDraw.text(self, Vector2i(x0 + 16, top), String(s.get("name", "")), UiTheme.MACHINE[4] if chosen else UiTheme.MACHINE[3])
		UiDraw.text_right(self, right - 62, top, "%d" % roundi(d.length()), UiTheme.MACHINE[2])
		var disp := StringName(s.get("disposition", &""))
		UiDraw.text_right(self, right, top, String(disp), UiTheme.WARN if disp == &"hostile" else UiTheme.MACHINE[2])
	var px := R.position.x + UiSlate.MARGIN_L
	var rright := R.end.x - 12
	_draw_interference(Rect2i(px, R.position.y + 8, rright - px, 46))
	_draw_radar(Vector2i(px + RADAR_R + 4, R.position.y + 82 + RADAR_R), read)
	var chosen_scan: Dictionary = menu.selected().get("scan", {})
	var dx := px + RADAR_R * 2 + 20
	var dy := R.position.y + 78
	UiSlate.heading(self, Vector2i(dx, dy), "read" if not chosen_scan.is_empty() else "the ground", rright, UiTheme.MACHINE[2])
	if chosen_scan.is_empty():
		# No signature: the ground still is one. It was surveyed and cut.
		var facts: Array = [["survey", "%d degrees" % roundi(float(read.bearing))]]
		if StringName(read.under) != &"":
			facts.append(["underfoot", mark_words(StringName(read.under))])
		var works: Array = read.works
		if not works.is_empty():
			var w0: Dictionary = works[0]
			facts.append(["nearest", "%s, %d %s" % [mark_words(StringName(w0.mark)), roundi(float(w0.dist)), _bearing(w0.dir)]])
		facts.append(["signature", "none in reach"])
		for k in facts.size():
			UiDraw.text(self, Vector2i(dx, dy + 14 + k * 11), facts[k][0], UiTheme.MACHINE[2])
			UiDraw.text(self, Vector2i(dx + 52, dy + 14 + k * 11), facts[k][1], UiTheme.MACHINE[3])
	else:
		var d: Vector2 = (chosen_scan.get("pos", Vector2.ZERO) as Vector2) - _player()
		var facts := [
			["kind", String(chosen_scan.get("kind", ""))],
			["disposed", String(chosen_scan.get("disposition", ""))],
			["distance", "%d tiles" % roundi(d.length())],
			["bearing", _bearing(d)],
		]
		for k in facts.size():
			UiDraw.text(self, Vector2i(dx, dy + 14 + k * 11), facts[k][0], UiTheme.MACHINE[2])
			UiDraw.text(self, Vector2i(dx + 52, dy + 14 + k * 11), facts[k][1], UiTheme.WARN if facts[k][1] == "hostile" else UiTheme.MACHINE[3])
		var note := String(chosen_scan.get("note", ""))
		if note != "":
			UiSlate.wrapped(self, Vector2i(dx, dy + 62), rright - dx, note, UiTheme.MACHINE[2])
	draw_keys([["wasd", "choose"], ["esc", "back"]])


## What they did to this land, listed where the living signatures would be: the
## works nearest the player, each with how far and which way.
func _draw_works(soil: Dictionary, x0: int, right: int, top: int) -> void:
	var works: Array = soil.works
	UiSlate.heading(self, Vector2i(x0, top), "what they did here", right, UiTheme.MACHINE[2])
	if works.is_empty():
		UiDraw.text(self, Vector2i(x0 + 2, top + 14), "unworked ground", UiTheme.MACHINE[2])
		return
	for i in works.size():
		var w: Dictionary = works[i]
		var y := top + 14 + i * UiTheme.LINE
		_arrow(Vector2i(x0 + 6, y + 4), w.dir)
		UiDraw.text(self, Vector2i(x0 + 16, y), mark_words(StringName(w.mark)), UiTheme.MACHINE[3])
		UiDraw.text_right(self, right, y, "%d" % roundi(float(w.dist)), UiTheme.MACHINE[2])
	var by := top + 14 + works.size() * UiTheme.LINE + 4
	UiDraw.text(self, Vector2i(x0 + 2, by), "all of it on one bearing: %d degrees" % roundi(float(soil.bearing)), UiTheme.MACHINE[2])


## The network's interference as a trace across the panel: flat and quiet when
## the machines pay no mind, jagged when they do; a broken line when nothing is read.
func _draw_interference(r: Rect2i) -> void:
	UiSlate.heading(self, r.position, "interference", r.end.x, UiTheme.MACHINE[2])
	var level := float(_feed.get("interference", -1.0))
	var box := Rect2i(r.position.x, r.position.y + 13, r.size.x, r.size.y - 13)
	UiSlate.brackets(self, box, UiTheme.MACHINE[1], 4)
	var mid := box.position.y + box.size.y / 2
	if level < 0.0:
		for x in range(box.position.x + 4, box.end.x - 4, 2):
			if Rng.hash01(x / 6, 0, 0, 0x1f7) < 0.7:
				UiDraw.px(self, x, mid, UiTheme.MACHINE[1])
		UiDraw.text_right(self, box.end.x - 8, box.position.y + 3, "NO NETWORK READ", UiTheme.MACHINE[2])
		return
	var amp := 1.0 + level * (box.size.y * 0.5 - 3.0)
	var frame := floori(_time * 12.0)
	var last := mid
	for x in range(box.position.x + 3, box.end.x - 3):
		var n := Rng.hash01(x / 2 + frame, 3, 0, 0x1f8) - 0.5
		var y := mid + roundi(n * 2.0 * amp * (0.5 + 0.5 * sin(x * 0.11 + _time * 1.7)))
		UiDraw.vline(self, x, mini(last, y), maxi(last, y), UiTheme.MACHINE[3] if level < UiRules.PRESSURE_WARN else UiTheme.WARN)
		last = y
	UiDraw.text_right(self, box.end.x - 4, box.position.y + 2, "%d%%  %s" % [roundi(level * 100.0), String(_feed.get("network", ""))], UiTheme.MACHINE[3])


## Where the machines stand, north up, the player in the middle, a sweep going
## round — and, on the rim, which way the works the page lists lie, since they
## are tens of tiles off and an instrument that plots nothing under a list of
## four reads as a broken one.
func _draw_radar(c: Vector2i, read: Dictionary) -> void:
	for ring: int in [RADAR_R, RADAR_R / 2]:
		var steps := ring * 3
		for k in steps:
			if k % 2 == 1:
				continue
			var a := k * TAU / steps
			UiDraw.px(self, c.x + roundi(cos(a) * ring), c.y + roundi(sin(a) * ring), UiTheme.MACHINE[1])
	UiDraw.hline(self, c.x - 2, c.x + 2, c.y, UiTheme.MACHINE[2])
	UiDraw.vline(self, c.x, c.y - 2, c.y + 2, UiTheme.MACHINE[2])
	var sweep := fposmod(_time * 1.2, TAU)
	for k in RADAR_R:
		UiDraw.px(self, c.x + roundi(cos(sweep) * k), c.y + roundi(sin(sweep) * k), Color(UiTheme.MACHINE[2], 0.6))
	var chosen: StringName = menu.selected().get("id", &"")
	for row: Dictionary in menu.rows:
		var s: Dictionary = row.scan
		var d: Vector2 = ((s.get("pos", Vector2.ZERO) as Vector2) - _player()) / SlateFeeds.READ_RADIUS * RADAR_R
		if d.length() > RADAR_R:
			continue
		var p := c + Vector2i(roundi(d.x), roundi(d.y))
		var hostile := StringName(s.get("disposition", &"")) == &"hostile"
		UiDraw.rect(self, Rect2i(p.x - 1, p.y - 1, 3, 3), UiTheme.WARN if hostile else UiTheme.MACHINE[3])
		if row.id == chosen:
			UiSlate.brackets(self, Rect2i(p.x - 4, p.y - 4, 9, 9), UiTheme.MACHINE[4], 2)
	_draw_works_beyond(c, read)
	UiDraw.text(self, Vector2i(c.x - 2, c.y - RADAR_R - 10), "N", UiTheme.MACHINE[2])


## The works the page lists, as a tick on the rim at the bearing they lie on: a
## ground mark is not a live signature and cannot be plotted inside the sweep,
## but which way the machines went at this land is worth the instrument saying.
## One close enough to stand in the sweep is drawn where it is, hollow.
func _draw_works_beyond(c: Vector2i, read: Dictionary) -> void:
	var works: Array = read.get("works", [])
	if works.is_empty():
		return
	var beyond := 0
	for w: Dictionary in works:
		var d: Vector2 = w.dir
		if d.length() < 0.01:
			continue
		var u := d.normalized()
		var dist := float(w.dist)
		if dist <= SlateFeeds.READ_RADIUS:
			var q := c + Vector2i(roundi(u.x * dist / SlateFeeds.READ_RADIUS * RADAR_R), roundi(u.y * dist / SlateFeeds.READ_RADIUS * RADAR_R))
			UiSlate.brackets(self, Rect2i(q.x - 2, q.y - 2, 5, 5), UiTheme.MACHINE[2], 2)
			continue
		beyond += 1
		# A tick pointing out of the sweep, brightest at its far end: that way,
		# and further than the module can read.
		for k in range(RADAR_R + 3, RADAR_R + 9):
			UiDraw.px(self, c.x + roundi(u.x * k), c.y + roundi(u.y * k), UiTheme.MACHINE[2] if k < RADAR_R + 7 else UiTheme.MACHINE[3])
	if beyond > 0:
		UiDraw.text(self, Vector2i(c.x - RADAR_R, c.y + RADAR_R + 12), "%d work%s beyond reach" % [beyond, "" if beyond == 1 else "s"], UiTheme.MACHINE[2])


## A 7x7 arrow pointing along `d` (north up).
func _arrow(c: Vector2i, d: Vector2) -> void:
	if d.length() < 0.01:
		UiDraw.rect(self, Rect2i(c.x - 1, c.y - 1, 3, 3), UiTheme.MACHINE[2])
		return
	var u := d.normalized()
	for k in range(-3, 4):
		UiDraw.px(self, c.x + roundi(u.x * k), c.y + roundi(u.y * k), UiTheme.MACHINE[2])
	var tip := c + Vector2i(roundi(u.x * 3.0), roundi(u.y * 3.0))
	var back := u.rotated(PI * 0.75) * 2.0
	var back2 := u.rotated(-PI * 0.75) * 2.0
	UiDraw.px(self, tip.x + roundi(back.x), tip.y + roundi(back.y), UiTheme.MACHINE[3])
	UiDraw.px(self, tip.x + roundi(back2.x), tip.y + roundi(back2.y), UiTheme.MACHINE[3])


static func _bearing(d: Vector2) -> String:
	if d.length() < 0.5:
		return "here"
	const NAMES := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return NAMES[posmod(roundi(d.angle() / (TAU / 8.0)), 8)]
