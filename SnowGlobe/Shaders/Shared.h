//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef Shared_h
#define Shared_h

#include <simd/simd.h>

#ifdef __METAL_VERSION__
    // Metal shading language is included
typedef float2 vec2;
typedef float3 vec3;
typedef float4 vec4;

typedef metal::float3x3 mat3;
typedef metal::float4x4 mat4;
//#include <metal_stdlib>
//using namespace metal;
#else
    // Metal is not included, fall back or handle error
//#include <stdio.h>
//#error "Metal is not available"
#endif

typedef struct
{
    float aspect;
    float time;
    simd_float3 color;
} Uniforms;

#endif /* Shared_h */

