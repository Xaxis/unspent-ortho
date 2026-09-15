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

const GAME_SCRIPT := "res://src/game.gd"
const TITLE_SCRIPT := "res://src/ui/ui_title.gd"
const WORLD_SCRIPT := "res://src/boot/boot_world.gd"

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
var _sheet: Control
var _t := 0.0
var _shown := 0
var _lift := -1.0
var _handed := false
## Frames drawn since the scene was made; the page lifts once it has drawn.
var _after := 0


## True where slow jobs may go to the worker pool (not the no-threads web build).
static func has_threads() -> bool:
	return not OS.has_feature("web") or OS.has_feature("threads")


static func headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Start a game with `o` under `parent` through the loading page. Returns the page,
## or the game itself when headless.
static func open_game(parent: Node, o: BootOptions) -> Node:
	if headless():
		return BootPage._make_game(parent, o)
	var page := BootPage.new()
	page._plan(parent, o, "game")
	parent.add_child(page)
	return page


## Show the title under `parent`, its first coast made on the loading page.
static func open_title(parent: Node, o: BootOptions) -> Node:
	if headless():
		return BootPage._make_title(parent, o)
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
	for s: Array in [[&"code", "waking"], [&"world", "raising the land"], [&"view", "laying out the ground"], [&"near", "drawing what is near"], [&"start", "setting out"]]:
		page.stages.add(s[0], s[1], 500.0, func() -> void: pass)
	parent.add_child(page)
	return page


static func _sketch_of(bw: GDScript, w: Variant) -> Image:
	return bw.call("sketch", w, SKETCH, {"coast": COAST, "contour": CONTOUR, "river": RIVER, "grid": GRID, "village": VILLAGE})


static func _make_game(parent: Node, o: BootOptions) -> Node:
	var game: Node = (load(GAME_SCRIPT) as GDScript).new()
	game.name = "game"
	parent.add_child(game)
	game.call("setup", o)
	return game


static func _make_title(parent: Node, o: BootOptions) -> Node:
	var title: Node = (load(TITLE_SCRIPT) as GDScript).new()
	title.name = "title"
	parent.add_child(title)
	title.call("setup", o)
	return title


## Lay out the stages that make `what` ("game" or "title") for `o` under `parent`.
## `threads` false runs every stage on the main thread (the no-threads web build).
func _plan(parent: Node, o: BootOptions, what: String, threads: bool = BootPage.has_threads()) -> void:
	_parent = parent
	options = o
	kind = what
	threaded = threads
	var scene_script := GAME_SCRIPT if what == "game" else TITLE_SCRIPT
	var scripts := PackedStringArray([scene_script])
	if what == "game":
		scripts.append_array(BootPage.system_scripts())
	if threaded:
		# The scene's scripts compile on loader threads beside the world.
		stages.add(&"code", "waking", 500.0, func() -> void:
			for path in scripts:
				ResourceLoader.load_threaded_request(path, "GDScript")
			_bw = load(WORLD_SCRIPT) as GDScript)
	else:
		stages.add(&"code", "waking", 500.0, func() -> void:
			_bw = load(WORLD_SCRIPT) as GDScript, false)
		# One script a frame (each pulls in what it uses).
		var left := Array(scripts)
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
			_focus = (load(TITLE_SCRIPT) as GDScript).call("opening", _world)[0]
		_sketch_image = BootPage._sketch_of(_bw, _world)
		_mark = Vector2i((_focus * SKETCH / float(_world.size)).floor()))
	# Main thread, one chunk a step: the chunks become nodes of the view.
	stages.add(&"near", "drawing what is near", 900.0, func() -> bool:
		return int(_bw.call("build_near", _view, _focus)) == 0, false)
	stages.add(&"start", "setting out", 300.0, func() -> void:
		if threaded:
			for path in scripts:
				ResourceLoader.load_threaded_get(path)
		_bw.call("offer", _world, _view)
		_world = null
		_view = null
		scene = BootPage._make_game(_parent, o) if what == "game" else BootPage._make_title(_parent, o), false)


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
	_sheet.draw.connect(_draw_page)
	add_child(_sheet)


func _process(delta: float) -> void:
	_t += delta
	_sheet.queue_redraw()
	var cur := stages.current()
	if _sketch == null and _sketch_image != null and (kind == "preview" or cur == null or cur.id == &"near" or cur.id == &"start"):
		_sketch = ImageTexture.create_from_image(_sketch_image)
		if kind != "preview":
			print("boot sketch %s: the island is drawn in" % kind)
	elif _sketch != null:
		_sketch_t += delta
	if kind == "preview":
		return
	if _lift >= 0.0:
		_lift += delta
		if _lift >= LIFT_SECONDS:
			queue_free()
		return
	if _handed:
		# Lift once the scene has drawn a couple of frames under the page.
		_after += 1
		if _after >= 2:
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
	handed_over.emit(scene)


func _exit_tree() -> void:
	# A page closed mid-way (the game quit) waits out its worker, and must not
	# leave a view nobody frees.
	stages.wait()
	if _view != null and is_instance_valid(_view) and not (_view as Node).is_inside_tree():
		(_view as Node).free()
		_view = null


func progress() -> float:
	return held_progress if held_progress >= 0.0 else stages.progress()


func _draw_page() -> void:
	var a := 1.0
	if _lift >= 0.0:
		a = 1.0 - clampf(_lift / LIFT_SECONDS, 0.0, 1.0)
	var ci := _sheet
	UiDraw.rect(ci, Rect2i(0, 0, 640, 360), Color(GLASS, a))
	if a < 1.0:
		return
	# A faint band drifting down the glass: the page is alive while a stage runs.
	var band_y := int(fmod(_t * 22.0, 400.0)) - 20
	UiDraw.rect(ci, Rect2i(0, band_y, 640, 14), SCAN)
	_draw_sketch(ci)
	var p := progress()
	var x0 := LINE_X0
	var x1 := LINE_X1
	var span := x1 - x0
	UiDraw.hline(ci, x0, x1, LINE_Y, RAIL)
	# A tick where each stage ends, lit once it has.
	var total := 0.0
	for s in stages.stages:
		total += s.weight
	var acc := 0.0
	for i in stages.stages.size():
		acc += stages.stages[i].weight
		if i == stages.stages.size() - 1:
			break
		var tx := x0 + int(round(acc / total * span))
		var lit := p * total >= acc - 0.5
		UiDraw.vline(ci, tx, LINE_Y - 3, LINE_Y - 1, LIT if lit else TICK)
	var head := x0 + int(round(p * span))
	if head > x0:
		UiDraw.hline(ci, x0, head, LINE_Y, LIT)
		UiDraw.hline(ci, x0, head, LINE_Y + 1, LIT_SOFT)
	# The head: two bright pixels that breathe, so a long stage still shows life.
	var breathe := 0.65 + 0.35 * sin(_t * 5.0)
	UiDraw.rect(ci, Rect2i(head - 1, LINE_Y, 2, 1), Color(HEAD, breathe))
	var cur := stages.current()
	var words := cur.label if cur != null else "setting out"
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


func _label_at(p: float) -> String:
	var total := 0.0
	for s in stages.stages:
		total += s.weight
	var acc := 0.0
	for s in stages.stages:
		acc += s.weight
		if p * total < acc:
			return s.label
	return stages.stages[-1].label if not stages.stages.is_empty() else ""
