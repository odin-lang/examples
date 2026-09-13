#version 450

// One vertex layout serves all three draw kinds (solid rect, textured quad,
// msdf glyph). Which behaviour is used is decided in the fragment shader via
// the `mode` fragment uniform.

layout(location = 0) in vec2 in_position;
layout(location = 1) in vec2 in_uv;
layout(location = 2) in vec4 in_color;

layout(location = 0) out vec2 out_uv;
layout(location = 1) out vec4 out_color;

// SDL_GPU resource binding convention for SPIR-V:
//   vertex shaders   -> uniform buffers live in set = 1
//   fragment shaders -> sampled textures in set = 2, uniform buffers in set = 3
// (see SDL_CreateGPUShader documentation)
layout(set = 1, binding = 0) uniform UniformBlock {
	mat4 mvp;
} ubo;

void main() {
	gl_Position = ubo.mvp * vec4(in_position, 0.0, 1.0);
	out_uv      = in_uv;
	out_color   = in_color;
}
