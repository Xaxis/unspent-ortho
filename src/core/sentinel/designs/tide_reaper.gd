## The Coast's keeper: a reaper on a gantry (docs/VISION.md §3, "the Coast's
## sentinel reaps"). It stands at the machines' intake on the shore and works the
## turf in rows, and the whole shore answers to it.
##
## What it is: a portal frame — a long ruled beam on two track units, wide enough
## to walk under — with a reaping drum slung beneath it and a spoil chute over its
## back. Nothing else in the game is an arch, which is the whole of why it is one:
## at 640x360 a player names it from a hundred tiles by the gap under it.
##
## How it is beaten, three ways (§3, tactics not stats):
##   force    its drum guards the front, so a player who walks in swinging rings
##            off it. The opening is the long stand after a bite that missed, and
##            the side that is open moves as it comes apart: front, then the left
##            leg's drive, then the chute's gear at its back.
##   founder  it keeps the tide line, and it is far too heavy for the mud it works
##            beside. Lured onto the flats below the intake it goes in to the deck
##            and stays there: a charge commits to its bearing, so the land is the
##            answer and the dodge is how you spend it.
##   starve   the intake and the pump house feed it. Rob them and it stands dark
##            with the tide coming in, which is the plan's own logic and no fight
##            at all.




static func make() -> SentinelDef:
	var d := SentinelDef.new()
	d.id = &"tide_reaper"
	d.land = &"coast"
	d.display_name = "the reaper"
	d.note = "An arch on two tracks: the one silhouette on the coast with daylight through it."
	d.kind = &"sentinel.coast"
	d.reach = 26.0
	d.stations = [&"intake", &"sea_wall", &"hulk", &"turf_rows"]
	d.feeds = [PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.PIPE, PropKind.RELAY]
	d.drops = &"sentinel_tide_reaper"
	d.core = &"reaper_core"
	d.hulk = PropKind.WRECKAGE

	# Phase one: reaping. The drum is down in the row and it is the front of the
	# machine: a blow into it rings, and the row it cuts is where it will take you.
	var reaping := SentinelPhase.make(&"reaping", 1.0, &"front",
		{"swing": [820, 170, 800, 900], "reach": 1.9, "width": 2.6, "dmg": 3, "knock": 9.0, "knock_ms": 320})
	reaping.guarded = true
	reaping.pace = 4.2
	reaping.dash = 8.5
	reaping.quick = 300
	reaping.turn = 1.4
	# The tell is the longest in the game so far and the bite is SOFTER than a
	# hauler's: the first keeper a player meets has to be readable and survivable at
	# twelve health, or the lesson it teaches is "come back later".
	reaping.note = "Guarded: the turning drum throws a blow off, so the opening is the stand after a miss."

	# Phase two: the arch rears. The drum comes up out of the row and jams, and the
	# drive in its left leg is open — the side to be on has MOVED, which is the
	# lesson a sentinel teaches that no ordinary machine does.
	var raised := SentinelPhase.make(&"raised", 0.6, &"left",
		{"swing": [620, 160, 640, 760], "reach": 2.0, "width": 2.2, "dmg": 4, "knock": 10.0, "knock_ms": 340})
	raised.pace = 5.0
	raised.dash = 10.0
	raised.quick = 340
	raised.turn = 1.5
	raised.note = "The drum up and jammed; it comes faster and turns on the spot for you."

	# Phase three: stooped on one track, hauling. Its bite takes hold instead of
	# hurting: it means to put the player under the arch, and the chute's gear at
	# its back is the last thing left open.
	var stooped := SentinelPhase.make(&"stooped", 0.28, &"back",
		{"swing": [520, 170, 560, 900], "reach": 1.8, "width": 2.0, "dmg": 0, "knock": 0.0, "knock_ms": 0, "grip": 4})
	stooped.pace = 3.4
	stooped.dash = 7.0
	stooped.quick = 260
	stooped.turn = 1.2
	stooped.note = "It stops killing and starts carrying: pull free, then take the chute gear."
	d.phases = [reaping, raised, stooped]

	var force := SentinelWay.make(SentinelWay.FORCE)
	force.says = "Its working side moves as it comes apart."
	var founder := SentinelWay.make(SentinelWay.FOUNDER, 1400.0, [Ground.MUD, Ground.WATER, Ground.RIVER])
	founder.says = "It is too heavy for the tide flats it works beside."
	var starve := SentinelWay.make(SentinelWay.STARVE, 4000.0)
	starve.says = "The intake feeds it. Rob the intake."
	d.ways = [force, founder, starve]
	return d
