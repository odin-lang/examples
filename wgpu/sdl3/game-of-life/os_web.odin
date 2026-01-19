#+build js
// Web Platform Layer - WASM
// ==========================
// Provides platform-specific initialisation and browser event loop for web builds.
//
package main

import "base:runtime"
import "core:fmt"
import "core:sys/wasm/js"
import "vendor:wgpu"

device_ready: bool = false

os_init :: proc() {
	ok := js.add_window_event_listener(.Resize, nil, size_callback)
	assert(ok)
}

os_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
	return wgpu.InstanceCreateSurface(
		instance,
		&wgpu.SurfaceDescriptor {
			nextInChain = &wgpu.SurfaceSourceCanvasHTMLSelector {
				sType    = .SurfaceSourceCanvasHTMLSelector,
				selector = "#wgpu-canvas",
			},
		},
	)
}

os_get_framebuffer_size :: proc() -> (width: u32, height: u32) {
	rect := js.get_bounding_client_rect("body")
	dpi := js.device_pixel_ratio()
	return u32(f64(rect.width) * dpi), u32(f64(rect.height) * dpi)
}

os_request_adapter_and_device :: proc() {
	fmt.println("[1/3] Requesting adapter (async - waiting for browser)...")
	
	// Define callbacks inline - crucial for async to work in WASM
	wgpu.InstanceRequestAdapter(
		state.instance,
		&{compatibleSurface = state.surface},
		{callback = on_adapter},
	)
	
	// Inline callback for adapter acquisition
	on_adapter :: proc "c" (
		status: wgpu.RequestAdapterStatus,
		adapter: wgpu.Adapter,
		message: string,
		userdata1, userdata2: rawptr,
	) {
		context = state.ctx
		
		if status != .Success || adapter == nil {
			fmt.panicf("Failed to get WebGPU adapter: [%v] %s", status, message)
		}
		
		fmt.println("[OK] [1/3] Adapter acquired")
		state.adapter = adapter
		
		desc := wgpu.DeviceDescriptor{}
		desc.uncapturedErrorCallbackInfo = {callback = on_device_error}
		
		fmt.println("[2/3] Requesting device (async)...")
		wgpu.AdapterRequestDevice(adapter, &desc, {callback = on_device})
	}
	
	// Inline callback for device acquisition
	on_device :: proc "c" (
		status: wgpu.RequestDeviceStatus,
		device: wgpu.Device,
		message: string,
		userdata1, userdata2: rawptr,
	) {
		context = state.ctx
		
		if status != .Success || device == nil {
			fmt.panicf("Failed to get WebGPU device: [%v] %s", status, message)
		}
		
		fmt.println("[OK] [2/3] Device acquired")
		complete_gpu_init(device)
	}
	
	fmt.println("Waiting for browser callbacks...")
}

os_run :: proc() {
	device_ready = true
	fmt.println("[OK] [3/3] WebGPU initialised - Game of Life ready!")
}

// step is called by the browser runtime at 60 FPS
@(export)
step :: proc(dt: f32) -> bool {
	context = state.ctx
	
	// Wait for async GPU initialization
	if !device_ready {
		return true
	}
	
	frame(dt)
	return true
}

@(fini)
cleanup_on_exit :: proc "contextless" () {
	context = runtime.default_context()
	cleanup()
	js.remove_window_event_listener(.Resize, nil, size_callback)
}

size_callback :: proc(e: js.Event) {
	if !device_ready {
		return
	}
	resize()
}
