extends TestCase
## The six M1 countries became six landscape files. This pins the proof: a world
## generated from only those six is the world M1 generated, tile for tile and
## prop for prop.
##
## The digests were taken on main at 2faee61, before the registry existed. If a
## change here moves one of them, the six landscapes are no longer what they
## were and the canon frames will have moved with them: look at the pictures
## before accepting a new number.
##
## RE-ACCEPTED ONCE, at `WorldStamp.GEN` 2, and here is the evidence, because the
## instruction above is the whole value of this file. `GenCountries` now marks a
## half-cell whose nearest border pair does not name its own country as a seam —
## the case its seam detector skipped, and the case where `country2` was left
## holding a stale value, which is what flipped. Three of the five seeds moved
## and only in `blend`, `ground` and `props`: the blend band loses 0.08% of its
## tiles and 0.2% of its mass over the three worldgen seeds, `GenSurface` picks a
## tile's recipe by blend, and `GenScatter` follows the ground, so a handful of
## props move in the ecotones and nowhere else. `country`, `country2` and `level`
## are untouched on every seed.
##
## The pictures were looked at: `shots/seam/` holds coast-moss,
## pinewood-snowfield and bonelands-burning on seed 7, shot before and after.
## The washes, the pools, the mud and the ash all fall in the same places; a few
## scattered sprigs and timbers move. Re-shoot those three before accepting any
## further number here.
##
## RE-ACCEPTED A SECOND TIME, for the THRESHOLD site (`GenScatter._black_site`),
## and this one needed no pictures because the evidence is stronger than a
## picture. **Only the `props` digest moved, on all five seeds; `country`,
## `country2`, `ground`, `level` and `blend` are byte-identical.** The site is
## five props laid in open water at the very END of the props stage, after the
## scatter, and they are the LAST FIVE ids in every world -- measured, not
## assumed: seed 1 ends 3193 props with the highest id that is not the site's at
## 3187, seed 7 3160 and 3154, seed 90210 3244 and 3238. Nothing that already
## stood anywhere moved by a tile, because nothing that already stood anywhere
## was asked to.
##
## That is the shape of a safe re-acceptance here, and it is worth saying so the
## next one can be judged the same way: five digests still equal and one that
## grew by exactly what was appended. A change that moved `ground` or `blend`
## would not be this, and would want the seam frames again.
##
## RE-ACCEPTED A THIRD TIME, and this one DID move `ground` -- on seeds 1 and 3,
## with `country`, `country2`, `level` and `blend` still equal on all five. So the
## rule above was followed rather than waived: the picture was looked at
## (`shots/intake.png`, seed 1 at 123,294, the run inland of the coast intake).
##
## The cause is two works changes, both deliberate. The coast's intake now runs
## its pipe inland, because an intake that stops at its own fence is a machine
## doing half a job and it left the coast's keeper feeding on ONE prop
## (`tests/sentinel/test_world.gd` holds that now). And a cistern asks for 14
## tiles of room instead of 26, because at an installation's spacing it lost every
## draw against the bonelands' drill rigs and a whole world came out with nought
## to two water tanks in fourteen thousand tiles of their own landscape. Works
## stamp the ground they stand on, so both move `ground` where they moved.
##
## What the frame shows: steel pipe on trestles running inland across coast turf,
## the sea wall behind it, the land either side of it unchanged in character. It
## reads as infrastructure that was always meant to be there, which is the test
## this file actually cares about.
##
## RE-ACCEPTED A FOURTH TIME, for the scale work of docs/WORLD.md §7b: a region is
## floored against the world instead of against a body, and a landscape's sites
## are counted per REGION instead of per type across the whole island. `ground`
## and `props` moved on all five seeds; `country`, `country2`, `level` and `blend`
## are equal on all five, so the LAND is the same land and what stands on it is
## what changed — which is exactly what those two changes are.
##
## Looked at rather than argued: seed 1 at the spawn village, wide. Coast turf, a
## shingle beach, a standing stone on the sand, a collapsed hull, pines at the
## edge. The world reads RICHER and not busier, which was the thing worth checking
## — one site per 3,326 tiles against one per 9,350 is two and a half times as
## much to walk into, and the failure mode of that change is clutter.
##
## Seed 42's `props` moved once more after that, and only seed 42's: a stone must
## stand in its own circle's landscape. A circle's centre is held to its region,
## but its stones are laid three or four tiles out, which is far enough to cross a
## border once there are several circles in a place instead of one or two on the
## whole island. It read as "standing stone on the Coast" — a landscape holding
## somebody else's monument.
const SIX: Array[StringName] = [&"coast", &"moss", &"pinewood", &"snowfield", &"bonelands", &"burning"]
const SIZE := 256

## seed -> "country country2 ground level blend props", md5 prefixes.
const M1 := {
	1: "d1335897 8b46ae9f 1ee81549 7b99a6e3 ce54a897 007c247b",
	3: "d7a39e67 dba8792b c2f270dc 090631fd a8be1d60 eeca157d",
	7: "aa526bae 4ff8f6b7 93243ecb 7fb78385 be4cc1f0 b63ba6b5",
	42: "325e4566 8d16e00c 094afc29 b88a5d6e 8cce8022 46f5c69a",
	90210: "5b1e7401 4d0ad4be ce1caab3 bf578b00 ed81f772 f822ec07",
}


## Muting the registry is a change to GLOBAL state that every later test in the
## shard would silently inherit. Tie the restore to the scope instead of to the
## last line of a happy path: however this test leaves — a failed assertion, an
## error, an early return — the guard goes out of scope and the whole registry
## comes back.
class Muted extends RefCounted:
	func _init(ids: Array[StringName]) -> void:
		BiomeRegistry.mute_to(ids)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			BiomeRegistry.mute_to([])


func test_a_world_of_the_six_is_the_world_m1_made() -> void:
	var guard := Muted.new(SIX)
	eq(BiomeRegistry.count(), 7, "the sea and the six")
	for s: int in M1:
		var w := WorldGen.generate(s, SIZE)
		eq(digest(w), M1[s], "seed %d" % s)
	guard = null
	gt(float(BiomeRegistry.count()), 7.0, "the whole registry is back")


func test_the_registry_is_whole_for_every_other_test() -> void:
	# If a parity test ever leaves the registry muted, this is the line that
	# says so instead of nine other tests quietly meaning something else.
	check(BiomeRegistry.get_def(&"salt_flats") != null, "the registry is not muted")


static func digest(w: WorldData) -> String:
	var parts: PackedStringArray = []
	for part: PackedByteArray in [w.country, w.country2, w.ground, w.level.to_byte_array(), w.blend.to_byte_array()]:
		parts.append(_md5(part))
	var props := PackedFloat32Array()
	for p in w.props:
		props.append(p.kind)
		props.append(p.pos.x)
		props.append(p.pos.y)
	parts.append(_md5(props.to_byte_array()))
	return " ".join(parts)


static func _md5(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, 8)
