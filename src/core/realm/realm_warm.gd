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
	SkyGround.prepare(w)
	SkyWear.prepare(w)
	_LIGHTS.prepare_world(w)
	_COLOSSI.prepare_world(w)
	WorksMap.prepare(w)
