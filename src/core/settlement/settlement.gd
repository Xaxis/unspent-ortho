class_name Settlement
extends RefCounted
## A place the player built and has to keep (docs/VISION.md).
##
## It holds its pieces, its people, its stores and the attention the machines
## pay it. Two packages meet on this object and neither owns both sides: the
## settlement package builds, staffs, produces and repairs; the raids package
## reads `signature()` to decide what a passing machine notices, writes
## `attention`, and calls `damage_structure` when a party comes through the
## gate. Nothing here runs a clock: the world does that and tells it.

var id := 0
## The realm it was built in (Realm.KINDS). A world is one realm's world, so a
## holding belongs to the ground it stands on and never follows the player down
## a shaft: the settlement system draws, walks and blocks only the holdings of
## the realm the game is in.
var realm: StringName = Realm.SURFACE
var name := ""
var centre := Vector2.ZERO
var pieces: Array[Structure] = []
## Person ids living here. They staff pieces; a raid can carry them off. The ids
## are the holding's own and outlive any body loaded in the world, because a
## settlement keeps producing while the player is a day's walk away and nothing
## of it is drawn.
var people: Array[int] = []
## Person id -> the seed their look was drawn from, so a loaded holding puts the
## same faces back at the same work.
var looks := {}
## Item id (String) -> count. What the place has laid by.
var stores := {}
## The holding's own bookkeeping: the FRACTIONS of a thing that a half hour's
## growing, eating and mending come to, carried until they are a whole basket.
## It is kept out of `stores` on purpose, so what the slate lists and what the
## store has room for are only ever whole things a person could pick up.
var tally := {}
## 0..1. The raids package owns this; the settlement only reads it, so a
## settlement can show the player their own weather without deciding it.
var attention := 0.0
## 0..1 how dark it is over the place, written by the settlement system once a
## second. It lives here rather than being asked for, because `signature()` is
## the one door the raids package knocks on and a lamp at noon is not a lamp at
## midnight: the hour has to be inside the answer, not beside it.
var night := 0.0
## Charge banked in its batteries, and the world minute its production was last
## settled to (-INF: never run). Catching up from a timestamp is the whole of how
## a holding works while the player is elsewhere.
var charge := 0.0
var worked_at := -INF
## 0..1 how hungry its people are. Nobody works on an empty holding for long.
var hunger := 0.0
var _next_piece := 1
var _next_person := 1


func _init(settlement_id: int = 0, in_realm: StringName = Realm.SURFACE, at: Vector2 = Vector2.ZERO, called: String = "") -> void:
	id = settlement_id
	realm = in_realm
	centre = at
	name = called


func add(kind: int, at: Vector2, strength: float = -1.0) -> Structure:
	var s := Structure.new(_next_piece, kind, at, strength)
	# Dealt once, here, so the drawing of this piece is the same every time the
	# holding is loaded (docs/LOOK.md: the same kind built twice is not the
	# same drawing, and it is not a different one tomorrow either).
	s.variant = int(Rng.hash01(id * 7919 + _next_piece, kind, 41) * 1024.0)
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


## A new resident's id. Ids are never reused, so a person carried off in a raid
## cannot come back as somebody else's bookkeeping.
func take_person_id() -> int:
	var next := _next_person
	_next_person += 1
	return next


## What a raiding party has to get through, standing and in repair.
func defence_total() -> float:
	var total := 0.0
	for s in pieces:
		if s.standing():
			total += StructureKind.defence(s.kind) * s.condition()
	return total


## How much the holding can lay by. Without a store the surplus is what a person
## can carry away and no more, which is the reason to build one.
func store_room() -> float:
	var room := BARE_STORE
	for s in pieces:
		if s.standing():
			room += StructureKind.store_room(s.kind) * s.condition()
	return room


## What of the stores a raid cannot reach: the room of every standing cellar
## (StructureKind.keeps), by its condition.
func kept_room() -> float:
	var room := 0.0
	for s in pieces:
		if s.standing():
			room += StructureKind.keeps(s.kind) * s.condition()
	return room


## Stores with nowhere to go: what a holding with no store loses every time.
const BARE_STORE := 6.0


func stored() -> float:
	var total := 0.0
	for k: Variant in stores:
		total += float(stores[k])
	return total


## Room for residents: a lean-to sleeps one, a hut two, a bunk four, and nobody
## moves in to sleep in the rain.
##
## This is the cap on `people`, and 46_settlements' `_recruit` is what holds them
## to it. For a long time it held nothing — it was written, documented, and called
## by nobody, so a holding took in one resident per job it had and housed them in
## the open, while the slate went on printing "sleeps 2" on the hut's build card.
func beds() -> int:
	var n := 0
	for s in pieces:
		if s.standing():
			n += StructureKind.sleeps(s.kind)
	return n


func charge_room() -> float:
	var room := 0.0
	for s in pieces:
		if s.standing():
			room += StructureKind.banks(s.kind) * s.condition()
	return room


## Everything the place gives off, after what hides it has had its say. Each
## channel takes the loudest piece rather than the sum: ten hearths are one
## column of smoke, but a radio mast is a radio mast.
##
## The hour is inside the answer (see `night`): a window is nothing at noon and
## everything at two in the morning, and smoke is the other way round.
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
				sig.set_channel(StringName(k), maxf(sig.get_channel(StringName(k)), v * _by_hour(k)))
	if not people.is_empty():
		sig.add(&"traffic", minf(0.6, 0.15 * float(people.size())) * _by_hour("traffic"))
	if hidden > 0.0:
		sig.mask(hidden)
	return sig


## What the hour does to a channel before it reaches a machine's senses. Light
## and traffic are night and day things; smoke is only a column while there is
## sky to see it against; radio, power and stolen tech never sleep, which is why
## they are the dangerous ones.
func _by_hour(channel: String) -> float:
	match channel:
		"light": return lerpf(0.3, 1.0, night)
		"smoke": return lerpf(1.0, 0.45, night)
		"traffic": return lerpf(1.0, 0.35, night)
		"noise": return lerpf(1.0, 0.8, night)
	return 1.0


## Tiles out from the centre a decoy has to stand before it is anywhere else. The
## raids package's `Notices.CLEAR_OF` is the same distance for the same reason:
## inside it a machine is still in the yard, and a decoy in the yard is the yard.
## Without it one decoy in the middle of the square would be read in place of the
## square every time and cut every record to a fraction of itself.
const LURE_APART := 12.0


## The decoys standing out past the yard, which a machine may read in place of
## the holding. Ruined ones say nothing, and one inside `LURE_APART` is not
## elsewhere.
func lures() -> Array[Structure]:
	var out: Array[Structure] = []
	for s in pieces:
		if s.standing() and StructureKind.lure(s.kind) > 0.0 and s.pos.distance_to(centre) >= LURE_APART:
			out.append(s)
	return out


## What a decoy shouts, from where it stands: the channel the holding itself is
## loudest on, so what a machine reads off it is the same account of the place,
## louder and in the wrong spot. A holding giving nothing away is shouted for as
## a light by night and a rattle by day, which is what a decoy is made of.
func lure_signature(p: Structure) -> Signature:
	var sig := Signature.new()
	if p == null or not p.standing():
		return sig
	var loud := signature().loudest()
	if loud == &"":
		loud = &"light" if night >= 0.5 else &"noise"
	var v := StructureKind.lure(p.kind) * lerpf(0.4, 1.0, p.condition())
	sig.set_channel(loud, v * _by_hour(String(loud)))
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
		"id": id, "realm": String(realm), "name": name, "centre": SaveCodec.vec2(centre),
		"pieces": out_pieces, "people": people, "looks": _looks_out(),
		"stores": SaveCodec.counts(stores), "tally": tally,
		"attention": attention, "night": night, "charge": charge,
		"worked_at": SaveCodec.num(worked_at), "hunger": hunger,
		"next_piece": _next_piece, "next_person": _next_person,
	}


## JSON has no integer keys, so who looks like what goes out as pairs.
func _looks_out() -> Array:
	var out := []
	for person_id: Variant in looks:
		out.append([SaveCodec.to_int(person_id), SaveCodec.to_int(looks[person_id])])
	return out


static func from_dict(d: Dictionary) -> Settlement:
	var s := Settlement.new(SaveCodec.to_int(d.get("id", 0)), StringName(d.get("realm", Realm.SURFACE)), SaveCodec.to_vec2(d.get("centre", Vector2.ZERO)), String(d.get("name", "")))
	for p: Variant in d.get("pieces", []):
		s.pieces.append(Structure.from_dict(p as Dictionary))
	for person: Variant in d.get("people", []):
		s.people.append(SaveCodec.to_int(person))
	for pair: Variant in d.get("looks", []):
		if pair is Array and (pair as Array).size() >= 2:
			s.looks[SaveCodec.to_int((pair as Array)[0])] = SaveCodec.to_int((pair as Array)[1])
	s.stores = SaveCodec.to_counts(d.get("stores", {}))
	var carried: Variant = d.get("tally", {})
	if carried is Dictionary:
		for k: Variant in carried:
			s.tally[String(k)] = SaveCodec.to_num((carried as Dictionary)[k])
	s.attention = float(d.get("attention", 0.0))
	s.night = float(d.get("night", 0.0))
	s.charge = float(d.get("charge", 0.0))
	s.worked_at = SaveCodec.to_num(d.get("worked_at", -INF), -INF)
	s.hunger = float(d.get("hunger", 0.0))
	s._next_piece = SaveCodec.to_int(d.get("next_piece", s.pieces.size() + 1), s.pieces.size() + 1)
	s._next_person = SaveCodec.to_int(d.get("next_person", s.people.size() + 1), s.people.size() + 1)
	return s
