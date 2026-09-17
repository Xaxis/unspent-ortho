class_name UiReadsScreen
extends UiScreen
## The machine reads app (from home): what the stolen module picks up off the
## machines about, all of it in the module's violet. The list: every machine in
## reach, how far, which way, and how it is disposed to the player. The
## replacement sub-panel: the network's interference as a trace, a sweep of
## where they stand with the works the list names ticked on its rim, and the
## chosen read. The disposition package fills it through SlateFeeds (&"reads");
## until then it reads the mobs' own `hostile`.

## The first row of the list, one text line's clearance under the pane's title.
const LIST_TOP := UiSlate.LIST.position.y + 36
## The sweep is an instrument's picture, so it covers the share of the panel it
## always did: its radius is the old 52 at the device's own factor.
const RADAR_R := 156
## What each ground mark the machines leave is, said plainly.
const MARK_WORDS := {&"cut": "cut in rows", &"scorch": "burnt over", &"quarry": "benches cut", &"bores": "drilled through"}
## What each WORK is, said plainly. The page used to name only the mark, and on
## a coast where the four nearest works are all turf rows it read "cut in rows"
## four times over with four different arrows beside it — which is what a
## placeholder looks like. The work has a name of its own; this is it.
const WORK_WORDS := {
	&"turf_rows": "turf cut in rows", &"drained": "a fen drained", &"corridor": "a corridor cut through",
	&"clearcut": "the wood felled flat", &"burned_grove": "a grove burnt over", &"quarry": "benches cut in the rock",
	&"drill_field": "a field drilled through", &"slag": "slag run out", &"refinery": "a refinery burnt out",
	&"archive": "an archive burnt", &"intake": "a sea intake", &"hulk": "a hulk run aground",
	&"sea_wall": "a sea wall raised", &"bog_graves": "graves cut in the bog", &"fire_tower": "a fire tower",
	&"checkpoint": "a checkpoint", &"stack": "a stack", &"convoy": "a convoy left standing",
	&"iced_line": "a line iced up", &"shelter": "a shelter", &"cistern": "a cistern",
	&"dugout": "a dugout", &"graves": "graves in rows", &"stolen_light": "light stolen off a machine",
	&"pans": "pans ruled across the flat", &"breaking_yard": "a yard for breaking machines",
	&"closing_corridor": "a corridor closing over",
}
## Works listed when nothing living reads back: kinds, not repeats of one kind.
const WORKS_ROWS := 6
## How tall the ground read is: its heading, its rows, and the survey plot. The
## plot is a picture and keeps its size on the glass; the headings and the gaps
## are type, and came down with it.
const PLOT_H := 138
const WORKS_H := 28 + WORKS_ROWS * UiTheme.LINE + 24 + 28 + PLOT_H + 24
## Works strung along the machines' bearing: how many are plotted, and the
## shortest reach the plot is ever drawn to (tiles), so one work near the player
## does not put every tick on top of the middle.
const LINE_WORKS := 40
const LINE_REACH := 60.0
## How far off their bearing a work still counts as on it, in tiles: a tick's
## height is how near the line it was cut.
const LINE_BAND := 56.0

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
	var out := {"bearing": -1.0, "under": &"", "level": 0.0, "works": [], "kinds": 0, "underfoot": {}}
	if game == null or game.world == null:
		return out
	out.bearing = rad_to_deg(GenWorks.bearing(game.world.seed_value))
	var p := _player()
	var works: WorksMap = game.view.works if game.view != null else null
	if works != null:
		var each := {}
		for mark: StringName in WorksMap.CHANNEL:
			var v := works.at(floori(p.x), floori(p.y), int(WorksMap.CHANNEL[mark]))
			each[mark] = v
			if v > float(out.level):
				out.level = v
				out.under = mark
		out.underfoot = each
	# One row per KIND of work, the nearest of that kind, with how many of them
	# there are. Four rows of the same three words with four arrows told the
	# player nothing they could not read off one row.
	var by_kind := {}
	for lm in game.world.landmarks:
		if not lm.has("mark"):
			continue
		var at: Vector2 = lm.pos
		var kind := StringName(lm.get("kind", &""))
		var d := at.distance_to(p)
		var row: Dictionary = by_kind.get(kind, {})
		if row.is_empty() or d < float(row.dist):
			by_kind[kind] = {"kind": kind, "mark": StringName(lm.mark), "dist": d, "dir": at - p, "count": int(row.get("count", 0)) + 1}
		else:
			row.count = int(row.count) + 1
	var found: Array[Dictionary] = []
	for k: StringName in by_kind:
		found.append(by_kind[k])
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.dist) < float(b.dist))
	out.kinds = found.size()
	out.works = found.slice(0, WORKS_ROWS)
	out.line = along_bearing(p)
	return out


## Everything they did to this land, strung along the one bearing they did it
## on: each work's distance up or down that line from where the player stands,
## and how far off it that work lies. {reach: tiles, marks: [{at -1..1, off 0..1, mark}]}
##
## Read off the landmarks rather than sampled off the ground, because the ground
## at any one place is usually unmarked — a sampled trace read 0% at the spawn
## and the panel it filled was emptier than the glass it replaced.
func along_bearing(p: Vector2) -> Dictionary:
	var out := {"reach": LINE_REACH, "marks": []}
	if game == null or game.world == null:
		return out
	var u := Vector2.RIGHT.rotated(GenWorks.bearing(game.world.seed_value))
	var n := Vector2(-u.y, u.x)
	var raw: Array[Dictionary] = []
	var reach := LINE_REACH
	for lm in game.world.landmarks:
		if not lm.has("mark"):
			continue
		var d: Vector2 = (lm.pos as Vector2) - p
		raw.append({"t": d.dot(u), "off": absf(d.dot(n)), "mark": StringName(lm.mark)})
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a.t)) < absf(float(b.t)))
	raw = raw.slice(0, LINE_WORKS)
	for m in raw:
		reach = maxf(reach, absf(float(m.t)))
	var marks: Array[Dictionary] = []
	for m in raw:
		marks.append({"at": float(m.t) / reach, "off": clampf(float(m.off) / LINE_BAND, 0.0, 1.0), "mark": m.mark})
	out.reach = reach
	out.marks = marks
	return out


## The ground read as the page last took it (see `ground`), taken now if the
## page is drawn before it has ever been refreshed.
func soil() -> Dictionary:
	if _soil.is_empty():
		_soil = ground()
	return _soil


static func mark_words(mark: StringName) -> String:
	return String(MARK_WORDS.get(mark, String(mark)))


## What a work is called on the page: its own name, or what it left on the
## ground for a kind nobody has words for yet.
static func work_words(kind: StringName, mark: StringName) -> String:
	if WORK_WORDS.has(kind):
		return String(WORK_WORDS[kind])
	if kind != &"":
		return String(kind).replace("_", " ")
	return mark_words(mark)


func _draw() -> void:
	draw_frame()
	var L := UiSlate.LIST
	var R := UiSlate.SPARE
	UiSlate.title(self, L, "MACHINE READS", UiTheme.MACHINE[3])
	UiSlate.spare(self)
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 16
	var read := soil()
	UiDraw.text_right(self, right, L.position.y + 8, "DIST  DISPOSED" if not menu.rows.is_empty() else "TILES OFF", UiTheme.MACHINE[2])
	if menu.rows.is_empty():
		UiDraw.text(self, Vector2i(x0 + 4, LIST_TOP), "nothing living reads back", UiTheme.MACHINE[2])
		UiDraw.text(self, Vector2i(x0 + 4, LIST_TOP + UiTheme.LINE), "within %d tiles" % int(SlateFeeds.READ_RADIUS), UiTheme.MACHINE[2])
	# What they did to this land stands under whatever lives on it, whenever the
	# pane has the room. One machine in reach used to blank the whole ground
	# read and leave nine tenths of the list pane empty glass.
	var after_list := LIST_TOP + maxi(menu.rows.size(), 2) * UiTheme.LINE + 40
	if after_list + WORKS_H <= L.end.y - 8:
		_draw_works(read, x0, right, after_list)
	var lines := UiSlate.line_count(LIST_TOP, mini(after_list - 40, L.end.y - 8))
	keep_in_view(lines)
	for n in mini(lines, menu.rows.size() - scroll):
		var i := scroll + n
		var s: Dictionary = menu.rows[i].scan
		var top := UiSlate.line_top(LIST_TOP, n)
		var chosen := i == menu.index
		if chosen:
			UiSlate.row_bar(self, x0 - 8, right + 6, top, UiTheme.MACHINE[3])
		var d: Vector2 = (s.get("pos", Vector2.ZERO) as Vector2) - _player()
		_arrow(Vector2i(x0 + 12, top + 8), d)
		UiDraw.text(self, Vector2i(x0 + 32, top), String(s.get("name", "")), UiTheme.MACHINE[4] if chosen else UiTheme.MACHINE[3])
		UiDraw.text_right(self, right - 124, top, "%d" % roundi(d.length()), UiTheme.MACHINE[2])
		var disp := StringName(s.get("disposition", &""))
		UiDraw.text_right(self, right, top, String(disp), UiTheme.WARN if disp == &"hostile" else UiTheme.MACHINE[2])
	var px := R.position.x + UiSlate.MARGIN_L
	var rright := R.end.x - 24
	_draw_interference(Rect2i(px, R.position.y + 16, rright - px, 138))
	# The sweep sits low and wide: the facts beside it are four short lines, and
	# the pane used to end in a third of a page of empty glass under them.
	_draw_radar(Vector2i(px + RADAR_R + 12, R.position.y + 224 + RADAR_R), read)
	var chosen_scan: Dictionary = menu.selected().get("scan", {})
	var dx := px + RADAR_R * 2 + 48
	var dy := R.position.y + 156
	UiSlate.heading(self, Vector2i(dx, dy), "read" if not chosen_scan.is_empty() else "the ground", rright, UiTheme.MACHINE[2])
	if chosen_scan.is_empty():
		# No signature: the ground still is one. It was surveyed and cut.
		var facts: Array = [["survey", "%d degrees" % roundi(float(read.bearing))]]
		if StringName(read.under) != &"":
			facts.append(["underfoot", mark_words(StringName(read.under))])
		var works: Array = read.works
		if not works.is_empty():
			var w0: Dictionary = works[0]
			facts.append(["nearest", work_words(StringName(w0.get("kind", &"")), StringName(w0.mark))])
			facts.append(["", "%d tiles %s" % [roundi(float(w0.dist)), _bearing(w0.dir)]])
		facts.append(["kinds", "%d within reach" % int(read.get("kinds", 0))])
		facts.append(["signature", "none in reach"])
		for k in facts.size():
			UiDraw.text(self, Vector2i(dx, dy + 28 + k * UiTheme.LINE), facts[k][0], UiTheme.MACHINE[2])
			UiDraw.text(self, Vector2i(dx + 124, dy + 28 + k * UiTheme.LINE), facts[k][1], UiTheme.MACHINE[3])
	else:
		var d: Vector2 = (chosen_scan.get("pos", Vector2.ZERO) as Vector2) - _player()
		var facts := [
			["kind", String(chosen_scan.get("kind", ""))],
			["disposed", String(chosen_scan.get("disposition", ""))],
			["distance", "%d tiles" % roundi(d.length())],
			["bearing", _bearing(d)],
		]
		for k in facts.size():
			UiDraw.text(self, Vector2i(dx, dy + 28 + k * UiTheme.LINE), facts[k][0], UiTheme.MACHINE[2])
			UiDraw.text(self, Vector2i(dx + 124, dy + 28 + k * UiTheme.LINE), facts[k][1], UiTheme.WARN if facts[k][1] == "hostile" else UiTheme.MACHINE[3])
		var note := String(chosen_scan.get("note", ""))
		if note != "":
			UiSlate.wrapped(self, Vector2i(dx, dy + 28 + UiTheme.LINE * 4 + 8), rright - dx, note, UiTheme.MACHINE[2])
	draw_keys([["wasd", "choose"], ["esc", "back"]])


## What they did to this land, listed where the living signatures would be: one
## row per kind of work, the nearest of that kind, how many there are, how far
## and which way. Under it, their bearing drawn as the ground reads it.
func _draw_works(soil: Dictionary, x0: int, right: int, top: int) -> void:
	var works: Array = soil.works
	UiSlate.heading(self, Vector2i(x0, top), "what they did here", right, UiTheme.MACHINE[2])
	if works.is_empty():
		UiDraw.text(self, Vector2i(x0 + 4, top + 28), "unworked ground", UiTheme.MACHINE[2])
		return
	for i in works.size():
		var w: Dictionary = works[i]
		var y := top + 28 + i * UiTheme.LINE
		_arrow(Vector2i(x0 + 12, y + 8), w.dir)
		UiDraw.text(self, Vector2i(x0 + 32, y), work_words(StringName(w.get("kind", &"")), StringName(w.mark)), UiTheme.MACHINE[3])
		var n := int(w.get("count", 1))
		if n > 1:
			UiDraw.text_right(self, right - 52, y, "x%d" % n, UiTheme.MACHINE[2])
		UiDraw.text_right(self, right, y, "%d" % roundi(float(w.dist)), UiTheme.MACHINE[2])
	var by := top + 28 + works.size() * UiTheme.LINE + 4
	var kinds := int(soil.get("kinds", works.size()))
	if kinds > works.size():
		UiDraw.text(self, Vector2i(x0 + 32, by), "and %d more kinds of it" % (kinds - works.size()), UiTheme.MACHINE[2])
		by += UiTheme.LINE
	_draw_line_of_works(soil, x0, right, by + 12)


## Their survey bearing with everything they did to this land strung along it:
## each work a tick up or down the line from where the player stands, its height
## how far off the line it lies. A page whose lower half is empty glass has not
## said what it knows, and the one bearing is the plainest thing the module has
## to say about who did this.
func _draw_line_of_works(soil: Dictionary, x0: int, right: int, top: int) -> void:
	var line: Dictionary = soil.get("line", {})
	var marks: Array = line.get("marks", [])
	UiSlate.heading(self, Vector2i(x0, top), "their survey through here", right, UiTheme.MACHINE[2])
	var box := Rect2i(x0, top + 28, right - x0, PLOT_H)
	UiSlate.brackets(self, box, UiTheme.MACHINE[1], 12)
	if marks.is_empty():
		UiDraw.text(self, Vector2i(x0 + 12, box.position.y + (box.size.y - UiFont.SIZE) / 2), "nothing on it within reach", UiTheme.MACHINE[2])
		return
	var span := box.size.x - 36
	var mid_x := box.position.x + 18 + span / 2
	var base := box.position.y + box.size.y / 2
	# The line itself, ruled straight: it is theirs and it is exact. The two
	# faint rules either side of it are LINE_BAND: a tick reaching one was cut
	# right along their bearing, a short one lies well off it.
	var band := box.size.y / 2 - 12
	for x in range(box.position.x + 18, box.end.x - 15, 12):
		UiDraw.px(self, x, base - band, UiTheme.MACHINE[1])
		UiDraw.px(self, x, base + band, UiTheme.MACHINE[1])
	for x in range(box.position.x + 18, box.end.x - 15, UiBase.PITCH):
		UiDraw.px(self, x, base, UiTheme.MACHINE[1] if (x / UiBase.PITCH) % 2 == 0 else UiTheme.MACHINE[2])
	for m: Dictionary in marks:
		var x := mid_x + roundi(float(m.at) * span * 0.5)
		# Off the line is drawn as height: a work they cut right along it stands
		# tall, one they left to the side of it hangs near the rule.
		var h := 9 + roundi((1.0 - float(m.off)) * (box.size.y / 2 - 21))
		var up := float(m.at) >= 0.0
		var col := UiTheme.MACHINE[3] if float(m.off) < 0.25 else UiTheme.MACHINE[2]
		# A tick is a bar the eye has to catch, not a hairline rule.
		if up:
			UiDraw.rect(self, Rect2i(x, base - h, UiBase.PITCH, h), col)
			UiDraw.px(self, x, base - h - UiBase.PITCH, UiTheme.MACHINE[4])
		else:
			UiDraw.rect(self, Rect2i(x, base + UiBase.PITCH, UiBase.PITCH, h), col)
			UiDraw.px(self, x, base + h + UiBase.PITCH, UiTheme.MACHINE[4])
	# Where the player stands on it.
	UiDraw.rect(self, Rect2i(mid_x, base - 15, UiBase.PITCH, 30), Color(UiTheme.MACHINE[4], 0.4))
	UiDraw.rect(self, Rect2i(mid_x - 2, base - 2, 6, 6), UiTheme.MACHINE[4])
	var reach := roundi(float(line.get("reach", LINE_REACH)))
	UiDraw.text(self, Vector2i(box.position.x + 4, box.end.y + 2), "%d tiles behind" % reach, UiTheme.MACHINE[2])
	UiDraw.text_right(self, box.end.x - 4, box.end.y + 2, "%d on, surveyed along %d degrees" % [reach, roundi(float(soil.bearing))], UiTheme.MACHINE[2])


## The network's interference as a trace across the panel: flat and quiet when
## the machines pay no mind, jagged when they do; a broken line when nothing is read.
func _draw_interference(r: Rect2i) -> void:
	UiSlate.heading(self, r.position, "interference", r.end.x, UiTheme.MACHINE[2])
	var level := float(_feed.get("interference", -1.0))
	var box := Rect2i(r.position.x, r.position.y + 26, r.size.x, r.size.y - 26)
	UiSlate.brackets(self, box, UiTheme.MACHINE[1], 12)
	var mid := box.position.y + box.size.y / 2
	if level < 0.0:
		for x in range(box.position.x + 12, box.end.x - 12, 2 * UiBase.PITCH):
			if Rng.hash01(x / (6 * UiBase.PITCH), 0, 0, 0x1f7) < 0.7:
				UiDraw.px(self, x, mid, UiTheme.MACHINE[1])
		UiDraw.text_right(self, box.end.x - 16, box.position.y + 6, "NO NETWORK READ", UiTheme.MACHINE[2])
		return
	var amp := 1.0 + level * (box.size.y * 0.5 - 9.0)
	var frame := floori(_time * 12.0)
	var last := mid
	# The trace is stepped and ruled in the module's own pixels: its jaggedness and
	# its wave keep the size they had on the glass, which is why the noise is
	# bucketed and the wave divided rather than read per base pixel.
	for x in range(box.position.x + 9, box.end.x - 9, UiBase.PITCH):
		var n := Rng.hash01(x / (3 * UiBase.PITCH) + frame, 3, 0, 0x1f8) - 0.5
		var y := mid + roundi(n * 2.0 * amp * (0.5 + 0.5 * sin(x * 0.037 + _time * 1.7)))
		UiDraw.rect(self, Rect2i(x, mini(last, y), UiBase.PITCH, absi(y - last) + UiBase.PITCH), UiTheme.MACHINE[3] if level < UiRules.PRESSURE_WARN else UiTheme.WARN)
		last = y
	UiDraw.text_right(self, box.end.x - 8, box.position.y + 4, "%d%%  %s" % [roundi(level * 100.0), String(_feed.get("network", ""))], UiTheme.MACHINE[3])


## Where the machines stand, north up, the player in the middle, a sweep going
## round — and, on the rim, which way the works the page lists lie, since they
## are tens of tiles off and an instrument that plots nothing under a list of
## four reads as a broken one.
func _draw_radar(c: Vector2i, read: Dictionary) -> void:
	# One dot of the module's glass every `steps`th of the way round: the count is
	# the ring's radius, which keeps the dots as far apart on the glass as they
	# were while each of them is a finer pixel than it was.
	for ring: int in [RADAR_R, RADAR_R / 2]:
		var steps := ring
		for k in steps:
			if k % 2 == 1:
				continue
			var a := k * TAU / steps
			UiDraw.px(self, c.x + roundi(cos(a) * ring), c.y + roundi(sin(a) * ring), UiTheme.MACHINE[1])
	UiDraw.rect(self, Rect2i(c.x - 5, c.y - 1, 10, UiBase.PITCH), UiTheme.MACHINE[2])
	UiDraw.rect(self, Rect2i(c.x - 1, c.y - 5, UiBase.PITCH, 10), UiTheme.MACHINE[2])
	var sweep := fposmod(_time * 1.2, TAU)
	for k in range(0, RADAR_R, UiBase.PITCH):
		UiDraw.px(self, c.x + roundi(cos(sweep) * k), c.y + roundi(sin(sweep) * k), Color(UiTheme.MACHINE[2], 0.6))
	var chosen: StringName = menu.selected().get("id", &"")
	for row: Dictionary in menu.rows:
		var s: Dictionary = row.scan
		var d: Vector2 = ((s.get("pos", Vector2.ZERO) as Vector2) - _player()) / SlateFeeds.READ_RADIUS * RADAR_R
		if d.length() > RADAR_R:
			continue
		var p := c + Vector2i(roundi(d.x), roundi(d.y))
		var hostile := StringName(s.get("disposition", &"")) == &"hostile"
		UiDraw.rect(self, Rect2i(p.x - 2, p.y - 2, 6, 6), UiTheme.WARN if hostile else UiTheme.MACHINE[3])
		if row.id == chosen:
			UiSlate.brackets(self, Rect2i(p.x - 8, p.y - 8, 18, 18), UiTheme.MACHINE[4], 4)
	_draw_works_beyond(c, read)
	UiDraw.text_centred(self, c.x, c.y - RADAR_R - 20, "N", UiTheme.MACHINE[2])


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
			UiSlate.brackets(self, Rect2i(q.x - 4, q.y - 4, 10, 10), UiTheme.MACHINE[2], 4)
			continue
		beyond += 1
		# A tick pointing out of the sweep, brightest at its far end: that way,
		# and further than the module can read.
		for k in range(RADAR_R + 9, RADAR_R + 27, UiBase.PITCH):
			UiDraw.px(self, c.x + roundi(u.x * k), c.y + roundi(u.y * k), UiTheme.MACHINE[2] if k < RADAR_R + 21 else UiTheme.MACHINE[3])
	if beyond > 0:
		UiDraw.text(self, Vector2i(c.x - RADAR_R, c.y + RADAR_R + 24), "%d work%s beyond reach" % [beyond, "" if beyond == 1 else "s"], UiTheme.MACHINE[2])


## A 7x7 arrow pointing along `d` (north up), cut in the module's own pixels: it
## is drawn beside a word, so it is type-sized and every step is one PITCH.
func _arrow(c: Vector2i, d: Vector2) -> void:
	var p := UiBase.PITCH
	if d.length() < 0.01:
		UiDraw.rect(self, Rect2i(c.x - p, c.y - p, 3 * p, 3 * p), UiTheme.MACHINE[2])
		return
	var u := d.normalized()
	for k in range(-3, 4):
		UiDraw.px(self, c.x + roundi(u.x * k * p), c.y + roundi(u.y * k * p), UiTheme.MACHINE[2])
	var tip := c + Vector2i(roundi(u.x * 3.0 * p), roundi(u.y * 3.0 * p))
	var back := u.rotated(PI * 0.75) * 2.0 * p
	var back2 := u.rotated(-PI * 0.75) * 2.0 * p
	UiDraw.px(self, tip.x + roundi(back.x), tip.y + roundi(back.y), UiTheme.MACHINE[3])
	UiDraw.px(self, tip.x + roundi(back2.x), tip.y + roundi(back2.y), UiTheme.MACHINE[3])


static func _bearing(d: Vector2) -> String:
	if d.length() < 0.5:
		return "here"
	const NAMES := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return NAMES[posmod(roundi(d.angle() / (TAU / 8.0)), 8)]
