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
# dart
var snatched := false
var reported := false
## Part dark (hurt) until; part flared (a blow reached it) until. View reads.
var dark_until := 0.0
var flare_until := 0.0
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
	mood = WORKING if approach == &"errand" else IDLE
	aim = facing
	last_think_pos = at
	# Charges turn badly (that is the whole answer to them); errands sweep slowly.
	match approach:
		&"charge": turn_rate = 2.4
		&"errand": turn_rate = 1.6
		_: turn_rate = 9.0
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


func mob_iframes() -> int:
	return mini(int(row.get("invuln", 300)), FightRules.MOB_IFRAMES_CAP_MS)
