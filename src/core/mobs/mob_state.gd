class_name MobState
extends Fighter
## One machine or creature, as data: its roster row, mood, brain timers and
## body. Stepped by FightSim; drawn by a Mob node that only reads it.
##
## Moods (design-extract §7.4):
##   idle / working -> (notices) alerted -> `ready` beats -> chasing -> (in reach) attacking
##   chasing -> fleeing home past `tether`; -> idle after `forget` beats unseen
##   fleeing -> idle once `safe` tiles clear; dead lies `linger` seconds, then goes

const IDLE := &"idle"
const WORKING := &"working"
const ALERTED := &"alerted"
const CHASING := &"chasing"
const ATTACKING := &"attacking"
const FLEEING := &"fleeing"
const DEAD := &"dead"

static var _next_id := 1

var id := 0
var kind: StringName = &""
var row: Dictionary = {}
var alive := true
var mood: StringName = IDLE
var mood_at := 0.0
var home := Vector2.ZERO
var part: StringName = &"none"
var approach: StringName = &"rush"
var machine := false

## Tiles/s: world-layer walking and roused, and close quarters.
var pace := 1.0
var dash := 1.0
var quick := 1.0

var bite: Blow = null
var second_act := false
## Desired velocity from the brain (tiles/s), applied by the sim each slice.
var want := Vector2.ZERO
## Facing the brain wants; the sim turns toward it at turn_rate (rad/s) unless committed.
var aim := 0.0
var turn_rate := 8.0
## A detour around something in the way, until.
var detour := Vector2.ZERO
var detour_until := 0.0
var last_think_pos := Vector2.ZERO
var flee_home := false
## Beats seen or heard in a row / beats since last contact.
var lost_beats := 0
var last_seen := Vector2.ZERO
var calm_until := 0.0
var dead_at := 0.0
var removed := false

# charge
var bearing := Vector2.RIGHT
var charging := false
var run_until := 0.0
var pause_until := 0.0
var run_from := Vector2.ZERO
# lunge
var phase_ms := 0
# errand
var line_a := Vector2.ZERO
var line_b := Vector2.ZERO
var line_to_b := true
var rest_until := 0.0
var closing_since := -1.0
var call_ready_at := 0.0
## The player has been told this one is heard out of sight (Racket).
var heard_told := false
# dart
var snatched := false
var reported := false
## A blow reached the part: it flares, lit, until flare_until, then is dark
## (hurt) until dark_until. View reads.
var dark_until := 0.0
var flare_until := 0.0
## A real hit may stall this machine again from this time.
var stall_ready_at := 0.0
## When the last bite ended and the machine went spent (sim ms): the view flares
## the working part once for it, so the opening is seen and not only timed.
var opened_at := -INF
## blow_at of the bite that last met the player (a landed bite is not spent).
var landed_at := -INF
## How it takes the player (VISION §2): &"hostile" hunts, &"indifferent" works
## on unless disturbed, &"observant" watches and reports, &"wary" keeps a site.
var disposition: StringName = &"hostile"
## Its place in the machines' plan (Roles): worker keeper watcher hunter recycler.
## The role never changes; the disposition above is what the role, the region's
## interference and what the player has done to this body add up to.
var role: StringName = &"hunter"
## How sure it is that something is there, 0..1. Sight fills it in one beat;
## a noise fills it slowly, and it drains when nothing comes of it. At 1 the
## body is sure and the alert pose snaps (drawn on the machine, never as text).
var suspicion := 0.0
## Where the last noise it heard came from, and the sim ms until which its
## optics are turned that way.
var heard_at := Vector2.ZERO
var look_until := -INF
## Why it turned on the player, for the interference the network files.
var disturbed_by: StringName = &""
## The network has already been told what this body took amiss (once only).
var turn_filed := false
## The network sent this body after the player. It is not news to the network
## that sent it when it does not come back: a player who fights off what was
## dispatched must be able to cool the region by breaking contact.
var sent := false
## One of a party sent against a holding (48_raids). It is not a wanderer, so the
## coast never culls it: the system that sent it takes it off the land when the
## step is over or the player leaves the yard. Without this, the cheapest answer
## to any raid was to walk twenty-five tiles and let the culler eat the party.
var raider := false
## Where the last blow that hurt it came from, when that was NOT the player's own
## swing (FightSim.strike: a turret); INF when it was the player's, or never. A
## party body hurt by the yard goes for what shot it and one hurt by the player
## goes for the player (48_raids), so the two must be told apart.
var struck_from := Vector2.INF
## An indifferent body the player has disturbed (struck it, stood in its way):
## it is hostile until it loses them.
var disturbed := false
## Sim ms until which a body that noticed the player only looks up.
var glance_until := -INF
## Sim ms since which the player has held up an indifferent body on its round (-1 = not).
var crowded_since := -1.0
## It has warned the player standing in its way (half way to taking it as interference).
var crowd_warned := false
## A point beside someone standing on its round that it walks to first, going
## round them (Vector2.INF: none).
var via := Vector2.INF
## Sim ms before which it will not try going round again (the last way round was blocked).
var via_retry_at := 0.0
## Put out by the coast to be seen on its round (a patrol), or as the first meeting.
var patrol := false
var first_meeting := false
## Times a patrol has carried its round on past the end of its line (Coast).
var legs := 0
## Sim ms it was put out on the coast (patrols come off the land after a while).
var put_out_at := 0.0
## Last time this body moved meaningfully (for the view's walk cycle).
var speed := 0.0


func _init(kind_id: StringName = &"", at: Vector2 = Vector2.ZERO, seed_value: int = 0) -> void:
	id = _next_id
	_next_id += 1
	if kind_id == &"":
		return
	kind = kind_id
	row = Roster.row(kind_id)
	pos = at
	home = at
	radius = row.get("radius", 0.4)
	part = row.get("part", &"none")
	approach = row.get("approach", &"rush")
	machine = row.get("machine", false)
	max_health = Roster.health_of(kind_id)
	health = max_health
	pace = float(row.get("pace", 1.0)) * FightRules.SPEED_SCALE
	dash = float(row.get("dash", row.get("pace", 1.0))) * FightRules.SPEED_SCALE
	quick = float(row.get("quick", 0)) / 100.0
	if quick <= 0.0:
		quick = dash
	bite = Roster.bite(kind_id)
	# Hashed from where it came into the world, so a seed and a place give the same body.
	var hx := floori(at.x * 8.0)
	var hy := floori(at.y * 8.0)
	phase_ms = int(Rng.hash01(seed_value, hx, hy, 0x10) * 1000.0)
	facing = Rng.hash01(seed_value, hx, hy, 0x11) * TAU
	# The bearing it keeps while nothing is happening: a charge overwrites this
	# when it commits, and a body that sweeps its optics sweeps about it.
	bearing = Vector2.from_angle(facing)
	mood = WORKING if approach == &"errand" else IDLE
	role = Roles.of_row(row)
	disposition = Roster.disposition(kind_id)
	aim = facing
	last_think_pos = at
	# Charges turn badly (that is the whole answer to them); errands sweep slowly.
	# Every machine turns slower than a player walks round it at close quarters
	# (about 2.8 rad/s at a tile and a bit), so its working side can be reached.
	match approach:
		&"charge": turn_rate = 1.5
		&"errand": turn_rate = 1.6
		_: turn_rate = 2.4 if machine else 9.0
	var stretch: float = row.get("stretch", 0)
	if stretch <= 0.0 and approach != &"errand" and machine and kind != &"cutter":
		# Idle machines keep to a beat of their own: up the row and back.
		stretch = 6.0
	var axis := Vector2.from_angle(roundf(facing / (PI * 0.5)) * PI * 0.5)
	line_a = at - axis * stretch
	line_b = at + axis * stretch


func stat(key: String, fallback: Variant = 0) -> Variant:
	return row.get(key, fallback)


func health_fraction() -> float:
	return float(health) / maxf(1.0, float(max_health))


func set_mood(m: StringName, now: float) -> void:
	if mood == m:
		return
	mood = m
	mood_at = now


func roused() -> bool:
	return mood == CHASING or mood == ATTACKING


## Hostile to the player in the sense of a fight: not a dart, and pressing.
func engaged() -> bool:
	return alive and not removed and approach != &"dart" and (roused() or (approach == &"errand" and closing_since >= 0.0))


func part_flaring(now: float) -> bool:
	return now < flare_until


func part_dark(now: float) -> bool:
	return now >= flare_until and now < dark_until


## Spent after a bite: its recovery and cooldown. A machine carries on past
## where it bit, then stands turning slowly; its working part is open.
func spent(now: float) -> bool:
	if blow == null or landed_at == blow_at:
		return false
	var p := blow_phase(now)
	return p == &"recovery" or p == &"cooldown"


## Radians per second it may turn now: slowly while spent or standing between
## runs (machines only; a creature has no side to find).
func turn_rate_at(now: float) -> float:
	if not machine:
		return turn_rate
	if at_work() and crowded_since >= 0.0:
		# A worker held up, looking round at what is in its way: unhurried, not a turret.
		return minf(turn_rate, FightRules.PAUSE_TURN)
	if blow_phase(now) == &"cooldown":
		return minf(turn_rate, float(row.get("recover_turn", FightRules.RECOVER_TURN)))
	if now < pause_until:
		return minf(turn_rate, FightRules.PAUSE_TURN)
	return turn_rate


## Which way it is going along its round (a unit vector), or ZERO for a body
## that stands. At the end of a leg it is the next leg: a worker about to turn
## back is about to come the other way.
func path_dir() -> Vector2:
	if via.is_finite() and via.distance_to(pos) >= 0.3:
		return (via - pos).normalized()
	if line_a.distance_squared_to(line_b) < 0.01:
		return Vector2.ZERO
	var target := line_b if line_to_b else line_a
	var to := target - pos
	if to.length() < 0.3:
		to = (line_a if line_to_b else line_b) - pos
	return to.normalized() if to.length() > 0.01 else Vector2.ZERO


## Works on whatever the player does, until disturbed.
func indifferent() -> bool:
	return disposition == &"indifferent" and not disturbed


## The middle rung (VISION §2): it keeps to its work and will not leave it for
## someone keeping their distance, but it looks up constantly, its working part
## never settles, and it lets nobody inside its guard. A keeper is born here;
## a worker is raised to it by the interference of its region.
func watchful() -> bool:
	return Disposition.watchful(disposition) and not disturbed


## At its work, whatever it makes of the player: it has not left its round.
func at_work() -> bool:
	return indifferent() or watchful()


func mob_iframes() -> int:
	return mini(int(row.get("invuln", 300)), FightRules.MOB_IFRAMES_CAP_MS)
