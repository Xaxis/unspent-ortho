# Machines and fighting

Machines on the land, their disposition, depots, keepers, the fight, targeting, defences and raids.

<!-- covers: system:30_mobs, system:32_disposition, system:34_works, system:36_machine_parade, system:40_fight, system:42_target, system:43_cracked_roof, system:44_sentinels, system:45_taken, system:47_defences, system:48_raids -->

## Sub-features

- 30_mobs: `src/systems/30_mobs.gd`, reached by `tools/tour.sh tours/machines.tour`.
- 32_disposition: `src/systems/32_disposition.gd`, reached by `tools/tour.sh tours/disposition.tour`.
  Relic heat (GEAR.md G9): each relic worn warms the player's region by Interference `carried` (0.03) an hour; made kit does not, and the reads app names it under the trace (StoryContent.READS_CAUSE `carried`): `tools/test.sh test_relic_heat`, `tools/tour.sh tours/relic_heat.tour` (options in its header).
- 34_works: `src/systems/34_works.gd`, reached by `tools/tour.sh tours/works.tour`.
- 36_machine_parade: `src/systems/36_machine_parade.gd`, reached by `tools/tour.sh tours/machines-day.tour`.
- 40_fight: `src/systems/40_fight.gd`, reached by `tools/tour.sh tours/fight.tour`.
  Height: a ledge (2 levels) stands bodies out of each other's blows (`tools/test.sh test_height`).
  Climbing (the jump key at a rock face too tall to jump; a route ruled up a face you face; breath a
  level, fall damage when it runs out; the climber's level on the face for blows):
  `tools/test.sh test_climb`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/climb.tour` (header has its options).
  The vertical line (the grapple at the foot of a face up to 8 levels, hauled up to a post, pylon or
  trunk at the top): `tools/test.sh test_vertical_grapple`,
  `TOUR_FIXED_FPS=60 tools/tour.sh tours/vertical_grapple.tour` (header has its options).
  The drop strike, a jump's landing off a ledge as a plate-opening blow: `tools/test.sh test_drop_strike`,
  `tools/tour.sh tours/drop_strike.tour` (header has its options).
  The heavy blow, swing held 300 ms: `tools/test.sh "test_heavy,test_bouts"` (the reader's time-to-kill
  metric prints there), `TOUR_FIXED_FPS=60 tools/tour.sh tours/heavy_blow.tour`.
  Attack slots (FightSim.attack_slots): at most two biters on the player at once, one bite at a time
  (`bite_turn`); the rest wait at the edge beside the pair, feinting, and swap in when a slot frees or a back is
  turned on them: `tools/test.sh test_attack_slots`; the crowd numbers: `tools/sweep.sh --crowds`.
  Unseen bites (FightSim.begin_bite): in a crowd a bite begun beyond 60 deg of the player's facing is told 2x long
  and cued, a machine's call from its bearing and a rust chevron at the slate's edge on its side (Hud.flag_unseen);
  a crowd shares what it sees, and breaks when only one is left or its leader is taken first:
  `tools/test.sh test_attack_slots`; the frame: `TOUR_FIXED_FPS=60 tools/tour.sh tours/unseen.tour` (options in its
  header; `behind KIND` stages a bite from the player's back). Judge balance under `tools/sweep.sh --reader=human`.
  Contact (roster `touch`, `touch_arc`): a sweeper's brush hurts at its front only, so its back part is
  struck and not brushed; a watcher's skin hurts all round: `tools/test.sh test_touch`.
  Every bite's ground ring (dashed where it lands, an inner ring closing on the strike):
  `tools/test.sh test_tell_ring`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/bite_ring.tour`.
  The thrower (the middens' sorter, Brains `throw`): a lane-long bite told by its lane on the
  ground, a reload that is the opening; `tools/test.sh test_throw` (the reader's bout numbers print
  there), `TOUR_FIXED_FPS=60 tools/tour.sh tours/thrower.tour` (header has its options).
  The dropper (the tamper, the scrapwood's own, Brains `drop`): waits on a ledge and comes down on where the player
  stood, told by its shadow growing on the ground; `tools/test.sh test_dropper`,
  `TOUR_FIXED_FPS=60 tools/tour.sh tours/dropper.tour` (top view and over the shoulder; the tour
  command `over KIND` stages a body on a lip with the player below).
  Ten awake machines' draw cost: `tools/test.sh test_awake_cost`.
  The crags rings (docs/HUSH.md H1): a machine will not follow into one; it holds at the edge facing in, goes home at
  dawn or past its forget, and a feral comes in: `tools/test.sh test_hush_hold` (its bout prints),
  `TOUR_FIXED_FPS=60 tools/tour.sh tours/hush_hold.tour --seed=7 --hour=11 --weather=clear:0`.
  No hopeless matchup: every weapon beats every common machine (not a keeper, not a dart) at
  least 1 start of 4 with the crowd reader (`tests/fight/crowd_reader.gd`, which sprints, heavies,
  walks in on a stand-off and baits a thrower): `tools/test.sh test_matchups` (~35 s, prints any
  hopeless pairing). The crowd reader against the one-machine reader: `tools/test.sh test_crowd_reader`.
  The shoulder reader (`tests/fight/shoulder_reader.gd`: what a player over the shoulder knows -- the eye's cone,
  what is heard, what was seen a second ago) runs the matchup sweep as its second column.
  Part sides (a landscape's `over` part moves the working part; the model builds it there):
  `tools/test.sh test_part_sides`, `tools/shot.sh shots/x.png --scene=gallery --filter=sides_hauler --zoom=4`,
  `tools/tour.sh tours/part_sides.tour` and `tours/part_sides_cave.tour` (headers have their options).
  Night hearing (a machine hears further and makes up its mind faster by ear at night): the day
  and night noticing distances and night bouts print in `tools/test.sh test_first_meetings:test_by_night`.
- 42_target: `src/systems/42_target.gd`, reached by `tools/tour.sh tours/targeting.tour`. A lock holds the body (facing, strafe arc, swing, dodge: `src/core/fight/lock_on.gd`, `tools/test.sh test_lock_on`), proven in both views by `tools/tour.sh tours/lockon_top.tour` and `tours/lockon_shoulder.tour` (each tour's header has its options).
- 44_sentinels: `src/systems/44_sentinels.gd`, reached by `tools/tour.sh tours/sentinels.tour`.
  The plough (the Snowfield's keeper; FightSim furrows: fast on its lanes, wallowing and bogging off them): `tools/test.sh test_plough`,
  `TOUR_FIXED_FPS=60 tools/tour.sh tours/plough.tour` (options in its header).
  Every keeper is a boss to the shoulder reader (won 18+/24, 25-45 s, 2+ health lost; ~50 s to run): `tools/test.sh test_keeper_bouts`.
  The come-round (a keeper sweeps a body kept at its flank; every keeper, its own flavour): `tools/test.sh test_come_round`,
  `TOUR_FIXED_FPS=60 tools/tour.sh tours/come_round.tour` (options in its header).
  A keeper reaches you on its own ground: a charge walks its own field round what stops its move (NavField.for_body:
  its climb, headroom, props but what it breaks), and a lost keeper hunts where it last knew you before it forgets
  (Brains._hunt, FightSim.hunting): `tools/test.sh test_keeper_reach` (seeds 1 and 4, every lair; ~2 min). Its lair
  is off the ground it founders on and opens Sentinels.OPENS_LEAST tiles of its own move (Sentinels.lair; a region
  with no such ground has no keeper).
  A struck keeper turns on you: every keeper on seed 1, put out once at its lair by 44_sentinels, hit on its own level,
  chases, is roused and faces you within 3 s: `tools/test.sh test_keeper_roused` (~2.5 min).
  A keeper goes through a wood: what its drawn body walks into of the kinds its row `breaks` (every keeper: trees and
  shrubs) is felled for good and thrown over (FightSim._break_through, 40_fight `felled`): `tools/test.sh test_keeper_breaks`.
  The frame, staged as a player does it (walk up to the snowfield's plough, hit it, run for the pines):
  `TOUR_FIXED_FPS=60 tools/tour.sh tours/plough_wood.tour` (options in its header).
  The Limestone Caves' drip-warden (src/core/sentinel/designs/drip_warden.gd: keeping, sealing, dry; force, founder
  on the sump's silt, starve on its pump houses and pipe; its bout in `test_keeper_bouts`): squat under
  a roof, and no body a roofed landscape fields is taller than 80% of its halls give: `tools/test.sh
  test_keeper_headroom`; whole at eye level under a tear and in a hall by the lamp (`near mob:KIND DIST`, on its
  own level first): `TOUR_FIXED_FPS=60 tools/tour.sh tours/drip_warden.tour` (options in its header).
  Its curtains (a row that `seals`, FightSim.curtains): a gap passed while it hunts is sprayed shut behind the
  player after a tell it stands still for; the curtain stops the player, not the warden; two heavy blows break
  one; it keeps two; it crumbles 1.5 s before it falls after its time: `tools/test.sh test_curtains`; seen,
  staged by walking through a lone way in the stones (`near gap`, `walkto gap`), fresh and wet, drying, dry and
  cracked, crumbling, gone, never stippled by the sight cut (GroundColors.HELD): `TOUR_FIXED_FPS=60 tools/tour.sh
  tours/curtains.tour`.
  The line brings the roof down (FightSim.hangings, AbilityGrapple `hanging`): the grapple takes a cracked
  stone hanging ahead and pulls it down; FALL_MS on, it hurts and stalls a machine under it whatever its plate,
  and a player under it: `tools/test.sh test_hanging_fall`.
- 43_cracked_roof: `src/systems/43_cracked_roof.gd`. The cracked roof, at play time with no worldgen (CrackedRoof):
  stones round a cave's tears, over ground a body stands on, the landscape's `collapse` pressure; hung in the fight
  near the player, drawn held in sight with a glowing split, brought down by the line, lying broken, and down for
  good through a save: `tools/test.sh test_cracked_roof`; seen: `TOUR_FIXED_FPS=60 tools/tour.sh
  tours/cracked_roof.tour` (options in its header).
- 45_taken: `src/systems/45_taken.gd`, reached by `tools/tour.sh tours/harvest.tour`.
  Freed by a dark yard or a fallen keeper, and back on a standing holding's books
  (`tools/test.sh test_come_home`; `tools/tour.sh tours/taken_home.tour`, options in its header;
  `tours/escort.tour` walks one to a village).
- 47_defences: `src/systems/47_defences.gd`, reached by `tools/tour.sh tours/defences.tour`.
  A gun sees over its own holding's walls and roofs, not another's (`tools/test.sh test_turret_sight`), and
  answers a raider striking a wall piece before anything else (`tools/test.sh test_turret_answers_the_wall`).
- 48_raids: `src/systems/48_raids.gd`, reached by `tools/tour.sh tours/raids.tour`.
  A probe fought live against a walled yard with covering guns, held (`tools/tour.sh tours/raids_live.tour`,
  options in its header, `--walled`); graded outcomes and the prepared-versus-open bout
  (`tools/test.sh test_raid_live`); hits from several sources land in one window (`tools/test.sh test_hits_stack`).

## How to reach it

- `tools/tour.sh tours/fight.tour`, `tours/targeting.tour`, `tours/sentinels.tour`, `tours/raids.tour`; `--spawn=KIND@DEG` in a shot.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/tour.sh tours/machines.tour
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- A tour `await` means since-last-asked; a latch that passed earlier proves nothing.
- `--spawn` bearings are degrees, 0 east, 90 south.
