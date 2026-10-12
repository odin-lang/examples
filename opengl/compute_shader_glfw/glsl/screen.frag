#version 330 core

in vec2 vs_tex_coords;
out vec4 fs_color;
uniform sampler2D colorbuf_tex;

void main() {
	fs_color = vec4(texture(colorbuf_tex, vs_tex_coords).rgb, 1.0);
}
