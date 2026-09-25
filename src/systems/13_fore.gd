extends GameSystem
## The foreground layer over the running game (docs/LOOK.md law 3): what passes
## between the camera and the place, and the promise that it never hides
## anything that matters.
##
## This system does three things and owns none of them: it points ForeView at
## the world and the camera, tells it where the focus is, and hands it the list
## of bodies a piece may not hide. The layer itself is `src/render/depth/`.
##
## It is numbered before 15_lights on purpose: a piece hung over the frame casts
## into the same shadow map the sun was already drawing, and the lights system
## decides how many LOCAL lights may cast on top of that.

var view: ForeView
## Reused every frame so a full frame of bodies allocates nothing.
var _pos: Array[Vector2] = []
var _hostile := PackedByteArray()
var _aware := PackedByteArray()
## The ground under a piece, asked by the layer. Built ONCE for the same reason
## the three arrays above are reused: a lambda written at the call site is a new
## Callable every frame, and this one closes over `game`, which never changes.
## The arrays were already hoisted and this was missed because an allocation
## spelled as a function body does not look like an allocation.
var _height := Callable()


func setup(g: Game) -> void:
	super.setup(g)
	view = ForeView.new()
	view.name = "fore"
	add_child(view)
	view.setup(g.world, g.query, g.camera)
	# `--fore=N` beats the tier, for this run only, so two frames of one moment
	# can be taken with the layer and without it. Everything this package claims
	# -- what it costs, and that it hides nothing -- is a difference between
	# those two frames, and a claim nobody can take the other half of is not
	# evidence (see tours/depth.tour).
	if g.options.fore >= 0:
		view.budget = g.options.fore


## A crossing points everything at the other realm's world. The pieces hung over
## the surface are the surface's; underground there are no boughs and there are
## rock lips, which is the same layer reading a different world.
func realm_changed(_from: StringName, _to: StringName) -> void:
	if view != null and game != null:
		view.rebind(game.world, game.query)


func _process(_delta: float) -> void:
	if view == null or game == null or view.budget <= 0:
		return
	var f3: Vector3 = game.camera.target if game.camera != null else game.player.position
	var focus := Vector2(f3.x, f3.z)
	view.follow(focus)
	# Thinned by whichever camera is DRAWING, not only the rig: a staged eye
	# (96_eye, `--eye`) is its own Camera3D, the rig's shoulder share stays 0
	# under it, and the pieces hung for the top-down frame were drawn full across
	# every eye frame -- the dark triangle in the top-right of the coast at dusk.
	# The horizon's share is the same test the rest of the eye-level rules use.
	var sh: float = game.camera.shoulder_share() if game.camera != null else 0.0
	view.thin(maxf(sh, SkyLight.horizon_share(get_viewport().get_camera_3d())))
	var here: Vector2 = game.player.pos
	_pos.clear()
	_hostile.clear()
	_aware.clear()
	for m: Node in get_tree().get_nodes_in_group(&"mobs"):
		# Read as the rest of the game reads a body (18_crowns, 75_music): the
		# group answers for `alive`, `pos`, `hostile` and `aware`, and anything
		# that does not answer is not one.
		var alive: Variant = m.get(&"alive")
		var pos: Variant = m.get(&"pos")
		if (alive is bool and not alive) or not pos is Vector2:
			continue
		var p := pos as Vector2
		if p.distance_to(here) > ForeView.NEAR:
			continue
		var hostile: Variant = m.get(&"hostile")
		var aware: Variant = m.get(&"aware")
		_pos.append(p)
		_hostile.append(0 if hostile is bool and not hostile else 1)
		_aware.append(1 if aware is bool and aware else 0)
	if _height.is_null():
		_height = func(p: Vector2) -> float: return game.view.surface_height(p)
	view.clear_for(here, _pos, _hostile, _aware, _height)


## What a tour can be shown of this layer. `fore` is the honest one: there really
## is something hung over the frame right now. `fore_clear` is the promise: a
## body is near enough to matter and a hole is open for it.
func tour_seen(what: StringName) -> bool:
	if view == null:
		return false
	match what:
		&"fore":
			return view.drawn > 0
		&"fore_clear":
			return view.drawn > 0 and not _pos.is_empty()
	return false
