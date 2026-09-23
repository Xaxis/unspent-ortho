class_name RaidPlan
extends RefCounted
## One thing the plan has decided to do to one holding, from the moment the world
## first says so to the moment it is over (docs/VISION.md).
##
## A plan is made at the WARNING and not at the arrival, and that order is the
## whole contract: `warned_at` is when the horizon lit up, `begins_at` is when
## the machines get there, and everything between is the player's. It is saved,
## so a game put down halfway through a warning comes back halfway through the
## same warning, with the same party already decided.
##
## It knows nothing about bodies. 48_raids gives the party bodies when the player
## is there to see them and settles it on paper when they are not.

var id := 0
var settlement_id := 0
var realm: StringName = Realm.SURFACE
var stage: StringName = RaidStage.SURVEY
## &"warned" (on the way) | &"under_way" | &"over".
var state: StringName = &"warned"
## World minutes.
var warned_at := 0.0
var begins_at := 0.0
var ended_at := -INF
## What the holding's attention was when the world gave the warning: a step is
## called off if the player brings it down far enough before the machines arrive.
var attention_was := 0.0
## And what the holding was giving off at that moment. Attention is slow and a
## signature is not: killing the mast inside the window is the answer a player
## can actually reach in an hour, so a step is called off on this too.
var signature_was := 0.0
## The store has been loaded into their arms already, so nobody takes it twice.
## A FULL tribute (RaidRoles.TRIBUTE) buys the party off and nothing is broken;
## less than that they keep, and go on to what they came for.
var paid := false
## [{role, kind, target, mob}] — target is a piece id, a person id, or -1.
var party: Array = []
## Piece ids broken and people taken, for the aftermath and for a test.
var broke: Array[int] = []
var ruined: Array[int] = []
var took: Array[int] = []
## Machines of this party that did not come home.
var lost := 0
## &"" until it is over: &"held" &"broken" &"razed" &"left".
var outcome: StringName = &""


func coming() -> bool:
	return state == &"warned"


func on() -> bool:
	return state == &"under_way"


func over() -> bool:
	return state == &"over"


## Minutes of the warning window still to run at `now`.
func left(now: float) -> float:
	return maxf(0.0, begins_at - now)


func as_dict() -> Dictionary:
	return {
		"id": id, "settlement": settlement_id, "realm": String(realm),
		"stage": String(stage), "state": String(state),
		"warned_at": warned_at, "begins_at": begins_at,
		"ended_at": SaveCodec.num(ended_at), "attention_was": attention_was,
		"signature_was": signature_was, "paid": paid,
		"party": _party_out(), "broke": broke, "ruined": ruined, "took": took,
		"lost": lost, "outcome": String(outcome),
	}


func _party_out() -> Array:
	var out: Array = []
	for row: Dictionary in party:
		out.append({"role": String(row.get("role", &"")), "kind": String(row.get("kind", &"")),
			"target": int(row.get("target", -1))})
	return out


static func from_dict(d: Dictionary) -> RaidPlan:
	var p := RaidPlan.new()
	p.id = SaveCodec.to_int(d.get("id", 0))
	p.settlement_id = SaveCodec.to_int(d.get("settlement", 0))
	p.realm = StringName(str(d.get("realm", Realm.SURFACE)))
	p.stage = StringName(str(d.get("stage", RaidStage.SURVEY)))
	p.state = StringName(str(d.get("state", &"warned")))
	p.warned_at = SaveCodec.to_num(d.get("warned_at", 0.0))
	p.begins_at = SaveCodec.to_num(d.get("begins_at", 0.0))
	p.ended_at = SaveCodec.to_num(d.get("ended_at", -INF), -INF)
	p.attention_was = float(d.get("attention_was", 0.0))
	p.signature_was = float(d.get("signature_was", 0.0))
	p.paid = bool(d.get("paid", false))
	for row: Variant in d.get("party", []):
		var r := row as Dictionary
		if r == null:
			continue
		# The body is a thing of the game it was spawned in; the trade and what
		# it came for outlive the save.
		p.party.append({"role": StringName(str(r.get("role", &""))),
			"kind": StringName(str(r.get("kind", &""))),
			"target": SaveCodec.to_int(r.get("target", -1)), "mob": -1})
	for v: Variant in d.get("broke", []):
		p.broke.append(SaveCodec.to_int(v))
	for v: Variant in d.get("ruined", []):
		p.ruined.append(SaveCodec.to_int(v))
	for v: Variant in d.get("took", []):
		p.took.append(SaveCodec.to_int(v))
	p.lost = SaveCodec.to_int(d.get("lost", 0))
	p.outcome = StringName(str(d.get("outcome", "")))
	return p
