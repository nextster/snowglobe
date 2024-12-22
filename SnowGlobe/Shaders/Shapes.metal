// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "Shared.h"
#import "SDFFunctions.h"

#include <metal_stdlib>

using namespace metal;

#define SPHERE_RAD 0.4

METAL_FUNC float2 squarifyUV(float2 uv, float aspect) {
    uv.y -= 0.5;
    uv.y /= aspect;
    uv.y += 0.5;
    return uv;
}

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
    treeTopResult.specular = 2;
    treeTopResult.roughness = 0.5;
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
    ball.roughness = 5.0;
//    return unionSDFsmooth(cap, ball, 0.003);
    return ball;
}

// MARK: Scene
METAL_FUNC SDFResult scene(vec3 point) {
    SDFResult ground = groundShape(point);
//    vec3 giftPoint = point;
//    giftPoint.y -= SPHERE_RAD * 0.2;
//    giftPoint.x += SPHERE_RAD * 0.25;
//    giftPoint.z -= SPHERE_RAD * 0.45;
//    giftPoint.xz = rot2d(giftPoint.xz, 0.35);
//    SDFResult gift = giftShape(giftPoint);
//    
//    vec3 threePoint = point;
//    threePoint.x -= SPHERE_RAD * 0.35;
//    SDFResult tree = treeShape(threePoint);
    
    vec3 ballPoint = point;
//    ballPoint.y -= SPHERE_RAD * 0.1;
//    ballPoint.xz += SPHERE_RAD * 0.35;
    SDFResult ball = ballShape(ballPoint);
//    return unionSDF(ball, ground);
    return ball;
    
//    SDFResult result = unionSDF(ground, gift);
//    result = unionSDF(result, tree);
//    result = unionSDF(result, ball);

//    return result;
}
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

METAL_FUNC vec4 raymarch(Ray ray, vec3 cam) {
    SDFResult sdf;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        sdf = scene(ray.pos);
        
        if (sdf.distance < DISTANCE_THRESHOLD) { break; }
        if (sdf.distance > length(cam)) { break; }
        ray.pos += ray.dir * sdf.distance;
    }
    
    vec4 resColor = vec4(vec3(0.0), 0.0);
    if (sdf.distance < DISTANCE_THRESHOLD) {
        resColor.rgb = sdf.diffuse;
        resColor.a = 1;
    } else {
        resColor.rgb = normalize(ray.dir);
        resColor.a = 0.0;
    }
    return resColor;
}

kernel void shapes(texture2d<float, access::write> output [[texture(0)]],
                         constant Uniforms & uniforms [[ buffer(0) ]],
                         uint2 gid [[thread_position_in_grid]]) {
    int width = output.get_width();
    int height = output.get_height();
    float2 pos = float2(gid);
    float2 uv = pos / float2(width, height);
    uv = squarifyUV(uv, uniforms.aspect);
    
    vec3 cam = vec3(sin(uniforms.time), -0.25, cos(uniforms.time));
    Ray ray = castRay(uv, cam);
    vec4 sceneColor = raymarch(ray, cam);
    output.write(sceneColor, gid);
}
