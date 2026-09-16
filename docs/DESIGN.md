# UNSPENT — design

What the game is, in the order decisions get made. Mechanics numbers live in
`docs/research/design-extract.md` (from the old game's content and engine);
the look in `docs/research/art-audio-extract.md`. Those are a **floor**, not a
ceiling: the job is a better game, not a port.

## Pillars

1. **The world is the game.** One generated coast per seed, big enough to be a
   journey, every country different enough that crossing into it is an event.
2. **Real-time, readable, Zelda-grade action.** Two verbs in a fight: swing, and get
   out of the way. No menus, no text, no numbers mid-fight. You read a machine's
   body and find the side that is still working.
3. **Survival and making are a pillar, not a layer.** You mine, fell, gather, make
   tools out of beaten machines, and reach further. Every hand tool is the best
   thing a person can still make and mend.
4. **The machines are predators, barely functioning.** They kill, take hold, carry
   people off to work, and file what they see. Their failures are the only reason
   anyone is alive; the gaps in their coverage are where you live.
5. **Beautiful, and changing as you travel.** The landscape evolves: grass thins into
   heath, heath into limestone, pines into snow, moss into black water, ash drifts
   over the southern rim. Light, weather, sound and machines change with it.

## Owner rulings carried over (mechanics only)

- Combat is SNES-action: fists and feet first; find, then craft, then find rare weapons.
- There is one combat system. No turn-based rows, no verb menus.
- Enemies are regional and varied; each machine has a working part on one side of its
  body, set by its trade; hitting the plate does nothing.
- Nothing speaks because you walked onto a tile; story is unlocked by interacting.
- One clock, the world's, driven by real time (1 world minute per real second by
  default). Walking buys no time. Sleeping, working, being carried off skip time.
- Nothing to do with Bitcoin or money-as-subject.

## The core loop (M1 target)

Wake on the coast → walk, look, gather what the shore gives → find stone and ore in the
rock → a fire and a bench make better tools out of what you took and what you beat →
machines on their rounds: avoid, or fight by finding the working side → night comes
blue and cold, hunger bites, the lamp needs oil → reach the next country with a tool
that can take what grows there.

## Systems (target shape)

| System | Shape |
|---|---|
| Body | health (small gauge, no numbers), wind (dodges), hunger, wet, load; a worn body is slower |
| Fight | continuous, fixed-step; blow boxes with windup/active/recovery; dodge with i-frames; plate side rule; knockback + stun; grip (ensnare) broken by pulling; outcomes: won, away, downed (time lost, no death), carried (a shift of forced work, wake elsewhere) |
| Machines | 12 kinds by country and hour; errand / charge / rush / dart approaches; sight dimmed by dark (a lamp undoes it), hearing not; seen often, met rarely |
| Tools | one hand one tool; the held tool is the work verb and the weapon; edge wears, never breaks; hardness ladder wood < iron < steel < crucible |
| Taking | verbs break/dig/fell/cut/gather/scrape/tap/turn on world props; time costs; some regrow, some are permanent world edits |
| Making | stations fire/bench/kiln (+ wheel/loom); recipes turn scrap from machines into tools; wearable salvage kit (plate, brace, rig, lens, aerial) |
| World | landscape TYPES from the registry (`src/content/biomes/`), composed per seed: Coast, Moss, Pinewood, Snowfield, Bonelands, Burning, Salt Flats, Scrapwood; each seed's world is a set of REGIONS of those types; villages; landmarks; interiors later |

## Story

The premise shape is the owner's (2026-09-15) and lives in **`docs/VISION.md`**: the
few dwindling humans after the machine apocalypse; machines that still mean to end
them, many of them indifferent unless you interfere with their **ultimate plan**; the
plan as the core arc with generative subarcs finished many ways. The words (what the
plan is, who is left, dialogue) are written from nothing in the story milestone.
Never port the old game's fiction, arcs, names or text.

## Look

See **`docs/ART.md`** (binding): the coast as a living field notebook. Flat washes,
inked contours, hatched shade pinned to the world, the hand (MADE) against the
ruler (FOUND), countries with their own wash, hatch, decor, light and weather, and
ecotones between them. Nothing like Minecraft or any voxel game.
