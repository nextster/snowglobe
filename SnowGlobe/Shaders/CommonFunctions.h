#ifndef Common_Functions_h
#define Common_Functions_h

#include <metal_stdlib>

using namespace metal;

#define SPHERE_RAD 0.4

METAL_FUNC float2 squarifyUV(float2 uv, float aspect) {
    uv.y -= 0.5;
    uv.y /= aspect;
    uv.y += 0.5;
    return uv;
}
/* discontinuous pseudorandom uniformly distributed in [-0.5, +0.5]^3 */
vec3 random3(vec3 c) {
    float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
    vec3 r;
    r.z = fract(512.0*j);
    j *= .125;
    r.x = fract(512.0*j);
    j *= .125;
    r.y = fract(512.0*j);
    return r-0.5;
}

float snoise(vec3 p) {
    const float F3 =  0.3333333;
    const float G3 =  0.1666667;
    
    vec3 s = floor(p + dot(p, vec3(F3)));
    vec3 x = p - s + dot(s, vec3(G3));
    
    vec3 e = step(vec3(0.0), x - x.yzx);
    vec3 i1 = e*(1.0 - e.zxy);
    vec3 i2 = 1.0 - e.zxy*(1.0 - e);
    
    vec3 x1 = x - i1 + G3;
    vec3 x2 = x - i2 + 2.0*G3;
    vec3 x3 = x - 1.0 + 3.0*G3;
    
    vec4 w, d;
    
    w.x = dot(x, x);
    w.y = dot(x1, x1);
    w.z = dot(x2, x2);
    w.w = dot(x3, x3);
    
    w = max(0.6 - w, 0.0);
    
    d.x = dot(random3(s), x);
    d.y = dot(random3(s + i1), x1);
    d.z = dot(random3(s + i2), x2);
    d.w = dot(random3(s + 1.0), x3);
    
    w *= w;
    w *= w;
    d *= w;
    
    return dot(d, vec4(52.0));
}

float snoiseFractal(vec3 m) {
    return   0.5333333* snoise(m)
    +0.2666667* snoise(2.0*m)
    +0.1333333* snoise(4.0*m)
    +0.0666667* snoise(8.0*m);
}


METAL_FUNC float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec3 noise3(vec3 p) {
    float n1 = snoise(p);             // Base noise
    float n2 = snoise(p + vec3(31.0, 17.0, 101.0)); // Offset noise
    float n3 = snoise(p + vec3(71.0, 37.0, 251.0)); // Another offset
    
    return vec3(n1, n2, n3);
}

METAL_FUNC float3 noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    float a = hash(i.x + i.y * 57.0);
    float b = hash(i.x + 1.0 + i.y * 57.0);
    float c = hash(i.x + (i.y + 1.0) * 57.0);
    float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
    
    float2 u = f * f * (3.0 - 2.0 * f);
    
    float n = mix(mix(a, b, u.x),
                  mix(c, d, u.x),
                  u.y);
    
    return float3(n, n, n);
}

METAL_FUNC float3 fbm(float2 p) {
    float3 f = float3(0.0);
    float amp = 0.5;
    float freq = 1.0;
    
    for (int i = 0; i < 5; i++) {
        f += amp * noise(p * freq);
        freq *= 2.0;
        amp *= 0.5;
    }
    
    return f;
}

float unitSin(float t)
{
    return 0.5 + 0.5 * sin(t);
}

float hash(vec2 x) {
    return hash(x.x + hash(x.y));
}

float valueNoise(vec2 p, float frequency) {
    float bl = hash(floor(p * frequency));
    float br = hash(floor(p * frequency + vec2(1.0, 0.0)));
    float tl = hash(floor(p * frequency + vec2(0.0, 1.0)));
    float tr = hash(floor(p * frequency + vec2(1.0, 1.0)));
    
    vec2 fractPos = fract(p * frequency);
    float smoothX = (3.0 - 2.0 * fractPos.x) * fractPos.x * fractPos.x;
    float bottom = mix(bl, br, smoothX);
    float top = mix(tl, tr, smoothX);
    return mix(bottom, top, (3.0 - 2.0 * fractPos.y) * fractPos.y * fractPos.y);
}

#endif /* Common_Functions_h */
