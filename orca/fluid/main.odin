package src

/*
Original Source: https://github.com/orca-app/orca/blob/main/samples/fluid/src/main.c

Can be run using in the local folder
1. odin.exe build main.odin -file -target:orca_wasm32 -out:module.wasm 
2. orca bundle --name orca_output --resource-dir data module.wasm
3. orca_output\bin\orca_output.exe
*/

import "base:runtime"
import "core:math"
import "core:strings"
import oc "core:sys/orca"
import gl "core:sys/orca/graphics"

glsl_common_vertex :: #load("shaders/common_vertex.glsl")
glsl_advect :: #load("shaders/advect.glsl")
glsl_divergence :: #load("shaders/divergence.glsl")
glsl_jacobi_step :: #load("shaders/jacobi_step.glsl")
glsl_multigrid_restrict_residual :: #load("shaders/multigrid_restrict_residual.glsl")
glsl_multigrid_correct :: #load("shaders/multigrid_correct.glsl")
glsl_subtract_pressure :: #load("shaders/subtract_pressure.glsl")
glsl_splat :: #load("shaders/splat.glsl")
glsl_blit_vertex :: #load("shaders/blit_vertex.glsl")
glsl_blit_fragment :: #load("shaders/blit_fragment.glsl")
glsl_blit_div_vertex :: #load("shaders/blit_div_vertex.glsl")
glsl_blit_div_fragment :: #load("shaders/blit_div_fragment.glsl")
glsl_blit_residue_fragment :: #load("shaders/blit_div_vertex.glsl")

//----------------------------------------------------------------
//NOTE(martin): GL vertex struct and identifiers
//----------------------------------------------------------------
Vertex :: [2]f32

GLenum :: u32
GLuint :: u32
GLint :: i32

advect_program :: struct #packed {
	prog:        GLuint,
	pos:         GLint,
	src:         GLint,
	velocity:    GLint,
	delta:       GLint,
	dissipation: GLint,
}

div_program :: struct #packed {
	prog: GLuint,
	pos:  GLint,
	src:  GLint,
}

jacobi_program :: struct #packed {
	prog: GLuint,
	pos:  GLint,
	xTex: GLint,
	bTex: GLint,
}

blit_residue_program :: struct #packed {
	prog: GLuint,
	pos:  GLint,
	mvp:  GLint,
	xTex: GLint,
	bTex: GLint,
}

multigrid_restrict_residual_program :: struct #packed {
	prog: GLuint,
	pos:  GLint,
	xTex: GLint,
	bTex: GLint,
}

multigrid_correct_program :: struct #packed {
	prog:        GLuint,
	pos:         GLint,
	src:         GLint,
	error:       GLint,
	invGridSize: GLint,
}

subtract_program :: struct #packed {
	prog:        GLuint,
	pos:         GLint,
	src:         GLint,
	pressure:    GLint,
	invGridSize: GLint,
}

blit_program :: struct #packed {
	prog:     GLuint,
	pos:      GLint,
	mvp:      GLint,
	gridSize: GLint,
	tex:      GLint,
}

splat_program :: struct #packed {
	prog:       GLuint,
	pos:        GLint,
	src:        GLint,
	splatPos:   GLint,
	splatColor: GLint,
	radius:     GLint,
	additive:   GLint,
	blending:   GLint,
	randomize:  GLint,
}

frame_buffer :: struct #packed {
	textures: [2]GLuint,
	fbos:     [2]GLuint,
}

advectProgram: advect_program
divProgram: div_program
jacobiProgram: jacobi_program
multigridRestrictResidualProgram: multigrid_restrict_residual_program
multigridCorrectProgram: multigrid_correct_program

subtractProgram: subtract_program
splatProgram: splat_program
blitProgram: blit_program
blitDivProgram: blit_program
blitResidueProgram: blit_residue_program

colorBuffer: frame_buffer
velocityBuffer: frame_buffer

MULTIGRID_COUNT :: 4
pressureBuffer: [4]frame_buffer
divBuffer: [4]frame_buffer

vertexBuffer: GLuint

surface: oc.surface
startTime: f64

//----------------------------------------------------------------
//NOTE(martin): initialization
//----------------------------------------------------------------

compile_shader :: proc(vs, fs: []u8) -> GLuint {
	vs := cstring(raw_data(vs))
	fs := cstring(raw_data(fs))

	vertexShader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertexShader, 1, &vs, nil)
	gl.CompileShader(vertexShader)

	fragmentShader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragmentShader, 1, &fs, nil)
	gl.CompileShader(fragmentShader)

	prog := gl.CreateProgram()
	gl.AttachShader(prog, vertexShader)
	gl.AttachShader(prog, fragmentShader)
	gl.LinkProgram(prog)

	status: i32
	gl.GetProgramiv(prog, gl.LINK_STATUS, &status)
	if status != 1 {
		oc.log_error("program failed to link: ")
		logSize: i32
		gl.GetProgramiv(prog, gl.INFO_LOG_LENGTH, &logSize)

		scratch := oc.scratch_begin()
		log := oc.arena_push(scratch.arena, u64(logSize))

		gl.GetProgramInfoLog(prog, logSize, nil, cast([^]u8)log)
		log_full := strings.string_from_ptr(cast(^u8)log, int(logSize))
		oc.log_errorf("%s\n", log_full)

		oc.scratch_end(scratch)
	}

	err := gl.GetError()
	if err != 0 {
		oc.log_errorf("gl. error %i\n", err)
	}

	return prog
}

init_advect :: proc(program: ^advect_program) {
	oc.log_info("compiling advect...")
	program.prog = compile_shader(glsl_common_vertex, glsl_advect)
	program.pos = gl.GetAttribLocation(program.prog, "pos")
	program.src = gl.GetUniformLocation(program.prog, "src")
	program.velocity = gl.GetUniformLocation(program.prog, "velocity")
	program.delta = gl.GetUniformLocation(program.prog, "delta")
	program.dissipation = gl.GetUniformLocation(program.prog, "dissipation")
}

init_div :: proc(program: ^div_program) {
	oc.log_info("compiling div...")
	program.prog = compile_shader(glsl_common_vertex, glsl_divergence)
	program.pos = gl.GetAttribLocation(program.prog, "pos")
	program.src = gl.GetUniformLocation(program.prog, "src")
}

init_jacobi :: proc(program: ^jacobi_program) {
	oc.log_info("compiling jacobi...")
	program.prog = compile_shader(glsl_common_vertex, glsl_jacobi_step)
	program.pos = gl.GetAttribLocation(program.prog, "pos")
	program.xTex = gl.GetUniformLocation(program.prog, "xTex")
	program.bTex = gl.GetUniformLocation(program.prog, "bTex")
}

init_multigrid_restrict_residual :: proc(program: ^multigrid_restrict_residual_program) {
	oc.log_info("compiling multigrid restrict residual...")
	program.prog = compile_shader(glsl_common_vertex, glsl_multigrid_restrict_residual)
	program.pos = gl.GetAttribLocation(program.prog, "pos")
	program.xTex = gl.GetUniformLocation(program.prog, "xTex")
	program.bTex = gl.GetUniformLocation(program.prog, "bTex")
}

init_multigrid_correct :: proc(program: ^multigrid_correct_program) {
	oc.log_info("compiling multigrid correct...")
	program.prog = compile_shader(glsl_common_vertex, glsl_multigrid_correct)
	program.pos = gl.GetAttribLocation(program.prog, "pos")
	program.src = gl.GetUniformLocation(program.prog, "src")
	program.error = gl.GetUniformLocation(program.prog, "error")
	program.invGridSize = gl.GetUniformLocation(program.prog, "invGridSize")
}

init_subtract :: proc(program: ^subtract_program) {
	oc.log_info("compiling subtract...")
	program.prog = compile_shader(glsl_common_vertex, glsl_subtract_pressure)
	program.pos = gl.GetAttribLocation(program.prog, "pos")
	program.src = gl.GetUniformLocation(program.prog, "src")
	program.pressure = gl.GetUniformLocation(program.prog, "pressure")
	program.invGridSize = gl.GetUniformLocation(program.prog, "invGridSize")
}

init_splat :: proc(program: ^splat_program) {
	oc.log_info("compiling splat...")
	program.prog = compile_shader(glsl_common_vertex, glsl_splat)
	program.pos = gl.GetAttribLocation(program.prog, "pos")
	program.src = gl.GetUniformLocation(program.prog, "src")
	program.splatPos = gl.GetUniformLocation(program.prog, "splatPos")
	program.splatColor = gl.GetUniformLocation(program.prog, "splatColor")
	program.radius = gl.GetUniformLocation(program.prog, "radius")
	program.additive = gl.GetUniformLocation(program.prog, "additive")
	program.blending = gl.GetUniformLocation(program.prog, "blending")
	program.randomize = gl.GetUniformLocation(program.prog, "randomize")
}

init_blit :: proc(program: ^blit_program) {
	oc.log_info("compiling blit...")
	program.prog = compile_shader(glsl_blit_vertex, glsl_blit_fragment)
	program.pos = gl.GetAttribLocation(program.prog, "pos")
	program.mvp = gl.GetUniformLocation(program.prog, "mvp")
	program.tex = gl.GetUniformLocation(program.prog, "tex")
	program.gridSize = gl.GetUniformLocation(program.prog, "gridSize")
}

init_blit_div :: proc(program: ^blit_program) {
	oc.log_info("compiling blit div...")
	program.prog = compile_shader(glsl_blit_div_vertex, glsl_blit_div_fragment)
	program.pos = gl.GetAttribLocation(program.prog, "pos")
	program.mvp = gl.GetUniformLocation(program.prog, "mvp")
	program.tex = gl.GetUniformLocation(program.prog, "tex")
}

init_blit_residue :: proc(program: ^blit_residue_program) {
	oc.log_info("compiling blit residue...")
	program.prog = compile_shader(glsl_blit_div_vertex, glsl_blit_residue_fragment)
	program.pos = gl.GetAttribLocation(program.prog, "pos")
	program.mvp = gl.GetUniformLocation(program.prog, "mvp")
	program.xTex = gl.GetUniformLocation(program.prog, "xTex")
	program.bTex = gl.GetUniformLocation(program.prog, "bTex")
}

create_texture :: proc(
	width, height: i32,
	internalFormat, format, type: GLenum,
	initData: [^]u8,
) -> (
	texture: GLuint,
) {
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, i32(internalFormat), width, height, 0, format, type, initData)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	return
}

create_fbo :: proc(texture: GLuint) -> (fbo: GLuint) {
	gl.GenFramebuffers(1, &fbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0)
	return
}

init_frame_buffer :: proc(
	framebuffer: ^frame_buffer,
	width: i32,
	height: i32,
	internalFormat: GLenum,
	format: GLenum,
	type: GLenum,
	initData: [^]u8,
) {
	for i in 0 ..< 2 {
		framebuffer.textures[i] = create_texture(
			width,
			height,
			internalFormat,
			format,
			type,
			initData,
		)
		framebuffer.fbos[i] = create_fbo(framebuffer.textures[i])
	}

	err := gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
	if err != gl.FRAMEBUFFER_COMPLETE {
		oc.log_infof("Frame buffer incomplete, %i", err)
	}
}

frame_buffer_swap :: proc(buffer: ^frame_buffer) {
	buffer.fbos[0], buffer.fbos[1] = buffer.fbos[1], buffer.fbos[0]
	buffer.textures[0], buffer.textures[1] = buffer.textures[1], buffer.textures[0]
}

//----------------------------------------------------------------
//NOTE(martin): entry point
//----------------------------------------------------------------

texWidth :: 256
texHeight :: 256

colorInitData: [texWidth * texHeight][4]f32
velocityInitData: [texWidth * texHeight][4]f32

EPSILON :: f32(1)
INV_GRID_SIZE :: f32(1) / f32(texWidth)
DELTA :: f32(1) / 120

TEX_INTERNAL_FORMAT :: gl.RGBA32F
TEX_FORMAT :: gl.RGBA
TEX_TYPE :: gl.FLOAT

square :: proc(x: f32) -> f32 {
	return x * x
}

mouse_input :: struct {
	x:      f32,
	y:      f32,
	deltaX: f32,
	deltaY: f32,
	down:   bool,
}

mouseInput: mouse_input
mouseWasDown := false

frameWidth := f32(800)
frameHeight := f32(600)

@(export)
oc_on_mouse_down :: proc "c" (button: i32) {
	mouseInput.down = true
	mouseWasDown = true
}

@(export)
oc_on_mouse_up :: proc "c" (button: i32) {
	mouseInput.down = false
}

@(export)
oc_on_mouse_move :: proc "c" (x, y, dx, dy: f32) {
	mouseInput.x = x
	mouseInput.y = y
	mouseInput.deltaX = dx
	mouseInput.deltaY = dy
}

init_color_checker :: proc() {
	for i in 0 ..< texHeight {
		for j in 0 ..< texWidth {
			u := f32(j) / f32(texWidth)
			v := f32(i) / f32(texWidth)
			value := f32((int(u * 10) % 2) == (int(v * 10) % 2) ? 1. : 0.)

			index := i * texHeight + j
			colorInitData[index] = {value, value, value, 1}
		}
	}
}

init_velocity_vortex :: proc() {
	for i in 0 ..< texHeight {
		for j in 0 ..< texWidth {
			x := 2 * f32(j) / f32(texWidth) - 1
			y := 2 * f32(i) / f32(texWidth) - 1

			index := i * texHeight + j
			velocityInitData[index].xy = {math.sin(2 * math.PI * y), math.sin(2 * math.PI * x)}
		}
	}
}

apply_splat :: proc(
	splatPosX: f32,
	splatPosY: f32,
	radius: f32,
	splatVelX: f32,
	splatVelY: f32,
	r: f32,
	g: f32,
	b: f32,
	randomize: bool,
) {
	gl.UseProgram(splatProgram.prog)

	if randomize {
		gl.Uniform1f(splatProgram.randomize, 1.)
	} else {
		gl.Uniform1f(splatProgram.randomize, 0.)
	}

	// force
	gl.BindFramebuffer(gl.FRAMEBUFFER, velocityBuffer.fbos[1])

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, velocityBuffer.textures[0])
	gl.Uniform1i(splatProgram.src, 0)

	gl.Uniform2f(splatProgram.splatPos, splatPosX, splatPosY)
	gl.Uniform3f(splatProgram.splatColor, splatVelX, splatVelY, 0)
	gl.Uniform1f(splatProgram.additive, 1)
	gl.Uniform1f(splatProgram.blending, 0)

	gl.Uniform1f(splatProgram.radius, radius)

	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	frame_buffer_swap(&velocityBuffer)

	// dye
	gl.BindFramebuffer(gl.FRAMEBUFFER, colorBuffer.fbos[1])

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, colorBuffer.textures[0])
	gl.Uniform1i(splatProgram.src, 0)

	gl.Uniform2f(splatProgram.splatPos, splatPosX, splatPosY)
	gl.Uniform3f(splatProgram.splatColor, r, g, b)
	gl.Uniform1f(splatProgram.additive, 0)
	gl.Uniform1f(splatProgram.blending, 1)
	gl.Uniform1f(splatProgram.radius, radius)

	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	frame_buffer_swap(&colorBuffer)
}

jacobi_solve :: proc(x, b: ^frame_buffer, invGridSize: f32, iterationCount: int) {
	gl.UseProgram(jacobiProgram.prog)

	for i in 0 ..< iterationCount {
		gl.BindFramebuffer(gl.FRAMEBUFFER, x.fbos[1])

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, x.textures[0])
		gl.Uniform1i(jacobiProgram.xTex, 0)

		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, b.textures[0])
		gl.Uniform1i(jacobiProgram.bTex, 1)

		gl.DrawArrays(gl.TRIANGLES, 0, 6)

		frame_buffer_swap(x)
	}
}

multigrid_coarsen_residual :: proc(output, x, b: ^frame_buffer, invFineGridSize: f32) {
	//NOTE: compute residual and downsample to coarser grid, put result in coarser buffer
	gl.UseProgram(multigridRestrictResidualProgram.prog)
	gl.BindFramebuffer(gl.FRAMEBUFFER, output.fbos[1])

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, x.textures[0])
	gl.Uniform1i(multigridRestrictResidualProgram.xTex, 0)

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, b.textures[0])
	gl.Uniform1i(multigridRestrictResidualProgram.bTex, 1)

	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	frame_buffer_swap(output)
}

multigrid_prolongate_and_correct :: proc(x, error: ^frame_buffer, invFineGridSize: f32) {
	//NOTE: correct finer pressure
	gl.UseProgram(multigridCorrectProgram.prog)
	gl.BindFramebuffer(gl.FRAMEBUFFER, x.fbos[1])

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, x.textures[0])
	gl.Uniform1i(multigridCorrectProgram.src, 0)

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, error.textures[0])
	gl.Uniform1i(multigridCorrectProgram.error, 1)

	gl.Uniform1f(multigridCorrectProgram.invGridSize, invFineGridSize)

	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	frame_buffer_swap(x)
}

multigrid_clear :: proc(error: ^frame_buffer) {
	gl.BindFramebuffer(gl.FRAMEBUFFER, error.fbos[0])
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

input_splat :: proc(t: f32) {
	applySplat := false
	x, y, deltaX, deltaY: f32
	@(static)
	lastFrameTime := f64(0)
	if lastFrameTime == 0 {
		lastFrameTime = startTime
	}
	now := oc.clock_time(.MONOTONIC)
	frameDuration := now - lastFrameTime
	lastFrameTime = now

	if mouseInput.down && (mouseInput.deltaX != 0 || mouseInput.deltaY != 0) {
		scaling := oc.surface_contents_scaling(surface)
		applySplat = true
		x = mouseInput.x * scaling.x / frameWidth
		y = mouseInput.y * scaling.y / frameHeight
		deltaX = 1. / 60 / f32(frameDuration) * mouseInput.deltaX * scaling.x / frameWidth
		deltaY = 1. / 60 / f32(frameDuration) * mouseInput.deltaY * scaling.y / frameHeight
		mouseInput.deltaX = 0
		mouseInput.deltaY = 0
	}

	timeSinceStart := now - startTime
	if !mouseWasDown && timeSinceStart < 1 {
		applySplat = true
		totalDeltaX := f32(0.5)
		x = 0.1 + totalDeltaX * f32(timeSinceStart)
		y = 0.5
		deltaX = totalDeltaX / 180
		deltaY = 0
	}

	//NOTE: apply force and dye
	if applySplat {
		// account for margin
		margin := f32(32)

		offset := margin / f32(texWidth)
		ratio := 1 - 2 * margin / f32(texWidth)

		splatPosX := x * ratio + offset
		splatPosY := (1 - y) * ratio + offset

		splatVelX := (10000. * DELTA * deltaX) * ratio
		splatVelY := (-10000. * DELTA * deltaY) * ratio

		intensity := 100 * math.sqrt(square(ratio * deltaX) + square(ratio * deltaY))

		r := intensity * (math.sin(2 * math.PI * 0.1 * t) + 1)
		g := 0.5 * intensity * (math.cos(2 * math.PI * 0.1 / math.e * t + 654) + 1)
		b := intensity * (math.sin(2 * math.PI * 0.1 / math.SQRT_TWO * t + 937) + 1)

		radius := 0.005

		apply_splat(
			splatPosX,
			splatPosY,
			f32(radius),
			f32(splatVelX),
			f32(splatVelY),
			r,
			g,
			b,
			false,
		)
	}
}

testDiv: [texWidth / 2][texWidth / 2][4]f32

main :: proc() {
	oc.log_info("Hello, world (from C)")

	oc.window_set_title("fluid")

	surface = oc.gles_surface_create()
	oc.gles_surface_make_current(surface)

	//	init_color_checker()
	//	init_velocity_vortex()

	// init programs
	context = runtime.default_context()
	init_advect(&advectProgram)
	init_div(&divProgram)
	init_jacobi(&jacobiProgram)
	init_multigrid_restrict_residual(&multigridRestrictResidualProgram)
	init_multigrid_correct(&multigridCorrectProgram)
	init_blit_residue(&blitResidueProgram)

	init_subtract(&subtractProgram)
	init_splat(&splatProgram)
	init_blit(&blitProgram)
	init_blit_div(&blitDivProgram)

	// init frame buffers
	oc.log_info("create color buffer")
	init_frame_buffer(
		&colorBuffer,
		texWidth,
		texHeight,
		TEX_INTERNAL_FORMAT,
		TEX_FORMAT,
		TEX_TYPE,
		cast([^]u8)&colorInitData[0],
	)
	oc.log_info("create velocity buffer")
	init_frame_buffer(
		&velocityBuffer,
		texWidth,
		texHeight,
		TEX_INTERNAL_FORMAT,
		TEX_FORMAT,
		TEX_TYPE,
		cast([^]u8)&velocityInitData[0],
	)

	gridFactor := 1
	for i in 0 ..< MULTIGRID_COUNT {
		oc.log_infof("create div buffer %i", i)
		init_frame_buffer(
			&divBuffer[i],
			i32(texWidth / gridFactor),
			i32(texHeight / gridFactor),
			TEX_INTERNAL_FORMAT,
			TEX_FORMAT,
			TEX_TYPE,
			nil,
		)
		oc.log_infof("create pressure buffer %i", i)
		init_frame_buffer(
			&pressureBuffer[i],
			i32(texWidth / gridFactor),
			i32(texHeight / gridFactor),
			TEX_INTERNAL_FORMAT,
			TEX_FORMAT,
			TEX_TYPE,
			nil,
		)
		gridFactor *= 2
	}

	// init vertex buffer
	@(static)
	vertices := [?]Vertex{{-1, -1}, {1, -1}, {1, 1}, {-1, -1}, {1, 1}, {-1, 1}}

	//WARN: we assume blitProgram.pos == advectProgram.pos, is there a situation where it wouldn't be true??
	vertexBuffer: GLuint
	gl.GenBuffers(1, &vertexBuffer)
	gl.BindBuffer(gl.ARRAY_BUFFER, vertexBuffer)
	gl.BufferData(gl.ARRAY_BUFFER, 6 * size_of(Vertex), &vertices[0], gl.STATIC_DRAW)

	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(u32(blitProgram.pos), 2, gl.FLOAT, gl.FALSE, 0, 0)

	for i in 0 ..< texWidth / 2 {
		for j in 0 ..< texHeight / 2 {
			testDiv[i][j][0] =
				0.5 + 0.5 * math.cos(f32(j) / 100. * 3.14159 + f32(i) / 100. * 1.2139)
		}
	}

	startTime = oc.clock_time(.MONOTONIC)
}

@(export)
oc_on_resize :: proc "c" (width, height: u32) {
	scaling := oc.surface_contents_scaling(surface)
	frameWidth = f32(width) * scaling.x
	frameHeight = f32(height) * scaling.y
}

@(export)
oc_on_frame_refresh :: proc "c" () {
	aspectRatio := f32(texWidth) / f32(texHeight)

	@(static)
	t := f32(0)
	t += 1. / 60.

	oc.gles_surface_make_current(surface)

	gl.Viewport(0, 0, texWidth, texHeight)

	//NOTE: advect velocity thru itself
	gl.UseProgram(advectProgram.prog)
	gl.BindFramebuffer(gl.FRAMEBUFFER, velocityBuffer.fbos[1])

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, velocityBuffer.textures[0])
	gl.Uniform1i(advectProgram.src, 0)

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, velocityBuffer.textures[0])
	gl.Uniform1i(advectProgram.velocity, 1)

	gl.Uniform1f(advectProgram.delta, DELTA)
	gl.Uniform1f(advectProgram.dissipation, 0.01)

	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	context = runtime.default_context()
	frame_buffer_swap(&velocityBuffer)

	input_splat(t)

	//NOTE: compute divergence of advected velocity
	gl.UseProgram(divProgram.prog)
	gl.BindFramebuffer(gl.FRAMEBUFFER, divBuffer[0].fbos[1])

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, velocityBuffer.textures[0])
	gl.Uniform1i(divProgram.src, 0)

	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	frame_buffer_swap(&divBuffer[0])

	//NOTE: compute pressure
	gl.BindFramebuffer(gl.FRAMEBUFFER, pressureBuffer[0].fbos[1])
	gl.Clear(gl.COLOR_BUFFER_BIT)

	// #if 0
	// 		multigrid_clear(&pressureBuffer[0])
	// 		jacobi_solve(&pressureBuffer[0], &divBuffer[0], INV_GRID_SIZE, texWidth*texHeight)
	// #else
	multigrid_clear(&pressureBuffer[0])

	for i in 0 ..< 1 {
		jacobi_solve(&pressureBuffer[0], &divBuffer[0], INV_GRID_SIZE, 2)
		multigrid_coarsen_residual(&divBuffer[1], &pressureBuffer[0], &divBuffer[0], INV_GRID_SIZE)

		multigrid_clear(&pressureBuffer[1])
		jacobi_solve(&pressureBuffer[1], &divBuffer[1], 2 * INV_GRID_SIZE, 2)
		multigrid_coarsen_residual(
			&divBuffer[2],
			&pressureBuffer[1],
			&divBuffer[1],
			2 * INV_GRID_SIZE,
		)

		multigrid_clear(&pressureBuffer[2])
		jacobi_solve(&pressureBuffer[2], &divBuffer[2], 4 * INV_GRID_SIZE, 30)

		multigrid_prolongate_and_correct(&pressureBuffer[1], &pressureBuffer[2], 2 * INV_GRID_SIZE)
		jacobi_solve(&pressureBuffer[1], &divBuffer[1], 2 * INV_GRID_SIZE, 8)

		multigrid_prolongate_and_correct(&pressureBuffer[0], &pressureBuffer[1], INV_GRID_SIZE)
		jacobi_solve(&pressureBuffer[0], &divBuffer[0], INV_GRID_SIZE, 4)
	}
	// #endif

	//NOTE: subtract pressure gradient to advected velocity
	gl.UseProgram(subtractProgram.prog)
	gl.BindFramebuffer(gl.FRAMEBUFFER, velocityBuffer.fbos[1])

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, velocityBuffer.textures[0])
	gl.Uniform1i(subtractProgram.src, 0)

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, pressureBuffer[0].textures[0])
	gl.Uniform1i(subtractProgram.pressure, 1)

	gl.Uniform1f(subtractProgram.invGridSize, INV_GRID_SIZE)

	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	frame_buffer_swap(&velocityBuffer)

	//NOTE: Advect color through corrected velocity field
	gl.UseProgram(advectProgram.prog)
	gl.BindFramebuffer(gl.FRAMEBUFFER, colorBuffer.fbos[1])

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, colorBuffer.textures[0])
	gl.Uniform1i(advectProgram.src, 0)

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, velocityBuffer.textures[0])
	gl.Uniform1i(advectProgram.velocity, 1)

	gl.Uniform1f(advectProgram.delta, DELTA)

	gl.Uniform1f(advectProgram.dissipation, 0.001)

	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	frame_buffer_swap(&colorBuffer)

	//NOTE: Blit color texture to screen

	gl.Viewport(0, 0, i32(frameWidth), i32(frameHeight))

	displayMatrix := [16]f32{1.0 / aspectRatio, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}

	gl.UseProgram(blitProgram.prog)
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, colorBuffer.textures[0])
	gl.Uniform1i(blitProgram.tex, 0)

	gl.Uniform2i(blitProgram.gridSize, texWidth, texHeight)

	gl.UniformMatrix4fv(blitProgram.mvp, 1, gl.FALSE, &displayMatrix[0])

	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	oc.gles_surface_swap_buffers(surface)
}
