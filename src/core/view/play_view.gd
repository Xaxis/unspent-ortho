extends RefCounted
## THE PLAY CAMERA'S BEARING, as a rule the world can read. CameraRig draws the
## view at YAW_DEG and the spawner scores what is in it from the same number; a
## world rule that cares which faces the eye sees (Works.lip_foot) reads it here,
## because worldgen and core may not name a render class. One number, so the
## camera and what is sited for it cannot drift apart.
##
## Reached through a `preload`, never a class_name, as Shoulder is.

## Degrees the play camera is turned about the vertical (CameraRig.yaw_deg).
const YAW_DEG := 45.0


## The way across the ground, in tiles (x east, y south), from what the camera
## looks at toward where it stands: a face falling this way is turned to the eye,
## and one falling the other way is hidden behind its own edge.
static func toward_eye() -> Vector2:
	var yaw := deg_to_rad(YAW_DEG)
	return Vector2(sin(yaw), cos(yaw))
