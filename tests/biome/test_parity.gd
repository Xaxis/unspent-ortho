extends TestCase
## The six M1 countries became six landscape files, and this pins their world:
## five whole-world digests that nothing may move by accident. If a change here
## moves one of them, the six landscapes are no longer what they were and the
## canon frames will have moved with them: look at the pictures before accepting
## a new number.
##
## **It was a parity proof and it is not one any more, and the fifth
## re-acceptance below is where that happened.** The digests were taken on main
## at 2faee61, before the registry existed, and for four re-acceptances the claim
## held: a world of the six was the world M1 generated, tile for tile. Giving the
## six relief at walking scale ended that deliberately, and nothing can restore
## it, because M1's coast had no shape a body could walk over. The name of the
## test below says what it checks NOW. Do not write the old claim back into it:
## a file whose header promises more than it delivers is worse than one that
## promises less, and the whole value of this file is that its evidence is
## believed.
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
## RE-ACCEPTED A FIFTH TIME, for the scale wave. `props` moved on all five and
## `ground` on seed 7 alone; `country`, `country2`, `level` and `blend` are equal
## everywhere, so the land is the same land. The cause is one rule: still water
## must not stand under a building's own footprint. `_free` clears a radius of
## one, which was the whole of a coastal cottage, and a city form stands on 2.4 —
## so a tower could be set down with a bog pool at its door and nothing refused
## it. Refusing those spots moves the buildings that would have taken them, and a
## building stamps the ground it stands on.
##
## Seed 42's `props` moved once more after that, and only seed 42's: a stone must
## stand in its own circle's landscape. A circle's centre is held to its region,
## but its stones are laid three or four tiles out, which is far enough to cross a
## border once there are several circles in a place instead of one or two on the
## whole island. It read as "standing stone on the Coast" — a landscape holding
## somebody else's monument.
## RE-ACCEPTED A SIXTH TIME, for the THRESHOLD site again (`BlackSite`), and
## this is the same safe shape as the second: **only `props` moved, and only on
## four of the five seeds; `country`, `country2`, `ground`, `level` and `blend`
## are byte-identical everywhere.** Measured rather than argued, by dumping every
## prop of all five muted worlds before and after: 16,215 rows, of which 24
## differ, and they are the site's own five on seeds 1, 3, 7 and 90210. Every
## prop COUNT is unchanged (3223, 3220, 3233), so nothing was added or dropped --
## the same five things stand in different water. Seed 42 did not move at all.
##
## Why it moved: `BlackSite` asked for proxies instead of properties. It threw 72
## rays from the spawn and took the first deep tile past `NEAREST` on a ray that
## had not touched land since going wet, which let the site stand on ONE deep
## tile in a shelf of shallows -- and a body that cannot swim could walk within a
## tile of the ladder on all four seeds, which is the opposite of the one thing
## the place has to be. It now asks outright: in the sea, a `MOAT` of deep water
## wider than the deck's own wall, and 15-40 tiles measured to the tile that is
## written down rather than to the ray that found it.
##
## RE-ACCEPTED A SEVENTH TIME, and this one is different in kind from every one
## above it: **all six digests moved on all five seeds.** Nothing is
## byte-identical. That is the largest movement this file can record and it was
## taken deliberately, by df and cb together.
##
## The cause is `near` on the six -- relief at WALKING scale, which `hills` and
## `ridge` cannot give because they ride noise 58 and 92 tiles wide against a
## camera that shows 26.7. It is not a drift: `BiomeDef.relief` is read by
## `GenRelief`, which runs BEFORE `GenCountries.fine`, so moving it moves the
## levels, then the borders, then the water, then the settlements, then every
## prop id. Six digests is what a relief change LOOKS like, and one that moved
## fewer would be the suspicious one.
##
## **Proved to be that and nothing else**, which is the only reason a hit this
## size is safe to take: with `near` set to 0.0 on the six and everything else on
## the branch left standing -- the map rebuild, the black site, `near` on the
## fourteen landscapes added since -- this test PASSES on the previous hashes, all
## five seeds, first try. So the whole movement is the one decision and no part of
## it is something else riding along. **Run that check before accepting any future
## number here that moves more than `props`: zero the thing you believe did it and
## see whether the old hashes come back.**
##
## The pictures were looked at and they are the argument:
##   tools/shot.sh shots/near.png --seed=7 --place=coast --hour=9 --weather=clear:0
## Before, with coast `near` at 0.0, is a flat green plane with props standing on
## it and one terrace edge away in the distance -- no shape at all under the feet.
## After, the player stands on a raised bank with a scarp falling off it and
## terraces winding through the turf. The owner's standing complaint is that the
## landscapes are too flat; this is that answered on the six he spends his first
## hours in.
##
## **So the test was RENAMED rather than annotated.** It was
## `test_a_world_of_the_six_is_the_world_m1_made`, and it is now
## `test_the_six_keep_the_world_they_have`, because a note explaining that a name
## is no longer true is the weaker half of the job: the next reader believes the
## name, not the note beneath it.
##
## **AND A WARNING PAID FOR TWICE IN THIS FILE, ON ONE DAY.** The sixth
## re-acceptance above was written, the hashes were updated, the test went green,
## and the NOTE never landed -- a scripted insert whose anchor had stopped
## matching after a merge, which reported success because it checked the hashes it
## had changed and not the text it had failed to add. It shipped to main as five
## moved digests with no evidence beside them, in the one file whose whole value
## is that its evidence is written down. If you accept a number here with a
## script, read the note back out of the file afterwards. A green test cannot see
## a comment that is missing.


const SIX: Array[StringName] = [&"coast", &"moss", &"pinewood", &"snowfield", &"bonelands", &"burning"]
const SIZE := 256

## seed -> "country country2 ground level blend props", md5 prefixes.
const M1 := {
	1: "06fa726c d5b85d6c 7e69e93f 673b50ca fe4b52d9 f765de64",
	3: "2202ae28 60362f9d 61bff61d 63df669a 585d921b afccb52f",
	7: "4b153668 3424d5c9 66637139 1ba2d360 72103915 19c2a3fb",
	42: "e5a96b5f bef1bc39 686852f9 bc57666e 824c752b c13aed2c",
	90210: "c3fe6c1a a851aff1 ef15edf1 ff6eb869 b6884aed 8c608290",
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


func test_the_six_keep_the_world_they_have() -> void:
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
