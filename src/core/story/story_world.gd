class_name StoryWorld
## The ONE door the story asks the world a question through (docs/STORY_SYSTEM.md §4).
##
## Kept to one file for two reasons. The story package then has exactly one place
## to change when the world's own contracts move — and they are moving, hard, this
## week — and a content file never asks the world anything directly, which is the
## bug this whole architecture exists to prevent: a fragment that names a bay a
## given world does not have.

## The one landscape a world cannot be without. The player wakes beside a coast
## village and that is a hard requirement of the opening hour.
##
## **IT WAS ONCE GUARANTEED BY THE SPAWN AND NOT BY A `spread` FLOOR, AND THAT
## ENDED ON 2026-09-22.** unspent-ortho-df ruled on 2026-09-18 (`d7de7a7`) that a
## floor would spend a landscape's worth of variety and that "the opening hour
## already pays for this one", so this file answered yes for the coast by name.
## The premise was that `GenSettle.spawn` guarantees HOME a coast. Measured at
## 1300, it did not: on seeds 1 and 42 the home continent grew 0 coast tiles and
## the player woke on another body, because the spawn follows the coast wherever
## it happened to grow. And a floor spends no variety for the one landscape every
## world must already hold. So the coast declares `spread (1, 0)` in its own file
## and the dealer is the single authority, as `guaranteed` below demands.
const COAST := &"coast"


## Whether EVERY world of this realm is guaranteed to contain this landscape, so
## the spine may rest a required beat on it.
##
## One thing guarantees a landscape: the dealer's own floor,
## `BiomeRegistry.guaranteed`, which reads `BiomeDef.spread.x >= 1` and nothing
## else (the coast declares one; see `COAST` above). Do NOT duplicate that
## reading here — the dealer's answer is the authority, or the two drift and the
## gate stops meaning anything. And never ask "is it exclusive?" instead: that is a
## proxy, false exactly when an ordinary landscape is left out of a small world, and
## not a thing the registry knows, so a rule written in terms of it cannot be tested.
##
## `tests/story/test_plan.gd` holds whatever this says yes to against the tiles of
## worlds that were really grown, so a promise here that the world does not keep
## fails the gate rather than a player.
static func guaranteed(land: StringName) -> bool:
	return BiomeRegistry.guaranteed(land)


## How near the old THRESHOLD site a readable thing must stand to be one of its
## own: the platform's mass is three tiles across (`BlackSite.blocks`), and what
## stands on it or moored against it belongs to it.
const PLACE_REACH := 5.0


## Where Elias died and was grown, or Vector2.INF (`BlackSite`, unspent-ortho-df).
static func black_site(world: WorldData) -> Vector2:
	# The Before is the same coast tile for tile, so the site is where it was.
	if world == null or not (world.realm == Realm.SURFACE or world.realm == Realm.ERA):
		return Vector2.INF
	return BlackSite.site(world)


## The story place a point belongs to, or &"": a thing standing there holds that
## place's own words (StoryContent.PLACED), not words dealt by kind.
static func place_of(world: WorldData, p: Vector2) -> StringName:
	var at := black_site(world)
	if at != Vector2.INF and p.distance_to(at) <= PLACE_REACH:
		return StorySlot.BLACK_SITE
	return &""
