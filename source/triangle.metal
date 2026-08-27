#include <metal_stdlib>
using namespace metal;

struct VertexData
{
    packed_float4 position;
    packed_float2 textureCoordinate;
    uint textureIndex;
};

struct VertexOut
{
    float4 position [[position]];
    float2 textureCoordinate;
    uint textureIndex [[flat]]; // flat = don't interpolate across the triangle
};

struct TransformationData
{
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 perspectiveMatrix;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]], constant VertexData* vertexData [[buffer(0)]], constant TransformationData* transformationData [[buffer(1)]])
{
    VertexOut out;
    out.position = transformationData->perspectiveMatrix * transformationData->viewMatrix * transformationData->modelMatrix * float4(vertexData[vertexID].position);
    out.textureCoordinate = vertexData[vertexID].textureCoordinate;
    out.textureIndex = vertexData[vertexID].textureIndex;
    return out;
}


fragment float4 fragmentShader(VertexOut in [[stage_in]], array<texture2d<float>, 3> textures [[texture(0)]])
{
    constexpr sampler textureSampler (mag_filter::nearest,min_filter::nearest);
    // Sample the texture to obtain a color
    const float4 colorSample = textures[in.textureIndex].sample(textureSampler, in.textureCoordinate);
    return colorSample;
}
