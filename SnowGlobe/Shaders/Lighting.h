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
    float eps = DISTANCE_THRESHOLD;
    float distAlongRay = eps * 10;
    
    for (int i = 0; i < 128; i++) {
        float3 samplePoint = point + lightDir * distAlongRay;
        float dist = sdfScene(samplePoint).distance;
        
        light = min(light, 1.0 - (eps - dist) / eps);
        
        distAlongRay += dist * 0.3;
        eps += dist * k;
        
        if (distAlongRay > lightDistance) {
            break;
        }
    }
    
    return max(light, 0.0);
}

METAL_FUNC float calculateAO(vec3 point, vec3 normal, SDFResult (*sdfScene)(vec3)) {
    float eps = 0.001;
    point += normal * eps * 5.0;
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
    float shadow = softShadow(point, lightDir, .9, sdfScene);
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
//    color = vec3(0,0,1) * shading + reflection * (shadow - 0.1);
//    color = sdf.diffuse * shading + reflection * (shadow - 0.1);
    
    return color;
}

#endif /* Lighting_h */
