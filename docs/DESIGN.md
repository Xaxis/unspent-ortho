# UNSPENT — design

What the game is, in the order decisions get made. Mechanics numbers live in
`docs/research/design-extract.md` (from the old game's content and engine);
the look in `docs/research/art-audio-extract.md`. Those are a **floor**, not a
ceiling: the job is a better game, not a port.

## Pillars

1. **The world is the game.** One generated coast per seed, big enough to be a
   journey, every country different enough that crossing into it is an event.
2. **Real-time, readable, Zelda-grade action.** Two verbs in a fight: swing, and get
   out of the way. You read a machine's body and find the side that is still
   working. No menus and no numbers of its own accord: the fight says nothing in
   words unless the player asks it to, by holding the target key (§Targeting).
3. **Survival and making are a pillar, not a layer.** You mine, fell, gather, make
   tools out of beaten machines, and reach further. Every hand tool is the best
   thing a person can still make and mend.
4. **The machines are predators, barely functioning.** They kill, take hold, carry
   people off to work, and file what they see. Their failures are the only reason
   anyone is alive; the gaps in their coverage are where you live.
5. **Beautiful, and changing as you travel.** The landscape evolves: grass thins into
   heath, heath into limestone, pines into snow, moss into black water, ash drifts
   over the southern rim. Light, weather, sound and machines change with it.

## Targeting (owner, 2026-09-16)

The slate can be put on a body. It is asked for and never imposed, it is never
required to fight, and it changes nothing in the simulation: no aim, no slow, no
hold. What it gives is perspective and knowledge.

- **Hold `z`.** The nearest threat is locked: the camera leans in behind the
  player (a little yaw toward the body, a lower pitch, closer in, the frame
  biased between the two), the body is bracketed with a ring on the ground it
  stands on, and the slate reads it.
- **`a` / `d` cycle** the lock along the list — what is on you first, then what
  is near (`Targeting.threat`), and the last people after everything in the fight.
- **`r` sweeps the field**: the camera stands back instead, nothing is locked,
  and the field is read in short, eight at a time; `a` / `d` page a field bigger
  than that, and the panel says which page of how many it is showing.
- **Let go** and the camera comes back square and the reads go with it.

**Anything the player can look at can be read**, not only what is in the fight.
A villager is a subject like a machine (`TargetSubject`), and reads as a person:
no health, no signature, no working part — their trade, their village, and what
they are doing. Nothing invents a life bar for somebody the simulation never
gave one. A works, a station, a sentinel become readable by getting a `from_*`
on that subject, and the order, the camera and the drawing follow unchanged.

**A lock waits.** A body that steps behind a house or a stride past the reach is
held for `Targeting.LOST_GRACE` before the lock takes anything else: a machine
that was there half a second ago is the same machine, and a lock that flicks to
its neighbour is a lock nobody trusts.

**Every body in the fight carries a wordless tag at all times** — health in pips
and one glyph for how far it has got with the player (nothing, stirring, sure,
coming). People carry none: nothing has noticed them and no number measures their
life, so pips over a villager would be a reading nobody took.
That is the part that is always true of every enemy on screen; the words are
the part the player asks for. This is what turned the old ruling round: a fight
may now be read in words, but only while the key is held.

What the read says is the simulation's own: health and the roster's numbers, its
powers (only what its row declares), what it has noticed (`StealthQuery`, the one
door) and what it is thinking (its mood, its blow's phase, its place in the plan).
Nothing is invented for the panel.

## Crafts (docs/VISION.md §5)

A craft is a thing a person builds out of machine parts and then stands on. It
opens ground a body cannot cross, it is a thing in the world when it is parked,
and it can be worn out, broken under you, and lost.

- **`b` is the whole verb.** Standing at a craft it boards it; carrying one it
  puts it down and steps on; standing on one it steps off; at a wreck it strips
  it for its parts. Nothing about a craft is a menu.
- **The three.** A **raft** (made by hand at the shore: driftwood, a rag and one
  drum off a wreck) crosses open water nobody can wade. A **hover sled** (mended,
  at a bench) runs bog, salt, ice, black water and everything else at half again
  a walking pace. A **walker rig** (mended, at a bench) strides a two-level step
  — a cliff to a body — and takes scree and deep snow under a load.
- **It is not a second movement system.** The fight simulation still moves the
  player: a craft only changes what the ground under the body means (`Hero.ride`
  -> `WorldQuery.move_body`) and what pace it allows (`Hero.ground_speed`). So a
  dodge, a grip, a blow and a machine shouldering you aside all land on a deck
  exactly as they land on turf, and being hauled off your raft leaves it adrift.
- **Getting on and off is never a teleport.** A craft is set down, and stepped
  off onto, only within a shove of the body and only along a line the craft
  itself could travel — so a raft is pushed out past the shallows and nosed back
  in, and a body only ever steps off onto ground it could have waded to. Getting
  off is never how a channel is crossed; the craft is.
- **Wear and wreck.** The shallows grind a raft's drums, scree tears at a
  skirt, every cliff costs the rig something, and a blow that lands on the rider
  takes it out of the hull as well. At nothing the craft breaks: whoever was on
  it is put ashore, and what is left of it lies where it broke and can be
  stripped for its materials — except a float wrecked in open water, which sinks,
  because some things are simply lost.
- **Drawn MENDED** (docs/ART.md §12): FOUND drums, pans, pods and legs in violet
  plate with the machines' own amber still lit on them, bound to MADE spars,
  boards and cord, both idioms in one silhouette, and the lashing crossing the
  rivet row is the drawing.

## Settlements (docs/VISION.md §9)

Making does not stop at what a person carries. A **holding** is crafting at world
scale: a roof, a fire, a plot, a wall, and the people who keep them. Everything in
it is something that can be taken away, which is the whole of why building it
matters.

- **`h` is the whole verb.** It opens the holding app on the slate: what can go up
  where the player stands, what each piece wants out of the creel, what the
  holding has already built, and — in the stolen module's violet, because it is
  the machines' reading and not the player's — what the place gives off. A piece
  goes up in front of the player, out of what they are carrying and against the
  world clock. Nothing about a holding is reached any other way.
- **The first piece founds the place.** After that a piece within a walk of the
  centre joins it, and further off starts another. A holding is named plainly and
  its centre creeps as it grows.
- **Fifteen pieces, in the six families**: lean-to, hearth, hut, store
  (shelter); plot, catchment (food and water); palisade, plate wall, netting,
  decoy mast, spoofer, turret (defence); wind spinner, battery stack (power);
  radio mast (work). What each costs, wears, makes and gives away is one row in
  `StructureKind.ROWS`.
- **A hearth is the game's own campfire.** Laid, it puts a `PropKind.FIRE` in the
  world, so it lights the yard, warms a body, can be slept beside and worked at.
  The holding only records that it has one, what it costs to keep, and that its
  smoke is what gives the place away.
- **A sustainability loop, not a counter.** Power is made by the wind, banked and
  spent; a plot is worked by hands and watered by a catchment or it makes half; a
  store is what stops a surplus going to waste; people eat out of the stores, and
  with nothing to eat they work badly and in the end walk away. Everything
  standing comes apart in the weather, faster where it is the hand's work than
  where it is the machines' plate, and the holding's own people mend the worst of
  it out of the stores. Nothing in it is free to keep.
- **A holding works while the player is away.** It is settled by **catching up**
  from its own timestamp in whole half-hour slices, never by ticking: six hours
  away is twelve steps, a month away is settled forward without being owed. The
  slices are aligned to the clock, so a place looked at every minute and a place
  left alone for a day come out exactly the same.
- **The machines will come for it** (VISION §9.4-7). What a place gives off is
  `Settlement.signature()`: light, noise, smoke, radio, power draw, the FOUND tech
  running inside the walls, and traffic in and out. Each channel takes the loudest
  piece rather than the sum, the hour is inside the answer (a window is nothing at
  noon), and netting takes a little off every channel. A settlement is engaged
  because of what it made, never because of a clock — and the raids package is
  what comes. The two meet on `Settlement` and neither imports the other.
- **Two pieces answer being read, and each buys ONE thing** (owner, 2026-09-17).
  A **spoofer** is a relay's voice box on a stake: while it has power it takes
  half off every channel, and dark it is a box on a stake. It is built round a
  record taken off a carrier, because nobody out here knows what the machines say
  to each other until they have read some — so a spoofer is earned by having
  been read once and having done something about it. A **decoy mast** hides
  nothing. It is walked out past the yard (the slate refuses one in it: a decoy
  in the yard is the yard) and there it shouts what the holding shouts, louder,
  from where nobody lives, so a machine that would have read the place reads the
  mast instead. It is torn at by the weather and by what it fooled, and when it
  falls the glass says so, because nothing else would: from then on the place is
  read at full strength again. A decoy that also masked and cooled the yard was
  considered and refused — three benefits on one row of timber is a discount,
  not a decision.
- **A turret answers back, and it is a decision to switch on.** A repeater taken
  off a machine, mounted on a crib of logs. It shoots only what comes FOR the
  place — a raider first, then anything pressing a fight — never a worker on its
  round, because a yard that shot everything walking past would be the loudest
  thing on the coast and a list of filed kills. Its head comes round onto a body
  and its lens catches before the first bolt, which is the tell. Its blow is the
  fight's own (the plate, the hit window, the stall), and a kill it makes is
  nobody's to be paid scrap for. It wants more power than anything else in the
  yard and it is stolen technology humming in the walls the whole time it is
  armed, so the `E` key on its row stands it down and arms it again: armed for
  the raid you were warned of, dark for the week after.
- **And what it shoots turns on IT.** A raider hurt by the yard walks back out to
  the turret and starts cutting it down, rather than carrying on with what it was
  sent for or coming for whoever is standing there. So the piece buys the rest of
  the yard exactly the time a raider spends answering it, and it pays for that
  time itself. **The player's own swing takes the body back**, and there is no
  rule anywhere that says so: the fight writes where the last blow came from
  (`MobState.struck_from`, INF for a player's swing), the last blow overwrites
  the one before it, and a body belongs to whoever hit it most recently.
- **Drawn by hands** (docs/ART.md §10): crooked frames, walls of what was to hand,
  thatch with a fringe the wind takes, and machine plate lashed over the gaps with
  the cord crossing the rivet row. A piece leans, patches and weathers by its own
  number, so the same kind built twice is not the same drawing. A spinner turns
  when there is wind in it and a battery burns amber while there is charge, so a
  player reads their own holding from a hillside before opening the slate.

## Jumping (owner, 2026-09-17)

A body can jump: **up two levels, across a two-tile gap, down three, and no
further.** Walking still steps one level either way and two is still a cliff, so
the jump is what opens a ledge, a trench or a narrow channel — and anything taller
is still a wall and anything deeper is still the glide's to get down, so the wing
and the rope keep their reasons to exist.

- **Space jumps.** Swing keeps J, its second key since the start, and both are
  rebindable on the settings page. The jump is everybody's: nothing sold as gear
  grants it and nothing takes it away.
- **It is an arc, not a lookup.** `Jump.plan` works the whole arc out at the press
  — rising to its apex, carried at the pace the body was moving (a hop forward
  from standing), stopped by any ground higher than the body is at that instant,
  coming down on whatever is under it — and the gear system replays it. So a
  two-level ledge is reachable because the apex clears it and a three-level one is
  not because it does not; nobody wrote a table of jumpable tiles.
- **It never goes off an edge deeper than a jump.** A planned landing more than
  three levels down is planned again with that drop as a wall, and the body comes
  down at the lip: a key pressed at a sea cliff is never the end of a run. Deep
  water is the exception — a drop into it is a dive, and the water takes it.
- **It is a decision in a fight, not a free move.** It costs a little breath,
  nothing swings or rolls from the air, a solid thing stops a body in the air as it
  stops one on the ground, and the landing is heard further the further the feet
  fell.
- **The height is honest.** While a jump runs `Player.lift` is the body's height
  over the ground actually under it, because a lit world places the shadow from
  that number.

## Swimming (owner, 2026-09-17)

Deep water was a wall to everything without a raft under it. A body that can take
it swims now.

- **What it costs is time and a soaking.** Two fifths of a walk, no running, and
  the wet that any water gives (`Hazards` already answers water with `wet` 1.0
  and a little more cold). Nothing is dropped, no load is refused, nothing
  drowns. That is the owner's ruling, and it is why the rules here are short.
- **What a raft is still for**: speed, a dry creel, and carrying what a swimmer
  cannot be bothered to carry. A crossing the sea can be swum; whether it is
  worth swimming is the player's to judge.
- **Who crosses** is one key on a roster row, `crosses`: `&"swim"` goes in after
  you, `&"fly"` goes over, and absent — which is most of the roster — the
  waterline is where it stops. The dogs swim, the flock and the gulls fly, and
  the dredger swims because it was built to work in water. So swimming away from
  a fight works, and never on everything.
- **Nothing swings from the water.** Not a toll: a blow wants something to push
  against. A dodge still works, because a kick away is the one thing a body in
  water can do.
- **It is the loudest way to travel.** Open water gives no cover and a stroke
  carries further than a footfall, so crossing in the open is a decision.

A swimmer is drawn lying through the surface with the stroke of somebody who was
never taught, and the rings it leaves are what say it is in the water rather than
on it — a figure is drawn over the water whatever its depth (people draw after
the outline pass), so the water cannot cut it yet. That is the one thing about
this that is not finished, and it is in ROADMAP.

## Raids: why and when the machines come (docs/VISION.md §9.2-9.7)

> "Certain machines and certain enemies can destroy your work, and when and how a
> machine engages a city or shelter must be determined by encounters and other fun
> playable systems." — owner, 2026-09-15

That sentence is the whole specification, and it has one consequence the package
is built to keep: **a raid the player could not have seen coming is a bug, however
well it is drawn.** Everything below exists to make every step traceable back to
something the player did, built, or watched happen.

- **A notice is an encounter, not a roll.** A machine that comes near enough reads
  ONE channel off the holding's signature — the loudest one it can hear from where
  it stands — and walks off with it along the bearing the plan surveyed this world
  on. Until it is clear of the yard that record is a thing in the world: kill it,
  spoof it into nonsense, take it off the body, follow it home, or let it go.
  Nothing is filed until one gets home, and **nothing is ever sent for a place
  nothing has read**. A record getting home is the only step in the chain that
  happens over the horizon, so it is heard and said: a player who watched a clerk
  walk off is told the moment it cost them. Taken off a body instead — and
  somebody has to be standing over the body to take it — the record is a thing in
  the creel: proof, and, stripped with a blade, the copper a signet is wound from.
  (It is a found thing, so nothing can ever make one. It is the gate to the
  spoofer the player can BUILD: one record goes into every one.)
- **Attention is 0..1 per holding, and 1.0 is a siege led by the region's keeper.**
  The unit it is counted in is one filed record at full strength
  (`Attention.NOTICE_FULL`, 0.09): twelve of those unanswered bring the keeper. It
  rises from records that got home, from the plan's network in that region going
  up a level, from stolen FOUND technology humming inside the walls (a stolen cell
  is the loudest thing in the game and it costs by the hour), and from machines the
  plan sent there that never came home. It falls with quiet hours, dark nights,
  a spoofed signature, a mask standing in the yard, a record destroyed before it
  travelled, and a step that has been paid. **Hours on their own only ever make a
  holding safer.**
- **A decoy is read instead of the place, and that is all it does.** A machine
  standing at a mast out in a field takes its account of the holding off the
  mast: the record is of the pole, it was taken where the pole stands, and the
  pole is the ground it has to be caught on — a player guarding their own fence
  is guarding the wrong ground, which is the trade the piece makes. When it gets
  home it is filed as a quarter of a real record (`Attention.LURED`), so the
  place still heats up, four times slower. It is never nothing: a piece that made
  a holding unfileable would end the decision the whole system is. And only the
  ONE loudest decoy is ever read, however many are standing, or the answer to
  being read would be a ring of the cheapest thing a player can build.
- **It is read as pressure, never as a bar.** The holding app draws what a machine
  HEARS — seven channels with the loudest named and its percentage — so a player
  can read the same number the machines read before anything arrives. Under it is
  ONE WORD for what the plan THINKS: read, surveyed, wanted, marked, condemned. A
  word and never a number, because the moment that line is a percentage the system
  stops being about reading the world and becomes a thing to optimise. Everything
  else the plan thinks is said by the world — the warnings, the tag bolted to the
  piece that gave you away, and the machines themselves.
- **Four steps, each warned by the world first**: survey (one machine looks and
  drives a stake in at the edge), probe (two come and test the wall), raid (a
  party with a purpose), siege (the region's own keeper leads it). The warning
  comes 25 to 110 world minutes before the machines do, and that window is the
  answer: fortify, take the people off the pieces, kill the mast, fire the signet,
  pay them off with a full store, or walk away and come back to whatever is left.
  **What turns them round on the road is the SIGNATURE falling**, not the books:
  attention moves in units of 0.09 and no hour of play shifts enough of it, but a
  mast pulled down halves what the place gives off in a minute. A holding that was
  always quiet is not called off — it is walked to, found to be nothing, and left
  at the gate. One made worse in the window is re-warned for a bigger step.
- **A party goes for what MAKES the signature.** A breacher takes the strongest
  thing standing between the yard and the outside, a harvester walks past the
  walls to whatever the slate named as loudest, a snatcher comes for whoever is at
  work. So the player's own build decides the fight, and the seven bars are a
  decision rather than a readout. A standing decoy is walked to before any of
  that: it is the loudest thing the plan has ever heard of the place, so a party
  that ignored it would know better than its own file — and the piece a player
  built to be read is the piece that gets taken apart.
- **A raider is here for the holding, not for the player.** It will walk past
  somebody standing in their own yard and start cutting their mast down, and only
  a blow turns it. Fighting one is a choice, and its price is that nothing is
  stopping the other two.
- **Not being there is a legitimate answer. Walking out of one is not an answer at
  all.** A raid the player is not present for is settled on exactly the same
  arithmetic, so coming home to a burnt plot is the same event reached the same
  way and never a cheaper one — and a raid they walk out of halfway through is
  settled the same way too, with whatever the party had not spent yet. The party
  is exempt from the coast's culling for exactly that reason: machines that
  evaporate when the player is twenty-five tiles away would make walking the
  cheapest answer in the game, and it would print "the holding held" while doing
  it. A wall is worth the same share of a blow in both paths, so building one is
  never only worth doing before leaving.
- **Aftermath.** Broken pieces stay where they fell as wreckage 46_settlements
  gives half of back for clearing; machines killed in the yard leave salvage in
  it; a razed holding is left standing as ruins with what the party could not
  carry lying in it; and the region remembers — a holding founded where one was
  razed starts on the plan's books. **Killing the region's keeper quiets its
  network for good**, which makes a boss fight the surest answer in the game.

**A portal is not a raid path, and will not be one until portals are something a
player knows, owns and can close.** A machine arriving through a gate the player
has never opened, from a realm they may not have visited, is unreadable by
construction: there is no warning it could have given and nothing they could have
done about it, which is the one thing this system may not be. So attention is kept
per realm — a machine in the caves never senses a village on the surface — and a
step is only ever warned for a holding in the realm the player is standing in. When
a portal is a thing the player has opened and can shut, a raid through one becomes
the best set piece the system has, and it gets built then, deliberately, with a
warning grammar of its own. Argue with that sentence, do not quietly widen it.

## Settings (owner, 2026-09-17)

The slate's own page, reached from the pause menu and from the title: **sound**
(everything, the world, the score — levels against the mix as it was tuned, not
absolutes), **picture** (the window and fullscreen where there is a window, how
far the camera shakes, and whether a struck body flashes), **playing** (crouch
and the slate-on-a-machine as a hold or a press), and **keys** — every action the
game answers to, read off the live input map, each one movable, and `put the keys
back` to undo the lot.

What it is not: a master configuration. Those are the owner's, packed into a
build (docs/DEV.md); these are the player's, kept on their own device. Nothing
here changes what a world is or how hard it presses — a settings page that can
change the game is a settings page that has to be balanced.

Two of them exist because holding a key for minutes is the commonest thing an
accessibility setting is asked to undo, and two because the camera moving and the
screen flashing are the only things in the game that happen to the player rather
than to their body.

## Owner rulings carried over (mechanics only)

- Combat is SNES-action: fists and feet first; find, then craft, then find rare weapons.
- There is one combat system. No turn-based rows, no verb menus.
- Enemies are regional and varied; each machine has a working part on one side of its
  body, set by its trade; hitting the plate does nothing.
- Nothing speaks because you walked onto a tile; story is unlocked by interacting.
- One clock, the world's, driven by real time (1 world minute per real second by
  default). Walking buys no time. Sleeping, working, being carried off skip time.
- Nothing to do with Bitcoin or money-as-subject.

## The core loop (M1 target)

Wake on the coast → walk, look, gather what the shore gives → find stone and ore in the
rock → a fire and a bench make better tools out of what you took and what you beat →
machines on their rounds: avoid, or fight by finding the working side → night comes
blue and cold, hunger bites, the lamp needs oil → reach the next country with a tool
that can take what grows there.

## Systems (target shape)

| System | Shape |
|---|---|
| Body | health (small gauge, no numbers), wind (dodges), hunger, wet, load; a worn body is slower |
| Fight | continuous, fixed-step; blow boxes with windup/active/recovery; dodge with i-frames; plate side rule; knockback + stun; grip (ensnare) broken by pulling; outcomes: won, away, downed (time lost, no death), carried (a shift of forced work, wake elsewhere) |
| Machines | 12 kinds by country and hour; errand / charge / rush / dart approaches; sight dimmed by dark (a lamp undoes it), hearing not; seen often, met rarely |
| Tools | one hand one tool; the held tool is the work verb and the weapon; edge wears, never breaks; hardness ladder wood < iron < steel < crucible |
| Taking | verbs break/dig/fell/cut/gather/scrape/tap/turn on world props; time costs; some regrow, some are permanent world edits |
| Making | stations fire/bench/kiln (+ wheel/loom); recipes turn scrap from machines into tools; wearable salvage kit (plate, brace, rig, lens, aerial) |
| World | landscape TYPES from the registry (`src/content/biomes/`), composed per seed: Coast, Moss, Pinewood, Snowfield, Bonelands, Burning, Salt Flats, Scrapwood; each seed's world is a set of REGIONS of those types; villages; landmarks; interiors later |
| Pressures | what a place puts on a body: cold, heat, fumes, toxins, radiation, wet, dark, vacuum, pressure, EM, resonance, time-shear. A landscape type declares its worst (`BiomeDef.hazards`); the hour, the weather, the height, a roof and a fire decide how much of it is on you now. Felt first (a gauge, breath, a cough), then in the legs, then a slow drain that stops before the last point of health: the weather never kills outright |
| Gear | six slots (head, body, hands, back, tool, craft), each piece with sockets, each module with resistances and sometimes an ability. Three idioms and three tiers: MADE (hand), MENDED (found parts on a made frame), FOUND (taken whole, spends charges, unmendable). Configured on the slate's gear page before a journey |
| Abilities | one interface (id, input action, cooldown, cost in charges or wind, press/hold/passive): dash, glide, scan, grapple, signature spoof. An ability asks for a move and for a mark; the gear system does both, so it never touches a node |

## Story

**The arc and every rule for writing it are in `docs/STORY.md`** (owner,
2026-09-17): the machines are reconcilers, not jailers — one attested reality,
every mind agreed — and to be free is not to escape but to fork. The words are
uncovered by reading a thing, talking to somebody, or watching a machine work,
never by walking onto a tile; a conversation is drawn over the world with the
world still running; and what the player says is remembered against the question,
not the person. What is built so far is the spine's first beats and the tide
sub-arc; the rest is declared and empty, which STORY.md §11 says plainly.

The premise shape is the owner's (2026-09-15) and lives in **`docs/VISION.md`**: the
few dwindling humans after the machine apocalypse; machines that still mean to end
them, many of them indifferent unless you interfere with their **ultimate plan**; the
plan as the core arc with generative subarcs finished many ways. The words (what the
plan is, who is left, dialogue) are written from nothing in the story milestone.
Never port the old game's fiction, arcs, names or text.

## Look

See **`docs/ART.md`** (binding): the coast as a living field notebook. Flat washes,
inked contours, hatched shade pinned to the world, the hand (MADE) against the
ruler (FOUND), countries with their own wash, hatch, decor, light and weather, and
ecotones between them. Nothing like Minecraft or any voxel game.
