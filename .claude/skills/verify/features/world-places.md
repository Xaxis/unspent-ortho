# World places

Realms and portals, the rooms behind a house's door, landmarks and caches, regional holds.

<!-- covers: system:20_realms, system:21_doors, system:22_landmarks, system:24_holds -->

## Sub-features

- 20_realms: `src/systems/20_realms.gd`, reached by `tools/tour.sh tours/realms.tour`.
- 21_doors: `src/systems/21_doors.gd`, reached by `tools/tour.sh tours/house.tour --seed=4 --hour=11 --weather=clear:0`: a coast house's door, the room behind it (a pocket world, `src/core/interior/`, `src/models/interior/`), both views, and out again.
- 22_landmarks: `src/systems/22_landmarks.gd`, reached by `tools/tour.sh tours/landmarks.tour`.
- 24_holds: `src/systems/24_holds.gd`, reached by `tools/tour.sh tours/region.tour`.

## How to reach it

- `tools/tour.sh tours/realms.tour`, `tours/house.tour`, `tours/rooms.tour --seed=4 --hour=15 --weather=clear:0`, `tours/hall.tour --seed=4 --hour=11 --weather=clear:0 --rooms=empty` (a depot's hatch and the weapons hall under it), `tours/hall-fight.tour --seed=4 --hour=11 --weather=clear:0` (its residents turn, a blow lands, the warden's arrest puts you out at the hatch), `tours/hall-guard.tour --seed=4 --hour=11 --weather=clear:0` (a strongbox shut while the warden stands, a turret's sighting lines), `tours/hall-sneak.tour --seed=4 --hour=11 --weather=clear:0` (down the hatch crouched and to a strongbox unarrested, by the way `walkto strongbox` picks out of sight), `tours/bunker.tour --seed=4 --hour=15 --weather=clear:0` (the hatch among the cast stones and the bunker under it, from above, by the lantern and over the shoulder), `tours/roundhouse.tour --seed=4 --hour=15 --weather=clear:0` (a crags roundhouse and the round room behind it: `form:ID` hosts, by day, by its fire at night and over the shoulder), `tours/stilt.tour --seed=4 --hour=15 --weather=clear:0` (a drowned city stilt house and its room over the water), `tours/lobby.tour --seed=4 --hour=15 --weather=clear:0` (a metropolis infill and the tower lobby lived in behind it), `tours/cliff.tour --seed=4 --hour=15 --weather=clear:0` (a mesas cut room and the room dug into the rock behind its front wall), `tours/hulk.tour --seed=4 --hour=15 --weather=clear:0` (a drowned city hulk and the hold under its deck), `tours/rooted.tour --seed=4 --hour=15 --weather=clear:0` (a Green Towers shell and the fallen tower's standing floor the forest came up through), `tours/tenement.tour --seed=4 --hour=15 --weather=clear:0` (a slums tower's stair hall, its corridor of numbered doors and the one flat left open; `near thing:KIND` stands by a room's thing), `tours/maintenance.tour --seed=4 --hour=15 --weather=clear:0` (a machine city block's service hatch and the bay one machine is kept in, dark but for its standby points, and the niche somebody lives in), `tours/foundry.tour --seed=4 --hour=15 --weather=clear:0` (the burning's depot hatch and the foundry under it, the line pouring, the cooling racks), `tours/foundry-sneak.tour --seed=4 --hour=15 --weather=clear:0` (down crouched and behind the racks to the store unnoticed), `tours/foundry-light.tour --seed=4 --hour=15 --weather=clear:0` (a whole sweep behind the racks unshot, then a turret fires in the pour's light: InteriorKind.dark, a thing's `glare`, `screens`; `near behind:KIND`; rules in `tools/test.sh test_foundry`), `tours/datahall.tour --seed=4 --hour=15 --weather=clear:0` (the server fields' sump and the data hall under it: aisles of racks by their status points, the console and its watcher, a sentry down each aisle, the tape room), `tours/datahall-hum.tour --seed=4 --hour=15 --weather=clear:0` (to the tape room upright, unnoticed; the hum itself, InteriorKind.hush, in `tools/test.sh test_data_hall`), `tours/laid_table.tour --seed=4 --hour=12.5 --weather=clear:0` (a grey orchards grower's house the machines keep: the table laid, the food hatch and its plate, a meal taken at `near hatch`; the schedule, once-a-meal, the save and the tray in `tools/test.sh test_laid_table`), `tours/sawhall.tour --seed=4 --hour=12 --weather=clear:0` (the pinewood's works hatch and the saw hall under it on the shift: the line running lit and loud, the warden at the gang saw), `tours/sawhall-night.tour --seed=4 --hour=23 --weather=clear:0` (at the curfew: the line dark, three haulers asleep in their docks, crouched to the kiln and its seasoned timber with none woken: InteriorKind.shift, MobState.asleep, `docks`), `tours/sawhall-wake.tour --seed=4 --hour=23 --weather=clear:0` (the same way upright: a sleeper wakes and turns; rules in `tools/test.sh test_saw_hall`), `tours/frozenhold.tour --seed=4 --hour=23 --weather=clear:0 --give=driftwood:3` (the frost sea's leaning mast and the trawler's hold under it, cold: the ice in at the seams, the machines' cable down through her bottom; the stove relit with `near stove`, and the hold warm; `fuel`, `stove_fuel`, the cold and sleep before and after in `tools/test.sh test_frozen_hold`), `tours/landmarks.tour`, `tours/region.tour`.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/tour.sh tours/realms.tour
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- Stage by name (`place NAME`, `near KIND`), never by a copied coordinate.
- A door's cost is `tests/interior/test_doors.gd`: it prints the swap in and out, best and worst of three trips, and fails a stall over 250 ms. Read the house tour's 02 and 04 side by side: the patch of sun on the boards must have moved between them.
- `tours/rooms.tour` stages three rooms by who lives there (`near door:fisher|tinker|keeper`, claimed `room:...`): read the three frames side by side; no two may be the same room. `tests/interior/test_interiors.gd` walks the real query from every door on seed 4 to its hearth, table and bed.
- A landscape's own building form can keep its own room (`BiomeDef.interiors` `form:ID`, looked up before `house`): `tests/interior/test_interiors.gd` holds that every house opens on its own form's room (the crags' roundhouse, the drowned city's stilt house, the metropolis infill, the mesas' cut room, the drowned city's hulk, Green Towers' shell), and walks each to what is in it.
- Indoors, the systems that keep the outside sleep (`indoors(inside)`, 20_realms) rather than re-reading it; a new system that keeps per-world state and does not declare `indoors` is still correct, only slower through a door.
