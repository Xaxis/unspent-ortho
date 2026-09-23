## The Frost Sea's keeper: the listener (docs/VISION.md, "its keeper listens
## through the ice"; docs/LANDSCAPES.md). The plan is mapping the sea floor
## by sound through the ice sheet, and this is the thing doing the listening: it
## stands out on the soundings line among the rigs and drives its spears into the
## ice to hear what is under it.
##
## What it is: a wide, low disc body on six splayed ski-feet, carrying a crown of
## long hydrophone spears it drives into the ice. It reads as a spider with
## needles held upright, and nothing else in the game is that shape: the Coast's
## keeper is an arch and the Flats' a delta on stilts, so this one is a DISC on
## the flattest ground there is, with every vertical it owns bunched into the
## crown.
##
## How it is beaten, three ways (§3, tactics not stats):
##   force    while it listens its spears are down, driven into the ice all round
##            it, and a blow into that fence rings off: the opening is the stand
##            after a spear-drive that missed. As it comes apart the side moves:
##            the receiver at its back, then the saw gear on its left flank, then
##            its bare face as it charges.
##   founder  it is far too heavy for the leads. Lured across black water — a
##            lead the sea opened, or the ring it cut itself — it goes through
##            and the sea has it. A charge commits to its bearing, so the lead is
##            the answer and the dodge is how you spend it.
##   spoof    its orders come as pings off the soundings line. Stand on a sounding
##            hole wearing a signature it reads as a rig's and it files you as one
##            and stands down: beaten, never killed, still out on the ice.
##
##   STARVE is left out on purpose. Its rigs are strung out along a soundings
##   line across a sea too wide to rob in a reasonable walk, and a way that is
##   open only after an afternoon of walking is not a way a player sees.
##
## Senses live on the ROSTER ROW, not on a phase: `SentinelPhase.row_patch` writes
## part, guard, bite and speeds and nothing else, so "hears high, sees low" is
## said once on `sentinel.frost` and holds through every phase. It is right for
## all three — a listener never stops being a listener — and it is why crouching
## matters against this keeper and nowhere near as much against the other two.




static func make() -> SentinelDef:
	var d := SentinelDef.new()
	d.id = &"listener"
	d.land = &"frost_sea"
	d.display_name = "the listener"
	d.note = "A low disc on six ski-feet under a crown of spears: a spider holding its needles up."
	d.kind = &"sentinel.frost"
	# The sea is open: nothing out here stops a line of sight or a sound, so it
	# holds more ground than a keeper among works and walls.
	d.reach = 34.0
	d.stations = [&"soundings"]
	# The soundings line's own parts feed it. Nothing here starves it, so the
	# list only says what it stands among.
	d.feeds = [PropKind.SOUNDING_RIG, PropKind.PIPE, PropKind.WATER_TANK]
	d.drops = &"sentinel_listener"
	d.core = &"listener_core"
	d.hulk = PropKind.WRECKAGE

	# Phase one: listening. Spears down, near-still, the receiver at its back the
	# working part. The crown driven into the ice all round it throws a blow off,
	# and it bites by driving a spear at whatever comes close enough to hear.
	var listening := SentinelPhase.make(&"listening", 1.0, &"back",
		{"swing": [800, 160, 760, 880], "reach": 1.8, "width": 1.8, "dmg": 3, "knock": 8.0, "knock_ms": 300})
	listening.guarded = true
	listening.pace = 2.4
	listening.dash = 6.0
	listening.quick = 260
	listening.turn = 1.2
	listening.note = "Guarded: the spears are a fence round it while it listens, so the opening is the stand after a drive that missed."

	# Phase two: cutting. The spears come up and the saw under its left flank
	# comes down: it saws a ring in the ice round the player, and the gear that
	# drives the saw is open on that side.
	var cutting := SentinelPhase.make(&"cutting", 0.6, &"left",
		{"swing": [560, 150, 640, 760], "reach": 2.0, "width": 2.4, "dmg": 4, "knock": 9.0, "knock_ms": 320})
	cutting.pace = 4.8
	cutting.dash = 9.5
	cutting.quick = 330
	cutting.turn = 1.3
	cutting.note = "The saw is down on its left: the ring it cuts is the ground that will take it."
	# HOOK, shared system 5 (docs/LANDSCAPES.md, "Time-varying ground edits"):
	# a bite landed in this phase also opens a ring of BLACKWATER in the ice round
	# the player for about a world minute, then the lead refreezes. That is the
	# ground edit the founder way below is played against, and it is not built
	# here: it needs a saved edit list, a chunk refresh and a WorldQuery restamp,
	# which land once for the icesaw's cut, this ring and the tide together. Until
	# then the blow is real and the ring is the leads the sea already opened.

	# Phase three: breaching. It runs, skis hissing: fast, straight charges that
	# it turns badly out of, with its bare face the last thing left open.
	var breaching := SentinelPhase.make(&"breaching", 0.3, &"front",
		{"swing": [640, 170, 700, 900], "reach": 2.2, "width": 2.0, "dmg": 5, "knock": 12.0, "knock_ms": 380})
	breaching.pace = 6.0
	breaching.dash = 12.0
	breaching.quick = 380
	breaching.turn = 0.8
	breaching.note = "Charging on its skis: fastest, hardest, and it cannot come round — the lead is where it ends."
	d.phases = [listening, cutting, breaching]

	var force := SentinelWay.make(SentinelWay.FORCE)
	force.says = "The receiver at its back, then its saw flank, then its face as it charges."
	# About 1200 ms in the water: shorter than the reaper's mud, because a lead is
	# narrow and a charge crosses one fast — the hold is the width of a lead at a
	# run, not a stand in it.
	var founder := SentinelWay.make(SentinelWay.FOUNDER, 1200.0, [Ground.BLACKWATER])
	founder.says = "It is too heavy for a lead. Bring it across black water, or across its own cut."
	var spoof := SentinelWay.make(SentinelWay.SPOOF, 2400.0)
	spoof.says = "Its orders come as pings. Stand on a sounding hole wearing the signet and it files you as a rig."
	d.ways = [force, founder, spoof]
	return d
