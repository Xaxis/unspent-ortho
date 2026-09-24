extends SceneTree
## HOW BIG EACH LANDSCAPE'S PLACE IS, measured, per landscape and seed.
##
##   godot --headless --path . -s tools/gd/probe_regions.gd -- --seeds=1,42,90210 [--size=N]
##
## Written for the owner's "the immensity each region should present vs the
## current 'walk a few paces and youre in a different landscape'". Each number is
## a question a player's eyes or legs ask, not a property of the generator:
##
##   frames   the main region's tiles over one top-down play frame (26.7 x 17.9)
##   core_s   seconds at a run (5.4 tiles/s) across the widest disc of the main
##            region that is all its own landscape: the core, not the bounds
##   eco      how deep the ecotone reaches into this landscape from its border,
##            in tiles (tiles with any `blend` over the border tiles): the width
##            of a slow blend, never a line
##   own      from the shoulder (eye ~2 units up, the frame's floor PITCH + FOV/2
##            down) at the core, all the way round out to SkyLight.SEE: the share
##            of the LAND in view, weighted by the screen it takes, that is this
##            landscape. Near ground dominates it; read `mid` and `far`.
##   mid      the same past MID_BAND tiles: the land beyond your own surroundings
##   far      the same past FAR_BAND tiles: what reads on the horizon, the
##            owner's complaint
##   lands    how many landscapes hold at least 5% of that horizon band
##   poi      things worth walking to inside the main region: landmarks, sites,
##            villages, the depot, the keeper's lair
##   reach    share of the main region within POI_REACH tiles of one of them
##   gap_s    the longest run from anywhere in the main region to the nearest
##            one, in seconds: an empty walk
##   road     share of the main region's tiles a road crosses
##   read     how far off a landmark of the main region READS at eye level, in
##            tiles, median over its landmarks and 36 bearings: the farthest a
##            standing eye (EYE_STAND up) still sees its top over the land
##            between, and no farther than its height holds READ_DEG of the
##            frame (a shape, not a speck)
##
## Headless, deterministic, no rendering: a world grown by BootWorld and read.

const FRAME_TILES := 26.7 * 17.9
const RUN := 5.4
const FAR_BAND := 250.0
const POI_REACH := 40.0
const SEE := 900.0
const EYE_UP := 1.98
const PITCH := 10.0
const FOV := 60.0
const ASPECT := 16.0 / 9.0
const AZIMUTHS := 720
const EYE_STAND := 1.7
## The least angle a landmark has to stand to read as a shape: 12 pixels of the
## 1080 a 60-degree frame is drawn in.
const READ_DEG := 0.67
const MID_BAND := 30.0

var _road := 0
## A directory to write one landscape map per seed into (`regions_<seed>.png`).
var _map := ""


func _init() -> void:
	var seeds: Array[int] = [1, 42, 90210]
	var size := Tuning.WORLD_SIZE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds.clear()
			for s in a.trim_prefix("--seeds=").split(","):
				seeds.append(s.to_int())
		elif a.begins_with("--map="):
			_map = a.trim_prefix("--map=")
		elif a.begins_with("--size="):
			size = a.trim_prefix("--size=").to_int()
	GearEconomy.declare(true)
	print("regions size %d seeds %s GEN %d" % [size, seeds, WorldStamp.GEN])
	print("regions %-18s %6s %4s %6s %6s %5s %5s %5s %4s %4s %5s %6s %5s %6s %5s %5s" % [
		"land", "seed", "runs", "tiles", "frames", "core_s", "eco", "own", "mid", "far", "lands", "poi", "reach", "gap_s", "road", "read"])
	for s in seeds:
		var t0 := Time.get_ticks_msec()
		var w := BootWorld.world(s, size)
		print("regions grew seed %d in %d ms, %d continents, %d regions" % [s, Time.get_ticks_msec() - t0, w.continents.size(), w.regions.size()])
		_seed(w)
		if _map != "":
			_draw(w)
	quit()


## Every landscape in its own colour, the blend shaded toward black, each
## region's edge drawn dark: the patchwork (or the lack of it) at a glance.
func _draw(w: WorldData) -> void:
	var n := w.size
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var sea := Color(0.06, 0.1, 0.18)
	for y in n:
		for x in n:
			var i := y * n + x
			if w.level[i] <= 0:
				img.set_pixel(x, y, sea)
				continue
			var c := int(w.country[i])
			var col := Color.from_hsv(fposmod(float(c) * 0.618034, 1.0), 0.55, 0.85)
			col = col.lerp(Color.BLACK, w.blend[i] * 0.6)
			if x > 0 and y > 0 and (w.region[i] != w.region[i - 1] or w.region[i] != w.region[i - n]):
				col = Color(0.05, 0.05, 0.05)
			img.set_pixel(x, y, col)
	var path := _map.path_join("regions_%d.png" % w.seed_value)
	var abs_path := path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	img.save_png(abs_path)
	print("regions map ", abs_path)


func _seed(w: WorldData) -> void:
	for row: Dictionary in w.continents:
		if not row.has("types"):
			continue
		var names: PackedStringArray = []
		for cc: int in (row.types as PackedInt32Array):
			names.append(str(BiomeRegistry.by_index(cc).id))
		var home := " home" if w.continent_at(floori(w.spawn.x), floori(w.spawn.y)) == int(row.id) else ""
		print("regions body %d%s at %s: %s" % [int(row.id), home, (row.centre as Vector2).round(), ", ".join(names)])
	var lm := Landmarks.sites(w)
	var ws := Works.sites(w)
	var ks := Sentinels.states(w)
	var sites := 0
	for m: Dictionary in w.landmarks:
		if bool(m.get("site", false)):
			sites += 1
	var missing: PackedStringArray = []
	var held := {}
	for i in w.country.size():
		if w.level[i] > 0:
			held[int(w.country[i])] = true
	for d: BiomeDef in BiomeRegistry.land_in(w.realm):
		if not held.has(d.index):
			missing.append(str(d.id))
	print("regions world %d: %d regions (chapters, asks), %d keepers, %d depots, %d landmarks, %d sites, %d villages, missing [%s]" % [
		w.seed_value, w.regions.size(), ks.size(), ws.size(), lm.size(), sites, w.villages.size(), ", ".join(missing)])
	for d: BiomeDef in BiomeRegistry.land_in(w.realm):
		var main := {}
		var runs := 0
		for r: Dictionary in w.regions:
			if StringName(str(r.get("type", &""))) != d.id:
				continue
			runs += 1
			if main.is_empty() or int(r.tiles) > int(main.tiles):
				main = r
		if main.is_empty():
			print("regions %-18s %6d %4d  NO REGION" % [d.id, w.seed_value, 0])
			continue
		var id := int(main.id)
		var bounds: Rect2 = main.bounds
		var core := _core(w, id, bounds)
		var eco := _ecotone(w, d.index)
		var view := _view(w, d.index, Vector2(core.x, core.y))
		var poi: Array[Vector2] = []
		var reads: Array[float] = []
		for s: LandmarkSite in lm:
			if s.region == id:
				poi.append(s.pos)
				reads.append(_reads(w, s))
		reads.sort()
		var read := reads[reads.size() / 2] if not reads.is_empty() else 0.0
		for m: Dictionary in w.landmarks:
			var p: Vector2 = m.get("pos", Vector2.ZERO)
			if bool(m.get("site", false)) and w.region_at(floori(p.x), floori(p.y)) == id:
				poi.append(p)
		for v: Dictionary in w.villages:
			var p: Vector2 = v.pos
			if w.region_at(floori(p.x), floori(p.y)) == id:
				poi.append(p)
		for s: WorksSite in ws:
			if s.region == id:
				poi.append(s.pos)
		for s: SentinelState in ks:
			if s.region == id:
				poi.append(s.lair)
		_road = 0
		var walk := _walk(w, id, bounds, poi)
		print("regions %-18s %6d %4d %6d %6.1f %5.0f %5.1f %5.2f %4.2f %4.2f %5d %6d %5.2f %6.0f %5.3f %5.0f" % [
			d.id, w.seed_value, runs, int(main.tiles), float(main.tiles) / FRAME_TILES,
			2.0 * core.z / RUN, eco, view.x, view.y, view.z, int(view.w), poi.size(), walk.x, walk.y / RUN, float(_road) / maxf(1.0, float(main.tiles)), read])


## The widest disc of the main region: x, y its centre, z its radius in tiles.
## A two-pass chamfer distance to the nearest tile NOT in the region (sea and
## other landscapes alike), inside the region's bounds grown by one.
func _core(w: WorldData, id: int, b: Rect2) -> Vector3:
	var x0 := maxi(0, int(b.position.x) - 1)
	var y0 := maxi(0, int(b.position.y) - 1)
	var x1 := mini(w.size, int(b.end.x) + 2)
	var y1 := mini(w.size, int(b.end.y) + 2)
	var bw := x1 - x0
	var bh := y1 - y0
	var d := PackedFloat32Array()
	d.resize(bw * bh)
	for y in bh:
		for x in bw:
			d[y * bw + x] = 1e9 if w.region[(y + y0) * w.size + x + x0] - 1 == id else 0.0
	const A := 1.0
	const B := 1.41421
	for y in bh:
		for x in bw:
			var i := y * bw + x
			if d[i] == 0.0:
				continue
			var v := d[i]
			if x > 0: v = minf(v, d[i - 1] + A)
			else: v = minf(v, A)
			if y > 0:
				v = minf(v, d[i - bw] + A)
				if x > 0: v = minf(v, d[i - bw - 1] + B)
				if x < bw - 1: v = minf(v, d[i - bw + 1] + B)
			else: v = minf(v, A)
			d[i] = v
	var best := Vector3(0, 0, 0)
	for y in range(bh - 1, -1, -1):
		for x in range(bw - 1, -1, -1):
			var i := y * bw + x
			if d[i] == 0.0:
				continue
			var v := d[i]
			if x < bw - 1: v = minf(v, d[i + 1] + A)
			else: v = minf(v, A)
			if y < bh - 1:
				v = minf(v, d[i + bw] + A)
				if x < bw - 1: v = minf(v, d[i + bw + 1] + B)
				if x > 0: v = minf(v, d[i + bw - 1] + B)
			else: v = minf(v, A)
			d[i] = v
			if v > best.z:
				best = Vector3(x + x0 + 0.5, y + y0 + 0.5, v)
	return best


## How deep a landscape's ecotone reaches in from its borders, in tiles: its land
## tiles with any blend toward a neighbour, over its land tiles on a border.
func _ecotone(w: WorldData, cc: int) -> float:
	var border := 0
	var band := 0
	var n := w.size
	for y in range(1, n - 1):
		for x in range(1, n - 1):
			var i := y * n + x
			if w.country[i] != cc or w.level[i] <= 0:
				continue
			if w.blend[i] > 0.01:
				band += 1
			for j: int in [i - 1, i + 1, i - n, i + n]:
				if w.level[j] > 0 and w.country[j] != cc:
					border += 1
					break
	return float(band) / maxf(1.0, float(border))


## What the eye sees from the core, all the way round: a viewshed per bearing
## (AZIMUTHS of them), each visible tile weighted by the angle it adds above what
## is already hidden behind -- the share of the SCREEN it takes -- from the bottom
## of the shoulder's frame (PITCH + FOV/2 down) out to SEE. Returns x the share of
## land in view that is `cc`, y the same past MID_BAND tiles (the land beyond the
## player's own surroundings), z the same past FAR_BAND (the horizon), w how many
## landscapes hold 5% of that horizon.
func _view(w: WorldData, cc: int, at: Vector2) -> Vector4:
	var n := w.size
	var eye_h := float(w.level_at(floori(at.x), floori(at.y))) * WorldData.STEP + EYE_UP
	var floor_ang := -deg_to_rad(PITCH + FOV * 0.5)
	var sums := PackedFloat32Array()
	sums.resize(6)
	var far_by := {}
	for a in AZIMUTHS:
		var yaw := TAU * float(a) / AZIMUTHS
		var dx := cos(yaw)
		var dy := sin(yaw)
		var top := floor_ang
		var t := 1.0
		while t < SEE:
			var ix := floori(at.x + dx * t)
			var iy := floori(at.y + dy * t)
			if ix < 0 or iy < 0 or ix >= n or iy >= n:
				break
			var i := iy * n + ix
			var lv := w.level[i]
			var gh := maxf(float(lv) * WorldData.STEP, Swim.WATER_Y)
			var ang := atan2(gh - eye_h, t)
			if ang > top:
				var wgt := ang - top
				top = ang
				if lv > 0:
					var mine := int(w.country[i]) == cc
					sums[0] += wgt
					if mine: sums[1] += wgt
					if t > MID_BAND:
						sums[2] += wgt
						if mine: sums[3] += wgt
					if t > FAR_BAND:
						sums[4] += wgt
						if mine: sums[5] += wgt
						far_by[int(w.country[i])] = float(far_by.get(int(w.country[i]), 0.0)) + wgt
			t += maxf(0.5, t * 0.01)
	var lands := 0
	for c: int in far_by:
		if float(far_by[c]) >= 0.05 * sums[4]:
			lands += 1
	return Vector4(sums[1] / maxf(1e-6, sums[0]), sums[3] / maxf(1e-6, sums[2]),
		sums[5] / maxf(1e-6, sums[4]), lands)


## How far off one landmark reads, in tiles: see the header's `read`.
func _reads(w: WorldData, s: LandmarkSite) -> float:
	var high := LandmarkModels.high_of(s.kind)
	var top := float(w.level_at(floori(s.pos.x), floori(s.pos.y))) * WorldData.STEP + high
	var most := minf(SEE, high / tan(deg_to_rad(READ_DEG)))
	var n := w.size
	var got: Array[float] = []
	for b in 36:
		var a := TAU * float(b) / 36.0
		var dx := cos(a)
		var dy := sin(a)
		var worst := -INF
		var seen := 0.0
		var t := 1.0
		while t < most:
			var ix := floori(s.pos.x + dx * t)
			var iy := floori(s.pos.y + dy * t)
			if ix < 0 or iy < 0 or ix >= n or iy >= n:
				break
			var gh := maxf(float(w.level[iy * n + ix]) * WorldData.STEP, Swim.WATER_Y)
			# The eye standing here sees the top if the line down to it clears
			# everything nearer the landmark.
			if (gh + EYE_STAND - top) / t >= worst:
				seen = t
			worst = maxf(worst, (gh - top) / t)
			t += maxf(1.0, t * 0.02)
		got.append(seen)
	got.sort()
	return got[got.size() / 2]


## Over the main region: x the share of its tiles within POI_REACH of a point
## worth walking to, y the longest distance any tile is from one (a BFS through
## the region's own tiles, so a point across a bay is not "near").
func _walk(w: WorldData, id: int, b: Rect2, poi: Array[Vector2]) -> Vector2:
	var x0 := maxi(0, int(b.position.x))
	var y0 := maxi(0, int(b.position.y))
	var x1 := mini(w.size, int(b.end.x) + 1)
	var y1 := mini(w.size, int(b.end.y) + 1)
	var bw := x1 - x0
	var bh := y1 - y0
	var dist := PackedInt32Array()
	dist.resize(bw * bh)
	dist.fill(-1)
	var q := PackedInt32Array()
	var total := 0
	for y in bh:
		for x in bw:
			var ti := (y + y0) * w.size + x + x0
			if w.region[ti] - 1 == id:
				total += 1
				if not w.road.is_empty() and w.road[ti] != 0:
					_road += 1
	for p in poi:
		var ix := floori(p.x) - x0
		var iy := floori(p.y) - y0
		if ix < 0 or iy < 0 or ix >= bw or iy >= bh:
			continue
		var k := iy * bw + ix
		if dist[k] < 0:
			dist[k] = 0
			q.append(k)
	if q.is_empty():
		return Vector2(0.0, INF)
	var head := 0
	var near := 0
	var worst := 0
	while head < q.size():
		var k := q[head]
		head += 1
		var dk := dist[k]
		var x := k % bw
		var y := k / bw
		if w.region[(y + y0) * w.size + x + x0] - 1 == id:
			worst = maxi(worst, dk)
			if dk <= POI_REACH:
				near += 1
		for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + dd.x
			var ny := y + dd.y
			if nx < 0 or ny < 0 or nx >= bw or ny >= bh:
				continue
			var j := ny * bw + nx
			if dist[j] >= 0:
				continue
			if w.region[(ny + y0) * w.size + nx + x0] - 1 != id:
				continue
			dist[j] = dk + 1
			q.append(j)
	return Vector2(float(near) / maxf(1.0, float(total)), float(worst))
