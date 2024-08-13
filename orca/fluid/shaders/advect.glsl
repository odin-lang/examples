#version 300 es

precision highp float;
precision highp sampler2D;

in vec2 texCoord;
out vec4 fragColor;

uniform sampler2D src;
uniform sampler2D velocity;
uniform float delta;
uniform float dissipation;

vec2 u(ivec2 coord)
{
    return (texelFetch(velocity, coord, 0).xy);
}

vec4 q(ivec2 coord)
{
    if(coord.x < 0
       || coord.x >= textureSize(src, 0).x
       || coord.y < 0
       || coord.y >= textureSize(src, 0).y)
    {
        return (vec4(0.));
    }
    return (texelFetch(src, coord, 0));
}

vec4 bilerpSrc(vec2 pos)
{
    vec2 offset = fract(pos);

    ivec2 bl = ivec2(floor(pos));

    ivec2 br = bl + ivec2(1, 0);
    ivec2 tl = bl + ivec2(0, 1);
    ivec2 tr = bl + ivec2(1, 1);

    vec4 lerpTop = (1. - offset.x) * q(tl) + offset.x * q(tr);
    vec4 lerpBottom = (1. - offset.x) * q(bl) + offset.x * q(br);
    vec4 result = (1. - offset.y) * lerpBottom + offset.y * lerpTop;

    return (result);
}

void main()
{
    float texWidth = float(textureSize(velocity, 0).x);

    ivec2 pixelCoord = ivec2(floor(gl_FragCoord.xy));

    vec2 samplePos = vec2(pixelCoord) - texWidth * delta * u(pixelCoord);
    fragColor = bilerpSrc(samplePos) / (1. + dissipation * delta);
}
