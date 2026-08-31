// Name: Frosted Glass
// Author: MustardOS
// Version: 3

#pragma parameter spread "Scatter" 3.00 0.00 12.00 0.25

uniform float spread;

vec2 native_res() {
    return max(u_native_resolution, vec2(1.0));
}

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

void main() {
    vec2 n = native_res();
    vec2 cell = floor(v_uv * n);
    vec2 px = spread / n;
    vec2 off = (vec2(hash(cell), hash(cell + 0.1)) - 0.5) * px;

    gl_FragColor = vec4(texture2D(u_tex, clamp(v_uv + off, 0.0, 1.0)).rgb, 1.0);
}
