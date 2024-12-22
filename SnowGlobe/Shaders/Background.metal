// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "Shared.h"
#import "CommonFunctions.h"

#include <metal_stdlib>

using namespace metal;

kernel void background(texture2d<float, access::write> output [[texture(0)]],
                         constant Uniforms & uniforms [[ buffer(0) ]],
                         uint2 gid [[thread_position_in_grid]]) {
    int width = output.get_width();
    int height = output.get_height();
    float2 pos = float2(gid);
    float2 uv = pos / float2(width, height);
    uv = squarifyUV(uv, uniforms.aspect);
    
//    float2 center = float2(0.5, 0.5);
//    float2 vec = uv - center;
    vec4 outputColor = (fmod(floor(uv.x * 8.0) + floor(uv.y * 8.0), 2.0) == 0) ? vec4(1.0, 1.0, 1.0, 1.0) : vec4(0.0, 0.0, 0.0, 1.0);

    output.write(outputColor, gid);
}
