class_name DustDevils
## Dust devils: whirls of grit that spin up on hot, dusty ground, wander a few
## tiles with the wind and die. Pure in (seed, world minute, focus), so a shot
## repeats and a test can count them; WeatherView draws each as a spinning column
## of marks (precip.gdshader SWIRL).
##
## The land is cut into CELL-tile cells; in each epoch of LIFE minutes a cell may
## raise one devil at a seeded point, which drifts along `bearing` over its life.

const CELL := 18.0
const LIFE := 22.0
## Drawn at most this many at once (nearest the focus).
const MAX := 3
## Tiles a devil wanders over its life.
const WANDER := 7.0


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
