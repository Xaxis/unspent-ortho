extends TestCase
## The six M1 countries became six landscape files. This pins the proof: a world
## generated from only those six is the world M1 generated, tile for tile and
## prop for prop.
##
## The digests were taken on main at 2faee61, before the registry existed. If a
## change here moves one of them, the six landscapes are no longer what they
## were and the canon frames will have moved with them: look at the pictures
## before accepting a new number.

const SIX: Array[StringName] = [&"coast", &"moss", &"pinewood", &"snowfield", &"bonelands", &"burning"]
const SIZE := 256

## seed -> "country country2 ground level blend props", md5 prefixes.
const M1 := {
	1: "d1335897 8b46ae9f 6a856d7c 7b99a6e3 48aff72c 0f7dd1f2",
	3: "d7a39e67 dba8792b 0ff796f3 090631fd 45aca88e 8c1b5599",
	7: "aa526bae 4ff8f6b7 03d1260a 7fb78385 be4cc1f0 54a7bd2c",
	42: "325e4566 8d16e00c 403bd9fe b88a5d6e b0352440 1dd38e5c",
	90210: "5b1e7401 4d0ad4be 0ddbbde8 bf578b00 ed81f772 dc65f737",
}


func test_a_world_of_the_six_is_the_world_m1_made() -> void:
	BiomeRegistry.mute_to(SIX)
	eq(BiomeRegistry.count(), 7, "the sea and the six")
	for s: int in M1:
		var w := WorldGen.generate(s, SIZE)
		eq(digest(w), M1[s], "seed %d" % s)
	BiomeRegistry.mute_to([])
	gt(float(BiomeRegistry.count()), 7.0, "the whole registry is back")


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
