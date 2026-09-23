class_name Portal
extends RefCounted
## One way between realms: a place in the world, not a menu (docs/VISION.md).
##
## A shaft the machines sank and stopped maintaining. It stands at the foot of a
## broken face, framed in FOUND plate, with a MADE ladder somebody hung in it
## afterwards, and it is entered by walking to it and pressing `use`.
##
## Pure data. Where the portals of a world ARE is Portals (deterministic from the
## world alone); what happens when one is entered is src/systems/20_realms.gd.

## Which shaft this is in its world, and the shaft it is paired with on the far
## side (the same index: Portals lays them in the same order in every realm).
var id := 0
## Tile space, the tile a player stands on to use it.
var pos := Vector2.ZERO
## The realm this mouth is in, and the realm it opens onto.
var realm: StringName = Realm.SURFACE
var to_realm: StringName = Realm.UNDERGROUND
## Which way the shaft is cut, in radians: the gate faces this way, out of the
## rock behind it. 0 = east.
var facing := 0.0
## The region of its own world it stands in (WorldData.regions), so a portal can
## be spoken of by the place it is in and saved against it.
var region := -1
## What the machines left it doing. A shaft they abandoned is open; one still on
## the plan's power is not, and wants mending (VISION §4: "old machine gates that
## need power, keys or repair"). Nothing shuts one yet: every shaft the generator
## lays is open, and this is the field the mending hangs on.
var open := true


## How near a player must stand to use it (tiles).
const REACH := 2.6


func within(p: Vector2) -> bool:
	return pos.distance_to(p) <= REACH


## What the slate says about it, in the machines' own flat voice.
func spoken() -> String:
	if realm == Realm.UNDERGROUND:
		return "a shaft head, and daylight up it"
	return "a shaft, cut and left open"


func to_dict() -> Dictionary:
	return {"id": id, "pos": SaveCodec.vec2(pos), "realm": String(realm),
		"to": String(to_realm), "facing": facing, "region": region, "open": open}


static func from_dict(d: Dictionary) -> Portal:
	var p := Portal.new()
	p.id = SaveCodec.to_int(d.get("id", 0))
	p.pos = SaveCodec.to_vec2(d.get("pos", [0.0, 0.0]))
	p.realm = StringName(str(d.get("realm", Realm.SURFACE)))
	p.to_realm = StringName(str(d.get("to", Realm.UNDERGROUND)))
	p.facing = float(d.get("facing", 0.0))
	p.region = SaveCodec.to_int(d.get("region", -1))
	p.open = bool(d.get("open", true))
	return p
