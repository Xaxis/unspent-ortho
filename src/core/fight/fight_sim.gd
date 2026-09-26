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
##   crowd_warning (half way to it taking that as interference), disturbed,
##   drop_strike (a jump's landing thrown as a blow: FightSim.drop_strike)

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
## What it only half has -- the player HEARD (their own steps, their breath, in
## its hearing), or GLIMPSED out of the corner of its optics behind its cone --
## makes it unsure, not sure: a ramp, not a snap, so there are a few seconds to
## get out of it. Heard or glimpsed past LOOK_AT, it turns its optics that way
## and goes to look, and only what it then SEES in its cone makes it sure. A
## warden in its hall made sure by a glimpse of the hatch behind it arrested
## whoever came down it within the second, every time.
const HEAR_RISE := 0.02
## And a machine makes up its mind by ear this much faster at full night, when
## its ears are what it has (Senses.NIGHT_HEARING): three times, so a walker
## heard in the dark is turned on in about a second.
const NIGHT_HEAR_RISE := 2.0
const GLIMPSE_RISE := 0.025
const LOOK_AT := 0.6
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
## Where a buffered swing is aimed, radians in tile space, or NAN for the swing's
## own rule (the way the body walks, else the way it faces). Set by a view that
## has a direction of its own to look in: over the shoulder a swing goes where the
## camera looks, because that is where the player is looking (CameraRig.aim).
var _swing_aim := NAN
## Charged swings thrown with a capacitor fitted, for the one it carries.
var _charged_swings := 0
## The buffered swing is the heavy blow (press_heavy).
var _swing_heavy := false
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


## A body of `kind` put down at `at`, as the landscape there makes that kind
## (BiomeDef.roster `over`): read at the one tile it stands on.
func add_mob(kind: StringName, at: Vector2) -> MobState:
	var m := MobState.new(kind, at, moment.seed_value, _landscape_over(kind, at))
	mobs.append(m)
	return m


func _landscape_over(kind: StringName, at: Vector2) -> Dictionary:
	if world == null or not world.in_bounds(floori(at.x), floori(at.y)):
		return {}
	var def := BiomeRegistry.by_index(world.country_at(floori(at.x), floori(at.y)))
	if def == null:
		return {}
	return def.roster.get(kind, {}).get("over", {})


func living() -> int:
	var n := 0
	for m in mobs:
		if m.alive and not m.removed:
			n += 1
	return n


# --- input -------------------------------------------------------------------

## The swing key. Held, it wrenches against the grip instead (never buffered).
func press_swing(aim := NAN) -> void:
	if hero.held():
		_try_pull()
		return
	_swing_until = now + FightRules.BUFFER_MS
	_swing_aim = aim
	_swing_heavy = false


## The swing key held past FightRules.HEAVY_HOLD_MS (the fight system times the
## hold): the heavy blow, buffered as a swing is. Held, it pulls, as a swing does.
func press_heavy(aim := NAN) -> void:
	press_swing(aim)
	_swing_heavy = not hero.held()


func press_dodge() -> void:
	_dodge_until = now + FightRules.BUFFER_MS


# --- stepping ----------------------------------------------------------------

## Advance by real seconds, in whole slices; the remainder carries.
func step(delta_s: float) -> void:
	hero.read_body()
	hero.swimming = hero.ride == null and Swim.deep(world, hero.pos)
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
	var b := _held_blow()
	var at_lock := is_nan(_swing_aim) and LockOn.locked(hero.lock) \
		and (hero.lock - hero.pos).length() >= LockOn.NEAR
	if not is_nan(_swing_aim):
		hero.facing = _swing_aim
		_swing_aim = NAN
	elif at_lock:
		# A lock says where the blow goes: at what is held, whatever else is near.
		hero.facing = (hero.lock - hero.pos).angle()
	elif hero.move.length() > 0.1:
		hero.facing = hero.move.angle()
	# Turn toward a body just off the facing, so a swing that was meant lands where it was meant.
	var best: MobState = null
	var best_off := FightRules.AIM_ASSIST_ANGLE
	for m in mobs:
		if at_lock:
			break
		if not m.alive or m.removed:
			continue
		var to := m.pos - hero.pos
		if to.length() > hero.radius + b.reach + m.radius + FightRules.AIM_ASSIST_EXTRA:
			continue
		if not meets(hero.pos, m.pos):
			continue
		var off := absf(wrapf(to.angle() - hero.facing, -PI, PI))
		if off < best_off:
			best_off = off
			best = m
	if best != null:
		hero.facing = (best.pos - hero.pos).angle()
	# Held, it is the heavy blow if there is the wind for it; winded, the light one.
	if _swing_heavy and hero.wind >= FightRules.HEAVY_WIND:
		b = b.heavier()
	_swing_heavy = false
	# A capacitor bank carries every CAPACITOR_EVERY-th charged swing itself.
	var carried := false
	if b.wick > 0 and hero.kit.capacitor:
		_charged_swings += 1
		carried = _charged_swings % FightKit.CAPACITOR_EVERY == 0
	var dry := b.wick > 0 and not carried and not FightRules.spend_charges(inv, b.wick)
	if dry:
		b.dry()
	hero.start_swing(b, now)
	_whiff_checked = false
	# The edge wears where it meets something: a swing at air costs wind, not edge.
	_blow_wore = false
	emit(&"swing", {"item": held, "dry": dry, "heavy": b.heavy})


## THE JUMP'S LANDING AS A BLOW. Called by whatever lands a jump (54_gear) with
## the level it took off from. A body in reach of the held blow that stands a
## ledge (FightRules.DROP_LEVELS) or more below that take-off was come down ON,
## whatever step the feet happen to find beside it, and the feet ARE the blow: it
## is live the instant they touch, turned onto the nearest such body, and it
## opens any plate (`cuts`) for that one hit, so a machine that waits under a
## ledge can be come down on from any side. Nothing in reach, or no drop, and it
## was only a landing. Costs no wind: the jump paid for it. True if it struck.
func drop_strike(from_level: int) -> bool:
	if hero.swimming or hero.held() or hero.stunned(now) or hero.committed(now):
		return false
	var b := _held_blow()
	var best: MobState = null
	var best_d := INF
	for m in mobs:
		if not m.alive or m.removed or not meets(hero.pos, m.pos):
			continue
		if from_level - level_of(m.pos) < FightRules.DROP_LEVELS:
			continue
		var d := hero.pos.distance_to(m.pos)
		if d <= hero.radius + b.reach + m.radius and d < best_d:
			best_d = d
			best = m
	if best == null:
		return false
	hero.facing = (best.pos - hero.pos).angle()
	var inv := hero.inventory
	if b.wick > 0 and not FightRules.spend_charges(inv, b.wick):
		b.dry()
	b.windup = 0
	b.cuts = true
	hero.start_blow(b, now)
	_whiff_checked = false
	_blow_wore = false
	emit(&"drop_strike", {"item": inv.held if inv != null else &"", "fell": from_level - level_of(best.pos), "target": best})
	return true


## The blow of whatever is in the hand now, at its edge.
func _held_blow() -> Blow:
	var inv := hero.inventory
	var held: StringName = inv.held if inv != null else &""
	return Blow.for_item(held, inv.edge(held) if inv != null and held != &"" else 10000)


func _dodge() -> void:
	# The keys' way, else a step back still facing the trouble -- under a lock,
	# straight back from what is held. A locked body goes on facing it.
	var dir := LockOn.dodge_way(hero.move, hero.pos, hero.lock, hero.facing)
	if hero.move.length() > 0.1 and not LockOn.locked(hero.lock):
		hero.facing = dir.angle()
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
		var how := _notice(m, look)
		var noticed := how != &""
		_suspicion(m, how)
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


## How the body at `m` has the player this beat: &"seen" in its cone (or all
## round, `look` NAN), &"glimpsed" only out of the corner of its optics behind
## the cone, &"heard", or &"" not at all. The one door is StealthQuery's, split
## so that only sight in front is sure at once.
func _notice(m: MobState, look: float) -> StringName:
	if now < m.calm_until or not StealthQuery.notices(m.row, m.pos, hero.pos, moment, world, query, look):
		return &""
	# Asleep, its optics are dark: only what it hears reaches it.
	if m.asleep:
		return &"heard" if StealthQuery.hears(m.row, m.pos, hero.pos, moment) else &""
	if StealthQuery.sees(m.row, m.pos, hero.pos, moment, world, query, look):
		if is_nan(look) or StealthQuery.in_cone(m.pos, look, hero.pos, StealthQuery.cone_half(m.row)):
			return &"seen"
		if StealthQuery.hears(m.row, m.pos, hero.pos, moment):
			return &"heard"
		return &"glimpsed"
	return &"heard"


## How sure a body is, beat by beat, and where it is looking while it makes up
## its mind. Seen in the open it is sure at once (nothing about a fight
## changes); low in the heather it has to look twice; a noise out of sight
## turns its optics that way and, kept up, brings it over. Drawn on the machine
## (Mob): the working part flickers with it, and the alert snaps at 1.
func _suspicion(m: MobState, how: StringName) -> void:
	if not m.machine:
		# A creature is sure or it is not: making up its mind is a machine's
		# reading, and nothing about a fight with an animal changes here.
		m.suspicion = 1.0 if how != &"" else 0.0
		return
	if how == &"seen":
		var hidden := moment.crouched or moment.cover > HIDDEN_COVER
		m.suspicion = minf(1.0, m.suspicion + (HIDDEN_RISE if hidden else SEEN_RISE))
		m.heard_at = hero.pos
		return
	if how == &"heard" or how == &"glimpsed":
		var rise := HEAR_RISE * (1.0 + NIGHT_HEAR_RISE * moment.nightfall()) if how == &"heard" else GLIMPSE_RISE
		m.suspicion = minf(1.0, m.suspicion + rise)
		if m.suspicion >= 1.0:
			m.asleep = false
		# Unsure enough to go and look: its optics turn to where it had them. A
		# machine at its work does not: it glances and goes on (`_beat`); stood
		# to look, a hauler stopped on its round for someone it only half saw.
		if m.suspicion >= LOOK_AT and not m.at_work():
			if m.look_until <= now or m.heard_at.distance_squared_to(hero.pos) > 1.0:
				emit(&"heard", {"mob": m, "at": hero.pos})
			m.heard_at = hero.pos
			m.look_until = now + LOOK_MS
		return
	if now - noise_ms < StealthNoise.FRESH_MS and StealthQuery.hears_noise(m.row, m.pos, noise_at, noise_radius, moment):
		if m.look_until <= now or m.heard_at.distance_squared_to(noise_at) > 1.0:
			emit(&"heard", {"mob": m, "at": noise_at})
		m.heard_at = noise_at
		m.look_until = now + LOOK_MS
		m.suspicion = minf(1.0, m.suspicion + NOISE_RISE)
		if m.suspicion >= 1.0:
			m.asleep = false
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


## A blow that is not the player's swing: a turret in a holding. It meets the
## rules a swing meets — the plate (`reaches_part` from where it came from), the
## hit window, the flare and the stall, the second act and the nerve — because a
## second way for a body to be hurt would be a second set of rules to keep level
## with the first. What differs is who is standing where: the body turns on the
## place the blow came FROM, and nothing about it is the player's (no swing box,
## no edge worn, no `hit` event — `struck` instead, so the camera, the hitstop
## and every "the player hit something" lesson stay the player's own).
##
## Returns &"hit", &"plate" (it rang off), or &"" (nothing there to strike, or
## still inside the window of the last blow).
func strike(m: MobState, b: Blow, from: Vector2) -> StringName:
	if m == null or b == null or not m.alive or m.removed:
		return &""
	if not reaches_part(m, from, b.cuts):
		emit(&"struck", {"from": from, "target": m, "damage": 0, "plate": true, "at": m.pos})
		_wake(m, &"damaged", from)
		return &"plate"
	if m.invulnerable(now):
		return &""
	_hurt_mob(m, b, from)
	return &"hit"


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
		hero.facing = LockOn.face(hero.facing, hero.pos, hero.lock, dt)
	else:
		var can_run := (not fight_on or hero.wind > FightRules.RUN_WIND_FLOOR) and not hero.crouched
		running = hero.run and can_run and hero.move.length() > 0.1
		var s := hero.run_speed if running else hero.walk_speed
		if hero.crouched:
			s *= Hero.CROUCH_SPEED
		if hero.committed(now):
			s *= hero.blow.creep
		v = LockOn.step(hero.move.limit_length(1.0) * s, hero.pos, hero.lock, dt)
		if hero.committed(now):
			pass
		elif LockOn.locked(hero.lock):
			hero.facing = LockOn.face(hero.facing, hero.pos, hero.lock, dt)
		elif hero.move.length() > 0.1:
			# Just let go of a lock: turned back onto the walk, not snapped to it.
			if now - hero.unlocked_at < LockOn.RELEASE_MS:
				hero.facing = rotate_toward(hero.facing, hero.move.angle(), LockOn.TURN * dt)
			else:
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
	var fall := m.drop_fall(now)
	if fall >= 0.0:
		# Through the air and then down where it said: no ground to go round, and
		# nothing stops a body falling onto the place it chose at the tell.
		var was := m.pos
		m.pos = m.drop_from.lerp(m.drop_at, fall)
		m.speed = was.distance_to(m.pos) / dt
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
	# A stroke is a stroke for anything that swims: a dog that came in after the
	# player crosses at the same share of its pace the player does, or the water
	# is a trap rather than the escape the ruling made it (Swim).
	if world != null and Swim.swims(m.row) and Swim.deep(world, m.pos):
		v *= Tuning.SWIM_FACTOR
	var before := m.pos
	# Deep water stops a body that cannot take it, which is most of the roster
	# (Swim): the few that cross carry it on their own row, not here.
	# A body whose row says it CLIMBS steps that many levels in one move, which is
	# a walker's ride with a longer stride (`CraftRide.levels`, the one field
	# `WorldQuery.passable` already reads for a walker rig). A climber does not
	# swim: the ride answers deep water as a walker would.
	var next := query.move_body(m.pos, v * dt, minf(m.radius, 0.45), climber(m.row), Swim.may_cross(m.row)) if query != null else m.pos + v * dt
	var keeps: Array = m.row.get("keeps_to", [])
	if not keeps.is_empty() and world != null:
		if not _ground_in(next, keeps):
			var nx := Vector2(next.x, m.pos.y)
			var ny := Vector2(m.pos.x, next.y)
			next = nx if _ground_in(nx, keeps) else (ny if _ground_in(ny, keeps) else m.pos)
	m.pos = next
	m.speed = before.distance_to(m.pos) / dt


## Levels a body of this row may step in one move, as a ride, or null for the
## one level everything else takes. `climbs` is a roster key (Roster's schema),
## and a sentinel phase may rewrite it on the live row copy, so a keeper that is
## off the wall stops climbing the moment its phase says so. One ride per stride,
## kept, because this is asked every step of every body.
static var _climbers: Dictionary = {}


static func climber(row: Dictionary) -> CraftRide:
	var n := int(row.get("climbs", 1))
	if n <= 1:
		return null
	if not _climbers.has(n):
		var ride := CraftRide.walker()
		ride.kind = &"climb"
		ride.levels = n
		_climbers[n] = ride
	return _climbers[n]


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
		if not meets(m.pos, hero.pos):
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
			if not meets(hero.pos, m.pos):
				continue
			hero.struck[m.id] = true
			_wear_on_contact()
			# The coil is spent on the first blow that meets the body, needed or not.
			var phased := false
			if phase_ready(m):
				_phase_read[m.id] = true
				phased = not reaches_part(m, hero.pos, b.cuts)
			if not phased and not reaches_part(m, hero.pos, b.cuts):
				if b.heavy and reaches_part(m, hero.pos, b.cuts, true) and now >= m.stall_ready_at:
					_jam(m)
					continue
				hero.throw(hero.pos - m.pos, FightRules.RING_RECOIL, FightRules.RING_RECOIL_MS, now)
				_ring(m)
				continue
			if m.invulnerable(now):
				continue
			# Read through what covers the part, it is a blow in the part like any
			# other, stall and all, for FightKit.PHASE_STALL_MS.
			_hurt_mob(m, b, Vector2.INF, FightKit.PHASE_STALL_MS if phased else FightRules.STALL_MS)
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
		if m.blow.area:
			if not FightRules.drop_hits(m.pos, m.radius, m.blow, hero.pos, hero.radius):
				continue
		elif not FightRules.box_hits(m.pos, m.facing, m.radius, m.blow, hero.pos, hero.radius):
			continue
		if not meets(m.pos, hero.pos):
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


## The level a body stands at, read at its own tile: the one height question a
## blow asks, and never more of the world than where the body stands. The sea's
## surface, not its bed, for a body in it: the same clamp `WorldData.height_at`
## draws a body at, or a swimmer off a shore shelf is out of every blow.
func level_of(p: Vector2) -> int:
	return maxi(0, world.level_at(floori(p.x), floori(p.y))) if world != null else 0


## Are two bodies on levels a blow passes between (FightRules.levels_meet)?
func meets(a: Vector2, b: Vector2) -> bool:
	return FightRules.levels_meet(level_of(a), level_of(b))


## Does a blow from `from` reach this body's working part now? The plate rule,
## and for a `guarded` part (a harvester's blade row, its bite side) only while
## the machine is open: spent after a bite, stopped by a blow, or not yet
## roused. A turning blade row throws a blow off like plate, so walking in
## swinging at the front rings, and the opening is the skill.
## A `heavy` blow goes through the turning blades, and jams them (`_jam`).
func reaches_part(m: MobState, from: Vector2, cuts: bool = false, heavy: bool = false) -> bool:
	if not FightRules.reaches(m.part, m.pos, m.facing, from, cuts):
		return false
	if cuts or heavy or not m.row.get("guarded", false):
		return true
	return m.spent(now) or m.stunned(now) or m.indifferent() or not m.roused()


## The first blow on a body with a phase coil fitted reads its working part
## through whatever covers it (FightKit.phase): plate from any side, and a guard
## the machine is holding closed. Once a body, spent by the first blow that meets
## it whether it needed the read or not, and it stalls the machine as a blow in
## its part does (for FightKit.PHASE_STALL_MS), so it is an
## opener and never a way to win: every blow after it meets the machine as it is,
## and the opening a stall gives stays the reader's to earn.
var _phase_read: Dictionary = {}


## Would a blow on this body now be read through what covers its part? What a
## player with a coil fitted knows: it has not been spent on this body.
func phase_ready(m: MobState) -> bool:
	return hero.kit.phase and not _phase_read.has(m.id) and m.part != &"none" and m.part != &""


## A swing rang off plate. With a harmonic edge fitted it still takes
## FightKit.HARMONIC_DAMAGE (outside the body's hurt frames), and it says so; a
## plate blow never stalls a machine, harmonic or not.
func _ring(m: MobState) -> void:
	var dmg := 0
	if hero.kit.harmonic and not m.invulnerable(now):
		dmg = FightKit.HARMONIC_DAMAGE
		m.health -= dmg
		m.invuln_until = now + m.mob_iframes()
		m.last_hit_at = now
	emit(&"hit", {"attacker": hero, "target": m, "damage": dmg, "plate": true, "at": m.pos})
	if m.health <= 0:
		_kill(m, true)
		return
	_wake(m)


## A blow in the part that lands in a machine's WINDUP breaks the tell: the bite
## never comes. And interrupting a tell is never worse than dodging it, so the
## machine stands spent as if that bite had gone past it, for the bite's own
## recovery and cooldown, and the stall runs alongside: open for the longer of the
## two. A bold read pays at least as well as a safe one
## (tests/fight/test_stall_window.gd). Its box is put past, so nothing lands, and
## it is `opened` as a bite gone by is.
func _break_tell(m: MobState) -> void:
	if m.blow == null or m.blow_phase(now) != &"windup":
		return
	m.blow_at = now - float(m.blow.windup + m.blow.active) - FightRules.SLICE_MS
	m.landed_at = -INF
	m.struck[&"hero"] = true
	m.opened_at = now
	emit(&"opened", {"mob": m})


## A heavy blow into a guarded part the machine was not holding open: the
## turning blades take it, so it does no harm, but they jam, and the machine
## stands stalled as a blow in the part stalls it, its tell lost and its part
## open for what comes next. Once a stall, as any stall. What is bought is the
## opening, not the damage: a heavy thrown at a guard over and over is a slow
## way to do nothing (tests/fight/test_bouts, the player who holds every swing).
func _jam(m: MobState) -> void:
	m.stall_ready_at = now + FightRules.STALL_EVERY_MS
	m.stun_until = maxf(m.stun_until, now + FightRules.STALL_MS)
	m.charging = false
	m.flare_until = now + FightRules.PART_FLARE_MS
	m.dark_until = m.flare_until + FightRules.PART_DARK_MS
	_break_tell(m)
	emit(&"hit", {"attacker": hero, "target": m, "damage": 0, "plate": false, "jammed": true, "at": m.pos})
	_wake(m)


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


## `from` is where the blow came from; INF is the player's own swing.
func _hurt_mob(m: MobState, b: Blow, from: Vector2 = Vector2.INF, stall_ms: int = FightRules.STALL_MS) -> void:
	var player_swing := not is_finite(from.x)
	var source := hero.pos if player_swing else from
	m.struck_from = from
	m.health -= b.dmg
	m.invuln_until = now + m.mob_iframes()
	m.last_hit_at = now
	# A creature has no part to flare: it is hurt at once.
	m.flare_until = now + (FightRules.PART_FLARE_MS if m.machine else 0.0)
	m.dark_until = m.flare_until + FightRules.PART_DARK_MS
	if m.row.get("stagger", false):
		m.throw(m.pos - source, b.knock, b.knock_ms, now)
		if m.blow_phase(now) == &"windup":
			m.blow = null
	elif stall_ms > 0 and m.machine and now >= m.stall_ready_at:
		# A machine never flinches, but a blow in its working part stops the work:
		# the light goes out, a tell in progress is lost, and it stands a moment.
		# Once in a while only, so it is an opening and not a lock.
		m.stall_ready_at = now + FightRules.STALL_EVERY_MS
		m.stun_until = maxf(m.stun_until, now + stall_ms)
		m.charging = false
		_break_tell(m)
	if player_swing:
		emit(&"hit", {"attacker": hero, "target": m, "damage": b.dmg, "plate": false, "at": m.pos})
	else:
		emit(&"struck", {"from": from, "target": m, "damage": b.dmg, "plate": false, "at": m.pos})
	if m.health <= 0:
		_kill(m, player_swing)
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
	_wake(m, &"damaged", source)


## Struck, a body that was not pressing turns on whoever struck it (errands only look).
## `cause` is what the player did (Roles.TURNS). Struck, anything stops and
## deals with it, even a body whose whole trade is to report; anything else
## reaches only a role that takes that cause amiss, and only a role that fights
## is actually turned by it.
##
## `from` is where it was struck from, when that was not the player (INF): it
## looks there first, and finds whoever it finds.
func _wake(m: MobState, cause: StringName = &"damaged", from: Vector2 = Vector2.INF) -> void:
	var turns := Disposition.turned_by(m.role, cause)
	if not turns and cause != &"damaged":
		return
	m.last_seen = hero.pos if not is_finite(from.x) else from
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
	# An ablative plate takes a blow that would hurt instead of the body, and is
	# burnt off doing it (FightKit.ablative): the module leaves the bag, and the
	# gear system takes it out of the loadout when the bag changes.
	if dmg > 0 and hero.kit.ablative and hero.inventory != null and hero.inventory.has(&"mod_ablative"):
		hero.inventory.remove(&"mod_ablative", 1)
		emit(&"ablated", {"at": hero.pos, "damage": dmg})
		dmg = 0
	hero.health -= dmg
	hero.invuln_until = now + FightRules.HURT_IFRAMES_MS
	# A clamp keeps the feet where they stand (FightKit.clamp).
	hero.throw(dir, knock * (FightKit.CLAMP_KNOCK if hero.kit.clamp else 1.0), knock_ms, now)
	hero.last_hit_by = by
	hero.last_hit_at = now
	# A gyro brace carries the swing through the blow (FightKit.gyro).
	if hero.committed(now) and not hero.kit.gyro:
		hero.blow = null
	emit(&"hurt", {"attacker": by, "target": hero, "damage": dmg, "at": hero.pos})


## `by_player`: the player's own blow did it, so the kill is theirs to feel (the
## hitstop, the shake) and the scrap off it is in their hands. A turret's kill in
## a yard is a body lying in the yard.
func _kill(m: MobState, by_player: bool = true) -> void:
	# A leech coil takes a charge back out of what the player puts down.
	if by_player and m.alive and hero.kit.leech and hero.inventory != null:
		hero.inventory.add(FightRules.CHARGE, FightKit.LEECH_CHARGES)
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
	emit(&"killed", {"mob": m, "at": m.pos, "by_player": by_player})


## A dart reached the player: it takes what it came for and runs. Inside
## `Coast.MEETING_GAP` of the last meeting it breaks off instead, taking and
## filing nothing: the gap only shut the darts not yet out, so two already on the
## land (different kinds keep different gaps) met the player twice in nine game
## minutes on seed 1 (test_soak), and a meeting is meant to be rare.
func snatch(m: MobState) -> void:
	if m.snatched:
		return
	m.snatched = true
	if moment != null and moment.minutes - last_meeting_minutes < Coast.MEETING_GAP:
		m.reported = true
		m.flee_home = false
		m.set_mood(MobState.FLEEING, now)
		return
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


## THE ONE DOOR FOR A BLOW THE PLAYER TAKES FROM SOMETHING THAT IS NOT A BODY: a
## hall's turret (21_doors). The mirror of `strike`: it meets the same rules a
## machine's blow does -- nothing lands in the player's hurt frames or through a
## dodge -- and it hurts through the same `_hurt_hero`, with no attacker, so
## everything that reads a hurt (the flash, the shake, the downed outcome) works
## unchanged. `from` is where it came from; returns whether it landed.
func strike_hero(b: Blow, from: Vector2) -> bool:
	if hero.health <= 0 or now < hero.invuln_until or hero.dodging(now):
		return false
	var dir := (hero.pos - from).normalized() if hero.pos.distance_to(from) > 0.01 else Vector2.RIGHT
	_hurt_hero(null, b.dmg, dir, b.knock, b.knock_ms)
	# Called between steps, not inside one: the next step opens by reading the
	# body back (`read_body`), so a hurt left only on the hero would be undone.
	if hero.body != null:
		hero.body.health = hero.health
	return true


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
