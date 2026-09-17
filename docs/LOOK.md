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
