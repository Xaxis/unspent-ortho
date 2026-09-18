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

`WorldData.region`'s own comment already records this lesson being learnt once:
it is an int array and not bytes because *"a byte would silently alias the tail of
them onto each other's ids"*.

## 4. Exclusivity: the continent is dealt a type set

Exclusivity is **a property of the deal, not a filter bolted onto the registry**.
The stage hands each body the list of types that may appear on it; `GenCountries`
then balances shares across *that list* and that body's land.

What a landscape declares, on `BiomeDef`:

- **`spread`** — how many bodies of a realm it may appear on. `0` = anywhere
  (the default, what every type does today), `1` = exclusive to one continent,
  `n` = at most n. This is the whole of exclusivity from a content author's side.
- Existing fields keep their meaning but change their frame of reference:
  `share` normalises across **the types dealt to this body**, `anchors` are
  positions within **this body's** bounds, `adjacency` is read against sites on
  **this body**.

**`temp_range` / `moist_range` need splitting deliberately and this is not yet
decided (§8).** Latitude is a property of the world — a continent near the pole
should be cold — while continentality (distance from that body's own shore) is a
property of the body. Today both come from "the island's own latitude and
continentality". Getting this wrong makes every continent a copy of the others
with different names, which defeats the point of the request.

## 5. Continents compose WITH realms, not under them

A world is already one realm's world: `GenContext` lays only the types whose
`BiomeDef.realms` names `WorldData.realm`, each realm's world is grown from the
game's seed with that realm's own salt (`Realm.seed_for`, `RealmWorlds`), and
`BootWorld.world(seed, size, realm)` is the only door.

**The underground inherits the surface's body layout.** `Portals` lays one shaft
per REGION and pairs them **by index** across the two worlds. If the underground
generated its own unrelated continents, a shaft would stop being a hole in the
ground and become a teleport between unrelated places — and the pairing, which is
the thing that makes a shaft legible, would mean nothing. So the underground is
generated with the surface's footprints as its input, and fills them with cavern
systems and its own type set.

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

## 8. Not decided, deliberately

These want answering before code, and one of them wants the owner:

1. **Climate.** How `temp_range` / `moist_range` split between world latitude and
   per-body continentality (§4). The difference between continents that feel
   like different parts of a planet and continents that are reskins.
2. **How many bodies, and how much ocean.** `GenShape.LAND_SHARE` is 0.47 of the
   square today. Two continents at 0.47 total is a very different world from two
   at 0.47 *each*, and it decides how much of the game is crossing water.
3. **Whether the spawn continent is special.** The journey runs south to north on
   one island today, and `GenSettle.spawn` puts the player beside a coast village.
4. **What a region id means across bodies.** `WorldData.region` keys sentinels,
   works and saves. Ids must stay unique across the whole world, not per body.

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
