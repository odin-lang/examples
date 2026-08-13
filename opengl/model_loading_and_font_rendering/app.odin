package main
import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "vendor:glfw"
import gl "vendor:OpenGL"

App :: struct {
	window:                glfw.WindowHandle,
	sp_solid:              u32,
	sp_font:               u32,
	sp_light:              u32,
	font_tex:              u32,
	font_vao:              u32,
	font_vbo:              u32,
	font_chars:            ^[FONT_MAX_CHARS]u32,
	ambient_light:         [3]f32,
	dir_light:             Directional_Light,
	point_light:           Point_Light,
	camera:                Camera,
	primitives:            ^[Primitive]Mesh,
	meshes:                [dynamic]Mesh,
	materials:             [dynamic]Material,
	models:                [dynamic]Model,
	frame:                 u32,
	time:                  f64,
	prev_time:             f64,
	dt:                    f64,
	fps:                   u32,
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
		glfw.Terminate()
		log.fatal("GLFW window creation failed.")
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
	
	// Load shaders
	app.sp_solid = gl_shader_load_vs_fs(SHADER_SOLID_VERT, SHADER_SOLID_FRAG)
	app.sp_font  = gl_shader_load_vs_fs(SHADER_FONT_VERT, SHADER_FONT_FRAG)
	app.sp_light = gl_shader_load_vs_fs(SHADER_LIGHT_VERT, SHADER_LIGHT_FRAG)

	// Load primitive meshes
	mesh_load_primitives(app.primitives)
	
	// Font setup
	app.font_chars = new([FONT_MAX_CHARS]u32)
	app.font_tex = gl_texture_load(FONT_PATH, filtering = false)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, app.font_tex)
	gl.GenVertexArrays(1, &app.font_vao)
	gl.BindVertexArray(app.font_vao)
	gl.GenBuffers(1, &app.font_vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, app.font_vbo)
	gl.BufferData(gl.ARRAY_BUFFER, FONT_MAX_CHARS * size_of(u32), nil, gl.DYNAMIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribIPointer(0, 1, gl.UNSIGNED_INT, size_of(u32), 0)
	gl.VertexAttribDivisor(0, 1)
	gl.BindVertexArray(0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.UseProgram(app.sp_font)
	gl_shader_set_float(app.sp_font, "spacing", FONT_SPACING)
	gl_shader_set_vec2_copy(app.sp_font, "ndc_pixel", {2.0 / WINDOW_WIDTH, 2.0 / WINDOW_HEIGHT})
	gl_shader_set_vec2_copy(app.sp_font, "size", {FONT_WIDTH, FONT_HEIGHT})
	gl_shader_set_int(app.sp_font, "font_tex", 1)
}

input :: proc(app: ^App) {
	if glfw.GetKey(app.window, glfw.KEY_ESCAPE) == glfw.PRESS { glfw.SetWindowShouldClose(app.window, true) }
}

update :: proc(app: ^App) {
	// Update timekeeping variables
	app.time = glfw.GetTime()
	app.dt = app.time - app.prev_time
	if app.dt > 0.0 && app.frame % 60 == 0 {
		app.fps = u32(1.0 / app.dt)
	}
	app.prev_time = app.time
	app.frame += 1

	// Update light color / position and model rotation
	col: glsl.vec3 = {f32(math.sin_f64(glfw.GetTime() * 0.2)), f32(math.sin_f64(glfw.GetTime() * 0.3)), f32(math.sin_f64(glfw.GetTime() * 0.4))}
	app.point_light.pos.z = math.cos_f32(f32(glfw.GetTime() * 0.2)) * 2 - 5
	app.point_light.pos.x = math.sin_f32(f32(glfw.GetTime() * 0.2)) * 2
	app.point_light.pos.y = math.cos_f32(f32(glfw.GetTime() * 1.5)) * 0.5 + 1
	app.point_light.diffuse  = col * 0.3 + 0.5
	app.point_light.specular = col * 0.5 + 0.5
	app.models[0].rot = {math.PI / 2, 0, 0} + {0, 0, -1} * f32(glfw.GetTime()) * glsl.radians_f32(20.0)
}


render :: proc(app: ^App) {
	// Clear screen
	gl.ClearColor(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	gl.Enable(gl.DEPTH_TEST)
	gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	
	// Set projection and view matrix
	projection_mat := glsl.mat4Perspective(glsl.radians_f32(app.camera.fov), f32(f32(WINDOW_WIDTH) / f32(WINDOW_HEIGHT)), CAM_CLIP_NEAR, CAM_CLIP_FAR)
	view_mat := glsl.mat4LookAt(app.camera.pos, app.camera.pos + app.camera.forward, app.camera.up)

	// Render models
	gl.UseProgram(app.sp_solid)
	gl_shader_set_mat4(app.sp_solid,  "projection_mat", projection_mat)
	gl_shader_set_mat4(app.sp_solid,  "view_mat", view_mat)
	gl_shader_set_vec3(app.sp_solid,  "view_pos", app.camera.pos)
	gl_shader_set_vec3(app.sp_solid,  "ambient_light", app.ambient_light)
	gl_shader_set_vec3(app.sp_solid,  "dir_light.dir", app.dir_light.dir)
	gl_shader_set_vec3(app.sp_solid,  "dir_light.diffuse", app.dir_light.diffuse)
	gl_shader_set_vec3(app.sp_solid,  "dir_light.specular", app.dir_light.specular)
	gl_shader_set_vec3(app.sp_solid,  "point_light.pos",       app.point_light.pos)
	gl_shader_set_vec3(app.sp_solid,  "point_light.diffuse",   app.point_light.diffuse)
	gl_shader_set_vec3(app.sp_solid,  "point_light.specular",  app.point_light.specular)
	gl_shader_set_float(app.sp_solid, "point_light.constant",  app.point_light.constant)
	gl_shader_set_float(app.sp_solid, "point_light.linear",    app.point_light.linear)
	gl_shader_set_float(app.sp_solid, "point_light.quadratic", app.point_light.quadratic)
	for &model in app.models {
		model_render(&model, app.sp_solid)
	}

	// Render point light
	gl.UseProgram(app.sp_light)
	gl_shader_set_mat4(app.sp_light, "projection_mat", projection_mat)
	gl_shader_set_mat4(app.sp_light, "view_mat", view_mat)
	point_light_render(&app.point_light, app.sp_light, &app.primitives[.Cube])

	// Render font
	gl.Disable(gl.DEPTH_TEST)
	gl.UseProgram(app.sp_font)
	gl.BindVertexArray(app.font_vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, app.font_vbo)
	font_draw({2, 0}, app.fps, app.fps >= 50 ? {0.2, 0.8, 0.2} : (app.fps >= 30 ? {0.8, 0.8, 0.2} : {0.8, 0.2, 0.2} ), app.font_chars, app.sp_font)
	font_draw({2, WINDOW_HEIGHT - FONT_HEIGHT}, "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~", 1, app.font_chars, app.sp_font)
	gl.BindVertexArray(0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
 
	// Swap buffers (present the framebuffer)
	glfw.SwapBuffers(app.window)
	gl_check_error()
}


exit :: proc(app: ^App) {
	free(app.font_chars)
	gl.DeleteProgram(app.sp_solid)
	gl.DeleteProgram(app.sp_font)
	gl.DeleteProgram(app.sp_light)
	gl.DeleteTextures(1, &app.font_tex)
	for &mesh in app.primitives {
		mesh_destroy(&mesh)
	}
	for &mesh in app.meshes {
		mesh_destroy(&mesh)
	}
	free(app.primitives)
	delete(app.meshes)
	delete(app.materials)
	delete(app.models)
	glfw.Terminate()
}
