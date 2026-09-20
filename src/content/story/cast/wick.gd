## Wick lives on the kerb between the kept metropolis and the dead one. A local: colour, never load (docs/STORY.md §8).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"wick", "name": "Wick", "title": "a kerbsman",
		"at": &"local_ruined_metropolis", "talk": &"wick", "trade": &"scavenger",
		"look": {"build": &"stark", "hair": &"grey", "hair_style": &"unkempt", "beard": &"full"},
		"wants": "To be on the kept side of the line when he is too old to move again.",
		"fears": "That the line will pass over him in his sleep.",
		"hides": "He has moved house four times and always inward, and calls it luck.",
	})
