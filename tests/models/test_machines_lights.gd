extends TestCase
## The machines' built-in lights tell their state (docs/VISION.md §2, the
## machines brief): status lamps blink the disposition, alert locks the eyes,
## a windup brightens the working side, hurt stutters, and the dead go dark in
## sequence with the working part last. Every pattern is exact, so every one is
## tested frame by frame. Also: the wear and trophies each kind carries.

const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk"]
const LIT: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"runner", &"clerk"]
const SCANNERS: Array[StringName] = [&"watcher", &"warden", &"clerk"]
const WASHES: Array[StringName] = [&"harvester", &"hauler", &"sweeper", &"cutter"]
const STEP := 1.0 / 60.0


static func joint_state(m: MachineModel) -> Array:
	var out: Array = []
	var names: Array = m.joints.keys()
	names.sort()
	for jn: StringName in names:
		var n: Node3D = m.joints[jn]
		out.append([n.position, n.rotation])
	return out


static func same_state(a: Array, b: Array, tol: float) -> bool:
	for i in a.size():
		if ((a[i][0] as Vector3) - (b[i][0] as Vector3)).length() > tol or ((a[i][1] as Vector3) - (b[i][1] as Vector3)).length() > tol:
			return false
	return true


static func beams(m: MachineModel, role: StringName) -> Array:
	var out: Array = []
	for b: Array in m._beams:
		if b[2] == role:
			out.append(b[0])
	return out


static func status_on(m: MachineModel) -> bool:
	var levels: Array = m.lamp_levels().get(&"status", [])
	return not levels.is_empty() and int(levels[0]) == 2


## Blinks (off -> hot) counted over `seconds` of animation from clock `from`.
static func count_blinks(m: MachineModel, from: float, seconds: float) -> int:
	var blinks := 0
	m.clock = from - STEP
	m.animate(STEP, 0.0)
	var was := status_on(m)
	for i in int(seconds / STEP):
		m.animate(STEP, 0.0)
		var now := status_on(m)
		if now and not was:
			blinks += 1
		was = now
	return blinks


func with_sun(energy: float) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.light_energy = energy
	tree.root.add_child(sun)
	MachineModel._sun = null
	MachineModel._dark_frame = -1
	return sun


func drop_sun(sun: DirectionalLight3D) -> void:
	sun.free()
	MachineModel._sun = null
	MachineModel._dark_frame = -1


func test_every_lit_kind_carries_a_status_lamp_and_a_way_to_look() -> void:
	for kid in LIT:
		var m := FigureModel.create(kid) as MachineModel
		var levels := m.lamp_levels()
		check(levels.has(&"status"), "%s has a status lamp" % kid)
		check(not m._scans.is_empty() or levels.has(&"optic") or not beams(m, &"scan").is_empty(), "%s has an eye that lights" % kid)
		m.free()


func test_lamps_are_cold_and_the_amber_part_stays_the_one_warm_read() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		var lights: MeshInstance3D = m.surfaces.get(&"lights")
		if lights != null:
			var cols := lights.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
			for c in cols:
				check(c.a < 0.98, "%s: every lamp vertex is a light to the FOUND shader" % kid)
				var cold := false
				for cc: Color in Palette.COLD:
					cold = cold or (absf(cc.r - c.r) < 0.006 and absf(cc.g - c.g) < 0.006 and absf(cc.b - c.b) < 0.006)
				check(cold, "%s: lamp colour %s is on the COLD ramp" % [kid, c])
				if not cold:
					break
		var body: MeshInstance3D = m.surfaces.get(&"body")
		if body != null:
			for c in body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
				if c.a < 0.98:
					fail("%s: a body vertex glows" % kid)
					break
		m.free()


func test_status_lamps_blink_the_disposition() -> void:
	for kid in LIT:
		var m := FigureModel.create(kid) as MachineModel
		m.set_pose(&"stand")
		m.settle()
		var code: int = MachineModel.DISPOSITION_CODE[m.disposition]
		var cycle := 0.3 * code + 1.6
		if code == 0:
			# Hostile: no code, a low steady burn.
			for i in 120:
				m.animate(STEP, 0.0)
				eq(int(m.lamp_levels()[&"status"][0]), 1, "%s burns steady" % kid)
		else:
			# Start just past a cycle boundary, then count one whole cycle.
			eq(count_blinks(m, 0.2, cycle), code, "%s (%s) blinks per cycle" % [kid, m.disposition])
		m.free()
	# The disposition system sets it on a live machine, and the lamp follows.
	var h := FigureModel.create(&"harvester") as MachineModel
	h.disposition = &"wary"
	h.settle()
	eq(count_blinks(h, 0.2, 0.3 * 2 + 1.6), 2, "a wary harvester blinks twice")
	h.free()


func test_alert_snaps_and_locks_the_eyes() -> void:
	for kid in LIT:
		var m := FigureModel.create(kid) as MachineModel
		m.set_pose(&"stand")
		m.settle()
		m.clock = 0.5
		m.animate(STEP, 0.0)
		m.set_pose(&"alert")
		# A servo, not a blend: most of the way there in a tenth of a second.
		for i in 6:
			m.animate(STEP, 0.0)
		var e := 1.0 - pow(1.0 - clampf(6.0 * STEP / float(MachineModel.BLEND[&"alert"]), 0.0, 1.0), 3.0)
		gt(e, 0.85, "%s alert snaps" % kid)
		for i in 30:
			m.animate(STEP, 0.0)
		for x: float in m.scan_positions():
			near(x, 0.5, 1e-4, "%s scan locked dead centre" % kid)
		for lvl: int in m.lamp_levels().get(&"optic", []):
			eq(lvl, 2, "%s optics locked hot" % kid)
		eq(count_blinks(m, 0.3, 0.6), 2, "%s double-blinks on alert" % kid)
		for b: MeshInstance3D in beams(m, &"scan"):
			near(float((b.material_override as ShaderMaterial).get_shader_parameter("narrow")), 0.55, 1e-4, "%s beam narrows" % kid)
		m.free()


## The four locked reads, checked after the lights have run a while.
func check_locked(m: MachineModel, kid: StringName, why: String) -> void:
	for x: float in m.scan_positions():
		near(x, 0.5, 1e-4, "%s %s: scan held dead centre" % [kid, why])
	for lvl: int in m.lamp_levels().get(&"optic", []):
		eq(lvl, 2, "%s %s: optics hot" % [kid, why])
	for b: MeshInstance3D in beams(m, &"scan"):
		near(float((b.material_override as ShaderMaterial).get_shader_parameter("narrow")), 0.55, 1e-4, "%s %s: beam narrowed" % [kid, why])
	eq(count_blinks(m, m.clock + 0.3, 0.6), 2, "%s %s: status double-blinks" % [kid, why])


## A mob walks the same `walk` pose on an errand and in a chase. A walk out of
## alert is a chase: it keeps every locked read until the body stands again.
func test_a_chase_keeps_the_lights_locked() -> void:
	for kid in LIT:
		var m := FigureModel.create(kid) as MachineModel
		m.set_pose(&"stand")
		m.settle()
		m.set_pose(&"alert")
		for i in 20:
			m.animate(STEP, 0.0)
		m.set_pose(&"walk")
		for i in 90:
			m.animate(STEP, 2.0)
		check(m.hunting, "%s: a walk out of alert hunts" % kid)
		check_locked(m, kid, "walking out of alert")
		# The head does not look round while it runs you down: the beam holds its bearing.
		var dirs := {}
		for i in 200:
			m.animate(STEP * 2.0, 2.0)
			for b: MeshInstance3D in beams(m, &"scan"):
				var d := m.model_space(b).basis.x
				dirs["%.2f,%.2f" % [d.x, d.z]] = true
		check(dirs.size() <= 1, "%s: a hunting beam holds its bearing (%d seen)" % [kid, dirs.size()])
		# A blow and the walk after it, and a hit and the walk after that.
		for p: StringName in [&"windup", &"walk", &"hurt", &"walk"]:
			m.set_pose(p)
			for i in 30:
				m.animate(STEP, 2.0 if p == &"walk" else 0.0)
		check(m.hunting, "%s: still hunting after a hit" % kid)
		check_locked(m, kid, "walking after a hit")
		# Standing ends the chase; the next walk is an errand and looks round.
		m.set_pose(&"stand")
		m.animate(STEP, 0.0)
		m.set_pose(&"walk")
		for i in 30:
			m.animate(STEP, 2.0)
		check(not m.hunting, "%s: a walk from a stand is an errand" % kid)
		var code: int = MachineModel.DISPOSITION_CODE[m.disposition]
		if code > 0:
			eq(count_blinks(m, 0.2, 0.3 * code + 1.6), code, "%s: an errand blinks its disposition again" % kid)
		for b: MeshInstance3D in beams(m, &"scan"):
			near(float((b.material_override as ShaderMaterial).get_shader_parameter("narrow")), 1.0, 1e-4, "%s: an errand's beam sweeps wide" % kid)
		m.free()


## When the mob says so, the machine believes it over its poses both ways.
func test_set_hunting_is_the_last_word() -> void:
	var m := FigureModel.create(&"warden") as MachineModel
	m.settle()
	m.set_hunting(true)
	m.set_pose(&"walk")
	for i in 30:
		m.animate(STEP, 2.0)
	check_locked(m, &"warden", "told it hunts")
	m.set_hunting(false)
	m.set_pose(&"alert")
	m.set_pose(&"walk")
	for i in 30:
		m.animate(STEP, 2.0)
	check(not m.hunting, "told it does not hunt, a walk out of alert is an errand")
	check(not m.locked(), "and its lights look round")
	m.free()
	# Every figure takes the call, machine or not.
	var f := FigureModel.create(&"no_such_figure")
	f.set_hunting(true)
	f.free()


func test_windup_brightens_the_working_side() -> void:
	for kid in LIT:
		var m := FigureModel.create(kid) as MachineModel
		if m.part_anchor == null:
			m.free()
			continue
		var n := MachineModel.side_normal(m.part_side)
		m.rotation.y = -PI * 0.25 - atan2(-n.z, n.x)
		m.set_pose(&"stand")
		m.settle()
		var base := m.part_emission()
		m.set_pose(&"windup")
		for i in 45:
			m.animate(STEP, 0.0)
		gt(m.part_emission(), base * 1.6, "%s part climbs through the windup" % kid)
		for l: Dictionary in m._lamps:
			if l.role == &"work" and l.side:
				check((l.hot as Node3D).visible, "%s: work lamp on the part's side goes hot" % kid)
		m.free()


func test_hurt_stutters_then_holds_dark() -> void:
	for kid in LIT:
		var m := FigureModel.create(kid) as MachineModel
		m.set_pose(&"stand")
		for i in 30:
			m.animate(STEP, 0.0)
		m.set_pose(&"hurt")
		m.set_part_lit(false)
		var seen_on := false
		var seen_off := false
		var lamp_states := {}
		for i in int(MachineModel.STUTTER / STEP) - 1:
			m.animate(STEP, 0.0)
			if m.light_level() > 0.0:
				seen_on = true
			else:
				seen_off = true
			lamp_states[str(m.lamp_levels())] = true
		check(seen_on and seen_off, "%s part stutters as it goes out" % kid)
		gt(float(lamp_states.size()), 1.0, "%s lamps stutter" % kid)
		for i in 3:
			m.animate(STEP, 0.0)
		for i in 40:
			m.animate(STEP, 0.0)
			eq(m.light_level(), 0.0, "%s part stays out once the stutter is over" % kid)
		check(not m.scanning(), "%s stops looking" % kid)
		m.free()


func test_the_dead_go_dark_in_sequence_with_the_part_last() -> void:
	var order: Array[StringName] = [&"status", &"optic", &"work"]
	for kid in LIT:
		var m := FigureModel.create(kid) as MachineModel
		m.set_pose(&"stand")
		m.settle()
		var standing := joint_state(m)
		m.set_pose(&"dead")
		var first_out := {}
		var last_out := {}
		var part_out := -1.0
		var t := 0.0
		while t < MachineModel.LIGHT_FIRST + 0.2:
			m.animate(1.0 / 120.0, 0.0)
			t += 1.0 / 120.0
			var levels := m.lamp_levels()
			for role: StringName in levels:
				var lv: Array = levels[role]
				for j in lv.size():
					var key := "%s%d" % [role, j]
					if int(lv[j]) == 0 and not first_out.has(key):
						first_out[key] = t
						last_out[role] = maxf(float(last_out.get(role, 0.0)), t)
						first_out[role] = minf(float(first_out.get(role, INF)), t)
			# Out means out for good: the part flickers on its way.
			if m.light_level() > 0.0:
				part_out = -1.0
			elif part_out < 0.0:
				part_out = t
			if t < MachineModel.LIGHT_FIRST:
				check(same_state(standing, joint_state(m), 1e-4), "%s moved at %.3f s, before its lights were out" % [kid, t])
		for i in order.size() - 1:
			for j in range(i + 1, order.size()):
				if last_out.has(order[i]) and first_out.has(order[j]):
					lt(float(last_out[order[i]]), float(first_out[order[j]]), "%s: every %s lamp is out before the first %s lamp" % [kid, order[i], order[j]])
		for role: StringName in last_out:
			if part_out >= 0.0:
				lt(float(last_out[role]), part_out, "%s: %s lamps out before the part" % [kid, role])
		gt(part_out, 0.0, "%s part goes out" % kid)
		lt(part_out, MachineModel.LIGHT_FIRST, "%s part out before the collapse" % kid)
		check(not m.scanning(), "%s beams and scans are out" % kid)
		m.free()


func test_scanners_throw_a_beam_that_sweeps_with_the_head() -> void:
	for kid in SCANNERS:
		var m := FigureModel.create(kid) as MachineModel
		var bs := beams(m, &"scan")
		eq(bs.size(), 1, "%s has one scan beam" % kid)
		if bs.is_empty():
			m.free()
			continue
		var beam: MeshInstance3D = bs[0]
		m.set_pose(&"stand")
		m.settle()
		check(beam.visible, "%s beam on while it looks" % kid)
		var dirs := {}
		for i in 150:
			m.animate(STEP * 2.0, 0.0)
			var d := m.model_space(beam).basis.x
			dirs["%.1f,%.1f" % [d.x, d.z]] = true
		gt(float(dirs.size()), 1.0, "%s beam sweeps as it looks round" % kid)
		m.free()


func test_work_washes_light_the_ground_only_after_dark() -> void:
	for kid in WASHES:
		var m := FigureModel.create(kid) as MachineModel
		var bs := beams(m, &"work")
		gt(float(bs.size()), 0.0, "%s has a work wash" % kid)
		var sun := with_sun(1.0)
		m.settle()
		for b: MeshInstance3D in bs:
			check(not b.visible, "%s wash dark by day" % kid)
		sun.light_energy = 0.55
		MachineModel._dark_frame = -1
		m.settle()
		for b: MeshInstance3D in bs:
			check(b.visible, "%s wash on at night" % kid)
		for lvl: int in m.lamp_levels().get(&"work", []):
			eq(lvl, 2, "%s work lamps hot at night" % kid)
		drop_sun(sun)
		m.free()


func test_every_kind_wears_its_years_and_its_trade() -> void:
	for kid in LIT:
		var m := FigureModel.create(kid) as MachineModel
		var wear := m.find_children("wear", "Node3D", true, false)
		gt(float(wear.size()), 0.0, "%s carries wear" % kid)
		m.free()
	# Trophies of the trade are matter on the machine, drawn by the hand.
	for trophy: Array in [[&"harvester", &"intake"], [&"hauler", &"load_f"], [&"hauler", &"load_r"], [&"warden", &"brim_r"], [&"dredger", &"hull"]]:
		var m := FigureModel.create(trophy[0]) as MachineModel
		var joint: Node3D = m.joints[trophy[1]]
		var holder := joint.get_node_or_null(^"wear") as Node3D
		check(holder != null, "%s has a trophy on its %s" % trophy)
		if holder != null:
			var b: int = m._bone_of.get(holder.get_instance_id(), -1)
			var matter: MeshInstance3D = m.surfaces.get(&"matter")
			var found := false
			if matter != null and b >= 0:
				var bones := matter.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES] as PackedInt32Array
				for i in range(0, bones.size(), 4):
					if bones[i] == b:
						found = true
						break
			check(found, "%s: the trophy on its %s is matter" % trophy)
		m.free()
