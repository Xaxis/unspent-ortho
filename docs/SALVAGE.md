# Salvage: what is taken, and why it costs something

The contract for taking (`use` on the land) and the material economy it feeds.
`DESIGN.md` §Taking says how the key works; this says what the world gives and
why. Decided by the owner's delegation, 2026-10-09: "the things mined are
post-technological refuse", and taking has to play with the rest of the game.

## The premise

It is 2098. A civilisation of nine billion ended sixty years ago and left all of
its metal behind; the machines are taking the land apart for the plan. **Nobody
alive mines rock for metal.** There is more refined iron and copper lying in the
ground than the last people could ever use. What is scarce is a hard edge,
power, working machine parts, and the safety to take any of it.

So the economy is **salvage**, never ore, and its currency is **risk**, not rarity.

## Four rules

1. **All metal is salvage.** No vein, no ore, no smelting. Metal comes out of the
   old world and out of the machines, and every source is drawn as what it is, so
   it can be read from across the land.
2. **Three strata, by risk** (they are also the made / mended / found idioms):
   - **The old world's refuse**, 2020s and 30s: rebar out of broken slabs, cable
     out of split ducts, boards out of drifts of dead appliances, plate turned out
     of tips, coal from a dead power station's tip. Safe, everywhere, low grade.
     It makes the made tier.
   - **The machines' spill**: what they shed, leave and are beaten into: carcasses,
     shed parts along their roads, the spoil heaps beside their works. Fought for
     or taken near working machines. It makes the mended tier and a steel edge.
   - **The plan's stock**: sorted bales, billets, cells, blades on its conveyors
     and racks. Taking it is theft, filed, and brings hunters; it feeds the
     keepers. With a landscape's elite material it makes the best there is.
3. **Taking has a cost you can see**: the clock, the noise (a verb is as loud as
   what it does to metal, and machines hear it), and theft at the plan's works.
   Night, cover and weather change it. Where and when to take is a decision.
4. **Nature is for living**: food, fuel (driftwood, dead wood, peat, coal), fibre
   and stone. A tree gives wood, never metal.

## Working metal is reworking

Nothing is smelted from rock. At a fire, salvage is worked back into stock:
rebar is beaten straight into **iron** bar, cable is burnt out of its sheath for
**copper**, solder is melted off boards for **tin**. Steel today is cemented old
iron (a kiln, charcoal, a night), which is real practice; the destination is
steel cut off the machines themselves.

## The buried old world

Where the land is cut (a cliff's foot, a scree, a gully) the old world shows
through it: the slab of a road deck, a duct's cable, a landfill's drift of boards.
That is why salvage stands at exposed faces and on rock: erosion has opened the
ground the cities were built on. Each form keeps its landscape's colour.

| Kind | What it is | Take | Gives |
|---|---|---|---|
| `REBAR_SLAB` | a broken slab of reinforced concrete, its edge fringed with rusted rebar | break or dig, iron | `rebar` |
| `CABLE_DUCT` | a split duct, loops of armoured cable spilling out | break or dig, steel | `cable` |
| `BOARD_DRIFT` | a slump of dead appliances, circuit boards on edge | break or dig, iron | `boards` |
| `COAL_TIP` | a dead power station's coal tip, a rusted hopper half-buried | break or dig, iron | `coal` |
| `STONE_ORE` | a quarried face, wedge holes ruled across it | break or gather | `stone` |

## In order

- **E1, the old world's refuse** (built): the ore veins became the buried old
  world above, in place; no world grows differently.
- **E2, noise** (built): every take is as loud as its verb (`StealthNoise.ACTS`:
  a hand gathering 4 tiles, a blade 7, turning a heap 9, digging 11, a pick on
  concrete or plate 16), machines hear it through `StealthQuery.hears_noise`, and
  the prompt says "(a machine will hear)" before the press (`Survival.would_be_heard`).
- **E3, carcasses**: a beaten machine leaves a body to strip under threat: its
  plate, its parts, its own material. Kills stop paying scrap by themselves.
- **E4, finds**: a tip, a drift and a ruin can turn up a thing with words on it.
- **E5, machine steel**: a steel edge is ground from a machine's own blade.
