extends GameSystem
## Grass parts round the player and every body near them (TrampleField), and the
## path they walked stays pressed a while (grass.gdshader reads it).
##
## Once a frame: follow the player with the window, let what was pressed stand
## back up, press it again under the player and under each live body within
## NEAR, and upload the 16 KB field as global `foliage_trample`, with the window
## in `foliage_trample_at` (xz its low corner, z 1/span, w span). Bodies are read
## as 18_crowns reads them: anything in the `mobs` group that answers `alive`
## and `pos`. A body that answers `radius` presses that wide.

## Tiles round a person that the grass parts over.
const REACH := 0.95
## Tiles round a body that says nothing of its size.
const BODY_REACH := 0.9
## A body further off than this presses nothing the camera would care about.
const NEAR := 7.0
## How hard a body standing still presses the middle down, and one moving.
const PRESS_STILL := 0.45
const PRESS_MOVING := 0.8

var field := TrampleField.new()
var _img: Image
var _tex: ImageTexture
var _last := Vector2.INF
## The texture last uploaded was all upright.
var _clean := true


func setup(g: Game) -> void:
	super.setup(g)
	_img = Image.create_from_data(TrampleField.SIZE, TrampleField.SIZE, false, Image.FORMAT_RGBA8, field.bytes())
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set(&"foliage_trample", _tex)
	RenderingServer.global_shader_parameter_set(&"foliage_trample_at", field.window())


func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	var here: Vector2 = game.player.pos
	field.focus(here)
	field.decay(delta)
	var moving := _last.is_finite() and here.distance_to(_last) > 0.2 * delta
	_last = here
	field.stamp(here, REACH, 1.0, PRESS_MOVING if moving else PRESS_STILL)
	for m: Node in get_tree().get_nodes_in_group(&"mobs"):
		var alive: Variant = m.get(&"alive")
		var pos: Variant = m.get(&"pos")
		if (alive is bool and not alive) or not pos is Vector2:
			continue
		var p := pos as Vector2
		if p.distance_to(here) > NEAR:
			continue
		var r: Variant = m.get(&"radius")
		field.stamp(p, clampf(float(r) * 1.6, 0.5, 2.5) if r is float else BODY_REACH, 1.0, PRESS_STILL)
	# Once more after the field goes quiet, so the last lean does not hang on.
	if not field.quiet or not _clean:
		_img.set_data(TrampleField.SIZE, TrampleField.SIZE, false, Image.FORMAT_RGBA8, field.bytes())
		_tex.update(_img)
	_clean = field.quiet
	RenderingServer.global_shader_parameter_set(&"foliage_trample_at", field.window())


## Tiles round the middle of a `near meadow` that are scored: the frame round
## the player at play zoom.
const MEADOW_HALF := 4
## How far out `near meadow` looks, and `near dune`.
const MEADOW_REACH := 60
const DUNE_REACH := 400
## The names `tour_place` answers (tests/tours/test_tour_claims.gd reads it).
const TOUR_PLACES: Array[String] = ["meadow", "dune"]


## `near meadow`: within MEADOW_REACH, the middle of the stretch with the most
## level grass of the player's own landscape round it, so the frame is sward and
## not a terrace lip or a mud edge. `near dune`: the same for sand, looked for
## further out, since the dunes lie along the bays. A tour about grass names the
## grass, not a coordinate that the next worldgen change moves.
func tour_place(what: String) -> Vector2:
	if not what in TOUR_PLACES or game == null or game.world == null or game.player == null:
		return Vector2.INF
	var dune := what == "dune"
	return _best(game.world, game.player.pos, Ground.SAND if dune else Ground.GRASS,
		DUNE_REACH if dune else MEADOW_REACH, 6 if dune else 2)


static func _best(w: WorldData, here: Vector2, g: int, reach: int, step: int) -> Vector2:
	var hx := floori(here.x)
	var hy := floori(here.y)
	var country := w.country_at(hx, hy)
	var best := 0
	var at := Vector2.INF
	for dy in range(-reach, reach + 1, step):
		for dx in range(-reach, reach + 1, step):
			var n := _open(w, hx + dx, hy + dy, g, country)
			if n > best:
				best = n
				at = Vector2(hx + dx + 0.5, hy + dy + 0.5)
	return at


## How many tiles round (x, y) are ground `g` of `country` on its level; 0 when
## (x, y) itself is not.
static func _open(w: WorldData, x: int, y: int, g: int, country: int) -> int:
	if w.ground_at(x, y) != g or w.country_at(x, y) != country:
		return 0
	var lvl := w.level_at(x, y)
	var n := 0
	for oy in range(-MEADOW_HALF, MEADOW_HALF + 1):
		for ox in range(-MEADOW_HALF, MEADOW_HALF + 1):
			if w.ground_at(x + ox, y + oy) == g and w.level_at(x + ox, y + oy) == lvl and w.country_at(x + ox, y + oy) == country:
				n += 1
	return n
