#version 300 es

precision highp float;

in vec2 pos;
out vec2 texCoord;

uniform mat4 mvp;
uniform ivec2 gridSize;

void main()
{
    float margin = 32.;
    float ratio = 1. - 2. * margin / float(gridSize.x);

    texCoord = margin / float(gridSize.x) + ratio * (0.5 * (pos + vec2(1, 1)));
    gl_Position = mvp * vec4(pos, 0, 1);
}
