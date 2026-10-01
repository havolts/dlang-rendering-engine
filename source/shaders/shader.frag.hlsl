
Texture2D    texture  : register(t0, space2);
SamplerState sampler_ : register(s0, space2);

float4 main(float2 textureCoordinate : TEXCOORD0, nointerpolation uint textureIndex : TEXCOORD1) : SV_Target0
{
    return texture.Sample(sampler_, textureCoordinate);
}
