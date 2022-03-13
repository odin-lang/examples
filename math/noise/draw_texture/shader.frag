#version 330 core

layout(location = 0) out vec4 color;
		
in vec2 texture_coords;
uniform sampler2D u_texture;

void main() {
		color = texture(u_texture, texture_coords);
}