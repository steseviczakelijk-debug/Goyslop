// Camera-facing unit sprite that can flash white when hit and lean from side to
// side. In a MultiMesh the per-instance custom data carries (flash, tilt).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform float flash = 0.0;
uniform float tilt = 0.0;

varying float v_flash;

void vertex() {
	float a = tilt + INSTANCE_CUSTOM.y;
	VERTEX.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
	v_flash = max(flash, INSTANCE_CUSTOM.x);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(MAIN_CAM_INV_VIEW_MATRIX[0], MAIN_CAM_INV_VIEW_MATRIX[1], MAIN_CAM_INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = mix(c.rgb, vec3(1.0), clamp(v_flash, 0.0, 1.0));
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
