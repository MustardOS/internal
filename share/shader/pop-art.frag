// Name: Pop Art
// Author: MustardOS
// Version: 3

#pragma parameter gain "Tint Gain" 1.40 0.50 3.00 0.05

uniform float gain;

void main() {
    vec2 q = floor(v_uv * 2.0);
    vec2 p = fract(v_uv * 2.0);
    vec2 uv = (floor(p * u_native_resolution) + 0.5) / max(u_native_resolution, vec2(1.0));

    float y = dot(texture2D(u_tex, uv).rgb, vec3(0.2126, 0.7152, 0.0722));

    vec3 tint;
    if (q.x < 0.5 && q.y < 0.5) tint = vec3(1.0, 0.2, 0.2);
    else if (q.x > 0.5 && q.y < 0.5) tint = vec3(0.2, 1.0, 0.2);
    else if (q.x < 0.5 && q.y > 0.5) tint = vec3(0.2, 0.4, 1.0);
    else tint = vec3(1.0, 1.0, 0.2);

    gl_FragColor = vec4(vec3(y) * tint * gain, 1.0);
}
