#version 300 es

precision highp float;
precision highp sampler2D;

in vec2 texCoord;
out vec4 fragColor;

uniform sampler2D src;
uniform sampler2D pressure;
uniform float invGridSize;

vec2 u(ivec2 coord)
{
    return (texelFetch(src, coord, 0).xy);
}

float p(ivec2 coord)
{
    if(coord.x <= 0
       || coord.x >= textureSize(pressure, 0).x
       || coord.y <= 0
       || coord.y >= textureSize(pressure, 0).y)
    {
        return (0.);
    }
    return (texelFetch(pressure, coord, 0).x);
}

void main()
{
    ivec2 pixelCoord = ivec2(floor(gl_FragCoord.xy));

    float tl = p(pixelCoord + ivec2(0, 1));
    float tr = p(pixelCoord + ivec2(1, 1));
    float bl = p(pixelCoord);
    float br = p(pixelCoord + ivec2(1, 0));

    float r = (tr + br) / 2.;
    float l = (tl + bl) / 2.;
    float t = (tl + tr) / 2.;
    float b = (bl + br) / 2.;

    vec2 gradP = vec2(r - l, t - b);

    fragColor = vec4(u(pixelCoord) - gradP, 0, 1);
}
