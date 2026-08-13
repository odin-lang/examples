package main
import "core:log"
import gl "vendor:OpenGL"
import stbi "vendor:stb/image"

gl_check_error :: proc(location := #caller_location) {
	if err := gl.GetError(); err != gl.NO_ERROR {
		log.errorf("OpenGL error! %s", gl.GL_Enum(err), location = location)
	}
}

gl_texture_load :: proc(path: cstring, filtering: bool = true) -> u32 {
	texture_id: u32
	img_width, img_height, img_channels: i32
	gl.GenTextures(1, &texture_id)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, texture_id)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filtering ? gl.LINEAR : gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filtering ? gl.LINEAR : gl.NEAREST)
	img := stbi.load(cstring(path), &img_width, &img_height, &img_channels, 0)
	if img == nil {
		log.panicf("Failed to load texture image. (%v)", path)
	}
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, img_width, img_height, 0, img_channels == 4 ? gl.RGBA : (img_channels == 3 ? gl.RGB : gl.RED), gl.UNSIGNED_BYTE, img)
	gl.GenerateMipmap(gl.TEXTURE_2D)
	stbi.image_free(img)
	return texture_id
}

gl_ssbo_create_and_write :: proc(bo: ^u32, binding_index: u32, data: rawptr, n: int, $T: typeid, usage: gl.GL_Enum) {
	gl_ssbo_create(bo, binding_index, n, T, usage)
	gl_ssbo_write(bo, binding_index, data, n, T, usage)
}

gl_ssbo_create :: proc(bo: ^u32, binding_index: u32, n: int, $T: typeid, usage: gl.GL_Enum) {
	gl.GenBuffers(1, bo)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, bo^)
	gl.BufferData(gl.SHADER_STORAGE_BUFFER, n * size_of(T), nil, u32(usage))
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, binding_index, bo^)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0)
}

gl_ssbo_write :: proc(bo: ^u32, binding_index: u32, data: rawptr, n: int, $T: typeid, usage: gl.GL_Enum) {
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, bo^)
	gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, n * size_of(T), data)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0)
}

gl_shader_load_vs_fs :: proc(vs, fs: string) -> u32 {
	sp, ok := gl.load_shaders_file(vs, fs)
	if !ok {
		log.panicf("Shader loading failed. (%s %s)", vs, fs)}
	return sp
}

gl_shader_load_cs :: proc(cs: string) -> u32 {
	sp, ok := gl.load_compute_file(cs)
	if !ok {
		log.panicf("Shader loading failed (%s).", cs)
	}
	return sp
}

gl_shader_set_bool :: proc(id: u32, name: cstring, value: bool) {
	gl.Uniform1i(gl.GetUniformLocation(id, name), i32(value))
}

gl_shader_set_int :: proc(id: u32, name: cstring, value: i32) {
	gl.Uniform1i(gl.GetUniformLocation(id, name), value)
}

gl_shader_set_uint :: proc(id: u32, name: cstring, value: u32) {
	gl.Uniform1ui(gl.GetUniformLocation(id, name), value)
}

gl_shader_set_float :: proc(id: u32, name: cstring, value: f32) {
	gl.Uniform1f(gl.GetUniformLocation(id, name), value)
}

gl_shader_set_uvec2 :: proc{
	gl_shader_set_uvec2_copy,
	gl_shader_set_uvec2_pointer,
}

gl_shader_set_uvec2_copy :: proc(id: u32, name: cstring, vec: [2]u32) {
	vec := vec
	gl.Uniform2uiv(gl.GetUniformLocation(id, name), 1, raw_data(&vec))
}

gl_shader_set_uvec2_pointer :: proc(id: u32, name: cstring, vec: ^[2]u32) {
	gl.Uniform2uiv(gl.GetUniformLocation(id, name), 1, raw_data(vec))
}

gl_shader_set_vec2 :: proc{
	gl_shader_set_vec2_copy,
	gl_shader_set_vec2_pointer,
}

gl_shader_set_vec2_copy :: proc(id: u32, name: cstring, vec: [2]f32) {
	vec := vec
	gl.Uniform2fv(gl.GetUniformLocation(id, name), 1, raw_data(&vec))
}

gl_shader_set_vec2_pointer :: proc(id: u32, name: cstring, vec: ^[2]f32) {
	gl.Uniform2fv(gl.GetUniformLocation(id, name), 1, raw_data(vec))
}

gl_shader_set_vec3 :: proc{
	gl_shader_set_vec3_copy,
	gl_shader_set_vec3_pointer,
}

gl_shader_set_vec3_copy :: proc(id: u32, name: cstring, vec: [3]f32) {
	vec := vec
	gl.Uniform3fv(gl.GetUniformLocation(id, name), 1, raw_data(&vec))
}

gl_shader_set_vec3_pointer :: proc(id: u32, name: cstring, vec: ^[3]f32) {
	gl.Uniform3fv(gl.GetUniformLocation(id, name), 1, raw_data(vec))
}

gl_shader_set_vec4 :: proc{
	gl_shader_set_vec4_copy,
	gl_shader_set_vec4_pointer,
}

gl_shader_set_vec4_copy :: proc(id: u32, name: cstring, vec: [4]f32) {
	vec := vec
	gl.Uniform4fv(gl.GetUniformLocation(id, name), 1, raw_data(&vec))
}

gl_shader_set_vec4_pointer :: proc(id: u32, name: cstring, vec: ^[4]f32) {
	gl.Uniform4fv(gl.GetUniformLocation(id, name), 1, raw_data(vec))
}

gl_shader_set_mat3 :: proc{
	gl_shader_set_mat3_copy,
	gl_shader_set_mat3_pointer,
}

gl_shader_set_mat3_copy :: proc(id: u32, name: cstring, mat: matrix[3, 3]f32) {
	mat := mat
	gl.UniformMatrix3fv(gl.GetUniformLocation(id, name), 1, gl.FALSE, raw_data(&mat))
}

gl_shader_set_mat3_pointer :: proc(id: u32, name: cstring, mat: ^matrix[3, 3]f32) {
	gl.UniformMatrix3fv(gl.GetUniformLocation(id, name), 1, gl.FALSE, raw_data(mat))
}

gl_shader_set_mat4 :: proc{
	gl_shader_set_mat4_copy,
	gl_shader_set_mat4_pointer,
}

gl_shader_set_mat4_copy :: proc(id: u32, name: cstring, mat: matrix[4, 4]f32) {
	mat := mat
	gl.UniformMatrix4fv(gl.GetUniformLocation(id, name), 1, gl.FALSE, raw_data(&mat))
}

gl_shader_set_mat4_pointer :: proc(id: u32, name: cstring, mat: ^matrix[4, 4]f32) {
	gl.UniformMatrix4fv(gl.GetUniformLocation(id, name), 1, gl.FALSE, raw_data(mat))
}
