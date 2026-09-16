extends TestCase
## Decor's enum and its hand-counted `KINDS` have to agree. `_SPECK` is sized to
## KINDS once and then indexed by kind on every item of every chunk, so a kind
## added without bumping the count reads off the end of a PackedByteArray on the
## first chunk the game builds — which is a crash on a real start and nothing at
## all in a headless test that never meshes. Two packages each added two kinds in
## M2 wave A and each bumped the count by two, which is how this test exists.

func test_the_kind_count_matches_the_enum() -> void:
	# REBAR is the last name in the enum; the count is one past it.
	eq(Decor.KINDS, Decor.REBAR + 1, "Decor.KINDS counts the enum")


func test_every_kind_is_drawn_in_every_landscape() -> void:
	for kind: int in Decor.KINDS:
		for d: BiomeDef in BiomeRegistry.land():
			var t := Decor.template(kind, d.index)
			check(t != null and t.v.size() > 0,
				"decor %d draws something in %s" % [kind, d.id])
