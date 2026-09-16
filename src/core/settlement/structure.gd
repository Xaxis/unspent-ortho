class_name Structure
extends RefCounted
## One piece the player built, standing in the world (docs/VISION.md §9).
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


func _init(piece_id: int = 0, piece_kind: int = StructureKind.LEAN_TO, at: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	id = piece_id
	kind = piece_kind
	pos = at
	max_health = strength
	health = strength


func family() -> StructureKind.Family:
	return StructureKind.family(kind)


func standing() -> bool:
	return not ruined


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
## ruined says nothing; one that needs power and has none says almost nothing.
func signs() -> Dictionary:
	if ruined:
		return {}
	var base: Dictionary = StructureKind.signs(kind)
	if base.is_empty():
		return base
	if base.has("power") and not powered:
		var quiet := base.duplicate()
		for k: String in quiet:
			quiet[k] = float(quiet[k]) * 0.25
		return quiet
	return base


func as_dict() -> Dictionary:
	return {
		"id": id, "kind": kind, "pos": SaveCodec.vec2(pos), "facing": facing,
		"health": health, "max_health": max_health,
		"powered": powered, "staffed_by": staffed_by, "ruined": ruined,
	}


static func from_dict(d: Dictionary) -> Structure:
	var s := Structure.new(SaveCodec.to_int(d.get("id", 0)), SaveCodec.to_int(d.get("kind", 0)), SaveCodec.to_vec2(d.get("pos", Vector2.ZERO)), float(d.get("max_health", 1.0)))
	s.facing = float(d.get("facing", 0.0))
	s.health = float(d.get("health", s.max_health))
	s.powered = bool(d.get("powered", false))
	s.staffed_by = SaveCodec.to_int(d.get("staffed_by", -1))
	s.ruined = bool(d.get("ruined", false))
	return s
