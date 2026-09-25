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
## `sky_gust` (SkyLight): x the offset down the wind in BANDS, wrapped at PERIOD
## bands where the band hashes repeat, so the wrap is invisible; y spare; zw the
## unit bearing the field travels on, kept through a calm so a dead wind never
## snaps it to +x.
##
## GUSTS ARE DISCRETE FRONTS. Down the wind the air is cut into bands SPACING
## tiles apart; each band holds a front DEPTH tiles deep at its middle and calm
## either side, so fronts are separated by calm far wider than the gap between
## a bush and the crown past it, and one front is seen to reach each in turn.
## Across the wind a front runs a while and stops (REACH tiles a stretch, some
## stretches off), and each front has its own strength. How hard the fronts
## blow on a given day is `level`, the shader's gust_level: gentle on a fair day,
## hard in a storm.
##
## The shader's `gust_at` is this `gust_at` times its gust_level, term for term;
## the constants are held equal by tests/render/test_wind.gd.

## Tiles from one front to the next, down the wind.
const SPACING := 20.0
## Tiles deep a front is, down the wind.
const DEPTH := 6.0
## Tiles a stretch of front runs across the wind before it may stop.
const REACH := 14.0
## Bands after which the band hashes repeat; the offset wraps here.
const PERIOD := 64.0
## Tiles a second a front travels in a calm, and more per unit of wind.
const SPEED_CALM := 2.5
const SPEED_WIND := 3.5


## Tiles a second a front travels in a wind of this strength (|sky_wind.xy|).
static func speed(strength: float) -> float:
	return SPEED_CALM + SPEED_WIND * clampf(strength, 0.0, 1.0)


## How hard the fronts blow, 0..1, from the wind's strength and the weather's
## gust (sky_wind.z): gentle on a fair day, full in a storm.
static func level(strength: float, storm: float) -> float:
	return clampf(0.1 + 0.9 * maxf(strength, storm), 0.0, 1.0)


## The gust state one step on: `g` is (offset, spare, bearing x, bearing y) and
## `along` is sky_wind.xy, the wind along world x/z times its strength.
static func advance(g: Vector4, along: Vector2, dt: float) -> Vector4:
	var strength := along.length()
	var dir := Vector2(g.z, g.w)
	if strength > 1e-3:
		dir = along / strength
	elif dir.length_squared() < 1e-6:
		dir = Vector2(1.0, 0.0)
	var off := g.x + speed(strength) * dt / SPACING
	return Vector4(fposmod(off, PERIOD), 0.0, dir.x, dir.y)


## 0..1: the shape of the gust at world `xz` under state `g`, before `level`.
static func gust_at(xz: Vector2, g: Vector4) -> float:
	var d := Vector2(g.z, g.w)
	var s := Vector2(-d.y, d.x)
	var a := xz.dot(d) / SPACING - g.x
	var band := floorf(a)
	var t := clampf(absf(a - band - 0.5) / (DEPTH * 0.5 / SPACING), 0.0, 1.0)
	var pulse := (1.0 - t * t) * (1.0 - t * t)
	var c := xz.dot(s) / REACH
	var ci := floorf(c)
	var cf := c - ci
	var u := cf * cf * (3.0 - 2.0 * cf)
	var runs := lerpf(_hash(band, ci), _hash(band, ci + 1.0), u)
	var on := smoothstep(0.3, 0.55, runs)
	return pulse * on * (0.6 + 0.4 * _hash(band, 97.0))


static func _hash(band: float, cell: float) -> float:
	var m := Vector2(fposmod(band, PERIOD), fposmod(cell, PERIOD))
	var v := sin(m.x * 127.1 + m.y * 311.7) * 43758.5453
	return v - floorf(v)
