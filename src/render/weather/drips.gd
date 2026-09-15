class_name Drips
## Where water drips from in a wet world: eaves, pylon arms, pole tops, lamp
## arms, the lips of pine tiers and broadleaf crowns, wreck edges. Pure: props in,
## world points out, so WeatherView's drip emitter (EMISSION_SHAPE_POINTS) and
## tests agree. Drips run while it rains and for a while after, as long as the
## ground is still wet, so a pinewood keeps raining under its crowns after the
## sky has stopped.

## Per prop kind: [height of the drip line above the foot, radius of the ring of
## drip points round the centre, points per prop]. Heights follow the models
## (props/*.gd); a kind not listed does not drip.
const SOURCES := {
	PropKind.HOUSE: [1.25, 1.35, 6],
	PropKind.PYLON: [3.6, 0.7, 4],
	PropKind.POLE: [2.1, 0.25, 2],
	PropKind.LAMP: [1.55, 0.4, 2],
	PropKind.PINE: [1.1, 0.6, 5],
	PropKind.SNOW_PINE: [1.1, 0.6, 3],
	PropKind.BROADLEAF: [1.3, 0.8, 5],
	PropKind.DEAD_TREE: [1.2, 0.5, 2],
	PropKind.WRECK: [0.7, 0.8, 3],
	PropKind.RUIN: [1.0, 1.0, 3],
}
## At most this many points go to the emitter (its budget, nearest first).
const MAX_POINTS := 96
## Tiles round the focus whose props drip.
const REACH := 13.0


## 0..1 how hard things drip: with the rain, then on while the ground is wet.
static func amount(rain: float, wet: float) -> float:
	return clampf(maxf(rain * 1.2, smoothstep(0.25, 0.8, wet) * 0.55), 0.0, 1.0)


## World-space drip points for props near `focus` (tile space), nearest first.
## `ground` maps a tile position to the world point under it.
static func points(props: Array[WorldProp], focus: Vector2, seed_value: int, ground: Callable, depleted: Dictionary = {}) -> PackedVector3Array:
	var near: Array = []
	for p in props:
		if not SOURCES.has(p.kind) or depleted.has(p.id):
			continue
		var d := p.pos.distance_squared_to(focus)
		if d <= REACH * REACH:
			near.append([d, p])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out := PackedVector3Array()
	for e: Array in near:
		var p: WorldProp = e[1]
		var spec: Array = SOURCES[p.kind]
		var base: Vector3 = ground.call(p.pos)
		var n := int(spec[2])
		for i in n:
			if out.size() >= MAX_POINTS:
				return out
			var h := Rng.hash01(seed_value, p.id, i, 0xD41)
			var a := -p.rot + (float(i) + h * 0.6) * TAU / n
			var r := float(spec[1]) * p.scale * lerpf(0.75, 1.05, Rng.hash01(seed_value, p.id, i, 0xD42))
			var y := float(spec[0]) * p.scale * lerpf(0.85, 1.0, h)
			out.append(base + Vector3(cos(a) * r, y, sin(a) * r))
	return out
