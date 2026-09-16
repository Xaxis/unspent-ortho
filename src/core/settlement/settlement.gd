class_name Settlement
extends RefCounted
## A place the player built and has to keep (docs/VISION.md §9).
##
## It holds its pieces, its people, its stores and the attention the machines
## pay it. Two packages meet on this object and neither owns both sides: the
## settlement package builds, staffs, produces and repairs; the raids package
## reads `signature()` to decide what a passing machine notices, writes
## `attention`, and calls `damage_structure` when a party comes through the
## gate. Nothing here runs a clock: the world does that and tells it.

var id := 0
var realm := 0
var name := ""
var centre := Vector2.ZERO
var pieces: Array[Structure] = []
## Person ids living here. They staff pieces; a raid can carry them off.
var people: Array[int] = []
## Item id (String) -> count. What the place has laid by.
var stores := {}
## 0..1. The raids package owns this; the settlement only reads it, so a
## settlement can show the player their own weather without deciding it.
var attention := 0.0
var _next_piece := 1


func _init(settlement_id: int = 0, in_realm: int = 0, at: Vector2 = Vector2.ZERO, called: String = "") -> void:
	id = settlement_id
	realm = in_realm
	centre = at
	name = called


func add(kind: int, at: Vector2, strength: float = 1.0) -> Structure:
	var s := Structure.new(_next_piece, kind, at, strength)
	_next_piece += 1
	pieces.append(s)
	return s


func piece(piece_id: int) -> Structure:
	for s in pieces:
		if s.id == piece_id:
			return s
	return null


func structures_of(kind: int) -> Array[Structure]:
	var out: Array[Structure] = []
	for s in pieces:
		if s.kind == kind:
			out.append(s)
	return out


func of_family(family: StructureKind.Family) -> Array[Structure]:
	var out: Array[Structure] = []
	for s in pieces:
		if s.family() == family:
			out.append(s)
	return out


func defences() -> Array[Structure]:
	return of_family(StructureKind.Family.DEFENCE)


func standing() -> Array[Structure]:
	var out: Array[Structure] = []
	for s in pieces:
		if s.standing():
			out.append(s)
	return out


## Everything the place gives off, after what hides it has had its say. Each
## channel takes the loudest piece rather than the sum: ten hearths are one
## column of smoke, but a radio mast is a radio mast.
func signature() -> Signature:
	var sig := Signature.new()
	var hidden := 0.0
	for s in pieces:
		var signs := s.signs()
		for k: String in signs:
			var v := float(signs[k])
			if k == "mask":
				hidden = maxf(hidden, v)
			else:
				sig.set_channel(StringName(k), maxf(sig.get_channel(StringName(k)), v))
	if not people.is_empty():
		sig.add(&"traffic", minf(0.6, 0.15 * float(people.size())))
	if hidden > 0.0:
		sig.mask(hidden)
	return sig


func damage_structure(piece_id: int, amount: float) -> bool:
	var s := piece(piece_id)
	if s == null:
		return false
	return s.damage(amount)


func destroy_structure(piece_id: int) -> void:
	var s := piece(piece_id)
	if s != null:
		s.damage(s.max_health + 1.0)


func as_dict() -> Dictionary:
	var out_pieces := []
	for s in pieces:
		out_pieces.append(s.as_dict())
	return {
		"id": id, "realm": realm, "name": name, "centre": SaveCodec.vec2(centre),
		"pieces": out_pieces, "people": people, "stores": stores,
		"attention": attention, "next_piece": _next_piece,
	}


static func from_dict(d: Dictionary) -> Settlement:
	var s := Settlement.new(SaveCodec.to_int(d.get("id", 0)), SaveCodec.to_int(d.get("realm", 0)), SaveCodec.to_vec2(d.get("centre", Vector2.ZERO)), String(d.get("name", "")))
	for p: Variant in d.get("pieces", []):
		s.pieces.append(Structure.from_dict(p as Dictionary))
	for person: Variant in d.get("people", []):
		s.people.append(SaveCodec.to_int(person))
	s.stores = SaveCodec.to_counts(d.get("stores", {}))
	s.attention = float(d.get("attention", 0.0))
	s._next_piece = SaveCodec.to_int(d.get("next_piece", s.pieces.size() + 1), s.pieces.size() + 1)
	return s
