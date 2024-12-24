// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "Shared.h"
#import "SDFFunctions.h"
#import "Raymarching.h"
#import "Lighting.h"
#import "CommonFunctions.h"

#include <metal_stdlib>

using namespace metal;

// MARK: Shapes
METAL_FUNC SDFResult groundShape(vec3 point) {
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
    treeTopResult.specular = 5;
    treeTopResult.roughness = 3;
    treeTopResult.uv *= 0.2;
    
    vec3 tp = point;
    tp.y -= SPHERE_RAD * 0.7;
    SDFResult trunk = cylinder(tp, SPHERE_RAD * 0.3, SPHERE_RAD * 0.07);
    trunk.diffuse = vec3(0.57, 0.41, 0.35);
    
    return unionSDF(treeTopResult, trunk);
}

METAL_FUNC SDFResult ballShape(vec3 point) {
    float rad = SPHERE_RAD * 0.375;
    float capRad = SPHERE_RAD * 0.07;
    vec3 capPoint = rotate3d(point, -0.1) + vec3(0,rad,0);
    SDFResult cap = cylinder(capPoint, capRad, capRad);
    cap = unionSDFsmooth(cap, cylinder(capPoint, capRad * 2, capRad * 0.3), 0.01);
    cap.diffuse = vec3(0.85);
    cap.specular = 10.0;
    SDFResult ball = sphere(point, rad);
    ball.diffuse = vec3(0.00384, 0.29412, 0.4);
    ball.uv *= 2;
    ball.specular = 0.5;
    ball.roughness = 5.0;
    return unionSDFsmooth(cap, ball, 0.003);
    return cap;
}

// MARK: Scene
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
    SDFResult tree = treeShape(threePoint);
    
    vec3 ballPoint = point;
    ballPoint.y -= SPHERE_RAD * 0.1;
    ballPoint.xz += SPHERE_RAD * 0.35;
    SDFResult ball = ballShape(ballPoint);
    
    SDFResult result = unionSDF(ground, gift);
    result = unionSDF(result, tree);
    result = unionSDF(result, ball);

    return result;
}

METAL_FUNC SDFResult sphereScene(vec3 point) {
    return sphere(point, SPHERE_RAD);
}

METAL_FUNC vec4 background(vec3 ray) {
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

kernel void drawScene(texture2d<float, access::write> output [[texture(0)]],
                         constant Uniforms & uniforms [[ buffer(0) ]],
                         uint2 gid [[thread_position_in_grid]]) {
    int width = output.get_width();
    int height = output.get_height();
    float2 pos = float2(gid);
    float2 uv = pos / float2(width, height);
    uv = squarifyUV(uv, uniforms.aspect);
    vec3 cam = vec3(sin(uniforms.time), -0.25, cos(uniforms.time));
    Ray ray = castRay(uv, cam);
    vec4 sphereIntersection = rayIntersection(ray, cam, sphereScene);
    
    if (sphereIntersection.w < DISTANCE_THRESHOLD) {
        vec3 sphereNormal = normalize(sphereIntersection.xyz);
        vec3 refractedRayDir = refract(ray.dir, sphereNormal, 1 / 1.05);
        Ray refractedRay;
        refractedRay = ray;
//        refractedRay = { sphereIntersection.yzw, refractedRayDir };
        float lightTime = -uniforms.time * 3;
        vec3 lightDir = normalize(vec3(cos(lightTime), -0.5, sin(lightTime)));

        vec4 sphereColor = raymarch(refractedRay, cam, lightDir, innerScene);
        if (sphereColor.a == 0.0) {
            sphereColor = background(sphereColor.rgb);
        }

        float specular = calculateReflection(sphereIntersection.xyz, lightDir, cam, sphereNormal, 50);
//        sphereColor += specular;
        output.write(sphereColor, gid);
    } else {
        vec4 bg = background(ray.dir);
        output.write(bg, gid);
    }
}
