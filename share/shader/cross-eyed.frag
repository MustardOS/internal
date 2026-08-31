// Name: Cross Eye Depth
// Author: MustardOS
// Version: 3

#pragma parameter separation "Separation" 1.50 0.00 8.00 0.10
#pragma parameter depth_gain "Depth Gain" 4.00 0.00 12.00 0.25

uniform float separation;
uniform float depth_gain;

vec2 native_res() {
    return max(u_native_resolution, vec2(1.0));
}

void main() {
    float side = step(0.5, v_uv.x);
    vec2 base = vec2((v_uv.x - side * 0.5) * 2.0, v_uv.y);

    vec3 src = texture2D(u_tex, clamp(base, 0.0, 1.0)).rgb;
    float depth = dot(src, vec3(0.2126, 0.7152, 0.0722));
    float sep = (separation + depth * depth_gain) / native_res().x;

    float dir = 1.0 - 2.0 * side;
    vec2 uv = clamp(base + vec2(sep * dir, 0.0), 0.0, 1.0);
    vec3 col = texture2D(u_tex, uv).rgb;

    gl_FragColor = vec4(col, 1.0);
}
