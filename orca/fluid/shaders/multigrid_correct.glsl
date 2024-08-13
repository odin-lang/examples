#version 300 es

precision highp float;
precision highp sampler2D;

in vec2 texCoord;
out vec4 fragColor;

uniform sampler2D src;
uniform sampler2D error;
uniform float invGridSize;

float e(ivec2 coord)
{
    if(coord.x <= 0
       || coord.x >= textureSize(error, 0).x
       || coord.y <= 0
       || coord.y >= textureSize(error, 0).y)
    {
        return (0.);
    }
    return (texelFetch(error, coord, 0).x);
}

float p(ivec2 coord)
{
    if(coord.x <= 0
       || coord.x >= textureSize(src, 0).x
       || coord.y <= 0
       || coord.y >= textureSize(src, 0).y)
    {
        return (0.);
    }
    return (texelFetch(src, coord, 0).x);
}

void main()
{
    ivec2 pixelCoord = ivec2(floor(gl_FragCoord.xy));
    vec2 coarseCoord = vec2(pixelCoord) / 2.;
    vec2 offset = fract(coarseCoord);

    ivec2 bl = ivec2(floor(coarseCoord));
    ivec2 br = bl + ivec2(1, 0);
    ivec2 tl = bl + ivec2(0, 1);
    ivec2 tr = bl + ivec2(1, 1);

    float topLerp = (1. - offset.x) * e(tl) + offset.x * e(tr);
    float bottomLerp = (1. - offset.x) * e(bl) + offset.x * e(br);
    float bilerpError = (1. - offset.y) * bottomLerp + offset.y * topLerp;

    fragColor = vec4(p(pixelCoord) + bilerpError, 0, 0, 1);
}
