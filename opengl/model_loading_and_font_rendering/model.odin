package main
import "core:math/linalg/glsl"
import gl "vendor:OpenGL"

Model :: struct {
	pos:      [3]f32,
	scale:    [3]f32,
	mesh:     ^Mesh,
	material: ^Material,
	rot:      [3]f32,
}

model_new :: proc(mesh: ^Mesh, material: ^Material, pos: [3]f32 = 0, scale: [3]f32 = 1, rot: [3]f32 = 0) -> Model {
	return Model{
		pos = pos,
		scale = scale,
		mesh = mesh,
		material = material,
	}
}

model_render :: proc(model: ^Model, shader_program: u32) {
	model_mat := glsl.mat4Translate(model.pos) * glsl.mat4Rotate({1, 0, 0}, model.rot.x) * glsl.mat4Rotate({0, 1, 0}, model.rot.y) * glsl.mat4Rotate({0, 0, 1}, model.rot.z) * glsl.mat4Scale(model.scale)
	gl_shader_set_mat4(shader_program, "model_mat", model_mat)
	gl_shader_set_mat3(shader_program, "normal_mat", glsl.mat3(glsl.inverse_transpose(model_mat)))
	gl_shader_set_float(shader_program, "material.shininess", model.material.shininess)
	gl_shader_set_vec3(shader_program, "material.color", model.material.color)
	gl.BindVertexArray(model.mesh.vao)
	gl.DrawElements(gl.TRIANGLES, model.mesh.num_indices, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
}
