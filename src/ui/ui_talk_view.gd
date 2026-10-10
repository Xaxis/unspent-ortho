class_name UiTalkView
extends CanvasLayer
## Words over the world: a conversation, or a thing being read (owner's ruling,
## 2026-09-17 — not on the slate, low on the glass, with the world still running
## behind it).
##
## The pillar it does not break: **nothing is written over a fight the player did
## not ask for** (docs/LOOK.md). Talking is asked for — the player pressed the
## key, standing in front of somebody — and it never opens by itself.
##
## ## Reading it against a world that is lit
##
## This was a bare dark rectangle with words on it, and it was written when the
## world was a flat wash with a narrow value range. LANTERN's `lit` replaced that
## with real geometry under real light: a night field is genuinely dark, a hearth
## or a machine's lamp is genuinely bright, and both can be behind this panel in
## one conversation as the speaker turns.
##
## So the panel is no longer a colour laid over the world — it is a window of the
## slate's own glass in its salvaged frame (`Hud.clip`), the same one every corner
## readout is read off. That settles two things at once. It is OPAQUE, so what is
## behind it cannot reach the words at all, whatever the hour and whatever is
## burning; and it is the slate, so a conversation is read off the same device as
## everything else the player reads, rather than off a panel of its own invention.

## THE TALK IS PACED BY THE PLAYER (owner, 2026-10-09). What is said types out a
## line at a time; a press (use, or a click) while a line is typing finishes it,
## and a press on a finished line moves on to the next. The replies come up only
## once the last line is out, and a click on one, or the key on the one lit,
## says it. Nothing moves on by itself.
##
## The box is as wide as its widest line wants, from NARROWEST up to the panel,
## centred above the slate's foot, with whoever is speaking named on its top edge.

## The panel's foot and the widest a box may be, in base pixels: every line
## written is held to fit this width (tests/story). A box is as tall as what it
## has to say, growing UP from this foot (`panel_for`).
const PANEL := Rect2i(72, 666, 1776, 300)
## The tallest it may grow, so a long page never climbs over the top of the frame.
const TALLEST := 420
## The shortest, so a one-line exchange is still a box and not a strip.
const SHORTEST := 150
const MARGIN := 16
const LINE := UiTheme.LINE
## Replies sit under what was said, indented, with the chosen one marked.
const REPLY_GAP := 12
## The narrowest a conversation's box is drawn: a short exchange does not sit in
## a strip across the whole screen.
const NARROWEST := 960
## Characters a second a line types out at.
const CPS := 48.0

var game: Game
## The conversation, or null while a thing is being read instead.
var talk: StoryTalk
## Lines of a fragment being read, and its title.
var reading: PackedStringArray = PackedStringArray()
var reading_title := ""
var choice := 0
## The line being typed (an index into `talk.says()`) and how much of it is out.
var line := 0
var typed := 0.0

var _canvas: Control
## What was on the glass last frame (talk, node), so a new node starts typing.
var _on: Array = []
## The replies' rows as drawn, for the pointer (`reply_at`).
var _reply_rows: Array[Rect2i] = []


func _ready() -> void:
	layer = 12
	_canvas = Control.new()
	_canvas.name = "talk"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.theme = UiTheme.theme()
	_canvas.draw.connect(_draw_talk)
	add_child(_canvas)


func showing() -> bool:
	return talk != null or not reading.is_empty()


func refresh() -> void:
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	if talk == null:
		_on = []
		return
	var key := [talk, talk.node]
	var says := talk.says()
	if key != _on:
		_on = key
		line = 0
		typed = 0.0
		# A scripted tour presses through talks as they were before they typed:
		# every line out at once, so each press means the reply it always meant.
		if game != null and game.options != null and game.options.tour != "" and not says.is_empty():
			line = says.size() - 1
			typed = float(says[line].length())
		refresh()
	if line < says.size() and typed < says[line].length():
		typed = minf(typed + CPS * delta, float(says[line].length()))
		refresh()


## Every line of the node is out: the replies are up.
func lines_done() -> bool:
	if talk == null:
		return true
	var says := talk.says()
	return says.is_empty() or (line >= says.size() - 1 and typed >= says[says.size() - 1].length())


## A press on what is being said: finish the line typing, or go on to the next.
## False when every line is already out, and the press is for the replies.
func advance() -> bool:
	if talk == null or lines_done():
		return false
	var says := talk.says()
	if typed < says[line].length():
		typed = float(says[line].length())
	else:
		line += 1
		typed = 0.0
	refresh()
	return true


## The reply under the pointer, or -1.
func reply_at(p: Vector2) -> int:
	for i in _reply_rows.size():
		if _reply_rows[i].has_point(Vector2i(p)):
			return i
	return -1


## The pointer where the box is drawn, in the glass's own pixels.
func pointer() -> Vector2:
	return _canvas.get_local_mouse_position()


## The panel for `lines` lines said or written and `replies` replies under them
## (0 for a thing being read, whose title heads the page; a talk's speaker is on
## the tab above): as tall as that needs, from the same foot, and as wide as its
## widest line `wide` wants (the whole panel when 0).
static func panel_for(lines: int, replies: int, wide: int = 0) -> Rect2i:
	var head := LINE + 4 if replies == 0 else 0
	var h := MARGIN + head + lines * LINE + (REPLY_GAP + replies * LINE if replies > 0 else 0) + 6 + LINE + 4 + MARGIN
	h = clampi(h, SHORTEST, TALLEST)
	var w := PANEL.size.x if wide <= 0 else clampi(wide + MARGIN * 2 + 32, NARROWEST, PANEL.size.x)
	return Rect2i(PANEL.position.x + (PANEL.size.x - w) / 2, PANEL.end.y - h, w, h)


func _draw_talk() -> void:
	_reply_rows.clear()
	if not showing() or game == null:
		return
	if talk != null:
		var says := talk.says()
		var rs := talk.replies()
		var wide := 0
		for l: String in says:
			wide = maxi(wide, UiFont.width(l))
		for r: Dictionary in rs:
			wide = maxi(wide, UiFont.width(String(r.text)) + 40)
		var r := panel_for(says.size(), rs.size(), wide)
		Hud.clip(_canvas, r, false)
		_draw_conversation(r.position.x + MARGIN, r.position.y + MARGIN, r)
	else:
		var r := panel_for(reading.size(), 0)
		Hud.clip(_canvas, r, false)
		_draw_reading(r.position.x + MARGIN, r.position.y + MARGIN, r)


## Who is speaking, on the box's top edge: their name lit, what they are dim.
func _draw_speaker(r: Rect2i) -> void:
	var who := StoryCast.speaker_of(talk.id) if talk.id != &"" else null
	var name := who.name.to_upper() if who != null and who.name != "" else ""
	var what := talk.title()
	var w := UiFont.width(name) + (UiFont.width(what) + 16 if what != "" else 0) + 24
	if name == "":
		w = UiFont.width(what.to_upper()) + 24
	var tab := Rect2i(r.position.x + MARGIN, r.position.y - LINE - 6, w, LINE + 6)
	UiDraw.rect(_canvas, tab, UiTheme.GLASS)
	UiDraw.frame(_canvas, tab, UiTheme.FAINT)
	var x := tab.position.x + 12
	var y := tab.position.y + 3
	if name != "":
		UiDraw.text(_canvas, Vector2i(x, y), name, UiTheme.BRIGHT)
		if what != "":
			UiDraw.text(_canvas, Vector2i(x + UiFont.width(name) + 16, y), what, UiTheme.TEXT_DIM)
	else:
		UiDraw.text(_canvas, Vector2i(x, y), what.to_upper(), UiTheme.TEXT)


func _draw_conversation(x: int, y: int, r: Rect2i) -> void:
	_draw_speaker(r)
	var says := talk.says()
	var now := Time.get_ticks_msec() / 1000.0
	for i in mini(line + 1, says.size()):
		var full: String = says[i]
		var shown := full if i < line else full.substr(0, int(typed))
		UiDraw.text(_canvas, Vector2i(x, y), shown, UiTheme.BRIGHT)
		# Finished and waiting on the player: a mark that it goes on.
		if i == line and shown.length() == full.length() and i < says.size() - 1 and fmod(now, 0.9) < 0.6:
			UiDraw.text(_canvas, Vector2i(x + UiFont.width(shown) + 10, y), ">", UiTheme.TEXT)
		y += LINE
	if not lines_done():
		var typing := typed < says[line].length()
		_draw_keys(r, "e / click  " + ("finish" if typing else "next"), "esc leave")
		if not typing:
			refresh()
		return
	y += REPLY_GAP
	var rs := talk.replies()
	for i in rs.size():
		var chosen := i == choice
		var row := Rect2i(x - 6, y - 3, r.size.x - MARGIN * 2 + 12, LINE + 2)
		_reply_rows.append(row)
		if chosen:
			UiDraw.rect(_canvas, row, UiTheme.GLASS_LIT)
			UiDraw.rect(_canvas, Rect2i(x - 6, y - 3, 4, LINE + 2), UiTheme.TEXT)
		UiDraw.text(_canvas, Vector2i(x + 10, y), "%d" % (i + 1), UiTheme.FAINT if not chosen else UiTheme.TEXT_DIM)
		UiDraw.text(_canvas, Vector2i(x + 34, y), String(rs[i].text), UiTheme.BRIGHT if chosen else UiTheme.TEXT_DIM)
		y += LINE
	_draw_keys(r, "e / click  say it", "esc leave")


func _draw_reading(x: int, y: int, r: Rect2i) -> void:
	UiDraw.text(_canvas, Vector2i(x, y), reading_title.to_upper(), UiTheme.TEXT_DIM)
	y += LINE + 4
	for l: String in reading:
		# A blank line in a fragment is a blank line on the glass: it is how the
		# machines' notices are laid out, and how a page breaks.
		if l != "":
			UiDraw.text(_canvas, Vector2i(x, y), l, UiTheme.TEXT)
		y += LINE
	_draw_keys(r, "e / click  put it down", "esc put it down")


func _draw_keys(r: Rect2i, left: String, right: String) -> void:
	var y := r.end.y - LINE - 4
	UiDraw.hline(_canvas, r.position.x + MARGIN, r.end.x - MARGIN, y - 6, UiTheme.GHOST)
	if left != "":
		UiDraw.text(_canvas, Vector2i(r.position.x + MARGIN, y), left, UiTheme.TEXT_DIM)
	UiDraw.text_right(_canvas, r.end.x - MARGIN, y, right, UiTheme.TEXT_DIM)
