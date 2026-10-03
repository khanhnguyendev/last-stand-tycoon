shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// One draw for every particle (S5 Task 4, D-214): camera-facing quads. Cell index comes from INSTANCE_CUSTOM.x.
uniform sampler2D atlas : source_color, filter_linear_mipmap;
varying float v_cell;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	v_cell = INSTANCE_CUSTOM.x;
}
void fragment() {
	vec2 uv = vec2((UV.x + v_cell) * 0.25, UV.y);
	vec4 t = texture(atlas, uv);
	ALBEDO = COLOR.rgb * t.rgb;
	ALPHA = COLOR.a * t.a;
}
