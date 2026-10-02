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
##   begin(leg, seed) -> WalkerClimb    at the foot of leg `leg`'s cable, in the tread
##   step(dt, pose, up) -> Array[StringName]   dt real seconds; `up` asks for the next hold.
##       Events: moved (reached a hold), rested (a pitch's top), rode (a ride began),
##       onto (straight on up the next pitch, where there is no ride),
##       slipped (out of breath, down to the stance below), quake (his leg set down
##       under him), fell (shaken off: caught at the pitch's foot, `wound` and
##       `lost_minutes` set), at_hub (the climb is over)
##   world_pos(def, pose) -> Vector3    where the body is, in world metres
##   surface_at(def, pitch, up_m, theta, lift) -> Vector3   a point on a pitch, bone-local
##
## Breath is the grip (FightRules.WIND): a move up costs Climb.WIND_PER_LEVEL a
## level at Climb.RATE (times a pitch's own `wind` and `pace`); hanging on an
## ordinary hold drains HANG_DRAIN a second, SWING_DRAIN_TIMES that while his
## leg swings, when no move is allowed; a STANCE (a ledge, every STANCE_EVERY
## levels, and every pitch's foot) gives breath back. Out of breath he slides to the stance below. Nothing up here
## kills: a fall is caught by a cable at the pitch's foot, wounded, and time
## passes (owner ruling 2026-09-30).

const Def := preload("res://src/core/colossus/colossus_def.gd")

enum { CLIMB, RIDE, DONE }

## Which bone of a leg (pose.bones: 0 the hub, then thigh, shin, foot per leg).
const THIGH := 1
const SHIN := 2
const FOOT := 3
const HUB := 0

## The route up, ground to hub. On the thigh and the shin `at` is where the pitch
## starts as a share of the bone from its root, and it climbs toward the root; on
## the foot and the hub `from` is the height up the bone's own Y it starts at.
## `levels` is how high it climbs and `ride` the real seconds inside the bone to
## the next pitch's foot; 0 goes straight on up the next one from its foot.
##
## IT BEGINS ON THE GROUND. The line's cable hangs from the drum's foot, down the
## belt and free to the tread the middle toe stands in (HANG_FOOT), a man's reach
## over its floor beside the pad: he walks to it and takes it (43_climb), climbs
## it hold to hold as any pitch, its ledges seats clamped to it, and at its top is
## at the drum's foot. The drum and the cable are turned FOOT_TURN off the middle
## toe, so the cable hangs clear of the toe, its heel joint and its pad's claws.
## The cable is knotted, with a loop for a foot at every level, so it is climbed
## at `pace` times the plate's rate for `wind` of its breath: at the plate's own
## it was ninety metres more and the whole climb 23 minutes, past the set
## piece's twenty. The walker's limp (ColossusDef.limp) took it from twice to
## three times.
##
## EACH IS ON A CLEAN RUN OF PLATE, with the patch drawn round it
## (colossus_leg_model.gd, HALF_W either side and MARGIN past each end): clear of
## the sleeves, the knee's flange and ball, the hip's drive ring and its struts
## and the thigh's beacons (colossus_model.gd); on the drum between the belt's
## top edge and the lip's, whose sharp creases a flat plate would cut; on the hub,
## on the rim's upright band under its top edge. tests/render/test_walker_leg.gd
## holds every one of them to the body it is drawn on.
const PITCHES: Array[Dictionary] = [
	{"id": &"cable", "bone": FOOT, "from": -119.0, "levels": 180, "ride": 0.0, "hang": true, "pace": 3.0, "wind": 0.5},
	{"id": &"drum", "bone": FOOT, "from": -29.0, "levels": 30, "ride": 60.0},
	{"id": &"knee", "bone": SHIN, "at": 0.05, "levels": 30, "ride": 30.0},
	{"id": &"thigh", "bone": THIGH, "at": 0.40, "levels": 60, "ride": 40.0},
	{"id": &"hip", "bone": THIGH, "at": 0.12, "levels": 40, "ride": 30.0},
	{"id": &"hatch", "bone": HUB, "from": 356.0, "levels": 30, "ride": 0.0},
]

const LEVEL := 0.5
## Holds are this many levels apart; every STANCE_EVERY levels one is a ledge.
const HOLD_EVERY := 2
const STANCE_EVERY := 10
## How far round the bone a hold may wander from the line, in metres of surface.
const WANDER := 3.0
## A sound leg's swing lasts about 107 real seconds and the lame one's, the leg
## the climb goes up (ColossusDef.limp), about 139: at these a whole lame one
## costs about 2,000 breath, so a climber caught between ledges with half a
## breath slips and one who set off on a full breath hangs on. Reading the gait
## is the skill.
const HANG_DRAIN := 6.0
const SWING_DRAIN_TIMES := 2.4
## On a ledge the breath comes back this fast. The lame leg stands a fifth less
## of each cycle than a sound one, and at 150 the waiting for breath on ledges
## put the set piece at 23 minutes; the swings and the rides are its drama, and
## the waiting is not.
const STANCE_REGEN := 250.0
## Under this breath when his leg sets down, the quake shakes him off.
const SLIP_BELOW := 400.0
## A pitch's surface stands this far proud of the flat of the body under it, so
## the two never fight for a pixel.
const SKIN := 0.1
## The hatch is on the hub's rim this many degrees round from the leg's own hip,
## on the middle of the nearest flat of the hull: clear of the outrigger the hip
## hangs on and of the lens that faces the way it walks.
const HATCH_TURN := -22.5
## The foot's pitches run this many degrees round from the middle toe (bearing 0
## of the foot's frame), and the cable hangs from the belt's foot (BELT_Y) out to
## its own foot, HANG_FOOT_R from the ankle's axis at the height its pitch starts.
const FOOT_TURN := 7.0
const BELT_Y := -52.0
const HANG_FOOT_R := 190.0
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
## The one body design, for a hold's wander round the bone.
static var _tripod: RefCounted = null


static func begin(leg_index: int, world_seed: int) -> WalkerClimb:
	var c := WalkerClimb.new()
	c.leg = leg_index
	c.seed_value = world_seed
	return c


## Hold `i` of pitch `p`: Vector2(level up the pitch, angle round the bone). A
## hanging cable's holds are on it, and so is the hold a cable hands him on to.
func hold_at(p: int, i: int) -> Vector2:
	if _tripod == null:
		_tripod = Def.tripod(&"C")
	if PITCHES[p].has("hang") or (i == 0 and p > 0 and float(PITCHES[p - 1].ride) <= 0.0):
		return Vector2(float(i * HOLD_EVERY), 0.0)
	var r := _radius(_tripod, PITCHES[p], _height(_tripod, p, 0.0), 0.0)
	var drift := (Rng.hash01(seed_value, SALT, leg, p, i) - 0.5) * 2.0 * WANDER / maxf(1.0, r)
	return Vector2(float(i * HOLD_EVERY), drift)


## Which pitch is called `id` (-1 for none).
static func pitch_of(id: StringName) -> int:
	for i in PITCHES.size():
		if PITCHES[i].id == id:
			return i
	return -1


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
	var cost := Climb.WIND_PER_LEVEL * HOLD_EVERY * float(PITCHES[pitch].get("wind", 1.0))
	if up and not swing and breath >= cost:
		breath -= cost
		busy = move_secs(pitch)
	return out


## Real seconds a move from one hold to the next takes on pitch `p`.
static func move_secs(p: int) -> float:
	return float(HOLD_EVERY) / (Climb.RATE * float(PITCHES[p].get("pace", 1.0)))


func _top(out: Array[StringName]) -> void:
	out.append(&"rested")
	if pitch >= PITCHES.size() - 1:
		state = DONE
		out.append(&"at_hub")
		return
	if float(PITCHES[pitch].ride) <= 0.0:
		pitch += 1
		hold = 0
		out.append(&"onto")
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
## pitch from its foot, `theta` round the bone from its line, `lift` metres proud
## of the surface. The one place the climb's geometry is decided, so what the leg
## is drawn with (colossus_leg_model.gd) and where the body hangs cannot part; and
## the surface is the body's own turned profile (ColossusDef), SKIN proud of the
## flat it is on, so neither can part from the machine either.
func surface_at(def: RefCounted, p: int, up_m: float, theta: float, lift: float) -> Vector3:
	var y := _height(def, p, up_m)
	var a := theta + _bearing(def, p)
	var r := _radius(def, PITCHES[p], y, a) + SKIN + lift
	return Vector3(cos(a) * r, y, sin(a) * r)


## Where `up_m` up pitch `p` is on its bone's Y. A thigh runs hip to knee and a
## shin knee to ankle, each with its Y down the leg, so climbing them is toward
## the root, up -Y.
func _height(def: RefCounted, p: int, up_m: float) -> float:
	var row: Dictionary = PITCHES[p]
	match int(row.bone):
		FOOT, HUB:
			return float(row.from) + up_m
	var length := float(def.thigh) if int(row.bone) == THIGH else float(def.shin)
	return clampf(float(row.at) * length - up_m, 0.0, length)


## Which way round its bone pitch `p`'s line runs: out along the leg's own +X,
## on the foot FOOT_TURN round from it, and on the hub a flat round from the
## leg's hip (HATCH_TURN).
func _bearing(def: RefCounted, p: int) -> float:
	if int(PITCHES[p].bone) == FOOT:
		return deg_to_rad(FOOT_TURN)
	if int(PITCHES[p].bone) != HUB:
		return 0.0
	var flat := TAU / float(Def.HULL_SIDES)
	return roundf(deg_to_rad(float(def.slots[leg]) + HATCH_TURN) / flat) * flat


## How far out of its bone's axis the body is at height `y` and bearing `a`. A
## hanging cable runs straight from the belt's foot out to its own.
static func _radius(def: RefCounted, row: Dictionary, y: float, a: float) -> float:
	match int(row.bone):
		FOOT:
			if row.has("hang") and y < BELT_Y:
				var belt := Def.turned_radius(def.drum_profile(), Def.DRUM_SIDES, BELT_Y, a)
				return lerpf(belt, HANG_FOOT_R, (BELT_Y - y) / (BELT_Y - float(row.from)))
			return Def.turned_radius(def.drum_profile(), Def.DRUM_SIDES, y, a)
		HUB:
			return Def.turned_radius(def.hull_profile(), Def.HULL_SIDES, y, a)
		THIGH:
			return Def.turned_radius(def.thigh_profile(), Def.LEG_SIDES, y, a)
	return Def.turned_radius(def.shin_profile(), Def.LEG_SIDES, y, a)
