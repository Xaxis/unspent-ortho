## Tull farms the lame walker's craters from the ground between them, which its
## foot never presses. The walker's, not a landscape's: colour, never load
## (docs/STORY.md). He never says the road up; the warden does (walker_told).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"tull", "name": "Tull", "title": "a tread-farmer",
		"at": &"the_tread", "talk": &"tull", "trade": &"digger",
		"look": {"build": &"bent", "hair": &"grey", "hair_style": &"unkempt", "beard": &"chin", "coat": &"wrap"},
		"wants": "One lap where nobody has to run.",
		"fears": "The foot coming down whole one day, and never coming back to these holes.",
		"hides": "His father is under the middle toe. He sows that crater first, and the line comes down into it.",
	})
