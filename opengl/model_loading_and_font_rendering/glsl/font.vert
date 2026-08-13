#version 330 core

const vec4 coords[4] = vec4[4]( vec4(-0.5, -0.5,  0.0, 0.99), vec4( 0.5, -0.5, 0.99, 0.99), vec4( 0.5,  0.5, 0.99,  0.0), vec4(-0.5,  0.5,  0.0,  0.0) );

layout (location = 0) in uint in_char;
out vec2 vs_tex_coords;
uniform vec2 size;
uniform vec2 ndc_pixel;
uniform float scale;
uniform vec2 pos;
uniform float spacing;

void main() {
    uint character = in_char & 255u;
    uint line = (in_char >> 8) & 255u;
    uint col = (in_char >> 16) & 255u;
    vec2 ndc_size = ndc_pixel * size * scale;
    vec4 vert_coords = coords[gl_VertexID];
    gl_Position = vec4((vert_coords.x + col + 0.5) * ndc_size.x + (pos.x + spacing * col) * ndc_pixel.x - 1.0, (vert_coords.y - 0.5 - line) * ndc_size.y - pos.y * ndc_pixel.y + 1.0, 0.0, 1.0);
    vs_tex_coords = vec2((vert_coords.z + character % 32u) / 32, (vert_coords.w + character / 32u) / 3);
}
