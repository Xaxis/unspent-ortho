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
## Everything is drawn at whole pixels at the 640x360 base. The bezel and glass
## are baked once per size into a texture (warm() bakes the page slate on a
## worker); layouts below are shared so every app lines up.
##
##   the page slate   DEVICE, GLASS_RECT; STATUS bar on top, KEYS strip below,
##                    BODY between, split into LIST and SPARE for two-pane apps

## The page slate's outer edge and its glass.
const DEVICE := Rect2i(8, 5, 624, 350)
const BEZEL_L := 16
const BEZEL_T := 14
const BEZEL_R := 16
const BEZEL_B := 20
const GLASS_RECT := Rect2i(24, 19, 592, 316)
const STATUS_H := 12
const KEYS_H := 12
const BODY := Rect2i(24, 32, 592, 290)
## Two-pane apps: the list, and the replacement sub-panel beside it.
const LIST := Rect2i(24, 32, 282, 290)
const SPARE := Rect2i(310, 34, 302, 286)
## Content never comes nearer the glass's left edge than this (the dead column
## lives inside it) nor its right edge (the crack lives there).
const MARGIN_L := 10
const MARGIN_R := 14
## Around the device in its texture: its shadow and the cable loop.
const PAD := 8
## Seconds the glass takes to wake (opening) and to change app (switching).
const WAKE_SECONDS := 0.2
const SWITCH_SECONDS := 0.1
## Below this power the glass dims, down to DIM_FLOOR of full brightness.
const LOW_POWER := 0.25
const DIM_FLOOR := 0.8

## Apps in the order the status bar lists them: [screen name, tab label].
const TABS := [[&"inventory", "CARRY"], [&"crafting", "MAKE"], [&"map", "MAP"], [&"loadout", "GEAR"], [&"reads", "READS"], [&"saves", "SAVES"]]

static var _textures := {}
static var _images := {}
static var _lock := Mutex.new()
static var _task := -1


# --- geometry -----------------------------------------------------------------

static func glass_of(device: Rect2i) -> Rect2i:
	return device.grow_individual(-BEZEL_L, -BEZEL_T, -BEZEL_R, -BEZEL_B)


## Where the crack runs, in screen pixels, for a device: nothing is drawn under it.
static func crack_zone(device: Rect2i) -> Rect2i:
	var g := glass_of(device)
	return Rect2i(g.end.x - MARGIN_R + 2, g.position.y, MARGIN_R - 2, 44)


## The dead column's x for a device.
static func dead_column_x(device: Rect2i) -> int:
	return glass_of(device).position.x + 3


# --- drawing on a CanvasItem ----------------------------------------------------

## Dim the world behind the awake slate.
static func veil(ci: CanvasItem) -> void:
	UiDraw.rect(ci, Rect2i(0, 0, 640, 360), UiTheme.VEIL)


## The device: bezel and glass, baked.
static func device(ci: CanvasItem, d: Rect2i = DEVICE) -> void:
	ci.draw_texture(device_texture(d.size), Vector2(d.position - Vector2i(PAD, PAD)))


## What lies over the content: the crack, the dead column and a stuck pixel.
static func marks(ci: CanvasItem, d: Rect2i = DEVICE) -> void:
	ci.draw_texture(marks_texture(d.size), Vector2(d.position - Vector2i(PAD, PAD)))


## The replacement sub-panel: its own glass, a step bluer, set in a dark seam.
static func spare(ci: CanvasItem, r: Rect2i = SPARE) -> void:
	UiDraw.frame(ci, r.grow(1), UiTheme.GLASS_OFF)
	ci.draw_texture(spare_texture(r.size), Vector2(r.position))
	# The clips that hold it in, top and bottom: two bright pixels and a dark one.
	for x: int in [r.position.x + 6, r.end.x - 8]:
		UiDraw.hline(ci, x, x + 2, r.position.y - 1, UiTheme.GHOST)
		UiDraw.hline(ci, x, x + 2, r.end.y, UiTheme.GHOST)


## The waking glass: everything below the scan line is still dark, the line is
## bright, and a few rows above it shimmer. `t` 0..1; nothing drawn at 1.
static func wake(ci: CanvasItem, t: float, d: Rect2i = DEVICE) -> void:
	if t >= 1.0:
		return
	var g := glass_of(d)
	var y := g.position.y + roundi(clampf(t, 0.0, 1.0) * g.size.y)
	if y < g.end.y:
		UiDraw.rect(ci, Rect2i(g.position.x, y, g.size.x, g.end.y - y), UiTheme.GLASS_OFF)
		UiDraw.hline(ci, g.position.x, g.end.x - 1, y, Color(UiTheme.BRIGHT, 0.55))
	var frame := roundi(t * 60.0)
	for k in 5:
		var ry := y - 2 - roundi(Rng.hash01(frame, k, 0, 0x5a4e) * 14.0)
		if ry > g.position.y and ry < g.end.y:
			UiDraw.hline(ci, g.position.x, g.end.x - 1, ry, Color(UiTheme.PHOSPHOR[2], 0.12 + 0.1 * Rng.hash01(frame, k, 1, 0x5a4e)))


## Brightness 0..1 laid over the glass: a dark wash, never on the bezel.
static func dim(ci: CanvasItem, brightness: float, d: Rect2i = DEVICE) -> void:
	if brightness >= 1.0:
		return
	UiDraw.rect(ci, glass_of(d), Color(UiTheme.GLASS_OFF, clampf(1.0 - brightness, 0.0, 1.0)))


## The status bar: the slate's name, the apps with the open one lit, the clock
## and the cell. `app` is a screen name (&"" on the home app).
static func status(ci: CanvasItem, app: StringName, clock: String, power: float, d: Rect2i = DEVICE, tabs: bool = true) -> void:
	var g := glass_of(d)
	var y := g.position.y + 2
	var x := g.position.x + MARGIN_L
	UiDraw.hline(ci, g.position.x + MARGIN_L - 2, g.end.x - MARGIN_R, g.position.y + STATUS_H, UiTheme.GHOST)
	var home := app == &"" or app == &"pause"
	UiDraw.text(ci, Vector2i(x, y), "slate", UiTheme.BRIGHT if home else UiTheme.TEXT_DIM)
	x += UiFont.width("slate") + 6
	UiDraw.vline(ci, x, y + 2, y + 8, UiTheme.FAINT)
	x += 6
	for tab: Array in (TABS if tabs else []):
		var label: String = tab[1]
		var lit: bool = tab[0] == app
		if lit:
			UiDraw.rect(ci, Rect2i(x - 3, y - 1, UiFont.width(label) + 6, 11), UiTheme.GLASS_LIT)
			UiDraw.hline(ci, x - 3, x + UiFont.width(label) + 2, y + 10, UiTheme.TEXT)
		UiDraw.text(ci, Vector2i(x, y), label, UiTheme.BRIGHT if lit else UiTheme.FAINT)
		x += UiFont.width(label) + 9
	var right := g.end.x - MARGIN_R - 14
	cell(ci, Vector2i(right - 13, y + 1), power)
	UiDraw.text_right(ci, right - 19, y, clock, UiTheme.TEXT_DIM)


## A four-segment cell glyph, 13x7: its segments go out from the right as power
## falls, and the last one shows in the warning.
static func cell(ci: CanvasItem, at: Vector2i, power: float) -> void:
	UiDraw.frame(ci, Rect2i(at.x, at.y, 12, 7), UiTheme.TEXT_DIM)
	UiDraw.vline(ci, at.x + 12, at.y + 2, at.y + 4, UiTheme.TEXT_DIM)
	var n := UiRules.cell_segments(power)
	for i in 4:
		var col := UiTheme.WARN if n == 1 else UiTheme.TEXT
		UiDraw.rect(ci, Rect2i(at.x + 2 + i * 2 + i * 0, at.y + 2, 1, 3), col if i < n else UiTheme.GHOST)
		UiDraw.rect(ci, Rect2i(at.x + 3 + i * 2, at.y + 2, 1, 3), col if i < n else UiTheme.GHOST)


## The key strip along the foot: `keys` as [[key, words], ...] in phosphor, and
## on the right a note (what was done, or why not, in the warning).
static func keys(ci: CanvasItem, pairs: Array, note: String = "", note_age: float = 0.0, warn: bool = false, d: Rect2i = DEVICE) -> void:
	var g := glass_of(d)
	var y := g.end.y - KEYS_H + 1
	UiDraw.hline(ci, g.position.x + MARGIN_L - 2, g.end.x - MARGIN_R, y - 2, UiTheme.GHOST)
	var x := g.position.x + MARGIN_L
	for p: Array in pairs:
		var k: String = p[0]
		x += key_cap(ci, Vector2i(x, y - 1), k) + 4
		UiDraw.text(ci, Vector2i(x, y), p[1], UiTheme.TEXT_DIM)
		x += UiFont.width(p[1]) + 12
	if note != "" and note_age < 4.0:
		var a := clampf(4.0 - note_age, 0.0, 1.0)
		UiDraw.text_right(ci, g.end.x - MARGIN_R, y, note, Color(UiTheme.WARN if warn else UiTheme.TEXT, UiDraw.stepped(a)))


## A key cap: a dark key with a lit rim and its name in phosphor. Returns its width.
static func key_cap(ci: CanvasItem, at: Vector2i, k: String, a: float = 1.0) -> int:
	var w := maxi(9, UiFont.width(k) + 4)
	UiDraw.rect(ci, Rect2i(at.x + 1, at.y, w - 2, 11), Color(UiTheme.RIM, a))
	UiDraw.rect(ci, Rect2i(at.x, at.y + 1, w, 9), Color(UiTheme.RIM, a))
	UiDraw.hline(ci, at.x + 1, at.x + w - 2, at.y, Color(UiTheme.FAINT, a))
	UiDraw.hline(ci, at.x + 1, at.x + w - 2, at.y + 10, Color(UiTheme.GHOST, a))
	UiDraw.vline(ci, at.x, at.y + 1, at.y + 9, Color(UiTheme.FAINT, a))
	UiDraw.vline(ci, at.x + w - 1, at.y + 1, at.y + 9, Color(UiTheme.GHOST, a))
	UiDraw.text(ci, Vector2i(at.x + (w - UiFont.width(k)) / 2, at.y), k, Color(UiTheme.BRIGHT, a))
	return w


## An app's title at the top of a pane, in capitals, with a rule running on.
static func title(ci: CanvasItem, r: Rect2i, text: String, col: Color = UiTheme.TEXT) -> void:
	var at := Vector2i(r.position.x + MARGIN_L, r.position.y + 4)
	UiDraw.text(ci, at, text, col)
	UiDraw.hline(ci, at.x + UiFont.width(text) + 5, r.end.x - MARGIN_R, at.y + 5, UiTheme.GHOST)


## A group heading in a list: small capitals in the dim tone, a rule after.
static func heading(ci: CanvasItem, at: Vector2i, text: String, right: int, col: Color = UiTheme.TEXT_DIM) -> void:
	var s := text.to_upper()
	UiDraw.text(ci, at, s, col)
	var x := at.x + UiFont.width(s) + 4
	var y := at.y + 5
	while x < right:
		UiDraw.px(ci, x, y, UiTheme.FAINT)
		x += 2


## The chosen row: a lit bar the width of the pane and a bright notch at its left.
static func row_bar(ci: CanvasItem, x0: int, x1: int, top: int, col: Color = UiTheme.TEXT) -> void:
	UiDraw.rect(ci, Rect2i(x0, top - 1, x1 - x0, 11), UiTheme.GLASS_LIT)
	UiDraw.rect(ci, Rect2i(x0, top, 2, 9), col)


## Top of text on the n-th line of a list that starts at `top`.
static func line_top(top: int, n: int) -> int:
	return top + n * UiTheme.LINE


## How many list lines fit between top and bottom.
static func line_count(top: int, bottom: int) -> int:
	return (bottom - top) / UiTheme.LINE


## A scan window: corner brackets, a faint grid of points, and the thing's scan
## in the middle. Found things are framed in the module's violet.
static func scan_box(ci: CanvasItem, r: Rect2i, id: StringName) -> void:
	var found := UiIcons.is_found(id)
	var edge := UiTheme.MACHINE[2] if found else UiTheme.TEXT_DIM
	brackets(ci, r, edge, 6)
	var y := r.position.y + 5
	while y < r.end.y - 3:
		var x := r.position.x + 5
		while x < r.end.x - 3:
			UiDraw.px(ci, x, y, UiTheme.GHOST)
			x += 6
		y += 6
	var size := mini(r.size.x, r.size.y) - 6
	UiSketch.draw_item(ci, id, r.position + (r.size - Vector2i(size, size)) / 2, size)
	UiDraw.text(ci, Vector2i(r.position.x + 3, r.end.y + 2), "SCAN" if not found else "FOUND", edge)


## Corner brackets `len` long round a rect.
static func brackets(ci: CanvasItem, r: Rect2i, col: Color, len: int) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x - 1
	var y1 := r.end.y - 1
	UiDraw.hline(ci, x0, x0 + len, y0, col)
	UiDraw.vline(ci, x0, y0, y0 + len, col)
	UiDraw.hline(ci, x1 - len, x1, y0, col)
	UiDraw.vline(ci, x1, y0, y0 + len, col)
	UiDraw.hline(ci, x0, x0 + len, y1, col)
	UiDraw.vline(ci, x0, y1 - len, y1, col)
	UiDraw.hline(ci, x1 - len, x1, y1, col)
	UiDraw.vline(ci, x1, y1 - len, y1, col)


## A segmented meter: `cells` segments over the rect's width, filled to `frac`;
## segments past `warn_from` (a fraction) show in the warning when filled.
static func meter(ci: CanvasItem, r: Rect2i, frac: float, warn_from: float = 2.0, col: Color = UiTheme.TEXT) -> void:
	UiDraw.frame(ci, r, UiTheme.FAINT)
	var inner := r.grow(-2)
	var n := maxi(1, inner.size.x / 3)
	var lit := roundi(clampf(frac, 0.0, 1.0) * n)
	for i in n:
		var c := col if i < lit else UiTheme.GHOST
		if i < lit and float(i + 1) / n > warn_from:
			c = UiTheme.WARN
		UiDraw.rect(ci, Rect2i(inner.position.x + i * 3, inner.position.y, 2, inner.size.y), c)


## Words wrapped at `width` from `at`, a line each. Returns the lines used.
static func wrapped(ci: CanvasItem, at: Vector2i, width: int, text: String, col: Color) -> int:
	var line := ""
	var y := at.y
	var used := 0
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if UiFont.width(next) > width and line != "":
			UiDraw.text(ci, Vector2i(at.x, y), line, col)
			y += UiTheme.LINE
			used += 1
			line = word
		else:
			line = next
	if line != "":
		UiDraw.text(ci, Vector2i(at.x, y), line, col)
		used += 1
	return used


# --- baked textures ---------------------------------------------------------------

## Bake the page slate ahead on a worker, so the first page opens at once.
static func warm() -> void:
	if _task >= 0 or _textures.has(_key("d", DEVICE.size)):
		return
	_task = WorkerThreadPool.add_task(func() -> void:
		var d := device_image(DEVICE.size)
		var m := marks_image(DEVICE.size)
		var s := spare_image(SPARE.size)
		_lock.lock()
		_images[_key("d", DEVICE.size)] = d
		_images[_key("m", DEVICE.size)] = m
		_images[_key("s", SPARE.size)] = s
		_lock.unlock())


static func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


static func device_texture(size: Vector2i) -> ImageTexture:
	return _texture(_key("d", size), func() -> Image: return device_image(size))


static func marks_texture(size: Vector2i) -> ImageTexture:
	return _texture(_key("m", size), func() -> Image: return marks_image(size))


static func spare_texture(size: Vector2i) -> ImageTexture:
	return _texture(_key("s", size), func() -> Image: return spare_image(size))


static func _key(kind: String, size: Vector2i) -> String:
	return "%s|%d|%d" % [kind, size.x, size.y]


static func _texture(key: String, make: Callable) -> ImageTexture:
	if _textures.has(key):
		return _textures[key]
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		wait()
	_lock.lock()
	var img: Image = _images.get(key)
	_images.erase(key)
	_lock.unlock()
	if img == null:
		img = make.call()
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


## The glass of the replacement sub-panel.
static func spare_image(size: Vector2i) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(UiTheme.GLASS_SPARE)
	for y in range(1, size.y, 2):
		img.fill_rect(Rect2i(0, y, size.x, 1), UiTheme.GLASS_SPARE_ROW)
	return img


## The bezel and the glass of a device `size` big, in a texture PAD bigger all
## round (its shadow and its cable). The device's top-left is at (PAD, PAD).
static func device_image(size: Vector2i) -> Image:
	var w := size.x
	var h := size.y
	var img := Image.create_empty(w + PAD * 2, h + PAD * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var o := Vector2i(PAD, PAD)
	var F := Palette.FOUND
	var A := Palette.ASH
	# The shadow it casts on the world.
	_fill(img, Rect2i(o.x + 3, o.y + 4, w, h), Color(0.0, 0.0, 0.02, 0.5))
	# 1. The stolen module's chrome: one violet face, a chamfered edge, a lit top
	#    and left, one shade step bottom and right. Exact.
	# Cold and dirty: the module's violet dulled toward plate by years outdoors.
	var face := F[1].lerp(Palette.PLATE[1], 0.35)
	for y in h:
		for x in w:
			if _chamfered(x, y, w, h, 4):
				continue
			var col := face
			if _chamfered(x, y, w, h, 5) or x == 0 or y == 0 or x == w - 1 or y == h - 1:
				col = F[0]
			elif y == 1:
				col = F[3]
			elif x == 1 or y == 2:
				col = F[2]
			elif y == h - 2 or x == w - 2:
				col = F[0].lerp(F[1], 0.5)
			_dot(img, o.x + x, o.y + y, col)
	# One rubbed edge: years of a thumb along the top, worn to bright metal.
	_hline(img, o.x + int(w * 0.18), o.x + int(w * 0.41), o.y + 1, F[4])
	_hline(img, o.x + int(w * 0.22), o.x + int(w * 0.36), o.y + 2, F[3])
	var g := Rect2i(BEZEL_L, BEZEL_T, w - BEZEL_L - BEZEL_R, h - BEZEL_T - BEZEL_B)
	# The plates the module's frame is built of: exact grooves, dark over lit.
	for sx: int in [int(w * 0.31), int(w * 0.69)]:
		_vline(img, o.x + sx, o.y + 3, o.y + g.position.y - 3, F[0])
		_vline(img, o.x + sx + 1, o.y + 3, o.y + g.position.y - 3, F[2])
	for sy: int in [int(h * 0.3)]:
		_hline(img, o.x + 3, o.x + g.position.x - 3, o.y + sy, F[0])
		_hline(img, o.x + 3, o.x + g.position.x - 3, o.y + sy + 1, F[2])
	# Vent slots down the left side, cut exact.
	for i in 9:
		_fill(img, Rect2i(o.x + 6, o.y + int(h * 0.3) + 10 + i * 4, 5, 2), F[0])
		_hline(img, o.x + 6, o.x + 10, o.y + int(h * 0.3) + 12 + i * 4, F[2])
	# The lip the glass sits in.
	_frame(img, Rect2i(g.position + o, g.size).grow(2), F[0].lerp(F[1], 0.4))
	_frame(img, Rect2i(g.position + o, g.size).grow(1), UiTheme.GLASS_OFF)
	_hline(img, o.x + g.position.x - 2, o.x + g.end.x + 1, o.y + g.end.y + 2, F[2])
	# Rivets along the top in an exact row, and the streak each has left below it.
	var sensor := Rect2i(w / 2 - 22, 4, 44, 5)
	var rx := 30
	while rx < w - 30:
		if rx < sensor.position.x - 6 or rx > sensor.end.x + 4:
			_dot(img, o.x + rx, o.y + 6, F[5])
			_dot(img, o.x + rx + 1, o.y + 6, F[3])
			_dot(img, o.x + rx, o.y + 7, F[3])
			_dot(img, o.x + rx + 1, o.y + 7, F[0])
			if rx % 48 == 30:
				_vline(img, o.x + rx + 1, o.y + 8, o.y + 10, F[1])
		rx += 16
	# The module's cold sensor slit, dead centre.
	_fill(img, Rect2i(o + sensor.position, sensor.size), F[0])
	_hline(img, o.x + sensor.position.x + 2, o.x + sensor.end.x - 3, o.y + sensor.position.y + 2, Palette.COLD[1])
	for k: int in [9, 10, 30]:
		_dot(img, o.x + sensor.position.x + k, o.y + sensor.position.y + 2, Palette.COLD[3])
	_hline(img, o.x + sensor.position.x, o.x + sensor.end.x - 1, o.y + sensor.end.y, F[3])
	# The part number the machine stamped on it: ticks nobody can read.
	var sx := BEZEL_L + 8
	for i in 22:
		var tall := int(Rng.hash01(71, i, 0, 0x57a) * 3.0) + 1
		_vline(img, o.x + w / 2 - 30 + i * 3, o.y + h - 8 - tall, o.y + h - 8, F[1])
	# 2. The glass: flat, every other row a hair lighter.
	_fill(img, Rect2i(o + g.position, g.size), UiTheme.GLASS)
	for y in range(1, g.size.y, 2):
		_fill(img, Rect2i(o.x + g.position.x, o.y + g.position.y + y, g.size.x, 1), UiTheme.GLASS_ROW)
	# 3. The patch: the lower right is the grey casing of some other device, cut
	#    by hand, a pixel proud of the chrome and rounded where the chrome is not.
	var seam_y := int(h * 0.44)
	var seam_x := int(w * 0.64)
	for y in range(0, h + 1):
		for x in range(0, w + 1):
			if not _patch(x, y, w, h, seam_x, seam_y):
				continue
			if _rounded_out(x, y, w + 1, h + 1, 7):
				continue
			var inner := x >= g.position.x - 2 and x < g.end.x + 2 and y >= g.position.y - 2 and y < g.end.y + 2
			if inner:
				continue
			var col := A[1]
			if x == w or y == h or _rounded_out(x, y, w + 1, h + 1, 8):
				col = A[0]
			elif _patch_edge(x, y, w, h, seam_x, seam_y):
				col = Palette.INK[1]
			elif y == seam_y + 2 or x == seam_x + 2 or y == g.end.y + 3 or x == g.end.x + 3:
				col = A[2]
			else:
				# Moulded plastic, scuffed: a few short scratches running with the grain.
				var scuff := Rng.hash01(x / 5, y, 0, 0x6a)
				if scuff < 0.025:
					col = A[2]
				elif Rng.hash01(x, y, 1, 0x6a) < 0.02:
					col = A[0]
			_dot(img, o.x + x, o.y + y, col)
	# Its own lip round the glass: plain dark plastic, not violet.
	for y in range(g.position.y - 2, g.end.y + 2):
		for x in range(g.position.x - 2, g.end.x + 2):
			var ring := x < g.position.x or x >= g.end.x or y < g.position.y or y >= g.end.y
			if ring and _patch(x, y, w, h, seam_x, seam_y):
				_dot(img, o.x + x, o.y + y, A[0] if (x == g.position.x - 1 or x == g.end.x or y == g.position.y - 1 or y == g.end.y) else A[0].lerp(A[1], 0.5))
	# A moulded ridge along the casing's bottom bar, and a speaker grille in it.
	_hline(img, o.x + seam_x + 10, o.x + w - 10, o.y + h - 6, A[0])
	_hline(img, o.x + seam_x + 10, o.x + w - 10, o.y + h - 5, A[2])
	for gy in 3:
		for gx in 7:
			_dot(img, o.x + w - 72 + gx * 3, o.y + g.end.y + 5 + gy * 3, A[0])
	# 4. Solder where the two were joined, and copper jumpers bridging the cut.
	for p: Vector2i in [Vector2i(w - BEZEL_R + 4, seam_y), Vector2i(w - 5, seam_y + 1), Vector2i(seam_x, h - BEZEL_B + 6), Vector2i(seam_x + 1, h - 6)]:
		_solder(img, o + p)
	_jumper(img, o + Vector2i(seam_x - 7, h - 12), o + Vector2i(seam_x + 9, h - 12))
	_jumper(img, o + Vector2i(w - 11, seam_y - 7), o + Vector2i(w - 11, seam_y + 8))
	# 5. Screws: exact machine screws in the chrome, a brass one in the patch where
	#    the right screw was lost, and an empty hole under the tape.
	_screw(img, o + Vector2i(5, 5), false)
	_screw(img, o + Vector2i(5, h - 10), false)
	_screw(img, o + Vector2i(w - 13, h - 13), true)
	_fill(img, Rect2i(o.x + w - 10, o.y + 5, 3, 3), F[0])
	# 6. KEEP DRY scratched into the chrome, and a tally beside it.
	if w >= 280:
		_scratch(img, o + Vector2i(BEZEL_L + 10, h - 14), "KEEP DRY", 5)
		for i in 5:
			var tx := BEZEL_L + 70 + i * 3 + (4 if i == 4 else 0)
			var slant := 1 if i == 4 else 0
			_scratch_line(img, o + Vector2i(tx - slant * 9, h - 13), o + Vector2i(tx + slant * 2, h - 7), i)
	# 7. A knob off something else entirely: brown bakelite with a lit notch.
	_knob(img, o + Vector2i(w - 36, h - 10))
	# 8. The power light, cold green while awake.
	_fill(img, Rect2i(o.x + BEZEL_L + 2, o.y + 6, 3, 2), UiTheme.PHOSPHOR[3])
	_dot(img, o.x + BEZEL_L + 2, o.y + 6, UiTheme.PHOSPHOR[4])
	# 9. The cable, out of the left side and looped, bound in electrical tape.
	var cy := int(h * 0.56)
	_cable(img, o, cy)
	_tape_band(img, Rect2i(o.x - 2, o.y + cy - 4, BEZEL_L - 2, 9), Palette.RUST)
	# 10. Duct tape across the top right corner, over the crack.
	_duct(img, o, w)
	return img


## The glass's flaws that sit over content: the crack in the top right corner,
## the dead column in the left margin, one stuck violet pixel.
static func marks_image(size: Vector2i) -> Image:
	var w := size.x
	var h := size.y
	var img := Image.create_empty(w + PAD * 2, h + PAD * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var o := Vector2i(PAD, PAD)
	var g := Rect2i(o + Vector2i(BEZEL_L, BEZEL_T), size - Vector2i(BEZEL_L + BEZEL_R, BEZEL_T + BEZEL_B))
	# Stuck pixels down the left margin, with gaps where the column still works.
	var dx := g.position.x + 3
	for y in range(g.position.y, g.end.y):
		var run := int((y - g.position.y) / 23)
		if Rng.hash01(run, 0, 0, 0xdead) < 0.18:
			continue
		_dot(img, dx, y, Color(UiTheme.PHOSPHOR[0], 0.9 if (y % 2 == 0) else 0.7))
	_dot(img, g.position.x + 5, g.position.y + g.size.y / 2 + 7, UiTheme.MACHINE[1])
	# The crack: from under the tape at the corner, a few jagged runs down the
	# right margin, a star of chips at its origin. Light glints on one side, dark on the other.
	var zone := Rect2i(g.end.x - MARGIN_R + 2, g.position.y, MARGIN_R - 2, 44)
	var origin := Vector2i(g.end.x - 2, g.position.y + 1)
	var branches := [[Vector2i(-1, 1), 40], [Vector2i(-2, 1), 16], [Vector2i(0, 1), 26]]
	for bi in branches.size():
		var dir: Vector2i = branches[bi][0]
		var n: int = branches[bi][1]
		var p := origin
		for i in n:
			var step := Vector2i(dir.x if Rng.hash01(bi, i, 0, 0xc7a) < 0.55 else 0, 1 if dir.y != 0 else 0)
			if step == Vector2i.ZERO:
				step = Vector2i(0, 1)
			p += step
			if Rng.hash01(bi, i, 1, 0xc7a) < 0.2:
				p.x += 1 if Rng.hash01(bi, i, 2, 0xc7a) < 0.5 else -1
			p.x = clampi(p.x, zone.position.x, zone.end.x - 1)
			if not zone.has_point(p):
				break
			_dot(img, p.x, p.y, Color(0.75, 0.84, 0.86, 0.55 - 0.3 * float(i) / n))
			if zone.has_point(p + Vector2i(1, 0)):
				_dot(img, p.x + 1, p.y, Color(0, 0, 0, 0.5))
	for k in 7:
		var a := k * TAU / 7.0 + 0.4
		var q := origin + Vector2i(roundi(cos(a) * 3.0), roundi(sin(a) * 3.0))
		if zone.has_point(q):
			_dot(img, q.x, q.y, Color(0.75, 0.84, 0.86, 0.35))
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


static func _hline(img: Image, x0: int, x1: int, y: int, col: Color) -> void:
	_fill(img, Rect2i(x0, y, x1 - x0 + 1, 1), col)


static func _vline(img: Image, x: int, y0: int, y1: int, col: Color) -> void:
	_fill(img, Rect2i(x, y0, 1, y1 - y0 + 1), col)


static func _frame(img: Image, r: Rect2i, col: Color) -> void:
	_hline(img, r.position.x, r.end.x - 1, r.position.y, col)
	_hline(img, r.position.x, r.end.x - 1, r.end.y - 1, col)
	_vline(img, r.position.x, r.position.y, r.end.y - 1, col)
	_vline(img, r.end.x - 1, r.position.y, r.end.y - 1, col)


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


## The grey casing's share of the bezel: the right side below its cut, the
## bottom bar right of its cut. The cuts wander a pixel, made by hand.
static func _patch(x: int, y: int, w: int, h: int, seam_x: int, seam_y: int) -> bool:
	var right := x >= w - BEZEL_R and y >= seam_y + _jag(x, 0)
	var bottom := y >= h - BEZEL_B and x >= seam_x + _jag(y, 1)
	return right or bottom


static func _patch_edge(x: int, y: int, w: int, h: int, seam_x: int, seam_y: int) -> bool:
	return (x >= w - BEZEL_R and y == seam_y + _jag(x, 0)) or (y >= h - BEZEL_B and x == seam_x + _jag(y, 1))


static func _jag(t: int, salt: int) -> int:
	return int(Rng.hash01(t / 3, salt, 0, 0x7a6) * 3.0) - 1


static func _solder(img: Image, c: Vector2i) -> void:
	var S := Palette.STONE
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if absi(dx) + absi(dy) > 3:
				continue
			var col := S[3]
			if dx + dy <= -2:
				col = S[5]
			elif dx + dy >= 2:
				col = S[1]
			_dot(img, c.x + dx, c.y + dy, col)
	_dot(img, c.x - 1, c.y - 1, Color.WHITE.lerp(S[5], 0.5))


static func _jumper(img: Image, a: Vector2i, b: Vector2i) -> void:
	var C := Palette.COPPER
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / n
		var p := Vector2(a).lerp(Vector2(b), t)
		# It sags a little between its blobs.
		var sag := sin(t * PI) * 2.0
		var q := Vector2i(roundi(p.x + (sag if a.x == b.x else 0.0)), roundi(p.y + (sag if a.y == b.y else 0.0)))
		_dot(img, q.x, q.y, C[2] if i % 5 != 2 else C[3])
	_solder(img, a)
	_solder(img, b)


static func _screw(img: Image, at: Vector2i, brass: bool) -> void:
	var R := Palette.COPPER if brass else Palette.PLATE
	var size := 6 if brass else 5
	var c := Vector2(size - 1, size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c)
			if d > size * 0.5 + 0.1:
				continue
			var col := R[2] if brass else R[3]
			if d > size * 0.5 - 0.7:
				col = R[0]
			elif x + y <= 2:
				col = R[4]
			_dot(img, at.x + x, at.y + y, col)
	if brass:
		# A cross head, turned a little off square: it was not made for this.
		_dot(img, at.x + 2, at.y + 1, R[0])
		_dot(img, at.x + 2, at.y + 2, R[0])
		_dot(img, at.x + 3, at.y + 3, R[0])
		_dot(img, at.x + 3, at.y + 4, R[0])
		_dot(img, at.x + 1, at.y + 3, R[0])
		_dot(img, at.x + 4, at.y + 2, R[0])
	else:
		_hline(img, at.x + 1, at.x + 3, at.y + 2, R[0])


static func _scratch(img: Image, at: Vector2i, text: String, seed: int) -> void:
	var F := Palette.FOUND
	var x := at.x
	for i in text.length():
		var gl := UiFont.glyph(text[i])
		var jog := int(Rng.hash01(seed, i, 0, 0x5c) * 2.0)
		for r in mini(7, gl.size()):
			for cx in gl[r].length():
				if gl[r][cx] != "#":
					continue
				# A scratch through the violet shows bright metal, its groove dark below it.
				if Rng.hash01(seed, i * 16 + cx, r, 0x5d) < 0.1:
					continue
				_dot(img, x + cx, at.y + r + jog + 1, F[1])
				_dot(img, x + cx, at.y + r + jog, F[5])
		x += UiFont.glyph_width(text[i]) + 1


static func _scratch_line(img: Image, a: Vector2i, b: Vector2i, seed: int) -> void:
	var F := Palette.FOUND
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var p := Vector2(a).lerp(Vector2(b), float(i) / maxf(1.0, n))
		var q := Vector2i(roundi(p.x), roundi(p.y))
		if Rng.hash01(seed, i, 0, 0x5e) < 0.12:
			continue
		_dot(img, q.x, q.y + 1, F[1])
		_dot(img, q.x, q.y, F[5])


static func _knob(img: Image, c: Vector2i) -> void:
	var E := Palette.EARTH
	for y in range(-5, 6):
		for x in range(-5, 6):
			var d := Vector2(x, y).length()
			if d > 5.2:
				continue
			var col := E[2]
			if d > 4.3:
				col = E[0] if (x + y + 20) % 2 == 0 else E[1]
			elif x + y < -3:
				col = E[3]
			elif x + y > 3:
				col = E[1]
			_dot(img, c.x + x, c.y + y, col)
	# Its pointer, turned up and right to wherever it was last left.
	_dot(img, c.x + 1, c.y - 1, E[5])
	_dot(img, c.x + 2, c.y - 2, E[5])
	_dot(img, c.x + 3, c.y - 3, E[4])
	# It casts a shade on the casing.
	for k in 4:
		_dot(img, c.x + 3 + k / 2, c.y + 5, Color(0, 0, 0, 0.35))


static func _cable(img: Image, o: Vector2i, cy: int) -> void:
	var I := Palette.INK
	# Out through the side, down in a loop hanging past the edge, and back in.
	var pts: Array[Vector2i] = []
	for i in 22:
		# A U hanging off the side: out, down and back in, drawn as one bent line.
		var t := float(i) / 21.0
		var a := t * PI
		pts.append(Vector2i(o.x - roundi(sin(a) * 6.0), o.y + cy + 1 + roundi(t * 16.0)))
	for p in pts:
		_dot(img, p.x, p.y, Palette.ASH[1])
		_dot(img, p.x, p.y + 1, I[1])
		_dot(img, p.x - 1, p.y, Palette.ASH[2])


static func _tape_band(img: Image, r: Rect2i, ramp: Array[Color]) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var col := ramp[2]
			if y == r.position.y:
				col = ramp[3]
			elif y == r.end.y - 1:
				col = ramp[1]
			elif (x + y) % 7 == 0:
				col = ramp[3]
			# The torn end is ragged.
			if x == r.position.x and Rng.hash01(x, y, 0, 0x7ae) < 0.5:
				continue
			_dot(img, x, y, col)
	# The gloss of fresh electrical tape.
	_hline(img, r.position.x + 3, r.position.x + 7, r.position.y + 2, Color(1, 1, 1, 0.25))


## Silver duct tape laid across the corner on the diagonal, its ends torn, its
## weave showing, lifting a little at one edge.
static func _duct(img: Image, o: Vector2i, w: int) -> void:
	var A := Palette.ASH
	var corner := Vector2(o.x + w - 1, o.y)
	var axis := Vector2(1, 1).normalized()
	var across := Vector2(1, -1).normalized()
	for y in range(o.y - 6, o.y + 34):
		for x in range(o.x + w - 40, o.x + w + 6):
			var p := Vector2(x, y) - corner
			var along := p.dot(axis)
			var off := p.dot(across)
			if absf(off + 16.0) > 6.0:
				continue
			var tear := (Rng.hash01(roundi(off), 0, 0, 0xd0c) - 0.5) * 3.0
			if along < -18.0 + tear or along > 22.0 + tear:
				continue
			var col := A[4]
			if absf(off + 16.0) > 5.0:
				col = A[3]
			elif (x * 2 + y) % 4 == 0:
				col = A[3]
			if off + 16.0 > 4.5:
				col = A[2]
			_dot(img, x, y, col)
	# Where it lifts, a line of shade under its edge.
	for t in range(-14, 18):
		var q := corner + axis * t + across * -22.5
		_dot(img, roundi(q.x), roundi(q.y), Color(0, 0, 0, 0.3))
