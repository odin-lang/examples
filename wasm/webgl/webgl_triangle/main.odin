// Shows how to draw a triangle using WASM + WebGL. Build using the build_web script. Note that
// there is an index.html in the web folder and that the `odin.js` runtime file will be copied from
// the Odin core folder into the web folder (by the build_web script).

package webgl_triangle

import "core:sys/wasm/js"
import gl "vendor:wasm/WebGL"

// The ID of the element in web/index.html to draw into
CANVAS_ID :: "webgl-canvas"

shader: gl.Program
vertex_buffer: gl.Buffer

// Run on strartup. But there is no "main loop" in here. Instead, frame "tick" is handled by the `step` proc.
main :: proc() {
	js.add_window_event_listener(.Resize, nil, resize_callback)
	gl.CreateCurrentContextById(CANVAS_ID, gl.DEFAULT_CONTEXT_ATTRIBUTES)
	gl.SetCurrentContextById(CANVAS_ID)
	shader = gl.CreateProgramFromStrings({SHADER_VERT}, {SHADER_FRAG}) or_else panic("Failed loading shader")

	vertex_buffer = gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(triangle_vertices), raw_data(&triangle_vertices), gl.DYNAMIC_DRAW)

	// Tell shader where it can find the in_position and in_color vertex attributes
	attr_pos := gl.GetAttribLocation(shader, "in_position")
	gl.EnableVertexAttribArray(attr_pos)
	gl.VertexAttribPointer(attr_pos, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))

	attr_col := gl.GetAttribLocation(shader, "in_color")
	gl.EnableVertexAttribArray(attr_col)
	gl.VertexAttribPointer(attr_col, 4, gl.UNSIGNED_BYTE, true, size_of(Vertex), offset_of(Vertex, color))

	fit_canvas_to_body()
	gl.Disable(gl.DEPTH_TEST)
	gl.Enable(gl.BLEND)
	gl.Enable(gl.CULL_FACE)
	gl.CullFace(gl.BACK)
	gl.FrontFace(gl.CW)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}

// A proc named "step" is automatically run by Odin JS runtime if exported.
@(export)
step :: proc(dt: f32) -> bool {
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(u32(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT))
	gl.UseProgram(shader)
	gl.DrawArrays(gl.TRIANGLES, 0, len(triangle_vertices))
	return true
}

Vertex :: struct {
	pos: [3]f32,
	color: [4]u8,
}

triangle_vertices := [3]Vertex {
	{
		pos = {  0.0,  0.5, 0.0 },
		color = {255, 0, 0, 255},
	},
	{
		pos = { 0.5, -0.5, 0.0 },
		color = { 0, 255, 0, 255 },
	},
	{
		pos = { -0.5, -0.5, 0.0 },
		color = { 0, 0, 255, 255 },
	},
}

fit_canvas_to_body :: proc() {
	rect := js.get_bounding_client_rect(CANVAS_ID)
	dpi := js.device_pixel_ratio()

	width := f64(rect.width) * dpi
	height := f64(rect.height) * dpi

	js.set_element_key_f64(CANVAS_ID, "width", width)
	js.set_element_key_f64(CANVAS_ID, "height", height)
	gl.Viewport(0, 0, i32(width), i32(height))
}

resize_callback :: proc(e: js.Event) {
	fit_canvas_to_body()
}

SHADER_VERT :: `
precision highp float;

attribute vec3 in_position;
attribute vec4 in_color;

varying vec4 color;

void main() {
	color = in_color;
	gl_Position = vec4(in_position, 1.0);
}
`

SHADER_FRAG :: `
precision highp float;

varying vec4 color;

void main() {
	gl_FragColor = color;
}
`
