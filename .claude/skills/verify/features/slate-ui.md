# The slate

The hacked tablet and every app on it: map, carrying, making, gear, reads, journal, holding, saves, settings, pause, character.

<!-- covers: screen:character, screen:crafting, screen:inventory, screen:journal, screen:loadout, screen:map, screen:pause, screen:reads, screen:saves, screen:settings, screen:settlement, screen:sheet, system:58_guide, system:90_ui -->

## Sub-features

- character `src/ui/ui_character_screen.gd`: `tools/tour.sh tours/character.tour` (opens from the title's New game, not in play).
- crafting `src/ui/ui_crafting_screen.gd`: `tools/shot.sh shots/crafting.png --screen=crafting`. Its "within reach" row at the foot is the long game's next elite material or part and where (`Guide.within_reach`), never the goal line: `tools/tour.sh tours/late_goal.tour --seed=7 --hour=11 --weather=clear:0 --give=pick:1,iron_ore:1` frame 02, and `tools/test.sh test_guide:test_past_the_pick,test_foundry`.
- inventory `src/ui/ui_inventory_screen.gd`: `tools/shot.sh shots/inventory.png --screen=inventory`.
- journal `src/ui/ui_journal_screen.gd`: `tools/shot.sh shots/journal.png --screen=journal`.
- loadout `src/ui/ui_loadout_screen.gd`: `tools/shot.sh shots/loadout.png --screen=loadout`.
- map `src/ui/ui_map_screen.gd`: `tools/shot.sh shots/map.png --screen=map`.
- pause `src/ui/ui_pause_screen.gd`: `tools/shot.sh shots/pause.png --screen=pause`.
- reads `src/ui/ui_reads_screen.gd`: `tools/shot.sh shots/reads.png --screen=reads`.
- saves `src/ui/ui_saves_screen.gd`: `tools/shot.sh shots/saves.png --screen=saves`.
- settings `src/ui/ui_settings_screen.gd`: `tools/shot.sh shots/settings.png --screen=settings`.
- settlement `src/ui/ui_settlement_screen.gd`: `tools/shot.sh shots/settlement.png --screen=holding`.
- sheet `src/ui/ui_sheet_screen.gd`: `tools/shot.sh shots/sheet.png --screen=sheet`.
- 58_guide `src/systems/58_guide.gd` (goal line and key row at wake, then each hint in its moment, retired once used; off in every shot). The goal line is his purpose (`Guide._goal_of`): a real need, the edge a keeper rang off, the open story lead's next step keyed on story state (any pick of `Guide.PICKS` counts as Maren's pick; Hob's `reaper` after reaper_named; the crew's `crew` after reaper_down), else empty, never a recipe ladder; `tools/test.sh test_goal_purpose`, and every tour logs `tour goal LABEL [KEY] LINE` at each shot: `tools/tour.sh tours/guide.tour --seed=1 --hour=9 --weather=clear:0 --fit=glide_wing`, `tours/feel.tour` frame `01-wake-the-goal`; `tools/test.sh test_hud,test_slate_says`.
- 90_ui `src/systems/90_ui.gd`: `tools/tour.sh tours/slate.tour`. Tour claim `goal:KEY`: the pinned goal is Guide's line keyed KEY (`Guide.last_goal_key`), in whoever's words: `tools/test.sh test_goal_claim`.

## How to reach it

- `tools/shot.sh $S/x.png --seed=7 --screen=NAME`.

## How to check it

`tools/shot.sh $S/map.png --seed=7 --screen=map` (proof rules: README).

## Gotchas

- A shot cannot show the guide line; use a tour for that.
- Every number in `src/ui/` is in 1920x1080 base pixels.
