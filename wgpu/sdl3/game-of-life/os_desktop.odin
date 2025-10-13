#+build !js
// Desktop Platform Layer - SDL3
// ==============================
// Provides platform-specific initialisation and event loop for desktop builds.
//
package main

import "core:fmt"
import SDL "vendor:sdl3"
import "vendor:wgpu"
import glue "vendor:wgpu/sdl3glue"

window: ^SDL.Window

os_init :: proc() {
	if !SDL.Init({.VIDEO}) {
		fmt.panicf("Failed to initialise SDL: %s", SDL.GetError())
	}
	
	window = SDL.CreateWindow("Conway's Game of Life", WIDTH, HEIGHT, {.RESIZABLE})
	if window == nil {
		fmt.panicf("Failed to create window: %s", SDL.GetError())
	}
}

os_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
	return glue.GetSurface(instance, window)
}

os_get_framebuffer_size :: proc() -> (width: u32, height: u32) {
	w, h: i32
	if SDL.GetWindowSizeInPixels(window, &w, &h) {
		return u32(w), u32(h)
	}
	return WIDTH, HEIGHT
}

os_request_adapter_and_device :: proc() {
	// Request adapter (synchronous on desktop)
	wgpu.InstanceRequestAdapter(
		state.instance,
		&{compatibleSurface = state.surface, powerPreference = .HighPerformance},
		{callback = on_adapter_sync},
	)
}

on_adapter_sync :: proc "c" (
	status: wgpu.RequestAdapterStatus,
	adapter: wgpu.Adapter,
	message: string,
	userdata1, userdata2: rawptr,
) {
	context = state.ctx
	
	if status != .Success || adapter == nil {
		fmt.panicf("Failed to get WebGPU adapter: [%v] %s", status, message)
	}
	
	state.adapter = adapter
	
	// Request device
	desc := wgpu.DeviceDescriptor{}
	desc.uncapturedErrorCallbackInfo = {callback = on_device_error}
	
	wgpu.AdapterRequestDevice(state.adapter, &desc, {callback = on_device_sync})
}

on_device_sync :: proc "c" (
	status: wgpu.RequestDeviceStatus,
	device: wgpu.Device,
	message: string,
	userdata1, userdata2: rawptr,
) {
	context = state.ctx
	
	if status != .Success || device == nil {
		fmt.panicf("Failed to get WebGPU device: [%v] %s", status, message)
	}
	
	complete_gpu_init(device)
}

os_run :: proc() {
	// Main event loop with delta time tracking
	event: SDL.Event
	running := true
	
	last := SDL.GetPerformanceCounter()
	now: u64
	dt: f32
	
	for running {
		// Calculate delta time in milliseconds
		now = SDL.GetPerformanceCounter()
		dt = f32((now - last) * 1000) / f32(SDL.GetPerformanceFrequency())
		last = now
		
		for SDL.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				running = false
			case .WINDOW_RESIZED, .WINDOW_PIXEL_SIZE_CHANGED:
				resize()
			case .KEY_DOWN:
				if event.key.scancode == .ESCAPE {
					running = false
				}
			}
		}
		
		frame(dt)
	}
	
	cleanup()
	SDL.DestroyWindow(window)
	SDL.Quit()
}
