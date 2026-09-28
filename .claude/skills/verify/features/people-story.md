# People and story

The player's own body, villagers, fauna, named cast, the story's talks and fragments.

<!-- covers: system:33_avatar, system:35_folk, system:37_fauna, system:48_wake, system:49_cast, system:49_story -->

## Sub-features

- 33_avatar `src/systems/33_avatar.gd`: `tools/tour.sh tours/character.tour`.
- 35_folk `src/systems/35_folk.gd`: `tools/tour.sh tours/locals.tour`.
- 37_fauna `src/systems/37_fauna.gd`: `tools/tour.sh tours/wild.tour`.
- 48_wake `src/systems/48_wake.gd` (the first morning in the surf, `src/core/story/wake_spot.gd`): `tools/tour.sh tours/home-coast.tour --scene=title --seed=1`, the slice's proof tour from the title (frames 01-03), and `tools/test.sh test_wake`. Only a player's new game wakes (the title's, dev play, or `--wake`); a game booted straight into the world starts dry at the spawn. Then Maren's first lead: her talk's `lead` node lands `marens_lead`, and the first hour's goals are said in her words (`Guide._led`, `StoryContent.LEAD`): `tools/test.sh test_guide_lead`, and `tours/home-coast.tour` frames 05-07. Then Hob names the yard and its keeper (`hob.reaper`, beat `reaper_named`): the steel edge's goal and the ring line are his words by the name he gave it (`Guide.edge_line`, `Guide.keeper_name`, `StoryContent.EDGE`/`KEEPER_NAMED`): `tools/test.sh test_reaper_named`, and `tours/home-coast.tour` frames 08-09 (run it with `TOUR_FIXED_FPS=60`). And when the Reaper falls: the record says what was seen of it falling (`StoryContent.KEEPER_FELL`, never the way's tactic hint), `reaper_down` lands (`KEEPER_DOWN`), the yard goes dark after it (`YARD_DARK`, `Events.yard_left_dark`) and only then do the held walk out (45_taken); Maren and Hob answer it (`maren.dark`, `hob.quiet_pipes`): `tools/test.sh test_reaper_down`. Then the road to the camp (slice 2, step 1): with her lead given and iron in the bag the goal is the crew (`Guide.camp_goal`, `LEAD.camp`) until Rook is met; the survey marks the places a person has told him of (`StoryContent.TOLD`, `UiMapScreen.told`), pinned at the glass's edge on their bearing when off it (`UiMapScreen.pin`); Rook says he was paid (`crew_paid`) and keeps the note until `echo_hulls`: `tools/test.sh test_road_to_camp,test_arcs`, and `tools/tour.sh tours/road-to-camp.tour --seed=1 --hour=11 --weather=clear:0 --beats=marens_lead --give=pick:1,iron_ore:1` frames 01-05.
- 49_cast `src/systems/49_cast.gd`: `tools/tour.sh tours/cast.tour`.
- 49_story `src/systems/49_story.gd`: `tools/tour.sh tours/story.tour`.
  - Room words (StoryRooms, `StoryContent.ROOMS`, read with `use` inside): `tools/tour.sh tours/bunker_words.tour --seed=4 --hour=15 --weather=clear:0`, `tests/story/test_rooms.gd`.
  - His bunker's gated terminal and the tenants per bunker (`StoryRooms.tenants`): `tools/tour.sh tours/bunker_woken.tour --seed=4 --hour=15 --weather=clear:0 --beats=built_halcyon`, `tests/story/test_under_the_stones.gd`.

## How to reach it

- The tours above; `--talk=ID` / `--read=ID` in a shot.

## How to check it

`tools/tour.sh tours/character.tour` (proof rules: README).

## Gotchas

- Every story line is bound by `docs/STORY.md`.
