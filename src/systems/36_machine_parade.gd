extends GameSystem
## A review surface for machines in the real world: real ground, real light, the
## game camera. Off unless asked for, and never a mob (fight owns those):
##
##   tools/shot.sh shots/p.png --parade=all --hour=21
##   tools/shot.sh shots/p.png --parade=watcher,warden:alert --zoom=8
##   godot --path . -- --parade=all:walk        they pace a ring round you
##
## Pose after the colon is any FigureModel pose, or `walk` to circle the player.

const RADIUS := 4.6

var machines: Array[FigureModel] = []
var _angles: PackedFloat32Array = PackedFloat32Array()
var _walking := false
var _centre := Vector2.ZERO


func setup(g: Game) -> void:
	super(g)
	var spec := g.options.parade
	if spec == "":
		return
	var parts := spec.split(":")
	var kinds: PackedStringArray = parts[0].split(",", false)
	if kinds.size() == 1 and kinds[0] == "all":
		kinds = PackedStringArray(["watcher", "longlegs", "harvester", "cutter", "hauler", "warden", "sweeper", "dredger", "lineman", "flock", "runner", "clerk"])
	var pose := StringName(parts[1]) if parts.size() > 1 else &"stand"
	_walking = pose == &"walk"
	_centre = g.player.pos
	for i in kinds.size():
		var m := FigureModel.create(StringName(kinds[i]), g.view.world_material())
		m.name = "parade_%s" % kinds[i]
		add_child(m)
		m.set_pose(pose)
		machines.append(m)
		_angles.append(float(i) / kinds.size() * TAU)
	_place(0.0)
	for m in machines:
		if m is MachineModel:
			(m as MachineModel).settle()


func _process(delta: float) -> void:
	if machines.is_empty():
		return
	_place(delta)


func _place(delta: float) -> void:
	for i in machines.size():
		var m := machines[i]
		var speed := 0.0
		if _walking:
			speed = 1.2
			_angles[i] += delta * speed / RADIUS
		var a := _angles[i]
		var pos := _centre + Vector2(cos(a), sin(a)) * RADIUS
		m.position = game.world.to_3d(pos)
		# Face along the ring when pacing it, else face the player.
		var facing := a + PI * 0.5 if _walking else a + PI
		m.rotation.y = -facing
		m.animate(delta, speed)
