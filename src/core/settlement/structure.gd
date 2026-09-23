class_name Structure
extends RefCounted
## One piece the player built, standing in the world (docs/VISION.md).
##
## A piece is a thing, not a number on a screen: it takes up ground, it shelters
## or stops a body, it wears, it can be broken by a machine that came for it,
## and it can be mended for what it costs. A ruined piece stays where it fell so
## the yard remembers the raid.

var id := 0
var kind := StructureKind.LEAN_TO
var pos := Vector2.ZERO
var facing := 0.0
var health := 1.0
var max_health := 1.0
## Wired to a working power piece this tick: what a turret, a mast and a machine
## shop need before they do anything, and what raises the power channel.
var powered := false
## Person id staffing it, or -1. A staffed piece produces; an empty one waits.
var staffed_by := -1
## Broken past mending: it stands as wreckage until it is cleared.
var ruined := false
## Switched off by hand (`StructureKind.switched`): it draws nothing, does nothing
## and gives off only what a cold piece of stolen technology does.
var off := false
## Which drawing of this kind. The same kind built twice is not the same piece
## (docs/LOOK.md, nothing is prefabricated): the model leans, patches and
## weathers by this number, and it is dealt when the piece is founded so that a
## loaded holding stands exactly as the player left it.
var variant := 0


func _init(piece_id: int = 0, piece_kind: int = StructureKind.LEAN_TO, at: Vector2 = Vector2.ZERO, strength: float = -1.0) -> void:
	id = piece_id
	kind = piece_kind
	pos = at
	# A piece is as strong as its kind unless somebody says otherwise: a hut is
	# not a lean-to, and a plate wall is not a net.
	max_health = strength if strength > 0.0 else StructureKind.health(piece_kind)
	health = max_health


func family() -> StructureKind.Family:
	return StructureKind.family(kind)


func standing() -> bool:
	return not ruined


## 0..1: how much of this piece is still there. What it produces, what it keeps
## off a body and what it gives off all ride on it, so a holding nobody mends is
## a holding that slowly stops working rather than one that fails all at once.
func condition() -> float:
	if ruined or max_health <= 0.0:
		return 0.0
	return clampf(health / max_health, 0.0, 1.0)


## It is doing its work now: whole enough, staffed if it needs hands, and wired
## if it needs power.
func working() -> bool:
	if ruined or off or condition() < WORKS_ABOVE:
		return false
	if StructureKind.needs_staff(kind) and staffed_by < 0:
		return false
	return powered or StructureKind.draw_power(kind) <= 0.0


## Under this share of its strength a piece has stopped working: a plot trampled
## to a quarter is not a plot, and a spinner with one blade left turns nothing.
const WORKS_ABOVE := 0.25


## Returns true if this blow is what ruined it.
func damage(amount: float) -> bool:
	if ruined:
		return false
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		ruined = true
		return true
	return false


func repair(amount: float) -> void:
	if ruined and amount <= 0.0:
		return
	health = minf(max_health, health + amount)
	if health > 0.0:
		ruined = false


## What a machine can sense from this piece as it stands now. A piece that is
## ruined says nothing; one that needs power and has none says almost nothing;
## and a piece falling apart is quieter than a piece kept up.
func signs() -> Dictionary:
	if ruined:
		return {}
	var base: Dictionary = StructureKind.signs(kind)
	if base.is_empty():
		return base
	# A mask that is a machine's voice needs a machine's power to speak: a spoofer
	# with none in it is a box on a stake, and it hides nothing at all.
	if not powered and StructureKind.draw_power(kind) > 0.0 and StructureKind.masks(kind):
		return {}
	var scale := 1.0
	if base.has("power") and not powered:
		scale = 0.25
	# A mask is a thing you keep in repair or it stops hiding you.
	scale *= lerpf(0.4, 1.0, condition())
	if is_equal_approx(scale, 1.0):
		return base
	var out := base.duplicate()
	for k: String in out:
		out[k] = float(out[k]) * scale
	return out


func as_dict() -> Dictionary:
	return {
		"id": id, "kind": kind, "pos": SaveCodec.vec2(pos), "facing": facing,
		"health": health, "max_health": max_health, "variant": variant,
		"powered": powered, "staffed_by": staffed_by, "ruined": ruined, "off": off,
	}


static func from_dict(d: Dictionary) -> Structure:
	var s := Structure.new(SaveCodec.to_int(d.get("id", 0)), SaveCodec.to_int(d.get("kind", 0)), SaveCodec.to_vec2(d.get("pos", Vector2.ZERO)), float(d.get("max_health", 1.0)))
	s.facing = float(d.get("facing", 0.0))
	s.health = float(d.get("health", s.max_health))
	s.variant = SaveCodec.to_int(d.get("variant", 0))
	s.powered = bool(d.get("powered", false))
	s.staffed_by = SaveCodec.to_int(d.get("staffed_by", -1))
	s.ruined = bool(d.get("ruined", false))
	s.off = bool(d.get("off", false))
	return s
