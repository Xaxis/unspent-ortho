# Machines and fighting

Machines on the land, their disposition, depots, keepers, the fight, targeting, defences and raids.

<!-- covers: system:30_mobs, system:32_disposition, system:34_works, system:36_machine_parade, system:40_fight, system:42_target, system:43_cracked_roof, system:44_sentinels, system:45_taken, system:47_defences, system:48_raids -->

"(h)" means the tour's header has its options.

## Sub-features

- 30_mobs `src/systems/30_mobs.gd`: `tools/tour.sh tours/machines.tour`.
- 32_disposition `src/systems/32_disposition.gd`: `tools/tour.sh tours/disposition.tour`.
  - Relic heat (GEAR.md G9): `tools/test.sh test_relic_heat`, `tools/tour.sh tours/relic_heat.tour` (h).
- 34_works `src/systems/34_works.gd`: `tools/tour.sh tours/works.tour`.
- 36_machine_parade `src/systems/36_machine_parade.gd`: `tools/tour.sh tours/machines-day.tour`.
- 40_fight `src/systems/40_fight.gd`: `tools/tour.sh tours/fight.tour`.
  - Height (a 2-level ledge stands bodies out of each other's blows): `tools/test.sh test_height`.
  - Climbing: `tools/test.sh test_climb`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/climb.tour` (h).
  - Vertical grapple (a face up to 8 levels): `tools/test.sh test_vertical_grapple`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/vertical_grapple.tour` (h).
  - Drop strike: `tools/test.sh test_drop_strike`, `tools/tour.sh tours/drop_strike.tour` (h).
  - Heavy blow (swing held 300 ms; time-to-kill prints): `tools/test.sh "test_heavy,test_bouts"`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/heavy_blow.tour`.
  - Bite ground ring: `tools/test.sh test_tell_ring`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/bite_ring.tour`.
  - Thrower (Brains `throw`): `tools/test.sh test_throw`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/thrower.tour` (h).
  - Dropper (Brains `drop`, told by its shadow): `tools/test.sh test_dropper`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/dropper.tour` (both views; `over KIND` stages a body on a lip).
  - Ten awake machines' draw cost: `tools/test.sh test_awake_cost`.
  - Crags rings (HUSH.md H1): `tools/test.sh test_hush_hold`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/hush_hold.tour --seed=7 --hour=11 --weather=clear:0`.
  - No hopeless matchup (GEAR.md §9; crowd and shoulder readers in `tests/fight/`): `tools/test.sh test_matchups` (~35 s); crowd vs one-machine reader: `tools/test.sh test_crowd_reader`.
  - Part sides (a landscape's `over` part): `tools/test.sh test_part_sides`, `tools/shot.sh shots/x.png --scene=gallery --filter=sides_hauler --zoom=4`, `tools/tour.sh tours/part_sides.tour` and `tours/part_sides_cave.tour` (h).
  - Night hearing: `tools/test.sh test_first_meetings:test_by_night` prints day and night distances.
  - Contact (roster `touch`, `touch_arc`; a sweeper brushes only at its front): `tools/test.sh test_touch`.
  - Attack slots (two after the player, one bite at a time, a charge counts; waiters feint at the edge; a free slot to a kind not in one; a crowd shares its sight and breaks when one is left or its leader falls first): `tools/test.sh test_attack_slots`; numbers: `tools/sweep.sh --crowds [--reader=human]`.
  - Unseen bites (in a crowd, one begun beyond 60 deg of the facing is told 2x long and cued: a call from its bearing, a rust chevron at the slate's edge): `tools/test.sh test_attack_slots`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/unseen.tour` (h; `behind KIND`).
- 42_target `src/systems/42_target.gd`: `tools/tour.sh tours/targeting.tour`.
  - A lock holds the body (docs/CONTROLS.md): `tools/test.sh test_lock_on`, `tools/tour.sh tours/lockon_top.tour` and `tours/lockon_shoulder.tour` (h).
- 44_sentinels `src/systems/44_sentinels.gd`: `tools/tour.sh tours/sentinels.tour`.
  Its fall (the yard dark after it, its stations dark, the ground closing over):
  `tools/tour.sh tours/keeper-fall.tour --seed=1 --hour=22 --weather=clear:0 --fallen=coast:72`
  and `tools/test.sh test_fall_changes_the_coast`.
  - Plough (snowfield keeper, furrows): `tools/test.sh test_plough`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/plough.tour` (h).
  - Every keeper a boss to the shoulder reader (won 18+/24, 25-45 s, 2+ health lost): `tools/test.sh test_keeper_bouts` (~50 s).
  - Come-round: `tools/test.sh test_come_round`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/come_round.tour` (h).
  - Reach (`NavField.for_body`, `Brains._hunt`, `Sentinels.lair`): `tools/test.sh test_keeper_reach` (~2 min).
  - Roused (faces you within 3 s of a hit): `tools/test.sh test_keeper_roused` (~2.5 min).
  - Breaks through a wood (`FightSim._break_through`): `tools/test.sh test_keeper_breaks`; as a player: `TOUR_FIXED_FPS=60 tools/tour.sh tours/plough_wood.tour` (h).
  - Drip-warden and headroom (no roofed landscape's body over 80% of its halls): `tools/test.sh test_keeper_headroom`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/drip_warden.tour` (h; `near mob:KIND DIST`).
  - Its curtains (FightSim.curtains: a gap passed while it hunts sprayed shut after a tell; fresh, drying, dry, crumbling): `tools/test.sh test_curtains`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/curtains.tour` (`near gap`, `walkto gap`).
  - The line brings a cracked stone down on what is under it (FightSim.hangings): `tools/test.sh test_hanging_fall`.
  - Plating (roster `plating`, FightRules.bites; the Tide Reaper is steel, so the iron knife rings off and the goal turns to the steel edge until it falls, Guide.edge_goal): `tools/test.sh "test_plating,test_edge_goal"`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/reaper_plating.tour` (h).
  - Reveal and fall (a keeper's first sight stands at its work for REVEAL_S, once ever; its fall folds the arch; each staged by one `_stage` call to 42_stage's `look`, `staged()`): `tools/test.sh test_reveal`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/reaper_set_piece.tour` (h; `fell KIND`); the Reaper foundered in the shallows: `tours/reaper_tide.tour` (h).
- 43_cracked_roof `src/systems/43_cracked_roof.gd` (stones round a cave's tears, hung, drawn held, brought down by the line, down for good through a save): `tools/test.sh test_cracked_roof`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/cracked_roof.tour` (h).
- 45_taken `src/systems/45_taken.gd`: `tools/tour.sh tours/harvest.tour`.
  The 71 hours (whole, empty, gone): `tools/test.sh test_clock` and
  `tools/tour.sh tours/rescue-late.tour --seed=1 --hour=11 --weather=clear:0 --held=axe_felling --carried=1:80`.
  - Freed, back on a holding's books: `tools/test.sh test_come_home`, `tools/tour.sh tours/taken_home.tour` (h); `tours/escort.tour` walks one to a village.
- 47_defences `src/systems/47_defences.gd`: `tools/tour.sh tours/defences.tour`.
  - A gun sees over its own holding's walls, not another's: `tools/test.sh test_turret_sight`; answers a raider at a wall first: `tools/test.sh test_turret_answers_the_wall`.
- 48_raids `src/systems/48_raids.gd`: `tools/tour.sh tours/raids.tour`.
  The villages that have seen him (35_folk `seen_by`, `SnatchNight`):
  `tools/test.sh test_seen_taken,test_snatch_night`.
  - A live probe against a walled yard, held: `tools/tour.sh tours/raids_live.tour --walled` (h); graded outcomes, prepared vs open: `tools/test.sh test_raid_live`; hits from several sources in one window: `tools/test.sh test_hits_stack`.

## How to reach it

- The tours above; `--spawn=KIND@DEG` in a shot.

## How to check it

`tools/tour.sh tours/machines.tour` (proof rules: README).

## Gotchas

- A tour `await` means since-last-asked; a latch that passed earlier proves nothing.
- `--spawn` bearings are degrees, 0 east, 90 south.
