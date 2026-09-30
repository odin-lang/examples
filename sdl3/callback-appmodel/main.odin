package sdl3_callback_appmodel_example

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "vendor:sdl3"
import "core:c"
import queue "core:container/queue"

main :: proc() {
	result := sdl3.RunApp(0, nil, SDL_AppMain, nil)
	os.exit(cast(int)result)
}

SDL_AppMain :: proc "c" (argc: c.int, argv: [^]cstring) -> c.int {
	return sdl3.EnterAppMainCallbacks(argc, argv, SDL_AppInit, SDL_AppIterate, SDL_AppEvent, SDL_AppQuit)
}

App_State :: struct {
	runtime_context:    runtime.Context,
	window:             ^sdl3.Window,
	renderer:           ^sdl3.Renderer,
	bill_texture:       ^sdl3.Texture,
	window_size_valid:  bool,
	window_size:        [2]i32,
	iterate_time:       SDL_Time,
	keyboard:           []bool,
	position:           [2]f32,
}

DEFAULT_CANVAS_W :: 800
DEFAULT_CANVAS_H :: 600

SDL_AppInit :: proc "cdecl" (appstate: ^rawptr, argc: c.int, argv: [^]cstring) -> sdl3.AppResult {

	context = runtime.default_context()
	context.logger = log.create_console_logger()

	state := new(App_State)
	assert(state != nil)
	state.runtime_context = context
	appstate^ = state

	assert(sdl3.Init({ .VIDEO }))

	state.window = sdl3.CreateWindow("SDL3 Callback AppModel example", DEFAULT_CANVAS_W, DEFAULT_CANVAS_H, {.RESIZABLE})
	assert(state.window != nil)

	state.renderer = sdl3.CreateRenderer(state.window, sdl3.SOFTWARE_RENDERER)
	assert(state.renderer != nil)

	assert(sdl3.SetRenderVSync(state.renderer, 1))

	state.bill_texture = load_texture_from_path(state.renderer, "bill32.png")
	assert(state.bill_texture != nil)

	return .CONTINUE
}

SDL_AppIterate :: proc "cdecl" (appstate: rawptr) -> sdl3.AppResult {

	state := cast(^App_State)appstate
	assert_contextless(state != nil)
	context = state.runtime_context

	statistics_sw := get_time()

	// Process window changes.

	if !state.window_size_valid {
		w, h : c.int
		assert(sdl3.GetWindowSizeInPixels(state.window, &w, &h))
		state.window_size = { w, h }
		// Resize the viewport.
		state.window_size_valid = true
		statistics_record_time(.window, &statistics_sw)
	}

	// Accumulate elapsed game time (RTC).

	now := get_time()
	elapsed_duration := get_duration(state.iterate_time, now)
	elapsed_ms := duration_to_ms32(elapsed_duration)
	state.iterate_time = now
	statistics_record_time(.timing, &statistics_sw)

	// Capture keyboard input state.

	num_keys : c.int
	keyboard_state := sdl3.GetKeyboardState(&num_keys)
	assert(keyboard_state != nil)
	state.keyboard = keyboard_state[:num_keys]
	statistics_record_time(.input, &statistics_sw)

	// Apply keyboard input

	SPEED_PX_PER_MS :: 0.1
	if state.keyboard[sdl3.Scancode.LEFT] {
		state.position.x -= SPEED_PX_PER_MS * elapsed_ms
	}
	if state.keyboard[sdl3.Scancode.UP] {
		state.position.y -= SPEED_PX_PER_MS * elapsed_ms
	}
	if state.keyboard[sdl3.Scancode.RIGHT] {
		state.position.x += SPEED_PX_PER_MS * elapsed_ms
	}
	if state.keyboard[sdl3.Scancode.DOWN] {
		state.position.y += SPEED_PX_PER_MS * elapsed_ms
	}
	statistics_record_time(.update_position, &statistics_sw)

	// Clear background

	sdl3.SetRenderDrawColor(state.renderer, 0, 0, 0, 0)
	sdl3.RenderClear(state.renderer)
	statistics_record_time(.render_clear, &statistics_sw)

	// Calculate bill position
	// state.position == (0, 0) means that bill is in the center of the window.

	texture_w, texture_h: f32
	sdl3.GetTextureSize(state.bill_texture, &texture_w, &texture_h)

	render_x := cast(f32)state.window_size.x / 2.0 - texture_w / 2 + state.position.x
	render_y := cast(f32)state.window_size.y / 2.0 - texture_h / 2 + state.position.y

	// Render bill

	sdl3.RenderTexture(state.renderer, state.bill_texture, nil, &sdl3.FRect{ render_x, render_y, texture_w, texture_h })
	statistics_record_time(.render_texture, &statistics_sw)

	statistics_render(state.renderer)
	statistics_record_time(.render_statistics, &statistics_sw)

	sdl3.RenderPresent(state.renderer)
	statistics_record_time(.present, &statistics_sw)

	return .CONTINUE
}

SDL_AppEvent :: proc "cdecl" (appstate: rawptr, event: ^sdl3.Event) -> sdl3.AppResult {

	state := cast(^App_State)appstate
	assert_contextless(state != nil)
	context = state.runtime_context

	sw := get_time()

	#partial switch event.type {

	case .QUIT:
		return .SUCCESS

	case .KEY_DOWN:
		if event.key.scancode == .ESCAPE {
			// Quit application.
			return .SUCCESS
		}

	case .WINDOW_RESIZED:
		state.window_size_valid = false
	}

	statistics_record_time(.event, &sw)

	return .CONTINUE
}

SDL_AppQuit :: proc "cdecl" (appstate: rawptr, result: sdl3.AppResult) {

	state := cast(^App_State)appstate
	assert_contextless(state != nil)
	context = state.runtime_context

	sdl3.DestroyTexture(state.bill_texture)
	state.bill_texture = nil
	sdl3.DestroyRenderer(state.renderer)
	state.renderer = nil
	sdl3.DestroyWindow(state.window)
	state.window = nil
	
	free(state)
}

// Timestamp in SDL time (nanosecond precision).
SDL_Time :: distinct u64
// Duration in nanoseconds.
SDL_Duration :: distinct i64

@(require_results)
get_time :: #force_inline proc "contextless" () -> SDL_Time {
	return cast(SDL_Time)sdl3.GetTicksNS()
}

@(require_results)
get_duration :: #force_inline proc "contextless" (start, end : SDL_Time) -> SDL_Duration {
	return cast(SDL_Duration)end - cast(SDL_Duration)start
}

@(require_results)
get_duration_ms32 :: #force_inline proc "contextless" (start, end : SDL_Time) -> f32 {
	return cast(f32)(end - start) / cast(f32)sdl3.NS_PER_MS
}

@(require_results)
duration_from_ms :: #force_inline proc "contextless" (ms : f64) -> SDL_Duration {
	return cast(SDL_Duration)(ms * sdl3.NS_PER_MS)
}

@(require_results)
duration_to_ms :: #force_inline proc "contextless" (duration : SDL_Duration) -> f64 {
	return cast(f64)duration / cast(f64)sdl3.NS_PER_MS
}

@(require_results)
duration_to_ms32 :: #force_inline proc "contextless" (duration : SDL_Duration) -> f32 {
	return cast(f32)duration / cast(f32)sdl3.NS_PER_MS
}

load_texture_from_path :: proc(renderer: ^sdl3.Renderer, path: cstring) -> ^sdl3.Texture {
	surface := sdl3.LoadPNG(path)
	assert(surface != nil)
	texture := sdl3.CreateTextureFromSurface(renderer, surface)
	assert(texture != nil)
	return texture
}

statistics_record_time :: proc(id: Statistic, sw: ^SDL_Time) {
	now := get_time()
	ms := get_duration_ms32(sw^, now)
	sw^ = now
	statistics_record(id, ms)
}

statistics_render :: proc(renderer: ^sdl3.Renderer) {
	sdl3.SetRenderDrawColor(renderer, 0, 255, 255, 255)
	for i in 0 ..< len(statistics) {
		name := statistics[i].name
		avg := statistics[i].sum_in_queue / cast(f32)queue.len(statistics[i].queue)
		max := statistics[i].max
		s := fmt.tprintf("%30v: Avg %.2f - Max %.2f", name, avg, max)
		sdl3.RenderDebugText(renderer, 0, cast(f32)(i * 10), auto_cast raw_data(s))
	}
}
