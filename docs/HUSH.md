# THE HUSH: what haunts the crags

Contract for the built haunting of the crags' stone circles (H0-H5, `src/systems/23_hush.gd`, `src/core/hush.gd`, `src/core/hush_sites.gd`).

The owner's idea 5: "foggy crag land of ancient human ruins, myth and wonder
still there, haunted by a force unknown even to the aliens and the machines."

## Rulings (teammate1, 2026-09-26, the design approved)

- The standoff ENDS: machines hold at a ring's edge until dawn, or until the
  player is out of their sight and past their forget, then go home. A ring is
  a refuge for a night, never a fortress.
- H4's pale grey-green stands: neither a person's warm nor a machine's cold.
- The crags only, on their own rings. Nothing reaches past them.
- H0, H2, H3, H4, H5 are cb's; H1 (the HOLD, and 46_settlements' overwrite of
  `mob_walls`) is the fight builder's; the words are the story-wright's once H1
  lands.

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

### H0: the rings, named
`HushSites.near/nearest/inside` finds a `BiomeDef.hush` landscape's rings round a point from
the stones themselves (centre where their facing lines meet), windowed, never from the
whole-world `world.landmarks`. A ring's id is its lowest stone's prop id; `BiomeDef.hush` is
LOOK in WorldStamp. Every crags circle is found; no `cast_stones` site and no other
landscape's circle ever is; with no hush landscape in reach no props are walked.

### H1: the machines will not follow
- A machine never steps inside a ring (radius + 1.5): `FightSim.hush_walls`, machines only,
  a list of its own beside the gates' `mob_walls`, so neither writer wipes the other.
- A chaser whose target goes into a ring HOLDS at the edge (MobState, Brains `_hold`):
  facing in, no attack, no fire into it, `lost` still counting. Its senses read the ring's
  inside as nothing, as they read hush slate.
- It goes home (`flee_home`, calm) at dawn, or once the player is out of its sight and past
  its forget (the ruling).
- Ferals and people are not stopped: only machines are afraid.
- A ring buys time, not an escape: no cover from the dark or the cold, no loot.
- Proof: `tools/test.sh test_hush_hold`, `tours/hush_hold.tour`.

### H2: the stones stand differently when you look back
- `Hush.turned`: one stone a ring an epoch (`floor(minutes / 25)`), turned 9-18 degrees
  (under 9 reads as nothing from above), never off its footprint, so collision and the walk
  are unchanged.
- A stone turns only while off screen (`CameraRig.sees_ground` false for foot and head) and
  the player within 40 tiles; seen, it holds its stance.
- `WorldData.turn_prop`; the chunk's props rebake on a worker, only the swap on the main
  thread (`WorldView.refresh_props_soon`).
- Proof: `tools/test.sh test_hush,test_props_rebake`, `tours/hush-stones.tour`.

### H3: the hush, sound that stops
- Inside a ring at dusk and night (and by day in fog), on entering, once per visit, when
  `hash(seed, site, day, visit)` < 0.5: the beds, the scatter one-shots and the wind fall to
  nothing over 1.5 s, hold 4-9 s, and come back.
- The player's own footsteps and breath are NOT silenced: they are the only sound left.
- 23_hush's `quiet` (group `&"hush"`) is read by 70_audio and 10_sky (wind, sway and fog
  drift hold), so it reads at both cameras.
- **Music** only thins, never silent: 75_music's no-silence budget (`_watch_silence`) is a
  rule and stays one.
- `--hush=always` stages it. Proof: `tools/test.sh test_hush`, `tours/hush-quiet.tour`.

### H4: lights in the fog that are nobody's
- `Hush.nobody`: one to three pale lights, low in the fog, 11-20 tiles from the player,
  drifting round a night at a time; walk toward one and it is always that far.
- Only on a hush landscape's nights in fog or mist; gone when it thins. Never inside a ring,
  never on a road.
- Steady, not flickering: a four-stroke star (`rays`), pale grey-green, a colour neither a
  person's warm flame nor a machine's cold beam uses (LOOK law 2); lent from 15_lights.
- Proof: `tools/test.sh test_hush`, `tours/hush-lights.tour` (`near nobodys_light`).

### H5: the rings answer
- `Hush.may_answer / answer_order / answering`: at night, a light brought into a ring (the
  lamp lit, a fire lit within its stones) is answered once a night per ring: round every
  stone in the night's own order (a permutation that never repeats in a night), 0.9 s a
  stone, the carved cups taking the light and giving it back as a slow pale pulse.
- One lent light walks the pulse, so the light pool is safe.
- Proof: `tools/test.sh test_hush`, `tours/hush-answer.tour` (`await ring_answering` /
  `ring_answered`, `near ring_answer`).

## The words (the story-wright)

Words never explain; they are people and machines NOT knowing. Every line is checked
against STORY.md's gates; none may touch the secret, HALCYON or Cairn.
- **Machine reads** for a machine held at a ring's edge (capitals, never cruel,
  STORY.md:144): the absence of a file, of the "UNFILED. HOLDING." kind, never a name for
  what is there.
- **One witnessed beat, once** (DESIGN.md §Story delivery): the first time the player watches
  machines stop at a ring (49_story). A person's line later, never at the ring. Fen is the
  one who would say it.
- **Fen:** a line or two that fit her fears ("that they left it out because it is worse
  than they are"). She has heard the hush, and will not say whether she has seen the lights.
- **A fragment near a ring:** offerings left at the stones by people who don't know what
  they are feeding. It never says what is fed.

No phenomenon moves worldgen: the rings already exist.
