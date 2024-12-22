#ifndef Lighting_h
#define Lighting_h

#import "CommonFunctions.h"

#include <metal_stdlib>

using namespace metal;

#define DISTANCE_THRESHOLD 0.001
#define MAX_STEPS 128

METAL_FUNC vec3 calculateNormal(vec3 point, SDFResult (*sdfScene)(vec3)) {
    const float h = 0.0001;
    const vec2 k = vec2(1, -1);
    SDFResult res = sdfScene(point);
    vec3 normal = normalize(k.xyy * sdfScene(point + k.xyy * h).distance +
                            k.yyx * sdfScene(point + k.yyx * h).distance +
                            k.yxy * sdfScene(point + k.yxy * h).distance +
                            k.xxx * sdfScene(point + k.xxx * h).distance);
    if (res.uv.x > 0.0 || res.uv.y > 0.0) {
//        normal += fbm(res.uv * 200) * 0.1 * res.roughness;
        normal = normalize(normal);
    }
    return normal;
}

METAL_FUNC float softShadow(vec3 point, vec3 lightPos, float k, SDFResult (*sdfScene)(vec3)) {
    float3 lightDir = lightPos - point;
    float lightDistance = length(lightDir);
    lightDir = normalize(lightDir);
    
    float light = 1.0;
    float rad = 0.005;
    float distAlongRay = rad * 3;
    
    for (int i = 0; i < 128; i++) {
        float3 samplePoint = point + lightDir * distAlongRay;
        float dist = sdfScene(samplePoint).distance;
        
        light = clamp(light, 0.0, 1.0);
        light = min(light, 1.0 - (rad - dist) / rad);
        
        distAlongRay += dist * 0.5;
        rad += dist * k;
        
        if (distAlongRay > lightDistance) {
            break;
        }
    }
    
    return max(light, 0.0);
}

METAL_FUNC float calculateAO(vec3 point, vec3 normal, SDFResult (*sdfScene)(float3)) {
    float eps = 0.001;
    
    point += normal * eps * 5.0;
    float occlusion = 0.0;
    
    for (int i = 1; i < 16; i++) {
        float d = sdfScene(point).distance;
        float coneWidth = 2.0 * eps;
        float occlusionAmount = max(coneWidth - d, 0.0);
        float occlusionFactor = occlusionAmount / coneWidth;
        occlusionFactor *= 1.0 - (float(i) / 10.0);
        
        occlusion = max(occlusion, occlusionFactor);
        
        eps *= 1.5; // Adjust scaling for smoother results
        point += normal * eps;
    }
    return max(0.0, 1.0 - occlusion);
}

METAL_FUNC float calculateFresnel(vec3 normal, vec3 viewDir, float F0) {
        // Compute the cosine of the angle between the normal and the view direction
    float cosTheta = clamp(dot(normalize(normal), normalize(viewDir)), 0.0, 1.0);
        // Apply the Schlick approximation formula
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

METAL_FUNC float calculateReflection(vec3 point, vec3 lightDir, vec3 cam, vec3 normal, float specular) {
    vec3 viewDir = normalize(cam - point);
    vec3 reflection = reflect(-viewDir, normal);
    float result = pow(max(dot(reflection, lightDir), 0.0), specular);
    
    float f0 = clamp(1 / specular, 0.05, 1.0);
    float fresnel = calculateFresnel(normal, viewDir, f0);
    result = saturate(result) * fresnel;
    return result;
}

METAL_FUNC vec3 calculateColor(vec3 point, SDFResult sdf, vec3 cam, vec3 lightDir, SDFResult (*sdfScene)(vec3)) {
    vec3 normal = calculateNormal(point, sdfScene);
    
    // Base lighting calculation
    float ambient = 0.3;
    float diffuse = max(dot(normal, lightDir), 0.0);
    float shadow = softShadow(point, lightDir, .5, sdfScene);
    float ao = calculateAO(point, normal, sdfScene);
    float shading = (ambient * ao + diffuse * shadow);
    float reflection = calculateReflection(point, lightDir, cam, normal, sdf.specular);
    
    vec3 color;
    color = normal;
//    color = ambient;
//    color = diffuse;
//    color = shadow;
//    color = ao;
//    color = reflection;
//    color = shading + reflection * (shadow - 0.1);
//    color = vec3(0,0,1) * shading + reflection * shadow;
//    color = sdf.diffuse * shading + reflection * shadow;
    
    return color;
}

#endif /* Lighting_h */
