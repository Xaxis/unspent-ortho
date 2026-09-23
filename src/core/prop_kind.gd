class_name PropKind
## Static things placed in the world by the generator. Rendered as MultiMesh
## instances per kind per chunk; collided with as circles.
##
## New kinds are appended at the end only: ids are saved and hashed.
## From FENCE on: the dystopian evidence each landscape holds (M2.0): what
## people left and still live in, and the machines' works across the land
## (src/models/props/remains.gd and works.gd, placed by GenWorks).

enum {
	PINE,
	BROADLEAF,
	DEAD_TREE,
	BUSH,
	REEDS,
	BOULDER,
	STONE_ORE,
	IRON_ORE,
	COPPER_ORE,
	PYLON,
	RUIN,
	HOUSE,
	LAMP,
	BONES,
	GORSE,
	DRIFTWOOD,
	WRACK,
	MUSSEL_ROCK,
	STANDING_STONE,
	CLINTS,
	VENT,
	TIP,
	WRECK,
	PEAT_BANK,
	SNOW_PINE,
	COAL_ORE,
	TIN_ORE,
	FIRE,
	BENCH,
	KILN,
	CAIRN,
	POLE,
	FENCE,
	BARRICADE,
	SIGN,
	GRAVE,
	DEBRIS,
	SHACK,
	VEHICLE,
	HULL,
	SEA_WALL,
	TIDE_GAUGE,
	INTAKE,
	PUMP_HOUSE,
	PIPE,
	STUMP,
	FIRE_TOWER,
	RELAY,
	CHECKPOINT,
	STACK,
	DRILL_RIG,
	CONVEYOR,
	SURVEY,
	WATER_TANK,
	SLAG_HEAP,
	VENT_CAP,
	ARCHIVE,
	WRECKAGE,
	MEMORIAL,
	# M2 landscapes bring their own things (salt flats, scrapwood).
	SALT_RIDGE,
	SALT_HEAP,
	PAN_GATE,
	SCRAP_TREE,
	MAGNET_HEAP,
	# The Slums: the wall the city painted, and what got bolted over it. The
	# sign itself is not a kind -- `Towers.billboard` hangs it on a wall.
	MURAL,
	# THE THRESHOLD SITE, standing in the sea off the home coast (`BlackSite`,
	# docs/STORY.md): the deck, the tank he was grown in, and the screens that
	# still have something to say. A CONSOLE is deliberately NOT one of the plan's
	# works -- a relay or a survey post is `Takes.PLAN_WORKS` and a second `use`
	# robs it, and the panel on the tank a man was grown in is not a thing you
	# strip for a signet.
	PLATFORM,
	GROWTH_TANK,
	CONSOLE,
	# THE CRAGS (docs/LANDSCAPES.md §1): what people cut out of the stone before
	# the machines -- a trilithon, a face in a boulder, a sunken lane between
	# dry-stone banks -- and the two pieces of survey furniture the plan left when
	# its instruments returned nothing it could file: a sighting mast and a rack
	# of cores. The masts and racks feed the crags' keeper (designs/plumb.gd).
	LINTEL,
	CARVED_FACE,
	THEODOLITE_MAST,
	CORE_RACK,
	HOLLOW_WAY,
	# THE FROST SEA (docs/LANDSCAPES.md §2, src/models/props/frost_sea.gd): what
	# the sea threw up, what it locked in, what the plan stood on it, and what
	# still lives under it. A pressure block is sea ice on end, a hull is a
	# trawler frozen in to the gunwale, a sounding rig is the plan's tripod over
	# a hole it keeps open, and a seal hole is a breathing hole with blood on it.
	PRESSURE_BLOCK,
	FROZEN_HULL,
	SOUNDING_RIG,
	SEAL_HOLE,
	# THE GLASS DESERT (docs/LANDSCAPES.md §3): what a place that was fused in a
	# second holds. Fulgurite tubes standing out of the drift, a burst dome of
	# glass, a car caught in the glassing, and the plan's own strike rod — the
	# one made thing here, and the only one that is THEIRS.
	FULGURITE,
	GLASS_BLISTER,
	FUSED_CAR,
	STRIKE_ROD,
	# THE RUINED METROPOLIS (docs/LANDSCAPES.md §4, src/models/props/metropolis.gd):
	# what a dead megacity left standing, and what the plan sorts it into. A
	# fallen span of elevated road, a lift core with its tower gone, a gutted
	# shop front; then the plan's own: a ruled bale of what it stripped, and the
	# straddle frame over its demolition face.
	DECK_SPAN,
	LIFT_SHAFT,
	SHOPFRONT,
	SORTED_BALE,
	DEMOLITION_GANTRY,
	# THE DROWNED CITY (docs/LANDSCAPES.md §5, src/models/props/drowned_city.gd):
	# how people meet the water where the street is a canal -- a stone stair
	# down off a quay, a crowd of piles a boat is tied to now the jetty has gone
	# -- what the water took and left standing, a tram half sunk in the silt,
	# and the plan's own: a gate leaf in a lock.
	STAIR_TO_WATER,
	DROWNED_TRAM,
	MOORING_POST,
	LOCK_GATE,
}

const COUNT := 90

const NAMES: PackedStringArray = [
	"pine", "broadleaf", "dead tree", "bush", "reeds", "boulder", "stone ore",
	"iron ore", "copper ore", "pylon", "ruin", "house", "lamp", "bones",
	"gorse", "driftwood", "wrack", "mussel rock", "standing stone", "clints", "vent", "tip",
	"wreck", "peat bank", "snow pine", "coal ore", "tin ore", "fire", "bench", "kiln", "cairn", "pole",
	"fence", "barricade", "sign", "grave", "debris", "shack", "vehicle", "hull", "sea wall", "tide gauge",
	"intake", "pump house", "pipe", "stump", "fire tower", "relay", "checkpoint", "stack", "drill rig",
	"conveyor", "survey", "water tank", "slag heap", "vent cap", "archive",
	"wreckage", "memorial",
	"salt ridge", "salt heap", "pan gate", "scrap tree", "magnet heap",
	"mural",
	"platform", "growth tank", "console",
	"lintel", "carved face", "theodolite mast", "core rack", "hollow way",
	"pressure block", "frozen hull", "sounding rig", "seal hole",
	"fulgurite", "glass blister", "fused car", "strike rod",
	"deck span", "lift shaft", "shopfront", "sorted bale", "demolition gantry",
	"stair to water", "drowned tram", "mooring post", "lock gate",
]

## Kinds past FENCE that are a landscape's own NATURE, not evidence somebody
## left: they are scattered like a boulder, by the per-tile scatter, and a
## reader counting what happened to a landscape should pass over them. The
## frost sea's block is ice the sea stood on end and its seal hole is a seal's:
## the hull and the rig are somebody's.
const WILD: Array[int] = [SALT_RIDGE, SCRAP_TREE, MAGNET_HEAP, PRESSURE_BLOCK, SEAL_HOLE,
	# The glass desert's fused sand: a strike's cast and a burst in the sheet are
	# what the land did, scattered like a boulder; the car and the rod are not.
	FULGURITE, GLASS_BLISTER]

## Collision radius in tiles at scale 1. 0 means you walk through it.
const SOLID: PackedFloat32Array = [
	0.3, 0.35, 0.25, 0.0, 0.0, 0.45, 0.4,
	0.4, 0.4, 0.4, 0.5, 1.6, 0.15, 0.0,
	0.3, 0.0, 0.0, 0.45, 0.35, 0.0, 0.35, 0.9,
	1.2, 0.4, 0.3, 0.4, 0.4, 0.3, 0.45, 0.6, 0.45, 0.12,
	0.0, 0.5, 0.1, 0.0, 0.0, 0.95, 0.8, 1.3, 0.6, 0.15,
	1.2, 0.95, 0.0, 0.0, 0.7, 0.2, 0.5, 0.9, 0.35,
	0.0, 0.0, 0.7, 1.0, 0.4, 0.6,
	0.0, 0.25,
	0.0, 0.55, 0.45, 0.4, 0.3,
	# A mural wall is SIX TILES of wall answered by ONE circle, which is the
	# limit of what a prop can say about itself. Whoever places these should hand
	# the wall to `WorldQuery.set_blocks` as circles along its length, the way a
	# landmark's tower and a depot's deck already do, or a player walks through
	# both ends of it.
	1.5,
	# The deck is 0: its mass is `BlackSite.blocks` handed to
	# `WorldQuery.set_blocks`, because a platform is a wall in the water and one
	# circle on a prop cannot say that. The tank and the console stop a body
	# themselves, as anything you walk up to and read should.
	0.0, 1.1, 0.35,
	# A trilithon is a wall with a window in it, and one circle cannot say so:
	# 1.2 is the spec's (docs/LANDSCAPES.md §1) and it stops a body at the
	# uprights. A carved face is a boulder. A mast and a rack stop a body as
	# furniture does. A hollow way is 0: it is a lane, and a lane is walked
	# through -- its banks are drawn, not stood against.
	1.2, 0.5, 0.25, 0.6, 0.0,
	# The frost sea: a block is cover you can put your back to; a hull frozen in
	# is six tiles of steel answered by one circle at its middle (the bulwark's
	# ends are walked through, the way a mural's are); a rig's legs stop a body
	# short of the hole; a seal hole is a hole, and a body stops at its rim.
	0.5, 1.4, 0.5, 0.3,
	# A fulgurite cluster is half a tile wide and stops a body; a blister is 0
	# because it is SHELTER — a body steps into it, and what the step costs is a
	# hazard row, not a wall; a car sunk to its sills is still a car's length
	# (VEHICLE is 0.8 and this one lies longer in its pool); a strike rod is a
	# mast on a guyed foot, no wider than a pole's head.
	0.25, 0.0, 1.0, 0.2,
	# A deck span's ORIGIN IS ITS HIGH END (metropolis.gd), so the one circle a
	# prop gets stops a body at the pier the high end stands on, and the low end
	# lying on the ground seven tiles off is walked over. A lift core is two by
	# two and a shop front three wide, each answered by the circle that fits
	# inside it. A bale is a cube. The gantry is 0: it is a frame six wide that a
	# body walks THROUGH, and its two legs are the same case as a mural wall —
	# whoever places one should hand its legs to `WorldQuery.set_blocks`.
	1.3, 1.0, 1.2, 0.75, 0.0,
	# The drowned city. A stair is 0: it is WALKED DOWN, and what it does to a
	# body is let it into the water and out again (docs/LANDSCAPES.md §5). A
	# tram is five long and answered by the circle at its middle, the frozen
	# hull's case; its ends are waded round. A crowd of piles is a post. A lock
	# gate is three across the canal in one circle, which cannot say so: whoever
	# lays the lock should hand the leaf to `WorldQuery.set_blocks` as circles
	# along it, the way a mural wall is meant to be.
	0.0, 1.2, 0.3, 0.9,
]
