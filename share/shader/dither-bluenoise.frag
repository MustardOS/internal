// Name: Dither - Blue Noise
// Author: MustardOS
// Version: 3

#pragma parameter strength "Dither Strength" 0.12 0.00 0.50 0.01
#pragma parameter levels "Colour Levels" 4.00 2.00 16.00 1.00

uniform float strength;
uniform float levels;

vec2 native_res() {
    return max(u_native_resolution, vec2(1.0));
}

float noise(vec2 p) {
    p = fract(p * vec2(0.1031, 0.1030));
    p += dot(p, p.yx + 33.33);
    return fract((p.x + p.y) * p.x);
}

float blue(vec2 p) {
    float n = noise(p)
            + noise(p + vec2(1.3, 0.0)) * 0.5
            + noise(p + vec2(0.0, 1.7)) * 0.5
            + noise(p + vec2(1.3, 1.7)) * 0.25;
    return n / 2.25 - 0.5;
}

void main() {
    vec3 col = texture2D(u_tex, v_uv).rgb;
    float th = blue(v_uv * native_res() + fract(u_time) * 37.0) * strength;

    gl_FragColor = vec4(floor((col + th) * levels + 0.5) / levels, 1.0);
}
