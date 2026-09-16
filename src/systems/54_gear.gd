extends GameSystem
## The gear on the body and the abilities it grants (docs/VISION.md §6, §7.4).
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

## Marks along a grapple line, and how long the line hangs.
const LINE_MARKS := 7
const LINE_SECONDS := 0.28
## Machines a scan will mark at once: the nearest few, so a works district does
## not fill the frame with light.
const SCAN_MOST := 6
## Seconds between the ink marks over a machine that has noticed you.
const AWARE_BEAT := 0.5
## Seconds between the violet glints that say you are still wearing their name.
const SPOOF_BEAT := 1.5
## A body that moves further than this between two frames of a motion was put
## there by something else: the motion gives way to it.
const JUMPED := 3.0

var loadout := Loadout.new()
var book := AbilityBook.new()
var _motion: AbilityMotion = null
var _wing: GlideWingModel = null
## Ability ids that have fired in this game, for the tour's awaits.
var _fired: Dictionary = {}
var _gliding := false
## Real seconds the next ink mark over an aware machine, and the next spoof
## glint, are due (the marks keep their own beat, not the frame rate's).
var _aware_at := 0.0
var _spoof_at := 0.0
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
	book.fit(Gear.abilities_of(loadout))


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
	# A refusal says why, quietly, and never while a fight is on the screen.
	Events.sfx.emit(&"ability_refused", game.player.position)
	if not Survival.threat_near(game):
		Events.message.emit(Ability.refusal_line(why))


# --- the body moved by an ability ----------------------------------------------

func _start_motion(m: AbilityMotion) -> void:
	_motion = m
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
		# The line of a flight and the line of a pull are both drawn as they
		# happen: a mark of light lives a sixth of a second, so it is laid again
		# every frame the body is still travelling.
		var beat := int(Time.get_ticks_msec())
		if _motion.kind == &"glide":
			MobFx.glint(game, game.player.position + Vector3(0, 0.9, 0), Palette.PLATE[3], beat, 0.22)
		elif _motion.kind == &"grapple":
			MobFx.glint(game, game.player.position + Vector3(0, 0.7, 0), Palette.COLD[3], beat, 0.3)
	_last_pos = next
	if not _motion.finished:
		return
	game.player.lift = 0.0
	_land(_motion)
	_motion = null
	_last_pos = Vector2.INF


func _land(m: AbilityMotion) -> void:
	if m.kind == &"glide":
		_gliding = false
		if _wing != null:
			_wing.set_open(false)
		MobFx.puffs(game, game.player.position, m.dir, Palette.STONE[4], 3, 0.55, int(Time.get_ticks_msec()))
		Events.sfx.emit(&"ability_land", game.player.position)
	elif m.kind == &"grapple":
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


# --- what an ability looks like ------------------------------------------------

## Every ability effect is drawn here, in ink and stipple for what a person
## made and clean and exact for what was taken from the machines (docs/ART.md §3).
func _fx(what: StringName, args: Dictionary) -> void:
	var at := game.player.position
	var seed_value := int(Time.get_ticks_msec())
	match what:
		&"dash":
			# Speed lines off the heels and a trail of stipple down the way it
			# came: the burst is drawn, never blurred (docs/ART.md §7).
			var dir: Vector2 = args.get("dir", Vector2.RIGHT)
			MobFx.streak(game, at + Vector3(0, 0.55, 0), dir, game.camera.yaw_deg, game.camera.pitch_deg, seed_value, 0.9)
			var dust := Palette.STONE[4]
			for i in 4:
				var back := Vector3(dir.x, 0.0, dir.y) * (-0.35 * (i + 1))
				MobFx.puff(game, at + back, -dir, dust, 0.34 - 0.04 * i, seed_value + i * 11)
			Events.sfx.emit(&"ability_dash", at)
		&"glide":
			Events.sfx.emit(&"ability_glide", at)
		&"scan":
			Events.sfx.emit(&"ability_scan", at)
			MobFx.ring(game, at, Palette.LENS[3], 1.6, 0.4)
			_aware_at = 0.0
			_scan_marks(float(args.get("reach", 20.0)), true)
		&"scan_beat":
			_scan_marks(float(args.get("reach", 20.0)), false)
		&"grapple":
			var from: Vector2 = args.get("at", game.player.pos)
			var to: Vector2 = args.get("to", from)
			# The line is light, not plate: drawn in the machines' own cold, so it
			# reads over any ground the land puts under it.
			for i in LINE_MARKS:
				var p := from.lerp(to, float(i + 1) / float(LINE_MARKS))
				MobFx.glint(game, game.world.to_3d(p) + Vector3(0, 0.7, 0), Palette.COLD[3], seed_value + i * 5, 0.34)
			MobFx.ring(game, game.world.to_3d(to), Palette.LENS[3], 0.7, LINE_SECONDS)
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


## A scan's read: the working part of every machine in reach held in the lens's
## own light, and a flicked ink mark over the ones that have noticed you (the
## interference the disposition package keeps; until it lands, aware is the read).
## The light is FOUND and exact; the reading of their behaviour is the player's
## own, and that is drawn by hand.
func _scan_marks(reach: float, opening: bool) -> void:
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
		MobFx.glint(game, mob.part_position(), Palette.LENS[3], mob.get_instance_id(), 0.3)
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
	return {"slots": rows, "resist": game.body.resist, "abilities": book.rows(Time.get_ticks_msec() / 1000.0)}


## What a module gives, in the few characters the page has room for.
func _grants(id: StringName) -> String:
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
	if slot == Gear.HAND_SLOT and here == &"":
		return "!Your hand is empty; choose a tool from carrying."
	if here == &"" or (slot == Gear.HAND_SLOT and loadout.free_sockets(slot) <= 0):
		var first := _spare_pieces(slot)
		if first.is_empty():
			return "!You carry nothing for that."
		loadout.fit(slot, first[0])
		return "%s on." % UiRules.item_name(first[0]).capitalize()
	var mod := _spare_module(slot)
	if mod != &"":
		loadout.socket(slot, mod)
		return "%s socketed." % UiRules.item_name(mod).capitalize()
	var next := _next_piece(slot, here)
	if next == &"":
		loadout.clear_slot(slot)
		return "Off."
	loadout.fit(slot, next)
	return "%s on." % UiRules.item_name(next).capitalize()


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
	match what:
		&"gliding": return _gliding
		&"ability": return not _fired.is_empty()
		&"spoofed": return AbilitySpoof.spoofed(game.body, game.clock.minutes)
		&"resisting": return not game.body.resist.is_empty()
	return false


func _save() -> Variant:
	return {"loadout": loadout.save(), "cooldowns": book.save(Time.get_ticks_msec() / 1000.0)}


func _load(v: Variant) -> void:
	if not (v is Dictionary):
		return
	loadout.load_from((v as Dictionary).get("loadout", {}))
	loadout.hold(game.inventory.held)
	book.load_from((v as Dictionary).get("cooldowns", {}), Time.get_ticks_msec() / 1000.0)
	_refit()
