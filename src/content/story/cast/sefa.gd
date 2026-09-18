## Sefa tends the Tether's foot on the far shore, fed by the machines for keeping
## it clear. She is the last stop on the ground, and the lead up.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"sefa", "name": "Sefa", "title": "a Tether-tender",
		"at": &"the_far_works", "talk": &"sefa", "trade": &"digger",
		"look": {"build": &"woman", "hair": &"black", "hair_style": &"crop", "beard": &"none", "coat": &"long"},
		"wants": "To see where the cars go.",
		"fears": "Looking up too long.",
		"hides": "She has watched the cars for nine years and never once asked to ride one.",
	})
