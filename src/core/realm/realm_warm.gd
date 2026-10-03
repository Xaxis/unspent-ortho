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
##   the world's own list of places, FIRST and whole: the shafts' rows
##                         (Portals.record), the landmarks' (Landmarks.record) and
##                         the depots' (Works.record), in the order 20_realms,
##                         22_landmarks and 34_works write them at their setup,
##                         where they now find them written. A keeper stationed
##                         at a landmark dens there only once its row is, and
##                         every answer keyed on the list's length (Works.sites,
##                         Sentinels' lairs) is worked out again each time it grows
## Every one of them is pure over the world and worker-safe
## (tests/core/test_worker_types): no node, no RID, no texture.

## The two systems' builders are LOADED WHEN ASKED FOR, by path, not preloaded:
## realm_worlds.gd reaches this file, and a core file preloading system scripts
## that reach back into the realms closes a cycle the engine never frees, so a
## game made by the loading page left 8-22 more objects behind at exit
## (tests/export/test_exit.gd). By then the systems are loaded; this is a lookup.
const _LIGHTS := "res://src/systems/15_lights.gd"
const _COLOSSI := "res://src/systems/19_colossi.gd"


static func prepare(w: WorldData) -> void:
	if w == null:
		return
	var ms := {}
	var t := Time.get_ticks_usec()
	Portals.record(w)
	Landmarks.record(w)
	Works.record(w)
	t = _took(ms, "rows", t)
	SkyGround.prepare(w)
	t = _took(ms, "sky_ground", t)
	SkyWear.prepare(w)
	t = _took(ms, "sky_wear", t)
	(load(_LIGHTS) as GDScript).call(&"prepare_world", w)
	t = _took(ms, "lights", t)
	(load(_COLOSSI) as GDScript).call(&"prepare_world", w)
	t = _took(ms, "treads", t)
	WorksMap.prepare(w)
	_took(ms, "works", t)
	# Read off a web run's console: this is the raise's time a title has to hide.
	print("realm warm %s: %s ms" % [w.realm, ms])


static func _took(ms: Dictionary, part: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	ms[part] = roundi((now - since) / 1000.0)
	return now
