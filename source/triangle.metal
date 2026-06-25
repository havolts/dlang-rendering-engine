#include <metal_stdlib>
using namespace metal;

struct VertexData {
    packed_float4 position;
    packed_float4 color;
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
    float4 color;
};

struct TransformationData {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 perspectiveMatrix;
};




vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
             constant VertexData* vertexData,
             constant TransformationData* transformationData)
{
    VertexOut out;
    out.position = transformationData->perspectiveMatrix * transformationData->viewMatrix * transformationData->modelMatrix * float4(vertexData[vertexID].position);
    out.color = float4(vertexData[vertexID].color);
    return out;
}


fragment float4 fragmentShader(VertexOut input [[stage_in]])
{
    return input.color;
}
