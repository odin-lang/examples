package draw_texture

import "base:runtime"

import "core:c"
import "core:fmt"
import "core:math/linalg/glsl"
import "core:math/noise"
import "core:mem"

import    "vendor:glfw"
import gl "vendor:OpenGL"

WIDTH  :: 400
HEIGHT :: 400
TITLE  :: cstring("Open Simplex 2 Texture!")

// @note You might need to lower this to 3.3 depending on how old your graphics card is.
GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 1

Adjust_Noise :: struct {
	seed:       i64,
	octaves:    i32,
	frequency: f64,
}

Vertices :: [16]f32

create_vertices :: proc(x, y, width, height: f32) -> Vertices {

	/**

	0 - x,y
	1 - x, y + height
	2 - x + width, y
	3 - x + width, y + height

	0      2
	|-----/|
	|   /  |
	|  /   |
	|/-----|
	1      3

	**/

	vertices: Vertices = {
		x, y,                   0.0, 1.0,
		x, y + height,          0.0, 0.0,
		x + width, y,           1.0, 1.0,
		x + width, y + height,  1.0, 0.0,
	}

	return vertices
}


WAVELENGTH :: 120
Pixel :: [4]u8

noise_at :: proc(seed: i64, x, y: int) -> f32 {
	return (noise.noise_2d(seed, {f64(x) / 120, f64(y) / 120}) + 1.0) / 2.0
}

create_texture_noise :: proc(texture_id: u32, adjust_noise: Adjust_Noise) {

	texture_data := make([]u8, WIDTH * HEIGHT * 4)
	defer delete(texture_data)

	gl.BindTexture(gl.TEXTURE_2D, texture_id)
	gl.ActiveTexture(gl.TEXTURE0)

	gradient_location: glsl.vec2 = {f32(WIDTH / 2), f32(HEIGHT / 2)}

	pixels := mem.slice_data_cast([]Pixel, texture_data)

	for x := 0; x < WIDTH; x += 1 {

		for y := 0; y < HEIGHT; y += 1 {

			using adjust_noise := adjust_noise

			noise_val: f32

			{

				for i := 0; i < int(octaves); i += 1 {
					noise_val += 0.4 * ((noise.noise_2d(seed, {f64(x) / frequency / 2, f64(y) / frequency / 2}) + 1.0) / 2.0)
					noise_val += 0.6 * ((noise.noise_2d(seed, {f64(x) / frequency * 2 ,f64(y) / frequency * 2}) + 1.0) / 2.0)
					frequency *= glsl.exp(frequency)
				}
				noise_val /= f32(octaves)
			}

			val := glsl.distance_vec2({f32(x), f32(y)}, gradient_location)
			val /= f32(HEIGHT / 2)

			noise_val = noise_val - val

			if noise_val < 0.0 {
				noise_val = 0
			}

			val = glsl.clamp(val, 0.0, 1.0)
			color := u8((noise_val) * 255.0)

			switch {
			case color <  20:
				// Water
				noise_val =  0.75 + 0.25 * noise_at(seed, x, y)
				pixels[0] = {u8( 51 * noise_val), u8( 81 * noise_val), u8(251 * noise_val), 255}

			case color <  30:
				// Sand
				noise_val = 0.75 + 0.25 * noise_at(seed, x, y)
				pixels[0] = {u8(251 * noise_val), u8(244 * noise_val), u8(189 * noise_val), 255}

			case color <  60:
				// Grass
				noise_val = 0.75 + 0.25 * noise_at(seed, x, y)
				pixels[0] = {u8(124 * noise_val), u8(200 * noise_val), u8( 65 * noise_val), 255}

			case color <  90:
				// The forest
				noise_val = 0.75 + 0.25 * noise_at(seed, x, y)
				pixels[0] = {u8(124 * noise_val), u8(150 * noise_val), u8( 65 * noise_val), 255}

			case color < 120:
				// The Mountain
				noise_val = 0.7 + 0.2 * noise_at(seed, x, y)
				noise_val = glsl.pow(noise_val, 2)

				pixels[0] = {u8(143 * noise_val), u8(143 * noise_val), u8(143 * noise_val), 255}

			case:
				// The peak of the mountain
				noise_val = 0.7 + 0.2 * noise_at(seed, x, y)
				noise_val = glsl.pow(noise_val, 2)

				pixels[0] = {u8(205 * noise_val), u8(221 * noise_val), u8(246 * noise_val), 255}
			}
			pixels = pixels[1:]
		}
	}

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(WIDTH), i32(HEIGHT), 0, gl.RGBA, gl.UNSIGNED_BYTE, &texture_data[0])
}

main :: proc() {

	if !bool(glfw.Init()) {
		fmt.println("GLFW has failed to load.")
		return
	}

	glfw.SetErrorCallback(proc "c" (error: c.int, description: cstring) {
		context = runtime.default_context()
		fmt.println(description)
	})

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, 1)

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

	vao: u32
	vbo: u32
	ebo: u32

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

	0      2
	|-----/|
	|   /  |
	|  /   |
	|/-----|
	1      3

	**/

	indices: [6]u32 = {
		0, 1, 2,
		2, 1, 3,
	}

	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(f32), 0)

	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 4 * size_of(f32), size_of(f32) * 2)

	gl.BufferData(gl.ARRAY_BUFFER,         len(vertices) * size_of(f32), raw_data(vertices[:]), gl.STATIC_DRAW)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices)  * size_of(u32), raw_data(indices[:]),  gl.STATIC_DRAW)

	program_id: u32; ok: bool
	if program_id, ok = gl.load_shaders("./shader.vert", "./shader.frag"); !ok {
		fmt.println("Failed to load shaders.")
		return
	}
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

	adjust_noise: Adjust_Noise
	adjust_noise.frequency = WIDTH / 2
	adjust_noise.octaves = 1
	adjust_noise.seed = 360000

	create_texture_noise(texture_id, adjust_noise)


	for !glfw.WindowShouldClose(window_handle) {

		// Process all incoming events like keyboard press, window resize, and etc.
		glfw.PollEvents()

		if glfw.GetKey(window_handle, glfw.KEY_COMMA) == glfw.PRESS && glfw.GetKey(window_handle, glfw.KEY_LEFT_SHIFT) == glfw.PRESS {
			adjust_noise.frequency -= 5.0
			adjust_noise.frequency = glsl.clamp(adjust_noise.frequency, 1, 9000)
			create_texture_noise(texture_id, adjust_noise)
		} else if glfw.GetKey(window_handle, glfw.KEY_COMMA) == glfw.PRESS {
			adjust_noise.frequency += 5.0
			create_texture_noise(texture_id, adjust_noise)
		}

		if glfw.GetKey(window_handle, glfw.KEY_PERIOD) == glfw.PRESS && glfw.GetKey(window_handle, glfw.KEY_LEFT_SHIFT) == glfw.PRESS {
			adjust_noise.octaves -= 1.0
			adjust_noise.octaves = glsl.clamp(adjust_noise.octaves, 1, 100)
			create_texture_noise(texture_id, adjust_noise)
		} else if glfw.GetKey(window_handle, glfw.KEY_PERIOD) == glfw.PRESS {
			adjust_noise.octaves += 1.0
			create_texture_noise(texture_id, adjust_noise)
		}

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
