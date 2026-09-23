## The Salt Flats' keeper: a rake on stilts (docs/VISION.md; §3's table gives
## the flats their pan rakers and their mirage decoys). It stands at the brine
## house among the evaporation pans and goes round and round pans that yield
## nothing, and it keeps every pan in the basin.
##
## What it is: a flat triangular deck close over the crust on four long splayed
## legs, a rake beam dragging behind it, and a single mast above carrying a tilting
## mirror — a heliostat, which is how a machine works a flat with no shade: it
## throws the sun. The silhouette is a delta on stilts under one disc, and it
## shares nothing with the Coast's arch.
##
## How it is beaten, three ways (§3, tactics not stats):
##   force    the rake gear behind it is open while it rakes; once the mirror comes
##            round it holds it over that flank, and the last phase stands it up to
##            its full height with the mast's foot bare. Three sides, in order.
##   founder  it made the pans, and the pans will not carry it. On the crust it is
##            sure-footed; over a pan floor its legs go through and it stays.
##   spoof    its orders come in from the pans' own relay and it is barely
##            functioning. Stand inside its guard with a signature it reads as one
##            of the machines' own and it files the player as its own and stands
##            down — beaten, never killed, and still standing on the flat.




static func make() -> SentinelDef:
	var d := SentinelDef.new()
	d.id = &"pan_rake"
	d.land = &"salt_flats"
	d.display_name = "the rake"
	d.note = "A delta on four stilts under one mirror: the flat's own shape, walking."
	d.kind = &"sentinel.salt"
	d.reach = 30.0
	d.stations = [&"brine_house", &"pans"]
	d.feeds = [PropKind.PAN_GATE, PropKind.WATER_TANK, PropKind.PIPE, PropKind.SURVEY]
	d.drops = &"sentinel_pan_rake"
	d.core = &"rake_core"
	d.hulk = PropKind.WRECKAGE

	# Phase one: raking. It drags its beam and stamps with a foreleg at whatever
	# comes in; the gear that drives the rake is behind it and open.
	var raking := SentinelPhase.make(&"raking", 1.0, &"back",
		{"swing": [620, 150, 700, 820], "reach": 1.8, "width": 1.6, "dmg": 3, "knock": 8.0, "knock_ms": 300})
	raking.pace = 4.6
	raking.dash = 9.0
	raking.quick = 310
	raking.turn = 1.5
	raking.note = "Stamping with a leg: the tell is the leg going up, and its gear is behind."

	# Phase two: the mirror comes round. It holds the disc over its open flank and
	# works the ground in front of it with the sun, so the side to be on is the one
	# it is shading — and a blow into the mirror rings.
	var dazzle := SentinelPhase.make(&"dazzle", 0.62, &"right",
		{"swing": [480, 140, 580, 700], "reach": 1.7, "width": 2.4, "dmg": 4, "knock": 9.0, "knock_ms": 320})
	dazzle.guarded = true
	dazzle.pace = 5.2
	dazzle.dash = 10.5
	dazzle.quick = 360
	dazzle.turn = 1.5
	dazzle.note = "Guarded: the mirror is over its working side until a bite leaves it open."

	# Phase three: stilted. It runs its legs out to full height, the crust cracking
	# under each foot, and comes down with the whole deck. Slow, heavy, and the
	# mast's foot is bare at the front.
	var stilted := SentinelPhase.make(&"stilted", 0.3, &"front",
		{"swing": [760, 190, 660, 980], "reach": 2.2, "width": 2.0, "dmg": 5, "knock": 11.0, "knock_ms": 360})
	stilted.pace = 3.6
	stilted.dash = 7.0
	stilted.quick = 250
	stilted.turn = 1.1
	stilted.note = "Up on its stilts: the slowest and the hardest, and it can be walked round."
	d.phases = [raking, dazzle, stilted]

	var force := SentinelWay.make(SentinelWay.FORCE)
	force.says = "Behind, then the flank it shades, then the mast's foot."
	var founder := SentinelWay.make(SentinelWay.FOUNDER, 1600.0, [Ground.PAN])
	founder.says = "It made the pans, and the pans will not carry it."
	var spoof := SentinelWay.make(SentinelWay.SPOOF, 2500.0)
	spoof.says = "Its orders come by relay. Wear a signature it knows and walk in."
	d.ways = [force, founder, spoof]
	return d
