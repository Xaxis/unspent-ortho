class_name UiTalkView
extends CanvasLayer
## Words over the world: a conversation, or a thing being read (owner's ruling,
## 2026-09-17 — not on the slate, low on the glass, with the world still running
## behind it).
##
## The pillar it does not break: **nothing is written over a fight the player did
## not ask for** (docs/ART.md §9). Talking is asked for — the player pressed the
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

## The panel at its SMALLEST, in base pixels. Clear of the slate's own edge: the
## held thing sits bottom-left and the panel used to cover it. It grows UP from
## this foot to hold what it has to say (`panel_for`): a fixed box held six lines,
## and a notice with seven wrote its last line over the keys.
const PANEL := Rect2i(72, 666, 1776, 300)
## The tallest it may grow, so a long page never climbs over the top of the frame.
const TALLEST := 420
const MARGIN := 16
const LINE := UiTheme.LINE
## Replies sit under what was said, indented, with the chosen one marked.
const REPLY_GAP := 12

var game: Game
## The conversation, or null while a thing is being read instead.
var talk: StoryTalk
## Lines of a fragment being read, and its title.
var reading: PackedStringArray = PackedStringArray()
var reading_title := ""
var choice := 0

var _canvas: Control


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


## The panel for `lines` lines said or written and `replies` replies under them
## (0 for a thing being read): as tall as that needs, from the same foot.
static func panel_for(lines: int, replies: int) -> Rect2i:
	var h := MARGIN + LINE + 4 + lines * LINE + (REPLY_GAP + replies * LINE if replies > 0 else 0) + LINE + 4 + MARGIN
	h = clampi(h, PANEL.size.y, TALLEST)
	return Rect2i(PANEL.position.x, PANEL.end.y - h, PANEL.size.x, h)


func _draw_talk() -> void:
	if not showing() or game == null:
		return
	var r := panel_for(talk.says().size(), talk.replies().size()) if talk != null else panel_for(reading.size(), 0)
	Hud.clip(_canvas, r, false)
	var x := r.position.x + MARGIN
	var y := r.position.y + MARGIN
	if talk != null:
		_draw_conversation(x, y, r)
	else:
		_draw_reading(x, y, r)


func _draw_conversation(x: int, y: int, r: Rect2i) -> void:
	UiDraw.text(_canvas, Vector2i(x, y), talk.title().to_upper(), UiTheme.TEXT_DIM)
	y += LINE + 4
	for line: String in talk.says():
		UiDraw.text(_canvas, Vector2i(x, y), line, UiTheme.BRIGHT)
		y += LINE
	y += REPLY_GAP
	var rs := talk.replies()
	for i in rs.size():
		var chosen := i == choice
		var text: String = rs[i].text
		if chosen:
			UiDraw.rect(_canvas, Rect2i(x - 4, y - 2, 6, LINE - 4), UiTheme.TEXT)
		UiDraw.text(_canvas, Vector2i(x + 16, y), text, UiTheme.TEXT if chosen else UiTheme.TEXT_DIM)
		y += LINE
	_draw_keys(r, "e say it", "esc leave")


func _draw_reading(x: int, y: int, r: Rect2i) -> void:
	UiDraw.text(_canvas, Vector2i(x, y), reading_title.to_upper(), UiTheme.TEXT_DIM)
	y += LINE + 4
	for line: String in reading:
		# A blank line in a fragment is a blank line on the glass: it is how the
		# machines' notices are laid out, and how a page breaks.
		if line != "":
			UiDraw.text(_canvas, Vector2i(x, y), line, UiTheme.TEXT)
		y += LINE
	_draw_keys(r, "", "esc put it down")


func _draw_keys(r: Rect2i, left: String, right: String) -> void:
	var y := r.end.y - LINE - 4
	UiDraw.hline(_canvas, r.position.x + MARGIN, r.end.x - MARGIN, y - 6, UiTheme.GHOST)
	if left != "":
		UiDraw.text(_canvas, Vector2i(r.position.x + MARGIN, y), left, UiTheme.TEXT_DIM)
	UiDraw.text_right(_canvas, r.end.x - MARGIN, y, right, UiTheme.TEXT_DIM)
