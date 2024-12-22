package common

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

Vertex :: struct {
	pos: glm.vec3,
	col: glm.vec4,
}

Game_Memory :: struct {
	uniforms : gl.Uniforms,
	indices : []u16,
	program: u32,
	vertices: []Vertex,
	ebo: u32,
	vbo: u32,
	vao: u32,
	window_width: i32,
	window_height: i32
}