# Machines and fighting

Machines on the land, their disposition, depots, keepers, the fight, targeting, defences and raids.

<!-- covers: system:30_mobs, system:32_disposition, system:34_works, system:36_machine_parade, system:40_fight, system:42_target, system:44_sentinels, system:45_taken, system:47_defences, system:48_raids -->

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
- 45_taken `src/systems/45_taken.gd`: `tools/tour.sh tours/harvest.tour`.
  - Freed, back on a holding's books: `tools/test.sh test_come_home`, `tools/tour.sh tours/taken_home.tour` (h); `tours/escort.tour` walks one to a village.
- 47_defences `src/systems/47_defences.gd`: `tools/tour.sh tours/defences.tour`.
  - A gun sees over its own holding's walls, not another's: `tools/test.sh test_turret_sight`; answers a raider at a wall first: `tools/test.sh test_turret_answers_the_wall`.
- 48_raids `src/systems/48_raids.gd`: `tools/tour.sh tours/raids.tour`.
  - A live probe against a walled yard, held: `tools/tour.sh tours/raids_live.tour --walled` (h); graded outcomes, prepared vs open: `tools/test.sh test_raid_live`; hits from several sources in one window: `tools/test.sh test_hits_stack`.

## How to reach it

- The tours above; `--spawn=KIND@DEG` in a shot.

## How to check it

`tools/tour.sh tours/machines.tour` (proof rules: README).

## Gotchas

- A tour `await` means since-last-asked; a latch that passed earlier proves nothing.
- `--spawn` bearings are degrees, 0 east, 90 south.
