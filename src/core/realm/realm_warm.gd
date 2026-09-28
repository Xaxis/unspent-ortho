class_name RealmWarm
extends RefCounted
## WHAT A WORLD IS GOT READY WITH BESIDE IT, on the raise's worker
## (RealmWorlds._raise), before any press: the once-per-world work a crossing
## would otherwise do on the press, which is the START a player waits on (S5e,
## the way down a shaft: 9.3 s at 1840, of which this was 6 s). Each piece is
## kept per world object and taken by the system that wants it:
##   SkyGround.prepare     the ground map's image (10_sky, 20_realms)
##   SkyWear.prepare       the wear and growth maps' images (10_sky)
##   15_lights.prepare_world   the index of every light source
##   19_colossi.prepare_world  what every tread's pads flatten, in the world's
##                             own record, before any view draws it
##   WorksMap.prepare      the machines' works cut into the ground (WorldView)
## Every one of them is pure over the world and worker-safe
## (tests/core/test_worker_types): no node, no RID, no texture.

const _LIGHTS := preload("res://src/systems/15_lights.gd")
const _COLOSSI := preload("res://src/systems/19_colossi.gd")


static func prepare(w: WorldData) -> void:
	if w == null:
		return
	var ms := {}
	var t := Time.get_ticks_usec()
	SkyGround.prepare(w)
	t = _took(ms, "sky_ground", t)
	SkyWear.prepare(w)
	t = _took(ms, "sky_wear", t)
	_LIGHTS.prepare_world(w)
	t = _took(ms, "lights", t)
	_COLOSSI.prepare_world(w)
	t = _took(ms, "treads", t)
	WorksMap.prepare(w)
	_took(ms, "works", t)
	# Read off a web run's console: this is the raise's time a title has to hide.
	print("realm warm %s: %s ms" % [w.realm, ms])


static func _took(ms: Dictionary, part: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	ms[part] = roundi((now - since) / 1000.0)
	return now
