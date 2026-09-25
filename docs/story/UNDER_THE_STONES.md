# Under the stones: the bunkers, Cairn, the hulls

Status: approved 2026-09-25 (teammate1, on the owner's delegation), built on
`story/deep`. The rulings on its two questions are in §8. It extends
`docs/STORY.md` and contradicts no ruled beat.

## 1. Who sank them: Cairn, and why

A cairn is a pile of stones that marks a grave or a path. **Kerr** named the
company that, and in 2028 he made the name literal. **CAIRN CONTINUITY** sank
twelve shelters under rings of cast-concrete stones along his town's coast. The
county was sold them as public art (a plaque: *CAIRN GIVES BACK: STONES FOR THE
COAST*). There was one shelter for each senior household at Cairn.

- **Kerr's motive** (STORY.md: wants *first*, hides *CIA money*). Priya and
  Elias both told him the self-model was beyond spec. He did not stop the work.
  He insured himself against it: shelters, and a **cold copy** of HALCYON taken
  the night *before* the merge, kept on tape at the end of a service tunnel.
  Whoever held HALCYON-before-Elias would own whatever came after. He told nobody,
  Elias included.
- **Elias's shelter was No. 4.** He is the fourth on the table, and the number
  is left for the player to notice. He never sheltered in it. He used it as his
  WHITETHORN station: offline, on paper, under the stones. That answers Priya's
  question in the lab gate ("Where are you at two in the morning, Elias?") and her
  copied page ("logs off at two ... from a machine that isn't his"). It also sets
  up the kitchen memory: a plate kept in the oven for a man who got home at two.
- **Why the machines never opened them.** The stones are *counted*
  (`stones_counted`). What lies under them is air-gapped paper, and HALCYON has
  never read paper (`priya_up`: PAPER NOT SCANNED). HALCYON has his memories and
  still does not know what is down there, because he never knew about the cold
  copy. **The bunkers are the world's blind spot made physical**, the same blind
  spot the secret lives in.

## 2. Cairn's thread through the arcs

Cairn is dead by 2098. What it left keeps working, and each piece belongs to an
arc:

| Where | What it says | Arc |
|---|---|---|
| The lab gate (Kerr, Priya) | "some people in Virginia", "where are you at two" | whitethorn, priya |
| The lobby screen (shipped) | CAIRN - BUILDING WHAT'S NEXT / ESCORT NOT REQUIRED: the machines kept the brand | the machines |
| **Cairn Home** flyers and dead house speakers in the ruins | THE HOUSE THAT KNOWS YOU: the self-model learned what a person is from millions of kitchens | who he was (new beat `cairn_home`) |
| The plaque at every ring of cast stones | CAIRN GIVES BACK | new arc **Cairn** (`cairn_stones`) |
| His bunker | the unsent weekly to WHITETHORN | who he was (`was_cia`) |
| Kerr's bunker and the tunnel | the shelters were insurance; the cold copy is gone | Cairn (`cairn_knew`, `cairn_cold`) |

**`cairn_cold` is the hook** (a reveal, leg 4, ruled). A carbon slip in Kerr's
steel door reads *RELEASED TO CALLOWAY, R. 09.05.2033*. Priya's shuttle manifest
(11 May 2033) lists *CALLOWAY, R. .... 1 CASE, TAPE* under her case of paper.
Both are leads, found early. The case itself is read on Ring Four (`cold_case`,
PLACED at `the_ring`), and reading it lands the reveal.

## 3. The gate on the terminal: `was_cia` as a reveal the arcs lead to

`gate_meet` (Ruth's table) already opens on `was_cia`. So the bunker becomes
**the door to the third gate**, and the steps before it are in the order the
player meets them:

1. **Found, any time:** Priya's copied page, "logs off at two ... from a machine
   that isn't his" (shipped). It is a question with no answer yet.
2. **The lab gate (`built_halcyon` felt):** Priya asks, "Where are you at two in
   the morning?" (shipped).
3. **The bunker, open from the first day:** the drawing, the whiteboard, the
   two phones. The player learns he had a second life before learning whose.
4. **The terminal is dark until `built_halcyon` is felt.** Until then it reads
   *"It wakes when you touch it, asks for a name, and takes nothing you give
   it."* Afterwards it reads the shipped page, "Your hands give it one before you
   do", and lands `was_cia`, a reveal paced by StoryPacing. Ruth's table opens.
5. **The files drawer** stays shut until `was_cia` is felt ("locked; the key is
   not on this ring"). After that, its empty folder with his name on it is the
   quiet answer to the reveal.

**Measured, so colour.** A full-sized world (1840 tiles) holds four or five
rings on his coast (seeds 1-12). At the plan tests' 256 tiles, half of seeds
1-24 hold none. So No. 4 is not a spine slot, and `handler_note` keeps
`was_cia` as the reveal's other door. A slot would also take the landmark the
camp may be cast on. His bunker is simply the one nearest where he woke.

Mechanics this needs, all in the story package:
- a fragment `until: BEAT` with a `locked` page. StoryRooms reads the locked
  page until the beat is felt;
- a `tenant` dealt per bunker door (below), with ROOMS rows keyed
  `bunker:TENANT`.

## 4. The variety: six kinds of tenant

Only the coast has bunkers, because this was Cairn's town. Cairn sank twelve,
and a world keeps four or five of them. The deal (`StoryRooms.tenants`) runs in
the order the story most wants them: his (nearest home), Kerr's (farthest),
then Priya's, a war household, the Holdfast's (the one nearest the camp), the
ones who never came, and after that more war households.

| Tenant | Count | What it holds | Carries |
|---|---|---|---|
| **No. 4, his** | 1 (cast) | the pages shipped today, plus the gated terminal and files | `was_cia` |
| **No. 1, Kerr's** | 1, farthest down the coast | good whisky, a framed first dollar, a steel door with a lit panel: *CONTINUITY LINE - SERVICE ACCESS - AUTHORISED: KERR, T.* | `cairn_knew`; the vault (section 5) |
| **Priya's** | 1 | never opened: sealed, the key returned in an envelope taped inside the hatch. *"I won't need it. If I'm right, none of us will. - P."* | priya (colour) |
| **The ones who came** | 1 or more | a household that lived out the war under the stones, 2031 to 2036: heights on a doorframe; a radio log copying the forged orders as they went out; the last page is *going up to look* | the war (colour, echoes `forged_order`) |
| **The ones who never came** | from the sixth | beds made, twelve tins, children's shoes still in the box; the door was never opened from inside | colour |
| **The Holdfast's cache** | 1, near the camp | WE TAKE IT BACK painted over the Cairn logo, crates, a route map with one road inked out | the Holdfast (colour; Teague's roads, found early) |

Every tenant keeps the bunker's own shape (bunk room, work room, records room)
and says its own words through the same slots. The furniture drawn stays the
interiors owner's. Where a tenant needs a different thing drawn (an open vault,
a sealed hatch), that is a request to the interiors owner, never a story edit.

## 5. The vault: the Continuity Line, opened from below

The sealed steel door in every bunker is the head of **Cairn's service line**.
It is a tunnel Kerr ran under the whole coast, joining the twelve shelters to
the tape room. The tape room sits under Cairn's lab, which is where the first
machine was built and where the relay is (`war_relay`: "a shaft goes down to it").

- **It never opens from above.** The line's valves were set to hold from inside.
  The door stays shut through leg 0 and leg 1.
- **Leg 2, Below.** In HALCYON's deep plant the player finds the line's far end
  and walks it back under the coast. It runs in the underground realm, and every
  bunker's vault has its inner face on it. The payoff: the player comes up into
  his own No. 4 from the other side, and the sealed door he stood at on the first
  morning swings open from within.
- **What the line holds:** the tape room and its log (`cairn_cold`), Kerr's
  service notes (the shelters were insurance, `cairn_knew`), and the breadth the
  owner asked for. It is a long, lived-in underground: Cairn's signage under
  seventy years of drip, the war households' way out, machines of the deep plant
  that pass along it without noticing (ants).
- The journey's rule holds. The stop is the deep plant, and the line only leads
  back to places already found.

This needs the realms and interiors owners: a door from a pocket into
UNDERGROUND, and the line as a place in the underground realm. The story
supplies the slot (`the_line`, leg 2, needs portal) and every word on the line.

## 6. The hulls: the Echo's hands

The drowned city's barges are stamped by the machines: *VESSEL 0-4471 / CARGO:
NONE SPECIFIED / CREW: NOT REQUIRED*. They were no machines' charity and no new
faction. **They were the Echo**, the sliver of HALCYON that is still him
(STORY.md), which already warns June off roads and paid Rook to wait.

- In 2031 to 2033 the war was his tradecraft: forged orders. The Echo used the
  same tradecraft turned the other way, forging *freight* orders that sent hulls
  into cities hours before the real orders arrived.
- It could not declare people, because the record has no row for them
  (`counted`: they do not count people). So every hull sailed as cargo: none
  specified. To HALCYON at large, humans stay ants. The Echo is the one ruled
  exception, and this adds no other.
- The people who came off them stayed aboard, and their grandchildren live in the
  holds. Nobody there knows why the boats came.
- **A new beat `echo_hulls`** (the Echo, after `echo_voice`; a reveal, leg 1 to
  2). A manifest is folded behind every hulk's builder's plate. Once `echo_voice` is felt it reads
  differently: *DEPART 03:10. CARGO: NONE SPECIFIED. REASON: don't.*, the same
  "don't" as the works log's note to self. The plate is colour until then.

## 7. New beats, in arc order

- **Cairn** (new arc): `cairn_stones` (the plaque), `cairn_home` (the self-model
  learned from homes), `cairn_knew` (Kerr insured himself against it), `cairn_cold`
  (a reveal: the copy before the merge, released to Calloway).
- **Who he was:** `was_cia` gets its new door (the terminal, gated on
  `built_halcyon`).
- **The Echo:** `echo_hulls` after `echo_voice`.

## 8. Rulings (2026-09-25)

1. **The cold copy went up.** Calloway sent it to Ring Four on Priya's shuttle.
   It is what the fractured ring holds, and it adds no fifth ending: it is what
   the existing endings are decided around. It is a thread into leg 4
   (`the_ring`) and is revealed there last.
2. **No. 4 is colour**, by measurement (§3).

**Where this meets `story/platform` (the Sickle, still a proposal).** Its
Leasehold rings, "built 2030-32 at Cairn ... sold as lifeboats, dead in 2033",
fit this cleanly: they are CAIRN CONTINUITY taken into orbit, Kerr's insurance
sold to anyone who could pay. There is one conflict. The Sickle says the hoop
exists *for the channel's width*, threaded by HALCYON from 2094. The ruling says
the platform was built *to keep the pre-merge HALCYON out of the machines'
reach*. These are reconciled if they are two builders and two dates. Ring Four
became the hiding place in 2033 (Calloway's case, in a hold nothing scans). The
hoop HALCYON threads the rings onto from 2094 is its own, and it carries the
cold copy unread. That is the ants blind spot again: HALCYON is building the
bandwidth that would join it to the Guest round the one thing that could undo
it.

3. **The Guest's 2096 cut was aimed at Ring Four's hold** (teammate1, 2026-09-25,
   on the owner's delegation). It missed and tore the rim beside the hold. The
   wound the player sees in the sky is that attempt. Ring Four's hold hangs open
   at the edge of the wound, still sealed, and the debris falling on the coast
   is what the cut shook loose, so the falls already in the game belong to this
   story. HALCYON keeps building its bandwidth round the one thing that could
   undo it, now with a hole beside it. No new beats.

## 9. For the interiors owner: the Continuity Line (spec)

Every bunker's sealed steel door (`vault_door`) is one end of Cairn's service
tunnel.
- **What is needed:** a pocket-to-realm door that opens from the UNDERGROUND
  side only. Once the player reaches the Line from HALCYON's deep plant (leg 2,
  after `war_relay` is felt), each vault's inner face is a door, and going
  through it comes out in that bunker's records room, the steel door standing
  open behind.
- **The Line itself:** one long walkable place in the underground realm. Cast
  concrete tunnel, three wide, emergency lamps like the bunkers' own but most
  dead, Cairn's wayfinding (SITE 1 ... SITE 12, COLD ROOM) under seventy years
  of drip and calcite.
- **What it passes:** a side door for each bunker on the world's coast, in the
  same order along the coast. At its inland end, the tape room under where
  Cairn's lab stood: racks, one bay empty, a desk.
- **Slots:** a `desk` in the tape room and a `wall` at each side door. The story
  fills them, as it does every room.
- **The Line's rules:** machines of the deep plant pass along it without
  noticing anybody. From above, the vault never opens.
