package src

/*
Original Source: https://github.com/orca-app/orca/blob/main/samples/triangle/src/main.c

Can be run using in the local folder
1. odin.exe build main.odin -file -target:orca_wasm32 -out:module.wasm 
2. orca bundle --name orca_output --resource-dir data module.wasm
3. orca_output\bin\orca_output.exe
*/

import "base:runtime"
import "core:math"
import oc "core:sys/orca"
import gl "core:sys/orca/graphics"

frameSize := oc.vec2{100, 100}
surface: oc.surface
program: u32

vshaderSource := `
attribute vec4 vPosition;
uniform mat4 transform;
void main() {
   gl_Position = transform*vPosition;
}
`

fshaderSource := `
precision mediump float;
void main()
{
    gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
`

compile_shader :: proc "c" (shader: u32, source: string) {
	shader_data_copy := cstring(raw_data(source))
	gl.ShaderSource(shader, 1, &shader_data_copy, nil)
	gl.CompileShader(shader)

	err := gl.GetError()
	if err != 0 {
		oc.log_info("gl error")
	}
}

main :: proc() {
	context = runtime.default_context()
	oc.window_set_title("triangle")

	surface = oc.gles_surface_create()
	oc.gles_surface_make_current(surface)

	extensionCount := i32(0)
	gl.GetIntegerv(gl.NUM_EXTENSIONS, &extensionCount)
	for i in 0 ..< extensionCount {
		extension := cast([^]u8)gl.GetStringi(gl.EXTENSIONS, u32(i))
		oc.log_infof("gl.ES extension %i: %s\n", i, extension)
	}

	vshader := gl.CreateShader(gl.VERTEX_SHADER)
	fshader := gl.CreateShader(gl.FRAGMENT_SHADER)
	program = gl.CreateProgram()

	compile_shader(vshader, vshaderSource)
	compile_shader(fshader, fshaderSource)

	gl.AttachShader(program, vshader)
	gl.AttachShader(program, fshader)
	gl.LinkProgram(program)
	gl.UseProgram(program)

	vertices := []f32{-0.866 / 2, -0.5 / 2, 0, 0.866 / 2, -0.5 / 2, 0, 0, 0.5, 0}

	buffer: u32
	gl.GenBuffers(1, &buffer)
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
	gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(f32), &vertices[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 0, 0)
	gl.EnableVertexAttribArray(0)
}

@(export)
oc_on_resize :: proc "c" (width, height: u32) {
	context = runtime.default_context()
	oc.log_infof("frame resize %v, %v", width, height)
	frameSize.x = f32(width)
	frameSize.y = f32(height)
}

@(export)
oc_on_frame_refresh :: proc "c" () {
	aspect := frameSize.x / frameSize.y

	oc.gles_surface_make_current(surface)

	gl.ClearColor(0, 1, 1, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	@(static)
	alpha := f32(0)

	scaling := oc.surface_contents_scaling(surface)

	gl.Viewport(0, 0, i32(frameSize.x * scaling.x), i32(frameSize.y * scaling.y))

	//odinfmt:disable
	mat := [?]f32 {
		math.cos(alpha) / aspect,
		math.sin(alpha),
		0,
		0,
		-math.sin(alpha) / aspect,
		math.cos(alpha),
		0,
		0,
		0,
		0,
		1,
		0,
		0,
		0,
		0,
		1,
	}
	alpha += 2 * math.PI / 120

	gl.UniformMatrix4fv(0, 1, false, &mat[0])
	gl.DrawArrays(gl.TRIANGLES, 0, 3)
	oc.gles_surface_swap_buffers(surface)
}
