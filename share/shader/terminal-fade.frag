// Name: Terminal - Fade Edition
// Author: MustardOS
// Version: 3

#pragma parameter fringe "Colour Fringe" 1.50 0.00 6.00 0.10
#pragma parameter scan_speed "Scan Speed" 1.00 0.00 4.00 0.05
#pragma parameter flicker_amt "Flicker" 0.04 0.00 0.30 0.01

uniform float fringe;
uniform float scan_speed;
uniform float flicker_amt;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

void main() {
    const float PI = 3.14159265;

    vec2 native = max(u_native_resolution, vec2(1.0));
    vec2 o = vec2(fringe) / native;

    vec3 col;
    col.r = texture2D(u_tex, v_uv + o).r;
    col.g = texture2D(u_tex, v_uv).g;
    col.b = texture2D(u_tex, v_uv - o).b;

    float scan = fract(v_uv.y + u_time * 0.01 * scan_speed);
    float fade = exp(-scan * 0.15);
    float lines = 0.9 + 0.1 * sin(v_uv.y * native.y * PI);
    float flick = hash(v_uv * native + u_time) * flicker_amt + (1.0 - flicker_amt);

    gl_FragColor = vec4(col * (0.4 + 0.6 * fade) * lines * flick, 1.0);
}
