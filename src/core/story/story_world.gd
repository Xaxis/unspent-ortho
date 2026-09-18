class_name StoryWorld
## The ONE door the story asks the world a question through (docs/STORY_SYSTEM.md §4).
##
## Kept to one file for two reasons. The story package then has exactly one place
## to change when the world's own contracts move — and they are moving, hard, this
## week — and a content file never asks the world anything directly, which is the
## bug this whole architecture exists to prevent: a fragment that names a bay a
## given world does not have.

## The one landscape a world cannot be without. The player wakes beside a coast
## village and that is a hard requirement of the opening hour, not a coincidence
## (`GenSettle.spawn`). The worldgen session said this plainly rather than
## inventing a floor for the rest, and was right to: guaranteeing a set of
## landscapes on the spawn continent is exactly the flattening continents exist to
## avoid — "no two worlds are the same map" dies if every home body must carry the
## same six things (unspent-ortho-df, 2026-09-18).
const COAST := &"coast"


## Whether EVERY world of this realm is guaranteed to contain this landscape, so
## the spine may rest a required beat on it.
##
## `BiomeRegistry.guaranteed(id)` is the committed name on the worldgen side and
## reads `BiomeDef.spread.least >= 1` and nothing else (docs/WORLD.md §spread).
## IT HAS NOT SHIPPED: as of 6782828 the design is on main and the source is not —
## that commit is `docs/WORLD.md | 28 +++`, one file, and there is no
## `always_present` or `guaranteed` anywhere in `src/`. Verified, not assumed.
##
## Until it lands this answers false for everything but the coast, which is
## conservative on purpose: nothing is guaranteed, so `StoryPlan.problems` refuses
## to let a required beat rest on a landscape at all and the spine stays on
## per-region features — which is the better spine anyway.
##
## WHEN IT LANDS: replace the body with `return BiomeRegistry.guaranteed(land)`.
## One line, and nothing else in the story package knows the difference. Do NOT
## duplicate the `spread.least` reading here; the dealer's own answer is the
## authority, or the two drift and the gate stops meaning anything.
static func guaranteed(land: StringName) -> bool:
	return land == COAST
