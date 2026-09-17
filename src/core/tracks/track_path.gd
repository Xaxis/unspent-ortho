class_name TrackPath
extends RefCounted
## Where a body leaves its marks, given where it has been (the PLACEMENT; what the
## ground keeps is TrackGround's, and the drawing is TrackMarks'). Pure: fed a
## position and what the body is doing, it answers the marks laid since, so a test
## walks it without a frame.
##
##   feed(pos, s) -> Array[Dictionary]    s: {step, gauge, swimming, airborne, dodging,
##                                         dodge_dir, kind}; each mark:
##                                         {at: Vector2, angle: float, side: -1|0|1, shape}
##
## A foot comes down every `step` of ground actually covered, left and right in
## turn, half a `gauge` either side of the line walked — so a figure that runs,
## crawls or walks a crooked line leaves exactly the trail it walked. Nothing is
## laid in the water or in the air; coming down lays both feet at once; the start
## of a dodge drags a scuff along it. `kind` is what is doing the walking:
##   &"foot"     a person
##   &"rig"      the walker rig: a machine foot every long stride, wide apart
##   &"sweep"    the hover sled: a band brushed across the ground, no feet at all
##   &""         nothing on the ground (a raft)

const SHAPE_FOOT := &"foot"
const SHAPE_SCUFF := &"scuff"
const SHAPE_RIG := &"rig"
const SHAPE_SWEEP := &"sweep"

var travelled := 0.0
var side := -1
var _last := Vector2.INF
var _was_airborne := false
var _was_dodging := false
var _heading := 0.0


func reset() -> void:
	travelled = 0.0
	_last = Vector2.INF
	_was_airborne = false
	_was_dodging = false


func feed(pos: Vector2, s: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kind := StringName(str(s.get("kind", SHAPE_FOOT)))
	var airborne := bool(s.get("airborne", false))
	var swimming := bool(s.get("swimming", false))
	var dodging := bool(s.get("dodging", false))
	var gauge := float(s.get("gauge", 0.18))
	if _last == Vector2.INF:
		_last = pos
		_was_airborne = airborne
		_was_dodging = dodging
		return out
	var moved := pos - _last
	var d := moved.length()
	# A jump across the map (a crossing, a load, a teleport) is not a walk.
	if d > 3.0:
		_last = pos
		travelled = 0.0
		return out
	if d > 0.0005:
		_heading = moved.angle()
	_last = pos
	if kind == &"" or swimming:
		travelled = 0.0
		_was_airborne = airborne
		_was_dodging = dodging
		return out
	if airborne:
		_was_airborne = true
		travelled = 0.0
		return out
	if _was_airborne:
		_was_airborne = false
		if kind == SHAPE_FOOT:
			# Both feet down together where the jump came down.
			for sd: int in [-1, 1]:
				out.append(_mark(pos, _heading, sd, gauge * 0.6, SHAPE_FOOT))
			travelled = 0.0
			return out
	if dodging and not _was_dodging and kind == SHAPE_FOOT:
		var dir := s.get("dodge_dir", Vector2.ZERO) as Vector2
		var a := dir.angle() if dir.length() > 0.01 else _heading
		out.append({"at": pos, "angle": a, "side": 0, "shape": SHAPE_SCUFF})
	_was_dodging = dodging
	var step := maxf(0.05, float(s.get("step", 0.6)))
	travelled += d
	while travelled >= step:
		travelled -= step
		# The foot came down a little behind where the body is now.
		var at := pos - Vector2.from_angle(_heading) * travelled
		match kind:
			SHAPE_SWEEP:
				out.append({"at": at, "angle": _heading, "side": 0, "shape": SHAPE_SWEEP})
			SHAPE_RIG:
				out.append(_mark(at, _heading, side, gauge, SHAPE_RIG))
				side = -side
			_:
				out.append(_mark(at, _heading, side, gauge, SHAPE_FOOT))
				side = -side
	return out


static func _mark(at: Vector2, heading: float, sd: int, gauge: float, shape: StringName) -> Dictionary:
	# Tile space turns the other way from screen space: +y is south, so the left
	# of a body heading `heading` is a quarter turn anticlockwise on the map.
	var left := Vector2.from_angle(heading - PI * 0.5)
	return {"at": at + left * (gauge * 0.5) * (-sd), "angle": heading, "side": sd, "shape": shape}
