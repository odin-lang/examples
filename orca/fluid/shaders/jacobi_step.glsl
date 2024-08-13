#version 300 es

precision highp float;
precision highp sampler2D;

in vec2 texCoord;
out vec4 fragColor;

uniform sampler2D xTex;
uniform sampler2D bTex;

float x(ivec2 coord)
{
    if(coord.x <= 0
       || coord.x >= textureSize(xTex, 0).x
       || coord.y <= 0
       || coord.y >= textureSize(xTex, 0).y)
    {
        return (0.);
    }
    return (texelFetch(xTex, coord, 0).x);
}

float b(ivec2 coord)
{
    if(coord.x <= 0
       || coord.x >= textureSize(bTex, 0).x
       || coord.y <= 0
       || coord.y >= textureSize(bTex, 0).y)
    {
        return (0.);
    }
    return (texelFetch(bTex, coord, 0).x);
}

void main()
{
    ivec2 pixelCoord = ivec2(floor(gl_FragCoord.xy));

    if(pixelCoord.x <= 0
       || pixelCoord.y <= 0)
    {
        fragColor = vec4(0, 0, 0, 1);
    }
    else
    {
        float tl = x(pixelCoord + ivec2(-1, 1));
        float tr = x(pixelCoord + ivec2(1, 1));
        float bl = x(pixelCoord + ivec2(-1, -1));
        float br = x(pixelCoord + ivec2(1, -1));

        float jacobi = (tl + tr + bl + br + b(pixelCoord)) / 4.;
        fragColor = vec4(jacobi, 0, 0, 1);
    }
}
