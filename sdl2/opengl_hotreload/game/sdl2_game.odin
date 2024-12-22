package game

import "../common"

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"

import SDL "vendor:sdl2"

// This is necessary to ensure we can reload DLL while using GL code inside the DLL
// This is because both the main executable and the DLL need to maintain a list of gl function pointers
@(export)
reload_init :: proc() {
	gl.load_up_to(3, 3, SDL.gl_set_proc_address)
}


@(export)
init :: proc(session_game_memory: ^common.Game_Memory) {
	
	reload_init()
	assert(session_game_memory != nil)
	
	session_game_memory.indices = []u16{
		0, 1, 2,
		2, 3, 0,
	}
	session_game_memory.vertices = []common.Vertex{
		{{-0.5, +0.5, 0}, {1.0, 0.0, 0.0, 0.75}},
		{{-0.5, -0.5, 0}, {1.0, 1.0, 0.0, 0.75}},
		{{+0.5, -0.5, 0}, {0.0, 1.0, 0.0, 0.75}},
		{{+0.5, +0.5, 0}, {0.0, 0.0, 1.0, 0.75}},
	}

	vertices := &session_game_memory.vertices
	indices := &session_game_memory.indices

	fmt.print(session_game_memory.indices)
	
	vao: u32
	gl.GenVertexArrays(1, &vao);
	session_game_memory.vao = vao
	
	// initialization of OpenGL buffers
	vbo, ebo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)
	session_game_memory.vbo = vbo
	session_game_memory.ebo = ebo

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(vertices)*size_of(vertices[0]), raw_data(vertices^), gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(common.Vertex), offset_of(common.Vertex, pos))
	gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(common.Vertex), offset_of(common.Vertex, col))
	
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices)*size_of(indices[0]), raw_data(indices^), gl.STATIC_DRAW)

}

// this allows us to run relevant SDL/GL rendering code from inside the Game DLL directly
@(export)
update :: proc(platform_window: rawptr, session_game_memory: ^common.Game_Memory, t: f32) -> bool {
	indices := session_game_memory.indices
	uniforms := session_game_memory.uniforms
	window := transmute(^SDL.Window)platform_window
	// Native support for GLSL-like functionality
	pos := glm.vec3{
		glm.cos(t*2),
		glm.sin(t*2),
		0,
	}
	// array programming support
	pos *= 0.3
	
	// matrix support
	// model matrix which a default scale of 0.5
	model := glm.mat4{
		0.5,   0,   0, 0,
		  0, 0.5,   0, 0,
		  0,   0, 0.5, 0,
		  0,   0,   0, 1,
	}

	// matrix indexing and array short with `.x`
	model[0, 3] = -pos.x
	model[1, 3] = -pos.y
	model[2, 3] = -pos.z
	
	// native swizzling support for arrays
	model[3].yzx = pos.yzx
	
	model = model * glm.mat4Rotate({0, 1, 1}, t)
	
	view := glm.mat4LookAt({0, -1, +1}, {0, 0, 0}, {0, 0, 1})
	proj := glm.mat4Perspective(45, 1.3, 0.1, 100.0)
	
	// matrix multiplication
	u_transform := proj * view * model

	gl.Viewport(0, 0, session_game_memory.window_width, session_game_memory.window_height)
	
	// matrix types in Odin are stored in column-major format but written as you'd normal write them
	gl.UniformMatrix4fv(uniforms["u_transform"].location, 1, false, &u_transform[0, 0])

	gl.ClearColor(0.7, 0.0, 1.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	
	gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_SHORT, nil)
	
	SDL.GL_SwapWindow(window)
	return true	
}
