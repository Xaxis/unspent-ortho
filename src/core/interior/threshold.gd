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


## The realm key a pocket behind this door is known by (Realm.POCKET).
func realm_key() -> StringName:
	return StringName(Realm.POCKET + key)
