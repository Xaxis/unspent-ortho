extends GameSystem
## Grass parts round the player and every body near them (TrampleField), and the
## path they walked stays pressed a while (grass.gdshader reads it).
##
## Once a frame: follow the player with the window, let what was pressed stand
## back up, press it again under the player and (on its own beat) each live body within
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
## Frames between a moving body's stamps, and how far it has to have gone since
## its last one to count as moving (tiles).
const BODY_EVERY := 2
const MOVED := 0.05
var _frame := 0
var _stamped: Dictionary = {}
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
	_frame += 1
	for m: Node in get_tree().get_nodes_in_group(&"mobs"):
		var alive: Variant = m.get(&"alive")
		var pos: Variant = m.get(&"pos")
		if (alive is bool and not alive) or not pos is Vector2:
			continue
		var p := pos as Vector2
		if p.distance_to(here) > NEAR:
			continue
		# A body is stamped on its own beat, not every frame: a stamp only has to
		# be renewed faster than the lean falls away (TrampleField.RECOVER, 1.3 s),
		# and a body stamping every frame cost a tenth of a millisecond each
		# (the widest body presses some 300 texels). A moving body every BODY_EVERY
		# frames, one standing still half as often: its lean dips 5% between stamps.
		var id := m.get_instance_id()
		var last: Vector2 = _stamped.get(id, Vector2.INF)
		var moved := not last.is_finite() or last.distance_to(p) > MOVED
		var every := BODY_EVERY if moved else BODY_EVERY * 2
		if (_frame + id) % every != 0:
			continue
		_stamped[id] = p
		var r: Variant = m.get(&"radius")
		field.stamp(p, clampf(float(r) * 1.6, 0.5, 2.5) if r is float else BODY_REACH, 1.0, PRESS_STILL)
	# Forget bodies now and then, so the freed ones do not pile up.
	if _frame % 600 == 0:
		_stamped.clear()
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
const TOUR_PLACES: Array[String] = ["meadow", "dune", "front", "snow_meadow", "ash_meadow"]
const SkySystem := preload("res://src/systems/10_sky.gd")
## `near front`: a bush with a crown downwind of it this far off, in tiles, and
## this far off the wind's line at most, in radians.
const FRONT_GAP := Vector2(3.0, 9.0)
const FRONT_LINE := 0.35
## Tiles aside from the bush-to-crown line the player stands for `near front`.
const FRONT_ASIDE := 2.5
## The bush and crown `near front` last chose, for a tour to print.
var front_bush := Vector2.INF
var front_crown := Vector2.INF


## `near meadow`: within MEADOW_REACH, the middle of the stretch with the most
## level grass of the player's own landscape round it, so the frame is sward and
## not a terrace lip or a mud edge. `near dune`: the same for sand, looked for
## further out, since the dunes lie along the bays. A tour about grass names the
## grass, not a coordinate that the next worldgen change moves.
func tour_place(what: String) -> Vector2:
	if not what in TOUR_PLACES or game == null or game.world == null or game.player == null:
		return Vector2.INF
	if what == "front":
		return _front()
	if what.ends_with("_meadow"):
		var mask := SkyGround.texture(game.world).get_image()
		return _settled_meadow(game.world, mask, game.player.pos, 0 if what == "snow_meadow" else 1)
	var dune := what == "dune"
	var at := _best(game.world, game.player.pos, Ground.SAND if dune else Ground.GRASS,
		DUNE_REACH if dune else MEADOW_REACH, 6 if dune else 2)
	# A landscape that grows little grass (the burning's scorched turf) may have
	# none near where it is named: look as far as for a dune, more coarsely.
	if at == Vector2.INF and not dune:
		at = _best(game.world, game.player.pos, Ground.GRASS, DUNE_REACH, 6)
	return at


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


## `near snow_meadow` / `near ash_meadow`: grass where snow (ash) can lie on
## it most fully (SkyGround's R or G, which grass.gdshader masks what settles by),
## so a frame of weather on the blades is not shot on an ecotone that holds a
## third of it. The stretch with the most level grass times that share squared,
## within DUNE_REACH.
static func _settled_meadow(w: WorldData, mask: Image, here: Vector2, channel: int) -> Vector2:
	var hx := floori(here.x)
	var hy := floori(here.y)
	var best := 0.0
	var at := Vector2.INF
	for dy in range(-DUNE_REACH, DUNE_REACH + 1, 3):
		for dx in range(-DUNE_REACH, DUNE_REACH + 1, 3):
			var x := hx + dx
			var y := hy + dy
			if x < 0 or y < 0 or x >= mask.get_width() or y >= mask.get_height() or w.ground_at(x, y) != Ground.GRASS:
				continue
			var share: float = mask.get_pixel(x, y)[channel]
			if share < 0.5:
				continue
			var score := float(_open(w, x, y, Ground.GRASS, w.country_at(x, y))) * share * share
			if score > best:
				best = score
				at = Vector2(x + 0.5, y + 0.5)
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


## `near front`: where one gust front is seen to cross grass, then a bush, then
## a tree. The nearest bush standing in grass with a broadleaf or pine downwind
## of it on the world's wind line (SkySystem.bearing_of, which a positive held wind
## blows along); the player stands upwind in the grass, so from above the frame
## runs grass, bush, crown along the way the front travels.
func _front() -> Vector2:
	var w := game.world
	var dir := SkySystem.bearing_of(w.seed_value)
	var here: Vector2 = game.player.pos
	var best := INF
	var at := Vector2.INF
	for b: WorldProp in game.query.props_near(here, 120.0):
		if b.kind != PropKind.BUSH or w.ground_at(floori(b.pos.x), floori(b.pos.y)) != Ground.GRASS:
			continue
		var stand := b.pos - dir * 4.0
		if w.ground_at(floori(stand.x), floori(stand.y)) != Ground.GRASS:
			continue
		for t: WorldProp in game.query.props_near(b.pos, FRONT_GAP.y):
			if t.kind != PropKind.BROADLEAF and t.kind != PropKind.PINE:
				continue
			var d := t.pos - b.pos
			if d.length() < FRONT_GAP.x or absf(d.angle_to(dir)) > FRONT_LINE:
				continue
			# Stand beside the line, level with the bush, so the frame holds the
			# grass upwind, the bush, and the crown past it, the crown mid-frame.
			var beside := b.pos + d * 0.35 + Vector2(-dir.y, dir.x) * FRONT_ASIDE
			if w.ground_at(floori(beside.x), floori(beside.y)) != Ground.GRASS:
				continue
			var far := here.distance_to(b.pos)
			if far < best:
				best = far
				at = beside
				front_bush = b.pos
				front_crown = t.pos
	if at != Vector2.INF:
		print("tour front: bush %s crown %s wind toward %s" % [front_bush, front_crown, dir])
	return at
