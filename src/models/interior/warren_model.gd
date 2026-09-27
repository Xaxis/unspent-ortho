extends "res://src/models/interior/weapons_hall_model.gd"
## THE CONTAINER WARREN, drawn (src/content/interiors/container_warren.gd says
## where everything stands). Shipping containers the heap was poured over, so
## what is drawn is OURS, never the machines': corrugated steel in the faded
## paint of whichever line shipped it, one colour to a container, a ribbed steel
## deck, and a vault of poured concrete at the end of the run. The ends between
## containers are torch-cut, ragged; the way in is a container's own end doors,
## hung open onto the alley at floor level (no stair: a warren is entered from
## the slot, not from above).
##
## Light is the dressing's: a kept warren's one lamp, a sorted warren's bin
## lights. And in every container the roof has rusted through in one place, and
## a thread of the day comes down through the heap onto the deck, as strong as
## the hour on the clock (&"seep", 21_doors): the one light a dug warren has,
## and what a player finds their way by.

## Faded container paint: oxide red, a shipping line's blue, a green, a rust
## orange and a grey, each dulled toward the dark of the heap round it. The
## middens is seventy years under the plan's refuse; nothing here is bright.
const PAINT: Array[Color] = [
	Color(0.29, 0.12, 0.09), Color(0.12, 0.17, 0.25), Color(0.15, 0.21, 0.15),
	Color(0.33, 0.18, 0.09), Color(0.2, 0.2, 0.21),
]
## Corrugations across one unit of wall.
const RIDGES := 6
const RIDGE_DEEP := 0.045
## The vault's poured concrete.
const POURED := Color(0.3, 0.29, 0.27)


func _paint(i: int) -> Color:
	if i < 0 or i >= layout.rooms.size():
		return PAINT[4]
	if layout.rooms[i].size.x == layout.rooms[i].size.y:
		return POURED
	return PAINT[Rng.hash_ints(i, layout.rooms[i].position.x, layout.rooms[i].position.y, 0xC047) % PAINT.size()]


## Which room a wall unit bounds: the one just inside it.
func _room_of(e: Dictionary) -> int:
	var m := ((e.a as Vector2) + (e.b as Vector2)) * 0.5 - (e.out as Vector2) * 0.25
	for i in layout.rooms.size():
		if Rect2(layout.rooms[i]).has_point(m):
			return i
	return -1


func _edge(k: Kit, e: Dictionary, h: float, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var o: Vector2 = e.out
	var along := (b - a).normalized()
	var half := o * THICK * 0.5
	var room := _room_of(e)
	var col := _paint(room)
	var dark := col.darkened(0.45)
	var cap := Color(0.05, 0.05, 0.06)
	var made := GroundColors.ENAMEL if col != POURED else GroundColors.CONCRETE
	match e.kind:
		&"door":
			_end_doors(k, e, h, cut, col)
			return
		&"inner":
			# Torch-cut: the steel's edge left ragged, a lip of it bent back.
			for p: Vector2 in [a, b]:
				var inward := along if p == a else -along
				var n := 5
				for i in n:
					var y0 := h * float(i) / float(n)
					var y1 := h * float(i + 1) / float(n)
					var j := 0.02 + 0.05 * float(Rng.hash_ints(int(p.x * 7.0), int(p.y * 7.0), i, 0x70C) % 3)
					k.made.box(_v(p - half, y0), _v(p + inward * j + half, y1), GroundColors.made(dark, made), GroundColors.made(cap if cut else dark, made))
			return
	# A CORRUGATED UNIT: ridges and troughs across it, the trough set back, every
	# ridge catching the one light the room has. Cut, it stops at `h` with the
	# heap's dark on the cut.
	for r in RIDGES:
		var u0 := float(r) / float(RIDGES)
		var u1 := float(r + 1) / float(RIDGES)
		var trough := (r & 1) == 1
		var inset := -o * (RIDGE_DEEP if trough else 0.0)
		var shade := col.darkened(0.18) if trough else col
		var p0 := a.lerp(b, u0) + inset
		var p1 := a.lerp(b, u1) + inset
		k.made.box(_v(p0 - half, 0.0), _v(p1 + half, h), GroundColors.made(shade, made), GroundColors.made(cap if cut else shade, made))
	# The ridges end under one flat rail, the container's top rail (the cut's
	# dark on a section), so a wall's top reads as a wall and never as teeth.
	var rail := GroundColors.made(cap if cut else dark, made)
	k.made.box(_v(a - half - o * RIDGE_DEEP, h - 0.04), _v(b + half, h + 0.02), rail, rail)
	# Rust where the floor has held water against the wall.
	var sd := Rng.hash_ints(int(a.x * 3.0), int(a.y * 3.0), 0x2057)
	if col != POURED and (sd & 3) == 0:
		var rust := GroundColors.made(Color(0.24, 0.1, 0.05), GroundColors.ENAMEL)
		var f := -o
		k.made.box(_v(a + f * (THICK * 0.5 + 0.004), 0.0), _v(b + f * (THICK * 0.5 + 0.01), 0.25 + 0.2 * float((sd >> 3) & 3)), rust, rust)


## The first container's end doors, swung wide onto the alley: two leaves
## hinged at the frame, their locking bars still on them.
func _end_doors(k: Kit, e: Dictionary, h: float, cut: bool, col: Color) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var o: Vector2 = e.out
	var along := (b - a).normalized()
	var paint := GroundColors.made(col, GroundColors.ENAMEL)
	var bar := GroundColors.made(col.darkened(0.5), GroundColors.ENAMEL)
	var top := h if cut else kind.wall_h
	for p: Vector2 in [a, b]:
		var side := -along if p == a else along
		# The leaf stands open, turned out past square, a door's width long.
		var hinge := p + o * (THICK * 0.5)
		var tip := hinge + (o * 0.35 + side * 0.94).normalized() * 1.0
		k.made.box(Vector3(minf(hinge.x, tip.x) - 0.03, floor_y, minf(hinge.y, tip.y) - 0.03),
			Vector3(maxf(hinge.x, tip.x) + 0.03, floor_y + top, maxf(hinge.y, tip.y) + 0.03), paint, paint)
		for u: float in [0.3, 0.7]:
			var q := hinge.lerp(tip, u)
			k.rod(Vector3(q.x, floor_y + 0.1, q.y), Vector3(q.x, floor_y + top - 0.1, q.y), 0.025, 6, bar)
		# The frame's post.
		k.made.box(_v(p - o * THICK * 0.5 - along * 0.06, 0.0), _v(p + o * THICK * 0.5 + along * 0.06, top), bar, bar)


# --- the floor and the roof -----------------------------------------------------

## Steel deck in the containers, ribbed across; poured concrete in the vault.
func _floor(k: Kit, _tears: Array[Vector2]) -> void:
	for i in layout.rooms.size():
		var r := layout.rooms[i]
		var vault := r.size.x == r.size.y
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var h := Rng.hash_ints(x, y, 0x57EE)
				if vault:
					var c := GroundColors.made(POURED.darkened(0.25 + 0.08 * float(h & 3)), GroundColors.CONCRETE)
					k.slab(x + 0.5, floor_y, y + 0.5, 0.99, DECK_TOP, 0.99, h, c, c, 0.0)
					continue
				var steel := GroundColors.made(Color(0.11, 0.105, 0.1).lerp(Color(0.2, 0.09, 0.05), 0.2 * float(h & 3)), GroundColors.ENAMEL)
				k.slab(x + 0.5, floor_y, y + 0.5, 1.0, DECK_TOP, 1.0, h, steel, steel, 0.0)
				# Ribs down the container's length, a hair proud and barely paler:
				# the deck a boot rings on. Across it, with the slab seams, they read
				# as a flight of steps from over the shoulder.
				var along_x := r.size.x > r.size.y
				for n in 3:
					var t := (float(n) + 0.5) / 3.0
					var rib := GroundColors.made(Color(0.13, 0.125, 0.12), GroundColors.ENAMEL)
					if along_x:
						k.made.box(Vector3(x, floor_y + DECK_TOP, y + t - 0.015), Vector3(x + 1.0, floor_y + DECK_TOP + 0.008, y + t + 0.015), rib, rib)
					else:
						k.made.box(Vector3(x + t - 0.015, floor_y + DECK_TOP, y), Vector3(x + t + 0.015, floor_y + DECK_TOP + 0.008, y + 1.0), rib, rib)
		# Under the rust hole: the flakes that came down through it.
		if not vault:
			var hole := _hole(i)
			var flake := GroundColors.made(Color(0.3, 0.14, 0.07), GroundColors.ENAMEL)
			for n in 5:
				var hh := Rng.hash_ints(i, n, 0xF1A)
				var at := hole + Vector2(float(hh & 255) / 255.0 - 0.5, float((hh >> 8) & 255) / 255.0 - 0.5) * 0.9
				k.stone(at.x, floor_y + DECK_TOP, at.y, 0.06 + 0.06 * float((hh >> 16) & 3), 0.02, hh, flake, 5)


## A container's roof from inside: the same corrugation, overhead, in its paint
## gone dark; the vault's a flat pour.
func _roof(k: Kit, h: float, _tears: Array[Vector2]) -> void:
	var y := floor_y + h
	for i in layout.rooms.size():
		var r := layout.rooms[i]
		var col := _paint(i).darkened(0.55)
		var made := GroundColors.ENAMEL if _paint(i) != POURED else GroundColors.CONCRETE
		var c := GroundColors.made(col, made)
		if _paint(i) == POURED:
			k.made.box(Vector3(r.position.x - THICK * 0.5, y, r.position.y - THICK * 0.5), Vector3(r.end.x + THICK * 0.5, y + 0.08, r.end.y + THICK * 0.5), c, c, true)
			continue
		# The roof tile by tile, less the one the rust has eaten through, whose
		# edges hang down ragged; the day comes down it.
		var hole := _hole(i)
		for x in range(r.position.x, r.end.x):
			for z in range(r.position.y, r.end.y):
				var cc := Vector2(x + 0.5, z + 0.5)
				if cc.distance_to(hole) < 0.1:
					var rust := GroundColors.made(Color(0.26, 0.11, 0.06), GroundColors.ENAMEL)
					for n in 4:
						var hh := Rng.hash_ints(i, n, 0x40E)
						var e := cc + Vector2(float(n % 2) - 0.5, float(n / 2) - 0.5) * 0.8
						k.made.box(Vector3(e.x - 0.14, y - 0.12 - 0.08 * float(hh & 3), e.y - 0.14), Vector3(e.x + 0.14, y + 0.08, e.y + 0.14), rust, rust, true)
					continue
				k.made.box(Vector3(x, y, z), Vector3(x + 1.0, y + 0.08, z + 1.0), c, c, true)
		lights.append([Vector3(hole.x, y + 0.3, hole.y), &"seep"])


## Where a container's roof has rusted through: one tile, dealt by where the
## container stands, never over the joints at its ends.
func _hole(i: int) -> Vector2:
	var r := layout.rooms[i]
	var h := Rng.hash_ints(r.position.x, r.position.y, i, 0x401E)
	var long_x := r.size.x > r.size.y
	var n := r.size.x if long_x else r.size.y
	var along := 1 + (h % maxi(1, n - 2))
	var across := (h >> 8) % mini(r.size.x, r.size.y)
	var t := Vector2i(along, across) if long_x else Vector2i(across, along)
	return Vector2(r.position + t) + Vector2(0.5, 0.5)


# --- what the warren holds ----------------------------------------------------

func _thing(k: Kit, t: Dictionary) -> void:
	var at: Vector2 = t.at
	var f: Vector2 = t.face
	match t.kind:
		&"crate": _crate(k, at, f)
		&"sorted_bins": _bins(k, at, f)
		&"bedroll": _bedroll(k, at, f)
		&"ledger": _ledger(k, at, f)
		&"manifest": _manifest(k, at, f)
		&"tally_marks": _tally(k, at, f)
		&"vault_door": _vault_door(k, at, bool(t.get("open", true)))
		&"machine_lamp": _lamp(k, at, f)
		&"dock": _dock(k, at, f)
		_: super._thing(k, t)


## A crate nobody came back for: boards on a frame.
func _crate(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	var wood := GroundColors.made(Color(0.26, 0.19, 0.12), GroundColors.TIMBER)
	var edge := GroundColors.made(Color(0.17, 0.12, 0.08), GroundColors.TIMBER)
	k.made.box(_v(at - s * 0.4 - f * 0.3, 0.0), _v(at + s * 0.4 + f * 0.3, 0.62), wood, wood)
	for u: float in [-0.4, 0.4]:
		k.made.box(_v(at + s * u - s * 0.03 - f * 0.31, 0.0), _v(at + s * u + s * 0.03 + f * 0.31, 0.64), edge, edge)


## The sorter's bins, in a row: what it has sorted out of the heap by kind, and
## the lamp over them it works by.
func _bins(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	var sd := int(at.x * 11.0 + at.y * 3.0)
	for n in 3:
		var u := float(n - 1) * 0.9
		var c := at + s * u
		var body := GroundColors.made(Color(0.14, 0.15, 0.17), GroundColors.ENAMEL)
		k.made.box(_v(c - s * 0.38 - f * 0.28, 0.0), _v(c + s * 0.38 + f * 0.28, 0.58), body, body)
		# What is in it, heaped a little over the rim: boards, wire, glass.
		var fill: Color = [Color(0.2, 0.28, 0.2), Color(0.35, 0.22, 0.12), Color(0.3, 0.32, 0.36)][(sd + n) % 3]
		k.stone(c.x, floor_y + 0.5, c.y, 0.3, 0.14, sd + n, GroundColors.made(fill, GroundColors.CLAY), 6)
	lights.append([_v(at + f * 0.2, 1.9), &"machine"])


func _bedroll(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	var cloth := GroundColors.made(Color(0.24, 0.23, 0.2), GroundColors.CLOTH)
	var rolled := GroundColors.made(Color(0.2, 0.17, 0.14), GroundColors.CLOTH)
	k.made.box(_v(at - s * 0.9 - f * 0.35, 0.0), _v(at + s * 0.9 + f * 0.35, 0.09), cloth, cloth)
	k.rod(_v(at - s * 0.9 - f * 0.3, 0.14), _v(at - s * 0.9 + f * 0.3, 0.14), 0.12, 8, rolled)


## The vault's ledger on its desk: a steel desk and the book open on it.
func _ledger(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	var steel := GroundColors.made(Color(0.17, 0.17, 0.18), GroundColors.ENAMEL)
	k.made.box(_v(at - s * 0.5 - f * 0.3, 0.0), _v(at + s * 0.5 + f * 0.3, 0.76), steel, steel)
	var page := GroundColors.made(Color(0.62, 0.58, 0.48), GroundColors.CLOTH)
	k.made.box(_v(at - s * 0.2 - f * 0.14, 0.76), _v(at + s * 0.2 + f * 0.14, 0.79), page, page)


## A manifest stencilled on the steel under the paint: a pale panel of ruled
## lines at a person's eye.
func _manifest(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	var pale := GroundColors.made(STENCIL.darkened(0.35), GroundColors.ENAMEL)
	for n in 4:
		var y := 1.3 + 0.12 * float(n)
		var w := 0.5 - 0.08 * float(n % 2)
		k.made.box(_v(at + f * 0.02 - s * w, y), _v(at + f * 0.03 + s * w, y + 0.05), pale, pale)


## Tallies scratched in the paint, in fives.
func _tally(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	var scratch := GroundColors.made(Color(0.5, 0.46, 0.4), GroundColors.ENAMEL)
	for g in 4:
		for n in 5:
			var x := -0.45 + 0.24 * float(g) + 0.035 * float(n)
			if n == 4:
				k.made.box(_v(at + f * 0.02 + s * (x - 0.14), 1.22), _v(at + f * 0.03 + s * x, 1.25), scratch, scratch)
			else:
				k.made.box(_v(at + f * 0.02 + s * x, 1.1), _v(at + f * 0.03 + s * (x + 0.012), 1.36), scratch, scratch)


## The vault's round door, hung open against the wall or shut in its ring.
func _vault_door(k: Kit, at: Vector2, open: bool) -> void:
	var steel := GroundColors.made(Color(0.24, 0.24, 0.25), GroundColors.ENAMEL)
	var ring := GroundColors.made(Color(0.14, 0.14, 0.15), GroundColors.ENAMEL)
	k.hoop(_v(at, 1.05), 0.62, 16, 0.08, ring, Vector3(0, 0, 1))
	var c := at + (Vector2(0.95, 0.35) if open else Vector2.ZERO)
	k.chamfer(c.x, floor_y + 0.42, c.y, 0.3 if open else 1.2, 1.25, 1.2 if open else 0.3, 0.2, steel)


## A kept warren's lamp: a hooded bulb on a hook, the one warm light in the steel.
func _lamp(k: Kit, at: Vector2, f: Vector2) -> void:
	var hood := GroundColors.made(Color(0.18, 0.17, 0.15), GroundColors.ENAMEL)
	var p := at + f * 0.18
	k.rod(_v(at + f * 0.02, 1.95), _v(p, 1.95), 0.015, 4, hood)
	k.made.box(_v(p - Vector2(0.1, 0.1), 1.72), _v(p + Vector2(0.1, 0.1), 1.9), hood, hood)
	lights.append([_v(p, 1.68), &"lamp"])


## Where the sorter docks: a charging plate on the deck and its cable to the wall.
func _dock(k: Kit, at: Vector2, f: Vector2) -> void:
	var plate := GroundColors.made(Color(0.09, 0.09, 0.11), GroundColors.ENAMEL)
	k.made.box(_v(at - Vector2(0.55, 0.55), 0.0), _v(at + Vector2(0.55, 0.55), DECK_TOP + 0.02), plate, plate)
	k.rod(_v(at - f * 0.5, 0.05), _v(at - f * 0.95, 0.05), 0.03, 6, HULL[0])
