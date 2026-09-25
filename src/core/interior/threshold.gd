class_name Threshold
extends RefCounted
## A way into a pocket (docs/interiors): the door of something standing on the
## land, derived from the finished island and never written into it, the way a
## Portal is. Its KEY names its pocket for the life of a seed: the host's kind and
## its position to a quarter tile (WorldProp.deal_hash's precedent), never a prop
## id, which renumbers when anything upstream changes.

var key := ""
var kind: StringName = &""
## Which sort of thing the door is in, as a number the pocket's hash takes: a
## house's is PropKind.HOUSE (every cottage's rooms were dealt off it), a
## depot's is `DEPOT`.
var host_code := PropKind.HOUSE
## The host (a house) and which way its door faces (+X at rot 0, turned by rot).
var host := Vector2.ZERO
var rot := 0.0
## Where a body stands at the door, outside, and the way out of the house.
var door := Vector2.ZERO
var out := Vector2.RIGHT
## The landscape the host stands in: the pocket is made of it.
var land := 0


## A house's door: it faces +X and GenScatter turns houses by `rot`, so the door
## is out along that from the house's own reach.
static func of_house(p: WorldProp, kind: StringName, land: int) -> Threshold:
	var t := Threshold.new()
	t.kind = kind
	t.host = p.pos
	t.rot = p.rot
	t.out = Vector2.from_angle(p.rot)
	t.door = p.pos + t.out * (p.solid + 0.4)
	t.land = land
	t.key = "house@%d,%d" % [floori(p.pos.x * 4.0), floori(p.pos.y * 4.0)]
	t.host_code = PropKind.HOUSE
	return t


## A depot's hatch: the plan's works keep a hall under the yard, and its way in
## is a hatch standing off the deck's BACK end, opposite the ramp, facing away
## along the survey bearing (every depot faces it: WorksSite.facing). `HATCH` is
## how far back from the yard's heart the hatch housing stands; the deck's own
## mass reaches 3.8 back (WorksDepot.yard_blocks), so this clears it.
const DEPOT := 0xDE9070
const HATCH := 5.0


static func of_depot(site: WorksSite, kind: StringName, land: int) -> Threshold:
	var t := Threshold.new()
	t.kind = kind
	var along := Vector2.from_angle(site.facing)
	t.host = site.pos - along * HATCH
	t.rot = site.facing + PI
	t.out = -along
	t.door = t.host + t.out * 0.9
	t.land = land
	t.key = "depot@%d,%d" % [floori(site.pos.x * 4.0), floori(site.pos.y * 4.0)]
	t.host_code = DEPOT
	return t


## A hatch let into a landmark's ground (the cast stones keep a bunker under
## the ring): in the ring, beside the tall stone in the middle, opening toward
## the GAP between two standing stones nearest the side away from the landmark's
## cache, so the way out walks out of the ring and never onto the cache.
const LANDMARK := 0x1A9D3A
## How far from the landmark's heart the hatch stands, and the ring's make:
## nine stones at `Landmarks`' 3.6, the first at 0.2 radians (landmark_models).
const IN_RING := 1.9
const RING_N := 9
const RING_FROM := 0.2


static func of_landmark(site: LandmarkSite, kind: StringName, land: int) -> Threshold:
	var t := Threshold.new()
	t.kind = kind
	var away := site.facing + PI
	var best := 0.0
	var bd := INF
	for i in RING_N:
		# The ring is laid in the site's own frame, turned by its facing
		# (22_landmarks hands its stones over `rotated(site.facing)`).
		var g := site.facing + RING_FROM + (float(i) + 0.5) * TAU / float(RING_N)
		var d := absf(angle_difference(g, away))
		if d < bd:
			bd = d
			best = g
	t.out = Vector2.from_angle(best)
	t.rot = best
	t.host = site.pos + t.out * IN_RING
	t.door = t.host + t.out * 0.9
	t.land = land
	t.key = "landmark@%d,%d" % [floori(site.pos.x * 4.0), floori(site.pos.y * 4.0)]
	t.host_code = LANDMARK
	return t


## The realm key a pocket behind this door is known by (Realm.POCKET).
func realm_key() -> StringName:
	return StringName(Realm.POCKET + key)
