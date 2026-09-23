## The Glass Desert's keeper: the anvil (docs/LANDSCAPES.md §3, docs/VISION.md
## §3: "fulgurite cores from the glass desert's strike fields"). The plan draws
## lightning down on purpose here — ruled fields of rods call the dry storms'
## strikes into the sand and the fused tubes are harvested — and the anvil is
## what the strikes are called THROUGH. The glassing was one strike; the fields
## are the same act, repeated small; and this is the machine that repeats it.
##
## What it is: a tall three-legged mast, about eight units, with a copper crown
## of rods at the top and a heavy shielded core slung low between the legs. The
## legs end in wide skates, not feet, because it was built to glide across the
## plates. Silhouette: a candelabrum on skates. It shares nothing with the
## Coast's arch, the flats' delta, the crags' tripod-over-a-pendulum (that one is
## thin and headless; this one is crowned and carries its weight at the bottom).
##
## How it is beaten, three ways (§3, tactics not stats):
##   force    the drive at the back of its core while it skates; the core's own
##            face while it stands and calls, which the charge shield guards
##            until a strike has come down on nothing; the burnt leg on its left
##            once the crown is spent. Three sides, in order.
##   founder  skates built for glass bog down in drift sand. Lure it off the
##            plates: a charge commits to its bearing, so the sand is the answer
##            and the dodge is how you spend it.
##   starve   the field's rods feed it. Break them and the crown has nothing to
##            call through.
##   SPOOF is left out. Its orders do not come by relay: it answers the SKY, and
##            a storm cannot be worn. A signature the flats' rake would file the
##            player under means nothing to a machine that only listens for
##            thunder, so the way would be a rule with nothing behind it.
##
## The calling phase's strike is a real bite, landed by FightSim off the phase's
## own row like any other: a long telegraph, then a ring two tiles across in
## front of it. The pale ring on the sand is `SentinelPhase.tell`, a picture
## 44_sentinels draws where that bite's box will be tested, so the sand and the
## rule agree by construction.




static func make() -> SentinelDef:
	var d := SentinelDef.new()
	d.id = &"anvil"
	d.land = &"glass_desert"
	d.display_name = "the anvil"
	d.note = "A candelabrum on skates: a mast, a copper crown, and its weight carried low."
	d.kind = &"sentinel.glass"
	d.reach = 30.0
	# The strike field is what it keeps (docs/LANDSCAPES.md §3 PLAN records it as
	# `strike_field`). Until the works row lays one, no region holds it and the
	# keeper stands at its region's heart, which `Sentinels.lair` already does for
	# a station nobody laid.
	d.stations = [&"strike_field"]
	# THE RODS ONLY. docs/LANDSCAPES.md §3 names the belt and the corner posts
	# too, and that was measured against the world before it was believed: with
	# CONVEYOR and SURVEY on this list the seed-1 keeper at 512 fed on TWO stray
	# works at its region's heart, which `tests/sentinel/test_world.gd` refuses
	# as "one theft wins it" (STARVE_LEAST is four). The spec's own sentence is
	# "STARVE on its rods", so the larder is the field's rods and nothing else:
	# none until the strike field is laid (phase B), which closes the way
	# honestly (`SentinelWay.progress`: a keeper the plan never fed cannot be
	# starved), and twelve the moment it is.
	d.feeds = [PropKind.STRIKE_ROD]
	d.drops = &"sentinel_anvil"
	d.core = &"anvil_core"
	d.hulk = PropKind.WRECKAGE

	# Phase one: skating. Fast glides across the glass and a poor turn — the
	# whole point of a machine on skates. Its bite is a skate's edge swung through
	# where you were as it passes, and the drive that pushes it is at its back.
	var skating := SentinelPhase.make(&"skating", 1.0, &"back",
		{"swing": [560, 150, 640, 760], "reach": 1.8, "width": 1.8, "dmg": 3, "knock": 9.0, "knock_ms": 320})
	skating.pace = 6.0
	skating.dash = 12.0
	skating.quick = 300
	# Under every other keeper's: it goes where it is pointed and comes round
	# slowly, so the side it keeps is reached by not being where it is going.
	skating.turn = 1.0
	skating.note = "Fast in a line, slow to come round: its drive is behind, and the line is the tell."

	# Phase two: calling. It plants itself, the crown glows cold white, and after
	# a telegraph longer than anything else in the game a strike comes down in a
	# ring two tiles across in front of it. The charge shield over the core's face
	# throws a blow off until a strike has come down on nothing.
	var calling := SentinelPhase.make(&"calling", 0.6, &"front",
		{"swing": [980, 200, 900, 1100], "reach": 2.4, "width": 4.0, "dmg": 5, "knock": 12.0, "knock_ms": 380})
	calling.guarded = true
	calling.tell = &"ring"
	# Planted: it shuffles on its skates and never glides. The founder way is
	# still open — a planted keeper that is lured is one that has to move.
	calling.pace = 1.6
	calling.dash = 3.0
	calling.quick = 200
	calling.turn = 1.3
	calling.note = "Guarded: the shield is over its face until a strike lands on sand. Stand off the pale ring."

	# Phase three: grounded. The crown is spent and it drags a burnt leg. Slow,
	# heavy, and it can be walked round; the burnt leg is on its left and bare.
	var grounded := SentinelPhase.make(&"grounded", 0.3, &"left",
		{"swing": [700, 180, 700, 900], "reach": 1.9, "width": 2.0, "dmg": 4, "knock": 10.0, "knock_ms": 340})
	grounded.pace = 2.8
	grounded.dash = 5.0
	grounded.quick = 240
	grounded.turn = 0.8
	grounded.note = "Dragging a leg: the slowest of its three, and the burnt leg is the side to be on."
	d.phases = [skating, calling, grounded]

	var force := SentinelWay.make(SentinelWay.FORCE)
	force.says = "Behind while it skates, its face once a strike has missed, then the burnt leg."
	var founder := SentinelWay.make(SentinelWay.FOUNDER, 1400.0, [Ground.SAND])
	founder.says = "Its skates were made for glass. Lead it into the sand."
	var starve := SentinelWay.make(SentinelWay.STARVE, 4000.0)
	starve.says = "The rods feed it. Break the field and the crown calls nothing."
	d.ways = [force, founder, starve]
	return d
