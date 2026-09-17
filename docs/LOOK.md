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
- **"The web is washed out" was not the colour door, and not a missing feature.**
  The first side-by-side of the canon, desktop against the exported web build,
  put every web frame a mean **44 apart** (0..255 per channel) and a stop brighter:
  noon 195 luma against 146. A flat quad came back from Compatibility exactly as
  written, so `sky_linear` was right. It was the LIGHT: a sun that casts is drawn
  by Compatibility in a pass of its own, and turning its shadow ON made the frame
  brighter (169 -> 199; the desktop goes 154 -> 151), because that pass lights the
  ambient and the emission again and the land far harder. Counted back by numbers
  fitted against the desktop's own frames (`CompatTrim`), the canon is **10.6
  apart**. And the web's own stand-in pass was writing the whole frame back every
  frame for nothing, 4.3 luma of lift at a clear noon with no shaft in it.

- **"The moss is one flat teal sheet" was not its washes, and not the night.**
  It was one number: FEN's SPECULAR, 0.68 on a relief of 0.010 — the second most
  specular ground in the game on the flattest — and `world.gdshader` takes a
  level face's normal to exactly vertical, so **every pixel of a bog had one
  identical BRDF response**. That is a flat sheet by construction, and no wash
  could have argued with it: the fen's `ground_mark` had been drawing hummocks,
  black pools and bog cotton the whole time, and a broad sheen was painting over
  all of it with the LIGHT's colour instead of the ground's. Measured at noon on
  seed 7 the fen came back at luma **162** — brighter than coast turf at 100, off
  a wash whose own luma is 58 — with chroma 13. Dropping the specular alone took
  it to 80 and chroma to 25. The bog and the pinewood, the hardest pair in the
  game to tell apart, were **2.61 mean-colour dE** apart, which is to say the
  same colour; they are 7.09 now.
- **And one global night was a real problem, but a third the size the frames
  suggested.** The evidence quoted against it compared a frame of a lit VILLAGE
  (24% under luma 24) with a frame of a bare BOG (92%). Bare against bare, on the
  same seed at 23:00, it is 81% and 95% — a gap worth fixing, not a chasm. The
  number that moved the bog was not the ambient either: scaling only the night
  sky's ambient by 1.45 took its ground from luma 10.5 to **10.9**. A lid over
  your head blocks the MOON as surely as the skyglow, so `BiomeDef.night_sky`
  scales both, and the same 1.45 then moved it to 13.9.

- **And the evening falling off a cliff was not one half hour.** It was TWO
  SCHEDULES doing the same job, which only ever overlapped for forty minutes.
  The tint keys give the day's level up from 16:48 and are flat again by 19:12;
  `Weather.night_fall` — which the sun's handover to the moon and the ambient's
  fall both rode — is still zero at 18:30 and does all of its work by 21:00. So
  from five to half past six almost nothing moved, and from seven to half past
  eight everything did: measured on the coast, half hour by half hour, 3.4, 2.6,
  5.5, 9.8 values and then 22.3, 23.3, 22.8. **Neither could have been reshaped
  on its own, because each is flat exactly where the other is steep.** One curve
  on the tint keys' own shoulders (`SkyLight.day_gone`) spends the same light in
  8.9 to 11.2 values a half hour. Two more hid behind it: the cast shadow stopped
  half an hour before the sunset the same file declares, and the last half hour
  of the evening turned back UP at a village while bare coast stayed flat — the
  light had landed but the TINT had not, and `15_lights.compensate` divides its
  lamp by that tint, so the lamps went on brightening with nothing left to pay
  for them.

Each of those would have been expensive to fix at the symptom and cheap at the
cause. **Look for the floor before repainting the room.**

One more of the same shape, found while fixing the above: **the lantern in the
limestone caves was DEEP RED**, sRGB (1.00, 0.39, 0.00) against the coast's
ochre. Not a grading drift and not the tonemapper. `SkyLight.closed`'s own header
says a roofed realm reads as night to everything the sky writes — and two lines
did not keep it, `last_tint` and `last_energy`, both still read straight off the
clock. `15_lights.compensate` divides its warm lamp by `last_tint` per channel
and subtracts `last_energy` as a black point, so a cave at noon was told the sun
was fully up in blue light, and it took the blue out of the lantern altogether.
The lamp was never wrong and needed no clamp. **When a file states a rule in its
own comments, check every line that should be keeping it.**

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

What the table first said was written before anything existed. This is what the
web build was found to have, by switching each thing off and on inside a running
game and measuring whether the frame moved (`tours/degrade.tour`, `perf features`,
Godot 4.7.2, headless Chromium on Metal). The desktop column is the `high` tier.

| | desktop (Forward+, `high`) | web (Compatibility, `web`) |
|---|---|---|
| sun shadow | real, soft, one orthogonal split | **real, soft** (the sun's angular size moves the web frame too), 2048 atlas, hard filter; its pass counted back by `CompatTrim` |
| moon shadow | faint | the same |
| local lights | many, eight cast | **all light, none cast**: switching every lamp's shadow on does not move the web frame |
| volumetric air | true volumetrics | **none** (does not move the frame); the depth fog takes each landscape's volumetric bank (`air_stand_in`), and screen-space shafts carry a lamp in fog and rain |
| depth fog, bloom, tonemapper, the grade, sky reflections | yes | yes, and each lands differently on display values: counted back by `CompatTrim` |
| ambient occlusion | SSAO | SSAO **does** move the web frame (-3 luma at noon) but is off: its cost is unmeasured, because frame cost does not move with anything on this GPU |
| indirect light | off on `high` | none (SSIL does not move the frame) |
| near depth of field | yes | **none** (does not move the frame); the shaft pass blurs what is nearer than the same focal plane (`near_stand_in`) |
| antialiasing | MSAA 4x | off; FXAA is refused by the engine on Compatibility |
| foreground layer | 20 pieces | 7 pieces |
| resolution | native | 0.75 (1440x810), chosen from the curve below |
| the feeling | — | **the same place, on a worse night** |

**Render scale, measured.** In headless Chromium with the frame-rate cap taken off,
on this machine's GPU a frame cost 4.2-4.8 ms at noon and 5.1-5.3 ms in rain at
night at every scale from 1.0 to 0.5: nothing to choose between. A GPU that is
bound by the pixels it fills is where the scale matters, so the same curve was
taken on the CPU renderer (SwiftShader), where it is nothing BUT fill: 1336 ms at
1.0, 1000 at 0.85, **720 at 0.75**, 688 at 0.67, 444 at 0.5. 0.75 takes 46% off the
full frame; 0.67 takes a further 4% for a fifth fewer pixels, and 0.5 is 960x540,
back toward the floor this document removed. 0.75 is where the curve stops paying.

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
