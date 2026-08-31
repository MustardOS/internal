// Name: Chromatic Aberration
// Author: MustardOS
// Version: 3

#pragma parameter amount "Fringe Amount" 0.75 0.00 4.00 0.05
#pragma parameter speed "Pulse Speed" 0.50 0.00 2.00 0.05

uniform float amount;
uniform float speed;

vec2 native_res() {
    return max(u_native_resolution, vec2(1.0));
}

void main() {
    vec2 px = 1.0 / native_res();
    float a = 0.5 + 0.5 * sin(u_time * speed);
    vec2 shift = px * amount * (1.0 + a);

    vec3 c;
    c.r = texture2D(u_tex, clamp(v_uv + shift, 0.0, 1.0)).r;
    c.g = texture2D(u_tex, v_uv).g;
    c.b = texture2D(u_tex, clamp(v_uv - shift, 0.0, 1.0)).b;

    gl_FragColor = vec4(c, 1.0);
}
