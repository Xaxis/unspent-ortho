class_name WalkerClimb
extends RefCounted
## THE CLIMB UP A WALKER (ROADMAP slice 3 step 7): pure and headless, one climb in
## progress. The body is never placed in the world by coordinates: it holds a
## PITCH and a HOLD on it, and where that is in metres is the posed bone's
## (ColossusWalk.pose) at the minute asked, so the gait carries him for free and a
## planted foot holds him still.
##
## At true scale the hub is 52 km up, about a day of climbing, so the leg is a
## few short gripped PITCHES (PITCHES: real levels, climbed hold by hold) joined
## by RIDES inside the bone (service ladders and lifts, seconds, not kilometres)
## that run only while his leg is planted.
##
##   begin(leg, seed) -> WalkerClimb    on the heel of leg `leg`, at the drum's foot
##   step(dt, pose, up) -> Array[StringName]   dt real seconds; `up` asks for the next hold.
##       Events: moved (reached a hold), rested (a pitch's top), rode (a ride began),
##       slipped (out of breath, down to the stance below), quake (his leg set down
##       under him), fell (shaken off: caught at the pitch's foot, `wound` and
##       `lost_minutes` set), at_hub (the climb is over)
##   world_pos(def, pose) -> Vector3    where the body is, in world metres
##   surface_at(def, pitch, up_m, theta, lift) -> Vector3   a point on a pitch, bone-local
##
## Breath is the grip (FightRules.WIND): a move up costs Climb.WIND_PER_LEVEL a
## level at Climb.RATE; hanging on an ordinary hold drains HANG_DRAIN a second,
## SWING_DRAIN_TIMES that while his leg swings, when no move is allowed; a
## STANCE (a ledge, every STANCE_EVERY levels, and every pitch's foot) gives
## breath back. Out of breath he slides to the stance below. Nothing up here
## kills: a fall is caught by a cable at the pitch's foot, wounded, and time
## passes (owner ruling 2026-09-30).

enum { CLIMB, RIDE, DONE }

## Which bone of a leg (pose.bones: 0 the hub, then thigh, shin, foot per leg).
const THIGH := 1
const SHIN := 2
const FOOT := 3
const HUB := 0

## The route up, foot to hub. `at` is where on the bone the pitch starts (the
## share of its length from its root), `levels` how high it climbs, `ride` the
## real seconds inside the bone to the next pitch's foot.
const PITCHES: Array[Dictionary] = [
	{"id": &"drum", "bone": FOOT, "levels": 40, "ride": 60.0},
	{"id": &"knee", "bone": SHIN, "at": 0.02, "levels": 30, "ride": 30.0},
	{"id": &"thigh", "bone": THIGH, "at": 0.5, "levels": 60, "ride": 40.0},
	{"id": &"hip", "bone": THIGH, "at": 0.03, "levels": 40, "ride": 30.0},
	{"id": &"hatch", "bone": HUB, "levels": 30, "ride": 0.0},
]

const LEVEL := 0.5
## Holds are this many levels apart; every STANCE_EVERY levels one is a ledge.
const HOLD_EVERY := 2
const STANCE_EVERY := 10
## How far round the bone a hold may wander from the line, in metres of surface.
const WANDER := 3.0
## A swing lasts about 107 real seconds: at these a whole one costs about 1,900
## breath, so a climber caught between ledges with half a breath slips and one
## who set off on a full breath hangs on. Reading the gait is the skill.
const HANG_DRAIN := 6.0
const SWING_DRAIN_TIMES := 3.0
const STANCE_REGEN := 150.0
## Under this breath when his leg sets down, the quake shakes him off.
const SLIP_BELOW := 400.0
## The ankle drum's radius, and how far out from the hub's centre the hatch is.
const DRUM_R := 150.0
const HATCH_R := 1800.0
## A fall's cost: a wound per FALL_LEVELS levels fallen, at most WOUND_MOST, and
## the world minutes spent hanging on the cable before he climbs on.
const FALL_LEVELS := 10
const WOUND_MOST := 4
const CAUGHT_MINUTES := 30.0
const SALT := 0x57c1

var leg := 0
var seed_value := 0
var state := CLIMB
var pitch := 0
var hold := 0
var breath := FightRules.WIND
## Seconds left of the move under way (0 = hanging), or of the ride.
var busy := 0.0
var wound := 0
var lost_minutes := 0.0
var _was_swinging := false
## The one body design's leg taper, for a hold's wander round the bone.
static var _tripod: RefCounted = null


static func begin(leg_index: int, world_seed: int) -> WalkerClimb:
	var c := WalkerClimb.new()
	c.leg = leg_index
	c.seed_value = world_seed
	return c


## Hold `i` of pitch `p`: Vector2(level up the pitch, angle round the bone).
func hold_at(p: int, i: int) -> Vector2:
	var r := _radius(PITCHES[p], 0.0)
	var drift := (Rng.hash01(seed_value, SALT, leg, p, i) - 0.5) * 2.0 * WANDER / maxf(1.0, r)
	return Vector2(float(i * HOLD_EVERY), drift)


func holds_in(p: int) -> int:
	return int(PITCHES[p].levels) / HOLD_EVERY + 1


func is_stance(i: int) -> bool:
	return (i * HOLD_EVERY) % STANCE_EVERY == 0


func swinging(pose: Dictionary) -> bool:
	return int(pose.get("swinging", -1)) == leg


func step(dt: float, pose: Dictionary, up: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	if state == DONE:
		return out
	var swing := swinging(pose)
	var landed := _was_swinging and not swing
	_was_swinging = swing
	if state == RIDE:
		# The lift runs only while the leg stands.
		if not swing:
			busy -= dt
		if busy <= 0.0:
			state = CLIMB
			pitch += 1
			hold = 0
			busy = 0.0
		return out
	if landed:
		out.append(&"quake")
		if breath < SLIP_BELOW and not is_stance(hold):
			_fall(out)
			return out
	if busy > 0.0:
		busy -= dt
		if busy <= 0.0:
			busy = 0.0
			hold += 1
			out.append(&"moved")
			if hold >= holds_in(pitch) - 1:
				_top(out)
		return out
	if is_stance(hold):
		breath = minf(FightRules.WIND, breath + STANCE_REGEN * dt)
	else:
		breath -= HANG_DRAIN * dt * (SWING_DRAIN_TIMES if swing else 1.0)
		if breath <= 0.0:
			breath = 0.0
			while hold > 0 and not is_stance(hold):
				hold -= 1
			out.append(&"slipped")
			return out
	var cost := Climb.WIND_PER_LEVEL * HOLD_EVERY
	if up and not swing and breath >= cost:
		breath -= cost
		busy = float(HOLD_EVERY) / Climb.RATE
	return out


func _top(out: Array[StringName]) -> void:
	out.append(&"rested")
	if pitch >= PITCHES.size() - 1:
		state = DONE
		out.append(&"at_hub")
		return
	state = RIDE
	busy = float(PITCHES[pitch].ride)
	out.append(&"rode")


func _fall(out: Array[StringName]) -> void:
	var fallen := hold * HOLD_EVERY
	wound = clampi(ceili(float(fallen) / FALL_LEVELS), 1, WOUND_MOST)
	lost_minutes = CAUGHT_MINUTES
	hold = 0
	busy = 0.0
	breath = 0.0
	out.append(&"fell")


## Where the body is, in world metres, on the posed bone.
func world_pos(def: RefCounted, pose: Dictionary) -> Vector3:
	var p := mini(pitch, PITCHES.size() - 1)
	var h := hold_at(p, hold)
	var t: Transform3D = (pose.bones as Array)[bone_index(p)]
	return t * surface_at(def, p, h.x * LEVEL, h.y, 0.0)


## Which of pose.bones pitch `p` is climbed on (0 the hub, then thigh, shin,
## foot per leg).
func bone_index(p: int) -> int:
	var b := int(PITCHES[p].bone)
	return 0 if b == HUB else 1 + 3 * leg + (b - 1)


## A point on pitch `p`'s surface in its bone's own frame: `up_m` metres up the
## pitch from its foot, `theta` round the bone, `lift` metres proud of the
## surface. The one place the climb's geometry is decided, so what the leg is
## drawn with (colossus_leg_model.gd) and where the body hangs cannot part.
func surface_at(def: RefCounted, p: int, up_m: float, theta: float, lift: float) -> Vector3:
	var row: Dictionary = PITCHES[p]
	var b := int(row.bone)
	if b == HUB:
		var under := float(def.hub_low) - float(def.hip_height)
		return Vector3(cos(theta) * (HATCH_R + lift), under + up_m, sin(theta) * (HATCH_R + lift))
	if b == FOOT:
		return Vector3(cos(theta) * (DRUM_R + lift), -float(def.ankle_up) + up_m, sin(theta) * (DRUM_R + lift))
	# A thigh runs hip to knee and a shin knee to ankle, each with its Y down the
	# leg: climbing is toward the bone's root, up its -Y.
	var length := float(def.thigh) if b == THIGH else float(def.shin)
	var along := clampf(float(row.get("at", 0.0)) * length - up_m, 0.0, length)
	var r := _radius(row, along / length) + lift
	return Vector3(cos(theta) * r, along, sin(theta) * r)


func _radius(row: Dictionary, share: float) -> float:
	match int(row.bone):
		FOOT:
			return DRUM_R
		HUB:
			return HATCH_R
	if _tripod == null:
		_tripod = (load("res://src/core/colossus/colossus_def.gd") as GDScript).call(&"tripod", &"C")
	var taper: Vector2 = _tripod.thigh_r if int(row.bone) == THIGH else _tripod.shin_r
	return lerpf(taper.x, taper.y, share)
