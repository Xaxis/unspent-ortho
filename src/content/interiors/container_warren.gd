extends RefCounted
## THE CONTAINER WARREN, behind a door at a blind alley's end in the middens
## (docs/MIDDENS_ROOMS.md §1). The plan poured its heaps over what stood here:
## shipping containers, and now and then a vault. Diggers found them and cut
## through their ends, so a warren is a run of steel boxes inside the wall, one
## opening into the next, entered by the first one's own end doors.
##
## THE FLOOR RINGS. A container's deck is steel (Ground.STEEL_FLOOR), the
## loudest floor in the game: a walk is heard two containers off. Crouch, or pay.
##
## WHO LIVES HERE NOW (the dressing, by hash):
## - `dug`: nobody. Sealed ones, their doors cut with a torch; crates nobody came
##   back for.
## - `kept`: a scavenger's store, with a bedroll and a lamp.
## - `sorted`: the plan's own. The middens' sorter works the warren as a store on
##   the shift (InteriorKind.shift) and at the curfew docks ASLEEP in a
##   container of its own, joined across the run's side: blind, but it hears.
##   The saw hall's rule on a louder floor. The dock is at that container's far
##   end, further from the way than a crouched step on steel is heard and well
##   inside a walked one, so crouching past it is a way and walking is not
##   (test_container_warren).
##
## THE PLAN, by hash: `line` (the run on one level), `step` (the run climbs once,
## a container's height, 5 levels, up a ladder) and `tower` (twice, the vault at
## the top). A tower is dealt only behind a door whose crawl can come up onto
## the plateau (Threshold.exit_at, SlotDoors.exit_beside): its top container has
## a way up through the heap (`crawl_up`, an `exit`), and a known tower is the
## one way up out of the maze there is besides the ramps. The heap was poured over boxes at every height, and a stepped run
## reads from above as a terraced heap of steel. Each rise is a riser with a
## `ladder` thing on it, facing into the lower room (InteriorGen hands the pocket
## the ladder, Climb takes it up and down), where the one below meets the one
## above.
##
## COLLAPSE (the middens' hazard, `collapse`): in about that share of warrens one
## container's roof has buckled over a BAY across its middle, down to BUCKLE_H,
## a `buckled` thing InteriorGen hands the pocket as mass overhead: a crouched
## body passes under it (Tuning.PLAYER_CROUCH_HEIGHT), a standing one does not.
## Never the first container (the way in) nor the last (the sorter's floor).
##
## What the vault keeps (Interiors.LOOT `container_warren`): salvage the machines
## sort for, and rarely a drive.
##
## STORY SLOTS: a container's stencilled manifest (`wall:manifest`), the marks
## scratched inside a kept one (`wall:tally_marks`), and the vault's ledger
## (`desk:vault_ledger`), each opened only where words are written for it in
## the warren's landscape (StoryRooms.words_for), as a squat's is: the things
## stand in the warren either way. Laid in the canonical frame: the way in is the first
## container's end, in the south wall (+y).

## A container, in tiles: its end is the short side, across the run.
const WIDE := 3
const LONG := 6
## The vault, poured concrete, at the far end of the run.
const VAULT := 4
## How many containers a run holds.
const FEWEST := 3
const MOST := 5
## Tiles a container may sit to either side of the one before it: a run that
## was poured, not laid, never lines up, and the joint is always wide enough to
## pass (the end doors are the middle unit of a container's width).
const JOG := 1
## A container's height in levels (2.5 units): each step of a stepped run.
const RISE := 5
## A buckled bay: this many tiles along the run, the roof down to BUCKLE_H over
## the floor (three levels, where a stand needs four and a crouch three).
const BAY := 2
const BUCKLE_H := 1.5
## The sorter's hours, on the clock: the middens' machines sort by day.
const SHIFT := Vector2(6, 19)
## Where the sorter sleeps: in its side container, this far in from the end
## away from the run.
const DOCK_IN := 1.0


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"container_warren"
	# Inside the heap: no sky at all.
	k.closed = 1.0
	# One lamp in a kept warren, the sorter's work lights in a sorted one: the
	# rest is dark to a machine's eye.
	k.dark = 0.85
	k.shift = SHIFT
	k.zoom = 11.0
	# A container is 2.5 units tall.
	k.wall_h = 2.5
	k.cut = 0.9
	# A container's end door.
	k.door_width = 1.2
	# Laid for its landscape, so a slot opens only where its words are written.
	k.by_land = true
	k.by_exit = true
	k.recipe = load("res://src/content/interiors/container_warren.gd")
	k.model = "res://src/models/interior/warren_model.gd"
	k.hatch = "res://src/models/interior/warren_hatch_model.gd"
	return k


static func lay(rng: RandomNumberGenerator, land: int = -1, has_exit: bool = false) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = [&"line", &"step", &"tower"][rng.randi_range(0, 2 if has_exit else 1)]
	l.dressing = [&"dug", &"kept", &"sorted"][rng.randi_range(0, 2)]
	l.has_hearth = false
	var n := rng.randi_range(FEWEST, MOST)
	# A tower keeps its vault at the top.
	var vault := l.plan == &"tower" or rng.randf() < 0.5
	# The containers from which the run stands a RISE higher: none, one, or two.
	var rises: Array[int] = []
	match l.plan:
		&"step":
			rises.append(rng.randi_range(1, n - 1))
		&"tower":
			var r1 := rng.randi_range(1, n - 2)
			rises.append(r1)
			rises.append(rng.randi_range(r1 + 1, n - 1))
	# Laid from the door northward, in negative y, then moved down so the door's
	# wall is the south edge of the first container.
	var boxes: Array[Rect2i] = []
	var x := 0
	var y := 0
	for i in n:
		if i > 0:
			x += rng.randi_range(-JOG, JOG)
		y -= LONG
		boxes.append(Rect2i(x, y, WIDE, LONG))
	var last := boxes[n - 1]
	var vault_rect := Rect2i(last.position.x + WIDE / 2 - VAULT / 2, last.position.y - VAULT, VAULT, VAULT)
	var drop := Vector2i(0, LONG * n + (VAULT if vault else 0))
	var level := 0
	for i in n:
		if rises.has(i):
			level += RISE
		l.rooms.append(Rect2i(boxes[i].position + drop, boxes[i].size))
		l.room_ground.append(Ground.STEEL_FLOOR)
		l.room_level.append(level)
	if vault:
		l.rooms.append(Rect2i(vault_rect.position + drop, vault_rect.size))
		l.room_ground.append(Ground.FLOOR)
		l.room_level.append(level)
	# The sorter's own container, across the side of one in the middle of the
	# run, lying the other way: the rest of the run never reaches its rows.
	if l.dressing == &"sorted":
		var host := l.rooms[n / 2]
		var east := rng.randf() < 0.5
		var sx := host.end.x if east else host.position.x - LONG
		l.rooms.append(Rect2i(sx, host.position.y + 1, LONG, WIDE))
		l.room_ground.append(Ground.STEEL_FLOOR)
		l.room_level.append(l.room_level[n / 2])
	var first := l.rooms[0]
	l.door = Vector2(first.position.x + 1.5, first.end.y)
	l.door_out = Vector2(0, 1)
	l.hearth = Vector2(first.position.x + 1.5, first.position.y + 2.0)
	l.hearth_wall = Vector2(0, -1)
	l.table = l.hearth
	l.lay_edges()
	var open := openings_of(l, n)
	for e: Dictionary in l.edges:
		var m := ((e.a as Vector2) + (e.b as Vector2)) * 0.5
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner:
			for j: Vector2 in open:
				if m.distance_to(j) < 0.1:
					e.kind = &"inner"
	_fit(l, n, vault, rng, land)
	return l


## Where one room opens into another: in the wall between them, the middle unit
## of the part of it the two share. The run's rooms (the containers, then the
## vault) each open into the one before; the sorter's container, last, opens
## into the one it lies across.
static func joints_of(l: InteriorLayout) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var run := l.rooms.size() - (1 if l.dressing == &"sorted" else 0)
	for i in range(1, run):
		var a := l.rooms[i - 1]
		var b := l.rooms[i]
		var lo := maxi(a.position.x, b.position.x)
		var hi := mini(a.end.x, b.end.x)
		out.append(Vector2(floorf((lo + hi) * 0.5) + 0.5, a.position.y))
	if run < l.rooms.size():
		var side := l.rooms[run]
		var x := float(side.position.x) if _east_of_run(l, side) else float(side.end.x)
		out.append(Vector2(x, float(side.position.y) + WIDE * 0.5))
	return out


## Every unit of wall cut open. Between two containers, ALL the wall they share:
## the diggers cut the ends out, and a doorway one unit wide at a jog stands at
## a corner of one of them, where the wall's corner leaves less than a body's
## width (test_container_warren). The sorter's container has its end cut out
## where it meets the run's side, as wide as it is; the vault has its one
## round door.
static func openings_of(l: InteriorLayout, n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(1, n):
		var a := l.rooms[i - 1]
		var b := l.rooms[i]
		for x in range(maxi(a.position.x, b.position.x), mini(a.end.x, b.end.x)):
			out.append(Vector2(float(x) + 0.5, float(a.position.y)))
	var joints := joints_of(l)
	var run := l.rooms.size() - (1 if l.dressing == &"sorted" else 0)
	if run > n:
		out.append(joints[n - 1])
	if run < l.rooms.size():
		var side := l.rooms[run]
		var x := joints[joints.size() - 1].x
		for y in range(side.position.y, side.end.y):
			out.append(Vector2(x, float(y) + 0.5))
	return out


## Whether the sorter's container lies east of the run (its west wall is shared).
static func _east_of_run(l: InteriorLayout, side: Rect2i) -> bool:
	for i in l.rooms.size() - 1:
		if l.rooms[i].end.x == side.position.x:
			return true
	return false


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


## A story slot at a thing, if words are written for it here.
static func _slot(l: InteriorLayout, land: int, slot: StringName, thing: StringName, at: Vector2, face: Vector2) -> void:
	if StoryRooms.words_for(&"container_warren", StringName("%s:%s" % [slot, thing]), land, l.dressing).is_empty():
		return
	l.slots.append({"slot": slot, "thing": thing, "at": at, "face": face})


static func _fit(l: InteriorLayout, n: int, vault: bool, rng: RandomNumberGenerator, land: int) -> void:
	var joints := joints_of(l)
	var run_joints := n - 1 + (1 if vault else 0)
	# The way through: up the middle of each container from joint to joint.
	var way := PackedVector2Array([l.door + Vector2(0, -0.6)])
	for i in run_joints:
		way.append(joints[i] + Vector2(0, 0.8))
		way.append(joints[i] + Vector2(0, -0.8))
		# Where the next room stands higher, a ladder up its riser, at the joint,
		# facing (as every thing does) into the room it stands in, the lower.
		if l.room_level[i + 1] > l.room_level[i]:
			_put(l, &"ladder", joints[i], Vector2(0, 1), 0.0)
	l.walks.append(way)
	# Each container: its manifest stencilled on a side wall, and what is in it.
	for i in n:
		var r := l.rooms[i]
		var side := -1.0 if (i % 2) == 0 else 1.0
		# The container the sorter's own opens off keeps its things on the far
		# wall, clear of that doorway.
		if l.dressing == &"sorted" and i == n / 2:
			side = 1.0 if not _east_of_run(l, l.rooms[l.rooms.size() - 1]) else -1.0
		var wall_x := float(r.position.x) + 0.36 if side < 0.0 else float(r.end.x) - 0.36
		var face := Vector2(-side, 0)
		var mid_y := float(r.position.y) + LONG * 0.5
		if i == 0:
			var plate := Vector2(wall_x, mid_y)
			_put(l, &"manifest", plate, face, 0.0)
			_slot(l, land, &"wall", &"manifest", plate, face)
		match l.dressing:
			&"dug":
				_put(l, &"crate", Vector2(wall_x + face.x * 0.4, mid_y - 1.2), face, 0.4)
				_put(l, &"crate", Vector2(wall_x + face.x * 0.4, mid_y + 1.0), face, 0.4)
			&"kept":
				# A lamp in every container they use: from above, the run reads as
				# a path of warm pools between the rust holes' grey.
				_put(l, &"machine_lamp", Vector2(wall_x, mid_y - 1.6), face, 0.0)
				if i == 1:
					_put(l, &"bedroll", Vector2(wall_x + face.x * 0.5, mid_y), face, 0.0)
					var marks := Vector2(wall_x, mid_y + 1.6)
					_put(l, &"tally_marks", marks, face, 0.0)
					_slot(l, land, &"wall", &"tally_marks", marks, face)
				_put(l, &"crate", Vector2(wall_x + face.x * 0.4, mid_y + 1.8), face, 0.4)
			&"sorted":
				_put(l, &"sorted_bins", Vector2(wall_x + face.x * 0.35, mid_y), face, 0.35, {"glare": 1.2, "shift": true})
	# The buckled bay, by the landscape's collapse share: across the middle of a
	# container that is neither the way in nor the last.
	var d := BiomeRegistry.by_index(land)
	var collapse := float(d.hazards.get(&"collapse", 0.0)) if d != null else 0.0
	if n >= 3 and rng.randf() < collapse:
		var r := l.rooms[rng.randi_range(1, n - 2)]
		var mid := Vector2(float(r.position.x) + WIDE * 0.5, float(r.position.y) + LONG * 0.5)
		_put(l, &"buckled", mid, Vector2(0, 1), 0.0, {"along": float(BAY), "across": float(WIDE), "low": BUCKLE_H})
	# A tower's way up: in its top container, on the wall across from what it
	# holds, a crawl up through the rusted roof into the heap, and out on the
	# plateau beside the alley.
	if l.plan == &"tower":
		var top := l.rooms[n - 1]
		var side := -1.0 if ((n - 1) % 2) == 0 else 1.0
		var wall_x := float(top.end.x) - 0.36 if side < 0.0 else float(top.position.x) + 0.36
		_put(l, &"crawl_up", Vector2(wall_x, float(top.position.y) + LONG * 0.5), Vector2(side, 0), 0.0, {"exit": true})
	# The vault: its round door hung in the joint, and the strongbox at its back.
	if vault:
		var v := l.rooms[n]
		var hinge: Vector2 = joints[n - 1]
		_put(l, &"vault_door", hinge, Vector2(0, 1), 0.0, {"open": rng.randf() < 0.7})
		var box := Vector2(float(v.position.x) + VAULT * 0.5, float(v.position.y) + 0.55)
		_put(l, &"strongbox", box, Vector2(0, 1), 0.36)
		var ledger := Vector2(float(v.position.x) + 0.55, float(v.position.y) + VAULT * 0.5)
		_put(l, &"ledger", ledger, Vector2(1, 0), 0.3)
		_slot(l, land, &"desk", &"vault_ledger", ledger, Vector2(1, 0))
	else:
		# With no vault, what was worth keeping is in the last container's end.
		var e := l.rooms[n - 1]
		_put(l, &"strongbox", Vector2(float(e.position.x) + WIDE * 0.5, float(e.position.y) + 0.55), Vector2(0, 1), 0.36)
	# THE SORTER, in a sorted warren: at its bins in the last container on the
	# shift, docked asleep at the far end of its own container at the curfew.
	if l.dressing == &"sorted":
		var last := l.rooms[n - 1]
		var mid := Vector2(float(last.position.x) + WIDE * 0.5, float(last.position.y) + LONG * 0.5)
		l.residents.append({"role": &"guard", "body": &"sorter", "at": mid, "face": Vector2(0, 1), "on": &"shift"})
		var side := l.rooms[l.rooms.size() - 1]
		var east := _east_of_run(l, side)
		var back := Vector2(-1, 0) if east else Vector2(1, 0)
		var dock := Vector2(float(side.end.x) - DOCK_IN if east else float(side.position.x) + DOCK_IN, float(side.position.y) + WIDE * 0.5)
		_put(l, &"dock", dock, back, 0.0)
		l.residents.append({"role": &"guard", "body": &"sorter", "at": dock, "face": back, "docks": true})
