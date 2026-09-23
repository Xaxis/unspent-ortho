## The Crags' keeper: a plumb on a tripod (docs/LANDSCAPES.md, docs/VISION.md
## §3). The plan surveyed this land and its instruments returned nothing it could
## file, so it keeps re-surveying: exact, patient and failing. That is the one
## machine behaviour in the crags, and it is not hostility.
##
## What it is: a very tall tripod, about seven units, three thin FOUND legs under
## a head with no lamp in it, and a plumb-weight hanging on a chain from the head
## down to a person's height. The weight swings and marks. The silhouette is a
## triangle over a pendulum, which shares nothing with the Coast's arch or the
## flats' delta, and it is the one ruled thing on a landscape whose every other
## line is soft.
##
## How it is beaten, three ways (§3, tactics not stats):
##   force    the register on its back leg while it sights; the leg it has driven
##            into the ground while it stakes, which is its guard; the winch on
##            its left flank while it plumbs, open in the long pause while it
##            hauls the weight back up. Three sides, in order.
##   founder  the valleys hold peat and the tripod's point feet go through it.
##            The fog hides where the peat is, which is the land doing the work.
##   starve   the survey's masts and core racks feed it. Robbed, it stands dark.
##   SPOOF is left out on purpose. Its orders do not come by relay: it lost its
##            line in the fog long ago, so there is no signature it could read the
##            player as. That keeps "the land the explanation does not reach"
##            true in the mechanics and not only in the words.




static func make() -> SentinelDef:
	var d := SentinelDef.new()
	d.id = &"plumb"
	d.land = &"the_crags"
	d.display_name = "the plumb"
	d.note = "A triangle over a pendulum: the one ruled thing in the fog."
	d.kind = &"sentinel.crags"
	d.reach = 28.0
	# The survey bench is what it keeps (GenWorks records one as `bench`). Until
	# the works row lays one, no region holds it and the keeper stands at its
	# region's heart, which `Sentinels.lair` already does for a station nobody laid.
	d.stations = [&"bench"]
	# What feeds it is the survey bench's own furniture: the sighting masts and
	# the racks of cores. The spec lists SURVEY posts as well, and they are left
	# out on purpose: the posts near a region's heart are the island survey's,
	# not the bench's, and measured at 512 on seeds 1, 4 and 42 they came to TWO
	# inside the keeper's larder every time -- a starve way open on two works is
	# won by one theft and an accident, which tests/sentinel/test_world.gd
	# refuses (STARVE_LEAST). With the masts and racks alone the larder is empty
	# until the bench is laid, which closes the way honestly, and four masts plus
	# a row of racks once it is.
	d.feeds = [PropKind.THEODOLITE_MAST, PropKind.CORE_RACK]
	d.drops = &"sentinel_plumb"
	d.core = &"plumb_core"
	d.hulk = PropKind.WRECKAGE

	# Phase one: sighting. Slow. The weight swings as a sweep, wide and with the
	# longest tell of any keeper, and the tell before the tell is the head turning
	# to sight you. The register that counts its bores is on the back leg, open.
	var sighting := SentinelPhase.make(&"sighting", 1.0, &"back",
		{"swing": [900, 180, 820, 900], "reach": 2.2, "width": 3.0, "dmg": 3, "knock": 9.0, "knock_ms": 320})
	sighting.pace = 3.6
	sighting.dash = 7.5
	sighting.quick = 260
	sighting.turn = 1.2
	sighting.note = "The weight comes round in a wide slow arc: walk out of it, then in behind."

	# Phase two: staking. It drives a leg into the ground as a stamp, and the
	# guard is the leg that is planted: a blow into the front of it rings off the
	# planted leg until a stamp has missed and it is heaving the foot back out.
	var staking := SentinelPhase.make(&"staking", 0.6, &"front",
		{"swing": [640, 150, 720, 820], "reach": 1.8, "width": 1.4, "dmg": 4, "knock": 10.0, "knock_ms": 340})
	staking.guarded = true
	staking.pace = 4.2
	staking.dash = 8.5
	staking.quick = 300
	staking.turn = 1.4
	staking.note = "Guarded: the planted leg throws a blow off until a stamp has gone into empty ground."

	# Phase three: plumbing. It drops the weight straight down in a ring and then
	# has to winch it back up, and the winch pause is its opening.
	#
	# The spec gives this phase no working part ("none: the weight"). The spine
	# refuses that -- `Sentinels.problems` fails a phase with no side, because a
	# keeper with no side to find is a keeper beaten by trading hits -- and the
	# opening the spec describes IS a side: the winch that hauls the weight is on
	# its left flank, and that is what stands open while it pays the chain back
	# in. So the part is `left`, and the phase is what the spec meant.
	var plumbing := SentinelPhase.make(&"plumbing", 0.3, &"left",
		{"swing": [780, 170, 960, 1100], "reach": 1.6, "width": 2.4, "dmg": 5, "knock": 12.0, "knock_ms": 360})
	plumbing.pace = 3.0
	plumbing.dash = 6.5
	plumbing.quick = 240
	plumbing.turn = 1.1
	plumbing.note = "The weight comes straight down; while it winds back up the winch on its left is bare."
	d.phases = [sighting, staking, plumbing]

	var force := SentinelWay.make(SentinelWay.FORCE)
	force.says = "The register behind, then the planted leg, then the winch on its flank."
	var founder := SentinelWay.make(SentinelWay.FOUNDER, 1500.0, [Ground.PEAT])
	founder.says = "Its feet are points, and the valleys are peat."
	var starve := SentinelWay.make(SentinelWay.STARVE, 4000.0)
	starve.says = "The survey feeds it. Strip the masts and turn out the racks."
	d.ways = [force, founder, starve]
	return d
