shader_type canvas_item;
// Colour grade for the 1970s painted-album-cover mood: crushed warm shadows,
// burning highlights, heavy vignette, a red glow from the sky and film grain.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 shadow = vec3(0.10, 0.015, 0.03);
	vec3 high = vec3(1.0, 0.70, 0.40);
	vec3 duo = mix(shadow, high, smoothstep(0.0, 0.85, l));
	vec3 g = mix(c, duo * (0.7 + 0.6 * c), 0.22) * 1.12;
	// keep the heat-ray green vivid
	float green = clamp((c.g - max(c.r, c.b)) * 3.0, 0.0, 1.0);
	g = mix(g, c * 1.15, green);
	// burning sky glow from the north edge of the map
	g += vec3(0.20, 0.035, 0.0) * pow(1.0 - uv.y, 2.0) * 0.6;
	// vignette
	vec2 d = (uv - 0.5) * vec2(1.25, 1.0);
	float v = smoothstep(0.95, 0.35, length(d));
	g *= mix(0.55, 1.0, v);
	// grain
	g += (rand(uv * 731.0 + fract(TIME * 13.7)) - 0.5) * 0.045;
	COLOR = vec4(g, 1.0);
}
