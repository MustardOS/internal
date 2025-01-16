#version 130

/*
   
  *******  Super XBR Shader - pass1  *******
   
  Copyright (c) 2015 Hyllian - sergiogdb@gmail.com

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.

*/

#define mul(a,b) (b*a)

#define wp1  8.0
#define wp2  0.0
#define wp3  0.0
#define wp4  0.0
#define wp5  0.0
#define wp6  0.0

#define XBR_RES 2.0

#define weight1 (XBR_WEIGHT*1.75068/10.0)
#define weight2 (XBR_WEIGHT*1.29633/10.0/2.0)

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 TEX0;

vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy;
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

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
uniform sampler2D PassPrev2Texture;
COMPAT_VARYING vec4 TEX0;

// compatibility #defines
#define Source Texture
#define Original PassPrev2Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutputSize vec4(OutputSize, 1.0 / OutputSize)

const float XBR_EDGE_STR = 0.6;
const float XBR_WEIGHT = 1.0;
const float XBR_ANTI_RINGING = 1.0;

const vec3 Y = vec3(.2126, .7152, .0722);

float RGBtoYUV(vec3 color)
{
  return dot(color, Y);
}

float df(float A, float B)
{
  return abs(A-B);
}

/*
                              P1
     |P0|B |C |P1|         C     F4          |a0|b1|c2|d3|
     |D |E |F |F4|      B     F     I4       |b0|c1|d2|e3|   |e1|i1|i2|e2|
     |G |H |I |I4|   P0    E  A  I     P3    |c0|d1|e2|f3|   |e3|i3|i4|e4|
     |P2|H5|I5|P3|      D     H     I5       |d0|e1|f2|g3|
                           G     H5
                              P2
*/

float d_wd(float b0, float b1, float c0, float c1, float c2, float d0, float d1, float d2, float d3, float e1, float e2, float e3, float f2, float f3)
{
	return (wp1*(df(c1,c2) + df(c1,c0) + df(e2,e1) + df(e2,e3)) + wp2*(df(d2,d3) + df(d0,d1)) + wp3*(df(d1,d3) + df(d0,d2)) + wp4*df(d1,d2) + wp5*(df(c0,c2) + df(e1,e3)) + wp6*(df(b0,b1) + df(f2,f3)));
}

float hv_wd(float i1, float i2, float i3, float i4, float e1, float e2, float e3, float e4)
{
	return ( wp4*(df(i1,i2)+df(i3,i4)) + wp1*(df(i1,e1)+df(i2,e2)+df(i3,e3)+df(i4,e4)) + wp3*(df(i1,e2)+df(i3,e4)+df(e1,i2)+df(e3,i4)));
}

vec3 min4(vec3 a, vec3 b, vec3 c, vec3 d)
{
    return min(a, min(b, min(c, d)));
}
vec3 max4(vec3 a, vec3 b, vec3 c, vec3 d)
{
    return max(a, max(b, max(c, d)));
}

const vec3 dtt = vec3(65536.,255.,1.);

vec4 reduce4(vec3 A, vec3 B, vec3 C, vec3 D)
{
  return mul(mat4x3(A, B, C, D), dtt);
}

void main()
{
	//Skip pixels on wrong grid
	vec2 dir = fract(vTexCoord*TextureSize/XBR_RES) - vec2(0.5,0.5);
 	if ((dir.x*dir.y)>0.0){ FragColor = COMPAT_TEXTURE(Source, vTexCoord);
      return;}
      else{

	vec2 tex = (floor(vTexCoord*TextureSize/XBR_RES) + vec2(0.5, 0.5))*XBR_RES/TextureSize;

	vec2 g1 = vec2((XBR_RES/2.0)/TextureSize.x, 0.0);
	vec2 g2 = vec2(0.0, (XBR_RES/2.0)/TextureSize.y);

	vec3 P0 = COMPAT_TEXTURE(Source,	vTexCoord -3.0*g1        ).xyz;
	vec3 P1 = COMPAT_TEXTURE(Source,	vTexCoord         -3.0*g2).xyz;
	vec3 P2 = COMPAT_TEXTURE(Source,	vTexCoord         +3.0*g2).xyz;
	vec3 P3 = COMPAT_TEXTURE(Source,	vTexCoord +3.0*g1        ).xyz;

	vec3  B = COMPAT_TEXTURE(Source,	vTexCoord -2.0*g1     -g2).xyz;
	vec3  C = COMPAT_TEXTURE(Source,	vTexCoord     -g1 -2.0*g2).xyz;
	vec3  D = COMPAT_TEXTURE(Source,	vTexCoord -2.0*g1     +g2).xyz;
	vec3  E = COMPAT_TEXTURE(Source,	vTexCoord     -g1        ).xyz;
	vec3  F = COMPAT_TEXTURE(Source,	vTexCoord             -g2).xyz;
	vec3  G = COMPAT_TEXTURE(Source,	vTexCoord     -g1 +2.0*g2).xyz;
	vec3  H = COMPAT_TEXTURE(Source,	vTexCoord             +g2).xyz;
	vec3  I = COMPAT_TEXTURE(Source,	vTexCoord     +g1        ).xyz;

	vec3 F4 = COMPAT_TEXTURE(Source,	vTexCoord     +g1 -2.0*g2).xyz;
	vec3 I4 = COMPAT_TEXTURE(Source,	vTexCoord +2.0*g1     -g2).xyz;
	vec3 H5 = COMPAT_TEXTURE(Source,	vTexCoord     +g1 +2.0*g2).xyz;
	vec3 I5 = COMPAT_TEXTURE(Source,	vTexCoord +2.0*g1     +g2).xyz;
   
   	vec3 A = COMPAT_TEXTURE(Source, vTexCoord).xyz;

	g1 *= 2.0;
	g2 *= 2.0;

	vec3 F6 = COMPAT_TEXTURE(Original, tex +g1+0.25*g1+0.25*g2).xyz;
	vec3 F7 = COMPAT_TEXTURE(Original, tex +g1+0.25*g1-0.25*g2).xyz;
	vec3 F8 = COMPAT_TEXTURE(Original, tex +g1-0.25*g1-0.25*g2).xyz;
	vec3 F9 = COMPAT_TEXTURE(Original, tex +g1-0.25*g1+0.25*g2).xyz;

	vec3 H6 = COMPAT_TEXTURE(Original, tex +0.25*g1+0.25*g2+g2).xyz;
	vec3 H7 = COMPAT_TEXTURE(Original, tex +0.25*g1-0.25*g2+g2).xyz;
	vec3 H8 = COMPAT_TEXTURE(Original, tex -0.25*g1-0.25*g2+g2).xyz;
	vec3 H9 = COMPAT_TEXTURE(Original, tex -0.25*g1+0.25*g2+g2).xyz;

	vec4 f0 = reduce4(F6, F7, F8, F9);
	vec4 h0 = reduce4(H6, H7, H8, H9);

        bool block_3d = ((f0.xyz==f0.yzw) && (h0.xyz==h0.yzw));

	float b = RGBtoYUV( B );
	float c = RGBtoYUV( C );
	float d = RGBtoYUV( D );
	float e = RGBtoYUV( E );
	float f = RGBtoYUV( F );
	float g = RGBtoYUV( G );
	float h = RGBtoYUV( H );
	float i = RGBtoYUV( I );

	float i4 = RGBtoYUV( I4 ); float p0 = RGBtoYUV( P0 );
	float i5 = RGBtoYUV( I5 ); float p1 = RGBtoYUV( P1 );
	float h5 = RGBtoYUV( H5 ); float p2 = RGBtoYUV( P2 );
	float f4 = RGBtoYUV( F4 ); float p3 = RGBtoYUV( P3 );

	/* Calc edgeness in diagonal directions. */
	float d_edge  = (d_wd( d, b, g, e, c, p2, h, f, p1, h5, i, f4, i5, i4 ) - d_wd( c, f4, b, f, i4, p0, e, i, p3, d, h, i5, g, h5 ));

	/* Calc edgeness in horizontal/vertical directions. */
	float hv_edge = (hv_wd(f, i, e, h, c, i5, b, h5) - hv_wd(e, f, h, i, d, f4, g, i4));

	float limits = XBR_EDGE_STR + 0.000001;
	float edge_strength = smoothstep(0.0, limits, abs(d_edge));

	/* Filter weights. Two taps only. */
	vec4 w1 = vec4(-weight1, weight1+0.5, weight1+0.5, -weight1);
	vec4 w2 = vec4(-weight2, weight2+0.25, weight2+0.25, -weight2);

	/* Filtering and normalization in four direction generating four colors. */
    vec3 c1 = mul(w1, mat4x3( P2,   H,   F,   P1 ));
    vec3 c2 = mul(w1, mat4x3( P0,   E,   I,   P3 ));
	 vec3 c3 = mul(w2, mat4x3(D+G, E+H, F+I, F4+I4));
    vec3 c4 = mul(w2, mat4x3(C+B, F+E, I+H, I5+H5));

	/* Smoothly blends the two strongest directions (one in diagonal and the other in vert/horiz direction). */
	vec3 color =  mix(mix(c1, c2, step(0.0, d_edge)), mix(c3, c4, step(0.0, hv_edge)), 1. - edge_strength);

	/* Anti-ringing code. */
	vec3 min_sample = min4( E, F, H, I ) + (1.-XBR_ANTI_RINGING)*mix((P2-H)*(F-P1), (P0-E)*(I-P3), step(0.0, d_edge));
	vec3 max_sample = max4( E, F, H, I ) - (1.-XBR_ANTI_RINGING)*mix((P2-H)*(F-P1), (P0-E)*(I-P3), step(0.0, d_edge));
	color = clamp(color, min_sample, max_sample);
   
   color = (block_3d) ? color : A;
	
   FragColor = vec4(color, 1.0);
   }
} 
#endif
