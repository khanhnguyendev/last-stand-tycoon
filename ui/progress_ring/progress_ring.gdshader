shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.2, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = fract(atan(p.x, -p.y) / 6.28318530718 + 1.0);
	float ring = step(0.72, r) * step(r, 1.0);
	float fill = step(ang, progress);
	ALBEDO = color.rgb;
	ALPHA = ring * mix(0.25, 1.0, fill) * color.a;
}
