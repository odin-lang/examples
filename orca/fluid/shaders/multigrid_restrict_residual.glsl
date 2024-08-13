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

float residual(ivec2 coord)
{
    ivec2 vr = coord + ivec2(1, 0);
    ivec2 vl = coord - ivec2(1, 0);
    ivec2 vt = coord + ivec2(0, 1);
    ivec2 vb = coord - ivec2(0, 1);

    return ((x(vl) + x(vr) + x(vt) + x(vb) + b(coord) - 4. * x(coord)) * 4.);
}

void main()
{
    ivec2 pixelCoord = ivec2(floor(gl_FragCoord.xy));

    float restricted = residual(2 * pixelCoord + ivec2(-1, -1))
                     + residual(2 * pixelCoord + ivec2(1, -1))
                     + residual(2 * pixelCoord + ivec2(1, 1))
                     + residual(2 * pixelCoord + ivec2(-1, 1))
                     + 2. * residual(2 * pixelCoord + ivec2(-1, 0))
                     + 2. * residual(2 * pixelCoord + ivec2(1, 0))
                     + 2. * residual(2 * pixelCoord + ivec2(0, -1))
                     + 2. * residual(2 * pixelCoord + ivec2(0, 1))
                     + 4. * residual(2 * pixelCoord);
    restricted /= 16.;
    fragColor = vec4(restricted, 0, 0, 1);
}
