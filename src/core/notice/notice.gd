class_name Notice
extends RefCounted
## One reading of a holding, in a machine's hands (docs/VISION.md).
##
## A notice is the whole reason a raid can be seen coming. Nothing files a
## settlement by dice: a body stood somewhere, read one channel of the place off
## `Signature`, and is now walking away with it. Until it gets clear the record
## is a thing in the world — it has a carrier, the carrier has a heading, and the
## player can kill it, jam it, or watch it go and know what that cost.
##
## Three ends, and the player decides which:
##   carried   the body still has it and is making for the plan's works
##   filed     it got away: the holding's attention rises by `worth`
##   stopped   the carrier died, or the reading was spoofed into nonsense
##
## Pure data. `Notices` holds the rules; 48_raids holds the live ones and saves
## them, so a game saved with a clerk halfway home resumes with it still walking.

var id := 0
var settlement_id := 0
## The realm the reading was taken in. A machine only ever senses a holding in
## its own realm (CLAUDE.md, the Raids row), so this is the realm of both.
var realm: StringName = Realm.SURFACE
## What took it: &"worker" &"watcher" &"drone" &"clerk" (Events.settlement_noticed).
var kind: StringName = &"worker"
## The roster kind of the body carrying it, for what the player is looking at.
var carrier: StringName = &""
## The Signature channel that gave the place away, and how good the reading is
## (0..1). One channel, not a sum: a machine reports the thing it noticed.
var channel: StringName = &"light"
var strength := 0.0
## The MobState id carrying it (-1 once the body is gone).
var mob_id := -1
## The piece that was read INSTEAD of the holding, or -1 for a reading taken of
## the yard itself (`Settlement.lures`). A decoy hides nothing: it shouts the
## holding's own loudest channel from where nobody lives, and a machine that took
## its account of the place off one walks home with a mast in a field. That is
## worth a quarter of the real thing (`Attention.LURED`), and `at` below is the
## DECOY's ground, because that is where the body stood and where it has to get
## clear of before anything is filed.
var lure := -1
## It got clear of the yard while somebody was watching (Notices.CLEAR_OF): past
## that the player could not have caught it, so if its body then goes off the
## land — culled, or a game put down — the reading counts as having got home.
## While it is false the record is still catchable, and a body that vanishes with
## one has to walk the whole way (Notices.HOME_MINUTES) before it is filed.
var clear := false
## Where it was taken, and the world minute.
var at := Vector2.ZERO
var taken_at := 0.0
## &"carried" &"filed" &"stopped".
var state: StringName = &"carried"
## Why it ended, for the line the world says: &"away" &"killed" &"jammed" &"lost".
var how: StringName = &""


func carried() -> bool:
	return state == &"carried"


func as_dict() -> Dictionary:
	return {
		"id": id, "settlement": settlement_id, "realm": String(realm),
		"kind": String(kind), "carrier": String(carrier), "channel": String(channel),
		"strength": strength, "mob": mob_id, "lure": lure, "clear": clear,
		"at": SaveCodec.vec2(at),
		"taken_at": taken_at, "state": String(state), "how": String(how),
	}


static func from_dict(d: Dictionary) -> Notice:
	var n := Notice.new()
	n.id = SaveCodec.to_int(d.get("id", 0))
	n.settlement_id = SaveCodec.to_int(d.get("settlement", 0))
	n.realm = StringName(str(d.get("realm", Realm.SURFACE)))
	n.kind = StringName(str(d.get("kind", &"worker")))
	n.carrier = StringName(str(d.get("carrier", "")))
	n.channel = StringName(str(d.get("channel", &"light")))
	n.strength = float(d.get("strength", 0.0))
	# A body is only ever a body in the game it was spawned in: a loaded notice
	# is one walking home with nobody in the world holding it, which is exactly
	# what a reading that has already left looks like.
	n.mob_id = -1
	# The piece a reading was taken off outlives the body that took it: what it
	# is worth when it lands, and where it has to get clear of, both hang on it.
	n.lure = SaveCodec.to_int(d.get("lure", -1), -1)
	n.clear = bool(d.get("clear", false))
	n.at = SaveCodec.to_vec2(d.get("at", Vector2.ZERO))
	n.taken_at = SaveCodec.to_num(d.get("taken_at", 0.0))
	n.state = StringName(str(d.get("state", &"carried")))
	n.how = StringName(str(d.get("how", "")))
	return n
