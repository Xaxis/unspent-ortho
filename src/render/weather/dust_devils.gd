class_name DustDevils
## Dust devils: whirls of grit that spin up on hot, dusty ground, wander a few
## tiles with the wind and die. Pure in (seed, world minute, focus), so a shot
## repeats and a test can count them; WeatherView draws each as a spinning column
## of marks (precip.gdshader SWIRL).
##
## The land is cut into CELL-tile cells; in each epoch of LIFE minutes a cell may
## raise one devil at a seeded point, which drifts along `bearing` over its life.
##
## In real dust (DUSTY and over) a devil is always in sight: when none of the
## cells' devils is on screen, a "home" devil spins up in view (keep_one), and
## the sky system keeps it until it has lived its life, so one never pops in or
## out where the player is looking.

const CELL := 18.0
const LIFE := 22.0
## Drawn at most this many at once (nearest the focus).
const MAX := 3
## Tiles a devil wanders over its life.
const WANDER := 7.0
## Dust at which a devil is always in sight.
const DUSTY := 0.6
## The part of the screen a devil's foot must stand in to be seen, in world
## units along the screen's right and down from the focus, for the default
## camera (view height 15): the column rises above its foot, so less room up.
const SCREEN_RIGHT := 10.5
const SCREEN_UP := 2.5
const SCREEN_DOWN := 6.0
## Home devils kept at once (an old one finishing its life, a new one in view).
const HOMES := 3


## amount 0..1 (how dusty and hot the air is); bearing: the wind's direction
## on the ground. Returns up to MAX of {pos: Vector2 (tiles), life: 0..1 how
## spun up it is (0 at birth and death), seed: int}.
static func at(seed_value: int, minutes: float, focus: Vector2, amount: float, bearing: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if amount <= 0.05:
		return out
	var cx := floori(focus.x / CELL)
	var cy := floori(focus.y / CELL)
	var found: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var gx := cx + dx
			var gy := cy + dy
			# Each cell keeps its own clock so devils do not all rise together.
			var off := Rng.hash01(seed_value, gx, gy, 0xDE71) * LIFE
			var epoch := floori((minutes + off) / LIFE)
			var t := (minutes + off) / LIFE - epoch
			if Rng.hash01(seed_value, gx, gy, epoch, 0xDE72) > amount * 0.7:
				continue
			var start := Vector2((gx + Rng.hash01(seed_value, gx, gy, epoch, 0xDE73)) * CELL, (gy + Rng.hash01(seed_value, gx, gy, epoch, 0xDE74)) * CELL)
			var wobble := Vector2.from_angle(Rng.hash01(seed_value, gx, gy, epoch, 0xDE75) * TAU)
			var path := (bearing.normalized() * 0.7 + wobble * 0.5) * WANDER
			var pos := start + path * t + wobble.orthogonal() * sin(t * TAU * 1.5) * 0.8
			var life := smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.75, 1.0, t))
			var d := pos.distance_squared_to(focus)
			if d > 20.0 * 20.0 or life <= 0.02:
				continue
			found.append([d, {"pos": pos, "life": life, "seed": Rng.hash_ints(seed_value, gx, gy, epoch)}])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for e: Array in found:
		if out.size() >= MAX:
			break
		out.append(e[1])
	return out


## Where a devil `age_minutes` into its life stands and how spun up it is, from
## where it rose: {pos, life}. The same path the cells' devils walk.
static func walk(start: Vector2, devil_seed: int, age_minutes: float, bearing: Vector2) -> Dictionary:
	var t := age_minutes / LIFE
	var wobble := Vector2.from_angle(Rng.hash01(devil_seed, 0xDE75) * TAU)
	var path := (bearing.normalized() * 0.7 + wobble * 0.5) * WANDER
	var pos := start + path * t + wobble.orthogonal() * sin(t * TAU * 1.5) * 0.8
	var life := smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.75, 1.0, t)) if t < 1.0 else 0.0
	return {"pos": pos, "life": life}


## Is a point (tiles) on screen round the focus? Camera yaw 45, pitch 57.
static func on_screen(pos: Vector2, focus: Vector2) -> bool:
	var d := pos - focus
	var right := (d.x - d.y) * 0.7071
	var down := (d.x + d.y) * 0.5931
	return absf(right) <= SCREEN_RIGHT and down >= -SCREEN_UP and down <= SCREEN_DOWN


## Keep a devil in sight in real dust. list: at()'s devils; homes: the home
## devils the caller keeps, [{start: Vector2, born: float, seed: int}]. Returns
## {list: the devils to draw (in sight first, then nearest; at most MAX), homes: the homes to
## keep}. snap: the first frame, when a new home rises already spun up.
static func keep_one(list: Array[Dictionary], homes: Array, seed_value: int, minutes: float, focus: Vector2, amount: float, bearing: Vector2, snap: bool = false) -> Dictionary:
	var kept: Array = []
	var drawn: Array = []
	for d: Dictionary in list:
		drawn.append([d.pos.distance_squared_to(focus), d])
	var seen := false
	for d: Dictionary in list:
		if float(d.life) > 0.05 and on_screen(d.pos, focus):
			seen = true
	for h: Dictionary in homes:
		var age := minutes - float(h.born)
		if age < 0.0 or age >= LIFE:
			continue
		kept.append(h)
		var w := walk(h.start, int(h.seed), age, bearing)
		if float(w.life) > 0.0:
			drawn.append([(w.pos as Vector2).distance_squared_to(focus), {"pos": w.pos, "life": w.life, "seed": int(h.seed)}])
			if on_screen(w.pos, focus) and (float(w.life) > 0.05 or age < LIFE * 0.5):
				seen = true
	if amount >= DUSTY and not seen:
		# Rise somewhere to the side of the player, well inside the screen.
		var k := floori(minutes * 4.0)
		var hs := Rng.hash_ints(seed_value, k, 0xDE76)
		var right := lerpf(3.0, 8.0, Rng.hash01(hs, 1)) * (1.0 if Rng.hash01(hs, 2) < 0.5 else -1.0)
		var down := lerpf(-1.5, 4.0, Rng.hash01(hs, 3))
		var start := focus + Vector2(right / 0.7071 + down / 0.5931, down / 0.5931 - right / 0.7071) * 0.5
		var born := minutes - LIFE * (0.3 if snap else 0.06)
		var h := {"start": start, "born": born, "seed": hs}
		kept.append(h)
		while kept.size() > HOMES:
			kept.pop_front()
		var w := walk(start, hs, minutes - born, bearing)
		drawn.append([(w.pos as Vector2).distance_squared_to(focus), {"pos": w.pos, "life": w.life, "seed": hs}])
	# Those in sight are drawn before nearer ones out of it.
	for e: Array in drawn:
		var d: Dictionary = e[1]
		if not on_screen(d.pos, focus):
			e[0] = float(e[0]) + 1e6
	drawn.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array[Dictionary] = []
	for e: Array in drawn:
		if out.size() >= MAX:
			break
		out.append(e[1])
	return {"list": out, "homes": kept}
