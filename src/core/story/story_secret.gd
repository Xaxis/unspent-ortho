class_name StorySecret
## Where he hid it (docs/STORY.md): in the ORDER of three ordinary memories,
## the kitchen at night, a song in the car, June's play. A living brain reliving
## them in order turns the key. His own hand scratched the order on a wall
## (`three_words`): kitchen. car. the hall. in that order.
##
## The keepers hold two of them and the Seeker's 2029 gives the third back, so
## the order they come back in is the order the player walked into them. That
## order is the version of the secret he holds (§4, "misremembered"): whole, or
## turned the wrong way. Pure: it reads when each memory beat landed off Story.

const KEY: Array[StringName] = [&"mem_kitchen", &"mem_car", &"mem_hall"]


## The memories back so far, in the order they came back.
static func order() -> Array[StringName]:
	var got: Array[StringName] = []
	for m: StringName in KEY:
		if Story.landed(m):
			got.append(m)
	got.sort_custom(func(a: StringName, b: StringName) -> bool: return Story.landed_at(a) < Story.landed_at(b))
	return got


static func complete() -> bool:
	return order().size() == KEY.size()


## Whether they came back in the order he hid them in.
static func whole() -> bool:
	return complete() and order() == KEY


## The beat the secret lands as once all three are back, or &"" before then.
static func version() -> StringName:
	if not complete():
		return &""
	return &"secret_whole" if whole() else &"secret_misremembered"
