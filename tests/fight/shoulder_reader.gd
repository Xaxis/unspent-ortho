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
## Radians a second a player turns the camera looking for what they lost.
const LOOK_TURN := 2.5

var _last_known := {}


func _init(s: FightSim) -> void:
	super(s)


func act() -> void:
	var known := _live()
	if known.is_empty() and sim.hero.move.length() < 0.1:
		sim.hero.facing = wrapf(sim.hero.facing + LOOK_TURN * FightRules.SLICE_MS * 2.0 / 1000.0, -PI, PI)
	super()


## Whether the player knows of `m` now.
func _knows(m: MobState) -> bool:
	var hero := sim.hero
	var to := m.pos - hero.pos
	var d := to.length()
	var seen := d <= SIGHT_REACH and absf(wrapf(to.angle() - hero.facing, -PI, PI)) <= SIGHT_CONE * 0.5
	var heard := d <= HEARD_BESIDE
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
	var in_cone := absf(wrapf(to.angle() - hero.facing, -PI, PI)) <= SIGHT_CONE * 0.5
	var ear := hero.kit != null and hero.kit.listen and to.length() <= EAR_REACH
	if not (in_cone or to.length() <= HEARD_BESIDE or ear):
		return false
	return super(m)
