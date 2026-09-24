extends RefCounted
## WHERE ONE COLOSSUS WALKS: a ring on the world, dealt from the seed.
##
## A pure function of (seed, world size, the body's circuit), so it is never
## saved and never drifts: the same world always has its walkers on the same
## rings, and where one IS on its ring is a function of the world clock alone
## (colossus_walk.gd). That is FlierView's rule at a larger scale, for the same
## reason -- a player who walks away and comes back finds it where it should
## have got to, and two shots of one moment are one picture.
##
## THE RING IS WALKED IN WHOLE CYCLES. Its circumference is divided into a whole
## number of hub advances, so after `cycles()` gait cycles every foot is back on
## the plant it started from and the whole walk is periodic (`lap_minutes`).
##
## Positions are world XZ in world units (metres), `Vector2(x, z)`.

var centre := Vector2.ZERO
var radius := 1.0
## Where on the ring the lap starts, 0..1, and which way round it goes (+1 or -1).
var phase := 0.0
var sense := 1.0
## World minutes the walk's own clock runs ahead of the world's, so two walkers
## on one world are never in step: one sets a foot down while another lifts.
var offset := 0.0
var _cycles := 1
var _cycle_minutes := 1.0
## THE TREADS THE LAND WAS MADE WITH (src/core/colossus/colossus_treads.gd): the
## plants of this walk that come down on the island, keyed by `tread_key`, each
## Vector4(x, the crater floor's height, z, the foot's yaw). World generation
## sites them and cuts their craters; a walk handed them steps back into its own
## holes every lap. Empty on a walk nobody handed any, which is every walk that
## never reaches land.
var treads: Dictionary = {}

const SALT := 0x0C0105


static func make(def: RefCounted, seed_value: int, world_size: int) -> RefCounted:
	var r: RefCounted = (load("res://src/core/colossus/colossus_route.gd") as GDScript).new()
	var rng := Rng.make(seed_value, SALT + int(String(def.id).hash() & 0xffff))
	var mid := Vector2(world_size * 0.5, world_size * 0.5)
	# The ring's centre: the island's, or (for a ring that passes over it) a
	# route_offset away on a bearing the seed deals.
	var off_bearing := rng.randf() * TAU
	r.centre = mid + Vector2(cos(off_bearing), sin(off_bearing)) * float(def.route_offset)
	r.radius = float(def.route_radius)
	if def.route_offset > 0.0:
		# Start where the ring crosses the island, so a new game opens with the
		# straddling walker overhead or nearly: the lap is long.
		r.phase = fposmod((off_bearing + PI) / TAU + (rng.randf() - 0.5) * 0.04, 1.0)
	else:
		r.phase = rng.randf()
	r.sense = 1.0 if rng.randf() < 0.5 else -1.0
	r.offset = rng.randf() * float(def.cycle_minutes)
	r._cycles = maxi(1, roundi(TAU * r.radius / float(def.stride)))
	r._cycle_minutes = float(def.cycle_minutes)
	return r


## Plant `j` of leg `k` as `treads` keys it: the same plant every lap.
func tread_key(k: int, j: int) -> int:
	return k * 1000003 + posmod(j, _cycles)


## The tread plant `j` of leg `k` comes down on, or a Vector4 of NAN.
func tread_of(k: int, j: int) -> Vector4:
	if treads.is_empty():
		return Vector4(NAN, NAN, NAN, NAN)
	return treads.get(tread_key(k, j), Vector4(NAN, NAN, NAN, NAN))


## How many gait cycles take the hub once round.
func cycles() -> int:
	return _cycles


func lap_minutes() -> float:
	return float(_cycles) * _cycle_minutes


## The ring's angle `u` gait cycles into the lap (u may be any real number).
func angle_at(u: float) -> float:
	return (phase + sense * u / float(_cycles)) * TAU


## Where the ring is `u` cycles into the lap.
func at(u: float) -> Vector2:
	var a := angle_at(u)
	return centre + Vector2(cos(a), sin(a)) * radius


## The bearing of travel `u` cycles in (radians, in the XZ plane: 0 is +X).
func heading(u: float) -> float:
	return angle_at(u) + sense * PI * 0.5
