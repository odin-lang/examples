#version 300 es

precision highp float;
precision highp sampler2D;

in vec2 texCoord;
out vec4 fragColor;

uniform sampler2D src;
uniform vec2 splatPos;
uniform vec3 splatColor;
uniform float radius;
uniform float additive;
uniform float blending;

uniform float randomize;

void main()
{
    float d2 = dot(texCoord - splatPos, texCoord - splatPos);
    float intensity = exp(-10. * d2 / radius);
    vec2 force = splatColor.xy;

    vec3 u = texture(src, texCoord).xyz;
    vec3 uAdd = u + intensity * splatColor.xyz;
    vec3 uBlend = u * (1. - intensity) + intensity * splatColor;

    fragColor = vec4(uAdd * additive + uBlend * blending, 1);
}
