class_name Takes
## What each prop in the world gives, and how (design-extract §9.5, mapped
## onto PropKind). Pure data plus the rule that picks an option for the tool in
## hand. No nodes, no game.
##
## An option:
##   verb      break dig fell cut need a held tool with that verb;
##             gather scrape tap turn are bare-handed
##   item, n   what one take adds
##   min       bare-hand world minutes (a matching tool's speed and edge shorten it)
##   regrow    hours until it can be taken again; NEVER = a permanent world edit
##   stuff     hardness the tool must reach (wood iron steel crucible)
##   uses      takes before the option is exhausted (a vein works out, a tip is picked over)
##   keep      true: the prop stays standing when exhausted (a rock after its mussels);
##             false: it is taken away (WorldData.depleted) until it regrows
##   tide      &"low": only when the water is off it (see TIDE_GATES)
##   bonus     [item, chance]: sometimes one more thing comes up with it
##   ground    only on these grounds (empty = any)
##
## Options are tried in order: a held tool whose verb matches wins; otherwise
## the first bare-handed option that is not exhausted.
##
## Departures from the source, for a game without trade:
## - A boulder gives a loose stone by hand (so a fire ring needs no pick);
##   breaking it with a pick gives more and takes it away.
## - Ore is broken with a pick OR dug with a mattock, and iron needs only iron,
##   so the first pick opens the iron rung. Copper (not in the source) needs steel.
## - Driftwood comes two at a time: the first fire should not be a chore.
## - Any tree gives dead wood by hand, and a ruin gives a little plate, so the
##   way in (a fire, a haft, a pick) opens inland as well as on the shore.

const NEVER := -1.0

const TOOL_VERBS: Array[StringName] = [&"break", &"dig", &"fell", &"cut"]

## The source gates shore food on the tide. The water does not yet visibly
## move, so an invisible gate would read as a bug; the data keeps the tide and
## this switch turns it on when the shore shows it.
const TIDE_GATES := false

static var _table: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		_table = _build()
	return _table


static func _o(verb: StringName, item: StringName, n: int, minutes: float, regrow: float, extra: Dictionary = {}) -> Dictionary:
	var o := {"verb": verb, "item": item, "n": n, "min": minutes, "regrow": regrow,
		"stuff": &"", "uses": 1, "keep": false, "tide": &"", "bonus": [], "ground": []}
	o.merge(extra, true)
	return o


static func _build() -> Dictionary:
	var t := {}
	var fell_tree := _o(&"fell", &"timber", 2, 18.0, NEVER, {"stuff": &"iron"})
	# Fallen wood under a crown, picked up by hand: a live tree drops a little, slowly.
	# Picking up by hand is a few minutes of the clock: a morning's gathering at
	# the source's minutes spent two hours before the first fire was laid.
	var deadfall := _o(&"gather", &"deadwood", 1, 3.0, 36.0, {"keep": true})
	var resin := _o(&"tap", &"resin", 1, 8.0, 96.0, {"keep": true})
	t[PropKind.PINE] = [fell_tree, deadfall, resin]
	t[PropKind.SNOW_PINE] = [fell_tree, deadfall, resin]
	t[PropKind.BROADLEAF] = [fell_tree, deadfall]
	# A dead tree sheds its own limbs: more of them, and they come back sooner.
	t[PropKind.DEAD_TREE] = [_o(&"fell", &"timber", 1, 11.0, NEVER, {"stuff": &"iron"}),
		_o(&"gather", &"deadwood", 2, 3.0, 24.0, {"keep": true, "uses": 2})]
	t[PropKind.BUSH] = [
		_o(&"gather", &"samphire", 1, 3.0, 18.0, {"keep": true, "ground": [Ground.SAND, Ground.SHINGLE, Ground.MUD]}),
		_o(&"gather", &"berries", 1, 3.0, 36.0, {"keep": true, "ground": [Ground.GRASS, Ground.HEATH, Ground.MOSS,
			Ground.NEEDLES, Ground.SNOW, Ground.BONE, Ground.ASH, Ground.ROCK, Ground.GRAVEL, Ground.SCREE,
			Ground.LIMESTONE, Ground.PEAT, Ground.FLOOR, Ground.ROAD, Ground.CLINKER]}),
	]
	t[PropKind.REEDS] = [_o(&"cut", &"reeds", 2, 7.0, 24.0, {"stuff": &"iron"})]
	t[PropKind.GORSE] = [_o(&"cut", &"gorse_cut", 1, 9.0, 72.0, {"stuff": &"iron"})]
	t[PropKind.PEAT_BANK] = [_o(&"cut", &"peat", 3, 10.0, NEVER, {"stuff": &"iron", "uses": 2}),
		_o(&"dig", &"peat", 3, 10.0, NEVER, {"stuff": &"iron", "uses": 2})]
	# Rock out in the snow grows crottle on its crust: scraped by hand once the loose stone is had.
	var crottle := _o(&"scrape", &"crottle", 1, 12.0, 240.0, {"keep": true, "ground": [Ground.SNOW, Ground.ICE]})
	t[PropKind.BOULDER] = [
		_o(&"break", &"stone", 2, 20.0, NEVER, {"stuff": &"iron", "uses": 2}),
		_o(&"gather", &"stone", 1, 5.0, 24.0, {"keep": true}),
		crottle,
	]
	t[PropKind.STONE_ORE] = [
		_o(&"break", &"stone", 2, 14.0, NEVER, {"stuff": &"iron", "uses": 3}),
		_o(&"gather", &"stone", 1, 5.0, 24.0, {"keep": true}),
		crottle,
	]
	# A fallen roof was patched in plate: turned over by hand, a piece or two comes out of the rubble.
	t[PropKind.RUIN] = [_o(&"break", &"stone", 2, 25.0, NEVER, {"stuff": &"iron", "uses": 2}),
		_o(&"turn", &"scrap", 1, 30.0, 96.0, {"keep": true})]
	# **ON LIMESTONE, BECAUSE A CLINT ON ROCK IS NOT LIMESTONE PAVEMENT.** A clint
	# is the block between the grikes of a limestone pavement; the same model
	# standing on plain rock in the crags is a rock formation and gives no
	# limestone. Measured over three seeds: 139 clints on limestone (all
	# bonelands) and 12 on rock (all the crags). Stating the ground is also what
	# makes `clint_spar`'s "land: bonelands" TRUE -- an elite material has one
	# gate, and a raw three landscapes give is not a gate
	# (tests/gear_economy/test_obtainable.gd).
	t[PropKind.CLINTS] = [_o(&"break", &"limestone", 2, 13.0, NEVER,
		{"stuff": &"iron", "uses": 2, "ground": [Ground.LIMESTONE]})]
	for pair: Array in [[PropKind.COAL_ORE, &"coal", 22.0, &"iron"], [PropKind.TIN_ORE, &"tin_ore", 22.0, &"iron"],
			[PropKind.IRON_ORE, &"iron_ore", 30.0, &"iron"], [PropKind.COPPER_ORE, &"copper_ore", 30.0, &"steel"]]:
		t[pair[0]] = [
			_o(&"break", pair[1], 1, pair[2], NEVER, {"stuff": pair[3], "uses": 3}),
			_o(&"dig", pair[1], 1, pair[2], NEVER, {"stuff": pair[3], "uses": 3}),
		]
	t[PropKind.MUSSEL_ROCK] = [_o(&"gather", &"mussels", 1, 3.0, 12.0, {"keep": true, "uses": 2, "tide": &"low", "bonus": [&"whelks", 0.35]})]
	t[PropKind.DRIFTWOOD] = [_o(&"gather", &"driftwood", 2, 2.0, 12.0)]
	t[PropKind.WRACK] = [_o(&"gather", &"wrack", 2, 2.0, 6.0)]
	# Scrap takes jumped the clock one to two and a half hours from one press; at
	# most half an hour now (Survival.MAX_JUMP_MINUTES), so a machine charging
	# you is never skipped past and the first plate comes in the morning.
	t[PropKind.TIP] = [
		_o(&"dig", &"scrap", 1, 15.0, 48.0, {"stuff": &"iron", "keep": true, "uses": 3}),
		_o(&"turn", &"scrap", 1, 20.0, 48.0, {"keep": true, "uses": 2}),
	]
	t[PropKind.WRECK] = [_o(&"break", &"scrap", 2, 30.0, NEVER, {"stuff": &"iron", "uses": 2})]
	t[PropKind.POLE] = [_o(&"break", &"scrap", 1, 30.0, NEVER, {"stuff": &"iron"})]
	t[PropKind.PYLON] = [_o(&"break", &"scrap", 2, 30.0, NEVER, {"stuff": &"steel", "uses": 3})]
	# **ON THE BURNING'S OWN GROUND.** Brimstone is dug out of the sulphur beds,
	# and a vent standing on a slum floor or on salt is a vent in something else.
	# Measured over three seeds: 97 vents on clinker or ash (96 of them in the
	# burning) against 10 on floor or salt elsewhere. The ground is what makes
	# `cinder_glass`'s "land: burning" true, and that one gate is the rule (an
	# elite material has ONE gate: `docs/ROADMAP.md` M3).
	#
	# **SO THE SULPHUR JUNGLE'S VENTS GIVE NOTHING, ON PURPOSE, FOR NOW.** Its vents
	# stand in its own crust, SALT, and now have fields of their own to stand in;
	# opening this row to them would hand cinder_glass a second land. What they
	# should yield is a raw of the jungle's own that feeds its answer to fumes
	# (M3: every landscape a material only it gives) -- the jungle's L2 builder's
	# job, not this row's.
	t[PropKind.VENT] = [_o(&"dig", &"brimstone", 1, 16.0, 72.0,
		{"stuff": &"iron", "keep": true, "uses": 2, "ground": [Ground.CLINKER, Ground.ASH]})]
	# What was lost (landscape: props/remains.gd) is salvage. Loose debris is
	# picked up for good; a car or a barricade is broken for its plate, or picked
	# over by hand; a beached hull gives planks and its fittings; a fence gives a
	# post to an axe and a rail to a hand; a stump is the last of a tree.
	t[PropKind.DEBRIS] = [_o(&"turn", &"scrap", 1, 30.0, NEVER)]
	# Stripping a car, a barricade or a hull is hours of work, and it is taken in
	# goes: each press is at most half an hour of the clock (Survival.MAX_JUMP_MINUTES)
	# and `uses` says how many goes the thing has in it, so nothing is ever skipped
	# past in one press and a machine can arrive while you are at it.
	t[PropKind.VEHICLE] = [_o(&"break", &"scrap", 2, 25.0, NEVER, {"stuff": &"iron", "uses": 4}),
		_o(&"turn", &"scrap", 1, 20.0, 96.0, {"keep": true, "uses": 3})]
	t[PropKind.BARRICADE] = [_o(&"break", &"scrap", 2, 20.0, NEVER, {"stuff": &"iron", "uses": 4}),
		_o(&"turn", &"scrap", 1, 25.0, 120.0, {"keep": true, "uses": 2})]
	t[PropKind.HULL] = [_o(&"break", &"scrap", 1, 30.0, NEVER, {"stuff": &"iron", "uses": 4}),
		_o(&"gather", &"driftwood", 1, 8.0, 48.0, {"keep": true})]
	t[PropKind.FENCE] = [_o(&"fell", &"timber", 1, 12.0, NEVER, {"stuff": &"iron"}),
		_o(&"gather", &"deadwood", 1, 5.0, 72.0, {"keep": true})]
	# Cloth: a shelter nobody came back to, and what a machine tore apart, still
	# hold the soft stuff a made garment needs (the hazards package's gear).
	t[PropKind.SHACK] = [_o(&"turn", &"scrap", 1, 25.0, 96.0, {"keep": true, "uses": 2}),
		_o(&"gather", &"rag", 2, 6.0, 72.0, {"keep": true, "uses": 2})]
	t[PropKind.WRECKAGE] = [_o(&"break", &"scrap", 2, 28.0, NEVER, {"stuff": &"iron", "uses": 3}),
		_o(&"gather", &"rag", 1, 6.0, 96.0, {"keep": true, "uses": 2})]
	# Found tech comes off the plan's own works, and only to a steel edge: a signet
	# prised out of a relay, a shield plate cut off a checkpoint. Neither grows back,
	# and a charge sometimes comes up with the plate.
	# A mast or a barrier robbed of its one good part still stands there, dead.
	t[PropKind.RELAY] = [_o(&"break", &"mod_signet", 1, 30.0, NEVER, {"stuff": &"steel", "keep": true}),
		_o(&"turn", &"scrap", 1, 25.0, 96.0, {"keep": true, "uses": 2, "bonus": [&"wick", 0.5]})]
	t[PropKind.CHECKPOINT] = [_o(&"break", &"shield_plate", 1, 30.0, NEVER, {"stuff": &"steel", "keep": true}),
		_o(&"turn", &"scrap", 1, 25.0, 120.0, {"keep": true, "uses": 2, "bonus": [&"wick", 0.5]})]
	t[PropKind.STUMP] = [_o(&"fell", &"timber", 1, 14.0, NEVER, {"stuff": &"iron"}),
		_o(&"gather", &"deadwood", 1, 5.0, 48.0, {"keep": true})]
	_signature(t)
	# The machines' own works are made of the best parts on the coast, and they
	# are not abandoned: taking from one is theft, and the plan's network files
	# it (Interference). The thing is left standing, opened and short a part.
	# ...but a work that already says what it gives keeps its own row: the relay
	# and the checkpoint are where the only found tech in the game comes from,
	# and they are on this list because robbing them is theft, not because they
	# hand out scrap like the rest.
	for k: int in PLAN_WORKS:
		if not t.has(k):
			t[k] = [_o(&"turn", &"scrap", 1, 12.0, 96.0, {"keep": true, "uses": 2})]
	return t


## What a landscape's own things give (docs/ROADMAP.md M3: "every signature prop
## does something to a body"). Every row here is KEPT: the thing stays standing
## when it is spent, because a take that carries a thing away needs a remnant of
## its own (RemnantModels.for_kind) and one that works it down needs a `Broken`
## cut that suits its model, and neither is this file's to add. Nothing here
## gives an elite material's raw: brimstone, limestone, peat and crottle each have
## one gate (EliteStock) and a second prop giving them would open a second.
static func _signature(t: Dictionary) -> void:
	# The salt flats. The crust IS salt: a pressure ridge is broken for a lump of
	# it and gives a little to a hand, and the crust grows back as the brine dries
	# (so it regrows, where a quarried stone does not).
	t[PropKind.SALT_RIDGE] = [_o(&"break", &"salt", 2, 12.0, 96.0, {"stuff": &"iron", "keep": true, "uses": 2}),
		_o(&"gather", &"salt", 1, 4.0, 24.0, {"keep": true})]
	# A heap the rakers left: salt by the armful until it is down to the part
	# fused under the sheet, and then the sheet itself, torn for rags. Neither
	# comes back: nobody is raking it any more.
	t[PropKind.SALT_HEAP] = [_o(&"gather", &"salt", 2, 5.0, NEVER, {"keep": true, "uses": 3}),
		_o(&"gather", &"rag", 1, 6.0, NEVER, {"keep": true})]
	# The gate is the ruler's, but the sandbags stacked against it are people's
	# (props/salt.gd), so what comes away is their sacking and taking it robs
	# nobody's network. The sluice itself is NOT a plan work here on purpose:
	# 34_works._strip spends every plan work in a broken yard, and the pan rake
	# feeds on pan gates, so making one a plan work would move the salt flats'
	# STARVE way -- tests/works/test_in_game.gd measures that seam and it is not
	# this file's to move.
	t[PropKind.PAN_GATE] = [_o(&"gather", &"rag", 1, 6.0, NEVER, {"keep": true, "uses": 2})]
	# The scrapwood. Plate grown into a crown is pulled out of the bark, and the
	# tree drops its dead wood like any tree. Nothing fells it: it grows leaves,
	# and a take that works a leafy thing down cuts the trunk under a whole crown
	# (tests/render/test_foliage.gd).
	t[PropKind.SCRAP_TREE] = [_o(&"turn", &"scrap", 1, 20.0, 96.0, {"keep": true, "uses": 2}),
		_o(&"gather", &"deadwood", 1, 3.0, 36.0, {"keep": true})]
	# Filings drawn up into a cone by a dead frame's field: shovelled out, they are
	# iron to smelt, once; a shard pulled off by hand comes back, because the field
	# stands another one up (props/scrap.gd).
	t[PropKind.MAGNET_HEAP] = [_o(&"dig", &"iron_ore", 1, 18.0, NEVER, {"stuff": &"iron", "keep": true, "uses": 2}),
		_o(&"turn", &"scrap", 1, 15.0, 72.0, {"keep": true})]
	# The drowned city (docs/LANDSCAPES.md: "break stone x2"). A length of cast
	# wall is broken for its blocks and still stands; it is cover more than quarry.
	t[PropKind.SEA_WALL] = [_o(&"break", &"stone", 2, 22.0, NEVER, {"stuff": &"iron", "keep": true, "uses": 2})]
	# The plan's gauge (docs/LANDSCAPES.md: "strip brass; theft"). Its brass
	# fittings are copper enough to pour, and only a steel edge gets them off,
	# the same rung copper ore wants, so it opens nothing early. It is a plan work
	# below: robbing it is filed.
	t[PropKind.TIDE_GAUGE] = [_o(&"break", &"copper", 1, 30.0, NEVER, {"stuff": &"steel", "keep": true}),
		_o(&"turn", &"scrap", 1, 20.0, 96.0, {"keep": true, "uses": 2})]
	# Slag the works tipped still holds the iron nobody recovered: dug out with a
	# tool, a few goes, like a tip. It is a heap of glass and cinder to a hand.
	t[PropKind.SLAG_HEAP] = [_o(&"dig", &"scrap", 1, 18.0, NEVER, {"stuff": &"iron", "keep": true, "uses": 3})]
	# A tank on a stand: the riveted plate comes off to an iron edge, and the
	# tank goes on standing, empty. Not theft: the same kind is people's water on
	# the orchards (props/remains.gd) and the plan's on the server fields, and one
	# row cannot tell which it is standing at.
	t[PropKind.WATER_TANK] = [_o(&"break", &"scrap", 1, 25.0, NEVER, {"stuff": &"iron", "keep": true})]
	# A lamp standard is a pole with a head on it, and gives what a pole gives. It
	# is KEPT, unlike a pole, because a live lamp is what the metropolis's keeper
	# is spoofed under (docs/LANDSCAPES.md) and a village's is somebody's light.
	t[PropKind.LAMP] = [_o(&"break", &"scrap", 1, 25.0, NEVER, {"stuff": &"iron", "keep": true})]
	# The crags (docs/LANDSCAPES.md: "turn stone x1"). One stone turned off a
	# waymark, once: taking the cairn down would take the way with it. The
	# player's own heap is also a CAIRN, and `Survival.use` answers a heap with
	# `take_back` before it ever asks this table (state.left comes first).
	t[PropKind.CAIRN] = [_o(&"turn", &"stone", 1, 6.0, NEVER, {"keep": true})]
	# The crags' carved face (docs/LANDSCAPES.md: "break hushstone x1, steel,
	# uses 2"). Hushstone is the crags' own raw -- stone a scanner reads as
	# nothing at all -- and it comes out of a face somebody cut, with a steel
	# edge, twice, and then the face is gone: quarrying the land's memory for the
	# one stone the machines cannot see is a choice, and it is meant to cost one.
	# Gated to ROCK, the ground the crags stand these on, so the same kind dealt
	# onto another land's ground gives the land's stone and not the crags' (which
	# is how the snowfield keeps its crottle; tests/gear_economy/test_obtainable).
	t[PropKind.CARVED_FACE] = [_o(&"break", &"hushstone", 1, 24.0, NEVER, {"stuff": &"steel", "uses": 2, "ground": [Ground.ROCK]}),
		_o(&"break", &"stone", 2, 20.0, NEVER, {"stuff": &"iron", "uses": 2})]
	# The survey's mast (docs/LANDSCAPES.md: "strip lens_glass x1; theft"). The
	# lens is unscrewed by hand, so the verb is `turn` -- the verb set is closed,
	# each has a sound (src/audio/sound_names.gd), and "strip" is what a person
	# would call it rather than a verb the key knows. It is NOT kept: with its
	# lens gone the mast is nothing and comes down, which is what stops it
	# feeding the crags' keeper (Sentinels.feeds counts what is not depleted).
	t[PropKind.THEODOLITE_MAST] = [_o(&"turn", &"lens_glass", 1, 12.0, NEVER)]
	# The rack of cores (docs/LANDSCAPES.md: "turn stone x2, keep; theft"). Two
	# cores turned out of it and it goes on standing, empty.
	t[PropKind.CORE_RACK] = [_o(&"turn", &"stone", 2, 10.0, NEVER, {"keep": true, "uses": 2})]


## The kinds that give NOTHING, on purpose, and why. `tests/survival/
## test_signature_takes.gd` holds every PropKind to either a row above or a line
## here, so a kind added later cannot quietly be a thing `use` walks past.
## A thing that gives nothing still does something to a body (docs/ROADMAP.md
## M3): it shelters (52_hazards ROOFS), hides (Cover), is read, or is worked at.
const GIVES_NOTHING := {
	PropKind.GRAVE: "People leave a grave alone, and somebody still lights the jar on one (props/remains.gd). It is read, and it is cover.",
	PropKind.MEMORIAL: "The dead of one day, with what they carried set on it. Nobody who lives here takes from it; it is read, and it is cover.",
	PropKind.STANDING_STONE: "One stone set up by people who meant it to stay, and read as a mark (StoryProps). It is cover; a boulder beside it gives the same stone.",
	PropKind.BONES: "No recipe uses bone and none is invented for it. The bones are cover, and they say what this land did.",
	PropKind.MURAL: "The landscape's one image, on a wall somebody kept standing. Its wall hides a body; nobody quarries the painting.",
	PropKind.BENCH: "A workbench is a station: `c` makes at it (Survival.STATION_KINDS). A `use` that broke it up would take the station out from under the player.",
	PropKind.FIRE: "A station: it lights, warms and is slept by.",
	PropKind.KILN: "A station, worked at with `c`.",
	PropKind.HOUSE: "Somebody lives in it, and its bench, wheel and loom are stations (Survival.STATION_KINDS).",
	PropKind.SIGN: "What a sign gives is its words (StoryProps.READABLE).",
	PropKind.CONSOLE: "The screens on the tank a man was grown in are read, never stripped (prop_kind.gd), and one kind cannot tell the threshold site's console from a server field's.",
	PropKind.GROWTH_TANK: "The tank he was grown in stands at the threshold site; the same kind on the orchards is the same tank, and nothing in it is a material.",
	PropKind.PLATFORM: "A deck is walked on: its mass is BlackSite.blocks, and there is nothing at hand height to take.",
	PropKind.STACK: "An exhaust read from everywhere. As a plan work, a broken yard (34_works._strip) would take it off the skyline; as anything else it would be the one machine work robbed unnoticed.",
	PropKind.PUMP_HOUSE: "A roof (52_hazards ROOFS): it shelters a body. It is also a keeper's feed (sentinel/designs/tide_reaper.gd), and a take that spent it would be a starving nobody designed.",
	PropKind.FIRE_TOWER: "A roof (52_hazards ROOFS): a body shelters in the cabin.",
	PropKind.LINTEL: "A roof (52_hazards ROOFS): the cap stone takes the wet and the dark off a body under it. Its uprights are the boulders beside it, which give the same stone; nobody quarries a doorway that was standing before the machines.",
	PropKind.HOLLOW_WAY: "A lane between two dry-stone banks: cover (Cover.PROPS) for a body walking it, and the walling is the ruin's, which gives the same stone. A take that broke a bank would take the lane's one use with it.",
}


## The works of the plan: what a machine takes it amiss to be robbed of
## (VISION §2, "take its parts"). Every one of them is robbable by hand above,
## so the disposition package can file the theft of any of them; a work with no
## take option is not on this list, because nothing could ever steal from it.
## Being on it also means 34_works._strip spends it for good when its yard is
## broken, which is why a stack is not.
const PLAN_WORKS: Array[int] = [PropKind.RELAY, PropKind.SURVEY, PropKind.CONVEYOR,
	PropKind.PIPE, PropKind.INTAKE, PropKind.CHECKPOINT, PropKind.DRILL_RIG,
	PropKind.TIDE_GAUGE, PropKind.VENT_CAP, PropKind.ARCHIVE,
	# The crags' survey furniture: a lens off a mast and cores out of a rack are
	# both filed as theft (docs/LANDSCAPES.md §1), and both feed its keeper.
	PropKind.THEODOLITE_MAST, PropKind.CORE_RACK]


static func is_plan_work(kind: int) -> bool:
	return PLAN_WORKS.has(kind)


static func workable(kind: int) -> bool:
	return table().has(kind)


static func options(kind: int) -> Array:
	return table().get(kind, [])


## Tide height 0..1 at a world minute: two tides per 24 h 50 m, t=0 low. (source §5)
static func tide(minutes: float) -> float:
	return 0.5 - 0.5 * cos(TAU * fposmod(minutes, 1490.0) / 745.0)


static func tide_is_low(minutes: float) -> bool:
	return tide(minutes) < 0.34


## Choose how a prop would be worked with `held`. `exhausted` is a Callable
## (option index -> bool). Returns:
##   {ok: true, index, option}                 it can be worked now
##   {ok: false, index, option, why: reason}   it cannot; why is one of
##       &"hands" (needs a tool you do not hold), &"hard" (tool too soft),
##       &"spent" (picked over, comes back later), &"tide" (water over it), &"none"
static func choose(kind: int, ground: int, held: StringName, exhausted: Callable, minutes: float) -> Dictionary:
	var opts := options(kind)
	if opts.is_empty():
		return {"ok": false, "index": -1, "option": {}, "why": &"none"}
	var held_verb := Items.verb(held)
	var fallback := {}
	# 1. The held tool's verb.
	for i in opts.size():
		var o: Dictionary = opts[i]
		if held_verb == &"" or o.verb != held_verb or not _on_ground(o, ground):
			continue
		if not Items.hard_enough(held, o.stuff):
			fallback = {"ok": false, "index": i, "option": o, "why": &"hard"}
			continue
		if exhausted.call(i):
			fallback = {"ok": false, "index": i, "option": o, "why": &"spent"}
			continue
		return {"ok": true, "index": i, "option": o}
	# 2. Bare hands.
	for i in opts.size():
		var o: Dictionary = opts[i]
		if TOOL_VERBS.has(o.verb) or not _on_ground(o, ground):
			continue
		if exhausted.call(i):
			if fallback.is_empty():
				fallback = {"ok": false, "index": i, "option": o, "why": &"spent"}
			continue
		if TIDE_GATES and o.tide == &"low" and not tide_is_low(minutes):
			fallback = {"ok": false, "index": i, "option": o, "why": &"tide"}
			continue
		return {"ok": true, "index": i, "option": o}
	if not fallback.is_empty():
		return fallback
	for i in opts.size():
		if _on_ground(opts[i], ground):
			return {"ok": false, "index": i, "option": opts[i], "why": &"hands"}
	return {"ok": false, "index": -1, "option": {}, "why": &"none"}


static func _on_ground(o: Dictionary, ground: int) -> bool:
	var g: Array = o.ground
	return g.is_empty() or g.has(ground)


## The player-facing line for a refusal reason. The first two are the source's.
static func refusal(why: StringName, held: StringName) -> String:
	match why:
		&"hands":
			return "Not with your hands." if Items.verb(held) == &"" else "Not with that."
		&"hard":
			return "It rings, and nothing comes away."
		&"spent":
			return "There is nothing more on it yet."
		&"tide":
			return "The water is over it."
	return ""
