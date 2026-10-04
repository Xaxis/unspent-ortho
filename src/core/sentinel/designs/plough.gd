## The Snowfield's keeper: the plough (docs/LANDSCAPES.md, docs/VISION.md). The
## plan's power line runs over the snowfield on pylons, and the linemen keep it;
## the plough keeps its road open. A low, heavy tracked hull under a swept V-share
## a lane wide, an engine cowl on its back steaming in the cold.
##
## Its ground rule is the fight (FightSim furrows). Where it has been it leaves a
## furrow, packed ice it runs on at full speed; off its furrows, in the drifts, it
## wallows -- half its pace, no run -- and a run carried off its lane into the
## snow bogs and stalls it. So the fight is played on its lanes: a player who
## stands in the snow beside them makes it plough its way to them, slow and open,
## and one who stands on them is run down. The opening comes from the ground, not
## from slowing a charge one at a time (docs/GEAR.md §12).
##
## How it is beaten, three ways (§3, tactics not stats):
##   force    the engine grille at its back while it wallows; then its left flank
##            once it banks the snow it clears against its right; then the drive
##            under the share, jammed with ice, at its front.
##   founder  its weight breaks the pools' ice: bring it along a furrow onto a
##            frozen pool and hold it there.
##   starve   the line feeds it. Rob the relay pylons inside its reach and it goes
##            dead in its lane.
##   SPOOF is left out on purpose: it keeps the linemen's road and takes no reading
##            from anything off the line.


static func make() -> SentinelDef:
	var d := SentinelDef.new()
	d.id = &"plough"
	d.land = &"snowfield"
	d.display_name = "the plough"
	d.note = "A wedge on tracks under a swept share, steaming: the one keeper that is wide and not tall."
	d.kind = &"sentinel.snowfield"
	d.reach = 30.0
	# The pylon run (GenWorks will record a `line`). Until the works row lays one,
	# no region holds it and the keeper stands at its region's heart.
	d.stations = [&"line"]
	d.feeds = [PropKind.PYLON]
	d.come_round = "It slews on its tracks and the share's wing sweeps the side you keep to."
	d.drops = &"sentinel_plough"
	d.core = &"plough_core"
	d.hulk = PropKind.WRECKAGE

	# Phase one: clearing. It runs its lanes and turns at the end of each. The run
	# is the bite; the share guards its front; off a lane it wallows, and the
	# grille on its back is open while it grinds round in the snow.
	# Each phase's bite is told about 100 ms past the floor a person needs
	# (FightRules.readable_windup): a slewing hull is slow to set its share, and a
	# person who reads it a beat late still clears the lane.
	var clearing := SentinelPhase.make(&"clearing", 1.0, &"back",
		{"swing": [888, 180, 900, 1000], "reach": 1.8, "width": 2.8, "dmg": 4, "knock": 12.0, "knock_ms": 340})
	clearing.pace = 3.6
	clearing.dash = 10.0
	clearing.quick = 330
	clearing.turn = 1.2
	clearing.note = "It runs its lanes. Stand in the snow beside them and make it come to you through the drifts."

	# Phase two: banking. It throws what it clears into banks against its right,
	# and walls its engine in with them: the side open is the left, guarded until a
	# run has gone past and the share is still up.
	var banking := SentinelPhase.make(&"banking", 0.6, &"left",
		{"swing": [918, 170, 760, 880], "reach": 2.0, "width": 3.0, "dmg": 4, "knock": 12.0, "knock_ms": 340})
	banking.guarded = true
	banking.pace = 4.0
	banking.dash = 10.5
	banking.quick = 340
	banking.turn = 1.2
	banking.note = "Guarded: it walls itself in with what it clears; the opening is the raised share after a run."

	# Phase three: stalled. The share is packed with ice: it can barely run, it
	# drags, and the drive under the share is bare.
	var stalled := SentinelPhase.make(&"stalled", 0.3, &"front",
		{"swing": [900, 200, 900, 1100], "reach": 1.6, "width": 2.4, "dmg": 5, "knock": 13.0, "knock_ms": 360})
	stalled.pace = 3.0
	stalled.dash = 6.0
	stalled.quick = 260
	stalled.turn = 1.1
	stalled.note = "The share is packed solid: it cannot cut, it hardly runs, and its front is bare."
	d.phases = [clearing, banking, stalled]

	var force := SentinelWay.make(SentinelWay.FORCE)
	var founder := SentinelWay.make(SentinelWay.FOUNDER, 1500.0, [Ground.ICE])
	var starve := SentinelWay.make(SentinelWay.STARVE, 4000.0)
	d.ways = [force, founder, starve]
	return d
