class_name WindField
extends RefCounted
## The travelling gust field every swaying thing reads (src/render/wind.gdshaderinc),
## held here in GDScript so a test can ask it where a front is and how fast it goes.
##
## THE FIELD MOVES BY AN INTEGRATED OFFSET, NOT BY `TIME x speed`. Speed and
## bearing both change with the weather, and anything written as a rate times a
## clock jumps by `clock x change` the moment they do: that is how the old sway
## scrambled every blade when the wind eased. So 10_sky advances `offset` by
## `speed x dt` each frame and the shader subtracts it, and nothing jumps.
##
## `sky_gust` (SkyLight): xy the offset in lattice cells, wrapped at PERIOD where
## the lattice repeats, so the wrap is invisible; zw the unit bearing the field
## travels on, kept through a calm so a dead wind never snaps it to +x.
##
## The shader's `gust_at` is this `gust_at` term for term; the constants are held
## equal by tests/render/test_wind.gd.

## Tiles across one lattice cell: a gust front is about this wide.
const CELL := 11.0
## Cells after which the lattice repeats; the offset wraps here.
const PERIOD := 64.0
## Tiles a second a front travels in a calm, and more per unit of wind.
const SPEED_CALM := 2.5
const SPEED_WIND := 3.5


## Tiles a second a front travels in a wind of this strength (|sky_wind.xy|).
static func speed(strength: float) -> float:
	return SPEED_CALM + SPEED_WIND * clampf(strength, 0.0, 1.0)


## The gust state one step on: `g` is (offset x, offset y, bearing x, bearing y)
## and `along` is sky_wind.xy, the wind along world x/z times its strength.
static func advance(g: Vector4, along: Vector2, dt: float) -> Vector4:
	var strength := along.length()
	var dir := Vector2(g.z, g.w)
	if strength > 1e-3:
		dir = along / strength
	elif dir.length_squared() < 1e-6:
		dir = Vector2(1.0, 0.0)
	var off := Vector2(g.x, g.y) + dir * speed(strength) * dt / CELL
	return Vector4(fposmod(off.x, PERIOD), fposmod(off.y, PERIOD), dir.x, dir.y)


## 0..1: how much gust stands at world `xz` under state `g`.
static func gust_at(xz: Vector2, g: Vector4) -> float:
	var q := xz / CELL - Vector2(g.x, g.y)
	var n := _vnoise(q) * 0.65 + _vnoise(q * 2.0 + Vector2(17.0, 17.0)) * 0.35
	return smoothstep(0.42, 0.78, n)


static func _hash(c: Vector2) -> float:
	var m := Vector2(fposmod(c.x, PERIOD), fposmod(c.y, PERIOD))
	var s := sin(m.x * 127.1 + m.y * 311.7) * 43758.5453
	return s - floorf(s)


static func _vnoise(q: Vector2) -> float:
	var i := q.floor()
	var f := q - i
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash(i)
	var b := _hash(i + Vector2(1.0, 0.0))
	var c := _hash(i + Vector2(0.0, 1.0))
	var d := _hash(i + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y)
