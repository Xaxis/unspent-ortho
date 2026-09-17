# UNSPENT — the look, and how we are going to find it

(owner, 2026-09-16) *"I'm not happy with the overall look of the entire world...
we need to rework the overall unique look and feel of this game and its holistic
production. Implement the most advanced shaders, dynamic lighting, and effects as
configurable options (in developer mode perhaps). We want to explore various
rendering options for the final thematic look and feel of the game."*

`docs/ART.md` says what the game should look like and stays binding. This says how
we are going to go and find it, because the honest answer is that we do not yet
know which combination gets there, and taste cannot be argued into existence — it
has to be put side by side and looked at.

## What is actually limiting us today

1. **There is no screen-space pass at all.** Six shaders, every one of them
   per-object (`world`, `found`, `outline`, `water`, `sky`, `ink`). Everything the
   eye reads as "the look of a game" — grade, grain, bloom, halation, depth fog,
   light shafts, vignette, dithering, chromatic aberration, a paper fibre over the
   whole frame — lives in a full-screen pass that this project has never had. We
   have been grading inside material shaders, which is why the frame reads flat and
   uniform: every object grades itself and nothing grades the picture.
2. **The renderer is `gl_compatibility`**, which is what makes the web build
   possible. It gives us directional shadows and simple lights and denies us
   volumetric fog, SSAO/SSIL, SDFGI, decals and light projectors.
3. **The lighting is one sun and a list of glints.** `SkyLight` writes a global
   tint once a frame and `15_lights` mirrors a few lights in wet ground. No light
   in this game casts a shadow, and nothing a machine carries lights anything but
   the ground directly under it.

## The fork, stated plainly

| | Compatibility (today) | Forward+ |
|---|---|---|
| Web build at unspent.world | yes | **no** — web is Compatibility only |
| Volumetric fog, light shafts | faked in a screen pass | real |
| Real shadows from lamps, fires, machine lenses | no | yes |
| SSAO / SSIL / SDFGI | no | yes |
| Cost | none | a second look to tune, and the beta loses the browser |

A dual path is possible (Forward+ for the desktop build, Compatibility for the
web) and the configuration system makes it expressible, but it is two looks to
keep in agreement, and two is where drift starts.

## How we choose: the look lab

Not by argument. By putting them next to each other.

1. **A screen-space stack**, every stage a switch and a number, none of them
   hard-coded: grade and LUT, dither and palette quantisation, paper fibre, grain,
   halation and bloom, depth fog, light shafts, vignette, aberration, edge ink.
2. **Every stage configurable in dev mode**, as a `look` group in `ConfigSchema`
   beside `world`, `rules` and `start` — so a look is a named file that can be
   kept, sent, played and put in a build, exactly as a master configuration is.
3. **Named looks**: `plate` (the ink-and-wash notebook we have), and however many
   candidates the exploration produces, each a configuration anyone can boot into.
4. **The canon is the comparison harness.** `tools/canon.sh` already renders the
   same 18 frames every time. The same 18 frames under each candidate look, on one
   contact sheet, is the artefact the decision gets made from — and the owner
   decides, because this is taste and taste is his.

## The rule that governs all of it

ART.md's six laws do not bend for a new effect. Bloom that makes the machines
glow like a phone game, ambient occlusion that turns the hand-drawn ground muddy,
or a grade that drowns the landscapes in one colour are all failures however
advanced the technique. The test is the one the art reviews already use: does the
frame look like a page someone made, and does each landscape still look like
itself?

The bar to beat is the frames the last review named: the snowfield, the moss, the
neon shack at night, and the village at dusk.
