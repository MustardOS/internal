// Name: Dot Matrix - Original Alt.
// Author: MustardOS
// Version: 3

#pragma parameter grid_x "Grid Depth X" 0.050 0.000 0.200 0.005
#pragma parameter grid_y "Grid Depth Y" 0.020 0.000 0.200 0.005
#pragma parameter edge_fade "Edge Fade" 1.00 0.00 8.00 0.25
#pragma parameter column_depth "Column Depth" 0.010 0.000 0.050 0.001

uniform float grid_x;
uniform float grid_y;
uniform float edge_fade;
uniform float column_depth;

vec2 native_res() {
    return max(u_native_resolution, vec2(1.0));
}

vec2 clamp_uv(vec2 uv) {
    vec2 px = 0.5 / native_res();
    return clamp(uv, px, 1.0 - px);
}

vec2 snap_uv(vec2 uv) {
    vec2 n = native_res();
    return clamp_uv((floor(uv * n) + 0.5) / n);
}

vec3 sample_rgb(vec2 uv) {
    return texture2D(u_tex, clamp_uv(uv)).rgb;
}

float edge_x(vec2 uv) {
    vec2 n = native_res();
    float px = uv.x * n.x;
    float fade = max(edge_fade, 0.001);
    return smoothstep(0.0, fade, px) *
           smoothstep(0.0, fade, n.x - px);
}

vec3 map_palette(float l, vec3 p0, vec3 p1, vec3 p2, vec3 p3) {
    if (l < 0.25) return mix(p0, p1, l / 0.25);
    if (l < 0.50) return mix(p1, p2, (l - 0.25) / 0.25);
    if (l < 0.75) return mix(p2, p3, (l - 0.50) / 0.25);
    return p3;
}

void main() {
    const float PI = 3.14159265;
    const vec3 LUMA = vec3(0.299, 0.587, 0.114);

    const vec3 p0 = vec3(0.06, 0.16, 0.06);
    const vec3 p1 = vec3(0.19, 0.38, 0.19);
    const vec3 p2 = vec3(0.55, 0.67, 0.26);
    const vec3 p3 = vec3(0.85, 0.93, 0.09);

    vec2 n = native_res();
    vec2 uv = snap_uv(v_uv);

    float l = dot(sample_rgb(uv), LUMA);
    vec3 col = map_palette(l, p0, p1, p2, p3);

    float ex = edge_x(v_uv);
    float gx = mix(1.0, 1.0 - grid_x + grid_x * sin(v_uv.x * n.x * PI), ex);
    float gy = 1.0 - grid_y + grid_y * sin(v_uv.y * n.y * PI);
    float column = mix(1.0, 1.0 - column_depth + column_depth * sin(v_uv.x * n.x * 1.5708), ex);

    col *= gx * gy;
    col *= column;

    gl_FragColor = vec4(col, 1.0);
}
