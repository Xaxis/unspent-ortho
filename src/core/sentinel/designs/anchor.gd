## The Mesas' keeper: the anchor (docs/LANDSCAPES.md §6, docs/VISION.md §3).
## The plan carries its haul across canyons no road can cross, on cables strung
## mesa top to mesa top, and the cables hang off bolts driven into the scarps.
## This is the machine that drives them and keeps them driven: a four-limbed
## climber with hooked grapnel feet and a long counterweight tail, at home on a
## wall and not on the ground.
##
## It CLIMBS. Its roster row steps four levels in one move (`climbs`, read by
## FightSim.climber as a walker's ride with a longer stride), so a scarp that is
## a wall to a person is a floor to it — until its last phase takes the grapnels
## off it and it is a walker like anything else.
##
## How it is beaten, three ways (§3, tactics not stats):
##   force    the bolt driver on its back while it clings and pounds; the right
##            flank while it rides the cable in long dashes, guarded by the tail
##            that swings across it; then the front, when it is off the wall and
##            lame. Three sides, in order.
##   founder  its grapnel feet are hooks. They find a crack in rock and nothing
##            at all in the canyon's sand: lure it down off the benches into a
##            wash and it wallows.
##   starve   the stations feed it: the pylons that hold the spans. Rob a
##            station and it goes dead on the wall.
##   SPOOF is left out on purpose. It keeps to the bolts it drove itself and
##            takes no orders over any relay: a signature it does not read is not
##            one it can be fooled by, and that is the whole character of a
##            machine left alone on a wall with its own work.




static func make() -> SentinelDef:
	var d := SentinelDef.new()
	d.id = &"anchor"
	d.land = &"mesas"
	d.display_name = "the anchor"
	d.note = "A spider on a wall with a pendulum for a tail: the one body in the game that stands on a cliff."
	d.kind = &"sentinel.mesas"
	# A canyon is wide and the stations are mesa tops apart: it holds more ground
	# than a street keeper and about what the plumb does.
	d.reach = 30.0
	# The anchor station (GenWorks will record one as `ropeway`). Until the works
	# row lays one, no region holds it and the keeper stands at its region's
	# heart, which `Sentinels.lair` already does for a station nobody laid.
	d.stations = [&"ropeway"]
	# What the ropeway puts in its reach: the pylons at each station. The spec
	# names the CABLE_SPAN as well, and it is left out because it does not
	# exist: a prop that spans two points is shared system 7 (docs/LANDSCAPES.md).
	# Until the works row lays a ropeway, no pylon stands and the larder is empty,
	# which closes the way honestly (the plumb's case).
	#
	# The spec's DRILL_RIG is left out on MEASUREMENT, the plumb's rule: the
	# island's own rigs are not the ropeway's, and on seed 1 they came to TWO
	# inside this keeper's larder (region 14) -- a starve way won by one theft
	# and an accident, which tests/sentinel/test_world.gd refuses
	# (STARVE_LEAST). When the works row lays a ropeway with its own bolt rigs,
	# those are the ones to name.
	d.feeds = [PropKind.SPAN_PYLON]
	d.drops = &"sentinel_anchor"
	d.core = &"anchor_core"
	d.hulk = PropKind.WRECKAGE

	# Phase one: bolting. It clings above you and pounds, and it comes DOWN on
	# you: the bite is a drop off a terrace, the longest tell it has, the tail
	# swinging up behind as the counterweight before it lets go. The bolt driver
	# on its back is what it pounds with, and it is open the whole time.
	var bolting := SentinelPhase.make(&"bolting", 1.0, &"back",
		{"swing": [860, 170, 820, 920], "reach": 2.0, "width": 2.2, "dmg": 4, "knock": 10.0, "knock_ms": 340})
	bolting.pace = 3.4
	bolting.dash = 7.0
	bolting.quick = 260
	bolting.turn = 1.3
	bolting.climbs = 4
	bolting.tell = &"ring"
	bolting.note = "It comes down on you from the wall: the ring is where it lands, the driver on its back is the part."

	# Phase two: swinging. It rides the cable in long lateral dashes, and the
	# tail swings across its right flank as it goes, so a blow into that side
	# rings off the counterweight until a dash has overshot and it is hauling
	# itself back.
	var swinging := SentinelPhase.make(&"swinging", 0.6, &"right",
		{"swing": [620, 160, 740, 840], "reach": 2.3, "width": 2.8, "dmg": 4, "knock": 11.0, "knock_ms": 360})
	swinging.guarded = true
	swinging.pace = 4.6
	swinging.dash = 10.5
	swinging.quick = 340
	swinging.turn = 1.4
	swinging.climbs = 4
	swinging.note = "Guarded: the tail sweeps across its right while it swings; the opening is the haul back after a dash."

	# Phase three: grounded. Off the wall and lame, a grapnel dragging: it
	# cannot climb any more and it cannot turn fast, and the drive in its chest
	# is the last thing open.
	var grounded := SentinelPhase.make(&"grounded", 0.3, &"front",
		{"swing": [760, 190, 900, 1040], "reach": 1.8, "width": 2.0, "dmg": 5, "knock": 12.0, "knock_ms": 380})
	grounded.pace = 2.8
	grounded.dash = 6.0
	grounded.quick = 230
	grounded.turn = 1.1
	grounded.climbs = 1
	grounded.note = "Lame and on the ground: it cannot climb, it drags a foot, and its front is bare."
	d.phases = [bolting, swinging, grounded]

	var force := SentinelWay.make(SentinelWay.FORCE)
	force.says = "The driver on its back, then the flank the tail guards, then its chest once it is down off the wall."
	var founder := SentinelWay.make(SentinelWay.FOUNDER, 1500.0, [Ground.SAND])
	founder.says = "Its feet are hooks. They find nothing in the wash: bring it down into the sand."
	var starve := SentinelWay.make(SentinelWay.STARVE, 4000.0)
	starve.says = "The stations feed it. Rob the pylons that hold the spans and it goes dead on the wall."
	d.ways = [force, founder, starve]
	return d
