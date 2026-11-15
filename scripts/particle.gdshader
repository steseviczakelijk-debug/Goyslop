// Camera-facing particle that can spin and pick one picture out of a grid.
// Per-instance custom data carries (cell index, rotation); colour tints it.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform vec2 grid = vec2(1.0, 1.0);

varying vec4 v_color;

void vertex() {
	float a = INSTANCE_CUSTOM.y;
	VERTEX.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
	float cell = floor(INSTANCE_CUSTOM.x + 0.5);
	UV = (UV + vec2(mod(cell, grid.x), floor(cell / grid.x))) / grid;
	v_color = COLOR;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(MAIN_CAM_INV_VIEW_MATRIX[0], MAIN_CAM_INV_VIEW_MATRIX[1], MAIN_CAM_INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(tex, UV) * v_color;
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
