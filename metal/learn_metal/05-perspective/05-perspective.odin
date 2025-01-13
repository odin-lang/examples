package main

import NS  "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA  "vendor:darwin/QuartzCore"

import SDL "vendor:sdl2"

import "core:fmt"
import "core:os"
import "core:math"
import glm "core:math/linalg/glsl"


Instance_Data :: struct #align(16) {
	transform: glm.mat4,
	color:     glm.vec4,
}

NUM_INSTANCES :: 32

Camera_Data :: struct {
	perspective_transform: glm.mat4,
	world_transform:       glm.mat4,
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
		packed_float3 position;
	};

	struct Instance_Data {
		float4x4 transform;
		float4   color;
	};

	struct Camera_Data {
		float4x4 perspective_transform;
		float4x4 world_transform;
	};

	v2f vertex vertex_main(device const Vertex_Data*   vertex_data   [[buffer(0)]],
	                       device const Instance_Data* instance_data [[buffer(1)]],
	                       device const Camera_Data&   camera_data   [[buffer(2)]],
	                       uint vertex_id                            [[vertex_id]],
	                       uint instance_id                          [[instance_id]]) {
		v2f o;
		float4 pos = float4(vertex_data[vertex_id].position, 1.0);
		pos = instance_data[instance_id].transform * pos;
		pos = camera_data.perspective_transform * camera_data.world_transform * pos;
		o.position = pos;
		o.color = half3(instance_data[instance_id].color.rgb);
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
	desc->setDepthAttachmentPixelFormat(.Depth16Unorm)

	pso = device->newRenderPipelineStateWithDescriptor(desc) or_return
	return
}

build_buffers :: proc(device: ^MTL.Device) -> (vertex_buffer, index_buffer, instance_buffer: ^MTL.Buffer) {
	s :: 0.5
	positions := [][3]f32{
		{-s, -s, +s},
		{+s, -s, +s},
		{+s, +s, +s},
		{-s, +s, +s},

		{-s, -s, -s},
		{-s, +s, -s},
		{+s, +s, -s},
		{+s, -s, -s},
	}
	indices := []u16{
		0, 1, 2, // front
		2, 3, 0,

		1, 7, 6, // right
		6, 2, 1,

		7, 4, 5, // back
		5, 6, 7,

		4, 0, 3, // left
		3, 5, 4,

		3, 2, 6, // top
		6, 5, 3,

		4, 7, 1, // bottom
		1, 0, 4,
	}

	vertex_buffer   = device->newBufferWithSlice(positions[:], {.StorageModeManaged})
	index_buffer    = device->newBufferWithSlice(indices[:],   {.StorageModeManaged})
	instance_buffer = device->newBuffer(NUM_INSTANCES*size_of(Instance_Data), {.StorageModeManaged})
	return
}

metal_main :: proc() -> (err: ^NS.Error) {
	SDL.SetHint(SDL.HINT_RENDER_DRIVER, "metal")
	SDL.setenv("METAL_DEVICE_WRAPPER_TYPE", "1", 0)
	SDL.Init({.VIDEO})
	defer SDL.Quit()

	window := SDL.CreateWindow("Metal in Odin - 05 perspective",
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

	vertex_buffer, index_buffer, instance_buffer := build_buffers(device)
	defer vertex_buffer->release()
	defer index_buffer->release()
	defer instance_buffer->release()

	camera_buffer := device->newBuffer(size_of(Camera_Data), {.StorageModeManaged})
	defer camera_buffer->release()

	depth_texture: ^MTL.Texture = nil

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

		w, h: i32
		SDL.GetWindowSize(window, &w, &h)
		aspect_ratio := f32(w)/max(f32(h), 1)

		{
			@static angle: f32
			angle += 0.01

			object_position := glm.vec3{0, 0, -5}
			rt := glm.mat4Translate(object_position)
			rr := glm.mat4Rotate({0, 1, 0}, -angle)
			rt_inv := glm.mat4Translate(-object_position)
			full_obj_rot := rt * rr * rt_inv

			instance_data := instance_buffer->contentsAsSlice([]Instance_Data)[:NUM_INSTANCES]
			for &instance, idx in instance_data {
				scl :: 0.1

				i := f32(idx) / NUM_INSTANCES
				xoff := (i*2 - 1) + (1.0/NUM_INSTANCES)
				yoff := math.sin((i + angle) * math.TAU)

				scale := glm.mat4Scale({scl, scl, scl})
				zrot := glm.mat4Rotate({0, 0, 1}, angle)
				yrot := glm.mat4Rotate({0, 1, 0}, angle)
				translate := glm.mat4Translate(object_position + {xoff, yoff, 0})

				instance.transform = full_obj_rot * translate * yrot * zrot * scale
				instance.color = {i, 1-i, math.sin(math.TAU * i), 1}
			}
			sz := NS.UInteger(len(instance_data)*size_of(instance_data[0]))
			instance_buffer->didModifyRange(NS.Range_Make(0, sz))
		}

		{
			camera_data := camera_buffer->contentsAsType(Camera_Data)
			camera_data.perspective_transform = glm.mat4Perspective(glm.radians_f32(45), aspect_ratio, 0.03, 500)
			camera_data.world_transform = 1

			camera_buffer->didModifyRange(NS.Range_Make(0, size_of(Camera_Data)))

		}

		if depth_texture == nil ||
		   depth_texture->width() != NS.UInteger(w) ||
		   depth_texture->height() != NS.UInteger(h) {
			desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
				pixelFormat = .Depth16Unorm,
				width = NS.UInteger(w),
				height = NS.UInteger(h),
				mipmapped = false,
			)
			defer desc->release()

			desc->setUsage({.RenderTarget})
			desc->setStorageMode(.Private)

			if depth_texture != nil {
				depth_texture->release()
			}

			depth_texture = device->newTextureWithDescriptor(desc)
		}

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

		depth_attachment := pass->depthAttachment()
		depth_attachment->setTexture(depth_texture)
		depth_attachment->setClearDepth(1.0)
		depth_attachment->setLoadAction(.Clear)
		depth_attachment->setStoreAction(.Store)

		command_buffer := command_queue->commandBuffer()
		defer command_buffer->release()

		render_encoder := command_buffer->renderCommandEncoderWithDescriptor(pass)
		defer render_encoder->release()

		render_encoder->setRenderPipelineState(pso)
		render_encoder->setVertexBuffer(vertex_buffer,   0, 0)
		render_encoder->setVertexBuffer(instance_buffer, 0, 1)
		render_encoder->setVertexBuffer(camera_buffer,   0, 2)
		render_encoder->drawIndexedPrimitivesWithInstanceCount(.Triangle, 6*6, .UInt16, index_buffer, 0, NUM_INSTANCES)

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
