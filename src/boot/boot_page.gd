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

## The page is the ink the title fades up from, so there is no flash at the hand-over.
const GLASS := Color("#08070f")
const RAIL := Color("#1c1a2a")
const TICK := Color("#2c2940")
const LIT := Color("#b07a3c")
const LIT_SOFT := Color("#4a3322")
const HEAD := Color("#f1c98a")
const WORDS := Color("#8b7a64")
const SCAN := Color(0.55, 0.5, 0.75, 0.05)
## The island, sketched once it exists: coast, contours, rivers.
const COAST := Color("#6b6784")
const CONTOUR := Color("#2c2a40")
const RIVER := Color("#3b5270")
const GRID := Color("#4f4872")
const VILLAGE := Color("#9a6a3c")
const SKETCH := 112
const SKETCH_AT := Vector2i(264, 70)
const SKETCH_DRAW_SECONDS := 0.45

const LINE_Y := 214
const LINE_X0 := 216
const LINE_X1 := 424
## Seconds the page takes to lift off the scene once it is up.
const LIFT_SECONDS := 0.35

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
var _ink: Control
var _t := 0.0
var _shown := 0
var _lift := -1.0
## Off the screen (and out of the boot_page group), with only _after_lift left.
var _lifted := false
var _handed := false
## Frames drawn since the scene was made (-1 before).
var _drawn := -1


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
	var needed := PackedStringArray([SCENES_SCRIPT])
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
			return left.is_empty(), false)
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
	stages.add(&"near", "drawing what is near", 900.0, func() -> bool:
		return int(_bw.call("build_near", _view, _focus)) == 0, false)
	if threaded:
		# Wait, a frame at a time, for the loader threads to finish the scripts:
		# taking them before they are done (load_threaded_get) held the page still
		# for over a second on the web.
		stages.add(&"compiled", "setting out", 400.0, func() -> bool:
			for path in needed:
				if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					return false
			return true, false)
	stages.add(&"start", "setting out", 300.0, func() -> void:
		if threaded:
			for path in needed:
				ResourceLoader.load_threaded_get(path)
		_bw.call("offer", _world, _view)
		_world = null
		_view = null
		scene = BootPage.make_game(_parent, o) if what == "game" else BootPage.make_title(_parent, o), false)
	# A world's first frame compiles its shaders and stalls (seconds on the web):
	# the line ends when that frame is drawn, not before.
	stages.add(&"draw", "looking up", 1200.0, func() -> bool:
		if _drawn < 0:
			_drawn = 0
			RenderingServer.frame_post_draw.connect(_on_drawn)
		return _drawn >= 2 or BootPage.headless(), false)


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


## The glass goes once the ink on it has faded.
func _draw_glass() -> void:
	var a := 1.0
	if _lift >= 0.0:
		a = 1.0 - clampf((_lift - LIFT_SECONDS * 0.4) / (LIFT_SECONDS * 0.6), 0.0, 1.0)
	UiDraw.rect(_sheet, Rect2i(0, 0, 640, 360), Color(GLASS, a))


func _draw_page() -> void:
	var ci := _ink
	# A faint band drifting down the glass: the page is alive while a stage runs.
	var band_y := int(fmod(_t * 22.0, 400.0)) - 20
	UiDraw.rect(ci, Rect2i(0, band_y, 640, 14), SCAN)
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
