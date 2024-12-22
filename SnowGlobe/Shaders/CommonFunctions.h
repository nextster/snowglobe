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

#endif /* Common_Functions_h */
