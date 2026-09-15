extends SceneTree
## Renders every generated sound to shots/audio/<key>.wav plus a picture of it
## (<key>.png), and prints the numbers the mix is held to, so a sound can be
## LOOKED at: envelope strip, log-frequency spectrogram (the 120 Hz laptop line
## drawn in), and a fine linear spectrum of 0-3 kHz where a machine's integer
## partials show as clean lines.
##   godot --headless --path . -s tools/gd/audio_dump.gd -- [filter] [--no-png]
##   ... -- --mix [--seed= --at= --walk= --hour= --weather= --machine= --cross --secs= --name=]
## Mix mode (SoundScene) renders what the player would hear at a place.

const OUT := "res://shots/audio"
const SPEC_W := 600
const SPEC_H := 260
const ENV_H := 40
const LIN_W := 300
const HEAD := 16
const PAD := 8
const LIN_MAX := 3000.0

var _rows: Array = []
var _mutex := Mutex.new()
var _keys: Array[StringName] = []
var _png := true


func _initialize() -> void:
	var filter := ""
	var mix_args: PackedStringArray = []
	var mix := false
	for a in OS.get_cmdline_user_args():
		if a == "--no-png":
			_png = false
		elif a == "--mix":
			mix = true
		elif a.begins_with("--"):
			mix_args.append(a)
		else:
			filter = a
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if mix:
		_run_mix(mix_args)
		quit()
		return
	var t0 := Time.get_ticks_msec()
	for k in SoundBank.all_keys():
		if filter == "" or String(k).contains(filter):
			_keys.append(k)
	var group := WorkerThreadPool.add_group_task(_one, _keys.size(), -1, true, "audio dump")
	WorkerThreadPool.wait_for_group_task_completion(group)
	_rows.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]) < String(b[0]))
	print("%-26s %-8s %6s %6s %4s %6s %7s %9s %6s %6s %6s %6s" % ["key", "cat", "secs", "rate", "loop", "ms", "heard", "window", "gain", "lf120", "seam", "peak"])
	var bad := 0
	for r: Array in _rows:
		var win: Array = SoundBank.CATEGORIES[r[1]]["window"]
		var ok: bool = r[6] >= win[0] - 0.05 and r[6] <= win[1] + 0.05
		if not ok:
			bad += 1
		print("%-26s %-8s %6.2f %6d %4s %6d %+7.1f %s%+4.0f..%+3.0f %+6.1f %5.1f%% %6s %+6.1f" % [r[0], r[1], r[2], r[3], "yes" if r[4] else "", r[5], r[6], " " if ok else "!", win[0], win[1], r[9], r[7] * 100.0, "%.2f" % r[8] if r[4] else "", r[10]])
	print("audio %d sounds, %d outside their window, %d ms -> %s" % [_rows.size(), bad, Time.get_ticks_msec() - t0, ProjectSettings.globalize_path(OUT)])
	quit()


## --mix: what the player hears at a place, through SoundScene.
##   --seed=N --size=N --at=X,Y --walk=DX,DY (tiles/s) --hour=H --secs=S
##   --weather=KIND:STRENGTH[:WIND] --machine=KIND:FROM:TO (tiles) --cross --name=LABEL
## --cross walks east across the country border nearest --at (or the spawn).
func _run_mix(args: PackedStringArray) -> void:
	var t0 := Time.get_ticks_msec()
	var scene := {}
	var name := "mix"
	var cross := false
	for a in args:
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"seed": scene["seed"] = v.to_int()
			"size": scene["size"] = v.to_int()
			"at":
				var p := v.split(",")
				scene["at"] = Vector2(p[0].to_float(), p[1].to_float())
			"walk":
				var p := v.split(",")
				scene["walk"] = Vector2(p[0].to_float(), p[1].to_float())
			"hour": scene["hour"] = v.to_float()
			"secs": scene["secs"] = v.to_float()
			"weather":
				var p := v.split(":")
				scene["weather"] = {"kind": StringName(p[0]), "strength": p[1].to_float() if p.size() > 1 else 1.0, "wind": p[2].to_float() if p.size() > 2 else 0.3}
			"machine":
				var p := v.split(":")
				scene["machine"] = {"kind": StringName(p[0]), "from": p[1].to_float() if p.size() > 1 else 20.0, "to": p[2].to_float() if p.size() > 2 else 0.0}
			"cross": cross = true
			"name": name = v
	var world := WorldGen.generate(int(scene.get("seed", 1)), int(scene.get("size", Tuning.WORLD_SIZE)))
	if cross:
		var walk := SoundScene.border_walk(world, scene.get("at", world.spawn))
		for k: String in walk:
			if k != "secs" or not scene.has("secs"):
				scene[k] = walk[k]
	var out := SoundScene.render(scene, world)
	var samples: PackedFloat32Array = out["samples"]
	var file := "mix_" + name
	var wav := Synth.to_wav(samples, SoundScene.RATE, false)
	wav.save_to_wav(ProjectSettings.globalize_path(OUT.path_join(file + ".wav")))
	var peak := Synth.peak(samples)
	var heard := SoundScene.heard_db(samples, 0.0, samples.size() / float(SoundScene.RATE))
	var lanes: Dictionary = out["lanes"]
	var path: Array = out["path"]
	print("mix %s: seed %d from %s to %s, %.1f s, heard %+.1f dB (loudest 0.5 s vs rain), peak %.2f" % [name, world.seed_value, str(path[0]), str(path[-1]), samples.size() / float(SoundScene.RATE), heard, peak])
	for bed: StringName in lanes:
		var lane: PackedFloat32Array = lanes[bed]
		var hi := 0.0
		for x in lane:
			hi = maxf(hi, x)
		if hi > 0.005:
			print("  %-18s max %.2f  start %.2f  end %.2f" % [bed, hi, lane[0], lane[-1]])
	if _png:
		var img := mix_picture(out, name, heard)
		img.save_png(ProjectSettings.globalize_path(OUT.path_join(file + ".png")))
	print("mix -> %s (%d ms)" % [ProjectSettings.globalize_path(OUT.path_join(file + ".wav")), Time.get_ticks_msec() - t0])


const LANE_H := 110
const LANE_COLOURS := [
	Color8(232, 194, 58), Color8(120, 190, 220), Color8(150, 210, 120), Color8(230, 120, 90),
	Color8(200, 150, 230), Color8(240, 240, 240), Color8(110, 140, 230), Color8(220, 170, 120),
]
## sea, coast, moss, pinewood, snowfield, bonelands, burning: far apart on purpose.
const COUNTRY_COLOURS := [
	Color8(40, 70, 140), Color8(230, 200, 90), Color8(60, 170, 110), Color8(30, 100, 50),
	Color8(235, 240, 250), Color8(150, 120, 200), Color8(220, 70, 40),
]


static func _country_names(countries: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for c: int in countries:
		var n := Country.NAMES[c]
		if out.is_empty() or out[-1] != n:
			out.append(n)
	return out


## Bed levels over time (one coloured line each, named on the right), the
## country underfoot as a strip, then the mix: envelope and spectrogram.
static func mix_picture(out: Dictionary, name: String, heard: float) -> Image:
	var samples: PackedFloat32Array = out["samples"]
	var lanes: Dictionary = out["lanes"]
	var countries: Array = out["countries"]
	var b := SoundBank.Baked.new()
	b.key = StringName("mix " + name)
	b.category = &"bed"
	b.rate = SoundScene.RATE
	b.samples = samples
	var w := PAD + SPEC_W + PAD * 3 + LIN_W + PAD
	var h := HEAD + LANE_H + 6 + PAD + ENV_H + PAD + SPEC_H + 14
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color8(12, 11, 20))
	var x0 := PAD + 18
	var spec_w := SPEC_W - 18
	text(img, PAD, 4, "MIX %s  %.1fS  HEARD %+.1fDB" % [name.to_upper(), samples.size() / float(SoundScene.RATE), heard], Color8(232, 194, 58))
	var top := HEAD
	for gy: float in [0.0, 0.5, 1.0]:
		var y := top + LANE_H - 1 - roundi(gy * (LANE_H - 1))
		for x in range(x0, x0 + spec_w, 3):
			img.set_pixel(x, y, Color8(50, 46, 80))
	var k := 0
	var label_y := top
	for bed: StringName in lanes:
		var lane: PackedFloat32Array = lanes[bed]
		var hi := 0.0
		for v in lane:
			hi = maxf(hi, v)
		if hi < 0.005:
			continue
		var col: Color = LANE_COLOURS[k % LANE_COLOURS.size()]
		k += 1
		var prev := -1
		for x in spec_w:
			var v := lane[mini(lane.size() - 1, floori(float(x) * lane.size() / spec_w))]
			var y := top + LANE_H - 1 - roundi(clampf(v, 0.0, 1.2) / 1.2 * (LANE_H - 1))
			if prev >= 0:
				for yy in range(mini(prev, y), maxi(prev, y) + 1):
					img.set_pixel(x0 + x, yy, col)
			img.set_pixel(x0 + x, y, col)
			prev = y
		text(img, x0 + spec_w + PAD * 3, label_y, String(bed).to_upper(), col)
		label_y += 8
	var strip := top + LANE_H + 2
	var last := -1
	for x in spec_w:
		var c: int = countries[mini(countries.size() - 1, floori(float(x) * countries.size() / spec_w))]
		for y in 4:
			img.set_pixel(x0 + x, strip + y, COUNTRY_COLOURS[clampi(c, 0, COUNTRY_COLOURS.size() - 1)])
		if last >= 0 and c != last:
			# Where the country underfoot changes, a line through the lanes.
			for y in range(top, strip):
				if y % 2 == 0:
					img.set_pixel(x0 + x, y, Color8(150, 140, 200))
		last = c
	text(img, x0 + spec_w + PAD * 3, strip - 2, " ".join(_country_names(countries)).to_upper(), Color8(150, 140, 200))
	var env_top := strip + 6 + PAD
	_envelope(img, b, Rect2i(x0, env_top, spec_w, ENV_H))
	_spectrogram(img, b, Rect2i(x0, env_top + ENV_H + PAD, spec_w, SPEC_H))
	return img


func _one(i: int) -> void:
	var key := _keys[i]
	var b := SoundBank.render(key)
	var file := String(key).replace(":", "_")
	var wav := Synth.to_wav(b.samples, b.rate, b.loop)
	wav.save_to_wav(ProjectSettings.globalize_path(OUT.path_join(file + ".wav")))
	var heard := SoundMix.heard_db(b)
	var lf := Synth.low_energy_ratio(b.samples, b.rate, 120.0)
	var seam := Synth.seam_ratio(b.samples) if b.loop else 0.0
	if _png:
		var img := picture(b, heard, lf)
		img.save_png(ProjectSettings.globalize_path(OUT.path_join(file + ".png")))
	_mutex.lock()
	# Peak after the call gain and the buses, dBFS: what the limiter would see.
	var peak_out := 20.0 * log(maxf(1e-9, Synth.peak(b.samples))) / log(10.0) + b.gain_db + SoundMix.bus_db(b.bus)
	_rows.append([key, b.category, b.samples.size() / float(b.rate), b.rate, b.loop, b.ms, heard, lf, seam, b.gain_db, peak_out])
	_mutex.unlock()


# ---------------------------------------------------------------- picture

static func picture(b: SoundBank.Baked, heard: float, lf: float) -> Image:
	var w := PAD + SPEC_W + PAD * 3 + LIN_W + PAD
	var h := HEAD + ENV_H + PAD + SPEC_H + 14
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color8(12, 11, 20))
	var x0 := PAD + 18
	var spec_w := SPEC_W - 18
	var title := "%s  %s  %.2fS  %dHZ%s  HEARD %+.1fDB  GAIN %+.1fDB  LF120 %.1f%%" % [String(b.key).to_upper(), String(b.category).to_upper(), b.samples.size() / float(b.rate), b.rate, "  LOOP" if b.loop else "", heard, b.gain_db, lf * 100.0]
	text(img, PAD, 4, title, Color8(232, 194, 58))
	_envelope(img, b, Rect2i(x0, HEAD, spec_w, ENV_H))
	_spectrogram(img, b, Rect2i(x0, HEAD + ENV_H + PAD, spec_w, SPEC_H))
	_linear(img, b, Rect2i(x0 + spec_w + PAD * 3, HEAD, LIN_W, ENV_H + PAD + SPEC_H))
	return img


static func _envelope(img: Image, b: SoundBank.Baked, r: Rect2i) -> void:
	var n := b.samples.size()
	var mid := r.position.y + r.size.y / 2
	for x in r.size.x:
		var a := floori(float(x) * n / r.size.x)
		var e := mini(n, floori(float(x + 1) * n / r.size.x))
		var p := 0.0
		var s := 0.0
		for i in range(a, maxi(a + 1, e)):
			var v := absf(b.samples[mini(i, n - 1)])
			p = maxf(p, v)
			s += v * v
		var rr := sqrt(s / maxf(1.0, e - a))
		var hp := roundi(p / SoundBank.PEAK * (r.size.y / 2 - 1))
		var hr := roundi(rr / SoundBank.PEAK * (r.size.y / 2 - 1))
		for y in range(-hp, hp + 1):
			img.set_pixel(r.position.x + x, mid + y, Color8(70, 62, 110))
		for y in range(-hr, hr + 1):
			img.set_pixel(r.position.x + x, mid + y, Color8(150, 140, 200))
	# Whole seconds.
	for sec in range(0, ceili(float(n) / b.rate) + 1):
		var x := r.position.x + roundi(float(sec * b.rate) / n * r.size.x)
		if x < r.position.x + r.size.x:
			for y in range(r.position.y, r.position.y + 4):
				img.set_pixel(x, y, Color8(232, 194, 58))


static func _spectrogram(img: Image, b: SoundBank.Baked, r: Rect2i) -> void:
	var n := b.samples.size()
	var nfft := 2048 if b.rate > 30000 else 1024
	var fmin := 40.0
	var fmax := b.rate * 0.5
	var cols := mini(r.size.x, maxi(8, ceili(float(n) / (nfft / 8.0))))
	var win := PackedFloat64Array()
	win.resize(nfft)
	for i in nfft:
		win[i] = 0.5 - 0.5 * cos(TAU * i / (nfft - 1))
	# Per output row, the band of bins it covers (log frequency).
	var row_lo := PackedInt32Array()
	var row_hi := PackedInt32Array()
	var binhz := float(b.rate) / nfft
	for y in r.size.y:
		var f0 := fmin * pow(fmax / fmin, float(y) / r.size.y)
		var f1 := fmin * pow(fmax / fmin, float(y + 1) / r.size.y)
		row_lo.append(clampi(floori(f0 / binhz), 1, nfft / 2 - 1))
		row_hi.append(clampi(ceili(f1 / binhz), 1, nfft / 2 - 1))
	var mags: Array[PackedFloat32Array] = []
	# Absolute: a full-scale sine reads 0 dB, so quiet sounds look quiet.
	var top := nfft / 4.0
	var re := PackedFloat64Array()
	var im := PackedFloat64Array()
	re.resize(nfft)
	im.resize(nfft)
	for c in cols:
		var center := roundi((c + 0.5) * n / cols)
		var start := center - nfft / 2
		for i in nfft:
			var k := start + i
			var v := 0.0
			if b.loop:
				v = b.samples[posmod(k, n)]
			elif k >= 0 and k < n:
				v = b.samples[k]
			re[i] = v * win[i]
			im[i] = 0.0
		fft(re, im)
		var col := PackedFloat32Array()
		col.resize(nfft / 2)
		for i in nfft / 2:
			col[i] = sqrt(re[i] * re[i] + im[i] * im[i])
		mags.append(col)
	for x in r.size.x:
		var col := mags[mini(cols - 1, floori(float(x) * cols / r.size.x))]
		for y in r.size.y:
			var m := 0.0
			for k in range(row_lo[y], row_hi[y] + 1):
				m = maxf(m, col[k])
			var db := 20.0 * log(maxf(1e-9, m / top)) / log(10.0)
			img.set_pixel(r.position.x + x, r.position.y + r.size.y - 1 - y, heat(clampf((db + 96.0) / 90.0, 0.0, 1.0)))
	for f: float in [120.0, 250.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0]:
		if f >= fmax:
			continue
		var y := r.position.y + r.size.y - 1 - roundi(log(f / fmin) / log(fmax / fmin) * r.size.y)
		var lab := ("%dK" % roundi(f / 1000.0)) if f >= 1000.0 else "%d" % roundi(f)
		var col := Color8(255, 90, 90) if f == 120.0 else Color8(90, 90, 120)
		for x in range(r.position.x - 3, r.position.x + r.size.x, 1 if f == 120.0 else 4):
			img.set_pixel(x, y, col)
		text(img, r.position.x - 18, y - 2, lab, col)


static func _linear(img: Image, b: SoundBank.Baked, r: Rect2i) -> void:
	var n := b.samples.size()
	var nfft := 32768
	while nfft > n and nfft > 1024:
		nfft /= 2
	var acc := PackedFloat64Array()
	acc.resize(nfft / 2)
	acc.fill(0.0)
	var re := PackedFloat64Array()
	var im := PackedFloat64Array()
	re.resize(nfft)
	im.resize(nfft)
	var windows := clampi(n / (nfft / 2), 1, 8)
	for wi in windows:
		var start := roundi(float(wi) * maxi(0, n - nfft) / maxf(1.0, windows - 1.0))
		for i in nfft:
			var k := start + i
			var v := b.samples[k % n] if (b.loop or k < n) else 0.0
			re[i] = v * (0.5 - 0.5 * cos(TAU * i / (nfft - 1)))
			im[i] = 0.0
		fft(re, im)
		for i in nfft / 2:
			acc[i] += sqrt(re[i] * re[i] + im[i] * im[i])
	var top := 1e-9
	var binhz := float(b.rate) / nfft
	var last := mini(nfft / 2 - 1, ceili(LIN_MAX / binhz))
	for i in range(1, last):
		top = maxf(top, acc[i])
	var bottom := r.position.y + r.size.y - 12
	var height := r.size.y - 12
	for x in r.size.x:
		var k0 := clampi(floori(float(x) / r.size.x * LIN_MAX / binhz), 1, last)
		var k1 := clampi(floori(float(x + 1) / r.size.x * LIN_MAX / binhz), k0, last)
		var m := 0.0
		for k in range(k0, k1 + 1):
			m = maxf(m, acc[k])
		var db := 20.0 * log(maxf(1e-9, m / top)) / log(10.0)
		var t := clampf((db + 72.0) / 72.0, 0.0, 1.0)
		var hh := roundi(t * height)
		for y in hh:
			img.set_pixel(r.position.x + x, bottom - y, heat(0.25 + 0.75 * float(y) / maxf(1.0, height)))
	for f in range(0, int(LIN_MAX) + 1, 500):
		var x := r.position.x + roundi(f / LIN_MAX * (r.size.x - 1))
		for y in range(bottom + 1, bottom + 4):
			img.set_pixel(x, y, Color8(150, 140, 200))
		if f > 0:
			text(img, x - 6, bottom + 5, "%.1fK" % (f / 1000.0) if f % 1000 != 0 else "%dK" % (f / 1000), Color8(150, 140, 200))
	text(img, r.position.x, r.position.y, "0-3KHZ LINEAR", Color8(150, 140, 200))


static func heat(t: float) -> Color:
	var stops: Array[Color] = [Color8(7, 6, 13), Color8(42, 31, 85), Color8(106, 63, 154), Color8(208, 102, 58), Color8(232, 194, 58), Color8(255, 243, 192)]
	var at: Array[float] = [0.0, 0.3, 0.55, 0.75, 0.9, 1.0]
	for i in range(1, stops.size()):
		if t <= at[i]:
			return stops[i - 1].lerp(stops[i], (t - at[i - 1]) / (at[i] - at[i - 1]))
	return stops[-1]


static func fft(re: PackedFloat64Array, im: PackedFloat64Array) -> void:
	var n := re.size()
	var j := 0
	for i in range(1, n):
		var bit := n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j ^= bit
		if i < j:
			var t := re[i]
			re[i] = re[j]
			re[j] = t
			t = im[i]
			im[i] = im[j]
			im[j] = t
	var size := 2
	while size <= n:
		var ang := -TAU / size
		var wr := cos(ang)
		var wi := sin(ang)
		var half := size >> 1
		var i := 0
		while i < n:
			var cr := 1.0
			var ci := 0.0
			for k in half:
				var a := i + k
				var bb := a + half
				var tr := re[bb] * cr - im[bb] * ci
				var ti := re[bb] * ci + im[bb] * cr
				re[bb] = re[a] - tr
				im[bb] = im[a] - ti
				re[a] += tr
				im[a] += ti
				var ncr := cr * wr - ci * wi
				ci = cr * wi + ci * wr
				cr = ncr
			i += size
		size <<= 1


# ------------------------------------------------------------ a tiny font

const GLYPHS := {
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
	"4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001001001",
	"8": "111101111101111", "9": "111101111001111", "A": "010101111101101", "B": "110101110101110",
	"C": "011100100100011", "D": "110101101101110", "E": "111100110100111", "F": "111100110100100",
	"G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "J": "001001001101010",
	"K": "101101110101101", "L": "100100100100111", "M": "101111111101101", "N": "110101101101101",
	"O": "010101101101010", "P": "110101110100100", "Q": "010101101110011", "R": "110101110101101",
	"S": "011100010001110", "T": "111010010010010", "U": "101101101101111", "V": "101101101101010",
	"W": "101101111111101", "X": "101101010101101", "Y": "101101010010010", "Z": "111001010100111",
	".": "000000000000010", ":": "000010000010000", "-": "000000111000000", "+": "000010111010000",
	"_": "000000000000111", "%": "101001010100101", "/": "001001010100100", "=": "000111000111000",
	"(": "010100100100010", ")": "010001001001010", ",": "000000000010100",
}


static func text(img: Image, x: int, y: int, s: String, col: Color) -> void:
	var cx := x
	for ch in s:
		var g: String = GLYPHS.get(ch.to_upper(), "")
		if g != "":
			for gy in 5:
				for gx in 3:
					if g[gy * 3 + gx] == "1":
						var px := cx + gx
						var py := y + gy
						if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
							img.set_pixel(px, py, col)
		cx += 4
