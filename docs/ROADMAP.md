# Roadmap

Draft for the owner to reorder (2026-09-23). Where the game stands, and what each
area needs next. `docs/VISION.md` is the destination; history lives in git.

## Where we are

A walkable, lit, generated world: 22 landscapes on five continents, day and night,
weather, villages, machines with keepers and depots, realms and portals, a slate
UI, saves, a web build on Vercel. Recent work has been almost all look, world
generation and world content. The game on top (fighting depth, crafting,
progression, story guidance) is thin.

**Next:** settle the look, then regroup the work by the areas below and change how
it's delegated. That's decided with the owner, not assumed here.

## Decided

- The look is LANTERN (`docs/LOOK.md`): lit, not drawn. Forward+ on desktop,
  Compatibility on the web as the degradation path.
- Keep the held-Z perspective lens. Making it the default is pending a cost
  re-run.
- Every landscape follows `docs/LANDSCAPES.md`'s four layers (plan, land, people,
  player), held by `tests/biome/test_landscape_depth.gd`.
- Content scales with area; the world grows rather than landscapes shrinking.

## Areas

Each area lists its state and its next few points.

### 1. Look and rendering
- State: LANTERN landed. Web night lamps: a fix to choose lamps by what's on
  screen is done on `cb/lamp-pool-frame`, not merged.
- Next: merge the lamp fix. Re-judge the web lamp dimming (0.40) on real-browser
  frames. Owner rulings on the lens default and the sky under the lens (#14).

### 2. World generation
- State: GEN 24 (1840 world, five continents, shares, slums spacing,
  works-search cost) is mostly done on `m3/standing`, not merged.
- Next: re-measure GEN 24 against current main, the parity re-accept, the canon
  sheet reviewed, land it.

### 3. World content
- State: six new landscapes have keepers, machines, props, materials and
  buildings on main. Placing them in the world is done for four on
  `l2/placement`; the drowned city and the mesas are open.
- Next: finish placement after GEN 24. Then the middens, sulphur jungle, grey
  orchards, server fields and machine city, then the first seven raised to the
  same bar.
- Missing shared systems: flying bodies, spanning props (cables), ruled canals,
  time-varying ground, a glass ground.

### 4. Core play
- State: walk, run, crouch, jump, swim, target, dodge and swing, stealth, taking
  from the world, survival needs, gear slots and abilities, crafts.
- Next: to be defined. Fighting depth, crafting that matters, how a first hour
  plays.

### 5. Progression and world systems
- State: keepers (three ways to take each), depots, interference and hunting,
  settlements and raids, realms, the loot economy, all built and mostly untested
  in real play.
- Next: to be defined. How regions unlock and how the long game is paced.

### 6. Story and direction
- State: the spine and words (`docs/STORY.md`), fragments, talks, locals,
  regional asks, the journal.
- Next: to be defined. How the story steers play, forks and endings.

### 7. Menus and controls
- State: the slate and its apps, a title, a character page, settings with
  rebinding, dev mode.
- Next: to be defined. A pass over every menu against real play, onboarding,
  gamepad.

### 8. Audio and score
- State: procedural sounds, per-landscape beds and score, crossfades at borders.
- Next: to be defined.

### 9. Shipping and technical
- State: CI gate on every push, web build proven in CI, Vercel deploys, saves
  with world stamps.
- Next: a verify skill and feature map, memory-safe test runs on this box,
  frame-time budgets on the web.
- Web memory: the tab reserves 1181 MB, because the wasm heap doubles past 592 and an
  1840 world's generation peaks 678 MB over the engine (`WorldGen.last_memory`). Trims
  cannot clear the step (props alone reach 448, the kept world is 260). The options are
  banded tiles, a broader restructure, a smaller web world (owner), or accepting it
  (current: fine on desktop browsers, a risk on phones).

### 10. Feel and balance
- State: nothing systematic.
- Next: regular playtests of the first hour. A read-only critic that grades frames
  against VISION and LOOK (with the owner).

## Open for the owner

- #14 Lens and look rulings (lens on by default, sky under the lens).
- #25 Rotate the Vercel token, which was visible in process listings.
- How work is delegated from here: roles, batch merges, the critic.
