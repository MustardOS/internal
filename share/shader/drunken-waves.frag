// Name: Drunken Waves
// Author: MustardOS
// Version: 3

#pragma parameter sway "Sway" 1.00 0.00 4.00 0.05
#pragma parameter speed "Speed" 1.00 0.00 4.00 0.05
#pragma parameter fringe "Colour Fringe" 1.00 0.00 4.00 0.05

uniform float sway;
uniform float speed;
uniform float fringe;

float tri(float x) {
    x = fract(x * 0.5 + 0.25);
    return abs(x - 0.5) * 4.0 - 1.0;
}

void main() {
    float t = u_time * 0.0075 * speed;
    vec2 uv = v_uv;

    uv.x += tri(v_uv.y * 3.5 + t * 2.0) * 0.010 * sway;
    uv.y += tri(v_uv.x * 3.5 + t * 1.6) * 0.007 * sway;

    float off = 0.005 * fringe;
    float r = texture2D(u_tex, clamp(uv + vec2(off, 0.0), 0.0, 1.0)).r;
    float g = texture2D(u_tex, clamp(uv, 0.0, 1.0)).g;
    float b = texture2D(u_tex, clamp(uv - vec2(off, 0.0), 0.0, 1.0)).b;

    gl_FragColor = vec4(r, g, b, 1.0);
}
