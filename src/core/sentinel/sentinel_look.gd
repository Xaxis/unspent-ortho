class_name SentinelLook
extends RefCounted
## Everything a way of beating a sentinel is allowed to read, taken off the
## running game once every half second (44_sentinels) and handed to pure rules.
##
## The ways must be pure to be tested and to be believed, and the fight is full
## of nodes, so this is the seam: the system fills it in, `SentinelWays` judges
## it. Nothing here is invented for the panel — every field is something the
## world already knows.

## Its health, 0..1 of full.
var health := 1.0
## The ground its own body is standing on (Ground), and how long it has been
## standing on that same ground (sim ms). A machine of this weight on ground that
## will not carry it is the land taking it, not the player.
var ground := -1
var ground_ms := 0.0
## The works inside its reach that still stand, and how many stood when it woke:
## the plan feeds its keeper, and a keeper whose feeds are gone stands dark.
var feeds := 0
var feeds_at_first := 0
## Sim ms its feeds have been gone for (INF while it still has one).
var dark_ms := 0.0
## The player's signature reads as one of the machines' own (Body.spoof_until),
## they are inside its guard, and for how long both have been true at once.
var spoofed := false
var inside := false
var spoof_ms := 0.0
## The prop kinds standing within BESIDE tiles of the player, none of them
## depleted: what a way gated on "under a lamp" reads (SentinelWay.beside).
var beside: Array[int] = []
## The craft the player is riding (`CraftRide.kind`), &"" on foot: what a way
## gated on "come to it on the water" reads (SentinelWay.aboard).
var riding: StringName = &""

## How near a standing thing has to be to count as beside the player, in
## tiles. A lamp standard's pool is about this wide, and it is under the light
## that a keeper reads a signet as a crew's.
const BESIDE := 2.0
