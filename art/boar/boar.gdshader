shader_type spatial;
render_mode cull_back, diffuse_lambert;
// The production Boar (S4 Task 9, D-192). Palette vertex colours are sRGB; leg vertices have COLOR.a = 0.
uniform float run_amount = 0.0;   // 0 idle, 1 run (two shared materials)
uniform float hop_hz = 4.0;
uniform float leg_swing = 0.5;    // hip-to-foot sweep per metre below the hip: a 0.25 m leg swings about 0.12 m
uniform bool flash = false;
uniform vec3 flash_color : source_color = vec3(1.0, 0.85, 0.8);   // pale pink-white; never #ffffff (R2)
void vertex() {
	vec3 origin = NODE_POSITION_WORLD;
	float phase = (origin.x + origin.z) * 1.7;
	float leg = 1.0 - COLOR.a;
	float side = sign(VERTEX.x) * sign(VERTEX.z);
	// one leg cycle per two hops (the prototype's 2 Hz swing against the 4 Hz hop)
	VERTEX.z += leg * side * leg_swing * run_amount * sin(TIME * hop_hz * 3.14159265 + phase) * max(0.25 - VERTEX.y, 0.0);
}
void fragment() {
	vec3 c = COLOR.rgb;  // palette vertex colours are sRGB
	vec3 lin = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
	ALBEDO = flash ? flash_color : lin;
	ROUGHNESS = 0.6;
	RIM = 0.35;
	RIM_TINT = 0.4;
}
