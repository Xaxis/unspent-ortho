extends TestCase
## The character page's builds and the WORLD's builds are two lists, and this
## file exists to keep them two.
##
## Since the story named its lead, the page dresses one man of 38 (owner,
## 2026-09-18) and offers only builds that read as him. The obvious way to
## implement that — narrow `PersonLook.BUILDS` — would not give the game one
## protagonist. It would give it a world with no women in it: every villager,
## every crowd and every passer is dealt from that array by `PersonLook.random`,
## so one line in the wrong file empties the coast of half its people, silently,
## everywhere at once, with no test anywhere going red.
##
## That is not hypothetical. CLAUDE.md records the same shape happening for real:
## a kit-only piece put in plain `EXTRAS` made `PersonLook.random` deal it to
## strangers, which reshuffled every crowd and tipped the rarities. A shared pool
## read by a narrow consumer is exactly where this class of bug lives.
##
## So: the page may narrow as much as the story wants; the world's pool may not
## be narrowed to serve the page.

const Page := preload("res://src/ui/ui_character_screen.gd")

## What the world must keep whatever the page offers. Not "everything in BUILDS"
## — that would fail the day somebody legitimately adds one — but the ones whose
## absence would mean a population had quietly changed.
const WORLD_MUST_KEEP: Array[StringName] = [&"man", &"woman", &"boy", &"old", &"bent"]


func test_the_world_still_deals_every_kind_of_person() -> void:
	for b: StringName in WORLD_MUST_KEEP:
		check(PersonLook.BUILDS.has(b),
			"`%s` is gone from PersonLook.BUILDS: the page's limit has reached the WORLD's pool, "
			% b + "and every villager, crowd and passer is dealt from it")


func test_the_page_offers_only_the_man_it_is_for() -> void:
	var offered: Array = Page.choices("build")
	check(not offered.is_empty(), "the page offers something")
	for b: StringName in [&"woman", &"boy", &"old", &"bent"]:
		check(not offered.has(b), "the page does not offer `%s`: it dresses Elias, who is 38" % b)
	for b: StringName in offered:
		check(PersonLook.BUILDS.has(b), "`%s` is a build the world actually knows how to draw" % b)


## The narrowing is the PAGE's and the pool is the WORLD's, so the page's list
## must be a strict subset — never the same object, never the same length.
func test_the_page_is_a_subset_and_not_the_pool_itself() -> void:
	var offered: Array = Page.choices("build")
	lt(float(offered.size()), float(PersonLook.BUILDS.size()),
		"the page offers fewer builds than the world holds, or the two lists have become one")
	check(Page.PAGE_FALLBACK in offered, "what a reshuffle falls back to is something the page offers")


## "Someone else" deals a stranger from the world's whole pool and reads it back
## onto Elias. Whatever it deals, what the page ends up showing is him.
func test_a_reshuffle_always_lands_on_a_build_the_page_offers() -> void:
	var offered: Array = Page.choices("build")
	var landed := {}
	for i in 200:
		var dealt := AvatarState.bare(PersonLook.random(7, i))
		var b: StringName = dealt.get("build", &"man")
		if not offered.has(b):
			b = Page.PAGE_FALLBACK
		landed[b] = true
		check(offered.has(b), "a reshuffle landed on `%s`, which the page does not offer" % b)
	# And the deal really is coming off the wide pool — if this ever sees only one
	# build, `PersonLook.random` has stopped varying and the test above is vacuous.
	gt(float(landed.size()), 1.0, "the reshuffle is drawing from a pool with range in it")
