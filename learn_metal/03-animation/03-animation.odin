package main

import NS "vendor:darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

import SDL "vendor:sdl2"

import "core:fmt"
import "core:os"


Frame_Data :: struct {
	angle: f32,
}

build_shaders :: proc(device: ^MTL.Device) -> (library: ^MTL.Library, pso: ^MTL.RenderPipelineState, err: ^NS.Error) {
	shader_src := `
	#include <metal_stdlib>
	using namespace metal;

	struct v2f {
		float4 position [[position]];
		half3 color;
	};

	struct Vertex_Data {
		device packed_float3* positions [[id(0)]];
		device packed_float3* colors    [[id(1)]];
	};

	struct Frame_Data {
		float angle;
	};

	v2f vertex vertex_main(device const Vertex_Data* vertex_data [[buffer(0)]],
	                       device const Frame_Data*  frame_data  [[buffer(1)]],
	                       uint vertex_id                        [[vertex_id]]) {
		float a = frame_data->angle;
		float3x3 rotation_matrix = float3x3(sin(a), cos(a), 0.0, cos(a), -sin(a), 0.0, 0.0, 0.0, 1.0);
		float3 position = float3(vertex_data->positions[vertex_id]);
		v2f o;
		o.position = float4(rotation_matrix * position, 1.0);
		o.color = half3(vertex_data->colors[vertex_id]);
		return o;
	}

	half4 fragment fragment_main(v2f in [[stage_in]]) {
		return half4(in.color, 1.0);
	}
	`
	shader_src_str := NS.String.alloc()->initWithOdinString(shader_src)
	defer shader_src_str->release()

	library = device->newLibraryWithSource(shader_src_str, nil) or_return

	vertex_function   := library->newFunctionWithName(NS.AT("vertex_main"))
	fragment_function := library->newFunctionWithName(NS.AT("fragment_main"))
	defer vertex_function->release()
	defer fragment_function->release()

	desc := MTL.RenderPipelineDescriptor.alloc()->init()
	defer desc->release()

	desc->setVertexFunction(vertex_function)
	desc->setFragmentFunction(fragment_function)
	desc->colorAttachments()->object(0)->setPixelFormat(.BGRA8Unorm_sRGB)

	pso = device->newRenderPipelineStateWithDescriptor(desc) or_return
	return
}

build_buffers :: proc(device: ^MTL.Device, library: ^MTL.Library) -> (vertex_positions_buffer, vertex_colors_buffer, arg_buffer: ^MTL.Buffer) {
	NUM_VERTICES :: 3
	positions := [NUM_VERTICES][3]f32{
		{-0.8,  0.8, 0.0},
		{ 0.0, -0.8, 0.0},
		{+0.8,  0.8, 0.0},
	}
	colors := [NUM_VERTICES][3]f32{
		{1.0, 0.3, 0.2},
		{0.8, 1.0, 0.0},
		{0.8, 0.0, 1.0},
	}

	vertex_positions_buffer = device->newBufferWithSlice(positions[:], {.StorageModeManaged})
	vertex_colors_buffer    = device->newBufferWithSlice(colors[:],    {.StorageModeManaged})

	vertex_function := library->newFunctionWithName(NS.AT("vertex_main"))
	defer vertex_function->release()

	arg_encoder := vertex_function->newArgumentEncoder(0)
	defer arg_encoder->release()

	arg_buffer = device->newBuffer(arg_encoder->encodedLength(), {.StorageModeManaged})
	arg_encoder->setArgumentBufferWithOffset(arg_buffer, 0)
	arg_encoder->setBuffer(vertex_positions_buffer, 0, 0)
	arg_encoder->setBuffer(vertex_colors_buffer,    0, 1)
	arg_buffer->didModifyRange(NS.Range_Make(0, arg_buffer->length()))

	return
}

metal_main :: proc() -> (err: ^NS.Error) {
	SDL.SetHint(SDL.HINT_RENDER_DRIVER, "metal")
	SDL.setenv("METAL_DEVICE_WRAPPER_TYPE", "1", 0)
	SDL.Init({.VIDEO})
	defer SDL.Quit()

	window := SDL.CreateWindow("Metal in Odin - 03 animation",
		SDL.WINDOWPOS_CENTERED, SDL.WINDOWPOS_CENTERED,
		854, 480,
		{.ALLOW_HIGHDPI, .HIDDEN, .RESIZABLE},
	)
	defer SDL.DestroyWindow(window)

	window_system_info: SDL.SysWMinfo
	SDL.GetVersion(&window_system_info.version)
	SDL.GetWindowWMInfo(window, &window_system_info)
	assert(window_system_info.subsystem == .COCOA)

	native_window := (^NS.Window)(window_system_info.info.cocoa.window)

	device := MTL.CreateSystemDefaultDevice()
	defer device->release()

	fmt.println(device->name()->odinString())

	swapchain := CA.MetalLayer.layer()
	defer swapchain->release()

	swapchain->setDevice(device)
	swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	swapchain->setFramebufferOnly(true)
	swapchain->setFrame(native_window->frame())

	native_window->contentView()->setLayer(swapchain)
	native_window->setOpaque(true)
	native_window->setBackgroundColor(nil)

	library, pso := build_shaders(device) or_return
	defer library->release()
	defer pso->release()

	vertex_positions_buffer, vertex_colors_buffer, arg_buffer := build_buffers(device, library)
	defer arg_buffer->release()

	frame_data_buffer := device->newBuffer(size_of(Frame_Data), {.StorageModeManaged})
	defer frame_data_buffer->release()

	command_queue := device->newCommandQueue()
	defer command_queue->release()

	SDL.ShowWindow(window)
	for quit := false; !quit;  {
		for e: SDL.Event; SDL.PollEvent(&e); {
			#partial switch e.type {
			case .QUIT:
				quit = true
			case .KEYDOWN:
				if e.key.keysym.sym == .ESCAPE {
					quit = true
				}
			}
		}

		@static angle: f32
		frame_data := (^Frame_Data)(frame_data_buffer->contentsPointer())
		frame_data.angle = angle
		angle += 0.01
		frame_data_buffer->didModifyRange(NS.Range_Make(0, size_of(Frame_Data)))

		drawable := swapchain->nextDrawable()
		assert(drawable != nil)
		defer drawable->release()

		pass := MTL.RenderPassDescriptor.renderPassDescriptor()
		defer pass->release()

		color_attachment := pass->colorAttachments()->object(0)
		assert(color_attachment != nil)
		color_attachment->setClearColor(MTL.ClearColor{0.25, 0.5, 1.0, 1.0})
		color_attachment->setLoadAction(.Clear)
		color_attachment->setStoreAction(.Store)
		color_attachment->setTexture(drawable->texture())

		command_buffer := command_queue->commandBuffer()
		defer command_buffer->release()

		render_encoder := command_buffer->renderCommandEncoderWithDescriptor(pass)
		defer render_encoder->release()

		render_encoder->setRenderPipelineState(pso)
		render_encoder->setVertexBuffer(arg_buffer,        0, 0)
		render_encoder->setVertexBuffer(frame_data_buffer, 0, 1)
		render_encoder->useResource(vertex_positions_buffer, {.Read})
		render_encoder->useResource(vertex_colors_buffer, {.Read})
		render_encoder->drawPrimitives(.Triangle, 0, 3)

		render_encoder->endEncoding()

		command_buffer->presentDrawable(drawable)
		command_buffer->commit()
	}

	return nil
}

main :: proc() {
	err := metal_main()
	if err != nil {
		fmt.eprintln(err->localizedDescription()->odinString())
		os.exit(1)
	}
}
