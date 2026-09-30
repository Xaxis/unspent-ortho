extends "res://tests/fight/crowd_reader.gd"
## The crowd reader as a player over the shoulder knows the fight: not the
## whole field, as from above, but what is in the eye's cone, what is heard,
## and what was seen a moment ago.
##
##   seen      a body inside SIGHT_CONE of the facing, within SIGHT_REACH;
##   heard     a body within HEARD_BESIDE (its feet, its engine), or, with the
##             listener's ear fitted (FightKit.listen), any body telling a blow
##             within EAR_REACH;
##   recalled  a body seen or heard in the last RECALL_MS: a short decay, not a
##             map.
##
## ITS KNOWN LIE: a recalled body is read where it truly is, not where it was
## last seen. The readers read MobState directly, and a proxy at the last-seen
## spot is a change to all of them; a second of drift is inside what a player's
## memory gets wrong, but a body that turns hard in that second is followed
## better than a player would follow it.
##
## Everything the crowd reader decides -- which tell to answer, who flanks, who
## is open, who is nearest -- it decides over these alone. With nothing known it
## looks round: the facing turns LOOK_TURN a second until something is.

const SIGHT_CONE := deg_to_rad(120.0)
const SIGHT_REACH := 22.0
const HEARD_BESIDE := 2.5
const EAR_REACH := 20.0
const RECALL_MS := 1000.0
## With `scan` it presses the scan whenever it is ready (AbilityScan: SECONDS
## on, its cooldown off, doubled by the plumb); while it stands, every machine
## in its reach is known. With the plumb its marks say where each will tell,
## and a tell met where it was marked is answered PLUMB_REACT_MS after it
## starts instead of react_ms.
var scan := false
## Played from above (GameDriver, 98_tour `drive` set it every step): the view
## shows the whole field round the body, so what is on it is seen whichever way
## the body faces. The cone is the shoulder view's. Walking round a keeper to
## its burnt side, back turned, the cone missed its tell and every bite landed
## (the anvil on seed 7: five downs, not fallen; one try locked).
var from_above := false
const PLUMB_REACT_MS := 80.0
var _scan_until := -INF
var _scan_ready := 0.0
## Radians a second a player turns the camera looking for what they lost.
const LOOK_TURN := 2.5
## With the veil fitted (FightKit.veil) it lets the veil fall when a body that
## works by sight from range -- a dart, a thrower -- is known, within VEIL_AT
## tiles and within VEIL_ARC of the facing, and the veil is ready: its cooldown
## and its charges, as AbilityVeil and the book keep them. With `veil_any` it
## lets it fall on any body so, to show what it does to those it is not for.
const VEIL_AT := 6.0
const VEIL_ARC := deg_to_rad(50.0)
var _veil_ready := 0.0
var veils_let := 0
var veil_any := false

var _last_known := {}


func _init(s: FightSim) -> void:
	super(s)


func act() -> void:
	var hero := sim.hero
	if scan and sim.now >= _scan_ready:
		_scan_until = sim.now + AbilityScan.SECONDS * 1000.0
		_scan_ready = sim.now + AbilityScan.cooldown_of(hero.kit) * 1000.0
	var plumbed := _scanning() and hero.kit != null and hero.kit.plumb
	react_ms = PLUMB_REACT_MS if plumbed else 220.0
	var known := _live()
	if hero.kit != null and hero.kit.veil and sim.now >= _veil_ready:
		_maybe_veil(known)
	if known.is_empty() and sim.hero.move.length() < 0.1:
		sim.hero.facing = wrapf(sim.hero.facing + LOOK_TURN * FightRules.SLICE_MS * 2.0 / 1000.0, -PI, PI)
	super()


func _maybe_veil(known: Array[MobState]) -> void:
	var hero := sim.hero
	var inv := hero.inventory
	if inv == null or inv.count(FightRules.CHARGE) < AbilityVeil.CHARGES:
		return
	for m in known:
		if not veil_any and not (m.approach == &"dart" or m.approach == &"throw"):
			continue
		var to := m.pos - hero.pos
		if to.length() > VEIL_AT or absf(wrapf(to.angle() - hero.facing, -PI, PI)) > VEIL_ARC:
			continue
		sim.veil(to)
		inv.remove(FightRules.CHARGE, AbilityVeil.CHARGES)
		_veil_ready = sim.now + AbilityVeil.COOLDOWN * 1000.0
		veils_let += 1
		return


func _scanning() -> bool:
	return sim.now < _scan_until


## Whether the player knows of `m` now.
func _knows(m: MobState) -> bool:
	var hero := sim.hero
	var to := m.pos - hero.pos
	var d := to.length()
	var seen := d <= SIGHT_REACH and (from_above or absf(wrapf(to.angle() - hero.facing, -PI, PI)) <= SIGHT_CONE * 0.5)
	var heard := d <= HEARD_BESIDE or (_scanning() and m.machine and d <= AbilityScan.reach_of(hero.kit))
	if not heard and hero.kit != null and hero.kit.listen and d <= EAR_REACH:
		heard = m.blow != null and m.blow_phase(sim.now) == &"windup"
	if seen or heard:
		_last_known[m.id] = sim.now
		return true
	return sim.now - float(_last_known.get(m.id, -INF)) <= RECALL_MS


func _live() -> Array[MobState]:
	var out: Array[MobState] = []
	for m in super():
		if _knows(m):
			out.append(m)
	return out


func _nearest() -> MobState:
	var best: MobState = null
	var bd := INF
	for m in _live():
		var d := m.pos.distance_to(sim.hero.pos)
		if d < bd:
			bd = d
			best = m
	return best


## A tell is answered only on a body the player knows of, and only if the tell
## itself is seen or heard: in the cone, beside them, or with the ear.
func _tell_to_answer(m: MobState) -> bool:
	var hero := sim.hero
	var to := m.pos - hero.pos
	var in_cone := from_above or absf(wrapf(to.angle() - hero.facing, -PI, PI)) <= SIGHT_CONE * 0.5
	var ear := hero.kit != null and hero.kit.listen and to.length() <= EAR_REACH
	# A bite begun out of sight in a crowd is cued (FightSim.begin_bite): known by
	# the cue, turned to, and answered at a cost (Reader.human's cue terms).
	var cued := m.blow != null and m.cued_at == m.blow_at
	if not (in_cone or to.length() <= HEARD_BESIDE or ear or cued):
		return false
	_by_cue = cued and not in_cone
	var answered := super(m)
	_by_cue = false
	return answered
