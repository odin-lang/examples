package d3d11_test

import win32 "core:sys/windows"
import fmt "core:fmt"
import d3d11 "vendor:directx/d3d11"
import dxgi "vendor:directx/dxgi"
import d3d "vendor:directx/d3d_compiler"
import glm "core:math/linalg/glsl"

// Based off https://gist.github.com/d7samurai/261c69490cce0620d0bfc93003cd1052

main :: proc() {
	running := true

	// Setup win32
	instance := win32.HINSTANCE(win32.GetModuleHandleW(nil))
	assert(instance != nil, "Failed to fetch current instance")

	lpCmdLine := win32.GetCommandLineW()
	fmt.printfln("Command line used to start this application was: %v", lpCmdLine)

	startup_info : win32.STARTUPINFOW
	win32.GetStartupInfoW(&startup_info)
	nCmdShow := (startup_info.dwFlags & win32.STARTF_USESHOWWINDOW) != 0 ? cast(win32.c_int)startup_info.wShowWindow : win32.SW_SHOWDEFAULT

	CLASS_NAME :: "DirectX Window"

	cls := win32.WNDCLASSW {
		lpfnWndProc = win32_proc,
		lpszClassName = CLASS_NAME,
		hInstance = instance,
		hCursor = win32.LoadCursorA(nil, win32.IDC_ARROW),
		hbrBackground = cast(win32.HBRUSH)cast(uintptr)(win32.COLOR_WINDOW + 1),
	}

	class := win32.RegisterClassW(&cls)
	assert(class != 0, "Class creation failed")

	hwnd := win32.CreateWindowW(CLASS_NAME, win32.L("Win32 + DirectX in Odin"), win32.WS_OVERLAPPEDWINDOW, win32.CW_USEDEFAULT, 0, 800, 600, nil, nil, instance, nil)
	assert(hwnd != nil, "Window creation failed")


	// Setup D3D11
	feature_levels := [?]d3d11.FEATURE_LEVEL{._11_0}

	// dummy device and device context to use to query actual device and device context
	base_device: ^d3d11.IDevice
	base_device_context: ^d3d11.IDeviceContext
	result := d3d11.CreateDevice(nil, .HARDWARE, nil, {.BGRA_SUPPORT}, &feature_levels[0], len(feature_levels), d3d11.SDK_VERSION, &base_device, nil, &base_device_context)

	if result != win32.S_OK { report_error_and_panic("CreateDevice returned with an error.") }
	
	// actual device and device context
	device: ^d3d11.IDevice
	base_device->QueryInterface(d3d11.IDevice_UUID, (^rawptr)(&device))

	device_context: ^d3d11.IDeviceContext
	base_device_context->QueryInterface(d3d11.IDeviceContext_UUID, (^rawptr)(&device_context))

	dxgi_device: ^dxgi.IDevice
	device->QueryInterface(dxgi.IDevice_UUID, (^rawptr)(&dxgi_device)) // CRASH HERE

	dxgi_adapter: ^dxgi.IAdapter
	dxgi_device->GetAdapter(&dxgi_adapter)

	dxgi_factory: ^dxgi.IFactory2
	dxgi_adapter->GetParent(dxgi.IFactory2_UUID, (^rawptr)(&dxgi_factory))

	swapchain_desc := dxgi.SWAP_CHAIN_DESC1{
		Width  = 0,
		Height = 0,
		Format = .B8G8R8A8_UNORM_SRGB,
		Stereo = false,
		SampleDesc = {
			Count   = 1,
			Quality = 0,
		},
		BufferUsage = {.RENDER_TARGET_OUTPUT},
		BufferCount = 2,
		Scaling     = .STRETCH,
		SwapEffect  = .DISCARD,
		AlphaMode   = .UNSPECIFIED,
		Flags       = {},
	}

	swapchain: ^dxgi.ISwapChain1
	dxgi_factory->CreateSwapChainForHwnd(device, hwnd, &swapchain_desc, nil, nil, &swapchain)

	framebuffer: ^d3d11.ITexture2D
	swapchain->GetBuffer(0, d3d11.ITexture2D_UUID, (^rawptr)(&framebuffer))

	framebuffer_view: ^d3d11.IRenderTargetView
	device->CreateRenderTargetView(framebuffer, nil, &framebuffer_view)

	depth_buffer_desc: d3d11.TEXTURE2D_DESC
	framebuffer->GetDesc(&depth_buffer_desc)
	depth_buffer_desc.Format = .D24_UNORM_S8_UINT
	depth_buffer_desc.BindFlags = { .DEPTH_STENCIL }

	depth_buffer: ^d3d11.ITexture2D
	device->CreateTexture2D(&depth_buffer_desc, nil, &depth_buffer)

	depth_buffer_view: ^d3d11.IDepthStencilView
	device->CreateDepthStencilView(depth_buffer, nil, &depth_buffer_view)

	vs_blob: ^d3d11.IBlob
	d3d.Compile(raw_data(shaders_hlsl), len(shaders_hlsl), "shaders.hlsl", nil, nil, "vs_main", "vs_5_0", 0, 0, &vs_blob, nil)
	assert(vs_blob != nil)

	vertex_shader: ^d3d11.IVertexShader
	device->CreateVertexShader(vs_blob->GetBufferPointer(), vs_blob->GetBufferSize(), nil, &vertex_shader)

	input_element_desc := [?]d3d11.INPUT_ELEMENT_DESC{
		{ "POS", 0, .R32G32B32_FLOAT, 0,                            0, .VERTEX_DATA, 0 },
		{ "NOR", 0, .R32G32B32_FLOAT, 0, d3d11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA, 0 },
		{ "TEX", 0, .R32G32_FLOAT,    0, d3d11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA, 0 },
		{ "COL", 0, .R32G32B32_FLOAT, 0, d3d11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA, 0 },
	}

	input_layout: ^d3d11.IInputLayout
	device->CreateInputLayout(&input_element_desc[0], len(input_element_desc), vs_blob->GetBufferPointer(), vs_blob->GetBufferSize(), &input_layout)

	ps_blob: ^d3d11.IBlob
	d3d.Compile(raw_data(shaders_hlsl), len(shaders_hlsl), "shaders.hlsl", nil, nil, "ps_main", "ps_5_0", 0, 0, &ps_blob, nil)

	pixel_shader: ^d3d11.IPixelShader
	device->CreatePixelShader(ps_blob->GetBufferPointer(), ps_blob->GetBufferSize(), nil, &pixel_shader)

	rasterizer_desc := d3d11.RASTERIZER_DESC{
		FillMode = .SOLID,
		CullMode = .BACK,
	}
	rasterizer_state: ^d3d11.IRasterizerState
	device->CreateRasterizerState(&rasterizer_desc, &rasterizer_state)

	sampler_desc := d3d11.SAMPLER_DESC{
		Filter         = .MIN_MAG_MIP_POINT,
		AddressU       = .WRAP,
		AddressV       = .WRAP,
		AddressW       = .WRAP,
		ComparisonFunc = .NEVER,
	}
	sampler_state: ^d3d11.ISamplerState
	device->CreateSamplerState(&sampler_desc, &sampler_state)


	depth_stencil_desc := d3d11.DEPTH_STENCIL_DESC{
		DepthEnable    = true,
		DepthWriteMask = .ALL,
		DepthFunc      = .LESS,
	}
	depth_stencil_state: ^d3d11.IDepthStencilState
	device->CreateDepthStencilState(&depth_stencil_desc, &depth_stencil_state)


	Constants :: struct #align (16) {
		transform:    glm.mat4,
		projection:   glm.mat4,
		light_vector: glm.vec3,
	}

	constant_buffer_desc := d3d11.BUFFER_DESC{
		ByteWidth      = size_of(Constants),
		Usage          = .DYNAMIC,
		BindFlags      = {.CONSTANT_BUFFER},
		CPUAccessFlags = {.WRITE},
	}
	constant_buffer: ^d3d11.IBuffer
	device->CreateBuffer(&constant_buffer_desc, nil, &constant_buffer)

	vertex_buffer_desc := d3d11.BUFFER_DESC{
		ByteWidth = size_of(vertex_data),
		Usage     = .IMMUTABLE,
		BindFlags = {.VERTEX_BUFFER},
	}
	vertex_buffer: ^d3d11.IBuffer
	device->CreateBuffer(&vertex_buffer_desc, &d3d11.SUBRESOURCE_DATA{pSysMem = &vertex_data[0], SysMemPitch = size_of(vertex_data)}, &vertex_buffer)

	index_buffer_desc := d3d11.BUFFER_DESC{
		ByteWidth = size_of(index_data),
		Usage     = .IMMUTABLE,
		BindFlags = {.INDEX_BUFFER},
	}
	index_buffer: ^d3d11.IBuffer
	device->CreateBuffer(&index_buffer_desc, &d3d11.SUBRESOURCE_DATA{pSysMem = &index_data[0], SysMemPitch = size_of(index_data)}, &index_buffer)

	texture_desc := d3d11.TEXTURE2D_DESC{
		Width      = TEXTURE_WIDTH,
		Height     = TEXTURE_HEIGHT,
		MipLevels  = 1,
		ArraySize  = 1,
		Format     = .R8G8B8A8_UNORM_SRGB,
		SampleDesc = {Count = 1},
		Usage      = .IMMUTABLE,
		BindFlags  = {.SHADER_RESOURCE},
	}

	texture_data := d3d11.SUBRESOURCE_DATA{
		pSysMem     = &texture_data[0],
		SysMemPitch = TEXTURE_WIDTH * 4,
	}

	texture: ^d3d11.ITexture2D
	device->CreateTexture2D(&texture_desc, &texture_data, &texture)

	texture_view: ^d3d11.IShaderResourceView
	device->CreateShaderResourceView(texture, nil, &texture_view)

	vertex_buffer_stride := u32(11 * 4)
	vertex_buffer_offset := u32(0)

	model_rotation    := glm.vec3{0.0, 0.0, 0.0}
	model_translation := glm.vec3{0.0, 0.0, 4.0}
	
	win32.ShowWindow(hwnd, nCmdShow)
	win32.UpdateWindow(hwnd)

	for running {
		msg : win32.MSG

		for win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE) {
			if msg.message == win32.WM_KEYDOWN {
				running = false
				break
			}

			win32.TranslateMessage(&msg)
			win32.DispatchMessageW(&msg)
		}

		// update loop if we bothered to make one
		viewport := d3d11.VIEWPORT{
			0, 0,
			f32(depth_buffer_desc.Width), f32(depth_buffer_desc.Height),
			0, 1,
		}

		// Setup projection
		w := viewport.Width / viewport.Height
		h := f32(1)
		n := f32(1)
		f := f32(9)

		rotate_x := glm.mat4Rotate({1, 0, 0}, model_rotation.x)
		rotate_y := glm.mat4Rotate({0, 1, 0}, model_rotation.y)
		rotate_z := glm.mat4Rotate({0, 0, 1}, model_rotation.z)
		translate := glm.mat4Translate(model_translation)

		model_rotation.x += 0.005
		model_rotation.y += 0.009
		model_rotation.z += 0.001

		mapped_subresource: d3d11.MAPPED_SUBRESOURCE
		device_context->Map(constant_buffer, 0, .WRITE_DISCARD, {}, &mapped_subresource)
		{
			constants := (^Constants)(mapped_subresource.pData)
			constants.transform = translate * rotate_z * rotate_y * rotate_x
			constants.light_vector = {+1, -1, +1}

			constants.projection = {
				2 * n / w, 0,         0,           0,
				0,         2 * n / h, 0,           0,
				0,         0,         f / (f - n), n * f / (n - f),
				0,         0,         1,           0,
			}
		}
		device_context->Unmap(constant_buffer, 0)

		// render procedure if we had one
		device_context->ClearRenderTargetView(framebuffer_view, &[4]f32{0, 0, 0, 1.0})
		device_context->ClearDepthStencilView(depth_buffer_view, {.DEPTH}, 1, 0)

		device_context->IASetPrimitiveTopology(.TRIANGLELIST)
		device_context->IASetInputLayout(input_layout)
		device_context->IASetVertexBuffers(0, 1, &vertex_buffer, &vertex_buffer_stride, &vertex_buffer_offset)
		device_context->IASetIndexBuffer(index_buffer, .R32_UINT, 0)

		device_context->VSSetShader(vertex_shader, nil, 0)
		device_context->VSSetConstantBuffers(0, 1, &constant_buffer)

		device_context->RSSetViewports(1, &viewport)
		device_context->RSSetState(rasterizer_state)

		device_context->PSSetShader(pixel_shader, nil, 0)
		device_context->PSSetShaderResources(0, 1, &texture_view)
		device_context->PSSetSamplers(0, 1, &sampler_state)

		device_context->OMSetRenderTargets(1, &framebuffer_view, depth_buffer_view)
		device_context->OMSetDepthStencilState(depth_stencil_state, 0)
		device_context->OMSetBlendState(nil, nil, ~u32(0)) // use default blend mode (i.e. disable)

		///////////////////////////////////////////////////////////////////////////////////////////////

		device_context->DrawIndexed(len(index_data), 0, 0)

		swapchain->Present(1, {})
	}
}

win32_proc :: proc "stdcall" (hwnd: win32.HWND, msg: win32.UINT, wParam : win32.WPARAM, lParam : win32.LPARAM) -> win32.LRESULT {
	switch(msg) {
	case win32.WM_DESTROY:
		win32.PostQuitMessage(0)
	}

	return win32.DefWindowProcW(hwnd, msg, wParam, lParam)
}

message_box :: #force_inline proc(text, caption: string, loc := #caller_location) {
	win32.MessageBoxW(nil, win32.utf8_to_wstring(text), win32.utf8_to_wstring(caption), win32.MB_ICONSTOP | win32.MB_OK)
}

report_error_and_panic :: proc(msg: string, loc := #caller_location) {
	win32.MessageBeep(win32.MB_ICONERROR)
	message_box(fmt.tprintf("%s\nError:%x\n", msg, win32.GetLastError()), "PANIC!!!")
	panic(msg, loc = loc)
}

shaders_hlsl := `
	cbuffer constants : register(b0) {
		float4x4 transform;
		float4x4 projection;
		float3 light_vector;
	}
	struct vs_in {
		float3 position : POS;
		float3 normal   : NOR;
		float2 texcoord : TEX;
		float3 color    : COL;
	};
	struct vs_out {
		float4 position : SV_POSITION;
		float2 texcoord : TEX;
		float4 color    : COL;
	};
	Texture2D    mytexture : register(t0);
	SamplerState mysampler : register(s0);
	vs_out vs_main(vs_in input) {
		float light = clamp(dot(normalize(mul(transform, float4(input.normal, 0.0f)).xyz), normalize(-light_vector)), 0.0f, 1.0f) * 0.8f + 0.2f;
		vs_out output;
		output.position = mul(projection, mul(transform, float4(input.position, 1.0f)));
		output.texcoord = input.texcoord;
		output.color    = float4(input.color * light, 1.0f);
		return output;
	}
	float4 ps_main(vs_out input) : SV_TARGET {
		return mytexture.Sample(mysampler, input.texcoord) * input.color;
	}
`

TEXTURE_WIDTH  :: 2
TEXTURE_HEIGHT :: 2

texture_data := [TEXTURE_WIDTH*TEXTURE_HEIGHT]u32{
	0xffffffff, 0xff7f7f7f,
	0xff7f7f7f, 0xffffffff,
}

// position: float3, normal: float3, texcoord: float2, color: float3
vertex_data := [?]f32{
	-1.0,  1.0, -1.0,  0.0,  0.0, -1.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	-0.6,  1.0, -1.0,  0.0,  0.0, -1.0,  2.0,  0.0,  0.973,  0.480,  0.002,
	 0.6,  1.0, -1.0,  0.0,  0.0, -1.0,  8.0,  0.0,  0.973,  0.480,  0.002,
	 1.0,  1.0, -1.0,  0.0,  0.0, -1.0, 10.0,  0.0,  0.973,  0.480,  0.002,
	-0.6,  0.6, -1.0,  0.0,  0.0, -1.0,  2.0,  2.0,  0.973,  0.480,  0.002,
	 0.6,  0.6, -1.0,  0.0,  0.0, -1.0,  8.0,  2.0,  0.973,  0.480,  0.002,
	-0.6, -0.6, -1.0,  0.0,  0.0, -1.0,  2.0,  8.0,  0.973,  0.480,  0.002,
	 0.6, -0.6, -1.0,  0.0,  0.0, -1.0,  8.0,  8.0,  0.973,  0.480,  0.002,
	-1.0, -1.0, -1.0,  0.0,  0.0, -1.0,  0.0, 10.0,  0.973,  0.480,  0.002,
	-0.6, -1.0, -1.0,  0.0,  0.0, -1.0,  2.0, 10.0,  0.973,  0.480,  0.002,
	 0.6, -1.0, -1.0,  0.0,  0.0, -1.0,  8.0, 10.0,  0.973,  0.480,  0.002,
	 1.0, -1.0, -1.0,  0.0,  0.0, -1.0, 10.0, 10.0,  0.973,  0.480,  0.002,
	 1.0,  1.0, -1.0,  1.0,  0.0,  0.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 1.0,  1.0, -0.6,  1.0,  0.0,  0.0,  2.0,  0.0,  0.897,  0.163,  0.011,
	 1.0,  1.0,  0.6,  1.0,  0.0,  0.0,  8.0,  0.0,  0.897,  0.163,  0.011,
	 1.0,  1.0,  1.0,  1.0,  0.0,  0.0, 10.0,  0.0,  0.897,  0.163,  0.011,
	 1.0,  0.6, -0.6,  1.0,  0.0,  0.0,  2.0,  2.0,  0.897,  0.163,  0.011,
	 1.0,  0.6,  0.6,  1.0,  0.0,  0.0,  8.0,  2.0,  0.897,  0.163,  0.011,
	 1.0, -0.6, -0.6,  1.0,  0.0,  0.0,  2.0,  8.0,  0.897,  0.163,  0.011,
	 1.0, -0.6,  0.6,  1.0,  0.0,  0.0,  8.0,  8.0,  0.897,  0.163,  0.011,
	 1.0, -1.0, -1.0,  1.0,  0.0,  0.0,  0.0, 10.0,  0.897,  0.163,  0.011,
	 1.0, -1.0, -0.6,  1.0,  0.0,  0.0,  2.0, 10.0,  0.897,  0.163,  0.011,
	 1.0, -1.0,  0.6,  1.0,  0.0,  0.0,  8.0, 10.0,  0.897,  0.163,  0.011,
	 1.0, -1.0,  1.0,  1.0,  0.0,  0.0, 10.0, 10.0,  0.897,  0.163,  0.011,
	 1.0,  1.0,  1.0,  0.0,  0.0,  1.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	 0.6,  1.0,  1.0,  0.0,  0.0,  1.0,  2.0,  0.0,  0.612,  0.000,  0.069,
	-0.6,  1.0,  1.0,  0.0,  0.0,  1.0,  8.0,  0.0,  0.612,  0.000,  0.069,
	-1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 10.0,  0.0,  0.612,  0.000,  0.069,
	 0.6,  0.6,  1.0,  0.0,  0.0,  1.0,  2.0,  2.0,  0.612,  0.000,  0.069,
	-0.6,  0.6,  1.0,  0.0,  0.0,  1.0,  8.0,  2.0,  0.612,  0.000,  0.069,
	 0.6, -0.6,  1.0,  0.0,  0.0,  1.0,  2.0,  8.0,  0.612,  0.000,  0.069,
	-0.6, -0.6,  1.0,  0.0,  0.0,  1.0,  8.0,  8.0,  0.612,  0.000,  0.069,
	 1.0, -1.0,  1.0,  0.0,  0.0,  1.0,  0.0, 10.0,  0.612,  0.000,  0.069,
	 0.6, -1.0,  1.0,  0.0,  0.0,  1.0,  2.0, 10.0,  0.612,  0.000,  0.069,
	-0.6, -1.0,  1.0,  0.0,  0.0,  1.0,  8.0, 10.0,  0.612,  0.000,  0.069,
	-1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 10.0, 10.0,  0.612,  0.000,  0.069,
	-1.0,  1.0,  1.0, -1.0,  0.0,  0.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-1.0,  1.0,  0.6, -1.0,  0.0,  0.0,  2.0,  0.0,  0.127,  0.116,  0.408,
	-1.0,  1.0, -0.6, -1.0,  0.0,  0.0,  8.0,  0.0,  0.127,  0.116,  0.408,
	-1.0,  1.0, -1.0, -1.0,  0.0,  0.0, 10.0,  0.0,  0.127,  0.116,  0.408,
	-1.0,  0.6,  0.6, -1.0,  0.0,  0.0,  2.0,  2.0,  0.127,  0.116,  0.408,
	-1.0,  0.6, -0.6, -1.0,  0.0,  0.0,  8.0,  2.0,  0.127,  0.116,  0.408,
	-1.0, -0.6,  0.6, -1.0,  0.0,  0.0,  2.0,  8.0,  0.127,  0.116,  0.408,
	-1.0, -0.6, -0.6, -1.0,  0.0,  0.0,  8.0,  8.0,  0.127,  0.116,  0.408,
	-1.0, -1.0,  1.0, -1.0,  0.0,  0.0,  0.0, 10.0,  0.127,  0.116,  0.408,
	-1.0, -1.0,  0.6, -1.0,  0.0,  0.0,  2.0, 10.0,  0.127,  0.116,  0.408,
	-1.0, -1.0, -0.6, -1.0,  0.0,  0.0,  8.0, 10.0,  0.127,  0.116,  0.408,
	-1.0, -1.0, -1.0, -1.0,  0.0,  0.0, 10.0, 10.0,  0.127,  0.116,  0.408,
	-1.0,  1.0,  1.0,  0.0,  1.0,  0.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	-0.6,  1.0,  1.0,  0.0,  1.0,  0.0,  2.0,  0.0,  0.000,  0.254,  0.637,
	 0.6,  1.0,  1.0,  0.0,  1.0,  0.0,  8.0,  0.0,  0.000,  0.254,  0.637,
	 1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 10.0,  0.0,  0.000,  0.254,  0.637,
	-0.6,  1.0,  0.6,  0.0,  1.0,  0.0,  2.0,  2.0,  0.000,  0.254,  0.637,
	 0.6,  1.0,  0.6,  0.0,  1.0,  0.0,  8.0,  2.0,  0.000,  0.254,  0.637,
	-0.6,  1.0, -0.6,  0.0,  1.0,  0.0,  2.0,  8.0,  0.000,  0.254,  0.637,
	 0.6,  1.0, -0.6,  0.0,  1.0,  0.0,  8.0,  8.0,  0.000,  0.254,  0.637,
	-1.0,  1.0, -1.0,  0.0,  1.0,  0.0,  0.0, 10.0,  0.000,  0.254,  0.637,
	-0.6,  1.0, -1.0,  0.0,  1.0,  0.0,  2.0, 10.0,  0.000,  0.254,  0.637,
	 0.6,  1.0, -1.0,  0.0,  1.0,  0.0,  8.0, 10.0,  0.000,  0.254,  0.637,
	 1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 10.0, 10.0,  0.000,  0.254,  0.637,
	-1.0, -1.0, -1.0,  0.0, -1.0,  0.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	-0.6, -1.0, -1.0,  0.0, -1.0,  0.0,  2.0,  0.0,  0.001,  0.447,  0.067,
	 0.6, -1.0, -1.0,  0.0, -1.0,  0.0,  8.0,  0.0,  0.001,  0.447,  0.067,
	 1.0, -1.0, -1.0,  0.0, -1.0,  0.0, 10.0,  0.0,  0.001,  0.447,  0.067,
	-0.6, -1.0, -0.6,  0.0, -1.0,  0.0,  2.0,  2.0,  0.001,  0.447,  0.067,
	 0.6, -1.0, -0.6,  0.0, -1.0,  0.0,  8.0,  2.0,  0.001,  0.447,  0.067,
	-0.6, -1.0,  0.6,  0.0, -1.0,  0.0,  2.0,  8.0,  0.001,  0.447,  0.067,
	 0.6, -1.0,  0.6,  0.0, -1.0,  0.0,  8.0,  8.0,  0.001,  0.447,  0.067,
	-1.0, -1.0,  1.0,  0.0, -1.0,  0.0,  0.0, 10.0,  0.001,  0.447,  0.067,
	-0.6, -1.0,  1.0,  0.0, -1.0,  0.0,  2.0, 10.0,  0.001,  0.447,  0.067,
	 0.6, -1.0,  1.0,  0.0, -1.0,  0.0,  8.0, 10.0,  0.001,  0.447,  0.067,
	 1.0, -1.0,  1.0,  0.0, -1.0,  0.0, 10.0, 10.0,  0.001,  0.447,  0.067,
	-0.6,  0.6, -1.0,  1.0,  0.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	-0.6,  0.6, -0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	-0.6, -0.6, -0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	-0.6, -0.6, -1.0,  1.0,  0.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	 0.6,  0.6, -0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	 0.6,  0.6, -1.0, -1.0,  0.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	 0.6, -0.6, -1.0, -1.0,  0.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	 0.6, -0.6, -0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	-0.6, -0.6, -1.0,  0.0,  1.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	-0.6, -0.6, -0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	 0.6, -0.6, -0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	 0.6, -0.6, -1.0,  0.0,  1.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	-0.6,  0.6, -0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	-0.6,  0.6, -1.0,  0.0, -1.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	 0.6,  0.6, -1.0,  0.0, -1.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	 0.6,  0.6, -0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.973,  0.480,  0.002,
	 1.0,  0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 0.6,  0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 0.6, -0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 1.0, -0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 0.6,  0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 1.0,  0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 1.0, -0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 0.6, -0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 1.0,  0.6,  0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 0.6,  0.6,  0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 0.6,  0.6, -0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 1.0,  0.6, -0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 0.6, -0.6,  0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 1.0, -0.6,  0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 1.0, -0.6, -0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 0.6, -0.6, -0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.897,  0.163,  0.011,
	 0.6,  0.6,  1.0, -1.0,  0.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	 0.6,  0.6,  0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	 0.6, -0.6,  0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	 0.6, -0.6,  1.0, -1.0,  0.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	-0.6,  0.6,  0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	-0.6,  0.6,  1.0,  1.0,  0.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	-0.6, -0.6,  1.0,  1.0,  0.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	-0.6, -0.6,  0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	 0.6, -0.6,  1.0,  0.0,  1.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	 0.6, -0.6,  0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	-0.6, -0.6,  0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	-0.6, -0.6,  1.0,  0.0,  1.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	 0.6,  0.6,  0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	 0.6,  0.6,  1.0,  0.0, -1.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	-0.6,  0.6,  1.0,  0.0, -1.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	-0.6,  0.6,  0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.612,  0.000,  0.069,
	-1.0,  0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-0.6,  0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-0.6, -0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-1.0, -0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-0.6,  0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-1.0,  0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-1.0, -0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-0.6, -0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-1.0, -0.6,  0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-0.6, -0.6,  0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-0.6, -0.6, -0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-1.0, -0.6, -0.6,  0.0,  1.0,  0.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-0.6,  0.6,  0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-1.0,  0.6,  0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-1.0,  0.6, -0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-0.6,  0.6, -0.6,  0.0, -1.0,  0.0,  0.0,  0.0,  0.127,  0.116,  0.408,
	-0.6,  1.0,  0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	-0.6,  0.6,  0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	-0.6,  0.6, -0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	-0.6,  1.0, -0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	 0.6,  0.6,  0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	 0.6,  1.0,  0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	 0.6,  1.0, -0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	 0.6,  0.6, -0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	-0.6,  1.0, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	-0.6,  0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	 0.6,  0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	 0.6,  1.0, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	-0.6,  0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	-0.6,  1.0,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	 0.6,  1.0,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	 0.6,  0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.000,  0.254,  0.637,
	-0.6, -0.6,  0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	-0.6, -1.0,  0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	-0.6, -1.0, -0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	-0.6, -0.6, -0.6,  1.0,  0.0,  0.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	 0.6, -1.0,  0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	 0.6, -0.6,  0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	 0.6, -0.6, -0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	 0.6, -1.0, -0.6, -1.0,  0.0,  0.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	-0.6, -0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	-0.6, -1.0, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	 0.6, -1.0, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	 0.6, -0.6, -0.6,  0.0,  0.0,  1.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	-0.6, -1.0,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	-0.6, -0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	 0.6, -0.6,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.001,  0.447,  0.067,
	 0.6, -1.0,  0.6,  0.0,  0.0, -1.0,  0.0,  0.0,  0.001,  0.447,  0.067,
}

index_data := [?]u32{
	  0,   1,   9,   9,   8,   0,   1,   2,   5,   5,   4,   1,   6,   7,  10,  10,   9,   6,   2,   3,  11,  11,  10,   2,
	 12,  13,  21,  21,  20,  12,  13,  14,  17,  17,  16,  13,  18,  19,  22,  22,  21,  18,  14,  15,  23,  23,  22,  14,
	 24,  25,  33,  33,  32,  24,  25,  26,  29,  29,  28,  25,  30,  31,  34,  34,  33,  30,  26,  27,  35,  35,  34,  26,
	 36,  37,  45,  45,  44,  36,  37,  38,  41,  41,  40,  37,  42,  43,  46,  46,  45,  42,  38,  39,  47,  47,  46,  38,
	 48,  49,  57,  57,  56,  48,  49,  50,  53,  53,  52,  49,  54,  55,  58,  58,  57,  54,  50,  51,  59,  59,  58,  50,
	 60,  61,  69,  69,  68,  60,  61,  62,  65,  65,  64,  61,  66,  67,  70,  70,  69,  66,  62,  63,  71,  71,  70,  62,
	 72,  73,  74,  74,  75,  72,  76,  77,  78,  78,  79,  76,  80,  81,  82,  82,  83,  80,  84,  85,  86,  86,  87,  84,
	 88,  89,  90,  90,  91,  88,  92,  93,  94,  94,  95,  92,  96,  97,  98,  98,  99,  96, 100, 101, 102, 102, 103, 100,
	104, 105, 106, 106, 107, 104, 108, 109, 110, 110, 111, 108, 112, 113, 114, 114, 115, 112, 116, 117, 118, 118, 119, 116,
	120, 121, 122, 122, 123, 120, 124, 125, 126, 126, 127, 124, 128, 129, 130, 130, 131, 128, 132, 133, 134, 134, 135, 132,
	136, 137, 138, 138, 139, 136, 140, 141, 142, 142, 143, 140, 144, 145, 146, 146, 147, 144, 148, 149, 150, 150, 151, 148,
	152, 153, 154, 154, 155, 152, 156, 157, 158, 158, 159, 156, 160, 161, 162, 162, 163, 160, 164, 165, 166, 166, 167, 164,
}
