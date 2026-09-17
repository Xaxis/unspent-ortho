class_name Craft
extends RefCounted
## One craft in the world: where it lies, which way it is turned, and what is
## left of it. Pure state — the node that draws it and the system that rides it
## are 44_crafts'. A parked craft is a thing in the world with a place of its
## own, so it can be come back to, and forgotten, and found wrecked.

var id := 0
var kind: StringName = &""
## Tile space, like every other position in the game.
var pos := Vector2.ZERO
## Radians, 0 = east, as a body's facing is.
var facing := 0.0
var hull := 0.0
var wrecked := false


static func make(id_value: int, kind_value: StringName, at: Vector2, facing_value: float = 0.0) -> Craft:
	var c := Craft.new()
	c.id = id_value
	c.kind = kind_value
	c.pos = at
	c.facing = facing_value
	c.hull = CraftKinds.hull(kind_value)
	return c


func ride() -> CraftRide:
	return CraftKinds.ride(kind)


func display_name() -> String:
	return CraftKinds.display_name(kind)


## Take `amount` off the hull. True when this is the blow that wrecked it.
func damage(amount: float) -> bool:
	if wrecked or amount <= 0.0:
		return false
	hull -= amount
	if hull > 0.0:
		return false
	hull = 0.0
	wrecked = true
	return true


## 0..1 of the hull left, for a mark on the glass and for the drawing's wear.
func condition() -> float:
	var full := CraftKinds.hull(kind)
	return clampf(hull / maxf(1.0, full), 0.0, 1.0)


func to_save() -> Dictionary:
	return {"id": id, "kind": String(kind), "pos": SaveCodec.vec2(pos), "facing": facing,
		"hull": hull, "wrecked": wrecked}


static func from_save(d: Dictionary) -> Craft:
	var kind_value := StringName(d.get("kind", ""))
	if not CraftKinds.known(kind_value):
		return null
	var c := Craft.make(SaveCodec.to_int(d.get("id", 0)), kind_value,
		SaveCodec.to_vec2(d.get("pos", [])), SaveCodec.to_num(d.get("facing", 0.0)))
	c.hull = SaveCodec.to_num(d.get("hull", c.hull), c.hull)
	c.wrecked = bool(d.get("wrecked", false))
	return c
