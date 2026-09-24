extends RefCounted
## WHERE THE RING IS IN THE SKY, as a pure function of the world clock
## (src/core/orbit/orbit_def.gd says why it goes over by PASSES and not by an
## honest orbit).
##
## Every answer is in the OBSERVER'S frame and in kilometres: x east, y up,
## z south (the world's own axes), the observer at the origin on the ground and
## the planet's centre at (0, -planet_km, 0). The player's few kilometres of
## wandering are nothing against 420 km up, so the sky is the same sky
## everywhere on the island and a player cannot walk out from under a pass.
##
## A PASS is an honest arc: the orbit is a circle of radius planet + altitude
## round the planet's centre, in a plane tilted so its closest point stands
## `peak_el` degrees up, and the ring rides along it. Only the PACE is not
## honest: `s`, the share of the window gone, is spent on the SKY ANGLE the ring
## has crossed, not on its angle round the planet, so it crosses the sky at one
## steady rate horizon to horizon (a real orbit would crawl up from the horizon
## and whip across the top) -- roughly sixteen degrees a world hour, about
## forty real seconds to cross its own width overhead.
##
## No class_name (reached by path).

const Def := preload("res://src/core/orbit/orbit_def.gd")

## Samples of the arc the pace is spent over.
const ARC_STEPS := 64
## The Earth's shadow is not a line: the sun is half a degree wide, and seen
## from 2000 km behind the limb that is a penumbra of about twenty kilometres.
const PENUMBRA_KM := 20.0
## Sunlight that grazes the limb has come through the whole of the air and is
## red; it stays red this far out past the planet's edge.
const RED_LIMB_KM := 90.0

## Salts, so nothing here ever deals the same numbers as another package.
const SALT_PHASE := 71031
const SALT_PEAK := 71032
const SALT_SIDE := 71033
const SALT_HEAD := 71034
const SALT_TUMBLE := 71035


static func period_min(def: RefCounted) -> float:
	return float(def.period_h) * 60.0


static func window_min(def: RefCounted) -> float:
	return float(def.window_h) * 60.0


## Minute the first pass (k = 0) rises.
static func phase(def: RefCounted, seed_value: int) -> float:
	return Rng.hash01(seed_value, SALT_PHASE) * period_min(def)


## The orbit's heading over this island, degrees (0 east, 90 south): one per
## world, the way a real ground track keeps its slant.
static func heading(seed_value: int) -> float:
	return Rng.hash01(seed_value, SALT_HEAD) * 360.0


## Pass k: when it rises, how high it climbs, which side of the zenith it goes
## by and along which bearing.
static func pass_of(def: RefCounted, seed_value: int, k: int) -> Dictionary:
	# A smooth walk between the least and the most: pass k sits between two
	# lattice values a third of the way along, so passes near each other in time
	# are near each other in height, and every height comes round.
	var x := float(k) / 2.6
	var i := floori(x)
	var f := x - float(i)
	f = f * f * (3.0 - 2.0 * f)
	var v := lerpf(Rng.hash01(seed_value, SALT_PEAK, i), Rng.hash01(seed_value, SALT_PEAK, i + 1), f)
	var peak := lerpf(float(def.peak_least), float(def.peak_most), v)
	var side := 1.0 if Rng.hash01(seed_value, SALT_SIDE, k) < 0.5 else -1.0
	var head := heading(seed_value) + (Rng.hash01(seed_value, SALT_HEAD, k) - 0.5) * 16.0
	return make_pass(def, k, phase(def, seed_value) + float(k) * period_min(def), peak, head, side)


## A pass from its numbers (a staged one is made here too).
static func make_pass(def: RefCounted, k: int, rise: float, peak_el: float, head_deg: float, side: float) -> Dictionary:
	var r: float = def.planet_km
	var rs: float = def.orbit_km()
	var e := deg_to_rad(clampf(peak_el, 0.5, 89.9))
	# The angle at the planet's centre between the observer and the arc's
	# closest point, for a thing `rs` out seen `e` above the horizon.
	var beta := acos(clampf(r / rs * cos(e), -1.0, 1.0)) - e
	var a := Vector3(cos(deg_to_rad(head_deg)), 0.0, sin(deg_to_rad(head_deg)))
	var c := Vector3(-a.z, 0.0, a.x) * side
	var n1 := Vector3.UP * cos(beta) + c * sin(beta)
	var theta_r := acos(clampf(r / (rs * cos(beta)), -1.0, 1.0))
	var p := {"k": k, "rise": rise, "set": rise + window_min(def), "peak_el": peak_el,
		"heading": head_deg, "side": side, "n1": n1, "a": a, "theta_r": theta_r}
	# The sky angle crossed, sampled along the arc, for spending `s` evenly.
	var cum := PackedFloat32Array()
	cum.resize(ARC_STEPS + 1)
	var prev := _dir_at(def, p, -theta_r)
	var total := 0.0
	cum[0] = 0.0
	for j in range(1, ARC_STEPS + 1):
		var th := lerpf(-theta_r, theta_r, float(j) / ARC_STEPS)
		var d := _dir_at(def, p, th)
		total += prev.angle_to(d)
		cum[j] = total
		prev = d
	p["cum"] = cum
	p["arc"] = total
	return p


## Where on the planet-centred circle angle `theta` is, relative to the observer.
static func rel_at(def: RefCounted, p: Dictionary, theta: float) -> Vector3:
	var at: Vector3 = ((p.n1 as Vector3) * cos(theta) + (p.a as Vector3) * sin(theta)) * float(def.orbit_km())
	return at - Vector3.UP * float(def.planet_km)


static func _dir_at(def: RefCounted, p: Dictionary, theta: float) -> Vector3:
	return rel_at(def, p, theta).normalized()


## The angle round the planet at which `s` of the pass's sky arc is crossed.
static func theta_of(p: Dictionary, s: float) -> float:
	var cum: PackedFloat32Array = p.cum
	var want := clampf(s, 0.0, 1.0) * float(p.arc)
	var j := 1
	while j < ARC_STEPS and cum[j] < want:
		j += 1
	var lo := cum[j - 1]
	var hi := cum[j]
	var f := 0.0 if hi <= lo else (want - lo) / (hi - lo)
	var tr: float = p.theta_r
	return lerpf(-tr, tr, (float(j - 1) + f) / ARC_STEPS)


## The pass whose window holds `minutes`, or the next to rise.
static func next_pass(def: RefCounted, seed_value: int, minutes: float) -> Dictionary:
	var k := floori((minutes - phase(def, seed_value)) / period_min(def))
	var p := pass_of(def, seed_value, k)
	if minutes > float(p.set):
		p = pass_of(def, seed_value, k + 1)
	return p


## THE POSE at `minutes`. `staged` (a pass from `make_pass`) replaces the
## schedule: only that pass exists, for a frame staged by name.
##   up        whether it is over the horizon at all
##   s         the share of the pass's window gone, 0..1
##   rel       the ring's centre from the observer, km
##   dir       unit direction to it; `dist` its distance, km
##   elevation, bearing   degrees (bearing 0 east, 90 south)
##   basis     the wheel's frame: y its axis, the spin laid in
##   earth     the planet's centre from the observer (0, -planet_km, 0)
static func pose(def: RefCounted, seed_value: int, minutes: float, staged := {}) -> Dictionary:
	var p: Dictionary = staged if not staged.is_empty() else next_pass(def, seed_value, minutes)
	var out := {"pass": p, "k": p.k, "earth": Vector3(0.0, -float(def.planet_km), 0.0)}
	var s := (minutes - float(p.rise)) / window_min(def)
	out["s"] = s
	out["up"] = s >= 0.0 and s <= 1.0
	var th := theta_of(p, s)
	var rel := rel_at(def, p, th)
	out["rel"] = rel
	out["dist"] = rel.length()
	out["dir"] = rel.normalized()
	out["elevation"] = rad_to_deg(asin(clampf(rel.normalized().y, -1.0, 1.0)))
	out["bearing"] = fposmod(rad_to_deg(atan2(rel.z, rel.x)), 360.0)
	out["basis"] = basis_at(def, seed_value, p, minutes)
	return out


## The wheel's frame: its axis tumbling slowly in the pass's own frame (so one
## pass shows an open wheel and another a line), and the spin about it.
static func basis_at(def: RefCounted, seed_value: int, p: Dictionary, minutes: float) -> Basis:
	var n1: Vector3 = p.n1
	var a: Vector3 = p.a
	var c := n1.cross(a).normalized()
	var phi := TAU * minutes / float(def.tumble_min) + Rng.hash01(seed_value, SALT_TUMBLE) * TAU
	var psi := TAU * minutes / (float(def.tumble_min) * 2.618) + 1.3
	var axis := (n1 * cos(phi) + (a * cos(psi) + c * sin(psi)) * sin(phi)).normalized()
	var x0 := axis.cross(a)
	if x0.length() < 1e-4:
		x0 = axis.cross(c)
	x0 = x0.normalized()
	var z0 := x0.cross(axis).normalized()
	var spin := TAU * minutes / float(def.spin_min)
	return Basis(x0, axis, z0) * Basis(Vector3.UP, spin)


## HOW SUNLIT a point is, 0..1: `at` from the planet's centre (km), `sun` the
## unit direction to the REAL sun (SkyLight.sky_sun). In front of the planet's
## terminator plane it is lit; behind it, only outside the planet's cylinder,
## with the penumbra's width. orbit.gdshader `sunlit` is this, per fragment.
static func sunlit(def: RefCounted, at: Vector3, sun: Vector3) -> float:
	var along := at.dot(sun)
	if along >= 0.0:
		return 1.0
	var perp := (at - sun * along).length()
	var r: float = def.planet_km
	return smoothstep(r - PENUMBRA_KM, r + PENUMBRA_KM, perp)


## The elevation (degrees, negative) the sun must be under for a point straight
## overhead to fall into the Earth's shadow: acos(R / (R + h)).
static func eclipse_depth(def: RefCounted) -> float:
	return -rad_to_deg(acos(float(def.planet_km) / float(def.orbit_km())))
