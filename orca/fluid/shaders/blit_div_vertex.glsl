#version 300 es

precision highp float;

in vec2 pos;
out vec2 texCoord;

uniform mat4 mvp;

void main()
{
    texCoord = 0.5 * (pos + vec2(1, 1));
    gl_Position = mvp * vec4(pos, 0, 1);
}
