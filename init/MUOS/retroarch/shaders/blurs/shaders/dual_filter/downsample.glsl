/*
    Dual Filter Blur & Bloom v1.2 by fishku
    Copyright (C) 2023-2024
    Public domain license (CC0)

    The dual filter blur implementation follows the notes of the SIGGRAPH 2015
    talk here:
    https://community.arm.com/cfs-file/__key/communityserver-blogs-components-weblogfiles/00-00-00-20-66/siggraph2015_2D00_mmg_2D00_marius_2D00_notes.pdf
    Dual filtering is a fast large-radius blur that approximates a Gaussian
    blur. It is closely related to the popular blur filter by Kawase, but runs
    faster at equal quality.

    How it works: Any number of downsampling passes are chained with the same
    number of upsampling passes in an hourglass configuration. Both types of
    resampling passes exploit bilinear interpolation with carefully chosen
    coordinates and weights to produce a smooth output. There are just 5 + 8 =
    13 texture samples per combined down- and upsampling pass. The effective
    blur radius increases with the number of passes.

    This implementation adds a configurable blur strength which can diminish or
    accentuate the effect compared to the reference implementation, equivalent
    to strength 1.0. A blur strength above 3.0 may lead to artifacts, especially
    on presets with fewer passes.

    The bloom filter applies a thresholding operation, then blurs the input to
    varying degrees. The scene luminance is estimated using a feedback pass with
    variable update speed. The final pass screen blends a tonemapped bloom value
    with the original input, with the bloom intensity controlled by the scene
    luminance (a.k.a. eye adaption).

    Changelog:
    v1.2: Implement mirrored_repeat programmatically to work around GLSL
          limitations.
    v1.1: Added bloom functionality.
    v1.0: Initial release.
*/

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 TEX0;

uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float BLUR_RADIUS;
#else
#define BLUR_RADIUS 1.0
#endif

COMPAT_VARYING vec2 in_size_normalized;
COMPAT_VARYING vec2 mirror_min;
COMPAT_VARYING vec2 mirror_max;
COMPAT_VARYING vec2 offset;

#define vTexCoord TEX0.xy

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy;
    in_size_normalized = InputSize / TextureSize;
    mirror_min = 0.5 / TextureSize;
    mirror_max = (InputSize - 0.5) / TextureSize;
    offset = BLUR_RADIUS / TextureSize;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out COMPAT_PRECISION vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;

COMPAT_VARYING vec2 in_size_normalized;
COMPAT_VARYING vec2 mirror_min;
COMPAT_VARYING vec2 mirror_max;
COMPAT_VARYING vec2 offset;

#define Source Texture
#define vTexCoord TEX0.xy

vec2 mirror_repeat(vec2 coord) {
    vec2 doubled = mod(coord, 2.0 * in_size_normalized);
    vec2 mirror = step(in_size_normalized, doubled);
    return clamp(mix(doubled, 2.0 * in_size_normalized - doubled, mirror),
                 mirror_min, mirror_max);
}

vec3 downsample(sampler2D tex, vec2 coord, vec2 offset) {
    // The offset should be 1 source pixel size which equals 0.5 output pixel
    // sizes in the default configuration.
    return (COMPAT_TEXTURE(tex, mirror_repeat(coord - offset)).rgb +
            COMPAT_TEXTURE(tex,
                           mirror_repeat(coord + vec2(offset.x, -offset.y)))
                .rgb +
            COMPAT_TEXTURE(tex, mirror_repeat(coord)).rgb * 4.0 +
            COMPAT_TEXTURE(tex, mirror_repeat(coord + offset)).rgb +
            COMPAT_TEXTURE(tex,
                           mirror_repeat(coord - vec2(offset.x, -offset.y)))
                .rgb) *
           0.125;
}

void main() { FragColor = vec4(downsample(Source, vTexCoord, offset), 1.0); }

#endif
