#+build !js
package vendor_wgpu_example_triangle

import     "core:fmt"

import     "vendor:wgpu"
import     "vendor:wgpu/sdl3glue"
import SDL "vendor:sdl3"

OS :: struct {
	window: ^SDL.Window,
}

os_init :: proc() {
	if !SDL.Init({.VIDEO}) {
		fmt.panicf("SDL.Init error: ", SDL.GetError())
	}

	state.os.window = SDL.CreateWindow("WGPU Native Triangle", 960, 540, {.RESIZABLE, .HIGH_PIXEL_DENSITY})
	if state.os.window == nil {
		fmt.panicf("SDL.CreateWindow error: ", SDL.GetError())
	}
}

os_run :: proc() {
	now := SDL.GetPerformanceCounter()
	last : u64
	dt: f32
	main_loop: for {
		last = now
		now = SDL.GetPerformanceCounter()
		dt = f32((now - last) * 1000) / f32(SDL.GetPerformanceFrequency())

		e: SDL.Event
		for SDL.PollEvent(&e) {
			#partial switch (e.type) {
			case .QUIT:
				break main_loop
			case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
				resize()
			}
		}

		frame(dt)
	}

	finish()

	SDL.DestroyWindow(state.os.window)
	SDL.Quit()
}


os_get_framebuffer_size :: proc() -> (width, height: u32) {
	w, h: i32
	SDL.GetWindowSizeInPixels(state.os.window, &w, &h)
	return u32(w), u32(h)
}

os_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
	return sdl3glue.GetSurface(instance, state.os.window)
}
