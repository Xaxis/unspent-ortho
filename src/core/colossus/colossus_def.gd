extends RefCounted
## ONE WALKING MEGASTRUCTURE, AS DATA (docs: the colossi design, 2026-09-23).
##
## The owner asked for two or three machines "so big the tops of them are almost
## in orbit", walking slowly over and around the world. What they ARE is ruled
## in docs/STORY.md (HALCYON's bandwidth, walking; one half-broken, the first
## enclave in its crown). Nothing here names one: a body is a set of numbers, a
## circuit is where it walks, and the engine draws whatever it is handed. A named design is a new `static func` beside `tripod()`.
##
## Everything is in world units, which are METRES (a tile is one), and world
## minutes. These are honest heights: the hub really stands 52 to 70 km up, and
## the renderer, not this file, is what makes that drawable
## (src/render/colossus/colossus_view.gd, compressed space).
##
## No class_name: reached by path (`preload`), so a new file cannot go stale in
## the global class cache for someone running from source after a pull.

## Which body, and which circuit it walks: &"A" out on the skyline (120-250 km,
## the whole figure against the sky), &"B" looming (30-80 km, the legs), &"C"
## straddling the island (the land passes between its legs, hub overhead).
var id: StringName = &"tripod"
var circuit: StringName = &"A"

## The hub: its underside, its crown, and how wide it is. The hips hang on a
## ring round it, and the hub's own origin is at hip height.
var hub_low := 52000.0
var hub_high := 70000.0
var hub_radius := 4200.0
var spire_top := 96000.0
var hip_height := 55000.0
var hip_ring := 5200.0

## The legs. Rigid bones of fixed length (the knee is where they meet, solved
## every pose), tapered from the hip to the ankle. Heavier than the design's
## first numbers (1200 and 500 m at the root): at those a leg thirty kilometres
## long read as a wire against the sky and the machine as a drawing of one.
var thigh := 34000.0
var shin := 36000.0
var thigh_r := Vector2(1700.0, 950.0)
var shin_r := Vector2(800.0, 110.0)
var knee_r := 1350.0
## The ankle stands this far over the pads: a person walks under it between toes.
var ankle_up := 120.0
var toe_reach := 180.0
## THE SOLE, as the ground reads it: three toes splayed ahead of the ankle along
## the way the foot walks, and a heel behind it under the drum. Each is
## (bearing from the foot's forward, degrees; reach from under the ankle; the
## pad's radius), metres. A foot that is the same all round read from above as a
## crater and not a footprint; a sole with a front and a back says which way the
## machine was going.
var toes: Array[Vector3] = [Vector3(-48.0, 180.0, 20.0), Vector3(0.0, 196.0, 21.0),
	Vector3(48.0, 180.0, 20.0), Vector3(180.0, 128.0, 30.0)]
var pad := 20.0

## Where each foot is set down, about the hub: a circle this wide, at these
## bearings from the heading (degrees). 90/210/330 rather than 0/120/240 so no
## foot is ever planted ON the line the hub walks -- the nearest is a quarter of
## the circle to the side -- which is what lets circuit C's hub pass over the
## island with all three feet in the sea.
var feet_circle := 12500.0
var slots: Array[float] = [90.0, 210.0, 330.0]

## The gait: a tripod wave, one leg in the air at a time. A whole cycle (each
## leg stepping once) and one leg's swing, in world minutes.
var cycle_minutes := 7.7 * 60.0
var swing_minutes := 2.5 * 60.0
## How far a foot is carried in one step, and how high it is lifted.
var stride := 40000.0
var lift := 3000.0
## The hub's own slow roll over the stride, in metres.
var sway := 350.0

## The circuit: a ring this far round its centre, whose centre stands this far
## from the island's (0 for a ring round it; the ring's own radius for one that
## passes over it).
var route_radius := 180000.0
var route_offset := 0.0


## Toe `i` in the foot's own frame: (bearing in radians from local +X, reach, pad).
func toe(i: int) -> Vector3:
	var t: Vector3 = toes[i]
	return Vector3(deg_to_rad(t.x), t.y, t.z)


## How much of a cycle one leg spends in the air.
func swing_share() -> float:
	return swing_minutes / cycle_minutes


## THE SHAPE EACH PART IS TURNED TO, as (radius, height) rows up its own bone's
## Y (colossus_walk.gd `pose().bones`): what colossus_model.gd and the near foot
## lathe, and what WalkerClimb puts a climber's hands on, so the surface drawn
## and the surface climbed cannot part. Each is turned with this many flats near
## to, a flat's middle at bearing 0 (the lathes' half-flat turn); the far body's
## legs have 8 where nobody can touch them.
const LEG_SIDES := 12
const HULL_SIDES := 16
const DRUM_SIDES := 40
## Where the thigh's courses change, as shares of it from the hip.
const THIGH_BANDS: Array[float] = [0.0, 0.04, 0.07, 0.10, 0.22, 0.36, 0.46, 0.49, 0.53, 0.56, 0.70, 0.84, 0.94, 1.0]
## How many rings the shin is laid in, densest toward the ground.
const SHIN_RINGS := 18


## Tapered hip to knee, a sleeve standing proud at two of its bands.
func thigh_profile() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in THIGH_BANDS.size():
		var t: float = THIGH_BANDS[i]
		var w := lerpf(thigh_r.x, thigh_r.y, t)
		if i == 2 or i == 8:
			w *= 1.14
		out.append(Vector2(w, t * thigh))
	out[0] = Vector2(thigh_r.x * 0.8, 0.0)
	return out


## Knee to ankle, narrowing fastest near the knee, two sleeves.
func shin_profile() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in SHIN_RINGS + 1:
		var t := 1.0 - pow(1.0 - float(i) / float(SHIN_RINGS), 1.6)
		var w := lerpf(shin_r.x, shin_r.y, pow(t, 0.8))
		if i == 3 or i == 9:
			w *= 1.18
		out.append(Vector2(w, t * shin))
	return out


## The hub's hull, keel to shoulder, about its origin at hip height.
func hull_profile() -> Array[Vector2]:
	var lo := hub_low - hip_height
	var r := hub_radius
	return [
		Vector2(0.0, lo - 400.0), Vector2(260.0, lo - 380.0), Vector2(420.0, lo),
		Vector2(r * 0.42, lo + 500.0), Vector2(r * 0.66, lo + 1200.0), Vector2(r * 0.86, lo + 2000.0),
		Vector2(r * 0.97, -350.0), Vector2(r * 1.04, 0.0), Vector2(r * 1.04, 380.0),
		Vector2(r * 0.95, 520.0), Vector2(r * 0.98, 900.0), Vector2(r * 1.08, 1050.0),
		Vector2(r * 0.90, 1350.0), Vector2(r * 0.78, 1700.0),
	]


## The ankle's drum about the ankle (colossus_foot_model.gd): its stepped
## underside, a belt, the wall, a lip, and the shin going up out of its crown.
func drum_profile() -> Array[Vector2]:
	return [
		Vector2(0.0, -80.0), Vector2(18.0, -80.0), Vector2(26.0, -77.0), Vector2(30.0, -72.0),
		Vector2(44.0, -70.0), Vector2(62.0, -68.0), Vector2(64.0, -66.0), Vector2(96.0, -65.0),
		Vector2(98.0, -63.0), Vector2(128.0, -61.0), Vector2(150.0, -56.0), Vector2(157.0, -52.0),
		Vector2(157.0, -41.0), Vector2(151.0, -37.0), Vector2(148.0, -30.0), Vector2(146.0, -10.0),
		Vector2(152.0, -6.0), Vector2(152.0, 0.0), Vector2(138.0, 7.0), Vector2(shin_r.y * 1.03, 13.0),
		Vector2(shin_r.y * 1.0, 16.0),
	]


## How far from its axis a lathe of `profile` turned with `sides` flats (a
## flat's middle at bearing 0) stands at height `y` and bearing `theta`: on the
## flat itself, not the circle through its corners.
static func turned_radius(profile: Array[Vector2], sides: int, y: float, theta: float) -> float:
	var w := profile[0].x
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if y <= b.y or i == profile.size() - 2:
			w = lerpf(a.x, b.x, clampf((y - a.y) / maxf(b.y - a.y, 1e-6), 0.0, 1.0))
			break
	var flat := TAU / float(sides)
	var off := theta - roundf(theta / flat) * flat
	return w * cos(flat * 0.5) / cos(off)


## The generic tripod every circuit walks in this slice.
static func tripod(circuit_id: StringName) -> RefCounted:
	var d: RefCounted = (load("res://src/core/colossus/colossus_def.gd") as GDScript).new()
	d.circuit = circuit_id
	d.id = StringName("tripod_%s" % String(circuit_id).to_lower())
	match circuit_id:
		&"A":
			d.route_radius = 180000.0
		&"B":
			d.route_radius = 55000.0
		&"C":
			# A ring through the island's centre: the hub passes overhead once a lap.
			d.route_radius = 60000.0
			d.route_offset = 60000.0
	return d


## The walkers a world of `size` tiles gets. A small world (a test island, a
## realm's pocket) gets one, far out, so nothing looms over a place too small to
## stand under it.
static func walkers(size: int) -> Array:
	if size <= 512:
		return [tripod(&"A")]
	return [tripod(&"A"), tripod(&"B"), tripod(&"C")]
