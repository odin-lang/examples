#version 330 core

layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec3 in_normal;
layout (location = 2) in vec2 in_tex_coords;
out vec3 vs_pos;
out vec3 vs_normal;
out vec2 vs_tex_coords;
uniform mat3 normal_mat;
uniform mat4 model_mat;
uniform mat4 view_mat;
uniform mat4 projection_mat;

void main() {
    gl_Position = projection_mat * view_mat * model_mat * vec4(in_pos, 1.0);
    vs_pos = vec3(model_mat * vec4(in_pos, 1.0));
    vs_normal = normal_mat * in_normal;
    vs_tex_coords = in_tex_coords;
}
