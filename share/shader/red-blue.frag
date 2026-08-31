// Name: Red Blue Stereo
// Author: MustardOS
// Version: 3

#pragma parameter separation "Separation" 5.00 0.00 20.00 0.50
#pragma parameter wobble "Wobble" 0.60 0.00 3.00 0.05
#pragma parameter blend "Blend" 0.85 0.00 1.00 0.01

uniform float separation;
uniform float wobble;
uniform float blend;

void main() {
    float px = 1.0 / max(u_native_resolution.x, 1.0);
    float depth = px * separation + sin(u_time * 0.18) * px * wobble;

    vec3 left = texture2D(u_tex, v_uv - vec2(depth, 0.0)).rgb;
    vec3 right = texture2D(u_tex, v_uv + vec2(depth, 0.0)).rgb;
    vec3 centre = texture2D(u_tex, v_uv).rgb;

    gl_FragColor = vec4(mix(centre, vec3(left.r, right.g, right.b), blend), 1.0);
}
