extends GameSystem
## The keeper a landscape has, in the running game (docs/VISION.md).
##
## Every region of a type whose file names a sentinel (`BiomeDef.sentinel`) has
## one, standing at that region's own works. This system does five things:
##   1. works out where each keeper stands and remembers what has been done to it
##      across the whole game (`SentinelState`, saved under `sentinels`);
##   2. puts its body out when the player comes near and lets the coast cull it
##      again when they leave, without ever losing its health or its phase;
##   3. drives its PHASES by rewriting the live body's own copy of its roster row,
##      so the fight, the senses and the enemy read under `z` all tell the truth
##      about what it is now without knowing what a sentinel is;
##   4. judges the three ways it can be taken (`SentinelWay`), which are pure
##      rules over a `SentinelLook` this system fills in;
##   5. when it falls, changes the region for good: its reach stops being held,
##      its table is rolled into the player's hands (src/core/loot), and what
##      killed it leaves a hulk in the land that is still there tomorrow.
##
## It owns no combat of its own. The one simulation (FightSim) fights it, and the
## body is drawn by the same Mob node every machine gets: a sentinel is a machine,
## only bigger, and everything that already reads a machine reads this one.

## A beacon per live keeper, in group &"sentinels" with `pos`, `reach`, `alive`
## and `land` on it: the contract the score reads (CLAUDE.md, the score row).
## `alive` is whether it still KEEPS the land, so a keeper that has stood down
## quiets the motif exactly as a dead one does.
class Beacon:
	extends Node3D
	var pos := Vector2.ZERO
	var reach := 26.0
	var alive := true
	var land: StringName = &""


var sim: FightSim
var _states: Array[SentinelState] = []
## Region id -> state, and MobState id -> the state whose body it is.
var _by_region: Dictionary = {}
var _bodies: Dictionary = {}
var _beacons: Dictionary = {}
var _judge_at := -INF
## What the tour has been shown.
var _seen: Dictionary = {}
## MobState id -> `blow_at` of the last bite a ground tell was drawn for, so a
## windup that lasts a second draws one ring and not sixty.
var _told: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	Sentinels.declare_loot()
	sim = g.player.sim
	_states = Sentinels.states(g.world)
	for s in _states:
		_by_region[s.region] = s
	SaveGame.register(&"sentinels", _save, _load)


func _physics_process(_delta: float) -> void:
	if sim == null:
		return
	_adopt()
	_put_out()
	_step()


# --- the body ---------------------------------------------------------------

## Any sentinel body in the simulation this system has not taken charge of yet —
## one it put out itself, or one a `--spawn`, a tour or dev mode put down. A
## keeper is a keeper however it arrived, so it is adopted rather than special
## cased, and a spawned one fights with its real phases.
func _adopt() -> void:
	for m in sim.mobs:
		if m.removed or _bodies.has(m.id):
			continue
		var design := Roster.sentinel_of(m.kind)
		if design == &"":
			continue
		var def := Sentinels.by_id(design)
		if def == null:
			continue
		var s := _state_for(def, m.pos)
		if s.fallen:
			# The region is already taken: whatever put this body down, it is not
			# the keeper any more. It stands and pays the player no attention.
			_stand_down(m)
			continue
		s.body = m
		_bodies[m.id] = s
		Sentinels.own_row(m)
		m.max_health = s.max_health
		m.health = s.health
		m.home = s.lair if s.lair.distance_to(m.pos) < 3.0 else m.pos
		s.ground_was = -1
		s.dark_since = INF
		s.spoof_since = INF
		_apply_phase(s, def, s.phase, false)
		_beacon_for(s, def)
		if not s.woken:
			s.woken = true
			Events.sentinel_woke.emit(s.region, s.land)
		_seen["sentinel_woke"] = true


## The state a body at `p` belongs to: its region's, or a loose one (region -1,
## never saved) for a keeper put down outside any region, so a gallery shot and a
## staged frame still get the real thing.
func _state_for(def: SentinelDef, p: Vector2) -> SentinelState:
	var region := game.world.region_at(floori(p.x), floori(p.y))
	var s: SentinelState = _by_region.get(region, null)
	if s != null and s.design == def.id:
		return s
	s = SentinelState.new()
	s.region = -1
	s.design = def.id
	s.land = def.land
	s.lair = p
	s.max_health = Roster.health_of(def.kind)
	s.health = s.max_health
	_states.append(s)
	return s


## Wake the keeper whose ground the player has walked onto. One at a time: two
## keepers within nineteen tiles of each other is not a thing a world holds.
func _put_out() -> void:
	var here := sim.hero.pos
	for s in _states:
		if s.fallen or s.body != null or s.region < 0:
			continue
		if Senses.chebyshev(s.lair, here) > Sentinels.PUT_OUT:
			continue
		var def := Sentinels.by_id(s.design)
		if def == null:
			continue
		var m := sim.add_mob(def.kind, s.lair)
		# Facing the way the player is coming from, so the first sight of it is
		# the side it keeps and not its back.
		m.facing = (here - s.lair).angle()
		m.aim = m.facing
		m.bearing = Vector2.from_angle(m.facing)
		# It stands its ground: a keeper does not walk a beat up and down.
		m.line_a = s.lair
		m.line_b = s.lair
		return


func _step() -> void:
	for s in _states:
		var def := Sentinels.by_id(s.design)
		if def == null:
			continue
		var m := s.body
		if m != null and not m.removed:
			s.health = m.health
			_phases(s, def, m)
			_ground_tell(s, def, m)
			if not m.alive and not s.fallen:
				_fell(s, def, def.way_of(SentinelWay.FORCE), m.pos)
			if s.fallen and not _kills(def, s.how):
				# Stood down: it goes on with its work and never notices the player again.
				_stand_down(m)
		elif m != null:
			# Culled, or its hulk has lain its time: what it has left is remembered.
			_leave(s, def, m)
		if s.fallen and not s.hulk_laid and def.hulk >= 0 and _kills(def, s.how):
			_lay_hulk(s, def)
		_beacon(s, def)
	if sim.now - _judge_at >= Sentinels.JUDGE_MS:
		_judge_at = sim.now
		_judge()


## Its phase is its body: the working side, the bite, the speeds and how fast it
## comes round. Entering one is announced BY THE BODY — the simulation's own
## `second_act`, which the fight system draws as a flare on the part, a ring and a
## shake — and never by a line of text (docs/VISION.md, "readable and fair").
func _phases(s: SentinelState, def: SentinelDef, m: MobState) -> void:
	var want := def.phase_at(m.health_fraction())
	if want == s.phase:
		return
	s.phase = want
	_apply_phase(s, def, want, true)
	Events.sentinel_phase.emit(s.region, def.phase(want).id)


func _apply_phase(s: SentinelState, def: SentinelDef, i: int, announce: bool) -> void:
	var m := s.body
	if m == null:
		return
	Sentinels.wear_phase(m, def, i)
	if m.blow_phase(sim.now) == &"windup":
		# Whatever it was about to do belongs to the phase it has left.
		m.blow = null
	if announce:
		sim.emit(&"second_act", {"mob": m})
		_seen["sentinel_phase"] = true


## The ground tell a phase asks for (`SentinelPhase.tell`), drawn ONCE per bite
## as its windup begins, where the bite will land: the middle of the blow box
## `FightRules.box_hits` will test, at that box's width, so the ring on the sand
## and the rule that hurts agree by construction. The ring lasts the windup, so
## it is gone the instant the strike is down — a ring that outlived the blow
## would be a promise about a second strike nobody is throwing.
func _ground_tell(s: SentinelState, def: SentinelDef, m: MobState) -> void:
	var phase := def.phase(s.phase)
	if phase.tell != &"ring" or m.blow == null or not m.alive:
		return
	if m.blow_phase(sim.now) != &"windup" or float(_told.get(m.id, -INF)) == m.blow_at:
		return
	_told[m.id] = m.blow_at
	var ahead := (m.radius + m.blow.reach) * 0.5
	var at := m.pos + Vector2.from_angle(m.facing) * ahead
	MobFx.ring(game, game.world.to_3d(at), Palette.LINEN[5], m.blow.width * 0.5, m.blow.windup / 1000.0)


## Its body has gone from the coast (culled, or its wreck has lain its time). The
## state keeps everything: come back and it is as hurt as it was.
func _leave(s: SentinelState, def: SentinelDef, m: MobState) -> void:
	if s.fallen and not s.hulk_laid and def.hulk >= 0:
		s.lair = m.pos
	_bodies.erase(m.id)
	_told.erase(m.id)
	s.body = null
	var b: Beacon = _beacons.get(s.region, null)
	if b != null and is_instance_valid(b):
		b.queue_free()
	_beacons.erase(s.region)


## Did the way that took this region leave a wreck, or a machine still standing?
func _kills(def: SentinelDef, how: StringName) -> bool:
	var w := def.way_named(how)
	return w != null and w.kills()


func _stand_down(m: MobState) -> void:
	m.calm_until = INF
	m.disturbed = false
	m.suspicion = 0.0
	m.charging = false
	if m.mood != MobState.IDLE and m.mood != MobState.DEAD:
		m.set_mood(MobState.IDLE, sim.now)


# --- the three ways ---------------------------------------------------------

## What each way has to read, taken off the running game. Pure rules judge it
## (SentinelWay), so every way is provable headless.
func look_at(s: SentinelState, def: SentinelDef) -> SentinelLook:
	var look := SentinelLook.new()
	look.health = 0.0 if (s.body != null and not s.body.alive) else s.health_fraction()
	var m := s.body
	var at := m.pos if m != null else s.lair
	if m != null and m.alive:
		var g := game.world.ground_at(floori(m.pos.x), floori(m.pos.y))
		if g != s.ground_was:
			s.ground_was = g
			s.ground_since = sim.now
		look.ground = g
		look.ground_ms = sim.now - s.ground_since
	var reach := def.reach * Sentinels.FEED_SHARE
	s.feeds = Sentinels.feeds_among(game.query.props_near(s.lair, reach), s.lair, def, game.world.depleted, reach)
	if s.feeds_at_first < 0:
		s.feeds_at_first = s.feeds
	if s.feeds > 0:
		s.dark_since = INF
	elif s.dark_since == INF:
		s.dark_since = sim.now
	look.feeds = s.feeds
	look.feeds_at_first = s.feeds_at_first
	look.dark_ms = 0.0 if s.dark_since == INF else sim.now - s.dark_since
	look.spoofed = game.clock.minutes < game.body.spoof_until
	# Inside its guard: nearer than a keeper lets anybody come (the fight's own
	# number, so the read and the behaviour can never disagree).
	var guard := float(Roster.row(def.kind).get("sees", 12)) * FightSim.WARY_INSIDE
	look.inside = at.distance_to(sim.hero.pos) <= guard
	# What stands beside the player, for a way that only reads a signature
	# under something (SentinelWay.beside). Asked only while it could matter:
	# the tile index is cheap, and the answer is meaningless otherwise.
	var spoof := def.way_of(SentinelWay.SPOOF)
	if look.spoofed and look.inside and spoof != null and not spoof.beside.is_empty():
		for q: WorldProp in game.query.props_near(sim.hero.pos, SentinelLook.BESIDE):
			if game.world.depleted.has(q.id) or q.pos.distance_to(sim.hero.pos) > SentinelLook.BESIDE:
				continue
			if not look.beside.has(q.kind):
				look.beside.append(q.kind)
	# What the player is riding, for a way that only reads a signature off a
	# boat in its lane (SentinelWay.aboard). The ride is the crafts package's
	# to write and this only reads it.
	if sim.hero.ride != null:
		look.riding = sim.hero.ride.kind
	# The clock runs only while the way could be met, so stepping out from
	# under the lamp, or off the raft, loses the count instead of banking it.
	if look.spoofed and look.inside and (spoof == null or spoof.reads_here(look)):
		if s.spoof_since == INF:
			s.spoof_since = sim.now
		look.spoof_ms = sim.now - s.spoof_since
	else:
		s.spoof_since = INF
	return look


func _judge() -> void:
	for s in _states:
		if s.fallen:
			continue
		var def := Sentinels.by_id(s.design)
		if def == null or (s.body == null and s.feeds_at_first < 0):
			# Nothing has ever looked at this one: no way can be met from far off.
			continue
		var look := look_at(s, def)
		for w in def.ways:
			s.progress[w.id()] = w.progress(look)
		for w in def.ways:
			if w.met(look):
				_fell(s, def, w, s.body.pos if s.body != null else s.lair)
				break


## The region is taken (docs/VISION.md, consequences). What changes here and
## now: its reach stops being held, the score's motif stops with its beacon, its
## table is rolled into the player's hands, and a keeper that was killed leaves a
## hulk where it fell that is saved with the world. What the rest of the plan
## makes of a region whose keeper has gone is answered through `sentinel_fell`.
func _fell(s: SentinelState, def: SentinelDef, way: SentinelWay, at: Vector2) -> void:
	if s.fallen or way == null:
		return
	s.fallen = true
	s.how = way.id()
	s.lair = at
	if s.body != null:
		if way.kills() and s.body.alive:
			# The land took it (a FORCE win is already down: the fight did that).
			_take_the_body(s.body)
		elif not way.kills():
			_stand_down(s.body)
	_take_its_table(s, def)
	Events.sentinel_fell.emit(s.region, s.land, s.how)
	if way.says != "":
		Events.message.emit(way.says)


## The land took it: the body dies where it stands, said through the simulation so
## the fight system draws it as it draws any death (its lights out in order, its
## dust, its ring) — there is no second way for a machine to die.
func _take_the_body(m: MobState) -> void:
	m.health = 0
	m.alive = false
	m.blow = null
	m.want = Vector2.ZERO
	m.dead_at = sim.now
	m.set_mood(MobState.DEAD, sim.now)
	sim.emit(&"killed", {"mob": m, "at": m.pos})


## Its table, rolled once and for good: the same seed and the same region always
## give the same things, so a keeper's core cannot be rerolled by loading.
func _take_its_table(s: SentinelState, def: SentinelDef) -> void:
	for row: Dictionary in Drops.roll(def.drops, game.world.seed_value, maxi(0, s.region), s.land):
		var id: StringName = row.get("item", &"")
		var n := int(row.get("count", 1))
		if id == &"" or n <= 0:
			continue
		if Items.def(id).is_empty():
			# A core is declared on the table and in `Materials` before there is an
			# item row to carry it: the gear package owns src/content/items.gd this
			# wave, so what the table promises is read by the economy and the slate
			# and is not forced into the bag here.
			continue
		game.inventory.add(id, n)
		Events.took.emit(id, n)


## What a killed keeper leaves where it fell: a hulk, salvageable, and saved with
## the world (SaveCore keeps props added in play), so the region is visibly
## different tomorrow and for every tomorrow after it.
func _lay_hulk(s: SentinelState, def: SentinelDef) -> void:
	if s.body != null and not s.body.removed:
		return
	s.hulk_laid = true
	var spot := Sentinels.stand_near(game.world, s.lair, 1.0)
	@warning_ignore("return_value_discarded")
	Survival.add_prop(game, def.hulk, spot, Rng.hash01(game.world.seed_value, s.region, 0x5E7) * TAU, 1.5)


# --- the beacon the score reads ---------------------------------------------

func _beacon_for(s: SentinelState, def: SentinelDef) -> void:
	if _beacons.has(s.region):
		return
	var b := Beacon.new()
	b.name = "sentinel_%d" % maxi(0, s.region)
	b.reach = def.reach
	b.land = def.land
	b.pos = s.lair
	b.add_to_group(&"sentinels")
	add_child(b)
	_beacons[s.region] = b


func _beacon(s: SentinelState, def: SentinelDef) -> void:
	var b: Beacon = _beacons.get(s.region, null)
	if b == null or not is_instance_valid(b):
		return
	b.pos = s.body.pos if s.body != null else s.lair
	b.alive = not s.fallen
	b.reach = def.reach


# --- saving -----------------------------------------------------------------

func _save() -> Variant:
	var out: Array = []
	for s in _states:
		if s.region >= 0:
			out.append(s.save())
	return out


func _load(v: Variant) -> void:
	if not v is Array:
		return
	for row: Variant in v:
		if not row is Dictionary:
			continue
		var was := SentinelState.from_save(row)
		var s: SentinelState = _by_region.get(was.region, null)
		if s == null or s.design != was.design:
			# The island this save was grown from held a different place here: the
			# save is refused by its stamp long before this, so there is nothing to
			# carry over and nothing to guess.
			continue
		s.health = clampi(was.health, 0, s.max_health)
		s.phase = was.phase
		s.woken = was.woken
		s.fallen = was.fallen
		s.how = was.how
		s.hulk_laid = was.hulk_laid
		if was.fallen:
			s.lair = was.lair


# --- what a tour can be shown -----------------------------------------------

## Answers a tour's `await WHAT` and a frame's `with WHAT` (98_tour):
##   sentinel            a keeper's body is in the world
##   sentinel:LAND       that landscape's keeper is
##   sentinel_woke       one has come out since the last action
##   sentinel_reach      the player is standing on ground a keeper holds
##   sentinel_phase      it has entered another phase since the last action
##   sentinel_phase:ID   the keeper out now is in that phase
##   sentinel_open       its working part is open (spent after a bite, or stalled)
##   sentinel_hurt       it has lost health
##   sentinel_fallen     a region has been taken (asked of the world, not latched:
##                       a keeper that has fallen stays fallen, and `_states` says so)
##   sentinel_dead       a keeper's hulk is lying in the world
func tour_seen(what: String) -> bool:
	if _seen.has(what):
		return true
	var live := _live()
	match what:
		"sentinel":
			return live != null
		"sentinel_hurt":
			return live != null and live.health < live.max_health
		"sentinel_open":
			# Spent after a bite, or stopped by a blow in its part. Never "it was
			# hit a moment ago": a tour that walks in on that walks into the next
			# bite, which is exactly what the opening is NOT.
			return live != null and (live.spent(sim.now) or live.stunned(sim.now))
		"sentinel_dead":
			for s in _states:
				if s.fallen and (s.hulk_laid or (s.body != null and not s.body.alive)):
					return true
			return false
		"sentinel_fallen":
			for s in _states:
				if s.fallen:
					return true
			return false
		"sentinel_reach":
			for s in _states:
				var def := Sentinels.by_id(s.design)
				if def != null and s.holds(sim.hero.pos, def.reach):
					return true
			return false
	if what.begins_with("sentinel:"):
		var land := StringName(what.substr(9))
		for id: int in _bodies:
			var s: SentinelState = _bodies[id]
			if s.land == land and s.body != null and not s.body.removed:
				return true
		return false
	if what.begins_with("sentinel_phase:"):
		var want := StringName(what.substr(15))
		for id: int in _bodies:
			var s: SentinelState = _bodies[id]
			var def := Sentinels.by_id(s.design)
			if def != null and def.phase(s.phase).id == want:
				return true
		return false
	if what.begins_with("sentinel_way:"):
		var want := StringName(what.substr(13))
		for s in _states:
			if s.fallen and s.how == want:
				return true
		return false
	return false


## An await is spent by the tour that asked it (98_tour `_forget`).
func tour_forget(what: StringName) -> void:
	_seen.erase(what)


func _live() -> MobState:
	for id: int in _bodies:
		var s: SentinelState = _bodies[id]
		if s.body != null and not s.body.removed:
			return s.body
	return null


## The states, for a test and for dev mode.
func states() -> Array[SentinelState]:
	return _states
