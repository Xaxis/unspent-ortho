# UNSPENT — design

What the game is, in the order decisions get made. Mechanics numbers live in
`docs/research/design-extract.md` (from the old game's content and engine);
the look in `docs/research/art-audio-extract.md`. Those are a **floor**, not a
ceiling: the job is a better game, not a port.

## Pillars

1. **The world is the game.** One generated coast per seed, big enough to be a
   journey, every country different enough that crossing into it is an event.
2. **Real-time, readable, Zelda-grade action.** Two verbs in a fight: swing, and get
   out of the way. You read a machine's body and find the side that is still
   working. No menus and no numbers of its own accord: the fight says nothing in
   words unless the player asks it to, by holding the target key (§Targeting).
3. **Survival and making are a pillar, not a layer.** You mine, fell, gather, make
   tools out of beaten machines, and reach further. Every hand tool is the best
   thing a person can still make and mend.
4. **The machines are predators, barely functioning.** They kill, take hold, carry
   people off to work, and file what they see. Their failures are the only reason
   anyone is alive; the gaps in their coverage are where you live.
5. **Beautiful, and changing as you travel.** The landscape evolves: grass thins into
   heath, heath into limestone, pines into snow, moss into black water, ash drifts
   over the southern rim. Light, weather, sound and machines change with it.

## Targeting (owner, 2026-09-16)

The slate can be put on a body. It is asked for and never imposed, it is never
required to fight, and it changes nothing in the simulation: no aim, no slow, no
hold. What it gives is perspective and knowledge.

- **Hold `z`.** The nearest threat is locked: the camera leans in behind the
  player (a little yaw toward the body, a lower pitch, closer in, the frame
  biased between the two), the body is bracketed with a ring on the ground it
  stands on, and the slate reads it.
- **`a` / `d` cycle** the lock along the list — what is on you first, then what
  is near (`Targeting.threat`), and the last people after everything in the fight.
- **`r` sweeps the field**: the camera stands back instead, nothing is locked,
  and the field is read in short, eight at a time; `a` / `d` page a field bigger
  than that, and the panel says which page of how many it is showing.
- **Let go** and the camera comes back square and the reads go with it.

**Anything the player can look at can be read**, not only what is in the fight.
A villager is a subject like a machine (`TargetSubject`), and reads as a person:
no health, no signature, no working part — their trade, their village, and what
they are doing. Nothing invents a life bar for somebody the simulation never
gave one. A works, a station, a sentinel become readable by getting a `from_*`
on that subject, and the order, the camera and the drawing follow unchanged.

**A lock waits.** A body that steps behind a house or a stride past the reach is
held for `Targeting.LOST_GRACE` before the lock takes anything else: a machine
that was there half a second ago is the same machine, and a lock that flicks to
its neighbour is a lock nobody trusts.

**Every body in the fight carries a wordless tag at all times** — health in pips
and one glyph for how far it has got with the player (nothing, stirring, sure,
coming). People carry none: nothing has noticed them and no number measures their
life, so pips over a villager would be a reading nobody took.
That is the part that is always true of every enemy on screen; the words are
the part the player asks for. This is what turned the old ruling round: a fight
may now be read in words, but only while the key is held.

What the read says is the simulation's own: health and the roster's numbers, its
powers (only what its row declares), what it has noticed (`StealthQuery`, the one
door) and what it is thinking (its mood, its blow's phase, its place in the plan).
Nothing is invented for the panel.

## Crafts (docs/VISION.md §5)

A craft is a thing a person builds out of machine parts and then stands on. It
opens ground a body cannot cross, it is a thing in the world when it is parked,
and it can be worn out, broken under you, and lost.

- **`b` is the whole verb.** Standing at a craft it boards it; carrying one it
  puts it down and steps on; standing on one it steps off; at a wreck it strips
  it for its parts. Nothing about a craft is a menu.
- **The three.** A **raft** (made by hand at the shore: driftwood, a rag and one
  drum off a wreck) crosses open water nobody can wade. A **hover sled** (mended,
  at a bench) runs bog, salt, ice, black water and everything else at half again
  a walking pace. A **walker rig** (mended, at a bench) strides a two-level step
  — a cliff to a body — and takes scree and deep snow under a load.
- **It is not a second movement system.** The fight simulation still moves the
  player: a craft only changes what the ground under the body means (`Hero.ride`
  -> `WorldQuery.move_body`) and what pace it allows (`Hero.ground_speed`). So a
  dodge, a grip, a blow and a machine shouldering you aside all land on a deck
  exactly as they land on turf, and being hauled off your raft leaves it adrift.
- **Getting on and off is never a teleport.** A craft is set down, and stepped
  off onto, only within a shove of the body and only along a line the craft
  itself could travel — so a raft is pushed out past the shallows and nosed back
  in, and a body only ever steps off onto ground it could have waded to. Getting
  off is never how a channel is crossed; the craft is.
- **Wear and wreck.** The shallows grind a raft's drums, scree tears at a
  skirt, every cliff costs the rig something, and a blow that lands on the rider
  takes it out of the hull as well. At nothing the craft breaks: whoever was on
  it is put ashore, and what is left of it lies where it broke and can be
  stripped for its materials — except a float wrecked in open water, which sinks,
  because some things are simply lost.
- **Drawn MENDED** (docs/ART.md §12): FOUND drums, pans, pods and legs in violet
  plate with the machines' own amber still lit on them, bound to MADE spars,
  boards and cord, both idioms in one silhouette, and the lashing crossing the
  rivet row is the drawing.

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
| Pressures | what a place puts on a body: cold, heat, fumes, toxins, radiation, wet, dark, vacuum, pressure, EM, resonance, time-shear. A landscape type declares its worst (`BiomeDef.hazards`); the hour, the weather, the height, a roof and a fire decide how much of it is on you now. Felt first (a gauge, breath, a cough), then in the legs, then a slow drain that stops before the last point of health: the weather never kills outright |
| Gear | six slots (head, body, hands, back, tool, craft), each piece with sockets, each module with resistances and sometimes an ability. Three idioms and three tiers: MADE (hand), MENDED (found parts on a made frame), FOUND (taken whole, spends charges, unmendable). Configured on the slate's gear page before a journey |
| Abilities | one interface (id, input action, cooldown, cost in charges or wind, press/hold/passive): dash, glide, scan, grapple, signature spoof. An ability asks for a move and for a mark; the gear system does both, so it never touches a node |

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
