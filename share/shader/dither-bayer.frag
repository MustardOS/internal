// Name: Dither - Bayer
// Author: MustardOS
// Version: 3

#pragma parameter strength "Dither Strength" 0.12 0.00 0.50 0.01
#pragma parameter levels "Colour Levels" 4.00 2.00 16.00 1.00

uniform float strength;
uniform float levels;

vec2 native_res() {
    return max(u_native_resolution, vec2(1.0));
}

float bayer(vec2 p) {
    p = mod(floor(p), 4.0);

    float a = mod(p.x, 2.0);
    float b = mod(floor(p.x * 0.5), 2.0);
    float c = mod(p.y, 2.0);
    float d = mod(floor(p.y * 0.5), 2.0);

    return (a + b * 2.0 + c * 4.0 + d * 8.0) / 16.0 - 0.5;
}

void main() {
    vec3 col = texture2D(u_tex, v_uv).rgb;
    float th = bayer(v_uv * native_res()) * strength;

    gl_FragColor = vec4(floor((col + th) * levels + 0.5) / levels, 1.0);
}
