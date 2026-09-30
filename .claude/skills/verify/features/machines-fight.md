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
  - A lock holds the body (docs/CONTROLS.md): `tools/test.sh test_lock_on`, `tools/tour.sh tours/lockon_top.tour` and `tours/lockon_shoulder.tour` (h). The lock costs a fight nothing: `tools/heavy.sh tools/test.sh test_ways` fights the Reaper free and then with the target key held, from above (`test_by_force`) and over the shoulder (`test_over_the_shoulder`, the view turned by pointer motion), and holds each locked fight to the free one's tries and LOCKED_MOST of its time. The walk is never bent round the lock; the dodge goes straight.
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
  - Reveal and fall (a keeper's first sight stands at its work for REVEAL_S, once ever, and holds off while the look holds the keys; its fall folds the arch; each staged by one `_stage` call to 42_stage's `look`, `staged()`): `tools/test.sh test_reveal`, `TOUR_FIXED_FPS=60 tools/tour.sh tours/reaper_set_piece.tour` (h; `fell KIND`; claims `sentinel_revealing`, `sentinel_falling` are the stage holding the view); the Reaper foundered in the shallows: `tours/reaper_tide.tour` (h).
  - The Reaper by force (from full health with the steel knife, 20+ blows in its open part over 20+ s on its seed-7 shore; the plate player on seeds 1 and 7, a human's hands, tries carrying its wounds: a tell within 6 s beside it, taken in about three tries; stooped, a grip torn loose slews it half round and jams it, Blow.torn, its chute gear to the player): `tools/test.sh test_reaper_force` (~3 min), `TOUR_FIXED_FPS=60 tools/tour.sh tours/reaper_torn.tour` (h; the keys only after `wound`; `walkto part N run`, claim `torn`).
  - Downed by a keeper, the player comes to at the edge of its ground (Sentinels.arena_edge, 40_fight's downed outcome), and it keeps its wounds: `tools/test.sh test_keeper_downed`.
  - The flats take a keeper that is lured, not one a fight spills onto (its founder hold counts only while it is not spent or stunned; 44_sentinels look_at): `tools/test.sh test_founder_lured`, and the lure itself `TOUR_FIXED_FPS=60 tools/tour.sh tours/reaper_tide.tour` (h).
  - Each way played by a player's actions on seed 1 (the feeds robbed with `use`, the flats reached by walking, the fight fought through the keys by tests/fight/game_driver.gd): `tools/test.sh test_ways` (~4 min). A robbed keeper's feed is gone in `world.depleted` (Sentinels.feeds_a_keeper); a machine at its work is no threat to a take (Survival.threat_near). Played on a fixed step, each way comes out the same at `TEST_FIXED_FPS=20` and `=60` (the fight's windows, the body's tick and the hazards' sweep all run on the physics step); the hitstop and Shift's tap are counted in steps by `tools/test.sh test_fight_clock`, run at both.
  - The second keeper, the anvil, taken by play on seeds 1 and 7 (force from ground its skates keep to, founder by a lure out on the sand far enough for its charge): `tools/heavy.sh tools/test.sh test_anvil_ways` (~4 min). Both games share tests/sentinel/keeper_fight.gd; from above the plate player sees the whole field (the cone is the shoulder view's). Which keeper is second: the nearest of a design not yet taken (Sentinels.next_keeper); once the Reaper is down the survey marks its strike field, the lead says it, and Nell names it the Candlestick: `tools/test.sh test_next_keeper`.
  - The Reaper by force with the keys: `TOUR_FIXED_FPS=60 tools/tour.sh tours/reaper_force.tour --seed=1 --hour=11 --weather=clear:0 --held=knife_shear` (h; `drive READER SECS UNTIL` hands the keys to the plate player and logs tries and seconds; claim `sentinel_way:force`).
  - Every keeper taken apart by the shoulder reader, never pinned or healed (test_fight `_beat`, up to 3 tries): `tools/test.sh test_fight`.
  - A body never trapped by a stair corner it already overhangs (WorldQuery._fits): `tools/test.sh test_movement`.
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
  - A housing broken on a live yard sends its hunters to burn the nearest roof
    (`Reprisal`): on the road, the burned shells, holdfast_price, met on the road:
    `TOUR_FIXED_FPS=60 tools/tour.sh tours/reprisal.tour --seed=1 --hour=9 --weather=clear:0 --held=axe_felling`;
    `tools/test.sh test_reprisal`. A light after dark filed (`seen_light`): `tools/test.sh test_seen_light`.
  - A live probe against a walled yard, held: `tools/tour.sh tours/raids_live.tour --walled` (h); graded outcomes, prepared vs open: `tools/test.sh test_raid_live`; hits from several sources in one window: `tools/test.sh test_hits_stack`.
  - Pacing, played on real frames over the days (seed 1, wild coast): a lit, staffed lean-to and hearth is surveyed about hour 15 and warned past a survey about hour 20; a dark, shuttered one is never read. A worker notices a light as anyone does (the floor gates the raw reading), a filed record is worth NOTICE_FULL by its reader's role, only a quiet holding (dark, masked, spoofed) cools, and creatures hold at most 3 of the coast's 6 places (Spawner.MAX_CREATURES): `TEST_FIXED_FPS=60 tools/heavy.sh tools/test.sh test_raid_pacing` (~13 min), `tools/test.sh test_spawner,test_attention`.

## How to reach it

- The tours above; `--spawn=KIND@DEG` in a shot.

## How to check it

`tools/tour.sh tours/machines.tour` (proof rules: README).

## Gotchas

- A tour `await` means since-last-asked; a latch that passed earlier proves nothing.
- `--spawn` bearings are degrees, 0 east, 90 south.
