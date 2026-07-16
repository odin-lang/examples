package main
import "core:c/libc"
import "core:log"
import "core:mem"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"

WINDOW_TITLE             :: "compute_shader_example"
GL_VERSION_MAJOR         :: 4
GL_VERSION_MINOR         :: 3
OPTION_VSYNC             :: false
OPTION_ANTI_ALIAS        :: false
OPTION_GAMMA_CORRECTION  :: false
SHADER_SCREEN_VERT       :: "./glsl/screen.vert"
SHADER_SCREEN_FRAG       :: "./glsl/screen.frag"
SHADER_COMPUTE           :: "./glsl/compute.comp"
WINDOW_WIDTH             :: 1280
WINDOW_HEIGHT            :: 720
COMPUTE_RENDER_WIDTH     :: 1280
COMPUTE_RENDER_HEIGHT    :: 720
BACKGROUND_COLOR         :[3]f32: {0, 0, 0}

App :: struct {
	window:          glfw.WindowHandle,
	colorbuf_tex:    u32,
	vao:             u32,
	vbo:             u32,
	sp_compute:      u32,
	sp_screen:       u32,
}

main :: proc() {
	// Tracking allocator and logger set up
	context.logger = log.create_console_logger()
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	defer mem_check_leaks(&tracking_allocator)

	// Program initialization
	app := App{}
	init(&app)

	// Main Loop
	for !glfw.WindowShouldClose(app.window) {
		input(&app)
		render(&app)
		glfw.PollEvents()
		mem_check_bad_free(&tracking_allocator)
		free_all(context.temp_allocator)
	}
   
	// Exit the program
	exit(&app)
}

mem_check_leaks :: proc(tracking_allocator: ^mem.Tracking_Allocator) {
	for _, leak in tracking_allocator.allocation_map {
		log.errorf("%v: Leaked %v bytes", leak.location, leak.size)
	}
	mem.tracking_allocator_clear(tracking_allocator)
}

mem_check_bad_free :: proc(tracking_allocator: ^mem.Tracking_Allocator) {
	if len(tracking_allocator.bad_free_array) > 0 {
		for bad_free in tracking_allocator.bad_free_array {
			log.errorf("Bad free at: %v", bad_free.location)
		}
		libc.getchar()
		panic("Bad free detected!")
	}
}

gl_check_error :: proc(location := #caller_location) {
	if err := gl.GetError(); err != gl.NO_ERROR {
		log.errorf("OpenGL error! %s", gl.GL_Enum(err), location = location)
	}
}

gl_shader_load_vs_fs :: proc(vs, fs: string) -> u32 {
	sp, ok := gl.load_shaders_file(vs, fs)
	if !ok {
		log.errorf("Shader loading failed. (%s %s)", vs, fs)
		os.exit(1)
	}
	return sp
}

gl_shader_load_cs :: proc(cs: string) -> u32 {
	sp, ok := gl.load_compute_file(cs)
	if !ok {
		log.errorf("Shader loading failed (%s).", cs)
		os.exit(1)
	}
	return sp
}

init :: proc(app: ^App) {
	// GLFW and OpenGL initialization
	glfw.Init()
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_VERSION_MAJOR)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_VERSION_MINOR)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)
	glfw.WindowHint(glfw.DECORATED, glfw.TRUE)
	if OPTION_ANTI_ALIAS {
		glfw.WindowHint(glfw.SAMPLES, 4)
	}
	app.window = glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE, nil, nil)
	if app.window == nil {
		log.errorf("GLFW window creation failed.")
		glfw.Terminate()
		os.exit(1)
	}
	glfw.MakeContextCurrent(app.window)
	if !OPTION_VSYNC {
		glfw.SwapInterval(0)
	}
	gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, glfw.gl_set_proc_address)
	gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
	
	// OpenGL settings
	gl.Enable(gl.CULL_FACE)
	gl.Enable(gl.LINE_SMOOTH)
	gl.LineWidth(2)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	if OPTION_GAMMA_CORRECTION {
		gl.Enable(gl.FRAMEBUFFER_SRGB)
	}
	if OPTION_ANTI_ALIAS {
		gl.Enable(gl.MULTISAMPLE)
	}

	// Vertex array object & vertex buffer object setup
	gl.GenVertexArrays(1, &app.vao)
	gl.BindVertexArray(app.vao)
	gl.GenBuffers(1, &app.vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, app.vbo)

	// Load shaders
	app.sp_screen = gl_shader_load_vs_fs(SHADER_SCREEN_VERT, SHADER_SCREEN_FRAG)
	app.sp_compute = gl_shader_load_cs(SHADER_COMPUTE)

	// Colorbuffer texture setup
	gl.GenTextures(1, &app.colorbuf_tex)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, app.colorbuf_tex)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, COMPUTE_RENDER_WIDTH, COMPUTE_RENDER_HEIGHT, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
	gl.BindImageTexture(0, app.colorbuf_tex, 0, gl.FALSE, 0, gl.READ_ONLY, gl.RGBA32F)
	gl.UseProgram(app.sp_screen)
	gl.Uniform1i(gl.GetUniformLocation(app.sp_screen, "colorbuf_tex"), 1)
}

input :: proc(app: ^App) {
	if glfw.GetKey(app.window, glfw.KEY_ESCAPE) == glfw.PRESS { glfw.SetWindowShouldClose(app.window, true) }
}

render :: proc(app: ^App) {
	// Clear screen
	gl.ClearColor(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	gl.BindVertexArray(app.vao)

	// Run compute shader to generate colorbuffer and depthbuffer
	gl.UseProgram(app.sp_compute)
	gl.DispatchCompute(COMPUTE_RENDER_WIDTH/10, COMPUTE_RENDER_WIDTH/10, 1)
	gl.MemoryBarrier(gl.SHADER_IMAGE_ACCESS_BARRIER_BIT)

	// Run screen shader to draw the colorbuffer to the framebuffer
	gl.Enable(gl.DEPTH_TEST)
	gl.UseProgram(app.sp_screen)
	gl.DrawArrays(gl.TRIANGLE_FAN, 0, 4)
	
	// Swap buffers (present the framebuffer)
	glfw.SwapBuffers(app.window)
	gl_check_error()
}

exit :: proc(app: ^App) {
	gl.DeleteProgram(app.sp_screen)
	gl.DeleteProgram(app.sp_compute)
	gl.DeleteVertexArrays(1, &app.vao)
	gl.DeleteBuffers(1, &app.vbo)
	gl.DeleteTextures(1, &app.colorbuf_tex)
	glfw.Terminate()
}
