// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "Shared.h"
#import "SDFFunctions.h"
#import "Raymarching+Lighting.h"
#import "CommonFunctions.h"

#include <metal_stdlib>

using namespace metal;

METAL_FUNC SDFResult groundShape(vec3 point) {
//    float att = 0.003;
//    point.y += sin(point.x * 10.0) * att;
//    point.y += cos(point.z * 10.0) * att;
    return {
        .distance = cutSphere(point, SPHERE_RAD, SPHERE_RAD * 0.4),
        .diffuse = vec3(1),
        .specular = 0.4,
        .roughness = 1,
        .uv = (point.xz + 0.5) * 3
    };
}

METAL_FUNC SDFResult giftShape(vec3 point) {
    SDFResult box = roundBox(point, SPHERE_RAD * 0.2, 0.005);
    box.diffuse = vec3(1, 0, 0);
    box.specular = 0.7;
    box.roughness = 2.5;
    box.uv *= 0.5;
    
    float ribbonHeight = SPHERE_RAD * 0.205;
    float ribbonWidth = SPHERE_RAD * 0.05;
    
    SDFResult ribbon1 = roundBox(point, vec3(ribbonWidth, ribbonHeight, ribbonHeight), 0.005);
    SDFResult ribbon2 = roundBox(point, vec3(ribbonHeight, ribbonHeight + 0.002, ribbonWidth), 0.005);
    
    SDFResult ribbon = unionSDF(ribbon1, ribbon2);
    ribbon.diffuse = vec3(1, 1, 0);
    ribbon.specular = 5;
    ribbon.roughness = 5;
    
    return unionSDF(box, ribbon);
}

METAL_FUNC SDFResult treeShape(vec3 point) {
    point.y += SPHERE_RAD * 0.5;
    
    vec3 p3 = point;
    p3.y += SPHERE_RAD * 0.15;
    
    SDFResult c3 = cone(p3, SPHERE_RAD * 0.22, SPHERE_RAD * 0.35);
    
    vec3 p1 = point;
    p1.y -= SPHERE_RAD * 0.05;
    SDFResult c1 = cone(p1, SPHERE_RAD * 0.29, SPHERE_RAD * 0.45);
    
    vec3 p2 = point;
    p2.y -= SPHERE_RAD * 0.3;
    SDFResult c2 = cone(p2, SPHERE_RAD * 0.35, SPHERE_RAD * 0.5);
    
    SDFResult treeTopResult = unionSDF(unionSDF(c1, c2), c3);
    treeTopResult.diffuse = vec3(0.0, 0.27, 0.157);
    treeTopResult.specular = 2;
    treeTopResult.roughness = 0.5;
    treeTopResult.uv *= 0.2;
    
    vec3 tp = point;
    tp.y -= SPHERE_RAD * 0.7;
    SDFResult trunk = cylinder(tp, SPHERE_RAD * 0.3, SPHERE_RAD * 0.07);
    trunk.diffuse = vec3(0.57, 0.41, 0.35);
    
//    return trunkResult;
    return unionSDF(treeTopResult, trunk);
}

METAL_FUNC SDFResult ballShape(vec3 point) {
    float rad = SPHERE_RAD * 0.375;
    float capRad = SPHERE_RAD * 0.07;
    vec3 capPoint = rotate3d(point, -0.1) + vec3(0,rad,0);
    SDFResult cap = cylinder(capPoint, capRad, capRad);
    cap = unionSDFsmooth(cap, cylinder(capPoint, capRad * 2, capRad * 0.3), 0.01);
    cap.diffuse = vec3(0.85);
//    cap.roughness = 0.5;
    cap.specular = 10.0;
    SDFResult ball = sphere(point, rad);
    ball.diffuse = vec3(0.00384, 0.29412, 0.4);
    ball.uv *= 2;
    ball.roughness = 5.0;
    return unionSDFsmooth(cap, ball, 0.003);
    return cap;
}

METAL_FUNC SDFResult innerScene(vec3 point) {
    SDFResult ground = groundShape(point);
    vec3 giftPoint = point;
    giftPoint.y -= SPHERE_RAD * 0.2;
    giftPoint.x += SPHERE_RAD * 0.25;
    giftPoint.z -= SPHERE_RAD * 0.45;
    giftPoint.xz = rot2d(giftPoint.xz, 0.35);
    SDFResult gift = giftShape(giftPoint);
    
    vec3 threePoint = point;
    threePoint.x -= SPHERE_RAD * 0.35;
//    threePoint.z += SPHERE_RAD * 0.1;
    SDFResult tree = treeShape(threePoint);
    
    vec3 ballPoint = point;
    ballPoint.y -= SPHERE_RAD * 0.1;
    ballPoint.xz += SPHERE_RAD * 0.35;
//    ballPoint.z -= SPHERE_RAD * 0.25;
    SDFResult ball = ballShape(ballPoint);
    
    SDFResult result = unionSDF(ground, gift);
    result = unionSDF(result, tree);
    result = unionSDF(result, ball);
    
//    float3 n = fbm3d(point * 10.4) * 0.001;
//    result.distance = intersectionSDF(result.distance, length(n));
//    result.distance = length(n);

    return result;
}

SDFResult sphereScene(vec3 point) {
    return sphere(point, SPHERE_RAD);
}


vec4 generateStars(vec3 ray) {
    vec2 uv = ray.xy;
    
    if (abs(ray.x) > 0.5)
        uv.x = ray.z;
    else if (abs(ray.y) > 0.5)
        uv.y = ray.z;
    float brightness = valueNoise(uv * 3.0, 100.0);
    float colorFactor = valueNoise(uv * 2.0, 20.0);
    brightness = pow(brightness, 256.0) * 100.0;
    brightness = clamp(brightness, 0.0, 1.0);
    
    vec3 starsColor = brightness * mix(
                                       vec3(1.0, 0.6, 0.2),
                                       vec3(0.2, 0.6, 1.0),
                                       colorFactor
                                       );
    return vec4(starsColor, 1.0);
}

vec4 background(vec3 rayDir) {
    float2 uv = rayDir.xy * 0.5 + 0.5;
    float3 noise = fbm(uv * 10.0);
    vec3 iridescence = vec3(0.5) + 0.5 * cos(noise * 10.0 + vec3(0.0, 2.0, 4.0));
    vec4 color = vec4(mix(vec3(1.0), iridescence, noise), 1.0);
    return color;
}

float calculateFresnel(vec3 normal, vec3 viewDir, float F0) {
        // Compute the cosine of the angle between the normal and the view direction
    float cosTheta = clamp(dot(normalize(normal), normalize(viewDir)), 0.0, 1.0);
        // Apply the Schlick approximation formula
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

kernel void glassSphere(texture2d<float, access::write> output [[texture(0)]],
//                       texture2d<float, access::sample> background [[texture(1)]],
//                       texture2d<float, access::sample> innerShape [[texture(2)]],
                         constant Uniforms & uniforms [[ buffer(0) ]],
                         uint2 gid [[thread_position_in_grid]]) {
    int width = output.get_width();
    int height = output.get_height();
    float2 pos = float2(gid);
    float2 uv = pos / float2(width, height);
    uv = squarifyUV(uv, uniforms.aspect);
//    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);
//    float2 center = float2(0.5, 0.5);
//    float2 vec = uv - center;
    vec3 cam = vec3(sin(uniforms.time), -0.25, cos(uniforms.time));
//    vec3 cam = vec3(0, -0.25, 1);
    Ray ray = castRay(uv, cam);
    float maxDist = length(cam);
    vec4 sphereIntersection = rayIntersection(ray, maxDist, sphereScene);
    if (sphereIntersection.x < DISTANCE_THRESHOLD) {
        vec3 normal = calculateNormal(sphereIntersection.yzw, sphereScene);
        vec3 refractedRayDir = refract(ray.dir, normal, 1 / 1.05);
        Ray refractedRay = { sphereIntersection.yzw, refractedRayDir };
        vec3 lightDir = normalize(vec3(cos(-uniforms.time * 3), 0.5, sin(-uniforms.time * 3)));

        vec4 refractedColor = raymarch(refractedRay, maxDist, uniforms.time * 3, innerScene);
        if (refractedColor.a == 0.0) {
//            Ray refractAgain = refractedRay;
//            refractAgain.dir = refract(refractAgain.dir, -normal, 1/1.333);
            refractedColor = generateStars(refractedColor.rgb);
//            refractedColor = vec4(1,0,0,1);
        }
        float fresnel = calculateFresnel(normal, -ray.dir, 0.25);
        float specular = calculateReflection(sphereIntersection.yzw, lightDir, cam, normal, 50);
        specular = saturate(specular);
        refractedColor += specular * fresnel;
        output.write(refractedColor, gid);
    } else {
        vec4 bg = generateStars(ray.dir);
//        vec4 bg = vec4(1,0,0,1);
        output.write(bg, gid);
        // output.write(background.sample(s, uv), gid);
    }

}
