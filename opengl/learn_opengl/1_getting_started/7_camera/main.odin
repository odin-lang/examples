package main

import "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "core:fmt"
import "core:os"
import stbi "vendor:stb/image"
import "core:math"

framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
	gl.Viewport(0, 0, width, height)
}

processInput :: proc "c" (window: glfw.WindowHandle) {
	if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}

	cameraSpeed := f32(deltaTime * 2.5)
	if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
		cameraPos += cameraSpeed * cameraFront
	}
	if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
		cameraPos -= cameraSpeed * cameraFront
	}
	if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
		cameraPos -= glsl.normalize(glsl.cross(cameraFront, cameraUp)) * cameraSpeed
	}
	if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
		cameraPos += glsl.normalize(glsl.cross(cameraFront, cameraUp)) * cameraSpeed
	}
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, xposIn: f64, yposIn: f64) {
	xpos := f32(xposIn)
	ypos := f32(yposIn)

	if firstMouse {
		lastX = xpos
		lastY = ypos
		firstMouse = false
	}

	xoffset := xpos - lastX
	yoffset := lastY - ypos
	lastX = xpos
	lastY = ypos

	sensitivity: f32 = 0.1
	xoffset *= sensitivity
	yoffset *= sensitivity

	yaw += xoffset
	pitch += yoffset

	if pitch > 89 {
		pitch = 89
	}
	if pitch < -89 {
		pitch = -89
	}

	front := glsl.vec3{
		math.cos(glsl.radians(yaw)) * math.cos(glsl.radians(pitch)),
		math.sin(glsl.radians(pitch)),
		math.sin(glsl.radians(yaw)) * glsl.cos(glsl.radians(pitch)),
	}
	cameraFront = glsl.normalize(front)
}

scroll_callback := proc "c" (window: glfw.WindowHandle, xoffset: f64, yoffset: f64) {
	fov -= f32(yoffset)
	if fov < 1 {
		fov = 1
	}
	if fov > 45 {
		fov = 45
	}
}

SCR_WIDTH :: 800
SCR_HEIGHT :: 600

cameraPos := glsl.vec3{0, 0, 3}
cameraFront := glsl.vec3{0, 0, -1}
cameraUp := glsl.vec3{0, 1, 0}

firstMouse := true
yaw: f32 = -90
pitch: f32 = 0
lastX: f32 = 800 / 2
lastY: f32 = 600 / 2
fov: f32 = 45

deltaTime: f32 = 0
lastFrame: f32 = 0

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

	gl.Viewport(0, 0, 800, 600)

	glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)
	glfw.SetCursorPosCallback(window, mouse_callback)
	glfw.SetScrollCallback(window, scroll_callback)

	glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)

	vertices := [?]f32 {
        -0.5, -0.5, -0.5,  0.0, 0.0,
         0.5, -0.5, -0.5,  1.0, 0.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
        -0.5,  0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 0.0,

        -0.5, -0.5,  0.5,  0.0, 0.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 1.0,
         0.5,  0.5,  0.5,  1.0, 1.0,
        -0.5,  0.5,  0.5,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,

        -0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5,  0.5, -0.5,  1.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,
        -0.5,  0.5,  0.5,  1.0, 0.0,

         0.5,  0.5,  0.5,  1.0, 0.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5,  0.5,  0.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 0.0,

        -0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5, -0.5,  1.0, 1.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,

        -0.5,  0.5, -0.5,  0.0, 1.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5,  0.5,  0.5,  1.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5,  0.5,  0.5,  0.0, 0.0,
        -0.5,  0.5, -0.5,  0.0, 1.0,
	}

	cubePositions := [?]glsl.vec3{
		{0.0, 0.0, 0.0},
		{2.0, 5.0, -15.0},
		{-1.5, -2.2, -2.5},
		{-3.8, -2.0, -12.3},
		{2.4, -0.4, -3.5},
		{-1.7, 3.0, -7.5},
		{1.3, -2.0, -2.5},
		{1.5, 2.0, -2.5},
		{1.5, 0.2, -1.5},
		{-1.3, 1.0, -1.5},
	}

	gl.Enable(gl.DEPTH_TEST)

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

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), 3 * size_of(f32))
	gl.EnableVertexAttribArray(1)

	texture1, texture2: u32
	gl.GenTextures(1, &texture1)
	gl.BindTexture(gl.TEXTURE_2D, texture1)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	width, height, nrChannels: i32
	stbi.set_flip_vertically_on_load(1)

	data := stbi.load("../res/container.jpg", &width, &height, &nrChannels, 0)
	if data == nil {
		fmt.println("Failed to load texture")
		os.exit(-1)
	}

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, data)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	stbi.image_free(data)

	gl.GenTextures(1, &texture2)
	gl.BindTexture(gl.TEXTURE_2D, texture2)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	data = stbi.load("../res/awesomeface.png", &width, &height, &nrChannels, 0)
	if data == nil {
		fmt.println("Failed to load texture")
		os.exit(-1)
	}

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	stbi.image_free(data)

	gl.UseProgram(shaderProgram)
	shader_set_int(shaderProgram, "texture1", 0)
	shader_set_int(shaderProgram, "texture2", 1)

	for !glfw.WindowShouldClose(window) {
		currentFrame := f32(glfw.GetTime())
		deltaTime = currentFrame - lastFrame
		lastFrame = currentFrame

		processInput(window)

		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, texture1)
		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, texture2)

		gl.UseProgram(shaderProgram)

		view: glsl.mat4 = 1
		view *= glsl.mat4LookAt(cameraPos, cameraPos + cameraFront, cameraUp)

		projection: glsl.mat4 = 1
		projection *= glsl.mat4Perspective(glsl.radians_f32(45), f32(f32(SCR_WIDTH) / f32(SCR_HEIGHT)), 0.1, 100)

		shader_set_mat4(shaderProgram, "projection", projection)
		shader_set_mat4(shaderProgram, "view", view)

		gl.BindVertexArray(VAO)
		for position, i in cubePositions {
			model: glsl.mat4 = 1
			model *= glsl.mat4Translate(position)
			angle := 20.0 * f32(i)
			model *= glsl.mat4Rotate({1.0, 0.3, 0.5}, glsl.radians(angle))
			shader_set_mat4(shaderProgram, "model", model)

			gl.DrawArrays(gl.TRIANGLES, 0, 36)
		}

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

	gl.DeleteVertexArrays(1, &VAO)
	gl.DeleteBuffers(1, &VBO)
	gl.DeleteProgram(shaderProgram)

	glfw.Terminate()
}