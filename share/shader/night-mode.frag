// Name: Night Mode
// Author: MustardOS
// Version: 3

#pragma parameter strength "Warmth" 0.72 0.00 1.00 0.01

uniform float strength;

vec2 snap_uv(vec2 uv) {
    vec2 native = max(u_native_resolution, vec2(1.0));
    return (floor(uv * native) + 0.5) / native;
}

void main() {
    vec3 col = texture2D(u_tex, snap_uv(v_uv)).rgb;
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    vec3 warm = vec3(lum * 1.05, lum * 0.90, lum * 0.65);

    col = mix(col, warm, strength);
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
