package main

import gl "vendor:OpenGL"
import "core:math/linalg/glsl"

shader_set_bool :: proc(id: u32, name: cstring, value: bool) {
	gl.Uniform1i(gl.GetUniformLocation(id, name), i32(value))
}

shader_set_int :: proc(id: u32, name: cstring, value: i32) {
	gl.Uniform1i(gl.GetUniformLocation(id, name), value)
}

shader_set_float :: proc(id: u32, name: cstring, value: f32) {
	gl.Uniform1f(gl.GetUniformLocation(id, name), value)
}

shader_set_vec2_v :: proc(id: u32, name: cstring, value: glsl.vec2) {
	lc := value
	gl.Uniform2fv(gl.GetUniformLocation(id, name), 1, raw_data(&lc))
}

shader_set_vec2_f :: proc(id: u32, name: cstring, x, y: f32) {
	gl.Uniform2f(gl.GetUniformLocation(id, name), x, y)
}

shader_set_vec2 :: proc {
	shader_set_vec2_v,
	shader_set_vec2_f,
}

shader_set_vec3_v :: proc(id: u32, name: cstring, value: glsl.vec3) {
	lc := value
	gl.Uniform3fv(gl.GetUniformLocation(id, name), 1, raw_data(&lc))
}

shader_set_vec3_f :: proc(id: u32, name: cstring, x, y, z: f32) {
	gl.Uniform3f(gl.GetUniformLocation(id, name), x, y, z)
}

shader_set_vec3 :: proc {
	shader_set_vec3_v,
	shader_set_vec3_f,
}

shader_set_vec4_v :: proc(id: u32, name: cstring, value: glsl.vec4) {
	lc := value
	gl.Uniform4fv(gl.GetUniformLocation(id, name), 1, raw_data(&lc))
}

shader_set_vec4_f :: proc(id: u32, name: cstring, x, y, z, w: f32) {
	gl.Uniform4f(gl.GetUniformLocation(id, name), x, y, z, w)
}

shader_set_vec4 :: proc {
	shader_set_vec4_v,
	shader_set_vec4_f,
}

shader_set_mat2 :: proc(id: u32, name: cstring, mat: glsl.mat2) {
	lc := mat
	gl.UniformMatrix2fv(gl.GetUniformLocation(id, name), 1, gl.FALSE, raw_data(&lc))
}

shader_set_mat3 :: proc(id: u32, name: cstring, mat: glsl.mat3) {
	lc := mat
	gl.UniformMatrix3fv(gl.GetUniformLocation(id, name), 1, gl.FALSE, raw_data(&lc))
}

shader_set_mat4 :: proc(id: u32, name: cstring, mat: glsl.mat4) {
	lc := mat
	gl.UniformMatrix4fv(gl.GetUniformLocation(id, name), 1, gl.FALSE, raw_data(&lc))
}