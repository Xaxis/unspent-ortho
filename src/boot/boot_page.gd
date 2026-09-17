class_name BootPage
extends CanvasLayer
## The loading page: what a player sees while a world is made, instead of a
## frozen window. It runs BootStages (code, world, view, the first view, the
## scene) with a drawn progress line, then hands over to the title or the game
## and lifts off it.
##
##   BootPage.open_game(parent, options)    every new game (the title's New game too)
##   BootPage.open_title(parent, options)   a player's first start
##   tools/shot.sh shots/export/loading.png --scene=loading --progress=0.4
##
## With threads, code, world and view are made on the worker pool while the page
## draws. Without (the no-threads web build) every stage runs on the main thread,
## one per frame. The page's own script references nothing heavy: the game's
## scripts compile inside the first stage, not before the first frame.
##
## Headless runs (tests) have no frames to keep: open_* builds the scene at once.

signal handed_over(scene: Node)

## The one script that names the scenes (Game, UiTitle). Everything the page
## makes goes through it: see its header for why that matters at exit.
const SCENES_SCRIPT := "res://src/boot/boot_scenes.gd"
const WORLD_SCRIPT := "res://src/boot/boot_world.gd"
## The share of the line the web shell fills while the engine downloads
## (src/boot/shell.html SHELL_SHARE): the first page on the web starts there.
const SHELL_SHARE := 0.12

## The page is the glass the title's slate wakes on, so there is no flash at the
## hand-over. The slate's glass and phosphor (UiTheme: GLASS_OFF, GHOST, FAINT, TEXT,
## BRIGHT, TEXT_DIM), written out so this page names nothing heavy: the loading
## page is the slate powering up.
##
## Palette is the one class it does name: eighty lines of const ramps with no
## dependencies of its own, so the bezel's violet chrome, its grey casing patch
## and its tape are the machines' own colours rather than a copy that can drift.
const GLASS := Color("#060a0c")
## The glass once it is lit (UiTheme.GLASS, GLASS_ROW): the screen inside the bezel.
const SCREEN_GLASS := Color("#0b1315")
const SCREEN_ROW := Color("#0d1618")
const RAIL := Color("#173029")
const TICK := Color("#2b5c4c")
const LIT := Color("#87d9b5")
const LIT_SOFT := Color("#1f443a")
const HEAD := Color("#c9fbe2")
const WORDS := Color("#4f9b81")
const SCAN := Color(0.53, 0.85, 0.71, 0.04)
## The island, sketched once it exists, as the slate's survey draws it: the coast
## and contours in phosphor, rivers a cold step, the machines' grid in the stolen
## module's violet (UiTheme.MACHINE), villages lit.
const COAST := Color("#4f9b81")
const CONTOUR := Color("#173029")
const RIVER := Color("#2b5c4c")
const GRID := Color("#4b4274")
const VILLAGE := Color("#c9fbe2")
const SKETCH := 112
const SKETCH_AT := Vector2i(264, 104)
const SKETCH_DRAW_SECONDS := 0.45

const LINE_Y := 248
const LINE_X0 := 216
const LINE_X1 := 424

## The device, and the glass in it: UiSlate.DEVICE and UiSlate.glass_of(DEVICE),
## written out for the same reason the colours are (tests/export/test_boot_page
## holds them to the slate's own). This is the device an app opens on, so the
## first screen of the game is the screen every screen after it is.
const DEVICE := Rect2i(8, 5, 624, 350)
const SCREEN := Rect2i(24, 19, 592, 316)
## The bar along the top of the glass and the strip along its foot.
const STATUS_H := 12
const KEYS_H := 12
## Seconds the chrome takes to come up, from a cold start. Following the web
## shell there is nothing to come up: the shell draws the same device while the
## engine downloads (src/boot/shell.html), and `lit()` hands it over already on.
const BEZEL_IN := 0.5
## The bezel's ink, all from the machines' own ramps.
const CHROME := Palette.FOUND
const CASING := Palette.ASH
const SENSOR := Palette.COLD
## Where light catches broken glass, and the runs the crack makes out from under
## the tape as [sideways step, length] — UiSlate.marks_image bakes the same three
## into every other screen, so the glass is broken the same way on all of them.
const CHIP := Color(0.75, 0.84, 0.86)
const CRACK := [[-1, 40], [-2, 16], [0, 26]]
## Seconds the page takes to lift off the scene once it is up.
const LIFT_SECONDS := 0.35

## THE DEADLINES. Every stage that waits on something the page does not control
## gives up at one of these, because a loading page that never ends is the worst
## failure this screen has: the player cannot tell it from a slow machine, and
## there is nothing to press. Measured on this laptop (six clean boots, seed 1,
## threads): the whole line runs 5.8-6.5 s, of which `draw` is 3.1-3.3 s and
## `near` 0.46-0.55 s. Two boots in an earlier five sat at 36.5 and 37.4 s and
## never handed over at all — an off-screen window stops being composited on
## macOS, `RenderingServer.frame_post_draw` stops firing, and `draw` waits for a
## frame that is never coming.
##
## So: three times the worst clean measurement for the stage that compiles the
## first frame's shaders (which is genuinely slow on the web and must not be cut
## short), and a shorter one for the stages that are only ever waiting on work
## already in flight. The line cannot now exceed about 25 s even if every one of
## them stalls, against no bound at all before — and in the case that actually
## happens, where no frame arrives at all, `draw` gives up at DRAW_SILENT_MS and
## the whole line is under eight seconds.
const DRAW_DEADLINE_MS := 10000.0
const WAIT_DEADLINE_MS := 5000.0
## ...and how long `draw` waits for its FIRST frame before it concludes that no
## frames are coming at all. The page is drawing itself while that stage waits,
## so one would have arrived long before this: measured over six boots, `draw`
## took 3.5-5.9 s in total and the first frame of every one of them landed inside
## two and a half. Four seconds leaves a slow web compile room and still halves
## the worst case, and when it does fire the log says which stage gave up.
const DRAW_SILENT_MS := 4000.0

## False until the first page has planned: only that one follows the web shell.
static var _after_shell := false

var stages := BootStages.new()
var threaded := true
var options: BootOptions
## "game", "title", or "preview" (a still page for shots).
var kind := "game"
## Preview only: the line is held here.
var held_progress := -1.0
var scene: Node

var _parent: Node
## BootWorld, loaded inside the first stage (a member: lambdas copy locals).
var _bw: GDScript
var _world: Variant = null
var _view: Variant = null
var _focus := Vector2.ZERO
## Made on the worker with the view; read on the main thread only after that stage.
var _sketch_image: Image
var _sketch: ImageTexture
var _sketch_t := 0.0
var _mark := Vector2i(-1, -1)
## The glass, and the ink on it (sketch, line, words): the ink lifts first.
var _sheet: Control
## What the static layer was last drawn at (`_chrome_key`); off the scale until
## the first frame, so it always draws once.
var _sheet_key := Vector2(-1.0, -1.0)
var _ink: Control
var _t := 0.0
var _shown := 0
var _lift := -1.0
## Off the screen (and out of the boot_page group), with only _after_lift left.
var _lifted := false
var _handed := false
## Frames drawn since the scene was made (-1 before).
var _drawn := -1
## When the `draw` stage began waiting (msec), for DRAW_SILENT_MS.
var _draw_from := 0


## True where slow jobs may go to the worker pool (not the no-threads web build).
static func has_threads() -> bool:
	return not OS.has_feature("web") or OS.has_feature("threads")


static func headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Start a game with `o` under `parent` through the loading page. Returns the page,
## or the game itself when headless.
static func open_game(parent: Node, o: BootOptions) -> Node:
	if headless():
		return BootPage.make_game(parent, o)
	var page := BootPage.new()
	page._plan(parent, o, "game")
	parent.add_child(page)
	return page


## Show the title under `parent`, its first coast made on the loading page.
static func open_title(parent: Node, o: BootOptions) -> Node:
	if headless():
		return BootPage.make_title(parent, o)
	var page := BootPage.new()
	page._plan(parent, o, "title")
	parent.add_child(page)
	return page


## A still loading page for shots of the page itself: the line held at
## o.progress, with the sketch of o's world (made now) and its start marked.
static func preview(parent: Node, o: BootOptions) -> Node:
	var page := BootPage.new()
	page.kind = "preview"
	page.options = o
	page.held_progress = clampf(o.progress, 0.0, 1.0)
	var bw := load(WORLD_SCRIPT) as GDScript
	var w: Variant = bw.call("world", o.seed_value, o.size)
	page._sketch_image = BootPage._sketch_of(bw, w)
	page._mark = Vector2i(((w.spawn as Vector2) * SKETCH / float(w.size)).floor())
	page._sketch_t = SKETCH_DRAW_SECONDS
	for s: Array in [[&"code", "waking"], [&"world", "raising the land"], [&"view", "laying out the ground"], [&"near", "drawing what is near"], [&"compiled", "setting out"], [&"start", "setting out"], [&"draw", "looking up"]]:
		page.stages.add(s[0], s[1], 500.0, func() -> void: pass)
	parent.add_child(page)
	return page


static func _sketch_of(bw: GDScript, w: Variant) -> Image:
	return bw.call("sketch", w, SKETCH, {"coast": COAST, "contour": CONTOUR, "river": RIVER, "grid": GRID, "village": VILLAGE})


## Make the game under `parent` now, in this frame (shots, headless runs, and the
## page's own hand-over). Compiles the game's scripts if nothing has yet.
static func make_game(parent: Node, o: BootOptions) -> Node:
	return (load(SCENES_SCRIPT) as GDScript).call("make_game", parent, o)


## Make the title under `parent` now, in this frame.
static func make_title(parent: Node, o: BootOptions) -> Node:
	return (load(SCENES_SCRIPT) as GDScript).call("make_title", parent, o)


## Lay out the stages that make `what` ("game" or "title") for `o` under `parent`.
## `threads` false runs every stage on the main thread (the no-threads web build).
func _plan(parent: Node, o: BootOptions, what: String, threads: bool = BootPage.has_threads()) -> void:
	_parent = parent
	options = o
	kind = what
	threaded = threads
	# The first page on the web continues the shell's line instead of starting it again.
	if OS.has_feature("web") and not BootPage._after_shell:
		stages.start_at = SHELL_SHARE
	BootPage._after_shell = true
	# What must be compiled before the scene is made. With threads, a title's page
	# also starts the game's systems compiling once the title is up (_after_lift).
	# The landscape files come FIRST: world gen cannot lay a tile without every
	# one of them compiled, so asking for them ahead of everything else lets the
	# loader threads have them ready by the time the world stage wants them,
	# instead of the world stage stopping to load them one at a time behind the
	# systems (a second of the start budget, measured).
	var needed := BiomeRegistry.scripts()
	needed.append(SCENES_SCRIPT)
	if what == "game":
		needed.append_array(BootPage.system_scripts())
	if threaded:
		# The scene's scripts compile on loader threads beside the world.
		stages.add(&"code", "waking", 500.0, func() -> void:
			for path in needed:
				ResourceLoader.load_threaded_request(path, "GDScript")
			_bw = load(WORLD_SCRIPT) as GDScript)
	else:
		stages.add(&"code", "waking", 500.0, func() -> void:
			_bw = load(WORLD_SCRIPT) as GDScript, false)
		# One script a frame (each pulls in what it uses).
		var left := Array(needed)
		stages.add(&"code2", "waking", 700.0, func() -> bool:
			if not left.is_empty():
				load(str(left.pop_front()))
			return left.is_empty(), false, WAIT_DEADLINE_MS)
	stages.add(&"world", "raising the land", 1600.0, func() -> void:
		_world = _bw.call("world", o.seed_value, o.size))
	stages.add(&"view", "laying out the ground", 500.0, func() -> void:
		_view = _bw.call("view", _world)
		# Where the first view is: the player's start, or where the title's drift begins.
		if what == "game":
			_focus = _bw.call("start_of", _world, o)
		else:
			_focus = (load(SCENES_SCRIPT) as GDScript).call("opening", _world)
		_sketch_image = BootPage._sketch_of(_bw, _world)
		_mark = Vector2i((_focus * SKETCH / float(_world.size)).floor()))
	# Main thread, one chunk a step: the chunks become nodes of the view.
	# Given up on rather than waited out: the view streams the rest in anyway, so
	# a slow chunk costs a moment of empty ground, not a page that never ends.
	stages.add(&"near", "drawing what is near", 900.0, func() -> bool:
		return int(_bw.call("build_near", _view, _focus)) == 0, false, WAIT_DEADLINE_MS)
	if threaded:
		# Wait, a frame at a time, for the loader threads to finish the scripts:
		# taking them before they are done (load_threaded_get) held the page still
		# for over a second on the web.
		# Given up on rather than waited out: `start` takes them with
		# load_threaded_get, which blocks, so the cost of giving up here is one
		# long frame and not a line that never reaches its end.
		stages.add(&"compiled", "setting out", 400.0, func() -> bool:
			for path in needed:
				if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					return false
			return true, false, WAIT_DEADLINE_MS)
	stages.add(&"start", "setting out", 300.0, func() -> void:
		if threaded:
			for path in needed:
				ResourceLoader.load_threaded_get(path)
		_bw.call("offer", _world, _view)
		_world = null
		_view = null
		scene = BootPage.make_game(_parent, o) if what == "game" else BootPage.make_title(_parent, o), false)
	# A world's first frame compiles its shaders and stalls (seconds on the web):
	# the line ends when that frame is drawn, not before — but it ends.
	stages.add(&"draw", "looking up", 1200.0, func() -> bool:
		if _drawn < 0:
			_drawn = 0
			_draw_from = Time.get_ticks_msec()
			RenderingServer.frame_post_draw.connect(_on_drawn)
		if _drawn >= 2 or BootPage.headless():
			return true
		# NOTHING has been drawn at all. The page itself is being drawn every
		# frame while this waits, so one frame would have arrived by now if the
		# window were being composited: it is not, and the whole of the long
		# deadline buys a stall nobody can see instead of the world's first frame.
		return Time.get_ticks_msec() - _draw_from > int(DRAW_SILENT_MS) and _drawn == 0,
		false, DRAW_DEADLINE_MS)


## Every system script the game loads (Game._system_files), as res:// paths.
## ResourceLoader lists what an export holds by its source names.
static func system_scripts() -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory("res://src/systems"):
		if f.ends_with(".gd") and f.substr(0, 2).is_valid_int():
			out.append("res://src/systems/" + f)
	out.sort()
	return out


func _ready() -> void:
	name = "boot"
	layer = 100
	add_to_group(&"boot_page")
	_sheet = Control.new()
	_sheet.name = "sheet"
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.draw.connect(_draw_glass)
	add_child(_sheet)
	_ink = Control.new()
	_ink.name = "ink"
	_ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.draw.connect(_draw_page)
	add_child(_ink)
	if OS.has_feature("web") and stages.start_at > 0.0:
		RenderingServer.frame_post_draw.connect(_hand_from_shell, CONNECT_ONE_SHOT)


## The web shell drew this page while the engine downloaded; now that the page is
## on the canvas, it goes (after the browser has shown that frame).
func _hand_from_shell() -> void:
	JavaScriptBridge.eval("requestAnimationFrame(() => requestAnimationFrame(() => window.unspentShellDone && window.unspentShellDone()))")


func _process(delta: float) -> void:
	_t += delta
	if not _lifted:
		# The chrome is a thousand primitives — the duct tape alone is 546 pixel
		# calls and the stuck-pixel column another 316 — and none of it changes
		# once the slate is up. Redrawing it sixty times a second is the main
		# thread the no-threads web build needs for making a world.
		var key := _chrome_key()
		if key.distance_squared_to(_sheet_key) > 0.000004:
			_sheet_key = key
			_sheet.queue_redraw()
		_ink.queue_redraw()
	if _lift >= 0.0:
		_ink.modulate.a = 1.0 - clampf(_lift / (LIFT_SECONDS * 0.5), 0.0, 1.0)
	var cur := stages.current()
	if _sketch == null and _sketch_image != null and (kind == "preview" or cur == null or not cur.worker):
		_sketch = ImageTexture.create_from_image(_sketch_image)
		if kind != "preview":
			print("boot sketch %s: the island is drawn in" % kind)
	elif _sketch != null:
		_sketch_t += delta
	if kind == "preview":
		return
	if _lift >= 0.0:
		_lift += delta
		if _lift >= LIFT_SECONDS and not _lifted:
			_lifted = true
			remove_from_group(&"boot_page")
			hide()
		if _lifted and _after_lift():
			queue_free()
		return
	if _handed:
		_lift = 0.0
		return
	# Draw the page once before the first stage, so the first frame is the page.
	_shown += 1
	if _shown < 2:
		return
	if not stages.step(threaded):
		return
	_handed = true
	var parts := PackedStringArray()
	var t := stages.timings()
	for k: StringName in t:
		parts.append("%s %d" % [k, t[k]])
	print("boot stages %s (%s): %s ms" % [kind, "threads" if threaded else "no threads", ", ".join(parts)])
	# The longest the page stood still in each stage: a frame it could not draw.
	parts.clear()
	var held := stages.held()
	for k: StringName in held:
		parts.append("%s %d" % [k, held[k]])
	print("boot held %s: %s ms" % [kind, ", ".join(parts)])
	# Said out loud, because a start that went past a deadline is a start that
	# went wrong and every other symptom of it is invisible.
	var late := stages.gave_up()
	if not late.is_empty():
		print("boot %s gave up waiting on: %s" % [kind, ", ".join(late)])
	handed_over.emit(scene)


## What a page still does once it has lifted; true when there is nothing left.
## A title's page (threads only) waits for the coast to finish streaming in, then
## has the loader threads compile the game's systems, so New game waits on none of
## them. Asked for as the title opened, they took the pool from the coast's chunks
## and the title's first full frame came 1.5 s later on the web.
func _after_lift() -> bool:
	if kind != "title" or not threaded:
		return true
	if is_instance_valid(scene) and scene.is_inside_tree():
		var view: Variant = scene.get("view")
		if view == null or int(view.call("pending")) > 0:
			return false
	for path in BootPage.system_scripts():
		ResourceLoader.load_threaded_request(path, "GDScript")
	return true


func _on_drawn() -> void:
	_drawn += 1


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_drawn):
		RenderingServer.frame_post_draw.disconnect(_on_drawn)
	if RenderingServer.frame_post_draw.is_connected(_hand_from_shell):
		RenderingServer.frame_post_draw.disconnect(_hand_from_shell)
	# A page closed mid-way (the game quit) waits out its worker, and must not
	# leave a view nobody frees.
	stages.wait()
	if _view != null and is_instance_valid(_view) and not (_view as Node).is_inside_tree():
		(_view as Node).free()
		_view = null


func progress() -> float:
	return held_progress if held_progress >= 0.0 else stages.progress()


## How far the slate has powered up, 0..1. A still page for shots is already on,
## and so is a page that follows the web shell: the shell has drawn the same
## device for the seconds the wasm took (src/boot/shell.html), so this page picks
## it up lit rather than powering it up a second time in front of the player.
func lit() -> float:
	if kind == "preview" or stages.start_at > 0.0:
		return 1.0
	return clampf(_t / BEZEL_IN, 0.0, 1.0)


## The two numbers everything on the static layer is drawn from: how far the
## glass has left to fade, and how far the slate has powered up. While neither
## moves, that layer does not redraw.
func _chrome_key() -> Vector2:
	var a := 1.0
	if _lift >= 0.0:
		a = 1.0 - clampf((_lift - LIFT_SECONDS * 0.4) / (LIFT_SECONDS * 0.6), 0.0, 1.0)
	return Vector2(a, lit())


## The glass goes once the ink on it has faded. The device and the glass's own
## flaws are here rather than on the page: they never change while a stage runs,
## and they are the expensive half of the drawing.
func _draw_glass() -> void:
	var key := _chrome_key()
	UiDraw.rect(_sheet, Rect2i(0, 0, 640, 360), Color(GLASS, key.x))
	_draw_device(_sheet, key.x * key.y)
	_draw_marks(_sheet, key.x * key.y)


## The device the page is a screen of: violet chrome stolen off a machine, a
## grey casing patched onto its lower right, duct tape over the cracked corner,
## KEEP DRY scratched into it (docs/ART.md §9). The loading page was the one
## screen in the game that was not the slate, and it is the first one anybody
## sees. Drawn from rects at whole pixels, not baked: it must be on the very
## first frame, and a bake takes a third of a second the start-up cannot spend.
func _draw_device(ci: CanvasItem, a: float) -> void:
	if a <= 0.0:
		return
	var d := DEVICE
	var g := SCREEN
	var face := CHROME[1].lerp(Palette.PLATE[1], 0.35)
	# 1. The chrome: one violet face, chamfered corners, lit along the top and
	#    left, one shade step along the bottom and right. Exact, as FOUND is.
	UiDraw.rect(ci, d, Color(face, a))
	for k in 4:
		var n := 4 - k
		for y: int in [d.position.y + k, d.end.y - 1 - k]:
			UiDraw.rect(ci, Rect2i(d.position.x, y, n, 1), Color(GLASS, a))
			UiDraw.rect(ci, Rect2i(d.end.x - n, y, n, 1), Color(GLASS, a))
	UiDraw.hline(ci, d.position.x + 4, d.end.x - 5, d.position.y, Color(CHROME[0], a))
	UiDraw.hline(ci, d.position.x + 4, d.end.x - 5, d.position.y + 1, Color(CHROME[3], a))
	UiDraw.hline(ci, d.position.x + 4, d.end.x - 5, d.position.y + 2, Color(CHROME[2], a))
	UiDraw.vline(ci, d.position.x + 1, d.position.y + 4, d.end.y - 5, Color(CHROME[2], a))
	UiDraw.hline(ci, d.position.x + 4, d.end.x - 5, d.end.y - 2, Color(CHROME[0].lerp(CHROME[1], 0.5), a))
	UiDraw.vline(ci, d.end.x - 2, d.position.y + 4, d.end.y - 5, Color(CHROME[0].lerp(CHROME[1], 0.5), a))
	# One rubbed edge: years of a thumb along the top, worn to bright metal.
	UiDraw.hline(ci, d.position.x + 112, d.position.x + 256, d.position.y + 1, Color(CHROME[5], a))
	# 2. The plates its frame is built of, and the vent slots cut down the side.
	for sx: int in [d.position.x + 193, d.position.x + 430]:
		UiDraw.vline(ci, sx, d.position.y + 3, g.position.y - 3, Color(CHROME[0], a))
		UiDraw.vline(ci, sx + 1, d.position.y + 3, g.position.y - 3, Color(CHROME[2], a))
	for i in 9:
		UiDraw.rect(ci, Rect2i(d.position.x + 6, d.position.y + 115 + i * 4, 5, 2), Color(CHROME[0], a))
		UiDraw.hline(ci, d.position.x + 6, d.position.x + 10, d.position.y + 117 + i * 4, Color(CHROME[2], a))
	# 3. Rivets along the top in an exact row, and the module's cold sensor slit.
	var slit := Rect2i(320 - 22, d.position.y + 4, 44, 5)
	var rx := d.position.x + 30
	while rx < d.end.x - 30:
		if rx < slit.position.x - 6 or rx > slit.end.x + 4:
			UiDraw.rect(ci, Rect2i(rx, d.position.y + 6, 2, 1), Color(CHROME[5], a))
			UiDraw.rect(ci, Rect2i(rx, d.position.y + 7, 2, 1), Color(CHROME[0], a))
		rx += 16
	UiDraw.rect(ci, slit, Color(CHROME[0], a))
	UiDraw.hline(ci, slit.position.x + 2, slit.end.x - 3, slit.position.y + 2, Color(SENSOR[1], a))
	for k: int in [9, 10, 30]:
		UiDraw.px(ci, slit.position.x + k, slit.position.y + 2, Color(SENSOR[3], a))
	UiDraw.hline(ci, slit.position.x, slit.end.x - 1, slit.end.y, Color(CHROME[3], a))
	# 4. The grey casing cut off some other device and soldered onto the corner.
	var seam_x := d.position.x + 399
	var seam_y := d.position.y + 154
	UiDraw.rect(ci, Rect2i(d.end.x - 16, seam_y, 16, d.end.y - seam_y), Color(CASING[1], a))
	UiDraw.rect(ci, Rect2i(seam_x, d.end.y - 20, d.end.x - seam_x, 20), Color(CASING[1], a))
	UiDraw.hline(ci, d.end.x - 16, d.end.x - 1, seam_y, Color(Palette.INK[1], a))
	UiDraw.vline(ci, seam_x, d.end.y - 20, d.end.y - 1, Color(Palette.INK[1], a))
	UiDraw.hline(ci, seam_x + 10, d.end.x - 10, d.end.y - 6, Color(CASING[0], a))
	UiDraw.hline(ci, seam_x + 10, d.end.x - 10, d.end.y - 5, Color(CASING[2], a))
	for gy in 3:
		for gx in 7:
			UiDraw.rect(ci, Rect2i(d.end.x - 72 + gx * 3, g.end.y + 5 + gy * 3, 1, 1), Color(CASING[0], a))
	# 5. Two machine screws, and the brass one where the right screw was lost.
	for s: Vector2i in [Vector2i(d.position.x + 5, d.position.y + 5), Vector2i(d.position.x + 5, d.end.y - 10)]:
		UiDraw.rect(ci, Rect2i(s.x, s.y, 5, 5), Color(Palette.PLATE[3], a))
		UiDraw.frame(ci, Rect2i(s.x, s.y, 5, 5), Color(Palette.PLATE[0], a))
		UiDraw.hline(ci, s.x + 1, s.x + 3, s.y + 2, Color(Palette.PLATE[0], a))
	UiDraw.rect(ci, Rect2i(d.end.x - 13, d.end.y - 13, 6, 6), Color(Palette.COPPER[2], a))
	UiDraw.frame(ci, Rect2i(d.end.x - 13, d.end.y - 13, 6, 6), Color(Palette.COPPER[0], a))
	# 6. KEEP DRY scratched into the chrome, the power light, the lip and the glass.
	UiDraw.text(ci, Vector2i(d.position.x + 26, d.end.y - 15), "KEEP DRY", Color(CHROME[5], a * 0.85))
	UiDraw.rect(ci, Rect2i(d.position.x + 18, d.position.y + 6, 3, 2), Color(LIT, a))
	UiDraw.frame(ci, g.grow(2), Color(CHROME[0].lerp(CHROME[1], 0.4), a))
	UiDraw.frame(ci, g.grow(1), Color(GLASS, a))
	UiDraw.rect(ci, g, Color(SCREEN_GLASS, a))
	for y in range(g.position.y + 1, g.end.y, 2):
		UiDraw.hline(ci, g.position.x, g.end.x - 1, y, Color(SCREEN_ROW, a))
	# 7. Duct tape across the top right corner, over the crack under it.
	_draw_tape(ci, a)


## Silver duct tape laid across the corner on the diagonal, its ends torn, its
## weave showing, lifting a little at one edge — UiSlate._duct in rects rather
## than baked pixels. Without the shade under the lifted edge it read as a
## speckled blob rather than as tape stuck over a broken corner.
func _draw_tape(ci: CanvasItem, a: float) -> void:
	var corner := Vector2(DEVICE.end.x - 1, DEVICE.position.y)
	var axis := Vector2(1, 1).normalized()
	var across := Vector2(1, -1).normalized()
	for t in range(-23, 27):
		var mid := corner + axis * t + across * -16.0
		for off in range(-6, 7):
			# Torn, not cut: how far the tape runs varies across its width.
			var tear := (Rng.hash01(off, 0, 0, 0xd0c) - 0.5) * 3.0
			if t < -19.0 + tear or t > 22.0 + tear:
				continue
			var q := mid + across * off
			var col := CASING[4] if absi(off) < 5 else CASING[3]
			if off > 4:
				col = CASING[2]
			elif (roundi(q.x) * 2 + roundi(q.y)) % 4 == 0:
				col = CASING[3]
			UiDraw.px(ci, roundi(q.x), roundi(q.y), Color(col, a))
	for t in range(-14, 18):
		var q := corner + axis * t + across * -22.5
		UiDraw.px(ci, roundi(q.x), roundi(q.y), Color(0, 0, 0, a * 0.35))
		var r := corner + axis * t + across * -9.5
		UiDraw.px(ci, roundi(r.x), roundi(r.y), Color(0, 0, 0, a * 0.2))


func _draw_page() -> void:
	var ci := _ink
	# A faint band drifting down the glass: the page is alive while a stage runs.
	var g := SCREEN
	var band_y := g.position.y + int(fmod(_t * 22.0, float(g.size.y + 40))) - 20
	UiDraw.rect(ci, Rect2i(g.position.x, maxi(band_y, g.position.y), g.size.x, clampi(14, 0, g.end.y - maxi(band_y, g.position.y))), SCAN)
	_draw_status(ci)
	_draw_sketch(ci)
	var p := progress()
	var x0 := LINE_X0
	var x1 := LINE_X1
	var span := x1 - x0
	UiDraw.hline(ci, x0, x1, LINE_Y, RAIL)
	# A tick where each stage ends (and where the shell's download did), lit once it has.
	for at in _tick_fractions():
		var tx := x0 + int(round(at * span))
		UiDraw.vline(ci, tx, LINE_Y - 3, LINE_Y - 1, LIT if p >= at - 0.0005 else TICK)
	var head := x0 + int(round(p * span))
	if head > x0:
		UiDraw.hline(ci, x0, head, LINE_Y, LIT)
		UiDraw.hline(ci, x0, head, LINE_Y + 1, LIT_SOFT)
	# The head: two bright pixels that breathe, so a long stage still shows life.
	var breathe := 0.65 + 0.35 * sin(_t * 5.0)
	UiDraw.rect(ci, Rect2i(head - 1, LINE_Y, 2, 1), Color(HEAD, breathe))
	var cur := stages.current()
	var words := cur.label if cur != null else "looking up"
	if held_progress >= 0.0:
		words = _label_at(p)
	UiDraw.text(ci, Vector2i(x0, LINE_Y - 16), words, WORDS)


## The slate's status bar and its key strip, the two things every app on this
## device has: the page is one of them, so the empty field the island used to
## float in is furnished the way the rest of the slate is.
func _draw_status(ci: CanvasItem) -> void:
	var a := lit()
	if a <= 0.0:
		return
	var g := SCREEN
	var x := g.position.x + 10
	var y := g.position.y + 2
	UiDraw.hline(ci, x - 2, g.end.x - 14, g.position.y + STATUS_H, Color(RAIL, a))
	UiDraw.text(ci, Vector2i(x, y), "slate", Color(HEAD, a))
	UiDraw.text_right(ci, g.end.x - 14, y, "island %d" % (options.seed_value if options != null else 0), Color(WORDS, a))
	# The foot strip: what it is doing, in the place an app names its keys.
	var fy := g.end.y - KEYS_H + 1
	UiDraw.hline(ci, x - 2, g.end.x - 14, fy - 2, Color(RAIL, a))
	UiDraw.text(ci, Vector2i(x, fy), "opening a world" if kind != "title" else "opening", Color(WORDS, a))
	UiDraw.text_right(ci, g.end.x - 14, fy, "%d%%" % roundi(progress() * 100.0), Color(WORDS, a))
	_draw_stages(ci, a)


## What the slate has done and what is left, as a list down the left margin: the
## work is real and saying it fills the glass the way an app's list pane does.
## The right margin stays clear, because that is where the crack is.
func _draw_stages(ci: CanvasItem, a: float) -> void:
	var rows: Array[String] = []
	var seen := {}
	for s in stages.stages:
		if seen.has(s.label):
			continue
		seen[s.label] = true
		rows.append(s.label)
	if rows.is_empty():
		return
	var top := SKETCH_AT.y + SKETCH / 2 - rows.size() * 11 / 2
	var here := stages.current()
	var doing := _label_at(progress()) if held_progress >= 0.0 else (here.label if here != null else rows[-1])
	var past := true
	for i in rows.size():
		var y := top + i * 11
		var now := rows[i] == doing
		if now:
			past = false
		# No word on the glass is ever dimmer than WORDS (UiTheme.TEXT_DIM): what a
		# stage is up to is said by its tick, not by dimming the words out of reach.
		var col := HEAD if now else WORDS
		UiDraw.rect(ci, Rect2i(SCREEN.position.x + 10, y + 3, 3, 3), Color(LIT if past else (HEAD if now else TICK), a))
		if now:
			UiDraw.rect(ci, Rect2i(SCREEN.position.x + 9, y + 2, 5, 5), Color(HEAD, a * (0.3 + 0.35 * sin(_t * 5.0) + 0.35)))
		UiDraw.text(ci, Vector2i(SCREEN.position.x + 18, y), rows[i], Color(col, a))


## The glass is salvaged and says so: a column of stuck pixels down the left
## margin, and the crack in the top right corner under the tape (docs/ART.md §9).
## Both live in the margins, clear of everything the page writes.
func _draw_marks(ci: CanvasItem, a: float) -> void:
	if a <= 0.0:
		return
	var g := SCREEN
	var dx := g.position.x + 3
	for y in range(g.position.y, g.end.y):
		if (y / 23) % 5 == 2:
			continue
		UiDraw.px(ci, dx, y, Color(RAIL, a * (0.9 if y % 2 == 0 else 0.6)))
	UiDraw.px(ci, g.position.x + 5, g.position.y + g.size.y / 2 + 7, Color(GRID, a))
	# The crack: three jagged runs out from under the tape and a star of chips at
	# their origin, the shape UiSlate bakes into every other screen. One
	# near-straight hairline read as a scratch at 640x360; broken glass branches.
	var zone := Rect2i(g.end.x - 12, g.position.y, 12, 44)
	var origin := Vector2i(g.end.x - 2, g.position.y + 1)
	for bi in CRACK.size():
		var run: Array = CRACK[bi]
		var dx2: int = run[0]
		var n: int = run[1]
		var p := origin
		for i in n:
			p += Vector2i(dx2 if Rng.hash01(bi, i, 0, 0xc7a) < 0.55 else 0, 1)
			if Rng.hash01(bi, i, 1, 0xc7a) < 0.2:
				p.x += 1 if Rng.hash01(bi, i, 2, 0xc7a) < 0.5 else -1
			p.x = clampi(p.x, zone.position.x, zone.end.x - 1)
			if not zone.has_point(p):
				break
			UiDraw.px(ci, p.x, p.y, Color(CHIP, a * (0.55 - 0.3 * float(i) / n)))
			if zone.has_point(p + Vector2i(1, 0)):
				UiDraw.px(ci, p.x + 1, p.y, Color(0, 0, 0, a * 0.5))
	for k in 7:
		var an := k * TAU / 7.0 + 0.4
		var q := origin + Vector2i(roundi(cos(an) * 3.0), roundi(sin(an) * 3.0))
		if zone.has_point(q):
			UiDraw.px(ci, q.x, q.y, Color(CHIP, a * 0.35))


## The island drawn in from the west, the start blinking on it like a cursor.
func _draw_sketch(ci: CanvasItem) -> void:
	if _sketch == null:
		return
	var cols := clampi(int(_sketch_t / SKETCH_DRAW_SECONDS * SKETCH), 0, SKETCH)
	if cols > 0:
		ci.draw_texture_rect_region(_sketch, Rect2(SKETCH_AT, Vector2(cols, SKETCH)), Rect2(0, 0, cols, SKETCH))
	if cols >= SKETCH and _mark.x >= 0 and fmod(_t, 1.2) < 0.8:
		var m := SKETCH_AT + _mark
		UiDraw.rect(ci, Rect2i(m.x - 2, m.y, 5, 1), LIT)
		UiDraw.rect(ci, Rect2i(m.x, m.y - 2, 1, 5), LIT)
		UiDraw.px(ci, m.x, m.y, HEAD)


## Where on the line (0..1) each stage but the last ends, after the shell's share.
func _tick_fractions() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if stages.start_at > 0.0:
		out.append(stages.start_at)
	var total := 0.0
	for s in stages.stages:
		total += s.weight
	var acc := 0.0
	for i in stages.stages.size() - 1:
		acc += stages.stages[i].weight
		out.append(stages.start_at + (1.0 - stages.start_at) * acc / total)
	return out


func _label_at(p: float) -> String:
	var total := 0.0
	for s in stages.stages:
		total += s.weight
	var acc := 0.0
	var q := (p - stages.start_at) / maxf(0.0001, 1.0 - stages.start_at)
	for s in stages.stages:
		acc += s.weight
		if q * total < acc:
			return s.label
	return stages.stages[-1].label if not stages.stages.is_empty() else ""
