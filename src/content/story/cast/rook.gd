## Rook, captain of the Holdfast's last mercenaries.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"rook", "name": "Rook", "title": "a man with a rifle",
		"at": &"the_camp", "talk": &"rook", "trade": &"scavenger",
		"look": {"build": &"stark", "hair": &"dark", "hair_style": &"crop", "beard": &"full"},
		"may_join": true,
		"wants": "HALCYON dead.",
		"fears": "Outliving the last of his company.",
		"hides": "Who paid him to wait for Elias on the shore.",
	})
