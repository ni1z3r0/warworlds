shader_type spatial;
// The machine's shield: an additive rim glow that shimmers in bands.
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 col = vec3(0.45, 1.0, 0.75);
uniform float strength = 0.35;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float bands = 0.6 + 0.4 * sin(TIME * 3.0 + UV.y * 40.0);
	ALBEDO = col * rim * strength * bands;
}
