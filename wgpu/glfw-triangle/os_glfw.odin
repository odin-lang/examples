#+build !js
package vendor_wgpu_example_triangle

import "core:time"

import "vendor:glfw"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

OS :: struct {
	window: glfw.WindowHandle,
}

os_init :: proc() {
	if !glfw.Init() {
		panic("[glfw] init failure")
	}

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	state.os.window = glfw.CreateWindow(960, 540, "WGPU Native Triangle", nil, nil)

	glfw.SetFramebufferSizeCallback(state.os.window, size_callback)
}

os_run :: proc() {
	dt: f32

	for !glfw.WindowShouldClose(state.os.window) {
		start := time.tick_now()

		glfw.PollEvents()
		frame(dt)

		dt = f32(time.duration_seconds(time.tick_since(start)))
	}

	finish()

	glfw.DestroyWindow(state.os.window)
	glfw.Terminate()
}

os_get_framebuffer_size :: proc() -> (width, height: u32) {
	iw, ih := glfw.GetFramebufferSize(state.os.window)
	return u32(iw), u32(ih)
}

os_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
	return glfwglue.GetSurface(instance, state.os.window)
}

@(private="file")
size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	resize()
}
