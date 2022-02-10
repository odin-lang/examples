package draw_texture

import "core:fmt"
import "core:math/linalg/glsl"
import "core:math/noise"
import gl "vendor:OpenGL"
import "vendor:glfw"

WIDTH 	 :: 640
HEIGHT 	 :: 640
TITLE 	 :: cstring("Open Simplex 2 Texture!")

// @note You might need to lower this to 3.3 depending on how old your graphics card is.
GL_MAJOR_VERSION :: 	4
GL_MINOR_VERSION :: 	5

create_vertices :: proc(x, y, width, height : f32) -> [dynamic]f32 {

	/**
	
	0 - x,y
	1 - x, y + height
	2 - x + width, y
	3 - x + width, y + height
	
	0	2
	|-----/|
	|   /  |
	|  /   |
	|/-----|
	1	3
	
	**/

	vertices : [dynamic]f32 = {
		x,		y,			0.0, 1.0,
		x,		y + height,		0.0, 0.0,
		x + width, 	y,			1.0, 1.0,
		x + width, 	y + height,		1.0, 0.0,
	}

	return vertices
}

create_texture_noise :: proc (texture_id : u32) {

	texture_data : [dynamic]u8

	gl.BindTexture(gl.TEXTURE_2D, texture_id)
	gl.ActiveTexture(gl.TEXTURE0)

	seed := i64(glfw.GetTime() * 400)

	for x := 0; x < WIDTH; x += 1 {
		
		for y := 0; y < HEIGHT; y += 1 {
			
			simplex_noise := ((noise.noise_2d(seed, {f64(x) / 60.0, f64(y) / 60.0}) + 1.0) / 2.0)
			color := u8(simplex_noise * 255.0)
			
			append(&texture_data, color, color, color, u8(255))
		
		}
	}

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(WIDTH), i32(HEIGHT), 0, gl.RGBA, gl.UNSIGNED_BYTE, &texture_data[0])
}

main :: proc() {

	if !bool(glfw.Init()) {
		fmt.println("GLFW has failed to load.")
		return
	}

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window_handle := glfw.CreateWindow(WIDTH, HEIGHT, TITLE, nil, nil)

	defer glfw.Terminate()
	defer glfw.DestroyWindow(window_handle)

	if window_handle == nil {
		fmt.println("GLFW has failed to load the window.")
		return
	}

	// Load OpenGL context or the "state" of OpenGL.
	glfw.MakeContextCurrent(window_handle)
	// Load OpenGL function pointers with the specficed OpenGL major and minor version.
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	// Disable Vsync
	glfw.SwapInterval(0)

	vao : u32
	vbo : u32
	ebo : u32

	gl.GenVertexArrays(1, &vao)
	defer gl.DeleteVertexArrays(1, &vao)

	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)
	defer gl.DeleteBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &ebo)
	
	gl.BindVertexArray(vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)

	vertices := create_vertices(x = 0, y = 0, width = WIDTH, height = HEIGHT)

	/**
	
	0	2
	|-----/|
	|   /  |
	|  /   |
	|/-----|
	1	3

	**/

	indices : [dynamic]u32 = {
		0, 1, 2,
		2, 1, 3,
	}

	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(f32), 0)

	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 4 * size_of(f32), size_of(f32) * 2)

	gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(f32), &vertices[0], gl.STATIC_DRAW)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), &indices[0], gl.STATIC_DRAW)
	
	program_id, err := gl.load_shaders("./shader.vert", "./shader.frag")
	defer gl.DeleteProgram(program_id)
	
	texture_id : u32
	gl.GenTextures(1, &texture_id)
	defer gl.DeleteTextures(1, &texture_id)

	gl.BindTexture(gl.TEXTURE_2D, texture_id)
	gl.ActiveTexture(gl.TEXTURE0)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	ortho := glsl.mat4Ortho3d(0.0, f32(WIDTH), f32(HEIGHT), 0.0, 1.0, 100.0)
	create_texture_noise(texture_id)

	for !glfw.WindowShouldClose(window_handle) {
	
		// Process all incoming events like keyboard press, window resize, and etc.
		glfw.PollEvents()

		gl.ClearColor(0.5, 0.0, 1.0, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.UseProgram(program_id)
		gl.BindVertexArray(vao)
		gl.BindTexture(gl.TEXTURE_2D, texture_id)
		gl.ActiveTexture(gl.TEXTURE0)
		gl.Uniform1i(gl.GetUniformLocation(program_id, "u_texture"), 0)
		gl.UniformMatrix4fv(gl.GetUniformLocation(program_id, "u_projection"), 1, gl.FALSE, &ortho[0][0])

		gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_INT, nil)

		glfw.SwapBuffers(window_handle)
	
	}

}