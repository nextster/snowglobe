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

METAL_FUNC float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

METAL_FUNC float hash(vec2 x) {
    return hash(x.x + hash(x.y));
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

METAL_FUNC float valueNoise(vec2 p, float frequency) {
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
