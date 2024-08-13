#version 300 es

precision highp float;
precision highp sampler2D;

in vec2 texCoord;
out vec4 fragColor;

uniform sampler2D src;

vec2 u(ivec2 coord)
{
    return (texelFetch(src, coord, 0).xy);
}

void main()
{
    ivec2 pixelCoord = ivec2(floor(gl_FragCoord.xy));

    if(pixelCoord.x <= 0
       || pixelCoord.x >= textureSize(src, 0).x
       || pixelCoord.y <= 0
       || pixelCoord.y >= textureSize(src, 0).y)
    {
        fragColor = vec4(0, 0, 0, 1);
    }
    else
    {
        vec2 tl = u(pixelCoord + ivec2(-1, 0));
        vec2 tr = u(pixelCoord);
        vec2 bl = u(pixelCoord + ivec2(-1, -1));
        vec2 br = u(pixelCoord + ivec2(0, -1));

        float r = (tr.x + br.x) / 2.;
        float l = (tl.x + bl.x) / 2.;
        float t = (tl.y + tr.y) / 2.;
        float b = (bl.y + br.y) / 2.;

        fragColor = vec4(-2. * (r - l + t - b), 0, 0, 1);
    }
}
