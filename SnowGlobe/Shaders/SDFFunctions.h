#ifndef SDFFunctions_h
#define SDFFunctions_h

#include <metal_stdlib>

using namespace metal;

// SDF
template <typename T>
METAL_FUNC T unionSDF(T d1, T d2) {
    return min(d1, d2);
}

template <typename T>
METAL_FUNC T intersectionSDF(T d1, T d2) {
    return max(d1, d2);
}

template <typename T>
METAL_FUNC T differenceSDF(T d1, T d2) {
    return max(d1, -d2);
}

template <typename T>
METAL_FUNC T smoothUnion(T d1, T d2, T k) {
    T h = clamp(0.5 + 0.5 * (d2 - d1) / k, T(0.0), T(1.0));
    return mix(d2, d1, h) - k * h * (T(1.0) - h);
}

template <typename T>
METAL_FUNC T smoothIntersection(T d1, T d2, T k) {
    T h = clamp(0.5 - 0.5 * (d2 - d1) / k, T(0.0), T(1.0));
    return mix(d2, d1, h) + k * h * (T(1.0) - h);
}

float2 rot2d(float2 pos, float rotation) {
    half angle = rotation * M_PI_H * 2 * -1;
    half sine = sin(angle);
    half cosine = cos(angle);
    return float2(cosine * pos.x + sine * pos.y,
                 cosine * pos.y - sine * pos.x);
}

float2 translate2d(float2 pos, float2 translation) {
    return pos + translation;
}

float2 scale2d(float2 pos, half scale) {
    return pos / scale;
}

float3 rotate3d(float3 pos, float3 rotation) {
    float3x3 rotX = float3x3(
        float3(1.0, 0.0, 0.0),
        float3(0.0, cos(rotation.x), -sin(rotation.x)),
        float3(0.0, sin(rotation.x), cos(rotation.x))
    );
    
    float3x3 rotY = float3x3(
        float3(cos(rotation.y), 0.0, sin(rotation.y)),
        float3(0.0, 1.0, 0.0),
        float3(-sin(rotation.y), 0.0, cos(rotation.y))
    );
    
    float3x3 rotZ = float3x3(
        float3(cos(rotation.z), -sin(rotation.z), 0.0),
        float3(sin(rotation.z), cos(rotation.z), 0.0),
        float3(0.0, 0.0, 1.0)
    );
    
    return (rotZ * rotY * rotX) * pos;
}

float4x4 lookAt(float3 eye, float3 target, float3 up) {
    float3 zAxis = normalize(target - eye);
    float3 xAxis = normalize(cross(up, zAxis));
    float3 yAxis = cross(zAxis, xAxis);
    
    return float4x4(
                    float4(xAxis, 0.0),
                    float4(yAxis, 0.0),
                    float4(zAxis, 0.0),
                    float4(eye, 1.0)
                    );
}

struct SDFResult {
    float distance;
    vec3 diffuse;
    float specular;
    float roughness;
    vec2 uv;
};

METAL_FUNC SDFResult unionSDF(SDFResult l, SDFResult r) {
    return (l.distance < r.distance) ? l : r;
}

METAL_FUNC SDFResult unionSDFsmooth(SDFResult l, SDFResult r, float k) {
    float h = smoothstep(k, -k, l.distance - r.distance);
    SDFResult result;
    result.distance = mix(r.distance, l.distance, h) - k * h * (1.0 - h);
    result.diffuse = mix(r.diffuse, l.diffuse, h);
    result.specular = mix(r.specular, l.specular, h);
    result.roughness = mix(r.roughness, l.roughness, h);
    result.uv = mix(r.uv, l.uv, h);
    return result;
}


SDFResult cone(vec3 point, float radius, float height) {
        // Calculate sin/cos of cone angle from radius and height
    float angle = atan(radius / height);
    vec2 c = vec2(sin(angle), cos(angle));
    
        // Calculate q vector
    vec2 q = height * vec2(c.x / c.y, 1.0);
    
        // Convert point to 2D working space
    vec2 w = vec2(length(point.xz), point.y);
    
        // Calculate closest points
    vec2 a = w - q * clamp(dot(w, q) / dot(q, q), 0.0, 1.0);
    vec2 b = w - q * vec2(clamp(w.x / q.x, 0.0, 1.0), 1.0);
    
    float k = sign(q.y);
    float d = min(dot(a, a), dot(b, b));
    float s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
    
        // Calculate UV coordinates for the cone
    float u = atan2(point.z, point.x) / (2.0 * M_PI_F) + 0.5;
    float v = (point.y + height) / (2.0 * height);
    
    return {
        .distance = sqrt(d) * sign(s),
        .uv = vec2(u, v)
    };
}

SDFResult roundCone(vec3 point, float r1, float r2, float h)
{
        // sampling independent computations (only depend on shape)
    float b = (r1-r2)/h;
    float a = sqrt(1.0-b*b);
    
        // sampling dependant computations
    vec2 q = vec2( length(point.xz), point.y );
    float k = dot(q,vec2(-b,a));
    float distance;
    if( k<0.0 ) {
        distance = length(q) - r1;
    } else if( k>a*h ) {
        distance = length(q-vec2(0.0,h)) - r2;
    } else {
        distance = dot(q, vec2(a,b) ) - r1;
    }
    
    // Calculate UV coordinates for the cone
    float u = atan2(point.z, point.x) / (2.0 * M_PI_F) + 0.5;
    float v = (point.y + h) / (2.0 * h);
    
    return {
        .distance = distance,
        .uv = vec2(u, v)
    };
}

SDFResult roundBox(vec3 point, vec3 size, float rad)
{
    vec3 q = abs(point) - size + rad;
    vec3 uvw = point / (2.0 * size) + 0.5;
    
    // Calculate UV coordinates based on the box's surface
    vec2 uv;
    if (q.x > q.y && q.x > q.z) {
        uv = vec2(uvw.y, uvw.z); // UV mapping for the x face
    } else if (q.y > q.x && q.y > q.z) {
        uv = vec2(uvw.x, uvw.z); // UV mapping for the y face
    } else {
        uv = vec2(uvw.x, uvw.y); // UV mapping for the z face
    }
    
    return {
        .distance = length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - rad,
        .uv = uv
    };
}

SDFResult sphere(vec3 point, float radius) {
    return {
        .distance = length(point) - radius,
        .uv = vec2(atan2(point.z, point.x) / (2.0 * M_PI_F) + 0.5, (point.y + radius) / (2.0 * radius))
    };
}

SDFResult cylinder(vec3 point, float height, float radius)
{
    vec2 d = abs(vec2(length(point.xz),point.y)) - vec2(radius,height);
    float distance = min(max(d.x,d.y),0.0) + length(max(d,0.0));
    
    // Calculate UV coordinates for the cylinder
    float u = atan2(point.z, point.x) / (2.0 * M_PI_F) + 0.5;
    float v = (point.y + height) / (2.0 * height);
    
    return {
        .distance = distance,
        .uv = vec2(u, v)
    };
}

float cutSphere(vec3 point, float rad, float height)
{
        // sampling independent computations (only depend on shape)
    float w = sqrt(rad*rad-height*height);
    
        // sampling dependant computations
    vec2 q = vec2( length(point.xz), point.y );
    float s = max( (height-rad)*q.x*q.x+w*w*(height+rad-2.0*q.y), height*q.x-w*q.y );
    return (s<0.0) ? length(q)-rad :
    (q.x<w) ? height - q.y     :
    length(q-vec2(w,height));
}
#endif /* SDFFunctions_h */
