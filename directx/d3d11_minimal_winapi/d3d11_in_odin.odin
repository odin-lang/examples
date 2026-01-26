#+build windows

package d3d11_test

import "core:fmt"
import win32 "core:sys/windows"
import "vendor:directx/dxgi"
import "vendor:directx/d3d11"

Win32_App :: struct {
	instance:           win32.HINSTANCE,
	window:             win32.HWND,
	window_title:       cstring16,
	window_classname:   cstring16,
	time_elapsed:       f32,
	frame_count:        u32,
	refresh_rate:       u32,
	client_width:       u32,
	client_height:      u32,
	min_client_width:   u32,
	min_client_height:  u32,
	background_color_r: u32,
	background_color_g: u32,
	background_color_b: u32,
	running:            bool,
	minimized:          bool,
	maximized:          bool,
	resizing:           bool,
	paused:             bool,
}; win32_app: Win32_App

Win32_Timer :: struct {
	seconds_per_count: f64,
	delta_time:        f64,
	base_time:         i64,
	paused_time:       i64,
	stop_time:         i64,
	prev_time:         i64,
	curr_time:         i64,
	stopped:           bool,
}; win32_timer: Win32_Timer

D3D11_Renderer :: struct {
	device:               ^d3d11.IDevice,
	immediate_context:    ^d3d11.IDeviceContext,
	swapchain:            ^dxgi.ISwapChain,
	depth_stencil_buffer: ^d3d11.ITexture2D,
	render_target_view:   ^d3d11.IRenderTargetView,
	depth_stencil_view:   ^d3d11.IDepthStencilView,
	screen_viewport:       d3d11.VIEWPORT,
}; d3d11_renderer: D3D11_Renderer

win32_release_com :: #force_inline proc "contextless" (object: ^$T) {
	if object^ != nil {
		object^->Release()
		object^ = nil
	}
}

debug_win32_result_ok :: #force_inline proc "contextless" (#any_int result: int) {
	when ODIN_DEBUG {
		if win32.FAILED(result) {
			/* NOTE: Investigate Problem */
		}
	}
}

win32_timer_init :: proc "contextless" (win32_timer: ^Win32_Timer) {
	win32_timer.delta_time = -1.0

	counts_per_sec: win32.LARGE_INTEGER
	win32.QueryPerformanceFrequency(&counts_per_sec)
	win32_timer.seconds_per_count = 1.0 / f64(counts_per_sec)
}

win32_timer_reset :: proc "contextless" (win32_timer: ^Win32_Timer) {
	curr_time: win32.LARGE_INTEGER
	win32.QueryPerformanceCounter(&curr_time)
	
	win32_timer.base_time = i64(curr_time)
	win32_timer.prev_time = i64(curr_time)
	win32_timer.stop_time = 0
	win32_timer.stopped = false
}

win32_timer_start :: proc "contextless" (win32_timer: ^Win32_Timer) {
	start_time: win32.LARGE_INTEGER
	win32.QueryPerformanceCounter(&start_time)

	if win32_timer.stopped {
		win32_timer.paused_time += ( i64(start_time) - win32_timer.stop_time )
		win32_timer.prev_time = i64(start_time)
		win32_timer.stop_time = 0
		win32_timer.stopped = false
	}
}

win32_timer_stop :: proc "contextless" (win32_timer: ^Win32_Timer) {
	if !win32_timer.stopped {
		curr_time: win32.LARGE_INTEGER
		win32.QueryPerformanceCounter(&curr_time)

		win32_timer.stop_time = i64(curr_time)
		win32_timer.stopped = true
	}
}

win32_timer_tick :: proc "contextless" (win32_timer: ^Win32_Timer) {
	if win32_timer.stopped {
		win32_timer.delta_time = 0
		return
	}

	curr_time: win32.LARGE_INTEGER
	win32.QueryPerformanceCounter(&curr_time)

	win32_timer.curr_time = i64(curr_time)
	win32_timer.delta_time = f64(win32_timer.curr_time - win32_timer.prev_time) * win32_timer.seconds_per_count
	win32_timer.prev_time = win32_timer.curr_time

	// INFO: Force nonnegative. The DXSDK's CDXUTTimer mentions that
	// if the processor goes into a power save mode or we get shuffled to
	// another processor, then delta_time can be negative
	if win32_timer.delta_time < 0 {
		win32_timer.delta_time = 0
	}
}

win32_timer_total_time :: #force_inline proc "contextless" (win32_timer: ^Win32_Timer) -> f32 {
	// INFO: Returns the total time elapsed since Reset()
	// was called, NOT counting any time when the clock is stopped
	if win32_timer.stopped {
		// INFO: If we are stopped, do not count the time that has passed
		// since we stopped. Moreover, if we previously already had a pause,
		// the distance stop_time - base_time includes paused time,
		// which we do not want to count. To correct this, we can subtract the
		// paused time from stop_time
		//
		//                    |<--paused time-->|
		// ----*---------------*-----------------*------------*------------*------> time
		//  base_time		stop_time        start_time     stop_time    curr_time
		return f32( f64(win32_timer.stop_time - win32_timer.paused_time - win32_timer.base_time) * win32_timer.seconds_per_count )
	} else {
		// INFO: The distance curr_time - base_time includes
		// paused time, which we do not want to count. To correct this, we can
		// subtract the paused time from curr_time
		//
		//                     |<--paused time-->|
		// ----*---------------*-----------------*------------*------> time
		//  base_time       stop_time        start_time     curr_time
		return f32( f64(win32_timer.curr_time - win32_timer.paused_time - win32_timer.base_time) * win32_timer.seconds_per_count )
	}
}

win32_app_calculate_frame_stats :: proc (win32_app: ^Win32_App, win32_timer: ^Win32_Timer) {
	win32_app.frame_count += 1
	timer_total_time := win32_timer_total_time(win32_timer)

	// INFO: Calculate Avg over one second period
	if timer_total_time - win32_app.time_elapsed >= 1.0 {
		fps := win32_app.frame_count
		mspf := 1000.0 / f32(fps)

		window_title := fmt.tprintf("%v FPS: %d Frame Time: %0.4f ms", win32_app.window_title, fps, mspf)
		window_title_w16 := win32.utf8_to_wstring(window_title)
		set_window_title_ok := win32.SetWindowTextW(win32_app.window, window_title_w16)
		if !set_window_title_ok {
			// NOTE: Investigate SetWindowTextW
		}

		win32_app.frame_count = 0
		win32_app.time_elapsed += 1.0
	}
}

win32_window_callback :: proc "system" (window: win32.HWND, message: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
	result: win32.LRESULT
	switch message {
	// INFO: WM_ACTIVATE is sent when the window is activated or
	// deactivated. We pause the game when the window is deactivated
	// and unpause it when it becomes active
	case win32.WM_ACTIVATE:
		if win32.LOWORD(wparam) == win32.WA_INACTIVE {
			win32_app.paused = true
			win32_timer_stop(&win32_timer)
		} else {
			win32_app.paused = false
			win32_timer_start(&win32_timer)
		}
	
	// INFO: WM_SIZE is sent when the user resizes the window
	case win32.WM_SIZE:
		win32_app.client_width  = u32(win32.LOWORD(lparam))
		win32_app.client_height = u32(win32.HIWORD(lparam))

		if d3d11_renderer.device != nil {
			switch wparam {
			case win32.SIZE_MINIMIZED:
				win32_app.paused = true
				win32_app.minimized = true
				win32_app.maximized = false

			case win32.SIZE_MAXIMIZED:
				win32_app.paused = false
				win32_app.minimized = false
				win32_app.maximized = true
				d3d11_renderer_on_resize_callback(&win32_app, &d3d11_renderer)

			case win32.SIZE_RESTORED:
				if win32_app.minimized {
					win32_app.paused = false
					win32_app.minimized = false
					d3d11_renderer_on_resize_callback(&win32_app, &d3d11_renderer)
				} else if win32_app.maximized {
					win32_app.paused = false
					win32_app.maximized = false
					d3d11_renderer_on_resize_callback(&win32_app, &d3d11_renderer)
				} else if win32_app.resizing {
					// INFO: If user is dragging the resize bars, we do not resize the buffers
					// here because as the user continuously drags the resize bars, a stream of WM_SIZE
					// messages are sent to the window, and it would be pointless (and slow) to resize
					// for each WM_SIZE message received from dragging the resize bars. So instead, we
					// reset after the user is done resizing the window and releases the resize bars,
					// which sends a WM_EXITSIZEMOVE message
				} else {
					// INFO: API call such as SetWindowPos or mSwapChain->SetFullscreenState
					d3d11_renderer_on_resize_callback(&win32_app, &d3d11_renderer)
				}
			}
		}

	// INFO: WM_ENTERSIZEMOVE is sent when the user grabs the resize bars	
	case win32.WM_ENTERSIZEMOVE:
		win32_app.paused = true
		win32_app.resizing = true
		win32_timer_stop(&win32_timer)

	// INFO: WM_EXITSIZEMOVE is sent when the user releases the resize bars.
	// Here we reset everything based on the new window dimensions
	case win32.WM_EXITSIZEMOVE:
		win32_app.paused = false
		win32_app.resizing = false
		win32_timer_start(&win32_timer)
		d3d11_renderer_on_resize_callback(&win32_app, &d3d11_renderer)

	// INFO: WM_DESTROY is sent when the window is being destroyed
	case win32.WM_DESTROY:
		win32_app.running = false

	// INFO: The WM_MENUCHAR message is sent when a menu is active
	// and the user presses a key that does not correspond to any mnemonic
	// or accelerator key
	case win32.WM_MENUCHAR:
		result = win32.MAKELRESULT(0, 1 /* MNC_CLOSE */)

	// INFO: Catch this message so to prevent the window from becoming too small
	case win32.WM_GETMINMAXINFO:
		min_client_rect := win32.RECT {0, 0, i32(win32_app.min_client_width), i32(win32_app.min_client_height)}
		win32.AdjustWindowRect(&min_client_rect, win32.WS_OVERLAPPEDWINDOW, false)

		min_max_info := cast(^win32.MINMAXINFO)uintptr(lparam)
		min_max_info.ptMinTrackSize.x = min_client_rect.right - min_client_rect.left
		min_max_info.ptMinTrackSize.y = min_client_rect.bottom - min_client_rect.top

	case:
		result = win32.DefWindowProcW(window, message, wparam, lparam)
	}
	return result
}

win32_app_process_pending_messages :: proc "contextless" (win32_app: ^Win32_App) {
	message: win32.MSG
	for win32.PeekMessageW(&message, win32_app.window, 0, 0, win32.PM_REMOVE) {
		switch message.message {
		case win32.WM_QUIT:
			win32_app.running = false
		case:
			win32.TranslateMessage(&message)
			win32.DispatchMessageW(&message)
		}
	}
}

win32_app_init_window :: proc (win32_app: ^Win32_App) -> bool {
	/* INFO: Win32 Main Instance */
	win32_instance := win32.HINSTANCE( win32.GetModuleHandleW(nil) )
	if win32_instance == nil {
		return false
	}
	
	win32_app^ = Win32_App {
		running            = true,
		refresh_rate       = 240,
		client_width       = 800,
		client_height      = 600,
		min_client_width   = 480,
		min_client_height  = 320,
		background_color_r = 51,
		background_color_g = 77,
		background_color_b = 77,
		instance           = win32_instance,
		window_title       = "D3D11 Application",
		window_classname   = "D3D11 ClassName",
	}

	/* INFO: Win32 Register Window Class */
	icon := win32.LoadIconW(nil, cstring16(win32._IDI_APPLICATION))
	cursor := win32.LoadCursorW(nil, cstring16(win32._IDC_ARROW))

	brush_color := win32.RGB(
		win32_app.background_color_r,
		win32_app.background_color_g,
		win32_app.background_color_b,
	)
	brush := win32.CreateSolidBrush(brush_color)

	window_class := win32.WNDCLASSW {
		style         = win32.CS_HREDRAW | win32.CS_VREDRAW,
		lpfnWndProc   = win32_window_callback,
		hInstance     = win32_app.instance,
		hIcon         = icon,
		hCursor       = cursor,
		hbrBackground = brush,
		lpszClassName = win32_app.window_classname,
	}

	register_class_ok := win32.RegisterClassW(&window_class)
	if register_class_ok == 0 {
		/* NOTE: Investigate class registration */
		return false
	}

	/* INFO: Adjust Client Width and Height to Window Width and Height */
	client_rect := win32.RECT {0, 0, i32(win32_app.client_width), i32(win32_app.client_height)}
	win32.AdjustWindowRect(&client_rect, win32.WS_OVERLAPPEDWINDOW, false)

	/* INFO: Create Window */
	window_width := client_rect.right - client_rect.left
	window_height := client_rect.bottom - client_rect.top

	win32_app.window = win32.CreateWindowW(
		win32_app.window_classname,
		win32_app.window_title,
		win32.WS_OVERLAPPEDWINDOW,
		win32.CW_USEDEFAULT,
		win32.CW_USEDEFAULT,
		window_width,
		window_height,
		nil,
		nil,
		win32_app.instance,
		nil,
	)
	if win32_app.window == nil {
		/* NOTE: Investigate Window Creation */
		return false
	}

	win32.ShowWindow(win32_app.window, win32.SW_SHOW)
	win32.UpdateWindow(win32_app.window)

	return true
}

d3d11_renderer_init :: proc (win32_app: ^Win32_App, d3d11_renderer: ^D3D11_Renderer) -> bool {
	d3d11_feature_level: d3d11.FEATURE_LEVEL
	d3d11_driver_type := d3d11.DRIVER_TYPE.HARDWARE
	d3d11_device_flags: d3d11.CREATE_DEVICE_FLAGS
	when ODIN_DEBUG {
		d3d11_device_flags = { .DEBUG }
	}
	
	create_device_ok := d3d11.CreateDevice(
		nil,
		d3d11_driver_type,
		nil,
		d3d11_device_flags,
		nil,
		0,
		d3d11.SDK_VERSION,
		&d3d11_renderer.device,
		&d3d11_feature_level,
		&d3d11_renderer.immediate_context,
	)
	
	if win32.FAILED(create_device_ok) {
		// NOTE: Investigate D3D11 Device Creation
		return false
	}

	if d3d11_feature_level != ._11_0 {
		// NOTE: Direct3D Feature Level 11 unsupported
		return false
	}

	refresh_rate := dxgi.RATIONAL {
		Numerator = win32_app.refresh_rate,
		Denominator = 1,
	}

	dxgi_swapchain_buffer_desc := dxgi.MODE_DESC {
		Width            = win32_app.client_width,
		Height           = win32_app.client_height,
		RefreshRate      = refresh_rate,
		Format           = .R8G8B8A8_UNORM,
		ScanlineOrdering = .UNSPECIFIED,
		Scaling          = .UNSPECIFIED,
	}

	dxgi_swapchain_sample_desc := dxgi.SAMPLE_DESC {
		Count = 1,
		Quality = 0,
	}

	dxgi_swapchain_desc := dxgi.SWAP_CHAIN_DESC {
		BufferDesc   = dxgi_swapchain_buffer_desc,
		SampleDesc   = dxgi_swapchain_sample_desc,
		BufferUsage  = { .RENDER_TARGET_OUTPUT },
		BufferCount  = 1,
		OutputWindow = win32_app.window,
		Windowed     = true,
		SwapEffect   = .DISCARD,
	}

	// INFO: To correctly create the swap chain, we must use the
	// IDXGIFactory that was used to create the device. If we tried to use
	// a different IDXGIFactory instance (by calling CreateDXGIFactory), we
	// get an error: "IDXGIFactory::CreateSwapChain: This function is being
	// called with a device from a different IDXGIFactory."
	dxgi_device: ^dxgi.IDevice
	debug_win32_result_ok( d3d11_renderer.device->QueryInterface(dxgi.IDevice_UUID, cast(^rawptr)&dxgi_device) )

	dxgi_adapter: ^dxgi.IAdapter
	debug_win32_result_ok( dxgi_device->GetParent(dxgi.IAdapter_UUID, cast(^rawptr)&dxgi_adapter) )
	
	dxgi_factory: ^dxgi.IFactory
	debug_win32_result_ok( dxgi_adapter->GetParent(dxgi.IFactory_UUID, cast(^rawptr)&dxgi_factory) )
	debug_win32_result_ok( dxgi_factory->CreateSwapChain(d3d11_renderer.device, &dxgi_swapchain_desc, &d3d11_renderer.swapchain) )
	
	// INFO: Disable Alt-Enter functionality to switch between full screen and
	// windowed mode; Method needs to be called after CreateSwapChainOk is called
	debug_win32_result_ok( dxgi_factory->MakeWindowAssociation(win32_app.window, { .NO_WINDOW_CHANGES }) )

	win32_release_com(&dxgi_device)
	win32_release_com(&dxgi_adapter)
	win32_release_com(&dxgi_factory)
	
	// INFO: The remaining steps that need to be carried out for d3d creation
	// also need to be executed every time the window is resized. So just call the
	// D3D11App_OnResize method here to avoid code duplication
	d3d11_renderer_on_resize_callback(win32_app, d3d11_renderer)

	return true
}

d3d11_renderer_on_resize_callback :: proc "contextless" (win32_app: ^Win32_App, d3d11_renderer: ^D3D11_Renderer) {
	assert_contextless(d3d11_renderer.immediate_context != nil)
	assert_contextless(d3d11_renderer.device != nil)
	assert_contextless(d3d11_renderer.swapchain != nil)

	// INFO: Release the old views, as they hold references to the buffers we
	// will be destroying. Also release the old depth/stencil buffer
	win32_release_com(&d3d11_renderer.render_target_view)
	win32_release_com(&d3d11_renderer.depth_stencil_view)
	win32_release_com(&d3d11_renderer.depth_stencil_buffer)
	
	// INFO: Resize the swap chain and recreate the render target view
	d3d11_back_buffer: ^d3d11.ITexture2D
	debug_win32_result_ok( d3d11_renderer.swapchain->ResizeBuffers(1, win32_app.client_width, win32_app.client_height, .R8G8B8A8_UNORM, nil) )
	debug_win32_result_ok( d3d11_renderer.swapchain->GetBuffer(0, d3d11.ITexture2D_UUID, cast(^rawptr)&d3d11_back_buffer) )
	debug_win32_result_ok( d3d11_renderer.device->CreateRenderTargetView(d3d11_back_buffer, nil, &d3d11_renderer.render_target_view) )

	depth_stencil_sample_desc := dxgi.SAMPLE_DESC {
		Count = 1,
		Quality = 0,
	}

	depth_stencil_desc := d3d11.TEXTURE2D_DESC {
		Width          = win32_app.client_width,
		Height         = win32_app.client_height,
		MipLevels      = 1,
		ArraySize      = 1,
		Format         = .D24_UNORM_S8_UINT,
		SampleDesc     = depth_stencil_sample_desc,
		Usage          = .DEFAULT,
		BindFlags      = { .DEPTH_STENCIL },
		CPUAccessFlags = nil,
		MiscFlags      = nil,
	}

	debug_win32_result_ok( d3d11_renderer.device->CreateTexture2D(&depth_stencil_desc, nil, &d3d11_renderer.depth_stencil_buffer) )
	debug_win32_result_ok( d3d11_renderer.device->CreateDepthStencilView(d3d11_renderer.depth_stencil_buffer, nil, &d3d11_renderer.depth_stencil_view) )

	// INFO: Bind the render target view and depth/stencil view to the pipeline
	d3d11_renderer.immediate_context->OMSetRenderTargets(1, &d3d11_renderer.render_target_view, d3d11_renderer.depth_stencil_view)

	// INFO: Set the viewport transform
	d3d11_renderer.screen_viewport = d3d11.VIEWPORT {
		TopLeftX = 0,
		TopLeftY = 0,
		Width    = f32(win32_app.client_width),
		Height   = f32(win32_app.client_height),
		MinDepth = 0,
		MaxDepth = 1.0,
	}

	d3d11_renderer.immediate_context->RSSetViewports(1, &d3d11_renderer.screen_viewport)
}

d3d11_renderer_delete :: proc (d3d11_renderer: ^D3D11_Renderer) {
	win32_release_com(&d3d11_renderer.render_target_view)
	win32_release_com(&d3d11_renderer.depth_stencil_view)
	win32_release_com(&d3d11_renderer.swapchain)
	win32_release_com(&d3d11_renderer.depth_stencil_buffer)

	if d3d11_renderer.immediate_context != nil {
		d3d11_renderer.immediate_context->ClearState()
	}

	win32_release_com(&d3d11_renderer.immediate_context)
	win32_release_com(&d3d11_renderer.device)
}

d3d11_renderer_draw_scene :: proc (win32_app: ^Win32_App, d3d11_renderer: ^D3D11_Renderer) {
	assert(d3d11_renderer.immediate_context != nil)
	assert(d3d11_renderer.swapchain != nil)

	background_color := [4]f32 {
		f32(win32_app.background_color_r) / 255.0,
		f32(win32_app.background_color_g) / 255.0,
		f32(win32_app.background_color_b) / 255.0,
		1.0,
	}
	
	d3d11_renderer.immediate_context->ClearRenderTargetView(d3d11_renderer.render_target_view, &background_color)
	d3d11_renderer.immediate_context->ClearDepthStencilView(d3d11_renderer.depth_stencil_view, { .DEPTH, .STENCIL }, 1.0, 0)

	debug_win32_result_ok( d3d11_renderer.swapchain->Present(0, nil) )
}

win32_app_run :: proc (win32_app: ^Win32_App, d3d11_renderer: ^D3D11_Renderer, win32_timer: ^Win32_Timer) {
	win32_timer_init(win32_timer)
	win32_timer_reset(win32_timer)

	for win32_app.running {
		win32_app_process_pending_messages(win32_app)
		win32_timer_tick(win32_timer)

		if !win32_app.paused {
			win32_app_calculate_frame_stats(win32_app, win32_timer)
			d3d11_renderer_draw_scene(win32_app, d3d11_renderer)
		} else {
			win32.Sleep(100)
		}
	}
}

main :: proc() {
	init_window_ok := win32_app_init_window(&win32_app)
	if !init_window_ok {
		return
	}

	init_renderer_ok := d3d11_renderer_init(&win32_app, &d3d11_renderer)
	if !init_renderer_ok {
		return
	}

	win32_app_run(&win32_app, &d3d11_renderer, &win32_timer)
	d3d11_renderer_delete(&d3d11_renderer)
}
