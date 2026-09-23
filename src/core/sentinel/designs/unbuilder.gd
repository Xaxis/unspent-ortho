## The Ruined Metropolis's keeper: a gantry crane that takes the city apart
## (docs/LANDSCAPES.md, "the unbuilder"; docs/VISION.md). The plan is
## stripping the city district by district for what it is made of — copper,
## steel, glass — and this is the machine that does the stripping: it straddles a
## street on four legs, and a grab on cables from its bridge comes down on
## whatever the survey marked. A cab rides the bridge. It is the tallest keeper
## in the game, about ten units, so it is read from the far end of a street as a
## frame with the sky through it and, close to, as legs.
##
## How it is beaten, three ways (§3, tactics not stats):
##   force    the winch that pays the grab out is low on the back of its
##            carriage while it sorts; once the grab is swinging it is the
##            swinging side that is open and guarded at once; at the end it
##            drops whole bales and slows as the cab runs out, with the drive
##            bare on the front sill. Three sides, in order.
##   founder  the LEFT districts are green because the ground under them is
##            hollow — the Undercroft — and a leg of this weight goes through.
##            It keeps to the swept streets; lure it out onto the grass.
##   spoof    it takes its orders off the district's own signal lamps. Stand
##            under a live LAMP wearing the signet, inside its guard, and it
##            files you as a crew and stands down.
##
## STARVE IS LEFT OUT, on purpose. A keeper is starved by robbing the works
## inside its feeding reach, and this one feeds off an entire city: the gantry,
## the bales, the conveyors and the lamps of a district are more than a player
## could ever strip, so the way would either be a promise the world never keeps
## or a rule tuned to be met, and neither is a tactic. `feeds` is still named,
## because it is what the yard puts in reach of it and what a broken depot bites
## out of (34_works), and that is a different seam from a way.




static func make() -> SentinelDef:
	var d := SentinelDef.new()
	d.id = &"unbuilder"
	d.land = &"ruined_metropolis"
	d.display_name = "the unbuilder"
	d.note = "Four legs astride a street and a grab hung from the bridge between them: a doorway with a fist in it."
	d.kind = &"sentinel.metropolis"
	# Streets are narrow: it holds less ground than the rake, and what it holds
	# is one district's streets rather than a basin.
	d.reach = 26.0
	d.stations = [&"unbuilding"]
	# What the demolition face puts in its reach: the frame over the cut, the
	# bales it sorts into, the conveyor run and the kept half's lamps.
	d.feeds = [PropKind.DEMOLITION_GANTRY, PropKind.SORTED_BALE, PropKind.CONVEYOR, PropKind.LAMP]
	d.drops = &"sentinel_unbuilder"
	d.core = &"unbuilder_core"
	d.hulk = PropKind.WRECKAGE

	# Phase one: sorting. The grab hangs still over a marked tile, then drops
	# on it, and the tell is the longest thing in the fight: the cable pays out
	# for most of a second before anything comes down. The winch that pays it is
	# on the back of the carriage, low, where a hand can reach it.
	var sorting := SentinelPhase.make(&"sorting", 1.0, &"back",
		{"swing": [880, 180, 820, 900], "reach": 2.0, "width": 1.8, "dmg": 3, "knock": 9.0, "knock_ms": 320})
	sorting.pace = 3.8
	sorting.dash = 8.0
	sorting.quick = 280
	sorting.turn = 1.3
	sorting.note = "The grab drops on a marked tile: the cable paying out is the tell, the winch behind is the part."

	# Phase two: sweeping. The grab swings on its cable across the whole street,
	# wide and guarded: a blow into the swinging side rings off the grab itself,
	# and the opening is the stand after a swing that met nobody.
	var sweeping := SentinelPhase.make(&"sweeping", 0.6, &"right",
		{"swing": [640, 170, 700, 820], "reach": 2.2, "width": 2.8, "dmg": 4, "knock": 10.0, "knock_ms": 340})
	sweeping.guarded = true
	sweeping.pace = 4.6
	sweeping.dash = 9.5
	sweeping.quick = 330
	sweeping.turn = 1.4
	sweeping.note = "Guarded: the grab swings across the street and its guard is the swinging side."

	# Phase three: dropping. It stops sorting and drops whole bales, which stamp
	# the ground where they land, and it slows as the cab runs out along the
	# bridge to do it. The drive on the front sill is the last thing open.
	var dropping := SentinelPhase.make(&"dropping", 0.3, &"front",
		{"swing": [780, 200, 780, 980], "reach": 2.0, "width": 2.4, "dmg": 5, "knock": 12.0, "knock_ms": 380})
	dropping.pace = 3.2
	dropping.dash = 6.5
	dropping.quick = 240
	dropping.turn = 1.1
	dropping.note = "It drops whole bales: the heaviest bite and the slowest, and it can be walked round."
	d.phases = [sorting, sweeping, dropping]

	var force := SentinelWay.make(SentinelWay.FORCE)
	force.says = "The winch behind, then the side it swings from, then the drive on the front sill."
	var founder := SentinelWay.make(SentinelWay.FOUNDER, 1600.0, [Ground.GRASS])
	founder.says = "The green districts are hollow underneath. Lure it off the swept streets."
	var spoof := SentinelWay.make(SentinelWay.SPOOF, 2200.0)
	spoof.beside = [PropKind.LAMP]
	spoof.says = "It takes its orders from the district's lamps. Stand under a live one wearing their signature."
	d.ways = [force, founder, spoof]
	return d
