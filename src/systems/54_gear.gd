extends GameSystem
## The gear on the body and the abilities it grants (docs/VISION.md, §7.4).
##
## It owns three things and nothing else:
##   the loadout   what is fitted in each of the six slots and their sockets,
##                 configured on the slate's gear page (SlateFeeds &"loadout")
##                 and kept in the save
##   Body.resist   what that loadout keeps off the body, which 52_hazards reads
##   the abilities AbilityBook: the fitted ones, their cooldowns and costs, fired
##                 from the real input actions, so a tour presses the same keys a
##                 player does
##
## An ability never touches a node. It asks for a move (AbilityMotion) and for a
## mark (`_fx`), and this system does both: it is the ONE place that puts the
## player somewhere walking could not, and the one place ability effects are
## drawn. That is the single interface the brief asked for; a sixth ability is a
## file in src/core/gear/abilities and a row in Abilities.make.
##
## Keys: q dash, g glide, r scan, t grapple, v spoof (project.godot [input]).
##
## Look at it:
##   tools/shot.sh shots/hazards/wing.png --fit=glide_wing --frames=40
##   tools/tour.sh tours/hazards.tour --seed=1

## How high off the ground the magnet line leaves the body: hand height, so it
## comes off the player and not off their feet.
const LINE_FROM := 0.75
## And how high it takes hold on what it caught.
const LINE_TO := 0.55
## Seconds between a travelling body's marks (a flight's trail, a rope redrawn as
## it shortens). A mark costs a material and a node, so these keep their own beat
## rather than the frame rate's: laid a little faster than one dies, so the line
## is continuous and the cost is eight a second, not sixty.
const TRAVEL_BEAT := 0.1
## How long the bracket on a scanned part and on a grapple's anchor is held.
const READ_SECONDS := 0.55
## Machines a scan will mark at once: the nearest few, so a works district does
## not fill the frame with light.
const SCAN_MOST := 6
## Seconds between the ink marks over a machine that has noticed you.
const AWARE_BEAT := 0.5
## Seconds between the violet glints that say you are still wearing their name.
const SPOOF_BEAT := 1.5
## A machine this close has had every chance to read the body: if it still has
## not noticed, the spoof is working (the tour's `unnoticed`).
const SPOOF_PROOF_REACH := 12.0
## A body that moves further than this between two frames of a motion was put
## there by something else: the motion gives way to it.
const JUMPED := 3.0
## The motions that THROW a body: over in a fifth of a second, and drawing their
## own mark across the player while they run. A scan's brackets stand down for
## these and for nothing else -- a glide is six seconds of ordinary flight, and
## a scan that goes blind for six seconds has stopped being a scan.
const THROWN: Array[StringName] = [&"dash", &"grapple"]

var loadout := Loadout.new()
var book := AbilityBook.new()
var _motion: AbilityMotion = null
var _wing: GlideWingModel = null
## The magnet line while a pull runs, re-pointed every frame as it shortens.
var _line: MeshInstance3D = null
## Ability ids that have fired in this game, for the tour's awaits.
var _fired: Dictionary = {}
var _gliding := false
## The kind of the last jump that came down (Jump.HOP UP ACROSS DOWN DIVE), and
## every kind that has, for a tour to ask after.
var _jumped: Dictionary = {}
## Seconds a jump's landing is held in the pose after the feet are down: the knees
## taking the weight is half of what says the body fell.
const JUMP_LANDING := PersonAnim.JUMP_ABSORB
## How much louder a landing is for every level it fell.
const LAND_PER_LEVEL := 0.35
## Modules prised out of a socket in this game: the count a pull's risk is indexed
## by, so a reload cannot reroll a part that broke (`Reforge`).
var _pulls := 0
## Real seconds the next ink mark over an aware machine, and the next spoof
## glint, are due (the marks keep their own beat, not the frame rate's).
var _aware_at := 0.0
var _spoof_at := 0.0
## Real seconds left before a travelling motion lays its marks again.
var _travel_at := 0.0
## How long each scanned part's bracket is held, from the scan's own beat.
var _read_for := READ_SECONDS
## Where the last step of a motion put the body, to notice when something else
## has moved it. Vector2.INF while no motion runs.
var _last_pos := Vector2.INF


func setup(g: Game) -> void:
	super.setup(g)
	loadout.changed.connect(_refit)
	g.inventory.changed.connect(_on_inventory_changed)
	SlateFeeds.provide(&"loadout", _feed)
	SlateFeeds.on_act(&"loadout", _act)
	SaveGame.register(&"gear", _save, _load)
	_fit_from_options()
	loadout.hold(g.inventory.held)
	_refit()


func _exit_tree() -> void:
	SlateFeeds.provide(&"loadout", Callable())
	SlateFeeds.on_act(&"loadout", Callable())


## Everything fitted is still carried: a piece traded, spent or dropped comes
## out of its slot by itself.
func _on_inventory_changed() -> void:
	loadout.hold(game.inventory.held)
	loadout.keep_only(func(id: StringName, n: int) -> bool: return game.inventory.count(id) >= n)
	_refit()


func _refit() -> void:
	game.body.resist = Gear.resist_total(loadout)
	# And what it changes in a fight (FightKit): read where a blow lands.
	if game.player != null and game.player.hero != null:
		game.player.hero.kit = FightKit.from_loadout(loadout)
	# Gear grants what it grants; legs are everybody's (Abilities.INNATE).
	book.fit(Abilities.with_innate(Gear.abilities_of(loadout)))
	_dress_player()


## What the player is seen wearing: the body they made (AvatarState), dressed by the loadout.
## The gear page draws this same look (the feed's `figure`), so the slate and the
## world cannot disagree about what is on.
func worn_look() -> Dictionary:
	var body := AvatarState.of(game).look
	return GearLook.compose(body if not body.is_empty() else PersonLook.BASE, loadout)



## Put the worn look on the figure walking the coast. Only when it changed: a
## refit runs on every pickup, and redressing a person rebuilds its meshes. The
## glide wing is the one piece the walking figure does not show until it opens
## (GlideWingModel hides it folded); the gear page draws it folded on the back.
func _dress_player() -> void:
	if game.player == null or game.player.model == null:
		return
	var m := game.player.model
	var look := worn_look()
	if var_to_str(PersonLook.normalize(look)) != var_to_str(m.look):
		m.set_look(look)


# --- input ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if game == null or game.player == null:
		return
	var ctx := _ctx()
	if not game.input_blocked():
		for a in book.all():
			if a.action == &"" or not InputMap.has_action(a.action):
				continue
			if a.hold:
				if Input.is_action_pressed(a.action):
					book.hold_down(a.id, ctx, delta)
			elif Input.is_action_just_pressed(a.action):
				_fire(a.id)
	book.step(_ctx(), delta)
	_run_motion(delta)


func _ctx() -> AbilityCtx:
	var c := AbilityCtx.new()
	c.game = game
	c.now = Time.get_ticks_msec() / 1000.0
	c.fx = _fx
	return c


## Fire one ability through the book (which is where every cost and cooldown
## lives) and, if it asked to move the body, start that move.
func fire(id: StringName) -> StringName:
	# A jump is a motion like any other and never starts over one already running:
	# pressed again in the air it would be a second jump off nothing.
	if id == &"jump" and _motion != null:
		return &"airborne"
	var ctx := _ctx()
	var why := book.press(id, ctx)
	if why != &"":
		return why
	if ctx.motion != null:
		_start_motion(ctx.motion)
	_fired[id] = true
	return &""


func _fire(id: StringName) -> void:
	var why := fire(id)
	if why == &"":
		return
	# The jump key is pressed often and in passing: pressed again in the air, or
	# again the instant the feet are down, it says nothing at all rather than
	# tutting at a player who is only playing.
	if id == &"jump" and why in [&"airborne", &"cooling", &"swinging", &"busy"]:
		return
	# A refusal says why, quietly, and never while a fight is on the screen.
	Events.sfx.emit(&"ability_refused", game.player.position)
	if not Survival.threat_near(game):
		Events.message.emit(Ability.refusal_line(why))


# --- the body moved by an ability ----------------------------------------------

func _start_motion(m: AbilityMotion) -> void:
	_motion = m
	_travel_at = TRAVEL_BEAT
	if m.kind == &"jump":
		if game.player.hero != null:
			game.player.hero.airborne = true
		if game.player.model != null:
			game.player.model.play_action(&"jump", m.seconds + JUMP_LANDING)
	if m.kind == &"glide":
		_gliding = true
		_ensure_wing()
		if _wing != null:
			_wing.set_open(true)


## While a motion runs it owns the body: the hero (which owns position in a
## running game), the player node and its height above the ground.
##
## Anything else that puts the body somewhere -- a teleport, a load, a machine
## carrying you off -- wins: a jump bigger than one step of the move means the
## flight is over, wherever it had got to. Without this a glide would go on
## flying a body that has been put down on the other side of the world.
func _run_motion(delta: float) -> void:
	if _motion == null:
		return
	var hero: Hero = game.player.hero
	var at: Vector2 = hero.pos if hero != null else game.player.pos
	if _last_pos != Vector2.INF and at.distance_to(_last_pos) > JUMPED:
		game.player.lift = 0.0
		_land(_motion)
		_motion = null
		_last_pos = Vector2.INF
		return
	var next := _motion.step(delta, at, game.world, game.query, Tuning.PLAYER_RADIUS)
	var facing := _motion.dir.angle() if _motion.dir.length() > 0.01 else game.player.facing
	if hero != null:
		hero.pos = next
		hero.facing = facing
		hero.move = Vector2.ZERO
	game.player.pos = next
	game.player.facing = facing
	game.player.lift = _motion.lift
	if game.view != null:
		game.view.ensure_near(next)
	if not _motion.finished:
		_travel_marks(delta)
	_last_pos = next
	if not _motion.finished:
		return
	game.player.lift = 0.0
	_land(_motion)
	_motion = null
	_last_pos = Vector2.INF


## What a flight and a pull look like while they are happening. The rope is the
## whole point of a grapple, so it is redrawn EVERY frame from wherever the body
## has got to back to the anchor: a player watches the line shorten and knows
## what is pulling them, instead of seeing a sparkle and being moved.
func _travel_marks(delta: float) -> void:
	if _motion.kind == &"grapple":
		_aim_line()
	_travel_at -= delta
	if _travel_at > 0.0:
		return
	_travel_at = TRAVEL_BEAT
	if _motion.kind == &"glide":
		MobFx.glint(game, game.player.position + Vector3(0, 0.9, 0), Palette.PLATE[3], int(Time.get_ticks_msec()), 0.22)


## The line itself: one ruled line of the machines' own cold, hand to anchor. It
## used to be a mark of light every half tile, which at the distance a grapple is
## actually thrown resolves to two sparkles over a gap of bare ground and reads
## as nothing at all (wave A2, art finding 4). It is FOUND: exact, whole, ruled.
func _draw_line(from: Vector2, to: Vector2) -> void:
	_drop_line()
	if from.distance_to(to) < 0.2:
		return
	_line = MobFx.line(game, _hand(), _line_end(to, LINE_TO), Palette.COLD[3])


func _aim_line() -> void:
	if _line == null or not is_instance_valid(_line):
		return
	MobFx.aim_line(_line, _hand(), _line_end(_motion.to, LINE_TO))


## Where the line leaves the body: the hand that threw it, so the rope does not
## lie across the figure's own chest on the way out.
func _hand() -> Vector3:
	var model := game.player.model
	if model != null and model.rig != null:
		return game.player.global_position + model.hand_position().rotated(Vector3.UP, -game.player.facing)
	return _line_end(game.player.pos, LINE_FROM)


func _line_end(p: Vector2, lift: float) -> Vector3:
	return game.world.to_3d(p) + Vector3(0, lift, 0)


func _drop_line() -> void:
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null


func _land(m: AbilityMotion) -> void:
	if m.kind == &"jump":
		_land_jump(m)
		return
	if m.kind == &"glide":
		_gliding = false
		if _wing != null:
			_wing.set_open(false)
		MobFx.puffs(game, game.player.position, m.dir, Palette.STONE[4], 3, 0.55, int(Time.get_ticks_msec()))
		Events.sfx.emit(&"ability_land", game.player.position)
	elif m.kind == &"grapple":
		_drop_line()
		MobFx.puff(game, game.player.position, -m.dir, Palette.STONE[4], 0.5, int(Time.get_ticks_msec()))


func _process(delta: float) -> void:
	if _wing != null:
		_wing.step(delta)


func _ensure_wing() -> void:
	if _wing != null or game.player == null or game.player.model == null:
		return
	_wing = GlideWingModel.new()
	_wing.name = "glide_wing"
	game.player.model.add_child(_wing)
	_wing.build(game.view.world_material() if game.view != null else null)
	# The model faces +X; the wing spans across the body, off the shoulders.
	_wing.position = Vector3(-0.14, 0.92, 0.0)
	_wing.rotation = Vector3(0.0, PI * 0.5, 0.0)


## The feet coming down. Heard, and heard further the further they fell, because
## a jump off a wall in front of a watcher is a decision and not a free move; a
## dive is the water taking the body, rings and all.
func _land_jump(m: AbilityMotion) -> void:
	var hero: Hero = game.player.hero
	if hero != null:
		hero.airborne = false
	var p := m.plan
	var kind := p.kind if p != null else Jump.HOP
	_jumped[kind] = true
	_jumped[&""] = kind
	var at := game.player.position
	var seed_value := int(Time.get_ticks_msec())
	if kind == Jump.DIVE:
		Events.sfx.emit(&"jump_dive", at)
		MobFx.ring(game, at, Palette.BRINE[5], 1.4, 0.5)
	else:
		Events.sfx.emit(&"jump_land", at)
		MobFx.puffs(game, at, Vector2.ZERO, Palette.STONE[4], 2, 0.35, seed_value)
	var sim: FightSim = game.player.sim
	if sim != null and p != null:
		var fell := maxi(0, p.from_level - p.to_level)
		var ground := game.world.ground_at(floori(p.to.x), floori(p.to.y))
		var radius := StealthNoise.radius(&"land", ground, game.body.crouched, 0) * (1.0 + LAND_PER_LEVEL * float(fell))
		sim.make_noise(p.to, radius)
		# Come down off a ledge onto something below it and the landing is the blow.
		if kind != Jump.DIVE:
			sim.drop_strike(p.from_level)


# --- what an ability looks like ------------------------------------------------

## Every ability effect is drawn here, in ink and stipple for what a person
## made and clean and exact for what was taken from the machines (docs/LOOK.md).
func _fx(what: StringName, args: Dictionary) -> void:
	var at := game.player.position
	var seed_value := int(Time.get_ticks_msec())
	match what:
		&"dash":
			# Speed lines off the heels and a little stipple down the way it came:
			# the burst is drawn, never blurred (docs/LOOK.md).
			#
			# Laid a body's width BEHIND the heels, the way the dodge's lines are,
			# and two puffs rather than four. On the body, with four of them
			# overlapping, the dash was a cream field with the player inside it
			# (wave A2, art finding 3).
			var dir: Vector2 = args.get("dir", Vector2.RIGHT)
			var back := Vector3(dir.x, 0.0, dir.y) * Tuning.PLAYER_RADIUS * 2.0
			MobFx.streak(game, at - back + Vector3(0, 0.55, 0), dir, game.camera.yaw_now(), game.camera.pitch_deg, seed_value, 0.9)
			var dust := Palette.STONE[4]
			for i in 2:
				MobFx.puff(game, at - back * (float(i) * 1.1 + 1.0), -dir, dust, 0.26 - 0.05 * i, seed_value + i * 11)
			Events.sfx.emit(&"ability_dash", at)
		&"jump":
			Events.sfx.emit(&"jump", at)
			MobFx.puff(game, at, -game.player.intent_move, Palette.STONE[4], 0.22, seed_value)
		&"glide":
			Events.sfx.emit(&"ability_glide", at)
		&"scan":
			Events.sfx.emit(&"ability_scan", at)
			MobFx.ring(game, at, Palette.LENS[3], 1.6, 0.4)
			_aware_at = 0.0
			_read_for = _hold_for(args)
			_scan_marks(float(args.get("reach", 20.0)), true)
		&"scan_beat":
			_read_for = _hold_for(args)
			_scan_marks(float(args.get("reach", 20.0)), false)
		&"grapple":
			var from: Vector2 = args.get("at", game.player.pos)
			var to: Vector2 = args.get("to", from)
			# Where the line took hold is held for the whole pull, so a player can
			# see what they are being pulled to before they get there, and the rope
			# itself is redrawn as the body travels (`_travel_marks`).
			var hold_for := maxf(READ_SECONDS, float(args.get("seconds", 0.0)))
			MobFx.bracket(game, game.world.to_3d(to) + Vector3(0, 0.6, 0), Palette.LENS[3], 1.2, hold_for, seed_value)
			MobFx.ring(game, game.world.to_3d(to), Palette.LENS[2], 0.8, hold_for)
			_draw_line(from, to)
			_travel_at = TRAVEL_BEAT
			Events.sfx.emit(&"ability_grapple", at)
		&"spoof":
			# Their own signature going out of you: a clean violet ring and a
			# lens flare at the head, exact, nothing hatched.
			Events.sfx.emit(&"ability_spoof", at)
			MobFx.ring(game, at, Palette.FOUND[3], 1.7, 0.9)
			MobFx.glint(game, at + Vector3(0, 1.35, 0), Palette.LENS[3], seed_value, 0.6)
			for i in 3:
				var a := i * TAU / 3.0
				MobFx.glint(game, at + Vector3(cos(a) * 0.6, 0.8, sin(a) * 0.6), Palette.FOUND[4], seed_value + i * 3, 0.3)
			_spoof_at = Time.get_ticks_msec() / 1000.0 + SPOOF_BEAT
		&"spoof_beat":
			# While it stands, one glint on a slow beat: you are still wearing
			# someone else's name, and you can see it.
			var now := Time.get_ticks_msec() / 1000.0
			if now >= _spoof_at:
				_spoof_at = now + SPOOF_BEAT
				MobFx.glint(game, at + Vector3(0, 1.35, 0), Palette.FOUND[4], seed_value, 0.26)
		&"spoof_ended":
			Events.message.emit("They can read you again.")
			MobFx.ring(game, at, Palette.FOUND[1], 1.0, 0.35)


## A scan's read: the working part of every machine in reach framed by a ruled
## bracket in the lens's own light, and a flicked ink mark over the ones that have
## noticed you (the interference the disposition package keeps; until it lands,
## aware is the read). The bracket is FOUND: clean, ruled, exact, and HELD -- it
## is laid again just before the last one dies so it tracks a walking machine
## while reading as one steady frame. Stippling it would say fire (docs/LOOK.md).
## The reading of their behaviour is the player's own, and that is drawn by hand.
## A mark is held a quarter longer than the beat that lays it, so the next one is
## on screen before the last one goes and the read never blinks.
func _hold_for(args: Dictionary) -> float:
	return maxf(READ_SECONDS, float(args.get("beat", 0.45)) * 1.25)


func _scan_marks(reach: float, opening: bool) -> void:
	# One ability's mark at a time -- but only while the body is being THROWN. A
	# scan laying brackets through a dash or a pull stacks two marks on the same
	# thirty pixels of screen and neither is readable (wave A2, art finding 3);
	# a glide is six seconds long, and six seconds with no brackets is a scan
	# that has quietly stopped working. So the brackets stand down for the fifth
	# of a second a throw lasts, and the tell over a machine that has NOTICED YOU
	# never stands down at all: that is the one read a player in the air needs.
	var thrown := _motion != null and THROWN.has(_motion.kind)
	var p := game.player.pos
	var up := game.camera.global_transform.basis.y if game.camera.is_inside_tree() else Vector3.UP
	var found: Array[Mob] = []
	for m: Node in get_tree().get_nodes_in_group(&"mobs"):
		var mob := m as Mob
		if mob == null or not mob.alive or mob.state == null or not mob.state.machine:
			continue
		if mob.pos.distance_to(p) <= reach:
			found.append(mob)
	found.sort_custom(func(a: Mob, b: Mob) -> bool: return a.pos.distance_to(p) < b.pos.distance_to(p))
	var now := Time.get_ticks_msec() / 1000.0
	var tell_due := now >= _aware_at
	if tell_due:
		_aware_at = now + AWARE_BEAT
	for i in mini(found.size(), SCAN_MOST):
		var mob := found[i]
		if not thrown:
			MobFx.bracket(game, mob.part_position(), Palette.LENS[3], 0.9, _read_for, mob.get_instance_id())
			if opening:
				MobFx.ring(game, game.world.to_3d(mob.pos), Palette.LENS[2], mob.state.radius + 0.5, 0.5)
		if mob.aware and tell_due:
			MobFx.tell(game, mob.screen_top(up), up, AWARE_BEAT, mob.get_instance_id() + 3, 0.7)


# --- the slate's gear page -----------------------------------------------------

func _feed(_g: Game) -> Dictionary:
	var rows: Array[Dictionary] = []
	for s in Gear.SLOTS:
		var mods: Array[Dictionary] = []
		for m in loadout.modules(s):
			mods.append({"id": m, "name": UiRules.item_name(m), "grants": _grants(m)})
		rows.append({"id": s, "label": Gear.label(s), "item": loadout.item(s),
			"sockets": Gear.sockets(loadout.item(s)), "modules": mods})
	# What the gear gives, and not what the legs do: the page is about what is worn.
	var abilities := book.rows(Time.get_ticks_msec() / 1000.0).filter(
		func(r: Dictionary) -> bool: return not Abilities.INNATE.has(r.id))
	# The body the page draws: the same look the world puts on the player.
	var figure := {"look": worn_look(), "held": game.inventory.held, "wing": GearLook.wing(loadout)}
	return {"slots": rows, "resist": game.body.resist, "abilities": abilities, "figure": figure}


## What a module gives, in the few characters the page has room for. A modifier
## says the DECISION it changes and the price it is paying in this kit, because a
## row of resistance percentages never told anybody what a part was for
## (`ModifierTable`, docs/VISION.md).
func _grants(id: StringName) -> String:
	if ModifierTable.has(id):
		return Modifiers.note(id, loadout.all_ids())
	var a := Gear.ability_of(id)
	if a != &"":
		return String(a)
	var out := PackedStringArray()
	var r := Gear.resist_of(id)
	var keys: Array = r.keys()
	keys.sort_custom(func(x: Variant, y: Variant) -> bool: return String(x) < String(y))
	for k: Variant in keys:
		out.append("%s %d" % [String(k).replace("_", " "), roundi(float(r[k]) * 100.0)])
	return " ".join(out)


## One key fits the whole slot, in the order a player wants it: put something on,
## then fill its sockets, then swap it for the next thing carried, then take it
## off. Every step says what happened, so the page teaches itself.
func _act(_g: Game, row_id: StringName) -> String:
	if not Gear.SLOTS.has(row_id):
		return "!Nothing fits there."
	var slot: StringName = row_id
	var here := loadout.item(slot)
	# The hand is the inventory's: what is held is chosen in carrying, and the only
	# thing this page does to it is bind something to the haft and take it off again.
	if slot == Gear.HAND_SLOT:
		return _act_hand(here)
	if here == &"":
		var first := _spare_pieces(slot)
		if first.is_empty():
			if Gear.wearables_for(slot).is_empty():
				return "!Nothing in the world fits there yet."
			return "!You carry nothing for that."
		loadout.fit(slot, first[0])
		return "%s on." % UiRules.item_name(first[0]).capitalize()
	var mod := _spare_module(slot)
	if mod != &"":
		loadout.socket(slot, mod)
		return "%s socketed." % UiRules.item_name(mod).capitalize()
	var next := _next_piece(slot, here)
	if next == &"":
		var broke := _pull_modules(slot)
		loadout.clear_slot(slot)
		return "Off." if broke == "" else "Off. %s" % broke
	loadout.fit(slot, next)
	return "%s on." % UiRules.item_name(next).capitalize()


## The hand's own row: bind what is carried to the haft, then unbind it. Swapping
## the tool itself is carrying's job, so this never offers to, and never answers
## about pieces that could not go there anyway.
func _act_hand(here: StringName) -> String:
	if here == &"":
		return "!Your hand is empty; choose a tool in carrying."
	var held_name := UiRules.item_name(here)
	if loadout.free_sockets(Gear.HAND_SLOT) > 0:
		var mod := _spare_module(Gear.HAND_SLOT)
		if mod != &"":
			loadout.socket(Gear.HAND_SLOT, mod)
			return "%s bound to the %s." % [UiRules.item_name(mod).capitalize(), held_name]
		return "!Nothing you carry binds to a %s." % held_name
	if not loadout.modules(Gear.HAND_SLOT).is_empty():
		var broke := _pull_modules(Gear.HAND_SLOT)
		loadout.clear_slot(Gear.HAND_SLOT)
		return "Unbound." if broke == "" else "Unbound. %s" % broke
	return "!A %s takes no binding." % held_name


## Taking a slot off pulls its modules out, and where you are standing decides
## whether they survive it (`Reforge`, docs/VISION.md: re-socketed at a
## bench, at the risk of losing the part). Cord unties anywhere; a panel drilled
## into a frame is being prised with the wrong tool out in the field. So a player
## either plans the build at a bench or gambles on the road.
func _pull_modules(slot: StringName) -> String:
	var at_bench := Survival.stations_near(game).has(&"bench")
	var broke := PackedStringArray()
	for m in loadout.modules(slot):
		_pulls += 1
		if Reforge.survives(m, at_bench, game.world.seed_value, _pulls):
			continue
		game.inventory.remove(m)
		broke.append(Reforge.broke_line(m))
	if broke.is_empty():
		return ""
	Events.sfx.emit(&"work_broken", game.player.position)
	return " ".join(broke)


## Pieces for this slot that are carried and not already fitted somewhere.
func _spare_pieces(slot: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in Gear.wearables_for(slot):
		if game.inventory.count(id) > loadout.fitted_count(id):
			out.append(id)
	return out


func _spare_module(slot: StringName) -> StringName:
	if loadout.free_sockets(slot) <= 0:
		return &""
	var ids: Array[StringName] = []
	for id: StringName in Items.DEFS:
		if Gear.is_module(id) and Gear.fits(id, slot):
			ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id in ids:
		if game.inventory.count(id) > loadout.fitted_count(id):
			return id
	return &""


## The next carried piece after the one fitted, or &"" to take it off.
func _next_piece(slot: StringName, here: StringName) -> StringName:
	var all := Gear.wearables_for(slot)
	var i := all.find(here)
	for k in range(i + 1, all.size()):
		var id := all[k]
		if game.inventory.count(id) > loadout.fitted_count(id):
			return id
	return &""


# --- boot, saving, tours -------------------------------------------------------

## --fit=ID,ID puts gear on for a shot or a tour: each piece into its own slot,
## each module into the first slot it fits, and anything not carried is given.
func _fit_from_options() -> void:
	for raw in game.options.fit:
		var id := StringName(String(raw).strip_edges())
		if Items.def(id).is_empty():
			push_warning("--fit: unknown item %s" % id)
			continue
		if game.inventory.count(id) <= loadout.fitted_count(id):
			game.inventory.add(id)
		if Gear.is_module(id):
			for s in Gear.SLOTS:
				if Gear.fits(id, s) and loadout.free_sockets(s) > 0 and loadout.socket(s, id):
					break
		else:
			loadout.fit(Gear.slot_of(id), id)


func tour_seen(what: StringName) -> bool:
	var s := String(what)
	if s.begins_with("ability:"):
		return _fired.has(StringName(s.substr(8)))
	if s.begins_with("jumped:"):
		return _jumped.has(StringName(s.substr(7)))
	if s.begins_with("worn:"):
		return _worn(StringName(s.substr(5)))
	match what:
		&"jumping": return _motion != null and _motion.kind == &"jump"
		&"jumped": return _jumped.has(&"")
		&"gliding": return _gliding
		&"ability": return not _fired.is_empty()
		&"spoofed": return AbilitySpoof.spoofed(game.body, game.clock.minutes)
		&"unnoticed": return _unnoticed()
		&"resisting": return not game.body.resist.is_empty()
	return false


## `id` is fitted AND the figure walking the coast has every piece of it on: the
## gear page draws that same look, so this is what a frame of the page is of.
func _worn(id: StringName) -> bool:
	if loadout.fitted_count(id) <= 0 or game.player == null or game.player.model == null:
		return false
	var look := game.player.model.look
	for piece: String in GearLook.pieces(id):
		var kv := piece.split(":")
		match kv[0]:
			"hat", "coat":
				if String(look[kv[0]]) != kv[1]:
					return false
			"extras", "salvage", "gear":
				if not (look[kv[0]] as Array).has(StringName(kv[1])):
					return false
	return true


## The sentence a spoof is for, proved rather than asserted: a machine standing
## close enough to have read the body has not. The flag alone (`spoofed`) says
## only that the signet fired.
func _unnoticed() -> bool:
	if not AbilitySpoof.spoofed(game.body, game.clock.minutes):
		return false
	var near := false
	for m: Node in get_tree().get_nodes_in_group(&"mobs"):
		var mob := m as Mob
		if mob == null or not mob.alive or mob.state == null or not mob.state.machine:
			continue
		if mob.pos.distance_to(game.player.pos) > SPOOF_PROOF_REACH:
			continue
		if mob.aware:
			return false
		near = true
	return near


func _save() -> Variant:
	return {"loadout": loadout.save(), "cooldowns": book.save(Time.get_ticks_msec() / 1000.0),
		"pulls": _pulls}


func _load(v: Variant) -> void:
	if not (v is Dictionary):
		return
	loadout.load_from((v as Dictionary).get("loadout", {}))
	loadout.hold(game.inventory.held)
	book.load_from((v as Dictionary).get("cooldowns", {}), Time.get_ticks_msec() / 1000.0)
	_pulls = SaveCodec.to_int((v as Dictionary).get("pulls", 0))
	_refit()
