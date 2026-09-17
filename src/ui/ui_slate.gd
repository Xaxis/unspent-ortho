class_name UiSlate
## The slate: the one device every screen is an app of (docs/ART.md §9).
##
## A display module stolen from a machine (FOUND: exact pixels, violet chrome,
## rivets in a row, a cold sensor slit, one clean shade step) in a bezel the
## player patched (MADE): the lower right is a grey casing cut from another
## device and soldered on, duct tape holds the cracked corner, electrical tape
## binds the cable where it leaves, a brass screw where a machine screw was
## lost, and KEEP DRY scratched into the chrome.
##
## The glass is honest about being salvaged, and none of it ever sits under
## text: a dead column of stuck pixels in the left margin, a crack confined to
## the top right corner, a replacement sub-panel (SPARE) a shade bluer than the
## rest, a scan shimmer when it wakes, and brightness that dips with low power.
##
## ## What LANTERN changed, and what it did not
##
## Everything here is now drawn in the base's own pixels (`UiBase.SIZE`). The
## device covers the same share of the frame it always did — `UNIT` is the
## factor its geometry came across by — but the type on it is two-thirds the
## size (`UiFont`), so the glass holds half again as many rows.
##
## The bake gained more than size. The chamfers, the rounded corner of the grey
## casing, the screw heads and the knob are all decided by a distance or a sum
## per pixel, so at the base's resolution they come out as true bevels and true
## circles instead of the three-pixel staircases they were. Nothing about the
## device's design moved; it is the same object, cut properly.
##
##   the page slate   DEVICE, GLASS_RECT; STATUS bar on top, KEYS strip below,
##                    BODY between, split into LIST and SPARE for two-pane apps

## Base pixels to one pixel of the device as it was originally cut. The geometry
## below is written as `<the old number> * UNIT` on purpose: the device is the
## one thing on screen that did NOT change size, and showing the factor is how
## the next person can tell that from a number that was simply retuned.
const UNIT := 3

## The page slate's outer edge and its glass.
const DEVICE := Rect2i(8 * UNIT, 5 * UNIT, 624 * UNIT, 350 * UNIT)
const BEZEL_L := 16 * UNIT
const BEZEL_T := 14 * UNIT
const BEZEL_R := 16 * UNIT
const BEZEL_B := 20 * UNIT
const GLASS_RECT := Rect2i(24 * UNIT, 19 * UNIT, 592 * UNIT, 316 * UNIT)
## The bar on top and the strip along the foot: sized off a line of TYPE, not off
## the device, so they are the one part of the furniture that came down with it.
const STATUS_H := UiTheme.LINE + 2
const KEYS_H := UiTheme.LINE + 2
const BODY := Rect2i(24 * UNIT, 19 * UNIT + STATUS_H + 2, 592 * UNIT, 316 * UNIT - (STATUS_H + 2) * 2)
## Two-pane apps: the list, and the replacement sub-panel beside it.
const LIST := Rect2i(BODY.position.x, BODY.position.y, 282 * UNIT, BODY.size.y)
const SPARE := Rect2i(310 * UNIT, BODY.position.y + 2 * UNIT, 302 * UNIT, BODY.size.y - 4 * UNIT)
## Content never comes nearer the glass's left edge than this (the dead column
## lives inside it) nor its right edge (the crack lives there).
const MARGIN_L := 10 * UNIT
const MARGIN_R := 14 * UNIT
## How far a WORD in the sub-panel keeps from that panel's own right edge. The
## panel is set a little further right than the crack's zone begins — it is a
## replacement module and it reaches under the flaw — so the clearance is the
## panel's, not the glass's, and `tests/ui/test_slate.gd` holds it.
const SPARE_INSET := 26
## Around the device in its texture: its shadow and the cable loop.
const PAD := 8 * UNIT
## Seconds the glass takes to wake (opening) and to change app (switching).
const WAKE_SECONDS := 0.2
const SWITCH_SECONDS := 0.1
## Below this power the glass dims, down to DIM_FLOOR of full brightness.
const LOW_POWER := 0.25
const DIM_FLOOR := 0.8

## Apps in the order the status bar lists them: [screen name, tab label, key].
## Every tab names the key that reaches it. Three have keys of their own; home
## is Esc; the three that live under home follow it behind a chevron, so the
## Esc cap reads as reaching them THROUGH home and never promises more.
const TABS := [[&"inventory", "CARRY", "i"], [&"crafting", "MAKE", "c"], [&"map", "MAP", "m"], [&"pause", "HOME", "esc"], [&"loadout", "GEAR", ""], [&"reads", "READS", ""], [&"saves", "SAVES", ""]]
## The app the keyless tabs are chosen inside.
const UNDER: StringName = &"pause"

## Main thread only: textures made from finished bakes.
static var _textures := {}
## Under _lock: finished bakes not yet made textures, and bakes in flight.
static var _images := {}
static var _baking := {}
static var _lock := Mutex.new()
static var _tasks: Array[int] = []


# --- geometry -----------------------------------------------------------------

static func glass_of(device: Rect2i) -> Rect2i:
	return device.grow_individual(-BEZEL_L, -BEZEL_T, -BEZEL_R, -BEZEL_B)


## Where the crack runs, in screen pixels, for a device: nothing is drawn under it.
static func crack_zone(device: Rect2i) -> Rect2i:
	var g := glass_of(device)
	return Rect2i(g.end.x - MARGIN_R + 2 * UNIT, g.position.y, MARGIN_R - 2 * UNIT, 44 * UNIT)


## The dead column's x for a device.
static func dead_column_x(device: Rect2i) -> int:
	return glass_of(device).position.x + 3 * UNIT


# --- drawing on a CanvasItem ----------------------------------------------------

## Dim the world behind the awake slate.
static func veil(ci: CanvasItem) -> void:
	UiDraw.rect(ci, UiBase.screen(), UiTheme.VEIL)


## The device: bezel and glass, baked; a plain frame while the bake is out.
static func device(ci: CanvasItem, d: Rect2i = DEVICE) -> void:
	var tex := device_texture(d.size)
	if tex != null:
		ci.draw_texture(tex, Vector2(d.position - Vector2i(PAD, PAD)))
		return
	var F := Palette.FOUND
	UiDraw.rect(ci, d, F[1].lerp(Palette.PLATE[1], 0.35))
	UiDraw.frame(ci, d, F[0])
	UiDraw.hline(ci, d.position.x + 1, d.end.x - 2, d.position.y + 1, F[3])
	var g := glass_of(d)
	UiDraw.rect(ci, g.grow(UNIT), UiTheme.GLASS_OFF)
	UiDraw.rect(ci, g, UiTheme.GLASS)


## What lies over the content: the crack, the dead column and a stuck pixel
## (nothing until they are baked).
static func marks(ci: CanvasItem, d: Rect2i = DEVICE) -> void:
	var tex := marks_texture(d.size)
	if tex != null:
		ci.draw_texture(tex, Vector2(d.position - Vector2i(PAD, PAD)))


## The replacement sub-panel: its own glass, a step bluer, set in a dark seam.
static func spare(ci: CanvasItem, r: Rect2i = SPARE) -> void:
	UiDraw.rect(ci, r.grow(UNIT), UiTheme.GLASS_OFF)
	var tex := spare_texture(r.size)
	if tex != null:
		ci.draw_texture(tex, Vector2(r.position))
	else:
		UiDraw.rect(ci, r, UiTheme.GLASS_SPARE)
	# The clips that hold it in, top and bottom: two bright pixels and a dark one.
	for x: int in [r.position.x + 6 * UNIT, r.end.x - 8 * UNIT]:
		UiDraw.rect(ci, Rect2i(x, r.position.y - UNIT, 3 * UNIT, UNIT), UiTheme.GHOST)
		UiDraw.rect(ci, Rect2i(x, r.end.y, 3 * UNIT, UNIT), UiTheme.GHOST)


## The waking glass: everything below the scan line is still dark, the line is
## bright, and a few rows above it shimmer. `t` 0..1; nothing drawn at 1.
static func wake(ci: CanvasItem, t: float, d: Rect2i = DEVICE) -> void:
	if t >= 1.0:
		return
	var g := glass_of(d)
	var y := g.position.y + roundi(clampf(t, 0.0, 1.0) * g.size.y)
	if y < g.end.y:
		UiDraw.rect(ci, Rect2i(g.position.x, y, g.size.x, g.end.y - y), UiTheme.GLASS_OFF)
		UiDraw.rect(ci, Rect2i(g.position.x, y, g.size.x, UiBase.PITCH), Color(UiTheme.BRIGHT, 0.55))
	var frame := roundi(t * 60.0)
	for k in 5:
		var ry := y - 2 * UNIT - roundi(Rng.hash01(frame, k, 0, 0x5a4e) * 14.0) * UNIT
		if ry > g.position.y and ry < g.end.y:
			UiDraw.rect(ci, Rect2i(g.position.x, ry, g.size.x, UiBase.PITCH), Color(UiTheme.PHOSPHOR[2], 0.12 + 0.1 * Rng.hash01(frame, k, 1, 0x5a4e)))


## Brightness 0..1 laid over the glass: a dark wash, never on the bezel.
static func dim(ci: CanvasItem, brightness: float, d: Rect2i = DEVICE) -> void:
	if brightness >= 1.0:
		return
	UiDraw.rect(ci, glass_of(d), Color(UiTheme.GLASS_OFF, clampf(1.0 - brightness, 0.0, 1.0)))


## The key that reaches app `n` on the status bar: its own, or home's for the
## apps chosen inside home. "" for anything that is not a tab.
static func tab_key(n: StringName) -> String:
	var home := ""
	for tab: Array in TABS:
		if tab[0] == UNDER:
			home = tab[2]
	for tab: Array in TABS:
		if tab[0] == n:
			return tab[2] if tab[2] != "" else home
	return ""


## True for an app reached by choosing it inside home rather than by a key.
static func tab_under_home(n: StringName) -> bool:
	for tab: Array in TABS:
		if tab[0] == n:
			return tab[2] == ""
	return false


## The status bar: the slate's name, the apps with the open one lit, the clock
## and the cell. `app` is a screen name (&"" with no app on the glass).
static func status(ci: CanvasItem, app: StringName, clock: String, power: float, d: Rect2i = DEVICE, tabs: bool = true) -> void:
	var g := glass_of(d)
	var y := g.position.y + 2
	var x := g.position.x + MARGIN_L
	UiDraw.hline(ci, g.position.x + MARGIN_L - 2 * UNIT, g.end.x - MARGIN_R, g.position.y + STATUS_H, UiTheme.GHOST)
	UiDraw.text(ci, Vector2i(x, y), "slate", UiTheme.BRIGHT if app == &"" else UiTheme.TEXT_DIM)
	x += UiFont.width("slate") + 12
	if tabs:
		UiDraw.vline(ci, x, y + 4, y + 16, UiTheme.FAINT)
		x += 12
	var under_home := false
	for tab: Array in (TABS if tabs else []):
		var label: String = tab[1]
		var lit: bool = tab[0] == app
		var k: String = tab[2]
		if k != "":
			if tab[0] == UNDER:
				# Home and what hangs off it stand apart from the keyed apps.
				UiDraw.vline(ci, x - 4, y + 4, y + 16, UiTheme.FAINT)
				x += 10
			x += mini_cap(ci, Vector2i(x, y), k, lit or (app != &"" and tab[0] == UNDER and tab_under_home(app))) + 6
		elif not under_home:
			# The chevron: these are reached by going through home, not by a key.
			under_home = true
			x += chevron(ci, Vector2i(x, y + 4), UiTheme.FAINT) + 8
		else:
			# One dim point between them: they are one set, all behind that Esc.
			UiDraw.px(ci, x - 10, y + 10, UiTheme.FAINT)
		if lit:
			UiDraw.rect(ci, Rect2i(x - 6, y - 2, UiFont.width(label) + 12, UiTheme.LINE), UiTheme.GLASS_LIT)
			UiDraw.hline(ci, x - 6, x + UiFont.width(label) + 4, y + UiFont.SIZE, UiTheme.TEXT)
		UiDraw.text(ci, Vector2i(x, y), label, UiTheme.BRIGHT if lit else UiTheme.TEXT_DIM)
		x += UiFont.width(label) + (14 if under_home else 18)
	var right := g.end.x - MARGIN_R - 28
	cell(ci, Vector2i(right - 26, y + 2), power)
	UiDraw.text_right(ci, right - 38, y, clock, UiTheme.TEXT_DIM)


## A small right-pointing chevron. Returns its width.
static func chevron(ci: CanvasItem, at: Vector2i, col: Color) -> int:
	var p := UiBase.PITCH
	for k in 3:
		UiDraw.px(ci, at.x + k * p, at.y + k * p, col)
		UiDraw.px(ci, at.x + k * p, at.y + (4 - k) * p, col)
	return 3 * p


## A four-segment cell glyph: its segments go out from the right as power falls,
## and the last one shows in the warning.
static func cell(ci: CanvasItem, at: Vector2i, power: float) -> void:
	var p := UiBase.PITCH
	UiDraw.frame(ci, Rect2i(at.x, at.y, 12 * p, 7 * p), UiTheme.TEXT_DIM)
	UiDraw.vline(ci, at.x + 12 * p, at.y + 2 * p, at.y + 5 * p - 1, UiTheme.TEXT_DIM)
	var n := UiRules.cell_segments(power)
	for i in 4:
		var col := UiTheme.WARN if n == 1 else UiTheme.TEXT
		UiDraw.rect(ci, Rect2i(at.x + 2 * p + i * 2 * p, at.y + 2 * p, p, 3 * p), col if i < n else UiTheme.GHOST)


## The key strip along the foot: `keys` as [[key, words], ...] in phosphor, and
## on the right a note (what was done, or why not, in the warning).
## Clear space kept between the last key hint and the note beside it.
const NOTE_GAP := 16
## A note shorter than this has nothing left to say once it is cut, so it is
## dropped rather than shown as a stub of one word and an ellipsis.
const NOTE_MIN := 56


## `text` cut to `room` pixels, ending in an ellipsis when anything was taken
## off; "" when there is not enough room to say anything worth reading. Whole
## words are kept where they fit, because a name cut mid-word reads as a fault
## in the device rather than as a message too long for its strip.
static func elided(text: String, room: int) -> String:
	if room < NOTE_MIN:
		return ""
	if UiFont.width(text) <= room:
		return text
	var out := ""
	for word: String in text.split(" ", false):
		var next := word if out == "" else "%s %s" % [out, word]
		if UiFont.width(next + "...") > room:
			break
		out = next
	if out == "":
		# One word longer than the whole strip: take it back a letter at a time.
		for i in range(text.length(), 0, -1):
			if UiFont.width(text.left(i) + "...") <= room:
				out = text.left(i)
				break
	return "%s..." % out if out != "" else ""


static func keys(ci: CanvasItem, pairs: Array, note: String = "", note_age: float = 0.0, warn: bool = false, d: Rect2i = DEVICE) -> void:
	var g := glass_of(d)
	var y := g.end.y - KEYS_H + 2
	UiDraw.hline(ci, g.position.x + MARGIN_L - 2 * UNIT, g.end.x - MARGIN_R, y - 4, UiTheme.GHOST)
	var x := g.position.x + MARGIN_L
	for p: Array in pairs:
		var k: String = p[0]
		x += key_cap(ci, Vector2i(x, y - 2), k) + 8
		UiDraw.text(ci, Vector2i(x, y), p[1], UiTheme.TEXT_DIM)
		x += UiFont.width(p[1]) + 24
	if note != "" and note_age < 4.0:
		var a := clampf(4.0 - note_age, 0.0, 1.0)
		# The key hints are how the device is worked, so the NOTE gives way, never
		# them. Nothing checked that before: the hints run left to right and the
		# note was right-aligned from the far edge, and on the title's narrow
		# slate — 200 px of room once the hints are down — six of the ten
		# sentences SaveSlots.problem() can write were drawn straight through
		# "e choose", the worst of them over by 84 px. Clipped here so it holds
		# for every caller instead of for the sentences one package could reach.
		var room := g.end.x - MARGIN_R - x - NOTE_GAP
		var shown := elided(note, room)
		if shown != "":
			UiDraw.text_right(ci, g.end.x - MARGIN_R, y, shown,
				Color(UiTheme.WARN if warn else UiTheme.TEXT, UiDraw.stepped(a)))


## A key cap small enough for the status bar: a ruled box, its name in the dim
## phosphor (bright on the open app). Returns its width.
static func mini_cap(ci: CanvasItem, at: Vector2i, k: String, lit: bool = false) -> int:
	var w := maxi(14, UiFont.width(k) + 8)
	var h := UiFont.SIZE - 2
	UiDraw.rect(ci, Rect2i(at.x, at.y, w, h), UiTheme.RIM)
	UiDraw.hline(ci, at.x + 2, at.x + w - 3, at.y - 2, UiTheme.GHOST)
	UiDraw.hline(ci, at.x + 2, at.x + w - 3, at.y + h, UiTheme.GHOST)
	UiDraw.vline(ci, at.x, at.y, at.y + h - 1, UiTheme.GHOST)
	UiDraw.vline(ci, at.x + w - 1, at.y, at.y + h - 1, UiTheme.GHOST)
	UiDraw.text(ci, Vector2i(at.x + (w - UiFont.width(k) + 2) / 2, at.y - 2), k, UiTheme.TEXT if lit else UiTheme.TEXT_DIM)
	return w


## A key cap: a dark key with a lit rim and its name in phosphor. Returns its width.
static func key_cap(ci: CanvasItem, at: Vector2i, k: String, a: float = 1.0) -> int:
	var w := maxi(18, UiFont.width(k) + 8)
	var h := UiFont.SIZE + 2
	UiDraw.rect(ci, Rect2i(at.x + 2, at.y, w - 4, h), Color(UiTheme.RIM, a))
	UiDraw.rect(ci, Rect2i(at.x, at.y + 2, w, h - 4), Color(UiTheme.RIM, a))
	UiDraw.hline(ci, at.x + 2, at.x + w - 3, at.y, Color(UiTheme.FAINT, a))
	UiDraw.hline(ci, at.x + 2, at.x + w - 3, at.y + h - 1, Color(UiTheme.GHOST, a))
	UiDraw.vline(ci, at.x, at.y + 2, at.y + h - 3, Color(UiTheme.FAINT, a))
	UiDraw.vline(ci, at.x + w - 1, at.y + 2, at.y + h - 3, Color(UiTheme.GHOST, a))
	UiDraw.text(ci, Vector2i(at.x + (w - UiFont.width(k)) / 2, at.y + 1), k, Color(UiTheme.BRIGHT, a))
	return w


## An app's title at the top of a pane, in capitals, with a rule running on.
static func title(ci: CanvasItem, r: Rect2i, text: String, col: Color = UiTheme.TEXT) -> void:
	var at := Vector2i(r.position.x + MARGIN_L, r.position.y + 8)
	UiDraw.text(ci, at, text, col)
	UiDraw.hline(ci, at.x + UiFont.width(text) + 10, r.end.x - MARGIN_R, at.y + UiFont.SIZE / 2, UiTheme.GHOST)


## A group heading in a list: small capitals in the dim tone, a rule after.
static func heading(ci: CanvasItem, at: Vector2i, text: String, right: int, col: Color = UiTheme.TEXT_DIM) -> void:
	var s := text.to_upper()
	UiDraw.text(ci, at, s, col)
	var x := at.x + UiFont.width(s) + 8
	var y := at.y + UiFont.SIZE / 2
	while x < right:
		UiDraw.px(ci, x, y, UiTheme.FAINT)
		x += 4


## The chosen row: a lit bar the width of the pane and a bright notch at its left.
static func row_bar(ci: CanvasItem, x0: int, x1: int, top: int, col: Color = UiTheme.TEXT) -> void:
	UiDraw.rect(ci, Rect2i(x0, top - 2, x1 - x0, UiTheme.LINE), UiTheme.GLASS_LIT)
	UiDraw.rect(ci, Rect2i(x0, top, 4, UiFont.SIZE - 2), col)


## Top of text on the n-th line of a list that starts at `top`.
static func line_top(top: int, n: int) -> int:
	return top + n * UiTheme.LINE


## How many list lines fit between top and bottom.
static func line_count(top: int, bottom: int) -> int:
	return (bottom - top) / UiTheme.LINE


## How far inside a scan window its sketch sits, so the corner brackets are clear
## of the drawing.
const SCAN_INSET := 12


## The sketch size for a scan window `wide` across. **Whoever warms the sketch
## asks here too**: a sketch is cached by its size, so a page that warmed 234 and
## then drew 222 warmed a picture nobody wanted and left the window to be drawn
## on the frame it was needed. That went unnoticed for as long as an unwarmed
## sketch was quietly rastered on the main thread; it is a visibly empty window
## now, which is the better failure.
static func scan_size(wide: int) -> int:
	return wide - SCAN_INSET


## A scan window: corner brackets, a faint grid of points, and the thing's scan
## in the middle. Found things are framed in the module's violet.
static func scan_box(ci: CanvasItem, r: Rect2i, id: StringName) -> void:
	var found := UiIcons.is_found(id)
	var edge := UiTheme.MACHINE[2] if found else UiTheme.TEXT_DIM
	brackets(ci, r, edge, 6 * UNIT)
	var y := r.position.y + 10
	while y < r.end.y - 6:
		var x := r.position.x + 10
		while x < r.end.x - 6:
			UiDraw.px(ci, x, y, UiTheme.GHOST)
			x += 12
		y += 12
	var size := scan_size(mini(r.size.x, r.size.y))
	UiSketch.draw_item(ci, id, r.position + (r.size - Vector2i(size, size)) / 2, size)
	UiDraw.text(ci, Vector2i(r.position.x + 6, r.end.y + 4), "SCAN" if not found else "FOUND", edge)


## Corner brackets `len` long round a rect, `weight` pixels thick. A bracket is
## the one mark on this device that is regularly drawn over the WORLD, so it is
## never a hairline: `weight` defaults to one pixel of the module's own glass.
static func brackets(ci: CanvasItem, r: Rect2i, col: Color, len: int, weight: int = UiBase.PITCH) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x - weight
	var y1 := r.end.y - weight
	for arm: Rect2i in [Rect2i(x0, y0, len, weight), Rect2i(x0, y0, weight, len),
			Rect2i(x1 - len + weight, y0, len, weight), Rect2i(x1, y0, weight, len),
			Rect2i(x0, y1, len, weight), Rect2i(x0, y1 - len + weight, weight, len),
			Rect2i(x1 - len + weight, y1, len, weight), Rect2i(x1, y1 - len + weight, weight, len)]:
		UiDraw.rect(ci, arm, col)


## A segmented meter: segments over the rect's width, filled to `frac`; segments
## past `warn_from` (a fraction) show in the warning when filled.
static func meter(ci: CanvasItem, r: Rect2i, frac: float, warn_from: float = 2.0, col: Color = UiTheme.TEXT) -> void:
	UiDraw.frame(ci, r, UiTheme.FAINT)
	var inner := r.grow(-2 * UiBase.PITCH)
	var step := 3 * UiBase.PITCH
	var n := maxi(1, inner.size.x / step)
	var lit := roundi(clampf(frac, 0.0, 1.0) * n)
	for i in n:
		var c := col if i < lit else UiTheme.GHOST
		if i < lit and float(i + 1) / n > warn_from:
			c = UiTheme.WARN
		UiDraw.rect(ci, Rect2i(inner.position.x + i * step, inner.position.y, step - UiBase.PITCH, inner.size.y), c)


## Words wrapped at `width` from `at`, a line each. Returns the lines used.
static func wrapped(ci: CanvasItem, at: Vector2i, width: int, text: String, col: Color) -> int:
	var lines := wrap_text(width, text)
	for i: int in lines.size():
		UiDraw.text(ci, Vector2i(at.x, at.y + i * UiTheme.LINE), lines[i], col)
	return lines.size()


## The same break, without drawing: what wrapped() will put on each line. Pure,
## so anything that has to know whether a sentence FITS where it is said can ask
## instead of keeping its own copy of the rule (tests/save/test_problem_fits.gd).
## (Not `wrap`: that is a built-in function, and a static of the same name here
## resolves to it — the native-name trap in CLAUDE.md.)
static func wrap_text(width: int, text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if UiFont.width(next) > width and line != "":
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out


# --- baked textures ---------------------------------------------------------------

## Bake a device `size` big (its bezel and glass, its flaws) and the page's
## sub-panel on a worker. Never blocks: until a bake is in, the device is drawn
## as a plain frame. Called from the ui system's and the title's setup, long
## before anyone opens anything.
static func warm(size: Vector2i = DEVICE.size) -> void:
	_start([["d", size], ["m", size], ["s", SPARE.size]])


## Wait for every bake in flight (shutdown, and shots that must show the bezel).
static func wait() -> void:
	for t: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()


## True once the device `size` and its flaws can be drawn as baked.
static func ready(size: Vector2i) -> bool:
	return device_texture(size) != null and marks_texture(size) != null


## The baked textures, or null while their bake is still on a worker (one is
## started if none is).
static func device_texture(size: Vector2i) -> ImageTexture:
	return _texture("d", size)


static func marks_texture(size: Vector2i) -> ImageTexture:
	return _texture("m", size)


static func spare_texture(size: Vector2i) -> ImageTexture:
	return _texture("s", size)


static func _key(kind: String, size: Vector2i) -> String:
	return "%s|%d|%d" % [kind, size.x, size.y]


static func _bake(kind: String, size: Vector2i) -> Image:
	match kind:
		"d": return device_image(size)
		"m": return marks_image(size)
	return spare_image(size)


## Start a worker on each [kind, size] not baked, waiting or in flight.
static func _start(jobs: Array) -> void:
	var todo: Array = []
	_lock.lock()
	for job: Array in jobs:
		var key := _key(job[0], job[1])
		if _textures.has(key) or _images.has(key) or _baking.has(key):
			continue
		_baking[key] = true
		todo.append(job)
	_lock.unlock()
	if todo.is_empty():
		return
	_tasks.append(WorkerThreadPool.add_task(func() -> void:
		for job: Array in todo:
			var img := UiSlate._bake(job[0], job[1])
			var key := UiSlate._key(job[0], job[1])
			_lock.lock()
			_images[key] = img
			_baking.erase(key)
			_lock.unlock()))


static func _texture(kind: String, size: Vector2i) -> ImageTexture:
	var key := _key(kind, size)
	if _textures.has(key):
		return _textures[key]
	for i in range(_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_tasks[i]):
			WorkerThreadPool.wait_for_task_completion(_tasks[i])
			_tasks.remove_at(i)
	_lock.lock()
	var img: Image = _images.get(key)
	_images.erase(key)
	_lock.unlock()
	if img == null:
		_start([[kind, size]])
		return null
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


## The glass of the replacement sub-panel. Its scan rows are one pixel of the
## MODULE thick, not one of the base's: a one-pixel stripe at 1080p is a moire
## pattern, and the structure is supposed to be read as the module's own.
static func spare_image(size: Vector2i) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(UiTheme.GLASS_SPARE)
	var p := UiBase.PITCH
	for y in range(p, size.y, p * 2):
		img.fill_rect(Rect2i(0, y, size.x, p), UiTheme.GLASS_SPARE_ROW)
	return img


## The bezel and the glass of a device `size` big, in a texture PAD bigger all
## round (its shadow and its cable). The device's top-left is at (PAD, PAD).
static func device_image(size: Vector2i) -> Image:
	var w := size.x
	var h := size.y
	var u := UNIT
	var img := Image.create_empty(w + PAD * 2, h + PAD * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var o := Vector2i(PAD, PAD)
	var F := Palette.FOUND
	var A := Palette.ASH
	# The shadow it casts on the world.
	_fill(img, Rect2i(o.x + 3 * u, o.y + 4 * u, w, h), Color(0.0, 0.0, 0.02, 0.5))
	# 1. The stolen module's chrome: one violet face, a chamfered edge, a lit top
	#    and left, one shade step bottom and right. Exact.
	# Cold and dirty: the module's violet dulled toward plate by years outdoors.
	var face := F[1].lerp(Palette.PLATE[1], 0.35)
	_fill(img, Rect2i(o.x, o.y, w, h), face)
	# The lit and shaded edges, laid as bands rather than per pixel: the whole
	# face is one fill, so only the rim and the four chamfers need looking at.
	_fill(img, Rect2i(o.x, o.y + u, w, u), F[3])
	_fill(img, Rect2i(o.x + u, o.y + 2 * u, w - 2 * u, u), F[2])
	_fill(img, Rect2i(o.x + u, o.y + 2 * u, u, h - 4 * u), F[2])
	_fill(img, Rect2i(o.x, o.y + h - 2 * u, w, u), F[0].lerp(F[1], 0.5))
	_fill(img, Rect2i(o.x + w - 2 * u, o.y, u, h), F[0].lerp(F[1], 0.5))
	_frame_thick(img, Rect2i(o.x, o.y, w, h), u, F[0])
	# The chamfers: a true bevel now, because the cut is decided per BASE pixel.
	for y in range(0, h):
		for x in range(0, w):
			var dx := mini(x, w - 1 - x)
			var dy := mini(y, h - 1 - y)
			if dx + dy >= 5 * u:
				continue
			if dx + dy < 4 * u:
				_dot(img, o.x + x, o.y + y, Color(0, 0, 0, 0))
			else:
				_dot(img, o.x + x, o.y + y, F[0])
	# One rubbed edge: years of a thumb along the top, worn to bright metal.
	_fill(img, Rect2i(o.x + int(w * 0.18), o.y + u, int(w * 0.23), u), F[4])
	_fill(img, Rect2i(o.x + int(w * 0.22), o.y + 2 * u, int(w * 0.14), u), F[3])
	var g := Rect2i(BEZEL_L, BEZEL_T, w - BEZEL_L - BEZEL_R, h - BEZEL_T - BEZEL_B)
	# The plates the module's frame is built of: exact grooves, dark over lit.
	for sx: int in [int(w * 0.31), int(w * 0.69)]:
		_fill(img, Rect2i(o.x + sx, o.y + 3 * u, u, g.position.y - 6 * u), F[0])
		_fill(img, Rect2i(o.x + sx + u, o.y + 3 * u, u, g.position.y - 6 * u), F[2])
	for sy: int in [int(h * 0.3)]:
		_fill(img, Rect2i(o.x + 3 * u, o.y + sy, g.position.x - 6 * u, u), F[0])
		_fill(img, Rect2i(o.x + 3 * u, o.y + sy + u, g.position.x - 6 * u, u), F[2])
	# Vent slots down the left side, cut exact.
	for i in 9:
		_fill(img, Rect2i(o.x + 6 * u, o.y + int(h * 0.3) + (10 + i * 4) * u, 5 * u, 2 * u), F[0])
		_fill(img, Rect2i(o.x + 6 * u, o.y + int(h * 0.3) + (12 + i * 4) * u, 5 * u, u), F[2])
	# The lip the glass sits in.
	_frame_thick(img, Rect2i(g.position + o, g.size).grow(2 * u), u, F[0].lerp(F[1], 0.4))
	_frame_thick(img, Rect2i(g.position + o, g.size).grow(u), u, UiTheme.GLASS_OFF)
	_fill(img, Rect2i(o.x + g.position.x - 2 * u, o.y + g.end.y + 2 * u, g.size.x + 4 * u, u), F[2])
	# Rivets along the top in an exact row, and the streak each has left below it.
	var sensor := Rect2i(w / 2 - 22 * u, 4 * u, 44 * u, 5 * u)
	var rx := 30 * u
	while rx < w - 30 * u:
		if rx < sensor.position.x - 6 * u or rx > sensor.end.x + 4 * u:
			_rivet(img, Vector2i(o.x + rx, o.y + 6 * u), u, F)
			if (rx / u) % 48 == 30:
				_fill(img, Rect2i(o.x + rx + u, o.y + 8 * u, u, 3 * u), F[1])
		rx += 16 * u
	# The module's cold sensor slit, dead centre.
	_fill(img, Rect2i(o + sensor.position, sensor.size), F[0])
	_fill(img, Rect2i(o.x + sensor.position.x + 2 * u, o.y + sensor.position.y + 2 * u, sensor.size.x - 5 * u, u), Palette.COLD[1])
	for k: int in [9, 10, 30]:
		_fill(img, Rect2i(o.x + sensor.position.x + k * u, o.y + sensor.position.y + 2 * u, u, u), Palette.COLD[3])
	_fill(img, Rect2i(o.x + sensor.position.x, o.y + sensor.end.y, sensor.size.x, u), F[3])
	# The part number the machine stamped on it: ticks nobody can read.
	for i in 22:
		var tall := (int(Rng.hash01(71, i, 0, 0x57a) * 3.0) + 1) * u
		_fill(img, Rect2i(o.x + w / 2 - 30 * u + i * 3 * u, o.y + h - 8 * u - tall, u, tall), F[1])
	# 2. The glass: flat, every other MODULE row a hair lighter.
	_fill(img, Rect2i(o + g.position, g.size), UiTheme.GLASS)
	var pitch := UiBase.PITCH
	for y in range(pitch, g.size.y, pitch * 2):
		_fill(img, Rect2i(o.x + g.position.x, o.y + g.position.y + y, g.size.x, pitch), UiTheme.GLASS_ROW)
	# 3. The patch: the lower right is the grey casing of some other device, cut
	#    by hand, a pixel proud of the chrome and rounded where the chrome is not.
	var seam_y := int(h * 0.44)
	var seam_x := int(w * 0.64)
	for y in range(seam_y - 2 * u, h + 1):
		for x in range(seam_x - 2 * u, w + 1):
			if not _patch(x, y, w, h, seam_x, seam_y):
				continue
			if _rounded_out(x, y, w + 1, h + 1, 7 * u):
				continue
			var inner := x >= g.position.x - 2 * u and x < g.end.x + 2 * u and y >= g.position.y - 2 * u and y < g.end.y + 2 * u
			if inner:
				continue
			var col := A[1]
			if x >= w or y >= h or _rounded_out(x, y, w + 1, h + 1, 8 * u):
				col = A[0]
			elif _patch_edge(x, y, w, h, seam_x, seam_y, u):
				col = Palette.INK[1]
			elif y >= seam_y + 2 * u and y < seam_y + 3 * u or x >= seam_x + 2 * u and x < seam_x + 3 * u or y >= g.end.y + 3 * u and y < g.end.y + 4 * u or x >= g.end.x + 3 * u and x < g.end.x + 4 * u:
				col = A[2]
			else:
				# Moulded plastic, scuffed: a few short scratches running with the grain.
				var scuff := Rng.hash01(x / (5 * u), y / u, 0, 0x6a)
				if scuff < 0.025:
					col = A[2]
				elif Rng.hash01(x / u, y / u, 1, 0x6a) < 0.02:
					col = A[0]
			_dot(img, o.x + x, o.y + y, col)
	# Its own lip round the glass: plain dark plastic, not violet.
	for y in range(g.position.y - 2 * u, g.end.y + 2 * u):
		for x in range(g.position.x - 2 * u, g.end.x + 2 * u):
			var ring := x < g.position.x or x >= g.end.x or y < g.position.y or y >= g.end.y
			if ring and _patch(x, y, w, h, seam_x, seam_y):
				var edge := x >= g.position.x - u and x < g.position.x or x >= g.end.x and x < g.end.x + u or y >= g.position.y - u and y < g.position.y or y >= g.end.y and y < g.end.y + u
				_dot(img, o.x + x, o.y + y, A[0] if edge else A[0].lerp(A[1], 0.5))
	# A moulded ridge along the casing's bottom bar, and a speaker grille in it.
	_fill(img, Rect2i(o.x + seam_x + 10 * u, o.y + h - 6 * u, w - 10 * u - seam_x - 10 * u, u), A[0])
	_fill(img, Rect2i(o.x + seam_x + 10 * u, o.y + h - 5 * u, w - 10 * u - seam_x - 10 * u, u), A[2])
	for gy in 3:
		for gx in 7:
			_fill(img, Rect2i(o.x + w - 72 * u + gx * 3 * u, o.y + g.end.y + 5 * u + gy * 3 * u, u, u), A[0])
	# 4. Solder where the two were joined, and copper jumpers bridging the cut.
	for p: Vector2i in [Vector2i(w - BEZEL_R + 4 * u, seam_y), Vector2i(w - 5 * u, seam_y + u), Vector2i(seam_x, h - BEZEL_B + 6 * u), Vector2i(seam_x + u, h - 6 * u)]:
		_solder(img, o + p, u)
	_jumper(img, o + Vector2i(seam_x - 7 * u, h - 12 * u), o + Vector2i(seam_x + 9 * u, h - 12 * u), u)
	_jumper(img, o + Vector2i(w - 11 * u, seam_y - 7 * u), o + Vector2i(w - 11 * u, seam_y + 8 * u), u)
	# 5. Screws: exact machine screws in the chrome, a brass one in the patch where
	#    the right screw was lost, and an empty hole under the tape.
	_screw(img, o + Vector2i(5 * u, 5 * u), false, u)
	_screw(img, o + Vector2i(5 * u, h - 10 * u), false, u)
	_screw(img, o + Vector2i(w - 13 * u, h - 13 * u), true, u)
	_fill(img, Rect2i(o.x + w - 10 * u, o.y + 5 * u, 3 * u, 3 * u), F[0])
	# 6. KEEP DRY scratched into the chrome, and a tally beside it.
	if w >= 280 * u:
		_scratch(img, o + Vector2i(BEZEL_L + 10 * u, h - 14 * u), "KEEP DRY", 5, u)
		for i in 5:
			var tx := BEZEL_L + 70 * u + i * 3 * u + (4 * u if i == 4 else 0)
			var slant := 1 if i == 4 else 0
			_scratch_line(img, o + Vector2i(tx - slant * 9 * u, h - 13 * u), o + Vector2i(tx + slant * 2 * u, h - 7 * u), i, u)
	# 7. A knob off something else entirely: brown bakelite with a lit notch.
	_knob(img, o + Vector2i(w - 36 * u, h - 10 * u), u)
	# 8. The power light, cold green while awake.
	_fill(img, Rect2i(o.x + BEZEL_L + 2 * u, o.y + 6 * u, 3 * u, 2 * u), UiTheme.PHOSPHOR[3])
	_fill(img, Rect2i(o.x + BEZEL_L + 2 * u, o.y + 6 * u, u, u), UiTheme.PHOSPHOR[4])
	# 9. The cable, out of the left side and looped, bound in electrical tape.
	var cy := int(h * 0.56)
	_cable(img, o, cy, u)
	_tape_band(img, Rect2i(o.x - 2 * u, o.y + cy - 4 * u, BEZEL_L - 2 * u, 9 * u), Palette.RUST, u)
	# 10. Duct tape across the top right corner, over the crack.
	_duct(img, o, w, u)
	return img


## The glass's flaws that sit over content: the crack in the top right corner,
## the dead column in the left margin, one stuck violet pixel. The stuck pixels
## are the MODULE's, so they are one of its pixels each; the crack is in the
## glass itself and is drawn as fine as the glass is.
static func marks_image(size: Vector2i) -> Image:
	var w := size.x
	var h := size.y
	var u := UNIT
	var p := UiBase.PITCH
	var img := Image.create_empty(w + PAD * 2, h + PAD * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var o := Vector2i(PAD, PAD)
	var g := Rect2i(o + Vector2i(BEZEL_L, BEZEL_T), size - Vector2i(BEZEL_L + BEZEL_R, BEZEL_T + BEZEL_B))
	# Stuck pixels down the left margin, with gaps where the column still works.
	var dx := g.position.x + 3 * u
	var row := 0
	for y in range(g.position.y, g.end.y, p):
		var run := int((y - g.position.y) / (23 * u))
		row += 1
		if Rng.hash01(run, 0, 0, 0xdead) < 0.18:
			continue
		_fill(img, Rect2i(dx, y, p, p), Color(UiTheme.PHOSPHOR[0], 0.9 if (row % 2 == 0) else 0.7))
	_fill(img, Rect2i(g.position.x + 5 * u, g.position.y + g.size.y / 2 + 7 * u, p, p), UiTheme.MACHINE[1])
	# The crack: from under the tape at the corner, a few jagged runs down the
	# right margin, a star of chips at its origin. Light glints on one side, dark on the other.
	var zone := Rect2i(g.end.x - MARGIN_R + 2 * u, g.position.y, MARGIN_R - 2 * u, 44 * u)
	var origin := Vector2i(g.end.x - 2 * u, g.position.y + u)
	var branches := [[Vector2i(-1, 1), 40 * u], [Vector2i(-2, 1), 16 * u], [Vector2i(0, 1), 26 * u]]
	for bi in branches.size():
		var dir: Vector2i = branches[bi][0]
		var n: int = branches[bi][1]
		var q := origin
		for i in n:
			var step := Vector2i(dir.x if Rng.hash01(bi, i / u, 0, 0xc7a) < 0.55 else 0, 1 if dir.y != 0 else 0)
			if step == Vector2i.ZERO:
				step = Vector2i(0, 1)
			q += step
			if Rng.hash01(bi, i / u, 1, 0xc7a) < 0.2:
				q.x += 1 if Rng.hash01(bi, i / u, 2, 0xc7a) < 0.5 else -1
			q.x = clampi(q.x, zone.position.x, zone.end.x - 1)
			if not zone.has_point(q):
				break
			_dot(img, q.x, q.y, Color(0.75, 0.84, 0.86, 0.55 - 0.3 * float(i) / n))
			if zone.has_point(q + Vector2i(1, 0)):
				_dot(img, q.x + 1, q.y, Color(0, 0, 0, 0.5))
	for k in 7:
		var a := k * TAU / 7.0 + 0.4
		var q2 := origin + Vector2i(roundi(cos(a) * 3.0 * u), roundi(sin(a) * 3.0 * u))
		if zone.has_point(q2):
			_fill(img, Rect2i(q2.x, q2.y, p, p), Color(0.75, 0.84, 0.86, 0.35))
	return img


# --- pixel helpers for the bake ----------------------------------------------------

static func _dot(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if col.a >= 1.0:
		img.set_pixel(x, y, col)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(col))


static func _fill(img: Image, r: Rect2i, col: Color) -> void:
	var c := r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if c.size.x <= 0 or c.size.y <= 0:
		return
	if col.a >= 1.0:
		img.fill_rect(c, col)
		return
	for y in range(c.position.y, c.end.y):
		for x in range(c.position.x, c.end.x):
			_dot(img, x, y, col)


static func _frame_thick(img: Image, r: Rect2i, t: int, col: Color) -> void:
	_fill(img, Rect2i(r.position.x, r.position.y, r.size.x, t), col)
	_fill(img, Rect2i(r.position.x, r.end.y - t, r.size.x, t), col)
	_fill(img, Rect2i(r.position.x, r.position.y, t, r.size.y), col)
	_fill(img, Rect2i(r.end.x - t, r.position.y, t, r.size.y), col)


## One rivet: a lit quarter, two shade steps, a dark one. Four cells of `u`.
static func _rivet(img: Image, at: Vector2i, u: int, F: Array[Color]) -> void:
	_fill(img, Rect2i(at.x, at.y, u, u), F[5])
	_fill(img, Rect2i(at.x + u, at.y, u, u), F[3])
	_fill(img, Rect2i(at.x, at.y + u, u, u), F[3])
	_fill(img, Rect2i(at.x + u, at.y + u, u, u), F[0])


## The grey casing's share of the bezel: the right side below its cut, the
## bottom bar right of its cut. The cuts wander a pixel, made by hand.
static func _patch(x: int, y: int, w: int, h: int, seam_x: int, seam_y: int) -> bool:
	var right := x >= w - BEZEL_R and y >= seam_y + _jag(x, 0)
	var bottom := y >= h - BEZEL_B and x >= seam_x + _jag(y, 1)
	return right or bottom


static func _patch_edge(x: int, y: int, w: int, h: int, seam_x: int, seam_y: int, u: int) -> bool:
	return (x >= w - BEZEL_R and y >= seam_y + _jag(x, 0) and y < seam_y + _jag(x, 0) + u) \
		or (y >= h - BEZEL_B and x >= seam_x + _jag(y, 1) and x < seam_x + _jag(y, 1) + u)


static func _jag(t: int, salt: int) -> int:
	return (int(Rng.hash01(t / (3 * UNIT), salt, 0, 0x7a6) * 3.0) - 1) * UNIT


static func _solder(img: Image, c: Vector2i, u: int) -> void:
	var S := Palette.STONE
	for dy in range(-2 * u, 3 * u):
		for dx in range(-2 * u, 3 * u):
			if absi(dx) + absi(dy) > 3 * u:
				continue
			var col := S[3]
			if dx + dy <= -2 * u:
				col = S[5]
			elif dx + dy >= 2 * u:
				col = S[1]
			_dot(img, c.x + dx, c.y + dy, col)
	_fill(img, Rect2i(c.x - u, c.y - u, u, u), Color.WHITE.lerp(S[5], 0.5))


static func _jumper(img: Image, a: Vector2i, b: Vector2i, u: int) -> void:
	var C := Palette.COPPER
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / n
		var p := Vector2(a).lerp(Vector2(b), t)
		# It sags a little between its blobs.
		var sag := sin(t * PI) * 2.0 * u
		var q := Vector2i(roundi(p.x + (sag if a.x == b.x else 0.0)), roundi(p.y + (sag if a.y == b.y else 0.0)))
		_fill(img, Rect2i(q.x, q.y, u, u), C[2] if (i / u) % 5 != 2 else C[3])
	_solder(img, a, u)
	_solder(img, b, u)


static func _screw(img: Image, at: Vector2i, brass: bool, u: int) -> void:
	var R := Palette.COPPER if brass else Palette.PLATE
	var size := (6 if brass else 5) * u
	var c := Vector2(size - 1, size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c)
			if d > size * 0.5 + 0.1:
				continue
			var col := R[2] if brass else R[3]
			if d > size * 0.5 - 0.7 * u:
				col = R[0]
			elif x + y <= 2 * u:
				col = R[4]
			_dot(img, at.x + x, at.y + y, col)
	if brass:
		# A cross head, turned a little off square: it was not made for this.
		for p: Vector2i in [Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(1, 3), Vector2i(4, 2)]:
			_fill(img, Rect2i(at.x + p.x * u, at.y + p.y * u, u, u), R[0])
	else:
		_fill(img, Rect2i(at.x + u, at.y + 2 * u, 3 * u, u), R[0])


static func _scratch(img: Image, at: Vector2i, text: String, seed: int, u: int) -> void:
	var F := Palette.FOUND
	var x := at.x
	for i in text.length():
		var gl := UiFont.glyph(text[i])
		var jog := int(Rng.hash01(seed, i, 0, 0x5c) * 2.0) * u
		for r in mini(7, gl.size()):
			for cx in gl[r].length():
				if gl[r][cx] != "#":
					continue
				# A scratch through the violet shows bright metal, its groove dark below it.
				if Rng.hash01(seed, i * 16 + cx, r, 0x5d) < 0.1:
					continue
				_fill(img, Rect2i(x + cx * u, at.y + (r + 1) * u + jog, u, u), F[1])
				_fill(img, Rect2i(x + cx * u, at.y + r * u + jog, u, u), F[5])
		x += (UiFont.glyph_width(text[i]) + 1) * u


static func _scratch_line(img: Image, a: Vector2i, b: Vector2i, seed: int, u: int) -> void:
	var F := Palette.FOUND
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var p := Vector2(a).lerp(Vector2(b), float(i) / maxf(1.0, n))
		var q := Vector2i(roundi(p.x), roundi(p.y))
		if Rng.hash01(seed, i / u, 0, 0x5e) < 0.12:
			continue
		_fill(img, Rect2i(q.x, q.y + u, u, u), F[1])
		_fill(img, Rect2i(q.x, q.y, u, u), F[5])


static func _knob(img: Image, c: Vector2i, u: int) -> void:
	var E := Palette.EARTH
	var r := 5.0 * u
	for y in range(-roundi(r) - u, roundi(r) + u):
		for x in range(-roundi(r) - u, roundi(r) + u):
			var d := Vector2(x, y).length()
			if d > r + 0.2 * u:
				continue
			var col := E[2]
			if d > r - 0.7 * u:
				col = E[0] if ((x + y) / u + 20) % 2 == 0 else E[1]
			elif x + y < -3 * u:
				col = E[3]
			elif x + y > 3 * u:
				col = E[1]
			_dot(img, c.x + x, c.y + y, col)
	# Its pointer, turned up and right to wherever it was last left.
	_fill(img, Rect2i(c.x + u, c.y - 2 * u, u, u), E[5])
	_fill(img, Rect2i(c.x + 2 * u, c.y - 3 * u, u, u), E[5])
	_fill(img, Rect2i(c.x + 3 * u, c.y - 4 * u, u, u), E[4])
	# It casts a shade on the casing.
	for k in 4:
		_fill(img, Rect2i(c.x + (3 + k / 2) * u, c.y + 5 * u, u, u), Color(0, 0, 0, 0.35))


static func _cable(img: Image, o: Vector2i, cy: int, u: int) -> void:
	var I := Palette.INK
	# Out through the side, down in a loop hanging past the edge, and back in.
	var steps := 22 * u
	for i in steps:
		# A U hanging off the side: out, down and back in, drawn as one bent line.
		var t := float(i) / float(steps - 1)
		var a := t * PI
		var p := Vector2i(o.x - roundi(sin(a) * 6.0 * u), o.y + cy + u + roundi(t * 16.0 * u))
		_fill(img, Rect2i(p.x, p.y, u, u), Palette.ASH[1])
		_fill(img, Rect2i(p.x, p.y + u, u, u), I[1])
		_fill(img, Rect2i(p.x - u, p.y, u, u), Palette.ASH[2])


static func _tape_band(img: Image, r: Rect2i, ramp: Array[Color], u: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var col := ramp[2]
			if y < r.position.y + u:
				col = ramp[3]
			elif y >= r.end.y - u:
				col = ramp[1]
			elif ((x + y) / u) % 7 == 0:
				col = ramp[3]
			# The torn end is ragged.
			if x < r.position.x + u and Rng.hash01(x / u, y / u, 0, 0x7ae) < 0.5:
				continue
			_dot(img, x, y, col)
	# The gloss of fresh electrical tape.
	_fill(img, Rect2i(r.position.x + 3 * u, r.position.y + 2 * u, 5 * u, u), Color(1, 1, 1, 0.25))


## Silver duct tape laid across the corner on the diagonal, its ends torn, its
## weave showing, lifting a little at one edge.
static func _duct(img: Image, o: Vector2i, w: int, u: int) -> void:
	var A := Palette.ASH
	var corner := Vector2(o.x + w - 1, o.y)
	var axis := Vector2(1, 1).normalized()
	var across := Vector2(1, -1).normalized()
	for y in range(o.y - 6 * u, o.y + 34 * u):
		for x in range(o.x + w - 40 * u, o.x + w + 6 * u):
			var p := Vector2(x, y) - corner
			var along := p.dot(axis)
			var off := p.dot(across)
			if absf(off + 16.0 * u) > 6.0 * u:
				continue
			var tear := (Rng.hash01(roundi(off / u), 0, 0, 0xd0c) - 0.5) * 3.0 * u
			if along < -18.0 * u + tear or along > 22.0 * u + tear:
				continue
			var col := A[4]
			if absf(off + 16.0 * u) > 5.0 * u:
				col = A[3]
			elif (roundi(x * 2 + y) / u) % 4 == 0:
				col = A[3]
			if off + 16.0 * u > 4.5 * u:
				col = A[2]
			_dot(img, x, y, col)
	# Where it lifts, a line of shade under its edge.
	for t in range(-14 * u, 18 * u):
		var q := corner + axis * t + across * -22.5 * u
		_fill(img, Rect2i(roundi(q.x), roundi(q.y), u, u), Color(0, 0, 0, 0.3))


## Outside a chamfer of `c` pixels at any corner of a w x h box.
static func _chamfered(x: int, y: int, w: int, h: int, c: int) -> bool:
	var dx := mini(x, w - 1 - x)
	var dy := mini(y, h - 1 - y)
	return dx + dy < c


## Outside the rounded bottom-right corner (radius r) of a w x h box.
static func _rounded_out(x: int, y: int, w: int, h: int, r: int) -> bool:
	var cx := w - 1 - r
	var cy := h - 1 - r
	if x <= cx or y <= cy:
		return false
	return Vector2(x - cx, y - cy).length() > r + 0.3
