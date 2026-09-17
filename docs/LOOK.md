# UNSPENT — the look: LANTERN

(owner, 2026-09-17, after seeing twelve directions rendered against the same
eighteen places) *"Maybe a combination of grit + noir, but also kinda NONE of
them. No matter what, things look papery — which is not unique. The resolution of
everything is too low, the lights not dynamic enough, not enough embedded
parallaxed layers. I want web to be the graceful degradation case: support the
most advanced Godot features as long as there is a highly usable and beautiful
degradation path that is ALMOST as good. Do another pass — but I want to see ONE
right one, unique and amazing and compelling."*

That is a direction, and this document is it. There is no menu here.

## Why twelve directions all felt papery

Because the paper was not a choice any of them made. Every one of them inherited a
**640x360 buffer and a wash-and-ink pipeline**, so each was a variation *on a
page*: change the ink, change the press, change the pigment, and it is still a
page. The flatness the owner keeps naming is not a grading failure. It is the
floor all twelve were standing on.

So the floor goes.

## LANTERN, in one sentence

**The world is lit, not drawn.** No ink, no wash, no hatch, no paper, no filter of
any kind between the player and the place. Everything the eye reads is geometry,
material and light, at a resolution that can hold detail, in a dark world where a
light is a thing somebody is carrying.

Three laws replace the six that governed the page.

### 1. Matter is honest

A surface is what it is made of, and what has happened to it. Wet slate, rusted
plate, frozen mud, ash, salt crust, bog water, oiled steel, rotten timber, snow
that has thawed once and refrozen. Wear accumulates **by world position**: a
machine standing in a bog rusts along its underside, the same machine on a salt
flat blooms white in its seams, the same machine in the Burning carries soot in
its lee. The land tells you what it has been through by what it is made of, not by
a mark drawn on top of it.

### 2. Light is the author

A real sun that casts, and dozens of local lights that cast: lamps, hearths,
fires, vents, a machine's lens, a relay line, a window with someone behind it.
Volumetric air, so light has shafts and glow and a lamp in rain is a cone. Bounce,
so a fire warms the wall beside it. Wet ground that mirrors. **Night is genuinely
dark**, which is what makes a lantern matter — and the lantern is the game's own
title in miniature.

The one thematic law inside this: **the machines' light is cold, exact, and
ruled** — hard-edged, unwavering, aimed. **A person's light is warm, small, and
unsteady** — it flickers, it gutters, it goes out. That contrast, at full
volumetric fidelity, is the game's signature and no other game has it because no
other game is about this.

### 3. The world has thickness

Not a flat plane seen from above: a place with layers. Things pass between the
camera and the player; fog banks sit *between* planes of the world, not over all
of it; rain and snow fall at several depths; distant land is separated by air
rather than by a haze filter. The orthographic camera stays — it is the game's
grammar — but what it looks at is deep.

## What this costs, said before anyone is surprised

1. **The resolution floor rises.** 640x360 goes. That is the change that makes the
   other two possible, and it invalidates the hatch, the wash, the ink, the paper
   and the whole style core — roughly every shader in `src/render/`.
2. **The slate has to be rebuilt.** `src/ui/` is drawn at whole pixels on a
   640x360 base. It stays a hacked tablet made of salvage — that identity is not
   in question and the owner has ruled on it twice — but it must be drawn
   resolution-independently. *(Done, `slate`: it is drawn in the base's own pixels
   now. The device kept its size on screen and the type came down to two-thirds
   of it, so half again as much fits on the glass; the hand-cut face was kept and
   its cell halved with its diagonal notches filled, rather than replaced by an
   outline face, which would have read as an application and not as a module
   stolen from a machine.)*
3. **The models are too coarse.** Budgets today are ~800 triangles for an animal,
   ~1300 for a person, ~2000 for a machine, all chosen for a 640x360 target. Under
   real light at real resolution they will read as faceted. Geometry budgets rise
   and the procedural builders (`MeshKit`, `src/models/`) gain chamfers, greebles
   and a level of detail they were never asked for.

None of that is a reason not to do it. It is what "holistic re-imagining" means,
and it is cheaper now than after twenty landscapes exist.

## What it actually was, which was not what any of this predicted

Five packages landed and **every one found that the visible symptom was not the
problem.** This is the most useful thing in this document, because it is the
pattern, not a result:

- **"Papery" was not the ink.** It was the 640x360 floor under it, and removing
  that floor made the game **faster** — a crowd went 31.0 ms to 12.0 ms at nine
  times the pixels. The cost was never resolution; it was Compatibility's
  CPU-side draw submission. The whole wave's budget came from that one finding.
- **"Washed out" was not a grading choice.** Forward+ reads `ALBEDO` as linear
  light and encodes the frame itself; Compatibility hands the value to the display
  unchanged — measured on a flat quad, a stop and a half apart. The palette is
  sRGB, so from the moment the floor moved the entire game was lifted and
  flattened, and a green gate never noticed. `matter_albedo()` is the one door now.
- **"Faceted" was not triangle budgets.** **Every normal in the game was a flat
  face normal** — correct under a wash, where ink drew the form and a normal only
  picked a shade band, and catastrophic under a sun. Welding and averaging under a
  crease angle fixed it at zero triangles and zero draw calls.
- **"Flat" was not missing layers.** The depth fog's two constants had been chosen
  against the depth range of the *loaded chunks*, while the frame is 9.8 units
  deep, so distance had been carrying the land about **one percent**.
- **The coarse interface was not only the interface.** Converting it exposed that
  the tag over every *unlocked* machine sat at **1.92:1** over white — over snow at
  noon, the tag was not there — and that one item sketch was rastering **on the
  calling thread** at 586 ms, freezing the game every time the carrying page opened.

Each of those would have been expensive to fix at the symptom and cheap at the
cause. **Look for the floor before repainting the room.**

## Three methods that paid, and are worth reusing

1. **Draw the measurement before guessing.** The harvester's hull had defeated
   four attempts that guessed at it. Drawing its silhouette mask as ASCII showed
   the cause in one look: the hull sat *down between* its track wells with skirts
   closing what was left, so there was no hole at any bearing.
2. **Measure a layer by toggling it inside one run.** `--stats` gave 83 and 63 fps
   for one identical command. Showing and hiding a layer three times within a
   single run and taking the median difference is the only number that survives a
   loaded machine.
3. **Print `UNMEASURED`, never `0.00 ms`.** When the GPU timer returns nothing, a
   number nobody clocked is worse than no number at all.

## Web is the graceful degradation path

**Forward+ is the target. `gl_compatibility` is the fallback, and it must be
almost as good.** Not a different look — the same look, with the expensive parts
approximated:

| | desktop (Forward+) | web (Compatibility) |
|---|---|---|
| sun shadow | real, soft, cascaded | real, one cascade, harder |
| local lights | many, shadow-casting | fewer, the important ones, unshadowed |
| volumetric air | true volumetrics | screen-space shafts and depth fog |
| ambient occlusion | SSAO/SSIL | baked into vertex and material |
| resolution | native | a step down, still well above 640x360 |
| the feeling | — | **the same place, on a worse night** |

Degradation is expressed through the master-configuration system that already
exists (`docs/DEV.md`), as quality tiers, so a build says which one it is and the
web build proves itself in a browser every time.

The test is not "does it run". The test is: **put the two side by side and the web
one should look like the same game, not a diagram of it.**

## The bar

The four frames the reviews named — the snowfield, the moss bog with its ruled
pipeline, the stolen-neon shack, the village at dusk — plus the two the search
produced that beat them: noir's burning at dusk, and bloom-dark's night coast with
its phosphorescent sea. LANTERN has to make all six look like a first draft.
