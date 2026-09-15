extends Node
## Autoload `Events`: the one signal bus between systems that are built in
## parallel and must not import each other. Emit freely; listeners are optional.

## A sound at a place. name is a key the audio system knows (unknown = ignored).
signal sfx(name: StringName, at: Vector3)
## One short line for the player (the HUD shows it, then lets it fade).
signal message(text: String)
## A blow landed or rang. target is the struck body; plate true = it rang off.
signal hit(attacker: Object, target: Object, damage: int, plate: bool, at: Vector3)
## A fight ended for the player: won | away | downed | carried.
signal fight_ended(outcome: StringName)
## A machine or creature died. kind is the roster id.
signal killed(kind: StringName, at: Vector3)
## The player took something from the world or made something.
signal took(item: StringName, count: int)
signal made(item: StringName, count: int)
## World clock jumped deliberately (sleep, work, carried off).
signal time_skipped(minutes: float, reason: StringName)
## A screen opened or closed (ui); gameplay input should pause while one is open.
signal screen_changed(name: StringName, open: bool)
