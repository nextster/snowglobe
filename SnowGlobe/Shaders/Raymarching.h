#ifndef Raymarching_h
#define Raymarching_h

#import "CommonFunctions.h"
#import "Lighting.h"

#include <metal_stdlib>

using namespace metal;

#define DISTANCE_THRESHOLD 0.001
#define MAX_STEPS 128

struct Ray {
    vec3 pos;
    vec3 dir;
};

METAL_FUNC Ray castRay(vec2 uv, vec3 cam) {
    vec3 rayOrigin = cam;
    vec3 rayDirection = normalize(vec3(uv - 0.5, 1.0)); // Simple perspective projection
    
        // Calculate and apply camera transform in one step
    mat4 cameraMatrix = lookAt(cam, float3(0.0), float3(0.0, 1.0, 0.0));
    rayDirection = (cameraMatrix * float4(rayDirection, 0.0)).xyz;
    
    return {
        .pos = rayOrigin,
        .dir = rayDirection
    };
}

METAL_FUNC vec4 rayIntersection(Ray ray, vec3 cam, SDFResult (*sdfScene)(vec3)) {
    SDFResult sdf;
    
    float maxDist = length(cam);
    
    for (int i = 0; i < MAX_STEPS; i++) {
        sdf = sdfScene(ray.pos);
        if (sdf.distance < DISTANCE_THRESHOLD) { break; }
        if (sdf.distance > maxDist) { break; }
        ray.pos += ray.dir * sdf.distance;
    }
    
    return vec4(ray.pos, sdf.distance);
}

METAL_FUNC vec4 raymarch(Ray ray, vec3 cam, vec3 lightDir, SDFResult (*sdfScene)(vec3)) {
    SDFResult sdf;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        sdf = sdfScene(ray.pos);
        
        if (sdf.distance < DISTANCE_THRESHOLD) { break; }
        if (sdf.distance > length(cam)) { break; }
        ray.pos += ray.dir * sdf.distance;
    }
    
    vec4 resColor = vec4(vec3(0.0), 0.0);
    if (sdf.distance < 0.01) {
        resColor = vec4(1, 0, 0, 1);
        resColor.rgb = calculateColor(ray.pos, sdf, cam, lightDir, sdfScene);
        resColor.a = 1;
    } else {
        resColor.rgb = normalize(ray.dir);
        resColor.a = 0.0;
    }
    return resColor;
}
#endif /* Raymarching_h */
