// Name: Dot Matrix - Colour Alt.
// Author: MustardOS
// Version: 3

#pragma parameter grid_x "Grid Depth X" 0.040 0.000 0.200 0.005
#pragma parameter grid_y "Grid Depth Y" 0.015 0.000 0.200 0.005
#pragma parameter edge_fade "Edge Fade" 1.00 0.00 8.00 0.25
#pragma parameter column_depth "Column Depth" 0.009 0.000 0.050 0.001

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

vec3 soft_sample(vec2 uv, vec2 px) {
    vec3 c;

    c = sample_rgb(uv) * 0.72;
    c += sample_rgb(uv - vec2(px.x, 0.0)) * 0.14;
    c += sample_rgb(uv + vec2(px.x, 0.0)) * 0.10;
    c += sample_rgb(uv - vec2(0.0, px.y)) * 0.02;
    c += sample_rgb(uv + vec2(0.0, px.y)) * 0.02;

    return c;
}

void main() {
    const float PI = 3.14159265;

    vec2 n = native_res();
    vec2 uv = snap_uv(v_uv);
    vec2 px = 1.0 / n;

    vec3 c = soft_sample(uv, px * 0.45);
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    vec3 col = mix(vec3(l), c, 0.985) * vec3(1.00, 0.995, 0.95);

    float ex = edge_x(v_uv);
    float gx = mix(1.0, 1.0 - grid_x + grid_x * sin(v_uv.x * n.x * PI), ex);
    float gy = 1.0 - grid_y + grid_y * sin(v_uv.y * n.y * PI);
    float column = mix(1.0, 1.0 - column_depth + column_depth * sin(v_uv.x * n.x * 1.5708), ex);

    col *= gx * gy;
    col *= column;

    gl_FragColor = vec4(col, 1.0);
}
