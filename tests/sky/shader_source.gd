extends RefCounted
## Reading the sky's shaders as text, for tests.
##
## A GLSL law cannot be run headless, so the rules the shaders spell out are read
## instead: the constants they are tuned by, and the lines a later change must not
## quietly drop. A test that only greps is weak, so the constants come back as
## NUMBERS and the test does the arithmetic the shader does with them.

const SKY_INC := "res://src/render/sky.gdshaderinc"
const OUTLINE := "res://src/render/outline.gdshader"
const PRECIP := "res://src/render/weather/precip.gdshader"


static func text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## The first number after `decl` in the shader source (a float const, or the
## first component of a vec3). NAN when the declaration is gone.
static func number(code: String, decl: String) -> float:
	var at := code.find(decl)
	if at < 0:
		return NAN
	var rest := code.substr(at + decl.length(), 64).strip_edges()
	if rest.begins_with("="):
		rest = rest.substr(1).strip_edges()
	if rest.begins_with("vec3("):
		rest = rest.substr(5)
	var num := ""
	for i in rest.length():
		var ch := rest[i]
		if ch.is_valid_int() or ch == "." or ch == "-":
			num += ch
		elif num != "":
			break
	return num.to_float() if num != "" else NAN


## All three components of a `const vec3 NAME = vec3(a, b, c);`.
static func vec3_const(code: String, decl: String) -> Vector3:
	var at := code.find(decl)
	if at < 0:
		return Vector3.ZERO
	var open := code.find("vec3(", at)
	var close := code.find(")", open)
	if open < 0 or close < 0:
		return Vector3.ZERO
	var parts := code.substr(open + 5, close - open - 5).split(",")
	if parts.size() < 3:
		return Vector3.ZERO
	return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())


## Rec. 709 luminance, the same weighting Color.get_luminance() uses, so a
## shader constant and a Palette colour can be compared on one scale.
static func luma(c: Vector3) -> float:
	return c.x * 0.2126 + c.y * 0.7152 + c.z * 0.0722
