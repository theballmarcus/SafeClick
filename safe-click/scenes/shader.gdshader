shader_type canvas_item;

uniform vec4 rect_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float corner_radius = 18.0;
uniform float edge_softness = 1.5;

uniform float light_strength = 0.035;
uniform float shadow_strength = 0.10;

uniform vec2 light_offset = vec2(-2.0, -2.0);
uniform vec2 shadow_offset = vec2(3.0, 3.0);

float rounded_box_sdf(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
    vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 p = UV * size - size * 0.5;
    vec2 half_size = size * 0.5;

    float base_shape = rounded_box_sdf(p, half_size, corner_radius);
    float alpha = 1.0 - smoothstep(0.0, edge_softness, base_shape);

    float light_shape = rounded_box_sdf(p + light_offset, half_size, corner_radius);
    float shadow_shape = rounded_box_sdf(p + shadow_offset, half_size, corner_radius);

    float light_mask = 1.0 - smoothstep(0.0, edge_softness * 3.0, light_shape);
    float shadow_mask = 1.0 - smoothstep(0.0, edge_softness * 4.0, shadow_shape);

    vec3 col = rect_color.rgb;
    col += light_mask * light_strength;
    col -= shadow_mask * shadow_strength;

    COLOR = vec4(col, rect_color.a * alpha);
}
