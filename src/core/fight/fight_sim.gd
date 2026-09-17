class_name FightSim
extends RefCounted
## The one continuous simulation of every body near the player: walking,
## noticing, chasing, blows, grips and how a fight ends. There is no separate
## fight mode and the world clock never stops for it; this runs in fixed 8 ms
## slices of real time (design-extract §7.1) and is pure data, so tests step it
## headless and the game only draws it.
##
## Per slice: presses -> think (64 ms) and moods (100 ms beats) -> move ->
## touching -> land blows -> holding -> retire -> settle.
##
## Everything the rest of the game should hear about goes in `out` as a
## dictionary {type: StringName, ...}; the fight system drains it into Events,
## sounds, effects and world consequences. Types:
##   swing whiff dodge evaded pull loose grip hit(ring) hurt killed second_act
##   alerted called snatch filed removed fight_started outcome
##   opened (a machine's bite is spent: its working part is open), dulled (a
##   blow that met a body wore the edge past dull), noticed (an indifferent
##   body looked up), crowded (the player holds a worker up on its round),
##   crowd_warning (half way to it taking that as interference), disturbed

const NAV_EVERY_MS := 240.0
## Tiles/s at most that a standing body eases the player out of itself.
const SHOULDER_SPEED := 4.0
## An indifferent worker the player holds up on its round stops and faces them;
## this long held up and it takes it as interference. It warns at half. Looking
## at a worker, walking beside its round or past it is never interference.
const CROWD_MS := 3000.0
## Tiles ahead of its hull, along its round, that count as its way.
const CROWD_AHEAD := 1.1
## How long a body that noticed the player only looks up, and how long before it looks again.
const GLANCE_MS := 900.0
const GLANCE_AGAIN_MS := 5000.0
## Suspicion per beat (MobState.suspicion, 0..1; 1 = sure, and the alert snaps).
## Seen in the open it is sure at once, as it always was; something low in the
## heather takes three beats to be sure of, and a noise on its own four.
const SEEN_RISE := 1.0
const HIDDEN_RISE := 0.4
const NOISE_RISE := 0.28
## What drains per beat when nothing comes of it: about two seconds to settle.
const SUSPICION_FADE := 0.05
## The player is hidden enough for it to have to look twice at this much cover.
const HIDDEN_COVER := 0.15
## How long a body keeps its optics on the last noise (sim ms).
const LOOK_MS := 3500.0
## The middle rung (Disposition.BY_LEVEL): a wary body keeps to its work, but
## it looks up this share as long after the last look (four times as often), its
## suspicion never settles below WARY_FLOOR so its working part never stops
## catching, it leaves its work only for someone who comes inside this share of
## what it can see, and it gives up on a player it has lost in this share of
## the beats a hunter would wait.
const WARY_GLANCE := 0.22
const WARY_FLOOR := 0.3
const WARY_INSIDE := 0.45
const WARY_FORGET := 0.5

var world: WorldData
var query: WorldQuery
var hero: Hero
var moment: Moment
var mobs: Array[MobState] = []
## Steps to the player over the ground, for chasers that meet a cliff.
var nav: NavField
## Simulation milliseconds.
var now := 0.0
## Real seconds that `now` corresponds to (Body stores real-time seconds).
var real_s := 0.0
var out: Array[Dictionary] = []
## The view is holding still (hitstop, or a held moment for a shot); nothing steps.
var hold := false
## The last noise the player made: where it happened, how far it carries
## (StealthNoise, tiles) and the sim ms it was made. Bodies near enough turn their
## optics to it and grow suspicious; it fades after StealthNoise.FRESH_MS.
var noise_at := Vector2.ZERO
var noise_radius := 0.0
var noise_ms := -INF

var fight_on := false
var fight_started := 0.0
var fight_mobs: Dictionary = {} # id -> MobState
var fight_kills := 0
var last_outcome: StringName = &""
## World minutes when a dart last reached the player (Coast keeps darts away after).
var last_meeting_minutes := -INF
## Sim ms the last fight ended (any outcome), and the last time the player was
## downed or carried off: the coast keeps new hunters away from a hurt player.
var last_fight_end_at := -INF
var last_downed_at := -INF
var _far_since := -1.0
var _nav_at := -100000.0
var _far_best := INF
var _best_d := INF
var _best_at := 0.0
var _carry := 0.0
var _swing_until := -1.0
var _dodge_until := -1.0
var _whiff_checked := true
## The current swing has already worn the edge (once, on the first body it meets).
var _blow_wore := true


func _init(w: WorldData, q: WorldQuery, h: Hero = null, m: Moment = null) -> void:
	world = w
	query = q
	hero = h if h != null else Hero.new()
	moment = m if m != null else Moment.new()
	nav = NavField.new(w, q) if w != null and q != null else null


func add_mob(kind: StringName, at: Vector2) -> MobState:
	var m := MobState.new(kind, at, moment.seed_value)
	mobs.append(m)
	return m


func living() -> int:
	var n := 0
	for m in mobs:
		if m.alive and not m.removed:
			n += 1
	return n


# --- input -------------------------------------------------------------------

## The swing key. Held, it wrenches against the grip instead (never buffered).
func press_swing() -> void:
	if hero.held():
		_try_pull()
		return
	_swing_until = now + FightRules.BUFFER_MS


func press_dodge() -> void:
	_dodge_until = now + FightRules.BUFFER_MS


# --- stepping ----------------------------------------------------------------

## Advance by real seconds, in whole slices; the remainder carries.
func step(delta_s: float) -> void:
	hero.read_body()
	_carry += minf(delta_s * 1000.0, FightRules.MAX_FRAME_MS)
	while _carry >= FightRules.SLICE_MS:
		_carry -= FightRules.SLICE_MS
		_slice()
	hero.write_body(now, real_s)
	_purge()


## Advance exactly n slices (tests).
func slices(n: int) -> void:
	hero.read_body()
	for i in n:
		_slice()
	hero.write_body(now, real_s)
	_purge()


func _slice() -> void:
	var t0 := now
	now += FightRules.SLICE_MS
	var dt := FightRules.SLICE_MS / 1000.0
	_presses()
	if fmod(now, FightRules.THINK_MS) < FightRules.SLICE_MS:
		for m in mobs:
			Brains.think(m, self)
	if floori(now / FightRules.BEAT_MS) != floori(t0 / FightRules.BEAT_MS):
		_beat()
	_move_hero(dt)
	for m in mobs:
		_move_mob(m, dt)
	_touching()
	_land(t0, now)
	_holding()
	_retire()
	_settle()


func _presses() -> void:
	if _swing_until >= now and not hero.held():
		if hero.swing_refusal(now) == &"":
			_swing_until = -1.0
			_swing()
	if _dodge_until >= now:
		if hero.dodge_refusal(now) == &"":
			_dodge_until = -1.0
			_dodge()


func _swing() -> void:
	var inv := hero.inventory
	var held: StringName = inv.held if inv != null else &""
	var b := Blow.for_item(held, inv.edge(held) if inv != null and held != &"" else 10000)
	if hero.move.length() > 0.1:
		hero.facing = hero.move.angle()
	# Turn toward a body just off the facing, so a swing that was meant lands where it was meant.
	var best: MobState = null
	var best_off := FightRules.AIM_ASSIST_ANGLE
	for m in mobs:
		if not m.alive or m.removed:
			continue
		var to := m.pos - hero.pos
		if to.length() > hero.radius + b.reach + m.radius + FightRules.AIM_ASSIST_EXTRA:
			continue
		var off := absf(wrapf(to.angle() - hero.facing, -PI, PI))
		if off < best_off:
			best_off = off
			best = m
	if best != null:
		hero.facing = (best.pos - hero.pos).angle()
	var dry := b.wick > 0 and not FightRules.spend_charges(inv, b.wick)
	if dry:
		b.dry()
	hero.start_swing(b, now)
	_whiff_checked = false
	# The edge wears where it meets something: a swing at air costs wind, not edge.
	_blow_wore = false
	emit(&"swing", {"item": held, "dry": dry})


func _dodge() -> void:
	var dir := hero.move
	if dir.length() > 0.1:
		hero.facing = dir.angle()
	else:
		# No direction held: a step back, still facing the trouble.
		dir = -Vector2.from_angle(hero.facing)
	hero.start_dodge(dir, now)
	emit(&"dodge", {})


func _try_pull() -> void:
	var inv := hero.inventory
	var cut: bool = inv != null and Items.def(inv.held).get("verb", &"") == &"cut"
	var holder := hero.holder
	if hero.pull(now, cut):
		emit(&"pull", {"grip": hero.grip, "by": holder})
		if hero.grip == 0:
			emit(&"loose", {"by": holder})


# --- moods (100 ms beats) ----------------------------------------------------

func _beat() -> void:
	for m in mobs:
		if not m.alive or m.removed:
			continue
		# A body at its work reads only what its own optics cover (StealthQuery's
		# cone); one that already has the player keeps track of them all round.
		var on_round := m.machine and (m.mood == MobState.IDLE or m.mood == MobState.WORKING)
		var look := m.facing if on_round else NAN
		var noticed := now >= m.calm_until and StealthQuery.notices(m.row, m.pos, hero.pos, moment, world, query, look)
		_suspicion(m, noticed)
		if noticed:
			m.lost_beats = 0
			m.last_seen = hero.pos
		else:
			m.lost_beats += 1
		var d := Senses.chebyshev(m.pos, hero.pos)
		var reach := float(m.stat("reach", 1))
		var beats := int((now - m.mood_at) / FightRules.BEAT_MS)
		match m.mood:
			MobState.IDLE, MobState.WORKING:
				if m.at_work():
					_crowding(m)
					var wary := m.watchful()
					var again := GLANCE_AGAIN_MS * (WARY_GLANCE if wary else 1.0)
					if noticed and now >= m.glance_until + again:
						# It sees you and goes on with its work: looked at, not hunted.
						# A wary one looks up again and again; that is what the
						# player reads as a region that has been stirred up.
						m.glance_until = now + GLANCE_MS
						emit(&"noticed", {"mob": m})
					if wary and m.suspicion >= 1.0 and d <= float(m.stat("sees", 10)) * WARY_INSIDE:
						# It will not chase someone keeping their distance, but it
						# lets nobody inside its guard.
						m.set_mood(MobState.ALERTED, now)
						emit(&"alerted", {"mob": m})
				elif m.suspicion >= 1.0:
					# Sure. The alert pose snaps on the body itself (Mob); nothing is said.
					m.set_mood(MobState.ALERTED, now)
					emit(&"alerted", {"mob": m})
			MobState.ALERTED:
				if m.lost_beats >= _forget(m):
					m.disturbed = false
					m.set_mood(MobState.WORKING if m.approach == &"errand" else MobState.IDLE, now)
				elif beats >= int(m.stat("ready", 2)):
					if m.approach == &"errand":
						_call(m)
					else:
						m.set_mood(MobState.CHASING, now)
			MobState.CHASING:
				if m.lost_beats >= _forget(m):
					m.disturbed = false
					m.set_mood(MobState.IDLE, now)
				elif m.approach != &"dart" and m.pos.distance_to(m.home) > float(m.stat("tether", 30)):
					m.flee_home = true
					m.set_mood(MobState.FLEEING, now)
				elif m.approach != &"dart" and d <= reach:
					m.set_mood(MobState.ATTACKING, now)
			MobState.ATTACKING:
				if m.lost_beats >= _forget(m):
					m.disturbed = false
					m.set_mood(MobState.IDLE, now)
				elif d > reach + 4.0 and not m.committed(now):
					m.charging = false
					m.set_mood(MobState.CHASING, now)
				elif m.pos.distance_to(m.home) > float(m.stat("tether", 30)) + 4.0:
					m.flee_home = true
					m.set_mood(MobState.FLEEING, now)
			MobState.FLEEING:
				if m.flee_home:
					if m.pos.distance_to(m.home) < 2.0:
						m.flee_home = false
						m.calm_until = now + 3000.0
						m.set_mood(MobState.IDLE, now)
				elif d >= float(m.stat("safe", 12)):
					if m.snatched:
						if m.row.get("hits", {}).get("files", false) and not m.reported:
							m.reported = true
							emit(&"filed", {"mob": m})
						remove_mob(m)
					else:
						m.calm_until = now + 4000.0
						m.set_mood(MobState.IDLE, now)


## How sure a body is, beat by beat, and where it is looking while it makes up
## its mind. Seen in the open it is sure at once (nothing about a fight
## changes); low in the heather it has to look twice; a noise out of sight
## turns its optics that way and, kept up, brings it over. Drawn on the machine
## (Mob): the working part flickers with it, and the alert snaps at 1.
func _suspicion(m: MobState, noticed: bool) -> void:
	if not m.machine:
		# A creature is sure or it is not: making up its mind is a machine's
		# reading, and nothing about a fight with an animal changes here.
		m.suspicion = 1.0 if noticed else 0.0
		return
	if noticed:
		var hidden := moment.crouched or moment.cover > HIDDEN_COVER
		m.suspicion = minf(1.0, m.suspicion + (HIDDEN_RISE if hidden else SEEN_RISE))
		m.heard_at = hero.pos
		return
	if now - noise_ms < StealthNoise.FRESH_MS and StealthQuery.hears_noise(m.row, m.pos, noise_at, noise_radius, moment):
		if m.look_until <= now or m.heard_at.distance_squared_to(noise_at) > 1.0:
			emit(&"heard", {"mob": m, "at": noise_at})
		m.heard_at = noise_at
		m.look_until = now + LOOK_MS
		m.suspicion = minf(1.0, m.suspicion + NOISE_RISE)
		return
	# A wary body never settles all the way: its part goes on catching, which is
	# how a region that has been stirred up is read without a word.
	m.suspicion = maxf(WARY_FLOOR if m.watchful() else 0.0, m.suspicion - SUSPICION_FADE)


## Beats of losing the player before a body gives up. One that never left its
## work for the player in the first place (a wary keeper that let them inside
## its guard) settles back twice as fast as one that came hunting.
func _forget(m: MobState) -> int:
	var f := int(m.stat("forget", 20))
	if m.watchful():
		return maxi(4, int(f * WARY_FORGET))
	return f


## The player made a noise at `at` that carries `radius` tiles (StealthNoise). Every
## body near enough turns to it on the next beat.
func make_noise(at: Vector2, radius: float) -> void:
	if radius <= noise_radius and now - noise_ms < FightRules.BEAT_MS:
		# Two noises in one beat: the louder one is the one that is heard.
		return
	noise_at = at
	noise_radius = radius
	noise_ms = now


## The player has done something to this body that its role takes amiss
## (Roles.TURNS: blocked, damaged, theft, trespass, curfew). A body that does
## not care goes on working; a worker robbed of its parts turns.
func disturb(m: MobState, cause: StringName) -> void:
	if not m.alive or m.removed:
		return
	_wake(m, cause)


## An indifferent worker on its round with the player planted on its path: it
## stops (the brain) and, held up past CROWD_MS, takes it as interference and
## turns on them. The way is measured along the round it walks, never along
## where it happens to face, so a worker that looks at someone does not put
## them in its way by looking. Errands have their own way of coming over you.
func _crowding(m: MobState) -> void:
	if m.approach == &"errand" or m.approach == &"dart":
		return
	var in_way := in_way_of(m, hero.pos, hero.radius)
	if not in_way or m.speed > 0.2:
		if not in_way and m.crowded_since >= 0.0:
			# Out of its path: it goes on, and the next time starts from nothing.
			m.crowded_since = -1.0
			m.crowd_warned = false
		return
	if m.crowded_since < 0.0:
		m.crowded_since = now
		emit(&"crowded", {"mob": m})
	elif now - m.crowded_since >= CROWD_MS:
		_wake(m, &"blocked")
	elif not m.crowd_warned and now - m.crowded_since >= CROWD_MS * 0.5:
		m.crowd_warned = true
		emit(&"crowd_warning", {"mob": m})


## Is a body of radius `r` at `p` on this worker's path: ahead of its hull along
## the round it walks, within CROWD_AHEAD, and close enough across the path that
## the hull would meet it.
static func in_way_of(m: MobState, p: Vector2, r: float) -> bool:
	var dir := m.path_dir()
	if dir == Vector2.ZERO:
		return false
	var off := p - m.pos
	var along := off.dot(dir)
	var across := absf(off.dot(dir.orthogonal()))
	return along > 0.0 and along < m.radius + r + CROWD_AHEAD and across < m.radius + r * 0.5


## An errand that works by eye has registered the player: every machine within
## its racket that is not already roused is told where the player stood.
func _call(watcher: MobState) -> void:
	var calls: float = watcher.stat("calls", 0)
	if calls <= 0.0 or now < watcher.call_ready_at:
		return
	watcher.call_ready_at = now + 30000.0
	var told := 0
	for m in mobs:
		if m == watcher or not m.alive or m.removed or m.approach == &"errand" or not m.machine:
			continue
		# Workers go on working: a report sends the hunters, not the harvest.
		if m.at_work():
			continue
		if m.mood != MobState.IDLE:
			continue
		if m.pos.distance_to(watcher.pos) <= calls:
			m.last_seen = hero.pos
			m.lost_beats = 1
			m.set_mood(MobState.ALERTED, now)
			told += 1
	emit(&"called", {"mob": watcher, "told": told})


# --- movement ----------------------------------------------------------------

func _move_hero(dt: float) -> void:
	var v := Vector2.ZERO
	var since_dodge := now - hero.dodge_at
	var running := false
	if hero.held():
		var h := hero.holder
		if h != null:
			var mouth := h.pos + Vector2.from_angle(h.facing) * (h.radius + hero.radius * 0.6)
			var to := mouth - hero.pos
			v = to.limit_length(1.5) * 3.0
			hero.facing = (h.pos - hero.pos).angle()
	elif hero.stunned(now):
		v = Vector2.ZERO
	elif since_dodge < FightRules.DODGE_MS:
		v = hero.dodge_dir * FightRules.dodge_speed(since_dodge)
	else:
		var can_run := (not fight_on or hero.wind > FightRules.RUN_WIND_FLOOR) and not hero.crouched
		running = hero.run and can_run and hero.move.length() > 0.1
		var s := hero.run_speed if running else hero.walk_speed
		if hero.crouched:
			s *= Hero.CROUCH_SPEED
		if hero.committed(now):
			s *= hero.blow.creep
		v = hero.move.limit_length(1.0) * s
		if not hero.committed(now) and hero.move.length() > 0.1:
			hero.facing = hero.move.angle()
	v += hero.throw_velocity(now)
	v += _shouldered(dt)
	var before := hero.pos
	if v.length_squared() > 0.0:
		hero.pos = query.move_body(hero.pos, v * dt, hero.radius, hero.ride, hero.swims) if query != null else hero.pos + v * dt
	hero.speed = before.distance_to(hero.pos) / dt
	# Wind: spent on dodges, swings and running in a fight; back at 500/s otherwise.
	if running and fight_on:
		hero.wind = maxf(0.0, hero.wind - FightRules.RUN_WIND_COST * dt)
	elif since_dodge >= FightRules.DODGE_MS:
		hero.wind = minf(hero.max_wind, hero.wind + FightRules.WIND_REGEN * dt)


## Bodies are solid to the player, so no one stands hidden in a machine's
## middle on no side of it. A standing body eases the player out of itself; a
## moving one (a charge coming on, a sweeper along its track) never changes
## course for the player: it shoulders them aside, off its line. A dodge goes
## through; a holder keeps what it holds; darts only brush past.
func _shouldered(dt: float) -> Vector2:
	if now - hero.dodge_at < FightRules.DODGE_MS:
		return Vector2.ZERO
	var push := Vector2.ZERO
	for m in mobs:
		if not m.alive or m.removed or m.approach == &"dart" or hero.holder == m:
			continue
		var away := hero.pos - m.pos
		var d := away.length()
		var inside := m.radius + hero.radius * 0.5 - d
		if inside <= 0.0:
			continue
		var dir := away / d if d > 1e-4 else Vector2.from_angle(m.facing + PI * 0.5)
		if m.speed > 1.0:
			var along := Vector2.from_angle(m.facing)
			var side := along.orthogonal()
			if side.dot(away) < 0.0:
				side = -side
			push += side * SHOULDER_SPEED * 1.5
		else:
			push += dir * minf(inside / dt, SHOULDER_SPEED)
			if hero.move.length() > 0.1 and hero.move.dot(-dir) > 0.2:
				# Walking into a standing body slides round it, as round a trunk: the
				# way to a machine's back goes past its flank, not dead into its front.
				var round := dir.orthogonal()
				if round.dot(hero.move) < 0.0:
					round = -round
				push += round * SHOULDER_SPEED * 0.9
	return push


func _move_mob(m: MobState, dt: float) -> void:
	if m.removed:
		return
	if not m.alive:
		m.speed = 0.0
		return
	if not m.committed(now) and not m.stunned(now):
		m.facing = rotate_toward(m.facing, m.aim, m.turn_rate_at(now) * dt)
	var v := m.want
	if m.stunned(now):
		v = Vector2.ZERO
	else:
		# Close bites read as a tell and a lunge; charges come on through them.
		var phase := m.blow_phase(now)
		if m.approach == &"charge" and phase == &"windup":
			# A run that tells from close in eases so the front arrives as the blow
			# goes live; at full speed it ran clean past a body beside its row.
			var fwd := Vector2.from_angle(m.facing)
			var ahead := (hero.pos - m.pos).dot(fwd)
			if ahead > 0.0:
				var stop := m.radius + hero.radius + m.blow.reach * 0.6
				var left_s := maxf(0.016, (m.blow_at + m.blow.windup - now) / 1000.0)
				v = v.limit_length(maxf(0.0, ahead - stop) / left_s)
		if m.approach != &"charge" and phase != &"":
			match phase:
				&"windup": v *= 0.2
				# A small follow-through: enough to see, never enough to outreach its box.
				&"active": v = Vector2.from_angle(m.facing) * m.quick * 0.5
				&"recovery":
					# The overcommit: a machine's lunge carries it on past where it bit,
					# its box dead, so the body it missed ends up at its flank or back.
					var over: float = m.row.get("overrun", 0.0) if m.landed_at != m.blow_at else 0.0
					v = Vector2.from_angle(m.facing) * m.quick * over if over > 0.0 else v * 0.3
	v += m.throw_velocity(now)
	# Hostiles keep a tile apart from each other; never from the player.
	for o in mobs:
		if o == m or not o.alive or o.removed:
			continue
		var sep := m.pos - o.pos
		var d := sep.length()
		if d < 1.0 and d > 1e-4:
			v += sep / d * (1.0 - d) * 4.0
	if not m.row.get("through", false):
		var to := hero.pos - m.pos
		var d := to.length()
		var skin := (m.radius + hero.radius) * 0.9
		if d < skin + 0.05 and d > 1e-4:
			var inward := v.dot(to / d)
			if inward > 0.0:
				v -= to / d * inward
	if v.length_squared() < 1e-6:
		m.speed = 0.0
		return
	var before := m.pos
	# Deep water stops a body that cannot take it, which is most of the roster
	# (Swim): the few that cross carry it on their own row, not here.
	var next := query.move_body(m.pos, v * dt, minf(m.radius, 0.45), null, Swim.may_cross(m.row)) if query != null else m.pos + v * dt
	var keeps: Array = m.row.get("keeps_to", [])
	if not keeps.is_empty() and world != null:
		if not _ground_in(next, keeps):
			var nx := Vector2(next.x, m.pos.y)
			var ny := Vector2(m.pos.x, next.y)
			next = nx if _ground_in(nx, keeps) else (ny if _ground_in(ny, keeps) else m.pos)
	m.pos = next
	m.speed = before.distance_to(m.pos) / dt


func _ground_in(p: Vector2, names: Array) -> bool:
	var g := world.ground_at(floori(p.x), floori(p.y))
	return Spawner.ground_matches(g, names)


static func rotate_toward(from: float, to: float, max_step: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	if absf(diff) <= max_step:
		return to
	return from + signf(diff) * max_step


# --- contact and blows -------------------------------------------------------

func _touching() -> void:
	for m in mobs:
		var touch: int = m.stat("touch", 0)
		if touch <= 0 or not m.alive or m.removed or m.bite != null:
			continue
		if m.pos.distance_to(hero.pos) > m.radius + hero.radius:
			continue
		if hero.invulnerable(now):
			continue
		_hurt_hero(m, touch, hero.pos - m.pos, 4.0, 200)


func _land(t0: float, t1: float) -> void:
	var b := hero.blow
	if b != null and b.live_in(hero.blow_at, t0, t1):
		for m in mobs:
			if not m.alive or m.removed or hero.struck.has(m.id):
				continue
			if not FightRules.box_hits(hero.pos, hero.facing, hero.radius, b, m.pos, m.radius):
				continue
			hero.struck[m.id] = true
			_wear_on_contact()
			if not reaches_part(m, hero.pos, b.cuts):
				hero.throw(hero.pos - m.pos, FightRules.RING_RECOIL, FightRules.RING_RECOIL_MS, now)
				emit(&"hit", {"attacker": hero, "target": m, "damage": 0, "plate": true, "at": m.pos})
				_wake(m)
				continue
			if m.invulnerable(now):
				continue
			_hurt_mob(m, b)
	if b != null and not _whiff_checked and t1 >= hero.blow_at + b.windup + b.active:
		_whiff_checked = true
		if hero.struck.is_empty():
			emit(&"whiff", {})
	for m in mobs:
		if m.alive and not m.removed and m.blow != null and m.machine and m.landed_at != m.blow_at:
			var spent_at := m.blow_at + m.blow.windup + m.blow.active
			if t0 < spent_at and spent_at <= t1:
				m.opened_at = spent_at
				emit(&"opened", {"mob": m})
		if not m.alive or m.removed or m.blow == null or m.struck.has(&"hero"):
			continue
		if not m.blow.live_in(m.blow_at, t0, t1):
			continue
		if not FightRules.box_hits(m.pos, m.facing, m.radius, m.blow, hero.pos, hero.radius):
			continue
		m.struck[&"hero"] = true
		if not hero.invulnerable(now):
			_landed(m)
		if hero.invulnerable(now):
			# Slipped: a blow met first inside the window is spent. The source let the
			# rest of the live window land, which made a dodge read right into a hit
			# whenever the box outlasted 90 ms; the timing is the skill, not the luck.
			emit(&"evaded", {"by": m, "dodge": FightRules.dodge_invulnerable(now - hero.dodge_at)})
			continue
		if m.blow.grip > 0:
			if hero.seize(m, m.blow.grip, now):
				hero.blow = null
				emit(&"grip", {"by": m, "grip": hero.grip})
			continue
		_hurt_hero(m, m.blow.dmg, Vector2.from_angle(m.facing) + (hero.pos - m.pos).normalized(), m.blow.knock, m.blow.knock_ms)


## Does a blow from `from` reach this body's working part now? The plate rule,
## and for a `guarded` part (a harvester's blade row, its bite side) only while
## the machine is open: spent after a bite, stopped by a blow, or not yet
## roused. A turning blade row throws a blow off like plate, so walking in
## swinging at the front rings, and the opening is the skill.
func reaches_part(m: MobState, from: Vector2, cuts: bool = false) -> bool:
	if not FightRules.reaches(m.part, m.pos, m.facing, from, cuts):
		return false
	if cuts or not m.row.get("guarded", false):
		return true
	return m.spent(now) or m.stunned(now) or m.indifferent() or not m.roused()


## A machine's bite met the player: it has what it came for, so it neither
## overcommits nor stands spent. The opening belongs to whoever got out of the
## way, not to whoever took the bite; but its next tell waits until the one it
## bit is on their feet again (LANDED_COOLDOWN_MS), so one bite is one bite.
func _landed(m: MobState) -> void:
	if not m.machine or m.blow == null:
		return
	var b := m.blow.copy()
	b.recovery = mini(b.recovery, FightRules.LANDED_RECOVERY_MS)
	b.cooldown = FightRules.LANDED_COOLDOWN_MS
	m.blow = b
	m.landed_at = m.blow_at


## The swing met a body (a hit or a ring): one use of the edge, once per swing.
func _wear_on_contact() -> void:
	if _blow_wore:
		return
	_blow_wore = true
	var inv := hero.inventory
	if inv == null or inv.held == &"":
		return
	if FightRules.wear(inv, inv.held, 1):
		emit(&"dulled", {"item": inv.held})


func _hurt_mob(m: MobState, b: Blow) -> void:
	m.health -= b.dmg
	m.invuln_until = now + m.mob_iframes()
	m.last_hit_at = now
	# A creature has no part to flare: it is hurt at once.
	m.flare_until = now + (FightRules.PART_FLARE_MS if m.machine else 0.0)
	m.dark_until = m.flare_until + FightRules.PART_DARK_MS
	if m.row.get("stagger", false):
		m.throw(m.pos - hero.pos, b.knock, b.knock_ms, now)
		if m.blow_phase(now) == &"windup":
			m.blow = null
	elif m.machine and now >= m.stall_ready_at:
		# A machine never flinches, but a blow in its working part stops the work:
		# the light goes out, a tell in progress is lost, and it stands a moment.
		# Once in a while only, so it is an opening and not a lock.
		m.stall_ready_at = now + FightRules.STALL_EVERY_MS
		m.stun_until = maxf(m.stun_until, now + FightRules.STALL_MS)
		m.charging = false
		if m.blow_phase(now) == &"windup":
			m.blow = null
	emit(&"hit", {"attacker": hero, "target": m, "damage": b.dmg, "plate": false, "at": m.pos})
	if m.health <= 0:
		_kill(m)
		return
	if m.row.has("then") and not m.second_act and m.health_fraction() <= float(m.row.get("then_at", 0.0)):
		m.second_act = true
		m.bite = Roster.second_bite(m.kind)
		if m.blow_phase(now) == &"windup":
			m.blow = null
		if hero.holder == m:
			hero.release()
			emit(&"loose", {"by": m})
		emit(&"second_act", {"mob": m})
	var nerve: int = m.stat("nerve", 100)
	if nerve < 100 and m.health_fraction() * 100.0 <= nerve:
		m.flee_home = false
		m.set_mood(MobState.FLEEING, now)
		return
	_wake(m)


## Struck, a body that was not pressing turns on whoever struck it (errands only look).
## `cause` is what the player did (Roles.TURNS). Struck, anything stops and
## deals with it, even a body whose whole trade is to report; anything else
## reaches only a role that takes that cause amiss, and only a role that fights
## is actually turned by it.
func _wake(m: MobState, cause: StringName = &"damaged") -> void:
	var turns := Disposition.turned_by(m.role, cause)
	if not turns and cause != &"damaged":
		return
	m.last_seen = hero.pos
	m.lost_beats = 0
	m.calm_until = 0.0
	m.suspicion = 1.0
	m.crowded_since = -1.0
	m.crowd_warned = false
	m.via = Vector2.INF
	if turns and not m.disturbed and not Disposition.hostile(m.disposition):
		# A worker or a keeper that was about the plan's work now has its own
		# reason, whatever its region thinks. Each turning is reported once
		# (32_disposition._turned), so a body that settled and is stirred again
		# is news again.
		m.turn_filed = false
		m.disturbed = true
		m.disturbed_by = cause
		emit(&"disturbed", {"mob": m, "cause": cause})
	if m.mood == MobState.IDLE or m.mood == MobState.WORKING or m.mood == MobState.ALERTED:
		if m.approach == &"errand":
			m.set_mood(MobState.ALERTED, now)
		elif m.approach != &"dart":
			m.set_mood(MobState.ATTACKING, now)


func _hurt_hero(by: MobState, dmg: int, dir: Vector2, knock: float, knock_ms: int) -> void:
	if hero.harm != 1.0:
		dmg = roundi(dmg * maxf(0.0, hero.harm))
	hero.health -= dmg
	hero.invuln_until = now + FightRules.HURT_IFRAMES_MS
	hero.throw(dir, knock, knock_ms, now)
	hero.last_hit_by = by
	hero.last_hit_at = now
	if hero.committed(now):
		hero.blow = null
	emit(&"hurt", {"attacker": by, "target": hero, "damage": dmg, "at": hero.pos})


func _kill(m: MobState) -> void:
	m.health = 0
	m.alive = false
	m.blow = null
	m.want = Vector2.ZERO
	m.dead_at = now
	m.set_mood(MobState.DEAD, now)
	if fight_mobs.has(m.id):
		fight_kills += 1
	if hero.holder == m:
		hero.release()
		emit(&"loose", {"by": m})
	emit(&"killed", {"mob": m, "at": m.pos})


## A dart reached the player: it takes what it came for and runs.
func snatch(m: MobState) -> void:
	if m.snatched:
		return
	m.snatched = true
	if moment != null:
		last_meeting_minutes = moment.minutes
	m.flee_home = false
	m.set_mood(MobState.FLEEING, now)
	emit(&"snatch", {"mob": m})


func _holding() -> void:
	if not hero.held():
		return
	var h := hero.holder as MobState
	if h == null or not h.alive or h.removed:
		hero.release()
		emit(&"loose", {"by": h})
		return
	if now - hero.grip_since >= FightRules.HOLD_LIMIT_MS:
		_end(&"carried")


func _retire() -> void:
	for m in mobs:
		if m.alive or m.removed:
			continue
		if now - m.dead_at >= float(m.stat("linger", 30.0)) * 1000.0:
			remove_mob(m)


func remove_mob(m: MobState) -> void:
	if m.removed:
		return
	m.removed = true
	if hero.holder == m:
		hero.release()
		emit(&"loose", {"by": m})
	emit(&"removed", {"mob": m})


## Take every body off the coast (a bad end, a jump in time).
func clear_mobs() -> void:
	for m in mobs:
		remove_mob(m)
	fight_mobs.clear()


func _purge() -> void:
	var keep: Array[MobState] = []
	for m in mobs:
		if not m.removed:
			keep.append(m)
	mobs = keep


# --- how a fight ends --------------------------------------------------------

func _settle() -> void:
	if hero.health <= 0:
		if not fight_on:
			_begin()
		_end(&"downed")
		return
	var engaged := false
	for m in mobs:
		if _pressing(m):
			engaged = true
			if fight_on and not fight_mobs.has(m.id):
				fight_mobs[m.id] = m
	if not fight_on:
		if engaged:
			_begin()
		return
	var nearest := INF
	var pressing := false
	for id: int in fight_mobs:
		var m: MobState = fight_mobs[id]
		if not m.alive or m.removed:
			continue
		nearest = minf(nearest, ground_distance(m.pos))
		if m.engaged() or hero.holder == m:
			pressing = true
	if nearest == INF:
		_end(&"won" if fight_kills > 0 else &"away")
		return
	if not pressing:
		_end(&"away")
		return
	# Left behind: far off for a while and not closing. Something still coming
	# round a cliff to you is closing, and is still a fight.
	if nearest > FightRules.AWAY_DISTANCE:
		if _far_since < 0.0 or nearest < _far_best - 0.5:
			_far_since = now
			_far_best = nearest
		elif now - _far_since >= FightRules.AWAY_MS:
			_end(&"away")
			return
	else:
		_far_since = -1.0
		_far_best = INF
	if nearest > 3.0:
		if nearest < _best_d - 0.5:
			_best_d = nearest
			_best_at = now
		elif now - _best_at >= FightRules.NO_PROGRESS_MS:
			_end(&"away")
	else:
		_best_d = nearest
		_best_at = now


## Bring the ground field to the player's tile, at most every NAV_EVERY_MS: a
## field a tile stale still leads round the same cliff, and a build is not free.
func refresh_nav() -> void:
	if nav == null:
		return
	if nav.builds > 0 and now - _nav_at < NAV_EVERY_MS:
		return
	var before := nav.builds
	nav.update(hero.pos)
	if nav.builds != before:
		_nav_at = now


## Tiles to the player over the ground (the way round a cliff, not through it),
## or the straight Chebyshev distance where the ground field does not reach.
func ground_distance(p: Vector2) -> float:
	var straight := Senses.chebyshev(p, hero.pos)
	if nav == null or straight > NavField.RADIUS or NavField.line_walkable(world, p, hero.pos):
		return straight
	refresh_nav()
	var s := nav.steps(floori(p.x), floori(p.y))
	if s >= NavField.FAR:
		return straight
	return maxf(straight, float(s) / NavField.STRAIGHT)


## Pressing the player closely enough to count as a fight. Something coming from
## the edge of sight is not a fight yet: it would count as left behind before it
## ever arrived, and the player's run would cost wind for a walk.
func _pressing(m: MobState) -> bool:
	if hero.holder == m:
		return true
	return m.engaged() and Senses.chebyshev(m.pos, hero.pos) <= FightRules.AWAY_DISTANCE


func _begin() -> void:
	fight_on = true
	fight_started = now
	fight_kills = 0
	fight_mobs.clear()
	for m in mobs:
		if _pressing(m):
			fight_mobs[m.id] = m
			# The first blow in a working part of a new fight always stops the work
			# (unless that blow is the one that started the fight).
			if now - m.last_hit_at > FightRules.STALL_EVERY_MS:
				m.stall_ready_at = 0.0
	_far_since = -1.0
	_far_best = INF
	_best_d = INF
	_best_at = now
	emit(&"fight_started", {})


func _end(outcome: StringName) -> void:
	fight_on = false
	last_outcome = outcome
	last_fight_end_at = now
	if outcome == &"downed" or outcome == &"carried":
		last_downed_at = now
	var by := hero.last_hit_by as MobState
	if outcome == &"carried":
		by = hero.holder as MobState
	match outcome:
		&"downed", &"carried":
			hero.release()
			hero.blow = null
			hero.stun_until = now
			hero.throw_until = now
			if outcome == &"downed":
				hero.health = FightRules.DOWNED_WAKE_HEALTH
			emit(&"outcome", {"outcome": outcome, "by": by, "ms": now - fight_started})
			clear_mobs()
			return
		&"away":
			for id: int in fight_mobs:
				var m: MobState = fight_mobs[id]
				if not m.alive or m.removed:
					continue
				m.charging = false
				m.closing_since = -1.0
				m.calm_until = now + 6000.0
				m.disturbed = false
				var nerve: int = m.stat("nerve", 100)
				if nerve < 100 and m.health < m.max_health:
					m.set_mood(MobState.FLEEING, now)
				else:
					m.set_mood(MobState.WORKING if m.approach == &"errand" else MobState.IDLE, now)
	fight_mobs.clear()
	emit(&"outcome", {"outcome": outcome, "by": by, "ms": now - fight_started})


func emit(type: StringName, data: Dictionary) -> void:
	data["type"] = type
	out.append(data)


## Take the events since the last drain.
func drain() -> Array[Dictionary]:
	var o := out
	out = []
	return o
