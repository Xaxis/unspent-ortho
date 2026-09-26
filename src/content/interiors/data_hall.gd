extends RefCounted
## THE DATA HALL UNDER THE SERVER FIELDS' SUMP (docs/interiors): where the
## machines THINK, as the burning's foundry is where they make. The sump over it
## (landmarks.gd `sump_pump`: "It kept this level dry for somebody. Whatever it
## was keeping out is in here now") is what kept this hall dry and cold, and the
## water it held back is the hall's clock.
##
## Built for machines, not people: aisles of racks to the ceiling, north to
## south, cold air, a hum, lit by nothing but the status points on the racks'
## faces. At the aisles' head, the console the hall answers to, the watcher that
## keeps it, and a sentry head at each aisle's end on the head wall, sweeping.
## Behind bars at the far end, the tape room.
##
## THE HUM COVERS A STEP (InteriorKind.hush): in here a body is heard far less
## far than it is anywhere else. BUT THE AISLES ARE SIGHTLINES, end to end, from
## the head: the racks stand to the ceiling (`screens`), so a sentry sees down
## the aisle it is looking down and nothing else. The quiet way is along the
## south cross-aisle, in the lee of each rack's end, crossing an aisle's mouth
## while the sweep looks down another -- to the tape room. The loud way is up an
## aisle to the watcher at the head: broken, the sentries stand down and the
## tape room's box opens (21_doors, as for the hall).
##
## What the tape room keeps (Interiors.LOOT `data_hall`): the machines' own
## records, always; sometimes a damper (`mod_damp`) -- a hall where the hum
## hides you is where you find what hides your blows.
##
## STORY SLOTS: the console at the head (`terminal:console`), the bay in a rack
## with nothing in it (`wall:restore_bay`), and a paper log in the tape room
## (`desk:paper_log`). Laid in the canonical frame: the way in is in the south
## wall (+y).

const HALL := Rect2i(0, 0, 12, 8)
const TAPES := Rect2i(12, 5, 3, 3)
## The rack rows: their middles across the hall, and where they run from and to.
const ROWS: Array[float] = [2.0, 4.5, 7.0, 9.5]
const ROW_FROM := 2.4
## The rows stop short of the south wall by the cross-aisle a body walks, with
## a body's room past each rack's end.
const ROW_TO := 5.8


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"data_hall"
	k.closed = 1.0
	# The status points are the only light: dim, but a body in an aisle is a
	# shape against a wall of pinpricks.
	k.dark = 0.6
	# The hum.
	k.hush = 0.6
	k.zoom = 12.0
	k.wall_h = 3.2
	k.cut = 1.0
	k.door_width = 1.1
	k.recipe = load("res://src/content/interiors/data_hall.gd")
	k.model = "res://src/models/interior/data_hall_model.gd"
	k.hatch = "res://src/models/interior/hatch_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = &"aisles"
	# Which way the aisles are lit: the racks' points all one colour, or run hot.
	l.dressing = [&"cold", &"warm"][rng.randi_range(0, 1)]
	l.has_hearth = false
	l.rooms.append(HALL)
	l.rooms.append(TAPES)
	l.door = Vector2(1.5, 8)
	l.door_out = Vector2(0, 1)
	l.hearth = Vector2(6.0, 1.2)
	l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(TAPES.position.x + 1.5, TAPES.position.y + 1.5)
	l.lay_edges()
	# The tape room's door off the east aisle, mid-wall: at its south end it came
	# against the hall's own wall and left a body no way to turn into it.
	var tape_door := Vector2(TAPES.position.x, 6.5)
	for e: Dictionary in l.edges:
		var m := ((e.a as Vector2) + (e.b as Vector2)) * 0.5
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner and m.distance_to(tape_door) < 0.1:
			e.kind = &"inner"
	_fit(l, rng)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _fit(l: InteriorLayout, rng: RandomNumberGenerator) -> void:
	var mid := (ROW_FROM + ROW_TO) * 0.5
	var long := ROW_TO - ROW_FROM
	# The rack rows, to the ceiling, faces east and west: each a wall down the
	# hall's length, which is what makes an aisle a sightline and nothing else.
	for x: float in ROWS:
		_put(l, &"rack_row", Vector2(x, mid), Vector2(1, 0), 0.32, {"long": long, "screens": true})
	# The bay with nothing in it, at the south end of one row, facing the
	# cross-aisle a body comes along: the one gap in all of it.
	var bay_x: float = ROWS[1 + rng.randi_range(0, 1)]
	var bay := Vector2(bay_x, ROW_TO + 0.36)
	_put(l, &"restore_bay", bay, Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"wall", "at": bay, "face": Vector2(0, 1)})
	# Floor grates in the cold aisles, breathing up.
	for i in ROWS.size() - 1:
		var ax := (ROWS[i] + ROWS[i + 1]) * 0.5
		_put(l, &"grate", Vector2(ax, mid), Vector2(0, 1), 0.0, {"long": long})
	# The head: the console the hall answers to, on the north wall at a sensor's
	# height, and the watcher that keeps it standing at it, READING it -- its back
	# to the aisles, which the sentries watch; what it has of the hall is what it
	# hears, and the hum takes most of that. Facing down the aisles it had every
	# aisle's mouth in its cone for ever, and no quiet way went anywhere.
	var console := Vector2(6.0, 0.36)
	_put(l, &"console", console, Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"terminal", "at": console, "face": Vector2(0, 1)})
	var post := Vector2(6.0, 1.3)
	_put(l, &"post", post, Vector2(0, -1), 0.0)
	l.residents.append({"role": &"warden", "at": post, "face": Vector2(0, -1)})
	# A sentry at the head of each aisle between two rows, looking straight
	# down it: an aisle is a sightline to its own sentry and to no other, and a
	# rack's lee is behind that rack's end from all of them. Two, off the aisles'
	# lines, saw round a rack's end and down no aisle's middle.
	for i in ROWS.size() - 1:
		_put(l, &"turret", Vector2((ROWS[i] + ROWS[i + 1]) * 0.5, 0.5), Vector2(0, 1), 0.0)
	# The tape room: its box against the far wall, and the paper log on a shelf
	# the racks never read.
	_put(l, &"strongbox", Vector2(TAPES.end.x - 0.52, TAPES.position.y + 1.2), Vector2(-1, 0), 0.36)
	var ledger := Vector2(TAPES.position.x + 1.5, TAPES.position.y + 0.4)
	_put(l, &"paper_log", ledger, Vector2(0, 1), 0.3)
	l.slots.append({"slot": &"desk", "at": ledger, "face": Vector2(0, 1)})
	l.walks.append(PackedVector2Array([l.door, Vector2(1.5, 6.9), Vector2(11.0, 6.9), Vector2(TAPES.position.x + 0.8, 6.5)]))
