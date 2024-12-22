//
//  SDF+Lighting.h
//  SnowGlobe
//
//  Created by Артём on 22.12.2024.
//

#ifndef Raymarchin_Lighting_h
#define Raymarchin_Lighting_h

#import "CommonFunctions.h"

#include <metal_stdlib>

using namespace metal;

#define DISTANCE_THRESHOLD 0.001
#define MAX_STEPS 128

struct Ray {
    vec3 origin;
    vec3 dir;
};

METAL_FUNC vec3 calculateNormal(vec3 point, SDFResult (*sdfScene)(vec3)) {
    const float h = 0.0001;
    const vec2 k = vec2(1, -1);
    SDFResult res = sdfScene(point);
    vec3 normal = normalize(k.xyy * sdfScene(point + k.xyy * h).distance +
                            k.yyx * sdfScene(point + k.yyx * h).distance +
                            k.yxy * sdfScene(point + k.yxy * h).distance +
                            k.xxx * sdfScene(point + k.xxx * h).distance);
    if (res.uv.x > 0.0 || res.uv.y > 0.0) {
        normal += fbm(res.uv * 200) * 0.1 * res.roughness;
        normal = normalize(normal);
    }
    return normal;
}

METAL_FUNC float softShadow(vec3 point, vec3 lightPos, float k, SDFResult (*sdfScene)(vec3)) {
    float3 lightDir = lightPos - point;
    float lightDistance = length(lightDir);
    lightDir = normalize(lightDir);
    
    float light = 1.0;
    float eps = DISTANCE_THRESHOLD;
    float distAlongRay = eps * 3;
    
    for (int i = 0; i < 256; i++) {
        float3 samplePoint = point + lightDir * distAlongRay;
        float dist = sdfScene(samplePoint).distance;
        
        light = min(light, 1.0 - (eps - dist) / eps);
        
        distAlongRay += dist * 0.5;
        eps += dist * k;
        
        if (distAlongRay > lightDistance) {
            break;
        }
    }
    
    return max(light, 0.0);
}

METAL_FUNC float calculateAO(vec3 point, vec3 normal, SDFResult (*sdfScene)(vec3)) {
    float eps = 0.001;
    point += normal * eps * 2.0;
    float occlusion = 0.0;
    for (float i = 1.0; i < 16; i++) {
        float d = sdfScene(point).distance;
        float coneWidth = 2.0 * eps;
        float occlusionAmount = max(coneWidth - d, 0.);
        float occlusionFactor = occlusionAmount / coneWidth;
        occlusionFactor *= 1.0 - (i / 10.0);
        occlusion = max(occlusion, occlusionFactor);
        eps *= 2.0;
        point += normal * eps;
    }
    return max(0.0, 1.0 - occlusion);
}

METAL_FUNC float calculateReflection(vec3 point, vec3 lightDir, vec3 cam, vec3 normal, float specular) {
    vec3 viewDir = normalize(cam - point);
    vec3 reflection = reflect(viewDir, normal);
    float result = pow(max(dot(reflection, lightDir), 0.0), specular) * specular;
    return result;
}

METAL_FUNC vec3 calculateColor(vec3 point, SDFResult sdf, vec3 cam, SDFResult (*sdfScene)(vec3), float time) {
    vec3 lightDir = normalize(vec3(sin(time), -0.5, cos(time)));
    vec3 normal = calculateNormal(point, sdfScene);
    
        // Base lighting calculation
    float ambient = 0.3;
    float diffuse = max(dot(normal, lightDir), 0.0) * 2.0;
    float shadow = softShadow(point + normal * 0.01, lightDir, .9, sdfScene);
    float ao = calculateAO(point, normal, sdfScene);
    
    vec3 color = sdf.diffuse * (ambient * ao + diffuse * shadow);
    
    float reflection = calculateReflection(point, lightDir, cam, normal, sdf.specular);
    
    color += reflection * (shadow - 0.1);;
    
    return color;
}

METAL_FUNC Ray castRay(vec2 uv, vec3 cam) {
    vec3 rayOrigin = cam;
    vec3 rayDirection = normalize(vec3(uv - 0.5, 1.0)); // Simple perspective projection
    
        // Calculate and apply camera transform in one step
    mat4 cameraMatrix = lookAt(cam, float3(0.0), float3(0.0, 1.0, 0.0));
    rayDirection = (cameraMatrix * float4(rayDirection, 0.0)).xyz;
    
    return {
        .origin = rayOrigin,
        .dir = rayDirection
    };
}

METAL_FUNC vec4 rayIntersection(Ray ray, float maxDist, SDFResult (*sdfScene)(vec3)) {
    SDFResult sdf;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        sdf = sdfScene(ray.origin);
        if (sdf.distance < DISTANCE_THRESHOLD) { break; }
        if (sdf.distance > maxDist) { break; }
        ray.origin += ray.dir * sdf.distance;
    }
    
    return vec4(sdf.distance, ray.origin);
}

METAL_FUNC vec4 raymarch(Ray ray, float maxDist, float time, SDFResult (*sdfScene)(vec3)) {
    SDFResult sdf;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        sdf = sdfScene(ray.origin);
        if (sdf.distance < DISTANCE_THRESHOLD) { break; }
        if (sdf.distance > maxDist) { break; }
        ray.origin += ray.dir * sdf.distance;
    }
    
    vec4 resColor = vec4(vec3(0.0), 0.0);
    if (sdf.distance < 0.01) {
        resColor = vec4(1, 0, 0, 1);
        resColor.rgb = calculateColor(ray.origin, sdf, ray.dir, sdfScene, time);
        resColor.a = 1;
    } else {
        resColor.rgb = normalize(ray.dir);
        resColor.a = 0.0;
    }
    return resColor;
}

#endif /* Raymarchin_Lighting_h */
