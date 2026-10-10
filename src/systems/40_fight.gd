extends GameSystem
## The player's two verbs and what comes of them. Reads swing and dodge,
## steps the one simulation (created by 30_mobs) in fixed slices, and turns
## what happened in it into the world: Events, sounds, the hitstop, the
## camera's shake, the ink marks (MobFx), the clock's jumps and the lines on screen.
##
## Controls: swing on `swing` (J, a click), thrown as the key comes up; held
## FightRules.HEAVY_HOLD_MS it is the heavy blow instead, thrown as the hold
## is reached. Dodge on `dodge` (K or the thumb button at once; Shift as
## DodgeInput says, holding it still runs). Pressed while held, swing pulls, at once. The keys are ControlScheme's; a lock (Hero.lock)
## decides where a swing and a dodge go, inside the simulation.

const HITSTOP_HIT := 0.05
const HITSTOP_HURT := 0.06
const HITSTOP_KILL := 0.08
## Seconds a body lies before it gets up after being downed or carried off.
const WAKE_SECONDS := 1.6
## Seconds between the struggle's marks while held.
const STRUGGLE_BEAT := 0.4
## Said the first time in a game a worker warns someone holding it up.
const CROWD_LINE := "It will not go round you. Step out of its path."

var sim: FightSim
var dodge_input := DodgeInput.new()
var _shift_down := false
## The hitstop's end, on the fight's frame clock (`_clock`: the physics steps'
## own seconds, summed). On a wall clock a slow box held the fight for fewer
## steps than a fast one, and the same fight played differently on each.
var _stop_until := 0.0
var _clock := 0.0
var _struggle_t := 0.0
var _mend_from := 0.0
var _last_health := 0
## Simulation ms at which a dodge in progress lands (its dust is drawn then), or -1.
var _land_at := -1.0
## A shot's held moment: the simulation never steps again.
var _held := false
## Where a held moment keeps the camera (the game points it at the player every frame).
var _focus := Vector3.ZERO
var _crowd_told := false
## Seconds the swing key has been down, while it is down and nothing is thrown
## yet (-1 otherwise). Counted in the frames' own time, so a hold is the same
## length to the fight whatever the frame rate, a fixed-rate tour's included.
var _swing_held := -1.0
## Simulation ms a heavy blow's drawn-back pose is let go into the strike, or -1.
var _heavy_let_go := -1.0
var _heavy_blow: Blow = null


func setup(g: Game) -> void:
	super.setup(g)
	sim = g.player.sim
	if sim == null:
		return
	Events.sentinel_fell.connect(_on_keeper_fell)
	_mend_from = g.clock.minutes
	_last_health = g.body.health
	_keep_texel()
	g.player.model.set_held(g.inventory.held)
	if g.options.act != "":
		_play_act(g.options.act)


## The marks' warm-up (MobFx.warm), drawn for the boot's warm-up frames
## (01_warm_lights) and gone on the same frame as its rack.
var _warm_marks: Array[Node3D] = []


func warm(on: bool) -> void:
	for n: Node3D in _warm_marks:
		if is_instance_valid(n):
			n.queue_free()
	_warm_marks.clear()
	if on and sim != null:
		_warm_marks = MobFx.warm(game, game.player.position)


## Which keys were down at the last read. A press is this system's own edge as
## well as `is_action_just_pressed`, which answers only in the frame the key
## went down: a press made later in a frame than this runs (a tour's) was never
## seen by it (20_realms met it on the climb back up a shaft).
var _was_down: Dictionary = {}


func _went_down(action: StringName) -> bool:
	var now := Keys.down(action)
	var was: bool = _was_down.get(action, false)
	_was_down[action] = now
	return (now and not was) or Input.is_action_just_pressed(action)


## Read by polling the actions, not from input events, so the real bindings,
## a tour's pressed actions and a bot all reach the same verbs. Shift's own
## edges are watched for DodgeInput; the dodge action pressed without Shift
## down (K, or an action pressed by a tour) dodges at once.
func _read_input(delta: float) -> void:
	var swing_went := _went_down(&"swing")
	var dodge_went := _went_down(&"dodge")
	var shift := Input.is_physical_key_pressed(KEY_SHIFT)
	# Shift's tap and hold are timed on the fight's frame clock, as the hitstop
	# is: a tap is the same number of steps at any frame rate.
	var t := _clock * 1000.0
	var blocked := game.input_blocked() or _held
	if shift != _shift_down:
		_shift_down = shift
		if not blocked:
			if shift:
				if dodge_input.shift_pressed(t, _in_fight()):
					sim.press_dodge()
			elif dodge_input.shift_released(t):
				sim.press_dodge()
	if blocked:
		_swing_held = -1.0
		return
	# A tap is a swing and a hold is the heavy blow, so the swing is thrown when
	# the key comes up, or when the hold is long enough, whichever is first. Over
	# the shoulder it goes where the camera looks (NAN elsewhere, which keeps the
	# swing's own rule). Held by something, the key wrenches at once.
	if swing_went:
		if sim.hero.held():
			sim.press_swing()
		else:
			_swing_held = 0.0
	elif _swing_held >= 0.0:
		_swing_held += delta
	if _swing_held >= 0.0:
		if not Keys.down(&"swing"):
			_swing_held = -1.0
			sim.press_swing(game.camera.aim())
		elif _swing_held * 1000.0 >= FightRules.HEAVY_HOLD_MS:
			_swing_held = -1.0
			sim.press_heavy(game.camera.aim())
	if dodge_went and not shift:
		sim.press_dodge()
	# The unbuilder's hands (FightKit.unbuild): use held at an open machine's part
	# strips it, gathered through its openings.
	if Keys.down(&"use"):
		var m := _strippable()
		if m != null:
			sim.strip(m, delta * 1000.0)


## The open machine a held `use` strips now (FightKit.unbuild), or null: the one
## answer the strip acts on and `use_line` names.
func _strippable() -> MobState:
	if sim == null or not sim.hero.kit.unbuild or Survival.ask_pending(game) or Survival.words_in_front(game):
		return null
	for m in sim.mobs:
		if sim.can_strip(m):
			return m
	return null


## The hint for the press the unbuilder's hands would take (UiLink.use_hint).
func use_line() -> String:
	return "machine - strip" if game != null and _strippable() != null else ""


func _in_fight() -> bool:
	if sim.fight_on:
		return true
	for m in sim.mobs:
		if m.alive and m.roused() and Senses.chebyshev(m.pos, sim.hero.pos) <= FightRules.AWAY_DISTANCE:
			return true
	return false


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	_read_input(delta)
	var now_s := Time.get_ticks_msec() / 1000.0
	_clock += delta
	var hero := sim.hero
	var player := game.player
	hero.move = player.intent_move
	hero.run = player.intent_run
	hero.walk_speed = Hero.ground_speed(game.world, hero.pos, false, game.body.move_factor, hero.ride)
	hero.run_speed = Hero.ground_speed(game.world, hero.pos, true, game.body.move_factor, hero.ride)
	sim.hold = _held or _clock < _stop_until
	if not sim.hold:
		sim.real_s = now_s
		sim.step(delta)
	player.take_place()
	_handle(sim.drain())
	_landing()
	_mend()


func _process(delta: float) -> void:
	if sim == null:
		return
	_keep_texel()
	if _held:
		game.camera.snap_to(_focus)
	var frozen := sim.hold
	game.player.sync_view(0.0 if frozen else delta, frozen)
	if not _curtains.is_empty():
		_age_curtains()
	game.player.draw_swing(sim.now)
	if game.options.hit_areas:
		_draw_hit_areas()
	if _heavy_let_go >= 0.0 and sim.now >= _heavy_let_go:
		_let_go()
	if sim.hero.held() and not frozen:
		# The struggle, drawn: a dashed ring at the feet on a beat while something has hold.
		_struggle_t -= delta
		if _struggle_t <= 0.0:
			_struggle_t = STRUGGLE_BEAT
			MobFx.ring(_fx_parent(), _at3(sim.hero.pos), MobFx.RING_INK, 0.55, 0.28)
	else:
		_struggle_t = 0.0
	# In the sea the hands are for swimming: what he holds is stowed until he is
	# out (still held: the inventory is not touched).
	var shown := &"" if game.player.swimming else game.inventory.held
	if game.player.model.held != shown:
		game.player.model.set_held(shown)


## Marks are sized in pixels of the frame the camera players actually have, and
## it is the rig's LIVE `size` that says so, never its `view_height`. A target
## lock leans the camera in and out (42_target's LOCK_ZOOM 0.86 and SWEEP_ZOOM
## 1.14), and `size` is what the rig itself divides by rows for its own texel --
## so for the whole time `z` is held, which is exactly when a player is reading a
## machine and deciding whether to fight it, every mark's floor was being worked
## out against a camera nobody was looking through, by up to a seventh either way.
func _keep_texel() -> void:
	if not game.camera.is_inside_tree():
		MobFx.texel = game.camera.view_height / float(UiBase.SIZE.y)
		return
	MobFx.texel = game.camera.units_per_pixel()


## The camera's up on screen, as a world direction (a tell stands above a body along it).
## Which way on the screen `at` lies from the player, y down: projected when it
## is in front of the camera, and read off the camera's own axes when it is
## behind it (over the shoulder, a body at the player's back is behind the lens).
func _screen_dir(at: Vector3) -> Vector2:
	var cam: Camera3D = game.camera
	var from := _at3(sim.hero.pos)
	if not cam.is_position_behind(at) and not cam.is_position_behind(from):
		return cam.unproject_position(at) - cam.unproject_position(from)
	var b := cam.global_transform.basis
	var off := at - from
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	return Vector2(off.dot(right), -off.dot(fwd))


func _screen_up() -> Vector3:
	return game.camera.global_transform.basis.y if game.camera.is_inside_tree() else Vector3.UP


## A dodge's dust is thrown where it lands, after the body has gone from where it
## started: drawn at the start it merged with the speed lines into one glyph.
func _landing() -> void:
	if _land_at < 0.0 or sim.now < _land_at:
		return
	_land_at = -1.0
	var hero := sim.hero
	MobFx.puff(_fx_parent(), _at3(hero.pos + hero.dodge_dir * 0.15), hero.dodge_dir, _dust_colour(hero.pos), 0.5, int(sim.now) + 2)


## The heavy blow's tell, the player's own: the tool held drawn back for the
## extra windup (PersonAnim.heavy_wind: turned away, the arm up and back), a fan
## of strokes thrown up off the body for as long, and the drive's sound. Then it
## is let go into the ordinary strike from the swing's own cock (`_let_go`). No
## ground ring: a ring on the ground is where a machine's bite will land, and
## only that.
func _heavy_windup(b: Blow) -> void:
	var player := game.player
	player.model.play_action(&"heavy", FightRules.HEAVY_WINDUP_MS / 1000.0)
	_heavy_let_go = sim.now + FightRules.HEAVY_WINDUP_MS
	_heavy_blow = b
	Events.sfx.emit(&"windup", player.position)
	MobFx.tell(player, player.model_centre(), _screen_up(), FightRules.HEAVY_WINDUP_MS / 1000.0, int(sim.now), 0.7, MobFx.FLICK_UP)


## The held heavy blow goes: the swing plays on from its cock, unless a hurt took
## the blow away in the meantime, in which case the hurt's own pose stands.
func _let_go() -> void:
	_heavy_let_go = -1.0
	var b := _heavy_blow
	_heavy_blow = null
	if b == null or sim.hero.blow != b:
		return
	Events.sfx.emit(&"swing", game.player.position)
	var light_windup := (b.windup - FightRules.HEAVY_WINDUP_MS) / 1000.0
	var light_len := (b.committed() - FightRules.HEAVY_WINDUP_MS) / 1000.0
	game.player.model.pose_at(&"swing", light_windup, light_len)
	game.player.model.unfreeze()


## One point of health back per hour of the world's clock, counted from the last
## hurt; four an hour by a fire.
func _mend() -> void:
	var b := game.body
	if b.health < _last_health:
		_mend_from = game.clock.minutes
	_last_health = b.health
	if b.health >= b.max_health:
		_mend_from = game.clock.minutes
		return
	var per := FightRules.mend_minutes(Survival.fire_near(game) != null)
	while game.clock.minutes - _mend_from >= per and b.health < b.max_health:
		_mend_from += per
		b.health += 1
	_last_health = b.health


func _stop(seconds: float) -> void:
	_stop_until = maxf(_stop_until, _clock + seconds)


## A KEEPER GOING THROUGH A WOOD (FightSim._break_through). The standing tree
## is taken out of its chunk; in its place its own model leans, then comes over
## away from the machine that pushed it, as a thing that heavy falls, and lies
## there for the session (the taken tree is what is saved: the scar). The crown
## shudders its leaves or its snow off as it goes, and it cracks. A shrub is
## flattened: a burst of its leaves and the same crack, and it is gone.
const FALLEN_KEPT := 40
const FALL_LEAN_S := 0.25
const FALL_S := 0.75
var _fallen: Array[Node3D] = []
var _felled_at := -INF


func _fell(e: Dictionary) -> void:
	_felled_at = Time.get_ticks_msec() / 1000.0
	var w := game.world
	var p := w.prop(int(e.id))
	if p == null:
		return
	if game.view != null:
		game.view.refresh_props(p)
	var fx := _fx_parent()
	var base := w.to_3d(p.pos)
	var dir: Vector2 = e.dir
	var tree := int(e.kind) in [PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE]
	var leaf := Palette.RIME[5] if int(e.kind) == PropKind.SNOW_PINE else (Palette.MOSS[3] if int(e.kind) == PropKind.BROADLEAF else Palette.SPRUCE[3])
	Events.sfx.emit(&"break", base)
	var h := 2.4 * p.scale if tree else 0.5
	MobFx.puffs(fx, base + Vector3(0, h * 0.8, 0), dir, leaf, 6 if tree else 4, 1.1 if tree else 0.7, int(e.id))
	if not tree:
		return
	var country := w.country_at(floori(p.pos.x), floori(p.pos.y))
	var node := PropModels.node(p.kind, PropModels.variant_of(p, w.seed_value, country), country)
	if game.view != null:
		node.material_override = game.view.world_material()
	var pivot := Node3D.new()
	fx.add_child(pivot)
	pivot.global_position = base
	pivot.add_child(node)
	node.rotation.y = p.rot
	node.scale = Vector3.ONE * p.scale
	# Over away from the machine: about the axis across the way it was pushed.
	var across := Vector3(dir.y, 0.0, -dir.x).normalized()
	var tw := pivot.create_tween()
	tw.tween_method(func(a: float) -> void: pivot.basis = Basis(across, a), 0.0, -0.12, FALL_LEAN_S).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float) -> void: pivot.basis = Basis(across, a), -0.12, -1.5, FALL_S).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		MobFx.puffs(fx, base + Vector3(-dir.x, 0.2, -dir.y) * -h * 0.7, dir, leaf, 5, 1.0, int(e.id) + 1)
		Events.sfx.emit(&"fall_boom", base))
	_fallen.append(pivot)
	while _fallen.size() > FALLEN_KEPT:
		var old: Node3D = _fallen.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## THE WARDEN'S CURTAINS (FightSim.curtains), drawn. The tell: a jet of lime
## from its crown to the gap and a ring on the ground there, for as long as it
## takes, so the player reads which way is about to close and can still get back
## through. Up: the flowstone curtain standing across the way, and it ages where
## the player can read it: FRESH (wet and bright, a cold glisten on it) for the
## first CURTAIN_FRESH of its time, DRYING to CURTAIN_DRY, then DRY, greyed and
## cracked. The crumble: it shakes and sheds, a moment before it goes. A crack:
## lime knocked off it. Down: broken, a burst of it; its time up, it slumps away.
const FlowstoneCurtain := preload("res://src/models/machines/sentinels/flowstone_curtain.gd")
const CURTAIN_FRESH := 0.3
const CURTAIN_DRY := 0.7
## Each standing curtain: {node, from, to, seed, up (sim ms), ms, stage, crumbling, rest}.
var _curtains := {}


## Its stage at this share of its time.
static func curtain_stage(share: float) -> int:
	if share < CURTAIN_FRESH:
		return FlowstoneCurtain.FRESH
	if share < CURTAIN_DRY:
		return FlowstoneCurtain.DRYING
	return FlowstoneCurtain.DRY


## Every standing curtain drawn at the stage its age says, shaking as it crumbles.
func _age_curtains() -> void:
	for id: int in _curtains:
		var c: Dictionary = _curtains[id]
		var node: MeshInstance3D = c.node
		if not is_instance_valid(node):
			continue
		var stage := curtain_stage((sim.now - float(c.up)) / maxf(1.0, float(c.ms)))
		if stage != int(c.stage):
			c.stage = stage
			node.mesh = FlowstoneCurtain.mesh(c.from, c.to, int(c.seed), stage)
		var rest: Vector3 = c.rest
		if bool(c.crumbling):
			var t := sim.now * 0.05
			node.position = rest + Vector3(sin(t * 7.3), 0.0, cos(t * 5.9)) * 0.035
		else:
			node.position = rest


var _curtain_seen := {}


func _curtain(e: Dictionary) -> void:
	_curtain_seen[e.type] = sim.now
	var fx := _fx_parent()
	var lime := Palette.LINEN[5]
	var at: Vector2 = e.at
	match e.type:
		&"curtain_tell":
			var m: MobState = e.mob
			var secs := float(e.ms) / 1000.0
			var crown := _at3(m.pos, float(m.row.get("height", 4.0)) * 0.95)
			MobFx.line(fx, crown, _at3(at, 1.6), lime, secs)
			# The round the curtain will hold the player out of (FightSim._held_by_curtains).
			var hold := float(e.r) + sim.hero.radius
			MobFx.tell_box(fx, _at3(at), 0.0, hold, hold, hold, lime, secs)
			Events.sfx.emit(&"splash", _at3(at))
		&"curtain_up":
			var node := MeshInstance3D.new()
			var seed_value := int(e.id) * 97 + game.world.seed_value
			node.mesh = FlowstoneCurtain.mesh(_at3(e.from), _at3(e.to), seed_value, FlowstoneCurtain.FRESH)
			node.material_override = game.view.world_material()
			# Round the middle of the way's own edges, where the mesh is built about.
			var rest := (_at3(e.from) + _at3(e.to)) * 0.5
			node.position = rest
			fx.add_child(node)
			var ms := float(e.get("ms", 25000.0))
			_curtains[int(e.id)] = {"node": node, "from": _at3(e.from), "to": _at3(e.to), "seed": seed_value, "up": sim.now,
				"ms": ms, "stage": FlowstoneCurtain.FRESH, "crumbling": false, "rest": rest}
			MobFx.puffs(fx, _at3(at, 1.0), Vector2.ZERO, lime, 5, 0.8, int(e.id))
			# Wet: a cold glisten on the fresh lime for as long as it is fresh, so a
			# new curtain stands out of the old wall round it.
			MobFx.glow(fx, _at3(at, 1.6) + (_at3(e.to) - _at3(e.from)).cross(Vector3.UP).normalized() * 0.9,
				Palette.RIME[5], 2.6, ms / 1000.0 * CURTAIN_FRESH)
		&"curtain_crumbling":
			var c: Dictionary = _curtains.get(int(e.id), {})
			if not c.is_empty():
				c.crumbling = true
			MobFx.puffs(fx, _at3(at, 1.8), Vector2.ZERO, Palette.LINEN[4], 6, 0.7, int(e.id) + 11)
			MobFx.puffs(fx, _at3(at, 0.4), Vector2.ZERO, Palette.LINEN[4], 4, 0.9, int(e.id) + 13)
			Events.sfx.emit(&"break", _at3(at))
		&"curtain_cracked":
			MobFx.puffs(fx, _at3(at, 1.1), Vector2.ZERO, lime, 4, 0.6, int(e.id) + int(e.hits) * 7)
			Events.sfx.emit(&"break", _at3(at))
		&"curtain_down":
			var c: Dictionary = _curtains.get(int(e.id), {})
			_curtains.erase(int(e.id))
			if not c.is_empty() and is_instance_valid(c.node):
				(c.node as Node).queue_free()
			var broken := bool(e.get("broken", false))
			MobFx.puffs(fx, _at3(at, 0.9), Vector2.ZERO, lime, 8 if broken else 3, 1.0 if broken else 0.6, int(e.id) + 3)
			if broken:
				Events.sfx.emit(&"break", _at3(at))


## --hit-areas: the player's blow box while it is live, and each body's hit
## circle, outlined over everything (no depth test) in the plane the stroke is
## drawn in (Player.draw_swing: half a unit over his feet), so a frame shows the
## hit on top of the stroke drawn for it.
var _hit_lines: MeshInstance3D = null


func _draw_hit_areas() -> void:
	if _hit_lines == null:
		_hit_lines = MeshInstance3D.new()
		_hit_lines.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.no_depth_test = true
		mat.render_priority = 100
		_hit_lines.material_override = mat
		_hit_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.add_child(_hit_lines)
	var im := _hit_lines.mesh as ImmediateMesh
	im.clear_surfaces()
	var loops: Array[Array] = []
	var b := sim.hero.blow
	if b != null and b.live_in(sim.hero.blow_at, sim.now - 1.0, sim.now):
		loops.append([FightRules.blow_outline(sim.hero.pos, sim.hero.facing, sim.hero.radius, b), Color(1, 0, 1)])
	for m in sim.mobs:
		if m.alive and not m.removed and m.pos.distance_to(sim.hero.pos) < 12.0:
			var ring := PackedVector2Array()
			for i in 32:
				ring.append(m.pos + Vector2.from_angle(i * TAU / 32.0) * m.radius)
			loops.append([ring, Color(0, 1, 1)])
	if loops.is_empty():
		return
	var plane := game.player.global_position.y + 0.5
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for loop: Array in loops:
		var pts: PackedVector2Array = loop[0]
		im.surface_set_color(loop[1])
		for i in pts.size():
			for q: Vector2 in [pts[i], pts[(i + 1) % pts.size()]]:
				var w := _at3(q)
				im.surface_add_vertex(Vector3(w.x, plane, w.z))
	im.surface_end()


func _at3(p: Vector2, lift: float = 0.0) -> Vector3:
	return game.world.to_3d(p) + Vector3(0, lift, 0)


func _node_of(f: Fighter) -> Object:
	if f == null:
		return null
	if f == sim.hero:
		return game.player
	return f.node


## Dust is the ground's own wash thrown up, a step paler.
func _dust_colour(p: Vector2) -> Color:
	var g := game.world.ground_at(floori(p.x), floori(p.y))
	match g:
		Ground.WATER, Ground.RIVER, Ground.BLACKWATER, Ground.DEEP_WATER:
			return Palette.BRINE[5]
		Ground.SNOW, Ground.ICE:
			return Palette.RIME[5]
		Ground.SAND, Ground.SHINGLE:
			return Palette.SAND[5]
		Ground.ASH, Ground.CLINKER:
			return Palette.ASH[4]
		Ground.LIMESTONE, Ground.BONE:
			return Palette.LINEN[5]
		Ground.MUD, Ground.PEAT, Ground.NEEDLES, Ground.ROAD:
			return Palette.EARTH[5]
		Ground.GRASS, Ground.MOSS, Ground.HEATH:
			return Palette.SAND[5]
	return Palette.STONE[5]


func _fx_parent() -> Node:
	return game


## One segment of a plough's furrow (FightSim furrows), as ground and not a mark:
## a floor of packed blue-white ice between two low ridges of the snow it threw
## aside, on the world's own lit material with no ink. Each segment is a little
## longer than the tile it stands for, so a lane of them reads as one continuous
## sunk track. It goes when the furrow fills in.
func _furrow_segment(at: Vector2, angle: float) -> void:
	var k := MeshKit.new()
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	k.push(Transform3D(Basis(Vector3.UP, -angle), Vector3.ZERO))
	var half := FURROW_LEN * 0.5
	var w := FURROW_WIDTH * 0.5
	# The ice floor, a hair over the snow; banked ridges make it read as sunk.
	k.quad(Vector3(-half, 0.015, -w), Vector3(-half, 0.015, w), Vector3(half, 0.015, w), Vector3(half, 0.015, -w), Palette.RIME[4])
	for sd: float in [-1.0, 1.0]:
		var z := sd * (w + FURROW_RIDGE * 0.5)
		k.prism(-half * 0.5, 0.0, z, FURROW_RIDGE * 0.5, FURROW_RIDGE_H, FURROW_RIDGE * 0.3, 5, Palette.RIME[5])
		k.prism(half * 0.5, 0.0, z, FURROW_RIDGE * 0.5, FURROW_RIDGE_H * 0.8, FURROW_RIDGE * 0.3, 5, Palette.RIME[5])
	k.pop()
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	if _furrow_mat == null:
		_furrow_mat = ShaderMaterial.new()
		_furrow_mat.shader = preload("res://src/render/world.gdshader")
	mi.material_override = _furrow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx_parent().add_child(mi)
	mi.global_position = _at3(at + Vector2(0.5, 0.5) - (at - at.floor()))
	var tw := mi.create_tween()
	tw.tween_interval(FightSim.FURROW_SECONDS)
	tw.tween_callback(mi.queue_free)


## A furrow segment: its length along the lane, the lane's width, and the ridges'
## width and height either side.
const FURROW_LEN := 1.3
const FURROW_WIDTH := 1.5
const FURROW_RIDGE := 0.35
const FURROW_RIDGE_H := 0.14
var _furrow_mat: ShaderMaterial = null


## The working part's place in the world, or the body's middle.
func _part_at(m: MobState) -> Vector3:
	if m.node is Mob:
		return (m.node as Mob).part_position()
	return _at3(m.pos, float(m.row.get("height", 1.0)) * 0.5)


## When an edge last rang off a keeper's plating, fight ms (tour `plating`).
var _plating_at := -INF
## Until when a gripper torn loose stands jammed, fight ms (tour `torn`).
var _torn_until := -INF


## A keeper down: the plating it wore is no longer a reason to want an edge.
func _on_keeper_fell(_region: int, land: StringName, _how: StringName) -> void:
	var st := SurvivalState.of(game)
	for plate: Variant in st.plates.keys():
		if StringName(st.plates[plate]) == land:
			st.plates.erase(plate)


func _handle(events: Array[Dictionary]) -> void:
	var player := game.player
	var hero := sim.hero
	var fx := _fx_parent()
	for e in events:
		match e.type:
			&"swing":
				var b := hero.blow
				if b != null and b.heavy:
					_heavy_windup(b)
				else:
					Events.sfx.emit(&"swing", player.position)
					if b != null:
						player.model.play_action(&"swing", b.committed() / 1000.0)
			&"drop_strike":
				# Came down on it: the swing is thrown from the landing, and the ground
				# under the feet takes the weight in one ring of its own dust.
				var b := hero.blow
				Events.sfx.emit(&"swing", player.position)
				if b != null:
					player.model.play_action(&"swing", b.committed() / 1000.0)
				MobFx.ring(fx, _at3(hero.pos), _dust_colour(hero.pos), 0.9, 0.3)
				game.camera.shake(0.05, 0.1)
			&"dulled":
				Events.message.emit(FightRules.DULL_LINE)
			&"opened":
				# Its bite went past: the drive lets go audibly and the part catches the
				# light, so the window to strike is heard and seen, not only timed.
				var m: MobState = e.mob
				Events.sfx.emit(&"loose", _at3(m.pos))
				MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id + int(sim.now), 0.55)
			&"crowded":
				# A worker stopped by someone standing in its way: it says so before it acts.
				var m: MobState = e.mob
				Events.sfx.emit(&"alert", _at3(m.pos))
				if not _crowd_told:
					# The first time in a game, said as it stops, with the time to act on it.
					_crowd_told = true
					Events.message.emit(CROWD_LINE)
			&"crowd_warning":
				# Half way to taking it as interference: its part flares and a ring goes out from it.
				var m: MobState = e.mob
				Events.sfx.emit(&"alert", _at3(m.pos))
				MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id + int(sim.now), 0.7)
				MobFx.ring(fx, _at3(m.pos), MobFx.RING_INK, m.radius + 0.9, 0.4)
				if m.node is Mob:
					(m.node as Mob).flash(0.08)
			&"disturbed":
				var m: MobState = e.mob
				Events.sfx.emit(&"second_act", _at3(m.pos))
				MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id, 0.7)
			&"whiff":
				Events.sfx.emit(&"whiff", player.position)
			&"dodge":
				Events.sfx.emit(&"dodge", player.position)
				player.model.play_action(&"dodge", FightRules.DODGE_MS / 1000.0)
				# The lines trail from one body width behind where it set off: the
				# body shoots away from them, and nothing else is drawn there.
				MobFx.streak(fx, _at3(hero.pos - hero.dodge_dir * hero.radius * 2.0, 0.5), hero.dodge_dir, game.camera.yaw_now(), game.camera.pitch_deg, int(sim.now))
				_land_at = sim.now + FightRules.DODGE_MS
			&"evaded":
				# Heard, not drawn (a mark here lands on the speed lines): its blow met air.
				var by: MobState = e.by
				Events.sfx.emit(&"whiff", _at3(by.pos) if by != null else player.position)
			&"grip":
				var by: MobState = e.by
				Events.sfx.emit(&"grip", player.position)
				player.model.play_action(&"hurt", 0.25)
				player.shudder(0.2)
				game.camera.shake(0.08, 0.14)
				_stop(0.04)
				MobFx.ring(fx, _at3(hero.pos), MobFx.RING_INK, 0.8, 0.3)
				if by != null:
					# The jaw closing is drawn like a blow, though it does no harm.
					var jaw := by.pos + Vector2.from_angle(by.facing) * by.radius
					MobFx.burst(fx, _at3(jaw.lerp(hero.pos, 0.4), 0.35), 0.8, by.id + int(sim.now))
					MobFx.puffs(fx, _at3(by.pos.lerp(hero.pos, 0.6)), hero.pos - by.pos, _dust_colour(hero.pos), 3, 0.6, by.id)
					if by.node is Mob:
						(by.node as Mob).flash(0.05)
			&"pull":
				Events.sfx.emit(&"pull", player.position)
				player.shudder(0.14)
				game.camera.shake(0.04, 0.08)
				var by: MobState = e.by
				var dir := (hero.pos - by.pos) if by != null else Vector2.ZERO
				MobFx.puff(fx, _at3(hero.pos), dir, _dust_colour(hero.pos), 0.5, int(sim.now))
			&"loose":
				Events.sfx.emit(&"loose", player.position)
				MobFx.puffs(fx, _at3(hero.pos), Vector2.ZERO, _dust_colour(hero.pos), 3, 0.55, int(sim.now) + 7)
			&"torn":
				# Torn loose (Blow.torn): the wrench jams what held on. It clangs at the
				# jaw, and its open part glows for as long as it stands, so where to go
				# is read in the body and not in a line.
				var m: MobState = e.by
				_torn_until = sim.now + float(e.ms)
				MobFx.clang(fx, _at3(m.pos.lerp(hero.pos, 0.5), 0.9), int(sim.now))
				MobFx.glow(fx, _part_at(m), Palette.LENS[3], 1.1, float(e.ms) / 1000.0)
				Events.sfx.emit(&"hit_plate", _at3(m.pos))
			&"hit":
				_on_hit(e)
			&"struck":
				_on_struck(e)
			&"rake":
				_rake_marks(e)
			&"locked":
				# The lock (FightKit.lock): a standing sheet of drowned light across
				# the way passed, edge to edge of the opening and as tall as a body,
				# for as long as it is shut to them: ruled lines stacked up it, the
				# lowest the brightest, and a faint light in the opening itself.
				_locked_at = Time.get_ticks_msec() / 1000.0
				var a: Vector2 = e.from
				var b: Vector2 = e.to
				for k in 6:
					var y := 0.15 + k * 0.3
					MobFx.line(fx, _at3(a, y), _at3(b, y), Palette.BRINE[5 - mini(k, 3)], FightKit.LOCK_SECONDS)
				MobFx.glow(fx, _at3((a + b) * 0.5, 0.9), Palette.BRINE[4], maxf(1.2, a.distance_to(b)), FightKit.LOCK_SECONDS)
				Events.sfx.emit(&"hit_plate", _at3(e.at))
			&"curtain_tell", &"curtain_up", &"curtain_cracked", &"curtain_crumbling", &"curtain_down":
				_curtain(e)
			&"stripped":
				# Its working part comes away in the hands, and into the creel.
				var m: MobState = e.mob
				var item: StringName = e.item
				_stripped_at = Time.get_ticks_msec() / 1000.0
				game.inventory.add(item)
				Events.took.emit(item, 1)
				Events.sfx.emit(&"hit_plate", _at3(m.pos))
				MobFx.burst(fx, _part_at(m), 0.9, m.id, Palette.LENS[3])
				Events.message.emit("Stripped: %s." % UiRules.item_name(item))
			&"grip_failed":
				# The anchor held (FightKit.anchor): the grip rang off a body that
				# would not be taken, and the ground round the feet says why.
				_grip_failed_at = Time.get_ticks_msec() / 1000.0
				MobFx.clang(fx, _at3(hero.pos, 0.9), int(sim.now))
				MobFx.ring(fx, _at3(hero.pos), Palette.STONE[4], hero.radius + 0.5, 0.4)
				Events.sfx.emit(&"hit_plate", player.position)
			&"furrowed":
				# The plough's furrow (FightSim furrows): packed ice down the lane it
				# cut, pale on the drift for as long as the furrow holds.
				_furrow_segment(e.at, e.angle)
			&"felled":
				_fell(e)
			&"bogged":
				# A run off its lane into the drift: the share buries itself and
				# throws snow up either side.
				_bogged_at = Time.get_ticks_msec() / 1000.0
				var bm: MobState = e.mob
				MobFx.puffs(fx, _at3(bm.pos + Vector2.from_angle(bm.facing) * bm.radius), Vector2.from_angle(bm.facing), Palette.RIME[5], 4, 0.9, bm.id)
			&"cabled":
				# The cable brace's line took a working part (FightKit.cable): the
				# part glints where the hook bit, as the stall goes in.
				_cabled_at = Time.get_ticks_msec() / 1000.0
				var cm: MobState = e.mob
				MobFx.glint(fx, _part_at(cm), Palette.LENS[3], cm.id, 0.8)
				MobFx.clang(fx, _part_at(cm), int(sim.now))
			&"plated":
				# The bench plate took its share of a hunter's or a raider's blow
				# (FightRules.PLATE_TURNS): a glint off his back where it struck.
				_plated_at = Time.get_ticks_msec() / 1000.0
				var pb: MobState = e.attacker
				var face := (pb.pos - hero.pos).normalized() * hero.radius if pb != null else Vector2.ZERO
				MobFx.glint(fx, _at3(hero.pos + face, 1.1), Palette.PLATE[5], int(sim.now), 0.6)
				Events.sfx.emit(&"hit_plate", player.position)
			&"plate_spent":
				# Spent by the blows it turned: it turns nothing now, and what mends
				# it is said once, where he is (Items `worn_by`, Crafting `mend_kit`).
				_seen_spent = true
				Events.message.emit(StoryContent.MENDED["spent"])
			&"turned":
				# The scale coat turned a blow at the back (FightKit.scale): the
				# scales ring where it struck and throw a glint, and no hurt.
				_turned_at = Time.get_ticks_msec() / 1000.0
				var by: MobState = e.attacker
				var back := (by.pos - hero.pos).normalized() * hero.radius
				MobFx.clang(fx, _at3(hero.pos + back, 1.1), int(sim.now))
				MobFx.glint(fx, _at3(hero.pos + back, 1.2), Palette.RUST[5], int(sim.now), 0.7)
				Events.sfx.emit(&"hit_plate", player.position)
			&"share_turned":
				# The ploughshare turned a charge (FightKit.ploughshare): the glove
				# rings on the machine's flank and rime sprays off along the way it
				# is carried on.
				_share_turned_at = Time.get_ticks_msec() / 1000.0
				var sm: MobState = e.mob
				var run := Vector2.from_angle(sm.facing)
				var side := (hero.pos - sm.pos).normalized() * sm.radius
				MobFx.clang(fx, _at3(sm.pos + side, 0.8), int(sim.now))
				MobFx.puffs(fx, _at3(sm.pos + side, 0.3), run, Palette.RIME[5], 4, 0.7, sm.id)
				Events.sfx.emit(&"hit_plate", player.position)
			&"hurt":
				_on_hurt(e)
			&"killed":
				_on_killed(e)
			&"second_act":
				var m: MobState = e.mob
				Events.sfx.emit(&"second_act", _at3(m.pos))
				if m.node is Mob:
					(m.node as Mob).flash(0.12)
				MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id, 0.8)
				MobFx.ring(fx, _at3(m.pos), MobFx.RING_INK, m.radius + 1.2, 0.45)
				game.camera.shake(0.06, 0.2)
			&"alerted":
				var m: MobState = e.mob
				Events.sfx.emit(&"alert", _at3(m.pos))
				if m.row.get("sight_only", false):
					# The lens catches the light as it finds you: the only warning it gives by eye.
					MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id, 0.6)
			&"plating":
				# An edge rang off a keeper's plating (FightRules.bites): the survival
				# state remembers the hardness it wants and whose, and the first time
				# it says why: the short form of what the one who named the keeper
				# told the player (Guide.edge_line, StoryContent.EDGE).
				var m: MobState = e.mob
				var plate := StringName(e.get("plate", &""))
				var st := SurvivalState.of(game)
				var design := Roster.sentinel_of(m.kind)
				var def := Sentinels.by_id(design) if design != &"" else null
				_plating_at = sim.now
				if plate != &"" and not st.plates.has(plate):
					st.plates[plate] = def.land if def != null else &""
					# Said at once, with the keeper close: the HUD keeps quiet in a
					# fight, and this is the one line the fight is for.
					if game.hud != null:
						game.hud.say_now(Guide.edge_line(&"rings", Guide.keeper_name(def.land if def != null else &"")))
			&"unseen_tell":
				# A bite begun out of the player's sight in a crowd: a call from its
				# bearing, and a mark at the slate's edge on its side for its tell.
				var m: MobState = e.mob
				Events.sfx.emit(&"unseen_tell", _at3(m.pos))
				if game.hud != null and game.camera != null:
					var tell := float(m.bite.windup) * FightSim.UNSEEN_TELL / 1000.0 if m.bite != null else 0.6
					game.hud.flag_unseen(_screen_dir(_at3(m.pos)), tell)
			&"windup":
				var m: MobState = e.mob
				Events.sfx.emit(&"windup", _at3(m.pos))
				# A keeper's come-round (Brains._come_round), for the tour's claim.
				if bool(e.get("come_round", false)):
					_came_round_at = Time.get_ticks_msec() / 1000.0
				if m.blow != null and m.node is Mob:
					# Over the WORKING PART, flicked down at it. The tell has to
					# send the eye to the side that opens — the side that hurts
					# you and the side you have to hit; three ticks floating over
					# the hull sent it to the roof while the comb was at the floor.
					# Hung on the MODEL, which is the thing that turns (Mob keeps the
					# lean and the heave; the model carries the facing). On the mob
					# node the mark would sit still while the machine swung round to
					# face you, and end up over its back.
					var mob := m.node as Mob
					var up := _screen_up()
					var on: Node = mob.model if mob.model != null else mob
					MobFx.tell(on, _part_at(m), up, m.blow.windup / 1000.0, m.id, 0.6 + m.radius * 0.5, MobFx.FLICK_DOWN)
				if m.blow != null:
					# And on the ground, where it will land: the pose is small over the
					# shoulder and a mark on the ground reads from above and behind alike.
					# It lasts the windup, so it is gone the instant the bite is down. It
					# is the ground the blow lands on, exactly: a bite's or a throw's box
					# grown by the player's radius (FightRules.tell_box).
					if m.blow.area and m.drop_at.is_finite():
						# Coming down from above: its shadow, growing where it lands.
						var spot := FightRules.tell_drop(m.drop_at, m.radius, m.blow, sim.hero.radius)
						MobFx.tell_drop(fx, _at3(Vector2(spot.x, spot.y)), Palette.LINEN[5], spot.z, m.blow.windup / 1000.0)
					else:
						var tb := FightRules.tell_box(m.pos, m.facing, m.radius, m.blow, sim.hero.radius)
						# Heard through a wall with the listener's ear (FightKit.listen).
						MobFx.tell_box(fx, _at3(Vector2(tb.x, tb.y)), m.facing, tb.z, tb.w, sim.hero.radius,
								Palette.LINEN[5], m.blow.windup / 1000.0, hero.kit.listen)
			&"charge":
				var m: MobState = e.mob
				MobFx.puffs(fx, _at3(m.pos - m.bearing * m.radius), -m.bearing, _dust_colour(m.pos), 2, 0.5 + m.radius * 0.4, m.id + int(sim.now))
			&"called":
				var m: MobState = e.mob
				Events.sfx.emit(&"watcher_call", _at3(m.pos))
			&"snatch":
				_on_snatch(e.mob)
			&"filed":
				# Nothing is said: machines seeing further is what the player notices.
				Snatch.file(game.body)
			&"holding":
				if bool(e.get("seen", false)):
					Events.ring_held.emit((e.mob as MobState).kind)
			&"outcome":
				_on_outcome(e)


func _on_hit(e: Dictionary) -> void:
	var target: Fighter = e.target
	var attacker: Fighter = e.attacker
	var at: Vector2 = e.at
	var m := target as MobState
	var h: float = m.row.get("height", 1.0) if m != null else 1.0
	var from_dir := (target.pos - attacker.pos).normalized()
	# Where the blow met the body: the near edge of it, at the height of the blow.
	var gap := attacker.pos.distance_to(target.pos)
	var meet := attacker.pos + from_dir * clampf(gap - target.radius, attacker.radius, gap)
	var impact := _at3(meet, clampf(h * 0.5, 0.35, 0.7))
	var fx := _fx_parent()
	Events.hit.emit(_node_of(attacker), _node_of(target), int(e.damage), bool(e.plate), _at3(at))
	if e.plate:
		Events.sfx.emit(&"hit_plate", impact)
		MobFx.clang(fx, impact, int(sim.now), target.radius * 2.0)
		game.camera.shake(0.025, 0.07)
		return
	Events.sfx.emit(&"hit_flesh", impact)
	_stop(HITSTOP_HIT)
	game.camera.shake(0.06, 0.12)
	if m != null and m.machine:
		# The blow is in the working part: the burst is drawn over it, and it flares
		# (Mob). A machine is not knocked about, so no dust: one mark, read at a glance.
		# Lifted a little up the screen, so the swinger's own body is not under it.
		MobFx.burst(fx, _part_at(m) + _screen_up() * MobFx.pen_px(6.0), 1.1, int(sim.now), Palette.LENS[3], m.radius * 2.0)
	else:
		MobFx.burst(fx, impact, 0.8, int(sim.now), Color(0, 0, 0, 0), target.radius * 2.0)
		MobFx.puff(fx, _at3(target.pos), from_dir, _dust_colour(target.pos), 0.6, int(sim.now) + 3)
	if target.node is Mob:
		# The part's flare follows from the state (Mob.sync_view), in its order.
		(target.node as Mob).flash(0.06)


## A blow that was not the player's (FightSim.strike: a turret). Seen and heard
## where it landed and nowhere else: no hitstop and no shake, because the
## player's hands did nothing, and no `Events.hit`, because every reader of that
## signal means the player struck something.
## A lattice discharge (FightKit.lattice): a crackle from the body struck to the
## one it jumped to, three kinked strokes of cold light for a fifth of a second,
## so the player sees why a machine they never touched took the hit. A line
## (MobFx.line) keeps its pixel width at both cameras.
func _crackle(from: Vector2, m: MobState, h: float) -> void:
	var fx := _fx_parent()
	var y := clampf(h * 0.5, 0.35, 0.7)
	var a := _at3(from, y)
	var b := _at3(m.pos, y)
	var side := Vector3(-(b - a).z, 0.0, (b - a).x).normalized()
	var pts: Array[Vector3] = [a]
	for k in 2:
		var t := (float(k) + 1.0) / 3.0
		var kink := (Rng.hash01(m.id, int(sim.now), k) - 0.5) * 0.7
		pts.append(a.lerp(b, t) + side * kink + Vector3(0.0, kink * 0.3, 0.0))
	pts.append(b)
	for k in 3:
		MobFx.line(fx, pts[k], pts[k + 1], Palette.COLD[3], 0.2)


## Real second the last rake was drawn, and the last grip failed on an anchored
## player, for the tour's `raked` and `grip_failed`.
var _raked_at := -INF
var _grip_failed_at := -INF
var _turned_at := -INF
var _plated_at := -INF
## The worn plate was spent in a fight (tour_seen `plate_spent`).
var _seen_spent := false
var _share_turned_at := -INF
var _cabled_at := -INF
var _came_round_at := -INF
var _bogged_at := -INF
var _locked_at := -INF
var _stripped_at := -INF


## `raked`: a rake's tines are on the ground now (they stand 0.35 s);
## `grip_failed`: a grip rang off a rooted player just now.
func tour_seen(what: StringName) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	match what:
		# The player's blow is live with four steps of its slice left, so a
		# `shot` (three steps on) takes it at the end of its live slice, the
		# stroke drawn furthest across its box (swing_drawn.tour).
		&"swing_closing":
			var b := sim.hero.blow
			var e := sim.now - sim.hero.blow_at
			return b != null and e >= b.windup and e >= b.windup + b.active - 67.0 and e < b.windup + b.active
		&"raked":
			return now - _raked_at < 0.35
		&"grip_failed":
			return now - _grip_failed_at < 0.4
		&"turned":
			return now - _turned_at < 0.4
		# The plate has just taken its share of a blow landing on him.
		&"plated":
			return now - _plated_at < 2.0
		&"plate_spent":
			return _seen_spent
		# The bench plate is on his back.
		&"plate_on":
			return FightRules.wears(game.inventory, &"plate")
		&"share_turned":
			return now - _share_turned_at < 0.6
		&"cabled":
			return now - _cabled_at < 0.6
		&"came_round":
			return now - _came_round_at < 0.4
		&"bogged":
			return now - _bogged_at < 0.6
		&"felled":
			return now - _felled_at < 2.0
		&"locked":
			return now - _locked_at < FightKit.LOCK_SECONDS
		&"stripped":
			return now - _stripped_at < 1.0
		# On the fight's own clock: a frame is taken after the ring, however slow.
		&"plating":
			return sim.now - _plating_at < 1500.0
		# A gripper torn loose still stands jammed (Blow.torn), on the fight's clock.
		&"torn":
			return sim.now < _torn_until
		# On the fight's own clock: a tell lasts its sim time however slow the frame.
		&"curtain_tell":
			return sim.now - float(_curtain_seen.get(what, -INF)) < 1400.0
		&"curtain_up", &"curtain_cracked", &"curtain_crumbling", &"curtain_down":
			return sim.now - float(_curtain_seen.get(what, -INF)) < 1000.0
	return false


## A rake (FightKit.rake): the tines drawn across the ground ahead, five short
## strokes fanned over the arc, and a glint on the part of every body it holds
## open, so the player sees what the heavy has opened before it comes down.
func _rake_marks(e: Dictionary) -> void:
	_raked_at = Time.get_ticks_msec() / 1000.0
	var fx := _fx_parent()
	var from: Vector2 = e.from
	var facing: float = e.facing
	for k in 5:
		var a := facing + FightKit.RAKE_ARC * (float(k) / 2.0 - 1.0)
		var dir := Vector2.from_angle(a)
		MobFx.line(fx, _at3(from + dir * 1.0, 0.06), _at3(from + dir * FightKit.RAKE_REACH, 0.06), Palette.LINEN[5], 0.35)
	for m: MobState in (e.bodies as Array):
		MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id, 0.7)
	Events.sfx.emit(&"hit_plate", _at3(from))


func _on_struck(e: Dictionary) -> void:
	var m := e.target as MobState
	if m == null:
		return
	var from: Vector2 = e.from
	var fx := _fx_parent()
	var h: float = m.row.get("height", 1.0)
	if bool(e.get("arc", false)):
		_crackle(from, m, h)
	var dir := (m.pos - from).normalized()
	var impact := _at3(m.pos - dir * m.radius, clampf(h * 0.5, 0.35, 0.7))
	if e.plate:
		Events.sfx.emit(&"hit_plate", impact)
		MobFx.clang(fx, impact, int(sim.now), m.radius * 2.0)
		return
	Events.sfx.emit(&"hit_flesh", impact)
	if m.machine:
		MobFx.burst(fx, _part_at(m), 0.9, int(sim.now), Palette.LENS[3])
	else:
		MobFx.burst(fx, impact, 0.7, int(sim.now))
	if m.node is Mob:
		(m.node as Mob).flash(0.06)


func _on_hurt(e: Dictionary) -> void:
	var by: MobState = e.attacker
	var hero := sim.hero
	var player := game.player
	var fx := _fx_parent()
	var dir := (hero.pos - by.pos).normalized() if by != null else Vector2.ZERO
	Events.hit.emit(_node_of(by), player, int(e.damage), false, _at3(hero.pos))
	Events.sfx.emit(&"hit_flesh", player.position)
	player.model.play_action(&"hurt", 0.3)
	# Where the blow came from, so the flash goes hot on the side it landed on
	# rather than over the whole body (Player.flash).
	player.flash(0.08, _at3(hero.pos - dir * 0.35, 0.9))
	_stop(HITSTOP_HURT)
	game.camera.shake(0.12, 0.18)
	MobFx.burst(fx, _at3(hero.pos - dir * 0.15, 0.75), 0.9, int(sim.now) + 9)
	MobFx.puffs(fx, _at3(hero.pos), dir, _dust_colour(hero.pos), 2, 0.6, int(sim.now) + 5)


func _on_killed(e: Dictionary) -> void:
	var m: MobState = e.mob
	var at := _at3(m.pos)
	var fx := _fx_parent()
	Events.killed.emit(m.kind, at)
	if m.machine:
		Events.sfx.emit(&"machine_down", at)
		# Its light goes out with a click and a puff of its own smoke off the part:
		# heard and seen apart from the blow that did it.
		Events.sfx.emit(&"lamp_off", _part_at(m))
		MobFx.puff(fx, _part_at(m), Vector2.ZERO, Palette.STONE[4], 0.7, m.id + 11)
	var by_player := bool(e.get("by_player", true))
	if by_player:
		_stop(HITSTOP_KILL)
		game.camera.shake(0.1, 0.22)
	MobFx.puffs(fx, at, Vector2.ZERO, _dust_colour(m.pos), 5, 0.5 + m.radius * 0.6, m.id)
	MobFx.ring(fx, at, MobFx.RING_INK, m.radius + 1.0, 0.4)
	var drops: int = m.row.get("drops", 0)
	# Its plate stays on it, to be stripped where it fell (48_carcasses): nothing
	# is in the pack until the hands have taken it off. A kill somebody else made
	# (a turret in the yard) leaves nothing on it for him.
	if m.machine and drops > 0 and by_player:
		m.spoils.push_front({"item": &"scrap", "count": drops})


func _on_snatch(m: MobState) -> void:
	var r := Snatch.apply(m.kind, game.body, game.inventory, game.clock.minutes)
	Events.sfx.emit(&"snatch", _at3(sim.hero.pos))
	# It came in close and went: dust where it turned, and a flicker over the player.
	var fx := _fx_parent()
	MobFx.puffs(fx, _at3(m.pos.lerp(sim.hero.pos, 0.5)), m.pos - sim.hero.pos, _dust_colour(sim.hero.pos), 2, 0.5, m.id)
	MobFx.tell(game.player, game.player.global_position + Vector3(0, 1.7, 0), _screen_up(), 0.25, m.id, 0.7)
	if String(r.line) != "":
		Events.message.emit(String(r.line))
	var arrest: bool = m.row.get("hits", {}).get("arrest", false)
	if float(r.minutes) > 0.0:
		var reason: StringName = &"arrested" if arrest else &"snatched"
		game.clock.skip(float(r.minutes))
		Events.time_skipped.emit(float(r.minutes), reason)
	if arrest:
		# Stood at the side of the track, as the line says: the hours pass off it.
		var off := Outcomes.off_the_track(game.world, game.query, sim.hero.pos)
		if off.moved:
			_put_hero(off.pos, sim.hero.facing)


func _on_outcome(e: Dictionary) -> void:
	var outcome: StringName = e.outcome
	var by: MobState = e.get("by", null)
	var player := game.player
	var hero := sim.hero
	Events.fight_ended.emit(outcome)
	if game.options.fail_downed and (outcome == &"downed" or outcome == &"carried"):
		printerr("ERROR fight: the player was %s (--fail-downed)" % outcome)
		get_tree().quit(1)
	match outcome:
		&"downed":
			var r := Outcomes.downed(game.body, game.clock, by.kind if by != null else &"")
			hero.health = game.body.health
			if by != null and Sentinels.is_keeper(by.row):
				var edge := Sentinels.arena_edge(game.world, game.query, by.home, hero.pos, Tuning.PLAYER_RADIUS, FightSim.HERO_TALL)
				if edge.is_finite():
					player.place(edge, (by.home - edge).angle())
					player.sync_view(0.0)
					game.view.ensure_near(hero.pos)
					game.camera.snap_to(player.position)
					r.line = Outcomes.KEEPER_DOWNED_LINE
			_wake()
			Events.sfx.emit(&"downed", player.position)
			Events.time_skipped.emit(float(r.minutes), &"downed")
			Events.message.emit(String(r.line))
		&"carried":
			var taken_at := hero.pos
			var r := Outcomes.carried(game.body, game.inventory, game.clock, game.world, game.query, hero.pos)
			var bag := Survival.leave_bag(game, taken_at)
			var home := Outcomes.home_hearth(_holdings(), taken_at, game.world, game.query)
			if not home.is_empty():
				r.pos = home.pos
				r.facing = home.facing
				r.line = HOME_LINE
			player.place(r.pos, r.facing)
			hero.throw_until = 0.0
			player.sync_view(0.0)
			game.view.ensure_near(hero.pos)
			game.camera.snap_to(player.position)
			_wake()
			Events.time_skipped.emit(float(r.minutes), &"carried")
			Events.message.emit(String(r.line))
			if bag != null:
				Events.message.emit(Survival.BAG_LINE)


## `near bag`: beside the heap the last bad end left (Survival.leave_bag), a
## step off it toward the camera, facing it, in reach of `use`.
## `near gap`: GAP_BACK before the nearest way between two solid things a warden
## seals (the curtains' own gap test, FightSim.gap_crossed), facing through it;
## `walkto gap` walks through it and on; `near gap_far` stands just beyond it,
## turned back to face it, and `near gap_view` further back, for a frame of it.
const TOUR_PLACES: Array[String] = ["bag", "gap", "gap_far", "gap_view"]
## `near gap_view`: back from the far side far enough to hold a curtain whole.
const GAP_VIEW := 3.4
const GAP_BACK := 2.5
## The way last found for `near gap`: {at, n (from the near side toward the far)}.
var _gap := {}


func tour_place(what: String) -> Vector2:
	if what == "gap":
		# The same way again while the player is still by it: stood back to face
		# the curtain across the gap they came through, not some other gap.
		if _gap.is_empty() or (_gap.at as Vector2).distance_to(game.player.pos) > 10.0:
			_gap = _nearest_gap()
		return (_gap.at as Vector2) - (_gap.n as Vector2) * GAP_BACK if not _gap.is_empty() else Vector2.INF
	if what == "gap_far" or what == "gap_view":
		return _gap_stand(what) if not _gap.is_empty() else Vector2.INF
	var heap := _last_bag()
	if what != "bag" or heap == null:
		return Vector2.INF
	return heap.pos + Vector2(0.9, 0.5)


func tour_face(what: String) -> float:
	if what == "gap" and not _gap.is_empty():
		return (_gap.n as Vector2).angle()
	if (what == "gap_far" or what == "gap_view") and not _gap.is_empty():
		return ((_gap.at as Vector2) - _gap_stand(what)).angle()
	var heap := _last_bag()
	if what != "bag" or heap == null:
		return NAN
	return (heap.pos - (heap.pos + Vector2(0.9, 0.5))).angle()


## `walkto gap`: through the way `near gap` found and on, away from the side the
## nearest sealing body is on, as a player runs from it; `near gap_far` then
## stands on the side they came out on.
func tour_route(what: String) -> PackedVector2Array:
	if what != "gap" or _gap.is_empty():
		return PackedVector2Array()
	var at: Vector2 = _gap.at
	var n: Vector2 = _gap.n
	var d := n
	var best := INF
	for m: MobState in sim.mobs:
		if m.alive and not m.removed and not FightSim.seals_of(m.row).is_empty() and m.pos.distance_to(at) < best:
			best = m.pos.distance_to(at)
			d = -n if (m.pos - at).dot(n) > 0.0 else n
	_gap.d = d
	# A step or two past it, so the tell is still going when the walk is done.
	return PackedVector2Array([at, at + d * 1.2])


## Where `gap_far` and `gap_view` stand: out on the side the player came through
## to, and for the view a step to one side too, so the player's own back is not
## in front of the curtain over the shoulder.
func _gap_stand(what: String) -> Vector2:
	var at: Vector2 = _gap.at
	var d: Vector2 = _gap.get("d", _gap.n)
	if what == "gap_far":
		return at + d * 1.6
	return at + d * GAP_VIEW - d.orthogonal() * 1.6


## The nearest way a warden seals, with open ground a walk long on both sides.
func _nearest_gap() -> Dictionary:
	var sealing := FightSim.seals_of(Roster.row(&"sentinel.limestone_caves"))
	var most := float(sealing.get("gap", 2.2))
	var here := game.player.pos
	var near: Array[WorldProp] = []
	for p: WorldProp in game.query.props_near(here, 30.0):
		if p.solid > 0.2 and not game.world.depleted.has(p.id):
			near.append(p)
	var best := {}
	var best_d := INF
	for i in near.size():
		for j in range(i + 1, near.size()):
			var a := near[i]
			var b := near[j]
			var gap := a.pos.distance_to(b.pos) - a.solid - b.solid
			if gap < 0.9 or gap > most:
				continue
			var across := (b.pos - a.pos).normalized()
			var at := a.pos + across * (a.solid + gap * 0.5)
			var d := at.distance_to(here)
			if d >= best_d:
				continue
			var n := across.orthogonal()
			if (here - at).dot(n) > 0.0:
				n = -n
			var from := at - n * GAP_BACK
			var to := at + n * GAP_BACK
			if not NavField.line_walkable(game.world, from, to, 0.3):
				continue
			# One way, not a run of them: no other solid thing near the lane, or
			# the walk out passes a second gap and the curtain goes up there.
			var lone := true
			for o: WorldProp in near:
				if WorldProp.same(o, a) or WorldProp.same(o, b):
					continue
				if Geometry2D.get_closest_point_to_segment(o.pos, from, to).distance_to(o.pos) < o.solid + 1.2:
					lone = false
					break
			if not lone:
				continue
			best = {"at": at, "n": n}
			best_d = d
	return best


func _last_bag() -> WorldProp:
	var state := SurvivalState.of(game)
	var best := -1
	for id: int in state.bags:
		if best < 0 or float(state.bags[id]) >= float(state.bags[best]):
			best = id
	return game.world.prop(best) if best >= 0 else null


const HOME_LINE := "You wake by your own fire, hands raw. The headlamp is off."


## The player's holdings in the realm they are in, from whichever system keeps
## them (46_settlements), found by its `places` rather than its name.
func _holdings() -> Array:
	for sys in game.systems:
		if sys.get(&"places") is Array and sys.has_method(&"realm_here") and sys.has_method(&"all"):
			return sys.call(&"all", sys.call(&"realm_here"))
	return []


## Moved while the hours went by: the player, the land about them and the camera all at once.
func _put_hero(at: Vector2, facing: float) -> void:
	game.player.place(at, facing)
	sim.hero.throw_until = 0.0
	game.player.sync_view(0.0)
	game.view.ensure_near(sim.hero.pos)
	game.camera.snap_to(game.player.position)


## Coming round after a bad end: the body lies a moment and gets up before it
## will walk, so the hours that went by are felt and not skipped past.
func _wake() -> void:
	# The hours lost were lost lying there: they mend nothing. Mending counts from waking.
	_mend_from = game.clock.minutes
	_last_health = game.body.health
	game.player.model.play_action(&"downed", WAKE_SECONDS)
	game.body.busy_until = maxf(game.body.busy_until, Survival.now_real() + WAKE_SECONDS)


# --- held moments for shots (--act) -------------------------------------------

## Plays a moment of a fight against the first body --spawn placed, then holds
## it still so a shot shows it: swing (a blow reaching the working part),
## grip (a seizing bite closed and a pull against it), hurt, dodge (through a
## live bite), alert (the body registering the player).
func _play_act(spec: String) -> void:
	var parts := spec.split(":")
	var act := parts[0]
	var ms := parts[1].to_float() if parts.size() > 1 else -1.0
	var hero := sim.hero
	var target: MobState = sim.mobs[0] if not sim.mobs.is_empty() else null
	MobFx.hold = true
	if target != null:
		for m in sim.mobs:
			m.calm_until = INF
			# Held to its spot: a machine at idle would walk its beat out of the picture.
			m.line_a = m.pos
			m.line_b = m.pos
		hero.facing = (target.pos - hero.pos).angle()
		game.player.facing = hero.facing
	match act:
		"swing":
			if target != null:
				_stand_on_part_side(target)
			sim.press_swing()
			sim.slices(1)
			var b := hero.blow
			var until := ms if ms >= 0.0 else (b.windup + b.active * 0.6 if b != null else 100.0)
			_run_for(until)
		"grip":
			if target != null and target.bite != null:
				_bring_to_bite(target)
				Brains.bite(target, sim)
				_run_for(target.bite.windup + target.bite.active)
				# Just taken: the jaw has closed and the first pull is thrown, before it has hauled you in.
				_run_for(24.0)
				sim.press_swing()
				_run_for(ms if ms >= 0.0 else 60.0)
		"windup":
			if target != null and target.bite != null:
				_bring_to_bite(target)
				Brains.bite(target, sim)
				_run_for(ms if ms >= 0.0 else target.bite.windup * 0.6)
		"hurt":
			if target != null and target.bite != null:
				_bring_to_bite(target)
				Brains.bite(target, sim)
				_run_for((target.bite.windup + target.bite.active * 0.5) + (ms if ms >= 0.0 else 40.0))
		"dodge":
			if target != null and target.bite != null:
				_bring_to_bite(target)
				Brains.bite(target, sim)
				_run_for(maxf(0.0, target.bite.windup - 60.0))
				hero.move = Vector2.from_angle(hero.facing + PI * 0.5)
				sim.press_dodge()
				_run_for(ms if ms >= 0.0 else 90.0)
		"fx":
			# Every mark about the player, held at MS/1000 of its life (review only).
			MobFx.hold_at = clampf(ms / 1000.0, 0.0, 0.99) if ms >= 0.0 else 0.3
			var p3 := game.player.position
			var dust := _dust_colour(sim.hero.pos)
			MobFx.burst(game, p3 + Vector3(2.0, 0.6, -2.0), 1.0, 3, Palette.LENS[3])
			MobFx.burst(game, p3 + Vector3(-2.0, 0.6, -2.0), 0.8, 4)
			MobFx.puff(game, p3 + Vector3(2.0, 0, 0), Vector2.RIGHT, dust, 0.6, 5)
			MobFx.puffs(game, p3 + Vector3(0, 0, -2.5), Vector2.ZERO, dust, 4, 0.55, 6)
			MobFx.ring(game, p3 + Vector3(-2.0, 0, 0), MobFx.RING_INK, 1.0, 0.3)
			MobFx.clang(game, p3 + Vector3(0, 0.6, 2.0), 7)
			MobFx.glint(game, p3 + Vector3(-2.0, 0.6, 2.0), Palette.LENS[3], 9, 0.6)
			MobFx.streak(game, p3 + Vector3(2.0, 0.6, 2.0), Vector2(1, -1), game.camera.yaw_now(), game.camera.pitch_deg, 10)
			MobFx.tell(game, p3 + Vector3(0, 0.3, 0) + Vector3(-1.2, 0, 1.2) * 2.0, _screen_up(), 0.4, 11)
			MobFx.breath(game, p3 + Vector3(-2.0, 1.3, -2.0), Palette.RIME[3], 0.4, 1.6, Vector2.ZERO, 12)
			# And one burst on the BODY, at that body's own width, because the rule
			# that sizes it (MobFx.on_body) cannot be seen in marks laid on grass:
			# every mark above is drawn with no body under it and takes the plain
			# floor. This is the one a player actually gets on a machine.
			if target != null:
				MobFx.burst(game, _part_at(target), 1.1, 13, Palette.LENS[3], target.radius * 2.0)
		"alert":
			for m in sim.mobs:
				m.calm_until = 0.0
			_run_for(ms if ms >= 0.0 else 1200.0)
		_:
			push_warning("unknown --act %s" % act)
	_handle(sim.drain())
	game.player.sync_view(0.0, true)
	# Framed on the meeting: between the player and the body, so a watcher on its
	# rise four tiles off is in the picture with the one it watches.
	var focus := game.player.position
	if target != null and target.node is Mob:
		focus = focus.lerp((target.node as Mob).global_position, 0.5)
	_focus = focus
	game.camera.snap_to(focus)
	_held = true
	sim.hold = true


func _run_for(ms: float) -> void:
	var n := maxi(0, roundi(ms / FightRules.SLICE_MS))
	var hero := sim.hero
	var move := hero.move
	var dt := FightRules.SLICE_MS / 1000.0
	for i in n:
		hero.move = move
		sim.slices(1)
		_handle(sim.drain())
		_landing()
		# The bodies are drawn along with it, so a held moment shows its poses
		# (a windup blended in, a swing half thrown) and not the first frame of each.
		game.player.sync_view(dt)
		for m in sim.mobs:
			if m.node is Mob:
				(m.node as Mob).sync_view(dt, sim.now, hero.holder == m)


## Put the player where the blow will reach the working part, facing the body.
func _stand_on_part_side(m: MobState) -> void:
	var hero := sim.hero
	var side := {&"front": 0.0, &"right": PI * 0.5, &"back": PI, &"left": -PI * 0.5}
	var off: float = side.get(m.part, 0.0)
	var dist := m.radius + hero.radius + Blow.for_item(game.inventory.held).reach * 0.6
	var cam_side := hero.pos - m.pos
	if m.part == &"none":
		off = wrapf(cam_side.angle() - m.facing, -PI, PI)
	var at := m.pos + Vector2.from_angle(m.facing + off) * dist
	if game.query.standable(floori(at.x), floori(at.y)):
		game.player.place(at)
	hero.facing = (m.pos - hero.pos).angle()


## Face a body at the player and close to where its bite lands: beside it on
## the screen where there is ground, so neither hides the other in the shot.
func _bring_to_bite(m: MobState) -> void:
	var hero := sim.hero
	var d := m.radius + hero.radius + m.bite.reach * 0.6
	var tries: Array[Vector2] = [Vector2(1, -1).normalized(), Vector2(-1, 1).normalized(), (hero.pos - m.pos).normalized()]
	for dir in tries:
		var at := m.pos + dir * d
		if game.query.standable(floori(at.x), floori(at.y)):
			game.player.place(at)
			break
	m.facing = (hero.pos - m.pos).angle()
	m.aim = m.facing
	hero.facing = (m.pos - hero.pos).angle()
