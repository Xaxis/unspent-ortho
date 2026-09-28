# Landscapes, built to depth

The spec a builder follows to give a landscape depth. Decided by the owner's
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

### The Crags (`the_crags.gd`)
- Plan: a survey that never closes. The keeper is the **plumb** (a tripod with a
  swinging weight); ways FORCE, FOUNDER on peat, STARVE. The machine is the **chainman**.
- Still to do:
  - works `&"bench"`, marked `bores`, with theodolite masts, core racks and survey posts
  - site `&"barrow"`
  - landmark `&"broch"`
  - `resonance 0.3` near stones only
- The only-in material, `hush_slate`, still has to reach the world (`player.only_in`),
  and a signature prop still does nothing to a body (`player.signature`).

### The Frost Sea (`frost_sea.gd`)
- Plan: sounding the sea floor through the ice. The keeper is the **listener**; ways
  FORCE, FOUNDER on blackwater, SPOOF. The machine is the **icesaw**.
- No villages and no built forms, on purpose.
- Still to do:
  - works `&"soundings"`, marked `bores`, with sounding rigs, a pipe and a tank
  - site `&"floe_camp"` with a living ice-fisher
  - landmark `&"ice_arch"`
  - pressure ridges laid in lines
  - collapse caused near leads and fresh cuts
  - the icesaw's leads and the listener's cut ring (needs time-varying ground)
  - `deep_ice_lens` reaching the world
  - signature props that act on a body

### The Glass Desert (`glass_desert.gd`)
- Plan: strike fields that call lightning into the sand. The keeper is the **anvil**;
  ways FORCE, FOUNDER on sand, STARVE. The machine is the **skater**, slowed on sand.
- No villages. Its person is a glass-picker at a camp.
- Still to do:
  - works `&"strike_field"`, marked `scorch`, with a grid of strike rods
  - site `&"crater"` and landmark `&"glass_spire"`
  - `Ground.GLASS`
  - `radiation 0.35`, rising to 0.6 in craters and strike fields
  - `fulgurite_core` reaching the world

### The Ruined Metropolis (`ruined_metropolis.gd`)
- Plan: taking the city apart district by district. The keeper is the **unbuilder**
  (a gantry crane); ways FORCE, FOUNDER on grass, SPOOF under a live lamp. The machine
  is the **demolisher**, which chews ruins.
- Still to do:
  - works `&"unbuilding"`, marked `quarry`, with a gantry, sorted bales, a conveyor and a checkpoint
  - site `&"plaza"` and landmark `&"broken_tower"`
  - the kept/left line: lamps where swept, grass and stacks where left
  - vehicles and barricades moved off road ground
  - `tower_cable` reaching the world
- `crossing_keeper` is held for L3.

### The Drowned City (`drowned_city.gd`)
- Plan: the port still runs. The keeper is the **lockkeeper** (a barge on stilts);
  ways FORCE, STARVE, SPOOF from a raft. The machine is the **ferry**, which rams crafts.
- Still to do:
  - works `&"lock"`, marked `cut`, with lock gates, a pump house and tide gauges moved out of scatter
  - site `&"flooded_hall"` and landmark `&"clock_tower"`
  - sea walls brought back
  - `pressure 0.3` in deep water only
  - `brine_copper` reaching the world
  - ruled canals: the streets hold standing water on the city's two lowest levels
    since GEN 33 (`_street`, `_flooded`; 10-14% of the city, 80-86% of its ruins by
    it), level and never over a drop. Channels a raft can run to the sea are still
    the shared system below.

### The Mesas (`mesas.gd`)
- Plan: a ropeway across the canyons. The keeper is the **anchor**, a climber; ways
  FORCE, FOUNDER on sand, STARVE by cutting a span. The machine is the **kite**. Its row
  and model are built, but it is not on the roster until bodies can fly.
- Still to do:
  - works `&"ropeway"`, marked `quarry`, with span pylons and the cable span
  - site `&"cliff_dwelling"` and landmark `&"great_span"`
  - dead trees and boulders on the canyon sand
  - `collapse 0.3` at rims
  - `span_wire` reaching the world
  - signature props that act on a body

### A note on the Snowfield (`snowfield.gd`)
- It grows no grass of its own, and never has: its surface lays snow, rock, gravel,
  shingle, ice and scree, and the grass colour and snow-tuft decor it declares dress
  grass that crosses in from a grassy neighbour's ecotone. So whether a snowfield has
  meadow at all is its neighbours' doing (seed 1's meets the grey orchards: 2,498
  tiles; seed 12's meets none, and `near snow_meadow` finds nothing there). Intended,
  as far as the file's history shows; a grass row of its own would be a decision.

## Shared systems still missing

- **Flying bodies**: drawn at altitude, a tethered orbit brain and a ground shadow. The kite needs it.
- **Spanning props**: a prop between two points (CABLE_SPAN) for its model, collision and culling.
- **Ruled canals**: straight channels between blocks in `GenWater` for the drowned city. It turns `GEN`.
- **Time-varying ground**: saved edits that open and close (leads, cut rings, later the tide), with a chunk refresh and a restamp.
- **A glass ground**: `Ground.GLASS`, appended, with its ground mark in 40..70 decided explicitly.
