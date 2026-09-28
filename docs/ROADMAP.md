# ROADMAP.md — what we are building now, in order

The current slice and its checklist. Updated in the commit that moves a step.
The destination is `docs/VISION.md`; the story is `docs/STORY.md`.

## How a step is done

A step is done when the **proof tour** (`tours/home-coast.tour`, from the title,
no `--give`/`--folk`/`--beats`) plays through it, its frames are read, the gate is
green and it is on main. Every step carries three threads (owner, 2026-09-28): a
story beat that points at the whole arc, a craft or survival need with a stated
reason, and an introduction (the record's voice; staged beats, never for a time
crossing).

## Slice 1 — thirty minutes on the home coast

Builders: **A** introduction and story (teammate3, words via story-wright) ·
**B** crafting with a reason, and the fight (fight) · **C** stakes and consequence
(teammate2). The owner plays a web build at each ★.

1. [ ] **The wake** (A). Staged in the surf: the black site offshore, Maren at the
   water; the record's first lines; the first sight of the Tether. ★
2. [ ] **Maren's ask becomes the goal** (A). After the pick, the goal line is her
   lead, not a recipe; the guide names why.
3. [ ] **The Tide Reaper, named** (A+B). A person names the yard and its keeper;
   the knife does not bite its plating, so the next make has a reason.
4. [ ] **The Reaper as a set piece** (B). Force and one other way; tells in its
   body; staged reveal and fall. ★
5. [ ] **Its fall changes the coast** (C). The first memory opens; the land shows it.
6. [ ] **The taken** (C, words via A). The motive awaits the owner's ruling in STORY.md.
   Rescue on a clock, or a loss heard in Maren's lines.
7. [ ] **Proof** (all). The proof tour plays the whole slice unassisted. ★

## Fixes that serve the slice

- [ ] The intermittent test hang after `works/test_in_game`'s depot test (blocks gates).
- [ ] Land the fight tuning and gear pass (`land/fight4`, `land/sweep`) once the hang is fixed: step 4 builds on it.
- [ ] The white panel on the player's back over the shoulder. Seen once (main
  c330ea47, `--seed=1 --hour=6.5 --view=shoulder --weather=clear:0`): a tall white
  card with a hit-splash on it, the player in a recoil pose. Not reproduced by the
  same shot three times, by a walk and turn at 06:30, or by a runner's hit over
  the shoulder. Look again if it shows.
- [ ] Web: a 0.8–1.0 s hitch after crowd spawns; a 0.2–0.6 s hitch on the shoulder
  switch in pinewood.

## Parked (decided after slice 1)

Landscape batch 2+3
(`look/batch3`) and batch 4 props (`l2/placement`) · streaming S4j3/S5c
(`land/s4j3`, `world/s5c`) · the crossing programs check and long-walk tour ·
the vent-tender and G10 · walls follow-ups · web frame budgets.

## The whole game, as slices

Each slice is one leg of the journey (`STORY.md`), playable end to end, and adds one
new layer of play with a reason. Rough size: two to three weeks each.

1. **Home coast**: survive and make, for a reason; the first keeper; the first lead;
   the taken. *(now)*
2. **The Holdfast**: Maren's lead to the camp. The holding is built to keep people from
   the depots; raids answer your light; a chapter's way on (explored, mined, defended)
   reads on the land; the next memory gates (the lab at the first works, Ruth's table at
   the camp); the second keeper.
3. **Across the water**: the raft; the Covenant's seat and June; the war's archive;
   mended gear; a third landscape; the first machine enclave that seeks balance
   with humans.
4. **Below**: HALCYON's deep plant; the Seeker and the Echo; the drill crawler; the secret
   takes shape.
5. **The far shore**: the Emissary's works at the Tether's foot; the Guest met in play;
   the climb.
6. **Orbit**: the dead ring, the Foundry, Oksana, the channel; the endings; the After.

## Groups, and what each does per slice

Every group moves in every slice, and only as far as the slice needs.

| Group | Standing direction |
|---|---|
| Story and narration | The slice's beats, leads and lines; the record's voice; wright reviews every line. |
| Survival, making, gear | One new reason to make per slice; gear tiers follow the journey (made → mended → found). |
| Fight and keepers | One keeper per slice, built as a set piece; balance judged by the human reader. |
| Settlements and raids | Introduced in slice 2, for the taken; grows each slice. |
| World and landscapes | Depth only where the slice walks; the parked batches return for the slice that visits them. |
| Realms and time | Memory gates in STORY.md's order (his house in slice 1); the underground in slice 4, orbit in slice 6. |
| Look, light, sound, slate | A quality pass on everything the slice shows: frames read, web budgets held. |
| Tech: web, streaming, speed | Whatever the slice's playtest shows is slow; the web title under 15 s before slice 3. |
| Process and tools | Refined at every slice's end; see below. |

## The loop, per slice

1. **Plan** (a day): the steps in this file; only the owner's own calls go to him.
2. **Build** (about a day per step): one branch per step, preflight, frames read,
   gated, landed; the proof tour grows with it.
3. **Play** (★): the owner plays a web build at each milestone.
4. **Close**: the slice's docs cut to contracts; one retro line on what slowed us,
   turned into a script, check or rule (CLAUDE.md, memory); then the next plan.

## Open for the owner

- Rotate the Vercel token (it was visible in process listings).
