package main

import "core:fmt"

import "core:time"
import "core:dynlib"
import "core:os"
import "core:c/libc"

import "../common"

import SDL "vendor:sdl2"
import gl "vendor:OpenGL"

session_game_memory : ^common.Game_Memory

WINDOW_WIDTH  :: 854
WINDOW_HEIGHT :: 480

GAME_DLL_NAME :: "game.dll"

window : ^SDL.Window
gl_context : SDL.GLContext



vertex_source := `#version 330 core

layout(location=0) in vec3 a_position;
layout(location=1) in vec4 a_color;

out vec4 v_color;

uniform mat4 u_transform;

void main() {	
	gl_Position = u_transform * vec4(a_position, 1.0);
	v_color = a_color;
}
`

fragment_source := `#version 330 core

in vec4 v_color;

out vec4 o_color;

void main() {
	o_color = v_color;
}
`

platform_init_window :: proc() {
    window = SDL.CreateWindow("Odin SDL2 Demo", SDL.WINDOWPOS_UNDEFINED, SDL.WINDOWPOS_UNDEFINED, WINDOW_WIDTH, WINDOW_HEIGHT, {.OPENGL})
    if window == nil {
        fmt.eprintln("Failed to create SDL2 Window")
        return
    }

    gl_context = SDL.GL_CreateContext(window)
    SDL.GL_MakeCurrent(window, gl_context)
    // load the OpenGL  procedures once an OpenGL context has been established
    gl.load_up_to(3, 3, SDL.gl_set_proc_address)

    fmt.println("Created SDL2 Window and OpenGL Context!")

    program, program_ok := gl.load_shaders_source(vertex_source, fragment_source)
    if !program_ok {
        fmt.eprintln("Failed to create GLSL Program")
        return
    }
    gl.UseProgram(program)

    session_game_memory = new(common.Game_Memory)
    session_game_memory.uniforms = gl.get_uniforms_from_program(program)
    session_game_memory.window_width = WINDOW_WIDTH
    session_game_memory.window_height = WINDOW_HEIGHT
}


platform_input :: proc() -> bool{
	// event polling
	
	should_not_quit := true
	event: SDL.Event
	for SDL.PollEvent(&event) != false {
		// #partial switch tells the compiler not to error if every case is not present
		#partial switch event.type {
		case .KEYDOWN:
			#partial switch event.key.keysym.sym {
			case .ESCAPE:
				// labelled control flow
				fmt.println("Bye!")
				should_not_quit = false
			}
		case .QUIT:
			// labelled control flow
			should_not_quit = false
		}
	}
	
	return should_not_quit
}

// Note: Reload mechanism borrowed from Karl Zylinski's raylib reload demo:
// https://github.com/karl-zylinski/odin-raylib-hot-reload-game-template

main :: proc() {
    game_api_version := 0
    game_api, game_api_ok := load_game_api(game_api_version)

    if !game_api_ok {
        fmt.eprintln("Failed to load Game API")
        return
    }
    game_api_version += 1

    platform_init_window()
    assert(session_game_memory != nil)
    

    // high precision timer
    start_tick := time.tick_now()
    game_api.init(session_game_memory)

    fmt.println(session_game_memory)

    loop: for {
        duration := time.tick_since(start_tick)
        t := f32(time.duration_seconds(duration))

        should_not_quit := platform_input()

        if !should_not_quit{ break }

        game_api.update(rawptr(window), session_game_memory, t)

        dll_time, dll_time_err := os.last_write_time_by_name(GAME_DLL_NAME)

        reload := dll_time_err == os.ERROR_NONE && game_api.dll_time != dll_time

        if reload {
            new_api, new_api_ok := load_game_api(game_api_version)

            if new_api_ok {
                fmt.println("Reloading Game DLL")
                unload_game_api(game_api)
                game_api = new_api
                game_api_version += 1
                game_api.reload_init()
            }
        }
    }

    unload_game_api(game_api)
}

Game_API :: struct {
    init: proc(^common.Game_Memory),
	reload_init: proc(),
	update: proc(rawptr, ^common.Game_Memory, f32) -> bool,	
	lib: dynlib.Library,
	dll_time: os.File_Time,
	api_version: int
}

load_game_api :: proc(api_version: int) -> (Game_API, bool) {
    dll_time, dll_time_err := os.last_write_time_by_name(GAME_DLL_NAME)

    if dll_time_err != os.ERROR_NONE {
        fmt.println("Could not fetch last write date of game.dll")
        return {}, false
    }

    dll_name := fmt.tprintf("game_{0}.dll", api_version)

    // TODO: this presently requires windows CLI tool 'copy' to work, for cross platform support, we can select the right command by OS
    copy_cmd := fmt.ctprintf("copy game.dll {0}", dll_name)
    if libc.system(copy_cmd) != 0 {
        fmt.println("Failed to copy game.dll to {0}", dll_name)
        return {}, false
    }

    fmt.println("Trying to load library...")
    lib, lib_ok := dynlib.load_library(dll_name)

    if !lib_ok {
        fmt.println("Failed loading game.dll")
        return {}, false
    }

    api := Game_API {
        init = cast(proc(^common.Game_Memory))(dynlib.symbol_address(lib, "init") or_else nil),
        reload_init = cast(proc())(dynlib.symbol_address(lib, "reload_init") or_else nil),
        update = cast(proc(rawptr, ^common.Game_Memory, f32)-> bool)(dynlib.symbol_address(lib, "update") or_else nil),

        lib = lib,
        dll_time = dll_time,
        api_version = api_version
    }

    if api.init == nil || api.update == nil || api.reload_init == nil {
        dynlib.unload_library(api.lib)
        fmt.println("game.dll unable to load needed API procedures")
        return {}, false
    }

    return api, true
}

unload_game_api :: proc(api: Game_API) {
    if api.lib != nil {
        dynlib.unload_library(api.lib)
    }

    del_cmd := fmt.ctprintf("del game_{0}.dll", api.api_version)
    if libc.system(del_cmd) != 0 {
        fmt.println("Failed to remove game_{0}.dll copy", api.api_version)
    }
}
