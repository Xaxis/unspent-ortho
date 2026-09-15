class_name Ink
## Hatch style ids, mirrored from src/render/ink.gdshaderinc. docs/ART.md says
## which thing is drawn in which hand.

const NONE := 0
const WIND := 1
const STIPPLE := 2
const UPRIGHT := 3
const SPARSE := 4
const CROSS := 5
const SCRIBBLE := 6
const HAND := 7
const CONTOUR := 8

## The ground hatch of each country (index by Country id).
const COUNTRY_STYLE: PackedInt32Array = [NONE, WIND, STIPPLE, UPRIGHT, SPARSE, CROSS, SCRIBBLE]
