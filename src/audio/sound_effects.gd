class_name SoundEffects
## One-shots for Events.sfx names: footfalls per ground, the fight, taking and
## making, fire and water, thunder, and the interface. Unknown names are ignored
## by the audio system, so emitting a name before its recipe exists is safe.
##
## Contract for emitters (Events.sfx(name, at)):
##   step_<family>   (the audio system also makes the player's own from movement)
##   swing whiff hit_flesh hit_plate dodge grip pull
##   break dig fell cut gather craft eat fire splash tree_fall pickup
##   machine_down alert downed lamp_on lamp_off door
##   thunder thunder_far
##   ui_move ui_accept ui_back ui_refuse
## A refusal is a different sound from an acceptance, never a louder one.

## Ground -> footfall family.
const STEP_FAMILY := {
	Ground.DEEP_WATER: &"water", Ground.WATER: &"water", Ground.RIVER: &"water", Ground.BLACKWATER: &"water",
	Ground.SAND: &"sand", Ground.GRASS: &"grass", Ground.HEATH: &"heath",
	Ground.MOSS: &"mud", Ground.MUD: &"mud", Ground.PEAT: &"mud",
	Ground.NEEDLES: &"needles", Ground.SNOW: &"snow", Ground.ICE: &"ice",
	Ground.ROCK: &"stone", Ground.LIMESTONE: &"stone", Ground.BONE: &"stone",
	Ground.GRAVEL: &"gravel", Ground.SCREE: &"gravel", Ground.SHINGLE: &"shingle",
	Ground.ASH: &"ash", Ground.CLINKER: &"clinker", Ground.ROAD: &"dirt", Ground.FLOOR: &"wood",
}

const FAMILIES: Array[StringName] = [
	&"sand", &"grass", &"heath", &"mud", &"needles", &"snow", &"ice", &"stone",
	&"gravel", &"shingle", &"ash", &"clinker", &"dirt", &"wood", &"water",
]


static func step_name(ground: int) -> StringName:
	return StringName("step_" + String(STEP_FAMILY.get(ground, &"dirt")))


static func make(name: StringName, variant: int, rate: int) -> PackedFloat32Array:
	var s := String(name)
	if s.begins_with("step_"):
		return _step(StringName(s.substr(5)), variant, rate)
	match name:
		&"swing": return _swing(rate, variant)
		&"whiff": return _whiff(rate, variant)
		&"hit_flesh": return _hit_flesh(rate, variant)
		&"hit_plate": return _hit_plate(rate, variant)
		&"dodge": return _dodge(rate, variant)
		&"grip": return _grip(rate)
		&"pull": return _pull(rate, variant)
		&"break": return _break(rate, variant)
		&"dig": return _dig(rate, variant)
		&"fell": return _fell(rate, variant)
		&"cut": return _cut(rate, variant)
		&"gather": return _gather(rate, variant)
		&"craft": return _craft(rate)
		&"eat": return _eat(rate)
		&"fire": return _fire(rate)
		&"splash": return _splash(rate)
		&"tree_fall": return _tree_fall(rate)
		&"pickup": return _pickup(rate)
		&"machine_down": return _machine_down(rate)
		&"alert": return _alert(rate)
		&"downed": return _downed(rate)
		&"lamp_on": return _lamp(rate, true)
		&"lamp_off": return _lamp(rate, false)
		&"door": return _door(rate)
		&"thunder": return _thunder(rate, variant, true)
		&"thunder_far": return _thunder(rate, variant, false)
		&"ui_move": return _ui_move(rate)
		&"ui_accept": return _ui_accept(rate)
		&"ui_back": return _ui_back(rate)
		&"ui_refuse": return _ui_refuse(rate)
	push_warning("no sfx %s" % name)
	return Synth.buffer(64)


# ------------------------------------------------------------------ helpers

static func _burst(rate: int, seconds: float, seed_value: int, lo: float, hi: float, t60: float, attack: float = 0.0008) -> PackedFloat32Array:
	var b := Synth.noise(Synth.samples(rate, seconds), seed_value)
	Synth.band(b, rate, lo, hi, false, false)
	Synth.env_perc(b, rate, attack, t60)
	Synth.normalize(b, 1.0)
	return b


## Grains: dense random impulses through a band, under a percussive envelope.
static func _grains(rate: int, seconds: float, seed_value: int, density: float, lo: float, hi: float, attack: float, t60: float) -> PackedFloat32Array:
	var b := Synth.buffer(Synth.samples(rate, seconds))
	Synth.add_impulses(b, rate, density, seed_value, 0.05, 1.0)
	Synth.band(b, rate, lo, hi, false, false)
	Synth.env_perc(b, rate, attack, t60)
	Synth.normalize(b, 1.0)
	return b


static func _modes(rate: int, seconds: float, freqs: Array, amps: Array, t60s: Array) -> PackedFloat32Array:
	return Synth.modes(rate, seconds, PackedFloat32Array(freqs), PackedFloat32Array(amps), PackedFloat32Array(t60s))


## A band-passed noise whose centre follows a bell-shaped glide lo -> peak -> end.
static func _swoosh(rate: int, seconds: float, seed_value: int, lo: float, top: float, end: float, q: float, peak_at: float = 0.4) -> PackedFloat32Array:
	var n := Synth.samples(rate, seconds)
	var b := Synth.noise(n, seed_value)
	var curve := Synth.buffer(n)
	for i in n:
		var u := float(i) / n
		curve[i] = lerpf(lo, top, u / peak_at) if u < peak_at else lerpf(top, end, (u - peak_at) / (1.0 - peak_at))
	Synth.sweep_band(b, rate, curve, q)
	for i in n:
		var u := float(i) / n
		var e := pow(sin(PI * pow(u, 0.7)), 2.0) if u < 1.0 else 0.0
		b[i] *= e
	Synth.normalize(b, 1.0)
	return b


static func _out(rate: int, seconds: float) -> PackedFloat32Array:
	return Synth.buffer(Synth.samples(rate, seconds))


static func _at(rate: int, seconds: float) -> int:
	return Synth.samples(rate, seconds)


# ---------------------------------------------------------------- footfalls

## Heel then toe, 40-70 ms apart; the variant moves seeds, timing and weight
## so four takes never sound like one sample repeated.
static func _step(family: StringName, v: int, rate: int) -> PackedFloat32Array:
	var r := Rng.make(8000 + FAMILIES.find(family) * 16, v)
	var gap := r.randf_range(0.04, 0.07)
	var toe_gain := r.randf_range(0.45, 0.7)
	var seed_value := 8100 + FAMILIES.find(family) * 16 + v
	var out := _out(rate, 0.32)
	var heel := _foot(family, rate, seed_value, r, true)
	var toe := _foot(family, rate, seed_value + 7, r, false)
	Synth.add(out, heel, 0)
	Synth.add(out, toe, _at(rate, gap), toe_gain)
	return out


static func _foot(family: StringName, rate: int, seed_value: int, r: RandomNumberGenerator, heel: bool) -> PackedFloat32Array:
	var b := _out(rate, 0.26)
	var weight := 1.0 if heel else 0.6
	match family:
		&"sand":
			Synth.add(b, _grains(rate, 0.14, seed_value, 1400.0, 350.0, 3000.0, 0.006, 0.1), 0, 0.9)
			Synth.add(b, _burst(rate, 0.08, seed_value + 1, 150.0, 400.0, 0.05, 0.004), 0, 0.5 * weight)
		&"grass":
			Synth.add(b, _burst(rate, 0.14, seed_value, 1800.0, 7000.0, 0.09, 0.006), 0, 0.7)
			Synth.add(b, _burst(rate, 0.08, seed_value + 1, 140.0, 420.0, 0.05, 0.003), 0, 0.6 * weight)
			Synth.add(b, _grains(rate, 0.1, seed_value + 2, 220.0, 3000.0, 8000.0, 0.002, 0.07), 0, 0.35)
		&"heath":
			Synth.add(b, _grains(rate, 0.18, seed_value, 420.0, 1500.0, 6000.0, 0.004, 0.13), 0, 0.9)
			Synth.add(b, _burst(rate, 0.08, seed_value + 1, 140.0, 420.0, 0.05, 0.003), 0, 0.55 * weight)
		&"mud":
			var n := _at(rate, 0.18)
			var sq := Synth.noise(n, seed_value)
			Synth.sweep_band(sq, rate, Synth.glide(n, 950.0 if heel else 700.0, 300.0), 3.0)
			Synth.env_perc(sq, rate, 0.01, 0.16)
			Synth.normalize(sq, 1.0)
			Synth.add(b, sq, 0, 0.9)
			var pop := _out(rate, 0.03)
			Synth.add_chirp(pop, rate, 380.0, 900.0, 1.0)
			Synth.env_perc(pop, rate, 0.002, 0.025)
			Synth.add(b, pop, _at(rate, 0.13), 0.3)
		&"needles":
			Synth.add(b, _grains(rate, 0.12, seed_value, 600.0, 600.0, 3500.0, 0.005, 0.09), 0, 0.7)
			Synth.add(b, _burst(rate, 0.08, seed_value + 1, 140.0, 380.0, 0.05, 0.004), 0, 0.6 * weight)
		&"snow":
			var g := _grains(rate, 0.2, seed_value, 900.0, 900.0, 5000.0, 0.04, 0.16)
			Synth.add(b, g, 0, 0.9)
			var n := _at(rate, 0.12)
			var squeak := Synth.noise(n, seed_value + 3)
			Synth.sweep_band(squeak, rate, Synth.glide(n, 1100.0 + r.randf_range(0.0, 200.0), 1450.0), 14.0)
			Synth.env_perc(squeak, rate, 0.03, 0.1)
			Synth.normalize(squeak, 1.0)
			Synth.add(b, squeak, _at(rate, 0.02), 0.25)
		&"ice":
			# A glassy tick that rings, and the boot sliding a hair on the sheen: the
			# ring and the slide carry the weight, so the tick needs no spike.
			Synth.add(b, _burst(rate, 0.02, seed_value, 2000.0, 9000.0, 0.012, 0.0012), 0, 0.45)
			Synth.add(b, _modes(rate, 0.2, [1900.0 + r.randf_range(-80.0, 80.0), 3300.0, 5100.0], [0.5, 0.3, 0.15], [0.14, 0.09, 0.05]), 0, 0.6 * weight)
			Synth.add(b, _burst(rate, 0.1, seed_value + 3, 1400.0, 6000.0, 0.08, 0.02), _at(rate, 0.005), 0.25)
		&"stone":
			# A hard tock with a body behind it (the slab answers) and grit under
			# the sole, rather than a bare click.
			Synth.add(b, _burst(rate, 0.03, seed_value, 900.0, 6000.0, 0.022, 0.0012), 0, 0.5)
			Synth.add(b, _modes(rate, 0.16, [420.0 + r.randf_range(-30.0, 30.0), 950.0, 2100.0], [0.5, 0.3, 0.12], [0.1, 0.075, 0.04]), 0, 0.7 * weight)
			Synth.add(b, _burst(rate, 0.08, seed_value + 3, 500.0, 3200.0, 0.06, 0.004), 0, 0.3)
			Synth.add(b, _grains(rate, 0.1, seed_value + 2, 500.0, 1500.0, 6000.0, 0.002, 0.07), 0, 0.2)
		&"gravel":
			Synth.add(b, _grains(rate, 0.2, seed_value, 1600.0, 800.0, 7000.0, 0.005, 0.15), 0, 1.0)
			Synth.add(b, _burst(rate, 0.06, seed_value + 1, 150.0, 450.0, 0.04, 0.003), 0, 0.4 * weight)
		&"shingle":
			for k in r.randi_range(8, 14):
				var f := r.randf_range(2200.0, 3800.0)
				var clack := _modes(rate, 0.04, [f, f * 2.31], [0.5, 0.25], [0.02, 0.012])
				Synth.add(b, clack, _at(rate, r.randf_range(0.0, 0.14)), r.randf_range(0.2, 0.8))
			Synth.add(b, _burst(rate, 0.06, seed_value + 1, 150.0, 450.0, 0.04, 0.003), 0, 0.4 * weight)
		&"ash":
			Synth.add(b, _grains(rate, 0.16, seed_value, 800.0, 600.0, 5000.0, 0.008, 0.12), 0, 0.7)
			Synth.add(b, _burst(rate, 0.12, seed_value + 1, 300.0, 1500.0, 0.09, 0.01), 0, 0.35)
		&"clinker":
			# Burnt slag crunching under the sole (a dense crunch and the foot's
			# weight), with glassy ticks of it breaking on top.
			Synth.add(b, _grains(rate, 0.18, seed_value + 4, 2600.0, 800.0, 4500.0, 0.006, 0.13), 0, 0.55)
			Synth.add(b, _burst(rate, 0.08, seed_value + 1, 150.0, 480.0, 0.05, 0.004), 0, 0.4 * weight)
			Synth.add(b, _grains(rate, 0.16, seed_value, 600.0, 2000.0, 9000.0, 0.003, 0.12), 0, 0.5)
			for k in 3:
				var f := r.randf_range(3000.0, 4800.0)
				Synth.add(b, _modes(rate, 0.05, [f, f * 1.52], [0.4, 0.2], [0.03, 0.02]), _at(rate, r.randf_range(0.0, 0.08)), 0.35)
		&"dirt":
			Synth.add(b, _burst(rate, 0.08, seed_value, 150.0, 900.0, 0.05, 0.002), 0, 0.8 * weight)
			Synth.add(b, _grains(rate, 0.1, seed_value + 1, 320.0, 1500.0, 6000.0, 0.003, 0.06), 0, 0.4)
		&"wood":
			Synth.add(b, _modes(rate, 0.14, [180.0 + r.randf_range(-10.0, 10.0), 420.0, 760.0], [0.5, 0.35, 0.18], [0.08, 0.06, 0.04]), 0, 0.9 * weight)
			Synth.add(b, _burst(rate, 0.01, seed_value, 1500.0, 6000.0, 0.006, 0.0005), 0, 0.3)
		&"water":
			var n := _at(rate, 0.24)
			var slosh := Synth.noise(n, seed_value)
			Synth.sweep_band(slosh, rate, Synth.glide(n, 600.0, 2400.0), 1.4)
			Synth.env_perc(slosh, rate, 0.015, 0.2)
			Synth.normalize(slosh, 1.0)
			Synth.add(b, slosh, 0, 0.9)
			for k in 3:
				var bub := _out(rate, 0.03)
				var f := r.randf_range(500.0, 1300.0)
				Synth.add_chirp(bub, rate, f, f * 1.6, 1.0)
				Synth.env_perc(bub, rate, 0.002, 0.03)
				Synth.add(b, bub, _at(rate, r.randf_range(0.04, 0.18)), 0.2)
	return b


# ------------------------------------------------------------------- fight

static func _swing(rate: int, v: int) -> PackedFloat32Array:
	var out := _swoosh(rate, 0.26, 8301 + v, 350.0, 1500.0, 650.0, 1.4, 0.45)
	Synth.add(out, _grains(rate, 0.12, 8302 + v, 300.0, 2000.0, 6000.0, 0.004, 0.1), 0, 0.2)
	return out


## The miss: airier and higher than a swing, with a longer tail into nothing.
static func _whiff(rate: int, v: int) -> PackedFloat32Array:
	return _swoosh(rate, 0.36, 8311 + v, 900.0, 3200.0, 1300.0, 2.2, 0.35)


static func _hit_flesh(rate: int, v: int) -> PackedFloat32Array:
	var out := _out(rate, 0.3)
	var body := _out(rate, 0.25)
	Synth.add_chirp(body, rate, 280.0 + v * 15.0, 140.0, 1.0)
	Synth.env_perc(body, rate, 0.002, 0.14)
	Synth.add(out, body, 0)
	Synth.add(out, _burst(rate, 0.05, 8321 + v, 900.0, 4000.0, 0.03, 0.0005), 0, 0.55)
	Synth.add(out, _grains(rate, 0.08, 8322 + v, 800.0, 400.0, 2500.0, 0.002, 0.05), 0, 0.3)
	Synth.saturate(out, 1.8)
	return out


## A flat ring: the plate takes the blow and gives nothing back. Damped
## inharmonic plate modes (1 : 2.76 : 5.40 : 8.93), a clank, a dull thump.
static func _hit_plate(rate: int, v: int) -> PackedFloat32Array:
	var f := 410.0 + v * 23.0
	var out := _modes(rate, 0.6, [f, f * 2.76, f * 5.40, f * 8.93], [0.5, 0.36, 0.2, 0.1], [0.34, 0.24, 0.16, 0.1])
	Synth.add(out, _burst(rate, 0.04, 8331 + v, 1500.0, 8000.0, 0.02, 0.0004), 0, 0.5)
	var thump := _out(rate, 0.12)
	Synth.add_chirp(thump, rate, 240.0, 180.0, 1.0)
	Synth.env_perc(thump, rate, 0.001, 0.08)
	Synth.add(out, thump, 0, 0.45)
	# Flat, not bright: take the shimmer off the top.
	Synth.peak_eq(out, rate, 3500.0, 0.7, -6.0)
	return out


static func _dodge(rate: int, v: int) -> PackedFloat32Array:
	var out := _out(rate, 0.32)
	Synth.add(out, _swoosh(rate, 0.18, 8341 + v, 500.0, 1300.0, 800.0, 1.0, 0.5), 0)
	Synth.add(out, _grains(rate, 0.14, 8342 + v, 900.0, 800.0, 5000.0, 0.004, 0.1), _at(rate, 0.12), 0.6)
	return out


## Taken hold of: five exact ratchet clicks, a servo rising, the clamp shutting.
static func _grip(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.75)
	var click := _modes(rate, 0.03, [1800.0, 3500.0], [0.5, 0.3], [0.015, 0.01])
	for k in 5:
		Synth.add(out, click, _at(rate, k * 0.045), 0.5)
	var whine := _out(rate, 0.26)
	Synth.add_chirp(whine, rate, 600.0, 900.0, 1.0)
	Synth.fade(whine, rate, 0.03, 0.05)
	Synth.add(out, whine, _at(rate, 0.05), 0.12)
	Synth.add(out, _modes(rate, 0.4, [220.0, 540.0, 1200.0], [0.6, 0.35, 0.15], [0.15, 0.1, 0.06]), _at(rate, 0.3), 0.9)
	Synth.add(out, _burst(rate, 0.02, 8351, 1200.0, 6000.0, 0.012), _at(rate, 0.3), 0.4)
	return out


## Pulling against a grip: a strained creak and a clack of give.
static func _pull(rate: int, v: int) -> PackedFloat32Array:
	var n := _at(rate, 0.5)
	var src := Synth.buffer(n)
	var r := Rng.make(8361, v)
	var ph := 0.0
	for i in n:
		ph += lerpf(60.0, 95.0, float(i) / n) / rate
		if ph >= 1.0:
			ph -= 1.0
			src[i] = r.randf_range(0.5, 1.0)
	var creak := Synth.formants(src, rate, PackedFloat32Array([500.0, 1300.0]), PackedFloat32Array([6.0, 8.0]), PackedFloat32Array([1.0, 0.5]))
	for i in n:
		creak[i] *= sin(PI * float(i) / n)
	Synth.normalize(creak, 1.0)
	var out := _out(rate, 0.55)
	Synth.add(out, creak, 0, 0.7)
	Synth.add(out, _modes(rate, 0.08, [1500.0, 2900.0], [0.5, 0.25], [0.03, 0.02]), _at(rate, 0.36), 0.6)
	return out


# ------------------------------------------------------------------ taking

static func _break(rate: int, v: int) -> PackedFloat32Array:
	var out := _out(rate, 0.7)
	Synth.add(out, _burst(rate, 0.06, 8401 + v, 1000.0, 9000.0, 0.03, 0.0004), 0, 0.8)
	Synth.add(out, _modes(rate, 0.25, [380.0 + v * 20.0, 870.0, 1900.0], [0.6, 0.35, 0.15], [0.1, 0.07, 0.04]), 0, 0.7)
	var r := Rng.make(8402, v)
	for k in 12:
		var t := r.randf_range(0.05, 0.45)
		var f := r.randf_range(1500.0, 4200.0)
		Synth.add(out, _modes(rate, 0.04, [f, f * 1.9], [0.5, 0.2], [0.02, 0.012]), _at(rate, t), 0.4 * (1.0 - t))
	return out


static func _dig(rate: int, v: int) -> PackedFloat32Array:
	var out := _out(rate, 0.5)
	Synth.add(out, _swoosh(rate, 0.12, 8411 + v, 2000.0, 1400.0, 800.0, 2.0, 0.2), 0, 0.5)
	Synth.add(out, _burst(rate, 0.12, 8412 + v, 150.0, 600.0, 0.08, 0.003), _at(rate, 0.05), 0.8)
	Synth.add(out, _grains(rate, 0.3, 8413 + v, 500.0, 500.0, 3000.0, 0.01, 0.22), _at(rate, 0.08), 0.5)
	return out


## A blade into timber: the thock, the bite, a splinter or two.
static func _fell(rate: int, v: int) -> PackedFloat32Array:
	var out := _out(rate, 0.5)
	Synth.add(out, _modes(rate, 0.3, [310.0 + v * 18.0, 720.0, 1350.0], [0.6, 0.35, 0.18], [0.12, 0.08, 0.05]), 0, 0.9)
	Synth.add(out, _burst(rate, 0.02, 8421 + v, 2000.0, 7000.0, 0.01, 0.0004), 0, 0.5)
	Synth.add(out, _grains(rate, 0.15, 8422 + v, 160.0, 1500.0, 5000.0, 0.01, 0.12), _at(rate, 0.03), 0.3)
	return out


static func _cut(rate: int, v: int) -> PackedFloat32Array:
	var out := _out(rate, 0.32)
	Synth.add(out, _swoosh(rate, 0.09, 8431 + v, 2500.0, 3300.0, 3300.0, 3.0, 0.5), 0, 0.6)
	Synth.add(out, _grains(rate, 0.22, 8432 + v, 900.0, 1500.0, 6000.0, 0.03, 0.18), _at(rate, 0.04), 0.7)
	return out


static func _gather(rate: int, v: int) -> PackedFloat32Array:
	var out := _out(rate, 0.5)
	var rustle := _grains(rate, 0.4, 8441 + v, 500.0, 1000.0, 6000.0, 0.12, 0.35)
	Synth.add(out, rustle, 0, 0.6)
	var r := Rng.make(8442, v)
	for k in 3:
		var f := r.randf_range(2200.0, 2800.0)
		Synth.add(out, _modes(rate, 0.04, [f, f * 2.2], [0.5, 0.25], [0.02, 0.012]), _at(rate, 0.12 + k * r.randf_range(0.06, 0.1)), 0.5)
	return out


## Three taps on salvage at the bench, then the file across it.
static func _craft(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 1.1)
	var tink := _modes(rate, 0.4, [1250.0, 3450.0, 6750.0], [0.5, 0.3, 0.12], [0.25, 0.12, 0.06])
	for t: float in [0.0, 0.28, 0.52]:
		Synth.add(out, tink, _at(rate, t), 0.8 if t > 0.0 else 1.0)
		Synth.add(out, _burst(rate, 0.02, 8451 + roundi(t * 100.0), 800.0, 4000.0, 0.01), _at(rate, t), 0.3)
	var scrape := Synth.noise(_at(rate, 0.3), 8452)
	Synth.band(scrape, rate, 2500.0, 7000.0, false, false)
	Synth.tremolo(scrape, rate, 38.0, 0.6)
	Synth.env_adsr(scrape, rate, 0.04, 0.05, 0.8, 0.22, 0.06)
	Synth.normalize(scrape, 1.0)
	Synth.add(out, scrape, _at(rate, 0.74), 0.35)
	return out


static func _eat(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.9)
	for k in 3:
		var c := _grains(rate, 0.14, 8461 + k, 700.0, 400.0, 2500.0, 0.01, 0.1)
		Synth.lowpass(c, rate, 1800.0)
		Synth.add(out, c, _at(rate, k * 0.29), 0.9 - k * 0.15)
	return out


## Striking a light: flint across steel, the catch, then crackle.
static func _fire(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 1.7)
	Synth.add(out, _swoosh(rate, 0.09, 8471, 2500.0, 6000.0, 4000.0, 2.0, 0.3), 0, 0.5)
	var r := Rng.make(8472)
	for k in 6:
		Synth.add(out, _burst(rate, 0.008, 8473 + k, 3000.0, 10000.0, 0.005, 0.0003), _at(rate, r.randf_range(0.02, 0.1)), r.randf_range(0.2, 0.5))
	var whump := Synth.noise(_at(rate, 0.5), 8480)
	Synth.band(whump, rate, 150.0, 900.0, false, false)
	for i in whump.size():
		var u := float(i) / whump.size()
		whump[i] *= pow(sin(PI * pow(u, 0.5)), 2.0)
	Synth.normalize(whump, 1.0)
	Synth.add(out, whump, _at(rate, 0.22), 0.7)
	for k in 22:
		var t := r.randf_range(0.4, 1.6)
		Synth.add(out, _burst(rate, 0.006, 8490 + k, 1500.0, 7000.0, 0.004, 0.0003), _at(rate, t), r.randf_range(0.1, 0.5) * (1.7 - t))
	return out


static func _splash(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.8)
	Synth.add(out, _burst(rate, 0.4, 8501, 300.0, 5000.0, 0.3, 0.002), 0, 0.9)
	var r := Rng.make(8502)
	for k in 15:
		var bub := _out(rate, 0.04)
		var f := r.randf_range(400.0, 1400.0)
		Synth.add_chirp(bub, rate, f, f * 1.7, 1.0)
		Synth.env_perc(bub, rate, 0.002, 0.035)
		Synth.add(out, bub, _at(rate, r.randf_range(0.05, 0.5)), r.randf_range(0.1, 0.3))
	for k in 8:
		var f := r.randf_range(2000.0, 4000.0)
		var drop := _out(rate, 0.05)
		Synth.add_chirp(drop, rate, f, f * 1.4, 1.0)
		Synth.env_perc(drop, rate, 0.001, 0.04)
		Synth.add(out, drop, _at(rate, r.randf_range(0.2, 0.7)), 0.12)
	return out


## Groan, give, and the crown coming down through its neighbours.
static func _tree_fall(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 2.6)
	var n := _at(rate, 1.0)
	var src := Synth.buffer(n)
	var r := Rng.make(8511)
	var ph := 0.0
	for i in n:
		ph += lerpf(30.0, 70.0, pow(float(i) / n, 2.0)) / rate
		if ph >= 1.0:
			ph -= 1.0
			src[i] = r.randf_range(0.5, 1.0)
	var groan := Synth.formants(src, rate, PackedFloat32Array([380.0, 900.0, 1700.0]), PackedFloat32Array([7.0, 9.0, 10.0]), PackedFloat32Array([1.0, 0.6, 0.3]))
	Synth.normalize(groan, 1.0)
	Synth.add(out, groan, 0, 0.6)
	Synth.add(out, _grains(rate, 0.9, 8512, 700.0, 1000.0, 6000.0, 0.2, 0.7), _at(rate, 1.0), 0.8)
	Synth.add(out, _burst(rate, 0.8, 8513, 130.0, 700.0, 0.6, 0.004), _at(rate, 1.55), 1.0)
	return out


static func _pickup(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.25)
	Synth.add(out, _grains(rate, 0.12, 8521, 600.0, 1500.0, 6000.0, 0.01, 0.1), 0, 0.5)
	Synth.add(out, _modes(rate, 0.06, [900.0, 2100.0], [0.5, 0.25], [0.04, 0.02]), _at(rate, 0.05), 0.6)
	return out


# ---------------------------------------------------------------- machines

## The light goes out: a relay drops, the tone it was holding sags an octave and stops.
static func _machine_down(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 1.3)
	Synth.add(out, _modes(rate, 0.3, [240.0, 610.0, 1350.0], [0.6, 0.35, 0.15], [0.14, 0.1, 0.06]), 0, 0.8)
	Synth.add(out, _burst(rate, 0.02, 8601, 1500.0, 7000.0, 0.01), 0, 0.4)
	var n := _at(rate, 0.9)
	var sag := Synth.buffer(n)
	Synth.add_chirp(sag, rate, 412.5, 206.25, 1.0)
	var h := Synth.buffer(n)
	Synth.add_chirp(h, rate, 825.0, 412.5, 0.5)
	Synth.add(sag, h, 0)
	for i in n:
		var u := float(i) / n
		sag[i] *= (1.0 - u) * (1.0 - u)
	Synth.add(out, sag, _at(rate, 0.05), 0.35)
	return out


## Registered: two exact glassy tones a fourth apart, and the optic's click.
static func _alert(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.45)
	Synth.add(out, _modes(rate, 0.2, [1375.0, 2750.0], [0.5, 0.15], [0.16, 0.08]), 0, 0.7)
	Synth.add(out, _modes(rate, 0.3, [1833.33, 3666.67], [0.5, 0.15], [0.22, 0.1]), _at(rate, 0.11), 0.7)
	Synth.add(out, _burst(rate, 0.006, 8611, 3000.0, 10000.0, 0.004), 0, 0.3)
	return out


static func _downed(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.8)
	var body := _out(rate, 0.35)
	Synth.add_chirp(body, rate, 230.0, 130.0, 1.0)
	Synth.env_perc(body, rate, 0.003, 0.25)
	Synth.add(out, body, 0)
	Synth.add(out, _grains(rate, 0.4, 8621, 1200.0, 700.0, 5000.0, 0.005, 0.3), 0, 0.5)
	Synth.add(out, _burst(rate, 0.2, 8622, 1500.0, 5000.0, 0.15, 0.01), _at(rate, 0.05), 0.3)
	Synth.saturate(out, 1.5)
	return out


static func _lamp(rate: int, on: bool) -> PackedFloat32Array:
	var out := _out(rate, 0.6 if on else 0.35)
	Synth.add(out, _modes(rate, 0.08, [1100.0, 2600.0], [0.5, 0.25], [0.04, 0.02]), 0, 0.6)
	var puff := Synth.noise(_at(rate, 0.35 if on else 0.15), 8631 if on else 8632)
	Synth.band(puff, rate, 300.0 if on else 800.0, 2500.0, false, false)
	for i in puff.size():
		var u := float(i) / puff.size()
		puff[i] *= pow(sin(PI * pow(u, 0.4 if on else 0.2)), 2.0)
	Synth.normalize(puff, 1.0)
	Synth.add(out, puff, _at(rate, 0.08), 0.5)
	return out


static func _door(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.9)
	var n := _at(rate, 0.5)
	var src := Synth.buffer(n)
	var r := Rng.make(8641)
	var ph := 0.0
	for i in n:
		ph += lerpf(90.0, 55.0, float(i) / n) / rate
		if ph >= 1.0:
			ph -= 1.0
			src[i] = r.randf_range(0.4, 1.0)
	var creak := Synth.formants(src, rate, PackedFloat32Array([650.0, 1500.0]), PackedFloat32Array([7.0, 9.0]), PackedFloat32Array([1.0, 0.5]))
	for i in n:
		creak[i] *= sin(PI * float(i) / n)
	Synth.normalize(creak, 1.0)
	Synth.add(out, creak, 0, 0.5)
	Synth.add(out, _modes(rate, 0.3, [160.0, 390.0, 820.0], [0.6, 0.35, 0.15], [0.12, 0.08, 0.05]), _at(rate, 0.55), 0.9)
	return out


# ----------------------------------------------------------------- weather

## Near: the crack, then the roll. Far: only the roll, duller.
static func _thunder(rate: int, v: int, near: bool) -> PackedFloat32Array:
	var secs := 5.5 if near else 6.5
	var n := _at(rate, secs)
	var out := Synth.buffer(n)
	var r := Rng.make(8701 + (0 if near else 50), v)
	if near:
		Synth.add(out, _burst(rate, 0.6, 8702 + v, 800.0, 8000.0, 0.35, 0.004), 0, 0.8)
	var roll := Synth.pink(n, 8703 + v)
	# Weight in the 120-400 Hz a laptop can play; the depth is implied, not carried.
	Synth.band(roll, rate, 120.0, 700.0 if near else 420.0, false, true)
	var bursts := Synth.wander(n, 11 + v, 8704 + v, 0.15, 1.0)
	var onset := 0.0 if near else r.randf_range(0.2, 0.6)
	for i in n:
		var u := float(i) / n
		var e := pow(clampf((u - onset * 0.1) * 12.0, 0.0, 1.0), 2.0) * pow(1.0 - u, 1.6)
		roll[i] *= e * pow(bursts[i], 2.0)
	Synth.normalize(roll, 1.0)
	Synth.add(out, roll, 0, 1.0)
	var mid := Synth.noise(n, 8705 + v)
	Synth.band(mid, rate, 300.0, 1500.0 if near else 800.0, false, false)
	for i in n:
		var u := float(i) / n
		mid[i] *= pow(1.0 - u, 3.0) * bursts[i]
	Synth.normalize(mid, 1.0)
	Synth.add(out, mid, 0, 0.45 if near else 0.25)
	return out


# --------------------------------------------------------------- interface

## Moving down the page: a pencil tick on paper over a desk. Dry, short, woody,
## the quietest thing the game makes.
static func _ui_move(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.06)
	Synth.add(out, _burst(rate, 0.012, 8801, 2200.0, 7500.0, 0.006, 0.0002), 0, 0.8)
	Synth.add(out, _modes(rate, 0.04, [1150.0, 2450.0], [0.5, 0.2], [0.014, 0.008]), 0, 0.45)
	return out


## Up a fifth on a warm pluck.
static func _ui_accept(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.45)
	Synth.add(out, Synth.pluck(rate, 659.26, 0.35, 8811, 0.45, 0.35), 0, 0.8)
	Synth.add(out, Synth.pluck(rate, 987.77, 0.38, 8812, 0.45, 0.35), _at(rate, 0.07), 0.8)
	return out


## Down a fourth, darker, no louder.
static func _ui_back(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.4)
	Synth.add(out, Synth.pluck(rate, 440.0, 0.3, 8821, 0.15, 0.25), 0, 0.8)
	Synth.add(out, Synth.pluck(rate, 329.63, 0.34, 8822, 0.12, 0.25), _at(rate, 0.06), 0.8)
	return out


## Two identical dull ticks: not now.
static func _ui_refuse(rate: int) -> PackedFloat32Array:
	var out := _out(rate, 0.2)
	var tick := _modes(rate, 0.06, [520.0, 1210.0], [0.5, 0.2], [0.04, 0.02])
	Synth.add(out, tick, 0)
	Synth.add(out, tick, _at(rate, 0.09))
	return out
