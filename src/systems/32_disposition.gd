extends GameSystem
## Roles, indifference, interference and stealth, wired into the running game
## (docs/VISION.md and the pillar "live in the gaps").
##
## It does four things, and nothing else may:
##   1. tells the simulation what the player is doing about being noticed:
##      crouched (the crouch key), what they are standing in (Cover), how loud
##      they are (StealthNoise), whether their signature reads as one of the
##      machines' own (Body.spoof_until). The Moment carries it; StealthQuery
##      is the only thing that reads it.
##   2. keeps the interference of every plan network: theft, sabotage, a dead
##      worker, a filing and a broken curfew raise it; time, distance, hiding
##      and a spoofed signature let it fall. Saved.
##   3. writes each live body's disposition from its role and the interference
##      where it stands, and puts it on the model, whose status lamps blink it.
##      As a region heats, workers that walked past you stop working and come.
##   4. lets the world say so without a word of UI: a machine's optics turn to
##      the last noise, its working part flickers with its suspicion, watchers
##      turn toward you when the network files something, a horn goes off at a
##      works, and at the top of the scale the network sends hunters.

## The crouch key is held, not toggled (project.godot: Left Ctrl, Q).
const CROUCH_ACTION := &"crouch"
## Cover is read again when the player has moved this far, or this often (s).
const COVER_STEP := 0.35
const COVER_EVERY := 0.3
## Dispositions are written this often (s): a region heating is felt in a
## breath, not on the frame.
const APPLY_EVERY := 0.25
## A job on a prop makes its noise this often (s): a player hammering a mast is
## heard, and keeps being heard.
const WORK_NOISE_EVERY := 0.7
## How far a rise in interference is felt: watchers within this turn toward the
## player, and the horn is heard from a works this far off.
const FELT_RADIUS := 44.0
## World minutes between hunters the network sends while it is hunted, and how
## many of them may be out at once. The budget is what makes being hunted a
## thing a player can come out the other side of: kill what was sent, break
## contact, and the file cools (Interference.UNSEEN_DECAY) faster than the next
## one can be raised.
const DISPATCH_EVERY := 90.0
const DISPATCH_AT_ONCE := 2
## Where a dispatched hunter comes out (tiles from the player).
const DISPATCH_RING := 19.0
## Machines this near a theft take it personally.
const THEFT_RADIUS := 22.0
## Tiles round the post a keeper holds that the plan counts as its site: stand
## inside one where the keeper can see you and you are trespassing.
const SITE_RADIUS := 7.0
## The horn a works sounds when its network files something (SoundNames).
const HORN := &"works_horn"

var interference := Interference.new()
var sim: FightSim
var _cover := 0.0
var _cover_at := Vector2(INF, INF)
var _cover_left := 0.0
var _cover_lamp := false
var _cover_crouched := false
var _apply_left := 0.0
var _work_left := 0.0
var _last_minutes := 0.0
var _stealing: int = -1
## The seam being worked, so a region being stripped is filed once per seam and
## not once a frame. Kept apart from `_stealing` because one is the plan's own
## works and the other is the land's, and they are different sentences.
var _quarrying: int = -1
var _dispatch_at := -INF
var _felt_level := 0
## Body.filed as this system last saw it (a clerk that got away raises it).
var _filed_seen := 0
## What the tour has been shown (tour_seen).
var _seen: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	sim = g.player.sim
	Events.killed.connect(_on_killed)
	Events.fight_ended.connect(_on_fight_ended)
	Events.took.connect(_on_took)
	Events.made.connect(_on_made)
	Events.hit.connect(_on_hit)
	Events.works_broken.connect(_on_plant_lost)
	Events.sentinel_fell.connect(_on_keeper_fell)
	# The fourth thing that can change a chapter; the other three are above.
	Events.landmark_found.connect(_on_landmark_found)
	SaveGame.register(&"disposition", _save, _load)
	SlateFeeds.provide(&"reads", _reads)
	_resync()
	_read_player()
	_apply_dispositions()


## The clock, the body and the player's place are only restored in started()
## (05_save applies a loaded game after every setup). Everything this system
## holds ABOUT them has to be taken again here, or the first frame of a loaded
## game decays a whole saved file away, files the player for a clerk that read
## them before the save, and blows the horn over it.
func started() -> void:
	_resync()


func _resync() -> void:
	_last_minutes = game.clock.minutes
	_filed_seen = game.body.filed
	_felt_level = interference.level(Interference.network(game.world, sim.hero.pos))
	# A game loaded into a hot region gets the same grace as one that just
	# heated up: nothing is sent on the frame it opens.
	_dispatch_at = game.clock.minutes if _felt_level >= 3 else -INF


func _save() -> Variant:
	return interference.save()


func _load(v: Variant) -> void:
	if v is Dictionary:
		interference.load(v)
	_resync()
	_apply_dispositions()


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	_read_player()
	_cool(delta)
	_work_noise(delta)
	_apply_left -= delta
	if _apply_left <= 0.0:
		_apply_left = APPLY_EVERY
		_filed()
		_curfew()
		_trespass()
		_turned()
		_apply_dispositions()
		_felt(sim.now)
		_dispatch()


# --- 1. what the player is doing about being noticed --------------------------

## The crouch key, the cover the player is standing in, how loud they are, and
## whether the machines are reading them as one of their own. Written onto the
## Moment every frame, because every one of them can change every frame.
func _read_player() -> void:
	var body := game.body
	var m := sim.moment
	var hero := sim.hero
	# Held, or pressed once and left on: the player's own rule for this key
	# (PlayerSettings, playing.crouch).
	body.crouched = HoldToggle.on(CROUCH_ACTION, &"playing.crouch") and not game.input_blocked()
	game.player.model.crouched = body.crouched
	m.crouched = body.crouched
	m.spoofed = game.clock.minutes < body.spoof_until
	var p := hero.pos
	var ground := game.world.ground_at(floori(p.x), floori(p.y))
	m.loudness = StealthNoise.loudness(hero.speed, ground, body.crouched, m.laden_tier)
	m.cover = _cover_now(p, m)
	m.interference = interference.value(Interference.network(game.world, p))


func _cover_now(p: Vector2, m: Moment) -> float:
	_cover_left -= get_physics_process_delta_time()
	# The lamp and the crouch are the player's own doing: they take effect on the
	# frame they happen, never on the next look round.
	var same := m.lamp_lit == _cover_lamp and m.crouched == _cover_crouched
	if same and _cover_left > 0.0 and p.distance_to(_cover_at) < COVER_STEP:
		return _cover
	_cover_left = COVER_EVERY
	_cover_at = p
	_cover_lamp = m.lamp_lit
	_cover_crouched = m.crouched
	# The night, or a room's own dark where its light does not fall (21_doors
	# `room_dark`): whichever is darker.
	var dark := m.nightfall() * Senses.DARKEST
	for sys: GameSystem in game.systems:
		if sys.has_method(&"room_dark"):
			dark = maxf(dark, float(sys.call(&"room_dark", p)))
	_cover = Cover.at(game.world, game.query, p, m.crouched, dark, m.lamp_lit)
	return _cover


# --- 2. the interference of a plan network -----------------------------------

## What the player just did, filed against the network they did it in, and what
## it cost given who watched. Each system that puts people on the land answers
## `witnesses` for its own (35_folk), so this one goes on knowing nothing about
## villagers or crowds and a package that adds people needs no line here.
func raise(cause: StringName, at: Vector2, scale: float = 1.0) -> float:
	# The hours already gone by cool the file BEFORE the news lands on it. Left to
	# the next frame's `_cool`, a clock skipped just before this (the hours a
	# piece took to build, a night slept) was charged against the news itself,
	# and a turret built at a cost of two hours was forgotten the frame after.
	_cool(0.0)
	var net := Interference.network(game.world, at)
	var rose := interference.raise(net, cause, at, game.clock.minutes, crowd_witnesses(at), scale)
	if rose > 0.0:
		_seen[&"interference"] = true
	return rose


## People who can see a spot, over every system that puts any there. Named apart
## from the `witnesses(at, reach)` those systems answer on purpose: this gather
## would otherwise find itself in `game.systems` and call itself forever.
func crowd_witnesses(at: Vector2) -> int:
	var n := 0
	for sys in game.systems:
		if sys.has_method(&"witnesses"):
			n += int(sys.call(&"witnesses", at, Interference.WITNESS_REACH))
	return n


## Time, distance, hiding and a misread signature. A player crouched in cover
## that nothing is looking for is forgotten about faster than one in the open.
func _cool(delta: float) -> void:
	var minutes := game.clock.minutes
	var passed := minutes - _last_minutes
	_last_minutes = minutes
	if passed <= 0.0:
		return
	var m := sim.moment
	var unseen := not _anything_aware()
	var hidden := m.crouched and m.cover > 0.4 and unseen
	interference.decay(passed / 60.0, hidden, m.spoofed,
		Interference.network(game.world, sim.hero.pos), sim.hero.pos, unseen)


## A clerk that got its reading away files the player (Body.filed, which is also
## what makes every machine see further). The network hears about it too.
func _filed() -> void:
	var n := game.body.filed
	if n <= _filed_seen:
		_filed_seen = n
		return
	_filed_seen = n
	raise(&"filed", sim.hero.pos)


## Out in the hours a keeper holds, and it has you: the keeper takes it amiss
## itself (Roles.TURNS), and the network files the curfew whether or not the
## keeper is the sort that turns.
func _curfew() -> void:
	var hour := sim.moment.hour()
	for m in sim.mobs:
		if not m.alive or m.removed or m.role != Roles.KEEPER:
			continue
		if not (m.roused() or m.mood == MobState.ALERTED or m.suspicion >= 1.0):
			continue
		var hours: Array = m.row.get("where", {}).get("hours", [])
		if hours.size() == 2 and Spawner.hour_in(hour, float(hours[0]), float(hours[1])):
			sim.disturb(m, &"curfew")
			# The keeper's own network, so this and the `_turned` report a keeper
			# that takes it amiss also makes are one file and not two.
			raise(&"curfew", m.home)
			return


## Standing on the site a keeper holds, where it can see you. The keeper turns
## on you; `_turned` is what files it against the network.
func _trespass() -> void:
	for m in sim.mobs:
		if not m.alive or m.removed or m.disturbed or m.role != Roles.KEEPER:
			continue
		if m.suspicion < 1.0 or sim.hero.pos.distance_to(m.home) > SITE_RADIUS:
			continue
		sim.disturb(m, &"trespass")
		if m.disturbed:
			_seen[&"trespass"] = true
			return


## A body that has just turned on the player reports what it took amiss, which
## is the one door every cause of the plan's own making goes through: blocked,
## trespass, curfew, theft, a blow. One report per body.
##
## **A BODY REPORTS TO ITS OWN NETWORK, WHICH IS WHERE IT WAS PUT OUT AND NOT
## WHERE ITS FEET HAPPEN TO BE.** This filed at `m.pos`, so the same offence went
## to a different file depending on how far along its round the body had walked:
## a keeper whose post is one region and whose body is three tiles over the
## border reported the trespass to the region it was standing in, which for a run
## too small to be a place is not a plan network at all (`Interference.network`
## answers `REGIONLESS - country` there, and nothing in that key runs anything).
## Worse, `_trespass` measures the offence against `m.home` — the post — so one
## event was weighed at the post and filed at the feet. Measured on seed 1 at
## size 128: post in region 0, body in network -12, and the test asking the
## player's own network found nothing. It also double-filed a curfew, which
## `_curfew` deliberately files itself: two networks means `SAME_CAUSE_GAP` never
## sees the second one.
func _turned() -> void:
	for m in sim.mobs:
		if not m.alive or m.removed or not m.disturbed or m.turn_filed:
			continue
		m.turn_filed = true
		if m.disturbed_by != &"":
			raise(m.disturbed_by, m.home)


func _anything_aware() -> bool:
	for mob in sim.mobs:
		if mob.alive and not mob.removed and (mob.roused() or mob.suspicion > 0.5):
			return true
	return false


## A body the network sent after the player is no news to the network that sent
## it: it already spent that. Anything else it loses is filed.
func _on_killed(kind: StringName, at: Vector3) -> void:
	if not Roster.row(kind).get("machine", false):
		return
	var p := Vector2(at.x, at.z)
	sim.make_noise(p, StealthNoise.radius(&"kill", game.world.ground_at(floori(p.x), floori(p.y)), false, 0))
	var s := _body_at(kind, p)
	if s != null and s.sent:
		return
	raise(&"killed_worker" if Roles.of(kind) == Roles.WORKER else &"killed_machine", p)


## Put down or carried off: the network where it happened files it (Interference
## `downed`). Emitted before a carry moves the player, so this is where it was.
func _on_fight_ended(outcome: StringName) -> void:
	if outcome == &"downed" or outcome == &"carried":
		raise(&"downed", sim.hero.pos)


## The body that just went down at `p`, while the simulation still holds it.
func _body_at(kind: StringName, p: Vector2) -> MobState:
	for m in sim.mobs:
		if not m.alive and m.kind == kind and m.pos.distance_squared_to(p) < 0.01:
			return m
	return null


## Taking is heard. Taking from the machines' own works is theft, and every
## worker near enough turns on whoever is stripping their plan (VISION §2).
func _on_took(_item: StringName, _count: int) -> void:
	_noise(&"work")
	_asking_dirty = true


func _on_made(_item: StringName, _count: int) -> void:
	_noise(&"make")


## A REGION WHOSE PLAN HAS LOST ITS PLANT. Both of these were emitted for a whole
## wave with nothing listening, so putting a depot out or bringing a keeper down
## changed the yard and changed nothing about how the region READ the player: it
## could still work itself up to hunted and send bodies out of a dark yard.
##
## Now the file on that region is capped under hostile for good and cools at
## `Interference.LOST_DECAY`. The region is not safe — what is standing in it is
## still standing — but nothing in it can pick a hunter and send it.
func _on_plant_lost(region: int, _land: StringName) -> void:
	interference.lose(region)
	_apply_dispositions()
	_asking_dirty = true


func _on_keeper_fell(region: int, _land: StringName, _how: StringName) -> void:
	interference.lose(region)
	_apply_dispositions()
	_asking_dirty = true


## A blow the player struck. `Events.hit` carries NODES, not fighters: the
## target of a blow on a machine is its Mob. Damage to a machine that was going
## about the plan's work is sabotage; a blow thrown in a fight the machines
## started is not, or defending yourself from what was sent after you would
## file you for it and the hunt could never end.
func _on_hit(attacker: Object, target: Object, _damage: int, plate: bool, at: Vector3) -> void:
	# The player's own blow is as loud as their kit makes it (FightKit.blow_noise).
	var heavy := sim.hero.blow != null and sim.hero.blow.heavy
	_noise(&"hit", sim.hero.kit.blow_noise(plate, heavy) if attacker == game.player else 1.0)
	if attacker != game.player:
		return
	var mob := target as Mob
	if mob == null or mob.state == null or not mob.state.machine:
		return
	var s := mob.state
	if s.sent or s.disturbed or s.roused() or Disposition.hostile(s.disposition):
		return
	raise(&"sabotage", Vector2(at.x, at.z))


func _noise(act: StringName, scale: float = 1.0) -> void:
	var p := sim.hero.pos
	var ground := game.world.ground_at(floori(p.x), floori(p.y))
	sim.make_noise(p, StealthNoise.radius(act, ground, game.body.crouched, sim.moment.laden_tier) * scale)


## A job under way is a noise that keeps going, and a job on the plan's own
## works is a theft the network files once.
func _work_noise(delta: float) -> void:
	var job := SurvivalState.of(game).job
	if job.is_empty():
		_stealing = -1
		_quarrying = -1
		return
	var prop: WorldProp = job.get("prop")
	_work_left -= delta
	if _work_left <= 0.0:
		_work_left = WORK_NOISE_EVERY
		var verb: StringName = (job.get("option", {}) as Dictionary).get("verb", &"work")
		_noise(verb if StealthNoise.ACTS.has(verb) else &"work")
	if prop == null:
		return
	# The land's own seams are not the plan's works, and taking one is not theft —
	# but a region being stripped is a resource the plan surveyed going away, and
	# it files that. Once per prop, like a theft, so leaning on one seam for a
	# minute is one filing and not sixty.
	if prop.id != _quarrying and Chapter.ore_kinds(game.world, game.world.region_at(floori(prop.pos.x), floori(prop.pos.y))).has(prop.kind):
		_quarrying = prop.id
		raise(&"quarried", prop.pos)
	if prop.id == _stealing or not Takes.is_plan_work(prop.kind):
		return
	_stealing = prop.id
	_theft(prop)


## Hands on the plan's own parts. A work of the plan is wired to whatever serves
## it: opening one tells them, whether or not anything was looking. So the
## network files it and every machine near enough whose role takes it amiss
## stops working and turns, hill or no hill between.
func _theft(prop: WorldProp) -> void:
	raise(&"theft", prop.pos)
	_seen[&"theft"] = true
	var turned := 0
	for m in sim.mobs:
		if not m.alive or m.removed or not m.machine:
			continue
		if Senses.chebyshev(m.pos, prop.pos) > THEFT_RADIUS:
			continue
		sim.disturb(m, &"theft")
		if m.disturbed:
			turned += 1
			m.last_seen = sim.hero.pos
			m.heard_at = sim.hero.pos
	if turned > 0:
		# Their lamps change on the frame they turn, not on the next round of reads.
		_apply_dispositions()
		Events.sfx.emit(&"alert", game.world.to_3d(prop.pos))


# --- 3. what each body makes of the player ------------------------------------

## A body's disposition is its role, plus the interference where it stands,
## plus what the player has done to it. The model's status lamps blink it.
func _apply_dispositions() -> void:
	for m in sim.mobs:
		if not m.alive or m.removed or not m.machine:
			continue
		var lvl := interference.level(Interference.network(game.world, m.pos))
		var want := Disposition.of(m.role, lvl, m.disturbed)
		if want != m.disposition:
			m.disposition = want
		if m.node is Mob:
			var model := (m.node as Mob).model as MachineModel
			if model != null and model.disposition != want:
				model.disposition = want


# --- 4. the world says so, in the world ---------------------------------------

## A network that has just been filed is felt without a word: the watchers
## still about turn their optics onto the player, and a horn goes off at a
## works over the land.
func _felt(now: float) -> void:
	var net := Interference.network(game.world, sim.hero.pos)
	var lvl := interference.level(net)
	if lvl == _felt_level:
		return
	var rising := lvl > _felt_level
	_felt_level = lvl
	if not rising:
		return
	_seen[&"felt"] = true
	for m in sim.mobs:
		if not m.alive or m.removed or Roles.of_row(m.row) != Roles.WATCHER:
			continue
		if Senses.chebyshev(m.pos, sim.hero.pos) > FELT_RADIUS:
			continue
		m.heard_at = sim.hero.pos
		m.look_until = now + FightSim.LOOK_MS
		m.suspicion = maxf(m.suspicion, 0.5)
	# Off over the land, where the works are: a long way off, and about you.
	var away := Vector2.from_angle(GenWorks.bearing(game.world.seed_value)) * FELT_RADIUS
	Events.sfx.emit(HORN, game.world.to_3d(sim.hero.pos + away))


## At the top of the scale the network stops waiting for the player to walk
## into something and sends a hunter after them.
func _dispatch() -> void:
	if interference.level(Interference.network(game.world, sim.hero.pos)) < 3:
		return
	if game.clock.minutes - _dispatch_at < DISPATCH_EVERY:
		return
	if _sent_out() >= DISPATCH_AT_ONCE:
		return
	var kind := _hunter_for_here()
	if kind == &"":
		return
	var spot := _spot_for(kind)
	if spot == Vector2.INF:
		return
	_dispatch_at = game.clock.minutes
	var m := sim.add_mob(kind, spot)
	m.last_seen = sim.hero.pos
	m.suspicion = 1.0
	m.sent = true
	_seen[&"hunter"] = true


## How many of the network's own are still out after the player. A network that
## is barely functioning cannot pour bodies at one person for ever, and a player
## who kills what was sent has to be able to break contact and cool the file.
func _sent_out() -> int:
	var n := 0
	for m in sim.mobs:
		if m.sent and m.alive and not m.removed:
			n += 1
	return n


func _hunter_for_here() -> StringName:
	var best: StringName = &""
	for kind: StringName in Roster.kinds():
		var row := Roster.row(kind)
		if not row.get("machine", false) or Roles.of_row(row) != Roles.HUNTER:
			continue
		if row.get("approach", &"") == &"dart":
			continue
		if not Spawner.moment_fits(row, sim.moment):
			continue
		best = kind
		break
	return best


## Where a sent hunter comes out. Its own country and ground first; failing
## that, anywhere it can stand: this one was sent, not rolled for, and the
## network sends it wherever the player is.
func _spot_for(kind: StringName) -> Vector2:
	var row := Roster.row(kind)
	var rng := Rng.make(game.world.seed_value, int(game.clock.minutes))
	var fallback := Vector2.INF
	for i in 32:
		var a := rng.randf() * TAU
		var p := sim.hero.pos + Vector2.from_angle(a) * DISPATCH_RING
		var tx := floori(p.x)
		var ty := floori(p.y)
		if not game.query.standable(tx, ty) or Ground.is_water(game.world.ground_at(tx, ty)):
			continue
		if Spawner.place_fits(row, game.world, game.query, tx, ty):
			return p
		if fallback == Vector2.INF:
			fallback = p
	return fallback


# --- the slate's machine reads -------------------------------------------------

## The reads app: what the network makes of the player, and what every machine
## in range makes of them (SlateFeeds).
## The plan's own note on the region the player is standing in, for the reads
## app (docs/VISION.md). KEPT rather than asked every frame: `Chapters.of`
## sweeps `game.systems` three times, and an open page is a page drawn every
## frame — which is the exact shape that took play to 5-12 fps when `24_holds`
## asked it once per hold (#122). Only four things can change a chapter and this
## file hears all four, so an idle frame costs nothing, which no timer manages.
var _asking := ""
var _asking_region := -2
var _asking_dirty := true


func _on_landmark_found(_id: StringName, _land: StringName, _at: Vector2) -> void:
	_asking_dirty = true


func _reads(_g: Game) -> Dictionary:
	var net := Interference.network(game.world, sim.hero.pos)
	if _asking_dirty or net != _asking_region:
		_asking_region = net
		_asking_dirty = false
		_asking = Chapter.asking(Chapters.of(game, net))
	var scans: Array = []
	for m in sim.mobs:
		if not m.alive or m.removed or not m.machine:
			continue
		if Senses.chebyshev(m.pos, sim.hero.pos) > SlateFeeds.READ_RADIUS:
			continue
		scans.append({"id": StringName("m%d" % m.id), "kind": m.kind, "name": String(m.kind),
			"pos": m.pos, "disposition": m.disposition, "note": _note(m)})
	return {"interference": interference.value(net),
		"network": _network_name(net), "scans": scans, "asking": _asking}


## What the slate calls the network the player is standing in. A region, so two
## snowfields in one world are two networks and read as different files: the
## second and later ones of a type are numbered so a player can tell them apart.
func _network_name(net: int) -> String:
	var r := game.world.region_of(net)
	if r.is_empty():
		return "unmapped network"
	var type := StringName(r.get("type", &""))
	var d := BiomeRegistry.get_def(type)
	var land := d.display_name if d != null else String(type)
	# `regions` runs biggest first, so counting the earlier regions of this type
	# numbers them the way a player would: the big snowfield, then snowfield 2.
	var nth := 0
	for other: Dictionary in game.world.regions:
		if int(other.get("id", -1)) == net:
			break
		if StringName(other.get("type", &"")) == type:
			nth += 1
	if nth <= 0:
		return "%s network" % land
	return "%s network %d" % [land, nth + 1]


func _note(m: MobState) -> String:
	if m.disturbed:
		return "it has taken something amiss"
	if m.roused():
		return "it has you"
	if m.suspicion >= 0.5:
		return "it is not sure"
	return String(m.role)


## Tour awaits: interference (a network rose), theft (hands on the plan's own
## parts), trespass (a keeper caught the player on its site), turned (a machine
## took it amiss), felt (a rise was felt in the world), hunter (one was sent),
## crouched, hidden (crouched in cover), suspicious (a machine is wondering),
## read (a machine is sure of the player).
func tour_seen(what: StringName) -> bool:
	match what:
		&"crouched":
			return game.body.crouched
		&"hidden":
			return sim.moment.crouched and sim.moment.cover > 0.4
		&"suspicious":
			for m in sim.mobs:
				if m.alive and not m.removed and m.suspicion > 0.0 and not m.roused():
					return true
			return false
		&"turned":
			for m in sim.mobs:
				if m.alive and not m.removed and m.disturbed:
					return true
			return false
		&"read":
			for m in sim.mobs:
				if m.alive and not m.removed and m.machine and (m.roused() or m.suspicion >= 1.0):
					return true
			return false
		&"network_hostile":
			# Live, not latched: the file the player is standing in has actually
			# reached hostile. `interference` only says something rose at all,
			# which a tour about what a CROWD costs cannot be proved by.
			return interference.level(Interference.network(game.world, sim.hero.pos)) >= 2
	return bool(_seen.get(what, false))


## An await is spent by the tour that asked it (98_tour `_forget`). The four
## above are computed from the live world and so are untouched by it; the five
## latched here (interference, theft, trespass, felt, hunter) are moments the
## world keeps no record of, and each is now answered once.
func tour_forget(what: StringName) -> void:
	_seen.erase(what)
