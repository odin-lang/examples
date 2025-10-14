package main

import gl "vendor:OpenGL"
import "vendor:glfw"
import "core:fmt"
import "core:os"

framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
	gl.Viewport(0, 0, width, height)
}

processInput :: proc "c" (window: glfw.WindowHandle) {
	if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}
}

shader_set_bool :: proc(id: u32, name: cstring, value: bool) {
	gl.Uniform1i(gl.GetUniformLocation(id, name), i32(value))
}

shader_set_int :: proc(id: u32, name: cstring, value: i32) {
	gl.Uniform1i(gl.GetUniformLocation(id, name), value)
}

shader_set_float :: proc(id: u32, name: cstring, value: f32) {
	gl.Uniform1f(gl.GetUniformLocation(id, name), value)
}

SCR_WIDTH :: 800
SCR_HEIGHT :: 600

main :: proc() {
	glfw.Init()
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(SCR_WIDTH, SCR_HEIGHT, "LearnOpenGL", nil, nil)
	if window == nil {
		fmt.println("Failed to create GLFW window")
		glfw.Terminate()
		os.exit(-1)
	}
	glfw.MakeContextCurrent(window)

	gl.load_up_to(3, 3, glfw.gl_set_proc_address)

	gl.Viewport(0, 0, SCR_WIDTH, SCR_HEIGHT)

	glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)

	vertices := [?]f32 {
         0.5, -0.5, 0.0,  1.0, 0.0, 0.0,
        -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,
         0.0,  0.5, 0.0,  0.0, 0.0, 1.0,
	}

	// The shader loading they create can be replaced with just this
	shaderProgram, loaded_ok := gl.load_shaders_file("./res/vertex.vs", "./res/fragment.fs")
	if !loaded_ok {
		os.exit(-1)
	}

	VBO, VAO: u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)

	gl.BindVertexArray(VAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(&vertices), gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 3 * size_of(f32))
	gl.EnableVertexAttribArray(1)

	for !glfw.WindowShouldClose(window) {
		processInput(window)

		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.UseProgram(shaderProgram)
		gl.BindVertexArray(VAO)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

	gl.DeleteVertexArrays(1, &VAO)
	gl.DeleteBuffers(1, &VBO)
	gl.DeleteProgram(shaderProgram)

	glfw.Terminate()
}