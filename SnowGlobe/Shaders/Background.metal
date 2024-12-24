// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "Shared.h"
//#import "CommonFunctions.h"

#include <metal_stdlib>

using namespace metal;

float chessPattern(float2 uv, float size) {
    return fmod(floor(uv.x * size) + floor(uv.y * size), 2.0);
}

kernel void background(texture2d<float, access::write> output [[texture(0)]],
                         constant Uniforms & uniforms [[ buffer(0) ]],
                         uint2 gid [[thread_position_in_grid]]) {
    int width = output.get_width();
    int height = output.get_height();
    float2 pos = float2(gid);
    float2 uv = pos / float2(width, height);
//    uv = squarifyUV(uv, uniforms.aspect);
    
//    float2 center = float2(0.5, 0.5);
//    float2 vec = uv - center;
    vec4 outputColor = chessPattern(uv, 10);
//    vec4 outputColor = vec4(uv.x,uv.y,0,1);
//    vec4 outputColor = vec4(uv.x,0,0,1);

    output.write(outputColor, gid);
}
