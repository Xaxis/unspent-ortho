# THE HUSH: what haunts the crags (design, cb, 2026-09-26)

The owner's idea 5: "foggy crag land of ancient human ruins, myth and wonder
still there, haunted by a force unknown even to the aliens and the machines."
Today it is only implied (the_crags.gd header, Fen's talk, `survey_bends`, the
roundhouse fragments). Nothing uncanny HAPPENS. This is what would, and who
builds it. Design only; nothing is built until it is agreed.

## Rulings (teammate1, 2026-09-26, the design approved)

- The standoff ENDS: machines hold at a ring's edge until dawn, or until the
  player is out of their sight and past their forget, then go home. A ring is
  a refuge for a night, never a fortress.
- H4's pale grey-green stands: neither a person's warm nor a machine's cold.
- The crags only, on their own rings. Nothing reaches past them.
- H0, H2, H3, H4, H5 are cb's; H1 (the HOLD, and 46_settlements' overwrite of
  `mob_walls`) is the fight builder's; the words are the story-wright's once H1
  lands.

## Status

- **H0 built** (world/hush): `BiomeDef.hush` (the crags declare it; classed LOOK
  in WorldStamp), `HushSites.near/nearest/inside` (windowed: the stones near a
  point, grouped, the centre fitted where their facing lines meet), 23_hush's
  `tour_place "hush_ring"`, tests/core/test_hush_sites.gd, tours/hush.tour.

## Rules every phenomenon keeps

1. **It never explains itself.** No line, fragment, machine read or journal
   entry says what it is, why, or since when. What people say about it is
   what they don't know (Fen: "there's older than them in these stones").
2. **Colour, never load** (STORY.md:76-77). Nothing here gates, advances or
   unlocks anything. No story flag reads it. It never touches the gated
   things: the secret and Hour 63 (no hint of minds merging, of shared
   bandwidth, of "many become one"), Cairn, June, the Echo, WHITETHORN, the
   gates into 2029. It must never look like HALCYON's interference either
   (STORY.md:155): no signal, no glitch, no screen noise, nothing machine.
3. **Nobody knows.** The machines have no file on it: they left the crags out
   of the survey (`survey_bends`) and they will not go near it. The Guest
   does not know it exists. The locals know only that it is older than the
   first lot.
4. **Its places are the crags' OWN rings.** These are the worldgen stone
   circles (`gen_scatter` `stone_circle`: 7-9 real STANDING_STONE props,
   hand-cut, lichened, CUP_RING-carved), in the_crags country only. NEVER the
   `cast_stones` landmark: those are Cairn's cast concrete over coast bunkers
   (UNDER_THE_STONES.md), and nothing here may read as Cairn's.
5. **Deterministic.** Every choice is `Rng.hash01(seed, site, ...)` over the
   world clock and what the player did. No `randf()`. Two runs of one tour
   see the same haunting.
6. **Readable at both cameras.** Each phenomenon has a frame from above AND
   one over the shoulder in its proof tour, or it is sound and is proven by
   the mix.
7. **Rare.** Three rings a landscape (`stone_circles: 3`). Each phenomenon
   is sparse enough that a player can doubt they saw it.

## The phenomena

### H1: the machines will not follow (a real behaviour change)
A machine never steps inside a crags ring (the ring's radius + 1.5). A
machine chasing the player who goes into a ring stops at its edge. It turns
to face the ring and holds there: it will not enter and it will not fire into
it. Its senses read the ring's inside as nothing, as they read hush slate
(items.gd `hush_slate`, "the scanner reads as nothing at all"). It WAITS at
the edge, facing in, for as long as the player stays and it keeps its tether.
Then it gives up and goes home (`flee_home`, calm).
- **Why it reads:** a standoff. Machines ringed outside the stones in the
  fog, facing in, not coming. From above: bodies stopped on a circle. Over
  the shoulder: their optics on you through the stones.
- **Not a free sanctuary:** only three rings, no cover from the dark hazard
  or the cold, no loot, and the machines wait outside. A ring buys time, not
  an escape. Ferals and people are not stopped: only machines are afraid.
- **Hooks:** ring discs APPENDED to `FightSim.mob_walls` for bodies whose
  roster row is a machine (merged with 46_settlements' gates, never
  replacing them; that overwrite needs fixing first). A new mood branch in
  `FightSim._beat` next to the tether check: a chaser whose target is inside
  a ring goes to a HOLD state at the edge (face the ring centre, no attack,
  `lost` still counting), then FLEEING home past its forget time. And
  `Senses` treats a ring's inside as unseen to machines.
- **Test (headless, FightSim):** a runner chasing the hero into a ring stops
  outside radius + 1.5 and never crosses. It holds facing the centre and
  makes no attack while the hero is inside. It goes home after `forget`. A
  feral dog on the same chase does enter. Red first with the rule removed.
- **Owner:** the fight builder (FightSim, Brains, Senses), with the ring data
  from H0. It is the one phenomenon with rules; everything else is look and
  sound.

### H2: the stones stand differently when you look back
Each stone of a crags ring has a few stances: turned 4-14 degrees, a lean of
a few degrees, never moved off its footprint (collision and the walk are
unchanged). The stance a stone SHOULD have is a function of time,
`hash(seed, site, stone, floor(minutes / 25))`. A stone only takes a new
stance while it is off screen (`CameraRig.sees_ground` false for its foot and
head) and the player is within 40 tiles. Seen, it holds whatever it last had.
At most one stone per ring changes at a time. So a player who studies a ring,
walks on and turns back finds one stone not quite where it was.
- **Hooks:** stones are baked into their chunk's props mesh. So the ring's
  stones are drawn by the phenomenon's own nodes (one MeshInstance per stone,
  a stance a transform) and left out of the chunk bake. Or the chunk is
  rebuilt while unseen, which is cheaper to write and dearer to run; choose
  in the slice.
- **Test:** headless: a stone's drawn stance never changes on a frame where
  it is on screen. It changes only after it was unseen through an epoch
  boundary. Same clock and same looks give the same stances. A tour: frame
  a ring, turn away 30 s (`mouse`), turn back, and `same` must FAIL over the
  one stone's crop. That is the proof it moved.
- **Owner:** me (a new system, 23_hush).

### H3: the hush: sound that stops
Inside a ring at dusk and night (and in the day in fog), sometimes the world
goes quiet. The beds, the scatter one-shots and the wind fall to nothing over
1.5 s, hold 4-9 s, and come back. The player's own footsteps and breath are
NOT silenced: they are the only sound left. The fog stops moving while it
lasts (the air's drift held), so it reads at both cameras too.
- **When:** each ring answers `hash(seed, site, day, visit)` < 0.5 on
  entering, once per visit. Deterministic, rare, doubtable.
- **Music:** the stems thin to their quietest, never silent. 75_music's
  no-silence budget (`_watch_silence`) is a rule and stays one.
- **Hooks:** a silence factor into `SoundMix.bed_levels` through
  70_audio `_extra()`, and a World-bus duck beside `set_muffle` that leaves
  the player's own sounds' bus alone. Air: a held drift in the fog layer
  (depth/air.gd).
- **Test:** SoundMix pure: with the factor at 1, every bed level is 0 and
  the player's bus untouched. The system: in a ring, entering on a hash-true
  day raises the factor and it falls back after its hold. A tour: `perf`
  or an audio probe line reads the World bus level down, and a frame pair
  shows the fog held still.
- **Owner:** me (with the audio code's owner told).

### H4: lights in the fog that are nobody's
On crags nights in fog or mist, one to three pale lights stand low in the fog
at 18-30 tiles from the player: far enough to be at the edge of the top
view's frame and deep in the fog over the shoulder. They are steady, not
flickering: not a person's warm unsteady flame and not a machine's cold
ruled beam (LOOK law 2). They are a colour neither uses, a pale grey-green.
Walk toward one and it is always that far. When the fog thins they are gone.
Never closer than 18 tiles, never inside a ring, never on a road.
- **Hooks:** positions `hash(seed, night, i)` along slow paths keyed to the
  player's bearing. Real light lent from 15_lights (`lend`/`take_back`), as
  21_doors does, and a glow in the fog (a `rays()` card or the fog's own
  lit term).
- **Test:** headless: for any player position and night, every light is
  18-30 tiles off, none inside a ring, none in clear weather or by day, and
  the same inputs give the same positions. A tour: a crags night in fog,
  frames from above and over the shoulder; walk toward one 20 s and the
  distance stays within 18-30.
- **Owner:** me.

### H5: the rings answer
At night, a light brought into a ring (a lantern held, a torch, a fire
lit within its stones) is answered. One stone after another round the
circle, the carved cups on the stones take the light and give it back, a
slow pale pulse, and then the ring is dark again. The order around the
circle differs each night and never repeats in a night. It answers once a
night per ring.
- **Hooks:** a short lend of one light at each stone in turn (one or two at
  a time, so the pool is safe), plus the cup-and-ring marks' emission on the
  stone (a per-stone uniform, or the H2 stone nodes' own material).
- **Test:** headless: answer order `hash(seed, site, night)`, a permutation,
  once a night, only for a light inside the ring at night. A tour: night,
  `near` the ring, `press lamp`, frames of the answer at both cameras.
- **Owner:** me.

### H0 (enabling): the rings, named
`HushSites.near(world, query, at, reach)`: the rings of a `BiomeDef.hush`
landscape round a point, from the stones themselves (worldgen turns each
circle's stones to face its centre). Not from `world.landmarks`: that is a
whole-world list and a streamed world may not hold it. Centre, radius and
stone ids, so systems read it and never hard-code a place. `tour_place "hush_ring"` stands a tour at the nearest one.
- **Test:** every crags circle is found; no `cast_stones` site ever is; no
  other landscape's circle is.
- **Owner:** me.

## The words (the story-wright)

Words never explain; they are people and machines NOT knowing.
- **Machine reads**, for a machine held at a ring's edge (capitals, never
  cruel, STORY.md:144). What it says is the absence of a file: of the
  "UNFILED. HOLDING." kind, and never a name for what is there.
- **One witnessed beat, once** (DESIGN.md:107): the first time the player
  watches machines stop at a ring. A person's line later, never at the ring
  (nothing speaks because the player walked onto a tile). Fen is the one
  who would say it.
- **Fen**: a line or two that fit her fears ("that they left it out because
  it is worse than they are"). She has heard the hush, and she will not say
  whether she has seen the lights.
- **A fragment near a ring** (the roundhouse pattern): offerings left at the
  stones by people who don't know what they are feeding. It never says what
  is fed.
- The story-wright checks every line against STORY.md's gates. None may
  touch the secret, HALCYON or Cairn.

## Slices, in order

1. **H0 + H1** (the rings, and the machines' fear): H0 is mine, H1 is the
   fight builder's, with the tests above. Gameplay first, because it changes
   how the crags play. The `mob_walls` overwrite in 46_settlements is fixed
   in the same slice.
2. **H3** (the hush): mine.
3. **H2** (the stones): mine. The node-versus-rebuild choice is made and
   measured here.
4. **H4** (the lights): mine.
5. **H5** (the answer): mine.
6. **Words**: the story-wright, at any point after slice 1 (they need the
   hold state to exist for the machine read).
No slice moves worldgen: the rings already exist. No GEN bump.

## Open questions for the owner / teammate1

- H1 makes a ring a place machines won't enter. Is a standoff (they wait
  outside) the right cost, or should they also leave for good by dawn?
- H4's colour: pale grey-green is proposed as the one light nobody in the
  world makes. The owner's call.
- Should any phenomenon reach past the crags? This design keeps them all to
  the crags' own rings, so the force stays the crags' own.
