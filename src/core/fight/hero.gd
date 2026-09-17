class_name Hero
extends Fighter
## The player as a fighter: swing, dodge, wind, grip. The rules of when a verb
## is refused live here (design-extract §6.4); movement and blows landing live
## in FightSim. Body is the shared record the HUD and survival read, so the
## hero reads it at the start of every step and writes it back at the end.

var body: Body
var inventory: Inventory

var wind := FightRules.WIND
var max_wind := FightRules.WIND
var dodge_at := -100000.0
var dodge_dir := Vector2.ZERO
## >0 while something has hold: pulls remaining. The holder is the body that seized.
var grip := 0
var grip_since := 0.0
var holder: Fighter = null
var last_pull := -100000.0

## Intent for the next slices (world space, length <= 1) and whether Shift is held.
var move := Vector2.ZERO
var run := false
## Tiles per second actually moved in the last slice.
var speed := 0.0
## The tiles/s the ground and body allow walking, set by the owner of movement.
var walk_speed := 3.4
var run_speed := 5.4
## Down in the heather (Body.crouched, read every step): slower, and no running.
## What crouching does to being seen and heard is StealthQuery's and Noise's.
var crouched := false
## What is left of a walk while crouched.
const CROUCH_SPEED := 0.45
## What a blow takes off, as a share of its damage (a configuration's
## `rules.harm`): 0 and nothing can down the player.
var harm := 1.0
## The craft carrying this body, or null on foot (src/core/craft/). It changes
## what the ground under the body means and nothing else: the simulation still
## moves the body, so a blow, a dodge and a grip are the same on a deck as on
## land. The crafts package (src/systems/44_crafts.gd) is the only writer.
var ride: CraftRide = null


func _init() -> void:
	radius = Tuning.PLAYER_RADIUS
	health = FightRules.HEALTH
	max_health = FightRules.HEALTH


## Tiles/s on the ground under `p`: walking or running, wading slower, a worn body
## slower. A craft under the body sets the pace instead of the ground: that is
## what a hover sled is for, and the ONE thing a ride changes about speed.
static func ground_speed(world: WorldData, p: Vector2, running: bool, move_factor: float = 1.0,
		on: CraftRide = null) -> float:
	if on != null:
		return on.speed(running) * clampf(move_factor, 0.2, 1.5)
	var s := Tuning.RUN_SPEED if running else Tuning.WALK_SPEED
	if world != null and world.ground_at(floori(p.x), floori(p.y)) == Ground.WATER:
		s *= Tuning.WADE_FACTOR
	return s * clampf(move_factor, 0.2, 1.5)


## Health is the one fight number others may change (eating, mending, waking
## downed), so it is read back; wind and grip only ever change in here.
func read_body() -> void:
	if body == null:
		return
	health = body.health
	crouched = body.crouched
	var plated := FightRules.wears(inventory, &"plate")
	max_health = FightRules.max_health(plated)
	max_wind = FightRules.max_wind(FightRules.wears(inventory, &"brace"), body.move_factor)
	wind = minf(wind, max_wind)


## Body's times are seconds of real time; `real_s` is the real second that `now` is.
func write_body(now: float, real_s: float) -> void:
	if body == null:
		return
	body.health = health
	body.max_health = max_health
	body.wind = wind
	body.max_wind = max_wind
	body.grip = grip
	body.grip_since = real_s + (grip_since - now) / 1000.0
	body.invuln_until = real_s + maxf(0.0, invuln_until - now) / 1000.0
	body.stun_until = real_s + maxf(0.0, stun_until - now) / 1000.0
	body.dodging = dodging(now)


func dodging(now: float) -> bool:
	return now - dodge_at < FightRules.DODGE_MS


func dodge_locked(now: float) -> bool:
	return now - dodge_at < FightRules.DODGE_LOCK_MS


func invulnerable(now: float) -> bool:
	return now < invuln_until or FightRules.dodge_invulnerable(now - dodge_at)


func held() -> bool:
	return grip > 0


## &"" when a swing may start now, else why not.
func swing_refusal(now: float) -> StringName:
	if held():
		return &"held"
	if stunned(now):
		return &"stunned"
	if locked_out(now):
		return &"locked"
	if dodge_locked(now):
		return &"dodge_locked"
	return &""


## &"" when a dodge may start now, else why not.
func dodge_refusal(now: float) -> StringName:
	if held():
		return &"held"
	if stunned(now):
		return &"stunned"
	if committed(now):
		return &"swinging"
	if dodge_locked(now):
		return &"dodge_locked"
	if wind < FightRules.DODGE_COST:
		return &"winded"
	return &""


func start_swing(b: Blow, now: float) -> void:
	start_blow(b, now)
	wind = maxf(0.0, wind - b.wind_cost)


func start_dodge(dir: Vector2, now: float) -> void:
	dodge_at = now
	dodge_dir = dir.normalized() if dir.length() > 0.01 else Vector2.from_angle(facing)
	wind -= FightRules.DODGE_COST


## One wrench against a grip. Returns true if it counted. A cutting tool takes two.
func pull(now: float, cut: bool) -> bool:
	if not held() or now - last_pull < FightRules.PULL_GAP_MS:
		return false
	last_pull = now
	grip = maxi(0, grip - (2 if cut else 1))
	if grip == 0:
		holder = null
	return true


## Seized: no damage, no knock, no i-frames, no restacking.
func seize(by: Fighter, pulls: int, now: float) -> bool:
	if held() or pulls <= 0:
		return false
	grip = pulls
	grip_since = now
	holder = by
	last_pull = -100000.0
	return true


func release() -> void:
	grip = 0
	holder = null
