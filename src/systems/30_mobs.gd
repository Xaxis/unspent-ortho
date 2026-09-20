extends GameSystem
## Puts machines and creatures on the coast around the player and takes them
## off again: the spawner's rolls, culling past 24 tiles, clearing the coast
## when the clock jumps, and a Mob node for every body in the simulation.
## The simulation itself (FightSim) is created here and stepped by 40_fight.

## A jump in the clock longer than this clears the coast (design-extract §7.4).
const JUMP_CLEARS := 30.0
## The jumps that are hours away from this place: sleeping, a bad end, a spell
## held by a machine. Taking and making never clear the coast (they are
## MAX_JUMP_MINUTES at most, and refused with a hostile close).
const CLEARING: Array[StringName] = [&"sleep", &"downed", &"carried", &"collapse", &"arrested", &"snatched"]

var sim: FightSim
var moment: Moment
var spawner: Spawner
var coast: Coast
var _told_ms := -Racket.QUIET_MS
var _layer: Node3D


func setup(g: Game) -> void:
	super.setup(g)
	moment = Moment.new()
	moment.seed_value = g.world.seed_value
	_read_moment()
	var hero := Hero.new()
	hero.body = g.body
	hero.inventory = g.inventory
	hero.pos = g.player.pos
	hero.facing = g.player.facing
	sim = FightSim.new(g.world, g.query, hero, moment)
	sim.real_s = Time.get_ticks_msec() / 1000.0
	g.player.hero = hero
	g.player.sim = sim
	spawner = Spawner.new()
	spawner.view_height = g.camera.view_height
	_layer = Node3D.new()
	_layer.name = "mobs"
	g.add_child(_layer)
	coast = Coast.new(sim, spawner)
	_warm_figures()
	coast.spawning = g.options.spawn.is_empty()
	Events.time_skipped.connect(_on_time_skipped)
	for k: String in g.options.spawn:
		var staged := Spawner.staged(k)
		place_near_player(staged.id, staged.facing)
	_ensure_nodes(true)


## EVERY KIND'S FIGURE BUILT BEFORE ANY OF THEM WALKS IN.
##
## **A LAZY BUILD IS A LURCH WITH A DELAY ON IT**, which is the same shape as the
## footprint textures, and the owner felt this one as "every second of running
## causes a small lurch". Measured walking a populated world: `_ensure_nodes`
## took **94 ms to stand ONE body up** the first time that kind appeared, against
## 8.5 ms for the next of the same kind — the script load, the first mesh and the
## first material of that kind, all on the main thread, in the frame a machine
## came over the rise. As a player walks and new kinds come into range it fires
## again, and again.
##
## The built figure is thrown away: what is bought is the kind's SCRIPT being
## resident and its material having been through the renderer once. Measured
## after: 30_mobs' worst physics tick 145.6 ms -> 34.7.
##
## **THIS LIVES HERE AND NOT IN `FigureModel` ON PURPOSE.** `src/models/` is
## frozen to the LOOK wave (CLAUDE.md), and a warm-up is the caller's business
## anyway — it is about when a cost is paid, not about what a figure is.
func _warm_figures() -> void:
	var mat: Material = game.view.world_material() if game.view != null else null
	for k: StringName in Roster.kinds():
		var m := FigureModel.create(k, mat)
		if m != null:
			m.free()


func _physics_process(_delta: float) -> void:
	if sim == null:
		return
	_read_moment()
	coast.tick()
	_listen()
	_ensure_nodes()


func _process(delta: float) -> void:
	if sim == null:
		return
	_ensure_nodes()
	var frozen := sim.hold
	for c in _layer.get_children():
		var mob := c as Mob
		if mob == null:
			continue
		if mob.state.removed:
			if not mob.state.alive and sim.now - mob.state.dead_at >= float(mob.state.stat("linger", 30.0)) * 1000.0 - 50.0:
				# A body that has lain its time comes apart where it lay, not in a blink.
				var dust := Palette.STONE[4] if mob.state.machine else Palette.SAND[4]
				MobFx.puffs(game, mob.global_position, Vector2.ZERO, dust, 3, 0.5 + mob.state.radius * 0.6, mob.state.id)
			mob.queue_free()
			continue
		mob.sync_view(0.0 if frozen else delta, sim.now, sim.hero.holder == mob.state)


## A machine heard and not yet seen: say so, once (Racket).
func _listen() -> void:
	var now_ms := float(Time.get_ticks_msec())
	var aerial := FightRules.wears(game.inventory, &"aerial")
	for m in sim.mobs:
		var visible := spawner.in_view(sim.hero.pos, m.pos, 0.0)
		if Racket.should_tell(m, sim.hero.pos, visible, aerial, now_ms, _told_ms):
			m.heard_told = true
			_told_ms = now_ms
			Events.message.emit(Racket.line_for(m, sim.hero.pos))
		elif visible:
			# Seen first: nothing to tell about this one later.
			m.heard_told = true


## How long standing bodies up may take in one frame before the rest wait for
## the next. **BODIES ARRIVE IN GROUPS AND THE COST IS PER BODY**, so a patrol of
## eight coming over the rise together built eight figures in one frame: 8.5 ms
## each once the kind is warm, which is 68 ms in the frame they appear. Spread,
## not skipped -- every body still gets its node, at worst a frame or two later,
## and a body with no node yet is one the player cannot see anyway.
##
## Four milliseconds leaves room for the rest of the frame inside 16.7 and still
## stands two or three bodies up a frame, so a group is whole within about a
## tenth of a second.
const NODE_BUDGET_MS := 4.0


## `all` builds every waiting body whatever it costs: setup and staging want the
## world complete before the first frame is drawn, and a shot with `--spawn`
## must hold its subject in the frame it claims.
func _ensure_nodes(all: bool = false) -> void:
	var began := Time.get_ticks_usec()
	for m in sim.mobs:
		if not all and float(Time.get_ticks_usec() - began) / 1000.0 > NODE_BUDGET_MS:
			return
		if m.node == null and not m.removed:
			var mob := Mob.new()
			_layer.add_child(mob)
			mob.setup(m, game.world, game.view.world_material())
			# A figure that draws itself as a PERSON (a machine that passes) needs
			# what every other person is given and no machine ever is: a seed, so
			# a street is not the same body six times, and the world's sun, since
			# somebody casting no shadow where everyone else casts one would be
			# the loudest tell in the landscape.
			if mob.model.has_method(&"pass_as"):
				mob.model.call(&"pass_as", Rng.hash_ints(game.world.seed_value, m.id, 0x9A55),
					game.sky.sun if game.sky != null else null)


func _read_moment() -> void:
	moment.minutes = game.clock.minutes
	moment.lamp_lit = game.body.lamp_lit
	moment.filed = game.body.filed
	moment.laden_tier = FightRules.laden_tier(game.body.load)
	moment.spoofed = game.body.spoof_until > game.clock.minutes
	# The weather where the bodies that matter are standing, which is where the
	# player is: a machine in a whiteout is blinded by the whiteout. This is
	# read once before the sim exists, on the way to building it, so the player
	# node is what it asks.
	moment.read_weather(BiomeRegistry.at(game.world, game.player.pos).id)


func _on_time_skipped(minutes: float, reason: StringName) -> void:
	if sim == null or minutes <= JUMP_CLEARS or not CLEARING.has(reason):
		return
	if sim.fight_on and reason != &"downed" and reason != &"carried":
		# Nothing long starts with a fight on (Survival.threat_near); if a jump comes
		# anyway, it does not delete what is charging the player.
		return
	sim.clear_mobs()


## Put a body where the camera shows it, in front of the player, on ground it
## may stand on. Used by --spawn for shots and by tests.
##
## It faces the PLAYER unless `facing` says otherwise (radians; `Spawner.staged`
## turns `--spawn=runner@-112` into one). A bearing is asked for when the frame is
## about the MODEL rather than about the fight: a hull is opened up and proved on
## a mask at one yaw, and the only way to ask whether that reads in the lit world
## is to stand the thing at that yaw and look. Where it LANDS is unchanged either
## way, so a spawn still fails when nothing could be placed in frame.
func place_near_player(kind: StringName, facing: float = NAN) -> MobState:
	if kind == &"":
		return null
	# The camera's frame as it is NOW, not as it was when this system was set up.
	# `in_view` below decides where a body is allowed to land, and the spawner
	# was told the view height once, in setup(); anything that zooms afterwards —
	# a tour's `zoom`, dev mode's view page — left it scoring against a frame the
	# camera no longer has, so a body asked for could be placed off screen and the
	# picture taken of it held nothing. The tour was writing this line itself
	# before every spawn; it belongs here, where every caller gets it.
	if game.camera != null:
		spawner.view_height = game.camera.view_height
		# AND ITS PITCH, or a body is placed for a camera that is not the one
		# drawing. `head_lift` divides by tan(pitch) to work out where the top of a
		# body lands on the ground plane, so a stale 57 while the camera has glided
		# to third person (09_view) puts a machine's head off the top of the frame
		# and it arrives with no warning -- which is the whole reason the zoom has a
		# near limit at all.
		spawner.pitch_deg = game.camera.pitch_deg
	var row := Roster.row(kind)
	var w := game.world
	var hp := sim.hero.pos
	var index := sim.mobs.size()
	var r: float = row.get("radius", 0.5)
	# Screen up and right of the player (world north): the body faces back toward
	# the camera side, so its front and the player's blow are both in view; several fan out.
	var ang := -PI * 0.5 + index * 0.9
	if float(row.get("height", 1.0)) < 1.0:
		# Low bodies go screen right instead, or the player would stand in front of them.
		ang = -PI * 0.25 + index * 0.9
	var dist := 1.6 + r + Tuning.PLAYER_RADIUS + 0.4
	if row.get("where", {}).get("rise", false):
		dist = 4.5
	var best := hp + Vector2.from_angle(ang) * dist
	var best_score := INF
	var keeps: Array = row.get("keeps_to", [])
	# Where the top of the body lands on the ground plane, seen down the camera.
	var yaw := deg_to_rad(spawner.yaw_deg)
	var screen_up := Vector2(-sin(yaw), -cos(yaw))
	var head_lift := screen_up * float(row.get("height", 1.0)) / tan(deg_to_rad(spawner.pitch_deg))
	for ring in range(0, 24):
		for i in 24:
			var a := ang + float(i) / 24.0 * TAU
			var p := hp + Vector2.from_angle(a) * (dist + ring * 0.5)
			var tx := floori(p.x)
			var ty := floori(p.y)
			if not game.query.standable(tx, ty):
				continue
			if not keeps.is_empty() and not Spawner.ground_matches(w.ground_at(tx, ty), keeps):
				continue
			if keeps.is_empty() and Ground.is_water(w.ground_at(tx, ty)):
				continue
			var score := p.distance_to(hp + Vector2.from_angle(ang) * dist)
			if not keeps.is_empty() and Ground.is_water(w.ground_at(tx, ty)):
				score -= 8.0
			if row.get("where", {}).get("rise", false) and Spawner.is_rise(w, tx, ty):
				score -= 20.0
			# Placed for a shot or a test: somewhere the camera shows, head and feet
			# both well inside the frame.
			var margin := -0.15 * spawner.view_height
			if not spawner.in_view(hp, p, margin) or not spawner.in_view(hp, p + head_lift, margin):
				score += 100.0
			if score < best_score:
				best_score = score
				best = p
	var m := sim.add_mob(kind, best)
	m.facing = facing if not is_nan(facing) else (hp - best).angle()
	m.aim = m.facing
	# And its sweep is about the way it was put to face, not about the bearing
	# its tile happened to hash to: a watcher stood in front of the player to be
	# walked past has to be reading the ground in front of it, or the proof is
	# its optics pointing somewhere else and not the heather the player is in.
	m.bearing = Vector2.from_angle(m.facing)
	return m
