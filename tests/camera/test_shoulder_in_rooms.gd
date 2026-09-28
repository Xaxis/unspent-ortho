extends TestCase
## THE EYE OVER THE SHOULDER IS NEVER INSIDE A ROOM'S GEOMETRY (teammate1's
## ruling, 2026-09-28: face_hold.tour frame 05 stood in the rock of a cell's
## roof). For every room kind, in its smallest room, a player in the middle
## facing each of the four ways: the eye the rig settles on (Shoulder.settle_eye,
## over the walls the query is handed and the ceilings 21_doors hands the eye)
## stands inside a room, under its ceiling by the eye's margin, and off every
## wall. Where there is no room behind, it comes over the head instead.

const DOORS := 6
const Shoulder := preload("res://src/core/view/shoulder.gd")

var _doors := load("res://src/systems/21_doors.gd") as GDScript


func _land_of(kind: StringName) -> int:
	var lands: Array[StringName] = Interiors.lands_of(kind)
	return BiomeRegistry.index_of(lands[0]) if not lands.is_empty() else 0


func test_the_eye_is_never_in_a_room_s_roof_or_walls() -> void:
	var asked := 0
	for kind: StringName in Interiors.RECIPES:
		var k := Interiors.kind(kind)
		var land := _land_of(kind)
		for n in DOORS:
			var t := Threshold.of_face(Vector2(40.0 + 11.0 * n, 60.0 + 5.0 * n), Vector2(0, 1), kind, land)
			var p := InteriorGen.grow(3, t)
			if p == null:
				continue
			var l := p.layout
			var smallest := 0
			for i in l.rooms.size():
				if l.rooms[i].get_area() < l.rooms[smallest].get_area():
					smallest = i
			var r := l.rooms[smallest]
			var walls: Array[Vector4] = []
			for c: Vector3 in _doors.call(&"_walls", l) as Array[Vector3]:
				walls.append(Vector4(c.x, c.y, c.z, INF))
			var mid := Rect2(r).get_center()
			var boxes: Array[PackedFloat32Array] = _doors.call(&"ceiling_boxes", l, k, mid, 12.0)
			var ground := func(q: Vector2) -> float:
				return p.world.height_at(q)
			var room_fn := func(a: Vector3, b: Vector3) -> float:
				return Shoulder.room(a, b, ground, walls, boxes)
			var clear_fn := func(a: Vector3, b: Vector3) -> float:
				return Shoulder.clear_along(a, b, ground, walls, boxes)
			var floor_y := p.world.height_at(mid)
			var feet := Vector3(mid.x, floor_y, mid.y)
			for turn in 4:
				var yaw := 90.0 * turn
				var basis := Basis.from_euler(Vector3(deg_to_rad(-Shoulder.PITCH), deg_to_rad(yaw), 0.0))
				var focus := feet + Vector3(0.0, Shoulder.FOCUS_UP, 0.0) + basis.x * Shoulder.RIGHT
				var head := feet + Vector3(0.0, Shoulder.HEAD_UP, 0.0)
				var eye := Shoulder.settle_eye(head, focus, focus + basis.z * Shoulder.BACK, room_fn, clear_fn)
				asked += 1
				var what := "%s %s room %s facing %d" % [kind, t.key, r, int(yaw)]
				var tx := floori(eye.x)
				var ty := floori(eye.z)
				check(l.is_floor(tx, ty), "%s: the eye is over a room's floor, not in a wall" % what)
				var roof := TerrainMesher.level_height(InteriorGen.FLOOR_LEVEL + l.level_of(tx, ty)) + k.wall_h
				lt(eye.y, roof - Shoulder.CLEAR * 0.5, "%s: the eye is under the ceiling" % what)
				for w: Vector4 in walls:
					var d := Vector2(eye.x - w.x, eye.z - w.y).length()
					if d < w.z:
						check(false, "%s: the eye is in a wall at (%.2f, %.2f)" % [what, w.x, w.y])
						break
	gt(float(asked), 100.0, "every kind was asked")
