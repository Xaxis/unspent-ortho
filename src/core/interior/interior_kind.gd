class_name InteriorKind
extends RefCounted
## One kind of enterable structure (docs/interiors): what it is like inside,
## said once, the way a LandmarkDef says a landmark. A recipe under
## src/content/interiors/ makes one (`static func make() -> InteriorKind`) and
## lays its rooms (`static func lay(rng) -> InteriorLayout`, in the canonical
## frame: the entry door in the south wall, facing +y).

var id: StringName = &""
## How far this place is from the sky, 0..1 (SkyLight.closed): a cottage's
## windows let the hour in; a bunker is night at noon. UNDER 0.5 THE SUN STILL
## CASTS (SkyLight stops the sun's shadow at a lid of 0.5), and a room with
## windows needs it to: its own ceiling and walls are what shade it, and the
## patches of sun on its floor are the sun through its windows. At 0.5 the room
## was lit evenly from nowhere, measured.
var closed := 0.4
## The land's view height inside, orthographic: a room fills the frame.
var zoom := 9.0
## Walls' height, and the height the ones facing the camera are CUT at from
## above (a section, drawn as architecture: the room is never hidden by its own
## near wall).
var wall_h := 2.4
var cut := 0.8
## The widest body that fits through the door (a big machine waits outside).
var door_width := 0.9
## The script that lays it (`lay(rng) -> InteriorLayout`).
var recipe: Script
