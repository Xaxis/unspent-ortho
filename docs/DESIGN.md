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

## Settlements (docs/VISION.md §9)

Making does not stop at what a person carries. A **holding** is crafting at world
scale: a roof, a fire, a plot, a wall, and the people who keep them. Everything in
it is something that can be taken away, which is the whole of why building it
matters.

- **`h` is the whole verb.** It opens the holding app on the slate: what can go up
  where the player stands, what each piece wants out of the creel, what the
  holding has already built, and — in the stolen module's violet, because it is
  the machines' reading and not the player's — what the place gives off. A piece
  goes up in front of the player, out of what they are carrying and against the
  world clock. Nothing about a holding is reached any other way.
- **The first piece founds the place.** After that a piece within a walk of the
  centre joins it, and further off starts another. A holding is named plainly and
  its centre creeps as it grows.
- **Twelve pieces, in the six families**: lean-to, hearth, hut, store (shelter);
  plot, catchment (food and water); palisade, plate wall, netting (defence);
  wind spinner, battery stack (power); radio mast (work). What each costs, wears,
  makes and gives away is one row in `StructureKind.ROWS`.
- **A hearth is the game's own campfire.** Laid, it puts a `PropKind.FIRE` in the
  world, so it lights the yard, warms a body, can be slept beside and worked at.
  The holding only records that it has one, what it costs to keep, and that its
  smoke is what gives the place away.
- **A sustainability loop, not a counter.** Power is made by the wind, banked and
  spent; a plot is worked by hands and watered by a catchment or it makes half; a
  store is what stops a surplus going to waste; people eat out of the stores, and
  with nothing to eat they work badly and in the end walk away. Everything
  standing comes apart in the weather, faster where it is the hand's work than
  where it is the machines' plate, and the holding's own people mend the worst of
  it out of the stores. Nothing in it is free to keep.
- **A holding works while the player is away.** It is settled by **catching up**
  from its own timestamp in whole half-hour slices, never by ticking: six hours
  away is twelve steps, a month away is settled forward without being owed. The
  slices are aligned to the clock, so a place looked at every minute and a place
  left alone for a day come out exactly the same.
- **The machines will come for it** (VISION §9.4-7). What a place gives off is
  `Settlement.signature()`: light, noise, smoke, radio, power draw, the FOUND tech
  running inside the walls, and traffic in and out. Each channel takes the loudest
  piece rather than the sum, the hour is inside the answer (a window is nothing at
  noon), and netting takes a little off every channel. A settlement is engaged
  because of what it made, never because of a clock — and the raids package is
  what comes. The two meet on `Settlement` and neither imports the other.
- **Drawn by hands** (docs/ART.md §10): crooked frames, walls of what was to hand,
  thatch with a fringe the wind takes, and machine plate lashed over the gaps with
  the cord crossing the rivet row. A piece leans, patches and weathers by its own
  number, so the same kind built twice is not the same drawing. A spinner turns
  when there is wind in it and a battery burns amber while there is charge, so a
  player reads their own holding from a hillside before opening the slate.

## Swimming (owner, 2026-09-17)

Deep water was a wall to everything without a raft under it. A body that can take
it swims now.

- **What it costs is time and a soaking.** Two fifths of a walk, no running, and
  the wet that any water gives (`Hazards` already answers water with `wet` 1.0
  and a little more cold). Nothing is dropped, no load is refused, nothing
  drowns. That is the owner's ruling, and it is why the rules here are short.
- **What a raft is still for**: speed, a dry creel, and carrying what a swimmer
  cannot be bothered to carry. A crossing the sea can be swum; whether it is
  worth swimming is the player's to judge.
- **Who crosses** is one key on a roster row, `crosses`: `&"swim"` goes in after
  you, `&"fly"` goes over, and absent — which is most of the roster — the
  waterline is where it stops. The dogs swim, the flock and the gulls fly, and
  the dredger swims because it was built to work in water. So swimming away from
  a fight works, and never on everything.
- **Nothing swings from the water.** Not a toll: a blow wants something to push
  against. A dodge still works, because a kick away is the one thing a body in
  water can do.
- **It is the loudest way to travel.** Open water gives no cover and a stroke
  carries further than a footfall, so crossing in the open is a decision.

A swimmer is drawn lying through the surface with the stroke of somebody who was
never taught, and the rings it leaves are what say it is in the water rather than
on it — a figure is drawn over the water whatever its depth (people draw after
the outline pass), so the water cannot cut it yet. That is the one thing about
this that is not finished, and it is in ROADMAP.

## Settings (owner, 2026-09-17)

The slate's own page, reached from the pause menu and from the title: **sound**
(everything, the world, the score — levels against the mix as it was tuned, not
absolutes), **picture** (the window and fullscreen where there is a window, how
far the camera shakes, and whether a struck body flashes), **playing** (crouch
and the slate-on-a-machine as a hold or a press), and **keys** — every action the
game answers to, read off the live input map, each one movable, and `put the keys
back` to undo the lot.

What it is not: a master configuration. Those are the owner's, packed into a
build (docs/DEV.md); these are the player's, kept on their own device. Nothing
here changes what a world is or how hard it presses — a settings page that can
change the game is a settings page that has to be balanced.

Two of them exist because holding a key for minutes is the commonest thing an
accessibility setting is asked to undo, and two because the camera moving and the
screen flashing are the only things in the game that happen to the player rather
than to their body.

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
