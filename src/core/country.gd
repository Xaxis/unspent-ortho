class_name Country
## Compatibility layer, kept only so the sea and the six M1 landscapes can be
## named by constant where a number is needed (a sentinel for "no land here", a
## gallery that wants one house of each). Landscapes are data now: they live in
## src/content/biomes/ and are read through BiomeRegistry.
##
## Never branch on a Country constant in new code, never iterate these, and
## never size an array by them: a world has as many landscape types as the
## registry holds, and these are only the first seven of them.

const SEA := 0
const COAST := 1
const MOSS := 2
const PINEWOOD := 3
const SNOWFIELD := 4
const BONELANDS := 5
const BURNING := 6
