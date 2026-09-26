extends RefCounted
## THE SAW HALL UNDER THE PINEWOOD'S WORKS (docs/interiors): where the machines
## TAKE, as the coast's weapons hall is where they keep and the foundry where
## they make. The pinewood is "the exact squares the machines cut out of it"
## (content/biomes/pinewood.gd): this is where the squares go. Logs ride a chain
## the length of the north wall into a gang saw and come out as beams so true
## they stack in cubes; the kiln at the far end dries them.
##
## IT KEEPS HOURS (InteriorKind.shift, 05 to 20; outside them, the curfew):
## - ON THE SHIFT the line runs. The saw's howl swallows a step (`hush`), its
##   work lights are the only light (`glare`, `shift`), the warden stands at the
##   saw watching it cut, and a turret over the kiln door sweeps the floor. The
##   haulers are out in the wood.
## - AT THE CURFEW the line stops and goes dark, the warden goes up to walk the
##   wood (pinewood's own wardens keep 20 to 05), and the haulers come home and
##   DOCK ALONG THE SOUTH WALL ASLEEP (21_doors `docks`): blind, but they hear. A
##   body walking upright past them is heard the length of the hall and one
##   wakes and takes it for a thief; crouched, well off the docks, it is not.
##   With no warden standing the turret is down and the kiln's box is open, and
##   the kiln is far enough from the docks that lifting its boards crouched is
##   not heard either; standing, it is.
##
## What the kiln keeps (Interiors.LOOT `saw_hall`): seasoned timber, what a
## settlement's cellar, tower and shutters are built from.
##
## STORY SLOTS: the saw's panel on the north wall (`terminal:saw_panel`) and the
## plate over the docks (`wall:dock_plate`). Laid in the canonical frame: the
## way in is in the south wall (+y).

const HALL := Rect2i(0, 0, 15, 8)
const KILN := Rect2i(15, 2, 3, 5)
## The line: the chain carrying logs in from the west, the gang saw at its end.
const CHAIN_AT := Vector2(4.5, 1.5)
const CHAIN_LONG := 7.0
const SAW_AT := Vector2(9.5, 1.5)
## Where the haulers dock, along the south wall, and where one sleeps in each:
## the west of the hall, far enough from the kiln that its box lifted crouched
## is not heard from them (test_saw_hall).
const DOCKS: Array[float] = [4.4, 6.45, 8.5]
const DOCK_Y := 7.3
const SLEEP_Y := 6.9
## The line along the middle of the hall the kiln's door opens on.
const WAY_Y := 3.0
## The shift, on the clock (InteriorKind.shift).
const SHIFT := Vector2(5, 20)


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"saw_hall"
	k.closed = 1.0
	# Away from the line's lights, dark to a machine's eye; at the curfew, all of it.
	k.dark = 0.8
	# The saw's howl, on the shift.
	k.hush = 0.6
	k.shift = SHIFT
	k.zoom = 12.5
	k.wall_h = 3.6
	k.cut = 1.0
	# A hauler comes in under its load.
	k.door_width = 1.4
	k.recipe = load("res://src/content/interiors/saw_hall.gd")
	k.model = "res://src/models/interior/saw_hall_model.gd"
	k.hatch = "res://src/models/interior/hatch_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = &"take"
	# What the chain brought in last: the kind of pine, which shows in the beams.
	l.dressing = [&"spruce", &"larch", &"black_pine"][rng.randi_range(0, 2)]
	l.has_hearth = false
	l.rooms.append(HALL)
	l.rooms.append(KILN)
	l.door = Vector2(1.5, 8)
	l.door_out = Vector2(0, 1)
	l.hearth = SAW_AT
	l.hearth_wall = Vector2(0, -1)
	l.table = SAW_AT
	l.lay_edges()
	var kiln_door := kiln_door_at()
	for e: Dictionary in l.edges:
		var m := ((e.a as Vector2) + (e.b as Vector2)) * 0.5
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner and m.distance_to(kiln_door) < 0.1:
			e.kind = &"inner"
	_fit(l)
	return l


## The kiln's doorway, in the wall between it and the hall: the middle of a
## unit of wall, a step north of the way.
static func kiln_door_at() -> Vector2:
	return Vector2(KILN.position.x, WAY_Y - 0.5)


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _fit(l: InteriorLayout) -> void:
	# The line, lit only while it runs.
	_put(l, &"log_chain", CHAIN_AT, Vector2(0, 1), 0.45, {"long": CHAIN_LONG, "glare": 1.8, "shift": true})
	_put(l, &"gang_saw", SAW_AT, Vector2(0, 1), 0.9, {"glare": 1.8, "shift": true})
	# What comes out: beams stacked in exact cubes along the north wall past it.
	_put(l, &"beam_stack", Vector2(12.4, 1.4), Vector2(0, 1), 0.7)
	_put(l, &"beam_stack", Vector2(13.7, 1.4), Vector2(0, 1), 0.7)
	# The saw's panel, on the north wall between the saw and the stacks, at a
	# sensor's height.
	var panel := Vector2(11.2, 0.36)
	_put(l, &"saw_panel", panel, Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"terminal", "at": panel, "face": Vector2(0, 1)})
	# The docks along the south wall, and the plate over them.
	for x: float in DOCKS:
		_put(l, &"dock", Vector2(x, DOCK_Y), Vector2(0, -1), 0.0)
	var plate := Vector2(5.42, 7.64)
	_put(l, &"dock_plate", plate, Vector2(0, -1), 0.0)
	l.slots.append({"slot": &"wall", "at": plate, "face": Vector2(0, -1)})
	# The turret high in the north-east corner, over the stacks and the kiln door.
	var c := Vector2(HALL.end.x - 0.6, 0.6)
	_put(l, &"turret", c, (kiln_door_at() + Vector2(-2.0, 0.0) - c).normalized(), 0.0)
	# The kiln: its racks of drying boards and its box.
	_put(l, &"kiln_rack", Vector2(KILN.position.x + 1.5, KILN.position.y + 0.4), Vector2(0, 1), 0.3)
	_put(l, &"strongbox", Vector2(KILN.end.x - 0.52, KILN.position.y + 3.2), Vector2(-1, 0), 0.36)
	# ON THE SHIFT: the warden at the saw, watching it cut, and a hauler at the
	# stacks squaring the beams.
	var post := Vector2(SAW_AT.x, 3.1)
	_put(l, &"post", post, Vector2(0, -1), 0.0)
	l.residents.append({"role": &"warden", "at": post, "face": Vector2(0, -1), "on": &"shift"})
	l.residents.append({"role": &"guard", "body": &"hauler", "at": Vector2(13.0, 2.8), "face": Vector2(0, -1), "on": &"shift"})
	# AT THE CURFEW: a hauler home in each dock, asleep.
	for x: float in DOCKS:
		l.residents.append({"role": &"guard", "body": &"hauler", "at": Vector2(x, SLEEP_Y), "face": Vector2(0, -1), "docks": true})
	# The quiet way at the curfew: up from the hatch and along the middle, a
	# crouched step's hearing and more off every dock (test_saw_hall).
	l.walks.append(PackedVector2Array([l.door, Vector2(l.door.x, WAY_Y), kiln_door_in()]))


## A step inside the kiln's doorway.
static func kiln_door_in() -> Vector2:
	return kiln_door_at() + Vector2(0.8, 0.0)
