extends Node
## Autoload `Events`: the one signal bus between systems that are built in
## parallel and must not import each other. Emit freely; listeners are optional.

## A sound at a place. name is a key the audio system knows (unknown = ignored).
signal sfx(name: StringName, at: Vector3)
## One short line for the player (the HUD shows it, then lets it fade).
signal message(text: String)
## The player has been PUT somewhere rather than walked there: a tour's `place`
## or `at`, dev mode's warp, a realm crossing. Anything showing what is true
## HERE has to let go of what was true THERE — the message line especially,
## which holds a line for 2.2 s and so was still naming the last landscape in
## most of the canon's reference frames. Emitted by whoever moves the body, not
## worked out from how far it went, because a body that is put somewhere is a
## decision and not a distance.
signal warped(to: Vector2)
## A teaching line and the key it is about ("" for none): said now or not at
## all. Unlike `message` it is never queued behind a fight's quiet, so a lesson
## cannot arrive minutes later, out of the moment that earned it. It is dropped
## there, so a lesson whose moment is "the fight is over" waits on
## `Hud.can_teach()` and is never emitted into the quiet.
signal hint(text: String, key: String)
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
## A save was written to `slot` (0 autosave, 1-3 the player's); reason: manual sleep land hours.
signal saved(slot: int, reason: StringName)

## Sentinels (docs/VISION.md): the keeper of a region. `woke` when its body
## first comes out to a player who is near it, `phase` when its body enters
## another phase (the phase itself is announced by the BODY, never by text — this
## is for whoever wants to hear about it), and `fell` when the region is taken,
## naming which of the design's ways did it (SentinelWay.id(): force founder
## starve spoof). A region whose keeper has fallen is a region the plan no longer
## holds; what each package makes of that is its own (docs/VISION.md).
signal sentinel_woke(region: int, land: StringName)
signal sentinel_phase(region: int, phase: StringName)
signal sentinel_fell(region: int, land: StringName, how: StringName)

## Works and landmarks (docs/VISION.md, §3). `works_broken` when a region's
## depot has been put out for good — its lights out, its yard's works spent, and
## nothing more coming out of it (what the plan makes of a region it has lost is
## every other package's own business). `landmark_found` the first time a player
## gets close enough to a place worth the walk for it to go on their map.
signal works_broken(region: int, land: StringName)
signal landmark_found(id: StringName, land: StringName, at: Vector2)

## Settlements (docs/VISION.md). The settlement package emits the first four;
## the raids package emits the rest, so neither has to import the other.
signal settlement_founded(id: int)
signal structure_built(settlement_id: int, structure_id: int)
signal structure_damaged(settlement_id: int, structure_id: int, amount: float)
signal structure_destroyed(settlement_id: int, structure_id: int)
## A machine sensed the place: kind is how (&"worker" &"watcher" &"drone" &"clerk").
signal settlement_noticed(settlement_id: int, mob_id: int, kind: StringName)
signal attention_changed(settlement_id: int, from: float, to: float)
## The world's warning before a step lands, then the step: stage is
## &"survey" &"probe" &"raid" &"siege".
signal raid_warned(settlement_id: int, stage: StringName)
signal raid_began(settlement_id: int, stage: StringName)
## outcome: &"held" &"broken" &"razed" &"left" (nobody was home).
signal raid_ended(settlement_id: int, outcome: StringName)

## The story (docs/STORY.md): a thing read for the first time, a reply chosen,
## a beat of an arc landed. 49_story emits all three; anything may listen.
signal story_found(id: StringName)
signal story_chose(id: StringName, pick: StringName)
signal story_beat(id: StringName)
