class_name Ink
## Hatch style ids, mirrored from src/render/ink.gdshaderinc. docs/ART.md says
## which thing is drawn in which hand; a landscape names its own in
## `BiomeDef.hatch`.

const NONE := 0
const WIND := 1
const STIPPLE := 2
const UPRIGHT := 3
const SPARSE := 4
const CROSS := 5
const SCRIBBLE := 6
const HAND := 7
const CONTOUR := 8
const CRACK := 9
## The last hand. BiomeRegistry validates a landscape's `hatch` against it, so a
## new hand is one const here and one branch in ink.gdshaderinc.
const LAST := CRACK


## The ground hatch of the landscape type at index c.
static func hand_of(c: int) -> int:
	return BiomeRegistry.by_index(c).hatch
