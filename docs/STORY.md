# STORY.md — the arc, and the rules for writing it

Binding on every line anybody writes for this game. The premise shape is the
owner's (docs/VISION.md §1); the spine below is the owner's ruling of
2026-09-17. `docs/DESIGN.md` §Story still holds: **never port the old game's
fiction, arcs, names or text.** `docs/research/` is a record of what not to
reuse.

---

## 1. The spine, in one paragraph

The machines are not jailers. They are **reconcilers**. Something once broke the
world into versions that could not be made to agree, and the machines' answer —
their whole plan, the thing every round, every pylon and every filing serves — is
that there must never again be more than one version of the truth. So they are
bringing every mind into one attested reality: surveyed, recorded, agreed. What
the player walks on is not a copy of a world that exists somewhere else. It **is**
the agreed world, the ledger's own rendering of the coast, and they were born
inside it. The people still out in the gaps are not survivors of the machines'
war. They are **divergences**: minds holding a version the network cannot verify.

And the answer to it is not escape. There is no outside to escape to. The answer
is to **fork** — to go unattested, to keep a key the machines do not hold, to be
a version they cannot reconcile and cannot delete without admitting there was
more than one.

## 2. Why this and not the other one

"You are in a simulation" is the most worn turn in the genre, and on its own it
is worth nothing. What makes it this game's is that **the machinery was already
built before the words were**:

| What the game already does | What it means once the spine is known |
|---|---|
| `Interference` per region, 0..1 | the network's confidence in its model of that place |
| `Body.filed` — a clerk logs you | attestation: you have been made to agree |
| the signature signet (`spoof_until`) | a forged key: a signature the network accepts and a person wrote |
| realms and portals, one world per realm | branches of the same state, reachable and inconsistent |
| a save refused as `&"elsewhere"` | a world whose parameters the build cannot reconcile — the machines' own logic, in the player's own save folder |
| works, relays, survey bearings | the infrastructure of agreement, laid in straight lines |
| a sentinel per region | what keeps a region's account |

Nothing in that table was invented for the story. The story is the reading of
what is there. **This is the rule the whole arc must keep: the fiction explains
the mechanics that already exist, and never asks for new ones to make sense.**

## 3. What is never said

- The game never uses the word "simulation" in its own voice. The machines say
  *reconciliation*, *divergence*, *attestation*, *the record*. People say *being
  kept tidy*, *the tally*, *going quiet*. The player may conclude whatever they
  like.
- Nothing speaks because the player walked onto a tile. **Story is uncovered by
  reading a thing, talking to somebody, or watching a machine do its work.** No
  arrival triggers, no cutscene on entry — this was the old game's best ruling
  and it survives the rewrite.
- Nothing explains itself. No character exists to tell the player what is going
  on, and a fragment that answers a question must open another.
- No exposition longer than the glass it is written on. A sign is a sign.
- Nobody is named until the player has a reason to ask.

## 4. The voice

The build already has a voice and every new line matches it: flat, second
person, present tense, no adjectives it can live without.

> The lamp gutters, and goes out.
> It lies still. It is finished.
> Plate rings, and does nothing. Strike the side that is lit.
> A gull comes down on your bag and is gone with something in it.

Three registers, and they never blur:

**The game** — what the player is told about the world. Flat, second person, no
opinion. *"You come to where you fell. Hours have gone."*

**The machines** — officialese, past the point of sense, written in capitals on
things bolted down. Never cruel, which is what makes it cruel. *"RECONCILIATION
IN PROGRESS. REPORT ANY DIVERGENCE."*

**People** — short, dry, tired, specific. They talk about work and weather
before they talk about the plan, and they never deliver a paragraph. They are
funny the way people who have lost are funny. *"You came from the water. Nobody
comes from the water."*

## 5. The world that came before

The ruin is our world, and the jokes are in the wreckage of its customer service.
This is where the wit lives, and it is dry, never winking:

> PLEASE WAIT TO BE SEATED.
>   — and under it, in pen: *still waiting*

> THIS AREA IS MONITORED FOR YOUR SAFETY.
>   — the machines took it literally, and kept the sign

> Accept all cookies?  [Y] [N]
>   — the Y key is gone. Somebody took it, or somebody pressed it too hard.

> YOUR PATIENCE IS APPRECIATED.
> YOUR DIVERGENCE IS NOT.
>   — the second line is newer than the first

The rule: **the old world's words are found, the machines' words are added.** A
sign that has both is the whole story in one object, and those are the best ones.

## 6. The cypherpunk stance

Not decoration. The arc is an argument, and the argument is old:

- A private thing is not a secret thing. It is a thing that is nobody's business.
- Nobody grants you the right to be unread. You keep yourself unread, or you are
  read.
- A key you do not hold is not yours. This is true of a door, a name, and a mind.
- Consensus is not truth. It is agreement, and agreement can be manufactured.
- The machines are not evil in the arc. They are **correct**, by their own rules,
  and their rules are the ones everyone agreed to when they were frightened.

Write it as people living it, never as a manifesto. Nobody in this game says
"privacy". They say *"they have not got my name and they are not having it."*

## 7. How it is uncovered

Four channels, each with its own job. A player who uses only one should still get
a whole thread, and a player who uses all four should find they agree.

1. **Things that are written** (`StoryFragments`) — signs, notebooks, terminals,
   marks scratched on stone. Placed by whoever places things (landmarks, works,
   scatter: they own the place, the story owns the words). Found by using them.
   This is where the world before speaks.
2. **People** (dialogue, over the world, choices remembered) — what the living
   know, what they will not say, and what they ask of the player. This is where
   the cost lives: a choice is a fact about the player that later lines read.
3. **Machines, by being watched** — what a clerk does to you, what a keeper's
   round is for, what the works are laying. The slate's read of a machine is
   already testimony; the story only has to name what the player is looking at.
   It does, in one line under the machine's name while the target key is held
   (`StoryContent.TESTIMONY`, by role: *taking a count, not a fight*), and a
   machine the player has stopped to read for a moment lands what reading it
   tells.
4. **The player's own state** — being filed, being hunted, a region gone quiet, a
   save refused. The mechanics are evidence, and the arc's turn is the moment the
   player understands that the number on the slate was about them. What is
   watched is written down in one table (`StoryContent.WITNESSED`) and each lands
   on the CHANGE, once, with its line said on the glass — because nothing else
   would tell the player that being filed was a sentence in somebody's account.

## 8. The arcs

One spine, and sub-arcs that can be finished in several ways and in any order.
Each is a handful of beats; a beat lands when something is read, said or done.

### The spine: **the account**
1. *Things repeat.* The tide at the same minute. A round walked identically. A
   gull's path. Small enough to be madness, until it is written down.
2. *The vocabulary.* The machines' words are not war words. They are clerks'
   words. Something is being kept, not fought.
3. *The filed.* Somebody who was taken and came back agreeing. They are not
   hurt. They are settled, and they are wrong in a way nobody can point at.
4. *The unattested.* The player is not hunted for what they did. They are hunted
   for what they are: a version nobody can check.
5. *Branches.* There is more than one of this place, and they do not agree with
   each other. Standing in another realm is how it is known; a map with two
   YOU ARE HERE dots is how it is suspected.
6. *No outside.* The last thing the arc gives is the removal of escape as an
   option, and the offer of the fork in its place. It is only ever said to
   somebody who already knows there is more than one of here.

### Sub-arcs (each finishable many ways, in any order)
- **the tide** — the repeating world, read off the shore and the weather.
  *Noticed, written, named.*
- **the quiet region** — a place whose interference never rises: everyone there
  already agrees. The horror is that it is pleasant. *Calm* (a noticeboard at
  100% agreement), *glad* (somebody who stopped disagreeing and was rested by
  it), *the cost* (the part that could have said no, which nobody misses — that
  is the cost).
- **the forged key** — who made the first signature the machines accepted, and
  what it cost them. Ties to the signet the player can wear. *Accepted* (a gate
  reader welcoming back a blank name), *the price* (a key works only while
  nobody knows whose it is), *carried* (firing the signet, once the first key is
  known of, is wearing a copy of a copy of it).
- **the last clerk** — a machine that files people, and the people who ask it to
  file them on purpose. *Written* (being filed), *the record* (holding their
  account of a place), *asked* (a form that says `reason: tired`, and a cutter
  who sleeps all night now).
- **the ones who went in** — people who walked into the works and did not come
  out, and the one who did. *Boots* (left at the fence, laces tied), *the tally*
  (INTAKE 31, RELEASE a dash — not a zero), *came out* (will not go near the
  water, says there is no inside), *dark* (a yard put out, and nobody in it, and
  nobody for a long time).

A conversation belongs to a TRADE (a keeper, a gatherer, a scavenger, a cutter,
a digger), one each, so whoever of that trade the player stops to talk to says
it: villagers are streamed, and nothing may hang on one body being one person.

## 9. Choices, and what they cost

A choice is remembered by the question, not by who was asked (`Story.choose`).
Three kinds, and every one must be honest:

- **What you say about yourself.** Giving a name, admitting where you came from,
  agreeing to be written down. The machines' side of this is mechanical: being
  filed raises interference and marks you.
- **What you tell other people.** The truth about the tide, about the filed,
  about what the works are for. People do not thank you for it.
- **What you refuse.** Saying nothing is always available and is never the
  cowardly option; in this arc it is the cypherpunk one.

No choice is scored. Nothing tracks a morality. What a choice does is change what
later lines say, and occasionally what the world does.

## 10. Editing it (dev mode)

Everything above is data, and the owner can move all of it without a rebuild
(docs/DEV.md): the arcs and their beats, every fragment's text, every line of
dialogue and every reply, and the record of what a playthrough has found and
chosen. Dev mode's story page can read the state, land a beat, forget a beat,
set a choice, and jump the arc, so a writer can sit in the middle of act three
without playing to it.

## 11. What is written so far

Every beat of every arc in §8 has at least one door the player can find, and
`tests/story/test_arcs.gd` fails the day one does not. Written: 23 things to read
(signs, notebooks, terminals, marks), five conversations (a keeper, a gatherer, a
scavenger, a cutter, a digger), a line of testimony for every role of the plan
and for a landscape's keeper, and six beats that the player's own state lands.
What is thin is placement: the words are there, but which readable thing in the
world carries which of them is still `StoryFragments.pick` over every fragment of
a kind, so a player meets the threads in whatever order the coast deals them.
Giving the landmarks and the works their own fragments is the next pass.
`--read=ID` and `--talk=ID[:NODE]` put any page or conversation on the glass for
a writer to look at.
