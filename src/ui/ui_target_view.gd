class_name UiTargetView
extends CanvasLayer
## What targeting draws (owner, 2026-09-16): the tag every body carries, the
## brackets and ring on the one being read, and the slate's read of it.
##
## Two tiers, so a fight is not covered in words:
##   always   every body on screen carries a wordless tag — health pips and one
##            glyph for how much it has noticed the player
##   held     what is locked is bracketed and ringed, and the slate says in
##            words what it is, what it can do, what it has noticed and what it
##            is thinking; a sweep says the short of it for a page of the field
##
## A person is read too, and reads as a person: no pips, no signature, no notice
## glyph. Nothing in the fight knows a villager, so a tag over one would be a
## number nobody took — they carry none, and words only while the key is held.
##
## Machine-sourced data is the stolen module's violet (docs/LOOK.md); what the
## player reads off a living creature with their own eyes is the slate's
## phosphor, since the module reads no creature's signature (SlateFeeds).

## The tag: pips PIP_W wide with a gap, then the notice glyph.
const PIP_W := 4
const PIP_H := 8
const PIP_GAP := 2
const GLYPH := 10
const TAG_LIFT := 10
## Air between the strip of glass the pips sit on and the notice chip: they are
## TWO salvaged parts taped near each other, not one sprite.
const TAG_GAP := 6
## What the tag is made of (docs/LOOK.md; A2 art finding 2).
##
## What was here was an opaque UiTheme.RIM lozenge behind every body on screen.
## Measured: its darkest pixels sat at luminance 7.3 when nothing else in the
## frame went below 12, and its pips read 161 against a frame mean of 52. It was
## in the slate's COLOURS but not in its CONSTRUCTION — no bezel, no scrap, no
## tape, no grain — so it was a small black HUD sprite standing in the world,
## which is the charge the scan ring was convicted on.
##
## So the backing is the slate's own GLASS at TAG_GLASS alpha, never RIM and
## never opaque: over pure black it still lands near 13, so the tag can no longer
## cut a hole in a frame. Under it runs a rail of the bezel's own dull phosphor
## with a screw at each end, its ends stepped in like a torn strip of tape, and a
## few stuck pixels of grain sit on the glass. The notice glyph gets a chip of
## its own, because an indicator lamp on the slate is a separate part.
##
## **TAG_GLASS answers to `lit`, and it was solved rather than chosen.**
##
## The binding ink is `MACHINE[2]` and that is the whole of why this number moved:
## a tag is drawn in the paler `MACHINE[3]` only while its body is the one being
## READ, so what is over the shoulder of every machine the player has not locked
## is the darker step. At 0.55, composited over a white ground, that came out at
## **1.92:1** — over snow at noon the tag was, in plain terms, not there — and
## `lit` has since added hearths, lamps and a machine's own lens to the list of
## bright things that can stand behind a body, so it now flickers in and out of
## legibility as a lamp sweeps past, which is worse than being always faint.
##
## The bar is **3:1, not 4.5:1**, because the tag is WORDLESS by the pillar in
## docs/LOOK.md — pips and one glyph, never a word — and 3:1 is the bar a
## non-text indicator is held to. At the value below the three inks land at
## 3.8:1 (a machine), 6.7:1 (the one being read) and 8.7:1 (a creature) against
## white, and measured in a real noon frame at seed 3 the machine's pips came out
## at 4.1:1 against a ground of luminance 0.52.
##
## The other end still holds: over black the tag's brightest channel is 19 of 255,
## inside the range a lit night frame already uses (23.6% of its pixels sit under
## 24), so it cuts no hole in the picture. `tests/ui/test_tag_reads.gd` solves
## both ends again from the colours, so neither this number nor the phosphor can
## be retuned into the dark without the gate saying so.
const TAG_GLASS := 0.90
const TAG_RAIL := 0.85
## The read panel on the right edge, under the clock.
const PANEL := Rect2i(1314, 138, 582, 300)
const SWEEP_PANEL := Rect2i(1314, 138, 582, 264)
## Rows of the read, at most, so the panel never pushes a line off its own glass.
const STATS_MOST := 5
const POWERS_MOST := 2
## The read's own furniture: the title, the pips line, and the two anchored lines
## at the foot (what it has noticed, what it is doing) with the keys under them.
const READ_HEAD := 54
## One line of text on this glass, for anything laid under the title (the
## testimony) so the panel grows by what it says rather than by a number.
const READ_LINE := UiTheme.LINE
const READ_FOOT := 80
## Clear air between the last row and the rule above the anchored lines: without
## it a body with everything to say had its last power struck through by that rule.
const READ_GAP := 10
## A body further than this from the player is tagged but never named.
const NAME_REACH := 14.0
## A person's ring, since a villager carries no roster radius.
const PERSON_RADIUS := 0.5
## The scan line that runs down a locked body's brackets (seconds).
const SCAN_SECONDS := 1.3

var game: Game
var _canvas: Control
var _t := 0.0


func _ready() -> void:
	layer = 11
	_canvas = Control.new()
	_canvas.name = "marks"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.theme = UiTheme.theme()
	_canvas.draw.connect(_draw_marks)
	add_child(_canvas)


func _process(delta: float) -> void:
	_t += delta
	_canvas.queue_redraw()


func _system() -> Node:
	return get_parent()


## Where a thing stands on the glass: the ground under it, and the top of it.
func _screen_at(pos: Vector2, height: float) -> Array:
	var cam := game.camera
	var base := game.world.to_3d(pos)
	var top := base + Vector3(0.0, height, 0.0)
	# `unproject_position` answers in the base's own pixels, which is what this
	# layer draws in, so there is nothing to convert (`UiBase.to_design`).
	return [cam.unproject_position(base).round(), cam.unproject_position(top).round()]


func _screen_of(m: MobState) -> Array:
	return _screen_at(m.pos, float(m.row.get("height", 1.0)))


func _on_glass(p: Vector2) -> bool:
	return Rect2(UiBase.screen()).grow(120.0).has_point(p)


## The stolen module's violet for a machine's signature, the slate's phosphor for
## a creature read by eye. Never the palest step: a tag over the world has to sit
## under the words the slate says, not over them (docs/LOOK.md).
func _ink(machine: bool, lit: bool = true) -> Color:
	if machine:
		return UiTheme.MACHINE[3] if lit else UiTheme.MACHINE[2]
	return UiTheme.TEXT if lit else UiTheme.TEXT_DIM


func _draw_marks() -> void:
	if game == null or game.world == null or game.player == null or game.camera == null:
		return
	if not game.open_screens.is_empty() or not game.camera.is_inside_tree():
		return
	var sim := game.player.sim
	if sim == null:
		return
	var sys := _system()
	var locked: TargetSubject = sys.get("locked")
	var field: Array = sys.get("field")
	var now := sim.now
	# Only what is in the fight carries a tag. A villager has no health and nothing
	# has noticed them, so pips over a person would be a number nobody read.
	for m in sim.mobs:
		if not m.alive or m.removed:
			continue
		# A MACHINE THAT PASSES carries none either (roster `passes`), and this is
		# NOT a hole in the pillar — it is the line above applied honestly. The tag
		# marks what can hurt you, and a passer is never in the fight: it has no
		# bite and no hits, `Roles.FILES` holds `watcher` so `Disposition.of`
		# answers observant at every interference level and however disturbed, and
		# `Roles.TURNS[&"watcher"]` is empty, so nothing the player does turns it.
		# That is not argued, it is provoked and measured:
		# `test_a_passer_never_joins_the_fight_however_hard_it_is_provoked` stands
		# one under the knife until it dies and watches every slice for a mood or
		# a blow. Never roused, never a blow, never hostile. So the exception is
		# UNCONDITIONAL — there is no transition at which the tag becomes owed,
		# and if a passer is ever given a bite this rule must go with it.
		#
		# Why it matters: the body's whole nature is that you cannot tell what it
		# is without putting the slate on it, and in a street of thirty people who
		# carry no tags, two floating pip bars answer that for free and for ever.
		# Measured in a real frame — the crowd was indistinguishable, the tags
		# were not. It is still locked, bracketed and read like anything else.
		if m.row.get("passes", false):
			continue
		var at := _screen_of(m)
		if not _on_glass(at[1]):
			continue
		_draw_tag(m, at[1], TargetRead.tag(m, now), locked != null and locked.body == m)
	if locked != null:
		_draw_lock(locked)
		_draw_read(sys.get("read"))
	elif bool(sys.get("sweeping")):
		_draw_sweep(sys.get("rows"), field, int(sys.get("page")), int(sys.get("pages")))


## The wordless tag above a body: its health in pips, and one glyph for how far
## it has got with the player (nothing, stirring, sure, coming). No words, ever —
## that is the pillar a fight is read by, and the words wait for the key.
func _draw_tag(m: MobState, top: Vector2, tag: Dictionary, lit: bool) -> void:
	var pips: Array = tag.pips
	var machine := bool(tag.machine)
	var bar := TargetRead.PIPS * (PIP_W + PIP_GAP) - PIP_GAP
	var width := bar + TAG_GAP + GLYPH + 4
	var x := int(top.x) - width / 2
	var y := int(top.y) - TAG_LIFT - PIP_H
	var full := int(pips[0])
	var part := float(pips[1])
	var plate := Rect2i(x - 4, y - 4, bar + 8, PIP_H + 6)
	_strip(plate, int(m.pos.x) * 31 + int(m.pos.y))
	# The wire from the strip to the notice lamp: two parts, joined the way
	# everything on this device is joined.
	UiDraw.rect(_canvas, Rect2i(plate.end.x, y + 2, TAG_GAP, UiBase.PITCH), Color(UiTheme.FAINT, 0.9))
	for i in TargetRead.PIPS:
		var cell := Rect2i(x + i * (PIP_W + PIP_GAP), y, PIP_W, PIP_H)
		var col := UiTheme.GHOST
		if i < full:
			col = _ink(machine, lit)
		elif i == full and part > 0.25:
			col = UiTheme.MACHINE[2] if machine else UiTheme.TEXT_DIM
		UiDraw.rect(_canvas, cell, col)
	_draw_notice(Vector2i(x + bar + TAG_GAP + 2, y - 2), int(tag.notice), machine, lit)


## A strip of the slate's glass with its own bezel: the ends stepped in like torn
## tape, a rail of dull phosphor under it with a screw at each end, and a stuck
## pixel or two of grain on the glass. Never opaque, never square-cornered.
func _strip(r: Rect2i, grain_seed: int) -> void:
	var glass := Color(UiTheme.GLASS, TAG_GLASS)
	var p := UiBase.PITCH
	UiDraw.rect(_canvas, Rect2i(r.position.x, r.position.y + p, r.size.x, r.size.y - p), glass)
	# Torn, not cut: the top edge is short at one end and the strip is one pixel
	# longer at the other, so no two of its four corners agree.
	var tear := (1 + int(Rng.hash01(grain_seed, 1) * 2.0)) * p
	UiDraw.rect(_canvas, Rect2i(r.position.x + tear, r.position.y, r.size.x - tear - p, p), glass)
	UiDraw.px(_canvas, r.end.x, r.position.y + 2 * p, glass)
	# The rail under it: the bezel's own dull phosphor, with a screw head at each
	# end. It is what the strip is held on by, and it is drawn over the world
	# rather than over the glass, so the tag has an edge without having a border.
	var rail := Color(UiTheme.FAINT, TAG_RAIL)
	UiDraw.rect(_canvas, Rect2i(r.position.x + p, r.end.y, r.size.x - 2 * p, p), rail)
	UiDraw.px(_canvas, r.position.x, r.end.y - p, rail)
	UiDraw.px(_canvas, r.end.x - p, r.end.y - p, rail)
	# Stuck pixels: this glass was cut out of something that was already failing
	# (UiSlate's dead column, at the only size this thing has room for).
	for i in 2:
		var gx := r.position.x + p + int(Rng.hash01(grain_seed, i, 3) * float(r.size.x - 2 * p))
		var gy := r.position.y + p + int(Rng.hash01(grain_seed, i, 4) * float(r.size.y - 2 * p))
		UiDraw.px(_canvas, gx, gy, Color(UiTheme.FAINT, 0.75))


## The notice glyph, 5x5: a hollow ring for a body that has noticed nothing, a
## ring with a point for one that is wondering, a filled one for a body that is
## sure, and a filled one with a chevron for one that is coming. On a chip of its
## own, because on the slate an indicator lamp is a separate salvaged part — and
## because the pips and this answer two different questions.
func _draw_notice(at: Vector2i, notice: int, machine: bool, lit: bool, chip: bool = true) -> void:
	var col := _ink(machine, lit) if notice > 0 else (UiTheme.MACHINE[2] if machine else UiTheme.TEXT_DIM)
	if notice >= 3:
		# Only the chevron keeps the alarm colour. A filled 5x5 in WARN was the
		# loudest thing on the glass and the tag is the quietest layer.
		col = UiTheme.WARN_DIM
	var p := UiBase.PITCH
	if chip:
		# A round lamp bezel: the corners cut off, so it is a lens and not a box.
		var g := Color(UiTheme.GLASS, TAG_GLASS)
		UiDraw.rect(_canvas, Rect2i(at.x - p, at.y, GLYPH + 2 * p, GLYPH), g)
		UiDraw.rect(_canvas, Rect2i(at.x, at.y - p, GLYPH, GLYPH + 2 * p), g)
		UiDraw.px(_canvas, at.x + 2 * p, at.y - 2 * p, Color(UiTheme.FAINT, 0.8))
		UiDraw.px(_canvas, at.x + 2 * p, at.y + GLYPH + p, Color(UiTheme.FAINT, 0.8))
	UiDraw.rect(_canvas, Rect2i(at.x + p, at.y, 3 * p, p), col)
	UiDraw.rect(_canvas, Rect2i(at.x + p, at.y + 4 * p, 3 * p, p), col)
	UiDraw.rect(_canvas, Rect2i(at.x, at.y + p, p, 3 * p), col)
	UiDraw.rect(_canvas, Rect2i(at.x + 4 * p, at.y + p, p, 3 * p), col)
	if notice == 1:
		UiDraw.px(_canvas, at.x + 2 * p, at.y + 2 * p, col)
	elif notice >= 2:
		UiDraw.rect(_canvas, Rect2i(at.x + p, at.y + p, 3 * p, 3 * p), col)
	if notice >= 3:
		# The chevron of something on its way to you: the one warm mark on the tag,
		# and the only thing here a player may never miss.
		for k in 3:
			UiDraw.px(_canvas, at.x + (6 + k) * p, at.y + k * p, UiTheme.WARN)
			UiDraw.px(_canvas, at.x + (6 + k) * p, at.y + (4 - k) * p, UiTheme.WARN)


## What is locked: corner brackets round it, a ring on the ground it stands on,
## and a scan line running down the brackets while the slate reads it.
func _draw_lock(s: TargetSubject) -> void:
	var at := _screen_at(s.here(), s.height)
	var base: Vector2 = at[0]
	var top: Vector2 = at[1]
	var half := maxf(27.0, absf(base.y - top.y) * 0.45)
	var box := Rect2i(int(base.x - half), int(top.y) - 9, int(half * 2.0), int(base.y - top.y) + 18)
	var col := _ink(s.machine)
	# A dark bracket under the bright one: the corners have to hold against grass
	# at noon as well as against snow, and under `lit` against a hearth too.
	UiSlate.brackets(_canvas, box.grow(UiBase.PITCH), UiTheme.RIM, maxi(15, box.size.y / 4))
	UiSlate.brackets(_canvas, box, col, maxi(12, box.size.y / 4))
	var t := fmod(_t, SCAN_SECONDS) / SCAN_SECONDS
	var line := box.position.y + roundi(t * box.size.y)
	UiDraw.rect(_canvas, Rect2i(box.position.x + UiBase.PITCH, line, box.size.x - 2 * UiBase.PITCH, UiBase.PITCH), Color(col, 0.45))
	_draw_ring(s, col)


## A ring on the ground, drawn through the camera so it lies on the world: the
## body's own radius, a ring of points rather than a disc, so it never covers
## what it is round.
func _draw_ring(s: TargetSubject, col: Color) -> void:
	var cam := game.camera
	# A body has its roster radius, a place has its own (a depot's yard is wider
	# than anything that walks), and a person has neither and takes PERSON_RADIUS.
	var r := s.radius()
	if r <= 0.0:
		r = PERSON_RADIUS
	var base := game.world.to_3d(s.here())
	var was := Vector2.ZERO
	for i in range(0, 25):
		var a := i * TAU / 24.0
		var p := cam.unproject_position(base + Vector3(cos(a) * r, 0.02, sin(a) * r)).round()
		if i > 0 and p.distance_to(was) < 120.0:
			_dotted(was, p, col)
		was = p


## A line of every other pixel between two points: a ring that reads as drawn.
func _dotted(a: Vector2, b: Vector2, col: Color) -> void:
	var steps := maxi(1, int(a.distance_to(b)))
	for i in range(0, steps + 1, UiBase.PITCH * 2):
		var p := a.lerp(b, float(i) / float(steps))
		UiDraw.px(_canvas, int(p.x), int(p.y), col)


## The read: what the body is, what it can do, what it has noticed, what it is
## thinking. Words, because the player is holding the key that asks for them.
func _draw_read(read: Dictionary) -> void:
	if read.is_empty():
		return
	var machine := bool(read.machine)
	var stats: Array = read.stats
	var powers: PackedStringArray = read.powers
	# The panel is as tall as what it has to say. A machine fills it; a person has
	# no health, no powers and little else, and a half-empty frame round two lines
	# reads as a slate with something missing rather than a person plainly read.
	var told := mini(stats.size(), STATS_MOST) + mini(powers.size(), POWERS_MOST)
	# What the plan has it doing, under its name: the story's line (docs/STORY.md
	# §7, machines by being watched). It adds its own height to the panel, so a
	# machine with everything to say still has room for the anchored foot.
	var testimony := str(read.get("testimony", ""))
	var extra := READ_LINE if testimony != "" else 0
	var r := Rect2i(PANEL.position, Vector2i(PANEL.size.x, mini(PANEL.size.y + extra, READ_HEAD + extra + told * UiTheme.LINE + READ_GAP + READ_FOOT)))
	Hud.clip(_canvas, r, false)
	var x := r.position.x + 12
	var y := r.position.y + 6
	var title := "%s  %s" % [String(read.name).to_upper(), read.role]
	UiDraw.text(_canvas, Vector2i(x, y), _fit(title, r.size.x - 24), _ink(machine))
	y += UiTheme.LINE
	if testimony != "":
		UiDraw.text(_canvas, Vector2i(x, y), _fit(testimony, r.size.x - 24), UiTheme.MACHINE[2])
		y += READ_LINE
	y = _draw_pips_line(x, y, read, machine)
	# Laid out in order and cut to what fits, so the last two lines — what it has
	# noticed and what it is doing about it — always have their room.
	for i in mini(stats.size(), STATS_MOST):
		var s: Array = stats[i]
		UiDraw.text(_canvas, Vector2i(x, y), str(s[0]), UiTheme.TEXT_DIM)
		UiDraw.text_right(_canvas, r.end.x - 12, y, _fit(str(s[1]), r.size.x - 116), UiTheme.TEXT)
		y += UiTheme.LINE
	for i in mini(powers.size(), POWERS_MOST):
		UiDraw.text(_canvas, Vector2i(x, y), _fit(powers[i], r.size.x - 24), UiTheme.MACHINE[3] if machine else UiTheme.TEXT_DIM)
		y += UiTheme.LINE
	# The last two lines are anchored: what it has noticed and what it is doing
	# about it are the whole point of the panel, and they never move about.
	var aware: Dictionary = read.awareness
	y = maxi(y, r.end.y - READ_FOOT)
	UiDraw.hline(_canvas, x, r.end.x - 12, y - 6, UiTheme.GHOST)
	UiDraw.text(_canvas, Vector2i(x, y), _fit(str(aware.word), r.size.x - 24), UiTheme.WARN if bool(aware.sure) else UiTheme.TEXT_DIM)
	UiDraw.text(_canvas, Vector2i(x, y + UiTheme.LINE), _fit(str(read.thinking), r.size.x - 24), UiTheme.BRIGHT)
	_draw_keys(r, false)


func _draw_pips_line(x: int, y: int, read: Dictionary, machine: bool) -> int:
	var pips: Array = read.pips
	if pips.is_empty():
		# A person: the slate has no health to show and does not invent one, so the
		# line carries only how far off they are.
		UiDraw.text_right(_canvas, PANEL.end.x - 12, y, TargetRead.tiles(float(roundi(float(read.distance)))), UiTheme.TEXT_DIM)
		return y + UiTheme.LINE
	var full := int(pips[0])
	for i in TargetRead.PIPS:
		var col := UiTheme.GHOST
		if i < full:
			col = _ink(machine)
		elif i == full and float(pips[1]) > 0.25:
			col = UiTheme.MACHINE[2] if machine else UiTheme.TEXT_DIM
		UiDraw.rect(_canvas, Rect2i(x + i * 10, y + 2, 8, 14), col)
	UiDraw.text(_canvas, Vector2i(x + TargetRead.PIPS * 10 + 12, y), "%d of %d" % [int(read.health), int(read.max_health)], UiTheme.TEXT)
	UiDraw.text_right(_canvas, PANEL.end.x - 12, y, TargetRead.tiles(float(roundi(float(read.distance)))), UiTheme.TEXT_DIM)
	return y + UiTheme.LINE


## What the other keys do while the target key is held, on the panel's own glass:
## over the world these words had nothing behind them and read as litter.
func _draw_keys(r: Rect2i, sweeping: bool, pages: int = 1) -> void:
	var y := r.end.y - UiTheme.LINE - 2
	var x := r.position.x + 10
	UiDraw.hline(_canvas, x, r.end.x - 12, y - 4, UiTheme.GHOST)
	if not sweeping or pages > 1:
		var word := "more" if sweeping else "another"
		# Asked of the live map: these were spelled "a d" and went on saying so
		# after the cycle moved off the move keys (docs/CONTROLS.md, C3).
		x += UiSlate.mini_cap(_canvas, Vector2i(x, y + 2), UiPauseScreen.key_line([&"target_prev", &"target_next"])) + 6
		UiDraw.text(_canvas, Vector2i(x, y), word, UiTheme.TEXT_DIM)
		x += UiFont.width(word) + 14
	x += UiSlate.mini_cap(_canvas, Vector2i(x, y + 2), PlayerSettings.cap_of(&"ability_scan")) + 6
	UiDraw.text(_canvas, Vector2i(x, y), "one at a time" if sweeping else "the field", UiTheme.TEXT_DIM)


## A sweep: the short of everything in this page of the field, and a mark on each
## of them. A field bigger than one page says which page this is, because a number
## the player cannot page through is a number that lies about the field.
func _draw_sweep(rows: Array, field: Array, page: int = 1, pages: int = 1) -> void:
	var r := Rect2i(SWEEP_PANEL.position, Vector2i(SWEEP_PANEL.size.x, 60 + maxi(1, rows.size()) * UiTheme.LINE))
	Hud.clip(_canvas, r, false)
	var x := r.position.x + 12
	var y := r.position.y + 6
	UiDraw.text(_canvas, Vector2i(x, y), "THE FIELD", UiTheme.MACHINE[4])
	var count := "%d" % rows.size() if pages <= 1 else "%d  %d/%d" % [rows.size(), page, pages]
	UiDraw.text_right(_canvas, r.end.x - 12, y, count, UiTheme.TEXT_DIM)
	y += UiTheme.LINE + 2
	for row: Dictionary in rows:
		if y > r.end.y - UiTheme.LINE - 4:
			break
		var machine := bool(row.machine)
		var tag: Dictionary = row.tag
		if tag.is_empty():
			# A person: a dash where a body's health would be, and nothing pretending
			# to be a reading of how much they have noticed.
			UiDraw.hline(_canvas, x, x + TargetRead.PIPS * 6 - 4, y + 8, UiTheme.TEXT_DIM)
		else:
			var full := int((tag.pips as Array)[0])
			for i in TargetRead.PIPS:
				UiDraw.rect(_canvas, Rect2i(x + i * 6, y + 4, 4, 10), _ink(machine) if i < full else UiTheme.GHOST)
			# No chip in the sweep: this row already sits on the panel's own glass.
			_draw_notice(Vector2i(x + TargetRead.PIPS * 6 + 6, y + 2), int(tag.notice), machine, true, false)
		UiDraw.text(_canvas, Vector2i(x + TargetRead.PIPS * 6 + 30, y), _fit(str(row.name), 222), _ink(machine, false))
		UiDraw.text_right(_canvas, r.end.x - 12, y, "%dt" % roundi(float(row.distance)), UiTheme.TEXT_DIM)
		y += UiTheme.LINE
	if rows.is_empty():
		UiDraw.text(_canvas, Vector2i(x, y), "nothing within reach", UiTheme.TEXT_DIM)
	for s: Variant in field:
		var subject := s as TargetSubject
		if subject == null:
			continue
		var at := _screen_at(subject.here(), subject.height)
		if _on_glass(at[1]):
			UiDraw.rect(_canvas, Rect2i(int(at[1].x) - 8, int(at[1].y) - TAG_LIFT - 16, 18, UiBase.PITCH), UiTheme.MACHINE[3] if subject.machine else UiTheme.TEXT)
	_draw_keys(r, true, pages)


## Text cut to `width` pixels with an ellipsis: a panel this narrow must never
## push a word off its own glass.
static func _fit(text: String, width: int) -> String:
	if UiFont.width(text) <= width:
		return text
	var t := text
	while t.length() > 1 and UiFont.width(t + "…") > width:
		t = t.left(t.length() - 1)
	return t + "…"
