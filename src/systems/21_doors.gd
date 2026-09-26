extends GameSystem
## DOORS (docs/interiors): walking into a house and out again. A house whose
## landscape declares an interior for it (`BiomeDef.interiors`) has a door
## (`Threshold`), and behind it a POCKET world (`InteriorGen`) that 20_realms
## points the game at, the way a shaft points it at a realm. Not a new game: the
## clock, the score, the body and the creel go in with the player.
##
## THE DOOR ONLY SWAPS. Everything that costs is paid before it:
##   - within WARM of a door the pocket is grown (pure, under a millisecond), and a
##     view of it is made sharing the outside view's materials and put in the
##     tree HIDDEN, so its chunks are built on its own worker while the player
##     walks up (S0 measured growing them at the door at 85-150 ms);
##   - at the door the outside view is taken out of the tree WHOLE -- its chunks,
##     its far land, its in-flight worker tasks, which finish into its own fields
##     -- and the pocket's view is shown, under a cover that closes on the door
##     from above (an iris) or blinks as the eye passes the jamb over the shoulder;
##   - coming out puts the outside view back as it was: nothing is rebuilt (S0:
##     rebinding the coast instead cost about a second).
##
## Inside, the walls are the layout's, handed to the query as blocks; the model
## shows the camera a section from above and the whole room over the shoulder
## (the kind's model, `show_for`); the windows let the sun in along its own bearing.

## A pocket is grown and its view built within this of a door, and a body within
## REACH of one may go through it.
const WARM := 7.0
const REACH := 1.4
## How far out past the doorstep a player comes out: far enough that the eye's
## own floor behind the shoulder (Shoulder.LEAST_BACK) clears the host. At 0.3 a
## player put out of a hatch had the eye inside its housing, which no probe can
## pull out of, because the eye is never let nearer the head than that floor.
const EXIT_OUT := 1.4
## Seconds the cover takes to close and to open, from above and over the shoulder.
const CLOSE := 0.18
const OPEN := 0.24
const BLINK := 0.06
## How much of the sky's light comes in off each window at full day; how hard a
## window's own sun is, and how far below level it shines (a fall of 0.62 for
## each unit across, about thirty-two degrees).
const SKY_IN := 0.35
const SUN_IN := 3.0
const SUN_LOW := 0.62

## The doors of the world outside, and the one within reach, if any.
var doors: Array[Threshold] = []
var door_near: Threshold = null
## Inside: the pocket and what draws it; null outside.
var pocket: InteriorGen.Pocket = null
var model: Node3D = null
var crossings := 0

var _grown: InteriorGen.Pocket = null
var _view: WorldView = null
var _model: Node3D = null
var _outside: WorldData = null
var _outside_view: WorldView = null
var _outside_query: WorldQuery = null
var _outside_key: StringName = &""
var _outside_height := 0.0
var _swapping := false
var _cover: ColorRect
var _cover_mat: ShaderMaterial
var _lights: Array[SpotLight3D] = []
var _windows: Array[Array] = []
## The house's own lights ([OmniLight3D, &"lamp" | &"machine"]), and per window
## the shaft of dusty air its sun stands in, and the motes in it.
var _lamps: Array[Array] = []
var _beams: Array[MeshInstance3D] = []
var _motes: Array[CPUParticles3D] = []
var _beam_mat: StandardMaterial3D
## The swap frames, measured: how long the frame that swapped in and out took.
var swap_in_ms := 0.0
var swap_out_ms := 0.0
var built_after_out := -1


func setup(g: Game) -> void:
	super.setup(g)
	doors = Interiors.thresholds(g.world)
	_stand_hatches()
	SaveGame.register(&"doors", _save, _load)
	Events.time_skipped.connect(_on_time_skipped)
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.name = "door_cover"
	add_child(layer)
	_cover = ColorRect.new()
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover_mat = ShaderMaterial.new()
	_cover_mat.shader = _iris()
	_cover.material = _cover_mat
	_cover.visible = false
	layer.add_child(_cover)


## THE HATCHES OVER THE DEPOTS' HALLS: a door that is not part of anything
## already drawn (a house's door is its model's), so this system draws it, one
## per depot door, and hands its housing to the query as a wall. They stand on
## the world outside and are hidden while the player is in a room.
const Shoulder := preload("res://src/core/view/shoulder.gd")
var _hatches: Node3D
## Each hatch housing as the shoulder camera's probe takes a drawn box
## (Shoulder.box_of): a circle held the query's walk and missed the housing's
## corners, and a player put out at the hatch had the eye pushed into it.
var _hatch_boxes: Array[PackedFloat32Array] = []


func _stand_hatches() -> void:
	if _hatches != null:
		_hatches.queue_free()
	_hatch_boxes.clear()
	_hatches = Node3D.new()
	_hatches.name = "hatches"
	game.add_child(_hatches)
	var mass: Array[Vector3] = []
	for t: Threshold in doors:
		# The kind says what hatch it is entered by; a house has none of its own.
		var k := Interiors.kind(t.kind)
		if k == null or k.hatch == "":
			continue
		var hm := load(k.hatch) as GDScript
		var n: Node3D = hm.call(&"node", game.view.world_material())
		n.position = game.world.to_3d(t.host)
		n.rotation.y = -t.rot
		_hatches.add_child(n)
		var c := hm.get_script_constant_map()
		mass.append(Vector3(t.host.x, t.host.y, float(c.REACH)))
		_hatch_boxes.append(Shoulder.box_of(t.host, t.rot, 1.0, c.LO, c.HI, n.position.y + float(c.TOP)))
	game.query.set_blocks(&"hatches", mass)


## A room's walls as the shoulder camera's probe takes them: one box a unit of
## wall, and one across the outside of the way in. The walls a body is stopped by
## are circles of 0.3, and the probe lets anything thinner than Shoulder.THIN
## (0.38) through along its line -- it takes them for poles -- so without these
## the eye went straight through a room's walls and the frame over the shoulder
## was the backs of them against the sky.
var _room_boxes: Array[PackedFloat32Array] = []


func _box_the_room() -> void:
	_room_boxes.clear()
	var l := pocket.layout
	var top := game.world.height_at(l.inside()) + pocket.kind.wall_h + 1.0
	for e: Dictionary in l.edges:
		if e.kind == &"door" or e.kind == &"inner":
			continue
		var a: Vector2 = e.a
		var b: Vector2 = e.b
		# As long as its edge: a round room's are chords, not unit tiles.
		var half := (b - a).length() * 0.5 + 0.12
		_room_boxes.append(Shoulder.box_of((a + b) * 0.5, (b - a).angle(), 1.0, Vector2(-half, -0.16), Vector2(half, 0.16), top))
	# The way in: a hole in the walls with nothing beyond it.
	_room_boxes.append(Shoulder.box_of(l.door + l.door_out * 0.8, l.door_out.angle(), 1.0, Vector2(-0.8, -0.9), Vector2(0.8, 0.9), top + 5.0))


## The hatch housings near `mid`, for the shoulder camera's probe (41_shoulder).
## In a room, the room's own walls hold the eye -- all but the way in, which is a
## hole in them with nothing beyond it: a player standing just inside turned the
## eye out through it, and the frame was the backs of the walls against the sky.
## So in a room the doorway's outside is a box too.
func sight_boxes(mid: Vector2, reach: float) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	if pocket != null:
		for b: PackedFloat32Array in _room_boxes:
			if Vector2(b[0], b[1]).distance_to(mid) <= reach + 1.0:
				out.append(b)
		return out
	for b: PackedFloat32Array in _hatch_boxes:
		if Vector2(b[0], b[1]).distance_to(mid) <= reach + 1.5:
			out.append(b)
	return out


## A game that ends with the player indoors still holds the coast's view, out of
## the tree, where nothing else will free it: freed here, so its workers are
## waited for (WorldView, at predelete) before the engine quits under them.
func _exit_tree() -> void:
	if _outside_view != null and is_instance_valid(_outside_view) and not _outside_view.is_inside_tree():
		_outside_view.free()
	_outside_view = null


func _process(delta: float) -> void:
	var down := Input.is_action_pressed(&"use")
	_use_edge = down and not _use_was
	_use_was = down
	if game == null or game.world == null or game.player == null or _swapping:
		return
	if game.watch.is_finite():
		return
	if pocket == null:
		_outside_side()
	else:
		_inside_side(delta)


func _outside_side() -> void:
	var at := game.player.pos
	door_near = null
	var best: Threshold = null
	var bd := INF
	for t: Threshold in doors:
		var d := t.door.distance_squared_to(at)
		if d < bd:
			bd = d
			best = t
	if best == null or bd > WARM * WARM:
		return
	# The nearest is grown while the player comes; the one they mean is the one
	# whose house they face (Interiors.door_for).
	var meant := Interiors.door_for(doors, at, game.player.hero.facing, REACH)
	_begin(meant if meant != null else best)
	if meant != null:
		door_near = meant
		if _pressed() and _door_wins(meant.door):
			go_in(meant)


func _inside_side(_delta: float) -> void:
	var cam := game.camera
	var back := Vector2(cam.global_transform.basis.z.x, cam.global_transform.basis.z.z)
	if back.length() > 0.001:
		back = back.normalized()
	model.call(&"show_for", back, cam.shoulder_share())
	# From above, the room is framed on its middle rather than on the doorway the
	# player is standing in, most of the way: the player stays in the picture.
	var mid := _room_middle()
	var lean := (mid - game.player.pos) * 0.7 if cam.shoulder_share() < 0.5 else Vector2.ZERO
	cam.frame_bias = Vector3(lean.x, 0.0, lean.y)
	_light_windows()
	door_near = null
	if game.player.pos.distance_to(pocket.layout.door) <= REACH:
		door_near = pocket.threshold
		if _pressed():
			go_out()
			return
	_keep_hours()
	_trespass()
	_run_turrets()
	box_near = _box_near()
	if box_near >= 0 and _pressed():
		_open_box(box_near)
	hatch_near = _hatch_near()
	if hatch_near >= 0 and box_near < 0 and _pressed():
		_take_meal(hatch_near)
	stove_near = _stove_near()
	if stove_near >= 0 and box_near < 0 and hatch_near < 0 and _pressed():
		_relight(stove_near)
	crawl_near = _crawl_near()
	if crawl_near and box_near < 0 and hatch_near < 0 and stove_near < 0 and _pressed():
		go_out(true)
	_show_trays()


## The press is this system's own edge (down now, up the frame before), not
## `is_action_just_pressed`: that answers only in the frame the key went down, so
## a press made later in a frame than this system runs -- a tour's, from a system
## numbered after it -- is never seen at all.
var _use_was := false
var _use_edge := false


## Whether `use` is this door's this frame, so nothing else answers it: while a
## door is swapping, inside a room at its door, and outside at a door that wins
## the key (`_door_wins`). 49_story asks every system this before it answers, as
## it does of a shaft. Without it the press that took a player IN also opened a
## conversation with a villager outside, which stayed open unseen in the room,
## and the press meant to let them out closed that instead -- measured in a tour.
func use_spent() -> bool:
	if _swapping:
		return true
	if pocket != null and (box_near >= 0 or hatch_near >= 0 or stove_near >= 0 or crawl_near):
		return true
	if door_near == null:
		return false
	return pocket != null or _door_wins(door_near.door)


func _pressed() -> bool:
	if game.input_blocked() or not _use_edge:
		return false
	for s in game.systems:
		if s != self and s.has_method(&"use_spent") and bool(s.call(&"use_spent")):
			return false
	return true


## `use` is one key: the door takes it only when it is nearer than whatever is
## under the hand, as a shaft does (20_realms `_shaft_wins`).
##
## A door the player is FACING wins outright: a bush growing against a hatch was
## a hair nearer than its door, so the key gathered the bush every time.
func _door_wins(at: Vector2) -> bool:
	var to_door := at - game.player.pos
	if to_door.length() > 0.01 and Vector2.from_angle(game.player.hero.facing).dot(to_door.normalized()) > 0.7:
		return true
	var t := Survival.use_target(game)
	return t == null or at.distance_to(game.player.pos) <= t.pos.distance_to(game.player.pos)


## Grow the pocket behind `t` and a hidden view of it, once, while the player is
## on the way to its door.
func _begin(t: Threshold) -> void:
	if _grown != null and _grown.threshold.key == t.key:
		return
	_drop_grown()
	_grown = InteriorGen.grow(game.options.seed_value, t)
	if _grown == null:
		return
	_view = WorldView.new()
	_view.name = "pocket"
	_view.setup_sharing(_grown.world, game.view)
	_view.visible = false
	_view.focus = _grown.world.spawn
	# The kind names its model by path (InteriorKind.model): a cottage and a
	# machines' hall are drawn by different scripts answering the same calls.
	_model = (load(_grown.kind.model) as GDScript).new()
	_model.name = "rooms"
	_model.call(&"build", _grown.layout, _grown.kind, t.land, game.view.world_material())
	_view.add_child(_model)
	game.add_child(_view)


func _drop_grown() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	_model = null
	_grown = null


## Through the door, under the cover.
func go_in(t: Threshold) -> void:
	if pocket != null or _swapping:
		return
	_begin(t)
	if _grown == null:
		return
	Events.sfx.emit(&"door", game.player.position)
	await _cover_close(t.door)
	var t0 := Time.get_ticks_usec()
	_swap_in()
	swap_in_ms = (Time.get_ticks_usec() - t0) / 1000.0
	await _cover_open()


func _swap_in() -> void:
	var realms := _realms()
	var p := _grown
	_outside = game.world
	_outside_view = game.view
	_outside_query = game.query
	_outside_key = realms.get("_realm")
	_outside_height = game.camera.view_height
	game.set_meta(SaveCore.META_OUTSIDE, _outside)
	_hatches.visible = false
	game.remove_child(_outside_view)
	_view.visible = true
	game.view = _view
	pocket = p
	model = _model
	_grown = null
	realms.set("pocket_closed", p.kind.closed)
	realms.call(&"enter", p.world, p.threshold.realm_key(), p.layout.inside())
	game.query.set_blocks(&"rooms", _walls(p.layout))
	game.camera.view_height = p.kind.zoom
	_windows = model.call(&"windows")
	_make_lights()
	_box_the_room()
	_light_stoves()
	_wake_residents()
	_stand_turrets()
	crossings += 1


## Out of the door, under the cover, onto the world that was left: the same one.
func go_out(back := false) -> void:
	if pocket == null or _swapping:
		return
	_out_back = back
	Events.sfx.emit(&"door", game.player.position)
	await _cover_close(pocket.layout.door)
	var t0 := Time.get_ticks_usec()
	var before := _outside_view.build_count
	_swap_out()
	swap_out_ms = (Time.get_ticks_usec() - t0) / 1000.0
	await _cover_open()
	built_after_out = game.view.build_count - before


# --- who is in a room ------------------------------------------------------------

## ARRESTED IN A ROOM, PUT OUT OF IT. A warden's blow stands a body at the side
## of the track until it is done with them (40_fight: the hours pass, every body
## is cleared); in the hall it keeps, the side of the track is outside its door.
## Left inside instead, the hour passed in an empty hall that came back full the
## next time the player walked in -- and the arrest meant nothing.
func _on_time_skipped(_minutes: float, reason: StringName) -> void:
	if reason == &"arrested" and pocket != null and not _swapping:
		go_out()


## A ROOM'S RESIDENTS are put into the fight on the way in, where the recipe
## stood them, as the bodies the host's land keeps: a keeper is the plan's own
## warden, a guard the first hunter the land's roster names. A hunter is hostile
## by its role. A keeper is wary, and TURNS when it notices the player in what it
## holds -- its own suspicion, which the stealth rules raise, reaching 1 -- as
## trespass (`_trespass`). Disturbed on the way in instead, a warden crossed the
## hall and arrested whoever opened the hatch within a second, every time. One
## that is broken stays broken: the dead are kept per door, and saved.
var _residents: Array[Array] = []
var _dead: Dictionary = {}


# --- what a hall guards --------------------------------------------------------

## THE WARDEN HOLDS THE HALL. While it stands, the turrets high in the corners
## turn on whoever is in their line and fire (HallTurret, through
## `FightSim.strike_hero`), and the strongboxes in the bays are shut. Broken, it
## lets go of both: the turrets stand down and the boxes open to the `use` key,
## each once, rolled on the kind's table in the one economy (Interiors.LOOT).
var _turrets: Array[HallTurret] = []
var _opened: Dictionary = {}
## The strongbox in reach (its index among the layout's), -1 for none.
var box_near := -1
## Latched, for a tour: a turret fired, a box was refused, a box was opened.
var _turret_fired := false
## Live: a turret is coming round on the player this frame (the eye is hot).
var _aiming := false
var _box_refused := false
## Latched, for a tour: a docked sleeper woke and turned.
var _woke := false
var _box_opened := false


func _warden_stands() -> bool:
	for pair: Array in _residents:
		var m: MobState = pair[1]
		if m.kind == &"warden" and m.alive:
			return true
	return false


func _stand_turrets() -> void:
	_turrets.clear()
	for t: Dictionary in pocket.layout.things:
		if t.kind == &"turret":
			_turrets.append(HallTurret.new(t.at, t.face, float(_turrets.size()) * StealthQuery.SWEEP_PERIOD * 0.37))


## What a hall turret's eye is to the stealth rules: a machine's optics that see
## as far as it reaches.
const TURRET_EYE := {"sees": HallTurret.REACH, "machine": true, "role": &"watcher"}
## The walls between the pocket's rooms, by their middles (`_corner`), for the
## turrets' lines. Built on first ask; cleared with the room.
var _walls_between: Dictionary = {}


func _run_turrets() -> void:
	if _turrets.is_empty():
		return
	var sim: FightSim = game.player.sim
	var armed := _warden_stands()
	var now := sim.now
	_aiming = false
	var target := game.player.pos
	for i in _turrets.size():
		var tu := _turrets[i]
		if not armed:
			model.call(&"aim_turret", i, tu.facing, false)
			continue
		var clear := _turret_sees(tu.at, target)
		# Its eye is a watcher's optics: idle, it sweeps its cone to and fro on
		# a fixed rhythm, and NOTICES the player only in that cone and within
		# what it sees of them as they are (StealthQuery: less of someone
		# crouched in the dark). Once it has come round on them it keeps its
		# full reach. Noticing anyone in its line at eight tiles, it found every
		# player in the hall however quiet, and its shots woke every machine.
		if not tu.aiming():
			tu.facing = tu.swept(now)
			if clear and not _turret_notices(tu, target, sim):
				clear = false
		var what := tu.step(now, target, clear)
		model.call(&"aim_turret", i, tu.facing, what == &"aim", tu.at.distance_to(target))
		_aiming = _aiming or what == &"aim"
		if what == &"aim" and now - tu.aim_since < 20.0:
			Events.sfx.emit(&"turret_aim", game.world.to_3d(tu.at))
		elif what == &"fire":
			Events.sfx.emit(&"turret_fire", game.world.to_3d(tu.at))
			if sim.strike_hero(HallTurret.blow(), tu.at):
				_turret_fired = true


## Whether a turret that has nobody would notice someone at `p` now: in its
## swept cone, in its sight of them as they are, in its line.
func _turret_notices(tu: HallTurret, p: Vector2, sim: FightSim, facing: float = NAN) -> bool:
	var f := tu.facing if is_nan(facing) else facing
	if tu.at.distance_to(p) > StealthQuery.sight_range(TURRET_EYE, sim.moment):
		return false
	if not StealthQuery.in_cone(tu.at, f, p, StealthQuery.cone_half(TURRET_EYE)):
		return false
	return _turret_sees(tu.at, p)


## `walkto` asks this of each next step: would anything in the room have the
## player there -- a resident's sight, or a turret's swept cone now or a second
## from now (the time a step takes)? A patient player waits until it would not.
func tour_safe(p: Vector2) -> bool:
	if pocket == null:
		return true
	var sim: FightSim = game.player.sim
	for pair: Array in _residents:
		var m: MobState = pair[1]
		if m.alive and not m.asleep and StealthQuery.sees(m.row, m.pos, p, sim.moment, sim.world, sim.query, m.facing):
			return false
	if _warden_stands():
		for tu: HallTurret in _turrets:
			for ahead: float in [0.0, 500.0, 1000.0]:
				if _turret_notices(tu, p, sim, tu.swept(sim.now + ahead)):
					return false
	return true


## A turret is mounted high: it sees OVER the racks and the gantry's legs, which
## stand in the query as walls a body cannot pass. What blocks it is the room's
## own shape -- a line that leaves the floor goes through a wall. (Asked of every
## block, a corner turret's line to a player by the door ran along the wall
## through the racks, and no turret ever fired.)
##
## Nor through a wall between two rooms: both sides are floor, so a line from a
## hall's corner into a bay passed every floor check and the bay was no cover.
## A step from one tile to the next crosses the edge between them, and only a
## doorway (an &"inner" edge) lets it through.
func _turret_sees(a: Vector2, b: Vector2) -> bool:
	if _screens(a, b):
		return false
	if _walls_between.is_empty():
		for e: Dictionary in pocket.layout.edges:
			if e.inner and e.kind != &"inner":
				_walls_between[_corner(((e.a as Vector2) + (e.b as Vector2)) * 0.5)] = true
	var n := ceili(a.distance_to(b) / 0.25)
	var last := Vector2i(floori(a.x), floori(a.y))
	for i in range(1, n):
		var q := a.lerp(b, float(i) / float(n))
		var tile := Vector2i(floori(q.x), floori(q.y))
		if not pocket.layout.is_floor(tile.x, tile.y):
			return false
		if tile != last:
			if tile.x != last.x and _walls_between.has(_corner(Vector2(maxi(tile.x, last.x), last.y + 0.5))):
				return false
			if tile.y != last.y and _walls_between.has(_corner(Vector2(tile.x + 0.5, maxi(tile.y, last.y)))):
				return false
			last = tile
	return true


## Whether a thing that stands to the ceiling (`screens`: a foundry's cooling
## racks) is across the line from `a` to `b`: a turret high in a corner sees over
## a gantry's leg and a strongbox, but not through a rack as tall as the room.
## Its footprint is `long` across its face and `SCREEN_DEEP` through it.
const SCREEN_DEEP := 0.3


func _screens(a: Vector2, b: Vector2) -> bool:
	return screened(pocket.layout, a, b)


static func screened(l: InteriorLayout, a: Vector2, b: Vector2) -> bool:
	var n := ceili(a.distance_to(b) / 0.2)
	for t: Dictionary in l.things:
		if not t.get("screens", false):
			continue
		var f: Vector2 = t.face
		var s := Vector2(-f.y, f.x)
		var half := float(t.get("long", 0.6)) * 0.5
		for i in range(1, n):
			var q := a.lerp(b, float(i) / float(n)) - (t.at as Vector2)
			if absf(q.dot(s)) <= half and absf(q.dot(f)) <= SCREEN_DEEP:
				return true
	return false


## How much of a body's noise the room it is in swallows (InteriorKind.hush):
## 0 outside a room. 32_disposition turns the player's loudness down by it.
func room_hush() -> float:
	return pocket.kind.hush if pocket != null and working() else 0.0


## HOW DARK THE ROOM IS AT `p` to the machines' eyes (InteriorKind.dark), where
## its own light does not reach: each thing with a `glare` lights a pool that
## far round it -- along the whole of a thing with a `long` -- and undoes the
## dark there, fully within half of it. 0 outside a room. 32_disposition takes
## the darker of this and the night.
func room_dark(p: Vector2) -> float:
	if pocket == null:
		return 0.0
	return dark_at(pocket.kind, pocket.layout, p, working())


static func dark_at(k: InteriorKind, l: InteriorLayout, p: Vector2, at_work := true) -> float:
	if k.dark <= 0.0:
		return 0.0
	var lit := 0.0
	for t: Dictionary in l.things:
		var r := float(t.get("glare", 0.0))
		# What runs on the shift is dark at the curfew.
		if r <= 0.0 or (t.get("shift", false) and not at_work):
			continue
		var f: Vector2 = t.face
		var s := Vector2(-f.y, f.x)
		var q := p - (t.at as Vector2)
		var half := float(t.get("long", 0.0)) * 0.5
		var along := clampf(q.dot(s), -half, half)
		var d := (q - s * along).length()
		lit = maxf(lit, 1.0 - smoothstep(r * 0.5, r, d))
	return k.dark * (1.0 - lit)


# --- what a room feeds -----------------------------------------------------

## A THING THAT SERVES (`serves`: an item, `meals`: the hours it serves at):
## a grey orchards house's food hatch, which the machines still fill on the
## household's schedule. At each meal hour a meal is put out, and it is there
## until the next meal: taken, it is taken for that meal, per door, and saved.
## Before the first meal of a day it still holds last night's.
var hatch_near := -1
var _served: Dictionary = {}
var _meal_taken := false


## Which serving thing is in reach of the player's hands (its index among the
## layout's things that serve), or -1.
func _hatch_near() -> int:
	if pocket == null:
		return -1
	var i := 0
	var best := -1
	var bd := 1.4
	for t: Dictionary in pocket.layout.things:
		if not t.has("serves"):
			continue
		var d := (t.at as Vector2).distance_to(game.player.pos)
		if d < bd:
			bd = d
			best = i
		i += 1
	return best


## A serving thing's tray (the model's `tray_N` child) stands behind the glass
## while its meal is out, and is gone once that meal is taken.
func _show_trays() -> void:
	if _model == null:
		return
	var n := 0
	for t: Dictionary in pocket.layout.things:
		if not t.has("serves"):
			continue
		var tray := _model.get_node_or_null("tray_%d" % n) as Node3D
		if tray != null:
			var stamp := meal_at(t.get("meals", [7, 12, 18]), game.clock.minutes)
			tray.visible = stamp >= 0 and int(_served.get("%s#%d" % [pocket.threshold.key, n], -9)) != stamp
		n += 1


# --- a stove to relight ------------------------------------------------------------

## A thing with a `fuel` (a frozen hold's galley stove) is out until the player
## feeds it what a campfire burns, without the stones: then it is a FIRE in the
## room's world -- warmth against the land's cold (52_hazards), light, and
## somewhere to sleep (Survival.fire_near) -- and it stays lit for whoever
## comes back, saved per door. Its flame is the model's (`stove_lit`), not a
## campfire's: the prop is put in the world and its query, never in the view.
var stove_near := -1
var _lit: Dictionary = {}
## Latched, for a tour: a stove was lit.
var _kindled := false


func _stove_near() -> int:
	if pocket == null:
		return -1
	var i := 0
	var best := -1
	var bd := 1.4
	for t: Dictionary in pocket.layout.things:
		if not t.has("fuel"):
			continue
		var d := (t.at as Vector2).distance_to(game.player.pos)
		if d < bd and not _lit.has("%s#%d" % [pocket.threshold.key, i]):
			bd = d
			best = i
		i += 1
	return best


## What a stove takes to light from what is carried: the first campfire's
## makings that can be met, less its stones; empty for none.
static func stove_fuel(inv: Inventory) -> Dictionary:
	for r: Dictionary in Crafting.recipes_at(&"hand"):
		if r.get("builds", &"") != &"fire":
			continue
		var needs := (r.needs as Dictionary).duplicate()
		needs.erase(&"stone")
		var ok := not needs.is_empty()
		for id: Variant in needs:
			ok = ok and inv.count(StringName(id)) >= int(needs[id])
		if ok:
			return needs
	return {}


func _relight(i: int) -> void:
	var fuel := stove_fuel(game.inventory)
	if fuel.is_empty():
		Events.message.emit("The stove is cold. It wants something to burn: driftwood, dead wood, peat or timber.")
		return
	for id: Variant in fuel:
		game.inventory.remove(StringName(id), int(fuel[id]))
	_lit["%s#%d" % [pocket.threshold.key, i]] = true
	_kindle(i)
	_kindled = true
	Events.sfx.emit(&"build_fire", game.player.position)
	Events.message.emit("The stove takes. The iron ticks as it warms, and the hold with it.")


func _light_stoves() -> void:
	var n := 0
	for t: Dictionary in pocket.layout.things:
		if t.has("fuel"):
			if _lit.has("%s#%d" % [pocket.threshold.key, n]):
				_kindle(n)
			n += 1


func _kindle(i: int) -> void:
	var n := 0
	for t: Dictionary in pocket.layout.things:
		if not t.has("fuel"):
			continue
		if n == i:
			var w := game.world
			var prop := WorldProp.new(w.next_id(), PropKind.FIRE, t.at, 0.0, 1.0)
			w.add_prop(prop)
			game.query.add_prop(prop)
			if model != null and model.has_method(&"stove_lit"):
				model.call(&"stove_lit", i)
			return
		n += 1


# --- a second way out -------------------------------------------------------------

## A thing with `exit` (a squat's hole through the back wall) is a way out that
## is not the door: crawled through, it puts the player out BEHIND the house,
## as far back from it as the door stands in front, where there is ground to
## stand on -- else, as a door does, in front.
var crawl_near := false
var _out_back := false
## Latched, for a tour: the player went out the back way.
var _went_out_back := false


func _crawl_near() -> bool:
	if pocket == null:
		return false
	for t: Dictionary in pocket.layout.things:
		if t.get("exit", false) and (t.at as Vector2).distance_to(game.player.pos) < 1.1:
			return true
	return false


func _back_of(t: Threshold) -> Vector2:
	var depth := t.door.distance_to(t.host)
	var q: WorldQuery = _outside_query
	for extra: float in [0.3, 0.8, 1.4]:
		var p := t.host - t.out * (depth + extra)
		if q == null or q.standable(floori(p.x), floori(p.y)):
			return p
	return t.door + t.out * EXIT_OUT


## The meal a thing serving at `hours` has out at `minutes`: a stamp (day * 8 +
## which meal), or -1 before its first meal ever.
static func meal_at(hours: Array, minutes: float) -> int:
	var day := floori(minutes / 1440.0)
	var hour := fmod(minutes / 60.0, 24.0)
	var last := -1
	for m in hours.size():
		if hour >= float(hours[m]):
			last = m
	if last < 0:
		return (day - 1) * 8 + hours.size() - 1 if day > 0 else -1
	return day * 8 + last


func _take_meal(i: int) -> void:
	var th: Dictionary = {}
	var n := 0
	for t: Dictionary in pocket.layout.things:
		if t.has("serves"):
			if n == i:
				th = t
			n += 1
	var hours: Array = th.get("meals", [7, 12, 18])
	var stamp := meal_at(hours, game.clock.minutes)
	var key := "%s#%d" % [pocket.threshold.key, i]
	if stamp < 0 or int(_served.get(key, -9)) == stamp:
		var hour := fmod(game.clock.minutes / 60.0, 24.0)
		var next: int = hours[0]
		for h: Variant in hours:
			if float(h) > hour:
				next = int(h)
				break
		Events.message.emit("The hatch is shut. It opens again at %02d:00." % next)
		return
	var got: Array[String] = []
	var serves: Dictionary = th.serves
	for id: Variant in serves:
		var c := int(serves[id])
		game.inventory.add(StringName(id), c)
		Events.took.emit(StringName(id), c)
		got.append(String(Items.def(StringName(id)).get("name", id)))
	_served[key] = stamp
	_meal_taken = true
	Events.sfx.emit(&"door", game.player.position)
	Events.message.emit("The hatch slides up on a tray: %s, still hot. It was set for four." % " and ".join(got))


## Which strongbox is within reach of the player's hands, or -1.
func _box_near() -> int:
	var i := 0
	var best := -1
	var bd := 1.4
	for t: Dictionary in pocket.layout.things:
		if t.kind != &"strongbox":
			continue
		var d := (t.at as Vector2).distance_to(game.player.pos)
		if d < bd:
			bd = d
			best = i
		i += 1
	return best


func _open_box(i: int) -> void:
	var key := pocket.threshold.key
	var done: Array = _opened.get(key, [])
	if done.has(i):
		Events.message.emit("It is empty. You emptied it.")
		return
	if _warden_stands():
		_box_refused = true
		Events.message.emit("It is shut, and it answers to the warden. Not while that stands.")
		return
	var land := BiomeRegistry.by_index(pocket.threshold.land).id
	var instance := Rng.hash_ints(game.options.seed_value, key.hash(), i, 0x5B0C)
	var got: Array[String] = []
	for row: Dictionary in Drops.roll(Interiors.loot_source(pocket.kind.id), game.options.seed_value, instance, land):
		var id: StringName = row.item
		var n := int(row.count)
		if Items.def(id).is_empty() or n <= 0:
			continue
		game.inventory.add(id, n)
		Events.took.emit(id, n)
		got.append("%s x%d" % [String(Items.def(id).get("name", id)), n])
	done.append(i)
	_opened[key] = done
	_box_opened = true
	Events.sfx.emit(&"door", game.player.position)
	Events.message.emit("The box gives up what the plan kept in it: %s." % ", ".join(got) if not got.is_empty() else "The box is empty.")


## A keeper that has noticed the player in the room it holds takes it as
## trespass, once.
func _trespass() -> void:
	var sim: FightSim = game.player.sim
	for pair: Array in _residents:
		var m: MobState = pair[1]
		if not m.alive or m.suspicion < 0.99 or pair.has(&"turned"):
			continue
		if Roles.of(m.kind) == Roles.KEEPER:
			sim.disturb(m, &"trespass")
			pair.append(&"turned")
		elif pocket.layout.residents[pair[0]].get("docks", false):
			# Woken in its dock with somebody in its store: whatever it is, it
			# takes that for theft, which a worker turns on (Roles.TURNS).
			sim.disturb(m, &"theft")
			pair.append(&"turned")
			_woke = true


func _sleepers() -> int:
	var n := 0
	for pair: Array in _residents:
		var m: MobState = pair[1]
		if m.alive and m.asleep:
			n += 1
	return n


## Whether the room is at its work now (InteriorKind.shift): outside the room,
## always.
func working() -> bool:
	return pocket == null or pocket.kind.working(fmod(game.clock.minutes / 60.0, 24.0))


## THE SHIFT COMES ROUND while the player is inside: whoever sleeps in a dock
## wakes when the room goes back to work, and goes about it.
func _keep_hours() -> void:
	if not working():
		return
	for pair: Array in _residents:
		var m: MobState = pair[1]
		if m.asleep:
			m.asleep = false


func _wake_residents() -> void:
	_residents.clear()
	if game.options.rooms_empty:
		return
	var sim: FightSim = game.player.sim
	if sim == null:
		return
	var gone: Array = _dead.get(pocket.threshold.key, [])
	for i in pocket.layout.residents.size():
		if gone.has(i):
			continue
		var r: Dictionary = pocket.layout.residents[i]
		# Its hours (InteriorKind.shift): one "on" the shift is here only while
		# the room works; one that "docks" comes home at the curfew and sleeps.
		var at_work := working()
		if (r.get("on", &"") == &"shift" and not at_work) or (r.get("docks", false) and at_work):
			continue
		var kind := _body_for(StringName(r.role), pocket.threshold.land)
		if r.has("body") and not Roster.row(StringName(r.body)).is_empty():
			kind = StringName(r.body)
		if kind == &"":
			continue
		var m := sim.add_mob(kind, r.at)
		m.asleep = bool(r.get("docks", false))
		m.home = r.at
		m.facing = (r.face as Vector2).angle()
		m.aim = m.facing
		# Every resident STANDS ITS WATCH where the recipe put it, facing what it
		# keeps: a round of no length (Brains). Left the beat every idle machine
		# is given (MobState: six tiles each way along its facing), it walked
		# through a seven-deep hall's walls, turned at the ends toward the hatch,
		# and whoever came down it was seen within the second, however quiet.
		m.line_a = r.at
		m.line_b = r.at
		_residents.append([i, m])


## Which roster body a role is, in the land the host stands in.
static func _body_for(role: StringName, land: int) -> StringName:
	if role == &"warden" and not Roster.row(&"warden").is_empty():
		return &"warden"
	var d := BiomeRegistry.by_index(land)
	var first := &""
	if d != null:
		for kind: Variant in d.roster:
			var k := StringName(str(kind))
			if not _walks_a_hall(k):
				continue
			if first == &"":
				first = k
			if Roles.of(k) == Roles.HUNTER:
				return k
	return first if first != &"" else &"runner"


## Whether a body can keep a hall: a machine that walks the floor, fits between
## the racks and the gantry's legs, and fights what it finds with a blow of its
## own. The coast's roster lists a flock first among its hunters, and a flock
## passes over and cannot be fought; its dredger (0.65 across the middle) stood
## wedged among the gantry's legs raising the alarm, and the warden came.
## Nothing on the coast fits, so its halls keep the plan's own runner.
const HALL_BODY := 0.5


static func _walks_a_hall(k: StringName) -> bool:
	var row := Roster.row(k)
	if row.is_empty() or not bool(row.get("machine", false)):
		return false
	if row.get("crosses", &"") == &"fly":
		return false
	if float(row.get("radius", 1.0)) > HALL_BODY:
		return false
	return row.has("bite")


func _count_the_dead() -> void:
	_count_live_dead()
	_residents.clear()


## Who has died in which room: the one thing about a room's residents worth
## keeping, because the room and who stands in it are grown again from the key.
func _save() -> Variant:
	_count_live_dead()
	var out := {}
	for k: Variant in _dead:
		out[str(k)] = _dead[k]
	var opened := {}
	for k: Variant in _opened:
		opened[str(k)] = _opened[k]
	var served := {}
	for k: Variant in _served:
		served[str(k)] = _served[k]
	var lit := {}
	for k: Variant in _lit:
		lit[str(k)] = true
	return {"dead": out, "opened": opened, "served": served, "lit": lit}


func _load(v: Variant) -> void:
	_dead.clear()
	if not (v is Dictionary):
		return
	var d: Dictionary = (v as Dictionary).get("dead", {})
	for k: Variant in d:
		var idx: Array = []
		for n: Variant in d[k]:
			idx.append(SaveCodec.to_int(n))
		_dead[str(k)] = idx
	_opened.clear()
	var o: Dictionary = (v as Dictionary).get("opened", {})
	for k: Variant in o:
		var idx: Array = []
		for n: Variant in o[k]:
			idx.append(SaveCodec.to_int(n))
		_opened[str(k)] = idx
	_served.clear()
	var sv: Dictionary = (v as Dictionary).get("served", {})
	for k: Variant in sv:
		_served[str(k)] = SaveCodec.to_int(sv[k])
	_lit.clear()
	for k: Variant in (v as Dictionary).get("lit", {}):
		_lit[str(k)] = true


## A save made in a room counts those already broken in it, without leaving.
func _count_live_dead() -> void:
	if pocket == null:
		return
	var gone: Array = _dead.get(pocket.threshold.key, [])
	for pair: Array in _residents:
		if not (pair[1] as MobState).alive and not gone.has(pair[0]):
			gone.append(pair[0])
	if not gone.is_empty():
		_dead[pocket.threshold.key] = gone


## The middle of every room together.
func _room_middle() -> Vector2:
	var box := Rect2(Vector2(pocket.layout.rooms[0].position), Vector2(pocket.layout.rooms[0].size))
	for r: Rect2i in pocket.layout.rooms:
		box = box.merge(Rect2(Vector2(r.position), Vector2(r.size)))
	return box.get_center()


func _swap_out() -> void:
	var realms := _realms()
	_count_the_dead()
	_turrets.clear()
	_walls_between.clear()
	_room_boxes.clear()
	_aiming = false
	box_near = -1
	hatch_near = -1
	crawl_near = false
	stove_near = -1
	game.camera.frame_bias = Vector3.ZERO
	var t := pocket.threshold
	for l: SpotLight3D in _lights:
		_take_back(l)
		l.queue_free()
	_lights.clear()
	for pair: Array in _lamps:
		_take_back(pair[0] as Light3D)
		(pair[0] as Node).queue_free()
	_lamps.clear()
	for b: Node in _beams:
		b.queue_free()
	_beams.clear()
	for m: Node in _motes:
		m.queue_free()
	_motes.clear()
	game.query.set_blocks(&"rooms", [] as Array[Vector3])
	game.remove_meta(SaveCore.META_OUTSIDE)
	_hatches.visible = true
	var inner := game.view
	game.remove_child(inner)
	inner.queue_free()
	game.add_child(_outside_view)
	_outside_view.reclaim()
	game.view = _outside_view
	var out_at := t.door + t.out * EXIT_OUT
	if _out_back:
		out_at = _back_of(t)
		_went_out_back = true
	_out_back = false
	realms.call(&"enter", _outside, _outside_key, out_at, true, _outside_query)
	game.camera.view_height = _outside_height
	pocket = null
	model = null
	_view = null
	_model = null
	_outside = null
	_outside_view = null
	_outside_query = null


func _realms() -> Node:
	for s in game.systems:
		if s.has_method(&"enter") and s.has_method(&"use_spent"):
			return s
	return null


## The walls as the query's blocks: a circle every half tile along every edge
## but the doorways, so a wall stops a body and a doorway lets it through.
##
## Where a wall meets a doorway its end circle is the JAMB's size, not the wall's:
## a full-size circle each side left a doorway 0.4 wide for a body 0.56 across,
## so no room through a doorway could be walked into (tests/interior, walking the
## real query from the door to the bed).
static func _walls(l: InteriorLayout) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var jambs := {}
	for e: Dictionary in l.edges:
		if e.kind == &"door" or e.kind == &"inner":
			jambs[_corner(e.a)] = true
			jambs[_corner(e.b)] = true
	for e: Dictionary in l.edges:
		if e.kind == &"door" or e.kind == &"inner":
			continue
		var a: Vector2 = e.a
		var b: Vector2 = e.b
		for k in 3:
			var p := a.lerp(b, float(k) / 2.0)
			var r := 0.12 if k != 1 and jambs.has(_corner(p)) else 0.3
			out.append(Vector3(p.x, p.y, r))
	# The chimney breast stands out from its wall.
	if l.has_hearth:
		var c := l.hearth + l.hearth_wall * 0.35
		out.append(Vector3(c.x, c.y, 0.55))
	# And what the household keeps: a bed is two tiles long, so two circles.
	for t: Dictionary in l.things:
		var r := float(t.solid)
		if r <= 0.0:
			continue
		var at: Vector2 = t.at
		if t.kind == &"bed":
			var s := Vector2(-(t.face as Vector2).y, (t.face as Vector2).x)
			out.append(Vector3(at.x + s.x * 0.5, at.y + s.y * 0.5, 0.45))
			out.append(Vector3(at.x - s.x * 0.5, at.y - s.y * 0.5, 0.45))
		elif t.has("deep") or t.has("long"):
			# A thing with a length (a pier, a ledge, a partition) stands the
			# whole of it, `deep` along its face through `at`; one that runs
			# along its wall (a rack, a bench) `long` across its face.
			# Circles no further apart than their radius, or a body slips
			# between them along a long ledge or partition.
			var f: Vector2 = t.face
			if t.has("long"):
				f = Vector2(-f.y, f.x)
			var deep := float(t.get("deep", t.get("long")))
			var n := maxi(3, ceili(deep / r) + 1)
			for k in n:
				var q := at + f * deep * (float(k) / float(n - 1) - 0.5)
				out.append(Vector3(q.x, q.y, r))
		else:
			out.append(Vector3(at.x, at.y, r))
	return out


static func _corner(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 2.0), roundi(p.y * 2.0))


# --- light through the windows -------------------------------------------------

## A ROOM'S LIGHTS ARE ON THE TIER'S BUDGET. Each is lent to the lights system
## (15_lights `lend`), which decides which show and which cast out of the same
## `Quality` row as every lamp outside -- this system only aims them and says
## how bright. When the row runs short, the sky fills go first and the window
## suns last, because the sun through a window is what the room is lit by.
const RANK_FILL := 1
const RANK_LAMP := 2
const RANK_SUN := 3


func _lighting() -> Node:
	for sys in game.systems:
		if sys.has_method(&"lend"):
			return sys
	return null


func _lend(l: Light3D, casts: bool, rank: int) -> void:
	var lights := _lighting()
	if lights != null:
		lights.call(&"lend", l, casts, rank)


func _take_back(l: Light3D) -> void:
	var lights := _lighting()
	if lights != null:
		lights.call(&"take_back", l)


func _make_lights() -> void:
	for w: Array in _windows:
		var sky := SpotLight3D.new()
		sky.spot_range = 5.0
		sky.spot_angle = 55.0
		sky.shadow_enabled = false
		sky.light_energy = 0.0
		game.view.add_child(sky)
		_lights.append(sky)
		_lend(sky, false, RANK_FILL)
		var sun := SpotLight3D.new()
		sun.spot_range = 6.0
		sun.spot_angle = 16.0
		sun.spot_attenuation = 0.4
		sun.light_energy = 0.0
		game.view.add_child(sun)
		_lights.append(sun)
		_lend(sun, true, RANK_SUN)
		var beam := MeshInstance3D.new()
		beam.mesh = _beam_mesh()
		beam.material_override = _beam_material()
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.view.add_child(beam)
		_beams.append(beam)
		var motes := _motes_in_air()
		game.view.add_child(motes)
		_motes.append(motes)
	for at: Array in model.get(&"lights"):
		var lamp := _room_light(StringName(at[1]))
		game.view.add_child(lamp)
		lamp.global_position = at[0]
		if lamp is SpotLight3D:
			_aim(lamp, Vector3.DOWN)
		_lamps.append([lamp, at[1]])
		_lend(lamp, false, RANK_LAMP)
		if at[1] == &"strip":
			# THE LIGHT THE POOL THROWS BACK UP: a low cold omni just over the deck
			# under each strip, so the wall panels and ribs beside a pool take a rim
			# from below and separate from the dark -- at eye level the downlight
			# alone lit the deck and left every wall an undifferentiated black. The
			# first to go when the tier's row runs short.
			var bounce := OmniLight3D.new()
			bounce.light_color = Color(0.62, 0.62, 0.8)
			bounce.omni_range = 3.4
			bounce.omni_attenuation = 1.6
			bounce.light_volumetric_fog_energy = 0.0
			bounce.shadow_enabled = false
			game.view.add_child(bounce)
			var foot: Vector3 = at[0]
			bounce.global_position = Vector3(foot.x, game.world.height_at(Vector2(foot.x, foot.z)) + 0.35, foot.z)
			_lamps.append([bounce, &"bounce"])
			_lend(bounce, false, RANK_FILL)


## One of a room's own lights, by what it is. A lantern is warm and reaches the
## room. A stolen strip in a cottage is the one cold light in the house and
## reaches only the bench it hangs over. A hall's strips are the machines' own
## light, a DOWNLIGHT each -- a cone throws a pool on the deck and leaves the dark
## between them, which an omni hung that high could not (it lit nothing it
## reached). The pump's core is the one warm light in a hall's dark end. None
## scatters in the air: their light is on surfaces.
static func _room_light(kind: StringName) -> Light3D:
	var l: Light3D
	if kind == &"strip":
		var sp := SpotLight3D.new()
		sp.spot_range = 4.8
		sp.spot_angle = 46.0
		sp.spot_attenuation = 0.9
		sp.spot_angle_attenuation = 1.4
		l = sp
	elif kind == &"sky":
		# The day down a smoke hole: a narrow grey shaft onto the hearth, as
		# strong as the hour (`_light_windows`), nothing at night.
		var sp := SpotLight3D.new()
		sp.spot_range = 6.0
		sp.spot_angle = 26.0
		sp.spot_attenuation = 0.6
		sp.spot_angle_attenuation = 2.2
		l = sp
	else:
		var o := OmniLight3D.new()
		o.omni_attenuation = 1.2
		o.omni_range = 5.5
		match kind:
			&"machine":
				o.omni_range = 3.2
			&"working":
				o.omni_range = 4.4
				o.omni_attenuation = 1.3
			&"emergency":
				o.omni_range = 3.4
				o.omni_attenuation = 1.5
			&"standby":
				o.omni_range = 1.2
				o.omni_attenuation = 2.0
		l = o
	l.light_color = Color(1.0, 0.7, 0.4) if kind == &"lamp" else Color(0.74, 0.72, 0.9)
	if kind == &"sky":
		l.light_color = Color(0.8, 0.84, 0.9)
	if kind == &"working":
		l.light_color = Color(1.0, 0.66, 0.26)
	elif kind == &"emergency":
		# A battery lamp that has been burning for decades: low, warm, reddened.
		l.light_color = Color(1.0, 0.5, 0.3)
	elif kind == &"standby":
		l.light_color = Color(1.0, 0.62, 0.2)
	l.light_volumetric_fog_energy = 0.0
	l.shadow_enabled = false
	return l


## THE HOUR COMES IN THROUGH THE WINDOWS. A cottage's lid is under the line where
## the sun stops casting (InteriorKind.closed), so the ceiling and the walls shade
## the room. But the game's sun is steep on purpose (SkyLight: it never drops
## below about sixty degrees, for the length of a shadow on screen), and through
## a window in a wall 0.22 thick its patch lands under the sill, where nobody sees
## it. So each window keeps a sun of its own on the sun's BEARING, at `SUN_LOW`,
## lit only while the sun is on that side of the house: the patch walks across
## the boards with the hour and goes when the sun goes round. Beside it, the SKY's
## light, a soft fill off each window, and the sky itself seen in it.
func _light_windows() -> void:
	if game.sky == null or game.sky.sun == null:
		return
	var sun: DirectionalLight3D = game.sky.sun
	var day := clampf(sun.light_energy, 0.0, 1.0)
	var hor := Color(0.62, 0.7, 0.8)
	var env: WorldEnvironment = game.sky.env
	if env != null and env.environment != null and env.environment.sky != null:
		var sm := env.environment.sky.sky_material as ProceduralSkyMaterial
		if sm != null:
			hor = sm.sky_horizon_color
	if model != null:
		# The sky, graded down from the blown white it was, and the land the house
		# stands in under it, hazed toward the sky with distance.
		var ground := _land_colour()
		var lit := lerpf(0.1, 0.9, day)
		model.call(&"daylight", Color(hor.r, hor.g, hor.b) * lerpf(0.14, 0.92, day),
			ground.lerp(hor, 0.28) * lit)
	for pair: Array in _lamps:
		var lamp := pair[0] as Light3D
		match pair[1]:
			&"machine":
				lamp.light_energy = 0.55
			&"strip":
				lamp.light_energy = 5.0
			&"bounce":
				lamp.light_energy = 0.9
			&"working":
				lamp.light_energy = 3.2 if working() else 0.0
			&"emergency":
				lamp.light_energy = 1.1
			&"standby":
				lamp.light_energy = 0.4
			&"sky":
				lamp.light_energy = 2.4 * day
			_:
				lamp.light_energy = lerpf(1.6, 0.25, day)
	for i in _windows.size():
		var at: Vector3 = _windows[i][0]
		var inward2: Vector2 = _windows[i][1]
		var inward := Vector3(inward2.x, 0.0, inward2.y)
		var travel := -sun.global_transform.basis.z
		var flat := Vector3(travel.x, 0.0, travel.z)
		var facing := 0.0
		if flat.length() > 0.01:
			flat = flat.normalized()
			facing = maxf(0.0, flat.dot(inward))
		var beam := (flat + Vector3.DOWN * SUN_LOW).normalized()
		var sp := _lights[i * 2 + 1] as SpotLight3D
		# Stood outside the wall and under the eaves, so the ceiling does not
		# shadow its own window's sun and the opening cuts the patch square.
		sp.global_position = at - beam * 1.5
		_aim(sp, beam)
		sp.light_color = sun.light_color
		sp.light_energy = SUN_IN * sun.light_energy * smoothstep(0.0, 0.35, facing)
		_air_in(i, at, inward2, beam, sp.light_energy / SUN_IN, sun.light_color)
		var fill := _lights[i * 2] as SpotLight3D
		var down := (inward + Vector3.DOWN * 0.45).normalized()
		fill.global_position = at - down * 1.2
		_aim(fill, down)
		fill.light_color = hor.lerp(Color(0.78, 0.84, 1.0), 0.5)
		fill.light_energy = SKY_IN * lerpf(0.15, 1.0, day)


## The land outside, as a colour: the host landscape's grass, or its rock.
func _land_colour() -> Color:
	var d := BiomeRegistry.by_index(pocket.threshold.land) if pocket != null else null
	if d != null and not d.grass_colors.is_empty():
		return d.grass_colors[mini(1, d.grass_colors.size() - 1)]
	return d.rock_color if d != null else Color(0.4, 0.42, 0.36)


## DUST IN THE SUN'S BEAM: a shaft of lit air from the window to the floor, and
## motes turning in it, as strong as the sun that is on the window, over the
## shoulder only. A sheared
## box is the whole beam -- its three columns are the opening's width, its
## height and the way the light goes, to where it meets the floor.
func _air_in(i: int, at: Vector3, inward: Vector2, beam: Vector3, strength: float, col: Color) -> void:
	var shaft := _beams[i]
	var motes := _motes[i]
	# Lit air is seen at eye level; a plan from above does not draw air, and there
	# the shaft read as a pale sheet laid across the room.
	var on := strength > 0.02 and game.camera.shoulder_share() > 0.5
	shaft.visible = on
	motes.emitting = on
	motes.visible = on
	if not on:
		return
	var across := Vector3(-inward.y, 0.0, inward.x)
	# The window's middle is 1.3 over the boards; the beam runs down to them.
	var reach := 1.3 / maxf(-beam.y, 0.2)
	var basis := Basis(across * 0.58, Vector3.UP * 0.8, beam * reach)
	shaft.global_transform = Transform3D(basis, at)
	var m := shaft.material_override as StandardMaterial3D
	# Faint: lit dust is seen, not a pane of light in the room.
	var warm := col.lerp(Color(1.0, 0.86, 0.66), 0.35)
	m.albedo_color = Color(warm.r, warm.g, warm.b, clampf(0.035 * strength, 0.0, 0.05))
	motes.global_transform = Transform3D(basis, at + beam * reach * 0.5)


static func _beam_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c: Array[Vector3] = []
	for z in 2:
		for y in 2:
			for x in 2:
				c.append(Vector3(float(x) - 0.5, float(y) - 0.5, float(z)))
	var faces: Array[Array] = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f: Array in faces:
		for tri: Array in [[f[0], f[1], f[2]], [f[0], f[2], f[3]]]:
			for v: int in tri:
				# Brightest at the window, gone by the floor, so the shaft has no
				# end of its own: it is seen only as lit air.
				st.set_color(Color(1, 1, 1, 1.0 - c[v].z))
				st.add_vertex(c[v])
	return st.commit()


## Transparent, added over what is behind it, and drawn at render priority 11:
## after people (10), so a figure standing in the beam is seen through the lit
## dust, and before MobFx's hit marks (12), which must stay on top.
func _beam_material() -> StandardMaterial3D:
	if _beam_mat == null:
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_beam_mat.vertex_color_use_as_albedo = true
		_beam_mat.render_priority = 11
	return _beam_mat.duplicate() as StandardMaterial3D


## Motes: a few dozen specks drifting in the beam's box, lit by nothing but being
## in it (additive, at the beam's own priority).
func _motes_in_air() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 36
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.5, 0.5, 0.5)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.005
	p.initial_velocity_max = 0.02
	p.gravity = Vector3(0.0, -0.004, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.02)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.9, 0.7, 0.55)
	m.render_priority = 11
	q.material = m
	p.mesh = q
	return p


static func _aim(l: Node3D, dir: Vector3) -> void:
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	l.look_at(l.global_position + dir, up)


# --- the cover -----------------------------------------------------------------

## From above, an iris closing on the doorway; over the shoulder, a blink as the
## eye passes the jamb. Either way the swap happens under full cover.
func _cover_close(at: Vector2) -> void:
	_swapping = true
	_cover.visible = true
	var cam := game.camera
	var over := cam.shoulder_share() > 0.5
	var p := cam.unproject_position(Vector3(at.x, game.player.position.y + 1.0, at.y))
	var size := get_viewport().get_visible_rect().size
	_cover_mat.set_shader_parameter(&"centre", Vector2(p.x / maxf(size.x, 1.0), p.y / maxf(size.y, 1.0)))
	_cover_mat.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))
	var tw := create_tween()
	_cover_mat.set_shader_parameter(&"radius", 1.6)
	tw.tween_method(func(r: float) -> void: _cover_mat.set_shader_parameter(&"radius", r), 1.6, 0.0, BLINK if over else CLOSE)
	await tw.finished


func _cover_open() -> void:
	var over := game.camera.shoulder_share() > 0.5
	var size := get_viewport().get_visible_rect().size
	var p := game.camera.unproject_position(game.player.position + Vector3(0, 1.0, 0))
	_cover_mat.set_shader_parameter(&"centre", Vector2(p.x / maxf(size.x, 1.0), p.y / maxf(size.y, 1.0)))
	var tw := create_tween()
	tw.tween_method(func(r: float) -> void: _cover_mat.set_shader_parameter(&"radius", r), 0.0, 1.6, BLINK * 2.0 if over else OPEN)
	await tw.finished
	_cover.visible = false
	_swapping = false


static func _iris() -> Shader:
	var s := Shader.new()
	s.code = """shader_type canvas_item;
uniform vec2 centre = vec2(0.5);
uniform float radius = 1.6;
uniform float aspect = 1.7778;
void fragment() {
	vec2 d = (UV - centre) * vec2(aspect, 1.0);
	float edge = smoothstep(radius, radius + 0.012, length(d));
	COLOR = vec4(0.018, 0.016, 0.02, edge);
}
"""
	return s


# --- what a tour may ask, and where it may stand -------------------------------

## An `await` means since I last asked: the three events this system latches are
## spent when a tour's question is answered.
func tour_forget(what: StringName) -> void:
	match what:
		&"turret_shot":
			_turret_fired = false
		&"box_refused":
			_box_refused = false
		&"box_opened":
			_box_opened = false
		&"meal_taken":
			_meal_taken = false
		&"kindled":
			_kindled = false
		&"out_back":
			_went_out_back = false
		&"woke":
			_woke = false


func tour_seen(what: StringName) -> bool:
	match what:
		&"turret_shot":
			return _turret_fired
		# No turret has fired since the tour last asked for a shot: held the whole
		# time, where `unnoticed` is the moment of the frame.
		&"unshot":
			return pocket != null and not _turret_fired
		&"turret_aiming":
			return pocket != null and _aiming
		&"box_refused":
			return _box_refused
		&"box_opened":
			return _box_opened
		&"box_near":
			return pocket != null and box_near >= 0
		&"hatch_near":
			return pocket != null and hatch_near >= 0
		&"stove_near":
			return pocket != null and stove_near >= 0
		&"kindled":
			return _kindled
		&"crawl_near":
			return pocket != null and crawl_near
		&"out_back":
			return _went_out_back
		# A fire is warming the player where they stand (Survival.fire_near).
		&"by_fire":
			return Survival.fire_near(game) != null
		# Somebody in here is asleep in a dock now.
		&"asleep":
			return _sleepers() > 0
		# They are, and none has woken since the tour last asked for a shot.
		&"unwoken":
			return _sleepers() > 0 and not _woke
		&"woke":
			return _woke
		&"meal_taken":
			return _meal_taken
		&"unnoticed":
			# In a room and nothing in it has the player: every resident still
			# idle at its post and no turret coming round.
			if pocket == null or _aiming:
				return false
			for pair: Array in _residents:
				var m: MobState = pair[1]
				if m.alive and (m.mood != MobState.IDLE or m.suspicion >= 1.0):
					return false
			return true
		&"warden_down":
			return pocket != null and not _swapping and not _warden_stands()
		&"door":
			return door_near != null
		&"inside":
			return pocket != null and not _swapping
		&"outside":
			return pocket == null and not _swapping and game.world.realm != Realm.INTERIOR
	if String(what).begins_with("inside:"):
		return pocket != null and not _swapping and String(pocket.kind.id) == String(what).substr(7)
	if String(what).begins_with("room:"):
		# `room:PLAN` or `room:HOUSEHOLD`: inside a room laid or kept that way.
		var want := String(what).substr(5)
		return pocket != null and not _swapping and (String(pocket.layout.plan) == want or String(pocket.layout.dressing) == want)
	return false


## The names `tour_place` answers (tests/tours/test_tour_claims reads this).
const TOUR_PLACES: Array[String] = ["door:house", "door", "door:hall", "door:side", "door:back",
	"door:fisher", "door:tinker", "door:keeper", "door:cottage", "door:weapons_hall", "door:bunker", "door:roundhouse", "door:stilt_room", "door:tower_lobby", "door:cliff_room", "door:hulk_hold", "door:rooted_floor", "door:tenement", "door:maintenance_bay", "door:foundry", "strongbox", "thing:turnstile", "thing:diag_panel", "thing:tally", "thing:line_panel", "thing:cast_rack", "behind:cast_rack", "door:data_hall", "thing:console", "thing:restore_bay", "door:laid_table", "thing:food_hatch", "hatch", "door:saw_hall", "thing:gang_saw", "thing:dock", "thing:beam_stack", "door:frozen_hold", "thing:stove", "thing:sounding_well", "thing:bunk_board", "stove", "door:home", "door:wireman", "door:trapper", "door:corer", "door:mason", "door:tapper", "door:collier", "thing:wire_coils", "thing:core_samples", "thing:resin_pots", "door:cutter", "door:reeder", "door:eeler", "door:raker", "door:boiler", "door:filer", "door:wright", "thing:peat_stack", "thing:salt_cones", "thing:filings_trays", "door:cook", "door:gatherer", "door:grower", "door:knapper", "door:stiller", "door:picker", "door:siphoner", "door:sorter", "door:wirer", "thing:steam_box", "thing:glass_blades", "thing:oil_drums", "thing:sorted_bins", "door:clerk", "door:shift", "door:squatter", "door:climber", "door:stilter", "door:bailer", "thing:ledgers", "thing:hammock", "thing:tide_gauge", "door:byrer", "door:stallholder", "door:spinner", "thing:stall", "thing:counter", "thing:loom", "door:squat", "crawl", "thing:crawl_hole", "thing:rug", "thing:laid_table"]


## `at door:house`: just outside the nearest door of that host, facing it -- or,
## inside, just inside the room's own door, facing out. `door:PLAN` and
## `door:HOUSEHOLD` (cottage.gd's deals) ask for the nearest door whose room is
## laid to that plan or kept by that household -- or, `door:KIND`, the nearest
## door into that kind at all -- so a tour stages a room by what is in it rather
## than by where some house happens to stand.
func tour_place(what: String) -> Vector2:
	var th := _tour_thing(what)
	if not th.is_empty():
		var f: Vector2 = th.face
		if what.begins_with("behind:"):
			return (th.at as Vector2) - f * 1.0
		# A step out from it and along its wall, facing the wall: from over the
		# shoulder a thing squarely in front of the player at arm's length is
		# covered by their own back (maintenance.tour frame 05), and a little to
		# one side it still is from the other shoulder. `STAND_ASIDE` along, it
		# clears the body from either (the eye's line crosses the player's plane
		# at about half the eye's offset from the thing).
		# Whichever way along the wall keeps the player on the room's floor with
		# a body's room round them, and nearer in where neither does.
		var out := (th.at as Vector2) + f * 1.0
		for aside: float in [STAND_ASIDE, -STAND_ASIDE, STAND_ASIDE * 0.6, -STAND_ASIDE * 0.6]:
			var p := out + Vector2(-f.y, f.x) * aside
			if _roomy(p):
				return p
		return out
	if what == "strongbox":
		var box := _first_box()
		return (box.at as Vector2) + (box.face as Vector2) * 0.8 if not box.is_empty() else Vector2.INF
	if what == "hatch" or what == "stove" or what == "crawl":
		var h := _first_with({"hatch": "serves", "stove": "fuel", "crawl": "exit"}[what])
		return (h.at as Vector2) + (h.face as Vector2) * 0.8 if not h.is_empty() else Vector2.INF
	var t := _tour_door(what)
	if pocket != null and t == null and TOUR_PLACES.has(what):
		return pocket.layout.door - pocket.layout.door_out * 0.5
	return t.door + t.out * 0.5 if t != null else Vector2.INF


func tour_face(what: String) -> float:
	var th := _tour_thing(what)
	if not th.is_empty():
		# In front, facing it; behind, facing along it, the way a body keeps to it.
		var f: Vector2 = th.face
		return (Vector2(-f.y, f.x)).angle() if what.begins_with("behind:") else (-f).angle()
	if what == "strongbox":
		var box := _first_box()
		return (-(box.face as Vector2)).angle() if not box.is_empty() else NAN
	if what == "hatch" or what == "stove" or what == "crawl":
		var h := _first_with({"hatch": "serves", "stove": "fuel", "crawl": "exit"}[what])
		return (-(h.face as Vector2)).angle() if not h.is_empty() else NAN
	var t := _tour_door(what)
	if pocket != null and t == null and TOUR_PLACES.has(what):
		return pocket.layout.door_out.angle()
	return (-t.out).angle() if t != null else NAN


## `near thing:KIND`: the first of the room's things of that kind, stood in
## front of and faced (a tenement's turnstile at the foot of its stair); `near
## behind:KIND`, a tile behind it, along it (a foundry's cooling racks). Empty
## outside a room, or in one without it.
const STAND_ASIDE := 1.3


## Whether a body can stand at `p` in the room: floor under it and a wall's
## thickness and a body's width of floor round it.
func _roomy(p: Vector2) -> bool:
	var l := pocket.layout
	for d: Vector2 in [Vector2.ZERO, Vector2(0.45, 0), Vector2(-0.45, 0), Vector2(0, 0.45), Vector2(0, -0.45)]:
		var q := p + d
		if not l.is_floor(floori(q.x), floori(q.y)):
			return false
	return true


func _tour_thing(what: String) -> Dictionary:
	if pocket == null or not (what.begins_with("thing:") or what.begins_with("behind:")):
		return {}
	var kind := what.get_slice(":", 1)
	for t: Dictionary in pocket.layout.things:
		if String(t.kind) == kind:
			return t
	return {}


## `walkto strongbox`: the way a quiet player goes to a strongbox, as waypoints.
## A sneak keeps out of sight: for each box, a few ways to its bay's doorway
## (along the hatch's wall, straight, through the room's middle), then in to the
## box's front -- and of all of them, the one that spends least of its length
## where a resident or a turret would see the player (StealthQuery, the moment
## as it is: crouched or not). Empty outside a room with one.
func tour_route(what: String) -> PackedVector2Array:
	if what == "guard" and pocket != null:
		return _route_to_guard()
	if what != "strongbox" or pocket == null:
		return PackedVector2Array()
	var l := pocket.layout
	var sim: FightSim = game.player.sim
	var along := Vector2(-l.door_out.y, l.door_out.x)
	var start := l.inside()
	var best := PackedVector2Array()
	var best_seen := INF
	for t: Dictionary in l.things:
		if t.kind != &"strongbox":
			continue
		var door := Vector2.INF
		for e: Dictionary in l.edges:
			if e.kind != &"inner":
				continue
			var m: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
			if door == Vector2.INF or m.distance_to(t.at) < door.distance_to(t.at):
				door = m
		if door == Vector2.INF:
			continue
		var into := ((t.at as Vector2) - door).normalized()
		var tail := PackedVector2Array([door - into * 0.9, door, (t.at as Vector2) + (t.face as Vector2) * 0.8])
		# The ways a sneak might go to the bay's doorway: along the wall the
		# hatch is in, straight across, through the middle of the room, or
		# straight in from the hatch and then along.
		var middle := _room_middle()
		var inward := -l.door_out
		for via: Array in [[start + along * along.dot(door - start)], [], [middle], [start + inward * inward.dot(door - start)]]:
			var route := PackedVector2Array()
			for v: Vector2 in via:
				route.append(v)
			route.append_array(tail)
			var seen := _seen_along(start, route, sim)
			if seen < best_seen:
				best_seen = seen
				best = route
	return best


## `walkto guard`: to a tile and a half short of the nearest guard still
## standing in the room, on the player's side of it -- a loud player going to
## fight what keeps the hall rather than the warden.
func _route_to_guard() -> PackedVector2Array:
	var out := PackedVector2Array()
	var best: MobState = null
	for pair: Array in _residents:
		var m: MobState = pair[1]
		if m.alive and Roles.of(m.kind) != Roles.KEEPER and (best == null or m.pos.distance_to(game.player.pos) < best.pos.distance_to(game.player.pos)):
			best = m
	if best != null:
		out.append(best.pos + (game.player.pos - best.pos).normalized() * 1.5)
	return out


## How many of the half-tile steps along `route` from `start` a standing
## resident or a turret would see the player on, or a sleeper hear a crouched
## step on.
func _seen_along(start: Vector2, route: PackedVector2Array, sim: FightSim) -> float:
	var seen := 0.0
	var from := start
	for p: Vector2 in route:
		var n := maxi(1, ceili(from.distance_to(p) / 0.5))
		for k in n:
			var q := from.lerp(p, float(k + 1) / float(n))
			for pair: Array in _residents:
				var m: MobState = pair[1]
				if m.alive and not m.asleep and StealthQuery.sees(m.row, m.pos, q, sim.moment, sim.world, sim.query, m.facing):
					seen += 1.0
				elif m.alive and m.asleep and Senses.chebyshev(m.pos, q) <= float(m.row.get("hears", 0)) * StealthNoise.loudness(Tuning.WALK_SPEED, sim.world.ground_at(floori(q.x), floori(q.y)), true, 0):
					seen += 1.0
			# And the turrets' eyes: a step in a turret's sweep costs a wait, not
			# a sighting, so it counts for less than a resident who never looks away.
			for tu: HallTurret in _turrets:
				if tu.at.distance_to(q) <= StealthQuery.sight_range(TURRET_EYE, sim.moment) and _turret_sees(tu.at, q):
					seen += 0.2
		from = p
	return seen


## `near strongbox`: the first strongbox in the room the player is in.
func _first_box() -> Dictionary:
	if pocket == null:
		return {}
	for t: Dictionary in pocket.layout.things:
		if t.kind == &"strongbox":
			return t
	return {}


## `near hatch`, `near stove`: the first thing in the room that serves a meal,
## or that burns, stood at in reach of it.
func _first_with(key: String) -> Dictionary:
	if pocket == null:
		return {}
	for t: Dictionary in pocket.layout.things:
		if t.has(key):
			return t
	return {}


## The door a tour name asks for from outside; null inside a room, or for a name
## this system does not answer.
func _tour_door(what: String) -> Threshold:
	if pocket != null or not TOUR_PLACES.has(what):
		return null
	var want := what.trim_prefix("door").trim_prefix(":")
	var any := want == "" or want == "house"
	var order := doors.duplicate()
	var from := game.player.pos
	order.sort_custom(func(a: Threshold, b: Threshold) -> bool:
		return a.door.distance_squared_to(from) < b.door.distance_squared_to(from))
	for t: Threshold in order:
		if any or String(t.kind) == want:
			return t
		if Interiors.RECIPES.has(StringName(want)):
			continue
		var l := InteriorGen.grow(game.options.seed_value, t).layout
		if String(l.plan) == want or String(l.dressing) == want:
			return t
	return null


## A crossing into another realm is another island with its own doors; a door's
## own crossing is this system's, and the doors outside stay as they were.
func realm_changed(from: StringName, to: StringName) -> void:
	if Realm.is_pocket(from) or Realm.is_pocket(to):
		return
	_drop_grown()
	doors = Interiors.thresholds(game.world)
	_stand_hatches()


## A SAVE MADE INSIDE (20_realms `started`): the game opened on the world outside,
## the player where they stood inside. The door is found again by its key, the
## pocket grown again from it, and gone into with no cover: this is the first
## frame, nothing to hide.
func reenter(key: StringName, at: Vector2) -> void:
	var door_key := String(key).trim_prefix(Realm.POCKET)
	var t := Interiors.by_key(game.world, door_key)
	if t == null:
		push_warning("doors: no door %s on this island; staying outside" % door_key)
		return
	_begin(t)
	if _grown == null:
		return
	_swap_in()
	var realms := _realms()
	# Where the save was made, not the doorway.
	game.player.pos = at
	if game.player.hero != null:
		game.player.hero.pos = at
	game.player.sync_view(0.0)
	if game.camera != null:
		game.camera.snap_to(game.player.position)
	realms.set("_settle", 0.0)
