## The Drowned City's keeper: a barge that walks (docs/LANDSCAPES.md §5, "the
## lockkeeper"; docs/VISION.md §3). The machines still run the port: ferries
## keep a timetable along the canals and one basin at a time is pumped dry and
## stripped behind a lock. This is the machine that keeps the locks: a long
## barge hull on four tall stilt legs, wading the canals with the water round
## its knees, and a lock-gate blade hung under its belly that it drops across a
## canal to close it. The silhouette is a boat walking, which nothing else in
## the game is.
##
## It walks the deep (`crosses: &"swim"` on its roster row). Every other keeper
## stops at the waterline, and in a landscape whose streets are water that
## would make the canals the one place nothing could follow; here the canals
## are where it LIVES.
##
## How it is beaten, three ways (§3, tactics not stats):
##   force    the ballast pump on the back of its hull while it wades; the
##            blade's winch on the bow once it gates, guarded by the blade
##            itself; its left flank once it floods, when it has opened its
##            ballast and stands high on bared legs. Three sides, in order.
##   starve   it keeps the locks' timetable, and what feeds it is the lock's own
##            furniture: the gate leaves and the pump house that dries the
##            basin (`feeds` says why the gauges and the pipe run are not).
##            Break the lock and it has no timetable to keep.
##   spoof    it reads a FERRY's call. Ride a raft into its lane inside its
##            guard with the signet worn and it files the raft as one of its
##            own boats and stands aside for it. The signet alone, on foot, is a
##            person with a machine's signature standing in a canal, and that it
##            does not read as anything it keeps (SentinelWay.aboard).
##
## FOUNDER IS LEFT OUT, on purpose. A keeper founders where the ground will not
## carry a machine of its weight, and this one was built to stand in water: its
## stilts go down through the silt to whatever is under it, which is the whole
## reason it has them. There is no ground in a drowned city that refuses a
## machine that already stands on the bottom of the sea, so a founder way here
## would be a rule with nothing in the land behind it.




static func make() -> SentinelDef:
	var d := SentinelDef.new()
	d.id = &"lockkeeper"
	d.land = &"drowned_city"
	d.display_name = "the lockkeeper"
	d.note = "A barge hull on four stilts and a gate blade under its belly: a boat walking the canals."
	d.kind = &"sentinel.drowned"
	# The canals of one quarter, not a basin: the same reach the unbuilder holds
	# over a district's streets, because a canal is a street with water in it.
	d.reach = 26.0
	# The lock the plan keeps across a canal (GenWorks records one as `lock` when
	# the works row lays it). Until then no region holds one and the keeper
	# stands at its region's heart, which `Sentinels.lair` already does for a
	# station nobody laid.
	d.stations = [&"lock"]
	# What the lock puts in its reach: its gate leaves and the pump house that
	# dries the basin (docs/LANDSCAPES.md §5).
	# The spec lists the TIDE GAUGES and the PIPE run as well, and they are left
	# out on purpose, the plumb's reason: gauges and pipes near a region's heart
	# are the coast's scatter and the island's works, not the lock's, and
	# measured at 512 they stood ONE (seed 1) and THREE (seed 42) inside the
	# keeper's larder -- a starve way open on so few is won by one theft and an
	# accident, which tests/sentinel/test_world.gd refuses (STARVE_LEAST). With
	# the lock's own furniture alone the larder is empty until the works row lays
	# a lock, which closes the way honestly, and full once it does.
	d.feeds = [PropKind.LOCK_GATE, PropKind.PUMP_HOUSE]
	d.drops = &"sentinel_lockkeeper"
	d.core = &"lockkeeper_core"
	d.hulk = PropKind.WRECKAGE

	# Phase one: wading. It stalks the canal slowly, and the blow is a stilt
	# lifted and stamped down in front of it: the tell is a whole leg coming up
	# out of the water, the longest thing a body can see coming. The ballast
	# pump is on the back of the hull, low, where a hand reaches from the bank.
	var wading := SentinelPhase.make(&"wading", 1.0, &"back",
		{"swing": [840, 170, 800, 900], "reach": 2.0, "width": 2.0, "dmg": 3, "knock": 8.0, "knock_ms": 300})
	wading.pace = 3.2
	wading.dash = 7.0
	wading.quick = 260
	wading.turn = 1.1
	wading.note = "A stilt stamps where it steps: the leg coming up out of the water is the tell, the pump behind is the part."

	# Phase two: gating. It drops the blade across the canal in front of it: a
	# wall of plate that a raft cannot pass, and the blow IS the drop. The winch
	# that hoists the blade is on the bow and the blade guards it: a blow into
	# the front rings off the gate, and the opening is the stand while it winds
	# the blade back up.
	var gating := SentinelPhase.make(&"gating", 0.6, &"front",
		{"swing": [760, 200, 820, 940], "reach": 2.2, "width": 3.2, "dmg": 4, "knock": 10.0, "knock_ms": 340})
	gating.guarded = true
	gating.pace = 3.6
	gating.dash = 7.5
	gating.quick = 280
	gating.turn = 1.2
	gating.note = "Guarded: the blade drops across the canal and the blade is the guard over the winch."

	# Phase three: flooding. It opens its ballast and stands up high on bared
	# legs, and what comes out of the hull is a wave: a wide shove that throws a
	# body in the water a long way. The left flank, where the sea-cocks are, is
	# the last thing open.
	var flooding := SentinelPhase.make(&"flooding", 0.3, &"left",
		{"swing": [700, 220, 760, 1000], "reach": 2.4, "width": 3.6, "dmg": 3, "knock": 14.0, "knock_ms": 420})
	flooding.pace = 4.2
	flooding.dash = 8.5
	flooding.quick = 300
	flooding.turn = 1.4
	flooding.note = "It opens its ballast: a wave that throws a body in the water, and its legs are bare."
	d.phases = [wading, gating, flooding]

	var force := SentinelWay.make(SentinelWay.FORCE)
	force.says = "The pump on its stern, then the winch behind the blade, then the sea-cocks on its left once it floods."
	var starve := SentinelWay.make(SentinelWay.STARVE, 4000.0)
	starve.says = "It keeps the locks' timetable. Break the lock's pump and its gates and it has nothing to keep."
	var spoof := SentinelWay.make(SentinelWay.SPOOF, 2500.0)
	spoof.aboard = &"raft"
	spoof.says = "It reads a ferry's call. Ride a raft into its lane wearing their signature and it stands aside."
	d.ways = [force, starve, spoof]
	return d
