# STORY_SYSTEM.md — how the story works

`docs/STORY.md` is what the story **is** — the premise, the voice, the cast, the
words. This file is the **machine that carries it**: how authored fiction is laid
over a world nobody authored, and how a player who could go anywhere is
nevertheless led somewhere.

Owner's ruling, 2026-09-18: the story is a system, not a table. It is edited and
managed in dev mode, it interleaves with the landscapes and realms, and a
procedurally generated world must still offer **a general guided path toward
success**.

---

## 1. The problem, stated honestly

Every other package here describes a world that already exists. The story is the
only one that has something to say **before the world is made**, and it must
still be true afterwards — on seed 1, on seed 40,000, in a world whose landscapes
were dealt differently, on a continent the player never leaves.

So the story may never name a place. It names **what kind of place it needs**,
and the world casts it. That one inversion is the whole architecture; everything
below follows from it.

The precedent is already in the codebase and the story should not invent a second
way of doing it: `Works.sites(world)` finds one depot per region, `Landmarks.sites(world)`
sweeps region by region, `Portals` lays one per region — all pure, all derived
from the world, none of them saved. The story casts its slots the same way.

---

## 2. The layers

Strict, and dependency runs **one way only — downward**. A layer may call what is
below it and must never be called by it.

```
  8  AUTHORING     dev mode: cast, arcs, plan, ledger, words        src/dev/pages/
  7  PRESENTATION  the use key, the talk view, the journal          src/systems/49_story.gd, src/ui/
  6  DELIVERY      the five channels a player meets the story on    story_fragments, story_talk, story_ledger
  5  STATE         what has been read, landed, chosen, met          story.gd
  4  PLAN          the guided path: stages, leads, problems()       story_plan.gd              (built)
  3  CASTING       bind a slot to a real place in a real world      story_casting.gd           (built)
  2  DEFS          typed shapes: arc, beat, character, slot         story_slot.gd              (built)
     THE DOOR      the one place the story asks the world anything  story_world.gd             (built)
  1  CONTENT       the words and the cast — data, no logic          src/content/story/
  ---------------------------------------------------------------- the seam
  0  THE WORLD     BiomeRegistry, Landmarks, Works, Portals, folk   (not ours)
```

Layers 2–6 are files in `src/core/story/`, flat, beside the ones already there —
not subdirectories. Moving the existing files would churn their `.uid`s and the
import cache for no gain while three sessions share this tree; group them later if
the package outgrows a flat listing.

**Layer 1 never calls layer 0.** A content file that asks the world a question is
the bug this architecture exists to prevent: it makes the words un-testable, it
makes them seed-dependent, and it is how a fragment ends up naming a bay that a
given world does not have. Content declares; casting resolves.

**Layers 2–5 are pure.** No nodes, no rendering, no input. They run headless, in a
loop, over a hundred seeds, in under a second. That is what makes the guided path
provable rather than hoped for.

---

## 3. Content is discovered, not listed

The project already has the right idiom and the story adopts it wholesale: *a
landscape is one file under `src/content/biomes/`, auto-discovered, sorted by
`order`.* So:

```
src/content/story/
  cast/       one file per character   static func make() -> StoryCharacter
  arcs/       one file per arc         static func make() -> StoryArc
  words/      fragments, grouped by thread rather than by kind
```

Adding a character is adding a file. Nothing is registered by hand, no central
list has to be edited by two sessions at once, and **a merge conflict between two
writers is impossible unless they wrote the same character.** That last point is
not a nicety — this repo runs three sessions at a time.

`StoryRegistry` discovers, sorts, indexes by **id**, and exposes `problems()`.

> **Key to the id, never the index.** `BiomeDef.order` decides landscape indices
> and adding a landscape reorders them; there are eleven now and `docs/VISION.md`
> wants 20+. A story flag that meant *bonelands* and silently becomes *burning*
> is a bug that survives a whole playtest. (unspent-ortho-cb and -df, both
> independently, 2026-09-18.)

---

## 4. Slots — the story's side of the seam

A slot is **a description of a place, not a place.**

```gdscript
StorySlot.make({
    "id":      &"the_fence",
    "needs":   &"works",          # village | works | landmark | portal
    "kind":    &"",               # for a landmark: which kind, &"" = any
    "land":    &"",               # optional landscape id — see the rule below
    "realm":   &"surface",
    "apart":   40.0,              # tiles from the spawn and from other slots
    "require": true,              # LOAD: the spine needs it. false = colour.
})
```

Five kinds of place today. Four are per-region, which is the point (see below).
The fifth, `black_site`, is the one exception: ONE per world, the old THRESHOLD
site in the sea off the home coast (`BlackSite.site`, unspent-ortho-df). It is
safe to require because every world is grown around a coast spawn, and a world
with no sea off its spawn answers `Vector2.INF`, which casts nothing and so is
named by `problems()`. A place in the sea stands on no body, so its candidate
says which coast it belongs to, and casting reports every slot's `body`. `shore`, `holding` and `region` are the obvious next ones and are not
built; add a `needs` only with the `_candidates` branch that answers it and a
test, or `problems()` will call the slot uncastable on every seed.

**The rule that keeps a player from being stranded**, and it is enforced, not
promised:

> A slot with `require: true` may name a landscape **only if it is guaranteed**
> — `StoryWorld.guaranteed(id)`, which delegates to `BiomeRegistry.guaranteed(id)`.
> Every other landscape carries **colour, never load**: a fragment worth finding,
> a character worth meeting, a side thread worth the crossing. Never a required
> beat.

**The predicate is "guaranteed", never "not exclusive", and the difference is the
whole rule.** `spread` is `Vector2i(least, most)`: `(1, 0)` is *guaranteed and
not exclusive*, and it is exactly the kind of landscape the spine may lean on.
Worse, a landscape need not be exclusive to be missing — `GenCountries.fit_types`
could already leave an ordinary landscape out of a small world before continents
existed. "Not exclusive" is therefore a proxy, and it is false in precisely the
case nobody tests: a 192-tile world in somebody's unit test. And "exclusive" is
not a thing the registry knows, so a law written in terms of it cannot be turned
into a test at all. (Both corrections from unspent-ortho-cb and -df, 2026-09-18.)

This came out of `docs/WORLD.md` §`spread`: a world is becoming one or more
continents, and a landscape may lie on only some of them. A beat gating an arc on
such a landscape strands any player who never crosses the ocean. `spread` carries
a floor, `least`, precisely so this question has an answer.

**The test runs in the direction that has never worked before in this repo.** It
fails the day somebody sets a guaranteed landscape's `spread` back to `least = 0`
— so the story's law catches a worldgen change, rather than a player finding it.

**Keep the guaranteed set small.** Every landscape given `least >= 1` is one that
can never be made rare, so a long guaranteed list quietly spends the variety that
continents exist to buy. A spine resting on one landscape that always exists is
more robust than one resting on eight that usually do. Today the spine rests on
exactly one — the **coast**, which the player wakes beside (`GenSettle.spawn`) —
and asks worldgen for no floor at all.

**The safest spine rests on per-REGION features, not on landscapes at all.** Every
continent has villages, a works depot per worked region, landmarks and a portal,
whatever landscapes it drew. A spine built from those cannot be dealt out of a
world.

**Legs, not distances.** The story crosses every continent people live on, in
order (owner, 2026-09-18). A slot names its `leg`; `StoryJourney` orders the
world's inhabited bodies outward from the spawn, and casting puts each slot on its
leg's body or farther out, never nearer home than the slot before it. `apart` is
measured only between places on one body (`WorldData.same_body`), because across
water a slot forty tiles off is not forty tiles away. A body counts only if a
village stands on it: a 1024 world has four continents and forty islets.

---

## 5. Casting — pure, derived, never saved

```gdscript
StoryCasting.cast(world) -> StoryCast     # slot id -> {pos, region, land, site}
```

Pure and deterministic: the same world casts identically every time it is grown,
which is what lets it stay **out of the save**. A save keeps the seed and grows
the world again; if casting were saved it would be a second copy of the truth,
and this game has strong opinions about second copies of the truth.

Casting is one sweep, cheapest question first, and it **fails loudly rather than
silently picking something wrong**. A slot that cannot be filled is a
`StoryPlan.problems()` entry naming the slot, the world and why.

---

## 6. The plan — the guided path

A stage of the spine, and the reason a procedural world can still lead somewhere:

```gdscript
StoryStage.new({
    "id":         &"find_the_book",
    "opens_when": [&"tide_noticed"],       # beats, choices, or player state
    "objective":  &"the_turf_rows",        # a slot
    "lead":       &"keeper_directions",    # how the player LEARNS it — never a marker
    "closes_when":[&"tide_written"],
})
```

**A lead is information, not a trigger.** Nothing in this game fires because a
player walked onto a tile, and the plan does not get an exception. A lead is one
of exactly four things:

1. somebody tells you, in a conversation, in their own words;
2. something written says where, in the words of whoever wrote it;
3. the **ledger** writes it down (§7) — the world's own record catching up;
4. a machine, read, testifies to it.

The shipped keeper dialogue is already the model and no new mechanism is needed
to see how it should sound:

> *"It is not here. It is where I left it when I stopped wanting to be the one
> holding it. North, past the works, where the turf is cut in rows."*

That is a real direction, in a real voice, resolvable against a real world, and
it names no coordinate. **Author the sentence; let casting decide which works and
which rows.** Where a line must reach into the world it does so through one
resolved token at most — a bearing, a landmark's own name, a landscape's own word
for itself — because a sentence assembled out of three of them stops sounding
like a person and starts sounding like a quest log.

### The guarantee

```gdscript
StoryPlan.problems(world) -> Array[String]
```

Every required slot cast, every stage reachable from the one before it, every
beat with a door, no spine dependency on a landscape that may be absent. Run over
a sample of seeds in the gate, beside the checks `Landmarks`, `GearEconomy` and
`BiomeRegistry` already make.

**This test is the guided path.** Without it the path is a claim; with it a world
that cannot carry the story is a content error caught in `tools/check.sh` rather
than a player stuck at three in the morning.

---

### Words that belong to a place

A story place keeps its own words (`StoryContent.PLACED`), which are never dealt
to a sign anywhere else: the tank he came out of is not a notice in somebody's
village. A placer stands a readable prop there and never names the words.
`StoryFragments.held_by(world, prop)` asks `StoryWorld.place_of` which place the
prop stands at (within `PLACE_REACH`). It then deals that place's words of the
prop's kind in id order: the n'th terminal on the platform holds the n'th
terminal's words (`pick_at`). Anywhere else it deals by kind, as `pick` always
has. Like casting, this is pure and derived, so a save opens onto the same words.

## 7. The ledger — the world writing you down

**Built.** `Story.note(act, land, minutes)` records what could have been seen
(a works put dark, a keeper brought down, going below, being filed); `49_story`
notes each from the event that is it. `StoryLedger` composes two records from it:
the `hearsay` notebook, in a stranger's hand, which hears each act `LAG` (half a
day) late, and the `error_log` terminal, which files it at once as an error. A
fragment with `ledger` set is composed at read time. The ledger saves with the
rest of `Story`, outside `WorldStamp`.

The owner's chosen narrator (2026-09-18). There is no narrator voice and no
omniscient line: instead **the record catches up with the player**, and what they
find written about themselves is the narration.

```gdscript
StoryLedger.note(act, where)              # fed by real events, never by walking
StoryLedger.render(entries) -> lines      # composed in the found-notebook voice
```

It listens to what the game already emits — `killed`, `works_broken`,
`settlement_founded`, `raid_ended`, `story_found`, being filed, a crossing — and
appends an entry. A readable thing of kind `&"record"` composes its lines at read
time out of entries the player actually caused.

Three disciplines, and the channel is worthless without them:

- **Only what could have been observed.** Something saw it, or it left a mark on
  the ground. A private act never appears. This is the difference between eerie
  and omniscient, and it is also the honest reading of a world whose machines
  survey what they can reach and no more.
- **It lags.** The record is always behind. You read about the yard you broke
  last week, in somebody else's hand, after they heard about it.
- **It is written by people, not by the plan** — at least at first. The machines'
  version of the same channel is a filing, and reads completely differently.

The arc of the channel is the arc of the game: early entries are about strangers,
middle entries are about somebody who sounds like you, and late entries are about
you by name, with the ink still wet.

---

## 8. The cast, and companions

**Built.** A named person is ONE file under `src/content/story/cast/`
(`static func make() -> StoryCharacter`), found by `StoryCast` the way landscapes
are found. Their words live in `StoryContent.TALKS` beside everyone else's, marked
`cast` = their id, so the journal, dev mode and the tests read them with no second
path; a trade's words never match a named person, and a named person says only
their own.

- **Anchored to a place, not a body.** `at` names a spine slot; `49_cast` stands
  them a few paces off wherever that slot was cast in THIS world, on ground a body
  can stand on, and draws them while the player is within `STREAM`. `35_folk`
  streams villagers nobody may count on meeting twice; a named person is there
  again when he comes back, because the place is.
- **Development is beats.** `appears_when` brings someone in (June, once her name
  has been said to him), `gone_when` takes them away (Dace, once he learns whose
  order it was). Both are story state that is already saved, so a person's arc
  costs no new save format.
- **Met** is `Story.meet(id)` / `Story.met(id)`, saved with the rest.
- **The one `use` key** reaches them through `49_story`, which reads `49_cast`'s
  rows beside the villagers'.
- **Companions** (owner: *"do not limit me"*): `may_join` says who can walk with
  him. Following, orders and control are the actors' business and not built;
  the story's half of the seam is this flag.
- **Tours** stand beside one with `at cast:ID` and answer `cast:ID` (drawn) and
  `met:ID` (spoken to): `tours/cast.tour`. `--beats=ID,ID` stages what he already
  knows, as long ago, so whoever waits on it is there.
- **A realm not yet grown** can hold someone: Oksana's `the_ring` is an orbital
  slot declared as colour, so it casts nowhere today and she waits for it.

### Pacing — one revelation at a time

**Built.** `docs/STORY.md` §9: the next revelation waits until the last has been
felt. A beat marked `reveal` is a revelation, and `Story` keeps the world minute
each beat landed. For `StoryPacing.SETTLE` world minutes after a revelation (four
real minutes; a night's sleep settles anything), the story holds back what it
OFFERS:

- a reply that would land a new revelation, by itself or by the node it leads to,
  is not offered (`StoryTalk.replies`); the same person can be asked again later;
- a person whose `appears_when` is a revelation is not there until it has settled.
  June does not walk in the minute Imre says her name; she sends for him.

It never holds back what the player has already done. A page read lands at once,
because it cannot be unread, and so does a beat that happened to him. Both still
count as the revelation that everything else then waits on.
`tests/story/test_pacing.gd` also proves that no conversation node is ever left
with nothing to say while a revelation settles.

## 9. State, and what must never happen to a save

`Story` holds what has been read, which beats landed, what was chosen, who has
been met and what became of them, ledger entries, and plan progress. Saved under
key `story`.

> **`Story` is deliberately outside `WorldStamp` and must stay there.** A story
> flag never changes what a world IS, so it must never be a reason a save is
> refused. The fiction is about to get much larger; the moment a rewrite can
> refuse somebody's game, the fiction owns the save format, which it may never do.

Casting is **not** saved (§5). Plan progress is saved; the plan itself is derived.

---

## 10. Dev mode

Everything above is data and the owner can move all of it without a rebuild.
**Built**: the story page and three pages off it (`src/dev/pages/dev_page_story*.gd`,
`--dev=people|path|ledger`, `tests/story/test_dev_story.gd`).

| Page | What it does |
|---|---|
| people | every named person by the place they stand at: where it was cast in THIS world, there, met, waiting (and on what) or gone; E stands beside them |
| story (arcs) | land a beat, take one back, land a whole arc, read every choice |
| the path | every spine stop by leg and body, the revelation still settling, `problems()`; E goes to the stop |
| ledger | what the world has seen, both records as they read now, and a row per act to note one here |
| words | *not built*: which fragment a given thing is holding, and read it on the glass |

`--read=ID`, `--talk=ID[:NODE]` and `--beats=ID,ID` stage a page, a conversation
or what he already knows for a writer.

---

## 11. The contracts, in one list

1. Content declares; casting resolves. A content file never asks the world a question.
2. Key to the **id**, never the index.
3. A required slot may only name a **guaranteed** landscape (`StoryWorld.guaranteed`). Everything else is colour, never load. The predicate is "guaranteed", never "not exclusive" (§4).
4. Casting is pure, derived, and never saved.
5. `Story` state stays outside `WorldStamp`.
6. A lead is information, not a trigger. Nothing fires because a player walked somewhere.
7. The ledger only records what could have been observed.
8. Layers call downward only.
9. `StoryPlan.problems(world)` runs in the gate over a sample of seeds.
10. `TESTIMONY_PASSES` and its comment belong to the slums wave — preserved verbatim, keyed to the passer roster row.

---

## 12. Order of work

1. **Defs + registry + discovery** — the shapes and the auto-discovery. Nothing works without it.
2. **Slots + casting + `problems()`** — and the seed-sample test, first, because it is the guarantee.
3. **Plan + leads** — the spine, cast into real worlds.
4. **Cast files** — the characters, written properly, one file each.
5. **Ledger** — the narrator.
6. **Words** — the fragments and talks rewritten against the new shapes.
7. **Dev pages.**
8. **Companions** — last, and only the story's half.

Steps 1–3 are the system. Steps 4–6 are the writing. They can proceed in
parallel once the shapes are fixed, which is the reason to fix the shapes first.
