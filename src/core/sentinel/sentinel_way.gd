class_name SentinelWay
extends RefCounted
## One way of taking a landscape from its keeper (docs/VISION.md §3: "tactics,
## not stats. Each can be beaten several ways and none by trading hits").
##
## A way is a pure rule over a `SentinelLook`, so every one of them is provable
## headless and none of them is a special case buried in a system. The four kinds
## are the vocabulary the spine offers; a design picks three and fills in its own
## numbers, which is how the Coast's keeper is drowned in its own tide and the
## Salt Flats' is dropped through the crust it made.
##
##   FORCE    its body is spent: the working part found, phase after phase. Always
##            on the table and never enough on its own — the part moves, it is
##            guarded, and a player who stands and trades is taken.
##   FOUNDER  the land takes it: it stands where ground that will not carry a
##            machine of its weight (its own workings, tide mud, a pan's crust)
##            gives under it. The player's part is to make it come to them there,
##            which a charge that commits to a bearing is the answer to.
##   STARVE   the plan's own logic: a keeper is fed by the works it keeps, and a
##            region whose works are broken or robbed leaves it standing dark.
##   SPOOF    the plan's own logic again: inside its guard with a signature it
##            reads as one of the machines' own, it files the player as its own
##            and stands down. It is never killed; it stops keeping.

enum { FORCE, FOUNDER, STARVE, SPOOF }

const KIND_NAMES: Array[StringName] = [&"force", &"founder", &"starve", &"spoof"]

var kind := FORCE
## Grounds that will not carry it (FOUNDER), as Ground ids.
var grounds: Array[int] = []
## Prop kinds the player has to be standing beside for the signature to be
## READ (SPOOF), as PropKind ids; empty is anywhere inside its guard. A keeper
## that takes its orders off the district's own signal lamps files a signet
## held up under one of them and nowhere else, which is a tactic about the
## LAND (find a lamp inside its guard) and not a longer hold.
var beside: Array[int] = []
## The craft the player has to be riding for the signature to be READ (SPOOF),
## a `CraftKinds` id; empty is on foot or aboard anything. A keeper that keeps a
## canal's timetable reads a signature as one of its boats' calls, and a person
## wading its lane with a machine's signature is not a boat: the tactic is to
## come to it on the water, which is a tactic about the CRAFT and not a longer
## hold.
var aboard: StringName = &""
## How long the condition must hold (sim ms). 0 for FORCE.
var hold_ms := 0.0
## One line a player could be told, and one for whoever reads the design.
var says := ""
var note := ""


static func make(way_kind: int, hold: float = 0.0, ground_ids: Array[int] = []) -> SentinelWay:
	var w := SentinelWay.new()
	w.kind = way_kind
	w.hold_ms = hold
	w.grounds = ground_ids
	return w


func id() -> StringName:
	return KIND_NAMES[clampi(kind, 0, KIND_NAMES.size() - 1)]


## How far this way has come, 0..1. 1 is met. Pure.
func progress(look: SentinelLook) -> float:
	match kind:
		FORCE:
			return clampf(1.0 - look.health, 0.0, 1.0)
		FOUNDER:
			if not grounds.has(look.ground):
				return 0.0
			return clampf(look.ground_ms / maxf(1.0, hold_ms), 0.0, 1.0)
		STARVE:
			if look.feeds_at_first <= 0:
				# Nothing fed it in the first place: this way is not open here, and
				# it must never read as already won because there is nothing to break.
				return 0.0
			if look.feeds > 0:
				return clampf(1.0 - float(look.feeds) / float(look.feeds_at_first), 0.0, 0.99)
			return clampf(look.dark_ms / maxf(1.0, hold_ms), 0.0, 1.0)
		SPOOF:
			if not (look.spoofed and look.inside and reads_here(look)):
				return 0.0
			return clampf(look.spoof_ms / maxf(1.0, hold_ms), 0.0, 1.0)
	return 0.0


## Whether the player stands where this way reads a signature: beside one of
## `beside`, or anywhere when the way names nothing. The system asks this to
## decide whether the spoof clock RUNS, so a player who steps out from under the
## lamp loses the count rather than banking it.
func beside_met(look: SentinelLook) -> bool:
	if beside.is_empty():
		return true
	for k: int in look.beside:
		if beside.has(k):
			return true
	return false


## Whether the player is on the craft this way reads a signature from, or the
## way names none. Asked by the system beside `beside_met`, for the same reason:
## stepping off the raft loses the count rather than banking it.
func aboard_met(look: SentinelLook) -> bool:
	return aboard == &"" or look.riding == aboard


## Every gate on WHERE the signature is read, together: what the player stands
## beside and what they are riding. The spoof clock runs only while this holds.
func reads_here(look: SentinelLook) -> bool:
	return beside_met(look) and aboard_met(look)


func met(look: SentinelLook) -> bool:
	if kind == FORCE:
		return look.health <= 0.0
	return progress(look) >= 1.0


## A way that ends with the machine dead, rather than standing down. What a
## FOUNDER or a FORCE leaves is a hulk; a STARVE or a SPOOF leaves it standing
## and no longer keeping anything, which is a different picture in the same land.
func kills() -> bool:
	return kind == FORCE or kind == FOUNDER
