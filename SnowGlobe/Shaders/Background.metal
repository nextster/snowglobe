// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "Shared.h"
#include <metal_stdlib>

using namespace metal;

float chessPattern(float2 uv, float size) {
    float xPattern = floor(uv.x * size);
    float yPattern = floor(uv.y * size);
    float patternSum = xPattern + yPattern;
    return fmod(patternSum, 2.0);
}

kernel void background(texture2d<float, access::write> output [[texture(0)]],
                         constant Uniforms & uniforms [[ buffer(0) ]],
                         uint2 gid [[thread_position_in_grid]]) {
    int width = output.get_width();
    int height = output.get_height();
    float2 pos = float2(gid);
    float2 uv = pos / float2(width, height);
    
    vec4 outputColor;
    outputColor = vec4(1,0,0,1);
//    outputColor = vec4(uniforms.color, 1);
//    outputColor = vec4(uv.x,0,0,1);
//    outputColor = vec4(uv.x,uv.y,0,1);
//    outputColor = chessPattern(uv, 10);
    
    output.write(outputColor, gid);
}
