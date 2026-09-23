# Scenes

The game, the model gallery and the title.

<!-- covers: scene:gallery, scene:game, scene:title -->

## Sub-features

- gallery: `src/main.gd`, reached by `tools/shot.sh shots/gallery.png --scene=gallery`.
- game: `src/main.gd`, reached by `tools/shot.sh shots/game.png --scene=game`.
- title: `src/main.gd`, reached by `tools/shot.sh shots/title.png --scene=title`.

## How to reach it

- `tools/shot.sh $S/g.png --scene=gallery [--filter=NAME]`, `--scene=title`, `--scene=game`.

## How to check it

Static: `godot --headless --path . --import --quit`; tests under `tests/` named for the package.

Runtime:

```sh
S=<your scratchpad>
tools/shot.sh $S/gallery.png --scene=gallery
```

Proves it when: the command exits 0 and, for a shot or tour, the frames show the thing named (Read them); for a tour, it prints `tour NAME done`.

## Gotchas

- After any model change, shoot the gallery and look.
