package main
import "core:math/linalg/glsl"
import gl "vendor:OpenGL"

Directional_Light :: struct {
	dir:         [3]f32,
	diffuse:     [3]f32,
	specular:    [3]f32,
}

Point_Light :: struct {
	pos:         [3]f32,
	diffuse:     [3]f32,
	specular:    [3]f32,
	constant:    f32,
	linear:      f32,
	quadratic:   f32,
}

directional_light_new :: proc(dir: [3]f32 = {0, -1, 0}, diffuse: [3]f32 = 0.2, specular: [3]f32 = 0.3) -> Directional_Light {
	return Directional_Light{
		dir      = dir,
		diffuse  = diffuse,
		specular = specular,
	}
}

point_light_new :: proc(pos: [3]f32 = 0, diffuse: [3]f32 = 0.5, specular: [3]f32 = 1, constant: f32 = 1, linear: f32 = 0.35, quadratic: f32 = 0.44) -> Point_Light {
	return Point_Light{
		pos = pos,
		diffuse = diffuse,
		specular = specular,
		constant = constant,
		linear = linear,
		quadratic = quadratic,
	}
}

point_light_render :: proc(light: ^Point_Light, shader_program: u32, mesh: ^Mesh, scale: [3]f32 = 0.2) {
	model_mat := glsl.mat4Translate(light.pos) * glsl.mat4Scale(scale)
	gl_shader_set_mat4(shader_program, "model_mat", model_mat)
	gl_shader_set_vec3(shader_program, "diffuse", light.diffuse)
	gl_shader_set_vec3(shader_program, "specular", light.specular)
	gl.BindVertexArray(mesh.vao)
	gl.DrawElements(gl.TRIANGLES, mesh.num_indices, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
}
