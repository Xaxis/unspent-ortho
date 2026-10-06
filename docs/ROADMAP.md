# ROADMAP.md — what we are building now, in order

The current work and its checklist, updated in the commit that moves a step. The
destination is `docs/VISION.md`; the story is `docs/STORY.md`. Finished steps are one
line here; their contracts live in the code's headers and tests.

## How a step is done

A step is done when its slice's **proof tour** plays through it, its frames are read,
the gate is green and it is on main. A slice is closed when the owner has played it (★).
Every step carries three threads (owner, 2026-09-28): a story beat that points at the
whole arc, a craft or survival need with a stated reason, and an introduction (the
record's voice; staged beats, never for a time crossing).

## Now: slices 1-3 to the owner's playtest (★)

None of the three has reached its ★. That comes before new depth (re-plan, 2026-10-05).
The owner plays on this box with `tools/play.sh coast | reaper | holdfast | across`, or on
the web preview that every push to main deploys.

- [x] Slice 1's proof: `home-coast.tour` from the title, frames 01-22 (main 9f7eb08d).
- [ ] Slice 2's proof: `holdfast.tour` holds 01-08 with the gate fix; 09 fails on staging
  (it feeds him after the lab at 23:30, beside a hunter his lit lamp drew).
- [x] Slice 3's proof: `across.tour` by the goal line, frames 01-38.
- [ ] The climb's clock runs at a set-piece rate (a 16-minute climb was 23 game hours),
  with the climb keys and the lamp working on the leg, and nothing below sensing him
  there. In batches 7-8.
- [ ] The web new game: 80-85 s to raise the world against 43-48 on desktop; the title
  under 15 s.
- [ ] ★ The owner plays slices 1-3; his notes become the next plan.

## Slice 1 — the home coast (done but ★)

The wake (the Tether's first sight; one staging call for reveals) · Maren's ask becomes
the goal · the Tide Reaper named (the knife won't bite its plate) · the Reaper as a set
piece (force, and the tide by its lure) · its fall changes the coast · the taken.

## Slice 2 — the Holdfast (proof open, then ★)

Reason to make: the holding's defence. The road to the camp (Rook pays for iron) · the
holding · raids answer attention (light, broken works; a yard's hunters go for the
nearest roof, his own included) · armour and shutters · the lab and Ruth's table
(`gate_lab`, `gate_meet`) · Vera and the way on.
- The second keeper (`second-keeper.tour`): the nearest keeper of another design on a leg
  he can reach, never across water before the raft. Where home holds only the Reaper
  (seeds 1, 7 and 42), the second keeper is the first across the water, in slice 3.

## Slice 3 — across the water (done but ★)

Reason to make: the raft, then gear mended from what the machines leave. The crossing
(130 tiles) · the Covenant's seat · June · the archive (`war_relay` is slice 4's lead) ·
mended gear · the drowned city at the landfall (`test_landfall`,
`test_body_independence`) · the climb to the first enclave (`colossi_climb.tour`; the
walker lead reaches a crater on 12/12 seeds; the tread-folk's holding) · back at the camp.

## Next: slice 4 — Below

HALCYON's deep plant; the Seeker and the Echo; the drill crawler; the secret takes shape.
Planned after the owner's ★ notes on slices 1-3. The parked "ground above ground" work
returns here: `~/Projects/unspent-ortho-archive/above-cost-2026-09-29.bundle`.

## Tools

- [x] The dev slate (T1), the story map (T2), the arc view (T3).
- [ ] T4 editing (after the owner has used T2-T3): story data in a structured file the
  game loads; edits pass the story tests and story-wright.
- [ ] Tours run on main daily: CI has no GPU, so tours rot unseen. `tools/tour-sweep.sh
  --since <yesterday>` plus the proofs, failures routed the same day; the whole set weekly.
- [ ] A world cache on disk, so tours and tests stop regenerating the same seeds.
- [ ] Tours walk with a path: `walkto` holds a straight line, so a proof can't walk a
  freed person home.

## Open fixes

- [ ] A lit machine yard throws a light pool at night, so a dark yard reads at a glance
  (one pool per yard; counts against the web's 7 pool slots).
- [ ] Parked until after the ★: shaped machine bodies that collide as drawn
  (`fix/draws-match-hits`: they moved every keeper fight off its bars), and fight tuning
  under the honest reader.
- [ ] Latent worldgen bugs no main seed hits yet. Each moves seeds, so each gets its own
  GEN and a check that the home coast's keeper stays put:
  - `gen_treads._never` marks water HARD but not the tiles beside it, so a step can hang
    water over a cut (seed 42 at GEN 47, drowned city (1223,756)).
  - `Sentinels.gets_out` passes a lair on 6 clear rays, but `test_keeper_reach` floods
    300 tiles (seed 1's crags lair opened 262 at GEN 47).
- Parked since slice 1: landscape batches 2-4, streaming S4j3/S5c, the vent-tender, web
  frame budgets.

## The whole game, as slices

Each slice is one leg of the journey (`STORY.md`), playable end to end, adding one new
layer of play with a reason.

1. **Home coast**: survive and make, for a reason; the first keeper; the first lead; the taken.
2. **The Holdfast**: the camp, the holding, raids that answer your light, the first memory
   gates, the second keeper.
3. **Across the water**: the raft, the Covenant and June, the archive, mended gear, the
   drowned city, the first machine enclave.
4. **Below**: HALCYON's deep plant; the Seeker and the Echo; the drill crawler.
5. **The far shore**: the Emissary's works at the Tether's foot; the Guest met in play; the climb.
6. **Orbit**: the dead ring, the Foundry, Oksana, the channel; the endings; the After.

| Group | Standing direction |
|---|---|
| Story and narration | The slice's beats, leads and lines; story-wright reviews every line. |
| Survival, making, gear | One new reason to make per slice; gear follows the journey (made → mended → found). |
| Fight and keepers | One keeper per slice, built as a set piece; balance judged by the human reader. |
| Settlements and raids | Grow each slice from slice 2's holding. |
| World and landscapes | Depth only where the slice walks. |
| Realms and time | Memory gates in STORY.md's order; the underground in slice 4, orbit in slice 6. |
| Look, light, sound, slate | A quality pass on everything the slice shows: frames read, web budgets held. |
| Tech | Whatever the slice's playtest shows is slow. |

## The loop, per slice

1. **Plan** (a day): the steps in this file; only the owner's own calls go to him.
2. **Build**: one branch per step, its own tests and preflight; land in batches (one gate
   round per batch, CI on the exact head); the proof tour grows with it.
3. **Play** (★): the owner plays it. Nothing past the slice starts before this.
4. **Close**: docs cut to contracts; one retro line on what slowed us, turned into a
   script, check or rule.

## Open for the owner

- Rotate the Vercel token (it was visible in process listings).
