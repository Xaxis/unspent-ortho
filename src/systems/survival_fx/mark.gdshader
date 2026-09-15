// A drawn mark hidden by what stands in front of it: dust, smoke, flecks. See mark.gdshaderinc.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

#include "res://src/systems/survival_fx/mark.gdshaderinc"
