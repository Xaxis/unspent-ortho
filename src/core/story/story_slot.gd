class_name StorySlot
extends RefCounted
## A description of a place, not a place (docs/STORY_SYSTEM.md §4).
##
## The story is the only package here with something to say BEFORE the world is
## made, and it must still be true afterwards — on seed 1, on seed 40,000, on a
## continent the player never leaves. So it never names a tile. It says what KIND
## of place it needs and `StoryCasting` binds that to somewhere real.
##
## The precedent is already in the codebase and the story does not invent a second
## way of doing it: `Works.sites`, `Landmarks.sites` and `Portals.in_world` are all
## pure, all derived from the world, none of them saved.
##
## `require` is the whole of load-bearing. True means the spine cannot be finished
## without it, and `StoryPlan.problems` refuses a world that cannot cast it.

## What kind of place a slot may ask for. These are per-REGION features on
## purpose: every continent has them whatever landscapes it drew, so a spine built
## out of them cannot be dealt out of a world. Building one out of LANDSCAPES
## cannot promise that — `docs/WORLD.md` makes a landscape exclusive to one
## continent, and `GenCountries.fit_types` could already leave one out of a small
## world before continents existed (unspent-ortho-df, 2026-09-18).
const VILLAGE := &"village"
const WORKS := &"works"
const LANDMARK := &"landmark"
const PORTAL := &"portal"
## The one exception to per-region: the old THRESHOLD site, ONE per world, in the
## sea off the home coast (`BlackSite`, unspent-ortho-df). Safe to require because
## every world is grown around a coast spawn; a world with no sea off its spawn
## answers Vector2.INF, which casts nothing, so `StoryPlan.problems` names the seed
## rather than the spine trusting it.
const BLACK_SITE := &"black_site"

const NEEDS: Array[StringName] = [VILLAGE, WORKS, LANDMARK, PORTAL, BLACK_SITE]

var id: StringName = &""
var needs: StringName = VILLAGE
## For LANDMARK: which kind of landmark, or &"" for any of them.
var kind: StringName = &""
## A landscape id, or &"" for any. A REQUIRED slot may only name one the world
## guarantees — `StoryWorld.guaranteed`, enforced by `StoryPlan.problems`.
var land: StringName = &""
var realm: StringName = &"surface"
## Which leg of the journey this belongs to: 0 is the body Elias wakes on, 1 the
## next one out, and so on (`StoryJourney`). The story spans every continent in
## order, so a slot names its leg and never a continent.
var leg := 0
## Take the candidate nearest the spawn instead of dealing one by hash: `home` is
## the village he wakes beside, where Maren keeps the fire, not any coast village.
var nearest := false
## Tiles clear of the spawn (on the home leg), and of every slot cast before this
## one on the same body, so a thread the player is meant to walk to is not three
## paces from the fire. Never measured across water: a distance cannot say whether
## two places share land (`WorldData.same_body`).
var apart := 0.0
## LOAD, not colour. The spine needs it; a world that cannot cast it is a content
## error caught in the gate.
var require := false


static func make(d: Dictionary) -> StorySlot:
	var s := StorySlot.new()
	s.id = StringName(str(d.get("id", &"")))
	s.needs = StringName(str(d.get("needs", VILLAGE)))
	s.kind = StringName(str(d.get("kind", &"")))
	s.land = StringName(str(d.get("land", &"")))
	s.realm = StringName(str(d.get("realm", &"surface")))
	s.leg = int(d.get("leg", 0))
	s.nearest = bool(d.get("nearest", false))
	s.apart = float(d.get("apart", 0.0))
	s.require = bool(d.get("require", false))
	return s
