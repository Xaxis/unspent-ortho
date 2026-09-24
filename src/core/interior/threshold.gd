class_name Threshold
extends RefCounted
## A way into a pocket (docs/interiors): the door of something standing on the
## land, derived from the finished island and never written into it, the way a
## Portal is. Its KEY names its pocket for the life of a seed: the host's kind and
## its position to a quarter tile (WorldProp.deal_hash's precedent), never a prop
## id, which renumbers when anything upstream changes.

var key := ""
var kind: StringName = &""
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
	return t


## The realm key a pocket behind this door is known by (Realm.POCKET).
func realm_key() -> StringName:
	return StringName(Realm.POCKET + key)
