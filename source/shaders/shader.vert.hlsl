
struct VertexIn
{
    float4 position : TEXCOORD0;
    float2 textureCoordinate : TEXCOORD1;
    uint textureIndex : TEXCOORD2;
};

struct VertexOut
{
    float4 position : SV_Position;
    float2 textureCoordinate : TEXCOORD0;
    uint textureIndex : TEXCOORD1;
};

cbuffer TransformationData : register(b0, space1)
{
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 perspectiveMatrix;
};

VertexOut main(VertexIn input)
{
    VertexOut output;
    output.position = mul(perspectiveMatrix,
                     mul(viewMatrix,
                     mul(modelMatrix, input.position)));
    output.textureCoordinate = input.textureCoordinate;
    output.textureIndex = input.textureIndex;
    return output;
}
