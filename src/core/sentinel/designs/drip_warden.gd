## The Limestone Caves' keeper: the drip-warden. The plan cut in from above for
## the stone, and water is what stops a face being worked: this keeps the
## cuttings dry. A squat riser mast on three limed legs, a pump pack at its hip,
## a spray lance on the mast and the drip crown at its top, hung with the
## stalactites its own lime has grown on it (sentinel_drip_warden.gd).
##
## ITS GROUND RULE: IT SEALS THE WAY BEHIND YOU (roster `seals`,
## FightSim.curtains). A gap the player passes while it hunts is sprayed shut
## with lime after a tell it stands still for; the curtain stops the player and
## not the warden, two heavy blows break one, and it keeps two standing. A chase
## is the cave being closed round you: the answer is choosing where you are
## cornered -- under the cracked roof (CrackedRoof), where the line brings a
## stone down on its crown (FightSim.hangings).
##
## How it is beaten, three ways:
##   force    the pump pack on its back while it keeps the cuttings; the lance
##            feed on its spray side (its right) once it seals, guarded by the
##            lance itself; its front once it runs dry, bare. A stone off the
##            roof on its crown stalls it whatever side it shows.
##   founder  the silt at the sump's edge will not carry it (the SHORE of a
##            flooded bottom lays SAND: LimestoneCaves._surface). Hold it there.
##   starve   its pumps feed on the pump houses and the pipe run the plan laid
##            to the face. Robbed, the galleries flood and it stands dead.
##
## SPOOF IS LEFT OUT: it reads no signature. It sprays whatever moves through a
## kept gap; a body that reads as one of its own is a body in the way.


static func make() -> SentinelDef:
	var d := SentinelDef.new()
	d.id = &"drip_warden"
	d.land = &"limestone_caves"
	d.display_name = "the drip-warden"
	d.note = "A squat mast on three limed legs, a drip crown hung with its own stalactites: it seals the cave behind you."
	d.kind = &"sentinel.limestone_caves"
	# A hall and the galleries off it, which is how far a lime curtain matters.
	d.reach = 28.0
	# The sump pump the plan keeps at a face. The caves lay no works yet
	# (GenWorks `works: &""`), so no region holds one and the keeper stands at its
	# region's heart, as `Sentinels.lair` does for any station nobody laid.
	d.stations = [&"sump_pump"]
	# What keeps its pumps: the pump houses and the pipe run to the face.
	d.feeds = [PropKind.PUMP_HOUSE, PropKind.PIPE]
	d.come_round = "It swings the lance round on its mast and hoses the side you keep to with lime."
	d.drops = &"sentinel_drip_warden"
	d.core = &"drip_core"
	# It calcifies where it falls: the keeper becomes the cave's own stone.
	d.hulk = PropKind.DRIPSTONE

	# Phase one: keeping. It keeps the cuttings dry, slow, and works by ear; the
	# long windup is the cave hauler's register. The pump pack on its back is open.
	var keeping := SentinelPhase.make(&"keeping", 1.0, &"back",
		{"swing": [720, 160, 820, 920], "reach": 2.4, "width": 2.8, "dmg": 4, "knock": 10.0, "knock_ms": 320})
	keeping.pace = 3.0
	keeping.dash = 5.0
	keeping.quick = 280
	keeping.turn = 1.0
	keeping.note = "It keeps the cuttings dry. The lance comes round slow; the pump on its back is the part."

	# Phase two: sealing. The lance guards the feed on its spray side, and the
	# opening is the stand after a spray, while it winds the lance back.
	var sealing := SentinelPhase.make(&"sealing", 0.6, &"right",
		{"swing": [640, 170, 780, 880], "reach": 2.5, "width": 2.8, "dmg": 4, "knock": 10.0, "knock_ms": 320})
	sealing.guarded = true
	sealing.pace = 3.4
	sealing.dash = 5.5
	sealing.quick = 290
	sealing.turn = 1.1
	sealing.note = "Guarded: the lance covers the feed on its spray side; the opening is the stand after it sprays."

	# Phase three: dry. Its pumps are dead and it thrashes instead of spraying;
	# the feed at its front is bare.
	var dry := SentinelPhase.make(&"dry", 0.3, &"front",
		{"swing": [580, 180, 700, 800], "reach": 2.2, "width": 2.6, "dmg": 5, "knock": 11.0, "knock_ms": 340})
	dry.pace = 3.8
	dry.dash = 6.0
	dry.quick = 300
	dry.turn = 1.2
	dry.note = "Its pumps are dry: it thrashes, and its front is bare."
	d.phases = [keeping, sealing, dry]

	var force := SentinelWay.make(SentinelWay.FORCE)
	force.says = "The pump on its back, then the lance feed on its spray side, then its front once it runs dry. A stone off the roof stalls it."
	var founder := SentinelWay.make(SentinelWay.FOUNDER, 1500.0, [Ground.SAND])
	founder.says = "The silt at the sump's edge will not carry it. Bring it onto the silt and hold it there."
	var starve := SentinelWay.make(SentinelWay.STARVE, 4000.0)
	starve.says = "The pump houses and the pipe run feed it. Rob them and the galleries flood round it."
	d.ways = [force, founder, starve]
	return d
