// Name: Ripple
// Author: MustardOS
// Version: 3

#pragma parameter amplitude "Amplitude" 2.00 0.00 8.00 0.10
#pragma parameter frequency "Frequency" 18.00 2.00 60.00 1.00
#pragma parameter speed "Speed" 0.045 0.000 0.300 0.005

uniform float amplitude;
uniform float frequency;
uniform float speed;

void main() {
    vec2 uv = v_uv - 0.5;
    float r = length(uv);
    float amp = amplitude / max(min(u_native_resolution.x, u_native_resolution.y), 1.0);
    float wave = sin(r * frequency - u_time * speed) * amp;

    gl_FragColor = vec4(texture2D(u_tex, v_uv + (uv / (r + 0.0001)) * wave).rgb, 1.0);
}
