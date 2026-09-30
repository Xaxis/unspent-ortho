# Scenes

The game, the model gallery and the title.

<!-- covers: scene:gallery, scene:game, scene:title -->

## Sub-features

- gallery `src/main.gd`: `tools/shot.sh shots/gallery.png --scene=gallery`.
- game `src/main.gd`: `tools/shot.sh shots/game.png --scene=game`.
- title `src/main.gd`: `tools/shot.sh shots/title.png --scene=title`. The coast it drifts over is a stand-in, BootPage.TITLE_COAST (256) tiles of the island's own seed; the island itself is raised behind it (RealmWorlds) and New game waits for it on the loading page, which says so if the raise fails: `tools/test.sh test_boot_page,test_teardown`; on the web, `tools/web.sh --quick` (first title frame) and `tools/web.sh --play --dwell=40` (new game after reading the title).

## How to reach it

- `--filter=NAME` narrows the gallery.

## How to check it

`tools/shot.sh $S/gallery.png --scene=gallery` (proof rules: README).

## Gotchas

- After any model change, shoot the gallery and look.
