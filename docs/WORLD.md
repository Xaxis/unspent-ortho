# The shape of a world: oceans, continents, bodies

**Owner, 2026-09-18.** Every generated world holds one or a few large **oceans
separating continents**. Continents carry a well-distributed mixture of
landscapes, and some of the rarer types are **exclusive to particular
continents**. **Underground** worlds exist throughout. **Orbital** worlds exist
too, with their own space landscapes — a captured asteroid, the moon. The system
has to be cohesive and reconfigurable, and to hold up at open-world scale.

`docs/VISION.md` §3 says what a world is MADE of — the landscape types and the
realms. This says what SHAPE it is, and it is the document worldgen answers to.
`docs/DESIGN.md` describes what is built today.

---

## 1. The decision: a stage above `GenShape`, not a bigger `GenShape`

`GenShape` is stage 1 and its own header says what it makes: *"One landmass with
a sea rim on every edge"*, with `ISLET_TILES` sinking anything detached and
bigger than a skerry *"so every country lies on the one walkable island"*.

Making that produce three islands is the smaller-looking change and the wrong
one, because **every stage after it is written against "the island"**:

- `GenCountries.fit_types` sums `c.land` to decide whether a type has room to be
  a place at all, and the balance loop drives every type's share against that one
  total. Across oceans, a share becomes a statement about the archipelago.
- `GenRelief` raises one massif.
- `GenSettle.roads` lays roads between villages, and would want to cross water.
- `GenWorks.bearing` is ONE survey line the machines worked along. Over three
  continents it becomes a bearing for a hemisphere.

None of those would fail loudly. They would keep returning numbers, and the
numbers would quietly be about the wrong thing — which is the same class of bug
as §6 below, at world scale.

**So: a new stage runs FIRST.** It lays the void and the bodies in it, and hands
each body a footprint, a land budget and a set of landscape types. `GenShape` and
everything after it then run **per body, against that body's own totals**, doing
exactly what they do now. A stage that was correct about an island stays correct
about a continent.

## 2. One stage, three configurations

The surface is not a special case. What the stage does is **separate bodies with
something impassable**, and each realm names its own:

| Realm | The void | The bodies | Typical count |
|---|---|---|---|
| surface | ocean | continents | 2–4 |
| underground | solid rock | cavern systems | follows the surface (§5) |
| orbital | vacuum | asteroids, moons, platforms | 3–8, small |

This is what makes the system reconfigurable rather than three generators: the
orbital realm is not "a different world generator", it is the same stage with a
smaller body size, a higher body count, and a type set of space landscapes. A
fourth realm later is a row here, not a package.

The void is not decoration. It is what a craft crosses (`docs/VISION.md` §5) and
what a portal skips, so it must be real ground state, not a gap in the data.

## 3. What is RECORDED, and why that is rule one

**`WorldData.continent`: one id per tile, and `WorldData.continents`: what each
one was dealt** — footprint, land budget, the type set, the climate band it sits
in.

This is the first rule and it is not a preference. Every bug fixed on 2026-09-17
and 18 was the same shape: something outside a stage wanted to know what the
stage had decided, could not ask, and read a nearby value as a stand-in.

- `Ground.ROAD` meant "a road people laid" for the project's whole life, because
  the access stage was the only thing that painted it. The Slums paves its own
  lanes and in one commit **2,786 of seed 1's 5,853 road tiles were roads nobody
  laid**. Fixed by recording the mask (`WorldData.road`).
- A hand-written `HOME` table in a test duplicated what landscapes declare, and
  the moment a second landscape legitimately used a prop the table was a lie.

Continents create three more chances at exactly that: **which continent a tile is
on**, **which continent a type was dealt to**, and **which realm a world is**
(already recorded, `WorldData.realm` — keep it that way). If any of them is
derivable-but-not-recorded, downstream code will infer continent from latitude or
from the ocean mask, and this document will be rewritten in a month with twenty
landscapes instead of eleven.

**Guard the door with a test, not with care.** `tests/render/test_one_writer.gd`
fails when anything but `SkyLight` writes the sky globals, and it caught a real
bypass this week by somebody who knew the rule. `WorldData.continent` wants the
same on the day it lands: one writer, and a test that fails when a second appears.
A rule that is only in a header is a rule until the first hurry.

`WorldData.region`'s own comment already records this lesson being learnt once:
it is an int array and not bytes because *"a byte would silently alias the tail of
them onto each other's ids"*.

## 4. Exclusivity: the continent is dealt a type set

Exclusivity is **a property of the deal, not a filter bolted onto the registry**.
The stage hands each body the list of types that may appear on it; `GenCountries`
then balances shares across *that list* and that body's land.

What a landscape declares, on `BiomeDef`:

- **`spread: Vector2i(least, most)`** — how many bodies of a realm this type must
  and may lie on. `(0, 0)` is the default and means what every type does today:
  anywhere, as many as the balance loop wants, **and it may be absent**.
  `(0, 1)` is "at most one continent, and a world may not have it at all" — the
  rare thing you travel to. **`(1, 0)` is the important one: at least one body
  always carries it.** `(1, 1)` is exactly one, guaranteed and exclusive.

  **`least` exists because the story is a consumer we did not have in mind.** A
  fragment, a talk or a beat keyed to a landscape that a world may not contain is
  unreachable, and a beat gating an arc on one could strand a player who never
  crosses the ocean. The alternative was asking the fiction to be careful — to keep
  arc spines off exclusive landscapes — and careful is a thing that holds until the
  first writer who did not read this file. `least >= 1` makes it safe by
  construction instead, and `BiomeRegistry.always_present(id)` is the question a
  consumer asks rather than inferring it from `share`.

  Landscapes with `least >= 1` are dealt to the HOME continent first (§8.3), which
  is where the game's spine already lives.

  **The dealer fails loudly when the guaranteed set cannot fit**, in
  `BiomeRegistry.problems()` alongside the checks `Landmarks` and `GearEconomy`
  already make: a world that cannot carry everything something depends on is a
  content error, not a runtime surprise. Note this question is not new with
  continents — `fit_types` can already leave a type out of a small world — it is
  only newly ANSWERABLE, and the story is what made it worth answering.
- Existing fields keep their meaning but change their frame of reference:
  `share` normalises across **the types dealt to this body**, `anchors` are
  positions within **this body's** bounds, `adjacency` is read against sites on
  **this body**.

**`spread` is `WorldStamp.TERRAIN`**, because it decides where a type may lie, and
a field added to `BiomeDef` that is in neither list fails `test_world_stamp.gd`.
The deeper half: **the DEAL is part of what a seed makes**, so the stamp has to
cover the dealing rule too — otherwise a save opens onto a world where the
exclusive landscape is on a different continent, which is exactly the class of
silent wrongness `WorldStamp` exists to refuse.

**`temp_range` / `moist_range` split by §4a**, which is what stops every continent
being a copy of the others with different names.

## 4a. Climate: latitude is the world's, continentality is the body's

Today `temperature` and `moisture` both come from the one island's own latitude
and distance from its own shore. Split them:

- **Latitude is GLOBAL.** A body's position down the world square sets the
  temperature band it sits in. The journey already runs south to north and the
  snowfield is northern; a continent laid in the north is a cold continent and one
  laid in the south is a warm one, before a single landscape is chosen.
- **Continentality is PER BODY.** Distance from *that body's own* shore drives
  moisture down and swings temperature wider — a wet, mild coast and a dry, harsh
  interior. This is the gradient that makes a continent feel like a place rather
  than a tile of one, and it must be measured against the body's shore, never the
  world square's edge.
- **Relief modifies locally**, as it already does.
- **And each body is DEALT a climate BAND** — a temperature and moisture offset
  with real spread — which the stage records with everything else it decided.

That third part is what actually stops the reskins, and neither of the first two
gives it to you: if a body's climate is only (latitude here) + (distance from this
body's shore), then **two continents at the same latitude with similar shapes ARE
the same place**, however cleverly the types are dealt. A type's `temp_range` /
`moist_range` is therefore read against `body.band + latitude(tile) +
continentality(tile)`. The polar continent is still cold and its middle is still
dry; the band is what makes two continents at one latitude two places rather than
two draws from the same bag. It is also the one knob worth exposing: "make the
continents more alike" is a single number.

**The reason this is the right split, and not a preference:** it makes exclusivity
partly EMERGENT instead of wholly declared. A landscape whose `temp_range` only
reaches cold can only be dealt to a continent whose band reaches cold, so the rare
thing is rare *because of where its continent lies*, which a player can read off
the world. `spread` (§4) then handles the rest — the types that are rare for
reasons other than climate.

## 4b. Weather: landscape character, a moving front, and a real blend

The owner asks for weather that varies, merges and blends, and is specific to a
landscape at times. Two thirds of that exists and the missing third is the
interesting one.

**What is already right, and stays.** Each landscape declares its own weather
table and mist (`BiomeDef.weather`, `BiomeDef.mist`), and the sky reads it through
`Weather.climate(type_id)`. Spells, fronts over time and the seasons are already
there (`spell_index`, `spell_start`, `day_of`). The burning's ash and the
snowfield's blizzards are properties of those landscapes and should be.

**What is missing: PLACE.** `Weather.at_type(seed, minutes, type_id)` takes no
position. Two regions of the same landscape on opposite sides of the world have
identical weather at the same instant, and no front ever crosses the map. With one
island that was invisible. With oceans between continents it is the difference
between a world and a diagram: **it should be able to be raining on one continent
and clear on another**, and a front should arrive.

So weather gains a place: the body's climate band (§4a) and a front whose phase
depends on where you are, so a spell sweeps across the world instead of switching
everywhere at once.

**What is missing: the BLEND.** The sky reads the weather of the type under the
tile, so today weather changes in one step at a border while the ground either
side of it is carefully crossfaded. **This project already solved that seam once**
— the score crossfades landscapes with equal power on `country2`/`blend`
(`SoundMix.land_share`, and `land_soon` so the next landscape is ready before its
border). Weather should cross the same seam by the same means rather than inventing
a second one: read `country`, `country2` and `blend`, and mix the two readings.
Walking out of the pinewood into the burning should see the rain thin and the ash
thicken across the ecotone, on the same curve the trees and the score already use.

## 5. Continents compose WITH realms, not under them

A world is already one realm's world: `GenContext` lays only the types whose
`BiomeDef.realms` names `WorldData.realm`, each realm's world is grown from the
game's seed with that realm's own salt (`Realm.seed_for`, `RealmWorlds`), and
`BootWorld.world(seed, size, realm)` is the only door.

**The underground inherits the surface's body layout**, for the geographical
reason: **a shaft should come up where it went down.** A hole in the ground that
surfaces under a different continent is not a hole in the ground.

**The Before inherits more than that: it IS the surface.** `docs/STORY.md` rests
on the ruin at spawn being his own town, and `portals.gd`'s header already said an
era gate opens on "the same coordinates in another time" — while `Realm.DEFS[ERA]`
carried a salt of its own, so 2029 grew a different island with a different spawn.
Written down and contradicted by the data, which is §9's rule with the halves
swapped. Two declarations fix it, and both are DATA so a second era is a row and
not a branch:

- **`footprints_of`** — whose body layout this realm takes. The underground's
  hard-coded case in `plan` became this, so neither `plan` nor any caller knows
  which realms share a map.
- **`same_land_as`** — whose LANDSCAPES it lays. The underground does not declare
  it (a cave is not a coast); the era does, because the coast was the coast then
  too. `Realm.land_realm` is the one door, and **both readers of `BiomeDef.realms`
  must ask it** — `BiomeRegistry.land_in` AND `GenContext._init`, which asked
  `d.realms.has(w.realm)` directly and so grew an empty era after `land_in` had
  been fixed.

With `salt: 0` beside them the era is the surface tile for tile: same ground, same
spawn, same regions, same props, same shafts on the same tiles
(`tests/core/test_era.gd`). **That identity is the floor, not the finish** — what
makes it 2029 is what STANDS on it, which is dressing and still to build. And the
exception is the era's alone: `test_each_realm_is_its_own_island_from_one_seed`
now states the collision rule twice, forbidden for a realm that is its own place
and REQUIRED for one that says whose land it lays.

Do NOT lean on the pairing for that argument — it is weaker than it looks.
`Portals.paired` is `all[posmod(id, all.size())]`: **it wraps**, so the moment the
two realms lay different numbers of shafts the pairing is already not one-to-one
(two above and five below means surface shaft 0 is reached from underground 0, 2
and 4). With one island that puts you in the wrong bay. With continents it would
put you under a different landmass, which is the thing this section exists to
prevent. **So the pairing becomes per body: a shaft pairs within its own body, and
wraps only inside it, never across.** The `Portals._lay` fallback ladder — "EVERY
world has a way out of it, or a realm can be generated and never reached" — was
right to exist and has to grow the same way: it is guarded on `out.is_empty()` for
the whole world today, so a body whose regions are all too small would get nothing
because another body had already filled the list. **Per body, or a continent can
be generated and never left.**

**And the inheritance must NOT make one realm's world depend on another's.**
`RealmWorlds._raise(key, seed, size, kind)` builds a realm from (seed, size, kind)
alone, on a worker; `begin()` speculatively raises a realm on a pool thread, and
the no-threads web path raises one inline for "the one frame the shaft costs".
Making the underground need the surface *world* would turn that frame into two
world generations and hold both resident — a hitch becomes a hang, on the web,
where it is hardest to see coming. So the body stage splits in two: **`Bodies.plan(seed, size, realm)` is pure, cheap and deterministic — footprints, budgets, bands, dealt
type sets — and the expensive filling is what `GenShape` and the rest do.** **And `plan` OWNS that rule — the caller never does.** Asking it for the
underground's plan returns the surface's footprints carrying the underground's own
type sets and bands. Putting "the underground asks for the surface's plan" in the
caller would mean every future caller has to know the underground is special, and
the first one that does not gets its own unrelated caverns under somebody else's
continents. That is rule one applied to an API: the rule lives in one place and
nobody can fail to apply it. The dependency is on a plan, not on a world, and
nothing about `RealmWorlds` changes.

**The orbital realm does not inherit anything.** A captured asteroid is not under
a continent. Its bodies are laid freely, and a portal to orbit is a different
kind of crossing from a shaft — which is `docs/VISION.md` §4's business, not
this document's, but it is the reason the two realms are treated differently here.

## 6. There is room: the ceiling, measured

`BiomeRegistry.SLOTS` was 16 and VISION wants 20+. The 16 was not a guess and not
`country2`'s width: `GenCountries._blend` packed the pair of types meeting at a
border as `mini * SLOTS + maxi`, and at 16 the largest pair is `15*16+15 = 255`,
exactly one byte. **A seventeenth type wrapped silently** — no error, no test,
a border reading as a different pair.

That packed pair never leaves the function, and `country`/`country2` are single
indices in byte arrays already carrying 255. So the ceiling was two generation-
time scratch arrays. They are widened and `SLOTS` is 32 (`0838178`), and the
three test seeds generate **bit-identical** `country`, `country2` and `blend`
before and after — no world changed, no save was refused.

So a continent's dealt type set can be genuinely distinct without anyone
budgeting slots, and the same change scales to 255 if it is ever wanted.

## 7. Scale

What must stay O(tiles) and cheap, because a world of continents is bigger than
an island: the per-tile arrays (`country`, `country2`, `blend`, `ground`,
`level`, `continent`). Adding `continent` adds one byte per tile.

What must NOT become O(bodies × tiles): anything that sweeps the whole square per
body. `GenShape` already works at half resolution; the body stage should work
coarser still, because a coastline between continents is read at a much larger
scale than a bay.

Streaming is already solved and does not change: `WorldView` streams chunks on a
worker and the camera shows about 27 x 18 tiles. A continent the player is not on
costs exactly what a distant part of the island costs today — nothing, until it
is walked to. **This is the reason the ocean is real ground and not a gap:** a
crossing has to stream like anything else.

## 8. Decided

These were open when this document was first written. They are engineering calls,
so they are made here rather than asked upward.

1. **Climate** — §4a. Latitude global, continentality per body.
2. **How much ocean, and how many bodies.** `GenShape.LAND_SHARE` (0.47) stays the
   whole WORLD's land budget and is divided among the bodies; it does not become
   0.47 each. A world of two continents therefore has about the land of today's
   island, with a real ocean in it, rather than twice the land and a channel.
   **Body count rises with world size, not on its own**, because a continent that
   cannot hold a mixture of landscapes is a big island with a label: 512 takes two
   bodies, and more only as the square grows. The reason to be strict here is that
   crossing water is a deliberate journey made in a craft (`docs/VISION.md` §5) —
   it should be an act, not the medium the game is played in.
3. **The ocean is no wider than the first craft can survive — MEASURED, and it
   does not bind.** A raft is made in the hand out of strand wood on day one
   (`recipes.gd`: no station, 30 minutes, driftwood and a drum off a wreck) and
   its `grounds` include `DEEP_WATER`, so a crossing is gated behind a beachcomb
   and a cutting edge, which is the right gate and an early one. The worry was
   that an ocean laid wider than a raft survives would silently move that gate to
   a bench, iron and copper, with nothing failing to say so.

   The numbers say otherwise. `44_crafts._carry` takes `hull -= step * wear`, and
   `step` is TILES: a raft is `hull 100` against `wear[DEEP_WATER] 0.08`, so it
   crosses **1250 tiles of open water** before it is gone. Measured between
   continent centres on seed 1 at 1024, the crossings are **25, 51, 74, 108, 275
   and 293 tiles**. The worst of them costs 23 hull of 100.

   **So the width is not a constraint at these sizes and the oceans are not
   graded.** The variety the journey wants — a short first crossing and longer
   ones later — is already there and emergent, an order of magnitude apart from
   narrowest to widest, without anybody placing it. Re-measure this if a raft's
   hull or wear changes, or if the square grows past about 4000 tiles; until then
   there is nothing here to build.

4. **The spawn continent is special, deliberately.** The player wakes on a HOME
   continent that holds the coast, the spawn village and a full starting economy,
   and that is not dealt the harshest or rarest types. The others are destinations:
   reached by craft or portal, allowed to be stranger, harder and thinner. This is
   the same argument as the first hour teaching the game, and it is where "some
   rarer landscapes exclusive to some continents" gets its meaning — the rare ones
   are somewhere you travel TO.
5. **How big a world is, and `k` per body — the number the rest hangs off.**
   `GenContext.k` is "size relative to the 512-tile design world" and the floors
   are computed through it: `min_tiles = maxi(24, REGION_TILES * k * k)`, which is
   QUADRATIC. On a 1024 world `k` is 2 and the smallest thing that counts as a
   place becomes four times what it was — so the small orbital bodies in §2 would
   hold no region at all: no place, no depot, no keeper, no landmark, on a world
   that generated perfectly. **`k` becomes per body**, derived from that body's own
   land against the design world's, so every size-derived floor in worldgen is
   computed against the thing it is being asked about. This is §1's argument
   applied to a single letter, and it threads through more stages than
   `LAND_SHARE` does.
   **The body, not the world, is the unit that stays constant**: a continent should
   hold about what today's island holds, or landscapes stop being legible and
   regions stop qualifying as places. So the world square GROWS with body count
   rather than the bodies shrinking to fit it — roughly `512 * sqrt(bodies)` plus
   the ocean between them.

   **Which makes `size` an OUTPUT of planning, not an input**, and the signature has
   to say so or it is circular: you cannot size the square until you know how many
   bodies, and the bodies are decided in the plan. So it is
   `Bodies.plan(seed, realm, want_size := 0) -> {size, bodies}`, and `BootWorld`
   asks the plan for the size instead of being told it. **How many bodies is the
   REALM's to say** (the table in §2), not a caller's argument and not a function of
   resolution — "one or a few large oceans" is a property of the world, not a
   consequence of how big a square somebody asked for.
   `want_size` is what `--size=` becomes: a ceiling, honoured by reducing the body
   count until each remaining body still holds a legible continent, with a floor of
   one. **This is what keeps the repository working**: every `--size=64` and
   `--size=256` in the tests and tours gets ONE body, which is exactly today's world,
   so every spatial assertion written against one island goes on meaning what it
   meant. The continents appear at the sizes a played world uses.
6. **Region ids are global.** `WorldData.region` is already an int array for
   exactly this reason, and ids continue across bodies rather than restarting;
   each entry in `regions` carries its `continent`. Sentinels, works and saves key
   on `id` and must not learn about bodies to stay correct.

## 8a. Known, measured, and deliberately not fixed

**A skerry can be a region.** `GenCountries` calls a run of land a place at
`REGION_TILES * body_k^2` tiles, and `GenShape` lets detached land up to
`ISLET_TILES` (900) survive as an islet — so an islet between those two numbers
qualifies as a REGION, which is what sentinels, works and saves key on. A keeper
can therefore be assigned to a rock.

Measured on seed 1: **five of twenty-five regions at 512, and five of forty at
1024.** It is the same count at both sizes, so it is not a consequence of the
region floor becoming per-body — it has been true since regions existed.

It is left alone on purpose. Fixing it moves region ids, which sentinels, works
and saves all key on, so it costs a `WorldStamp.GEN` bump and a re-accepted canon
— a real world-shape change, for something nothing currently depends on. The
story session's journey needed "which bodies are worth stopping at" and answered
it the better way, with **a village stands there** rather than with a region
count. When something does depend on it, decide it deliberately rather than
discovering it here.

## 9. Rules this document is built on

Earned the hard way on 2026-09-17 and 18; each has a worked example in the repo.

- **Record what the stage decided.** Never let downstream infer it. (§3)
- **Sample, do not pin.** A property asserted against one seed is a fact about
  one island. Adding a landscape shrinks every share, and the rarest thing falls
  off the pinned world first — four landscapes "failed" at once for painting a
  ground that was still being laid, 98 tiles of it, on the one 192-tile world a
  test happened to generate.
- **An absolute bar in a growing world is a countdown.** `flips < 12` was really
  "this world has about ten landscapes in it". Measure what the property is, then
  assert THAT: counting only the flips away from a three-landscape junction gives
  a bar of zero, which is stricter and never moves.
- **Measure what a fix COSTS, not only what it closes.** A wider fade made the
  seam test pass and cost **40% of the world's blend mass** — passing a test by
  flattening the ecotones the test exists to protect.
- **A clock in the gate is scaled, or it is measuring the laptop.**
- **A correct invariant is not restated when its premise changes, and that is how
  it becomes a lie.** `GenShape._clean` keeping exactly one landmass was not a
  bug — it was the line that MADE "every country lies on the one walkable island"
  true, and it was right for as long as that sentence was. It became wrong the
  moment a world could have two, and it silently deleted three continents out of
  four. The same animal as ART.md's review checklist still asking after a hatch in
  a world with no hatch, and as the wear law naming a model that was thrown away.
  When a premise moves, go and read what was true because of it.
  Three more of it came in with the city, all on 2026-09-18, and they are worth
  listing because not one is a bug anybody wrote: `SkyLight.MAX_LAMPS` is the size
  of the SHADER's packed pool and was also, for the game's whole life, how many
  lights the engine built — so a city could not be lit without overrunning the
  other meaning; `test_houses` held every village to "one stolen light, not a
  street of them", which is the coast's true answer written down as every
  landscape's; and `ForeKinds.ROWS` hangs a 2.1-unit cottage eave over a
  `PropKind.HOUSE`, which was right until a HOUSE could be six storeys.
- **A PROXY IS A PREMISE TOO, and it rots the same way.** `Landmarks.sites` gives
  the region with least room the first word — and measured room as TILES, which
  stands in for room only while a region's places are spread evenly through it.
  Villages, works and solid ground are not spread evenly: pinewood on seed 1 is
  the second biggest region on the island with eleven places a landmark may stand,
  so sorted by tiles it spoke last and took what was left, which was one thing
  worth the walk in a landscape big enough to want crossing twice. The comment
  above that sort said "the one with least room speaks first" the whole time. When
  a rule names the thing it wants, check that the code measures THAT, and not
  something that used to correlate with it.
- **A digest is an instrument too.** Comparing bytes answered exactly the question
  it was asked — *did the world move?* — and was structurally unable to answer the
  one that mattered: *is this one island or four?* Both of the multi-body failures
  passed every test in the repository, and only `tools/map.sh` showed the four arms
  of a single mass. Measure, then look at it.
- **A test that cannot observe the thing it rules is not a test of it.**
  ART.md §4 ("a machine is a dark mass by day") is held by `test_machines_ramps.gd`,
  which reads the PALETTE — so it cannot see `matter_worn`, and when wear began
  lightening machines on the snowfield and the salt the test went on passing.
  Honest, green, and blind in exactly the direction the feature moved. Before
  trusting a law, ask what would fail if it broke.
- **A feature that is silently off looks exactly like a feature that is subtle.**
  `matter_wear()` returns early while `sky_view.z <= 0`, only `SkyLight.set_ground`
  writes it, and the gallery never called it — so LANTERN's first law was switched
  OFF in every model review this project has ever taken, the wave's own included,
  and every one of those reviews read as "the wear is subtle here". It was found by
  forcing the input to white and seeing nothing change. When a thing looks weak,
  prove it is running before you tune it.
