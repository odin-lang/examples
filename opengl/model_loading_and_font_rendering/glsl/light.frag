#version 330 core

in vec2 vs_tex_coords;
out vec4 fs_color;
uniform vec3 diffuse;
uniform vec3 specular;

void main() {
    fs_color = vec4(mix(specular, diffuse, distance(abs(vs_tex_coords - 0.5) * 2, vec2(0))), 1.0);
}
