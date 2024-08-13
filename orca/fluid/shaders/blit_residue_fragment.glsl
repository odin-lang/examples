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

vec3 color_map(float v)
{
    float logv = log(abs(v)) / log(10.0);
    float f = floor(logv + 7.0);
    float i = floor(4.0 * (logv + 7.0 - f));

    if(f < 0.0)
        return vec3(0.0);
    if(f < 1.0)
        return mix(vec3(1.0, 0.0, 0.0), vec3(1.0), i / 4.0);
    if(f < 2.0)
        return mix(vec3(0.0, 1.0, 0.0), vec3(1.0), i / 4.0);
    if(f < 3.0)
        return mix(vec3(0.0, 0.0, 1.0), vec3(1.0), i / 4.0);
    if(f < 4.0)
        return mix(vec3(1.0, 1.0, 0.0), vec3(1.0), i / 4.0);
    if(f < 5.0)
        return mix(vec3(1.0, 0.0, 1.0), vec3(1.0), i / 4.0);
    if(f < 6.0)
        return mix(vec3(0.0, 1.0, 1.0), vec3(1.0), i / 4.0);
    if(f < 7.0)
        return mix(vec3(1.0, 0.5, 0.0), vec3(1.0), i / 4.0);
    if(f < 8.0)
        return mix(vec3(1.0, 1.0, 1.0), vec3(1.0), i / 4.0);
    return vec3(1.0);
}

void main()
{
    ivec2 pixelCoord = ivec2(floor(texCoord.xy * vec2(textureSize(xTex, 0).xy)));

    float tl = x(pixelCoord + ivec2(-1, 1));
    float tr = x(pixelCoord + ivec2(1, 1));
    float bl = x(pixelCoord + ivec2(-1, -1));
    float br = x(pixelCoord + ivec2(1, -1));

    float residue = b(pixelCoord) - (-tl - tr - bl - br + 4. * x(pixelCoord));
    fragColor = vec4(color_map(residue), 1);
}
