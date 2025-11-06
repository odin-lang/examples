struct PSInput
{
    float2 uv    : TEXCOORD0; 
};

struct PSOutput
{
    float4 color : SV_Target;
};

Texture2D tex          : register(t0);
SamplerState tex_sampl : register(s0);

PSOutput main(PSInput input)
{
    PSOutput output;
    output.color = tex.Sample(tex_sampl, input.uv);
    return output;
}