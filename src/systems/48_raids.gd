extends GameSystem
## Why and when the machines come for what the player built (docs/VISION.md §9.2
## to §9.7). Reachable as the system named "48_raids".
##
## **There is no raid timer and there never will be.** Every step this system
## takes can be traced back to something the player did or built and could have
## seen coming: a holding that gave itself away on a channel the slate already
## draws, a record a machine walked home with while they watched, a network they
## stirred, stolen technology humming in their own walls, or a machine they
## killed in their own yard that the plan is still waiting on. Nothing rolls to
## decide whether a place is raided, and hours passing with nothing happening
## only ever make a holding SAFER (tests/raid/test_attention.gd names that rule).
##
## What it owns:
##   the notices    a body reads a holding, and walks off with it. Until it is
##                  clear the record is a thing in the world: kill it, spoof it,
##                  take the record off it, follow it home, or let it go
##   the attention  one 0..1 per holding, 1 being a siege led by the region's
##                  keeper (`Attention` says what the unit is and what moves it)
##   the escalation survey -> probe -> raid -> siege, each WARNED by the world
##                  first and each answerable: fight, hide, spoof, evacuate, pay
##   the raid       a party with trades (breacher, harvester, snatcher) whose
##                  targets are chosen off the holding's own signature
##   the aftermath  wrecks in the yard, what the party could not carry, people
##                  gone, a razed holding left standing as ruins to reclaim, and
##                  a region that remembers
##
## It never builds, staffs, produces or repairs: that is 46_settlements. It holds
## `Settlement` objects and calls `damage_structure` on them, which that system
## reconciles and announces on its own next step — so this file emits none of
## `structure_damaged`/`structure_destroyed`, and 46 emits none of the four here.
##
## **A holding is only ever WARNED in the realm the player is standing in**, and
## only machines of its own realm ever read it. That is the whole of the per-realm
## ruling: attention is a thing one realm's machines keep about one realm's
## holdings, or it is one world-wide number again. A step already under way when
## the player walks down a shaft runs to its end without them — they were warned
## before they left, and coming home to what happened is a legitimate ending.
##
## Staging, for shots and tours:
##   --attention=F   every holding — stood up at boot or built during the run —
##                   starts at F (0..1) of the way to a siege. It stages a state
##                   a player reaches by living somewhere loud for days; it is
##                   never part of a normal start, and it still sends nothing
##                   until a machine has read the place.
##
## A staged holding is still not warned until something reads it, so a shot that
## wants the plan's tags on the pieces puts a reader beside it:
##
##   tools/shot.sh shots/raids/marked.png --seed=1 --hour=19.5 --weather=clear:0 \
##     --holding=hearth,hut,plot,radio_mast,palisade --attention=0.72 --spawn=clerk --frames=200
##   tools/tour.sh tours/raids.tour --seed=1 --hour=16 --weather=clear:0 --attention=0.7 \
##     --held=axe_felling --give=stone:8,deadwood:8,timber:8,scrap:12,reeds:8,rag:6,copper:4,pitch:4,driftwood:6
##   tools/tour.sh tours/raids-dark.tour --seed=7 --hour=15 --weather=clear:0 --held=axe_felling \
##     --give=driftwood:8,rag:6,deadwood:8,stone:8,timber:6,reeds:8

## Real seconds between sweeps. Everything here is settled against the WORLD
## clock from each holding's own timestamp, so this only decides how soon the
## player sees it, never what happened.
const SWEEP := 1.0
## World minutes settled in one step of the catch-up, the same slice the
## settlement package works in, so the two never disagree about an hour.
const SLICE := SettlementRules.SLICE
## World minutes since a holding was last read before quiet hours start cooling
## it. A place something looks at every hour is not a quiet place.
const QUIET_AFTER := 90.0
## Real seconds between looks at which machines can sense which holdings.
const SENSE_EVERY := 1.5
## A body only ever reads a holding once in this long: the plan does not file the
## same machine on the same place twice on one pass (world minutes).
const READ_AGAIN := 120.0
## Tiles from the player a raid is FOUGHT rather than settled on paper. Beyond
## it the party is not drawn at all and the player comes home to the yard, and a
## raid already under way when they walk out of it is settled the same way.
const LIVE_REACH := 46.0
## How near the body the player has to be for the record to come off it. It is
## proof lying in the grass where the carrier fell, not a thing that appears in
## the creel because something killed a clerk on the far side of the land.
const RECORD_REACH := 8.0
## Where a party comes out, how fast it marches in against its own walking pace,
## and how near a piece a machine has to be to put a blow into it. A party is
## seen crossing the ground for the best part of a quarter of a minute before it
## arrives, which is the last of the warnings and the one that says from which
## side (docs/VISION.md §9.4).
const PARTY_RING := 12.0
const MARCH := 1.9
const STRIKE_REACH := 1.4
## Near enough the holding to be AT it: what a frame called "the party at the
## gate" has to hold before the shutter falls, rather than the ring they were put
## out on, which is the far corner of the picture.
const PARTY_AT_GATE := 5.0
## World minutes after a step is over before the same holding is warned again:
## the plan does not send two parties at one place in an afternoon.
const COOL_OFF := 240.0
## Sim ms a snatcher has to stand in the yard before it gets somebody out.
const SNATCH_MS := 5000.0
## Sim ms of getting no nearer to what it came for before a raider steps aside
## and comes at it another way, and how far aside it steps. The ground between a
## party and a yard is full of what the ruin left — a fence, a hull, the corner
## of a house — and a raid that walks into a fence for an hour is a raid that
## never happened, which from the yard looks exactly like nothing.
const STUCK_MS := 1600.0
const STEP_ASIDE := 3.0
## Tiles from the holding's centre a survey plants its stake.
const STAKE_OUT := 3.4
## How much of a step's force a live party has already spent when its time runs
## out with bodies still standing: what the survivors got done, on paper.
const LEFTOVER := 0.45
## What one of a machine's own blows is worth against timber and plate.
const BLOW_SCALE := 1.2
## Sim ms of not looking up that keeping to the job buys, renewed every step.
## A raider is here for the HOLDING, not for the player: it will walk past
## somebody standing in its own yard and start cutting their mast down, and only
## a BLOW turns it. That is the whole of what makes a raid a raid rather than
## three more machines — the player chooses whether this is a fight, and the
## price of choosing it is that nothing is stopping the other two.
const JOB_MS := 600.0

## `--attention=F`, kept so a load can tell a staged game from a played one.
var attention_out := 0.0

var notices: Array[Notice] = []
var plans: Array[RaidPlan] = []
## Settlement id -> {settled_at, last_read, stake, surveyed, felt}.
var _books: Dictionary = {}
## "REALM:region id" -> {razed, lost, taken}. A region remembers
## (docs/VISION.md §9.6), and it remembers it in ONE realm: region ids restart at
## 0 in every realm's world (GenCountries.regions), so a bare id had the keeper
## of the caves' region 3 quieting a surface holding in region 3 for good.
var _regions: Dictionary = {}
## MobState id -> the Notice it is carrying.
var _carriers: Dictionary = {}
## MobState id -> {plan, role, target, settlement, since, strike_at}.
var _raiders: Dictionary = {}
## "sid:pid" -> the tag hanging on that piece, and where the piece it hangs on
## stands (the tag is turned to face the camera every frame, so it keeps its own
## anchor rather than asking the holding for the piece again).
var _marks: Dictionary = {}
var _mark_at: Dictionary = {}
## "sid:mob id" -> the world minute that body last read that place.
var _read_at: Dictionary = {}
var _sweep := 0.0
var _sense := 0.0
var _next_notice := 1
var _next_plan := 1
var _holdings: Node
var _dispositions: Node
## What the tour has been shown.
var _seen: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	RaidSpoils.declare()
	SaveGame.register(&"raids", _save, _load)
	Events.killed.connect(_on_killed)
	Events.sentinel_fell.connect(_on_sentinel_fell)
	Events.settlement_founded.connect(_on_founded)
	if g.options != null and g.options.attention > 0.0:
		attention_out = clampf(g.options.attention, 0.0, 1.0)


func started() -> void:
	# 46_settlements stands its holdings up in its own started(); this runs after
	# it (48 after 46), so every place is on its feet before anything is settled.
	_stage()
	_settle_attention()
	_sync_marks()


# --- the register this system reads ------------------------------------------

func holdings() -> Node:
	if _holdings == null or not is_instance_valid(_holdings):
		_holdings = null
		for s in game.systems:
			if s.name == "46_settlements":
				_holdings = s
	return _holdings


func dispositions() -> Node:
	if _dispositions == null or not is_instance_valid(_dispositions):
		_dispositions = null
		for s in game.systems:
			if s.name == "32_disposition":
				_dispositions = s
	return _dispositions


func places() -> Array[Settlement]:
	var h := holdings()
	if h == null:
		return [] as Array[Settlement]
	return h.call("all") as Array[Settlement]


func get_place(id: int) -> Settlement:
	for s in places():
		if s.id == id:
			return s
	return null


## Everything this system keeps about one holding that is not on the holding.
func book(id: int) -> Dictionary:
	if not _books.has(id):
		var now := game.clock.minutes if game != null and game.clock != null else 0.0
		_books[id] = {"settled_at": floorf(now / SLICE) * SLICE, "last_read": -INF,
			"stake": -1, "surveyed": false, "felt": 0}
	return _books[id]


## The plan's network a holding stands in: the REGION, which is the same file the
## disposition package keeps (docs/VISION.md §2). A holding a realm away stands in
## a network of a world that is not under the player's feet and cannot be asked.
func network_of(s: Settlement) -> int:
	if s.realm != realm_here():
		return Interference.REGIONLESS
	return Interference.network(game.world, s.centre)


func region_of(s: Settlement) -> int:
	if s.realm != realm_here():
		return -1
	return game.world.region_at(floori(s.centre.x), floori(s.centre.y))


## The plan's file on one region, which is one region OF ONE REALM. Nothing here
## may ever be keyed on a bare region id (see `_regions`).
func region_key(realm: StringName, region: int) -> String:
	return "%s:%d" % [String(realm), region]


## What the plan remembers of the region a holding stands in.
func _memory(s: Settlement) -> Dictionary:
	var r := region_of(s)
	if r < 0:
		return {}
	return _regions.get(region_key(s.realm, r), {}) as Dictionary


## A region whose keeper has been taken: its network is quiet for good
## (docs/VISION.md §9.7). Nothing is ever filed against a holding in one again.
func quieted(s: Settlement) -> bool:
	return bool(_memory(s).get("taken", false))


func realm_here() -> StringName:
	return game.world.realm if game != null and game.world != null else Realm.SURFACE


func _near(s: Settlement) -> bool:
	return game.player != null and s.realm == realm_here() and s.centre.distance_to(game.player.pos) <= LIVE_REACH


# --- 1. a notice is a thing in the world -------------------------------------

## Every machine standing about, against every holding of its OWN realm. A
## machine in the caves never senses a village on the surface: attention is per
## realm or it is one world-wide number again (CLAUDE.md, the Raids row).
func _sense_holdings() -> void:
	var sim: FightSim = game.player.sim
	if sim == null:
		return
	var here := realm_here()
	var minutes := game.clock.minutes
	var blind := 1.0 if minutes < game.body.spoof_until else 0.0
	var readable: Array[Settlement] = []
	var signs: Array[Signature] = []
	for s in places():
		if s.realm != here or quieted(s):
			continue
		readable.append(s)
		signs.append(s.signature())
	if readable.is_empty():
		return
	for m in sim.mobs:
		if not m.alive or m.removed or _carriers.has(m.id) or not Notices.reports(m.row):
			continue
		for i in readable.size():
			var s := readable[i]
			var key := "%d:%d" % [s.id, m.id]
			if minutes - float(_read_at.get(key, -INF)) < READ_AGAIN:
				continue
			var read := Notices.read(signs[i], s.centre, m.pos, m.row, blind)
			if read.is_empty():
				continue
			_read_at[key] = minutes
			_take_notice(s, m, read)
			break


## A body has read the place and is now walking home with it. It is announced the
## moment it is taken, so the player is told by the world that something is
## leaving with something — not later, when it is too late to do anything.
func _take_notice(s: Settlement, m: MobState, read: Dictionary) -> void:
	var n := Notice.new()
	n.id = _next_notice
	_next_notice += 1
	n.settlement_id = s.id
	n.realm = s.realm
	n.kind = Notices.kind_of(m.row)
	n.carrier = m.kind
	n.channel = read.get("channel", &"light")
	n.strength = float(read.get("strength", 0.0))
	n.mob_id = m.id
	n.at = s.centre
	n.taken_at = game.clock.minutes
	notices.append(n)
	_carriers[m.id] = n
	book(s.id)["last_read"] = n.taken_at
	# It turns for home along the plan's own survey bearing, so a player who
	# follows one is walking the machines' line and not a random heading.
	var home := m.pos + Notices.home_bearing(game.world.seed_value, m.pos, s.centre) * Notices.GOT_AWAY
	m.line_a = m.pos
	m.line_b = home
	m.line_to_b = true
	Events.settlement_noticed.emit(s.id, m.id, n.kind)
	Events.sfx.emit(&"raid_notice", game.world.to_3d(m.pos))
	_seen["noticed"] = true
	if _near(s):
		Events.hint.emit("%s read %s, and is leaving with it." % [_said_kind(n.kind), s.name], "")


## The carried records: each one either gets clear, or is stopped.
func _step_notices() -> void:
	var sim: FightSim = game.player.sim
	var minutes := game.clock.minutes
	for n in notices:
		if not n.carried():
			continue
		var m := _mob(sim, n.mob_id)
		if m != null and not m.alive:
			_lost_carrier(n, m.pos, &"killed")
			continue
		# A spoofed signature reaches the reading itself: what it is carrying
		# stops being about anybody. This is the signet's whole use here.
		if m != null and minutes < game.body.spoof_until and not Notices.got_away(n, m.pos):
			_stop(n, &"jammed")
			continue
		if m != null and m.removed:
			# Its body has gone off the land with the record on it, and where it
			# was standing when it went is the whole question. Past the yard it
			# was past catching, and walking over the horizon IS getting away.
			# Still in the yard, it has to walk the way home like anything else.
			if Notices.clear_of_holding(n, m.pos) or minutes - n.taken_at >= Notices.HOME_MINUTES:
				_file(n)
			continue
		if m == null:
			# Nobody in the world is holding it: a game loaded back with a reading
			# already in flight, or a realm crossed and left behind. It walks.
			# Filing these on the first frame turned a clerk the player could have
			# killed into a filed record by saving the game beside it.
			if minutes - n.taken_at >= Notices.HOME_MINUTES:
				_file(n)
			continue
		if Notices.got_away(n, m.pos) or minutes - n.taken_at >= Notices.HOME_MINUTES:
			_file(n)


func _mob(sim: FightSim, id: int) -> MobState:
	if sim == null or id < 0:
		return null
	for m in sim.mobs:
		if m.id == id:
			return m
	return null


## It got home. This is the one thing in the game that raises attention by a
## whole unit, and it was answerable every step of the way.
func _file(n: Notice) -> void:
	n.state = &"filed"
	n.how = &"away"
	@warning_ignore("return_value_discarded")
	_carriers.erase(n.mob_id)
	n.mob_id = -1
	var s := get_place(n.settlement_id)
	if s == null:
		return
	_raise(s, &"notice", Notices.worth(n) / Attention.NOTICE_FULL)
	_seen["filed"] = true
	# And it is SAID. This is the one link in the chain the player cannot see for
	# themselves — the taking, the jamming, the killing and every warning happen
	# in front of them, and a record getting home happens over the horizon — so a
	# player who watched a clerk walk off is told the moment it cost them.
	Events.sfx.emit(&"raid_filed", game.world.to_3d(s.centre))
	if _near(s):
		Events.hint.emit("What it had of %s is in the plan's hands now." % s.name, "")


## It never got there: killed in the yard, or its reading spoofed into nonsense.
## Attention comes DOWN, because the plan has lost what it thought it knew.
func _stop(n: Notice, how: StringName) -> void:
	n.state = &"stopped"
	n.how = how
	@warning_ignore("return_value_discarded")
	_carriers.erase(n.mob_id)
	var s := get_place(n.settlement_id)
	if s != null:
		_raise(s, &"stopped")
	_seen["stopped"] = true
	if how == &"jammed":
		Events.sfx.emit(&"raid_jammed", game.world.to_3d(n.at))
		if s != null and _near(s):
			Events.message.emit("Whatever it had of %s is nonsense now." % s.name)


## A carrier went down with the record on it. The record comes off the body: it
## is proof, and it is the one thing in the game worth more taken than left.
func _lost_carrier(n: Notice, at: Vector2, how: StringName) -> void:
	_stop(n, how)
	# It comes off the body where the body fell, and somebody has to be standing
	# there to take it. A carrier killed by something else on the far side of the
	# land is a record lying in the grass, not a thing that appears in the creel.
	if game.player == null or game.player.pos.distance_to(at) > RECORD_REACH:
		return
	for row: Dictionary in RaidSpoils.record(game.world.seed_value, n.id):
		var id: StringName = row.get("item", &"")
		var count := int(row.get("count", 1))
		if id == &"" or count <= 0 or Items.def(id).is_empty():
			continue
		game.inventory.add(id, count)
		Events.took.emit(id, count)
	Events.sfx.emit(&"raid_record", game.world.to_3d(at))
	_seen["record"] = true
	# And what it is, once, in the moment it is in the hand: proof, and a spool of
	# copper when proof is worth less than copper (Recipes: record_stripped).
	Events.hint.emit("Their own account of the place. Stripped, it is the copper a signet is wound from.", "")


func _said_kind(kind: StringName) -> String:
	match kind:
		&"clerk": return "A clerk"
		&"watcher": return "A watcher"
		&"drone": return "Something small"
	return "A worker"


# --- 2. attention -------------------------------------------------------------

## Move a holding's attention by a declared cause, and say so. `attention_changed`
## is the one door: nothing else in the game writes `Settlement.attention`.
##
## A rise is scaled by the configuration's `rules.raid_pace`; a FALL never is,
## because a playtest that wanted raids sooner must not also make quiet weeks
## worth less (docs/DEV.md, the master configurations).
func _raise(s: Settlement, cause: StringName, scale: float = 1.0) -> void:
	var was := s.attention
	if Attention.of(cause) > 0.0:
		scale *= pace()
	s.attention = Attention.raised(was, cause, scale)
	if absf(s.attention - was) > 1e-5:
		Events.attention_changed.emit(s.id, was, s.attention)


## How fast a holding earns the plan's attention, against the game as tuned.
func pace() -> float:
	return maxf(0.0, float(GameConfig.value("rules.raid_pace")))


## Whether anything is ever SENT. A holding is still read and still files with
## this off: what stops is the party at the gate, so a playtest can watch the
## whole notice and attention loop without losing a yard to it.
func sends() -> bool:
	return bool(GameConfig.value("rules.raids"))


## Settle every holding's attention up to the world clock, in whole slices from
## its own timestamp. Cheap and idempotent, so calling it every sweep, once an
## hour, or once after six hours away all give the same holding.
##
## The only things a SLICE can do on its own are take attention OFF (quiet hours)
## and put it on for FOUND technology the player chose to run inside their own
## walls. Nothing else here reads the clock, and that is the ruling.
func _settle_attention() -> void:
	if game == null or game.clock == null:
		return
	var now := game.clock.minutes
	var spoofed := now < game.body.spoof_until
	for s in places():
		var b := book(s.id)
		var at := float(b["settled_at"])
		if not is_finite(at):
			at = floorf(now / SLICE) * SLICE
		# The signature is read once for the whole catch-up: the found_tech
		# channel (the only one that RAISES here) is not weighed by the hour at
		# all, so the rise is exact however many slices are settled at once.
		var sig := s.signature()
		var dark := sig.total() < Attention.DARK_UNDER
		var masked := _mask_of(s)
		var found := sig.found_tech
		var quiet := not quieted(s)
		var guard := 0
		while at + SLICE <= now and guard < 4096:
			guard += 1
			at += SLICE
			var was := s.attention
			var hours := SLICE / 60.0
			if found > 0.0 and quiet:
				s.attention = Attention.from_found_tech(s.attention, found, hours * pace())
			if at - float(b["last_read"]) >= QUIET_AFTER:
				var night := SettlementRules.night_at(at) > 0.5
				s.attention = Attention.cooled(s.attention, hours, dark and night, spoofed, masked)
			if absf(s.attention - was) > 1e-5:
				Events.attention_changed.emit(s.id, was, s.attention)
		b["settled_at"] = at


## The strongest thing standing in the holding that hides it. Masks are inside
## the Signature already; this is the part that goes on working while nothing is
## looking, which is what a decoy is for.
func _mask_of(s: Settlement) -> float:
	var top := 0.0
	for p in s.pieces:
		if p.standing():
			top = maxf(top, float(p.signs().get("mask", 0.0)))
	return top


## The plan's network round a holding going up a level is the player's doing, in
## that region, and the holding standing in it wears it.
func _felt_interference() -> void:
	var d := dispositions()
	if d == null:
		return
	var interference: Interference = d.get("interference")
	if interference == null:
		return
	for s in places():
		if s.realm != realm_here() or quieted(s):
			continue
		var b := book(s.id)
		var lvl := interference.level(network_of(s))
		if lvl > int(b["felt"]):
			b["felt"] = lvl
			if lvl >= 2:
				_raise(s, &"interference")
		elif lvl < int(b["felt"]):
			b["felt"] = lvl


# --- 3. escalation, warned first ---------------------------------------------

## Is any holding due a step it is not already having? A plan is only ever made
## HERE, at the warning, and `_begin` is only ever called on a plan this made —
## which is how "every step is preceded by its warning" is kept true by
## construction rather than by care.
func _escalate() -> void:
	if not sends():
		return
	var now := game.clock.minutes
	for s in places():
		# Only ever warned in the realm the player is in: a step nobody could
		# have watched coming is the one thing this system may not do.
		if s.realm != realm_here() or quieted(s):
			continue
		var b := book(s.id)
		if not is_finite(float(b["last_read"])):
			# Nothing has ever read this place. The plan does not act on somewhere
			# it has not been told about, whatever else is on its books — which is
			# what makes a notice the first cause of everything that follows, and
			# what makes running dark an answer and not a delay.
			continue
		var i := RaidStage.due_at(s.attention)
		if i < 0:
			continue
		if _plan_for(s.id) != null:
			continue
		if RaidStage.name_of(i) == RaidStage.SURVEY and bool(b["surveyed"]):
			# They have already been and looked. Nothing comes again until the
			# place has earned more than a look, or until the stake is pulled up.
			continue
		if now - _last_ended(s.id) < COOL_OFF:
			continue
		_warn(s, RaidStage.name_of(i))


func _plan_for(settlement_id: int) -> RaidPlan:
	for p in plans:
		if p.settlement_id == settlement_id and not p.over():
			return p
	return null


func _last_ended(settlement_id: int) -> float:
	var last := -INF
	for p in plans:
		if p.settlement_id == settlement_id and p.over():
			last = maxf(last, p.ended_at)
	return last


## The world says it first. A warning is a thing that happens out there — lights
## along the survey line, something small over the yard, the set gone to static,
## one long note — and a tag hung on every piece the party is coming for, so the
## player can see WHICH of their own things gave them away.
func _warn(s: Settlement, stage: StringName) -> void:
	var p := RaidPlan.new()
	p.id = _next_plan
	_next_plan += 1
	p.settlement_id = s.id
	p.realm = s.realm
	p.stage = stage
	p.state = &"warned"
	p.warned_at = game.clock.minutes
	p.begins_at = p.warned_at + RaidStage.warn_minutes(stage)
	p.attention_was = s.attention
	p.signature_was = s.signature().total()
	p.party = _party_for(s, stage)
	plans.append(p)
	Events.raid_warned.emit(s.id, stage)
	var w := RaidStage.warning(stage)
	if not w.is_empty():
		Events.sfx.emit(StringName(w.get("sfx", &"raid_horizon")), game.world.to_3d(_warn_from(s)))
		if _near(s):
			Events.message.emit(String(w.get("says", "")))
	if _near(s):
		Events.hint.emit(RaidStage.says_coming(stage) % s.name, "h")
	_sync_marks()
	_seen["warned"] = true
	_seen["warned:%s" % String(stage)] = true


## Where a warning comes from: off along the bearing the machines surveyed this
## world on, so every warning in the game points the same way and a player learns
## which horizon to watch.
func _warn_from(s: Settlement) -> Vector2:
	return s.centre + Vector2.from_angle(GenWorks.bearing(game.world.seed_value)) * 40.0


## Who comes and what each one is for. The targets are read off the holding's
## OWN signature, so the thing the slate names on its page is the thing that is
## walked to first (docs/VISION.md §9.5).
func _party_for(s: Settlement, stage: StringName) -> Array:
	var out: Array = []
	var moment: Moment = game.player.sim.moment if game.player.sim != null else null
	var fits := func(_kind: StringName, row: Dictionary) -> bool:
		return moment == null or Spawner.moment_fits(row, moment)
	var want := RaidStage.party_size(stage)
	var roles: Array = RaidRoles.roles_for(stage)
	for i in mini(want, roles.size()):
		var role: StringName = roles[i]
		var kind := RaidRoles.kind_for(role, fits)
		if kind == &"":
			continue
		out.append({"role": role, "kind": kind, "target": RaidRoles.target_for(role, s), "mob": -1})
	return out


## The warning window has run out. Two things can have happened in it, and both
## are the player's doing: the place went quiet enough that the plan lost
## interest, or it did not.
func _step_plans() -> void:
	var now := game.clock.minutes
	for p in plans:
		if p.over():
			continue
		var s := get_place(p.settlement_id)
		if s == null:
			_end(p, null, &"left")
			continue
		if p.coming():
			if _called_off(p, s):
				# Brought down during the warning: nothing sets out. The tags come
				# off the pieces, which is how the player knows they answered it.
				_end(p, s, &"left")
				if _near(s):
					Events.message.emit("Whatever was coming for %s has turned back." % s.name)
				continue
			var due := RaidStage.due_at(s.attention)
			if due > RaidStage.index(p.stage):
				# It got worse while they were on the way. What was coming is
				# called off and something bigger is announced, with its own
				# window: a player who makes a bad afternoon worse hears about it.
				_reaim(p, s, RaidStage.name_of(due))
				continue
			if now < p.begins_at:
				continue
			_begin(p, s)
			continue
		_step_raid(p, s, now)


## Has the player answered the warning? Two ways, and both are theirs. The books
## came down far enough that the plan lost interest — slow, and rarely reachable
## inside one window — or the place stopped giving off what it was sent for,
## which is the fast answer and the one the warning window is the right length
## for: the mast down, the fire out, the people off the pieces.
func _called_off(p: RaidPlan, s: Settlement) -> bool:
	if quieted(s):
		return true
	if s.attention < p.attention_was * RaidStage.CALLED_OFF_UNDER:
		return true
	# A place that was always quiet is not called off here: it is walked to, found
	# to be nothing, and left (RaidResolve.nothing_here at the gate). What turns
	# them round on the road is the place going quiet AFTER the warning — which is
	# something the player did in the window, and the only thing they can do
	# enough of in an hour to be answered.
	return p.signature_was > 0.0 and s.signature().total() < p.signature_was * RaidStage.CALLED_OFF_SIGNATURE


## The same warning again, for a bigger step. The plan keeps its identity — one
## per holding — so nothing can end up with two parties on the way at once.
func _reaim(p: RaidPlan, s: Settlement, stage: StringName) -> void:
	p.stage = stage
	p.warned_at = game.clock.minutes
	p.begins_at = p.warned_at + RaidStage.warn_minutes(stage)
	p.attention_was = s.attention
	p.signature_was = s.signature().total()
	p.party = _party_for(s, stage)
	Events.raid_warned.emit(s.id, stage)
	var w := RaidStage.warning(stage)
	if not w.is_empty():
		Events.sfx.emit(StringName(w.get("sfx", &"raid_horizon")), game.world.to_3d(_warn_from(s)))
		if _near(s):
			Events.message.emit(String(w.get("says", "")))
	if _near(s):
		Events.hint.emit(RaidStage.says_coming(stage) % s.name, "h")
	_sync_marks()
	_seen["warned"] = true
	_seen["warned:%s" % String(stage)] = true
	_seen["reaimed"] = true


func _begin(p: RaidPlan, s: Settlement) -> void:
	p.state = &"under_way"
	p.begins_at = game.clock.minutes
	Events.raid_began.emit(s.id, p.stage)
	_seen["raid"] = true
	_seen["raid:%s" % String(p.stage)] = true
	if RaidResolve.nothing_here(s, p.stage):
		# They came, and there was nothing here worth the walk. Evacuating and
		# running dark is a real answer and this is what it buys.
		_end(p, s, &"left")
		if _near(s):
			Events.message.emit("They went through %s, found nothing worth taking, and left." % s.name)
		return
	if p.stage == RaidStage.SURVEY:
		_survey(s)
		_end(p, s, &"held")
		return
	if _near(s):
		_put_out(p, s)
		return
	_settle_raid(p, s, 1.0)


## A survey does not break anything: it drives the plan's own stake into the
## ground at the edge of the yard and goes. The stake is a real work of the plan
## (PropKind.SURVEY), so pulling it up is a real theft against the region — which
## is exactly the price of destroying a record before it travels.
func _survey(s: Settlement) -> void:
	var b := book(s.id)
	b["surveyed"] = true
	if int(b["stake"]) >= 0 or s.realm != realm_here():
		return
	var out := Vector2.from_angle(GenWorks.bearing(game.world.seed_value)) * STAKE_OUT
	var spot := Sentinels.stand_near(game.world, s.centre + out, 0.4)
	var prop := Survival.add_prop(game, PropKind.SURVEY, spot)
	b["stake"] = prop.id
	_seen["stake"] = true
	if _near(s):
		Events.message.emit("They have driven a stake in at the edge of %s." % s.name)


# --- 4. the raid --------------------------------------------------------------

## Give the party bodies. They come out of the ring round the holding and walk in
## on the thing each of them was sent for; the fight simulation drives them like
## any other machine the moment they notice the player.
func _put_out(p: RaidPlan, s: Settlement) -> void:
	var sim: FightSim = game.player.sim
	if sim == null:
		_settle_raid(p, s, 1.0)
		return
	var bearing := GenWorks.bearing(game.world.seed_value)
	var n := p.party.size()
	for i in n:
		var row: Dictionary = p.party[i]
		var kind: StringName = row.get("kind", &"")
		if kind == &"":
			continue
		var a := bearing + (float(i) - float(n - 1) * 0.5) * 0.5
		var at := _march_from(s, a, float(Roster.row(kind).get("radius", 0.5)))
		var m := sim.add_mob(kind, at)
		# It is here for the holding, not for the player: hostile, so its lamps
		# say so and the slate reads it as what it is, and `sent`, so the network
		# that spent it is not told about it again when it does not come home.
		m.disturbed = true
		m.disturbed_by = &""
		m.turn_filed = true
		m.sent = true
		# And the coast does not cull it (MobState.raider): a party is taken off
		# the land by the plan that sent it, never by the player walking away.
		m.raider = true
		m.home = s.centre
		m.facing = (s.centre - at).angle()
		m.aim = m.facing
		m.bearing = Vector2.from_angle(m.facing)
		# On a march, not on a round: a body walking its line goes at a share of
		# its pace (Brains), and a party that took four minutes to cross a field
		# would be a raid nobody could stay awake for.
		m.pace *= MARCH
		row["mob"] = m.id
		_raiders[m.id] = {"plan": p.id, "role": row.get("role", &""), "target": int(row.get("target", -1)),
			"settlement": s.id, "since": sim.now, "strike_at": -INF,
			"closest": INF, "stalled_at": sim.now, "side": 1.0}
	if RaidStage.led_by_keeper(p.stage):
		_call_the_keeper(s, bearing)
	_seen["party"] = true


## A siege is led by the region's own keeper (docs/VISION.md §9.4). Its body is
## put down at the party's ring and 44_sentinels ADOPTS it — a keeper is a keeper
## however it arrived — so it comes with its real health, its real phases, and
## the three ways it can be taken. Which is the point: a siege is where killing
## the thing that files you becomes something a player can reach.
func _call_the_keeper(s: Settlement, bearing: float) -> void:
	var def := Sentinels.for_land(BiomeRegistry.at(game.world, s.centre).id)
	if def == null or not Roster.has(def.kind):
		return
	var sim: FightSim = game.player.sim
	for m in sim.mobs:
		if m.alive and not m.removed and Roster.sentinel_of(m.kind) != &"":
			return
	var at := _march_from(s, bearing, float(Roster.row(def.kind).get("radius", 1.2)))
	var keeper := sim.add_mob(def.kind, at)
	keeper.facing = (s.centre - at).angle()
	keeper.aim = keeper.facing
	keeper.bearing = Vector2.from_angle(keeper.facing)
	_seen["siege_keeper"] = true


## Where one of them comes out of the land: on the plan's own bearing if there is
## a way in from there, and otherwise round until there is. The line has to be
## WALKABLE to the holding — a party put down across a channel or behind a cliff
## walks into it for an hour and the raid never happens, which is the worst kind
## of failure this system can have, because from the yard it looks like nothing.
func _march_from(s: Settlement, want: float, body: float) -> Vector2:
	var loose := Vector2.INF
	# Outward first, and in toward the yard until there is a way: a party seen
	# crossing the land is the better picture, but a party that cannot get in is
	# not a raid at all, and coming out of the dark at the fence is still a raid.
	for share: float in [1.0, 0.85, 0.7, 0.55, 0.45, 0.35]:
		for turn: float in [0.0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2, 1.6, -1.6, 2.0, -2.0, 2.4, -2.4, 2.8, -2.8, PI]:
			var p := s.centre + Vector2.from_angle(want + turn) * PARTY_RING * share
			if not _can_stand(p):
				continue
			if not is_finite(loose.x):
				loose = p
			if _way_in(p, s.centre, body):
				return p
	if is_finite(loose.x):
		return loose
	return _standable(s.centre + Vector2.from_angle(want) * PARTY_RING, s.centre)


func _can_stand(p: Vector2) -> bool:
	var tx := floori(p.x)
	var ty := floori(p.y)
	return game.world.in_bounds(tx, ty) and game.query.standable(tx, ty) \
			and not Ground.is_water(game.world.ground_at(tx, ty))


## Is there a way in from `a` to `b` for a body this wide: dry, no cliff, and
## clear of anything solid, along the middle and both flanks?
##
## It is stricter than `NavField.line_walkable` on purpose. That one asks whether
## the TERRAIN carries a line, and it counts shallows as ground; a machine cannot
## walk in water at all, and a holding built in a village's gaps has houses,
## fences and hulls on every line into it. A party put down where it can only
## slide along a wall for an hour is the worst failure this system has, because
## from the yard it looks exactly like nothing happening.
func _way_in(a: Vector2, b: Vector2, body: float) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / 0.8))
	var across := (b - a).normalized().orthogonal() * maxf(body, 0.3)
	var last := game.world.level_at(floori(a.x), floori(a.y))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(steps))
		if not _can_stand(p) or not _can_stand(p + across) or not _can_stand(p - across):
			return false
		var l := game.world.level_at(floori(p.x), floori(p.y))
		if absi(l - last) > 1:
			return false
		last = l
		for q in game.query.props_near(p, 3.2):
			# A holding's own pieces have negative ids (46_settlements' footprints).
			# They are what the party CAME for: a wall in the way is the raid, not
			# a reason to call one off.
			if q.id < 0 or q.solid <= 0.0 or game.world.depleted.has(q.id):
				continue
			if q.pos.distance_to(p) < q.solid + body + 0.2:
				return false
	return true


func _standable(want: Vector2, toward: Vector2) -> Vector2:
	var step := (toward - want).normalized()
	for i in 18:
		var p := want + step * float(i) * 0.9
		var tx := floori(p.x)
		var ty := floori(p.y)
		if game.query.standable(tx, ty) and not Ground.is_water(game.world.ground_at(tx, ty)):
			return p
	return toward


## Steer whatever is left of a live party, and settle it when it is over.
func _step_raid(p: RaidPlan, s: Settlement, now: float) -> void:
	var sim: FightSim = game.player.sim
	var live := 0
	for row: Dictionary in p.party:
		if p.over():
			# One of them bought the whole party off with what was lying in the
			# yard (`_tribute`): there is no raid left to steer.
			return
		var m := _mob(sim, int(row.get("mob", -1)))
		if m == null or not m.alive or m.removed:
			continue
		live += 1
		_drive(p, s, m, sim)
	if p.over():
		return
	if live > 0 and not _near(s):
		# The player has left the yard while it was going on. The rest of it
		# happens without them, on the same arithmetic as a raid they were never
		# at: coming home to what happened is the ending, not a way of calling it
		# off. Anything the party had not spent yet is spent here.
		_pull_party(p, sim)
		_settle_raid(p, s, _unspent(p))
		return
	if live > 0 and now - p.begins_at < RaidStage.minutes(p.stage):
		return
	if live > 0:
		# It has run its course with bodies still standing: they take what they
		# came for and go, which is the same arithmetic as a raid nobody saw.
		_pull_party(p, sim)
		_settle_raid(p, s, LEFTOVER)
		return
	var left := _unspent(p)
	if left > 0.0:
		# Bodies went off the land without the player putting them down and
		# without finishing their errand — a realm crossing, a game cleared. What
		# they were sent with is settled rather than forgotten, because a step
		# that pays itself off for nothing is the cheapest raid in the game.
		_settle_raid(p, s, left)
		return
	if p.broke.is_empty() and p.took.is_empty():
		# Every one of them went down in the yard before it got anything: the
		# holding held, and it cost the plan bodies it is still waiting on.
		_end(p, s, &"held")
		return
	_end(p, s, RaidResolve.outcome_of(s, {"broke": p.broke, "ruined": p.ruined, "took": p.took}))


## Take whatever of a party is still standing off the land. Nothing else ever
## removes a raider: the coast is told to leave them alone (MobState.raider), so
## a party stands in the yard until this system is done with it.
func _pull_party(p: RaidPlan, sim: FightSim) -> void:
	if sim == null:
		return
	for row: Dictionary in p.party:
		var m := _mob(sim, int(row.get("mob", -1)))
		if m == null or not m.alive or m.removed:
			continue
		m.raider = false
		sim.remove_mob(m)
		@warning_ignore("return_value_discarded")
		_raiders.erase(m.id)


## The share of a step still in the hands of bodies that neither died in the yard
## nor finished what they came for: what is settled on paper when the party stops
## being something the player is standing in front of.
func _unspent(p: RaidPlan) -> float:
	var sent := 0
	var left := 0
	for row: Dictionary in p.party:
		if int(row.get("mob", -1)) < 0:
			continue
		sent += 1
		if not bool(row.get("done", false)) and not bool(row.get("killed", false)):
			left += 1
	if sent <= 0:
		# Nothing of this party is a body any more: a game loaded back into the
		# middle of a step, or a realm crossed. What it is still worth is what it
		# had left when the bodies went — the plan saves its dead (`lost`).
		var n := p.party.size()
		return 1.0 if n <= 0 else clampf(float(n - p.lost) / float(n), 0.0, 1.0)
	return float(left) / float(sent)


## Mark what became of one of the party, so `_unspent` never pays twice for a
## snatcher that got its person, nor forgets a breacher that was killed.
func _spent(p: RaidPlan, mob_id: int, key: String) -> void:
	for row: Dictionary in p.party:
		if int(row.get("mob", -1)) == mob_id:
			row[key] = true
			return


## One raider, this step. Answered — struck, or stood in front of — the fight
## simulation has it and this does nothing: a machine fighting the player is a
## machine the player is paying for with the time it is not spending on the
## walls. Otherwise it walks at what it was sent for and puts blows into it.
func _drive(p: RaidPlan, s: Settlement, m: MobState, sim: FightSim) -> void:
	var r: Dictionary = _raiders.get(m.id, {})
	if r.is_empty() or not _on_the_job(m, sim):
		return
	var role: StringName = r.get("role", &"")
	if role == RaidRoles.SNATCHER:
		_drive_snatcher(p, s, m, r, sim)
		return
	if role == RaidRoles.SCOUT:
		# It came to look. It stands off the place, reads it, and goes home with
		# what it saw: the probe's eyes, and the thing worth killing first.
		_drive_scout(s, m, r, sim)
		return
	var piece := s.piece(int(r.get("target", -1)))
	if piece == null or not piece.standing():
		# What it came for is down: it takes the next thing of its trade, and if
		# there is nothing left it stands off and the raid runs out.
		var next := RaidRoles.target_for(role, s)
		r["target"] = next
		piece = s.piece(next)
		if piece == null:
			m.line_a = m.pos
			m.line_b = m.pos
			return
	var d := m.pos.distance_to(piece.pos)
	if d > STRIKE_REACH + m.radius + StructureKind.solid(piece.kind):
		_march(m, r, piece.pos, d, sim)
		return
	m.line_a = m.pos
	m.line_b = m.pos
	m.aim = (piece.pos - m.pos).angle()
	if role == RaidRoles.HARVESTER and _tribute(p, s, m, sim):
		return
	_strike(p, s, m, r, piece, sim)


## A full store lying loose in the yard buys them off, and it does so with the
## player standing there. docs/DESIGN.md offers paying them as one of the answers
## inside the warning window; until this, only a raid nobody was at could be paid
## — the live harvester walked past the store and started cutting the mast down.
## It is the same door the paper settle uses (RaidResolve.take_stores), and it is
## expensive: they take what a week of the plot made.
func _tribute(p: RaidPlan, s: Settlement, m: MobState, sim: FightSim) -> bool:
	if p.paid or s.stores.is_empty():
		return false
	# The same arithmetic as the paper settle, to the number: they carry what the
	# step's force is worth, up to a tribute, and only a FULL tribute buys them.
	var took := RaidResolve.take_stores(s, RaidResolve.through(p.stage, s.defence_total()))
	if took.is_empty():
		return false
	p.paid = true
	_seen["looted"] = true
	Events.sfx.emit(&"raid_loot", game.world.to_3d(m.pos))
	var carried := 0.0
	for k: Variant in took:
		carried += float(took[k])
	if carried < RaidRoles.TRIBUTE:
		# Not enough lying loose to be worth the walk on its own: they take it and
		# go on to the thing they came for.
		if _near(s):
			Events.message.emit("They have taken what was lying in %s, and they are not finished." % s.name)
		return false
	_seen["paid"] = true
	if _near(s):
		Events.message.emit("They have loaded up what was lying in %s, and that is what they came for." % s.name)
	# Paid, the whole party turns round: nothing is broken and nobody is taken,
	# which is the same ending the arithmetic gives when nobody is home.
	_pull_party(p, sim)
	_end(p, s, &"held")
	return true


## Is this one still about its errand? A raider that has been struck, or that
## belongs to the fight from then on and this system leaves it alone. One that
## has not is kept on the job: it does not even look up (`calm_until`), which is
## the same door a keeper that has stood down uses, and it is what lets a player
## stand in their own yard and watch their mast being taken apart, and have to
## decide whether to make it their fight.
func _on_the_job(m: MobState, sim: FightSim) -> bool:
	if m.health < m.max_health:
		return false
	m.calm_until = maxf(m.calm_until, sim.now + JOB_MS)
	# And it does not stop for a noise either. A body at its work puts its optics
	# on whatever it heard and stands there until it is satisfied (Brains), which
	# is right for a worker on its round and wrong for a party with orders: the
	# first fire crackling in the yard it came to break would hold the whole raid
	# on the spot for the rest of the night.
	m.look_until = -INF
	if m.roused() or m.mood == MobState.ALERTED:
		m.set_mood(MobState.IDLE, sim.now)
		m.suspicion = 0.0
		m.charging = false
		m.lost_beats = 999
	return true


## One step of the march, and the way round whatever is in it. A machine walking
## its line goes in a straight one (Brains), so anything the ruin left between it
## and the yard stops it dead; getting no nearer for STUCK_MS is how it finds out,
## and `via` — the same door a worker uses to go round somebody on its round — is
## how it answers.
func _march(m: MobState, r: Dictionary, to: Vector2, d: float, sim: FightSim) -> void:
	# BOTH ends of its line are the thing it came for. A body walking a line
	# turns back on the beat it is held up (Brains), and a line whose other end
	# was the machine's own feet meant one bump left it standing on the spot
	# facing its own toes for the rest of the raid.
	m.line_a = to + (to - m.pos).normalized() * 0.6
	m.line_b = to
	m.line_to_b = true
	if d < float(r.get("closest", INF)) - 0.25:
		r["closest"] = d
		r["stalled_at"] = sim.now
		return
	if sim.now - float(r.get("stalled_at", sim.now)) < STUCK_MS or m.via.is_finite():
		return
	r["stalled_at"] = sim.now
	var side := -float(r.get("side", 1.0))
	r["side"] = side
	var aside := (to - m.pos).normalized().orthogonal() * side * STEP_ASIDE
	var round_it := m.pos + aside + (to - m.pos).normalized() * 0.8
	var tx := floori(round_it.x)
	var ty := floori(round_it.y)
	if game.world.in_bounds(tx, ty) and game.query.standable(tx, ty) and not Ground.is_water(game.world.ground_at(tx, ty)):
		m.via = round_it


## A scout stands where it can read the whole place and then leaves along the
## survey line. It never puts a blow into anything; what it takes away is the
## notice, and the notice is what brings the rest.
func _drive_scout(s: Settlement, m: MobState, r: Dictionary, sim: FightSim) -> void:
	var stand := Notices.CLEAR_OF * 0.6
	var d := m.pos.distance_to(s.centre)
	if d > stand + 1.0:
		_march(m, r, s.centre, d - stand, sim)
		return
	m.line_a = m.pos
	m.line_b = m.pos
	m.aim = (s.centre - m.pos).angle()
	r["target"] = -1


## A raider hitting a wall throws its own bite, so the tell, the pose, the sound
## and the timing are the ones a player already reads on that machine. The piece
## takes the blow at the moment the blade would land.
func _strike(p: RaidPlan, s: Settlement, m: MobState, r: Dictionary, piece: Structure, sim: FightSim) -> void:
	var pending := float(r.get("strike_at", -INF))
	if is_finite(pending) and sim.now >= pending:
		r["strike_at"] = -INF
		var ruined := s.damage_structure(piece.id, _blow_of(m, s))
		if not p.broke.has(piece.id):
			p.broke.append(piece.id)
		if ruined and not p.ruined.has(piece.id):
			p.ruined.append(piece.id)
			_wreck_left(s, piece)
		Events.sfx.emit(&"raid_break", game.world.to_3d(piece.pos))
		_seen["raid_damage"] = true
		return
	if is_finite(pending) or m.bite == null or m.blow_phase(sim.now) != &"":
		return
	Brains.bite(m, sim)
	r["strike_at"] = m.blow_at + float(m.bite.windup) + float(m.bite.active) * 0.5


## What one of its blows is worth against timber and plate. A machine's bite is
## written for a body; a wall is not a body, so it is the bite scaled, never a
## number of this system's own invention — and then the holding's own defences
## take their share of it, exactly as they do when the raid is settled on paper
## (RaidResolve.turned). Without that, a second plate wall halved a raid the
## player was away for and changed nothing about one they stood in, which is the
## wrong way round: a wall you are defending should be worth more, not less.
func _blow_of(m: MobState, s: Settlement) -> float:
	var dmg := float(m.bite.dmg if m.bite != null else 1)
	return maxf(RaidResolve.LEAST, dmg * BLOW_SCALE * (1.0 - RaidResolve.turned(s.defence_total())))


## Somebody is carried off (docs/VISION.md §9.5). The snatcher has to stand in
## the yard unanswered to do it, so being there is a real answer to it.
func _drive_snatcher(p: RaidPlan, s: Settlement, m: MobState, r: Dictionary, sim: FightSim) -> void:
	var d := m.pos.distance_to(s.centre)
	if d > 2.0:
		_march(m, r, s.centre, d, sim)
		return
	m.line_a = m.pos
	m.line_b = m.pos
	if sim.now - float(r.get("since", sim.now)) < SNATCH_MS:
		return
	var who := int(r.get("target", -1))
	if who < 0 or not s.people.has(who):
		who = RaidRoles.snatch_target(s)
	if who >= 0:
		_take_person(s, who)
		p.took.append(who)
		Events.sfx.emit(&"raid_snatch", game.world.to_3d(s.centre))
		if _near(s):
			Events.message.emit("They have taken somebody out of %s." % s.name)
	# It has what it came for and it walks off with it: its share of the step is
	# spent, so nothing settles it a second time on paper.
	_spent(p, m.id, "done")
	m.raider = false
	sim.remove_mob(m)
	@warning_ignore("return_value_discarded")
	_raiders.erase(m.id)


## Off the holding's books, and off whatever they were working. The body walking
## in the yard is let go of through the settlement system's own door when there
## is one; until then it is left to walk away, which is what it looks like.
func _take_person(s: Settlement, who: int) -> void:
	for piece in s.pieces:
		if piece.staffed_by == who:
			piece.staffed_by = -1
	s.people.erase(who)
	@warning_ignore("return_value_discarded")
	s.looks.erase(who)
	var h := holdings()
	if h != null and h.has_method("_send_away"):
		h.call("_send_away", s, who)
	_seen["snatched"] = true


## Settle whatever the party did not do by hand.
func _settle_raid(p: RaidPlan, s: Settlement, share: float) -> void:
	var report := RaidResolve.resolve(s, p.stage, game.world.seed_value, p.id, share)
	for id: int in report.get("broke", []):
		if not p.broke.has(id):
			p.broke.append(id)
	for id: int in report.get("ruined", []):
		if not p.ruined.has(id):
			p.ruined.append(id)
			var piece := s.piece(id)
			if piece != null:
				_wreck_left(s, piece)
	for who: int in report.get("took", []):
		_take_person(s, who)
		p.took.append(who)
	if not (report.get("stores", {}) as Dictionary).is_empty():
		_seen["looted"] = true
	if not p.broke.is_empty():
		_seen["raid_damage"] = true
	_end(p, s, RaidResolve.outcome_of(s, report))


## What a broken piece leaves in the yard: a machine's blow does not tidy up
## after itself, and a raided holding has to read like one tomorrow
## (docs/ART.md §10). 46_settlements keeps the wreck of the piece itself.
func _wreck_left(s: Settlement, piece: Structure) -> void:
	if s.realm != realm_here():
		return
	var spot := piece.pos + Vector2.from_angle(float(piece.id) * 2.4) * 1.1
	@warning_ignore("return_value_discarded")
	Survival.add_prop(game, PropKind.DEBRIS, spot, Rng.hash01(game.world.seed_value, piece.id, 0x5A1D) * TAU, 0.9)


# --- 5. aftermath -------------------------------------------------------------

func _end(p: RaidPlan, s: Settlement, outcome: StringName) -> void:
	p.state = &"over"
	p.outcome = outcome
	p.ended_at = game.clock.minutes
	# Whatever is still standing in the yard goes with it. Nothing else takes a
	# raider off the land, so a plan that ends without this leaves its machines
	# walking about the holding for ever.
	if game.player != null:
		_pull_party(p, game.player.sim)
	for row: Dictionary in p.party:
		var id := int(row.get("mob", -1))
		if id >= 0:
			@warning_ignore("return_value_discarded")
			_raiders.erase(id)
	if s != null:
		if outcome != &"left":
			var was := s.attention
			s.attention = clampf(was - RaidStage.spends(p.stage), 0.0, 1.0)
			if absf(s.attention - was) > 1e-5:
				Events.attention_changed.emit(s.id, was, s.attention)
		if outcome == &"razed":
			_raze(s)
		Events.raid_ended.emit(s.id, outcome)
		_seen["raid_ended"] = true
		_seen["raid_ended:%s" % String(outcome)] = true
		if _near(s):
			Events.message.emit(_says_ended(s, outcome))
	_sync_marks()


func _says_ended(s: Settlement, outcome: StringName) -> String:
	match outcome:
		&"held": return "%s held." % s.name
		&"broken": return "They have been through %s." % s.name
		&"razed": return "There is nothing left of %s but what it was made of." % s.name
	return "They came to %s and went away again." % s.name


## Nothing of it is standing. The ruin stays exactly where it fell — every piece
## is a wreck 46_settlements gives half of back for clearing, which is what
## reclaiming a razed holding means — and what the party could not carry is left
## lying in the yard for whoever comes back for it.
func _raze(s: Settlement) -> void:
	var region := region_of(s)
	if region >= 0:
		var key := region_key(s.realm, region)
		var mem: Dictionary = _regions.get(key, {"razed": 0, "lost": 0, "taken": false})
		mem["razed"] = int(mem.get("razed", 0)) + 1
		_regions[key] = mem
	var land: StringName = BiomeRegistry.at(game.world, s.centre).id if s.realm == realm_here() else &""
	for row: Dictionary in RaidSpoils.razed(game.world.seed_value, s.id, land):
		var id: StringName = row.get("item", &"")
		var n := int(row.get("count", 0))
		if id == &"" or n <= 0:
			continue
		s.stores[id] = int(s.stores.get(id, 0)) + n
	_seen["razed"] = true


## A machine of a party that did not come home. The plan does not forget one: it
## is the most expensive thing on the whole board, and it is the price of
## standing and fighting rather than hiding, spoofing or paying.
func _on_killed(kind: StringName, at: Vector3) -> void:
	var p2 := Vector2(at.x, at.z)
	var sim: FightSim = game.player.sim
	var body := _body_at(sim, kind, p2)
	if body == null:
		return
	var carried: Notice = _carriers.get(body.id, null)
	if carried != null and carried.carried():
		_lost_carrier(carried, p2, &"killed")
	var r: Dictionary = _raiders.get(body.id, {})
	if r.is_empty():
		return
	@warning_ignore("return_value_discarded")
	_raiders.erase(body.id)
	# A machine broken in the yard stays in the yard: salvage, and the reason a
	# holding that has stood three raids looks like it (docs/ART.md §10).
	@warning_ignore("return_value_discarded")
	Survival.add_prop(game, PropKind.WRECKAGE, p2, Rng.hash01(game.world.seed_value, body.id, 0x77) * TAU, 0.8)
	var plan := _plan(int(r.get("plan", -1)))
	if plan != null:
		plan.lost += 1
		_spent(plan, body.id, "killed")
	var s := get_place(int(r.get("settlement", -1)))
	if s == null:
		return
	_raise(s, &"lost")
	var region := region_of(s)
	if region >= 0:
		var key := region_key(s.realm, region)
		var mem: Dictionary = _regions.get(key, {"razed": 0, "lost": 0, "taken": false})
		mem["lost"] = int(mem.get("lost", 0)) + 1
		_regions[key] = mem
	_seen["raider_down"] = true


func _body_at(sim: FightSim, kind: StringName, p: Vector2) -> MobState:
	if sim == null:
		return null
	for m in sim.mobs:
		if not m.alive and m.kind == kind and m.pos.distance_squared_to(p) < 0.01:
			return m
	return null


func _plan(id: int) -> RaidPlan:
	for p in plans:
		if p.id == id:
			return p
	return null


## The region's keeper is gone, so its network is gone with it: every holding in
## it is forgotten, whatever it is running, for good (docs/VISION.md §9.7). This
## is the surest answer in the game, and it is a boss fight.
func _on_sentinel_fell(region: int, _land: StringName, _how: StringName) -> void:
	# A keeper is a keeper of a region OF A REALM. The one that fell is the one in
	# the world the player is standing in, and nothing a realm away hears of it.
	var here := realm_here()
	var key := region_key(here, region)
	var mem: Dictionary = _regions.get(key, {"razed": 0, "lost": 0, "taken": false})
	mem["taken"] = true
	_regions[key] = mem
	for s in places():
		if s.realm != here or region_of(s) != region:
			continue
		var was := s.attention
		s.attention = 0.0
		if was > 0.0:
			Events.attention_changed.emit(s.id, was, 0.0)
		var p := _plan_for(s.id)
		if p != null:
			_end(p, s, &"left")
		if _near(s):
			Events.message.emit("Nothing files %s any more." % s.name)
	_seen["quieted"] = true


## A holding founded in a region that has already lost one starts on the plan's
## books: the region remembers what stood there (docs/VISION.md §9.6).
func _on_founded(id: int) -> void:
	var s := get_place(id)
	if s == null:
		return
	var b := book(id)
	b["settled_at"] = floorf(game.clock.minutes / SLICE) * SLICE
	var was := s.attention
	# Staging (--attention) reaches a holding founded during the run, not only one
	# the boot option stood up: a tour that builds its own place on the real keys
	# has to be able to start it somewhere other than the beginning.
	if attention_out > 0.0:
		s.attention = attention_out
	var razed := int(_memory(s).get("razed", 0))
	if razed > 0:
		s.attention = clampf(s.attention + Attention.NOTICE_FULL * float(razed), 0.0, 1.0)
	if absf(s.attention - was) > 1e-5:
		Events.attention_changed.emit(s.id, was, s.attention)


# --- the tags on the pieces ---------------------------------------------------

## A tag on every piece a live plan is coming for, and nothing on anything else.
func _sync_marks() -> void:
	if game == null or game.world == null:
		return
	var want: Dictionary = {}
	for p in plans:
		if p.over():
			continue
		var s := get_place(p.settlement_id)
		if s == null or s.realm != realm_here():
			continue
		for row: Dictionary in p.party:
			var piece := s.piece(int(row.get("target", -1)))
			if piece == null or not piece.standing():
				continue
			var key := "%d:%d" % [s.id, piece.id]
			want[key] = true
			var mark: Node3D = _marks.get(key, null)
			if mark == null or not is_instance_valid(mark):
				mark = RaidMark.create(piece.id + s.id)
				mark.call("build")
				add_child(mark)
				_marks[key] = mark
			_mark_at[key] = {"pos": piece.pos, "out": StructureKind.solid(piece.kind) + 0.55}
	for key: String in _marks.keys():
		if want.has(key):
			continue
		var node: Node3D = _marks[key]
		if is_instance_valid(node):
			node.queue_free()
		@warning_ignore("return_value_discarded")
		_marks.erase(key)
		@warning_ignore("return_value_discarded")
		_mark_at.erase(key)
	_face_marks()


## Every tag stands on the camera's side of its piece and square to it, and it is
## turned there EVERY FRAME. The camera leans when the player holds a target
## (CameraRig.yaw_now), so a tag whose yaw was fixed when it was hung goes
## edge-on at the very moment the player is reading the yard — and a warning
## nobody can read is a warning nobody was given (docs/ART.md §10).
func _face_marks() -> void:
	if _marks.is_empty() or game == null or game.world == null:
		return
	var yaw := deg_to_rad(game.camera.yaw_now() if game.camera != null else 45.0)
	var toward := Vector2(sin(yaw), cos(yaw))
	for key: String in _marks:
		var node: Node3D = _marks[key]
		var anchor: Dictionary = _mark_at.get(key, {})
		if not is_instance_valid(node) or anchor.is_empty():
			continue
		node.position = game.world.to_3d(anchor["pos"] as Vector2 + toward * float(anchor["out"]))
		node.rotation.y = yaw


# --- the frame ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if game == null or game.world == null or game.player == null or game.player.sim == null:
		return
	_sense -= delta
	if _sense <= 0.0:
		_sense = SENSE_EVERY
		_sense_holdings()
	_step_notices()
	_step_plans()
	_face_marks()
	_sweep -= delta
	if _sweep > 0.0:
		return
	_sweep = SWEEP
	sweep()


## Everything the once-a-second sweep does. Idempotent: it settles from each
## holding's own timestamp, so calling it every second, once an hour or twice in
## a row all leave the same holding.
func sweep() -> void:
	_settle_attention()
	_felt_interference()
	_stake_pulled()
	_escalate()
	_sync_marks()
	_forget_old_reads()


## A body only reads a holding once in READ_AGAIN world minutes, and the line
## saying so is worth nothing after that. It is not saved (a loaded game has new
## bodies with new ids), and left alone it grew for every machine that ever stood
## near a holding, for the whole length of a game.
func _forget_old_reads() -> void:
	if _read_at.size() < 64:
		return
	var now := game.clock.minutes
	for key: String in _read_at.keys():
		if now - float(_read_at[key]) >= READ_AGAIN:
			@warning_ignore("return_value_discarded")
			_read_at.erase(key)


## One whole pass of the plan, in the order the running game takes it. A test or
## a tour calls this when it wants the machines to have had their look NOW,
## rather than waiting a real second for the next sweep.
func pass_now() -> void:
	_sense_holdings()
	_step_notices()
	_step_plans()
	sweep()


## The stake pulled up out of the yard. It is a plan work, so the taking itself
## is a theft the region files (32_disposition does that on its own); what it
## buys is the plan losing the mark it put on the place.
func _stake_pulled() -> void:
	for s in places():
		# Prop ids restart at 0 in every realm's world (Survival.add_prop counts
		# this world's props), so the only world that can answer for a stake is
		# the one it was driven into.
		if s.realm != realm_here():
			continue
		var b := book(s.id)
		var id := int(b["stake"])
		if id < 0 or not game.world.depleted.has(id):
			continue
		b["stake"] = -1
		b["surveyed"] = false
		_raise(s, &"stopped")
		_seen["stake_pulled"] = true
		if _near(s):
			Events.message.emit("The stake is out of the ground. They will have to come and look again.")


## A crossing hands the game another world: every tag standing in the old one is
## standing in the wrong world, and every body of a live party has gone with it.
## The holdings of the realm being entered get their tags back; the rest go on,
## because a plan does not stop for the player walking down a shaft.
func realm_changed(_from: StringName, _to: StringName) -> void:
	for key: String in _marks:
		var node: Node3D = _marks[key]
		if is_instance_valid(node):
			node.queue_free()
	_marks.clear()
	_mark_at.clear()
	_read_at.clear()
	_raiders.clear()
	_carriers.clear()
	for n in notices:
		if n.carried():
			n.mob_id = -1
	_sync_marks()


# --- staging ------------------------------------------------------------------

## `--attention=F`: every holding starts F of the way to a siege, so a shot or a
## tour can begin at a state a player reaches by playing. A holding founded
## during the run gets it too (`_on_founded`). Never part of a normal start.
func _stage() -> void:
	if attention_out <= 0.0:
		return
	for s in places():
		var was := s.attention
		s.attention = attention_out
		Events.attention_changed.emit(s.id, was, s.attention)


# --- what a tour can be shown -------------------------------------------------

## Answers a tour's `await WHAT` and a frame's `with WHAT`:
##   noticed         a machine has read a holding and is walking off with it
##   carrier         one is carrying a reading right now
##   filed           a reading got home
##   stopped         one was killed or spoofed before it did
##   record          a record came off a body into the creel
##   warned          the world warned of a step; warned:STAGE for which
##   raid_coming     a warned step has not arrived yet
##   raid            a step began; raid:STAGE for which
##   raid_on         a step is under way now
##   party           a raiding party has bodies in the world
##   party_close     one of them is at the holding's own fence (PARTY_AT_GATE),
##                   which is what "at the gate" means: a frame that says so is
##                   held to it rather than to the moment they were put out
##   paid            a full store bought them off and the party turned round
##   siege_keeper    the region's keeper came with one
##   marked          a piece is wearing the plan's tag
##   stake           the plan's survey stake is standing in a yard
##   stake_pulled    it has been taken up again
##   raid_damage     a machine has put a blow into a piece
##   snatched        somebody was carried off
##   razed           a holding was left with nothing standing
##   looted          the party took what was lying in the store
##   raid_ended      a step is over; raid_ended:OUTCOME for how
##   raider_down     one of the party did not come home
##   quieted         a region's keeper fell and its network went quiet
##   attention       a holding is on the plan's books at all
##   unfiled         nothing has ever got home about any holding, and nothing is
##                   carrying one now: what running dark buys, said as a state
##                   rather than as a thing that failed to happen
##   nothing_coming  no step is warned or under way anywhere, and no holding is
##                   at a line that would start one
func tour_seen(what: String) -> bool:
	match what:
		"attention":
			for s in places():
				if s.attention > Attention.NOTHING:
					return true
			return false
		"marked":
			for key: String in _marks:
				if is_instance_valid(_marks[key]):
					return true
			return false
		"party":
			return not _raiders.is_empty()
		"party_close":
			var sim: FightSim = game.player.sim if game.player != null else null
			for id: Variant in _raiders:
				var r: Dictionary = _raiders[id]
				var s := get_place(int(r.get("settlement", -1)))
				var m := _mob(sim, int(id))
				if s == null or m == null or not m.alive or m.removed:
					continue
				if m.pos.distance_to(s.centre) <= PARTY_AT_GATE:
					return true
			return false
		"carrier":
			return not _carriers.is_empty()
		"raid_on":
			for p in plans:
				if p.on():
					return true
			return false
		"raid_coming":
			for p in plans:
				if p.coming():
					return true
			return false
		"unfiled":
			# Nothing has ever got home about any holding, and nothing is on its
			# way with one. It is the state a place that runs dark stays in, and
			# the only way a tour can prove a raid never came: by naming the
			# world the player is standing in rather than waiting for nothing.
			for s in places():
				if s.attention > Attention.NOTHING:
					return false
			return _carriers.is_empty()
		"nothing_coming":
			for p in plans:
				if not p.over():
					return false
			for s in places():
				if RaidStage.due_at(s.attention) >= 0:
					return false
			return true
	return bool(_seen.get(what, false))


# --- saving -------------------------------------------------------------------

func _save() -> Variant:
	var out_notices: Array = []
	for n in notices:
		if n.carried():
			out_notices.append(n.as_dict())
	var out_plans: Array = []
	for p in plans:
		out_plans.append(p.as_dict())
	var out_books := {}
	for id: Variant in _books:
		var b: Dictionary = _books[id]
		out_books[str(id)] = {"settled_at": SaveCodec.num(b["settled_at"]),
			"last_read": SaveCodec.num(b["last_read"]), "stake": int(b["stake"]),
			"surveyed": bool(b["surveyed"]), "felt": int(b["felt"])}
	var out_regions := {}
	for key: Variant in _regions:
		var m: Dictionary = _regions[key]
		out_regions[str(key)] = {"razed": int(m.get("razed", 0)), "lost": int(m.get("lost", 0)),
			"taken": bool(m.get("taken", false))}
	return {"notices": out_notices, "plans": out_plans, "books": out_books,
		"regions": out_regions, "next_notice": _next_notice, "next_plan": _next_plan}


func _load(v: Variant) -> void:
	var d := v as Dictionary
	if d == null:
		return
	notices.clear()
	plans.clear()
	_books.clear()
	_regions.clear()
	_carriers.clear()
	_raiders.clear()
	_read_at.clear()
	for row: Variant in d.get("notices", []):
		notices.append(Notice.from_dict(row as Dictionary))
	for row: Variant in d.get("plans", []):
		plans.append(RaidPlan.from_dict(row as Dictionary))
	var books := d.get("books", {}) as Dictionary
	for key: Variant in books:
		var b := books[key] as Dictionary
		_books[SaveCodec.to_int(key)] = {
			"settled_at": SaveCodec.to_num(b.get("settled_at", 0.0)),
			"last_read": SaveCodec.to_num(b.get("last_read", -INF), -INF),
			"stake": SaveCodec.to_int(b.get("stake", -1), -1),
			"surveyed": bool(b.get("surveyed", false)),
			"felt": SaveCodec.to_int(b.get("felt", 0)),
		}
	var regions := d.get("regions", {}) as Dictionary
	for key: Variant in regions:
		var m := regions[key] as Dictionary
		# "REALM:region": a bare number is a save from before the plan kept one
		# file per realm, and it belongs to the realm every world started in.
		var id := str(key)
		if not id.contains(":"):
			id = region_key(Realm.SURFACE, SaveCodec.to_int(key))
		_regions[id] = {"razed": SaveCodec.to_int(m.get("razed", 0)),
			"lost": SaveCodec.to_int(m.get("lost", 0)), "taken": bool(m.get("taken", false))}
	_next_notice = SaveCodec.to_int(d.get("next_notice", notices.size() + 1), notices.size() + 1)
	_next_plan = SaveCodec.to_int(d.get("next_plan", plans.size() + 1), plans.size() + 1)
