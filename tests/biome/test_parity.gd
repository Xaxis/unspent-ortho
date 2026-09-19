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


## RE-ACCEPTED AN EIGHTH TIME, and back to the safe shape: **only `props` moved,
## on all five seeds; the other five digests are byte-identical everywhere.**
##
## The cause is one refusal in `GenWorks._put`. It kept works clear of a CIRCLE of
## the village's recorded `radius`, and a village's own ground is a LOBE -- 7.6
## tiles to 11.4 where the circle stops at 9.5 -- so a barricade, a fence or a
## survey post could stand on ground the village had already claimed, outside the
## number the check asked and inside the place. Both now ask
## `GenSettle.village_core`, which is the shape `_flatten` laid the ground to.
##
## Proved by the check the seventh re-acceptance asks for: with that one line put
## back, this test passes on the previous hashes, all five seeds.
##
## **And a number I got wrong by reasoning instead of measuring, kept here because
## the reasoning was the convincing kind.** A refusal can only ever place FEWER
## props -- it adds a condition and takes nothing away. Four seeds do place fewer
## (12, 4, 22 and 4). Seed 90210 places TWELVE MORE, because a refused spot does
## not drop its prop: it sends the placer round its attempt loop to try somewhere
## else, and somewhere else can succeed where this one would have failed for
## another reason. Count them; do not derive them from the diff.


## RE-ACCEPTED A NINTH TIME, and the safe shape again: **only `props` moved, on
## all five seeds; country, country2, ground, level and blend are byte-identical
## everywhere.** That is what a scatter change must look like, because a scatter
## decides what STANDS on a tile and never what the tile IS.
##
## The cause is the scatter wave: nine landscapes rewritten to place what they
## declare, of which exactly two are in `SIX` -- the moss and the snowfield. The
## other seven are muted out of this world and cannot have moved a byte of it.
##
## Proved the way the seventh asks: with the pre-wave `moss.gd` and
## `snowfield.gd` put back and nothing else on the branch touched, this test
## passes on the PREVIOUS hashes, all five seeds, first try.
##
## **And the counted number went the opposite way to the obvious reasoning, which
## is the second time this file has caught that.** A recipe that grew from one
## prop kind to ten must place more; it places FEWER. Per seed, island total then
## the snowfield's own share:
##
##   1      3310 -> 3191   snowfield 397 -> 305
##   3      3314 -> 3207   snowfield 384 -> 286
##   7      3258 -> 3077   snowfield 423 -> 277
##   42     3409 -> 3243   snowfield 455 -> 315
##   90210  3385 -> 3255   snowfield 363 -> 262
##
## Because the old recipe answered `BiomeScatter.PASS` on every ground but one,
## and PASS hands the tile to `BiomeScatter.shared` -- which is the COAST's
## answer. Naming your own grounds is what costs you that fallback. **The picture
## is the argument and it is not close**:
##   tools/shot.sh shots/cb/snowfield-{before,after}.png --seed=7 --place=snowfield --hour=11 --weather=clear:0
## Before is bare grey driftwood strewn over snow -- a lumber yard in a blizzard.
## After is snow pines carrying snow, a few dead trees, boulders and open ground.
## The 146 props seed 7 lost were the wrong props.
##
## **A third thing fell out of counting, which no amount of reasoning would have
## produced.** Landscapes nobody touched moved too: pinewood, coast, bonelands and
## burning, by -9 to +1. If a tile's recipe followed its COUNTRY those counts
## would be identical. `gen_scatter.gd` picks the recipe off `recipe[i]` -- the
## island a tile's GROUND came from -- so an ecotone tile counted under its
## neighbour's name can be running the moss's recipe. The counts are how you find
## that out; the dispatch is where it is written down.
##
## **This also owed a `WorldStamp.GEN` bump (12 -> 13) and the wave did not pay
## it.** The stamp hashes a scatter recipe by NAME, so it read identical while
## every prop id after the first changed tile moved. Five digests failing here is
## the only instrument that pointed at it, and a re-acceptance that only edited
## the table below would have buried the save bug it was reporting.


## RE-ACCEPTED A TENTH TIME, and this one BROKE THE SAFE SHAPE ON PURPOSE:
## `ground` moved as well as `props`, on three of the five seeds, and seeds 3 and
## 90210 did not move at all. `country`, `country2`, `level` and `blend` are
## byte-identical everywhere, so the LAND is the same land.
##
## The cause is the region floor: a place is now floored against the CONTINENT it
## lies on rather than against the square, because the world stopped being one
## island and became five (`gen_countries.gd` carries the measurement). At the
## shipped size a quarter of the world belonged to no region and two landscapes
## had no chapter anywhere on the island.
##
## **I WAS TOLD TO EXPECT `ground` NOT TO MOVE, AND IT DID, SO I DID NOT ACCEPT
## UNTIL I COULD SAY WHY.** The author's reasoning was that regions are computed
## after the terrain is final and nothing writes back to it. That is true of the
## TERRAIN and false of the GROUND: works stamp the ground they stand on, and a
## works site is chosen per REGION. This file's own third re-acceptance says it in
## one line -- "Works stamp the ground they stand on, so both move `ground` where
## they moved" -- and nobody, including me, remembered it.
##
## MEASURED, not argued. The same five muted worlds, before and after, counting
## regions and digesting every works landmark:
##
##   seed    regions      works        works digest      parity
##   1       8 -> 6       77 -> 74     changed           moved
##   7       7 -> 6       76 -> 75     changed           moved
##   42      7 -> 6       92 -> 91     changed           moved
##   3       6 -> 6       80 -> 80     IDENTICAL         unchanged
##   90210   6 -> 6       81 -> 81     IDENTICAL         unchanged
##
## Exactly the seeds whose region COUNT changed are the seeds whose works changed,
## and exactly those are the seeds whose digests moved. Two seeds where the floor
## changed nothing moved nothing. That is as tight as this file has ever managed
## and it is why a broken shape was safe to take.
##
## Causation proved the way the seventh asks: with the old square-based floor put
## back and nothing else touched, this test PASSES on the previous hashes.
##
## `props` moves for the second, documented reason: `GenScatter` iterates
## `w.regions` and filters with `region_at`, so which runs are places decides
## where things stand. `WorldStamp.GEN` is 14, turned by hand.
##
## **The rule this adds to the file: "only `props` moved" is the safe shape for a
## SCATTER change, and it is the wrong expectation for a REGION change.** A region
## decides who stamps the ground. Expect `ground` with it, and be suspicious if it
## does not come.


const SIX: Array[StringName] = [&"coast", &"moss", &"pinewood", &"snowfield", &"bonelands", &"burning"]
const SIZE := 256

## seed -> "country country2 ground level blend props", md5 prefixes.
const M1 := {
	1: "06fa726c d5b85d6c 3a2e2753 673b50ca fe4b52d9 cf7dfca2",
	3: "2202ae28 60362f9d 61bff61d 63df669a 585d921b 0aaa6cc8",
	7: "4b153668 3424d5c9 771043cf 1ba2d360 72103915 e9842620",
	42: "e5a96b5f bef1bc39 d84bd16c bc57666e 824c752b d624c3c4",
	90210: "c3fe6c1a a851aff1 ef15edf1 ff6eb869 b6884aed 56e4195f",
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
