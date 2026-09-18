## Imre Vass, who left the Covenant and drinks near it.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"imre", "name": "Imre", "title": "a man who left the Covenant",
		"at": &"the_covenant", "talk": &"imre", "trade": &"fixer",
		"look": {"build": &"slight", "hair": &"fair", "hair_style": &"unkempt", "beard": &"chin"},
		"may_join": true,
		"wants": "To be trusted again.",
		"fears": "Being sent back.",
		"hides": "He still loves someone inside.",
	})
