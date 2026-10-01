# Landscapes, built to depth

Spec for giving a landscape depth (four layers); built rows are held by `test_landscape_depth`. Decided by the owner's
delegation, 2026-09-22. Change a detail only with a frame or a measurement,
written back here. The words people say belong to the story-wright.

## The rule

Every landscape has four layers. Each one follows from the one before it.

- **PLAN**: what the machines do here. A depot, a keeper and a machine found nowhere else.
- **LAND**: what the plan did to the place. Props, a site and a landmark of its own.
- **PEOPLE**: built forms, a shelter, a trade and a local.
- **PLAYER**: hazards that gear answers, a material only this land gives, and every
  signature prop doing something to a body (cover, shelter, a take, a crossing).

`tests/biome/test_landscape_depth.gd` asks each row of a grown world, not of the file.
`tests/biome/depth_standing.txt` lists what still fails. That list only shrinks.

A keeper takes exactly three ways. FORCE is always one of them.

## Phase A: what exists, what is left

Already in code for all six: the prop kinds (`src/core/prop_kind.gd`) and their Takes
rows, the keeper design (`src/core/sentinel/designs/`), the unique roster kind, the
built forms, the local (`StoryPlan.LOCALS`) and the only-in material with its gear.

Placement (props, works, sites) for the crags, frost sea, glass desert and metropolis
is built on branch `l2/placement`, not yet on main; the drowned city is half done there
and the mesas not started.

Still to do for all six (on main):
- bands that place the new props (`land.own_props`; the crags already pass)
- a `GenWorks.register` works row and its depot props (`plan.depot`, `plan.work_props`)
- the site kind (`land.site`) and a landmark kind of its own (`land.landmark`)
- the pressures listed under each landscape below
- enough frames of land (`land.frames`)

Per landscape, still to do on main:

### The Crags (`the_crags.gd`)
- Plan: a survey that never closes. Keeper the **plumb** (a tripod with a swinging weight):
  FORCE, FOUNDER on peat, STARVE. Machine the **chainman**.
- To do: works `&"bench"` (`bores`: theodolite masts, core racks, survey posts); site
  `&"barrow"`; landmark `&"broch"`; `resonance 0.3` near stones only; `hush_slate` reaching
  the world (`player.only_in`); a signature prop acting on a body (`player.signature`).

### The Frost Sea (`frost_sea.gd`)
- Plan: sounding the sea floor through the ice. Keeper the **listener**: FORCE, FOUNDER on
  blackwater, SPOOF. Machine the **icesaw**. No villages and no built forms, on purpose.
- To do: works `&"soundings"` (`bores`: sounding rigs, a pipe, a tank); site `&"floe_camp"`
  with a living ice-fisher; landmark `&"ice_arch"`; pressure ridges in lines; collapse near
  leads and fresh cuts; the icesaw's leads and the listener's cut ring (time-varying ground);
  `deep_ice_lens` reaching the world; signature props acting on a body.

### The Glass Desert (`glass_desert.gd`)
- Plan: strike fields that call lightning into the sand. Keeper the **anvil**: FORCE,
  FOUNDER on sand, STARVE. Machine the **skater**, slowed on sand. No villages; its person
  is a glass-picker at a camp.
- To do: works `&"strike_field"` (`scorch`: a grid of strike rods); site `&"crater"`;
  landmark `&"glass_spire"`; `Ground.GLASS`; `radiation 0.35`, 0.6 in craters and strike
  fields; `fulgurite_core` reaching the world.

### The Ruined Metropolis (`ruined_metropolis.gd`)
- Plan: taking the city apart district by district. Keeper the **unbuilder** (a gantry
  crane): FORCE, FOUNDER on grass, SPOOF under a live lamp. Machine the **demolisher**, which
  chews ruins. `crossing_keeper` is held for L3.
- To do: works `&"unbuilding"` (`quarry`: gantry, sorted bales, conveyor, checkpoint); site
  `&"plaza"`; landmark `&"broken_tower"`; the kept/left line (lamps where swept, grass and
  stacks where left); vehicles and barricades off road ground; `tower_cable` reaching the
  world.

### The Drowned City (`drowned_city.gd`)
- Plan: the port still runs. Keeper the **lockkeeper** (a barge on stilts): FORCE, STARVE,
  SPOOF from a raft. Machine the **ferry**, which rams crafts.
- To do: works `&"lock"` (`cut`: lock gates, a pump house and tide gauges moved out of
  scatter); site `&"flooded_hall"`; sea walls back; trams in the silt (`brine_copper`
  reaching the world); a slip at the landing; `pressure 0.3` in deep water only; channels a
  raft can run to the sea (the shared ruled canals below).
- Built: it is the LANDFALL (`BiomeDef.LANDFALL`): dealt to the body the shortest water
  from home reaches, its heart where that water comes ashore, so the raft lands in it and it
  is the story's leg 1. Its streets are ruled on the survey bearing, a level to a block
  (`relief.streets`), and hold standing water on its two lowest levels (`_street`,
  `_flooded`), level and never over a drop. Every block keeps its frontage of drowned blocks
  (`DROWNED_SHELL`, eight profiles, sunk to their first floor's sills), the grid goes on into
  the shallows as roofs (`DROWNED_ROOF`), its shore is quays (`relief.quays`), and its
  landmark `&"clock_tower"` stands over it all, stopped at ten past four.

### The Mesas (`mesas.gd`)
- Plan: a ropeway across the canyons. Keeper the **anchor**, a climber: FORCE, FOUNDER on
  sand, STARVE by cutting a span. Machine the **kite** (row and model built; off the roster
  until bodies can fly).
- To do: works `&"ropeway"` (`quarry`: span pylons and the cable span); site
  `&"cliff_dwelling"`; landmark `&"great_span"`; dead trees and boulders on the canyon sand;
  `collapse 0.3` at rims; `span_wire` reaching the world; signature props acting on a body.

### A note on the Snowfield (`snowfield.gd`)
- It grows no grass of its own: its grass colour and snow-tuft decor dress only grass that
  crosses in from a grassy neighbour's ecotone, so its meadow is its neighbours' doing
  (seed 12's has none, and `near snow_meadow` finds nothing there). A grass row of its own
  would be a decision.

## Shared systems still missing

- **Flying bodies**: drawn at altitude, a tethered orbit brain and a ground shadow. The kite needs it.
- **Spanning props**: a prop between two points (CABLE_SPAN) for its model, collision and culling.
- **Ruled canals**: straight channels between blocks in `GenWater` for the drowned city. It turns `GEN`.
- **Time-varying ground**: saved edits that open and close (leads, cut rings, later the tide), with a chunk refresh and a restamp.
- **A glass ground**: `Ground.GLASS`, appended, with its ground mark in 40..70 decided explicitly.
