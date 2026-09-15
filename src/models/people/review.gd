extends RefCounted
## Filmstrips for judging people and animals frame by frame. Silent in the
## normal gallery; answers only a filter that starts with "review":
##
##   tools/shot.sh shots/r.png --scene=gallery --zoom=7 --filter="review swing axe_felling"
##   --filter="review walk"            8 frames of the walk cycle (also: run)
##   --filter="review act dodge knife" 8 frames through an action
##   --filter="review swing pick"      guard, windup, strike, follow, recovery
##   --filter="review build heavy"     one build from the side and the front
##   --filter="review animal dog"      every pose of an animal
##   --filter="review item person actions b"   one gallery item alone, centred
##
## Every item's name is the filter itself, so the gallery keeps them all.


static func gallery() -> Array:
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.trim_prefix("--filter=")
	if not filter.begins_with("review"):
		return []
	var words := filter.split(" ", false)
	var what := words[1] if words.size() > 1 else "walk"
	var arg := words[2] if words.size() > 2 else ""
	var arg2 := words[3] if words.size() > 3 else ""
	if what == "item":
		# One gallery item alone, centred: --filter="review item people builds"
		var want := " ".join(words.slice(2))
		var found: Array = []
		for script: GDScript in [PersonModel, preload("res://src/models/animals/dog.gd"), preload("res://src/models/animals/sheep.gd"), preload("res://src/models/animals/bull.gd"), preload("res://src/models/animals/rat.gd"), preload("res://src/models/animals/gull.gd")]:
			for it: Dictionary in script.call("gallery"):
				if String(it.name).begins_with(want) and found.is_empty():
					found.append(it.node)
				else:
					(it.node as Node).free()
		var holder := Node3D.new()
		if not found.is_empty():
			(found[0] as Node3D).position = Vector3(1.6, 0, 0)
			holder.add_child(found[0])
		return [{"name": filter, "node": holder}, {"name": filter, "node": Node3D.new()}]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/render/world.gdshader")
	var nodes: Array[Node3D] = []
	match what:
		"walk", "run":
			var speed := PersonAnim.GAIT_WALK if what == "walk" else PersonAnim.GAIT_RUN
			var look := {"coat": &"long"} if arg == "coat" else {}
			for i in 8:
				var p := PersonModel.make(look, StringName(arg2) if arg2 != "" else &"knife", mat)
				p.rotation.y = PersonModel.FACE_RIGHT
				# Exactly frame i of 8 (a zero delta does not advance the cycle).
				p._phase = i / 8.0
				p.animate(speed, 0.0)
				nodes.append(p)
		"act":
			var action := StringName(arg if arg != "" else "dodge")
			var tool := StringName(arg2)
			var len := PersonAnim.default_seconds(action, tool)
			if len <= 0.0:
				len = 1.0
			for i in 8:
				var p := PersonModel.make({}, tool, mat)
				p.rotation.y = PersonModel.FACE_RIGHT
				p.pose_at(action, len * i / 7.0)
				nodes.append(p)
		"swing":
			var tool := StringName(arg)
			var ms := HeldTools.swing_ms(tool)
			var total := float(ms[0] + ms[1] + ms[2])
			var marks: Array[float] = [0.0, ms[0] * 0.5 / total, ms[0] / total, (ms[0] + ms[1] * 0.45) / total, (ms[0] + ms[1]) / total, 1.0 - (ms[2] * 0.5) / total]
			var len := total / 1000.0
			for u: float in marks:
				var p := PersonModel.make({}, tool, mat)
				p.rotation.y = PersonModel.FACE_RIGHT
				p.pose_at(&"swing", u * len, len)
				nodes.append(p)
		"build":
			for face: float in [PersonModel.FACE_RIGHT, PersonModel.FACE_CAMERA, -PI * 0.75]:
				var p := PersonModel.make({"build": StringName(arg)}, &"", mat)
				p.rotation.y = face
				nodes.append(p)
		"salvage":
			for face: float in [PersonModel.FACE_RIGHT, PersonModel.FACE_CAMERA, -PI * 0.75, PI * 0.75]:
				var p := PersonModel.make({"salvage": [StringName(arg)], "coat": &"jerkin"}, &"", mat)
				p.rotation.y = face
				nodes.append(p)
		"look":
			for i in 6:
				var p := PersonModel.make(PersonLook.random(arg.to_int(), i), &"", mat)
				p.rotation.y = PersonModel.FACE_CAMERA
				nodes.append(p)
		"tool":
			for face: float in [PersonModel.FACE_RIGHT, PersonModel.FACE_CAMERA]:
				var p := PersonModel.make({}, StringName(arg), mat)
				p.rotation.y = face
				nodes.append(p)
		"zoo":
			for k: StringName in [&"dog", &"sheep", &"bull", &"rat", &"gull"]:
				for v in 2:
					var m := FigureModel.create(k, mat) as AnimalModel
					m.vary(v * 31 + arg.to_int())
					m.rotation.y = PersonModel.FACE_RIGHT if v == 0 else PersonModel.FACE_CAMERA
					m.animate(0.5, 0.0)
					nodes.append(m)
		"animal":
			for pose: StringName in [&"stand", &"walk", &"alert", &"flee", &"windup", &"strike", &"hurt", &"dead"]:
				var m := FigureModel.create(StringName(arg), mat)
				m.rotation.y = PersonModel.FACE_RIGHT
				m.set_pose(pose)
				for f in 9:
					m.animate(0.045, 3.0 if pose == &"walk" else (7.0 if pose == &"flee" else 0.0))
				nodes.append(m)
	# One strip, left to right across the screen, in time order. The gallery centres
	# its camera between two items 3.2 apart, so the strip is built around that point
	# and the second item is empty.
	var strip := Node3D.new()
	var across := Vector3(1, 0, -1).normalized()
	var spacing := 1.25 if nodes.size() > 3 else 1.6
	if what == "zoo":
		spacing = 0.95
	if what == "animal":
		spacing = {"rat": 0.45, "gull": 0.6, "dog": 0.95, "sheep": 1.0, "bull": 1.75}.get(arg, 1.0)
	for i in nodes.size():
		nodes[i].position = Vector3(1.6, 0, 0) + across * (i - (nodes.size() - 1) * 0.5) * spacing
		strip.add_child(nodes[i])
	return [{"name": filter, "node": strip}, {"name": filter, "node": Node3D.new()}]
