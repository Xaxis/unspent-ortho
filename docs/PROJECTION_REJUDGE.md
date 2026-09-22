# Which art conclusions were reached through a lens that cannot show depth

**This document decides nothing.** `docs/LOOK.md` is the direction of record and
`docs/ART.md` is binding; neither is edited here and neither should be until the
owner has ruled. This is a list of conclusions in those two documents that were
reached from ORTHOGRAPHIC frames and are therefore open questions again, with —
for each — the specific thing about an orthographic frame that could have
produced that conclusion falsely, and what would settle it.

It is deliberately short. A list that flags everything is worth nothing, so
there is a section at the end naming the big conclusions that are NOT affected
and why, including several that look geometric and are not.

## The precedent, which is this document's whole justification

LOOK.md already contains the argument for doing this, about a different
instrument (#81, the gallery):

> **The gallery — the surface every model in this project has ever been judged
> on — never set `sky_view.z`** ... "the instrument that was used to decide
> whether models looked right was structurally incapable of showing it, and drew
> a perfectly good picture anyway. It is the widest of the nine because it is not
> a test: **a picture is an instrument too**, and a reviewer looking at one is
> taking a reading."

And it names the consequence it had for the document itself: *"Two of this
document's own sentences were written from those frames and one of them was
wrong (law 1 said 'underside')."* The projection is the same class of thing, one
level up: every frame in the project's history, the gallery included, was taken
through it.

LOOK.md's own rule for this is method 5 in its instrument section: **"ask what
the surface is NOT drawing before you ask whether what it drew is good."**

## The fact the audit rests on, verified rather than quoted

Read off a real `Camera3D` by `tests/render/test_read_reach.gd`, and
re-derived here rather than taken from its header:

    PITCH_DEG 57.0, VIEW_HEIGHT 15.0        (src/render/camera_rig.gd:10,16)
    ahead reach = (half - foot * cos p) / sin p,  half = VIEW_HEIGHT / 2 = 7.5

    foot  0.0  on the ground        8.94 tiles ahead   (the test says "about 8.9")
    foot  5.3  block roof + LIFT    5.50               (the test says 5.5)
    foot 11.3  stack roof           1.60
    foot 17.0  spire roof          -2.10               NEGATIVE

    1 / tan(57 deg) = 0.6494        (LOOK.md law 3 says "0.649 tiles per unit")

Three properties follow, and they are properties of the projection and not of
this game's settings:

1. **No horizon.** A pitched orthographic camera never sees a horizon line, so
   backing away from a tall thing loses its TOP first and its feet last. A
   `spire` at 16.3 units and a `tower` at 14.3 can never stand whole in frame.
2. **No sky in frame.** Following from 1, a pitched ortho frame of open ground
   contains no sky at all. Every whole-frame statistic in LOOK.md was therefore
   taken over ground, lamps and props only.
3. **One view vector for every pixel.** Parallel rays mean `V` is constant across
   the whole frame, and the camera's position along its own view axis cannot move
   a screen position (the test says so in as many words). This has consequences
   for specular and for silhouette that are easy to mistake for material facts.

## Suspect, in descending order of how much rides on them

### 1. "Why twelve directions all felt papery" — the diagnosis is incomplete

> "Because the paper was not a choice any of them made. Every one of them
> inherited a **640x360 buffer and a wash-and-ink pipeline** ... The flatness the
> owner keeps naming is not a grading failure. It is the floor all twelve were
> standing on."

**Concluded:** the floor (resolution + wash/ink) was the cause of "papery", so
removing the floor answers it.

**What could have produced it falsely:** the owner's complaint has three clauses
and the diagnosis answers two. The third is *"not enough embedded parallaxed
layers"* — and **an orthographic camera has no parallax by construction.**
Parallel rays mean depth layers do not move relative to each other as the camera
moves, at any resolution, under any lighting. Raising the floor cannot add it;
LANTERN's law 2 cannot add it. So a named symptom was carried into a diagnosis
that had no mechanism for it, and nothing since has closed that clause.

There is a second, weaker reading worth stating because it is cheap to test:
**an axonometric projection is the projection technical illustration uses.**
"Papery" may be the correct word for a pitched parallel projection, in which case
the twelve directions inherited two floors and only one was removed.

**Not a retraction.** The floor finding was measured and independently true: a
crowd went 31.0 ms to 12.0 ms at nine times the pixels, and the cost was
Compatibility's CPU-side draw submission. That stands. The claim being marked is
only that the list of sufficient causes was closed too early.

**What would settle it:** the twelve directions are gone, but the question is
answerable without them — show the owner one place in both projections and ask
whether "papery" survives the lens. The orchestrator's slums and coast pairs may
already be that evidence.

### 2. Law 3 — "the orthographic camera stays" is an axiom, and it was never tested

> "Not a flat plane seen from above: a place with layers ... **The orthographic
> camera stays — it is the game's grammar — but what it looks at is deep.**"

**Concluded:** thickness can be delivered by putting layers into the world, with
the projection held fixed.

**What could have produced it falsely:** the sentence grants the camera the
status of "grammar" — an aesthetic axiom, not a finding — and then sets out to
buy depth inside it. Every depth cue except occlusion and fog is unavailable
under ortho: no convergence, no diminution with distance, no parallax, no
horizon. So the law's own goal was being pursued with most of the instruments
for it switched off, and the frames used to judge progress could not have shown
success if it had been achieved.

The orchestrator's report that the crowd "was always standing there" is the
predicted result of exactly this: the layers were built, and the projection was
not able to report them.

**What would settle it:** already half-settled by the persp pairs. The open part
is the owner's, because "grammar" is his call and not a measurement.

### 3. `tall_cut` — the cure may be part of the disease

> "a thing of height *h* draws over ground *h/tan(pitch)* — 0.649 tiles per unit
> at the play pitch — further from the eye than it stands, so an occluder is
> always covering ground somebody could be standing on. Three layers keep the
> same promise ... and, since the city, **anything BUILT above 3.0 units**
> (`tall_cut`)."

**Concluded:** tall built geometry must be stippled out so it cannot hide the
player.

**What could have produced it falsely:** the arithmetic is correct and the
document says plainly that it is orthographic arithmetic. Under a lens the
relation changes completely — occlusion depends on the occluder's distance from
the camera, not only on its height — so the rule as stated does not transfer,
and the threshold 3.0 has no meaning under perspective.

**The sharper point:** `tall_cut` (`src/render/world.gdshader:1395`, applied at
:1431) removes the upper part of exactly the buildings that carry a city's
verticality. The orchestrator's ortho slums frame shows "two buildings clipped at
the top edge". Some of that is the frame's top edge; some of it may be this
shader deliberately cutting them. **A cure written for the projection may be
subtracting the thing the projection was already failing to show.**

**What would settle it:** one persp frame of the same slums moment with
`tall_cut` forced off, against the same moment with it on. Cheap, and it needs a
lane. Note the two guards are unaffected and still right either way: the ground
band 40..70 is refused, and no `BiomeForms.PLAIN` form reaches 3.0.

### 4. "'Flat' was not missing layers" — the premise is an ortho measurement

> "The depth fog's two constants had been chosen against the depth range of the
> *loaded chunks*, while **the frame is 9.8 units deep**, so distance had been
> carrying the land about one percent."

**Concluded:** flatness was a fog-constant bug; layers were not missing.

**What could have produced it falsely:** "the frame is 9.8 units deep" is a
property of a parallel projection with a fixed `size`. A perspective frame is as
deep as its far plane — 250 units, per the camera the read-reach test builds. So
the bound that made "distance carries one percent" true is projection-specific,
and the dismissal of "missing layers" was reached inside a 9.8-unit box.

The fog fix itself was real and is not in question. What is in question is the
second half of the sentence, which closed an alternative.

### 5. The fen's "flat teal sheet" — a material conclusion resting on a geometric step

This is the one entry most likely to be waved through as material, and it should
not be.

> "`world.gdshader` takes a level face's normal to exactly vertical, so **every
> pixel of a bog had one identical BRDF response**. That is a flat sheet by
> construction, and no wash could have argued with it"

**What could have produced it falsely:** under ortho, `V` is constant across the
frame. Constant normal + constant view + constant sun = literally one specular
value everywhere, which is what "by construction" means here. **Under perspective
`V` varies per pixel**, so the same surface with the same specular gets a
highlight that moves with the eye — a gradient, not a sheet. The phrase "no wash
could have argued with it" is true only of the projection it was measured in.

**Careful on both sides.** The FIX is probably still right on its own merits: a
bog being the second most specular ground in the game is a material claim and a
dubious one. But every magnitude quoted for it — fen luma 162, down to 80;
chroma 13 to 25; the fen-vs-pinewood distance 2.61 dE to 7.09 — is a whole-frame
statistic taken through the flattening projection, and all of them need
re-measuring before they are quoted again. It is possible that a lens would have
made the sheen read as a wet bog rather than as a flat sheet.

**What would settle it:** the same seed and hour in both projections, with FEN's
specular restored, measured on the bog rather than on the whole frame.

### 6. Every whole-frame night statistic

> "compared a frame of a lit VILLAGE (24% under luma 24) with a frame of a bare
> BOG (92%). Bare against bare, on the same seed at 23:00, it is 81% and 95%"
> ... "scaling only the night sky's ambient by 1.45 took its ground from luma
> 10.5 to **10.9**"

**Concluded:** the night was too dark by a measurable amount, and `night_sky`
scaling both ambient and moon by 1.45 is the size of the fix.

**What could have produced it falsely:** "percentage of pixels under luma 24" is
a whole-frame statistic, and **a pitched ortho frame contains no sky**. A
perspective frame of the same moment contains sky and far land, and at night the
sky is among the brightest things in the picture after lamps. The denominator and
the numerator both change. The 1.45 was fitted against numbers that a lens would
not reproduce.

LOOK.md's own method says this in the general case — *"a whole-frame statistic is
only as good as what is holding the frame still"* and *"measure a claim on its
SUBJECT, not on every pixel"*. The projection is a second way for a whole-frame
statistic to be the wrong question.

**Same flag, lighter:** the evening half-hour series (3.4, 2.6, 5.5, 9.8, then
22.3, 23.3, 22.8) is `frame_level` over ortho frames. **The mechanism survives
untouched** — two schedules, `day_gone` against `Weather.night_fall`, one flat
where the other is steep — because that is a code-structure finding and has
nothing to do with the camera. Only the magnitudes need re-taking.

### 7. "The bar" — six frames, all taken through the lens

> "The four frames the reviews named — the snowfield, the moss bog with its ruled
> pipeline, the stolen-neon shack, the village at dusk — plus the two the search
> produced ... LANTERN has to make all six look like a first draft."

The bar for the whole direction is set by six orthographic pictures. If the
projection is part of what made them look like first drafts, the bar is measuring
the wrong axis. Not a falsification — a note that the yardstick shares the
suspect property.

### 8. ART.md — silhouette and readability are ortho-complete, and stop being so

> §5: "The player and every machine must read against any ground at any hour, at
> the base size"

> §4: "A pine is 3-5 offset, irregular star-shaped tiers, each drooping, never a
> smooth cone."

**Under ortho a thing's screen size does not change with distance**, so
"readable" has one answer per thing and silhouette has one variable: bearing.
That is why `tests/models/test_machines_silhouette.gd` can characterise a machine
by its worst YAW and be complete. Under a lens, distance and position in frame
become variables: a machine forty tiles off is a handful of pixels, and its
silhouette differs at the top of the frame and the bottom.

These conclusions were correct for the projection they were made in. They are
not wrong; they are **scoped**, and the scope was invisible because there was
only ever one projection.

### 9. ART.md — "the flank is most of what is seen"

> "**both light channels are gated on what faces the SKY** ... the flanks, wheels
> and underside keep their mass, and **at the play camera's 57 degrees the flank
> is most of what is seen**."

**What could have produced it falsely:** under ortho every machine in the frame
is seen from the same angle, so "the flank is most of what is seen" is one fact
about one pitch. Under perspective it varies with where the machine sits in
frame — more flank low in the frame, more top surface high in it. The wear-gating
argument, and the instruction **"Do not cap the light channels to restore the
number"**, both rest on that constant.

The underlying law — a machine is a dark mass by day — is a colour/palette claim
and is not affected. Only the geometric justification for the gating is.

### 10. The `sees` numbers are already known to be ortho-scoped

`Landmarks.read_reach` and everything downstream of it (CLAUDE.md's "11-13 tiles
at the play camera") are pure orthographic geometry. The new test already says
so and quantifies the case the function does not cover. Listed here only so that
the rejudge list is complete: any conclusion of the form *"this landmark kind can
be read from far enough away"* is scoped to one projection.

## NOT suspect, and why — do not re-open these

- **The colour-space finding** (`matter_albedo`, Forward+ reads ALBEDO as linear,
  a stop and a half). Measured **on a flat unshaded quad**. No geometry, no
  depth, no camera. Projection-independent.
- **"Faceted was not triangle budgets"** — every normal was a flat face normal,
  fixed by welding under a crease angle. A property of the MESH. If anything a
  lens makes this conclusion stronger, not weaker.
- **The 640x360 performance finding** — a crowd 31.0 ms to 12.0 ms at nine times
  the pixels, the cost being Compatibility's CPU-side draw submission. A timing
  measurement; the camera does not enter it.
- **The web/desktop fit (`CompatTrim`, 44 apart to 10.6).** Both sides are
  captured in the same run and the same projection, and it compares RENDERERS.
  LOOK.md's own rule applies in its favour: *"A difference measured WITHIN one run
  is safe where a difference measured ACROSS runs is not."* Re-shooting in persp
  would move both sides together.
- **The caves' red lantern** (`SkyLight.closed`, `last_tint`/`last_energy` read
  off the clock). A code-path bug found by reading the file against its own
  header. No camera in it.
- **The nine broken instruments.** Latches, crops, a gallery that never set
  `sky_view.z`, a test that allowed 737 pixels in a 658-pixel panel. Instrument
  bugs. (The gallery one is this document's precedent, not its subject.)
- **MADE / FOUND / MENDED, the slate's identity, dystopia-in-content, the
  palette and the machine ramps' packing.** Material, colour and theme. A
  projection cannot make a violet ramp wrong.
- **The four methods.** They are what this audit is made of.

## What this list is worth

Nine of the ten entries are open QUESTIONS, not corrections. Two of them (3 and
5) name a specific, cheap experiment that could be run in a single frame each;
one (1) is the owner's to answer and cannot be measured; the rest are magnitudes
that need re-taking before they are quoted again.

The one structural claim the list does make is this: **LOOK.md diagnosed a
flatness complaint by removing one floor, while a second floor — the projection —
was never on the list of candidates, and could not have been, because every frame
used to look for candidates was taken through it.**
