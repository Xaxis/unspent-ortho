class_name Glints
## The glint list: the lights that exist near the camera (lamps, fires, house
## hearths, stolen neon, pylon beacons, machine lenses and strips, the player's
## lantern), handed to the sky so wet ground mirrors them and fog throws their
## shafts, without an OmniLight each (docs/LOOK.md section 6). Pure: candidates
## in, the few that matter out, packed for SkyLight.glints.
##
## A candidate is {at: Vector3 world position of the light, rgb: Vector3 its
## colour (display, 0..1), level: float 0..1 how bright it is now, shaft: float
## 0..1 how strongly it throws shafts into fog (default 1)}. A light that already
## draws its own strokes (rays.gdshader: fires, lamps, beacons, the lantern)
## throws weak shafts or none, or a fire in fog turns into a spark burst.
## Machine lights are already multiplied by the sky's power (sky_power) when
## they come in.

## Tiles from the focus within which a light may glint.
const REACH := 18.0


## The nearest lit candidates to `focus` (world space), at most `count`, nearest
## first. A brighter light holds its place a little further out, so a fire is
## not dropped for a dim window beside the player.
static func pick(candidates: Array[Dictionary], focus: Vector3, count: int = SkyLight.MAX_GLINTS) -> Array[Dictionary]:
	var ranked: Array = []
	for c: Dictionary in candidates:
		var level := float(c.get("level", 0.0))
		if level <= 0.02:
			continue
		var at: Vector3 = c.at
		var d := Vector2(at.x - focus.x, at.z - focus.z).length()
		if d > REACH:
			continue
		ranked.append([d / (0.6 + 0.4 * clampf(level, 0.0, 1.0)), c])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array[Dictionary] = []
	for r: Array in ranked:
		if out.size() >= count:
			break
		out.append(r[1])
	return out


## [positions: Array[Vector4] (xyz, level), colours: Array[Vector4] (rgb, shaft)].
static func pack(list: Array[Dictionary]) -> Array:
	var pos: Array[Vector4] = []
	var rgb: Array[Vector4] = []
	for c: Dictionary in list:
		var at: Vector3 = c.at
		var col: Vector3 = c.rgb
		pos.append(Vector4(at.x, at.y, at.z, clampf(float(c.level), 0.0, 1.0)))
		rgb.append(Vector4(col.x, col.y, col.z, clampf(float(c.get("shaft", 1.0)), 0.0, 1.0)))
	return [pos, rgb]
