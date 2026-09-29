# Survival, gear and building

Taking from the world, hunger and weather, hazards, tracks, gear and abilities, the economy, crafts, settlements.

<!-- covers: system:44_crafts, system:46_settlements, system:50_survival, system:51_harvest, system:52_hazards, system:52_survival_fx, system:53_tracks, system:54_gear, system:56_economy -->

"(h)" means the tour's header has its options. A power's test prints its bout.

## Sub-features

- 44_crafts `src/systems/44_crafts.gd`: `tools/tour.sh tours/crafts.tour`.
- 46_settlements `src/systems/46_settlements.gd`: `tools/tour.sh tours/settlements.tour`.
  - Footing (`WorldQuery.flat_footing`): `tools/test.sh test_system:test_a_piece_goes_up_on_ground`, `test_system:test_nothing_goes_up_astride`; on rugged land `tools/shot.sh shots/x.png --seed=7 --place=bonelands --holding=hearth,hut,plot,palisade,store` stands all five, no "no room" warning.
  - Unstaffed piece says why: `tools/test.sh test_staff_reason`, `tools/tour.sh tours/staff_reason.tour` (settlements.tour's options).
  - Carried off near your holding wakes at its hearth: `tools/tour.sh tours/carried_home.tour`.
  - Building raises interference by loudness: `tools/test.sh test_noticed`, `tours/built_noticed.tour`.
  - Gate (walked through, breached first): `tools/test.sh test_gate`, `tools/shot.sh shots/x.png --scene=gallery --filter="holding gate"`.
  - Cellar (stores a raid cannot take): `tools/test.sh test_cellar`, gallery `--filter="holding cellar"`.
  - Stolen cell (unlocked by a keeper's core): `tools/test.sh test_unlocks`, gallery `--filter="holding stolen cell"`.
- 50_survival `src/systems/50_survival.gd`: `tools/tour.sh tours/survival.tour`. Sleep is asked for, never one press: an idle `use` at rest asks ("Again, and you sleep till morning.", the target reads `fire - sleep?`) and a second within BUILD_ASK_SECONDS sleeps; eating stays the fallback when hungry: `tools/test.sh test_first_hour:test_one_stray,test_taking,test_condition`, and the two-press sleep in `tours/core_loop.tour` and `tours/home-coast.tour`.
  - The bag left on a heap where you were carried off ("your things"): `tools/test.sh test_bag_heap`, `tools/tour.sh tours/bag_heap.tour` (h).
- 51_harvest `src/systems/51_harvest.gd`: `tools/tour.sh tours/harvest.tour`.
- 52_hazards `src/systems/52_hazards.gd`: `tools/tour.sh tours/hazards.tour`.
  - At eye level no cue draws over the body: `tools/test.sh test_shoulder:test_no_hazard`, `tools/tour.sh tours/cue_eye.tour` (h).
- 52_survival_fx `src/systems/52_survival_fx.gd`: `tools/tour.sh tours/survival.tour`.
- 53_tracks `src/systems/53_tracks.gd`: `tools/tour.sh tours/tracks.tour`.
- 54_gear `src/systems/54_gear.gd`: `tools/tour.sh tours/gear-economy.tour`. Each piece's rule: docs/GEAR.md §5-§6.
  - Glide off a deep drop falls the rest: `tools/test.sh test_abilities:test_a_glide_off_a_deep_drop`, `tools/tour.sh tours/glide_fall.tour` (h; `ledge glide`, claim `falling_out`).
  - Scale coat: `tools/test.sh test_scale_coat`, `tools/tour.sh tours/scale_coat.tour` (h).
  - Hush wrap: `tools/test.sh test_hush_wrap`, `tools/tour.sh tours/hush_wrap.tour`.
  - Vane cloak: `tools/test.sh test_vane_cloak`, `tools/tour.sh tours/vane_cloak.tour` (in a storm).
  - Ploughshare: `tools/test.sh test_ploughshare`, `tools/tour.sh tours/ploughshare.tour` (h; claim `share_turned`).
  - Cable line: `tools/test.sh test_cable_brace`, `tools/tour.sh tours/cable_brace.tour` (h).
  - A scan over a dart says "It takes and goes. Break its sight.": `tools/test.sh test_abilities:test_a_scan_says`, `tools/tour.sh tours/scan_dart.tour` (h).
  - Lattice at a gate: `tools/test.sh test_lattice_icelens:test_the_lattice_at_a_gate`.
  - Undertow: `tools/test.sh test_undertow`, `tools/tour.sh tours/undertow.tour` (h).
  - Rake: `tools/test.sh test_rake`, `tools/tour.sh tours/rake.tour` (h).
  - Anchor (a grip on a rooted body snaps back, stalling its gripper): `tools/test.sh test_anchor`, `tools/tour.sh tours/anchor.tour` (h).
  - Veil (drip_core, back; a curtain of water sight does not pass for 12 s; a dart it cuts off leaves with its flock; soaks you, lamp out): `tools/test.sh test_veil` (bout prints), `TOUR_FIXED_FPS=60 tools/tour.sh tours/veil.tour` (h).
  - Lock: `tools/test.sh test_lock`, `tools/tour.sh tours/lock.tour` (h).
  - Ear: `tools/test.sh "test_listen,test_shoulder:test_no_hazard"`, `tools/tour.sh tours/ear.tour` (h; `spawn KIND beyond PROP`, `tell KIND`).
  - Plumb: `tools/test.sh test_plumb`, `tools/tour.sh tours/plumb.tour` (h).
  - Unbuilder's hands: `tools/test.sh test_unbuild`, `tools/tour.sh tours/unbuild.tour` (h).
  - A keeper's core as a choice: `tools/test.sh test_rules:test_a_keepers_core`, `tools/tour.sh tours/core_choice.tour` (h).
- 56_economy `src/systems/56_economy.gd`: `tools/tour.sh tours/gear-economy.tour`.
  - Salvage key ("take apart the X"): `tools/test.sh test_salvage_key`, `tools/tour.sh tours/salvage.tour` (h).

## How to reach it

- The tours above; `--give=ID:N --held=ID` in a shot.

## How to check it

`tools/tour.sh tours/crafts.tour` (proof rules: README).

## Gotchas

- A hazard claim needs its weather staged (`--weather=`); `clear:0` hides it.
