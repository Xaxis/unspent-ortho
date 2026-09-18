## Vera Kessane, who leads the Holdfast. She comes to the camp once Rook has told
## her he fished a weapon out of the sea.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"vera", "name": "Vera", "title": "the Holdfast's leader",
		"at": &"the_camp", "talk": &"vera", "trade": &"scavenger",
		"look": {"build": &"woman", "hair": &"dark", "hair_style": &"crop", "beard": &"none", "coat": &"long"},
		"appears_when": &"holdfast_hope",
		"wants": "The world back.",
		"fears": "That her people will stop.",
		"hides": "She read the machines' record of her war: they file the Holdfast under weather. She has not told her people.",
	})
