extends GameSystem
## Survival drawn, so taking reads without a word on screen. Everything here is
## drawn feedback in the notebook's hand (docs/ART.md §7): short ink bursts,
## stipple dust, flecks of stuff, sparks as a bright pixel or two, and nothing
## that bounces like a physics engine. Motion steps at FPS, like drawn frames.
## - each blow of the work: an ink burst where it lands, flecks of what the thing
##   is made of, a spark where iron meets stone or plate, dust at its foot;
## - when it gives out it goes the way that thing goes: a tree falls away from you
##   and is gone in its own dust, rock splits in a puff, reeds and driftwood lift
##   into your hands;
## - what you took or made hops into your hands as a small drawn token per piece;
## - a fire you build goes up in a ring of dust; a thing that grows back is
##   announced by a few green specks;
## - what taking leaves stays marked while it is gone (RemnantModels);
## - every fire nearby burns (FireModel).
## Every mark is sized in screen pixels through the camera (_px), so a stroke is a
## stroke at the 640x360 the game is played at: ticks at least a pixel and a half
## across and five or more long, dots two pixels. Ink marks take ink or paper from
## what is drawn behind them (SurvivalMarks.CONTRAST), never from a list of kinds.
## Reads SurvivalState, WorldData and Events; writes nothing but its own nodes.

const FPS := 15.0
const DOTS := 320
const TICKS := 72
const FLECKS := 96
const SPARKS := 24
const FIRE_RADIUS := 22.0
const REMNANT_RADIUS := 48.0
## Blows land at these fractions of Survival.WORK_SECONDS.
const BLOWS: Array[float] = [0.28, 0.62, 0.94]
const TOKEN_SECONDS := 0.42
const MAX_TOKENS := 3
## Screen pixels: a pen tick's half-width (its three-sided bar is about three of
## these across, so 0.9 draws a line one to two pixels wide), where a burst's
## ticks start from the blow, a dot's radius and a fleck's size.
const TICK_PX := 0.9
const BURST_INNER_PX := 3.0
const DOT_PX := 1.1
const FLECK_PX := 2.6
## A felled tree: it shivers, goes over, lies where it fell a while, then is gone in its dust.
const FALL_SHIVER := 0.22
const FALL_DROP := 0.62
const FALL_LIE := 0.9

const TREES: Array[int] = [PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE]
const ROCKS: Array[int] = [PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE,
	PropKind.COAL_ORE, PropKind.TIN_ORE, PropKind.CLINTS, PropKind.RUIN, PropKind.VENT]
const SCRAP: Array[int] = [PropKind.TIP, PropKind.WRECK, PropKind.POLE, PropKind.PYLON]

var _mat: ShaderMaterial
var _dots: SurvivalMarks.Pool
var _ticks: SurvivalMarks.Pool
var _sparks_pool: SurvivalMarks.Pool
var _flecks: SurvivalMarks.Pool
## Flecks of plate are FOUND: drawn by the ruler's material, never hatched.
var _found_flecks: SurvivalMarks.Pool
var _found_mat: ShaderMaterial
## Live marks: {i, t, life, from, to, arc, size, col, drop} (dots, flecks), {i, t, life, at, dir, r0, r1, thick, col} (ticks)
var _dot: Array[Dictionary] = []
var _spark: Array[Dictionary] = []
var _tick: Array[Dictionary] = []
var _fleck: Array[Dictionary] = []
var _free_dots: Array[int] = []
var _free_sparks: Array[int] = []
var _free_ticks: Array[int] = []
var _free_flecks: Array[int] = []
var _ffleck: Array[Dictionary] = []
var _free_found: Array[int] = []
var _job_prop: WorldProp = null
## The work that ended most recently, and on which frame: what a took event came from.
var _ended_prop: WorldProp = null
var _ended_frame := -1
var _job_t := 0.0
var _blow := 0
var _anims: Array[Dictionary] = []
var _tokens: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
## Where the last took came from when nothing was being worked: a machine just beaten.
var _killed_at := Vector3.ZERO
var _killed_time := -10.0
var _remnant_mm: Dictionary = {} # StringName -> MultiMesh
var _remnant_sig := ""
var _remnant_at := Vector2(-1e9, -1e9)
var _fires: Dictionary = {} # prop id -> FireModel
var _scan_in := 0.0
## The dots of the ring drawn round an asked-for fire.
var _ring: Array[Dictionary] = []
var _time := 0.0
var _acc := 0.0


func setup(g: Game) -> void:
	super.setup(g)
	_mat = g.view.world_material() if g.view != null else ShaderMaterial.new()
	var marks := SurvivalMarks.material()
	_dots = SurvivalMarks.Pool.new(SurvivalMarks.dot(), DOTS, marks, self)
	_ticks = SurvivalMarks.Pool.new(SurvivalMarks.tick(), TICKS, SurvivalMarks.overlay(), self, true)
	_sparks_pool = SurvivalMarks.Pool.new(SurvivalMarks.dot(), SPARKS, SurvivalMarks.overlay(), self)
	for i in range(SPARKS - 1, -1, -1):
		_free_sparks.append(i)
	_flecks = SurvivalMarks.Pool.new(SurvivalMarks.shard(), FLECKS, _mat, self)
	_found_mat = SurvivalMarks.found_material()
	_found_flecks = SurvivalMarks.Pool.new(SurvivalMarks.shard(), FLECKS / 2, _found_mat, self)
	for i in range(FLECKS / 2 - 1, -1, -1):
		_free_found.append(i)
	for i in range(DOTS - 1, -1, -1):
		_free_dots.append(i)
	for i in range(TICKS - 1, -1, -1):
		_free_ticks.append(i)
	for i in range(FLECKS - 1, -1, -1):
		_free_flecks.append(i)
	_build_remnant_layers()
	Events.took.connect(_on_took)
	Events.made.connect(_on_made)
	Events.killed.connect(_on_killed)
	Events.sfx.connect(_on_sfx)
	# Stations built before this system was listening (a --build shot) still go up in dust.
	for prop in SurvivalState.of(g).built:
		_on_sfx(&"build_fire", g.world.to_3d(prop.pos))
	var asked := Survival.build_asked(g)
	if asked.is_finite():
		_on_sfx(&"ask_fire", g.world.to_3d(asked))


func _exit_tree() -> void:
	for pair: Array in [[Events.took, _on_took], [Events.made, _on_made], [Events.killed, _on_killed], [Events.sfx, _on_sfx]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	if game != null and game.options.hold >= 0.0:
		Survival.fixed_now = -1.0


# --- Per frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	if game == null:
		return
	if game.options.hold >= 0.0:
		delta = Survival.fixed_step
	_time += delta
	_follow_job(delta)
	_resolve_pending()
	if not _ring.is_empty() and not Survival.build_asked(game).is_finite():
		_clear_ring()
	_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = 0.5
		_scan_fires()
		_refresh_remnants()
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var dt := _acc
	_acc = 0.0
	_step_marks(dt)
	_step_anims(dt)
	_step_tokens(dt)


func _follow_job(delta: float) -> void:
	var job := SurvivalState.of(game).job
	var prop: WorldProp = job.get("prop", null)
	if prop != _job_prop:
		if _job_prop != null:
			_ended_prop = _job_prop
			_ended_frame = Engine.get_process_frames()
			if game.world.depleted.has(_job_prop.id):
				_give_out(_job_prop)
		_job_prop = prop
		_job_t = 0.0
		_blow = 0
	if prop == null:
		return
	_job_t += delta
	var verb: StringName = job.option.verb
	while _blow < BLOWS.size() and _job_t >= BLOWS[_blow] * Survival.WORK_SECONDS:
		_blow += 1
		_strike(prop, verb, job.get("tool", &"") != &"")


# --- Mark pools -----------------------------------------------------------------

## A dot that travels from `from` to `to` (easing out) over `life`, lifted `arc` at
## its middle, and drops out at `drop` (0..1 of its life): stipple dust and specks.
func _emit_dot(from: Vector3, to: Vector3, life: float, size: float, col: Color, arc: float = 0.0, drop: float = 1.0) -> void:
	if _free_dots.is_empty():
		return
	var d := {"i": _free_dots.pop_back(), "t": 0.0, "life": life, "from": from, "to": to, "arc": arc, "size": size, "col": col, "drop": drop}
	_dot.append(d)
	_draw_travel(_dots, d)


func _emit_fleck(from: Vector3, to: Vector3, life: float, size: float, col: Color, arc: float, found: bool = false) -> void:
	var free := _free_found if found else _free_flecks
	if free.is_empty():
		return
	var d := {"i": free.pop_back(), "t": 0.0, "life": life, "from": from, "to": to, "arc": arc, "size": size, "col": col, "drop": 1.0,
		"spin": Rng.hash01(int(_time * 1000.0), _fleck.size() + _ffleck.size()) * TAU}
	(_ffleck if found else _fleck).append(d)
	_draw_travel(_found_flecks if found else _flecks, d)


## An ink tick flicked out from `at` along `dir`: its head runs out to r1, then its
## tail catches up, so over two or three drawn frames it reads as a stroke of the pen.
## `still`: drawn whole for its life, not flicked (a dashed ring).
func _emit_tick(at: Vector3, dir: Vector3, r0: float, r1: float, life: float, col: Color, thick: float = -1.0, still: bool = false) -> void:
	if thick < 0.0:
		thick = _px(TICK_PX)
	if _free_ticks.is_empty():
		return
	var d := {"i": _free_ticks.pop_back(), "t": 0.0, "life": life, "at": at, "dir": dir, "r0": r0, "r1": r1, "thick": thick, "col": col, "still": still}
	_tick.append(d)
	_draw_tick(d)


func _draw_travel(pool: SurvivalMarks.Pool, d: Dictionary) -> void:
	var k := clampf(float(d.t) / float(d.life), 0.0, 1.0)
	if k >= float(d.drop):
		pool.hide(d.i)
		return
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	var pos: Vector3 = (d.from as Vector3).lerp(d.to, e) + Vector3(0, float(d.arc) * sin(k * PI), 0)
	if d.has("spin"):
		var b := Basis(Vector3(0.3, 1.0, 0.2).normalized(), float(d.spin) + k * 5.0).scaled(Vector3.ONE * float(d.size))
		pool.put_xf(d.i, Transform3D(b, pos), d.col)
	else:
		pool.put(d.i, pos, d.size, d.col)


func _draw_tick(d: Dictionary) -> void:
	var k := clampf(float(d.t) / float(d.life), 0.0, 1.0)
	var r0: float = d.r0
	var r1: float = d.r1
	var head := r1 if d.still else r0 + (r1 - r0) * minf(1.0, 0.45 + k * 1.6)
	var tail := r0 if d.still else r0 + (r1 - r0) * clampf((k - 0.3) / 0.7, 0.0, 1.0)
	if head - tail < 0.02:
		_ticks.hide(d.i)
		return
	var at: Vector3 = d.at
	var dir: Vector3 = d.dir
	# Each tick takes ink or paper from what lies under the middle of its own stroke, so a
	# burst over a dark rock's edge is scratched pale on the rock and inked on the snow.
	_ticks.put_xf(d.i, SurvivalMarks.stroke_xf(at + dir * tail, at + dir * head, d.thick), d.col, at + dir * (r0 + r1) * 0.5)


func _step_marks(dt: float) -> void:
	for pair: Array in [[_dot, _dots, _free_dots], [_spark, _sparks_pool, _free_sparks], [_fleck, _flecks, _free_flecks], [_ffleck, _found_flecks, _free_found]]:
		var list: Array[Dictionary] = pair[0]
		var pool: SurvivalMarks.Pool = pair[1]
		var free: Array[int] = pair[2]
		for j in range(list.size() - 1, -1, -1):
			var d := list[j]
			d.t = float(d.t) + dt
			if float(d.t) >= float(d.life):
				pool.hide(d.i)
				free.append(d.i)
				list.remove_at(j)
			else:
				_draw_travel(pool, d)
	for j in range(_tick.size() - 1, -1, -1):
		var d := _tick[j]
		d.t = float(d.t) + dt
		if float(d.t) >= float(d.life):
			_ticks.hide(d.i)
			_free_ticks.append(d.i)
			_tick.remove_at(j)
		else:
			_draw_tick(d)


# --- The drawn vocabulary -------------------------------------------------------

## Toward the camera: marks are pulled this way so the thing they are on does not hide them.
func _toward_eye() -> Vector3:
	return game.camera.global_transform.basis.z if game.camera != null else Vector3(0.39, 0.84, 0.39)


## World units across `n` screen pixels at the camera's zoom.
func _px(n: float) -> float:
	var h := game.camera.view_height if game.camera != null else 14.0
	return n * h / 360.0


func _page_basis() -> Basis:
	return game.camera.global_transform.basis if game.camera != null else Basis.from_euler(Vector3(deg_to_rad(-57.0), deg_to_rad(45.0), 0.0))


## A starburst of `n` pen ticks round `at`, in the plane of the page, reaching
## `reach_px` screen pixels out. Ink on a pale ground or thing, paper on a dark one.
func _ink_burst(at: Vector3, n: int, reach_px: float, salt: int) -> void:
	var b := _page_basis()
	var base := Rng.hash01(salt, 1) * TAU
	for i in n:
		var a := base + float(i) / n * TAU + (Rng.hash01(salt, i, 2) - 0.5) * 0.7
		var dir := (b.x * cos(a) + b.y * sin(a)).normalized()
		var r := _px(reach_px * (0.8 + Rng.hash01(salt, i, 3) * 0.45))
		_emit_tick(at, dir, _px(BURST_INNER_PX), r, 0.2, SurvivalMarks.CONTRAST)


## Stipple dust: dots flung low from `at` over a ring of `radius`, dropping out
## at random so the puff thins like a dither, not a fade.
func _dust(at: Vector3, n: int, radius: float, colors: Array[Color], salt: int, rise: float = 0.12, life: float = 0.6) -> void:
	for i in n:
		var a := Rng.hash01(salt, i, 11) * TAU
		var r := radius * (0.45 + Rng.hash01(salt, i, 12) * 0.75)
		var to := at + Vector3(cos(a) * r, rise * Rng.hash01(salt, i, 13), sin(a) * r)
		var from := at + Vector3(cos(a), 0.0, sin(a)) * radius * 0.15
		_emit_dot(from, to, life * (0.7 + Rng.hash01(salt, i, 14) * 0.5), _px(DOT_PX * (0.9 + Rng.hash01(salt, i, 15) * 0.5)),
			colors[i % colors.size()], 0.06, 0.45 + Rng.hash01(salt, i, 16) * 0.55)


## Flecks of stuff knocked out of `at`, back toward the worker and up a little.
func _knock_flecks(at: Vector3, back: Vector3, n: int, colors: Array[Color], salt: int, spread: float = 0.35, found: bool = false) -> void:
	for i in n:
		var side := Vector3(Rng.hash01(salt, i, 21) - 0.5, 0.0, Rng.hash01(salt, i, 22) - 0.5) * spread * 2.0
		var to := at + back * (0.18 + Rng.hash01(salt, i, 23) * 0.3) + side
		to.y = game.world.height_at(Vector2(to.x, to.z)) + 0.03
		_emit_fleck(at, to, 0.32 + Rng.hash01(salt, i, 24) * 0.2, _px(FLECK_PX * (0.85 + Rng.hash01(salt, i, 25) * 0.4)),
			colors[i % colors.size()], 0.18 + Rng.hash01(salt, i, 26) * 0.2, found)


func _sparks(at: Vector3, n: int, salt: int) -> void:
	for i in n:
		var to := at + Vector3(Rng.hash01(salt, i, 31) - 0.5, 0.35 + Rng.hash01(salt, i, 32) * 0.25, Rng.hash01(salt, i, 33) - 0.5) * 0.45
		var col := Palette.EMBER[5] if i % 2 == 0 else Palette.LENS[3]
		if _free_sparks.is_empty():
			return
		var d := {"i": _free_sparks.pop_back(), "t": 0.0, "life": 0.16, "from": at, "to": to, "arc": 0.0, "size": _px(DOT_PX),
			"col": Color(col.r, col.g, col.b, 0.0), "drop": 1.0}
		_spark.append(d)
		_draw_travel(_sparks_pool, d)


func _colors(kind: int, verb: StringName) -> Array[Color]:
	if TREES.has(kind):
		if verb == &"tap":
			return [Palette.COPPER[4], Palette.COPPER[3]]
		if kind == PropKind.DEAD_TREE:
			return [Palette.ASH[4], Palette.SAND[4], Palette.ASH[3]]
		return [Palette.SAND[5], Palette.EARTH[3], Palette.SAND[4]]
	match kind:
		# Broken rock shows its pale inside, so flecks read on any ground; the ore shows its colour.
		PropKind.IRON_ORE:
			return [Palette.STONE[5], Palette.RUST[4], Palette.RUST[5]]
		PropKind.COPPER_ORE:
			return [Palette.STONE[5], Palette.SPRUCE[4], Palette.SPRUCE[5]]
		PropKind.COAL_ORE:
			return [Palette.INK[3], Palette.STONE[5], Palette.INK[4]]
		PropKind.TIN_ORE:
			return [Palette.STONE[5], Palette.RIME[5], Palette.ASH[4]]
		PropKind.CLINTS:
			return [Palette.LINEN[5], Palette.LINEN[4], Palette.STONE[4]]
		PropKind.DRIFTWOOD:
			return [Palette.SAND[4], Palette.LINEN[4], Palette.SAND[3]]
		PropKind.WRACK:
			return [Palette.MOSS[3], Palette.EARTH[3], Palette.MOSS[2]]
		PropKind.MUSSEL_ROCK:
			return [Palette.BRINE[5], Palette.LINEN[5], Palette.BRINE[4]]
		PropKind.PEAT_BANK:
			return [Palette.EARTH[2], Palette.EARTH[3], Palette.EARTH[1]]
		PropKind.VENT:
			return [Palette.COPPER[4], Palette.ASH[3], Palette.COPPER[3]]
		PropKind.GORSE:
			return [Palette.MOSS[4], Palette.COPPER[4], Palette.MOSS[3]]
		PropKind.REEDS:
			return [Palette.SAND[4], Palette.MOSS[4], Palette.SAND[5]]
	if ROCKS.has(kind):
		return [Palette.STONE[5], Palette.STONE[4], Palette.LINEN[4]]
	if SCRAP.has(kind):
		return [Palette.PLATE[4], Palette.RUST[4], Palette.PLATE[3]]
	return [Palette.MOSS[4], Palette.MOSS[3], Palette.SAND[4]]


## Stipple is the pen: dust is dots of ink or paper (whichever reads on the ground
## under them), with a fleck of the stuff's own colour among them.
func _dust_colors(kind: int) -> Array[Color]:
	var c := SurvivalMarks.CONTRAST
	if kind == PropKind.PEAT_BANK:
		return [c, Palette.EARTH[3], c]
	if SCRAP.has(kind):
		return [c, Palette.RUST[4], c]
	if TREES.has(kind):
		return [c, Palette.SAND[4], c]
	return [c, Palette.STONE[4], c]


## Where a blow meets the thing: its near side, at a height that suits it.
func _contact(prop: WorldProp) -> Vector3:
	var to := prop.pos - game.player.pos
	var dir := to.normalized() if to.length() > 0.01 else Vector2.RIGHT
	var edge := prop.pos - dir * prop.solid * 0.9
	var h := 0.15
	if TREES.has(prop.kind):
		h = 0.42
	elif ROCKS.has(prop.kind) or SCRAP.has(prop.kind):
		h = 0.28 * prop.scale
	return game.world.to_3d(edge) + Vector3(0, h, 0)


func _strike(prop: WorldProp, verb: StringName, tooled: bool) -> void:
	var salt: int = prop.id * 7919 + _blow * 131 + int(SurvivalState.of(game).taken.get(SurvivalState.key(prop.id, 0), 0)) * 17
	var colors := _colors(prop.kind, verb)
	var at := _contact(prop) + _toward_eye() * 0.3
	var back := game.world.to_3d(game.player.pos) - game.world.to_3d(prop.pos)
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.LEFT
	match verb:
		&"fell", &"break", &"dig", &"cut":
			_ink_burst(at, 5 if verb != &"cut" else 4, 10.0 if verb != &"cut" else 8.0, salt)
			_knock_flecks(at, back, 3 if verb != &"cut" else 2, colors, salt, 0.35, SCRAP.has(prop.kind))
		&"gather", &"scrape", &"turn":
			_ink_burst(at, 3, 7.0, salt)
			_knock_flecks(at, back, 2 if verb != &"gather" else 1, colors, salt, 0.2, SCRAP.has(prop.kind))
		&"tap":
			# A tap only weeps: one drop runs down the bark.
			var foot := game.world.to_3d(prop.pos + Vector2(back.x, back.z) * prop.solid) + Vector3(0, 0.05, 0)
			_emit_dot(at, foot + back * 0.25, 0.5, _px(DOT_PX * 1.3), Palette.COPPER[4], 0.0)
	if verb == &"dig" or verb == &"break" or verb == &"turn":
		var foot := game.world.to_3d(prop.pos + Vector2(back.x, back.z) * prop.solid) + Vector3(0, 0.04, 0)
		_dust(foot, 5, 0.35, _dust_colors(prop.kind), salt + 5, 0.08, 0.5)
	# Iron on stone or plate strikes a spark or two.
	if tooled and (verb == &"break" or verb == &"dig") and (ROCKS.has(prop.kind) or SCRAP.has(prop.kind)):
		_sparks(at, 2, salt + 9)
	# A blow to a trunk shakes needles or leaves out of the crown; they come down slowly.
	if verb == &"fell":
		var crown := Palette.RIME[5] if prop.kind == PropKind.SNOW_PINE else (Palette.ASH[3] if prop.kind == PropKind.DEAD_TREE else Palette.SPRUCE[4])
		var top := game.world.to_3d(prop.pos) + Vector3(0, 1.3 * prop.scale, 0)
		for i in 4:
			var off := Vector3(Rng.hash01(salt, i, 41) - 0.5, 0.0, Rng.hash01(salt, i, 42) - 0.5) * 1.2 * prop.scale
			var from := top + off * 0.5 + Vector3(0, Rng.hash01(salt, i, 43) * 0.6 * prop.scale, 0)
			_emit_dot(from, from + off * 0.4 + Vector3(0, -0.7, 0), 0.9, _px(DOT_PX), crown if i % 2 else Palette.SPRUCE[3], 0.0, 0.8)


# --- Giving out: the thing goes the way that thing goes ---------------------------

func _give_out(prop: WorldProp) -> void:
	var node := MeshInstance3D.new()
	node.mesh = PropModels.mesh(prop.kind)
	node.material_override = _found_mat if SCRAP.has(prop.kind) else _mat
	var pivot := Node3D.new()
	pivot.position = game.world.to_3d(prop.pos)
	pivot.add_child(node)
	node.rotation.y = prop.rot
	node.scale = Vector3.ONE * prop.scale
	add_child(pivot)
	var away := prop.pos - game.player.pos
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	var kind := &"lift"
	if TREES.has(prop.kind):
		# Over across the page, not into it: a tree falling toward or away from the eye
		# is foreshortened to a blob. It goes to whichever side is further from the worker.
		var b := _page_basis()
		var side := Vector2(b.x.x, b.x.z).normalized()
		side = side if side.dot(away) >= 0.0 else -side
		away = (side + away * 0.3).normalized()
	if TREES.has(prop.kind):
		kind = &"fall"
	elif ROCKS.has(prop.kind) or SCRAP.has(prop.kind) or prop.kind == PropKind.PEAT_BANK:
		kind = &"split"
	_anims.append({"pivot": pivot, "t": 0.0, "kind": kind, "away": away, "prop": prop, "stage": 0, "frame": Engine.get_process_frames()})
	_step_anim(_anims[-1], 0.0)


func _step_anims(dt: float) -> void:
	for i in range(_anims.size() - 1, -1, -1):
		var a := _anims[i]
		a.t = float(a.t) + dt
		if _step_anim(a, dt):
			(a.pivot as Node3D).queue_free()
			_anims.remove_at(i)


## Returns true when the animation is over.
func _step_anim(a: Dictionary, _dt: float) -> bool:
	var t: float = a.t
	var pivot: Node3D = a.pivot
	var prop: WorldProp = a.prop
	var base := game.world.to_3d(prop.pos)
	match a.kind:
		&"fall":
			# It shivers, goes over slowly and then fast, bounces once, lies where it
			# fell long enough to be seen, and is gone in its own dust.
			var away: Vector2 = a.away
			var axis := Vector3.UP.cross(Vector3(away.x, 0.0, away.y)).normalized()
			var lie := PI * 0.5 - 0.06
			var angle := 0.0
			if t < FALL_SHIVER:
				angle = (0.07 if int(t * FPS) % 2 == 0 else -0.04)
			else:
				var f := clampf((t - FALL_SHIVER) / FALL_DROP, 0.0, 1.0)
				angle = f * f * lie
				var since := t - FALL_SHIVER - FALL_DROP
				if since > 0.0 and since < 0.14:
					angle = lie - 0.12 * sin(since / 0.14 * PI)
			pivot.basis = Basis(axis, angle)
			# It comes to rest on its crown, not through the ground.
			pivot.position.y = base.y + (angle / lie) * (angle / lie) * 0.35 * prop.scale
			if t >= FALL_SHIVER + FALL_DROP and int(a.stage) == 0:
				a.stage = 1
				_along_trunk(prop, away, 18, _dust_colors(prop.kind), 0.16, 0.7)
				var needles: Array[Color] = [Palette.SPRUCE[3], Palette.SPRUCE[4]]
				if prop.kind == PropKind.SNOW_PINE:
					needles = [Palette.RIME[5], Palette.RIME[4]]
				elif prop.kind == PropKind.DEAD_TREE:
					needles = [Palette.ASH[3], Palette.ASH[4]]
				elif prop.kind == PropKind.BROADLEAF:
					needles = [Palette.MOSS[3], Palette.MOSS[4]]
				_along_trunk(prop, away, 10, needles, 0.3, 0.8, 1.2)
				var mid := prop.pos + away * 1.0 * prop.scale
				_ink_burst(Vector3(mid.x, game.world.height_at(mid) + 0.25, mid.y) + _toward_eye() * 0.3, 6, 12.0, prop.id * 13 + 5)
			var gone := FALL_SHIVER + FALL_DROP + FALL_LIE
			if t >= gone and int(a.stage) == 1:
				a.stage = 2
				pivot.visible = false
				_along_trunk(prop, away, 22, _dust_colors(prop.kind), 0.22, 0.8)
			return t >= gone + 0.05
		&"split":
			# Drawn frames: it cracks wider, slumps, and is gone in a burst of its own pieces.
			var k := clampf(floorf(t * FPS) / FPS / 0.2, 0.0, 1.0)
			pivot.scale = Vector3(1.0 + k * 0.16, 1.0 - k * 0.5, 1.0 + k * 0.16)
			if k >= 1.0 and int(a.stage) == 0:
				a.stage = 1
				pivot.visible = false
				var salt := prop.id * 31 + 7
				var at := base + Vector3(0, 0.22 * prop.scale, 0) + _toward_eye() * 0.25
				_ink_burst(at, 7, 13.0 * prop.scale, salt)
				_dust(base + Vector3(0, 0.05, 0), 16, 0.75 * prop.scale, _dust_colors(prop.kind), salt, 0.3, 0.75)
				var colors := _colors(prop.kind, &"break")
				var toward := game.world.to_3d(game.player.pos) - base
				toward.y = 0.0
				_knock_flecks(at, toward.normalized() if toward.length() > 0.01 else Vector3.LEFT, 6, colors, salt, 0.6, SCRAP.has(prop.kind))
			return t >= 0.22
		_:
			var k := clampf(t / 0.35, 0.0, 1.0)
			var hands := _hands()
			pivot.position = base.lerp(hands, k * k) + Vector3(0, sin(k * PI) * 0.35, 0)
			pivot.scale = Vector3.ONE * (1.0 - k * 0.9)
			if k >= 1.0:
				_dust(hands, 3, 0.18, [SurvivalMarks.CONTRAST], prop.id, 0.1, 0.3)
			return k >= 1.0


## Dots (and a few flecks when `fleck_share` > 0) laid along a fallen trunk.
func _along_trunk(prop: WorldProp, away: Vector2, n: int, colors: Array[Color], rise: float, life: float, drift: float = 0.35) -> void:
	var length := 2.1 * prop.scale
	for i in n:
		var u := 0.1 + Rng.hash01(prop.id, i, 51) * 0.9
		var along := Vector2(away.x, away.y) * u * length
		var side := Vector2(-away.y, away.x) * (Rng.hash01(prop.id, i, 52) - 0.5) * 0.7
		var p := prop.pos + along + side
		var from := Vector3(p.x, game.world.height_at(p) + 0.05, p.y)
		var to := from + Vector3((Rng.hash01(prop.id, i, 53) - 0.5) * drift, rise * Rng.hash01(prop.id, i, 54), (Rng.hash01(prop.id, i, 55) - 0.5) * drift)
		_emit_dot(from, to, life * (0.6 + Rng.hash01(prop.id, i, 56) * 0.6), _px(DOT_PX * (0.9 + Rng.hash01(prop.id, i, 57) * 0.5)),
			colors[i % colors.size()], 0.08, 0.4 + Rng.hash01(prop.id, i, 58) * 0.6)


func _clear_ring() -> void:
	for d in _ring:
		d.t = maxf(float(d.t), float(d.life) - 0.001)
	_ring.clear()


# --- Tokens: what you took, into your hands ----------------------------------------

func _hands() -> Vector3:
	return game.world.to_3d(game.player.pos) + Vector3(0, 0.72, 0)


func _on_took(item: StringName, n: int) -> void:
	if n > 0:
		_pending.append({"item": item, "n": n, "made": false})


func _on_made(item: StringName, n: int) -> void:
	if n > 0:
		_pending.append({"item": item, "n": n, "made": true})


func _on_killed(_kind: StringName, at: Vector3) -> void:
	_killed_at = at
	_killed_time = _time


func _on_sfx(name: StringName, at: Vector3) -> void:
	if game == null:
		return
	var s := String(name)
	if s.begins_with("build_"):
		# A station goes up in a ring of dust, and its fire is lit at once.
		_ink_burst(at + Vector3(0, 0.3, 0) + _toward_eye() * 0.3, 6, 12.0, int(_time * 100.0))
		_dust(at + Vector3(0, 0.04, 0), 18, 0.8, _dust_colors(PropKind.BOULDER), int(_time * 100.0), 0.25, 0.8)
		_scan_in = 0.0
		_clear_ring()
	elif name == &"ask_fire":
		# A dashed pencil ring where the fire would go, until the second press or the ask lapses.
		_clear_ring()
		var dashes := 12
		for i in dashes:
			var a := (float(i) + 0.5) / dashes * TAU
			var p := at + Vector3(cos(a) * 0.5, 0.06, sin(a) * 0.5)
			var tangent := Vector3(-sin(a), 0.0, cos(a))
			_emit_tick(p, tangent, -_px(2.5), _px(2.5), Survival.BUILD_ASK_SECONDS + 1.0, SurvivalMarks.CONTRAST, -1.0, true)
			_ring.append(_tick[-1])
	elif name == &"regrow":
		_dust(at + Vector3(0, 0.1, 0), 6, 0.5, [Palette.MOSS[5], Palette.MOSS[4]], int(at.x * 13.0 + at.z * 7.0), 0.4, 0.9)
	elif name == &"work_broken":
		_ink_burst(at + Vector3(0, 0.35, 0) + _toward_eye() * 0.3, 3, 8.0, int(_time * 100.0))
	elif name == &"collapse":
		_dust(at + Vector3(0, 0.04, 0), 12, 0.6, _dust_colors(PropKind.BOULDER), int(_time * 100.0), 0.15, 0.8)


## Took and made events are resolved after the job is followed in the same frame,
## so a token knows whether its thing is falling (a tree's timber comes when it lands)
## or lifting (driftwood is its own token).
func _resolve_pending() -> void:
	if _pending.is_empty():
		return
	var frame := Engine.get_process_frames()
	for p: Dictionary in _pending:
		var item: StringName = p.item
		var from := _hands() + Vector3(0, -0.4, 0)
		var delay := 0.0
		var skip := false
		var last: Dictionary = _anims[-1] if not _anims.is_empty() else {}
		if p.made:
			var kinds: Array[int] = []
			kinds.assign(Survival.STATION_KINDS.keys())
			var station := game.query.nearest_prop(game.player.pos, Survival.STATION_REACH + 2.0, kinds)
			from = game.world.to_3d(station.pos) + Vector3(0, 0.35, 0) if station != null else _hands() + Vector3(0, 0.25, 0)
		elif not last.is_empty() and int(last.frame) == frame:
			var prop: WorldProp = last.prop
			match last.kind:
				&"lift":
					skip = true
				&"fall":
					var away: Vector2 = last.away
					var mid := prop.pos + away * 1.1 * prop.scale
					from = Vector3(mid.x, game.world.height_at(mid) + 0.2, mid.y)
					delay = FALL_SHIVER + FALL_DROP + 0.1
				_:
					from = game.world.to_3d(prop.pos) + Vector3(0, 0.3, 0)
					delay = 0.12
		elif _ended_frame == frame and _ended_prop != null:
			from = _contact(_ended_prop)
		elif _time - _killed_time < 0.5:
			from = _killed_at + Vector3(0, 0.4, 0)
		if skip:
			continue
		for i in mini(int(p.n), MAX_TOKENS):
			_spawn_token(item, from, delay + i * 0.09)
	_pending.clear()


func _spawn_token(item: StringName, from: Vector3, delay: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = SurvivalMarks.glyph(SurvivalMarks.glyph_for(item))
	mi.material_override = _found_mat if SurvivalMarks.is_found_glyph(mi.mesh) else _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.position = from
	add_child(mi)
	_tokens.append({"node": mi, "t": -delay, "from": from, "spin": Rng.hash01(int(_time * 1000.0), _tokens.size()) * TAU})


func _step_tokens(dt: float) -> void:
	for i in range(_tokens.size() - 1, -1, -1):
		var tk := _tokens[i]
		tk.t = float(tk.t) + dt
		var node: MeshInstance3D = tk.node
		var t: float = tk.t
		if t < 0.0:
			continue
		var k := clampf(t / TOKEN_SECONDS, 0.0, 1.0)
		var hands := _hands()
		var from: Vector3 = tk.from
		node.visible = true
		# Up off the thing, over, and down into the hands: a drawn hop, not a throw.
		node.position = from.lerp(hands, k * k * (3.0 - 2.0 * k)) + Vector3(0, sin(k * PI) * 0.45, 0)
		node.rotation.y = float(tk.spin) + k * 2.4
		node.scale = Vector3.ONE * (1.15 - 0.45 * k)
		if k >= 1.0:
			_dust(hands, 3, 0.16, [SurvivalMarks.CONTRAST], int(float(tk.spin) * 1000.0), 0.12, 0.3)
			node.queue_free()
			_tokens.remove_at(i)


# --- Remnants: what taking leaves behind -----------------------------------------

func _build_remnant_layers() -> void:
	for name in RemnantModels.NAMES:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = RemnantModels.mesh(name)
		mm.instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "remnant_%s" % name
		mmi.multimesh = mm
		mmi.material_override = SurvivalMarks.found_material() if RemnantModels.is_found(name) else _mat
		add_child(mmi)
		_remnant_mm[name] = mm


func _refresh_remnants() -> void:
	var w := game.world
	var here := game.player.pos
	var spent := SurvivalState.of(game).spent
	var sig := "%d:%d:%d" % [w.depleted.size(), w.props.size(), spent.size()]
	if sig == _remnant_sig and here.distance_to(_remnant_at) < 12.0:
		return
	_remnant_sig = sig
	_remnant_at = here
	var lists := {}
	for name: StringName in _remnant_mm:
		lists[name] = []
	for id: int in w.depleted:
		if id < 0 or id >= w.props.size():
			continue
		var p := w.props[id]
		var r := RemnantModels.for_kind(p.kind)
		if r == &"" or p.pos.distance_to(here) > REMNANT_RADIUS:
			continue
		lists[r].append(p)
	# Standing but picked over: one mark of each sort per prop, however many of its options are spent.
	var marked := {}
	for key: String in spent:
		var id := key.get_slice(":", 0).to_int()
		if id < 0 or id >= w.props.size() or w.depleted.has(id):
			continue
		var p := w.props[id]
		var opts := Takes.options(p.kind)
		var index := key.get_slice(":", 1).to_int()
		var verb: StringName = (opts[index] as Dictionary).verb if index >= 0 and index < opts.size() else &""
		var mark := RemnantModels.worked_for(p.kind, verb)
		var mk := "%d:%s" % [id, mark]
		if marked.has(mk) or p.pos.distance_to(here) > REMNANT_RADIUS:
			continue
		marked[mk] = true
		lists[mark].append(p)
	for name: StringName in lists:
		var mm: MultiMesh = _remnant_mm[name]
		var list: Array = lists[name]
		mm.instance_count = list.size()
		for j in list.size():
			var p: WorldProp = list[j]
			var s := p.scale * (1.3 if p.kind == PropKind.BROADLEAF else 1.0)
			# A tap mark faces the camera's side of the trunk (south-east), where it can be seen.
			var turn := -PI * 0.25 if name == &"tapped" else p.rot
			mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * s), w.to_3d(p.pos)))
			var tint := Color.WHITE
			match p.kind:
				PropKind.COPPER_ORE:
					tint = Color(0.86, 1.0, 0.92)
				PropKind.COAL_ORE:
					tint = Color(0.6, 0.6, 0.68)
				PropKind.DEAD_TREE:
					tint = Color(0.8, 0.82, 0.88)
			var k := 0.92 + Rng.hash01(w.seed_value, p.id, 91) * 0.16
			mm.set_instance_color(j, Color(tint.r * k, tint.g * k, tint.b * k))


# --- Fires -------------------------------------------------------------------------

func _scan_fires() -> void:
	var here := game.player.pos
	var seen := {}
	for q in game.query.props_near(here, FIRE_RADIUS):
		if q.kind != PropKind.FIRE or game.world.depleted.has(q.id):
			continue
		seen[q.id] = true
		if not _fires.has(q.id):
			var f := FireModel.new()
			f.name = "fire_%d" % q.id
			f.position = game.world.to_3d(q.pos)
			add_child(f)
			f.build(_mat, q.id)
			_fires[q.id] = f
	for id: int in _fires.keys():
		if not seen.has(id):
			(_fires[id] as Node3D).queue_free()
			_fires.erase(id)
	var dark := FireModel.darkness_at(game.clock.hour())
	for id: int in _fires:
		(_fires[id] as FireModel).darkness = dark
